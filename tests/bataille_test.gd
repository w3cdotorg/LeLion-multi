extends SceneTree
## Test de la bataille locale : godot --headless --fixed-fps 60 --script tests/bataille_test.gd
## Une bataille à 4 lions dans un seul processus (sans réseau : ce poste est l'hôte) : écran 16:9,
## un lion par joueur, apparitions et peintre à l'échelle de l'écran, puis une manche de 90 s
## pilotée par le test, dont les mesures (territoire, couverture, vols, crans, jeux de tampons)
## s'affichent en lignes « MESURE ». Avec `--fixed-fps 60`, chaque frame avance d'un tick sans
## attendre l'horloge : la manche entière prend quelques secondes.
## Compilé avant les autoloads : ne nomme ni `GameState`, ni `Lion`, ni `Ennemi`, ni la ville.

const NB_LIONS := 4
const TAILLE_BATAILLE := Vector2(2000, 1125)
const HAUTEURS_JET: Array[float] = [-233.0, -200.0, -270.0]  # y du lion sous le haut de la skyline, comme le pilote de la démo
const DISTANCE_PASTILLE_TENTANTE := 900.0  # le pilote de la manche va chercher une pastille dans ce rayon

var _echecs := 0
var GS: Node
## Les règles branchées par `configurer_bataille`, avant le chargement de la scène.
var _regles_branchees: Regles


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func _run() -> void:
	print("== test de bataille LeLion ==")
	GS = root.get_node("GameState")
	seed(20260925)  # apparitions, ennemis et motifs des tampons reproductibles d'un passage à l'autre
	await _tester_fin_pendant_intro()
	await _tester_scene()
	await _tester_apparitions()
	await _tester_peintre()
	await _tester_manche()
	await _tester_solo_apres_bataille()
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


## Comme le fera le salon : les règles de bataille sont branchées AVANT le chargement de la scène.
func _charger_bataille(niveau: int) -> Node:
	GS.niveau_courant = niveau
	GS.difficulte_courante = 0  # Facile : le solo y a des cœurs, pas la bataille
	GS.configurer_bataille(NB_LIONS)
	_regles_branchees = GS.regles
	var main: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	return main


## L'intro « Prêt ? Vomissez ! » appelle GameState.demarrer à sa fin.
func _attendre_depart() -> void:
	for i in range(300):
		if GS.pret:
			return
		await physics_frame


## Ennemis, pastilles et étoiles sont des enfants de la scène : ils partent avec elle.
func _liberer(main: Node) -> void:
	paused = false
	main.free()
	await _frames(1)


func _tester_scene() -> void:
	print("-- Scène de bataille à 4 lions")
	var main := await _charger_bataille(0)
	var ville: Node2D = main.get_node("Ville")
	var lions: Array = main.lions
	_check(root.content_scale_size == Vector2i(TAILLE_BATAILLE) and root.get_visible_rect().size == TAILLE_BATAILLE,
		"l'écran de la bataille est en 16:9 (%s)" % root.get_visible_rect().size)
	_check(main.get_node("Ciel").size == TAILLE_BATAILLE and main.get_node("Camera").position == TAILLE_BATAILLE / 2.0,
		"le ciel couvre l'écran et la caméra en vise le centre")
	_check(is_equal_approx(ville.position.y + ville.tex_size.y / 2.0, TAILLE_BATAILLE.y) and ville.territoire != null,
		"la skyline est posée en bas de l'écran et tient le territoire")
	_check(is_same(GS.regles, _regles_branchees), "la scène garde les règles branchées avant elle (elle ne configure pas le mode)")
	_check(lions.size() == NB_LIONS and get_nodes_in_group("lion").size() == NB_LIONS, "un lion par joueur (%d)" % lions.size())
	_check(range(lions.size()).all(func(i: int) -> bool: return lions[i].joueur == GS.joueurs[i]),
		"chaque lion porte son joueur, dans l'ordre des joueurs")
	var ids_commandes := {}
	for l in lions.slice(1):
		ids_commandes[l.commandes.get_instance_id()] = l.commandes.source
	_check(lions[0].commandes.source == Commandes.Source.LOCALES and ids_commandes.size() == NB_LIONS - 1
		and ids_commandes.values().all(func(s: int) -> bool: return s == Commandes.Source.MANUELLES),
		"seul le lion local lit le clavier ; chaque autre lion a ses propres commandes manuelles")
	var teints := lions.size() == NB_LIONS
	var repartis := lions.size() == NB_LIONS
	var centres: Array[Vector2] = []
	for i in range(lions.size()):
		var mat := lions[i].sprite.material as ShaderMaterial
		teints = teints and mat != null and mat.get_shader_parameter("couleur_joueur") == GS.PALETTE_BATAILLE[i]
		var centre: Vector2 = lions[i].position + lions[i].CENTRE
		centres.append(centre)
		repartis = repartis and is_equal_approx(centre.x, TAILLE_BATAILLE.x * (i + 0.5) / NB_LIONS) \
			and is_equal_approx(lions[i].position.y, TAILLE_BATAILLE.y * main.hauteur_depart_lions)
	_check(teints, "chaque lion est teint de la couleur de son joueur")
	_check(repartis, "les lions partent en haut du ciel, répartis sur la largeur (%s)" % [centres])
	await _attendre_depart()
	_check(GS.pret, "l'intro lance la manche")
	GS.terminer_partie(true)
	_check(paused and main.get_node_or_null("GameOver") == null, "la fin de manche fige la bataille, sans le bilan du solo")
	await _liberer(main)


func _tester_solo_apres_bataille() -> void:
	print("-- Solo après une bataille")
	GS.configurer_solo()
	GS.niveau_courant = 2  # le Village : son peintre
	GS.difficulte_courante = 0
	var main: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	_check(root.get_visible_rect().size == Vector2(2000, 648) and main.lions.size() == 1
		and get_nodes_in_group("lion").size() == 1,
		"une partie solo après une bataille repasse en 2000×648, avec un seul lion")
	_check(main.lion.sprite.material == null and main.lion.commandes.source == Commandes.Source.LOCALES
		and main.lion.position == Vector2(200, 200),
		"son lion garde le rendu d'origine, sa place de départ et les commandes de ce poste")
	var boss: Node2D = get_first_node_in_group("boss")
	_check(main.get_node("Ciel").size == Vector2(2000, 648) and main.get_node("Camera").position == Vector2(1000, 324)
		and boss != null and absf(boss.y_sol - (648 - 180)) < 0.5,
		"ciel, caméra et peintre retrouvent l'écran du solo")
	await _liberer(main)


func _etoiles(main: Node) -> Array[Node]:
	var etoiles: Array[Node] = []
	for n in main.get_children():
		if n.scene_file_path.ends_with("BonusPickup.tscn"):
			etoiles.append(n)
	return etoiles


func _tester_fin_pendant_intro() -> void:
	print("-- Fin de partie pendant l'intro")
	var main := await _charger_bataille(0)
	var spawner: Node = main.get_node("Spawner")
	_check(not GS.pret and spawner._timer_soucoupe == null,
		"(pré-condition) l'intro tourne, les minuteries des ennemis n'existent pas encore")
	GS.terminer_partie(false)
	_check(not GS.partie_en_cours and paused and main.get_node_or_null("GameOver") == null,
		"une bataille terminée se fige sans le bilan du solo, même pendant l'intro (le Spawner n'a encore aucune minuterie à arrêter)")
	await _liberer(main)


func _tester_apparitions() -> void:
	print("-- Apparitions de la bataille")
	var main := await _charger_bataille(0)
	var ville: Node2D = main.get_node("Ville")
	var lions: Array = main.lions
	await _attendre_depart()
	# Ce qui apparaît est décidé par les règles, à l'échelle de l'écran
	var spawner: Node = main.get_node("Spawner")
	_check(spawner._timer_soucoupe != null and spawner._timer_coeur == null,
		"en bataille, même en Facile, aucun cœur n'est programmé")
	var echelle := TAILLE_BATAILLE.y / 648.0
	var zone: Rect2 = spawner.zone_pickups
	var dans_zone := true
	var y_max := 0.0
	var loin_de_tous := 0
	for i in range(200):
		var p: Vector2 = spawner._position_pickup_aleatoire()
		y_max = maxf(y_max, p.y)
		if p.x < zone.position.x or p.x > zone.end.x or p.y < zone.position.y * echelle - 0.01 or p.y > zone.end.y * echelle + 0.01:
			dans_zone = false
		if lions.all(func(l: Node2D) -> bool: return p.distance_to(l.global_position) >= spawner.distance_min_du_lion):
			loin_de_tous += 1
	_check(dans_zone and y_max > zone.end.y, "les pastilles apparaissent dans leur zone, à l'échelle de l'écran (y jusqu'à %.0f px)" % y_max)
	_check(loin_de_tous >= 190, "les pastilles apparaissent loin de tous les lions, pas seulement du premier (%d/200)" % loin_de_tous)
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	var ys: Array[float] = []
	for i in range(60):
		var soucoupe: Node2D = spawner.spawn_soucoupe()
		ys.append(soucoupe.position.y)
		soucoupe.free()
	_check(ys.min() >= spawner.zone_y_ennemis.x * echelle - 0.01 and ys.max() <= spawner.zone_y_ennemis.y * echelle + 0.01
		and ys.max() > haut + HAUTEURS_JET[1],
		"les ennemis apparaissent à l'échelle de l'écran et atteignent la bande de peinture (y de %.0f à %.0f)" % [ys.min(), ys.max()])

	# Pastilles : la suivante arrive après le ramassage, même si aucune couleur n'est débloquée
	spawner.delai_entre_pickups = 0.5
	var premiere: Node2D = null
	for i in range(120):
		premiere = get_first_node_in_group("pickup")
		if premiere != null:
			break
		await physics_frame
	_check(premiere != null, "une première pastille arrive après le départ")
	var l2: Node2D = lions[2]
	premiere.global_position = l2.global_position + l2.CENTRE
	await _frames(3)
	_check(not is_instance_valid(premiere) and GS.joueurs[2].crans == 2
		and GS.joueurs.filter(func(j: Joueur) -> bool: return j.crans > 1).size() == 1,
		"une pastille donne un cran au lion qui la touche, à lui seul")
	var suivante: Node2D = null
	for i in range(90):
		suivante = get_first_node_in_group("pickup")
		if suivante != null:
			break
		await physics_frame
	_check(suivante != null, "la pastille suivante arrive après le ramassage de la précédente (aucun déblocage de couleur ne le signale en bataille)")

	# Étoile : possible quel que soit l'état du joueur local
	GS.joueur_local().activer_bonus(5.0)
	spawner._on_timer_bonus()
	var etoiles := _etoiles(main)
	_check(etoiles.size() == 1, "l'étoile apparaît même quand le joueur local est déjà en gerbe XXL")
	for e in etoiles:
		e.free()
	GS.joueur_local().bonus_restant = 0.0
	await _liberer(main)


func _tester_peintre() -> void:
	print("-- Peintre en 16:9")
	var main := await _charger_bataille(2)
	var ville: Node2D = main.get_node("Ville")
	await _frames(1)  # le Spawner ajoute le peintre en différé
	var boss: Node2D = get_first_node_in_group("boss")
	_check(boss != null, "le Village de la bataille a son peintre")
	var hauteur: float = boss.sprite.scale.y * boss.sprite.texture.get_height()
	_check(absf(hauteur - 648.0 * boss.hauteur_ratio) < 1.0,
		"le peintre garde sa taille du solo (%.0f px) sur l'écran de 1125 px" % hauteur)
	_check(absf(boss.y_sol - (TAILLE_BATAILLE.y - ville.tex_size.y)) < 0.5 and absf(boss.position.y + boss._demi_hauteur - boss.y_sol) < 0.5,
		"le peintre est posé sur le haut de la skyline, en bas de l'écran (sol %.0f)" % boss.y_sol)
	GS.progression = 0.0
	GS.temps_ecoule = ReglesBataille.DUREE_MANCHE / 2.0
	_check(is_equal_approx(boss.facteur_vitesse(), lerpf(1.0, boss.acceleration_max, 0.5)),
		"à mi-manche, le peintre a fait la moitié de son accélération, que la ville soit peinte ou non (%.3f)" % boss.facteur_vitesse())
	GS.temps_ecoule = 0.0
	await _attendre_depart()
	boss._arreter()
	boss.etat = boss.Etat.PAUSE
	boss.position.x = TAILLE_BATAILLE.x / 2.0
	var l3: Node2D = main.lions[3]
	var j3: Joueur = GS.joueurs[3]
	l3.global_position = Vector2(boss.position.x - l3.CENTRE.x, boss.position.y - l3.CENTRE.y)
	await _frames(3)
	_check(j3.est_etourdi() and j3.etourdi_restant > ReglesBataille.DUREE_ETOURDI_ENNEMI - 0.2 and j3.vies == 3,
		"le peintre étourdit le lion de bataille qu'il touche, sans lui ôter de vie")
	await _liberer(main)


## Pastilles et étoiles de la scène.
func _pastilles(main: Node) -> Array[Node]:
	var liste: Array[Node] = []
	liste.assign(get_nodes_in_group("pickup"))
	liste.append_array(_etoiles(main))
	return liste


## La pastille (ou l'étoile) que ce lion va chercher : la plus proche à portée, dont il est le
## lion le plus proche ; null s'il n'y en a pas.
func _pastille_visee(lion: Node2D, lions: Array, pastilles: Array[Node]) -> Node2D:
	var centre: Vector2 = lion.global_position + lion.CENTRE
	var visee: Node2D = null
	var distance := DISTANCE_PASTILLE_TENTANTE
	for p: Node2D in pastilles:
		var d := centre.distance_to(p.global_position)
		var plus_proche := lions.all(func(l: Node2D) -> bool:
			return l == lion or (l.global_position + l.CENTRE).distance_to(p.global_position) >= d)
		if d < distance and plus_proche:
			distance = d
			visee = p
	return visee


## Pilote d'un lion de la manche : il va chercher sa pastille s'il en vise une ; sinon il balaie
## son couloir en vomissant et change de hauteur à chaque demi-tour. Les couloirs voisins se
## chevauchent : les lions se volent des cellules.
func _piloter(lion: Node2D, couloir: Dictionary, haut: float, lions: Array, pastilles: Array[Node]) -> void:
	var centre: Vector2 = lion.global_position + lion.CENTRE
	var visee := _pastille_visee(lion, lions, pastilles)
	if visee != null:
		lion.commandes.direction_voulue = (visee.global_position - centre).normalized()
		lion.commandes.vomir_voulu = false
		return
	if centre.x >= couloir.max:
		couloir.sens = -1.0
		couloir.rangee = (couloir.rangee + 1) % HAUTEURS_JET.size()
	elif centre.x <= couloir.min:
		couloir.sens = 1.0
		couloir.rangee = (couloir.rangee + 1) % HAUTEURS_JET.size()
	var ecart_y: float = haut + HAUTEURS_JET[couloir.rangee] - lion.global_position.y
	lion.commandes.direction_voulue = Vector2(couloir.sens, clampf(ecart_y / 60.0, -1.0, 1.0)).normalized()
	lion.commandes.vomir_voulu = true


func _tester_manche() -> void:
	print("-- Manche à 4 lions, pilotée")
	var main := await _charger_bataille(0)
	var ville: Node2D = main.get_node("Ville")
	var t: Territoire = ville.territoire
	var lions: Array = main.lions
	lions[0].commandes = Commandes.manuelles()  # le lion local est piloté par le test, comme les autres
	await _attendre_depart()
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	var couloirs: Array[Dictionary] = []
	for i in range(NB_LIONS):
		var centre := TAILLE_BATAILLE.x * (i + 0.5) / NB_LIONS
		couloirs.append({"min": maxf(centre - 350.0, 150.0), "max": minf(centre + 350.0, 1850.0),
			"sens": 1.0 if i % 2 == 0 else -1.0, "rangee": i % HAUTEURS_JET.size()})
	var jeux_au_depart: int = ville._tampons.size()
	var jeux_max_par_frame := 0
	var pire_frame_ms := 0.0
	var instant := Time.get_ticks_usec()
	for f in range(int(ReglesBataille.DUREE_MANCHE * Engine.physics_ticks_per_second)):
		var pastilles := _pastilles(main)
		for i in range(NB_LIONS):
			_piloter(lions[i], couloirs[i], haut, lions, pastilles)
		var jeux_avant: int = ville._tampons.size()
		await physics_frame
		jeux_max_par_frame = maxi(jeux_max_par_frame, ville._tampons.size() - jeux_avant)
		var maintenant := Time.get_ticks_usec()
		pire_frame_ms = maxf(pire_frame_ms, (maintenant - instant) / 1000.0)
		instant = maintenant
	GS.terminer_partie(true)
	var scores: Array = range(NB_LIONS).map(func(i: int) -> int: return t.cellules_de(i))
	var comptees: int = scores.reduce(func(somme: int, n: int) -> int: return somme + n, 0)
	var personne := t.cellules_de(Territoire.PERSONNE)
	var chargees := 0
	for c in range(t.taille_grille.x * t.taille_grille.y):
		if t.proprietaire(c) != Territoire.PERSONNE:
			chargees += 1
	var vols: Array = GS.joueurs.map(func(j: Joueur) -> int: return j.cellules_volees)
	print("  MESURE manche de %d s : cellules %s (%.1f %% de la ville), %d chargées dont %d ne comptent pour personne (%.0f %%), couverture %.1f %%"
		% [int(ReglesBataille.DUREE_MANCHE), scores, 100.0 * comptees / t.nb_peignables, chargees, chargees - comptees,
			100.0 * (chargees - comptees) / maxi(chargees, 1), 100.0 * ville.progression()])
	print("  MESURE vols %s, étourdissements infligés %s, chocs %s, crans %s"
		% [vols, GS.joueurs.map(func(j: Joueur) -> int: return j.etourdissements_infliges),
			GS.joueurs.map(func(j: Joueur) -> int: return j.chocs), GS.joueurs.map(func(j: Joueur) -> int: return j.crans)])
	print("  MESURE jeux de tampons : %d générés pendant la manche (%d en cache), au plus %d dans une même frame ; frame la plus longue %.1f ms"
		% [ville._tampons.size() - jeux_au_depart, ville._tampons.size(), jeux_max_par_frame, pire_frame_ms])
	_check(scores.all(func(n: int) -> bool: return n > 0), "chaque lion possède des cellules en fin de manche (%s)" % [scores])
	_check(comptees + personne == t.nb_peignables, "les scores et les cellules qui ne comptent pour personne font toute la ville")
	_check(vols.any(func(n: int) -> bool: return n > 0), "les couloirs qui se chevauchent donnent des vols (%s)" % [vols])
	_check(GS.joueurs.any(func(j: Joueur) -> bool: return j.crans > 1), "des pastilles sont ramassées en cours de manche")
	_check(paused and main.get_node_or_null("GameOver") == null, "la fin de manche fige la bataille, sans le bilan du solo")
	await _liberer(main)
