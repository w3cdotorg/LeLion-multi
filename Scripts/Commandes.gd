class_name Commandes
extends RefCounted
## Intentions d'un lion : direction voulue et envie de vomir. Le lion ne lit jamais Input
## lui-même. Deux sources : les actions de ce poste (clavier, manette, tactile), ou des valeurs
## écrites par un tiers (pilote de la démo, tests, prédiction du lion local d'un client, et chez
## l'hôte les commandes reçues d'un client).
## Chez l'hôte (phase 16), les commandes d'un client arrivent numérotées, par paquets redondants (la
## dernière et jusqu'à REDONDANCE précédentes, `encoder_paquet`) : chaque numéro neuf entre dans une
## file (`recevoir`), dont le lion applique une commande par tick physique, dans l'ordre
## (`appliquer_suivante`) ; aucune n'est appliquée deux fois, et `numero_applique` (la dernière
## appliquée) part avec l'état du lion vers le client, qui y recale sa prédiction.

enum Source { LOCALES, MANUELLES }

## Commandes précédentes renvoyées avec chaque commande (spec §4 : la commande courante et les 3
## précédentes) : un paquet perdu en Wi-Fi ne fait pas sauter le lion.
const REDONDANCE := 3
## File d'attente maximale chez l'hôte, en commandes (ticks) : au-delà (un client qui rattrape d'un
## coup un retard de plusieurs images), les plus anciennes sont sautées, pour ne pas garder un retard
## que rien ne résorberait.
const FILE_MAX := 8
## Octets d'un paquet : numéro de la dernière commande (u32), nombre de commandes (u8), puis pour
## chacune, de la plus ancienne à la dernière, direction (deux f32) et vomir (u8).
const TAILLE_ENTETE := 5
const TAILLE_COMMANDE := 9

var source := Source.MANUELLES
## Lus seulement en source MANUELLES. direction() borne direction_voulue à une longueur de 1.
var direction_voulue := Vector2.ZERO
var vomir_voulu := false
## Vrai tant que ce poste a ouvert son menu local pendant une manche en réseau (la partie continue,
## spec §4) : les commandes valent alors le repos, quelle que soit leur source, pour qu'un joueur qui
## navigue dans le menu ne fasse ni avancer ni vomir son lion.
var suspendues := false
## Chez l'hôte : le numéro de la dernière commande appliquée (0 : aucune), le plus grand numéro reçu,
## et les comptes que lisent les tests (chaque numéro jusqu'à `numero_applique` est appliqué une fois
## ou sauté, jamais deux fois : `appliquees + sautees == numero_applique`).
var numero_applique := 0
var dernier_recu := 0
var appliquees := 0
var sautees := 0
## La plus longue file vue (tests).
var file_max_vue := 0
var _file: Array[Dictionary] = []


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
	# Bornée : une valeur reçue du réseau pourrait dépasser 1 et rendre un lion plus rapide que sa
	# vitesse.
	return direction_voulue.limit_length(1.0)


func vomir() -> bool:
	if suspendues:
		return false
	if source == Source.LOCALES:
		return Input.is_action_pressed("vomir")
	return vomir_voulu


## Chez l'hôte : la commande `numero` d'un client entre dans la file, à sa place (triée par numéro),
## si son numéro dépasse la dernière appliquée et qu'elle n'y est pas déjà (un doublon tardif, ou un
## paquet redondant qui la recouvre) ; sa direction doit être finie. Un Wi-Fi qui réordonne les
## paquets d'une rafale de rattrapage (scénario 12, désync-report) ne fait donc plus sauter les
## numéros manquants faute d'avoir été refusés à tort : ils comblent le trou en arrivant, dans
## n'importe quel ordre, tant qu'ils ne sont pas déjà appliqués. Faux sinon (déjà appliquée, déjà en
## file, ou non finie).
func recevoir(numero: int, direction_recue: Vector2, vomir_recu: bool) -> bool:
	if numero <= numero_applique or not direction_recue.is_finite():
		return false
	var i := 0
	while i < _file.size() and (_file[i].numero as int) < numero:
		i += 1
	if i < _file.size() and (_file[i].numero as int) == numero:
		return false  # déjà en file : doublon tardif d'un paquet redondant
	_file.insert(i, {"numero": numero, "direction": direction_recue, "vomir": vomir_recu})
	dernier_recu = maxi(dernier_recu, numero)
	while _file.size() > FILE_MAX:
		_file.pop_front()  # la plus ancienne (numéro le plus bas) : sautée, comptée par `appliquer_suivante`
	file_max_vue = maxi(file_max_vue, _file.size())
	return true


## Chez l'hôte, au début du tick physique du lion : la commande suivante de la file devient celle du
## lion. File vide (commande en retard ou perdue) : la dernière appliquée tient encore un tick.
func appliquer_suivante() -> void:
	if _file.is_empty():
		return
	var c: Dictionary = _file.pop_front()
	sautees += c.numero - numero_applique - 1
	numero_applique = c.numero
	appliquees += 1
	direction_voulue = c.direction
	vomir_voulu = c.vomir


## Commandes en attente dans la file (tests).
func en_attente() -> int:
	return _file.size()


## Chez l'hôte, un client muet depuis trop longtemps (`Manche.SILENCE_COMMANDES`) : son lion revient
## au repos et sa file se vide ; les numéros déjà reçus restent refusés.
func remettre_au_repos() -> void:
	direction_voulue = Vector2.ZERO
	vomir_voulu = false
	_file.clear()


## Le paquet d'un client : ses commandes `commandes` (`[direction: Vector2, vomir: bool]`, de la plus
## ancienne à la dernière, 1 à REDONDANCE + 1), dont la dernière porte le numéro `dernier` et les
## précédentes les numéros qui le précèdent.
static func encoder_paquet(dernier: int, commandes: Array) -> PackedByteArray:
	var octets := PackedByteArray()
	octets.resize(TAILLE_ENTETE + TAILLE_COMMANDE * commandes.size())
	octets.encode_u32(0, dernier)
	octets.encode_u8(4, commandes.size())
	for i in range(commandes.size()):
		var debut := TAILLE_ENTETE + TAILLE_COMMANDE * i
		var direction_envoyee: Vector2 = commandes[i][0]
		octets.encode_float(debut, direction_envoyee.x)
		octets.encode_float(debut + 4, direction_envoyee.y)
		octets.encode_u8(debut + 8, 1 if commandes[i][1] else 0)
	return octets


## Le paquet `octets` reçu d'un client : ses commandes `{numero, direction, vomir}`, de la plus
## ancienne à la dernière ; vide pour un paquet mal formé (autre type, taille, nombre de commandes
## hors de 1 à REDONDANCE + 1, numéros sous 1, direction non finie).
static func decoder_paquet(octets: Variant) -> Array[Dictionary]:
	var commandes: Array[Dictionary] = []
	if not (octets is PackedByteArray) or octets.size() < TAILLE_ENTETE:
		return commandes
	var nb: int = octets.decode_u8(4)
	var dernier: int = octets.decode_u32(0)
	if nb < 1 or nb > REDONDANCE + 1 or octets.size() != TAILLE_ENTETE + TAILLE_COMMANDE * nb or dernier < nb:
		return commandes
	for i in range(nb):
		var debut := TAILLE_ENTETE + TAILLE_COMMANDE * i
		var direction_recue := Vector2(octets.decode_float(debut), octets.decode_float(debut + 4))
		if not direction_recue.is_finite():
			return [] as Array[Dictionary]
		commandes.append({"numero": dernier - nb + 1 + i, "direction": direction_recue, "vomir": octets.decode_u8(debut + 8) != 0})
	return commandes
