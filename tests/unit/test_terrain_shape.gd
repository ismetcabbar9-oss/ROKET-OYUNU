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
