extends Pastille
## Cœur à ramasser (mode Facile) : rend une vie. Bat doucement et s'efface s'il est ignoré.

const DUREE_DE_VIE := 9.0

@onready var sprite: Sprite2D = $Sprite2D

var _temps := 0.0


func _ready() -> void:
	var tween := create_tween()
	tween.tween_interval(DUREE_DE_VIE - 1.5)
	tween.tween_property(sprite, "modulate:a", 0.0, 1.5)
	tween.tween_callback(_expirer)


func _process(delta: float) -> void:
	_temps += delta
	sprite.scale = Vector2.ONE * (1.0 + 0.12 * max(0.0, sin(_temps * 5.0)))


func _ramasser(joueur: Joueur) -> void:
	GameState.regles.coeur_ramasse(joueur)
