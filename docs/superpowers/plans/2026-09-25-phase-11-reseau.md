# Phase 11 : réseau (1/2), le transport, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** un autoload `Reseau` met les postes en réseau local : un hôte ENet (port UDP 7777) accepte jusqu'à 6 joueurs, hôte compris ; chaque client se présente (version, pseudo) par une poignée de main ; l'hôte refuse explicitement une version différente, une partie pleine, une manche en cours ou une demande mal formée, attribue à chaque accepté le plus petit index libre et la première couleur libre de la palette de bataille, et voit arriver et partir ses joueurs ; un client voit son inscription, son refus (avec la raison et la version de l'hôte), l'échec de sa connexion (5 s) ou le départ de l'hôte, et revient alors de lui-même hors réseau (`OfflineMultiplayerPeer`). Un test à plusieurs processus headless sur localhost (`tests/reseau/lancer.sh` + `tests/reseau/joueur.gd`) le prouve. Sortie : **hôte + 2 clients se connectent, version refusée**. **Le solo reste strictement identique.**

**Architecture:** `Scripts/Reseau.gd` est un autoload sans `class_name` (le nom `Reseau` est pris par l'autoload) qui ne connaît de la partie que deux constantes de classe (`EtatPartie.NB_JOUEURS_MAX`, `EtatPartie.PALETTE_BATAILLE`) : ni `GameState`, ni scène. La poignée de main passe par l'authentification de `SceneMultiplayer` (`auth_callback`, `send_auth`, `complete_auth`, `auth_timeout`) : des octets bruts (`var_to_bytes` d'un dictionnaire) échangés avant tout RPC. L'hôte décide par une fonction pure, `examiner_demande(demande) -> Dictionary`, et inscrit l'accepté dans `inscrits` (id réseau → index, couleur, pseudo) au moment même de sa réponse. Les signaux de `SceneMultiplayer` deviennent six signaux de `Reseau` : `joueur_arrive` / `joueur_parti` chez l'hôte, `inscrit` / `refuse` / `connexion_echouee` / `hote_perdu` chez le client ; les trois derniers partent une seule fois, après le retour hors réseau. `project.godot` déclare l'autoload et la version présentée (`application/config/version`).

**Tech Stack:** Godot 4.7.2, GDScript typé, `ENetMultiplayerPeer` / `SceneMultiplayer`, tests headless (`tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd` avec `--fixed-fps 60`), test à plusieurs processus en bash (`timeout` de GNU coreutils : `/opt/homebrew/bin/timeout` sur le Mac, natif sur Ubuntu).

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1 ligne `Reseau`, §4 transport, poignée de main, déconnexions, §9 erreurs, §10 tests) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (lignes 11 et 11 bis ; points de vigilance « phase 11 » et « phases 12/13 ») · suite : `docs/superpowers/plans/2026-09-25-phase-11bis-joueur-local.md` · prérequis : phase 10 ter fusionnée (`main` 04b8b2c).

## Écarts assumés

1. **La phase 11 est scindée en 11 et 11 bis** : la ligne de la feuille de route (5 fichiers) ne contenait que le transport, mais les points de vigilance « phase 11 » touchent 5 autres fichiers (`Joueur.id_reseau`, `GameState.joueur_local()` par identifiant, retour au solo, réabonnement d'`Audio`, palette, et le test réseau en CI). La phase 11 livre le transport et son test ; la 11 bis, le joueur local par identifiant réseau, la palette et la CI. Le tableau de la feuille de route est mis à jour par le commit de planification.
2. **Poignée de main par l'authentification de `SceneMultiplayer`, pas par RPC** : les octets bruts passent avant tout RPC, si bien qu'une version plus ancienne du jeu (RPC différents) apprend encore pourquoi elle est refusée ; un pair non authentifié ne peut envoyer aucun RPC. **L'hôte ne déconnecte pas un refusé** : mesuré en préparant ce plan, `disconnect_peer` juste après `send_auth` vide la file d'envoi d'ENet (`enet_peer_disconnect` remet les files à zéro), la réponse ne part jamais et le client voit « hôte perdu » au lieu de la raison. Le refusé ferme lui-même la connexion en lisant le refus ; un pair qui ne répond pas est coupé par `auth_timeout` (3 s).
3. **La version présentée est `application/config/version`**, ajoutée à `project.godot` (`"0.11"`) ; la phase 19 y mettra la version livrée. Les raisons de refus sont des clés (`RESEAU_REFUS_VERSION`, `…_PLEIN`, `…_MANCHE`, `…_DEMANDE`) : les textes, dont « Version différente de l'hôte (x.y) », arrivent avec l'écran Réseau et `traductions.csv` en phase 12 (réaffecté par la Task 3).
4. **Index et couleur sont attribués séparément** (le plus petit index libre, la première couleur libre) : ils coïncident tant que personne ne change de couleur, ce que permettra le salon (phase 13). `Reseau` tient sa propre table `inscrits` et ne touche pas `GameState.joueurs` : c'est le salon qui la reportera dans la partie (`configurer_bataille(n, couleurs)` de la phase 11 bis, `Joueur.id_reseau`).
5. **`Reseau.manche_en_cours` est posé par la partie** (phase 13 au lancement, phase 18 au retour au salon) au lieu d'être lu dans `GameState` : le transport reste indépendant du jeu et se teste seul.
6. **`Reseau` revient de lui-même hors réseau** avant d'émettre `refuse`, `connexion_echouee` et `hote_perdu` : un retour au titre qui suit ces signaux trouve déjà un solo qui fonctionne. `Titre._ready` n'est pas modifié ici (il est dans les fichiers de la phase 12) : l'appel explicite de `Reseau.quitter()` y est réaffecté par la Task 3.
7. **ENet accepte 2 connexions de plus que les places** (`CONNEXIONS_EN_TROP`) : la spec veut un refus explicite pour une partie pleine, pas une connexion qui échoue sans explication au niveau d'ENet.
8. **Le pseudo est nettoyé et coupé à 12 caractères par l'hôte** (`PSEUDO_MAX`) : c'est la moitié du point de vigilance de la phase 13 sur la largeur de l'étiquette (un client ne peut plus imposer un pseudo démesuré) ; le champ de saisie du salon reste à faire.
9. **Le test à plusieurs processus entre en CI en phase 11 bis, pas en phase 15** : `.github/workflows/ci.yml` serait le 6ᵉ fichier de cette phase ; la 11 bis en a la place. Plus tôt qu'en phase 15 parce que les phases 12 à 14 modifient `Reseau.gd` et `tests/reseau/joueur.gd` : ce test d'une quinzaine de secondes les garde. La ligne 15 de la feuille de route n'a donc plus `ci.yml` (commit de planification).
10. **Pas de nettoyage préalable (« Step 0 »)** : `tests/unitaires.gd` (747 lignes) ne reçoit qu'une fonction ajoutée à la fin et un appel ; aucune refonte. Le lire par morceaux (`offset` / `limit`).
11. **Bruit attendu** : les tests unitaires affichent `ERROR: Couldn't create an ENet host.` (le test du port occupé le provoque exprès) en plus des deux `ERROR: Territoire.tamponner : index de joueur hors plage` déjà présents ; ce ne sont pas des `SCRIPT ERROR`.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`, sur la branche `phase-11-reseau`.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations (y compris dans `tests/reseau/lancer.sh`).
- Fichiers de la phase (5) : ➕ `Scripts/Reseau.gd`, ✏️ `project.godot`, ✏️ `tests/unitaires.gd`, ➕ `tests/reseau/lancer.sh`, ➕ `tests/reseau/joueur.gd`. Les `.uid` générés par l'import (`Scripts/Reseau.gd.uid`, `tests/reseau/joueur.gd.uid`) sont committés avec leurs scripts, hors plafond ; la spec et la feuille de route ne comptent pas.
- Solo strictement identique : l'autoload ne change pas le pair au démarrage (le `OfflineMultiplayerPeer` par défaut de Godot) ; le smoke test n'est pas modifié et reste vert.
- `Reseau.gd` n'a **pas** de `class_name` (le nom est celui de l'autoload) et ne nomme aucun autoload ; `Reseau` ne touche ni `GameState` ni aucune scène.
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : `tests/unitaires.gd` et `tests/reseau/joueur.gd` récupèrent `Reseau` par `root.get_node("Reseau")` (variable typée `Node`, appels dynamiques) et ne nomment ni `Reseau` ni `GameState` ; ils peuvent nommer `EtatPartie` (le script de `GameState` ne nomme aucun autoload), `Joueur`, `SceneMultiplayer`, `ENetMultiplayerPeer`, `OfflineMultiplayerPeer`, `MultiplayerPeer`.
- **Toujours lancer un test Godot avec `timeout`** et chercher les erreurs dans la sortie :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/unitaires.gd; O=""; timeout 300 godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/smoke_test.gd; O=""` ou `T=tests/bataille_test.gd; O="--fixed-fps 60"` pour les deux autres suites). Une `SCRIPT ERROR` ne change pas le code de sortie et une erreur avant `quit()` bloque le processus jusqu'au `timeout` (code 124). Un « resources still in use at exit » final est le bruit connu.
- Test réseau : `bash tests/reseau/lancer.sh` (chaque processus sous `timeout -k 5 40`, tous tués en sortie) ; il finit par `== 0 échec(s) ==` et le code 0. Il utilise les ports 17778 à 17781 (port de base 17777 + n° du scénario), jamais le 7777 d'une vraie partie ; `bash tests/reseau/lancer.sh 27777` décale tout si ces ports sont pris.
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`** (la CI les cherche dans toute la sortie).
- Les quatre suites (unitaires, smoke, bataille, réseau) se valident sur **5 passages consécutifs verts**.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Un solo cassé après une session réseau** : un pair ENet fermé (ou un rappel d'authentification) qui reste branché laisse `multiplayer.is_server()` faux, et le solo relancé depuis le titre ne réagit plus (ennemis, pastilles, gerbe). → « quitter revient hors réseau : pair hors ligne, hôte de soi-même, plus d'inscrits ni de poignée de main » (Task 1) et, pour chaque poste du test réseau après départ volontaire, hôte perdu, refus ou échec, « à la fin, le poste est revenu hors réseau » (Task 2).
2. **Deux demandes simultanées pour la dernière place** : les deux acceptées, une 7ᵉ personne dans une partie à 6. → scénario « deux demandes pour la dernière place » : exactement un inscrit et un refus « plein » (Task 2) ; « examiner une demande n'inscrit personne » (Task 1 : l'inscription se fait à la réponse, pas avant).
3. **La raison d'un refus perdue ou doublée** : le client voit « hôte perdu » ou « connexion échouée » au lieu de « version différente », ou les deux à la suite. → « refusé avec la raison RESEAU_REFUS_VERSION et la version de l'hôte 0.11 », « refusé avec la raison RESEAU_REFUS_MANCHE… », « un refus n'est suivi d'aucun autre signal » (Task 2).
4. **Une demande mal formée ou venue d'un autre programme** sur le port 7777 (un autre jeu, une ancienne version aux champs différents) : plantage de l'hôte ou joueur accepté. → « une demande mal formée ou d'un autre programme est refusée, sans erreur » (Task 1).
5. **Une place perdue pour toujours** : un accepté qui ne finit jamais sa poignée de main, ou un index / une couleur qui ne se libère pas au départ d'un joueur, et la partie se dit pleine avec des fantômes. → « un accepté qui ne finit pas sa poignée de main libère sa place… », « après un départ : l'index 1 et la troisième couleur sont les premiers libres » (Task 1) ; « un client parti n'est plus inscrit », « son index est de nouveau libre » (Task 2).

---

### Task 0 : vérification des plans

Ce plan et celui de la phase 11 bis ont été commités par le commit de planification de la phase 11, avec la mise à jour du tableau de la feuille de route (lignes 11, 11 bis et 15) : ne pas les recommiter, **ne jamais les modifier** (ni réécriture, ni résumé). Pas d'autre étape.

---

### Task 1 : l'autoload `Reseau` (poignée de main, attribution, transport)

**Files:**
- Create: `Scripts/Reseau.gd`
- Modify: `project.godot` (sections `[application]` et `[autoload]`)
- Test: `tests/unitaires.gd` (`_run`, une fonction à la fin)

**Interfaces:**
- Consumes : `EtatPartie.NB_JOUEURS_MAX` (6), `EtatPartie.PALETTE_BATAILLE` (`Array[Color]`, 6 couleurs) ; l'API de Godot `SceneMultiplayer` (`auth_callback`, `auth_timeout`, `send_auth`, `complete_auth`, signaux `peer_authenticating`, `peer_authentication_failed`, `peer_connected`, `peer_disconnected`, `connected_to_server`, `connection_failed`, `server_disconnected`).
- Produces (autoload `/root/Reseau`, sans `class_name`) :
  - signaux : `joueur_arrive(id: int)`, `joueur_parti(id: int)` (hôte) ; `inscrit(index: int, couleur: Color)`, `refuse(raison: String, version_hote: String)`, `connexion_echouee()`, `hote_perdu()` (client ; les trois derniers après le retour hors réseau, une seule fois par connexion) ;
  - constantes : `PORT := 7777`, `JEU := "LELION"`, `DELAI_CONNEXION := 5.0`, `DELAI_POIGNEE_DE_MAIN := 3.0`, `PSEUDO_MAX := 12`, `CONNEXIONS_EN_TROP := 2`, `REFUS_VERSION := "RESEAU_REFUS_VERSION"`, `REFUS_PLEIN := "RESEAU_REFUS_PLEIN"`, `REFUS_MANCHE := "RESEAU_REFUS_MANCHE"`, `REFUS_DEMANDE := "RESEAU_REFUS_DEMANDE"` ;
  - variables : `version: String`, `pseudo: String`, `places: int` (défaut 6), `manche_en_cours: bool`, `inscrits: Dictionary[int, Dictionary]` (`{"index": int, "couleur": Color, "pseudo": String}`), `index_local: int` (-1 hors réseau), `couleur_locale: Color` ;
  - méthodes : `heberger(port := PORT) -> Error`, `rejoindre(adresse: String, port := PORT) -> Error`, `quitter() -> void`, `en_ligne() -> bool`, `examiner_demande(demande: Variant) -> Dictionary` (`{"accepte": true, "index", "couleur", "pseudo"}` ou `{"accepte": false, "raison", "version_hote"}`), `static premier_index_libre(occupes: Dictionary[int, Dictionary], nb_places: int) -> int`, `static premiere_couleur_libre(occupes: Dictionary[int, Dictionary]) -> Color`, `static pseudo_valide(texte: String) -> String` ;
  - gestionnaires que le test unitaire appelle directement : `_sur_echec_poignee_de_main(id: int)`, `_sur_pair_deconnecte(id: int)`.
  - `project.godot` : `config/version="0.11"`, autoload `Reseau="*res://Scripts/Reseau.gd"`.

- [ ] **Step 1 : le test (il échoue : l'autoload n'existe pas)**

1a. Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_territoire()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_territoire()
	_tester_reseau()
	print("== %d échec(s) ==" % _echecs)
```

1b. Ajouter à la fin de `tests/unitaires.gd` :

```gdscript


func _tester_reseau() -> void:
	print("-- Réseau (poignée de main, attribution)")
	var reseau: Node = root.get_node("Reseau")  # autoload : jamais nommé (compilé avant lui)
	var api: SceneMultiplayer = root.multiplayer
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	_check(not reseau.en_ligne() and api.multiplayer_peer is OfflineMultiplayerPeer and api.is_server(),
		"hors réseau par défaut : pair hors ligne, ce poste est son propre hôte (le solo)")
	_check(not reseau.version.is_empty() and reseau.version == ProjectSettings.get_setting("application/config/version"),
		"la version présentée est celle du projet (%s)" % reseau.version)

	# Attribution : le plus petit index libre et la première couleur libre, chacun de son côté
	var occupes: Dictionary[int, Dictionary] = {}
	_check(reseau.premier_index_libre(occupes, 6) == 0 and reseau.premiere_couleur_libre(occupes) == palette[0],
		"partie vide : index 0 et première couleur")
	occupes[1] = {"index": 0, "couleur": palette[0], "pseudo": "Hôte"}
	occupes[77] = {"index": 2, "couleur": palette[1], "pseudo": "B"}
	_check(reseau.premier_index_libre(occupes, 6) == 1 and reseau.premiere_couleur_libre(occupes) == palette[2],
		"après un départ : l'index 1 et la troisième couleur sont les premiers libres (index et couleur indépendants)")
	_check(reseau.premier_index_libre(occupes, 2) == 1 and reseau.premier_index_libre(occupes, 1) == -1,
		"les places bornent les index : 1 est libre sur 2 places, rien sur 1")
	occupes[78] = {"index": 1, "couleur": palette[2], "pseudo": "C"}
	for i in range(3, EtatPartie.NB_JOUEURS_MAX):
		occupes[100 + i] = {"index": i, "couleur": palette[i], "pseudo": ""}
	_check(occupes.size() == EtatPartie.NB_JOUEURS_MAX and reseau.premier_index_libre(occupes, 9) == -1
		and reseau.premiere_couleur_libre(occupes) == Color.TRANSPARENT,
		"à %d joueurs, plus d'index ni de couleur, même si l'on demande plus de places" % EtatPartie.NB_JOUEURS_MAX)
	_check(reseau.pseudo_valide("  Léa\n\t ") == "Léa" and reseau.pseudo_valide("Zoé la grande dompteuse") == "Zoé la grand"
		and reseau.pseudo_valide("Zoé la grande dompteuse").length() == reseau.PSEUDO_MAX,
		"le pseudo est nettoyé (contrôles, espaces) et coupé à %d caractères" % reseau.PSEUDO_MAX)

	# Décision de l'hôte sur une demande
	var version: String = reseau.version
	var places: int = reseau.places
	var demande := {"jeu": reseau.JEU, "version": version, "pseudo": "  Zoé la grande dompteuse "}
	reseau.inscrits[1] = {"index": 0, "couleur": palette[0], "pseudo": "Hôte"}
	var r: Dictionary = reseau.examiner_demande(demande)
	_check(r.accepte and r.index == 1 and r.couleur == palette[1] and r.pseudo == "Zoé la grand",
		"demande valable : acceptée avec l'index 1, la deuxième couleur et le pseudo nettoyé (%s)" % [r])
	_check(reseau.inscrits.size() == 1, "examiner une demande n'inscrit personne")
	var autre_version := demande.duplicate()
	autre_version.version = "0.0-ancienne"
	r = reseau.examiner_demande(autre_version)
	_check(not r.accepte and r.raison == reseau.REFUS_VERSION and r.version_hote == version,
		"version différente : refusée, avec la version de l'hôte pour le message (%s)" % [r])
	reseau.manche_en_cours = true
	_check(reseau.examiner_demande(demande).raison == reseau.REFUS_MANCHE, "manche en cours : refusée")
	_check(reseau.examiner_demande(autre_version).raison == reseau.REFUS_VERSION,
		"une version différente se dit avant tout autre refus (le joueur sait quoi mettre à jour)")
	reseau.manche_en_cours = false
	reseau.places = 2
	reseau.inscrits[5] = {"index": 1, "couleur": palette[1], "pseudo": "B"}
	_check(reseau.examiner_demande(demande).raison == reseau.REFUS_PLEIN, "partie pleine (2 places sur 2) : refusée")
	reseau.places = places
	for i in range(2, EtatPartie.NB_JOUEURS_MAX):
		reseau.inscrits[10 + i] = {"index": i, "couleur": palette[i], "pseudo": ""}
	_check(reseau.examiner_demande(demande).raison == reseau.REFUS_PLEIN,
		"partie pleine à %d joueurs : refusée" % EtatPartie.NB_JOUEURS_MAX)
	reseau.inscrits.clear()
	var mal_formees: Array = [null, 42, "LELION", {}, {"jeu": "AUTRE", "version": version, "pseudo": "x"},
		{"jeu": reseau.JEU, "version": 11, "pseudo": "x"}, {"jeu": reseau.JEU, "version": version},
		{"jeu": reseau.JEU, "version": version, "pseudo": ["x"]}]
	var refus_demande := mal_formees.all(func(d: Variant) -> bool:
		var reponse: Dictionary = reseau.examiner_demande(d)
		return not reponse.accepte and reponse.raison == reseau.REFUS_DEMANDE)
	_check(refus_demande, "une demande mal formée ou d'un autre programme est refusée, sans erreur")

	# Départs vus par l'hôte
	var partis: Array[int] = []
	var sur_depart := func(id: int) -> void: partis.append(id)
	reseau.joueur_parti.connect(sur_depart)
	reseau.inscrits[42] = {"index": 1, "couleur": palette[1], "pseudo": "Fantôme"}
	reseau._sur_echec_poignee_de_main(42)
	_check(not reseau.inscrits.has(42) and partis.is_empty(),
		"un accepté qui ne finit pas sa poignée de main libère sa place, sans être signalé comme parti")
	reseau.inscrits[43] = {"index": 1, "couleur": palette[1], "pseudo": "B"}
	reseau._sur_pair_deconnecte(43)
	reseau._sur_pair_deconnecte(99)
	_check(not reseau.inscrits.has(43) and partis == [43], "un inscrit qui part est signalé une fois ; un inconnu, jamais (%s)" % [partis])
	reseau.joueur_parti.disconnect(sur_depart)

	# Hébergement : port occupé, puis libre, puis retour hors réseau
	var port := 17790
	var occupant := ENetMultiplayerPeer.new()
	_check(occupant.create_server(port) == OK, "un autre programme occupe le port %d" % port)
	var erreur: int = reseau.heberger(port)
	_check(erreur != OK and not reseau.en_ligne() and api.is_server() and reseau.inscrits.is_empty(),
		"port occupé : heberger renvoie l'erreur (%d) et le poste reste hors réseau" % erreur)
	occupant.close()
	reseau.pseudo = "Hôte"
	_check(reseau.heberger(port) == OK and reseau.en_ligne() and api.is_server() and reseau.inscrits.size() == 1
		and reseau.index_local == 0 and reseau.couleur_locale == palette[0] and reseau.inscrits[1].pseudo == "Hôte",
		"port libre : l'hôte écoute et s'inscrit lui-même (index 0, première couleur, son pseudo)")
	reseau.quitter()
	_check(not reseau.en_ligne() and api.multiplayer_peer is OfflineMultiplayerPeer and api.is_server()
		and reseau.inscrits.is_empty() and reseau.index_local == -1 and api.auth_callback.is_null(),
		"quitter revient hors réseau : pair hors ligne, hôte de soi-même, plus d'inscrits ni de poignée de main")
	reseau.pseudo = ""
```

- [ ] **Step 2 : lancer le test, constater l'échec**

Run : `export PATH="/opt/homebrew/bin:$PATH"; timeout 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|Node not found|== " "$TMPDIR/t.log"`
Expected : `code 0` (!), mais `ERROR: Node not found: "Reseau" (relative to "/root").` puis `SCRIPT ERROR: Attempt to call function 'en_ligne' in base 'null instance' on a null instance.` ; `== 0 échec(s) ==` quand même, la fonction s'étant arrêtée à sa première ligne. C'est exactement le cas que le filtre `SCRIPT ERROR` rattrape.

- [ ] **Step 3 : la version et l'autoload dans `project.godot`**

3a. Dans `project.godot`, remplacer :

```ini
config/name="LeLion"
run/main_scene="res://Scenes/Titre.tscn"
```

par :

```ini
config/name="LeLion"
config/version="0.11"
run/main_scene="res://Scenes/Titre.tscn"
```

3b. Remplacer :

```ini
Audio="*res://Scripts/Audio.gd"
```

par :

```ini
Audio="*res://Scripts/Audio.gd"
Reseau="*res://Scripts/Reseau.gd"
```

- [ ] **Step 4 : `Scripts/Reseau.gd`**

Créer `Scripts/Reseau.gd` :

```gdscript
extends Node
## Transport LAN (spec §4) : le pair ENet (port UDP 7777), la poignée de main (version, pseudo),
## l'attribution des index et des couleurs par l'hôte, les arrivées et les départs. Ne sait rien
## de la partie : le salon (phase 13) et la manche synchronisée (phase 14) s'appuient sur ses
## signaux et sur `inscrits`. Hors réseau (solo, retour au titre), le pair est un
## `OfflineMultiplayerPeer` : ce poste est son propre hôte (`multiplayer.is_server()` vrai), et
## `quitter()` y revient toujours.
##
## La poignée de main passe par l'authentification de `SceneMultiplayer` : des octets bruts
## (`var_to_bytes` d'un dictionnaire), échangés avant tout RPC, si bien que deux versions
## différentes du jeu peuvent encore se dire pourquoi elles ne jouent pas ensemble. Le client
## envoie `{jeu, version, pseudo}` ; l'hôte répond `{accepte: true, index, couleur, pseudo}` ou
## `{accepte: false, raison, version_hote}` ; le client refusé ferme lui-même la connexion (sinon,
## le délai de la poignée de main la ferme). Un joueur accepté est inscrit chez l'hôte dès la
## réponse (sa place est prise) : deux demandes simultanées ne peuvent ni obtenir la même place,
## ni dépasser le nombre de places.
##
## Autoload : les tests `--script`, compilés avant l'enregistrement des autoloads, le récupèrent
## par `root.get_node("Reseau")` et ne le nomment pas.

## Chez l'hôte : un joueur a fini sa poignée de main (il est dans `inscrits`, les RPC passent).
signal joueur_arrive(id: int)
## Chez l'hôte : un joueur arrivé est parti ; sa place, son index et sa couleur sont libres.
signal joueur_parti(id: int)
## Chez le client : l'hôte l'a accepté et la connexion est établie (`index_local`, `couleur_locale`).
signal inscrit(index: int, couleur: Color)
## Chez le client : l'hôte a refusé ; `raison` est une des constantes REFUS_* (clé de traduction
## pour l'écran Réseau de la phase 12), `version_hote` la version de l'hôte. Le poste est déjà
## revenu hors réseau quand le signal part.
signal refuse(raison: String, version_hote: String)
## Chez le client : pas d'inscription dans le délai (IP qui ne répond pas, port fermé). Le poste
## est déjà revenu hors réseau quand le signal part.
signal connexion_echouee()
## Chez le client : l'hôte a quitté la partie ou ne répond plus. Le poste est déjà revenu hors
## réseau quand le signal part.
signal hote_perdu()

const PORT := 7777
## Identifiant de la poignée de main : une demande qui ne le porte pas vient d'un autre programme.
const JEU := "LELION"
## Délai d'une connexion jusqu'à l'inscription (spec §9 : 5 s puis message).
const DELAI_CONNEXION := 5.0
## Délai laissé à chaque pair pour finir la poignée de main (`SceneMultiplayer.auth_timeout`).
const DELAI_POIGNEE_DE_MAIN := 3.0
## Longueur maximale d'un pseudo, en caractères, imposée par l'hôte (l'étiquette du lion est
## centrée sur lui et coupée par le bord de l'écran au-delà d'une douzaine de caractères).
const PSEUDO_MAX := 12
## Connexions ENet acceptées au-delà des places : de quoi recevoir, et refuser explicitement, les
## demandes d'une partie pleine au lieu de les laisser échouer sans explication.
const CONNEXIONS_EN_TROP := 2
const REFUS_VERSION := "RESEAU_REFUS_VERSION"
const REFUS_PLEIN := "RESEAU_REFUS_PLEIN"
const REFUS_MANCHE := "RESEAU_REFUS_MANCHE"
const REFUS_DEMANDE := "RESEAU_REFUS_DEMANDE"

## Version présentée à la poignée de main (`application/config/version`) ; deux versions
## différentes ne jouent pas ensemble. Modifiable par les tests.
var version: String = ProjectSettings.get_setting("application/config/version", "")
## Pseudo de ce poste, présenté à l'hôte (ou inscrit tel quel quand ce poste héberge).
var pseudo := ""
## Nombre de joueurs d'une partie hébergée, hôte compris (au plus `EtatPartie.NB_JOUEURS_MAX`).
var places := EtatPartie.NB_JOUEURS_MAX
## Posé par la partie (phase 13 au lancement de la manche, phase 18 au retour au salon) : tant
## qu'il est vrai, l'hôte refuse tout nouveau venu (pas d'arrivée en cours de manche, spec §1).
var manche_en_cours := false
## Chez l'hôte : les joueurs inscrits, hôte compris, par identifiant réseau :
## `{"index": int, "couleur": Color, "pseudo": String}`. Vide chez un client et hors réseau.
var inscrits: Dictionary[int, Dictionary] = {}
## Index et couleur de ce poste, attribués par l'hôte (-1 et transparente hors réseau).
var index_local := -1
var couleur_locale := Color.TRANSPARENT

## Vrai dès que l'issue d'une connexion est décidée (refus, échec, hôte perdu) : un seul signal
## part, même quand ENet signale ensuite la fermeture qui en découle.
var _issue_decidee := false
var _delai: Timer


func _ready() -> void:
	# Les délais courent aussi quand l'arbre est en pause (fin de manche).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_delai = Timer.new()
	_delai.one_shot = true
	_delai.timeout.connect(_sur_delai_depasse)
	add_child(_delai)
	var api := _api()
	api.peer_authenticating.connect(_sur_debut_poignee_de_main)
	api.peer_authentication_failed.connect(_sur_echec_poignee_de_main)
	api.peer_connected.connect(_sur_pair_connecte)
	api.peer_disconnected.connect(_sur_pair_deconnecte)
	api.connected_to_server.connect(_sur_connecte_a_l_hote)
	api.connection_failed.connect(_sur_connexion_echouee)
	api.server_disconnected.connect(_sur_hote_perdu)


## Héberge une partie sur `port`. Ce poste s'inscrit lui-même (index 0, première couleur).
## Renvoie l'erreur d'ENet sans rien changer si le port est pris (spec §9 : « port occupé »).
func heberger(port := PORT) -> Error:
	quitter()
	var pair := ENetMultiplayerPeer.new()
	var erreur := pair.create_server(port, places + CONNEXIONS_EN_TROP)
	if erreur != OK:
		return erreur
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = pair
	index_local = premier_index_libre(inscrits, places)
	couleur_locale = premiere_couleur_libre(inscrits)
	inscrits[multiplayer.get_unique_id()] = {"index": index_local, "couleur": couleur_locale, "pseudo": pseudo_valide(pseudo)}
	return OK


## Rejoint l'hôte à `adresse`. La réponse arrive par `inscrit`, `refuse` ou `connexion_echouee`
## (au plus tard après DELAI_CONNEXION). Renvoie l'erreur d'ENet si le client ne peut même pas
## être créé (adresse invalide).
func rejoindre(adresse: String, port := PORT) -> Error:
	quitter()
	var pair := ENetMultiplayerPeer.new()
	var erreur := pair.create_client(adresse, port)
	if erreur != OK:
		return erreur
	_activer_poignee_de_main()
	multiplayer.multiplayer_peer = pair
	_delai.start(DELAI_CONNEXION)
	return OK


## Quitte le réseau : ferme le pair (les autres postes voient partir ce joueur, ou l'hôte), remet
## `OfflineMultiplayerPeer` et oublie inscrits, index et couleur. Sans effet visible hors réseau :
## chaque chemin de retour au titre peut l'appeler (point de vigilance des phases 12/13).
func quitter() -> void:
	_delai.stop()
	var pair := multiplayer.multiplayer_peer
	if pair != null and not (pair is OfflineMultiplayerPeer):
		pair.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_api().auth_callback = Callable()
	inscrits.clear()
	index_local = -1
	couleur_locale = Color.TRANSPARENT
	_issue_decidee = false


## Vrai si ce poste est en réseau (hôte ou client), faux hors réseau (solo).
func en_ligne() -> bool:
	return not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


## Décision de l'hôte sur une demande d'inscription (le dictionnaire décodé, ou n'importe quoi
## venu d'un autre programme). Dans l'ordre : demande mal formée, version différente, manche en
## cours, partie pleine ; sinon l'index et la couleur libres les plus bas, et le pseudo nettoyé.
## Ne modifie rien : c'est `_repondre` qui inscrit.
func examiner_demande(demande: Variant) -> Dictionary:
	if not (demande is Dictionary) or not _est_texte(demande, "jeu") or demande.jeu != JEU \
			or not _est_texte(demande, "version") or not _est_texte(demande, "pseudo"):
		return _refus(REFUS_DEMANDE)
	if demande.version != version:
		return _refus(REFUS_VERSION)
	if manche_en_cours:
		return _refus(REFUS_MANCHE)
	var index := premier_index_libre(inscrits, places)
	if index < 0:
		return _refus(REFUS_PLEIN)
	return {"accepte": true, "index": index, "couleur": premiere_couleur_libre(inscrits), "pseudo": pseudo_valide(demande.pseudo)}


## Le plus petit index de joueur qu'aucun inscrit n'occupe, parmi les `places` premiers (au plus
## NB_JOUEURS_MAX) ; -1 si la partie est pleine.
static func premier_index_libre(occupes: Dictionary[int, Dictionary], nb_places: int) -> int:
	var pris := occupes.values().map(func(fiche: Dictionary) -> int: return fiche.index)
	for i in range(mini(nb_places, EtatPartie.NB_JOUEURS_MAX)):
		if not pris.has(i):
			return i
	return -1


## La première couleur de la palette de bataille qu'aucun inscrit ne porte (transparente s'il n'y
## en a plus, ce que les places interdisent). Le salon (phase 13) laissera chacun en changer
## parmi les libres.
static func premiere_couleur_libre(occupes: Dictionary[int, Dictionary]) -> Color:
	var prises := occupes.values().map(func(fiche: Dictionary) -> Color: return fiche.couleur)
	for c in EtatPartie.PALETTE_BATAILLE:
		if not prises.has(c):
			return c
	return Color.TRANSPARENT


## Le pseudo tel que l'hôte l'inscrit : sans caractères de contrôle ni espaces autour, au plus
## PSEUDO_MAX caractères.
static func pseudo_valide(texte: String) -> String:
	return texte.strip_escapes().strip_edges().left(PSEUDO_MAX)


func _api() -> SceneMultiplayer:
	return multiplayer as SceneMultiplayer


func _activer_poignee_de_main() -> void:
	var api := _api()
	api.auth_callback = _sur_donnees_poignee_de_main
	api.auth_timeout = DELAI_POIGNEE_DE_MAIN


func _refus(raison: String) -> Dictionary:
	return {"accepte": false, "raison": raison, "version_hote": version}


static func _est_texte(d: Dictionary, cle: String) -> bool:
	return d.get(cle) is String


## Début de la poignée de main avec `id` : le client présente sa demande, l'hôte attend la sienne.
func _sur_debut_poignee_de_main(id: int) -> void:
	if multiplayer.is_server():
		return
	_api().send_auth(id, var_to_bytes({"jeu": JEU, "version": version, "pseudo": pseudo}))


## Octets de poignée de main reçus de `id` : une demande (chez l'hôte) ou la réponse de l'hôte.
func _sur_donnees_poignee_de_main(id: int, donnees: PackedByteArray) -> void:
	if multiplayer.is_server():
		_repondre(id, bytes_to_var(donnees))
	else:
		_lire_reponse(bytes_to_var(donnees))


func _repondre(id: int, demande: Variant) -> void:
	if inscrits.has(id):
		return  # demande répétée : la première réponse fait foi
	var reponse := examiner_demande(demande)
	if reponse.accepte:
		inscrits[id] = {"index": reponse.index, "couleur": reponse.couleur, "pseudo": reponse.pseudo}
	_api().send_auth(id, var_to_bytes(reponse))
	# Un refusé n'est pas déconnecté ici : ENet viderait sa file d'envoi, réponse comprise, et le
	# client ne saurait jamais pourquoi. Il part de lui-même en lisant le refus ; sinon le délai de
	# la poignée de main (DELAI_POIGNEE_DE_MAIN) le déconnecte.
	if reponse.accepte:
		_api().complete_auth(id)


func _lire_reponse(reponse: Variant) -> void:
	var valide := reponse is Dictionary and reponse.get("accepte") is bool
	if valide and reponse.accepte and reponse.get("index") is int and reponse.get("couleur") is Color:
		index_local = reponse.index
		couleur_locale = reponse.couleur
		_api().complete_auth(MultiplayerPeer.TARGET_PEER_SERVER)
		return
	var raison: String = reponse.raison if valide and reponse.get("raison") is String else REFUS_DEMANDE
	var version_hote: String = reponse.version_hote if valide and reponse.get("version_hote") is String else ""
	_decider("refuse", [raison, version_hote])


## Chez l'hôte, un pair qui ne finit pas sa poignée de main (délai, départ) libère la place qui
## lui avait été attribuée ; il n'était jamais « arrivé », il ne « part » donc pas.
func _sur_echec_poignee_de_main(id: int) -> void:
	if multiplayer.is_server():
		inscrits.erase(id)


func _sur_pair_connecte(id: int) -> void:
	if multiplayer.is_server() and inscrits.has(id):
		joueur_arrive.emit(id)


func _sur_pair_deconnecte(id: int) -> void:
	if multiplayer.is_server() and inscrits.erase(id):
		joueur_parti.emit(id)


func _sur_connecte_a_l_hote() -> void:
	_delai.stop()
	inscrit.emit(index_local, couleur_locale)


func _sur_connexion_echouee() -> void:
	_decider("connexion_echouee")


## L'hôte ferme la connexion. Avant l'inscription (délai encore en cours), c'est un échec de
## connexion, pas un hôte perdu : ce poste n'a jamais été dans la partie.
func _sur_hote_perdu() -> void:
	_decider("connexion_echouee" if not _delai.is_stopped() else "hote_perdu")


func _sur_delai_depasse() -> void:
	if en_ligne() and not multiplayer.is_server():
		_decider("connexion_echouee")


## Décide l'issue de la connexion (signal `nom`), une seule fois. Différé : on ne change pas de
## pair pendant que SceneMultiplayer traite ses paquets.
func _decider(nom: StringName, arguments: Array = []) -> void:
	if _issue_decidee:
		return
	_issue_decidee = true
	_fermer_puis_emettre.call_deferred(nom, arguments)


## Revient hors réseau, puis émet le signal `nom` : ceux qui le reçoivent trouvent déjà le poste
## hors réseau (un retour au titre y relance une partie solo qui fonctionne).
func _fermer_puis_emettre(nom: StringName, arguments: Array) -> void:
	quitter()
	callv("emit_signal", [nom] + arguments)
```

- [ ] **Step 5 : importer (le `.uid` du nouveau script), relancer le test**

Run : `export PATH="/opt/homebrew/bin:$PATH"; timeout 300 godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"; ls Scripts/Reseau.gd.uid`
Expected : aucune ligne d'erreur, puis `Scripts/Reseau.gd.uid`.

Run : `export PATH="/opt/homebrew/bin:$PATH"; timeout 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"; sed -n '/-- Réseau/,/== /p' "$TMPDIR/t.log"`
Expected : `code 0`, `== 0 échec(s) ==`, et dans la section « -- Réseau » les 21 lignes ✅, de « hors réseau par défaut : pair hors ligne, ce poste est son propre hôte (le solo) » et « la version présentée est celle du projet (0.11) » à « quitter revient hors réseau : pair hors ligne, hôte de soi-même, plus d'inscrits ni de poignée de main », dont « port occupé : heberger renvoie l'erreur (20) et le poste reste hors réseau » (20 = `ERR_CANT_CREATE`), précédée du bruit attendu `ERROR: Couldn't create an ENet host.`

- [ ] **Step 6 : le solo et la bataille locale n'ont pas bougé**

Run : les deux autres suites avec la commande des Global Constraints (`T=tests/smoke_test.gd; O=""`, puis `T=tests/bataille_test.gd; O="--fixed-fps 60"`), 5 fois chacune.
Expected : `code 0` et `== 0 échec(s) ==` à chaque passage, aucune `SCRIPT ERROR` ni `SHADER ERROR`.

- [ ] **Step 7 : Commit**

```bash
git add Scripts/Reseau.gd Scripts/Reseau.gd.uid project.godot tests/unitaires.gd
git commit -m "Réseau : autoload Reseau (ENet 7777, poignée de main par l'authentification de SceneMultiplayer, refus explicites version / plein / manche / demande, index et couleurs attribués par l'hôte, départs, retour hors réseau) ; version du projet 0.11

<ligne fournie par l'environnement>"
```

---

### Task 2 : le test à plusieurs processus (hôte + 2 clients, refus, départs)

**Files:**
- Create: `tests/reseau/joueur.gd`
- Create: `tests/reseau/lancer.sh` (exécutable)

**Interfaces:**
- Consumes : l'autoload de la Task 1 (signaux, `heberger`, `rejoindre`, `quitter`, `en_ligne`, `inscrits`, `index_local`, `places`, `manche_en_cours`, `version`, `pseudo`, `premier_index_libre`, constantes `REFUS_*` et `DELAI_CONNEXION`) ; `EtatPartie.PALETTE_BATAILLE`, `EtatPartie.NB_JOUEURS_MAX`.
- Produces : `godot --headless --script tests/reseau/joueur.gd -- --role=hote|client [options]` (options dans la docstring ; lignes `HOTE PRET` et `RESULTAT …` ; code de sortie 0 si toutes ses vérifications passent) ; `bash tests/reseau/lancer.sh [port_de_base]` (défaut 17777 ; variables `GODOT`, `DELAI`) qui joue 4 scénarios et sort en 0 seulement si tout est vert. Les phases 13 à 16 y ajoutent leurs scénarios (salon, manche synchronisée, empreintes, latence).

Les 4 scénarios, un port chacun (port de base + n) :
1. hôte + 2 clients ; un 3ᵉ se présente avec la version `0.0-ancienne` et est refusé ; l'un des deux clients repart de lui-même une fois l'autre en vue (l'hôte voit son départ et récupère son index), puis l'hôte quitte (le client restant le voit partir, une fois, comme « hôte perdu ») ;
2. partie à 2 places, deux demandes simultanées : exactement une acceptée, l'autre refusée « plein » (compté par `lancer.sh` d'un journal à l'autre) ;
3. manche en cours : l'arrivant est refusé « manche » ;
4. aucun hôte : la connexion échoue après le délai de 5 s.

- [ ] **Step 1 : le poste du test**

Créer `tests/reseau/joueur.gd` :

```gdscript
extends SceneTree
## Un poste du test réseau, lancé par tests/reseau/lancer.sh (un processus Godot par poste) :
##   godot --headless --script tests/reseau/joueur.gd -- --role=hote|client [options]
## Communes : --port=N (défaut 17777), --pseudo=texte.
## Hôte : --places=N (joueurs, hôte compris ; défaut 6), --clients=N (clients qui doivent arriver),
##   --partants=N (clients qui repartiront d'eux-mêmes), --manche (manche en cours : tout nouveau
##   venu est refusé), --attente=S (secondes gardées ouvertes après les arrivées et départs, pour
##   les demandes qui doivent être refusées). Écrit « HOTE PRET » quand il écoute, puis quitte le
##   réseau (ses clients doivent voir l'hôte partir).
## Client : --attendu=inscrit|inscrit_ou_plein|refus_version|refus_manche|echec, --version=x.y (se
##   présente avec cette version au lieu de la sienne), --partir (une fois inscrit et un autre
##   client en vue, quitte de lui-même ; sinon, attend que l'hôte parte). Écrit une ligne
##   « RESULTAT … » que lancer.sh compte d'un poste à l'autre.
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
## `Reseau` par `root.get_node`, ne nomme ni `Reseau` ni `GameState` (il peut nommer
## `EtatPartie`, dont le script ne nomme aucun autoload).

const DELAI_ETAPE := 15.0  # secondes au plus pour chaque attente

var _echecs := 0
var _options := {}
var reseau: Node
var _arrivees: Array[int] = []
var _departs: Array[int] = []
var _issue := ""  # client : les signaux reçus, dans l'ordre (voir `_ajouter_issue`)
var _raison := ""
var _version_hote := ""
var _index := -1
var _couleur := Color.TRANSPARENT


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var morceaux := arg.trim_prefix("--").split("=", true, 1)
		_options[morceaux[0]] = morceaux[1] if morceaux.size() > 1 else "oui"
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _option(nom: String, defaut: String) -> String:
	return _options.get(nom, defaut)


## Attend (au plus DELAI_ETAPE) que `condition` soit vraie ; renvoie sa dernière valeur.
func _attendre(condition: Callable) -> bool:
	var fin := Time.get_ticks_msec() + int(DELAI_ETAPE * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < fin:
		await process_frame
	return condition.call()


func _pause(secondes: float) -> void:
	await create_timer(secondes).timeout


func _run() -> void:
	reseau = root.get_node("Reseau")
	reseau.pseudo = _option("pseudo", "Poste")
	var role := _option("role", "")
	print("== poste réseau : %s (%s) ==" % [role, reseau.pseudo])
	if role == "hote":
		await _jouer_hote()
	elif role == "client":
		await _jouer_client()
	else:
		_check(false, "rôle inconnu : --role=hote ou --role=client")
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		and root.multiplayer.is_server() and reseau.inscrits.is_empty() and reseau.index_local == -1,
		"à la fin, le poste est revenu hors réseau (pair hors ligne, hôte de lui-même, plus d'inscrits)")
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _jouer_hote() -> void:
	var nb_clients := int(_option("clients", "0"))
	var nb_partants := int(_option("partants", "0"))
	reseau.places = int(_option("places", str(EtatPartie.NB_JOUEURS_MAX)))
	reseau.manche_en_cours = _options.has("manche")
	reseau.joueur_arrive.connect(_sur_arrivee)
	reseau.joueur_parti.connect(_sur_depart)
	var erreur: int = reseau.heberger(int(_option("port", "17777")))
	_check(erreur == OK, "l'hôte écoute (erreur %d)" % erreur)
	if erreur != OK:
		return
	print("HOTE PRET")
	var hote: Dictionary = reseau.inscrits[root.multiplayer.get_unique_id()]
	_check(root.multiplayer.is_server() and hote.index == 0 and hote.couleur == EtatPartie.PALETTE_BATAILLE[0]
		and hote.pseudo == reseau.pseudo, "l'hôte s'inscrit lui-même : index 0, première couleur, son pseudo")

	_check(await _attendre(func() -> bool: return _arrivees.size() >= nb_clients),
		"%d client(s) arrivé(s) sur %d attendu(s)" % [_arrivees.size(), nb_clients])
	var indices: Array = reseau.inscrits.values().map(func(f: Dictionary) -> int: return f.index)
	var couleurs: Array = reseau.inscrits.values().map(func(f: Dictionary) -> Color: return f.couleur)
	indices.sort()
	var couleurs_distinctes := couleurs.all(func(c: Color) -> bool: return couleurs.count(c) == 1)
	var couleurs_de_la_palette := couleurs.all(func(c: Color) -> bool: return EtatPartie.PALETTE_BATAILLE.has(c))
	_check(indices == range(nb_clients + 1) and couleurs_distinctes and couleurs_de_la_palette,
		"les inscrits ont les index 0 à %d et chacun sa couleur de la palette (%s)" % [nb_clients, indices])

	if nb_partants > 0:
		_check(await _attendre(func() -> bool: return _departs.size() >= nb_partants),
			"%d client(s) parti(s) sur %d attendu(s)" % [_departs.size(), nb_partants])
		var libere: int = nb_clients + 1 - nb_partants
		_check(_departs.all(func(id: int) -> bool: return not reseau.inscrits.has(id)) and reseau.inscrits.size() == libere,
			"un client parti n'est plus inscrit (%d inscrits)" % reseau.inscrits.size())
		_check(reseau.premier_index_libre(reseau.inscrits, reseau.places) < nb_clients + 1,
			"son index est de nouveau libre")

	await _pause(float(_option("attente", "0")))
	_check(_arrivees.size() == nb_clients, "aucune arrivée de trop : %d client(s) en tout" % _arrivees.size())
	reseau.quitter()
	await _pause(0.5)  # le temps que la fermeture parte vers les clients


func _jouer_client() -> void:
	var attendu := _option("attendu", "inscrit")
	var version_projet: String = reseau.version
	if _options.has("version"):
		reseau.version = _option("version", "")
	reseau.inscrit.connect(_sur_inscription)
	reseau.refuse.connect(_sur_refus)
	reseau.connexion_echouee.connect(_ajouter_issue.bind("echec"))
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	var debut := Time.get_ticks_msec()
	var erreur: int = reseau.rejoindre("127.0.0.1", int(_option("port", "17777")))
	_check(erreur == OK, "le client est créé (erreur %d)" % erreur)
	if erreur != OK:
		return
	await _attendre(func() -> bool: return not _issue.is_empty())
	var duree := (Time.get_ticks_msec() - debut) / 1000.0
	match _issue:
		"inscrit":
			print("RESULTAT inscrit index=%d" % _index)
		"refuse":
			print("RESULTAT refus %s" % _raison)
		_:
			print("RESULTAT %s" % _issue)

	match attendu:
		"inscrit", "inscrit_ou_plein":
			if attendu == "inscrit_ou_plein" and _issue == "refuse":
				_check(_raison == reseau.REFUS_PLEIN and _version_hote == version_projet,
					"refusé parce que la partie est pleine (%s)" % _raison)
				await _pause(1.0)
				_check(_issue == "refuse", "un refus n'est suivi d'aucun autre signal (%s)" % _issue)
				return
			_check(_issue == "inscrit" and _index >= 1 and _index < EtatPartie.NB_JOUEURS_MAX
				and _couleur == EtatPartie.PALETTE_BATAILLE[_index] and reseau.index_local == _index,
				"inscrit par l'hôte : index %d, couleur de la palette à cet index" % _index)
			if _issue != "inscrit":
				return
			if _options.has("partir"):
				_check(await _attendre(func() -> bool: return root.multiplayer.get_peers().size() >= 2),
					"un autre client est en vue (pairs : %s)" % [root.multiplayer.get_peers()])
				await _pause(0.5)
				reseau.quitter()
				_check(_issue == "inscrit", "partir de soi-même n'émet ni échec ni hôte perdu (%s)" % _issue)
			else:
				_check(await _attendre(func() -> bool: return _issue != "inscrit"), "l'hôte finit par partir")
				_check(_issue == "inscrit+hote_perdu", "le départ de l'hôte est signalé une fois, comme hôte perdu (%s)" % _issue)
		"refus_version", "refus_manche":
			var raison_attendue: String = reseau.REFUS_VERSION if attendu == "refus_version" else reseau.REFUS_MANCHE
			_check(_issue == "refuse" and _raison == raison_attendue and _version_hote == version_projet,
				"refusé avec la raison %s et la version de l'hôte %s (%s, %s)" % [raison_attendue, version_projet, _raison, _version_hote])
			await _pause(1.0)
			_check(_issue == "refuse", "un refus n'est suivi d'aucun autre signal (%s)" % _issue)
		"echec":
			_check(_issue == "echec" and duree >= reseau.DELAI_CONNEXION - 0.5 and duree <= reseau.DELAI_CONNEXION + 2.0,
				"sans hôte, la connexion échoue après le délai de %.0f s (%.1f s)" % [reseau.DELAI_CONNEXION, duree])
		_:
			_check(false, "issue attendue inconnue : %s" % attendu)


func _sur_arrivee(id: int) -> void:
	_arrivees.append(id)
	var fiche: Dictionary = reseau.inscrits[id]
	print("  arrivée de %d : index %d, « %s »" % [id, fiche.index, fiche.pseudo])


func _sur_depart(id: int) -> void:
	_departs.append(id)


func _sur_inscription(index: int, couleur: Color) -> void:
	_ajouter_issue("inscrit")
	_index = index
	_couleur = couleur


func _sur_refus(raison: String, version_hote: String) -> void:
	_ajouter_issue("refuse")
	_raison = raison
	_version_hote = version_hote


## Chaque signal reçu s'ajoute à l'issue : « inscrit+hote_perdu » est le parcours normal d'un
## client qui reste ; « refuse+echec » trahirait un double signal.
func _ajouter_issue(quoi: String) -> void:
	_issue = quoi if _issue.is_empty() else _issue + "+" + quoi
```

Écueil connu (vu en préparant le plan) : une lambda de plusieurs lignes dont la parenthèse fermante suit la dernière instruction sur la même ligne (`…connect(func(…) -> void:` / `…print(…))`), ou une lambda dont l'expression continue sur la ligne suivante, ne compile pas (`Parse Error: Expected closing ")" after call arguments`). D'où les gestionnaires en méthodes et les deux booléens calculés avant le `_check` des couleurs.

- [ ] **Step 2 : le lanceur**

Créer `tests/reseau/lancer.sh` :

```bash
#!/usr/bin/env bash
# Test réseau du transport (phase 11) : des postes headless sur localhost, un processus Godot par
# poste (tests/reseau/joueur.gd), scénario après scénario.
#   tests/reseau/lancer.sh [port_de_base]
# Le scénario n utilise le port port_de_base + n (défaut 17777 : jamais le 7777 d'une vraie partie).
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40).
# Sortie 0 si chaque poste sort en 0, sans ❌ ni SCRIPT ERROR ni SHADER ERROR dans son journal, et
# si les comptes croisés entre postes tombent juste. Tous les processus lancés sont tués en sortie.
set -u
cd "$(dirname "$0")/../.." || exit 2

GODOT="${GODOT:-godot}"
PORT_BASE="${1:-17777}"
DELAI="${DELAI:-40}"
JOURNAUX="$(mktemp -d "${TMPDIR:-/tmp}/lelion-reseau.XXXXXX")"
PIDS=()
NOMS=()
ECHECS=0

nettoyer() {
	local pid
	for pid in ${PIDS[@]+"${PIDS[@]}"}; do
		kill "$pid" 2>/dev/null
	done
	wait 2>/dev/null
}
trap nettoyer EXIT
trap 'echo "interrompu"; exit 130' INT TERM

echec() {
	echo "  ❌ $1"
	ECHECS=$((ECHECS + 1))
}

# lancer <nom> <arguments de joueur.gd…> : un poste en arrière-plan, borné par timeout (TERM au
# bout de DELAI secondes, KILL 5 s plus tard s'il résiste).
lancer() {
	local nom="$1"
	shift
	timeout -k 5 "$DELAI" "$GODOT" --headless --script tests/reseau/joueur.gd -- "$@" >"$JOURNAUX/$nom.log" 2>&1 &
	PIDS+=("$!")
	NOMS+=("$nom")
}

# attendre_hote <nom> : attend que l'hôte écoute (ligne « HOTE PRET »), 15 s au plus.
attendre_hote() {
	local i
	for i in $(seq 1 150); do
		grep -q "HOTE PRET" "$JOURNAUX/$1.log" 2>/dev/null && return 0
		sleep 0.1
	done
	echec "l'hôte $1 n'écoute pas"
	return 1
}

# terminer <titre> : attend chaque poste lancé, vérifie son code de sortie et son journal.
terminer() {
	local titre="$1" i code avant=$ECHECS
	for i in "${!PIDS[@]}"; do
		wait "${PIDS[$i]}"
		code=$?
		if [ "$code" -eq 124 ] || [ "$code" -eq 137 ]; then
			echec "$titre : ${NOMS[$i]} n'a pas fini dans les $DELAI s (tué par timeout)"
		elif [ "$code" -ne 0 ]; then
			echec "$titre : ${NOMS[$i]} sort en $code"
		fi
		if grep -HnE "❌|SCRIPT ERROR|SHADER ERROR|Parse Error" "$JOURNAUX/${NOMS[$i]}.log"; then
			echec "$titre : erreurs dans le journal de ${NOMS[$i]}"
		fi
	done
	PIDS=()
	NOMS=()
	[ "$ECHECS" -eq "$avant" ] && echo "  ✅ $titre"
}

# compter <motif> <nom…> : nombre de lignes qui contiennent le motif dans les journaux nommés.
compter() {
	local motif="$1" nom total=0 n
	shift
	for nom in "$@"; do
		n=$(grep -c -- "$motif" "$JOURNAUX/$nom.log" 2>/dev/null)
		total=$((total + ${n:-0}))
	done
	echo "$total"
}

echo "== test réseau LeLion (journaux : $JOURNAUX) =="

# 1. Hôte + 2 clients ; un troisième se présente avec une autre version. L'un des deux clients
#    repart de lui-même, puis l'hôte quitte : l'autre le voit partir.
P=$((PORT_BASE + 1))
lancer hote1 --role=hote --port=$P --pseudo=Hote --clients=2 --partants=1 --attente=1
if attendre_hote hote1; then
	lancer reste1 --role=client --port=$P --pseudo=Reste --attendu=inscrit
	lancer partant1 --role=client --port=$P --pseudo=Partant --attendu=inscrit --partir
	lancer ancien1 --role=client --port=$P --pseudo=Ancien --attendu=refus_version --version=0.0-ancienne
fi
terminer "hôte + 2 clients, départ d'un client et de l'hôte, version différente refusée"

# 2. Partie à 2 places, deux demandes simultanées : exactement une acceptée, l'autre refusée.
P=$((PORT_BASE + 2))
lancer hote2 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --attente=2
if attendre_hote hote2; then
	lancer rival2a --role=client --port=$P --pseudo=RivalA --attendu=inscrit_ou_plein
	lancer rival2b --role=client --port=$P --pseudo=RivalB --attendu=inscrit_ou_plein
fi
terminer "deux demandes pour la dernière place"
[ "$(compter "RESULTAT inscrit" rival2a rival2b)" -eq 1 ] || echec "dernière place : il fallait exactement un client inscrit"
[ "$(compter "RESULTAT refus RESEAU_REFUS_PLEIN" rival2a rival2b)" -eq 1 ] || echec "dernière place : il fallait exactement un refus « plein »"

# 3. Manche en cours : tout nouveau venu est refusé.
P=$((PORT_BASE + 3))
lancer hote3 --role=hote --port=$P --pseudo=Hote --manche --attente=3
if attendre_hote hote3; then
	lancer tard3 --role=client --port=$P --pseudo=Tard --attendu=refus_manche
fi
terminer "manche en cours : arrivée refusée"

# 4. Aucun hôte sur le port : la connexion échoue après le délai.
P=$((PORT_BASE + 4))
lancer seul4 --role=client --port=$P --pseudo=Seul --attendu=echec
terminer "sans hôte : échec de connexion après le délai"

echo "== $ECHECS échec(s) =="
if [ "$ECHECS" -eq 0 ]; then
	rm -rf "$JOURNAUX"
	exit 0
fi
echo "journaux gardés dans $JOURNAUX"
exit 1
```

Run : `chmod +x tests/reseau/lancer.sh && export PATH="/opt/homebrew/bin:$PATH" && timeout 300 godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"; ls tests/reseau`
Expected : aucune ligne d'erreur ; `joueur.gd  joueur.gd.uid  lancer.sh`.

- [ ] **Step 3 : lancer le test réseau**

Run : `export PATH="/opt/homebrew/bin:$PATH"; time bash tests/reseau/lancer.sh; echo "code $?"`
Expected (une quinzaine de secondes, dont 5 pour le scénario 4) :

```
== test réseau LeLion (journaux : …/lelion-reseau.XXXXXX) ==
  ✅ hôte + 2 clients, départ d'un client et de l'hôte, version différente refusée
  ✅ deux demandes pour la dernière place
  ✅ manche en cours : arrivée refusée
  ✅ sans hôte : échec de connexion après le délai
== 0 échec(s) ==
code 0
```

Pour lire les journaux d'un passage réussi (supprimés en fin de passage) : `sed 's/rm -rf "\$JOURNAUX"/:/' tests/reseau/lancer.sh > tests/reseau/garder.sh; bash tests/reseau/garder.sh; rm tests/reseau/garder.sh` puis `cat` du dossier affiché. Référence au moment du plan : l'hôte 1 voit arriver ses deux clients aux index 1 et 2 (dans l'ordre d'arrivée), le partant voit ses pairs `[1, <id de l'autre client>]`, le client qui reste finit sur `inscrit+hote_perdu`, l'ancien sur `RESULTAT refus RESEAU_REFUS_VERSION` avec la version `0.11`, le client seul échoue en 4,9 à 5,1 s. Chaque journal finit par `== 0 échec(s) ==` puis le bruit connu (`ObjectDB instances were leaked`, `resources still in use at exit`).

- [ ] **Step 4 : le test est discriminant (mutations temporaires, jamais commitées)**

4a. Neutraliser la vérification de version : dans `Scripts/Reseau.gd`, remplacer `	if demande.version != version:` par `	if false and demande.version != version:`, puis `bash tests/reseau/lancer.sh`.
Expected : `❌ hôte + 2 clients, … : hote1 sort en 1` et `… ancien1 sort en 1` (l'ancien est inscrit : 3 arrivées au lieu de 2), `== 4 échec(s) ==`, code 1 ; les trois autres scénarios restent ✅.

4b. Remettre le fichier : `git checkout Scripts/Reseau.gd`. Puis remettre la déconnexion immédiate du refusé que l'Écart 2 écarte : dans `_repondre`, remplacer

```gdscript
	if reponse.accepte:
		_api().complete_auth(id)
```

par

```gdscript
	if reponse.accepte:
		_api().complete_auth(id)
	else:
		_api().disconnect_peer(id)
```

et relancer `bash tests/reseau/lancer.sh`.
Expected : ❌ dans les scénarios 1, 2 et 3 (`ancien1`, `rival2a` ou `rival2b`, `tard3` sortent en 1, et « il fallait exactement un refus « plein » ») : les refusés écrivent `RESULTAT echec` (l'hôte les a coupés avant que la raison parte) ; `== 7 échec(s) ==` au moment du plan, code 1 ; le scénario 4 reste ✅.

4c. `git checkout Scripts/Reseau.gd` ; `git status --short` n'affiche plus que les deux fichiers de la tâche (`tests/reseau/`).

- [ ] **Step 5 : 5 passages consécutifs, et le ménage en cas d'interruption**

Run : `export PATH="/opt/homebrew/bin:$PATH"; for i in 1 2 3 4 5; do bash tests/reseau/lancer.sh > "$TMPDIR/r$i.log" 2>&1; echo "passage $i : code $? $(tail -1 "$TMPDIR/r$i.log")"; done`
Expected : cinq lignes `passage i : code 0 == 0 échec(s) ==`.

Run : `export PATH="/opt/homebrew/bin:$PATH"; bash tests/reseau/lancer.sh 18777 > "$TMPDIR/int.log" 2>&1 & p=$!; sleep 2; kill -TERM $p; wait $p; echo "code $?"; sleep 1; pgrep -fl "tests/reseau/joueur.gd" | wc -l; rm -rf "${TMPDIR:-/tmp}"/lelion-reseau.*`
Expected : `code 130` puis `0` : plus aucun poste ne tourne. (Un `kill -INT` sur un script lancé en arrière-plan depuis un shell non interactif est ignoré : bash y démarre avec SIGINT ignoré, que `trap` ne peut pas rétablir ; au terminal, Ctrl-C fonctionne, et la CI envoie TERM.)

- [ ] **Step 6 : Commit**

```bash
git add tests/reseau/joueur.gd tests/reseau/joueur.gd.uid tests/reseau/lancer.sh
git commit -m "Test réseau : hôte + clients headless sur localhost (tests/reseau/lancer.sh, un processus par poste sous timeout) ; inscription, version différente, partie pleine, manche en cours, départs, hôte perdu, échec de connexion

<ligne fournie par l'environnement>"
```

Vérifier que le mode exécutable est committé : `git ls-files -s tests/reseau/lancer.sh` commence par `100755`.

---

### Task 3 : spec et feuille de route

**Files:**
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§4, §10)
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (points de vigilance)

**Interfaces:**
- Consumes : Tasks 1 et 2.
- Produces : la spec décrit la poignée de main telle qu'elle est faite ; la feuille de route réaffecte ce que la phase 11 prépare sans le brancher (phases 12, 13, 14).

- [ ] **Step 1 : spec §4 (poignée de main)**

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
- **Poignée de main** : le client envoie version + pseudo. Version différente : refus avec message
  « Version différente de l'hôte (x.y) ». Salon plein ou manche en cours : refus explicite.
```

par :

```markdown
- **Poignée de main** : le client envoie version + pseudo. Version différente : refus avec message
  « Version différente de l'hôte (x.y) ». Salon plein ou manche en cours : refus explicite.
  Elle passe par l'authentification de `SceneMultiplayer` (octets bruts avant tout RPC : deux
  versions différentes se comprennent encore assez pour se refuser). La version est
  `application/config/version`. L'hôte refuse dans l'ordre : demande mal formée (autre programme),
  version différente, manche en cours, partie pleine ; il inscrit l'accepté au moment de répondre
  (deux demandes simultanées ne prennent pas la même place), lui donne le plus petit index libre et
  la première couleur libre de la palette, et coupe son pseudo à 12 caractères. Un refusé ferme
  lui-même la connexion après avoir lu la raison (couper du côté de l'hôte viderait la file d'envoi
  d'ENet, raison comprise) ; un pair muet est coupé au bout de 3 s. Après un refus, un échec ou le
  départ de l'hôte, le poste revient de lui-même hors réseau (`OfflineMultiplayerPeer`) avant de le
  signaler (`Reseau`, phase 11).
```

- [ ] **Step 2 : spec §10 (tests)**

Remplacer :

```markdown
- **Test réseau de bout en bout** (`tests/reseau/lancer.sh` + `tests/reseau/joueur.gd`) : 1 hôte +
  3 clients headless sur localhost, commandes scriptées. Vérifie à la fin : empreinte identique
  des propriétaires de cellules chez tous, scores identiques, même nombre de tampons reçus,
  déconnexion d'un client en cours de manche gérée.
```

par :

```markdown
- **Test réseau** (`tests/reseau/lancer.sh` + `tests/reseau/joueur.gd`) : un processus Godot
  headless par poste, sur localhost (ports 17778 et suivants), chacun sous `timeout`, tous tués en
  sortie ; verdict par les codes de sortie et les journaux. Depuis la phase 11, le transport : hôte
  + 2 clients inscrits, version différente, partie pleine (deux demandes pour la dernière place),
  manche en cours, départ d'un client, départ de l'hôte, échec de connexion. De bout en bout (phase
  15) : 1 hôte + 3 clients, commandes scriptées ; vérifie à la fin l'empreinte identique des
  propriétaires de cellules chez tous, les scores identiques, le même nombre de tampons reçus, la
  déconnexion d'un client en cours de manche.
```

- [ ] **Step 3 : feuille de route, points de vigilance**

3a. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phases 12/13** : le retour au titre remet les règles (`configurer_solo()`, phase 10 ter) mais
  pas le pair multijoueur. Après « hôte perdu → retour au titre » (spec §4/§9), un pair ENet client
  qui traîne ou vient de se fermer laisse `multiplayer.is_server()` à faux, et le solo relancé depuis
  ce titre casse silencieusement (ennemis qui ne touchent jamais, pastilles ignorées, gerbe et chocs
  non signalés) : chaque chemin de retour au titre doit restaurer
  `multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()`, dans `Titre._ready` à côté de
  `configurer_solo()` ou dans `Reseau.quitter()`, avec une vérification que le solo fonctionne après
  la fermeture d'un pair client ;
```

par :

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
- **phase 13** (salon) : l'hôte tient `Reseau.inscrits` (id réseau → index, couleur, pseudo) et
  ses signaux `joueur_arrive` / `joueur_parti` ; le salon les synchronise chez les clients (`Reseau`
  est dans ses fichiers), change les couleurs parmi les libres (`Reseau.premiere_couleur_libre`,
  l'hôte arbitre), pose `Reseau.manche_en_cours = true` au lancement (et `false` au retour au salon,
  phase 18), puis reporte la table dans la partie : `id_reseau`, pseudo et couleur de chaque joueur
  par index (phase 11 bis : `Joueur.id_reseau`, `configurer_bataille(n, couleurs)`). Ajouter ses
  scénarios à `tests/reseau/joueur.gd` et `lancer.sh` ;
- **phase 14** : un client qui part en cours de manche arrive chez l'hôte par
  `Reseau.joueur_parti(id)` (id réseau, à retrouver par `Joueur.id_reseau`) ; un hôte perdu, chez
  chaque client, par `Reseau.hote_perdu` (le poste est alors déjà hors réseau) ;
```

3b. Remplacer :

```markdown
- **phase 13** (salon) : le pseudo choisi au salon peut être plus large que le sprite du lion
  (l'étiquette de bataille est centrée, `offset_left -42 … offset_right 178`, sur un lion borné à
  `x ∈ [0, 2000 - sprite_w]`) ; au-delà d'une douzaine de caractères à 26 px, elle est coupée par le
  bord de l'écran : plafonner la longueur du pseudo au salon, ou clamper l'abscisse de l'étiquette
  dans l'écran ;
```

par :

```markdown
- **phase 13** (salon) : le pseudo choisi au salon peut être plus large que le sprite du lion
  (l'étiquette de bataille est centrée, `offset_left -42 … offset_right 178`, sur un lion borné à
  `x ∈ [0, 2000 - sprite_w]`) ; au-delà d'une douzaine de caractères à 26 px, elle est coupée par le
  bord de l'écran. L'hôte coupe déjà tout pseudo à `Reseau.PSEUDO_MAX` (12 caractères, phase 11) :
  borner aussi le champ de saisie à `Reseau.PSEUDO_MAX`, et vérifier sur capture qu'un pseudo de 12
  caractères larges (« MMMMMMMMMMMM ») tient dans l'écran à chaque bord, sinon clamper l'abscisse de
  l'étiquette ;
```

Run : `grep -nE "^- (\*\*)?phases? 12/13" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md; grep -c "Reseau.quitter()" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
Expected : aucune ligne pour le premier grep (le point des phases 12/13 est réaffecté), au moins `2` pour le second.

Les trois points « phase 11 » (joueur local par `id_reseau`, réabonnement d'`Audio`, `configurer_solo`) et la palette restent : ils sont à la phase 11 bis, qui les résout.

- [ ] **Step 4 : Commit**

```bash
git add docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
git commit -m "Spec et feuille de route : poignée de main telle que faite (authentification de SceneMultiplayer, ordre des refus, retour hors réseau), test réseau par processus ; retour au titre, textes des refus, salon et départs réaffectés aux phases 12 à 14

<ligne fournie par l'environnement>"
```

---

## Sortie de phase

- Les quatre suites vertes 5 fois de suite localement (unitaires, smoke, bataille, `bash tests/reseau/lancer.sh`), sans `SCRIPT ERROR` ni `SHADER ERROR` ; en CI sur la PR, les trois suites Godot (le test réseau y entre en phase 11 bis).
- Sortie de la feuille de route : **hôte + 2 clients se connectent, version refusée** = scénario 1 du test réseau (Task 2, Step 3), à montrer à l'utilisateur.
- `git diff main --stat` : 5 fichiers de code et de test (`Scripts/Reseau.gd`, `project.godot`, `tests/unitaires.gd`, `tests/reseau/lancer.sh`, `tests/reseau/joueur.gd`), plus les deux `.uid`, la spec et la feuille de route.
- `grep -nE "class_name|GameState" Scripts/Reseau.gd` : aucune ligne ; `grep -n "get_node" Scripts/Reseau.gd` : la seule ligne 19 de la docstring (le transport ne connaît pas la partie).
- Rappeler à l'utilisateur : rien de visible en jeu (l'écran Réseau est la phase 12, le salon la 13) ; la phase 11 bis suit (joueur local par identifiant réseau, retour au solo, `Audio`, palette réglée pour la deutéranopie, test réseau en CI), après sa validation.
