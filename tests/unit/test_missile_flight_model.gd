extends GutTest
## MissileFlightModel davranış testleri. Her test kendi ayarlarını kurar,
## böylece config/ altındaki ince ayarlar testleri bozmaz.

const DT: float = 1.0 / 60.0


func _settings() -> MissileFlightSettings:
	var s := MissileFlightSettings.new()
	s.max_yaw_rate_deg = 60.0
	s.max_pitch_rate_deg = 60.0
	s.turn_response = 3.0
	s.high_speed_turn_multiplier = 1.0
	s.input_curve_exponent = 1.0
	s.launch_speed = 40.0
	s.max_speed = 80.0
	s.thrust = 20.0
	s.drag = 0.25
	s.turn_speed_bleed = 0.0
	s.min_speed = 5.0
	s.gravity_scale = 0.0
	s.wobble_strength_deg = 0.0
	s.fuel_seconds = 10.0
	s.max_flight_seconds = 20.0
	return s


func _simulate(model: MissileFlightModel, state: MissileState, steer: Vector2, seconds: float, dt: float = DT) -> void:
	var steps: int = roundi(seconds / dt)
	for i: int in steps:
		model.step(state, steer, dt)


func test_create_state_reads_launch_direction() -> void:
	var model := MissileFlightModel.new(_settings())
	var xform := Transform3D(Basis.looking_at(Vector3(1.0, 1.0, 0.0)), Vector3(3.0, 4.0, 5.0))
	var state: MissileState = model.create_state(xform)
	assert_almost_eq(state.get_forward(), Vector3(1.0, 1.0, 0.0).normalized(), Vector3.ONE * 0.001)
	assert_eq(state.position, Vector3(3.0, 4.0, 5.0))
	assert_eq(state.speed, 40.0)


func test_straight_flight_without_input_keeps_heading() -> void:
	var model := MissileFlightModel.new(_settings())
	var state: MissileState = model.create_state(Transform3D.IDENTITY)
	_simulate(model, state, Vector2.ZERO, 3.0)
	assert_almost_eq(state.get_forward(), Vector3.FORWARD, Vector3.ONE * 0.0001)


func test_turn_rate_never_exceeds_max() -> void:
	var s := _settings()
	var model := MissileFlightModel.new(s)
	var state: MissileState = model.create_state(Transform3D.IDENTITY)
	var max_rate: float = deg_to_rad(s.max_yaw_rate_deg)
	var exceeded: bool = false
	for i: int in 300:
		model.step(state, Vector2(1.0, 1.0), DT)
		if absf(state.turn_rate.x) > max_rate + 0.0001 or absf(state.turn_rate.y) > max_rate + 0.0001:
			exceeded = true
	assert_false(exceeded, "dönüş hızı sınırı aşıldı")


func test_inertia_reaches_63_percent_after_one_time_constant() -> void:
	var s := _settings()
	var model := MissileFlightModel.new(s)
	var state: MissileState = model.create_state(Transform3D.IDENTITY)
	_simulate(model, state, Vector2(1.0, 0.0), 1.0 / s.turn_response)
	var expected: float = deg_to_rad(s.max_yaw_rate_deg) * (1.0 - exp(-1.0))
	assert_almost_eq(state.turn_rate.x, expected, 0.01)


func test_steer_right_turns_right_and_up_climbs() -> void:
	var model := MissileFlightModel.new(_settings())
	var state: MissileState = model.create_state(Transform3D.IDENTITY)
	_simulate(model, state, Vector2(1.0, 0.0), 0.5)
	assert_gt(state.get_forward().x, 0.0, "sağa girdi sağa döndürmeli (+X)")
	state = model.create_state(Transform3D.IDENTITY)
	_simulate(model, state, Vector2(0.0, 1.0), 0.5)
	assert_gt(state.get_forward().y, 0.0, "yukarı girdi burnu kaldırmalı")


func test_right_turn_banks_right() -> void:
	var model := MissileFlightModel.new(_settings())
	var state: MissileState = model.create_state(Transform3D.IDENTITY)
	_simulate(model, state, Vector2(1.0, 0.0), 1.0)
	var right_wing: Vector3 = state.get_basis().x
	assert_lt(right_wing.y, 0.0, "sağa dönüşte sağ kanat aşağı inmeli")


func test_result_is_frame_rate_independent() -> void:
	var model_a := MissileFlightModel.new(_settings())
	var model_b := MissileFlightModel.new(_settings())
	var a: MissileState = model_a.create_state(Transform3D.IDENTITY)
	var b: MissileState = model_b.create_state(Transform3D.IDENTITY)
	_simulate(model_a, a, Vector2(0.7, -0.3), 2.0, 1.0 / 30.0)
	_simulate(model_b, b, Vector2(0.7, -0.3), 2.0, 1.0 / 120.0)
	assert_almost_eq(a.yaw, b.yaw, 0.02)
	assert_almost_eq(a.pitch, b.pitch, 0.02)
	assert_almost_eq(a.speed, b.speed, 0.5)


func test_pitch_is_clamped() -> void:
	var s := _settings()
	var model := MissileFlightModel.new(s)
	var state: MissileState = model.create_state(Transform3D.IDENTITY)
	_simulate(model, state, Vector2(0.0, 1.0), 6.0)
	assert_almost_eq(state.pitch, deg_to_rad(s.max_pitch_angle_deg), 0.0001)


func test_speed_capped_while_burning_and_drops_after_fuel() -> void:
	var s := _settings()
	s.thrust = 100.0
	s.fuel_seconds = 2.0
	var model := MissileFlightModel.new(s)
	var state: MissileState = model.create_state(Transform3D.IDENTITY)
	_simulate(model, state, Vector2.ZERO, 2.0)
	assert_eq(state.speed, s.max_speed)
	assert_almost_eq(state.fuel, 0.0, 0.0001)
	_simulate(model, state, Vector2.ZERO, 2.0)
	assert_lt(state.speed, s.max_speed)
	assert_true(state.speed >= s.min_speed)


func test_hard_turns_bleed_speed() -> void:
	var s := _settings()
	s.turn_speed_bleed = 0.5
	var model := MissileFlightModel.new(s)
	var straight: MissileState = model.create_state(Transform3D.IDENTITY)
	var turning: MissileState = model.create_state(Transform3D.IDENTITY)
	_simulate(model, straight, Vector2.ZERO, 2.0)
	_simulate(model, turning, Vector2(1.0, 0.0), 2.0)
	assert_lt(turning.speed, straight.speed)


func test_gravity_pulls_nose_down() -> void:
	var s := _settings()
	s.gravity_scale = 1.0
	var model := MissileFlightModel.new(s)
	var state: MissileState = model.create_state(Transform3D.IDENTITY)
	_simulate(model, state, Vector2.ZERO, 1.0)
	assert_lt(state.pitch, 0.0)


func test_wobble_is_deterministic_and_deflects() -> void:
	var s := _settings()
	s.wobble_strength_deg = 10.0
	var model_a := MissileFlightModel.new(s)
	var model_b := MissileFlightModel.new(s)
	var a: MissileState = model_a.create_state(Transform3D.IDENTITY)
	var b: MissileState = model_b.create_state(Transform3D.IDENTITY)
	_simulate(model_a, a, Vector2.ZERO, 3.0)
	_simulate(model_b, b, Vector2.ZERO, 3.0)
	assert_eq(a.yaw, b.yaw, "aynı tohum aynı uçuşu vermeli")
	assert_ne(a.get_forward(), Vector3.FORWARD, "sapma yönü değiştirmeli")


func test_wobble_is_bounded() -> void:
	var s := _settings()
	s.wobble_strength_deg = 8.0
	var model := MissileFlightModel.new(s)
	var limit: float = deg_to_rad(8.0) + 0.0001
	var exceeded: bool = false
	for i: int in 200:
		var w: Vector2 = model.get_wobble(i * 0.1)
		if absf(w.x) > limit or absf(w.y) > limit:
			exceeded = true
	assert_false(exceeded)


func test_input_curve_softens_small_inputs() -> void:
	var s := _settings()
	s.input_curve_exponent = 2.0
	var model := MissileFlightModel.new(s)
	assert_almost_eq(model.apply_input_curve(Vector2(0.5, -0.5)), Vector2(0.25, -0.25), Vector2.ONE * 0.0001)
	assert_almost_eq(model.apply_input_curve(Vector2(1.0, -1.0)), Vector2(1.0, -1.0), Vector2.ONE * 0.0001)


func test_high_speed_reduces_turn_rate() -> void:
	var s := _settings()
	s.high_speed_turn_multiplier = 0.5
	var model := MissileFlightModel.new(s)
	assert_almost_eq(model.get_max_turn_rate(s.max_speed).x, deg_to_rad(s.max_yaw_rate_deg) * 0.5, 0.0001)
	assert_gt(model.get_max_turn_rate(0.0).x, model.get_max_turn_rate(s.max_speed).x)


func test_expires_after_max_flight_time() -> void:
	var s := _settings()
	s.max_flight_seconds = 1.0
	var model := MissileFlightModel.new(s)
	var state: MissileState = model.create_state(Transform3D.IDENTITY)
	_simulate(model, state, Vector2.ZERO, 0.9)
	assert_false(model.is_expired(state))
	_simulate(model, state, Vector2.ZERO, 0.2)
	assert_true(model.is_expired(state))


func test_shipped_missile_definitions_are_valid() -> void:
	for path: String in ["res://config/missiles/hasta.tres", "res://config/missiles/storm_shadow.tres", "res://config/missiles/fateh110.tres"]:
		var def: MissileDefinition = load(path) as MissileDefinition
		assert_not_null(def, path)
		assert_not_null(def.model_scene, path)
		assert_not_null(def.flight, path)
		assert_gt(def.flight.max_speed, def.flight.launch_speed, path)
		assert_gt(def.flight.max_flight_seconds, def.flight.fuel_seconds, path)
