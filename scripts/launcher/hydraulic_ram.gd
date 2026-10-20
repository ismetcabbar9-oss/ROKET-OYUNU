class_name HydraulicRam
extends Node3D
## Teleskopik piston: gövde (barrel) sabit bağlantı noktasından, mil (rod) hareketli bağlantı
## noktasından birbirine doğru bakar; aradaki mesafe değiştikçe iç içe kayarlar.
## İki parçanın ağı da kendi orijininden -Z yönünde uzanır. Launcher her pozdan sonra update() çağırır.

## Rampa gövdesindeki bağlantı noktası.
@export var anchor: Node3D
## Hareketli parçadaki (ray/erektör) bağlantı noktası.
@export var attach: Node3D
@export var barrel: Node3D
@export var rod: Node3D


func update() -> void:
	var a: Vector3 = anchor.global_position
	var b: Vector3 = attach.global_position
	if a.is_equal_approx(b):
		return
	var up: Vector3 = Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.FORWARD
	barrel.global_transform = Transform3D(Basis.looking_at(b - a, up), a)
	rod.global_transform = Transform3D(Basis.looking_at(a - b, up), b)
