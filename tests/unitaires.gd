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
	_tester_delegation_regles()
	_tester_facade_retiree()
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


func _tester_game_state() -> void:
	print("-- GameState (état de partie)")
	var gs: Node = root.get_node("GameState")
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	_check(gs.joueurs.size() == 1 and gs.joueur_local() == gs.joueurs[0], "en solo, un seul joueur, qui est le joueur local")
	var j: Joueur = gs.joueur_local()
	_check(j.vies == 3, "nouvelle_partie donne au joueur les vies de la difficulté")

	# Prochaine couleur à offrir (lue par le Spawner)
	_check(gs.prochain_index_couleur() == 0, "sans couleur, la prochaine pastille est la première")
	j.debloquer_couleur(gs.couleur(0))
	_check(gs.prochain_index_couleur() == 1, "prochain_index_couleur suit les couleurs du joueur local")
	for i in range(1, gs.nb_couleurs_total()):
		j.debloquer_couleur(gs.couleur(i))
	_check(gs.prochain_index_couleur() == -1, "toutes les couleurs débloquées : plus de pastille à offrir")

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
	_check(not r.pastille_ramassee(j, 2), "une couleur déjà débloquée n'a pas d'effet")
	_check(not r.pastille_ramassee(j, -1) and not r.pastille_ramassee(j, gs.nb_couleurs_total()) and j.couleurs_debloquees.size() == 1,
		"un index de couleur hors bornes est refusé")
	r.etoile_ramassee(j)
	_check(j.bonus_actif() and is_equal_approx(j.bonus_restant, ReglesSolo.DUREE_ETOILE), "l'étoile active la gerbe XXL pour DUREE_ETOILE secondes")
	_check(r.coeur_ramasse(j) and j.vies == 3, "un cœur rend une vie")
	_check(not r.coeur_ramasse(j) and j.vies == gs.VIES_MAX, "un cœur ne dépasse pas le maximum de vies")

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
