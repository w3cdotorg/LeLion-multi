class_name Commandes
extends RefCounted
## Intentions d'un lion : direction voulue et envie de vomir. Le lion ne lit jamais Input
## lui-même. Deux sources : les actions de ce poste (clavier, manette, tactile), ou des valeurs
## écrites par un tiers (pilote de la démo, tests, et plus tard le réseau).

enum Source { LOCALES, MANUELLES }

var source := Source.MANUELLES
## Lus seulement en source MANUELLES.
var direction_voulue := Vector2.ZERO
var vomir_voulu := false


static func locales() -> Commandes:
	var c := Commandes.new()
	c.source = Source.LOCALES
	return c


static func manuelles() -> Commandes:
	return Commandes.new()


func direction() -> Vector2:
	if source == Source.LOCALES:
		return Input.get_vector("deplacer_gauche", "deplacer_droite", "deplacer_haut", "deplacer_bas")
	return direction_voulue


func vomir() -> bool:
	if source == Source.LOCALES:
		return Input.is_action_pressed("vomir")
	return vomir_voulu
