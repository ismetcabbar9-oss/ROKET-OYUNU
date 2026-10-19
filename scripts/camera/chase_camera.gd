class_name ChaseCamera
extends Camera3D
## Füzeyi arkadan takip eden kamera.
## Kamera ofseti hedefe bağlı bir çerçevede yumuşatılır: yüksek hızda geride kalmaz,
## yalnızca dönüşlerde gecikerek ataleti hissettirir. Araziye girmemek için ışın testi yapar.
## Patlamalar ChaseCamera'yı "camera_shake" grubu üzerinden sarsar.

@export_group("Takip")
## Kamera ofsetinin yeni yöne yetişme hızı (1/s). Düşük = daha "ağır" his.
@export var follow_sharpness: float = 5.0
@export var look_sharpness: float = 9.0
## Kameranın baktığı noktanın füzenin ne kadar önünde olduğu (boyun katı).
@export var look_ahead_lengths: float = 3.0
## Hızla birlikte kameranın uzaklaşma oranı.
@export var speed_pullback: float = 0.25
## Füze rampadayken ek yükseklik, uzaklık çarpanı ve yandan bakış açısı (kamyon füzeyi kapatmasın).
@export var rail_extra_height: float = 3.5
@export var rail_distance_multiplier: float = 1.5
@export var rail_view_yaw_deg: float = 32.0

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


func _ready() -> void:
	# Kamera _process içinde hareket ettiriliyor; fizik interpolasyonu ona uygulanmamalı.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(Explosion.SHAKE_GROUP)
	_noise.frequency = 2.5
	fov = base_fov


## Yeni bir füzeyi takip etmeye başlar. snap = geçiş animasyonu olmadan yerine otur.
func follow(missile: Missile, snap: bool = true) -> void:
	target = missile
	_has_focus = false
	if snap and missile != null:
		_offset = _desired_offset(missile)
		_look_offset = _desired_look(missile)
		_apply(missile.get_global_transform_interpolated().origin, 0.0)


## Hedef yokken (ör. patlamadan sonra) verilen noktaya bakarak yerinde kalır.
func focus(point: Vector3) -> void:
	target = null
	_focus_point = point
	_has_focus = true


func add_trauma_at(point: Vector3, strength: float) -> void:
	var falloff: float = clampf(1.0 - global_position.distance_to(point) / shake_range, 0.0, 1.0)
	_trauma = clampf(_trauma + strength * falloff * 0.9, 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	_trauma = maxf(_trauma - shake_decay * delta, 0.0)

	if is_instance_valid(target):
		var blend: float = 1.0 - exp(-follow_sharpness * delta)
		_offset = _offset.lerp(_desired_offset(target), blend)
		_look_offset = _look_offset.lerp(_desired_look(target), 1.0 - exp(-look_sharpness * delta))
		_apply(target.get_global_transform_interpolated().origin, delta)
		var speed_t: float = clampf(target.get_speed() / fov_reference_speed, 0.0, 1.0)
		fov = lerpf(fov, base_fov + speed_fov_gain * speed_t, 1.0 - exp(-3.0 * delta))
	elif _has_focus:
		var wanted := Transform3D(global_basis, global_position).looking_at(_focus_point, Vector3.UP)
		global_basis = global_basis.slerp(wanted.basis.orthonormalized(), 1.0 - exp(-4.0 * delta))
		_apply_shake()


func _desired_offset(missile: Missile) -> Vector3:
	var forward: Vector3 = missile.get_forward()
	var definition: MissileDefinition = missile.definition
	var pull: float = 1.0 + speed_pullback * clampf(missile.get_speed() / fov_reference_speed, 0.0, 1.5)
	var height: float = definition.camera_height
	var back: Vector3 = -forward * definition.camera_distance * pull
	if missile.phase == Missile.Phase.ON_RAIL:
		height += rail_extra_height
		back = back.rotated(Vector3.UP, deg_to_rad(rail_view_yaw_deg)) * rail_distance_multiplier
	return back + Vector3.UP * height


func _desired_look(missile: Missile) -> Vector3:
	return missile.get_forward() * missile.definition.length * look_ahead_lengths


func _apply(target_pos: Vector3, _delta: float) -> void:
	var desired: Vector3 = target_pos + _offset
	# Kamera ile füze arasına arazi girerse kamerayı engelin önüne çek
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(target_pos, desired, collision_mask)
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		var hit_pos: Vector3 = hit["position"]
		var hit_normal: Vector3 = hit["normal"]
		desired = hit_pos + hit_normal * collision_margin
	global_position = desired
	var look_point: Vector3 = target_pos + _look_offset
	if not global_position.is_equal_approx(look_point):
		look_at(look_point, Vector3.UP)
	_apply_shake()


func _apply_shake() -> void:
	if _trauma <= 0.0:
		h_offset = 0.0
		v_offset = 0.0
		return
	var amount: float = _trauma * _trauma
	h_offset = _noise.get_noise_2d(_time * 10.0, 0.0) * shake_max_offset * amount
	v_offset = _noise.get_noise_2d(0.0, _time * 10.0) * shake_max_offset * amount
	rotate_object_local(Vector3.FORWARD, deg_to_rad(shake_max_roll_deg) * amount * _noise.get_noise_2d(_time * 10.0, 50.0))
