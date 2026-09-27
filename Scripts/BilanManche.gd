class_name BilanManche
extends RefCounted
## Le bilan d'une manche de bataille (phase 18, spec §8 ; logique pure : les tests `--script` le
## nomment) : ce que l'hôte tient pour définitif au gong, et que chaque poste affiche à l'identique sur
## l'écran Résultats. Par joueur, dans l'ordre des index : ses cellules (le territoire de l'hôte), ses
## crans, ses statistiques (étourdissements infligés, cellules volées, chocs : l'hôte seul les tient,
## spec §3.1) et s'il est parti ; et l'état final de chaque lion encore en jeu (`EtatLion`), où chaque
## client pose le sien (sa prédiction arrêtée) et ceux des autres. En réseau, la manche de l'hôte le
## relève au gong et l'envoie avec la fin (`encoder`) ; chaque client le lit (`decoder`). Hors réseau
## (bataille locale), la scène de jeu le relève elle-même. Le classement, les parts et les trois titres
## se calculent ici, sur ces seules valeurs : les mêmes sur chaque poste.

## Entiers par joueur au format réseau : cellules, crans, étourdissements infligés, cellules volées,
## chocs, parti (0 ou 1).
const CHAMPS := 6
## Octets par lion au format réseau : l'index de son joueur, puis son état (`EtatLion.TAILLE`).
const TAILLE_LION := 1 + EtatLion.TAILLE
## Les trois titres de l'écran Résultats (spec §8), dans l'ordre d'affichage : « Le plus vicieux »
## (étourdissements infligés), « Le voleur » (cellules volées), « L'auto-tamponneur » (chocs).
const TITRES: Array[StringName] = [&"vicieux", &"voleur", &"tamponneur"]

## Le chrono de l'hôte au gong, en secondes.
var temps := 0.0
var cellules: Array[int] = []
var crans: Array[int] = []
var etourdissements: Array[int] = []
var volees: Array[int] = []
var chocs: Array[int] = []
var partis: Array[bool] = []
## Par index de joueur, l'état final de son lion (`EtatLion.encoder`) ; aucun pour un joueur parti.
var lions: Dictionary[int, PackedByteArray] = {}


## Le bilan de la partie en cours, relevé chez l'hôte au gong : les joueurs `joueurs` (crans et
## statistiques), leurs cellules `cellules_par_joueur` (dans l'ordre des index), les index des partis
## `index_partis`, l'état final de chaque lion `etats` (par index de joueur) et le chrono `temps_`.
static func relever(joueurs: Array[Joueur], cellules_par_joueur: Array[int], index_partis: Array[int],
		etats: Dictionary[int, PackedByteArray], temps_: float) -> BilanManche:
	var bilan := BilanManche.new()
	bilan.temps = temps_
	for j in joueurs:
		bilan.cellules.append(cellules_par_joueur[j.index] if j.index < cellules_par_joueur.size() else 0)
		bilan.crans.append(j.crans)
		bilan.etourdissements.append(j.etourdissements_infliges)
		bilan.volees.append(j.cellules_volees)
		bilan.chocs.append(j.chocs)
		bilan.partis.append(index_partis.has(j.index))
	for index: int in etats:
		if index >= 0 and index < joueurs.size() and not index_partis.has(index):
			bilan.lions[index] = etats[index]
	return bilan


func nb_joueurs() -> int:
	return cellules.size()


## Le format réseau : `[temps, PackedInt32Array (CHAMPS entiers par joueur), PackedByteArray
## (TAILLE_LION octets par lion, par index croissant)]`.
func encoder() -> Array:
	var entiers := PackedInt32Array()
	for i in range(nb_joueurs()):
		entiers.append_array([cellules[i], crans[i], etourdissements[i], volees[i], chocs[i], 1 if partis[i] else 0])
	var octets := PackedByteArray()
	var index := lions.keys()
	index.sort()
	for i: int in index:
		octets.append(i)
		octets.append_array(lions[i])
	return [temps, entiers, octets]


## Le bilan reçu de l'hôte (`encoder`) pour une partie à `nb` joueurs, ou null s'il est mal formé :
## autre type, chrono non fini ou négatif, pas exactement CHAMPS entiers par joueur, cellules ou
## statistiques négatives, crans hors de [1, Joueur.CRANS_MAX], parti autre que 0 ou 1, lion d'un index
## hors de la partie, en double, d'un parti, ou dont l'état ne se lit pas (`EtatLion.decoder`).
static func decoder(recu: Variant, nb: int) -> BilanManche:
	if not (recu is Array) or recu.size() != 3 or not (recu[0] is float) or not (recu[1] is PackedInt32Array) \
			or not (recu[2] is PackedByteArray):
		return null
	var temps_: float = recu[0]
	var entiers: PackedInt32Array = recu[1]
	var octets: PackedByteArray = recu[2]
	if not is_finite(temps_) or temps_ < 0.0 or nb < 1 or entiers.size() != nb * CHAMPS or octets.size() % TAILLE_LION != 0:
		return null
	var bilan := BilanManche.new()
	bilan.temps = temps_
	for i in range(nb):
		var k := i * CHAMPS
		if entiers[k] < 0 or entiers[k + 1] < 1 or entiers[k + 1] > Joueur.CRANS_MAX or entiers[k + 2] < 0 \
				or entiers[k + 3] < 0 or entiers[k + 4] < 0 or (entiers[k + 5] != 0 and entiers[k + 5] != 1):
			return null
		bilan.cellules.append(entiers[k])
		bilan.crans.append(entiers[k + 1])
		bilan.etourdissements.append(entiers[k + 2])
		bilan.volees.append(entiers[k + 3])
		bilan.chocs.append(entiers[k + 4])
		bilan.partis.append(entiers[k + 5] == 1)
	for debut in range(0, octets.size(), TAILLE_LION):
		var index := octets[debut]
		var etat := octets.slice(debut + 1, debut + TAILLE_LION)
		if index >= nb or bilan.lions.has(index) or bilan.partis[index] or EtatLion.decoder(etat).is_empty():
			return null
		bilan.lions[index] = etat
	return bilan


## Le rang de chaque joueur (`ReglesBataille.rangs` : 1 pour le plus de cellules, ex æquo au même rang,
## 0 sans cellule).
func rangs() -> Array[int]:
	return ReglesBataille.rangs(cellules)


## La part de chaque joueur dans les cellules peintes (`ReglesBataille.parts` : 100 à elles toutes).
func parts() -> Array[int]:
	return ReglesBataille.parts(cellules)


## Les index des joueurs dans l'ordre du classement : le plus de cellules d'abord, à égalité le plus
## petit index (le même ordre sur chaque poste) ; les joueurs sans cellule à la fin.
func classement() -> Array[int]:
	var ordre: Array[int] = []
	for i in range(nb_joueurs()):
		ordre.append(i)
	ordre.sort_custom(func(a: int, b: int) -> bool: return cellules[a] > cellules[b] or (cellules[a] == cellules[b] and a < b))
	return ordre


## Les index des meneurs (rang 1, ex æquo compris) ; aucun si personne n'a de cellule.
func meneurs() -> Array[int]:
	var liste: Array[int] = []
	var r := rangs()
	for i in range(r.size()):
		if r[i] == 1:
			liste.append(i)
	return liste


## Les valeurs du titre `titre` (un de TITRES), par joueur.
func valeurs(titre: StringName) -> Array[int]:
	match titre:
		&"vicieux":
			return etourdissements
		&"voleur":
			return volees
		&"tamponneur":
			return chocs
	return [] as Array[int]


## Le record du titre `titre` : la plus grande de ses valeurs (0 si personne n'en a).
func record(titre: StringName) -> int:
	var plus := 0
	for v in valeurs(titre):
		plus = maxi(plus, v)
	return plus


## Les index de ceux qui portent le titre `titre` : tous ceux qui en ont le record (ex æquo compris),
## aucun si le record est nul (personne n'a étourdi, volé ou percuté personne).
func laureats(titre: StringName) -> Array[int]:
	var liste: Array[int] = []
	var plus := record(titre)
	if plus <= 0:
		return liste
	var v := valeurs(titre)
	for i in range(v.size()):
		if v[i] == plus:
			liste.append(i)
	return liste


## Le bilan en une ligne (tests réseau : la même chez l'hôte et chez chaque client).
func resume() -> String:
	var morceaux := PackedStringArray(["%.3f" % temps])
	for i in range(nb_joueurs()):
		morceaux.append("%d:%d,%d,%d,%d,%d%s" % [i, cellules[i], crans[i], etourdissements[i], volees[i], chocs[i], ":parti" if partis[i] else ""])
	var index := lions.keys()
	index.sort()
	for i: int in index:
		var etat := EtatLion.decoder(lions[i])
		morceaux.append("L%d@%.1f,%.1f,%d" % [i, etat.position.x, etat.position.y, etat.direction])
	return "|".join(morceaux)
