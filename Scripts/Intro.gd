extends CanvasLayer
## Intro de niveau façon arcade : nom du stage, « PRÊT ? », « VOMISSEZ ! », puis départ.

@export var duree_etape := 0.7
## Vrai : l'intro se lance d'elle-même (solo, bataille locale). En réseau, la scène de jeu la lance
## chez tous une fois la barrière de chargement passée (`lancer`).
var automatique := true

@onready var texte: Label = $Texte

var _lancee := false


func _ready() -> void:
	if automatique:
		lancer()


func lancer() -> void:
	if _lancee:
		return
	_lancee = true
	var etapes: Array[String] = [GameState.titre_etape(), tr("PRET"), tr("VOMISSEZ")]
	var tween := create_tween()
	for i in range(etapes.size()):
		tween.tween_callback(_afficher.bind(etapes[i], i == etapes.size() - 1))
		tween.tween_property(texte, "scale", Vector2.ONE, 0.18).from(Vector2(1.5, 1.5)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(duree_etape - 0.18)
	tween.tween_callback(GameState.demarrer)
	tween.tween_property(texte, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _afficher(mot: String, dernier: bool) -> void:
	texte.text = mot
	if dernier:
		Audio.jouer("pret")
