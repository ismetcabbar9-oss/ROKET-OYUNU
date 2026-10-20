class_name AmbientSoundSettings
extends Resource
## Bölümün ortam sesi ayarları (rüzgâr, üs uğultusu, yankı bölgeleri).

@export_group("Rüzgâr")
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var wind_volume_db: float = -9.0
## Esintilerin ses seviyesine etkisi (± dB).
@export_range(0.0, 20.0, 0.5, "suffix:dB") var gust_depth_db: float = 5.0
## Esinti sıklığı (düşük = yavaş, uzun esintiler).
@export_range(0.01, 2.0, 0.01) var gust_frequency: float = 0.12

@export_group("Üs uğultusu")
## Jeneratör uğultusu çalan düz alanlar (TerrainFlatZone.name).
@export var hum_zones: PackedStringArray = ["Servis alanı", "Yakıt deposu", "Hedef kompleksi"]
@export_range(-60.0, 6.0, 0.5, "suffix:dB") var hum_volume_db: float = -8.0

@export_group("Yankı")
## Kanyon geçidinde ve sırtın ardındaki vadide "Canyon" veri yoluna gönderilen pay (0..1).
@export_range(0.0, 1.0, 0.01) var canyon_reverb_amount: float = 0.75
@export_range(0.0, 1.0, 0.01) var valley_reverb_amount: float = 0.3
