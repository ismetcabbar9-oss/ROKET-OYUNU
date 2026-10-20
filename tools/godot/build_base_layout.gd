extends SceneTree
## Geliştirme aracı: bölümün üs yerleşimini (yapılar, çitler, bariyerler, araçlar, kaya/çalı
## serpiştirmesi) TerrainShape'teki düz alanlara göre kurar ve tek bir sahne olarak kaydeder.
## DİKKAT: --headless ile ÇALIŞTIRMAYIN (sahte render sunucusu MultiMesh verisini saklamaz);
## ekransız ortamda xvfb-run kullanın.
##   godot --path . -s res://tools/godot/build_base_layout.gd -- \
##       res://config/terrain/valley_01.tres res://scenes/levels/valley_01/base_layout.tscn res://assets/terrain/valley_01/layout
##
## Mobil kuralları:
##  - Benzersiz yapılar tek tek örneklenir (kendi kutu çarpışmalarıyla).
##  - Tekrarlanan nesneler MultiMesh: tür + bölge başına tek draw call; uzakta görünmez olurlar.
##  - Çarpışması gereken MultiMesh nesneleri için bölge başına tek StaticBody + kutu şekilleri.
## Konumlar alanların yerel koordinatlarında: x = sağ, y = ileri (metre), açı = alanın yönüne göre.

const PROPS: String = "res://scenes/props/"
const SHRUB_TEXTURE: String = "res://assets/textures/fx/dry_shrub.png"
const FOLIAGE_SHADER: String = "res://shaders/foliage.gdshader"
const SLAB_TOP: Dictionary = {0: 0.0, 1: 0.14, 2: 0.10, 3: 0.05}
const FENCE_PANEL_LENGTH: float = 3.37

var _shape: TerrainShape
var _root: Node3D
var _groups: Dictionary = {}       # isim -> Node3D
var _mm: Dictionary = {}           # anahtar -> {mesh, xforms, vis_end, shadow}
var _boxes: Dictionary = {}        # bölge -> Array[[Transform3D, Vector3, int katman]]
var _mesh_cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _road_points := PackedVector2Array()


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_shape = load(args[0]) as TerrainShape
	var out_scene: String = args[1]
	var mm_dir: String = args[2]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(mm_dir))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_scene.get_base_dir()))
	for f: String in DirAccess.get_files_at(mm_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(mm_dir + "/" + f))
	_rng.seed = 20261020
	if not _shape.roads.is_empty():
		_road_points = _shape.get_road_profile(0)["points"]

	_root = Node3D.new()
	_root.name = "BaseLayout"
	_launch_base()
	_service_area()
	_fuel_depot()
	_outpost()
	_compound()
	_roadside()
	_scatter()
	_flush_multimeshes(mm_dir)
	_flush_collisions()
	if not _verify_multimeshes(mm_dir):
		push_error("MultiMesh verisi boş kaydedildi: aracı --headless ile değil, xvfb-run ile çalıştırın.")
		_root.free()
		quit(1)
		return

	var packed := PackedScene.new()
	packed.pack(_root)
	ResourceSaver.save(packed, out_scene)
	var instances: int = 0
	for g: Node in _groups.values():
		instances += g.get_child_count()
	print("yerleşim: %d grup, %d düğüm, %d MultiMesh" % [_groups.size(), instances, _mm.size()])
	_root.free()
	quit()


# --- Bölümler -------------------------------------------------------------------------------

func _launch_base() -> void:
	var z: TerrainFlatZone = _zone("Fırlatma pisti")
	_place("radar", z, Vector2(-36, -24), 20, "LaunchBase")
	_ring("sandbag_wall", z, Vector2(-36, -24), 7.5, 0.75, "base", 350.0, false)
	# Rampanın arkasında yarım daire kum torbası siperi
	_arc("sandbag_wall", z, Vector2(0, -2), 11.0, 200.0, 340.0, "base", 350.0)
	# Arka kenar ve yan kenarlarda beton bariyer hattı (ön taraf yola açık)
	_line("concrete_barrier", z, Vector2(-42, -36), Vector2(42, -36), 3.4, "base", 450.0, true)
	_line("concrete_barrier", z, Vector2(-48, -30), Vector2(-48, 20), 3.4, "base", 450.0, true, 90.0)
	for p: Vector2 in [Vector2(-47, -33), Vector2(-47, 31), Vector2(47, -33), Vector2(47, 31)]:
		_mm_add("street_light", _xform(z, p, 0.0 if p.x < 0 else 180.0), "base", 700.0, true)
	_place("ural_truck", z, Vector2(30, 18), 80, "LaunchBase")
	_place("humvee", z, Vector2(36, 8), 95, "LaunchBase")
	_place("humvee", z, Vector2(-30, 20), -60, "LaunchBase")


func _service_area() -> void:
	var z: TerrainFlatZone = _zone("Servis alanı")
	_place("hangar", z, Vector2(-8, 8), 0, "ServiceArea")
	_place("control_tower", z, Vector2(17, 29), 0, "ServiceArea")
	_place("bld_office", z, Vector2(2, -27), 0, "ServiceArea")
	_place("bld_garage", z, Vector2(17, 2), 90, "ServiceArea")
	_place("bld_small", z, Vector2(-18, -35), 0, "ServiceArea")
	_place("bld_booth", z, Vector2(22, -12), 0, "ServiceArea")
	_place("humvee", z, Vector2(13, -14), 90, "ServiceArea")
	_place("humvee", z, Vector2(9, -14), 90, "ServiceArea")
	for p: Vector2 in [Vector2(-26, -20), Vector2(-26, 20), Vector2(26, 14), Vector2(26, -30)]:
		_mm_add("street_light", _xform(z, p, 0.0 if p.x < 0 else 180.0), "base", 700.0, true)
	# Apron tarafında (sol) giriş boşluğu
	_fence_rect(z, 1.5, 3, 0.5, 18.0, "base")


func _fuel_depot() -> void:
	var z: TerrainFlatZone = _zone("Yakıt deposu")
	for p: Vector2 in [Vector2(-9, -7), Vector2(9, -7), Vector2(-9, 8), Vector2(9, 8)]:
		_mm_add("fuel_tank", _xform(z, p, 0.0), "base", 800.0, true, true)
	# Tankların çevresinde kum torbası seddi
	for side: Array in [[Vector2(-18, -17), Vector2(18, -17)], [Vector2(18, -17), Vector2(18, 18)],
			[Vector2(18, 18), Vector2(-18, 18)], [Vector2(-18, 18), Vector2(-18, -17)]]:
		_line("sandbag_wall", z, side[0], side[1], 2.5, "base", 350.0, false)
	_mm_add("container", _xform(z, Vector2(-22, -4), 90.0), "base", 800.0, true, true)
	# Pist tarafında (sağ) giriş boşluğu
	_fence_rect(z, 1.0, 1, 0.5, 12.0, "base")


func _outpost() -> void:
	var z: TerrainFlatZone = _zone("Yol karakolu")
	_place("checkpoint", z, Vector2(6, 0), 0, "Outpost")
	_place("watchtower", z, Vector2(-10, 14), 0, "Outpost")
	_place("humvee", z, Vector2(-5, -12), 15, "Outpost")
	_ring("sandbag_wall", z, Vector2(-10, 14), 5.0, 0.8, "outpost", 350.0, false)
	_line("concrete_barrier", z, Vector2(-16, -18), Vector2(-16, 18), 3.4, "outpost", 450.0, true, 90.0)
	_mm_add("street_light", _xform(z, Vector2(12, 12), 180.0), "outpost", 700.0, true)


func _compound() -> void:
	var z: TerrainFlatZone = _zone("Hedef kompleksi")
	_place("warehouses_row", z, Vector2(-28, 40), 0, "Compound")
	_place("warehouse", z, Vector2(44, 40), 0, "Compound")
	_place("bld_office", z, Vector2(46, -22), 0, "Compound")
	_place("bld_long", z, Vector2(-52, -14), 90, "Compound")
	_place("bld_garage", z, Vector2(-50, 12), 0, "Compound")
	_place("bunker", z, Vector2(-8, 8), 0, "Compound")
	_place("bunker", z, Vector2(20, 14), 30, "Compound")
	_place("bunker", z, Vector2(-14, -30), -20, "Compound")
	for p: Vector2 in [Vector2(-76, -58), Vector2(76, -58), Vector2(-76, 58), Vector2(76, 58)]:
		_place("watchtower", z, p, 45, "Compound")
	for p: Vector2 in [Vector2(-30, -42), Vector2(-24, -42), Vector2(-18, -42)]:
		_place("ural_truck", z, p, 0, "Compound")
	_place("humvee", z, Vector2(30, -46), 10, "Compound")
	_place("humvee", z, Vector2(36, -47), -5, "Compound")
	# Konteyner istifi: iki sıra, birinin üstünde bir tane daha
	for i: int in 3:
		_mm_add("container", _xform(z, Vector2(16, -8 + i * 2.6), 0.0), "compound", 900.0, true, true)
		_mm_add("container", _xform(z, Vector2(30, -8 + i * 2.6), 0.0), "compound", 900.0, true, true)
	_mm_add("container", _xform(z, Vector2(16, -5.4), 0.0, 2.4), "compound", 900.0, true, true)
	# Çit: güney kenarda (yolun girdiği yer) kapı boşluğu
	_fence_rect(z, 2.0, 0, 0.5, 16.0, "compound")
	_line("concrete_barrier", z, Vector2(-17, -64), Vector2(-9, -64), 3.4, "compound", 450.0, true)
	_line("concrete_barrier", z, Vector2(9, -64), Vector2(17, -64), 3.4, "compound", 450.0, true)
	for p: Vector2 in [Vector2(-10, -58), Vector2(10, -58), Vector2(-60, 30), Vector2(60, 30), Vector2(0, 50), Vector2(0, -10)]:
		_mm_add("street_light", _xform(z, p, 90.0), "compound", 700.0, true)


## Yol kenarında terk edilmiş birkaç araç: vadi boyunca hikâye ve ölçek hissi.
func _roadside() -> void:
	for spec: Array in [[480.0, 9.0, 70.0, "ural_truck"], [205.0, -8.0, -25.0, "humvee"], [-300.0, -11.0, 110.0, "ural_truck"]]:
		var p: Vector3 = _road_side_point(spec[0], spec[1])
		_place_world(spec[3], p, spec[2], "Roadside")


## Kaya ve kuru çalı serpiştirmesi: 200 m'lik bölgeler halinde (uzaktaki bölge çizilmez).
func _scatter() -> void:
	var shrub: Mesh = _shrub_mesh()
	for start: int in range(-900, 900, 200):
		var cluster: String = "scatter_%d" % start
		var rocks: int = 0
		var shrubs: int = 0
		var tries: int = 0
		while (rocks < 14 or shrubs < 70) and tries < 3000:
			tries += 1
			var zz: float = start + _rng.randf() * 200.0
			var x: float = _shape.get_valley_center_x(zz) + clampf(_rng.randfn(0.0, 85.0), -150.0, 150.0)
			if not _free_spot(x, zz):
				continue
			var y: float = _shape.get_height(x, zz)
			var yaw: float = _rng.randf() * TAU
			if rocks < 14 and _rng.randf() < 0.25:
				var prop: String = "rock_eroded" if _rng.randf() < 0.55 else "rock_base"
				var s: float = _rng.randf_range(0.3, 0.95)
				var basis := Basis(Vector3.UP, yaw).rotated(Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized(), _rng.randf_range(0.0, 0.15)).scaled(Vector3.ONE * s)
				_mm_add(prop, Transform3D(basis, Vector3(x, y - 0.35 * s, zz)), cluster, 700.0, true, true, 1)
				rocks += 1
			elif shrubs < 70:
				var s: float = _rng.randf_range(0.7, 1.7)
				_mm_add_mesh("dry_shrub", shrub, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.2), s)), Vector3(x, y - 0.05, zz)), cluster, 280.0, false)
				shrubs += 1


func _free_spot(x: float, z: float) -> bool:
	if not _shape.is_in_play_area(Vector3(x, 10.0, z)):
		return false
	if _shape.get_normal(x, z, 2.0).y < 0.9:
		return false
	for zone: TerrainFlatZone in _shape.flat_zones:
		if zone.distance_outside(x, z) < 10.0:
			return false
	if not _road_points.is_empty():
		var road: TerrainRoad = _shape.roads[0]
		var limit: float = road.width * 0.5 + road.shoulder + 2.0
		for p: Vector2 in _road_points:
			if absf(p.y - z) < limit and Vector2(x, z).distance_to(p) < limit:
				return false
	return true


# --- Yerleştirme yardımcıları -----------------------------------------------------------------

func _zone(zone_name: String) -> TerrainFlatZone:
	for zone: TerrainFlatZone in _shape.flat_zones:
		if zone.name == zone_name:
			return zone
	push_error("alan yok: " + zone_name)
	return null


## Alan yerel konumu -> dünya dönüşümü (nesnenin -Z'si alanın ileri yönü + açı).
func _xform(zone: TerrainFlatZone, local: Vector2, yaw_deg: float, lift: float = 0.0) -> Transform3D:
	var p: Vector3 = zone.to_world(local)
	var ground: float = zone.center.y + SLAB_TOP[zone.surface]
	if zone.distance_outside(p.x, p.z) > 0.01:
		ground = _shape.get_height(p.x, p.z)
	return Transform3D(Basis(Vector3.UP, -deg_to_rad(zone.heading_deg + yaw_deg)), Vector3(p.x, ground + lift, p.z))


func _group(group_name: String) -> Node3D:
	if not _groups.has(group_name):
		var g := Node3D.new()
		g.name = group_name
		_root.add_child(g)
		g.owner = _root
		_groups[group_name] = g
	return _groups[group_name]


func _place(prop: String, zone: TerrainFlatZone, local: Vector2, yaw_deg: float, group_name: String) -> void:
	_add_instance(prop, _xform(zone, local, yaw_deg), group_name)


func _place_world(prop: String, pos: Vector3, yaw_deg: float, group_name: String) -> void:
	_add_instance(prop, Transform3D(Basis(Vector3.UP, -deg_to_rad(yaw_deg)), pos), group_name)


func _add_instance(prop: String, xform: Transform3D, group_name: String) -> void:
	var node: Node3D = (load(PROPS + prop + ".tscn") as PackedScene).instantiate() as Node3D
	var parent: Node3D = _group(group_name)
	parent.add_child(node, true)
	node.owner = _root
	node.transform = xform


func _prop_mesh(prop: String) -> Mesh:
	if not _mesh_cache.has(prop):
		var node: Node = (load(PROPS + prop + ".tscn") as PackedScene).instantiate()
		var mi: MeshInstance3D = node.find_child("Mesh", true, false) as MeshInstance3D
		_mesh_cache[prop] = mi.mesh
		node.free()
	return _mesh_cache[prop]


## Gölge düşürmeyen küçük, tekrarlanan nesneler (mobilde gölge geçişi draw call'ları ikiye katlar).
const NO_SHADOW_PROPS: PackedStringArray = ["fence_panel", "concrete_barrier", "sandbag_wall", "street_light"]


func _mm_add(prop: String, xform: Transform3D, cluster: String, vis_end: float, shadow: bool, collide: bool = false, layer: int = 2) -> void:
	if prop in NO_SHADOW_PROPS:
		shadow = false
	var mesh: Mesh = _prop_mesh(prop)
	_mm_add_mesh(prop, mesh, xform, cluster, vis_end, shadow)
	if collide:
		if not _boxes.has(cluster):
			_boxes[cluster] = []
		(_boxes[cluster] as Array).append([xform, mesh.get_aabb(), layer])


func _mm_add_mesh(key_name: String, mesh: Mesh, xform: Transform3D, cluster: String, vis_end: float, shadow: bool) -> void:
	var key: String = key_name + "|" + cluster
	if not _mm.has(key):
		_mm[key] = {"name": key_name, "cluster": cluster, "mesh": mesh, "xforms": [], "vis_end": vis_end, "shadow": shadow}
	(_mm[key]["xforms"] as Array).append(xform)


## Doğru boyunca eşit aralıklı nesneler (ör. bariyer, kum torbası). angle: nesnenin hatta göre açısı.
func _line(prop: String, zone: TerrainFlatZone, a: Vector2, b: Vector2, spacing: float, cluster: String, vis_end: float, collide: bool, angle: float = 0.0) -> void:
	var count: int = maxi(1, int(a.distance_to(b) / spacing))
	var dir: Vector2 = (b - a).normalized()
	var line_yaw: float = rad_to_deg(atan2(dir.x, dir.y))
	for i: int in count:
		var p: Vector2 = a.lerp(b, (i + 0.5) / count)
		_mm_add(prop, _xform(zone, p, line_yaw + 90.0 + angle), cluster, vis_end, true, collide)


func _ring(prop: String, zone: TerrainFlatZone, center: Vector2, radius: float, gap_fraction: float, cluster: String, vis_end: float, collide: bool) -> void:
	_arc(prop, zone, center, radius, 0.0, 360.0 * gap_fraction, cluster, vis_end, collide)


func _arc(prop: String, zone: TerrainFlatZone, center: Vector2, radius: float, from_deg: float, to_deg: float, cluster: String, vis_end: float, collide: bool = false) -> void:
	var length: float = deg_to_rad(to_deg - from_deg) * radius
	var count: int = maxi(1, int(length / 2.5))
	for i: int in count:
		var a: float = deg_to_rad(lerpf(from_deg, to_deg, (i + 0.5) / count))
		var p: Vector2 = center + Vector2(sin(a), cos(a)) * radius
		_mm_add(prop, _xform(zone, p, rad_to_deg(a)), cluster, vis_end, true, collide)


## Dikdörtgen çit hattı; gap_side kenarında (0 arka, 1 sağ, 2 ön, 3 sol) kapı boşluğu bırakır.
func _fence_rect(zone: TerrainFlatZone, inset: float, gap_side: int, gap_t: float, gap_width: float, cluster: String) -> void:
	var h: Vector2 = zone.half_size - Vector2(inset, inset)
	var corners: Array[Vector2] = [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
	for side: int in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		if side == gap_side:
			var mid: Vector2 = a.lerp(b, gap_t)
			var dir: Vector2 = (b - a).normalized()
			_fence_segment(zone, a, mid - dir * gap_width * 0.5, cluster)
			_fence_segment(zone, mid + dir * gap_width * 0.5, b, cluster)
		else:
			_fence_segment(zone, a, b, cluster)


func _fence_segment(zone: TerrainFlatZone, a: Vector2, b: Vector2, cluster: String) -> void:
	var length: float = a.distance_to(b)
	if length < 1.0:
		return
	var count: int = maxi(1, ceili(length / FENCE_PANEL_LENGTH))
	var stretch: float = (length / count) / FENCE_PANEL_LENGTH
	var dir: Vector2 = (b - a).normalized()
	var yaw: float = rad_to_deg(atan2(dir.x, dir.y))
	for i: int in count:
		var xf: Transform3D = _xform(zone, a.lerp(b, (i + 0.5) / count), yaw)
		xf.basis = xf.basis.scaled_local(Vector3(1.0, 1.0, stretch))
		_mm_add("fence_panel", xf, cluster, 500.0, true)


## Yol orta çizgisinde verilen Z'ye en yakın noktadan yana kaydırılmış zemin noktası.
func _road_side_point(z: float, lateral: float) -> Vector3:
	var best: int = 0
	for i: int in _road_points.size():
		if absf(_road_points[i].y - z) < absf(_road_points[best].y - z):
			best = i
	var a: Vector2 = _road_points[maxi(best - 1, 0)]
	var b: Vector2 = _road_points[mini(best + 1, _road_points.size() - 1)]
	var dir: Vector2 = (b - a).normalized()
	var p: Vector2 = _road_points[best] + Vector2(-dir.y, dir.x) * lateral
	return Vector3(p.x, _shape.get_height(p.x, p.y), p.y)


func _shrub_mesh() -> Mesh:
	var mat := ShaderMaterial.new()
	mat.shader = load(FOLIAGE_SHADER) as Shader
	mat.set_shader_parameter(&"albedo_tex", load(SHRUB_TEXTURE) as Texture2D)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	const W: float = 0.75
	const H: float = 1.2
	# İki çapraz düzlem; çift yüzlülük ve sabit yukarı normal foliage.gdshader'da.
	for angle: float in [0.0, PI * 0.5]:
		var r := Vector3(cos(angle), 0.0, sin(angle)) * W
		var quad: Array[Vector3] = [-r, r, r + Vector3.UP * H, -r + Vector3.UP * H]
		var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[idx])
			st.add_vertex(quad[idx])
	return st.commit()


# --- Çıktı ---------------------------------------------------------------------------------------

func _flush_multimeshes(mm_dir: String) -> void:
	var parent: Node3D = _group("Instanced")
	for key: String in _mm:
		var entry: Dictionary = _mm[key]
		var xforms: Array = entry["xforms"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = entry["mesh"]
		mm.instance_count = xforms.size()
		for i: int in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var path: String = "%s/%s_%s.res" % [mm_dir, entry["name"], entry["cluster"]]
		ResourceSaver.save(mm, path, ResourceSaver.FLAG_COMPRESS)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%s" % [(entry["name"] as String).to_pascal_case(), (entry["cluster"] as String).to_pascal_case()]
		mmi.multimesh = load(path) as MultiMesh
		mmi.visibility_range_end = entry["vis_end"]
		mmi.visibility_range_end_margin = 20.0
		if not entry["shadow"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi, true)
		mmi.owner = _root


## Kaydedilen MultiMesh'leri yeniden okuyup örneklerin gerçekten yayıldığını doğrular.
func _verify_multimeshes(mm_dir: String) -> bool:
	for f: String in DirAccess.get_files_at(mm_dir):
		var mm: MultiMesh = ResourceLoader.load(mm_dir + "/" + f, "", ResourceLoader.CACHE_MODE_IGNORE) as MultiMesh
		if mm != null and mm.instance_count > 0 and mm.get_instance_transform(0).origin.length() < 1.0:
			return false
	return true


func _flush_collisions() -> void:
	var parent: Node3D = _group("Collisions")
	for cluster: String in _boxes:
		var by_layer: Dictionary = {}
		for item: Array in _boxes[cluster]:
			var layer: int = item[2]
			if not by_layer.has(layer):
				var body := StaticBody3D.new()
				body.name = "%s_L%d" % [cluster.to_pascal_case(), layer]
				body.collision_layer = layer
				body.collision_mask = 0
				parent.add_child(body, true)
				body.owner = _root
				by_layer[layer] = body
			var aabb: AABB = item[1]
			var xf: Transform3D = item[0]
			var shape := BoxShape3D.new()
			shape.size = aabb.size * xf.basis.get_scale()
			var col := CollisionShape3D.new()
			col.shape = shape
			col.transform = Transform3D(xf.basis.orthonormalized(), xf * aabb.get_center())
			(by_layer[layer] as StaticBody3D).add_child(col, true)
			col.owner = _root
