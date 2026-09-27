extends SceneTree
## Le simulateur de latence (phase 16, spec §4.1) : un relais UDP, sur ce poste, entre des clients et un
## hôte, qui retarde, mélange et jette les datagrammes d'ENet dans les deux sens :
##   godot --headless --script tests/reseau/relais.gd -- --ecoute=<port> --vers=<port de l'hôte>
##       [--latence=80] [--gigue=40] [--pertes=5] [--graine=1] [--fin=<fichier>] [--duree=<s>]
## Les clients rejoignent 127.0.0.1 sur le port --ecoute ; chacun (adresse et port source) a sa liaison,
## avec son propre port vers l'hôte (127.0.0.1, port --vers). Chaque datagramme part avec un retard
## d'une demi-latence (--latence est l'aller-retour, en ms), plus ou moins une demi-gigue (--gigue : son
## étendue sur chaque aller), tirée au hasard, donc dans un ordre qui peut changer ; ou se perd, avec la
## probabilité --pertes (%). Comme en Wi-Fi : sous ENet, un datagramme fiable perdu est renvoyé (la
## peinture, les réactions, la poignée de main arrivent, en retard) ; un état ou un paquet de commandes
## perdu ne l'est pas (les suivants le remplacent, la redondance des commandes le couvre).
## Écrit « RELAIS PRET » quand il écoute ; s'arrête quand le fichier --fin existe (vérifié toutes les
## 0,1 s) ou au bout de --duree secondes (défaut 300), et écrit « RELAIS datagrammes=… perdus=…
## retard_moyen=… ms liaisons=… ». Aucun autoload n'est nommé ; rien du jeu n'est chargé.
## Hors du test réseau, il sert le contrôle à la main (◉) : un hôte sur son port, un client qui rejoint
## celui du relais.

var _options := {}
var _rng := RandomNumberGenerator.new()
var _latence := 80.0
var _gigue := 40.0
var _pertes := 5.0
var _datagrammes := 0
var _perdus := 0
var _retard_total := 0.0
## Datagrammes en route : `[instant d'envoi (µs), pair de sortie, octets]`.
var _en_route: Array = []


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var morceaux := arg.trim_prefix("--").split("=", true, 1)
		_options[morceaux[0]] = morceaux[1] if morceaux.size() > 1 else "oui"
	call_deferred("_run")


func _run() -> void:
	var ecoute := int(_options.get("ecoute", "0"))
	var vers := int(_options.get("vers", "0"))
	_latence = float(_options.get("latence", "80"))
	_gigue = float(_options.get("gigue", "40"))
	_pertes = float(_options.get("pertes", "5"))
	_rng.seed = int(_options.get("graine", "1"))
	var fin: String = _options.get("fin", "")
	var limite := Time.get_ticks_usec() + int(float(_options.get("duree", "300")) * 1000000.0)
	var serveur := UDPServer.new()
	if ecoute <= 0 or vers <= 0 or serveur.listen(ecoute, "127.0.0.1") != OK:
		printerr("  ❌ relais : --ecoute et --vers requis, port %d libre" % ecoute)
		quit(1)
		return
	print("RELAIS PRET ecoute=%d vers=%d latence=%.0f gigue=%.0f pertes=%.1f" % [ecoute, vers, _latence, _gigue, _pertes])
	var liaisons: Array = []  # [aval (vers le client), amont (vers l'hôte)]
	var controle := 0
	while Time.get_ticks_usec() < limite:
		var maintenant := Time.get_ticks_usec()
		if maintenant >= controle:
			if not fin.is_empty() and FileAccess.file_exists(fin):
				break
			controle = maintenant + 100000
		serveur.poll()
		while serveur.is_connection_available():
			var aval := serveur.take_connection()
			var amont := PacketPeerUDP.new()
			amont.connect_to_host("127.0.0.1", vers)
			liaisons.append([aval, amont])
		for liaison: Array in liaisons:
			var aval: PacketPeerUDP = liaison[0]
			var amont: PacketPeerUDP = liaison[1]
			while aval.get_available_packet_count() > 0:
				_programmer(amont, aval.get_packet(), maintenant)
			while amont.get_available_packet_count() > 0:
				_programmer(aval, amont.get_packet(), maintenant)
		var restants: Array = []
		for datagramme: Array in _en_route:
			if datagramme[0] <= maintenant:
				(datagramme[1] as PacketPeerUDP).put_packet(datagramme[2])
			else:
				restants.append(datagramme)
		_en_route = restants
		OS.delay_usec(250)
	var envoyes := _datagrammes - _perdus
	print("RELAIS datagrammes=%d perdus=%d (%.1f %%) retard_moyen=%.1f ms liaisons=%d" % [_datagrammes, _perdus,
		100.0 * _perdus / maxi(_datagrammes, 1), _retard_total / maxi(envoyes, 1), liaisons.size()])
	serveur.stop()
	quit(0)


## Un datagramme `octets` arrivé à `maintenant` (µs), à faire suivre par `sortie` : retardé, ou perdu.
func _programmer(sortie: PacketPeerUDP, octets: PackedByteArray, maintenant: int) -> void:
	_datagrammes += 1
	if _rng.randf() * 100.0 < _pertes:
		_perdus += 1
		return
	var retard := maxf(0.0, _latence / 2.0 + _rng.randf_range(-_gigue / 2.0, _gigue / 2.0))
	_retard_total += retard
	_en_route.append([maintenant + int(retard * 1000.0), sortie, octets])
