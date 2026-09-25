# Phase 7 : teinte de la crinière et pseudo, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** la crinière de chaque lion prend la couleur de son joueur (visage, yeux, museau, langue et contour gardent leurs couleurs), sur les deux sprites (repos et vomi). En bataille, le pseudo du joueur s'affiche au-dessus du lion, dans sa couleur. **Le lion du solo reste exactement celui d'aujourd'hui.** C'est le premier changement visible du multijoueur.

**Architecture:** `Joueur.couleur` vaut `Color.TRANSPARENT` par défaut : alpha 0 = « pas de couleur de lion », c'est le cas du solo (`Joueur.a_une_couleur()`). `Lion.appliquer_apparence()` (appelée dans `_ready`) : si le joueur n'a pas de couleur, le sprite n'a **aucun matériau** (rendu d'origine garanti par construction) ; sinon le lion crée **son propre** `ShaderMaterial` (`Shaders/Lion.gdshader`, jamais partagé entre instances) et lui passe `couleur_joueur`. Le shader déduit le masque de la crinière du sprite lui-même, pixel par pixel (teinte, valeur, saturation), donc un seul shader vaut pour les deux sprites que l'`AnimationPlayer` échange. Il porte déjà `barbouillage_couleur` / `barbouillage_force` (à 0), que la phase 8 animera. Une étiquette `Pseudo` (nœud de `Lion.tscn`, cachée par défaut) n'est visible que si le joueur a une couleur **et** un pseudo.

**Tech Stack:** Godot 4.7.2, GDScript, shader `canvas_item` (rendus Mobile et Compatibilité), smoke test headless, planche de contrôle rendue en `opengl3`.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§5 « Lion » : teinte, repli, barbouillage, pseudo) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (phase 7 ; points de vigilance mis à jour dans le commit de ce plan, Task 0)

## Écarts assumés

1. **Pas de masques générés** (spec §5 et feuille de route : `tools/generer_masques_lion.py` + PNG de masques). Le masque est calculé dans le shader à partir de la teinte, de la valeur et de la saturation du sprite, sans zone géométrique d'exclusion du visage. Raisons :
   - **plafond de 5 fichiers** : outil + PNG + shader + `Lion.tscn` + `Lion.gd` font déjà 5, sans place ni pour les tests ni pour le « pas de teinte » du solo dans `Joueur.gd` ;
   - **les mesures sur les sprites montrent que la couleur suffit** (quantiles 10 / 50 / 90 %, pixels de valeur ≥ 0,25) :

     | Zone | Teinte (°, 0 = rouge) | Valeur |
     |---|---|---|
     | crinière (côtés, repos et vomi) | −46 / −26 / +4 | 0,27 / 0,38 / 0,72 |
     | crinière (haut, repos) | −31 / −1 / +12 | 0,31 / 0,61 / 0,82 |
     | visage (front, repos) | +3 / +30 / +43 | 0,47 / 0,92 / 0,99 |
     | langue (vomi) | −29 / +2 / +20 | 0,42 / 0,93 / 1,00 |
     | contour, intérieur de la gueule | bleu nuit | < 0,2 |

     Le visage se sépare par sa teinte (orange-jaune), la langue par sa clarté, le contour par sa noirceur ;
   - **déjà vérifié au moment du plan** : le shader de la Task 1 a été compilé et rendu (copie jetable du dépôt, `--rendering-driver opengl3`) sur la planche de la Task 3. Les 6 crinières sont nettement teintées, le visage et les yeux intacts. Défauts résiduels acceptés : liseré teinté de 1 à 2 px sur le bord ombré de la langue (surtout en bleu et jaune), quelques mouchetures orange dans la crinière bleue, jaune tirant sur l'or kaki et proche du visage.
2. **Formule de teinte** : `couleur × min(1, luminance × 2,2)` au lieu de `luminance × couleur` (spec §5). La crinière est sombre (valeur médiane 0,38) : sans gain, elle vire au presque noir (rendu comparé au moment du plan).
3. **« En multi uniquement » pour le pseudo** devient « joueur avec une couleur et un pseudo » : il n'existe pas encore d'indicateur de mode (voir la vigilance `configurer_bataille`, Task 0), et un joueur de bataille a toujours une couleur.
4. **Palette** : les 6 valeurs (rouge, bleu, jaune, vert, magenta, cyan) ne vivent que dans la planche de contrôle et le smoke test. La constante de palette et l'attribution des couleurs appartiennent à la phase 11 (`Reseau`). La simulation deutéranopie de la planche montre déjà que **rouge, vert et jaune se confondent** (kaki) et que **magenta et cyan se rapprochent** : c'est noté pour la phase 11 (Task 0).

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations.
- Solo strictement identique : aucune vérification existante ne change. Le lion du solo n'a pas de matériau.
- Fichiers de la phase (5) : ➕ `Shaders/Lion.gdshader`, ✏️ `Scripts/Joueur.gd`, ✏️ `Scripts/Lion.gd`, ✏️ `Scenes/Lion.tscn`, ✏️ `tests/smoke_test.gd`. Le `Shaders/Lion.gdshader.uid` généré est commité avec le shader, hors plafond. La planche de contrôle (`rendu_lions.gd`, `planche_lions.py`) vit dans le scratchpad de l'implémenteur et **n'est pas commitée**.
- **Toujours lancer un test Godot avec un délai maximal** (une erreur de script bloque le processus headless). En mode headless, le rendu factice **compile quand même les shaders** et affiche `SHADER ERROR` en cas d'erreur (vérifié en 4.7.2) : le grep le cherche aussi.
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; ( godot --headless --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd` pour les tests unitaires ; un test qui passe n'affiche que ses deux lignes `== … ==`).
- Après la création du shader : `godot --headless --import .` avant les tests (génère le `.uid`, met à jour le cache d'import).
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : le smoke test continue de typer les lions en `Node` / `CharacterBody2D` et **jamais** en `Lion` (`Lion.gd` nomme `GameState` et `Audio`). `Joueur` et `Commandes` ne nomment aucun autoload, on peut les typer.
- Toute modification du smoke test se valide sur **5 passages consécutifs verts**.
- Commits en français, terminés par la ligne `Co-Authored-By:` qu'impose l'environnement de l'auteur du commit.

## Review Focus

1. **Solo identique** : le joueur du solo n'a pas de couleur, son lion n'a **aucun matériau** et pas de pseudo, même avec un pseudo renseigné. → vérifications « en solo, le joueur n'a pas de couleur de lion… » et « un joueur sans couleur garde le rendu d'origine… » (Tasks 1 et 2).
2. **Matériaux indépendants** : chaque lion teinté crée son propre `ShaderMaterial`. Changer la couleur d'un joueur puis réappliquer ne touche que son lion ; un joueur redevenu sans couleur rend le rendu d'origine. Le piège des sous-ressources partagées de la phase 2 est évité par construction. → vérifications « deux lions ont chacun leur matériau… », « réappliquer l'apparence… », « un joueur redevenu sans couleur… » (Task 1).
3. **Shader compilé, deux sprites** : le shader compile (liste des uniformes non vide, aucun `SHADER ERROR`) et expose `couleur_joueur`, `barbouillage_couleur`, `barbouillage_force`. Pendant le vomi, le sprite de vomi garde le même matériau. → vérifications « le shader du lion compile… » et « en vomissant, le sprite de vomi garde le matériau… » (Task 1).
4. **Pseudo** : visible seulement avec une couleur et un pseudo, dans la couleur du joueur, au-dessus de la tête et centré, jamais traduit (`auto_translate_mode` désactivé), sans capter la souris. → vérifications « le pseudo du joueur s'affiche dans sa couleur », « le pseudo est au-dessus de la tête du lion, centré », « un joueur sans pseudo… » (Task 2) + relecture de `Lion.tscn`.
5. **Qualité du masque** (ne se vérifie pas en headless) : crinière nettement à la couleur du joueur, visage et yeux intacts, langue rose, clignotement toujours translucide, pseudos lisibles sur les trois bandes du ciel. → planche de contrôle rendue et **regardée** (Task 3), critères explicites ; repli par rotation de teinte si le rendu reste inacceptable.

---

### Task 0 : documentation (commit de ce plan)

**Files:**
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
- Create: `docs/superpowers/plans/2026-09-25-phase-07-teinte.md` (ce plan)

Les documents ne comptent pas dans le plafond de 5 fichiers.

- [ ] **Step 1 : spec, §5 « Lion »**

Remplacer :

```markdown
- **Teinte** : seule la crinière prend la couleur du joueur. `tools/generer_masques_lion.py`
  produit un masque par sprite (`LionHead_masque.png`, `LionHeadVomit_masque.png`) à partir de la
  teinte et de la luminance, en excluant le visage. Le shader `Lion.gdshader` mélange
  `original` et `luminance × couleur_joueur` selon le masque. Paramètres `barbouillage_couleur` et
  `barbouillage_force` pour l'étourdissement. **Repli** si le masque est laid : rotation de teinte
  de toute la tête.
```

par :

```markdown
- **Teinte** : seule la crinière prend la couleur du joueur. Le shader `Lion.gdshader` déduit le
  masque du sprite lui-même, pixel par pixel : la crinière est dans les teintes du violet au rouge,
  le visage dans l'orange et le jaune (exclu par sa teinte), la langue et les reflets sont trop
  clairs, le contour trop sombre. Un seul shader vaut donc pour les deux sprites (repos et vomi),
  sans masque généré. Il mélange `original` et `couleur_joueur × min(1, luminance × gain)` selon
  le masque (la crinière est sombre : sans gain, elle noircit). Paramètres `barbouillage_couleur`
  et `barbouillage_force` pour l'étourdissement. Un joueur sans couleur (alpha 0, le solo) laisse
  le sprite sans matériau. **Repli** si le masque est laid : rotation de teinte de toute la tête.
```

Dans le tableau §3.1, ligne `Joueur`, remplacer `En solo il porte aussi `couleurs_debloquees`, `vies`.` par `En solo il porte aussi `couleurs_debloquees`, `vies`, et sa `couleur` reste transparente (pas de teinte).`

En §12, remplacer `2. Teinte du lion (masques, shader), gerbe mono-couleur, étourdissement, collisions.` par `2. Teinte du lion (masque calculé par le shader), gerbe mono-couleur, étourdissement, collisions.`

- [ ] **Step 2 : feuille de route, ligne de la phase 7**

Remplacer la ligne qui commence par `| 7 | **Teinte de la crinière**` par :

```markdown
| 7 | **Teinte de la crinière** : masque déduit du sprite par le shader (teinte, valeur, saturation), uniformes de barbouillage prêts, pseudo au-dessus du lion ; le lion d'un joueur sans couleur (solo) n'a aucun matériau. Repli par rotation de teinte si le masque est laid. | ➕ `Shaders/Lion.gdshader` ✏️ `Scripts/Joueur.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scenes/Lion.tscn` ✏️ `tests/smoke_test.gd` | ◉ 6 lions teintés |
```

- [ ] **Step 3 : feuille de route, vérification commune**

Juste après la ligne `Les deux derniers doivent finir sur `== 0 échec(s) ==` et un code de sortie 0.`, ajouter :

```markdown
Leur sortie ne doit contenir ni `SCRIPT ERROR` ni `SHADER ERROR` : en headless, le rendu factice
compile quand même les shaders et signale leurs erreurs sans changer le code de sortie.
```

- [ ] **Step 4 : feuille de route, points de vigilance résolus ou recadrés**

4a. Supprimer l'item résolu en 6 bis (les lignes citées n'existent plus) :

```markdown
- références de phase périmées à corriger au passage : `Scripts/GameState.gd` lignes 5, 35 et 50
  (« phase 6 » → 6 bis).
```

4b. Supprimer l'item fait en 6 bis (le passage manuel de `tests/screenshots.gd` a été signalé à l'utilisateur, et il est repris dans le nouvel item Spawner/captures ci-dessous) :

```markdown
- **phase 6 bis** : garder `GameState.prochain_index_couleur()` (lu par `Spawner.gd`), réécrit sur
  `joueur_local()` au lieu de la façade, et réécrire (pas supprimer) le commentaire sur l'invariant
  « `joueurs` n'est jamais réassigné » en citant l'abonnement d'`Audio` ; lancer
  `tests/screenshots.gd` à la main (la CI ne le lance pas) ;
```

4c. Remplacer `- phase 7/8 ou 14 : le gestionnaire de contact est copié` par `- phase 8 ou 14 : le gestionnaire de contact est copié` (la phase 7 ne touche pas aux pastilles).

4d. Remplacer :

```markdown
- phase 7 ou 8 : ajouter `class_name Lion` et tester `body is Lion` dans les gestionnaires de
  contact au lieu de supposer `body.joueur` ;
```

par :

```markdown
- phase 8 : ajouter `class_name Lion` et tester `body is Lion` dans les gestionnaires de
  contact au lieu de supposer `body.joueur`. Les tests `--script` (compilés avant les autoloads)
  continuent de typer les lions en `Node` / `CharacterBody2D`, jamais `Lion` : `Lion.gd` nomme
  `GameState` et `Audio` ;
```

4e. Dans l'item `- Prochaine phase qui touche `.github/workflows/ci.yml``, remplacer `faire échouer le job si la
  sortie contient `SCRIPT ERROR`` par `faire échouer le job si la
  sortie contient `SCRIPT ERROR` ou `SHADER ERROR``.

- [ ] **Step 5 : feuille de route, nouveaux points de vigilance**

Ajouter à la fin de la liste :

```markdown
- **phase 8 ou 10 (obligatoire avant la première partie de bataille)** : la mise en place et le
  démontage d'un mode sur `GameState` doivent précéder `Main._enter_tree` (Main y appelle
  `GameState.nouvelle_partie()`, puis Lion, Spawner, HUD et Main s'abonnent à `joueur_local()` dans
  leur `_ready`). Ajouter `GameState.configurer_solo()` / `configurer_bataille(n)`, appelés **avant**
  le changement de scène (règles, nombre de joueurs remplis en place, couleurs et pseudos), avec un
  test unitaire : bataille puis solo rend `ReglesSolo` et un seul joueur, sans couleur (le lion du
  solo retrouve son rendu d'origine) ;
- **phase 14** : les réactions du `Joueur` sont des appels de méthode qui émettent des signaux
  (`debloquer_couleur`, `activer_bonus`, `encaisser_coup`). Un `MultiplayerSynchronizer` qui écrit
  les champs bruts n'émettrait rien chez les clients (HUD, Audio, Lion muets) : choisir des RPC
  d'événement qui appellent les mêmes méthodes du `Joueur`, ou des setters qui émettent. De même,
  `GameState._process` ferait avancer les copies des clients (`Joueur.avancer`) : l'hôte seul décompte ;
- **préexistant, à corriger dès qu'une phase touche `Scripts/Spawner.gd` ou `tests/screenshots.gd`** :
  `Spawner._on_partie_terminee` appelle `stop()` sur `_timer_soucoupe` / `_timer_coccinelle`, qui
  sont `null` si la partie se termine pendant l'intro (`SCRIPT ERROR` dans `tests/screenshots.gd`) ;
  et le coup de `tests/screenshots.gd` (vers la ligne 96) tombe pendant l'intro et n'a aucun effet.
  Relancer `tests/screenshots.gd` à la main après correction (la CI ne le lance pas) ;
- **phase 8** : le barbouillage passe par les uniformes `barbouillage_couleur` /
  `barbouillage_force` du matériau du lion (`Shaders/Lion.gdshader`, déjà prêts à 0). Ce matériau
  n'existe que si le joueur a une couleur, ce qui est toujours vrai en bataille ;
- **phase 10** : le pseudo est une étiquette au-dessus du sprite (38 px au-dessus du lion) : un
  lion collé en haut de l'écran la cache. En bataille, borner `y` à la hauteur de l'étiquette ou la
  passer sous le lion près du bord ;
- **phase 11** : la palette de bataille (planche de la phase 7 : rouge `(0.90, 0.16, 0.16)`, bleu
  `(0.16, 0.39, 0.95)`, jaune `(0.98, 0.82, 0.10)`, vert `(0.18, 0.78, 0.25)`, magenta
  `(0.90, 0.20, 0.85)`, cyan `(0.10, 0.85, 0.90)`) devient une constante unique. En simulation
  deutéranopie, rouge, vert et jaune se confondent (kaki) et magenta et cyan se rapprochent, et le
  jaune est proche du visage du lion : différencier les luminosités (vert plus sombre, jaune plus
  clair, par exemple) et compter aussi sur le pseudo et les vignettes du HUD. Attribuer la couleur
  **avant** l'ajout du lion à l'arbre, ou rappeler `Lion.appliquer_apparence()` (aperçu du salon en
  phase 13) ;
```

- [ ] **Step 6 : Commit**

```bash
git add docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md docs/superpowers/plans/2026-09-25-phase-07-teinte.md
git commit -m "Plan de la phase 7 (teinte de la crinière, pseudo) ; spec : masque calculé par le shader ; feuille de route : vigilance mise à jour

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 1 : crinière à la couleur du joueur, solo sans matériau

**Files:**
- Modify: `Scripts/Joueur.gd:3,13` (+ nouvelle méthode après `bonus_actif`)
- Create: `Shaders/Lion.gdshader`
- Modify: `Scripts/Lion.gd`
- Modify: `tests/smoke_test.gd:135` et la fin de `_run` (avant `print("== %d échec(s) ==" …)`)

**Interfaces:**
- Consumes : `Joueur` (`couleur`, `pseudo`, `debloquer_couleur`), `Commandes.manuelles()`, `Lion.sprite`, `Lion.anim` (piste `Vomit` qui remplace la texture du sprite).
- Produces :
  - `Joueur.couleur` vaut par défaut `Color.TRANSPARENT` ; `Joueur.a_une_couleur() -> bool` (`couleur.a > 0`).
  - `Shaders/Lion.gdshader` : uniformes `couleur_joueur: vec4`, `barbouillage_couleur: vec4`, `barbouillage_force: float` (0 par défaut).
  - `Lion.SHADER_TEINTE`, `Lion.appliquer_apparence() -> void` (publique, à rappeler si la couleur ou le pseudo du joueur change après l'ajout à l'arbre) et `Lion._appliquer_teinte()`.

- [ ] **Step 1 : `Scripts/Joueur.gd`, le « pas de couleur » du solo**

1a. Remplacer la ligne de docstring 3 :

```gdscript
## État d'un lion pendant une partie : couleurs débloquées, vies, invulnérabilité, bonus.
```

par :

```gdscript
## État d'un lion : identité (index, pseudo, couleur) et, pendant une partie, couleurs
## débloquées, vies, invulnérabilité, bonus.
```

1b. Remplacer :

```gdscript
@export var couleur := Color.WHITE
```

par :

```gdscript
## Couleur du lion en bataille. Transparente (alpha 0) = pas de couleur de lion : c'est le cas
## du solo, dont le lion garde sa crinière d'origine et n'affiche pas de pseudo.
@export var couleur := Color.TRANSPARENT
```

(`reinitialiser` ne touche ni `couleur` ni `pseudo`, qui sont l'identité du joueur d'une partie à l'autre, et c'est voulu. Aucun script ne lit `Joueur.couleur` aujourd'hui : `grep -rn "joueur.couleur\b\|\.couleur\b" Scripts tests | grep -v couleurs` ne trouve que `Ville.gd:153`, où `c` est une coulure.)

1c. Juste après la fonction `bonus_actif()` (avant la docstring `## Active (ou prolonge) la gerbe XXL…`), ajouter, en gardant deux lignes vides entre les fonctions :

```gdscript
## Vrai si le joueur a une couleur de lion (bataille), faux en solo.
func a_une_couleur() -> bool:
	return couleur.a > 0.0
```

- [ ] **Step 2 : `tests/smoke_test.gd`, les vérifications de teinte**

2a. Juste après :

```gdscript
	_check(lion.joueur == GS.joueur_local() and lion.commandes.source == Commandes.Source.LOCALES,
		"hors démo, le lion porte le joueur local et lit les commandes de ce poste")
```

ajouter :

```gdscript
	_check(not JL.a_une_couleur() and lion.sprite.material == null,
		"en solo, le joueur n'a pas de couleur de lion : le sprite reste sans matériau (rendu d'origine)")
```

2b. Juste après les deux lignes :

```gdscript
	autre.debloquer_couleur(Color.BLUE)
	autre = null
```

(fin de la section multi-lions, avant `print("== %d échec(s) ==" % _echecs)`), ajouter une ligne vide puis :

```gdscript
	# Bataille : crinière à la couleur du joueur, pseudo au-dessus du lion
	var shader_lion: Shader = load("res://Shaders/Lion.gdshader")
	var uniformes: Array = [] if shader_lion == null else shader_lion.get_shader_uniform_list().map(
		func(u: Dictionary) -> String: return u.name)
	_check(uniformes.has("couleur_joueur") and uniformes.has("barbouillage_couleur") and uniformes.has("barbouillage_force"),
		"le shader du lion compile et expose couleur_joueur, barbouillage_couleur et barbouillage_force (%s)" % [uniformes])
	var rouge := Joueur.new()
	rouge.couleur = Color(0.90, 0.16, 0.16)
	rouge.pseudo = "Alice"
	var bleu := Joueur.new()
	bleu.couleur = Color(0.16, 0.39, 0.95)
	var sans_couleur := Joueur.new()
	sans_couleur.pseudo = "Solo"
	var lions_teintes: Array[Node] = []
	for j: Joueur in [rouge, bleu, sans_couleur]:
		var l: Node = load("res://Scenes/Lion.tscn").instantiate()
		l.joueur = j
		l.commandes = Commandes.manuelles()
		l.position = Vector2(200 + 300 * lions_teintes.size(), 0)
		root.add_child(l)
		lions_teintes.append(l)
	await _frames(1)
	var mat_rouge := lions_teintes[0].sprite.material as ShaderMaterial
	var mat_bleu := lions_teintes[1].sprite.material as ShaderMaterial
	_check(mat_rouge != null and mat_rouge.shader == shader_lion and mat_rouge.get_shader_parameter("couleur_joueur") == rouge.couleur,
		"le lion d'un joueur coloré porte le shader de teinte, à la couleur de son joueur")
	_check(mat_bleu != null and mat_bleu != mat_rouge and mat_bleu.get_shader_parameter("couleur_joueur") == bleu.couleur,
		"deux lions ont chacun leur matériau, chacun à la couleur de son joueur")
	_check(lions_teintes[2].sprite.material == null, "un joueur sans couleur garde le rendu d'origine")
	bleu.couleur = Color(0.10, 0.85, 0.90)
	lions_teintes[1].appliquer_apparence()
	_check(mat_bleu.get_shader_parameter("couleur_joueur") == bleu.couleur and mat_rouge.get_shader_parameter("couleur_joueur") == rouge.couleur,
		"réappliquer l'apparence après un changement de couleur ne retouche que le lion de ce joueur")
	bleu.couleur = Color.TRANSPARENT
	lions_teintes[1].appliquer_apparence()
	_check(lions_teintes[1].sprite.material == null, "un joueur redevenu sans couleur rend au lion son rendu d'origine")
	rouge.debloquer_couleur(Color.RED)
	GS.pret = true
	lions_teintes[0].commandes.vomir_voulu = true
	for i in range(3):
		await process_frame  # le vomi démarre dans _process et l'AnimationPlayer change de sprite au même rythme
	_check(lions_teintes[0].est_en_train_de_vomir and lions_teintes[0].sprite.texture.resource_path.ends_with("LionHeadVomit.png")
		and lions_teintes[0].sprite.material == mat_rouge,
		"en vomissant, le sprite de vomi garde le matériau de teinte du joueur")
	lions_teintes[0].commandes.vomir_voulu = false
	await _frames(2)
	for l in lions_teintes:
		l.free()
```

Notes :
- `get_shader_parameter` ne renvoie que les valeurs **écrites** par `set_shader_parameter`, pas les valeurs par défaut du shader (il renvoie `null` pour `barbouillage_force`) : ne pas tester ces défauts.
- `mat_rouge.shader == shader_lion` : `preload` dans `Lion.gd` et `load` ici renvoient la même ressource en cache.
- La vérification du vomi attend des `process_frame` et non des `physics_frame` : avec 3 frames physiques, elle a échoué une fois sur plusieurs passages pendant la mise au point du plan (plusieurs ticks physiques peuvent tomber dans une seule frame de rendu).

- [ ] **Step 3 : Lancer le smoke test (échec attendu)**

Run : le smoke test avec délai (60 s suffisent ici).
Expected : `❌ le shader du lion compile… ([])`, `❌ le lion d'un joueur coloré porte le shader de teinte…`, `❌ deux lions ont chacun leur matériau…`, puis `SCRIPT ERROR: Invalid call. Nonexistent function 'appliquer_apparence'`. Le test s'arrête là, et le délai le coupe. La vérification solo de l'étape 2a passe déjà : c'est une non-régression.

- [ ] **Step 4 : `Shaders/Lion.gdshader`**

```glsl
shader_type canvas_item;
// Teinte de la crinière du lion à la couleur de son joueur (spec §5).
// Le masque se déduit du sprite lui-même, pixel par pixel : la crinière est dans les teintes
// du violet au rouge, le visage dans l'orange et le jaune ; le contour (trop sombre) et la
// langue ou les reflets (trop clairs) gardent leurs couleurs. Seuils réglés sur captures.

uniform vec4 couleur_joueur : source_color = vec4(1.0);
// Barbouillage de l'étourdissement (phase 8) : toute la tête vire à la couleur de l'agresseur.
uniform vec4 barbouillage_couleur : source_color = vec4(1.0);
uniform float barbouillage_force : hint_range(0.0, 1.0) = 0.0;

// Teinte en degrés, de -180 à 180 (0 = rouge, négatif = vers le violet).
const vec2 TEINTE_BORD_VIOLET = vec2(-110.0, -80.0);  // fondu d'entrée
const vec2 TEINTE_BORD_VISAGE = vec2(8.0, 18.0);      // fondu de sortie
const vec2 VALEUR_BORD_SOMBRE = vec2(0.10, 0.22);     // en dessous : contour
const vec2 VALEUR_BORD_CLAIR = vec2(0.78, 0.92);      // au-dessus : langue, reflets
const vec2 SATURATION_MIN = vec2(0.20, 0.35);         // en dessous : gris, blancs
// La crinière est sombre (valeur médiane ≈ 0,38) : sans gain, luminance × couleur la noircit.
const float GAIN_LUMINANCE = 2.2;

vec3 rgb_vers_tsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// 1 sur la crinière, 0 ailleurs, avec des fondus pour éviter les pixels isolés.
float masque_criniere(vec3 c) {
	vec3 tsv = rgb_vers_tsv(c);
	float teinte = tsv.x * 360.0;
	if (teinte > 180.0) {
		teinte -= 360.0;
	}
	float m = smoothstep(TEINTE_BORD_VIOLET.x, TEINTE_BORD_VIOLET.y, teinte)
		* (1.0 - smoothstep(TEINTE_BORD_VISAGE.x, TEINTE_BORD_VISAGE.y, teinte));
	m *= smoothstep(VALEUR_BORD_SOMBRE.x, VALEUR_BORD_SOMBRE.y, tsv.z)
		* (1.0 - smoothstep(VALEUR_BORD_CLAIR.x, VALEUR_BORD_CLAIR.y, tsv.z));
	m *= smoothstep(SATURATION_MIN.x, SATURATION_MIN.y, tsv.y);
	return m;
}

void fragment() {
	vec4 base = COLOR;  // texture × modulate (le clignotement joue sur l'alpha)
	float lum = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	float eclat = clamp(lum * GAIN_LUMINANCE, 0.0, 1.0);
	vec3 rgb = mix(base.rgb, couleur_joueur.rgb * eclat, masque_criniere(base.rgb));
	rgb = mix(rgb, barbouillage_couleur.rgb * eclat, barbouillage_force);
	COLOR = vec4(rgb, base.a);
}
```

(En Godot 4, `COLOR` à l'entrée de `fragment()` vaut déjà texture × modulate : le clignotement de `_on_lion_touche`, qui anime `sprite.modulate:a`, reste visible. Le masque est calculé sur la couleur modulée, dont le RVB est celui de la texture puisque le lion ne module que l'alpha.)

- [ ] **Step 5 : `Scripts/Lion.gd`, la teinte**

5a. Remplacer la ligne de docstring 2 :

```gdscript
## Le lion : déplacement, gerbe de vomi multicolore, traceuse de peinture.
```

par :

```gdscript
## Le lion : déplacement, gerbe de vomi multicolore, traceuse de peinture ; en bataille,
## crinière à la couleur de son joueur et pseudo au-dessus de la tête.
```

5b. Juste après `const BOUCHE_X_GAUCHE := 47.0`, ajouter :

```gdscript
const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
```

5c. Dans `_ready()`, remplacer :

```gdscript
	_appliquer_direction()
	mettre_a_jour_degrade_vomi()
```

par :

```gdscript
	_appliquer_direction()
	mettre_a_jour_degrade_vomi()
	appliquer_apparence()
```

5d. Juste avant `## Penche le lion dans le sens de la course et le fait trottiner.`, ajouter :

```gdscript
## Crinière à la couleur du joueur et pseudo au-dessus de la tête. Lu une fois dans `_ready` ;
## à rappeler si la couleur ou le pseudo du joueur change ensuite (aperçu du salon, phase 13).
func appliquer_apparence() -> void:
	_appliquer_teinte()


## Un joueur sans couleur (le solo) laisse le sprite sans matériau : le lion s'affiche
## exactement comme ses sprites d'origine. Sinon, le lion crée son propre matériau (jamais
## partagé entre instances de Lion.tscn) ; il vaut pour les deux sprites, repos et vomi.
func _appliquer_teinte() -> void:
	if not joueur.a_une_couleur():
		sprite.material = null
		return
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = SHADER_TEINTE
		sprite.material = mat
	mat.set_shader_parameter("couleur_joueur", joueur.couleur)


```

(Le matériau est posé sur le `Sprite2D`, pas sur les textures : l'`AnimationPlayer` peut échanger `LionHead.png` et `LionHeadVomit.png` sans y toucher. Les particules et la traceuse ne sont pas concernées.)

- [ ] **Step 6 : Vérifier**

```sh
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|SHADER ERROR|Parse Error|Compile Error"
```

Expected : aucune ligne ; `Shaders/Lion.gdshader.uid` existe. Puis `tests/unitaires.gd` avec délai (vert) et **5 passages** consécutifs du smoke test : verts, sans `SHADER ERROR`, avec les 7 nouvelles vérifications (`✅`) visibles dans `$TMPDIR/t.log`.

- [ ] **Step 7 : Commit**

```bash
git add Scripts/Joueur.gd Shaders/Lion.gdshader Shaders/Lion.gdshader.uid Scripts/Lion.gd tests/smoke_test.gd
git commit -m "Lion : crinière à la couleur de son joueur (shader à masque calculé) ; le joueur du solo n'a pas de couleur, son lion reste sans matériau

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 2 : pseudo au-dessus du lion

**Files:**
- Modify: `Scenes/Lion.tscn` (nouveau nœud `Pseudo`, à la fin)
- Modify: `Scripts/Lion.gd` (`@onready`, `appliquer_apparence`)
- Modify: `tests/smoke_test.gd`

**Interfaces:**
- Consumes : Task 1 (`appliquer_apparence`, `Joueur.a_une_couleur()`, section « Bataille » du smoke test).
- Produces : `Lion.etiquette_pseudo: Label` (`$Pseudo`), visible si et seulement si `joueur.a_une_couleur() and not joueur.pseudo.is_empty()`, texte = `joueur.pseudo`, `font_color` = `joueur.couleur`.

- [ ] **Step 1 : `tests/smoke_test.gd`, les vérifications du pseudo**

1a. Remplacer (vérification solo de la Task 1) :

```gdscript
	_check(not JL.a_une_couleur() and lion.sprite.material == null,
		"en solo, le joueur n'a pas de couleur de lion : le sprite reste sans matériau (rendu d'origine)")
```

par :

```gdscript
	_check(not JL.a_une_couleur() and lion.sprite.material == null and not lion.etiquette_pseudo.visible,
		"en solo, le joueur n'a pas de couleur de lion : sprite sans matériau (rendu d'origine), pas de pseudo")
```

1b. Remplacer :

```gdscript
	_check(lions_teintes[2].sprite.material == null, "un joueur sans couleur garde le rendu d'origine")
```

par :

```gdscript
	_check(lions_teintes[2].sprite.material == null and not lions_teintes[2].etiquette_pseudo.visible,
		"un joueur sans couleur garde le rendu d'origine et n'affiche pas son pseudo, même s'il en a un")
```

1c. Juste avant `	rouge.debloquer_couleur(Color.RED)`, ajouter :

```gdscript
	var etiquette: Label = lions_teintes[0].etiquette_pseudo
	var haut_sprite: float = lions_teintes[0].sprite.position.y - lions_teintes[0].sprite.texture.get_height() / 2.0
	_check(etiquette.visible and etiquette.text == "Alice" and etiquette.get_theme_color("font_color") == rouge.couleur,
		"le pseudo du joueur s'affiche dans sa couleur")
	_check(etiquette.get_rect().end.y <= haut_sprite and absf(etiquette.get_rect().get_center().x - lions_teintes[0].sprite.position.x) < 1.0,
		"le pseudo est au-dessus de la tête du lion, centré")
	_check(not lions_teintes[1].etiquette_pseudo.visible, "un joueur sans pseudo n'affiche pas d'étiquette")
```

(`bleu` n'a pas de pseudo et vient d'être remis sans couleur ; `lions_teintes[1]` couvre donc le cas « sans pseudo ». Les couleurs sont comparées après passage par le thème, sans conversion : égalité exacte.)

- [ ] **Step 2 : Lancer le smoke test (échec attendu)**

Run : le smoke test avec délai (60 s).
Expected : `SCRIPT ERROR: Invalid access to property or key 'etiquette_pseudo' on a base object of type 'CharacterBody2D (Lion.gd)'` dès la vérification solo. Le test s'arrête là, et le délai le coupe.

- [ ] **Step 3 : `Scenes/Lion.tscn`, l'étiquette**

À la fin du fichier, après le nœud `Bouche`, ajouter (une ligne vide avant) :

```
[node name="Pseudo" type="Label" parent="."]
visible = false
z_index = 3
offset_left = -42.0
offset_top = -38.0
offset_right = 178.0
grow_horizontal = 2
mouse_filter = 2
auto_translate_mode = 2
theme_override_colors/font_outline_color = Color(0.1, 0.05, 0.15, 1)
theme_override_constants/outline_size = 8
theme_override_font_sizes/font_size = 26
horizontal_alignment = 1
vertical_alignment = 2
```

Pourquoi ces valeurs :
- boîte de 220 px centrée sur x = 68 (centre du sprite), de y = −38 à 0 : le haut du sprite est à y = 3 ;
- `grow_horizontal = 2` : un pseudo long s'élargit des deux côtés et reste centré ;
- `mouse_filter = 2` : ignore la souris ;
- `auto_translate_mode = 2` : un pseudo n'est jamais traduit ;
- contour de la couleur de l'intro, `z_index` au-dessus des particules (2).

Le nœud est enfant du `CharacterBody2D`, pas du sprite : il ne se retourne pas, ne penche pas et ne trottine pas avec lui. `load_steps` ne change pas (aucune nouvelle ressource).

- [ ] **Step 4 : `Scripts/Lion.gd`, le pseudo**

4a. Juste après `@onready var bouche: Marker2D = $Bouche`, ajouter :

```gdscript
@onready var etiquette_pseudo: Label = $Pseudo
```

4b. Remplacer :

```gdscript
func appliquer_apparence() -> void:
	_appliquer_teinte()
```

par :

```gdscript
func appliquer_apparence() -> void:
	_appliquer_teinte()
	etiquette_pseudo.text = joueur.pseudo
	etiquette_pseudo.add_theme_color_override("font_color", joueur.couleur)
	etiquette_pseudo.visible = joueur.a_une_couleur() and not joueur.pseudo.is_empty()
```

- [ ] **Step 5 : Vérifier**

`godot --headless --import .` (aucune erreur), `tests/unitaires.gd` avec délai (vert), puis **5 passages** consécutifs du smoke test : verts, sans `SCRIPT ERROR` ni `SHADER ERROR`.

- [ ] **Step 6 : Commit**

```bash
git add Scenes/Lion.tscn Scripts/Lion.gd tests/smoke_test.gd
git commit -m "Lion : pseudo du joueur au-dessus de la tête, dans sa couleur, seulement pour un joueur coloré (bataille)

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 3 : contrôle visuel (planche de 6 lions teintés + solo)

**Files:**
- Create (scratchpad, **non commité**) : `$SCRATCH/rendu_lions.gd`, `$SCRATCH/planche_lions.py` (`$SCRATCH` = le dossier scratchpad de l'implémenteur)
- Modify (seulement si le réglage l'exige) : `Shaders/Lion.gdshader` (constantes de seuils)

**Interfaces:**
- Consumes : Tasks 1 et 2 (`Lion.tscn`, `Joueur.couleur`, `Joueur.pseudo`, `Lion.anim`, `Lion.sprite`).
- Produces : planches PNG regardées ; éventuellement des seuils réajustés dans le shader, puis commités.

- [ ] **Step 1 : Script de rendu**

Écrire `$SCRATCH/rendu_lions.gd` :

```gdscript
extends SceneTree
## Planche de contrôle de la teinte (phase 7, non commitée) :
## godot --rendering-driver opengl3 --script <ce fichier> -- --dossier=<dossier>
## Colonnes : solo (sans couleur), les 6 couleurs de la palette, puis rouge en clignotement.
## Lignes : repos (haut du ciel), vomi (milieu), repos (bas du ciel, au-dessus des toits).

const PALETTE := [
	["Rouge", Color(0.90, 0.16, 0.16)],
	["Bleu", Color(0.16, 0.39, 0.95)],
	["Jaune", Color(0.98, 0.82, 0.10)],
	["Vert", Color(0.18, 0.78, 0.25)],
	["Magenta", Color(0.90, 0.20, 0.85)],
	["Cyan", Color(0.10, 0.85, 0.90)],
]
const LIGNES_Y := [50.0, 270.0, 490.0]
var dossier := "user://"


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dossier="):
			dossier = arg.trim_prefix("--dossier=")
	call_deferred("_run")


func _run() -> void:
	root.get_node("GameState").pret = false  # les lions restent immobiles
	# Même ciel que Scenes/Main.tscn, pour juger la lisibilité des pseudos
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
	var scene_lion: PackedScene = load("res://Scenes/Lion.tscn")
	for ligne in range(LIGNES_Y.size()):
		for colonne in range(8):
			var j := Joueur.new()
			if colonne >= 1:
				var entree: Array = PALETTE[colonne - 1] if colonne < 7 else PALETTE[0]
				j.couleur = entree[1]
				j.pseudo = entree[0] if colonne < 7 else "Clignote"
			var lion: Node = scene_lion.instantiate()
			lion.joueur = j
			lion.commandes = Commandes.manuelles()
			lion.position = Vector2(20 + colonne * 245, LIGNES_Y[ligne])
			root.add_child(lion)
			if ligne == 1:
				lion.anim.play("Vomit")
			if colonne == 7:
				lion.sprite.modulate.a = 0.25  # creux du clignotement d'invulnérabilité
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(dossier.path_join("lions.png"))
	print("📸 lions.png ", image.get_size())
	quit(0)
```

- [ ] **Step 2 : Script d'agrandissement et de simulation deutéranopie**

Écrire `$SCRATCH/planche_lions.py` :

```python
#!/usr/bin/env python3
"""Agrandit la planche lions.png (×2, pixels nets) et en fait une version deutéranopie."""
import sys
from pathlib import Path
from PIL import Image

dossier = Path(sys.argv[1])
image = Image.open(dossier / "lions.png").convert("RGB")
l, h = image.size
# Deux moitiés agrandies ×2 (colonnes 0-3 puis 4-7), lisibles avec l'outil Read
for i, (x0, x1) in enumerate([(0, 1000), (980, 2000)]):
    image.crop((x0, 0, x1, h)).resize(((x1 - x0) * 2, h * 2), Image.NEAREST).save(dossier / f"lions_x2_{i}.png")
# Deutéranopie (Machado 2009, sévérité 1), appliquée en RVB linéaire
M = ((0.367322, 0.860646, -0.227968), (0.280085, 0.672501, 0.047413), (-0.011820, 0.042940, 0.968881))
lin = [((v / 255) / 12.92 if v <= 10 else (((v / 255) + 0.055) / 1.055) ** 2.4) for v in range(256)]
def srgb(x):
    x = min(1.0, max(0.0, x))
    return round(255 * (12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055))
px = image.load()
deut = Image.new("RGB", image.size)
dp = deut.load()
for y in range(h):
    for x in range(l):
        r, g, b = (lin[c] for c in px[x, y])
        dp[x, y] = tuple(srgb(m[0] * r + m[1] * g + m[2] * b) for m in M)
deut.save(dossier / "lions_deuteranopie.png")
print("planches écrites dans", dossier)
```

- [ ] **Step 3 : Rendre (rendu réel, une fenêtre s'ouvre)**

```sh
export PATH="/opt/homebrew/bin:$PATH"; mkdir -p "$SCRATCH/rendu"
( godot --rendering-driver opengl3 --script "$SCRATCH/rendu_lions.gd" -- --dossier="$SCRATCH/rendu" > "$SCRATCH/rendu/rendu.log" 2>&1 & p=$!; for i in $(seq 1 60); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null )
grep -E "SCRIPT ERROR|SHADER ERROR|📸" "$SCRATCH/rendu/rendu.log"
python3 "$SCRATCH/planche_lions.py" "$SCRATCH/rendu"
```

Expected : `📸 lions.png (2000, 648)`, aucune erreur (un « resources still in use at exit » final est le bruit connu). Le rendu est Compatibilité (`opengl3`) ; le jeu tourne en Mobile, mais le shader n'utilise rien de propre à un rendu.

- [ ] **Step 4 : Regarder les planches (outil Read) et juger**

Lire `lions.png` (taille réelle, ce que voit le joueur), puis `lions_x2_0.png` et `lions_x2_1.png` (détail). **« Ça rend bien »** veut dire, pour chacune des 6 couleurs et sur les 3 lignes :

1. la crinière se lit sans hésitation comme la couleur du joueur à taille réelle, sombre dans les creux et claire sur les mèches ;
2. visage, oreilles, yeux, museau, nez, dents et contour gardent leurs couleurs d'origine : aucune tache teintée sur le visage ni dans les yeux ;
3. la langue (ligne vomi) reste rose. Un liseré teinté de 1 à 2 px sur son bord ombré est toléré, pas une bande qui la traverse ;
4. quelques pixels isolés restés à leur couleur d'origine dans la crinière (mouchetures orange) sont tolérés ;
5. la colonne 0 (solo) est identique au sprite d'origine (aucun matériau : c'est garanti, on vérifie seulement qu'elle ne diffère pas des autres lignes de la colonne 0) ;
6. la colonne 7 (clignotement) est translucide sur les 3 lignes ;
7. chaque pseudo est lisible sur sa bande de ciel (bleu nuit en haut, violet au milieu, orangé en bas).

Référence : c'est exactement ce qu'a donné la mise au point du plan avec les seuils de la Task 1, défauts tolérés compris (voir « Écarts assumés », point 1). Si le rendu diffère nettement (crinière non teintée, visage teinté), chercher d'abord une erreur de recopie du shader.

Leviers de réglage, dans l'ordre, un seul à la fois, avec un nouveau rendu et un nouveau regard à chaque essai :
- `TEINTE_BORD_VISAGE` (bord du visage et liseré de la langue ; baisser vers `(4, 14)` réduit le liseré mais éteint le haut rouge-orangé de la crinière) ;
- `VALEUR_BORD_CLAIR` (langue, reflets) ;
- `GAIN_LUMINANCE` (crinière trop sombre ou délavée ; 2,8 a été essayé au moment du plan, gain marginal) ;
- `SATURATION_MIN`.

Le jaune reste proche du visage quel que soit le réglage : c'est une question de palette (phase 11), pas de masque.

Lire aussi `lions_deuteranopie.png`. Attendu : rouge, vert et jaune se confondent, magenta et cyan se rapprochent (déjà noté pour la phase 11, Task 0). Si le constat diffère, corriger l'item « phase 11 » de la feuille de route dans le commit du Step 6.

- [ ] **Step 5 : Repli si le masque reste inacceptable (spec §5)**

Seulement si les critères 1 à 3 ne peuvent pas être tenus. Dans ce cas, remplacer tout le code sous les uniformes de `Shaders/Lion.gdshader` par une rotation de teinte de toute la tête (le visage tourne avec la crinière). Les uniformes ne changent pas, les tests non plus. Code compilé au moment du plan :

```glsl
// Repli (spec §5) : rotation de teinte de toute la tête, la crinière passant de sa teinte
// médiane d'origine à celle du joueur (le visage tourne avec elle).
const float TEINTE_CRINIERE = -25.0 / 360.0;  // teinte médiane de la crinière d'origine
const float GAIN_LUMINANCE = 2.2;

vec3 rgb_vers_tsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 tsv_vers_rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 base = COLOR;
	vec3 tsv = rgb_vers_tsv(base.rgb);
	tsv.x = fract(tsv.x + rgb_vers_tsv(couleur_joueur.rgb).x - TEINTE_CRINIERE);
	vec3 rgb = tsv_vers_rgb(tsv);
	float eclat = clamp(dot(base.rgb, vec3(0.299, 0.587, 0.114)) * GAIN_LUMINANCE, 0.0, 1.0);
	rgb = mix(rgb, barbouillage_couleur.rgb * eclat, barbouillage_force);
	COLOR = vec4(rgb, base.a);
}
```

Mettre alors à jour le commentaire d'en-tête du shader et la phrase « Teinte » du spec §5 (repli adopté), puis refaire les Steps 3 et 4 : avec le repli, les critères 2 et 3 ne s'appliquent plus.

- [ ] **Step 6 : Commit (seulement si le shader ou la doc ont changé)**

Si des seuils ont changé ou si le repli a été adopté : relancer les deux suites (smoke test 5 fois, sans `SHADER ERROR`), puis :

```bash
git add Shaders/Lion.gdshader docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
git commit -m "Lion : seuils du masque de crinière réglés sur la planche de contrôle

Co-Authored-By: <ligne imposée par l'environnement>"
```

(`git add` seulement des fichiers réellement modifiés.) Les scripts de la planche restent dans le scratchpad.

---

## Sortie de phase

- Les deux suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR`, localement (smoke test 5 fois) puis en CI sur la PR.
- Planche `lions.png` regardée et conforme aux critères de la Task 3. Joindre `lions.png` (et `lions_deuteranopie.png`) à la demande de validation de l'utilisateur, avec les défauts tolérés nommés : c'est la sortie ◉ « 6 lions teintés » de la feuille de route.
- `git diff main --stat` : 5 fichiers de code (`Shaders/Lion.gdshader`, `Scripts/Joueur.gd`, `Scripts/Lion.gd`, `Scenes/Lion.tscn`, `tests/smoke_test.gd`) plus le `.uid` du shader et la documentation.
- Rappeler à l'utilisateur que `tests/screenshots.gd` n'a pas été relancé (solo inchangé par construction : le lion du solo n'a pas de matériau), et que son `SCRIPT ERROR` préexistant (Spawner pendant l'intro) est inscrit dans la feuille de route.
