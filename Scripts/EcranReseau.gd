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
const COULEUR_ERREUR := Color(1.0, 0.72, 0.64)
const TAILLE_BOUTON_PARTIE := Vector2(1100, 64)

## Port de jeu d'`heberger()` et de la saisie par IP (modifiable par les tests).
var port_jeu: int = Reseau.PORT
var etat := Etat.ACCUEIL
## Un bouton par partie entendue, par « ip:port », dans l'ordre de la liste (mis à jour en place :
## le bouton qui a le focus le garde quand sa partie change).
var boutons_parties: Dictionary[String, Button] = {}

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
	if event.is_action_pressed("ui_cancel"):
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


## Rejoint la partie de la liste `cle` (« ip:port »), si elle est encore là et joignable.
func rejoindre_partie(cle: String) -> void:
	var partie: Dictionary = Decouverte.parties.get(cle, {})
	if etat == Etat.ACCUEIL and not partie.is_empty() and _raison_injoignable(partie).is_empty():
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


## Met la liste à jour en place : un bouton par partie, dans l'ordre de `Decouverte.parties_triees`.
func _afficher_parties() -> void:
	var parties: Array[Dictionary] = []
	if etat == Etat.ACCUEIL:
		parties = Decouverte.parties_triees()
	var cles: Array[String] = []
	for partie in parties:
		var cle := "%s:%d" % [partie.ip, partie.port]
		cles.append(cle)
		var bouton: Button = boutons_parties.get(cle)
		if bouton == null:
			bouton = Button.new()
			bouton.custom_minimum_size = TAILLE_BOUTON_PARTIE
			bouton.add_theme_font_size_override("font_size", 28)
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
	var adresses := ", ".join(Decouverte.adresses_privees(IP.get_local_addresses()))
	_afficher_message("RESEAU_HEBERGE", [Reseau.inscrits.size(), Reseau.places, adresses if not adresses.is_empty() else "?"], false)


func _afficher_message(cle: String, arguments: Array, erreur: bool) -> void:
	_message = {"cle": cle, "arguments": arguments, "erreur": erreur}
	_rendre_message()


func _rendre_message() -> void:
	var cle: String = _message.cle
	var arguments: Array = _message.arguments
	message.text = "" if cle.is_empty() else (tr(cle) % arguments if not arguments.is_empty() else tr(cle))
	message.add_theme_color_override("font_color", COULEUR_ERREUR if _message.erreur else COULEUR_INFO)


func _sur_inscription(index: int, _couleur: Color) -> void:
	if etat == Etat.CONNEXION:
		_changer_etat(Etat.INSCRIT)
		_afficher_message("RESEAU_INSCRIT", [index + 1], false)


## `Reseau` a déjà remis ce poste hors réseau quand ses signaux d'échec partent.
func _sur_refus(raison: String, version_hote: String) -> void:
	var connues := [Reseau.REFUS_VERSION, Reseau.REFUS_PLEIN, Reseau.REFUS_MANCHE, Reseau.REFUS_DEMANDE]
	var cle := raison if connues.has(raison) else Reseau.REFUS_DEMANDE
	_changer_etat(Etat.ACCUEIL)
	_afficher_message(cle, [version_hote] if cle == Reseau.REFUS_VERSION else [], true)


func _sur_connexion_echouee() -> void:
	_changer_etat(Etat.ACCUEIL)
	_afficher_message("RESEAU_ECHEC_CONNEXION", [], true)


func _sur_hote_perdu() -> void:
	_changer_etat(Etat.ACCUEIL)
	_afficher_message("RESEAU_HOTE_PERDU", [], true)


func _sur_joueurs_changes(_id: int) -> void:
	if etat == Etat.HEBERGE:
		_afficher_hebergement()


func _sur_langue_changee(_langue: String) -> void:
	_rendre_message()
	_afficher_parties()
