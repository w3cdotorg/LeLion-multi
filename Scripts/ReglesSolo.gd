class_name ReglesSolo
extends Regles
## Règles du jeu solo : des cœurs, l'arc-en-ciel à débloquer pastille par pastille, et la
## victoire quand la ville est peinte au seuil de la difficulté.

## Durée de la gerbe XXL donnée par une étoile.
const DUREE_ETOILE := 8.0


func _init(partie_: EtatPartie) -> void:
	assert(partie_ != null, "ReglesSolo a besoin de l'état de partie")
	super(partie_)


func lion_touche_par_ennemi(joueur: Joueur, origine: Vector2) -> void:
	if not partie.partie_en_cours or not partie.pret or joueur.est_invulnerable():
		return
	if joueur.encaisser_coup(origine, partie.DUREE_INVULNERABILITE) <= 0:
		partie.terminer_partie(false)


func pastille_ramassee(joueur: Joueur, index_couleur: int) -> bool:
	if index_couleur < 0 or index_couleur >= partie.nb_couleurs_total():
		return false
	return joueur.debloquer_couleur(partie.couleur(index_couleur))


func etoile_ramassee(joueur: Joueur) -> void:
	joueur.activer_bonus(DUREE_ETOILE)


func coeur_ramasse(joueur: Joueur) -> bool:
	return joueur.gagner_vie(partie.VIES_MAX)


func progression_mesuree(ratio: float) -> void:
	if partie.partie_en_cours and ratio >= partie.seuil_victoire():
		partie.terminer_partie(true)
