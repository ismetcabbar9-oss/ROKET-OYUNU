class_name MissileDefinition
extends Resource
## Bir füze türü: görünüm, uçuş hissi ve kamera ayarları tek dosyada.
## Yeni füze eklemek = config/missiles/ altına yeni bir .tres eklemek.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Burnu -Z yönünde, merkezi orijinde olan görsel model sahnesi.
@export var model_scene: PackedScene
@export var flight: MissileFlightSettings

@export_group("Boyutlar")
## Gövde boyu (m): çarpışma kapsülü ve kamera mesafesi buna göre ayarlanır.
@export_range(0.5, 20.0, 0.1, "suffix:m") var length: float = 4.0
@export_range(0.05, 2.0, 0.01, "suffix:m") var body_radius: float = 0.3
## Egzoz alevinin büyüklük çarpanı.
@export_range(0.1, 5.0, 0.05) var exhaust_scale: float = 1.0

@export_group("Kamera")
@export_range(1.0, 60.0, 0.5, "suffix:m") var camera_distance: float = 9.0
@export_range(0.0, 20.0, 0.1, "suffix:m") var camera_height: float = 2.2

@export_group("Savaş başlığı")
## Patlama yarıçapı (hedef/yıkım adımında kullanılacak).
@export_range(1.0, 100.0, 0.5, "suffix:m") var blast_radius: float = 14.0
@export_range(0.0, 10000.0, 10.0) var blast_damage: float = 600.0
## Patlama efektinin görsel büyüklük çarpanı.
@export_range(0.2, 5.0, 0.05) var explosion_scale: float = 1.0
