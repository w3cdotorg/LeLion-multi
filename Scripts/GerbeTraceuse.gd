extends Area2D
## Zone qui suit la gerbe et peint la ville quand elle la recouvre.
## Le rayon de peinture est celui de sa forme de collision (réglé par le lion).

@onready var forme: CollisionShape2D = $CollisionShape2D
## Le lion qui porte cette zone : on peint pour son joueur (ses couleurs ; en bataille, son
## territoire).
@onready var lion: Node = get_parent()


## Tampon au tick physique (60 Hz), pas au rendu : le territoire (`Territoire.GAIN`) est réglé sur
## un gain par tampon, donc par 1/60 s ; peindre au rythme de l'affichage ferait dépendre le trafic
## de tampons et le rééquilibrage du territoire du taux de rafraîchissement de l'hôte (30 à 144 Hz).
## En solo, à 60 Hz, rien ne change. Sur l'hôte seulement : sur un client, le lion réplique le vomi
## de l'hôte (la zone surveille donc aussi la ville), mais ses tampons sont ceux que l'hôte diffuse
## (`Ville.peindre_tampon_recu`) ; en peindre ici en ferait un second, tiré par ce poste.
func _physics_process(_delta: float) -> void:
	if not monitoring or not multiplayer.is_server():
		return
	var peintre: Joueur = lion.joueur
	if peintre.couleurs_debloquees.is_empty():
		return
	var rayon := int((forme.shape as CircleShape2D).radius)
	for area in get_overlapping_areas():
		var ville: Node = area.get_parent()
		if ville != null and ville.has_method("peindre"):
			ville.peindre(global_position, rayon, peintre)
