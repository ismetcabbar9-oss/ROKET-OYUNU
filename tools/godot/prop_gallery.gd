extends Node3D
## Geliştirme aracı: scenes/props altındaki tüm nesneleri yan yana dizer (ölçek/görünüm kontrolü).


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	add_child(ground)
	var x: float = 0.0
	for file: String in DirAccess.get_files_at("res://scenes/props"):
		if not file.ends_with(".tscn"):
			continue
		var node: Node3D = (load("res://scenes/props/" + file) as PackedScene).instantiate() as Node3D
		add_child(node)
		var width: float = 8.0
		for mi: Node in node.find_children("*", "MeshInstance3D", true, false):
			width = maxf(width, (mi as MeshInstance3D).get_aabb().size.x)
		node.position = Vector3(x + width * 0.5, 0.0, 0.0)
		print(file, " x=", snappedf(x + width * 0.5, 0.1))
		x += width + 3.0
