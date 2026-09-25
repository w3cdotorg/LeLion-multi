class_name ReglesBataille
extends Regles
## Règles de la bataille de peinture (spec §2) : ni vies ni cœurs. Chaque joueur vomit dès le
## départ dans les trois nuances de sa couleur ; le vomi d'un autre lion l'étourdit 1,5 s (tête
## barbouillée de la couleur de l'agresseur), un ennemi 2,5 s, puis 1 s d'immunité ; chaque
## pastille donne un cran de gerbe ; l'étoile XXL est celle du solo. Le territoire (phase 9) et
## la fin de manche au chrono (phase 17) s'y ajouteront.

const DUREE_ETOURDI_VOMI := 1.5
const DUREE_ETOURDI_ENNEMI := 2.5
const DUREE_IMMUNITE := 1.0


func _init(partie_: EtatPartie) -> void:
	assert(partie_ != null, "ReglesBataille a besoin de l'état de partie")
	super(partie_)


func couleurs_de_depart(joueur: Joueur) -> Array[Color]:
	return joueur.nuances()


## Pas de vie perdue : l'ennemi étourdit, sans barbouillage.
func lion_touche_par_ennemi(joueur: Joueur, origine: Vector2) -> void:
	if not _peut_etre_etourdi(joueur):
		return
	joueur.etourdir(DUREE_ETOURDI_ENNEMI, DUREE_IMMUNITE, origine, Color.TRANSPARENT)


## Un lion étourdi ne vomit plus : s'il est signalé comme agresseur (contact de la frame où il
## a été étourdi), il n'étourdit personne.
func lion_touche_par_vomi(victime: Joueur, agresseur: Joueur, origine: Vector2) -> void:
	if victime == agresseur or agresseur.est_etourdi() or not _peut_etre_etourdi(victime):
		return
	victime.etourdir(DUREE_ETOURDI_VOMI, DUREE_IMMUNITE, origine, agresseur.couleur)
	agresseur.etourdissements_infliges += 1


## Un choc n'étourdit jamais (spec §5) ; il compte pour le titre « L'auto-tamponneur ».
func choc_entre_lions(a: Joueur, b: Joueur) -> void:
	if a == b or not _manche_en_cours():
		return
	a.chocs += 1
	b.chocs += 1


## Un cran de gerbe de plus (jusqu'à Joueur.CRANS_MAX) ; l'index de couleur ne compte pas.
func pastille_ramassee(joueur: Joueur, _index_couleur: int) -> bool:
	return joueur.gagner_cran()


func etoile_ramassee(joueur: Joueur) -> void:
	joueur.activer_bonus(ReglesSolo.DUREE_ETOILE)


# coeur_ramasse et progression_mesuree : ceux de la base, sans effet (aucun cœur en bataille,
# la manche se termine au chrono).


func _manche_en_cours() -> bool:
	return partie.partie_en_cours and partie.pret


## Un joueur déjà étourdi ou encore immunisé est ignoré : le peintre et la gerbe signalent leur
## contact à chaque frame, l'étourdissement ne doit pas redémarrer sans fin.
func _peut_etre_etourdi(joueur: Joueur) -> bool:
	return _manche_en_cours() and not joueur.est_etourdi() and not joueur.est_invulnerable()
