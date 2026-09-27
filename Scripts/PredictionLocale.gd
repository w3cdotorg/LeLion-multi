class_name PredictionLocale
extends Node
## La prédiction du lion local sur un client (phase 16, spec §4.1) : ce lion avance dès la frame
## courante avec les commandes de ce poste, par le même pas que l'hôte (`Lion.avancer`), sans attendre
## l'aller-retour du réseau. Enfant du lion du joueur local, sur un client seulement (ni chez l'hôte, ni
## en solo, ni en bataille locale) ; ajouté par le lion quand `Main` le lui donne.
## À chaque tick physique, avant les lions (priorité -10) et avant la manche qui envoie (priorité 100) :
## 1. les actions de ce poste sont lues une seule fois (direction et vomir au même tick), numérotées,
##    écrites dans les commandes manuelles du lion et gardées dans l'historique (`paquet()` en donne
##    la dernière et jusqu'à 3 précédentes, que la manche envoie à l'hôte) ;
## 2. si un état neuf de l'hôte est arrivé (`Lion.etat_reseau`, reçu pendant le sondage réseau, donc
##    rejoué ici, dans une image physique), le lion repart de cet état (position, vitesse commandée,
##    recul, orientation) et rejoue les commandes que l'hôte n'a pas encore appliquées (numéros au-delà
##    de celui de l'état), avec les chocs qu'il avait simulés à ces ticks ; l'écart entre l'ancienne
##    prédiction et la nouvelle passe dans un décalage d'affichage ;
## 3. le lion fait son pas de ce tick ; le décalage s'amortit (DUREE_CORRECTION : 95 % en 120 ms),
##    sauf au-delà de SEUIL_RECALAGE (téléportation, désynchronisation grave) : recalage immédiat.
## Le lion ne suit que les commandes qu'accepte l'hôte : rien avant la fin de l'intro, rien pendant un
## étourdissement (le rejeu applique la même règle, `Lion.direction_pour` : pendant un étourdissement,
## le lion suit l'hôte). Ses chocs contre les autres lions (affichés, interpolés) sont simulés tout de
## suite par son pare-chocs (`PareChocs.choc_simule`), notés au tick où ils arrivent et rejoués avec
## lui ; l'hôte fait foi, le recalage absorbe l'écart. Les réactions décidées par l'hôte
## (étourdissement, recul d'un coup) arrivent dans ses états : jamais notées ni rejouées ici.
## Nœud : il nomme `Lion` ; les tests `--script` ne le nomment pas.

## Au-delà de cet écart (px) entre l'ancienne prédiction et la nouvelle, le lion est recalé d'un coup.
const SEUIL_RECALAGE := 200.0
## Constante de temps (s) du décalage d'affichage : e^(-0,12 / 0,04) = 5 % restent après 120 ms.
const DUREE_CORRECTION := 0.04
## Décalage résiduel (px) remis à zéro : invisible.
const DECALAGE_NEGLIGEABLE := 0.5
## Commandes gardées au plus pour le rejeu (2 s) : un hôte figé n'en accuse plus aucune.
const HISTORIQUE_MAX := 120
## Erreurs de prédiction gardées pour les statistiques (tests).
const JOURNAL_MAX := 20000

## Numéro de la dernière commande lue (0 : aucune encore).
var numero := 0
## Numéro de la dernière commande appliquée par l'hôte, selon son dernier état reçu.
var numero_accuse := 0
## Statistiques lues par les tests : états neufs reçus, recalages immédiats, plus long rejeu (pas).
var etats_recus := 0
var recalages := 0
var rejeu_max := 0

var _lion: Lion
## Les actions de ce poste, lues une fois par tick.
var _locales := Commandes.locales()
## Commandes pas encore appliquées par l'hôte, de la plus ancienne à la dernière :
## `{numero, direction, vomir, choc_vitesse, choc_recul, predite}` (predite : la position prédite après
## son pas, au tick où elle a été lue, sans le décalage d'affichage : ce que le joueur a vu).
var _historique: Array[Dictionary] = []
## Chocs simulés depuis le dernier tick (notés avec la commande de ce tick).
var _choc_vitesse := Vector2.ZERO
var _choc_recul := Vector2.ZERO
## Écart d'affichage (px) entre la position montrée et la position prédite.
var _decalage := Vector2.ZERO
## Instant (tick de l'hôte) du dernier état utilisé.
var _instant_utilise := -1
## `Vector2(numéro accusé, erreur)` de chaque état neuf : l'erreur de prédiction est l'écart entre la
## position de l'hôte après la commande accusée et celle que ce poste avait prédite pour elle au tick
## où il l'a lue (ce que le joueur a vu, pas une prédiction refaite depuis par un rejeu).
var _journal: PackedVector2Array = []


func _ready() -> void:
	process_physics_priority = -10
	_lion = get_parent() as Lion
	_lion.pare_chocs.choc_simule.connect(_sur_choc_simule)
	# Sur un client, le déplacement du lion n'avait jamais servi : il part d'un état neutre, jamais
	# d'une vitesse reçue de l'hôte (vitesse totale, recul déjà joué).
	_lion.deplacement.vitesse = Vector2.ZERO
	_lion.deplacement.recul = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_lion.position -= _decalage
	var suspendues := _lion.commandes.suspendues
	var direction_lue := Vector2.ZERO if suspendues else _locales.direction()
	var vomir_lu := false if suspendues else _locales.vomir()
	numero += 1
	var commande: Dictionary = {"numero": numero, "direction": direction_lue, "vomir": vomir_lu,
		"choc_vitesse": _choc_vitesse, "choc_recul": _choc_recul, "predite": Vector2.ZERO}
	_choc_vitesse = Vector2.ZERO
	_choc_recul = Vector2.ZERO
	_historique.append(commande)
	if _historique.size() > HISTORIQUE_MAX:
		_historique.pop_front()
	_lion.commandes.direction_voulue = direction_lue
	_lion.commandes.vomir_voulu = vomir_lu
	var etat := _lion.dernier_etat_recu()
	if not etat.is_empty() and etat.instant > _instant_utilise:
		_recaler(etat, delta)
	_lion.avancer(_lion.direction_pour(direction_lue), delta)
	commande.predite = _lion.position
	_decalage *= exp(-delta / DUREE_CORRECTION)
	if _decalage.length() < DECALAGE_NEGLIGEABLE:
		_decalage = Vector2.ZERO
	_lion.position += _decalage


## Le paquet de commandes à envoyer à l'hôte : la dernière lue et jusqu'à REDONDANCE précédentes
## (`Commandes.encoder_paquet`) ; vide avant la première.
func paquet() -> PackedByteArray:
	if _historique.is_empty():
		return PackedByteArray()
	var envoi := _historique.slice(maxi(0, _historique.size() - Commandes.REDONDANCE - 1))
	return Commandes.encoder_paquet(envoi[-1].numero, envoi.map(func(c: Dictionary) -> Array: return [c.direction, c.vomir]))


## Écart (px) entre la position affichée et la position prédite.
func decalage() -> Vector2:
	return _decalage


## Remet les statistiques à zéro (tests, contrôle à la main).
func remettre_statistiques() -> void:
	etats_recus = 0
	recalages = 0
	rejeu_max = 0
	_journal.clear()


## La plus grande erreur de prédiction des états qui accusent une commande de `depuis` à `jusqu_a`
## (tests) ; -1 si aucun.
func erreur_max(depuis := 1, jusqu_a := 1 << 30) -> float:
	var pire := -1.0
	for e in _journal:
		if int(e.x) >= depuis and int(e.x) <= jusqu_a:
			pire = maxf(pire, e.y)
	return pire


## Nombre d'états neufs qui accusent au moins la commande `depuis` et dont l'erreur dépasse `seuil`
## (tests).
func erreurs_au_dela(seuil: float, depuis := 0) -> int:
	var n := 0
	for e in _journal:
		if int(e.x) >= depuis and e.y > seuil:
			n += 1
	return n


## Nombre d'états neufs qui accusent au moins la commande `depuis` (tests).
func etats_depuis(depuis: int) -> int:
	var n := 0
	for e in _journal:
		if int(e.x) >= depuis:
			n += 1
	return n


## Le lion repart de l'état `etat` de l'hôte et rejoue les commandes que l'hôte n'a pas encore
## appliquées, sauf celle de ce tick (son pas suit).
func _recaler(etat: Dictionary, delta: float) -> void:
	_instant_utilise = etat.instant
	etats_recus += 1
	var accuse: int = etat.commande
	numero_accuse = accuse
	var avant: Vector2 = _lion.position
	while not _historique.is_empty() and _historique[0].numero <= accuse:
		var appliquee: Dictionary = _historique.pop_front()
		if appliquee.numero == accuse and _journal.size() < JOURNAL_MAX:
			_journal.append(Vector2(accuse, (etat.position as Vector2).distance_to(appliquee.predite)))
	_lion.position = etat.position
	_lion.deplacement.vitesse = etat.vitesse
	_lion.deplacement.recul = etat.recul
	_lion.direction_du_lion = etat.direction
	for i in range(_historique.size()):
		var c: Dictionary = _historique[i]
		_lion.deplacement.vitesse += c.choc_vitesse
		_lion.deplacement.recul += c.choc_recul
		if i == _historique.size() - 1:
			break  # la commande de ce tick : son pas suit, dans `_physics_process`
		_lion.avancer(_lion.direction_pour(c.direction), delta)
	rejeu_max = maxi(rejeu_max, _historique.size() - 1)
	var ecart := avant - _lion.position
	if ecart.length() > SEUIL_RECALAGE:
		recalages += 1
		_decalage = Vector2.ZERO
	else:
		_decalage += ecart


## Un choc simulé par le pare-chocs du lion (entre deux ticks) : noté avec la commande du prochain tick,
## pour le rejouer tant que l'hôte ne l'a pas.
func _sur_choc_simule(vitesse: Vector2, recul: Vector2) -> void:
	_choc_vitesse += vitesse
	_choc_recul += recul
