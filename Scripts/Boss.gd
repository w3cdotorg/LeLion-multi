extends Ennemi
## Le peintre géant : s'annonce au bord de l'écran, avance jusqu'au centre, marque une
## pause, repart du même côté, puis revient de l'autre. Sa collision épouse la silhouette.

enum Etat { REPOS, ANNONCE, ENTREE, PAUSE, SORTIE }

signal etat_change(etat: Etat)

@export var hauteur_ratio := 0.65        # part de la hauteur de l'écran du solo, dans les deux modes
@export var duree_annonce := 1.0
@export var duree_entree := 3.0
@export var duree_pause := 1.0
@export var duree_sortie := 3.0
@export var duree_repos := 2.0
@export var acceleration_max := 0.65     # facteur de durée quand la ville est presque peinte
@export var depassement_annonce := 40.0  # pixels visibles pendant l'annonce

@onready var sprite: Sprite2D = $Sprite2D

var etat := Etat.REPOS
var cote := 1                            # 1 = entre par la gauche, -1 = par la droite
var y_sol := 468.0                       # y du haut de la skyline (bas du boss)
var _tween: Tween
var _demi_largeur := 0.0
var _demi_hauteur := 0.0
var _temps_annonce := 0.0
var _polygones_base: Array[PackedVector2Array] = []  # silhouette tournée vers la droite


func _ready() -> void:
	# Le peintre garde sa taille du solo sur l'écran 16:9 de la bataille, comme les lions et les
	# skylines : 65 % des 1125 px le feraient dominer tout le ciel.
	var hauteur_cible := Regles.TAILLE_ECRAN_SOLO.y * hauteur_ratio
	var echelle := hauteur_cible / sprite.texture.get_height()
	sprite.scale = Vector2(echelle, echelle)
	_demi_largeur = sprite.texture.get_width() * echelle / 2.0
	_demi_hauteur = hauteur_cible / 2.0
	_generer_collision(echelle)

	cote = 1 if randf() < 0.5 else -1
	_appliquer_cote()
	position = Vector2(_x_hors_ecran(), y_sol - _demi_hauteur)
	GameState.partie_terminee.connect(func(_v: bool) -> void: _arreter())
	if not GameState.pret:
		await GameState.partie_prete
	_changer_etat(Etat.REPOS)


func _physics_process(delta: float) -> void:
	if etat == Etat.ANNONCE:
		_temps_annonce += delta
		position.y = y_sol - _demi_hauteur + sin(_temps_annonce * 40.0) * 3.0
	if etat != Etat.REPOS:
		_signaler_les_lions_au_contact()


## Le coup du peintre part de sa verticale, à la hauteur du lion (et non de son centre, bien plus
## haut ou plus bas que le lion) : le lion est repoussé sur le côté.
func origine_du_coup(lion: Lion) -> Vector2:
	return Vector2(global_position.x, lion.global_position.y)


## Facteur appliqué aux durées : 1 au début, `acceleration_max` en fin de partie. L'avancement
## vient des règles : la ville peinte en solo, le temps de la manche en bataille.
func facteur_vitesse() -> float:
	var avancement: float = clamp(GameState.regles.avancement(), 0.0, 1.0)
	return lerp(1.0, acceleration_max, avancement)


func _x_hors_ecran() -> float:
	var largeur := get_viewport_rect().size.x
	return -_demi_largeur - 10.0 if cote > 0 else largeur + _demi_largeur + 10.0


func _x_annonce() -> float:
	var largeur := get_viewport_rect().size.x
	return -_demi_largeur + depassement_annonce if cote > 0 else largeur + _demi_largeur - depassement_annonce


func _changer_etat(nouvel_etat: Etat) -> void:
	etat = nouvel_etat
	etat_change.emit(etat)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	match etat:
		Etat.REPOS:
			position.x = _x_hors_ecran()
			_tween.tween_interval(duree_repos * facteur_vitesse())
			_tween.tween_callback(_changer_etat.bind(Etat.ANNONCE))
		Etat.ANNONCE:
			position.x = _x_annonce()
			_temps_annonce = 0.0
			Audio.jouer("boss")
			_tween.tween_interval(duree_annonce)
			_tween.tween_callback(_changer_etat.bind(Etat.ENTREE))
		Etat.ENTREE:
			position.y = y_sol - _demi_hauteur
			var centre := get_viewport_rect().size.x / 2.0
			_tween.tween_property(self, "position:x", centre, duree_entree * facteur_vitesse()) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_tween.tween_callback(_changer_etat.bind(Etat.PAUSE))
		Etat.PAUSE:
			_tween.tween_interval(duree_pause)
			_tween.tween_callback(_changer_etat.bind(Etat.SORTIE))
		Etat.SORTIE:
			_tween.tween_property(self, "position:x", _x_hors_ecran(), duree_sortie * facteur_vitesse()) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			_tween.tween_callback(_changer_cote_et_reposer)


func _changer_cote_et_reposer() -> void:
	cote = -cote
	_appliquer_cote()
	_changer_etat(Etat.REPOS)


## Le boss regarde toujours vers le centre : venu de la droite, il est en miroir
## (pinceau à gauche), et sa collision aussi.
func _appliquer_cote() -> void:
	sprite.scale.x = abs(sprite.scale.x) * cote
	var index := 0
	for enfant in get_children():
		if enfant is CollisionPolygon2D and index < _polygones_base.size():
			var points := PackedVector2Array()
			for p in _polygones_base[index]:
				points.append(Vector2(p.x * cote, p.y))
			enfant.polygon = points
			index += 1


func _arreter() -> void:
	if _tween != null:
		_tween.kill()


## Construit des CollisionPolygon2D à partir des zones opaques du sprite.
func _generer_collision(echelle: float) -> void:
	var image: Image = sprite.texture.get_image()
	if image == null:
		var forme := CollisionShape2D.new()
		forme.shape = RectangleShape2D.new()
		forme.shape.size = Vector2(_demi_largeur, _demi_hauteur) * 2.0
		add_child(forme)
		return
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, 0.5)
	var decalage := Vector2(image.get_width(), image.get_height()) / 2.0
	for polygone in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 6.0):
		if polygone.size() < 3:
			continue
		var collision := CollisionPolygon2D.new()
		var points := PackedVector2Array()
		for p in polygone:
			points.append((p - decalage) * echelle)
		_polygones_base.append(points)
		collision.polygon = points
		add_child(collision)
