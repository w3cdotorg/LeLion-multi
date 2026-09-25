extends Node
## Effets sonores et musique en couches. La musique est un ensemble de trois pistes
## synchronisées (base, arpèges, mélodie) ; l'intensité 0..2 décide combien on entend.

const DB_VOMI := -8.0
const DB_MUSIQUE := -12.0
const DB_MUET := -80.0
const COUCHES := ["base", "arp", "melodie"]
const FONDU := 0.8

const SONS := {
	"pickup": preload("res://Assets/Sons/pickup.wav"),
	"mort": preload("res://Assets/Sons/mort.wav"),
	"victoire": preload("res://Assets/Sons/victoire.wav"),
	"boss": preload("res://Assets/Sons/boss.wav"),
	"pret": preload("res://Assets/Sons/pret.wav"),
}
const ENSEMBLES := {
	"ville": {
		"base": preload("res://Assets/Sons/ville_base.wav"),
		"arp": preload("res://Assets/Sons/ville_arp.wav"),
		"melodie": preload("res://Assets/Sons/ville_melodie.wav"),
	},
	"boss": {
		"base": preload("res://Assets/Sons/boss_base.wav"),
		"arp": preload("res://Assets/Sons/boss_arp.wav"),
		"melodie": preload("res://Assets/Sons/boss_melodie.wav"),
	},
}

var _vomi_stream: AudioStreamWAV = preload("res://Assets/Sons/vomi.wav")
var _vomi: AudioStreamPlayer
var _pistes: Array[AudioStreamPlayer] = []
var _musique: AudioStreamPlayer  # la piste de base, toujours audible
var ensemble_courant := ""
var intensite := -1
var _fondus: Array = [null, null, null]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vomi_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_vomi_stream.loop_end = int(_vomi_stream.get_length() * _vomi_stream.mix_rate)
	_vomi = AudioStreamPlayer.new()
	_vomi.stream = _vomi_stream
	add_child(_vomi)

	for couche in COUCHES:
		var piste := AudioStreamPlayer.new()
		piste.name = "Piste" + couche.capitalize()
		add_child(piste)
		_pistes.append(piste)
	_musique = _pistes[0]
	for ensemble in ENSEMBLES.values():
		for stream: AudioStreamWAV in ensemble.values():
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length() * stream.mix_rate)

	Parametres.volumes_changes.connect(appliquer_volumes)
	demarrer_musique("ville", 1)

	# Son de pastille : le joueur local vient de débloquer une couleur. Le Joueur vit aussi
	# longtemps que GameState, l'abonnement est pris une fois pour toute la session.
	GameState.joueur_local().couleur_debloquee.connect(func(_c: Color) -> void: jouer("pickup"))
	GameState.partie_terminee.connect(_on_partie_terminee)


## Lance un ensemble (toutes les pistes ensemble, en boucle) à l'intensité donnée.
func demarrer_musique(nom: String, intensite_initiale: int) -> void:
	if nom == ensemble_courant:
		definir_intensite(intensite_initiale)
		return
	ensemble_courant = nom
	for i in range(COUCHES.size()):
		_pistes[i].stream = ENSEMBLES[nom][COUCHES[i]]
	intensite = -1
	definir_intensite(intensite_initiale, true)
	for piste in _pistes:
		piste.play(0.0)


## 0 = base seule, 1 = + arpèges, 2 = + mélodie. Fondu de FONDU s sauf si `immediat`.
func definir_intensite(niveau: int, immediat := false) -> void:
	niveau = clampi(niveau, 0, COUCHES.size() - 1)
	if niveau == intensite:
		return
	intensite = niveau
	for i in range(COUCHES.size()):
		var cible := _db_piste(i)
		if _fondus[i] != null and _fondus[i].is_valid():
			_fondus[i].kill()
		if immediat:
			_pistes[i].volume_db = cible
		else:
			_fondus[i] = create_tween()
			_fondus[i].tween_property(_pistes[i], "volume_db", cible, FONDU)


func _db_piste(index: int) -> float:
	var db := DB_MUSIQUE + Parametres.en_db(Parametres.musique)
	return db if index <= intensite else db + DB_MUET


func appliquer_volumes() -> void:
	for i in range(_pistes.size()):
		_pistes[i].volume_db = _db_piste(i)
	_vomi.volume_db = DB_VOMI + Parametres.en_db(Parametres.effets)


func jouer(nom: String) -> void:
	var lecteur := AudioStreamPlayer.new()
	lecteur.stream = SONS[nom]
	lecteur.volume_db = Parametres.en_db(Parametres.effets)
	lecteur.finished.connect(lecteur.queue_free)
	add_child(lecteur)
	lecteur.play()


func demarrer_vomi() -> void:
	if not _vomi.playing:
		_vomi.play()


func arreter_vomi() -> void:
	_vomi.stop()


func _on_partie_terminee(victoire: bool) -> void:
	arreter_vomi()
	jouer("victoire" if victoire else "mort")
	if victoire:
		definir_intensite(2)
