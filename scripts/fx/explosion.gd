class_name Explosion
extends Node3D
## Tek seferlik patlama efekti: parçacıklar, ışık parlaması, zeminde yanık izi ve kamera sarsıntısı.
## Ses iki katmanlıdır: yakında çatırtılı patlama, uzakta boğuk gümleme + vadi yankısı. Ses,
## dinleyiciye ses hızıyla gecikerek ulaşır (ışık hemen görünür, gümleme sonra gelir).
## Kullanım: sahneye ekle, global konumu ver, play() çağır. Kendini temizler.

## Kamera sarsıntısı için bu gruba üye düğümlerde add_trauma_at(konum, güç) çağrılır.
const SHAKE_GROUP: StringName = &"camera_shake"
const SPEED_OF_SOUND: float = 343.0

@export var particles: Array[GPUParticles3D] = []
@export var flash: OmniLight3D
@export var scorch: Decal
@export var sound: AudioStreamPlayer3D
## Uzak katman (boğuk gümleme ve yankı kuyruğu).
@export var far_sound: AudioStreamPlayer3D
## Yakın katmanın tamamen uzak katmana devrettiği mesafe aralığı (m).
@export var near_far_start: float = 60.0
@export var near_far_end: float = 450.0
## Ses gecikmesinin üst sınırı (çok uzak patlamalar sonsuza kadar beklemesin).
@export var max_sound_delay: float = 2.5
@export var flash_energy: float = 12.0
@export var flash_range: float = 40.0
@export var lifetime: float = 7.0
## Zemindeki yanık izinin kalma süresi.
@export var scorch_lifetime: float = 45.0


## Füzeye özgü yakın/uzak patlama kayıtları (play'den önce; boş olan sahnedeki varsayılanı korur).
func set_sounds(near: AudioStream, far: AudioStream) -> void:
	if near != null:
		sound.stream = near
	if far != null:
		far_sound.stream = far


func play(size: float = 1.0, ground_normal: Vector3 = Vector3.UP, on_ground: bool = true) -> void:
	scale = Vector3.ONE * size
	for p: GPUParticles3D in particles:
		p.restart()
		p.emitting = true

	sound.pitch_scale = clampf(1.15 - size * 0.15, 0.8, 1.1)
	far_sound.pitch_scale = sound.pitch_scale
	var distance: float = _listener_distance()
	var mix: Vector2 = layer_mix(distance, near_far_start, near_far_end)
	sound.volume_db = linear_to_db(maxf(mix.x, 0.001))
	far_sound.volume_db = linear_to_db(maxf(mix.y, 0.001))
	var delay: float = sound_delay(distance, max_sound_delay)
	if delay > 0.02:
		get_tree().create_timer(delay).timeout.connect(_play_sounds)
	else:
		_play_sounds()
	flash.omni_range = flash_range * size
	flash.light_energy = flash_energy
	var tween: Tween = create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

	if on_ground:
		_place_scorch(ground_normal)
	else:
		scorch.queue_free()

	get_tree().call_group(SHAKE_GROUP, &"add_trauma_at", global_position, size)
	get_tree().create_timer(lifetime).timeout.connect(_on_finished)


## Mesafeye göre katman kazançları: x = yakın, y = uzak (eşit güçte çapraz geçiş).
static func layer_mix(distance: float, start: float, end: float) -> Vector2:
	var t: float = clampf((distance - start) / maxf(end - start, 1.0), 0.0, 1.0)
	return Vector2(cos(t * PI * 0.5), sin(t * PI * 0.5))


static func sound_delay(distance: float, max_delay: float) -> float:
	return clampf(distance / SPEED_OF_SOUND, 0.0, max_delay)


func _listener_distance() -> float:
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera.global_position.distance_to(global_position) if camera != null else 0.0


func _play_sounds() -> void:
	if is_instance_valid(sound):
		sound.play()
	if is_instance_valid(far_sound):
		far_sound.play()


func _place_scorch(normal: Vector3) -> void:
	# Decal -Y yönüne yansıtılır: yerel +Y'yi zemin normaline hizala
	var up: Vector3 = normal.normalized()
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	scorch.global_basis = Basis(side, up, side.cross(up)).scaled(scorch.global_basis.get_scale())
	scorch.rotate_object_local(Vector3.UP, randf() * TAU)


func _on_finished() -> void:
	if not is_instance_valid(scorch):
		queue_free()
		return
	# Parçacıklar bitti; yanık izi bir süre daha kalıp solar.
	for p: GPUParticles3D in particles:
		p.queue_free()
	flash.queue_free()
	sound.queue_free()
	far_sound.queue_free()
	var tween: Tween = create_tween()
	tween.tween_interval(maxf(scorch_lifetime - lifetime - 3.0, 0.0))
	tween.tween_property(scorch, "modulate:a", 0.0, 3.0)
	tween.tween_callback(queue_free)
