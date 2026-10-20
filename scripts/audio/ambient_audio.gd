class_name AmbientAudio
extends Node3D
## Bölümün ortam sesleri: esintili çöl rüzgârı (konumsuz), üs bölgelerinde jeneratör uğultusu
## (konumlu) ve vadide yankı bölgeleri (Area3D -> "Canyon" yankı veri yolu).
## Konumlar TerrainShape'ten okunur; arazi değişince ortam sesi de kendiliğinden yerine oturur.

const REVERB_BUS: StringName = &"Canyon"

@export var terrain_shape: TerrainShape
@export var settings: AmbientSoundSettings
@export var wind: AudioStreamPlayer
## Jeneratör uğultusunun kopyalanacağı örnek oynatıcı (her üs bölgesine bir tane).
@export var hum_template: AudioStreamPlayer3D

var _noise := FastNoiseLite.new()
var _time: float = 0.0
var _hums: Array[AudioStreamPlayer3D] = []


func _ready() -> void:
	if settings == null:
		settings = AmbientSoundSettings.new()
	_noise.frequency = settings.gust_frequency
	_noise.seed = 77
	wind.volume_db = settings.wind_volume_db
	wind.play()
	if terrain_shape != null:
		_place_hums()
		_place_reverb_zones()


func _process(delta: float) -> void:
	_time += delta
	# Esinti: yavaş gürültüyle ses seviyesi ve perde dalgalanır
	var gust: float = _noise.get_noise_1d(_time)
	wind.volume_db = settings.wind_volume_db + gust * settings.gust_depth_db
	wind.pitch_scale = 1.0 + gust * 0.06


## Bir bölgenin yankı kutusu (kanyon geçidi ya da vadi): merkez, boyut, yankı payı.
func get_reverb_zones() -> Array[Dictionary]:
	var s: TerrainShape = terrain_shape
	var zones: Array[Dictionary] = []
	var canyon_x: float = s.get_valley_center_x(s.ridge_z) + s.canyon_offset
	zones.append({
		"name": "KanyonYankisi",
		"center": Vector3(canyon_x, s.get_height(canyon_x, s.ridge_z) + 60.0, s.ridge_z),
		"size": Vector3(s.canyon_half_width * 2.0 * 1.6, 160.0, s.ridge_thickness * 2.2),
		"amount": settings.canyon_reverb_amount,
		"priority": 2,
	})
	# Sırtın kuzeyindeki vadi: daha hafif, geniş yankı (duvarlardan dönen gümlemeler)
	var valley_z: float = s.ridge_z - 380.0
	var valley_x: float = s.get_valley_center_x(valley_z)
	zones.append({
		"name": "VadiYankisi",
		"center": Vector3(valley_x, s.valley_floor_height + 90.0, valley_z),
		"size": Vector3(s.valley_half_width * 2.0 + 260.0, 260.0, 560.0),
		"amount": settings.valley_reverb_amount,
		"priority": 1,
	})
	return zones


func _place_hums() -> void:
	for zone: TerrainFlatZone in terrain_shape.flat_zones:
		if not settings.hum_zones.has(zone.name):
			continue
		var hum: AudioStreamPlayer3D = hum_template.duplicate() as AudioStreamPlayer3D
		hum.name = "Hum_" + zone.name.validate_node_name()
		add_child(hum)
		hum.global_position = zone.center + Vector3.UP * 3.0
		hum.volume_db = settings.hum_volume_db
		hum.play()
		_hums.append(hum)


func _place_reverb_zones() -> void:
	for zone: Dictionary in get_reverb_zones():
		var area := Area3D.new()
		area.name = zone["name"]
		area.monitoring = false
		area.monitorable = false
		area.collision_layer = 1
		area.collision_mask = 0
		area.priority = zone["priority"]
		area.reverb_bus_enabled = true
		area.reverb_bus_name = REVERB_BUS
		area.reverb_bus_amount = zone["amount"]
		area.reverb_bus_uniformity = 0.4
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = zone["size"]
		shape.shape = box
		area.add_child(shape)
		add_child(area)
		area.global_position = zone["center"]
