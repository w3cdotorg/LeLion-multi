class_name PareChocs
extends Area2D
## Le pare-chocs d'un lion, ses auto-tamponneuses (spec §5) : un cercle de 45 px (au lieu des 63 px
## du corps) sur la couche des lions (couche 5), qui ne voit que les pare-chocs des autres lions.
## Au premier contact avec un autre lion, la part de la vitesse commandée qui pointait vers lui est
## annulée (sinon la commande maintenue y ramène aussitôt et re-déclenche un choc à chaque frame,
## ~7/s en pratique) : le lion doit réaccélérer avant de retraverser. Le choc n'est compté, secoué et
## signalé aux règles que si l'approche était assez rapide et que le délai anti-rafale est passé avec
## cet autre lion (un lion étourdi reste poussable). Pendant le contact, `bloquer` retire de la vitesse
## du lion ce qui l'enfoncerait dans l'autre et écarte deux lions qui se chevauchent.
## Seul l'hôte signale un choc aux règles. Sur un client, un lion distant ne fait que secouer son
## sprite au choc (sa position et sa vitesse viennent de l'hôte, interpolées) ; le lion local, prédit
## (phase 16), prend tout de suite son recul et son blocage contre les lions affichés, pour un « boing »
## immédiat : chaque choc simulé part aussi en signal (`choc_simule`), que sa prédiction note pour le
## rejouer tant que l'hôte, qui fait foi, ne l'a pas dans ses états.

## Un choc vient de changer la vitesse commandée et le recul de ce lion (ce qui leur a été ajouté).
signal choc_simule(vitesse: Vector2, recul: Vector2)

## Recul de chaque lion au choc = vitesse d'approche relative × facteur_choc.
@export var facteur_choc: float = 1.2
## Vitesse d'écartement de deux lions qui se chevauchent, par pixel d'enfoncement.
@export var raideur_choc: float = 8.0
## Vitesse d'approche minimale (px/s) pour qu'un contact compte comme un choc ; en dessous,
## les lions se bloquent quand même (`bloquer`), sans secousse ni décompte.
@export var approche_min_choc: float = 100.0
## Délai minimal entre deux chocs comptés avec le même autre lion, en secondes de jeu, pour
## qu'une poussée continue ne rafale pas les chocs (la commande maintenue ramène aussitôt l'un vers
## l'autre).
@export var delai_entre_chocs: float = 0.3

## Rayon du pare-chocs (celui de sa forme).
@onready var rayon: float = ($CollisionShape2D.shape as CircleShape2D).radius
@onready var _lion: Lion = get_parent()

## Vrai pendant qu'une prédiction rejoue des pas passés du lion (`PredictionLocale`) : `bloquer` ne
## voit que les contacts présents, qu'il ne compte alors qu'aux positions rejouées où les deux
## pare-chocs se touchent (un pas rejoué d'avant le contact ne doit pas buter contre lui).
var en_rejeu := false
## Instant (`Lion.temps`, en secondes de jeu) du dernier choc compté avec chaque autre lion, par
## identifiant d'instance du lion ; entrées des lions libérés nettoyées à la volée. Le temps de jeu,
## pas l'horloge murale : une frame qui rame ou un test en `--fixed-fps` ne change rien au décompte.
var _derniers_chocs: Dictionary = {}


func _ready() -> void:
	area_entered.connect(_on_area_entered)


## Pendant le contact, la vitesse `v` du lion ne l'enfonce pas dans un autre lion (la part dirigée
## vers lui est annulée), et deux lions qui se chevauchent s'écartent.
func bloquer(v: Vector2) -> Vector2:
	for zone in get_overlapping_areas():
		var autre := zone.get_parent() as Lion
		if autre == null or autre == _lion:
			continue
		if en_rejeu and global_position.distance_to(autre.pare_chocs.global_position) > 2.0 * rayon:
			continue
		var normale := _normale_de_choc(autre)
		var vers_autre := v.dot(-normale)
		if vers_autre > 0.0:
			v += normale * vers_autre
		var enfoncement := 2.0 * rayon - global_position.distance_to(autre.pare_chocs.global_position)
		var vitesse_ecartement: float = minf(maxf(enfoncement, 0.0) * raideur_choc, _lion.deplacement.speed)
		v += normale * vitesse_ecartement
	return v


func _on_area_entered(zone: Area2D) -> void:
	var autre := zone.get_parent() as Lion
	if autre == null or autre == _lion:
		return
	var deplacement := _lion.deplacement
	var normale := _normale_de_choc(autre)
	var approche := (_lion.velocity - autre.velocity).dot(-normale)
	var vers_autre := deplacement.vitesse.dot(-normale)
	var choc_vitesse := Vector2.ZERO
	if vers_autre > 0.0:
		choc_vitesse = normale * vers_autre
		deplacement.vitesse += choc_vitesse
	var choc_recul := Vector2.ZERO
	if _compte_comme_choc(autre, approche):
		choc_recul = normale * approche * facteur_choc
		deplacement.recul += choc_recul
		_lion.secouer()
		# Un seul signalement par choc : celui des deux lions dont l'identifiant est le plus petit.
		if multiplayer.is_server() and _lion.get_instance_id() < autre.get_instance_id():
			GameState.regles.choc_entre_lions(_lion.joueur, autre.joueur)
	if choc_vitesse != Vector2.ZERO or choc_recul != Vector2.ZERO:
		choc_simule.emit(choc_vitesse, choc_recul)


## Vrai si le contact avec `autre`, à la vitesse d'approche `approche`, compte comme un choc (assez
## rapide, délai anti-rafale passé avec cet autre lion) ; il est alors noté pour ce délai.
func _compte_comme_choc(autre: Lion, approche: float) -> bool:
	if approche < approche_min_choc:
		return false
	_nettoyer_derniers_chocs()
	var dernier: float = _derniers_chocs.get(autre.get_instance_id(), -1.0)
	if dernier >= 0.0 and _lion.temps - dernier < delai_entre_chocs:
		return false
	_derniers_chocs[autre.get_instance_id()] = _lion.temps
	return true


## Entrées du dictionnaire des délais anti-rafale dont l'autre lion n'existe plus (déconnexion,
## fin de manche) : nettoyées à la volée, jamais par une passe périodique dédiée.
func _nettoyer_derniers_chocs() -> void:
	for id in _derniers_chocs.keys():
		if instance_from_id(id) == null:
			_derniers_chocs.erase(id)


## Direction de l'autre lion vers celui-ci ; deux lions superposés s'écartent quand même,
## chacun de son côté.
func _normale_de_choc(autre: Lion) -> Vector2:
	var ecart := global_position - autre.pare_chocs.global_position
	if ecart.length() > 0.01:
		return ecart.normalized()
	return Vector2.LEFT if _lion.get_instance_id() < autre.get_instance_id() else Vector2.RIGHT
