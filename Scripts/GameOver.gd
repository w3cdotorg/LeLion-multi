extends CanvasLayer
## Bilan de fin de partie : lignes animées (compteurs), comparaison au record, badge
## « Nouveau record », puis Niveau suivant / Rejouer / Menu. Une touche saute l'animation.

const COULEUR_VICTOIRE := Color(1.0, 0.85, 0.2)
const COULEUR_DEFAITE := Color(1.0, 0.35, 0.35)
const COULEUR_MIEUX := Color(0.45, 0.95, 0.5)
const COULEUR_MOINS_BIEN := Color(1.0, 0.55, 0.45)
const COULEUR_NOM := Color(1, 1, 1, 0.7)
const SCENE_TITRE := "res://Scenes/Titre.tscn"
const TEXTURE_CONFETTI := preload("res://Assets/Sprites/circle_white.png")
const DELAI_LIGNE := 0.3
const DUREE_COMPTEUR := 0.45
const COMPTE_CONTINUE := 9

@onready var titre: Label = $Centre/Colonne/Titre
@onready var sous_titre: Label = $Centre/Colonne/SousTitre
@onready var compte: Label = $Centre/Colonne/Compte
@onready var aide_continue: Label = $Centre/Colonne/AideContinue
@onready var stats: GridContainer = $Centre/Colonne/Stats
@onready var boutons: HBoxContainer = $Centre/Colonne/Boutons
@onready var bouton_suivant: Button = $Centre/Colonne/Boutons/Suivant
@onready var bouton_rejouer: Button = $Centre/Colonne/Boutons/Rejouer

var _tween: Tween
var _animation_finie := false
var _lignes: Array[Dictionary] = []
var phase_continue := false
var _compte_restant := COMPTE_CONTINUE
var _victoire := false
var _progression := 0.0
var _temps := 0.0


## Défaite : d'abord « CONTINUE ? » avec compte à rebours, puis le bilan.
func afficher(victoire: bool, progression: float, temps: float) -> void:
	_victoire = victoire
	_progression = progression
	_temps = temps
	if victoire:
		_afficher_bilan()
	else:
		_demarrer_continue()


func _demarrer_continue() -> void:
	phase_continue = true
	titre.text = tr("CONTINUE")
	titre.add_theme_color_override("font_color", COULEUR_DEFAITE)
	compte.visible = true
	aide_continue.visible = true
	stats.visible = false
	boutons.visible = false
	sous_titre.visible = false
	_compte_restant = COMPTE_CONTINUE
	_afficher_compte()
	_tween = create_tween().set_loops(COMPTE_CONTINUE)
	_tween.tween_interval(1.0)
	_tween.tween_callback(_decrementer)


func _afficher_compte() -> void:
	compte.text = str(_compte_restant)
	compte.pivot_offset = compte.size / 2.0
	compte.scale = Vector2(1.3, 1.3)
	create_tween().tween_property(compte, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _decrementer() -> void:
	_compte_restant -= 1
	if _compte_restant <= 0:
		_fin_continue()
	else:
		_afficher_compte()


## Le compte est écoulé : on montre le bilan classique.
func _fin_continue() -> void:
	if not phase_continue:
		return
	phase_continue = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	compte.visible = false
	aide_continue.visible = false
	stats.visible = true
	boutons.visible = true
	_afficher_bilan()


func _afficher_bilan() -> void:
	var victoire := _victoire
	var progression := _progression
	var temps := _temps
	var fin_arcade := victoire and GameState.arcade_termine()
	titre.text = tr("ARCADE_TERMINE") if fin_arcade else (tr("VICTOIRE") if victoire else tr("GAME_OVER"))
	titre.add_theme_color_override("font_color", COULEUR_VICTOIRE if victoire else COULEUR_DEFAITE)

	var pourcent := int(round(progression * 100))
	var record_precedent := -1.0
	var rang := -1
	if victoire:
		record_precedent = Scores.meilleur_temps(GameState.cle_score())
		rang = Scores.enregistrer(GameState.cle_score(), temps)
		_lancer_confettis()
	var rang_arcade := -1
	if fin_arcade:
		rang_arcade = Scores.enregistrer("arcade", GameState.temps_arcade)
	sous_titre.text = tr("NOUVEAU_RECORD") if (rang == 0 or rang_arcade == 0) else ""
	sous_titre.visible = rang == 0 or rang_arcade == 0
	sous_titre.modulate.a = 0.0

	_ajouter_ligne(tr("STAT_PEINT"), pourcent, "%d %%")
	var commentaire_temps := ""
	var couleur_temps := Color.WHITE
	if victoire:
		if record_precedent < 0.0:
			commentaire_temps = tr("PREMIER_TEMPS")
		else:
			var ecart := temps - record_precedent
			commentaire_temps = ("−" if ecart < 0.0 else "+") + GameState.formater_temps(abs(ecart))
			couleur_temps = COULEUR_MIEUX if ecart < 0.0 else COULEUR_MOINS_BIEN
	_ajouter_ligne(tr("STAT_TEMPS"), int(temps), "temps", commentaire_temps, couleur_temps)
	var max_vies: int = GameState.difficulte().vies
	var joueur := GameState.joueur_local()
	var sans_egratignure := victoire and joueur.coups_recus == 0
	_ajouter_ligne(tr("STAT_COEURS_PERDUS"), joueur.coups_recus, "%d / " + str(max_vies),
		tr("SANS_EGRATIGNURE") if sans_egratignure else "", COULEUR_MIEUX)
	_ajouter_ligne(tr("STAT_COULEURS"), joueur.couleurs_debloquees.size(), "%d / " + str(GameState.nb_couleurs_total()))
	if victoire and record_precedent >= 0.0:
		_ajouter_ligne(tr("STAT_RECORD_PRECEDENT"), int(record_precedent), "temps")
	if fin_arcade:
		_ajouter_ligne(tr("STAT_TEMPS_TOTAL"), int(GameState.temps_arcade), "temps")

	if GameState.mode_arcade:
		bouton_suivant.visible = victoire and GameState.etape_arcade_suivante_existe()
		bouton_rejouer.visible = not fin_arcade
	else:
		bouton_suivant.visible = victoire and GameState.niveau_suivant_existe()
	boutons.modulate.a = 0.0
	_animer()


## Une ligne = nom, valeur (compteur animé), commentaire optionnel.
## `format` : chaîne avec %d, ou "temps" pour mm:ss.
func _ajouter_ligne(nom: String, valeur: int, format: String, commentaire := "", couleur_commentaire := Color.WHITE) -> void:
	var label_nom := Label.new()
	label_nom.text = nom
	label_nom.add_theme_font_size_override("font_size", 32)
	label_nom.add_theme_color_override("font_color", COULEUR_NOM)
	label_nom.modulate.a = 0.0
	var label_valeur := Label.new()
	label_valeur.add_theme_font_size_override("font_size", 36)
	label_valeur.custom_minimum_size = Vector2(170, 0)
	label_valeur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label_valeur.modulate.a = 0.0
	var label_commentaire := Label.new()
	label_commentaire.text = commentaire
	label_commentaire.add_theme_font_size_override("font_size", 30)
	label_commentaire.add_theme_color_override("font_color", couleur_commentaire)
	label_commentaire.custom_minimum_size = Vector2(240, 0)
	label_commentaire.modulate.a = 0.0
	stats.add_child(label_nom)
	stats.add_child(label_valeur)
	stats.add_child(label_commentaire)
	var ligne := {"nom": label_nom, "valeur": label_valeur, "commentaire": label_commentaire,
		"cible": valeur, "format": format}
	_lignes.append(ligne)
	_ecrire_valeur(ligne, 0)


func _ecrire_valeur(ligne: Dictionary, valeur: int) -> void:
	var format: String = ligne.format
	ligne.valeur.text = GameState.formater_temps(valeur) if format == "temps" else format % valeur


func _animer() -> void:
	_tween = create_tween()
	for ligne in _lignes:
		_tween.tween_property(ligne.nom, "modulate:a", 1.0, 0.15)
		_tween.parallel().tween_property(ligne.valeur, "modulate:a", 1.0, 0.15)
		_tween.parallel().tween_method(func(v: float) -> void: _ecrire_valeur(ligne, int(round(v))),
			0.0, float(ligne.cible), DUREE_COMPTEUR)
		_tween.parallel().tween_property(ligne.commentaire, "modulate:a", 1.0, 0.3).set_delay(DUREE_COMPTEUR * 0.6)
		_tween.tween_interval(DELAI_LIGNE - 0.15)
	if sous_titre.visible:
		_tween.tween_property(sous_titre, "modulate:a", 1.0, 0.25)
		_tween.parallel().tween_property(sous_titre, "scale", Vector2.ONE, 0.35).from(Vector2(1.6, 1.6)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		sous_titre.pivot_offset = sous_titre.size / 2.0
	_tween.tween_property(boutons, "modulate:a", 1.0, 0.25)
	_tween.tween_callback(_terminer_animation)


## Affiche tout d'un coup et donne le focus aux boutons.
func _terminer_animation() -> void:
	if _animation_finie:
		return
	_animation_finie = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for ligne in _lignes:
		ligne.nom.modulate.a = 1.0
		ligne.valeur.modulate.a = 1.0
		ligne.commentaire.modulate.a = 1.0
		_ecrire_valeur(ligne, ligne.cible)
	sous_titre.modulate.a = 1.0
	sous_titre.scale = Vector2.ONE
	boutons.modulate.a = 1.0
	if bouton_suivant.visible:
		bouton_suivant.grab_focus()
	elif bouton_rejouer.visible:
		bouton_rejouer.grab_focus()
	else:
		$Centre/Colonne/Boutons/Menu.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	var valide: bool = event.is_action_pressed("vomir") or event.is_action_pressed("ui_accept") \
		or (event is InputEventScreenTouch and event.pressed)
	if not valide:
		return
	if phase_continue:
		Audio.jouer("pickup")
		_relancer()
		get_viewport().set_input_as_handled()
	elif not _animation_finie:
		_terminer_animation()
		get_viewport().set_input_as_handled()


func _on_suivant_pressed() -> void:
	if GameState.mode_arcade:
		GameState.passer_etape_arcade()
	else:
		GameState.passer_au_niveau_suivant()
		Scores.definir_preference("niveau", GameState.niveau_courant)
	_relancer()


func _on_rejouer_pressed() -> void:
	_relancer()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_TITRE)


func _relancer() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Explosion de confettis arc-en-ciel depuis le bas de l'écran.
func _lancer_confettis() -> void:
	var gradient := Gradient.new()
	var couleurs := GameState.COULEURS_ARC_EN_CIEL
	for i in range(couleurs.size()):
		if i < 2:
			gradient.set_color(i, couleurs[i])
		else:
			gradient.add_point(float(i) / (couleurs.size() - 1), couleurs[i])
	gradient.set_offset(1, 1.0 / (couleurs.size() - 1))
	var rampe := GradientTexture1D.new()
	rampe.gradient = gradient

	var materiau := ParticleProcessMaterial.new()
	materiau.color_initial_ramp = rampe
	materiau.direction = Vector3(0, -1, 0)
	materiau.spread = 55.0
	materiau.initial_velocity_min = 700.0
	materiau.initial_velocity_max = 1100.0
	materiau.gravity = Vector3(0, 900, 0)
	materiau.scale_min = 1.5
	materiau.scale_max = 3.0
	materiau.angular_velocity_min = -360.0
	materiau.angular_velocity_max = 360.0

	var taille := get_viewport().get_visible_rect().size
	for x in [taille.x * 0.25, taille.x * 0.5, taille.x * 0.75]:
		var confettis := GPUParticles2D.new()
		confettis.texture = TEXTURE_CONFETTI
		confettis.process_material = materiau
		confettis.amount = 160
		confettis.lifetime = 2.5
		confettis.one_shot = true
		confettis.explosiveness = 0.9
		confettis.position = Vector2(x, taille.y + 10)
		add_child(confettis)
		move_child(confettis, 1)  # au-dessus du fond assombri, sous le texte
		confettis.emitting = true
