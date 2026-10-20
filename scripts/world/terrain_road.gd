@tool
class_name TerrainRoad
extends Resource
## Arazide yol koridoru. Kontrol noktaları (x, z) yumuşatılarak yoğunlaştırılır; arazi yol boyunca
## enine düz, boyuna yumuşak bir profile oturtulur ve yolun üstüne şerit ağı üretilir.

@export var name: String = ""
## Kontrol noktaları: x = dünya X, y = dünya Z.
@export var points: PackedVector2Array = PackedVector2Array()
@export_range(2.0, 30.0, 0.5, "suffix:m") var width: float = 9.0
## Yol kenarından itibaren arazinin yola yumuşakça bağlandığı mesafe.
@export_range(1.0, 60.0, 0.5, "suffix:m") var shoulder: float = 14.0
@export var surface: TerrainFlatZone.Surface = TerrainFlatZone.Surface.ASPHALT
## Yoğunlaştırma aralığı (m).
@export var sample_spacing: float = 6.0


## Catmull-Rom ile yumuşatılmış, yaklaşık sample_spacing aralıklı orta çizgi noktaları.
func get_dense_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.size() < 2:
		return points
	for i: int in points.size() - 1:
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, points.size() - 1)]
		var steps: int = maxi(1, ceili(p1.distance_to(p2) / sample_spacing))
		for s: int in steps:
			var t: float = float(s) / steps
			out.append(_catmull_rom(p0, p1, p2, p3, t))
	out.append(points[points.size() - 1])
	return out


static func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
