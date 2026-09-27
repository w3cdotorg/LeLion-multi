class_name InterpolationLion
extends RefCounted
## L'affichage d'un lion distant sur un client (phase 16, spec §4, logique pure : les tests
## `--script` la nomment) : les états reçus de l'hôte (`EtatLion`), rangés par instant de l'hôte,
## sont rejoués avec RETARD ticks de retard, par interpolation entre les deux qui encadrent l'instant
## affiché. Ce retard absorbe la gigue et les pertes du Wi-Fi : un état en retard ou perdu tombe entre
## deux autres, qui suffisent. L'horloge d'affichage avance d'un tick par tick physique du client et se
## recale en douceur sur le dernier instant reçu (RATTRAPAGE de l'écart par tick), d'un coup au-delà
## d'ECART_MAX (premier état, gel d'un des postes). Plus aucun état : le lion continue sur sa vitesse
## EXTRAPOLATION_MAX ticks au plus, puis s'arrête.

## Retard d'affichage, en ticks de l'hôte (100 ms à 60 ticks par seconde) : plus que la gigue simulée
## (40 ms) et deux états perdus de suite (2 × 16,7 ms).
const RETARD := 6.0
const EXTRAPOLATION_MAX := 3.0
const RATTRAPAGE := 0.05
const ECART_MAX := 30.0
const TAMPON_MAX := 32

var _ticks_par_seconde := 60.0
## États reçus (`{instant, position, vitesse, direction}`), par instant croissant, sans doublon.
var _etats: Array[Dictionary] = []
## Instant affiché, en ticks de l'hôte (négatif tant qu'aucun état n'est arrivé).
var _horloge := -1.0
var _dernier := -1


func _init(ticks_par_seconde := 60) -> void:
	_ticks_par_seconde = float(ticks_par_seconde)


## Un état reçu de l'hôte, à son instant `instant` : `vitesse` est la vitesse totale du lion
## (commandée et recul), que lisent son animation et le pare-chocs du lion local. Un état plus ancien
## que ceux qu'on affiche déjà, ou déjà reçu, est ignoré.
func ajouter(instant: int, position: Vector2, vitesse: Vector2, direction: int) -> void:
	if (_horloge >= 0.0 and instant < _horloge - 1.0) or _etats.any(func(e: Dictionary) -> bool: return e.instant == instant):
		return
	var i := _etats.size()
	while i > 0 and _etats[i - 1].instant > instant:
		i -= 1
	_etats.insert(i, {"instant": instant, "position": position, "vitesse": vitesse, "direction": direction})
	while _etats.size() > TAMPON_MAX:
		_etats.pop_front()
	_dernier = maxi(_dernier, instant)


## Un tick physique du client (`ticks` ticks de l'hôte, 1 à la même cadence) : l'horloge avance et se
## recale sur le dernier instant reçu, moins RETARD ; les états trop vieux s'en vont (on garde celui
## qui précède l'instant affiché).
func avancer(ticks: float) -> void:
	if _dernier < 0:
		return
	var cible := _dernier - RETARD
	if _horloge < 0.0:
		_horloge = cible
	else:
		_horloge += ticks
		var ecart := cible - _horloge
		if absf(ecart) > ECART_MAX:
			_horloge = cible
		else:
			_horloge += ecart * RATTRAPAGE
	while _etats.size() > 2 and _etats[1].instant <= _horloge:
		_etats.pop_front()


## Ce qu'affiche le lion à l'instant de l'horloge : `{position, vitesse, direction}`, ou un
## dictionnaire vide tant qu'aucun état n'est arrivé.
func echantillon() -> Dictionary:
	if _etats.is_empty() or _horloge < 0.0:
		return {}
	var a: Dictionary = _etats[0]
	if _horloge <= a.instant:
		return {"position": a.position, "vitesse": a.vitesse, "direction": a.direction}
	for i in range(_etats.size() - 1):
		var b: Dictionary = _etats[i + 1]
		if _horloge <= b.instant:
			a = _etats[i]
			var t: float = (_horloge - a.instant) / float(b.instant - a.instant)
			return {"position": a.position.lerp(b.position, t), "vitesse": a.vitesse.lerp(b.vitesse, t), "direction": a.direction}
	var dernier: Dictionary = _etats[-1]
	var avance := minf(_horloge - dernier.instant, EXTRAPOLATION_MAX)
	return {"position": dernier.position + dernier.vitesse * avance / _ticks_par_seconde, "vitesse": dernier.vitesse, "direction": dernier.direction}


## Retard de l'affichage sur le dernier état reçu, en ticks de l'hôte (tests).
func retard() -> float:
	return _dernier - _horloge
