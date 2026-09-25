class_name Territoire
extends RefCounted
## Territoire d'une bataille (spec §6), sur la grille de cellules de la ville : chaque cellule
## peignable a un propriétaire et une charge. Un tampon charge les cellules vierges et celles du
## peintre, décharge celles des autres joueurs et les leur prend quand leur charge tombe à zéro ;
## une cellule compte pour son propriétaire à partir de SEUIL_POSSESSION. Une cellule qui se met
## à compter pour un joueur alors qu'elle comptait en dernier pour un autre est un vol. Calcul
## entier et déterministe (les mêmes tampons dans le même ordre donnent le même territoire), fait
## par l'hôte seulement. Logique pure : ne nomme aucun autoload, ce qui permet de la tester dans
## un test `--script`.
##
## Les joueurs sont désignés par leur index (0 à 5, `Joueur.index`). En mémoire, le propriétaire
## tient sur un octet, décalé de un : 0 = personne, 1 à 6 = joueurs 0 à 5 (le format réseau du
## spec §6).

## Charge qu'un tampon donne à une cellule vierge ou du peintre, et retire à une cellule adverse.
const GAIN := 4
## Charge à partir de laquelle une cellule compte pour son propriétaire : 3 tampons sur une
## cellule vierge, ce qui suit la mesure de couverture du solo pour une gerbe en mouvement.
const SEUIL_POSSESSION := 12
## Une cellule repeinte par son propriétaire se renforce jusqu'à CHARGE_MAX : la vider demande
## alors 6 tampons adverses, et il en faut 3 de plus pour qu'elle compte pour le voleur.
const CHARGE_MAX := 24
const PERSONNE := -1

var taille_grille: Vector2i
var taille_cellule: int
## Nombre de cellules peignables : le total d'un score en pourcentage.
var nb_peignables := 0

var _peignables: PackedByteArray
var _proprietaires: PackedByteArray   # 0 = personne, 1 à 6 = index du joueur + 1
var _charges: PackedByteArray
var _cellules: PackedInt32Array       # cellules qui comptent, par propriétaire (0 : pour personne)
var _dernier_compte: PackedByteArray  # dernier propriétaire pour qui la cellule a compté (0 : aucun)
var _changee: PackedByteArray         # 1 = déjà dans _changements
var _changements: PackedInt32Array


## `peignables` : un octet par cellule, rangée par rangée (1 = peignable), comme la ville le
## calcule ; `taille_cellule` en pixels de la ville.
func _init(taille_grille_: Vector2i, peignables: PackedByteArray, taille_cellule_: int = 8) -> void:
	assert(peignables.size() == taille_grille_.x * taille_grille_.y, "une valeur de peignable par cellule")
	taille_grille = taille_grille_
	taille_cellule = taille_cellule_
	_peignables = peignables
	nb_peignables = peignables.count(1)
	var nb := peignables.size()
	_proprietaires.resize(nb)
	_charges.resize(nb)
	_dernier_compte.resize(nb)
	_changee.resize(nb)
	_cellules.resize(EtatPartie.NB_JOUEURS_MAX + 1)
	reinitialiser()


## Toute la ville redevient vierge (nouvelle manche), sans changement à synchroniser.
func reinitialiser() -> void:
	_proprietaires.fill(0)
	_charges.fill(0)
	_dernier_compte.fill(0)
	_changee.fill(0)
	_cellules.fill(0)
	_cellules[0] = nb_peignables
	_changements.clear()


## Applique le tampon du joueur `index_joueur`, centré en `centre` (pixels de la ville), de rayon
## `rayon` : il touche les cellules peignables dont le centre est à moins de `rayon`. Renvoie le
## nombre de cellules que ce tampon vole (elles se mettent à compter pour le peintre alors
## qu'elles comptaient en dernier pour un autre joueur) : deux peintres qui se disputent une
## cellule que personne n'a encore possédée ne se volent rien. Coût mesuré au moment du plan :
## environ 25 µs pour un tampon de 46 px.
func tamponner(index_joueur: int, centre: Vector2i, rayon: int) -> int:
	assert(index_joueur >= 0 and index_joueur < EtatPartie.NB_JOUEURS_MAX, "index de joueur de 0 à 5")
	if rayon <= 0:
		return 0
	var peintre := index_joueur + 1
	var demi := taille_cellule / 2
	var r2 := rayon * rayon
	# Colonnes et rangées bornées à la grille : un tampon qui déborde à gauche ne touche jamais
	# la fin de la rangée précédente.
	var cx_min := maxi(0, (centre.x - rayon) / taille_cellule)
	var cx_max := mini(taille_grille.x - 1, (centre.x + rayon) / taille_cellule)
	var cy_min := maxi(0, (centre.y - rayon) / taille_cellule)
	var cy_max := mini(taille_grille.y - 1, (centre.y + rayon) / taille_cellule)
	var volees := 0
	for cy in range(cy_min, cy_max + 1):
		var dy := cy * taille_cellule + demi - centre.y
		var reste := r2 - dy * dy
		if reste <= 0:
			continue
		var ligne := cy * taille_grille.x
		for cx in range(cx_min, cx_max + 1):
			var dx := cx * taille_cellule + demi - centre.x
			if dx * dx >= reste:
				continue
			var i := ligne + cx
			if _peignables[i] == 0:
				continue
			var proprietaire_ := _proprietaires[i]
			var charge_ := _charges[i]
			var compte_avant := proprietaire_ if charge_ >= SEUIL_POSSESSION else 0
			if proprietaire_ == peintre or proprietaire_ == 0:
				proprietaire_ = peintre
				charge_ = mini(charge_ + GAIN, CHARGE_MAX)
			else:
				charge_ -= GAIN
				if charge_ <= 0:
					proprietaire_ = peintre
					charge_ = -charge_
			_proprietaires[i] = proprietaire_
			_charges[i] = charge_
			var compte_apres := proprietaire_ if charge_ >= SEUIL_POSSESSION else 0
			if compte_apres == compte_avant:
				continue
			_cellules[compte_avant] -= 1
			_cellules[compte_apres] += 1
			if compte_apres != 0:
				var dernier := _dernier_compte[i]
				if dernier != 0 and dernier != compte_apres:
					volees += 1
				_dernier_compte[i] = compte_apres
			if _changee[i] == 0:
				_changee[i] = 1
				_changements.append(i)
	return volees


## Cellules qui comptent pour le joueur `index_joueur` : son score. `cellules_de(PERSONNE)` :
## les cellules peignables qui ne comptent pour personne.
func cellules_de(index_joueur: int) -> int:
	return _cellules[index_joueur + 1]


## Index du joueur pour qui la cellule compte, PERSONNE si elle ne compte pour personne.
func proprietaire_compte(cellule: int) -> int:
	return _proprietaires[cellule] - 1 if _charges[cellule] >= SEUIL_POSSESSION else PERSONNE


## Index du dernier joueur qui a chargé la cellule (qu'elle compte ou non), PERSONNE si elle est
## vierge.
func proprietaire(cellule: int) -> int:
	return _proprietaires[cellule] - 1


func charge(cellule: int) -> int:
	return _charges[cellule]


## Cellules dont le propriétaire compté a changé depuis le dernier appel, chacune une fois, dans
## l'ordre de leur premier changement (synchronisation des scores, phase 14) ; vide la liste.
## Une cellule revenue à son propriétaire compté d'avant y figure quand même : la renvoyer est
## sans effet.
func extraire_changements() -> PackedInt32Array:
	var liste := _changements
	_changements = PackedInt32Array()
	for i in liste:
		_changee[i] = 0
	return liste
