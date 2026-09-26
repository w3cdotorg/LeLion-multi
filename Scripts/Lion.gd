class_name Lion
extends CharacterBody2D
## Le lion : déplacement, gerbe de vomi multicolore, traceuse de peinture ; en bataille,
## crinière à la couleur de son joueur, pseudo au-dessus de la tête, étourdissement et
## auto-tamponneuses.
## La gerbe part de la bouche à 45° vers le bas ; la traceuse est placée au point de chute et
## les zones de contact le long de la parabole, avec la même physique que les particules.
## Le lion ne décide de rien : sur l'hôte, il signale aux règles les autres lions que touche
## sa gerbe et ceux qu'il percute, comme le font les ennemis et les pastilles.

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
const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
const PAS_RAYON_PAR_CRAN := 5
const NB_ZONES_CONTACT := 3
const RAYON_ZONE_CONTACT := 22.0
const COUCHE_CORPS_LIONS := 1  # couche du corps des lions, celle que détectent ennemis et pastilles
const CENTRE := Vector2(68, 66)  # centre du corps, dans le repère du lion
const FORCE_BARBOUILLAGE := 0.7
const RAYON_ETOILES := Vector2(40, 12)
const VITESSE_ETOILES := 5.0  # radians par seconde
const DUREE_SECOUSSE := 0.25
const AMPLITUDE_SECOUSSE := 6.0

@export var speed: float = 350.0
@export var acceleration: float = 2400.0
@export var force_recul: float = 700.0
@export var inclinaison_max: float = 0.14  # radians
## Auto-tamponneuses : recul de chaque lion = vitesse d'approche relative × facteur_choc.
@export var facteur_choc: float = 1.2
## Vitesse d'écartement de deux lions qui se chevauchent, par pixel d'enfoncement.
@export var raideur_choc: float = 8.0
## Vitesse d'approche minimale (px/s) pour qu'un contact compte comme un choc ; en dessous,
## les lions se bloquent quand même (`_bloquer_contre_les_lions`), sans secousse ni décompte.
@export var approche_min_choc: float = 100.0
## Délai minimal entre deux chocs comptés avec le même autre lion, en secondes de jeu, pour
## qu'une poussée continue ne rafale pas les chocs (la commande maintenue ramène aussitôt l'un vers
## l'autre).
@export var delai_entre_chocs: float = 0.3

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var vomi_container: Node2D = $VomiParticlesContainer
@onready var gerbe_traceuse: Area2D = $GerbeTraceuse
@onready var traceuse_shape: CollisionShape2D = $GerbeTraceuse/CollisionShape2D
@onready var bouche: Marker2D = $Bouche
@onready var etiquette_pseudo: Label = $Pseudo
@onready var etoiles: Node2D = $Etoiles
@onready var pare_chocs: Area2D = $PareChocs
@onready var _rayon_choc: float = ($PareChocs/CollisionShape2D.shape as CircleShape2D).radius

var est_en_train_de_vomir := false
var direction_du_lion: int = 1  # 1 = droite, -1 = gauche
## État du lion (couleurs, bonus, coups) et source de ses intentions. À fournir avant l'ajout
## à l'arbre ; à défaut, le joueur local et ses commandes (celles du pilote en démo).
var joueur: Joueur:
	set(valeur):
		# `is_node_ready()` vaut déjà true pendant `_ready()` lui-même (pas seulement après) :
		# le garde-fou ne bloque donc que le remplacement d'un joueur déjà fixé, pas le repli
		# par défaut fait par `_ready()` ci-dessous.
		if is_node_ready() and joueur != null:
			push_error("Lion.joueur se fixe avant l'ajout à l'arbre")
			return
		joueur = valeur
var commandes: Commandes
## Zones de contact de la gerbe, de la bouche au point de chute (la dernière y rejoint la traceuse).
var zones_contact: Array[Area2D] = []
var _vitesse := Vector2.ZERO
var _recul := Vector2.ZERO
var _temps := 0.0  # secondes de jeu écoulées pour ce lion (ticks physiques)
var _clignotement: Tween
var _secousse_restante := 0.0
## Générateur propre au lion pour la secousse du sprite : ne pas consommer la séquence globale
## de `randf_range`, dont dépendent le Spawner et les ennemis.
var _rng := RandomNumberGenerator.new()
## Instant (`_temps`, en secondes de jeu) du dernier choc compté avec chaque autre lion, par
## identifiant d'instance ; entrées des lions libérés nettoyées à la volée. Le temps de jeu, pas
## l'horloge murale : une frame qui rame ou un test en `--fixed-fps` ne change rien au décompte.
var _derniers_chocs: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	if joueur == null:
		joueur = GameState.joueur_local()
	if commandes == null:
		commandes = Commandes.manuelles() if GameState.demo else Commandes.locales()
	# La sous-ressource de Lion.tscn est partagée par toutes les instances ; chaque lion a besoin
	# de son propre rayon.
	traceuse_shape.shape = traceuse_shape.shape.duplicate()
	joueur.couleur_debloquee.connect(_on_couleur_debloquee)
	joueur.bonus_change.connect(_on_bonus_change)
	joueur.touche.connect(_on_lion_touche)
	joueur.crans_changes.connect(_on_crans_changes)
	joueur.etourdi.connect(_on_etourdi)
	joueur.etourdissement_fini.connect(_on_etourdissement_fini)
	pare_chocs.area_entered.connect(_on_pare_chocs_area_entered)
	_creer_zones_contact()
	_appliquer_direction()
	mettre_a_jour_degrade_vomi()
	appliquer_apparence()


func _physics_process(delta: float) -> void:
	_temps += delta
	var input_vector := _direction_voulue()

	if input_vector.x != 0:
		var nouvelle_direction := 1 if input_vector.x > 0 else -1
		if nouvelle_direction != direction_du_lion:
			direction_du_lion = nouvelle_direction
			_appliquer_direction()

	_vitesse = _vitesse.move_toward(input_vector * speed, acceleration * delta)
	_recul = _recul.move_toward(Vector2.ZERO, acceleration * 1.5 * delta)
	velocity = _bloquer_contre_les_lions(_vitesse + _recul)
	move_and_slide()
	_animer_deplacement(delta)

	var screen_rect := get_viewport_rect()
	var sprite_size := sprite.texture.get_size()
	var x_borne: float = clamp(global_position.x, 0, screen_rect.size.x - sprite_size.x)
	var y_borne: float = clamp(global_position.y, _marge_haute(), screen_rect.size.y - sprite_size.y)
	# Un lion plaqué contre un bord n'a plus de vitesse fantôme sur cet axe : move_and_slide()
	# ne connaît pas ce bord (ce n'est pas une collision), il ne l'a donc pas déjà annulée.
	if x_borne != global_position.x:
		velocity.x = 0.0
	if y_borne != global_position.y:
		velocity.y = 0.0
	global_position.x = x_borne
	global_position.y = y_borne
	_signaler_vomi_sur_les_lions()


func _process(delta: float) -> void:
	if _veut_vomir():
		if not est_en_train_de_vomir:
			demarrer_vomi()
	elif est_en_train_de_vomir:
		arreter_vomi()
	if (etoiles.visible or _barbouillage_actif()) and not joueur.est_etourdi():
		# L'étourdissement peut finir sans passer par le signal (`Joueur.reinitialiser` en plein
		# étourdissement, par exemple, qui n'émet rien) : les effets visuels se corrigent d'eux-mêmes.
		_on_etourdissement_fini()
	if etoiles.visible:
		_tourner_etoiles()
	if _secousse_restante > 0.0:
		_secousse_restante = max(0.0, _secousse_restante - delta)
		var amplitude := AMPLITUDE_SECOUSSE * _secousse_restante / DUREE_SECOUSSE
		sprite.offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * amplitude


## Hauteur gardée libre au-dessus du lion : celle de son pseudo quand il s'affiche (bataille),
## pour qu'un lion collé en haut de l'écran ne le cache pas ; aucune en solo.
func _marge_haute() -> float:
	return -etiquette_pseudo.position.y if etiquette_pseudo.visible else 0.0


## Un lion étourdi ignore ses commandes : il ne se dirige plus et ne vomit plus.
func _direction_voulue() -> Vector2:
	return commandes.direction() if GameState.pret and not joueur.est_etourdi() else Vector2.ZERO


func _veut_vomir() -> bool:
	return GameState.pret and not joueur.est_etourdi() and commandes.vomir()


func _on_couleur_debloquee(_couleur: Color) -> void:
	mettre_a_jour_degrade_vomi()


## Crinière à la couleur du joueur et pseudo au-dessus de la tête. Lu une fois dans `_ready` ;
## à rappeler si la couleur ou le pseudo du joueur change ensuite (aperçu du salon, phase 13).
func appliquer_apparence() -> void:
	if not is_node_ready():
		return  # sprite et étiquette n'existent pas encore : `_ready` l'appliquera
	_appliquer_teinte()
	etiquette_pseudo.text = joueur.pseudo
	etiquette_pseudo.add_theme_color_override("font_color", joueur.couleur)
	etiquette_pseudo.visible = joueur.a_une_couleur() and not joueur.pseudo.is_empty()


## Un joueur sans couleur (le solo) laisse le sprite sans matériau : le lion s'affiche
## exactement comme ses sprites d'origine. Sinon, le lion crée son propre matériau (jamais
## partagé entre instances de Lion.tscn) ; il vaut pour les deux sprites, repos et vomi.
func _appliquer_teinte() -> void:
	if not joueur.a_une_couleur():
		sprite.material = null
		return
	var mat := sprite.material as ShaderMaterial
	if mat == null or mat.shader != SHADER_TEINTE:
		mat = ShaderMaterial.new()
		mat.shader = SHADER_TEINTE
		sprite.material = mat
	mat.set_shader_parameter("couleur_joueur", joueur.couleur)


## Penche le lion dans le sens de la course et le fait trottiner.
func _animer_deplacement(delta: float) -> void:
	var cible: float = (_vitesse.x / speed) * inclinaison_max * signf(sprite.scale.x)
	sprite.rotation = lerp(sprite.rotation, cible, min(1.0, 10.0 * delta))
	var en_mouvement := _vitesse.length() > speed * 0.2
	var bob := sin(_temps * 14.0) * 3.0 if en_mouvement else 0.0
	sprite.position.y = lerp(sprite.position.y, 67.0 + bob, min(1.0, 12.0 * delta))


## Recul et clignotement pendant l'invulnérabilité qui suit un coup (solo).
func _on_lion_touche(origine: Vector2) -> void:
	Audio.jouer("mort")
	_reculer(origine)
	_clignoter(joueur.invulnerable_restant)


## Étourdi (bataille) : immobile, repoussé, tête barbouillée de la couleur de l'agresseur
## (aucune pour un ennemi), étoiles qui tournent. Le vomi s'arrête au `_process` suivant
## (`_veut_vomir` est faux pendant l'étourdissement) ; d'ici là, les règles n'ignorent un
## agresseur étourdi que depuis une frame physique antérieure (un échange simultané étourdit
## les deux lions).
func _on_etourdi(origine: Vector2, barbouillage: Color) -> void:
	_vitesse = Vector2.ZERO
	_reculer(origine)
	_barbouiller(barbouillage)
	etoiles.visible = true
	_tourner_etoiles()


## Fin de l'étourdissement : barbouillage et étoiles s'en vont, l'immunité clignote.
func _on_etourdissement_fini() -> void:
	_barbouiller(Color.TRANSPARENT)
	etoiles.visible = false
	_clignoter(joueur.invulnerable_restant)


func _reculer(origine: Vector2) -> void:
	var direction_recul := Vector2(-direction_du_lion, 0.0)
	if origine.is_finite():
		direction_recul = (global_position + CENTRE - origine).normalized()
		if direction_recul.length() < 0.1:
			direction_recul = Vector2(-direction_du_lion, 0.0)
	_recul = direction_recul * force_recul


## Clignotement de l'invulnérabilité : le même après un coup (solo) et pour l'immunité qui suit
## un étourdissement (bataille).
func _clignoter(duree: float) -> void:
	var nb_clignotements := int(duree / 0.15)
	if nb_clignotements <= 0:
		return
	if _clignotement != null:
		_clignotement.kill()
	sprite.modulate.a = 1.0
	_clignotement = create_tween()
	for i in range(nb_clignotements):
		_clignotement.tween_property(sprite, "modulate:a", 0.25, 0.075)
		_clignotement.tween_property(sprite, "modulate:a", 1.0, 0.075)


## Toute la tête vire à `couleur` (uniformes du shader de teinte) ; une couleur transparente
## efface le barbouillage. Sans matériau (joueur sans couleur), rien à barbouiller.
func _barbouiller(couleur: Color) -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("barbouillage_couleur", couleur)
	mat.set_shader_parameter("barbouillage_force", FORCE_BARBOUILLAGE if couleur.a > 0.0 else 0.0)


func _tourner_etoiles() -> void:
	var nb := etoiles.get_child_count()
	for i in range(nb):
		var angle := _temps * VITESSE_ETOILES + TAU * i / nb
		etoiles.get_child(i).position = Vector2(cos(angle) * RAYON_ETOILES.x, sin(angle) * RAYON_ETOILES.y)


## Auto-tamponneuses, à chaque contact : la part de la vitesse commandée qui pointait vers
## l'autre lion est annulée (sinon la commande maintenue y ramène aussitôt et re-déclenche un
## choc à chaque frame, ~7/s en pratique) ; le lion doit donc réaccélérer avant de retraverser.
## Le choc n'est compté, secoué et signalé aux règles que si l'approche était assez rapide et
## que le délai anti-rafale est passé avec cet autre lion (un lion étourdi reste poussable).
func _on_pare_chocs_area_entered(zone: Area2D) -> void:
	var autre := zone.get_parent() as Lion
	if autre == null or autre == self:
		return
	var normale := _normale_de_choc(autre)
	var approche := (velocity - autre.velocity).dot(-normale)
	var vers_autre := _vitesse.dot(-normale)
	if vers_autre > 0.0:
		_vitesse += normale * vers_autre
	if approche < approche_min_choc:
		return
	_nettoyer_derniers_chocs()
	var dernier: float = _derniers_chocs.get(autre.get_instance_id(), -1.0)
	if dernier >= 0.0 and _temps - dernier < delai_entre_chocs:
		return
	_derniers_chocs[autre.get_instance_id()] = _temps
	_recul += normale * approche * facteur_choc
	_secousse_restante = DUREE_SECOUSSE
	# Un seul signalement par choc : celui des deux lions dont l'identifiant est le plus petit.
	if multiplayer.is_server() and get_instance_id() < autre.get_instance_id():
		GameState.regles.choc_entre_lions(joueur, autre.joueur)


## Entrées du dictionnaire des délais anti-rafale dont l'autre lion n'existe plus (déconnexion,
## fin de manche) : nettoyées à la volée, jamais par une passe périodique dédiée.
func _nettoyer_derniers_chocs() -> void:
	for id in _derniers_chocs.keys():
		if instance_from_id(id) == null:
			_derniers_chocs.erase(id)


## Vrai si la tête porte encore un barbouillage visible (couleur d'agresseur appliquée).
## `get_shader_parameter` renvoie `null` tant que `_barbouiller` ne l'a jamais fixé.
func _barbouillage_actif() -> bool:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return false
	var force: Variant = mat.get_shader_parameter("barbouillage_force")
	return force != null and force > 0.0


## Pendant le contact, un lion ne s'enfonce pas dans l'autre (la part de sa vitesse dirigée
## vers lui est annulée), et deux lions qui se chevauchent s'écartent.
func _bloquer_contre_les_lions(v: Vector2) -> Vector2:
	for zone in pare_chocs.get_overlapping_areas():
		var autre := zone.get_parent() as Lion
		if autre == null or autre == self:
			continue
		var normale := _normale_de_choc(autre)
		var vers_autre := v.dot(-normale)
		if vers_autre > 0.0:
			v += normale * vers_autre
		var enfoncement := 2.0 * _rayon_choc - pare_chocs.global_position.distance_to(autre.pare_chocs.global_position)
		var vitesse_ecartement: float = minf(maxf(enfoncement, 0.0) * raideur_choc, speed)
		v += normale * vitesse_ecartement
	return v


## Direction de l'autre lion vers celui-ci ; deux lions superposés s'écartent quand même,
## chacun de son côté.
func _normale_de_choc(autre: Lion) -> Vector2:
	var ecart := pare_chocs.global_position - autre.pare_chocs.global_position
	if ecart.length() > 0.01:
		return ecart.normalized()
	return Vector2.LEFT if get_instance_id() < autre.get_instance_id() else Vector2.RIGHT


func _on_crans_changes(_crans: int) -> void:
	_placer_traceuse()


func _on_bonus_change(_actif: bool) -> void:
	_placer_traceuse()
	_appliquer_taille_particules()


func _facteur_bonus() -> float:
	return FACTEUR_BONUS if joueur.bonus_actif() else 1.0


func _appliquer_taille_particules() -> void:
	for emitter in vomi_container.get_children():
		var mat := emitter.process_material as ParticleProcessMaterial
		if mat != null:
			mat.scale_min = 0.6 * _facteur_bonus()
			mat.scale_max = 1.4 * _facteur_bonus()


## Retourne le sprite, déplace la bouche et réoriente gerbe et traceuse.
func _appliquer_direction() -> void:
	sprite.scale.x = direction_du_lion
	bouche.position.x = BOUCHE_X_DROITE if direction_du_lion > 0 else BOUCHE_X_GAUCHE
	vomi_container.position = bouche.position
	_orienter_emetteurs()
	_placer_traceuse()


func _angle_gerbe(index: int, count: int) -> float:
	var base := ANGLE_GERBE_DEG if direction_du_lion > 0 else 180.0 - ANGLE_GERBE_DEG
	var offset: float = lerp(-ECART_EVENTAIL_DEG / 2, ECART_EVENTAIL_DEG / 2, float(index) / max(count - 1, 1))
	return deg_to_rad(base + offset * direction_du_lion)


## Position, dans le repère du lion, d'une particule tirée à 45° après `t` secondes de vol
## (même physique que le ParticleProcessMaterial). `t = DUREE_GERBE` : le point de chute.
func _point_de_gerbe(t: float) -> Vector2:
	var v := Vector2.from_angle(deg_to_rad(ANGLE_GERBE_DEG)) * VITESSE_GERBE
	var point := Vector2(v.x * t, v.y * t + 0.5 * GRAVITE_GERBE * t * t)
	point.x *= direction_du_lion
	return bouche.position + point


## Traceuse au point de chute ; rayon de peinture selon les crans (16 px au premier, 5 px de
## plus par cran, 46 px au plus) et le bonus. Zones de contact réparties sur la parabole.
func _placer_traceuse() -> void:
	gerbe_traceuse.position = _point_de_gerbe(DUREE_GERBE)
	if traceuse_shape.shape is CircleShape2D:
		var rayon: float = clamp(RAYON_TRACEUSE.x + (joueur.crans - 1) * PAS_RAYON_PAR_CRAN, RAYON_TRACEUSE.x, RAYON_TRACEUSE.y)
		traceuse_shape.shape.radius = rayon * _facteur_bonus()
	for i in range(zones_contact.size()):
		zones_contact[i].position = _point_de_gerbe(DUREE_GERBE * (i + 1) / zones_contact.size())
		(zones_contact[i].get_child(0).shape as CircleShape2D).radius = RAYON_ZONE_CONTACT * _facteur_bonus()


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


## Sur l'hôte : chaque autre lion que touche la gerbe est signalé aux règles, à chaque frame
## de contact (les règles ignorent un lion déjà étourdi ou immunisé).
func _signaler_vomi_sur_les_lions() -> void:
	if not est_en_train_de_vomir or not multiplayer.is_server():
		return
	for zone in zones_contact:
		for corps in zone.get_overlapping_bodies():
			var victime := corps as Lion
			if victime != null and victime != self:
				GameState.regles.lion_touche_par_vomi(victime.joueur, joueur, zone.global_position)


func _orienter_emetteurs() -> void:
	var emitters := vomi_container.get_children()
	for index in range(emitters.size()):
		var mat := emitters[index].process_material as ParticleProcessMaterial
		if mat != null:
			var angle := _angle_gerbe(index, emitters.size())
			mat.direction = Vector3(cos(angle), sin(angle), 0)


## Reconstruit un émetteur par couleur débloquée (en bataille, les trois nuances du joueur,
## débloquées dès le départ : voir `Regles.couleurs_de_depart`).
func mettre_a_jour_degrade_vomi() -> void:
	for child in vomi_container.get_children():
		vomi_container.remove_child(child)
		child.queue_free()

	for couleur in joueur.couleurs_debloquees:
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
		emitter.emitting = est_en_train_de_vomir
		vomi_container.add_child(emitter)

	_orienter_emetteurs()
	_placer_traceuse()


func demarrer_vomi() -> void:
	if joueur.couleurs_debloquees.is_empty():
		return
	est_en_train_de_vomir = true
	gerbe_traceuse.monitoring = true
	for zone in zones_contact:
		zone.monitoring = true
	anim.play("Vomit")
	Audio.demarrer_vomi()
	for emitter in vomi_container.get_children():
		emitter.emitting = true


func arreter_vomi() -> void:
	est_en_train_de_vomir = false
	gerbe_traceuse.monitoring = false
	for zone in zones_contact:
		zone.monitoring = false
	anim.play("Idle")
	Audio.arreter_vomi()
	for emitter in vomi_container.get_children():
		emitter.emitting = false
