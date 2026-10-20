class_name Launcher
extends Node3D
## Fırlatma rampası: füzeyi taşır ve aşamalı fırlatma dizisini yürütür.
##   READY -> PREPARE -> RAISE -> LOCK -> IGNITE -> RELEASE -> RESET -> READY
## Mekanizmanın görünümü üç sürekli değerle tanımlanır (0..1): hazırlık (destek ayakları),
## kaldırma (ray açısı / silo kapağı) ve kilit (kelepçeler). Üç rampa türü de aynı betiği
## kullanır; sahnede hangi parçalar atanmışsa onlar hareket eder.

signal stage_changed(stage: Stage)
## Füze rampadan ayrıldı (motoru yanıyor ve uçuş modeli devrede).
signal missile_released(missile: Missile)

enum Stage { READY, PREPARE, RAISE, LOCK, IGNITE, RELEASE, RESET }

@export var definition: LauncherDefinition
## Füzenin bağlandığı nokta (füze merkezi, -Z burun yönü); hareketli parçanın çocuğu.
@export var cradle: Node3D
## Açıksa cradle füze merkezini değil burnunu gösterir (silo: burun kapağın hemen altında).
@export var cradle_at_nose: bool = false
## Fırlatma bulutunun çıktığı nokta (TEL/ray: kuyruk altındaki zemin, silo: tüp ağzı).
@export var blast_point: Marker3D
@export var blast_scene: PackedScene
## Dizi boyunca yanıp sönen uyarı lambaları.
@export var beacons: Array[Node3D] = []
@export var alarm_sound: AudioStreamPlayer3D
## Kaldırma aşamasında çalar (hidrolik döngü ya da kapak sesi).
@export var mechanism_sound: AudioStreamPlayer3D
@export var lock_sound: AudioStreamPlayer3D
## Füze ayrıldıktan sonra mekanizmanın toparlanmaya başlamasına kadar bekleme.
@export var release_hold_seconds: float = 2.0
@export var reset_seconds: float = 3.0
@export var beacon_blink_hz: float = 2.5

@export_group("Mekanizma parçaları")
## Kaldırılan ray/erektör: yerel X ekseninde taşıma açısından fırlatma açısına döner.
@export var raise_pivot: Node3D
## Silo kapakları: yerel Z ekseninde, bulundukları tarafa doğru açılır.
@export var hatches: Array[Node3D] = []
@export var hatch_open_deg: float = 115.0
## Destek ayakları: hazırlıkta aşağı iner.
@export var jacks: Node3D
@export var jack_travel: float = 0.35
## Füze kelepçeleri: kilitte içe kapanır (açık durumda dışa açık).
@export var clamps: Array[Node3D] = []
@export var clamp_open_deg: float = 65.0
## Kaldırma pistonları (rampa gövdesi ile hareketli parça arasında uzar).
@export var rams: Array[HydraulicRam] = []

var stage: Stage = Stage.READY
var missile: Missile

var _stage_time: float = 0.0
var _time_scale: float = 1.0
var _steer: SteerInput
var _prep: float = 0.0
var _raise: float = 0.0
var _lock: float = 0.0
## RESET başlangıcındaki değerler (oradan sıfıra inilir).
var _reset_from: Vector3 = Vector3.ZERO
var _eject_speed: float = 0.0
var _eject_start: Transform3D


func _ready() -> void:
	_apply_pose(0.0, 0.0, 0.0)
	_set_beacons(false)


## Füzeyi rampaya yerleştirir (READY ya da RESET sırasında).
func attach(p_missile: Missile) -> void:
	missile = p_missile
	_hold_missile()
	missile.reset_physics_interpolation()


## Rampadaki füzeyi bırakmadan ayırır (ör. başka rampaya taşınacak).
func detach() -> void:
	missile = null


func is_ready() -> bool:
	return stage == Stage.READY and is_instance_valid(missile)


func is_busy() -> bool:
	return stage != Stage.READY


## Fırlatma dizisini başlatır; füze RELEASE aşamasında bu girdiyle uçuşa geçer.
func begin_sequence(steer: SteerInput) -> bool:
	if not is_ready():
		return false
	_steer = steer
	_time_scale = 1.0
	_enter(Stage.PREPARE)
	return true


## Ateşlemeye kadarki aşamaları hızlandırır ("ATLA").
func skip() -> void:
	if stage in [Stage.PREPARE, Stage.RAISE, Stage.LOCK]:
		_time_scale = definition.skip_time_scale


## Ateşleme anındaki füze dönüşümü (fırlatma açısında, kilitli). Testler ve kamera için.
func get_launch_transform() -> Transform3D:
	var saved: Vector3 = Vector3(_prep, _raise, _lock)
	_apply_pose(1.0, 1.0, 1.0)
	var xform: Transform3D = cradle.global_transform
	_apply_pose(saved.x, saved.y, saved.z)
	return xform


func _physics_process(delta: float) -> void:
	if stage == Stage.READY:
		if is_instance_valid(missile):
			_hold_missile()
		return
	var scaled: float = delta * (_time_scale if stage in [Stage.PREPARE, Stage.RAISE, Stage.LOCK] else 1.0)
	_stage_time += scaled
	var duration: float = _stage_duration(stage)
	var t: float = 1.0 if duration <= 0.0 else clampf(_stage_time / duration, 0.0, 1.0)
	var eased: float = smoothstep(0.0, 1.0, t)
	match stage:
		Stage.PREPARE:
			_prep = eased
		Stage.RAISE:
			_raise = eased
		Stage.LOCK:
			_lock = eased
		Stage.RESET:
			_prep = _reset_from.x * (1.0 - eased)
			_raise = _reset_from.y * (1.0 - eased)
			_lock = _reset_from.z * (1.0 - eased)
	_apply_pose(_prep, _raise, _lock)

	if stage == Stage.IGNITE and definition.kind == LauncherDefinition.Kind.SILO:
		_step_cold_eject(delta, t)
	elif stage <= Stage.IGNITE and is_instance_valid(missile):
		_hold_missile()

	_set_beacons(stage <= Stage.IGNITE and fmod(_beacon_clock(), 1.0) < 0.5)
	if _stage_time >= duration:
		_advance()


func _advance() -> void:
	match stage:
		Stage.PREPARE:
			_enter(Stage.RAISE)
		Stage.RAISE:
			_enter(Stage.LOCK)
		Stage.LOCK:
			_enter(Stage.IGNITE)
		Stage.IGNITE:
			_enter(Stage.RELEASE)
		Stage.RELEASE:
			_enter(Stage.RESET)
		Stage.RESET:
			_enter(Stage.READY)


func _enter(new_stage: Stage) -> void:
	stage = new_stage
	_stage_time = 0.0
	match stage:
		Stage.PREPARE:
			_play(alarm_sound)
		Stage.RAISE:
			_play(mechanism_sound)
		Stage.LOCK:
			_stop(mechanism_sound)
			_play(lock_sound)
		Stage.IGNITE:
			_begin_ignition()
		Stage.RELEASE:
			_release()
		Stage.RESET:
			_reset_from = Vector3(_prep, _raise, _lock)
			_play(mechanism_sound)
		Stage.READY:
			_stop(mechanism_sound)
			_set_beacons(false)
			_apply_pose(0.0, 0.0, 0.0)
	stage_changed.emit(stage)


func _begin_ignition() -> void:
	_time_scale = 1.0
	if definition.kind == LauncherDefinition.Kind.SILO:
		# Soğuk fırlatma: motor yanmadan gaz basıncıyla tüpten atılır
		_eject_speed = definition.eject_speed
		_eject_start = missile.global_transform
		_spawn_blast(LaunchBlast.Kind.COLD, blast_point.global_transform)
	else:
		missile.ignite_on_rail()
		_spawn_blast(LaunchBlast.Kind.GROUND, blast_point.global_transform)


func _release() -> void:
	if not is_instance_valid(missile):
		return
	var released: Missile = missile
	missile = null
	if definition.kind == LauncherDefinition.Kind.SILO:
		var tail := Transform3D(Basis.IDENTITY, released.global_position + released.global_basis.z * released.definition.length * 0.5)
		_spawn_blast(LaunchBlast.Kind.AIR, tail)
	released.launch(_steer)
	missile_released.emit(released)


## Gazla atılan füze yerçekimiyle yavaşlarken burnu ateşleme açısına doğru eğilir.
func _step_cold_eject(delta: float, t: float) -> void:
	if not is_instance_valid(missile):
		return
	_eject_speed -= MissileFlightModel.GRAVITY * delta
	var pos: Vector3 = missile.global_position + Vector3.UP * _eject_speed * delta
	var target: Basis = _ignition_basis()
	var basis: Basis = _eject_start.basis.orthonormalized().slerp(target, smoothstep(0.0, 1.0, t))
	missile.global_transform = Transform3D(basis, pos)


## Silonun fırlatma yönünde, ignition_pitch_deg açısında burun yukarı bakan dönüşüm.
func _ignition_basis() -> Basis:
	var heading: Vector3 = -global_basis.z
	heading.y = 0.0
	heading = heading.normalized()
	var pitch: float = deg_to_rad(definition.ignition_pitch_deg)
	var forward: Vector3 = heading * cos(pitch) + Vector3.UP * sin(pitch)
	return Basis.looking_at(forward, Vector3.UP)


func _spawn_blast(kind: LaunchBlast.Kind, xform: Transform3D) -> void:
	if blast_scene == null:
		return
	var blast: LaunchBlast = blast_scene.instantiate() as LaunchBlast
	get_parent().add_child(blast)
	blast.global_transform = xform
	blast.play(kind, definition.blast_scale, definition.shake_strength)


func _hold_missile() -> void:
	var xform: Transform3D = cradle.global_transform
	if cradle_at_nose:
		xform.origin += xform.basis.z.normalized() * missile.definition.length * 0.5
	missile.global_transform = xform


func _stage_duration(s: Stage) -> float:
	match s:
		Stage.PREPARE:
			return definition.prepare_seconds
		Stage.RAISE:
			return definition.raise_seconds
		Stage.LOCK:
			return definition.lock_seconds
		Stage.IGNITE:
			return definition.ignite_seconds
		Stage.RELEASE:
			return release_hold_seconds
		Stage.RESET:
			return reset_seconds
	return 0.0


func _beacon_clock() -> float:
	return Time.get_ticks_msec() * 0.001 * beacon_blink_hz


func _set_beacons(lit: bool) -> void:
	for b: Node3D in beacons:
		b.visible = lit


func _play(player: AudioStreamPlayer3D) -> void:
	if player != null:
		player.play()


func _stop(player: AudioStreamPlayer3D) -> void:
	if player != null:
		player.stop()


func _apply_pose(prep_t: float, raise_t: float, lock_t: float) -> void:
	if raise_pivot != null:
		raise_pivot.rotation.x = deg_to_rad(lerpf(definition.stow_angle_deg, definition.launch_angle_deg, raise_t))
	for h: Node3D in hatches:
		h.rotation.z = -signf(h.position.x) * deg_to_rad(hatch_open_deg) * raise_t
	if jacks != null:
		jacks.position.y = -jack_travel * prep_t
	for c: Node3D in clamps:
		c.rotation.z = -signf(c.position.x) * deg_to_rad(clamp_open_deg) * (1.0 - lock_t)
	for r: HydraulicRam in rams:
		r.update()
