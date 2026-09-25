# Phase 9 bis : territoire dans la ville, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** la ville d'une bataille tient le territoire de la phase 9 : chaque tampon d'un lion y est reporté, sur l'hôte seulement, ses vols sont signalés aux règles (`cellules_volees`), et les scores de chaque joueur se lisent sur le territoire de la ville. La ville garde ses tampons en cache **par jeu de couleurs** (point obligatoire de la feuille de route : deux lions qui ont autant de couleurs peignaient avec les tampons du premier), et la vérification du smoke test « la traceuse d'un lion peint avec les couleurs de son joueur » est durcie pour le prouver. `DUREE_INVULNERABILITE` descend de `GameState` vers `ReglesSolo`. **Le solo reste strictement identique** : pas de territoire, même mesure de couverture (alpha moyen ≥ 0,4 par cellule), mêmes rayons, même invulnérabilité. Rien ne lance encore de bataille dans le jeu (scène de bataille : phase 10) : tout se vérifie dans une section propre du smoke test.

**Architecture:** `Ville.peindre(position, rayon, peintre: Joueur)` reçoit le joueur qui peint au lieu de ses couleurs (elles sont `peintre.couleurs_debloquees`) ; `GerbeTraceuse` lui passe `lion.joueur`. Les tampons vivent dans un `Dictionary[String, Array]` dont la clé est le rayon suivi du `to_rgba32()` de chaque couleur (`_cle_tampons`), généré au premier usage (`_tampons_pour`), vidé au changement de skyline ou au-delà de `TAMPONS_EN_CACHE_MAX` jeux. `charger_skyline` crée `territoire = Territoire.new(grille_taille, _cellules_peignables, TAILLE_CELLULE)` si `GameState.regles.compte_le_territoire()`, `null` sinon (solo). Après le blit, sur l'hôte (`multiplayer.is_server()`), `peindre` appelle `territoire.tamponner(peintre.index, Vector2i(px, py), rayon)` avec le centre du tampon en pixels de la ville (le repère de la grille) et, s'il y a des vols, `GameState.regles.vol_de_cellules(peintre, volees)`. Un client dessine le tampon sans toucher au territoire (phase 14 : il appliquera la liste des cellules reçue de l'hôte). La mesure de couverture ne change pas et tourne dans les deux modes.

**Tech Stack:** Godot 4.7.2, GDScript, smoke test headless.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1 `Ville`, §6 « Propriété », « Visuel », « Synchro du score », « Solo ») · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (phase 9 bis ; points de vigilance « phase 9 bis (obligatoire) », « phases 9 et 9 bis », « phase 9 bis » sur `DUREE_INVULNERABILITE`) · prérequis : phase 9 (`docs/superpowers/plans/2026-09-25-phase-09-territoire.md`) fusionnée, dont la Task 0 a commité ce plan.

## Écarts assumés

1. **`peindre` reçoit le peintre, pas ses couleurs** : la ville doit savoir qui peint (territoire, vols), et les couleurs se déduisent du joueur : une seule source, comme le tampon diffusé en phase 14, qui porte l'index du joueur (spec §6 « Synchro des tampons »). Les deux appels directs du smoke test (niveau Métropole) passent `JL`.
2. **La couverture reste mesurée en bataille** : `GameState.progression` nourrit encore l'intensité de la musique (`Audio`), la vitesse du peintre (`Boss.facteur_vitesse`) et la barre du HUD ; la phase 10 (scène de bataille) et la phase 17 (HUD de bataille) décideront de ce que la bataille en garde. Coût inchangé (une réduction du masque toutes les 0,2 s).
3. **Cache des tampons** : clé texte (rayon puis `%08x` de chaque couleur, dans l'ordre), `TAMPONS_EN_CACHE_MAX = 96` jeux (6 joueurs × 7 crans × 2 avec l'étoile XXL = 84 au pire, environ 12 Mo), vidé à chaque skyline comme l'ancien cache. En solo, les moments où des tampons sont générés changent un peu (un jeu déjà vu, par exemple le rayon normal après l'étoile, est repris au lieu d'être régénéré) : les tirages du hasard global aussi, sans effet visible ni testé (le hasard n'est pas amorcé).
4. **Couleurs comparées après un passage en RGBA8** (`_rgba8` dans le smoke test) : `Image.set_pixel` tronque chaque composante sur 8 bits, alors que `Color.to_rgba32()` arrondit ; les nuances d'un joueur de bataille ne sont pas exactement représentables (mesuré : nuance foncée du rouge `951b1b` par `to_rgba32`, `951a1a` relue sur la ville). Les couleurs de l'arc-en-ciel du solo le sont, d'où l'ancienne comparaison, qui marchait.
5. **`DUREE_INVULNERABILITE` descend ici** (point de vigilance « phase 9 bis ») : `Scripts/Lion.gd` ne la lit plus depuis la phase 8 bis, `ReglesSolo` est la seule à s'en servir ; `Scripts/GameState.gd` et `Scripts/ReglesSolo.gd` tiennent dans le plafond de cette phase. La vérification passe par la carte des constantes des scripts (`get_script_constant_map()`), pour que le smoke test compile avant la Task.
6. **Pas de `Joueur.cellules`** (phase 9, écart 3) : le smoke test lit les scores sur `ville.territoire.cellules_de(index)`.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations.
- Solo strictement identique : les vérifications existantes du smoke test restent vraies ; seules changent la vérification de la traceuse (durcie), celle de l'invulnérabilité (précisée) et la façon d'appeler `peindre` depuis le test.
- Fichiers de la phase (5) : ✏️ `Scripts/Ville.gd`, ✏️ `Scripts/GerbeTraceuse.gd`, ✏️ `Scripts/GameState.gd`, ✏️ `Scripts/ReglesSolo.gd`, ✏️ `tests/smoke_test.gd`. Aucun nouveau script, donc aucun `.uid`.
- Pas de nettoyage préalable (règle « Step 0 ») : `Scripts/Ville.gd` fait 184 lignes ; `tests/smoke_test.gd` dépasse 300 lignes, mais n'y gagne que deux fonctions d'aide (dont une extraite du code de la vérification qu'elle remplace) et une section à la fin.
- **Toujours lancer un test Godot avec un délai maximal** (une erreur de script bloque le processus headless), et chercher `SCRIPT ERROR` et `SHADER ERROR` dans la sortie (une erreur dans une fonction appelée ne change pas le code de sortie) :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; ( godot --headless --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd` pour les tests unitaires ; une suite qui passe n'affiche que ses deux lignes `== … ==`). Un « resources still in use at exit » final est le bruit connu.
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : le smoke test ne nomme ni `Lion`, ni `Ennemi`, ni le script de la ville ; il peut nommer `Territoire` (logique pure, phase 9) et `Regles` (qui ne nomme aucun autoload).
- Section « Territoire » du smoke test **propre** : elle libère d'abord tout ennemi encore en jeu, crée sa ville et ses deux lions, les libère et remet le solo (`configurer_solo()`) à la fin. Les tests partagent l'autoload `GameState` : `configurer_bataille(2)` au début, `configurer_solo()` à la fin, toujours.
- Performance : `tamponner` coûte environ 25 µs pour un tampon de 46 px (phase 9, test de coût) ; la clé du cache est une courte chaîne par tampon ; la mesure de couverture (toutes les 0,2 s) ne change pas.
- Toute modification du smoke test se valide sur **5 passages consécutifs verts**.
- Commits en français, terminés par la ligne `Co-Authored-By:` qu'impose l'environnement de l'auteur du commit.

## Review Focus

1. **Tampons par jeu de couleurs** : le lion local peint d'abord la ville avec autant de couleurs et le même rayon que l'autre lion ; l'autre ne peint ensuite qu'avec les siennes (échec avant la Task 1 : il reprenait les tampons du lion local) ; en bataille, deux lions à trois nuances et au même rayon peignent chacun dans les leurs. → « la traceuse d'un lion peint avec les couleurs de son joueur, même après un lion qui en a autant » (Task 1), « à rayon et nombre de couleurs égaux, le second lion peint dans ses propres nuances » (Task 2).
2. **Solo identique** : pas de territoire en solo ; mesure de couverture inchangée (un tampon isolé ne compte presque pas, la ville entièrement peinte gagne) ; invulnérabilité de 1,5 s, désormais une règle du solo. → « en solo, la ville ne tient pas de territoire… », « un tampon isolé ne compte presque pas », « progression >= seuil après avoir tout peint », « le lion est invulnérable après un coup, pour la durée que fixent les règles du solo… » (Tasks 2 et 3).
3. **Territoire branché** : la traceuse d'un vrai lion de bataille (pas un appel direct) fait compter ses cellules pour son joueur ; les cellules qui se mettent à compter sont listées une fois ; un autre lion qui repeint par-dessus les vole, et les règles comptent exactement les cellules perdues par le premier. → « les cellules que peint un lion comptent pour son joueur », « les cellules qui se mettent à compter sont listées… », « repeindre les cellules d'un autre les lui vole… » (Task 2).
4. **L'hôte seul décide** : sous un pair client, la ville dessine les tampons sans toucher au territoire ; revenue sur l'hôte, les mêmes tampons comptent. → « sur un client, la ville dessine les tampons sans toucher au territoire », « de retour sur l'hôte, les mêmes tampons comptent » (Task 2).
5. **Une seule source par donnée** : couleurs lues sur le peintre, scores sur le territoire, durée d'invulnérabilité dans `ReglesSolo`, durée de l'étoile dans `Regles` ; plus aucune constante `DUREE_INVULNERABILITE` dans `GameState`. → vérification de l'invulnérabilité (Task 3) + greps de la sortie de phase.

---

### Task 0 : documentation (spec : la ville et son territoire)

**Files:**
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1 ligne `Ville`, §6 « Synchro du score »)

Ce plan a été commité par la Task 0 de la phase 9 (avec celui de la phase 9 bis) : vérifier qu'il l'est (`git log --oneline -- docs/superpowers/plans/2026-09-25-phase-09bis-ville.md` : une ligne), sans le recommiter. **Ne jamais modifier le fichier du plan** (ni celui-ci ni celui de la phase 9 : ni réécriture, ni résumé) ; seul le spec est édité ici. La feuille de route est mise à jour à la fin de la phase (Task 4).

- [ ] **Step 1 : spec, §3.1 ligne `Ville`**

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
| `Ville` (scène) | Masque de peinture (visuel) + deux comptages : couverture (solo, inchangé) et **grille de propriété** (bataille). | rien |
```

par :

```markdown
| `Ville` (scène) | Masque de peinture (visuel), tampons en cache par rayon et jeu de couleurs, + deux comptages : couverture (solo, inchangé) et **grille de propriété** (bataille : un `Territoire`, créé quand les règles se jouent au territoire, tamponné par l'hôte seul, qui tient aussi les scores). Chaque tampon est peint pour un `Joueur`, dans ses couleurs. | `Joueur`, `Territoire`, `Regles` |
```

- [ ] **Step 2 : spec, §6 « Synchro du score »**

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
- **Synchro du score** : toutes les 0,2 s, l'hôte envoie la liste des cellules dont le
  propriétaire compté a changé (index u16 + propriétaire u8) et les scores. Les clients
  n'effectuent aucun calcul de propriété.
```

par :

```markdown
- **Synchro du score** : toutes les 0,2 s, l'hôte envoie la liste des cellules dont le
  propriétaire compté a changé (index u16 + propriétaire u8, `Territoire.extraire_changements()`)
  et les scores. Les clients n'effectuent aucun calcul de propriété : leur ville dessine les
  tampons reçus sans toucher à son territoire, auquel elle applique la liste reçue, d'où les
  mêmes scores que l'hôte.
```

- [ ] **Step 3 : Vérifier et committer**

Run : `git diff --stat docs/`
Expected : le spec seul, deux passages.

```bash
git add docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md
git commit -m "Spec : la ville tient le territoire (hôte seul) et ses tampons par jeu de couleurs ; synchro du score par la liste des cellules changées

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 1 : tampons en cache par jeu de couleurs (point obligatoire)

**Files:**
- Modify: `Scripts/Ville.gd`
- Modify: `tests/smoke_test.gd` (fonctions d'aide, section « La traceuse d'un lion peint avec les couleurs de son propre joueur »)

**Interfaces:**
- Consumes : `Regles.DUREE_ETOILE` (phase 9), `ReglesSolo.pastille_ramassee` (un cran par couleur, phase 8 bis), `Joueur.gagner_cran`, `Joueur.avancer`.
- Produces : `Ville.TAMPONS_EN_CACHE_MAX := 96` ; `Ville._tampons: Dictionary[String, Array]` ; `Ville._tampons_pour(rayon, couleurs) -> Array` ; `static Ville._cle_tampons(rayon, couleurs) -> String` ; `Ville._generer_tampons(rayon, couleurs) -> Array[Image]` (le corps de l'ancien `_assurer_tampons`, qui disparaît avec `_tampons_rayon` et `_tampons_nb_couleurs`) ; dans le smoke test, `_couleurs_peintes(image) -> Dictionary` et `_rgba8(couleur) -> int`.

- [ ] **Step 1 : `tests/smoke_test.gd`, les fonctions d'aide**

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
func _frames(n: int) -> void:
	for i in range(n):
		await physics_frame
```

par :

```gdscript
func _frames(n: int) -> void:
	for i in range(n):
		await physics_frame


## Couleurs présentes sur une image (pixels non transparents), en clés `to_rgba32()`. À comparer
## à `_rgba8(couleur)`, pas à `couleur.to_rgba32()` : une image RGBA8 tronque chaque composante
## sur 8 bits (les nuances d'un joueur de bataille ne sont pas exactement représentables).
func _couleurs_peintes(image: Image) -> Dictionary:
	var couleurs := {}
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.0:
				couleurs[c.to_rgba32()] = true
	return couleurs


## La couleur telle qu'une image RGBA8 la stocke, en `to_rgba32()`.
func _rgba8(c: Color) -> int:
	var pixel := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	pixel.set_pixel(0, 0, c)
	return pixel.get_pixel(0, 0).to_rgba32()
```

- [ ] **Step 2 : `tests/smoke_test.gd`, la vérification durcie**

À ce point du smoke test (partie Hardcore terminée, ennemis et Spawner libérés), le joueur local a le vert (1 couleur, 2 crans) et l'autre joueur le rouge et le cyan (2 couleurs, 2 crans, gerbe XXL de l'étoile encore active : l'autre joueur n'est pas dans `GS.joueurs`, rien ne la décompte). On leur donne autant de couleurs, sans couleur commune, et le même rayon (26 px, 3 crans, sans étoile), puis le lion local peint le premier.

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	# La traceuse d'un lion peint avec les couleurs de son propre joueur
	var ville_hc: Node = main.get_node("Ville")
	_check(local.couleurs_debloquees.any(func(c: Color) -> bool: return not autre.couleurs_debloquees.has(c)),
		"(pré-condition) le joueur local a une couleur que l'autre joueur n'a pas")
	lion_autre.commandes.vomir_voulu = true
	await _frames(20)
	lion_autre.commandes.vomir_voulu = false
	await _frames(2)
	# Comparaison par to_rgba32() : une couleur relue depuis une image RGBA8 n'est égale à la
	# couleur d'origine (Color, float) que si celle-ci est exactement représentable en 8 bits.
	# Limite connue : Ville.gd met ses tampons en cache par (rayon, nombre de couleurs), pas par
	# jeu de couleurs, donc deux lions ayant le même nombre de couleurs peindraient avec les
	# tampons du premier peintre ; cette vérification ne discrimine que parce que le lion local
	# ne peint pas dans cette ville et que les comptes diffèrent (1 couleur ici vs 2 pour l'autre
	# joueur) ; le cache sera corrigé en phase 9, qui fera peindre ce test par le lion local en
	# premier à nombre de couleurs égal.
	var couleurs_peintes := {}
	var image_ville: Image = ville_hc.image
	for y in range(image_ville.get_height()):
		for x in range(image_ville.get_width()):
			var c: Color = image_ville.get_pixel(x, y)
			if c.a > 0.0:
				couleurs_peintes[c.to_rgba32()] = true
	var rgba32_autre: Array = autre.couleurs_debloquees.map(func(c: Color) -> int: return c.to_rgba32())
	_check(not couleurs_peintes.is_empty()
		and couleurs_peintes.keys().all(func(k: int) -> bool: return rgba32_autre.has(k)),
		"la traceuse d'un lion peint avec les couleurs de son joueur (%d couleur(s) sur la ville)" % couleurs_peintes.size())
```

par :

```gdscript
	# La traceuse d'un lion peint avec les couleurs de son propre joueur. Le lion local peint
	# d'abord, avec autant de couleurs et le même rayon que l'autre lion : la ville garde ses
	# tampons par jeu de couleurs, l'autre lion ne doit donc pas reprendre ceux du lion local.
	var ville_hc: Node = main.get_node("Ville")
	GS.regles.pastille_ramassee(local, 5)  # le joueur local : vert et bleu, 3 crans
	autre.gagner_cran()  # l'autre joueur : rouge et cyan, 3 crans
	autre.avancer(Regles.DUREE_ETOILE)  # fin de la gerbe XXL de l'étoile ramassée plus haut (autre n'est pas dans GS.joueurs)
	_check(local.couleurs_debloquees.size() == autre.couleurs_debloquees.size()
		and lion.traceuse_shape.shape.radius == lion_autre.traceuse_shape.shape.radius
		and not local.couleurs_debloquees.any(func(c: Color) -> bool: return autre.couleurs_debloquees.has(c)),
		"(pré-condition) les deux lions ont autant de couleurs, le même rayon (%.0f px) et aucune couleur commune" % lion.traceuse_shape.shape.radius)
	lion.global_position = Vector2(600, ville_hc.position.y - 300)
	Input.action_press("vomir")
	await _frames(20)
	Input.action_release("vomir")
	await _frames(2)
	_check(not _couleurs_peintes(ville_hc.image).is_empty(), "(pré-condition) le lion local a peint la ville le premier")
	ville_hc.image.fill(Color(0, 0, 0, 0))
	ville_hc.coulures.clear()  # celles du lion local couleraient encore dans ses couleurs
	lion_autre.commandes.vomir_voulu = true
	await _frames(20)
	lion_autre.commandes.vomir_voulu = false
	await _frames(2)
	var couleurs_peintes := _couleurs_peintes(ville_hc.image)
	var rgba32_autre: Array = autre.couleurs_debloquees.map(_rgba8)
	_check(not couleurs_peintes.is_empty()
		and couleurs_peintes.keys().all(func(k: int) -> bool: return rgba32_autre.has(k)),
		"la traceuse d'un lion peint avec les couleurs de son joueur, même après un lion qui en a autant (%d couleur(s) sur la ville)" % couleurs_peintes.size())
```

Notes :
- `lion` est le lion local de la partie Hardcore (`main.get_node("Lion")`), qui lit les commandes de ce poste : `Input.action_press("vomir")` le fait vomir, comme dans la partie Facile.
- L'image et les coulures sont effacées entre les deux peintres : seules les couleurs du second restent à vérifier.
- `JL.bonus_restant = 0.0`, plus haut dans la section, coupe le bonus du joueur local sans signal : son rayon redevient normal au prochain cran (`crans_changes`), ici donné par la pastille.

- [ ] **Step 3 : Lancer le smoke test (échec attendu)**

Run : le smoke test avec délai.
Expected : les deux pré-conditions passent, puis `❌ la traceuse d'un lion peint avec les couleurs de son joueur, même après un lion qui en a autant (4 couleur(s) sur la ville)` (le nombre peut varier : l'autre lion peint avec les tampons du lion local, et ses coulures dans ses propres couleurs), `== 1 échec(s) ==`.

- [ ] **Step 4 : `Scripts/Ville.gd`**

4a. Dans `Scripts/Ville.gd`, remplacer :

```gdscript
const COUVERTURE_CELLULE := 0.4
```

par :

```gdscript
const COUVERTURE_CELLULE := 0.4
## Jeux de tampons gardés au plus (un jeu par rayon et jeu de couleurs) ; au-delà, le cache est
## vidé. 6 joueurs × 7 crans × 2 (étoile XXL) en demandent 84 au pire.
const TAMPONS_EN_CACHE_MAX := 96
```

4b. Dans `Scripts/Ville.gd`, remplacer :

```gdscript
var _tampons: Array[Image] = []
var _tampons_rayon := -1
var _tampons_nb_couleurs := -1
```

par :

```gdscript
## Tampons par rayon et jeu de couleurs (clé : `_cle_tampons`) : deux lions qui ont autant de
## couleurs et le même rayon peignent chacun avec les leurs.
var _tampons: Dictionary[String, Array] = {}
```

4c. Dans `Scripts/Ville.gd`, remplacer :

```gdscript
	coulures.clear()
	_tampons_rayon = -1
	_calculer_cellules_peignables()
```

par :

```gdscript
	coulures.clear()
	_tampons.clear()
	_calculer_cellules_peignables()
```

4d. Dans `Scripts/Ville.gd`, remplacer :

```gdscript
	_assurer_tampons(rayon, couleurs)
	var tampon := _tampons[randi() % _tampons.size()]
```

par :

```gdscript
	var tampons := _tampons_pour(rayon, couleurs)
	var tampon: Image = tampons[randi() % tampons.size()]
```

4e. Dans `Scripts/Ville.gd`, remplacer :

```gdscript
	coulures = restantes
	_dirty = true



## Régénère les tampons quand le rayon ou le nombre de couleurs change.
func _assurer_tampons(rayon: int, couleurs: Array[Color]) -> void:
	if rayon == _tampons_rayon and couleurs.size() == _tampons_nb_couleurs:
		return
	_tampons_rayon = rayon
	_tampons_nb_couleurs = couleurs.size()
	_tampons.clear()
	var taille := rayon * 2 + 1
```

par :

```gdscript
	coulures = restantes
	_dirty = true


## Les NB_TAMPONS tampons de ce rayon et de ce jeu de couleurs : générés au premier usage, puis
## gardés en cache (TAMPONS_EN_CACHE_MAX jeux au plus).
func _tampons_pour(rayon: int, couleurs: Array[Color]) -> Array:
	var cle := _cle_tampons(rayon, couleurs)
	if not _tampons.has(cle):
		if _tampons.size() >= TAMPONS_EN_CACHE_MAX:
			_tampons.clear()
		_tampons[cle] = _generer_tampons(rayon, couleurs)
	return _tampons[cle]


## Le rayon puis chaque couleur en RGBA 8 bits, dans l'ordre : deux jeux qui ne diffèrent que par
## une couleur ont des clés différentes.
static func _cle_tampons(rayon: int, couleurs: Array[Color]) -> String:
	var cle := str(rayon)
	for c in couleurs:
		cle += ":%08x" % c.to_rgba32()
	return cle


## Tampons denses au centre, épars sur les bords, dont chaque pixel prend une des couleurs.
func _generer_tampons(rayon: int, couleurs: Array[Color]) -> Array[Image]:
	var tampons: Array[Image] = []
	var taille := rayon * 2 + 1
```

4f. Dans `Scripts/Ville.gd`, remplacer :

```gdscript
					tampon.set_pixel(x, y, c)
		_tampons.append(tampon)
```

par :

```gdscript
					tampon.set_pixel(x, y, c)
		tampons.append(tampon)
	return tampons
```

- [ ] **Step 5 : Vérifier**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` (aucune ligne), les tests unitaires avec délai (verts), puis **5 passages** consécutifs du smoke test : verts, sans `SCRIPT ERROR` ni `SHADER ERROR`, avec « la traceuse d'un lion peint avec les couleurs de son joueur, même après un lion qui en a autant (2 couleur(s) sur la ville) ».

- [ ] **Step 6 : Commit**

```bash
git add Scripts/Ville.gd tests/smoke_test.gd
git commit -m "Ville : tampons en cache par rayon et jeu de couleurs (deux lions qui ont autant de couleurs peignent chacun avec les leurs) ; smoke : le lion local peint d'abord, à nombre de couleurs et rayon égaux

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 2 : la ville tient le territoire, la traceuse peint pour son joueur

**Files:**
- Modify: `Scripts/Ville.gd`
- Modify: `Scripts/GerbeTraceuse.gd`
- Modify: `tests/smoke_test.gd` (partie Facile, niveau Métropole, nouvelle section « Territoire » à la fin de `_run`)

**Interfaces:**
- Consumes : phase 9 (`Territoire`, `Regles.compte_le_territoire`, `Regles.vol_de_cellules`) ; Task 1 ; `Joueur.index`, `Joueur.couleurs_debloquees`, `Joueur.nuances` ; `GameState.configurer_bataille` / `configurer_solo` (phase 8).
- Produces : `Ville.territoire: Territoire` (null hors bataille) ; `Ville.peindre(position_globale: Vector2, rayon: int, peintre: Joueur)` ; `GerbeTraceuse` appelle `ville.peindre(global_position, rayon, lion.joueur)`.

- [ ] **Step 1 : `tests/smoke_test.gd`, les vérifications**

1a. Partie Facile, juste après le chargement de `Main`. Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	_check(not JL.a_une_couleur() and lion.sprite.material == null and not lion.etiquette_pseudo.visible,
		"en solo, le joueur n'a pas de couleur de lion : sprite sans matériau (rendu d'origine), pas de pseudo")
```

par :

```gdscript
	_check(not JL.a_une_couleur() and lion.sprite.material == null and not lion.etiquette_pseudo.visible,
		"en solo, le joueur n'a pas de couleur de lion : sprite sans matériau (rendu d'origine), pas de pseudo")
	_check(ville.territoire == null, "en solo, la ville ne tient pas de territoire : seule la couverture compte")
```

1b. Niveau Métropole : `peindre` reçoit le joueur. Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	ville.peindre(Vector2(1000, haut + 200), 45, JL.couleurs_debloquees)
```

par :

```gdscript
	ville.peindre(Vector2(1000, haut + 200), 45, JL)
```

1c. Dans `tests/smoke_test.gd`, remplacer :

```gdscript
			ville.peindre(Vector2(x, haut + y), 45, JL.couleurs_debloquees)
```

par :

```gdscript
			ville.peindre(Vector2(x, haut + y), 45, JL)
```

1d. Fin de `_run`, après la section des lions de bataille. Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	for l in lions_bataille:
		l.free()
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false

	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	for l in lions_bataille:
		l.free()
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false

	# Territoire : la ville d'une bataille tient la grille de propriété, dans une scène propre
	# (sa ville, ses deux lions). Aucun ennemi des sections précédentes ne doit y entrer.
	for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss"):
		ennemi.free()
	GS.configurer_bataille(2)
	GS.nouvelle_partie()
	GS.pret = true
	var j_r: Joueur = GS.joueurs[0]
	var j_b: Joueur = GS.joueurs[1]
	var ville_b: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	root.add_child(ville_b)
	ville_b.position = Vector2(1000, 648 - ville_b.tex_size.y / 2.0)  # comme Main._placer_ville
	var lions_t: Array[CharacterBody2D] = []
	for j: Joueur in GS.joueurs:
		var l: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
		l.joueur = j
		l.commandes = Commandes.manuelles()
		l.position = Vector2(200 + 1000 * lions_t.size(), 0)
		root.add_child(l)
		lions_t.append(l)
	var l_r: CharacterBody2D = lions_t[0]
	var l_b: CharacterBody2D = lions_t[1]
	var poste_peinture := Vector2(600, ville_b.position.y - 300)
	await _frames(2)
	var t: Territoire = ville_b.territoire
	_check(t != null and t.nb_peignables == ville_b.cellules_peignables and t.cellules_de(0) == 0 and t.cellules_de(1) == 0,
		"en bataille, la ville tient un territoire vierge sur ses cellules peignables (%d)" % ville_b.cellules_peignables)
	_check(l_r.traceuse_shape.shape.radius == l_b.traceuse_shape.shape.radius and j_r.couleurs_debloquees.size() == j_b.couleurs_debloquees.size(),
		"(pré-condition) les deux lions ont le même rayon et autant de couleurs (trois nuances)")

	# Le lion rouge peint : ses cellules comptent pour lui, dans ses nuances
	l_r.global_position = poste_peinture
	await _frames(1)
	l_r.commandes.vomir_voulu = true
	await _frames(40)
	l_r.commandes.vomir_voulu = false
	await _frames(2)
	var cellules_rouges: int = t.cellules_de(0)
	var rgba32_rouge: Array = j_r.nuances().map(_rgba8)
	var rgba32_bleu: Array = j_b.nuances().map(_rgba8)
	_check(cellules_rouges > 0 and t.cellules_de(1) == 0, "les cellules que peint un lion comptent pour son joueur (%d)" % cellules_rouges)
	_check(_couleurs_peintes(ville_b.image).keys().all(func(k: int) -> bool: return rgba32_rouge.has(k)),
		"le lion rouge peint dans ses nuances")
	_check(t.extraire_changements().size() == cellules_rouges and t.extraire_changements().is_empty(),
		"les cellules qui se mettent à compter sont listées pour la synchronisation, une fois")

	# Le lion bleu repeint au même endroit : il vole les cellules du rouge, dans ses propres nuances
	l_r.global_position = Vector2(1500, 0)
	l_b.global_position = poste_peinture
	await _frames(1)
	ville_b.image.fill(Color(0, 0, 0, 0))
	ville_b.coulures.clear()
	l_b.commandes.vomir_voulu = true
	await _frames(40)
	l_b.commandes.vomir_voulu = false
	await _frames(2)
	_check(_couleurs_peintes(ville_b.image).keys().all(func(k: int) -> bool: return rgba32_bleu.has(k)),
		"à rayon et nombre de couleurs égaux, le second lion peint dans ses propres nuances")
	_check(t.cellules_de(1) > 0 and t.cellules_de(0) < cellules_rouges and j_b.cellules_volees > 0
		and j_b.cellules_volees == cellules_rouges - t.cellules_de(0) and j_r.cellules_volees == 0,
		"repeindre les cellules d'un autre les lui vole ; les règles comptent les vols (%d volées, %d restent au rouge)" % [j_b.cellules_volees, t.cellules_de(0)])

	# Sur un client, la ville dessine le tampon mais ne touche pas au territoire : l'hôte décide
	var api_ville := SceneMultiplayer.new()
	var pair_ville := ENetMultiplayerPeer.new()
	pair_ville.create_client("127.0.0.1", 7779)
	api_ville.multiplayer_peer = pair_ville
	set_multiplayer(api_ville, ville_b.get_path())
	var scores_avant := [t.cellules_de(0), t.cellules_de(1)]
	var point_vierge := Vector2(1800, 648 - 20)  # bas de la skyline, à droite : jamais peint ici
	ville_b.image.fill(Color(0, 0, 0, 0))
	for i in range(10):
		ville_b.peindre(point_vierge, 30, j_r)
	_check(not ville_b.multiplayer.is_server() and not _couleurs_peintes(ville_b.image).is_empty()
		and [t.cellules_de(0), t.cellules_de(1)] == scores_avant,
		"sur un client, la ville dessine les tampons sans toucher au territoire")
	set_multiplayer(null, ville_b.get_path())
	pair_ville.close()
	for i in range(10):
		ville_b.peindre(point_vierge, 30, j_r)
	_check(t.cellules_de(0) > scores_avant[0], "de retour sur l'hôte, les mêmes tampons comptent")

	for l in lions_t:
		l.free()
	ville_b.free()
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false

	print("== %d échec(s) ==" % _echecs)
```

Notes :
- Les deux lions sont au premier cran (16 px) et vomissent leurs trois nuances : même rayon et autant de couleurs, la situation exacte du défaut de cache corrigé par la Task 1, cette fois en bataille.
- Immobile, un lion tamponne le même disque à chaque frame : en 40 frames, le rouge renforce ses cellules à `CHARGE_MAX` ; le bleu les vide (6 tampons) puis les possède (3 de plus). Au moment du plan : 8 cellules, toutes volées (le vol exact, cellule par cellule, est vérifié par les tests unitaires de la phase 9).
- `extraire_changements()` est appelé deux fois dans la même vérification, de gauche à droite : la première liste, puis la liste vide.
- Le lion rouge est posé en `(1500, 0)`, loin du bleu : leurs pare-chocs ne se touchent pas, et sa traceuse ne peint pas (il ne vomit plus).
- Sous-arbre client : la technique de la phase 8 ter (`set_multiplayer(api, chemin)`, pair ENet jamais connecté), ici sur la ville.

- [ ] **Step 2 : Lancer le smoke test (échec attendu)**

Run : le smoke test avec délai.
Expected : `SCRIPT ERROR: Invalid access to property or key 'territoire' on a base object of type 'Node2D (Ville.gd)'.` (la vérification du solo, en tête de la partie Facile). La suite s'arrête là et le délai coupe le processus.

- [ ] **Step 3 : `Scripts/Ville.gd`**

3a. Dans `Scripts/Ville.gd`, remplacer :

```gdscript
## La ville : masque de peinture RGBA appliqué par shader sur la skyline.
## La peinture se fait par tampons multicolores (blit natif). La progression est mesurée
## sur une grille de cellules couvrant les zones opaques de la skyline : une cellule compte
## quand au moins COUVERTURE_CELLULE de sa surface est réellement peinte (mesure par
## réduction du masque, à intervalle régulier).
```

par :

```gdscript
## La ville : masque de peinture RGBA appliqué par shader sur la skyline.
## La peinture se fait par tampons multicolores (blit natif), aux couleurs du joueur qui peint.
## La progression est mesurée sur une grille de cellules couvrant les zones opaques de la
## skyline : une cellule compte quand au moins COUVERTURE_CELLULE de sa surface est réellement
## peinte (mesure par réduction du masque, à intervalle régulier). En bataille, la même grille
## porte aussi le territoire (`Territoire`) : l'hôte y reporte chaque tampon.
```

3b. Dans `Scripts/Ville.gd`, remplacer :

```gdscript
var cellules_peintes := 0
var _cellules_peignables: PackedByteArray
```

par :

```gdscript
var cellules_peintes := 0
## Grille de propriété de la bataille (propriétaire et charge par cellule, scores par joueur),
## créée par `charger_skyline` quand les règles se jouent au territoire ; null en solo.
var territoire: Territoire
var _cellules_peignables: PackedByteArray
```

3c. Dans `Scripts/Ville.gd`, remplacer :

```gdscript
	_tampons.clear()
	_calculer_cellules_peignables()
```

par :

```gdscript
	_tampons.clear()
	_calculer_cellules_peignables()
	territoire = Territoire.new(grille_taille, _cellules_peignables, TAILLE_CELLULE) \
		if GameState.regles.compte_le_territoire() else null
```

3d. Dans `Scripts/Ville.gd`, remplacer :

```gdscript
## Applique un tampon de peinture de rayon `rayon` centré sur une position globale.
func peindre(position_globale: Vector2, rayon: int, couleurs: Array[Color]) -> void:
	if couleurs.is_empty() or rayon <= 0:
		return
```

par :

```gdscript
## Applique un tampon de peinture de rayon `rayon`, centré sur une position globale, aux couleurs
## débloquées de `peintre`. En bataille, sur l'hôte seulement, le tampon est aussi reporté sur le
## territoire et ses vols sont signalés aux règles.
func peindre(position_globale: Vector2, rayon: int, peintre: Joueur) -> void:
	var couleurs := peintre.couleurs_debloquees
	if couleurs.is_empty() or rayon <= 0:
		return
```

3e. Dans `Scripts/Ville.gd`, remplacer :

```gdscript
			"fin": float(py + rayon + randi_range(14, 44)), "couleur": c,
		})
	_dirty = true
```

par :

```gdscript
			"fin": float(py + rayon + randi_range(14, 44)), "couleur": c,
		})
	_dirty = true
	if territoire != null and multiplayer.is_server():
		var volees := territoire.tamponner(peintre.index, Vector2i(px, py), rayon)
		if volees > 0:
			GameState.regles.vol_de_cellules(peintre, volees)
```

(`px`, `py` : le centre du tampon en pixels de la ville, le repère de la grille de `_calculer_cellules_peignables` ; un tampon qui déborde de la texture est borné par `Territoire`.)

- [ ] **Step 4 : `Scripts/GerbeTraceuse.gd`**

Dans `Scripts/GerbeTraceuse.gd`, remplacer :

```gdscript
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

par :

```gdscript
## Le lion qui porte cette zone : on peint pour son joueur (ses couleurs ; en bataille, son
## territoire).
@onready var lion: Node = get_parent()


func _process(_delta: float) -> void:
	if not monitoring:
		return
	var peintre: Joueur = lion.joueur
	if peintre.couleurs_debloquees.is_empty():
		return
	var rayon := int((forme.shape as CircleShape2D).radius)
	for area in get_overlapping_areas():
		var ville: Node = area.get_parent()
		if ville != null and ville.has_method("peindre"):
			ville.peindre(global_position, rayon, peintre)
```

- [ ] **Step 5 : Vérifier**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` (aucune ligne), les tests unitaires avec délai (verts), puis **5 passages** consécutifs du smoke test : verts, sans `SCRIPT ERROR` ni `SHADER ERROR`, avec les 10 nouvelles vérifications (une dans la partie Facile, neuf dans la section « Territoire ») ; relever dans `$TMPDIR/t.log` le nombre de cellules peintes puis volées (8 et 8 au moment du plan, identiques d'un passage à l'autre).

Run aussi : `grep -rn "peindre(" Scripts tests`
Expected : la définition dans `Scripts/Ville.gd`, l'appel de `Scripts/GerbeTraceuse.gd` et ceux du smoke test, tous avec un `Joueur` en troisième argument.

- [ ] **Step 6 : Commit**

```bash
git add Scripts/Ville.gd Scripts/GerbeTraceuse.gd tests/smoke_test.gd
git commit -m "Ville : en bataille, territoire tamponné par l'hôte seul, vols signalés aux règles ; peindre reçoit le joueur qui peint, la traceuse lui passe le sien

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 3 : `DUREE_INVULNERABILITE` descend dans `ReglesSolo`

**Files:**
- Modify: `Scripts/GameState.gd`
- Modify: `Scripts/ReglesSolo.gd`
- Modify: `tests/smoke_test.gd` (partie Facile ; lecture de `DUREE_ETOILE`)

**Interfaces:**
- Consumes : `ReglesSolo.lion_touche_par_ennemi` (phases 3 et 9).
- Produces : `ReglesSolo.DUREE_INVULNERABILITE := 1.5` ; `GameState.DUREE_INVULNERABILITE` n'existe plus (plus aucun lecteur : `Lion.gd` clignote sur `joueur.invulnerable_restant` depuis la phase 8 bis).

- [ ] **Step 1 : `tests/smoke_test.gd`, les vérifications**

1a. Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	_check(JL.est_invulnerable(), "le lion est invulnérable après un coup")
```

par :

```gdscript
	var constantes_solo: Dictionary = GS.regles.get_script().get_script_constant_map()
	_check(JL.est_invulnerable() and JL.invulnerable_restant > constantes_solo.get("DUREE_INVULNERABILITE", 99.0) - 0.2
		and not GS.get_script().get_script_constant_map().has("DUREE_INVULNERABILITE"),
		"le lion est invulnérable après un coup, pour la durée que fixent les règles du solo (plus GameState)")
```

1b. Dans `tests/smoke_test.gd`, remplacer :

```gdscript
		and is_equal_approx(autre.bonus_restant, ReglesSolo.DUREE_ETOILE) and local.bonus_actif() == bonus_local,
```

par :

```gdscript
		and is_equal_approx(autre.bonus_restant, Regles.DUREE_ETOILE) and local.bonus_actif() == bonus_local,
```

(La constante est dans la base depuis la phase 9 ; `ReglesSolo.DUREE_ETOILE` se lisait encore par héritage.)

Notes :
- La carte des constantes (`get_script_constant_map()`) est lue par l'instance des règles et par le script de `GameState` : le test compile avant la Task (nommer `ReglesSolo.DUREE_INVULNERABILITE` ne compilerait pas), et échoue alors sur sa valeur par défaut (99).
- Trois frames séparent le coup de la vérification : l'invulnérabilité restante est un peu sous 1,5 s, d'où la marge de 0,2 s.

- [ ] **Step 2 : Lancer le smoke test (échec attendu)**

Run : le smoke test avec délai.
Expected : `❌ le lion est invulnérable après un coup, pour la durée que fixent les règles du solo (plus GameState)`, `== 1 échec(s) ==`.

- [ ] **Step 3 : `Scripts/GameState.gd`**

Dans `Scripts/GameState.gd`, remplacer :

```gdscript
const NB_ETAPES_ARCADE := 9  # 3 niveaux × 3 difficultés
const DUREE_INVULNERABILITE := 1.5
```

par :

```gdscript
const NB_ETAPES_ARCADE := 9  # 3 niveaux × 3 difficultés
```

- [ ] **Step 4 : `Scripts/ReglesSolo.gd`**

4a. Dans `Scripts/ReglesSolo.gd`, remplacer :

```gdscript
## celle de la base (`Regles.DUREE_ETOILE`).


func _init(partie_: EtatPartie) -> void:
```

par :

```gdscript
## celle de la base (`Regles.DUREE_ETOILE`).

## Invulnérabilité qui suit un coup, en secondes (le lion clignote pendant ce temps).
const DUREE_INVULNERABILITE := 1.5


func _init(partie_: EtatPartie) -> void:
```

4b. Dans `Scripts/ReglesSolo.gd`, remplacer :

```gdscript
	if joueur.encaisser_coup(origine, partie.DUREE_INVULNERABILITE) <= 0:
```

par :

```gdscript
	if joueur.encaisser_coup(origine, DUREE_INVULNERABILITE) <= 0:
```

- [ ] **Step 5 : Vérifier**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` (aucune ligne), les tests unitaires avec délai (verts), puis **5 passages** consécutifs du smoke test : verts, sans `SCRIPT ERROR` ni `SHADER ERROR`.

Run aussi : `grep -rn "DUREE_INVULNERABILITE" Scripts tests`
Expected : la constante et son usage dans `Scripts/ReglesSolo.gd`, et la vérification du smoke test (dans une chaîne).

- [ ] **Step 6 : Commit**

```bash
git add Scripts/GameState.gd Scripts/ReglesSolo.gd tests/smoke_test.gd
git commit -m "ReglesSolo : DUREE_INVULNERABILITE quitte GameState (seule règle qui s'en sert) ; smoke : la durée de l'étoile se lit sur la base Regles

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 4 : feuille de route, points de vigilance résolus par les phases 9 et 9 bis

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`

**Ne jamais modifier le fichier du plan** (ce fichier, ni celui de la phase 9) : seule la feuille de route change ici.

- [ ] **Step 1 : le point obligatoire du cache des tampons, résolu (Task 1)**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 9 bis (obligatoire)** : `Scripts/Ville.gd` met en cache ses tampons par (rayon, nombre de
  couleurs) et non par jeu de couleurs : deux lions ayant autant de couleurs peignent avec les
  tampons du premier (prouvé en revue de phase 6 ; en bataille, chacun a 3 nuances). Mettre les
  tampons en cache par jeu de couleurs (clé rayon + `to_rgba32` de chaque couleur, plusieurs
  entrées), et durcir la vérification du smoke test « la traceuse d'un lion peint avec les
  couleurs de son joueur » en faisant peindre d'abord le lion local avec autant de couleurs que
  l'autre ;
```

par :

```markdown
- **phase 14** : sur un client, la ville a aussi un territoire (les règles de bataille y sont
  branchées) mais `Ville.peindre` n'y touche pas (`multiplayer.is_server()`, phase 9 bis) : lui
  appliquer la liste des cellules reçue de l'hôte (`Territoire.extraire_changements()` chez
  l'hôte, index u16 + propriétaire u8) par une méthode d'affichage à ajouter à `Territoire`
  (propriétaire compté posé tel quel, sans charge), d'où les mêmes scores chez tous ; ne jamais y
  rejouer `tamponner`. Le tampon diffusé porte l'index du joueur : `Ville.peindre(position,
  rayon, peintre)` prend déjà un `Joueur`. Le motif et les coulures d'un tampon viennent encore du
  hasard global (`randi`, `randf`) : les tirer de la graine du tampon (spec §6) ;
```

- [ ] **Step 2 : le point sur `cellules_volees`, résolu (Task 2)**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phases 9 et 9 bis** : `Joueur.cellules_volees` existe depuis la phase 8 (remis à zéro par
  `reinitialiser`, jamais incrémenté) : `Territoire.tamponner` renvoie les cellules que vole un
  tampon (phase 9), la ville de l'hôte les signale aux règles (`Regles.vol_de_cellules`, phase
  9 bis), qui l'incrémentent pendant la manche. En bataille, les couleurs débloquées d'un joueur
  sont ses trois nuances (données par `Regles.couleurs_de_depart`) : c'est ce que reçoivent la
  traceuse et `Ville.peindre` ;
```

par :

```markdown
- **phases 10 et 17** : le score d'un joueur se lit sur le territoire de la ville
  (`ville.territoire.cellules_de(joueur.index)`, sur `ville.territoire.nb_peignables` pour un
  pourcentage) ; il n'y a pas de `Joueur.cellules` (spec §3.1). La ville crée son territoire dans
  `charger_skyline` d'après les règles branchées (`compte_le_territoire()`) : c'est une raison de
  plus d'appeler `configurer_bataille(n)` avant la scène de bataille. La couverture du solo reste
  mesurée en bataille (`GameState.progression`, lue par `Audio`, `Boss.facteur_vitesse` et le
  HUD) : décider de ce que la bataille en garde (phase 10 pour le peintre, 17 pour la musique et
  le HUD). Les réglages du territoire (`GAIN`, `SEUIL_POSSESSION`, `CHARGE_MAX`) sont à revoir
  sur une vraie manche ;
```

- [ ] **Step 3 : le point sur `DUREE_INVULNERABILITE`, résolu (Task 3)**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 9 bis** : `Scripts/Lion.gd` ne lit plus `GameState.DUREE_INVULNERABILITE` (il clignote
  sur `joueur.invulnerable_restant` depuis la phase 8 bis) : descendre cette constante de
  `GameState` vers `ReglesSolo`, seule règle qui s'en sert encore (`DUREE_ETOILE` et
  `_manche_en_cours()` sont dans la base `Regles` depuis la phase 9) ;
```

par :

```markdown
- les tests `--script` peuvent nommer `Territoire` (logique pure, phase 9) et les règles, jamais
  la ville, le lion ni les ennemis (qui nomment des autoloads). Les couleurs relues sur la ville
  se comparent après un passage par une image RGBA8 (`_rgba8` du smoke test) : `set_pixel`
  tronque sur 8 bits, `Color.to_rgba32()` arrondit ;
```

- [ ] **Step 4 : Vérifier et committer**

Run : `grep -nE "^- \*\*(phase 9 bis|phases 9 et 9 bis)" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
Expected : aucune ligne (les trois points de la phase sont remplacés ; la ligne `| 9 bis |` du tableau et la mention « phase 9 bis » du nouveau point de la phase 14 restent).

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
git commit -m "Feuille de route : points de vigilance résolus par les phases 9 et 9 bis (cache des tampons, vols, DUREE_INVULNERABILITE) ; territoire des clients (phase 14), scores et couverture en bataille (phases 10 et 17)

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

## Sortie de phase

- Les deux suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR`, localement (smoke test 5 fois) puis en CI sur la PR.
- `git diff main --stat` : 5 fichiers de code (`Scripts/Ville.gd`, `Scripts/GerbeTraceuse.gd`, `Scripts/GameState.gd`, `Scripts/ReglesSolo.gd`, `tests/smoke_test.gd`) plus le spec et la feuille de route.
- `grep -n "_tampons_rayon\|_tampons_nb_couleurs\|_assurer_tampons" Scripts/Ville.gd` : aucune ligne.
- `grep -rn "DUREE_INVULNERABILITE" Scripts/GameState.gd` : aucune ligne.
- `grep -rn "compte_le_territoire\|vol_de_cellules\|Territoire.new" Scripts | grep -v "^Scripts/Regles"` : seulement `Scripts/Ville.gd` (création dans `charger_skyline`, vols dans `peindre`).
- Rappeler à l'utilisateur : la bataille ne se joue pas encore (scène de bataille, branchement de `configurer_bataille` et lecture des scores : phase 10) ; `tests/screenshots.gd` n'a pas été relancé (solo inchangé) et son `SCRIPT ERROR` préexistant (Spawner pendant l'intro) reste inscrit dans la feuille de route.
