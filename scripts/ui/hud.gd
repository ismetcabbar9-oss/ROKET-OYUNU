class_name Hud
extends CanvasLayer
## Test alanı arayüzü: joystick, fırlat/atla/patlat, füze ve rampa seçimi, kontrol modu, telemetri.
## Oyun mantığı bilmez; sinyal yayınlar ve kendisine verilen değerleri gösterir.

signal fire_pressed
## Fırlatma dizisi sürerken FIRLAT butonu "ATLA" olur.
signal skip_pressed
signal detonate_pressed
signal missile_selected(index: int)
signal launcher_selected(index: int)
signal control_mode_toggled
signal calibrate_pressed

enum Mode { READY, LAUNCHING, FLYING, AFTERMATH }

@export var joystick: TouchJoystick
@export var fire_button: TouchButton
@export var detonate_button: TouchButton
@export var control_button: TouchButton
@export var calibrate_button: TouchButton
@export var missile_list: VBoxContainer
@export var launcher_list: VBoxContainer
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
var _launcher_buttons: Array[TouchButton] = []
var _message_timer: SceneTreeTimer
var _mode: Mode = Mode.READY


func _ready() -> void:
	fire_button.pressed.connect(_on_fire_button)
	detonate_button.pressed.connect(detonate_pressed.emit)
	control_button.pressed.connect(control_mode_toggled.emit)
	calibrate_button.pressed.connect(calibrate_pressed.emit)
	refresh_control_mode()


func set_missiles(definitions: Array[MissileDefinition]) -> void:
	var names: PackedStringArray = []
	for d: MissileDefinition in definitions:
		names.append(d.display_name)
	_missile_buttons = _fill_list(missile_list, _missile_buttons, names, missile_selected, 64)


func set_launchers(definitions: Array[LauncherDefinition]) -> void:
	var names: PackedStringArray = []
	for d: LauncherDefinition in definitions:
		names.append(d.display_name)
	_launcher_buttons = _fill_list(launcher_list, _launcher_buttons, names, launcher_selected, 56)


## Seçili füze ve rampayı gösterir; seçili rampayla atılamayan füzeler soluk görünür.
func set_selection(missile_index: int, missile: MissileDefinition, launcher_index: int,
		launcher: LauncherDefinition, compatible: Array[bool]) -> void:
	for i: int in _missile_buttons.size():
		_missile_buttons[i].selected = i == missile_index
		_missile_buttons[i].modulate.a = 1.0 if compatible[i] else 0.45
	for i: int in _launcher_buttons.size():
		_launcher_buttons[i].selected = i == launcher_index
	missile_name.text = "%s  ·  %s" % [missile.display_name, launcher.display_name]
	missile_description.text = "%s\n%s" % [missile.description, launcher.description]


func set_mode(mode: Mode) -> void:
	_mode = mode
	fire_button.visible = mode == Mode.READY or mode == Mode.LAUNCHING
	fire_button.text = "ATLA" if mode == Mode.LAUNCHING else "FIRLAT"
	missile_list.visible = mode == Mode.READY
	launcher_list.visible = mode == Mode.READY
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


func _on_fire_button() -> void:
	if _mode == Mode.LAUNCHING:
		skip_pressed.emit()
	else:
		fire_pressed.emit()


func _fill_list(list: VBoxContainer, old: Array[TouchButton], names: PackedStringArray, on_press: Signal, height: float) -> Array[TouchButton]:
	for b: TouchButton in old:
		b.queue_free()
	var buttons: Array[TouchButton] = []
	for i: int in names.size():
		var button := TouchButton.new()
		button.text = names[i]
		button.font_size = 22
		button.custom_minimum_size = Vector2(210, height)
		button.pressed.connect(on_press.emit.bind(i))
		list.add_child(button)
		buttons.append(button)
	return buttons


func update_telemetry(speed_ms: float, altitude: float, fuel_ratio: float, flight_time: float, target_distance: float) -> void:
	speed_label.text = "%d km/sa" % roundi(speed_ms * 3.6)
	altitude_label.text = "%d m" % roundi(altitude)
	time_label.text = "%.1f s" % flight_time
	fuel_bar.value = fuel_ratio * 100.0
	target_label.text = ("%.2f km" % (target_distance / 1000.0)) if target_distance >= 1000.0 else ("%d m" % roundi(target_distance))
