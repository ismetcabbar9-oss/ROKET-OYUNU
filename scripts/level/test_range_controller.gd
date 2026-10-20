class_name TestRangeController
extends Node3D
## Test alanı akışı: füze rampada hazır -> fırlat -> uçuş -> patlama -> yeni füze rampada.
## Füze türü seçimi, kontrol modu (joystick / jiroskop) ve HUD güncellemesi burada.

enum State { READY, FLYING, AFTERMATH }

@export var missiles: Array[MissileDefinition] = []
@export var missile_scene: PackedScene
@export var explosion_scene: PackedScene
@export var terrain_shape: TerrainShape
@export var launch_point: Marker3D
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
var current_missile: Missile

var _out_of_bounds_time: float = 0.0


func _ready() -> void:
	hud.fire_pressed.connect(fire)
	hud.detonate_pressed.connect(detonate)
	hud.missile_selected.connect(select_missile)
	hud.control_mode_toggled.connect(_toggle_control_mode)
	hud.calibrate_pressed.connect(_calibrate)
	hud.set_missiles(missiles)
	select_missile(0)


func select_missile(index: int) -> void:
	if state != State.READY or missiles.is_empty():
		return
	selected_index = clampi(index, 0, missiles.size() - 1)
	hud.set_selected(selected_index, missiles[selected_index])
	_spawn_on_rail()


func fire() -> void:
	if state != State.READY or current_missile == null:
		return
	var input: SteerInput = _active_input()
	input.calibrate()
	current_missile.launch(input)
	state = State.FLYING
	_out_of_bounds_time = 0.0
	hud.set_mode(Hud.Mode.FLYING)
	hud.show_message("Füze yolda! Hedef kuzeyde, vadinin sonunda.", 3.0)


## Uçuştaki füzeyi havada patlatır.
func detonate() -> void:
	if state == State.FLYING and is_instance_valid(current_missile):
		current_missile.detonate_now()


func _spawn_on_rail() -> void:
	if is_instance_valid(current_missile):
		current_missile.queue_free()
	current_missile = missile_scene.instantiate() as Missile
	projectiles.add_child(current_missile)
	current_missile.setup(missiles[selected_index])
	current_missile.global_transform = launch_point.global_transform
	current_missile.detonated.connect(_on_missile_detonated)
	camera.follow(current_missile, true)
	state = State.READY
	hud.set_mode(Hud.Mode.READY)
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
	get_tree().create_timer(aftermath_seconds).timeout.connect(_spawn_on_rail)


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
