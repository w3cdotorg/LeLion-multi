# Phase 6 : abonnés du joueur (HUD, écran de fin, audio, traceuse), plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Plus aucun script du jeu (hors `GameState` lui-même, `Main` et `tests/screenshots.gd`, traités en phase 6 bis) ne lit l'état par joueur à travers la façade de `GameState`. Le HUD, l'écran de fin et l'audio suivent explicitement le joueur local ; la traceuse peint avec les couleurs du joueur de **son** lion. Aucun changement de comportement du solo.

**Architecture:** le HUD garde une référence `_joueur := GameState.joueur_local()` et s'abonne à ses signaux (`vies_changees`, `touche`, `couleur_debloquee`) ; l'écran de fin lit `GameState.joueur_local()` ; l'autoload `Audio` s'abonne au `couleur_debloquee` du joueur local (le `Joueur` est persistant, l'abonnement dure toute la session) ; `GerbeTraceuse` lit `get_parent().joueur`.

**Tech Stack:** Godot 4.7.2, GDScript, smoke test headless.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (phase 6 et points de vigilance, mis à jour dans le commit de ce plan avec les remarques de la revue finale de la phase 5)

**Report assumé** : l'unification des sons de ramassage (l'étoile et le cœur jouent leur son dans le gestionnaire réservé à l'hôte, la pastille via `Audio` et le signal du joueur local) touche `BonusPickup` et `CoeurPickup`, hors de cette phase. Elle n'a d'effet qu'avec de vrais clients : elle est reportée à la phase 14 (point de vigilance ajouté).

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, indentation par tabulations.
- Solo strictement identique : les vérifications existantes de `tests/smoke_test.gd` ne changent pas ; la phase ajoute une vérification et durcit la section multi-lions.
- Fichiers de la phase (5) : `Scripts/HUD.gd`, `Scripts/GameOver.gd`, `Scripts/Audio.gd`, `Scripts/GerbeTraceuse.gd`, `tests/smoke_test.gd`.
- **Toujours lancer un test Godot avec un délai maximal** (une erreur de script bloque le processus headless) :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; ( godot --headless --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd` pour les tests unitaires ; un test qui passe n'affiche que ses deux lignes `== … ==`).
- La section multi-lions du smoke test a déjà été instable (restes d'une section précédente) : **toute modification du smoke test se valide sur 5 passages consécutifs verts**.
- Commits en français, terminés par la ligne `Co-Authored-By:` qu'impose l'environnement de l'auteur du commit.

## Review Focus

1. **La traceuse peint avec les couleurs du joueur de son lion** : un lion lié à un autre joueur ne dépose sur la ville aucune couleur que son joueur n'a pas, même si le joueur local en a d'autres. → vérification (Task 2).
2. **HUD** : cœurs, pastilles, flash rouge et étiquette XXL réagissent au joueur local exactement comme avant. → vérifications existantes (« le HUD grise le cœur perdu », « l'écran flashe en rouge », « le HUD affiche le bonus », pastilles) restent vertes.
3. **Écran de fin** : « cœurs perdus », « sans une égratignure » et le nombre de couleurs lisent le joueur local. → vérifications existantes du bilan restent vertes.
4. **Audio** : le son de pastille retentit toujours quand le joueur local débloque une couleur, une seule fois par couleur, sur toutes les parties successives (abonnement unique, pris par l'autoload au démarrage). → relecture du diff (Task 1) ; vérifications audio existantes.
5. **Stabilité** : la section multi-lions libère aussi le Spawner et le groupe `boss` hérités de la section Hardcore. → 5 passages consécutifs verts (Task 2).

---

### Task 1 : HUD, écran de fin et audio suivent le joueur local

**Files:**
- Modify: `Scripts/HUD.gd`
- Modify: `Scripts/GameOver.gd:124-128`
- Modify: `Scripts/Audio.gd:62`

**Interfaces:**
- Consumes : `GameState.joueur_local() -> Joueur` ; `Joueur` : signaux `vies_changees(vies: int)`, `touche(origine: Vector2)`, `couleur_debloquee(couleur: Color)` ; `vies`, `coups_recus`, `couleurs_debloquees`, `bonus_actif()`, `bonus_restant`.
- Produces : `HUD`, `GameOver` et `Audio` ne lisent plus `GameState.vies`, `coups_recus`, `couleurs_debloquees`, `bonus_actif()`, `bonus_restant`, ni les signaux `vies_changees`, `lion_touche`, `couleur_debloquee` de `GameState` (ces membres de façade disparaîtront en phase 6 bis).

- [ ] **Step 1 : `Scripts/HUD.gd`**

1a. Remplacer :

```gdscript
var _pastilles: Array[ColorRect] = []
var _coeurs: Array[TextureRect] = []


func _ready() -> void:
	for i in range(GameState.nb_couleurs_total()):
```

par :

```gdscript
var _pastilles: Array[ColorRect] = []
var _coeurs: Array[TextureRect] = []
## Le HUD du solo suit le joueur local (la bataille aura son propre HUD, phase 17).
var _joueur: Joueur


func _ready() -> void:
	_joueur = GameState.joueur_local()
	for i in range(GameState.nb_couleurs_total()):
```

1b. Remplacer :

```gdscript
	_on_vies_changees(GameState.vies)

	GameState.vies_changees.connect(_on_vies_changees)
	GameState.lion_touche.connect(_on_lion_touche)
	GameState.progression_changee.connect(_on_progression_changee)
	GameState.couleur_debloquee.connect(_on_couleur_debloquee)
```

par :

```gdscript
	_on_vies_changees(_joueur.vies)

	_joueur.vies_changees.connect(_on_vies_changees)
	_joueur.touche.connect(_on_lion_touche)
	GameState.progression_changee.connect(_on_progression_changee)
	_joueur.couleur_debloquee.connect(_on_couleur_debloquee)
```

1c. Remplacer `	for c in GameState.couleurs_debloquees:` par `	for c in _joueur.couleurs_debloquees:`.

1d. Dans `_process`, remplacer `GameState.bonus_actif()` par `_joueur.bonus_actif()` et `GameState.bonus_restant` par `_joueur.bonus_restant`.

1e. Dans `_on_couleur_debloquee`, remplacer `var index := GameState.couleurs_debloquees.find(couleur)` par `var index := _joueur.couleurs_debloquees.find(couleur)`.

- [ ] **Step 2 : `Scripts/GameOver.gd`**

Remplacer :

```gdscript
	var max_vies: int = GameState.difficulte().vies
	var sans_egratignure := victoire and GameState.coups_recus == 0
	_ajouter_ligne(tr("STAT_COEURS_PERDUS"), GameState.coups_recus, "%d / " + str(max_vies),
		tr("SANS_EGRATIGNURE") if sans_egratignure else "", COULEUR_MIEUX)
	_ajouter_ligne(tr("STAT_COULEURS"), GameState.couleurs_debloquees.size(), "%d / " + str(GameState.nb_couleurs_total()))
```

par :

```gdscript
	var max_vies: int = GameState.difficulte().vies
	var joueur := GameState.joueur_local()
	var sans_egratignure := victoire and joueur.coups_recus == 0
	_ajouter_ligne(tr("STAT_COEURS_PERDUS"), joueur.coups_recus, "%d / " + str(max_vies),
		tr("SANS_EGRATIGNURE") if sans_egratignure else "", COULEUR_MIEUX)
	_ajouter_ligne(tr("STAT_COULEURS"), joueur.couleurs_debloquees.size(), "%d / " + str(GameState.nb_couleurs_total()))
```

- [ ] **Step 3 : `Scripts/Audio.gd`**

Remplacer :

```gdscript
	GameState.couleur_debloquee.connect(func(_c: Color) -> void: jouer("pickup"))
```

par :

```gdscript
	# Son de pastille : le joueur local vient de débloquer une couleur. Le Joueur vit aussi
	# longtemps que GameState, l'abonnement est pris une fois pour toute la session.
	GameState.joueur_local().couleur_debloquee.connect(func(_c: Color) -> void: jouer("pickup"))
```

- [ ] **Step 4 : Vérifier**

Run : `grep -nE "GameState\.(vies|coups_recus|couleurs_debloquees|bonus_actif|bonus_restant|vies_changees|lion_touche|couleur_debloquee)" Scripts/HUD.gd Scripts/GameOver.gd Scripts/Audio.gd` → aucune ligne.

Puis `godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` (rien) et les deux suites avec délai : uniquement leurs lignes `== … ==`, `== 0 échec(s) ==`.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/HUD.gd Scripts/GameOver.gd Scripts/Audio.gd
git commit -m "HUD, écran de fin et audio : suivent le joueur local, sans passer par la façade

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 2 : la traceuse peint avec les couleurs de son lion ; section multi-lions durcie

**Files:**
- Modify: `tests/smoke_test.gd` (section « Un lion lié à un autre joueur », ≈ lignes 502-620)
- Modify: `Scripts/GerbeTraceuse.gd`

**Interfaces:**
- Consumes : `Lion.joueur: Joueur` (la traceuse est un enfant direct du lion, `Scenes/Lion.tscn`) ; `Ville.peindre(position_globale: Vector2, rayon: int, couleurs: Array[Color])`, `Ville.image: Image`.
- Produces : `GerbeTraceuse` ne lit plus `GameState`.

- [ ] **Step 1 : Adapter le smoke test (qui échoue)**

1a. Supprimer ces deux lignes de commentaire, devenues fausses :

```gdscript
	# La GerbeTraceuse de ce lion peint encore avec les couleurs du joueur local via la
	# façade GameState, jusqu'à la phase 6.
```

1b. Remplacer :

```gdscript
	for ennemi in get_nodes_in_group("ennemi"):
		ennemi.free()
```

par :

```gdscript
	for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss"):
		ennemi.free()
	# Le Spawner de la partie Hardcore a encore des apparitions programmées (minuteries) :
	# on le libère aussi, pour que rien d'autre que cette section n'agisse pendant qu'elle tourne.
	main.get_node("Spawner").free()
```

(et, dans le commentaire juste au-dessus qui se termine par « On libère tout ennemi encore en jeu avant de continuer. », remplacer cette dernière phrase par « On libère tout ennemi encore en jeu (et le peintre, s'il y en avait un) avant de continuer. »)

1c. Remplacer :

```gdscript
	_check(not is_instance_valid(coeur_autre), "le cœur ramassé disparaît")
```

par :

```gdscript
	_check(not is_instance_valid(coeur_autre), "le cœur ramassé disparaît")

	# La traceuse d'un lion peint avec les couleurs de son propre joueur
	var ville_hc: Node = main.get_node("Ville")
	_check(local.couleurs_debloquees.any(func(c: Color) -> bool: return not autre.couleurs_debloquees.has(c)),
		"(pré-condition) le joueur local a une couleur que l'autre joueur n'a pas")
	lion_autre.commandes.vomir_voulu = true
	await _frames(20)
	lion_autre.commandes.vomir_voulu = false
	await _frames(2)
	var couleurs_peintes := {}
	var image_ville: Image = ville_hc.image
	for y in range(image_ville.get_height()):
		for x in range(image_ville.get_width()):
			var c: Color = image_ville.get_pixel(x, y)
			if c.a > 0.0:
				couleurs_peintes[c] = true
	_check(not couleurs_peintes.is_empty()
		and couleurs_peintes.keys().all(func(c: Color) -> bool: return autre.couleurs_debloquees.has(c)),
		"la traceuse d'un lion peint avec les couleurs de son joueur (%d couleur(s) sur la ville)" % couleurs_peintes.size())
```

- [ ] **Step 2 : Lancer le smoke test pour le voir échouer**

Run : commande avec délai, `T=tests/smoke_test.gd`.
Expected : la vérification « la traceuse d'un lion peint avec les couleurs de son joueur » échoue (`❌`) : la ville porte du vert, la couleur du joueur local. La pré-condition et tout le reste sont verts.

- [ ] **Step 3 : `Scripts/GerbeTraceuse.gd`**

Remplacer tout le contenu à partir de la ligne `@onready var forme: CollisionShape2D = $CollisionShape2D` par :

```gdscript
@onready var forme: CollisionShape2D = $CollisionShape2D
## Le lion qui porte cette zone : on peint avec les couleurs de son joueur.
@onready var lion: Node = get_parent()


func _process(_delta: float) -> void:
	if not monitoring:
		return
	var couleurs: Array[Color] = lion.joueur.couleurs_debloquees
	if couleurs.is_empty():
		return
	var rayon := int((forme.shape as CircleShape2D).radius)
	for area in get_overlapping_areas():
		var ville: Node = area.get_parent()
		if ville != null and ville.has_method("peindre"):
			ville.peindre(global_position, rayon, couleurs)
```

(Les trois lignes de docstring en tête du fichier restent.)

- [ ] **Step 4 : Vérifier**

Run : `grep -n "GameState" Scripts/GerbeTraceuse.gd` → aucune ligne.

Puis l'import (rien), `tests/unitaires.gd` avec délai (vert), et **5 passages consécutifs** du smoke test avec délai : chacun n'affiche que `== smoke test LeLion ==` et `== 0 échec(s) ==`. Consigner les 5 résultats dans le rapport.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/GerbeTraceuse.gd tests/smoke_test.gd
git commit -m "Traceuse : peint avec les couleurs du joueur de son lion ; section multi-lions sans restes de la partie Hardcore

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

## Sortie de phase

- Les deux suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR`, localement (smoke test 5 fois) puis en CI sur la PR.
- `grep -rnE "GameState\.(vies|coups_recus|couleurs_debloquees|bonus_actif|bonus_restant|invulnerable_restant|est_invulnerable|toucher_lion|gagner_vie|debloquer_couleur|activer_bonus|vies_changees|lion_touche|couleur_debloquee|bonus_change)" Scripts` : seulement `Scripts/GameState.gd` et `Scripts/Main.gd` (phase 6 bis).
