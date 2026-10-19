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

@export_group("Düz alanlar")
@export var launch_site: Vector3 = Vector3(0.0, 14.0, 780.0)
@export var launch_flat_radius: float = 90.0
@export var target_area: Vector3 = Vector3(0.0, 6.0, -640.0)
@export var target_flat_radius: float = 230.0

var _noise_low: FastNoiseLite
var _noise_ridge: FastNoiseLite
var _noise_detail: FastNoiseLite


func get_height(x: float, z: float) -> float:
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
