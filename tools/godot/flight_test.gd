extends Node
## Geliştirme aracı: test alanını açar, seçilen füzeyi seçilen rampadan fırlatır (tam fırlatma
## dizisiyle), basit bir otopilotla hedefe uçurur, telemetriyi yazdırır ve istenen karelerde
## ekran görüntüsü alır. (Autoload'lar yüklensin diye -s ile değil sahne olarak çalıştırılır.)
##   godot --path . --fixed-fps 60 res://tools/godot/flight_test.tscn -- <füze_no> <çıktı_öneki> [kare,...] [ateşleme=1|0] [rampa_no]
## Rampa no: 0 Mobil TEL, 1 Eğik Ray, 2 Dikey Silo (füzeyle uyumsuzsa uyumlu rampa seçilir).
## Ekran görüntüsü istenmezse --headless ile hızlı çalışır.

const LEVEL: String = "res://scenes/levels/level_01.tscn"
const FIRE_FRAME: int = 40


class Autopilot extends SteerInput:
	## Vadi orta çizgisini ve sırttaki kanyonu izleyen basit ara nokta takipçisi.
	var missile: Missile
	var waypoints: Array[Vector3] = []
	var _next: int = 0

	func build_route(shape: TerrainShape, aim: Vector3) -> void:
		for z: float in [650.0, 480.0, 300.0, 150.0]:
			waypoints.append(_valley_point(shape, z, 0.0, 30.0))
		# Kanyon geçidi: sırtın önünde, içinde ve arkasında alçak uç
		for z: float in [110.0, 40.0, -30.0]:
			waypoints.append(_valley_point(shape, z, shape.canyon_offset, 18.0))
		for z: float in [-180.0, -350.0, -500.0]:
			waypoints.append(_valley_point(shape, z, 0.0, 30.0))
		waypoints.append(aim)

	func _valley_point(shape: TerrainShape, z: float, offset: float, height: float) -> Vector3:
		var x: float = shape.get_valley_center_x(z) + offset
		return Vector3(x, shape.get_height(x, z) + height, z)

	func get_steer() -> Vector2:
		if not is_instance_valid(missile):
			return Vector2.ZERO
		var pos: Vector3 = missile.global_position
		# Hızlı füzeler ara noktaya daha erken döner (dönüş yarıçapı büyük)
		var lead: float = 15.0 + missile.get_speed() * 0.9
		while _next < waypoints.size() - 1 and pos.z < waypoints[_next].z + lead:
			_next += 1
		var dir: Vector3 = (waypoints[_next] - pos).normalized()
		var forward: Vector3 = missile.get_forward()
		var right: Vector3 = forward.cross(Vector3.UP).normalized()
		var up: Vector3 = right.cross(forward).normalized()
		return Vector2(dir.dot(right), dir.dot(up)).limit_length(1.0) * 2.5


var _frame: int = 0
var _shots: PackedInt32Array = []
var _prefix: String
var _missile_index: int = 0
var _controller: TestRangeController
var _pilot := Autopilot.new()
var _done_frame: int = -1
var _logged_detonation: bool = false
var _fire: bool = true
var _launcher_index: int = -1
var _launched: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_missile_index = int(args[0]) if args.size() > 0 else 0
	_prefix = args[1] if args.size() > 1 else "/tmp/flight"
	if args.size() > 2:
		for f: String in args[2].split(",", false):
			_shots.append(int(f))
	_fire = args.size() <= 3 or args[3] != "0"
	_launcher_index = int(args[4]) if args.size() > 4 else -1
	var level: Node = (load(LEVEL) as PackedScene).instantiate()
	add_child(level)
	_controller = level as TestRangeController
	_controller.missile_launched.connect(_on_launched)


func _on_launched(missile: Missile) -> void:
	_launched = true
	print("FIRLATMA karesi=", _frame, " rampa=", _controller.launchers[_controller.selected_launcher].definition.display_name)
	_pilot.missile = missile
	_pilot.build_route(_controller.terrain_shape, _controller.target_point.global_position + Vector3(34, 2, -18))
	missile.steer_source = _pilot
	add_child(_pilot)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 2:
		if _launcher_index >= 0:
			_controller.select_launcher(_launcher_index)
		_controller.select_missile(_missile_index)
	if _frame == FIRE_FRAME and _fire:
		_controller.fire()
	if _launched and _frame % 30 == 0 and is_instance_valid(_pilot.missile):
		var m: Missile = _pilot.missile
		print("t=%.1fs pos=%s hız=%.0f km/sa yakıt=%.0f%% hedefe=%.0f m" % [m.get_flight_time(), m.global_position.round(), m.get_speed() * 3.6, m.get_fuel_ratio() * 100.0, m.global_position.distance_to(_pilot.waypoints[_pilot.waypoints.size() - 1])])
	if _launched and not is_instance_valid(_pilot.missile) and not _logged_detonation:
		_logged_detonation = true
		_done_frame = _frame
		print("PATLAMA karesi=", _frame, " durum=", _controller.hud.status_label.text)
	if _shots.has(_frame) and DisplayServer.get_name() != "headless":
		var path: String = "%s_%04d.png" % [_prefix, _frame]
		get_viewport().get_texture().get_image().save_png(path)
		var draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var prims: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		print("görüntü: ", path, " draw_call=", draws, " üçgen=", prims)
	var last_shot: int = _shots[_shots.size() - 1] if not _shots.is_empty() else 0
	var finished: bool = _done_frame > 0 and _frame > _done_frame + 260
	var shots_done: bool = not _shots.is_empty() and _frame > last_shot
	if shots_done or (finished or not _fire) and _frame > last_shot or _frame > 3600:
		get_tree().quit()
