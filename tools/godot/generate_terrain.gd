extends SceneTree
## Geliştirme aracı: bir TerrainShape'ten oyuna hazır terrain.tscn üretir.
##   godot --headless --path . -s res://tools/godot/generate_terrain.gd -- \
##       res://config/terrain/valley_01.tres res://assets/terrain/valley_01 res://materials/terrain/terrain_valley.tres
##
## İşlemciyi/GPU'yu yormamak için yalnızca oynanan alan detaylıdır:
##  - Vadi koridoruna yakın parçalar: tam çözünürlük + LOD'lar
##  - Vadi duvarlarının arkası: kaba (4 kat seyrek) kabuk, gölge atmaz
##  - Daha uzak parçalar üretilmez; ufku birkaç yüz üçgenlik siluet halkaları ve tek bir
##    uzak zemin düzlemi örter (sis/pus ile kaybolur).

const SKIRT_DEPTH_FULL: float = 6.0
const SKIRT_DEPTH_COARSE: float = 18.0
const COARSE_STRIDE: int = 4
const DISTANCE_SAMPLE_STEP: float = 32.0
## Elenen komşuya bakan kenarda arazinin alçaldığı mesafe (kesik kenar görünmesin).
const EDGE_FADE_DISTANCE: float = 160.0
const EDGE_FADE_HEIGHT: float = -30.0
const CONCRETE_MATERIAL: String = "res://materials/surfaces/concrete.tres"
const GRAVEL_MATERIAL: String = "res://materials/surfaces/gravel.tres"
const ROAD_MATERIAL: String = "res://materials/surfaces/asphalt_road.tres"
## Kaplamaların araziden yüksekliği (z-fighting olmasın).
const SLAB_TOP: Dictionary = {1: 0.14, 2: 0.10, 3: 0.05}
const ROAD_LIFT: float = 0.10

var _shape: TerrainShape
var _heights: PackedFloat32Array
var _grid: int
var _chunk_kind: Dictionary = {}  # Vector2i -> 0 tam, 1 kaba, 2 elendi


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_shape = load(args[0]) as TerrainShape
	var out_dir: String = args[1]
	var material: Material = load(args[2]) as Material
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_remove_old_meshes(out_dir)

	var t0: int = Time.get_ticks_msec()
	_sample_heights()
	print("yükseklikler: %d ms (%dx%d)" % [Time.get_ticks_msec() - t0, _grid, _grid])

	var root := Node3D.new()
	root.name = "Terrain"

	var chunks_per_side: int = int(_shape.size / _shape.chunk_size)
	var verts_per_chunk: int = int(_shape.chunk_size / _shape.resolution)
	var stats: Dictionary = {"full": 0, "coarse": 0, "skipped": 0, "triangles": 0}
	for cz: int in chunks_per_side:
		for cx: int in chunks_per_side:
			var distance: float = _chunk_valley_distance(cx, cz)
			_chunk_kind[Vector2i(cx, cz)] = 2 if distance > _shape.coarse_distance else (0 if distance <= _shape.full_detail_distance else 1)
	for cz: int in chunks_per_side:
		for cx: int in chunks_per_side:
			var kind: int = _chunk_kind[Vector2i(cx, cz)]
			if kind == 2:
				stats["skipped"] += 1
				continue
			var full: bool = kind == 0
			var stride: int = 1 if full else COARSE_STRIDE
			var mesh: ArrayMesh = _build_chunk(cx * verts_per_chunk, cz * verts_per_chunk, verts_per_chunk, stride, full, Vector2i(cx, cz))
			var path: String = "%s/chunk_%d_%d.res" % [out_dir, cx, cz]
			ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [cx, cz]
			mi.mesh = load(path) as Mesh
			mi.material_override = material
			if not full:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
			mi.owner = root
			stats["full" if full else "coarse"] += 1
			stats["triangles"] += mesh.surface_get_array_index_len(0) / 3
	print("parçalar: %s (%d ms)" % [stats, Time.get_ticks_msec() - t0])

	_build_surfaces(root, out_dir)

	var horizon_material: StandardMaterial3D = _horizon_material()
	ResourceSaver.save(horizon_material, out_dir + "/horizon_material.tres")
	horizon_material = load(out_dir + "/horizon_material.tres") as StandardMaterial3D
	_add_static_mesh(root, "Horizon", _build_horizon(), out_dir + "/horizon.res", horizon_material)
	_add_static_mesh(root, "FarGround", _build_far_ground(), out_dir + "/far_ground.res", horizon_material)

	var shape_path: String = out_dir + "/collision.res"
	ResourceSaver.save(_build_collision(), shape_path, ResourceSaver.FLAG_COMPRESS)
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	body.owner = root
	var col := CollisionShape3D.new()
	col.name = "HeightMap"
	col.shape = load(shape_path) as Shape3D
	col.scale = Vector3(_shape.resolution, 1.0, _shape.resolution)
	body.add_child(col)
	col.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, out_dir + "/terrain.tscn")
	print("bitti: %d ms" % (Time.get_ticks_msec() - t0))
	root.free()
	quit()


func _remove_old_meshes(out_dir: String) -> void:
	var dir := DirAccess.open(out_dir)
	if dir == null:
		return
	for file: String in dir.get_files():
		if file.ends_with(".res"):
			dir.remove(file)


func _add_static_mesh(root: Node3D, node_name: String, mesh: ArrayMesh, path: String, material: Material, casts_shadow: bool = false) -> void:
	ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = load(path) as Mesh
	mi.material_override = material
	if not casts_shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.owner = root


func _sample_heights() -> void:
	_grid = int(_shape.size / _shape.resolution) + 1
	_heights.resize(_grid * _grid)
	var half: float = _shape.size * 0.5
	for iz: int in _grid:
		for ix: int in _grid:
			_heights[iz * _grid + ix] = _shape.get_height(ix * _shape.resolution - half, iz * _shape.resolution - half)


## Parçanın vadi orta çizgisine en yakın noktasının uzaklığı.
func _chunk_valley_distance(cx: int, cz: int) -> float:
	var half: float = _shape.size * 0.5
	var x0: float = cx * _shape.chunk_size - half
	var z0: float = cz * _shape.chunk_size - half
	var steps: int = int(_shape.chunk_size / DISTANCE_SAMPLE_STEP)
	var best: float = INF
	for iz: int in steps + 1:
		for ix: int in steps + 1:
			best = minf(best, _shape.distance_to_valley(x0 + ix * DISTANCE_SAMPLE_STEP, z0 + iz * DISTANCE_SAMPLE_STEP))
	return best


func _h(ix: int, iz: int) -> float:
	return _heights[clampi(iz, 0, _grid - 1) * _grid + clampi(ix, 0, _grid - 1)]


func _grid_normal(ix: int, iz: int, stride: int) -> Vector3:
	var r: float = _shape.resolution * stride
	return Vector3(_h(ix - stride, iz) - _h(ix + stride, iz), 2.0 * r, _h(ix, iz - stride) - _h(ix, iz + stride)).normalized()


## Elenen komşu parçalara yaklaştıkça yükseklik EDGE_FADE_HEIGHT'e iner (yalnızca görsel).
func _faded_height(gx: int, gz: int, chunk: Vector2i) -> float:
	var h: float = _h(gx, gz)
	var r: float = _shape.resolution
	var local := Vector2(gx * r - chunk.x * _shape.chunk_size, gz * r - chunk.y * _shape.chunk_size)
	var fade: float = 0.0
	for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		if _chunk_kind.get(chunk + offset, 2) != 2:
			continue
		var dist: float
		match offset:
			Vector2i(-1, 0): dist = local.x
			Vector2i(1, 0): dist = _shape.chunk_size - local.x
			Vector2i(0, -1): dist = local.y
			_: dist = _shape.chunk_size - local.y
		fade = maxf(fade, 1.0 - smoothstep(0.0, EDGE_FADE_DISTANCE, dist))
	return lerpf(h, EDGE_FADE_HEIGHT, fade)


func _build_chunk(x0: int, z0: int, n: int, stride: int, with_lods: bool, chunk: Vector2i) -> ArrayMesh:
	var half: float = _shape.size * 0.5
	var r: float = _shape.resolution
	var cells: int = n / stride
	var row: int = cells + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz: int in row:
		for ix: int in row:
			var gx: int = x0 + ix * stride
			var gz: int = z0 + iz * stride
			var pos := Vector3(gx * r - half, _faded_height(gx, gz, chunk), gz * r - half)
			st.set_normal(_grid_normal(gx, gz, stride))
			st.set_uv(Vector2(pos.x, pos.z))
			st.add_vertex(pos)
	for iz: int in cells:
		for ix: int in cells:
			var i: int = iz * row + ix
			for idx: int in [i, i + 1, i + row, i + 1, i + row + 1, i + row]:
				st.add_index(idx)

	# Etek (skirt): farklı çözünürlük/LOD'daki komşu parçalar arasındaki çatlakları gizler
	var border: Array[Vector2i] = []
	for i: int in cells:
		border.append(Vector2i(i, 0))
	for i: int in cells:
		border.append(Vector2i(cells, i))
	for i: int in cells:
		border.append(Vector2i(cells - i, cells))
	for i: int in cells:
		border.append(Vector2i(0, cells - i))
	var skirt_depth: float = SKIRT_DEPTH_FULL if stride == 1 else SKIRT_DEPTH_COARSE
	var skirt_start: int = row * row
	for p: Vector2i in border:
		var gx: int = x0 + p.x * stride
		var gz: int = z0 + p.y * stride
		var pos := Vector3(gx * r - half, _faded_height(gx, gz, chunk) - skirt_depth, gz * r - half)
		st.set_normal(_grid_normal(gx, gz, stride))
		st.set_uv(Vector2(pos.x, pos.z))
		st.add_vertex(pos)
	var count: int = border.size()
	for k: int in count:
		var a_top: int = border[k].y * row + border[k].x
		var b_top: int = border[(k + 1) % count].y * row + border[(k + 1) % count].x
		var a_low: int = skirt_start + k
		var b_low: int = skirt_start + (k + 1) % count
		# İki yönlü (her iki taraftan da görünür)
		for idx: int in [a_top, a_low, b_top, b_top, a_low, b_low, a_top, b_top, a_low, b_top, b_low, a_low]:
			st.add_index(idx)

	if not with_lods:
		st.generate_normals()
	st.generate_tangents()
	var arrays: Array = st.commit_to_arrays()
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if with_lods:
		importer.generate_lods(25.0, 60.0, [])
	return importer.get_mesh()


## Tasarlanmış alanların kaplamaları (beton plakalar, çakıl avlular) ve yollar.
## Aynı malzemedeki her şey tek ağda birleşir: kaplama başına tek draw call.
func _build_surfaces(root: Node3D, out_dir: String) -> void:
	var slabs: Dictionary = {}  # Surface -> SurfaceTool
	for zone: TerrainFlatZone in _shape.flat_zones:
		if zone.surface == TerrainFlatZone.Surface.NONE:
			continue
		if not slabs.has(zone.surface):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			slabs[zone.surface] = st
		_add_slab(slabs[zone.surface], zone)
	var materials: Dictionary = {
		TerrainFlatZone.Surface.CONCRETE: CONCRETE_MATERIAL,
		TerrainFlatZone.Surface.ASPHALT: CONCRETE_MATERIAL,
		TerrainFlatZone.Surface.GRAVEL: GRAVEL_MATERIAL,
	}
	for surface: int in slabs:
		var st: SurfaceTool = slabs[surface]
		st.generate_tangents()
		var node_name: String = "Surface_%s" % TerrainFlatZone.Surface.keys()[surface].capitalize()
		_add_static_mesh(root, node_name, st.commit(), "%s/%s.res" % [out_dir, node_name.to_snake_case()],
			load(materials[surface]) as Material, true)

	if _shape.roads.is_empty():
		return
	var road_st := SurfaceTool.new()
	road_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in _shape.roads.size():
		_add_road(road_st, _shape.get_road_profile(i))
	road_st.generate_tangents()
	_add_static_mesh(root, "Roads", road_st.commit(), out_dir + "/roads.res", load(ROAD_MATERIAL) as Material, false)


## Kalınlığı olan plaka: üst yüzey + dört yan (araziye gömülür).
func _add_slab(st: SurfaceTool, zone: TerrainFlatZone) -> void:
	var top: float = zone.center.y + SLAB_TOP[zone.surface]
	var bottom: float = zone.center.y - 0.8
	var c: Array[Vector3] = []
	for local: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector3 = zone.to_world(local * zone.half_size)
		c.append(Vector3(p.x, top, p.z))
	_add_quad(st, c[0], c[1], c[2], c[3], Vector3.UP, true)
	for i: int in 4:
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		var out: Vector3 = (a + b) * 0.5 - Vector3(zone.center.x, top, zone.center.z)
		_add_quad(st, a, b, Vector3(b.x, bottom, b.z), Vector3(a.x, bottom, a.z), Vector3(out.x, 0.0, out.z).normalized(), false)


## Dört köşeli yüz; sarım yönü istenen normale göre otomatik seçilir.
func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, top_uv: bool) -> void:
	var quad: Array[Vector3] = [a, b, c, d]
	# Godot'ta ön yüz saat yönündedir: (b-a)x(c-a) normalin tersini göstermeli
	if (b - a).cross(c - a).dot(normal) > 0.0:
		quad = [a, d, c, b]
	var uvs: Array[Vector2] = []
	for p: Vector3 in quad:
		if top_uv:
			uvs.append(Vector2(p.x, p.z))
		else:
			uvs.append(Vector2(p.x + p.z, p.y))
	for idx: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[idx])
		st.add_vertex(quad[idx])


## Yol şeridi: profili izleyen 5 köşeli kesit + kenarlarda araziye gömülen etekler.
func _add_road(st: SurfaceTool, profile: Dictionary) -> void:
	var pts: PackedVector2Array = profile["points"]
	var heights: PackedFloat32Array = profile["heights"]
	var half_width: float = profile["half_width"]
	var across: PackedFloat32Array = [-1.0, -0.5, 0.0, 0.5, 1.0]
	var distance: float = 0.0
	var rows: Array[PackedVector3Array] = []
	var vs: PackedFloat32Array = []
	for i: int in pts.size():
		var prev: Vector2 = pts[maxi(i - 1, 0)]
		var next: Vector2 = pts[mini(i + 1, pts.size() - 1)]
		var dir: Vector2 = (next - prev).normalized()
		var right := Vector3(-dir.y, 0.0, dir.x)
		if i > 0:
			distance += pts[i].distance_to(pts[i - 1])
		var center := Vector3(pts[i].x, heights[i] + ROAD_LIFT, pts[i].y)
		var row := PackedVector3Array()
		row.append(center - right * (half_width + 0.8) + Vector3.DOWN * 0.7)
		for a: float in across:
			row.append(center + right * a * half_width)
		row.append(center + right * (half_width + 0.8) + Vector3.DOWN * 0.7)
		rows.append(row)
		vs.append(distance / (half_width * 2.0))
	var us: PackedFloat32Array = [0.0, 0.0, 0.25, 0.5, 0.75, 1.0, 1.0]
	for i: int in rows.size() - 1:
		for k: int in 6:
			var a: Vector3 = rows[i][k]
			var b: Vector3 = rows[i][k + 1]
			var c: Vector3 = rows[i + 1][k + 1]
			var d: Vector3 = rows[i + 1][k]
			var quad: Array[Vector3] = [a, b, c, d]
			var quv: Array[Vector2] = [Vector2(us[k], vs[i]), Vector2(us[k + 1], vs[i]), Vector2(us[k + 1], vs[i + 1]), Vector2(us[k], vs[i + 1])]
			if (b - a).cross(c - a).dot(Vector3.UP) > 0.0:
				quad = [a, d, c, b]
				quv = [quv[0], quv[3], quv[2], quv[1]]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_uv(quv[idx])
				st.add_vertex(quad[idx])


## Ufuk: iki eş merkezli, dikey dağ silueti halkası (yakın koyu, uzak puslu).
func _build_horizon() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_ring(st, 2600.0, 160.0, 300.0, Color(0.34, 0.26, 0.21), Color(0.60, 0.47, 0.38), 11)
	_add_ring(st, 3900.0, 260.0, 420.0, Color(0.50, 0.46, 0.45), Color(0.66, 0.63, 0.64), 23)
	return st.commit()


func _add_ring(st: SurfaceTool, radius: float, base: float, amplitude: float, low: Color, high: Color, noise_seed: int) -> void:
	const SEGMENTS: int = 160
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = 3.0
	noise.fractal_octaves = 4
	var start: int = 0
	for i: int in SEGMENTS + 1:
		var a: float = TAU * i / SEGMENTS
		var dir := Vector3(sin(a), 0.0, cos(a))
		# Halka kapanırken dikiş olmasın diye gürültü daire üzerinde örneklenir
		var ridged: float = 1.0 - absf(noise.get_noise_2d(cos(a), sin(a)))
		var top: float = base + ridged * ridged * amplitude
		st.set_color(low)
		st.add_vertex(dir * radius + Vector3.DOWN * 40.0)
		# Tepeler açık, çukurlar koyu: düz renk yerine okunur bir dağ sırası
		st.set_color(low.lerp(high, 0.55 + 0.45 * ridged))
		st.add_vertex(dir * radius + Vector3.UP * top)
	for i: int in SEGMENTS:
		var b: int = start + i * 2
		for idx: int in [b, b + 1, b + 2, b + 2, b + 1, b + 3]:
			st.add_index(idx)


## Üretilmeyen uzak bölgelerin altını kapatan tek düzlem (boşluk görünmesin).
func _build_far_ground() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const S: float = 4200.0
	var color := Color(0.45, 0.36, 0.28)
	for p: Vector3 in [Vector3(-S, 2, -S), Vector3(S, 2, -S), Vector3(-S, 2, S), Vector3(S, 2, S)]:
		st.set_color(color)
		st.add_vertex(p)
	for idx: int in [0, 1, 2, 1, 3, 2]:
		st.add_index(idx)
	return st.commit()


func _horizon_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _build_collision() -> HeightMapShape3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = _grid
	shape.map_depth = _grid
	shape.map_data = _heights
	return shape
