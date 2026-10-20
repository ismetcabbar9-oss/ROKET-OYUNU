class_name LauncherCameraShot
extends Resource
## Fırlatma dizisinin bir aşamasındaki kamera çekimi. Konumlar rampanın yerel uzayında
## (x = sağ, y = yukarı, -z = fırlatma yönü).

## Launcher.Stage değeri (READY, PREPARE, RAISE, LOCK, IGNITE, RELEASE).
@export var stage: int = 0
@export var position: Vector3 = Vector3(12, 4, 10)
## Bakılan nokta; track_missile açıksa füzeye bakılır ve bu değer yok sayılır.
@export var look_at: Vector3 = Vector3(0, 3, 0)
@export var track_missile: bool = false
@export_range(10.0, 120.0, 0.5, "suffix:°") var fov: float = 55.0
## Önceki görüntüden bu çekime geçiş süresi.
@export_range(0.0, 5.0, 0.05, "suffix:s") var blend_seconds: float = 1.0
