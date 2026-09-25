extends Area2D
## Cœur à ramasser (mode Facile) : rend une vie. Bat doucement et s'efface s'il est ignoré.

const DUREE_DE_VIE := 9.0

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
	sprite.scale = Vector2.ONE * (1.0 + 0.12 * max(0.0, sin(_temps * 5.0)))


## Les contacts ne sont tranchés que par l'hôte (en solo, le poste est son propre hôte).
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	if not body.is_in_group("lion"):
		return
	if _ramassee:  # premier arrivé, premier servi : queue_free() est différé
		return
	_ramassee = true
	GameState.regles.coeur_ramasse(body.joueur)
	Audio.jouer("pickup")
	queue_free()
