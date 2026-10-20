extends GutTest
## Arazi biçimi: tasarım noktaları düz, vadi tabanı geçilebilir, kanyon açık.

var shape: TerrainShape


func before_each() -> void:
	shape = load("res://config/terrain/valley_01.tres") as TerrainShape


func test_launch_and_target_areas_are_flat() -> void:
	for p: Vector3 in [shape.launch_site, shape.target_area]:
		for offset: Vector2 in [Vector2.ZERO, Vector2(20, 0), Vector2(0, -20), Vector2(-15, 15)]:
			assert_almost_eq(shape.get_height(p.x + offset.x, p.z + offset.y), p.y, 0.5)


func test_launch_and_target_are_on_valley_floor() -> void:
	assert_almost_eq(shape.launch_site.x, shape.get_valley_center_x(shape.launch_site.z), 5.0)
	assert_almost_eq(shape.target_area.x, shape.get_valley_center_x(shape.target_area.z), 5.0)


func test_ridge_blocks_valley_but_canyon_is_open() -> void:
	var cx: float = shape.get_valley_center_x(shape.ridge_z)
	var canyon_floor: float = shape.get_height(cx + shape.canyon_offset, shape.ridge_z)
	var ridge_top: float = shape.get_height(cx - shape.canyon_offset * 2.0, shape.ridge_z)
	assert_lt(canyon_floor, shape.valley_floor_height + shape.valley_floor_variation + 2.0, "kanyon tabanı alçak olmalı")
	assert_gt(ridge_top, 80.0, "sırt vadiyi kapatmalı")


func test_height_is_deterministic() -> void:
	var other: TerrainShape = shape.duplicate() as TerrainShape
	assert_eq(other.get_height(123.0, -456.0), shape.get_height(123.0, -456.0))


func test_play_area_bounds() -> void:
	var z: float = 300.0
	var cx: float = shape.get_valley_center_x(z)
	assert_true(shape.is_in_play_area(Vector3(cx, 50.0, z)), "vadi ortası içeride")
	assert_false(shape.is_in_play_area(Vector3(cx + shape.corridor_half_width + 10.0, 50.0, z)), "koridor dışı")
	assert_false(shape.is_in_play_area(Vector3(cx, shape.valley_floor_height + shape.ceiling_above_floor + 5.0, z)), "tavan üstü")
	assert_false(shape.is_in_play_area(Vector3(0.0, 50.0, shape.corridor_length_limit + 10.0)), "güney sınırı dışı")
	assert_true(shape.is_in_play_area(shape.launch_site + Vector3.UP * 3.0), "rampa içeride")
	assert_true(shape.is_in_play_area(shape.target_area + Vector3.UP * 3.0), "hedef içeride")


func test_flat_zones_are_level() -> void:
	assert_gt(shape.flat_zones.size(), 0)
	for zone: TerrainFlatZone in shape.flat_zones:
		for local: Vector2 in [Vector2.ZERO, Vector2(0.9, 0.9), Vector2(-0.9, 0.5), Vector2(0.4, -0.9)]:
			var p: Vector3 = zone.to_world(local * zone.half_size)
			# Yol bir alana girebilir; o zaman yol profili alanla aynı yüksekliğe yakın kalmalı
			assert_almost_eq(shape.get_height(p.x, p.z), zone.center.y, 1.5, zone.name)


func test_flat_zone_geometry() -> void:
	var zone := TerrainFlatZone.new()
	zone.center = Vector3(10, 5, 20)
	zone.half_size = Vector2(4, 8)
	zone.heading_deg = 90.0
	# 90°: ileri = +X; ileri yarı boyu 8 m
	assert_almost_eq(zone.distance_outside(17.0, 20.0), 0.0, 0.001)
	assert_almost_eq(zone.distance_outside(20.0, 20.0), 2.0, 0.001)
	assert_almost_eq(zone.distance_outside(10.0, 26.0), 2.0, 0.001)
	assert_eq(zone.get_weight(10.0, 20.0), 1.0)


func test_road_is_flat_across_and_smooth_along() -> void:
	assert_gt(shape.roads.size(), 0)
	var profile: Dictionary = shape.get_road_profile(0)
	var pts: PackedVector2Array = profile["points"]
	var heights: PackedFloat32Array = profile["heights"]
	var max_grade: float = 0.0
	for i: int in range(1, pts.size()):
		max_grade = maxf(max_grade, absf(heights[i] - heights[i - 1]) / maxf(pts[i].distance_to(pts[i - 1]), 0.01))
	assert_lt(max_grade, 0.2, "yol eğimi %20'den az olmalı")
	# Orta çizgi ile kenar aynı yükseklikte
	var i_mid: int = pts.size() / 2
	var dir: Vector2 = (pts[i_mid + 1] - pts[i_mid]).normalized()
	var side := Vector2(-dir.y, dir.x) * 3.0
	var center_h: float = shape.get_height(pts[i_mid].x, pts[i_mid].y)
	assert_almost_eq(shape.get_height(pts[i_mid].x + side.x, pts[i_mid].y + side.y), center_h, 0.3)


func test_road_stays_in_play_area() -> void:
	var pts: PackedVector2Array = shape.get_road_profile(0)["points"]
	for p: Vector2 in pts:
		assert_true(shape.is_in_play_area(Vector3(p.x, 20.0, p.y)), "yol oyun alanında: %s" % p)
