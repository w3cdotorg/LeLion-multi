extends SceneTree
## Un poste du test réseau, lancé par tests/reseau/lancer.sh (un processus Godot par poste) :
##   godot --headless --script tests/reseau/joueur.gd -- --role=hote|client|lent [options]
## Communes : --port=N (défaut 17777), --pseudo=texte.
## Hôte : --places=N (joueurs, hôte compris ; défaut 6), --clients=N (clients qui doivent arriver),
##   --partants=N (clients qui repartiront d'eux-mêmes), --manche (manche en cours : tout nouveau
##   venu est refusé), --refus=N (poignées de main qui doivent échouer : demandes refusées, dont le
##   client ferme la connexion en lisant le refus, ou jamais finies, coupées par le délai ; l'hôte
##   les compte par `peer_authentication_failed` et reste ouvert jusqu'à la N-ième, DELAI_ETAPE au
##   plus), --delai-poignee=S (délai de poignée de main de cette session, en secondes, au lieu de
##   `Reseau.DELAI_POIGNEE_DE_MAIN`). Écrit « HOTE PRET » quand il écoute et « POIGNEE ECHOUEE n »
##   à chaque poignée de main échouée (n = leur compte, après que `Reseau` a libéré la place), puis
##   quitte le réseau (ses clients doivent voir l'hôte partir).
## Client : --attendu=inscrit|inscrit_ou_plein|refus_plein|refus_version|refus_manche|echec,
##   --version=x.y (se présente avec cette version au lieu de la sienne), --partir (une fois inscrit
##   et un autre client en vue, quitte de lui-même ; sinon, attend que l'hôte parte), --feu=chemin
##   (écrit « ATTEND LE FEU » puis ne rejoint l'hôte qu'une fois ce fichier créé par lancer.sh,
##   DELAI_ETAPE au plus : le démarrage de Godot est déjà fait quand la demande doit partir). Écrit
##   une ligne « RESULTAT … » que lancer.sh compte d'un poste à l'autre. `refus_plein` est la
##   version déterministe d'`inscrit_ou_plein` (un seul dénouement possible, pas une course).
## Lent : présente sa demande sur sa propre poignée de main (son propre `ENetMultiplayerPeer` et
##   `SceneMultiplayer`, posé par `set_multiplayer` sur un nœud à lui : le `SceneTree` interroge
##   aussi ces API), mais n'appelle jamais `complete_auth` — sa poignée de main ne finit donc
##   jamais, et son propre délai de poignée de main est coupé (`auth_timeout` à 0) : seul l'hôte
##   peut y mettre fin. Écrit « ACCEPTE index=N » dès la réponse de l'hôte, puis attend que l'hôte
##   le coupe et vérifie que c'est au bout de --delai-poignee=S secondes (le délai de l'hôte ;
##   défaut `Reseau.DELAI_POIGNEE_DE_MAIN`). Preuve de bout en bout (Focus 2, Focus 5) que la place
##   d'un accepté est réservée dès la réponse et libérée par le vrai `auth_timeout` de l'hôte.
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
## `Reseau` par `root.get_node`, ne nomme ni `Reseau` ni `GameState` (il peut nommer
## `EtatPartie`, dont le script ne nomme aucun autoload).

const DELAI_ETAPE := 15.0  # secondes au plus pour chaque attente

var _echecs := 0
var _options := {}
var reseau: Node
var _arrivees: Array[int] = []
var _departs: Array[int] = []
var _poignees_echouees: Array[int] = []  # hôte : pairs dont la poignée de main a échoué, dans l'ordre
var _issue := ""  # client : les signaux reçus, dans l'ordre (voir `_ajouter_issue`)
var _raison := ""
var _version_hote := ""
var _index := -1
var _couleur := Color.TRANSPARENT


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var morceaux := arg.trim_prefix("--").split("=", true, 1)
		_options[morceaux[0]] = morceaux[1] if morceaux.size() > 1 else "oui"
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _option(nom: String, defaut: String) -> String:
	return _options.get(nom, defaut)


## Attend (au plus DELAI_ETAPE) que `condition` soit vraie ; renvoie sa dernière valeur.
func _attendre(condition: Callable) -> bool:
	var fin := Time.get_ticks_msec() + int(DELAI_ETAPE * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < fin:
		await process_frame
	return condition.call()


func _pause(secondes: float) -> void:
	await create_timer(secondes).timeout


func _run() -> void:
	reseau = root.get_node("Reseau")
	reseau.pseudo = _option("pseudo", "Poste")
	var role := _option("role", "")
	print("== poste réseau : %s (%s) ==" % [role, reseau.pseudo])
	if role == "hote":
		await _jouer_hote()
	elif role == "client":
		await _jouer_client()
	elif role == "lent":
		await _jouer_lent()
	else:
		_check(false, "rôle inconnu : --role=hote, --role=client ou --role=lent")
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		and root.multiplayer.is_server() and reseau.inscrits.is_empty() and reseau.index_local == -1,
		"à la fin, le poste est revenu hors réseau (pair hors ligne, hôte de lui-même, plus d'inscrits)")
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _jouer_hote() -> void:
	var nb_clients := int(_option("clients", "0"))
	var nb_partants := int(_option("partants", "0"))
	var nb_refus := int(_option("refus", "0"))
	reseau.places = int(_option("places", str(EtatPartie.NB_JOUEURS_MAX)))
	reseau.joueur_arrive.connect(_sur_arrivee)
	reseau.joueur_parti.connect(_sur_depart)
	# Branché après le gestionnaire de Reseau (connecté dans son _ready) : quand « POIGNEE ECHOUEE »
	# s'écrit, la place réservée est déjà libérée.
	root.multiplayer.peer_authentication_failed.connect(_sur_poignee_echouee)
	var erreur: int = reseau.heberger(int(_option("port", "17777")))
	_check(erreur == OK, "l'hôte écoute (erreur %d)" % erreur)
	if erreur != OK:
		return
	# manche_en_cours après heberger() : quitter() (que heberger() appelle en premier) le remet à
	# faux à chaque nouvelle session (I1).
	reseau.manche_en_cours = _options.has("manche")
	# heberger() vient de poser DELAI_POIGNEE_DE_MAIN sur l'API (avant toute poignée de main, avant
	# « HOTE PRET ») : c'est le vrai délai de poignée de main du jeu, couvert ici même quand
	# --delai-poignee l'écrase ensuite pour ce scénario (Scripts/Reseau.gd non touché).
	var api := root.multiplayer as SceneMultiplayer
	_check(api.auth_timeout == reseau.DELAI_POIGNEE_DE_MAIN and reseau.DELAI_POIGNEE_DE_MAIN > 0.0,
		"heberger() pose le délai de poignée de main du jeu (%.1f s)" % api.auth_timeout)
	if _options.has("delai-poignee"):
		# Après cette vérification et avant « HOTE PRET » : aucune poignée de main n'a commencé.
		# SceneMultiplayer relit auth_timeout à chaque image.
		api.auth_timeout = float(_option("delai-poignee", ""))
	print("HOTE PRET")
	var hote: Dictionary = reseau.inscrits[root.multiplayer.get_unique_id()]
	_check(root.multiplayer.is_server() and hote.index == 0 and hote.couleur == EtatPartie.PALETTE_BATAILLE[0]
		and hote.pseudo == reseau.pseudo, "l'hôte s'inscrit lui-même : index 0, première couleur, son pseudo")

	# Les poignées de main échouées d'abord : dans le scénario 5, l'arrivée attendue ne peut venir
	# qu'après la dernière (la place du client lent libérée par le délai). Les comptes ne font que
	# croître : l'ordre des attentes ne change rien aux autres scénarios.
	_check(await _attendre(func() -> bool: return _poignees_echouees.size() >= nb_refus),
		"%d poignée(s) de main échouée(s) sur %d attendue(s) (refus lus, ou délai dépassé)" % [_poignees_echouees.size(), nb_refus])
	_check(await _attendre(func() -> bool: return _arrivees.size() >= nb_clients),
		"%d client(s) arrivé(s) sur %d attendu(s)" % [_arrivees.size(), nb_clients])
	var indices: Array = reseau.inscrits.values().map(func(f: Dictionary) -> int: return f.index)
	var couleurs: Array = reseau.inscrits.values().map(func(f: Dictionary) -> Color: return f.couleur)
	indices.sort()
	var couleurs_distinctes := couleurs.all(func(c: Color) -> bool: return couleurs.count(c) == 1)
	var couleurs_de_la_palette := couleurs.all(func(c: Color) -> bool: return EtatPartie.PALETTE_BATAILLE.has(c))
	_check(indices == range(nb_clients + 1) and couleurs_distinctes and couleurs_de_la_palette,
		"les inscrits ont les index 0 à %d et chacun sa couleur de la palette (%s)" % [nb_clients, indices])

	if nb_partants > 0:
		_check(await _attendre(func() -> bool: return _departs.size() >= nb_partants),
			"%d client(s) parti(s) sur %d attendu(s)" % [_departs.size(), nb_partants])
		var libere: int = nb_clients + 1 - nb_partants
		_check(_departs.all(func(id: int) -> bool: return not reseau.inscrits.has(id)) and reseau.inscrits.size() == libere,
			"un client parti n'est plus inscrit (%d inscrits)" % reseau.inscrits.size())
		_check(reseau.premier_index_libre(reseau.inscrits, reseau.places) < nb_clients + 1,
			"son index est de nouveau libre")

	_check(_arrivees.size() == nb_clients and _poignees_echouees.size() == nb_refus,
		"ni arrivée ni poignée de main échouée de trop : %d client(s), %d échec(s) de poignée de main" % [_arrivees.size(), _poignees_echouees.size()])
	reseau.quitter()  # close() envoie ses paquets de façon synchrone (N7) : pas de pause à ajouter ici


func _jouer_client() -> void:
	var attendu := _option("attendu", "inscrit")
	var version_projet: String = reseau.version
	if _options.has("version"):
		reseau.version = _option("version", "")
	reseau.inscrit.connect(_sur_inscription)
	reseau.refuse.connect(_sur_refus)
	reseau.connexion_echouee.connect(_ajouter_issue.bind("echec"))
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	if _options.has("feu"):
		var feu := _option("feu", "")
		print("ATTEND LE FEU")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(feu)), "lancer.sh donne le feu (%s)" % feu)
	var debut := Time.get_ticks_msec()
	var erreur: int = reseau.rejoindre("127.0.0.1", int(_option("port", "17777")))
	_check(erreur == OK, "le client est créé (erreur %d)" % erreur)
	if erreur != OK:
		return
	await _attendre(func() -> bool: return not _issue.is_empty())
	var duree := (Time.get_ticks_msec() - debut) / 1000.0
	match _issue:
		"inscrit":
			print("RESULTAT inscrit index=%d" % _index)
		"refuse":
			print("RESULTAT refus %s" % _raison)
		_:
			print("RESULTAT %s" % _issue)

	match attendu:
		"inscrit", "inscrit_ou_plein":
			if attendu == "inscrit_ou_plein" and _issue == "refuse":
				_check(_raison == reseau.REFUS_PLEIN and _version_hote == version_projet,
					"refusé parce que la partie est pleine (%s)" % _raison)
				await _pause(1.0)
				_check(_issue == "refuse", "un refus n'est suivi d'aucun autre signal (%s)" % _issue)
				return
			_check(_issue == "inscrit" and _index >= 1 and _index < EtatPartie.NB_JOUEURS_MAX
				and _couleur == EtatPartie.PALETTE_BATAILLE[_index] and reseau.index_local == _index,
				"inscrit par l'hôte : index %d, couleur de la palette à cet index" % _index)
			if _issue != "inscrit":
				return
			if _options.has("partir"):
				_check(await _attendre(func() -> bool: return root.multiplayer.get_peers().size() >= 2),
					"un autre client est en vue (pairs : %s)" % [root.multiplayer.get_peers()])
				await _pause(0.5)
				reseau.quitter()
				_check(_issue == "inscrit", "partir de soi-même n'émet ni échec ni hôte perdu (%s)" % _issue)
			else:
				_check(await _attendre(func() -> bool: return _issue != "inscrit"), "l'hôte finit par partir")
				_check(_issue == "inscrit+hote_perdu", "le départ de l'hôte est signalé une fois, comme hôte perdu (%s)" % _issue)
		"refus_plein":
			_check(_issue == "refuse" and _raison == reseau.REFUS_PLEIN and _version_hote == version_projet,
				"refusé parce que la partie est pleine, sans course possible (%s, %s)" % [_raison, _issue])
			await _pause(1.0)
			_check(_issue == "refuse", "un refus n'est suivi d'aucun autre signal (%s)" % _issue)
		"refus_version", "refus_manche":
			var raison_attendue: String = reseau.REFUS_VERSION if attendu == "refus_version" else reseau.REFUS_MANCHE
			_check(_issue == "refuse" and _raison == raison_attendue and _version_hote == version_projet,
				"refusé avec la raison %s et la version de l'hôte %s (%s, %s)" % [raison_attendue, version_projet, _raison, _version_hote])
			await _pause(1.0)
			_check(_issue == "refuse", "un refus n'est suivi d'aucun autre signal (%s)" % _issue)
		"echec":
			_check(_issue == "echec" and duree >= reseau.DELAI_CONNEXION - 0.5 and duree <= reseau.DELAI_CONNEXION + 2.0,
				"sans hôte, la connexion échoue après le délai de %.0f s (%.1f s)" % [reseau.DELAI_CONNEXION, duree])
		_:
			_check(false, "issue attendue inconnue : %s" % attendu)


## Rôle de test « lent » (I2, Focus 2 et 5) : une poignée de main qui ne finit jamais, sur sa propre
## API (jamais celle de `Reseau`, jamais nommée). Preuve de bout en bout que la place d'un accepté
## est réservée dès la réponse de l'hôte (pas à l'arrivée), et libérée par le vrai `auth_timeout`.
func _jouer_lent() -> void:
	var noeud := Node.new()
	root.add_child(noeud)
	var api := SceneMultiplayer.new()
	set_multiplayer(api, noeud.get_path())  # ce script est déjà le SceneTree
	var pair := ENetMultiplayerPeer.new()
	var erreur := pair.create_client("127.0.0.1", int(_option("port", "17777")))
	_check(erreur == OK, "le client lent est créé (erreur %d)" % erreur)
	if erreur == OK:
		var pseudo_lent: String = reseau.pseudo
		# Un Dictionary, pas un bool local : une lambda GDScript capture les variables locales par
		# valeur, pas par référence ; `etat.accepte` reste, lui, partagé avec `_attendre` ci-dessous.
		var etat := {"accepte": false}
		api.peer_authenticating.connect(func(id: int) -> void:
			api.send_auth(id, var_to_bytes({"jeu": reseau.JEU, "version": reseau.version, "pseudo": pseudo_lent})))
		api.auth_callback = func(_id: int, donnees: PackedByteArray) -> void:
			var reponse: Variant = bytes_to_var(donnees)
			if reponse is Dictionary and reponse.get("accepte") == true:
				etat.accepte = true
				print("ACCEPTE index=%d" % reponse.index)
			# Jamais de complete_auth ici : la poignée de main ne finit pas, exprès.
		# Son propre délai coupé (0 = aucun) : sinon ce poste abandonnerait lui-même la poignée de
		# main au bout de 3 s (le défaut de SceneMultiplayer), et la coupure ne prouverait plus rien
		# du délai de l'hôte.
		# Pris avant la connexion (le délai de l'hôte ne peut démarrer qu'après) : « duree >= delai »
		# est une borne exacte, sans tolérance.
		var accepte_a := Time.get_ticks_msec()
		api.auth_timeout = 0.0
		api.multiplayer_peer = pair
		_check(await _attendre(func() -> bool: return etat.accepte), "le client lent reçoit une acceptation, sans jamais finir sa poignée de main")
		if etat.accepte:
			var delai := float(_option("delai-poignee", str(reseau.DELAI_POIGNEE_DE_MAIN)))
			var coupe := await _attendre(func() -> bool: return pair.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED)
			var duree := (Time.get_ticks_msec() - accepte_a) / 1000.0
			print("COUPE apres=%.1f s" % duree)
			_check(coupe and duree >= delai,
				"l'hôte coupe le client lent au bout de son délai de poignée de main (%.1f s, attendu %.0f s)" % [duree, delai])
	pair.close()
	noeud.queue_free()


func _sur_arrivee(id: int) -> void:
	_arrivees.append(id)
	var fiche: Dictionary = reseau.inscrits[id]
	print("  arrivée de %d : index %d, « %s »" % [id, fiche.index, fiche.pseudo])


func _sur_depart(id: int) -> void:
	_departs.append(id)


func _sur_poignee_echouee(id: int) -> void:
	_poignees_echouees.append(id)
	print("POIGNEE ECHOUEE %d (pair %d)" % [_poignees_echouees.size(), id])


func _sur_inscription(index: int, couleur: Color) -> void:
	_ajouter_issue("inscrit")
	_index = index
	_couleur = couleur


func _sur_refus(raison: String, version_hote: String) -> void:
	_ajouter_issue("refuse")
	_raison = raison
	_version_hote = version_hote


## Chaque signal reçu s'ajoute à l'issue : « inscrit+hote_perdu » est le parcours normal d'un
## client qui reste ; « refuse+echec » trahirait un double signal.
func _ajouter_issue(quoi: String) -> void:
	_issue = quoi if _issue.is_empty() else _issue + "+" + quoi
