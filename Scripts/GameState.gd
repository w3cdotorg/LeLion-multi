class_name EtatPartie
extends Node
## État global d'une partie : joueurs, progression de la peinture, chrono, fin de partie.
## L'état propre à chaque lion vit dans `Joueur` ; les propriétés et méthodes marquées
## « façade » délèguent au joueur local le temps que les appelants migrent (phases 2 à 6).

signal couleur_debloquee(couleur: Color)
signal progression_changee(ratio: float)
signal partie_terminee(victoire: bool)
signal bonus_change(actif: bool)
signal vies_changees(vies: int)
signal partie_prete()
signal lion_touche(origine: Vector2)

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
## réassigné : les relais de signaux de la façade sont liés à `joueurs[0]` dans `_ready`
## (jusqu'à la phase 6), et une réassignation les rendrait muets sans erreur.
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

# Façade : état du joueur local (supprimée en phase 6).
var couleurs_debloquees: Array[Color]:
	get:
		return joueur_local().couleurs_debloquees
	set(_valeur):
		push_error("GameState.couleurs_debloquees est en lecture seule : passer par debloquer_couleur()")
var vies: int:
	get:
		return joueur_local().vies
	set(valeur):
		joueur_local().vies = valeur
var coups_recus: int:
	get:
		return joueur_local().coups_recus
	set(valeur):
		joueur_local().coups_recus = valeur
var invulnerable_restant: float:
	get:
		return joueur_local().invulnerable_restant
	set(valeur):
		joueur_local().invulnerable_restant = valeur
var bonus_restant: float:
	get:
		return joueur_local().bonus_restant
	set(valeur):
		joueur_local().bonus_restant = valeur


func _init() -> void:
	regles = ReglesSolo.new(self)


func _ready() -> void:
	assert(joueurs.size() == 1, "GameState._ready suppose un seul joueur (solo) pour lier les relais de signaux")
	var j := joueur_local()
	j.couleur_debloquee.connect(func(c: Color) -> void: couleur_debloquee.emit(c))
	j.bonus_change.connect(func(actif: bool) -> void: bonus_change.emit(actif))
	j.vies_changees.connect(func(nb: int) -> void: vies_changees.emit(nb))
	j.touche.connect(func(origine: Vector2) -> void: lion_touche.emit(origine))


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


func est_invulnerable() -> bool:
	return joueur_local().est_invulnerable()


## Façade : un ennemi touche le lion du joueur local (voir Regles.lion_touche_par_ennemi).
func toucher_lion(origine: Vector2 = Vector2.INF) -> void:
	regles.lion_touche_par_ennemi(joueur_local(), origine)


func gagner_vie() -> bool:
	return regles.coeur_ramasse(joueur_local())


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


func debloquer_couleur(index: int) -> bool:
	return regles.pastille_ramassee(joueur_local(), index)


func prochain_index_couleur() -> int:
	var i := couleurs_debloquees.size()
	return i if i < COULEURS_ARC_EN_CIEL.size() else -1


func bonus_actif() -> bool:
	return joueur_local().bonus_actif()


## Active (ou prolonge) la gerbe XXL pour `duree` secondes.
func activer_bonus(duree: float) -> void:
	joueur_local().activer_bonus(duree)


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
