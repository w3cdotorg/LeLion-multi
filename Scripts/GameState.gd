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
## Une bataille se joue de NB_JOUEURS_MIN à NB_JOUEURS_MAX joueurs (le salon ne lance pas la
## manche à moins de deux inscrits, spec §4).
const NB_JOUEURS_MIN := 2
const NB_JOUEURS_MAX := 6
## Palette de bataille : rouge, bleu, jaune, vert, magenta, cyan. L'hôte attribue la première
## libre à chaque arrivant (`Reseau`), `configurer_bataille` la donne par index hors salon. Réglée
## en phase 11 bis pour la deutéranopie (Machado 2009) : l'écart OKLab minimal entre deux couleurs
## simulées passe de 0,115 (planche de la phase 7 : rouge et vert confondus) à 0,186, sans
## s'éloigner de plus de 0,06 des teintes de la planche, et chacune reste claire (OKLab L >= 0,54).
const PALETTE_BATAILLE: Array[Color] = [
	Color(0.81, 0.14, 0.01), Color(0.24, 0.38, 1.00), Color(1.00, 0.91, 0.09),
	Color(0.19, 0.82, 0.34), Color(0.87, 0.26, 0.73), Color(0.23, 0.92, 1.00),
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
## réassigné. Les abonnés valables pour plus d'une manche suivent `joueur_local_change` (`Audio`,
## pour toute la session) : l'identité d'objet du `Joueur` de ce poste n'est PAS garantie d'une
## manche à l'autre en réseau (le salon, phase 13, écrit la table par index).
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
## (`multiplayer.get_unique_id()` : 1 chez l'hôte et hors réseau). Hors d'une session réseau (solo,
## bataille locale, pair fermé ou absent), 1 ne dit rien de ce poste (c'est aussi la case de
## l'hôte) : le dernier joueur local annoncé (`_dernier_joueur_local`) est gardé s'il est toujours
## dans le tableau. En session (hôte ou client), seul l'identifiant fait foi : le salon peut avoir
## donné l'ancien objet à un autre poste. À défaut (client dont les identifiants ne sont pas encore
## attribués), le premier joueur.
func joueur_local() -> Joueur:
	var id := _id_reseau_local()
	if not _en_session() and joueurs.has(_dernier_joueur_local):
		return _dernier_joueur_local
	if id != Joueur.SANS_PAIR:  # N1 : un identifiant nul ne doit désigner aucun poste
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
	var local := joueur_local()  # au retour au titre, `joueur_local()` garde déjà le dernier annoncé
	var k := joueurs.find(local)
	joueurs[k] = joueurs[0]  # échange en place : le tableau reste le même objet
	joueurs[0] = local
	joueurs.resize(1)
	local.index = 0
	local.id_reseau = MultiplayerPeer.TARGET_PEER_SERVER
	local.couleur = Color.TRANSPARENT
	_annoncer_joueur_local()


## Prépare une bataille locale à `nb_joueurs` (NB_JOUEURS_MIN à NB_JOUEURS_MAX) : règles de
## bataille, joueurs ajoutés ou retirés en place, index, et couleurs (`couleurs_de_bataille`).
## Pseudos et identifiants réseau ne changent pas ; un joueur ajouté n'appartient à aucun poste
## (`Joueur.SANS_PAIR`). La bataille en réseau passe par `configurer_bataille_reseau`.
func configurer_bataille(nb_joueurs: int, couleurs: Array[Color] = []) -> void:
	_preparer_bataille(nb_joueurs, couleurs)
	_annoncer_joueur_local()


## Prépare une bataille en réseau, sur chaque poste, juste avant de charger la scène de jeu (le
## salon, phase 13, à la réception de `Reseau.manche_lancee`) : une fiche
## `{"id_reseau": int, "pseudo": String, "couleur": Color}` par joueur, dans l'ordre des index
## (compactés sur 0..n-1 par l'hôte). Comme `configurer_bataille`, puis chaque index reçoit
## l'identifiant réseau et le pseudo de sa fiche, l'index 0 compris (l'hôte, 1, sur tous les
## postes) ; le joueur local n'est annoncé qu'une fois tous les identifiants posés.
func configurer_bataille_reseau(fiches: Array[Dictionary]) -> void:
	var couleurs: Array[Color] = []
	for fiche in fiches:
		couleurs.append(fiche.couleur)
	var nb := _preparer_bataille(fiches.size(), couleurs)
	for i in range(nb):
		var fiche: Dictionary = fiches[i] if i < fiches.size() else {}
		joueurs[i].id_reseau = fiche.get("id_reseau", Joueur.SANS_PAIR)
		joueurs[i].pseudo = fiche.get("pseudo", "")
	_annoncer_joueur_local()


## Les couleurs de `nb` joueurs de bataille : celle de `couleurs` à chaque index si elle est
## opaque et pas déjà prise par un index précédent, sinon (manquante, transparente, en double) la
## première couleur de la palette qui n'est pas encore utilisée (la règle de
## `Reseau.premiere_couleur_libre`). Les couleurs au-delà de `nb` sont ignorées.
static func couleurs_de_bataille(nb: int, couleurs: Array[Color]) -> Array[Color]:
	var retenues: Array[Color] = []
	for i in range(nb):
		var c: Color = couleurs[i] if i < couleurs.size() else Color.TRANSPARENT
		retenues.append(c if c.a >= 1.0 and not retenues.has(c) else Color.TRANSPARENT)
	for i in range(nb):
		if retenues[i].a < 1.0:
			for c in PALETTE_BATAILLE:
				if not retenues.has(c):
					retenues[i] = c
					break
	return retenues


## Règles de bataille et table des joueurs à la bonne taille, index et couleurs posés, sans
## annoncer le joueur local. Un nombre de joueurs hors de [NB_JOUEURS_MIN, NB_JOUEURS_MAX] est
## ramené dans ces bornes, et des couleurs corrigées (voir `couleurs_de_bataille`) le sont en
## le signalant (`push_error`) : un salon mal formé ne doit pas planter la partie. Renvoie le
## nombre de joueurs retenu.
func _preparer_bataille(nb_joueurs: int, couleurs: Array[Color]) -> int:
	var nb := clampi(nb_joueurs, NB_JOUEURS_MIN, NB_JOUEURS_MAX)
	if nb != nb_joueurs:
		push_error("une bataille se joue de %d à %d joueurs : %d demandés, %d retenus" % [NB_JOUEURS_MIN, NB_JOUEURS_MAX, nb_joueurs, nb])
	var retenues := couleurs_de_bataille(nb, couleurs)
	if retenues.slice(0, mini(couleurs.size(), nb)) != couleurs:
		push_error("couleurs de bataille corrigées : %s devient %s" % [couleurs, retenues])
	regles = ReglesBataille.new(self)
	var nb_avant := joueurs.size()
	joueurs.resize(nb)
	for i in range(nb):
		if i >= nb_avant:
			joueurs[i] = Joueur.new()
		joueurs[i].index = i
		joueurs[i].couleur = retenues[i]
	return nb


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


## Vrai si ce poste est dans une session réseau ouverte (hôte ou client) ; faux en solo, en bataille
## locale (`OfflineMultiplayerPeer`), sans pair ou pair fermé.
func _en_session() -> bool:
	if not is_inside_tree():
		return false
	var pair := multiplayer.multiplayer_peer
	return pair != null and not pair is OfflineMultiplayerPeer \
		and pair.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED


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
