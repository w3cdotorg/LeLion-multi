class_name PlacementPseudos
extends RefCounted
## Les étiquettes de pseudo des lions d'une bataille (phase 17) : deux lions qui se touchent ne
## doivent pas mêler leurs pseudos (« Joueur 3Joueur 4 »), ni un lion collé à un bord faire sortir le
## sien de l'écran. Les étiquettes glissent à l'horizontale seulement : leur hauteur, que le lion garde
## libre au-dessus de lui (`Lion._marge_haute`), ne change jamais. Logique pure, que les tests
## unitaires nomment ; la scène de jeu l'applique à chaque image (`Main._placer_pseudos`).

## Écart gardé entre deux textes voisins, en pixels de l'écran.
const ECART := 6.0


## Les textes `textes` (un rectangle par lion, en pixels de l'écran) écartés à l'horizontale pour ne
## pas se recouvrir et gardés dans l'écran, large de `largeur`. Les textes qui se recouvrent en hauteur
## (de proche en proche) forment une rangée ; dans une rangée, des textes qui se recouvrent se serrent
## en un bloc, dans leur ordre, centré sur la moyenne de leurs places voulues (deux textes s'écartent
## chacun de la moitié de ce qui manque) et ramené dans l'écran (contre un bord, l'autre prend tout
## l'écart). Renvoie le bord gauche de chaque texte, dans l'ordre reçu. Des textes plus larges, à eux
## tous, que l'écran débordent encore à droite (six pseudos de 12 caractères larges tiennent).
static func repartir(textes: Array[Rect2], largeur: float) -> Array[float]:
	var xs: Array[float] = []
	xs.resize(textes.size())
	for rangee in _rangees(textes):
		rangee.sort_custom(func(a: int, b: int) -> bool:
			return textes[a].get_center().x < textes[b].get_center().x or (textes[a].get_center().x == textes[b].get_center().x and a < b))
		# Blocs de textes serrés, de gauche à droite : {"debut", "fin" (dans `rangee`), "x", "largeur",
		# "somme" (des places voulues du bloc, chacune rapportée à son bord gauche)}
		var blocs: Array[Dictionary] = []
		for k in range(rangee.size()):
			var t: Rect2 = textes[rangee[k]]
			var bloc := {"debut": k, "fin": k, "largeur": t.size.x, "somme": t.position.x, "n": 1}
			bloc.x = _dans_l_ecran(t.position.x, t.size.x, largeur)
			while not blocs.is_empty() and blocs[-1].x + blocs[-1].largeur + ECART > bloc.x:
				var avant: Dictionary = blocs.pop_back()
				var decalage: float = avant.largeur + ECART
				var somme: float = avant.somme + bloc.somme - bloc.n * decalage
				var n: int = avant.n + bloc.n
				bloc = {"debut": avant.debut, "fin": bloc.fin, "largeur": decalage + bloc.largeur, "somme": somme, "n": n}
				bloc.x = _dans_l_ecran(somme / n, bloc.largeur, largeur)
			blocs.append(bloc)
		for bloc in blocs:
			var x: float = bloc.x
			for k in range(bloc.debut, bloc.fin + 1):
				xs[rangee[k]] = x
				x += textes[rangee[k]].size.x + ECART
	return xs


## Les rangées : les index des textes qui se recouvrent en hauteur, de proche en proche.
static func _rangees(textes: Array[Rect2]) -> Array[Array]:
	var rangee_de: Array[int] = []
	for i in range(textes.size()):
		rangee_de.append(i)
	for i in range(textes.size()):
		for j in range(i + 1, textes.size()):
			if absf(textes[i].position.y - textes[j].position.y) < minf(textes[i].size.y, textes[j].size.y):
				var vieille := rangee_de[j]
				for k in range(textes.size()):
					if rangee_de[k] == vieille:
						rangee_de[k] = rangee_de[i]
	var rangees: Dictionary[int, Array] = {}
	for i in range(textes.size()):
		if not rangees.has(rangee_de[i]):
			rangees[rangee_de[i]] = []
		rangees[rangee_de[i]].append(i)
	var resultat: Array[Array] = []
	resultat.assign(rangees.values())
	return resultat


static func _dans_l_ecran(x: float, w: float, largeur: float) -> float:
	return clampf(x, 0.0, maxf(largeur - w, 0.0))
