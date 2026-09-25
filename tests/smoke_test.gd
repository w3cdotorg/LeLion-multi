extends SceneTree
## Test de fumée headless : godot --headless --script tests/smoke_test.gd
## Charge Main, débloque une couleur, fait vomir le lion sur la ville, vérifie la
## peinture, puis fait apparaître un ennemi sur le lion et vérifie la défaite.

var _echecs := 0
var GS: Node


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
	print("== smoke test LeLion ==")
	GS = root.get_node("GameState")
	var scores: Node = root.get_node("Scores")
	var params: Node = root.get_node("Parametres")
	scores.chemin = "user://scores_test.cfg"
	scores.effacer()
	params.definir_langue("fr")

	# Traductions et réglages
	_check(tr("CONTINUER") == "Continuer", "les traductions françaises sont chargées")
	params.definir_langue("en")
	_check(tr("CONTINUER") == "Resume" and tr("NIVEAU_METROPOLE") == "Metropolis", "le passage en anglais traduit les libellés")
	params.definir_langue("fr")
	params.definir_musique(0.3)
	params.definir_effets(0.0)
	_check(abs(float(scores.preference("musique", -1.0)) - 0.3) < 0.001 and float(scores.preference("effets", -1.0)) == 0.0, "les volumes sont sauvegardés")
	_check(root.get_node("Audio")._musique.volume_db < -20.0 and params.en_db(0.0) <= -80.0, "le volume s'applique à la musique, 0 = silence")
	params.definir_musique(0.7)
	params.definir_effets(1.0)
	_check(params.couche_crt != null and not params.couche_crt.visible, "le filtre CRT est présent et désactivé par défaut")
	params.definir_crt(true)
	_check(params.couche_crt.visible and bool(scores.preference("crt", false)), "activer le filtre CRT l'affiche et le sauvegarde")
	_check(params.couche_crt.get_child(0).material.shader != null, "la couche CRT porte le shader")
	params.definir_crt(false)

	# Écran titre : un bouton par niveau, lancer un niveau le sélectionne
	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	_check(titre.boutons.size() == GS.NIVEAUX.size(), "l'écran titre a un bouton par niveau (%d)" % titre.boutons.size())
	_check(titre.boutons_difficulte.size() == GS.DIFFICULTES.size(), "l'écran titre a un bouton par difficulté (%d)" % titre.boutons_difficulte.size())
	titre.choisir_difficulte(2)
	_check(GS.difficulte_courante == 2 and titre.boutons_difficulte[2].button_pressed, "choisir une difficulté la sélectionne")
	titre.choisir_difficulte(0)
	_check(tr("PAS_ENCORE_PEINT") in titre.boutons[1].text, "un niveau jamais gagné affiche « pas encore peint »")
	_check(tr("NIVEAU_METROPOLE") in titre.boutons[1].text and tr("DIFF_FACILE") in titre.boutons_difficulte[0].text, "l'écran titre affiche les noms traduits")
	# Clic souris réel sur le bouton Réglages (il doit être au-dessus du conteneur central)
	var centre_bouton: Vector2 = titre.bouton_reglages.get_global_rect().get_center()
	for presse in [true, false]:
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = presse
		clic.position = centre_bouton
		clic.global_position = centre_bouton
		if presse:
			clic.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(clic, true)  # coordonnées du viewport, pas de la fenêtre
		await process_frame
	await process_frame
	var reglages: Node = titre.get_node_or_null("Reglages")
	_check(reglages != null and reglages.musique.has_focus(), "un clic souris sur Réglages ouvre l'écran de réglages")
	reglages._choisir_langue("en")
	await _frames(1)
	_check(params.langue == "en" and "Metropolis" in titre.boutons[1].text, "changer la langue retraduit l'écran titre")
	reglages._choisir_langue("fr")
	reglages.fermer()
	await _frames(1)
	_check(titre.get_node_or_null("Reglages") == null and titre.bouton_reglages.has_focus(), "Fermer referme les réglages et rend le focus")
	GS.niveau_courant = 1
	titre.free()

	# Préférences : la difficulté et le niveau choisis sont relus par l'écran titre
	scores.definir_preference("difficulte", 2)
	scores.definir_preference("niveau", 1)
	scores.charger()
	GS.difficulte_courante = 0
	GS.niveau_courant = 0
	titre = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	_check(GS.difficulte_courante == 2 and titre.boutons_difficulte[2].button_pressed, "l'écran titre restaure la difficulté sauvegardée")
	_check(GS.niveau_courant == 1 and titre.boutons[1].button_pressed and not titre.boutons[0].button_pressed, "l'écran titre restaure le dernier niveau, sélectionné")
	_check(titre.bouton_jouer.has_focus(), "le bouton Jouer a le focus au départ")
	var style_selection: StyleBox = titre.boutons[1].get_theme_stylebox("pressed")
	_check(style_selection is StyleBoxFlat and style_selection.border_color == Styles.JAUNE, "le niveau sélectionné a une bordure jaune")
	titre.choisir_niveau(2)
	_check(GS.niveau_courant == 2 and int(scores.preference("niveau", -1)) == 2 and titre.boutons[2].button_pressed, "choisir un niveau le sélectionne et le sauvegarde")
	titre.choisir_difficulte(0)
	_check(int(scores.preference("difficulte", -1)) == 0, "changer de difficulté la sauvegarde")
	titre.free()
	scores.effacer()
	GS.niveau_courant = 0

	# Scores
	_check(scores.enregistrer("skyline/facile", 50.0) == 0 and scores.meilleur_temps("metropole/facile") < 0.0
		and scores.meilleur_temps("skyline/moyen") < 0.0, "un record ne compte que pour son niveau et sa difficulté")
	scores.effacer()
	_check(scores.enregistrer("test", 90.0) == 0, "premier temps enregistré = record")
	_check(scores.enregistrer("test", 120.0) == 1, "temps plus lent = rang 1")
	_check(scores.enregistrer("test", 60.0) == 0, "temps plus rapide = nouveau record")
	scores.charger()
	_check(scores.meilleur_temps("test") == 60.0, "les scores sont relus depuis le disque")
	GS.niveau_courant = 0
	var main: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(3)

	var ville: Node = main.get_node("Ville")
	var lion: CharacterBody2D = main.get_node("Lion")
	var spawner: Node = main.get_node("Spawner")
	_check(GS.partie_en_cours, "partie en cours après Main._ready")
	_check(lion.joueur == GS.joueur_local() and lion.commandes.source == Commandes.Source.LOCALES,
		"hors démo, le lion porte le joueur local et lit les commandes de ce poste")

	# Intro « Prêt ? Vomissez ! » : le jeu attend
	_check(not GS.pret and main.get_node_or_null("Intro") != null, "l'intro s'affiche et le jeu n'est pas encore prêt")
	var position_avant: Vector2 = lion.global_position
	Input.action_press("deplacer_droite")
	await _frames(5)
	Input.action_release("deplacer_droite")
	_check(lion.global_position == position_avant, "le lion ne bouge pas pendant l'intro")
	_check(GS.temps_ecoule == 0.0, "le chrono ne tourne pas pendant l'intro")
	main.get_node("Intro").queue_free()
	GS.demarrer()
	await _frames(1)
	_check(GS.pret, "demarrer() rend le jeu prêt")
	_check(root.get_node_or_null("Audio") != null, "autoload Audio présent")
	var audio: Node = root.get_node("Audio")
	_check(audio._musique.playing and audio._pistes[1].playing and audio._pistes[2].playing, "les trois pistes de musique tournent ensemble")
	_check(audio.ensemble_courant == "ville" and audio.intensite == 0, "en jeu, thème de la ville avec la base seule")
	_check(audio._pistes[2].volume_db < -60.0, "la mélodie est muette au départ")
	GS.signaler_progression(0.5)
	_check(audio.intensite == 1, "à mi-chemin, les arpèges entrent")
	GS.signaler_progression(0.6)
	_check(audio.intensite == 2, "aux deux tiers, la mélodie entre")
	GS.signaler_progression(0.0)
	audio.definir_intensite(0, true)

	# Contrôles tactiles : cachés sans écran tactile, le stick pilote les actions
	var tactile: CanvasLayer = main.get_node("ControlesTactiles")
	_check(tactile.visible == DisplayServer.is_touchscreen_available(), "les contrôles tactiles ne s'affichent que sur écran tactile (ici : %s)" % tactile.visible)
	var stick: Control = tactile.joystick
	stick.debut(Vector2(300, 500))
	stick.glisser(Vector2(300 + stick.rayon, 500 - stick.rayon * 0.5))
	_check(Input.get_action_strength("deplacer_droite") > 0.8 and Input.get_action_strength("deplacer_haut") > 0.3
		and Input.get_action_strength("deplacer_gauche") == 0.0, "le stick virtuel pilote les actions avec leur intensité")
	stick.fin()
	_check(Input.get_action_strength("deplacer_droite") == 0.0 and stick.vecteur == Vector2.ZERO, "relâcher le stick relâche les actions")
	_check(tactile.get_node("BoutonVomir").action == "vomir" and tactile.get_node("BoutonPause").action == "pause", "les boutons tactiles déclenchent vomir et pause")

	# Pause via l'action "pause"
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await _frames(2)
	var menu_pause: CanvasLayer = main.get_node("PauseMenu")
	_check(paused and menu_pause.visible, "Échap met en pause et ouvre le menu de pause")
	_check(menu_pause.bouton_continuer.has_focus(), "le bouton Continuer a le focus")
	Input.parse_input_event(ev.duplicate())
	Input.flush_buffered_events()
	await _frames(2)
	_check(not paused and not menu_pause.visible, "Échap relance la partie")
	menu_pause.ouvrir()
	_check(paused, "ouvrir() met en pause")
	menu_pause.ouvrir_reglages()
	await _frames(1)
	_check(menu_pause.get_node_or_null("Reglages") != null, "les réglages s'ouvrent depuis la pause")
	menu_pause.get_node("Reglages").fermer()
	await _frames(1)
	menu_pause.reprendre()
	_check(not paused and not menu_pause.visible, "Continuer reprend la partie")
	var nb_cellules: int = ville.grille_taille.x * ville.grille_taille.y
	_check(ville.cellules_peignables > 0 and ville.cellules_peignables < nb_cellules,
		"cellules peignables = zones opaques de la skyline (%d / %d)" % [ville.cellules_peignables, nb_cellules])

	# Pickup : le lion marche dessus
	var pickup: Node = spawner.spawn_pickup(0, lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(pickup), "le pickup disparaît au contact")
	_check(GS.couleurs_debloquees.size() == 1, "une couleur débloquée via pickup")
	_check(lion.vomi_container.get_child_count() == 1, "un émetteur de particules par couleur")
	var hud: Node = main.get_node("HUD")
	_check(hud.indice.visible == false, "le HUD cache l'indice après la première couleur")
	_check(hud._pastilles[0].color == GS.couleur(0) and hud._pastilles[1].color != GS.couleur(1),
		"le HUD affiche la première pastille débloquée et la deuxième verrouillée")

	# Vomir sur la ville : on place le lion au-dessus de la skyline
	lion.global_position = Vector2(600, ville.position.y - 300)
	Input.action_press("vomir")
	await _frames(30)
	_check(lion.est_en_train_de_vomir, "le lion vomit tant que l'action est maintenue")
	var rayon_normal: float = lion.traceuse_shape.shape.radius
	var bonus: Node = spawner.spawn_bonus(lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(bonus) and GS.bonus_actif(), "l'étoile ramassée active la gerbe XXL")
	_check(lion.traceuse_shape.shape.radius == rayon_normal * 2.0, "le rayon de peinture est doublé pendant le bonus")
	_check(hud.etiquette_bonus.visible, "le HUD affiche le bonus")
	GS.bonus_restant = 0.01
	await create_timer(0.1).timeout
	await _frames(1)
	_check(not GS.bonus_actif() and lion.traceuse_shape.shape.radius == rayon_normal, "le bonus expire et le rayon revient à la normale")
	_check(root.get_node("Audio")._vomi.playing, "la boucle sonore de vomi tourne")
	_check(ville.cellules_peintes > 0, "la ville a été peinte (%d cellules)" % ville.cellules_peintes)
	_check(GS.progression > 0.0, "la progression est remontée dans GameState (%.4f)" % GS.progression)
	_check(hud.progression.value > 0.0, "la barre de progression du HUD bouge")
	_check(spawner.difficulte() >= 0.0 and spawner.difficulte() <= 1.0, "difficulté bornée (%.3f)" % spawner.difficulte())
	var soucoupe: Node = spawner.spawn_soucoupe(20)
	_check(soucoupe.speed >= spawner.vitesse_soucoupe.x, "la soucoupe reçoit sa vitesse du spawner (%.0f)" % soucoupe.speed)
	soucoupe.queue_free()
	Input.action_release("vomir")
	await _frames(3)
	_check(not lion.est_en_train_de_vomir, "le lion arrête de vomir quand l'action est relâchée")

	# Mode Facile : un coup enlève une vie et rend invulnérable un moment
	_check(GS.vies == 3 and hud._coeurs[2].visible, "mode Facile : 3 vies affichées")
	_check(abs(GS.seuil_victoire() - 0.85) < 0.001 and abs(hud.repere_seuil.offset_left + 1.5 - 0.85 * hud.progression.size.x) < 2.0,
		"seuil de victoire 85 %% en Facile, repère placé sur la barre")
	var coccinelle: Node = spawner.spawn_coccinelle(lion.global_position.y + 66)
	coccinelle.position.x = lion.global_position.x + 68
	await _frames(3)
	_check(GS.partie_en_cours and GS.vies == 2, "un coup coûte une vie, la partie continue (%d vies)" % GS.vies)
	_check(GS.est_invulnerable(), "le lion est invulnérable après un coup")
	_check(lion._recul.length() > 0.0, "le lion est repoussé par le coup (%.0f px/s)" % lion._recul.length())
	_check(hud.flash.color.a > 0.0, "l'écran flashe en rouge")
	_check(main._tremblement_restant > 0.0, "la caméra tremble")
	_check(hud._coeurs[2].modulate == hud.COULEUR_COEUR_PERDU, "le HUD grise le cœur perdu")
	coccinelle.queue_free()
	var soucoupe2: Node = spawner.spawn_soucoupe(lion.global_position.y + 66)
	soucoupe2.position.x = lion.global_position.x + 68
	await _frames(3)
	_check(GS.vies == 2, "un coup pendant l'invulnérabilité ne compte pas")
	soucoupe2.queue_free()
	GS.invulnerable_restant = 0.0

	# Cœur : rend une vie, jamais au-delà du maximum
	var coeur: Node = spawner.spawn_coeur(lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(coeur) and GS.vies == 3, "un cœur ramassé rend une vie (%d)" % GS.vies)
	_check(not GS.gagner_vie(), "impossible de dépasser le maximum de vies")

	# Défaite : trois coups, le doigt toujours sur le stick
	stick.debut(Vector2(300, 500))
	stick.glisser(Vector2(300 + stick.rayon, 500))
	GS.vies = 1
	coccinelle = spawner.spawn_coccinelle(lion.global_position.y + 66)
	coccinelle.position.x = lion.global_position.x + 68
	await _frames(3)
	_check(not GS.partie_en_cours, "la partie se termine quand la dernière vie est perdue")
	_check(paused, "l'arbre est en pause après la défaite")
	var overlay: Node = main.get_node_or_null("GameOver")
	_check(overlay != null, "l'overlay GameOver est affiché")
	_check(overlay != null and overlay.phase_continue and overlay.compte.text == "9" and overlay.titre.text == tr("CONTINUE"),
		"la défaite commence par CONTINUE ? avec un compte à 9")
	_check(overlay != null and not overlay.stats.visible and not overlay.boutons.visible, "le bilan attend la fin du compte")
	overlay._decrementer()
	_check(overlay != null and overlay.compte.text == "8", "le compte descend")
	overlay._fin_continue()
	_check(overlay != null and not overlay.phase_continue and overlay.stats.visible, "à zéro, le bilan apparaît")
	_check(overlay != null and overlay.titre.text == tr("GAME_OVER"), "l'overlay affiche GAME OVER")
	_check(overlay != null and overlay._lignes.size() == 4 and overlay._lignes[2].cible == GS.coups_recus and GS.coups_recus == 2,
		"le bilan de défaite a 4 lignes et compte les coups reçus (%d)" % GS.coups_recus)
	_check(overlay != null and not overlay.sous_titre.visible, "pas de badge record sur une défaite")
	overlay._terminer_animation()
	_check(overlay != null and overlay._lignes[0].valeur.text == "%d %%" % int(round(GS.progression * 100)) and overlay.bouton_rejouer.has_focus(),
		"sauter l'animation affiche les valeurs finales et donne le focus")
	_check(overlay != null and not overlay.bouton_suivant.visible, "pas de bouton Niveau suivant après une défaite")

	_check(Input.get_action_strength("deplacer_droite") == 0.0, "la défaite relâche le stick virtuel")
	Input.action_press("deplacer_droite", 1.0)  # comme un doigt resté posé

	# Victoire sur le niveau Métropole : nouvelle partie, on peint toute la skyline
	paused = false
	main.queue_free()
	await _frames(2)
	GS.niveau_courant = 1
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	main.get_node("Intro").queue_free()
	GS.demarrer()
	await _frames(1)
	_check(Input.get_action_strength("deplacer_droite") == 0.0, "une nouvelle partie démarre avec les actions relâchées")
	_check(GS.couleurs_debloquees.is_empty() and main.get_node("Lion").vomi_container.get_child_count() == 0
		and main.get_node("HUD")._pastilles[0].color == main.get_node("HUD").COULEUR_VERROUILLEE,
		"une nouvelle partie repart sans couleur : ni émetteur, ni pastille allumée")
	_check(GS.vies == 3 and GS.coups_recus == 0 and main.get_node("HUD")._coeurs[2].modulate == main.get_node("HUD").COULEUR_COEUR,
		"après une défaite, le niveau suivant repart avec tous ses cœurs affichés")
	ville = main.get_node("Ville")
	_check(ville.tex_size == Vector2i(2000, 320), "la ville a chargé la skyline du niveau Métropole (%s)" % ville.tex_size)
	GS.debloquer_couleur(0)
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	# un seul tampon clairsemé ne suffit pas : la couverture réelle est mesurée
	ville.peindre(Vector2(1000, haut + 200), 45, GS.couleurs_debloquees)
	ville.mesurer_progression()
	_check(GS.progression < 0.01, "un tampon isolé ne compte presque pas (couverture %.3f)" % GS.progression)
	for x in range(0, ville.tex_size.x, 40):
		for y in range(0, ville.tex_size.y, 40):
			ville.peindre(Vector2(x, haut + y), 45, GS.couleurs_debloquees)
	ville.mesurer_progression()
	await _frames(3)
	_check(GS.progression >= GS.seuil_victoire(), "progression >= seuil après avoir tout peint (%.2f)" % GS.progression)
	_check(ville.coulures.size() > 0 or ville.CHANCE_COULURE == 0.0, "des coulures de peinture sont en cours (%d)" % ville.coulures.size())
	_check(not GS.partie_en_cours and paused, "la partie se termine en victoire")
	overlay = main.get_node_or_null("GameOver")
	_check(overlay != null and overlay.titre.text == tr("VICTOIRE"), "l'overlay affiche VICTOIRE")
	var nb_confettis := 0
	for enfant in overlay.get_children():
		if enfant is GPUParticles2D:
			nb_confettis += 1
	_check(nb_confettis == 3, "la victoire lance des confettis (%d émetteurs)" % nb_confettis)
	_check(overlay != null and tr("NOUVEAU_RECORD") in overlay.sous_titre.text and overlay.sous_titre.visible, "la victoire affiche le badge Nouveau record")
	_check(overlay != null and overlay._lignes[1].commentaire.text == tr("PREMIER_TEMPS"), "premier temps sur ce niveau : pas de comparaison")
	_check(overlay != null and overlay._lignes[2].commentaire.text == tr("SANS_EGRATIGNURE"), "victoire sans coup reçu : « Sans une égratignure »")
	await create_timer(4.0).timeout
	_check(overlay != null and overlay._animation_finie and overlay.bouton_suivant.has_focus(), "l'animation du bilan se termine seule et donne le focus")
	_check(overlay != null and overlay.bouton_suivant.visible, "le bouton Niveau suivant est proposé")
	_check(scores.meilleur_temps("metropole/facile") >= 0.0, "le record est persisté par niveau et difficulté")
	scores.effacer()

	# Boss sur le niveau Village : cycle d'états accéléré et contact
	paused = false
	main.queue_free()
	await _frames(2)
	GS.niveau_courant = 2
	GS.difficulte_courante = 0
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	main.get_node("Intro").queue_free()
	GS.demarrer()
	await _frames(1)
	lion = main.get_node("Lion")
	var boss: Node = get_first_node_in_group("boss")
	_check(boss != null, "le niveau Village fait apparaître le boss")
	_check(root.get_node("Audio").ensemble_courant == "boss", "le Village joue le thème du boss")
	_check(main.get_node("Spawner")._facteur_ennemis == 2.0, "les autres ennemis sont deux fois moins fréquents avec un boss")
	var nb_polygones := 0
	for enfant in boss.get_children():
		if enfant is CollisionPolygon2D:
			nb_polygones += 1
	_check(nb_polygones > 0, "la collision du boss est générée depuis la silhouette (%d polygones)" % nb_polygones)
	_check(abs(boss.sprite.scale.y * boss.sprite.texture.get_height() - 648 * 0.65) < 1.0, "le boss fait 65 % de la hauteur de l'écran")
	_check(abs(boss.position.y + boss._demi_hauteur - boss.y_sol) < 0.5 and abs(boss.y_sol - (648 - 180)) < 0.5,
		"le boss est posé sur le haut de la skyline (bas=%.1f, sol=%.1f)" % [boss.position.y + boss._demi_hauteur, boss.y_sol])
	_check(boss.etat == boss.Etat.REPOS, "le boss commence hors écran, au repos")
	# on accélère le cycle
	var cote_initial: int = boss.cote
	boss.duree_repos = 0.05
	boss.duree_annonce = 0.05
	boss.duree_entree = 0.2
	boss.duree_pause = 0.05
	boss.duree_sortie = 0.2
	boss._changer_etat(boss.Etat.ANNONCE)
	var etats_vus: Array = []
	boss.etat_change.connect(func(e: int) -> void: etats_vus.append(e))
	lion.global_position = Vector2(1000 - 68, boss.position.y - 66)  # au centre, sur le passage
	var vies_avant: int = GS.vies
	await create_timer(0.9).timeout
	_check(etats_vus.has(boss.Etat.PAUSE) and etats_vus.has(boss.Etat.SORTIE) and etats_vus.has(boss.Etat.REPOS),
		"le boss enchaîne entrée, pause au centre, sortie, repos")
	_check(boss.cote == -cote_initial, "le boss change de côté après un cycle")
	_check(signf(boss.sprite.scale.x) == boss.cote, "le sprite du boss regarde vers le centre")
	var x_max_poly := -1e9
	for enfant in boss.get_children():
		if enfant is CollisionPolygon2D:
			for p in enfant.polygon:
				x_max_poly = max(x_max_poly, p.x)
	_check((boss.cote > 0 and x_max_poly > 200.0) or (boss.cote < 0 and x_max_poly < 200.0),
		"la collision du boss est en miroir avec le sprite (x max %.0f, côté %d)" % [x_max_poly, boss.cote])
	_check(GS.vies < vies_avant, "le boss blesse le lion au passage (%d → %d)" % [vies_avant, GS.vies])
	GS.niveau_courant = 0

	# Arcade : neuf stages, Facile → Moyen → Hardcore
	GS.demarrer_arcade()
	_check(GS.mode_arcade and GS.difficulte_courante == 0 and GS.niveau_courant == 0 and GS.titre_etape() == "STAGE 1/9",
		"l'arcade démarre au stage 1 : Skyline en Facile")
	for i in range(3):
		GS.passer_etape_arcade()
	_check(GS.difficulte_courante == 1 and GS.niveau_courant == 0, "le stage 4 est Skyline en Moyen")
	for i in range(5):
		GS.passer_etape_arcade()
	_check(GS.etape_arcade == 8 and GS.difficulte_courante == 2 and GS.niveau_courant == 2 and not GS.etape_arcade_suivante_existe(),
		"le stage 9 est Village en Hardcore, dernier")
	GS.temps_arcade = 400.0
	paused = false
	main.queue_free()
	await _frames(2)
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	main.get_node("Intro").queue_free()
	GS.demarrer()
	await _frames(1)
	hud = main.get_node("HUD")
	_check(hud.etape.visible and hud.etape.text == "STAGE 9/9", "le HUD affiche le stage en arcade")
	GS.temps_ecoule = 30.0
	GS.signaler_progression(0.96)
	await _frames(3)
	overlay = main.get_node_or_null("GameOver")
	_check(overlay != null and overlay.titre.text == tr("ARCADE_TERMINE"), "gagner le stage 9 termine l'arcade")
	_check(overlay != null and not overlay.bouton_suivant.visible and not overlay.bouton_rejouer.visible, "fin d'arcade : seul Menu reste")
	_check(abs(GS.temps_arcade - 430.0) < 0.01 and abs(scores.meilleur_temps("arcade") - 430.0) < 0.01, "le temps total d'arcade est cumulé et enregistré")
	_check(overlay != null and overlay._lignes[-1].cible == 430, "le bilan affiche le temps total")
	scores.effacer()
	GS.quitter_arcade()

	# Attract mode : inactivité sur le titre → démo pilotée, toute touche en sort
	titre = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	titre.demo_autorisee = true
	titre.inactivite = titre.DELAI_DEMO
	var difficulte_avant: int = GS.difficulte_courante
	# on empêche le changement de scène en interceptant : lancer_demo(false) est l'équivalent testable
	titre.demo_autorisee = false
	titre.lancer_demo(false)
	_check(GS.demo and GS.difficulte_courante == 0, "l'inactivité lance la démo en Facile")
	titre.free()
	paused = false
	main.queue_free()
	await _frames(2)
	GS.niveau_courant = 0
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	main.get_node("Intro").queue_free()
	GS.demarrer()
	await _frames(1)
	_check(main.get_node_or_null("Pilote") != null and main.get_node_or_null("Demo") != null, "en démo, le pilote et l'étiquette DÉMO sont là")
	lion = main.get_node("Lion")
	spawner = main.get_node("Spawner")
	_check(lion.commandes.source == Commandes.Source.MANUELLES, "en démo, le lion suit des commandes manuelles")
	spawner.spawn_pickup(0, Vector2(1200, 250))
	await _frames(10)
	_check(lion.commandes.direction_voulue.length() > 0.9 and lion._vitesse.length() > 0.0, "le pilote dirige le lion vers la pastille")
	var soucoupe3: Node = spawner.spawn_soucoupe(lion.global_position.y + 66)
	soucoupe3.position.x = lion.global_position.x + 250
	await _frames(2)
	_check(lion.commandes.direction_voulue.x < 0.0, "le pilote fuit un ennemi proche")
	soucoupe3.queue_free()
	Input.action_press("deplacer_droite")
	await _frames(2)
	Input.action_release("deplacer_droite")
	main.quitter_demo(false)
	_check(not GS.demo, "quitter la démo rend la main")
	GS.difficulte_courante = difficulte_avant

	# Hardcore : un seul coup
	paused = false
	main.queue_free()
	await _frames(2)
	GS.niveau_courant = 0
	GS.difficulte_courante = 2
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	main.get_node("Intro").queue_free()
	GS.demarrer()
	await _frames(1)
	lion = main.get_node("Lion")
	spawner = main.get_node("Spawner")
	hud = main.get_node("HUD")
	_check(GS.vies == 1 and not hud._coeurs[1].visible, "mode Hardcore : un seul cœur affiché")
	_check(abs(GS.seuil_victoire() - 0.95) < 0.001, "mode Hardcore : 95 %% à peindre")
	GS.signaler_progression(0.92)
	_check(GS.partie_en_cours, "92 %% ne suffit pas en Hardcore")
	_check(spawner._timer_coeur == null, "mode Hardcore : pas de cœurs à ramasser")
	coccinelle = spawner.spawn_coccinelle(lion.global_position.y + 66)
	coccinelle.position.x = lion.global_position.x + 68
	await _frames(3)
	_check(not GS.partie_en_cours, "mode Hardcore : un coup et c'est fini")
	GS.difficulte_courante = 0

	# Un lion lié à un autre joueur suit ce joueur et ses propres commandes
	# La GerbeTraceuse de ce lion peint encore avec les couleurs du joueur local via la
	# façade GameState, jusqu'à la phase 6.
	paused = false
	var autre := Joueur.new()
	autre.reinitialiser(3)
	var lion_autre: Node = load("res://Scenes/Lion.tscn").instantiate()
	lion_autre.joueur = autre
	lion_autre.commandes = Commandes.manuelles()
	lion_autre.position = Vector2(400, 200)
	root.add_child(lion_autre)
	await _frames(1)
	_check(lion_autre.vomi_container.get_child_count() == 0, "un lion lié à un joueur sans couleur n'a pas d'émetteur")
	GS.debloquer_couleur(3)
	_check(lion_autre.vomi_container.get_child_count() == 0, "une couleur du joueur local ne touche pas un lion lié à un autre joueur")
	autre.debloquer_couleur(Color.RED)
	_check(lion_autre.vomi_container.get_child_count() == 1, "le lion reconstruit sa gerbe quand son propre joueur débloque une couleur")
	var rayon_autre: float = lion_autre.traceuse_shape.shape.radius
	GS.activer_bonus(5.0)
	_check(lion_autre.traceuse_shape.shape.radius == rayon_autre, "le bonus du joueur local ne touche pas un lion lié à un autre joueur")
	GS.bonus_restant = 0.0
	autre.activer_bonus(5.0)
	_check(is_equal_approx(lion_autre.traceuse_shape.shape.radius, rayon_autre * 2.0), "le bonus de son propre joueur double la gerbe du lion")
	autre.encaisser_coup(Vector2.INF, 1.5)
	_check(lion_autre._recul.length() > 0.0, "un coup encaissé par son propre joueur repousse le lion")
	lion_autre._recul = Vector2.ZERO  # sinon le recul contamine les vérifications de mouvement ci-dessous
	GS.pret = false
	lion_autre.commandes.direction_voulue = Vector2.RIGHT
	var x_avant: float = lion_autre.global_position.x
	await _frames(5)
	_check(lion_autre.global_position.x == x_avant, "hors jeu (intro), même des commandes manuelles sont ignorées")
	GS.pret = true
	await _frames(5)
	_check(lion_autre.global_position.x > x_avant, "le lion avance selon ses commandes manuelles")
	lion_autre.commandes.vomir_voulu = true
	await _frames(2)
	_check(lion_autre.est_en_train_de_vomir, "le lion vomit quand ses commandes manuelles le demandent")
	lion_autre.commandes.vomir_voulu = false
	await _frames(2)
	lion_autre.free()
	_check(autre.couleur_debloquee.get_connections().is_empty() and autre.touche.get_connections().is_empty(),
		"le lion libéré se désabonne de son joueur")
	autre.debloquer_couleur(Color.BLUE)
	autre = null

	print("== %d échec(s) ==" % _echecs)
	paused = false
	main.free()
	quit(1 if _echecs > 0 else 0)
