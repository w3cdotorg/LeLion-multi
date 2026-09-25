# Phase 4 : ennemis et pastille vers les règles, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Les ennemis (soucoupe, coccinelle, peintre) et la pastille de couleur signalent aux règles **le lion qu'ils touchent** (son `Joueur`), au lieu de supposer que c'est le joueur local. Aucun changement de comportement du solo.

**Architecture:** chaque script appelle `GameState.regles.<événement>(body.joueur, …)` là où il appelait la façade `GameState.toucher_lion(…)` / `GameState.debloquer_couleur(…)`. Les règles (phase 3) agissent sur le joueur reçu ; pour le lion local, le retour visuel (flash du HUD, secousse) passe toujours par les relais de `GameState` ; pour un autre lion, il n'y en a pas.

**Tech Stack:** Godot 4.7.2, GDScript, smoke test headless.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1, `Regles`) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`

**Écart assumé avec la feuille de route** (mise à jour dans le commit de ce plan) : `BonusPickup` passe en phase 5. La vérification de la phase doit aller dans `tests/smoke_test.gd` (il faut de vrais ennemis et de vrais lions), ce qui fait déjà 5 fichiers avec les 4 scripts. Les phases 5, 6 et « 6 bis » sont rééquilibrées en conséquence.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, indentation par tabulations.
- Solo strictement identique : les vérifications existantes de `tests/smoke_test.gd` ne changent pas ; la phase ajoute seulement une section.
- Fichiers de la phase (5) : `Scripts/Soucoupe.gd`, `Scripts/Coccinelle.gd`, `Scripts/Boss.gd`, `Scripts/ColorPickup.gd`, `tests/smoke_test.gd`. `Scripts/BonusPickup.gd` n'est **pas** modifié (phase 5).
- **Toujours lancer un test Godot avec un délai maximal** (une erreur de script bloque le processus headless) :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; ( godot --headless --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd` pour les tests unitaires ; un test qui passe n'affiche que ses deux lignes `== … ==`).
- Commits en français, terminés par la ligne `Co-Authored-By:` qu'impose l'environnement de l'auteur du commit.

## Review Focus

1. **Un ennemi qui touche un autre lion** retire une vie au joueur de ce lion, pas au joueur local, et ne déclenche aucun retour visuel du joueur local (`GameState.lion_touche` muet). → section du smoke test (coccinelle et soucoupe).
2. **Une pastille ramassée par un autre lion** va à son joueur et disparaît. → section du smoke test.
3. **Le peintre du Village** garde ses deux chemins de contact (entrée dans la zone, et chevauchement continu hors repos) avec la même origine de recul `(x du peintre, y du lion)`. → la vérification existante « le boss blesse le lion au passage » reste verte.
4. **Coup fatal d'un autre lion pendant le test** : la section ne doit jamais amener `autre` à 0 vie, sinon `terminer_partie(false)` ouvrirait l'écran de fin sur la scène encore présente. → `autre.vies = 3` avant les deux coups.
5. **Solo inchangé** : toutes les vérifications existantes (coccinelle, soucoupe pendant l'invulnérabilité, pastille, boss, Hardcore) restent vertes.

---

### Task 1 : ennemis et pastille signalent le lion touché aux règles

**Files:**
- Modify: `tests/smoke_test.gd` (section « Un lion lié à un autre joueur », avant `lion_autre.free()`)
- Modify: `Scripts/Soucoupe.gd:13-15`
- Modify: `Scripts/Coccinelle.gd:40-42`
- Modify: `Scripts/Boss.gd:53-60`
- Modify: `Scripts/ColorPickup.gd:11-15`

**Interfaces:**
- Consumes : `GameState.regles: Regles` avec `lion_touche_par_ennemi(joueur: Joueur, origine: Vector2) -> void` et `pastille_ramassee(joueur: Joueur, index_couleur: int) -> bool` (phase 3) ; `Lion.joueur: Joueur` (phase 2) ; tout corps du groupe `"lion"` est une instance de `Lion.tscn`, donc a un `joueur`.
- Produces : plus aucun appel à `GameState.toucher_lion` ni à `GameState.debloquer_couleur` dans ces quatre scripts (la façade reste pour `CoeurPickup`, `BonusPickup` et les tests jusqu'aux phases 5 et 6 bis).

- [ ] **Step 1 : Ajouter la section de smoke test (qui échoue)**

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	lion_autre.commandes.vomir_voulu = false
	await _frames(2)
	lion_autre.free()
```

par :

```gdscript
	lion_autre.commandes.vomir_voulu = false
	await _frames(2)

	# Ennemis et pastilles signalent le lion qu'ils touchent, pas le joueur local
	var local: Joueur = GS.joueur_local()
	var vies_local: int = local.vies
	var couleurs_local: int = local.couleurs_debloquees.size()
	var touches_locales: Array[Vector2] = []
	var sur_touche_locale := func(o: Vector2) -> void: touches_locales.append(o)
	GS.lion_touche.connect(sur_touche_locale)
	GS.partie_en_cours = true  # la partie Hardcore est finie : les règles ignorent les coups hors partie
	lion_autre.commandes.direction_voulue = Vector2.ZERO
	lion_autre.global_position = Vector2(1400, 300)  # loin du lion local, resté dans la scène
	await _frames(1)
	autre.vies = 3  # deux coups à venir : jamais le coup fatal, qui terminerait la partie
	autre.invulnerable_restant = 0.0
	var centre_autre: Vector2 = lion_autre.global_position + Vector2(68, 66)
	var coccinelle_autre: Node2D = load("res://Scenes/Coccinelle.tscn").instantiate()
	coccinelle_autre.position = centre_autre
	root.add_child(coccinelle_autre)
	await _frames(3)
	_check(autre.vies == 2 and local.vies == vies_local and touches_locales.is_empty(),
		"une coccinelle retire une vie au joueur du lion touché, pas au joueur local")
	coccinelle_autre.queue_free()
	autre.invulnerable_restant = 0.0
	var soucoupe_autre: Node2D = load("res://Scenes/Soucoupe.tscn").instantiate()
	soucoupe_autre.position = centre_autre
	root.add_child(soucoupe_autre)
	await _frames(3)
	_check(autre.vies == 1 and local.vies == vies_local and touches_locales.is_empty(),
		"une soucoupe retire une vie au joueur du lion touché, pas au joueur local")
	soucoupe_autre.queue_free()
	var pastille_autre: Node2D = load("res://Scenes/ColorPickup.tscn").instantiate()
	pastille_autre.couleur_index = 4
	pastille_autre.position = centre_autre
	root.add_child(pastille_autre)
	await _frames(3)
	_check(not is_instance_valid(pastille_autre) and autre.couleurs_debloquees.has(GS.couleur(4))
		and local.couleurs_debloquees.size() == couleurs_local,
		"une pastille ramassée par un lion va à son joueur, pas au joueur local")
	GS.lion_touche.disconnect(sur_touche_locale)
	GS.partie_en_cours = false
	lion_autre.free()
```

- [ ] **Step 2 : Lancer le smoke test pour le voir échouer**

Run : commande avec délai des Global Constraints, `T=tests/smoke_test.gd`.
Expected : les trois nouvelles vérifications échouent (`❌`) : les ennemis frappent le joueur local (façade) au lieu d'`autre`, et la pastille débloque la couleur chez le joueur local. Le reste est vert.

- [ ] **Step 3 : `Scripts/Soucoupe.gd`**

Remplacer :

```gdscript
	if body.is_in_group("lion"):
		GameState.toucher_lion(global_position)
```

par :

```gdscript
	if body.is_in_group("lion"):
		GameState.regles.lion_touche_par_ennemi(body.joueur, global_position)
```

- [ ] **Step 4 : `Scripts/Coccinelle.gd`**

Même remplacement que la Step 3 (le bloc est identique dans `_on_body_entered`).

- [ ] **Step 5 : `Scripts/Boss.gd`**

Remplacer les **deux** occurrences de :

```gdscript
GameState.toucher_lion(Vector2(global_position.x, body.global_position.y))
```

(l'une dans `_physics_process`, l'autre dans `_on_body_entered`, à l'indentation près) par :

```gdscript
GameState.regles.lion_touche_par_ennemi(body.joueur, Vector2(global_position.x, body.global_position.y))
```

en conservant l'indentation de chaque occurrence.

- [ ] **Step 6 : `Scripts/ColorPickup.gd`**

Remplacer :

```gdscript
	GameState.debloquer_couleur(couleur_index)
	queue_free()
```

par :

```gdscript
	GameState.regles.pastille_ramassee(body.joueur, couleur_index)
	queue_free()
```

Et remplacer la docstring de tête `## Pastille qui débloque une couleur de l'arc-en-ciel quand le lion la touche.` par `## Pastille ramassée par le lion qui la touche ; son effet dépend des règles (en solo, une couleur de l'arc-en-ciel).`

- [ ] **Step 7 : Vérifier qu'il ne reste aucun appel à la façade dans ces scripts**

Run : `grep -n "toucher_lion\|debloquer_couleur" Scripts/Soucoupe.gd Scripts/Coccinelle.gd Scripts/Boss.gd Scripts/ColorPickup.gd`
Expected : aucune ligne. Et `grep -n "regles\." Scripts/Soucoupe.gd Scripts/Coccinelle.gd Scripts/Boss.gd Scripts/ColorPickup.gd` : exactement 5 lignes (1 + 1 + 2 + 1).

- [ ] **Step 8 : Vérification complète**

Run : `godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"`, puis les deux suites avec délai.
Expected : rien pour l'import ; `tests/unitaires.gd` et `tests/smoke_test.gd` n'affichent que leurs lignes `== … ==` avec `== 0 échec(s) ==`.

- [ ] **Step 9 : Commit**

```bash
git add Scripts/Soucoupe.gd Scripts/Coccinelle.gd Scripts/Boss.gd Scripts/ColorPickup.gd tests/smoke_test.gd
git commit -m "Ennemis et pastille : ils signalent aux règles le joueur du lion touché

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

## Sortie de phase

- Les deux suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR`, localement puis en CI sur la PR.
- `git diff main --stat` : les 5 fichiers prévus et les documents.
