extends Node2D
## Racine de la partie : met l'écran à la taille du mode, place la ville, le ciel, la caméra et
## un lion par joueur, écoute la fin de partie et affiche le bilan du solo.

@export var game_over_scene: PackedScene

@export var force_tremblement := 14.0
@export var duree_tremblement := 0.35
@export var duree_demo := 45.0
## Plusieurs lions (bataille) : hauteur de départ, en part de la hauteur de l'écran (en haut du ciel).
@export var hauteur_depart_lions := 0.12

const SCENE_TITRE := "res://Scenes/Titre.tscn"
const SCRIPT_PILOTE := preload("res://Scripts/Pilote.gd")
const SCENE_LION := preload("res://Scenes/Lion.tscn")

@onready var ville: Node2D = $Ville
@onready var lion: Lion = $Lion
@onready var camera: Camera2D = $Camera
@onready var ciel: TextureRect = $Ciel

## Un lion par joueur, dans l'ordre de `GameState.joueurs` : le premier est celui de la scène,
## le lion du joueur local.
var lions: Array[Lion] = []

var _tremblement_restant := 0.0
var _demo_restant := 0.0


const ACTIONS_DE_JEU := ["deplacer_gauche", "deplacer_droite", "deplacer_haut", "deplacer_bas", "vomir"]


## Avant les _ready des enfants : le lion et le HUD lisent l'état de partie en se construisant,
## le peintre et les apparitions la taille de l'écran. Les règles du mode sont branchées AVANT le
## changement de scène (`GameState.configurer_solo` / `configurer_bataille`), jamais ici.
func _enter_tree() -> void:
	for action in ACTIONS_DE_JEU:
		Input.action_release(action)
	Regles.appliquer_ecran(get_tree(), GameState.regles.taille_ecran())
	GameState.nouvelle_partie()


func _ready() -> void:
	Audio.demarrer_musique("boss" if GameState.niveau().get("boss", false) else "ville", 0)
	GameState.progression_changee.connect(_on_progression_changee)
	GameState.partie_terminee.connect(_on_partie_terminee)
	GameState.joueur_local().touche.connect(_on_lion_touche)
	ville.charger_skyline(load(GameState.niveau().texture))
	_placer_ville()
	_placer_ciel_et_camera()
	_ajouter_lions()
	if GameState.demo:
		_installer_demo()


## Attract mode : un pilote automatique joue, une étiquette clignote, toute touche ramène au titre.
func _installer_demo() -> void:
	_demo_restant = duree_demo
	var pilote := Node.new()
	pilote.name = "Pilote"
	pilote.set_script(SCRIPT_PILOTE)
	add_child(pilote)
	var couche := CanvasLayer.new()
	couche.name = "Demo"
	couche.layer = 7
	var etiquette := Label.new()
	etiquette.text = "DEMO"
	etiquette.add_theme_font_size_override("font_size", 44)
	etiquette.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	etiquette.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	etiquette.grow_horizontal = Control.GROW_DIRECTION_BOTH
	etiquette.position.y -= 90.0
	couche.add_child(etiquette)
	add_child(couche)
	var clignote := create_tween().set_loops()
	clignote.tween_property(etiquette, "modulate:a", 0.15, 0.6)
	clignote.tween_property(etiquette, "modulate:a", 1.0, 0.6)


func _input(event: InputEvent) -> void:
	if not GameState.demo:
		return
	var pression := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
		or event is InputEventScreenTouch) and event.is_pressed()
	if pression:
		quitter_demo()
		get_viewport().set_input_as_handled()


func quitter_demo(changer_scene := true) -> void:
	if not GameState.demo:
		return
	GameState.demo = false
	get_tree().paused = false
	if changer_scene:
		get_tree().change_scene_to_file(SCENE_TITRE)


func _placer_ville() -> void:
	var screen_size := get_viewport_rect().size
	var texture_size: Vector2 = ville.get_node("Sprite2D").texture.get_size()
	ville.position = Vector2(screen_size.x / 2, screen_size.y - texture_size.y / 2)


## Le ciel couvre l'écran du mode et la caméra en vise le centre (en solo : 2000×648 et
## (1000, 324), les valeurs de la scène).
func _placer_ciel_et_camera() -> void:
	var taille := get_viewport_rect().size
	ciel.size = taille
	camera.position = taille / 2.0


## Un lion par joueur. Le lion de la scène prend de lui-même le joueur local ; chaque autre lion
## reçoit son joueur et des commandes manuelles AVANT l'ajout à l'arbre, sinon il prendrait en
## silence le joueur local et le clavier de ce poste (en phase 14, ses commandes viendront du
## réseau). Plusieurs lions partent en haut du ciel, répartis sur la largeur.
func _ajouter_lions() -> void:
	lions.clear()
	lions.append(lion)
	for i in range(1, GameState.joueurs.size()):
		var autre: Lion = SCENE_LION.instantiate()
		autre.name = "Lion%d" % (i + 1)
		autre.joueur = GameState.joueurs[i]
		autre.commandes = Commandes.manuelles()
		add_child(autre)
		move_child(autre, lion.get_index() + i)
		lions.append(autre)
	if lions.size() > 1:
		_repartir_lions()


## Centres des lions régulièrement espacés sur la largeur, tous à la même hauteur.
func _repartir_lions() -> void:
	var taille := get_viewport_rect().size
	for i in range(lions.size()):
		var centre_x := taille.x * (i + 0.5) / lions.size()
		lions[i].position = Vector2(centre_x - Lion.CENTRE.x, taille.y * hauteur_depart_lions)


func _process(delta: float) -> void:
	if GameState.demo and GameState.partie_en_cours:
		_demo_restant -= delta
		if _demo_restant <= 0.0:
			quitter_demo()
			return
	if _tremblement_restant <= 0.0:
		return
	_tremblement_restant = max(0.0, _tremblement_restant - delta)
	var intensite := force_tremblement * (_tremblement_restant / duree_tremblement)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * intensite
	if _tremblement_restant == 0.0:
		camera.offset = Vector2.ZERO


## La musique gagne une couche par tiers du chemin vers la victoire.
func _on_progression_changee(ratio: float) -> void:
	Audio.definir_intensite(int(ratio / GameState.seuil_victoire() * 3.0))


func trembler() -> void:
	_tremblement_restant = duree_tremblement


## Le lion du joueur local est touché : l'écran tremble.
func _on_lion_touche(_origine: Vector2) -> void:
	trembler()


func _on_partie_terminee(victoire: bool) -> void:
	if GameState.demo:
		if not victoire:
			lion.hide()
		get_tree().paused = true
		get_tree().create_timer(2.5, true).timeout.connect(quitter_demo)
		return
	if GameState.regles.compte_le_territoire():
		# Bataille : tout se fige, scores compris. Le bilan du solo ne parle que du joueur local ;
		# les résultats de la bataille, lus sur le territoire, viendront en phase 18.
		get_tree().paused = true
		return
	if not victoire:
		lion.hide()
	var overlay := game_over_scene.instantiate()
	add_child(overlay)
	overlay.afficher(victoire, GameState.progression, GameState.temps_ecoule)
	get_tree().paused = true
