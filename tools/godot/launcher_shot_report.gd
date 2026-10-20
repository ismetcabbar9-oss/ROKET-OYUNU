extends Node
## Geliştirme aracı: her rampanın her kamera çekimini (mekanizma o aşamanın pozunda) çizer,
## draw call / üçgen sayısını yazdırır ve isteğe bağlı ekran görüntüsü alır. Mobil bütçe raporu için.
##   xvfb-run godot --path . --fixed-fps 60 res://tools/godot/launcher_shot_report.tscn -- [çıktı_öneki|-] [gölge_mesafesi]
## gölge_mesafesi verilirse güneşin gölge menzili denemelik olarak değiştirilir (ayar denemesi için).
## (Ekran görüntüsü istenmezse de gerçek render gerekir: --headless çizim sayısı vermez.)

const LEVEL: String = "res://scenes/levels/level_01.tscn"
const SETTLE_FRAMES: int = 12
## Aşama -> (hazırlık, kaldırma, kilit) pozu
const POSES: Dictionary = {
	Launcher.Stage.READY: Vector3(0, 0, 0),
	Launcher.Stage.PREPARE: Vector3(0.6, 0, 0),
	Launcher.Stage.RAISE: Vector3(1, 0.5, 0),
	Launcher.Stage.LOCK: Vector3(1, 1, 0.5),
	Launcher.Stage.IGNITE: Vector3(1, 1, 1),
	Launcher.Stage.RELEASE: Vector3(1, 1, 1),
}

var _controller: TestRangeController
var _prefix: String = ""
var _jobs: Array[Vector2i] = []   # (rampa, aşama)
var _frame: int = 0
var _worst: Vector2i = Vector2i.ZERO


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_prefix = args[0] if args.size() > 0 and args[0] != "-" else ""
	_controller = (load(LEVEL) as PackedScene).instantiate() as TestRangeController
	add_child(_controller)
	if args.size() > 1:
		for node: Node in _controller.find_children("*", "DirectionalLight3D", true, false):
			(node as DirectionalLight3D).directional_shadow_max_distance = float(args[1])
	for li: int in _controller.launchers.size():
		for stage: int in POSES.keys():
			_jobs.append(Vector2i(li, stage))


func _process(_delta: float) -> void:
	_frame += 1
	if _jobs.is_empty():
		print("EN AĞIR: draw_call=%d üçgen=%d" % [_worst.x, _worst.y])
		get_tree().quit()
		return
	var job: Vector2i = _jobs[0]
	if _frame == 1:
		_setup(job)
	elif _frame >= SETTLE_FRAMES:
		_measure(job)
		_jobs.pop_front()
		_frame = 0


func _setup(job: Vector2i) -> void:
	if _controller.selected_launcher != job.x:
		_controller.select_launcher(job.x)
	var launcher: Launcher = _controller.launchers[job.x]
	var pose: Vector3 = POSES[job.y]
	launcher._apply_pose(pose.x, pose.y, pose.z)
	var shot: LauncherCameraShot = launcher.definition.get_shot(job.y)
	var xform: Transform3D = launcher.global_transform
	var look: Vector3 = xform * shot.look_at
	if shot.track_missile:
		# Çıkış çekimleri füzeyi izler; raporda rampanın biraz üstüne bakılır
		look = launcher.cradle.global_position + Vector3.UP * 12.0
	_controller.camera.play_shot(xform * shot.position, look, shot.fov, 0.0)


func _measure(job: Vector2i) -> void:
	var launcher: Launcher = _controller.launchers[job.x]
	var draws: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var stage_name: String = Launcher.Stage.keys()[job.y]
	var flag: String = "  << BÜTÇE AŞIMI" if draws > 150 or prims > 400000 else ""
	print("%-11s %-8s draw_call=%3d üçgen=%6d%s" % [launcher.definition.display_name, stage_name, draws, prims, flag])
	_worst = Vector2i(maxi(_worst.x, draws), maxi(_worst.y, prims))
	if _prefix != "":
		get_viewport().get_texture().get_image().save_png("%s_%s_%s.png" % [_prefix, launcher.definition.id, stage_name.to_lower()])
