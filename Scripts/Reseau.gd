extends Node
## Transport LAN (spec §4) : le pair ENet (port UDP 7777), la poignée de main (version, pseudo),
## l'attribution des index et des couleurs par l'hôte, les arrivées et les départs. Ne sait rien
## de la partie : le salon (phase 13) et la manche synchronisée (phase 14) s'appuient sur ses
## signaux et sur `inscrits`. Hors réseau (solo, retour au titre), le pair est un
## `OfflineMultiplayerPeer` : ce poste est son propre hôte (`multiplayer.is_server()` vrai), et
## `quitter()` y revient toujours.
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
## Autoload : les tests `--script`, compilés avant l'enregistrement des autoloads, le récupèrent
## par `root.get_node("Reseau")` et ne le nomment pas.

## Chez l'hôte : un joueur a fini sa poignée de main (il est dans `inscrits`, les RPC passent).
signal joueur_arrive(id: int)
## Chez l'hôte : un joueur arrivé est parti ; sa place, son index et sa couleur sont libres.
signal joueur_parti(id: int)
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
## réseau quand le signal part.
signal hote_perdu()

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
## Connexions ENet acceptées au-delà des places : de quoi recevoir, et refuser explicitement, les
## demandes d'une partie pleine au lieu de les laisser échouer sans explication.
const CONNEXIONS_EN_TROP := 2
const REFUS_VERSION := "RESEAU_REFUS_VERSION"
const REFUS_PLEIN := "RESEAU_REFUS_PLEIN"
const REFUS_MANCHE := "RESEAU_REFUS_MANCHE"
const REFUS_DEMANDE := "RESEAU_REFUS_DEMANDE"

## Version présentée à la poignée de main (`application/config/version`) ; deux versions
## différentes ne jouent pas ensemble. Modifiable par les tests.
var version: String = ProjectSettings.get_setting("application/config/version", "")
## Pseudo de ce poste, présenté à l'hôte (ou inscrit tel quel quand ce poste héberge).
var pseudo := ""
## Nombre de joueurs d'une partie hébergée, hôte compris (au plus `EtatPartie.NB_JOUEURS_MAX`).
var places := EtatPartie.NB_JOUEURS_MAX
## Posé par la partie (phase 13 au lancement de la manche, phase 18 au retour au salon) : tant
## qu'il est vrai, l'hôte refuse tout nouveau venu (pas d'arrivée en cours de manche, spec §1).
var manche_en_cours := false
## Chez l'hôte : les joueurs inscrits, hôte compris, par identifiant réseau :
## `{"index": int, "couleur": Color, "pseudo": String}`. Vide chez un client et hors réseau.
var inscrits: Dictionary[int, Dictionary] = {}
## Index et couleur de ce poste, attribués par l'hôte (-1 et transparente hors réseau).
var index_local := -1
var couleur_locale := Color.TRANSPARENT

## Vrai dès que l'issue d'une connexion est décidée (refus, échec, hôte perdu) : un seul signal
## part, même quand ENet signale ensuite la fermeture qui en découle.
var _issue_decidee := false
var _delai: Timer


func _ready() -> void:
	# Les délais courent aussi quand l'arbre est en pause (fin de manche).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_delai = Timer.new()
	_delai.one_shot = true
	_delai.timeout.connect(_sur_delai_depasse)
	add_child(_delai)
	var api := _api()
	api.peer_authenticating.connect(_sur_debut_poignee_de_main)
	api.peer_authentication_failed.connect(_sur_echec_poignee_de_main)
	api.peer_connected.connect(_sur_pair_connecte)
	api.peer_disconnected.connect(_sur_pair_deconnecte)
	api.connected_to_server.connect(_sur_connecte_a_l_hote)
	api.connection_failed.connect(_sur_connexion_echouee)
	api.server_disconnected.connect(_sur_hote_perdu)


## Héberge une partie sur `port`. Ce poste s'inscrit lui-même (index 0, première couleur).
## Renvoie l'erreur d'ENet sans rien changer si le port est pris (spec §9 : « port occupé »).
func heberger(port := PORT) -> Error:
	quitter()
	var pair := ENetMultiplayerPeer.new()
	var erreur := pair.create_server(port, places + CONNEXIONS_EN_TROP)
	if erreur != OK:
		return erreur
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = pair
	index_local = premier_index_libre(inscrits, places)
	couleur_locale = premiere_couleur_libre(inscrits)
	inscrits[multiplayer.get_unique_id()] = {"index": index_local, "couleur": couleur_locale, "pseudo": pseudo_valide(pseudo)}
	return OK


## Rejoint l'hôte à `adresse`. La réponse arrive par `inscrit`, `refuse` ou `connexion_echouee`
## (au plus tard après DELAI_CONNEXION). Renvoie l'erreur d'ENet si le client ne peut même pas
## être créé (adresse invalide).
func rejoindre(adresse: String, port := PORT) -> Error:
	quitter()
	var pair := ENetMultiplayerPeer.new()
	var erreur := pair.create_client(adresse, port)
	if erreur != OK:
		return erreur
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = pair
	_delai.start(DELAI_CONNEXION)
	return OK


## Quitte le réseau : ferme le pair (les autres postes voient partir ce joueur, ou l'hôte), remet
## `OfflineMultiplayerPeer` et oublie inscrits, index et couleur. Sans effet visible hors réseau :
## chaque chemin de retour au titre peut l'appeler (point de vigilance des phases 12/13).
func quitter() -> void:
	_delai.stop()
	var pair := multiplayer.multiplayer_peer
	if pair != null and not (pair is OfflineMultiplayerPeer):
		pair.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_api().auth_callback = Callable()
	inscrits.clear()
	index_local = -1
	couleur_locale = Color.TRANSPARENT
	_issue_decidee = false


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
	return {"accepte": true, "index": index, "couleur": premiere_couleur_libre(inscrits), "pseudo": pseudo_valide(demande.pseudo)}


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


## Le pseudo tel que l'hôte l'inscrit : sans caractères de contrôle ni espaces autour, au plus
## PSEUDO_MAX caractères.
static func pseudo_valide(texte: String) -> String:
	return texte.strip_escapes().strip_edges().left(PSEUDO_MAX)


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


## Octets de poignée de main reçus de `id` : une demande (chez l'hôte) ou la réponse de l'hôte.
func _sur_donnees_poignee_de_main(id: int, donnees: PackedByteArray) -> void:
	if multiplayer.is_server():
		_repondre(id, bytes_to_var(donnees))
	else:
		_lire_reponse(bytes_to_var(donnees))


func _repondre(id: int, demande: Variant) -> void:
	if inscrits.has(id):
		return  # demande répétée : la première réponse fait foi
	var reponse := examiner_demande(demande)
	if reponse.accepte:
		inscrits[id] = {"index": reponse.index, "couleur": reponse.couleur, "pseudo": reponse.pseudo}
	_api().send_auth(id, var_to_bytes(reponse))
	# Un refusé n'est pas déconnecté ici : ENet viderait sa file d'envoi, réponse comprise, et le
	# client ne saurait jamais pourquoi. Il part de lui-même en lisant le refus ; sinon le délai de
	# la poignée de main (DELAI_POIGNEE_DE_MAIN) le déconnecte.
	if reponse.accepte:
		_api().complete_auth(id)


func _lire_reponse(reponse: Variant) -> void:
	var valide := reponse is Dictionary and reponse.get("accepte") is bool
	if valide and reponse.accepte and reponse.get("index") is int and reponse.get("couleur") is Color:
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
	if multiplayer.is_server():
		inscrits.erase(id)


func _sur_pair_connecte(id: int) -> void:
	if multiplayer.is_server() and inscrits.has(id):
		joueur_arrive.emit(id)


func _sur_pair_deconnecte(id: int) -> void:
	if multiplayer.is_server() and inscrits.erase(id):
		joueur_parti.emit(id)


func _sur_connecte_a_l_hote() -> void:
	_delai.stop()
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
## pair pendant que SceneMultiplayer traite ses paquets.
func _decider(nom: StringName, arguments: Array = []) -> void:
	if _issue_decidee:
		return
	_issue_decidee = true
	_fermer_puis_emettre.call_deferred(nom, arguments)


## Revient hors réseau, puis émet le signal `nom` : ceux qui le reçoivent trouvent déjà le poste
## hors réseau (un retour au titre y relance une partie solo qui fonctionne).
func _fermer_puis_emettre(nom: StringName, arguments: Array) -> void:
	quitter()
	callv("emit_signal", [nom] + arguments)
