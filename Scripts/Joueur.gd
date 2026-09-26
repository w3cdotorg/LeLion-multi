class_name Joueur
extends Resource
## État d'un lion : identité (poste, index, pseudo, couleur) et, pendant une partie, couleurs
## débloquées, crans de gerbe, vies, invulnérabilité, étourdissement, bonus et statistiques.
## Ne dépend de rien : ce sont les règles qui décident quand appeler ces méthodes.

signal couleur_debloquee(couleur: Color)
signal bonus_change(actif: bool)
signal vies_changees(vies: int)
signal touche(origine: Vector2)
signal crans_changes(crans: int)
## Début d'un étourdissement (bataille). `barbouillage` = couleur de l'agresseur, transparente
## si c'est un ennemi (pas de barbouillage).
signal etourdi(origine: Vector2, barbouillage: Color)
signal etourdissement_fini()

## Crans de gerbe : de 1 (départ, rayon de peinture minimal) à CRANS_MAX.
const CRANS_MAX := 7
## Écart des nuances foncée et claire autour de la couleur du joueur (voir `nuances`).
const ECART_NUANCES := 0.35
## `id_reseau` d'un joueur qu'aucun poste ne joue (les lions pilotés d'une bataille locale).
const SANS_PAIR := 0

## Identifiant réseau du poste qui joue ce lion (`multiplayer.get_unique_id()` de ce poste), par
## lequel `GameState.joueur_local()` reconnaît le joueur de ce poste. Le joueur du solo porte
## celui de l'hôte (1) : hors réseau, ce poste est son propre hôte.
@export var id_reseau := SANS_PAIR
@export var index := 0
@export var pseudo := ""
## Couleur du lion en bataille. Transparente (alpha 0) = pas de couleur de lion : c'est le cas
## du solo, dont le lion garde sa crinière d'origine et n'affiche pas de pseudo.
@export var couleur := Color.TRANSPARENT

var couleurs_debloquees: Array[Color] = []
var crans := 1
var vies := 3
var coups_recus := 0
## Invulnérabilité, appelée immunité en bataille : ni coup ni étourdissement ne porte tant
## qu'elle dure. Une seule minuterie pour les deux modes ; ce sont les règles qui choisissent sa
## durée (1,5 s après un coup en solo ; en bataille, l'étourdissement puis 1 s).
var invulnerable_restant := 0.0
var etourdi_restant := 0.0
## Frame physique du dernier étourdissement (-1 = aucun), pour que les règles distinguent un
## étourdissement de cette frame-ci d'un étourdissement plus ancien (trade tête-à-tête).
var etourdi_a_la_frame := -1
var bonus_restant := 0.0
# Statistiques de bataille, pour les titres de l'écran Résultats (les cellules volées sont
# comptées par le territoire, phase 9).
var etourdissements_infliges := 0
var cellules_volees := 0
var chocs := 0


## Remet le joueur à l'état de départ d'une partie, sans émettre de signal.
## `couleurs_depart` : couleurs vomies d'emblée (les trois nuances en bataille, aucune en solo).
func reinitialiser(vies_depart: int, couleurs_depart: Array[Color] = []) -> void:
	couleurs_debloquees.assign(couleurs_depart)
	crans = 1
	vies = vies_depart
	coups_recus = 0
	invulnerable_restant = 0.0
	etourdi_restant = 0.0
	etourdi_a_la_frame = -1
	bonus_restant = 0.0
	etourdissements_infliges = 0
	cellules_volees = 0
	chocs = 0


## Décompte invulnérabilité, étourdissement et bonus ; signale la fin de l'étourdissement et
## celle de la gerbe XXL.
func avancer(delta: float) -> void:
	if invulnerable_restant > 0.0:
		invulnerable_restant = max(0.0, invulnerable_restant - delta)
	if etourdi_restant > 0.0:
		etourdi_restant = max(0.0, etourdi_restant - delta)
		if etourdi_restant == 0.0:
			etourdissement_fini.emit()
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


## Un cran de gerbe de plus, jusqu'à CRANS_MAX. Renvoie false (sans signal) au maximum.
func gagner_cran() -> bool:
	if crans >= CRANS_MAX:
		return false
	crans += 1
	crans_changes.emit(crans)
	return true


## Étourdit le joueur `duree` secondes puis l'immunise `duree_immunite` secondes : son
## invulnérabilité couvre les deux (une seule minuterie de protection, voir `invulnerable_restant`).
func etourdir(duree: float, duree_immunite: float, origine: Vector2, barbouillage: Color) -> void:
	etourdi_restant = duree
	invulnerable_restant = duree + duree_immunite
	etourdi_a_la_frame = Engine.get_physics_frames()
	etourdi.emit(origine, barbouillage)


func gagner_vie(vies_max: int) -> bool:
	if vies >= vies_max:
		return false
	vies += 1
	vies_changees.emit(vies)
	return true


func est_invulnerable() -> bool:
	return invulnerable_restant > 0.0


func est_etourdi() -> bool:
	return etourdi_restant > 0.0


func bonus_actif() -> bool:
	return bonus_restant > 0.0


## Vrai si le joueur a une couleur de lion (bataille), faux en solo.
func a_une_couleur() -> bool:
	return couleur.a > 0.0


## Les trois nuances de la gerbe d'un joueur de bataille, dans l'ordre de l'éventail :
## foncée, pure, claire (spec §2).
func nuances() -> Array[Color]:
	return [couleur.darkened(ECART_NUANCES), couleur, couleur.lightened(ECART_NUANCES)]


## Chez un client (phase 14) : les réactions décidées par l'hôte, que la manche lui transmet (sur un
## client, seul l'hôte décompte les minuteries : `GameState` n'y appelle pas `avancer`). Chacune pose
## l'état que l'hôte a et émet le même signal que la méthode de l'hôte (Lion, HUD, Audio l'écoutent
## sur chaque poste) ; sans effet ni signal si rien ne change. Le début d'un étourdissement et celui
## d'une gerbe XXL passent par `etourdir` et `activer_bonus`, comme chez l'hôte.


## Les crans de gerbe de l'hôte (ramenés dans [1, CRANS_MAX]).
func recevoir_crans(n: int) -> void:
	var crans_hote := clampi(n, 1, CRANS_MAX)
	if crans_hote == crans:
		return
	crans = crans_hote
	crans_changes.emit(crans)


## Fin de l'étourdissement chez l'hôte : l'immunité qui reste (`invulnerable_restant` de l'hôte) est
## celle que le lion fait clignoter.
func recevoir_fin_etourdissement(immunite_restante: float) -> void:
	if not est_etourdi():
		return
	etourdi_restant = 0.0
	invulnerable_restant = maxf(immunite_restante, 0.0)
	etourdissement_fini.emit()


## Fin de la gerbe XXL chez l'hôte.
func recevoir_fin_bonus() -> void:
	if not bonus_actif():
		return
	bonus_restant = 0.0
	bonus_change.emit(false)


## Active (ou prolonge) la gerbe XXL pour `duree` secondes.
func activer_bonus(duree: float) -> void:
	var etait_actif := bonus_actif()
	bonus_restant = max(bonus_restant, duree)
	if not etait_actif:
		bonus_change.emit(true)
