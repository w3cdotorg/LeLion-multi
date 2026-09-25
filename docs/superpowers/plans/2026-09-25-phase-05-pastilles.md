# Phase 5 : étoile, cœur et apparitions, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** L'étoile et le cœur passent par les règles avec le joueur du lion qui les ramasse (premier arrivé, premier servi, décidé par l'hôte), le doublon de durée de l'étoile disparaît, et le Spawner lit explicitement le joueur local au lieu de la façade. Aucun changement de comportement du solo.

**Architecture:** même schéma que `ColorPickup` en phase 4 : garde `multiplayer.is_server()`, drapeau `_ramassee`, appel `GameState.regles.<événement>(body.joueur)`. `ReglesSolo.DUREE_ETOILE` devient la seule durée de l'étoile. Le Spawner décide des apparitions d'après `GameState.joueur_local()` (en solo, l'unique joueur ; la phase 10 traitera plusieurs lions).

**Tech Stack:** Godot 4.7.2, GDScript, smoke test headless.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§2 : étoile XXL par joueur, premier arrivé premier servi ; §3 : l'hôte fait autorité) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (phase 5 et points de vigilance)

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, indentation par tabulations.
- Solo strictement identique : les vérifications existantes de `tests/smoke_test.gd` ne changent pas ; la phase ajoute des vérifications.
- Fichiers de la phase (5) : `Scripts/BonusPickup.gd`, `Scripts/CoeurPickup.gd`, `Scripts/ReglesSolo.gd`, `Scripts/Spawner.gd`, `tests/smoke_test.gd`.
- `GameState.prochain_index_couleur()` (lu par le Spawner) reste tel quel : il sera revu avec la façade en phase 6 bis.
- **Toujours lancer un test Godot avec un délai maximal** (une erreur de script bloque le processus headless) :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; ( godot --headless --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd` pour les tests unitaires ; un test qui passe n'affiche que ses deux lignes `== … ==`).
- Commits en français, terminés par la ligne `Co-Authored-By:` qu'impose l'environnement de l'auteur du commit.

## Review Focus

1. **Étoile ramassée par un autre lion** : la gerbe XXL de son joueur s'active pour `ReglesSolo.DUREE_ETOILE`, pas celle du joueur local. → vérification (Task 1).
2. **Premier arrivé, premier servi** : deux lions qui touchent le même cœur dans la même frame, un seul en profite. → vérification avec deux contacts successifs, le second venant du lion local (Task 1).
3. **Une seule durée d'étoile** : plus aucune constante `DUREE_BONUS` ; si quelqu'un change `DUREE_ETOILE`, l'étoile suit. → grep + vérification (Task 1).
4. **Spawner** : l'étoile n'apparaît qu'à partir de 2 couleurs et hors gerbe XXL, le cœur seulement sous le maximum de vies, pour le joueur local, comme avant. → relecture du diff (Task 2) ; les vérifications existantes du solo restent vertes.
5. **Solo inchangé** : « l'étoile ramassée active la gerbe XXL », « un cœur ramassé rend une vie », « impossible de dépasser le maximum de vies » restent vertes.

---

### Task 1 : étoile et cœur passent par les règles

**Files:**
- Modify: `tests/smoke_test.gd` (section « Ennemis et pastilles signalent le lion qu'ils touchent », juste avant `GS.lion_touche.disconnect(sur_touche_locale)`)
- Modify: `Scripts/BonusPickup.gd`
- Modify: `Scripts/CoeurPickup.gd`
- Modify: `Scripts/ReglesSolo.gd:6-8`

**Interfaces:**
- Consumes : `GameState.regles.etoile_ramassee(joueur: Joueur) -> void`, `GameState.regles.coeur_ramasse(joueur: Joueur) -> bool` (phase 3) ; `ReglesSolo.DUREE_ETOILE` ; `Lion.joueur`.
- Produces : `BonusPickup` et `CoeurPickup` n'appellent plus la façade (`activer_bonus`, `gagner_vie`) ; `BonusPickup.DUREE_BONUS` n'existe plus.

- [ ] **Step 1 : Ajouter les vérifications (qui échouent)**

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	GS.lion_touche.disconnect(sur_touche_locale)
	GS.partie_en_cours = false
	local.vies = vies_local_avant
```

par :

```gdscript
	var bonus_local: bool = local.bonus_actif()
	autre.bonus_restant = 0.0
	var etoile_autre: Node2D = load("res://Scenes/BonusPickup.tscn").instantiate()
	etoile_autre.position = centre_autre
	root.add_child(etoile_autre)
	await _frames(3)
	_check(not is_instance_valid(etoile_autre) and autre.bonus_actif()
		and is_equal_approx(autre.bonus_restant, ReglesSolo.DUREE_ETOILE) and local.bonus_actif() == bonus_local,
		"une étoile ramassée par un lion active la gerbe XXL de son joueur, pas celle du joueur local")
	var coeur_autre: Node2D = load("res://Scenes/CoeurPickup.tscn").instantiate()
	coeur_autre.position = Vector2(-500, -500)  # hors d'atteinte : les contacts sont simulés à la main
	root.add_child(coeur_autre)
	await _frames(1)
	autre.vies = 1
	local.vies = 2
	coeur_autre._on_body_entered(lion_autre)
	coeur_autre._on_body_entered(main.get_node("Lion"))  # le lion local touche le même cœur dans la même frame
	_check(autre.vies == 2 and local.vies == 2, "premier arrivé, premier servi : un seul lion profite d'un cœur touché par deux lions")
	await _frames(1)
	_check(not is_instance_valid(coeur_autre), "le cœur ramassé disparaît")
	GS.lion_touche.disconnect(sur_touche_locale)
	GS.partie_en_cours = false
	local.vies = vies_local_avant
```

(Le texte exact de la ligne `local.vies = vies_local_avant` porte un commentaire en fin de ligne dans le fichier ; conserver ce commentaire.)

- [ ] **Step 2 : Lancer le smoke test pour le voir échouer**

Run : commande avec délai, `T=tests/smoke_test.gd`.
Expected : les deux vérifications « étoile ramassée par un lion » et « premier arrivé, premier servi » échouent (`❌`) : l'étoile active la gerbe du joueur local (façade) et le cœur rend une vie au joueur local, deux fois de suite.

- [ ] **Step 3 : `Scripts/BonusPickup.gd`**

3a. Supprimer la ligne `const DUREE_BONUS := 8.0`.

3b. Juste après `var _temps := 0.0`, ajouter :

```gdscript
var _ramassee := false
```

3c. Remplacer :

```gdscript
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("lion"):
		return
	GameState.activer_bonus(DUREE_BONUS)
	Audio.jouer("pickup")
	queue_free()
```

par :

```gdscript
## Les contacts ne sont tranchés que par l'hôte (en solo, le poste est son propre hôte).
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	if not body.is_in_group("lion"):
		return
	if _ramassee:  # premier arrivé, premier servi : queue_free() est différé
		return
	_ramassee = true
	GameState.regles.etoile_ramassee(body.joueur)
	Audio.jouer("pickup")
	queue_free()
```

- [ ] **Step 4 : `Scripts/CoeurPickup.gd`**

4a. Juste après `var _temps := 0.0`, ajouter `var _ramassee := false`.

4b. Remplacer :

```gdscript
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("lion"):
		return
	GameState.gagner_vie()
	Audio.jouer("pickup")
	queue_free()
```

par :

```gdscript
## Les contacts ne sont tranchés que par l'hôte (en solo, le poste est son propre hôte).
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	if not body.is_in_group("lion"):
		return
	if _ramassee:  # premier arrivé, premier servi : queue_free() est différé
		return
	_ramassee = true
	GameState.regles.coeur_ramasse(body.joueur)
	Audio.jouer("pickup")
	queue_free()
```

- [ ] **Step 5 : `Scripts/ReglesSolo.gd`**

Remplacer :

```gdscript
## `BonusPickup` applique encore ses propres 8 secondes via `GameState.activer_bonus`, en plus de
## celles-ci : ce doublon ne sera retiré qu'en phase 4.
const DUREE_ETOILE := 8.0
```

par :

```gdscript
## Durée de la gerbe XXL donnée par une étoile.
const DUREE_ETOILE := 8.0
```

- [ ] **Step 6 : Vérifier**

Run : `grep -rn "DUREE_BONUS\|activer_bonus\|gagner_vie" Scripts/BonusPickup.gd Scripts/CoeurPickup.gd` → aucune ligne. `grep -n "is_server\|_ramassee" Scripts/BonusPickup.gd Scripts/CoeurPickup.gd` → dans chaque fichier, une garde `is_server`, la déclaration du drapeau, son test et son affectation.

Puis `godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` (rien) et les deux suites avec délai : uniquement leurs lignes `== … ==`, `== 0 échec(s) ==`.

Contrôle par mutation (à consigner dans le rapport, sans le commiter) : remettre temporairement dans `BonusPickup.gd` l'appel `GameState.activer_bonus(8.0)` à la place de `GameState.regles.etoile_ramassee(body.joueur)`, relancer le smoke test : la vérification de l'étoile doit échouer. Restaurer, relancer : vert.

- [ ] **Step 7 : Commit**

```bash
git add Scripts/BonusPickup.gd Scripts/CoeurPickup.gd Scripts/ReglesSolo.gd tests/smoke_test.gd
git commit -m "Étoile et cœur : ramassés par le lion qui les touche, via les règles, premier arrivé premier servi

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 2 : le Spawner lit le joueur local explicitement

**Files:**
- Modify: `Scripts/Spawner.gd:39,100,108`

**Interfaces:**
- Consumes : `GameState.joueur_local() -> Joueur` ; `Joueur.couleur_debloquee`, `couleurs_debloquees`, `bonus_actif()`, `vies` ; `GameState.VIES_MAX`.
- Produces : le Spawner ne lit plus `GameState.couleur_debloquee`, `GameState.couleurs_debloquees`, `GameState.bonus_actif()` ni `GameState.vies` (façade). `GameState.prochain_index_couleur()` reste (phase 6 bis).

- [ ] **Step 1 : Modifier `Scripts/Spawner.gd`**

1a. Remplacer :

```gdscript
func _ready() -> void:
	GameState.couleur_debloquee.connect(_on_couleur_debloquee)
```

par :

```gdscript
func _ready() -> void:
	# En solo, les apparitions suivent l'unique joueur, le joueur local (plusieurs lions : phase 10).
	GameState.joueur_local().couleur_debloquee.connect(_on_couleur_debloquee)
```

1b. Remplacer :

```gdscript
	if GameState.couleurs_debloquees.size() >= couleurs_requises_bonus and not GameState.bonus_actif():
```

par :

```gdscript
	var joueur := GameState.joueur_local()
	if joueur.couleurs_debloquees.size() >= couleurs_requises_bonus and not joueur.bonus_actif():
```

1c. Remplacer :

```gdscript
	if GameState.vies < GameState.VIES_MAX and get_tree().get_first_node_in_group("coeur_pickup") == null:
```

par :

```gdscript
	if GameState.joueur_local().vies < GameState.VIES_MAX and get_tree().get_first_node_in_group("coeur_pickup") == null:
```

- [ ] **Step 2 : Vérifier**

Run : `grep -nE "GameState\.(couleur_debloquee\.|couleurs_debloquees|bonus_actif|vies <)" Scripts/Spawner.gd` → aucune ligne ; `grep -n "joueur_local()" Scripts/Spawner.gd` → 3 lignes.

Puis l'import (rien) et les deux suites avec délai : `== 0 échec(s) ==`, aucune `SCRIPT ERROR`.

- [ ] **Step 3 : Commit**

```bash
git add Scripts/Spawner.gd
git commit -m "Spawner : décide des apparitions d'après le joueur local, sans passer par la façade

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

## Sortie de phase

- Les deux suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR`, localement puis en CI sur la PR.
- `git diff main --stat` : les 5 fichiers prévus et les documents.
