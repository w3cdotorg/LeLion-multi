extends Node
## Pilote automatique de l'attract mode : fuit les ennemis proches, ramasse les pastilles,
## puis balaie la ville en vomissant. Écrit dans les commandes manuelles du lion.

const DISTANCE_DANGER := 280.0
const DISTANCE_PICKUP_TENTANT := 450.0
const VITESSE_BALAYAGE := 220.0
const HAUTEURS_JET := [-233.0, -200.0, -270.0]  # y du lion par rapport au haut de la skyline

@onready var lion: CharacterBody2D = get_parent().get_node("Lion")
@onready var ville: Node2D = get_parent().get_node("Ville")

var _cible_x := 300.0
var _sens := 1.0
var _rangee := 0


func _ready() -> void:
	assert(lion.commandes.source == Commandes.Source.MANUELLES, "le pilote a besoin de commandes manuelles, sinon ses écritures sont ignorées")


func _physics_process(delta: float) -> void:
	if not GameState.pret or not GameState.partie_en_cours or not is_instance_valid(lion):
		return
	var centre: Vector2 = lion.global_position + Vector2(68, 66)

	# 1. Fuir les ennemis proches
	var fuite := Vector2.ZERO
	for ennemi in get_tree().get_nodes_in_group("ennemi"):
		var ecart: Vector2 = centre - ennemi.global_position
		if ecart.length() < DISTANCE_DANGER:
			fuite += ecart.normalized() * (DISTANCE_DANGER - ecart.length())
	if fuite != Vector2.ZERO:
		lion.commandes.direction_voulue = fuite.normalized()
		lion.commandes.vomir_voulu = false
		return

	# 2. Une pastille à portée, ou aucune couleur : on va la chercher
	var pickup := _pickup_le_plus_proche(centre)
	if pickup != null and (lion.joueur.couleurs_debloquees.is_empty()
			or pickup.global_position.distance_to(centre) < DISTANCE_PICKUP_TENTANT):
		_aller_vers(pickup.global_position - Vector2(68, 66))
		lion.commandes.vomir_voulu = false
		return

	# 3. Balayer la ville en vomissant
	_cible_x += _sens * VITESSE_BALAYAGE * delta
	if _cible_x > 1750.0 or _cible_x < 150.0:
		_sens = -_sens
		_cible_x = clampf(_cible_x, 150.0, 1750.0)
		_rangee = (_rangee + 1) % HAUTEURS_JET.size()
	var haut_ville: float = ville.position.y - ville.tex_size.y / 2.0
	_aller_vers(Vector2(_cible_x, haut_ville + HAUTEURS_JET[_rangee]))
	lion.commandes.vomir_voulu = not lion.joueur.couleurs_debloquees.is_empty()


func _aller_vers(cible: Vector2) -> void:
	var ecart: Vector2 = cible - lion.global_position
	lion.commandes.direction_voulue = ecart.normalized() if ecart.length() > 24.0 else Vector2.ZERO


func _pickup_le_plus_proche(centre: Vector2) -> Node2D:
	var meilleur: Node2D = null
	var distance := INF
	for pickup in get_tree().get_nodes_in_group("pickup"):
		var d: float = pickup.global_position.distance_to(centre)
		if d < distance:
			distance = d
			meilleur = pickup
	return meilleur
