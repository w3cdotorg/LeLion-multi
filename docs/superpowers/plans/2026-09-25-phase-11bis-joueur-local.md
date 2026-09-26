# Phase 11 bis : réseau (2/2), le joueur local par identifiant réseau, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** chaque `Joueur` porte l'identifiant réseau de son poste (`id_reseau`) et `GameState.joueur_local()` choisit celui dont l'identifiant est `multiplayer.get_unique_id()` (1 chez l'hôte et hors réseau), au lieu de `joueurs[0]` ; un changement de joueur local est annoncé (`joueur_local_change`) et `Audio`, abonné pour toute la session, le suit ; le retour au solo garde le joueur de ce poste (pas celui de l'hôte), en tête, avec l'index 0, même quand le pair réseau est déjà fermé ; `configurer_bataille(n, couleurs)` accepte les couleurs du salon ; la palette de bataille est réglée pour la deutéranopie (écart minimal entre couleurs simulées de 0,115 à 0,186) ; le test réseau de la phase 11 tourne en CI. Sortie : **tests verts, CI verte, ◉ planche de la palette**. **Le solo reste strictement identique.**

**Architecture:** `Joueur.id_reseau` (défaut `Joueur.SANS_PAIR` = 0, aucun poste) ; `GameState._init` donne au joueur du solo l'identifiant de l'hôte (`MultiplayerPeer.TARGET_PEER_SERVER` = 1 : hors réseau, `OfflineMultiplayerPeer` répond 1). `joueur_local()` parcourt les joueurs et compare à `_id_reseau_local()` (1 hors de l'arbre, sans pair ou avec un pair fermé), `joueurs[0]` à défaut. `GameState` retient le dernier joueur local annoncé (`_dernier_joueur_local`) et l'annonce à nouveau s'il a changé, dans `nouvelle_partie`, `configurer_bataille` et `configurer_solo` ; `configurer_solo` s'appuie sur lui (et non sur le pair, déjà remis hors ligne par `Reseau` après « hôte perdu ») pour échanger en place le joueur de ce poste avec `joueurs[0]`. `Audio` s'abonne au joueur local de départ puis à `joueur_local_change`. La palette est une constante de `GameState`, vérifiée par un test unitaire (OKLab, simulation de Machado) et une planche rendue.

**Tech Stack:** Godot 4.7.2, GDScript typé, tests headless (`tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd` avec `--fixed-fps 60`, `tests/reseau/lancer.sh`), planche de contrôle rendue en `opengl3` (script jetable du scratchpad) et Python 3 + Pillow, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§2 palette, §3 un seul chemin d'autorité, §3.1 `Joueur.id_reseau`, §11 CI) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 11 bis ; points de vigilance « phase 11 », palette, `configurer_bataille`) · plan de la phase 11 (découpage, `Reseau`) : `docs/superpowers/plans/2026-09-25-phase-11-reseau.md` · planche de la phase 7 (méthode de la simulation deutéranopie) : `docs/superpowers/plans/2026-09-25-phase-07-teinte.md`, Task 3 · prérequis : phase 11 fusionnée (`Reseau`, `tests/reseau/lancer.sh`, `project.godot` en version 0.11) ; nouvelle branche `phase-11bis-joueur-local` depuis `main`.

## Écarts assumés

1. **Un joueur sans poste a l'identifiant 0** (`Joueur.SANS_PAIR` : ENet ne donne jamais 0) ; seul le joueur du solo porte 1. Les joueurs ajoutés par `configurer_bataille` (bataille locale pilotée par les tests) restent à 0 : le joueur local de la bataille locale reste `joueurs[0]`, comme avant. C'est le salon (phase 13) qui posera les vrais identifiants.
2. **`joueur_local()` retombe sur `joueurs[0]` quand aucun joueur ne porte l'identifiant du poste** (client dont le salon n'a pas encore posé les identifiants) ; un pair fermé ou absent compte comme l'hôte (1) : un pair ENet fermé n'a plus d'identifiant (`get_unique_id` y lève une erreur), et `Reseau` le remplace de toute façon aussitôt par un pair hors ligne.
3. **`configurer_solo` ne résout pas le joueur local par le pair** : au retour au titre après « hôte perdu », `Reseau` a déjà remis `OfflineMultiplayerPeer` (identifiant 1), et la résolution par le pair désignerait le joueur de l'hôte chez un client (pseudo et identifiant d'un autre), exactement le défaut du point de vigilance. Il garde le **dernier joueur local annoncé**, qui l'a été au plus tard par la `nouvelle_partie` de la manche. Mesuré en préparant le plan : avec `var local := joueur_local()`, les trois vérifications du retour au solo échouent.
4. **Les entrées de `GameState.joueurs` peuvent s'échanger** (le joueur de ce poste passe en case 0) : le tableau reste le même objet, aucun `Joueur` n'est recréé, et le seul abonné de toute la session (`Audio`) suit `joueur_local_change`. Les scènes (Lion, HUD, Main, Spawner, GameOver) s'abonnent au joueur local dans leur `_ready`, une partie à la fois : rien à changer chez elles.
5. **`configurer_bataille(n, couleurs)` est l'interface du salon, livrée avant lui** (point de vigilance de la phase 13) ; le reste du point (l'`assert` sur le nombre de joueurs changé en clamp ou `push_error`) attend son premier appelant hors des tests : réaffecté à la phase 13 par la Task 4.
6. **La palette** : cible numérique (écart OKLab minimal entre deux couleurs simulées en deutéranopie, Machado 2009, au moins 0,18 ; entre couleurs normales au moins 0,2 ; clarté OKLab d'au moins 0,5), trouvée par une recherche aléatoire contrainte à rester à 0,06 près de chaque teinte de la planche de la phase 7, puis arrondie au centième. Mesures au moment du plan : 0,115 → 0,186 (simulées), 0,201 → 0,213 (normales), clarté minimale 0,549. Sur la planche rendue, les nuances de gerbe se séparent nettement mieux ; **sur la crinière** (couleur × luminance du sprite), rouge et vert restent pour un deutéranope deux kakis que la clarté seule sépare (le rouge plus sombre), magenta et cyan deux gris bleutés : d'où le pseudo sur l'étiquette et bientôt sur les vignettes du HUD (réaffecté à la phase 17). Le vert devient plus clair, pas plus sombre comme l'exemple de la feuille de route : c'est ce que donne la recherche. **Valider ces valeurs est une décision de l'utilisateur** sur la planche (Task 2, Step 5).
7. **Le test réseau entre en CI ici, pas en phase 15** (phase 11, écart 9) : `.github/workflows/ci.yml` est le 5ᵉ fichier de la phase.
8. **Pas de nettoyage préalable (« Step 0 »)** : `tests/unitaires.gd` (environ 850 lignes après la phase 11) ne reçoit que des fonctions à la fin et deux appels ; `GameState.gd`, `Joueur.gd` et `Audio.gd` font moins de 300 lignes. Lire `tests/unitaires.gd` par morceaux (`offset` / `limit`).

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations.
- Fichiers de la phase (5) : ✏️ `Scripts/Joueur.gd`, ✏️ `Scripts/GameState.gd`, ✏️ `Scripts/Audio.gd`, ✏️ `tests/unitaires.gd`, ✏️ `.github/workflows/ci.yml`. Aucun nouveau script. La spec et la feuille de route ne comptent pas ; les scripts de la planche vivent dans le scratchpad de l'exécutant et **ne sont pas commités**.
- Solo strictement identique : hors réseau, `joueur_local()` est toujours `joueurs[0]` (identifiant 1 = celui du pair hors ligne) ; `Audio` joue le même son de pastille ; la palette ne sert qu'en bataille. Le smoke test n'est pas modifié et reste vert.
- `GameState.joueurs` : jamais réassigné, rempli ou réduit en place ; les entrées peuvent s'échanger (Écart 4), aucun `Joueur` n'est recréé pour le même poste.
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : `tests/unitaires.gd` récupère `GameState`, `Audio` et `Reseau` par `root.get_node(…)` et ne les nomme pas ; il peut nommer `EtatPartie`, `Joueur`, `SceneMultiplayer`, `ENetMultiplayerPeer`, `MultiplayerPeer`.
- **Toujours lancer un test Godot avec `timeout`** et chercher les erreurs dans la sortie :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/unitaires.gd; O=""; timeout 300 godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/smoke_test.gd; O=""` ou `T=tests/bataille_test.gd; O="--fixed-fps 60"` pour les deux autres suites ; le test réseau : `bash tests/reseau/lancer.sh`, qui borne lui-même chacun de ses processus). Une `SCRIPT ERROR` ne change pas le code de sortie et une erreur avant `quit()` bloque le processus jusqu'au `timeout` (code 124). Bruit connu : « resources still in use at exit », et dans les tests unitaires `ERROR: Couldn't create an ENet host.` (test du port occupé, phase 11) et deux `ERROR: Territoire.tamponner : index de joueur hors plage`.
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`**.
- Les quatre suites se valident sur **5 passages consécutifs verts**.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Un client qui revient au titre avec le `Joueur` d'un autre** (pseudo et identifiant de l'hôte, index ≠ 0), en particulier quand le pair est déjà fermé et remis hors ligne (« hôte perdu ») au moment de `configurer_solo`. → « retour au solo : le joueur de ce poste pendant la partie passe en tête, dans le même tableau », « … avec l'index 0, l'identifiant de l'hôte, sans couleur, son pseudo gardé » (Task 1).
2. **`Audio` resté abonné à l'ancien joueur local** (son de pastille muet chez un client) ou abonné deux fois (son doublé). → « une nouvelle partie annonce le nouveau joueur local : Audio le suit et lâche l'ancien », « le joueur local n'est annoncé qu'à son changement », « Audio écoute toujours ce joueur » (Task 1).
3. **Un pair fermé ou absent** : `joueur_local()` qui lève une erreur ou garde l'identifiant d'un client disparu ; un état de partie hors de l'arbre (tests) sans `multiplayer`. → « pair fermé : plus d'identifiant de client, le joueur local redevient celui de l'hôte (1) », « un état de partie hors de l'arbre a pour joueur local son premier joueur » (Task 1).
4. **La bataille locale déréglée par les identifiants** (tous à 1, ou le joueur local qui n'est plus `joueurs[0]`), ou des couleurs du salon écrasées par la palette. → « bataille locale : le joueur local reste le premier, les autres n'appartiennent à aucun poste », « configurer_bataille garde les couleurs qu'on lui donne (celles du salon), par index » (Task 1) ; `tests/bataille_test.gd` 5 fois vert.
5. **Deux couleurs de la palette confondues** par un joueur deutéranope, ou trop sombres sur le haut du ciel (bleu nuit). → « en deutéranopie simulée aussi (écart OKLab minimal …, au moins 0,18 …) », « chaque couleur reste claire (OKLab L >= 0,5) … » (Task 2) et la planche regardée (Task 2, Step 5).

---

### Task 0 : vérification des plans

Ce plan a été commité par le commit de planification de la phase 11 : ne pas le recommiter, **ne jamais le modifier** (ni réécriture, ni résumé). Pas d'autre étape.

---

### Task 1 : le joueur local par identifiant réseau, le retour au solo, `Audio` qui suit

**Files:**
- Modify: `Scripts/Joueur.gd` (docstring du fichier, constante, variable)
- Modify: `Scripts/GameState.gd` (signal, commentaire de `joueurs`, variable, `_init`, `joueur_local`, `configurer_solo`, `configurer_bataille`, `nouvelle_partie`, deux fonctions)
- Modify: `Scripts/Audio.gd` (variable, `_ready`, deux fonctions)
- Test: `tests/unitaires.gd` (`_run`, une fonction à la fin)

**Interfaces:**
- Consumes : `GameState.joueurs`, `joueur_local()`, `configurer_solo()`, `configurer_bataille(n)`, `nouvelle_partie()` (phases 8 à 10 ter) ; `MultiplayerPeer.TARGET_PEER_SERVER` (1) ; la technique du smoke test pour donner un pair client à un sous-arbre (`SceneTree.set_multiplayer(api, chemin)`, puis `set_multiplayer(null, chemin)`).
- Produces :
  - `const Joueur.SANS_PAIR := 0`, `@export var Joueur.id_reseau := SANS_PAIR` ;
  - `signal GameState.joueur_local_change(joueur: Joueur)` ; `GameState.joueur_local() -> Joueur` par identifiant ; `GameState.configurer_bataille(nb_joueurs: int, couleurs: Array[Color] = [])` ; `configurer_solo()` garde le dernier joueur local annoncé, en tête ; `nouvelle_partie()`, `configurer_bataille()` et `configurer_solo()` annoncent le joueur local s'il a changé ; privés : `_dernier_joueur_local: Joueur`, `_id_reseau_local() -> int`, `_annoncer_joueur_local()` ;
  - `Audio._ecouter(joueur: Joueur)`, `Audio._on_couleur_debloquee(_couleur: Color)` (le test vérifie la connexion de ce second).

- [ ] **Step 1 : le test**

1a. Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_reseau()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_reseau()
	_tester_joueur_local()
	print("== %d échec(s) ==" % _echecs)
```

1b. Ajouter à la fin de `tests/unitaires.gd` :

```gdscript


func _tester_joueur_local() -> void:
	print("-- Joueur local par identifiant réseau")
	var gs: Node = root.get_node("GameState")
	var son_pastille := Callable(root.get_node("Audio"), "_on_couleur_debloquee")
	var tableau: Array[Joueur] = gs.joueurs
	var solo: Joueur = gs.joueurs[0]
	_check(solo.id_reseau == MultiplayerPeer.TARGET_PEER_SERVER and gs.joueur_local() == solo and root.multiplayer.get_unique_id() == 1,
		"hors réseau, le joueur du solo porte l'identifiant de l'hôte (1), celui de ce poste : c'est le joueur local")
	_check(Joueur.new().id_reseau == Joueur.SANS_PAIR, "un nouveau joueur n'appartient à aucun poste")
	_check(solo.couleur_debloquee.is_connected(son_pastille), "Audio joue le son de pastille du joueur local")
	var hors_arbre := EtatPartie.new()
	_check(hors_arbre.joueur_local() == hors_arbre.joueurs[0], "un état de partie hors de l'arbre a pour joueur local son premier joueur")
	hors_arbre.free()

	# Bataille locale : les couleurs viennent de la palette, ou de l'appelant (le salon, phase 13)
	gs.configurer_bataille(3)
	_check(gs.joueur_local() == solo and gs.joueurs.slice(1).all(func(j: Joueur) -> bool: return j.id_reseau == Joueur.SANS_PAIR),
		"bataille locale : le joueur local reste le premier, les autres n'appartiennent à aucun poste")
	var choisies: Array[Color] = [EtatPartie.PALETTE_BATAILLE[4], EtatPartie.PALETTE_BATAILLE[0], EtatPartie.PALETTE_BATAILLE[2]]
	gs.configurer_bataille(3, choisies)
	_check(gs.joueurs.map(func(j: Joueur) -> Color: return j.couleur) == choisies
		and gs.joueurs.map(func(j: Joueur) -> int: return j.index) == [0, 1, 2],
		"configurer_bataille garde les couleurs qu'on lui donne (celles du salon), par index")

	# Un client : le sous-arbre de GameState reçoit un pair client ENet jamais connecté, dont
	# l'identifiant est tiré à sa création.
	var api := SceneMultiplayer.new()
	var pair := ENetMultiplayerPeer.new()
	_check(pair.create_client("127.0.0.1", 17791) == OK, "un pair client est créé")
	api.multiplayer_peer = pair
	set_multiplayer(api, gs.get_path())
	var client: Joueur = gs.joueurs[2]
	client.id_reseau = pair.get_unique_id()
	client.pseudo = "Client"
	var annonces: Array[Joueur] = []
	var sur_annonce := func(j: Joueur) -> void: annonces.append(j)
	gs.joueur_local_change.connect(sur_annonce)
	_check(client.id_reseau > 1 and gs.joueur_local() == client,
		"sur un client, le joueur local est celui qui porte l'identifiant du poste (%d), pas le premier" % client.id_reseau)
	gs.nouvelle_partie()
	_check(annonces == [client] and client.couleur_debloquee.is_connected(son_pastille) and not solo.couleur_debloquee.is_connected(son_pastille),
		"une nouvelle partie annonce le nouveau joueur local : Audio le suit et lâche l'ancien")
	gs.nouvelle_partie()
	_check(annonces.size() == 1, "le joueur local n'est annoncé qu'à son changement")

	# Hôte perdu : le pair se ferme et le poste revient hors réseau AVANT le retour au titre
	pair.close()
	_check(gs.joueur_local() == solo, "pair fermé : plus d'identifiant de client, le joueur local redevient celui de l'hôte (1)")
	set_multiplayer(null, gs.get_path())
	gs.partie_en_cours = false
	gs.pret = false
	gs.configurer_solo()
	_check(gs.joueurs.size() == 1 and gs.joueurs[0] == client and is_same(tableau, gs.joueurs),
		"retour au solo : le joueur de ce poste pendant la partie passe en tête, dans le même tableau (%s)" % gs.joueurs[0].pseudo)
	_check(client.index == 0 and client.id_reseau == MultiplayerPeer.TARGET_PEER_SERVER and not client.a_une_couleur()
		and client.pseudo == "Client" and gs.joueur_local() == client,
		"… avec l'index 0, l'identifiant de l'hôte, sans couleur, son pseudo gardé : c'est le joueur local hors réseau")
	_check(annonces == [client] and client.couleur_debloquee.is_connected(son_pastille),
		"Audio écoute toujours ce joueur (aucune annonce de plus : il n'a pas changé)")
	gs.joueur_local_change.disconnect(sur_annonce)
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false
```

- [ ] **Step 2 : lancer le test, constater l'échec**

Run : `export PATH="/opt/homebrew/bin:$PATH"; timeout 60 godot --headless --script tests/unitaires.gd > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/t.log"`
Expected : `code 124` (le script ne compile pas, le processus attend le `timeout`) et `SCRIPT ERROR: Parse Error: Cannot find member "SANS_PAIR" in base "Joueur".` (deux fois).

- [ ] **Step 3 : `Joueur.id_reseau`**

3a. Dans `Scripts/Joueur.gd`, remplacer :

```gdscript
## État d'un lion : identité (index, pseudo, couleur) et, pendant une partie, couleurs
```

par :

```gdscript
## État d'un lion : identité (poste, index, pseudo, couleur) et, pendant une partie, couleurs
```

3b. Remplacer :

```gdscript
## Écart des nuances foncée et claire autour de la couleur du joueur (voir `nuances`).
const ECART_NUANCES := 0.35

@export var index := 0
```

par :

```gdscript
## Écart des nuances foncée et claire autour de la couleur du joueur (voir `nuances`).
const ECART_NUANCES := 0.35
## `id_reseau` d'un joueur qu'aucun poste ne joue (les lions pilotés d'une bataille locale).
const SANS_PAIR := 0

## Identifiant réseau du poste qui joue ce lion (`multiplayer.get_unique_id()` de ce poste), par
## lequel `GameState.joueur_local()` reconnaît le joueur de ce poste. Le joueur du solo porte
## celui de l'hôte (1) : hors réseau, ce poste est son propre hôte.
@export var id_reseau := SANS_PAIR
@export var index := 0
```

- [ ] **Step 4 : `GameState` choisit le joueur local par identifiant et l'annonce**

4a. Dans `Scripts/GameState.gd`, remplacer :

```gdscript
signal partie_prete()
```

par :

```gdscript
signal partie_prete()
## Le joueur de ce poste a changé (client réseau dont le salon a attribué les identifiants, retour
## au solo) : ceux qui l'écoutent pour toute la session (`Audio`) s'y réabonnent.
signal joueur_local_change(joueur: Joueur)
```

4b. Remplacer :

```gdscript
## Le tableau doit être rempli ou réinitialisé en place (append, resize, etc.) et jamais
## réassigné : `Audio` s'abonne une fois pour toute la session au joueur local (`joueurs[0]`),
## une réassignation rendrait son son de pastille muet sans erreur (voir la phase 11 de la
## feuille de route).
var joueurs: Array[Joueur] = [Joueur.new()]
```

par :

```gdscript
## Le tableau est rempli ou réinitialisé en place (append, resize, échange de cases) et jamais
## réassigné, et un `Joueur` n'est jamais remplacé par un autre objet pour le même poste : les
## scènes s'abonnent au joueur local dans leur `_ready`, `Audio` pour toute la session (il suit
## `joueur_local_change`).
var joueurs: Array[Joueur] = [Joueur.new()]
```

4c. Remplacer tout le bloc qui va de `var temps_arcade` à la fin de `configurer_bataille` :

```gdscript
var temps_arcade := 0.0  # somme des temps des stages gagnés


func _init() -> void:
	regles = ReglesSolo.new(self)


## Le joueur de ce poste. En solo, le seul joueur.
func joueur_local() -> Joueur:
	return joueurs[0]


## Prépare une partie solo : règles du solo, un seul joueur, sans couleur (son lion garde son
## rendu d'origine). Comme `configurer_bataille`, à appeler AVANT de charger la scène de jeu :
## `Main._enter_tree` appelle `nouvelle_partie()`, puis Lion, Spawner, HUD et Main s'abonnent à
## `joueur_local()` dans leur `_ready`. L'écran titre l'appelle (toute partie qu'il lance est
## une partie solo).
func configurer_solo() -> void:
	regles = ReglesSolo.new(self)
	joueurs.resize(1)  # en place : joueurs[0] reste le même objet
	joueur_local().couleur = Color.TRANSPARENT


## Prépare une bataille à `nb_joueurs` (2 à NB_JOUEURS_MAX) : règles de bataille, joueurs
## ajoutés ou retirés en place, index et couleur de la palette. Les pseudos ne changent pas.
func configurer_bataille(nb_joueurs: int) -> void:
	assert(nb_joueurs >= 2 and nb_joueurs <= NB_JOUEURS_MAX, "une bataille se joue de 2 à %d" % NB_JOUEURS_MAX)
	regles = ReglesBataille.new(self)
	var nb_avant := joueurs.size()
	joueurs.resize(nb_joueurs)
	for i in range(nb_joueurs):
		if i >= nb_avant:
			joueurs[i] = Joueur.new()
		joueurs[i].index = i
		joueurs[i].couleur = PALETTE_BATAILLE[i]
```

par :

```gdscript
var temps_arcade := 0.0  # somme des temps des stages gagnés
## Le dernier joueur local annoncé par `joueur_local_change` : le joueur de ce poste pendant la
## dernière partie, que `configurer_solo` garde même si le pair réseau est déjà fermé.
var _dernier_joueur_local: Joueur


func _init() -> void:
	regles = ReglesSolo.new(self)
	joueurs[0].id_reseau = MultiplayerPeer.TARGET_PEER_SERVER  # le solo : ce poste est son propre hôte
	_dernier_joueur_local = joueurs[0]


## Le joueur de ce poste : celui dont `id_reseau` est l'identifiant réseau du poste
## (`multiplayer.get_unique_id()` : 1 chez l'hôte et hors réseau). À défaut (client dont les
## identifiants ne sont pas encore attribués), le premier joueur.
func joueur_local() -> Joueur:
	var id := _id_reseau_local()
	for j in joueurs:
		if j.id_reseau == id:
			return j
	return joueurs[0]


## Prépare une partie solo : règles du solo, un seul joueur, sans couleur (son lion garde son
## rendu d'origine). Ce joueur est celui de ce poste pendant la dernière partie (sur un client, pas
## forcément `joueurs[0]`), même si le réseau est déjà fermé (hôte perdu) : il passe en tête, avec
## l'index 0 et l'identifiant de l'hôte. Comme `configurer_bataille`, à appeler AVANT de charger la
## scène de jeu : `Main._enter_tree` appelle `nouvelle_partie()`, puis Lion, Spawner, HUD et Main
## s'abonnent à `joueur_local()` dans leur `_ready`. L'écran titre l'appelle (toute partie qu'il
## lance est une partie solo).
func configurer_solo() -> void:
	regles = ReglesSolo.new(self)
	var local := _dernier_joueur_local if joueurs.has(_dernier_joueur_local) else joueur_local()
	var k := joueurs.find(local)
	joueurs[k] = joueurs[0]  # échange en place : le tableau reste le même objet
	joueurs[0] = local
	joueurs.resize(1)
	local.index = 0
	local.id_reseau = MultiplayerPeer.TARGET_PEER_SERVER
	local.couleur = Color.TRANSPARENT
	_annoncer_joueur_local()


## Prépare une bataille à `nb_joueurs` (2 à NB_JOUEURS_MAX) : règles de bataille, joueurs
## ajoutés ou retirés en place, index, et couleur : celle de `couleurs` à cet index si elle est
## donnée (les choix du salon, phase 13), sinon celle de la palette. Pseudos et identifiants
## réseau ne changent pas ; un joueur ajouté n'appartient à aucun poste (`Joueur.SANS_PAIR`).
func configurer_bataille(nb_joueurs: int, couleurs: Array[Color] = []) -> void:
	assert(nb_joueurs >= 2 and nb_joueurs <= NB_JOUEURS_MAX, "une bataille se joue de 2 à %d" % NB_JOUEURS_MAX)
	regles = ReglesBataille.new(self)
	var nb_avant := joueurs.size()
	joueurs.resize(nb_joueurs)
	for i in range(nb_joueurs):
		if i >= nb_avant:
			joueurs[i] = Joueur.new()
		joueurs[i].index = i
		joueurs[i].couleur = couleurs[i] if i < couleurs.size() else PALETTE_BATAILLE[i]
	_annoncer_joueur_local()
```

4d. Remplacer :

```gdscript
	pret = false
	partie_en_cours = true
```

par :

```gdscript
	pret = false
	partie_en_cours = true
	_annoncer_joueur_local()


## L'identifiant réseau de ce poste ; 1 (l'hôte, le solo) hors de l'arbre, sans pair, ou quand le
## pair est fermé (un pair ENet fermé n'a plus d'identifiant).
func _id_reseau_local() -> int:
	if not is_inside_tree():
		return MultiplayerPeer.TARGET_PEER_SERVER
	var pair := multiplayer.multiplayer_peer
	if pair == null or pair.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return MultiplayerPeer.TARGET_PEER_SERVER
	return multiplayer.get_unique_id()


## Émet `joueur_local_change` si le joueur local n'est plus celui de la dernière annonce.
func _annoncer_joueur_local() -> void:
	var local := joueur_local()
	if local == _dernier_joueur_local:
		return
	_dernier_joueur_local = local
	joueur_local_change.emit(local)
```

(Ce bloc de deux lignes n'apparaît qu'une fois, à la fin de `nouvelle_partie`.)

- [ ] **Step 5 : `Audio` suit le joueur local**

5a. Dans `Scripts/Audio.gd`, remplacer :

```gdscript
var intensite := -1
var _fondus: Array = [null, null, null]
```

par :

```gdscript
var intensite := -1
var _fondus: Array = [null, null, null]
## Le joueur local, dont chaque couleur débloquée joue le son de pastille. Suivi pour toute la
## session : il change sur un client réseau et au retour au solo (`GameState.joueur_local_change`).
var _joueur_ecoute: Joueur
```

5b. Remplacer :

```gdscript
	# Son de pastille : le joueur local vient de débloquer une couleur. Le Joueur vit aussi
	# longtemps que GameState, l'abonnement est pris une fois pour toute la session.
	GameState.joueur_local().couleur_debloquee.connect(func(_c: Color) -> void: jouer("pickup"))
	GameState.partie_terminee.connect(_on_partie_terminee)
```

par :

```gdscript
	_ecouter(GameState.joueur_local())
	GameState.joueur_local_change.connect(_ecouter)
	GameState.partie_terminee.connect(_on_partie_terminee)
```

5c. Remplacer :

```gdscript
func _on_partie_terminee(victoire: bool) -> void:
```

par :

```gdscript
## Écoute le joueur local `joueur` à la place du précédent.
func _ecouter(joueur: Joueur) -> void:
	if _joueur_ecoute != null:
		_joueur_ecoute.couleur_debloquee.disconnect(_on_couleur_debloquee)
	_joueur_ecoute = joueur
	joueur.couleur_debloquee.connect(_on_couleur_debloquee)


## Son de pastille : le joueur local vient de débloquer une couleur.
func _on_couleur_debloquee(_couleur: Color) -> void:
	jouer("pickup")


func _on_partie_terminee(victoire: bool) -> void:
```

- [ ] **Step 6 : relancer le test**

Run : `export PATH="/opt/homebrew/bin:$PATH"; timeout 300 godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"; timeout 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"; sed -n '/-- Joueur local/,/== /p' "$TMPDIR/t.log"`
Expected : `code 0`, `== 0 échec(s) ==`, et 14 lignes ✅ dans la section, de « hors réseau, le joueur du solo porte l'identifiant de l'hôte (1)… » à « Audio écoute toujours ce joueur (aucune annonce de plus : il n'a pas changé) », dont « sur un client, le joueur local est celui qui porte l'identifiant du poste (<un entier > 1>), pas le premier ».

Vérifier que le test du retour au solo est discriminant (mutation temporaire, jamais commitée) : dans `configurer_solo`, remplacer `var local := _dernier_joueur_local if joueurs.has(_dernier_joueur_local) else joueur_local()` par `var local := joueur_local()` et relancer. Expected : `❌ retour au solo : … (…)`, `❌ … avec l'index 0, …`, `❌ Audio écoute toujours ce joueur …`, `== 3 échec(s) ==`. Puis remettre la ligne (`git diff Scripts/GameState.gd` ne montre plus que les changements de cette tâche).

- [ ] **Step 7 : les autres suites, 5 fois**

Run : smoke, bataille (commande des Global Constraints) et `bash tests/reseau/lancer.sh`, 5 fois chacun.
Expected : `code 0` et `== 0 échec(s) ==` à chaque passage, sans `SCRIPT ERROR` ni `SHADER ERROR`. Le smoke test vérifie que le lion du solo porte le joueur local et lit le clavier, et qu'une pastille ramassée lui débloque une couleur ; le test de bataille, que le lion de la scène est celui du joueur local (`joueurs[0]` en bataille locale), et il finit par un `configurer_solo()` : le retour au solo ordinaire.

- [ ] **Step 8 : Commit**

```bash
git add Scripts/Joueur.gd Scripts/GameState.gd Scripts/Audio.gd tests/unitaires.gd
git commit -m "Joueur local par identifiant réseau : Joueur.id_reseau, GameState.joueur_local() selon multiplayer.get_unique_id(), annonce joueur_local_change suivie par Audio, retour au solo avec le joueur de ce poste (même pair déjà fermé), configurer_bataille(n, couleurs)

<ligne fournie par l'environnement>"
```

---

### Task 2 : la palette de bataille réglée pour la deutéranopie (◉ planche)

**Files:**
- Modify: `Scripts/GameState.gd` (commentaire et valeurs de `PALETTE_BATAILLE`)
- Test: `tests/unitaires.gd` (`_run`, trois fonctions à la fin)
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§2, ligne Palette)
- Create (scratchpad, **non commité**) : `$SCRATCH/rendu_palette.gd`, `$SCRATCH/planche_palette.py` (`$SCRATCH` = le dossier scratchpad de l'exécutant)

**Interfaces:**
- Consumes : `EtatPartie.PALETTE_BATAILLE`, `EtatPartie.NB_JOUEURS_MAX`, `Joueur.nuances()`, `Scenes/Lion.tscn` (`joueur`, `commandes`, `anim`), `Color.srgb_to_linear()`.
- Produces : `PALETTE_BATAILLE = [Color(0.81, 0.14, 0.01), Color(0.24, 0.38, 1.00), Color(1.00, 0.91, 0.09), Color(0.19, 0.82, 0.34), Color(0.87, 0.26, 0.73), Color(0.23, 0.92, 1.00)]` (rouge, bleu, jaune, vert, magenta, cyan) ; dans le test : `_tester_palette()`, `_deuteranopie(l: Vector3) -> Vector3`, `_oklab(l: Vector3) -> Vector3` (couleurs en RVB linéaire).

- [ ] **Step 1 : le test**

1a. Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_joueur_local()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_joueur_local()
	_tester_palette()
	print("== %d échec(s) ==" % _echecs)
```

1b. Ajouter à la fin de `tests/unitaires.gd` :

```gdscript


func _tester_palette() -> void:
	print("-- Palette de bataille (deutéranopie)")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	var normales: Array[Vector3] = []
	var deuteranopes: Array[Vector3] = []
	for c in palette:
		var lineaire := c.srgb_to_linear()
		normales.append(_oklab(Vector3(lineaire.r, lineaire.g, lineaire.b)))
		deuteranopes.append(_oklab(_deuteranopie(Vector3(lineaire.r, lineaire.g, lineaire.b))))
	var min_normale := INF
	var min_deuteranope := INF
	for i in range(palette.size()):
		for k in range(i + 1, palette.size()):
			min_normale = minf(min_normale, normales[i].distance_to(normales[k]))
			min_deuteranope = minf(min_deuteranope, deuteranopes[i].distance_to(deuteranopes[k]))
	_check(palette.size() == EtatPartie.NB_JOUEURS_MAX and palette.all(func(c: Color) -> bool: return c.a == 1.0),
		"une couleur opaque par joueur possible")
	_check(normales.all(func(v: Vector3) -> bool: return v.x >= 0.5), "chaque couleur reste claire (OKLab L >= 0,5) : lisible sur le haut du ciel, bleu nuit")
	_check(min_normale >= 0.2, "deux couleurs se distinguent nettement (écart OKLab minimal %.3f, au moins 0,2)" % min_normale)
	_check(min_deuteranope >= 0.18,
		"en deutéranopie simulée aussi (écart OKLab minimal %.3f, au moins 0,18 ; 0,115 pour la planche de la phase 7)" % min_deuteranope)


## Deutéranopie simulée (Machado 2009, sévérité 1), en RVB linéaire.
func _deuteranopie(l: Vector3) -> Vector3:
	return Vector3(
		0.367322 * l.x + 0.860646 * l.y - 0.227968 * l.z,
		0.280085 * l.x + 0.672501 * l.y + 0.047413 * l.z,
		-0.011820 * l.x + 0.042940 * l.y + 0.968881 * l.z).clamp(Vector3.ZERO, Vector3.ONE)


## OKLab (Ottosson 2020) d'une couleur en RVB linéaire : la distance entre deux couleurs y suit
## l'écart perçu.
func _oklab(l: Vector3) -> Vector3:
	var lms := Vector3(
		0.4122214708 * l.x + 0.5363325363 * l.y + 0.0514459929 * l.z,
		0.2119034982 * l.x + 0.6806995451 * l.y + 0.1073969566 * l.z,
		0.0883024619 * l.x + 0.2817188376 * l.y + 0.6299787005 * l.z)
	var r := Vector3(pow(lms.x, 1.0 / 3.0), pow(lms.y, 1.0 / 3.0), pow(lms.z, 1.0 / 3.0))
	return Vector3(
		0.2104542553 * r.x + 0.7936177850 * r.y - 0.0040720468 * r.z,
		1.9779984951 * r.x - 2.4285922050 * r.y + 0.4505937099 * r.z,
		0.0259040371 * r.x + 0.7827717662 * r.y - 0.8086757660 * r.z)
```

- [ ] **Step 2 : lancer le test, constater l'échec**

Run : la commande des Global Constraints sur `tests/unitaires.gd`, puis `sed -n '/-- Palette/,/== /p' "$TMPDIR/t.log"`.
Expected : `❌ en deutéranopie simulée aussi (écart OKLab minimal 0.115, au moins 0,18 ; 0,115 pour la planche de la phase 7)`, `== 1 échec(s) ==` ; les trois autres vérifications de la palette passent déjà (clarté minimale 0,554, écart normal minimal 0.201).

- [ ] **Step 3 : la palette**

Dans `Scripts/GameState.gd`, remplacer :

```gdscript
## Palette de bataille, attribuée par index de joueur (planche de la phase 7). Provisoire : la
## phase 11 en fait l'attribution du salon et règle les luminosités (deutéranopie).
const PALETTE_BATAILLE: Array[Color] = [
	Color(0.90, 0.16, 0.16), Color(0.16, 0.39, 0.95), Color(0.98, 0.82, 0.10),
	Color(0.18, 0.78, 0.25), Color(0.90, 0.20, 0.85), Color(0.10, 0.85, 0.90),
]
```

par :

```gdscript
## Palette de bataille : rouge, bleu, jaune, vert, magenta, cyan. L'hôte attribue la première
## libre à chaque arrivant (`Reseau`), `configurer_bataille` la donne par index hors salon. Réglée
## en phase 11 bis pour la deutéranopie (Machado 2009) : l'écart OKLab minimal entre deux couleurs
## simulées passe de 0,115 (planche de la phase 7 : rouge et vert confondus) à 0,186, sans
## s'éloigner de plus de 0,06 des teintes de la planche, et chacune reste claire (OKLab L >= 0,54).
const PALETTE_BATAILLE: Array[Color] = [
	Color(0.81, 0.14, 0.01), Color(0.24, 0.38, 1.00), Color(1.00, 0.91, 0.09),
	Color(0.19, 0.82, 0.34), Color(0.87, 0.26, 0.73), Color(0.23, 0.92, 1.00),
]
```

- [ ] **Step 4 : relancer les tests**

Run : la commande des Global Constraints sur `tests/unitaires.gd`, puis `sed -n '/-- Palette/,/== /p' "$TMPDIR/t.log"`.
Expected : `code 0`, `== 0 échec(s) ==`, et dans la section : « deux couleurs se distinguent nettement (écart OKLab minimal 0.213, au moins 0,2) », « en deutéranopie simulée aussi (écart OKLab minimal 0.186, au moins 0,18 ; … ) ».

Puis `tests/bataille_test.gd` (il compare le matériau de chaque lion à `PALETTE_BATAILLE[i]`) et `bash tests/reseau/lancer.sh` (il compare les couleurs attribuées à la palette) : verts.

- [ ] **Step 5 : la planche (◉, rendu réel : une fenêtre s'ouvre)**

5a. Écrire `$SCRATCH/rendu_palette.gd` :

```gdscript
extends SceneTree
## Planche de contrôle de la palette de bataille (phase 11 bis, non commitée) :
## godot --rendering-driver opengl3 --script <ce fichier> -- --dossier=<dossier>
## Colonnes : les 6 couleurs de GameState.PALETTE_BATAILLE, puis le lion du solo (sans couleur).
## Lignes : repos (haut du ciel, bleu nuit), vomi (milieu du ciel), repos (bas du ciel, orangé) ;
## sous chaque lion de bataille, ses trois nuances de gerbe sur la couleur sombre de la skyline.
## Avec --ancienne : la palette de la planche de la phase 7, pour comparer (palette_ancienne.png).

const LIGNES_Y := [40.0, 250.0, 460.0]
const NOMS := ["Rouge", "Bleu", "Jaune", "Vert", "Magenta", "Cyan"]
const ANCIENNE: Array[Color] = [
	Color(0.90, 0.16, 0.16), Color(0.16, 0.39, 0.95), Color(0.98, 0.82, 0.10),
	Color(0.18, 0.78, 0.25), Color(0.90, 0.20, 0.85), Color(0.10, 0.85, 0.90),
]
var dossier := "user://"
var ancienne := false


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dossier="):
			dossier = arg.trim_prefix("--dossier=")
		elif arg == "--ancienne":
			ancienne = true
	call_deferred("_run")


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	gs.pret = false  # les lions restent immobiles
	var palette: Array[Color] = ANCIENNE if ancienne else gs.PALETTE_BATAILLE
	# Même ciel que Scenes/Main.tscn, pour juger crinières et pseudos sur ses trois bandes
	var degrade := Gradient.new()
	degrade.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	degrade.colors = PackedColorArray([Color(0.09, 0.1, 0.24), Color(0.42, 0.25, 0.43), Color(0.9, 0.5, 0.32)])
	var texture_ciel := GradientTexture2D.new()
	texture_ciel.gradient = degrade
	texture_ciel.fill_to = Vector2(0, 1)
	var ciel := TextureRect.new()
	ciel.texture = texture_ciel
	ciel.size = Vector2(2000, 648)
	root.add_child(ciel)
	var scene_lion: PackedScene = load("res://Scenes/Lion.tscn")
	for ligne in range(LIGNES_Y.size()):
		for colonne in range(7):
			var j := Joueur.new()
			if colonne < 6:
				j.couleur = palette[colonne]
				j.pseudo = NOMS[colonne]
			var lion: Node = scene_lion.instantiate()
			lion.joueur = j
			lion.commandes = Commandes.manuelles()
			lion.position = Vector2(30 + colonne * 280, LIGNES_Y[ligne])
			root.add_child(lion)
			if ligne == 1:
				lion.anim.play("Vomit")
			if ligne == 2 and colonne < 6:
				# Les trois nuances de la gerbe, sur le noir bleuté de la skyline
				var fond := ColorRect.new()
				fond.color = Color(0.07, 0.07, 0.12)
				fond.position = Vector2(20 + colonne * 280, 598)
				fond.size = Vector2(260, 50)
				root.add_child(fond)
				var n: Array[Color] = j.nuances()
				for k in range(3):
					var pastille := ColorRect.new()
					pastille.color = n[k]
					pastille.position = Vector2(30 + colonne * 280 + k * 82, 606)
					pastille.size = Vector2(76, 34)
					root.add_child(pastille)
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var nom := "palette_ancienne.png" if ancienne else "palette.png"
	image.save_png(dossier.path_join(nom))
	print("📸 ", nom, " ", image.get_size())
	quit(0)
```

5b. Écrire `$SCRATCH/planche_palette.py` :

```python
#!/usr/bin/env python3
"""Agrandit une planche (palette.png par défaut, ou le nom donné) en deux moitiés ×2 et en fait une
version deutéranopie : <nom>_x2_0.png, <nom>_x2_1.png, <nom>_deuteranopie.png."""
import sys
from pathlib import Path
from PIL import Image

dossier = Path(sys.argv[1])
nom = sys.argv[2] if len(sys.argv) > 2 else "palette"
image = Image.open(dossier / f"{nom}.png").convert("RGB")
l, h = image.size
for i, (x0, x1) in enumerate([(0, 1000), (980, 2000)]):
    image.crop((x0, 0, x1, h)).resize(((x1 - x0) * 2, h * 2), Image.NEAREST).save(dossier / f"{nom}_x2_{i}.png")
# Deutéranopie (Machado 2009, sévérité 1), appliquée en RVB linéaire
M = ((0.367322, 0.860646, -0.227968), (0.280085, 0.672501, 0.047413), (-0.011820, 0.042940, 0.968881))
lin = [((v / 255) / 12.92 if v <= 10 else (((v / 255) + 0.055) / 1.055) ** 2.4) for v in range(256)]
def srgb(x):
    x = min(1.0, max(0.0, x))
    return round(255 * (12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055))
px = image.load()
deut = Image.new("RGB", image.size)
dp = deut.load()
for y in range(h):
    for x in range(l):
        r, g, b = (lin[c] for c in px[x, y])
        dp[x, y] = tuple(srgb(m[0] * r + m[1] * g + m[2] * b) for m in M)
deut.save(dossier / f"{nom}_deuteranopie.png")
print("planches écrites dans", dossier)
```

5c. Rendre les deux planches (nouvelle palette, puis celle de la phase 7) :

```sh
export PATH="/opt/homebrew/bin:$PATH"; mkdir -p "$SCRATCH/rendu"
for opt in "" "--ancienne"; do timeout 60 godot --rendering-driver opengl3 --script "$SCRATCH/rendu_palette.gd" -- --dossier="$SCRATCH/rendu" $opt > "$SCRATCH/rendu/rendu.log" 2>&1; grep -E "SCRIPT ERROR|SHADER ERROR|📸" "$SCRATCH/rendu/rendu.log"; done
python3 "$SCRATCH/planche_palette.py" "$SCRATCH/rendu" && python3 "$SCRATCH/planche_palette.py" "$SCRATCH/rendu" palette_ancienne
```

Expected : `📸 palette.png (2000, 648)` puis `📸 palette_ancienne.png (2000, 648)`, aucune erreur ; deux lignes « planches écrites dans … ».

5d. Regarder (outil de lecture d'images) `palette.png`, `palette_deuteranopie.png`, puis les mêmes de `palette_ancienne`, et juger :
1. en vision normale, chaque crinière se lit sans hésitation comme sa couleur, sur les trois bandes du ciel ; chaque pseudo est lisible ; le jaune reste distinct du visage du lion (plus citron qu'avant) ;
2. en deutéranopie simulée, les nuances de gerbe (bandeau du bas) se distinguent d'une colonne à l'autre, mieux qu'avec l'ancienne palette (rouge nettement plus sombre que vert, magenta plus sombre que cyan) ;
3. sur les crinières simulées, rouge et vert restent deux kakis et magenta et cyan deux gris bleutés, séparés surtout par la clarté : c'est la limite connue (Écart 6), pas un échec.
Référence au moment du plan : exactement ce constat. Montrer `palette.png` et `palette_deuteranopie.png` à l'utilisateur : **il valide la palette** (ou demande un autre compromis, par exemple un vert plus clair encore ; un nouveau jeu de valeurs doit repasser `_tester_palette`).

- [ ] **Step 6 : spec §2**

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
| Palette | Rouge, bleu, jaune, vert, magenta, cyan (valeurs à valider sur captures, y compris simulation deutéranopie). |
```

par :

```markdown
| Palette | Rouge `(0.81, 0.14, 0.01)`, bleu `(0.24, 0.38, 1.00)`, jaune `(1.00, 0.91, 0.09)`, vert `(0.19, 0.82, 0.34)`, magenta `(0.87, 0.26, 0.73)`, cyan `(0.23, 0.92, 1.00)` (`GameState.PALETTE_BATAILLE`, phase 11 bis). En deutéranopie simulée (Machado 2009), l'écart OKLab minimal entre deux couleurs est de 0,186 (0,115 avant réglage) ; sur la crinière, rouge et vert, magenta et cyan ne s'y distinguent que par la clarté : le pseudo accompagne toujours la couleur (étiquette du lion, vignettes du HUD). |
```

- [ ] **Step 7 : Commit**

```bash
git add Scripts/GameState.gd tests/unitaires.gd docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md
git commit -m "Palette de bataille réglée pour la deutéranopie (écart OKLab minimal entre couleurs simulées 0,115 → 0,186, vérifié par les tests unitaires, planche regardée)

<ligne fournie par l'environnement>"
```

---

### Task 3 : le test réseau en CI

**Files:**
- Modify: `.github/workflows/ci.yml` (un pas après « Test de la bataille locale »)

**Interfaces:**
- Consumes : `tests/reseau/lancer.sh` (phase 11), le Godot installé par le job dans `/usr/local/bin/godot` (nom par défaut `godot` du lanceur), `timeout` d'Ubuntu.
- Produces : un pas « Test réseau (transport, plusieurs processus sur localhost) » ; les phases 13 à 16 n'y touchent plus : leurs scénarios s'ajoutent à `lancer.sh`.

- [ ] **Step 1 : le pas**

Dans `.github/workflows/ci.yml`, remplacer :

```yaml
          if grep -nE "SCRIPT ERROR|SHADER ERROR" bataille_test.log; then echo "::error::erreur de script dans le test de bataille"; exit 1; fi
```

par :

```yaml
          if grep -nE "SCRIPT ERROR|SHADER ERROR" bataille_test.log; then echo "::error::erreur de script dans le test de bataille"; exit 1; fi

      - name: Test réseau (transport, plusieurs processus sur localhost)
        shell: bash
        run: |
          set -o pipefail
          timeout 300 bash tests/reseau/lancer.sh 2>&1 | tee reseau.log
          if grep -nE "SCRIPT ERROR|SHADER ERROR" reseau.log; then echo "::error::erreur de script dans le test réseau"; exit 1; fi
```

Run : `python3 -c "import yaml; d = yaml.safe_load(open('.github/workflows/ci.yml')); print([s.get('name') for s in d['jobs']['test-et-export']['steps']])"`
Expected : `[None, "Installer Godot et les templates d'export", 'Importer les ressources', 'Tests unitaires', 'Smoke test', 'Test de la bataille locale', 'Test réseau (transport, plusieurs processus sur localhost)', 'Exporter en Web']`.

(`bash tests/reseau/lancer.sh` plutôt que `./tests/reseau/lancer.sh` : ne dépend pas du bit exécutable. Le lanceur sort en 1 sur tout échec ; `pipefail` le transmet à travers `tee`.)

- [ ] **Step 2 : Commit, puis CI**

```bash
git add .github/workflows/ci.yml
git commit -m "CI : le test réseau (hôte et clients headless sur localhost) après le test de bataille

<ligne fournie par l'environnement>"
```

Sur la PR, le job doit passer, pas « Test réseau » compris (une quinzaine de secondes). Si seul ce pas échoue en CI, lire les journaux affichés (`grep -HnE` du lanceur) avant toute retouche ; ne pas élargir les délais (`DELAI_ETAPE`, `DELAI`) sans en avoir trouvé la cause.

---

### Task 4 : feuille de route, points de vigilance de la phase 11

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`

**Interfaces:**
- Consumes : Tasks 1 à 3.
- Produces : les points « phase 11 » résolus disparaissent ; ce qui reste va aux phases 13 et 17.

- [ ] **Step 1 : les points résolus**

1a. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, supprimer (remplacer par rien) :

```markdown
- Phase 11 : `GameState.joueur_local()` renvoie `joueurs[0]` (correct en solo seulement) ; il doit
  choisir le joueur dont `id_reseau` correspond à `multiplayer.get_unique_id()`.
```

1b. Supprimer (remplacer par rien) :

```markdown
- **phase 11** : `Audio` s'abonne une fois pour toute la session au joueur local (`joueurs[0]`) ;
  quand `joueur_local()` choisira le joueur par `id_reseau`, `Audio` (et tout abonnement pris une
  seule fois) devra se réabonner quand le joueur local change (signal dédié, ou abonnement par
  partie depuis `Main`) ;
- **phase 11** : `GameState.configurer_solo()` (retour au titre, phase 10 ter) garde `joueurs[0]`,
  pas `joueur_local()`, et ne remet pas `index` à 0. Une fois `joueur_local()` capable de résoudre
  par `id_reseau` (point ci-dessus), un client dont le joueur local était l'index *k* ≠ 0 reviendrait
  au titre avec le `Joueur` d'un autre (pseudo, `id_reseau`) comme joueur solo : `configurer_solo()`
  doit garder ou déplacer le joueur local en case 0 et réinitialiser son `index` ; le réabonnement
  d'`Audio` (point ci-dessus) doit couvrir ce chemin ;
```

- [ ] **Step 2 : la palette, vers les phases 17 et 13**

Remplacer :

```markdown
- **phase 11** : la palette de bataille (planche de la phase 7 : rouge `(0.90, 0.16, 0.16)`, bleu
  `(0.16, 0.39, 0.95)`, jaune `(0.98, 0.82, 0.10)`, vert `(0.18, 0.78, 0.25)`, magenta
  `(0.90, 0.20, 0.85)`, cyan `(0.10, 0.85, 0.90)`) est depuis la phase 8 la constante unique
  `GameState.PALETTE_BATAILLE`, attribuée par index par `configurer_bataille(n)` ; le salon
  l'attribuera au choix des joueurs. En simulation
  deutéranopie, rouge, vert et jaune se confondent (kaki) et magenta et cyan se rapprochent, et le
  jaune est proche du visage du lion : différencier les luminosités (vert plus sombre, jaune plus
  clair, par exemple) et compter aussi sur le pseudo et les vignettes du HUD. Attribuer la couleur
  **avant** l'ajout du lion à l'arbre, ou rappeler `Lion.appliquer_apparence()` (aperçu du salon en
  phase 13) ;
```

par :

```markdown
- **phase 17** (HUD) : la palette de bataille est réglée pour la deutéranopie depuis la phase 11 bis
  (écart OKLab minimal 0,186 entre couleurs simulées, vérifié par `tests/unitaires.gd`), mais sur la
  crinière (couleur × luminance du sprite) rouge et vert restent deux kakis que seule la clarté
  sépare, magenta et cyan deux gris bleutés : les vignettes du HUD portent le pseudo, pas seulement
  la couleur, comme l'étiquette au-dessus du lion ;
- **phase 13** (aperçu du salon) : attribuer la couleur d'un joueur **avant** l'ajout de son lion à
  l'arbre, ou rappeler `Lion.appliquer_apparence()` quand elle change (voir le point des phases 13
  et 14 sur `apparence_changee`) ;
```

- [ ] **Step 3 : `configurer_bataille`, pour la phase 13**

Remplacer :

```markdown
- **phase 13** : `GameState.configurer_bataille(nb_joueurs)` attribue l'index et la couleur de
  chaque joueur depuis `PALETTE_BATAILLE`, par position ; une fois que le salon attribue les
  couleurs (choix des joueurs), `configurer_bataille` ne doit plus les écraser : lui passer les
  couleurs du salon, par exemple `configurer_bataille(nb_joueurs, couleurs)`. Son `assert` sur le
  nombre de joueurs devra aussi devenir un clamp ou un `push_error` une fois que c'est le salon qui
  l'appelle (un salon mal formé ne doit pas planter la partie) ;
```

par :

```markdown
- **phase 13** : `GameState.configurer_bataille(nb_joueurs, couleurs)` (phase 11 bis) garde les
  couleurs qu'on lui passe, par index (la palette sinon) : le salon lui passe les siennes, après
  avoir posé `id_reseau` et pseudo de chaque joueur depuis `Reseau.inscrits`. `configurer_bataille`
  et `nouvelle_partie` annoncent alors le joueur local (`joueur_local_change`, qu'`Audio` suit), et
  `configurer_solo` garde au retour au titre le dernier joueur local annoncé. Son `assert` sur le
  nombre de joueurs doit devenir un clamp ou un `push_error` (un salon mal formé ne doit pas planter
  la partie) : reporté faute d'appelant hors des tests ;
```

Run : `grep -nE "^- (\*\*)?[Pp]hases? 11" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
Expected : aucune ligne (tous les points de vigilance de la phase 11 sont résolus ou réaffectés).

- [ ] **Step 4 : Commit**

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
git commit -m "Feuille de route : points de vigilance de la phase 11 résolus (joueur local par identifiant, Audio, retour au solo, palette) ; HUD et aperçu du salon pour la palette, configurer_bataille pour la phase 13

<ligne fournie par l'environnement>"
```

---

## Sortie de phase

- Les quatre suites vertes 5 fois de suite localement, sans `SCRIPT ERROR` ni `SHADER ERROR`, puis le job CI vert sur la PR, pas « Test réseau » compris.
- ◉ : `palette.png` et `palette_deuteranopie.png` regardées et montrées à l'utilisateur, qui valide la palette (Task 2, Step 5).
- `git diff main --stat` : 5 fichiers de code, de test et de CI (`Scripts/Joueur.gd`, `Scripts/GameState.gd`, `Scripts/Audio.gd`, `tests/unitaires.gd`, `.github/workflows/ci.yml`), plus la spec et la feuille de route.
- `grep -n "joueurs\[0\]" Scripts/GameState.gd` : seulement `_init` (2 lignes), le repli de `joueur_local()`, la docstring et l'échange de `configurer_solo` (2 lignes) ; `grep -n "joueur_local()" Scripts/Audio.gd` : une seule ligne, dans `_ready`.
- Rappeler à l'utilisateur : toujours rien de visible en jeu ; l'écran Réseau (phase 12) branche `Reseau.quitter()` dans le titre et les textes des refus ; le salon (phase 13) pose les `id_reseau` et passe ses couleurs à `configurer_bataille`.
