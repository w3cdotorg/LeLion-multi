class_name EtatPartie
extends Node
## État global d'une partie : joueurs, règles, progression de la peinture, chrono, fin de partie.
## L'état propre à chaque lion vit dans `Joueur` ; les effets du jeu sont décidés par `regles`.

signal progression_changee(ratio: float)
signal partie_terminee(victoire: bool)
signal partie_prete()
## Le joueur de ce poste a changé (client réseau dont le salon a attribué les identifiants, retour
## au solo) : ceux qui l'écoutent pour toute la session (`Audio`) s'y réabonnent.
signal joueur_local_change(joueur: Joueur)

const COULEURS_ARC_EN_CIEL: Array[Color] = [
	Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN,
	Color.CYAN, Color.BLUE, Color.VIOLET,
]
const VIES_MAX := 3
const NB_JOUEURS_MAX := 6
## Palette de bataille, attribuée par index de joueur (planche de la phase 7). Provisoire : la
## phase 11 en fait l'attribution du salon et règle les luminosités (deutéranopie).
const PALETTE_BATAILLE: Array[Color] = [
	Color(0.90, 0.16, 0.16), Color(0.16, 0.39, 0.95), Color(0.98, 0.82, 0.10),
	Color(0.18, 0.78, 0.25), Color(0.90, 0.20, 0.85), Color(0.10, 0.85, 0.90),
]
const NB_ETAPES_ARCADE := 9  # 3 niveaux × 3 difficultés
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

## Le tableau est rempli ou réinitialisé en place (append, resize, échange de cases) et jamais
## réassigné, et un `Joueur` n'est jamais remplacé par un autre objet pour le même poste : les
## scènes s'abonnent au joueur local dans leur `_ready`, `Audio` pour toute la session (il suit
## `joueur_local_change`).
var joueurs: Array[Joueur] = [Joueur.new()]
## Règles de la partie : celles du solo par défaut ; `configurer_solo` et `configurer_bataille`
## les changent.
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
## Le dernier joueur local annoncé par `joueur_local_change` : le joueur de ce poste pendant la
## dernière partie, que `configurer_solo` garde même si le pair réseau est déjà fermé.
var _dernier_joueur_local: Joueur


func _init() -> void:
	regles = ReglesSolo.new(self)
	joueurs[0].id_reseau = MultiplayerPeer.TARGET_PEER_SERVER  # le solo : ce poste est son propre hôte
	_dernier_joueur_local = joueurs[0]


## Le joueur de ce poste : celui dont `id_reseau` est l'identifiant réseau du poste
## (`multiplayer.get_unique_id()` : 1 chez l'hôte et hors réseau). À défaut (client dont les
## identifiants ne sont pas encore attribués), le premier joueur.
func joueur_local() -> Joueur:
	var id := _id_reseau_local()
	for j in joueurs:
		if j.id_reseau == id:
			return j
	return joueurs[0]


## Prépare une partie solo : règles du solo, un seul joueur, sans couleur (son lion garde son
## rendu d'origine). Ce joueur est celui de ce poste pendant la dernière partie (sur un client, pas
## forcément `joueurs[0]`), même si le réseau est déjà fermé (hôte perdu) : il passe en tête, avec
## l'index 0 et l'identifiant de l'hôte. Comme `configurer_bataille`, à appeler AVANT de charger la
## scène de jeu : `Main._enter_tree` appelle `nouvelle_partie()`, puis Lion, Spawner, HUD et Main
## s'abonnent à `joueur_local()` dans leur `_ready`. L'écran titre l'appelle (toute partie qu'il
## lance est une partie solo).
func configurer_solo() -> void:
	regles = ReglesSolo.new(self)
	var local := _dernier_joueur_local if joueurs.has(_dernier_joueur_local) else joueur_local()
	var k := joueurs.find(local)
	joueurs[k] = joueurs[0]  # échange en place : le tableau reste le même objet
	joueurs[0] = local
	joueurs.resize(1)
	local.index = 0
	local.id_reseau = MultiplayerPeer.TARGET_PEER_SERVER
	local.couleur = Color.TRANSPARENT
	_annoncer_joueur_local()


## Prépare une bataille à `nb_joueurs` (2 à NB_JOUEURS_MAX) : règles de bataille, joueurs
## ajoutés ou retirés en place, index, et couleur : celle de `couleurs` à cet index si elle est
## donnée (les choix du salon, phase 13), sinon celle de la palette. Pseudos et identifiants
## réseau ne changent pas ; un joueur ajouté n'appartient à aucun poste (`Joueur.SANS_PAIR`).
func configurer_bataille(nb_joueurs: int, couleurs: Array[Color] = []) -> void:
	assert(nb_joueurs >= 2 and nb_joueurs <= NB_JOUEURS_MAX, "une bataille se joue de 2 à %d" % NB_JOUEURS_MAX)
	regles = ReglesBataille.new(self)
	var nb_avant := joueurs.size()
	joueurs.resize(nb_joueurs)
	for i in range(nb_joueurs):
		if i >= nb_avant:
			joueurs[i] = Joueur.new()
		joueurs[i].index = i
		joueurs[i].couleur = couleurs[i] if i < couleurs.size() else PALETTE_BATAILLE[i]
	_annoncer_joueur_local()


func _process(delta: float) -> void:
	if not partie_en_cours or not pret:
		return
	temps_ecoule += delta
	for j in joueurs:
		j.avancer(delta)


func nouvelle_partie() -> void:
	for j in joueurs:
		j.reinitialiser(difficulte().vies, regles.couleurs_de_depart(j))
	progression = 0.0
	temps_ecoule = 0.0
	pret = false
	partie_en_cours = true
	_annoncer_joueur_local()


## L'identifiant réseau de ce poste ; 1 (l'hôte, le solo) hors de l'arbre, sans pair, ou quand le
## pair est fermé (un pair ENet fermé n'a plus d'identifiant).
func _id_reseau_local() -> int:
	if not is_inside_tree():
		return MultiplayerPeer.TARGET_PEER_SERVER
	var pair := multiplayer.multiplayer_peer
	if pair == null or pair.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return MultiplayerPeer.TARGET_PEER_SERVER
	return multiplayer.get_unique_id()


## Émet `joueur_local_change` si le joueur local n'est plus celui de la dernière annonce.
func _annoncer_joueur_local() -> void:
	var local := joueur_local()
	if local == _dernier_joueur_local:
		return
	_dernier_joueur_local = local
	joueur_local_change.emit(local)


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
