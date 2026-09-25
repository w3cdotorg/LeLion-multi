# Phase 1 : ressource Joueur, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sortir l'état par joueur (couleurs débloquées, vies, coups reçus, invulnérabilité, bonus) de l'autoload `GameState` vers une ressource `Joueur`, sans aucun changement de comportement du solo.

**Architecture:** `Joueur` (Resource, `class_name Joueur`) porte l'état et les signaux d'un lion et ne dépend de rien. `GameState` détient `joueurs: Array[Joueur]` (un seul en solo) et garde, pour cette phase, une **façade transitoire** : mêmes propriétés, mêmes méthodes et mêmes signaux qu'avant, qui délèguent au joueur local. Les 15 appelants existants ne changent donc pas encore ; ils migreront aux phases 2 à 5 et la façade disparaîtra en phase 6.

**Tech Stack:** Godot 4.7.2, GDScript typé, tests headless (`extends SceneTree`), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (section 3.1, unités `Joueur` et `GameState`) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`

## Global Constraints

- Godot 4.7.2 (celui de la CI : `GODOT_VERSION: 4.7.2`, et `/opt/homebrew/bin/godot` en local).
- Identifiants, commentaires et messages de test en français, docstrings `##` comme le code existant.
- Indentation par tabulations (style du dépôt).
- Solo strictement identique : `tests/smoke_test.gd` doit rester vert **sans modifier ses assertions** (seul le Step 0 retire une vérification sans effet).
- 5 fichiers au plus touchés dans la phase : `Scripts/Joueur.gd`, `Scripts/GameState.gd`, `tests/unitaires.gd`, `.github/workflows/ci.yml`, `tests/smoke_test.gd`.
- Avant chaque commande `godot` : `export PATH="/opt/homebrew/bin:$PATH"` ; toutes les commandes se lancent depuis `~/Sites/LeLion-multi`.
- Après la création d'un script à `class_name`, relancer `godot --headless --import .` avant les tests.
- Commits : message en français, terminé par la ligne `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus

1. **Ordre des signaux lors d'un coup** : aujourd'hui `vies_changees` part avant `lion_touche` (le HUD grise le cœur, puis flashe). Il doit rester dans cet ordre, et `lion_touche` ne doit pas partir sur le coup fatal. → test « ordre des signaux » (Task 2).
2. **Nouvelle partie pendant une gerbe XXL** : `nouvelle_partie()` remet le bonus à zéro **sans** émettre `bonus_change(false)` (le lion est recréé de toute façon). Émettre changerait le comportement. → test « reinitialiser n'émet rien » (Task 2).
3. **Écriture via la façade** : le smoke test écrit `GS.vies = 1`, `GS.bonus_restant = 0.01`, `GS.invulnerable_restant = 0.0`. Les setters doivent écrire dans le joueur local. → test façade (Task 3).
4. **Débloquer une couleur hors bornes** : `debloquer_couleur(-1)` ou `(7)` doit renvoyer `false` sans rien émettre, comme aujourd'hui. → test façade (Task 3).
5. **Minuteries qui avancent hors partie** : pendant l'intro (`pret == false`) ou après la fin, ni l'invulnérabilité ni le bonus ne décomptent. → test façade (Task 3).

---

### Task 1 : Step 0, retirer la vérification sans effet du smoke test

`tests/smoke_test.gd` dépasse 300 lignes : règle « Step 0 » du `CLAUDE.md`. Le scan du dépôt (fonctions, variables, constantes et signaux référencés une seule fois, `print` de debug dans `Scripts/`) ne trouve rien d'autre. Ligne 396, la vérification porte sur `titre` déjà libéré ligne 109 : elle vaut toujours `true` et affiche « (titre libéré) ».

**Files:**
- Modify: `tests/smoke_test.gd:396`

- [ ] **Step 1 : Supprimer la ligne**

Supprimer exactement cette ligne (et elle seule) :

```gdscript
	_check(tr("ARCADE") in titre.bouton_arcade.text if is_instance_valid(titre) else true, "(titre libéré)")
```

- [ ] **Step 2 : Vérifier**

Run: `godot --headless --script tests/smoke_test.gd 2>&1 | tail -3`
Expected: `== 0 échec(s) ==`

- [ ] **Step 3 : Commit (séparé, comme l'exige le Step 0)**

```bash
git add tests/smoke_test.gd
git commit -m "Smoke test : retire une vérification sans effet (titre déjà libéré)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2 : ressource `Joueur` et ses tests unitaires

**Files:**
- Create: `tests/unitaires.gd`
- Create: `Scripts/Joueur.gd`

**Interfaces:**
- Consumes : rien.
- Produces (utilisé par la Task 3 puis par les phases 2 à 8) :
  - `class_name Joueur extends Resource`
  - signaux `couleur_debloquee(couleur: Color)`, `bonus_change(actif: bool)`, `vies_changees(vies: int)`, `touche(origine: Vector2)`
  - propriétés `index: int`, `pseudo: String`, `couleur: Color`, `couleurs_debloquees: Array[Color]`, `vies: int`, `coups_recus: int`, `invulnerable_restant: float`, `bonus_restant: float`
  - `reinitialiser(vies_depart: int) -> void`
  - `avancer(delta: float) -> void`
  - `debloquer_couleur(c: Color) -> bool`
  - `encaisser_coup(origine: Vector2, duree_invulnerabilite: float) -> int` (vies restantes)
  - `gagner_vie(vies_max: int) -> bool`
  - `activer_bonus(duree: float) -> void`, `bonus_actif() -> bool`, `est_invulnerable() -> bool`

- [ ] **Step 1 : Écrire les tests (qui échouent)**

Créer `tests/unitaires.gd` :

```gdscript
extends SceneTree
## Tests unitaires headless : godot --headless --script tests/unitaires.gd
## Logique pure (Joueur, puis territoire, couleurs, protocole…), sans charger de scène de jeu.

var _echecs := 0


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _run() -> void:
	print("== tests unitaires LeLion ==")
	_tester_joueur()
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _tester_joueur() -> void:
	print("-- Joueur")
	var j := Joueur.new()
	j.reinitialiser(3)
	_check(j.vies == 3 and j.coups_recus == 0 and j.couleurs_debloquees.is_empty(), "un joueur réinitialisé a ses vies et aucune couleur")

	# Couleurs
	var recues: Array[Color] = []
	j.couleur_debloquee.connect(func(c: Color) -> void: recues.append(c))
	_check(j.debloquer_couleur(Color.RED), "débloquer une couleur nouvelle renvoie true")
	_check(not j.debloquer_couleur(Color.RED), "débloquer deux fois la même couleur renvoie false")
	_check(j.couleurs_debloquees == [Color.RED] and recues == [Color.RED], "la couleur est ajoutée et signalée une seule fois")

	# Coups : ordre des signaux, invulnérabilité, coup fatal
	var journal: Array[String] = []
	j.vies_changees.connect(func(v: int) -> void: journal.append("vies:%d" % v))
	j.touche.connect(func(o: Vector2) -> void: journal.append("touche:%d,%d" % [int(o.x), int(o.y)]))
	_check(j.encaisser_coup(Vector2(10, 20), 1.5) == 2, "un coup renvoie les vies restantes (2)")
	_check(journal == ["vies:2", "touche:10,20"], "ordre des signaux : vies_changees puis touche (%s)" % [journal])
	_check(j.est_invulnerable() and is_equal_approx(j.invulnerable_restant, 1.5) and j.coups_recus == 1, "après un coup : invulnérable 1,5 s, un coup compté")
	j.avancer(1.0)
	_check(is_equal_approx(j.invulnerable_restant, 0.5), "avancer décompte l'invulnérabilité")
	j.avancer(2.0)
	_check(j.invulnerable_restant == 0.0 and not j.est_invulnerable(), "l'invulnérabilité s'arrête à zéro, jamais en négatif")
	journal.clear()
	j.vies = 1
	_check(j.encaisser_coup(Vector2.INF, 1.5) == 0, "le dernier coup renvoie 0")
	_check(journal == ["vies:0"], "le coup fatal n'émet pas touche (%s)" % [journal])
	_check(not j.est_invulnerable(), "le coup fatal ne rend pas invulnérable")

	# Vies
	j.reinitialiser(3)
	_check(not j.gagner_vie(3), "impossible de dépasser le maximum de vies")
	j.vies = 2
	_check(j.gagner_vie(3) and j.vies == 3, "gagner une vie sous le maximum")

	# Bonus : une émission à l'activation, une à l'expiration
	var bonus: Array[bool] = []
	j.bonus_change.connect(func(actif: bool) -> void: bonus.append(actif))
	j.activer_bonus(8.0)
	j.activer_bonus(4.0)
	_check(bonus == [true] and is_equal_approx(j.bonus_restant, 8.0), "prolonger un bonus actif ne réémet pas et garde la durée la plus longue")
	j.avancer(7.9)
	_check(j.bonus_actif() and bonus == [true], "le bonus est encore actif avant son terme")
	j.avancer(0.2)
	_check(not j.bonus_actif() and j.bonus_restant == 0.0 and bonus == [true, false], "le bonus expire et le signale une fois")
	j.avancer(1.0)
	_check(bonus == [true, false], "pas de nouvelle émission après l'expiration")

	# Réinitialiser en plein bonus : silencieux (le lion est recréé par la nouvelle partie)
	j.activer_bonus(8.0)
	j.debloquer_couleur(Color.BLUE)
	bonus.clear()
	recues.clear()
	journal.clear()
	j.reinitialiser(1)
	_check(bonus.is_empty() and recues.is_empty() and journal.is_empty(), "reinitialiser n'émet aucun signal")
	_check(j.vies == 1 and not j.bonus_actif() and j.couleurs_debloquees.is_empty() and j.coups_recus == 0,
		"reinitialiser remet vies, bonus, couleurs et coups à l'état de départ")
```

- [ ] **Step 2 : Lancer les tests pour les voir échouer**

Run: `godot --headless --script tests/unitaires.gd 2>&1 | grep -E "Joueur|ERROR" | head -3`
Expected: une erreur de compilation du type `Identifier "Joueur" not declared in the current scope`.

- [ ] **Step 3 : Écrire `Scripts/Joueur.gd`**

```gdscript
class_name Joueur
extends Resource
## État d'un lion pendant une partie : couleurs débloquées, vies, invulnérabilité, bonus.
## Ne dépend de rien : ce sont les règles qui décident quand appeler ces méthodes.

signal couleur_debloquee(couleur: Color)
signal bonus_change(actif: bool)
signal vies_changees(vies: int)
signal touche(origine: Vector2)

@export var index := 0
@export var pseudo := ""
@export var couleur := Color.WHITE

var couleurs_debloquees: Array[Color] = []
var vies := 3
var coups_recus := 0
var invulnerable_restant := 0.0
var bonus_restant := 0.0


## Remet le joueur à l'état de départ d'une partie, sans émettre de signal.
func reinitialiser(vies_depart: int) -> void:
	couleurs_debloquees.clear()
	vies = vies_depart
	coups_recus = 0
	invulnerable_restant = 0.0
	bonus_restant = 0.0


## Décompte invulnérabilité et bonus ; signale la fin de la gerbe XXL.
func avancer(delta: float) -> void:
	if invulnerable_restant > 0.0:
		invulnerable_restant = max(0.0, invulnerable_restant - delta)
	if bonus_restant > 0.0:
		bonus_restant -= delta
		if bonus_restant <= 0.0:
			bonus_restant = 0.0
			bonus_change.emit(false)


func debloquer_couleur(c: Color) -> bool:
	if couleurs_debloquees.has(c):
		return false
	couleurs_debloquees.append(c)
	couleur_debloquee.emit(c)
	return true


## Perd une vie. S'il en reste, devient invulnérable et émet `touche` (après `vies_changees`).
## `origine` = position de ce qui a frappé, pour le recul (Vector2.INF si inconnue).
func encaisser_coup(origine: Vector2, duree_invulnerabilite: float) -> int:
	vies -= 1
	coups_recus += 1
	vies_changees.emit(vies)
	if vies > 0:
		invulnerable_restant = duree_invulnerabilite
		touche.emit(origine)
	return vies


func gagner_vie(vies_max: int) -> bool:
	if vies >= vies_max:
		return false
	vies += 1
	vies_changees.emit(vies)
	return true


func est_invulnerable() -> bool:
	return invulnerable_restant > 0.0


func bonus_actif() -> bool:
	return bonus_restant > 0.0


## Active (ou prolonge) la gerbe XXL pour `duree` secondes.
func activer_bonus(duree: float) -> void:
	var etait_actif := bonus_actif()
	bonus_restant = max(bonus_restant, duree)
	if not etait_actif:
		bonus_change.emit(true)
```

- [ ] **Step 4 : Mettre à jour le cache des classes, puis lancer les tests**

Run: `godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"; godot --headless --script tests/unitaires.gd 2>&1 | tail -2`
Expected: aucune ligne d'erreur de compilation, puis `== 0 échec(s) ==`.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Joueur.gd* tests/unitaires.gd*
git commit -m "Joueur : état par lion (couleurs, vies, invulnérabilité, bonus) et tests unitaires

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

(Le motif `*` embarque les `.uid` que l'import de Godot 4.4+ génère à côté des scripts ; le dépôt les versionne déjà pour tous les autres. Vérifier avec `git status --short` qu'aucun autre fichier n'est ajouté.)

---

### Task 3 : `GameState` délègue au joueur local (façade transitoire)

**Files:**
- Modify: `Scripts/GameState.gd`
- Modify: `tests/unitaires.gd`

**Interfaces:**
- Consumes : `Joueur` (Task 2).
- Produces (utilisé par les phases 2 à 5) :
  - `GameState.joueurs: Array[Joueur]` (un élément en solo)
  - `GameState.joueur_local() -> Joueur`
  - façade inchangée pour les appelants existants : propriétés `couleurs_debloquees`, `vies` (lecture/écriture), `coups_recus`, `invulnerable_restant` (l/é), `bonus_restant` (l/é) ; méthodes `toucher_lion`, `gagner_vie`, `debloquer_couleur`, `prochain_index_couleur`, `bonus_actif`, `activer_bonus`, `est_invulnerable` ; signaux `couleur_debloquee`, `bonus_change`, `vies_changees`, `lion_touche` relayés depuis le joueur local.

- [ ] **Step 1 : Ajouter les tests de la façade (qui échouent)**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_joueur()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_joueur()
	_tester_facade_game_state()
	print("== %d échec(s) ==" % _echecs)
```

puis ajouter à la fin du fichier :

```gdscript
func _tester_facade_game_state() -> void:
	print("-- GameState (façade vers le joueur local)")
	var gs: Node = root.get_node("GameState")
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	_check(gs.joueurs.size() == 1 and gs.joueur_local() == gs.joueurs[0], "en solo, un seul joueur, qui est le joueur local")
	var j: Joueur = gs.joueur_local()
	_check(j.vies == 3 and gs.vies == 3, "nouvelle_partie donne au joueur les vies de la difficulté")

	# Relais des signaux et bornes
	var relaye: Array[Color] = []
	var relais := func(c: Color) -> void: relaye.append(c)
	gs.couleur_debloquee.connect(relais)
	_check(gs.debloquer_couleur(0) and j.couleurs_debloquees == [gs.couleur(0)], "debloquer_couleur écrit dans le joueur local")
	_check(relaye == [gs.couleur(0)], "le signal couleur_debloquee de GameState relaie celui du joueur")
	_check(not gs.debloquer_couleur(-1) and not gs.debloquer_couleur(gs.nb_couleurs_total()) and relaye.size() == 1,
		"un index hors bornes est refusé sans signal")
	_check(gs.prochain_index_couleur() == 1, "prochain_index_couleur suit les couleurs du joueur")
	gs.couleur_debloquee.disconnect(relais)

	# Setters de la façade (utilisés par le smoke test)
	gs.vies = 1
	gs.bonus_restant = 0.5
	gs.invulnerable_restant = 0.25
	_check(j.vies == 1 and is_equal_approx(j.bonus_restant, 0.5) and is_equal_approx(j.invulnerable_restant, 0.25),
		"les setters vies / bonus_restant / invulnerable_restant écrivent dans le joueur")

	# Les minuteries ne tournent qu'en partie, une fois prêt
	gs.pret = false
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.25) and is_equal_approx(j.bonus_restant, 0.5), "pendant l'intro, les minuteries ne décomptent pas")
	gs.pret = true
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.05) and is_equal_approx(j.bonus_restant, 0.3), "une fois prêt, GameState fait avancer le joueur")

	# Coup via la façade : relais de lion_touche, puis défaite au dernier coup
	gs.invulnerable_restant = 0.0
	gs.vies = 2
	var touches: Array[Vector2] = []
	var sur_touche := func(o: Vector2) -> void: touches.append(o)
	gs.lion_touche.connect(sur_touche)
	gs.toucher_lion(Vector2(5, 5))
	_check(gs.vies == 1 and touches == [Vector2(5, 5)] and gs.est_invulnerable(), "toucher_lion retire une vie et relaie lion_touche")
	gs.toucher_lion(Vector2(6, 6))
	_check(gs.vies == 1, "pas de coup pendant l'invulnérabilité")
	gs.invulnerable_restant = 0.0
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)
	gs.toucher_lion(Vector2(7, 7))
	_check(fins == [false] and not gs.partie_en_cours and touches.size() == 1, "le dernier coup termine la partie en défaite, sans lion_touche")
	gs.lion_touche.disconnect(sur_touche)
	gs.partie_terminee.disconnect(sur_fin)

	# Nouvelle partie : repart de zéro
	gs.activer_bonus(8.0)
	gs.nouvelle_partie()
	_check(gs.couleurs_debloquees.is_empty() and gs.vies == 3 and gs.coups_recus == 0 and not gs.bonus_actif(),
		"nouvelle_partie remet le joueur local à zéro")
	gs.partie_en_cours = false
	gs.pret = false
```

- [ ] **Step 2 : Lancer les tests pour les voir échouer**

Run: `godot --headless --script tests/unitaires.gd 2>&1 | tail -4`
Expected: une erreur sur `joueurs` / `joueur_local` (propriété ou méthode inexistante sur `GameState`) ; la section `-- Joueur` reste verte.

- [ ] **Step 3 : Modifier `Scripts/GameState.gd`**

3a. Remplacer l'en-tête de docstring :

```gdscript
extends Node
## État global d'une partie : couleurs débloquées, progression de la peinture,
## chrono, fin de partie.
```

par :

```gdscript
extends Node
## État global d'une partie : joueurs, progression de la peinture, chrono, fin de partie.
## L'état propre à chaque lion vit dans `Joueur` ; les propriétés et méthodes marquées
## « façade » délèguent au joueur local le temps que les appelants migrent (phases 2 à 6).
```

3b. Remplacer ce bloc de variables :

```gdscript
var couleurs_debloquees: Array[Color] = []
var progression := 0.0
```

par :

```gdscript
var joueurs: Array[Joueur] = [Joueur.new()]
var progression := 0.0
```

et supprimer ces cinq lignes (plus bas dans le même bloc de variables) :

```gdscript
var vies := 3
var coups_recus := 0
var invulnerable_restant := 0.0
var bonus_restant := 0.0
```

(la ligne `var etape_arcade := 0` et `var temps_arcade := 0.0` restent.)

3c. Juste après le bloc de variables (avant `func _process`), ajouter :

```gdscript
# Façade : état du joueur local (supprimée en phase 6).
var couleurs_debloquees: Array[Color]:
	get:
		return joueur_local().couleurs_debloquees
var vies: int:
	get:
		return joueur_local().vies
	set(valeur):
		joueur_local().vies = valeur
var coups_recus: int:
	get:
		return joueur_local().coups_recus
var invulnerable_restant: float:
	get:
		return joueur_local().invulnerable_restant
	set(valeur):
		joueur_local().invulnerable_restant = valeur
var bonus_restant: float:
	get:
		return joueur_local().bonus_restant
	set(valeur):
		joueur_local().bonus_restant = valeur


func _ready() -> void:
	var j := joueur_local()
	j.couleur_debloquee.connect(func(c: Color) -> void: couleur_debloquee.emit(c))
	j.bonus_change.connect(func(actif: bool) -> void: bonus_change.emit(actif))
	j.vies_changees.connect(func(nb: int) -> void: vies_changees.emit(nb))
	j.touche.connect(func(origine: Vector2) -> void: lion_touche.emit(origine))


## Le joueur de ce poste. En solo, le seul joueur.
func joueur_local() -> Joueur:
	return joueurs[0]
```

3d. Remplacer `_process` :

```gdscript
func _process(delta: float) -> void:
	if not partie_en_cours or not pret:
		return
	temps_ecoule += delta
	if invulnerable_restant > 0.0:
		invulnerable_restant = max(0.0, invulnerable_restant - delta)
	if bonus_restant > 0.0:
		bonus_restant -= delta
		if bonus_restant <= 0.0:
			bonus_restant = 0.0
			bonus_change.emit(false)
```

par :

```gdscript
func _process(delta: float) -> void:
	if not partie_en_cours or not pret:
		return
	temps_ecoule += delta
	for j in joueurs:
		j.avancer(delta)
```

3e. Remplacer `nouvelle_partie` :

```gdscript
func nouvelle_partie() -> void:
	couleurs_debloquees.clear()
	progression = 0.0
	temps_ecoule = 0.0
	bonus_restant = 0.0
	invulnerable_restant = 0.0
	vies = difficulte().vies
	coups_recus = 0
	pret = false
	partie_en_cours = true
```

par :

```gdscript
func nouvelle_partie() -> void:
	for j in joueurs:
		j.reinitialiser(difficulte().vies)
	progression = 0.0
	temps_ecoule = 0.0
	pret = false
	partie_en_cours = true
```

3f. Remplacer `est_invulnerable`, `toucher_lion` et `gagner_vie` :

```gdscript
func est_invulnerable() -> bool:
	return invulnerable_restant > 0.0


## Un ennemi touche le lion : perd une vie, ou termine la partie s'il n'en reste plus.
## `origine` = position de l'ennemi, pour le recul (Vector2.INF si inconnue).
func toucher_lion(origine: Vector2 = Vector2.INF) -> void:
	if not partie_en_cours or not pret or est_invulnerable():
		return
	vies -= 1
	coups_recus += 1
	vies_changees.emit(vies)
	if vies <= 0:
		terminer_partie(false)
		return
	invulnerable_restant = DUREE_INVULNERABILITE
	lion_touche.emit(origine)


func gagner_vie() -> bool:
	if vies >= VIES_MAX:
		return false
	vies += 1
	vies_changees.emit(vies)
	return true
```

par :

```gdscript
func est_invulnerable() -> bool:
	return joueur_local().est_invulnerable()


## Un ennemi touche le lion : perd une vie, ou termine la partie s'il n'en reste plus.
## `origine` = position de l'ennemi, pour le recul (Vector2.INF si inconnue).
func toucher_lion(origine: Vector2 = Vector2.INF) -> void:
	if not partie_en_cours or not pret or est_invulnerable():
		return
	if joueur_local().encaisser_coup(origine, DUREE_INVULNERABILITE) <= 0:
		terminer_partie(false)


func gagner_vie() -> bool:
	return joueur_local().gagner_vie(VIES_MAX)
```

3g. Remplacer `debloquer_couleur` :

```gdscript
func debloquer_couleur(index: int) -> bool:
	if index < 0 or index >= COULEURS_ARC_EN_CIEL.size():
		return false
	var c := COULEURS_ARC_EN_CIEL[index]
	if couleurs_debloquees.has(c):
		return false
	couleurs_debloquees.append(c)
	couleur_debloquee.emit(c)
	return true
```

par :

```gdscript
func debloquer_couleur(index: int) -> bool:
	if index < 0 or index >= COULEURS_ARC_EN_CIEL.size():
		return false
	return joueur_local().debloquer_couleur(COULEURS_ARC_EN_CIEL[index])
```

3h. Remplacer `bonus_actif` et `activer_bonus` :

```gdscript
func bonus_actif() -> bool:
	return bonus_restant > 0.0


## Active (ou prolonge) la gerbe XXL pour `duree` secondes.
func activer_bonus(duree: float) -> void:
	var etait_actif := bonus_actif()
	bonus_restant = max(bonus_restant, duree)
	if not etait_actif:
		bonus_change.emit(true)
```

par :

```gdscript
func bonus_actif() -> bool:
	return joueur_local().bonus_actif()


## Active (ou prolonge) la gerbe XXL pour `duree` secondes.
func activer_bonus(duree: float) -> void:
	joueur_local().activer_bonus(duree)
```

`prochain_index_couleur()` ne change pas : il lit `couleurs_debloquees`, désormais la façade.

- [ ] **Step 4 : Relire le fichier modifié**

Run: `grep -nwE "couleurs_debloquees|bonus_restant|invulnerable_restant|vies|coups_recus" Scripts/GameState.gd`
Expected : ces noms n'apparaissent plus que dans le bloc « Façade », dans `prochain_index_couleur` et dans `nouvelle_partie` (`difficulte().vies`). Aucune affectation directe `vies -= 1`, `bonus_restant -= delta`, etc.

- [ ] **Step 5 : Vérification complète**

Run:
```sh
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
godot --headless --script tests/unitaires.gd 2>&1 | tail -2
godot --headless --script tests/smoke_test.gd 2>&1 | grep -E "❌|échec"
```
Expected : aucune erreur de compilation ; `== 0 échec(s) ==` pour les deux suites, aucune ligne `❌`.

- [ ] **Step 6 : Commit**

```bash
git add Scripts/GameState.gd tests/unitaires.gd
git commit -m "GameState : l'état par joueur passe dans Joueur, façade transitoire pour les appelants

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4 : CI, tests unitaires et retrait du déploiement Pages

Le dépôt hérite du déploiement GitHub Pages du solo, qui échoue sur le fork (Pages n'est pas activé) : les deux premiers runs sont rouges pour cette seule raison. Le multi se distribue en `.exe` (phase 19) ; l'export Web reste pour l'instant comme contrôle de compilation d'export.

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1 : Ajouter les tests unitaires avant le smoke test**

Remplacer :

```yaml
      - name: Smoke test
        run: godot --headless --script tests/smoke_test.gd
```

par :

```yaml
      - name: Tests unitaires
        run: godot --headless --script tests/unitaires.gd

      - name: Smoke test
        run: godot --headless --script tests/smoke_test.gd
```

- [ ] **Step 2 : Retirer la publication Pages**

Supprimer le step :

```yaml
      - name: Publier l'artefact Pages
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        uses: actions/upload-pages-artifact@v3
        with:
          path: export/web
```

et tout le job `deploiement:` (de la ligne `  deploiement:` jusqu'à la fin du fichier).

- [ ] **Step 3 : Vérifier la syntaxe YAML**

Run: `python3 -c "import yaml,sys; d=yaml.safe_load(open('.github/workflows/ci.yml')); print(list(d['jobs']), [s.get('name') for s in d['jobs']['test-et-export']['steps']])"`
Expected : `['test-et-export'] [None, "Installer Godot et les templates d'export", 'Importer les ressources', 'Tests unitaires', 'Smoke test', 'Exporter en Web']`

- [ ] **Step 4 : Commit, push, CI verte**

```bash
git add .github/workflows/ci.yml
git commit -m "CI : tests unitaires, retrait du déploiement Pages hérité du solo

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
git push
RUN=$(gh run list -R w3cdotorg/LeLion-multi --commit "$(git rev-parse HEAD)" -L 1 --json databaseId -q '.[0].databaseId')
gh run watch -R w3cdotorg/LeLion-multi --exit-status "$RUN"
```

Si `RUN` est vide, le run n'est pas encore enregistré : relancer la ligne `RUN=…` quelques secondes plus tard.
Expected : le run se termine en `success` (tests unitaires, smoke test, export Web).

---

## Sortie de phase

- `tests/unitaires.gd` et `tests/smoke_test.gd` : `== 0 échec(s) ==`, localement et en CI.
- `git diff 7fa3f81 --stat -- Scripts tests .github` ne montre que les 5 fichiers prévus.
- Arrêt : présenter le résultat et attendre la validation avant d'écrire le plan de la phase 2.
