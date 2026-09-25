# Phase 10 bis : bataille locale (2/3), la scène de bataille en 16:9, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Scenes/Main.tscn` joue une bataille locale à N lions (2 à 6) en 16:9 : l'écran suit les règles du mode, le ciel et la caméra en découlent, un lion par joueur (joueur et commandes fixés avant l'ajout à l'arbre), répartis en haut du ciel ; les apparitions passent par les règles et suivent la hauteur de l'écran ; le peintre garde sa taille du solo et accélère avec le temps de la manche ; une bataille terminée se fige sans le bilan du solo. Un nouveau test, `tests/bataille_test.gd`, charge la scène à 4 lions dans un seul processus, la vérifie, joue une manche de 90 s pilotée et en affiche les mesures ; il tourne en CI. **Le solo reste strictement identique** (smoke test inchangé et vert, écran 2000×648).

**Architecture:** `Main._enter_tree` applique `GameState.regles.taille_ecran()` à `get_tree().root.content_scale_size` avant les `_ready` des enfants (le peintre, le Spawner et les bornes des lions lisent l'écran) ; `Main._ready` règle le ciel (`size`) et la caméra (centre) sur `get_viewport_rect()`, puis ajoute un lion `Lion.tscn` par joueur au-delà du premier, avec `joueur = GameState.joueurs[i]` et `commandes = Commandes.manuelles()` posés avant `add_child`, et les répartit sur la largeur quand il y en a plusieurs. La scène ne configure jamais le mode : `configurer_bataille(n)` est appelé avant de la charger (par le test ici, par le salon en phase 13). Le Spawner ne lit plus le joueur local : `regles.pastille_a_offrir()`, `etoile_peut_apparaitre()`, `coeurs_en_jeu()`, `coeur_peut_apparaitre()`, `avancement()` (phase 10) ; la pastille suivante est programmée quand la précédente quitte la scène ; ses hauteurs d'apparition (réglées pour 648 px) sont multipliées par `hauteur de l'écran / 648`. Le peintre se dimensionne sur `Regles.TAILLE_ECRAN_SOLO` et accélère selon `regles.avancement()`.

**Tech Stack:** Godot 4.7.2, GDScript typé, tests headless (`tests/bataille_test.gd` avec `--fixed-fps 60`, `tests/smoke_test.gd`, `tests/unitaires.gd`), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§5 « Apparition », §7 viewport, §8 fin de manche, §10 tests) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 10 bis ; points de vigilance « phase 10 ») · plan de la phase 10 (découpage, mesures, table des points de vigilance) : `docs/superpowers/plans/2026-09-25-phase-10-bataille-locale.md` · prérequis : phase 10 fusionnée (les requêtes des règles, `Regles.TAILLE_ECRAN_SOLO`, `ReglesBataille.DUREE_MANCHE`).

## Écarts assumés

1. **La scène applique l'écran de ses règles dans les deux modes** (`Main._enter_tree`) : en solo c'est (2000, 648), déjà la taille de départ, donc aucun changement ; une partie solo lancée après une bataille retrouve son écran d'elle-même. L'écran titre, lui, ne revient au solo qu'en phase 10 ter. La taille de la **fenêtre** ne change pas (1400×454, `project.godot`) : en fenêtre, la bataille 16:9 s'affiche avec des bandes ; les captures lisent le viewport (2000×1125) et n'en dépendent pas. Réaffecté à la phase 14 (partie à 2 fenêtres) et 19 (`project.godot`) par la Task 5.
2. **Les lions non locaux ont des commandes manuelles que personne n'écrit dans le jeu** : seul le test les pilote ; la phase 14 y écrira les commandes reçues du réseau.
3. **La pastille suivante est programmée quand la précédente quitte la scène** (`tree_exited`), en solo comme en bataille : en bataille, un cran ne débloque aucune couleur et `couleur_debloquee` ne partait jamais (mesuré : une seule pastille par manche). En partie solo rien ne change (la pastille quitte la scène quand le lion la ramasse, ce qui débloque sa couleur dans la même frame). Dans le smoke test, les appels directs à `regles.pastille_ramassee` ne programment plus de pastille de fond : seules les apparitions aléatoires de fond changent, aucune vérification n'en dépend. Une pastille que personne ne ramasse bloque la suivante (comme en solo) : la cadence de la bataille (un délai de 6 s, une pastille à la fois) est à revoir en jeu, réaffectée à la phase 17 par la Task 5.
4. **Le peintre garde sa taille du solo** (65 % de 648 px, soit 421 px) sur l'écran de 1125 px, comme les lions, les pastilles et les skylines, qui ne changent pas de taille : 65 % de 1125 px (731 px) le ferait dominer tout le ciel. Il accélère avec l'avancement des règles : la ville peinte en solo (inchangé), le temps de la manche en bataille. C'est ce que la bataille garde du peintre (point de vigilance « phases 10 et 17 ») ; la musique et le HUD restent à la phase 17.
5. **Fin d'une bataille : tout se fige, sans overlay** (`compte_le_territoire()` vrai) : le bilan du solo (`GameOver`) ne parle que du joueur local ; l'écran Résultats vient en phase 18. En bataille, le HUD est encore celui du solo (cœurs, pastilles de l'arc-en-ciel, chrono qui monte) et Échap ouvre la pause : phases 17 et 14.
6. **`--fixed-fps 60` et hasard amorcé** pour `tests/bataille_test.gd` : la manche de 90 s dure quelques secondes et se rejoue presque à l'identique (`seed(20260925)` ; seul le délai anti-rafale des chocs, mesuré à l'horloge murale jusqu'à la phase 10 ter, varie). Les mesures de la manche sont affichées (`MESURE`), pas vérifiées : les cibles de réglage viennent en phase 10 ter.
7. **Pas de pré-génération des jeux de tampons** : mesures du plan de la phase 10 (jamais plus d'un jeu généré par frame, 14,6 ms au pire pour l'étoile XXL) ; la manche de la Task 4 les remesure ; la décision et le reste sont écrits dans la feuille de route (Task 5), pour la phase 14.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations.
- Fichiers de la phase (5) : ✏️ `Scripts/Main.gd`, ✏️ `Scripts/Spawner.gd`, ✏️ `Scripts/Boss.gd`, ➕ `tests/bataille_test.gd` (et son `.uid`, généré par l'import, committé avec lui, hors plafond), ✏️ `.github/workflows/ci.yml`. Aucun changement de scène (`Scenes/Main.tscn` garde ses valeurs du solo, que `Main` recalcule).
- Pas de nettoyage préalable (« Step 0 ») : `Main.gd` (132 lignes), `Spawner.gd` (196), `Boss.gd` (156) font moins de 300 lignes.
- Solo strictement identique : le smoke test n'est pas modifié et reste vert ; en solo, l'échelle des hauteurs vaut exactement 1, la difficulté et la vitesse du peintre sont calculées avec les mêmes flottants.
- **Toujours lancer un test Godot avec un délai maximal** et chercher les erreurs dans la sortie :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/bataille_test.gd; O="--fixed-fps 60"; ( godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|MESURE|== " "$TMPDIR/t.log"`
  (`T=tests/smoke_test.gd; O=""` ou `T=tests/unitaires.gd; O=""` pour les deux autres suites ; une suite qui passe n'affiche que ses deux lignes `== … ==`, plus les lignes `MESURE` du test de bataille). Une `SCRIPT ERROR` dans une fonction appelée ne change pas le code de sortie et une erreur avant `quit()` bloque le processus : d'où le délai et le filtre. Un « resources still in use at exit » final est le bruit connu.
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`** : la CI et le filtre ci-dessus les cherchent dans toute la sortie.
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : `tests/bataille_test.gd` récupère `GameState` par `root.get_node("GameState")`, type les lions en `Node2D` / `CharacterBody2D`, lit leurs constantes par l'instance (`lion.CENTRE`) et ne nomme ni `Lion`, ni `Ennemi`, ni la ville ; il peut nommer `Joueur`, `Commandes`, `Territoire`, `Regles` et `ReglesBataille`.
- Les règles du mode sont branchées **avant** de charger la scène (`configurer_bataille(n)`), jamais depuis elle ; `GameState.joueurs` est réinitialisé en place, jamais réassigné.
- La phase est locale : aucune mise en réseau ; les gardes « hôte » (`multiplayer.is_server()`) sont vraies hors ligne.
- `tests/bataille_test.gd` et le smoke test se valident sur **5 passages consécutifs verts**.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Un lion non local qui prend en silence le joueur local ou le clavier** (joueur ou commandes posés après `add_child`, ou pas du tout) : deux lions obéiraient au même clavier et peindraient pour le même joueur. → « chaque lion porte son joueur, dans l'ordre des joueurs », « seul le lion local lit le clavier ; chaque autre lion a ses propres commandes manuelles » (Task 1).
2. **L'écran qui fuit d'un mode à l'autre** : une partie solo lancée après une bataille resterait en 1125 px (lion, ciel, caméra, peintre calés dessus). → « une partie solo après une bataille repasse en 2000×648, avec un seul lion », « ciel, caméra et peintre retrouvent l'écran du solo » (Task 1).
3. **La cadence des pastilles bloquée en bataille** (plus aucune pastille après la première, faute de couleur débloquée) et des cœurs en Facile. → « la pastille suivante arrive après le ramassage de la précédente… », « en bataille, même en Facile, aucun cœur n'est programmé » (Task 2).
4. **Des apparitions calées sur 648 px** (pastilles et ennemis dans le haut du ciel, jamais sur la bande de peinture) ou tenues à distance du seul premier lion. → « les pastilles apparaissent dans leur zone, à l'échelle de l'écran », « … loin de tous les lions, pas seulement du premier », « les ennemis … atteignent la bande de peinture » (Task 2).
5. **Un peintre de 731 px, flottant ou accéléré par la couverture** en bataille. → « le peintre garde sa taille du solo », « … posé sur le haut de la skyline, en bas de l'écran », « à mi-manche, le peintre a fait la moitié de son accélération, que la ville soit peinte ou non » (Task 3).

---

### Task 0 : documentation (spec §7)

**Files:**
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§7)

Ce plan a été commité par le commit de planification de la phase 10 : ne pas le recommiter, **ne jamais le modifier** (ni réécriture, ni résumé).

- [ ] **Step 1 : spec, §7**

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
- En entrant dans une scène multi (salon compris), `get_tree().root.content_scale_size` passe à
  2000×1125, et revient à 2000×648 au retour au titre.
- Le dégradé du ciel et le centre de la caméra, aujourd'hui en dur, sont calculés depuis la taille
  du viewport. Les hauteurs d'apparition des ennemis et des pastilles sont vérifiées.
```

par :

```markdown
- En entrant dans une scène multi (salon compris), `get_tree().root.content_scale_size` passe à
  2000×1125, et revient à 2000×648 au retour au titre. La scène de jeu applique l'écran de ses
  règles (`Regles.taille_ecran()`) en entrant dans l'arbre ; l'écran titre remet le solo
  (`configurer_solo()`) et son écran.
- Le dégradé du ciel et le centre de la caméra sont calculés depuis la taille du viewport. Les
  hauteurs d'apparition des ennemis et des pastilles, réglées pour les 648 px du solo, suivent la
  hauteur de l'écran ; le peintre garde sa taille du solo (65 % de 648 px), comme les lions et
  les skylines, et accélère en bataille avec le temps de la manche.
```

- [ ] **Step 2 : Vérifier et committer**

Run : `git diff --stat docs/`
Expected : la spec seule.

```bash
git add docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md
git commit -m "Spec §7 : la scène applique l'écran de ses règles, apparitions à l'échelle de la hauteur, peintre à sa taille du solo

<ligne fournie par l'environnement>"
```

---

### Task 1 : la scène de bataille à N lions, en 16:9

**Files:**
- Modify: `Scripts/Main.gd` (tout le fichier)
- Create: `tests/bataille_test.gd` (et `tests/bataille_test.gd.uid`)

**Interfaces:**
- Consumes : phase 10 (`Regles.taille_ecran()`, `Regles.compte_le_territoire()`) ; `GameState.configurer_bataille(n)` / `configurer_solo()` (phase 8) ; `Lion.joueur` (se fixe avant l'ajout à l'arbre), `Lion.commandes`, `Lion.CENTRE` (phase 8 bis) ; `Commandes.manuelles()`.
- Produces : `Main.lions: Array[Lion]` (un par joueur, dans l'ordre de `GameState.joueurs`, le premier est `$Lion`) ; `Main.lion: Lion` ; `Main.ciel: TextureRect` ; `@export var Main.hauteur_depart_lions := 0.12` ; les nœuds ajoutés s'appellent `Lion2` … `Lion6`. Dans le test : `_charger_bataille(niveau) -> Node`, `_attendre_depart()`, `_liberer(main)`, `_regles_branchees`, `const NB_LIONS := 4`, `const TAILLE_BATAILLE := Vector2(2000, 1125)`.

- [ ] **Step 1 : le test**

Créer `tests/bataille_test.gd` :

```gdscript
extends SceneTree
## Test de la bataille locale : godot --headless --fixed-fps 60 --script tests/bataille_test.gd
## Une bataille à 4 lions dans un seul processus (sans réseau : ce poste est l'hôte) : écran 16:9,
## un lion par joueur, apparitions et peintre à l'échelle de l'écran, puis une manche de 90 s
## pilotée par le test, dont les mesures (territoire, couverture, vols, crans, jeux de tampons)
## s'affichent en lignes « MESURE ». Avec `--fixed-fps 60`, chaque frame avance d'un tick sans
## attendre l'horloge : la manche entière prend quelques secondes.
## Compilé avant les autoloads : ne nomme ni `GameState`, ni `Lion`, ni `Ennemi`, ni la ville.

const NB_LIONS := 4
const TAILLE_BATAILLE := Vector2(2000, 1125)

var _echecs := 0
var GS: Node
## Les règles branchées par `configurer_bataille`, avant le chargement de la scène.
var _regles_branchees: Regles


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func _run() -> void:
	print("== test de bataille LeLion ==")
	GS = root.get_node("GameState")
	seed(20260925)  # apparitions, ennemis et motifs des tampons reproductibles d'un passage à l'autre
	await _tester_scene()
	await _tester_solo_apres_bataille()
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


## Comme le fera le salon : les règles de bataille sont branchées AVANT le chargement de la scène.
func _charger_bataille(niveau: int) -> Node:
	GS.niveau_courant = niveau
	GS.difficulte_courante = 0  # Facile : le solo y a des cœurs, pas la bataille
	GS.configurer_bataille(NB_LIONS)
	_regles_branchees = GS.regles
	var main: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	return main


## L'intro « Prêt ? Vomissez ! » appelle GameState.demarrer à sa fin.
func _attendre_depart() -> void:
	for i in range(300):
		if GS.pret:
			return
		await physics_frame


## Ennemis, pastilles et étoiles sont des enfants de la scène : ils partent avec elle.
func _liberer(main: Node) -> void:
	paused = false
	main.free()
	await _frames(1)


func _tester_scene() -> void:
	print("-- Scène de bataille à 4 lions")
	var main := await _charger_bataille(0)
	var ville: Node2D = main.get_node("Ville")
	var lions: Array = main.lions
	_check(root.content_scale_size == Vector2i(TAILLE_BATAILLE) and root.get_visible_rect().size == TAILLE_BATAILLE,
		"l'écran de la bataille est en 16:9 (%s)" % root.get_visible_rect().size)
	_check(main.get_node("Ciel").size == TAILLE_BATAILLE and main.get_node("Camera").position == TAILLE_BATAILLE / 2.0,
		"le ciel couvre l'écran et la caméra en vise le centre")
	_check(is_equal_approx(ville.position.y + ville.tex_size.y / 2.0, TAILLE_BATAILLE.y) and ville.territoire != null,
		"la skyline est posée en bas de l'écran et tient le territoire")
	_check(is_same(GS.regles, _regles_branchees), "la scène garde les règles branchées avant elle (elle ne configure pas le mode)")
	_check(lions.size() == NB_LIONS and get_nodes_in_group("lion").size() == NB_LIONS, "un lion par joueur (%d)" % lions.size())
	_check(range(lions.size()).all(func(i: int) -> bool: return lions[i].joueur == GS.joueurs[i]),
		"chaque lion porte son joueur, dans l'ordre des joueurs")
	var ids_commandes := {}
	for l in lions.slice(1):
		ids_commandes[l.commandes.get_instance_id()] = l.commandes.source
	_check(lions[0].commandes.source == Commandes.Source.LOCALES and ids_commandes.size() == NB_LIONS - 1
		and ids_commandes.values().all(func(s: int) -> bool: return s == Commandes.Source.MANUELLES),
		"seul le lion local lit le clavier ; chaque autre lion a ses propres commandes manuelles")
	var teints := lions.size() == NB_LIONS
	var repartis := lions.size() == NB_LIONS
	var centres: Array[Vector2] = []
	for i in range(lions.size()):
		var mat := lions[i].sprite.material as ShaderMaterial
		teints = teints and mat != null and mat.get_shader_parameter("couleur_joueur") == GS.PALETTE_BATAILLE[i]
		var centre: Vector2 = lions[i].position + lions[i].CENTRE
		centres.append(centre)
		repartis = repartis and is_equal_approx(centre.x, TAILLE_BATAILLE.x * (i + 0.5) / NB_LIONS) \
			and is_equal_approx(lions[i].position.y, TAILLE_BATAILLE.y * main.hauteur_depart_lions)
	_check(teints, "chaque lion est teint de la couleur de son joueur")
	_check(repartis, "les lions partent en haut du ciel, répartis sur la largeur (%s)" % [centres])
	await _attendre_depart()
	_check(GS.pret, "l'intro lance la manche")
	GS.terminer_partie(true)
	_check(paused and main.get_node_or_null("GameOver") == null, "la fin de manche fige la bataille, sans le bilan du solo")
	await _liberer(main)


func _tester_solo_apres_bataille() -> void:
	print("-- Solo après une bataille")
	GS.configurer_solo()
	GS.niveau_courant = 2  # le Village : son peintre
	GS.difficulte_courante = 0
	var main: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(2)
	_check(root.get_visible_rect().size == Vector2(2000, 648) and main.lions.size() == 1
		and get_nodes_in_group("lion").size() == 1,
		"une partie solo après une bataille repasse en 2000×648, avec un seul lion")
	_check(main.lion.sprite.material == null and main.lion.commandes.source == Commandes.Source.LOCALES
		and main.lion.position == Vector2(200, 200),
		"son lion garde le rendu d'origine, sa place de départ et les commandes de ce poste")
	var boss: Node2D = get_first_node_in_group("boss")
	_check(main.get_node("Ciel").size == Vector2(2000, 648) and main.get_node("Camera").position == Vector2(1000, 324)
		and boss != null and absf(boss.y_sol - (648 - 180)) < 0.5,
		"ciel, caméra et peintre retrouvent l'écran du solo")
	await _liberer(main)
```

- [ ] **Step 2 : le lancer, il échoue**

Run : `godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error"` (génère `tests/bataille_test.gd.uid`), puis la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected : `SCRIPT ERROR: Invalid access to property or key 'lions' on a base object of type 'Node2D (Main.gd)'` (deux fois : une par section), puis `== 0 échec(s) ==` (la fonction qui rencontre l'erreur s'arrête, le filtre la montre : c'est l'échec attendu).

- [ ] **Step 3 : `Scripts/Main.gd`**

Remplacer tout le contenu de `Scripts/Main.gd` par :

```gdscript
extends Node2D
## Racine de la partie : met l'écran à la taille du mode, place la ville, le ciel, la caméra et
## un lion par joueur, écoute la fin de partie et affiche le bilan du solo.

@export var game_over_scene: PackedScene

@export var force_tremblement := 14.0
@export var duree_tremblement := 0.35
@export var duree_demo := 45.0
## Plusieurs lions (bataille) : hauteur de départ, en part de la hauteur de l'écran (en haut du ciel).
@export var hauteur_depart_lions := 0.12

const SCENE_TITRE := "res://Scenes/Titre.tscn"
const SCRIPT_PILOTE := preload("res://Scripts/Pilote.gd")
const SCENE_LION := preload("res://Scenes/Lion.tscn")

@onready var ville: Node2D = $Ville
@onready var lion: Lion = $Lion
@onready var camera: Camera2D = $Camera
@onready var ciel: TextureRect = $Ciel

## Un lion par joueur, dans l'ordre de `GameState.joueurs` : le premier est celui de la scène,
## le lion du joueur local.
var lions: Array[Lion] = []

var _tremblement_restant := 0.0
var _demo_restant := 0.0


const ACTIONS_DE_JEU := ["deplacer_gauche", "deplacer_droite", "deplacer_haut", "deplacer_bas", "vomir"]


## Avant les _ready des enfants : le lion et le HUD lisent l'état de partie en se construisant,
## le peintre et les apparitions la taille de l'écran. Les règles du mode sont branchées AVANT le
## changement de scène (`GameState.configurer_solo` / `configurer_bataille`), jamais ici.
func _enter_tree() -> void:
	for action in ACTIONS_DE_JEU:
		Input.action_release(action)
	get_tree().root.content_scale_size = GameState.regles.taille_ecran()
	GameState.nouvelle_partie()


func _ready() -> void:
	Audio.demarrer_musique("boss" if GameState.niveau().get("boss", false) else "ville", 0)
	GameState.progression_changee.connect(_on_progression_changee)
	GameState.partie_terminee.connect(_on_partie_terminee)
	GameState.joueur_local().touche.connect(_on_lion_touche)
	ville.charger_skyline(load(GameState.niveau().texture))
	_placer_ville()
	_placer_ciel_et_camera()
	_ajouter_lions()
	if GameState.demo:
		_installer_demo()


## Attract mode : un pilote automatique joue, une étiquette clignote, toute touche ramène au titre.
func _installer_demo() -> void:
	_demo_restant = duree_demo
	var pilote := Node.new()
	pilote.name = "Pilote"
	pilote.set_script(SCRIPT_PILOTE)
	add_child(pilote)
	var couche := CanvasLayer.new()
	couche.name = "Demo"
	couche.layer = 7
	var etiquette := Label.new()
	etiquette.text = "DEMO"
	etiquette.add_theme_font_size_override("font_size", 44)
	etiquette.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	etiquette.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	etiquette.grow_horizontal = Control.GROW_DIRECTION_BOTH
	etiquette.position.y -= 90.0
	couche.add_child(etiquette)
	add_child(couche)
	var clignote := create_tween().set_loops()
	clignote.tween_property(etiquette, "modulate:a", 0.15, 0.6)
	clignote.tween_property(etiquette, "modulate:a", 1.0, 0.6)


func _input(event: InputEvent) -> void:
	if not GameState.demo:
		return
	var pression := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
		or event is InputEventScreenTouch) and event.is_pressed()
	if pression:
		quitter_demo()
		get_viewport().set_input_as_handled()


func quitter_demo(changer_scene := true) -> void:
	if not GameState.demo:
		return
	GameState.demo = false
	get_tree().paused = false
	if changer_scene:
		get_tree().change_scene_to_file(SCENE_TITRE)


func _placer_ville() -> void:
	var screen_size := get_viewport_rect().size
	var texture_size: Vector2 = ville.get_node("Sprite2D").texture.get_size()
	ville.position = Vector2(screen_size.x / 2, screen_size.y - texture_size.y / 2)


## Le ciel couvre l'écran du mode et la caméra en vise le centre (en solo : 2000×648 et
## (1000, 324), les valeurs de la scène).
func _placer_ciel_et_camera() -> void:
	var taille := get_viewport_rect().size
	ciel.size = taille
	camera.position = taille / 2.0


## Un lion par joueur. Le lion de la scène prend de lui-même le joueur local ; chaque autre lion
## reçoit son joueur et des commandes manuelles AVANT l'ajout à l'arbre, sinon il prendrait en
## silence le joueur local et le clavier de ce poste (en phase 14, ses commandes viendront du
## réseau). Plusieurs lions partent en haut du ciel, répartis sur la largeur.
func _ajouter_lions() -> void:
	lions.clear()
	lions.append(lion)
	for i in range(1, GameState.joueurs.size()):
		var autre: Lion = SCENE_LION.instantiate()
		autre.name = "Lion%d" % (i + 1)
		autre.joueur = GameState.joueurs[i]
		autre.commandes = Commandes.manuelles()
		add_child(autre)
		move_child(autre, lion.get_index() + i)
		lions.append(autre)
	if lions.size() > 1:
		_repartir_lions()


## Centres des lions régulièrement espacés sur la largeur, tous à la même hauteur.
func _repartir_lions() -> void:
	var taille := get_viewport_rect().size
	for i in range(lions.size()):
		var centre_x := taille.x * (i + 0.5) / lions.size()
		lions[i].position = Vector2(centre_x - Lion.CENTRE.x, taille.y * hauteur_depart_lions)


func _process(delta: float) -> void:
	if GameState.demo and GameState.partie_en_cours:
		_demo_restant -= delta
		if _demo_restant <= 0.0:
			quitter_demo()
			return
	if _tremblement_restant <= 0.0:
		return
	_tremblement_restant = max(0.0, _tremblement_restant - delta)
	var intensite := force_tremblement * (_tremblement_restant / duree_tremblement)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * intensite
	if _tremblement_restant == 0.0:
		camera.offset = Vector2.ZERO


## La musique gagne une couche par tiers du chemin vers la victoire.
func _on_progression_changee(ratio: float) -> void:
	Audio.definir_intensite(int(ratio / GameState.seuil_victoire() * 3.0))


func trembler() -> void:
	_tremblement_restant = duree_tremblement


## Le lion du joueur local est touché : l'écran tremble.
func _on_lion_touche(_origine: Vector2) -> void:
	trembler()


func _on_partie_terminee(victoire: bool) -> void:
	if GameState.demo:
		if not victoire:
			lion.hide()
		get_tree().paused = true
		get_tree().create_timer(2.5, true).timeout.connect(quitter_demo)
		return
	if GameState.regles.compte_le_territoire():
		# Bataille : tout se fige, scores compris. Le bilan du solo ne parle que du joueur local ;
		# les résultats de la bataille, lus sur le territoire, viendront en phase 18.
		get_tree().paused = true
		return
	if not victoire:
		lion.hide()
	var overlay := game_over_scene.instantiate()
	add_child(overlay)
	overlay.afficher(victoire, GameState.progression, GameState.temps_ecoule)
	get_tree().paused = true
```

- [ ] **Step 4 : les tests passent, le solo n'a pas bougé**

Run : `godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"`
Expected : aucune ligne.

Run : la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`, puis avec `T=tests/smoke_test.gd; O=""` et `T=tests/unitaires.gd; O=""`.
Expected : `== 0 échec(s) ==` pour les trois, sans `SCRIPT ERROR` ; pour le test de bataille, 14 lignes ✅ (`grep -c "✅" "$TMPDIR/t.log"`).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Main.gd tests/bataille_test.gd tests/bataille_test.gd.uid
git commit -m "Main : écran du mode (16:9 en bataille), ciel et caméra calculés, un lion par joueur (joueur et commandes avant l'ajout), répartis en haut du ciel ; une bataille terminée se fige sans le bilan du solo ; test de bataille à 4 lions

<ligne fournie par l'environnement>"
```

---

### Task 2 : les apparitions par les règles, à l'échelle de l'écran

**Files:**
- Modify: `Scripts/Spawner.gd` (tout le fichier)
- Test: `tests/bataille_test.gd` (constante, `_run`, trois fonctions à la fin)

**Interfaces:**
- Consumes : phase 10 (`Regles.pastille_a_offrir()`, `etoile_peut_apparaitre()`, `coeurs_en_jeu()`, `coeur_peut_apparaitre()`, `avancement()`, `Regles.TAILLE_ECRAN_SOLO`) ; Task 1 (`Main.lions`, `_charger_bataille`, `_attendre_depart`, `_liberer`).
- Produces : `Spawner._echelle_hauteur() -> float` (hauteur de l'écran / 648) ; `Spawner._y_ennemi_aleatoire() -> float` ; `Spawner._on_pastille_partie()` (branché sur `tree_exited` de chaque pastille par `spawn_pickup`) ; `Spawner._position_pickup_aleatoire()` tient compte de tous les lions du groupe « lion » ; l'export `couleurs_requises_bonus` disparaît (c'est `ReglesSolo.COULEURS_POUR_ETOILE`) ; plus aucune lecture de `GameState.joueur_local()`, de `GameState.prochain_index_couleur()` ni de `GameState.difficulte().pickups_coeur` dans le Spawner. Dans le test : `const HAUTEURS_JET: Array[float]`, `_etoiles(main) -> Array[Node]`.

- [ ] **Step 1 : les tests**

1a. Dans `tests/bataille_test.gd`, remplacer :

```gdscript
const TAILLE_BATAILLE := Vector2(2000, 1125)
```

par :

```gdscript
const TAILLE_BATAILLE := Vector2(2000, 1125)
const HAUTEURS_JET: Array[float] = [-233.0, -200.0, -270.0]  # y du lion sous le haut de la skyline, comme le pilote de la démo
```

1b. Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	await _tester_scene()
	await _tester_solo_apres_bataille()
```

par :

```gdscript
	await _tester_fin_pendant_intro()
	await _tester_scene()
	await _tester_apparitions()
	await _tester_solo_apres_bataille()
```

1c. Ajouter à la fin de `tests/bataille_test.gd` :

```gdscript


func _etoiles(main: Node) -> Array[Node]:
	var etoiles: Array[Node] = []
	for n in main.get_children():
		if n.scene_file_path.ends_with("BonusPickup.tscn"):
			etoiles.append(n)
	return etoiles


func _tester_fin_pendant_intro() -> void:
	print("-- Fin de partie pendant l'intro")
	var main := await _charger_bataille(0)
	var spawner: Node = main.get_node("Spawner")
	_check(not GS.pret and spawner._timer_soucoupe == null,
		"(pré-condition) l'intro tourne, les minuteries des ennemis n'existent pas encore")
	GS.terminer_partie(false)
	_check(not GS.partie_en_cours and paused and main.get_node_or_null("GameOver") == null,
		"une bataille terminée se fige sans le bilan du solo, même pendant l'intro (le Spawner n'a encore aucune minuterie à arrêter)")
	await _liberer(main)


func _tester_apparitions() -> void:
	print("-- Apparitions de la bataille")
	var main := await _charger_bataille(0)
	var ville: Node2D = main.get_node("Ville")
	var lions: Array = main.lions
	await _attendre_depart()
	# Ce qui apparaît est décidé par les règles, à l'échelle de l'écran
	var spawner: Node = main.get_node("Spawner")
	_check(spawner._timer_soucoupe != null and spawner._timer_coeur == null,
		"en bataille, même en Facile, aucun cœur n'est programmé")
	var echelle := TAILLE_BATAILLE.y / 648.0
	var zone: Rect2 = spawner.zone_pickups
	var dans_zone := true
	var y_max := 0.0
	var loin_de_tous := 0
	for i in range(200):
		var p: Vector2 = spawner._position_pickup_aleatoire()
		y_max = maxf(y_max, p.y)
		if p.x < zone.position.x or p.x > zone.end.x or p.y < zone.position.y * echelle - 0.01 or p.y > zone.end.y * echelle + 0.01:
			dans_zone = false
		if lions.all(func(l: Node2D) -> bool: return p.distance_to(l.global_position) >= spawner.distance_min_du_lion):
			loin_de_tous += 1
	_check(dans_zone and y_max > zone.end.y, "les pastilles apparaissent dans leur zone, à l'échelle de l'écran (y jusqu'à %.0f px)" % y_max)
	_check(loin_de_tous >= 190, "les pastilles apparaissent loin de tous les lions, pas seulement du premier (%d/200)" % loin_de_tous)
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	var ys: Array[float] = []
	for i in range(60):
		var soucoupe: Node2D = spawner.spawn_soucoupe()
		ys.append(soucoupe.position.y)
		soucoupe.free()
	_check(ys.min() >= spawner.zone_y_ennemis.x * echelle - 0.01 and ys.max() <= spawner.zone_y_ennemis.y * echelle + 0.01
		and ys.max() > haut + HAUTEURS_JET[1],
		"les ennemis apparaissent à l'échelle de l'écran et atteignent la bande de peinture (y de %.0f à %.0f)" % [ys.min(), ys.max()])

	# Pastilles : la suivante arrive après le ramassage, même si aucune couleur n'est débloquée
	spawner.delai_entre_pickups = 0.5
	var premiere: Node2D = null
	for i in range(120):
		premiere = get_first_node_in_group("pickup")
		if premiere != null:
			break
		await physics_frame
	_check(premiere != null, "une première pastille arrive après le départ")
	var l2: Node2D = lions[2]
	premiere.global_position = l2.global_position + l2.CENTRE
	await _frames(3)
	_check(not is_instance_valid(premiere) and GS.joueurs[2].crans == 2
		and GS.joueurs.filter(func(j: Joueur) -> bool: return j.crans > 1).size() == 1,
		"une pastille donne un cran au lion qui la touche, à lui seul")
	var suivante: Node2D = null
	for i in range(90):
		suivante = get_first_node_in_group("pickup")
		if suivante != null:
			break
		await physics_frame
	_check(suivante != null, "la pastille suivante arrive après le ramassage de la précédente (aucun déblocage de couleur ne le signale en bataille)")

	# Étoile : possible quel que soit l'état du joueur local
	GS.joueur_local().activer_bonus(5.0)
	spawner._on_timer_bonus()
	var etoiles := _etoiles(main)
	_check(etoiles.size() == 1, "l'étoile apparaît même quand le joueur local est déjà en gerbe XXL")
	for e in etoiles:
		e.free()
	GS.joueur_local().bonus_restant = 0.0
	await _liberer(main)
```

- [ ] **Step 2 : les lancer, ils échouent**

Run : la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected (valeurs relevées à la préparation du plan) : `SCRIPT ERROR: Cannot call method 'stop' on a null value.` (partie terminée pendant l'intro), puis `❌ en bataille, même en Facile, aucun cœur n'est programmé`, `❌ les pastilles apparaissent dans leur zone, à l'échelle de l'écran (y jusqu'à 379 px)`, `❌ les pastilles apparaissent loin de tous les lions, pas seulement du premier (8/200)`, `❌ les ennemis apparaissent à l'échelle de l'écran et atteignent la bande de peinture (y de 122 à 479)`, puis l'échec de la pastille suivante (ou une erreur d'accès à `premiere` si elle manque).

- [ ] **Step 3 : `Scripts/Spawner.gd`**

Remplacer tout le contenu de `Scripts/Spawner.gd` par :

```gdscript
extends Node
## Fait apparaître pickups et ennemis dans la scène parente. Ce qui peut apparaître (pastilles,
## étoile, cœurs) est décidé par les règles de la partie ; les hauteurs d'apparition, réglées pour
## l'écran du solo, suivent la hauteur de l'écran. La difficulté (0 → 1) suit l'avancement de la
## partie (`Regles.avancement`) et le temps écoulé.

@export var color_pickup_scene: PackedScene = preload("res://Scenes/ColorPickup.tscn")
@export var soucoupe_scene: PackedScene = preload("res://Scenes/Soucoupe.tscn")
@export var coccinelle_scene: PackedScene = preload("res://Scenes/Coccinelle.tscn")
@export var bonus_scene: PackedScene = preload("res://Scenes/BonusPickup.tscn")
@export var coeur_scene: PackedScene = preload("res://Scenes/CoeurPickup.tscn")
@export var boss_scene: PackedScene = preload("res://Scenes/Boss.tscn")

@export_group("Pickups")
@export var delai_premier_pickup := 1.0
## Délai entre le départ d'une pastille (ramassée) et l'arrivée de la suivante.
@export var delai_entre_pickups := 6.0
## Zone des pastilles dans l'écran du solo (648 px de haut) ; sa hauteur suit celle de l'écran.
@export var zone_pickups := Rect2(150, 80, 1700, 300)
@export var distance_min_du_lion := 300.0
@export var delai_premier_bonus := 20.0
@export var intervalle_bonus := Vector2(25.0, 35.0)  # min, max
@export var delai_premier_coeur := 12.0
@export var intervalle_coeur := Vector2(18.0, 28.0)  # min, max

@export_group("Ennemis")
## Hauteurs d'apparition des ennemis dans l'écran du solo ; elles suivent la hauteur de l'écran.
@export var zone_y_ennemis := Vector2(120, 480)
@export var intervalle_soucoupe := Vector2(6.0, 2.5)  # début → fin
@export var intervalle_coccinelle := Vector2(8.0, 3.0)
@export var vitesse_soucoupe := Vector2(150.0, 320.0)
@export var duree_montee_difficulte := 120.0
@export var facteur_ennemis_avec_boss := 2.0  # intervalles multipliés quand un boss est présent

var _timer_soucoupe: Timer
var _timer_coccinelle: Timer
var _timer_bonus: Timer
var _timer_coeur: Timer
var _facteur_ennemis := 1.0


func _ready() -> void:
	GameState.partie_terminee.connect(_on_partie_terminee)
	if GameState.niveau().get("boss", false):
		_facteur_ennemis = facteur_ennemis_avec_boss
		spawn_boss()
	if not GameState.pret:
		await GameState.partie_prete
	_programmer(delai_premier_pickup, _spawn_prochain_pickup)
	_timer_soucoupe = _creer_timer(_on_timer_soucoupe)
	_timer_coccinelle = _creer_timer(_on_timer_coccinelle)
	_timer_bonus = _creer_timer(_on_timer_bonus)
	_timer_soucoupe.start(intervalle_soucoupe.x * 0.5 * _facteur_ennemis)
	_timer_coccinelle.start(intervalle_coccinelle.x * 0.8 * _facteur_ennemis)
	_timer_bonus.start(delai_premier_bonus)
	if GameState.regles.coeurs_en_jeu():
		_timer_coeur = _creer_timer(_on_timer_coeur)
		_timer_coeur.start(delai_premier_coeur)


## 0 au début, 1 en fin de partie (avancement des règles : la ville presque peinte en solo, la
## fin de la manche en bataille) ou après `duree_montee_difficulte`.
func difficulte() -> float:
	var par_temps := GameState.temps_ecoule / duree_montee_difficulte
	return clamp(max(GameState.regles.avancement(), par_temps), 0.0, 1.0)


func _intervalle(bornes: Vector2) -> float:
	return lerp(bornes.x, bornes.y, difficulte()) * randf_range(0.8, 1.2) * _facteur_ennemis


func _creer_timer(action: Callable) -> Timer:
	var t := Timer.new()
	t.one_shot = true
	t.timeout.connect(action)
	add_child(t)
	return t


func _programmer(delai: float, action: Callable) -> void:
	get_tree().create_timer(delai).timeout.connect(action)


## Une partie peut se terminer pendant l'intro, avant la création des minuteries.
func _on_partie_terminee(_victoire: bool) -> void:
	for t: Timer in [_timer_soucoupe, _timer_coccinelle, _timer_bonus, _timer_coeur]:
		if t != null:
			t.stop()


func _on_timer_soucoupe() -> void:
	spawn_soucoupe()
	_timer_soucoupe.start(_intervalle(intervalle_soucoupe))


func _on_timer_coccinelle() -> void:
	spawn_coccinelle()
	_timer_coccinelle.start(_intervalle(intervalle_coccinelle))


func _on_timer_bonus() -> void:
	if GameState.regles.etoile_peut_apparaitre():
		spawn_bonus(_position_pickup_aleatoire())
		_timer_bonus.start(randf_range(intervalle_bonus.x, intervalle_bonus.y))
	else:
		_timer_bonus.start(5.0)


func _on_timer_coeur() -> void:
	if GameState.regles.coeur_peut_apparaitre() and get_tree().get_first_node_in_group("coeur_pickup") == null:
		spawn_coeur(_position_pickup_aleatoire())
		_timer_coeur.start(randf_range(intervalle_coeur.x, intervalle_coeur.y))
	else:
		_timer_coeur.start(5.0)


func spawn_coeur(position_coeur: Vector2) -> Node:
	var coeur := coeur_scene.instantiate()
	coeur.global_position = position_coeur
	get_parent().add_child(coeur)
	return coeur


func spawn_bonus(position_bonus: Vector2) -> Node:
	var bonus := bonus_scene.instantiate()
	bonus.global_position = position_bonus
	get_parent().add_child(bonus)
	return bonus


## La pastille suivante est programmée quand celle-ci quitte la scène (ramassée) : en bataille,
## un cran de gerbe ne débloque aucune couleur, rien d'autre ne le signalerait. Une scène qui se
## libère fait aussi sortir ses pastilles : rien n'est programmé hors de l'arbre.
func _on_pastille_partie() -> void:
	if is_inside_tree():
		_programmer(delai_entre_pickups, _spawn_prochain_pickup)


func _spawn_prochain_pickup() -> void:
	var index := GameState.regles.pastille_a_offrir()
	if index < 0 or not GameState.partie_en_cours:
		return
	spawn_pickup(index, _position_pickup_aleatoire())


## Hauteur de l'écran rapportée à celle du solo : 1 en solo (hauteurs d'apparition inchangées).
func _echelle_hauteur() -> float:
	return get_viewport().get_visible_rect().size.y / Regles.TAILLE_ECRAN_SOLO.y


## Au hasard dans la zone des pastilles, à `distance_min_du_lion` de chaque lion si possible
## (dix essais).
func _position_pickup_aleatoire() -> Vector2:
	var lions := get_tree().get_nodes_in_group("lion")
	var echelle := _echelle_hauteur()
	var pos := Vector2.ZERO
	for tentative in range(10):
		pos = Vector2(
			randf_range(zone_pickups.position.x, zone_pickups.end.x),
			randf_range(zone_pickups.position.y * echelle, zone_pickups.end.y * echelle))
		if lions.all(func(l: Node) -> bool: return pos.distance_to((l as Node2D).global_position) >= distance_min_du_lion):
			break
	return pos


func _y_ennemi_aleatoire() -> float:
	var echelle := _echelle_hauteur()
	return randf_range(zone_y_ennemis.x * echelle, zone_y_ennemis.y * echelle)


## Le boss se pose sur le haut de la skyline. Ajout différé : depuis _ready, la ville n'a
## pas encore reçu la texture du niveau (Main la charge après ses enfants).
func spawn_boss() -> Node:
	var boss := boss_scene.instantiate()
	_placer_et_ajouter_boss.call_deferred(boss)
	return boss


func _placer_et_ajouter_boss(boss: Node) -> void:
	var ville: Node2D = get_tree().get_first_node_in_group("ville")
	if ville != null:
		boss.y_sol = ville.position.y - ville.tex_size.y / 2.0
	get_parent().add_child(boss)


func spawn_pickup(index: int, position_pickup: Vector2) -> Node:
	var pickup := color_pickup_scene.instantiate()
	pickup.couleur_index = index
	pickup.global_position = position_pickup
	pickup.tree_exited.connect(_on_pastille_partie)
	get_parent().add_child(pickup)
	return pickup


## `y_depart` négatif = hauteur aléatoire.
func spawn_soucoupe(y_depart: float = -1.0) -> Node:
	var soucoupe := soucoupe_scene.instantiate()
	if y_depart < 0.0:
		y_depart = _y_ennemi_aleatoire()
	soucoupe.position = Vector2(-200, y_depart)
	soucoupe.speed = lerp(vitesse_soucoupe.x, vitesse_soucoupe.y, difficulte())
	get_parent().add_child(soucoupe)
	return soucoupe


## `y_depart` négatif = hauteur aléatoire.
func spawn_coccinelle(y_depart: float = -1.0) -> Node:
	var c := coccinelle_scene.instantiate()
	var largeur := get_viewport().get_visible_rect().size.x
	if y_depart < 0.0:
		y_depart = _y_ennemi_aleatoire()
	c.position = Vector2(largeur + 100, y_depart)
	get_parent().add_child(c)
	return c
```

- [ ] **Step 4 : les tests passent, le solo n'a pas bougé**

Run : `grep -rn "couleurs_requises_bonus\|joueur_local\|prochain_index_couleur\|pickups_coeur" Scripts/Spawner.gd Scenes/Main.tscn`
Expected : aucune ligne (la scène ne surchargeait pas l'export retiré).

Run : la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`, puis `T=tests/smoke_test.gd; O=""`.
Expected : `== 0 échec(s) ==` pour les deux, sans `SCRIPT ERROR` (le smoke test vérifie toujours « mode Hardcore : pas de cœurs à ramasser » par `_timer_coeur == null` et les pastilles du solo).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Spawner.gd tests/bataille_test.gd
git commit -m "Spawner : apparitions décidées par les règles (plus de lecture du joueur local), hauteurs à l'échelle de l'écran, pastilles loin de tous les lions, pastille suivante après le départ de la précédente ; minuteries nulles pendant l'intro gérées

<ligne fournie par l'environnement>"
```

---

### Task 3 : le peintre à sa taille du solo, accéléré par l'avancement

**Files:**
- Modify: `Scripts/Boss.gd` (`hauteur_ratio`, `_ready`, `facteur_vitesse`)
- Test: `tests/bataille_test.gd` (`_run`, une fonction à la fin)

**Interfaces:**
- Consumes : phase 10 (`Regles.TAILLE_ECRAN_SOLO`, `Regles.avancement()`, `ReglesBataille.DUREE_MANCHE`, `ReglesBataille.DUREE_ETOURDI_ENNEMI`) ; Task 1 (`Main.lions`) ; Task 2 (le Spawner pose le peintre sur la ville placée en bas de l'écran).
- Produces : `Boss.facteur_vitesse()` lit `GameState.regles.avancement()` ; la hauteur du peintre vaut `Regles.TAILLE_ECRAN_SOLO.y × hauteur_ratio` dans les deux modes.

- [ ] **Step 1 : le test**

1a. Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	await _tester_apparitions()
```

par :

```gdscript
	await _tester_apparitions()
	await _tester_peintre()
```

1b. Ajouter à la fin de `tests/bataille_test.gd` :

```gdscript


func _tester_peintre() -> void:
	print("-- Peintre en 16:9")
	var main := await _charger_bataille(2)
	var ville: Node2D = main.get_node("Ville")
	await _frames(1)  # le Spawner ajoute le peintre en différé
	var boss: Node2D = get_first_node_in_group("boss")
	_check(boss != null, "le Village de la bataille a son peintre")
	var hauteur: float = boss.sprite.scale.y * boss.sprite.texture.get_height()
	_check(absf(hauteur - 648.0 * boss.hauteur_ratio) < 1.0,
		"le peintre garde sa taille du solo (%.0f px) sur l'écran de 1125 px" % hauteur)
	_check(absf(boss.y_sol - (TAILLE_BATAILLE.y - ville.tex_size.y)) < 0.5 and absf(boss.position.y + boss._demi_hauteur - boss.y_sol) < 0.5,
		"le peintre est posé sur le haut de la skyline, en bas de l'écran (sol %.0f)" % boss.y_sol)
	GS.progression = 0.0
	GS.temps_ecoule = ReglesBataille.DUREE_MANCHE / 2.0
	_check(is_equal_approx(boss.facteur_vitesse(), lerpf(1.0, boss.acceleration_max, 0.5)),
		"à mi-manche, le peintre a fait la moitié de son accélération, que la ville soit peinte ou non (%.3f)" % boss.facteur_vitesse())
	GS.temps_ecoule = 0.0
	await _attendre_depart()
	boss._arreter()
	boss.etat = boss.Etat.PAUSE
	boss.position.x = TAILLE_BATAILLE.x / 2.0
	var l3: Node2D = main.lions[3]
	var j3: Joueur = GS.joueurs[3]
	l3.global_position = Vector2(boss.position.x - l3.CENTRE.x, boss.position.y - l3.CENTRE.y)
	await _frames(3)
	_check(j3.est_etourdi() and j3.etourdi_restant > ReglesBataille.DUREE_ETOURDI_ENNEMI - 0.2 and j3.vies == 3,
		"le peintre étourdit le lion de bataille qu'il touche, sans lui ôter de vie")
	await _liberer(main)
```

- [ ] **Step 2 : le lancer, il échoue**

Run : la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected : `❌ le peintre garde sa taille du solo (731 px) sur l'écran de 1125 px` et `❌ à mi-manche, le peintre a fait la moitié de son accélération, que la ville soit peinte ou non (1.000)`, puis `== 2 échec(s) ==`.

- [ ] **Step 3 : `Scripts/Boss.gd`**

3a. Remplacer :

```gdscript
@export var hauteur_ratio := 0.65        # part de la hauteur de l'écran
```

par :

```gdscript
@export var hauteur_ratio := 0.65        # part de la hauteur de l'écran du solo, dans les deux modes
```

3b. Remplacer :

```gdscript
	var taille_ecran := get_viewport_rect().size
	var hauteur_cible := taille_ecran.y * hauteur_ratio
```

par :

```gdscript
	# Le peintre garde sa taille du solo sur l'écran 16:9 de la bataille, comme les lions et les
	# skylines : 65 % des 1125 px le feraient dominer tout le ciel.
	var hauteur_cible := Regles.TAILLE_ECRAN_SOLO.y * hauteur_ratio
```

3c. Remplacer :

```gdscript
## Facteur appliqué aux durées : 1 au début, `acceleration_max` quand la ville est presque peinte.
func facteur_vitesse() -> float:
	var avancement: float = clamp(GameState.progression / GameState.seuil_victoire(), 0.0, 1.0)
```

par :

```gdscript
## Facteur appliqué aux durées : 1 au début, `acceleration_max` en fin de partie. L'avancement
## vient des règles : la ville peinte en solo, le temps de la manche en bataille.
func facteur_vitesse() -> float:
	var avancement: float = clamp(GameState.regles.avancement(), 0.0, 1.0)
```

- [ ] **Step 4 : les tests passent, le solo n'a pas bougé**

Run : la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`, puis `T=tests/smoke_test.gd; O=""`.
Expected : `== 0 échec(s) ==` pour les deux (le smoke test vérifie toujours « le boss fait 65 % de la hauteur de l'écran » sur 648 px et le cycle accéléré du peintre).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Boss.gd tests/bataille_test.gd
git commit -m "Peintre : taille du solo sur l'écran 16:9, accélération par l'avancement des règles (temps de la manche en bataille)

<ligne fournie par l'environnement>"
```

---

### Task 4 : une manche à 4 lions pilotée, en CI

**Files:**
- Test: `tests/bataille_test.gd` (constante, `_run`, quatre fonctions à la fin)
- Modify: `.github/workflows/ci.yml` (une étape)

**Interfaces:**
- Consumes : Tasks 1 à 3 ; `Territoire.cellules_de`, `Territoire.proprietaire`, `Territoire.nb_peignables`, `Territoire.taille_grille`, `Territoire.PERSONNE` ; `Ville._tampons` (lu par l'instance), `Ville.progression()`.
- Produces : dans le test, `const DISTANCE_PASTILLE_TENTANTE := 900.0`, `_pastilles(main) -> Array[Node]`, `_pastille_visee(lion, lions, pastilles) -> Node2D`, `_piloter(lion, couloir: Dictionary, haut, lions, pastilles)`, `_tester_manche()` et ses trois lignes `MESURE` (reprises par la phase 10 ter) ; une étape « Test de la bataille locale » en CI.

Les scores se lisent sur le territoire de la ville (`ville.territoire.cellules_de(i)`, sur `nb_peignables` pour un pourcentage) : il n'y a pas de `Joueur.cellules` (spec §3.1). Le pilote de la manche va chercher la pastille (ou l'étoile) la plus proche à moins de 900 px dont il est le lion le plus proche, sinon balaie son couloir (700 px, centré sur sa place de départ, qui chevauche ceux des voisins) en vomissant sur les trois hauteurs de jet du pilote de la démo.

- [ ] **Step 1 : le test**

1a. Dans `tests/bataille_test.gd`, remplacer :

```gdscript
const HAUTEURS_JET: Array[float] = [-233.0, -200.0, -270.0]  # y du lion sous le haut de la skyline, comme le pilote de la démo
```

par :

```gdscript
const HAUTEURS_JET: Array[float] = [-233.0, -200.0, -270.0]  # y du lion sous le haut de la skyline, comme le pilote de la démo
const DISTANCE_PASTILLE_TENTANTE := 900.0  # le pilote de la manche va chercher une pastille dans ce rayon
```

1b. Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	await _tester_peintre()
	await _tester_solo_apres_bataille()
```

par :

```gdscript
	await _tester_peintre()
	await _tester_manche()
	await _tester_solo_apres_bataille()
```

1c. Ajouter à la fin de `tests/bataille_test.gd` :

```gdscript


## Pastilles et étoiles de la scène.
func _pastilles(main: Node) -> Array[Node]:
	var liste: Array[Node] = []
	liste.assign(get_nodes_in_group("pickup"))
	liste.append_array(_etoiles(main))
	return liste


## La pastille (ou l'étoile) que ce lion va chercher : la plus proche à portée, dont il est le
## lion le plus proche ; null s'il n'y en a pas.
func _pastille_visee(lion: Node2D, lions: Array, pastilles: Array[Node]) -> Node2D:
	var centre: Vector2 = lion.global_position + lion.CENTRE
	var visee: Node2D = null
	var distance := DISTANCE_PASTILLE_TENTANTE
	for p: Node2D in pastilles:
		var d := centre.distance_to(p.global_position)
		var plus_proche := lions.all(func(l: Node2D) -> bool:
			return l == lion or (l.global_position + l.CENTRE).distance_to(p.global_position) >= d)
		if d < distance and plus_proche:
			distance = d
			visee = p
	return visee


## Pilote d'un lion de la manche : il va chercher sa pastille s'il en vise une ; sinon il balaie
## son couloir en vomissant et change de hauteur à chaque demi-tour. Les couloirs voisins se
## chevauchent : les lions se volent des cellules.
func _piloter(lion: Node2D, couloir: Dictionary, haut: float, lions: Array, pastilles: Array[Node]) -> void:
	var centre: Vector2 = lion.global_position + lion.CENTRE
	var visee := _pastille_visee(lion, lions, pastilles)
	if visee != null:
		lion.commandes.direction_voulue = (visee.global_position - centre).normalized()
		lion.commandes.vomir_voulu = false
		return
	if centre.x >= couloir.max:
		couloir.sens = -1.0
		couloir.rangee = (couloir.rangee + 1) % HAUTEURS_JET.size()
	elif centre.x <= couloir.min:
		couloir.sens = 1.0
		couloir.rangee = (couloir.rangee + 1) % HAUTEURS_JET.size()
	var ecart_y: float = haut + HAUTEURS_JET[couloir.rangee] - lion.global_position.y
	lion.commandes.direction_voulue = Vector2(couloir.sens, clampf(ecart_y / 60.0, -1.0, 1.0)).normalized()
	lion.commandes.vomir_voulu = true


func _tester_manche() -> void:
	print("-- Manche à 4 lions, pilotée")
	var main := await _charger_bataille(0)
	var ville: Node2D = main.get_node("Ville")
	var t: Territoire = ville.territoire
	var lions: Array = main.lions
	lions[0].commandes = Commandes.manuelles()  # le lion local est piloté par le test, comme les autres
	await _attendre_depart()
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	var couloirs: Array[Dictionary] = []
	for i in range(NB_LIONS):
		var centre := TAILLE_BATAILLE.x * (i + 0.5) / NB_LIONS
		couloirs.append({"min": maxf(centre - 350.0, 150.0), "max": minf(centre + 350.0, 1850.0),
			"sens": 1.0 if i % 2 == 0 else -1.0, "rangee": i % HAUTEURS_JET.size()})
	var jeux_au_depart: int = ville._tampons.size()
	var jeux_max_par_frame := 0
	var pire_frame_ms := 0.0
	var instant := Time.get_ticks_usec()
	for f in range(int(ReglesBataille.DUREE_MANCHE * Engine.physics_ticks_per_second)):
		var pastilles := _pastilles(main)
		for i in range(NB_LIONS):
			_piloter(lions[i], couloirs[i], haut, lions, pastilles)
		var jeux_avant: int = ville._tampons.size()
		await physics_frame
		jeux_max_par_frame = maxi(jeux_max_par_frame, ville._tampons.size() - jeux_avant)
		var maintenant := Time.get_ticks_usec()
		pire_frame_ms = maxf(pire_frame_ms, (maintenant - instant) / 1000.0)
		instant = maintenant
	GS.terminer_partie(true)
	var scores: Array = range(NB_LIONS).map(func(i: int) -> int: return t.cellules_de(i))
	var comptees: int = scores.reduce(func(somme: int, n: int) -> int: return somme + n, 0)
	var personne := t.cellules_de(Territoire.PERSONNE)
	var chargees := 0
	for c in range(t.taille_grille.x * t.taille_grille.y):
		if t.proprietaire(c) != Territoire.PERSONNE:
			chargees += 1
	var vols: Array = GS.joueurs.map(func(j: Joueur) -> int: return j.cellules_volees)
	print("  MESURE manche de %d s : cellules %s (%.1f %% de la ville), %d chargées dont %d ne comptent pour personne (%.0f %%), couverture %.1f %%"
		% [int(ReglesBataille.DUREE_MANCHE), scores, 100.0 * comptees / t.nb_peignables, chargees, chargees - comptees,
			100.0 * (chargees - comptees) / maxi(chargees, 1), 100.0 * ville.progression()])
	print("  MESURE vols %s, étourdissements infligés %s, chocs %s, crans %s"
		% [vols, GS.joueurs.map(func(j: Joueur) -> int: return j.etourdissements_infliges),
			GS.joueurs.map(func(j: Joueur) -> int: return j.chocs), GS.joueurs.map(func(j: Joueur) -> int: return j.crans)])
	print("  MESURE jeux de tampons : %d générés pendant la manche (%d en cache), au plus %d dans une même frame ; frame la plus longue %.1f ms"
		% [ville._tampons.size() - jeux_au_depart, ville._tampons.size(), jeux_max_par_frame, pire_frame_ms])
	_check(scores.all(func(n: int) -> bool: return n > 0), "chaque lion possède des cellules en fin de manche (%s)" % [scores])
	_check(comptees + personne == t.nb_peignables, "les scores et les cellules qui ne comptent pour personne font toute la ville")
	_check(vols.any(func(n: int) -> bool: return n > 0), "les couloirs qui se chevauchent donnent des vols (%s)" % [vols])
	_check(GS.joueurs.any(func(j: Joueur) -> bool: return j.crans > 1), "des pastilles sont ramassées en cours de manche")
	_check(paused and main.get_node_or_null("GameOver") == null, "la fin de manche fige la bataille, sans le bilan du solo")
	await _liberer(main)
```

- [ ] **Step 2 : la manche passe, ses mesures s'affichent**

Run : la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected : trois lignes `MESURE` (ordre de grandeur mesuré à la préparation du plan : 20 à 27 % de la ville possédée, 8 à 16 % des cellules chargées sans propriétaire compté, des centaines de vols, crans jusqu'à 6 ou 7, 15 à 17 jeux de tampons générés, au plus 1 par frame), puis `== 0 échec(s) ==`, en moins de 10 s.

- [ ] **Step 3 : la CI lance le test de bataille**

Dans `.github/workflows/ci.yml`, remplacer :

```yaml
      - name: Exporter en Web
```

par :

```yaml
      - name: Test de la bataille locale
        shell: bash
        run: |
          set -o pipefail
          timeout 300 godot --headless --fixed-fps 60 --script tests/bataille_test.gd 2>&1 | tee bataille_test.log
          if grep -nE "SCRIPT ERROR|SHADER ERROR" bataille_test.log; then echo "::error::erreur de script dans le test de bataille"; exit 1; fi

      - name: Exporter en Web
```

Run : `python3 -c "import yaml,sys; d=yaml.safe_load(open('.github/workflows/ci.yml')); print([s.get('name') for s in d['jobs']['test-et-export']['steps']])"`
Expected : `[None, "Installer Godot et les templates d'export", 'Importer les ressources', 'Tests unitaires', 'Smoke test', 'Test de la bataille locale', 'Exporter en Web']`.

- [ ] **Step 4 : validation, 5 passages consécutifs**

Run : 5 fois la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`, puis 5 fois avec `T=tests/smoke_test.gd; O=""`, puis une fois `T=tests/unitaires.gd; O=""`.
Expected : `== 0 échec(s) ==` à chaque passage, sans `SCRIPT ERROR` ni `SHADER ERROR`.

- [ ] **Step 5 : Commit**

```bash
git add tests/bataille_test.gd .github/workflows/ci.yml
git commit -m "Test de bataille : manche de 90 s à 4 lions pilotés (scores lus sur le territoire, vols, crans, mesures des jeux de tampons) ; la CI le lance en --fixed-fps 60

<ligne fournie par l'environnement>"
```

---

### Task 5 : feuille de route, points de vigilance de la phase 10 bis

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`

**Ne jamais modifier les fichiers des plans** : seule la feuille de route change ici. Reprendre les chiffres des lignes `MESURE` de la Task 4 là où ce texte les cite, s'ils diffèrent.

- [ ] **Step 1 : la vérification commune lance le test de bataille**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

````markdown
godot --headless --script tests/smoke_test.gd
```

Les deux derniers doivent finir sur `== 0 échec(s) ==` et un code de sortie 0.
````

par :

````markdown
godot --headless --script tests/smoke_test.gd
godot --headless --fixed-fps 60 --script tests/bataille_test.gd  # à partir de la phase 10 bis
```

Les trois derniers doivent finir sur `== 0 échec(s) ==` et un code de sortie 0.
````

- [ ] **Step 2 : les lions non locaux (Task 1)**

Remplacer :

```markdown
- Phases 10 et 14 : tout lion qui n'est pas celui du joueur local doit recevoir `joueur` et
  `commandes` avant `add_child` (en phase 14 via la `spawn_function` du `MultiplayerSpawner`) ;
  sinon il prend en silence le joueur local et le clavier de ce poste.
```

par :

```markdown
- Phase 14 : tout lion qui n'est pas celui du joueur local doit recevoir `joueur` et `commandes`
  avant `add_child`, via la `spawn_function` du `MultiplayerSpawner` (en local, c'est
  `Main._ajouter_lions` depuis la phase 10 bis, vérifié par `tests/bataille_test.gd`) ; sinon il
  prend en silence le joueur local et le clavier de ce poste. La fenêtre garde sa taille du solo
  (1400×454) : en 16:9, la bataille s'y affiche avec des bandes ; régler la fenêtre pour la partie
  à 2 fenêtres de la phase 14, puis dans `project.godot` en phase 19. En bataille, Échap ouvre
  encore la pause du solo (`PauseMenu` met l'arbre en pause) : en réseau, un menu local sans pause
  (spec §4).
```

- [ ] **Step 3 : les apparitions et `prochain_index_couleur` (Task 2)**

Remplacer :

```markdown
- phase 10 : les conditions d'apparition (étoile à partir de 2 couleurs, cœurs) passent par les
  règles (par exemple `regles.etoile_peut_apparaitre()`, aucun cœur en bataille) au lieu que le
  Spawner lise le joueur local ;
```

par :

```markdown
- **phase 17** (rythme de la manche) : le Spawner fait arriver une pastille à la fois, 6 s après le
  départ de la précédente (phase 10 bis) ; une pastille que personne ne ramasse bloque la suivante,
  comme en solo. À revoir en jeu à 4-6 joueurs (délai propre à la bataille dans les règles, durée
  de vie des pastilles) ;
```

puis supprimer (remplacer par rien) :

```markdown
- **phase 10** : `Spawner.gd` choisit la prochaine pastille avec `GameState.prochain_index_couleur()`
  (règle du solo) : à faire passer par les règles avec les autres conditions d'apparition.
```

- [ ] **Step 4 : le coût des jeux de tampons, mesuré (Task 4)**

Remplacer :

```markdown
- **phase 10** : chaque nouveau jeu de tampons (`Ville._generer_tampons`) est généré en GDScript,
  dans le tick physique de l'hôte, au premier usage d'un rayon et d'un jeu de couleurs : coût
  mesuré de 3,7 ms (46 px) à 14,5 ms (92 px, étoile XXL) sur la machine du plan. À 6 joueurs, 84
  jeux possibles au pire, donc des à-coups visibles si plusieurs étoiles sont ramassées dans la
  même seconde. Pré-générer les jeux de chaque joueur pendant l'intro « Prêt ? Vomissez ! » (ses
  nuances, les 7 rayons, x2), ou les générer au premier cran atteint, ou mesurer d'abord sur la
  manche à 4 lions avant de décider. Mémoire du cache plein : environ 14,5 Mo pour 6 joueurs (et
  non 12 Mo comme l'annonce le commentaire de `Ville.gd`, sans conséquence) ;
```

par :

```markdown
- **phase 14** : jeux de tampons (`Ville._generer_tampons`), mesurés en phase 10 : 0,5 ms (16 px)
  à 3,7 ms (46 px), 14,6 ms pour l'étoile XXL (92 px), 65 ms pour les 14 jeux d'un joueur ; sur la
  manche à 4 pilotée de `tests/bataille_test.gd` (ligne `MESURE jeux de tampons`), 15 à 17 jeux
  générés, jamais plus d'un par frame (une seule pastille et une seule étoile à la fois). Décision
  de la phase 10 bis : pas de pré-génération en local. En phase 14, chaque client génère aussi ses
  jeux (graine dérivée de la clé) : les pré-générer pendant l'intro (nuances de chaque joueur, 7
  rayons, ×2) si la mesure sur un client montre des à-coups. Mémoire du cache plein : environ
  14,5 Mo pour 6 joueurs ;
```

- [ ] **Step 5 : le préexistant du Spawner, résolu ; la moitié `screenshots.gd`, réaffectée (Task 2)**

Remplacer :

```markdown
- **préexistant, à corriger dès qu'une phase touche `Scripts/Spawner.gd` ou `tests/screenshots.gd`** :
  `Spawner._on_partie_terminee` appelle `stop()` sur `_timer_soucoupe` / `_timer_coccinelle`, qui
  sont `null` si la partie se termine pendant l'intro (`SCRIPT ERROR` dans `tests/screenshots.gd`) ;
  et le coup de `tests/screenshots.gd` (vers la ligne 96) tombe pendant l'intro et n'a aucun effet.
  Relancer `tests/screenshots.gd` à la main après correction (la CI ne le lance pas) ;
```

par :

```markdown
- **phase 19** (qui touche `tests/screenshots.gd`) : le coup de `tests/screenshots.gd` (vers la
  ligne 96) tombe pendant l'intro et n'a aucun effet ; le déplacer après `GS.demarrer()` et relancer
  le script à la main (la CI ne le lance pas). Les minuteries `null` du Spawner quand la partie se
  termine pendant l'intro sont corrigées depuis la phase 10 bis (vérifié par
  `tests/bataille_test.gd`) ;
```

- [ ] **Step 6 : scores et couverture en bataille (Tasks 3 et 4)**

Remplacer :

```markdown
- **phases 10 et 17** : le score d'un joueur se lit sur le territoire de la ville
  (`ville.territoire.cellules_de(joueur.index)`, sur `ville.territoire.nb_peignables` pour un
  pourcentage) ; il n'y a pas de `Joueur.cellules` (spec §3.1). La ville crée son territoire dans
  `charger_skyline` d'après les règles branchées (`compte_le_territoire()`) : c'est une raison de
  plus d'appeler `configurer_bataille(n)` avant la scène de bataille. La couverture du solo reste
  mesurée en bataille (`GameState.progression`, lue par `Audio`, `Boss.facteur_vitesse` et le
  HUD) : décider de ce que la bataille en garde (phase 10 pour le peintre, 17 pour la musique et
  le HUD). Les réglages du territoire (`GAIN`, `SEUIL_POSSESSION`, `CHARGE_MAX`) sont à revoir
  sur une vraie manche ;
```

par :

```markdown
- **phase 17** : le score d'un joueur se lit sur le territoire de la ville
  (`ville.territoire.cellules_de(joueur.index)`, sur `ville.territoire.nb_peignables` pour un
  pourcentage, comme la manche de `tests/bataille_test.gd`) ; il n'y a pas de `Joueur.cellules`
  (spec §3.1). La couverture du solo reste mesurée en bataille (`GameState.progression`) : le
  peintre et la difficulté des ennemis suivent `Regles.avancement()` depuis la phase 10 bis (le
  temps de la manche en bataille) ; la musique (`Main._on_progression_changee`, encore sur la
  couverture) et le HUD (encore celui du solo en bataille : cœurs, arc-en-ciel, chrono qui monte)
  sont à la phase 17. `int(regles.avancement() × 3)` donne les couches de la spec §8 (arpèges à
  30 s écoulées, mélodie à 60 s), mais au rythme du chrono, pas des mesures de couverture ;
```

- [ ] **Step 7 : Vérifier et committer**

Run : `grep -nE "^- (\*\*)?phases? 10( |\*\*|,)" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
Expected : les quatre points que traite la phase 10 ter (réglage du territoire, pseudo, `configurer_solo()` / `configurer_bataille(n)`, retrait de `prochain_index_couleur`), et eux seuls.

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
git commit -m "Feuille de route : points de vigilance résolus par la phase 10 bis (lions non locaux, apparitions, minuteries du Spawner, peintre) ; jeux de tampons mesurés (phase 14), rythme des pastilles (17), captures (19), fenêtre et pause en bataille (14)

<ligne fournie par l'environnement>"
```

---

## Sortie de phase

- Les trois suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR`, localement (test de bataille et smoke test 5 fois de suite chacun) puis en CI sur la PR (nouvelle étape « Test de la bataille locale » verte).
- `git diff main --stat` : 5 fichiers de code et de test (`Scripts/Main.gd`, `Scripts/Spawner.gd`, `Scripts/Boss.gd`, `tests/bataille_test.gd`, `.github/workflows/ci.yml`) plus `tests/bataille_test.gd.uid`, la spec et la feuille de route.
- `grep -n "joueur_local\|prochain_index_couleur\|seuil_victoire\|progression" Scripts/Spawner.gd Scripts/Boss.gd` : seulement les commentaires qui parlent de l'avancement (aucun appel).
- `grep -rn "prochain_index_couleur" Scripts tests` : la seule définition dans `Scripts/GameState.gd` (retirée en phase 10 ter).
- Rappeler à l'utilisateur : la bataille se lance seulement depuis le test (le salon arrive en phase 13) ; en bataille, le HUD et la musique sont encore ceux du solo (phase 17) ; le retour au titre, le réglage du territoire et le contrôle visuel ◉ « manche à 4 » sont la phase 10 ter (`docs/superpowers/plans/2026-09-25-phase-10ter-reglage-manche.md`).
