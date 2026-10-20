class_name TestRangeController
extends Node3D
## Test alanı akışı: füze rampada hazır -> fırlatma dizisi -> uçuş -> patlama -> yeni füze rampada.
## Füze ve rampa seçimi (uyumluluk kuralıyla), sinematik kamera çekimleri, kontrol modu
## (joystick / jiroskop) ve HUD güncellemesi burada.

## Füze rampadan ayrılıp uçuşa geçtiğinde (araçlar ve testler için).
signal missile_launched(missile: Missile)

enum State { READY, LAUNCHING, FLYING, AFTERMATH }

@export var missiles: Array[MissileDefinition] = []
@export var missile_scene: PackedScene
@export var explosion_scene: PackedScene
@export var terrain_shape: TerrainShape
@export var launchers: Array[Launcher] = []
@export var target_point: Node3D
@export var projectiles: Node3D
@export var camera: ChaseCamera
@export var hud: Hud
@export var touch_input: TouchSteerInput
@export var gyro_input: GyroSteerInput
## Patlamadan sonra yeni füzenin rampaya gelmesine kadar geçen süre.
@export var aftermath_seconds: float = 3.0
## Oyun alanı dışında kalınabilecek süre; sonra füze kendini imha eder.
@export var out_of_bounds_seconds: float = 3.0

var state: State = State.READY
var selected_index: int = 0
var selected_launcher: int = 0
var current_missile: Missile

var _out_of_bounds_time: float = 0.0


func _ready() -> void:
	hud.fire_pressed.connect(fire)
	hud.skip_pressed.connect(skip_sequence)
	hud.detonate_pressed.connect(detonate)
	hud.missile_selected.connect(select_missile)
	hud.launcher_selected.connect(select_launcher)
	hud.control_mode_toggled.connect(_toggle_control_mode)
	hud.calibrate_pressed.connect(_calibrate)
	hud.set_missiles(missiles)
	var launcher_definitions: Array[LauncherDefinition] = []
	for launcher: Launcher in launchers:
		launcher_definitions.append(launcher.definition)
		launcher.stage_changed.connect(_on_launcher_stage.bind(launcher))
		launcher.missile_released.connect(_on_missile_released)
	hud.set_launchers(launcher_definitions)
	selected_launcher = maxi(_find_launcher_for(missiles[selected_index]), 0)
	_spawn_on_launcher(0.0)


## Füze seçer; seçili rampa bu füzeyi atamıyorsa uyumlu ilk rampaya geçer.
func select_missile(index: int) -> void:
	if state != State.READY or missiles.is_empty():
		return
	selected_index = clampi(index, 0, missiles.size() - 1)
	var missile: MissileDefinition = missiles[selected_index]
	if not _launcher_definition().supports(missile):
		var found: int = _find_launcher_for(missile)
		if found >= 0:
			selected_launcher = found
			hud.show_message("%s yalnızca uyumlu rampadan atılır: %s" % [missile.display_name, _launcher_definition().display_name], 2.5)
	_spawn_on_launcher(_shot_blend(Launcher.Stage.READY))


## Rampa seçer; seçili füze bu rampadan atılamıyorsa rampanın uyumlu ilk füzesine geçer.
func select_launcher(index: int) -> void:
	if state != State.READY or launchers.is_empty():
		return
	selected_launcher = clampi(index, 0, launchers.size() - 1)
	var definition: LauncherDefinition = _launcher_definition()
	var previous: MissileDefinition = missiles[selected_index]
	if not definition.supports(previous):
		for i: int in missiles.size():
			if definition.supports(missiles[i]):
				selected_index = i
				hud.show_message("%s bu rampadan atılamaz; %s seçildi." % [previous.display_name, missiles[i].display_name], 2.5)
				break
	_spawn_on_launcher(_shot_blend(Launcher.Stage.READY))


## Fırlatma dizisini başlatır.
func fire() -> void:
	if state != State.READY or current_missile == null:
		return
	var launcher: Launcher = launchers[selected_launcher]
	if not launcher.begin_sequence(_active_input()):
		hud.show_message("Rampa hazırlanıyor, biraz bekleyin.", 1.5)
		return
	state = State.LAUNCHING
	hud.set_mode(Hud.Mode.LAUNCHING)


## Ateşlemeye kadarki aşamaları hızlandırır.
func skip_sequence() -> void:
	if state == State.LAUNCHING:
		launchers[selected_launcher].skip()


func _on_launcher_stage(stage: Launcher.Stage, launcher: Launcher) -> void:
	if launcher != launchers[selected_launcher] or state != State.LAUNCHING:
		return
	_play_shot(launcher, stage)
	var caption: String = launcher.definition.get_caption(stage)
	if caption != "":
		hud.show_message(caption, 0.0)


func _on_missile_released(missile: Missile) -> void:
	if missile != current_missile:
		return
	var input: SteerInput = _active_input()
	input.calibrate()
	missile.steer_source = input
	state = State.FLYING
	_out_of_bounds_time = 0.0
	hud.set_mode(Hud.Mode.FLYING)
	hud.show_message("Füze yolda! Hedef kuzeyde, vadinin sonunda.", 3.0)
	missile_launched.emit(missile)
	var launcher: Launcher = launchers[selected_launcher]
	_play_shot(launcher, Launcher.Stage.RELEASE)
	get_tree().create_timer(launcher.definition.release_follow_delay).timeout.connect(func() -> void:
		if state == State.FLYING and is_instance_valid(missile) and missile == current_missile:
			camera.follow(missile, 1.0))


## Uçuştaki füzeyi havada patlatır.
func detonate() -> void:
	if state == State.FLYING and is_instance_valid(current_missile):
		current_missile.detonate_now()


## Seçili füzeyi seçili rampaya yerleştirir ve hazır çekimine geçer (blend 0 = kesme).
func _spawn_on_launcher(blend: float) -> void:
	for launcher: Launcher in launchers:
		launcher.detach()
	if is_instance_valid(current_missile):
		current_missile.queue_free()
	current_missile = missile_scene.instantiate() as Missile
	projectiles.add_child(current_missile)
	current_missile.setup(missiles[selected_index])
	current_missile.detonated.connect(_on_missile_detonated)
	var launcher: Launcher = launchers[selected_launcher]
	launcher.attach(current_missile)
	var shot: LauncherCameraShot = launcher.definition.get_shot(Launcher.Stage.READY)
	if shot != null:
		var xform: Transform3D = launcher.global_transform
		camera.play_shot(xform * shot.position, xform * shot.look_at, shot.fov, blend)
	else:
		camera.follow(current_missile)
	state = State.READY
	hud.set_mode(Hud.Mode.READY)
	_refresh_selection()
	hud.update_telemetry(0.0, _altitude(current_missile.global_position), 1.0, 0.0, _target_distance(current_missile.global_position))


func _on_missile_detonated(at: Vector3, normal: Vector3, collider: Object) -> void:
	var definition: MissileDefinition = missiles[selected_index]
	var explosion: Explosion = explosion_scene.instantiate() as Explosion
	projectiles.add_child(explosion)
	# Ateş topu zemine gömülmesin diye yüzey normali yönünde biraz yukarı alınır
	explosion.global_position = at + normal * 1.5 * definition.explosion_scale
	explosion.play(definition.explosion_scale, normal, collider != null)

	camera.focus(at)
	state = State.AFTERMATH
	hud.set_mode(Hud.Mode.AFTERMATH)
	var distance: float = _target_distance(at)
	if collider != null and distance < 300.0:
		hud.show_message("İsabet! Hedef bölgesine %d m." % roundi(distance), aftermath_seconds)
	elif collider != null:
		hud.show_message("Arazi çarpması. Hedefe %d m kaldı." % roundi(distance), aftermath_seconds)
	else:
		hud.show_message("Füze havada imha edildi.", aftermath_seconds)
	current_missile = null
	get_tree().create_timer(aftermath_seconds).timeout.connect(_spawn_on_launcher.bind(0.0))


func _process(delta: float) -> void:
	if state == State.FLYING and is_instance_valid(current_missile):
		var pos: Vector3 = current_missile.global_position
		hud.update_telemetry(current_missile.get_speed(), _altitude(pos), current_missile.get_fuel_ratio(),
			current_missile.get_flight_time(), _target_distance(pos))
		_check_bounds(pos, delta)


## Görünmez sınır: koridordan çıkan ya da tavanı aşan füzeye süre tanınır, sonra imha edilir.
func _check_bounds(pos: Vector3, delta: float) -> void:
	if terrain_shape == null or terrain_shape.is_in_play_area(pos):
		if _out_of_bounds_time > 0.0:
			_out_of_bounds_time = 0.0
			hud.set_warning("")
		return
	_out_of_bounds_time += delta
	var left: float = out_of_bounds_seconds - _out_of_bounds_time
	if left <= 0.0:
		hud.set_warning("")
		current_missile.detonate_now()
		return
	hud.set_warning("SINIR! Geri dön  %.1f" % left)


func _play_shot(launcher: Launcher, stage: Launcher.Stage) -> void:
	var shot: LauncherCameraShot = launcher.definition.get_shot(stage)
	if shot == null:
		return
	var xform: Transform3D = launcher.global_transform
	var look_node: Node3D = current_missile if shot.track_missile else null
	camera.play_shot(xform * shot.position, xform * shot.look_at, shot.fov, shot.blend_seconds, look_node)


func _shot_blend(stage: Launcher.Stage) -> float:
	var shot: LauncherCameraShot = _launcher_definition().get_shot(stage)
	return shot.blend_seconds if shot != null else 0.0


func _refresh_selection() -> void:
	var definition: LauncherDefinition = _launcher_definition()
	var compatible: Array[bool] = []
	for m: MissileDefinition in missiles:
		compatible.append(definition.supports(m))
	hud.set_selection(selected_index, missiles[selected_index], selected_launcher, definition, compatible)


func _launcher_definition() -> LauncherDefinition:
	return launchers[selected_launcher].definition


func _find_launcher_for(missile: MissileDefinition) -> int:
	for i: int in launchers.size():
		if launchers[i].definition.supports(missile):
			return i
	return -1


func _active_input() -> SteerInput:
	if UserSettings.control_mode == UserSettings.ControlMode.GYRO:
		return gyro_input
	return touch_input


func _toggle_control_mode() -> void:
	if UserSettings.control_mode == UserSettings.ControlMode.GYRO:
		UserSettings.control_mode = UserSettings.ControlMode.JOYSTICK
	elif GyroSteerInput.is_available():
		UserSettings.control_mode = UserSettings.ControlMode.GYRO
	else:
		hud.show_message("Bu cihazda eğim sensörü bulunamadı.", 2.5)
		return
	UserSettings.save_settings()
	hud.refresh_control_mode()
	if state == State.FLYING and is_instance_valid(current_missile):
		var input: SteerInput = _active_input()
		input.calibrate()
		current_missile.steer_source = input


func _calibrate() -> void:
	gyro_input.calibrate()
	hud.show_message("Jiroskop kalibre edildi: bu duruş artık düz uçuş.", 2.0)


func _altitude(pos: Vector3) -> float:
	return pos.y - terrain_shape.get_height(pos.x, pos.z) if terrain_shape != null else pos.y


func _target_distance(pos: Vector3) -> float:
	return pos.distance_to(target_point.global_position) if target_point != null else 0.0
