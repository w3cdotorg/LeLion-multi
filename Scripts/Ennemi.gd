class_name Ennemi
extends Area2D
## Base des ennemis (soucoupe, coccinelle, peintre) : leur gestionnaire de contact commun. Un
## contact n'est tranché que par l'hôte (en solo, le poste est son propre hôte), ne compte que
## pour un lion (`body is Lion`) et part de `origine_du_coup`, que chaque ennemi peut redéfinir.
## Ce sont les règles qui en décident l'effet : un coup en solo, un étourdissement en bataille.


## Branché sur `body_entered` dans la scène de chaque ennemi.
func _on_body_entered(body: Node2D) -> void:
	if multiplayer.is_server():
		_signaler_si_lion(body)


## Contact continu (le peintre, hors repos) : chaque lion qui chevauche l'ennemi est signalé à
## chaque frame ; les règles ignorent un joueur déjà frappé, étourdi ou immunisé.
func _signaler_les_lions_au_contact() -> void:
	if not multiplayer.is_server():
		return
	for body in get_overlapping_bodies():
		_signaler_si_lion(body)


## Point d'où part le coup, pour le recul du lion : par défaut, la position de l'ennemi.
func origine_du_coup(_lion: Lion) -> Vector2:
	return global_position


func _signaler_si_lion(body: Node2D) -> void:
	if body is Lion:
		var lion: Lion = body
		GameState.regles.lion_touche_par_ennemi(lion.joueur, origine_du_coup(lion))
