class_name ReglesBataille
extends Regles
## Règles de la bataille de peinture (spec §2) : ni vies ni cœurs. Chaque joueur vomit dès le
## départ dans les trois nuances de sa couleur ; le vomi d'un autre lion l'étourdit 1,5 s (tête
## barbouillée de la couleur de l'agresseur) puis l'immunise 1 s, un ennemi l'étourdit 2,5 s puis lui
## laisse 3 s de répit (le temps de fuir le peintre, phase 17) ; chaque
## pastille donne un cran de gerbe ; l'étoile XXL est celle du solo. La manche se joue au
## territoire, que tient la ville (`Territoire`) : les règles en comptent les vols. L'écran est
## en 16:9 ; une pastille est toujours offerte (plusieurs à la fois, qui expirent), l'étoile toujours
## possible, jamais de cœur ; le peintre se repose deux fois plus longtemps qu'en solo. Le
## chrono termine la manche chez l'hôte (phase 17) ; le plus de cellules gagne, ex æquo possibles
## (`rangs`).

const DUREE_ETOURDI_VOMI := 1.5
const DUREE_ETOURDI_ENNEMI := 2.5
const DUREE_IMMUNITE := 1.0
## Réglages du rythme de la manche à 4-6 joueurs (phase 17, faits sans essai à 4-6 : à revoir à
## l'essai LAN de la phase 19). Après un étourdissement par un ennemi, le répit (l'immunité) laisse le
## temps de fuir : à 350 px/s, 3 s font plus de 1000 px, plus de deux fois la largeur du peintre
## (442 px) ; l'immunité après un vomi reste de 1 s (les duels ne changent pas).
const DUREE_REPIT_ENNEMI := 3.0
## Pastilles en même temps au plus : environ une pour deux joueurs, pour qu'il y en ait toujours une
## à portée sans cesser de se les disputer.
const PASTILLES_JUSQU_A_3_JOUEURS := 2
const PASTILLES_A_4_JOUEURS_ET_PLUS := 3
## Délai entre deux arrivées (6 s en solo) : le plafond est atteint en 9 s, et une pastille partie
## est remplacée en 4 s ; de l'ordre de 20 pastilles par manche au lieu de 13, 3 à 4 crans par joueur
## à 6 au lieu de 2.
const DELAI_ENTRE_PASTILLES := 4.0
## Durée de vie d'une pastille que personne ne ramasse : trois délais d'arrivée, bien plus que la
## traversée de l'écran (2000 px à 350 px/s : moins de 6 s) ; une pastille oubliée ne bloque plus les
## autres sous le plafond.
const DUREE_DE_VIE_PASTILLE := 12.0
## La pause du peintre hors de l'écran, deux fois celle du solo (4 s au lieu de 2, 2,6 s en fin de
## manche) : la bande de peinture est libre un tiers du temps au lieu d'un cinquième.
const FACTEUR_REPOS_PEINTRE := 2.0
## Bande du HUD en haut de l'écran de bataille (extra, revue de capture du 27/09 : une pastille née
## juste sous les vignettes se retrouvait partiellement cachée derrière elles) sous laquelle aucune
## pastille ne doit apparaître, à l'échelle de l'écran de bataille (1125 px de haut) : le bas des
## vignettes (`HUDBataille` : 10 px de marge du conteneur, 112 px de haut) plus le rayon d'une
## pastille (`ColorPickup`, 28 px) et un peu d'air.
const HAUTEUR_BANDE_HUD := 160.0
## Durée d'une manche (spec §2) : son temps écoulé fait l'avancement, et le chrono la termine chez
## l'hôte.
const DUREE_MANCHE := 90.0
## Secondes restantes à partir desquelles le chrono du HUD passe au rouge et tique (spec §8).
const SECONDES_TIC := 10
## Écran de la bataille (spec §7) : 16:9, la skyline posée en bas sous un grand ciel.
const TAILLE_ECRAN := Vector2i(2000, 1125)

## Durée des prochaines manches : DUREE_MANCHE, réglable par le test réseau (une manche courte ; le
## script, `load("res://Scripts/ReglesBataille.gd")`, porte cette variable, comme
## `Manche.delai_chargement`).
static var duree_manche := DUREE_MANCHE


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
	return partie.temps_ecoule / duree_manche


## Secondes de manche qui restent, jamais négatives.
func temps_restant() -> float:
	return maxf(duree_manche - partie.temps_ecoule, 0.0)


## Le chrono du HUD, en secondes entières : arrondi au-dessus (1:30 pendant la première seconde,
## 0:01 jusqu'au bout, 0:00 une fois la manche finie).
func secondes_restantes() -> int:
	return ceili(temps_restant())


## Le chrono arrivé à zéro termine la manche (spec §2 : personne n'est éliminé). Appelé chez l'hôte
## seulement (`GameState._process`) : le chrono d'un client, parti à la fin de sa propre intro, est
## décalé de la latence ; il attend la fin de l'hôte (`Manche`).
func temps_ecoule_change() -> void:
	if manche_en_cours() and partie.temps_ecoule >= duree_manche:
		partie.terminer_partie(true)


## Le rang de chaque joueur d'après ses cellules (`cellules[i]` : celles du joueur d'index i) : 1
## pour le plus de cellules, les ex æquo au même rang, le suivant sautant d'autant (1, 1, 3) ; 0
## pour un joueur sans cellule, pas classé (au départ, personne ne mène).
static func rangs(cellules: Array[int]) -> Array[int]:
	var resultat: Array[int] = []
	for n in cellules:
		var rang := 0
		if n > 0:
			rang = 1
			for autre in cellules:
				if autre > n:
					rang += 1
		resultat.append(rang)
	return resultat


## La part de chaque joueur dans les cellules possédées (`cellules[i]` : celles du joueur d'index i),
## en pourcents entiers qui font 100 à eux tous : les centièmes perdus à l'arrondi vont aux plus grands
## restes (à égalité, au plus petit index), jamais à un joueur sans cellule ; toutes nulles tant que
## personne ne possède de cellule. Ce qu'affiche le HUD (spec §8) ; le classement vient des cellules
## (`rangs`), pas de ces parts arrondies.
static func parts(cellules: Array[int]) -> Array[int]:
	var total := 0
	for n in cellules:
		total += n
	var resultat: Array[int] = []
	var restes: Array[Vector2i] = []  # (reste, index)
	var distribue := 0
	for i in range(cellules.size()):
		var part := 0 if total <= 0 else cellules[i] * 100 / total
		resultat.append(part)
		distribue += part
		restes.append(Vector2i(0 if total <= 0 else cellules[i] * 100 % total, i))
	if total <= 0:
		return resultat
	restes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x > b.x or (a.x == b.x and a.y < b.y))
	for k in range(100 - distribue):
		resultat[restes[k].y] += 1
	return resultat


## Une pastille donne un cran quelle que soit sa couleur : une couleur de l'arc-en-ciel au hasard,
## pour l'œil seulement.
func pastille_a_offrir() -> int:
	return randi() % partie.nb_couleurs_total()


## Chaque lion vomit dès le départ : l'étoile peut toujours apparaître (premier arrivé, premier
## servi), quel que soit l'état du joueur local.
func etoile_peut_apparaitre() -> bool:
	return true


## À plusieurs, un lion est presque toujours près d'une pastille qui naît : jamais collée à l'un d'eux
## (point de vigilance de la phase 17).
func pastilles_loin_des_lions() -> bool:
	return true


## Deux pastilles à la fois de 2 à 3 joueurs, trois de 4 à 6.
func pastilles_en_meme_temps() -> int:
	return PASTILLES_JUSQU_A_3_JOUEURS if partie.joueurs.size() <= 3 else PASTILLES_A_4_JOUEURS_ET_PLUS


func pastille_peut_arriver(presentes: int) -> bool:
	return presentes < pastilles_en_meme_temps()


func delai_entre_pastilles(_delai_du_spawner: float) -> float:
	return DELAI_ENTRE_PASTILLES


func duree_de_vie_pastille() -> float:
	return DUREE_DE_VIE_PASTILLE


func facteur_repos_peintre() -> float:
	return FACTEUR_REPOS_PEINTRE


## Sous la bande du HUD (extra, revue de capture) : une pastille ne naît plus partiellement cachée
## derrière les vignettes. Ne change que le haut de la zone (son bas, `zone.end.y`, ne bouge pas).
func zone_pickups_ajustee(zone: Rect2) -> Rect2:
	var echelle := TAILLE_ECRAN.y / float(Regles.TAILLE_ECRAN_SOLO.y)
	var decalage := maxf(0.0, HAUTEUR_BANDE_HUD / echelle - zone.position.y)
	zone.position.y += decalage
	zone.size.y -= decalage
	return zone


## Pas de vie perdue : l'ennemi étourdit, sans barbouillage, puis laisse son répit (le peintre, qui
## couvre la bande de peinture, étourdirait sinon sans relâche un lion qui vient de se réveiller dessous).
func lion_touche_par_ennemi(joueur: Joueur, origine: Vector2) -> void:
	if not _peut_etre_etourdi(joueur):
		return
	joueur.etourdir(DUREE_ETOURDI_ENNEMI, DUREE_REPIT_ENNEMI, origine, Color.TRANSPARENT)


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
