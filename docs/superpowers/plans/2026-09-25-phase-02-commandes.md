# Phase 2 : Commandes et lion par joueur, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Le lion ne lit plus ni `Input` ni l'état du singleton : il porte son `Joueur` et une source d'intentions `Commandes`, sans aucun changement de comportement du solo.

**Architecture:** `Commandes` (RefCounted, `class_name Commandes`) expose `direction()` et `vomir()` et a deux sources : `LOCALES` (actions InputMap de ce poste, clavier, manette ou tactile) et `MANUELLES` (valeurs écrites par un tiers : pilote de démo, tests, et plus tard le réseau). Le lion reçoit `joueur` et `commandes` avant son entrée dans l'arbre, ou prend par défaut le joueur local et ses commandes (manuelles en démo, locales sinon). Il s'abonne aux signaux de **son** joueur. Le pilote écrit dans les commandes manuelles du lion.

**Tech Stack:** Godot 4.7.2, GDScript typé, tests headless.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (section 3.1, unités `Commandes` et `Lion`) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (phase 2)

**Écart assumé avec le spec** (spec mis à jour dans le même commit que ce plan) : une seule classe `Commandes` à deux sources au lieu de trois sous-classes. Une classe interne GDScript ne peut pas proprement hériter de la classe `class_name` qui la contient, et trois fichiers dépasseraient le plafond de 5 fichiers de la phase. Les commandes réseau (phase 14) seront des commandes manuelles écrites par le gestionnaire de RPC ; la numérotation et la redondance (phase 16) s'ajouteront par-dessus. La méthode s'appelle `vomir()` (et non `vomit()`), comme l'action InputMap.

## Global Constraints

- Godot 4.7.2 (`/opt/homebrew/bin/godot` en local, `GODOT_VERSION: 4.7.2` en CI).
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations.
- Solo strictement identique : `tests/smoke_test.gd` reste vert ; seules changent les deux lignes qui lisaient `lion.pilote_direction`, et des vérifications s'ajoutent.
- Fichiers de la phase (5 au plus, `.uid` non comptés) : `Scripts/Commandes.gd`, `tests/unitaires.gd`, `Scripts/Lion.gd`, `Scripts/Pilote.gd`, `tests/smoke_test.gd`.
- `Scripts/GerbeTraceuse.gd` n'est **pas** modifié : il continue de lire `GameState.couleurs_debloquees` (façade) jusqu'à la phase 6.
- Avant chaque commande `godot` : `export PATH="/opt/homebrew/bin:$PATH"` ; toutes les commandes depuis `~/Sites/LeLion-multi`.
- Après la création d'un script à `class_name`, relancer `godot --headless --import .` avant les tests.
- Commits en français, terminés par la ligne `Co-Authored-By:` qu'impose l'environnement de l'auteur du commit.

## Review Focus

1. **Un lion lié à un autre joueur** ne doit pas réagir au joueur local (couleurs, bonus, coups), et doit réagir au sien. C'est la raison d'être de la phase. → vérification « lion lié à son propre joueur » (Task 2).
2. **Commandes manuelles et vraie saisie** : en démo, appuyer sur une touche ne doit pas piloter le lion (seul le pilote le fait). → test « les commandes manuelles ignorent le clavier » (Task 1).
3. **Intro** : pendant « Prêt ? Vomissez ! », les commandes, quelles qu'elles soient, sont ignorées. → la vérification existante « le lion ne bouge pas pendant l'intro » doit rester verte ; plus une vérification sur des commandes manuelles (Task 2).
4. **Lion libéré, joueur persistant** : le `Joueur` survit aux parties (il vit dans `GameState`) alors que le lion est recréé à chaque partie. Un signal du joueur émis après la libération d'un ancien lion ne doit provoquer aucune erreur. → le smoke test enchaîne 6 parties ; sa sortie ne doit contenir aucune ligne `SCRIPT ERROR` (Task 2, étape de vérification).
5. **Démo** : le lion de la démo est sur des commandes manuelles, le pilote les remplit, et quitter la démo rend la main. → vérifications de démo (Task 2).

---

### Task 1 : classe `Commandes` et ses tests unitaires

**Files:**
- Create: `Scripts/Commandes.gd`
- Modify: `tests/unitaires.gd`

**Interfaces:**
- Consumes : actions InputMap existantes `deplacer_gauche`, `deplacer_droite`, `deplacer_haut`, `deplacer_bas`, `vomir` (dans `project.godot`).
- Produces (utilisé par la Task 2, puis par le réseau en phases 14 et 16) :
  - `class_name Commandes extends RefCounted`
  - `enum Source { LOCALES, MANUELLES }`, `var source: Source`
  - `var direction_voulue: Vector2`, `var vomir_voulu: bool` (lus seulement en source `MANUELLES`)
  - `static func locales() -> Commandes`, `static func manuelles() -> Commandes`
  - `func direction() -> Vector2`, `func vomir() -> bool`

- [ ] **Step 1 : Écrire les tests (qui échouent)**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_facade_game_state()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_facade_game_state()
	_tester_commandes()
	print("== %d échec(s) ==" % _echecs)
```

puis ajouter à la fin du fichier :

```gdscript
func _tester_commandes() -> void:
	print("-- Commandes")
	var m := Commandes.manuelles()
	_check(m.source == Commandes.Source.MANUELLES and m.direction() == Vector2.ZERO and not m.vomir(),
		"des commandes manuelles neuves sont au repos")
	m.direction_voulue = Vector2(0.6, -0.8)
	m.vomir_voulu = true
	_check(m.direction() == Vector2(0.6, -0.8) and m.vomir(), "les commandes manuelles renvoient ce qu'on y écrit")

	var l := Commandes.locales()
	_check(l.source == Commandes.Source.LOCALES, "Commandes.locales() crée des commandes locales")
	_check(l.direction() == Vector2.ZERO and not l.vomir(), "sans action pressée, les commandes locales sont au repos")
	Input.action_press("deplacer_droite")
	Input.action_press("vomir")
	_check(l.direction().x > 0.99 and absf(l.direction().y) < 0.01 and l.vomir(), "les commandes locales lisent les actions de ce poste")
	m.direction_voulue = Vector2.ZERO
	m.vomir_voulu = false
	_check(m.direction() == Vector2.ZERO and not m.vomir(), "les commandes manuelles ignorent le clavier et la manette")
	l.direction_voulue = Vector2.LEFT
	_check(l.direction().x > 0.99, "écrire direction_voulue ne change pas des commandes locales")
	Input.action_release("deplacer_droite")
	Input.action_release("vomir")
	_check(l.direction() == Vector2.ZERO and not l.vomir(), "relâcher les actions remet les commandes locales au repos")
```

- [ ] **Step 2 : Lancer les tests pour les voir échouer**

Run: `godot --headless --script tests/unitaires.gd 2>&1 | grep -E "Commandes|ERROR" | head -3`
Expected : une erreur de compilation du type `Identifier "Commandes" not declared in the current scope`.

- [ ] **Step 3 : Écrire `Scripts/Commandes.gd`**

```gdscript
class_name Commandes
extends RefCounted
## Intentions d'un lion : direction voulue et envie de vomir. Le lion ne lit jamais Input
## lui-même. Deux sources : les actions de ce poste (clavier, manette, tactile), ou des valeurs
## écrites par un tiers (pilote de la démo, tests, et plus tard le réseau).

enum Source { LOCALES, MANUELLES }

var source := Source.MANUELLES
## Lus seulement en source MANUELLES.
var direction_voulue := Vector2.ZERO
var vomir_voulu := false


static func locales() -> Commandes:
	var c := Commandes.new()
	c.source = Source.LOCALES
	return c


static func manuelles() -> Commandes:
	return Commandes.new()


func direction() -> Vector2:
	if source == Source.LOCALES:
		return Input.get_vector("deplacer_gauche", "deplacer_droite", "deplacer_haut", "deplacer_bas")
	return direction_voulue


func vomir() -> bool:
	if source == Source.LOCALES:
		return Input.is_action_pressed("vomir")
	return vomir_voulu
```

- [ ] **Step 4 : Mettre à jour le cache des classes, puis lancer les tests**

Run: `godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"; godot --headless --script tests/unitaires.gd 2>&1 | tail -2`
Expected : aucune erreur de compilation, puis `== 0 échec(s) ==`.

- [ ] **Step 5 : Smoke test inchangé**

Run: `godot --headless --script tests/smoke_test.gd 2>&1 | grep -E "❌|== "`
Expected : `== smoke test LeLion ==` puis `== 0 échec(s) ==`, aucune ligne `❌`.

- [ ] **Step 6 : Commit**

```bash
git add Scripts/Commandes.gd* tests/unitaires.gd
git status --short   # rien d'autre ne doit être indexé
git commit -m "Commandes : intentions d'un lion, locales (ce poste) ou manuelles (pilote, tests, réseau)

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 2 : le lion lit son joueur et ses commandes ; le pilote écrit des commandes manuelles

**Files:**
- Modify: `tests/smoke_test.gd`
- Modify: `Scripts/Lion.gd`
- Modify: `Scripts/Pilote.gd`

**Interfaces:**
- Consumes : `Commandes` (Task 1) ; `Joueur` et `GameState.joueur_local()` (phase 1) ; signaux du joueur `couleur_debloquee(couleur: Color)`, `bonus_change(actif: bool)`, `touche(origine: Vector2)`.
- Produces (utilisé par les phases 8, 10, 14, 16) :
  - `Lion.joueur: Joueur` et `Lion.commandes: Commandes`, assignables avant `add_child` ; par défaut `GameState.joueur_local()` et `Commandes.manuelles()` en démo, `Commandes.locales()` sinon.
  - `Lion.pilote_direction` et `Lion.pilote_vomir` **disparaissent**.

- [ ] **Step 1 : Adapter et compléter le smoke test (qui échoue)**

1a. Après la ligne (≈ 131) :

```gdscript
	_check(GS.partie_en_cours, "partie en cours après Main._ready")
```

ajouter :

```gdscript
	_check(lion.joueur == GS.joueur_local() and lion.commandes.source == Commandes.Source.LOCALES,
		"hors démo, le lion porte le joueur local et lit les commandes de ce poste")
```

1b. Dans la section « Attract mode », remplacer :

```gdscript
	lion = main.get_node("Lion")
	spawner = main.get_node("Spawner")
	spawner.spawn_pickup(0, Vector2(1200, 250))
	await _frames(10)
	_check(lion.pilote_direction.length() > 0.9 and lion._vitesse.length() > 0.0, "le pilote dirige le lion vers la pastille")
```

par :

```gdscript
	lion = main.get_node("Lion")
	spawner = main.get_node("Spawner")
	_check(lion.commandes.source == Commandes.Source.MANUELLES, "en démo, le lion suit des commandes manuelles")
	spawner.spawn_pickup(0, Vector2(1200, 250))
	await _frames(10)
	_check(lion.commandes.direction_voulue.length() > 0.9 and lion._vitesse.length() > 0.0, "le pilote dirige le lion vers la pastille")
```

1c. Remplacer :

```gdscript
	_check(lion.pilote_direction.x < 0.0, "le pilote fuit un ennemi proche")
```

par :

```gdscript
	_check(lion.commandes.direction_voulue.x < 0.0, "le pilote fuit un ennemi proche")
```

1d. Remplacer :

```gdscript
	_check(not GS.partie_en_cours, "mode Hardcore : un coup et c'est fini")
	GS.difficulte_courante = 0

	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_check(not GS.partie_en_cours, "mode Hardcore : un coup et c'est fini")
	GS.difficulte_courante = 0

	# Un lion lié à un autre joueur suit ce joueur et ses propres commandes
	paused = false
	var autre := Joueur.new()
	autre.reinitialiser(3)
	var lion_autre: Node = load("res://Scenes/Lion.tscn").instantiate()
	lion_autre.joueur = autre
	lion_autre.commandes = Commandes.manuelles()
	lion_autre.position = Vector2(400, 200)
	root.add_child(lion_autre)
	await _frames(1)
	_check(lion_autre.vomi_container.get_child_count() == 0, "un lion lié à un joueur sans couleur n'a pas d'émetteur")
	GS.debloquer_couleur(3)
	_check(lion_autre.vomi_container.get_child_count() == 0, "une couleur du joueur local ne touche pas un lion lié à un autre joueur")
	autre.debloquer_couleur(Color.RED)
	_check(lion_autre.vomi_container.get_child_count() == 1, "le lion reconstruit sa gerbe quand son propre joueur débloque une couleur")
	GS.pret = false
	lion_autre.commandes.direction_voulue = Vector2.RIGHT
	var x_avant: float = lion_autre.global_position.x
	await _frames(5)
	_check(lion_autre.global_position.x == x_avant, "hors jeu (intro), même des commandes manuelles sont ignorées")
	GS.pret = true
	await _frames(5)
	_check(lion_autre.global_position.x > x_avant, "le lion avance selon ses commandes manuelles")
	lion_autre.commandes.vomir_voulu = true
	await _frames(2)
	_check(lion_autre.est_en_train_de_vomir, "le lion vomit quand ses commandes manuelles le demandent")
	lion_autre.commandes.vomir_voulu = false
	await _frames(2)
	lion_autre.free()

	print("== %d échec(s) ==" % _echecs)
```

- [ ] **Step 2 : Lancer le smoke test pour le voir échouer**

Run: `godot --headless --script tests/smoke_test.gd 2>&1 | grep -E "❌|SCRIPT ERROR|== " | head -8`
Expected : des erreurs sur la propriété `joueur` / `commandes` inexistante du lion (ou des `❌` correspondants).

- [ ] **Step 3 : Modifier `Scripts/Lion.gd`**

3a. Remplacer :

```gdscript
var est_en_train_de_vomir := false
var direction_du_lion: int = 1  # 1 = droite, -1 = gauche
var pilote_direction := Vector2.ZERO  # attract mode
var pilote_vomir := false
```

par :

```gdscript
var est_en_train_de_vomir := false
var direction_du_lion: int = 1  # 1 = droite, -1 = gauche
## État du lion (couleurs, bonus, coups) et source de ses intentions. À fournir avant l'ajout
## à l'arbre ; à défaut, le joueur local et ses commandes (celles du pilote en démo).
var joueur: Joueur
var commandes: Commandes
```

3b. Remplacer :

```gdscript
func _ready() -> void:
	GameState.couleur_debloquee.connect(_on_couleur_debloquee)
	GameState.bonus_change.connect(_on_bonus_change)
	GameState.lion_touche.connect(_on_lion_touche)
	_appliquer_direction()
	mettre_a_jour_degrade_vomi()
```

par :

```gdscript
func _ready() -> void:
	if joueur == null:
		joueur = GameState.joueur_local()
	if commandes == null:
		commandes = Commandes.manuelles() if GameState.demo else Commandes.locales()
	joueur.couleur_debloquee.connect(_on_couleur_debloquee)
	joueur.bonus_change.connect(_on_bonus_change)
	joueur.touche.connect(_on_lion_touche)
	_appliquer_direction()
	mettre_a_jour_degrade_vomi()
```

3c. Remplacer :

```gdscript
func _direction_voulue() -> Vector2:
	if not GameState.pret:
		return Vector2.ZERO
	if GameState.demo:
		return pilote_direction
	return Input.get_vector("deplacer_gauche", "deplacer_droite", "deplacer_haut", "deplacer_bas")


func _veut_vomir() -> bool:
	if not GameState.pret:
		return false
	return pilote_vomir if GameState.demo else Input.is_action_pressed("vomir")
```

par :

```gdscript
func _direction_voulue() -> Vector2:
	return commandes.direction() if GameState.pret else Vector2.ZERO


func _veut_vomir() -> bool:
	return GameState.pret and commandes.vomir()
```

3d. Dans `_facteur_bonus`, remplacer `GameState.bonus_actif()` par `joueur.bonus_actif()`.

3e. Dans `_placer_traceuse`, remplacer `var n := GameState.couleurs_debloquees.size()` par `var n := joueur.couleurs_debloquees.size()`.

3f. Dans `mettre_a_jour_degrade_vomi`, remplacer `for couleur in GameState.couleurs_debloquees:` par `for couleur in joueur.couleurs_debloquees:`.

3g. Dans `demarrer_vomi`, remplacer `if GameState.couleurs_debloquees.is_empty():` par `if joueur.couleurs_debloquees.is_empty():`.

`GameState.DUREE_INVULNERABILITE` (dans `_on_lion_touche`) reste inchangé : c'est une règle, elle migrera en phase 3.

- [ ] **Step 4 : Vérifier `Lion.gd`**

Run: `grep -n "GameState\.\|Input\.\|pilote_" Scripts/Lion.gd`
Expected : exactement cinq lignes : `GameState.joueur_local()`, `GameState.demo`, `GameState.pret` deux fois (dans `_direction_voulue` et `_veut_vomir`) et `GameState.DUREE_INVULNERABILITE`. Aucune ligne `Input.`, aucune ligne `pilote_`.

- [ ] **Step 5 : Modifier `Scripts/Pilote.gd`**

5a. Remplacer la ligne de docstring :

```gdscript
## puis balaie la ville en vomissant. Écrit dans lion.pilote_direction / pilote_vomir.
```

par :

```gdscript
## puis balaie la ville en vomissant. Écrit dans les commandes manuelles du lion.
```

5b. Remplacer :

```gdscript
	if fuite != Vector2.ZERO:
		lion.pilote_direction = fuite.normalized()
		lion.pilote_vomir = false
		return
```

par :

```gdscript
	if fuite != Vector2.ZERO:
		lion.commandes.direction_voulue = fuite.normalized()
		lion.commandes.vomir_voulu = false
		return
```

5c. Remplacer :

```gdscript
	if pickup != null and (GameState.couleurs_debloquees.is_empty()
			or pickup.global_position.distance_to(centre) < DISTANCE_PICKUP_TENTANT):
		_aller_vers(pickup.global_position - Vector2(68, 66))
		lion.pilote_vomir = false
		return
```

par :

```gdscript
	if pickup != null and (lion.joueur.couleurs_debloquees.is_empty()
			or pickup.global_position.distance_to(centre) < DISTANCE_PICKUP_TENTANT):
		_aller_vers(pickup.global_position - Vector2(68, 66))
		lion.commandes.vomir_voulu = false
		return
```

5d. Remplacer :

```gdscript
	lion.pilote_vomir = not GameState.couleurs_debloquees.is_empty()
```

par :

```gdscript
	lion.commandes.vomir_voulu = not lion.joueur.couleurs_debloquees.is_empty()
```

5e. Dans `_aller_vers`, remplacer :

```gdscript
	lion.pilote_direction = ecart.normalized() if ecart.length() > 24.0 else Vector2.ZERO
```

par :

```gdscript
	lion.commandes.direction_voulue = ecart.normalized() if ecart.length() > 24.0 else Vector2.ZERO
```

- [ ] **Step 6 : Vérifier qu'il ne reste aucune référence à l'ancienne API**

Run: `grep -rn "pilote_direction\|pilote_vomir" Scripts Scenes tests`
Expected : aucune ligne.

- [ ] **Step 7 : Vérification complète**

Run:
```sh
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
godot --headless --script tests/unitaires.gd 2>&1 | tail -2
godot --headless --script tests/smoke_test.gd 2>&1 | grep -E "❌|SCRIPT ERROR|== "
```
Expected : rien pour la première commande ; `== 0 échec(s) ==` pour les tests unitaires ; pour le smoke test, uniquement `== smoke test LeLion ==` et `== 0 échec(s) ==` (aucun `❌`, aucun `SCRIPT ERROR`, Review Focus 4).

- [ ] **Step 8 : Commit**

```bash
git add Scripts/Lion.gd Scripts/Pilote.gd tests/smoke_test.gd
git commit -m "Lion : lit son Joueur et ses Commandes ; le pilote de démo écrit des commandes manuelles

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

## Sortie de phase

- `tests/unitaires.gd` et `tests/smoke_test.gd` : `== 0 échec(s) ==`, localement puis en CI sur la PR.
- `git diff main --stat` ne montre que les 5 fichiers prévus (plus `Scripts/Commandes.gd.uid`).
- `grep -n "GameState" Scripts/Lion.gd` : seulement `joueur_local()`, `demo`, `pret` et `DUREE_INVULNERABILITE`.
