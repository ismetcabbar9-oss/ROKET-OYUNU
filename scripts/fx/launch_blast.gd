class_name LaunchBlast
extends Node3D
## Fırlatma anı efekti. Üç tür:
##  GROUND: rampada ateşleme (yere yayılan egzoz bulutu, toz halkası, yanık izi, gürleme)
##  COLD:   silodan gazla atılma (beyaz gaz sütunu, "pof")
##  AIR:    havada ateşleme (kısa alev patlaması, gürleme)
## Yerel +Z, egzozun yönlendirildiği taraftır (rampanın arkası). Kendini temizler.

enum Kind { GROUND, COLD, AIR }

@export var billow: GPUParticles3D
@export var dust: GPUParticles3D
@export var gas: GPUParticles3D
@export var puff: GPUParticles3D
@export var flash: OmniLight3D
@export var scorch: Decal
@export var roar_sound: AudioStreamPlayer3D
@export var pof_sound: AudioStreamPlayer3D
@export var flash_energy: float = 9.0
@export var flash_range: float = 30.0
@export var lifetime: float = 9.0
## Rampadaki yanık izinin kalma süresi.
@export var scorch_lifetime: float = 60.0

var _active: Array[GPUParticles3D] = []


func play(kind: Kind, size: float = 1.0, shake: float = 0.5) -> void:
	match kind:
		Kind.GROUND:
			_active = [billow, dust]
			roar_sound.play()
		Kind.COLD:
			_active = [gas]
			pof_sound.play()
			shake *= 0.4
		Kind.AIR:
			_active = [puff]
			roar_sound.play()
			shake *= 0.6
	for p: GPUParticles3D in [billow, dust, gas, puff]:
		if p in _active:
			_scale_particles(p, size)
			p.restart()
			p.emitting = true
		else:
			p.queue_free()

	if kind == Kind.COLD:
		flash.queue_free()
	else:
		flash.omni_range = flash_range * size
		flash.light_energy = flash_energy
		var tween: Tween = create_tween()
		tween.tween_property(flash, "light_energy", 0.0, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

	if kind == Kind.GROUND:
		scorch.size *= Vector3(size, 1.0, size)
		scorch.rotate_object_local(Vector3.UP, randf() * TAU)
	else:
		scorch.queue_free()

	get_tree().call_group(Explosion.SHAKE_GROUP, &"add_trauma_at", global_position, shake)
	get_tree().create_timer(lifetime).timeout.connect(_on_finished)


## Dünya uzayı parçacıklar düğüm ölçeğinden etkilenmez; boyut ve hız ayrıca çarpılır.
func _scale_particles(p: GPUParticles3D, size: float) -> void:
	if is_equal_approx(size, 1.0):
		return
	var process: ParticleProcessMaterial = (p.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
	process.scale_min *= size
	process.scale_max *= size
	process.initial_velocity_min *= size
	process.initial_velocity_max *= size
	p.process_material = process


func _on_finished() -> void:
	if not is_instance_valid(scorch):
		queue_free()
		return
	# Bulut dağıldı; yanık izi bir süre daha kalıp solar.
	for p: GPUParticles3D in _active:
		p.queue_free()
	if is_instance_valid(flash):
		flash.queue_free()
	var tween: Tween = create_tween()
	tween.tween_interval(maxf(scorch_lifetime - lifetime - 4.0, 0.0))
	tween.tween_property(scorch, "modulate:a", 0.0, 4.0)
	tween.tween_callback(queue_free)
