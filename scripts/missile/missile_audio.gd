class_name MissileAudio
extends Node3D
## Füzenin katmanlı sesi. Missile her fizik adımında update() çağırır; katman seviyeleri
## saf fonksiyon layer_gains() ile hesaplanır (birim testleriyle doğrulanır).
## Oynatıcılar doppler izler: yerdeki kameranın yanından geçen füzenin perdesi düşer.

## Sessiz kabul edilen kazanç (altında oynatıcı durdurulur, işlemci boşa çalışmaz).
const SILENT: float = 0.002

@export var crack: AudioStreamPlayer3D
@export var booster: AudioStreamPlayer3D
@export var sustainer: AudioStreamPlayer3D
@export var burnout: AudioStreamPlayer3D
@export var air: AudioStreamPlayer3D
## Seviye değişimlerinin yumuşatma hızı (1/s): ani sıçrama ve tıkırtı olmasın.
@export var smoothing: float = 10.0

var settings: MissileSoundSettings
var max_speed: float = 100.0

var _ignited: bool = false
var _burned_out: bool = false
var _gains: Vector3 = Vector3.ZERO   # booster, sustainer, hava (doğrusal)


func configure(p_settings: MissileSoundSettings, p_max_speed: float) -> void:
	settings = p_settings if p_settings != null else MissileSoundSettings.new()
	max_speed = p_max_speed
	booster.pitch_scale = settings.booster_pitch
	sustainer.pitch_scale = settings.sustainer_pitch


## Motor ateşlendi (rampada ya da silodan çıktıktan sonra havada).
func ignite() -> void:
	if _ignited:
		return
	_ignited = true
	crack.play()


## burn_time: ateşlemeden beri geçen süre (rampada bekleme dahil), fuel_left: kalan yakıt (s).
func update(burn_time: float, fuel_left: float, speed: float, delta: float) -> void:
	if not _ignited:
		return
	if fuel_left <= 0.0 and not _burned_out:
		_burned_out = true
		burnout.play()
	var target: Vector3 = layer_gains(settings, burn_time, fuel_left, speed)
	_gains = _gains.lerp(target, 1.0 - exp(-smoothing * delta))
	var speed_t: float = clampf(speed / maxf(max_speed, 1.0), 0.0, 1.0)
	var engine_pitch: float = 1.0 + settings.speed_pitch_gain * speed_t
	_drive(booster, _gains.x, settings.engine_volume_db, settings.booster_pitch * engine_pitch)
	_drive(sustainer, _gains.y, settings.engine_volume_db, settings.sustainer_pitch * engine_pitch)
	var air_t: float = clampf(speed / settings.air_full_speed, 0.0, 1.0)
	_drive(air, _gains.z, settings.air_volume_db, lerpf(settings.air_pitch_min, settings.air_pitch_max, air_t))


## Katman kazançları (0..1): x = booster, y = sustainer, z = hava sürtünmesi.
static func layer_gains(s: MissileSoundSettings, burn_time: float, fuel_left: float, speed: float) -> Vector3:
	var air_t: float = clampf(speed / s.air_full_speed, 0.0, 1.0)
	var air_gain: float = air_t * air_t
	if fuel_left <= 0.0:
		return Vector3(0.0, 0.0, air_gain)
	var fade: float = clampf((burn_time - s.booster_seconds) / s.booster_crossfade_seconds, 0.0, 1.0)
	return Vector3(cos(fade * PI * 0.5), sin(fade * PI * 0.5), air_gain)


## Füze yok olurken: döngüler kesilir (patlama sesi zaten devralır).
func stop_all() -> void:
	for p: AudioStreamPlayer3D in [booster, sustainer, air]:
		p.stop()


func _drive(player: AudioStreamPlayer3D, gain: float, base_db: float, pitch: float) -> void:
	if gain < SILENT:
		if player.playing:
			player.stop()
		return
	player.volume_db = base_db + linear_to_db(gain)
	player.pitch_scale = pitch
	if not player.playing:
		player.play()
