extends Area2D
## Pastille ramassée par le lion qui la touche ; son effet dépend des règles (en solo, une couleur de l'arc-en-ciel).

@export var couleur_index: int = 0


func _ready() -> void:
	$Sprite2D.modulate = GameState.couleur(couleur_index)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("lion"):
		return
	GameState.regles.pastille_ramassee(body.joueur, couleur_index)
	queue_free()
