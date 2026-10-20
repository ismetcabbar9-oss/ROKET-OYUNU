@tool
class_name TerrainFlatZone
extends Resource
## Arazide düzleştirilen dikdörtgen alan (beton pist, üs avlusu vb.).
## Arazi bu alanda center.y yüksekliğine iner/çıkar; kenarda falloff mesafesinde yumuşakça birleşir.

enum Surface { NONE, CONCRETE, ASPHALT, GRAVEL }

@export var name: String = ""
## x/z konum, y = alanın yüksekliği (m).
@export var center: Vector3 = Vector3.ZERO
## Yarı genişlik (x = sağ/sol, y = ileri/geri), metre.
@export var half_size: Vector2 = Vector2(20.0, 20.0)
## İleri yönünün kuzeyden (-Z) doğuya (+X) açısı (derece).
@export_range(-180.0, 180.0, 0.1, "suffix:°") var heading_deg: float = 0.0
@export_range(1.0, 200.0, 0.5, "suffix:m") var falloff: float = 25.0
## Üzerine kaplama (beton plaka vb.) üretilsin mi?
@export var surface: Surface = Surface.CONCRETE


func get_forward() -> Vector3:
	var h: float = deg_to_rad(heading_deg)
	return Vector3(sin(h), 0.0, -cos(h))


func get_right() -> Vector3:
	var h: float = deg_to_rad(heading_deg)
	return Vector3(cos(h), 0.0, sin(h))


## Dikdörtgenin dışına olan yatay uzaklık (içeride 0).
func distance_outside(x: float, z: float) -> float:
	var d := Vector3(x - center.x, 0.0, z - center.z)
	var q := Vector2(absf(d.dot(get_right())) - half_size.x, absf(d.dot(get_forward())) - half_size.y)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length()


## Bu alanın arazi yüksekliğine etkisi (0 = yok, 1 = tamamen düz).
func get_weight(x: float, z: float) -> float:
	return 1.0 - smoothstep(0.0, falloff, distance_outside(x, z))


## Alanın yerel (sağ, ileri) koordinatını dünya konumuna çevirir (yükseklik center.y).
func to_world(local: Vector2) -> Vector3:
	return Vector3(center.x, center.y, center.z) + get_right() * local.x + get_forward() * local.y
