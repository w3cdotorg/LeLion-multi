extends SceneTree
## Test de la bataille locale : godot --headless --fixed-fps 60 --script tests/bataille_test.gd
## Une bataille à 4 lions dans un seul processus (sans réseau : ce poste est l'hôte) : écran 16:9,
## un lion par joueur, apparitions et peintre à l'échelle de l'écran, puis une manche de 90 s
## pilotée par le test, dont les mesures (territoire, couverture, vols, crans, jeux de tampons)
## s'affichent en lignes « MESURE ». Avec `--fixed-fps 60`, chaque frame avance d'un tick sans
## attendre l'horloge : la manche entière prend quelques secondes. Avec le rendu (sans
## `--headless`) et `-- --captures=<dossier>`, la manche est aussi capturée en PNG (contrôle ◉).
## `--captures` est ignoré en `--headless` (pas de rendu). Sections : intro, scène, apparitions,
## peintre, pseudos et chocs, réglage du territoire, la manche à 4, retour au titre, solo après
## une bataille.
## Compilé avant les autoloads : ne nomme ni `GameState`, ni `Lion`, ni `Ennemi`, ni la ville.

const NB_LIONS := 4
const TAILLE_BATAILLE := Vector2(2000, 1125)
const HAUTEURS_JET: Array[float] = [-233.0, -200.0, -270.0]  # y du lion sous le haut de la skyline, comme le pilote de la démo
const DISTANCE_PASTILLE_TENTANTE := 900.0  # le pilote de la manche va chercher une pastille dans ce rayon
const RAYON_PASTILLE := 28.0  # Scenes/ColorPickup.tscn : CircleShape2D (M4, revue finale phase 17)
## Réglage du territoire (spec §6) : sur une passe pleine vitesse, les cellules que le territoire
## fait compter, rapportées à celles que compte la couverture du solo pour la même passe, restent
## dans ces bornes ; et la même passe sur les cellules d'un adversaire lui en vole au moins cette
## part.
const CIBLE_RAPPORT_COUVERTURE := Vector2(0.7, 1.3)
const CIBLE_PART_VOLEE := 0.4
const INSTANTS_CAPTURES: Array[float] = [5.0, 45.0, 88.0]  # secondes de manche

var _echecs := 0
var GS: Node
var _dossier_captures := ""
## Les règles branchées par `configurer_bataille`, avant le chargement de la scène.
var _regles_branchees: Regles


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):
			_dossier_captures = arg.trim_prefix("--captures=")
	if not _dossier_captures.is_empty() and DisplayServer.get_name() == "headless":
		# En headless, `RenderingServer.frame_post_draw` n'est jamais émis (pas de rendu réel) :
		# `_capturer` attendrait indéfiniment le premier signal. Prévenir et ne pas capturer.
		printerr("  ⚠️ --captures ignoré : pas de rendu en --headless")
		_dossier_captures = ""
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
	await _tester_rythme_pastilles()
	await _tester_peintre()
	await _tester_pseudos_et_chocs()
	await _tester_reglage_territoire()
	await _tester_manche()
	await _tester_hud()
	await _tester_retour_au_titre()
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
	# Le solo a été configuré par l'écran titre (section précédente), comme dans le jeu.
	_check(GS.regles is ReglesSolo and GS.joueurs.size() == 1,
		"(pré-condition) le solo est déjà branché avant cette section")
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
		if lions.all(func(l: Node2D) -> bool: return p.distance_to(l.global_position + l.CENTRE) >= spawner.distance_min_du_lion):
			loin_de_tous += 1
	_check(dans_zone and y_max > zone.end.y, "les pastilles apparaissent dans leur zone, à l'échelle de l'écran (y jusqu'à %.0f px)" % y_max)
	_check(loin_de_tous >= 190, "les pastilles apparaissent loin du centre de tous les lions, pas seulement du premier (%d/200)" % loin_de_tous)
	# Phase 17 : aucun des dix essais assez loin (distance impossible) : le plus loin de tous est gardé
	var distance_du_jeu: float = spawner.distance_min_du_lion
	spawner.distance_min_du_lion = 1.0e6
	var graine := 1717
	var attendue := Vector2.ZERO
	var derniere := Vector2.ZERO
	var ecart_max := -1.0
	while graine < 1737:  # une graine dont le plus loin n'est pas le dernier essai (celui que garde le solo)
		seed(graine)
		ecart_max = -1.0
		for essai in range(10):
			derniere = Vector2(randf_range(zone.position.x, zone.end.x), randf_range(zone.position.y * echelle, zone.end.y * echelle))
			var ecart := INF
			for l: Node2D in lions:
				ecart = minf(ecart, derniere.distance_to(l.global_position + l.CENTRE))
			if ecart > ecart_max:
				ecart_max = ecart
				attendue = derniere
		if attendue != derniere:
			break
		graine += 1
	seed(graine)
	var gardee: Vector2 = spawner._position_pickup_aleatoire()
	spawner.distance_min_du_lion = distance_du_jeu
	seed(20260925)
	_check(gardee == attendue and attendue != derniere,
		"sans essai assez loin, la pastille naît au plus loin des lions des dix essais, pas au dernier (%.0f px du plus proche)" % ecart_max)
	# Extra (revue de capture) : aucune pastille ne naît sous la bande du HUD (les vignettes), où
	# elle se retrouverait partiellement cachée
	var y_min_pastilles := INF
	for i in range(200):
		y_min_pastilles = minf(y_min_pastilles, spawner._position_pickup_aleatoire().y)
	_check(y_min_pastilles >= ReglesBataille.HAUTEUR_BANDE_HUD - 0.01,
		"les pastilles n'apparaissent jamais sous la bande du HUD (y min %.0f px, attendu >= %.0f px)"
			% [y_min_pastilles, ReglesBataille.HAUTEUR_BANDE_HUD])
	# M4 (revue finale phase 17) : le check au-dessus ne teste que la fonction pure des règles (le
	# `zone_pickups` du Spawner est déjà ajusté par sa précondition) ; celui-ci teste le branchement
	# lui-même (`Spawner._ready`), qui mord sous la mutation « zone_pickups_ajustee jamais appelée »
	_check(zone.position.y * echelle >= ReglesBataille.HAUTEUR_BANDE_HUD - 0.01,
		"le Spawner applique bien la zone ajustée sous la bande du HUD (%.0f px, attendu >= %.0f px)"
			% [zone.position.y * echelle, ReglesBataille.HAUTEUR_BANDE_HUD])
	# Et la bande est assez haute pour le vrai bas des vignettes du HUD (mesuré, pas supposé) plus le
	# rayon d'une pastille : sans air, une pastille née en haut de la zone mordrait sous les vignettes
	var hud: CanvasLayer = main.hud_bataille
	var bas_vignette: float = hud.vignettes[0].cadre.get_global_rect().end.y
	_check(bas_vignette + RAYON_PASTILLE <= ReglesBataille.HAUTEUR_BANDE_HUD,
		"la bande du HUD couvre le vrai bas des vignettes plus le rayon d'une pastille (bas %.0f px + rayon %.0f px <= bande %.0f px)"
			% [bas_vignette, RAYON_PASTILLE, ReglesBataille.HAUTEUR_BANDE_HUD])
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	var ys: Array[float] = []
	for i in range(60):
		var soucoupe: Node2D = spawner.spawn_soucoupe()
		ys.append(soucoupe.position.y)
		soucoupe.free()
	_check(ys.min() >= spawner.zone_y_ennemis.x * echelle - 0.01 and ys.max() <= spawner.zone_y_ennemis.y * echelle + 0.01
		and ys.max() > haut + HAUTEURS_JET[1],
		"les ennemis apparaissent à l'échelle de l'écran et atteignent la bande de peinture (y de %.0f à %.0f)" % [ys.min(), ys.max()])

	# Pastilles : la suivante arrive après le ramassage, même si aucune couleur n'est débloquée (le délai
	# est celui des règles de bataille : `delai_entre_pickups`, celui du solo, n'y compte pas)
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
	for i in range(int((ReglesBataille.DELAI_ENTRE_PASTILLES + 0.5) * Engine.physics_ticks_per_second)):
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


## Phase 17 : le rythme des pastilles à 4 joueurs, lions immobiles, ennemis écartés : une pastille
## toutes les 4 s jusqu'à trois à la fois, jamais plus ; une pastille que personne ne prend expire au
## bout de 12 s, et une autre la remplace 4 s plus tard.
func _tester_rythme_pastilles() -> void:
	print("-- Rythme des pastilles à 4")
	var main := await _charger_bataille(0)
	var ecarter := func() -> void:
		for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss"):
			ennemi.queue_free()
	physics_frame.connect(ecarter)
	await _attendre_depart()
	var depart: float = GS.temps_ecoule
	var arrivees: Array[float] = []  # secondes de manche de chaque arrivée
	var departs: Array[float] = []
	var vues := {}
	var plus_grand_nombre := 0
	var premiere: Node2D = null
	var ramassees := 0
	var crans_avant := 0
	for j: Joueur in GS.joueurs:
		crans_avant += j.crans
	for f in range(int(26.0 * Engine.physics_ticks_per_second)):
		await physics_frame
		var presentes := get_nodes_in_group("pickup")
		plus_grand_nombre = maxi(plus_grand_nombre, presentes.size())
		var t: float = GS.temps_ecoule - depart
		for p: Node in presentes:
			if not vues.has(p.get_instance_id()):
				vues[p.get_instance_id()] = t
				arrivees.append(t)
				if arrivees.size() == 1:
					premiere = p
		if arrivees.size() >= 1 and not is_instance_valid(premiere) and departs.is_empty():
			departs.append(t)  # (un objet libéré ne se compare pas à null : is_instance_valid seul)
	physics_frame.disconnect(ecarter)
	for j: Joueur in GS.joueurs:
		ramassees += j.crans
	ramassees -= crans_avant
	var arrondies: Array = arrivees.map(func(t: float) -> String: return "%.1f" % t)
	_check(ramassees == 0, "(pré-condition) aucun lion, immobile, ne ramasse de pastille (%d)" % ramassees)
	_check(plus_grand_nombre == ReglesBataille.PASTILLES_A_4_JOUEURS_ET_PLUS and arrivees.size() >= 4
		and absf(arrivees[1] - arrivees[0] - ReglesBataille.DELAI_ENTRE_PASTILLES) < 0.1
		and absf(arrivees[2] - arrivees[1] - ReglesBataille.DELAI_ENTRE_PASTILLES) < 0.1,
		"à 4, une pastille toutes les 4 s jusqu'à trois à la fois, jamais plus (arrivées %s)" % [arrondies])
	_check(not departs.is_empty() and absf(departs[0] - arrivees[0] - ReglesBataille.DUREE_DE_VIE_PASTILLE) < 0.1
		and absf(arrivees[3] - departs[0] - ReglesBataille.DELAI_ENTRE_PASTILLES) < 0.1,
		"une pastille que personne ne prend expire au bout de 12 s (%.1f s), une autre arrive 4 s plus tard (%.1f s)"
			% [departs[0] - arrivees[0] if not departs.is_empty() else -1.0, arrivees[3] - departs[0] if not departs.is_empty() and arrivees.size() >= 4 else -1.0])
	# Au plafond, une arrivée de plus (celle qu'un départ et la suite des arrivées programment parfois en
	# même temps) n'ajoute rien
	var au_plafond := get_nodes_in_group("pickup").size()
	main.get_node("Spawner")._spawn_prochain_pickup()
	await _frames(1)
	_check(au_plafond == ReglesBataille.PASTILLES_A_4_JOUEURS_ET_PLUS and get_nodes_in_group("pickup").size() == au_plafond,
		"au plafond (%d), une pastille de plus ne peut pas arriver" % au_plafond)
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
	_check(is_equal_approx(j3.invulnerable_restant - j3.etourdi_restant, ReglesBataille.DUREE_REPIT_ENNEMI),
		"puis lui laisse %.0f s de répit pour fuir, même s'il reste dessous (%.2f s)" % [ReglesBataille.DUREE_REPIT_ENNEMI, j3.invulnerable_restant - j3.etourdi_restant])
	# Phase 17 : en bataille, le peintre se repose deux fois plus longtemps hors de l'écran qu'en solo
	boss._changer_etat(boss.Etat.REPOS)
	var attendu: float = boss.duree_repos * ReglesBataille.FACTEUR_REPOS_PEINTRE * boss.facteur_vitesse()
	var ticks := 0
	while boss.etat == boss.Etat.REPOS and ticks < 600:
		await physics_frame
		ticks += 1
	_check(absf(ticks / 60.0 - attendu) < 0.05 and attendu > 3.8,
		"en bataille, la pause du peintre entre deux passages dure deux fois celle du solo (%.2f s, attendu %.2f s)" % [ticks / 60.0, attendu])
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
	GS.configurer_bataille(NB_LIONS)  # les joueurs existent avant la scène : leurs pseudos aussi
	for i in range(NB_LIONS):
		GS.joueurs[i].pseudo = "Joueur %d" % (i + 1)  # pour les captures : chaque lion porte son pseudo
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
		# Avec --captures, ce await supplémentaire décale le pilote d'au moins une frame et gonfle
		# pire_frame_ms : les lignes MESURE d'un passage avec captures ne se comparent pas à
		# celles d'un passage headless.
		for k in range(INSTANTS_CAPTURES.size()):
			if f == int(INSTANTS_CAPTURES[k] * Engine.physics_ticks_per_second):
				await _capturer("bataille_%d" % (k + 1))
		var maintenant := Time.get_ticks_usec()
		pire_frame_ms = maxf(pire_frame_ms, (maintenant - instant) / 1000.0)
		instant = maintenant
	for f in range(5):  # les 90 s de la boucle, comptées d'une image physique : le chrono finit à une image près
		if not GS.partie_en_cours:
			break
		await physics_frame
	_check(not GS.partie_en_cours and GS.temps_ecoule >= ReglesBataille.DUREE_MANCHE and GS.temps_ecoule < ReglesBataille.DUREE_MANCHE + 0.05,
		"le chrono termine la manche à %d s (%.3f s de jeu)" % [int(ReglesBataille.DUREE_MANCHE), GS.temps_ecoule])
	GS.terminer_partie(true)  # sans effet : la manche est déjà finie
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
	for j: Joueur in GS.joueurs:
		j.pseudo = ""


## Passe pleine vitesse d'un lion en vomissant, de la gauche vers x = 1700, à la hauteur de jet
## médiane du pilote de la démo ; puis la gerbe en vol retombe.
func _passe(lion: CharacterBody2D, haut: float) -> void:
	lion.global_position = Vector2(0, haut + HAUTEURS_JET[1])
	lion.commandes.direction_voulue = Vector2.RIGHT
	await _frames(20)  # l'élan : pleine vitesse avant de vomir
	lion.commandes.vomir_voulu = true
	var i := 0
	while lion.global_position.x < 1700.0 and i < 600:  # borné : une régression du déplacement ne bloque pas la suite
		await physics_frame
		i += 1
	_check(i < 600, "la passe atteint x = 1700 sans être bloquée (%d frames)" % i)
	lion.commandes.vomir_voulu = false
	lion.commandes.direction_voulue = Vector2.ZERO
	await _frames(60)


## Sur une ville vierge du niveau, au cran donné : x = cellules que la passe d'un premier lion
## fait compter au territoire, rapportées à celles de la couverture du solo ; y = part de ces
## cellules que la même passe d'un second lion lui vole. Scène propre : une ville, deux lions.
func _mesurer_passe(niveau: int, crans: int) -> Vector2:
	GS.niveau_courant = niveau
	GS.configurer_bataille(2)
	GS.nouvelle_partie()
	GS.pret = true
	var ville: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	root.add_child(ville)
	ville.charger_skyline(load(GS.niveau().texture))
	ville.position = Vector2(TAILLE_BATAILLE.x / 2.0, TAILLE_BATAILLE.y - ville.tex_size.y / 2.0)
	var lions: Array[CharacterBody2D] = []
	for j: Joueur in GS.joueurs:
		for i in range(crans - 1):
			j.gagner_cran()
		var l: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
		l.joueur = j
		l.commandes = Commandes.manuelles()
		l.position = Vector2.ZERO  # en haut à gauche, loin de la bande peinte
		root.add_child(l)
		lions.append(l)
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	var t: Territoire = ville.territoire
	await _passe(lions[0], haut)
	ville.mesurer_progression()
	var cellules_a := t.cellules_de(0)
	var rapport := float(cellules_a) / maxi(ville.cellules_peintes, 1)
	lions[0].global_position = Vector2.ZERO
	await _passe(lions[1], haut)
	var part_volee := float(GS.joueurs[1].cellules_volees) / maxi(cellules_a, 1)
	print("  MESURE niveau %d, rayon %d : territoire %d / couverture %d = %.2f ; volées par une passe : %d (%.0f %%)"
		% [niveau, int(lions[0].gerbe.traceuse_shape.shape.radius), cellules_a, ville.cellules_peintes, rapport,
			GS.joueurs[1].cellules_volees, 100.0 * part_volee])
	for l in lions:
		l.free()
	ville.free()
	return Vector2(rapport, part_volee)


func _tester_reglage_territoire() -> void:
	print("-- Réglage du territoire sur une passe pleine vitesse")
	# Les motifs des tampons (couverture du solo) suivent le hasard global : semé ici, cette mesure ne
	# dépend plus de ce que les sections d'avant ont tiré (phase 17 : la section du rythme des pastilles
	# l'avait poussée de 1,22 à 1,29, près de la borne de 1,3)
	seed(20260925)
	root.content_scale_size = Vector2i(TAILLE_BATAILLE)  # l'écran d'une bataille (sans Main dans cette section)
	var rapport_min := INF
	var rapport_max := 0.0
	var part_volee_min := INF
	for niveau in range(GS.NIVEAUX.size()):
		for crans in [1, 2, 4, 7]:
			var mesure := await _mesurer_passe(niveau, crans)
			rapport_min = minf(rapport_min, mesure.x)
			rapport_max = maxf(rapport_max, mesure.x)
			part_volee_min = minf(part_volee_min, mesure.y)
	_check(rapport_min >= CIBLE_RAPPORT_COUVERTURE.x and rapport_max <= CIBLE_RAPPORT_COUVERTURE.y,
		"une passe fait compter au territoire à peu près les cellules que compterait la couverture du solo (%.2f à %.2f, cible %.1f à %.1f)"
			% [rapport_min, rapport_max, CIBLE_RAPPORT_COUVERTURE.x, CIBLE_RAPPORT_COUVERTURE.y])
	_check(part_volee_min >= CIBLE_PART_VOLEE,
		"une passe pleine vitesse vole au moins %.0f %% des cellules d'un adversaire, dès le premier cran (%.0f %%)"
			% [100.0 * CIBLE_PART_VOLEE, 100.0 * part_volee_min])


func _tester_pseudos_et_chocs() -> void:
	print("-- Pseudos et chocs")
	GS.configurer_bataille(NB_LIONS)  # les joueurs existent avant la scène : leurs pseudos aussi
	for i in range(NB_LIONS):
		GS.joueurs[i].pseudo = "" if i == 3 else "Joueur %d" % (i + 1)
	GS.joueurs[2].pseudo = "WWWWWWWWWWWW"  # 12 caractères larges (Reseau.PSEUDO_MAX), plus large que son lion
	var main := await _charger_bataille(0)
	var lions: Array = main.lions
	await _attendre_depart()
	# Un lion qui monte tout en haut de l'écran garde son pseudo visible ; sans pseudo, il monte jusqu'au bord
	for i in [1, 3]:
		lions[i].commandes.direction_voulue = Vector2.UP
	await _frames(90)
	var etiquette: Label = lions[1].etiquette_pseudo
	_check(etiquette.visible and etiquette.get_global_rect().position.y >= -0.5,
		"un lion collé en haut de l'écran n'y cache pas son pseudo (haut de l'étiquette à %.1f px)" % etiquette.get_global_rect().position.y)
	_check(absf(etiquette.get_global_rect().position.y) <= 0.5,
		"le lion est bien pressé contre sa borne, pas bridé bien plus bas (haut de l'étiquette à %.1f px)" % etiquette.get_global_rect().position.y)
	_check(not lions[3].etiquette_pseudo.visible and lions[3].global_position.y == 0.0,
		"un lion sans pseudo monte jusqu'au bord de l'écran")
	for i in [1, 3]:
		lions[i].commandes.direction_voulue = Vector2.ZERO

	# Deux chocs à 0,5 s de jeu d'écart comptent tous les deux (délai anti-rafale : 0,3 s de jeu).
	# En --fixed-fps, 0,5 s de jeu passent en quelques millisecondes : un délai mesuré à
	# l'horloge murale bloquait le second.
	var l1: CharacterBody2D = lions[1]
	var l2: CharacterBody2D = lions[2]
	var j1: Joueur = GS.joueurs[1]
	var j2: Joueur = GS.joueurs[2]
	for essai in range(2):
		for l: CharacterBody2D in [l1, l2]:
			l.deplacement.recul = Vector2.ZERO
			l.deplacement.vitesse = Vector2.ZERO
		l1.global_position = Vector2(600, 400)
		l2.global_position = Vector2(800, 400)
		await _frames(2)
		l1.commandes.direction_voulue = Vector2.RIGHT
		for i in range(90):
			await physics_frame
			if j1.chocs > essai:
				break
		l1.commandes.direction_voulue = Vector2.ZERO
		await _frames(30)
	_check(j1.chocs == 2 and j2.chocs == 2, "deux chocs à une demi-seconde de jeu d'écart comptent tous les deux (%d, %d)" % [j1.chocs, j2.chocs])

	# Phase 17 : deux lions côte à côte (sans se toucher) contre chaque bord, dont un pseudo large : leurs
	# pseudos s'écartent sans se recouvrir, dans l'écran
	for bord in ["gauche", "droit"]:
		for l: CharacterBody2D in [l1, l2]:
			l.deplacement.recul = Vector2.ZERO
			l.deplacement.vitesse = Vector2.ZERO
		var x1 := 0.0 if bord == "gauche" else TAILLE_BATAILLE.x - 236.0
		l1.global_position = Vector2(x1, 400)
		l2.global_position = Vector2(x1 + 100.0, 400)
		await _frames(2)
		var a := _texte_pseudo(l1)
		var b := _texte_pseudo(l2)
		_check(a.position.x >= -0.5 and b.end.x <= TAILLE_BATAILLE.x + 0.5 and a.end.x + 5.5 <= b.position.x,
			"bord %s : deux pseudos voisins s'écartent sans se recouvrir, dans l'écran (%.0f à %.0f, puis %.0f à %.0f)"
				% [bord, a.position.x, a.end.x, b.position.x, b.end.x])

	# I1 (revue finale phase 17) : à distance de contact (92 px de centre à centre, deux lions qui se
	# frôlent), le pseudo large (WWWWWWWWWWWW) doit rester sur son propre lion, jamais basculé sur son
	# voisin à pseudo court, que le lion large soit à droite ou à gauche (tri par centre, pas par bord
	# gauche : PlacementPseudos.repartir). Le pseudo court est raccourci à « Al » pour cette section (la
	# vraie scène qui a révélé le bogue) : à 105 px (« Joueur 2 »), la marge à cette distance ne mord pas.
	var pseudo_court_avant: String = l1.etiquette_pseudo.text
	l1.etiquette_pseudo.text = "Al"
	for large_a_droite in [true, false]:
		for l: CharacterBody2D in [l1, l2]:
			l.deplacement.recul = Vector2.ZERO
			l.deplacement.vitesse = Vector2.ZERO
		var x_court := 900.0 if large_a_droite else 992.0
		var x_large := 992.0 if large_a_droite else 900.0
		l1.global_position = Vector2(x_court, 400)  # "Al" : pseudo court
		l2.global_position = Vector2(x_large, 400)  # "WWWWWWWWWWWW" : pseudo large
		await _frames(2)
		var court := _texte_pseudo(l1)
		var large := _texte_pseudo(l2)
		if large_a_droite:
			_check(court.end.x + 5.5 <= large.position.x,
				"à distance de contact (92 px), le pseudo large reste à droite, sur son lion (court %.0f à %.0f, large %.0f à %.0f)"
					% [court.position.x, court.end.x, large.position.x, large.end.x])
		else:
			_check(large.end.x + 5.5 <= court.position.x,
				"à distance de contact (92 px), le pseudo large reste à gauche, sur son lion (large %.0f à %.0f, court %.0f à %.0f)"
					% [large.position.x, large.end.x, court.position.x, court.end.x])
	l1.etiquette_pseudo.text = pseudo_court_avant
	# Le pseudo suit le lion affiché (le décalage de la prédiction d'un client), pas son seul corps
	var avant: Rect2 = l1.rect_pseudo()
	l1.visuel.position = Vector2(40, -10)
	var decale: Rect2 = l1.rect_pseudo()
	l1.visuel.position = Vector2.ZERO
	_check(decale.position - avant.position == Vector2(40, -10), "le pseudo suit la position affichée du lion (corps et décalage d'affichage)")
	await _liberer(main)
	for j: Joueur in GS.joueurs:
		j.pseudo = ""


## Phase 17 : le HUD de la bataille, à la place de celui du solo (vignettes, scores lus sur le
## territoire, crans, gerbe XXL, étourdissement, départ), le chrono qui rougit et tique, la fin au
## chrono et sa sortie (Échap : le titre).
func _tester_hud() -> void:
	print("-- HUD de la bataille")
	var main := await _charger_bataille(0)
	var hud: CanvasLayer = main.hud_bataille
	var ville: Node2D = main.get_node("Ville")
	var t: Territoire = ville.territoire
	_check(hud != null and main.get_node_or_null("HUD") == null and hud.vignettes.size() == NB_LIONS
		and hud.gauche.get_child_count() == NB_LIONS / 2 and hud.droite.get_child_count() == NB_LIONS / 2,
		"en bataille, le HUD de la bataille remplace celui du solo : une vignette par joueur, moitié de chaque côté du chrono")
	_check(range(NB_LIONS).all(func(i: int) -> bool: return hud.vignettes[i].pseudo.text == "Joueur %d" % (i + 1)),
		"sans pseudo (bataille locale), chaque vignette porte « Joueur n »")
	var pseudo: Label = hud.vignettes[0].pseudo
	var largeur_w: float = pseudo.get_theme_font("font").get_string_size("WWWWWWWWWWWW", HORIZONTAL_ALIGNMENT_LEFT, -1,
		pseudo.get_theme_font_size("font_size")).x + 2 * pseudo.get_theme_constant("outline_size")
	var rangee_a_6: float = 6 * hud.vignettes[0].cadre.size.x + hud.chrono.size.x + 7 * hud.get_node("Haut").get_theme_constant("separation") + 24.0
	_check(largeur_w <= pseudo.size.x and rangee_a_6 <= TAILLE_BATAILLE.x,
		"12 caractères larges (« WWWWWWWWWWWW », %d px) tiennent dans une vignette (%d px) ; six vignettes et le chrono dans l'écran (%d px)"
			% [largeur_w, pseudo.size.x, rangee_a_6])
	_check(hud.vignettes[0].badge.text == "TOI" and hud.vignettes[0].style.border_width_top == 6
		and range(1, NB_LIONS).all(func(i: int) -> bool: return hud.vignettes[i].badge.text == "" and hud.vignettes[i].style.border_width_top == 3),
		"la vignette du joueur de ce poste est mise en évidence : « TOI », bordure épaisse")
	_check(hud.chrono.text == "1:30" and not hud.vignettes.any(func(v: Dictionary) -> bool: return v.couronne.visible or v.rang.text != ""),
		"au départ : 1:30, personne n'est classé ni couronné")
	await _attendre_depart()
	var bas: float = ville.position.y + ville.tex_size.y / 2.0 - 30.0
	for k in range(3):
		ville.peindre(Vector2(500, bas), 30, GS.joueurs[1])
	await _frames(1)
	var n1 := t.cellules_de(1)
	_check(n1 > 0 and hud.vignettes[1].part.text == "100 %" and hud.vignettes[0].part.text == "0 %" and hud.vignettes[1].rang.text == "1er"
		and hud.vignettes[1].couronne.visible and not hud.vignettes[0].couronne.visible and hud.vignettes[0].rang.text == "",
		"le HUD lit les scores sur le territoire de la ville : le joueur 2, seul peintre, a 100 %% des cellules peintes (%d), il mène, couronné" % n1)
	_check(hud.vignettes[1].couronne.get_parent() == hud.vignettes[1].lion and hud.vignettes[1].couronne.rotation > 0.2,
		"la couronne est posée de travers sur la tête du lion de la vignette")
	for k in range(3):
		ville.peindre(Vector2(1500, bas), 20, GS.joueurs[3])  # moins de cellules : le joueur 2 mène encore
	await _frames(1)
	var affichees: Array = hud.vignettes.map(func(v: Dictionary) -> int: return int(v.part.text.trim_suffix(" %")))
	var cellules: Array[int] = []
	for i in range(NB_LIONS):
		cellules.append(t.cellules_de(i))
	_check(affichees == ReglesBataille.parts(cellules) and affichees.reduce(func(s: int, n: int) -> int: return s + n, 0) == 100,
		"deux peintres : leurs parts des cellules peintes font 100 %% (%s pour %s cellules)" % [affichees, cellules])
	_check(hud.vignettes[1].couronne.visible and not hud.vignettes[3].couronne.visible and hud.vignettes[3].rang.text == "2e",
		"le rang et la couronne viennent des cellules : le joueur 2 mène, le joueur 4 est deuxième")
	GS.regles.pastille_ramassee(GS.joueurs[1], 0)
	GS.regles.pastille_ramassee(GS.joueurs[1], 0)
	GS.regles.etoile_ramassee(GS.joueurs[2])
	GS.regles.lion_touche_par_ennemi(GS.joueurs[3], Vector2.INF)
	await _frames(1)
	var pleins: Array = hud.vignettes[1].points.filter(func(p: Panel) -> bool: return p.modulate == Color.WHITE)
	_check(pleins.size() == 3, "trois crans : trois points pleins sur sept")
	_check(hud.vignettes[2].etat.text == "★ XXL 8 s" and hud.vignettes[3].etat.text == "★ ÉTOURDI",
		"la gerbe XXL et ses secondes, l'étourdissement (%s, %s)" % [hud.vignettes[2].etat.text, hud.vignettes[3].etat.text])
	# Comme sur un client : `bonus_restant` y reste la durée reçue (seule la fin arrive de l'hôte)
	for f in range(61):
		GS.joueurs[2].bonus_restant = 8.0
		await physics_frame
	_check(hud.vignettes[2].etat.text == "★ XXL 7 s", "le HUD décompte lui-même les secondes de la gerbe XXL (%s)" % hud.vignettes[2].etat.text)
	# M2 (revue finale phase 17) : une deuxième étoile en pleine gerbe XXL recale le décompte affiché
	# du HUD (`bonus_dure`), pas seulement la vraie durée de `Joueur.bonus_restant`
	GS.regles.etoile_ramassee(GS.joueurs[2])
	await _frames(1)
	_check(hud.vignettes[2].etat.text == "★ XXL 8 s",
		"M2 : une deuxième étoile en pleine gerbe XXL recale le décompte du HUD à la nouvelle durée (%s)" % hud.vignettes[2].etat.text)
	GS.joueurs[2].recevoir_fin_bonus()
	hud.marquer_parti(3)
	await _frames(1)
	_check(hud.vignettes[2].etat.text == "", "la fin de la gerbe XXL efface ses secondes")
	_check(hud.vignettes[3].cadre.modulate.a < 0.5 and hud.vignettes[3].badge.text == "PARTI", "un joueur parti reste au classement, en grisé")
	_check(hud.texte_gagnant(PackedStringArray()) == "Personne n'a peint la ville." and hud.texte_gagnant(PackedStringArray(["Zoé"])) == "Zoé gagne la manche !"
		and hud.texte_gagnant(PackedStringArray(["Anna", "Bruno"])) == "Égalité : Anna, Bruno !",
		"le panneau de fin nomme le gagnant, les ex æquo, ou personne")
	# Les dix dernières secondes : le chrono rougit et tique, jusqu'à la fin au chrono
	GS.temps_ecoule = ReglesBataille.DUREE_MANCHE - 10.5
	await _frames(1)
	var tics_avant: int = hud.tics_joues
	_check(hud.chrono.text == "0:11" and hud.chrono.modulate == Color.WHITE and root.get_node("Audio").intensite == 2,
		"à 11 s de la fin, le chrono est encore blanc ; la musique a toutes ses couches depuis 60 s")
	for f in range(900):
		if not GS.partie_en_cours:
			break
		await physics_frame
	_check(not GS.partie_en_cours and paused and GS.temps_ecoule < ReglesBataille.DUREE_MANCHE + 0.05,
		"le chrono à zéro termine la manche et fige tout (%.3f s)" % GS.temps_ecoule)
	_check(hud.tics_joues - tics_avant == ReglesBataille.SECONDES_TIC and hud.chrono.text == "0:00" and hud.chrono.modulate != Color.WHITE,
		"dix tics dans les dix dernières secondes (%d), le chrono rouge à 0:00" % (hud.tics_joues - tics_avant))
	_check(hud.fin.visible and hud.gagnant.text == "Joueur 2 gagne la manche !" and not main.menu_pause.visible
		and main.menu_pause.process_mode == Node.PROCESS_MODE_DISABLED,
		"le panneau de fin nomme le gagnant (%s) ; le menu local se tait" % hud.gagnant.text)
	# Espace (vomir, valider) encore tenu au gong ne quitte pas la partie : le bouton ne prend pas le focus
	for action: StringName in [&"vomir", &"ui_accept"]:
		var appui := InputEventAction.new()
		appui.action = action
		appui.pressed = true
		root.push_input(appui)
	await _frames(3)
	_check(current_scene == main and hud.fin.visible and root.gui_get_focus_owner() == null,
		"Espace tenu au gong (vomir, valider) ne quitte pas la partie : rien n'a le focus")
	var scores: Node = root.get_node("Scores")
	scores.chemin = "user://scores_test_bataille.cfg"  # l'écran titre enregistre ses préférences
	var echap := InputEventAction.new()
	echap.action = &"pause"
	echap.pressed = true
	root.push_input(echap)
	for f in range(300):
		if current_scene != null and current_scene.scene_file_path == "res://Scenes/Titre.tscn" and current_scene.is_node_ready():
			break
		await process_frame
	_check(current_scene != null and current_scene.scene_file_path == "res://Scenes/Titre.tscn" and not paused and GS.regles is ReglesSolo,
		"Échap, la manche finie : retour au titre (le solo), en attendant les résultats de la phase 18")
	current_scene.free()
	await _frames(1)
	scores.effacer()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))
	GS.configurer_bataille(NB_LIONS)  # la section suivante part d'une bataille


func _tester_retour_au_titre() -> void:
	print("-- Retour au titre après une bataille")
	var main := await _charger_bataille(0)
	await _liberer(main)
	_check(GS.regles.compte_le_territoire() and root.content_scale_size == Vector2i(TAILLE_BATAILLE),
		"(pré-condition) une bataille vient de se jouer, en 16:9")
	var scores: Node = root.get_node("Scores")
	scores.chemin = "user://scores_test_bataille.cfg"  # l'écran titre enregistre ses préférences
	scores.effacer()
	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	_check(GS.regles is ReglesSolo and GS.joueurs.size() == 1 and not GS.joueur_local().a_une_couleur(),
		"l'écran titre remet le solo avant toute partie : ses règles, un seul joueur, sans couleur")
	_check(root.get_visible_rect().size == Vector2(2000, 648), "l'écran titre est en 2000×648")
	titre.free()
	scores.effacer()


## Le texte du pseudo d'un lion tel qu'il s'affiche, en pixels de l'écran : l'étiquette est plus large
## que son texte, centré.
func _texte_pseudo(lion: Node2D) -> Rect2:
	var etiquette: Label = lion.etiquette_pseudo
	var boite := etiquette.get_global_rect()
	var texte := etiquette.get_minimum_size().x
	return Rect2(boite.position.x + (boite.size.x - texte) / 2.0, boite.position.y, texte, boite.size.y)


## Avec le rendu et `--captures=<dossier>` seulement : en headless, le viewport n'a pas d'image.
func _capturer(nom: String) -> void:
	if _dossier_captures.is_empty():
		return
	await RenderingServer.frame_post_draw
	var chemin := _dossier_captures.path_join(nom + ".png")
	root.get_texture().get_image().save_png(chemin)
	print("  📸 ", chemin)
