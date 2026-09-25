extends Node2D
## La ville : masque de peinture RGBA appliqué par shader sur la skyline.
## La peinture se fait par tampons multicolores (blit natif), aux couleurs du joueur qui peint.
## La progression est mesurée sur une grille de cellules couvrant les zones opaques de la
## skyline : une cellule compte quand au moins COUVERTURE_CELLULE de sa surface est réellement
## peinte (mesure par réduction du masque, à intervalle régulier). En bataille, la même grille
## porte aussi le territoire (`Territoire`) : l'hôte y reporte chaque tampon.

const TAILLE_CELLULE := 8
const NB_TAMPONS := 4
const DENSITE_TAMPON := 0.5
const CHANCE_COULURE := 0.3
const COULURES_MAX := 40
const VITESSE_COULURE := 70.0  # px/s
const INTERVALLE_MESURE := 0.2  # s
const COUVERTURE_CELLULE := 0.4
## Jeux de tampons gardés au plus (un jeu par rayon et jeu de couleurs) ; au-delà, le cache est
## vidé. 6 joueurs × 7 crans × 2 (étoile XXL) en demandent 84 au pire.
const TAMPONS_EN_CACHE_MAX := 96

@onready var sprite: Sprite2D = $Sprite2D
@onready var zone_shape: CollisionShape2D = $PeintureZone/CollisionShape2D

var tex_size: Vector2i
var image: Image
var texture: ImageTexture

var grille_taille: Vector2i
var cellules_peignables := 0
var cellules_peintes := 0
## Grille de propriété de la bataille (propriétaire et charge par cellule, scores par joueur),
## créée par `charger_skyline` quand les règles se jouent au territoire ; null en solo.
var territoire: Territoire
var _cellules_peignables: PackedByteArray
var _a_mesurer := false
var _temps_mesure := 0.0

var _dirty := false
var coulures: Array[Dictionary] = []
## Tampons par rayon et jeu de couleurs (clé : `_cle_tampons`) : deux lions qui ont autant de
## couleurs et le même rayon peignent chacun avec les leurs.
var _tampons: Dictionary[String, Array] = {}


func _ready() -> void:
	charger_skyline(sprite.texture)


## Remplace la skyline : recalcule la grille, le masque de peinture et la zone de collision.
func charger_skyline(nouvelle: Texture2D) -> void:
	sprite.texture = nouvelle
	tex_size = Vector2i(nouvelle.get_width(), nouvelle.get_height())
	cellules_peignables = 0
	cellules_peintes = 0
	coulures.clear()
	_tampons.clear()
	_calculer_cellules_peignables()
	territoire = Territoire.new(grille_taille, _cellules_peignables, TAILLE_CELLULE) \
		if GameState.regles.compte_le_territoire() else null

	image = Image.create(tex_size.x, tex_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	texture = ImageTexture.create_from_image(image)
	(sprite.material as ShaderMaterial).set_shader_parameter("paint_mask", texture)

	var forme := RectangleShape2D.new()
	forme.size = Vector2(tex_size)
	zone_shape.shape = forme
	zone_shape.position = Vector2.ZERO


func _process(delta: float) -> void:
	_avancer_coulures(delta)
	if _dirty:
		_dirty = false
		_a_mesurer = true
		texture.update(image)
	_temps_mesure += delta
	if _a_mesurer and _temps_mesure >= INTERVALLE_MESURE:
		_temps_mesure = 0.0
		_a_mesurer = false
		mesurer_progression()


## Réduit le masque à la grille : l'alpha moyen d'une cellule est sa couverture peinte.
func mesurer_progression() -> float:
	var reduite: Image = image.duplicate()
	reduite.resize(grille_taille.x, grille_taille.y, Image.INTERPOLATE_TRILINEAR)
	cellules_peintes = 0
	for cy in range(grille_taille.y):
		for cx in range(grille_taille.x):
			if _cellules_peignables[cy * grille_taille.x + cx] == 1 \
					and reduite.get_pixel(cx, cy).a >= COUVERTURE_CELLULE:
				cellules_peintes += 1
	GameState.signaler_progression(progression())
	return progression()


func progression() -> float:
	return float(cellules_peintes) / max(cellules_peignables, 1)


## Une cellule est peignable si la skyline y est opaque à plus de 15 % (moyenne).
func _calculer_cellules_peignables() -> void:
	grille_taille = Vector2i(ceili(tex_size.x / float(TAILLE_CELLULE)), ceili(tex_size.y / float(TAILLE_CELLULE)))
	var nb := grille_taille.x * grille_taille.y
	_cellules_peignables.resize(nb)

	var source: Image = sprite.texture.get_image()
	if source == null:
		_cellules_peignables.fill(1)
		cellules_peignables = nb
		return

	var reduite: Image = source.duplicate()
	reduite.resize(grille_taille.x, grille_taille.y, Image.INTERPOLATE_TRILINEAR)
	for cy in range(grille_taille.y):
		for cx in range(grille_taille.x):
			var peignable := reduite.get_pixel(cx, cy).a > 0.15
			_cellules_peignables[cy * grille_taille.x + cx] = 1 if peignable else 0
			if peignable:
				cellules_peignables += 1


## Applique un tampon de peinture de rayon `rayon`, centré sur une position globale, aux couleurs
## débloquées de `peintre`. En bataille, sur l'hôte seulement, et tant que la manche est en cours,
## le tampon est aussi reporté sur le territoire et ses vols sont signalés aux règles.
func peindre(position_globale: Vector2, rayon: int, peintre: Joueur) -> void:
	var couleurs := peintre.couleurs_debloquees
	if couleurs.is_empty() or rayon <= 0:
		return
	var local := sprite.to_local(position_globale)
	var px := int(local.x + tex_size.x / 2.0)
	var py := int(local.y + tex_size.y / 2.0)
	if px < -rayon or py < -rayon or px >= tex_size.x + rayon or py >= tex_size.y + rayon:
		return

	var tampons := _tampons_pour(rayon, couleurs)
	var tampon: Image = tampons[randi() % tampons.size()]
	var taille := tampon.get_width()
	image.blit_rect_mask(tampon, tampon, Rect2i(0, 0, taille, taille), Vector2i(px - rayon, py - rayon))
	if coulures.size() < COULURES_MAX and randf() < CHANCE_COULURE:
		var c := couleurs[randi() % couleurs.size()]
		c.a = 1.0
		coulures.append({
			"x": px + randi_range(-rayon, rayon), "y": float(py + randi_range(0, rayon)),
			"fin": float(py + rayon + randi_range(14, 44)), "couleur": c,
		})
	_dirty = true
	# Ruling (b) phase 9 bis : après terminer_partie, partie_en_cours retombe mais pret reste vrai
	# (un lion peut encore peindre) ; ne toucher au territoire que tant que la manche est en cours,
	# pour que la fin de manche fige les scores sans empêcher le tampon visuel.
	if territoire != null and multiplayer.is_server() and GameState.regles._manche_en_cours():
		var volees := territoire.tamponner(peintre.index, Vector2i(px, py), rayon)
		if volees > 0:
			GameState.regles.vol_de_cellules(peintre, volees)


## Les coulures descendent d'un trait de 2 px, une ligne à la fois.
func _avancer_coulures(delta: float) -> void:
	if coulures.is_empty():
		return
	var restantes: Array[Dictionary] = []
	for c in coulures:
		var y_avant := int(c.y)
		c.y = min(c.y + VITESSE_COULURE * delta, c.fin)
		for y in range(y_avant, int(c.y) + 1):
			if y < 0 or y >= tex_size.y:
				continue
			for x in [c.x, c.x + 1]:
				if x >= 0 and x < tex_size.x:
					image.set_pixel(x, y, c.couleur)
		if c.y < c.fin:
			restantes.append(c)
	coulures = restantes
	_dirty = true


## Les NB_TAMPONS tampons de ce rayon et de ce jeu de couleurs : générés au premier usage, puis
## gardés en cache (TAMPONS_EN_CACHE_MAX jeux au plus).
func _tampons_pour(rayon: int, couleurs: Array[Color]) -> Array:
	var cle := _cle_tampons(rayon, couleurs)
	if not _tampons.has(cle):
		if _tampons.size() >= TAMPONS_EN_CACHE_MAX:
			_tampons.clear()
		_tampons[cle] = _generer_tampons(rayon, couleurs)
	return _tampons[cle]


## Le rayon puis chaque couleur en RGBA 8 bits, dans l'ordre : deux jeux qui ne diffèrent que par
## une couleur ont des clés différentes.
static func _cle_tampons(rayon: int, couleurs: Array[Color]) -> String:
	var cle := str(rayon)
	for c in couleurs:
		cle += ":%08x" % c.to_rgba32()
	return cle


## Tampons denses au centre, épars sur les bords, dont chaque pixel prend une des couleurs.
func _generer_tampons(rayon: int, couleurs: Array[Color]) -> Array[Image]:
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
				if randf() < DENSITE_TAMPON * (1.3 - d):
					var c := couleurs[randi() % couleurs.size()]
					c.a = 1.0
					tampon.set_pixel(x, y, c)
		tampons.append(tampon)
	return tampons
