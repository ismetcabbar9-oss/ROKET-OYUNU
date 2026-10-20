@tool
class_name TerrainShape
extends Resource
## Bir bölümün arazi biçimi: yükseklik fonksiyonu ve tasarım noktaları.
## Hem çevrimdışı arazi üreticisi (tools/godot/generate_terrain.gd) hem de oyun içi
## yerleştirme (ör. hedefleri zemine oturtma) aynı fonksiyonu kullanır.
## Koordinatlar metre; oyun alanı orijin merkezli, kuzey = -Z.

@export_group("Alan")
## Oyun alanının bir kenarı (m). Çözünürlük ile bölünebilir olmalı.
@export var size: float = 2048.0
## Izgara aralığı (m).
@export var resolution: float = 4.0
## Bir arazi parçasının (chunk) kenarı (m).
@export var chunk_size: float = 256.0
@export var noise_seed: int = 4242

@export_group("Vadi")
@export var valley_floor_height: float = 8.0
@export var valley_floor_variation: float = 7.0
## Vadi tabanının yarı genişliği (dağların başladığı mesafe).
@export var valley_half_width: float = 70.0
## Dağların tam yüksekliğe ulaştığı mesafe.
@export var valley_wall_distance: float = 430.0
@export var valley_meander: float = 150.0

@export_group("Dağlar")
@export var mountain_height: float = 230.0
@export var mountain_base: float = 25.0
## Teras (katman) yüksekliği; 0 = teras yok.
@export var terrace_step: float = 22.0
@export var border_rise: float = 180.0

@export_group("Sırt ve kanyon")
## Vadiyi enine kesen sırtın Z konumu.
@export var ridge_z: float = 40.0
@export var ridge_height: float = 120.0
@export var ridge_thickness: float = 75.0
## Sırtı kesen kanyonun yarı genişliği.
@export var canyon_half_width: float = 28.0
@export var canyon_offset: float = 35.0

@export_group("Oyun alanı")
## Vadi orta çizgisinden bu uzaklığa kadar tam detaylı arazi üretilir (m).
@export var full_detail_distance: float = 470.0
## Bu uzaklığa kadar kaba (16 m) kabuk üretilir; ötesi hiç üretilmez, ufuk silueti örter.
@export var coarse_distance: float = 720.0
## Oyuncunun uçabileceği koridorun yarı genişliği (vadi orta çizgisinden, m).
@export var corridor_half_width: float = 420.0
## Kuzey/güney sınırı (|z|, m).
@export var corridor_length_limit: float = 980.0
## Vadi tabanından itibaren uçuş tavanı (m).
@export var ceiling_above_floor: float = 300.0

@export_group("Düz alanlar")
@export var launch_site: Vector3 = Vector3(0.0, 14.0, 780.0)
@export var launch_flat_radius: float = 90.0
@export var target_area: Vector3 = Vector3(0.0, 6.0, -640.0)
@export var target_flat_radius: float = 230.0

@export_group("Tasarlanmış alanlar")
## Beton pistler, avlular: arazi bu dikdörtgenlerde düzleşir.
@export var flat_zones: Array[TerrainFlatZone] = []
## Yollar: arazi yol boyunca düzleşir.
@export var roads: Array[TerrainRoad] = []

var _noise_low: FastNoiseLite
var _noise_ridge: FastNoiseLite
var _noise_detail: FastNoiseLite

const ROAD_CELL: float = 64.0
## Her yol için önbellek: {"points", "heights", "grid", "half_width", "shoulder"}
var _road_cache: Array[Dictionary] = []
var _roads_ready: bool = false


func get_height(x: float, z: float) -> float:
	var h: float = _zoned_height(x, z)
	_ensure_roads()
	for road: Dictionary in _road_cache:
		var hit: Vector2 = _road_query(road, x, z)
		if hit.x >= 0.0:
			h = lerpf(h, hit.y, hit.x)
	return h


## Yolun yoğunlaştırılmış orta çizgisi ve yumuşatılmış yükseklik profili (ağ üretimi için).
## Dönüş: {"points": PackedVector2Array, "heights": PackedFloat32Array, "half_width": float}
func get_road_profile(index: int) -> Dictionary:
	_ensure_roads()
	return _road_cache[index] if index < _road_cache.size() else {}


## Yol önbelleğini sıfırlar (yol/alan verisi değiştiğinde).
func invalidate_cache() -> void:
	_roads_ready = false
	_road_cache.clear()


## Doğal arazi + düzleştirilmiş alanlar (yollar hariç).
func _zoned_height(x: float, z: float) -> float:
	var h: float = _natural_height(x, z)
	for zone: TerrainFlatZone in flat_zones:
		var w: float = zone.get_weight(x, z)
		if w > 0.0:
			h = lerpf(h, zone.center.y, w)
	return h


func _natural_height(x: float, z: float) -> float:
	_ensure_noise()
	var center_x: float = get_valley_center_x(z)
	var d: float = absf(x - center_x)

	var floor_h: float = valley_floor_height + _noise_low.get_noise_2d(x, z) * valley_floor_variation
	var wall: float = smoothstep(valley_half_width, valley_wall_distance, d + _noise_detail.get_noise_2d(x, z) * 40.0)

	# Sırtlı (ridged) gürültü: keskin kanyon dağları
	var ridged: float = 1.0 - absf(_noise_ridge.get_noise_2d(x, z))
	ridged = ridged * ridged
	var mountain: float = mountain_base + ridged * mountain_height
	mountain = _terrace(mountain)

	var h: float = floor_h + mountain * wall

	# Vadiyi enine kesen sırt ve içinden geçen dar kanyon
	var ridge_t: float = (z - ridge_z) / ridge_thickness
	var ridge: float = exp(-ridge_t * ridge_t) * ridge_height
	var canyon: float = smoothstep(canyon_half_width, canyon_half_width * 2.6, absf(x - center_x - canyon_offset))
	h = maxf(h, floor_h + _terrace(ridge) * canyon)

	# Harita kenarına doğru yükselen dağlar (oyuncuyu içeride tutar, ufuk çizgisi)
	var edge: float = maxf(absf(x), absf(z)) / (size * 0.5)
	h += smoothstep(0.72, 1.15, edge) * border_rise * (0.6 + ridged * 0.8)

	# Fırlatma ve hedef alanlarını düzleştir
	h = _flatten(h, x, z, launch_site, launch_flat_radius)
	h = _flatten(h, x, z, target_area, target_flat_radius)
	return h


func _ensure_roads() -> void:
	if _roads_ready:
		return
	_roads_ready = true
	_road_cache.clear()
	for road: TerrainRoad in roads:
		var pts: PackedVector2Array = road.get_dense_points()
		if pts.size() < 2:
			continue
		# Profil: alanlar dahil araziden örneklenir ve yumuşatılır (yokuşlar keskin olmasın)
		var heights := PackedFloat32Array()
		for p: Vector2 in pts:
			heights.append(_zoned_height(p.x, p.y))
		for _pass: int in 3:
			var smoothed := heights.duplicate()
			for i: int in heights.size():
				var sum: float = 0.0
				var count: int = 0
				for k: int in range(maxi(i - 4, 0), mini(i + 5, heights.size())):
					sum += heights[k]
					count += 1
				smoothed[i] = sum / count
			heights = smoothed
		var reach: float = road.width * 0.5 + road.shoulder
		var grid: Dictionary = {}
		for i: int in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var lo := Vector2i(floori((minf(a.x, b.x) - reach) / ROAD_CELL), floori((minf(a.y, b.y) - reach) / ROAD_CELL))
			var hi := Vector2i(floori((maxf(a.x, b.x) + reach) / ROAD_CELL), floori((maxf(a.y, b.y) + reach) / ROAD_CELL))
			for cx: int in range(lo.x, hi.x + 1):
				for cz: int in range(lo.y, hi.y + 1):
					var key := Vector2i(cx, cz)
					if not grid.has(key):
						grid[key] = PackedInt32Array()
					var list: PackedInt32Array = grid[key]
					list.append(i)
					grid[key] = list
		_road_cache.append({"points": pts, "heights": heights, "grid": grid,
			"half_width": road.width * 0.5, "shoulder": road.shoulder})


## Yol etkisi: x = ağırlık (yol dışı -1), y = yolun o noktadaki yüksekliği.
func _road_query(road: Dictionary, x: float, z: float) -> Vector2:
	var grid: Dictionary = road["grid"]
	var key := Vector2i(floori(x / ROAD_CELL), floori(z / ROAD_CELL))
	if not grid.has(key):
		return Vector2(-1.0, 0.0)
	var pts: PackedVector2Array = road["points"]
	var heights: PackedFloat32Array = road["heights"]
	var p := Vector2(x, z)
	var best: float = INF
	var best_h: float = 0.0
	for i: int in grid[key] as PackedInt32Array:
		var a: Vector2 = pts[i]
		var ab: Vector2 = pts[i + 1] - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d: float = p.distance_to(a + ab * t)
		if d < best:
			best = d
			best_h = lerpf(heights[i], heights[i + 1], t)
	var half_width: float = road["half_width"]
	var shoulder: float = road["shoulder"]
	if best > half_width + shoulder:
		return Vector2(-1.0, 0.0)
	return Vector2(1.0 - smoothstep(half_width, half_width + shoulder, best), best_h)


## Vadi orta çizgisine yatay uzaklık (m).
func distance_to_valley(x: float, z: float) -> float:
	return absf(x - get_valley_center_x(z))


## Oyuncunun uçmasına izin verilen hacmin içinde mi? (görünmez sınır)
func is_in_play_area(pos: Vector3) -> bool:
	return distance_to_valley(pos.x, pos.z) <= corridor_half_width \
		and absf(pos.z) <= corridor_length_limit \
		and pos.y <= valley_floor_height + ceiling_above_floor


## Vadi orta çizgisinin verilen Z'deki X konumu.
func get_valley_center_x(z: float) -> float:
	return valley_meander * sin(z * 0.0032) + valley_meander * 0.4 * sin(z * 0.0105 + 1.3)


func get_normal(x: float, z: float, step: float = 1.0) -> Vector3:
	var hx: float = get_height(x + step, z) - get_height(x - step, z)
	var hz: float = get_height(x, z + step) - get_height(x, z - step)
	return Vector3(-hx, 2.0 * step, -hz).normalized()


func _terrace(h: float) -> float:
	if terrace_step <= 0.0:
		return h
	var s: float = h / terrace_step
	var f: float = s - floorf(s)
	return (floorf(s) + smoothstep(0.15, 0.85, f)) * terrace_step


func _flatten(h: float, x: float, z: float, center: Vector3, radius: float) -> float:
	var dist: float = Vector2(x - center.x, z - center.z).length()
	var t: float = 1.0 - smoothstep(radius, radius * 1.8, dist)
	return lerpf(h, center.y, t)


func _ensure_noise() -> void:
	if _noise_low != null:
		return
	_noise_low = FastNoiseLite.new()
	_noise_low.seed = noise_seed
	_noise_low.frequency = 0.004
	_noise_low.fractal_octaves = 3

	_noise_ridge = FastNoiseLite.new()
	_noise_ridge.seed = noise_seed + 1
	_noise_ridge.frequency = 0.0022
	_noise_ridge.fractal_octaves = 4
	_noise_ridge.fractal_lacunarity = 2.1

	_noise_detail = FastNoiseLite.new()
	_noise_detail.seed = noise_seed + 2
	_noise_detail.frequency = 0.01
	_noise_detail.fractal_octaves = 2
