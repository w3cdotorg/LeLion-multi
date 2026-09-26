extends Node2D
## La ville : masque de peinture RGBA appliqué par shader sur la skyline.
## La peinture se fait par tampons multicolores (blit natif), aux couleurs du joueur qui peint.
## La progression est mesurée sur une grille de cellules couvrant les zones opaques de la
## skyline : une cellule compte quand au moins COUVERTURE_CELLULE de sa surface est réellement
## peinte (mesure par réduction du masque, à intervalle régulier). En bataille, la même grille
## porte aussi le territoire (`Territoire`) : l'hôte y reporte chaque tampon, sur toutes les
## cellules qu'il recouvre (`EMPREINTE_TERRITOIRE`).
## En réseau (phase 14), seule la traceuse de l'hôte peint : chaque tampon qu'il applique part en
## événement (`tampon_peint`), que la manche diffuse ; un client dessine les tampons reçus
## (`peindre_tampon_recu`), identiques à ceux de l'hôte (`Peinture` : jeux de tampons tirés de leur
## clé, variante et coulure tirées de la graine du tampon), et son territoire suit celui de l'hôte
## par les cellules changées reçues (`Territoire.appliquer_changements`).

## Sur l'hôte : un tampon vient d'être appliqué. `tampon` : `{"index": int, "x": int, "y": int,
## "rayon": int, "graine": int}` (index du peintre, centre en pixels de la ville), le format que
## `Peinture.encoder_tampons` diffuse.
signal tampon_peint(tampon: Dictionary)

const TAILLE_CELLULE := 8
const NB_TAMPONS := Peinture.NB_TAMPONS
const CHANCE_COULURE := Peinture.CHANCE_COULURE
## Coulures lancées au plus parmi les FENETRE_COULURES derniers tampons de la ville : un plafond
## compté en tampons, pas en coulures encore en cours. Chaque poste peint les mêmes tampons dans le
## même ordre (ceux que diffuse l'hôte) : il lance donc les mêmes coulures, quel que soit son rythme
## d'affichage (qui, lui, fait avancer les coulures).
const COULURES_MAX := 40
const FENETRE_COULURES := 120
const VITESSE_COULURE := 70.0  # px/s
const INTERVALLE_MESURE := 0.2  # s
const COUVERTURE_CELLULE := 0.4
## Marge ajoutée au rayon d'un tampon pour le territoire : `Territoire.tamponner` touche les
## cellules dont le centre est à moins du rayon reçu ; avec une demi-cellule de plus, il touche
## à peu près toutes celles que le tampon recouvre (les cellules en diagonale, dont le centre est
## entre r+4 et r+4√2, restent hors d'atteinte), comme la couverture du solo les compte à
## peu près (une cellule comptée à 40 % d'alpha, pas « recouverte »). Mesuré sur une
## passe pleine vitesse (`tests/bataille_test.gd`, phase 10 ter) : sans cette marge, le territoire
## comptait 0,44 à 0,92 fois les cellules de la couverture et une passe ne volait que 8 % des
## cellules d'un adversaire au premier cran ; avec elle, 0,82 à 1,21 fois et 49 % au moins.
const EMPREINTE_TERRITOIRE := TAILLE_CELLULE / 2
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
## Tampons peints depuis la dernière skyline, et le numéro du tampon de chaque coulure récente (voir
## FENETRE_COULURES).
var _nb_tampons := 0
var _tampons_des_coulures: Array[int] = []
## Tampons par rayon et jeu de couleurs (clé : `Peinture.cle_tampons`) : deux lions qui ont autant de
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
	_nb_tampons = 0
	_tampons_des_coulures.clear()
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
## débloquées de `peintre`. Sa graine (variante et coulure, voir `Peinture.tirage`) est tirée ici
## (`randi`). Sur l'hôte, le tampon part aussi en événement (`tampon_peint`) et, en bataille, tant
## que la manche est en cours, il est reporté sur le territoire et ses vols sont signalés aux règles.
func peindre(position_globale: Vector2, rayon: int, peintre: Joueur) -> void:
	var local := sprite.to_local(position_globale)
	_peindre_en(Vector2i(int(local.x + tex_size.x / 2.0), int(local.y + tex_size.y / 2.0)), rayon, peintre,
		randi() & Peinture.GRAINE_MAX)


## Chez un client : un tampon diffusé par l'hôte (voir `tampon_peint`), dessiné à l'identique ; un
## index de joueur inconnu de ce poste est ignoré.
func peindre_tampon_recu(tampon: Dictionary) -> void:
	if tampon.index < 0 or tampon.index >= GameState.joueurs.size():
		return
	_peindre_en(Vector2i(tampon.x, tampon.y), tampon.rayon, GameState.joueurs[tampon.index], tampon.graine)


## Le tampon de rayon `rayon` et de graine `graine`, centré en `centre` (pixels de la ville,
## éventuellement hors de l'image : un tampon qui déborde est dessiné en partie).
func _peindre_en(centre: Vector2i, rayon: int, peintre: Joueur, graine: int) -> void:
	var couleurs := peintre.couleurs_debloquees
	if couleurs.is_empty() or rayon <= 0:
		return
	var px := centre.x
	var py := centre.y
	if px < -rayon or py < -rayon or px >= tex_size.x + rayon or py >= tex_size.y + rayon:
		return

	var tire := Peinture.tirage(graine, rayon, couleurs.size())
	var tampon: Image = _tampons_pour(rayon, couleurs)[tire.variante]
	var taille := tampon.get_width()
	image.blit_rect_mask(tampon, tampon, Rect2i(0, 0, taille, taille), Vector2i(px - rayon, py - rayon))
	_nb_tampons += 1
	while not _tampons_des_coulures.is_empty() and _tampons_des_coulures[0] <= _nb_tampons - FENETRE_COULURES:
		_tampons_des_coulures.pop_front()
	if tire.coulure and _tampons_des_coulures.size() < COULURES_MAX:
		_tampons_des_coulures.append(_nb_tampons)
		var c := couleurs[tire.couleur]
		c.a = 1.0
		coulures.append({
			"x": px + tire.dx, "y": float(py + tire.dy), "fin": float(py + rayon + tire.longueur), "couleur": c,
		})
	_dirty = true
	if not multiplayer.is_server():
		return
	tampon_peint.emit({"index": peintre.index, "x": px, "y": py, "rayon": rayon, "graine": graine})
	# Le territoire ne bouge que pendant la manche : après terminer_partie, pret reste vrai et un
	# lion peut encore peindre ; le tampon se dessine, le score reste figé.
	if territoire != null and GameState.regles.manche_en_cours():
		var volees := territoire.tamponner(peintre.index, Vector2i(px, py), rayon + EMPREINTE_TERRITOIRE)
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


## Les NB_TAMPONS tampons de ce rayon et de ce jeu de couleurs (`Peinture.generer_tampons`, les
## mêmes sur chaque poste) : générés au premier usage, puis gardés en cache (TAMPONS_EN_CACHE_MAX
## jeux au plus).
func _tampons_pour(rayon: int, couleurs: Array[Color]) -> Array:
	var cle := Peinture.cle_tampons(rayon, couleurs)
	if not _tampons.has(cle):
		if _tampons.size() >= TAMPONS_EN_CACHE_MAX:
			_tampons.clear()
		_tampons[cle] = Peinture.generer_tampons(rayon, couleurs)
	return _tampons[cle]
