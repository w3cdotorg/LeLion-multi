extends Area2D
## Pastille ramassée par le lion qui la touche ; son effet dépend des règles (en solo, une couleur de l'arc-en-ciel).

@export var couleur_index: int = 0

var _ramassee := false


func _ready() -> void:
	$Sprite2D.modulate = GameState.couleur(couleur_index)


## Les contacts ne sont tranchés que par l'hôte (en solo, le poste est son propre hôte).
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	if not body.is_in_group("lion"):
		return
	if _ramassee:  # premier arrivé, premier servi : queue_free() est différé
		return
	_ramassee = true
	GameState.regles.pastille_ramassee(body.joueur, couleur_index)
	queue_free()
