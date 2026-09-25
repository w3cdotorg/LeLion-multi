class_name ReglesSolo
extends Regles
## Règles du jeu solo : des cœurs, l'arc-en-ciel à débloquer pastille par pastille, et la
## victoire quand la ville est peinte au seuil de la difficulté. La durée de l'étoile XXL est
## celle de la base (`Regles.DUREE_ETOILE`).

## Invulnérabilité qui suit un coup, en secondes (le lion clignote pendant ce temps).
const DUREE_INVULNERABILITE := 1.5


func _init(partie_: EtatPartie) -> void:
	assert(partie_ != null, "ReglesSolo a besoin de l'état de partie")
	super(partie_)


func lion_touche_par_ennemi(joueur: Joueur, origine: Vector2) -> void:
	if not _manche_en_cours() or joueur.est_invulnerable():
		return
	if joueur.encaisser_coup(origine, DUREE_INVULNERABILITE) <= 0:
		partie.terminer_partie(false)


## Chaque nouvelle couleur donne aussi un cran de gerbe : le rayon de peinture grandit de 5 px
## par couleur, de 21 px (une couleur) à 46 px.
func pastille_ramassee(joueur: Joueur, index_couleur: int) -> bool:
	if index_couleur < 0 or index_couleur >= partie.nb_couleurs_total():
		return false
	if not joueur.debloquer_couleur(partie.couleur(index_couleur)):
		return false
	joueur.gagner_cran()
	return true


func etoile_ramassee(joueur: Joueur) -> void:
	joueur.activer_bonus(DUREE_ETOILE)


func coeur_ramasse(joueur: Joueur) -> bool:
	return joueur.gagner_vie(partie.VIES_MAX)


func progression_mesuree(ratio: float) -> void:
	if partie.partie_en_cours and ratio >= partie.seuil_victoire():
		partie.terminer_partie(true)
