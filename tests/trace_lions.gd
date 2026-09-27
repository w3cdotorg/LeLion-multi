extends SceneTree
## Trace des lions, l'outil de non-régression des refontes du lion (phase 15 bis) :
##   godot --headless --fixed-fps 60 --script tests/trace_lions.gd
## Rejoue dans un seul processus, tick par tick, trois parties scriptées et reproductibles (hasard
## global semé, `--fixed-fps 60`) qui passent par tout le code du lion : une bataille locale à 4 lions
## sur le Village (couloirs de peinture, pastilles, étoile, soucoupe, gerbes croisées, chocs, poussée
## continue, bords de l'écran, peintre), une partie solo (couleurs débloquées, coups, clignotement,
## étoile) et la réplique d'un lion sur un client (état et réactions reçus de l'hôte). À chaque tick,
## l'état observable de chaque lion (corps, sprite, étoiles, gerbe, traceuse, zones de contact,
## matériau, étiquette, joueur) et le territoire entrent dans une empreinte ; chaque partie écrit
## « TRACE <partie> <empreinte> ». Deux passages du même code donnent les mêmes empreintes ; une
## refonte qui ne change rien au comportement aussi. N'y entre pas le décalage de la secousse
## (`sprite.offset`, tiré par le générateur propre à chaque lion, semé au hasard).
## Lit le lion par les nœuds de sa scène (noms stables) et ses champs publics, jamais par ses champs
## privés : le même script sert avant et après une refonte. Les vérifications (« ✅ ») disent
## seulement que chaque partie est bien passée par ce qu'elle doit couvrir.
## `-- --etats=<fichier>` écrit aussi l'état de chaque tick, une ligne par tick (`var_to_str`) : deux
## fichiers qui diffèrent se comparent ligne à ligne pour trouver le premier tick qui change.
## Compilé avant les autoloads : ne nomme ni `GameState`, ni `Lion`, ni la ville, ni les ennemis.

const NB_LIONS := 4
const TICKS_BATAILLE := 5400  # la manche entière (90 s), après l'intro
const TICKS_SOLO := 1800
const TICKS_REPLIQUE := 240
const HAUTEURS_JET: Array[float] = [-233.0, -200.0, -270.0]  # y du lion sous le haut de la skyline

var _echecs := 0
var GS: Node
var _empreinte := 0
## Réactions vues pendant la partie en cours (signaux des joueurs), pour les vérifications.
var _vus := {}
var _fichier_etats := ""
var _etats: PackedStringArray = []


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--etats="):
			_fichier_etats = arg.trim_prefix("--etats=")
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _run() -> void:
	print("== trace des lions LeLion ==")
	GS = root.get_node("GameState")
	var scores: Node = root.get_node("Scores")
	scores.chemin = "user://scores_trace.cfg"  # la fin du solo enregistre un temps : jamais les scores du joueur
	scores.effacer()
	await _tracer_bataille()
	await _tracer_solo()
	await _tracer_replique()
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false
	scores.effacer()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))
	if not _fichier_etats.is_empty():
		FileAccess.open(_fichier_etats, FileAccess.WRITE).store_string("\n".join(_etats))
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


## L'état observable d'un lion à ce tick, par les nœuds de sa scène.
func _etat(l: Node) -> Array:
	var sprite: Sprite2D = l.get_node("Visuel/Sprite2D")
	var etoiles: Node2D = l.get_node("Visuel/Etoiles")
	var traceuse: Area2D = l.get_node("GerbeTraceuse")
	var conteneur: Node2D = l.get_node("Visuel/VomiParticlesContainer")
	var etiquette: Label = l.get_node("Visuel/Pseudo")
	var j: Joueur = l.joueur
	var etat: Array = [l.position, l.velocity, l.direction_du_lion, l.est_en_train_de_vomir, l.vomi_de_l_hote,
		sprite.position, sprite.rotation, sprite.scale, sprite.modulate, sprite.texture.resource_path,
		etoiles.visible, etoiles.get_child(0).position, traceuse.position, traceuse.monitoring,
		(traceuse.get_node("CollisionShape2D").shape as CircleShape2D).radius, conteneur.position,
		(l.get_node("Bouche") as Node2D).position, etiquette.visible, etiquette.text,
		j.crans, j.vies, j.etourdi_restant, j.invulnerable_restant, j.bonus_restant, j.chocs,
		j.etourdissements_infliges, j.cellules_volees, j.couleurs_debloquees.size()]
	for e: GPUParticles2D in conteneur.get_children():
		var m := e.process_material as ParticleProcessMaterial
		etat.append_array([e.emitting, e.amount, m.direction, m.scale_min, m.scale_max, m.color_ramp.gradient.get_color(0)])
	for n in range(1, 4):
		var z: Area2D = l.find_child("ZoneContact%d" % n, true, false)  # créées par le code : sans propriétaire
		etat.append_array([z.position, z.monitoring, (z.get_child(0).shape as CircleShape2D).radius])
	var mat := sprite.material as ShaderMaterial
	if mat != null:
		etat.append_array([mat.get_shader_parameter("couleur_joueur"), mat.get_shader_parameter("barbouillage_couleur"),
			mat.get_shader_parameter("barbouillage_force")])
	return etat


func _tracer_tick(lions: Array, ville: Node2D) -> void:
	var etats: Array = lions.map(func(l: Node) -> Array: return _etat(l))
	if ville != null and ville.territoire != null:
		etats.append(ville.territoire.scores())
	_empreinte = hash([_empreinte, var_to_bytes(etats)])
	if not _fichier_etats.is_empty():
		_etats.append(var_to_str(etats).replace("\n", " "))


## Compte les réactions des joueurs de la partie (étourdissements par un ennemi ou par une gerbe,
## coups, crans, gerbes XXL, couleurs) pour les vérifications de couverture.
func _suivre(joueurs: Array) -> void:
	_vus = {"ennemi": 0, "gerbe": 0, "touche": 0, "cran": 0, "xxl": 0, "couleur": 0}
	for j: Joueur in joueurs:
		j.etourdi.connect(func(_o: Vector2, barbouillage: Color) -> void: _vus["gerbe" if barbouillage.a > 0.0 else "ennemi"] += 1)
		j.touche.connect(func(_o: Vector2) -> void: _vus.touche += 1)
		j.crans_changes.connect(func(_c: int) -> void: _vus.cran += 1)
		j.bonus_change.connect(func(actif: bool) -> void:
			if actif:
				_vus.xxl += 1)
		j.couleur_debloquee.connect(func(_c: Color) -> void: _vus.couleur += 1)


func _oublier(joueurs: Array) -> void:
	for j: Joueur in joueurs:
		for s: Signal in [j.etourdi, j.touche, j.crans_changes, j.bonus_change, j.couleur_debloquee]:
			for c: Dictionary in s.get_connections():
				if (c.callable as Callable).get_object() == self:
					s.disconnect(c.callable)


func _charger_main() -> Node:
	var main: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	return main


func _liberer(main: Node) -> void:
	paused = false
	main.free()
	await physics_frame


## Couloirs de peinture, comme la manche de `tests/bataille_test.gd` : chaque lion balaie le sien en
## vomissant et change de hauteur à chaque demi-tour ; les couloirs voisins se chevauchent.
func _piloter(lion: Node2D, couloir: Dictionary, haut: float) -> void:
	var centre: Vector2 = lion.global_position + lion.CENTRE
	if centre.x >= couloir.max:
		couloir.sens = -1.0
		couloir.rangee = (couloir.rangee + 1) % HAUTEURS_JET.size()
	elif centre.x <= couloir.min:
		couloir.sens = 1.0
		couloir.rangee = (couloir.rangee + 1) % HAUTEURS_JET.size()
	var ecart_y: float = haut + HAUTEURS_JET[couloir.rangee] - lion.global_position.y
	lion.commandes.direction_voulue = Vector2(couloir.sens, clampf(ecart_y / 60.0, -1.0, 1.0)).normalized()
	lion.commandes.vomir_voulu = true


func _tracer_bataille() -> void:
	print("-- Bataille locale à 4 lions sur le Village")
	seed(20260926)
	_empreinte = 0
	GS.niveau_courant = 2
	GS.difficulte_courante = 0
	GS.configurer_bataille(NB_LIONS)
	for i in range(NB_LIONS):
		GS.joueurs[i].pseudo = "Joueur %d" % (i + 1)
	var main := _charger_main()
	var lions: Array = main.lions
	lions[0].commandes = Commandes.manuelles()
	var ville: Node2D = main.get_node("Ville")
	var spawner: Node = main.get_node("Spawner")
	_suivre(GS.joueurs)
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	var couloirs: Array[Dictionary] = []
	for i in range(NB_LIONS):
		var centre := 2000.0 * (i + 0.5) / NB_LIONS
		couloirs.append({"min": maxf(centre - 350.0, 150.0), "max": minf(centre + 350.0, 1850.0),
			"sens": 1.0 if i % 2 == 0 else -1.0, "rangee": i % HAUTEURS_JET.size()})
	var l0: Node2D = lions[0]
	var l1: Node2D = lions[1]
	var l2: Node2D = lions[2]
	var l3: Node2D = lions[3]
	var bords := 0
	var chevauchements := 0
	var f := -1  # ticks depuis la fin de l'intro
	while f < TICKS_BATAILLE:
		if GS.pret:
			f += 1
		if f >= 0:
			for i in range(NB_LIONS):
				_piloter(lions[i], couloirs[i], haut)
		# La gerbe du lion 1 sur le lion 2, placé sous la trajectoire
		if f >= 600 and f < 660:
			if f == 600:
				l0.global_position = Vector2(500, 300)
				l0.direction_du_lion = 1
			l0.commandes.direction_voulue = Vector2.ZERO
			l0.commandes.vomir_voulu = true
			if f >= 605:
				l1.global_position = l0.find_child("ZoneContact2", true, false).global_position - l1.CENTRE
				l1.commandes.direction_voulue = Vector2.ZERO
		# Un choc de face, puis une poussée continue contre un lion arrêté
		if f >= 900 and f < 1120:
			if f == 900 or f == 1000:
				l2.global_position = Vector2(600, 400)
				l3.global_position = Vector2(900, 400)
			l2.commandes.direction_voulue = Vector2.RIGHT
			l3.commandes.direction_voulue = Vector2.LEFT if f < 1000 else Vector2.ZERO
			l2.commandes.vomir_voulu = false
			l3.commandes.vomir_voulu = false
		if f == 1200:
			var soucoupe: Node2D = spawner.spawn_soucoupe(l1.global_position.y + l1.CENTRE.y)
			soucoupe.position.x = l1.global_position.x + l1.CENTRE.x
		if f == 1300:
			spawner.spawn_bonus(l2.global_position + l2.CENTRE)
		if f == 1400 or f == 1410 or f == 1420:
			spawner.spawn_pickup(0, l3.global_position + l3.CENTRE)
		# Les bords de l'écran : en haut à gauche, puis en bas à droite
		if f >= 1500 and f < 1620:
			l0.commandes.direction_voulue = Vector2(-1, -1).normalized()
		if f >= 1620 and f < 1740:
			l1.commandes.direction_voulue = Vector2(1, 1).normalized()
		await physics_frame
		_tracer_tick(lions, ville)
		for l: Node2D in lions:
			if l.global_position.x == 0.0 or l.global_position.y == -(l.get_node("Visuel/Pseudo") as Control).position.y:
				bords += 1
		if l2.get_node("PareChocs").global_position.distance_to(l3.get_node("PareChocs").global_position) < 90.0:
			chevauchements += 1
	GS.terminer_partie(true)
	var chocs: int = GS.joueurs.reduce(func(n: int, j: Joueur) -> int: return n + j.chocs, 0)
	print("TRACE bataille %d" % _empreinte)
	print("  (bataille) %s, chocs %d, ticks aux bords %d, pare-chocs chevauchés %d, scores %s"
		% [_vus, chocs, bords, chevauchements, ville.territoire.scores()])
	_check(_vus.gerbe > 0 and _vus.ennemi > 0 and _vus.cran >= 3 and _vus.xxl > 0 and chocs > 0 and bords > 0 and chevauchements > 0,
		"la bataille passe par les gerbes, les ennemis, les pastilles, l'étoile, les chocs, les bords et les pare-chocs")
	_oublier(GS.joueurs)
	await _liberer(main)
	for j: Joueur in GS.joueurs:
		j.pseudo = ""


func _tracer_solo() -> void:
	print("-- Partie solo sur la Skyline")
	seed(20260927)
	_empreinte = 0
	GS.configurer_solo()
	GS.niveau_courant = 0
	GS.difficulte_courante = 0
	var main := _charger_main()
	var lion: Node2D = main.lion
	lion.commandes = Commandes.manuelles()
	var ville: Node2D = main.get_node("Ville")
	var spawner: Node = main.get_node("Spawner")
	_suivre([GS.joueur_local()])
	GS.joueur_local().vies = 9  # la partie dure jusqu'au bout des ticks, malgré les ennemis
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	var couloir := {"min": 150.0, "max": 1850.0, "sens": 1.0, "rangee": 0}
	var f := -1
	while f < TICKS_SOLO:
		if GS.pret:
			f += 1
		if f >= 0:
			_piloter(lion, couloir, haut)
		if f == 120 or f == 130 or f == 140:
			spawner.spawn_pickup((f - 120) / 10, lion.global_position + lion.CENTRE)
		if f == 400 or f == 1000:
			var soucoupe: Node2D = spawner.spawn_soucoupe(lion.global_position.y + lion.CENTRE.y)
			soucoupe.position.x = lion.global_position.x + lion.CENTRE.x
		if f == 700:
			spawner.spawn_bonus(lion.global_position + lion.CENTRE)
		await physics_frame
		_tracer_tick([lion], null)
	print("TRACE solo %d" % _empreinte)
	print("  (solo) %s, vies %d, couverture %.3f" % [_vus, GS.joueur_local().vies, ville.progression()])
	_check(_vus.couleur >= 3 and _vus.touche >= 2 and _vus.xxl > 0 and GS.partie_en_cours,
		"le solo passe par les couleurs, les coups et l'étoile, sans finir la partie")
	_oublier([GS.joueur_local()])
	GS.terminer_partie(false)
	await _liberer(main)


func _tracer_replique() -> void:
	print("-- Réplique d'un lion sur un client")
	seed(20260928)
	_empreinte = 0
	GS.configurer_bataille(2)
	GS.nouvelle_partie()
	GS.pret = true
	var poste := Node2D.new()
	poste.name = "PosteTrace"
	root.add_child(poste)
	var api := SceneMultiplayer.new()
	var pair := ENetMultiplayerPeer.new()
	_check(pair.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client, jamais connecté")
	api.multiplayer_peer = pair
	set_multiplayer(api, poste.get_path())
	var j: Joueur = GS.joueurs[1]
	var repl: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
	repl.joueur = j
	repl.commandes = Commandes.manuelles()
	repl.direction_du_lion = -1
	repl.position = Vector2(600, 500)
	poste.add_child(repl)
	_suivre([j])
	var etoiles_vues := 0
	var emission_vue := 0
	for f in range(TICKS_REPLIQUE):
		# Ce qu'écrirait le Synchro : une course en huit, le vomi par moments
		repl.position = Vector2(600 + 300 * sin(f * 0.05), 500 + 120 * sin(f * 0.1))
		repl.velocity = Vector2(15 * cos(f * 0.05), 12 * cos(f * 0.1)) * 60.0
		repl.direction_du_lion = 1 if cos(f * 0.05) >= 0.0 else -1
		repl.vomi_de_l_hote = (f / 30) % 2 == 1
		repl.commandes.direction_voulue = Vector2.LEFT  # ignorées par une réplique
		if f == 60:
			j.etourdir(1.5, 1.0, repl.global_position + Vector2(-50, 66), GS.joueurs[0].couleur)
		if f == 150:
			j.recevoir_fin_etourdissement(1.0)
		if f == 170:
			j.recevoir_crans(3)
		if f == 180:
			j.activer_bonus(2.0)
		if f == 200:
			j.recevoir_fin_bonus()
		await physics_frame
		_tracer_tick([repl], null)
		if repl.get_node("Visuel/Etoiles").visible:
			etoiles_vues += 1
		if repl.est_en_train_de_vomir:
			emission_vue += 1
	print("TRACE replique %d" % _empreinte)
	_check(etoiles_vues > 0 and emission_vue > 0 and _vus.gerbe == 1 and _vus.cran == 1 and _vus.xxl == 1,
		"la réplique passe par le vomi reçu, l'étourdissement, les crans et la gerbe XXL reçus")
	_oublier([j])
	repl.free()
	set_multiplayer(null, poste.get_path())
	pair.close()
	poste.free()
