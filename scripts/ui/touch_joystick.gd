class_name TouchJoystick
extends Control
## Çoklu dokunmatik destekli sanal joystick. Bu Control'ün alanı içinde nereye dokunulursa
## merkez orası olur (dinamik merkez); parmak sürüklendikçe değer -1..1 aralığında üretilir.
## value: x = sağ (+), y = yukarı (+).

@export var radius: float = 120.0
@export_range(0.0, 0.5, 0.01) var dead_zone: float = 0.06
## Dokunulmadığında joystick'in gösterildiği yer (alanın içinde, 0..1 oranı).
@export var rest_anchor: Vector2 = Vector2(0.35, 0.65)
@export var base_color: Color = Color(1, 1, 1, 0.12)
@export var ring_color: Color = Color(1, 1, 1, 0.35)
@export var knob_color: Color = Color(1, 1, 1, 0.7)

var value: Vector2 = Vector2.ZERO

var _touch_index: int = -1
var _center: Vector2
var _knob: Vector2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset()
	resized.connect(_reset)


func is_active() -> bool:
	return _touch_index >= 0


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and _touch_index < 0 and get_global_rect().has_point(touch.position):
			_touch_index = touch.index
			_center = touch.position - global_position
			_knob = _center
			_update_value()
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _touch_index:
			_knob = drag.position - global_position
			_update_value()
			get_viewport().set_input_as_handled()


func _update_value() -> void:
	var offset: Vector2 = (_knob - _center).limit_length(radius)
	_knob = _center + offset
	var v: Vector2 = offset / radius
	var length: float = v.length()
	if length < dead_zone:
		value = Vector2.ZERO
	else:
		# Ölü bölge sonrası 0'dan yeniden ölçeklenir: küçük hareketler kaybolmaz
		value = v / length * ((length - dead_zone) / (1.0 - dead_zone))
	value.y = -value.y
	queue_redraw()


func _reset() -> void:
	_touch_index = -1
	_center = size * rest_anchor
	_knob = _center
	value = Vector2.ZERO
	queue_redraw()


func _notification(what: int) -> void:
	# Uygulama arka plana giderse ya da odak kaybolursa joystick takılı kalmasın
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		_reset()


func _draw() -> void:
	var active: bool = is_active()
	draw_circle(_center, radius, base_color if active else Color(base_color, base_color.a * 0.6))
	draw_arc(_center, radius, 0.0, TAU, 64, ring_color, 3.0, true)
	draw_circle(_knob, radius * 0.38, knob_color if active else Color(knob_color, knob_color.a * 0.5))
