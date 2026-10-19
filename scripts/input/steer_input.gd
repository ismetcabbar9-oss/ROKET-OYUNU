class_name SteerInput
extends Node
## Yönlendirme girdisi kaynağı için temel sınıf (joystick, jiroskop, ileride başka).
## get_steer(): x = sağ (+) / sol (-), y = yukarı (+) / aşağı (-), uzunluk <= 1.


func get_steer() -> Vector2:
	return Vector2.ZERO


## O anki duruşu nötr kabul eder (jiroskop için anlamlı).
func calibrate() -> void:
	pass


func _apply_user_settings(raw: Vector2, sensitivity: float) -> Vector2:
	var v: Vector2 = raw * sensitivity
	if UserSettings.invert_pitch:
		v.y = -v.y
	return v.limit_length(1.0)
