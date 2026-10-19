extends SceneTree
## Geliştirme aracı: bir sahneyi açıp ekran görüntüsü alır (oyuna dahil değildir).
##   godot --path . -s res://tools/godot/capture.gd -- <sahne> <çıktı.png> [kare_sayısı] [mod]
## mod "model": kamera/ışık ekler, modeli çerçeveler ve ağaç yapısını yazdırır.
## mod "cam:x,y,z:hx,hy,hz": verilen noktadan verilen hedefe bakan bir kamera ekler.

var _out: String
var _frames_left: int = 30
var _model_scene: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Kullanım: -- <sahne> <çıktı.png> [kare] [model]")
		quit(1)
		return
	_out = args[1]
	if args.size() > 2:
		_frames_left = int(args[2])
	var packed: PackedScene = load(args[0]) as PackedScene
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	if args.size() > 3 and args[3] == "model":
		_model_scene = scene
	elif args.size() > 3 and args[3].begins_with("cam:"):
		var parts: PackedStringArray = args[3].split(":")
		var cam := Camera3D.new()
		cam.far = 12000.0
		cam.fov = 70.0
		root.add_child(cam)
		var from: PackedFloat64Array = parts[1].split_floats(",")
		var to: PackedFloat64Array = parts[2].split_floats(",")
		cam.look_at_from_position(Vector3(from[0], from[1], from[2]), Vector3(to[0], to[1], to[2]))
		cam.current = true


func _process(_delta: float) -> bool:
	if _model_scene:
		_setup_model_view(_model_scene)
		_model_scene = null
	_frames_left -= 1
	if _frames_left > 0:
		return false
	var img: Image = root.get_texture().get_image()
	img.save_png(_out)
	print("Kaydedildi: ", _out, " ", img.get_size())
	quit()
	return true


func _setup_model_view(scene: Node) -> void:
	var aabb := AABB()
	var first: bool = true
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		var box: AABB = mi.global_transform * mi.get_aabb()
		print("  mesh: ", scene.get_path_to(mi), " aabb=", box, " surfaces=", mi.mesh.get_surface_count())
		aabb = box if first else aabb.merge(box)
		first = false
	print("TOPLAM AABB: ", aabb, " boyut=", aabb.size)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.4, 0.45)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	root.add_child(sun)

	var cam := Camera3D.new()
	var radius: float = aabb.size.length() * 0.5
	var center: Vector3 = aabb.get_center()
	root.add_child(cam)
	cam.position = center + Vector3(1.0, 0.6, 1.2).normalized() * radius * 2.2
	cam.look_at(center)
	cam.near = radius * 0.01
	cam.far = radius * 20.0
	cam.current = true
