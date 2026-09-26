extends Node
## Découverte des parties sur le réseau local (spec §4) : la balise UDP de l'hôte et l'écoute de
## l'écran Réseau.
##
## Balise : tant que ce poste héberge (`Reseau` en ligne et hôte), une fois par PERIODE_BALISE, un
## datagramme texte vers le port PORT_BALISE de chaque destination de diffusion :
## `LELION|<version>|<port de jeu>|<nb joueurs>|<places>|<manche 0/1>|<niveau>|<pseudo hôte>`.
## Le pseudo, seul texte libre, vient en dernier : il peut contenir `|` sans décaler les autres
## champs. Personne n'a à démarrer ni à arrêter la balise : elle suit l'état de `Reseau` (un
## `Reseau.quitter()` l'arrête à la période suivante), jusque dans le salon (phase 13).
##
## Écoute : `ecouter()` ouvre le port PORT_BALISE (l'écran Réseau, tant qu'il cherche des parties),
## `arreter_ecoute()` le ferme. Les balises reçues remplissent `parties`, par « ip:port de jeu » ;
## une partie dont la balise ne revient pas pendant DELAI_EXPIRATION disparaît. Rien ne bloque le
## thread principal : sockets non bloquantes, adresses IP littérales (jamais de résolution de nom).
##
## Autoload : les tests `--script` le récupèrent par `root.get_node("Decouverte")` et ne le nomment
## pas. Ce script ne nomme aucun autoload (il trouve `Reseau` et `GameState` par leur chemin) : les
## fonctions statiques se testent sans eux.

## Une partie est apparue, a disparu, ou sa balise a changé (joueurs, manche, niveau…).
signal parties_changees()

const _Reseau := preload("res://Scripts/Reseau.gd")

const PORT_BALISE := 7778
## Secondes entre deux balises (spec §4 : toutes les secondes).
const PERIODE_BALISE := 1.0
## Une partie sans balise depuis ce délai, en secondes, disparaît de la liste (spec §4 : 3 s).
const DELAI_EXPIRATION := 3.0
## Adresse de diffusion limitée : tout le segment de l'interface par défaut.
const DIFFUSION := "255.255.255.255"
## Au-delà, un datagramme n'est pas une balise (le décodage reste borné, quel que soit l'émetteur).
const TAILLE_BALISE_MAX := 512
## Parties gardées au plus : des balises forgées ne font pas grossir la liste sans fin.
const PARTIES_MAX := 16
## Datagrammes lus au plus par image : un déluge sur le port ne gèle pas l'image, le reste attend
## l'image suivante.
const PAQUETS_PAR_IMAGE_MAX := 32
const _NB_CHAMPS := 8
## Une version reste courte et sans séparateur (elle s'affiche dans le refus « version différente »).
const _MOTIF_VERSION := "^[0-9A-Za-z._-]{1,16}$"

## Port des balises, émises et écoutées. Modifiable par les tests (jamais le 7778 d'une vraie partie).
var port_balise := PORT_BALISE
## Si non vide, les destinations des balises à la place de la diffusion (les tests : 127.0.0.1).
var destinations_forcees := PackedStringArray()
## Parties entendues, par « ip:port » : {version, port, nb_joueurs, places, manche_en_cours, niveau,
## pseudo, ip, vue_a (Time.get_ticks_msec de la dernière balise)}.
var parties: Dictionary[String, Dictionary] = {}
## Résultat du dernier `ecouter()` : OK, ou l'erreur du port (déjà pris par un autre programme ou
## un autre LeLion sur ce PC).
var erreur_ecoute := OK

var _ecouteur: PacketPeerUDP
var _emetteur: PacketPeerUDP
var _destinations := PackedStringArray()
static var _motif_version: RegEx = RegEx.create_from_string(_MOTIF_VERSION)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var minuterie := Timer.new()
	minuterie.wait_time = PERIODE_BALISE
	minuterie.timeout.connect(_emettre_balise)
	add_child(minuterie)
	minuterie.start()


## Ouvre l'écoute des balises sur `port_balise` (repart d'une liste vide). Renvoie OK, ou l'erreur
## si le port est déjà pris : rien ne plante, `ecoute_active()` reste faux, `erreur_ecoute` la garde.
func ecouter() -> Error:
	arreter_ecoute()
	var ecouteur := PacketPeerUDP.new()
	# Une socket IPv4 (et non « * », à double pile sous Windows) : les diffusions IPv4 y arrivent.
	erreur_ecoute = ecouteur.bind(port_balise, "0.0.0.0")
	if erreur_ecoute == OK:
		_ecouteur = ecouteur
	return erreur_ecoute


## Ferme l'écoute et oublie les parties entendues. Sans effet si rien n'écoute.
func arreter_ecoute() -> void:
	if _ecouteur != null:
		_ecouteur.close()
		_ecouteur = null
	if not parties.is_empty():
		parties.clear()
		parties_changees.emit()


func ecoute_active() -> bool:
	return _ecouteur != null


## Les parties entendues, triées par pseudo puis par adresse (un ordre stable pour la liste).
func parties_triees() -> Array[Dictionary]:
	var liste: Array[Dictionary] = []
	liste.assign(parties.values())
	liste.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ordre: int = a.pseudo.nocasecmp_to(b.pseudo)
		return ordre < 0 if ordre != 0 else "%s:%d" % [a.ip, a.port] < "%s:%d" % [b.ip, b.port])
	return liste


func _process(_delta: float) -> void:
	if _ecouteur == null:
		return
	var maintenant := Time.get_ticks_msec()
	var change := false
	var lus := 0
	while lus < PAQUETS_PAR_IMAGE_MAX and _ecouteur.get_available_packet_count() > 0:
		lus += 1
		var donnees := _ecouteur.get_packet()
		var fiche := decoder_balise(donnees)
		if not fiche.is_empty():
			change = enregistrer_partie(parties, _ecouteur.get_packet_ip(), fiche, maintenant) or change
	change = purger_parties(parties, maintenant, int(DELAI_EXPIRATION * 1000.0)) or change
	if change:
		parties_changees.emit()


## Chaque seconde : une balise si ce poste héberge, sinon la socket d'émission se ferme.
func _emettre_balise() -> void:
	var reseau := get_node_or_null(^"/root/Reseau")
	var pair := multiplayer.multiplayer_peer
	if reseau == null or not reseau.en_ligne() or not multiplayer.is_server() or not (pair is ENetMultiplayerPeer):
		_fermer_emetteur()
		return
	if _emetteur == null:
		_ouvrir_emetteur()
	var partie := get_node_or_null(^"/root/GameState")
	var hote: Dictionary = reseau.inscrits.get(multiplayer.get_unique_id(), {})
	var balise := encoder_balise(reseau.version, (pair as ENetMultiplayerPeer).host.get_local_port(),
		reseau.inscrits.size(), reseau.places, reseau.manche_en_cours,
		partie.niveau_courant if partie != null else 0, hote.get("pseudo", ""))
	for destination in _destinations:
		# Une destination injoignable (interface tombée, pas de route) n'empêche pas les autres.
		if _emetteur.set_dest_address(destination, port_balise) == OK:
			_emetteur.put_packet(balise)


func _ouvrir_emetteur() -> void:
	_emetteur = PacketPeerUDP.new()
	_emetteur.set_broadcast_enabled(true)
	_emetteur.bind(0, "0.0.0.0")  # port quelconque, IPv4 : la diffusion part de cette socket
	# Les interfaces sont relues à chaque session hébergée (câble branché, Wi-Fi changé entre-temps).
	_destinations = destinations_forcees if not destinations_forcees.is_empty() \
		else destinations_balise(IP.get_local_addresses())


func _fermer_emetteur() -> void:
	if _emetteur != null:
		_emetteur.close()
		_emetteur = null


## La balise d'une partie, en octets UTF-8.
static func encoder_balise(version: String, port: int, nb_joueurs: int, places: int, manche_en_cours: bool,
		niveau: int, pseudo: String) -> PackedByteArray:
	return "|".join(PackedStringArray([_Reseau.JEU, version, str(port), str(nb_joueurs), str(places),
		"1" if manche_en_cours else "0", str(niveau), pseudo])).to_utf8_buffer()


## La fiche d'une balise reçue : {version, port, nb_joueurs, places, manche_en_cours, niveau,
## pseudo} ; un dictionnaire vide pour tout ce qui n'est pas une balise valide (autre programme,
## datagramme tronqué ou forgé). Le pseudo est nettoyé comme l'hôte nettoie ceux de ses joueurs.
static func decoder_balise(donnees: PackedByteArray) -> Dictionary:
	if donnees.is_empty() or donnees.size() > TAILLE_BALISE_MAX:
		return {}
	var champs := donnees.get_string_from_utf8().split("|", true, _NB_CHAMPS - 1)
	if champs.size() != _NB_CHAMPS or champs[0] != _Reseau.JEU:
		return {}
	if _motif_version.search(champs[1]) == null:
		return {}
	for i in [2, 3, 4, 6]:
		if not champs[i].is_valid_int():
			return {}
	var port := champs[2].to_int()
	var nb_joueurs := champs[3].to_int()
	var places := champs[4].to_int()
	var niveau := champs[6].to_int()
	if port < 1 or port > 65535 or places < 2 or places > EtatPartie.NB_JOUEURS_MAX \
			or nb_joueurs < 1 or nb_joueurs > places or niveau < 0 or niveau >= EtatPartie.NIVEAUX.size() \
			or not (champs[5] == "0" or champs[5] == "1"):
		return {}
	return {"version": champs[1], "port": port, "nb_joueurs": nb_joueurs, "places": places,
		"manche_en_cours": champs[5] == "1", "niveau": niveau, "pseudo": _Reseau.pseudo_ou_defaut(champs[7], 0)}


## Inscrit (ou rafraîchit) dans `liste` la partie de la fiche `fiche` entendue depuis `ip` à
## `maintenant_ms`. Renvoie vrai si la liste affichée change (partie nouvelle ou balise différente),
## faux pour une simple balise répétée, ou pour une partie nouvelle quand la liste est pleine
## (PARTIES_MAX).
static func enregistrer_partie(liste: Dictionary[String, Dictionary], ip: String, fiche: Dictionary,
		maintenant_ms: int) -> bool:
	var cle := "%s:%d" % [ip, fiche.port]
	var ancienne: Dictionary = liste.get(cle, {})
	if ancienne.is_empty() and liste.size() >= PARTIES_MAX:
		return false
	var nouvelle := fiche.duplicate()
	nouvelle["ip"] = ip
	nouvelle["vue_a"] = maintenant_ms
	liste[cle] = nouvelle
	return ancienne.is_empty() or _sans_date(ancienne) != _sans_date(nouvelle)


static func _sans_date(partie: Dictionary) -> Dictionary:
	var copie := partie.duplicate()
	copie.erase("vue_a")
	return copie


## Retire de `liste` les parties sans balise depuis plus de `delai_ms`. Renvoie vrai si une partie
## a disparu.
static func purger_parties(liste: Dictionary[String, Dictionary], maintenant_ms: int, delai_ms: int) -> bool:
	var perimees := liste.keys().filter(func(cle: String) -> bool: return maintenant_ms - int(liste[cle].vue_a) > delai_ms)
	for cle: String in perimees:
		liste.erase(cle)
	return not perimees.is_empty()


## Destinations des balises pour les adresses locales `adresses` (`IP.get_local_addresses()`) : la
## diffusion limitée, plus la diffusion dirigée de chaque réseau privé IPv4 (a.b.c.255, en
## supposant un /24, le cas des box ; 169.254.255.255 pour une liaison directe sans DHCP). Sous
## Windows, 255.255.255.255 ne sort que par une interface, pas forcément celle du Wi-Fi de la LAN
## (VPN, cartes virtuelles) : la diffusion dirigée couvre les autres.
static func destinations_balise(adresses: PackedStringArray) -> PackedStringArray:
	var destinations := PackedStringArray([DIFFUSION])
	for adresse in adresses_privees(adresses):
		var octets := adresse.split(".")
		var dirigee := "169.254.255.255" if octets[0] == "169" else "%s.%s.%s.255" % [octets[0], octets[1], octets[2]]
		if not destinations.has(dirigee):
			destinations.append(dirigee)
	return destinations


## Les adresses IPv4 privées ou de liaison locale parmi `adresses` (10/8, 172.16/12, 192.168/16,
## 169.254/16), dans leur ordre : celles qu'un autre PC de la LAN peut joindre, que l'écran Réseau
## affiche à l'hôte pour la saisie par IP.
static func adresses_privees(adresses: PackedStringArray) -> PackedStringArray:
	var privees := PackedStringArray()
	for adresse in adresses:
		var normale := adresse_ipv4(adresse)
		if normale.is_empty():
			continue
		var octets := normale.split(".")
		var a := octets[0].to_int()
		var b := octets[1].to_int()
		if a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168) or (a == 169 and b == 254):
			if not privees.has(normale):
				privees.append(normale)
	return privees


## L'adresse IPv4 saisie `texte` sous sa forme normale (« 192.168.001.010 » → « 192.168.1.10 »), ou
## une chaîne vide si ce n'est pas une adresse joignable : quatre nombres de 0 à 255 d'un à trois
## chiffres, ni 0.x.x.x, ni multidiffusion ou réservée (224 et au-delà, 255.255.255.255 compris).
## Jamais de nom d'hôte : sa résolution bloquerait le thread principal (Windows : plusieurs
## secondes pour une faute de frappe).
static func adresse_ipv4(texte: String) -> String:
	var morceaux := texte.strip_edges().split(".")
	if morceaux.size() != 4:
		return ""
	var octets := PackedStringArray()
	for morceau in morceaux:
		if morceau.is_empty() or morceau.length() > 3 or not morceau.lstrip("0123456789").is_empty():
			return ""
		var valeur := morceau.to_int()
		if valeur > 255:
			return ""
		octets.append(str(valeur))
	var premier := octets[0].to_int()
	if premier == 0 or premier >= 224:
		return ""
	return ".".join(octets)
