class_name Commandes
extends RefCounted
## Intentions d'un lion : direction voulue et envie de vomir. Le lion ne lit jamais Input
## lui-même. Deux sources : les actions de ce poste (clavier, manette, tactile), ou des valeurs
## écrites par un tiers (pilote de la démo, tests, et plus tard le réseau).

enum Source { LOCALES, MANUELLES }

var source := Source.MANUELLES
## Lus seulement en source MANUELLES. direction() borne direction_voulue à une longueur de 1.
var direction_voulue := Vector2.ZERO
var vomir_voulu := false
## Vrai tant que ce poste a ouvert son menu local pendant une manche en réseau (la partie continue,
## spec §4) : les commandes valent alors le repos, quelle que soit leur source, pour qu'un joueur qui
## navigue dans le menu ne fasse ni avancer ni vomir son lion.
var suspendues := false


static func locales() -> Commandes:
	var c := Commandes.new()
	c.source = Source.LOCALES
	return c


static func manuelles() -> Commandes:
	return Commandes.new()


func direction() -> Vector2:
	if suspendues:
		return Vector2.ZERO
	if source == Source.LOCALES:
		return Input.get_vector("deplacer_gauche", "deplacer_droite", "deplacer_haut", "deplacer_bas")
	# Bornée : une valeur reçue du réseau (phases suivantes) pourrait dépasser 1 et rendre
	# un lion plus rapide que sa vitesse.
	return direction_voulue.limit_length(1.0)


func vomir() -> bool:
	if suspendues:
		return false
	if source == Source.LOCALES:
		return Input.is_action_pressed("vomir")
	return vomir_voulu
