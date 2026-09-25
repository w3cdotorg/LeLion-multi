class_name Regles
extends RefCounted
## Règles d'une partie : reçoivent les événements du jeu et décident de leurs effets.
## Chaque événement concerne le joueur reçu, qui n'est pas forcément le joueur local.
## Sans effet par défaut ; chaque mode (solo, bataille) en dérive. Ne s'exécutent que sur
## l'hôte (en solo, le poste est son propre hôte).

## État de la partie (l'autoload GameState), fourni à la construction : les règles ne
## dépendent pas d'un global, ce qui permet de les tester (un test `--script` est compilé avant
## l'enregistrement des autoloads).
var partie: Node


func _init(partie_: Node = null) -> void:
	partie = partie_


## Un ennemi (soucoupe, coccinelle, peintre) touche le lion du joueur. `origine` = position de
## l'ennemi, pour le recul (Vector2.INF si inconnue).
func lion_touche_par_ennemi(_joueur: Joueur, _origine: Vector2) -> void:
	pass


## Renvoie true si la pastille a eu un effet.
func pastille_ramassee(_joueur: Joueur, _index_couleur: int) -> bool:
	return false


func etoile_ramassee(_joueur: Joueur) -> void:
	pass


## Renvoie true si le cœur a eu un effet.
func coeur_ramasse(_joueur: Joueur) -> bool:
	return false


## La ville vient de mesurer la part peinte (0 à 1).
func progression_mesuree(_ratio: float) -> void:
	pass
