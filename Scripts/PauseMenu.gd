extends CanvasLayer
## Menu de pause : Échap (ou Start) l'ouvre et le ferme ; Continuer / Revenir au menu.
## En réseau (spec §4), un menu local : il ne met pas la partie en pause (elle continue chez tous ;
## la scène de jeu suspend les commandes de ce poste tant qu'il est ouvert), et « Quitter la
## partie » ramène au titre, qui quitte le réseau.

const SCENE_TITRE := "res://Scenes/Titre.tscn"
const SCENE_REGLAGES := preload("res://Scenes/Reglages.tscn")

@onready var bouton_continuer: Button = $Centre/Colonne/Continuer
@onready var bouton_reglages: Button = $Centre/Colonne/Reglages

var _reglages_ouverts := false


func _ready() -> void:
	if Reseau.en_ligne():
		$Centre/Colonne/Titre.text = "PAUSE_RESEAU"
		$Centre/Colonne/Menu.text = "QUITTER_PARTIE"


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or _reglages_ouverts:
		return
	if visible:
		reprendre()
	elif GameState.partie_en_cours:
		ouvrir()
	get_viewport().set_input_as_handled()


func ouvrir() -> void:
	if not Reseau.en_ligne():
		get_tree().paused = true
	visible = true
	Audio.arreter_vomi()
	bouton_continuer.grab_focus()


func reprendre() -> void:
	visible = false
	if not Reseau.en_ligne():
		get_tree().paused = false


func ouvrir_reglages() -> void:
	_reglages_ouverts = true
	var reglages := SCENE_REGLAGES.instantiate()
	reglages.ferme.connect(func() -> void:
		_reglages_ouverts = false
		bouton_reglages.grab_focus())
	add_child(reglages)


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_TITRE)
