class_name ChaseCamera
extends Camera3D
## Füzeyi arkadan takip eden kamera.
## Kamera ofseti hedefe bağlı bir çerçevede yumuşatılır: yüksek hızda geride kalmaz,
## yalnızca dönüşlerde gecikerek ataleti hissettirir. Araziye girmemek için ışın testi yapar.
## Patlamalar ChaseCamera'yı "camera_shake" grubu üzerinden sarsar.
## Üç kip: takip (follow), sabit noktaya bakış (focus) ve sinematik çekim (play_shot).
## Kipler arası geçişler önceki görüntüden yumuşakça harmanlanır.

@export_group("Takip")
## Kamera ofsetinin yeni yöne yetişme hızı (1/s). Düşük = daha "ağır" his.
@export var follow_sharpness: float = 5.0
@export var look_sharpness: float = 9.0
## Kameranın baktığı noktanın füzenin ne kadar önünde olduğu (boyun katı).
@export var look_ahead_lengths: float = 3.0
## Hızla birlikte kameranın uzaklaşma oranı.
@export var speed_pullback: float = 0.25

@export_group("Görüş açısı")
@export var base_fov: float = 60.0
@export var speed_fov_gain: float = 12.0
@export var fov_reference_speed: float = 100.0

@export_group("Çarpışma")
@export_flags_3d_physics var collision_mask: int = 1
@export var collision_margin: float = 0.8

@export_group("Sarsıntı")
@export var shake_max_offset: float = 0.7
@export var shake_max_roll_deg: float = 4.0
@export var shake_decay: float = 1.4
## Bu mesafenin ötesindeki patlamalar sarsmaz.
@export var shake_range: float = 350.0

var target: Missile

var _offset: Vector3 = Vector3(0, 3, 10)
var _look_offset: Vector3 = Vector3.FORWARD
var _focus_point: Vector3
var _has_focus: bool = false
var _trauma: float = 0.0
var _noise := FastNoiseLite.new()
var _time: float = 0.0

var _shot_active: bool = false
var _shot_position: Vector3
var _shot_look: Vector3
var _shot_look_node: Node3D
var _shot_fov: float = 60.0

var _blend_from: Transform3D
var _blend_fov_from: float = 60.0
var _blend_time: float = 0.0
var _blend_duration: float = 0.0


func _ready() -> void:
	# Kamera _process içinde hareket ettiriliyor; fizik interpolasyonu ona uygulanmamalı.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(Explosion.SHAKE_GROUP)
	_noise.frequency = 2.5
	fov = base_fov


## Yeni bir füzeyi takip etmeye başlar. blend_seconds > 0 ise önceki görüntüden geçiş yapar.
func follow(missile: Missile, blend_seconds: float = 0.0) -> void:
	_begin_blend(blend_seconds)
	target = missile
	_has_focus = false
	_shot_active = false
	if missile != null:
		_offset = _desired_offset(missile)
		_look_offset = _desired_look(missile)
		if blend_seconds <= 0.0:
			global_transform = _follow_transform(missile.get_global_transform_interpolated().origin)


## Hedef yokken (ör. patlamadan sonra) verilen noktaya bakarak yerinde kalır.
func focus(point: Vector3) -> void:
	target = null
	_shot_active = false
	_focus_point = point
	_has_focus = true


## Sinematik çekim: kamera from noktasına geçip look_point'e (ya da look_node'a) bakar.
func play_shot(from: Vector3, look_point: Vector3, shot_fov: float, blend_seconds: float, look_node: Node3D = null) -> void:
	_begin_blend(blend_seconds)
	target = null
	_has_focus = false
	_shot_active = true
	_shot_position = from
	_shot_look = look_point
	_shot_look_node = look_node
	_shot_fov = shot_fov


func add_trauma_at(point: Vector3, strength: float) -> void:
	var falloff: float = clampf(1.0 - global_position.distance_to(point) / shake_range, 0.0, 1.0)
	_trauma = clampf(_trauma + strength * falloff * 0.9, 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)

	var wanted: Transform3D = global_transform
	var wanted_fov: float = fov
	if is_instance_valid(target):
		var blend: float = 1.0 - exp(-follow_sharpness * delta)
		_offset = _offset.lerp(_desired_offset(target), blend)
		_look_offset = _look_offset.lerp(_desired_look(target), 1.0 - exp(-look_sharpness * delta))
		wanted = _follow_transform(target.get_global_transform_interpolated().origin)
		var speed_t: float = clampf(target.get_speed() / fov_reference_speed, 0.0, 1.0)
		wanted_fov = lerpf(fov, base_fov + speed_fov_gain * speed_t, 1.0 - exp(-3.0 * delta))
	elif _shot_active:
		var look: Vector3 = _shot_look_node.get_global_transform_interpolated().origin if is_instance_valid(_shot_look_node) else _shot_look
		wanted = _look_transform(_shot_position, look)
		wanted_fov = _shot_fov
	elif _has_focus:
		var look_xform: Transform3D = _look_transform(global_position, _focus_point)
		wanted = Transform3D(global_basis.orthonormalized().slerp(look_xform.basis, 1.0 - exp(-4.0 * delta)), global_position)

	if _blend_time < _blend_duration:
		_blend_time += delta
		var w: float = smoothstep(0.0, 1.0, _blend_time / _blend_duration)
		wanted = _blend_from.interpolate_with(wanted, w)
		wanted_fov = lerpf(_blend_fov_from, wanted_fov, w)
	global_transform = wanted
	fov = wanted_fov
	_apply_shake()


func _begin_blend(seconds: float) -> void:
	_blend_from = Transform3D(global_basis.orthonormalized(), global_position)
	_blend_fov_from = fov
	_blend_time = 0.0
	_blend_duration = seconds


func _desired_offset(missile: Missile) -> Vector3:
	var forward: Vector3 = missile.get_forward()
	var definition: MissileDefinition = missile.definition
	var pull: float = 1.0 + speed_pullback * clampf(missile.get_speed() / fov_reference_speed, 0.0, 1.5)
	var height: float = definition.camera_height
	var back: Vector3 = -forward * definition.camera_distance * pull
	return back + Vector3.UP * height


func _desired_look(missile: Missile) -> Vector3:
	return missile.get_forward() * missile.definition.length * look_ahead_lengths


func _follow_transform(target_pos: Vector3) -> Transform3D:
	var desired: Vector3 = target_pos + _offset
	# Kamera ile füze arasına arazi girerse kamerayı engelin önüne çek
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(target_pos, desired, collision_mask)
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		var hit_pos: Vector3 = hit["position"]
		var hit_normal: Vector3 = hit["normal"]
		desired = hit_pos + hit_normal * collision_margin
	return _look_transform(desired, target_pos + _look_offset)


func _look_transform(from: Vector3, to: Vector3) -> Transform3D:
	if from.is_equal_approx(to):
		return Transform3D(global_basis.orthonormalized(), from)
	return Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


func _apply_shake() -> void:
	if _trauma <= 0.0:
		h_offset = 0.0
		v_offset = 0.0
		return
	var amount: float = _trauma * _trauma
	h_offset = _noise.get_noise_2d(_time * 10.0, 0.0) * shake_max_offset * amount
	v_offset = _noise.get_noise_2d(0.0, _time * 10.0) * shake_max_offset * amount
	rotate_object_local(Vector3.FORWARD, deg_to_rad(shake_max_roll_deg) * amount * _noise.get_noise_2d(_time * 10.0, 50.0))
