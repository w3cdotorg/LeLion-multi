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
	_tester_facade_game_state()
	_tester_commandes()
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


func _tester_facade_game_state() -> void:
	print("-- GameState (façade vers le joueur local)")
	var gs: Node = root.get_node("GameState")
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	_check(gs.joueurs.size() == 1 and gs.joueur_local() == gs.joueurs[0], "en solo, un seul joueur, qui est le joueur local")
	var j: Joueur = gs.joueur_local()
	_check(j.vies == 3 and gs.vies == 3, "nouvelle_partie donne au joueur les vies de la difficulté")

	# Relais des signaux et bornes
	var relaye: Array[Color] = []
	var relais := func(c: Color) -> void: relaye.append(c)
	gs.couleur_debloquee.connect(relais)
	_check(gs.debloquer_couleur(0) and j.couleurs_debloquees == [gs.couleur(0)], "debloquer_couleur écrit dans le joueur local")
	_check(relaye == [gs.couleur(0)], "le signal couleur_debloquee de GameState relaie celui du joueur")
	_check(not gs.debloquer_couleur(-1) and not gs.debloquer_couleur(gs.nb_couleurs_total()) and relaye.size() == 1,
		"un index hors bornes est refusé sans signal")
	_check(gs.prochain_index_couleur() == 1, "prochain_index_couleur suit les couleurs du joueur")
	gs.couleur_debloquee.disconnect(relais)

	# Setters de la façade (utilisés par le smoke test)
	gs.vies = 1
	gs.bonus_restant = 0.5
	gs.invulnerable_restant = 0.25
	_check(j.vies == 1 and is_equal_approx(j.bonus_restant, 0.5) and is_equal_approx(j.invulnerable_restant, 0.25),
		"les setters vies / bonus_restant / invulnerable_restant écrivent dans le joueur")
	gs.coups_recus = 2
	_check(j.coups_recus == 2, "le setter coups_recus écrit dans le joueur")
	gs.coups_recus = 0

	# Les minuteries ne tournent qu'en partie, une fois prêt
	gs.pret = false
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.25) and is_equal_approx(j.bonus_restant, 0.5), "pendant l'intro, les minuteries ne décomptent pas")
	gs.pret = true
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.05) and is_equal_approx(j.bonus_restant, 0.3), "une fois prêt, GameState fait avancer le joueur")

	# Coup via la façade : relais de lion_touche, puis défaite au dernier coup
	gs.invulnerable_restant = 0.0
	gs.vies = 2
	var touches: Array[Vector2] = []
	var sur_touche := func(o: Vector2) -> void: touches.append(o)
	gs.lion_touche.connect(sur_touche)
	gs.toucher_lion(Vector2(5, 5))
	_check(gs.vies == 1 and touches == [Vector2(5, 5)] and gs.est_invulnerable(), "toucher_lion retire une vie et relaie lion_touche")
	gs.toucher_lion(Vector2(6, 6))
	_check(gs.vies == 1, "pas de coup pendant l'invulnérabilité")
	gs.invulnerable_restant = 0.0
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)
	gs.toucher_lion(Vector2(7, 7))
	_check(fins == [false] and not gs.partie_en_cours and touches.size() == 1, "le dernier coup termine la partie en défaite, sans lion_touche")
	gs.invulnerable_restant = 0.4
	gs.bonus_restant = 0.6
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.4) and is_equal_approx(j.bonus_restant, 0.6),
		"après la fin de partie, les minuteries ne décomptent plus")
	gs.lion_touche.disconnect(sur_touche)
	gs.partie_terminee.disconnect(sur_fin)

	# Nouvelle partie : repart de zéro
	gs.activer_bonus(8.0)
	gs.nouvelle_partie()
	_check(gs.couleurs_debloquees.is_empty() and gs.vies == 3 and gs.coups_recus == 0 and not gs.bonus_actif(),
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
