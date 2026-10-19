extends SceneTree
## Geliştirme aracı: bir TerrainShape'ten arazi parçaları (LOD'lu), çarpışma yükseklik
## haritası ve uzak dağ halkası üretip hazır bir terrain.tscn kaydeder.
##   godot --headless --path . -s res://tools/godot/generate_terrain.gd -- \
##       res://config/terrain/valley_01.tres res://assets/terrain/valley_01 res://materials/terrain/terrain_valley.tres

const SKIRT_DEPTH: float = 6.0
const BACKDROP_SIZE: float = 14336.0
const BACKDROP_SPACING: float = 128.0

var _shape: TerrainShape
var _heights: PackedFloat32Array
var _grid: int


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_shape = load(args[0]) as TerrainShape
	var out_dir: String = args[1]
	var material: Material = load(args[2]) as Material
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var t0: int = Time.get_ticks_msec()
	_sample_heights()
	print("yükseklikler: %d ms (%dx%d)" % [Time.get_ticks_msec() - t0, _grid, _grid])

	var root := Node3D.new()
	root.name = "Terrain"

	var chunks_per_side: int = int(_shape.size / _shape.chunk_size)
	var verts_per_chunk: int = int(_shape.chunk_size / _shape.resolution)
	for cz: int in chunks_per_side:
		for cx: int in chunks_per_side:
			var mesh: ArrayMesh = _build_chunk(cx * verts_per_chunk, cz * verts_per_chunk, verts_per_chunk)
			var path: String = "%s/chunk_%d_%d.res" % [out_dir, cx, cz]
			ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [cx, cz]
			mi.mesh = load(path) as Mesh
			mi.material_override = material
			root.add_child(mi)
			mi.owner = root
	print("parçalar: %d ms" % (Time.get_ticks_msec() - t0))

	var backdrop_path: String = out_dir + "/backdrop.res"
	ResourceSaver.save(_build_backdrop(), backdrop_path, ResourceSaver.FLAG_COMPRESS)
	var backdrop := MeshInstance3D.new()
	backdrop.name = "Backdrop"
	backdrop.mesh = load(backdrop_path) as Mesh
	backdrop.material_override = material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(backdrop)
	backdrop.owner = root

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


func _sample_heights() -> void:
	_grid = int(_shape.size / _shape.resolution) + 1
	_heights.resize(_grid * _grid)
	var half: float = _shape.size * 0.5
	for iz: int in _grid:
		for ix: int in _grid:
			_heights[iz * _grid + ix] = _shape.get_height(ix * _shape.resolution - half, iz * _shape.resolution - half)


func _h(ix: int, iz: int) -> float:
	return _heights[clampi(iz, 0, _grid - 1) * _grid + clampi(ix, 0, _grid - 1)]


func _grid_normal(ix: int, iz: int) -> Vector3:
	var r: float = _shape.resolution
	return Vector3(_h(ix - 1, iz) - _h(ix + 1, iz), 2.0 * r, _h(ix, iz - 1) - _h(ix, iz + 1)).normalized()


func _build_chunk(x0: int, z0: int, n: int) -> ArrayMesh:
	var half: float = _shape.size * 0.5
	var r: float = _shape.resolution
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var row: int = n + 1
	for iz: int in row:
		for ix: int in row:
			var gx: int = x0 + ix
			var gz: int = z0 + iz
			var pos := Vector3(gx * r - half, _h(gx, gz), gz * r - half)
			st.set_normal(_grid_normal(gx, gz))
			st.set_uv(Vector2(pos.x, pos.z))
			st.add_vertex(pos)
	for iz: int in n:
		for ix: int in n:
			var i: int = iz * row + ix
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + row)
			st.add_index(i + 1)
			st.add_index(i + row + 1)
			st.add_index(i + row)

	# Etek (skirt): farklı LOD'daki komşu parçalar arasındaki çatlakları gizler
	var border: Array[Vector2i] = []
	for i: int in n:
		border.append(Vector2i(i, 0))
	for i: int in n:
		border.append(Vector2i(n, i))
	for i: int in n:
		border.append(Vector2i(n - i, n))
	for i: int in n:
		border.append(Vector2i(0, n - i))
	var skirt_start: int = row * row
	for p: Vector2i in border:
		var gx: int = x0 + p.x
		var gz: int = z0 + p.y
		var pos := Vector3(gx * r - half, _h(gx, gz) - SKIRT_DEPTH, gz * r - half)
		st.set_normal(_grid_normal(gx, gz))
		st.set_uv(Vector2(pos.x, pos.z))
		st.add_vertex(pos)
	var count: int = border.size()
	for k: int in count:
		var a_top: int = border[k].y * row + border[k].x
		var b_top: int = border[(k + 1) % count].y * row + border[(k + 1) % count].x
		var a_low: int = skirt_start + k
		var b_low: int = skirt_start + (k + 1) % count
		# İki yönlü (her iki taraftan da görünür)
		for tri: PackedInt32Array in [
			PackedInt32Array([a_top, a_low, b_top]), PackedInt32Array([b_top, a_low, b_low]),
			PackedInt32Array([a_top, b_top, a_low]), PackedInt32Array([b_top, b_low, a_low]),
		]:
			for idx: int in tri:
				st.add_index(idx)

	st.generate_tangents()
	var arrays: Array = st.commit_to_arrays()
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(25.0, 60.0, [])
	return importer.get_mesh()


func _build_backdrop() -> ArrayMesh:
	var half: float = BACKDROP_SIZE * 0.5
	var inner: float = _shape.size * 0.5
	var n: int = int(BACKDROP_SIZE / BACKDROP_SPACING)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz: int in n + 1:
		for ix: int in n + 1:
			var x: float = ix * BACKDROP_SPACING - half
			var z: float = iz * BACKDROP_SPACING - half
			# Oyun alanının dışında araziyi yükselterek ufka dağ silueti verir.
			# İçeride kalan kısım oyun arazisinin altına gömülür: kenarlarda hiç delik kalmaz.
			var outside: float = maxf(absf(x), absf(z)) - inner
			var h: float = _shape.get_height(clampf(x, -inner, inner), clampf(z, -inner, inner))
			if outside > 0.0:
				h += smoothstep(0.0, 2500.0, outside) * 380.0 * (0.6 + 0.4 * sin(x * 0.0011) * cos(z * 0.0013))
			elif outside < -1.0:
				h -= 60.0
			st.set_normal(_shape.get_normal(clampf(x, -inner, inner), clampf(z, -inner, inner), 16.0))
			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, h - 2.0, z))
	var row: int = n + 1
	for iz: int in n:
		for ix: int in n:
			var i: int = iz * row + ix
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + row)
			st.add_index(i + 1)
			st.add_index(i + row + 1)
			st.add_index(i + row)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


func _build_collision() -> HeightMapShape3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = _grid
	shape.map_depth = _grid
	shape.map_data = _heights
	return shape
