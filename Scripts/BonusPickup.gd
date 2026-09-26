extends Pastille
## Étoile arc-en-ciel : double le rayon de la gerbe pendant quelques secondes.
## Disparaît d'elle-même si personne ne la ramasse.

const DUREE_DE_VIE := 7.0

@onready var sprite: Sprite2D = $Sprite2D

var _temps := 0.0


func _ready() -> void:
	var tween := create_tween()
	tween.tween_interval(DUREE_DE_VIE - 1.5)
	tween.tween_property(sprite, "modulate:a", 0.0, 1.5)
	tween.tween_callback(_expirer)


func _process(delta: float) -> void:
	_temps += delta
	sprite.modulate = Color.from_hsv(fmod(_temps * 0.6, 1.0), 0.8, 1.0, sprite.modulate.a)
	sprite.scale = Vector2.ONE * (1.2 + 0.15 * sin(_temps * 6.0))
	sprite.rotation = _temps * 1.5


func _ramasser(joueur: Joueur) -> void:
	GameState.regles.etoile_ramassee(joueur)
