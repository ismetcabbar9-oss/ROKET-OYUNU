extends SceneTree
## Geliştirme aracı: üç fırlatma rampası sahnesini (mobil TEL, eğik ray, dikey silo) basit
## geometrik parçalardan kurar ve kaydeder. Hareketli her parça tek ağ + tek malzemedir
## (mobil draw call bütçesi); renk farkları köşe rengiyle verilir.
##   godot --headless --path . -s res://tools/godot/build_launchers.gd
## Çıktılar: scenes/launchers/*.tscn, assets/models/launchers/*.res
## Ölçüler rampanın yerel uzayında: x = sağ, y = yukarı, -z = fırlatma yönü (metre).

const OUT_SCENES: String = "res://scenes/launchers/"
const OUT_MESHES: String = "res://assets/models/launchers/"
## Küçük hareketli parçaların (kelepçe, piston, ayak) görünürlük mesafesi.
const SMALL_PART_RANGE: float = 90.0
const STEEL: String = "res://materials/launchers/launcher_steel.tres"
const CONCRETE: String = "res://materials/launchers/launcher_concrete.tres"
const BEACON: String = "res://materials/launchers/launcher_beacon.tres"
const TRUCK_MESH: String = "res://assets/models/props/launcher_truck/launcher_truck_mesh.res"
const BLAST: String = "res://scenes/fx/launch_blast.tscn"
const SFX: String = "res://assets/audio/sfx/"

const OLIVE := Color(0.33, 0.35, 0.25)
const OLIVE_DARK := Color(0.2, 0.22, 0.16)
const STEEL_GREY := Color(0.42, 0.43, 0.42)
const CHROME := Color(0.8, 0.8, 0.78)
const STRIPE := Color(0.85, 0.65, 0.12)
const CONCRETE_LIGHT := Color(1, 1, 1)
const CONCRETE_DARK := Color(0.22, 0.21, 0.2)

var _steel: Material
var _concrete: Material
var _beacon: Material


func _initialize() -> void:
	_steel = load(STEEL) as Material
	_concrete = load(CONCRETE) as Material
	_beacon = load(BEACON) as Material
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_SCENES))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_MESHES))
	_save(_build_tel(), "tel_launcher")
	_save(_build_rail(), "rail_launcher")
	_save(_build_silo(), "silo_launcher")
	quit()


# --- Mobil TEL kamyonu -------------------------------------------------------------------------

func _build_tel() -> Launcher:
	var root: Launcher = _launcher("TelLauncher", "res://config/launchers/tel.tres")
	var truck := MeshInstance3D.new()
	truck.name = "Truck"
	truck.mesh = load(TRUCK_MESH) as Mesh
	_add(root, truck)

	# Destek ayakları: hazırlıkta 0,35 m iner (başlangıçta yukarıda)
	var jacks := Node3D.new()
	jacks.name = "Jacks"
	jacks.position.y = 0.35
	_add(root, jacks)
	var st: SurfaceTool = _begin()
	for x: float in [-1.45, 1.45]:
		for z: float in [4.6, -0.4]:
			_box(st, Vector3(0.24, 1.3, 0.24), Vector3(x, 0.69, z), OLIVE_DARK)
			_box(st, Vector3(0.62, 0.08, 0.62), Vector3(x, 0.04, z), STEEL_GREY)
	_add(jacks, _mesh_node("JackMesh", _commit(st, "tel_jacks"), _steel, false))

	# Erektör: arkadaki mafsal etrafında döner
	var erector := Node3D.new()
	erector.name = "Erector"
	erector.position = Vector3(0, 2.3, 4.9)
	erector.rotation.x = deg_to_rad(22.0)
	_add(root, erector)
	st = _begin()
	for x: float in [-0.5, 0.5]:
		_box(st, Vector3(0.2, 0.32, 9.6), Vector3(x, 0.0, -4.8), OLIVE)
	for i: int in 7:
		_box(st, Vector3(1.2, 0.12, 0.14), Vector3(0, 0.1, -0.5 - i * 1.45), OLIVE_DARK)
	_box(st, Vector3(1.5, 0.5, 0.5), Vector3(0, -0.05, -0.1), OLIVE_DARK)
	# Destek kızakları (füzenin oturduğu V yatakları)
	for z: float in [-1.4, -8.2]:
		_box(st, Vector3(0.9, 0.22, 0.3), Vector3(0, 0.27, z), STEEL_GREY)
	_add(erector, _mesh_node("ErectorMesh", _commit(st, "tel_erector"), _steel))
	_clamps(root, erector, 0.62, 0.16, -4.9, "tel_clamp")
	var cradle := Marker3D.new()
	cradle.name = "Cradle"
	cradle.position = Vector3(0, 0.75, -4.9)
	_add(erector, cradle)

	var attach := Marker3D.new()
	attach.name = "RamAttach"
	attach.position = Vector3(0, -0.2, -3.6)
	_add(erector, attach)
	var anchor := Marker3D.new()
	anchor.name = "RamAnchor"
	anchor.position = Vector3(0, 1.55, 1.3)
	_add(root, anchor)
	var ram: HydraulicRam = _ram(root, anchor, attach, 0.17, 0.1, 1.85, "tel")

	var beacon: MeshInstance3D = _beacon_node("Beacon", Vector3(0.0, 4.45, -3.3))
	_add(root, beacon)
	var blast := Marker3D.new()
	blast.name = "BlastPoint"
	blast.position = Vector3(0, 0.05, 7.0)
	_add(root, blast)

	root.raise_pivot = erector
	root.jacks = jacks
	root.cradle = cradle
	root.blast_point = blast
	root.rams = [ram]
	root.beacons = [beacon]
	_sounds(root, "hydraulic_loop.ogg")
	return root


# --- Sabit eğik ray rampası ---------------------------------------------------------------------

func _build_rail() -> Launcher:
	var root: Launcher = _launcher("RailLauncher", "res://config/launchers/rail.tres")
	var st: SurfaceTool = _begin()
	_box(st, Vector3(4.2, 0.4, 11.0), Vector3(0, 0.2, -0.5), CONCRETE_LIGHT)
	# Arka mafsal kaidesi
	_box(st, Vector3(2.4, 1.5, 1.8), Vector3(0, 1.15, 3.3), CONCRETE_LIGHT)
	# Ön piston kaidesi
	_box(st, Vector3(1.4, 0.3, 1.4), Vector3(0, 0.55, -3.2), CONCRETE_LIGHT)
	# Alev saptırıcı: rampanın arkasında eğik beton plaka
	_box(st, Vector3(3.6, 0.45, 3.2), Vector3(0, 1.0, 6.0), CONCRETE_LIGHT, Vector3(deg_to_rad(-38.0), 0, 0))
	# Yan patlama duvarları
	for x: float in [-2.3, 2.3]:
		_box(st, Vector3(0.4, 1.2, 4.0), Vector3(x, 1.0, 4.4), CONCRETE_LIGHT)
	# Uyarı lambası direği
	_box(st, Vector3(0.12, 2.2, 0.12), Vector3(1.9, 1.5, 2.2), CONCRETE_DARK)
	_add(root, _mesh_node("Plinth", _commit(st, "rail_plinth"), _concrete))

	var rail := Node3D.new()
	rail.name = "Rail"
	rail.position = Vector3(0, 1.95, 3.4)
	rail.rotation.x = deg_to_rad(8.0)
	_add(root, rail)
	st = _begin()
	for x: float in [-0.34, 0.34]:
		_box(st, Vector3(0.1, 0.26, 9.2), Vector3(x, 0.0, -4.6), STEEL_GREY)
		_box(st, Vector3(0.24, 0.05, 9.2), Vector3(x, 0.13, -4.6), STEEL_GREY)
		_box(st, Vector3(0.24, 0.05, 9.2), Vector3(x, -0.13, -4.6), STEEL_GREY)
	for i: int in 6:
		_box(st, Vector3(0.9, 0.08, 0.16), Vector3(0, -0.1, -0.4 - i * 1.7), OLIVE_DARK)
	_box(st, Vector3(1.3, 0.45, 0.6), Vector3(0, -0.05, -0.1), OLIVE_DARK)
	# Sarı-siyah uyarı bandı (ray ucu)
	_box(st, Vector3(0.9, 0.1, 0.25), Vector3(0, 0.12, -9.1), STRIPE)
	_add(rail, _mesh_node("RailMesh", _commit(st, "rail_beam"), _steel))
	_clamps(root, rail, 0.5, 0.12, -4.6, "rail_clamp")
	var cradle := Marker3D.new()
	cradle.name = "Cradle"
	cradle.position = Vector3(0, 0.62, -4.6)
	_add(rail, cradle)

	var attach := Marker3D.new()
	attach.name = "RamAttach"
	attach.position = Vector3(0, -0.15, -6.4)
	_add(rail, attach)
	var anchor := Marker3D.new()
	anchor.name = "RamAnchor"
	anchor.position = Vector3(0, 0.7, -3.2)
	_add(root, anchor)
	var ram: HydraulicRam = _ram(root, anchor, attach, 0.15, 0.09, 1.95, "rail")

	var beacon: MeshInstance3D = _beacon_node("Beacon", Vector3(1.9, 2.7, 2.2))
	_add(root, beacon)
	var blast := Marker3D.new()
	blast.name = "BlastPoint"
	blast.position = Vector3(0, 0.45, 5.0)
	_add(root, blast)

	root.raise_pivot = rail
	root.cradle = cradle
	root.blast_point = blast
	root.rams = [ram]
	root.beacons = [beacon]
	_sounds(root, "hydraulic_loop.ogg")
	return root


# --- Dikey silo (VLS) ---------------------------------------------------------------------------

func _build_silo() -> Launcher:
	var root: Launcher = _launcher("SiloLauncher", "res://config/launchers/silo.tres")
	var st: SurfaceTool = _begin()
	# Yuvarlak beton taban ve yükseltilmiş silo yakası (içi koyu: tüp derin görünür)
	_ring(st, 1.55, 4.6, 0.0, 0.3, 32, CONCRETE_LIGHT, CONCRETE_DARK)
	_ring(st, 1.55, 2.35, 0.3, 3.7, 32, CONCRETE_LIGHT, CONCRETE_DARK)
	# Kapak menteşe yuvaları
	for x: float in [-2.05, 2.05]:
		_box(st, Vector3(0.7, 0.6, 3.0), Vector3(x, 3.6, 0.0), CONCRETE_LIGHT)
	# Servis merdiveni (ince basamaklar) ve tüp içi koyu halka
	for i: int in 6:
		_box(st, Vector3(0.6, 0.06, 0.06), Vector3(0.0, 0.5 + i * 0.55, 2.42), CONCRETE_DARK)
	_add(root, _mesh_node("Silo", _commit(st, "silo_body"), _concrete))

	var hatches: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "HatchLeft" if side < 0.0 else "HatchRight"
		hinge.position = Vector3(1.62 * side, 3.82, 0.0)
		_add(root, hinge)
		st = _begin()
		_box(st, Vector3(1.62, 0.24, 3.3), Vector3(-0.81 * side, 0.0, 0.0), OLIVE)
		_box(st, Vector3(1.2, 0.06, 2.6), Vector3(-0.85 * side, 0.15, 0.0), OLIVE_DARK)
		_box(st, Vector3(0.2, 0.03, 3.3), Vector3(-1.52 * side, 0.135, 0.0), STRIPE)
		_add(hinge, _mesh_node("Mesh", _commit(st, "silo_hatch_%s" % ("l" if side < 0.0 else "r")), _steel))
		hatches.append(hinge)

	# Füze burnu kapağın hemen altında; Launcher burnu bu noktaya hizalar
	var cradle := Marker3D.new()
	cradle.name = "Cradle"
	cradle.position = Vector3(0, 3.35, 0)
	cradle.rotation.x = deg_to_rad(90.0)
	_add(root, cradle)
	var b1: MeshInstance3D = _beacon_node("BeaconLeft", Vector3(-2.05, 4.0, 1.2))
	var b2: MeshInstance3D = _beacon_node("BeaconRight", Vector3(2.05, 4.0, -1.2))
	_add(root, b1)
	_add(root, b2)
	var blast := Marker3D.new()
	blast.name = "BlastPoint"
	blast.position = Vector3(0, 3.7, 0)
	_add(root, blast)

	root.hatches = hatches
	root.cradle = cradle
	root.cradle_at_nose = true
	root.blast_point = blast
	root.beacons = [b1, b2]
	_sounds(root, "hatch_open.ogg")
	return root


# --- Ortak parçalar ----------------------------------------------------------------------------

func _launcher(node_name: String, definition_path: String) -> Launcher:
	var root := Launcher.new()
	root.name = node_name
	root.definition = load(definition_path) as LauncherDefinition
	root.blast_scene = load(BLAST) as PackedScene
	return root


## Ray üzerinde füzeyi iki yandan kavrayan kelepçeler (kilit aşamasında kapanır).
func _clamps(launcher: Launcher, parent: Node3D, half_width: float, y: float, z: float, mesh_name: String) -> void:
	var clamps: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "ClampLeft" if side < 0.0 else "ClampRight"
		hinge.position = Vector3(half_width * side, y, z)
		_add(parent, hinge)
		var st: SurfaceTool = _begin()
		_box(st, Vector3(0.1, 0.75, 0.5), Vector3(0, 0.37, 0), STEEL_GREY)
		_box(st, Vector3(0.3, 0.1, 0.5), Vector3(-0.12 * side, 0.74, 0), STRIPE)
		_add(hinge, _mesh_node("Mesh", _commit(st, "%s_%s" % [mesh_name, "l" if side < 0.0 else "r"]), _steel, false))
		clamps.append(hinge)
	launcher.clamps = clamps


func _ram(root: Node3D, anchor: Node3D, attach: Node3D, barrel_r: float, rod_r: float, length: float, prefix: String) -> HydraulicRam:
	var ram := HydraulicRam.new()
	ram.name = "Ram"
	_add(root, ram)
	var st: SurfaceTool = _begin()
	_cylinder_z(st, barrel_r, length, OLIVE_DARK)
	var barrel: MeshInstance3D = _mesh_node("Barrel", _commit(st, prefix + "_ram_barrel"), _steel, false)
	st = _begin()
	_cylinder_z(st, rod_r, length, CHROME)
	var rod: MeshInstance3D = _mesh_node("Rod", _commit(st, prefix + "_ram_rod"), _steel, false)
	_add(ram, barrel)
	_add(ram, rod)
	ram.anchor = anchor
	ram.attach = attach
	ram.barrel = barrel
	ram.rod = rod
	return ram


func _beacon_node(node_name: String, pos: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.26
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _beacon
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _sounds(root: Launcher, mechanism_file: String) -> void:
	var specs: Array = [["Alarm", "launch_alarm.ogg", -6.0], ["Mechanism", mechanism_file, -4.0], ["Lock", "lock_clunk.ogg", 0.0]]
	var players: Array[AudioStreamPlayer3D] = []
	for spec: Array in specs:
		var p := AudioStreamPlayer3D.new()
		p.name = spec[0]
		p.stream = load(SFX + String(spec[1])) as AudioStream
		p.volume_db = spec[2]
		p.unit_size = 14.0
		p.max_distance = 600.0
		p.position.y = 2.0
		_add(root, p)
		players.append(p)
	root.alarm_sound = players[0]
	root.mechanism_sound = players[1]
	root.lock_sound = players[2]


# --- Ağ yardımcıları ---------------------------------------------------------------------------

func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## İlkel ağı dönüşümle ve tek renkle yüzey aracına ekler.
func _append(st: SurfaceTool, prim: PrimitiveMesh, xform: Transform3D, color: Color) -> void:
	var arrays: Array = prim.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var nbasis: Basis = xform.basis.inverse().transposed()
	for i: int in indices:
		st.set_color(color)
		st.set_normal((nbasis * normals[i]).normalized())
		st.set_uv(uvs[i])
		st.add_vertex(xform * verts[i])


func _box(st: SurfaceTool, size: Vector3, center: Vector3, color: Color, euler: Vector3 = Vector3.ZERO) -> void:
	var box := BoxMesh.new()
	box.size = size
	_append(st, box, Transform3D(Basis.from_euler(euler), center), color)


## Orijinden -Z yönünde uzanan silindir (piston parçaları).
func _cylinder_z(st: SurfaceTool, radius: float, length: float, color: Color) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 10
	cyl.rings = 1
	_append(st, cyl, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), Vector3(0, 0, -length * 0.5)), color)


## İçi boş halka: dış duvar, iç duvar (içe bakan, koyu) ve üst yüzey.
func _ring(st: SurfaceTool, r_in: float, r_out: float, y0: float, y1: float, segments: int, outer: Color, inner: Color) -> void:
	for i: int in segments:
		var a0: float = TAU * i / segments
		var a1: float = TAU * (i + 1) / segments
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var u0: float = float(i) / segments
		var u1: float = float(i + 1) / segments
		# Dış duvar (normal dışa)
		_quad(st, d0 * r_out + Vector3.UP * y0, d1 * r_out + Vector3.UP * y0, d1 * r_out + Vector3.UP * y1, d0 * r_out + Vector3.UP * y1, (d0 + d1).normalized(), outer, u0, u1)
		# İç duvar (normal içe)
		_quad(st, d1 * r_in + Vector3.UP * y0, d0 * r_in + Vector3.UP * y0, d0 * r_in + Vector3.UP * y1, d1 * r_in + Vector3.UP * y1, -(d0 + d1).normalized(), inner, u0, u1)
		# Üst yüzey
		_quad(st, d0 * r_out + Vector3.UP * y1, d1 * r_out + Vector3.UP * y1, d1 * r_in + Vector3.UP * y1, d0 * r_in + Vector3.UP * y1, Vector3.UP, outer, u0, u1)


## a-b-c-d dörtgeni (normal tarafından bakınca Godot'nun ön yüz sırasında).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color, u0: float, u1: float) -> void:
	var pts: Array[Vector3] = [a, b, c, a, c, d]
	var uvs: Array[Vector2] = [Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(u0, 1), Vector2(u1, 0), Vector2(u0, 0)]
	for i: int in 6:
		st.set_color(color)
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


func _commit(st: SurfaceTool, mesh_name: String) -> ArrayMesh:
	st.index()
	var mesh: ArrayMesh = st.commit()
	var path: String = OUT_MESHES + mesh_name + ".res"
	ResourceSaver.save(mesh, path)
	mesh.take_over_path(path)
	return mesh


## Küçük parçalar (shadow = false) gölge düşürmez ve uzakta çizilmez: draw call tasarrufu.
func _mesh_node(node_name: String, mesh: Mesh, material: Material, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = SMALL_PART_RANGE
	return mi


func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)


## Tüm düğümlerin sahibini köke ayarlayıp sahneyi kaydeder.
func _save(root: Node, file_name: String) -> void:
	for node: Node in root.find_children("*", "", true, false):
		node.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	var path: String = OUT_SCENES + file_name + ".tscn"
	ResourceSaver.save(packed, path)
	print("kaydedildi: ", path)
	root.free()
