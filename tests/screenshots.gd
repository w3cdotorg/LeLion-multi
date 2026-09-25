extends SceneTree
## Capture d'écran pilotée : godot --script tests/screenshots.gd (rendu réel requis, pas headless)
## Écrit dans le dossier passé par --dossier=<chemin> (défaut : user://).

var dossier := "user://"
var GS: Node


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dossier="):
			dossier = arg.trim_prefix("--dossier=")
	call_deferred("_run")


func _attendre(secondes: float) -> void:
	await create_timer(secondes).timeout


func _shot(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(dossier.path_join(nom + ".png"))
	print("📸 ", nom)


func _run() -> void:
	GS = root.get_node("GameState")
	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	root.add_child(titre)
	await _attendre(0.2)
	await _shot("00_titre")
	titre.free()
	var main: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _attendre(0.15)
	main.get_node("Spawner").spawn_pickup(0, Vector2(900, 250))
	await _attendre(0.1)
	await _shot("01_depart")

	var lion: CharacterBody2D = main.get_node("Lion")
	var spawner: Node = main.get_node("Spawner")
	var ville: Node2D = main.get_node("Ville")
	for i in range(3):
		GS.regles.pastille_ramassee(GS.joueur_local(), i)
	await _attendre(0.1)
	lion.global_position = Vector2(500, ville.position.y - 330)
	Input.action_press("vomir")
	await _attendre(1.00)
	await _shot("02_vomi_droite_3_couleurs")
	Input.action_press("deplacer_droite")
	await _attendre(1.50)
	Input.action_release("deplacer_droite")
	Input.action_release("vomir")
	await _attendre(0.1)
	for i in range(3, 7):
		GS.regles.pastille_ramassee(GS.joueur_local(), i)
	Input.action_press("deplacer_gauche")
	await _attendre(0.1)
	Input.action_press("vomir")
	await _attendre(0.83)
	Input.action_release("deplacer_gauche")
	spawner.spawn_soucoupe(300)
	spawner.spawn_coccinelle(250)
	spawner.spawn_bonus(Vector2(1300, 220))
	spawner.spawn_coeur(Vector2(1600, 300))
	GS.joueur_local().activer_bonus(8.0)
	GS.regles.lion_touche_par_ennemi(GS.joueur_local(), Vector2.INF)
	GS.joueur_local().invulnerable_restant = 0.0
	await _attendre(0.75)
	await _shot("03_vomi_gauche_7_couleurs_ennemis")
	Input.action_release("vomir")
	main.get_node("PauseMenu").ouvrir()
	await _attendre(0.2)
	await _shot("03b_pause")
	main.get_node("PauseMenu").reprendre()
	GS.terminer_partie(false)
	await _attendre(3.5)
	await _shot("04_game_over")

	# Victoire avec record précédent
	paused = false
	main.free()
	root.get_node("Scores").chemin = "user://scores_captures.cfg"
	root.get_node("Scores").effacer()
	root.get_node("Scores").enregistrer("skyline/facile", 95.0)
	GS.niveau_courant = 0
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _attendre(0.2)
	for i in range(7):
		GS.regles.pastille_ramassee(GS.joueur_local(), i)
	GS.temps_ecoule = 71.0
	GS.regles.lion_touche_par_ennemi(GS.joueur_local(), Vector2.INF)
	GS.signaler_progression(0.91)
	await _attendre(1.2)
	await _shot("04b_victoire_animation")
	await _attendre(3.0)
	await _shot("04b_victoire")
	root.get_node("Scores").effacer()
	paused = false
	main.free()

	# Village : le boss au centre
	GS.niveau_courant = 2
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _attendre(0.2)
	var boss: Node = get_first_node_in_group("boss")
	for i in range(7):
		GS.regles.pastille_ramassee(GS.joueur_local(), i)
	main.get_node("Lion").global_position = Vector2(1500, 150)
	boss.cote = 1
	boss._changer_etat(boss.Etat.ENTREE)
	await _attendre(3.2)
	Input.action_press("vomir")
	await _attendre(0.8)
	await _shot("05_village_boss")
	Input.action_release("vomir")
	main.free()
	quit(0)
