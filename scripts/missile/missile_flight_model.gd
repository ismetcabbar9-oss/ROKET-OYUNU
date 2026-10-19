class_name MissileFlightModel
extends RefCounted
## Füze uçuş fiziği. Sahne/düğüm bilmez; yalnızca MissileState'i ilerletir,
## bu yüzden headless birim testleriyle doğrulanabilir.
##
## Model:
##  1. Girdi eğrisi -> hedef dönüş hızı (hızla azalan azami dönüş hızı)
##  2. Gerçek dönüş hızı hedefe üstel yaklaşır (atalet, kare hızından bağımsız)
##  3. Düzgün gürültü ile sapma eklenir
##  4. Yerçekimi burnu aşağı çeker (γ' = -g·cosγ / V)
##  5. Hız = itki - sürüklenme - dönüş kaybı - yerçekimi bileşeni

const GRAVITY: float = 9.8

var settings: MissileFlightSettings

var _noise_yaw: FastNoiseLite
var _noise_pitch: FastNoiseLite


func _init(p_settings: MissileFlightSettings) -> void:
	settings = p_settings
	_noise_yaw = _make_noise(settings.wobble_seed)
	_noise_pitch = _make_noise(settings.wobble_seed + 7919)


## Verilen fırlatma noktasından yeni bir durum üretir. Yuvarlanma yok sayılır.
func create_state(launch_transform: Transform3D) -> MissileState:
	var state := MissileState.new()
	var forward: Vector3 = -launch_transform.basis.z.normalized()
	state.position = launch_transform.origin
	state.yaw = atan2(-forward.x, -forward.z)
	state.pitch = clampf(asin(clampf(forward.y, -1.0, 1.0)), -_max_pitch(), _max_pitch())
	state.speed = settings.launch_speed
	state.fuel = settings.fuel_seconds
	return state


## steer: x = sağ/sol (-1..1), y = yukarı/aşağı (-1..1). Konumu değiştirmez;
## hareket ve çarpışma çağıran düğümün işidir (bkz. get_velocity()).
func step(state: MissileState, steer: Vector2, delta: float) -> void:
	if delta <= 0.0:
		return
	state.flight_time += delta

	# 1. Hedef dönüş hızı
	var input: Vector2 = apply_input_curve(steer.limit_length(1.0))
	var max_rate: Vector2 = get_max_turn_rate(state.speed)
	var target_rate := Vector2(input.x * max_rate.x, input.y * max_rate.y)

	# 2. Atalet
	var blend: float = 1.0 - exp(-settings.turn_response * delta)
	state.turn_rate = state.turn_rate.lerp(target_rate, blend)

	# 3. Sapma (dönüş hızına değil, açıya eklenir; böylece birikmez ve sınırı bozmaz)
	var wobble: Vector2 = get_wobble(state.flight_time)

	# 4. Yerçekimi kaynaklı burun düşmesi
	var gravity_pitch_rate: float = 0.0
	if settings.gravity_scale > 0.0:
		gravity_pitch_rate = -settings.gravity_scale * GRAVITY * cos(state.pitch) / maxf(state.speed, 1.0)

	state.yaw -= (state.turn_rate.x + wobble.x) * delta
	state.yaw = wrapf(state.yaw, -PI, PI)
	state.pitch += (state.turn_rate.y + wobble.y + gravity_pitch_rate) * delta
	state.pitch = clampf(state.pitch, -_max_pitch(), _max_pitch())

	# Görsel yatış: sağa dönüşte sağa yatar (Godot'ta negatif Z dönüşü)
	var yaw_ratio: float = 0.0
	if max_rate.x > 0.0:
		yaw_ratio = clampf(state.turn_rate.x / max_rate.x, -1.0, 1.0)
	var target_bank: float = -yaw_ratio * deg_to_rad(settings.max_bank_deg)
	state.bank = lerpf(state.bank, target_bank, 1.0 - exp(-settings.bank_response * delta))

	# 5. Hız
	var accel: float = -settings.drag * state.speed
	if state.fuel > 0.0:
		var burn: float = minf(state.fuel, delta)
		accel += settings.thrust * (burn / delta)
		state.fuel -= burn
	var turn_amount: float = 0.0
	if max_rate.x > 0.0 and max_rate.y > 0.0:
		turn_amount = clampf(Vector2(state.turn_rate.x / max_rate.x, state.turn_rate.y / max_rate.y).length(), 0.0, 1.0)
	accel -= settings.turn_speed_bleed * turn_amount * state.speed
	accel -= settings.gravity_scale * GRAVITY * sin(state.pitch)
	state.speed = clampf(state.speed + accel * delta, settings.min_speed, settings.max_speed)


func is_expired(state: MissileState) -> bool:
	return state.flight_time >= settings.max_flight_seconds


func apply_input_curve(steer: Vector2) -> Vector2:
	var e: float = settings.input_curve_exponent
	return Vector2(signf(steer.x) * pow(absf(steer.x), e), signf(steer.y) * pow(absf(steer.y), e))


## Hıza bağlı azami dönüş hızı (rad/s): x = sapma, y = yunuslama.
func get_max_turn_rate(speed: float) -> Vector2:
	var speed_t: float = clampf(speed / settings.max_speed, 0.0, 1.0)
	var mult: float = lerpf(1.0, settings.high_speed_turn_multiplier, speed_t)
	return Vector2(deg_to_rad(settings.max_yaw_rate_deg), deg_to_rad(settings.max_pitch_rate_deg)) * mult


## Belirli bir uçuş anındaki sapma açısal hızı (rad/s).
func get_wobble(time: float) -> Vector2:
	if settings.wobble_strength_deg <= 0.0:
		return Vector2.ZERO
	var amp: float = deg_to_rad(settings.wobble_strength_deg)
	return Vector2(_noise_yaw.get_noise_1d(time), _noise_pitch.get_noise_1d(time)) * amp


func _max_pitch() -> float:
	return deg_to_rad(settings.max_pitch_angle_deg)


func _make_noise(noise_seed: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = noise_seed
	noise.frequency = settings.wobble_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	return noise
