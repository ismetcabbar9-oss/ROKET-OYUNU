class_name Explosion
extends Node3D
## Tek seferlik patlama efekti: parçacıklar, ışık parlaması, zeminde yanık izi ve kamera sarsıntısı.
## Kullanım: sahneye ekle, global konumu ver, play() çağır. Kendini temizler.

## Kamera sarsıntısı için bu gruba üye düğümlerde add_trauma_at(konum, güç) çağrılır.
const SHAKE_GROUP: StringName = &"camera_shake"

@export var particles: Array[GPUParticles3D] = []
@export var flash: OmniLight3D
@export var scorch: Decal
@export var sound: AudioStreamPlayer3D
@export var flash_energy: float = 12.0
@export var flash_range: float = 40.0
@export var lifetime: float = 7.0
## Zemindeki yanık izinin kalma süresi.
@export var scorch_lifetime: float = 45.0


func play(size: float = 1.0, ground_normal: Vector3 = Vector3.UP, on_ground: bool = true) -> void:
	scale = Vector3.ONE * size
	for p: GPUParticles3D in particles:
		p.restart()
		p.emitting = true

	sound.pitch_scale = clampf(1.15 - size * 0.15, 0.8, 1.1)
	sound.play()
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
	var tween: Tween = create_tween()
	tween.tween_interval(maxf(scorch_lifetime - lifetime - 3.0, 0.0))
	tween.tween_property(scorch, "modulate:a", 0.0, 3.0)
	tween.tween_callback(queue_free)
