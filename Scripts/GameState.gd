class_name EtatPartie
extends Node
## État global d'une partie : joueurs, règles, progression de la peinture, chrono, fin de partie.
## L'état propre à chaque lion vit dans `Joueur` ; les effets du jeu sont décidés par `regles`.

signal progression_changee(ratio: float)
signal partie_terminee(victoire: bool)
signal partie_prete()

const COULEURS_ARC_EN_CIEL: Array[Color] = [
	Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN,
	Color.CYAN, Color.BLUE, Color.VIOLET,
]
const VIES_MAX := 3
const NB_ETAPES_ARCADE := 9  # 3 niveaux × 3 difficultés
const DUREE_INVULNERABILITE := 1.5
const DIFFICULTES: Array[Dictionary] = [
	{"id": "facile", "nom": "DIFF_FACILE", "description": "DIFF_FACILE_DESC", "vies": 3, "pickups_coeur": true, "seuil": 0.85},
	{"id": "moyen", "nom": "DIFF_MOYEN", "description": "DIFF_MOYEN_DESC", "vies": 3, "pickups_coeur": false, "seuil": 0.90},
	{"id": "hardcore", "nom": "DIFF_HARDCORE", "description": "DIFF_HARDCORE_DESC", "vies": 1, "pickups_coeur": false, "seuil": 0.95},
]
const NIVEAUX: Array[Dictionary] = [
	{"id": "skyline", "nom": "NIVEAU_SKYLINE", "texture": "res://Assets/Sprites/skyline_2000px.png"},
	{"id": "metropole", "nom": "NIVEAU_METROPOLE", "texture": "res://Assets/Sprites/skyline_metropole.png"},
	{"id": "village", "nom": "NIVEAU_VILLAGE", "texture": "res://Assets/Sprites/skyline_village.png", "boss": true},
]

## Le tableau doit être rempli ou réinitialisé en place (append, resize, etc.) et jamais
## réassigné : `Audio` s'abonne une fois pour toute la session au joueur local (`joueurs[0]`),
## une réassignation rendrait son son de pastille muet sans erreur (voir la phase 11 de la
## feuille de route).
var joueurs: Array[Joueur] = [Joueur.new()]
## Règles de la partie : celles du solo par défaut ; la bataille branchera les siennes.
var regles: Regles
var progression := 0.0
var temps_ecoule := 0.0
var partie_en_cours := false
var pret := false  # false pendant l'intro « Prêt ? Vomissez ! »
var niveau_courant := 0
var difficulte_courante := 0
var mode_arcade := false
var demo := false  # attract mode : le jeu se joue tout seul
var etape_arcade := 0
var temps_arcade := 0.0  # somme des temps des stages gagnés


func _init() -> void:
	regles = ReglesSolo.new(self)


## Le joueur de ce poste. En solo, le seul joueur.
func joueur_local() -> Joueur:
	return joueurs[0]


func _process(delta: float) -> void:
	if not partie_en_cours or not pret:
		return
	temps_ecoule += delta
	for j in joueurs:
		j.avancer(delta)


func nouvelle_partie() -> void:
	for j in joueurs:
		j.reinitialiser(difficulte().vies)
	progression = 0.0
	temps_ecoule = 0.0
	pret = false
	partie_en_cours = true


## Fin de l'intro : le jeu réagit aux commandes, les ennemis arrivent, le chrono tourne.
func demarrer() -> void:
	if pret:
		return
	pret = true
	partie_prete.emit()


func difficulte() -> Dictionary:
	return DIFFICULTES[difficulte_courante]


## Texte affiché par l'intro : « STAGE n/9 » en arcade, sinon le nom du niveau.
func titre_etape() -> String:
	if mode_arcade:
		return tr("STAGE") % [etape_arcade + 1, NB_ETAPES_ARCADE]
	return tr(niveau().nom).to_upper()


## Arcade : les neuf stages à la suite, Facile puis Moyen puis Hardcore, trois niveaux chacun.
func demarrer_arcade() -> void:
	mode_arcade = true
	etape_arcade = 0
	temps_arcade = 0.0
	_appliquer_etape_arcade()


func quitter_arcade() -> void:
	mode_arcade = false


func _appliquer_etape_arcade() -> void:
	difficulte_courante = etape_arcade / NIVEAUX.size()
	niveau_courant = etape_arcade % NIVEAUX.size()


func etape_arcade_suivante_existe() -> bool:
	return etape_arcade + 1 < NB_ETAPES_ARCADE


func passer_etape_arcade() -> void:
	if etape_arcade_suivante_existe():
		etape_arcade += 1
		_appliquer_etape_arcade()


func arcade_termine() -> bool:
	return mode_arcade and not etape_arcade_suivante_existe()


## Part de la ville à peindre pour gagner, selon la difficulté.
func seuil_victoire() -> float:
	return difficulte().seuil


func cle_score() -> String:
	return "%s/%s" % [niveau().id, difficulte().id]


func niveau() -> Dictionary:
	return NIVEAUX[niveau_courant]


func niveau_suivant_existe() -> bool:
	return niveau_courant + 1 < NIVEAUX.size()


func passer_au_niveau_suivant() -> void:
	if niveau_suivant_existe():
		niveau_courant += 1


func couleur(index: int) -> Color:
	return COULEURS_ARC_EN_CIEL[index]


func nb_couleurs_total() -> int:
	return COULEURS_ARC_EN_CIEL.size()


## Prochaine couleur de l'arc-en-ciel à offrir au joueur local (-1 si toutes sont débloquées).
## Règle du solo, lue par le Spawner (en bataille, les apparitions passeront par les règles).
func prochain_index_couleur() -> int:
	var i := joueur_local().couleurs_debloquees.size()
	return i if i < COULEURS_ARC_EN_CIEL.size() else -1


func signaler_progression(ratio: float) -> void:
	progression = ratio
	progression_changee.emit(ratio)
	regles.progression_mesuree(ratio)


func terminer_partie(victoire: bool) -> void:
	if not partie_en_cours:
		return
	partie_en_cours = false
	if victoire and mode_arcade:
		temps_arcade += temps_ecoule
	partie_terminee.emit(victoire)


static func formater_temps(secondes: float) -> String:
	var total := int(secondes)
	return "%d:%02d" % [total / 60, total % 60]
