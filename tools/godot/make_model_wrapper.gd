extends SceneTree
## Geliştirme aracı: içe aktarılmış bir glTF'i oyunun beklediği yönelim ve ölçeğe getiren
## bir sarmalayıcı sahne (.tscn) üretir. Burun -Z yönünde, merkez orijinde, boy metre cinsinden.
##   godot --headless --path . -s res://tools/godot/make_model_wrapper.gd -- \
##       <kaynak.gltf> <çıktı.tscn> <boy_m> <uzun_eksen:x|y|z> <burun:+|-> [gizlenecek düğüm adları...]
## "burun" kaynak modelde burnun uzun eksenin hangi yönünde olduğunu söyler.
## "--ground" verilirse model ortalanmak yerine tabanı orijine (y=0) oturtulur (sahne nesneleri için).


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 5:
		push_error("eksik argüman")
		quit(1)
		return
	var source: PackedScene = load(args[0]) as PackedScene
	var out_path: String = args[1]
	var length: float = float(args[2])
	var axis: String = args[3]
	var nose_positive: bool = args[4] == "+"
	var hidden: PackedStringArray = args.slice(5)
	var ground: bool = hidden.has("--ground")
	if ground:
		hidden.remove_at(hidden.find("--ground"))

	var root_node := Node3D.new()
	root_node.name = out_path.get_file().get_basename().to_pascal_case()
	var model: Node3D = source.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	model.name = "Model"
	root_node.add_child(model)
	model.owner = root_node

	var overrides: String = ""
	for hide_name: String in hidden:
		var target: Node = model.find_child(hide_name, true, false)
		if target is Node3D:
			(target as Node3D).visible = false
			var parent_path: String = "Model/" + str(model.get_path_to(target.get_parent()))
			overrides += "\n[node name=\"%s\" parent=\"%s\" index=\"%d\"]\nvisible = false\n" % [
				target.name, parent_path.trim_suffix("/."), target.get_index()]
			print("gizlendi: ", target.name)
		else:
			push_error("bulunamadı: " + hide_name)

	# Görünür ağların birleşik AABB'si (model uzayında)
	var aabb := AABB()
	var first: bool = true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if not _visible_under(model, mi):
			continue
		var box: AABB = _relative_transform(model, mi) * mi.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false

	# Uzun ekseni -Z'ye (burun yönü) çeviren dönüş
	var nose_dir: Vector3 = {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}[axis]
	if not nose_positive:
		nose_dir = -nose_dir
	var rot := Basis(Quaternion(nose_dir, Vector3.FORWARD))
	var extent: float = aabb.size[{"x": 0, "y": 1, "z": 2}[axis]]
	var scale_factor: float = length / extent
	var basis: Basis = rot.scaled(Vector3.ONE * scale_factor)
	var center: Vector3 = aabb.get_center()
	var offset: Vector3 = -(basis * center)
	if ground:
		var rotated: AABB = Transform3D(basis, offset) * aabb
		offset.y -= rotated.position.y
	model.transform = Transform3D(basis, offset)

	var packed := PackedScene.new()
	packed.pack(root_node)
	var err: Error = ResourceSaver.save(packed, out_path)
	if overrides != "":
		# Örnek sahnenin alt düğümü için yalnızca görünürlük geçersiz kılması (veri gömmeden).
		var file := FileAccess.open(out_path, FileAccess.READ_WRITE)
		file.seek_end()
		file.store_string(overrides)
		file.close()
	print("kaydedildi: ", out_path, " err=", err, " ölçek=", scale_factor, " aabb=", aabb)
	root_node.free()
	quit()


func _relative_transform(ancestor: Node3D, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != ancestor and current is Node3D:
		xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform


func _visible_under(ancestor: Node3D, node: Node3D) -> bool:
	var current: Node = node
	while current != null:
		if current is Node3D and not (current as Node3D).visible:
			return false
		if current == ancestor:
			return true
		current = current.get_parent()
	return true
