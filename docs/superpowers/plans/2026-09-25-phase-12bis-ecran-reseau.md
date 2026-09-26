# Phase 12 bis : découverte des parties (2/2), l'écran Réseau et le bouton Multijoueur, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** le titre gagne un bouton **Multijoueur** qui ouvre l'**écran Réseau** (16:9) : pseudo mémorisé (12 caractères au plus), **Héberger une partie**, **liste des parties** entendues par `Decouverte` (pleines, en cours ou d'une autre version grisées, avec la raison), **Rejoindre par IP** en secours (IPv4 seulement), et les messages traduits des refus (version, plein, manche, demande), de l'échec de connexion (avec l'indice pare-feu), de l'hôte perdu et du port occupé. Le titre remet toujours ce poste hors réseau avant le solo. Tant que le salon n'existe pas (phase 13), une partie hébergée ou rejointe attend sur l'écran. Sortie : **◉ écran Réseau** (captures regardées et validées par l'utilisateur), les quatre suites vertes 5 fois. **Le solo reste strictement identique** (seul ajout visible : le bouton Multijoueur).

**Architecture:** `Scenes/EcranReseau.tscn` (même ciel et mêmes tailles de police que le titre, `CenterContainer` / `VBoxContainer`, liste dans un `ScrollContainer` qui suit le focus) et `Scripts/EcranReseau.gd`, une petite machine à quatre états (`ACCUEIL`, `CONNEXION`, `HEBERGE`, `INSCRIT`) branchée sur les signaux de `Reseau` et sur `Decouverte.parties_changees` ; on n'écoute les balises qu'à l'accueil. La liste est mise à jour **en place** (un bouton par « ip:port », qui garde le focus quand sa partie change) et chaînée au clavier et à la manette (Héberger → parties → adresse IP). Les messages sont gardés en clé et arguments pour se retraduire au changement de langue. `Titre.gd` appelle `Reseau.quitter()` avant `configurer_solo()` et crée le bouton Multijoueur en bas à droite (voisin de droite de Jouer). Tous les textes passent par `traductions.csv` ; les clés des refus sont les constantes `Reseau.REFUS_*`.

**Tech Stack:** Godot 4.7.2, GDScript typé, `Control` / `LineEdit` / `ScrollContainer`, CSV de traductions (import `csv_translation`), tests headless (`tests/smoke_test.gd` et les trois autres suites), captures rendues en `opengl3` par un script jetable du scratchpad (Pillow pour zoomer si besoin).

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§4 parcours et refus, §7 viewport multi, §8 traductions, §9 erreurs) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 12 bis ; points de vigilance « phase 12 » : `Titre._ready` et `Reseau.quitter()`, textes des clés `REFUS_*`, M8 ; « phase 13 » : pseudo borné, 16:9 de l'écran Réseau) · plan précédent (autoload `Decouverte`, Écarts 1 à 7) : `docs/superpowers/plans/2026-09-25-phase-12-decouverte.md` · prérequis : phase 12 fusionnée (`Decouverte` autoload, `tests/reseau/lancer.sh` à 6 scénarios) ; nouvelle branche `phase-12bis-ecran-reseau` depuis `main`.

## Écarts assumés

1. **Le bouton Multijoueur est créé par `Titre.gd`** (en bas à droite, comme les boutons de coin Arcade et Réglages), pas ajouté à `Scenes/Titre.tscn` : la scène serait un 6ᵉ fichier, et la colonne centrale remplit déjà les 648 px de haut (logo 130 px, deux rangées de choix, Jouer, aide) ; un bouton de plus sous Jouer déborderait. Les boutons de difficulté et de niveau sont déjà créés par script. Au clavier et à la manette : droite depuis Jouer mène à Multijoueur, gauche en revient (voisins posés explicitement, vérifiés par le smoke test).
2. **Deux états d'attente provisoires** (`HEBERGE` : « Partie hébergée : n/6 joueurs… ton adresse : … » ; `INSCRIT` : « Connecté : tu es le joueur n… »), que le salon (phase 13) remplacera par un changement de scène. Ils rendent la phase vérifiable à deux fenêtres (l'une héberge, l'autre la voit et la rejoint, le compte de l'hôte monte) et montrent à l'hôte ses adresses pour la saisie par IP.
3. **« Hôte perdu » sur l'écran Réseau ramène à son accueil**, pas au titre : spec §9 (« message puis retour au titre ») vise une partie ou le salon (phases 13-14) ; ici, le joueur peut aussitôt rejoindre une autre partie, et le titre est à un Retour. Le message est « L'hôte a quitté la partie ».
4. **L'écran Réseau est en 16:9** (spec §7 et point de vigilance de la phase 13 : « le salon et l'écran Réseau passent eux-mêmes en 16:9 ») ; le titre remet 2000×648. Dans la fenêtre du solo (1400×454), il s'affiche donc avec de larges bandes, petit, jusqu'au réglage de la fenêtre (phases 14 et 19, déjà à la feuille de route) ; en plein écran 16:9, il remplit l'écran.
5. **Les captures ◉ viennent d'un script jetable du scratchpad**, non commité (comme la planche de la phase 11 bis) : `tests/screenshots.gd` n'est pas dans les fichiers ; y verser ces captures est réaffecté à la phase 19 (qui le touche), Task 4.
6. **Les durcissements du smoke test issus de la revue de la phase 8 ter** (« prochaine phase qui touche `tests/smoke_test.gd` » : `create_client` vérifié, intrus du groupe « lion » avec un champ `joueur`, direction du recul du peintre, peintre remis au repos) sont réaffectés à la **phase 14 bis** : ils portent sur les sections de contact que la 14 bis réécrit (base `Pastille`, `body is Lion`) ; les mêler à un écran de menu brouillerait la revue (Task 4).
7. **Le champ de pseudo est borné à `Reseau.PSEUDO_MAX`** ici (point de vigilance de la phase 13, qui parlait du « pseudo choisi au salon » : c'est l'écran Réseau qui le saisit, spec §4) ; la capture vérifie que 12 caractères larges (« MMMMMMMMMMMM ») tiennent dans le champ et dans la liste. Le clamp de l'étiquette du lion reste à la phase 13 (aperçu du salon).
8. **Le garde-fou contre un nom d'hôte reste dans l'écran** (`Decouverte.adresse_ipv4`, phase 12, Écart 7) ; `Reseau.rejoindre` le recevra en phase 13. Le pare-feu Windows (fenêtre au premier hébergement sur l'hôte, et désormais aussi à la première écoute des balises sur chaque client) va au README de la phase 19 (Task 4).
9. **Pas de nettoyage préalable (« Step 0 »)** : `tests/smoke_test.gd` (≈ 1 150 lignes) ne reçoit que deux appels et deux fonctions à la fin ; `Titre.gd` fait moins de 300 lignes. Lire `tests/smoke_test.gd` par morceaux (`offset` / `limit`).

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`, sur la branche `phase-12bis-ecran-reseau`.
- Fichiers de la phase (5) : ➕ `Scenes/EcranReseau.tscn`, ➕ `Scripts/EcranReseau.gd` (et son `.uid` généré), ✏️ `Scripts/Titre.gd`, ✏️ `Assets/Traductions/traductions.csv` (et les deux `.translation` que l'import en régénère, commités avec lui comme aux phases du solo), ✏️ `tests/smoke_test.gd`. La spec, la feuille de route, les plans et le script de captures (scratchpad) ne comptent pas. **`Scripts/Reseau.gd` et `Scripts/Decouverte.gd` ne sont jamais modifiés, même temporairement.**
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations. Tout texte visible passe par `traductions.csv` (FR + EN) ; les clés des refus sont les valeurs de `Reseau.REFUS_*` (`RESEAU_REFUS_VERSION`, `RESEAU_REFUS_PLEIN`, `RESEAU_REFUS_MANCHE`, `RESEAU_REFUS_DEMANDE`).
- Solo strictement identique : Jouer, Arcade, Réglages, la démo et les préférences du titre ne changent pas ; `Titre._ready` ajoute `Reseau.quitter()` (sans effet hors réseau) et le bouton. Le smoke test garde toutes ses vérifications du solo, vertes.
- Clavier et manette comme au titre : un bouton a le focus à l'arrivée (Héberger), haut et bas parcourent Héberger → parties → adresse IP, `ui_cancel` (Échap, B) fait Retour ; Espace / Entrée / A activent le bouton qui a le focus (`ui_accept` par défaut).
- Jamais le port 7777 ni le 7778 d'une vraie partie dans un test : le smoke test règle `Decouverte.port_balise = 17895` et `destinations_forcees = ["127.0.0.1"]`, héberge sur 17797 / 17798, se connecte à 17796 (personne), et remet les valeurs par défaut en sortie de section.
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : `tests/smoke_test.gd` récupère `Reseau`, `Decouverte`, `Scores`, `Parametres` par `root.get_node(…)` et ne les nomme pas ; il peut nommer `EtatPartie`, `PacketPeerUDP`, `ENetMultiplayerPeer`, `OfflineMultiplayerPeer`, `InputEventAction`. Les scènes chargées à l'exécution (`EcranReseau.tscn`, `Titre.tscn`) nomment les autoloads sans problème.
- **Toujours lancer un test Godot avec `timeout`** et chercher les erreurs dans la sortie :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; O=""; timeout -k 5 300 godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd; O=""`, `T=tests/bataille_test.gd; O="--fixed-fps 60"` ; le test réseau : `timeout -k 5 300 bash tests/reseau/lancer.sh`). Une `SCRIPT ERROR` ne change pas le code de sortie (la fonction fautive s'arrête, la suite continue) ; un solo enrayé peut bloquer le processus jusqu'au `timeout` (code 124). Après la création d'un script ou la modification du CSV : `godot --headless --import .` avant les tests. Bruit connu : « ObjectDB instances were leaked », « resources still in use at exit » ; dans le smoke test, `ERROR: Couldn't create an ENet host.` (port de jeu occupé, voulu) et deux `ERROR: The local port number must be between 0 and 65535 (inclusive).` (erreur d'hébergement forcée, voulue).
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`**.
- Les quatre suites se valident sur **5 passages consécutifs verts**.
- Les mutations de preuve ne touchent que le code neuf de cette phase (`Scripts/EcranReseau.gd`, `Scripts/Titre.gd`), déjà commité, et sont annulées par `git checkout -- <fichier>` : **jamais commitées**.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Revenir au titre d'une session laisse le poste en ligne** : un ancien client relance un solo où `multiplayer.is_server()` est faux (ennemis, pastilles, gerbe inertes, sans erreur), un ancien hôte émet encore sa balise et accepte des joueurs. → « après un hébergement, le titre remet ce poste hors réseau… », « après une connexion, le titre rend ce poste hôte de lui-même… » (Task 2), et le solo qui suit (« un coup coûte une vie ») ; sans `Reseau.quitter()` dans `Titre._ready` ⇒ ces deux `❌`, puis le solo s'enraye (« ❌ le pickup disparaît au contact »…, code 124) (Task 2, Step 4).
2. **Un nom d'hôte ou une faute de frappe dans l'adresse** (« lelion.local », « 192.168.1 ») : une résolution bloquante gèlerait le jeu, ou une connexion partirait vers n'importe quoi. → « un nom d'hôte est refusé sans rien tenter », « une IPv4 saisie lance la connexion, adresse normalisée » (Task 1) ; sans `Decouverte.adresse_ipv4` ⇒ `❌` (Task 1, Step 5).
3. **Un refus ou un échec qui affiche une clé brute, rien, ou laisse l'écran bloqué en « Connexion… »** (raison inconnue d'un hôte d'une autre version, hôte perdu pendant l'attente). → « chaque refus a son texte traduit… une raison inconnue lue comme demande incomprise », « pas de réponse : le message indique le pare-feu… », « hôte perdu : … retour à l'accueil qui écoute de nouveau » (Task 1).
4. **Un joueur au clavier ou à la manette coincé** : focus perdu quand une partie disparaît ou change, aucun chemin vers la liste ou l'adresse, Échap sans effet. → « haut et bas : Héberger, les parties dans l'ordre, puis l'adresse IP », « une partie qui change garde sa ligne et le focus », « la partie qui avait le focus disparaît : le focus revient à Héberger », « Échap (ou B) arrête d'héberger… » (Task 1) ; « droite depuis Jouer mène à Multijoueur » (Task 2) ; sans la chaîne ou sans le repli du focus ⇒ `❌` (Task 1, Step 5).
5. **Deux LeLion sur un même PC, ou un port déjà pris** : l'hébergement échoue sans explication, ou l'écran ne dit pas pourquoi la liste reste vide ; ou l'écran fermé laisse l'écoute ouverte (le prochain écran ne peut plus écouter). → « port occupé : « Impossible d'héberger : port 17798 occupé » … », « port des balises occupé : « Recherche impossible … Rejoins par IP » », « l'écran fermé ne laisse ni écoute ni connexion aux autoloads » (Task 1) ; sans le message ou avec l'écoute laissée ouverte ⇒ `❌` (Task 1, Step 5).

---

### Task 0 : vérification des plans

Ce plan a été commité par le commit de planification de la phase 12 : ne pas le recommiter, **ne jamais le modifier** (ni réécriture, ni résumé). Vérifier seulement que la phase 12 est fusionnée : `grep -n "Decouverte" project.godot` montre l'autoload et `grep -c "PARTIE EXPIREE" tests/reseau/lancer.sh` vaut au moins 1. Sinon, s'arrêter et le signaler.

---

### Task 1 : l'écran Réseau, ses textes et son test

**Files:**
- Create: `Scenes/EcranReseau.tscn`
- Create: `Scripts/EcranReseau.gd` (+ `Scripts/EcranReseau.gd.uid` généré)
- Modify: `Assets/Traductions/traductions.csv` (25 lignes à la fin ; `traductions.fr.translation` et `traductions.en.translation` régénérés)
- Test: `tests/smoke_test.gd` (`_run`, une fonction à la fin)

**Interfaces:**
- Consumes : `Reseau` (phase 11) : `heberger(port) -> Error`, `rejoindre(adresse, port) -> Error`, `quitter()`, `pseudo`, `version`, `places`, `inscrits`, `PORT`, `PSEUDO_MAX`, `REFUS_*`, `pseudo_valide(texte)`, signaux `inscrit(index, couleur)`, `refuse(raison, version_hote)`, `connexion_echouee()`, `hote_perdu()`, `joueur_arrive(id)`, `joueur_parti(id)` ; `Decouverte` (phase 12) : `ecouter()`, `arreter_ecoute()`, `ecoute_active()`, `parties`, `parties_triees()`, `port_balise`, `adresse_ipv4(texte)`, `adresses_privees(adresses)`, `enregistrer_partie(…)`, signal `parties_changees` ; `Scores.preference("pseudo", "")` / `definir_preference` ; `Parametres.langue_changee` ; `GameState.NIVEAUX` ; `ReglesBataille.TAILLE_ECRAN`.
- Produces (la phase 13 et le smoke test s'en servent) : scène `res://Scenes/EcranReseau.tscn` ; dans `EcranReseau.gd` : `enum Etat { ACCUEIL, CONNEXION, HEBERGE, INSCRIT }`, `var etat: Etat`, `var port_jeu: int`, `var boutons_parties: Dictionary[String, Button]`, nœuds `champ_pseudo`, `bouton_heberger`, `titre_parties`, `cadre_parties`, `liste`, `indice`, `champ_ip`, `bouton_rejoindre`, `message`, `bouton_retour` ; méthodes `heberger()`, `rejoindre_partie(cle: String)`, `rejoindre_par_ip()`, `retour(changer_scene := true)`. Clés de traduction `MULTIJOUEUR`, `RETOUR`, `RESEAU_*` (liste au Step 3c).

- [ ] **Step 1 : le test**

1a. Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	titre.free()
	scores.effacer()
	GS.niveau_courant = 0

	# Scores
```

par :

```gdscript
	titre.free()
	scores.effacer()
	GS.niveau_courant = 0

	await _tester_ecran_reseau(scores, params)

	# Scores
```

1b. Ajouter à la fin de `tests/smoke_test.gd` (après la ligne `quit(1 if _echecs > 0 else 0)` de `_run`) :

```gdscript


## Phase 12 bis : l'écran Réseau (liste, IP, refus, échecs, hébergement, port occupé, clavier). Les
## signaux de `Reseau` sont émis comme il le fait (après être revenu hors réseau pour les échecs) :
## le transport lui-même est couvert par tests/reseau/lancer.sh.
func _tester_ecran_reseau(scores: Node, params: Node) -> void:
	print("-- Écran Réseau")
	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	var port_balise := 17895  # jamais le 7778 d'une vraie partie
	decouverte.port_balise = port_balise
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	scores.definir_preference("pseudo", "Léa")
	var ecran: Control = load("res://Scenes/EcranReseau.tscn").instantiate()
	ecran.port_jeu = 17797
	root.add_child(ecran)
	await _frames(1)

	# Accueil : 16:9, focus, pseudo mémorisé et borné, écoute des balises, liste vide avec l'indice
	_check(root.content_scale_size == Vector2i(2000, 1125), "l'écran Réseau passe en 16:9, comme le salon")
	_check(ecran.etat == ecran.Etat.ACCUEIL and ecran.bouton_heberger.has_focus(), "à l'accueil, Héberger a le focus")
	_check(ecran.champ_pseudo.text == "Léa" and ecran.champ_pseudo.max_length == reseau.PSEUDO_MAX,
		"le pseudo mémorisé est repris, la saisie bornée à %d caractères" % reseau.PSEUDO_MAX)
	_check(decouverte.ecoute_active() and decouverte.port_balise == port_balise, "l'écran écoute les balises")
	_check(ecran.boutons_parties.is_empty() and ecran.indice.visible and ecran.indice.text == tr("RESEAU_AUCUNE_PARTIE")
		and "Pare-feu" in ecran.indice.text, "aucune partie : l'indice « Pare-feu ? Réseau Privé ? Essaie par IP »")
	_check(ecran.bouton_heberger.get_node(ecran.bouton_heberger.focus_neighbor_bottom) == ecran.champ_ip,
		"liste vide : bas depuis Héberger mène à l'adresse IP")

	# Parties entendues : une joignable, trois refusées d'avance (pleine, autre version, manche)
	var futur := Time.get_ticks_msec() + 600000  # « vues dans le futur » : elles n'expirent pas pendant le test
	var zoe := {"version": reseau.version, "port": 17797, "nb_joueurs": 2, "places": 6, "manche_en_cours": false, "niveau": 1, "pseudo": "Zoé"}
	decouverte.enregistrer_partie(decouverte.parties, "127.0.0.1", zoe, futur)
	decouverte.enregistrer_partie(decouverte.parties, "10.0.0.2", zoe.merged({"pseudo": "Anna", "nb_joueurs": 6}, true), futur)
	decouverte.enregistrer_partie(decouverte.parties, "10.0.0.3", zoe.merged({"pseudo": "Bob", "version": "0.1"}, true), futur)
	decouverte.enregistrer_partie(decouverte.parties, "10.0.0.4", zoe.merged({"pseudo": "Chloé", "manche_en_cours": true}, true), futur)
	decouverte.parties_changees.emit()
	await _frames(1)
	var ordre: Array = ecran.liste.get_children().slice(1).map(func(b: Button) -> String: return b.text.get_slice(" ", 0))
	_check(ecran.boutons_parties.size() == 4 and not ecran.indice.visible and ordre == ["Anna", "Bob", "Chloé", "Zoé"],
		"une ligne par partie entendue, triées par pseudo, sans l'indice (%s)" % [ordre])
	var b_zoe: Button = ecran.boutons_parties["127.0.0.1:17797"]
	_check(not b_zoe.disabled and b_zoe.text == tr("RESEAU_PARTIE") % ["Zoé", 2, 6, tr("NIVEAU_METROPOLE")],
		"une partie joignable : pseudo, joueurs sur places, niveau (%s)" % b_zoe.text)
	var b_anna: Button = ecran.boutons_parties["10.0.0.2:17797"]
	var b_bob: Button = ecran.boutons_parties["10.0.0.3:17797"]
	var b_chloe: Button = ecran.boutons_parties["10.0.0.4:17797"]
	_check(b_anna.disabled and b_anna.text.ends_with(tr("RESEAU_PARTIE_PLEINE")) and b_bob.disabled
		and b_bob.text.ends_with(tr("RESEAU_PARTIE_VERSION") % "0.1") and b_chloe.disabled and b_chloe.text.ends_with(tr("RESEAU_PARTIE_MANCHE")),
		"pleine, autre version, manche en cours : grisées, avec la raison (%s | %s | %s)" % [b_anna.text, b_bob.text, b_chloe.text])
	_check(ecran.bouton_heberger.get_node(ecran.bouton_heberger.focus_neighbor_bottom) == b_anna
		and b_zoe.get_node(b_zoe.focus_neighbor_bottom) == ecran.champ_ip and ecran.champ_ip.get_node(ecran.champ_ip.focus_neighbor_top) == b_zoe,
		"haut et bas : Héberger, les parties dans l'ordre, puis l'adresse IP")
	ecran.rejoindre_partie("10.0.0.2:17797")
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne(), "une partie grisée ne se rejoint pas")
	b_zoe.grab_focus()
	decouverte.enregistrer_partie(decouverte.parties, "127.0.0.1", zoe.merged({"nb_joueurs": 3}, true), futur)
	decouverte.parties_changees.emit()
	await _frames(1)
	_check(ecran.boutons_parties["127.0.0.1:17797"] == b_zoe and b_zoe.has_focus() and "3/6" in b_zoe.text,
		"une partie qui change garde sa ligne et le focus (%s)" % b_zoe.text)
	decouverte.parties.erase("127.0.0.1:17797")
	decouverte.parties_changees.emit()
	await _frames(1)
	_check(ecran.boutons_parties.size() == 3 and not ecran.boutons_parties.has("127.0.0.1:17797") and ecran.bouton_heberger.has_focus(),
		"la partie qui avait le focus disparaît : le focus revient à Héberger")

	# Adresse IP saisie : refusée si ce n'est pas une IPv4, sinon connexion avec le pseudo nettoyé
	ecran.champ_ip.text = "lelion.local"
	ecran.rejoindre_par_ip()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == tr("RESEAU_IP_INVALIDE")
		and ecran.champ_ip.has_focus(), "un nom d'hôte est refusé sans rien tenter (%s)" % ecran.message.text)
	ecran.champ_pseudo.text = " Zoé la grande dompteuse"
	_check(ecran.champ_pseudo.text == " Zoé la gran", "la saisie du pseudo s'arrête à %d caractères (%s)" % [reseau.PSEUDO_MAX, ecran.champ_pseudo.text])
	ecran.port_jeu = 17796  # personne n'y écoute
	ecran.champ_ip.text = " 127.000.0.1 "
	ecran.rejoindre_par_ip()
	_check(ecran.etat == ecran.Etat.CONNEXION and reseau.en_ligne() and not root.multiplayer.is_server()
		and ecran.champ_ip.text == "127.0.0.1" and ecran.message.text == tr("RESEAU_CONNEXION") % "127.0.0.1",
		"une IPv4 saisie lance la connexion, adresse normalisée (%s)" % ecran.message.text)
	_check(reseau.pseudo == "Zoé la gran" and ecran.champ_pseudo.text == "Zoé la gran" and scores.preference("pseudo", "") == "Zoé la gran",
		"le pseudo nettoyé (sans l'espace de tête) est donné à Reseau et mémorisé (%s)" % reseau.pseudo)
	_check(not decouverte.ecoute_active() and ecran.boutons_parties.is_empty() and not ecran.cadre_parties.visible
		and ecran.bouton_heberger.disabled and not ecran.champ_ip.editable and ecran.bouton_retour.has_focus(),
		"pendant la connexion : plus d'écoute ni de liste, tout est grisé sauf Retour, qui a le focus")
	reseau.inscrit.emit(2, palette[2])
	_check(ecran.etat == ecran.Etat.INSCRIT and ecran.message.text == tr("RESEAU_INSCRIT") % 3, "inscrit par l'hôte : « tu es le joueur 3 »")
	reseau.quitter()
	reseau.hote_perdu.emit()
	_check(ecran.etat == ecran.Etat.ACCUEIL and ecran.message.text == tr("RESEAU_HOTE_PERDU") and decouverte.ecoute_active()
		and ecran.bouton_heberger.has_focus(), "hôte perdu : « L'hôte a quitté la partie », retour à l'accueil qui écoute de nouveau")
	ecran.rejoindre_par_ip()
	reseau.quitter()
	reseau.connexion_echouee.emit()
	_check(ecran.etat == ecran.Etat.ACCUEIL and ecran.message.text == tr("RESEAU_ECHEC_CONNEXION") and "Pare-feu" in ecran.message.text,
		"pas de réponse : le message indique le pare-feu de l'hôte et le réseau Privé (%s)" % ecran.message.text)
	var attendus := {reseau.REFUS_VERSION: tr("RESEAU_REFUS_VERSION") % "0.9", reseau.REFUS_PLEIN: tr("RESEAU_REFUS_PLEIN"),
		reseau.REFUS_MANCHE: tr("RESEAU_REFUS_MANCHE"), reseau.REFUS_DEMANDE: tr("RESEAU_REFUS_DEMANDE"), "RAISON_INCONNUE": tr("RESEAU_REFUS_DEMANDE")}
	var faux: Array[String] = []
	for raison: String in attendus:
		ecran.rejoindre_par_ip()
		reseau.quitter()
		reseau.refuse.emit(raison, "0.9")
		if ecran.etat != ecran.Etat.ACCUEIL or ecran.message.text != attendus[raison] or ecran.message.text.begins_with("RESEAU_"):
			faux.append("%s → %s" % [raison, ecran.message.text])
	_check(faux.is_empty() and tr("RESEAU_REFUS_VERSION") % "0.9" == "Version différente de l'hôte (0.9)",
		"chaque refus a son texte traduit, la version de l'hôte dans le refus de version, une raison inconnue lue comme demande incomprise (%s)" % [faux])

	# Héberger : en ligne, hôte, plus d'écoute ; les arrivées s'affichent ; Échap arrête
	ecran.port_jeu = 17797
	ecran.heberger()
	_check(ecran.etat == ecran.Etat.HEBERGE and reseau.en_ligne() and root.multiplayer.is_server()
		and reseau.inscrits[1].pseudo == "Zoé la gran" and not decouverte.ecoute_active() and ecran.bouton_retour.has_focus(),
		"Héberger : ce poste héberge avec son pseudo, n'écoute plus les balises (il ne se verrait pas lui-même)")
	_check(ecran.message.text.begins_with(tr("RESEAU_HEBERGE").get_slice("%", 0)) and "1/6" in ecran.message.text,
		"l'hôte voit ses joueurs et ses adresses (%s)" % ecran.message.text)
	reseau.inscrits[5] = {"index": 1, "couleur": palette[1], "pseudo": "Bob"}
	reseau.joueur_arrive.emit(5)
	_check("2/6" in ecran.message.text, "un joueur arrive : l'hôte le voit (%s)" % ecran.message.text)
	var echap := InputEventAction.new()
	echap.action = "ui_cancel"
	echap.pressed = true
	root.push_input(echap)
	await process_frame
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and decouverte.ecoute_active() and ecran.message.text.is_empty(),
		"Échap (ou B) arrête d'héberger et revient à l'accueil, qui écoute de nouveau")

	# Port de jeu occupé, autre erreur d'hébergement ; changer de langue retraduit le message
	var occupant := ENetMultiplayerPeer.new()
	_check(occupant.create_server(17798) == OK, "(pré-condition) un autre programme occupe le port 17798")
	ecran.port_jeu = 17798
	ecran.heberger()
	_check(ecran.etat == ecran.Etat.ACCUEIL and not reseau.en_ligne() and ecran.message.text == "Impossible d'héberger : port 17798 occupé",
		"port occupé : « Impossible d'héberger : port 17798 occupé », sans quitter l'accueil (%s)" % ecran.message.text)
	params.definir_langue("en")
	await _frames(1)
	_check(ecran.message.text == "Can't host: port 17798 in use" and ecran.indice.text.begins_with("No game found"),
		"changer de langue retraduit le message et l'indice (%s | %s)" % [ecran.message.text, ecran.indice.text])
	params.definir_langue("fr")
	occupant.close()
	var erreur_attendue := ENetMultiplayerPeer.new().create_server(70000)
	ecran.port_jeu = 70000
	ecran.heberger()
	_check(not reseau.en_ligne() and ecran.message.text == tr("RESEAU_HEBERGER_IMPOSSIBLE") % erreur_attendue,
		"une autre erreur d'hébergement donne son code (%s)" % ecran.message.text)

	# Retour à l'accueil (sans changer de scène : la navigation vers le titre est vérifiée avec le
	# bouton Multijoueur) ; l'écran fermé ne laisse ni écoute ni connexion aux autoloads
	ecran.retour(false)
	_check(not reseau.en_ligne() and scores.preference("pseudo", "") == "Zoé la gran", "Retour quitte le réseau et garde le pseudo mémorisé")
	ecran.free()
	_check(not decouverte.ecoute_active() and decouverte.parties_changees.get_connections().is_empty()
		and reseau.refuse.get_connections().is_empty() and reseau.joueur_arrive.get_connections().is_empty(),
		"l'écran fermé ne laisse ni écoute ni connexion aux autoloads")

	# Port des balises déjà pris (deux LeLion sur un PC) : la liste le dit, sans planter
	var intrus := PacketPeerUDP.new()
	_check(intrus.bind(port_balise, "0.0.0.0") == OK, "(pré-condition) un autre programme occupe le port des balises")
	var ecran2: Control = load("res://Scenes/EcranReseau.tscn").instantiate()
	root.add_child(ecran2)
	await _frames(1)
	_check(not decouverte.ecoute_active() and ecran2.indice.visible and ecran2.indice.text == tr("RESEAU_ECOUTE_IMPOSSIBLE") % port_balise,
		"port des balises occupé : « Recherche impossible … Rejoins par IP » (%s)" % ecran2.indice.text)
	ecran2.free()
	intrus.close()

	decouverte.port_balise = decouverte.PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray()
	reseau.pseudo = ""
	scores.effacer()
```

- [ ] **Step 2 : le test échoue**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`.
Expected (mesuré) : `ERROR: Cannot open file 'res://Scenes/EcranReseau.tscn'.`, puis `SCRIPT ERROR: Attempt to call function 'instantiate' in base 'null instance' on a null instance.` dans `_tester_ecran_reseau` ; aucune ligne ✅ ou ❌ sous « -- Écran Réseau » (la section s'arrête là, le reste du smoke test continue et peut finir en `code 0`) : c'est la `SCRIPT ERROR` qui fait l'échec.

- [ ] **Step 3 : l'écran**

3a. Créer `Scenes/EcranReseau.tscn` :

```ini
[gd_scene load_steps=5 format=3 uid="uid://dlelionreseau"]

[ext_resource type="Script" path="res://Scripts/EcranReseau.gd" id="1_reseau"]

[sub_resource type="Gradient" id="Gradient_ciel"]
offsets = PackedFloat32Array(0, 0.55, 1)
colors = PackedColorArray(0.09, 0.1, 0.24, 1, 0.42, 0.25, 0.43, 1, 0.9, 0.5, 0.32, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_ciel"]
gradient = SubResource("Gradient_ciel")
fill_to = Vector2(0, 1)

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_liste"]
content_margin_left = 16.0
content_margin_top = 16.0
content_margin_right = 16.0
content_margin_bottom = 16.0
bg_color = Color(0, 0, 0, 0.25)
corner_radius_top_left = 12
corner_radius_top_right = 12
corner_radius_bottom_right = 12
corner_radius_bottom_left = 12

[node name="EcranReseau" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_reseau")

[node name="Ciel" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
texture = SubResource("GradientTexture2D_ciel")

[node name="Centre" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Colonne" type="VBoxContainer" parent="Centre"]
layout_mode = 2
theme_override_constants/separation = 20
alignment = 1

[node name="Titre" type="Label" parent="Centre/Colonne"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.85, 0.2, 1)
theme_override_font_sizes/font_size = 110
text = "MULTIJOUEUR"
horizontal_alignment = 1

[node name="RangeePseudo" type="HBoxContainer" parent="Centre/Colonne"]
layout_mode = 2
theme_override_constants/separation = 16
alignment = 1

[node name="Etiquette" type="Label" parent="Centre/Colonne/RangeePseudo"]
custom_minimum_size = Vector2(300, 0)
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.75)
theme_override_font_sizes/font_size = 30
text = "RESEAU_PSEUDO"
horizontal_alignment = 2
vertical_alignment = 1

[node name="Pseudo" type="LineEdit" parent="Centre/Colonne/RangeePseudo"]
custom_minimum_size = Vector2(520, 72)
layout_mode = 2
theme_override_font_sizes/font_size = 34
max_length = 12

[node name="Heberger" type="Button" parent="Centre/Colonne"]
custom_minimum_size = Vector2(520, 80)
layout_mode = 2
size_flags_horizontal = 4
theme_override_font_sizes/font_size = 38
text = "RESEAU_HEBERGER"

[node name="TitreParties" type="Label" parent="Centre/Colonne"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.75)
theme_override_font_sizes/font_size = 30
text = "RESEAU_PARTIES"
horizontal_alignment = 1

[node name="Cadre" type="PanelContainer" parent="Centre/Colonne"]
custom_minimum_size = Vector2(1180, 0)
layout_mode = 2
size_flags_horizontal = 4
theme_override_styles/panel = SubResource("StyleBoxFlat_liste")

[node name="Defilement" type="ScrollContainer" parent="Centre/Colonne/Cadre"]
custom_minimum_size = Vector2(0, 360)
layout_mode = 2
follow_focus = true
horizontal_scroll_mode = 0

[node name="Parties" type="VBoxContainer" parent="Centre/Colonne/Cadre/Defilement"]
layout_mode = 2
size_flags_horizontal = 3
theme_override_constants/separation = 10

[node name="Indice" type="Label" parent="Centre/Colonne/Cadre/Defilement/Parties"]
custom_minimum_size = Vector2(1100, 0)
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.6)
theme_override_font_sizes/font_size = 26
horizontal_alignment = 1
autowrap_mode = 3

[node name="RangeeIP" type="HBoxContainer" parent="Centre/Colonne"]
layout_mode = 2
theme_override_constants/separation = 16
alignment = 1

[node name="Etiquette" type="Label" parent="Centre/Colonne/RangeeIP"]
custom_minimum_size = Vector2(300, 0)
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.75)
theme_override_font_sizes/font_size = 30
text = "RESEAU_ADRESSE_IP"
horizontal_alignment = 2
vertical_alignment = 1

[node name="IP" type="LineEdit" parent="Centre/Colonne/RangeeIP"]
custom_minimum_size = Vector2(420, 72)
layout_mode = 2
theme_override_font_sizes/font_size = 34
placeholder_text = "192.168.1.20"
max_length = 21

[node name="Rejoindre" type="Button" parent="Centre/Colonne/RangeeIP"]
custom_minimum_size = Vector2(260, 72)
layout_mode = 2
theme_override_font_sizes/font_size = 32
text = "RESEAU_REJOINDRE"

[node name="Message" type="Label" parent="Centre/Colonne"]
custom_minimum_size = Vector2(1400, 90)
layout_mode = 2
theme_override_colors/font_outline_color = Color(0.1, 0.05, 0.12, 0.85)
theme_override_constants/outline_size = 6
theme_override_font_sizes/font_size = 30
horizontal_alignment = 1
autowrap_mode = 3

[node name="BoutonRetour" type="Button" parent="."]
layout_mode = 1
offset_left = 24.0
offset_top = 24.0
offset_right = 284.0
offset_bottom = 100.0
theme_override_font_sizes/font_size = 26
text = "RETOUR"

[connection signal="pressed" from="BoutonRetour" to="." method="retour"]
[connection signal="pressed" from="Centre/Colonne/Heberger" to="." method="heberger"]
[connection signal="pressed" from="Centre/Colonne/RangeeIP/Rejoindre" to="." method="rejoindre_par_ip"]
[connection signal="text_submitted" from="Centre/Colonne/RangeeIP/IP" to="." method="rejoindre_par_ip" unbinds=1]
```

Notes : le contour du message (`outline_size = 6`) le garde lisible sur le bas orangé du ciel (mesuré sur capture : sans lui, le saumon des erreurs s'y perd ; à 10, les lettres s'empâtent). `uid://dlelionreseau` suit le style des scènes du projet (`uid://dleliontitre0`, `uid://dlelionreglag`).

3b. Créer `Scripts/EcranReseau.gd` :

```gdscript
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
```

3c. Ajouter à la fin de `Assets/Traductions/traductions.csv` (après la ligne `DEMO,…`, qui finit par un saut de ligne) :

```csv
MULTIJOUEUR,Multijoueur,Multiplayer
RETOUR,Retour,Back
RESEAU_PSEUDO,Pseudo,Name
RESEAU_HEBERGER,Héberger une partie,Host a game
RESEAU_PARTIES,Parties sur le réseau,Games on the network
RESEAU_AUCUNE_PARTIE,"Aucune partie trouvée. Pare-feu ? Réseau Privé ? Essaie par IP.","No game found. Firewall? Private network? Try by IP."
RESEAU_ECOUTE_IMPOSSIBLE,"Recherche impossible : port %d déjà utilisé (un autre LeLion ouvert ?). Rejoins par IP.","Can't search: port %d already in use (another LeLion open?). Join by IP."
RESEAU_PARTIE,%s · %d/%d joueurs · %s,%s · %d/%d players · %s
RESEAU_PARTIE_PLEINE,complète,full
RESEAU_PARTIE_MANCHE,manche en cours,round in progress
RESEAU_PARTIE_VERSION,version %s,version %s
RESEAU_ADRESSE_IP,Adresse IP,IP address
RESEAU_REJOINDRE,Rejoindre,Join
RESEAU_IP_INVALIDE,"Adresse IP invalide (exemple : 192.168.1.20)","Invalid IP address (example: 192.168.1.20)"
RESEAU_CONNEXION,Connexion à %s…,Connecting to %s…
RESEAU_HEBERGE,"Partie hébergée : %d/%d joueurs. Les autres la voient dans leur liste, ou tapent ton adresse : %s","Game hosted: %d/%d players. Others see it in their list, or type your address: %s"
RESEAU_INSCRIT,"Connecté : tu es le joueur %d. En attente de l'hôte…","Connected: you are player %d. Waiting for the host…"
RESEAU_REFUS_VERSION,Version différente de l'hôte (%s),Different version from the host (%s)
RESEAU_REFUS_PLEIN,La partie est complète.,The game is full.
RESEAU_REFUS_MANCHE,"Une manche est en cours : réessaie à la fin.","A round is in progress: try again when it ends."
RESEAU_REFUS_DEMANDE,"Réponse incomprise : est-ce bien une partie de LeLion ?","Unreadable answer: is this really a LeLion game?"
RESEAU_ECHEC_CONNEXION,"Pas de réponse de l'hôte. Pare-feu de l'hôte ? Réseau Privé ?","No answer from the host. Host firewall? Private network?"
RESEAU_HOTE_PERDU,L'hôte a quitté la partie,The host left the game
RESEAU_PORT_OCCUPE,Impossible d'héberger : port %d occupé,Can't host: port %d in use
RESEAU_HEBERGER_IMPOSSIBLE,Impossible d'héberger (erreur %d),Can't host (error %d)
```

Les textes de la spec sont repris mot pour mot : « Version différente de l'hôte (x.y) » (§4), « L'hôte a quitté la partie » (§4), « Impossible d'héberger : port 7777 occupé » (§9, le port réellement essayé), « Pare-feu ? Réseau Privé ? Essaie par IP » (§9) ; l'échec de connexion porte l'indice « Pare-feu de l'hôte ? Réseau Privé ? » (M8). `RESEAU_REFUS_DEMANDE` ne s'affiche que si la réponse de l'hôte est illisible (un LeLion ne se voit jamais refuser sa demande pour ce motif).

3d. Import (génère `Scripts/EcranReseau.gd.uid` et régénère les deux `.translation`) :
Run : `export PATH="/opt/homebrew/bin:$PATH"; timeout -k 5 120 godot --headless --import . > "$TMPDIR/i.log" 2>&1; grep -E "SCRIPT ERROR|Parse Error|Compile Error" "$TMPDIR/i.log"; git status --short`
Expected : aucune ligne d'erreur ; `git status` montre les deux fichiers neufs (et le `.uid`), `traductions.csv`, `traductions.en.translation`, `traductions.fr.translation`, `tests/smoke_test.gd`.

- [ ] **Step 4 : le test passe**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`.
Expected : `code 0`, `== 0 échec(s) ==`, 34 lignes ✅ sous « -- Écran Réseau » (dont « port occupé : « Impossible d'héberger : port 17798 occupé », sans quitter l'accueil » et « l'écran fermé ne laisse ni écoute ni connexion aux autoloads »), toutes les vérifications du solo toujours vertes.

- [ ] **Step 5 : Commit, puis le test discrimine**

```bash
git add Scenes/EcranReseau.tscn Scripts/EcranReseau.gd Scripts/EcranReseau.gd.uid Assets/Traductions/traductions.csv Assets/Traductions/traductions.fr.translation Assets/Traductions/traductions.en.translation tests/smoke_test.gd
git commit -m "Écran Réseau : pseudo mémorisé, Héberger, liste des parties (grisées avec la raison), Rejoindre par IP (IPv4 seulement), textes des refus et des échecs, clavier et manette ; smoke test

<ligne fournie par l'environnement>"
```

Puis chaque mutation seule sur `Scripts/EcranReseau.gd`, le smoke test (`grep -E "❌"`), et **`git checkout -- Scripts/EcranReseau.gd`** avant la suivante (mesuré en préparant le plan) :
- M1 : supprimer la ligne `_chainer_focus(cles)` ⇒ `❌ liste vide : bas depuis Héberger mène à l'adresse IP` et `❌ haut et bas : …` ;
- M2 : supprimer les deux lignes `if focus_perdu:` / `bouton_heberger.grab_focus()` ⇒ `❌ la partie qui avait le focus disparaît : le focus revient à Héberger` ;
- M3 : dans `_exit_tree`, supprimer `Decouverte.arreter_ecoute()` ⇒ `❌ … sans écoute` (« l'écran fermé ne laisse ni écoute… ») et `❌ port des balises occupé …` ;
- M4 : `if erreur == ERR_CANT_CREATE:` → `if false:` ⇒ `❌ port occupé : … (Impossible d'héberger (erreur 20))` ;
- M5 : `var adresse := Decouverte.adresse_ipv4(champ_ip.text)` → `var adresse := champ_ip.text.strip_edges()` ⇒ `❌ un nom d'hôte est refusé sans rien tenter` (le passage dure plus longtemps : la résolution de « lelion.local » bloque, c'est le défaut même que la validation évite).

Expected ensuite : `git status --short` vide.

---

### Task 2 : le titre (bouton Multijoueur, retour hors réseau) et son test

**Files:**
- Modify: `Scripts/Titre.gd` (docstring, constante, variable, `_ready`, deux fonctions)
- Test: `tests/smoke_test.gd` (`_run`, une fonction à la fin)

**Interfaces:**
- Consumes : `Reseau.quitter()` (phase 11) ; `Scenes/EcranReseau.tscn` et `EcranReseau.bouton_retour`, `EcranReseau.retour()` (Task 1) ; le point de vigilance « phase 12 » (`Titre._ready` doit appeler `Reseau.quitter()` à côté de `configurer_solo()`).
- Produces : `Titre.SCENE_RESEAU`, `Titre.bouton_multijoueur: Button` (nœud `BoutonMultijoueur`), `Titre.ouvrir_reseau()` ; `Titre._ready` remet toujours ce poste hors réseau avant le solo (tout chemin de retour au titre des phases 13 à 18 en profite).

- [ ] **Step 1 : le test**

1a. Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	await _tester_ecran_reseau(scores, params)
```

par :

```gdscript
	await _tester_ecran_reseau(scores, params)
	await _tester_titre_reseau(scores)
```

1b. Ajouter à la fin de `tests/smoke_test.gd` (après `_tester_ecran_reseau`) :

```gdscript


## Phase 12 bis : le bouton Multijoueur du titre, l'aller et retour avec l'écran Réseau, et le titre
## qui remet toujours ce poste hors réseau avant le solo.
func _tester_titre_reseau(scores: Node) -> void:
	print("-- Titre et réseau")
	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	decouverte.port_balise = 17895  # l'écran Réseau ouvert ici écoute : jamais le 7778 d'une vraie partie
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])

	# Titre : le bouton Multijoueur, dans l'écran, sans chevaucher les autres, joignable au clavier
	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	var multi: Button = titre.bouton_multijoueur
	_check(multi != null and multi.get_parent() == titre and multi.text == "MULTIJOUEUR" and tr("MULTIJOUEUR") == "Multijoueur",
		"l'écran titre a un bouton Multijoueur, traduit")
	var rect_multi: Rect2 = multi.get_global_rect()
	var autres: Array = [titre.bouton_jouer, titre.bouton_reglages, titre.bouton_arcade, titre.get_node("Centre/Colonne/Aide")]
	_check(Rect2(Vector2.ZERO, Vector2(2000, 648)).encloses(rect_multi)
		and autres.all(func(c: Control) -> bool: return not c.get_global_rect().intersects(rect_multi)),
		"le bouton Multijoueur tient dans l'écran du titre sans chevaucher Jouer, Réglages, Arcade ni l'aide (%s)" % rect_multi)
	_check(titre.bouton_jouer.get_node(titre.bouton_jouer.focus_neighbor_right) == multi
		and multi.get_node(multi.focus_neighbor_left) == titre.bouton_jouer,
		"clavier et manette : droite depuis Jouer mène à Multijoueur, gauche en revient")
	multi.pressed.emit()
	await _frames(2)
	var ecran: Control = current_scene
	titre.free()
	_check(ecran != null and ecran.scene_file_path == "res://Scenes/EcranReseau.tscn", "Multijoueur ouvre l'écran Réseau")
	if ecran == null or ecran.scene_file_path != "res://Scenes/EcranReseau.tscn":
		return
	ecran.bouton_retour.pressed.emit()
	await _frames(2)
	var titre_retour: Control = current_scene
	_check(titre_retour != null and titre_retour.scene_file_path == "res://Scenes/Titre.tscn" and not is_instance_valid(ecran)
		and root.content_scale_size == Vector2i(2000, 648) and not decouverte.ecoute_active() and not reseau.en_ligne(),
		"Retour ramène au titre, en 2000×648, hors réseau et sans écoute")
	if titre_retour != null:
		titre_retour.free()

	# Retour au titre depuis une session : hors réseau AVANT le solo (point de vigilance de la phase 12)
	_check(reseau.heberger(17797) == OK, "(pré-condition) ce poste héberge")
	titre = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and reseau.inscrits.is_empty(),
		"après un hébergement, le titre remet ce poste hors réseau (plus de balise ni d'arrivée)")
	titre.free()
	_check(reseau.rejoindre("127.0.0.1", 17796) == OK and not root.multiplayer.is_server(), "(pré-condition) ce poste est un client")
	titre = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	_check(root.multiplayer.is_server() and not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,
		"après une connexion, le titre rend ce poste hôte de lui-même : le solo qui suit tranche ses contacts (« un coup coûte une vie »)")
	titre.free()
	decouverte.port_balise = decouverte.PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray()
	reseau.pseudo = ""
	scores.effacer()
```

Notes : `multi.pressed.emit()` et `ecran.bouton_retour.pressed.emit()` passent par les vraies connexions (changement de scène compris) : la section tourne avant le chargement de `Main.tscn`, quand `current_scene` est encore nul ; `change_scene_to_file` y pose l'écran, puis le titre, que la section libère. Toute la partie solo du smoke test qui suit tourne donc juste après un retour au titre depuis un poste client : c'est la preuve demandée par le point de vigilance (« un ennemi touche le lion » : « un coup coûte une vie, la partie continue »).

- [ ] **Step 2 : le test échoue**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`.
Expected (mesuré) : `SCRIPT ERROR: Invalid access to property or key 'bouton_multijoueur' on a base object of type 'Control (Titre.gd)'.` dans `_tester_titre_reseau` ; la section s'arrête là, le reste du smoke test continue (`code 0` possible) : c'est la `SCRIPT ERROR` qui fait l'échec.

- [ ] **Step 3 : le titre**

Dans `Scripts/Titre.gd` :

3a. Remplacer :

```gdscript
## Écran titre : difficulté et niveau se choisissent (mémorisés), Jouer lance la partie.
## Les niveaux affichent le record pour la difficulté choisie. `_ready` remet aussi le solo
## (`GameState.configurer_solo()` et l'écran 2000×648), même au retour d'une bataille.

const SCENE_JEU := "res://Scenes/Main.tscn"
```

par :

```gdscript
## Écran titre : difficulté et niveau se choisissent (mémorisés), Jouer lance la partie,
## Multijoueur ouvre l'écran Réseau. Les niveaux affichent le record pour la difficulté choisie.
## `_ready` remet aussi ce poste hors réseau et le solo (`GameState.configurer_solo()` et l'écran
## 2000×648), même au retour d'une bataille ou de l'écran Réseau.

const SCENE_JEU := "res://Scenes/Main.tscn"
const SCENE_RESEAU := "res://Scenes/EcranReseau.tscn"
```

3b. Remplacer :

```gdscript
@onready var bouton_arcade: Button = $BoutonArcade

```

par :

```gdscript
@onready var bouton_arcade: Button = $BoutonArcade
## Créé par `_ready`, en bas à droite (la colonne centrale remplit déjà les 648 px de haut).
var bouton_multijoueur: Button

```

3c. Remplacer :

```gdscript
	get_tree().paused = false
	# L'écran titre est celui du solo
```

par :

```gdscript
	get_tree().paused = false
	# Retour depuis l'écran Réseau, le salon ou une manche quittée par le menu local, sans signal de
	# `Reseau` : ce poste revient hors réseau AVANT de remettre le solo. Sinon un ancien client
	# relancerait un solo où `multiplayer.is_server()` est faux (ennemis, pastilles, gerbe et chocs
	# inertes), et un ancien hôte émettrait encore sa balise et accepterait des joueurs.
	Reseau.quitter()
	# L'écran titre est celui du solo
```

(la ligne `# L'écran titre est celui du solo : Jouer, la démo et l'arcade…` continue telle quelle ; seul son début sert à situer l'insertion.)

3d. Remplacer :

```gdscript
	Parametres.langue_changee.connect(func(_l: String) -> void: rafraichir_textes())
```

par :

```gdscript
	bouton_multijoueur = _creer_bouton_multijoueur()
	Parametres.langue_changee.connect(func(_l: String) -> void: rafraichir_textes())
```

3e. Remplacer :

```gdscript
func lancer_demo(changer_scene := true) -> void:
```

par :

```gdscript
## Le bouton Multijoueur, en bas à droite, dans le style des boutons de coin (Arcade, Réglages) ;
## au clavier et à la manette, droite depuis Jouer y mène, gauche en revient.
func _creer_bouton_multijoueur() -> Button:
	var bouton := Button.new()
	bouton.name = "BoutonMultijoueur"
	bouton.text = "MULTIJOUEUR"
	bouton.add_theme_font_size_override("font_size", 26)
	bouton.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bouton.offset_left = -284.0
	bouton.offset_top = -100.0
	bouton.offset_right = -24.0
	bouton.offset_bottom = -24.0
	bouton.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bouton.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bouton.pressed.connect(ouvrir_reseau)
	add_child(bouton)
	bouton_jouer.focus_neighbor_right = bouton_jouer.get_path_to(bouton)
	bouton.focus_neighbor_left = bouton.get_path_to(bouton_jouer)
	return bouton


func ouvrir_reseau() -> void:
	get_tree().change_scene_to_file(SCENE_RESEAU)


func lancer_demo(changer_scene := true) -> void:
```

- [ ] **Step 4 : le test passe, et il discrimine**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`.
Expected : `code 0`, `== 0 échec(s) ==`, 9 lignes ✅ sous « -- Titre et réseau », dont « le bouton Multijoueur tient dans l'écran du titre sans chevaucher Jouer, Réglages, Arcade ni l'aide ([P: (1716.0, 548.0), S: (260.0, 76.0)]) ».

Commit :

```bash
git add Scripts/Titre.gd tests/smoke_test.gd
git commit -m "Titre : bouton Multijoueur vers l'écran Réseau (voisin de droite de Jouer), ce poste remis hors réseau avant le solo ; smoke test

<ligne fournie par l'environnement>"
```

Puis la preuve (mesurée en préparant le plan) : dans `Scripts/Titre.gd`, supprimer la ligne `	Reseau.quitter()` ; smoke test avec `timeout -k 5 300`.
Expected : `code 124`, `❌ après un hébergement, le titre remet ce poste hors réseau …`, `❌ après une connexion, le titre rend ce poste hôte de lui-même …`, puis le solo s'enraye (`❌ le pickup disparaît au contact`, `❌ une couleur débloquée via pickup`…). `git checkout -- Scripts/Titre.gd` ; `git status --short` vide.

- [ ] **Step 5 : les suites, 5 fois**

Run : 5 fois de suite chacune des trois suites Godot et `bash tests/reseau/lancer.sh`.
Expected : chaque fois `code 0` et `== 0 échec(s) ==`, aucune `SCRIPT ERROR` ni `SHADER ERROR`.

---

### Task 3 : ◉ captures de l'écran Réseau (non commitées)

**Files:**
- Create (scratchpad de l'exécutant, jamais dans le dépôt) : `<scratchpad>/captures_reseau.gd`

**Interfaces:**
- Consumes : Tasks 1 et 2 (scènes, `Decouverte.enregistrer_partie`, `EcranReseau.port_jeu`, `heberger()`, `rejoindre_par_ip()`, `retour(false)`, `Titre.bouton_multijoueur`).
- Produces : 11 captures PNG dans `<scratchpad>/captures-12bis/`, montrées à l'utilisateur.

- [ ] **Step 1 : le script**

Créer `<scratchpad>/captures_reseau.gd` :

```gdscript
extends SceneTree
## Captures de contrôle de l'écran Réseau (phase 12 bis, non commitées) :
## godot --path <dépôt> --rendering-driver opengl3 --script <ce fichier> -- --dossier=<dossier>
## Rendu réel (pas headless). N'utilise ni le port 7777 ni le 7778 d'une vraie partie.

var dossier := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dossier="):
			dossier = arg.trim_prefix("--dossier=")
	call_deferred("_run")


func _attendre(secondes: float) -> void:
	await create_timer(secondes).timeout


func _shot(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var chemin := dossier.path_join(nom + ".png")
	image.save_png(chemin)
	print("📸 %s (%dx%d)" % [chemin, image.get_width(), image.get_height()])


func _run() -> void:
	if dossier.is_empty():
		printerr("--dossier=<chemin> manquant")
		quit(1)
		return
	var scores: Node = root.get_node("Scores")
	var params: Node = root.get_node("Parametres")
	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	scores.chemin = "user://scores_captures.cfg"
	scores.effacer()
	params.definir_langue("fr")
	scores.definir_preference("pseudo", "MMMMMMMMMMMM")  # 12 caractères larges : le champ doit les tenir
	decouverte.port_balise = 17899
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])

	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _attendre(0.3)
	await _shot("00_titre_multijoueur")
	titre.bouton_multijoueur.grab_focus()
	await _attendre(0.1)
	await _shot("01_titre_focus_multijoueur")
	titre.free()

	var ecran: Control = load("res://Scenes/EcranReseau.tscn").instantiate()
	ecran.port_jeu = 17890
	root.add_child(ecran)
	await _attendre(0.3)
	await _shot("02_reseau_vide")

	var futur := Time.get_ticks_msec() + 600000
	var zoe := {"version": reseau.version, "port": 7777, "nb_joueurs": 2, "places": 6, "manche_en_cours": false, "niveau": 1, "pseudo": "Zoé"}
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.20", zoe, futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.21", zoe.merged({"pseudo": "Anna", "nb_joueurs": 6}, true), futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.22", zoe.merged({"pseudo": "Bob", "version": "0.10"}, true), futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.23", zoe.merged({"pseudo": "Chloé", "manche_en_cours": true, "niveau": 2}, true), futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.24", zoe.merged({"pseudo": "MMMMMMMMMMMM", "nb_joueurs": 5, "niveau": 0}, true), futur)
	decouverte.parties_changees.emit()
	await _attendre(0.2)
	await _shot("03_reseau_liste")
	ecran.boutons_parties["192.168.1.20:7777"].grab_focus()
	await _attendre(0.1)
	await _shot("04_reseau_focus_partie")

	ecran.champ_ip.text = "lelion.local"
	ecran.rejoindre_par_ip()
	await _attendre(0.1)
	await _shot("05_ip_invalide")

	ecran.champ_ip.text = "127.0.0.1"
	ecran.port_jeu = 17891
	ecran.rejoindre_par_ip()
	await _attendre(0.1)
	await _shot("06_connexion")
	reseau.quitter()
	reseau.refuse.emit(reseau.REFUS_VERSION, "0.10")
	await _attendre(0.1)
	await _shot("07_refus_version")

	ecran.port_jeu = 17890
	ecran.heberger()
	await _attendre(0.1)
	await _shot("08_heberge")
	ecran.retour(false)

	params.definir_langue("en")
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.20", zoe, futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.21", zoe.merged({"pseudo": "Anna", "nb_joueurs": 6}, true), futur)
	decouverte.parties_changees.emit()
	await _attendre(0.2)
	await _shot("09_anglais")
	params.definir_langue("fr")
	ecran.free()

	var intrus := PacketPeerUDP.new()
	intrus.bind(decouverte.port_balise, "0.0.0.0")
	var ecran2: Control = load("res://Scenes/EcranReseau.tscn").instantiate()
	root.add_child(ecran2)
	await _attendre(0.3)
	await _shot("10_ecoute_impossible")
	ecran2.free()
	intrus.close()
	scores.effacer()
	quit(0)
```

- [ ] **Step 2 : les captures**

Run : `export PATH="/opt/homebrew/bin:$PATH"; S=<scratchpad>; mkdir -p $S/captures-12bis; timeout -k 5 120 godot --path . --rendering-driver opengl3 --script $S/captures_reseau.gd -- --dossier=$S/captures-12bis > "$TMPDIR/cap.log" 2>&1; echo "code $?"; grep -E "📸|SCRIPT ERROR|❌" "$TMPDIR/cap.log"`
Expected : `code 0`, 11 lignes 📸 : `00_…` et `01_…` en 2000×648, les autres en 2000×1125 ; aucune `SCRIPT ERROR`. (Une fenêtre s'ouvre le temps du script.)

- [ ] **Step 3 : regarder, puis montrer à l'utilisateur**

Vérifier sur les images (constaté en préparant le plan, à revoir sur la machine de l'exécutant) :
- `00` : Multijoueur en bas à droite, à hauteur de Jouer, sans toucher l'aide ; `01` : son contour de focus visible ;
- `02` : titre jaune, champ de pseudo avec « MMMMMMMMMMMM » entier, Héberger encadré (focus), cadre de la liste avec l'indice « Aucune partie trouvée. Pare-feu ? Réseau Privé ? Essaie par IP. », rangée Adresse IP / Rejoindre ;
- `03` : cinq lignes triées (Anna, Bob, Chloé, MMMMMMMMMMMM, Zoé) ; les trois grisées finissent par « complète », « version 0.10 », « manche en cours » ; « MMMMMMMMMMMM · 5/6 joueurs · Skyline » tient dans sa ligne ; `04` : la ligne de Zoé a le focus ;
- `05` : « Adresse IP invalide (exemple : 192.168.1.20) » en saumon, lisible (contour sombre) sur le bas orangé ; `06` : « Connexion à 127.0.0.1… », tout grisé, liste masquée, Retour encadré ;
- `07` : « Version différente de l'hôte (0.10) » ; `08` : « Partie hébergée : 1/6 joueurs. Les autres la voient dans leur liste, ou tapent ton adresse : … » sur deux lignes, adresses privées de la machine ;
- `09` : tout en anglais (Host a game, Games on the network, « Anna · 6/6 players · Metropolis · full ») ; `10` : « Recherche impossible : port 17899 déjà utilisé (un autre LeLion ouvert ?). Rejoins par IP. ».

Montrer les captures à l'utilisateur (au moins `00`, `03`, `07`, `08`, `10`) : **valider la mise en page de l'écran et la place du bouton Multijoueur est une décision de l'utilisateur**. Rien à commiter.

---

### Task 4 : feuille de route et spec

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`

**Interfaces:**
- Consumes : Tasks 1 à 3, Écarts 1 à 8.
- Produces : plus aucun point de vigilance « phase 12 » ; les restes vont aux phases 13 (garde-fou de `Reseau.rejoindre`, états d'attente de l'écran remplacés par le salon, 16:9 et pseudo déjà faits), 14 (hôte perdu en partie), 14 bis (durcissements du smoke test) et 19 (README pare-feu, captures dans `tests/screenshots.gd`).

- [ ] **Step 1 : les points « phase 12 » résolus**

1a. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, supprimer (remplacer par rien) :

```markdown
- **phase 12** : `Reseau.quitter()` (phase 11) ferme le pair et remet `OfflineMultiplayerPeer` ;
  `Reseau` le fait déjà de lui-même avant d'émettre `refuse`, `connexion_echouee` et `hote_perdu`
  (vérifié par `tests/reseau/lancer.sh`). `Titre._ready` doit encore appeler `Reseau.quitter()` à
  côté de `configurer_solo()` (retour au titre depuis l'écran Réseau, le salon, ou une manche
  quittée par le menu local, sans signal de `Reseau`), avec une vérification que le solo relancé
  depuis le titre après un hébergement fonctionne (`multiplayer.is_server()` vrai, un ennemi touche
  le lion) ; sans quoi ennemis, pastilles, gerbe et chocs cessent en silence ;
- **phase 12** (écran Réseau) : `Reseau` ne donne que des clés : les textes de `REFUS_VERSION`
  (« Version différente de l'hôte (%s) », avec `version_hote`), `REFUS_PLEIN`, `REFUS_MANCHE` et
  `REFUS_DEMANDE`, celui de `connexion_echouee` (spec §9 : après 5 s, retour à l'écran Réseau), de
  `hote_perdu` (« L'hôte a quitté la partie ») et d'un `heberger` qui renvoie une erreur
  (`ERR_CANT_CREATE` : « Impossible d'héberger : port 7777 occupé ») vont dans `traductions.csv` ;
  le pseudo mémorisé dans `Scores` est donné à `Reseau.pseudo` avant `heberger` / `rejoindre` ;
```

1b. Remplacer :

```markdown
- **phase 12** (écran Réseau, M8 de la revue de la phase 11) : `rejoindre()` passe un nom d'hôte tel
  quel à `create_client`, qui le résout de façon bloquante (`IP::resolve_hostname`) : une faute de
  frappe gèle le jeu plusieurs secondes sous Windows (NetBIOS/LLMNR). N'accepter que
  `adresse.is_valid_ip_address()` (ou résoudre hors du thread principal), et ajouter l'indice
  « Pare-feu de l'hôte ? Réseau Privé ? » au texte de `connexion_echouee`. Le premier `heberger()`
  déclenche aussi la fenêtre du pare-feu Windows Defender : si le joueur clique « Annuler », ou si
  le réseau est classé Public, les clients ne voient que `connexion_echouee` après 5 s, sans
  indice ; en phase 19, le README doit expliquer comment retirer une règle de blocage.
```

par :

```markdown
- **phase 13** (qui touche `Reseau.gd`, M8 de la revue de la phase 11) : l'écran Réseau n'envoie à
  `Reseau.rejoindre()` que des IPv4 validées (`Decouverte.adresse_ipv4`, phases 12 et 12 bis), mais
  `rejoindre()` lui-même passe encore tout nom d'hôte à `create_client`, qui le résout de façon
  bloquante (plusieurs secondes sous Windows pour une faute de frappe) : y refuser toute adresse
  que `Decouverte.adresse_ipv4` ne normalise pas (renvoyer `ERR_INVALID_PARAMETER`) ;
- **phase 19** (README, M8) : le premier `heberger()` déclenche la fenêtre du pare-feu Windows
  Defender sur l'hôte (port 7777), et la première ouverture de l'écran Réseau la déclenche aussi sur
  chaque client (écoute des balises sur le port 7778, phase 12). « Annuler », ou un réseau classé
  Public : l'hôte n'est pas joignable (les clients voient « Pas de réponse de l'hôte. Pare-feu de
  l'hôte ? Réseau Privé ? » après 5 s) ou le client ne voit aucune partie (« Aucune partie trouvée.
  Pare-feu ? Réseau Privé ? Essaie par IP. »). Le README explique comment autoriser LeLion en réseau
  Privé et retirer une règle de blocage, et que deux LeLion sur un même PC ne peuvent pas lister les
  parties tous les deux (« Recherche impossible : port 7778 déjà utilisé… Rejoins par IP. ») ;
- **phase 13** (salon, phase 12 bis) : l'écran Réseau garde, en attendant le salon, deux états
  d'attente (`HEBERGE` : « Partie hébergée : n/6 joueurs… » ; `INSCRIT` : « Connecté : tu es le
  joueur n… »). Le salon les remplace : un `heberger()` réussi et `Reseau.inscrit` changent de scène
  vers le salon (le `_exit_tree` de l'écran ferme l'écoute mais ne quitte pas le réseau ; seul Retour
  le fait). Un refus, un échec ou un hôte perdu pendant le salon ramène à l'écran Réseau avec son
  message (clés `RESEAU_*` déjà traduites) ;
- **phase 14** (hôte perdu en manche, phase 12 bis) : sur l'écran Réseau, « L'hôte a quitté la
  partie » ramène à son accueil (Écart 3 du plan 12 bis) ; en manche, spec §9 : message
  (`RESEAU_HOTE_PERDU`) puis retour au titre ;
```

- [ ] **Step 2 : les points des phases 13, 14 bis et 19 mis à jour**

2a. Remplacer :

```markdown
- **prochaine phase qui touche `tests/smoke_test.gd`** : petits durcissements issus de la revue de
  la phase 8 ter : vérifier que `create_client` renvoie `OK` avant le test de la garde hôte ;
```

par :

```markdown
- **phase 14 bis** (qui touche `tests/smoke_test.gd` ; la phase 12 bis, première à y revenir, les a
  laissés à la phase qui réécrit ces sections de contact) : petits durcissements issus de la revue de
  la phase 8 ter : vérifier que `create_client` renvoie `OK` avant le test de la garde hôte ;
```

2b. Remplacer :

```markdown
  bord de l'écran. L'hôte coupe déjà tout pseudo à `Reseau.PSEUDO_MAX` (12 caractères, phase 11) :
  borner aussi le champ de saisie à `Reseau.PSEUDO_MAX`, et vérifier sur capture qu'un pseudo de 12
  caractères larges (« MMMMMMMMMMMM ») tient dans l'écran à chaque bord, sinon clamper l'abscisse de
  l'étiquette ;
```

par :

```markdown
  bord de l'écran. L'hôte coupe déjà tout pseudo à `Reseau.PSEUDO_MAX` (12 caractères, phase 11) et
  le champ de saisie de l'écran Réseau s'y arrête (phase 12 bis, où « MMMMMMMMMMMM » tient dans le
  champ et dans la liste des parties) : vérifier sur capture qu'un pseudo de 12 caractères larges
  tient au-dessus du lion à chaque bord de l'écran, sinon clamper l'abscisse de l'étiquette ;
```

2c. Remplacer :

```markdown
  solo avant toute partie (`configurer_solo()` et l'écran 2000×648, phase 10 ter) ; le salon et
  l'écran Réseau passent eux-mêmes en 16:9 (spec §7 : `ReglesBataille.TAILLE_ECRAN`) ;
```

par :

```markdown
  solo avant toute partie (`configurer_solo()` et l'écran 2000×648, phase 10 ter) ; le salon passe
  lui-même en 16:9 (spec §7 : `ReglesBataille.TAILLE_ECRAN`), comme l'écran Réseau depuis la phase
  12 bis ;
```

2d. Remplacer :

```markdown
  le script à la main (la CI ne le lance pas). Les minuteries `null` du Spawner quand la partie se
  termine pendant l'intro sont corrigées depuis la phase 10 bis (vérifié par
  `tests/bataille_test.gd`) ;
```

par :

```markdown
  le script à la main (la CI ne le lance pas). Les minuteries `null` du Spawner quand la partie se
  termine pendant l'intro sont corrigées depuis la phase 10 bis (vérifié par
  `tests/bataille_test.gd`). Y verser aussi les captures de l'écran Réseau (script jetable du plan
  de la phase 12 bis, Task 3 : titre avec Multijoueur, liste, IP invalide, refus, hébergement,
  anglais, port des balises occupé) ;
```

Run : `grep -nE "^- (\*\*)?[Pp]hases? 12\b|prochaine phase qui touche .tests/smoke_test" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
Expected : aucune ligne (les points de la phase 12 sont résolus ou réaffectés).

- [ ] **Step 3 : la spec**

3a. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
- **Parcours** : Titre → *Multijoueur* → écran Réseau (pseudo mémorisé dans `Scores`,
  *Héberger*, liste des parties, *Rejoindre par IP*) → **Salon**.
```

par :

```markdown
- **Parcours** : Titre → *Multijoueur* (bouton en bas à droite, voisin de droite de *Jouer*) →
  écran Réseau, en 16:9 (pseudo mémorisé dans `Scores`, 12 caractères au plus, *Héberger*, liste
  des parties où les pleines, en cours ou d'une autre version sont grisées avec la raison,
  *Rejoindre par IP*, IPv4 seulement) → **Salon**. Le titre remet toujours le poste hors réseau
  (`Reseau.quitter()`) avant le solo.
```

3b. Remplacer :

```markdown
| Port 7777 déjà utilisé à l'hébergement | Message « Impossible d'héberger : port 7777 occupé » |
| Connexion à une IP qui ne répond pas | Délai de 5 s puis message, retour à l'écran Réseau |
| Version différente, salon plein, manche en cours | Refus explicite côté client |
| Aucune balise reçue | Liste vide avec l'indice « Pare-feu ? Réseau Privé ? Essaie par IP » |
| Hôte perdu | Message puis retour au titre |
```

par :

```markdown
| Port 7777 déjà utilisé à l'hébergement | Message « Impossible d'héberger : port 7777 occupé » |
| Port 7778 déjà utilisé (deux LeLion sur un PC) | Liste impossible : « Recherche impossible : port 7778 déjà utilisé (un autre LeLion ouvert ?). Rejoins par IP. » |
| Adresse saisie qui n'est pas une IPv4 (nom, faute de frappe) | Refusée sans rien tenter : « Adresse IP invalide (exemple : 192.168.1.20) » |
| Connexion à une IP qui ne répond pas | Délai de 5 s puis « Pas de réponse de l'hôte. Pare-feu de l'hôte ? Réseau Privé ? », retour à l'accueil de l'écran Réseau |
| Version différente, salon plein, manche en cours | Refus explicite côté client (textes traduits, clés `Reseau.REFUS_*`) |
| Aucune balise reçue | Liste vide avec l'indice « Pare-feu ? Réseau Privé ? Essaie par IP » |
| Hôte perdu | Message « L'hôte a quitté la partie » puis retour au titre (salon, manche) ; sur l'écran Réseau, retour à son accueil |
```

Run : `grep -n "7778 déjà utilisé\|Adresse IP invalide\|voisin de droite" docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`
Expected : trois lignes.

- [ ] **Step 4 : Commit**

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md
git commit -m "Feuille de route et spec : points de vigilance de la phase 12 résolus (titre hors réseau, textes des refus, adresse IPv4) ; garde-fou de Reseau.rejoindre et salon pour la phase 13, hôte perdu en manche pour la 14, durcissements du smoke test pour la 14 bis, pare-feu et captures pour la 19

<ligne fournie par l'environnement>"
```

---

## Sortie de phase

- Les quatre suites vertes 5 fois de suite localement, sans `SCRIPT ERROR` ni `SHADER ERROR`, puis le job CI vert sur la PR, pas « Test réseau » compris.
- ◉ : les 11 captures regardées et montrées à l'utilisateur, qui valide la mise en page (Task 3, Step 3).
- Les preuves M1 à M5 (Task 1) et celle de la Task 2 ont donné les `❌` attendus, sans qu'aucun fichier hors de la phase ait été touché.
- `git diff main --stat` : 5 fichiers de code, de scène, de traduction et de test (`Scenes/EcranReseau.tscn`, `Scripts/EcranReseau.gd`, `Scripts/Titre.gd`, `Assets/Traductions/traductions.csv`, `tests/smoke_test.gd`), plus `Scripts/EcranReseau.gd.uid`, les deux `.translation`, la spec et la feuille de route ; `git diff main --stat -- Scripts/Reseau.gd Scripts/Decouverte.gd` vide.
- Test à deux fenêtres, à la main, conseillé avant la revue : `godot --path . &` deux fois ; dans l'une, Multijoueur → Héberger ; l'autre voit la partie (une seconde au plus), la rejoint, « Connecté : tu es le joueur 2 » ; le message de l'hôte passe à « 2/6 joueurs » ; Retour chez l'hôte : le client lit « L'hôte a quitté la partie », et la partie quitte sa liste en 3 à 4 s. (La seconde fenêtre ne peut pas écouter les balises tant que la première écoute : c'est le cas « Recherche impossible » ; lancer d'abord l'hôte et l'y laisser héberger, ce qui ferme son écoute.)
- Rappeler à l'utilisateur : le bouton Multijoueur est le premier changement visible du multi ; une partie hébergée ou rejointe attend sur l'écran Réseau jusqu'au salon (phase 13), qui reprendra ces deux états ; sous Windows, la première fois, le pare-feu demandera l'autorisation (hôte et clients).
