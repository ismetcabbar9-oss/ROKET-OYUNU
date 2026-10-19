class_name TouchSteerInput
extends SteerInput
## Ekrandaki sanal joystick'ten yönlendirme okur.

@export var joystick: TouchJoystick


func get_steer() -> Vector2:
	if joystick == null:
		return Vector2.ZERO
	return _apply_user_settings(joystick.value, UserSettings.joystick_sensitivity)
