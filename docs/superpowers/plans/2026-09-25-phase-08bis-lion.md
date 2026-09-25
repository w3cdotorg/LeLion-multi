# Phase 8 bis : lion de bataille, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** le lion se comporte en lion de bataille quand son joueur est un joueur de bataille (phase 8) : rayon de peinture selon les crans, gerbe en trois nuances dès le départ, étourdissement visible (commandes ignorées, recul, tête barbouillée de la couleur de l'agresseur, étoiles, clignotement de l'immunité), trois zones de contact sur la parabole qui étourdissent les autres lions (l'hôte décide, par les règles), et auto-tamponneuses entre lions. Toujours sans réseau ni scène de bataille (phases 10 et suivantes) : tout se vérifie dans une section propre du smoke test. **Le solo reste strictement identique** : mêmes rayons, même lion sans matériau, même clignotement.

**Architecture:** le rayon de la traceuse se lit désormais sur `joueur.crans` (16 px au premier cran, 5 px de plus par cran, 46 px au plus) ; pour que le solo ne change pas, `ReglesSolo` donne un cran par nouvelle couleur (1 couleur = 2 crans = 21 px, comme avant). Les trois émetteurs en nuances ne demandent aucun code : un joueur de bataille a ses nuances comme couleurs débloquées dès `nouvelle_partie` (phase 8). Le lion s'abonne à `etourdi` / `etourdissement_fini` de son joueur ; il ignore ses commandes tant que `joueur.est_etourdi()`, barbouille sa tête par les uniformes du shader de teinte, fait tourner des étoiles (nœud `Etoiles` de `Lion.tscn`) et, à la fin, clignote pendant ce qui reste d'invulnérabilité (le clignotement du solo, lu sur `joueur.invulnerable_restant` au lieu de la constante). Les zones de contact sont trois `Area2D` créées par le code (formes propres à chaque lion), placées à 0,2, 0,4 et 0,6 s de vol par la même formule que la traceuse ; elles détectent le corps des lions (couche 1) pendant le vomi, et le lion signale chaque autre lion touché à `GameState.regles.lion_touche_par_vomi`, sur l'hôte seulement, à chaque frame (les règles ignorent les répétitions). Auto-tamponneuses : un pare-chocs `Area2D` de 45 px sur la couche 5 (valeur 16), le corps de 63 px ne heurtant plus rien (masque 0) ; au premier contact (`area_entered`), chaque lion prend un recul proportionnel à la vitesse d'approche et son sprite tremble, et le lion d'identifiant le plus petit signale le choc aux règles ; pendant le contact, la part de la vitesse dirigée vers l'autre lion est annulée et deux lions qui se chevauchent s'écartent. `class_name Lion` sert aux zones et au pare-chocs.

**Tech Stack:** Godot 4.7.2, GDScript, tests unitaires et smoke test headless, planche de contrôle rendue en `opengl3`.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§2, §5 « Lion », mis à jour par la phase 8) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (phase 8 bis) · prérequis : phase 8 (`docs/superpowers/plans/2026-09-25-phase-08-bataille.md`) fusionnée.

## Écarts assumés

1. **Pare-chocs `Area2D` et réponse calculée, pas une collision de corps** (spec §5 « blocage physique ») : Godot n'a pas de couche par forme, or le corps de 63 px doit rester sur la couche 1, où ennemis et pastilles le détectent (`body_entered`). Le blocage est donc calculé par le lion à partir des pare-chocs qui se chevauchent : même résultat pour le joueur, et un calcul que la prédiction (phase 16) pourra refaire à l'identique contre les positions affichées. Mesuré au moment du plan : 84 px au plus près quand un lion pousse sans relâche un lion étourdi (enfoncement de 6 px), et le lion poussé recule de 54 px.
2. **Le lion signale ses contacts aux règles** (spec §3.1, corrigé par la phase 8 : « Ne décide de rien ») : exactement comme les ennemis et les pastilles, sous `multiplayer.is_server()`.
3. **Pas de son « boing »** : il faut synthétiser un son (`tools/generer_sons.py`, `Assets/Sons/boing.wav`, `Audio.gd`), trois fichiers de plus. Reporté en phase 17 bis (feuille de route). Pas non plus de son d'étourdissement (le spec n'en demande pas ; « mort » reste le son du coup en solo).
4. **Gestionnaires de contact inchangés** : `body is Lion` y arrive en phases 8 ter (ennemis) et 14 bis (pastilles) ; en bataille, les ennemis étourdissent déjà par les règles de la phase 8 (vérifié ici avec une vraie coccinelle).
5. **Réglages** (choisis sur la planche de la Task 2 et les mesures du smoke test, à reprendre sur une vraie manche en phase 10) : barbouillage à 70 % (`FORCE_BARBOUILLAGE`), zones de contact de 22 px (doublées par l'étoile XXL, comme la gerbe), `facteur_choc = 1.2`, `raideur_choc = 8`, secousse de 6 px pendant 0,25 s, étoiles sur une ellipse de 40 × 12 px au-dessus de la tête.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations.
- Solo strictement identique : aucune vérification existante du smoke test ne change ; la seule vérification ajoutée à la partie solo (« avec une couleur, la gerbe peint sur 21 px ») passe avant **et** après.
- Fichiers de la phase (5) : ✏️ `Scripts/ReglesSolo.gd`, ✏️ `tests/unitaires.gd`, ✏️ `Scripts/Lion.gd`, ✏️ `Scenes/Lion.tscn`, ✏️ `tests/smoke_test.gd`. Aucun nouveau script, donc aucun `.uid`. La planche de contrôle (`rendu_etourdi.gd`) vit dans le scratchpad de l'implémenteur et **n'est pas commitée**.
- `Scripts/Lion.gd` passe d'environ 270 à 440 lignes par ajouts, sans refactor structurel ; le smoke test ne gagne qu'une section à sa fin : pas d'étape 0 de nettoyage (règle `CLAUDE.md` des fichiers de plus de 300 lignes).
- **Toujours lancer un test Godot avec un délai maximal**, et chercher `SCRIPT ERROR` et `SHADER ERROR` (une erreur dans une fonction appelée ne change pas le code de sortie) :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; ( godot --headless --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd` pour les tests unitaires ; une suite qui passe n'affiche que ses deux lignes `== … ==`). Un « resources still in use at exit » final est le bruit connu.
- Après l'ajout de `class_name Lion` (Task 3) : `godot --headless --import .` avant les tests.
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : le smoke test type les lions en `CharacterBody2D` / `Node` et **jamais** en `Lion` (`Lion.gd` nomme `GameState` et `Audio`) ; il lit les constantes du lion par l'instance (`lb.CENTRE`, `lb.FORCE_BARBOUILLAGE`), jamais par `Lion.`.
- Section de bataille du smoke test **propre** : elle commence par libérer la partie Hardcore (`main.free()` : son lion, sa ville, ses ennemis), crée ses propres lions, les libère et remet le solo (`configurer_solo()`) à la fin. Les sections précédentes ne doivent rien laisser qui touche ces lions (des restes ont déjà rendu le smoke test instable).
- Sous-ressources partagées (vu deux fois dans le projet) : les formes des zones de contact sont créées par le code, une par zone et par lion, parce que leur rayon change avec le bonus ; la forme du pare-chocs est une sous-ressource de `Lion.tscn` partagée par toutes les instances, **jamais modifiée** (c'est ce qui la rend sûre).
- Toute modification du smoke test se valide sur **5 passages consécutifs verts**.
- Commits en français, terminés par la ligne `Co-Authored-By:` qu'impose l'environnement de l'auteur du commit.

## Review Focus

1. **Solo identique** : rayon de 21 px avec une couleur (et doublé par l'étoile), le lion du solo sans matériau, dix clignotements après un coup (1,5 s lues sur `joueur.invulnerable_restant`), un corps qui ne heurtait déjà rien (seul lion de la scène). → vérification « avec une couleur, la gerbe peint sur 21 px » + tout le smoke test existant (Tasks 1 à 4).
2. **Crans et nuances** : trois émetteurs aux nuances du joueur, rayon 16 → 21 → 46 px, pour le seul lion du joueur concerné ; le solo gagne un cran par couleur nouvelle, jamais pour une couleur déjà là. → Task 1.
3. **Étourdissement** : commandes ignorées (ni déplacement ni vomi), recul, étoiles qui tournent, barbouillage de la couleur de l'agresseur seulement pour le vomi, effacé à la fin ; immunité qui clignote et protège d'un nouvel ennemi ; vrai chemin d'un ennemi (coccinelle, `body_entered`) en plein vomi. → Task 2 + planche regardée.
4. **Contacts signalés, décisions aux règles** : trois zones sur la parabole (la dernière au point de chute), inertes hors du vomi, formes propres à chaque lion ; un lion touché est étourdi une fois, pas à chaque frame ; l'agresseur n'est pas touché par sa propre gerbe. → Task 3.
5. **Auto-tamponneuses** : couche 5 et pare-chocs de 45 px, corps à masque 0 ; un choc compté une fois pour les deux lions (et par un seul des deux lions), reculs opposés, secousse, aucun étourdissement ; pas d'enfoncement ; un lion étourdi est poussé. → Task 4.
6. **`class_name Lion`** : utilisé par le lion lui-même (zones, pare-chocs), jamais nommé dans un test `--script`. → relecture + grep de sortie.

---

### Task 1 : rayon selon les crans (le solo gagne un cran par couleur), gerbe en nuances, reliquats de la phase 7

**Files:**
- Modify: `Scripts/ReglesSolo.gd` (`pastille_ramassee`)
- Modify: `tests/unitaires.gd` (`_tester_regles_solo`)
- Modify: `Scripts/Lion.gd`
- Modify: `tests/smoke_test.gd` (partie solo, et nouvelle section de bataille à la fin de `_run`)

**Interfaces:**
- Consumes : phase 8 (`Joueur.crans`, `gagner_cran`, `crans_changes`, `nuances`, `GameState.configurer_bataille`, `configurer_solo`, `ReglesBataille.pastille_ramassee`).
- Produces : `Lion.PAS_RAYON_PAR_CRAN := 5` ; rayon de la traceuse = `clamp(16 + (crans - 1) × 5, 16, 46) × bonus`, recalculé à chaque `crans_changes` ; `appliquer_apparence()` sans effet avant `_ready` ; un matériau d'un autre shader sur le sprite est remplacé ; la section « Bataille » du smoke test (`lions_bataille`, `lr`, `lb`, `j_rouge`, `j_bleu`), que les Tasks 2 à 4 complètent.

- [ ] **Step 1 : `tests/unitaires.gd`, le cran du solo**

1a. Dans `_tester_regles_solo()`, remplacer :

```gdscript
	_check(r.pastille_ramassee(j, 2) and j.couleurs_debloquees == [gs.couleur(2)], "une pastille débloque sa couleur de l'arc-en-ciel chez le joueur reçu")
	_check(not r.pastille_ramassee(j, 2), "une couleur déjà débloquée n'a pas d'effet")
	_check(not r.pastille_ramassee(j, -1) and not r.pastille_ramassee(j, gs.nb_couleurs_total()) and j.couleurs_debloquees.size() == 1,
		"un index de couleur hors bornes est refusé")
```

par :

```gdscript
	_check(r.pastille_ramassee(j, 2) and j.couleurs_debloquees == [gs.couleur(2)], "une pastille débloque sa couleur de l'arc-en-ciel chez le joueur reçu")
	_check(j.crans == 2, "en solo, chaque nouvelle couleur donne aussi un cran de gerbe")
	_check(not r.pastille_ramassee(j, 2) and j.crans == 2, "une couleur déjà débloquée n'a pas d'effet, pas même un cran")
	_check(not r.pastille_ramassee(j, -1) and not r.pastille_ramassee(j, gs.nb_couleurs_total()) and j.couleurs_debloquees.size() == 1
		and j.crans == 2, "un index de couleur hors bornes est refusé")
```

1b. Juste avant :

```gdscript
	r.etoile_ramassee(j)
	_check(j.bonus_actif() and is_equal_approx(j.bonus_restant, ReglesSolo.DUREE_ETOILE), "l'étoile active la gerbe XXL pour DUREE_ETOILE secondes")
```

ajouter :

```gdscript
	var toutes := Joueur.new()
	toutes.reinitialiser(3)
	for i in range(gs.nb_couleurs_total()):
		r.pastille_ramassee(toutes, i)
	_check(toutes.couleurs_debloquees.size() == 7 and toutes.crans == Joueur.CRANS_MAX,
		"les sept couleurs débloquées, la gerbe plafonne à son dernier cran (7)")
```

- [ ] **Step 2 : `tests/smoke_test.gd`, les vérifications**

2a. Partie solo : juste après

```gdscript
	_check(lion.vomi_container.get_child_count() == 1, "un émetteur de particules par couleur")
```

ajouter :

```gdscript
	_check(lion.traceuse_shape.shape.radius == 21.0, "avec une couleur, la gerbe peint sur 21 px (16 px + 5 px par couleur)")
```

(Non-régression : elle passe avant et après la Task.)

2b. Fin de `_run` : remplacer

```gdscript
	for l in lions_teintes:
		l.free()

	print("== %d échec(s) ==" % _echecs)
	paused = false
	main.free()
	quit(1 if _echecs > 0 else 0)
```

par :

```gdscript
	for l in lions_teintes:
		l.free()

	# Bataille : lions de bataille, dans une scène propre. La partie Hardcore est libérée d'abord
	# (son lion, sa ville) : rien des sections précédentes ne doit toucher ces lions.
	paused = false
	main.free()
	main = null
	GS.configurer_bataille(2)
	GS.nouvelle_partie()
	GS.pret = true
	var j_rouge: Joueur = GS.joueurs[0]
	var j_bleu: Joueur = GS.joueurs[1]
	var lions_bataille: Array[CharacterBody2D] = []
	for j: Joueur in GS.joueurs:
		var l: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
		l.joueur = j
		l.commandes = Commandes.manuelles()
		l.position = Vector2(200 + 1000 * lions_bataille.size(), 100)
		root.add_child(l)
		lions_bataille.append(l)
	var lr: CharacterBody2D = lions_bataille[0]
	var lb: CharacterBody2D = lions_bataille[1]
	await _frames(2)

	# Gerbe en trois nuances, rayon selon les crans
	var couleurs_gerbe: Array = lr.vomi_container.get_children().map(
		func(e: GPUParticles2D) -> Color: return (e.process_material as ParticleProcessMaterial).color_ramp.gradient.get_color(0))
	_check(couleurs_gerbe == j_rouge.nuances(), "un lion de bataille a trois émetteurs, aux nuances de son joueur (%s)" % [couleurs_gerbe])
	_check(lr.traceuse_shape.shape.radius == 16.0, "au premier cran, la gerbe peint sur 16 px")
	GS.regles.pastille_ramassee(j_rouge, 0)
	_check(lr.traceuse_shape.shape.radius == 21.0 and lb.traceuse_shape.shape.radius == 16.0, "une pastille donne un cran : 5 px de plus, pour ce lion seulement")
	for i in range(10):
		GS.regles.pastille_ramassee(j_rouge, 0)
	_check(lr.traceuse_shape.shape.radius == 46.0, "au septième cran, la gerbe peint sur 46 px")
	lr.commandes.vomir_voulu = true
	for i in range(3):
		await process_frame  # le vomi démarre dans _process
	_check(lr.est_en_train_de_vomir, "un lion de bataille vomit dès le départ, sans pastille")
	lr.commandes.vomir_voulu = false
	await _frames(2)

	# Reliquats de la phase 7 : apparence appliquée trop tôt, matériau d'un autre shader
	var lion_neuf: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
	lion_neuf.joueur = Joueur.new()
	lion_neuf.joueur.couleur = Color(0.18, 0.78, 0.25)
	lion_neuf.commandes = Commandes.manuelles()
	lion_neuf.position = Vector2(700, 400)
	lion_neuf.appliquer_apparence()
	root.add_child(lion_neuf)
	await _frames(1)
	_check(lion_neuf.sprite.material is ShaderMaterial and lion_neuf.sprite.material.shader == shader_lion,
		"appliquer_apparence avant l'ajout à l'arbre ne fait rien ; _ready teinte le lion")
	var materiau_etranger := ShaderMaterial.new()
	materiau_etranger.shader = load("res://Shaders/Ville.gdshader")
	lion_neuf.sprite.material = materiau_etranger
	lion_neuf.appliquer_apparence()
	_check(lion_neuf.sprite.material != materiau_etranger and lion_neuf.sprite.material.shader == shader_lion,
		"un matériau d'un autre shader sur le sprite est remplacé par celui de la teinte")
	lion_neuf.free()

	for l in lions_bataille:
		l.free()
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false

	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)
```

Notes :
- `main` est libéré au début de la section (et plus à la fin) : le lion de la partie Hardcore, caché mais toujours dans l'arbre, aurait heurté les lions de bataille (Task 4).
- `shader_lion` est la variable de la section de la phase 7, juste au-dessus.
- Le premier lion de bataille est lié à `GS.joueurs[0]`, le joueur local : c'est voulu (le même objet qu'en solo, redevenu rouge par `configurer_bataille`), et `configurer_solo()` lui rend son absence de couleur à la fin.
- La couleur de chaque émetteur se lit sur son dégradé (`color_ramp`, point 0), tel que `mettre_a_jour_degrade_vomi` le construit.

- [ ] **Step 3 : Lancer les deux suites (échec attendu)**

Run : les tests unitaires puis le smoke test, avec délai.
Expected :
- tests unitaires : `❌ en solo, chaque nouvelle couleur donne aussi un cran de gerbe`, `❌ une couleur déjà débloquée n'a pas d'effet, pas même un cran`, `❌ un index de couleur hors bornes est refusé`, `❌ les sept couleurs débloquées…`, `== 4 échec(s) ==` ;
- smoke test : la vérification solo à 21 px passe ; `❌ au premier cran, la gerbe peint sur 16 px` (le lion lit encore le nombre de couleurs : 3 nuances, 31 px), `❌ une pastille donne un cran…`, `❌ au septième cran…`, puis `SCRIPT ERROR: Invalid access to property or key 'material' on a base object of type 'Nil'` (l'apparence appliquée avant `_ready`), `❌ un matériau d'un autre shader…`, `== 4 échec(s) ==`.

- [ ] **Step 4 : `Scripts/ReglesSolo.gd`**

Remplacer :

```gdscript
func pastille_ramassee(joueur: Joueur, index_couleur: int) -> bool:
	if index_couleur < 0 or index_couleur >= partie.nb_couleurs_total():
		return false
	return joueur.debloquer_couleur(partie.couleur(index_couleur))
```

par :

```gdscript
## Chaque nouvelle couleur donne aussi un cran de gerbe : le rayon de peinture grandit de 5 px
## par couleur, de 21 px (une couleur) à 46 px.
func pastille_ramassee(joueur: Joueur, index_couleur: int) -> bool:
	if index_couleur < 0 or index_couleur >= partie.nb_couleurs_total():
		return false
	if not joueur.debloquer_couleur(partie.couleur(index_couleur)):
		return false
	joueur.gagner_cran()
	return true
```

(Ordre des signaux : `couleur_debloquee` d'abord, puis `crans_changes` ; le lion replace sa traceuse aux deux, la seconde fois avec le bon rayon. Le rayon du solo est inchangé : n couleurs donnaient `16 + 5n` plafonné à 46, n couleurs donnent maintenant `n + 1` crans, soit `16 + 5n`, plafonné au septième cran.)

- [ ] **Step 5 : `Scripts/Lion.gd`**

5a. Juste après `const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")`, ajouter :

```gdscript
const PAS_RAYON_PAR_CRAN := 5
```

5b. Dans `_ready()`, juste après `	joueur.touche.connect(_on_lion_touche)`, ajouter :

```gdscript
	joueur.crans_changes.connect(_on_crans_changes)
```

5c. Remplacer :

```gdscript
func appliquer_apparence() -> void:
	_appliquer_teinte()
```

par :

```gdscript
func appliquer_apparence() -> void:
	if not is_node_ready():
		return  # sprite et étiquette n'existent pas encore : `_ready` l'appliquera
	_appliquer_teinte()
```

5d. Dans `_appliquer_teinte()`, remplacer :

```gdscript
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
```

par :

```gdscript
	var mat := sprite.material as ShaderMaterial
	if mat == null or mat.shader != SHADER_TEINTE:
		mat = ShaderMaterial.new()
```

5e. Juste avant `func _on_bonus_change(_actif: bool) -> void:`, ajouter :

```gdscript
func _on_crans_changes(_crans: int) -> void:
	_placer_traceuse()


```

5f. Remplacer :

```gdscript
func _placer_traceuse() -> void:
	gerbe_traceuse.position = _point_de_chute()
	if traceuse_shape.shape is CircleShape2D:
		var n := joueur.couleurs_debloquees.size()
		var rayon: float = clamp(RAYON_TRACEUSE.x + n * 5, RAYON_TRACEUSE.x, RAYON_TRACEUSE.y)
		traceuse_shape.shape.radius = rayon * _facteur_bonus()
```

par :

```gdscript
## Traceuse au point de chute ; rayon de peinture selon les crans (16 px au premier, 5 px de
## plus par cran, 46 px au plus) et le bonus.
func _placer_traceuse() -> void:
	gerbe_traceuse.position = _point_de_chute()
	if traceuse_shape.shape is CircleShape2D:
		var rayon: float = clamp(RAYON_TRACEUSE.x + (joueur.crans - 1) * PAS_RAYON_PAR_CRAN, RAYON_TRACEUSE.x, RAYON_TRACEUSE.y)
		traceuse_shape.shape.radius = rayon * _facteur_bonus()
```

5g. Remplacer la docstring `## Reconstruit un émetteur par couleur débloquée.` par :

```gdscript
## Reconstruit un émetteur par couleur débloquée (en bataille, les trois nuances du joueur,
## débloquées dès le départ : voir `Regles.couleurs_de_depart`).
```

- [ ] **Step 6 : Vérifier**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|SHADER ERROR|Parse Error|Compile Error"` (aucune ligne), les tests unitaires avec délai (verts), puis **5 passages** consécutifs du smoke test : verts, sans `SCRIPT ERROR` ni `SHADER ERROR`, avec les 8 nouvelles vérifications (`✅`).

- [ ] **Step 7 : Commit**

```bash
git add Scripts/ReglesSolo.gd tests/unitaires.gd Scripts/Lion.gd tests/smoke_test.gd
git commit -m "Lion : rayon de peinture selon les crans (le solo gagne un cran par couleur, rayons inchangés) ; gerbe de bataille en trois nuances ; appliquer_apparence sûre avant _ready et face à un autre shader

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 2 : étourdissement visible, barbouillage, étoiles, clignotement de l'immunité

**Files:**
- Modify: `Scenes/Lion.tscn` (ressource `etoile.png`, nœud `Etoiles` et ses trois sprites, à la fin)
- Modify: `Scripts/Lion.gd`
- Modify: `tests/smoke_test.gd` (section « Bataille »)
- Create (scratchpad, **non commité**) : `$SCRATCH/rendu_etourdi.gd` (`$SCRATCH` = le dossier scratchpad de l'implémenteur)

**Interfaces:**
- Consumes : phase 8 (`Joueur.etourdi`, `etourdissement_fini`, `est_etourdi`, `invulnerable_restant`, `ReglesBataille`), Task 1 (section « Bataille » du smoke test), uniformes `barbouillage_couleur` / `barbouillage_force` de `Shaders/Lion.gdshader` (phase 7).
- Produces : `Lion.CENTRE`, `Lion.FORCE_BARBOUILLAGE := 0.7`, `Lion.etoiles: Node2D` (`$Etoiles`, caché hors étourdissement), `Lion._clignotement: Tween` ; `_on_etourdi`, `_on_etourdissement_fini`, `_reculer`, `_clignoter`, `_barbouiller`, `_tourner_etoiles`. Un lion étourdi ignore ses commandes.

- [ ] **Step 1 : `tests/smoke_test.gd`, les vérifications**

Dans la section « Bataille », juste avant les lignes de fin :

```gdscript
	for l in lions_bataille:
		l.free()
	GS.configurer_solo()
```

ajouter :

```gdscript
	# Étourdissement par un ennemi : immobile, repoussé, étoiles, sans barbouillage
	var materiau_bleu := lb.sprite.material as ShaderMaterial
	lb.commandes.direction_voulue = Vector2.LEFT
	await _frames(5)
	_check(lb._vitesse.x < 0.0, "(pré-condition) le lion bleu avance selon ses commandes")
	GS.regles.lion_touche_par_ennemi(j_bleu, lb.global_position + lb.CENTRE + Vector2(-80, 0))
	_check(j_bleu.est_etourdi() and lb._vitesse == Vector2.ZERO and lb._recul.x > 0.0 and lb.etoiles.visible,
		"un ennemi étourdit le lion : il s'arrête, il est repoussé, des étoiles tournent")
	_check(materiau_bleu.get_shader_parameter("barbouillage_force") == 0.0, "un ennemi ne barbouille pas")
	lb.commandes.vomir_voulu = true
	var position_etoile: Vector2 = lb.etoiles.get_child(0).position
	await _frames(10)
	_check(lb._vitesse == Vector2.ZERO and not lb.est_en_train_de_vomir, "étourdi, le lion ignore ses commandes : ni déplacement ni vomi")
	_check(lb.etoiles.get_child(0).position != position_etoile, "les étoiles tournent autour de la tête")
	j_bleu.etourdi_restant = 0.05
	await create_timer(0.1).timeout
	await _frames(2)
	_check(not j_bleu.est_etourdi() and not lb.etoiles.visible and j_bleu.est_invulnerable()
		and lb._clignotement != null and lb._clignotement.is_running(),
		"à la fin de l'étourdissement, les étoiles s'en vont et l'immunité clignote")
	_check(lb._vitesse.x < 0.0 and lb.est_en_train_de_vomir, "le lion obéit de nouveau à ses commandes")
	GS.regles.lion_touche_par_ennemi(j_bleu, Vector2.INF)
	_check(not j_bleu.est_etourdi(), "un ennemi ne ré-étourdit pas un lion immunisé")

	# Étourdissement par le vomi : tête barbouillée de la couleur de l'agresseur
	j_bleu.invulnerable_restant = 0.0
	GS.regles.lion_touche_par_vomi(j_bleu, j_rouge, lb.global_position + lb.CENTRE + Vector2(0, -80))
	_check(materiau_bleu.get_shader_parameter("barbouillage_couleur") == j_rouge.couleur
		and is_equal_approx(materiau_bleu.get_shader_parameter("barbouillage_force"), lb.FORCE_BARBOUILLAGE)
		and materiau_bleu.get_shader_parameter("couleur_joueur") == j_bleu.couleur,
		"le vomi barbouille la tête de la couleur de l'agresseur, par-dessus la teinte du joueur")
	await _frames(3)
	_check(not lb.est_en_train_de_vomir and not lb.gerbe_traceuse.monitoring, "étourdi en plein vomi, le lion arrête de vomir")
	j_bleu.etourdi_restant = 0.05
	await create_timer(0.1).timeout
	await _frames(2)
	_check(materiau_bleu.get_shader_parameter("barbouillage_force") == 0.0, "le barbouillage s'efface à la fin de l'étourdissement")

	# Un vrai ennemi, en plein vomi : l'étourdissement part d'un rappel physique (body_entered)
	j_bleu.invulnerable_restant = 0.0
	lb.commandes.direction_voulue = Vector2.ZERO
	await _frames(3)
	_check(lb.est_en_train_de_vomir, "(pré-condition) le lion bleu vomit")
	var coccinelle_bataille: Node2D = load("res://Scenes/Coccinelle.tscn").instantiate()
	coccinelle_bataille.position = lb.global_position + lb.CENTRE
	root.add_child(coccinelle_bataille)
	await _frames(3)
	_check(j_bleu.est_etourdi() and j_bleu.vies == 3 and not lb.est_en_train_de_vomir,
		"une coccinelle étourdit le lion de bataille qu'elle touche, sans lui ôter de vie ; il arrête de vomir")
	coccinelle_bataille.free()
	lb.commandes.vomir_voulu = false
	await _frames(2)
	j_bleu.etourdi_restant = 0.0
	j_bleu.invulnerable_restant = 0.0

```

Notes :
- `j_bleu.etourdi_restant = 0.05` puis une attente de 0,1 s : `GameState._process` (partie en cours, prête) fait avancer le joueur, qui émet `etourdissement_fini` ; c'est le vrai chemin de la fin d'étourdissement, en 0,1 s au lieu de 1,5 ou 2,5 s.
- Les dernières lignes remettent `etourdi_restant` à zéro à la main (sans signal) : les étoiles du lion bleu restent affichées, sans effet sur la suite ; seul l'état du joueur compte pour les vérifications suivantes.
- `get_shader_parameter` ne renvoie que les valeurs écrites par `set_shader_parameter` (phase 7) : les vérifications à `0.0` portent sur la valeur que le lion écrit lui-même.

- [ ] **Step 2 : Lancer le smoke test (échec attendu)**

Run : le smoke test avec délai (100 s suffisent).
Expected : `SCRIPT ERROR: Invalid access to property or key 'CENTRE' on a base object of type 'CharacterBody2D (Lion.gd)'.` La section s'arrête là et le délai coupe le processus.

- [ ] **Step 3 : `Scenes/Lion.tscn`, les étoiles**

3a. Remplacer `[gd_scene load_steps=11 format=3` par `[gd_scene load_steps=12 format=3` (début de la première ligne, le reste inchangé).

3b. Juste après la ligne `[ext_resource type="Script" uid="uid://dmbxtsy64rnau" path="res://Scripts/GerbeTraceuse.gd" id="9_or3p1"]`, ajouter :

```
[ext_resource type="Texture2D" uid="uid://dy0pggnw08ymx" path="res://Assets/Sprites/etoile.png" id="10_etoile"]
```

(uid lu dans `Assets/Sprites/etoile.png.import`.)

3c. À la fin du fichier, après le nœud `Pseudo`, ajouter (une ligne vide avant) :

```
[node name="Etoiles" type="Node2D" parent="."]
visible = false
z_index = 3
position = Vector2(68, 18)

[node name="Etoile1" type="Sprite2D" parent="Etoiles"]
modulate = Color(1, 0.9, 0.3, 1)
scale = Vector2(0.35, 0.35)
texture = ExtResource("10_etoile")

[node name="Etoile2" type="Sprite2D" parent="Etoiles"]
modulate = Color(1, 0.9, 0.3, 1)
scale = Vector2(0.35, 0.35)
texture = ExtResource("10_etoile")

[node name="Etoile3" type="Sprite2D" parent="Etoiles"]
modulate = Color(1, 0.9, 0.3, 1)
scale = Vector2(0.35, 0.35)
texture = ExtResource("10_etoile")
```

(Étoiles de 22 px (64 px × 0,35), centrées sur le haut de la tête (x = 68, le sprite commence à y = 3), sous l'étiquette du pseudo (y de −38 à 0) ; `z_index` au-dessus des particules. Le nœud est enfant du corps : il ne se retourne pas avec le sprite.)

- [ ] **Step 4 : `Scripts/Lion.gd`**

4a. Remplacer les lignes de docstring 2 et 3 :

```gdscript
## Le lion : déplacement, gerbe de vomi multicolore, traceuse de peinture ; en bataille,
## crinière à la couleur de son joueur et pseudo au-dessus de la tête.
```

par :

```gdscript
## Le lion : déplacement, gerbe de vomi multicolore, traceuse de peinture ; en bataille,
## crinière à la couleur de son joueur, pseudo au-dessus de la tête et étourdissement.
```

4b. Juste après `const PAS_RAYON_PAR_CRAN := 5`, ajouter :

```gdscript
const CENTRE := Vector2(68, 66)  # centre du corps, dans le repère du lion
const FORCE_BARBOUILLAGE := 0.7
const RAYON_ETOILES := Vector2(40, 12)
const VITESSE_ETOILES := 5.0  # radians par seconde
```

4c. Juste après `@onready var etiquette_pseudo: Label = $Pseudo`, ajouter :

```gdscript
@onready var etoiles: Node2D = $Etoiles
```

4d. Juste après `var _temps := 0.0`, ajouter :

```gdscript
var _clignotement: Tween
```

4e. Dans `_ready()`, juste après `	joueur.crans_changes.connect(_on_crans_changes)`, ajouter :

```gdscript
	joueur.etourdi.connect(_on_etourdi)
	joueur.etourdissement_fini.connect(_on_etourdissement_fini)
```

4f. Remplacer :

```gdscript
	elif est_en_train_de_vomir:
		arreter_vomi()


func _direction_voulue() -> Vector2:
	return commandes.direction() if GameState.pret else Vector2.ZERO


func _veut_vomir() -> bool:
	return GameState.pret and commandes.vomir()
```

par :

```gdscript
	elif est_en_train_de_vomir:
		arreter_vomi()
	if etoiles.visible:
		_tourner_etoiles()


## Un lion étourdi ignore ses commandes : il ne se dirige plus et ne vomit plus.
func _direction_voulue() -> Vector2:
	return commandes.direction() if GameState.pret and not joueur.est_etourdi() else Vector2.ZERO


func _veut_vomir() -> bool:
	return GameState.pret and not joueur.est_etourdi() and commandes.vomir()
```

4g. Remplacer toute la fonction `_on_lion_touche` et sa docstring :

```gdscript
## Recul et clignotement pendant l'invulnérabilité qui suit un coup.
func _on_lion_touche(origine: Vector2) -> void:
	Audio.jouer("mort")
	var direction_recul := Vector2(-direction_du_lion, 0.0)
	if origine.is_finite():
		direction_recul = (global_position + Vector2(68, 66) - origine).normalized()
		if direction_recul.length() < 0.1:
			direction_recul = Vector2(-direction_du_lion, 0.0)
	_recul = direction_recul * force_recul
	var tween := create_tween()
	var nb_clignotements := int(GameState.DUREE_INVULNERABILITE / 0.15)
	for i in range(nb_clignotements):
		tween.tween_property(sprite, "modulate:a", 0.25, 0.075)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.075)
```

par :

```gdscript
## Recul et clignotement pendant l'invulnérabilité qui suit un coup (solo).
func _on_lion_touche(origine: Vector2) -> void:
	Audio.jouer("mort")
	_reculer(origine)
	_clignoter(joueur.invulnerable_restant)


## Étourdi (bataille) : immobile, repoussé, tête barbouillée de la couleur de l'agresseur
## (aucune pour un ennemi), étoiles qui tournent. Le vomi s'arrête au `_process` suivant
## (`_veut_vomir` est faux pendant l'étourdissement) ; d'ici là, les règles ignorent un
## agresseur étourdi.
func _on_etourdi(origine: Vector2, barbouillage: Color) -> void:
	_vitesse = Vector2.ZERO
	_reculer(origine)
	_barbouiller(barbouillage)
	etoiles.visible = true
	_tourner_etoiles()


## Fin de l'étourdissement : barbouillage et étoiles s'en vont, l'immunité clignote.
func _on_etourdissement_fini() -> void:
	_barbouiller(Color.TRANSPARENT)
	etoiles.visible = false
	_clignoter(joueur.invulnerable_restant)


func _reculer(origine: Vector2) -> void:
	var direction_recul := Vector2(-direction_du_lion, 0.0)
	if origine.is_finite():
		direction_recul = (global_position + CENTRE - origine).normalized()
		if direction_recul.length() < 0.1:
			direction_recul = Vector2(-direction_du_lion, 0.0)
	_recul = direction_recul * force_recul


## Clignotement de l'invulnérabilité : le même après un coup (solo) et pour l'immunité qui suit
## un étourdissement (bataille).
func _clignoter(duree: float) -> void:
	var nb_clignotements := int(duree / 0.15)
	if nb_clignotements <= 0:
		return
	if _clignotement != null:
		_clignotement.kill()
	sprite.modulate.a = 1.0
	_clignotement = create_tween()
	for i in range(nb_clignotements):
		_clignotement.tween_property(sprite, "modulate:a", 0.25, 0.075)
		_clignotement.tween_property(sprite, "modulate:a", 1.0, 0.075)


## Toute la tête vire à `couleur` (uniformes du shader de teinte) ; une couleur transparente
## efface le barbouillage. Sans matériau (joueur sans couleur), rien à barbouiller.
func _barbouiller(couleur: Color) -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("barbouillage_couleur", couleur)
	mat.set_shader_parameter("barbouillage_force", FORCE_BARBOUILLAGE if couleur.a > 0.0 else 0.0)


func _tourner_etoiles() -> void:
	var nb := etoiles.get_child_count()
	for i in range(nb):
		var angle := _temps * VITESSE_ETOILES + TAU * i / nb
		etoiles.get_child(i).position = Vector2(cos(angle) * RAYON_ETOILES.x, sin(angle) * RAYON_ETOILES.y)
```

Pourquoi le solo ne change pas : au moment où `touche` est émis, `encaisser_coup` vient de régler `invulnerable_restant` à `GameState.DUREE_INVULNERABILITE` (1,5 s) : `int(1.5 / 0.15)` donne les mêmes dix clignotements qu'avant. Tuer un clignotement précédent ne change rien en solo : un nouveau coup n'arrive qu'après la fin de l'invulnérabilité, donc du clignotement. Un lion sans couleur n'a pas de matériau : `_barbouiller` ne fait rien.

- [ ] **Step 5 : Vérifier**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|SHADER ERROR|Parse Error|Compile Error"` (aucune ligne), les tests unitaires avec délai (verts), puis **5 passages** consécutifs du smoke test : verts, sans `SCRIPT ERROR` ni `SHADER ERROR`, avec les 13 nouvelles vérifications (`✅`) ; celles du coup en solo (« le lion est repoussé par le coup », « le lion est invulnérable après un coup ») restent vertes.

- [ ] **Step 6 : Planche de contrôle (rendu réel, une fenêtre s'ouvre)**

Écrire `$SCRATCH/rendu_etourdi.gd` :

```gdscript
extends SceneTree
## Planche de contrôle de l'étourdissement (phase 8 bis, non commitée) :
## godot --rendering-driver opengl3 --script <ce fichier> -- --dossier=<dossier>
## Colonnes : rouge normal, bleu étourdi par le vomi du rouge, jaune étourdi par un ennemi,
## vert étourdi par le vomi du jaune.

const PSEUDOS := ["Normal", "Vomi du rouge", "Ennemi", "Vomi du jaune"]
var dossier := "user://"


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dossier="):
			dossier = arg.trim_prefix("--dossier=")
	call_deferred("_run")


func _run() -> void:
	var gs: Node = root.get_node("GameState")
	gs.configurer_bataille(4)
	gs.nouvelle_partie()
	gs.pret = true
	# Même ciel que Scenes/Main.tscn
	var degrade := Gradient.new()
	degrade.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	degrade.colors = PackedColorArray([Color(0.09, 0.1, 0.24), Color(0.42, 0.25, 0.43), Color(0.9, 0.5, 0.32)])
	var texture_ciel := GradientTexture2D.new()
	texture_ciel.gradient = degrade
	texture_ciel.fill_to = Vector2(0, 1)
	var ciel := TextureRect.new()
	ciel.texture = texture_ciel
	ciel.size = Vector2(2000, 648)
	root.add_child(ciel)
	var lions: Array[Node] = []
	for i in range(4):
		gs.joueurs[i].pseudo = PSEUDOS[i]
		var lion: Node = load("res://Scenes/Lion.tscn").instantiate()
		lion.joueur = gs.joueurs[i]
		lion.commandes = Commandes.manuelles()
		lion.position = Vector2(100 + i * 450, 250)
		root.add_child(lion)
		lions.append(lion)
	await process_frame
	gs.regles.lion_touche_par_vomi(gs.joueurs[3], gs.joueurs[2], Vector2.INF)  # avant que le jaune soit étourdi
	gs.regles.lion_touche_par_vomi(gs.joueurs[1], gs.joueurs[0], Vector2.INF)
	gs.regles.lion_touche_par_ennemi(gs.joueurs[2], Vector2.INF)
	for i in range(3):
		await process_frame
	for i in range(4):
		lions[i]._recul = Vector2.ZERO
		lions[i].position = Vector2(100 + i * 450, 250)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(dossier.path_join("etourdi.png"))
	# Agrandi ×2, deux moitiés, pour le détail
	for moitie in range(2):
		var morceau := image.get_region(Rect2i(moitie * 1000, 150, 1000, 300))
		morceau.resize(2000, 600, Image.INTERPOLATE_NEAREST)
		morceau.save_png(dossier.path_join("etourdi_x2_%d.png" % moitie))
	print("📸 etourdi.png ", image.get_size())
	quit(0)
```

Puis :

```sh
export PATH="/opt/homebrew/bin:$PATH"; mkdir -p "$SCRATCH/rendu"
( godot --rendering-driver opengl3 --script "$SCRATCH/rendu_etourdi.gd" -- --dossier="$SCRATCH/rendu" > "$SCRATCH/rendu/rendu.log" 2>&1 & p=$!; for i in $(seq 1 60); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null )
grep -E "SCRIPT ERROR|SHADER ERROR|📸" "$SCRATCH/rendu/rendu.log"
```

Expected : `📸 etourdi.png (2000, 648)`, aucune erreur.

- [ ] **Step 7 : Regarder la planche (outil Read) et juger**

Lire `etourdi.png` (taille réelle), puis `etourdi_x2_0.png` et `etourdi_x2_1.png`. **« Ça rend bien »** veut dire :

1. colonnes 2 et 4 : toute la tête vire nettement à la couleur de l'agresseur (rouge, jaune), visage compris, et la couleur du joueur se devine encore dans l'ombre de la crinière ; les yeux et le contour restent lisibles ;
2. colonne 3 (ennemi) : aucune trace de barbouillage, crinière jaune d'origine ;
3. colonnes 2 à 4 : trois étoiles jaunes autour du haut de la tête, qui débordent un peu sur le pseudo sans le rendre illisible ; colonne 1 : aucune étoile ;
4. les pseudos restent lisibles.

Référence : c'est ce qu'a donné la mise au point du plan avec les réglages de la Task 2. Défaut toléré : sur le lion jaune, les étoiles jaunes contrastent moins (question de palette, phase 11). Leviers, un seul à la fois, avec un nouveau rendu à chaque essai : `FORCE_BARBOUILLAGE` (0,5 à 0,8), la `position` du nœud `Etoiles` et `RAYON_ETOILES`. Si un réglage change, relancer le smoke test 5 fois (la vérification du barbouillage lit `lb.FORCE_BARBOUILLAGE`, elle suit la constante).

- [ ] **Step 8 : Commit**

```bash
git add Scenes/Lion.tscn Scripts/Lion.gd tests/smoke_test.gd
git commit -m "Lion : étourdissement (commandes ignorées, recul, tête barbouillée de la couleur de l'agresseur, étoiles) puis clignotement de l'immunité, lu sur l'invulnérabilité du joueur

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 3 : zones de contact sur la parabole, `class_name Lion`

**Files:**
- Modify: `Scripts/Lion.gd`
- Modify: `tests/smoke_test.gd` (section « Bataille »)

**Interfaces:**
- Consumes : Tasks 1 et 2, `Regles.lion_touche_par_vomi` (phase 8), `multiplayer.is_server()` (vrai en solo et hors réseau : `OfflineMultiplayerPeer`).
- Produces : `class_name Lion` ; `Lion.NB_ZONES_CONTACT := 3`, `RAYON_ZONE_CONTACT := 22.0`, `COUCHE_CORPS_LIONS := 1` ; `Lion.zones_contact: Array[Area2D]` (`ZoneContact1` à `3`, couche 0, masque 1, actives seulement pendant le vomi) ; `_point_de_gerbe(t)` remplace `_point_de_chute()` ; `_creer_zones_contact()`, `_signaler_vomi_sur_les_lions()`.

- [ ] **Step 1 : `tests/smoke_test.gd`, les vérifications**

Dans la section « Bataille », juste avant les lignes de fin `	for l in lions_bataille:` / `		l.free()` / `	GS.configurer_solo()`, ajouter :

```gdscript
	# Zones de contact : trois, le long de la parabole, jusqu'au point de chute
	var zones: Array[Area2D] = lr.zones_contact
	_check(zones.size() == 3 and zones[2].position == lr.gerbe_traceuse.position
		and zones[0].position.y < zones[1].position.y and zones[1].position.y < zones[2].position.y
		and zones.all(func(z: Area2D) -> bool: return z.collision_layer == 0 and not z.monitoring),
		"trois zones de contact sur la parabole, la dernière au point de chute, inertes hors du vomi")
	_check(zones[0].get_child(0).shape != lb.zones_contact[0].get_child(0).shape, "chaque lion a ses propres formes de zones de contact")
	j_bleu.invulnerable_restant = 0.0
	var infliges_avant: int = j_rouge.etourdissements_infliges
	lb._recul = Vector2.ZERO
	lb.global_position = lr.to_global(zones[1].position) - lb.CENTRE
	await _frames(2)
	lr.commandes.vomir_voulu = true
	for i in range(30):  # vomi démarré au _process, contacts connus au tick physique suivant
		await _frames(1)
		if j_bleu.est_etourdi():
			break
	_check(j_bleu.est_etourdi() and materiau_bleu.get_shader_parameter("barbouillage_couleur") == j_rouge.couleur
		and j_rouge.etourdissements_infliges == infliges_avant + 1 and not j_rouge.est_etourdi(),
		"la gerbe d'un lion étourdit l'autre lion qu'elle touche, barbouillé de sa couleur, et lui compte l'étourdissement")
	var etourdi_apres_coup: float = j_bleu.etourdi_restant
	await _frames(10)
	_check(j_rouge.etourdissements_infliges == infliges_avant + 1 and j_bleu.etourdi_restant < etourdi_apres_coup,
		"un lion déjà étourdi n'est pas ré-étourdi par la gerbe qui le touche encore")
	lr.commandes.vomir_voulu = false
	await _frames(3)  # le vomi s'arrête au _process suivant : pas de nouveau contact ensuite
	j_bleu.etourdi_restant = 0.0
	j_bleu.invulnerable_restant = 0.0

```

Notes :
- Le centre du lion bleu est posé sur la zone du milieu : son corps (63 px) touche aussi la première zone ; les règles ne comptent qu'un étourdissement.
- Le compteur de l'agresseur est comparé à sa valeur d'avant : la Task 2 a déjà fait étourdir le bleu par le rouge, directement par les règles.
- La détection prend trois ticks au moment du plan (vomi démarré dans `_process`, recouvrements connus au tick physique suivant, signalement au tick d'après) : la boucle attend jusqu'à 30 ticks.

- [ ] **Step 2 : Lancer le smoke test (échec attendu)**

Run : le smoke test avec délai (100 s).
Expected : `SCRIPT ERROR: Invalid access to property or key 'zones_contact' on a base object of type 'CharacterBody2D (Lion.gd)'.` La section s'arrête là et le délai coupe le processus.

- [ ] **Step 3 : `Scripts/Lion.gd`**

3a. Remplacer le début du fichier :

```gdscript
extends CharacterBody2D
## Le lion : déplacement, gerbe de vomi multicolore, traceuse de peinture ; en bataille,
## crinière à la couleur de son joueur, pseudo au-dessus de la tête et étourdissement.
## La gerbe part de la bouche à 45° vers le bas ; la traceuse est placée au point de
## chute calculé avec la même physique que les particules.
```

par :

```gdscript
class_name Lion
extends CharacterBody2D
## Le lion : déplacement, gerbe de vomi multicolore, traceuse de peinture ; en bataille,
## crinière à la couleur de son joueur, pseudo au-dessus de la tête et étourdissement.
## La gerbe part de la bouche à 45° vers le bas ; la traceuse est placée au point de chute et
## les zones de contact le long de la parabole, avec la même physique que les particules.
## Le lion ne décide de rien : sur l'hôte, il signale aux règles les autres lions que touche
## sa gerbe, comme le font les ennemis et les pastilles.
```

3b. Juste après `const PAS_RAYON_PAR_CRAN := 5`, ajouter :

```gdscript
const NB_ZONES_CONTACT := 3
const RAYON_ZONE_CONTACT := 22.0
const COUCHE_CORPS_LIONS := 1  # couche du corps des lions, celle que détectent ennemis et pastilles
```

3c. Juste après `var commandes: Commandes`, ajouter :

```gdscript
## Zones de contact de la gerbe, de la bouche au point de chute (la dernière y rejoint la traceuse).
var zones_contact: Array[Area2D] = []
```

3d. Dans `_ready()`, remplacer :

```gdscript
	joueur.etourdissement_fini.connect(_on_etourdissement_fini)
	_appliquer_direction()
```

par :

```gdscript
	joueur.etourdissement_fini.connect(_on_etourdissement_fini)
	_creer_zones_contact()
	_appliquer_direction()
```

(Avant `_appliquer_direction()`, qui place la traceuse et désormais les zones.)

3e. À la fin de `_physics_process`, juste après `	global_position.y = clamp(global_position.y, 0, screen_rect.size.y - sprite_size.y)`, ajouter :

```gdscript
	_signaler_vomi_sur_les_lions()
```

3f. Remplacer :

```gdscript
## Point de chute d'une particule tirée à 45° (même physique que le ParticleProcessMaterial).
func _point_de_chute() -> Vector2:
	var v := Vector2.from_angle(deg_to_rad(ANGLE_GERBE_DEG)) * VITESSE_GERBE
	var chute := Vector2(v.x * DUREE_GERBE, v.y * DUREE_GERBE + 0.5 * GRAVITE_GERBE * DUREE_GERBE * DUREE_GERBE)
	chute.x *= direction_du_lion
	return bouche.position + chute


## Traceuse au point de chute ; rayon de peinture selon les crans (16 px au premier, 5 px de
## plus par cran, 46 px au plus) et le bonus.
func _placer_traceuse() -> void:
	gerbe_traceuse.position = _point_de_chute()
	if traceuse_shape.shape is CircleShape2D:
		var rayon: float = clamp(RAYON_TRACEUSE.x + (joueur.crans - 1) * PAS_RAYON_PAR_CRAN, RAYON_TRACEUSE.x, RAYON_TRACEUSE.y)
		traceuse_shape.shape.radius = rayon * _facteur_bonus()
```

par :

```gdscript
## Position, dans le repère du lion, d'une particule tirée à 45° après `t` secondes de vol
## (même physique que le ParticleProcessMaterial). `t = DUREE_GERBE` : le point de chute.
func _point_de_gerbe(t: float) -> Vector2:
	var v := Vector2.from_angle(deg_to_rad(ANGLE_GERBE_DEG)) * VITESSE_GERBE
	var point := Vector2(v.x * t, v.y * t + 0.5 * GRAVITE_GERBE * t * t)
	point.x *= direction_du_lion
	return bouche.position + point


## Traceuse au point de chute ; rayon de peinture selon les crans (16 px au premier, 5 px de
## plus par cran, 46 px au plus) et le bonus. Zones de contact réparties sur la parabole.
func _placer_traceuse() -> void:
	gerbe_traceuse.position = _point_de_gerbe(DUREE_GERBE)
	if traceuse_shape.shape is CircleShape2D:
		var rayon: float = clamp(RAYON_TRACEUSE.x + (joueur.crans - 1) * PAS_RAYON_PAR_CRAN, RAYON_TRACEUSE.x, RAYON_TRACEUSE.y)
		traceuse_shape.shape.radius = rayon * _facteur_bonus()
	for i in range(zones_contact.size()):
		zones_contact[i].position = _point_de_gerbe(DUREE_GERBE * (i + 1) / zones_contact.size())
		(zones_contact[i].get_child(0).shape as CircleShape2D).radius = RAYON_ZONE_CONTACT * _facteur_bonus()


## Zones qui détectent le corps des autres lions sur la trajectoire de la gerbe, pendant le
## vomi. Créées par le code : chaque lion a ses propres formes (leur rayon suit son bonus).
func _creer_zones_contact() -> void:
	for i in range(NB_ZONES_CONTACT):
		var zone := Area2D.new()
		zone.name = "ZoneContact%d" % (i + 1)
		zone.collision_layer = 0  # rien ne la détecte (ennemis, pastilles, ville)
		zone.collision_mask = COUCHE_CORPS_LIONS
		zone.monitorable = false
		zone.monitoring = false
		var forme := CollisionShape2D.new()
		forme.shape = CircleShape2D.new()
		zone.add_child(forme)
		add_child(zone)
		zones_contact.append(zone)


## Sur l'hôte : chaque autre lion que touche la gerbe est signalé aux règles, à chaque frame
## de contact (les règles ignorent un lion déjà étourdi ou immunisé).
func _signaler_vomi_sur_les_lions() -> void:
	if not est_en_train_de_vomir or not multiplayer.is_server():
		return
	for zone in zones_contact:
		for corps in zone.get_overlapping_bodies():
			var victime := corps as Lion
			if victime != null and victime != self:
				GameState.regles.lion_touche_par_vomi(victime.joueur, joueur, zone.global_position)
```

(`_point_de_chute` n'avait pas d'autre appelant : `grep -rn "_point_de_chute" Scripts tests` ne doit plus rien trouver. Les zones sont à 0,2, 0,4 et 0,6 s de vol ; la dernière coïncide avec la traceuse. Leur rayon suit le bonus comme la gerbe. En solo, un seul lion : `get_overlapping_bodies()` ne rend que le lion lui-même, s'il touche sa première zone, et il est écarté.)

3g. Remplacer :

```gdscript
	est_en_train_de_vomir = true
	gerbe_traceuse.monitoring = true
```

par :

```gdscript
	est_en_train_de_vomir = true
	gerbe_traceuse.monitoring = true
	for zone in zones_contact:
		zone.monitoring = true
```

3h. Remplacer :

```gdscript
	est_en_train_de_vomir = false
	gerbe_traceuse.monitoring = false
```

par :

```gdscript
	est_en_train_de_vomir = false
	gerbe_traceuse.monitoring = false
	for zone in zones_contact:
		zone.monitoring = false
```

- [ ] **Step 4 : Vérifier**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|SHADER ERROR|Parse Error|Compile Error"` (aucune ligne : la classe `Lion` entre dans le cache des classes globales), les tests unitaires avec délai (verts), puis **5 passages** consécutifs du smoke test : verts, sans `SCRIPT ERROR` ni `SHADER ERROR`, avec les 4 nouvelles vérifications. Puis `grep -n "Lion" tests/*.gd | grep -v '"'` : aucune ligne (le mot n'apparaît dans les tests que dans des chaînes, comme `"res://Scenes/Lion.tscn"` : aucun test ne nomme la classe).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Lion.gd tests/smoke_test.gd
git commit -m "Lion : trois zones de contact sur la parabole de la gerbe ; sur l'hôte, chaque autre lion touché est signalé aux règles (class_name Lion)

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 4 : auto-tamponneuses ; feuille de route

**Files:**
- Modify: `Scenes/Lion.tscn` (masque du corps, pare-chocs)
- Modify: `Scripts/Lion.gd`
- Modify: `tests/smoke_test.gd` (section « Bataille »)
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (Step 7)

**Interfaces:**
- Consumes : Tasks 1 à 3, `Regles.choc_entre_lions` (phase 8).
- Produces : corps du lion à `collision_mask = 0` ; `Lion.pare_chocs: Area2D` (`$PareChocs`, couche 16, masque 16, cercle de 45 px centré sur le corps) et `_rayon_choc` lu sur sa forme ; exports `facteur_choc = 1.2`, `raideur_choc = 8.0` ; `DUREE_SECOUSSE`, `AMPLITUDE_SECOUSSE`, `_secousse_restante` ; `_on_pare_chocs_area_entered`, `_bloquer_contre_les_lions`, `_normale_de_choc`.

- [ ] **Step 1 : `tests/smoke_test.gd`, les vérifications**

Dans la section « Bataille », juste avant les lignes de fin `	for l in lions_bataille:` / `		l.free()` / `	GS.configurer_solo()`, ajouter :

```gdscript
	# Auto-tamponneuses : pare-chocs réduit, recul proportionnel à la vitesse d'approche
	_check(lr.collision_mask == 0 and lr.pare_chocs.collision_layer == 16 and lr.pare_chocs.collision_mask == 16
		and is_equal_approx(lr._rayon_choc, 45.0) and lr.get_node("CollisionShape2D").shape.radius > 60.0,
		"les lions se heurtent sur leur couche dédiée, à 45 px ; le corps (63 px) reste celui que touchent ennemis et pastilles")
	lr._recul = Vector2.ZERO
	lb._recul = Vector2.ZERO
	lr.global_position = Vector2(600, 300)
	lb.global_position = Vector2(800, 300)
	await _frames(2)
	lr.commandes.direction_voulue = Vector2.RIGHT
	for i in range(90):
		await _frames(1)
		if j_rouge.chocs > 0:
			break
	lr.commandes.direction_voulue = Vector2.ZERO
	_check(j_rouge.chocs == 1 and j_bleu.chocs == 1, "un choc est compté une fois, pour les deux lions")
	_check(lr._recul.x < 0.0 and lb._recul.x > 0.0 and lr._secousse_restante > 0.0 and lb._secousse_restante > 0.0,
		"au choc, les deux lions reculent chacun de son côté, et leur sprite tremble")
	_check(not j_rouge.est_etourdi() and not j_bleu.est_etourdi(), "un choc n'étourdit personne")
	var distance_min := 1e9
	for i in range(30):
		await _frames(1)
		distance_min = minf(distance_min, lr.pare_chocs.global_position.distance_to(lb.pare_chocs.global_position))
	_check(distance_min > 2 * 45.0 - 15.0 and j_rouge.chocs == 1,
		"les lions ne s'enfoncent pas l'un dans l'autre (distance min %.0f px), un seul choc compté" % distance_min)
	# Un lion étourdi peut être poussé
	GS.regles.lion_touche_par_ennemi(j_bleu, Vector2.INF)
	lb._recul = Vector2.ZERO
	lr._recul = Vector2.ZERO
	lr.global_position = Vector2(600, 300)
	lb.global_position = Vector2(800, 300)
	await _frames(2)
	var x_bleu: float = lb.global_position.x
	lr.commandes.direction_voulue = Vector2.RIGHT
	distance_min = 1e9
	for i in range(40):
		await _frames(1)
		distance_min = minf(distance_min, lr.pare_chocs.global_position.distance_to(lb.pare_chocs.global_position))
	lr.commandes.direction_voulue = Vector2.ZERO
	_check(j_bleu.est_etourdi() and lb.global_position.x > x_bleu + 10.0 and j_rouge.chocs >= 2,
		"un lion étourdi est poussé par celui qui le percute (%.0f px)" % (lb.global_position.x - x_bleu))
	_check(distance_min > 2 * 45.0 - 15.0, "même en poussant sans relâche, un lion ne s'enfonce pas dans l'autre (distance min %.0f px)" % distance_min)

```

Notes :
- Mesures au moment du plan : 96 px au plus près après le premier choc, 84 px en poussant sans relâche (seuil : 75 px), 54 px de poussée du lion étourdi (seuil : 10 px).
- Le lion rouge s'arrête dès le premier choc compté : sinon il rebondit puis revient, et chaque nouveau contact est un nouveau choc (c'est voulu : les titres comptent les chocs).
- Le lion bleu est poussé alors qu'il ignore ses commandes : c'est le recul de son pare-chocs qui le déplace.

- [ ] **Step 2 : Lancer le smoke test (échec attendu)**

Run : le smoke test avec délai (100 s).
Expected : `❌ les lions se heurtent sur leur couche dédiée…`, `❌ un choc est compté une fois, pour les deux lions` (sans pare-chocs, aucun choc n'est signalé), `❌ au choc, les deux lions reculent…`, puis `SCRIPT ERROR: Invalid access to property or key 'pare_chocs' on a base object of type 'CharacterBody2D (Lion)'.` et le délai coupe le processus.

- [ ] **Step 3 : `Scenes/Lion.tscn`, le pare-chocs**

3a. Remplacer `[gd_scene load_steps=12 format=3` par `[gd_scene load_steps=13 format=3`.

3b. Juste après :

```
[sub_resource type="CircleShape2D" id="CircleShape2D_03dqy"]
radius = 62.0725
```

ajouter (une ligne vide avant) :

```
[sub_resource type="CircleShape2D" id="CircleShape2D_choc"]
radius = 45.0
```

3c. Remplacer :

```
[node name="Lion" type="CharacterBody2D" groups=["lion"]]
script = ExtResource("1_3r2l0")
```

par :

```
[node name="Lion" type="CharacterBody2D" groups=["lion"]]
collision_mask = 0
script = ExtResource("1_3r2l0")
```

(Le corps garde sa couche 1, où ennemis, pastilles et zones de contact le détectent ; il ne heurte plus rien. En solo, il ne heurtait déjà rien : aucun autre corps dans la scène.)

3d. À la fin du fichier, après le dernier sprite `Etoile3`, ajouter (une ligne vide avant) :

```
[node name="PareChocs" type="Area2D" parent="."]
position = Vector2(68, 66)
collision_layer = 16
collision_mask = 16

[node name="CollisionShape2D" type="CollisionShape2D" parent="PareChocs"]
shape = SubResource("CircleShape2D_choc")
```

(Couche 5 (valeur 16) : ni les ennemis, ni les pastilles, ni la ville (couche 4, valeur 8) ne la voient. La forme est partagée par toutes les instances et n'est jamais modifiée.)

- [ ] **Step 4 : `Scripts/Lion.gd`**

4a. Remplacer les lignes de docstring :

```gdscript
## Le lion : déplacement, gerbe de vomi multicolore, traceuse de peinture ; en bataille,
## crinière à la couleur de son joueur, pseudo au-dessus de la tête et étourdissement.
```

par :

```gdscript
## Le lion : déplacement, gerbe de vomi multicolore, traceuse de peinture ; en bataille,
## crinière à la couleur de son joueur, pseudo au-dessus de la tête, étourdissement et
## auto-tamponneuses.
```

et :

```gdscript
## Le lion ne décide de rien : sur l'hôte, il signale aux règles les autres lions que touche
## sa gerbe, comme le font les ennemis et les pastilles.
```

par :

```gdscript
## Le lion ne décide de rien : sur l'hôte, il signale aux règles les autres lions que touche
## sa gerbe et ceux qu'il percute, comme le font les ennemis et les pastilles.
```

4b. Juste après `const VITESSE_ETOILES := 5.0  # radians par seconde`, ajouter :

```gdscript
const DUREE_SECOUSSE := 0.25
const AMPLITUDE_SECOUSSE := 6.0
```

4c. Juste après `@export var inclinaison_max: float = 0.14  # radians`, ajouter :

```gdscript
## Auto-tamponneuses : recul de chaque lion = vitesse d'approche relative × facteur_choc.
@export var facteur_choc: float = 1.2
## Vitesse d'écartement de deux lions qui se chevauchent, par pixel d'enfoncement.
@export var raideur_choc: float = 8.0
```

4d. Juste après `@onready var etoiles: Node2D = $Etoiles`, ajouter :

```gdscript
@onready var pare_chocs: Area2D = $PareChocs
@onready var _rayon_choc: float = ($PareChocs/CollisionShape2D.shape as CircleShape2D).radius
```

4e. Juste après `var _clignotement: Tween`, ajouter :

```gdscript
var _secousse_restante := 0.0
```

4f. Dans `_ready()`, juste après `	joueur.etourdissement_fini.connect(_on_etourdissement_fini)`, ajouter :

```gdscript
	pare_chocs.area_entered.connect(_on_pare_chocs_area_entered)
```

4g. Dans `_physics_process`, remplacer `	velocity = _vitesse + _recul` par :

```gdscript
	velocity = _bloquer_contre_les_lions(_vitesse + _recul)
```

4h. Remplacer `func _process(_delta: float) -> void:` par `func _process(delta: float) -> void:`, puis, dans cette fonction, remplacer :

```gdscript
	if etoiles.visible:
		_tourner_etoiles()
```

par :

```gdscript
	if etoiles.visible:
		_tourner_etoiles()
	if _secousse_restante > 0.0:
		_secousse_restante = max(0.0, _secousse_restante - delta)
		var amplitude := AMPLITUDE_SECOUSSE * _secousse_restante / DUREE_SECOUSSE
		sprite.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amplitude
```

(La secousse passe par `sprite.offset`, que rien d'autre n'utilise : elle ne gêne ni le trottinement (`sprite.position.y`), ni l'inclinaison, ni le retournement. Elle revient à zéro avec son amplitude.)

4i. Juste avant `func _on_crans_changes(_crans: int) -> void:`, ajouter :

```gdscript
## Auto-tamponneuses, au premier contact : chaque lion recule en proportion de la vitesse à
## laquelle les deux se rapprochaient (un lion étourdi est donc poussé), et son sprite tremble.
func _on_pare_chocs_area_entered(zone: Area2D) -> void:
	var autre := zone.get_parent() as Lion
	if autre == null or autre == self:
		return
	var normale := _normale_de_choc(autre)
	var approche := (velocity - autre.velocity).dot(-normale)
	_recul += normale * maxf(approche, 0.0) * facteur_choc
	_secousse_restante = DUREE_SECOUSSE
	# Un seul signalement par choc : celui des deux lions dont l'identifiant est le plus petit.
	if multiplayer.is_server() and get_instance_id() < autre.get_instance_id():
		GameState.regles.choc_entre_lions(joueur, autre.joueur)


## Pendant le contact, un lion ne s'enfonce pas dans l'autre (la part de sa vitesse dirigée
## vers lui est annulée), et deux lions qui se chevauchent s'écartent.
func _bloquer_contre_les_lions(v: Vector2) -> Vector2:
	for zone in pare_chocs.get_overlapping_areas():
		var autre := zone.get_parent() as Lion
		if autre == null or autre == self:
			continue
		var normale := _normale_de_choc(autre)
		var vers_autre := v.dot(-normale)
		if vers_autre > 0.0:
			v += normale * vers_autre
		var enfoncement := 2.0 * _rayon_choc - pare_chocs.global_position.distance_to(autre.pare_chocs.global_position)
		v += normale * maxf(enfoncement, 0.0) * raideur_choc
	return v


## Direction de l'autre lion vers celui-ci ; deux lions superposés s'écartent quand même,
## chacun de son côté.
func _normale_de_choc(autre: Lion) -> Vector2:
	var ecart := pare_chocs.global_position - autre.pare_chocs.global_position
	if ecart.length() > 0.01:
		return ecart.normalized()
	return Vector2.LEFT if get_instance_id() < autre.get_instance_id() else Vector2.RIGHT


```

Pourquoi c'est symétrique : les deux pare-chocs reçoivent `area_entered` pendant le même tick physique ; chaque lion ne modifie que son propre `_recul` et lit la `velocity` de l'autre, qui n'est recalculée qu'au tick suivant. Les deux lions voient donc la même vitesse d'approche et des normales opposées.

- [ ] **Step 5 : Vérifier**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|SHADER ERROR|Parse Error|Compile Error"` (aucune ligne), les tests unitaires avec délai (verts), puis **5 passages** consécutifs du smoke test : verts, sans `SCRIPT ERROR` ni `SHADER ERROR`, avec les 7 nouvelles vérifications et, dans `$TMPDIR/t.log`, des distances minimales proches de celles du plan (96 et 84 px).

- [ ] **Step 6 : Commit (code)**

```bash
git add Scenes/Lion.tscn Scripts/Lion.gd tests/smoke_test.gd
git commit -m "Lion : auto-tamponneuses (pare-chocs de 45 px sur une couche dédiée, recul proportionnel à la vitesse d'approche, blocage, secousse du sprite) ; le choc est signalé une fois aux règles

Co-Authored-By: <ligne imposée par l'environnement>"
```

- [ ] **Step 7 : Feuille de route, points résolus par la phase 8 bis**

**Ne jamais modifier le fichier du plan** (ce fichier, ni celui de la phase 8) : seule la feuille de route change ici.

7a. Supprimer l'item résolu (Task 2) :

```markdown
- **phase 8 bis** : le barbouillage passe par les uniformes `barbouillage_couleur` /
  `barbouillage_force` du matériau du lion (`Shaders/Lion.gdshader`, déjà prêts à 0). Ce matériau
  n'existe que si le joueur a une couleur, ce qui est toujours vrai en bataille ;
```

7b. Remplacer :

```markdown
- **phase 8 bis** : ajouter `class_name Lion` (les zones de contact et le pare-chocs s'en servent).
  **Phases 8 ter (ennemis) et 14 bis (pastilles)** : tester `body is Lion` dans les gestionnaires
  de contact au lieu de supposer `body.joueur`. Les tests `--script` (compilés avant les
  autoloads) continuent de typer les lions en `Node` / `CharacterBody2D`, jamais `Lion` : `Lion.gd`
  nomme `GameState` et `Audio` ;
```

par :

```markdown
- **phases 8 ter (ennemis) et 14 bis (pastilles)** : `class_name Lion` existe depuis la phase
  8 bis ; tester `body is Lion` dans les gestionnaires de contact au lieu de supposer
  `body.joueur`. Les tests `--script` (compilés avant les autoloads) continuent de typer les lions
  en `Node` / `CharacterBody2D`, jamais `Lion` : `Lion.gd` nomme `GameState` et `Audio` ;
```

7c. Ajouter à la fin de la liste :

```markdown
- **phase 16** : chaque machine simule le choc de son lion (`Lion._on_pare_chocs_area_entered` :
  recul, secousse), mais seul l'hôte le signale aux règles ; l'étourdissement, lui, ne vient que
  des règles de l'hôte (`Joueur.etourdir`) : `PredictionLocale` suspend la prédiction tant que
  `joueur.est_etourdi()` (spec §4.1) ;
- **phase 17 bis** : jouer le « boing » dans `Lion._on_pare_chocs_area_entered`, sur chaque machine
  (pas seulement l'hôte) : c'est ce qui le rend immédiat pour le joueur local (spec §4.1) ;
```

- [ ] **Step 8 : Commit (documentation)**

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
git commit -m "Feuille de route : points de vigilance résolus par la phase 8 bis (barbouillage, class_name Lion) ; chocs et prédiction, boing

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

## Sortie de phase

- Les deux suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR`, localement (smoke test 5 fois) puis en CI sur la PR.
- Planche `etourdi.png` regardée et conforme aux critères de la Task 2 : la joindre à la demande de validation de l'utilisateur (sortie ◉ « lions étourdis » de la feuille de route), avec le défaut toléré nommé (étoiles jaunes sur le lion jaune).
- `git diff main --stat` : 5 fichiers de code (`Scripts/ReglesSolo.gd`, `tests/unitaires.gd`, `Scripts/Lion.gd`, `Scenes/Lion.tscn`, `tests/smoke_test.gd`) plus la feuille de route.
- Rappeler à l'utilisateur : `tests/screenshots.gd` n'a pas été relancé (solo inchangé, rayons vérifiés par le smoke test) et son `SCRIPT ERROR` préexistant (Spawner pendant l'intro) reste inscrit dans la feuille de route ; aucun son pour les chocs avant la phase 17 bis ; la bataille ne se joue pas encore (scène de bataille et branchement des modes : phase 10).
