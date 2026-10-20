class_name Hud
extends CanvasLayer
## Test alanı arayüzü: joystick, fırlat/patlat, füze seçimi, kontrol modu ve telemetri.
## Oyun mantığı bilmez; sinyal yayınlar ve kendisine verilen değerleri gösterir.

signal fire_pressed
signal detonate_pressed
signal missile_selected(index: int)
signal control_mode_toggled
signal calibrate_pressed

enum Mode { READY, FLYING, AFTERMATH }

@export var joystick: TouchJoystick
@export var fire_button: TouchButton
@export var detonate_button: TouchButton
@export var control_button: TouchButton
@export var calibrate_button: TouchButton
@export var missile_list: VBoxContainer
@export var missile_name: Label
@export var missile_description: Label
@export var status_label: Label
@export var speed_label: Label
@export var altitude_label: Label
@export var time_label: Label
@export var target_label: Label
@export var fuel_bar: ProgressBar
@export var telemetry_panel: Control
@export var warning_label: Label

var _missile_buttons: Array[TouchButton] = []
var _message_timer: SceneTreeTimer


func _ready() -> void:
	fire_button.pressed.connect(fire_pressed.emit)
	detonate_button.pressed.connect(detonate_pressed.emit)
	control_button.pressed.connect(control_mode_toggled.emit)
	calibrate_button.pressed.connect(calibrate_pressed.emit)
	refresh_control_mode()


func set_missiles(definitions: Array[MissileDefinition]) -> void:
	for b: TouchButton in _missile_buttons:
		b.queue_free()
	_missile_buttons.clear()
	for i: int in definitions.size():
		var button := TouchButton.new()
		button.text = definitions[i].display_name
		button.font_size = 22
		button.custom_minimum_size = Vector2(210, 64)
		button.pressed.connect(missile_selected.emit.bind(i))
		missile_list.add_child(button)
		_missile_buttons.append(button)


func set_selected(index: int, definition: MissileDefinition) -> void:
	for i: int in _missile_buttons.size():
		_missile_buttons[i].selected = i == index
	missile_name.text = definition.display_name
	missile_description.text = definition.description


func set_mode(mode: Mode) -> void:
	fire_button.visible = mode == Mode.READY
	missile_list.visible = mode == Mode.READY
	missile_description.visible = mode == Mode.READY
	detonate_button.visible = mode == Mode.FLYING
	if mode != Mode.FLYING:
		set_warning("")
	telemetry_panel.modulate.a = 1.0 if mode == Mode.FLYING else 0.55


func refresh_control_mode() -> void:
	var gyro: bool = UserSettings.control_mode == UserSettings.ControlMode.GYRO
	control_button.text = "Kontrol:\nJİROSKOP" if gyro else "Kontrol:\nJOYSTICK"
	calibrate_button.visible = gyro
	joystick.visible = not gyro


## Sürekli gösterilen uyarı (ör. sınır dışı); boş metin gizler.
func set_warning(text: String) -> void:
	warning_label.text = text
	warning_label.visible = text != ""


func show_message(text: String, seconds: float = 2.5) -> void:
	status_label.text = text
	status_label.visible = text != ""
	if seconds > 0.0:
		_message_timer = get_tree().create_timer(seconds)
		var timer: SceneTreeTimer = _message_timer
		timer.timeout.connect(func() -> void:
			if _message_timer == timer:
				status_label.visible = false)


func update_telemetry(speed_ms: float, altitude: float, fuel_ratio: float, flight_time: float, target_distance: float) -> void:
	speed_label.text = "%d km/sa" % roundi(speed_ms * 3.6)
	altitude_label.text = "%d m" % roundi(altitude)
	time_label.text = "%.1f s" % flight_time
	fuel_bar.value = fuel_ratio * 100.0
	target_label.text = ("%.2f km" % (target_distance / 1000.0)) if target_distance >= 1000.0 else ("%d m" % roundi(target_distance))
