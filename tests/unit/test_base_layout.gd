extends GutTest
## Üs yerleşimi: sahne yüklenir, beklenen bölgeler ve MultiMesh'ler var, nesneler zeminde.

const LAYOUT: String = "res://scenes/levels/valley_01/base_layout.tscn"


func test_layout_has_zones() -> void:
	var layout: Node = (load(LAYOUT) as PackedScene).instantiate()
	for group: String in ["LaunchBase", "ServiceArea", "Outpost", "Compound", "Roadside", "Instanced", "Collisions"]:
		assert_not_null(layout.get_node_or_null(group), group)
	layout.free()


func test_multimeshes_exist() -> void:
	# Not: örnek konumları headless'ta okunamaz (sahte render sunucusu MultiMesh verisini tutmaz);
	# o doğrulamayı build_base_layout.gd üretim sırasında yapar.
	var layout: Node = (load(LAYOUT) as PackedScene).instantiate()
	var count: int = 0
	for node: Node in layout.get_node("Instanced").get_children():
		var mmi: MultiMeshInstance3D = node as MultiMeshInstance3D
		assert_not_null(mmi.multimesh, mmi.name)
		assert_gt(mmi.multimesh.instance_count, 0, mmi.name)
		assert_gt(mmi.visibility_range_end, 0.0, "%s uzakta kesilmeli" % mmi.name)
		count += 1
	assert_gt(count, 10)
	layout.free()


func test_props_sit_on_ground() -> void:
	var shape: TerrainShape = load("res://config/terrain/valley_01.tres") as TerrainShape
	var layout: Node = (load(LAYOUT) as PackedScene).instantiate()
	for group: String in ["LaunchBase", "ServiceArea", "Compound", "Outpost"]:
		for node: Node in layout.get_node(group).get_children():
			var p: Vector3 = (node as Node3D).position
			assert_almost_eq(p.y, shape.get_height(p.x, p.z), 0.5, "%s/%s zeminde" % [group, node.name])
	layout.free()
