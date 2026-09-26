class_name Peinture
extends RefCounted
## La peinture d'un tampon en logique pure (ne nomme aucun autoload : testable dans un test
## `--script`) : les jeux de tampons, le tirage de chaque tampon et le format réseau des tampons que
## l'hôte diffuse (spec §6). Chaque poste doit dessiner exactement le même tampon :
## - un jeu de tampons (NB_TAMPONS images d'un rayon et d'un jeu de couleurs) est tiré d'un
##   générateur dont la graine est dérivée de sa clé (`cle_tampons(...).hash()`) : chaque poste qui
##   le génère, au premier usage, à n'importe quel moment, obtient les mêmes images ;
## - la variante et la coulure d'un tampon viennent de sa graine u16 (`tirage`), tirée par l'hôte
##   (`randi()`) et diffusée avec lui.
## Ni l'un ni l'autre ne consomme le hasard global (`randi`, `randf`), dont dépendent le Spawner et
## les ennemis.

## Variantes d'un jeu de tampons.
const NB_TAMPONS := 4
## Densité des pixels d'un tampon, au centre (plus épars vers le bord).
const DENSITE_TAMPON := 0.5
## Probabilité qu'un tampon lâche une coulure.
const CHANCE_COULURE := 0.3
## Longueur d'une coulure sous le bas du tampon, en pixels (min, max).
const LONGUEUR_COULURE := Vector2i(14, 44)
## Format réseau d'un tampon : index du joueur u8, x i16, y i16 (le centre, en pixels de la ville :
## négatif quand le tampon déborde en haut ou à gauche, ce qu'un u16 ferait boucler vers ~65 500),
## rayon u8, graine u16.
const OCTETS_PAR_TAMPON := 8
const RAYON_MAX := 255
const GRAINE_MAX := 0xFFFF


## Le rayon puis chaque couleur en RGBA 8 bits, dans l'ordre : deux jeux qui ne diffèrent que par
## une couleur ont des clés différentes (le même jeu dans un autre ordre aussi : une entrée de cache
## redondante, pas un mauvais rendu).
static func cle_tampons(rayon: int, couleurs: Array[Color]) -> String:
	var cle := str(rayon)
	for c in couleurs:
		cle += ":%08x" % c.to_rgba32()
	return cle


## Les NB_TAMPONS tampons de ce rayon et de ce jeu de couleurs : denses au centre, épars sur les
## bords, chaque pixel d'une des couleurs. Toujours les mêmes images pour la même clé.
static func generer_tampons(rayon: int, couleurs: Array[Color]) -> Array[Image]:
	var rng := RandomNumberGenerator.new()
	rng.seed = cle_tampons(rayon, couleurs).hash()
	var tampons: Array[Image] = []
	var taille := rayon * 2 + 1
	for t in range(NB_TAMPONS):
		var tampon := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
		tampon.fill(Color(0, 0, 0, 0))
		for y in range(taille):
			for x in range(taille):
				var dx := x - rayon
				var dy := y - rayon
				var d := sqrt(dx * dx + dy * dy) / rayon
				if d > 1.0:
					continue
				# Plus dense au centre, éparse sur les bords.
				if rng.randf() < DENSITE_TAMPON * (1.3 - d):
					var c := couleurs[rng.randi() % couleurs.size()]
					c.a = 1.0
					tampon.set_pixel(x, y, c)
		tampons.append(tampon)
	return tampons


## Le tirage d'un tampon de graine `graine` (0 à GRAINE_MAX), de rayon `rayon`, peint dans
## `nb_couleurs` couleurs : `{"variante": int, "coulure": bool, "dx": int, "dy": int,
## "longueur": int, "couleur": int}` (la coulure part de (dx, dy) autour du centre, dx dans
## [-rayon, rayon], dy dans [0, rayon], et descend de `longueur` px sous le bas du tampon, dans la
## couleur d'index `couleur`). Le même sur chaque poste pour la même graine.
static func tirage(graine: int, rayon: int, nb_couleurs: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	return {
		"variante": rng.randi() % NB_TAMPONS,
		"coulure": rng.randf() < CHANCE_COULURE,
		"dx": rng.randi_range(-rayon, rayon),
		"dy": rng.randi_range(0, rayon),
		"longueur": rng.randi_range(LONGUEUR_COULURE.x, LONGUEUR_COULURE.y),
		"couleur": rng.randi() % maxi(nb_couleurs, 1),
	}


## Les tampons `{"index", "x", "y", "rayon", "graine"}` d'une frame de l'hôte, dans l'ordre, au format
## réseau (OCTETS_PAR_TAMPON octets chacun). Les valeurs sont ramenées dans leur plage (x et y en i16,
## rayon en u8, graine en u16) : la ville n'en produit jamais d'autres.
static func encoder_tampons(tampons: Array[Dictionary]) -> PackedByteArray:
	var octets := PackedByteArray()
	octets.resize(tampons.size() * OCTETS_PAR_TAMPON)
	for i in range(tampons.size()):
		var t: Dictionary = tampons[i]
		var o := i * OCTETS_PAR_TAMPON
		octets.encode_u8(o, clampi(t.index, 0, 255))
		octets.encode_s16(o + 1, clampi(t.x, -32768, 32767))
		octets.encode_s16(o + 3, clampi(t.y, -32768, 32767))
		octets.encode_u8(o + 5, clampi(t.rayon, 0, RAYON_MAX))
		octets.encode_u16(o + 6, clampi(t.graine, 0, GRAINE_MAX))
	return octets


## Les tampons reçus de l'hôte, dans l'ordre ; un tableau vide pour tout ce qui n'est pas un lot
## bien formé (pas un `PackedByteArray`, taille qui n'est pas un multiple de OCTETS_PAR_TAMPON, index
## de joueur hors de [0, `EtatPartie.NB_JOUEURS_MAX`[) : un lot douteux est ignoré en entier.
static func decoder_tampons(octets: Variant) -> Array[Dictionary]:
	var tampons: Array[Dictionary] = []
	if not (octets is PackedByteArray) or octets.size() % OCTETS_PAR_TAMPON != 0:
		return tampons
	for o in range(0, octets.size(), OCTETS_PAR_TAMPON):
		var index: int = octets.decode_u8(o)
		if index >= EtatPartie.NB_JOUEURS_MAX:
			return [] as Array[Dictionary]
		tampons.append({"index": index, "x": octets.decode_s16(o + 1), "y": octets.decode_s16(o + 3),
			"rayon": octets.decode_u8(o + 5), "graine": octets.decode_u16(o + 6)})
	return tampons
