class_name Lion
extends CharacterBody2D
## Le lion : son joueur et ses commandes, son déplacement, son vomi ; en bataille, crinière à la
## couleur de son joueur, pseudo au-dessus de la tête, étourdissement. Trois composants (phase 15 bis) :
## - `deplacement` (`DeplacementLion`, logique pure) : vitesse commandée et recul, dont `avancer` fait
##   un pas par tick physique sur l'hôte (la prédiction du lion local, phase 16, rejouera ces pas) ;
## - `pare_chocs` (`PareChocs`, le nœud `PareChocs`) : les auto-tamponneuses (chocs, blocage) ;
## - `gerbe` (`GerbeLion`, le nœud `Gerbe`) : émetteurs, traceuse de peinture au point de chute et
##   zones de contact le long de la parabole.
## Le lion écoute son joueur et répartit ses réactions entre eux ; la présentation (teinte, pseudo,
## étoiles, barbouillage, clignotement, secousse, trot) reste ici.
## Le lion ne décide de rien : sur l'hôte, il signale aux règles les autres lions que touche
## sa gerbe et ceux qu'il percute, comme le font les ennemis et les pastilles.
## En réseau (phase 14), l'hôte simule les lions et écrit à chaque tick l'état de chacun
## (`etat_reseau`, `EtatLion` : position, vitesse commandée, recul, orientation, dernière commande
## appliquée), que son `MultiplayerSynchronizer` (`Synchro`) recopie chez chaque client avec son vomi ;
## ses réactions (étourdissement, crans, gerbe XXL) arrivent par les signaux de son joueur, que la
## manche lui transmet (`Joueur.recevoir_*`). Sur un client (phase 16), un lion distant est affiché
## avec un peu de retard, interpolé entre les états reçus (`_suivre_l_hote`, `InterpolationLion`) ; le
## lion du joueur local est prédit (`prediction`, `PredictionLocale`) : il avance tout de suite avec les
## commandes de ce poste, par le même pas que l'hôte (`avancer`), et se recale sur ses états.

const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
const CENTRE := Vector2(68, 66)  # centre du corps, dans le repère du lion
const FORCE_BARBOUILLAGE := 0.7
const RAYON_ETOILES := Vector2(40, 12)
const VITESSE_ETOILES := 5.0  # radians par seconde
const DUREE_SECOUSSE := 0.25
const AMPLITUDE_SECOUSSE := 6.0
## États de l'hôte gardés au plus entre deux ticks physiques d'un client.
const ETATS_RECUS_MAX := 64

@export var inclinaison_max: float = 0.14  # radians

## Nœud purement visuel (phase 16) : sprite, pseudo et étoiles, jamais le corps physique (`PareChocs`,
## `GerbeTraceuse`, les zones de contact) ni `Gerbe`, qui peint. Seule la prédiction du lion local d'un
## client y pose son décalage d'affichage (`visuel.position`) : le corps (`position`) reste toujours à
## l'endroit prédit, jamais décalé (sinon `PareChocs` verrait l'affichage, pas la prédiction).
@onready var visuel: Node2D = $Visuel
@onready var sprite: Sprite2D = $Visuel/Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var etiquette_pseudo: Label = $Visuel/Pseudo
@onready var etoiles: Node2D = $Visuel/Etoiles
@onready var pare_chocs: PareChocs = $PareChocs
@onready var gerbe: GerbeLion = $Gerbe

var est_en_train_de_vomir := false
## 1 = droite, -1 = gauche. Le setter retourne le sprite et réoriente la gerbe. Sur un client, celle
## d'un lion distant vient de ses états interpolés, celle du lion local de sa prédiction (jamais
## remise à l'ancienne orientation de l'hôte pendant un demi-tour).
var direction_du_lion: int = 1:
	set(valeur):
		if valeur == direction_du_lion:
			return
		direction_du_lion = valeur
		if is_node_ready():
			_appliquer_direction()
## Sur l'hôte, l'état de vomi du lion ; répliqué chez les clients (`Synchro`), où il fait vomir la
## réplique (particules, animation : sa traceuse ne peint pas, voir `GerbeTraceuse`).
var vomi_de_l_hote := false
## État du lion (couleurs, bonus, coups) et source de ses intentions. À fournir avant l'ajout
## à l'arbre : les lions d'une bataille les reçoivent de la scène de jeu (`Main`), en réseau par la
## `spawn_function` de son `MultiplayerSpawner`, qui les crée chez chaque poste par l'index de leur
## joueur (des commandes de ce poste pour le lion du joueur local, manuelles pour les autres, qu'en
## réseau l'hôte remplit de celles que chaque client lui envoie). À défaut (le lion de la scène, en
## solo), le joueur local et ses commandes (celles du pilote en démo).
var joueur: Joueur:
	set(valeur):
		# `is_node_ready()` vaut déjà true pendant `_ready()` lui-même (pas seulement après) :
		# le garde-fou ne bloque donc que le remplacement d'un joueur déjà fixé, pas le repli
		# par défaut fait par `_ready()` ci-dessous.
		if is_node_ready() and joueur != null:
			push_error("Lion.joueur se fixe avant l'ajout à l'arbre")
			return
		joueur = valeur
## Chez l'hôte, un lion de client applique une commande reçue par tick (`Commandes.appliquer_suivante`) ;
## sur un client, le lion local a des commandes manuelles, que remplit sa prédiction.
var commandes: Commandes
## Sur un client, la prédiction du lion du joueur local (phase 16) : donnée par `Main` avant l'ajout à
## l'arbre, ajoutée par `_ready` comme enfant du lion. Nulle ailleurs (hôte, solo, bataille locale, lions
## distants).
var prediction: PredictionLocale
## Vrai sur un client (fixé dans `_ready`) : les états reçus de l'hôte y sont gardés pour le prochain
## tick physique.
var _replique := false
## Sur un client : les états reçus de l'hôte depuis le dernier tick physique (décodés, dans l'ordre
## d'arrivée), rejoués dans ce tick : par l'interpolation d'un lion distant, ou par la prédiction.
var _etats_recus: Array[Dictionary] = []
## Sur un client, l'affichage d'un lion distant.
var _interpolation: InterpolationLion
## Chez l'hôte, l'état du lion écrit à chaque tick physique (`EtatLion.encoder`), que le `Synchro`
## recopie chez chaque client ; sur un client, le setter garde chaque état reçu pour le prochain tick
## physique (jamais appliqué pendant le sondage réseau : `avancer` ne se rejoue que dans une image
## physique).
var etat_reseau := PackedByteArray():
	set(valeur):
		etat_reseau = valeur
		if not _replique:
			return
		var etat := EtatLion.decoder(valeur)
		if etat.is_empty():
			push_warning("Lion : état de l'hôte illisible, ignoré")
		elif _etats_recus.size() < ETATS_RECUS_MAX:
			_etats_recus.append(etat)
## Vitesse commandée et recul du lion (logique pure) : ce que `avancer` fait avancer d'un pas.
var deplacement := DeplacementLion.new()
## Secondes de jeu écoulées pour ce lion (ticks physiques) : trot, étoiles, délai entre deux chocs.
var temps := 0.0
var _clignotement: Tween
var _secousse_restante := 0.0
## Générateur propre au lion pour la secousse du sprite : ne pas consommer la séquence globale
## de `randf_range`, dont dépendent le Spawner et les ennemis.
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_replique = not multiplayer.is_server()
	if _replique and prediction == null:
		_interpolation = InterpolationLion.new(Engine.physics_ticks_per_second)
	if joueur == null:
		joueur = GameState.joueur_local()
	if commandes == null:
		commandes = Commandes.manuelles() if GameState.demo else Commandes.locales()
	gerbe.preparer()
	joueur.couleur_debloquee.connect(_on_couleur_debloquee)
	joueur.bonus_change.connect(_on_bonus_change)
	joueur.touche.connect(_on_lion_touche)
	joueur.crans_changes.connect(_on_crans_changes)
	joueur.etourdi.connect(_on_etourdi)
	joueur.etourdissement_fini.connect(_on_etourdissement_fini)
	_appliquer_direction()
	gerbe.reconstruire()
	appliquer_apparence()
	if prediction != null:
		prediction.name = "Prediction"
		add_child(prediction)


func _physics_process(delta: float) -> void:
	temps += delta
	if not multiplayer.is_server():
		if prediction == null:
			_suivre_l_hote(delta)
		else:
			_animer_deplacement(delta)  # le pas de ce tick est déjà fait, par la prédiction (priorité -10)
		return
	commandes.appliquer_suivante()
	avancer(_direction_voulue(), delta)
	_animer_deplacement(delta)
	gerbe.signaler_vomi_sur_les_lions()
	etat_reseau = EtatLion.encoder(Engine.get_physics_frames(), commandes.numero_applique, position,
		deplacement.vitesse, deplacement.recul, direction_du_lion)


## Un pas de déplacement du lion vers `direction` (longueur 1 au plus), de `delta` secondes : son
## orientation, sa vitesse (commandée, recul, contacts avec les autres lions), `move_and_slide`, puis
## les bords de l'écran. Le seul chemin du déplacement : sur l'hôte (tick physique) et dans la
## prédiction du lion local d'un client (`PredictionLocale`, qui rejoue aussi les pas pas encore
## appliqués par l'hôte).
## Seulement dans une image physique, avec `delta` égal au tick physique : `move_and_slide()` intègre
## avec le delta du moteur, pas celui reçu en argument, donc un appel hors d'une image physique (ex.
## depuis le `poll` multijoueur, où arrivent les états de l'hôte) fausserait la distance parcourue ;
## refusé (faux, le lion ne bouge pas). `pare_chocs.bloquer()` ne rejoue pas des contacts passés, il ne
## lit que l'état physique et les positions actuelles au moment de l'appel.
func avancer(direction: Vector2, delta: float) -> bool:
	if not Engine.is_in_physics_frame():
		push_error("Lion.avancer hors d'une image physique : ce pas est ignoré")
		return false
	if direction.x != 0:
		direction_du_lion = 1 if direction.x > 0 else -1  # le setter réoriente le lion
	velocity = pare_chocs.bloquer(deplacement.vitesse_du_pas(direction, delta))
	move_and_slide()
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
	return true


func _process(delta: float) -> void:
	if _veut_vomir():
		if not est_en_train_de_vomir:
			demarrer_vomi()
	elif est_en_train_de_vomir:
		arreter_vomi()
	if multiplayer.is_server():
		vomi_de_l_hote = est_en_train_de_vomir
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


## Sur un client, un lion distant suit l'hôte : position, vitesse (totale) et orientation viennent de
## ses états, interpolés avec un peu de retard (`InterpolationLion`) ; tant qu'aucun n'est arrivé, il
## garde les siennes. Il ne se déplace pas de lui-même, ne se bloque pas contre les autres lions et ne
## signale rien aux règles. L'animation (inclinaison, trot) tourne sur la vitesse affichée.
func _suivre_l_hote(delta: float) -> void:
	for etat in _etats_recus:
		_interpolation.ajouter(etat.instant, etat.position, etat.vitesse + etat.recul, etat.direction)
	_etats_recus.clear()
	_interpolation.avancer(delta * Engine.physics_ticks_per_second)
	var vu := _interpolation.echantillon()
	if not vu.is_empty():
		position = vu.position
		velocity = vu.vitesse
		direction_du_lion = vu.direction
	deplacement.vitesse = velocity
	_animer_deplacement(delta)


## Sur un client, pour la prédiction : le plus récent des états reçus de l'hôte depuis le dernier appel
## (vide s'il n'en est arrivé aucun).
func dernier_etat_recu() -> Dictionary:
	var dernier := {}
	for etat in _etats_recus:
		if dernier.is_empty() or etat.instant > dernier.instant:
			dernier = etat
	_etats_recus.clear()
	return dernier


## La direction que suit le lion pour la commande `voulue` : aucune avant la fin de l'intro ni pendant
## un étourdissement (commandes ignorées). La même règle chez l'hôte et dans la prédiction d'un client,
## qui rejoue ses commandes avec elle.
func direction_pour(voulue: Vector2) -> Vector2:
	return voulue if GameState.pret and not joueur.est_etourdi() else Vector2.ZERO


func _direction_voulue() -> Vector2:
	return direction_pour(commandes.direction())


## Un lion étourdi ne vomit plus. Sur un client, un lion distant vomit quand le lion de l'hôte vomit ;
## le lion local, prédit, dès l'appui (particules seulement : la peinture reste décidée par l'hôte).
func _veut_vomir() -> bool:
	if not multiplayer.is_server() and prediction == null:
		return vomi_de_l_hote
	return GameState.pret and not joueur.est_etourdi() and commandes.vomir()


func demarrer_vomi() -> void:
	if joueur.couleurs_debloquees.is_empty():
		return
	est_en_train_de_vomir = true
	gerbe.demarrer()
	anim.play("Vomit")
	if est_local():
		Audio.demarrer_vomi()


## La boucle du vomi (une seule, dans `Audio`) n'est qu'au lion de ce poste : un autre lion qui arrête
## de vomir ne la coupe plus (phase 17 bis).
func arreter_vomi() -> void:
	est_en_train_de_vomir = false
	gerbe.arreter()
	anim.play("Idle")
	if est_local():
		Audio.arreter_vomi()


## Vrai si ce lion est celui du joueur de ce poste (en solo, le seul lion).
func est_local() -> bool:
	return joueur == GameState.joueur_local()


## Crinière à la couleur du joueur et pseudo au-dessus de la tête. Lu une fois dans `_ready` ; à
## rappeler si la couleur ou le pseudo du joueur change ensuite (jamais en jeu : la table des joueurs
## d'une bataille est posée avant la scène de jeu, et le salon n'a pas de lion).
func appliquer_apparence() -> void:
	if not is_node_ready():
		return  # sprite et étiquette n'existent pas encore : `_ready` l'appliquera
	_appliquer_teinte()
	etiquette_pseudo.text = joueur.pseudo
	etiquette_pseudo.add_theme_color_override("font_color", joueur.couleur)
	etiquette_pseudo.visible = joueur.a_une_couleur() and not joueur.pseudo.is_empty()


## Petite secousse du sprite, au choc avec un autre lion (`PareChocs`) ; pas de secousse d'écran.
func secouer() -> void:
	_secousse_restante = DUREE_SECOUSSE


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


## Retourne le sprite et réoriente la gerbe (bouche, émetteurs, traceuse, zones de contact).
func _appliquer_direction() -> void:
	sprite.scale.x = direction_du_lion
	gerbe.orienter()


## Penche le lion dans le sens de la course et le fait trottiner.
func _animer_deplacement(delta: float) -> void:
	var cible: float = (deplacement.vitesse.x / deplacement.speed) * inclinaison_max * signf(sprite.scale.x)
	sprite.rotation = lerp(sprite.rotation, cible, min(1.0, 10.0 * delta))
	var en_mouvement := deplacement.vitesse.length() > deplacement.speed * 0.2
	var bob := sin(temps * 14.0) * 3.0 if en_mouvement else 0.0
	sprite.position.y = lerp(sprite.position.y, 67.0 + bob, min(1.0, 12.0 * delta))


func _on_couleur_debloquee(_couleur: Color) -> void:
	gerbe.reconstruire()


func _on_crans_changes(_crans: int) -> void:
	gerbe.placer_traceuse()


func _on_bonus_change(_actif: bool) -> void:
	gerbe.placer_traceuse()
	gerbe.appliquer_taille_particules()


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
	deplacement.arreter()
	_reculer(origine)
	_barbouiller(barbouillage)
	etoiles.visible = true
	_tourner_etoiles()
	Audio.jouer_etourdi(est_local())


## Fin de l'étourdissement : barbouillage et étoiles s'en vont, l'immunité clignote.
func _on_etourdissement_fini() -> void:
	_barbouiller(Color.TRANSPARENT)
	etoiles.visible = false
	_clignoter(joueur.invulnerable_restant)


func _reculer(origine: Vector2) -> void:
	deplacement.repousser(global_position + CENTRE, origine, direction_du_lion)


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


## Vrai si la tête porte encore un barbouillage visible (couleur d'agresseur appliquée).
## `get_shader_parameter` renvoie `null` tant que `_barbouiller` ne l'a jamais fixé.
func _barbouillage_actif() -> bool:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return false
	var force: Variant = mat.get_shader_parameter("barbouillage_force")
	return force != null and force > 0.0


func _tourner_etoiles() -> void:
	var nb := etoiles.get_child_count()
	for i in range(nb):
		var angle := temps * VITESSE_ETOILES + TAU * i / nb
		etoiles.get_child(i).position = Vector2(cos(angle) * RAYON_ETOILES.x, sin(angle) * RAYON_ETOILES.y)
