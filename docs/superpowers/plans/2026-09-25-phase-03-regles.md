# Phase 3 : Règles, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sortir les règles du solo (coup d'ennemi, cœur, pastille de couleur, étoile, victoire au seuil) de `GameState` vers une couche `Regles` interchangeable, sans aucun changement de comportement, pour que la bataille puisse brancher ses propres règles.

**Architecture:** `Regles` (RefCounted, `class_name Regles`) définit les événements du jeu, chacun sans effet par défaut. `ReglesSolo` en dérive et porte les règles actuelles. Les événements reçoivent **le `Joueur` concerné**, pas forcément le joueur local : c'est ce qui permettra en phase 4 aux ennemis et pastilles de signaler le lion touché, et à la bataille d'avoir N joueurs. `GameState` détient `regles` (un `ReglesSolo` par défaut) ; ses méthodes de façade (`toucher_lion`, `gagner_vie`, `debloquer_couleur`, `signaler_progression`) délèguent aux règles avec le joueur local.

**Tech Stack:** Godot 4.7.2, GDScript typé, tests headless.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (section 3.1, unité `Regles`) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (phase 3 et « Points de vigilance transverses »)

**Écarts assumés avec le spec et la feuille de route** (spec et feuille de route mis à jour dans le commit de ce plan) :
- `Regles` est un `RefCounted` détenu par `GameState`, pas un `Node` instancié par `Main`. Les règles n'ont besoin ni de l'arbre ni de `_process` aujourd'hui ; le chrono de bataille (phase 17) passera par une méthode `avancer(delta)` appelée par `GameState._process`, ajoutée à ce moment-là. Les tests unitaires peuvent ainsi les exercer sans scène.
- `Main.gd` n'est pas modifié : tant qu'il n'existe qu'un mode, le `ReglesSolo` par défaut suffit. Le choix des règles selon le mode arrivera avec la bataille (phase 8 ou 10).
- `VIES_MAX`, `DUREE_INVULNERABILITE` et `seuil_victoire()` restent dans `GameState` : d'autres scripts les lisent (HUD, Spawner, Lion). Ils migreront avec leurs lecteurs.
- **Décision d'exécution (Task 1)** : les règles reçoivent l'état de partie par injection, `Regles.new(partie)` / `ReglesSolo.new(partie)`, et l'utilisent via `partie.` au lieu du global `GameState`. Raison : un test lancé par `--script` est compilé avant l'enregistrement des autoloads, donc un script qui nomme `GameState` ne compile pas depuis un test unitaire. Bonus : plus de dépendance circulaire GameState ↔ ReglesSolo. `GameState` construit ses règles dans `_init()` avec `ReglesSolo.new(self)`.

## Global Constraints

- Godot 4.7.2 (`/opt/homebrew/bin:$PATH`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations.
- Solo strictement identique : `tests/smoke_test.gd` reste vert **sans aucune modification**.
- Fichiers de la phase (5 au plus, `.uid` non comptés) : `Scripts/Regles.gd`, `Scripts/ReglesSolo.gd`, `Scripts/GameState.gd`, `tests/unitaires.gd`.
- Après la création d'un script à `class_name`, relancer `godot --headless --import .` avant les tests.
- **Toujours lancer un test Godot avec un délai maximal** (une erreur de script bloque le processus headless) :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/unitaires.gd; ( godot --headless --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/t.log"`
  (remplacer `T=` par `tests/smoke_test.gd` pour le smoke test ; un test qui passe n'affiche que ses deux lignes `== … ==`).
- Commits en français, terminés par la ligne `Co-Authored-By:` qu'impose l'environnement de l'auteur du commit.

## Review Focus

1. **Les règles agissent sur le joueur reçu, pas sur le joueur local** : un coup signalé pour un autre joueur ne retire rien au joueur local. C'est le contrat dont dépendent la phase 4 et la bataille. → test « coup sur un autre joueur » (Task 1).
2. **Un lion à 0 vie n'est plus jamais frappé** (`Joueur.encaisser_coup` n'a pas de plancher, cf. feuille de route) : après la fin de partie, un coup ne change rien. → test (Task 1).
3. **Victoire signalée une seule fois** même si la progression continue d'être mesurée au-delà du seuil. → test (Task 1).
4. **Coup pendant l'intro** (`pret == false`) ou pendant l'invulnérabilité : aucun effet. → tests (Task 1).
5. **Brancher d'autres règles change vraiment le jeu** : si `GameState.regles` est remplacé, la façade suit les nouvelles règles. C'est ce qui permettra de brancher `ReglesBataille`. → test de délégation (Task 2).

---

### Task 1 : `Regles` et `ReglesSolo`, avec leurs tests unitaires

**Files:**
- Create: `Scripts/Regles.gd`
- Create: `Scripts/ReglesSolo.gd`
- Modify: `tests/unitaires.gd`

**Interfaces:**
- Consumes : `Joueur` (`encaisser_coup(origine, duree) -> int`, `debloquer_couleur(c) -> bool`, `activer_bonus(duree)`, `gagner_vie(vies_max) -> bool`, `est_invulnerable()`) ; `GameState` (`partie_en_cours`, `pret`, `DUREE_INVULNERABILITE`, `VIES_MAX`, `couleur(index) -> Color`, `nb_couleurs_total() -> int`, `seuil_victoire() -> float`, `terminer_partie(victoire: bool)`, signal `partie_terminee(victoire: bool)`).
- Produces (utilisé par la Task 2, la phase 4 et la bataille) :
  - `class_name Regles extends RefCounted` avec :
    - `func lion_touche_par_ennemi(joueur: Joueur, origine: Vector2) -> void`
    - `func pastille_ramassee(joueur: Joueur, index_couleur: int) -> bool`
    - `func etoile_ramassee(joueur: Joueur) -> void`
    - `func coeur_ramasse(joueur: Joueur) -> bool`
    - `func progression_mesuree(ratio: float) -> void`
    (sans effet par défaut, et `false` pour celles qui renvoient un booléen)
  - `class_name ReglesSolo extends Regles`, `const DUREE_ETOILE := 8.0`

- [ ] **Step 1 : Écrire les tests (qui échouent)**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_commandes()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_commandes()
	_tester_regles_solo()
	print("== %d échec(s) ==" % _echecs)
```

puis ajouter à la fin du fichier :

```gdscript
func _tester_regles_solo() -> void:
	print("-- Règles")
	var gs: Node = root.get_node("GameState")
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	gs.pret = true

	# Règles de base : aucun effet
	var base := Regles.new()
	var j := Joueur.new()
	j.reinitialiser(3)
	base.lion_touche_par_ennemi(j, Vector2.ZERO)
	base.etoile_ramassee(j)
	base.progression_mesuree(1.0)
	_check(j.vies == 3 and not j.bonus_actif() and not base.pastille_ramassee(j, 0) and not base.coeur_ramasse(j)
		and j.couleurs_debloquees.is_empty() and fins.is_empty(), "les règles de base n'ont aucun effet")

	# Règles solo : elles agissent sur le joueur reçu, pas sur le joueur local
	var r := ReglesSolo.new()
	var local: Joueur = gs.joueur_local()
	r.lion_touche_par_ennemi(j, Vector2(3, 4))
	_check(j.vies == 2 and j.est_invulnerable() and local.vies == 3, "un coup d'ennemi touche le joueur reçu, pas le joueur local")
	r.lion_touche_par_ennemi(j, Vector2(3, 4))
	_check(j.vies == 2, "pas de coup pendant l'invulnérabilité")
	j.invulnerable_restant = 0.0
	gs.pret = false
	r.lion_touche_par_ennemi(j, Vector2(3, 4))
	_check(j.vies == 2, "pas de coup pendant l'intro")
	gs.pret = true

	# Pastilles, étoile, cœur
	_check(r.pastille_ramassee(j, 2) and j.couleurs_debloquees == [gs.couleur(2)], "une pastille débloque sa couleur de l'arc-en-ciel chez le joueur reçu")
	_check(not r.pastille_ramassee(j, 2), "une couleur déjà débloquée n'a pas d'effet")
	_check(not r.pastille_ramassee(j, -1) and not r.pastille_ramassee(j, gs.nb_couleurs_total()) and j.couleurs_debloquees.size() == 1,
		"un index de couleur hors bornes est refusé")
	r.etoile_ramassee(j)
	_check(j.bonus_actif() and is_equal_approx(j.bonus_restant, ReglesSolo.DUREE_ETOILE), "l'étoile active la gerbe XXL pour DUREE_ETOILE secondes")
	_check(r.coeur_ramasse(j) and j.vies == 3, "un cœur rend une vie")
	_check(not r.coeur_ramasse(j) and j.vies == gs.VIES_MAX, "un cœur ne dépasse pas le maximum de vies")

	# Progression : victoire au seuil, une seule fois
	r.progression_mesuree(gs.seuil_victoire() - 0.01)
	_check(fins.is_empty() and gs.partie_en_cours, "sous le seuil, la partie continue")
	r.progression_mesuree(gs.seuil_victoire())
	_check(fins == [true] and not gs.partie_en_cours, "au seuil de la difficulté, la partie est gagnée")
	r.progression_mesuree(1.0)
	_check(fins == [true], "la victoire n'est signalée qu'une fois")

	# Coup fatal : défaite, et plus aucun coup ensuite
	gs.nouvelle_partie()
	gs.pret = true
	fins.clear()
	j.reinitialiser(1)
	r.lion_touche_par_ennemi(j, Vector2.INF)
	_check(j.vies == 0 and fins == [false] and not gs.partie_en_cours, "le dernier coup termine la partie en défaite")
	r.lion_touche_par_ennemi(j, Vector2.INF)
	_check(j.vies == 0 and fins == [false], "après la fin de partie, un lion à 0 vie n'est plus frappé")

	gs.partie_terminee.disconnect(sur_fin)
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false
```

- [ ] **Step 2 : Lancer les tests pour les voir échouer**

Run (commande avec délai des Global Constraints, `T=tests/unitaires.gd`).
Expected : une `SCRIPT ERROR` ou erreur de compilation sur `Regles` / `ReglesSolo` inconnus (le processus peut être tué par le délai : c'est l'état RED attendu).

- [ ] **Step 3 : Écrire `Scripts/Regles.gd`**

```gdscript
class_name Regles
extends RefCounted
## Règles d'une partie : reçoivent les événements du jeu et décident de leurs effets.
## Chaque événement concerne le joueur reçu, qui n'est pas forcément le joueur local.
## Sans effet par défaut ; chaque mode (solo, bataille) en dérive. Ne s'exécutent que sur
## l'hôte (en solo, le poste est son propre hôte).


## Un ennemi (soucoupe, coccinelle, peintre) touche le lion du joueur. `origine` = position de
## l'ennemi, pour le recul (Vector2.INF si inconnue).
func lion_touche_par_ennemi(_joueur: Joueur, _origine: Vector2) -> void:
	pass


## Renvoie true si la pastille a eu un effet.
func pastille_ramassee(_joueur: Joueur, _index_couleur: int) -> bool:
	return false


func etoile_ramassee(_joueur: Joueur) -> void:
	pass


## Renvoie true si le cœur a eu un effet.
func coeur_ramasse(_joueur: Joueur) -> bool:
	return false


## La ville vient de mesurer la part peinte (0 à 1).
func progression_mesuree(_ratio: float) -> void:
	pass
```

- [ ] **Step 4 : Écrire `Scripts/ReglesSolo.gd`**

```gdscript
class_name ReglesSolo
extends Regles
## Règles du jeu solo : des cœurs, l'arc-en-ciel à débloquer pastille par pastille, et la
## victoire quand la ville est peinte au seuil de la difficulté.

const DUREE_ETOILE := 8.0


func lion_touche_par_ennemi(joueur: Joueur, origine: Vector2) -> void:
	if not GameState.partie_en_cours or not GameState.pret or joueur.est_invulnerable():
		return
	if joueur.encaisser_coup(origine, GameState.DUREE_INVULNERABILITE) <= 0:
		GameState.terminer_partie(false)


func pastille_ramassee(joueur: Joueur, index_couleur: int) -> bool:
	if index_couleur < 0 or index_couleur >= GameState.nb_couleurs_total():
		return false
	return joueur.debloquer_couleur(GameState.couleur(index_couleur))


func etoile_ramassee(joueur: Joueur) -> void:
	joueur.activer_bonus(DUREE_ETOILE)


func coeur_ramasse(joueur: Joueur) -> bool:
	return joueur.gagner_vie(GameState.VIES_MAX)


func progression_mesuree(ratio: float) -> void:
	if GameState.partie_en_cours and ratio >= GameState.seuil_victoire():
		GameState.terminer_partie(true)
```

- [ ] **Step 5 : Mettre à jour le cache des classes, puis lancer les tests**

Run : `godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"`, puis la commande avec délai pour `tests/unitaires.gd`, puis pour `tests/smoke_test.gd`.
Expected : aucune erreur de compilation ; les deux suites n'affichent que leurs lignes `== … ==`, avec `== 0 échec(s) ==`.

- [ ] **Step 6 : Commit**

```bash
git add Scripts/Regles.gd* Scripts/ReglesSolo.gd* tests/unitaires.gd
git status --short   # rien d'autre ne doit être indexé
git commit -m "Règles : couche d'événements interchangeable, règles du solo (coup, cœur, pastille, étoile, victoire)

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 2 : `GameState` délègue ses règles à `regles`

**Files:**
- Modify: `Scripts/GameState.gd`
- Modify: `tests/unitaires.gd`

**Interfaces:**
- Consumes : `Regles`, `ReglesSolo` (Task 1).
- Produces (utilisé par la phase 4 et la bataille) : `GameState.regles: Regles` (un `ReglesSolo` par défaut, remplaçable) ; les méthodes `toucher_lion(origine)`, `gagner_vie() -> bool`, `debloquer_couleur(index) -> bool` et `signaler_progression(ratio)` gardent leur signature et délèguent à `regles` avec le joueur local.

- [ ] **Step 1 : Ajouter le test de délégation (qui échoue)**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_regles_solo()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_regles_solo()
	_tester_delegation_regles()
	print("== %d échec(s) ==" % _echecs)
```

puis ajouter à la fin du fichier :

```gdscript
func _tester_delegation_regles() -> void:
	print("-- GameState délègue aux règles")
	var gs: Node = root.get_node("GameState")
	_check(gs.regles is ReglesSolo, "par défaut, GameState applique les règles du solo")
	var solo: Regles = gs.regles
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	gs.pret = true
	var j: Joueur = gs.joueur_local()
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)

	# Des règles sans effet : la façade ne fait plus rien
	gs.regles = Regles.new(gs)
	gs.toucher_lion(Vector2.ZERO)
	_check(j.vies == 3 and not gs.debloquer_couleur(0) and j.couleurs_debloquees.is_empty() and not gs.gagner_vie(),
		"avec d'autres règles, toucher_lion, debloquer_couleur et gagner_vie suivent ces règles")
	gs.signaler_progression(1.0)
	_check(fins.is_empty() and gs.partie_en_cours and is_equal_approx(gs.progression, 1.0),
		"signaler_progression enregistre toujours la progression mais laisse la victoire aux règles")

	# Retour aux règles du solo
	gs.regles = solo
	gs.signaler_progression(0.0)
	gs.toucher_lion(Vector2.ZERO)
	_check(j.vies == 2, "avec les règles du solo, toucher_lion retire une vie")

	gs.partie_terminee.disconnect(sur_fin)
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false
```

- [ ] **Step 2 : Lancer les tests pour les voir échouer**

Run : commande avec délai, `T=tests/unitaires.gd`.
Expected : erreur sur la propriété `regles` inexistante de `GameState` (les sections précédentes restent vertes).

- [ ] **Step 3 : Modifier `Scripts/GameState.gd`**

3a. Juste après la ligne `var joueurs: Array[Joueur] = [Joueur.new()]`, ajouter :

```gdscript
## Règles de la partie : celles du solo par défaut ; la bataille branchera les siennes.
var regles: Regles
```

et, juste avant `func _ready() -> void:`, ajouter :

```gdscript
func _init() -> void:
	regles = ReglesSolo.new(self)
```

3b. Remplacer :

```gdscript
func toucher_lion(origine: Vector2 = Vector2.INF) -> void:
	if not partie_en_cours or not pret or est_invulnerable():
		return
	if joueur_local().encaisser_coup(origine, DUREE_INVULNERABILITE) <= 0:
		terminer_partie(false)


func gagner_vie() -> bool:
	return joueur_local().gagner_vie(VIES_MAX)
```

par :

```gdscript
func toucher_lion(origine: Vector2 = Vector2.INF) -> void:
	regles.lion_touche_par_ennemi(joueur_local(), origine)


func gagner_vie() -> bool:
	return regles.coeur_ramasse(joueur_local())
```

(Garder le commentaire `##` au-dessus de `toucher_lion` tel quel s'il décrit toujours la méthode ; sinon le remplacer par `## Façade : un ennemi touche le lion du joueur local (voir Regles.lion_touche_par_ennemi).`)

3c. Remplacer :

```gdscript
func debloquer_couleur(index: int) -> bool:
	if index < 0 or index >= COULEURS_ARC_EN_CIEL.size():
		return false
	return joueur_local().debloquer_couleur(COULEURS_ARC_EN_CIEL[index])
```

par :

```gdscript
func debloquer_couleur(index: int) -> bool:
	return regles.pastille_ramassee(joueur_local(), index)
```

3d. Remplacer :

```gdscript
func signaler_progression(ratio: float) -> void:
	progression = ratio
	progression_changee.emit(ratio)
	if partie_en_cours and ratio >= seuil_victoire():
		terminer_partie(true)
```

par :

```gdscript
func signaler_progression(ratio: float) -> void:
	progression = ratio
	progression_changee.emit(ratio)
	regles.progression_mesuree(ratio)
```

`activer_bonus(duree)` ne change pas en phase 3 : `BonusPickup` lui passe sa propre durée ; il passera par `regles.etoile_ramassee` en phase 4, qui retirera alors la constante en double de `BonusPickup`.

- [ ] **Step 4 : Vérifier `GameState.gd`**

Run : `grep -n "encaisser_coup\|gagner_vie(VIES_MAX)\|ratio >= seuil_victoire\|COULEURS_ARC_EN_CIEL\[index\]" Scripts/GameState.gd`
Expected : aucune ligne (ces règles vivent désormais dans `ReglesSolo`). Et `grep -n "regles\." Scripts/GameState.gd` : exactement 4 lignes.

- [ ] **Step 5 : Vérification complète**

Run : `godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"`, puis les deux suites avec délai.
Expected : aucune erreur de compilation ; `tests/unitaires.gd` et `tests/smoke_test.gd` n'affichent que leurs lignes `== … ==` avec `== 0 échec(s) ==`. `git diff --stat HEAD` ne montre pas `tests/smoke_test.gd`.

- [ ] **Step 6 : Commit**

```bash
git add Scripts/GameState.gd tests/unitaires.gd
git commit -m "GameState : la façade délègue coup, cœur, pastille et victoire aux règles branchées

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

## Sortie de phase

- Les deux suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR`, localement puis en CI sur la PR.
- `git diff main --stat` : les 4 fichiers prévus (plus les `.uid` des deux nouveaux scripts) et les documents.
