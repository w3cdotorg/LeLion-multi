extends Node
## Transport LAN (spec §4) : le pair ENet (port UDP 7777), la poignée de main (version, pseudo),
## l'attribution des index et des couleurs par l'hôte, les arrivées et les départs, et la table du
## salon (phase 13) : qui est là, sa couleur, s'il est prêt, le niveau et le lancement de la
## manche, que l'hôte ne permet que si le salon est prêt (`raison_attente`). Le salon
## (`Scripts/Salon.gd`) affiche la table et porte le bouton de l'hôte. Pendant la manche (phase 14),
## la barrière de chargement : chaque poste signale sa scène de jeu chargée
## (`signaler_scene_chargee`), l'hôte les note (`scenes_chargees`) ; la manche synchronisée
## (`Scripts/Manche.gd`) attend tous les joueurs avant l'intro, et suit les départs
## (`joueur_parti`, `hote_perdu`). Hors réseau (solo, retour au titre), le pair est un
## `OfflineMultiplayerPeer` : ce poste est son propre hôte (`multiplayer.is_server()` vrai), et
## `quitter()` y revient toujours.
##
## Départs et silences (M6) : `quitter()` part proprement (un DISCONNECT fiable d'ENet, renvoyé
## jusqu'à son accusé de réception, DELAI_DEPART au plus, en arrière-plan : `_partants`), pas par
## un seul datagramme qu'une perte Wi-Fi ferait passer inaperçu ; un pair muet est considéré parti
## après SILENCE_SESSION (au lieu des 5 à 30 s d'ENet), sauf pendant le chargement de la manche
## (SILENCE_CHARGEMENT : un poste qui charge sa scène ou compile ses shaders ne répond plus). Le
## relais du serveur est coupé (`server_relay`) : tout passe par l'hôte.
##
## La poignée de main passe par l'authentification de `SceneMultiplayer` : des octets bruts
## (`var_to_bytes` d'un dictionnaire), échangés avant tout RPC, si bien que deux versions
## différentes du jeu peuvent encore se dire pourquoi elles ne jouent pas ensemble. Le client
## envoie `{jeu, version, pseudo}` ; l'hôte répond `{accepte: true, index, couleur, pseudo}` ou
## `{accepte: false, raison, version_hote}` ; le client refusé ferme lui-même la connexion (sinon,
## le délai de la poignée de main la ferme). Un joueur accepté est inscrit chez l'hôte dès la
## réponse (sa place est prise) : deux demandes simultanées ne peuvent ni obtenir la même place,
## ni dépasser le nombre de places.
##
## Salon : l'hôte tient la table dans `inscrits` et la diffuse, arrivés seulement, à chaque
## changement (`_recevoir_salon`, fiable) ; chaque poste la lit dans `table_salon`. Les clients
## demandent (couleur, Prêt) et l'hôte arbitre. Tous ces RPC passent par cet autoload, présent au
## même chemin sur chaque poste dès la connexion : une table envoyée avant que la scène du salon
## soit chargée chez un client l'y attend. Les RPC de l'hôte sont en mode "authority" (le moteur
## rejette tout autre émetteur) ; ceux des clients vérifient l'émetteur et leurs arguments.
##
## Autoload : les tests `--script`, compilés avant l'enregistrement des autoloads, le récupèrent
## par `root.get_node("Reseau")` et ne le nomment pas.

## Chez l'hôte : un joueur a fini sa poignée de main (il est dans `inscrits`, les RPC passent).
signal joueur_arrive(id: int)
## Chez l'hôte : un joueur arrivé est parti ; sa place, son index et sa couleur sont libres.
signal joueur_parti(id: int)
## Chez l'hôte, pendant une manche : la scène de jeu du joueur `id` est chargée (l'hôte compris).
signal scene_chargee(id: int)
## Chez le client : l'hôte l'a accepté et la connexion est établie (`index_local`, `couleur_locale`).
signal inscrit(index: int, couleur: Color)
## Chez le client : l'hôte a refusé ; `raison` est une des constantes REFUS_* (clé de traduction
## pour l'écran Réseau de la phase 12), `version_hote` la version de l'hôte. Le poste est déjà
## revenu hors réseau quand le signal part.
signal refuse(raison: String, version_hote: String)
## Chez le client : pas d'inscription dans le délai (IP qui ne répond pas, port fermé). Le poste
## est déjà revenu hors réseau quand le signal part.
signal connexion_echouee()
## Chez le client : l'hôte a quitté la partie ou ne répond plus. Le poste est déjà revenu hors
## réseau quand le signal part. N4 : si le pair ENet de l'hôte tombe lui-même en erreur, ce même
## signal part aussi chez l'hôte (server_disconnected n'y distingue pas les deux cas) ; personne ne
## l'écoute encore côté hôte à cette phase, mais un futur appelant ne doit pas supposer « jamais
## chez l'hôte ».
signal hote_perdu()
## Sur chaque poste en session : la table du salon (`table_salon`), son niveau ou ses places ont
## changé ; chez l'hôte, aussi quand une place se réserve ou se libère (le bouton Démarrer en
## dépend, `raison_attente`).
signal salon_change()
## Sur chaque poste en session : l'hôte lance la manche. `fiches` : une fiche
## `{"id_reseau", "pseudo", "couleur"}` par joueur, dans l'ordre des index compactés (0..n-1), à
## donner à `GameState.configurer_bataille_reseau` avant de charger la scène de jeu.
signal manche_lancee(fiches: Array[Dictionary])

const PORT := 7777
## Identifiant de la poignée de main : une demande qui ne le porte pas vient d'un autre programme.
const JEU := "LELION"
## Délai d'une connexion jusqu'à l'inscription (spec §9 : 5 s puis message).
const DELAI_CONNEXION := 5.0
## Délai laissé à chaque pair pour finir la poignée de main (`SceneMultiplayer.auth_timeout`).
const DELAI_POIGNEE_DE_MAIN := 3.0
## Longueur maximale d'un pseudo, en caractères, imposée par l'hôte (l'étiquette du lion est
## centrée sur lui et coupée par le bord de l'écran au-delà d'une douzaine de caractères).
const PSEUDO_MAX := 12
## Connexions ENet (`max_clients`) acceptées au-delà de `places` : l'hôte ne consomme pas de
## connexion vers lui-même, donc `places - 1` suffiraient aux vrais clients ; ce solde donne de quoi
## recevoir, et refuser explicitement, les demandes d'une partie déjà pleine au lieu de les laisser
## échouer sans explication côté ENet (N1 : la marge réelle est donc de CONNEXIONS_EN_TROP + 1).
const CONNEXIONS_EN_TROP := 2
## Taille maximale, en octets, d'un envoi de poignée de main : au-delà, `bytes_to_var` ne décode
## pas (le coût du décodage doit rester borné, même pour un émetteur quelconque sur le port UDP).
const TAILLE_POIGNEE_DE_MAIN_MAX := 1024
const REFUS_VERSION := "RESEAU_REFUS_VERSION"
const REFUS_PLEIN := "RESEAU_REFUS_PLEIN"
const REFUS_MANCHE := "RESEAU_REFUS_MANCHE"
const REFUS_DEMANDE := "RESEAU_REFUS_DEMANDE"
## Pourquoi l'hôte ne peut pas encore démarrer la partie (`raison_attente`), en clés de traduction.
const ATTENTE_JOUEURS := "SALON_ATTENTE_JOUEURS"
const ATTENTE_ARRIVEE := "SALON_ATTENTE_ARRIVEE"
const ATTENTE_PRETS := "SALON_ATTENTE_PRETS"
## Silence d'un pair ENet au-delà duquel il est considéré parti (`ENetPacketPeer.set_timeout`, en
## millisecondes : minimum, maximum ; ENet le décide entre les deux selon le temps d'aller-retour).
## Au salon et en manche : un poste planté ou en veille part en 8 s au plus, au lieu des 5 à 30 s
## par défaut d'ENet.
const SILENCE_SESSION := Vector2i(3000, 8000)
## Pendant le chargement de la manche, du lancement à l'intro : un poste qui charge sa scène de jeu
## (ou compile ses shaders, sous Windows) ne répond plus, parfois plus de 5 s.
const SILENCE_CHARGEMENT := Vector2i(20000, 30000)
## Essais de renvoi d'ENet avant de compter le silence (son défaut).
const ESSAIS_SILENCE := 32
## Délai laissé à un départ volontaire pour être reçu (accusé de réception du DISCONNECT), en
## millisecondes.
const DELAI_DEPART := 1000
## Pour `adresse_ipv4`, la validation de l'écran Réseau (fonction statique : l'autoload n'est pas
## nommé). `Decouverte.gd` précharge aussi ce script : ce préchargement croisé passe en Godot 4.7.
const _Decouverte := preload("res://Scripts/Decouverte.gd")

## Version présentée à la poignée de main (`application/config/version`) ; deux versions
## différentes ne jouent pas ensemble. Modifiable par les tests.
var version: String = ProjectSettings.get_setting("application/config/version", "")
## Pseudo de ce poste, présenté à l'hôte (ou inscrit tel quel quand ce poste héberge).
var pseudo := ""
## Nombre de joueurs d'une partie hébergée, hôte compris ; `heberger()` la borne à
## [2, `EtatPartie.NB_JOUEURS_MAX`] (N3 : au-delà, `premier_index_libre` renverrait -1 pour l'hôte
## lui-même).
var places := EtatPartie.NB_JOUEURS_MAX
## Posé par la partie (phase 13 au lancement de la manche, phase 18 au retour au salon) : tant
## qu'il est vrai, l'hôte refuse tout nouveau venu (pas d'arrivée en cours de manche, spec §1).
var manche_en_cours := false
## Chez l'hôte : les joueurs inscrits, hôte compris, par identifiant réseau :
## `{"index": int, "couleur": Color, "pseudo": String, "arrive": bool, "pret": bool}`. Un accepté y
## entre dès la réponse de l'hôte (sa place est réservée), avec `arrive` faux jusqu'à la fin de sa
## poignée de main : seuls les arrivés sont dans `table_salon` et reçoivent des RPC. Vide chez un
## client et hors réseau.
var inscrits: Dictionary[int, Dictionary] = {}
## Sur chaque poste en session : la table du salon, la même partout, triée par index : une fiche
## `{"id": int, "index": int, "couleur": Color, "pseudo": String, "pret": bool}` par joueur ARRIVÉ
## (jamais une place seulement réservée). Construite par l'hôte depuis `inscrits`, reçue par les
## clients ; vide hors réseau.
var table_salon: Array[Dictionary] = []
## Niveau choisi par l'hôte au salon (index de `EtatPartie.NIVEAUX`), diffusé avec la table.
var niveau_salon := 0
## Places de la partie (`places` de l'hôte), diffusées avec la table.
var places_salon := EtatPartie.NB_JOUEURS_MAX
## Index et couleur de ce poste, attribués par l'hôte (-1 et transparente hors réseau).
var index_local := -1
var couleur_locale := Color.TRANSPARENT
## Chez l'hôte, pendant une manche : les identifiants des joueurs dont la scène de jeu est chargée,
## dans l'ordre (l'hôte compris) ; vidé au lancement de chaque manche et hors réseau.
var scenes_chargees: Array[int] = []
## Silence toléré des pairs de cette session (SILENCE_SESSION ou SILENCE_CHARGEMENT), posé sur
## chaque pair connecté et sur chaque nouveau venu.
var silence := SILENCE_SESSION

## Vrai dès que l'issue d'une connexion est décidée (refus, échec, hôte perdu) : un seul signal
## part, même quand ENet signale ensuite la fermeture qui en découle.
var _issue_decidee := false
## Incrémenté à chaque `quitter()` (donc à chaque `heberger()` ou `rejoindre()`, qui commencent par
## lui) : la génération de la session en cours. `_decider` capture la sienne avant de différer sa
## fermeture ; si une nouvelle session a déjà commencé quand l'appel différé s'exécute, il ne doit
## ni la fermer, ni émettre un signal qui ne la concerne plus.
var _generation := 0
var _delai: Timer
## Sessions quittées dont le départ n'est pas encore reçu : `{"pair": ENetMultiplayerPeer,
## "paquets": Array (ses ENetPacketPeer), "fin": int (ms)}`, servies par `_process` jusqu'à ce que
## chaque autre poste ait accusé réception, ou jusqu'à `fin`, puis fermées.
var _partants: Array[Dictionary] = []


func _ready() -> void:
	# Les délais courent aussi quand l'arbre est en pause (fin de manche).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_delai = Timer.new()
	_delai.one_shot = true
	_delai.timeout.connect(_sur_delai_depasse)
	add_child(_delai)
	var api := _api()
	api.server_relay = false  # M5 : aucun client ne parle à un autre, tout passe par l'hôte
	api.peer_authenticating.connect(_sur_debut_poignee_de_main)
	api.peer_authentication_failed.connect(_sur_echec_poignee_de_main)
	api.peer_connected.connect(_sur_pair_connecte)
	api.peer_disconnected.connect(_sur_pair_deconnecte)
	api.connected_to_server.connect(_sur_connecte_a_l_hote)
	api.connection_failed.connect(_sur_connexion_echouee)
	api.server_disconnected.connect(_sur_hote_perdu)


## Héberge une partie sur `port` : quitte d'abord toute session en cours, borne `places`, puis ce
## poste s'inscrit lui-même (index 0, première couleur). Si le port est pris, renvoie l'erreur
## d'ENet sans rien changer de plus (spec §9 : « port occupé ») : la session précédente reste
## close, mais rien de neuf n'est créé.
func heberger(port := PORT) -> Error:
	quitter()
	_clore_partants()  # une session hébergée qui part encore tient son port : le libérer d'abord
	places = clampi(places, EtatPartie.NB_JOUEURS_MIN, EtatPartie.NB_JOUEURS_MAX)
	var pair := ENetMultiplayerPeer.new()
	var erreur := pair.create_server(port, places + CONNEXIONS_EN_TROP)
	if erreur != OK:
		return erreur
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = pair
	index_local = premier_index_libre(inscrits, places)
	couleur_locale = premiere_couleur_libre(inscrits)
	inscrits[multiplayer.get_unique_id()] = {"index": index_local, "couleur": couleur_locale,
		"pseudo": pseudo_ou_defaut(pseudo, index_local), "arrive": true, "pret": false}
	places_salon = places
	_diffuser_salon()
	return OK


## Rejoint l'hôte à `adresse`, une IPv4 (M8 : un nom d'hôte serait résolu par `create_client` en
## bloquant le jeu, plusieurs secondes sous Windows pour une faute de frappe) : toute adresse que
## `Decouverte.adresse_ipv4` ne reconnaît pas est refusée (ERR_INVALID_PARAMETER) sans rien
## changer, pas même la session en cours. La réponse arrive par `inscrit`, `refuse` ou
## `connexion_echouee` (au plus tard après DELAI_CONNEXION). Renvoie l'erreur d'ENet si le client
## ne peut même pas être créé.
func rejoindre(adresse: String, port := PORT) -> Error:
	var ipv4: String = _Decouverte.adresse_ipv4(adresse)
	if ipv4.is_empty():
		return ERR_INVALID_PARAMETER
	quitter()
	var pair := ENetMultiplayerPeer.new()
	var erreur := pair.create_client(ipv4, port)
	if erreur != OK:
		return erreur
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = pair
	_delai.start(DELAI_CONNEXION)
	return OK


## Quitte le réseau : part proprement (les autres postes voient partir ce joueur, ou l'hôte : voir
## `_partir`), remet `OfflineMultiplayerPeer` et oublie inscrits, table du salon, index, couleur,
## scènes chargées et manche en cours (une session hébergée finie n'a plus lieu d'être). Sans effet
## visible hors réseau : chaque chemin de retour au titre peut l'appeler (point de vigilance des
## phases 12/13).
func quitter() -> void:
	_generation += 1
	_delai.stop()
	var pair := multiplayer.multiplayer_peer
	if pair is ENetMultiplayerPeer:
		_partir(pair)
	elif pair != null and not (pair is OfflineMultiplayerPeer):
		pair.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_api().auth_callback = Callable()
	inscrits.clear()
	table_salon.clear()
	scenes_chargees.clear()
	silence = SILENCE_SESSION
	niveau_salon = 0
	places_salon = EtatPartie.NB_JOUEURS_MAX
	index_local = -1
	couleur_locale = Color.TRANSPARENT
	manche_en_cours = false
	_issue_decidee = false


## Départ volontaire d'une session ENet (M6) : chaque autre poste connecté reçoit un DISCONNECT fiable,
## envoyé tout de suite, puis renvoyé par `_process` jusqu'à son accusé de réception (DELAI_DEPART au
## plus) ; la session est alors fermée. `close()` seul n'envoie qu'un datagramme non fiable : perdu
## en Wi-Fi, le départ ne serait vu qu'au bout du silence de l'autre poste.
func _partir(pair: ENetMultiplayerPeer) -> void:
	if pair.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		pair.close()
		return
	var connexion := pair.host
	var paquets: Array = [] if connexion == null else connexion.get_peers().filter(
		func(p: ENetPacketPeer) -> bool: return p.get_state() == ENetPacketPeer.STATE_CONNECTED)
	if paquets.is_empty():
		pair.close()
		return
	for p: ENetPacketPeer in paquets:
		p.peer_disconnect()
	connexion.flush()
	_partants.append({"pair": pair, "paquets": paquets, "fin": Time.get_ticks_msec() + DELAI_DEPART})


## Sert les départs en cours ; ferme ceux qui sont reçus ou dont le délai est passé.
func _process(_delta: float) -> void:
	if _partants.is_empty():
		return
	for partant: Dictionary in _partants.duplicate():
		partant.pair.poll()
		var recus: bool = partant.paquets.all(func(p: ENetPacketPeer) -> bool: return p.get_state() == ENetPacketPeer.STATE_DISCONNECTED)
		if recus or Time.get_ticks_msec() >= partant.fin:
			partant.pair.close()
			_partants.erase(partant)


## Ferme tout de suite les départs en cours (leurs ports se libèrent).
func _clore_partants() -> void:
	for partant: Dictionary in _partants:
		partant.pair.close()
	_partants.clear()


## Pose `bornes` (SILENCE_SESSION ou SILENCE_CHARGEMENT) comme silence toléré de chaque pair connecté
## de cette session, et de chaque nouveau venu (`silence`). Hors réseau, ne fait que le retenir.
func definir_silence(bornes: Vector2i) -> void:
	silence = bornes
	var pair := multiplayer.multiplayer_peer
	if pair is ENetMultiplayerPeer and pair.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED \
			and pair.host != null:
		for p: ENetPacketPeer in pair.host.get_peers():
			if p.get_state() == ENetPacketPeer.STATE_CONNECTED:
				p.set_timeout(ESSAIS_SILENCE, bornes.x, bornes.y)


## La scène de jeu de ce poste est chargée (appelé par la manche, chez chaque joueur) : chez l'hôte,
## noté tout de suite ; un client le fait savoir à l'hôte.
func signaler_scene_chargee() -> void:
	if multiplayer.is_server():
		_noter_scene_chargee(multiplayer.get_unique_id())
	else:
		_scene_chargee.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


func _noter_scene_chargee(id: int) -> void:
	if not scenes_chargees.has(id):
		scenes_chargees.append(id)
		scene_chargee.emit(id)


## Vrai si ce poste est en réseau (hôte ou client), faux hors réseau (solo).
func en_ligne() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


## Décision de l'hôte sur une demande d'inscription (le dictionnaire décodé, ou n'importe quoi
## venu d'un autre programme). Dans l'ordre : demande mal formée, version différente, manche en
## cours, partie pleine ; sinon l'index et la couleur libres les plus bas, et le pseudo nettoyé.
## Ne modifie rien : c'est `_repondre` qui inscrit.
func examiner_demande(demande: Variant) -> Dictionary:
	if not (demande is Dictionary) or not _est_texte(demande, "jeu") or demande.jeu != JEU \
			or not _est_texte(demande, "version") or not _est_texte(demande, "pseudo"):
		return _refus(REFUS_DEMANDE)
	if demande.version != version:
		return _refus(REFUS_VERSION)
	if manche_en_cours:
		return _refus(REFUS_MANCHE)
	var index := premier_index_libre(inscrits, places)
	if index < 0:
		return _refus(REFUS_PLEIN)
	return {"accepte": true, "index": index, "couleur": premiere_couleur_libre(inscrits), "pseudo": pseudo_ou_defaut(demande.pseudo, index)}


## Le plus petit index de joueur qu'aucun inscrit n'occupe, parmi les `places` premiers (au plus
## NB_JOUEURS_MAX) ; -1 si la partie est pleine.
static func premier_index_libre(occupes: Dictionary[int, Dictionary], nb_places: int) -> int:
	var pris := occupes.values().map(func(fiche: Dictionary) -> int: return fiche.index)
	for i in range(mini(nb_places, EtatPartie.NB_JOUEURS_MAX)):
		if not pris.has(i):
			return i
	return -1


## La première couleur de la palette de bataille qu'aucun inscrit ne porte (transparente s'il n'y
## en a plus, ce que les places interdisent). Le salon (phase 13) laissera chacun en changer
## parmi les libres.
static func premiere_couleur_libre(occupes: Dictionary[int, Dictionary]) -> Color:
	var prises := occupes.values().map(func(fiche: Dictionary) -> Color: return fiche.couleur)
	for c in EtatPartie.PALETTE_BATAILLE:
		if not prises.has(c):
			return c
	return Color.TRANSPARENT


## Vrai pour un point de code que l'étiquette du lion ne doit jamais afficher : les contrôles C0
## (`strip_escapes` ne va que jusqu'à U+001F) et C1, les caractères invisibles (espaces et joints de
## largeur nulle, U+FEFF) et les forçages de sens (RLO/LRO, isolats) qui casseraient la lecture ou
## la mise en page d'un pseudo hostile.
static func _code_point_interdit(c: int) -> bool:
	return c <= 0x1F or (c >= 0x7F and c <= 0x9F) \
		or (c >= 0x200B and c <= 0x200F) or c == 0x2028 or c == 0x2029 \
		or (c >= 0x202A and c <= 0x202E) or (c >= 0x2060 and c <= 0x206F) or c == 0xFEFF


## Le pseudo tel que l'hôte l'inscrit : sans caractères de contrôle, invisibles ni forçages de sens
## (voir `_code_point_interdit`), coupé à PSEUDO_MAX caractères puis sans espaces autour (pour ne
## pas laisser d'espace finale à la coupe). Peut être vide : c'est `pseudo_ou_defaut` qui y met un
## repli.
static func pseudo_valide(texte: String) -> String:
	var propre := ""
	for i in texte.length():
		var c := texte.unicode_at(i)
		if not _code_point_interdit(c):
			propre += texte.substr(i, 1)
	# Un premier strip_edges avant la coupe ne gâche pas le quota sur des espaces qui l'entourent ;
	# le second retire celle que la coupe peut exposer en fin de chaîne (spec M3).
	return propre.strip_edges().left(PSEUDO_MAX).strip_edges()


## `pseudo_valide(texte)`, ou « Joueur N » (N = index + 1) si le nettoyage ne laisse rien : un
## pseudo vide ne doit jamais atteindre `inscrits` ni l'étiquette du lion.
static func pseudo_ou_defaut(texte: String, index: int) -> String:
	var propre := pseudo_valide(texte)
	return propre if not propre.is_empty() else "Joueur %d" % (index + 1)


## Chez l'hôte, à l'ouverture du salon (et au retour d'une manche, phase 18) : plus de manche en
## cours (les arrivées sont de nouveau acceptées, la balise l'annonce), personne n'est prêt, le
## niveau est `niveau` (ramené dans la liste des niveaux).
func ouvrir_salon(niveau: int) -> void:
	if not multiplayer.is_server():
		return
	manche_en_cours = false
	for fiche: Dictionary in inscrits.values():
		fiche.pret = false
	niveau_salon = posmod(niveau, EtatPartie.NIVEAUX.size())
	_diffuser_salon()


## Chez l'hôte : le niveau du salon, ramené dans la liste des niveaux (en boucle). Sans effet
## pendant une manche.
func definir_niveau(niveau: int) -> void:
	if not multiplayer.is_server() or manche_en_cours:
		return
	niveau_salon = posmod(niveau, EtatPartie.NIVEAUX.size())
	_diffuser_salon()


## Demande de ce poste : la couleur libre suivante (`sens` 1) ou précédente (-1). L'hôte arbitre
## (`changer_couleur`) ; un client lui envoie sa demande.
func demander_couleur(sens: int) -> void:
	if multiplayer.is_server():
		changer_couleur(multiplayer.get_unique_id(), sens)
	else:
		_demande_couleur.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, sens)


## Demande de ce poste : prêt ou non. L'hôte arbitre (`definir_pret`) ; un client lui envoie sa
## demande.
func demander_pret(pret: bool) -> void:
	if multiplayer.is_server():
		definir_pret(multiplayer.get_unique_id(), pret)
	else:
		_demande_pret.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, pret)


## Chez l'hôte : le joueur `id` prend la couleur libre voisine de la sienne dans le sens `sens`
## (`couleur_voisine_libre`). Refusé (faux, rien ne change) pour un inconnu, un joueur pas encore
## arrivé ou déjà prêt (sa couleur est figée tant qu'il est prêt), un `sens` autre que 1 ou -1,
## pendant une manche, ou s'il n'y a aucune couleur libre. Les demandes sont traitées une à une :
## deux joueurs qui visent la même couleur ne peuvent pas l'obtenir tous les deux.
func changer_couleur(id: int, sens: int) -> bool:
	var fiche: Dictionary = inscrits.get(id, {})
	if not multiplayer.is_server() or manche_en_cours or absi(sens) != 1 or fiche.is_empty() \
			or not fiche.arrive or fiche.pret:
		return false
	var couleur := couleur_voisine_libre(inscrits, id, sens)
	if couleur == fiche.couleur:
		return false
	fiche.couleur = couleur
	if id == multiplayer.get_unique_id():
		couleur_locale = couleur
	_diffuser_salon()
	return true


## Chez l'hôte : le joueur `id` est prêt ou non. Refusé (faux) pour un inconnu, un joueur pas
## encore arrivé, pendant une manche, ou si rien ne change.
func definir_pret(id: int, pret: bool) -> bool:
	var fiche: Dictionary = inscrits.get(id, {})
	if not multiplayer.is_server() or manche_en_cours or fiche.is_empty() or not fiche.arrive or fiche.pret == pret:
		return false
	fiche.pret = pret
	_diffuser_salon()
	return true


## Chez l'hôte, quand il appuie sur « Démarrer la partie » : la manche commence. Plus aucune arrivée
## (`manche_en_cours`, que la balise annonce), index compactés sur 0..n-1 (des départs ont pu
## laisser des trous), table compactée diffusée (chaque client y lit son nouvel `index_local`),
## puis le lancement (`_recevoir_manche`, sur le même canal fiable que la table : il arrive
## après elle) ; `manche_lancee` part aussi ici. La demande est revérifiée ici, au moment même :
## faux, sans rien changer, si le salon n'est plus prêt (`salon_pret` : un joueur parti ou repassé
## non prêt dans la même image que l'appui, alors que le bouton n'était pas encore regrisé).
##
## M1 : les fiches de la manche sont aussi revérifiées avant tout engagement (défense en profondeur) :
## une table que `fiches_de_manche` refuse, une fois les index compactés (l'hôte n'y serait plus,
## par exemple), fait refuser le lancement, sans rien changer. Le chargement commence : le silence
## toléré devient SILENCE_CHARGEMENT, et plus aucune scène n'est chargée.
func lancer_manche() -> bool:
	if not multiplayer.is_server() or manche_en_cours or not salon_pret(inscrits):
		return false
	var essai: Dictionary[int, Dictionary] = inscrits.duplicate(true)
	compacter_index(essai)
	if fiches_de_manche(table_de(essai), multiplayer.get_unique_id()).is_empty():
		push_error("Reseau.lancer_manche : fiches de la manche incohérentes, lancement refusé")
		return false
	manche_en_cours = true
	scenes_chargees.clear()
	definir_silence(SILENCE_CHARGEMENT)
	compacter_index(inscrits)
	index_local = inscrits[multiplayer.get_unique_id()].index
	_diffuser_salon()
	if en_ligne():
		_recevoir_manche.rpc()
	manche_lancee.emit(fiches_de_manche(table_salon, multiplayer.get_unique_id()))
	return true


## Vrai si l'hôte peut démarrer la partie (`raison_attente` vide).
static func salon_pret(occupes: Dictionary[int, Dictionary]) -> bool:
	return raison_attente(occupes.values()).is_empty()


## Pourquoi la partie ne peut pas encore démarrer, dans cet ordre : moins de
## `EtatPartie.NB_JOUEURS_MIN` joueurs arrivés (ATTENTE_JOUEURS), une place encore réservée par une
## poignée de main en cours (ATTENTE_ARRIVEE : son joueur arrivera non prêt), quelqu'un qui n'est
## pas prêt (ATTENTE_PRETS) ; vide si elle peut démarrer. `fiches` : les fiches d'`inscrits` chez
## l'hôte, ou `table_salon` chez un client (arrivés seulement : une fiche sans `arrive` est une
## fiche d'arrivé).
static func raison_attente(fiches: Array) -> String:
	var arrives := fiches.filter(func(fiche: Dictionary) -> bool: return fiche.get("arrive", true))
	if arrives.size() < EtatPartie.NB_JOUEURS_MIN:
		return ATTENTE_JOUEURS
	if arrives.size() < fiches.size():
		return ATTENTE_ARRIVEE
	if not fiches.all(func(fiche: Dictionary) -> bool: return fiche.get("pret", false)):
		return ATTENTE_PRETS
	return ""


## La couleur de la palette voisine de celle du joueur `id` dans le sens `sens` (1 : suivante,
## -1 : précédente, la palette en boucle) qu'aucun autre inscrit ne porte, places réservées
## comprises ; sa propre couleur s'il n'y en a aucune ; transparente si `id` est inconnu.
static func couleur_voisine_libre(occupes: Dictionary[int, Dictionary], id: int, sens: int) -> Color:
	var fiche: Dictionary = occupes.get(id, {})
	if fiche.is_empty():
		return Color.TRANSPARENT
	var prises := occupes.keys().filter(func(autre: int) -> bool: return autre != id) \
		.map(func(autre: int) -> Color: return occupes[autre].couleur)
	var palette := EtatPartie.PALETTE_BATAILLE
	var depart := palette.find(fiche.couleur)
	for pas in range(1, palette.size() + 1):
		var c: Color = palette[posmod(depart + pas * signi(sens), palette.size())]
		if not prises.has(c):
			return c
	return fiche.couleur


## Renumérote en place les index de `occupes` sur 0..n-1, dans leur ordre (des départs ont pu
## laisser des trous que `premier_index_libre` ne comble qu'à une nouvelle arrivée).
static func compacter_index(occupes: Dictionary[int, Dictionary]) -> void:
	var ids := occupes.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return occupes[a].index < occupes[b].index)
	for i in range(ids.size()):
		occupes[ids[i]].index = i


## La table du salon tirée de `occupes` : les arrivés seulement, triés par index (voir
## `table_salon`).
static func table_de(occupes: Dictionary[int, Dictionary]) -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	for id: int in occupes:
		var fiche: Dictionary = occupes[id]
		if fiche.get("arrive", false):
			table.append({"id": id, "index": fiche.index, "couleur": fiche.couleur, "pseudo": fiche.pseudo, "pret": fiche.get("pret", false)})
	table.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.index < b.index)
	return table


## La table du salon reçue de l'hôte, vérifiée : au plus NB_JOUEURS_MAX fiches
## `{id, index, couleur, pseudo, pret}` aux identifiants (1 et plus), index (0 à NB_JOUEURS_MAX - 1)
## et couleurs (de la palette) tous distincts, triée par index, pseudos nettoyés comme l'hôte les
## nettoie ; un tableau vide pour toute autre chose.
static func lire_table(table: Variant) -> Array[Dictionary]:
	var lue: Array[Dictionary] = []
	if not (table is Array) or table.size() > EtatPartie.NB_JOUEURS_MAX:
		return lue
	var ids := []
	var index := []
	var couleurs := []
	for fiche: Variant in table:
		if not (fiche is Dictionary) or not (fiche.get("id") is int) or not (fiche.get("index") is int) \
				or not (fiche.get("couleur") is Color) or not (fiche.get("pseudo") is String) or not (fiche.get("pret") is bool) \
				or fiche.id < 1 or fiche.index < 0 or fiche.index >= EtatPartie.NB_JOUEURS_MAX \
				or not EtatPartie.PALETTE_BATAILLE.has(fiche.couleur) \
				or ids.has(fiche.id) or index.has(fiche.index) or couleurs.has(fiche.couleur):
			return [] as Array[Dictionary]
		ids.append(fiche.id)
		index.append(fiche.index)
		couleurs.append(fiche.couleur)
		lue.append({"id": fiche.id, "index": fiche.index, "couleur": fiche.couleur,
			"pseudo": pseudo_ou_defaut(fiche.pseudo, fiche.index), "pret": fiche.pret})
	lue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.index < b.index)
	return lue


## Les fiches de la manche tirées d'une table du salon (voir `manche_lancee`), ou un tableau vide si
## elle ne peut pas lancer de manche : moins de NB_JOUEURS_MIN joueurs, index qui ne sont pas
## exactement 0..n-1 (compactés par l'hôte), ou `id_local` absent (ce poste n'est pas dans la
## partie).
static func fiches_de_manche(table: Array[Dictionary], id_local: int) -> Array[Dictionary]:
	var fiches: Array[Dictionary] = []
	if table.size() < EtatPartie.NB_JOUEURS_MIN or not table.any(func(f: Dictionary) -> bool: return f.id == id_local):
		return fiches
	for i in range(table.size()):
		if table[i].index != i:
			return [] as Array[Dictionary]
		fiches.append({"id_reseau": table[i].id, "pseudo": table[i].pseudo, "couleur": table[i].couleur})
	return fiches


## Chez l'hôte : reconstruit `table_salon` depuis `inscrits` (arrivés seulement), la diffuse aux
## clients (`rpc()` ne vise que les pairs connectés, donc arrivés : jamais une place seulement
## réservée, M4) et émet `salon_change` ici.
func _diffuser_salon() -> void:
	if not multiplayer.is_server():
		return
	table_salon = table_de(inscrits)
	if en_ligne():
		_recevoir_salon.rpc(table_salon, niveau_salon, places_salon)
	salon_change.emit()


## Chez l'hôte : un client demande une autre couleur.
@rpc("any_peer", "call_remote", "reliable")
func _demande_couleur(sens: Variant) -> void:
	if sens is int:
		changer_couleur(multiplayer.get_remote_sender_id(), sens)


## Chez l'hôte : un client demande à être prêt, ou plus.
@rpc("any_peer", "call_remote", "reliable")
func _demande_pret(pret: Variant) -> void:
	if pret is bool:
		definir_pret(multiplayer.get_remote_sender_id(), pret)


## Chez un client : la table du salon diffusée par l'hôte (ignorée si elle est illisible). Ce
## poste y lit son index et sa couleur.
@rpc("authority", "call_remote", "reliable")
func _recevoir_salon(table: Variant, niveau: Variant, nb_places: Variant) -> void:
	var lue := lire_table(table)
	if lue.is_empty() or not (niveau is int) or niveau < 0 or niveau >= EtatPartie.NIVEAUX.size() \
			or not (nb_places is int) or nb_places < EtatPartie.NB_JOUEURS_MIN or nb_places > EtatPartie.NB_JOUEURS_MAX:
		push_warning("Reseau : table du salon illisible, ignorée")
		return
	table_salon = lue
	niveau_salon = niveau
	places_salon = nb_places
	for fiche in lue:
		if fiche.id == multiplayer.get_unique_id():
			index_local = fiche.index
			couleur_locale = fiche.couleur
	salon_change.emit()


## Chez un client : l'hôte lance la manche, sur la table compactée reçue juste avant. Le chargement
## commence : silence toléré SILENCE_CHARGEMENT.
@rpc("authority", "call_remote", "reliable")
func _recevoir_manche() -> void:
	var fiches := fiches_de_manche(table_salon, multiplayer.get_unique_id())
	if fiches.is_empty():
		push_warning("Reseau : lancement de manche sur une table illisible, ignoré")
		return
	manche_en_cours = true
	definir_silence(SILENCE_CHARGEMENT)
	manche_lancee.emit(fiches)


## Chez l'hôte : la scène de jeu d'un joueur de la manche est chargée (barrière avant l'intro).
@rpc("any_peer", "call_remote", "reliable")
func _scene_chargee() -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and manche_en_cours and inscrits.has(id):
		_noter_scene_chargee(id)


func _api() -> SceneMultiplayer:
	return multiplayer as SceneMultiplayer


func _activer_poignee_de_main() -> void:
	var api := _api()
	api.auth_callback = _sur_donnees_poignee_de_main
	api.auth_timeout = DELAI_POIGNEE_DE_MAIN


func _refus(raison: String) -> Dictionary:
	return {"accepte": false, "raison": raison, "version_hote": version}


static func _est_texte(d: Dictionary, cle: String) -> bool:
	return d.get(cle) is String


## Début de la poignée de main avec `id` : le client présente sa demande, l'hôte attend la sienne.
func _sur_debut_poignee_de_main(id: int) -> void:
	if multiplayer.is_server():
		return
	_api().send_auth(id, var_to_bytes({"jeu": JEU, "version": version, "pseudo": pseudo}))


## Décode les octets d'une poignée de main, ou renvoie `null` sans décoder si `donnees` dépasse
## TAILLE_POIGNEE_DE_MAIN_MAX : le coût de `bytes_to_var` doit rester borné, quel que soit
## l'émetteur sur le port UDP (spec M2). `examiner_demande` et `_lire_reponse` refusent déjà
## n'importe quoi qui n'est pas le dictionnaire attendu, `null` y compris.
static func decoder_poignee_de_main(donnees: PackedByteArray) -> Variant:
	return null if donnees.size() > TAILLE_POIGNEE_DE_MAIN_MAX else bytes_to_var(donnees)


## Octets de poignée de main reçus de `id` : une demande (chez l'hôte) ou la réponse de l'hôte.
func _sur_donnees_poignee_de_main(id: int, donnees: PackedByteArray) -> void:
	var contenu: Variant = decoder_poignee_de_main(donnees)
	if multiplayer.is_server():
		_repondre(id, contenu)
	else:
		_lire_reponse(contenu)


func _repondre(id: int, demande: Variant) -> void:
	if inscrits.has(id):
		return  # demande répétée : la première réponse fait foi
	var reponse := examiner_demande(demande)
	if reponse.accepte:
		inscrits[id] = {"index": reponse.index, "couleur": reponse.couleur, "pseudo": reponse.pseudo, "arrive": false, "pret": false}
		salon_change.emit()  # une place réservée : le bouton Démarrer de l'hôte se grise
	_api().send_auth(id, var_to_bytes(reponse))
	# Un refusé n'est pas déconnecté ici : ENet viderait sa file d'envoi, réponse comprise, et le
	# client ne saurait jamais pourquoi. Il part de lui-même en lisant le refus ; sinon le délai de
	# la poignée de main (DELAI_POIGNEE_DE_MAIN) le déconnecte.
	if reponse.accepte:
		_api().complete_auth(id)


func _lire_reponse(reponse: Variant) -> void:
	var valide := reponse is Dictionary and reponse.get("accepte") is bool
	if valide and reponse.accepte and reponse.get("index") is int and reponse.get("couleur") is Color \
			and reponse.index >= 0 and reponse.index < EtatPartie.NB_JOUEURS_MAX:
		index_local = reponse.index
		couleur_locale = reponse.couleur
		_api().complete_auth(MultiplayerPeer.TARGET_PEER_SERVER)
		return
	var raison: String = reponse.raison if valide and reponse.get("raison") is String else REFUS_DEMANDE
	var version_hote: String = reponse.version_hote if valide and reponse.get("version_hote") is String else ""
	_decider("refuse", [raison, version_hote])


## Chez l'hôte, un pair qui ne finit pas sa poignée de main (délai, départ) libère la place qui
## lui avait été attribuée ; il n'était jamais « arrivé », il ne « part » donc pas.
func _sur_echec_poignee_de_main(id: int) -> void:
	if multiplayer.is_server() and inscrits.erase(id):
		salon_change.emit()  # la place réservée se libère : le bouton de l'hôte peut revenir


## Chez l'hôte : un accepté a fini sa poignée de main. Il est désormais arrivé : sa carte apparaît
## au salon et la table lui est envoyée avec celle des autres.
func _sur_pair_connecte(id: int) -> void:
	if multiplayer.is_server() and inscrits.has(id):
		definir_silence(silence)  # le nouveau venu aussi
		inscrits[id].arrive = true
		_diffuser_salon()
		joueur_arrive.emit(id)


## Chez l'hôte : un arrivé est parti ; sa carte se libère chez tous (spec §4).
func _sur_pair_deconnecte(id: int) -> void:
	if multiplayer.is_server() and inscrits.erase(id):
		_diffuser_salon()
		joueur_parti.emit(id)


func _sur_connecte_a_l_hote() -> void:
	_delai.stop()
	definir_silence(silence)
	inscrit.emit(index_local, couleur_locale)


func _sur_connexion_echouee() -> void:
	_decider("connexion_echouee")


## L'hôte ferme la connexion. Avant l'inscription (délai encore en cours), c'est un échec de
## connexion, pas un hôte perdu : ce poste n'a jamais été dans la partie.
func _sur_hote_perdu() -> void:
	_decider("connexion_echouee" if not _delai.is_stopped() else "hote_perdu")


func _sur_delai_depasse() -> void:
	if en_ligne() and not multiplayer.is_server():
		_decider("connexion_echouee")


## Décide l'issue de la connexion (signal `nom`), une seule fois. Différé : on ne change pas de
## pair pendant que SceneMultiplayer traite ses paquets. Capture la génération de la session en
## cours (M5) : si une nouvelle session démarre avant que l'appel différé s'exécute, il ne doit
## rien faire à celle-ci.
func _decider(nom: StringName, arguments: Array = []) -> void:
	if _issue_decidee:
		return
	_issue_decidee = true
	_fermer_puis_emettre.call_deferred(nom, arguments, _generation)


## Revient hors réseau, puis émet le signal `nom` : ceux qui le reçoivent trouvent déjà le poste
## hors réseau (un retour au titre y relance une partie solo qui fonctionne). Sans effet si une
## nouvelle session a déjà commencé (`generation` périmée) : ni la fermer, ni émettre un signal
## qui ne la concerne plus (M5).
func _fermer_puis_emettre(nom: StringName, arguments: Array, generation: int) -> void:
	if generation != _generation:
		return
	quitter()
	callv("emit_signal", [nom] + arguments)
