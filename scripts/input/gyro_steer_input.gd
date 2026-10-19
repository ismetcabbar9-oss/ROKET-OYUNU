class_name GyroSteerInput
extends SteerInput
## Cihazı eğerek yönlendirme. Yerçekimi vektörünün kalibre edilen nötr duruşa göre
## sapmasından sağ/sol (yatırma) ve yukarı/aşağı (öne/arkaya eğme) açıları hesaplanır.
## Yatay (landscape) ekran yönü varsayılır.

## Tam girdiye karşılık gelen eğim açısı.
@export_range(5.0, 60.0, 1.0, "suffix:°") var full_tilt_deg: float = 22.0
@export_range(0.0, 0.5, 0.01) var dead_zone: float = 0.05
## Ham sensör verisini yumuşatma katsayısı (1/s).
@export var smoothing: float = 18.0

var _neutral_roll: float = 0.0
var _neutral_pitch: float = 0.0
var _smoothed: Vector2 = Vector2.ZERO


static func is_available() -> bool:
	return Input.get_gravity().length_squared() > 0.01


func calibrate() -> void:
	var angles: Vector2 = _read_angles()
	_neutral_roll = angles.x
	_neutral_pitch = angles.y
	_smoothed = Vector2.ZERO


func get_steer() -> Vector2:
	return _apply_user_settings(_smoothed, UserSettings.gyro_sensitivity)


func _process(delta: float) -> void:
	var angles: Vector2 = _read_angles()
	var full: float = deg_to_rad(full_tilt_deg)
	var raw := Vector2(
		wrapf(angles.x - _neutral_roll, -PI, PI) / full,
		wrapf(angles.y - _neutral_pitch, -PI, PI) / full
	)
	raw = raw.limit_length(1.0)
	if raw.length() < dead_zone:
		raw = Vector2.ZERO
	_smoothed = _smoothed.lerp(raw, 1.0 - exp(-smoothing * delta))


## x = yatırma (sağa pozitif), y = öne/arkaya eğim (cihazın üst kenarını kendine çekmek pozitif).
func _read_angles() -> Vector2:
	var g: Vector3 = Input.get_gravity()
	if g.length_squared() < 0.01:
		return Vector2.ZERO
	g = g.normalized()
	var roll: float = atan2(g.x, -g.y)
	var pitch: float = atan2(g.z, Vector2(g.x, g.y).length())
	return Vector2(roll, pitch)
