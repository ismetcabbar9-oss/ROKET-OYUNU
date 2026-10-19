class_name MissileState
extends RefCounted
## Füzenin anlık uçuş durumu. Yönelim yaw/pitch olarak tutulur, böylece ufuk
## her zaman düz kalır (yaw-pitch karışımından istenmeyen yuvarlanma birikmez).
## Açılar radyan, hızlar m/s.

var position: Vector3 = Vector3.ZERO
## Dünya Y ekseni etrafında yön (0 = -Z yönü).
var yaw: float = 0.0
## Yatay düzleme göre burun açısı (pozitif = yukarı).
var pitch: float = 0.0
## Yalnızca görsel yatış.
var bank: float = 0.0
## Açısal hızlar (rad/s): x = sapma (pozitif = sağa), y = yunuslama (pozitif = yukarı).
var turn_rate: Vector2 = Vector2.ZERO
var speed: float = 0.0
var fuel: float = 0.0
var flight_time: float = 0.0


func get_forward() -> Vector3:
	return Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3.FORWARD


func get_velocity() -> Vector3:
	return get_forward() * speed


## Yatış dahil görsel yönelim.
func get_basis() -> Basis:
	return Basis.from_euler(Vector3(pitch, yaw, bank))


func get_transform() -> Transform3D:
	return Transform3D(get_basis(), position)
