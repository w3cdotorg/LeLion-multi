# Phase 8 ter : base commune des ennemis, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** les trois ennemis (soucoupe, coccinelle, peintre) partagent un seul gestionnaire de contact, `Scripts/Ennemi.gd` : garde hôte (`multiplayer.is_server()`), `body is Lion` au lieu de supposer qu'un corps du groupe « lion » a un champ `joueur`, et origine du coup redéfinissable (le peintre frappe depuis sa verticale, à la hauteur du lion). Le peintre garde ses deux chemins de contact : `body_entered` et le contact continu hors repos. **Le solo reste strictement identique** : mêmes coups, mêmes reculs, mêmes invulnérabilités ; en bataille, les ennemis étourdissent toujours par les règles de la phase 8.

**Architecture:** `Ennemi` (`class_name Ennemi`, `extends Area2D`) porte `_on_body_entered` (branché sur `body_entered` dans chaque scène, qui ne change pas : la méthode héritée est trouvée par son nom), `_signaler_les_lions_au_contact()` (contact continu, pour le peintre), `origine_du_coup(lion)` (position de l'ennemi par défaut) et `_signaler_si_lion(body)`, qui ne transmet aux règles que les corps qui sont des `Lion`. Les deux points d'entrée testent `multiplayer.is_server()` : un client ne tranche rien (spec §3, un seul chemin d'autorité). `Soucoupe`, `Coccinelle` et `Boss` passent de `extends Area2D` à `extends Ennemi` et perdent leur copie du gestionnaire ; `Boss` redéfinit `origine_du_coup` et appelle `_signaler_les_lions_au_contact()` hors repos. Le groupe « lion » reste dans `Lion.tscn` : le Spawner et les pastilles le lisent encore (phase 14 bis pour les pastilles).

**Tech Stack:** Godot 4.7.2, GDScript, smoke test headless.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3 « un seul chemin d'autorité », §3.1 `Regles`, §2 ennemis) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (phase 8 ter ; points de vigilance « phases 8 ter et 14 bis », « phase 14 » sur les gestionnaires inertes côté client) · prérequis : phase 8 bis (`docs/superpowers/plans/2026-09-25-phase-08bis-lion.md`) fusionnée (`class_name Lion`).

## Écarts assumés

1. **Le groupe « lion » n'est plus lu par les ennemis, mais il reste** : `Spawner.gd` (`get_first_node_in_group("lion")`) et les trois pastilles s'en servent encore. Les pastilles passent à `body is Lion` en phase 14 bis (base `Pastille`, même modèle que `Ennemi`).
2. **Garde hôte testée par un sous-arbre client, sans réseau** : le smoke test donne à un nœud de la scène son propre `SceneMultiplayer` dont le pair est un `ENetMultiplayerPeer` client jamais connecté (`create_client("127.0.0.1", 7779)`, `SceneTree.set_multiplayer(api, chemin)`) : pour tout ce qui est sous ce nœud, `multiplayer.is_server()` est faux, le reste de l'arbre reste sur l'`OfflineMultiplayerPeer` du solo. Aucun paquet n'est attendu (personne n'écoute sur 7779) ; le pair est fermé et le nœud libéré à la fin de la vérification. Mesuré au moment du plan : `is_server()` reste faux pendant au moins 10 frames, redevient vrai dès `set_multiplayer(null, chemin)`.
3. **Aucune vérification du solo ne change** : les vérifications existantes des coups (coccinelle, soucoupe, peintre, Hardcore, lion d'un autre joueur, coccinelle de bataille) couvrent le chemin commun. Seules s'ajoutent les vérifications propres à la base (héritage, intrus, client) et aux deux chemins du peintre.
4. **Pas de nettoyage préalable (règle « Step 0 »)** : `Scripts/Boss.gd` fait 160 lignes, `Soucoupe.gd` et `Coccinelle.gd` moins de 50 ; `tests/smoke_test.gd` dépasse 300 lignes, mais ne gagne que des vérifications, sans refactor structurel.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations.
- Solo strictement identique : aucune vérification existante du smoke test ne change.
- Fichiers de la phase (5) : ➕ `Scripts/Ennemi.gd`, ✏️ `Scripts/Soucoupe.gd`, ✏️ `Scripts/Coccinelle.gd`, ✏️ `Scripts/Boss.gd`, ✏️ `tests/smoke_test.gd`. Le `Scripts/Ennemi.gd.uid` généré est commité avec le script, hors plafond. Les scènes (`Soucoupe.tscn`, `Coccinelle.tscn`, `Boss.tscn`) ne changent pas : leur connexion `body_entered` → `_on_body_entered` trouve la méthode héritée.
- **Toujours lancer un test Godot avec un délai maximal** (une erreur de script bloque le processus headless), et chercher `SCRIPT ERROR` et `SHADER ERROR` dans la sortie (une erreur dans un rappel de signal ou une fonction appelée ne change pas le code de sortie : la suite peut finir sur `== 0 échec(s) ==` malgré elle) :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; ( godot --headless --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd` pour les tests unitaires ; une suite qui passe n'affiche que ses deux lignes `== … ==`). Un « resources still in use at exit » final est le bruit connu.
- Après la création de `Scripts/Ennemi.gd` (`class_name`) : `godot --headless --import .` avant les tests, sinon le cache des classes globales ne la connaît pas.
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : le smoke test ne nomme **jamais** `Lion` ni `Ennemi` (les deux scripts nomment `GameState`, `Lion.gd` aussi `Audio`). Il type les ennemis en `Node2D`, les lions en `CharacterBody2D` / `Node`, et vérifie l'héritage par `load(...).get_base_script().resource_path`.
- Toute modification du smoke test se valide sur **5 passages consécutifs verts** ; ses sections libèrent ce qu'elles créent (des restes ont déjà rendu le smoke test instable).
- Commits en français, terminés par la ligne `Co-Authored-By:` qu'impose l'environnement de l'auteur du commit.

## Review Focus

1. **Solo identique** : un coup de coccinelle ou de soucoupe coûte une vie, rend invulnérable et repousse ; le peintre blesse au passage ; un coup pendant l'invulnérabilité ne compte pas ; Hardcore, un coup et c'est fini. → vérifications existantes « un coup coûte une vie… », « un coup pendant l'invulnérabilité ne compte pas », « le boss blesse le lion au passage », « mode Hardcore : un coup et c'est fini » (Tasks 1 et 2).
2. **`body is Lion`** : un corps de la couche 1 dans le groupe « lion » qui n'est pas un lion est ignoré, sans erreur (avant la phase : `SCRIPT ERROR: Invalid access to property or key 'joueur'`). → vérification « un ennemi ignore un corps qui n'est pas un lion, même dans le groupe « lion » » + absence de `SCRIPT ERROR` (Task 1).
3. **Garde hôte** : sur un client, un ennemi au contact d'un lion ne le signale pas aux règles, même quand il le chevauche. → vérification « sur un client, un ennemi au contact d'un lion ne le signale pas aux règles (seul l'hôte tranche) » (Task 1).
4. **Les deux chemins du peintre et son origine** : le coup part de sa verticale, à la hauteur du lion ; un lion resté à son contact est frappé dès la fin de son invulnérabilité, sans nouveau `body_entered`. → vérifications « le coup du peintre part de sa verticale… » et « un lion resté au contact du peintre est frappé… (contact continu) » (Task 2).
5. **Base commune, sans nommer de classe dans les tests** : les trois scripts dérivent d'`Ennemi.gd`, aucun ne garde de copie du gestionnaire, le smoke test ne nomme ni `Lion` ni `Ennemi`. → vérification « soucoupe, coccinelle et peintre dérivent de la base Ennemi » (Task 2) + greps de la sortie de phase.

---

### Task 0 : documentation (commit de ce plan)

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 8 ter du tableau des phases)
- Create: `docs/superpowers/plans/2026-09-25-phase-08ter-ennemis.md` (ce plan)

Les documents ne comptent pas dans le plafond de 5 fichiers. Ce plan est déjà écrit : le committer tel quel. **Ne jamais modifier le fichier du plan** (ni réécriture, ni résumé) ; seule la feuille de route est éditée ici, le spec ne change pas dans cette phase.

- [ ] **Step 1 : feuille de route, ligne 8 ter**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
| 8 ter | **Ennemis vers `body is Lion`** : base commune des gestionnaires de contact des ennemis (garde hôte, `body is Lion`, origine du coup). |
```

par :

```markdown
| 8 ter | **Ennemis vers `body is Lion`** : base commune `Ennemi` des gestionnaires de contact des ennemis (garde hôte, `body is Lion`, origine du coup redéfinissable) ; le peintre garde ses deux chemins de contact (`body_entered` et contact continu hors repos). |
```

- [ ] **Step 2 : Vérifier**

Run : `git diff --stat docs/`
Expected : une ligne changée dans la feuille de route ; ce plan apparaît comme fichier nouveau (non suivi) dans `git status`.

- [ ] **Step 3 : Commit**

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md docs/superpowers/plans/2026-09-25-phase-08ter-ennemis.md
git commit -m "Plan de la phase 8 ter (base commune des ennemis) ; feuille de route : ligne 8 ter précisée

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 1 : base `Ennemi`, soucoupe et coccinelle

**Files:**
- Create: `Scripts/Ennemi.gd` (et son `.uid` généré)
- Modify: `Scripts/Soucoupe.gd`
- Modify: `Scripts/Coccinelle.gd`
- Modify: `tests/smoke_test.gd` (section « Ennemis et pastilles signalent le lion qu'ils touchent »)

**Interfaces:**
- Consumes : `class_name Lion` et `Lion.joueur` (phase 8 bis), `GameState.regles.lion_touche_par_ennemi(joueur, origine)` (phases 3 et 8), la connexion `body_entered` → `_on_body_entered` des scènes d'ennemis (phase 4).
- Produces : `class_name Ennemi extends Area2D` ; `Ennemi._on_body_entered(body: Node2D)` (garde hôte) ; `Ennemi.origine_du_coup(lion: Lion) -> Vector2` (par défaut `global_position`) ; `Ennemi._signaler_si_lion(body: Node2D)` (sans garde : appelé par les points d'entrée gardés) ; `Soucoupe` et `Coccinelle` en dérivent.

- [ ] **Step 1 : `tests/smoke_test.gd`, les vérifications**

Elles vont juste après le test du cœur « premier arrivé, premier servi » : le lion de l'autre joueur est alors à 2 vies, comme le joueur local. Il est remis à sa place avant la vérification du client : le recul des coups précédents l'éloigne encore de quelques pixels par frame.

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	_check(not is_instance_valid(coeur_autre), "le cœur ramassé disparaît")
```

par :

```gdscript
	_check(not is_instance_valid(coeur_autre), "le cœur ramassé disparaît")

	# Base commune des ennemis : seul un lion compte (`body is Lion`, pas le groupe « lion »), et
	# seul l'hôte tranche un contact
	var bases: Array = ["Soucoupe", "Coccinelle"].map(func(nom: String) -> String:
		var base: Script = load("res://Scripts/%s.gd" % nom).get_base_script()
		return "" if base == null else base.resource_path)
	_check(bases.all(func(p: String) -> bool: return p == "res://Scripts/Ennemi.gd"),
		"soucoupe et coccinelle dérivent de la base Ennemi (%s)" % [bases])
	var intrus := CharacterBody2D.new()  # sur la couche 1 et dans le groupe « lion », mais pas un lion
	intrus.add_to_group("lion")
	var forme_intrus := CollisionShape2D.new()
	forme_intrus.shape = CircleShape2D.new()
	forme_intrus.shape.radius = 30.0
	intrus.add_child(forme_intrus)
	intrus.position = Vector2(300, -400)  # hors de l'écran, loin des lions
	root.add_child(intrus)
	var soucoupe_intrus: Node2D = load("res://Scenes/Soucoupe.tscn").instantiate()
	soucoupe_intrus.position = intrus.position
	root.add_child(soucoupe_intrus)
	await _frames(3)
	_check(soucoupe_intrus.get_overlapping_bodies().has(intrus) and autre.vies == 2 and local.vies == 2,
		"un ennemi ignore un corps qui n'est pas un lion, même dans le groupe « lion »")
	soucoupe_intrus.free()
	intrus.free()
	autre.invulnerable_restant = 0.0
	lion_autre._recul = Vector2.ZERO  # le recul des coups précédents l'éloigne encore
	lion_autre.global_position = Vector2(1400, 300)
	await _frames(1)
	var poste_client := Node2D.new()  # sous-arbre dont le pair multijoueur est un client
	poste_client.name = "PosteClient"
	root.add_child(poste_client)
	var api_client := SceneMultiplayer.new()
	var pair_client := ENetMultiplayerPeer.new()
	pair_client.create_client("127.0.0.1", 7779)  # jamais connecté : un client qui attend l'hôte
	api_client.multiplayer_peer = pair_client
	set_multiplayer(api_client, poste_client.get_path())
	var coccinelle_client: Node2D = load("res://Scenes/Coccinelle.tscn").instantiate()
	coccinelle_client.position = lion_autre.global_position + Vector2(68, 66)
	poste_client.add_child(coccinelle_client)
	await _frames(3)
	_check(not coccinelle_client.multiplayer.is_server() and coccinelle_client.get_overlapping_bodies().has(lion_autre)
		and autre.vies == 2 and not autre.est_invulnerable(),
		"sur un client, un ennemi au contact d'un lion ne le signale pas aux règles (seul l'hôte tranche)")
	set_multiplayer(null, poste_client.get_path())
	pair_client.close()
	poste_client.free()
```

Notes :
- L'intrus est un `CharacterBody2D` nu : il est sur la couche 1 (celle que détectent ennemis et pastilles) et dans le groupe « lion », mais n'a pas de champ `joueur`. Avant la phase, la soucoupe lit `body.joueur` et lève une `SCRIPT ERROR` dans son rappel ; la vérification elle-même ne peut que constater que rien n'a changé : c'est le `grep SCRIPT ERROR` qui fait foi.
- La vérification du client passe déjà avant la phase (la garde existe depuis la phase 4) : c'est un filet de non-régression de la garde, désormais dans la base.
- `lion_autre` reste à `(1400, 300)` pour la section suivante (traceuse), où il se trouvait à peu près avant cet ajout.

- [ ] **Step 2 : Lancer le smoke test (échec attendu)**

Run : le smoke test avec délai.
Expected : `❌ soucoupe et coccinelle dérivent de la base Ennemi (["", ""])`, puis `SCRIPT ERROR: Invalid access to property or key 'joueur' on a base object of type 'CharacterBody2D'.` (le rappel de la soucoupe sur l'intrus), puis `== 1 échec(s) ==`. Toutes les autres vérifications passent.

- [ ] **Step 3 : `Scripts/Ennemi.gd`**

Créer `Scripts/Ennemi.gd` :

```gdscript
class_name Ennemi
extends Area2D
## Base des ennemis (soucoupe, coccinelle, peintre) : leur gestionnaire de contact commun. Un
## contact n'est tranché que par l'hôte (en solo, le poste est son propre hôte), ne compte que
## pour un lion (`body is Lion`) et part de `origine_du_coup`, que chaque ennemi peut redéfinir.
## Ce sont les règles qui en décident l'effet : un coup en solo, un étourdissement en bataille.


## Branché sur `body_entered` dans la scène de chaque ennemi.
func _on_body_entered(body: Node2D) -> void:
	if multiplayer.is_server():
		_signaler_si_lion(body)


## Point d'où part le coup, pour le recul du lion : par défaut, la position de l'ennemi.
func origine_du_coup(_lion: Lion) -> Vector2:
	return global_position


func _signaler_si_lion(body: Node2D) -> void:
	if body is Lion:
		var lion: Lion = body
		GameState.regles.lion_touche_par_ennemi(lion.joueur, origine_du_coup(lion))
```

- [ ] **Step 4 : `Scripts/Soucoupe.gd`**

4a. Dans `Scripts/Soucoupe.gd`, remplacer :

```gdscript
extends Area2D
## Ennemi : traverse l'écran de gauche à droite en ligne droite.
```

par :

```gdscript
extends Ennemi
## Ennemi : traverse l'écran de gauche à droite en ligne droite.
```

4b. Dans `Scripts/Soucoupe.gd`, remplacer :

```gdscript
		queue_free()


## Les contacts ne sont tranchés que par l'hôte (en solo, le poste est son propre hôte).
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	if body.is_in_group("lion"):
		GameState.regles.lion_touche_par_ennemi(body.joueur, global_position)
```

par :

```gdscript
		queue_free()
```

- [ ] **Step 5 : `Scripts/Coccinelle.gd`**

5a. Dans `Scripts/Coccinelle.gd`, remplacer :

```gdscript
extends Area2D
## Ennemi : traverse l'écran de droite à gauche en zigzag de plus en plus ample.
```

par :

```gdscript
extends Ennemi
## Ennemi : traverse l'écran de droite à gauche en zigzag de plus en plus ample.
```

5b. Dans `Scripts/Coccinelle.gd`, remplacer :

```gdscript
	if position.x < -200:
		queue_free()


## Les contacts ne sont tranchés que par l'hôte (en solo, le poste est son propre hôte).
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	if body.is_in_group("lion"):
		GameState.regles.lion_touche_par_ennemi(body.joueur, global_position)
```

par :

```gdscript
	if position.x < -200:
		queue_free()
```

- [ ] **Step 6 : Vérifier**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` (aucune ligne), puis **5 passages** consécutifs du smoke test avec délai : `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR`, avec les 3 nouvelles vérifications (`✅`). Les tests unitaires (inchangés) une fois : verts.

- [ ] **Step 7 : Commit**

```bash
git add Scripts/Ennemi.gd Scripts/Ennemi.gd.uid Scripts/Soucoupe.gd Scripts/Coccinelle.gd tests/smoke_test.gd
git commit -m "Ennemi : base commune des gestionnaires de contact (garde hôte, body is Lion, origine du coup) ; soucoupe et coccinelle en dérivent

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 2 : le peintre dérive d'`Ennemi`, avec ses deux chemins de contact

**Files:**
- Modify: `Scripts/Ennemi.gd` (contact continu)
- Modify: `Scripts/Boss.gd`
- Modify: `tests/smoke_test.gd` (section « Boss sur le niveau Village », vérification d'héritage de la Task 1)

**Interfaces:**
- Consumes : Task 1 ; `Boss.Etat`, `Boss._arreter()`, `Boss.etat` (phase 4 et antérieures).
- Produces : `Ennemi._signaler_les_lions_au_contact()` (garde hôte, puis chaque corps qui chevauche l'ennemi) ; `Boss extends Ennemi` ; `Boss.origine_du_coup(lion) = Vector2(global_position.x, lion.global_position.y)` ; `Boss._physics_process` appelle `_signaler_les_lions_au_contact()` hors repos ; le `_on_body_entered` du peintre est celui de la base.

- [ ] **Step 1 : `tests/smoke_test.gd`, les vérifications**

1a. Dans la section du boss, le lion vient d'être blessé au passage (niveau Village, Facile). On arrête le cycle du peintre au centre, on y pose le lion encore invulnérable : `body_entered` est ignoré par les règles, et seul le contact continu peut le frapper une fois l'invulnérabilité finie.

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	_check(JL.vies < vies_avant, "le boss blesse le lion au passage (%d → %d)" % [vies_avant, JL.vies])
```

par :

```gdscript
	_check(JL.vies < vies_avant, "le boss blesse le lion au passage (%d → %d)" % [vies_avant, JL.vies])
	# Les deux chemins de contact du peintre : body_entered, puis le contact continu hors repos.
	# Un lion resté à son contact est frappé dès la fin de son invulnérabilité, sans nouveau
	# body_entered ; le coup part de la verticale du peintre, à la hauteur du lion.
	_check(boss.origine_du_coup(lion) == Vector2(boss.global_position.x, lion.global_position.y),
		"le coup du peintre part de sa verticale, à la hauteur du lion")
	boss._arreter()
	boss.etat = boss.Etat.PAUSE
	boss.position.x = 1000.0
	lion.global_position = Vector2(1000 - 68, boss.position.y - 66)
	JL.vies = 3
	JL.invulnerable_restant = 0.3
	await _frames(3)
	_check(boss.get_overlapping_bodies().has(lion) and JL.vies == 3,
		"(pré-condition) le lion, invulnérable, est au contact du peintre et n'a rien perdu")
	await create_timer(0.4).timeout
	await _frames(2)
	_check(JL.vies == 2, "un lion resté au contact du peintre est frappé dès la fin de son invulnérabilité (contact continu)")
```

1b. Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	var bases: Array = ["Soucoupe", "Coccinelle"].map(func(nom: String) -> String:
		var base: Script = load("res://Scripts/%s.gd" % nom).get_base_script()
		return "" if base == null else base.resource_path)
	_check(bases.all(func(p: String) -> bool: return p == "res://Scripts/Ennemi.gd"),
		"soucoupe et coccinelle dérivent de la base Ennemi (%s)" % [bases])
```

par :

```gdscript
	var bases: Array = ["Soucoupe", "Coccinelle", "Boss"].map(func(nom: String) -> String:
		var base: Script = load("res://Scripts/%s.gd" % nom).get_base_script()
		return "" if base == null else base.resource_path)
	_check(bases.all(func(p: String) -> bool: return p == "res://Scripts/Ennemi.gd"),
		"soucoupe, coccinelle et peintre dérivent de la base Ennemi (%s)" % [bases])
```

Notes :
- `boss.position.x = 1000.0` : le centre de l'écran de 2000 px, là où le peintre marque sa pause. `_arreter()` tue le tween du cycle, et `etat = PAUSE` (sans `_changer_etat`, qui relancerait un tween) garde le contact continu actif.
- La partie Village continue ensuite jusqu'à l'arcade, qui libère `main` : le peintre arrêté disparaît avec elle.

- [ ] **Step 2 : Lancer le smoke test (échec attendu)**

Run : le smoke test avec délai.
Expected : `SCRIPT ERROR: Invalid call. Nonexistent function 'origine_du_coup' in base 'Area2D (Boss.gd)'.` La section s'arrête là et le délai coupe le processus (pas de ligne `== … échec(s) ==`).

- [ ] **Step 3 : `Scripts/Ennemi.gd`, le contact continu**

Dans `Scripts/Ennemi.gd`, remplacer :

```gdscript
## Point d'où part le coup, pour le recul du lion : par défaut, la position de l'ennemi.
```

par :

```gdscript
## Contact continu (le peintre, hors repos) : chaque lion qui chevauche l'ennemi est signalé à
## chaque frame ; les règles ignorent un joueur déjà frappé, étourdi ou immunisé.
func _signaler_les_lions_au_contact() -> void:
	if not multiplayer.is_server():
		return
	for body in get_overlapping_bodies():
		_signaler_si_lion(body)


## Point d'où part le coup, pour le recul du lion : par défaut, la position de l'ennemi.
```

- [ ] **Step 4 : `Scripts/Boss.gd`**

4a. Dans `Scripts/Boss.gd`, remplacer :

```gdscript
extends Area2D
## Le peintre géant : s'annonce au bord de l'écran, avance jusqu'au centre, marque une
```

par :

```gdscript
extends Ennemi
## Le peintre géant : s'annonce au bord de l'écran, avance jusqu'au centre, marque une
```

4b. Dans `Scripts/Boss.gd`, remplacer :

```gdscript
	if etat != Etat.REPOS and multiplayer.is_server():
		for body in get_overlapping_bodies():
			if body.is_in_group("lion"):
				GameState.regles.lion_touche_par_ennemi(body.joueur, Vector2(global_position.x, body.global_position.y))


## Les contacts ne sont tranchés que par l'hôte (en solo, le poste est son propre hôte).
func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return
	if body.is_in_group("lion"):
		GameState.regles.lion_touche_par_ennemi(body.joueur, Vector2(global_position.x, body.global_position.y))
```

par :

```gdscript
	if etat != Etat.REPOS:
		_signaler_les_lions_au_contact()


## Le coup du peintre part de sa verticale, à la hauteur du lion (et non de son centre, bien plus
## haut ou plus bas que le lion) : le lion est repoussé sur le côté.
func origine_du_coup(lion: Lion) -> Vector2:
	return Vector2(global_position.x, lion.global_position.y)
```

(Le `_on_body_entered` du peintre est désormais celui de la base, avec la même origine : `_signaler_si_lion` appelle la méthode redéfinie.)

- [ ] **Step 5 : Vérifier**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` (aucune ligne), les tests unitaires avec délai (verts), puis **5 passages** consécutifs du smoke test : verts, sans `SCRIPT ERROR` ni `SHADER ERROR`, avec les 3 vérifications du peintre et « soucoupe, coccinelle et peintre dérivent de la base Ennemi (["res://Scripts/Ennemi.gd", "res://Scripts/Ennemi.gd", "res://Scripts/Ennemi.gd"]) ».

- [ ] **Step 6 : Commit**

```bash
git add Scripts/Ennemi.gd Scripts/Boss.gd tests/smoke_test.gd
git commit -m "Boss : dérive d'Ennemi, garde ses deux chemins de contact (body_entered et contact continu hors repos) et son origine du coup

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 3 : feuille de route, points de vigilance résolus par la phase 8 ter

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`

**Ne jamais modifier le fichier du plan** (ce fichier) : seule la feuille de route change ici.

- [ ] **Step 1 : le point « phases 8 ter et 14 bis »**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phases 8 ter (ennemis) et 14 bis (pastilles)** : `class_name Lion` existe depuis la phase
  8 bis ; tester `body is Lion` dans les gestionnaires de contact au lieu de supposer
  `body.joueur`. Les tests `--script` (compilés avant les autoloads) continuent de typer les lions
  en `Node` / `CharacterBody2D`, jamais `Lion` : `Lion.gd` nomme `GameState` et `Audio` ;
```

par :

```markdown
- **phase 14 bis (pastilles)** : comme la base `Ennemi` de la phase 8 ter (`Scripts/Ennemi.gd`),
  tester `body is Lion` dans le gestionnaire de contact commun au lieu de supposer `body.joueur`.
  Les tests `--script` (compilés avant les autoloads) continuent de typer les lions en `Node` /
  `CharacterBody2D`, et ne nomment ni `Lion`, ni `Ennemi`, ni `Pastille` : ces scripts nomment
  `GameState` (`Lion.gd` aussi `Audio`). Le smoke test vérifie l'héritage d'un script par
  `load(...).get_base_script().resource_path`. Le groupe « lion » ne sert alors plus qu'au
  Spawner ;
```

- [ ] **Step 2 : le point « phase 14 » sur les gestionnaires inertes côté client**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  aléatoires) ; les gestionnaires de contact sont déjà inertes côté client
  (`multiplayer.is_server()`, phase 4) ;
```

par :

```markdown
  aléatoires) ; les gestionnaires de contact sont déjà inertes côté client
  (`multiplayer.is_server()`, phase 4 ; pour les ennemis, dans la base `Ennemi` depuis la phase
  8 ter, vérifié par le smoke test sur un sous-arbre dont le pair est un client ENet jamais
  connecté : `SceneTree.set_multiplayer(api, chemin)`, technique réutilisable pour les pastilles
  et la ville) ;
```

- [ ] **Step 3 : Vérifier et committer**

Run : `grep -n "phases 8 ter" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
Expected : aucune ligne. `git diff --stat` : la feuille de route seule.

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
git commit -m "Feuille de route : points de vigilance résolus par la phase 8 ter (base Ennemi, garde hôte testée par un sous-arbre client)

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

## Sortie de phase

- Les deux suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR`, localement (smoke test 5 fois) puis en CI sur la PR.
- `git diff main --stat` : 5 fichiers de code (`Scripts/Ennemi.gd`, `Scripts/Soucoupe.gd`, `Scripts/Coccinelle.gd`, `Scripts/Boss.gd`, `tests/smoke_test.gd`), le `.uid` d'`Ennemi` et la documentation. Les scènes sont intactes.
- `grep -n "is_in_group(\"lion\")\|body.joueur" Scripts/Soucoupe.gd Scripts/Coccinelle.gd Scripts/Boss.gd Scripts/Ennemi.gd` : aucune ligne.
- `grep -nE "(: |as |is |extends )(Lion|Ennemi)\b|\b(Lion|Ennemi)\.[A-Za-z_]" tests/*.gd | grep -vE "(Lion|Ennemi)\.(tscn|gd)|:[0-9]+:\s*#"` : aucune ligne (aucun test `--script` ne nomme ces classes, ni en type, ni en `is`, ni par une constante ; restent des chemins de fichiers et des commentaires).
- Rappeler à l'utilisateur la suite : les pastilles passent au même modèle en phase 14 bis (base `Pastille`) ; la phase 9 (territoire) ne dépend pas de celle-ci.
