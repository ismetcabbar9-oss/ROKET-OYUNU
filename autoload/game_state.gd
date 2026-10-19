extends Node
## Bölüm boyunca paylaşılan oyun durumu: skor ve bölüm ilerlemesi.
## Sahneler bu düğüme doğrudan değil, sinyalleri üzerinden bağlanır.

signal score_changed(score: int)

var score: int = 0


func reset() -> void:
	score = 0
	score_changed.emit(score)


func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)
