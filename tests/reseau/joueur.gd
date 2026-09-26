extends SceneTree
## Un poste du test réseau, lancé par tests/reseau/lancer.sh (un processus Godot par poste) :
##   godot --headless --script tests/reseau/joueur.gd -- --role=<rôle> [options]
## Rôles : hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client,
## manche-muet.
## Communes : --port=N (défaut 17777), --pseudo=texte, --port-balise=N (port des balises de
##   découverte, émises par un hôte et écoutées par un écouteur ; défaut : --port + 1000),
##   --diffusion (balises en vraie diffusion, comme en jeu ; sans elle, vers 127.0.0.1 seulement).
## Hôte : --places=N (joueurs, hôte compris ; défaut 6), --clients=N (clients qui doivent arriver),
##   --partants=N (clients qui repartiront d'eux-mêmes), --manche (manche en cours : tout nouveau
##   venu est refusé), --refus=N (poignées de main qui doivent échouer : demandes refusées, dont le
##   client ferme la connexion en lisant le refus, ou jamais finies, coupées par le délai ; l'hôte
##   les compte par `peer_authentication_failed` et reste ouvert jusqu'à la N-ième, DELAI_ETAPE au
##   plus), --delai-poignee=S (délai de poignée de main de cette session, en secondes, au lieu de
##   `Reseau.DELAI_POIGNEE_DE_MAIN`), --rester=chemin (une fois ses vérifications faites, écrit
##   « HOTE RESTE » et ne quitte le réseau qu'une fois ce fichier créé par lancer.sh, DELAI_ETAPE au
##   plus), --apres-depart=S (le processus vit encore S secondes après avoir quitté le réseau : sa
##   balise doit s'arrêter d'elle-même, pas avec le processus). Écrit « HOTE PRET » quand il écoute
##   et « POIGNEE ECHOUEE n » à chaque poignée de main échouée (n = leur compte, après que `Reseau` a
##   libéré la place), puis quitte le réseau (ses clients doivent voir l'hôte partir).
## Client : --attendu=inscrit|inscrit_ou_plein|refus_plein|refus_version|refus_manche|echec,
##   --version=x.y (se présente avec cette version au lieu de la sienne), --partir (une fois inscrit
##   et un autre client en vue dans la table de l'hôte, quitte de lui-même ; sinon, attend que
##   l'hôte parte), --feu=chemin
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
## Écouteur (phase 12) : écoute les balises (`Decouverte`), vérifie que des datagrammes étrangers
##   n'ajoutent aucune partie, écrit « ECOUTE PRETE », attend la partie de --hote=pseudo et vérifie
##   sa balise (adresse, --port, version, 1 joueur sur --places=N, pas de manche) : « PARTIE VUE ».
##   Avec --rejoindre, la rejoint à l'adresse et au port de sa balise, attend la balise qui compte
##   2 joueurs (« PARTIE A 2 »), puis le départ de l'hôte. Enfin, la partie doit disparaître de la
##   liste DELAI_EXPIRATION après sa dernière balise (« PARTIE EXPIREE ») et, avec --rejoindre, au
##   plus PERIODE_BALISE + DELAI_EXPIRATION (plus une marge) après le départ de l'hôte. Avec
##   --occupe : un second écouteur sur un port de balises déjà pris ; `ecouter()` doit renvoyer une
##   erreur sans planter (deux LeLion sur un même PC).
## Salon (phase 13), par les vraies scènes : l'écran Réseau (Héberger, ou Rejoindre par IP vers
##   127.0.0.1), qui passe la main au salon, puis la scène de jeu. Chaque poste écrit
##   « SALON OUVERT » à l'ouverture de son salon, note la ligne d'état du salon après chaque
##   `salon_change` (vérifiée à la fin), et écrit « MANCHE <empreinte> » une fois la scène de jeu
##   chargée (identifiant, pseudo et couleur de chaque index de `GameState.joueurs`, puis le
##   niveau : la même sur tous les postes).
##   Salon-hôte : --clients=N (arrivées attendues), --partants=K (départs attendus), --niveau=L (le
##   niveau qu'il choisit, par haut/bas), --rester=chemin (comme l'hôte). Écrit « HOTE PRET » une
##   fois son salon ouvert, « SALON COMPLET » quand la table compte 1 + N - K joueurs, puis se
##   déclare prêt ; « BOUTON ACTIF » chaque fois que « Démarrer la partie » s'active. La première
##   fois, il attend qu'un client repasse non prêt (le bouton se regrise), essaie quand même de
##   démarrer (« DEMARRAGE REFUSE » : la manche ne part pas) ; la seconde, il démarre.
##   Salon-client : --voir=N (attend d'avoir vu la table compter N joueurs : « SALON VU N »), puis
##   --partir (quitte le salon par Retour : l'écran Réseau revient) ou --reste=M (attend que la
##   table compte M joueurs ; défaut 2), --couleur=S et --feu=chemin (« ATTEND LE FEU », puis
##   demande la couleur voisine dans le sens S au feu : « COULEUR <html> »), prêt ensuite ;
##   --annuler=chemin (une fois ce fichier créé, repasse non prêt : « PLUS PRET » ; puis se
##   redéclare prêt une fois --relance=chemin créé), --index=K (son index attendu dans la manche,
##   compactés compris). Vérifie à la fin avoir vu « l'hôte peut démarrer », puis attend le départ
##   de l'hôte.
## Manche (phase 14), par les vraies scènes jusqu'à la scène de jeu, puis une manche jouée au clavier
##   de chaque poste (actions pressées comme un joueur : `Input.action_press`).
##   Manche-hôte : --clients=N (arrivées attendues, le muet compris), --gel=S (fige son processus S
##   secondes dès sa scène de jeu chargée : ses clients, qui chargent, ne doivent pas le croire
##   parti), --delai-chargement=S (délai de la barrière), --rester=chemin. Écrit « HOTE PRET »,
##   « BARRIERE prets=… exclus=… », « DEPART VU », puis, une fois les lions arrêtés et les coulures
##   finies, fige la manche (`terminer_partie`) : « EMPREINTE <territoire, scores, tampons,
##   lions, apparitions> » et « FIGE ».
##   Manche-client : --sens=1|-1 (sa passe de peinture, vers la droite ou la gauche), --partir (quitte
##   la manche par le menu local une fois sa passe faite : « PARTI »), --fige=chemin (une fois ce
##   fichier créé par lancer.sh, attend ses coulures puis écrit sa propre « EMPREINTE »), puis attend
##   le départ de l'hôte (« L'hôte a quitté la partie », puis le titre).
##   Manche-muet : rejoint l'hôte sans scène (pas de salon ni de scène de jeu), se dit prêt, reçoit le
##   lancement de la manche mais ne charge jamais sa scène : l'hôte doit l'exclure après le délai de
##   la barrière (« EXCLU »).
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
## `Reseau`, `Decouverte`, `GameState` et `Scores` par `root.get_node`, ne nomme ni `Reseau`, ni
## `Decouverte`, ni `GameState`, ni le salon (il peut nommer `EtatPartie`, dont le script ne nomme
## aucun autoload, et `ReglesBataille`).

const DELAI_ETAPE := 15.0  # secondes au plus pour chaque attente

var _echecs := 0
var _options := {}
var reseau: Node
var decouverte: Node
var _arrivees: Array[int] = []
var _departs: Array[int] = []
var _poignees_echouees: Array[int] = []  # hôte : pairs dont la poignée de main a échoué, dans l'ordre
var _issue := ""  # client : les signaux reçus, dans l'ordre (voir `_ajouter_issue`)
var _raison := ""
var _version_hote := ""
var _index := -1
var _couleur := Color.TRANSPARENT
var _fiches_manche: Array[Dictionary] = []  # salon : les fiches reçues avec le lancement de la manche
## Salon : la taille de la table à chaque `salon_change` reçu, dans l'ordre. Une table à 4 joueurs
## qui ne dure qu'une image (un départ aussitôt après une arrivée) y reste, là où une attente qui
## relirait la table à chaque image pourrait la manquer.
var _tailles_vues: Array[int] = []
## Salon : la ligne d'état du salon notée après chaque `salon_change`, une fois l'affichage à jour.
var _textes_etat: Array[String] = []


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
	decouverte = root.get_node("Decouverte")
	reseau.pseudo = _option("pseudo", "Poste")
	# Chaque hôte émet sa balise (elle suit l'état de Reseau) : vers un port de test propre au
	# scénario, et vers localhost seulement, sauf --diffusion (jamais le 7778 d'une vraie partie).
	decouverte.port_balise = int(_option("port-balise", str(int(_option("port", "17777")) + 1000)))
	if not _options.has("diffusion"):
		decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	var role := _option("role", "")
	print("== poste réseau : %s (%s) ==" % [role, reseau.pseudo])
	if role == "hote":
		await _jouer_hote()
	elif role == "client":
		await _jouer_client()
	elif role == "lent":
		await _jouer_lent()
	elif role == "ecouteur":
		await _jouer_ecouteur()
	elif role == "salon-hote" or role == "salon-client":
		await _jouer_salon(role == "salon-hote")
	elif role == "manche-hote" or role == "manche-client":
		await _jouer_manche(role == "manche-hote")
	elif role == "manche-muet":
		await _jouer_muet()
	else:
		_check(false, "rôle inconnu : --role=hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client ou manche-muet")
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		and root.multiplayer.is_server() and reseau.inscrits.is_empty() and reseau.index_local == -1
		and not decouverte.ecoute_active(),
		"à la fin, le poste est revenu hors réseau (pair hors ligne, hôte de lui-même, plus d'inscrits ni d'écoute)")
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
	if _options.has("rester"):
		var rester := _option("rester", "")
		print("HOTE RESTE")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
	reseau.quitter()  # close() envoie ses paquets de façon synchrone (N7) : pas de pause à ajouter ici
	if _options.has("apres-depart"):
		# Le processus vit encore : si la balise ne suivait pas l'état de Reseau, elle continuerait.
		await _pause(float(_option("apres-depart", "0")))


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
				# Sans relais du serveur (phase 14, M5), un client ne voit que l'hôte parmi ses pairs :
				# l'autre client est vu dans la table que l'hôte diffuse (hôte et deux clients).
				_check(await _attendre(func() -> bool: return reseau.table_salon.size() >= 3),
					"un autre client est en vue dans la table de l'hôte (%d joueurs)" % reseau.table_salon.size())
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


## Rôle de test « écouteur » (phase 12) : la liste des parties de l'écran Réseau, vue par les
## balises d'un hôte de test (voir l'en-tête).
func _jouer_ecouteur() -> void:
	var erreur: int = decouverte.ecouter()
	if _options.has("occupe"):
		_check(erreur != OK and not decouverte.ecoute_active() and decouverte.erreur_ecoute == erreur,
			"port des balises %d déjà pris par un autre poste : ecouter() renvoie l'erreur (%d), sans planter" % [decouverte.port_balise, erreur])
		print("RESULTAT occupe erreur=%d" % erreur)
		return
	_check(erreur == OK, "l'écoute des balises s'ouvre sur le port %d (erreur %d)" % [decouverte.port_balise, erreur])
	if erreur != OK:
		return
	# Des datagrammes étrangers sur le port des balises (autre programme, balise tronquée ou forgée)
	var brouilleur := PacketPeerUDP.new()
	brouilleur.set_dest_address("127.0.0.1", decouverte.port_balise)
	var trop_long := PackedByteArray()
	trop_long.resize(decouverte.TAILLE_BALISE_MAX + 1)
	for donnees: PackedByteArray in [PackedByteArray([0xFF, 0x00, 0x7C]), "LELION|x".to_utf8_buffer(),
			"AUTRE|0.11|7777|1|6|0|0|x".to_utf8_buffer(), trop_long]:
		brouilleur.put_packet(donnees)
	brouilleur.close()
	await _pause(0.3)
	var hote_seul: bool = decouverte.parties.values().all(func(p: Dictionary) -> bool:
		return p.pseudo == _option("hote", "Hote") and p.port == int(_option("port", "17777")))
	_check(decouverte.ecoute_active() and hote_seul,
		"des datagrammes qui ne sont pas des balises n'ajoutent aucune partie autre que celle de l'hôte (%s)" % [decouverte.parties])
	print("ECOUTE PRETE")

	var hote := _option("hote", "Hote")
	_check(await _attendre(func() -> bool: return not _cle_partie(hote).is_empty()), "la partie de « %s » apparaît dans la liste" % hote)
	var cle := _cle_partie(hote)
	if cle.is_empty():
		decouverte.arreter_ecoute()
		return
	var partie: Dictionary = decouverte.parties[cle]
	print("PARTIE VUE %s" % cle)
	var adresse_attendue: bool = IP.get_local_addresses().has(partie.ip) if _options.has("diffusion") else partie.ip == "127.0.0.1"
	_check(adresse_attendue and partie.port == int(_option("port", "17777")) and partie.version == reseau.version
		and partie.nb_joueurs == 1 and partie.places == int(_option("places", str(EtatPartie.NB_JOUEURS_MAX)))
		and not partie.manche_en_cours and partie.niveau >= 0 and partie.niveau < EtatPartie.NIVEAUX.size(),
		"sa balise donne l'adresse de l'hôte, son port de jeu, sa version, 1 joueur sur %s places, pas de manche (%s)" % [_option("places", "6"), partie])

	var depart := -1
	if _options.has("rejoindre"):
		reseau.inscrit.connect(_sur_inscription)
		reseau.refuse.connect(_sur_refus)
		reseau.connexion_echouee.connect(_ajouter_issue.bind("echec"))
		reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
		_check(reseau.rejoindre(partie.ip, partie.port) == OK, "rejoindre la partie vue, à l'adresse et au port de sa balise")
		_check(await _attendre(func() -> bool: return not _issue.is_empty()) and _issue == "inscrit",
			"l'hôte trouvé dans la liste inscrit ce poste (%s)" % _issue)
		_check(await _attendre(func() -> bool: return decouverte.parties.has(cle) and decouverte.parties[cle].nb_joueurs == 2),
			"la balise suivante de l'hôte compte 2 joueurs")
		print("PARTIE A 2")
		_check(await _attendre(func() -> bool: return _issue != "inscrit"), "l'hôte finit par partir")
		_check(_issue == "inscrit+hote_perdu", "le départ de l'hôte est signalé une fois, comme hôte perdu (%s)" % _issue)
		depart = Time.get_ticks_msec()

	# Un Array, pas un int local : une lambda GDScript capture les variables locales par valeur.
	var derniere_vue := [int(partie.vue_a)]
	var expiree := await _attendre(func() -> bool:
		if decouverte.parties.has(cle):
			derniere_vue[0] = int(decouverte.parties[cle].vue_a)
		return not decouverte.parties.has(cle))
	var apres: float = (Time.get_ticks_msec() - int(derniere_vue[0])) / 1000.0
	print("PARTIE EXPIREE apres=%.2f s" % apres)
	# Marge à 1,0 s (au lieu de 0,5 s) : Godot headless dort ~7 ms par image, sûr sauf si le runner
	# cale plus de 0,5 s entre deux images (constat 4 de la revue finale de la phase 12) ; la
	# frontière exacte reste verrouillée par les tests unitaires (« 3 s pile reste », 3001 ms disparaît).
	_check(expiree and apres >= decouverte.DELAI_EXPIRATION and apres <= decouverte.DELAI_EXPIRATION + 1.0,
		"la partie disparaît de la liste %.0f s après sa dernière balise (%.2f s)" % [decouverte.DELAI_EXPIRATION, apres])
	if depart >= 0:
		var depuis_depart := (Time.get_ticks_msec() - depart) / 1000.0
		var borne: float = decouverte.PERIODE_BALISE + decouverte.DELAI_EXPIRATION + 1.0
		_check(depuis_depart <= borne,
			"et au plus %.0f s après le départ de l'hôte, dont le processus vit encore : sa balise s'arrête avec la session (%.1f s)" % [borne, depuis_depart])
	decouverte.arreter_ecoute()


## Rôles « salon-hote » et « salon-client » (phase 13, voir l'en-tête) : un poste passe par l'écran
## Réseau et le salon comme un joueur, jusqu'à la scène de jeu.
func _jouer_salon(hote: bool) -> void:
	var scores: Node = root.get_node("Scores")
	var gs: Node = root.get_node("GameState")
	scores.chemin = "user://scores_reseau_%s.cfg" % reseau.pseudo  # jamais les préférences du joueur
	scores.effacer()
	reseau.salon_change.connect(func() -> void: _noter_etat.call_deferred())
	reseau.salon_change.connect(func() -> void: _tailles_vues.append(reseau.table_salon.size()))
	reseau.manche_lancee.connect(func(fiches: Array[Dictionary]) -> void: _fiches_manche.assign(fiches))
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	change_scene_to_file("res://Scenes/EcranReseau.tscn")
	_check(await _attendre(func() -> bool: return _scene_est("EcranReseau")), "l'écran Réseau s'ouvre")
	var ecran: Node = current_scene
	ecran.port_jeu = int(_option("port", "17777"))
	ecran.champ_pseudo.text = reseau.pseudo
	if hote:
		ecran.heberger()
	else:
		ecran.champ_ip.text = "127.0.0.1"
		ecran.rejoindre_par_ip()
	_check(await _attendre(func() -> bool: return _scene_est("Salon")), "l'écran Réseau passe la main au salon")
	if not _scene_est("Salon"):
		reseau.quitter()
		return
	var salon: Node = current_scene
	print("SALON OUVERT")
	if hote:
		await _animer_salon_hote(salon, gs)
	else:
		if not await _animer_salon_client(salon):
			scores.effacer()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))
			return
	# La scène de jeu, chargée par le salon sur chaque poste, avec la même table des joueurs
	_check(await _attendre(func() -> bool: return _scene_est("Main")), "le salon charge la scène de jeu")
	var empreinte := ";".join(gs.joueurs.map(func(j: Joueur) -> String: return "%d:%s:%s" % [j.id_reseau, j.pseudo, j.couleur.to_html(false)]))
	var attendues := ";".join(_fiches_manche.map(func(f: Dictionary) -> String: return "%d:%s:%s" % [f.id_reseau, f.pseudo, f.couleur.to_html(false)]))
	var moi: Joueur = gs.joueur_local()
	_check(gs.regles is ReglesBataille and gs.joueurs.size() == _fiches_manche.size() and empreinte == attendues
		and gs.joueurs.map(func(j: Joueur) -> int: return j.index) == range(gs.joueurs.size()),
		"règles de bataille et un joueur par fiche reçue, index 0..n-1, identifiants, pseudos et couleurs de l'hôte (%s)" % empreinte)
	_check(moi.id_reseau == root.multiplayer.get_unique_id() and moi.index == reseau.index_local and moi.couleur == reseau.couleur_locale
		and gs.joueurs[0].id_reseau == 1 and root.content_scale_size == Vector2i(ReglesBataille.TAILLE_ECRAN),
		"le joueur local est celui de ce poste (index %d), l'index 0 celui de l'hôte, écran 16:9" % moi.index)
	if _options.has("index"):
		_check(moi.index == int(_option("index", "")), "index compacté attendu : %s (%d)" % [_option("index", ""), moi.index])
	_check(gs.niveau_courant == int(_option("niveau", str(gs.niveau_courant))), "le niveau choisi au salon (%d)" % gs.niveau_courant)
	print("MANCHE %s|%d" % [empreinte, gs.niveau_courant])
	if hote:
		_check(_textes_etat.has(tr("SALON_ATTENTE_PRETS")) and _textes_etat.has(tr("SALON_PRET_A_DEMARRER")),
			"l'hôte a vu pourquoi le bouton était grisé, puis « tu peux démarrer la partie »")
		_check(reseau.manche_en_cours, "manche lancée : l'hôte refuse désormais tout nouveau venu")
		if _options.has("rester"):
			var rester := _option("rester", "")
			print("HOTE RESTE")
			_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
		reseau.quitter()
	else:
		_check(_textes_etat.has(tr("SALON_ATTENTE_HOTE")), "un client a vu « Tout le monde est prêt : l'hôte peut démarrer. »")
		_check(await _attendre(func() -> bool: return _issue.ends_with("hote_perdu")), "l'hôte finit par partir")
	scores.effacer()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))


func _animer_salon_hote(salon: Node, gs: Node) -> void:
	var niveau := int(_option("niveau", "0"))
	while reseau.niveau_salon != niveau:
		salon.changer_niveau(1)
	_check(gs.niveau_courant == niveau, "le niveau choisi au salon devient celui de la partie (%d), que la balise annonce" % niveau)
	print("HOTE PRET")
	var nb_clients := int(_option("clients", "0"))
	var nb_partants := int(_option("partants", "0"))
	reseau.joueur_arrive.connect(_sur_arrivee)
	reseau.joueur_parti.connect(_sur_depart)
	var complet := func() -> bool:
		return _arrivees.size() >= nb_clients and _departs.size() >= nb_partants and reseau.table_salon.size() == 1 + nb_clients - nb_partants
	_check(await _attendre(complet),
		"%d arrivée(s), %d départ(s) : la table compte %d joueurs" % [_arrivees.size(), _departs.size(), reseau.table_salon.size()])
	print("SALON COMPLET")
	salon.basculer_pret()
	var bouton: Button = salon.bouton_demarrer
	_check(await _attendre(func() -> bool: return not bouton.disabled), "tous prêts : « Démarrer la partie » s'active")
	print("BOUTON ACTIF")
	_check(await _attendre(func() -> bool: return bouton.disabled), "un client repasse non prêt : le bouton se regrise")
	salon.demarrer()
	_check(not reseau.manche_en_cours and _scene_est("Salon"), "démarrer quand même est refusé : la manche ne part pas")
	print("DEMARRAGE REFUSE")
	_check(await _attendre(func() -> bool: return not bouton.disabled), "de nouveau tous prêts : le bouton revient")
	print("BOUTON ACTIF")
	salon.demarrer()


## Renvoie faux si ce poste quitte le salon avant la manche (--partir).
func _animer_salon_client(salon: Node) -> bool:
	if _options.has("voir"):
		var voir := int(_option("voir", ""))
		_check(await _attendre(func() -> bool: return _tailles_vues.has(voir)), "la table du salon a compté %d joueurs (%s)" % [voir, _tailles_vues])
		print("SALON VU %d" % voir)
	if _options.has("partir"):
		salon.retour()
		_check(await _attendre(func() -> bool: return _scene_est("EcranReseau")) and not reseau.en_ligne(),
			"Retour quitte le réseau et ramène à l'écran Réseau")
		if current_scene != null:
			current_scene.free()  # son écoute des balises se ferme avec lui
		return false
	var reste := int(_option("reste", "2"))
	_check(await _attendre(func() -> bool: return reseau.table_salon.size() == reste), "la table compte %d joueurs (%s)" % [reste, _tailles_vues])
	print("SALON VU %d" % reste)
	if _options.has("feu"):
		var avant: Color = reseau.couleur_locale
		print("ATTEND LE FEU")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("feu", ""))), "lancer.sh donne le feu")
		salon.changer_couleur(int(_option("couleur", "1")))
		_check(await _attendre(func() -> bool: return reseau.couleur_locale != avant), "l'hôte change la couleur de ce poste")
		var couleurs: Array = reseau.table_salon.map(func(f: Dictionary) -> Color: return f.couleur)
		_check(couleurs.all(func(c: Color) -> bool: return couleurs.count(c) == 1), "chacun garde une couleur à lui (%s)" % [couleurs])
		print("COULEUR %s" % reseau.couleur_locale.to_html(false))
	salon.basculer_pret()
	if _options.has("annuler"):
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("annuler", ""))), "lancer.sh demande de repasser non prêt")
		salon.basculer_pret()
		_check(await _attendre(func() -> bool: return not _ma_fiche_pret()), "l'hôte enregistre ce poste non prêt")
		print("PLUS PRET")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("relance", ""))), "lancer.sh relance (%s)" % _option("relance", ""))
		salon.basculer_pret()
	return true


func _scene_est(nom: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://Scenes/%s.tscn" % nom and current_scene.is_node_ready()


## Appelé en différé après chaque `salon_change` : le salon a déjà mis sa ligne d'état à jour.
func _noter_etat() -> void:
	if _scene_est("Salon"):
		_textes_etat.append(current_scene.etat.text)


## Vrai si la table du salon dit ce poste prêt.
func _ma_fiche_pret() -> bool:
	for fiche: Dictionary in reseau.table_salon:
		if fiche.id == root.multiplayer.get_unique_id():
			return fiche.pret
	return false


## La clé (« ip:port ») d'une partie de la liste dont l'hôte a ce pseudo, la première dans l'ordre de
## la liste affichée ; une chaîne vide s'il n'y en a pas.
func _cle_partie(pseudo_hote: String) -> String:
	for partie: Dictionary in decouverte.parties_triees():
		if partie.pseudo == pseudo_hote:
			return "%s:%d" % [partie.ip, partie.port]
	return ""


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



## Rôles « manche-hote » et « manche-client » (phase 14, voir l'en-tête) : du salon à une manche
## jouée, jusqu'au départ de l'hôte.
func _jouer_manche(hote: bool) -> void:
	var scores: Node = root.get_node("Scores")
	var gs: Node = root.get_node("GameState")
	scores.chemin = "user://scores_reseau_%s.cfg" % reseau.pseudo
	scores.effacer()
	var script_manche: Script = load("res://Scripts/Manche.gd")
	script_manche.delai_chargement = float(_option("delai-chargement", str(script_manche.DELAI_CHARGEMENT)))
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	reseau.joueur_parti.connect(_sur_depart)
	change_scene_to_file("res://Scenes/EcranReseau.tscn")
	_check(await _attendre(func() -> bool: return _scene_est("EcranReseau")), "l'écran Réseau s'ouvre")
	var ecran: Node = current_scene
	ecran.port_jeu = int(_option("port", "17777"))
	ecran.champ_pseudo.text = reseau.pseudo
	if hote:
		ecran.heberger()
	else:
		ecran.champ_ip.text = "127.0.0.1"
		ecran.rejoindre_par_ip()
	_check(await _attendre(func() -> bool: return _scene_est("Salon")), "l'écran Réseau passe la main au salon")
	if not _scene_est("Salon"):
		reseau.quitter()
		return
	var salon: Node = current_scene
	if hote:
		print("HOTE PRET")
		var nb := 1 + int(_option("clients", "0"))
		_check(await _attendre(func() -> bool: return reseau.table_salon.size() == nb), "%d joueurs au salon" % nb)
		salon.basculer_pret()
		var bouton: Button = salon.bouton_demarrer
		_check(await _attendre(func() -> bool: return not bouton.disabled), "tous prêts : « Démarrer la partie » s'active")
		salon.demarrer()
	else:
		salon.basculer_pret()
	_check(await _attendre(func() -> bool: return _scene_est("Main")), "le salon charge la scène de jeu")
	if not _scene_est("Main"):
		reseau.quitter()
		return
	var main: Node = current_scene
	var manche: Node = main.get_node("Manche")
	if hote and _options.has("gel"):
		# Tout le processus se fige, comme un hôte qui charge ou compile ses shaders : ses clients
		# chargent pendant ce temps, et leurs « scène chargée » l'attendent.
		print("GEL")
		OS.delay_msec(int(float(_option("gel", "0")) * 1000.0))
	_check(await _attendre(func() -> bool: return manche.barriere), "la barrière de chargement passe")
	_check(_issue.is_empty(), "personne ne s'est cru abandonné pendant le chargement (%s)" % _issue)
	if hote:
		var exclus: Array = manche._exclus
		print("BARRIERE prets=%s exclus=%s" % [manche._prets, exclus])
		_check(manche._prets.size() == int(_option("clients", "0")) - 1 and exclus.size() == 1,
			"les clients chargés sont prêts, le muet est exclu (%s, %s)" % [manche._prets, exclus])
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size() - 1), "un lion par joueur resté (%d)" % main.lions.size())
	var moi: Joueur = gs.joueur_local()
	_check(main.lion != null and main.lion.joueur == moi and main.lion.commandes.source == Commandes.Source.LOCALES
		and main.lions.all(func(l: Node) -> bool: return l == main.lion or l.commandes.source == Commandes.Source.MANUELLES),
		"le lion de ce poste lit ses commandes, les autres ont des commandes manuelles")
	if not hote:
		_check(root.multiplayer.get_peers() == PackedInt32Array([1]) and not root.multiplayer.is_server(),
			"sans relais du serveur, un client ne voit que l'hôte parmi ses pairs (%s)" % [root.multiplayer.get_peers()])
	_check(await _attendre(func() -> bool: return gs.pret), "l'intro se termine chez tous")
	print("INTRO")
	await _jouer_passe(main, int(_option("sens", "1")))
	if hote:
		await _finir_manche_hote(main, manche, gs)
	elif _options.has("partir"):
		main.get_node("PauseMenu").ouvrir()
		await _pause(0.3)
		_check(main.lion.commandes.suspendues and not paused, "le menu local suspend les commandes sans mettre la partie en pause")
		main.get_node("PauseMenu")._on_menu_pressed()  # « Quitter la partie »
		_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not reseau.en_ligne(), "quitter la partie ramène au titre, hors réseau")
		print("PARTI")
	else:
		await _finir_manche_client(main, manche)
	scores.effacer()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))


## La passe de ce poste : descendre jusqu'à la hauteur de peinture (celle du pilote de la démo, 233 px
## au-dessus des toits ; la position du lion de ce poste est celle que l'hôte lui renvoie), puis
## peindre la ville en allant dans le sens `sens`.
func _jouer_passe(main: Node, sens: int) -> void:
	var ville: Node2D = main.get_node("Ville")
	var cible: float = ville.position.y - ville.tex_size.y / 2.0 - 233.0
	Input.action_press("deplacer_bas")
	_check(await _attendre(func() -> bool: return main.lion.position.y >= cible), "le lion de ce poste descend vers la ville (%.0f)" % main.lion.position.y)
	Input.action_release("deplacer_bas")
	var action := "deplacer_droite" if sens > 0 else "deplacer_gauche"
	Input.action_press(action)
	Input.action_press("vomir")
	var pire := 0.0
	var fin := Time.get_ticks_msec() + 2500
	var avant := Time.get_ticks_msec()
	while Time.get_ticks_msec() < fin:
		await process_frame
		pire = maxf(pire, Time.get_ticks_msec() - avant)
		avant = Time.get_ticks_msec()
	Input.action_release(action)
	Input.action_release("vomir")
	print("MESURE %s : %d jeux de tampons en cache, frame la plus longue %.0f ms pendant la passe" % [reseau.pseudo, main.get_node("Ville")._tampons.size(), pire])


## L'empreinte de la manche sur ce poste : territoire (propriétaire compté de chaque cellule), scores,
## tampons (nombre diffusé par l'hôte ou reçu par un client, et l'empreinte de leur suite), lions
## (position, orientation, crans, étourdi, gerbe XXL), apparitions (ennemis et pastilles : nom et position). Pas l'image
## de la ville : les mêmes tampons y sont dessinés à l'identique (smoke test), mais une coulure qui
## descend encore quand un tampon la recouvre passe dessus ou dessous selon le rythme de chaque poste.
func _empreinte(main: Node, manche: Node, hote: bool) -> String:
	var ville: Node2D = main.get_node("Ville")
	var territoire: Territoire = ville.territoire
	var proprietaires := PackedByteArray()
	proprietaires.resize(territoire.taille_grille.x * territoire.taille_grille.y)
	for i in range(proprietaires.size()):
		proprietaires[i] = territoire.proprietaire_compte(i) + 1
	var lions: Array = main.lions.map(func(l: Node) -> String:
		return "%s:%.1f,%.1f,%d,%d,%s,%s" % [l.name, l.position.x, l.position.y, l.direction_du_lion, l.joueur.crans,
			l.joueur.est_etourdi(), l.joueur.bonus_actif()])
	var scenes: Array[String] = []
	var spawner: MultiplayerSpawner = main.get_node("Apparitions")
	for i in range(spawner.get_spawnable_scene_count()):
		scenes.append(spawner.get_spawnable_scene(i))
	var apparitions: Array[String] = []
	for enfant in main.get_children():
		if scenes.has(enfant.scene_file_path):
			apparitions.append("%s@%.0f,%.0f" % [enfant.name, enfant.position.x, enfant.position.y])
	apparitions.sort()
	return "territoire=%d scores=%s tampons=%d:%d lions=%s apparitions=%s" % [hash(proprietaires), territoire.scores(),
		manche.tampons_diffuses if hote else manche.tampons_recus, manche.empreinte_tampons, ";".join(lions), ";".join(apparitions)]


func _finir_manche_hote(main: Node, manche: Node, gs: Node) -> void:
	var ville: Node2D = main.get_node("Ville")
	_check(await _attendre(func() -> bool: return _departs.size() >= 2), "le client parti en pleine manche (et le muet exclu) sont partis (%d)" % _departs.size())
	var index_parti := -1
	for j: Joueur in gs.joueurs:
		if j.id_reseau == _departs[-1]:
			index_parti = j.index
	var cellules_parti: int = ville.territoire.cellules_de(index_parti)
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size() - 2) and cellules_parti > 0,
		"son lion disparaît, ses cellules restent au territoire (%d)" % cellules_parti)
	print("DEPART VU")
	# Les réactions d'Anna, décidées ici : un cran, la gerbe XXL, un étourdissement (elle les reçoit
	# par la manche ; son empreinte doit les montrer)
	var restants: Array = gs.joueurs.filter(func(j: Joueur) -> bool: return j.id_reseau != 1 and reseau.inscrits.has(j.id_reseau))
	_check(restants.size() == 1, "(pré-condition) il reste un client, Anna")
	if restants.size() == 1:
		var anna: Joueur = restants[0]
		var crans_avant := anna.crans  # une pastille a pu être ramassée pendant sa passe
		gs.regles.pastille_ramassee(anna, 0)
		gs.regles.etoile_ramassee(anna)
		anna.invulnerable_restant = 0.0
		gs.regles.lion_touche_par_ennemi(anna, Vector2.INF)
		_check(anna.crans == mini(crans_avant + 1, Joueur.CRANS_MAX) and anna.bonus_actif() and anna.est_etourdi(),
			"Anna gagne un cran et la gerbe XXL, puis un ennemi l'étourdit")
	var calme := func() -> bool:
		return main.lions.all(func(l: Node) -> bool: return l.velocity == Vector2.ZERO) and ville.coulures.is_empty()
	_check(await _attendre(calme), "les lions s'arrêtent, les coulures finissent")
	await _pause(0.3)
	gs.terminer_partie(false)  # tout se fige chez l'hôte (bataille) ; la manche diffuse encore
	await _pause(1.0)
	_check(ville.territoire.cellules_de(index_parti) == cellules_parti, "les cellules du parti restent jusqu'au bout")
	print("EMPREINTE %s" % _empreinte(main, manche, true))
	print("FIGE")
	if _options.has("rester"):
		var rester := _option("rester", "")
		print("HOTE RESTE")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
	paused = false
	reseau.quitter()


func _finir_manche_client(main: Node, manche: Node) -> void:
	var ville: Node2D = main.get_node("Ville")
	_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("fige", ""))), "l'hôte a figé la manche")
	_check(await _attendre(func() -> bool: return ville.coulures.is_empty()), "les coulures de ce poste finissent")
	await _pause(0.5)  # les dernières positions et cellules de l'hôte figé
	print("EMPREINTE %s" % _empreinte(main, manche, false))
	_check(await _attendre(func() -> bool: return _issue == "hote_perdu"), "l'hôte finit par partir")
	var message: Node = main.get_node_or_null("HotePerdu/Message")
	_check(message != null and message.text == "RESEAU_HOTE_PERDU" and paused, "« L'hôte a quitté la partie » s'affiche, la partie se fige")
	_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not paused and not reseau.en_ligne(),
		"puis retour au titre, hors réseau")


## Rôle « manche-muet » (phase 14) : un joueur prêt qui ne charge jamais sa scène de jeu.
func _jouer_muet() -> void:
	reseau.inscrit.connect(_sur_inscription)
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	var lancee := [0]
	reseau.manche_lancee.connect(func(_f: Array[Dictionary]) -> void: lancee[0] = Time.get_ticks_msec())
	_check(reseau.rejoindre("127.0.0.1", int(_option("port", "17777"))) == OK, "le client muet est créé")
	_check(await _attendre(func() -> bool: return _issue == "inscrit"), "le muet est inscrit")
	_check(await _attendre(func() -> bool: return reseau.table_salon.any(func(f: Dictionary) -> bool: return f.id == root.multiplayer.get_unique_id())),
		"le muet est à la table du salon")
	reseau.demander_pret(true)
	_check(await _attendre(func() -> bool: return lancee[0] > 0), "le muet reçoit le lancement de la manche, sans charger de scène")
	var fin := Time.get_ticks_msec() + int((DELAI_ETAPE + float(_option("gel", "0"))) * 1000.0)
	while _issue != "inscrit+hote_perdu" and Time.get_ticks_msec() < fin:
		await process_frame
	var apres: float = (Time.get_ticks_msec() - lancee[0]) / 1000.0
	print("EXCLU apres=%.1f s" % apres)
	_check(_issue == "inscrit+hote_perdu" and apres >= float(_option("delai-chargement", "0")),
		"l'hôte l'exclut après le délai de la barrière (%.1f s)" % apres)
