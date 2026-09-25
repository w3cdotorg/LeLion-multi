extends Area2D
## Ennemi : traverse l'écran de gauche à droite en ligne droite.

@export var speed: float = 150.0


func _physics_process(delta: float) -> void:
	position.x += speed * delta
	if position.x > get_viewport().get_visible_rect().size.x + 200:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("lion"):
		GameState.regles.lion_touche_par_ennemi(body.joueur, global_position)
