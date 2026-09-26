extends Control
## Écran Réseau (spec §4, §9) : pseudo mémorisé, Héberger, liste des parties entendues
## (`Decouverte`), Rejoindre par IP en secours, messages des refus et des échecs. En 16:9, comme le
## salon (spec §7) ; le titre remet l'écran du solo au retour.
##
## Quatre états : ACCUEIL (tout est permis, la liste écoute les balises), CONNEXION (en attente de
## l'hôte), HEBERGE et INSCRIT. Tant que le salon n'existe pas (phase 13), une partie hébergée ou
## rejointe attend ici : l'hôte voit ses joueurs arriver, le client son inscription. Retour (ou
## Échap, B à la manette) annule l'état en cours, puis ramène au titre.

enum Etat { ACCUEIL, CONNEXION, HEBERGE, INSCRIT }

const SCENE_TITRE := "res://Scenes/Titre.tscn"
const COULEUR_INFO := Color(1, 1, 1, 0.85)
# M3 (revue finale 12 bis) : le remplissage passe en blanc pour le contraste (le contour salmon
# reste l'accent qui distingue un refus/échec d'une simple information).
const COULEUR_ERREUR := Color(1, 1, 1, 0.95)
const COULEUR_CONTOUR_INFO := Color(0.1, 0.05, 0.12, 0.85)
const COULEUR_CONTOUR_ERREUR := Color(0.85, 0.22, 0.14, 0.9)
const TAILLE_BOUTON_PARTIE := Vector2(1100, 64)

## Port de jeu d'`heberger()` et de la saisie par IP (modifiable par les tests).
var port_jeu: int = Reseau.PORT
var etat := Etat.ACCUEIL
## Un bouton par partie entendue, par « ip:port » (ou « 127.0.0.1:port » pour une partie hébergée
## par ce poste, I2), dans l'ordre de la liste (mis à jour en place : le bouton qui a le focus le
## garde quand sa partie change).
var boutons_parties: Dictionary[String, Button] = {}
## La dernière fiche affichée par clé (I2 : fusionnée via `fusionner_parties_locales`), pour que
## `rejoindre_partie` retrouve l'adresse réellement jointe (127.0.0.1 pour ce poste lui-même).
var _parties_affichees: Dictionary[String, Dictionary] = {}
## Le contrôle qui a lancé la tentative en cours (une ligne de partie ou le champ IP), pour lui
## rendre le focus après un refus ou un échec (M10, revue finale 12 bis) ; repli sur Héberger s'il
## n'existe plus (la partie a disparu de la liste pendant la tentative).
var _dernier_controle: Control = null

@onready var champ_pseudo: LineEdit = $Centre/Colonne/RangeePseudo/Pseudo
@onready var bouton_heberger: Button = $Centre/Colonne/Heberger
@onready var titre_parties: Label = $Centre/Colonne/TitreParties
@onready var cadre_parties: PanelContainer = $Centre/Colonne/Cadre
@onready var liste: VBoxContainer = $Centre/Colonne/Cadre/Defilement/Parties
@onready var indice: Label = $Centre/Colonne/Cadre/Defilement/Parties/Indice
@onready var champ_ip: LineEdit = $Centre/Colonne/RangeeIP/IP
@onready var bouton_rejoindre: Button = $Centre/Colonne/RangeeIP/Rejoindre
@onready var message: Label = $Centre/Colonne/Message
@onready var bouton_retour: Button = $BoutonRetour

## Le message affiché, gardé en clé et arguments pour être retraduit au changement de langue.
var _message := {"cle": "", "arguments": [], "erreur": false}


func _ready() -> void:
	get_tree().root.content_scale_size = ReglesBataille.TAILLE_ECRAN
	champ_pseudo.max_length = Reseau.PSEUDO_MAX
	champ_pseudo.text = Reseau.pseudo_valide(str(Scores.preference("pseudo", "")))
	Decouverte.parties_changees.connect(_afficher_parties)
	Reseau.inscrit.connect(_sur_inscription)
	Reseau.refuse.connect(_sur_refus)
	Reseau.connexion_echouee.connect(_sur_connexion_echouee)
	Reseau.hote_perdu.connect(_sur_hote_perdu)
	Reseau.joueur_arrive.connect(_sur_joueurs_changes)
	Reseau.joueur_parti.connect(_sur_joueurs_changes)
	Parametres.langue_changee.connect(_sur_langue_changee)
	_changer_etat(Etat.ACCUEIL)


## Les autoloads survivent à l'écran : ne rien leur laisser (écoute, connexions). Ne quitte pas le
## réseau : le salon (phase 13) prendra la suite d'une partie hébergée ou rejointe.
func _exit_tree() -> void:
	Decouverte.arreter_ecoute()
	Decouverte.parties_changees.disconnect(_afficher_parties)
	Reseau.inscrit.disconnect(_sur_inscription)
	Reseau.refuse.disconnect(_sur_refus)
	Reseau.connexion_echouee.disconnect(_sur_connexion_echouee)
	Reseau.hote_perdu.disconnect(_sur_hote_perdu)
	Reseau.joueur_arrive.disconnect(_sur_joueurs_changes)
	Reseau.joueur_parti.disconnect(_sur_joueurs_changes)
	Parametres.langue_changee.disconnect(_sur_langue_changee)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# M1 (revue finale 12 bis) : Échap dans un LineEdit en édition n'en sort pas de lui-même (le
	# champ ne marque pas l'entrée traitée), donc ce gestionnaire renvoyait déjà à l'écran d'avant en
	# même temps qu'un simple abandon de saisie. On sort d'abord le champ de l'édition ; un second
	# Échap ramènera bien à l'accueil ou au titre.
	var proprietaire := get_viewport().gui_get_focus_owner()
	if proprietaire is LineEdit and (proprietaire as LineEdit).is_editing():
		(proprietaire as LineEdit).unedit()
		get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	retour()


## Héberge une partie sur `port_jeu` avec le pseudo saisi.
func heberger() -> void:
	if etat != Etat.ACCUEIL:
		return
	_appliquer_pseudo()
	var erreur := Reseau.heberger(port_jeu)
	if erreur == ERR_CANT_CREATE:
		_afficher_message("RESEAU_PORT_OCCUPE", [port_jeu], true)
	elif erreur != OK:
		_afficher_message("RESEAU_HEBERGER_IMPOSSIBLE", [erreur], true)
	else:
		_changer_etat(Etat.HEBERGE)
		_afficher_hebergement()


## Rejoint la partie de la liste `cle` (« ip:port », ou « 127.0.0.1:port » pour une partie hébergée
## par ce poste, I2), si elle est encore là et joignable.
func rejoindre_partie(cle: String) -> void:
	var partie: Dictionary = _parties_affichees.get(cle, {})
	if etat == Etat.ACCUEIL and not partie.is_empty() and _raison_injoignable(partie).is_empty():
		_dernier_controle = boutons_parties.get(cle)  # M10 : lui rendre le focus après un échec
		_rejoindre(partie.ip, partie.port)


## Rejoint l'adresse saisie : une IPv4 seulement (un nom se résoudrait en bloquant le jeu).
func rejoindre_par_ip() -> void:
	if etat != Etat.ACCUEIL:
		return
	var adresse := Decouverte.adresse_ipv4(champ_ip.text)
	if adresse.is_empty():
		_afficher_message("RESEAU_IP_INVALIDE", [], true)
		champ_ip.grab_focus()
		return
	champ_ip.text = adresse
	_dernier_controle = champ_ip  # M10 : lui rendre le focus après un échec
	_rejoindre(adresse, port_jeu)


## Hors de l'accueil : annule (quitte le réseau, revient à l'accueil). À l'accueil : retour au titre
## (qui quitte aussi le réseau). `changer_scene` à faux pour les tests.
func retour(changer_scene := true) -> void:
	Reseau.quitter()
	if etat != Etat.ACCUEIL:
		_changer_etat(Etat.ACCUEIL)
		_afficher_message("", [], false)
		return
	_appliquer_pseudo()
	if changer_scene:
		get_tree().change_scene_to_file(SCENE_TITRE)


func _rejoindre(adresse: String, port: int) -> void:
	_appliquer_pseudo()
	if Reseau.rejoindre(adresse, port) != OK:
		_afficher_message("RESEAU_ECHEC_CONNEXION", [], true)
		return
	_changer_etat(Etat.CONNEXION)
	_afficher_message("RESEAU_CONNEXION", [adresse], false)


## Le pseudo saisi, nettoyé comme l'hôte le nettoiera, devient celui de ce poste et est mémorisé.
func _appliquer_pseudo() -> void:
	var pseudo := Reseau.pseudo_valide(champ_pseudo.text)
	champ_pseudo.text = pseudo
	Reseau.pseudo = pseudo
	Scores.definir_preference("pseudo", pseudo)


func _changer_etat(nouvel_etat: Etat) -> void:
	etat = nouvel_etat
	var accueil := etat == Etat.ACCUEIL
	champ_pseudo.editable = accueil
	champ_ip.editable = accueil
	bouton_heberger.disabled = not accueil
	bouton_rejoindre.disabled = not accueil
	titre_parties.visible = accueil
	cadre_parties.visible = accueil
	# On n'écoute qu'à l'accueil : la liste est cachée ailleurs, et un hôte ne doit pas s'y voir.
	if accueil and not Decouverte.ecoute_active():
		Decouverte.ecouter()
	elif not accueil:
		Decouverte.arreter_ecoute()
	_afficher_parties()
	if accueil:
		bouton_heberger.grab_focus()
	else:
		bouton_retour.grab_focus()


## Fusionne dans `parties` les entrées dont l'adresse source est une adresse locale de ce poste
## (I2, revue finale de la phase 12 bis) : une partie que ce poste héberge apparaît une fois par
## interface (une par diffusion dirigée, `Decouverte.destinations_balise`), avec des adresses que
## les autres joueurs ne peuvent pas tous joindre. Une seule ligne par port de jeu, jointe via
## 127.0.0.1 (l'adresse à laquelle ce poste se rejoint toujours lui-même). Fonction statique pure,
## testée sans dépendre de l'OS ni d'une vraie liste. Ne distingue pas deux hôtes différents portant
## le même port sur des postes différents (une balise sans identifiant de session, feuille de
## route : phase 13 au plus tard, un id de session par balise).
static func fusionner_parties_locales(parties: Array[Dictionary], adresses_locales: PackedStringArray) -> Dictionary[String, Dictionary]:
	var vues: Dictionary[String, Dictionary] = {}
	for partie in parties:
		var locale := adresses_locales.has(partie.ip)
		var cle := "127.0.0.1:%d" % partie.port if locale else "%s:%d" % [partie.ip, partie.port]
		if vues.has(cle):
			continue
		if locale and partie.ip != "127.0.0.1":
			var copie := partie.duplicate()
			copie["ip"] = "127.0.0.1"
			vues[cle] = copie
		else:
			vues[cle] = partie
	return vues


## Met la liste à jour en place : un bouton par partie, dans l'ordre de `Decouverte.parties_triees`
## (fusionnée, I2).
func _afficher_parties() -> void:
	var parties: Array[Dictionary] = []
	if etat == Etat.ACCUEIL:
		parties = Decouverte.parties_triees()
	_parties_affichees = fusionner_parties_locales(parties, IP.get_local_addresses())
	var cles: Array[String] = []
	for cle: String in _parties_affichees:
		var partie: Dictionary = _parties_affichees[cle]
		cles.append(cle)
		var bouton: Button = boutons_parties.get(cle)
		if bouton == null:
			bouton = Button.new()
			bouton.custom_minimum_size = TAILLE_BOUTON_PARTIE
			bouton.add_theme_font_size_override("font_size", 28)
			# I3 (revue finale 12 bis) : un anneau de focus qui ne dépasse pas du bouton (le
			# ScrollContainer qui le contient clippe tout ce qui dépasse), plus un fond éclairci pour
			# qu'un joueur au clavier ou à la manette voie clairement quelle ligne il va rejoindre.
			bouton.add_theme_stylebox_override("focus", _style_focus_partie())
			bouton.focus_entered.connect(func() -> void: bouton.modulate = Color(1.18, 1.18, 1.18))
			bouton.focus_exited.connect(func() -> void: bouton.modulate = Color(1, 1, 1))
			bouton.pressed.connect(rejoindre_partie.bind(cle))
			liste.add_child(bouton)
			boutons_parties[cle] = bouton
		bouton.text = _texte_partie(partie)
		bouton.disabled = not _raison_injoignable(partie).is_empty()
		liste.move_child(bouton, cles.size())  # après l'indice, premier enfant de la liste
	var focus_perdu := false
	for cle: String in boutons_parties.keys():
		if not cles.has(cle):
			var bouton: Button = boutons_parties[cle]
			focus_perdu = focus_perdu or bouton.has_focus()
			boutons_parties.erase(cle)
			liste.remove_child(bouton)
			bouton.queue_free()
	if focus_perdu:
		bouton_heberger.grab_focus()
	indice.visible = cles.is_empty()
	indice.text = tr("RESEAU_AUCUNE_PARTIE") if Decouverte.ecoute_active() else tr("RESEAU_ECOUTE_IMPOSSIBLE") % Decouverte.port_balise
	_chainer_focus(cles)


## Haut et bas au clavier ou à la manette : Héberger, les parties dans l'ordre, puis l'adresse IP.
func _chainer_focus(cles: Array[String]) -> void:
	var chaine: Array[Control] = [bouton_heberger]
	for cle in cles:
		chaine.append(boutons_parties[cle])
	chaine.append(champ_ip)
	for i in range(chaine.size() - 1):
		chaine[i].focus_neighbor_bottom = chaine[i].get_path_to(chaine[i + 1])
		chaine[i + 1].focus_neighbor_top = chaine[i + 1].get_path_to(chaine[i])
	bouton_rejoindre.focus_neighbor_top = bouton_rejoindre.get_path_to(chaine[chaine.size() - 2])


## Le style de focus des lignes de partie (I3, revue finale 12 bis) : une bordure intérieure sans
## marge d'expansion, pour ne pas se faire clipper par le `ScrollContainer` qui contient la liste.
static func _style_focus_partie() -> StyleBoxFlat:
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Styles.JAUNE
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(6)
	return focus


func _texte_partie(partie: Dictionary) -> String:
	var niveau: String = tr(GameState.NIVEAUX[partie.niveau].nom)
	var texte: String = tr("RESEAU_PARTIE") % [partie.pseudo, partie.nb_joueurs, partie.places, niveau]
	var raison := _raison_injoignable(partie)
	return texte if raison.is_empty() else "%s · %s" % [texte, raison]


## Pourquoi l'hôte refuserait ce poste, dans l'ordre de ses refus (version, manche, places) ; vide
## si la partie est joignable.
func _raison_injoignable(partie: Dictionary) -> String:
	if partie.version != Reseau.version:
		return tr("RESEAU_PARTIE_VERSION") % partie.version
	if partie.manche_en_cours:
		return tr("RESEAU_PARTIE_MANCHE")
	if partie.nb_joueurs >= partie.places:
		return tr("RESEAU_PARTIE_PLEINE")
	return ""


func _afficher_hebergement() -> void:
	# I1 (revue finale 12 bis) : triées par interface (physique d'abord), pas seulement par plage
	# IPv4, sans quoi une carte virtuelle (bridge, vEthernet, VMware…) pouvait passer devant le Wi-Fi.
	var adresses := ", ".join(Decouverte.adresses_hote(IP.get_local_interfaces()))
	_afficher_message("RESEAU_HEBERGE", [Reseau.inscrits.size(), Reseau.places, adresses if not adresses.is_empty() else "?"], false)


func _afficher_message(cle: String, arguments: Array, erreur: bool) -> void:
	_message = {"cle": cle, "arguments": arguments, "erreur": erreur}
	_rendre_message()


func _rendre_message() -> void:
	var cle: String = _message.cle
	var arguments: Array = _message.arguments
	message.text = "" if cle.is_empty() else (tr(cle) % arguments if not arguments.is_empty() else tr(cle))
	# M3 (revue finale 12 bis) : un remplissage blanc porte le contraste, le contour reste l'accent
	# qui distingue un refus/échec (salmon) d'une simple information (sombre, comme avant).
	message.add_theme_color_override("font_color", COULEUR_ERREUR if _message.erreur else COULEUR_INFO)
	message.add_theme_color_override("font_outline_color", COULEUR_CONTOUR_ERREUR if _message.erreur else COULEUR_CONTOUR_INFO)


## Rend le focus au contrôle qui a lancé la tentative en cours (M10), ou le laisse sur Héberger
## (déjà focusé par `_changer_etat`) si ce contrôle n'existe plus ou n'est plus dans l'arbre (la
## partie visée a disparu de la liste pendant la tentative).
func _reprendre_focus_echec() -> void:
	if is_instance_valid(_dernier_controle) and _dernier_controle.is_inside_tree():
		_dernier_controle.grab_focus()


func _sur_inscription(index: int, _couleur: Color) -> void:
	if etat == Etat.CONNEXION:
		# La tentative a réussi : un « hôte perdu » bien plus tard (M10) ne doit pas rendre le focus
		# à un champ IP ou une ligne utilisés il y a longtemps, mais à Héberger comme d'habitude.
		_dernier_controle = null
		_changer_etat(Etat.INSCRIT)
		_afficher_message("RESEAU_INSCRIT", [index + 1], false)


## `Reseau` a déjà remis ce poste hors réseau quand ses signaux d'échec partent.
func _sur_refus(raison: String, version_hote: String) -> void:
	var connues := [Reseau.REFUS_VERSION, Reseau.REFUS_PLEIN, Reseau.REFUS_MANCHE, Reseau.REFUS_DEMANDE]
	var cle := raison if connues.has(raison) else Reseau.REFUS_DEMANDE
	_changer_etat(Etat.ACCUEIL)
	_reprendre_focus_echec()
	_afficher_message(cle, [version_hote] if cle == Reseau.REFUS_VERSION else [], true)


func _sur_connexion_echouee() -> void:
	_changer_etat(Etat.ACCUEIL)
	_reprendre_focus_echec()
	_afficher_message("RESEAU_ECHEC_CONNEXION", [], true)


func _sur_hote_perdu() -> void:
	_changer_etat(Etat.ACCUEIL)
	_reprendre_focus_echec()
	_afficher_message("RESEAU_HOTE_PERDU", [], true)


func _sur_joueurs_changes(_id: int) -> void:
	if etat == Etat.HEBERGE:
		_afficher_hebergement()


func _sur_langue_changee(_langue: String) -> void:
	_rendre_message()
	_afficher_parties()
