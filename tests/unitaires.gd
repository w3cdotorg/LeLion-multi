extends SceneTree
## Tests unitaires headless : godot --headless --script tests/unitaires.gd
## Logique pure (Joueur, puis territoire, couleurs, protocole…), sans charger de scène de jeu.

var _echecs := 0


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _run() -> void:
	print("== tests unitaires LeLion ==")
	_tester_joueur()
	_tester_game_state()
	_tester_commandes()
	_tester_regles_solo()
	_tester_regles_bataille()
	_tester_delegation_regles()
	_tester_modes()
	_tester_facade_retiree()
	_tester_territoire()
	_tester_reseau()
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _tester_joueur() -> void:
	print("-- Joueur")
	var j := Joueur.new()
	j.reinitialiser(3)
	_check(j.vies == 3 and j.coups_recus == 0 and j.couleurs_debloquees.is_empty(), "un joueur réinitialisé a ses vies et aucune couleur")

	# Couleurs
	var recues: Array[Color] = []
	j.couleur_debloquee.connect(func(c: Color) -> void: recues.append(c))
	_check(j.debloquer_couleur(Color.RED), "débloquer une couleur nouvelle renvoie true")
	_check(not j.debloquer_couleur(Color.RED), "débloquer deux fois la même couleur renvoie false")
	_check(j.couleurs_debloquees == [Color.RED] and recues == [Color.RED], "la couleur est ajoutée et signalée une seule fois")

	# Coups : ordre des signaux, invulnérabilité, coup fatal
	var journal: Array[String] = []
	j.vies_changees.connect(func(v: int) -> void: journal.append("vies:%d" % v))
	j.touche.connect(func(o: Vector2) -> void: journal.append("touche:%d,%d" % [int(o.x), int(o.y)]))
	_check(j.encaisser_coup(Vector2(10, 20), 1.5) == 2, "un coup renvoie les vies restantes (2)")
	_check(journal == ["vies:2", "touche:10,20"], "ordre des signaux : vies_changees puis touche (%s)" % [journal])
	_check(j.est_invulnerable() and is_equal_approx(j.invulnerable_restant, 1.5) and j.coups_recus == 1, "après un coup : invulnérable 1,5 s, un coup compté")
	j.avancer(1.0)
	_check(is_equal_approx(j.invulnerable_restant, 0.5), "avancer décompte l'invulnérabilité")
	j.avancer(2.0)
	_check(j.invulnerable_restant == 0.0 and not j.est_invulnerable(), "l'invulnérabilité s'arrête à zéro, jamais en négatif")
	journal.clear()
	j.vies = 1
	_check(j.encaisser_coup(Vector2.INF, 1.5) == 0, "le dernier coup renvoie 0")
	_check(journal == ["vies:0"], "le coup fatal n'émet pas touche (%s)" % [journal])
	_check(not j.est_invulnerable(), "le coup fatal ne rend pas invulnérable")

	# Vies
	j.reinitialiser(3)
	_check(not j.gagner_vie(3), "impossible de dépasser le maximum de vies")
	j.vies = 2
	_check(j.gagner_vie(3) and j.vies == 3, "gagner une vie sous le maximum")

	# Bonus : une émission à l'activation, une à l'expiration
	var bonus: Array[bool] = []
	j.bonus_change.connect(func(actif: bool) -> void: bonus.append(actif))
	j.activer_bonus(8.0)
	j.activer_bonus(4.0)
	_check(bonus == [true] and is_equal_approx(j.bonus_restant, 8.0), "prolonger un bonus actif ne réémet pas et garde la durée la plus longue")
	j.avancer(7.9)
	_check(j.bonus_actif() and bonus == [true], "le bonus est encore actif avant son terme")
	j.avancer(0.2)
	_check(not j.bonus_actif() and j.bonus_restant == 0.0 and bonus == [true, false], "le bonus expire et le signale une fois")
	j.avancer(1.0)
	_check(bonus == [true, false], "pas de nouvelle émission après l'expiration")

	# Réinitialiser en plein bonus : silencieux (le lion est recréé par la nouvelle partie)
	j.activer_bonus(8.0)
	j.debloquer_couleur(Color.BLUE)
	bonus.clear()
	recues.clear()
	journal.clear()
	j.reinitialiser(1)
	_check(bonus.is_empty() and recues.is_empty() and journal.is_empty(), "reinitialiser n'émet aucun signal")
	_check(j.vies == 1 and not j.bonus_actif() and j.couleurs_debloquees.is_empty() and j.coups_recus == 0,
		"reinitialiser remet vies, bonus, couleurs et coups à l'état de départ")

	# Crans de gerbe : de 1 à CRANS_MAX, signalés
	var crans_recus: Array[int] = []
	j.crans_changes.connect(func(c: int) -> void: crans_recus.append(c))
	_check(j.crans == 1, "un joueur réinitialisé a un cran de gerbe")
	for i in range(Joueur.CRANS_MAX - 1):
		j.gagner_cran()
	_check(j.crans == Joueur.CRANS_MAX and crans_recus == [2, 3, 4, 5, 6, 7], "chaque cran gagné est signalé, jusqu'à 7 (%s)" % [crans_recus])
	_check(not j.gagner_cran() and j.crans == Joueur.CRANS_MAX and crans_recus.size() == 6, "au maximum, un cran de plus est refusé sans signal")

	# Nuances de la gerbe de bataille
	j.couleur = Color(0.16, 0.39, 0.95)
	var n: Array[Color] = j.nuances()
	_check(n.size() == 3 and n[1] == j.couleur and n[0].get_luminance() < n[1].get_luminance()
		and n[2].get_luminance() > n[1].get_luminance() and n.all(func(c: Color) -> bool: return c.a == 1.0),
		"trois nuances opaques : foncée, la couleur du joueur, claire")

	# Étourdissement puis immunité : une seule minuterie de protection
	var etourdissements: Array[String] = []
	j.etourdi.connect(func(o: Vector2, b: Color) -> void: etourdissements.append("etourdi:%d,%d:%s" % [int(o.x), int(o.y), b.to_html()]))
	j.etourdissement_fini.connect(func() -> void: etourdissements.append("fini"))
	j.etourdir(1.5, 1.0, Vector2(5, 6), Color.RED)
	_check(etourdissements == ["etourdi:5,6:%s" % Color.RED.to_html()], "etourdir signale l'origine et la couleur du barbouillage (%s)" % [etourdissements])
	_check(j.est_etourdi() and is_equal_approx(j.etourdi_restant, 1.5) and j.est_invulnerable() and is_equal_approx(j.invulnerable_restant, 2.5),
		"étourdi 1,5 s, et invulnérable pendant l'étourdissement puis 1 s d'immunité")
	j.avancer(1.0)
	_check(j.est_etourdi() and etourdissements.size() == 1, "l'étourdissement dure encore")
	j.avancer(0.6)
	_check(not j.est_etourdi() and j.etourdi_restant == 0.0 and etourdissements.back() == "fini",
		"la fin de l'étourdissement est signalée, jamais en négatif")
	_check(j.est_invulnerable() and is_equal_approx(j.invulnerable_restant, 0.9), "puis l'immunité continue seule (0,9 s restantes)")
	j.avancer(1.0)
	_check(not j.est_invulnerable() and etourdissements.size() == 2, "l'immunité s'arrête, la fin n'est signalée qu'une fois")

	# Réinitialiser : crans, étourdissement et statistiques repartent de zéro, en silence
	j.gagner_cran()
	j.etourdir(1.5, 1.0, Vector2.ZERO, Color.TRANSPARENT)
	j.etourdissements_infliges = 2
	j.cellules_volees = 30
	j.chocs = 4
	crans_recus.clear()
	etourdissements.clear()
	j.reinitialiser(3)
	_check(j.crans == 1 and not j.est_etourdi() and not j.est_invulnerable() and j.etourdissements_infliges == 0
		and j.cellules_volees == 0 and j.chocs == 0 and crans_recus.is_empty() and etourdissements.is_empty(),
		"reinitialiser remet crans, étourdissement et statistiques à zéro sans signal")
	j.reinitialiser(3, j.nuances())
	_check(j.couleurs_debloquees == j.nuances() and recues.is_empty(), "reinitialiser peut donner des couleurs de départ, sans les signaler")
	var avant: Array[Color] = j.couleurs_debloquees
	j.reinitialiser(3)
	_check(j.couleurs_debloquees.is_empty() and is_same(avant, j.couleurs_debloquees),
		"les couleurs sont remises à zéro en place (le tableau lu par le lion et le HUD reste le même)")


func _tester_game_state() -> void:
	print("-- GameState (état de partie)")
	var gs: Node = root.get_node("GameState")
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	_check(gs.joueurs.size() == 1 and gs.joueur_local() == gs.joueurs[0], "en solo, un seul joueur, qui est le joueur local")
	var j: Joueur = gs.joueur_local()
	_check(j.vies == 3, "nouvelle_partie donne au joueur les vies de la difficulté")

	# Les minuteries du joueur ne tournent qu'en partie, une fois prêt
	j.bonus_restant = 0.5
	j.invulnerable_restant = 0.25
	gs.pret = false
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.25) and is_equal_approx(j.bonus_restant, 0.5), "pendant l'intro, les minuteries ne décomptent pas")
	gs.pret = true
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.05) and is_equal_approx(j.bonus_restant, 0.3), "une fois prêt, GameState fait avancer le joueur")
	gs.terminer_partie(false)
	j.invulnerable_restant = 0.4
	j.bonus_restant = 0.6
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.4) and is_equal_approx(j.bonus_restant, 0.6),
		"après la fin de partie, les minuteries ne décomptent plus")

	# Nouvelle partie : repart de zéro
	j.activer_bonus(8.0)
	j.coups_recus = 2
	gs.nouvelle_partie()
	_check(j.couleurs_debloquees.is_empty() and j.vies == 3 and j.coups_recus == 0 and not j.bonus_actif(),
		"nouvelle_partie remet le joueur local à zéro")
	gs.partie_en_cours = false
	gs.pret = false


func _tester_commandes() -> void:
	print("-- Commandes")
	var m := Commandes.manuelles()
	_check(m.source == Commandes.Source.MANUELLES and m.direction() == Vector2.ZERO and not m.vomir(),
		"des commandes manuelles neuves sont au repos")
	m.direction_voulue = Vector2(0.6, -0.8)
	m.vomir_voulu = true
	_check(m.direction() == Vector2(0.6, -0.8) and m.vomir(), "les commandes manuelles renvoient ce qu'on y écrit")

	var l := Commandes.locales()
	_check(l.source == Commandes.Source.LOCALES, "Commandes.locales() crée des commandes locales")
	_check(l.direction() == Vector2.ZERO and not l.vomir(), "sans action pressée, les commandes locales sont au repos")
	Input.action_press("deplacer_droite")
	Input.action_press("vomir")
	_check(l.direction().x > 0.99 and absf(l.direction().y) < 0.01 and l.vomir(), "les commandes locales lisent les actions de ce poste")
	m.direction_voulue = Vector2.ZERO
	m.vomir_voulu = false
	_check(m.direction() == Vector2.ZERO and not m.vomir(), "les commandes manuelles ignorent le clavier et la manette")
	l.direction_voulue = Vector2.LEFT
	_check(l.direction().x > 0.99, "écrire direction_voulue ne change pas des commandes locales")
	Input.action_release("deplacer_droite")
	Input.action_release("vomir")
	_check(l.direction() == Vector2.ZERO and not l.vomir(), "relâcher les actions remet les commandes locales au repos")
	m.direction_voulue = Vector2(3, 4)
	_check(is_equal_approx(m.direction().length(), 1.0) and m.direction().is_equal_approx(Vector2(0.6, 0.8)),
		"direction() borne les commandes manuelles à une longueur de 1")


func _tester_regles_solo() -> void:
	print("-- Règles")
	var gs: Node = root.get_node("GameState")
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	gs.pret = true

	# Règles de base : aucun effet
	var base := Regles.new(gs)
	var j := Joueur.new()
	j.reinitialiser(3)
	base.lion_touche_par_ennemi(j, Vector2.ZERO)
	base.etoile_ramassee(j)
	base.progression_mesuree(1.0)
	_check(j.vies == 3 and not j.bonus_actif() and not base.pastille_ramassee(j, 0)
		and j.couleurs_debloquees.is_empty() and fins.is_empty(), "les règles de base n'ont aucun effet")
	j.vies = 2
	_check(not base.coeur_ramasse(j) and j.vies == 2, "coeur_ramasse des règles de base n'a aucun effet, même sous le maximum")
	j.vies = 3
	var autre := Joueur.new()
	autre.reinitialiser(3)
	base.lion_touche_par_vomi(j, autre, Vector2.ZERO)
	base.choc_entre_lions(j, autre)
	base.vol_de_cellules(j, 4)
	_check(base.couleurs_de_depart(j).is_empty() and not j.est_etourdi() and not j.est_invulnerable()
		and autre.etourdissements_infliges == 0 and j.chocs == 0 and autre.chocs == 0 and j.cellules_volees == 0,
		"sans règles de mode, ni couleur de départ, ni effet du vomi, des chocs ou des vols")
	_check(not base.compte_le_territoire() and not ReglesSolo.new(gs).compte_le_territoire(),
		"ni les règles de base ni celles du solo ne se jouent au territoire")
	_check(base.pastille_a_offrir() == -1 and not base.etoile_peut_apparaitre() and not base.coeurs_en_jeu()
		and not base.coeur_peut_apparaitre() and base.avancement() == 0.0 and base.taille_ecran() == Regles.TAILLE_ECRAN_SOLO,
		"les règles de base ne font rien apparaître, rien n'accélère, l'écran est celui du solo (2000×648)")
	_check(base.has_method("manche_en_cours") and not base.has_method("_manche_en_cours"),
		"manche_en_cours() est publique : la ville la lit")

	# Règles solo : elles agissent sur le joueur reçu, pas sur le joueur local
	var r := ReglesSolo.new(gs)
	var local: Joueur = gs.joueur_local()
	var touches_locales: Array[Vector2] = []
	var sur_touche_locale := func(o: Vector2) -> void: touches_locales.append(o)
	local.touche.connect(sur_touche_locale)
	r.lion_touche_par_ennemi(j, Vector2(3, 4))
	_check(j.vies == 2 and j.est_invulnerable() and local.vies == 3 and touches_locales.is_empty(),
		"un coup d'ennemi touche le joueur reçu, pas le joueur local, et ne lui signale aucun coup")
	local.touche.disconnect(sur_touche_locale)
	r.lion_touche_par_ennemi(j, Vector2(3, 4))
	_check(j.vies == 2, "pas de coup pendant l'invulnérabilité")
	j.invulnerable_restant = 0.0
	gs.pret = false
	r.lion_touche_par_ennemi(j, Vector2(3, 4))
	_check(j.vies == 2, "pas de coup pendant l'intro")
	gs.pret = true

	# Pastilles, étoile, cœur
	_check(r.pastille_ramassee(j, 2) and j.couleurs_debloquees == [gs.couleur(2)], "une pastille débloque sa couleur de l'arc-en-ciel chez le joueur reçu")
	_check(j.crans == 2, "en solo, chaque nouvelle couleur donne aussi un cran de gerbe")
	_check(not r.pastille_ramassee(j, 2) and j.crans == 2, "une couleur déjà débloquée n'a pas d'effet, pas même un cran")
	_check(not r.pastille_ramassee(j, -1) and not r.pastille_ramassee(j, gs.nb_couleurs_total()) and j.couleurs_debloquees.size() == 1
		and j.crans == 2, "un index de couleur hors bornes est refusé")
	var toutes := Joueur.new()
	toutes.reinitialiser(3)
	for i in range(gs.nb_couleurs_total()):
		r.pastille_ramassee(toutes, i)
	_check(toutes.couleurs_debloquees.size() == 7 and toutes.crans == Joueur.CRANS_MAX,
		"les sept couleurs débloquées, la gerbe plafonne à son dernier cran (7)")
	r.etoile_ramassee(j)
	_check(j.bonus_actif() and is_equal_approx(j.bonus_restant, Regles.DUREE_ETOILE), "l'étoile active la gerbe XXL pour DUREE_ETOILE secondes")
	_check(r.coeur_ramasse(j) and j.vies == 3, "un cœur rend une vie")
	_check(not r.coeur_ramasse(j) and j.vies == gs.VIES_MAX, "un cœur ne dépasse pas le maximum de vies")

	# Apparitions du solo : elles suivent le joueur local, l'unique joueur (lues par le Spawner)
	local.reinitialiser(3)
	_check(r.pastille_a_offrir() == 0 and not r.etoile_peut_apparaitre(),
		"sans couleur, la prochaine pastille est la première de l'arc-en-ciel ; pas d'étoile")
	local.debloquer_couleur(gs.couleur(0))
	_check(r.pastille_a_offrir() == 1 and not r.etoile_peut_apparaitre(),
		"une couleur : la pastille suivante est la deuxième, toujours pas d'étoile")
	local.debloquer_couleur(gs.couleur(1))
	_check(r.pastille_a_offrir() == 2 and r.etoile_peut_apparaitre(), "dès deux couleurs, l'étoile peut apparaître")
	local.activer_bonus(1.0)
	_check(not r.etoile_peut_apparaitre(), "pas d'étoile pendant une gerbe XXL")
	local.bonus_restant = 0.0
	for i in range(2, gs.nb_couleurs_total() - 1):
		local.debloquer_couleur(gs.couleur(i))
	_check(r.pastille_a_offrir() == gs.nb_couleurs_total() - 1, "six couleurs : la dernière pastille (violet) est encore offerte")
	local.debloquer_couleur(gs.couleur(gs.nb_couleurs_total() - 1))
	_check(r.pastille_a_offrir() == -1, "toutes les couleurs débloquées : plus de pastille à offrir")
	_check(r.coeurs_en_jeu() and not r.coeur_peut_apparaitre(), "en Facile, des cœurs, mais aucun tant que le joueur a toutes ses vies")
	local.vies = 2
	_check(r.coeur_peut_apparaitre(), "un cœur peut apparaître dès qu'une vie manque")
	gs.difficulte_courante = 1
	var sans_coeur_moyen := not r.coeurs_en_jeu()
	gs.difficulte_courante = 2
	_check(sans_coeur_moyen and not r.coeurs_en_jeu(), "ni en Moyen ni en Hardcore")
	gs.difficulte_courante = 0
	local.reinitialiser(3)
	gs.progression = 0.425
	_check(is_equal_approx(r.avancement(), 0.5), "l'avancement du solo est la ville peinte rapportée au seuil (0,425 / 0,85)")
	gs.progression = 0.9
	_check(r.avancement() > 1.0, "au-delà du seuil, l'avancement dépasse 1 (les appelants le bornent)")
	gs.progression = 0.0
	_check(r.taille_ecran() == Vector2i(2000, 648), "l'écran du solo reste en 2000×648")

	# Progression : victoire au seuil, une seule fois
	r.progression_mesuree(gs.seuil_victoire() - 0.01)
	_check(fins.is_empty() and gs.partie_en_cours, "sous le seuil, la partie continue")
	r.progression_mesuree(gs.seuil_victoire())
	_check(fins == [true] and not gs.partie_en_cours, "au seuil de la difficulté, la partie est gagnée")
	r.progression_mesuree(1.0)
	_check(fins == [true], "la victoire n'est signalée qu'une fois")

	# Coup fatal : défaite, et plus aucun coup ensuite
	gs.nouvelle_partie()
	gs.pret = true
	fins.clear()
	j.reinitialiser(1)
	r.lion_touche_par_ennemi(j, Vector2.INF)
	_check(j.vies == 0 and fins == [false] and not gs.partie_en_cours, "le dernier coup termine la partie en défaite")
	r.lion_touche_par_ennemi(j, Vector2.INF)
	_check(j.vies == 0 and fins == [false], "après la fin de partie, un lion à 0 vie n'est plus frappé")

	gs.partie_terminee.disconnect(sur_fin)
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false


func _tester_regles_bataille() -> void:
	print("-- Règles de bataille")
	var gs: Node = root.get_node("GameState")
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	gs.pret = true
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)
	var r := ReglesBataille.new(gs)
	var rouge := Joueur.new()
	rouge.couleur = Color(0.90, 0.16, 0.16)
	var bleu := Joueur.new()
	bleu.couleur = Color(0.16, 0.39, 0.95)
	for j: Joueur in [rouge, bleu]:
		j.reinitialiser(3, r.couleurs_de_depart(j))
	_check(rouge.couleurs_debloquees == rouge.nuances() and bleu.couleurs_debloquees == bleu.nuances(),
		"en bataille, chaque joueur vomit dès le départ dans ses trois nuances")
	var barbouillages: Array[Color] = []
	bleu.etourdi.connect(func(_o: Vector2, b: Color) -> void: barbouillages.append(b))

	# Vomi : 1,5 s d'étourdissement, barbouillé de la couleur de l'agresseur, puis 1 s d'immunité
	r.lion_touche_par_vomi(bleu, rouge, Vector2(7, 8))
	_check(bleu.est_etourdi() and is_equal_approx(bleu.etourdi_restant, ReglesBataille.DUREE_ETOURDI_VOMI)
		and is_equal_approx(bleu.invulnerable_restant, ReglesBataille.DUREE_ETOURDI_VOMI + ReglesBataille.DUREE_IMMUNITE)
		and barbouillages == [rouge.couleur],
		"le vomi d'un autre lion étourdit 1,5 s, barbouille de la couleur de l'agresseur, puis immunise 1 s")
	_check(rouge.etourdissements_infliges == 1 and bleu.vies == 3 and fins.is_empty(),
		"l'étourdissement compte pour l'agresseur ; aucune vie perdue, la manche continue")
	for i in range(10):
		r.lion_touche_par_vomi(bleu, rouge, Vector2(7, 8))
	_check(barbouillages.size() == 1 and rouge.etourdissements_infliges == 1 and is_equal_approx(bleu.etourdi_restant, ReglesBataille.DUREE_ETOURDI_VOMI),
		"un lion déjà étourdi n'est pas ré-étourdi (contact signalé à chaque frame)")
	bleu.avancer(ReglesBataille.DUREE_ETOURDI_VOMI + 0.1)
	r.lion_touche_par_vomi(bleu, rouge, Vector2(7, 8))
	_check(not bleu.est_etourdi() and bleu.est_invulnerable() and barbouillages.size() == 1 and rouge.etourdissements_infliges == 1,
		"un lion immunisé n'est pas étourdi et ne compte pas")
	bleu.avancer(ReglesBataille.DUREE_IMMUNITE)
	r.lion_touche_par_vomi(rouge, rouge, Vector2.ZERO)
	_check(not rouge.est_etourdi() and rouge.etourdissements_infliges == 1, "son propre vomi n'étourdit pas")
	rouge.etourdir(1.0, 1.0, Vector2.ZERO, Color.TRANSPARENT)
	rouge.etourdi_a_la_frame = Engine.get_physics_frames() - 1  # simule un étourdissement d'une frame passée
	r.lion_touche_par_vomi(bleu, rouge, Vector2.ZERO)
	_check(not bleu.est_etourdi() and rouge.etourdissements_infliges == 1, "un lion étourdi lors d'une frame passée n'étourdit personne")
	rouge.avancer(2.0)

	# Trade tête-à-tête : deux lions se vomissent dessus la même frame, les deux rapports portent
	var a := Joueur.new()
	a.couleur = Color(0.90, 0.16, 0.16)
	var b := Joueur.new()
	b.couleur = Color(0.16, 0.39, 0.95)
	for j: Joueur in [a, b]:
		j.reinitialiser(3, r.couleurs_de_depart(j))
	r.lion_touche_par_vomi(b, a, Vector2.ZERO)
	r.lion_touche_par_vomi(a, b, Vector2.ZERO)
	_check(a.est_etourdi() and b.est_etourdi() and a.etourdissements_infliges == 1 and b.etourdissements_infliges == 1,
		"un trade tête-à-tête dans la même frame étourdit les deux lions (aucun n'est ignoré comme agresseur déjà étourdi)")

	# Ennemis : 2,5 s sans barbouillage, puis 1 s d'immunité ; aucune vie perdue
	for i in range(10):
		r.lion_touche_par_ennemi(bleu, Vector2(1, 2))  # le peintre signale le contact à chaque frame
	_check(bleu.est_etourdi() and is_equal_approx(bleu.etourdi_restant, ReglesBataille.DUREE_ETOURDI_ENNEMI)
		and is_equal_approx(bleu.invulnerable_restant, ReglesBataille.DUREE_ETOURDI_ENNEMI + ReglesBataille.DUREE_IMMUNITE)
		and barbouillages.size() == 2 and barbouillages[1].a == 0.0 and bleu.vies == 3,
		"un ennemi étourdit 2,5 s sans barbouillage (un seul étourdissement pour dix contacts), sans vie perdue")
	bleu.avancer(ReglesBataille.DUREE_ETOURDI_ENNEMI + 0.5)
	r.lion_touche_par_ennemi(bleu, Vector2(1, 2))
	_check(barbouillages.size() == 2, "un ennemi ne ré-étourdit pas un lion immunisé")
	bleu.avancer(1.0)
	gs.pret = false
	r.lion_touche_par_ennemi(bleu, Vector2(1, 2))
	r.lion_touche_par_vomi(bleu, rouge, Vector2.ZERO)
	_check(barbouillages.size() == 2, "rien n'étourdit pendant l'intro")
	gs.pret = true

	# Chocs : comptés des deux côtés, jamais d'étourdissement
	r.choc_entre_lions(rouge, bleu)
	_check(rouge.chocs == 1 and bleu.chocs == 1 and not rouge.est_etourdi() and not bleu.est_etourdi(),
		"un choc compte pour les deux lions et n'étourdit personne")
	r.choc_entre_lions(rouge, rouge)
	_check(rouge.chocs == 1, "un lion ne se choque pas lui-même")

	# Pastilles, étoile, cœur, progression
	_check(r.pastille_ramassee(rouge, 5) and rouge.crans == 2 and rouge.couleurs_debloquees == rouge.nuances(),
		"une pastille donne un cran de gerbe, quelle que soit sa couleur, sans débloquer de couleur")
	for i in range(10):
		r.pastille_ramassee(rouge, 0)
	_check(rouge.crans == Joueur.CRANS_MAX and not r.pastille_ramassee(rouge, 0), "les crans plafonnent à 7")
	r.etoile_ramassee(bleu)
	_check(bleu.bonus_actif() and is_equal_approx(bleu.bonus_restant, Regles.DUREE_ETOILE), "l'étoile XXL est celle du solo (même durée, constante de la base)")
	bleu.vies = 2
	_check(not r.coeur_ramasse(bleu) and bleu.vies == 2, "aucun cœur en bataille")
	r.progression_mesuree(1.0)
	_check(fins.is_empty() and gs.partie_en_cours, "peindre toute la ville ne termine pas la manche (elle finit au chrono)")

	# Territoire : la bataille s'y joue, les vols comptent pour « Le voleur »
	_check(r.compte_le_territoire(), "la bataille se joue au territoire")
	r.vol_de_cellules(rouge, 5)
	r.vol_de_cellules(rouge, 0)
	_check(rouge.cellules_volees == 5 and bleu.cellules_volees == 0, "les cellules volées comptent pour le voleur seul (%d)" % rouge.cellules_volees)
	gs.pret = false
	r.vol_de_cellules(rouge, 2)
	_check(rouge.cellules_volees == 5, "un vol pendant l'intro ne compte pas")
	gs.pret = true

	# Apparitions et écran de la bataille : rien ne dépend du joueur local
	var indices_valides := true
	for i in range(50):
		var k := r.pastille_a_offrir()
		if k < 0 or k >= gs.nb_couleurs_total():
			indices_valides = false
	_check(indices_valides, "une pastille est toujours offerte, d'une couleur valide de l'arc-en-ciel (pour l'œil)")
	var local: Joueur = gs.joueur_local()
	local.reinitialiser(1)
	local.activer_bonus(1.0)
	_check(r.etoile_peut_apparaitre(), "l'étoile peut toujours apparaître, même si le joueur local n'a pas de couleur ou est en gerbe XXL")
	_check(gs.difficulte_courante == 0 and not r.coeurs_en_jeu() and not r.coeur_peut_apparaitre(),
		"aucun cœur en bataille, même en Facile et même quand le joueur local a perdu des vies")
	local.reinitialiser(3)
	gs.temps_ecoule = 45.0
	gs.progression = 1.0
	_check(is_equal_approx(r.avancement(), 0.5) and is_equal_approx(ReglesBataille.DUREE_MANCHE, 90.0),
		"l'avancement de la bataille est le temps de la manche (45 s sur 90), pas la ville peinte")
	gs.temps_ecoule = 0.0
	gs.progression = 0.0
	_check(r.avancement() == 0.0, "au départ de la manche, l'avancement est nul")
	_check(r.taille_ecran() == Vector2i(2000, 1125), "l'écran de la bataille est en 16:9 (2000×1125)")
	gs.terminer_partie(false)
	bleu.invulnerable_restant = 0.0
	bleu.etourdi_restant = 0.0
	var etourdissements_avant := rouge.etourdissements_infliges
	r.lion_touche_par_ennemi(bleu, Vector2.ZERO)
	r.lion_touche_par_vomi(bleu, rouge, Vector2.ZERO)
	r.choc_entre_lions(rouge, bleu)
	r.vol_de_cellules(rouge, 3)
	_check(not bleu.est_etourdi() and bleu.chocs == 1 and rouge.etourdissements_infliges == etourdissements_avant
		and rouge.cellules_volees == 5,
		"après la fin de manche, plus d'étourdissement (ennemi ou vomi), de choc ni de vol compté")

	gs.partie_terminee.disconnect(sur_fin)
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false


func _tester_delegation_regles() -> void:
	print("-- GameState délègue aux règles")
	var gs: Node = root.get_node("GameState")
	_check(gs.regles is ReglesSolo, "par défaut, GameState applique les règles du solo")
	var solo: Regles = gs.regles
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	gs.pret = true
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)

	# Des règles sans effet : la victoire ne vient plus de GameState
	gs.regles = Regles.new(gs)
	gs.signaler_progression(1.0)
	_check(fins.is_empty() and gs.partie_en_cours and is_equal_approx(gs.progression, 1.0),
		"signaler_progression enregistre toujours la progression mais laisse la victoire aux règles branchées")

	# Retour aux règles du solo : la même progression gagne la partie
	gs.regles = solo
	gs.signaler_progression(1.0)
	_check(fins == [true] and not gs.partie_en_cours, "avec les règles du solo, la même progression gagne la partie")

	gs.partie_terminee.disconnect(sur_fin)
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false


func _tester_modes() -> void:
	print("-- Mise en place des modes")
	var gs: Node = root.get_node("GameState")
	var tableau: Array[Joueur] = gs.joueurs
	var local: Joueur = gs.joueur_local()
	gs.configurer_bataille(4)
	_check(gs.regles is ReglesBataille and gs.joueurs.size() == 4, "configurer_bataille(4) branche les règles de bataille pour 4 joueurs")
	_check(is_same(tableau, gs.joueurs) and gs.joueur_local() == local,
		"les joueurs sont ajoutés en place : même tableau, joueur local inchangé (Audio y est abonné)")
	var indices: Array = gs.joueurs.map(func(j: Joueur) -> int: return j.index)
	var couleurs: Array = gs.joueurs.map(func(j: Joueur) -> Color: return j.couleur)
	_check(indices == [0, 1, 2, 3] and couleurs == gs.PALETTE_BATAILLE.slice(0, 4),
		"chaque joueur a son index et sa couleur de la palette (%s)" % [indices])
	var troisieme: Joueur = gs.joueurs[2]
	gs.nouvelle_partie()
	_check(gs.joueurs.all(func(j: Joueur) -> bool: return j.crans == 1 and j.couleurs_debloquees == j.nuances()),
		"une nouvelle partie de bataille donne à chacun un cran et ses trois nuances")
	gs.pret = true
	troisieme.etourdir(1.0, 1.0, Vector2.ZERO, Color.TRANSPARENT)
	gs._process(0.4)
	_check(is_equal_approx(troisieme.etourdi_restant, 0.6), "GameState fait avancer tous les joueurs, pas seulement le joueur local")
	gs.configurer_bataille(2)
	_check(gs.joueurs.size() == 2 and is_same(tableau, gs.joueurs) and gs.joueur_local() == local, "moins de joueurs : retirés en place")
	gs.configurer_solo()
	_check(gs.regles is ReglesSolo and gs.joueurs.size() == 1 and gs.joueur_local() == local and is_same(tableau, gs.joueurs),
		"bataille puis solo : règles du solo et un seul joueur, le même")
	gs.nouvelle_partie()
	_check(not local.a_une_couleur() and local.couleurs_debloquees.is_empty() and local.crans == 1,
		"le joueur du solo n'a plus de couleur (son lion retrouve son rendu d'origine) et repart sans couleur débloquée")
	gs.partie_en_cours = false
	gs.pret = false


func _tester_facade_retiree() -> void:
	print("-- GameState sans façade")
	var gs: Node = root.get_node("GameState")
	var restes: Array[String] = []
	for nom in ["couleurs_debloquees", "vies", "coups_recus", "invulnerable_restant", "bonus_restant"]:
		if nom in gs:
			restes.append(nom)
	for nom in ["est_invulnerable", "toucher_lion", "gagner_vie", "debloquer_couleur", "bonus_actif", "activer_bonus"]:
		if gs.has_method(nom):
			restes.append(nom + "()")
	for nom in ["couleur_debloquee", "bonus_change", "vies_changees", "lion_touche"]:
		if gs.has_signal(nom):
			restes.append("signal " + nom)
	_check(restes.is_empty(), "GameState n'expose plus l'état par joueur (restes : %s)" % [restes])


func _tester_territoire() -> void:
	print("-- Territoire")
	# Grille de 4 × 3 cellules de 8 px, rangée par rangée ; la cellule 11 (colonne 3, rangée 2)
	# n'est pas peignable. La cellule 5 (colonne 1, rangée 1) a son centre en (12, 12) : un tampon
	# de 5 px qui y est centré ne touche qu'elle (le centre de ses voisines est à 8 px).
	var peignables := PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0])
	var centre_5 := Vector2i(12, 12)
	var n_prise := ceili(float(Territoire.SEUIL_POSSESSION) / Territoire.GAIN)
	var n_vider := ceili(float(Territoire.CHARGE_MAX) / Territoire.GAIN)
	_check(n_prise == 3 and n_vider == 3,
		"réglages : 3 tampons pour posséder une cellule vierge, 3 pour vider une cellule qui compte déjà (CHARGE_MAX = SEUIL_POSSESSION) (%d, %d)" % [n_prise, n_vider])
	var t := Territoire.new(Vector2i(4, 3), peignables)
	_check(t.nb_peignables == 11 and t.cellules_de(0) == 0 and t.cellules_de(Territoire.PERSONNE) == 11
		and t.proprietaire(5) == Territoire.PERSONNE and t.extraire_changements().is_empty(),
		"un territoire neuf est vierge : 11 cellules peignables, qui ne comptent pour personne")

	# Peindre une cellule vierge : chargée au premier tampon, comptée au troisième
	_check(t.tamponner(0, centre_5, 5) == 0 and t.proprietaire(5) == 0 and t.charge(5) == Territoire.GAIN
		and t.cellules_de(0) == 0 and t.proprietaire_compte(5) == Territoire.PERSONNE,
		"un tampon sur une cellule vierge la charge pour le peintre, sans la faire compter encore")
	_check(range(12).all(func(i: int) -> bool: return i == 5 or t.charge(i) == 0),
		"le tampon ne touche que les cellules dont le centre est à moins de son rayon")
	for i in range(n_prise - 1):
		t.tamponner(0, centre_5, 5)
	_check(t.cellules_de(0) == 1 and t.proprietaire_compte(5) == 0 and t.cellules_de(Territoire.PERSONNE) == 10,
		"au troisième tampon, la cellule compte pour le peintre")
	_check(t.extraire_changements() == PackedInt32Array([5]) and t.extraire_changements().is_empty(),
		"la cellule qui se met à compter est listée une fois, et la liste se vide à la lecture")
	for i in range(10):
		t.tamponner(0, centre_5, 5)
	_check(t.charge(5) == Territoire.CHARGE_MAX and t.cellules_de(0) == 1 and t.extraire_changements().is_empty(),
		"repeinte par son propriétaire, la charge reste à son plafond (déjà atteint dès le seuil de possession), sans nouveau changement")

	# Vol : l'adversaire vide la cellule, la prend, puis la possède
	var vols := 0
	for i in range(n_vider - 1):
		vols += t.tamponner(1, centre_5, 5)
	_check(t.proprietaire(5) == 0 and t.proprietaire_compte(5) == Territoire.PERSONNE and t.cellules_de(0) == 0
		and t.cellules_de(1) == 0 and vols == 0,
		"un adversaire décharge la cellule : sous le seuil, elle ne compte plus pour personne, mais reste au premier peintre")
	vols += t.tamponner(1, centre_5, 5)
	_check(t.proprietaire(5) == 1 and t.charge(5) == 0 and vols == 0, "vidée, la cellule passe à l'adversaire, sans charge et sans vol encore")
	for i in range(n_prise):
		vols += t.tamponner(1, centre_5, 5)
	_check(t.cellules_de(1) == 1 and t.proprietaire_compte(5) == 1 and vols == 1,
		"dès qu'elle compte pour lui, c'est un vol, compté une fois (%d)" % vols)
	_check(t.extraire_changements() == PackedInt32Array([5]), "la cellule volée est listée une fois, même passée par « personne »")
	for i in range(n_vider + n_prise):
		vols += t.tamponner(0, centre_5, 5)
	_check(t.proprietaire_compte(5) == 0 and vols == 2, "la reprendre à son voleur est aussi un vol")

	# Vol à trois : A possède, B décharge sans prendre, C prend : le vol est crédité à C, pas à B.
	var t2 := Territoire.new(Vector2i(4, 3), peignables)
	for i in range(n_prise):
		t2.tamponner(0, centre_5, 5)  # A prend la cellule
	for i in range(n_vider - 1):
		t2.tamponner(1, centre_5, 5)  # B la décharge sous le seuil, sans la faire compter pour lui
	_check(t2.proprietaire(5) == 0 and t2.proprietaire_compte(5) == Territoire.PERSONNE,
		"B décharge la cellule d'A sous le seuil sans la lui prendre")
	var vols_c := 0
	for i in range(1 + n_prise):
		vols_c += t2.tamponner(2, centre_5, 5)  # C la prend et la fait compter
	_check(t2.proprietaire_compte(5) == 2 and vols_c == 1,
		"le vol est crédité à C, qui fait compter la cellule, pas à B, qui l'avait seulement déchargée")

	# Reprise sans vol : B prend la cellule brute d'A (sous le seuil), puis A la reprend : comme la
	# cellule n'a jamais compté pour B, la reprise d'A n'est pas un vol.
	var t3 := Territoire.new(Vector2i(4, 3), peignables)
	for i in range(n_prise):
		t3.tamponner(0, centre_5, 5)  # A prend et fait compter la cellule
	for i in range(n_vider):
		t3.tamponner(1, centre_5, 5)  # B la vide et se la fait attribuer, sans atteindre le seuil
	_check(t3.proprietaire(5) == 1 and t3.proprietaire_compte(5) == Territoire.PERSONNE,
		"la cellule vidée passe à B sans compter pour lui")
	var vols_retour := 0
	for i in range(n_prise):
		vols_retour += t3.tamponner(0, centre_5, 5)  # A la reprend et la refait compter
	_check(t3.proprietaire_compte(5) == 0 and vols_retour == 0,
		"A reprend une cellule que B n'a jamais fait compter : ce n'est pas un vol")

	# Réglage (fiche de correction du 25/09) : depuis CHARGE_MAX = SEUIL_POSSESSION, une passe pleine
	# vitesse d'un adversaire vole des cellules au lieu de seulement les effacer. On reprend la forme
	# de sonde du plan de la phase 9 : 60 tampons par seconde à 350 px/s, rayons 16 puis 21 (les deux
	# premiers crans de gerbe).
	var n_saturer := ceili(float(Territoire.CHARGE_MAX) / Territoire.GAIN)
	for rayon_b in [16, 21]:
		var largeur := 60
		var hauteur := 4
		var taille_cellule_bande := 8
		var bande := PackedByteArray()
		bande.resize(largeur * hauteur)
		bande.fill(1)
		var v := Territoire.new(Vector2i(largeur, hauteur), bande, taille_cellule_bande)
		# A charge sa bande au maximum, comme une passe pleine vitesse (5 à 7 tampons par cellule) :
		# chargée au seul seuil (n_prise tampons), la vérification passait aussi avec l'ancien
		# CHARGE_MAX = 24, qu'elle doit refuser.
		for i in range(n_saturer):
			v.tamponner(0, Vector2i(largeur * taille_cellule_bande / 2, hauteur * taille_cellule_bande / 2), 400)
		var avant_a := v.cellules_de(0)
		_check(v.charge(0) == Territoire.CHARGE_MAX and avant_a == largeur * hauteur,
			"(pré-condition) A possède toute la bande, chargée au maximum (%d)" % v.charge(0))
		var x := 0.0
		while x < largeur * taille_cellule_bande:
			v.tamponner(1, Vector2i(int(x), hauteur * taille_cellule_bande / 2), rayon_b)  # B traverse à 350 px/s, 60 tampons/s
			x += 350.0 / 60.0
		_check(v.cellules_de(1) > 0 and v.cellules_de(0) < avant_a,
			"une passe pleine vitesse de B (rayon %d) sur la bande d'A lui vole des cellules (B : %d, A : %d → %d)"
				% [rayon_b, v.cellules_de(1), avant_a, v.cellules_de(0)])

	# Deux peintres qui se disputent une cellule vierge tampon après tampon
	var u := Territoire.new(Vector2i(4, 3), peignables)
	var vols_disputes := 0
	for i in range(20):
		vols_disputes += u.tamponner(0, centre_5, 5)
		vols_disputes += u.tamponner(1, centre_5, 5)
	_check(vols_disputes == 0 and u.cellules_de(0) == 0 and u.cellules_de(1) == 0,
		"deux peintres qui se disputent une cellule que personne n'a possédée ne se volent rien")

	# Bords et cellules non peignables
	u.tamponner(2, Vector2i(16, 12), 40)  # couvre toute la grille
	_check(u.charge(11) == 0 and u.proprietaire(11) == Territoire.PERSONNE and u.proprietaire(0) == 2,
		"une cellule non peignable ne change jamais")
	var w := Territoire.new(Vector2i(4, 3), peignables)
	w.tamponner(0, Vector2i(-2, 12), 8)
	_check(w.charge(4) == Territoire.GAIN and range(12).all(func(i: int) -> bool: return i == 4 or w.charge(i) == 0),
		"un tampon débordant à gauche ne touche que la première colonne, jamais la fin de la rangée précédente")
	_check(w.tamponner(3, Vector2i(5000, -5000), 46) == 0 and range(12).all(func(i: int) -> bool: return i == 4 or w.charge(i) == 0),
		"un tampon hors de la grille ne touche rien")
	w.reinitialiser()
	_check(w.charge(4) == 0 and w.proprietaire(4) == Territoire.PERSONNE and w.cellules_de(Territoire.PERSONNE) == 11
		and w.extraire_changements().is_empty(), "reinitialiser rend toute la ville vierge")

	# Index de joueur hors plage : la garde d'exécution (pas seulement l'assert de debug, retirée
	# à l'export release) refuse le tampon sans rien changer.
	_check(w.tamponner(-1, centre_5, 5) == 0 and w.tamponner(EtatPartie.NB_JOUEURS_MAX, centre_5, 5) == 0
		and w.charge(5) == 0 and w.proprietaire(5) == Territoire.PERSONNE
		and w.cellules_de(Territoire.PERSONNE) == 11 and w.extraire_changements().is_empty(),
		"un index de joueur hors plage (négatif ou ≥ NB_JOUEURS_MAX) ne touche aucune cellule")

	# Déterminisme et scores, sur une suite de tampons pseudo-aléatoire à trois joueurs
	var grande := PackedByteArray()
	grande.resize(40 * 20)
	for i in range(grande.size()):
		grande[i] = 0 if i % 7 == 0 else 1
	var a := Territoire.new(Vector2i(40, 20), grande)
	var b := Territoire.new(Vector2i(40, 20), grande)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in range(600):
		var joueur := rng.randi_range(0, 2)
		var centre := Vector2i(rng.randi_range(-20, 340), rng.randi_range(-20, 180))
		var rayon := rng.randi_range(8, 46)
		a.tamponner(joueur, centre, rayon)
		b.tamponner(joueur, centre, rayon)
	var identiques := true
	var recompte := [0, 0, 0]
	for i in range(grande.size()):
		if a.proprietaire(i) != b.proprietaire(i) or a.charge(i) != b.charge(i):
			identiques = false
		var p := a.proprietaire_compte(i)
		if p != Territoire.PERSONNE:
			recompte[p] += 1
	_check(identiques, "mêmes tampons dans le même ordre, même territoire (calcul entier, déterministe)")
	_check(recompte == [a.cellules_de(0), a.cellules_de(1), a.cellules_de(2)] and recompte.all(func(n: int) -> bool: return n > 0)
		and a.cellules_de(Territoire.PERSONNE) + recompte[0] + recompte[1] + recompte[2] == a.nb_peignables,
		"les scores tenus tampon après tampon égalent un recompte complet (%s)" % [recompte])
	var liste := a.extraire_changements()
	var listees := {}
	for i in liste:
		listees[i] = true
	_check(listees.size() == liste.size()
		and range(grande.size()).all(func(i: int) -> bool: return a.proprietaire_compte(i) == Territoire.PERSONNE or listees.has(i)),
		"chaque cellule qui compte figure dans la liste des changements, une seule fois (%d)" % liste.size())

	# Coût : une seconde de bataille à 6 lions (60 tampons par lion) sur une grille de 250 × 81
	var pleine := PackedByteArray()
	pleine.resize(250 * 81)
	pleine.fill(1)
	var c := Territoire.new(Vector2i(250, 81), pleine)
	var debut := Time.get_ticks_usec()
	for i in range(360):
		c.tamponner(i % 6, Vector2i(rng.randi_range(0, 2000), rng.randi_range(0, 648)), 46)
	var ms := (Time.get_ticks_usec() - debut) / 1000.0
	_check(ms < 60.0, "360 tampons de 46 px (une seconde à 6 lions) coûtent %.1f ms au territoire (moins de 60 ms)" % ms)


func _tester_reseau() -> void:
	print("-- Réseau (poignée de main, attribution)")
	var reseau: Node = root.get_node("Reseau")  # autoload : jamais nommé (compilé avant lui)
	var api: SceneMultiplayer = root.multiplayer
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	_check(not reseau.en_ligne() and api.multiplayer_peer is OfflineMultiplayerPeer and api.is_server(),
		"hors réseau par défaut : pair hors ligne, ce poste est son propre hôte (le solo)")
	_check(not reseau.version.is_empty() and reseau.version == ProjectSettings.get_setting("application/config/version"),
		"la version présentée est celle du projet (%s)" % reseau.version)

	# Attribution : le plus petit index libre et la première couleur libre, chacun de son côté
	var occupes: Dictionary[int, Dictionary] = {}
	_check(reseau.premier_index_libre(occupes, 6) == 0 and reseau.premiere_couleur_libre(occupes) == palette[0],
		"partie vide : index 0 et première couleur")
	occupes[1] = {"index": 0, "couleur": palette[0], "pseudo": "Hôte"}
	occupes[77] = {"index": 2, "couleur": palette[1], "pseudo": "B"}
	_check(reseau.premier_index_libre(occupes, 6) == 1 and reseau.premiere_couleur_libre(occupes) == palette[2],
		"après un départ : l'index 1 et la troisième couleur sont les premiers libres (index et couleur indépendants)")
	_check(reseau.premier_index_libre(occupes, 2) == 1 and reseau.premier_index_libre(occupes, 1) == -1,
		"les places bornent les index : 1 est libre sur 2 places, rien sur 1")
	occupes[78] = {"index": 1, "couleur": palette[2], "pseudo": "C"}
	for i in range(3, EtatPartie.NB_JOUEURS_MAX):
		occupes[100 + i] = {"index": i, "couleur": palette[i], "pseudo": ""}
	_check(occupes.size() == EtatPartie.NB_JOUEURS_MAX and reseau.premier_index_libre(occupes, 9) == -1
		and reseau.premiere_couleur_libre(occupes) == Color.TRANSPARENT,
		"à %d joueurs, plus d'index ni de couleur, même si l'on demande plus de places" % EtatPartie.NB_JOUEURS_MAX)
	_check(reseau.pseudo_valide("  Léa\n\t ") == "Léa" and reseau.pseudo_valide("Zoé la grande dompteuse") == "Zoé la grand"
		and reseau.pseudo_valide("Zoé la grande dompteuse").length() == reseau.PSEUDO_MAX,
		"le pseudo est nettoyé (contrôles, espaces) et coupé à %d caractères" % reseau.PSEUDO_MAX)

	# Décision de l'hôte sur une demande
	var version: String = reseau.version
	var places: int = reseau.places
	var demande := {"jeu": reseau.JEU, "version": version, "pseudo": "  Zoé la grande dompteuse "}
	reseau.inscrits[1] = {"index": 0, "couleur": palette[0], "pseudo": "Hôte"}
	var r: Dictionary = reseau.examiner_demande(demande)
	_check(r.accepte and r.index == 1 and r.couleur == palette[1] and r.pseudo == "Zoé la grand",
		"demande valable : acceptée avec l'index 1, la deuxième couleur et le pseudo nettoyé (%s)" % [r])
	_check(reseau.inscrits.size() == 1, "examiner une demande n'inscrit personne")
	var autre_version := demande.duplicate()
	autre_version.version = "0.0-ancienne"
	r = reseau.examiner_demande(autre_version)
	_check(not r.accepte and r.raison == reseau.REFUS_VERSION and r.version_hote == version,
		"version différente : refusée, avec la version de l'hôte pour le message (%s)" % [r])
	reseau.manche_en_cours = true
	_check(reseau.examiner_demande(demande).raison == reseau.REFUS_MANCHE, "manche en cours : refusée")
	_check(reseau.examiner_demande(autre_version).raison == reseau.REFUS_VERSION,
		"une version différente se dit avant tout autre refus (le joueur sait quoi mettre à jour)")
	reseau.manche_en_cours = false
	reseau.places = 2
	reseau.inscrits[5] = {"index": 1, "couleur": palette[1], "pseudo": "B"}
	_check(reseau.examiner_demande(demande).raison == reseau.REFUS_PLEIN, "partie pleine (2 places sur 2) : refusée")
	reseau.places = places
	for i in range(2, EtatPartie.NB_JOUEURS_MAX):
		reseau.inscrits[10 + i] = {"index": i, "couleur": palette[i], "pseudo": ""}
	_check(reseau.examiner_demande(demande).raison == reseau.REFUS_PLEIN,
		"partie pleine à %d joueurs : refusée" % EtatPartie.NB_JOUEURS_MAX)
	reseau.inscrits.clear()
	var mal_formees: Array = [null, 42, "LELION", {}, {"jeu": "AUTRE", "version": version, "pseudo": "x"},
		{"jeu": reseau.JEU, "version": 11, "pseudo": "x"}, {"jeu": reseau.JEU, "version": version},
		{"jeu": reseau.JEU, "version": version, "pseudo": ["x"]}]
	var refus_demande := mal_formees.all(func(d: Variant) -> bool:
		var reponse: Dictionary = reseau.examiner_demande(d)
		return not reponse.accepte and reponse.raison == reseau.REFUS_DEMANDE)
	_check(refus_demande, "une demande mal formée ou d'un autre programme est refusée, sans erreur")

	# Départs vus par l'hôte
	var partis: Array[int] = []
	var sur_depart := func(id: int) -> void: partis.append(id)
	reseau.joueur_parti.connect(sur_depart)
	reseau.inscrits[42] = {"index": 1, "couleur": palette[1], "pseudo": "Fantôme"}
	reseau._sur_echec_poignee_de_main(42)
	_check(not reseau.inscrits.has(42) and partis.is_empty(),
		"un accepté qui ne finit pas sa poignée de main libère sa place, sans être signalé comme parti")
	reseau.inscrits[43] = {"index": 1, "couleur": palette[1], "pseudo": "B"}
	reseau._sur_pair_deconnecte(43)
	reseau._sur_pair_deconnecte(99)
	_check(not reseau.inscrits.has(43) and partis == [43], "un inscrit qui part est signalé une fois ; un inconnu, jamais (%s)" % [partis])
	reseau.joueur_parti.disconnect(sur_depart)

	# Hébergement : port occupé, puis libre, puis retour hors réseau
	var port := 17790
	var occupant := ENetMultiplayerPeer.new()
	_check(occupant.create_server(port) == OK, "un autre programme occupe le port %d" % port)
	var erreur: int = reseau.heberger(port)
	_check(erreur != OK and not reseau.en_ligne() and api.is_server() and reseau.inscrits.is_empty(),
		"port occupé : heberger renvoie l'erreur (%d) et le poste reste hors réseau" % erreur)
	occupant.close()
	reseau.pseudo = "Hôte"
	_check(reseau.heberger(port) == OK and reseau.en_ligne() and api.is_server() and reseau.inscrits.size() == 1
		and reseau.index_local == 0 and reseau.couleur_locale == palette[0] and reseau.inscrits[1].pseudo == "Hôte",
		"port libre : l'hôte écoute et s'inscrit lui-même (index 0, première couleur, son pseudo)")
	reseau.quitter()
	_check(not reseau.en_ligne() and api.multiplayer_peer is OfflineMultiplayerPeer and api.is_server()
		and reseau.inscrits.is_empty() and reseau.index_local == -1 and api.auth_callback.is_null(),
		"quitter revient hors réseau : pair hors ligne, hôte de soi-même, plus d'inscrits ni de poignée de main")
	reseau.pseudo = ""
