# Phase 12 : découverte des parties (1/2), balise UDP et liste des parties, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** un hôte annonce sa partie sur le réseau local par une balise UDP (port 7778, une par seconde, tant qu'il héberge) et un poste qui écoute en tient la liste (entrées qui expirent 3 s après leur dernière balise) ; une adresse IPv4 saisie à la main est validée sans jamais résoudre de nom. Tout cela vit dans un autoload `Decouverte` sans interface : l'écran Réseau qui s'en sert est la phase 12 bis. Sortie : **tests verts (unitaires, smoke, bataille, réseau), test réseau vert 5 fois sous bash 5 et 5 fois sous bash 3.2**. **Le solo reste strictement identique.**

**Architecture:** `Scripts/Decouverte.gd` (autoload, après `Reseau`) ne nomme aucun autoload : il trouve `Reseau` et `GameState` par leur chemin, et ses fonctions statiques (encodage et décodage de la balise, liste des parties, destinations, adresse saisie) se testent seules. Une minuterie d'une seconde émet la balise **si et seulement si** `Reseau` est en ligne et hôte sur un pair ENet : personne n'a à la démarrer ni à l'arrêter, elle suit l'hébergement jusque dans le salon (phase 13) et s'arrête d'elle-même après `Reseau.quitter()`. La balise part d'une socket IPv4 vers `255.255.255.255` et vers la diffusion dirigée de chaque réseau privé de l'hôte (a.b.c.255) ; les tests la dirigent vers `127.0.0.1` sur un port à eux (`destinations_forcees`, `port_balise`). L'écoute (`ecouter()` / `arreter_ecoute()`) lit au plus 32 datagrammes par image dans `_process`, sans jamais bloquer, et signale `parties_changees`.

**Tech Stack:** Godot 4.7.2, GDScript typé, `PacketPeerUDP`, tests headless (`tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd` avec `--fixed-fps 60`, `tests/reseau/lancer.sh` + `tests/reseau/joueur.gd`, bash 3.2 et 5).

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1 unités, §4 découverte, §9 « aucune balise reçue », §10 test réseau, §13 broadcast filtré) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 12, points de vigilance « phase 12 ») · modèle du harnais réseau : `docs/superpowers/plans/2026-09-25-phase-11ter-test-reseau-ci.md` · suite : `docs/superpowers/plans/2026-09-25-phase-12bis-ecran-reseau.md` (écran Réseau, bouton Multijoueur, textes) · prérequis : phase 11 ter fusionnée (PR de `phase-11ter-test-reseau-ci` : harnais `--refus`/`--feu`, pas « Test réseau » en CI) ; nouvelle branche `phase-12-decouverte` depuis `main`.

## Écarts assumés

1. **La ligne 12 de la feuille de route est découpée en 12 et 12 bis.** Ses 5 fichiers (`Decouverte.gd`, `EcranReseau.tscn`, `EcranReseau.gd`, `Titre.gd`, `traductions.csv`) n'ont laissé aucune place aux tests, et il faut en plus `project.godot` (Écart 2) : 8 fichiers de code et de test en tout. Phase 12 (ce plan) : ➕ `Scripts/Decouverte.gd`, ✏️ `project.godot`, ✏️ `tests/unitaires.gd`, ✏️ `tests/reseau/joueur.gd`, ✏️ `tests/reseau/lancer.sh`. Phase 12 bis : ➕ `Scenes/EcranReseau.tscn`, ➕ `Scripts/EcranReseau.gd`, ✏️ `Scripts/Titre.gd`, ✏️ `Assets/Traductions/traductions.csv`, ✏️ `tests/smoke_test.gd`. La Task 3 met la feuille de route à jour ; le contrôle visuel ◉ passe à la 12 bis.
2. **`Decouverte` est un autoload** (`project.godot`, absent de la ligne de la feuille de route) : la balise doit survivre au changement de scène vers le salon (phase 13) et suivre `Reseau` sans que l'écran Réseau, puis le salon, aient à la relancer ou à la mettre à jour (un seul état, celui de `Reseau`). Un nœud de l'écran Réseau mourrait avec lui ; l'ajouter à `Reseau.gd` coûterait aussi un fichier et mélangerait transport et découverte.
3. **Format de la balise** : `LELION|<version>|<port de jeu>|<nb joueurs>|<places>|<manche 0/1>|<niveau>|<pseudo hôte>` au lieu de `LELION|<version>|<pseudo hôte>|<nb joueurs>|<id niveau>` (spec §4). Le pseudo, seul texte libre (il peut contenir `|`), passe **en dernier** : le découpage s'arrête au 7ᵉ séparateur et le garde entier. S'ajoutent le **port de jeu** (un client rejoint exactement ce qu'il a entendu ; les tests hébergent sur 17778 et suivants, jamais le 7777), les **places** et la **manche en cours** (l'écran grise une partie pleine ou en cours avant toute tentative, dans l'ordre des refus de l'hôte). Le niveau est l'index de `GameState.niveau_courant` (le dernier choix du titre de l'hôte, puis celui du salon en phase 13). La spec est mise à jour (Task 3).
4. **Destinations** : `255.255.255.255` plus la diffusion dirigée **a.b.c.255** de chaque adresse IPv4 privée de l'hôte (169.254.255.255 pour une liaison directe sans DHCP). Sous Windows, la diffusion limitée ne sort que par une seule interface (celle de la route par défaut, parfois un VPN ou une carte virtuelle) ; Godot ne donne pas les masques de sous-réseau (`IP.get_local_interfaces()` n'a que les adresses), d'où le /24 supposé (le cas des box) ; un réseau en /16 reçoit toujours la diffusion limitée.
5. **Diffusion en test** : le scénario 6 (en CI) dirige la balise vers `127.0.0.1` (`destinations_forcees`) : même code que le jeu à la liste des destinations près. La vraie diffusion (scénario 7) ne tourne qu'avec `DIFFUSION=1`, hors CI : mesurée en préparant ce plan sur macOS (une diffusion vers 255.255.255.255 et a.b.c.255 revient bien aux sockets locales, source = l'adresse Wi-Fi du Mac), jamais sur le runner Ubuntu, dont un échec rendrait la CI rouge pour une raison d'environnement. L'essayer en CI est réaffecté à la phase 19 (qui touche `ci.yml`), Task 3.
6. **Port des balises occupé** (deux LeLion sur un même PC, ou un autre programme) : `PacketPeerUDP.bind` de Godot ne pose pas `SO_REUSEADDR` (mesuré : second `bind` sur le même port → `ERR_UNAVAILABLE`, 2) ; `ecouter()` renvoie l'erreur, garde `erreur_ecoute` et n'écoute pas, sans rien planter : l'écran Réseau dira « rejoins par IP » (phase 12 bis).
7. **L'adresse saisie est validée par `Decouverte.adresse_ipv4()`**, utilisée par l'écran (phase 12 bis), et non dans `Reseau.rejoindre()` (`Reseau.gd` n'est pas dans les fichiers) : tant que l'écran est son seul appelant avec une saisie, aucun nom n'atteint `create_client`. Le garde-fou dans `Reseau.rejoindre` va à la phase 13, qui touche `Reseau.gd` (Task 3).
8. **Pas de nettoyage préalable (« Step 0 »)** : `tests/unitaires.gd` (≈ 1 070 lignes) ne reçoit qu'un appel et deux fonctions à la fin ; `joueur.gd` (≈ 300 lignes) un rôle et deux options ; lire les deux par morceaux (`offset` / `limit`).

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`, sur la branche `phase-12-decouverte`.
- Fichiers de la phase (5) : ➕ `Scripts/Decouverte.gd` (et son `.uid` généré, commité avec lui), ✏️ `project.godot`, ✏️ `tests/unitaires.gd`, ✏️ `tests/reseau/joueur.gd`, ✏️ `tests/reseau/lancer.sh`. La spec, la feuille de route et les plans ne comptent pas. **`Scripts/Reseau.gd` n'est jamais modifié, même temporairement** ; `git diff main --stat -- Scripts/` ne montre que `Decouverte.gd` et `Decouverte.gd.uid`.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations (y compris dans `lancer.sh`).
- Solo strictement identique : hors réseau, `Decouverte` n'émet rien (sa minuterie ne fait que constater que `Reseau` n'est pas en ligne) et n'écoute rien tant qu'on ne le lui demande pas ; aucune scène ne change ; le smoke test n'est pas modifié et reste vert.
- Jamais le port 7777 ni le 7778 d'une vraie partie dans un test : scénario n du test réseau sur `port_de_base + n` (jeu) et `port_de_base + 1000 + n` (balises) ; les tests unitaires sur 17792 (jeu) et 17891 (balises).
- Rien de bloquant sur le thread principal : sockets `PacketPeerUDP` non bloquantes, adresses IP littérales seulement (jamais `IP.resolve_hostname` ni de nom passé à `create_client` / `set_dest_address`).
- `lancer.sh` tourne sous bash 3.2 (`/bin/bash` du Mac) et bash 5 (Ubuntu) : pas de `mapfile`, `declare -A`, `${var,,}`, `wait -n`. Chaque processus Godot sous `timeout -k 5 "$DELAI"` ; chaque attente guette un événement, 15 s au plus ; seules restent de courtes fenêtres de vérification d'absence (0,3 s après l'envoi de datagrammes étrangers), qui ne peuvent pas donner de faux rouge.
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : `tests/unitaires.gd` et `tests/reseau/joueur.gd` récupèrent `Decouverte`, `Reseau` et `GameState` par `root.get_node(…)` et ne les nomment pas ; ils peuvent nommer `EtatPartie`, `PacketPeerUDP`, `IP`, `OS`, `Time`.
- **Toujours lancer un test Godot avec `timeout`** et chercher les erreurs dans la sortie :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/unitaires.gd; O=""; timeout -k 5 300 godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/smoke_test.gd; O=""` ou `T=tests/bataille_test.gd; O="--fixed-fps 60"` ; le test réseau : `timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== |✅" "$TMPDIR/r.log"`). Une `SCRIPT ERROR` ne change pas le code de sortie (la fonction fautive s'arrête, la suite continue) ; si elle interrompt `_run` avant `quit()`, le processus reste bloqué jusqu'au `timeout` (code 124). Après la création de `Decouverte.gd` : `godot --headless --import .` avant les tests. Bruit connu : « ObjectDB instances were leaked », « resources still in use at exit », dans les tests unitaires `ERROR: Couldn't create an ENet host.` (port occupé, phase 11) et deux `ERROR: Territoire.tamponner : index de joueur hors plage`, dans le journal d'un écouteur `Unicode parsing error … (ff)` (datagramme étranger volontairement invalide).
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`**.
- Les quatre suites se valident sur **5 passages consécutifs verts** ; le test réseau en plus 5 fois sous `/bin/bash` (3.2) et une fois avec `DIFFUSION=1` (sur un Mac en Wi-Fi ou en Ethernet).
- Les mutations de preuve ne touchent que du code neuf de cette phase (`Scripts/Decouverte.gd`, déjà commité à ce moment-là) et sont annulées par `git checkout -- Scripts/Decouverte.gd` : **jamais commitées**.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Une partie fantôme qui reste dans les listes après le départ de l'hôte** (la balise continue après `Reseau.quitter()`, par exemple tant que le processus vit) : les joueurs cliquent dessus et attendent 5 s pour rien. → unitaire « après quitter(), la balise s'arrête et sa socket se ferme » (Task 1) ; scénario 6 : l'hôte vit encore 6 s après avoir quitté le réseau et la partie doit disparaître au plus 5 s après son départ ; une balise répétée après `quitter()` ⇒ « ❌ … (9.0 s) » (Task 2, Step 4).
2. **Un datagramme étranger ou forgé sur le port 7778** (autre programme, balise tronquée, champs hors plage, version à rallonge, pseudo avec forçage de sens, déluge) qui ajoute une partie, casse la liste ou gèle l'image. → unitaire « 19 datagrammes invalides, aucun pris pour une balise », « le pseudo d'une balise est nettoyé… », « liste pleine (16 parties) : une nouvelle est ignorée… » (Task 1) ; écouteur du scénario 6 : « des datagrammes qui ne sont pas des balises n'ajoutent aucune partie » sur une vraie socket (Task 2).
3. **Deux LeLion sur un même PC** : le second ne peut pas ouvrir le port des balises ; il doit le savoir et ne rien planter. → unitaire « port déjà pris : ecouter() renvoie l'erreur (2) sans planter ni écouter » (Task 1) ; poste `occupe6` du scénario 6 (Task 2).
4. **Un poste qui émet une balise sans héberger** (le solo, ou un client : il apparaîtrait comme une partie, avec 0 joueur). → unitaires « hors réseau (le solo), aucune balise », « un client n'émet aucune balise », qui comptent les datagrammes bruts (une balise invalide compterait aussi) ; sans la garde `is_server()` ⇒ « ❌ un client n'émet aucune balise » (Task 1, Step 4).
5. **Une liste qui clignote ou se trompe de partie** : entrée remplacée à chaque balise (le bouton perdrait le focus en 12 bis), expiration un cran trop tôt, deux hôtes sur la même IP confondus. → unitaires « la même balise répétée rafraîchit l'heure sans changer la liste affichée », « une partie vue il y a 3 s pile reste », « même port de jeu, autre adresse : une autre partie » (Task 1) ; écouteur : « la partie disparaît de la liste 3 s après sa dernière balise (3.0x s) » (Task 2).

---

### Task 0 : vérification des plans

Ce plan et celui de la phase 12 bis ont été commités par le commit de planification de la phase 12 : ne pas les recommiter, **ne jamais les modifier** (ni réécriture, ni résumé). Vérifier seulement que la phase 11 ter est fusionnée : `git log --oneline main -- tests/reseau/lancer.sh | head -3` montre ses commits, et `grep -n "feu" tests/reseau/lancer.sh | head -2` trouve l'option `--feu`. Sinon, s'arrêter et le signaler.

---

### Task 1 : l'autoload `Decouverte` (balise, liste, adresse saisie) et ses tests unitaires

**Files:**
- Create: `Scripts/Decouverte.gd` (+ `Scripts/Decouverte.gd.uid` généré par l'import)
- Modify: `project.godot` (section `[autoload]`)
- Test: `tests/unitaires.gd` (`_run`, deux fonctions à la fin)

**Interfaces:**
- Consumes : `Reseau` (autoload, phase 11) par son chemin `/root/Reseau` : `en_ligne() -> bool`, `version: String`, `inscrits: Dictionary[int, Dictionary]` (fiche `{index, couleur, pseudo}`), `places: int`, `manche_en_cours: bool` ; en constantes et statiques par `preload("res://Scripts/Reseau.gd")` : `JEU`, `pseudo_ou_defaut(texte, index)` ; `GameState.niveau_courant` par `/root/GameState` ; `EtatPartie.NB_JOUEURS_MAX`, `EtatPartie.NIVEAUX` ; `ENetMultiplayerPeer.host.get_local_port()`.
- Produces (autoload `Decouverte`, que la phase 12 bis et le harnais réseau utilisent) :
  - `signal parties_changees()` ;
  - constantes `PORT_BALISE := 7778`, `PERIODE_BALISE := 1.0`, `DELAI_EXPIRATION := 3.0`, `DIFFUSION := "255.255.255.255"`, `TAILLE_BALISE_MAX := 512`, `PARTIES_MAX := 16`, `PAQUETS_PAR_IMAGE_MAX := 32` ;
  - `var port_balise: int`, `var destinations_forcees: PackedStringArray`, `var parties: Dictionary[String, Dictionary]` (clé « ip:port », fiche `{version, port, nb_joueurs, places, manche_en_cours, niveau, pseudo, ip, vue_a}`), `var erreur_ecoute: Error` ;
  - `ecouter() -> Error`, `arreter_ecoute() -> void`, `ecoute_active() -> bool`, `parties_triees() -> Array[Dictionary]` ;
  - statiques : `encoder_balise(version: String, port: int, nb_joueurs: int, places: int, manche_en_cours: bool, niveau: int, pseudo: String) -> PackedByteArray`, `decoder_balise(donnees: PackedByteArray) -> Dictionary`, `enregistrer_partie(liste: Dictionary[String, Dictionary], ip: String, fiche: Dictionary, maintenant_ms: int) -> bool`, `purger_parties(liste: Dictionary[String, Dictionary], maintenant_ms: int, delai_ms: int) -> bool`, `destinations_balise(adresses: PackedStringArray) -> PackedStringArray`, `adresses_privees(adresses: PackedStringArray) -> PackedStringArray`, `adresse_ipv4(texte: String) -> String` ;
  - privés que les tests appellent : `_emettre_balise()`, `_emetteur: PacketPeerUDP` (nul quand rien n'émet).

- [ ] **Step 1 : le test**

1a. Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_palette()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_palette()
	_tester_decouverte()
	print("== %d échec(s) ==" % _echecs)
```

1b. Ajouter à la fin de `tests/unitaires.gd` (après `_oklab`) :

```gdscript


func _tester_decouverte() -> void:
	print("-- Découverte (balise, liste des parties, adresse saisie)")
	var decouverte: Node = root.get_node("Decouverte")  # autoload : jamais nommé (compilé avant lui)
	var reseau: Node = root.get_node("Reseau")
	var version: String = reseau.version

	# Balise : un texte, le pseudo (seul texte libre) en dernier, relu tel quel
	var balise: PackedByteArray = decouverte.encoder_balise(version, 7777, 2, 6, false, 1, "Zoé|la|reine")
	_check(balise.get_string_from_utf8() == "LELION|%s|7777|2|6|0|1|Zoé|la|reine" % version,
		"la balise est « LELION|version|port|joueurs|places|manche|niveau|pseudo » (%s)" % balise.get_string_from_utf8())
	var fiche: Dictionary = decouverte.decoder_balise(balise)
	_check(fiche == {"version": version, "port": 7777, "nb_joueurs": 2, "places": 6, "manche_en_cours": false, "niveau": 1, "pseudo": "Zoé|la|reine"},
		"une balise se relit telle quelle, même avec des « | » dans le pseudo (%s)" % [fiche])
	var pleine: Dictionary = decouverte.decoder_balise(decouverte.encoder_balise(version, 17778, 6, 6, true, 2, "   "))
	_check(pleine.get("manche_en_cours") == true and pleine.get("nb_joueurs") == 6 and pleine.get("pseudo") == "Joueur 1",
		"manche en cours et partie pleine se relisent ; un pseudo vide devient « Joueur 1 » (l'hôte)")
	var hostile := "\u202eAbc\u0007defghijklmnopq"
	_check(decouverte.decoder_balise(decouverte.encoder_balise(version, 7777, 1, 6, false, 0, hostile)).get("pseudo") == reseau.pseudo_valide(hostile),
		"le pseudo d'une balise est nettoyé comme celui d'un joueur (forçages de sens, contrôles, %d caractères)" % reseau.PSEUDO_MAX)

	# Tout ce qui n'est pas une balise valide est ignoré (autre programme, balise tronquée ou forgée)
	var trop_longue := PackedByteArray()
	trop_longue.resize(decouverte.TAILLE_BALISE_MAX + 1)
	trop_longue.fill(65)
	var invalides: Array[PackedByteArray] = [PackedByteArray(), trop_longue]
	for texte: String in ["LELION", "AUTRE|0.11|7777|1|6|0|0|x", "LELION|0.11|7777|1|6|0|0",
			"LELION|0.11|0|1|6|0|0|x", "LELION|0.11|65536|1|6|0|0|x", "LELION|0.11|port|1|6|0|0|x",
			"LELION|0.11|7777|0|6|0|0|x", "LELION|0.11|7777|7|6|0|0|x", "LELION|0.11|7777|1|1|0|0|x",
			"LELION|0.11|7777|3|2|0|0|x", "LELION|0.11|7777|1|7|0|0|x", "LELION|0.11|7777|1|6|2|0|x",
			"LELION|0.11|7777|1|6|0|-1|x", "LELION|0.11|7777|1|6|0|%d|x" % EtatPartie.NIVEAUX.size(),
			"LELION||7777|1|6|0|0|x", "LELION|0.11 beta|7777|1|6|0|0|x", "LELION|0123456789abcdefg|7777|1|6|0|0|x"]:
		invalides.append(texte.to_utf8_buffer())
	var acceptees := invalides.filter(func(d: PackedByteArray) -> bool: return not decouverte.decoder_balise(d).is_empty())
	_check(acceptees.is_empty(), "%d datagrammes invalides, aucun pris pour une balise (%s)"
		% [invalides.size(), acceptees.map(func(d: PackedByteArray) -> String: return d.get_string_from_utf8())])

	# La liste : une partie par adresse et port de jeu, rafraîchie, changée, expirée, plafonnée
	var liste: Dictionary[String, Dictionary] = {}
	_check(decouverte.enregistrer_partie(liste, "192.168.1.20", fiche, 1000) and liste.size() == 1
		and liste["192.168.1.20:7777"].ip == "192.168.1.20" and liste["192.168.1.20:7777"].vue_a == 1000,
		"une partie nouvelle entre dans la liste, avec son adresse et l'heure de sa balise")
	_check(not decouverte.enregistrer_partie(liste, "192.168.1.20", fiche, 1900) and liste["192.168.1.20:7777"].vue_a == 1900,
		"la même balise répétée rafraîchit l'heure sans changer la liste affichée")
	var arrivee := fiche.duplicate()
	arrivee["nb_joueurs"] = 3
	_check(decouverte.enregistrer_partie(liste, "192.168.1.20", arrivee, 2500) and liste["192.168.1.20:7777"].nb_joueurs == 3,
		"une balise différente (un joueur de plus) change la liste")
	_check(decouverte.enregistrer_partie(liste, "192.168.1.21", fiche, 2500) and liste.size() == 2,
		"même port de jeu, autre adresse : une autre partie")
	_check(not decouverte.purger_parties(liste, 5500, 3000) and liste.size() == 2, "une partie vue il y a 3 s pile reste")
	_check(decouverte.purger_parties(liste, 5501, 3000) and liste.is_empty(), "sans balise depuis plus de 3 s, les parties disparaissent")
	for i in range(decouverte.PARTIES_MAX):
		decouverte.enregistrer_partie(liste, "10.0.0.%d" % (i + 1), fiche, 0)
	_check(not decouverte.enregistrer_partie(liste, "10.0.1.1", fiche, 0) and liste.size() == decouverte.PARTIES_MAX
		and not decouverte.enregistrer_partie(liste, "10.0.0.1", fiche, 10) and liste["10.0.0.1:7777"].vue_a == 10,
		"liste pleine (%d parties) : une nouvelle est ignorée, les connues se rafraîchissent encore" % decouverte.PARTIES_MAX)

	# Destinations de la balise et adresses de l'hôte
	var adresses := PackedStringArray(["fe80:0:0:0:0:0:0:1", "127.0.0.1", "192.168.1.17", "10.0.3.4", "172.20.1.2",
		"172.32.0.1", "8.8.8.8", "169.254.10.20", "192.168.1.30"])
	_check(decouverte.adresses_privees(adresses) == PackedStringArray(["192.168.1.17", "10.0.3.4", "172.20.1.2", "169.254.10.20", "192.168.1.30"]),
		"les adresses de l'hôte à afficher : IPv4 privées ou de liaison locale seulement (%s)" % decouverte.adresses_privees(adresses))
	_check(decouverte.destinations_balise(adresses) == PackedStringArray(["255.255.255.255", "192.168.1.255", "10.0.3.255", "172.20.1.255", "169.254.255.255"]),
		"la balise part en diffusion limitée et dirigée, une fois par réseau privé (%s)" % decouverte.destinations_balise(adresses))
	_check(decouverte.destinations_balise(PackedStringArray()) == PackedStringArray(["255.255.255.255"]),
		"sans adresse privée connue, la diffusion limitée seule")

	# Adresse saisie : IPv4 seulement, normalisée ; jamais un nom (résolution bloquante)
	var valides := {"192.168.1.20": "192.168.1.20", " 192.168.001.010 ": "192.168.1.10", "127.0.0.1": "127.0.0.1", "10.0.0.255": "10.0.0.255"}
	_check(valides.keys().all(func(t: String) -> bool: return decouverte.adresse_ipv4(t) == valides[t]),
		"une adresse IPv4 saisie est acceptée, sans zéros ni espaces superflus")
	var refusees := ["", "192.168.1", "192.168.1.256", "192.168.1.2.3", "localhost", "lelion.local", "::1", "0.1.2.3",
		"224.0.0.1", "255.255.255.255", "1.2.3.-4", "1.2.3.+4", "1.2.3.4a", "1..3.4", "1234.1.1.1", "１.２.３.４"]
	var passees := refusees.filter(func(t: String) -> bool: return not decouverte.adresse_ipv4(t).is_empty())
	_check(passees.is_empty(), "noms d'hôte, IPv6, adresses incomplètes, hors plage ou de diffusion refusés (%s)" % [passees])

	# Écoute : un port libre, puis déjà pris (deux LeLion sur un même PC) : une erreur, jamais un plantage
	var port_balise := 17891
	decouverte.port_balise = port_balise
	_check(decouverte.ecouter() == OK and decouverte.ecoute_active() and decouverte.erreur_ecoute == OK, "l'écoute s'ouvre sur un port libre")
	var intrus := PacketPeerUDP.new()
	_check(intrus.bind(port_balise, "0.0.0.0") != OK, "(pré-condition) l'écoute tient son port : un autre ne peut pas l'ouvrir")
	var signaux := [0]
	var compter := func() -> void: signaux[0] += 1
	decouverte.parties_changees.connect(compter)
	decouverte.parties["10.0.0.9:7777"] = fiche.merged({"ip": "10.0.0.9", "vue_a": 0})
	decouverte.arreter_ecoute()
	_check(not decouverte.ecoute_active() and decouverte.parties.is_empty() and signaux[0] == 1,
		"arrêter l'écoute ferme le port et vide la liste, signalé une fois")
	decouverte.arreter_ecoute()
	_check(signaux[0] == 1, "arrêter une écoute déjà arrêtée ne signale rien")
	_check(intrus.bind(port_balise, "0.0.0.0") == OK, "le port d'écoute est rendu à la fermeture")
	var erreur: int = decouverte.ecouter()
	_check(erreur != OK and not decouverte.ecoute_active() and decouverte.erreur_ecoute == erreur,
		"port déjà pris : ecouter() renvoie l'erreur (%d) sans planter ni écouter" % erreur)
	intrus.close()
	decouverte.parties_changees.disconnect(compter)

	# Balise de l'hôte : ce qu'émet `Reseau` en ligne et hôte, rien hors réseau ni chez un client
	var recepteur := PacketPeerUDP.new()
	_check(recepteur.bind(port_balise, "0.0.0.0") == OK, "(pré-condition) un récepteur écoute les balises de test")
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	var gs: Node = root.get_node("GameState")
	gs.niveau_courant = 2
	decouverte._emettre_balise()
	_check(_datagrammes_recus(recepteur).is_empty() and decouverte._emetteur == null, "hors réseau (le solo), aucune balise")
	reseau.pseudo = "Zoé"
	reseau.places = 4
	var port_jeu := 17792
	_check(reseau.heberger(port_jeu) == OK, "(pré-condition) ce poste héberge sur le port %d" % port_jeu)
	reseau.manche_en_cours = true
	decouverte._emettre_balise()
	var recus := _datagrammes_recus(recepteur)
	var recue: Dictionary = decouverte.decoder_balise(recus[0]) if recus.size() == 1 else {}
	_check(recue == {"version": version, "port": port_jeu, "nb_joueurs": 1, "places": 4, "manche_en_cours": true, "niveau": 2, "pseudo": "Zoé"},
		"l'hôte émet une balise : version, port de jeu, joueurs inscrits, places, manche, niveau, pseudo (%s)" % [recue])
	reseau.quitter()
	decouverte._emettre_balise()
	_check(_datagrammes_recus(recepteur).is_empty() and decouverte._emetteur == null, "après quitter(), la balise s'arrête et sa socket se ferme")
	_check(reseau.rejoindre("127.0.0.1", port_jeu + 1) == OK and not root.multiplayer.is_server(), "(pré-condition) ce poste est un client qui attend son hôte")
	decouverte._emettre_balise()
	_check(_datagrammes_recus(recepteur).is_empty(), "un client n'émet aucune balise")
	reseau.quitter()
	recepteur.close()
	reseau.pseudo = ""
	reseau.places = EtatPartie.NB_JOUEURS_MAX
	gs.niveau_courant = 0
	decouverte.destinations_forcees = PackedStringArray()
	decouverte.port_balise = decouverte.PORT_BALISE


## Les datagrammes arrivés sur `recepteur` dans les 0,3 s, quels qu'ils soient (valides ou non :
## « aucune balise » veut dire aucun datagramme). Attente active et bornée : sur localhost, un
## datagramme émis est déjà là ou presque ; 0,3 s de silence suffit à conclure qu'il n'y en a pas.
func _datagrammes_recus(recepteur: PacketPeerUDP) -> Array[PackedByteArray]:
	var recus: Array[PackedByteArray] = []
	var fin := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < fin:
		while recepteur.get_available_packet_count() > 0:
			recus.append(recepteur.get_packet())
		OS.delay_msec(5)
	return recus
```

Notes pour l'exécutant : `"\u202e…\u0007…"` s'écrit tel quel (échappements GDScript, pas de caractère invisible dans le fichier) ; `"１.２.３.４"` est en chiffres pleine largeur (U+FF11…), à recopier tels quels. Les appels synchrones (sans `await`) laissent la minuterie de `Decouverte` à l'arrêt pendant la section : seules les émissions appelées à la main partent.

- [ ] **Step 2 : le test échoue**

Run : `export PATH="/opt/homebrew/bin:$PATH"; timeout -k 5 60 godot --headless --script tests/unitaires.gd > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|Decouverte|== " "$TMPDIR/t.log" | head`
Expected (mesuré) : `ERROR: Node not found: "Decouverte" (relative to "/root").` puis `SCRIPT ERROR: Attempt to call function 'encoder_balise' in base 'null instance' on a null instance.` ; la section s'arrête là et le reste finit en `== 0 échec(s) ==`, `code 0` : c'est la `SCRIPT ERROR` qui fait l'échec (la CI la cherche). Toutes les sections précédentes restent vertes.

- [ ] **Step 3 : l'autoload**

3a. Créer `Scripts/Decouverte.gd` :

```gdscript
extends Node
## Découverte des parties sur le réseau local (spec §4) : la balise UDP de l'hôte et l'écoute de
## l'écran Réseau.
##
## Balise : tant que ce poste héberge (`Reseau` en ligne et hôte), une fois par PERIODE_BALISE, un
## datagramme texte vers le port PORT_BALISE de chaque destination de diffusion :
## `LELION|<version>|<port de jeu>|<nb joueurs>|<places>|<manche 0/1>|<niveau>|<pseudo hôte>`.
## Le pseudo, seul texte libre, vient en dernier : il peut contenir `|` sans décaler les autres
## champs. Personne n'a à démarrer ni à arrêter la balise : elle suit l'état de `Reseau` (un
## `Reseau.quitter()` l'arrête à la période suivante), jusque dans le salon (phase 13).
##
## Écoute : `ecouter()` ouvre le port PORT_BALISE (l'écran Réseau, tant qu'il cherche des parties),
## `arreter_ecoute()` le ferme. Les balises reçues remplissent `parties`, par « ip:port de jeu » ;
## une partie dont la balise ne revient pas pendant DELAI_EXPIRATION disparaît. Rien ne bloque le
## thread principal : sockets non bloquantes, adresses IP littérales (jamais de résolution de nom).
##
## Autoload : les tests `--script` le récupèrent par `root.get_node("Decouverte")` et ne le nomment
## pas. Ce script ne nomme aucun autoload (il trouve `Reseau` et `GameState` par leur chemin) : les
## fonctions statiques se testent sans eux.

## Une partie est apparue, a disparu, ou sa balise a changé (joueurs, manche, niveau…).
signal parties_changees()

const _Reseau := preload("res://Scripts/Reseau.gd")

const PORT_BALISE := 7778
## Secondes entre deux balises (spec §4 : toutes les secondes).
const PERIODE_BALISE := 1.0
## Une partie sans balise depuis ce délai, en secondes, disparaît de la liste (spec §4 : 3 s).
const DELAI_EXPIRATION := 3.0
## Adresse de diffusion limitée : tout le segment de l'interface par défaut.
const DIFFUSION := "255.255.255.255"
## Au-delà, un datagramme n'est pas une balise (le décodage reste borné, quel que soit l'émetteur).
const TAILLE_BALISE_MAX := 512
## Parties gardées au plus : des balises forgées ne font pas grossir la liste sans fin.
const PARTIES_MAX := 16
## Datagrammes lus au plus par image : un déluge sur le port ne gèle pas l'image, le reste attend
## l'image suivante.
const PAQUETS_PAR_IMAGE_MAX := 32
const _NB_CHAMPS := 8
## Une version reste courte et sans séparateur (elle s'affiche dans le refus « version différente »).
const _MOTIF_VERSION := "^[0-9A-Za-z._-]{1,16}$"

## Port des balises, émises et écoutées. Modifiable par les tests (jamais le 7778 d'une vraie partie).
var port_balise := PORT_BALISE
## Si non vide, les destinations des balises à la place de la diffusion (les tests : 127.0.0.1).
var destinations_forcees := PackedStringArray()
## Parties entendues, par « ip:port » : {version, port, nb_joueurs, places, manche_en_cours, niveau,
## pseudo, ip, vue_a (Time.get_ticks_msec de la dernière balise)}.
var parties: Dictionary[String, Dictionary] = {}
## Résultat du dernier `ecouter()` : OK, ou l'erreur du port (déjà pris par un autre programme ou
## un autre LeLion sur ce PC).
var erreur_ecoute := OK

var _ecouteur: PacketPeerUDP
var _emetteur: PacketPeerUDP
var _destinations := PackedStringArray()
static var _motif_version: RegEx = RegEx.create_from_string(_MOTIF_VERSION)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var minuterie := Timer.new()
	minuterie.wait_time = PERIODE_BALISE
	minuterie.timeout.connect(_emettre_balise)
	add_child(minuterie)
	minuterie.start()


## Ouvre l'écoute des balises sur `port_balise` (repart d'une liste vide). Renvoie OK, ou l'erreur
## si le port est déjà pris : rien ne plante, `ecoute_active()` reste faux, `erreur_ecoute` la garde.
func ecouter() -> Error:
	arreter_ecoute()
	var ecouteur := PacketPeerUDP.new()
	# Une socket IPv4 (et non « * », à double pile sous Windows) : les diffusions IPv4 y arrivent.
	erreur_ecoute = ecouteur.bind(port_balise, "0.0.0.0")
	if erreur_ecoute == OK:
		_ecouteur = ecouteur
	return erreur_ecoute


## Ferme l'écoute et oublie les parties entendues. Sans effet si rien n'écoute.
func arreter_ecoute() -> void:
	if _ecouteur != null:
		_ecouteur.close()
		_ecouteur = null
	if not parties.is_empty():
		parties.clear()
		parties_changees.emit()


func ecoute_active() -> bool:
	return _ecouteur != null


## Les parties entendues, triées par pseudo puis par adresse (un ordre stable pour la liste).
func parties_triees() -> Array[Dictionary]:
	var liste: Array[Dictionary] = []
	liste.assign(parties.values())
	liste.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ordre: int = a.pseudo.nocasecmp_to(b.pseudo)
		return ordre < 0 if ordre != 0 else "%s:%d" % [a.ip, a.port] < "%s:%d" % [b.ip, b.port])
	return liste


func _process(_delta: float) -> void:
	if _ecouteur == null:
		return
	var maintenant := Time.get_ticks_msec()
	var change := false
	var lus := 0
	while lus < PAQUETS_PAR_IMAGE_MAX and _ecouteur.get_available_packet_count() > 0:
		lus += 1
		var donnees := _ecouteur.get_packet()
		var fiche := decoder_balise(donnees)
		if not fiche.is_empty():
			change = enregistrer_partie(parties, _ecouteur.get_packet_ip(), fiche, maintenant) or change
	change = purger_parties(parties, maintenant, int(DELAI_EXPIRATION * 1000.0)) or change
	if change:
		parties_changees.emit()


## Chaque seconde : une balise si ce poste héberge, sinon la socket d'émission se ferme.
func _emettre_balise() -> void:
	var reseau := get_node_or_null(^"/root/Reseau")
	var pair := multiplayer.multiplayer_peer
	if reseau == null or not reseau.en_ligne() or not multiplayer.is_server() or not (pair is ENetMultiplayerPeer):
		_fermer_emetteur()
		return
	if _emetteur == null:
		_ouvrir_emetteur()
	var partie := get_node_or_null(^"/root/GameState")
	var hote: Dictionary = reseau.inscrits.get(multiplayer.get_unique_id(), {})
	var balise := encoder_balise(reseau.version, (pair as ENetMultiplayerPeer).host.get_local_port(),
		reseau.inscrits.size(), reseau.places, reseau.manche_en_cours,
		partie.niveau_courant if partie != null else 0, hote.get("pseudo", ""))
	for destination in _destinations:
		# Une destination injoignable (interface tombée, pas de route) n'empêche pas les autres.
		if _emetteur.set_dest_address(destination, port_balise) == OK:
			_emetteur.put_packet(balise)


func _ouvrir_emetteur() -> void:
	_emetteur = PacketPeerUDP.new()
	_emetteur.set_broadcast_enabled(true)
	_emetteur.bind(0, "0.0.0.0")  # port quelconque, IPv4 : la diffusion part de cette socket
	# Les interfaces sont relues à chaque session hébergée (câble branché, Wi-Fi changé entre-temps).
	_destinations = destinations_forcees if not destinations_forcees.is_empty() \
		else destinations_balise(IP.get_local_addresses())


func _fermer_emetteur() -> void:
	if _emetteur != null:
		_emetteur.close()
		_emetteur = null


## La balise d'une partie, en octets UTF-8.
static func encoder_balise(version: String, port: int, nb_joueurs: int, places: int, manche_en_cours: bool,
		niveau: int, pseudo: String) -> PackedByteArray:
	return "|".join(PackedStringArray([_Reseau.JEU, version, str(port), str(nb_joueurs), str(places),
		"1" if manche_en_cours else "0", str(niveau), pseudo])).to_utf8_buffer()


## La fiche d'une balise reçue : {version, port, nb_joueurs, places, manche_en_cours, niveau,
## pseudo} ; un dictionnaire vide pour tout ce qui n'est pas une balise valide (autre programme,
## datagramme tronqué ou forgé). Le pseudo est nettoyé comme l'hôte nettoie ceux de ses joueurs.
static func decoder_balise(donnees: PackedByteArray) -> Dictionary:
	if donnees.is_empty() or donnees.size() > TAILLE_BALISE_MAX:
		return {}
	var champs := donnees.get_string_from_utf8().split("|", true, _NB_CHAMPS - 1)
	if champs.size() != _NB_CHAMPS or champs[0] != _Reseau.JEU:
		return {}
	if _motif_version.search(champs[1]) == null:
		return {}
	for i in [2, 3, 4, 6]:
		if not champs[i].is_valid_int():
			return {}
	var port := champs[2].to_int()
	var nb_joueurs := champs[3].to_int()
	var places := champs[4].to_int()
	var niveau := champs[6].to_int()
	if port < 1 or port > 65535 or places < 2 or places > EtatPartie.NB_JOUEURS_MAX \
			or nb_joueurs < 1 or nb_joueurs > places or niveau < 0 or niveau >= EtatPartie.NIVEAUX.size() \
			or not (champs[5] == "0" or champs[5] == "1"):
		return {}
	return {"version": champs[1], "port": port, "nb_joueurs": nb_joueurs, "places": places,
		"manche_en_cours": champs[5] == "1", "niveau": niveau, "pseudo": _Reseau.pseudo_ou_defaut(champs[7], 0)}


## Inscrit (ou rafraîchit) dans `liste` la partie de la fiche `fiche` entendue depuis `ip` à
## `maintenant_ms`. Renvoie vrai si la liste affichée change (partie nouvelle ou balise différente),
## faux pour une simple balise répétée, ou pour une partie nouvelle quand la liste est pleine
## (PARTIES_MAX).
static func enregistrer_partie(liste: Dictionary[String, Dictionary], ip: String, fiche: Dictionary,
		maintenant_ms: int) -> bool:
	var cle := "%s:%d" % [ip, fiche.port]
	var ancienne: Dictionary = liste.get(cle, {})
	if ancienne.is_empty() and liste.size() >= PARTIES_MAX:
		return false
	var nouvelle := fiche.duplicate()
	nouvelle["ip"] = ip
	nouvelle["vue_a"] = maintenant_ms
	liste[cle] = nouvelle
	return ancienne.is_empty() or _sans_date(ancienne) != _sans_date(nouvelle)


static func _sans_date(partie: Dictionary) -> Dictionary:
	var copie := partie.duplicate()
	copie.erase("vue_a")
	return copie


## Retire de `liste` les parties sans balise depuis plus de `delai_ms`. Renvoie vrai si une partie
## a disparu.
static func purger_parties(liste: Dictionary[String, Dictionary], maintenant_ms: int, delai_ms: int) -> bool:
	var perimees := liste.keys().filter(func(cle: String) -> bool: return maintenant_ms - int(liste[cle].vue_a) > delai_ms)
	for cle: String in perimees:
		liste.erase(cle)
	return not perimees.is_empty()


## Destinations des balises pour les adresses locales `adresses` (`IP.get_local_addresses()`) : la
## diffusion limitée, plus la diffusion dirigée de chaque réseau privé IPv4 (a.b.c.255, en
## supposant un /24, le cas des box ; 169.254.255.255 pour une liaison directe sans DHCP). Sous
## Windows, 255.255.255.255 ne sort que par une interface, pas forcément celle du Wi-Fi de la LAN
## (VPN, cartes virtuelles) : la diffusion dirigée couvre les autres.
static func destinations_balise(adresses: PackedStringArray) -> PackedStringArray:
	var destinations := PackedStringArray([DIFFUSION])
	for adresse in adresses_privees(adresses):
		var octets := adresse.split(".")
		var dirigee := "169.254.255.255" if octets[0] == "169" else "%s.%s.%s.255" % [octets[0], octets[1], octets[2]]
		if not destinations.has(dirigee):
			destinations.append(dirigee)
	return destinations


## Les adresses IPv4 privées ou de liaison locale parmi `adresses` (10/8, 172.16/12, 192.168/16,
## 169.254/16), dans leur ordre : celles qu'un autre PC de la LAN peut joindre, que l'écran Réseau
## affiche à l'hôte pour la saisie par IP.
static func adresses_privees(adresses: PackedStringArray) -> PackedStringArray:
	var privees := PackedStringArray()
	for adresse in adresses:
		var normale := adresse_ipv4(adresse)
		if normale.is_empty():
			continue
		var octets := normale.split(".")
		var a := octets[0].to_int()
		var b := octets[1].to_int()
		if a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168) or (a == 169 and b == 254):
			if not privees.has(normale):
				privees.append(normale)
	return privees


## L'adresse IPv4 saisie `texte` sous sa forme normale (« 192.168.001.010 » → « 192.168.1.10 »), ou
## une chaîne vide si ce n'est pas une adresse joignable : quatre nombres de 0 à 255 d'un à trois
## chiffres, ni 0.x.x.x, ni multidiffusion ou réservée (224 et au-delà, 255.255.255.255 compris).
## Jamais de nom d'hôte : sa résolution bloquerait le thread principal (Windows : plusieurs
## secondes pour une faute de frappe).
static func adresse_ipv4(texte: String) -> String:
	var morceaux := texte.strip_edges().split(".")
	if morceaux.size() != 4:
		return ""
	var octets := PackedStringArray()
	for morceau in morceaux:
		if morceau.is_empty() or morceau.length() > 3 or not morceau.lstrip("0123456789").is_empty():
			return ""
		var valeur := morceau.to_int()
		if valeur > 255:
			return ""
		octets.append(str(valeur))
	var premier := octets[0].to_int()
	if premier == 0 or premier >= 224:
		return ""
	return ".".join(octets)
```

3b. Dans `project.godot`, remplacer :

```ini
Reseau="*res://Scripts/Reseau.gd"
```

par :

```ini
Reseau="*res://Scripts/Reseau.gd"
Decouverte="*res://Scripts/Decouverte.gd"
```

3c. Import (génère `Scripts/Decouverte.gd.uid`) :
Run : `export PATH="/opt/homebrew/bin:$PATH"; timeout -k 5 120 godot --headless --import . > "$TMPDIR/i.log" 2>&1; grep -E "SCRIPT ERROR|Parse Error|Compile Error" "$TMPDIR/i.log"; ls Scripts/Decouverte.gd.uid`
Expected : aucune ligne d'erreur, le fichier `.uid` existe.

- [ ] **Step 4 : le test passe, et il discrimine**

Run : la commande des Global Constraints avec `T=tests/unitaires.gd`.
Expected : `code 0`, `== 0 échec(s) ==`, 30 lignes ✅ sous « -- Découverte », dont « l'hôte émet une balise : version, port de jeu, joueurs inscrits, places, manche, niveau, pseudo ({ "version": "0.11", "port": 17792, "nb_joueurs": 1, "places": 4, "manche_en_cours": true, "niveau": 2, "pseudo": "Zoé" }) » et « port déjà pris : ecouter() renvoie l'erreur (2) sans planter ni écouter ».

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Decouverte.gd Scripts/Decouverte.gd.uid project.godot tests/unitaires.gd
git commit -m "Découverte : balise UDP 7778 de l'hôte qui suit Reseau, liste des parties qui expirent, adresse IPv4 saisie validée ; autoload Decouverte et tests unitaires

<ligne fournie par l'environnement>"
```

- [ ] **Step 6 : le test discrimine**

Chaque mutation seule, sur `Scripts/Decouverte.gd` commité, puis `timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/m.log" 2>&1; grep -E "❌" "$TMPDIR/m.log"` et **`git checkout -- Scripts/Decouverte.gd`** avant la suivante (mesuré en préparant le plan) :
- D1 : dans `_emettre_balise`, retirer ` or not multiplayer.is_server()` ⇒ `❌ un client n'émet aucune balise` ;
- D2 : dans `purger_parties`, `> delai_ms` → `>= delai_ms` ⇒ `❌ une partie vue il y a 3 s pile reste` ;
- D3 : dans `enregistrer_partie`, `if ancienne.is_empty() and liste.size() >= PARTIES_MAX:` → `if false:` ⇒ `❌ liste pleine (16 parties) …` ;
- D4 : dans `_emettre_balise`, supprimer la ligne `_fermer_emetteur()` (garder `return`) ⇒ `❌ après quitter(), la balise s'arrête et sa socket se ferme` ;
- D5 : dans `decoder_balise`, `if _motif_version.search(champs[1]) == null:` → `if false:` ⇒ `❌ 19 datagrammes invalides, aucun pris pour une balise (["LELION||7777|…", "LELION|0.11 beta|…", "LELION|0123456789abcdefg|…"])`.

Expected ensuite : `git status --short` vide.

- [ ] **Step 7 : les suites, 5 fois**

Run : 5 fois de suite chacune des trois suites Godot (`T=tests/unitaires.gd`, `T=tests/smoke_test.gd`, `T=tests/bataille_test.gd; O="--fixed-fps 60"`) et `bash tests/reseau/lancer.sh`.
Expected : chaque fois `code 0` et `== 0 échec(s) ==`, aucune `SCRIPT ERROR` ni `SHADER ERROR`. Tant que `joueur.gd` n'est pas modifié (Task 2), les hôtes du test réseau émettent leur balise en vraie diffusion sur le port 7778 : sans effet sur le test (personne n'écoute), la Task 2 les ramène sur localhost.

---

### Task 2 : la découverte dans le test réseau (écouteur, partie rejointe par sa balise, expiration, port occupé)

**Files:**
- Modify: `tests/reseau/joueur.gd` (en-tête, variable, `_run`, `_jouer_hote`, deux fonctions)
- Modify: `tests/reseau/lancer.sh` (en-tête, scénarios 6 et 7)

**Interfaces:**
- Consumes : `Decouverte` (Task 1) par `root.get_node("Decouverte")` : `port_balise`, `destinations_forcees`, `ecouter()`, `arreter_ecoute()`, `ecoute_active()`, `erreur_ecoute`, `parties`, `parties_triees()`, `TAILLE_BALISE_MAX`, `DELAI_EXPIRATION`, `PERIODE_BALISE` ; `Reseau` (phase 11) ; les fonctions du harnais (11 ter) `_check`, `_option`, `_attendre`, `_pause`, `_sur_inscription`, `_sur_refus`, `_ajouter_issue`, et dans `lancer.sh` `lancer`, `attendre_hote`, `attendre_ligne`, `terminer`, `compter`, `echec`.
- Produces : options communes `--port-balise=N` (défaut `--port` + 1000), `--diffusion` ; options d'hôte `--rester=chemin` (ligne « HOTE RESTE »), `--apres-depart=S` ; rôle `ecouteur` (`--hote=pseudo`, `--places=N`, `--rejoindre`, `--occupe` ; lignes « ECOUTE PRETE », « PARTIE VUE ip:port », « PARTIE A 2 », « PARTIE EXPIREE apres=… s », « RESULTAT occupe erreur=N ») ; scénario 6 (toujours) et 7 (`DIFFUSION=1`). La phase 15 (test de bout en bout) peut réutiliser `--rester`.

- [ ] **Step 1 : le rôle écouteur et les options de l'hôte**

Dans `tests/reseau/joueur.gd` :

1a. Remplacer :

```gdscript
##   godot --headless --script tests/reseau/joueur.gd -- --role=hote|client|lent [options]
## Communes : --port=N (défaut 17777), --pseudo=texte.
```

par :

```gdscript
##   godot --headless --script tests/reseau/joueur.gd -- --role=hote|client|lent|ecouteur [options]
## Communes : --port=N (défaut 17777), --pseudo=texte, --port-balise=N (port des balises de
##   découverte, émises par un hôte et écoutées par un écouteur ; défaut : --port + 1000),
##   --diffusion (balises en vraie diffusion, comme en jeu ; sans elle, vers 127.0.0.1 seulement).
```

1b. Remplacer :

```gdscript
##   `Reseau.DELAI_POIGNEE_DE_MAIN`). Écrit « HOTE PRET » quand il écoute et « POIGNEE ECHOUEE n »
##   à chaque poignée de main échouée (n = leur compte, après que `Reseau` a libéré la place), puis
##   quitte le réseau (ses clients doivent voir l'hôte partir).
```

par :

```gdscript
##   `Reseau.DELAI_POIGNEE_DE_MAIN`), --rester=chemin (une fois ses vérifications faites, écrit
##   « HOTE RESTE » et ne quitte le réseau qu'une fois ce fichier créé par lancer.sh, DELAI_ETAPE au
##   plus), --apres-depart=S (le processus vit encore S secondes après avoir quitté le réseau : sa
##   balise doit s'arrêter d'elle-même, pas avec le processus). Écrit « HOTE PRET » quand il écoute
##   et « POIGNEE ECHOUEE n » à chaque poignée de main échouée (n = leur compte, après que `Reseau` a
##   libéré la place), puis quitte le réseau (ses clients doivent voir l'hôte partir).
```

1c. Remplacer :

```gdscript
##   défaut `Reseau.DELAI_POIGNEE_DE_MAIN`). Preuve de bout en bout (Focus 2, Focus 5) que la place
##   d'un accepté est réservée dès la réponse et libérée par le vrai `auth_timeout` de l'hôte.
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
## `Reseau` par `root.get_node`, ne nomme ni `Reseau` ni `GameState` (il peut nommer
## `EtatPartie`, dont le script ne nomme aucun autoload).
```

par :

```gdscript
##   défaut `Reseau.DELAI_POIGNEE_DE_MAIN`). Preuve de bout en bout (Focus 2, Focus 5) que la place
##   d'un accepté est réservée dès la réponse et libérée par le vrai `auth_timeout` de l'hôte.
## Écouteur (phase 12) : écoute les balises (`Decouverte`), vérifie que des datagrammes étrangers
##   n'ajoutent aucune partie, écrit « ECOUTE PRETE », attend la partie de --hote=pseudo et vérifie
##   sa balise (adresse, --port, version, 1 joueur sur --places=N, pas de manche) : « PARTIE VUE ».
##   Avec --rejoindre, la rejoint à l'adresse et au port de sa balise, attend la balise qui compte
##   2 joueurs (« PARTIE A 2 »), puis le départ de l'hôte. Enfin, la partie doit disparaître de la
##   liste DELAI_EXPIRATION après sa dernière balise (« PARTIE EXPIREE ») et, avec --rejoindre, au
##   plus PERIODE_BALISE + DELAI_EXPIRATION (plus une marge) après le départ de l'hôte. Avec
##   --occupe : un second écouteur sur un port de balises déjà pris ; `ecouter()` doit renvoyer une
##   erreur sans planter (deux LeLion sur un même PC).
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
## `Reseau` et `Decouverte` par `root.get_node`, ne nomme ni `Reseau`, ni `Decouverte`, ni
## `GameState` (il peut nommer `EtatPartie`, dont le script ne nomme aucun autoload).
```

1d. Remplacer :

```gdscript
var reseau: Node
```

par :

```gdscript
var reseau: Node
var decouverte: Node
```

1e. Remplacer :

```gdscript
	reseau = root.get_node("Reseau")
	reseau.pseudo = _option("pseudo", "Poste")
	var role := _option("role", "")
```

par :

```gdscript
	reseau = root.get_node("Reseau")
	decouverte = root.get_node("Decouverte")
	reseau.pseudo = _option("pseudo", "Poste")
	# Chaque hôte émet sa balise (elle suit l'état de Reseau) : vers un port de test propre au
	# scénario, et vers localhost seulement, sauf --diffusion (jamais le 7778 d'une vraie partie).
	decouverte.port_balise = int(_option("port-balise", str(int(_option("port", "17777")) + 1000)))
	if not _options.has("diffusion"):
		decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	var role := _option("role", "")
```

1f. Remplacer :

```gdscript
	elif role == "lent":
		await _jouer_lent()
	else:
		_check(false, "rôle inconnu : --role=hote, --role=client ou --role=lent")
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		and root.multiplayer.is_server() and reseau.inscrits.is_empty() and reseau.index_local == -1,
		"à la fin, le poste est revenu hors réseau (pair hors ligne, hôte de lui-même, plus d'inscrits)")
```

par :

```gdscript
	elif role == "lent":
		await _jouer_lent()
	elif role == "ecouteur":
		await _jouer_ecouteur()
	else:
		_check(false, "rôle inconnu : --role=hote, --role=client, --role=lent ou --role=ecouteur")
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		and root.multiplayer.is_server() and reseau.inscrits.is_empty() and reseau.index_local == -1
		and not decouverte.ecoute_active(),
		"à la fin, le poste est revenu hors réseau (pair hors ligne, hôte de lui-même, plus d'inscrits ni d'écoute)")
```

1g. Remplacer :

```gdscript
	_check(_arrivees.size() == nb_clients and _poignees_echouees.size() == nb_refus,
		"ni arrivée ni poignée de main échouée de trop : %d client(s), %d échec(s) de poignée de main" % [_arrivees.size(), _poignees_echouees.size()])
	reseau.quitter()  # close() envoie ses paquets de façon synchrone (N7) : pas de pause à ajouter ici
```

par :

```gdscript
	_check(_arrivees.size() == nb_clients and _poignees_echouees.size() == nb_refus,
		"ni arrivée ni poignée de main échouée de trop : %d client(s), %d échec(s) de poignée de main" % [_arrivees.size(), _poignees_echouees.size()])
	if _options.has("rester"):
		var rester := _option("rester", "")
		print("HOTE RESTE")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
	reseau.quitter()  # close() envoie ses paquets de façon synchrone (N7) : pas de pause à ajouter ici
	if _options.has("apres-depart"):
		# Le processus vit encore : si la balise ne suivait pas l'état de Reseau, elle continuerait.
		await _pause(float(_option("apres-depart", "0")))
```

1h. Remplacer :

```gdscript
func _sur_arrivee(id: int) -> void:
```

par :

```gdscript
## Rôle de test « écouteur » (phase 12) : la liste des parties de l'écran Réseau, vue par les
## balises d'un hôte de test (voir l'en-tête).
func _jouer_ecouteur() -> void:
	var erreur: int = decouverte.ecouter()
	if _options.has("occupe"):
		_check(erreur != OK and not decouverte.ecoute_active() and decouverte.erreur_ecoute == erreur,
			"port des balises %d déjà pris par un autre poste : ecouter() renvoie l'erreur (%d), sans planter" % [decouverte.port_balise, erreur])
		print("RESULTAT occupe erreur=%d" % erreur)
		return
	_check(erreur == OK, "l'écoute des balises s'ouvre sur le port %d (erreur %d)" % [decouverte.port_balise, erreur])
	if erreur != OK:
		return
	# Des datagrammes étrangers sur le port des balises (autre programme, balise tronquée ou forgée)
	var brouilleur := PacketPeerUDP.new()
	brouilleur.set_dest_address("127.0.0.1", decouverte.port_balise)
	var trop_long := PackedByteArray()
	trop_long.resize(decouverte.TAILLE_BALISE_MAX + 1)
	for donnees: PackedByteArray in [PackedByteArray([0xFF, 0x00, 0x7C]), "LELION|x".to_utf8_buffer(),
			"AUTRE|0.11|7777|1|6|0|0|x".to_utf8_buffer(), trop_long]:
		brouilleur.put_packet(donnees)
	brouilleur.close()
	await _pause(0.3)
	_check(decouverte.ecoute_active() and decouverte.parties.is_empty(), "des datagrammes qui ne sont pas des balises n'ajoutent aucune partie")
	print("ECOUTE PRETE")

	var hote := _option("hote", "Hote")
	_check(await _attendre(func() -> bool: return not _cle_partie(hote).is_empty()), "la partie de « %s » apparaît dans la liste" % hote)
	var cle := _cle_partie(hote)
	if cle.is_empty():
		decouverte.arreter_ecoute()
		return
	var partie: Dictionary = decouverte.parties[cle]
	print("PARTIE VUE %s" % cle)
	var adresse_attendue: bool = IP.get_local_addresses().has(partie.ip) if _options.has("diffusion") else partie.ip == "127.0.0.1"
	_check(adresse_attendue and partie.port == int(_option("port", "17777")) and partie.version == reseau.version
		and partie.nb_joueurs == 1 and partie.places == int(_option("places", str(EtatPartie.NB_JOUEURS_MAX)))
		and not partie.manche_en_cours and partie.niveau >= 0 and partie.niveau < EtatPartie.NIVEAUX.size(),
		"sa balise donne l'adresse de l'hôte, son port de jeu, sa version, 1 joueur sur %s places, pas de manche (%s)" % [_option("places", "6"), partie])

	var depart := -1
	if _options.has("rejoindre"):
		reseau.inscrit.connect(_sur_inscription)
		reseau.refuse.connect(_sur_refus)
		reseau.connexion_echouee.connect(_ajouter_issue.bind("echec"))
		reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
		_check(reseau.rejoindre(partie.ip, partie.port) == OK, "rejoindre la partie vue, à l'adresse et au port de sa balise")
		_check(await _attendre(func() -> bool: return not _issue.is_empty()) and _issue == "inscrit",
			"l'hôte trouvé dans la liste inscrit ce poste (%s)" % _issue)
		_check(await _attendre(func() -> bool: return decouverte.parties.has(cle) and decouverte.parties[cle].nb_joueurs == 2),
			"la balise suivante de l'hôte compte 2 joueurs")
		print("PARTIE A 2")
		_check(await _attendre(func() -> bool: return _issue != "inscrit"), "l'hôte finit par partir")
		_check(_issue == "inscrit+hote_perdu", "le départ de l'hôte est signalé une fois, comme hôte perdu (%s)" % _issue)
		depart = Time.get_ticks_msec()

	# Un Array, pas un int local : une lambda GDScript capture les variables locales par valeur.
	var derniere_vue := [int(partie.vue_a)]
	var expiree := await _attendre(func() -> bool:
		if decouverte.parties.has(cle):
			derniere_vue[0] = int(decouverte.parties[cle].vue_a)
		return not decouverte.parties.has(cle))
	var apres: float = (Time.get_ticks_msec() - int(derniere_vue[0])) / 1000.0
	print("PARTIE EXPIREE apres=%.2f s" % apres)
	_check(expiree and apres >= decouverte.DELAI_EXPIRATION and apres <= decouverte.DELAI_EXPIRATION + 0.5,
		"la partie disparaît de la liste %.0f s après sa dernière balise (%.2f s)" % [decouverte.DELAI_EXPIRATION, apres])
	if depart >= 0:
		var depuis_depart := (Time.get_ticks_msec() - depart) / 1000.0
		var borne: float = decouverte.PERIODE_BALISE + decouverte.DELAI_EXPIRATION + 1.0
		_check(depuis_depart <= borne,
			"et au plus %.0f s après le départ de l'hôte, dont le processus vit encore : sa balise s'arrête avec la session (%.1f s)" % [borne, depuis_depart])
	decouverte.arreter_ecoute()


## La clé (« ip:port ») d'une partie de la liste dont l'hôte a ce pseudo, la première dans l'ordre de
## la liste affichée ; une chaîne vide s'il n'y en a pas.
func _cle_partie(pseudo_hote: String) -> String:
	for partie: Dictionary in decouverte.parties_triees():
		if partie.pseudo == pseudo_hote:
			return "%s:%d" % [partie.ip, partie.port]
	return ""


func _sur_arrivee(id: int) -> void:
```

- [ ] **Step 2 : les scénarios**

Dans `tests/reseau/lancer.sh` :

2a. Remplacer :

```bash
# Test réseau du transport (phase 11) : des postes headless sur localhost, un processus Godot par
# poste (tests/reseau/joueur.gd), scénario après scénario.
#   tests/reseau/lancer.sh [port_de_base]
# Le scénario n utilise le port port_de_base + n (défaut 17777 : jamais le 7777 d'une vraie partie).
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40).
```

par :

```bash
# Test réseau du transport (phase 11) et de la découverte (phase 12) : des postes headless sur
# localhost, un processus Godot par poste (tests/reseau/joueur.gd), scénario après scénario.
#   tests/reseau/lancer.sh [port_de_base]
# Le scénario n utilise le port port_de_base + n (défaut 17777 : jamais le 7777 d'une vraie partie)
# et, pour les balises de découverte, port_de_base + 1000 + n (jamais le 7778).
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40),
# DIFFUSION=1 (ajoute le scénario 7, balises en vraie diffusion : hors CI, où la diffusion n'a pas
# été mesurée ; le scénario 6 couvre le même chemin en envoi direct vers 127.0.0.1).
```

2b. Remplacer :

```bash
terminer "poignée de main jamais finie : réservation à la réponse, puis libération par le vrai délai"
```

par :

```bash
terminer "poignée de main jamais finie : réservation à la réponse, puis libération par le vrai délai"

# 6. Découverte (balises vers 127.0.0.1) : l'hôte émet sa balise ; un écouteur voit sa partie,
#    la rejoint à l'adresse et au port de la balise, voit la balise suivante compter 2 joueurs.
#    Un second écouteur sur le même port de balises (deux LeLion sur un PC) reçoit une erreur,
#    sans planter. Puis l'hôte quitte le réseau mais son processus vit encore 6 s : la partie doit
#    quitter la liste 3 s après sa dernière balise, pas à la fin du processus.
P=$((PORT_BASE + 6))
B=$((PORT_BASE + 1006))
lancer hote6 --role=hote --port=$P --port-balise=$B --pseudo=Hote6 --places=4 --clients=1 --rester="$JOURNAUX/rester6" --apres-depart=6
if attendre_hote hote6; then
	lancer ecouteur6 --role=ecouteur --port=$P --port-balise=$B --hote=Hote6 --places=4 --rejoindre
	if attendre_ligne ecouteur6 "ECOUTE PRETE"; then
		lancer occupe6 --role=ecouteur --port-balise=$B --occupe
		attendre_ligne ecouteur6 "PARTIE A 2" && touch "$JOURNAUX/rester6"
	fi
fi
terminer "découverte : partie vue et rejointe par sa balise, comptée à 2, expirée après le départ de l'hôte ; port des balises occupé sans plantage"
[ "$(compter "PARTIE EXPIREE" ecouteur6)" -eq 1 ] || echec "découverte : la partie n'a pas expiré dans la liste"

# 7. (DIFFUSION=1) La même découverte en vraie diffusion (255.255.255.255 et réseaux privés), sans
#    rejoindre : l'adresse vue est l'une de celles de ce PC.
if [ "${DIFFUSION:-0}" = "1" ]; then
	P=$((PORT_BASE + 7))
	B=$((PORT_BASE + 1007))
	lancer hote7 --role=hote --port=$P --port-balise=$B --pseudo=Hote7 --diffusion --rester="$JOURNAUX/rester7"
	if attendre_hote hote7; then
		lancer ecouteur7 --role=ecouteur --port=$P --port-balise=$B --hote=Hote7 --diffusion
		attendre_ligne ecouteur7 "PARTIE VUE" && touch "$JOURNAUX/rester7"
	fi
	terminer "découverte en vraie diffusion"
	[ "$(compter "PARTIE EXPIREE" ecouteur7)" -eq 1 ] || echec "diffusion : la partie n'a pas expiré dans la liste"
else
	echo "  (scénario 7, découverte en vraie diffusion : DIFFUSION=1 pour le lancer)"
fi
```

- [ ] **Step 3 : le test passe**

Run : `export PATH="/opt/homebrew/bin:$PATH"; timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== |✅|scénario 7" "$TMPDIR/r.log"`
Expected : `code 0`, les cinq scénarios de la phase 11 verts, « ✅ découverte : partie vue et rejointe par sa balise, comptée à 2, expirée après le départ de l'hôte ; port des balises occupé sans plantage », la ligne « (scénario 7 … DIFFUSION=1 pour le lancer) » et `== 0 échec(s) ==` ; environ 30 s au total (mesuré : 27 s). Dans le journal de `ecouteur6` (garder les journaux en copiant le lanceur sans sa ligne `rm -rf "$JOURNAUX"`, copie supprimée ensuite) : « PARTIE EXPIREE apres=3.01 s » et « … sa balise s'arrête avec la session (3.0 s) ».

Puis la vraie diffusion, une fois : `DIFFUSION=1 timeout -k 5 300 bash tests/reseau/lancer.sh 27777 > "$TMPDIR/r7.log" 2>&1; echo "code $?"; grep -E "❌|== |✅" "$TMPDIR/r7.log"`
Expected : `code 0` et « ✅ découverte en vraie diffusion » (mesuré sur un Mac en Wi-Fi : partie vue à l'adresse Wi-Fi du Mac, 192.168.1.x). Si ce PC n'a aucun réseau (ni Wi-Fi ni Ethernet), noter le scénario 7 comme non vérifié plutôt que d'y toucher.

- [ ] **Step 4 : le scénario 6 discrimine**

Mutation temporaire de `Scripts/Decouverte.gd` (code neuf de la Task 1), jamais commitée : la balise continue après `quitter()` en répétant la dernière. Dans `_emettre_balise`, remplacer :

```gdscript
	if reseau == null or not reseau.en_ligne() or not multiplayer.is_server() or not (pair is ENetMultiplayerPeer):
		_fermer_emetteur()
		return
```

par :

```gdscript
	if reseau == null or not reseau.en_ligne() or not multiplayer.is_server() or not (pair is ENetMultiplayerPeer):
		if _emetteur != null and not _mut.is_empty():
			for d in _destinations:
				_emetteur.set_dest_address(d, port_balise)
				_emetteur.put_packet(_mut)
		return
```

ajouter `var _mut := PackedByteArray()` sous `var _emetteur: PacketPeerUDP`, et `_mut = balise` juste avant `for destination in _destinations:`.
Run : `timeout -k 5 300 bash tests/reseau/lancer.sh 37777 > "$TMPDIR/rm.log" 2>&1; echo "code $?"; grep -E "❌" "$TMPDIR/rm.log" | head -3`
Expected : `code 1` et « ❌ et au plus 5 s après le départ de l'hôte, dont le processus vit encore : sa balise s'arrête avec la session (9.0 s) » (mesuré). Puis `git checkout -- Scripts/Decouverte.gd` et `git status --short` : seuls `tests/reseau/joueur.gd` et `tests/reseau/lancer.sh`.

- [ ] **Step 5 : 5 fois, sous bash 5 et bash 3.2**

Run : 5 fois `bash tests/reseau/lancer.sh`, puis 5 fois `/bin/bash tests/reseau/lancer.sh`, puis une fois chacune des trois suites Godot.
Expected : chaque fois `code 0` et `== 0 échec(s) ==`, aucune `SCRIPT ERROR` ni `SHADER ERROR`.

- [ ] **Step 6 : Commit**

```bash
git add tests/reseau/joueur.gd tests/reseau/lancer.sh
git commit -m "Test réseau : découverte (partie vue et rejointe par sa balise, comptée à 2, expirée 3 s après le départ de l'hôte, port des balises occupé) ; vraie diffusion avec DIFFUSION=1

<ligne fournie par l'environnement>"
```

---

### Task 3 : feuille de route et spec

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`

**Interfaces:**
- Consumes : Tasks 1 et 2, Écarts 1 à 7.
- Produces : la ligne 12 découpée en 12 et 12 bis ; le format de la balise dans la spec ; les points réaffectés (diffusion en CI → phase 19, garde-fou de `Reseau.rejoindre` → phase 13, balise et salon → phase 13, pare-feu des clients → phase 19). Les points de vigilance « phase 12 » propres à l'écran (titre, textes, M8) restent ouverts : c'est la phase 12 bis qui les résout.

- [ ] **Step 1 : la ligne 12 découpée**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
| 12 | **Découverte et écran Réseau** : balise UDP 7778, liste des parties, IP en secours, bouton Multijoueur. | ➕ `Scripts/Decouverte.gd` ➕ `Scenes/EcranReseau.tscn` ➕ `Scripts/EcranReseau.gd` ✏️ `Scripts/Titre.gd` ✏️ `Assets/Traductions/traductions.csv` | ◉ écran Réseau |
```

par :

```markdown
| 12 | **Découverte** : autoload `Decouverte` (balise UDP 7778 de l'hôte, qui suit `Reseau` ; écoute ; liste des parties qui expirent ; adresse IPv4 saisie validée), test à plusieurs processus (balises vers 127.0.0.1 ; vraie diffusion avec `DIFFUSION=1`, hors CI). Découpage (8 fichiers avec les tests et l'autoload) : plans des phases 12 et 12 bis. | ➕ `Scripts/Decouverte.gd` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | tests verts, test réseau vert 5 fois (bash 3.2 et 5) |
| 12 bis | **Écran Réseau** : pseudo mémorisé, Héberger, liste des parties, Rejoindre par IP, textes des refus et des échecs, bouton Multijoueur du titre, `Titre._ready` hors réseau. | ➕ `Scenes/EcranReseau.tscn` ➕ `Scripts/EcranReseau.gd` ✏️ `Scripts/Titre.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `tests/smoke_test.gd` | ◉ écran Réseau |
```

- [ ] **Step 2 : les points réaffectés**

Dans le même fichier, remplacer :

```markdown
- **phase 12** (écran Réseau, M8 de la revue de la phase 11) : `rejoindre()` passe un nom d'hôte tel
```

par :

```markdown
- **phase 19** (qui touche `ci.yml`, phase 12, Écart 5) : le test réseau ne vérifie la vraie diffusion
  (scénario 7 de `tests/reseau/lancer.sh`) qu'avec `DIFFUSION=1`, mesurée sur macOS seulement ; en
  CI, le scénario 6 dirige les balises vers 127.0.0.1. Essayer `DIFFUSION=1` dans le pas « Test
  réseau » (sous Linux, une diffusion revient d'ordinaire aux sockets locales) ; le garder s'il est
  vert 5 fois, sinon le noter ici. Sur Windows, la découverte n'est vérifiée qu'à la main (`.exe` de
  la CI) : deux PC de la LAN, dont un avec une carte réseau virtuelle ou un VPN (la balise part aussi
  en diffusion dirigée a.b.c.255, en supposant des réseaux en /24) ;
- **phase 13** (salon, phase 12) : la balise de découverte (`Decouverte`) suit l'état de `Reseau` sans
  qu'on la relance : `inscrits.size()` (réservations comprises, voir M4 plus bas), `places`,
  `manche_en_cours` et le niveau `GameState.niveau_courant`. Le salon doit donc poser
  `GameState.niveau_courant` quand l'hôte change de niveau (la liste des autres postes l'affiche) et
  `Reseau.manche_en_cours` au lancement (la partie y apparaît grisée « manche en cours ») ;
- **phase 12** (écran Réseau, M8 de la revue de la phase 11) : `rejoindre()` passe un nom d'hôte tel
```

- [ ] **Step 3 : la spec**

3a. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
| `Reseau` (autoload) | Pair ENet, découverte UDP, poignée de main (version, pseudo), liste des joueurs du salon, attribution des index et couleurs, signaux de connexion / déconnexion. | `MultiplayerAPI` |
```

par :

```markdown
| `Reseau` (autoload) | Pair ENet, poignée de main (version, pseudo), liste des joueurs du salon, attribution des index et couleurs, signaux de connexion / déconnexion. | `MultiplayerAPI` |
| `Decouverte` (autoload) | Balise UDP de l'hôte (émise tant que `Reseau` héberge, sans qu'on la relance), écoute et liste des parties entendues, validation d'une adresse IPv4 saisie. Ne nomme aucun autoload (phase 12). | `Reseau` (par son chemin) |
```

3b. Remplacer :

```markdown
- **Découverte** : l'hôte émet toutes les secondes une balise UDP broadcast sur le port **7778** :
  `LELION|<version>|<pseudo hôte>|<nb joueurs>|<id niveau>`. L'écran « Rejoindre » écoute et liste
  les parties (expiration après 3 s sans balise). Saisie d'IP en secours.
```

par :

```markdown
- **Découverte** : l'hôte émet toutes les secondes une balise UDP broadcast sur le port **7778**
  (vers 255.255.255.255 et la diffusion dirigée a.b.c.255 de chaque réseau privé de l'hôte, en
  supposant un /24 : sous Windows, la diffusion limitée ne sort que par une interface) :
  `LELION|<version>|<port de jeu>|<nb joueurs>|<places>|<manche 0/1>|<index du niveau>|<pseudo hôte>`.
  Le pseudo, seul texte libre, vient en dernier (il peut contenir `|`) ; le port de jeu dit au client
  où rejoindre ; places et manche en cours permettent de griser une partie pleine ou en cours. Une
  balise invalide (autre programme, champs hors plage) est ignorée, 16 parties au plus. L'écran
  Réseau écoute et liste les parties (expiration après 3 s sans balise). Saisie d'IP en secours
  (IPv4 seulement : un nom se résoudrait en bloquant le jeu).
```

3c. Remplacer :

```markdown
  un départ volontaire), qui ne peuvent pas donner de faux rouge ; en CI depuis la phase 11 ter. De bout en bout (phase
```

par :

```markdown
  un départ volontaire), qui ne peuvent pas donner de faux rouge ; en CI depuis la phase 11 ter.
  Depuis la phase 12, la découverte : balise vers 127.0.0.1 (ports de balise 18778 et suivants),
  partie vue puis rejointe par sa balise, balise suivante à 2 joueurs, expiration 3 s après la
  dernière balise alors que le processus de l'hôte vit encore, port des balises occupé par un
  second écouteur ; la vraie diffusion avec `DIFFUSION=1`, hors CI. De bout en bout (phase
```

Run : `grep -n "12 bis\|DIFFUSION\|index du niveau" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`
Expected : la ligne 12 bis du tableau, le point « phase 19 » sur `DIFFUSION=1`, le format de la balise et la phrase de §10.

- [ ] **Step 4 : Commit**

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md
git commit -m "Feuille de route et spec : phase 12 découpée (découverte, puis écran Réseau en 12 bis) ; format de la balise (port de jeu, places, manche, pseudo en dernier) ; diffusion en CI pour la phase 19, balise et niveau du salon pour la phase 13

<ligne fournie par l'environnement>"
```

---

## Sortie de phase

- Les quatre suites vertes 5 fois de suite localement, sans `SCRIPT ERROR` ni `SHADER ERROR` ; le test réseau aussi 5 fois sous `/bin/bash` (3.2) et une fois avec `DIFFUSION=1` ; puis le job CI vert sur la PR, pas « Test réseau » compris.
- Les preuves de discrimination D1 à D5 (Task 1) et la mutation de la Task 2 ont donné les `❌` attendus, sans qu'aucun fichier hors de la phase ait été touché.
- `git diff main --stat` : 5 fichiers de code et de test (`Scripts/Decouverte.gd`, `project.godot`, `tests/unitaires.gd`, `tests/reseau/joueur.gd`, `tests/reseau/lancer.sh`), plus `Scripts/Decouverte.gd.uid`, la spec et la feuille de route ; `git diff main --stat -- Scripts/Reseau.gd` vide.
- `grep -n "Reseau\.\|GameState\." Scripts/Decouverte.gd` : aucune ligne (pas d'autoload nommé ; seulement `_Reseau.` et des chemins `/root/…`).
- Rappeler à l'utilisateur : toujours rien de visible en jeu ; un poste qui héberge (par le test ou plus tard l'écran Réseau) annonce désormais sa partie sur le port UDP 7778 ; la phase 12 bis ajoute l'écran Réseau et le bouton Multijoueur, avec les captures à valider.
