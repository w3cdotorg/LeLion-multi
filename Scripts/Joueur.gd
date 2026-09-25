class_name Joueur
extends Resource
## État d'un lion pendant une partie : couleurs débloquées, vies, invulnérabilité, bonus.
## Ne dépend de rien : ce sont les règles qui décident quand appeler ces méthodes.

signal couleur_debloquee(couleur: Color)
signal bonus_change(actif: bool)
signal vies_changees(vies: int)
signal touche(origine: Vector2)

@export var index := 0
@export var pseudo := ""
@export var couleur := Color.WHITE

var couleurs_debloquees: Array[Color] = []
var vies := 3
var coups_recus := 0
var invulnerable_restant := 0.0
var bonus_restant := 0.0


## Remet le joueur à l'état de départ d'une partie, sans émettre de signal.
func reinitialiser(vies_depart: int) -> void:
	couleurs_debloquees.clear()
	vies = vies_depart
	coups_recus = 0
	invulnerable_restant = 0.0
	bonus_restant = 0.0


## Décompte invulnérabilité et bonus ; signale la fin de la gerbe XXL.
func avancer(delta: float) -> void:
	if invulnerable_restant > 0.0:
		invulnerable_restant = max(0.0, invulnerable_restant - delta)
	if bonus_restant > 0.0:
		bonus_restant -= delta
		if bonus_restant <= 0.0:
			bonus_restant = 0.0
			bonus_change.emit(false)


func debloquer_couleur(c: Color) -> bool:
	if couleurs_debloquees.has(c):
		return false
	couleurs_debloquees.append(c)
	couleur_debloquee.emit(c)
	return true


## Perd une vie. S'il en reste, devient invulnérable et émet `touche` (après `vies_changees`).
## `origine` = position de ce qui a frappé, pour le recul (Vector2.INF si inconnue).
func encaisser_coup(origine: Vector2, duree_invulnerabilite: float) -> int:
	vies -= 1
	coups_recus += 1
	vies_changees.emit(vies)
	if vies > 0:
		invulnerable_restant = duree_invulnerabilite
		touche.emit(origine)
	return vies


func gagner_vie(vies_max: int) -> bool:
	if vies >= vies_max:
		return false
	vies += 1
	vies_changees.emit(vies)
	return true


func est_invulnerable() -> bool:
	return invulnerable_restant > 0.0


func bonus_actif() -> bool:
	return bonus_restant > 0.0


## Active (ou prolonge) la gerbe XXL pour `duree` secondes.
func activer_bonus(duree: float) -> void:
	var etait_actif := bonus_actif()
	bonus_restant = max(bonus_restant, duree)
	if not etait_actif:
		bonus_change.emit(true)
