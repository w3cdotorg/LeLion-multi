extends Pastille
## Pastille de couleur ; son effet dépend des règles (en solo, une couleur de l'arc-en-ciel, en
## bataille un cran de gerbe).

@export var couleur_index: int = 0


func _ready() -> void:
	$Sprite2D.modulate = GameState.couleur(couleur_index)


func _ramasser(joueur: Joueur) -> void:
	GameState.regles.pastille_ramassee(joueur, couleur_index)
