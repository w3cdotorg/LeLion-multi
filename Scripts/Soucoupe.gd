extends Ennemi
## Ennemi : traverse l'écran de gauche à droite en ligne droite.

@export var speed: float = 150.0


func _physics_process(delta: float) -> void:
	if est_replique():
		return
	position.x += speed * delta
	if position.x > get_viewport().get_visible_rect().size.x + 200:
		queue_free()
