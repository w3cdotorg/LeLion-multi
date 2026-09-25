class_name ReglesBataille
extends Regles
## Règles de la bataille de peinture (spec §2) : ni vies ni cœurs. Chaque joueur vomit dès le
## départ dans les trois nuances de sa couleur ; le vomi d'un autre lion l'étourdit 1,5 s (tête
## barbouillée de la couleur de l'agresseur), un ennemi 2,5 s, puis 1 s d'immunité ; chaque
## pastille donne un cran de gerbe ; l'étoile XXL est celle du solo. La manche se joue au
## territoire, que tient la ville (`Territoire`) : les règles en comptent les vols. L'écran est
## en 16:9 ; une pastille est toujours offerte, l'étoile toujours possible, jamais de cœur. La
## fin de manche au chrono (phase 17) s'y ajoutera.

const DUREE_ETOURDI_VOMI := 1.5
const DUREE_ETOURDI_ENNEMI := 2.5
const DUREE_IMMUNITE := 1.0
## Durée d'une manche (spec §2), dont le temps écoulé fait l'avancement. Le chrono qui la termine
## vient en phase 17.
const DUREE_MANCHE := 90.0
## Écran de la bataille (spec §7) : 16:9, la skyline posée en bas sous un grand ciel.
const TAILLE_ECRAN := Vector2i(2000, 1125)


func _init(partie_: EtatPartie) -> void:
	assert(partie_ != null, "ReglesBataille a besoin de l'état de partie")
	super(partie_)


func couleurs_de_depart(joueur: Joueur) -> Array[Color]:
	return joueur.nuances()


func compte_le_territoire() -> bool:
	return true


func taille_ecran() -> Vector2i:
	return TAILLE_ECRAN


## Le temps de la manche : la ville peinte ne dit rien de la fin d'une bataille.
func avancement() -> float:
	return partie.temps_ecoule / DUREE_MANCHE


## Une pastille donne un cran quelle que soit sa couleur : une couleur de l'arc-en-ciel au hasard,
## pour l'œil seulement.
func pastille_a_offrir() -> int:
	return randi() % partie.nb_couleurs_total()


## Chaque lion vomit dès le départ : l'étoile peut toujours apparaître (premier arrivé, premier
## servi), quel que soit l'état du joueur local.
func etoile_peut_apparaitre() -> bool:
	return true


## Pas de vie perdue : l'ennemi étourdit, sans barbouillage.
func lion_touche_par_ennemi(joueur: Joueur, origine: Vector2) -> void:
	if not _peut_etre_etourdi(joueur):
		return
	joueur.etourdir(DUREE_ETOURDI_ENNEMI, DUREE_IMMUNITE, origine, Color.TRANSPARENT)


## Un lion étourdi ne vomit plus : s'il est signalé comme agresseur, il n'étourdit personne, sauf
## si son étourdissement date de cette frame-ci (trade tête-à-tête : deux lions se vomissent
## dessus la même frame, les deux rapports doivent porter et les étourdir tous les deux).
func lion_touche_par_vomi(victime: Joueur, agresseur: Joueur, origine: Vector2) -> void:
	var agresseur_deja_etourdi := agresseur.est_etourdi() and agresseur.etourdi_a_la_frame < Engine.get_physics_frames()
	if victime == agresseur or agresseur_deja_etourdi or not _peut_etre_etourdi(victime):
		return
	victime.etourdir(DUREE_ETOURDI_VOMI, DUREE_IMMUNITE, origine, agresseur.couleur)
	agresseur.etourdissements_infliges += 1


## Un choc n'étourdit jamais (spec §5) ; il compte pour le titre « L'auto-tamponneur ».
func choc_entre_lions(a: Joueur, b: Joueur) -> void:
	if a == b or not manche_en_cours():
		return
	a.chocs += 1
	b.chocs += 1


## Un cran de gerbe de plus (jusqu'à Joueur.CRANS_MAX) ; l'index de couleur ne compte pas.
func pastille_ramassee(joueur: Joueur, _index_couleur: int) -> bool:
	return joueur.gagner_cran()


func etoile_ramassee(joueur: Joueur) -> void:
	joueur.activer_bonus(DUREE_ETOILE)


## Les cellules volées comptent pour le titre « Le voleur » (écran Résultats), pendant la manche.
func vol_de_cellules(voleur: Joueur, nb: int) -> void:
	if nb > 0 and manche_en_cours():
		voleur.cellules_volees += nb


# coeur_ramasse, progression_mesuree, coeurs_en_jeu et coeur_peut_apparaitre : ceux de la base,
# sans effet (aucun cœur en bataille, la manche se termine au chrono).


## Un joueur déjà étourdi ou encore immunisé est ignoré : le peintre et la gerbe signalent leur
## contact à chaque frame, l'étourdissement ne doit pas redémarrer sans fin.
func _peut_etre_etourdi(joueur: Joueur) -> bool:
	return manche_en_cours() and not joueur.est_etourdi() and not joueur.est_invulnerable()
