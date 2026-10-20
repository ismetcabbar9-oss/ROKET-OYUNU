extends SceneTree
## Geliştirme aracı: içe aktarılmış bir glTF'i mobil için hazır bir sahne nesnesine "pişirir".
##  - Tüm görünür parçaları malzeme başına tek yüzeyde birleştirir (parça sayısı kadar draw call olmaz)
##  - İsteğe bağlı: yalnızca belirli düğümleri al (paketten tek nesne ayırmak için)
##  - İsteğe bağlı: üçgen sayısını hedefe indir (Godot'un LOD üreticisiyle), LOD'ları da üretir
##  - Ölçeği metreye çevirir, tabanı y=0'a ve merkezi orijine oturtur
##  - Çıktı: <çıktı_klasörü>/<isim>_mesh.res ve scenes/props/<isim>.tscn (isteğe bağlı kutu çarpışması)
##
##   godot --headless --path . -s res://tools/godot/bake_prop.gd -- <kaynak.gltf> <isim> <boyut_m> <eksen:x|y|z|max> \
##       [--keep=ad1,ad2] [--hide=ad1,ad2] [--tris=N] [--yaw=derece] [--collision] [--layer=N] [--no-shadow]
##       [--color=r,g,b]   (dokusuz modellere düz renkli malzeme)
##       [--lods]          (çalışma zamanı LOD'ları üret; varsayılan kapalı: kaba LOD'lar gölge
##                          geçişinde kullanılıp nesnenin kendi üstüne gölge düşürüyor)

const SCENE_DIR: String = "res://scenes/props"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 4:
		push_error("eksik argüman")
		quit(1)
		return
	var src: String = args[0]
	var prop_name: String = args[1]
	var target_size: float = float(args[2])
	var axis: String = args[3]
	var opts: Dictionary = _parse_options(args.slice(4))

	var model: Node3D = (load(src) as PackedScene).instantiate() as Node3D
	root.add_child(model)

	# Malzeme başına bir SurfaceTool
	var tools: Dictionary = {}  # Material -> SurfaceTool
	var order: Array[Material] = []
	var no_material := StandardMaterial3D.new()
	var parts: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if not _selected(mi, model, opts):
			continue
		parts += 1
		var xform: Transform3D = _relative_transform(model, mi)
		for s: int in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			if mat == null:
				mat = no_material
			if not tools.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(mat)
				tools[mat] = st
				order.append(mat)
			(tools[mat] as SurfaceTool).append_from(mi.mesh, s, xform)
	if parts == 0:
		push_error("seçilen parça yok")
		quit(1)
		return

	var merged := ArrayMesh.new()
	for mat: Material in order:
		(tools[mat] as SurfaceTool).commit(merged)

	# Normalizasyon: yaw, ölçek, taban y=0, merkez orijin
	var yaw := Basis(Vector3.UP, deg_to_rad(float(opts.get("yaw", "0"))))
	var aabb: AABB = Transform3D(yaw, Vector3.ZERO) * merged.get_aabb()
	var extent: float
	match axis:
		"x": extent = aabb.size.x
		"y": extent = aabb.size.y
		"z": extent = aabb.size.z
		_: extent = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	var k: float = target_size / extent
	var center: Vector3 = aabb.get_center()
	var offset := Vector3(-center.x, -aabb.position.y, -center.z) * k
	var normalize := Transform3D(yaw.scaled(Vector3.ONE * k), offset)

	var importer := ImporterMesh.new()
	var total_tris: int = 0
	for s: int in merged.get_surface_count():
		var st := SurfaceTool.new()
		st.append_from(merged, s, normalize)
		st.set_material(merged.surface_get_material(s))
		var arrays: Array = _strip_unused(st.commit_to_arrays())
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, merged.surface_get_material(s))
		total_tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arrays[Mesh.ARRAY_INDEX] != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	# Üçgen azaltma için LOD'lar her durumda geçici olarak üretilir
	importer.generate_lods(25.0, 60.0, [])

	var target_tris: int = int(opts.get("tris", "0"))
	if target_tris > 0 and total_tris > target_tris:
		importer = _reduce(importer, float(target_tris) / total_tris)

	if not opts.has("lods"):
		importer = _without_lods(importer)
	var mesh: ArrayMesh = importer.get_mesh()
	var out_dir: String = src.get_base_dir()
	var mesh_path: String = "%s/%s_mesh.res" % [out_dir, prop_name]
	ResourceSaver.save(mesh, mesh_path, ResourceSaver.FLAG_COMPRESS)
	var final_tris: int = 0
	for s: int in mesh.get_surface_count():
		final_tris += mesh.surface_get_array_index_len(s) / 3
	var size: Vector3 = mesh.get_aabb().size
	print("%s: parça=%d yüzey=%d üçgen %d -> %d boyut=%s" % [prop_name, parts, mesh.get_surface_count(), total_tris, final_tris, size.snapped(Vector3.ONE * 0.01)])

	_save_scene(prop_name, load(mesh_path) as Mesh, opts)
	quit()


## Oyunda kullanılmayan kanallar (özel veri, kemik, ağırlık) atılır; bazı modellerde
## birleştirme sonrası yanlış türe dönüşüp yüzey oluşturmayı bozuyorlar.
func _strip_unused(arrays: Array) -> Array:
	for i: int in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
		arrays[i] = null
	return arrays


func _parse_options(raw: PackedStringArray) -> Dictionary:
	var opts: Dictionary = {}
	for a: String in raw:
		if not a.begins_with("--"):
			continue
		var kv: PackedStringArray = a.substr(2).split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return opts


func _selected(mi: MeshInstance3D, model: Node3D, opts: Dictionary) -> bool:
	if mi.mesh == null:
		return false
	var path: String = str(model.get_path_to(mi))
	if opts.has("keep"):
		var found: bool = false
		for key: String in (opts["keep"] as String).split(","):
			if path.contains(key):
				found = true
		if not found:
			return false
	if opts.has("hide"):
		for key: String in (opts["hide"] as String).split(","):
			if path.contains(key):
				return false
	return mi.is_visible_in_tree()


## Her yüzeyde, üçgen oranı hedefe en yakın (altında kalan) LOD'u taban ağ yapar ve LOD'ları yeniden üretir.
func _reduce(src: ImporterMesh, ratio: float) -> ImporterMesh:
	var out := ImporterMesh.new()
	for s: int in src.get_surface_count():
		var arrays: Array = src.get_surface_arrays(s)
		var base_count: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
		var best: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for l: int in src.get_surface_lod_count(s):
			var idx: PackedInt32Array = src.get_surface_lod_indices(s, l)
			best = idx
			if float(idx.size()) / base_count <= ratio:
				break
		arrays[Mesh.ARRAY_INDEX] = best
		out.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, src.get_surface_material(s))
	out.generate_lods(25.0, 60.0, [])
	return out


func _without_lods(src: ImporterMesh) -> ImporterMesh:
	var out := ImporterMesh.new()
	for s: int in src.get_surface_count():
		out.add_surface(Mesh.PRIMITIVE_TRIANGLES, src.get_surface_arrays(s), [], {}, src.get_surface_material(s))
	return out


func _relative_transform(ancestor: Node3D, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != ancestor and current is Node3D:
		xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform


func _save_scene(prop_name: String, mesh: Mesh, opts: Dictionary) -> void:
	var root_node: Node3D
	if opts.has("collision"):
		var body := StaticBody3D.new()
		body.collision_layer = int(opts.get("layer", "2"))
		body.collision_mask = 0
		root_node = body
	else:
		root_node = Node3D.new()
	root_node.name = prop_name.to_pascal_case()
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	if opts.has("no-shadow"):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if opts.has("color"):
		var c: PackedFloat64Array = (opts["color"] as String).split_floats(",")
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(c[0], c[1], c[2])
		mat.roughness = 0.75
		mi.material_override = mat
	root_node.add_child(mi)
	mi.owner = root_node
	if opts.has("collision"):
		var aabb: AABB = mesh.get_aabb()
		var shape := BoxShape3D.new()
		shape.size = aabb.size
		var col := CollisionShape3D.new()
		col.name = "Collision"
		col.shape = shape
		col.position = aabb.get_center()
		root_node.add_child(col)
		col.owner = root_node
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCENE_DIR))
	var packed := PackedScene.new()
	packed.pack(root_node)
	ResourceSaver.save(packed, "%s/%s.tscn" % [SCENE_DIR, prop_name])
	root_node.free()
