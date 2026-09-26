class_name Pastille
extends Area2D
## Base des pastilles (couleur, étoile, cœur) : leur gestionnaire de contact commun. Un contact
## n'est tranché que par l'hôte (en solo, le poste est son propre hôte), ne compte que pour un
## lion (`body is Lion`, pas le groupe « lion », qui ne sert plus qu'au Spawner), et une pastille
## ne sert qu'une fois : premier arrivé, premier servi (deux lions qui la touchent dans la même
## frame : `queue_free()` est différé). L'effet est décidé par les règles (`_ramasser`, que chaque
## pastille définit) ; le son de ramassage est joué par `Audio`, sur un signal du joueur local, sur
## chaque poste. Sur un client, une pastille n'est qu'une réplique de celle de l'hôte (apparue par
## le `MultiplayerSpawner` de la scène de jeu) : elle ne se libère jamais d'elle-même (`_expirer`),
## c'est l'hôte qui la fait disparaître chez tous.

var _ramassee := false


## Branché sur `body_entered` dans la scène de chaque pastille.
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server() or _ramassee or not (body is Lion):
		return
	_ramassee = true
	var lion: Lion = body
	_ramasser(lion.joueur)
	queue_free()


## L'effet de la pastille pour le joueur du lion qui la ramasse : celui des règles de la partie.
func _ramasser(_joueur: Joueur) -> void:
	pass


## Fin de vie d'une pastille que personne n'a ramassée : l'hôte la libère (sa disparition est
## répliquée chez les clients) ; une réplique attend l'hôte.
func _expirer() -> void:
	if multiplayer.is_server():
		queue_free()
