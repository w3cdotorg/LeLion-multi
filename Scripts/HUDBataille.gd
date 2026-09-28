extends CanvasLayer
## Le HUD de la bataille (spec §8, phase 17), à la place de celui du solo : en haut de l'écran, une
## vignette par joueur, dans l'ordre des index (moitié à gauche du chrono, moitié à droite) : le lion
## teint de sa couleur (la couronne des meneurs posée de travers sur sa crinière, ex æquo compris), son
## pseudo, sa part des cellules peintes (les parts font 100 % à elles toutes), son rang, ses crans en
## points, la gerbe XXL et ses secondes, l'étourdissement ; la vignette de ce
## poste mise en évidence (« TOI », bordure épaisse), celle d'un joueur parti en grisé. Au centre, le
## chrono qui descend, rouge et qui tique dans les dix dernières secondes. La propriété d'une cellule
## ne se lit qu'ici, au pseudo et à la part (jamais à la teinte de la ville : deutéranopie, spec §2).
## Tout se lit sur chaque poste : les scores sur le territoire de la ville (celui de l'hôte, recopié
## chez chaque client toutes les 0,2 s), le chrono sur `GameState.temps_ecoule` (chez un client, parti
## à la fin de sa propre intro), les réactions par les signaux des joueurs (répliqués par la manche) ;
## les secondes de la gerbe XXL se décomptent ici (sur un client, `Joueur.bonus_restant` reste la
## durée reçue au début de la gerbe). À la fin de la manche (`GameState.partie_terminee`, chez un
## client la fin décidée par l'hôte), il se rafraîchit une dernière fois ; l'écran Résultats (phase 18,
## `Resultats`) prend alors sa place. Ne bouge pas pendant une pause.

const TEXTURE_LION := preload("res://Assets/Sprites/LionHead.png")
const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
## La couronne sur la tête du lion de la vignette (56 px) : sa place, sa taille et son inclinaison (de
## travers, comme posée sur la crinière), en radians.
const PLACE_COURONNE := Vector2(26, 1)
const TAILLE_COURONNE := Vector2(30, 20)
const INCLINAISON_COURONNE := 0.38
## Une vignette : six tiennent avec le chrono dans les 2000 px ; un pseudo de 12 caractères larges
## (« WWWWWWWWWWWW ») y tient à POLICE_PSEUDO px (vérifié par tests/bataille_test.gd).
const TAILLE_VIGNETTE := Vector2(270, 112)
const POLICE_PSEUDO := 20
const COULEUR_CONTOUR := Color(0.1, 0.05, 0.15, 1)
const COULEUR_CHRONO := Color.WHITE
const COULEUR_CHRONO_FIN := Color(1.0, 0.32, 0.25)
const COULEUR_POINT_VIDE := Color(1, 1, 1, 0.22)
const COULEUR_ETOURDI := Color(0.75, 0.85, 1.0)
const OPACITE_PARTI := 0.4

## La ville de la scène de jeu (son territoire tient les scores), donnée par `Main` avant l'ajout.
var ville: Node2D
## Une vignette par joueur, dans l'ordre des index : {"cadre": PanelContainer, "style": StyleBoxFlat,
## "lion": TextureRect, "teinte": ShaderMaterial, "pseudo": Label, "badge": Label, "couronne": Control (sur le lion), "part": Label,
## "rang": Label, "etat": Label, "points": Array[Panel]}.
var vignettes: Array[Dictionary] = []
## Par index de joueur : les secondes de gerbe XXL qui restent, décomptées ici (0 : pas de gerbe).
var xxl_restant: Array[float] = []
## Par index de joueur : vrai une fois parti (`marquer_parti`).
var partis: Array[bool] = []
## Tics joués (dix dernières secondes), lus par les tests.
var tics_joues := 0

@onready var gauche: HBoxContainer = $Haut/Gauche
@onready var droite: HBoxContainer = $Haut/Droite
@onready var chrono: Label = $Haut/Chrono

var _secondes_vues := -1
## Le style des points de crans, partagé (un point vide n'est qu'estompé : `modulate`, sans changer
## de thème à chaque image).
var _style_point := StyleBoxFlat.new()


func _ready() -> void:
	_style_point.bg_color = Color.WHITE
	_style_point.set_corner_radius_all(6)
	var nb := GameState.joueurs.size()
	for i in range(nb):
		var joueur: Joueur = GameState.joueurs[i]
		var vignette := _creer_vignette(joueur)
		(gauche if i < ceili(nb / 2.0) else droite).add_child(vignette.cadre)
		vignettes.append(vignette)
		xxl_restant.append(0.0)
		partis.append(false)
		joueur.bonus_change.connect(_sur_bonus.bind(i))
		joueur.bonus_dure.connect(_sur_bonus_dure.bind(i))
	GameState.partie_terminee.connect(_sur_fin)
	_secondes_vues = _secondes()
	rafraichir()


func _process(delta: float) -> void:
	if GameState.partie_en_cours and GameState.pret:
		for i in range(xxl_restant.size()):
			xxl_restant[i] = maxf(xxl_restant[i] - delta, 0.0)
	var secondes := _secondes()
	if secondes < _secondes_vues and secondes >= 1 and secondes <= ReglesBataille.SECONDES_TIC:
		tics_joues += 1
		Audio.jouer("tic")
		chrono.pivot_offset = chrono.size / 2.0
		chrono.scale = Vector2(1.25, 1.25)
		create_tween().tween_property(chrono, "scale", Vector2.ONE, 0.3)
	_secondes_vues = secondes
	rafraichir()


## Le joueur d'index `index` a quitté la manche : sa vignette reste, en grisé, avec ses cellules.
func marquer_parti(index: int) -> void:
	if index < 0 or index >= partis.size():
		return
	partis[index] = true
	rafraichir()


## Met chaque vignette et le chrono à jour : parts et rangs lus sur le territoire (les rangs sur les
## cellules, pas sur les parts arrondies), réactions sur les joueurs.
func rafraichir() -> void:
	var cellules := _cellules()
	var rangs := ReglesBataille.rangs(cellules)
	var parts := ReglesBataille.parts(cellules)
	for i in range(vignettes.size()):
		var joueur: Joueur = GameState.joueurs[i]
		var v: Dictionary = vignettes[i]
		v.part.text = "%d %%" % parts[i]
		v.rang.text = tr("BATAILLE_RANG_%d" % rangs[i]) if rangs[i] > 0 else ""
		v.rang.modulate = Styles.JAUNE if rangs[i] == 1 else Color.WHITE
		v.couronne.visible = rangs[i] == 1
		for k in range(v.points.size()):
			(v.points[k] as Panel).modulate = Color.WHITE if k < joueur.crans else COULEUR_POINT_VIDE
		if joueur.est_etourdi():
			v.etat.text = tr("BATAILLE_ETOURDI")
			v.etat.modulate = COULEUR_ETOURDI
		elif xxl_restant[i] > 0.0:
			v.etat.text = tr("BATAILLE_XXL") % ceili(xxl_restant[i])
			v.etat.modulate = Styles.JAUNE
		else:
			v.etat.text = ""
		var badges := PackedStringArray()
		if joueur == GameState.joueur_local():
			badges.append(tr("SALON_TOI"))
		if partis[i]:
			badges.append(tr("BATAILLE_PARTI"))
		v.badge.text = " · ".join(badges)
		v.cadre.modulate.a = OPACITE_PARTI if partis[i] else 1.0
	var secondes := _secondes()
	chrono.text = EtatPartie.formater_temps(secondes)
	chrono.modulate = COULEUR_CHRONO_FIN if secondes <= ReglesBataille.SECONDES_TIC else COULEUR_CHRONO


## Le HUD tel qu'il s'affiche, en une ligne (tests réseau : le même chez l'hôte et chaque client à la
## fin de la manche) : le chrono, puis pour chaque joueur son pseudo, sa part, son rang et s'il est parti.
func resume() -> String:
	var morceaux := PackedStringArray([chrono.text])
	for i in range(vignettes.size()):
		var v: Dictionary = vignettes[i]
		morceaux.append("%s:%s:%s%s" % [v.pseudo.text, v.part.text, v.rang.text, ":parti" if partis[i] else ""])
	return "|".join(morceaux)


## Le nom d'un joueur tel que le HUD l'affiche : son pseudo, ou « Joueur n » sans pseudo (bataille
## locale).
static func nom_affiche(joueur: Joueur) -> String:
	return joueur.pseudo if not joueur.pseudo.is_empty() else TranslationServer.translate("BATAILLE_JOUEUR") % (joueur.index + 1)


## Les cellules de chaque joueur, lues sur le territoire de la ville (aucune sans territoire).
func _cellules() -> Array[int]:
	var cellules: Array[int] = []
	for i in range(vignettes.size()):
		cellules.append(0 if ville == null or ville.territoire == null else ville.territoire.cellules_de(i))
	return cellules


func _secondes() -> int:
	return (GameState.regles as ReglesBataille).secondes_restantes()


func _sur_bonus(actif: bool, index: int) -> void:
	if not actif:
		xxl_restant[index] = 0.0


## M2 (revue finale phase 17) : `bonus_dure` part à chaque activation de la gerbe XXL (première
## activation et prolongation confondues) : le décompte se recale même quand une deuxième étoile
## prolonge une gerbe déjà en cours (`bonus_change`, lui, ne l'est qu'à la première activation).
func _sur_bonus_dure(duree: float, index: int) -> void:
	xxl_restant[index] = duree


## Fin de la manche : les scores définitifs (le dernier territoire de l'hôte est déjà appliqué chez un
## client : il arrive avant la fin, sur le même canal) ; l'écran Résultats prend ensuite la place du HUD.
func _sur_fin(_victoire: bool) -> void:
	rafraichir()


func _creer_vignette(joueur: Joueur) -> Dictionary:
	var local := joueur == GameState.joueur_local()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.62 if local else 0.45)
	style.border_color = joueur.couleur
	style.set_border_width_all(6 if local else 3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(11)  # au moins 5 px entre le texte et la bordure épaisse de ce poste
	var cadre := PanelContainer.new()
	cadre.custom_minimum_size = TAILLE_VIGNETTE
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_theme_stylebox_override("panel", style)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 0)
	cadre.add_child(colonne)
	# En haut, sur toute la largeur : le pseudo, dans sa couleur
	var pseudo := _etiquette(POLICE_PSEUDO, joueur.couleur, true)
	pseudo.text = nom_affiche(joueur)
	pseudo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	colonne.add_child(pseudo)
	# Dessous : le lion teint de la couleur du joueur (et la couronne sur sa tête), puis sa part, son
	# état ; son rang, ses crans et le badge
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 8)
	colonne.add_child(rangee)
	var lion := TextureRect.new()
	lion.texture = TEXTURE_LION
	lion.custom_minimum_size = Vector2(56, 56)
	lion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var teinte := ShaderMaterial.new()  # une par vignette : jamais partagée
	teinte.shader = SHADER_TEINTE
	teinte.set_shader_parameter("couleur_joueur", joueur.couleur)
	lion.material = teinte
	rangee.add_child(lion)
	var couronne := Couronne.new()
	couronne.position = PLACE_COURONNE
	couronne.size = TAILLE_COURONNE
	couronne.pivot_offset = TAILLE_COURONNE / 2.0
	couronne.rotation = INCLINAISON_COURONNE
	couronne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lion.add_child(couronne)  # un TextureRect ne range pas ses enfants : la couronne reste où on la pose
	var droite_v := VBoxContainer.new()
	droite_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite_v.add_theme_constant_override("separation", 0)
	rangee.add_child(droite_v)
	var ligne_part := HBoxContainer.new()
	ligne_part.add_theme_constant_override("separation", 8)
	var part := _etiquette(34, Color.WHITE)
	var etat := _etiquette(18, Color.WHITE)  # teinte par `modulate` : jaune (XXL) ou bleutée (étourdi)
	etat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for noeud: Control in [part, etat]:
		ligne_part.add_child(noeud)
	droite_v.add_child(ligne_part)
	var ligne_rang := HBoxContainer.new()
	ligne_rang.add_theme_constant_override("separation", 8)
	var rang := _etiquette(20, Color.WHITE)  # teinte par `modulate` : jaune pour les meneurs
	rang.custom_minimum_size.x = 40
	rang.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var points_ligne := HBoxContainer.new()
	points_ligne.add_theme_constant_override("separation", 4)
	points_ligne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var points: Array[Panel] = []
	for k in range(Joueur.CRANS_MAX):
		var point := Panel.new()
		point.custom_minimum_size = Vector2(11, 11)
		point.mouse_filter = Control.MOUSE_FILTER_IGNORE
		point.add_theme_stylebox_override("panel", _style_point)
		points_ligne.add_child(point)
		points.append(point)
	var badge := _etiquette(16, Styles.JAUNE)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for noeud: Control in [rang, points_ligne, badge]:
		ligne_rang.add_child(noeud)
	droite_v.add_child(ligne_rang)
	return {"cadre": cadre, "style": style, "lion": lion, "teinte": teinte, "pseudo": pseudo, "badge": badge, "couronne": couronne,
		"part": part, "rang": rang, "etat": etat, "points": points}


## Une étiquette jamais traduite d'elle-même (les textes sont traduits ici, et un pseudo comme
## « PAUSE » n'est pas une clé). `coupee` : coupée au bord de sa vignette, points de suspension
## compris, plutôt que de l'élargir (le pseudo) ; une étiquette coupée n'a plus de largeur minimale,
## elle doit s'étendre : les autres gardent la largeur de leur texte.
func _etiquette(taille: int, couleur: Color, coupee := false) -> Label:
	var etiquette := Label.new()
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiquette.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	etiquette.clip_text = coupee
	if coupee:
		etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.add_theme_font_size_override("font_size", taille)
	etiquette.add_theme_color_override("font_color", couleur)
	etiquette.add_theme_color_override("font_outline_color", COULEUR_CONTOUR)
	etiquette.add_theme_constant_override("outline_size", 6)
	return etiquette


## La couronne des meneurs, dessinée (la police n'a pas de glyphe de couronne) : trois pointes et leurs
## perles, un contour sombre pour se détacher de toutes les crinières (le jaune compris).
class Couronne extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var points := PackedVector2Array([Vector2(1, h - 1), Vector2(1, h * 0.3), Vector2(w * 0.28, h * 0.62),
			Vector2(w * 0.5, 1), Vector2(w * 0.72, h * 0.62), Vector2(w - 1, h * 0.3), Vector2(w - 1, h - 1)])
		draw_colored_polygon(points, Styles.JAUNE)
		points.append(points[0])
		draw_polyline(points, Color(0.1, 0.05, 0.15), 2.0)
		for perle in [Vector2(1, h * 0.3), Vector2(w * 0.5, 1), Vector2(w - 1, h * 0.3)]:
			draw_circle(perle, 2.5, Color.WHITE)
