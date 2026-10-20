class_name LauncherDefinition
extends Resource
## Bir fırlatma rampası türü: aşama süreleri, açılar, sesler, kamera çekimleri ve uyumlu füzeler.
## Yeni rampa eklemek = config/launchers/ altına yeni bir .tres + scenes/launchers/ altına sahne.

enum Kind { TEL, RAIL, SILO }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.TEL
## Bu rampadan atılabilen füzelerin kimlikleri (MissileDefinition.id).
@export var compatible_missiles: Array[StringName] = []

## Aşama başlarken ekranda gösterilen kısa açıklamalar: hazırlık, kaldırma, kilit, ateşleme.
@export var stage_captions: PackedStringArray = ["Hazırlık", "Kaldırma", "Kilitlendi", "Ateşleme!"]

@export_group("Aşama süreleri")
## Uyarı kornası, destek ayakları / kilit açma.
@export_range(0.0, 10.0, 0.05, "suffix:s") var prepare_seconds: float = 1.5
## Ray kalkışı ya da silo kapağının açılması.
@export_range(0.0, 10.0, 0.05, "suffix:s") var raise_seconds: float = 2.5
## Kilit pimleri oturur, füze hazır.
@export_range(0.0, 10.0, 0.05, "suffix:s") var lock_seconds: float = 0.6
## Motor rampada yanar (soğuk fırlatmada: gazla fırlatılıp havada süzülme süresi).
@export_range(0.0, 10.0, 0.05, "suffix:s") var ignite_seconds: float = 0.8
## Ateşleme dizisi "ATLA" ile hızlandırılınca zaman çarpanı.
@export_range(1.0, 20.0, 0.5) var skip_time_scale: float = 5.0

@export_group("Mekanizma")
## Taşıma (bekleme) açısı ve fırlatma açısı (derece, ufka göre).
@export_range(-10.0, 90.0, 0.5, "suffix:°") var stow_angle_deg: float = 20.0
@export_range(0.0, 90.0, 0.5, "suffix:°") var launch_angle_deg: float = 50.0

@export_group("Soğuk fırlatma (silo)")
## Gaz basıncıyla tüpten çıkış hızı; sonrasında yalnızca yerçekimi etkiler.
@export_range(0.0, 80.0, 0.5, "suffix:m/s") var eject_speed: float = 24.0
## Havada ateşlemeden hemen önceki burun açısı (füze tüpten çıkarken buna doğru eğilir).
@export_range(0.0, 90.0, 0.5, "suffix:°") var ignition_pitch_deg: float = 70.0

@export_group("Efektler")
## Fırlatma bulutu, toz ve sarsıntının büyüklük çarpanı.
@export_range(0.2, 4.0, 0.05) var blast_scale: float = 1.0
## Ateşlemede kamera sarsıntısı gücü (0..1).
@export_range(0.0, 1.0, 0.05) var shake_strength: float = 0.55

@export_group("Kamera")
## Aşamalara göre sinematik çekimler (bkz. LauncherCameraShot.stage).
@export var camera_shots: Array[LauncherCameraShot] = []
## Füze ayrıldıktan sonra takip kamerasına geçmeden önce çıkış çekiminde kalma süresi.
@export_range(0.0, 5.0, 0.05, "suffix:s") var release_follow_delay: float = 1.3


func supports(missile: MissileDefinition) -> bool:
	return missile != null and compatible_missiles.has(missile.id)


## Launcher.Stage değeri için açıklama (yoksa boş).
func get_caption(stage: int) -> String:
	var i: int = stage - 1
	return stage_captions[i] if i >= 0 and i < stage_captions.size() else ""


func get_shot(stage: int) -> LauncherCameraShot:
	for shot: LauncherCameraShot in camera_shots:
		if shot.stage == stage:
			return shot
	return null


## Ateşlemeye kadar geçen toplam süre (ATLA kullanılmazsa).
func get_sequence_seconds() -> float:
	return prepare_seconds + raise_seconds + lock_seconds + ignite_seconds
