class_name MissileExhaust
extends Node3D
## Füzenin kuyruğundaki motor görselleri: alev konisi, titreşen ışık ve duman izi.
## Füze bu düğümü kuyruğa yerleştirir ve throttle'ı (0..1) her karede ayarlar.

@export var flame: MeshInstance3D
@export var light: OmniLight3D
@export var smoke: GPUParticles3D
@export var motor_sound: AudioStreamPlayer3D
@export var light_energy: float = 3.0

var _throttle: float = 0.0
var _flame_material: ShaderMaterial


func _ready() -> void:
	_flame_material = flame.get_surface_override_material(0) as ShaderMaterial
	set_throttle(0.0)


## Ölçeği füze türüne göre ayarlar (alev boyu, ışık menzili, duman kalınlığı).
func configure(exhaust_scale: float) -> void:
	scale = Vector3.ONE * exhaust_scale
	light.omni_range = 9.0 * exhaust_scale
	var process: ParticleProcessMaterial = smoke.process_material as ParticleProcessMaterial
	# Ölçek düğüm ölçeğine bağlı değil (dünya uzayı parçacıklar), bu yüzden ayrıca ayarlanır.
	process.scale_min = 1.6 * exhaust_scale
	process.scale_max = 2.6 * exhaust_scale


func set_throttle(value: float) -> void:
	_throttle = clampf(value, 0.0, 1.0)
	var on: bool = _throttle > 0.01
	flame.visible = on
	_flame_material.set_shader_parameter(&"throttle", _throttle)
	smoke.emitting = on
	if on and not motor_sound.playing:
		motor_sound.play()
	elif not on and motor_sound.playing:
		motor_sound.stop()


## Motor sesinin perdesini hıza göre ayarlar (0..1 arası hız oranı).
func set_speed_ratio(ratio: float) -> void:
	motor_sound.pitch_scale = lerpf(0.85, 1.25, clampf(ratio, 0.0, 1.0))


## Füze yok olurken duman izini dünyaya bırakır; iz kendi ömrünü tamamlayıp silinir.
func detach_trail(world: Node) -> void:
	var xform: Transform3D = smoke.global_transform
	smoke.emitting = false
	smoke.reparent(world)
	smoke.global_transform = xform
	var tree: SceneTree = world.get_tree()
	var trail: GPUParticles3D = smoke
	tree.create_timer(smoke.lifetime + 0.5).timeout.connect(trail.queue_free)


func _process(_delta: float) -> void:
	if _throttle <= 0.01:
		light.light_energy = 0.0
		return
	var t: float = Time.get_ticks_msec() * 0.001
	light.light_energy = light_energy * _throttle * (0.85 + 0.15 * sin(t * 37.0) * sin(t * 13.0))
