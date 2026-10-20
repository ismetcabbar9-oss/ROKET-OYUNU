class_name MissileSoundSettings
extends Resource
## Bir füzenin motor ve uçuş sesi ayarları (MissileDefinition.sound).
## Katmanlar: ateşleme çatlaması -> booster gürlemesi -> sustainer -> yakıt bitişi; hava sürtünmesi
## hıza göre tüm uçuş boyunca. Seviyeler dB, perdeler çarpan.

@export_group("Kayıtlar")
## Füzeye özgü motor döngüleri ve patlama sesleri; boş bırakılan sahnedeki varsayılanı kullanır.
@export var booster_stream: AudioStream
@export var sustainer_stream: AudioStream
@export var explosion_near: AudioStream
@export var explosion_far: AudioStream

@export_group("Motor")
## Fırlatmadan sonra booster gürlemesinin sürdüğü süre; sonra sustainer'a geçilir.
@export_range(0.0, 30.0, 0.1, "suffix:s") var booster_seconds: float = 2.5
@export_range(0.1, 5.0, 0.05, "suffix:s") var booster_crossfade_seconds: float = 0.8
@export_range(0.3, 2.0, 0.01) var booster_pitch: float = 1.0
@export_range(0.3, 2.0, 0.01) var sustainer_pitch: float = 1.0
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var engine_volume_db: float = 0.0
## Hız arttıkça motor perdesine eklenen pay (en yüksek hızda).
@export_range(0.0, 1.0, 0.01) var speed_pitch_gain: float = 0.25

@export_group("Hava sürtünmesi")
## Bu hızda hava sesi tam seviyeye ulaşır.
@export_range(10.0, 400.0, 1.0, "suffix:m/s") var air_full_speed: float = 120.0
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var air_volume_db: float = -9.0
@export_range(0.3, 2.0, 0.01) var air_pitch_min: float = 0.8
@export_range(0.3, 3.0, 0.01) var air_pitch_max: float = 1.35
