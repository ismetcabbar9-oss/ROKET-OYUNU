extends GutTest
## Ses sistemi: veri yolları, motor katman geçişleri, patlama gecikmesi/katmanları, ortam yerleşimi.

const DT: float = 1.0 / 60.0


func test_buses_exist_and_route_to_master() -> void:
	for bus: String in ["SFX", "Ambient", "UI", "Canyon"]:
		var i: int = AudioServer.get_bus_index(bus)
		assert_gt(i, 0, "%s veri yolu var" % bus)
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index("Canyon")), &"SFX", "yankı efektlere gider")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index("SFX")), &"Master")


func test_user_settings_drive_bus_volume() -> void:
	var before: float = UserSettings.sfx_volume
	UserSettings.sfx_volume = 0.5
	UserSettings.apply_audio()
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), linear_to_db(0.5), 0.01)
	UserSettings.sfx_volume = 0.0
	UserSettings.apply_audio()
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "sıfır seviye = sessiz")
	UserSettings.sfx_volume = before
	UserSettings.apply_audio()


func test_booster_hands_over_to_sustainer() -> void:
	var s := MissileSoundSettings.new()
	s.booster_seconds = 2.0
	s.booster_crossfade_seconds = 1.0
	var early: Vector3 = MissileAudio.layer_gains(s, 0.5, 10.0, 30.0)
	assert_almost_eq(early.x, 1.0, 0.001, "başta booster tam")
	assert_almost_eq(early.y, 0.0, 0.001)
	var mid: Vector3 = MissileAudio.layer_gains(s, 2.5, 10.0, 30.0)
	assert_almost_eq(mid.x * mid.x + mid.y * mid.y, 1.0, 0.001, "geçişte toplam güç sabit")
	var late: Vector3 = MissileAudio.layer_gains(s, 5.0, 10.0, 30.0)
	assert_almost_eq(late.y, 1.0, 0.001, "sonra sustainer tam")
	assert_almost_eq(late.x, 0.0, 0.001)


func test_engine_silent_after_burnout_but_air_remains() -> void:
	var s := MissileSoundSettings.new()
	s.air_full_speed = 100.0
	var g: Vector3 = MissileAudio.layer_gains(s, 20.0, 0.0, 100.0)
	assert_eq(g.x, 0.0)
	assert_eq(g.y, 0.0)
	assert_almost_eq(g.z, 1.0, 0.001, "hava sesi hızla sürer")
	assert_lt(MissileAudio.layer_gains(s, 1.0, 5.0, 30.0).z, 0.1, "yavaşken hava sesi zayıf")


func test_missile_audio_ignites_and_plays_burnout_once() -> void:
	var missile: Missile = (load("res://scenes/missile/missile.tscn") as PackedScene).instantiate() as Missile
	add_child_autofree(missile)
	missile.setup(load("res://config/missiles/sahin.tres") as MissileDefinition)
	var audio: MissileAudio = missile.audio
	audio.update(0.0, 5.0, 0.0, DT)
	assert_false(audio.booster.playing, "ateşlenmeden ses yok")
	missile.ignite_on_rail()
	for i: int in 30:
		audio.update(i * DT, 5.0, 20.0, DT)
	assert_true(audio.booster.playing, "rampada booster çalıyor")
	audio.update(1.0, 0.0, 60.0, DT)
	assert_true(audio.burnout.playing, "yakıt bitince sönme sesi")
	for i: int in 120:
		audio.update(1.0 + i * DT, 0.0, 60.0, DT)
	assert_false(audio.booster.playing, "yakıt bitince booster susar")


func test_explosion_sound_delay_follows_speed_of_sound() -> void:
	assert_almost_eq(Explosion.sound_delay(343.0, 3.0), 1.0, 0.001)
	assert_almost_eq(Explosion.sound_delay(0.0, 3.0), 0.0, 0.001)
	assert_almost_eq(Explosion.sound_delay(5000.0, 2.5), 2.5, 0.001, "üst sınır")


func test_explosion_layers_cross_fade_with_distance() -> void:
	var near: Vector2 = Explosion.layer_mix(20.0, 60.0, 450.0)
	assert_almost_eq(near.x, 1.0, 0.001)
	assert_almost_eq(near.y, 0.0, 0.001)
	var far: Vector2 = Explosion.layer_mix(1000.0, 60.0, 450.0)
	assert_almost_eq(far.y, 1.0, 0.001)
	var mid: Vector2 = Explosion.layer_mix(255.0, 60.0, 450.0)
	assert_almost_eq(mid.x * mid.x + mid.y * mid.y, 1.0, 0.001)


func test_ambient_places_reverb_and_hums() -> void:
	var ambient: AmbientAudio = (load("res://scenes/audio/ambient_audio.tscn") as PackedScene).instantiate() as AmbientAudio
	ambient.terrain_shape = load("res://config/terrain/valley_01.tres") as TerrainShape
	add_child_autofree(ambient)
	var areas: Array[Node] = ambient.find_children("*", "Area3D", false, false)
	assert_eq(areas.size(), 2, "kanyon + vadi yankısı")
	for node: Node in areas:
		var area: Area3D = node as Area3D
		assert_true(area.reverb_bus_enabled)
		assert_eq(area.reverb_bus_name, AmbientAudio.REVERB_BUS)
	var canyon: Area3D = ambient.get_node("KanyonYankisi") as Area3D
	var s: TerrainShape = ambient.terrain_shape
	var through_canyon := Vector3(s.get_valley_center_x(s.ridge_z) + s.canyon_offset, s.get_height(s.get_valley_center_x(s.ridge_z) + s.canyon_offset, s.ridge_z) + 18.0, s.ridge_z)
	var box: BoxShape3D = (canyon.get_child(0) as CollisionShape3D).shape as BoxShape3D
	assert_true(AABB(canyon.global_position - box.size * 0.5, box.size).has_point(through_canyon), "kanyondan geçen füze yankı alanında")
	var hums: int = 0
	for node: Node in ambient.get_children():
		if node.name.begins_with("Hum_"):
			hums += 1
	assert_eq(hums, 3, "üç üs bölgesinde uğultu")
