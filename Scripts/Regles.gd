class_name Regles
extends RefCounted
## Règles d'une partie : reçoivent les événements du jeu et décident de leurs effets.
## Chaque événement concerne le joueur reçu, qui n'est pas forcément le joueur local.
## Sans effet par défaut ; chaque mode (solo, bataille) en dérive. Ne s'exécutent que sur
## l'hôte (en solo, le poste est son propre hôte).

## Durée de la gerbe XXL donnée par une étoile, la même en solo et en bataille.
const DUREE_ETOILE := 8.0
## Écran du solo (spec §7) : la taille de référence des hauteurs d'apparition et du peintre, qui
## gardent en bataille leurs dimensions du solo.
const TAILLE_ECRAN_SOLO := Vector2i(2000, 648)

## État de la partie (l'autoload GameState, typé par sa classe EtatPartie), fourni à la
## construction : les règles ne dépendent pas d'un global, ce qui permet de les tester (un test
## `--script` est compilé avant l'enregistrement des autoloads).
var partie: EtatPartie


func _init(partie_: EtatPartie = null) -> void:
	partie = partie_


## Couleurs que le joueur vomit dès le départ d'une partie (lu par `nouvelle_partie`).
func couleurs_de_depart(_joueur: Joueur) -> Array[Color]:
	return []


## Vrai si la partie se joue au territoire (bataille) : la ville tient alors, en plus de sa
## mesure de couverture, une grille de propriété (`Territoire`) qui compte les cellules de
## chaque joueur. Lu par la ville quand elle charge sa skyline.
func compte_le_territoire() -> bool:
	return false


## Taille de l'écran du mode (`content_scale_size`, spec §7), appliquée par `Main` en entrant
## dans la scène de jeu : celle du solo par défaut.
func taille_ecran() -> Vector2i:
	return TAILLE_ECRAN_SOLO


## Avancement de la partie, de 0 (début) à 1 (fin en vue), qui accélère le peintre et les
## apparitions d'ennemis. Peut dépasser 1 : les appelants le bornent. Nul par défaut (rien
## n'accélère).
func avancement() -> float:
	return 0.0


## Index de la couleur de l'arc-en-ciel de la prochaine pastille à faire apparaître, -1 pour
## aucune (lu par le Spawner quand une pastille est due). Aucune par défaut.
func pastille_a_offrir() -> int:
	return -1


## Vrai si l'étoile XXL peut apparaître maintenant (lu par le Spawner à chaque échéance).
func etoile_peut_apparaitre() -> bool:
	return false


## Vrai si la partie a des cœurs à ramasser (le Spawner ne programme leurs apparitions que si
## c'est le cas).
func coeurs_en_jeu() -> bool:
	return false


## Vrai si un cœur peut apparaître maintenant (lu par le Spawner à chaque échéance, quand la
## partie a des cœurs).
func coeur_peut_apparaitre() -> bool:
	return false


## Un ennemi (soucoupe, coccinelle, peintre) touche le lion du joueur. `origine` vient de
## `Ennemi.origine_du_coup` (le peintre donne x du peintre, y du lion), pour le recul
## (Vector2.INF si inconnue). Le peintre le signale à chaque frame de chevauchement : un
## joueur déjà frappé doit être ignoré.
func lion_touche_par_ennemi(_joueur: Joueur, _origine: Vector2) -> void:
	pass


## Le vomi du lion d'`agresseur` touche le lion de `victime`, à `origine` (point de la gerbe,
## pour le recul). Signalé à chaque frame de contact, comme le peintre.
func lion_touche_par_vomi(_victime: Joueur, _agresseur: Joueur, _origine: Vector2) -> void:
	pass


## Les lions de `a` et `b` viennent de se rentrer dedans (signalé une fois par contact).
func choc_entre_lions(_a: Joueur, _b: Joueur) -> void:
	pass


## Renvoie true si la pastille a eu un effet (elle disparaît dans tous les cas ; la valeur de
## retour ne sert qu'au feedback). `index_couleur` ne compte que pour les règles qui utilisent
## l'arc-en-ciel ; les règles de bataille l'ignorent.
func pastille_ramassee(_joueur: Joueur, _index_couleur: int) -> bool:
	return false


func etoile_ramassee(_joueur: Joueur) -> void:
	pass


## Renvoie true si le cœur a eu un effet (il disparaît dans tous les cas ; la valeur de retour
## ne sert qu'au feedback).
func coeur_ramasse(_joueur: Joueur) -> bool:
	return false


## La ville vient de mesurer la part peinte (0 à 1).
func progression_mesuree(_ratio: float) -> void:
	pass


## Un tampon du lion de `voleur` vient de lui faire posséder `nb` cellules (au moins une) qui
## comptaient en dernier pour d'autres joueurs (territoire, bataille). Signalé par la ville de
## l'hôte, une fois par tampon.
func vol_de_cellules(_voleur: Joueur, _nb: int) -> void:
	pass


## Vrai pendant le jeu proprement dit : partie en cours et intro « Prêt ? Vomissez ! » finie.
## Lu aussi par la ville, qui ne tamponne le territoire que pendant la manche.
func manche_en_cours() -> bool:
	return partie.partie_en_cours and partie.pret
