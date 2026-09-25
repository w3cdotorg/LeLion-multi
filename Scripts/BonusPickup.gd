extends Area2D
## Étoile arc-en-ciel : double le rayon de la gerbe pendant quelques secondes.
## Disparaît d'elle-même si personne ne la ramasse.

const DUREE_DE_VIE := 7.0

@onready var sprite: Sprite2D = $Sprite2D

var _temps := 0.0
var _ramassee := false


func _ready() -> void:
	var tween := create_tween()
	tween.tween_interval(DUREE_DE_VIE - 1.5)
	tween.tween_property(sprite, "modulate:a", 0.0, 1.5)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	_temps += delta
	sprite.modulate = Color.from_hsv(fmod(_temps * 0.6, 1.0), 0.8, 1.0, sprite.modulate.a)
	sprite.scale = Vector2.ONE * (1.2 + 0.15 * sin(_temps * 6.0))
	sprite.rotation = _temps * 1.5


## Les contacts ne sont tranchés que par l'hôte (en solo, le poste est son propre hôte).
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	if not body.is_in_group("lion"):
		return
	if _ramassee:  # premier arrivé, premier servi : queue_free() est différé
		return
	_ramassee = true
	GameState.regles.etoile_ramassee(body.joueur)
	Audio.jouer("pickup")
	queue_free()
