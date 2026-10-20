class_name Missile
extends CharacterBody3D
## Oyuncunun yönlendirdiği füze. Uçuş matematiği MissileFlightModel'de;
## bu düğüm yalnızca girdiyi okur, modeli ilerletir, hareket ettirir ve çarpışmayı bildirir.

## Füze bir yere çarptığında ya da ömrü dolduğunda bir kez yayınlanır.
signal detonated(position: Vector3, normal: Vector3, collider: Object)

enum Phase { ON_RAIL, FLYING, DONE }

@export var exhaust: MissileExhaust
@export var visual_root: Node3D
@export var collision_shape: CollisionShape3D

var definition: MissileDefinition
var steer_source: SteerInput
var phase: Phase = Phase.ON_RAIL

var _model: MissileFlightModel
var _state: MissileState


## Füzeyi bir türle kurar (fırlatmadan önce, sahneye eklendikten sonra çağrılır).
func setup(p_definition: MissileDefinition) -> void:
	definition = p_definition
	for child: Node in visual_root.get_children():
		child.queue_free()
	visual_root.add_child(definition.model_scene.instantiate())

	var capsule := CapsuleShape3D.new()
	capsule.radius = definition.body_radius
	capsule.height = maxf(definition.length * 0.9, capsule.radius * 2.0)
	collision_shape.shape = capsule

	exhaust.position = Vector3(0.0, 0.0, definition.length * 0.5)
	exhaust.configure(definition.exhaust_scale)
	_model = MissileFlightModel.new(definition.flight)


## Motor rampada, füze henüz bırakılmadan yanar (ateşleme aşaması).
func ignite_on_rail() -> void:
	if phase == Phase.ON_RAIL:
		exhaust.set_throttle(1.0)
		exhaust.set_speed_ratio(0.0)


func launch(steer: SteerInput) -> void:
	steer_source = steer
	_state = _model.create_state(global_transform)
	phase = Phase.FLYING


func get_speed() -> float:
	return _state.speed if _state != null else 0.0


func get_fuel_ratio() -> float:
	if _state == null:
		return 1.0
	if definition.flight.fuel_seconds <= 0.0:
		return 0.0
	return clampf(_state.fuel / definition.flight.fuel_seconds, 0.0, 1.0)


func get_flight_time() -> float:
	return _state.flight_time if _state != null else 0.0


func get_forward() -> Vector3:
	return _state.get_forward() if _state != null else -global_basis.z


## Uçuştaki füzeyi bulunduğu yerde patlatır (oyuncu "PATLAT" dediğinde).
func detonate_now() -> void:
	if phase == Phase.FLYING:
		_detonate(global_position, Vector3.UP, null)


func _physics_process(delta: float) -> void:
	if phase != Phase.FLYING:
		return
	var steer: Vector2 = steer_source.get_steer() if steer_source != null else Vector2.ZERO
	_model.step(_state, steer, delta)
	global_basis = _state.get_basis()
	exhaust.set_throttle(1.0 if _state.fuel > 0.0 else 0.0)
	exhaust.set_speed_ratio(_state.speed / definition.flight.max_speed)

	var collision: KinematicCollision3D = move_and_collide(_state.get_velocity() * delta)
	if collision != null:
		_detonate(collision.get_position(), collision.get_normal(), collision.get_collider())
		return
	_state.position = global_position
	if _model.is_expired(_state):
		_detonate(global_position, Vector3.UP, null)


func _detonate(at: Vector3, normal: Vector3, collider: Object) -> void:
	phase = Phase.DONE
	exhaust.detach_trail(get_parent())
	detonated.emit(at, normal, collider)
	queue_free()
