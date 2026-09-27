class_name GerbeLion
extends Node2D
## La gerbe d'un lion : un émetteur de particules par couleur débloquée (en bataille, les trois
## nuances du joueur), en éventail, partant de la bouche à 45° vers le bas ; la traceuse de peinture
## au point de chute, son rayon selon les crans (16 px au premier, 5 px de plus par cran, 46 px au
## plus) et la gerbe XXL ; les zones de contact le long de la parabole, avec la même physique que les
## particules, qui signalent aux règles de l'hôte les autres lions que la gerbe touche.
## Nœud posé à l'origine du lion : ses zones de contact (ses enfants, créées par le code) sont dans le
## repère du lion, comme la bouche et la traceuse (des nœuds du lion, que la scène lui donne) : elles
## décident, jamais l'affichage. Les émetteurs (`vomi_container`), purement visuels, vivent sous
## `Visuel` (M4, revue finale phase 16) : pendant une correction d'affichage (`PredictionLocale`), ils
## suivent le même décalage que le sprite, sans quoi le jet partirait à côté de la bouche affichée. Le
## lion la prépare (`preparer`), la réoriente (`orienter`), la reconstruit quand son joueur débloque
## une couleur (`reconstruire`), la fait partir et l'arrête (`demarrer`, `arreter`).

const ANGLE_GERBE_DEG := 45.0
const ECART_EVENTAIL_DEG := 24.0
const VITESSE_GERBE := 320.0
const GRAVITE_GERBE := 300.0
const DUREE_GERBE := 0.6
const PARTICULES_PAR_COULEUR := 400
const RAYON_TRACEUSE := Vector2i(16, 46)  # min, max
const FACTEUR_BONUS := 2.0
const TEXTURE_PARTICULE := preload("res://Assets/Sprites/circle_white.png")
const BOUCHE_X_DROITE := 89.0
const BOUCHE_X_GAUCHE := 47.0
const PAS_RAYON_PAR_CRAN := 5
const NB_ZONES_CONTACT := 3
const RAYON_ZONE_CONTACT := 22.0
const COUCHE_CORPS_LIONS := 1  # couche du corps des lions, celle que détectent ennemis et pastilles

## Les nœuds du lion que la gerbe place et anime (donnés par `Scenes/Lion.tscn`).
@export var vomi_container: Node2D
@export var traceuse: Area2D
@export var traceuse_shape: CollisionShape2D
@export var bouche: Marker2D

## Zones de contact de la gerbe, de la bouche au point de chute (la dernière y rejoint la traceuse).
var zones_contact: Array[Area2D] = []

@onready var _lion: Lion = get_parent()


## Appelé une fois par le lion, dans son `_ready` : la forme de la traceuse de Lion.tscn est partagée
## par toutes les instances, chaque lion a besoin de son propre rayon ; puis les zones de contact.
func preparer() -> void:
	traceuse_shape.shape = traceuse_shape.shape.duplicate()
	_creer_zones_contact()


## Déplace la bouche du côté où regarde le lion, puis réoriente émetteurs, traceuse et zones.
func orienter() -> void:
	bouche.position.x = BOUCHE_X_DROITE if _lion.direction_du_lion > 0 else BOUCHE_X_GAUCHE
	vomi_container.position = bouche.position
	_orienter_emetteurs()
	placer_traceuse()


## Reconstruit un émetteur par couleur débloquée (en bataille, les trois nuances du joueur,
## débloquées dès le départ : voir `Regles.couleurs_de_depart`).
func reconstruire() -> void:
	for child in vomi_container.get_children():
		vomi_container.remove_child(child)
		child.queue_free()

	for couleur in _lion.joueur.couleurs_debloquees:
		var gradient := Gradient.new()
		gradient.set_color(0, couleur)
		gradient.set_color(1, Color(couleur, 0.0))
		gradient.add_point(0.75, couleur)
		var gradient_texture := GradientTexture1D.new()
		gradient_texture.gradient = gradient

		var material := ParticleProcessMaterial.new()
		material.color_ramp = gradient_texture
		material.spread = 6.0
		material.initial_velocity_min = VITESSE_GERBE * 0.9
		material.initial_velocity_max = VITESSE_GERBE * 1.1
		material.gravity = Vector3(0, GRAVITE_GERBE, 0)
		material.scale_min = 0.6 * _facteur_bonus()
		material.scale_max = 1.4 * _facteur_bonus()

		var emitter := GPUParticles2D.new()
		emitter.texture = TEXTURE_PARTICULE
		emitter.process_material = material
		emitter.amount = PARTICULES_PAR_COULEUR
		emitter.lifetime = DUREE_GERBE
		emitter.emitting = _lion.est_en_train_de_vomir
		vomi_container.add_child(emitter)

	_orienter_emetteurs()
	placer_traceuse()


## Traceuse au point de chute ; rayon de peinture selon les crans et le bonus. Zones de contact
## réparties sur la parabole.
func placer_traceuse() -> void:
	traceuse.position = _point_de_gerbe(DUREE_GERBE)
	if traceuse_shape.shape is CircleShape2D:
		var rayon: float = clamp(RAYON_TRACEUSE.x + (_lion.joueur.crans - 1) * PAS_RAYON_PAR_CRAN, RAYON_TRACEUSE.x, RAYON_TRACEUSE.y)
		traceuse_shape.shape.radius = rayon * _facteur_bonus()
	for i in range(zones_contact.size()):
		zones_contact[i].position = _point_de_gerbe(DUREE_GERBE * (i + 1) / zones_contact.size())
		(zones_contact[i].get_child(0).shape as CircleShape2D).radius = RAYON_ZONE_CONTACT * _facteur_bonus()


## Gerbe XXL (ou sa fin) : particules plus grosses ou normales.
func appliquer_taille_particules() -> void:
	for emitter in vomi_container.get_children():
		var mat := emitter.process_material as ParticleProcessMaterial
		if mat != null:
			mat.scale_min = 0.6 * _facteur_bonus()
			mat.scale_max = 1.4 * _facteur_bonus()


## La gerbe part : la traceuse et les zones de contact surveillent, les émetteurs émettent.
func demarrer() -> void:
	traceuse.monitoring = true
	for zone in zones_contact:
		zone.monitoring = true
	for emitter in vomi_container.get_children():
		emitter.emitting = true


func arreter() -> void:
	traceuse.monitoring = false
	for zone in zones_contact:
		zone.monitoring = false
	for emitter in vomi_container.get_children():
		emitter.emitting = false


## Sur l'hôte : chaque autre lion que touche la gerbe est signalé aux règles, à chaque frame
## de contact (les règles ignorent un lion déjà étourdi ou immunisé).
func signaler_vomi_sur_les_lions() -> void:
	if not _lion.est_en_train_de_vomir or not multiplayer.is_server():
		return
	for zone in zones_contact:
		for corps in zone.get_overlapping_bodies():
			var victime := corps as Lion
			if victime != null and victime != _lion:
				GameState.regles.lion_touche_par_vomi(victime.joueur, _lion.joueur, zone.global_position)


func _facteur_bonus() -> float:
	return FACTEUR_BONUS if _lion.joueur.bonus_actif() else 1.0


func _angle_gerbe(index: int, count: int) -> float:
	var base := ANGLE_GERBE_DEG if _lion.direction_du_lion > 0 else 180.0 - ANGLE_GERBE_DEG
	var offset: float = lerp(-ECART_EVENTAIL_DEG / 2, ECART_EVENTAIL_DEG / 2, float(index) / max(count - 1, 1))
	return deg_to_rad(base + offset * _lion.direction_du_lion)


## Position, dans le repère du lion, d'une particule tirée à 45° après `t` secondes de vol
## (même physique que le ParticleProcessMaterial). `t = DUREE_GERBE` : le point de chute.
func _point_de_gerbe(t: float) -> Vector2:
	var v := Vector2.from_angle(deg_to_rad(ANGLE_GERBE_DEG)) * VITESSE_GERBE
	var point := Vector2(v.x * t, v.y * t + 0.5 * GRAVITE_GERBE * t * t)
	point.x *= _lion.direction_du_lion
	return bouche.position + point


## Zones qui détectent le corps des autres lions sur la trajectoire de la gerbe, pendant le
## vomi. Créées par le code : chaque lion a ses propres formes (leur rayon suit son bonus).
func _creer_zones_contact() -> void:
	for i in range(NB_ZONES_CONTACT):
		var zone := Area2D.new()
		zone.name = "ZoneContact%d" % (i + 1)
		zone.collision_layer = 0  # rien ne la détecte (ennemis, pastilles, ville)
		zone.collision_mask = COUCHE_CORPS_LIONS
		zone.monitorable = false
		zone.monitoring = false
		var forme := CollisionShape2D.new()
		forme.shape = CircleShape2D.new()
		zone.add_child(forme)
		add_child(zone)
		zones_contact.append(zone)


func _orienter_emetteurs() -> void:
	var emitters := vomi_container.get_children()
	for index in range(emitters.size()):
		var mat := emitters[index].process_material as ParticleProcessMaterial
		if mat != null:
			var angle := _angle_gerbe(index, emitters.size())
			mat.direction = Vector3(cos(angle), sin(angle), 0)
