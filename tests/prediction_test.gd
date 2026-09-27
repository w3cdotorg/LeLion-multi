extends SceneTree
## Banc de la prédiction du lion local (phase 16, spec §4.1 et §10), dans un seul processus :
##   godot --headless --fixed-fps 60 --script tests/prediction_test.gd
## Deux postes côte à côte, chacun dans son propre monde (une `SubViewport` de 2000×1125, dont la
## physique ne voit pas l'autre) : l'hôte (H0, le lion de son joueur ; H1, celui du client, qui applique
## les commandes reçues) et le client (C0, réplique interpolée de H0 ; C1, son lion, prédit, joué au
## clavier comme un joueur). Entre eux, des lignes à retard semées (`Ligne`), au tick près et
## reproductibles : les états de chaque lion de l'hôte (non fiables), les paquets de commandes du
## client (non fiables et ordonnés : un paquet plus ancien que le dernier livré est jeté, comme
## `unreliable_ordered`), les réactions de l'hôte (fiables : retardées, renvoyées après une perte,
## jamais perdues ni mélangées). Latence (aller-retour), gigue (étendue de chaque aller) et pertes :
## celles du simulateur du test réseau (`tests/reseau/relais.gd`).
## Mesure l'erreur de prédiction (la position de l'hôte après chaque commande accusée, comparée à
## celle que le client avait prédite pour elle), les recalages, les à-coups de l'affichage, la
## convergence après l'arrêt des commandes, la régularité d'un lion distant ; vérifie qu'aucune
## commande n'est appliquée deux fois. Chaque scénario écrit sa ligne « MESURE ».
## Compilé avant les autoloads : ne nomme ni `GameState`, ni `Lion`, ni `PredictionLocale`.

const TICK_MS := 1000.0 / 60.0
const PAS := 350.0 / 60.0  # px par tick à pleine vitesse
## Spec §4.1 et §10 : sans pertes, le lion prédit reste à moins de 4 px de l'hôte ; sous 80 ms, 40 ms
## et 5 %, l'écart converge sous 4 px en 150 ms (9 ticks) après l'arrêt des commandes.
const ECART_MAX := 4.0
const TICKS_CONVERGENCE := 9
## Au-delà, un saut de l'affichage d'un tick à l'autre (pleine vitesse, et moitié en plus) est un à-coup.
const A_COUP := PAS * 1.5
## Le programme du joueur du client : `[ticks, direction]`, joué au clavier ; il passe par un bord
## (en haut, sous son pseudo).
const PROGRAMME: Array = [[30, Vector2.ZERO], [90, Vector2.RIGHT], [40, Vector2(1, 1)], [60, Vector2.LEFT],
	[20, Vector2.ZERO], [120, Vector2.UP], [45, Vector2(1, -1)], [90, Vector2(-1, 1)], [60, Vector2.DOWN]]

var _echecs := 0
var GS: Node
var _t := 0.0  # ms, temps du banc
var _tick := 0
var _vue_hote: SubViewport
var _vue_client: SubViewport
var _pair: ENetMultiplayerPeer
var h0: CharacterBody2D
var h1: CharacterBody2D
var c0: CharacterBody2D
var c1: CharacterBody2D
var _joueurs_client: Array[Joueur] = []
var _etats: Array[Ligne] = []
var _commandes: Ligne
var _reactions: Ligne
## Mesures du scénario en cours : sauts de l'affichage de C1, pas de C0 pendant la course de H0.
var _a_coups := 0
var _pas_c0: Array[float] = []
var _affiche_avant := Vector2.INF
var _c0_avant := Vector2.INF


## Une ligne à retard entre les deux postes : chaque message part avec un retard d'une demi-latence,
## plus ou moins une demi-gigue (tirée au hasard, semée : l'ordre d'arrivée peut changer), et se perd
## avec la probabilité `pertes` (%). Fiable : jamais perdu (une perte coûte un aller-retour de plus,
## le renvoi) et jamais doublé par un message plus récent. Ordonnée : un message qui arrive après un
## plus récent est jeté.
class Ligne:
	var rng := RandomNumberGenerator.new()
	var latence := 0.0
	var gigue := 0.0
	var pertes := 0.0
	var fiable := false
	var ordonnee := false
	var envoyes := 0
	var perdus := 0
	var _en_route: Array = []  # [arrivée (ms), numéro d'envoi, message]
	var _dernier_livre := 0
	var _derniere_arrivee := 0.0

	func _init(graine: int, latence_ms: float, gigue_ms: float, pertes_pc: float, est_fiable: bool, est_ordonnee: bool) -> void:
		rng.seed = graine
		latence = latence_ms
		gigue = gigue_ms
		pertes = pertes_pc
		fiable = est_fiable
		ordonnee = est_ordonnee

	func envoyer(message: Variant, maintenant: float) -> void:
		envoyes += 1
		var retard := latence / 2.0 + rng.randf_range(-gigue / 2.0, gigue / 2.0)
		if rng.randf() * 100.0 < pertes:
			perdus += 1
			if not fiable:
				return
			retard += latence  # le renvoi
		var arrivee := maintenant + retard
		if fiable:
			arrivee = maxf(arrivee, _derniere_arrivee)
			_derniere_arrivee = arrivee
		_en_route.append([arrivee, envoyes, message])

	func recevoir(maintenant: float) -> Array:
		var arrives := _en_route.filter(func(m: Array) -> bool: return m[0] <= maintenant)
		_en_route = _en_route.filter(func(m: Array) -> bool: return m[0] > maintenant)
		arrives.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		var livres: Array = []
		for m: Array in arrives:
			if ordonnee and m[1] < _dernier_livre:
				continue
			_dernier_livre = maxi(_dernier_livre, m[1])
			livres.append(m[2])
		return livres


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _run() -> void:
	print("== banc de la prédiction LeLion ==")
	GS = root.get_node("GameState")
	await _scenario_parcours("lien parfait", 0.0, 0.0, 0.0)
	await _scenario_parcours("80 ms, 40 ms de gigue, 5 % de pertes", 80.0, 40.0, 5.0)
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


# --- Les deux postes ---------------------------------------------------------------------------------


## Les deux postes d'une partie à 2 : H0 et C0 partent de `depart0`, H1 et C1 de `depart1` ; les lignes
## à retard sous `latence` (ms, aller-retour), `gigue` (ms) et `pertes` (%), semées par `graine`.
func _preparer(depart0: Vector2, depart1: Vector2, latence: float, gigue: float, pertes: float, graine: int) -> void:
	GS.configurer_bataille(2)
	for i in range(2):
		GS.joueurs[i].pseudo = "Joueur %d" % (i + 1)
	GS.nouvelle_partie()
	GS.pret = true
	_t = 0.0
	_tick = 0
	_vue_hote = _vue("Hote")
	_vue_client = _vue("Client")
	# Le client : son propre pair (jamais connecté), comme la réplique du smoke test ; ses nœuds ne
	# sont pas l'hôte (`multiplayer.is_server()` faux).
	var api := SceneMultiplayer.new()
	_pair = ENetMultiplayerPeer.new()
	_check(_pair.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client pour le poste client")
	api.multiplayer_peer = _pair
	set_multiplayer(api, _vue_client.get_path())
	_joueurs_client.clear()
	for j: Joueur in GS.joueurs:
		var copie := Joueur.new()
		copie.index = j.index
		copie.pseudo = j.pseudo
		copie.couleur = j.couleur
		copie.reinitialiser(j.vies, j.couleurs_debloquees.duplicate())
		_joueurs_client.append(copie)
	h0 = _lion(_vue_hote, GS.joueurs[0], depart0, false)
	h1 = _lion(_vue_hote, GS.joueurs[1], depart1, false)
	c0 = _lion(_vue_client, _joueurs_client[0], depart0, false)
	c1 = _lion(_vue_client, _joueurs_client[1], depart1, true)
	_check(c1 != null and c1.get_node_or_null("Prediction") != null, "(pré-condition) le lion du client est prédit (PredictionLocale)")
	_etats = [Ligne.new(graine, latence, gigue, pertes, false, false), Ligne.new(graine + 1, latence, gigue, pertes, false, false)]
	_commandes = Ligne.new(graine + 2, latence, gigue, pertes, false, true)
	_reactions = Ligne.new(graine + 3, latence, gigue, pertes, true, false)
	for j: Joueur in GS.joueurs:
		j.etourdi.connect(func(origine: Vector2, barbouillage: Color) -> void:
			_reactions.envoyer(["etourdi", j.index, j.etourdi_restant, j.invulnerable_restant - j.etourdi_restant, origine, barbouillage], _t))
		j.etourdissement_fini.connect(func() -> void: _reactions.envoyer(["fin", j.index, j.invulnerable_restant], _t))
	_a_coups = 0
	_pas_c0.clear()
	_affiche_avant = Vector2.INF
	_c0_avant = Vector2.INF
	_relacher()


func _vue(nom: String) -> SubViewport:
	var vue := SubViewport.new()
	vue.name = "Poste" + nom
	vue.size = Vector2i(2000, 1125)
	vue.disable_3d = true
	root.add_child(vue)
	return vue


func _lion(vue: SubViewport, j: Joueur, depart: Vector2, predit: bool) -> CharacterBody2D:
	var l: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
	l.joueur = j
	l.commandes = Commandes.manuelles()
	l.position = depart
	if predit:
		l.prediction = load("res://Scripts/PredictionLocale.gd").new()
	vue.add_child(l)
	return l


func _liberer() -> void:
	_relacher()
	for j: Joueur in GS.joueurs:
		for s: Signal in [j.etourdi, j.etourdissement_fini]:
			for c: Dictionary in s.get_connections():
				if (c.callable as Callable).get_object() == self:
					s.disconnect(c.callable)
	set_multiplayer(null, _vue_client.get_path())
	_pair.close()
	_vue_hote.free()
	_vue_client.free()
	await physics_frame


## Un tick du banc, au début de l'image physique (avant la prédiction, à -10, et les lions) : chaque
## ligne livre ce qui arrive, puis part ce que chaque poste a produit au tick précédent (les états
## écrits par les lions de l'hôte, le paquet de la prédiction), comme le sondage réseau entre deux
## images physiques. Puis l'image physique suit.
func _pas() -> void:
	await physics_frame
	_tick += 1
	_t = _tick * TICK_MS
	for k in range(2):
		for octets: PackedByteArray in _etats[k].recevoir(_t):
			(c0 if k == 0 else c1).etat_reseau = octets
	for octets: PackedByteArray in _commandes.recevoir(_t):
		for c: Dictionary in Commandes.decoder_paquet(octets):
			h1.commandes.recevoir(c.numero, c.direction, c.vomir)
	for r: Array in _reactions.recevoir(_t):
		var j: Joueur = _joueurs_client[r[1]]
		if r[0] == "etourdi":
			j.etourdir(r[2], r[3], r[4], r[5])
		else:
			j.recevoir_fin_etourdissement(r[2])
	_etats[0].envoyer(h0.etat_reseau, _t)
	_etats[1].envoyer(h1.etat_reseau, _t)
	var paquet: PackedByteArray = c1.prediction.paquet()
	if not paquet.is_empty():
		_commandes.envoyer(paquet, _t)
	# Mesures : sauts de l'affichage du lion prédit, pas du lion distant
	if _affiche_avant.is_finite() and c1.position.distance_to(_affiche_avant) > A_COUP + c1.deplacement.recul.length() / 60.0:
		_a_coups += 1
	_affiche_avant = c1.position
	if _c0_avant.is_finite():
		_pas_c0.append(c0.position.x - _c0_avant.x)
	_c0_avant = c0.position


func _presser(direction: Vector2) -> void:
	_basculer("deplacer_droite", direction.x > 0.0)
	_basculer("deplacer_gauche", direction.x < 0.0)
	_basculer("deplacer_bas", direction.y > 0.0)
	_basculer("deplacer_haut", direction.y < 0.0)


func _relacher() -> void:
	for action in ["deplacer_gauche", "deplacer_droite", "deplacer_haut", "deplacer_bas", "vomir"]:
		Input.action_release(action)


static func _basculer(action: String, appuyee: bool) -> void:
	if appuyee:
		Input.action_press(action)
	else:
		Input.action_release(action)


## Le numéro de la première commande lue après cet appel.
func _prochain_numero() -> int:
	return c1.prediction.numero + 1


## Attend `ticks` ticks au repos, puis vérifie la convergence (spec §10) : les états qui accusent une
## commande lue au moins TICKS_CONVERGENCE ticks après `arret` (la première commande au repos) ont
## une erreur sous ECART_MAX, et le lion affiché est là où l'hôte a posé le sien.
func _verifier_convergence(titre: String, arret: int, ticks: int) -> void:
	for i in range(ticks):
		await _pas()
	var apres: float = c1.prediction.erreur_max(arret + TICKS_CONVERGENCE)
	_check(c1.prediction.etats_depuis(arret + TICKS_CONVERGENCE) > 0 and apres >= 0.0 and apres < ECART_MAX,
		"(%s) 150 ms après l'arrêt des commandes, l'erreur de prédiction reste sous %.0f px (au plus %.2f px)" % [titre, ECART_MAX, apres])
	_check(c1.position.distance_to(h1.position) < ECART_MAX and c1.prediction.decalage() == Vector2.ZERO,
		"(%s) au repos, le lion affiché du client est sur celui de l'hôte (%.2f px), sans décalage résiduel" % [titre, c1.position.distance_to(h1.position)])


## Aucune commande appliquée deux fois par l'hôte : chaque numéro jusqu'à la dernière appliquée l'est
## une fois ou est sauté, et les sautées restent rares (redondance).
func _verifier_commandes(titre: String, sautees_max: int) -> void:
	var c: Commandes = h1.commandes
	_check(c.appliquees + c.sautees == c.numero_applique and c.sautees <= sautees_max and c.numero_applique > 0,
		"(%s) aucune commande appliquée deux fois : %d appliquées, %d sautées, jusqu'à la %d (file au plus %d)"
		% [titre, c.appliquees, c.sautees, c.numero_applique, c.file_max_vue])


# --- Scénarios ---------------------------------------------------------------------------------------


## Le programme du joueur du client, pendant que le lion de l'hôte file à pleine vitesse (le lion
## distant du client doit en montrer une course régulière), puis le repos.
func _scenario_parcours(titre: String, latence: float, gigue: float, pertes: float) -> void:
	print("-- Parcours : %s" % titre)
	_preparer(Vector2(300, 150), Vector2(900, 500), latence, gigue, pertes, 1600)
	var vomi_avant_hote := -1
	for segment: Array in PROGRAMME:
		_presser(segment[1])
		for i in range(segment[0]):
			h0.commandes.direction_voulue = Vector2.RIGHT if _tick >= 60 and _tick < 300 else Vector2.ZERO
			if _tick == 200:
				Input.action_press("vomir")
			await _pas()
			if _tick == 202:
				vomi_avant_hote = 1 if c1.est_en_train_de_vomir and (latence == 0.0 or not h1.est_en_train_de_vomir) else 0
			if _tick == 260:
				Input.action_release("vomir")
	_relacher()
	var arret := _prochain_numero()
	var p: Node = c1.prediction
	var etats: int = p.etats_depuis(1)
	var pas_c0 := _pas_c0.slice(110, 290)
	var pas_min: float = pas_c0.min()
	var pas_max: float = pas_c0.max()
	print("MESURE parcours (%s) : erreur max %.2f px, %d états sur %d au-delà de %.0f px, %d au-delà de 16 px ; recalages %d ; à-coups %d ; rejeu le plus long %d pas ; lion distant : %.2f à %.2f px par tick (%.2f) ; commandes sautées %d, file au plus %d"
		% [titre, p.erreur_max(), p.erreurs_au_dela(ECART_MAX), etats, ECART_MAX, p.erreurs_au_dela(16.0), p.recalages, _a_coups, p.rejeu_max,
			pas_min, pas_max, PAS, h1.commandes.sautees, h1.commandes.file_max_vue])
	if latence == 0.0:
		_check(p.erreur_max() < ECART_MAX and etats > 500,
			"(%s) sans latence ni pertes, le lion prédit reste à moins de %.0f px de l'hôte (au plus %.2f px sur %d états)" % [titre, ECART_MAX, p.erreur_max(), etats])
	else:
		_check(p.erreurs_au_dela(16.0) <= etats / 50 and p.erreur_max() < 30.0,
			"(%s) pendant la course, l'erreur de prédiction reste petite (au plus %.2f px ; %d états sur %d au-delà de 16 px)" % [titre, p.erreur_max(), p.erreurs_au_dela(16.0), etats])
	_check(p.recalages == 0 and _a_coups <= 3, "(%s) ni recalage ni à-coup visible (%d recalages, %d à-coups)" % [titre, p.recalages, _a_coups])
	_check(vomi_avant_hote == 1, "(%s) la gerbe du lion local part dès l'appui, sans attendre l'hôte" % titre)
	_check(pas_min > 0.7 * PAS and pas_max < 1.3 * PAS,
		"(%s) le lion distant (interpolé) court d'un pas régulier, sans recul ni saut (%.2f à %.2f px par tick, pour %.2f)" % [titre, pas_min, pas_max, PAS])
	await _verifier_convergence(titre, arret, 90)
	_verifier_commandes(titre, h1.commandes.numero_applique / 100)
	await _liberer()
