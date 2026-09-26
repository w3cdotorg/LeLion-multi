extends SceneTree
## Test de fumée headless : godot --headless --script tests/smoke_test.gd
## Charge Main, débloque une couleur, fait vomir le lion sur la ville, vérifie la
## peinture, puis fait apparaître un ennemi sur le lion et vérifie la défaite.

var _echecs := 0
var GS: Node
var JL: Joueur  # le joueur local (unique en solo)
## Les sons joués par `Audio` (un lecteur par son, ajouté comme enfant), par nom de fichier :
## `_sons.count("pickup")` compte les sons de ramassage.
var _sons: Array[String] = []


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


## Couleurs présentes sur une image (pixels non transparents), en clés `to_rgba32()`. À comparer
## à `_rgba8(couleur)`, pas à `couleur.to_rgba32()` : une image RGBA8 tronque chaque composante
## sur 8 bits (les nuances d'un joueur de bataille ne sont pas exactement représentables).
func _couleurs_peintes(image: Image) -> Dictionary:
	var couleurs := {}
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.0:
				couleurs[c.to_rgba32()] = true
	return couleurs


## Chaque lecteur ajouté à `Audio` : le nom du son qu'il joue (voir `_sons`).
func _noter_son(noeud: Node) -> void:
	if noeud is AudioStreamPlayer and noeud.stream != null:
		_sons.append(noeud.stream.resource_path.get_file().get_basename())


## La couleur telle qu'une image RGBA8 la stocke, en `to_rgba32()`.
func _rgba8(c: Color) -> int:
	var pixel := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	pixel.set_pixel(0, 0, c)
	return pixel.get_pixel(0, 0).to_rgba32()


func _run() -> void:
	print("== smoke test LeLion ==")
	GS = root.get_node("GameState")
	JL = GS.joueur_local()
	var scores: Node = root.get_node("Scores")
	var params: Node = root.get_node("Parametres")
	scores.chemin = "user://scores_test.cfg"
	scores.effacer()
	params.definir_langue("fr")
	root.get_node("Audio").child_entered_tree.connect(_noter_son)

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

	await _tester_ecran_reseau(scores, params)
	await _tester_titre_reseau(scores)
	await _tester_salon(params)

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
	_check(not JL.a_une_couleur() and lion.sprite.material == null and not lion.etiquette_pseudo.visible,
		"en solo, le joueur n'a pas de couleur de lion : sprite sans matériau (rendu d'origine), pas de pseudo")
	_check(ville.territoire == null, "en solo, la ville ne tient pas de territoire : seule la couverture compte")

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
	var sons_avant := _sons.count("pickup")
	var pickup: Node = spawner.spawn_pickup(0, lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(pickup), "le pickup disparaît au contact")
	_check(_sons.count("pickup") == sons_avant + 1 and JL.crans == 2,
		"une pastille du solo débloque une couleur et donne un cran : un seul son de ramassage (%d)" % (_sons.count("pickup") - sons_avant))
	_check(JL.couleurs_debloquees.size() == 1, "une couleur débloquée via pickup")
	_check(lion.vomi_container.get_child_count() == 1, "un émetteur de particules par couleur")
	_check(lion.traceuse_shape.shape.radius == 21.0, "avec une couleur, la gerbe peint sur 21 px (16 px + 5 px par couleur)")
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
	sons_avant = _sons.count("pickup")
	var bonus: Node = spawner.spawn_bonus(lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(bonus) and JL.bonus_actif(), "l'étoile ramassée active la gerbe XXL")
	_check(_sons.count("pickup") == sons_avant + 1, "l'étoile joue le son de ramassage, par Audio (%d)" % (_sons.count("pickup") - sons_avant))
	_check(lion.traceuse_shape.shape.radius == rayon_normal * 2.0, "le rayon de peinture est doublé pendant le bonus")
	_check(hud.etiquette_bonus.visible, "le HUD affiche le bonus")
	var etoile_solo: Node = spawner.spawn_bonus(Vector2(-500, -500))  # loin du lion : jamais ramassée
	etoile_solo._expirer()
	await _frames(1)
	_check(not is_instance_valid(etoile_solo), "en solo (son propre hôte), une étoile en fin de vie se libère elle-même")
	JL.bonus_restant = 0.01
	await create_timer(0.1).timeout
	await _frames(1)
	_check(not JL.bonus_actif() and lion.traceuse_shape.shape.radius == rayon_normal, "le bonus expire et le rayon revient à la normale")
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
	_check(JL.vies == 3 and hud._coeurs[2].visible, "mode Facile : 3 vies affichées")
	_check(abs(GS.seuil_victoire() - 0.85) < 0.001 and abs(hud.repere_seuil.offset_left + 1.5 - 0.85 * hud.progression.size.x) < 2.0,
		"seuil de victoire 85 %% en Facile, repère placé sur la barre")
	var coccinelle: Node = spawner.spawn_coccinelle(lion.global_position.y + 66)
	coccinelle.position.x = lion.global_position.x + 68
	await _frames(3)
	_check(GS.partie_en_cours and JL.vies == 2, "un coup coûte une vie, la partie continue (%d vies)" % JL.vies)
	_check(JL.est_invulnerable() and absf(JL.invulnerable_restant - ReglesSolo.DUREE_INVULNERABILITE) < 0.2
		and not GS.get_script().get_script_constant_map().has("DUREE_INVULNERABILITE"),
		"le lion est invulnérable après un coup, pour la durée que fixent les règles du solo (plus GameState)")
	_check(lion._recul.length() > 0.0, "le lion est repoussé par le coup (%.0f px/s)" % lion._recul.length())
	_check(hud.flash.color.a > 0.0, "l'écran flashe en rouge")
	_check(main._tremblement_restant > 0.0, "la caméra tremble")
	_check(hud._coeurs[2].modulate == hud.COULEUR_COEUR_PERDU, "le HUD grise le cœur perdu")
	coccinelle.queue_free()
	var soucoupe2: Node = spawner.spawn_soucoupe(lion.global_position.y + 66)
	soucoupe2.position.x = lion.global_position.x + 68
	await _frames(3)
	_check(JL.vies == 2, "un coup pendant l'invulnérabilité ne compte pas")
	soucoupe2.queue_free()
	JL.invulnerable_restant = 0.0

	# Cœur : rend une vie, jamais au-delà du maximum
	sons_avant = _sons.count("pickup")
	var coeur: Node = spawner.spawn_coeur(lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(coeur) and JL.vies == 3, "un cœur ramassé rend une vie (%d)" % JL.vies)
	_check(_sons.count("pickup") == sons_avant + 1, "le cœur joue le son de ramassage, par Audio (%d)" % (_sons.count("pickup") - sons_avant))
	_check(not GS.regles.coeur_ramasse(JL), "impossible de dépasser le maximum de vies")

	# Défaite : trois coups, le doigt toujours sur le stick
	stick.debut(Vector2(300, 500))
	stick.glisser(Vector2(300 + stick.rayon, 500))
	JL.vies = 1
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
	_check(overlay != null and overlay._lignes.size() == 4 and overlay._lignes[2].cible == JL.coups_recus and JL.coups_recus == 2,
		"le bilan de défaite a 4 lignes et compte les coups reçus (%d)" % JL.coups_recus)
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
	_check(JL.couleurs_debloquees.is_empty() and main.get_node("Lion").vomi_container.get_child_count() == 0
		and main.get_node("HUD")._pastilles[0].color == main.get_node("HUD").COULEUR_VERROUILLEE,
		"une nouvelle partie repart sans couleur : ni émetteur, ni pastille allumée")
	_check(JL.vies == 3 and JL.coups_recus == 0 and main.get_node("HUD")._coeurs[2].modulate == main.get_node("HUD").COULEUR_COEUR,
		"après une défaite, le niveau suivant repart avec tous ses cœurs affichés")
	# La défaite a laissé 0 vie ; `nouvelle_partie` en a remis 3 sans signal : un coup (3 → 2) n'est
	# pas une vie regagnée.
	sons_avant = _sons.count("pickup")
	JL.encaisser_coup(Vector2.INF, 0.0)
	_check(JL.vies == 2 and _sons.count("pickup") == sons_avant,
		"un coup au départ d'une nouvelle partie (vies remises sans signal) ne joue pas le son de ramassage")
	JL.vies = 3
	JL.coups_recus = 0
	ville = main.get_node("Ville")
	_check(ville.tex_size == Vector2i(2000, 320), "la ville a chargé la skyline du niveau Métropole (%s)" % ville.tex_size)
	GS.regles.pastille_ramassee(JL, 0)
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	# un seul tampon clairsemé ne suffit pas : la couverture réelle est mesurée
	ville.peindre(Vector2(1000, haut + 200), 45, JL)
	ville.mesurer_progression()
	_check(GS.progression < 0.01, "un tampon isolé ne compte presque pas (couverture %.3f)" % GS.progression)
	for x in range(0, ville.tex_size.x, 40):
		for y in range(0, ville.tex_size.y, 40):
			ville.peindre(Vector2(x, haut + y), 45, JL)
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
	var vies_avant: int = JL.vies
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
	_check(JL.vies < vies_avant, "le boss blesse le lion au passage (%d → %d)" % [vies_avant, JL.vies])
	# Les deux chemins de contact du peintre : body_entered, puis le contact continu hors repos.
	# Un lion resté à son contact est frappé dès la fin de son invulnérabilité, sans nouveau
	# body_entered ; le coup part de la verticale du peintre, à la hauteur du lion : le recul est
	# horizontal.
	boss._arreter()
	boss.etat = boss.Etat.PAUSE
	boss.position.x = 1000.0
	lion.global_position = Vector2(1000 - 60 - 68, boss.position.y - 120 - 66)
	lion.direction_du_lion = -1  # dos au peintre : le repli par défaut pointerait vers lui, à l'envers
	JL.vies = 3
	JL.invulnerable_restant = 0.3
	await _frames(3)
	_check(boss.get_overlapping_bodies().has(lion) and JL.vies == 3,
		"(pré-condition) le lion, invulnérable, est au contact du peintre et n'a rien perdu")
	await create_timer(0.4).timeout
	await _frames(2)
	_check(JL.vies == 2, "un lion resté au contact du peintre est frappé dès la fin de son invulnérabilité (contact continu)")
	_check(lion._recul.normalized().is_equal_approx(Vector2(-1, 0)),
		"le coup du peintre part de sa verticale, à la hauteur du lion : le recul est horizontal, loin du peintre (%s)" % lion._recul)
	boss.etat = boss.Etat.REPOS  # au repos, hors de l'écran : il ne touche plus rien
	boss.position.x = boss._x_hors_ecran()
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
	_check(JL.vies == 1 and not hud._coeurs[1].visible, "mode Hardcore : un seul cœur affiché")
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
	GS.regles.pastille_ramassee(JL, 3)
	_check(lion_autre.vomi_container.get_child_count() == 0, "une couleur du joueur local ne touche pas un lion lié à un autre joueur")
	autre.debloquer_couleur(Color.RED)
	_check(lion_autre.vomi_container.get_child_count() == 1, "le lion reconstruit sa gerbe quand son propre joueur débloque une couleur")
	var rayon_autre: float = lion_autre.traceuse_shape.shape.radius
	JL.activer_bonus(5.0)
	_check(lion_autre.traceuse_shape.shape.radius == rayon_autre, "le bonus du joueur local ne touche pas un lion lié à un autre joueur")
	JL.bonus_restant = 0.0
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

	# Ennemis et pastilles signalent le lion qu'ils touchent, pas le joueur local
	var local: Joueur = GS.joueur_local()
	var vies_local_avant: int = local.vies
	# La partie Hardcore vient de se terminer : le joueur local est à 0 vie, or
	# `Joueur.encaisser_coup` n'émet `touche` que si `vies > 0` après le coup, donc un coup
	# mal routé vers le joueur local ne déclencherait jamais `touches_locales` et la moitié
	# « pas de retour local » des vérifications ci-dessous serait toujours vraie à tort.
	# On le remet à 3 vies, invulnérabilité coupée, pour qu'il soit de nouveau touchable.
	local.vies = 3
	local.invulnerable_restant = 0.0
	var vies_local: int = local.vies
	var couleurs_local: int = local.couleurs_debloquees.size()
	var touches_locales: Array[Vector2] = []
	var sur_touche_locale := func(o: Vector2) -> void: touches_locales.append(o)
	JL.touche.connect(sur_touche_locale)
	# La coccinelle qui a infligé la défaite Hardcore n'a jamais été libérée : elle continue de
	# zigzaguer vers la gauche et peut retraverser le lion local, désormais de nouveau touchable
	# ci-dessus, ce qui rendait ce test instable. On libère tout ennemi encore en jeu (et le peintre,
	# s'il y en avait un) avant de continuer.
	for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss"):
		ennemi.free()
	# Le Spawner de la partie Hardcore a encore des apparitions programmées (minuteries) :
	# on le libère aussi, pour que rien d'autre que cette section n'agisse pendant qu'elle tourne.
	main.get_node("Spawner").free()
	spawner = null
	GS.partie_en_cours = true  # la partie Hardcore est finie : les règles ignorent les coups hors partie
	lion_autre.commandes.direction_voulue = Vector2.ZERO
	lion_autre.global_position = Vector2(1400, 300)  # loin du lion local, resté dans la scène
	await _frames(1)
	autre.vies = 3  # deux coups à venir : jamais le coup fatal, qui terminerait la partie
	autre.invulnerable_restant = 0.0
	var centre_autre: Vector2 = lion_autre.global_position + Vector2(68, 66)
	var coccinelle_autre: Node2D = load("res://Scenes/Coccinelle.tscn").instantiate()
	coccinelle_autre.position = centre_autre
	root.add_child(coccinelle_autre)
	await _frames(3)
	_check(autre.vies == 2 and local.vies == vies_local and touches_locales.is_empty(),
		"une coccinelle retire une vie au joueur du lion touché, pas au joueur local")
	coccinelle_autre.queue_free()
	autre.invulnerable_restant = 0.0
	var soucoupe_autre: Node2D = load("res://Scenes/Soucoupe.tscn").instantiate()
	soucoupe_autre.position = centre_autre
	root.add_child(soucoupe_autre)
	await _frames(3)
	_check(autre.vies == 1 and local.vies == vies_local and touches_locales.is_empty(),
		"une soucoupe retire une vie au joueur du lion touché, pas au joueur local")
	soucoupe_autre.queue_free()
	var pastille_autre: Node2D = load("res://Scenes/ColorPickup.tscn").instantiate()
	pastille_autre.couleur_index = 4  # autre n'a que le rouge
	pastille_autre.position = centre_autre
	var sons_locaux := _sons.count("pickup")
	root.add_child(pastille_autre)
	await _frames(3)
	_check(not is_instance_valid(pastille_autre) and autre.couleurs_debloquees.has(GS.couleur(4))
		and local.couleurs_debloquees.size() == couleurs_local,
		"une pastille ramassée par un lion va à son joueur, pas au joueur local")
	var bonus_local: bool = local.bonus_actif()
	autre.bonus_restant = 0.0
	var etoile_autre: Node2D = load("res://Scenes/BonusPickup.tscn").instantiate()
	etoile_autre.position = centre_autre
	root.add_child(etoile_autre)
	await _frames(3)
	_check(not is_instance_valid(etoile_autre) and autre.bonus_actif()
		and is_equal_approx(autre.bonus_restant, Regles.DUREE_ETOILE) and local.bonus_actif() == bonus_local,
		"une étoile ramassée par un lion active la gerbe XXL de son joueur, pas celle du joueur local")
	_check(_sons.count("pickup") == sons_locaux, "ce que ramasse un autre lion ne joue pas le son de ramassage de ce poste")
	var coeur_autre: Node2D = load("res://Scenes/CoeurPickup.tscn").instantiate()
	coeur_autre.position = Vector2(-500, -500)  # hors d'atteinte : les contacts sont simulés à la main
	root.add_child(coeur_autre)
	await _frames(1)
	autre.vies = 1
	local.vies = 2
	coeur_autre._on_body_entered(lion_autre)
	coeur_autre._on_body_entered(main.get_node("Lion"))  # le lion local touche le même cœur dans la même frame
	_check(autre.vies == 2 and local.vies == 2, "premier arrivé, premier servi : un seul lion profite d'un cœur touché par deux lions")
	await _frames(1)
	_check(not is_instance_valid(coeur_autre), "le cœur ramassé disparaît")

	# Bases communes des ennemis et des pastilles : seul un lion compte (`body is Lion`, pas le
	# groupe « lion »), et seul l'hôte tranche un contact
	var bases: Array = ["Soucoupe", "Coccinelle", "Boss"].map(func(nom: String) -> String:
		var base: Script = load("res://Scripts/%s.gd" % nom).get_base_script()
		return "" if base == null else base.resource_path)
	_check(bases.all(func(p: String) -> bool: return p == "res://Scripts/Ennemi.gd"),
		"soucoupe, coccinelle et peintre dérivent de la base Ennemi (%s)" % [bases])
	var bases_pastilles: Array = ["ColorPickup", "BonusPickup", "CoeurPickup"].map(func(nom: String) -> String:
		var base: Script = load("res://Scripts/%s.gd" % nom).get_base_script()
		return "" if base == null else base.resource_path)
	_check(bases_pastilles.all(func(p: String) -> bool: return p == "res://Scripts/Pastille.gd"),
		"pastille de couleur, étoile et cœur dérivent de la base Pastille (%s)" % [bases_pastilles])
	# L'intrus a un champ `joueur`, comme un lion : sous l'ancien typage (groupe « lion » puis
	# `body.joueur`), il serait accepté.
	var script_intrus := GDScript.new()
	script_intrus.source_code = "extends CharacterBody2D\nvar joueur: Joueur = Joueur.new()\n"
	script_intrus.reload()
	var intrus := CharacterBody2D.new()  # sur la couche 1 et dans le groupe « lion », mais pas un lion
	intrus.set_script(script_intrus)
	intrus.add_to_group("lion")
	var forme_intrus := CollisionShape2D.new()
	forme_intrus.shape = CircleShape2D.new()
	forme_intrus.shape.radius = 30.0
	intrus.add_child(forme_intrus)
	intrus.position = Vector2(300, -400)  # hors de l'écran, loin des lions
	root.add_child(intrus)
	var soucoupe_intrus: Node2D = load("res://Scenes/Soucoupe.tscn").instantiate()
	soucoupe_intrus.position = intrus.position
	root.add_child(soucoupe_intrus)
	await _frames(3)
	_check(soucoupe_intrus.get_overlapping_bodies().has(intrus) and autre.vies == 2 and local.vies == 2
		and intrus.joueur.vies == 3 and not intrus.joueur.est_invulnerable(),
		"un ennemi ignore un corps qui n'est pas un lion, même dans le groupe « lion » et avec un joueur")
	soucoupe_intrus.free()
	for nom in ["ColorPickup", "BonusPickup", "CoeurPickup"]:
		var pastille_intrus: Area2D = load("res://Scenes/%s.tscn" % nom).instantiate()
		pastille_intrus.position = intrus.position
		root.add_child(pastille_intrus)
		await _frames(3)
		_check(is_instance_valid(pastille_intrus) and pastille_intrus.get_overlapping_bodies().has(intrus)
			and intrus.joueur.couleurs_debloquees.is_empty() and intrus.joueur.crans == 1 and not intrus.joueur.bonus_actif(),
			"%s : une pastille ignore un corps qui n'est pas un lion, même dans le groupe « lion » et avec un joueur" % nom)
		if is_instance_valid(pastille_intrus):
			pastille_intrus.free()
	intrus.free()
	autre.invulnerable_restant = 0.0
	lion_autre._recul = Vector2.ZERO  # le recul des coups précédents l'éloigne encore
	lion_autre.global_position = Vector2(1400, 300)
	await _frames(1)
	var poste_client := Node2D.new()  # sous-arbre dont le pair multijoueur est un client
	poste_client.name = "PosteClient"
	root.add_child(poste_client)
	var api_client := SceneMultiplayer.new()
	var pair_client := ENetMultiplayerPeer.new()
	_check(pair_client.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client, jamais connecté : un client qui attend l'hôte")
	api_client.multiplayer_peer = pair_client
	set_multiplayer(api_client, poste_client.get_path())
	var coccinelle_client: Node2D = load("res://Scenes/Coccinelle.tscn").instantiate()
	coccinelle_client.position = lion_autre.global_position + Vector2(68, 66)
	poste_client.add_child(coccinelle_client)
	await _frames(3)
	_check(not coccinelle_client.multiplayer.is_server() and coccinelle_client.get_overlapping_bodies().has(lion_autre)
		and autre.vies == 2 and not autre.est_invulnerable(),
		"sur un client, un ennemi au contact d'un lion ne le signale pas aux règles (seul l'hôte tranche)")
	coccinelle_client.free()
	var crans_client := autre.crans
	var pastille_client: Area2D = load("res://Scenes/ColorPickup.tscn").instantiate()
	pastille_client.couleur_index = 6
	pastille_client.position = lion_autre.global_position + Vector2(68, 66)
	poste_client.add_child(pastille_client)
	var etoile_client: Area2D = load("res://Scenes/BonusPickup.tscn").instantiate()
	etoile_client.position = Vector2(-500, -500)
	poste_client.add_child(etoile_client)
	await _frames(3)
	_check(is_instance_valid(pastille_client) and pastille_client.get_overlapping_bodies().has(lion_autre)
		and not autre.couleurs_debloquees.has(GS.couleur(6)) and autre.crans == crans_client,
		"sur un client, une pastille au contact d'un lion n'est pas ramassée (seul l'hôte tranche)")
	if etoile_client.has_method("_expirer"):
		etoile_client._expirer()
	await _frames(1)
	_check(is_instance_valid(etoile_client) and etoile_client.has_method("_expirer"),
		"sur un client, une étoile en fin de vie ne se libère pas d'elle-même (l'hôte la fait disparaître)")
	set_multiplayer(null, poste_client.get_path())
	pair_client.close()
	poste_client.free()

	# La traceuse d'un lion peint avec les couleurs de son propre joueur. Le lion local peint
	# d'abord, avec autant de couleurs et le même rayon que l'autre lion : la ville garde ses
	# tampons par jeu de couleurs, l'autre lion ne doit donc pas reprendre ceux du lion local.
	var ville_hc: Node = main.get_node("Ville")
	GS.regles.pastille_ramassee(local, 5)  # le joueur local : vert et bleu, 3 crans
	autre.gagner_cran()  # l'autre joueur : rouge et cyan, 3 crans
	autre.avancer(Regles.DUREE_ETOILE)  # fin de la gerbe XXL de l'étoile ramassée plus haut (autre n'est pas dans GS.joueurs)
	_check(local.couleurs_debloquees.size() == autre.couleurs_debloquees.size()
		and lion.traceuse_shape.shape.radius == lion_autre.traceuse_shape.shape.radius
		and not local.couleurs_debloquees.any(func(c: Color) -> bool: return autre.couleurs_debloquees.has(c)),
		"(pré-condition) les deux lions ont autant de couleurs, le même rayon (%.0f px) et aucune couleur commune" % lion.traceuse_shape.shape.radius)
	lion.global_position = Vector2(600, ville_hc.position.y - 300)
	Input.action_press("vomir")
	await _frames(20)
	Input.action_release("vomir")
	await _frames(2)
	_check(not _couleurs_peintes(ville_hc.image).is_empty(), "(pré-condition) le lion local a peint la ville le premier")
	ville_hc.image.fill(Color(0, 0, 0, 0))
	ville_hc.coulures.clear()  # celles du lion local couleraient encore dans ses couleurs
	lion_autre.commandes.vomir_voulu = true
	await _frames(20)
	lion_autre.commandes.vomir_voulu = false
	await _frames(2)
	var couleurs_peintes := _couleurs_peintes(ville_hc.image)
	var rgba32_autre: Array = autre.couleurs_debloquees.map(_rgba8)
	_check(not couleurs_peintes.is_empty()
		and couleurs_peintes.keys().all(func(k: int) -> bool: return rgba32_autre.has(k)),
		"la traceuse d'un lion peint avec les couleurs de son joueur, même après un lion qui en a autant (%d couleur(s) sur la ville)" % couleurs_peintes.size())
	JL.touche.disconnect(sur_touche_locale)
	GS.partie_en_cours = false
	local.vies = vies_local_avant  # on restaure l'état d'avant la section, mort Hardcore compris
	lion_autre.free()
	_check(autre.couleur_debloquee.get_connections().is_empty() and autre.touche.get_connections().is_empty(),
		"le lion libéré se désabonne de son joueur")
	autre.debloquer_couleur(Color.BLUE)
	autre = null

	# Bataille : crinière à la couleur du joueur, pseudo au-dessus du lion
	var shader_lion: Shader = load("res://Shaders/Lion.gdshader")
	var uniformes: Array = [] if shader_lion == null else shader_lion.get_shader_uniform_list().map(
		func(u: Dictionary) -> String: return u.name)
	_check(uniformes.has("couleur_joueur") and uniformes.has("barbouillage_couleur") and uniformes.has("barbouillage_force"),
		"le shader du lion compile et expose couleur_joueur, barbouillage_couleur et barbouillage_force (%s)" % [uniformes])
	var rouge := Joueur.new()
	rouge.couleur = Color(0.90, 0.16, 0.16)
	rouge.pseudo = "Alice"
	var bleu := Joueur.new()
	bleu.couleur = Color(0.16, 0.39, 0.95)
	var sans_couleur := Joueur.new()
	sans_couleur.pseudo = "Solo"
	var lions_teintes: Array[Node] = []
	for j: Joueur in [rouge, bleu, sans_couleur]:
		var l: Node = load("res://Scenes/Lion.tscn").instantiate()
		l.joueur = j
		l.commandes = Commandes.manuelles()
		l.position = Vector2(200 + 300 * lions_teintes.size(), 0)
		root.add_child(l)
		lions_teintes.append(l)
	await _frames(1)
	var mat_rouge := lions_teintes[0].sprite.material as ShaderMaterial
	var mat_bleu := lions_teintes[1].sprite.material as ShaderMaterial
	_check(mat_rouge != null and mat_rouge.shader == shader_lion and mat_rouge.get_shader_parameter("couleur_joueur") == rouge.couleur,
		"le lion d'un joueur coloré porte le shader de teinte, à la couleur de son joueur")
	_check(mat_bleu != null and mat_bleu != mat_rouge and mat_bleu.get_shader_parameter("couleur_joueur") == bleu.couleur,
		"deux lions ont chacun leur matériau, chacun à la couleur de son joueur")
	_check(lions_teintes[2].sprite.material == null and not lions_teintes[2].etiquette_pseudo.visible,
		"un joueur sans couleur garde le rendu d'origine et n'affiche pas son pseudo, même s'il en a un")
	bleu.couleur = Color(0.10, 0.85, 0.90)
	lions_teintes[1].appliquer_apparence()
	_check(mat_bleu.get_shader_parameter("couleur_joueur") == bleu.couleur and mat_rouge.get_shader_parameter("couleur_joueur") == rouge.couleur,
		"réappliquer l'apparence après un changement de couleur ne retouche que le lion de ce joueur")
	bleu.couleur = Color.TRANSPARENT
	lions_teintes[1].appliquer_apparence()
	_check(lions_teintes[1].sprite.material == null, "un joueur redevenu sans couleur rend au lion son rendu d'origine")
	var etiquette: Label = lions_teintes[0].etiquette_pseudo
	var haut_sprite: float = lions_teintes[0].sprite.position.y - lions_teintes[0].sprite.texture.get_height() / 2.0
	_check(etiquette.visible and etiquette.text == "Alice" and etiquette.get_theme_color("font_color") == rouge.couleur,
		"le pseudo du joueur s'affiche dans sa couleur")
	_check(etiquette.get_rect().end.y <= haut_sprite and absf(etiquette.get_rect().get_center().x - lions_teintes[0].sprite.position.x) < 1.0,
		"le pseudo est au-dessus de la tête du lion, centré")
	_check(not lions_teintes[1].etiquette_pseudo.visible, "un joueur sans pseudo n'affiche pas d'étiquette")
	rouge.debloquer_couleur(Color.RED)
	GS.pret = true
	lions_teintes[0].commandes.vomir_voulu = true
	for i in range(3):
		await process_frame  # le vomi démarre dans _process et l'AnimationPlayer change de sprite au même rythme
	_check(lions_teintes[0].est_en_train_de_vomir and lions_teintes[0].sprite.texture.resource_path.ends_with("LionHeadVomit.png")
		and lions_teintes[0].sprite.material == mat_rouge,
		"en vomissant, le sprite de vomi garde le matériau de teinte du joueur")
	lions_teintes[0].commandes.vomir_voulu = false
	await _frames(2)
	for l in lions_teintes:
		l.free()

	# Bataille : lions de bataille, dans une scène propre. La partie Hardcore est libérée d'abord
	# (son lion, sa ville) : rien des sections précédentes ne doit toucher ces lions.
	paused = false
	main.free()
	main = null
	GS.configurer_bataille(2)
	GS.nouvelle_partie()
	GS.pret = true
	# Ce test contourne l'intro (`GameState.demarrer`), qui émettrait `partie_prete` en jeu réel et
	# resynchroniserait Audio (vies et crans) sur le joueur local après le `reinitialiser` silencieux
	# de `nouvelle_partie` : on le fait à la main pour ne pas hériter d'un `_crans_vus` d'une section
	# précédente.
	root.get_node("Audio")._on_partie_prete()
	var j_rouge: Joueur = GS.joueurs[0]
	var j_bleu: Joueur = GS.joueurs[1]
	var lions_bataille: Array[CharacterBody2D] = []
	for j: Joueur in GS.joueurs:
		var l: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
		l.joueur = j
		l.commandes = Commandes.manuelles()
		l.position = Vector2(200 + 1000 * lions_bataille.size(), 100)
		root.add_child(l)
		lions_bataille.append(l)
	var lr: CharacterBody2D = lions_bataille[0]
	var lb: CharacterBody2D = lions_bataille[1]
	await _frames(2)

	# Gerbe en trois nuances, rayon selon les crans
	var couleurs_gerbe: Array = lr.vomi_container.get_children().map(
		func(e: GPUParticles2D) -> Color: return (e.process_material as ParticleProcessMaterial).color_ramp.gradient.get_color(0))
	_check(couleurs_gerbe == j_rouge.nuances(), "un lion de bataille a trois émetteurs, aux nuances de son joueur (%s)" % [couleurs_gerbe])
	_check(lr.traceuse_shape.shape.radius == 16.0, "au premier cran, la gerbe peint sur 16 px")
	var sons_bataille := _sons.count("pickup")
	GS.regles.pastille_ramassee(j_rouge, 0)
	_check(lr.traceuse_shape.shape.radius == 21.0 and lb.traceuse_shape.shape.radius == 16.0, "une pastille donne un cran : 5 px de plus, pour ce lion seulement")
	_check(GS.joueur_local() == j_rouge and _sons.count("pickup") == sons_bataille + 1,
		"en bataille, le cran d'une pastille (aucune couleur débloquée) joue le son de ramassage du joueur local")
	for i in range(10):
		GS.regles.pastille_ramassee(j_rouge, 0)
	_check(lr.traceuse_shape.shape.radius == 46.0, "au septième cran, la gerbe peint sur 46 px")
	lr.commandes.vomir_voulu = true
	for i in range(3):
		await process_frame  # le vomi démarre dans _process
	_check(lr.est_en_train_de_vomir, "un lion de bataille vomit dès le départ, sans pastille")
	lr.commandes.vomir_voulu = false
	await _frames(2)

	# Reliquats de la phase 7 : apparence appliquée trop tôt, matériau d'un autre shader
	var lion_neuf: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
	lion_neuf.joueur = Joueur.new()
	lion_neuf.joueur.couleur = Color(0.18, 0.78, 0.25)
	lion_neuf.commandes = Commandes.manuelles()
	lion_neuf.position = Vector2(700, 400)
	lion_neuf.appliquer_apparence()
	root.add_child(lion_neuf)
	await _frames(1)
	_check(lion_neuf.sprite.material is ShaderMaterial and lion_neuf.sprite.material.shader == shader_lion,
		"appliquer_apparence avant l'ajout à l'arbre ne fait rien ; _ready teinte le lion")
	var materiau_etranger := ShaderMaterial.new()
	materiau_etranger.shader = load("res://Shaders/Ville.gdshader")
	lion_neuf.sprite.material = materiau_etranger
	lion_neuf.appliquer_apparence()
	_check(lion_neuf.sprite.material != materiau_etranger and lion_neuf.sprite.material.shader == shader_lion,
		"un matériau d'un autre shader sur le sprite est remplacé par celui de la teinte")
	lion_neuf.free()

	# Étourdissement par un ennemi : immobile, repoussé, étoiles, sans barbouillage
	var materiau_bleu := lb.sprite.material as ShaderMaterial
	lb.commandes.direction_voulue = Vector2.LEFT
	await _frames(5)
	_check(lb._vitesse.x < 0.0, "(pré-condition) le lion bleu avance selon ses commandes")
	materiau_bleu.set_shader_parameter("barbouillage_force", 0.5)  # pour un check discriminant : un ennemi doit bien la remettre à 0
	GS.regles.lion_touche_par_ennemi(j_bleu, lb.global_position + lb.CENTRE + Vector2(-80, 0))
	_check(j_bleu.est_etourdi() and lb._vitesse == Vector2.ZERO and lb._recul.x > 0.0 and lb.etoiles.visible,
		"un ennemi étourdit le lion : il s'arrête, il est repoussé, des étoiles tournent")
	_check(materiau_bleu.get_shader_parameter("barbouillage_force") == 0.0, "un ennemi ne barbouille pas")
	lb.commandes.vomir_voulu = true
	var position_etoile: Vector2 = lb.etoiles.get_child(0).position
	await _frames(10)
	_check(lb._vitesse == Vector2.ZERO and not lb.est_en_train_de_vomir, "étourdi, le lion ignore ses commandes : ni déplacement ni vomi")
	_check(lb.etoiles.get_child(0).position != position_etoile, "les étoiles tournent autour de la tête")
	j_bleu.etourdi_restant = 0.05
	await create_timer(0.1).timeout
	await _frames(2)
	_check(not j_bleu.est_etourdi() and not lb.etoiles.visible and j_bleu.est_invulnerable()
		and lb._clignotement != null and lb._clignotement.is_running(),
		"à la fin de l'étourdissement, les étoiles s'en vont et l'immunité clignote")
	_check(lb._vitesse.x < 0.0 and lb.est_en_train_de_vomir, "le lion obéit de nouveau à ses commandes")
	GS.regles.lion_touche_par_ennemi(j_bleu, Vector2.INF)
	_check(not j_bleu.est_etourdi(), "un ennemi ne ré-étourdit pas un lion immunisé")

	# Étourdissement par le vomi : tête barbouillée de la couleur de l'agresseur
	j_bleu.invulnerable_restant = 0.0
	GS.regles.lion_touche_par_vomi(j_bleu, j_rouge, lb.global_position + lb.CENTRE + Vector2(0, -80))
	_check(materiau_bleu.get_shader_parameter("barbouillage_couleur") == j_rouge.couleur
		and is_equal_approx(materiau_bleu.get_shader_parameter("barbouillage_force"), lb.FORCE_BARBOUILLAGE)
		and materiau_bleu.get_shader_parameter("couleur_joueur") == j_bleu.couleur,
		"le vomi barbouille la tête de la couleur de l'agresseur, par-dessus la teinte du joueur")
	await _frames(3)
	_check(not lb.est_en_train_de_vomir and not lb.gerbe_traceuse.monitoring, "étourdi en plein vomi, le lion arrête de vomir")
	j_bleu.etourdi_restant = 0.05
	await create_timer(0.1).timeout
	await _frames(2)
	_check(materiau_bleu.get_shader_parameter("barbouillage_force") == 0.0, "le barbouillage s'efface à la fin de l'étourdissement")

	# Un vrai ennemi, en plein vomi : l'étourdissement part d'un rappel physique (body_entered)
	j_bleu.invulnerable_restant = 0.0
	lb.commandes.direction_voulue = Vector2.ZERO
	await _frames(3)
	_check(lb.est_en_train_de_vomir, "(pré-condition) le lion bleu vomit")
	var coccinelle_bataille: Node2D = load("res://Scenes/Coccinelle.tscn").instantiate()
	coccinelle_bataille.position = lb.global_position + lb.CENTRE
	root.add_child(coccinelle_bataille)
	await _frames(3)
	_check(j_bleu.est_etourdi() and j_bleu.vies == 3 and not lb.est_en_train_de_vomir,
		"une coccinelle étourdit le lion de bataille qu'elle touche, sans lui ôter de vie ; il arrête de vomir")
	coccinelle_bataille.free()
	lb.commandes.vomir_voulu = false
	await _frames(2)
	j_bleu.etourdi_restant = 0.0
	j_bleu.invulnerable_restant = 0.0

	# Auto-guérison des effets visuels : `Joueur.reinitialiser` n'émet aucun signal
	# (contrairement à `Joueur.etourdir`) ; le lion doit s'en remettre tout seul au `_process` suivant
	var couleurs_j_bleu := j_bleu.couleurs_debloquees.duplicate()
	GS.regles.lion_touche_par_vomi(j_bleu, j_rouge, lb.global_position + lb.CENTRE + Vector2(0, -80))
	await _frames(2)
	_check(j_bleu.est_etourdi() and lb.etoiles.visible and materiau_bleu.get_shader_parameter("barbouillage_force") > 0.0,
		"(pré-condition) le lion bleu est étourdi et barbouillé, étoiles visibles")
	j_bleu.reinitialiser(3, couleurs_j_bleu)
	await _frames(3)
	_check(not lb.etoiles.visible and materiau_bleu.get_shader_parameter("barbouillage_force") == 0.0,
		"Joueur.reinitialiser en plein étourdissement n'émet rien : étoiles et barbouillage se corrigent tout seuls")
	j_bleu.etourdi_restant = 0.0
	j_bleu.invulnerable_restant = 0.0

	# Zones de contact : trois, le long de la parabole, jusqu'au point de chute
	var zones: Array[Area2D] = lr.zones_contact
	_check(zones.size() == 3 and zones[2].position.is_equal_approx(lr.gerbe_traceuse.position)
		and zones[0].position.y < zones[1].position.y and zones[1].position.y < zones[2].position.y
		and zones.all(func(z: Area2D) -> bool: return z.collision_layer == 0 and not z.monitoring),
		"trois zones de contact sur la parabole, la dernière au point de chute, inertes hors du vomi")
	_check(zones[0].get_child(0).shape != lb.zones_contact[0].get_child(0).shape, "chaque lion a ses propres formes de zones de contact")
	j_bleu.invulnerable_restant = 0.0
	var infliges_avant: int = j_rouge.etourdissements_infliges
	lb._recul = Vector2.ZERO
	lb.global_position = lr.to_global(zones[1].position) - lb.CENTRE
	await _frames(2)
	lr.commandes.vomir_voulu = true
	for i in range(30):  # vomi démarré au _process, contacts connus au tick physique suivant
		await _frames(1)
		if j_bleu.est_etourdi():
			break
	_check(j_bleu.est_etourdi() and materiau_bleu.get_shader_parameter("barbouillage_couleur") == j_rouge.couleur
		and j_rouge.etourdissements_infliges == infliges_avant + 1 and not j_rouge.est_etourdi(),
		"la gerbe d'un lion étourdit l'autre lion qu'elle touche, barbouillé de sa couleur, et lui compte l'étourdissement")
	var etourdi_apres_coup: float = j_bleu.etourdi_restant
	await _frames(10)
	_check(j_rouge.etourdissements_infliges == infliges_avant + 1 and j_bleu.etourdi_restant < etourdi_apres_coup,
		"un lion déjà étourdi n'est pas ré-étourdi par la gerbe qui le touche encore")
	lr.commandes.vomir_voulu = false
	await _frames(3)  # le vomi s'arrête au _process suivant : pas de nouveau contact ensuite
	j_bleu.etourdi_restant = 0.0
	j_bleu.invulnerable_restant = 0.0

	# Auto-tamponneuses : pare-chocs réduit, recul proportionnel à la vitesse d'approche
	_check(lr.collision_mask == 0 and lr.pare_chocs.collision_layer == 16 and lr.pare_chocs.collision_mask == 16
		and is_equal_approx(lr._rayon_choc, 45.0) and lr.get_node("CollisionShape2D").shape.radius > 60.0,
		"les lions se heurtent sur leur couche dédiée, à 45 px ; le corps (63 px) reste celui que touchent ennemis et pastilles")
	lr._recul = Vector2.ZERO
	lb._recul = Vector2.ZERO
	lr.global_position = Vector2(600, 300)
	lb.global_position = Vector2(800, 300)
	await _frames(2)
	lr.commandes.direction_voulue = Vector2.RIGHT
	for i in range(90):
		await _frames(1)
		if j_rouge.chocs > 0:
			break
	lr.commandes.direction_voulue = Vector2.ZERO
	_check(j_rouge.chocs == 1 and j_bleu.chocs == 1, "un choc est compté une fois, pour les deux lions")
	_check(lr._recul.x < 0.0 and lb._recul.x > 0.0 and lr._secousse_restante > 0.0 and lb._secousse_restante > 0.0,
		"au choc, les deux lions reculent chacun de son côté, et leur sprite tremble")
	_check(not j_rouge.est_etourdi() and not j_bleu.est_etourdi(), "un choc n'étourdit personne")
	var distance_min := 1e9
	for i in range(30):
		await _frames(1)
		distance_min = minf(distance_min, lr.pare_chocs.global_position.distance_to(lb.pare_chocs.global_position))
	_check(distance_min > 2 * 45.0 - 15.0 and j_rouge.chocs == 1,
		"les lions ne s'enfoncent pas l'un dans l'autre (distance min %.0f px), un seul choc compté" % distance_min)

	# Poussée continue de 2 s (120 ticks physiques) contre un lion immobile : avant cette
	# correction, seul `_recul` s'opposait à `_vitesse` (qui ramenait aussitôt vers l'autre) et
	# chaque re-contact comptait, jusqu'à 14 chocs en 2 s ; `_vitesse` doit maintenant se
	# réaccélérer et le délai anti-rafale limiter le décompte.
	lr._recul = Vector2.ZERO
	lb._recul = Vector2.ZERO
	lr.global_position = Vector2(600, 300)
	lb.global_position = Vector2(800, 300)
	await _frames(2)
	var chocs_rouge_avant: int = j_rouge.chocs
	var chocs_bleu_avant: int = j_bleu.chocs
	distance_min = 1e9
	lr.commandes.direction_voulue = Vector2.RIGHT
	for i in range(120):
		await _frames(1)
		distance_min = minf(distance_min, lr.pare_chocs.global_position.distance_to(lb.pare_chocs.global_position))
	lr.commandes.direction_voulue = Vector2.ZERO
	_check(j_rouge.chocs - chocs_rouge_avant <= 2 and j_bleu.chocs - chocs_bleu_avant <= 2,
		"une poussée continue de 2 s ne rafale pas les chocs (%d, %d)" % [j_rouge.chocs - chocs_rouge_avant, j_bleu.chocs - chocs_bleu_avant])
	_check(distance_min >= 75.0, "les deux lions restent à au moins 75 px l'un de l'autre pendant la poussée continue (min %.0f px)" % distance_min)

	# Un lion étourdi peut être poussé
	GS.regles.lion_touche_par_ennemi(j_bleu, Vector2.INF)
	lb._recul = Vector2.ZERO
	lr._recul = Vector2.ZERO
	lr.global_position = Vector2(600, 300)
	lb.global_position = Vector2(800, 300)
	await _frames(2)
	var x_bleu: float = lb.global_position.x
	lr.commandes.direction_voulue = Vector2.RIGHT
	distance_min = 1e9
	for i in range(40):
		await _frames(1)
		distance_min = minf(distance_min, lr.pare_chocs.global_position.distance_to(lb.pare_chocs.global_position))
	lr.commandes.direction_voulue = Vector2.ZERO
	_check(j_bleu.est_etourdi() and lb.global_position.x > x_bleu + 10.0 and j_rouge.chocs >= 2,
		"un lion étourdi est poussé par celui qui le percute (%.0f px)" % (lb.global_position.x - x_bleu))
	_check(distance_min > 2 * 45.0 - 15.0, "même en poussant sans relâche, un lion ne s'enfonce pas dans l'autre (distance min %.0f px)" % distance_min)

	for l in lions_bataille:
		l.free()
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false

	# Territoire : la ville d'une bataille tient la grille de propriété, dans une scène propre
	# (sa ville, ses deux lions). Aucun ennemi des sections précédentes ne doit y entrer.
	for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss"):
		ennemi.free()
	GS.configurer_bataille(2)
	GS.nouvelle_partie()
	GS.pret = true
	var j_r: Joueur = GS.joueurs[0]
	var j_b: Joueur = GS.joueurs[1]
	var ville_b: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	root.add_child(ville_b)
	ville_b.position = Vector2(1000, 648 - ville_b.tex_size.y / 2.0)  # comme Main._placer_ville
	var lions_t: Array[CharacterBody2D] = []
	for j: Joueur in GS.joueurs:
		var l: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
		l.joueur = j
		l.commandes = Commandes.manuelles()
		l.position = Vector2(200 + 1000 * lions_t.size(), 0)
		root.add_child(l)
		lions_t.append(l)
	var l_r: CharacterBody2D = lions_t[0]
	var l_b: CharacterBody2D = lions_t[1]
	var poste_peinture := Vector2(600, ville_b.position.y - 300)
	await _frames(2)
	var t: Territoire = ville_b.territoire
	_check(t != null and t.nb_peignables == ville_b.cellules_peignables and t.cellules_de(0) == 0 and t.cellules_de(1) == 0,
		"en bataille, la ville tient un territoire vierge sur ses cellules peignables (%d)" % ville_b.cellules_peignables)
	_check(l_r.traceuse_shape.shape.radius == l_b.traceuse_shape.shape.radius and j_r.couleurs_debloquees.size() == j_b.couleurs_debloquees.size(),
		"(pré-condition) les deux lions ont le même rayon et autant de couleurs (trois nuances)")

	# Le lion rouge peint : ses cellules comptent pour lui, dans ses nuances
	l_r.global_position = poste_peinture
	await _frames(1)
	l_r.commandes.vomir_voulu = true
	await _frames(40)
	l_r.commandes.vomir_voulu = false
	await _frames(2)
	var cellules_rouges: int = t.cellules_de(0)
	var rgba32_rouge: Array = j_r.nuances().map(_rgba8)
	var rgba32_bleu: Array = j_b.nuances().map(_rgba8)
	_check(cellules_rouges > 0 and t.cellules_de(1) == 0, "les cellules que peint un lion comptent pour son joueur (%d)" % cellules_rouges)
	_check(not _couleurs_peintes(ville_b.image).is_empty()
		and _couleurs_peintes(ville_b.image).keys().all(func(k: int) -> bool: return rgba32_rouge.has(k)),
		"le lion rouge peint dans ses nuances")
	_check(t.extraire_changements().size() == cellules_rouges and t.extraire_changements().is_empty(),
		"les cellules qui se mettent à compter sont listées pour la synchronisation, une fois")

	# Le lion bleu repeint au même endroit : il vole les cellules du rouge, dans ses propres nuances
	l_r.global_position = Vector2(1500, 0)
	l_b.global_position = poste_peinture
	await _frames(1)
	ville_b.image.fill(Color(0, 0, 0, 0))
	ville_b.coulures.clear()
	l_b.commandes.vomir_voulu = true
	await _frames(40)
	l_b.commandes.vomir_voulu = false
	await _frames(2)
	_check(not _couleurs_peintes(ville_b.image).is_empty()
		and _couleurs_peintes(ville_b.image).keys().all(func(k: int) -> bool: return rgba32_bleu.has(k)),
		"à rayon et nombre de couleurs égaux, le second lion peint dans ses propres nuances")
	_check(t.cellules_de(1) > 0 and t.cellules_de(0) < cellules_rouges and j_b.cellules_volees > 0
		and j_b.cellules_volees == cellules_rouges - t.cellules_de(0) and j_r.cellules_volees == 0,
		"repeindre les cellules d'un autre les lui vole ; les règles comptent les vols (%d volées, %d restent au rouge)" % [j_b.cellules_volees, t.cellules_de(0)])

	# Sur un client, la ville dessine le tampon mais ne touche pas au territoire : l'hôte décide
	var api_ville := SceneMultiplayer.new()
	var pair_ville := ENetMultiplayerPeer.new()
	_check(pair_ville.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client pour la ville")
	api_ville.multiplayer_peer = pair_ville
	set_multiplayer(api_ville, ville_b.get_path())
	var scores_avant := [t.cellules_de(0), t.cellules_de(1)]
	var point_vierge := Vector2(1800, 648 - 20)  # bas de la skyline, à droite : jamais peint ici
	ville_b.image.fill(Color(0, 0, 0, 0))
	for i in range(10):
		ville_b.peindre(point_vierge, 30, j_r)
	_check(not ville_b.multiplayer.is_server() and not _couleurs_peintes(ville_b.image).is_empty()
		and [t.cellules_de(0), t.cellules_de(1)] == scores_avant,
		"sur un client, la ville dessine les tampons sans toucher au territoire")
	set_multiplayer(null, ville_b.get_path())
	pair_ville.close()
	for i in range(10):
		ville_b.peindre(point_vierge, 30, j_r)
	_check(t.cellules_de(0) > scores_avant[0], "de retour sur l'hôte, les mêmes tampons comptent")

	# Phase 14 : chaque tampon de l'hôte part en événement ; un client le dessine à l'identique (même
	# jeu de tampons, même variante, même coulure), centres négatifs compris, sans le rediffuser ni
	# toucher à son territoire. La traceuse d'un lion de client ne peint pas.
	var emis: Array[Dictionary] = []
	var sur_tampon := func(tampon: Dictionary) -> void: emis.append(tampon)
	ville_b.tampon_peint.connect(sur_tampon)
	ville_b.image.fill(Color(0, 0, 0, 0))
	ville_b.coulures.clear()
	ville_b._nb_tampons = 0  # comme une ville neuve : le plafond des coulures compte en tampons peints
	ville_b._tampons_des_coulures.clear()
	var coin_ville: Vector2 = ville_b.position - Vector2(ville_b.tex_size) / 2.0
	ville_b.peindre(coin_ville + Vector2(-10, 40), 30, j_r)  # déborde à gauche : x négatif
	for i in range(40):
		ville_b.peindre(coin_ville + Vector2(200 + 11 * i, 60), 21, j_b)
	ville_b.tampon_peint.disconnect(sur_tampon)
	_check(emis.size() == 41 and emis[0].index == 0 and emis[0].x == -10 and emis[0].rayon == 30 and emis[1].index == 1
		and ville_b.coulures.size() > 0,
		"sur l'hôte, chaque tampon part en événement (index du peintre, centre en pixels de la ville, rayon, graine), coulures comprises")
	var poste_c := Node2D.new()
	poste_c.name = "PosteClientVille"
	root.add_child(poste_c)
	var api_c := SceneMultiplayer.new()
	var pair_c := ENetMultiplayerPeer.new()
	_check(pair_c.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client pour la ville d'un client")
	api_c.multiplayer_peer = pair_c
	set_multiplayer(api_c, poste_c.get_path())
	var ville_c: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	ville_c.position = ville_b.position
	poste_c.add_child(ville_c)
	var emis_client: Array[Dictionary] = []
	ville_c.tampon_peint.connect(func(tampon: Dictionary) -> void: emis_client.append(tampon))
	for tampon in emis:
		ville_c.peindre_tampon_recu(tampon)
	_check(not ville_c.multiplayer.is_server() and ville_c.image.get_data() == ville_b.image.get_data()
		and ville_c.coulures == ville_b.coulures,
		"chez un client, les tampons reçus se dessinent pixel pour pixel comme chez l'hôte, coulures comprises (%d coulures)" % ville_c.coulures.size())
	_check(emis_client.is_empty() and ville_c.territoire.cellules_de(0) == 0 and ville_c.territoire.cellules_de(1) == 0,
		"un client ne rediffuse pas les tampons reçus et ne les compte pas dans son territoire")
	ville_c.peindre_tampon_recu({"index": 7, "x": 500, "y": 50, "rayon": 20, "graine": 1})
	_check(ville_c.image.get_data() == ville_b.image.get_data(), "un tampon reçu pour un joueur inconnu de ce poste est ignoré")
	# Les mêmes 400 tampons, l'un d'un coup, l'autre avec des coulures qui finissent entre deux
	# tampons (un autre rythme d'affichage) : les mêmes coulures sont lancées
	var ville_d: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	var ville_e: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	for v: Node2D in [ville_d, ville_e]:
		v.position = ville_b.position
		poste_c.add_child(v)
	for g in range(400):
		var tampon := {"index": 1, "x": 100 + (g * 7) % 1800, "y": 60, "rayon": 21, "graine": g}
		ville_d.peindre_tampon_recu(tampon)
		ville_e.peindre_tampon_recu(tampon)
		ville_e._avancer_coulures(1.0)
	_check(ville_d._tampons_des_coulures == ville_e._tampons_des_coulures and ville_d._tampons_des_coulures.size() > 0
		and ville_d.coulures.size() > ville_e.coulures.size(),
		"les mêmes tampons lancent les mêmes coulures, quel que soit le rythme d'affichage (plafond compté en tampons)")
	ville_d.free()
	ville_e.free()
	var lion_c: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
	lion_c.joueur = j_r
	lion_c.commandes = Commandes.manuelles()
	poste_c.add_child(lion_c)
	lion_c.global_position = poste_peinture
	await _frames(2)
	emis.clear()
	ville_b.tampon_peint.connect(sur_tampon)
	lion_c.gerbe_traceuse.monitoring = true  # comme un vomi répliqué
	await _frames(5)
	_check(lion_c.gerbe_traceuse.get_overlapping_areas().size() > 0 and emis.is_empty(),
		"la traceuse d'un lion de client, au-dessus de la ville, ne peint pas (seule celle de l'hôte peint)")
	ville_b.tampon_peint.disconnect(sur_tampon)
	lion_c.free()
	set_multiplayer(null, poste_c.get_path())
	pair_c.close()
	poste_c.free()

	# Après terminer_partie, partie_en_cours retombe mais pret reste vrai (pas de retour à
	# l'intro) ; un lion peut donc encore peindre. Le tampon visuel doit rester, mais plus aucun
	# score de territoire ne doit bouger.
	GS.terminer_partie(true)
	_check(GS.pret and not GS.partie_en_cours, "(pré-condition) la manche est terminée mais le jeu reste « pret »")
	var scores_manche_finie := [t.cellules_de(0), t.cellules_de(1)]
	var volees_manche_finie := [j_r.cellules_volees, j_b.cellules_volees]
	ville_b.image.fill(Color(0, 0, 0, 0))
	ville_b.coulures.clear()
	l_r.global_position = poste_peinture  # cellules déjà possédées par le bleu : un vol s'y verrait
	await _frames(1)
	l_r.commandes.vomir_voulu = true
	await _frames(20)
	l_r.commandes.vomir_voulu = false
	await _frames(2)
	_check(_couleurs_peintes(ville_b.image).keys().any(func(k: int) -> bool: return rgba32_rouge.has(k))
		and [t.cellules_de(0), t.cellules_de(1)] == scores_manche_finie
		and [j_r.cellules_volees, j_b.cellules_volees] == volees_manche_finie,
		"après la fin de la manche, peindre dessine toujours le tampon mais ne change plus aucun score de territoire")

	# Éviction du cache des tampons : au-delà de TAMPONS_EN_CACHE_MAX jeux, le cache repart de zéro
	# (M4) ; passer par l'instance, le test ne peut pas nommer le script de la ville.
	for r in range(1, ville_b.TAMPONS_EN_CACHE_MAX + 2):
		ville_b._tampons_pour(r, j_r.couleurs_debloquees)
	_check(ville_b._tampons.size() <= ville_b.TAMPONS_EN_CACHE_MAX,
		"le cache des tampons ne dépasse jamais TAMPONS_EN_CACHE_MAX jeux (%d)" % ville_b._tampons.size())
	var gros_tampons: Array = ville_b._tampons_pour(97, j_r.couleurs_debloquees)
	_check(gros_tampons.size() == ville_b.NB_TAMPONS and gros_tampons.all(func(im: Image) -> bool: return im.get_width() == 195),
		"un jeu de tampons régénéré après éviction reste correct (rayon 97 -> 195 px)")

	for l in lions_t:
		l.free()
	ville_b.free()
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false

	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


## Phase 12 bis : l'écran Réseau (liste, IP, refus, échecs, hébergement, port occupé, clavier). Les
## signaux de `Reseau` sont émis comme il le fait (après être revenu hors réseau pour les échecs) :
## le transport lui-même est couvert par tests/reseau/lancer.sh.
func _tester_ecran_reseau(scores: Node, params: Node) -> void:
	print("-- Écran Réseau")
	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	var port_balise := 17895  # jamais le 7778 d'une vraie partie
	decouverte.port_balise = port_balise
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	scores.definir_preference("pseudo", "Léa")
	var ecran: Control = load("res://Scenes/EcranReseau.tscn").instantiate()
	ecran.port_jeu = 17797
	root.add_child(ecran)
	await _frames(1)

	# Accueil : 16:9, focus, pseudo mémorisé et borné, écoute des balises, liste vide avec l'indice
	_check(root.content_scale_size == Vector2i(2000, 1125), "l'écran Réseau passe en 16:9, comme le salon")
	_check(ecran.etat == ecran.Etat.ACCUEIL and ecran.bouton_heberger.has_focus(), "à l'accueil, Héberger a le focus")
	_check(ecran.champ_pseudo.text == "Léa" and ecran.champ_pseudo.max_length == reseau.PSEUDO_MAX,
		"le pseudo mémorisé est repris, la saisie bornée à %d caractères" % reseau.PSEUDO_MAX)
	_check(decouverte.ecoute_active() and decouverte.port_balise == port_balise, "l'écran écoute les balises")
	_check(ecran.boutons_parties.is_empty() and ecran.indice.visible and ecran.indice.text == tr("RESEAU_AUCUNE_PARTIE")
		and "Pare-feu" in ecran.indice.text, "aucune partie : l'indice « Pare-feu ? Réseau Privé ? Essaie par IP »")
	_check(ecran.bouton_heberger.get_node(ecran.bouton_heberger.focus_neighbor_bottom) == ecran.champ_ip,
		"liste vide : bas depuis Héberger mène à l'adresse IP")

	# Parties entendues : une joignable, trois refusées d'avance (pleine, autre version, manche)
	var futur := Time.get_ticks_msec() + 600000  # « vues dans le futur » : elles n'expirent pas pendant le test
	var zoe := {"version": reseau.version, "port": 17797, "nb_joueurs": 2, "places": 6, "manche_en_cours": false, "niveau": 1, "pseudo": "Zoé"}
	decouverte.enregistrer_partie(decouverte.parties, "127.0.0.1", zoe, futur)
	decouverte.enregistrer_partie(decouverte.parties, "10.0.0.2", zoe.merged({"pseudo": "Anna", "nb_joueurs": 6}, true), futur)
	decouverte.enregistrer_partie(decouverte.parties, "10.0.0.3", zoe.merged({"pseudo": "Bob", "version": "0.1"}, true), futur)
	decouverte.enregistrer_partie(decouverte.parties, "10.0.0.4", zoe.merged({"pseudo": "Chloé", "manche_en_cours": true}, true), futur)
	decouverte.parties_changees.emit()
	await _frames(1)
	var ordre: Array = ecran.liste.get_children().slice(1).map(func(b: Button) -> String: return b.text.get_slice(" ", 0))
	_check(ecran.boutons_parties.size() == 4 and not ecran.indice.visible and ordre == ["Anna", "Bob", "Chloé", "Zoé"],
		"une ligne par partie entendue, triées par pseudo, sans l'indice (%s)" % [ordre])
	var b_zoe: Button = ecran.boutons_parties["127.0.0.1:17797"]
	_check(not b_zoe.disabled and b_zoe.text == tr("RESEAU_PARTIE") % ["Zoé", 2, 6, tr("NIVEAU_METROPOLE")],
		"une partie joignable : pseudo, joueurs sur places, niveau (%s)" % b_zoe.text)
	var b_anna: Button = ecran.boutons_parties["10.0.0.2:17797"]
	var b_bob: Button = ecran.boutons_parties["10.0.0.3:17797"]
	var b_chloe: Button = ecran.boutons_parties["10.0.0.4:17797"]
	_check(b_anna.disabled and b_anna.text.ends_with(tr("RESEAU_PARTIE_PLEINE")) and b_bob.disabled
		and b_bob.text.ends_with(tr("RESEAU_PARTIE_VERSION") % "0.1") and b_chloe.disabled and b_chloe.text.ends_with(tr("RESEAU_PARTIE_MANCHE")),
		"pleine, autre version, manche en cours : grisées, avec la raison (%s | %s | %s)" % [b_anna.text, b_bob.text, b_chloe.text])
	_check(ecran.bouton_heberger.get_node(ecran.bouton_heberger.focus_neighbor_bottom) == b_anna
		and b_zoe.get_node(b_zoe.focus_neighbor_bottom) == ecran.champ_ip and ecran.champ_ip.get_node(ecran.champ_ip.focus_neighbor_top) == b_zoe
		# M5 (b), revue finale 12 bis : le bas de Rejoindre n'était pas vérifié (mutation qui l'enlève
		# passait). Zoé est la dernière partie (ordre alphabétique Anna, Bob, Chloé, Zoé).
		and ecran.bouton_rejoindre.get_node(ecran.bouton_rejoindre.focus_neighbor_top) == b_zoe,
		"haut et bas : Héberger, les parties dans l'ordre, puis l'adresse IP, puis Rejoindre")
	# I3 (revue finale 12 bis) : l'anneau de focus des lignes ne dépasse pas du bouton (sinon le
	# ScrollContainer qui contient la liste le clippe et le joueur ne voit presque rien).
	var style_focus: StyleBoxFlat = b_zoe.get_theme_stylebox("focus") as StyleBoxFlat
	_check(style_focus != null and style_focus.expand_margin_left == 0.0 and style_focus.expand_margin_top == 0.0
		and style_focus.expand_margin_right == 0.0 and style_focus.expand_margin_bottom == 0.0 and style_focus.border_width_left > 0,
		"I3 : le focus d'une ligne de partie est une bordure sans marge d'expansion (visible, jamais clippée)")
	# I2 (revue finale 12 bis) : le même hôte vu sur plusieurs interfaces (adresses locales de ce
	# poste) ne fait qu'une ligne, jointe via 127.0.0.1 ; une adresse non locale garde la sienne.
	var multi: Array[Dictionary] = [zoe.merged({"ip": "192.168.1.5"}, true), zoe.merged({"ip": "192.168.56.1"}, true)]
	var fusion: Dictionary = ecran.fusionner_parties_locales(multi, PackedStringArray(["192.168.1.5", "192.168.56.1"]))
	_check(fusion.size() == 1 and fusion.has("127.0.0.1:17797") and fusion["127.0.0.1:17797"].ip == "127.0.0.1",
		"I2 : un hôte vu sur deux interfaces (adresses locales) ne fait qu'une ligne, jointe via 127.0.0.1 (%s)" % [fusion.keys()])
	var distincts: Dictionary = ecran.fusionner_parties_locales(multi, PackedStringArray(["192.168.1.5"]))
	_check(distincts.size() == 2 and distincts.has("127.0.0.1:17797") and distincts.has("192.168.56.1:17797"),
		"I2 : seule l'adresse reconnue comme locale est jointe, l'autre garde sa propre ligne (%s)" % [distincts.keys()])
	ecran.rejoindre_partie("10.0.0.2:17797")
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne(), "une partie grisée ne se rejoint pas")
	b_zoe.grab_focus()
	decouverte.enregistrer_partie(decouverte.parties, "127.0.0.1", zoe.merged({"nb_joueurs": 3}, true), futur)
	decouverte.parties_changees.emit()
	await _frames(1)
	_check(ecran.boutons_parties["127.0.0.1:17797"] == b_zoe and b_zoe.has_focus() and "3/6" in b_zoe.text,
		"une partie qui change garde sa ligne et le focus (%s)" % b_zoe.text)
	decouverte.parties.erase("127.0.0.1:17797")
	decouverte.parties_changees.emit()
	await _frames(1)
	_check(ecran.boutons_parties.size() == 3 and not ecran.boutons_parties.has("127.0.0.1:17797") and ecran.bouton_heberger.has_focus(),
		"la partie qui avait le focus disparaît : le focus revient à Héberger")

	# Adresse IP saisie : refusée si ce n'est pas une IPv4, sinon connexion avec le pseudo nettoyé
	ecran.champ_ip.text = "lelion.local"
	ecran.rejoindre_par_ip()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == tr("RESEAU_IP_INVALIDE")
		and ecran.champ_ip.has_focus(), "un nom d'hôte est refusé sans rien tenter (%s)" % ecran.message.text)
	ecran.champ_pseudo.text = " Zoé la grande dompteuse"
	_check(ecran.champ_pseudo.text == " Zoé la gran", "la saisie du pseudo s'arrête à %d caractères (%s)" % [reseau.PSEUDO_MAX, ecran.champ_pseudo.text])
	ecran.port_jeu = 17796  # personne n'y écoute
	ecran.champ_ip.text = " 127.000.0.1 "
	ecran.rejoindre_par_ip()
	_check(ecran.etat == ecran.Etat.CONNEXION and reseau.en_ligne() and not root.multiplayer.is_server()
		and ecran.champ_ip.text == "127.0.0.1" and ecran.message.text == tr("RESEAU_CONNEXION") % "127.0.0.1",
		"une IPv4 saisie lance la connexion, adresse normalisée (%s)" % ecran.message.text)
	_check(reseau.pseudo == "Zoé la gran" and ecran.champ_pseudo.text == "Zoé la gran" and scores.preference("pseudo", "") == "Zoé la gran",
		"le pseudo nettoyé (sans l'espace de tête) est donné à Reseau et mémorisé (%s)" % reseau.pseudo)
	_check(not decouverte.ecoute_active() and ecran.boutons_parties.is_empty() and not ecran.cadre_parties.visible
		and ecran.bouton_heberger.disabled and not ecran.champ_ip.editable and ecran.bouton_retour.has_focus(),
		"pendant la connexion : plus d'écoute ni de liste, tout est grisé sauf Retour, qui a le focus")
	reseau.inscrit.emit(2, palette[2])
	_check(ecran.etat == ecran.Etat.SALON and ecran.bouton_heberger.disabled and not decouverte.ecoute_active(),
		"inscrit par l'hôte : en route vers le salon, tout reste grisé")
	await _frames(2)
	var salon_client: Node = current_scene
	_check(salon_client != null and salon_client.scene_file_path == "res://Scenes/Salon.tscn" and reseau.en_ligne(),
		"puis le salon prend la suite, toujours en ligne (phase 13)")
	if salon_client != null:
		salon_client.free()
	reseau.quitter()
	reseau.hote_perdu.emit()
	_check(ecran.etat == ecran.Etat.ACCUEIL and ecran.message.text == tr("RESEAU_HOTE_PERDU") and decouverte.ecoute_active()
		and ecran.bouton_heberger.has_focus(), "hôte perdu : « L'hôte a quitté la partie », retour à l'accueil qui écoute de nouveau")
	ecran.rejoindre_par_ip()
	reseau.quitter()
	reseau.connexion_echouee.emit()
	_check(ecran.etat == ecran.Etat.ACCUEIL and ecran.message.text == tr("RESEAU_ECHEC_CONNEXION") and "Pare-feu" in ecran.message.text,
		"pas de réponse : le message indique le pare-feu de l'hôte et le réseau Privé (%s)" % ecran.message.text)
	var attendus := {reseau.REFUS_VERSION: tr("RESEAU_REFUS_VERSION") % "0.9", reseau.REFUS_PLEIN: tr("RESEAU_REFUS_PLEIN"),
		reseau.REFUS_MANCHE: tr("RESEAU_REFUS_MANCHE"), reseau.REFUS_DEMANDE: tr("RESEAU_REFUS_DEMANDE"), "RAISON_INCONNUE": tr("RESEAU_REFUS_DEMANDE")}
	var faux: Array[String] = []
	for raison: String in attendus:
		ecran.rejoindre_par_ip()
		reseau.quitter()
		reseau.refuse.emit(raison, "0.9")
		if ecran.etat != ecran.Etat.ACCUEIL or ecran.message.text != attendus[raison] or ecran.message.text.begins_with("RESEAU_"):
			faux.append("%s → %s" % [raison, ecran.message.text])
	_check(faux.is_empty() and tr("RESEAU_REFUS_VERSION") % "0.9" == "Version différente de l'hôte (0.9)",
		"chaque refus a son texte traduit, la version de l'hôte dans le refus de version, une raison inconnue lue comme demande incomprise (%s)" % [faux])

	# Héberger : en ligne, hôte, plus d'écoute, puis le salon (phase 13) ; Échap arrête
	ecran.port_jeu = 17797
	ecran.heberger()
	_check(ecran.etat == ecran.Etat.SALON and reseau.en_ligne() and root.multiplayer.is_server()
		and reseau.inscrits[1].pseudo == "Zoé la gran" and not decouverte.ecoute_active() and ecran.bouton_retour.has_focus(),
		"Héberger : ce poste héberge avec son pseudo, n'écoute plus les balises (il ne se verrait pas lui-même)")
	ecran.heberger()
	_check(reseau.en_ligne() and reseau.inscrits.size() == 1 and ecran.etat == ecran.Etat.SALON,
		"un second Héberger avant le changement de scène ne relance rien")
	await _frames(2)
	var salon_hote: Node = current_scene
	_check(salon_hote != null and salon_hote.scene_file_path == "res://Scenes/Salon.tscn" and reseau.en_ligne() and root.multiplayer.is_server(),
		"puis le salon prend la suite, toujours hôte (phase 13 : il affiche les adresses de l'hôte)")
	if salon_hote != null:
		salon_hote.free()
	var echap := InputEventAction.new()
	echap.action = "ui_cancel"
	echap.pressed = true
	root.push_input(echap)
	await process_frame
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and decouverte.ecoute_active() and ecran.message.text.is_empty(),
		"Échap (ou B) arrête d'héberger et revient à l'accueil, qui écoute de nouveau")

	# Port de jeu occupé, autre erreur d'hébergement ; changer de langue retraduit le message
	var occupant := ENetMultiplayerPeer.new()
	_check(occupant.create_server(17798) == OK, "(pré-condition) un autre programme occupe le port 17798")
	ecran.port_jeu = 17798
	ecran.heberger()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == "Impossible d'héberger : port 17798 occupé",
		"port occupé : « Impossible d'héberger : port 17798 occupé », sans quitter l'accueil (%s)" % ecran.message.text)
	# M5 (c) : une partie encore dans la liste (le passage par CONNEXION plus haut a vidé
	# `decouverte.parties` en fermant l'écoute) pour vérifier que la langue retraduit aussi les lignes.
	decouverte.enregistrer_partie(decouverte.parties, "10.0.0.9", zoe.merged({"pseudo": "Nina"}, true), futur)
	decouverte.parties_changees.emit()
	await _frames(1)
	params.definir_langue("en")
	await _frames(1)
	_check(ecran.message.text == "Can't host: port 17798 in use" and ecran.indice.text.begins_with("No game found"),
		"changer de langue retraduit le message et l'indice (%s | %s)" % [ecran.message.text, ecran.indice.text])
	# M5 (c), revue finale 12 bis : la retraduction des lignes de la liste n'était pas vérifiée
	# (mutation qui enlève l'appel à _afficher_parties() passait quand même).
	var lignes_en: Array = ecran.boutons_parties.values().map(func(b: Button) -> String: return b.text)
	_check(not lignes_en.is_empty() and lignes_en.any(func(t: String) -> bool: return "players" in t),
		"changer de langue retraduit aussi les lignes de la liste, pas seulement le message (%s)" % [lignes_en])
	params.definir_langue("fr")
	occupant.close()
	var erreur_attendue := ENetMultiplayerPeer.new().create_server(70000)
	ecran.port_jeu = 70000
	ecran.heberger()
	_check(not reseau.en_ligne() and ecran.message.text == tr("RESEAU_HEBERGER_IMPOSSIBLE") % erreur_attendue,
		"une autre erreur d'hébergement donne son code (%s)" % ecran.message.text)

	# Retour à l'accueil (sans changer de scène : la navigation vers le titre est vérifiée avec le
	# bouton Multijoueur) ; l'écran fermé ne laisse ni écoute ni connexion aux autoloads
	ecran.retour(false)
	_check(not reseau.en_ligne() and scores.preference("pseudo", "") == "Zoé la gran", "Retour quitte le réseau et garde le pseudo mémorisé")
	# M5 (a), revue finale 12 bis : retirer de l'arbre sans détruire, pour vérifier que c'est bien
	# `_exit_tree` (les `disconnect` explicites) qui nettoie, pas seulement le nettoyage automatique
	# des connexions d'un nœud détruit (une simple `ecran.free()` faisait passer une mutation qui
	# enlève les 8 `disconnect`).
	root.remove_child(ecran)
	_check(not decouverte.ecoute_active() and decouverte.parties_changees.get_connections().is_empty()
		and reseau.refuse.get_connections().is_empty() and reseau.joueur_arrive.get_connections().is_empty(),
		"l'écran retiré de l'arbre (pas encore détruit) ne laisse ni écoute ni connexion aux autoloads")
	ecran.free()

	# Port des balises déjà pris (deux LeLion sur un PC) : la liste le dit, sans planter
	var intrus := PacketPeerUDP.new()
	_check(intrus.bind(port_balise, "0.0.0.0") == OK, "(pré-condition) un autre programme occupe le port des balises")
	var ecran2: Control = load("res://Scenes/EcranReseau.tscn").instantiate()
	root.add_child(ecran2)
	await _frames(1)
	_check(not decouverte.ecoute_active() and ecran2.indice.visible and ecran2.indice.text == tr("RESEAU_ECOUTE_IMPOSSIBLE") % port_balise,
		"port des balises occupé : « Recherche impossible … Rejoins par IP » (%s)" % ecran2.indice.text)
	ecran2.free()
	intrus.close()

	decouverte.port_balise = decouverte.PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray()
	reseau.pseudo = ""
	scores.effacer()


## Phase 12 bis : le bouton Multijoueur du titre, l'aller et retour avec l'écran Réseau, et le titre
## qui remet toujours ce poste hors réseau avant le solo.
func _tester_titre_reseau(scores: Node) -> void:
	print("-- Titre et réseau")
	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	decouverte.port_balise = 17895  # l'écran Réseau ouvert ici écoute : jamais le 7778 d'une vraie partie
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])

	# Titre : le bouton Multijoueur, dans l'écran, sans chevaucher les autres, joignable au clavier
	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	var multi: Button = titre.bouton_multijoueur
	_check(multi != null and multi.get_parent() == titre and multi.text == "MULTIJOUEUR" and tr("MULTIJOUEUR") == "Multijoueur",
		"l'écran titre a un bouton Multijoueur, traduit")
	var rect_multi: Rect2 = multi.get_global_rect()
	var autres: Array = [titre.bouton_jouer, titre.bouton_reglages, titre.bouton_arcade, titre.get_node("Centre/Colonne/Aide")]
	_check(Rect2(Vector2.ZERO, Vector2(2000, 648)).encloses(rect_multi)
		and autres.all(func(c: Control) -> bool: return not c.get_global_rect().intersects(rect_multi)),
		"le bouton Multijoueur tient dans l'écran du titre sans chevaucher Jouer, Réglages, Arcade ni l'aide (%s)" % rect_multi)
	_check(titre.bouton_jouer.get_node(titre.bouton_jouer.focus_neighbor_right) == multi
		and multi.get_node(multi.focus_neighbor_left) == titre.bouton_jouer,
		"clavier et manette : droite depuis Jouer mène à Multijoueur, gauche en revient")
	multi.pressed.emit()
	await _frames(2)
	var ecran: Control = current_scene
	titre.free()
	_check(ecran != null and ecran.scene_file_path == "res://Scenes/EcranReseau.tscn", "Multijoueur ouvre l'écran Réseau")
	if ecran == null or ecran.scene_file_path != "res://Scenes/EcranReseau.tscn":
		return
	ecran.bouton_retour.pressed.emit()
	await _frames(2)
	var titre_retour: Control = current_scene
	_check(titre_retour != null and titre_retour.scene_file_path == "res://Scenes/Titre.tscn" and not is_instance_valid(ecran)
		and root.content_scale_size == Vector2i(2000, 648) and not decouverte.ecoute_active() and not reseau.en_ligne(),
		"Retour ramène au titre, en 2000×648, hors réseau et sans écoute")
	if titre_retour != null:
		titre_retour.free()

	# Retour au titre depuis une session : hors réseau AVANT le solo (point de vigilance de la phase 12)
	_check(reseau.heberger(17797) == OK, "(pré-condition) ce poste héberge")
	titre = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and reseau.inscrits.is_empty(),
		"après un hébergement, le titre remet ce poste hors réseau (plus de balise ni d'arrivée)")
	titre.free()
	_check(reseau.rejoindre("127.0.0.1", 17796) == OK and not root.multiplayer.is_server(), "(pré-condition) ce poste est un client")
	titre = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	_check(root.multiplayer.is_server() and not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,
		"après une connexion, le titre rend ce poste hôte de lui-même : le solo qui suit tranche ses contacts (« un coup coûte une vie »)")
	titre.free()
	decouverte.port_balise = decouverte.PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray()
	reseau.pseudo = ""
	scores.effacer()


## Phase 13 : le salon, sur un seul poste (le salon à plusieurs postes, du lancement de la manche
## compris, est couvert par tests/reseau/lancer.sh, scénario 8). Les arrivées sont simulées dans
## `Reseau.inscrits`, comme `Reseau` les y inscrit : place réservée, puis arrivée.
func _tester_salon(params: Node) -> void:
	print("-- Salon")
	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	var port_balise := 17896  # la balise de l'hôte : jamais le 7778 d'une vraie partie
	decouverte.port_balise = port_balise
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	reseau.pseudo = "MMMMMMMMMMMM"  # 12 caractères larges : ils doivent tenir dans la carte
	GS.niveau_courant = 1
	_check(reseau.heberger(17797) == OK, "(pré-condition) ce poste héberge")
	var salon: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon)
	await process_frame

	# L'hôte seul : sa carte, les places libres, le niveau du titre, ses adresses ; aucun focus
	var c0: Dictionary = salon.cartes[0]
	_check(root.content_scale_size == Vector2i(2000, 1125) and salon.cartes.size() == 6
		and salon.cartes.all(func(c: Dictionary) -> bool: return c.cadre.visible), "le salon est en 16:9, une carte par place (6)")
	_check(c0.pseudo.text == "MMMMMMMMMMMM" and c0.badge.text == "HÔTE · TOI" and c0.etat.text == tr("SALON_PAS_PRET")
		and c0.lion.material == c0.teinte and c0.teinte.get_shader_parameter("couleur_joueur") == palette[0] and c0.style.border_color == palette[0],
		"la carte de l'hôte : pseudo, badges, pas prêt, lion et contour à sa couleur")
	var police: Font = c0.pseudo.get_theme_font("font")
	var largeur_w: float = police.get_string_size("WWWWWWWWWWWW", HORIZONTAL_ALIGNMENT_LEFT, -1, c0.pseudo.get_theme_font_size("font_size")).x \
		+ 2 * c0.pseudo.get_theme_constant("outline_size")
	_check(largeur_w <= c0.pseudo.size.x and salon.rangee_cartes.get_combined_minimum_size().x <= 2000.0,
		"12 caractères larges (« WWWWWWWWWWWW », %d px) tiennent dans une carte (%d px) ; les six cartes dans l'écran" % [largeur_w, c0.pseudo.size.x])
	_check(salon.cartes.slice(1).all(func(c: Dictionary) -> bool: return c.pseudo.text == tr("SALON_LIBRE") and c.lion.material == null),
		"les autres places sont libres : une silhouette sans couleur")
	_check(salon.titre_niveau.text == "Niveau : Métropole" and reseau.niveau_salon == 1 and salon.aide.text == tr("SALON_AIDE_HOTE")
		and salon.adresses.visible and salon.etat.text == tr("SALON_ATTENTE_JOUEURS") and salon.bouton_demarrer.visible and salon.bouton_demarrer.disabled,
		"le niveau choisi au titre, l'aide de l'hôte, ses adresses, Démarrer grisé : « Il faut au moins 2 joueurs pour démarrer. »")
	_check(root.gui_get_focus_owner() == null and salon.bouton_retour.focus_mode == Control.FOCUS_NONE,
		"aucun contrôle ne prend le focus : flèches, croix, stick, vomir et démarrer vont au salon")

	# Une place réservée (poignée de main en cours) n'a pas de carte ; un joueur arrivé a la sienne
	reseau.inscrits[7] = {"index": 2, "couleur": palette[2], "pseudo": "Rita", "arrive": false, "pret": false}
	reseau.inscrits[5] = {"index": 1, "couleur": palette[1], "pseudo": "Bob", "arrive": false, "pret": false}
	reseau._sur_pair_connecte(5)
	_check(salon.cartes[1].pseudo.text == "Bob" and salon.cartes[1].badge.text == " " and salon.cartes[2].pseudo.text == tr("SALON_LIBRE")
		and reseau.table_salon.map(func(f: Dictionary) -> int: return f.id) == [1, 5],
		"une place seulement réservée n'a pas de carte (M4) ; un joueur arrivé a la sienne")

	# Couleurs : la voisine libre (celle d'une place réservée est prise) ; une seule par appui
	salon.changer_couleur(1)
	_check(reseau.inscrits[1].couleur == palette[3] and reseau.couleur_locale == palette[3] and c0.teinte.get_shader_parameter("couleur_joueur") == palette[3],
		"droite : la couleur libre suivante, bleu et jaune (réservé) sautés : vert")
	salon.changer_couleur(-1)
	_check(reseau.inscrits[1].couleur == palette[0], "gauche : la libre précédente : rouge")
	await _appuyer(&"deplacer_gauche", true)
	await _appuyer(&"deplacer_gauche", true)  # le stick encore penché : un autre événement, pas un autre appui
	await _appuyer(&"deplacer_gauche", false)
	_check(reseau.inscrits[1].couleur == palette[5], "gauche tenue (clavier, croix ou stick) ne change la couleur qu'une fois, la palette en boucle : cyan")
	await _appuyer(&"deplacer_droite", true)
	await _appuyer(&"deplacer_droite", false)
	_check(reseau.inscrits[1].couleur == palette[0], "droite : de nouveau rouge, en boucle")
	_check(reseau.changer_couleur(5, 1) and reseau.inscrits[5].couleur == palette[3],
		"l'hôte arbitre la demande d'un client : Bob passe à la suivante libre, vert")
	_check(not reseau.changer_couleur(7, 1) and not reseau.changer_couleur(99, 1) and not reseau.changer_couleur(5, 2),
		"refusées : une place seulement réservée, un inconnu, un sens hors de ±1")

	# Prêt : couleur figée. Le bouton « Démarrer la partie » de l'hôte, grisé avec sa raison tant que
	# la partie ne peut pas démarrer ; l'hôte revérifie au moment de l'appui
	var bouton: Button = salon.bouton_demarrer
	await _appuyer(&"vomir", true)
	await _appuyer(&"vomir", false)
	_check(reseau.inscrits[1].pret and c0.etat.text == tr("SALON_PRET"), "vomir : prêt")
	salon.changer_couleur(1)
	_check(reseau.inscrits[1].couleur == palette[0], "prêt, sa couleur est figée")
	_check(reseau.definir_pret(5, true) and bouton.visible and bouton.disabled and bouton.focus_mode == Control.FOCUS_NONE
		and salon.etat.text == tr("SALON_ATTENTE_ARRIVEE"),
		"tous les arrivés sont prêts, mais une place est réservée : bouton grisé, « Un joueur est en train d'arriver… »")
	await _appuyer(&"demarrer", true)
	await _appuyer(&"demarrer", false)
	_check(not reseau.manche_en_cours and root.get_children().has(salon), "Tab (ou Start) sur un bouton grisé ne démarre rien")
	reseau._sur_echec_poignee_de_main(7)
	_check(not bouton.disabled and salon.etat.text == tr("SALON_PRET_A_DEMARRER"),
		"la place libérée, tous prêts : le bouton s'active, « tu peux démarrer la partie »")
	reseau.inscrits[5].pret = false  # Bob repasse non prêt dans la même image que l'appui, avant tout affichage
	salon.demarrer()
	_check(not reseau.manche_en_cours and bouton.disabled and salon.etat.text == tr("SALON_ATTENTE_PRETS") and root.get_children().has(salon),
		"l'hôte revérifie au moment de démarrer : refusé, le bouton se regrise, « tous les joueurs doivent être prêts »")
	reseau.definir_pret(5, true)
	_check(not bouton.disabled, "(Bob de nouveau prêt : le bouton revient)")
	reseau.definir_pret(5, false)
	_check(bouton.disabled and salon.etat.text == tr("SALON_ATTENTE_PRETS"), "Bob repasse non prêt : le bouton se regrise aussitôt")
	salon.changer_niveau(1)
	_check(reseau.niveau_salon == 2, "l'hôte change de niveau quand il veut, même quand tous ne sont pas prêts")
	salon.changer_niveau(-1)
	reseau._sur_pair_deconnecte(5)
	_check(salon.cartes[1].pseudo.text == tr("SALON_LIBRE") and bouton.disabled and salon.etat.text == tr("SALON_ATTENTE_JOUEURS"),
		"Bob part : sa carte se libère, « il faut au moins 2 joueurs pour démarrer »")

	# Niveau (l'hôte, haut/bas, en boucle) : la partie et la balise le suivent
	await _appuyer(&"deplacer_bas", true)
	await _appuyer(&"deplacer_bas", false)
	_check(reseau.niveau_salon == 2 and GS.niveau_courant == 2 and salon.titre_niveau.text == "Niveau : Village", "bas : le niveau suivant")
	salon.changer_niveau(1)
	_check(reseau.niveau_salon == 0 and GS.niveau_courant == 0, "après le dernier, le premier (en boucle)")
	salon.changer_niveau(-1)
	var recepteur := PacketPeerUDP.new()
	_check(recepteur.bind(port_balise, "0.0.0.0") == OK, "(pré-condition) un récepteur écoute la balise de l'hôte")
	decouverte._emettre_balise()
	var balise := {}
	var fin := Time.get_ticks_msec() + 500
	while balise.is_empty() and Time.get_ticks_msec() < fin:
		if recepteur.get_available_packet_count() > 0:
			balise = decouverte.decoder_balise(recepteur.get_packet())
		else:
			OS.delay_msec(5)
	recepteur.close()
	_check(balise.get("niveau") == 2 and balise.get("nb_joueurs") == 1 and balise.get("manche_en_cours") == false,
		"la balise de l'hôte annonce le niveau choisi au salon (%s)" % [balise])

	# Langue ; Retour ; plus aucune connexion aux autoloads
	params.definir_langue("en")
	await process_frame
	_check(salon.titre_niveau.text == "Level: Village" and salon.cartes[1].pseudo.text == "Free slot" and c0.etat.text == "READY!"
		and salon.aide.text.begins_with("Left/Right"), "changer de langue retraduit le salon (%s)" % salon.titre_niveau.text)
	params.definir_langue("fr")
	salon.retour(false)
	_check(not reseau.en_ligne() and reseau.table_salon.is_empty(), "Retour quitte le réseau : les clients voient partir l'hôte")
	salon.free()
	_check(reseau.salon_change.get_connections().is_empty()
		and reseau.manche_lancee.get_connections().is_empty() and reseau.hote_perdu.get_connections().is_empty(),
		"le salon fermé ne laisse aucune connexion aux autoloads")

	# Un client : ni niveau ni adresses ; l'hôte perdu ramène à l'écran Réseau, avec son message
	_check(reseau.rejoindre("127.0.0.1", 17796) == OK, "(pré-condition) ce poste est un client")
	var salon_client: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon_client)
	await process_frame
	_check(salon_client.aide.text == tr("SALON_AIDE") and not salon_client.adresses.visible and not salon_client.bouton_demarrer.visible,
		"un client : l'aide sans le niveau ni Démarrer, pas d'adresses, pas de bouton")
	salon_client.changer_niveau(1)
	salon_client.demarrer()
	_check(reseau.niveau_salon == 0 and not reseau.manche_en_cours, "un client ne change pas le niveau et ne démarre pas la partie")
	var id_client: int = root.multiplayer.get_unique_id()
	reseau.table_salon.assign([{"id": 1, "index": 0, "couleur": palette[0], "pseudo": "Hôte", "pret": true},
		{"id": id_client, "index": 1, "couleur": palette[1], "pseudo": "Moi", "pret": false}])
	reseau.salon_change.emit()
	var attente_client: String = salon_client.etat.text
	reseau.table_salon[1].pret = true
	reseau.salon_change.emit()
	_check(attente_client == tr("SALON_ATTENTE_PRETS") and salon_client.etat.text == tr("SALON_ATTENTE_HOTE"),
		"un client voit pourquoi la partie attend, puis « l'hôte peut démarrer » (%s | %s)" % [attente_client, salon_client.etat.text])
	reseau.quitter()
	reseau.hote_perdu.emit()
	await _frames(2)
	var ecran: Node = current_scene
	_check(ecran != null and ecran.scene_file_path == "res://Scenes/EcranReseau.tscn" and ecran.etat == ecran.Etat.ACCUEIL
		and ecran.message.text == tr("RESEAU_HOTE_PERDU"), "hôte perdu : retour à l'écran Réseau, « L'hôte a quitté la partie »")
	salon_client.free()
	if ecran != null:
		ecran.free()

	# Échap (ou B) : quitte le réseau, écran Réseau sans message (celui de l'hôte perdu ne s'affiche
	# qu'une fois)
	_check(reseau.rejoindre("127.0.0.1", 17796) == OK, "(pré-condition) ce poste est de nouveau un client")
	salon_client = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon_client)
	await process_frame
	await _appuyer(&"ui_cancel", true)
	await _frames(2)
	ecran = current_scene
	_check(not reseau.en_ligne() and ecran != null and ecran.scene_file_path == "res://Scenes/EcranReseau.tscn" and ecran.message.text.is_empty(),
		"Échap (ou B) quitte le réseau et revient à l'écran Réseau, sans message")
	salon_client.free()
	if ecran != null:
		ecran.free()

	# Un salon ouvert hors réseau (l'hôte parti pendant le chargement du salon : son signal n'a
	# trouvé personne)
	var orphelin: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(orphelin)
	await _frames(2)
	ecran = current_scene
	_check(ecran != null and ecran.scene_file_path == "res://Scenes/EcranReseau.tscn" and ecran.message.text == tr("RESEAU_HOTE_PERDU"),
		"un salon ouvert hors réseau revient à l'écran Réseau avec « L'hôte a quitté la partie »")
	orphelin.free()
	if ecran != null:
		ecran.free()

	decouverte.port_balise = decouverte.PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray()
	reseau.pseudo = ""
	GS.niveau_courant = 0


## Un appui (ou un relâchement) de `action`, comme le clavier ou la manette l'envoient au jeu.
func _appuyer(action: StringName, appuye: bool) -> void:
	var evenement := InputEventAction.new()
	evenement.action = action
	evenement.pressed = appuye
	root.push_input(evenement)
	await process_frame
