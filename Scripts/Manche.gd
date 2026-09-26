extends Node
## La manche synchronisée (phase 14, spec §3.2) : ce qui passe entre l'hôte et les clients pendant
## une manche en réseau, sur ce nœud de la scène de jeu (`/root/Main/Manche`, au même chemin sur
## chaque poste). Hors réseau (solo, bataille locale), la scène de jeu ne l'appelle pas : il ne fait
## rien. L'hôte simule tout (lions, ennemis, pastilles, étourdissements, territoire) ; un client
## n'envoie que ses commandes et affiche ce que l'hôte décide.
## - Barrière de chargement : chaque poste signale sa scène de jeu chargée
##   (`Reseau.signaler_scene_chargee`) ; l'hôte attend tous les joueurs de la manche encore là, au
##   plus `delai_chargement` secondes de jeu, puis exclut les absents (il les déconnecte : leur
##   départ est un départ comme un autre) ; alors seulement (`barriere_passee`, chez l'hôte puis
##   chez chaque client) les lions apparaissent, le Spawner démarre et l'intro se lance chez tous.
## - Commandes : chaque client envoie à chaque tick physique la direction et l'envie de vomir de son
##   lion (RPC `unreliable_ordered`, numérotées : l'hôte ignore un numéro déjà vu, en attendant la
##   redondance de la phase 16) ; l'hôte les écrit dans les commandes manuelles de ce lion, et les
##   remet au repos après SILENCE_COMMANDES sans nouvelle commande.
## - Tampons : chaque tampon de la ville de l'hôte (`Ville.tampon_peint`) est diffusé, regroupé par
##   tick physique, sur le canal fiable 1 (`Peinture.encoder_tampons`) ; un client le dessine
##   (`Ville.peindre_tampon_recu`).
## - Territoire : toutes les INTERVALLE_TERRITOIRE secondes, l'hôte diffuse les cellules dont le
##   propriétaire compté a changé et les scores (même canal fiable) ; un client les applique
##   (`Territoire.appliquer_changements`) et vérifie qu'il a les mêmes scores.
## - Réactions des joueurs : étourdissement et sa fin, crans, gerbe XXL et sa fin partent de l'hôte en
##   RPC fiables, qui appellent chez chaque client les méthodes du `Joueur` qui émettent les mêmes
##   signaux (Lion, HUD, Audio).
## - Départs : un client parti (`Reseau.joueur_parti`) perd son lion chez l'hôte (sa disparition est
##   répliquée), ses cellules restent ; un hôte perdu arrête la manche du client (la scène de jeu
##   affiche le message et revient au titre).
## Nœud de scène : il nomme `Reseau` et `GameState` ; les tests `--script` ne le nomment pas.

## Chez l'hôte puis chez chaque client : la barrière de chargement est passée, la manche commence.
signal barriere_passee()
## Chez l'hôte : le joueur d'index `index` a quitté la manche (déconnecté, ou exclu faute de scène
## chargée à temps).
signal joueur_parti(index: int)

## Délai de la barrière de chargement, en secondes : au-delà, les joueurs dont la scène n'est pas
## chargée sont exclus.
const DELAI_CHARGEMENT := 20.0
## Sans commande d'un client depuis ce délai (ms), l'hôte remet son lion au repos (point de
## vigilance des phases 14 et 16 : un client planté ne laisse pas son lion filer ou vomir).
const SILENCE_COMMANDES := 500
## Période de diffusion du territoire (cellules changées et scores), en secondes (spec §6).
const INTERVALLE_TERRITOIRE := 0.2
## Canal ENet des tampons et du territoire (spec §4 : canal 1, fiable ordonné).
const CANAL_PEINTURE := 1

## Délai de la barrière de chargement de la prochaine manche : DELAI_CHARGEMENT, réglable par les
## tests réseau (le script de la manche, `load("res://Scripts/Manche.gd")`, porte cette variable).
static var delai_chargement := DELAI_CHARGEMENT

## Vrai une fois `demarrer` appelé, jusqu'à ce que l'hôte soit perdu (un client ne devient jamais
## hôte : revenu hors réseau, il attend le retour au titre).
var actif := false
## Vrai une fois la barrière passée (chez l'hôte et chez chaque client).
var barriere := false
## Statistiques de la manche, lues par le test réseau : tampons diffusés (hôte) ou reçus (client),
## et l'empreinte de leur suite (chaque lot, dans l'ordre), la même chez l'hôte et chez chaque client
## qui a tout reçu.
var tampons_diffuses := 0
var tampons_recus := 0
var empreinte_tampons := 0

var _hote := false
var _ville: Node2D
## Hôte : les commandes manuelles du lion de chaque client, par index de joueur. Client : les
## commandes de son lion (celles de ce poste), à l'index de son joueur.
var _commandes: Dictionary[int, Commandes] = {}
## Hôte : par index de joueur, la dernière commande reçue `{"numero": int, "a": int (ms)}`.
var _recues: Dictionary[int, Dictionary] = {}
## Hôte : les clients dont la scène est chargée, destinataires de tout ce que diffuse la manche.
var _prets: Array[int] = []
## Hôte : les clients exclus par la barrière, qui partent.
var _exclus: Array[int] = []
var _tampons: Array[Dictionary] = []
var _temps_territoire := 0.0
## Hôte : temps de jeu (ticks physiques) écoulé depuis le début du chargement. Pas l'horloge
## murale : un hôte figé (chargement, compilation des shaders) n'exclut personne en reprenant, avant
## d'avoir lu les « scène chargée » arrivés pendant qu'il était figé.
var _temps_chargement := 0.0
## Client : numéro de la dernière commande envoyée.
var _numero := 0


func _ready() -> void:
	# Après les lions et leurs traceuses (priorité 0) : les tampons d'un tick partent dans ce tick.
	process_physics_priority = 100


## Commence la manche en réseau, sur la ville `ville` de la scène de jeu : appelé par `Main` en
## réseau seulement, une fois sa scène prête. La manche continue alors même quand l'arbre est en
## pause (fin de manche) : ses derniers tampons et son territoire partent quand même.
func demarrer(ville: Node2D) -> void:
	actif = true
	_ville = ville
	_hote = multiplayer.is_server()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Reseau.hote_perdu.connect(_sur_hote_perdu)
	if _hote:
		Reseau.scene_chargee.connect(_sur_scene_chargee)
		Reseau.joueur_parti.connect(_sur_depart_reseau)
	Reseau.signaler_scene_chargee()
	if _hote:
		_verifier_barriere()


## Les autoloads survivent à la scène de jeu : ne rien leur laisser.
func _exit_tree() -> void:
	for connexion: Array in [[Reseau.hote_perdu, _sur_hote_perdu], [Reseau.scene_chargee, _sur_scene_chargee],
			[Reseau.joueur_parti, _sur_depart_reseau]]:
		if (connexion[0] as Signal).is_connected(connexion[1]):
			(connexion[0] as Signal).disconnect(connexion[1])


## Le lion `lion` vient d'apparaître sur ce poste (appelé par `Main`) : chez l'hôte, les commandes
## manuelles du lion d'un client y seront écrites ; chez un client, les commandes de son propre lion
## partiront vers l'hôte.
func suivre_lion(lion: Lion) -> void:
	var local := lion.joueur == GameState.joueur_local()
	if (_hote and not local) or (not _hote and local):
		_commandes[lion.joueur.index] = lion.commandes


## Chez l'hôte : vrai si le joueur d'index `index` est encore dans la manche (inscrit, ni parti ni
## exclu) : son lion doit apparaître.
func joue(index: int) -> bool:
	if index < 0 or index >= GameState.joueurs.size():
		return false
	var id := GameState.joueurs[index].id_reseau
	return Reseau.inscrits.has(id) and not _exclus.has(id)


func _physics_process(delta: float) -> void:
	if not actif:
		return
	if not _hote:
		_envoyer_commandes()
		return
	if not barriere:
		_temps_chargement += delta
		_verifier_barriere()
		return
	verifier_silences(Time.get_ticks_msec())
	_diffuser_tampons()
	_temps_territoire += delta
	if _temps_territoire >= INTERVALLE_TERRITOIRE:
		_temps_territoire = 0.0
		_diffuser_territoire()


# --- Barrière de chargement (hôte) ---------------------------------------------------------------


func _sur_scene_chargee(_id: int) -> void:
	_verifier_barriere()


## Les identifiants réseau des joueurs de la manche encore inscrits chez l'hôte (hôte compris).
func _attendus() -> Array[int]:
	var ids: Array[int] = []
	for j in GameState.joueurs:
		if Reseau.inscrits.has(j.id_reseau):
			ids.append(j.id_reseau)
	return ids


## Passe la barrière quand chaque joueur encore là a chargé sa scène. Délai passé, les absents sont
## exclus (déconnectés) : la barrière attend alors leur départ, qui les retire des attendus.
func _verifier_barriere() -> void:
	if barriere or not actif:
		return
	var absents := _attendus().filter(func(id: int) -> bool: return not Reseau.scenes_chargees.has(id))
	if not absents.is_empty():
		if _temps_chargement >= delai_chargement:
			for id: int in absents:
				_exclure(id)
		return
	barriere = true
	_prets.clear()
	for id in Reseau.scenes_chargees:
		if id != multiplayer.get_unique_id() and Reseau.inscrits.has(id):
			_prets.append(id)
	Reseau.definir_silence(Reseau.SILENCE_SESSION)
	_ville.tampon_peint.connect(_sur_tampon_peint)
	for j in GameState.joueurs:
		j.etourdi.connect(_sur_etourdi.bind(j))
		j.etourdissement_fini.connect(_sur_fin_etourdissement.bind(j))
		j.crans_changes.connect(_sur_crans.bind(j))
		j.bonus_change.connect(_sur_bonus.bind(j))
	barriere_passee.emit()  # la scène fait apparaître les lions : leurs apparitions partent avant l'intro
	_envoyer(&"_lancer_intro", [])


## Chez l'hôte : `id` n'a pas chargé sa scène à temps. Il est déconnecté (proprement : il le voit
## comme un hôte perdu, et son départ arrive ici par `Reseau.joueur_parti`).
func _exclure(id: int) -> void:
	if _exclus.has(id):
		return
	_exclus.append(id)
	push_warning("Manche : le joueur %d n'a pas chargé sa scène à temps, exclu" % id)
	if multiplayer.get_peers().has(id):
		multiplayer.multiplayer_peer.disconnect_peer(id)


## Chez un client : la barrière est passée chez l'hôte.
@rpc("authority", "call_remote", "reliable")
func _lancer_intro() -> void:
	if not actif or barriere:
		return
	barriere = true
	Reseau.definir_silence(Reseau.SILENCE_SESSION)
	barriere_passee.emit()


# --- Commandes -------------------------------------------------------------------------------------


## Chez un client : les commandes de son lion, une fois par tick physique.
func _envoyer_commandes() -> void:
	if not barriere or _commandes.is_empty():
		return
	var c: Commandes = _commandes.values()[0]
	_numero += 1
	_recevoir_commandes.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, _numero, c.direction(), c.vomir())


## Chez l'hôte : les commandes d'un client, pour son lion.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _recevoir_commandes(numero: Variant, direction: Variant, vomir: Variant) -> void:
	if not _hote:
		return
	var id := multiplayer.get_remote_sender_id()
	for j in GameState.joueurs:
		if j.id_reseau == id:
			recevoir_commandes_de(j.index, numero, direction, vomir, Time.get_ticks_msec())
			return


## Chez l'hôte : écrit la commande `numero` du joueur d'index `index` dans les commandes de son lion,
## reçue à `maintenant` (ms). Refusée (faux) pour un lion inconnu, des arguments d'un autre type ou
## non finis, ou un numéro déjà vu.
func recevoir_commandes_de(index: int, numero: Variant, direction: Variant, vomir: Variant, maintenant: int) -> bool:
	var c: Commandes = _commandes.get(index)
	if c == null or not (numero is int) or not (direction is Vector2) or not (vomir is bool) or not direction.is_finite():
		return false
	if numero <= _recues.get(index, {"numero": 0}).numero:
		return false
	c.direction_voulue = direction  # bornée à une longueur de 1 par `Commandes.direction()`
	c.vomir_voulu = vomir
	_recues[index] = {"numero": numero, "a": maintenant}
	return true


## Chez l'hôte : le lion d'un client dont aucune commande n'est arrivée depuis SILENCE_COMMANDES ms
## (à `maintenant`) revient au repos.
func verifier_silences(maintenant: int) -> void:
	for index: int in _recues:
		if maintenant - int(_recues[index].a) > SILENCE_COMMANDES and _commandes.has(index):
			_commandes[index].direction_voulue = Vector2.ZERO
			_commandes[index].vomir_voulu = false


# --- Tampons et territoire -------------------------------------------------------------------------


func _sur_tampon_peint(tampon: Dictionary) -> void:
	_tampons.append(tampon)


## Chez l'hôte : les tampons de ce tick, en un seul envoi.
func _diffuser_tampons() -> void:
	if _tampons.is_empty():
		return
	var octets := Peinture.encoder_tampons(_tampons)
	tampons_diffuses += _tampons.size()
	empreinte_tampons = hash([empreinte_tampons, octets])
	_envoyer(&"_recevoir_tampons", [octets])
	_tampons.clear()


## Chez un client : les tampons d'un tick de l'hôte, dessinés dans l'ordre.
@rpc("authority", "call_remote", "reliable", CANAL_PEINTURE)
func _recevoir_tampons(octets: Variant) -> void:
	if not actif:
		return
	var tampons := Peinture.decoder_tampons(octets)
	if tampons.is_empty():
		push_warning("Manche : lot de tampons illisible, ignoré")
		return
	for tampon in tampons:
		_ville.peindre_tampon_recu(tampon)
	tampons_recus += tampons.size()
	empreinte_tampons = hash([empreinte_tampons, octets])


## Chez l'hôte : les cellules changées depuis le dernier envoi et les scores.
func _diffuser_territoire() -> void:
	var territoire: Territoire = _ville.territoire
	if territoire == null:
		return
	var changees := territoire.extraire_changements()
	if changees.is_empty():
		return
	_envoyer(&"_recevoir_territoire", [territoire.encoder_changements(changees), territoire.scores()])


## Chez un client : les cellules changées chez l'hôte, appliquées ; les scores doivent alors être
## ceux de l'hôte (sinon, une désynchronisation est signalée).
@rpc("authority", "call_remote", "reliable", CANAL_PEINTURE)
func _recevoir_territoire(octets: Variant, scores: Variant) -> void:
	var territoire: Territoire = null if _ville == null else _ville.territoire
	if not actif or territoire == null:
		return
	if not territoire.appliquer_changements(octets):
		push_warning("Manche : cellules changées illisibles, ignorées")
		return
	if not (scores is PackedInt32Array) or scores != territoire.scores():
		push_error("Manche : territoire désynchronisé de l'hôte (%s au lieu de %s)" % [territoire.scores(), scores])


# --- Réactions des joueurs -------------------------------------------------------------------------


func _sur_etourdi(origine: Vector2, barbouillage: Color, j: Joueur) -> void:
	_envoyer(&"_recevoir_etourdi", [j.index, j.etourdi_restant, j.invulnerable_restant - j.etourdi_restant, origine, barbouillage])


func _sur_fin_etourdissement(j: Joueur) -> void:
	_envoyer(&"_recevoir_fin_etourdissement", [j.index, j.invulnerable_restant])


func _sur_crans(crans: int, j: Joueur) -> void:
	_envoyer(&"_recevoir_crans", [j.index, crans])


func _sur_bonus(actif_: bool, j: Joueur) -> void:
	if actif_:
		_envoyer(&"_recevoir_bonus", [j.index, j.bonus_restant])
	else:
		_envoyer(&"_recevoir_fin_bonus", [j.index])


@rpc("authority", "call_remote", "reliable")
func _recevoir_etourdi(index: Variant, duree: Variant, immunite: Variant, origine: Variant, barbouillage: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null and duree is float and immunite is float and origine is Vector2 and barbouillage is Color:
		j.etourdir(duree, immunite, origine, barbouillage)


@rpc("authority", "call_remote", "reliable")
func _recevoir_fin_etourdissement(index: Variant, immunite: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null and immunite is float:
		j.recevoir_fin_etourdissement(immunite)


@rpc("authority", "call_remote", "reliable")
func _recevoir_crans(index: Variant, crans: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null and crans is int:
		j.recevoir_crans(crans)


@rpc("authority", "call_remote", "reliable")
func _recevoir_bonus(index: Variant, duree: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null and duree is float:
		j.activer_bonus(duree)


@rpc("authority", "call_remote", "reliable")
func _recevoir_fin_bonus(index: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null:
		j.recevoir_fin_bonus()


## Le joueur d'index `index` reçu de l'hôte, ou null (index d'un autre type ou hors de la table).
func _joueur_recu(index: Variant) -> Joueur:
	if not actif or not (index is int) or index < 0 or index >= GameState.joueurs.size():
		return null
	return GameState.joueurs[index]


# --- Départs ----------------------------------------------------------------------------------------


## Chez l'hôte : le client `id` est parti (ou a été exclu).
func _sur_depart_reseau(id: int) -> void:
	_prets.erase(id)
	for j in GameState.joueurs:
		if j.id_reseau == id:
			_commandes.erase(j.index)
			_recues.erase(j.index)
			joueur_parti.emit(j.index)
	_verifier_barriere()


## Chez un client : l'hôte est perdu (ce poste est déjà hors réseau) ; la manche s'arrête là.
func _sur_hote_perdu() -> void:
	actif = false


## Chez l'hôte : appelle la RPC `methode` chez chaque client prêt et encore connecté (jamais chez un
## client dont la scène de jeu n'est pas chargée : le nœud de la manche n'y existe pas encore ; ni
## chez un client déjà déconnecté dont le départ n'est pas encore arrivé ici).
func _envoyer(methode: StringName, arguments: Array) -> void:
	var connectes := multiplayer.get_peers()
	for id in _prets:
		if connectes.has(id):
			callv("rpc_id", [id, methode] + arguments)
