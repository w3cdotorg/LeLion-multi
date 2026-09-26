# Phase 14 bis : les pastilles vers `body is Lion` (base commune `Pastille`), sons de ramassage unifiés, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** les trois pastilles (couleur, étoile, cœur) partagent une base `Pastille` : un contact n'est tranché que par l'hôte, ne compte que pour un lion (`body is Lion`, plus le groupe « lion » ni `body.joueur` supposé), une pastille ne sert qu'une fois (premier arrivé, premier servi), et une réplique (client) ne se libère jamais d'elle-même (`_expirer`) ; le son de ramassage passe par `Audio` et les signaux du joueur local sur chaque poste (couleur, cran, gerbe XXL, vie), une seule fois par ramassage ; le smoke test reçoit les durcissements de la revue de la phase 8 ter, dont l'un révèle et fait corriger le recul du peintre (vers le bas, au lieu d'être horizontal). Sortie : **smoke vert**, les quatre suites vertes 5 fois (test réseau sous bash 3.2 et 5). **Le solo reste identique**, au recul du peintre près (Écart 4).

**Architecture:** `Scripts/Pastille.gd` (`class_name Pastille extends Area2D`) porte le gestionnaire `_on_body_entered` (branché dans chaque scène, inchangée), la garde hôte, le typage `body is Lion` et le premier arrivé ; chaque pastille ne définit plus que son effet (`_ramasser(joueur)`, les règles) et son apparence. La fin de vie d'une étoile ou d'un cœur ignoré passe par `_expirer()`, qui ne libère la pastille que sur l'hôte (en phase 14, sa disparition sera répliquée par le `MultiplayerSpawner` de la scène de jeu). `Audio` écoute quatre signaux du joueur local (`couleur_debloquee`, `crans_changes`, `bonus_change(true)`, `vies_changees` en hausse) et ne joue qu'un son de ramassage par frame. `Boss.origine_du_coup` prend la hauteur du centre du lion.

**Tech Stack:** Godot 4.7.2, GDScript typé, `SceneMultiplayer` / `ENetMultiplayerPeer` (sous-arbre client par `SceneTree.set_multiplayer`, comme la phase 8 ter), tests headless (`tests/smoke_test.gd`, `tests/unitaires.gd`, `tests/bataille_test.gd`, `tests/reseau/lancer.sh`).

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§2 pastilles « premier arrivé, premier servi », §3.1 unités `Lion` et `Regles` : les événements s'exécutent sur l'hôte, §10 smoke test) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 14 bis ; points de vigilance « phase 14 bis », « phase 14 bis (pastilles) », « phase 14 bis (qui touche `tests/smoke_test.gd`) », « phase 14 : unifier les sons de ramassage », « prochaine phase qui touche `Scripts/Boss.gd` ») · plan voisin : `docs/superpowers/plans/2026-09-25-phase-14-manche.md` (la manche synchronisée, exécutée après celui-ci) · prérequis : phase 13 fusionnée ; nouvelle branche `phase-14bis-pastilles` depuis `main`.

## Écarts assumés

1. **La phase 14 bis passe avant la 14**, dans son propre plan : elle est indépendante du réseau (aucune RPC, `config/version` inchangée), la phase 14 s'appuie sur elle (`Pastille._expirer`, les sections de contact du smoke test réécrites ici) et le plan réuni aurait dépassé 4 000 lignes. Son numéro reste « 14 bis » ; la Task 4 l'inscrit dans la feuille de route.
2. **Les sons de ramassage unifiés** (point « phase 14 » de la feuille de route) sont faits ici : ils retirent `Audio.jouer` des pastilles, que ce plan réécrit. Tout ramassage du joueur local joue le son de pastille par `Audio`, sur chaque poste : une couleur débloquée, un cran de gerbe (**nouveau en bataille**, où une pastille ne débloque aucune couleur et restait muette), la gerbe XXL qui commence, une vie regagnée. Une pastille du solo débloque une couleur ET donne un cran dans la même frame : un seul son par frame. Ce que ramasse un autre lion ne joue rien sur ce poste (c'était déjà le cas pour les pastilles de couleur ; l'étoile et le cœur jouaient leur son chez l'hôte, pour n'importe quel lion).
3. **Une vie regagnée est un `vies_changees` en hausse** par rapport à la dernière valeur vue par `Audio` ; `Joueur.reinitialiser` pose les vies sans signal, la référence est donc reprise au départ de chaque partie (`GameState.partie_prete`, émis à la fin de l'intro : aucune vie ne change avant). Pas de nouveau signal dans `Joueur`.
4. **Le recul du peintre est corrigé** : le durcissement demandé (« vérifier la direction du recul, horizontale, après le contact continu ») échoue sur le code actuel : `Boss.origine_du_coup` prend `lion.global_position.y`, le coin du lion, 66 px au-dessus de son centre ; le recul pointait donc vers le bas (vers la ville), et tout droit vers le bas pour un lion centré sous le peintre (mesuré en préparant ce plan : `(0.0, 220.0)`, tout droit vers le bas, au lieu d'un recul horizontal). L'origine prend maintenant `lion.global_position.y + Lion.CENTRE.y`, comme l'annonçait son docstring. Seul changement visible du solo ; **à signaler à l'utilisateur**.
5. **Pas de nettoyage préalable (« Step 0 »)** : les pastilles et `Audio.gd` (147 lignes) sont courts ; `tests/smoke_test.gd` reçoit des vérifications dans des sections existantes. Lire le smoke test par morceaux (`offset` / `limit`).

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), commandes depuis `~/Sites/LeLion-multi`, branche `phase-14bis-pastilles`.
- Fichiers de la phase : ➕ `Scripts/Pastille.gd` (+ `.uid` généré), ✏️ `Scripts/ColorPickup.gd`, ✏️ `Scripts/BonusPickup.gd`, ✏️ `Scripts/CoeurPickup.gd`, ✏️ `Scripts/Audio.gd`, ✏️ `Scripts/Boss.gd`, ✏️ `tests/smoke_test.gd` ; la feuille de route (Task 4). **Les scènes (`Scenes/*.tscn`), `Scripts/Reseau.gd`, `Scripts/Ennemi.gd`, `Scripts/Lion.gd`, `project.godot` et `.github/workflows/ci.yml` ne changent pas.**
- Identifiants, commentaires et messages de test en français, docstrings `##`, tabulations.
- **Aucune séquence d'échappement `\u…` n'est tapée dans un fichier** (l'outillage peut la changer en caractère invisible réel). Vérifier après chaque écriture : `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' <fichiers>` ne sort rien. (Le `\n` d'une chaîne GDScript, dans la Task 1, est un échappement ordinaire.)
- Un test `--script` est compilé **avant** les autoloads : il ne nomme ni `Lion`, ni `Ennemi`, ni `Pastille` (ces scripts nomment `GameState`, `Audio`) ; il type les lions en `Node` / `CharacterBody2D` et vérifie un héritage par `load(...).get_base_script().resource_path`.
- **Toujours lancer un test Godot avec `timeout`** et chercher les erreurs :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; O=""; timeout -k 5 300 godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd; O=""`, `T=tests/bataille_test.gd; O="--fixed-fps 60"` ; le test réseau : `timeout -k 5 300 bash tests/reseau/lancer.sh`). Une `SCRIPT ERROR` ne change pas le code de sortie : c'est elle, ou l'absence de la ligne `== n échec(s) ==`, qui fait l'échec. Après la création d'un script à `class_name` : `godot --headless --import .` avant les tests. Bruit connu du smoke test : `ERROR: Couldn't create an ENet host.` et deux `ERROR: The local port number must be between 0 and 65535 (inclusive).` (voulus), « ObjectDB instances were leaked », « resources still in use at exit ».
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`**.
- Les quatre suites se valident sur **5 passages consécutifs verts**, le test réseau sous bash 3.2 (`/bin/bash`, macOS) et bash 5.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).
- Mutations de preuve : seulement sur les fichiers de cette phase, déjà commités, annulées par `git checkout -- <fichier>` ; **jamais commitées**, jamais sur `Scripts/Reseau.gd`.

## Review Focus

1. **Un corps qui n'est pas un lion mais porte un `joueur` et le groupe « lion »** (un futur nœud de test, une réplique, un intrus) ramasserait une pastille sous l'ancien typage, pour un joueur qui n'a pas de lion. → « ColorPickup / BonusPickup / CoeurPickup : une pastille ignore un corps qui n'est pas un lion, même dans le groupe « lion » et avec un joueur » (Task 1) ; mutation P1.
2. **Une pastille ramassée ou libérée par un client** (en phase 14, chaque client aura des répliques) : double effet, ou disparition locale suivie d'une disparition répliquée d'un nœud déjà libéré. → « sur un client, une pastille au contact d'un lion n'est pas ramassée », « sur un client, une étoile en fin de vie ne se libère pas d'elle-même » (Task 1) ; mutations P2, P3.
3. **Deux sons pour une pastille, ou aucun** : le solo débloque une couleur et un cran dans la même frame ; la bataille ne débloque aucune couleur ; l'étoile d'un autre lion sonnait chez l'hôte. → « un seul son de ramassage », « en bataille, le cran d'une pastille … joue le son », « ce que ramasse un autre lion ne joue pas le son » (Task 2) ; mutations A1, A2.
4. **Un coup pris pour une vie regagnée** au départ d'une partie qui suit une défaite (vies remises à 3 sans signal, dernière valeur vue : 0) : le son de pastille sur un coup. → « un coup au départ d'une nouvelle partie … ne joue pas le son de ramassage » (Task 2) ; mutation A3.
5. **Le peintre qui pousse le lion dans la ville** : recul vers le bas au lieu de sur le côté. → « le recul est horizontal » (Task 3) ; mutation B1.

---

### Task 0 : vérifications

Ce plan est commité par le commit de planification de la phase 14 bis : ne pas le recommiter, **ne jamais le modifier**. Vérifier que la phase 13 est fusionnée : `grep -n "func configurer_bataille_reseau" Scripts/GameState.gd` et `grep -n "func lancer_manche" Scripts/Reseau.gd` trouvent chacun une ligne, `grep -c "SALON_DEMARRER" Assets/Traductions/traductions.csv` vaut 1, `grep -n 'config/version="0.13"' project.godot` trouve une ligne. Sinon, s'arrêter et le signaler. Les blocs « Remplacer » citent le code tel que la phase 13 l'a laissé (vérifié sur `origin/phase-13-salon`) : si l'ancre a bougé, adapter l'ancre au texte réel sans changer le remplacement, et le noter dans le rapport de la tâche.

Puis : `git switch -c phase-14bis-pastilles`.

---

### Task 1 : la base commune `Pastille`

**Files:**
- Create: `Scripts/Pastille.gd` (+ `Scripts/Pastille.gd.uid` généré)
- Modify: `Scripts/ColorPickup.gd`, `Scripts/BonusPickup.gd`, `Scripts/CoeurPickup.gd` (réécrits en entier)
- Test: `tests/smoke_test.gd` (section « Ennemis et pastilles signalent le lion qu'ils touchent », section « Base commune des ennemis », sous-arbre client, ville du client)

**Interfaces:**
- Consumes : `class_name Lion` (phase 8 bis), `Lion.joueur` ; `GameState.regles.pastille_ramassee(joueur, index)`, `etoile_ramassee(joueur)`, `coeur_ramasse(joueur)`, `GameState.couleur(index)`.
- Produces (phase 14) : `class_name Pastille extends Area2D` ; `func _on_body_entered(body: Node2D) -> void` (branché par les scènes, inchangées) ; `func _ramasser(joueur: Joueur) -> void` (virtuelle) ; `func _expirer() -> void` (libère la pastille sur l'hôte seulement) ; `var _ramassee := false`. `ColorPickup.couleur_index` inchangé.

- [ ] **Step 1 : le test**

Dans `tests/smoke_test.gd` :

1a. Remplacer :

```gdscript
	# Base commune des ennemis : seul un lion compte (`body is Lion`, pas le groupe « lion »), et
	# seul l'hôte tranche un contact
	var bases: Array = ["Soucoupe", "Coccinelle", "Boss"].map(func(nom: String) -> String:
		var base: Script = load("res://Scripts/%s.gd" % nom).get_base_script()
		return "" if base == null else base.resource_path)
	_check(bases.all(func(p: String) -> bool: return p == "res://Scripts/Ennemi.gd"),
		"soucoupe, coccinelle et peintre dérivent de la base Ennemi (%s)" % [bases])
	var intrus := CharacterBody2D.new()  # sur la couche 1 et dans le groupe « lion », mais pas un lion
	intrus.add_to_group("lion")
```

par :

```gdscript
	# Bases communes des ennemis et des pastilles : seul un lion compte (`body is Lion`, pas le
	# groupe « lion »), et seul l'hôte tranche un contact
	var bases: Array = ["Soucoupe", "Coccinelle", "Boss"].map(func(nom: String) -> String:
		var base: Script = load("res://Scripts/%s.gd" % nom).get_base_script()
		return "" if base == null else base.resource_path)
	_check(bases.all(func(p: String) -> bool: return p == "res://Scripts/Ennemi.gd"),
		"soucoupe, coccinelle et peintre dérivent de la base Ennemi (%s)" % [bases])
	var bases_pastilles: Array = ["ColorPickup", "BonusPickup", "CoeurPickup"].map(func(nom: String) -> String:
		var base: Script = load("res://Scripts/%s.gd" % nom).get_base_script()
		return "" if base == null else base.resource_path)
	_check(bases_pastilles.all(func(p: String) -> bool: return p == "res://Scripts/Pastille.gd"),
		"pastille de couleur, étoile et cœur dérivent de la base Pastille (%s)" % [bases_pastilles])
	# L'intrus a un champ `joueur`, comme un lion : sous l'ancien typage (groupe « lion » puis
	# `body.joueur`), il serait accepté.
	var script_intrus := GDScript.new()
	script_intrus.source_code = "extends CharacterBody2D\nvar joueur: Joueur = Joueur.new()\n"
	script_intrus.reload()
	var intrus := CharacterBody2D.new()  # sur la couche 1 et dans le groupe « lion », mais pas un lion
	intrus.set_script(script_intrus)
	intrus.add_to_group("lion")
```

1b. Remplacer :

```gdscript
	_check(soucoupe_intrus.get_overlapping_bodies().has(intrus) and autre.vies == 2 and local.vies == 2,
		"un ennemi ignore un corps qui n'est pas un lion, même dans le groupe « lion »")
	soucoupe_intrus.free()
	intrus.free()
```

par :

```gdscript
	_check(soucoupe_intrus.get_overlapping_bodies().has(intrus) and autre.vies == 2 and local.vies == 2
		and intrus.joueur.vies == 3 and not intrus.joueur.est_invulnerable(),
		"un ennemi ignore un corps qui n'est pas un lion, même dans le groupe « lion » et avec un joueur")
	soucoupe_intrus.free()
	for nom in ["ColorPickup", "BonusPickup", "CoeurPickup"]:
		var pastille_intrus: Area2D = load("res://Scenes/%s.tscn" % nom).instantiate()
		pastille_intrus.position = intrus.position
		root.add_child(pastille_intrus)
		await _frames(3)
		_check(is_instance_valid(pastille_intrus) and pastille_intrus.get_overlapping_bodies().has(intrus)
			and intrus.joueur.couleurs_debloquees.is_empty() and intrus.joueur.crans == 1 and not intrus.joueur.bonus_actif(),
			"%s : une pastille ignore un corps qui n'est pas un lion, même dans le groupe « lion » et avec un joueur" % nom)
		if is_instance_valid(pastille_intrus):
			pastille_intrus.free()
	intrus.free()
```

1c. Remplacer :

```gdscript
	var pair_client := ENetMultiplayerPeer.new()
	pair_client.create_client("127.0.0.1", 7779)  # jamais connecté : un client qui attend l'hôte
	api_client.multiplayer_peer = pair_client
```

par :

```gdscript
	var pair_client := ENetMultiplayerPeer.new()
	_check(pair_client.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client, jamais connecté : un client qui attend l'hôte")
	api_client.multiplayer_peer = pair_client
```

1d. Remplacer :

```gdscript
	_check(not coccinelle_client.multiplayer.is_server() and coccinelle_client.get_overlapping_bodies().has(lion_autre)
		and autre.vies == 2 and not autre.est_invulnerable(),
		"sur un client, un ennemi au contact d'un lion ne le signale pas aux règles (seul l'hôte tranche)")
```

par :

```gdscript
	_check(not coccinelle_client.multiplayer.is_server() and coccinelle_client.get_overlapping_bodies().has(lion_autre)
		and autre.vies == 2 and not autre.est_invulnerable(),
		"sur un client, un ennemi au contact d'un lion ne le signale pas aux règles (seul l'hôte tranche)")
	coccinelle_client.free()
	var crans_client := autre.crans
	var pastille_client: Area2D = load("res://Scenes/ColorPickup.tscn").instantiate()
	pastille_client.couleur_index = 6
	pastille_client.position = lion_autre.global_position + Vector2(68, 66)
	poste_client.add_child(pastille_client)
	var etoile_client: Area2D = load("res://Scenes/BonusPickup.tscn").instantiate()
	etoile_client.position = Vector2(-500, -500)
	poste_client.add_child(etoile_client)
	await _frames(3)
	_check(is_instance_valid(pastille_client) and pastille_client.get_overlapping_bodies().has(lion_autre)
		and not autre.couleurs_debloquees.has(GS.couleur(6)) and autre.crans == crans_client,
		"sur un client, une pastille au contact d'un lion n'est pas ramassée (seul l'hôte tranche)")
	if etoile_client.has_method("_expirer"):
		etoile_client._expirer()
	await _frames(1)
	_check(etoile_client.has_method("_expirer") and is_instance_valid(etoile_client),
		"sur un client, une étoile en fin de vie ne se libère pas d'elle-même (l'hôte la fait disparaître)")
```

1e. Remplacer :

```gdscript
	var pair_ville := ENetMultiplayerPeer.new()
	pair_ville.create_client("127.0.0.1", 7779)
	api_ville.multiplayer_peer = pair_ville
```

par :

```gdscript
	var pair_ville := ENetMultiplayerPeer.new()
	_check(pair_ville.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client pour la ville")
	api_ville.multiplayer_peer = pair_ville
```

- [ ] **Step 2 : le test échoue**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`.
Expected (mesuré) : `code 1`, `== 5 échec(s) ==` : `❌ pastille de couleur, étoile et cœur dérivent de la base Pastille (["", "", ""])`, les trois `❌ … : une pastille ignore un corps qui n'est pas un lion, même dans le groupe « lion » et avec un joueur` (l'ancien gestionnaire accepte l'intrus et lui donne couleur, gerbe XXL ou vie) et `❌ sur un client, une étoile en fin de vie ne se libère pas d'elle-même` (pas encore de `_expirer` : le test ne l'appelle que s'il existe, sans quoi la `SCRIPT ERROR` arrêterait le smoke test jusqu'à son `timeout`).

- [ ] **Step 3 : la base et les trois pastilles**

3a. Créer `Scripts/Pastille.gd` :

```gdscript
class_name Pastille
extends Area2D
## Base des pastilles (couleur, étoile, cœur) : leur gestionnaire de contact commun. Un contact
## n'est tranché que par l'hôte (en solo, le poste est son propre hôte), ne compte que pour un
## lion (`body is Lion`, pas le groupe « lion », qui ne sert plus qu'au Spawner), et une pastille
## ne sert qu'une fois : premier arrivé, premier servi (deux lions qui la touchent dans la même
## frame : `queue_free()` est différé). L'effet est décidé par les règles (`_ramasser`, que chaque
## pastille définit) ; le son de ramassage est joué par `Audio`, sur un signal du joueur local, sur
## chaque poste. Sur un client, une pastille n'est qu'une réplique de celle de l'hôte (apparue par
## le `MultiplayerSpawner` de la scène de jeu) : elle ne se libère jamais d'elle-même (`_expirer`),
## c'est l'hôte qui la fait disparaître chez tous.

var _ramassee := false


## Branché sur `body_entered` dans la scène de chaque pastille.
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server() or _ramassee or not (body is Lion):
		return
	_ramassee = true
	var lion: Lion = body
	_ramasser(lion.joueur)
	queue_free()


## L'effet de la pastille pour le joueur du lion qui la ramasse : celui des règles de la partie.
func _ramasser(_joueur: Joueur) -> void:
	pass


## Fin de vie d'une pastille que personne n'a ramassée : l'hôte la libère (sa disparition est
## répliquée chez les clients) ; une réplique attend l'hôte.
func _expirer() -> void:
	if multiplayer.is_server():
		queue_free()
```

3b. Remplacer tout `Scripts/ColorPickup.gd` par :

```gdscript
extends Pastille
## Pastille de couleur ; son effet dépend des règles (en solo, une couleur de l'arc-en-ciel, en
## bataille un cran de gerbe).

@export var couleur_index: int = 0


func _ready() -> void:
	$Sprite2D.modulate = GameState.couleur(couleur_index)


func _ramasser(joueur: Joueur) -> void:
	GameState.regles.pastille_ramassee(joueur, couleur_index)
```

3c. Remplacer tout `Scripts/BonusPickup.gd` par :

```gdscript
extends Pastille
## Étoile arc-en-ciel : double le rayon de la gerbe pendant quelques secondes.
## Disparaît d'elle-même si personne ne la ramasse.

const DUREE_DE_VIE := 7.0

@onready var sprite: Sprite2D = $Sprite2D

var _temps := 0.0


func _ready() -> void:
	var tween := create_tween()
	tween.tween_interval(DUREE_DE_VIE - 1.5)
	tween.tween_property(sprite, "modulate:a", 0.0, 1.5)
	tween.tween_callback(_expirer)


func _process(delta: float) -> void:
	_temps += delta
	sprite.modulate = Color.from_hsv(fmod(_temps * 0.6, 1.0), 0.8, 1.0, sprite.modulate.a)
	sprite.scale = Vector2.ONE * (1.2 + 0.15 * sin(_temps * 6.0))
	sprite.rotation = _temps * 1.5


func _ramasser(joueur: Joueur) -> void:
	GameState.regles.etoile_ramassee(joueur)
```

3d. Remplacer tout `Scripts/CoeurPickup.gd` par :

```gdscript
extends Pastille
## Cœur à ramasser (mode Facile) : rend une vie. Bat doucement et s'efface s'il est ignoré.

const DUREE_DE_VIE := 9.0

@onready var sprite: Sprite2D = $Sprite2D

var _temps := 0.0


func _ready() -> void:
	var tween := create_tween()
	tween.tween_interval(DUREE_DE_VIE - 1.5)
	tween.tween_property(sprite, "modulate:a", 0.0, 1.5)
	tween.tween_callback(_expirer)


func _process(delta: float) -> void:
	_temps += delta
	sprite.scale = Vector2.ONE * (1.0 + 0.12 * max(0.0, sin(_temps * 5.0)))


func _ramasser(joueur: Joueur) -> void:
	GameState.regles.coeur_ramasse(joueur)
```

L'étoile et le cœur ne jouent plus `Audio.jouer("pickup")` : la Task 2 le fait jouer par `Audio`. D'ici là, seul leur son manque (aucun test ne le vérifie encore).

3e. `export PATH="/opt/homebrew/bin:$PATH"; timeout -k 5 120 godot --headless --import . > "$TMPDIR/i.log" 2>&1; grep -E "SCRIPT ERROR|Parse Error" "$TMPDIR/i.log"` ne sort rien (la classe `Pastille` enregistrée).

- [ ] **Step 4 : le test passe**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`, puis `T=tests/bataille_test.gd; O="--fixed-fps 60"` (les pastilles de la manche à 4).
Expected : `code 0`, `== 0 échec(s) ==` pour les deux, dont « pastille de couleur, étoile et cœur dérivent de la base Pastille », les trois « une pastille ignore un corps qui n'est pas un lion… », « sur un client, une pastille au contact d'un lion n'est pas ramassée », « sur un client, une étoile en fin de vie ne se libère pas d'elle-même », et toujours « premier arrivé, premier servi : un seul lion profite d'un cœur touché par deux lions ».

- [ ] **Step 5 : Commit, puis le test discrimine**

```bash
git add Scripts/Pastille.gd Scripts/Pastille.gd.uid Scripts/ColorPickup.gd Scripts/BonusPickup.gd Scripts/CoeurPickup.gd tests/smoke_test.gd
git commit -m "Pastilles : base commune Pastille (garde hôte, body is Lion, premier arrivé premier servi, une réplique ne se libère pas d'elle-même) ; smoke test : héritage, intrus du groupe « lion » avec un joueur, pastilles inertes sur un client, pairs clients vérifiés

<ligne fournie par l'environnement>"
```

Puis chaque mutation seule, `T=tests/smoke_test.gd` (`grep -E "❌|SCRIPT ERROR"`), et **`git checkout -- Scripts/Pastille.gd`** avant la suivante (mesuré en préparant le plan) :
- P1 (l'ancien typage) : dans `_on_body_entered`, `not (body is Lion)` → `not body.is_in_group("lion")`, et les deux lignes `var lion: Lion = body` / `_ramasser(lion.joueur)` → `_ramasser(body.joueur)` ⇒ les trois `❌ … : une pastille ignore un corps qui n'est pas un lion…` ;
- P2 : `if not multiplayer.is_server() or _ramassee` → `if _ramassee` ⇒ `❌ sur un client, une pastille au contact d'un lion n'est pas ramassée (seul l'hôte tranche)` ;
- P3 : dans `_expirer`, retirer la condition (toujours `queue_free()`) ⇒ `❌ sur un client, une étoile en fin de vie ne se libère pas d'elle-même (l'hôte la fait disparaître)`.

Expected ensuite : `git status --short` vide.

---

### Task 2 : les sons de ramassage par `Audio`

**Files:**
- Modify: `Scripts/Audio.gd` (variables du joueur écouté, `_ready`, `_ecouter`, gestionnaires)
- Test: `tests/smoke_test.gd` (en-tête, `_run`, sections pastille, étoile, cœur, Métropole, ennemis et pastilles, bataille)

**Interfaces:**
- Consumes : signaux de `Joueur` : `couleur_debloquee(couleur)`, `crans_changes(crans)`, `bonus_change(actif)`, `vies_changees(vies)` ; `GameState.partie_prete`, `GameState.joueur_local_change` ; Task 1.
- Produces : `Audio._jouer_ramassage()` (un son de pastille par frame au plus) ; `var _vies_vues`, `var _ramassage_joue_a` ; test : `var _sons: Array[String]` et `func _noter_son(noeud)` du smoke test (noms des sons joués par `Audio`).

- [ ] **Step 1 : le test**

Dans `tests/smoke_test.gd` :

1a. Remplacer :

```gdscript
var _echecs := 0
var GS: Node
var JL: Joueur  # le joueur local (unique en solo)
```

par :

```gdscript
var _echecs := 0
var GS: Node
var JL: Joueur  # le joueur local (unique en solo)
## Les sons joués par `Audio` (un lecteur par son, ajouté comme enfant), par nom de fichier :
## `_sons.count("pickup")` compte les sons de ramassage.
var _sons: Array[String] = []
```

1b. Remplacer :

```gdscript
## La couleur telle qu'une image RGBA8 la stocke, en `to_rgba32()`.
```

par :

```gdscript
## Chaque lecteur ajouté à `Audio` : le nom du son qu'il joue (voir `_sons`).
func _noter_son(noeud: Node) -> void:
	if noeud is AudioStreamPlayer and noeud.stream != null:
		_sons.append(noeud.stream.resource_path.get_file().get_basename())


## La couleur telle qu'une image RGBA8 la stocke, en `to_rgba32()`.
```

1c. Remplacer :

```gdscript
	scores.effacer()
	params.definir_langue("fr")

	# Traductions et réglages
```

par :

```gdscript
	scores.effacer()
	params.definir_langue("fr")
	root.get_node("Audio").child_entered_tree.connect(_noter_son)

	# Traductions et réglages
```

1d. Remplacer :

```gdscript
	# Pickup : le lion marche dessus
	var pickup: Node = spawner.spawn_pickup(0, lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(pickup), "le pickup disparaît au contact")
```

par :

```gdscript
	# Pickup : le lion marche dessus
	var sons_avant := _sons.count("pickup")
	var pickup: Node = spawner.spawn_pickup(0, lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(pickup), "le pickup disparaît au contact")
	_check(_sons.count("pickup") == sons_avant + 1 and JL.crans == 2,
		"une pastille du solo débloque une couleur et donne un cran : un seul son de ramassage (%d)" % (_sons.count("pickup") - sons_avant))
```

1e. Remplacer :

```gdscript
	var rayon_normal: float = lion.traceuse_shape.shape.radius
	var bonus: Node = spawner.spawn_bonus(lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(bonus) and JL.bonus_actif(), "l'étoile ramassée active la gerbe XXL")
```

par :

```gdscript
	var rayon_normal: float = lion.traceuse_shape.shape.radius
	sons_avant = _sons.count("pickup")
	var bonus: Node = spawner.spawn_bonus(lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(bonus) and JL.bonus_actif(), "l'étoile ramassée active la gerbe XXL")
	_check(_sons.count("pickup") == sons_avant + 1, "l'étoile joue le son de ramassage, par Audio (%d)" % (_sons.count("pickup") - sons_avant))
```

1f. Remplacer :

```gdscript
	# Cœur : rend une vie, jamais au-delà du maximum
	var coeur: Node = spawner.spawn_coeur(lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(coeur) and JL.vies == 3, "un cœur ramassé rend une vie (%d)" % JL.vies)
```

par :

```gdscript
	# Cœur : rend une vie, jamais au-delà du maximum
	sons_avant = _sons.count("pickup")
	var coeur: Node = spawner.spawn_coeur(lion.global_position + Vector2(68, 66))
	await _frames(3)
	_check(not is_instance_valid(coeur) and JL.vies == 3, "un cœur ramassé rend une vie (%d)" % JL.vies)
	_check(_sons.count("pickup") == sons_avant + 1, "le cœur joue le son de ramassage, par Audio (%d)" % (_sons.count("pickup") - sons_avant))
```

1g. Remplacer :

```gdscript
	_check(JL.vies == 3 and JL.coups_recus == 0 and main.get_node("HUD")._coeurs[2].modulate == main.get_node("HUD").COULEUR_COEUR,
		"après une défaite, le niveau suivant repart avec tous ses cœurs affichés")
```

par :

```gdscript
	_check(JL.vies == 3 and JL.coups_recus == 0 and main.get_node("HUD")._coeurs[2].modulate == main.get_node("HUD").COULEUR_COEUR,
		"après une défaite, le niveau suivant repart avec tous ses cœurs affichés")
	# La défaite a laissé 0 vie ; `nouvelle_partie` en a remis 3 sans signal : un coup (3 → 2) n'est
	# pas une vie regagnée.
	sons_avant = _sons.count("pickup")
	JL.encaisser_coup(Vector2.INF, 0.0)
	_check(JL.vies == 2 and _sons.count("pickup") == sons_avant,
		"un coup au départ d'une nouvelle partie (vies remises sans signal) ne joue pas le son de ramassage")
	JL.vies = 3
	JL.coups_recus = 0
```

1h. Remplacer :

```gdscript
	var pastille_autre: Node2D = load("res://Scenes/ColorPickup.tscn").instantiate()
	pastille_autre.couleur_index = 4  # autre n'a que le rouge
	pastille_autre.position = centre_autre
	root.add_child(pastille_autre)
```

par :

```gdscript
	var pastille_autre: Node2D = load("res://Scenes/ColorPickup.tscn").instantiate()
	pastille_autre.couleur_index = 4  # autre n'a que le rouge
	pastille_autre.position = centre_autre
	var sons_locaux := _sons.count("pickup")
	root.add_child(pastille_autre)
```

1i. Remplacer :

```gdscript
	_check(not is_instance_valid(etoile_autre) and autre.bonus_actif()
		and is_equal_approx(autre.bonus_restant, Regles.DUREE_ETOILE) and local.bonus_actif() == bonus_local,
		"une étoile ramassée par un lion active la gerbe XXL de son joueur, pas celle du joueur local")
```

par :

```gdscript
	_check(not is_instance_valid(etoile_autre) and autre.bonus_actif()
		and is_equal_approx(autre.bonus_restant, Regles.DUREE_ETOILE) and local.bonus_actif() == bonus_local,
		"une étoile ramassée par un lion active la gerbe XXL de son joueur, pas celle du joueur local")
	_check(_sons.count("pickup") == sons_locaux, "ce que ramasse un autre lion ne joue pas le son de ramassage de ce poste")
```

1j. Remplacer :

```gdscript
	GS.regles.pastille_ramassee(j_rouge, 0)
	_check(lr.traceuse_shape.shape.radius == 21.0 and lb.traceuse_shape.shape.radius == 16.0, "une pastille donne un cran : 5 px de plus, pour ce lion seulement")
```

par :

```gdscript
	var sons_bataille := _sons.count("pickup")
	GS.regles.pastille_ramassee(j_rouge, 0)
	_check(lr.traceuse_shape.shape.radius == 21.0 and lb.traceuse_shape.shape.radius == 16.0, "une pastille donne un cran : 5 px de plus, pour ce lion seulement")
	_check(GS.joueur_local() == j_rouge and _sons.count("pickup") == sons_bataille + 1,
		"en bataille, le cran d'une pastille (aucune couleur débloquée) joue le son de ramassage du joueur local")
```

- [ ] **Step 2 : le test échoue**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`.
Expected (mesuré) : `code 1`, `❌ l'étoile joue le son de ramassage, par Audio (0)`, `❌ le cœur joue le son de ramassage, par Audio (0)` (Task 1 a retiré leur `Audio.jouer`) et `❌ en bataille, le cran d'une pastille (aucune couleur débloquée) joue le son de ramassage du joueur local` ; les autres vérifications de son passent déjà (le son de la couleur existe, celui de l'autre lion n'existe plus).

- [ ] **Step 3 : `Audio`**

Dans `Scripts/Audio.gd` :

3a. Remplacer :

```gdscript
## Le joueur local, dont chaque couleur débloquée joue le son de pastille. Suivi pour toute la
## session : il change sur un client réseau et au retour au solo (`GameState.joueur_local_change`).
var _joueur_ecoute: Joueur
```

par :

```gdscript
## Le joueur local, dont chaque ramassage joue le son de pastille (couleur débloquée, cran de gerbe,
## gerbe XXL, vie regagnée), sur chaque poste : en réseau, ses signaux partent aussi chez un client
## (les réactions du joueur répliquées par la manche). Suivi pour toute la session : il change sur
## un client réseau et au retour au solo (`GameState.joueur_local_change`).
var _joueur_ecoute: Joueur
## Vies du joueur écouté à son dernier `vies_changees` (ou au départ de la partie, que
## `Joueur.reinitialiser` pose sans signal) : une vie regagnée est un `vies_changees` en hausse.
var _vies_vues := 0
## Frame du dernier son de ramassage : une pastille du solo débloque une couleur ET donne un cran
## dans la même frame, un seul son part.
var _ramassage_joue_a := -1
```

3b. Remplacer :

```gdscript
	_ecouter(GameState.joueur_local())
	GameState.joueur_local_change.connect(_ecouter)
	GameState.partie_terminee.connect(_on_partie_terminee)
```

par :

```gdscript
	_ecouter(GameState.joueur_local())
	GameState.joueur_local_change.connect(_ecouter)
	GameState.partie_prete.connect(_on_partie_prete)
	GameState.partie_terminee.connect(_on_partie_terminee)
```

3c. Remplacer :

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
```

par :

```gdscript
## Écoute le joueur local `joueur` à la place du précédent.
func _ecouter(joueur: Joueur) -> void:
	if _joueur_ecoute != null:
		_joueur_ecoute.couleur_debloquee.disconnect(_on_couleur_debloquee)
		_joueur_ecoute.crans_changes.disconnect(_on_crans_changes)
		_joueur_ecoute.bonus_change.disconnect(_on_bonus_change)
		_joueur_ecoute.vies_changees.disconnect(_on_vies_changees)
	_joueur_ecoute = joueur
	_vies_vues = joueur.vies
	joueur.couleur_debloquee.connect(_on_couleur_debloquee)
	joueur.crans_changes.connect(_on_crans_changes)
	joueur.bonus_change.connect(_on_bonus_change)
	joueur.vies_changees.connect(_on_vies_changees)


## Son de pastille, une fois par frame au plus : le joueur local vient de ramasser quelque chose.
func _jouer_ramassage() -> void:
	if _ramassage_joue_a == Engine.get_process_frames():
		return
	_ramassage_joue_a = Engine.get_process_frames()
	jouer("pickup")


func _on_couleur_debloquee(_couleur: Color) -> void:
	_jouer_ramassage()


## Une pastille de bataille donne un cran sans débloquer de couleur.
func _on_crans_changes(_crans: int) -> void:
	_jouer_ramassage()


## L'étoile : la gerbe XXL commence (sa fin, `actif` faux, ne joue rien).
func _on_bonus_change(actif: bool) -> void:
	if actif:
		_jouer_ramassage()


## Le cœur : une vie de plus. Un coup (vies en baisse) joue son propre son (`Lion`).
func _on_vies_changees(vies: int) -> void:
	if vies > _vies_vues:
		_jouer_ramassage()
	_vies_vues = vies


## Départ d'une partie : `nouvelle_partie` a remis les vies sans signal.
func _on_partie_prete() -> void:
	_vies_vues = _joueur_ecoute.vies
```

- [ ] **Step 4 : le test passe**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`, puis `T=tests/unitaires.gd` (le joueur local se réabonne) et `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected : `code 0`, `== 0 échec(s) ==` pour les trois, dont « une pastille du solo … : un seul son de ramassage (1) », « l'étoile joue le son de ramassage, par Audio (1) », « le cœur … (1) », « un coup au départ d'une nouvelle partie … ne joue pas le son de ramassage », « ce que ramasse un autre lion ne joue pas le son de ramassage de ce poste », « en bataille, le cran d'une pastille … joue le son de ramassage du joueur local ». `grep -n 'Audio.jouer("pickup")' Scripts/*.gd` ne trouve plus que `Scripts/GameOver.gd` et `Scripts/Reglages.gd` (le bilan et l'essai du volume des effets).

- [ ] **Step 5 : Commit, puis le test discrimine**

```bash
git add Scripts/Audio.gd tests/smoke_test.gd
git commit -m "Audio : un seul son de ramassage par frame, sur les signaux du joueur local (couleur, cran, gerbe XXL, vie regagnée), sur chaque poste ; plus de son dans les pastilles ; smoke test

<ligne fournie par l'environnement>"
```

Puis chaque mutation seule sur `Scripts/Audio.gd`, `T=tests/smoke_test.gd`, et **`git checkout -- Scripts/Audio.gd`** avant la suivante (mesuré) :
- A1 : dans `_jouer_ramassage`, retirer les deux lignes `if _ramassage_joue_a == …` / `return` ⇒ `❌ une pastille du solo débloque une couleur et donne un cran : un seul son de ramassage (2)` ;
- A2 : retirer la ligne `joueur.crans_changes.connect(_on_crans_changes)` ⇒ `❌ en bataille, le cran d'une pastille (aucune couleur débloquée) joue le son de ramassage du joueur local` (plus des lignes `ERROR: Attempt to disconnect a nonexistent connection` au changement de joueur local, sans `SCRIPT ERROR`) ;
- A3 : retirer la ligne `GameState.partie_prete.connect(_on_partie_prete)` ⇒ `❌ un coup au départ d'une nouvelle partie (vies remises sans signal) ne joue pas le son de ramassage`.

Expected ensuite : `git status --short` vide.

---

### Task 3 : le recul du peintre, et les durcissements du smoke test

**Files:**
- Modify: `Scripts/Boss.gd` (`acceleration_max`, `origine_du_coup`)
- Test: `tests/smoke_test.gd` (section « Boss sur le niveau Village »)

**Interfaces:**
- Consumes : `Lion.CENTRE` (phase 8 bis), `Lion._reculer(origine)` (repli horizontal quand l'origine est au centre du lion).
- Produces : `Boss.origine_du_coup(lion) -> Vector2(global_position.x, lion.global_position.y + Lion.CENTRE.y)`.

- [ ] **Step 1 : le test**

Dans `tests/smoke_test.gd` :

1a. Remplacer :

```gdscript
	# Les deux chemins de contact du peintre : body_entered, puis le contact continu hors repos.
	# Un lion resté à son contact est frappé dès la fin de son invulnérabilité, sans nouveau
	# body_entered ; le coup part de la verticale du peintre, à la hauteur du lion.
	_check(boss.origine_du_coup(lion) == Vector2(boss.global_position.x, lion.global_position.y),
		"le coup du peintre part de sa verticale, à la hauteur du lion")
	boss._arreter()
```

par :

```gdscript
	# Les deux chemins de contact du peintre : body_entered, puis le contact continu hors repos.
	# Un lion resté à son contact est frappé dès la fin de son invulnérabilité, sans nouveau
	# body_entered ; le coup part de la verticale du peintre, à la hauteur du lion : le recul est
	# horizontal.
	boss._arreter()
```

1b. Remplacer :

```gdscript
	_check(JL.vies == 2, "un lion resté au contact du peintre est frappé dès la fin de son invulnérabilité (contact continu)")
	GS.niveau_courant = 0
```

par :

```gdscript
	_check(JL.vies == 2, "un lion resté au contact du peintre est frappé dès la fin de son invulnérabilité (contact continu)")
	_check(lion._recul.length() > 0.0 and absf(lion._recul.normalized().y) < 0.01,
		"le coup du peintre part de sa verticale, à la hauteur du lion : le recul est horizontal (%s)" % lion._recul)
	boss.etat = boss.Etat.REPOS  # au repos, hors de l'écran : il ne touche plus rien
	boss.position.x = boss._x_hors_ecran()
	GS.niveau_courant = 0
```

- [ ] **Step 2 : le test échoue**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`.
Expected (mesuré) : `code 1`, `== 1 échec(s) ==` : `❌ le coup du peintre part de sa verticale, à la hauteur du lion : le recul est horizontal ((0.0, 220.0))` (la valeur exacte dépend du temps écoulé depuis le coup ; x nul, y positif) : l'origine du coup est au coin du lion, 66 px au-dessus de son centre (Écart 4).

- [ ] **Step 3 : `Boss`**

Dans `Scripts/Boss.gd` :

3a. Remplacer :

```gdscript
@export var acceleration_max := 0.65     # facteur de durée quand la ville est presque peinte
```

par :

```gdscript
@export var acceleration_max := 0.65     # facteur de durée en fin de partie (avancement des règles)
```

3b. Remplacer :

```gdscript
## Le coup du peintre part de sa verticale, à la hauteur du lion (et non de son centre, bien plus
## haut ou plus bas que le lion) : le lion est repoussé sur le côté.
func origine_du_coup(lion: Lion) -> Vector2:
	return Vector2(global_position.x, lion.global_position.y)
```

par :

```gdscript
## Le coup du peintre part de sa verticale, à la hauteur du centre du lion (et non du centre du
## peintre, bien plus haut ou plus bas) : le lion est repoussé sur le côté, jamais vers le bas.
## `lion.global_position` est le coin du lion : sans `Lion.CENTRE.y`, le recul pointait vers le bas
## (vers la ville), et tout droit vers le bas pour un lion centré sur le peintre.
func origine_du_coup(lion: Lion) -> Vector2:
	return Vector2(global_position.x, lion.global_position.y + Lion.CENTRE.y)
```

- [ ] **Step 4 : le test passe**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`, puis `T=tests/bataille_test.gd; O="--fixed-fps 60"` (le peintre de la manche à 4, ses mesures).
Expected : `code 0`, `== 0 échec(s) ==` pour les deux, dont « le coup du peintre part de sa verticale, à la hauteur du lion : le recul est horizontal ((-220.0, 0.0)) » (mesuré ; le repli horizontal de `Lion._reculer`, le lion étant centré sous le peintre) et, dans `tests/bataille_test.gd`, les vérifications du peintre inchangées.

- [ ] **Step 5 : Commit, puis le test discrimine, puis les suites 5 fois**

```bash
git add Scripts/Boss.gd tests/smoke_test.gd
git commit -m "Peintre : le coup part à la hauteur du centre du lion (le recul était dirigé vers la ville) ; smoke test : recul horizontal vérifié après le contact continu, peintre remis au repos

<ligne fournie par l'environnement>"
```

Puis la mutation B1 sur `Scripts/Boss.gd` : `lion.global_position.y + Lion.CENTRE.y` → `lion.global_position.y` ⇒ `❌ … le recul est horizontal ((0.0, 220.0))` ; **`git checkout -- Scripts/Boss.gd`**.

Puis 5 fois de suite chacune des trois suites Godot et `bash tests/reseau/lancer.sh`, puis 5 fois `/bin/bash tests/reseau/lancer.sh`.
Expected : chaque fois `code 0` et `== 0 échec(s) ==`, aucune `SCRIPT ERROR` ni `SHADER ERROR` ; `git status --short` vide.

---

### Task 4 : feuille de route

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`

**Interfaces:**
- Consumes : Tasks 1 à 3, Écarts 1 à 4 ; la feuille de route telle que la phase 13 l'a laissée (ancres ci-dessous vérifiées sur `origin/phase-13-salon`).
- Produces : plus aucun point « phase 14 bis » ; le point des sons de ramassage résolu ; celui de `Boss.gd` résolu.

- [ ] **Step 1 : la ligne 14 bis**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` :

Remplacer :

```markdown
| 14 bis | **Pastilles vers `body is Lion`** : base commune des trois pastilles (garde hôte, `body is Lion`, premier arrivé, premier servi). | ➕ `Scripts/Pastille.gd` ✏️ `Scripts/ColorPickup.gd` ✏️ `Scripts/BonusPickup.gd` ✏️ `Scripts/CoeurPickup.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
```

par :

```markdown
| 14 bis | **Pastilles vers `body is Lion`** (exécutée avant la 14) : base commune des trois pastilles (garde hôte, `body is Lion`, premier arrivé, premier servi, une réplique ne se libère pas d'elle-même : `_expirer`), sons de ramassage par `Audio` et les signaux du joueur local (un par frame, le cran de bataille compris), recul du peintre horizontal (il pointait vers la ville), durcissements du smoke test de la revue 8 ter. | ➕ `Scripts/Pastille.gd` ✏️ `Scripts/ColorPickup.gd` ✏️ `Scripts/BonusPickup.gd` ✏️ `Scripts/CoeurPickup.gd` ✏️ `Scripts/Audio.gd` ✏️ `Scripts/Boss.gd` ✏️ `tests/smoke_test.gd` | smoke vert, suites vertes 5 fois |
```

- [ ] **Step 2 : les points de vigilance**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` :

2a. Remplacer :

```markdown
- phase 14 : unifier les sons de ramassage. L'étoile et le cœur jouent leur son dans le gestionnaire
  réservé à l'hôte (un client n'entendrait rien) alors que la pastille passe par `Audio` et le signal
  du joueur local : tout passer par `Audio` et les signaux du joueur local (`bonus_change(true)`,
  `vies_changees` en hausse) et retirer `Audio.jouer` des pastilles ;
- **phase 14 bis** : le gestionnaire de contact est copié dans `ColorPickup`, `BonusPickup` et
  `CoeurPickup` ; en faire une base commune `Pastille` (garde hôte, `body is Lion`, premier
  arrivé, premier servi). La désapparition répliquée reste à la phase 14 ;
```

par :

```markdown
- (résolu en phase 14 bis, réaffecté de la phase 14) sons de ramassage : tout passe par `Audio` et
  les signaux du joueur local, sur chaque poste (`couleur_debloquee`, `crans_changes`,
  `bonus_change(true)`, `vies_changees` en hausse, la référence des vies reprise à `partie_prete`),
  un son par frame au plus ; les pastilles ne jouent plus rien ;
- (résolu en phase 14 bis) base commune `Pastille` (garde hôte, `body is Lion`, premier arrivé,
  premier servi) ; la fin de vie d'une étoile ou d'un cœur passe par `Pastille._expirer`, qui ne
  libère la pastille que sur l'hôte. **Phase 14** : la disparition répliquée (le `MultiplayerSpawner`
  de la scène de jeu) s'appuie dessus ;
```

2b. Remplacer :

```markdown
- **phase 14 bis (pastilles)** : comme la base `Ennemi` de la phase 8 ter (`Scripts/Ennemi.gd`),
  tester `body is Lion` dans le gestionnaire de contact commun au lieu de supposer `body.joueur`.
  Les tests `--script` (compilés avant les autoloads) continuent de typer les lions en `Node` /
  `CharacterBody2D`, et ne nomment ni `Lion`, ni `Ennemi`, ni `Pastille` : ces scripts nomment
  `GameState` (`Lion.gd` aussi `Audio`). Le smoke test vérifie l'héritage d'un script par
  `load(...).get_base_script().resource_path`. Le groupe « lion » ne sert alors plus qu'au
  Spawner ;
```

par :

```markdown
- (résolu en phase 14 bis) `body is Lion` dans le gestionnaire commun des pastilles ; les tests
  `--script` ne nomment ni `Lion`, ni `Ennemi`, ni `Pastille` et vérifient l'héritage par
  `load(...).get_base_script().resource_path` ; le groupe « lion » ne sert plus qu'au Spawner ;
```

2c. Remplacer :

```markdown
- **phase 14 bis** (qui touche `tests/smoke_test.gd` ; la phase 12 bis, première à y revenir, les a
  laissés à la phase qui réécrit ces sections de contact) : petits durcissements issus de la revue de
  la phase 8 ter : vérifier que `create_client` renvoie `OK` avant le test de la garde hôte ;
  donner à l'intrus du groupe « lion » un script avec un champ `joueur` pour que la vérification
  échoue d'elle-même sous l'ancien typage ; vérifier la direction du recul (horizontale) après le
  contact continu du peintre au lieu d'appeler `origine_du_coup` directement ; remettre le peintre
  au repos après sa vérification ;
```

par :

```markdown
- (résolu en phase 14 bis) durcissements de la revue 8 ter : `create_client` vérifié `OK`, intrus
  du groupe « lion » avec un champ `joueur` (ennemis et pastilles), recul du peintre vérifié
  horizontal après le contact continu, peintre remis au repos. Le recul vérifié a révélé un défaut :
  `Boss.origine_du_coup` prenait la hauteur du coin du lion (66 px au-dessus de son centre) et
  poussait le lion vers la ville ; corrigé (`lion.global_position.y + Lion.CENTRE.y`) ;
```

2d. Remplacer :

```markdown
- prochaine phase qui touche `Scripts/Boss.gd` : le commentaire de `acceleration_max` (« quand la
  ville est presque peinte ») date d'avant la phase 10 bis : « facteur de durée en fin de partie
  (avancement des règles) » ;
```

par :

```markdown
- (résolu en phase 14 bis) le commentaire de `Boss.acceleration_max` suit l'avancement des règles ;
```

- [ ] **Step 3 : Commit**

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
git commit -m "Feuille de route : phase 14 bis faite avant la 14 (base Pastille, sons de ramassage par Audio, recul du peintre horizontal, durcissements du smoke test) ; points de vigilance résolus

<ligne fournie par l'environnement>"
```

---

## Sortie de phase

- Les quatre suites vertes 5 fois de suite localement (test réseau sous bash 3.2 et 5), sans `SCRIPT ERROR` ni `SHADER ERROR`, puis le job CI vert sur la PR.
- Les preuves P1 à P3, A1 à A3 et B1 ont donné les `❌` attendus.
- `git diff main --stat` : les 7 fichiers des Global Constraints, `Scripts/Pastille.gd.uid` et la feuille de route ; `git diff main --stat -- Scenes/ Scripts/Reseau.gd Scripts/Ennemi.gd Scripts/Lion.gd project.godot` vide.
- Rappeler à l'utilisateur : le recul du peintre change en solo (Écart 4 : sur le côté au lieu de vers la ville) ; en bataille, une pastille joue désormais le son de ramassage (Écart 2).
