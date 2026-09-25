extends CanvasLayer
## Affiche la progression de la peinture, les couleurs débloquées et le chrono.

const TAILLE_PASTILLE := Vector2(36, 36)
const COULEUR_VERROUILLEE := Color(1, 1, 1, 0.15)
const TEXTURE_COEUR := preload("res://Assets/Sprites/coeur.png")
const COULEUR_COEUR := Color(1.0, 0.3, 0.35)
const COULEUR_COEUR_PERDU := Color(1, 1, 1, 0.15)

@onready var flash: ColorRect = $Flash
@onready var vies: HBoxContainer = $Marge/Ligne/Vies
@onready var progression: ProgressBar = $Marge/Ligne/Progression
@onready var pourcent: Label = $Marge/Ligne/Progression/Pourcent
@onready var repere_seuil: ColorRect = $Marge/Ligne/Progression/RepereSeuil
@onready var couleurs: HBoxContainer = $Marge/Ligne/Couleurs
@onready var chrono: Label = $Marge/Ligne/Chrono
@onready var etape: Label = $Marge/Ligne/Etape
@onready var indice: Label = $Indice
@onready var etiquette_bonus: Label = $Marge/Ligne/Bonus

var _pastilles: Array[ColorRect] = []
var _coeurs: Array[TextureRect] = []
## Le HUD du solo suit le joueur local (la bataille aura son propre HUD, phase 17).
var _joueur: Joueur


func _ready() -> void:
	_joueur = GameState.joueur_local()
	for i in range(GameState.nb_couleurs_total()):
		var pastille := ColorRect.new()
		pastille.custom_minimum_size = TAILLE_PASTILLE
		pastille.color = COULEUR_VERROUILLEE
		couleurs.add_child(pastille)
		_pastilles.append(pastille)

	for i in range(GameState.VIES_MAX):
		var coeur := TextureRect.new()
		coeur.texture = TEXTURE_COEUR
		coeur.custom_minimum_size = TAILLE_PASTILLE
		coeur.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coeur.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vies.add_child(coeur)
		_coeurs.append(coeur)
	_on_vies_changees(_joueur.vies)

	_joueur.vies_changees.connect(_on_vies_changees)
	_joueur.touche.connect(_on_lion_touche)
	GameState.progression_changee.connect(_on_progression_changee)
	_joueur.couleur_debloquee.connect(_on_couleur_debloquee)
	if DisplayServer.is_touchscreen_available():
		indice.text = "INDICE_TACTILE"
	_placer_repere_seuil()
	etape.visible = GameState.mode_arcade
	if GameState.mode_arcade:
		etape.text = GameState.titre_etape()
	_on_progression_changee(GameState.progression)
	for c in _joueur.couleurs_debloquees:
		_on_couleur_debloquee(c)


func _process(_delta: float) -> void:
	chrono.text = GameState.formater_temps(GameState.temps_ecoule)
	etiquette_bonus.visible = _joueur.bonus_actif()
	if etiquette_bonus.visible:
		etiquette_bonus.text = tr("BONUS_XXL") % ceili(_joueur.bonus_restant)



func _on_lion_touche(_origine: Vector2) -> void:
	flash.color.a = 0.45
	create_tween().tween_property(flash, "color:a", 0.0, 0.4)


## Affiche autant de cœurs que la difficulté en accorde ; les perdus restent en grisé.
func _on_vies_changees(nb: int) -> void:
	var max_difficulte: int = GameState.difficulte().vies
	for i in range(_coeurs.size()):
		_coeurs[i].visible = i < max_difficulte
		_coeurs[i].modulate = COULEUR_COEUR if i < nb else COULEUR_COEUR_PERDU


## Trait jaune sur la barre à la hauteur du pourcentage à atteindre.
func _placer_repere_seuil() -> void:
	var x := GameState.seuil_victoire() * progression.size.x
	repere_seuil.offset_left = x - 1.5
	repere_seuil.offset_right = x + 1.5


func _on_progression_changee(ratio: float) -> void:
	var valeur := ratio * 100.0
	progression.value = valeur
	pourcent.text = "%d %%" % int(round(valeur))


func _on_couleur_debloquee(couleur: Color) -> void:
	var index := _joueur.couleurs_debloquees.find(couleur)
	if index >= 0 and index < _pastilles.size():
		_pastilles[index].color = couleur
	indice.hide()
