@tool
class_name TouchButton
extends Control
## Çoklu dokunmatikle çalışan buton (joystick basılıyken ikinci parmakla basılabilir).
## Godot'nun standart Button'ı yalnızca ilk parmağı fare olarak algıladığı için gerekli.

signal pressed

@export var text: String = "":
	set(v):
		text = v
		queue_redraw()
@export var font_size: int = 26:
	set(v):
		font_size = v
		queue_redraw()
@export var round_shape: bool = false:
	set(v):
		round_shape = v
		queue_redraw()
@export var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()
@export var fill_color: Color = Color(0.08, 0.1, 0.12, 0.62)
@export var selected_color: Color = Color(0.85, 0.42, 0.12, 0.85)
@export var pressed_color: Color = Color(1.0, 0.55, 0.2, 0.95)
@export var border_color: Color = Color(1, 1, 1, 0.45)
@export var text_color: Color = Color(1, 1, 1, 0.95)

var _touch_index: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and _touch_index < 0 and _hit(touch.position):
			_touch_index = touch.index
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			queue_redraw()
			get_viewport().set_input_as_handled()
			if _hit(touch.position):
				pressed.emit()


func _hit(point: Vector2) -> bool:
	var rect: Rect2 = get_global_rect()
	if round_shape:
		return point.distance_to(rect.get_center()) <= minf(rect.size.x, rect.size.y) * 0.5
	return rect.grow(8.0).has_point(point)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_touch_index = -1


func _draw() -> void:
	var color: Color = pressed_color if _touch_index >= 0 else (selected_color if selected else fill_color)
	var rect := Rect2(Vector2.ZERO, size)
	if round_shape:
		var r: float = minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, color)
		draw_arc(size * 0.5, r - 1.5, 0.0, TAU, 64, border_color, 3.0, true)
	else:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.border_color = border_color
		box.set_border_width_all(2)
		box.set_corner_radius_all(12)
		box.anti_aliasing = true
		draw_style_box(box, rect)
	var font: Font = get_theme_default_font()
	var lines: PackedStringArray = text.split("\n")
	var line_h: float = font.get_height(font_size)
	var y: float = (size.y - line_h * lines.size()) * 0.5 + font.get_ascent(font_size)
	for line: String in lines:
		draw_string(font, Vector2(0.0, y), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, text_color)
		y += line_h
