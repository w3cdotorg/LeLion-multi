# Phase 6 bis : fin de la façade de GameState, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `GameState` ne contient plus que l'état de **partie** : la façade transitoire des phases 1 à 6 (propriétés, méthodes et signaux qui déléguaient au joueur local) disparaît. Le socle (phases 1 à 6 bis) est terminé. Aucun changement de comportement du solo.

**Architecture:** d'abord, les tests passent à l'API directe (`GS.joueur_local()`, `GS.regles.<événement>(joueur, …)`, signaux du `Joueur`) : ils restent verts avec ou sans façade. Ensuite, la façade est supprimée de `GameState`, `Main` s'abonne au `touche` du joueur local pour la secousse, et `tests/screenshots.gd` passe à l'API directe. `GameState.prochain_index_couleur()` reste (lu par le Spawner), réécrit sur `joueur_local()`.

**Tech Stack:** Godot 4.7.2, GDScript, tests headless.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1, `GameState` = état de partie) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (phase 6 bis ; points de vigilance « phase 6 bis » et « phase 11 »)

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, indentation par tabulations.
- Solo strictement identique : toutes les vérifications du smoke test gardent leur sens ; seule leur façon d'atteindre le joueur change.
- Fichiers de la phase (5) : `tests/unitaires.gd`, `tests/smoke_test.gd`, `Scripts/GameState.gd`, `Scripts/Main.gd`, `tests/screenshots.gd`.
- **Toujours lancer un test Godot avec un délai maximal** (une erreur de script bloque le processus headless) :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; ( godot --headless --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd` pour les tests unitaires ; un test qui passe n'affiche que ses deux lignes `== … ==`).
- Toute modification du smoke test se valide sur **5 passages consécutifs verts**.
- Commits en français, terminés par la ligne `Co-Authored-By:` qu'impose l'environnement de l'auteur du commit.

## Review Focus

1. **Aucun lecteur oublié** : plus aucune référence à un membre de façade dans `Scripts/` ni `tests/` (y compris via les alias `GS.` et `gs.`), et `GameState` n'expose plus ces membres. → test unitaire « GameState n'expose plus l'état par joueur » + grep de sortie (Task 2).
2. **Secousse de l'écran au coup** : `Main` l'obtient désormais du `touche` du joueur local. → la vérification existante « la caméra tremble » reste verte (Task 2).
3. **Abonnement d'`Audio`** : l'invariant « `joueurs` n'est jamais réassigné » reste écrit, avec sa vraie raison (l'abonnement d'`Audio` pour toute la session). → relecture du diff (Task 2).
4. **`tests/screenshots.gd`**, que la CI ne lance pas : il compile et n'utilise plus la façade. → `--check-only` + grep (Task 2).
5. **Délégation restante** : `signaler_progression` laisse la victoire aux règles branchées, et `prochain_index_couleur` suit le joueur local jusqu'à épuisement des couleurs. → tests unitaires (Task 1).

---

### Task 1 : les tests passent à l'API directe

**Files:**
- Modify: `tests/unitaires.gd`
- Modify: `tests/smoke_test.gd`

**Interfaces:**
- Consumes : `GameState.joueur_local()`, `GameState.regles` (`pastille_ramassee(joueur, index) -> bool`, `coeur_ramasse(joueur) -> bool`), `GameState.prochain_index_couleur()`, `GameState.terminer_partie(victoire)`, `GameState._process(delta)` ; `Joueur` (membres et signal `touche`).
- Produces : aucun test n'utilise plus la façade ; les tests passent **avant et après** la Task 2.

- [ ] **Step 1 : `tests/unitaires.gd`, test de `GameState`**

1a. Dans `_run`, remplacer `	_tester_facade_game_state()` par `	_tester_game_state()`.

1b. Remplacer toute la fonction `_tester_facade_game_state()` (de la ligne `func _tester_facade_game_state() -> void:` jusqu'aux deux lignes `	gs.partie_en_cours = false` / `	gs.pret = false` qui la terminent, juste avant `func _tester_commandes()`) par :

```gdscript
func _tester_game_state() -> void:
	print("-- GameState (état de partie)")
	var gs: Node = root.get_node("GameState")
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	_check(gs.joueurs.size() == 1 and gs.joueur_local() == gs.joueurs[0], "en solo, un seul joueur, qui est le joueur local")
	var j: Joueur = gs.joueur_local()
	_check(j.vies == 3, "nouvelle_partie donne au joueur les vies de la difficulté")

	# Prochaine couleur à offrir (lue par le Spawner)
	_check(gs.prochain_index_couleur() == 0, "sans couleur, la prochaine pastille est la première")
	j.debloquer_couleur(gs.couleur(0))
	_check(gs.prochain_index_couleur() == 1, "prochain_index_couleur suit les couleurs du joueur local")
	for i in range(1, gs.nb_couleurs_total()):
		j.debloquer_couleur(gs.couleur(i))
	_check(gs.prochain_index_couleur() == -1, "toutes les couleurs débloquées : plus de pastille à offrir")

	# Les minuteries du joueur ne tournent qu'en partie, une fois prêt
	j.bonus_restant = 0.5
	j.invulnerable_restant = 0.25
	gs.pret = false
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.25) and is_equal_approx(j.bonus_restant, 0.5), "pendant l'intro, les minuteries ne décomptent pas")
	gs.pret = true
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.05) and is_equal_approx(j.bonus_restant, 0.3), "une fois prêt, GameState fait avancer le joueur")
	gs.terminer_partie(false)
	j.invulnerable_restant = 0.4
	j.bonus_restant = 0.6
	gs._process(0.2)
	_check(is_equal_approx(j.invulnerable_restant, 0.4) and is_equal_approx(j.bonus_restant, 0.6),
		"après la fin de partie, les minuteries ne décomptent plus")

	# Nouvelle partie : repart de zéro
	j.activer_bonus(8.0)
	j.coups_recus = 2
	gs.nouvelle_partie()
	_check(j.couleurs_debloquees.is_empty() and j.vies == 3 and j.coups_recus == 0 and not j.bonus_actif(),
		"nouvelle_partie remet le joueur local à zéro")
	gs.partie_en_cours = false
	gs.pret = false
```

- [ ] **Step 2 : `tests/unitaires.gd`, règles solo**

Dans `_tester_regles_solo()`, remplacer :

```gdscript
	gs.lion_touche.connect(sur_touche_locale)
	r.lion_touche_par_ennemi(j, Vector2(3, 4))
	_check(j.vies == 2 and j.est_invulnerable() and local.vies == 3 and touches_locales.is_empty(),
		"un coup d'ennemi touche le joueur reçu, pas le joueur local, sans déclencher son relai lion_touche")
	gs.lion_touche.disconnect(sur_touche_locale)
```

par :

```gdscript
	local.touche.connect(sur_touche_locale)
	r.lion_touche_par_ennemi(j, Vector2(3, 4))
	_check(j.vies == 2 and j.est_invulnerable() and local.vies == 3 and touches_locales.is_empty(),
		"un coup d'ennemi touche le joueur reçu, pas le joueur local, et ne lui signale aucun coup")
	local.touche.disconnect(sur_touche_locale)
```

- [ ] **Step 3 : `tests/unitaires.gd`, délégation**

Remplacer toute la fonction `_tester_delegation_regles()` (jusqu'à la fin du fichier) par :

```gdscript
func _tester_delegation_regles() -> void:
	print("-- GameState délègue aux règles")
	var gs: Node = root.get_node("GameState")
	_check(gs.regles is ReglesSolo, "par défaut, GameState applique les règles du solo")
	var solo: Regles = gs.regles
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	gs.pret = true
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)

	# Des règles sans effet : la victoire ne vient plus de GameState
	gs.regles = Regles.new(gs)
	gs.signaler_progression(1.0)
	_check(fins.is_empty() and gs.partie_en_cours and is_equal_approx(gs.progression, 1.0),
		"signaler_progression enregistre toujours la progression mais laisse la victoire aux règles branchées")

	# Retour aux règles du solo : la même progression gagne la partie
	gs.regles = solo
	gs.signaler_progression(1.0)
	_check(fins == [true] and not gs.partie_en_cours, "avec les règles du solo, la même progression gagne la partie")

	gs.partie_terminee.disconnect(sur_fin)
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false
```

- [ ] **Step 4 : `tests/smoke_test.gd`, alias du joueur local**

4a. Juste après la ligne `var GS: Node`, ajouter :

```gdscript
var JL: Joueur  # le joueur local (unique en solo)
```

4b. Juste après la ligne `	GS = root.get_node("GameState")`, ajouter :

```gdscript
	JL = GS.joueur_local()
```

4c. Remplacer les accès à la façade, **dans cet ordre** :

```sh
sed -i '' -E \
  -e 's/GS\.gagner_vie\(\)/GS.regles.coeur_ramasse(JL)/g' \
  -e 's/GS\.debloquer_couleur\(([0-9]+)\)/GS.regles.pastille_ramassee(JL, \1)/g' \
  -e 's/GS\.lion_touche\./JL.touche./g' \
  -e 's/GS\.(couleurs_debloquees|bonus_actif|bonus_restant|vies|est_invulnerable|invulnerable_restant|coups_recus|activer_bonus)/JL.\1/g' \
  tests/smoke_test.gd
```

Puis relire `git diff tests/smoke_test.gd` : les remplacements doivent tomber exactement sur les lignes qui lisaient la façade (vérifications de pastille, d'étoile, de vies et de cœurs, bilan de défaite, nouvelle partie Métropole, peinture de la Métropole, boss, Hardcore, section multi-lions) et nulle part ailleurs. Aucune ligne `GS.difficulte().vies` ni `GS.VIES_MAX` ne doit avoir changé.

- [ ] **Step 5 : Vérifier**

Run : `grep -nE "(GS|gs)\.(couleurs_debloquees|vies|coups_recus|invulnerable_restant|bonus_restant|est_invulnerable|toucher_lion|gagner_vie|debloquer_couleur|bonus_actif|activer_bonus|couleur_debloquee|bonus_change|vies_changees|lion_touche)" tests/unitaires.gd tests/smoke_test.gd` → aucune ligne (attention : `gs.VIES_MAX` et `GS.difficulte().vies` ne correspondent pas au motif, c'est voulu).

Puis `tests/unitaires.gd` avec délai (vert) et **5 passages** consécutifs du smoke test (verts) : la façade existe encore, les tests ne l'utilisent simplement plus.

- [ ] **Step 6 : Commit**

```bash
git add tests/unitaires.gd tests/smoke_test.gd
git commit -m "Tests : passent à l'API directe (joueur local, règles, signaux du joueur) au lieu de la façade

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 2 : suppression de la façade

**Files:**
- Modify: `tests/unitaires.gd` (test d'absence)
- Modify: `Scripts/GameState.gd`
- Modify: `Scripts/Main.gd:35`
- Modify: `tests/screenshots.gd:46,58,68-70,94,96,114`

**Interfaces:**
- Consumes : Task 1 (plus aucun test sur la façade).
- Produces : `GameState` sans les propriétés `couleurs_debloquees`, `vies`, `coups_recus`, `invulnerable_restant`, `bonus_restant`, sans les méthodes `est_invulnerable`, `toucher_lion`, `gagner_vie`, `debloquer_couleur`, `bonus_actif`, `activer_bonus`, sans les signaux `couleur_debloquee`, `bonus_change`, `vies_changees`, `lion_touche`, et sans `_ready`. `prochain_index_couleur()` reste, sur `joueur_local()`.

- [ ] **Step 1 : Test d'absence de la façade (qui échoue)**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_delegation_regles()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_delegation_regles()
	_tester_facade_retiree()
	print("== %d échec(s) ==" % _echecs)
```

et ajouter à la fin du fichier :

```gdscript
func _tester_facade_retiree() -> void:
	print("-- GameState sans façade")
	var gs: Node = root.get_node("GameState")
	var restes: Array[String] = []
	for nom in ["couleurs_debloquees", "vies", "coups_recus", "invulnerable_restant", "bonus_restant"]:
		if nom in gs:
			restes.append(nom)
	for nom in ["est_invulnerable", "toucher_lion", "gagner_vie", "debloquer_couleur", "bonus_actif", "activer_bonus"]:
		if gs.has_method(nom):
			restes.append(nom + "()")
	for nom in ["couleur_debloquee", "bonus_change", "vies_changees", "lion_touche"]:
		if gs.has_signal(nom):
			restes.append("signal " + nom)
	_check(restes.is_empty(), "GameState n'expose plus l'état par joueur (restes : %s)" % [restes])
```

Run : `tests/unitaires.gd` avec délai → cette seule vérification échoue (`❌`, restes listés).

- [ ] **Step 2 : `Scripts/GameState.gd`**

2a. Remplacer les lignes de docstring 3 à 5 :

```gdscript
## État global d'une partie : joueurs, progression de la peinture, chrono, fin de partie.
## L'état propre à chaque lion vit dans `Joueur` ; les propriétés et méthodes marquées
## « façade » délèguent au joueur local le temps que les appelants migrent (phases 2 à 6).
```

par :

```gdscript
## État global d'une partie : joueurs, règles, progression de la peinture, chrono, fin de partie.
## L'état propre à chaque lion vit dans `Joueur` ; les effets du jeu sont décidés par `regles`.
```

2b. Supprimer les quatre lignes de signal `signal couleur_debloquee(couleur: Color)`, `signal bonus_change(actif: bool)`, `signal vies_changees(vies: int)` et `signal lion_touche(origine: Vector2)` (garder `progression_changee`, `partie_terminee`, `partie_prete`).

2c. Remplacer :

```gdscript
## Le tableau doit être rempli ou réinitialisé en place (append, resize, etc.) et jamais
## réassigné : les relais de signaux de la façade sont liés à `joueurs[0]` dans `_ready`
## (jusqu'à la phase 6), et une réassignation les rendrait muets sans erreur.
```

par :

```gdscript
## Le tableau doit être rempli ou réinitialisé en place (append, resize, etc.) et jamais
## réassigné : `Audio` s'abonne une fois pour toute la session au joueur local (`joueurs[0]`),
## une réassignation rendrait son son de pastille muet sans erreur (voir la phase 11 de la
## feuille de route).
```

2d. Supprimer tout le bloc qui commence par `# Façade : état du joueur local (supprimée en phase 6).` jusqu'à la dernière ligne du setter de `bonus_restant` incluse (les cinq propriétés `couleurs_debloquees`, `vies`, `coups_recus`, `invulnerable_restant`, `bonus_restant`), ainsi que la ligne vide qui le précède.

2e. Supprimer toute la fonction `_ready()` (l'`assert` et les quatre relais).

2f. Supprimer les fonctions `est_invulnerable()`, `toucher_lion()` (avec sa docstring « ## Façade : … »), `gagner_vie()`, `debloquer_couleur()`, `bonus_actif()` et `activer_bonus()` (avec sa docstring « ## Active (ou prolonge) … »).

2g. Remplacer :

```gdscript
func prochain_index_couleur() -> int:
	var i := couleurs_debloquees.size()
	return i if i < COULEURS_ARC_EN_CIEL.size() else -1
```

par :

```gdscript
## Prochaine couleur de l'arc-en-ciel à offrir au joueur local (-1 si toutes sont débloquées).
## Règle du solo, lue par le Spawner (en bataille, les apparitions passeront par les règles).
func prochain_index_couleur() -> int:
	var i := joueur_local().couleurs_debloquees.size()
	return i if i < COULEURS_ARC_EN_CIEL.size() else -1
```

Garder deux lignes vides entre les fonctions, comme le reste du fichier.

- [ ] **Step 3 : `Scripts/Main.gd`**

3a. Remplacer :

```gdscript
	GameState.lion_touche.connect(func(_o: Vector2) -> void: trembler())
```

par :

```gdscript
	GameState.joueur_local().touche.connect(_on_lion_touche)
```

3b. Juste après la fonction `trembler()`, ajouter :

```gdscript


## Le lion du joueur local est touché : l'écran tremble.
func _on_lion_touche(_origine: Vector2) -> void:
	trembler()
```

(une méthode liée plutôt qu'un lambda : la connexion au `Joueur`, qui survit aux parties, tombe d'elle-même quand `Main` est libéré.)

- [ ] **Step 4 : `tests/screenshots.gd`**

```sh
sed -i '' -E \
  -e 's/GS\.debloquer_couleur\(([a-z0-9_]+)\)/GS.regles.pastille_ramassee(GS.joueur_local(), \1)/g' \
  -e 's/GS\.toucher_lion\((Vector2\.INF)?\)/GS.regles.lion_touche_par_ennemi(GS.joueur_local(), Vector2.INF)/g' \
  -e 's/GS\.activer_bonus\(/GS.joueur_local().activer_bonus(/g' \
  -e 's/GS\.invulnerable_restant/GS.joueur_local().invulnerable_restant/g' \
  tests/screenshots.gd
```

Relire `git diff tests/screenshots.gd` : 8 remplacements (4 pastilles, 2 coups, 1 étoile, 1 invulnérabilité), rien d'autre.

- [ ] **Step 5 : Vérification complète**

```sh
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
godot --headless --check-only --script tests/screenshots.gd 2>&1 | grep -E "ERROR|Error" || echo "screenshots.gd compile"
grep -rnE "GameState\.(couleurs_debloquees|vies|coups_recus|invulnerable_restant|bonus_restant|est_invulnerable|toucher_lion|gagner_vie|debloquer_couleur|bonus_actif|activer_bonus|couleur_debloquee|bonus_change|vies_changees|lion_touche)" Scripts tests
grep -rnE "(GS|gs)\.(couleurs_debloquees|vies|coups_recus|invulnerable_restant|bonus_restant|est_invulnerable|toucher_lion|gagner_vie|debloquer_couleur|bonus_actif|activer_bonus|couleur_debloquee|bonus_change|vies_changees|lion_touche)" tests
```

Expected : rien pour l'import ; « screenshots.gd compile » ; aucune ligne pour les deux grep. Puis `tests/unitaires.gd` avec délai (vert, y compris « GameState n'expose plus l'état par joueur ») et **5 passages** consécutifs du smoke test (verts, dont « la caméra tremble »).

- [ ] **Step 6 : Commit**

```bash
git add tests/unitaires.gd Scripts/GameState.gd Scripts/Main.gd tests/screenshots.gd
git commit -m "GameState : fin de la façade, il ne porte plus que l'état de partie ; Main tremble sur le coup du joueur local

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

## Sortie de phase

- Les deux suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR`, localement (smoke test 5 fois) puis en CI sur la PR.
- `tests/screenshots.gd` compile (`--check-only`) ; un passage réel avec rendu (`godot --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier=…`) reste à faire à la main par l'utilisateur, la CI ne le lance pas.
- Le socle A (phases 1 à 6 bis) est terminé : la feuille de route passe au bloc B (bataille hors réseau).
