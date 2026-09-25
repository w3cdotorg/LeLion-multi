# Phase 9 : territoire (logique et règles), plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** la logique du territoire de la bataille existe et est testée sans scène : `Scripts/Territoire.gd` (propriétaire et charge par cellule, gain, décharge, prise et vol, seuil de possession, scores par joueur, liste des cellules changées pour la future synchronisation), en calcul entier et déterministe, réglé pour qu'une cellule se peigne à peu près aussi vite que la couverture du solo ; les règles comptent les vols (`Regles.vol_de_cellules`, statistique `cellules_volees`) et disent si la partie se joue au territoire (`Regles.compte_le_territoire`). La dette des règles est soldée : `DUREE_ETOILE` et `_manche_en_cours()` montent dans la base `Regles`. **Le solo reste strictement identique**, et rien n'appelle encore le territoire hors des tests : la ville le tiendra en phase 9 bis.

**Architecture:** `Territoire` (`class_name`, `RefCounted`, logique pure : ne nomme aucun autoload) reçoit la grille de la ville (taille, octets « peignable », 8 px par cellule) et tient cinq tableaux compacts : `_proprietaires` et `_charges` (`PackedByteArray`, spec §6 ; propriétaire stocké décalé de un, 0 = personne), `_dernier_compte` (dernier joueur pour qui la cellule a compté), `_cellules` (`PackedInt32Array` : cellules qui comptent, par propriétaire, tenues à jour tampon après tampon, donc un score en O(1)) et la liste `_changements` (indices des cellules dont le propriétaire compté a changé, chacune une fois, vidée par `extraire_changements()`). `tamponner(index_joueur, centre, rayon)` ne parcourt que le carré de cellules qui borne le disque (bornes coupées à la grille, jamais de débordement d'une rangée sur l'autre) et renvoie le nombre de cellules volées. Les règles ne tiennent pas le territoire : elles reçoivent les vols (`vol_de_cellules(voleur, nb)`, compté pendant la manche seulement) et, par `compte_le_territoire()`, disent à la ville (phase 9 bis) s'il faut en créer un.

**Tech Stack:** Godot 4.7.2, GDScript, tests unitaires headless.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1 `Joueur`, `Regles`, `Ville` ; §6 « Peinture, territoire et synchronisation », corrigé par la Task 0 ; §10 tests unitaires) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (phase 9, coupée en 9 et 9 bis par la Task 0 ; points de vigilance « phase 9 (obligatoire) », « phase 9 » sur `cellules_volees`, « la prochaine phase qui touche `Regles.gd`… ») · suite : `docs/superpowers/plans/2026-09-25-phase-09bis-ville.md` · prérequis : phase 8 ter (`docs/superpowers/plans/2026-09-25-phase-08ter-ennemis.md`) fusionnée (cette phase n'en dépend pas, mais la suit dans la feuille de route).

## Découpage : phase 9 et phase 9 bis

La ligne 9 de la feuille de route (Territoire, Ville, ReglesBataille, tests unitaires, smoke test) ne tient pas en 5 fichiers une fois comptés ce qu'elle demande : la base `Regles` doit déclarer le nouvel événement de vol et la question « territoire ou pas » (sinon `GameState.regles`, typé `Regles`, ne compile pas l'appel), la ville a besoin de savoir **qui** peint (`Scripts/GerbeTraceuse.gd` lui passe aujourd'hui des couleurs seulement), et la dette des règles (`DUREE_ETOILE`, `_manche_en_cours()`) touche aussi `ReglesSolo.gd`. Elle est coupée en deux phases de 5 fichiers, chacune testable et fusionnable seule :

| Phase | Objet | Fichiers |
|---|---|---|
| **9** (ce plan) | Territoire et règles : logique pure, tests unitaires ; dette `DUREE_ETOILE` / `_manche_en_cours()` | ➕ `Scripts/Territoire.gd` ✏️ `Scripts/Regles.gd` ✏️ `Scripts/ReglesSolo.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `tests/unitaires.gd` |
| **9 bis** | Territoire dans la ville : tampons en cache par jeu de couleurs (point obligatoire), la ville tient et tamponne le territoire en bataille (hôte seulement), la traceuse peint pour son joueur ; `DUREE_INVULNERABILITE` descend dans `ReglesSolo` | ✏️ `Scripts/Ville.gd` ✏️ `Scripts/GerbeTraceuse.gd` ✏️ `Scripts/GameState.gd` ✏️ `Scripts/ReglesSolo.gd` ✏️ `tests/smoke_test.gd` |

À la fin de la phase 9, rien n'appelle `Territoire`, `vol_de_cellules` ni `compte_le_territoire` hors des tests : le jeu est inchangé.

## Écarts assumés

1. **Le vol est compté quand la cellule se met à compter pour le voleur** (spec §6 : « le vol est compté » au passage de `charge <= 0`). Pris à la lettre, ce passage se produit à chaque tampon quand deux lions se disputent une cellule que personne n'a encore possédée : A charge à 4, B la vide et la prend (0), A la reprend (4), et ainsi de suite, soit jusqu'à 60 « vols » par seconde et par cellule, sans que personne ne l'ait jamais possédée. Le titre « Le voleur » mesurerait le temps passé dans les zones disputées. Un vol est donc une cellule qui se met à compter pour le peintre alors qu'elle comptait en dernier pour un autre joueur ; le passage de propriétaire à `charge <= 0` (avec `charge = -charge`) reste celui du spec. Vérifié par « deux peintres qui se disputent une cellule que personne n'a possédée ne se volent rien ». Le spec est corrigé (Task 0).
2. **Réglages** (mesurés au moment du plan, sur la vraie ville et ses vrais tampons, en comparant les cellules comptées par la mesure du solo à celles qui ont reçu *k* tampons) : pour une gerbe en mouvement pendant 1 s, *k* = 3 suit le solo à quelques pourcents près pour tous les rayons (rayon 21 px à 350 px/s : 215 cellules au solo, 223 à *k* = 3 ; rayon 46 px : 548 contre 543 ; à 100 px/s : 79 contre 80). Immobile, le solo compte déjà 40 à 50 % du disque au premier tampon et 65 à 90 % au troisième ; le territoire rien, puis tout le disque au troisième (un lion immobile est l'exception : la gerbe suit un lion qui vole). D'où `GAIN = 4` et `SEUIL_POSSESSION = 12` (3 tampons). `CHARGE_MAX = 24`, choix de jeu et non de calibrage : une cellule que son propriétaire repeint se renforce, il faut alors 6 tampons adverses pour la vider et 3 de plus pour qu'elle compte pour le voleur (trois fois le temps de peindre une cellule vierge ; une cellule tout juste possédée se vole en 6). Avec ces valeurs, toutes multiples de `GAIN`, la charge d'une cellule prise (`-charge`) vaut toujours 0 ; le code garde la règle du spec pour d'autres réglages.
3. **Pas de `Joueur.cellules`** (spec §3.1) : le score d'un joueur est `Territoire.cellules_de(index)`, tenu à jour tampon après tampon, seule source. Un champ de plus dans `Joueur` serait une copie à synchroniser ; en phase 14, les clients appliqueront à leur propre territoire la liste des cellules reçue de l'hôte et en déduiront les mêmes scores. Le spec est corrigé (Task 0).
4. **Taille de la grille** : le spec annonce « ≈ 250 × 81 » ; les skylines font 2000 × 241, 2000 × 320 et 2000 × 180 px, soit des grilles de 250 × 31, 250 × 40 et 250 × 23 (4 733 cellules peignables pour la première). Le coût est mesuré sur 250 × 81, le pire cas annoncé : 360 tampons de 46 px (une seconde à 6 lions) coûtent environ 9 ms, 35 ms avec l'étoile XXL (92 px) pour les six. Le spec est corrigé (Task 0).
5. **Dette des règles en deux temps** : `DUREE_ETOILE` et `_manche_en_cours()` montent dans la base ici (les trois fichiers de règles sont dans cette phase) ; `DUREE_INVULNERABILITE` ne peut descendre de `GameState` vers `ReglesSolo` qu'avec `Scripts/GameState.gd`, un sixième fichier : elle part en phase 9 bis, qui a la place. `ReglesSolo.DUREE_ETOILE` reste lisible par le nom de la sous-classe (constante héritée, vérifié au moment du plan) : le smoke test, qui la lit, compile et passe sans changement dans cette phase.
6. **API du territoire par index de joueur** (0 à 5, `Joueur.index`) : le décalage de un du stockage (0 = personne) ne sort pas de `Territoire` ; `PERSONNE = -1` pour une cellule qui ne compte pour personne.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations.
- Solo strictement identique : `ReglesSolo` ne change que par la montée de la constante et du garde-fou dans la base (même comportement, mêmes tests) ; le smoke test n'est pas modifié et reste vert tel quel.
- Fichiers de la phase (5) : ➕ `Scripts/Territoire.gd`, ✏️ `Scripts/Regles.gd`, ✏️ `Scripts/ReglesSolo.gd`, ✏️ `Scripts/ReglesBataille.gd`, ✏️ `tests/unitaires.gd`. Le `Scripts/Territoire.gd.uid` généré est commité avec le script, hors plafond.
- Pas de nettoyage préalable (règle « Step 0 ») : `tests/unitaires.gd` dépasse 300 lignes mais ne gagne qu'une section et quelques vérifications, sans refactor structurel ; les scripts de règles font moins de 100 lignes.
- **Toujours lancer un test Godot avec un délai maximal** (une erreur de script bloque le processus headless), et chercher `SCRIPT ERROR` et `SHADER ERROR` dans la sortie (une erreur dans une fonction appelée ne change pas le code de sortie, la suite peut finir sur `== 0 échec(s) ==` malgré elle) :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/unitaires.gd; ( godot --headless --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/smoke_test.gd` pour le smoke test ; une suite qui passe n'affiche que ses deux lignes `== … ==`). Un « resources still in use at exit » final est le bruit connu.
- Après la création de `Scripts/Territoire.gd` (`class_name`) : `godot --headless --import .` avant les tests, sinon le cache des classes globales ne la connaît pas.
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : `Territoire.gd` ne nomme aucun autoload (il lit `EtatPartie.NB_JOUEURS_MAX`, la constante de la **classe** de l'autoload, déjà compilée par les tests des règles), ce qui permet aux tests unitaires de le nommer directement.
- Calcul entier seulement dans `Territoire.gd` (aucun `float`, aucun hasard) : c'est ce qui rend le territoire déterministe d'une machine à l'autre.
- Coût : `tamponner` ne parcourt que le carré de cellules qui borne le disque ; aucune allocation par tampon (la liste des changements grandit, sans doublon). Vérifié par un test de coût (moins de 60 ms pour 360 tampons de 46 px ; environ 9 ms au moment du plan).
- Commits en français, terminés par la ligne `Co-Authored-By:` qu'impose l'environnement de l'auteur du commit.

## Review Focus

1. **Charge, prise et seuil** : 3 tampons pour posséder une cellule vierge, plafond à `CHARGE_MAX`, un adversaire la décharge (elle cesse de compter sous le seuil mais reste au premier peintre), la prend à zéro, puis la possède ; la reprendre est aussi un vol. → vérifications de « -- Territoire » de « réglages… » à « la reprendre à son voleur est aussi un vol » (Task 1).
2. **Pas de vol fantôme** : deux peintres qui se disputent une cellule vierge tampon après tampon ne se volent rien (écart 1). → « deux peintres qui se disputent une cellule que personne n'a possédée ne se volent rien » (Task 1).
3. **Déterminisme et scores** : mêmes tampons, même territoire ; les scores tenus tampon après tampon égalent un recompte complet ; chaque cellule qui compte figure une seule fois dans la liste des changements. → « mêmes tampons dans le même ordre… », « les scores tenus… égalent un recompte complet », « chaque cellule qui compte figure dans la liste des changements… » (Task 1).
4. **Bords et coût** : une cellule non peignable ne change jamais ; un tampon qui déborde à gauche ne touche pas la fin de la rangée précédente ; hors de la grille, rien ; 360 tampons de 46 px en moins de 60 ms. → vérifications « une cellule non peignable… », « un tampon débordant à gauche… », « un tampon hors de la grille… », « 360 tampons de 46 px… » (Task 1).
5. **Règles** : seule la bataille se joue au territoire ; les vols comptent pour le voleur pendant la manche, pas pendant l'intro ni après la fin ; l'étoile a la même durée dans les deux modes (constante de la base) ; le solo inchangé (tests des règles solo existants et smoke test vert sans modification). → Task 2.

---

### Task 0 : documentation (commit de ce plan et de celui de la phase 9 bis)

**Files:**
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1 lignes `Joueur` et `Regles`, §6 « Grille » et « Propriété »)
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 9 du tableau, coupée en 9 et 9 bis ; points de vigilance « phase 9 (obligatoire) » et « phase 9 » sur `cellules_volees`)
- Create: `docs/superpowers/plans/2026-09-25-phase-09-territoire.md` (ce plan)
- Create: `docs/superpowers/plans/2026-09-25-phase-09bis-ville.md` (plan de la phase 9 bis)

Les documents ne comptent pas dans le plafond de 5 fichiers. Les deux plans sont déjà écrits : les committer tels quels. **Ne jamais modifier le fichier du plan** (ni celui-ci ni celui de la phase 9 bis : ni réécriture, ni résumé) ; seuls le spec et la feuille de route sont édités ici. La ligne `Ville` du §3.1 et la synchronisation du score (§6) sont éditées par la Task 0 de la phase 9 bis.

- [ ] **Step 1 : spec, §3.1 « Unités »**

1a. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
voir §5), `cellules`, stats (`etourdissements_infliges`, `cellules_volees`, `chocs`).
```

par :

```markdown
voir §5), stats (`etourdissements_infliges`, `cellules_volees`, `chocs`) ; son score (les cellules qu'il possède) est tenu par le territoire de la ville (§6), pas par le `Joueur`.
```

1b. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
Reçoit les événements (lion touché par ennemi, par vomi, pastille ramassée, choc, fin de chrono, progression), chacun pour le `Joueur` concerné, et décide des effets. Donne aussi les couleurs de départ de chaque joueur (aucune en solo, ses trois nuances en bataille).
```

par :

```markdown
Reçoit les événements (lion touché par ennemi, par vomi, pastille ramassée, choc, vol de cellules, fin de chrono, progression), chacun pour le `Joueur` concerné, et décide des effets. Donne aussi les couleurs de départ de chaque joueur (aucune en solo, ses trois nuances en bataille) et dit si la partie se joue au territoire (en bataille seulement).
```

- [ ] **Step 2 : spec, §6 « Peinture, territoire et synchronisation »**

2a. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
- **Grille** : la grille de cellules de 8 px existante (≈ 250 × 81 à 2000 px de large, seules les
  cellules opaques comptent).
```

par :

```markdown
- **Grille** : la grille de cellules de 8 px existante (250 colonnes à 2000 px de large, 23 à 40
  rangées selon la skyline, haute de 180 à 320 px ; seules les cellules opaques comptent).
```

2b. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
  - cellule adverse : `charge -= GAIN`. Si `charge <= 0`, la cellule passe au peintre avec
    `charge = -charge`, et le vol est compté dans les stats.
  - une cellule compte dans le score si `charge >= SEUIL_POSSESSION`.
  Les valeurs de `GAIN`, `CHARGE_MAX` et `SEUIL_POSSESSION` sont réglées pour qu'il faille à peu
  près autant de temps pour peindre une cellule qu'aujourd'hui en solo. Calcul entier et
  déterministe.
```

par :

```markdown
  - cellule adverse : `charge -= GAIN`. Si `charge <= 0`, la cellule passe au peintre avec
    `charge = -charge`.
  - une cellule compte dans le score si `charge >= SEUIL_POSSESSION`.
  - **vol** (statistique `cellules_volees`, comptée par les règles pendant la manche) : une
    cellule qui se met à compter pour le peintre alors qu'elle comptait en dernier pour un autre
    joueur. Deux lions qui se disputent une cellule que personne n'a encore possédée ne se volent
    donc rien (compté au passage de `charge <= 0`, chaque tampon de la dispute serait un vol).
  Les valeurs de `GAIN`, `CHARGE_MAX` et `SEUIL_POSSESSION` sont réglées pour qu'il faille à peu
  près autant de temps pour peindre une cellule qu'aujourd'hui en solo : `GAIN = 4` et
  `SEUIL_POSSESSION = 12`, soit 3 tampons sur une cellule vierge, ce qui suit la mesure du solo
  pour une gerbe en mouvement (16 à 46 px de rayon) ; `CHARGE_MAX = 24` : une cellule que son
  propriétaire repeint se renforce, et se vide alors en 6 tampons adverses. Calcul entier et
  déterministe (`Territoire`, phase 9).
```

- [ ] **Step 3 : feuille de route, ligne 9 coupée en 9 et 9 bis**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
| 9 | **Territoire** : logique pure de charge et de vol, grille de propriété dans la ville, tampons en cache par jeu de couleurs. | ➕ `Scripts/Territoire.gd` ✏️ `Scripts/Ville.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` | tests verts |
```

par :

```markdown
| 9 | **Territoire, logique** : `Territoire` (charge, prise, vol, seuil de possession, scores par joueur, liste des cellules changées), réglé sur la couverture du solo ; règles : vols comptés (`vol_de_cellules`), partie au territoire (`compte_le_territoire`) ; `DUREE_ETOILE` et `_manche_en_cours()` montent dans la base `Regles`. | ➕ `Scripts/Territoire.gd` ✏️ `Scripts/Regles.gd` ✏️ `Scripts/ReglesSolo.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `tests/unitaires.gd` | tests verts |
| 9 bis | **Territoire dans la ville** : tampons en cache par jeu de couleurs (obligatoire), la ville tient le territoire en bataille et le tamponne sur l'hôte, la traceuse peint pour son joueur ; `DUREE_INVULNERABILITE` descend dans `ReglesSolo`. | ✏️ `Scripts/Ville.gd` ✏️ `Scripts/GerbeTraceuse.gd` ✏️ `Scripts/GameState.gd` ✏️ `Scripts/ReglesSolo.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
```

- [ ] **Step 4 : feuille de route, points de vigilance reportés en 9 bis**

4a. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 9 (obligatoire)** : `Scripts/Ville.gd` met en cache ses tampons par (rayon, nombre de
```

par :

```markdown
- **phase 9 bis (obligatoire)** : `Scripts/Ville.gd` met en cache ses tampons par (rayon, nombre de
```

4b. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 9** : `Joueur.cellules_volees` existe depuis la phase 8 (remis à zéro par
  `reinitialiser`, jamais incrémenté) : le territoire l'incrémente quand un tampon vole une
  cellule. En bataille, les couleurs débloquées d'un joueur sont ses trois nuances (données par
  `Regles.couleurs_de_depart`) : c'est ce que reçoivent la traceuse et `Ville.peindre` ;
```

par :

```markdown
- **phases 9 et 9 bis** : `Joueur.cellules_volees` existe depuis la phase 8 (remis à zéro par
  `reinitialiser`, jamais incrémenté) : `Territoire.tamponner` renvoie les cellules que vole un
  tampon (phase 9), la ville de l'hôte les signale aux règles (`Regles.vol_de_cellules`, phase
  9 bis), qui l'incrémentent pendant la manche. En bataille, les couleurs débloquées d'un joueur
  sont ses trois nuances (données par `Regles.couleurs_de_depart`) : c'est ce que reçoivent la
  traceuse et `Ville.peindre` ;
```

- [ ] **Step 5 : Vérifier**

Run : `grep -n "250 × 81\|et le vol est compté dans les stats\|\`cellules\`, stats\|phase 9 (obligatoire)" docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
Expected : aucune ligne. Relire `git diff docs/` : seuls le spec et la feuille de route ont changé ; les deux plans sont nouveaux et intacts.

- [ ] **Step 6 : Commit**

```bash
git add docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md docs/superpowers/plans/2026-09-25-phase-09-territoire.md docs/superpowers/plans/2026-09-25-phase-09bis-ville.md
git commit -m "Plans des phases 9 et 9 bis (territoire, territoire dans la ville) ; spec : vol à la prise de possession, réglages, score tenu par le territoire, taille de la grille ; feuille de route : phase 9 coupée en 9 et 9 bis

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 1 : `Territoire`, logique pure

**Files:**
- Create: `Scripts/Territoire.gd` (et son `.uid` généré)
- Modify: `tests/unitaires.gd` (`_run`, nouvelle section `_tester_territoire` à la fin du fichier)

**Interfaces:**
- Consumes : `EtatPartie.NB_JOUEURS_MAX` (phase 8) ; la grille de la ville telle que `Ville._calculer_cellules_peignables` la calcule (un octet par cellule, rangée par rangée, 1 = peignable ; `Ville.TAILLE_CELLULE = 8`), branchée en phase 9 bis.
- Produces : `class_name Territoire extends RefCounted` ; constantes `GAIN = 4`, `SEUIL_POSSESSION = 12`, `CHARGE_MAX = 24`, `PERSONNE = -1` ; `Territoire.new(taille_grille: Vector2i, peignables: PackedByteArray, taille_cellule: int = 8)` ; `taille_grille`, `taille_cellule`, `nb_peignables` ; `reinitialiser()` ; `tamponner(index_joueur: int, centre: Vector2i, rayon: int) -> int` (cellules volées ; `centre` en pixels de la ville) ; `cellules_de(index_joueur: int) -> int` (`cellules_de(PERSONNE)` : celles qui ne comptent pour personne) ; `proprietaire_compte(cellule: int) -> int` ; `proprietaire(cellule: int) -> int` ; `charge(cellule: int) -> int` ; `extraire_changements() -> PackedInt32Array`.

- [ ] **Step 1 : `tests/unitaires.gd`, les vérifications**

1a. Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_facade_retiree()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_facade_retiree()
	_tester_territoire()
	print("== %d échec(s) ==" % _echecs)
```

1b. À la fin du fichier, dans `tests/unitaires.gd`, remplacer :

```gdscript
	_check(restes.is_empty(), "GameState n'expose plus l'état par joueur (restes : %s)" % [restes])
```

par :

```gdscript
	_check(restes.is_empty(), "GameState n'expose plus l'état par joueur (restes : %s)" % [restes])


func _tester_territoire() -> void:
	print("-- Territoire")
	# Grille de 4 × 3 cellules de 8 px, rangée par rangée ; la cellule 11 (colonne 3, rangée 2)
	# n'est pas peignable. La cellule 5 (colonne 1, rangée 1) a son centre en (12, 12) : un tampon
	# de 5 px qui y est centré ne touche qu'elle (le centre de ses voisines est à 8 px).
	var peignables := PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0])
	var centre_5 := Vector2i(12, 12)
	var n_prise := ceili(float(Territoire.SEUIL_POSSESSION) / Territoire.GAIN)
	var n_vider := ceili(float(Territoire.CHARGE_MAX) / Territoire.GAIN)
	_check(n_prise == 3 and n_vider == 6,
		"réglages : 3 tampons pour posséder une cellule vierge, 6 pour vider une cellule renforcée (%d, %d)" % [n_prise, n_vider])
	var t := Territoire.new(Vector2i(4, 3), peignables)
	_check(t.nb_peignables == 11 and t.cellules_de(0) == 0 and t.cellules_de(Territoire.PERSONNE) == 11
		and t.proprietaire(5) == Territoire.PERSONNE and t.extraire_changements().is_empty(),
		"un territoire neuf est vierge : 11 cellules peignables, qui ne comptent pour personne")

	# Peindre une cellule vierge : chargée au premier tampon, comptée au troisième
	_check(t.tamponner(0, centre_5, 5) == 0 and t.proprietaire(5) == 0 and t.charge(5) == Territoire.GAIN
		and t.cellules_de(0) == 0 and t.proprietaire_compte(5) == Territoire.PERSONNE,
		"un tampon sur une cellule vierge la charge pour le peintre, sans la faire compter encore")
	_check(range(12).all(func(i: int) -> bool: return i == 5 or t.charge(i) == 0),
		"le tampon ne touche que les cellules dont le centre est à moins de son rayon")
	for i in range(n_prise - 1):
		t.tamponner(0, centre_5, 5)
	_check(t.cellules_de(0) == 1 and t.proprietaire_compte(5) == 0 and t.cellules_de(Territoire.PERSONNE) == 10,
		"au troisième tampon, la cellule compte pour le peintre")
	_check(t.extraire_changements() == PackedInt32Array([5]) and t.extraire_changements().is_empty(),
		"la cellule qui se met à compter est listée une fois, et la liste se vide à la lecture")
	for i in range(10):
		t.tamponner(0, centre_5, 5)
	_check(t.charge(5) == Territoire.CHARGE_MAX and t.cellules_de(0) == 1 and t.extraire_changements().is_empty(),
		"repeinte par son propriétaire, la cellule se renforce jusqu'à CHARGE_MAX, sans nouveau changement")

	# Vol : l'adversaire vide la cellule, la prend, puis la possède
	var vols := 0
	for i in range(n_vider - 1):
		vols += t.tamponner(1, centre_5, 5)
	_check(t.proprietaire(5) == 0 and t.proprietaire_compte(5) == Territoire.PERSONNE and t.cellules_de(0) == 0
		and t.cellules_de(1) == 0 and vols == 0,
		"un adversaire décharge la cellule : sous le seuil, elle ne compte plus pour personne, mais reste au premier peintre")
	vols += t.tamponner(1, centre_5, 5)
	_check(t.proprietaire(5) == 1 and t.charge(5) == 0 and vols == 0, "vidée, la cellule passe à l'adversaire, sans charge et sans vol encore")
	for i in range(n_prise):
		vols += t.tamponner(1, centre_5, 5)
	_check(t.cellules_de(1) == 1 and t.proprietaire_compte(5) == 1 and vols == 1,
		"dès qu'elle compte pour lui, c'est un vol, compté une fois (%d)" % vols)
	_check(t.extraire_changements() == PackedInt32Array([5]), "la cellule volée est listée une fois, même passée par « personne »")
	for i in range(n_vider + n_prise):
		vols += t.tamponner(0, centre_5, 5)
	_check(t.proprietaire_compte(5) == 0 and vols == 2, "la reprendre à son voleur est aussi un vol")

	# Deux peintres qui se disputent une cellule vierge tampon après tampon
	var u := Territoire.new(Vector2i(4, 3), peignables)
	var vols_disputes := 0
	for i in range(20):
		vols_disputes += u.tamponner(0, centre_5, 5)
		vols_disputes += u.tamponner(1, centre_5, 5)
	_check(vols_disputes == 0 and u.cellules_de(0) == 0 and u.cellules_de(1) == 0,
		"deux peintres qui se disputent une cellule que personne n'a possédée ne se volent rien")

	# Bords et cellules non peignables
	u.tamponner(2, Vector2i(16, 12), 40)  # couvre toute la grille
	_check(u.charge(11) == 0 and u.proprietaire(11) == Territoire.PERSONNE and u.proprietaire(0) == 2,
		"une cellule non peignable ne change jamais")
	var w := Territoire.new(Vector2i(4, 3), peignables)
	w.tamponner(0, Vector2i(-2, 12), 8)
	_check(w.charge(4) == Territoire.GAIN and range(12).all(func(i: int) -> bool: return i == 4 or w.charge(i) == 0),
		"un tampon débordant à gauche ne touche que la première colonne, jamais la fin de la rangée précédente")
	_check(w.tamponner(3, Vector2i(5000, -5000), 46) == 0 and range(12).all(func(i: int) -> bool: return i == 4 or w.charge(i) == 0),
		"un tampon hors de la grille ne touche rien")
	w.reinitialiser()
	_check(w.charge(4) == 0 and w.proprietaire(4) == Territoire.PERSONNE and w.cellules_de(Territoire.PERSONNE) == 11
		and w.extraire_changements().is_empty(), "reinitialiser rend toute la ville vierge")

	# Déterminisme et scores, sur une suite de tampons pseudo-aléatoire à trois joueurs
	var grande := PackedByteArray()
	grande.resize(40 * 20)
	for i in range(grande.size()):
		grande[i] = 0 if i % 7 == 0 else 1
	var a := Territoire.new(Vector2i(40, 20), grande)
	var b := Territoire.new(Vector2i(40, 20), grande)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in range(600):
		var joueur := rng.randi_range(0, 2)
		var centre := Vector2i(rng.randi_range(-20, 340), rng.randi_range(-20, 180))
		var rayon := rng.randi_range(8, 46)
		a.tamponner(joueur, centre, rayon)
		b.tamponner(joueur, centre, rayon)
	var identiques := true
	var recompte := [0, 0, 0]
	for i in range(grande.size()):
		if a.proprietaire(i) != b.proprietaire(i) or a.charge(i) != b.charge(i):
			identiques = false
		var p := a.proprietaire_compte(i)
		if p != Territoire.PERSONNE:
			recompte[p] += 1
	_check(identiques, "mêmes tampons dans le même ordre, même territoire (calcul entier, déterministe)")
	_check(recompte == [a.cellules_de(0), a.cellules_de(1), a.cellules_de(2)] and recompte.all(func(n: int) -> bool: return n > 0)
		and a.cellules_de(Territoire.PERSONNE) + recompte[0] + recompte[1] + recompte[2] == a.nb_peignables,
		"les scores tenus tampon après tampon égalent un recompte complet (%s)" % [recompte])
	var liste := a.extraire_changements()
	var listees := {}
	for i in liste:
		listees[i] = true
	_check(listees.size() == liste.size()
		and range(grande.size()).all(func(i: int) -> bool: return a.proprietaire_compte(i) == Territoire.PERSONNE or listees.has(i)),
		"chaque cellule qui compte figure dans la liste des changements, une seule fois (%d)" % liste.size())

	# Coût : une seconde de bataille à 6 lions (60 tampons par lion) sur une grille de 250 × 81
	var pleine := PackedByteArray()
	pleine.resize(250 * 81)
	pleine.fill(1)
	var c := Territoire.new(Vector2i(250, 81), pleine)
	var debut := Time.get_ticks_usec()
	for i in range(360):
		c.tamponner(i % 6, Vector2i(rng.randi_range(0, 2000), rng.randi_range(0, 648)), 46)
	var ms := (Time.get_ticks_usec() - debut) / 1000.0
	_check(ms < 60.0, "360 tampons de 46 px (une seconde à 6 lions) coûtent %.1f ms au territoire (moins de 60 ms)" % ms)
```

Notes :
- La cellule 5 est au milieu d'une grille assez petite pour que chaque vérification porte sur toutes les cellules (`range(12).all(...)`).
- Le débordement à gauche : un tampon centré en x = -2 de 8 px de rayon atteint le centre de la cellule 4 (colonne 0, rangée 1, centre en (4, 12), à 6 px) ; une indexation qui ne borne pas les colonnes toucherait la cellule 3 (colonne 3, rangée 0), la « colonne -1 » de la rangée 1.
- `recompte.all(n > 0)` garantit que la suite pseudo-aléatoire a bien mis les trois joueurs en concurrence (27, 19 et 47 cellules au moment du plan, 446 cellules listées).
- Le seuil de coût (60 ms) laisse une marge de six fois la mesure (environ 9 ms sur le Mac de développement, avec le binaire de l'éditeur) pour la CI.

- [ ] **Step 2 : Lancer les tests unitaires (échec attendu)**

Run : `godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error"`, puis les tests unitaires avec délai.
Expected : `SCRIPT ERROR: Parse Error: Identifier "Territoire" not declared in the current scope.` (plusieurs lignes), et la suite ne se lance pas (pas de ligne `== … ==`).

- [ ] **Step 3 : `Scripts/Territoire.gd`**

Créer `Scripts/Territoire.gd` :

```gdscript
class_name Territoire
extends RefCounted
## Territoire d'une bataille (spec §6), sur la grille de cellules de la ville : chaque cellule
## peignable a un propriétaire et une charge. Un tampon charge les cellules vierges et celles du
## peintre, décharge celles des autres joueurs et les leur prend quand leur charge tombe à zéro ;
## une cellule compte pour son propriétaire à partir de SEUIL_POSSESSION. Une cellule qui se met
## à compter pour un joueur alors qu'elle comptait en dernier pour un autre est un vol. Calcul
## entier et déterministe (les mêmes tampons dans le même ordre donnent le même territoire), fait
## par l'hôte seulement. Logique pure : ne nomme aucun autoload, ce qui permet de la tester dans
## un test `--script`.
##
## Les joueurs sont désignés par leur index (0 à 5, `Joueur.index`). En mémoire, le propriétaire
## tient sur un octet, décalé de un : 0 = personne, 1 à 6 = joueurs 0 à 5 (le format réseau du
## spec §6).

## Charge qu'un tampon donne à une cellule vierge ou du peintre, et retire à une cellule adverse.
const GAIN := 4
## Charge à partir de laquelle une cellule compte pour son propriétaire : 3 tampons sur une
## cellule vierge, ce qui suit la mesure de couverture du solo pour une gerbe en mouvement.
const SEUIL_POSSESSION := 12
## Une cellule repeinte par son propriétaire se renforce jusqu'à CHARGE_MAX : la vider demande
## alors 6 tampons adverses, et il en faut 3 de plus pour qu'elle compte pour le voleur.
const CHARGE_MAX := 24
const PERSONNE := -1

var taille_grille: Vector2i
var taille_cellule: int
## Nombre de cellules peignables : le total d'un score en pourcentage.
var nb_peignables := 0

var _peignables: PackedByteArray
var _proprietaires: PackedByteArray   # 0 = personne, 1 à 6 = index du joueur + 1
var _charges: PackedByteArray
var _cellules: PackedInt32Array       # cellules qui comptent, par propriétaire (0 : pour personne)
var _dernier_compte: PackedByteArray  # dernier propriétaire pour qui la cellule a compté (0 : aucun)
var _changee: PackedByteArray         # 1 = déjà dans _changements
var _changements: PackedInt32Array


## `peignables` : un octet par cellule, rangée par rangée (1 = peignable), comme la ville le
## calcule ; `taille_cellule` en pixels de la ville.
func _init(taille_grille_: Vector2i, peignables: PackedByteArray, taille_cellule_: int = 8) -> void:
	assert(peignables.size() == taille_grille_.x * taille_grille_.y, "une valeur de peignable par cellule")
	taille_grille = taille_grille_
	taille_cellule = taille_cellule_
	_peignables = peignables
	nb_peignables = peignables.count(1)
	var nb := peignables.size()
	_proprietaires.resize(nb)
	_charges.resize(nb)
	_dernier_compte.resize(nb)
	_changee.resize(nb)
	_cellules.resize(EtatPartie.NB_JOUEURS_MAX + 1)
	reinitialiser()


## Toute la ville redevient vierge (nouvelle manche), sans changement à synchroniser.
func reinitialiser() -> void:
	_proprietaires.fill(0)
	_charges.fill(0)
	_dernier_compte.fill(0)
	_changee.fill(0)
	_cellules.fill(0)
	_cellules[0] = nb_peignables
	_changements.clear()


## Applique le tampon du joueur `index_joueur`, centré en `centre` (pixels de la ville), de rayon
## `rayon` : il touche les cellules peignables dont le centre est à moins de `rayon`. Renvoie le
## nombre de cellules que ce tampon vole (elles se mettent à compter pour le peintre alors
## qu'elles comptaient en dernier pour un autre joueur) : deux peintres qui se disputent une
## cellule que personne n'a encore possédée ne se volent rien. Coût mesuré au moment du plan :
## environ 25 µs pour un tampon de 46 px.
func tamponner(index_joueur: int, centre: Vector2i, rayon: int) -> int:
	assert(index_joueur >= 0 and index_joueur < EtatPartie.NB_JOUEURS_MAX, "index de joueur de 0 à 5")
	if rayon <= 0:
		return 0
	var peintre := index_joueur + 1
	var demi := taille_cellule / 2
	var r2 := rayon * rayon
	# Colonnes et rangées bornées à la grille : un tampon qui déborde à gauche ne touche jamais
	# la fin de la rangée précédente.
	var cx_min := maxi(0, (centre.x - rayon) / taille_cellule)
	var cx_max := mini(taille_grille.x - 1, (centre.x + rayon) / taille_cellule)
	var cy_min := maxi(0, (centre.y - rayon) / taille_cellule)
	var cy_max := mini(taille_grille.y - 1, (centre.y + rayon) / taille_cellule)
	var volees := 0
	for cy in range(cy_min, cy_max + 1):
		var dy := cy * taille_cellule + demi - centre.y
		var reste := r2 - dy * dy
		if reste <= 0:
			continue
		var ligne := cy * taille_grille.x
		for cx in range(cx_min, cx_max + 1):
			var dx := cx * taille_cellule + demi - centre.x
			if dx * dx >= reste:
				continue
			var i := ligne + cx
			if _peignables[i] == 0:
				continue
			var proprietaire_ := _proprietaires[i]
			var charge_ := _charges[i]
			var compte_avant := proprietaire_ if charge_ >= SEUIL_POSSESSION else 0
			if proprietaire_ == peintre or proprietaire_ == 0:
				proprietaire_ = peintre
				charge_ = mini(charge_ + GAIN, CHARGE_MAX)
			else:
				charge_ -= GAIN
				if charge_ <= 0:
					proprietaire_ = peintre
					charge_ = -charge_
			_proprietaires[i] = proprietaire_
			_charges[i] = charge_
			var compte_apres := proprietaire_ if charge_ >= SEUIL_POSSESSION else 0
			if compte_apres == compte_avant:
				continue
			_cellules[compte_avant] -= 1
			_cellules[compte_apres] += 1
			if compte_apres != 0:
				var dernier := _dernier_compte[i]
				if dernier != 0 and dernier != compte_apres:
					volees += 1
				_dernier_compte[i] = compte_apres
			if _changee[i] == 0:
				_changee[i] = 1
				_changements.append(i)
	return volees


## Cellules qui comptent pour le joueur `index_joueur` : son score. `cellules_de(PERSONNE)` :
## les cellules peignables qui ne comptent pour personne.
func cellules_de(index_joueur: int) -> int:
	return _cellules[index_joueur + 1]


## Index du joueur pour qui la cellule compte, PERSONNE si elle ne compte pour personne.
func proprietaire_compte(cellule: int) -> int:
	return _proprietaires[cellule] - 1 if _charges[cellule] >= SEUIL_POSSESSION else PERSONNE


## Index du dernier joueur qui a chargé la cellule (qu'elle compte ou non), PERSONNE si elle est
## vierge.
func proprietaire(cellule: int) -> int:
	return _proprietaires[cellule] - 1


func charge(cellule: int) -> int:
	return _charges[cellule]


## Cellules dont le propriétaire compté a changé depuis le dernier appel, chacune une fois, dans
## l'ordre de leur premier changement (synchronisation des scores, phase 14) ; vide la liste.
## Une cellule revenue à son propriétaire compté d'avant y figure quand même : la renvoyer est
## sans effet.
func extraire_changements() -> PackedInt32Array:
	var liste := _changements
	_changements = PackedInt32Array()
	for i in liste:
		_changee[i] = 0
	return liste
```

Notes :
- Division entière et négatifs : GDScript tronque vers zéro (`-3 / 8 == 0`), ce qui peut élargir le carré parcouru d'une colonne ou d'une rangée, jamais le rétrécir ; le test de distance fait foi, et `maxi` / `mini` bornent à la grille.
- `proprietaire_` et `charge_` (et non `proprietaire` et `charge`) : les méthodes du même nom existent.
- `_cellules[0]` compte les cellules peignables qui ne comptent pour personne : la somme des scores et de `cellules_de(PERSONNE)` vaut toujours `nb_peignables` (vérifié par le recompte).
- `extraire_changements` rend le tableau tel quel et en repart un vide : un `PackedInt32Array` se copie à l'écriture, la liste rendue ne bouge plus.

- [ ] **Step 4 : Vérifier**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` (aucune ligne), puis les tests unitaires avec délai : `== 0 échec(s) ==`, sans `SCRIPT ERROR`, avec les 21 vérifications de « -- Territoire » (`✅`), la dernière donnant le coût mesuré. Le smoke test (inchangé) une fois : vert.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Territoire.gd Scripts/Territoire.gd.uid tests/unitaires.gd
git commit -m "Territoire : propriétaire et charge par cellule, prise, vol à la possession, seuil de 3 tampons, scores par joueur, liste des cellules changées ; calcul entier et déterministe

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 2 : règles du territoire ; `DUREE_ETOILE` et `_manche_en_cours()` dans la base

**Files:**
- Modify: `tests/unitaires.gd` (`_tester_regles_solo`, `_tester_regles_bataille`)
- Modify: `Scripts/Regles.gd`
- Modify: `Scripts/ReglesSolo.gd`
- Modify: `Scripts/ReglesBataille.gd`

**Interfaces:**
- Consumes : `Joueur.cellules_volees` (phase 8), `partie.partie_en_cours` et `partie.pret` (`EtatPartie`).
- Produces : `Regles.DUREE_ETOILE := 8.0` (la constante de `ReglesSolo` disparaît ; `ReglesSolo.DUREE_ETOILE` reste lisible, héritée) ; `Regles.compte_le_territoire() -> bool` (faux ; vrai dans `ReglesBataille`) ; `Regles.vol_de_cellules(voleur: Joueur, nb: int)` (sans effet ; `ReglesBataille` ajoute `nb` à `voleur.cellules_volees` pendant la manche) ; `Regles._manche_en_cours() -> bool` (partie en cours et intro finie), utilisé par `ReglesSolo.lion_touche_par_ennemi` et par `ReglesBataille`, qui perd sa copie.

- [ ] **Step 1 : `tests/unitaires.gd`, les vérifications**

1a. Dans `_tester_regles_solo()`, dans `tests/unitaires.gd`, remplacer :

```gdscript
	base.lion_touche_par_vomi(j, autre, Vector2.ZERO)
	base.choc_entre_lions(j, autre)
	_check(base.couleurs_de_depart(j).is_empty() and not j.est_etourdi() and not j.est_invulnerable()
		and autre.etourdissements_infliges == 0 and j.chocs == 0 and autre.chocs == 0,
		"sans règles de mode, ni couleur de départ, ni effet du vomi ou des chocs")
```

par :

```gdscript
	base.lion_touche_par_vomi(j, autre, Vector2.ZERO)
	base.choc_entre_lions(j, autre)
	base.vol_de_cellules(j, 4)
	_check(base.couleurs_de_depart(j).is_empty() and not j.est_etourdi() and not j.est_invulnerable()
		and autre.etourdissements_infliges == 0 and j.chocs == 0 and autre.chocs == 0 and j.cellules_volees == 0,
		"sans règles de mode, ni couleur de départ, ni effet du vomi, des chocs ou des vols")
	_check(not base.compte_le_territoire() and not ReglesSolo.new(gs).compte_le_territoire(),
		"ni les règles de base ni celles du solo ne se jouent au territoire")
```

1b. Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_check(j.bonus_actif() and is_equal_approx(j.bonus_restant, ReglesSolo.DUREE_ETOILE), "l'étoile active la gerbe XXL pour DUREE_ETOILE secondes")
```

par :

```gdscript
	_check(j.bonus_actif() and is_equal_approx(j.bonus_restant, Regles.DUREE_ETOILE), "l'étoile active la gerbe XXL pour DUREE_ETOILE secondes")
```

1c. Dans `_tester_regles_bataille()`, dans `tests/unitaires.gd`, remplacer :

```gdscript
	_check(bleu.bonus_actif() and is_equal_approx(bleu.bonus_restant, ReglesSolo.DUREE_ETOILE), "l'étoile XXL est celle du solo")
```

par :

```gdscript
	_check(bleu.bonus_actif() and is_equal_approx(bleu.bonus_restant, Regles.DUREE_ETOILE), "l'étoile XXL est celle du solo (même durée, constante de la base)")
```

1d. Dans `tests/unitaires.gd`, remplacer :

```gdscript
	r.progression_mesuree(1.0)
	_check(fins.is_empty() and gs.partie_en_cours, "peindre toute la ville ne termine pas la manche (elle finit au chrono)")
	gs.terminer_partie(false)
```

par :

```gdscript
	r.progression_mesuree(1.0)
	_check(fins.is_empty() and gs.partie_en_cours, "peindre toute la ville ne termine pas la manche (elle finit au chrono)")

	# Territoire : la bataille s'y joue, les vols comptent pour « Le voleur »
	_check(r.compte_le_territoire(), "la bataille se joue au territoire")
	r.vol_de_cellules(rouge, 5)
	r.vol_de_cellules(rouge, 0)
	_check(rouge.cellules_volees == 5 and bleu.cellules_volees == 0, "les cellules volées comptent pour le voleur seul (%d)" % rouge.cellules_volees)
	gs.pret = false
	r.vol_de_cellules(rouge, 2)
	_check(rouge.cellules_volees == 5, "un vol pendant l'intro ne compte pas")
	gs.pret = true
	gs.terminer_partie(false)
```

1e. Dans `tests/unitaires.gd`, remplacer :

```gdscript
	r.choc_entre_lions(rouge, bleu)
	_check(not bleu.est_etourdi() and bleu.chocs == 1 and rouge.etourdissements_infliges == etourdissements_avant,
		"après la fin de manche, plus d'étourdissement (ennemi ou vomi) ni de choc compté")
```

par :

```gdscript
	r.choc_entre_lions(rouge, bleu)
	r.vol_de_cellules(rouge, 3)
	_check(not bleu.est_etourdi() and bleu.chocs == 1 and rouge.etourdissements_infliges == etourdissements_avant
		and rouge.cellules_volees == 5,
		"après la fin de manche, plus d'étourdissement (ennemi ou vomi), de choc ni de vol compté")
```

- [ ] **Step 2 : Lancer les tests unitaires (échec attendu)**

Run : les tests unitaires avec délai.
Expected : `SCRIPT ERROR: Parse Error: Cannot find member "DUREE_ETOILE" in base "Regles".` (deux fois), puis `ERROR: Failed to load script "res://tests/unitaires.gd" with error "Parse error".` : la suite ne se lance pas. L'analyseur s'arrête à la première erreur de chaque fonction ; `vol_de_cellules` et `compte_le_territoire`, introuvables eux aussi, ne sont signalés qu'une fois la constante montée.

- [ ] **Step 3 : `Scripts/Regles.gd`**

3a. Dans `Scripts/Regles.gd`, remplacer :

```gdscript
## l'hôte (en solo, le poste est son propre hôte).

## État de la partie
```

par :

```gdscript
## l'hôte (en solo, le poste est son propre hôte).

## Durée de la gerbe XXL donnée par une étoile, la même en solo et en bataille.
const DUREE_ETOILE := 8.0

## État de la partie
```

3b. Dans `Scripts/Regles.gd`, remplacer :

```gdscript
func couleurs_de_depart(_joueur: Joueur) -> Array[Color]:
	return []
```

par :

```gdscript
func couleurs_de_depart(_joueur: Joueur) -> Array[Color]:
	return []


## Vrai si la partie se joue au territoire (bataille) : la ville tient alors, en plus de sa
## mesure de couverture, une grille de propriété (`Territoire`) qui compte les cellules de
## chaque joueur. Lu par la ville quand elle charge sa skyline.
func compte_le_territoire() -> bool:
	return false
```

3c. Dans `Scripts/Regles.gd`, remplacer :

```gdscript
## La ville vient de mesurer la part peinte (0 à 1).
func progression_mesuree(_ratio: float) -> void:
	pass
```

par :

```gdscript
## La ville vient de mesurer la part peinte (0 à 1).
func progression_mesuree(_ratio: float) -> void:
	pass


## Un tampon du lion de `voleur` vient de lui faire posséder `nb` cellules (au moins une) qui
## comptaient en dernier pour d'autres joueurs (territoire, bataille). Signalé par la ville de
## l'hôte, une fois par tampon.
func vol_de_cellules(_voleur: Joueur, _nb: int) -> void:
	pass


## Vrai pendant le jeu proprement dit : partie en cours et intro « Prêt ? Vomissez ! » finie.
func _manche_en_cours() -> bool:
	return partie.partie_en_cours and partie.pret
```

- [ ] **Step 4 : `Scripts/ReglesSolo.gd`**

4a. Dans `Scripts/ReglesSolo.gd`, remplacer :

```gdscript
## victoire quand la ville est peinte au seuil de la difficulté.

## Durée de la gerbe XXL donnée par une étoile.
const DUREE_ETOILE := 8.0


func _init(partie_: EtatPartie) -> void:
```

par :

```gdscript
## victoire quand la ville est peinte au seuil de la difficulté. La durée de l'étoile XXL est
## celle de la base (`Regles.DUREE_ETOILE`).


func _init(partie_: EtatPartie) -> void:
```

4b. Dans `Scripts/ReglesSolo.gd`, remplacer :

```gdscript
	if not partie.partie_en_cours or not partie.pret or joueur.est_invulnerable():
```

par :

```gdscript
	if not _manche_en_cours() or joueur.est_invulnerable():
```

(`etoile_ramassee` lit toujours `DUREE_ETOILE` : c'est désormais la constante héritée. `progression_mesuree` garde son `partie.partie_en_cours` seul, sans `pret` : ce n'est pas le même garde-fou, et le solo ne change pas.)

- [ ] **Step 5 : `Scripts/ReglesBataille.gd`**

5a. Dans `Scripts/ReglesBataille.gd`, remplacer :

```gdscript
## pastille donne un cran de gerbe ; l'étoile XXL est celle du solo. Le territoire (phase 9) et
## la fin de manche au chrono (phase 17) s'y ajouteront.
```

par :

```gdscript
## pastille donne un cran de gerbe ; l'étoile XXL est celle du solo. La manche se joue au
## territoire, que tient la ville (`Territoire`) : les règles en comptent les vols. La fin de
## manche au chrono (phase 17) s'y ajoutera.
```

5b. Dans `Scripts/ReglesBataille.gd`, remplacer :

```gdscript
func couleurs_de_depart(joueur: Joueur) -> Array[Color]:
	return joueur.nuances()
```

par :

```gdscript
func couleurs_de_depart(joueur: Joueur) -> Array[Color]:
	return joueur.nuances()


func compte_le_territoire() -> bool:
	return true
```

5c. Dans `Scripts/ReglesBataille.gd`, remplacer :

```gdscript
	joueur.activer_bonus(ReglesSolo.DUREE_ETOILE)


# coeur_ramasse et progression_mesuree : ceux de la base, sans effet (aucun cœur en bataille,
# la manche se termine au chrono).


func _manche_en_cours() -> bool:
	return partie.partie_en_cours and partie.pret
```

par :

```gdscript
	joueur.activer_bonus(DUREE_ETOILE)


## Les cellules volées comptent pour le titre « Le voleur » (écran Résultats), pendant la manche.
func vol_de_cellules(voleur: Joueur, nb: int) -> void:
	if nb > 0 and _manche_en_cours():
		voleur.cellules_volees += nb


# coeur_ramasse et progression_mesuree : ceux de la base, sans effet (aucun cœur en bataille,
# la manche se termine au chrono).
```

(`choc_entre_lions` et `_peut_etre_etourdi` appellent toujours `_manche_en_cours()`, désormais celui de la base.)

- [ ] **Step 6 : Vérifier**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` (aucune ligne), les tests unitaires avec délai : `== 0 échec(s) ==`, sans `SCRIPT ERROR`, avec les 4 nouvelles vérifications (« ni les règles de base ni celles du solo ne se jouent au territoire », « la bataille se joue au territoire », « les cellules volées comptent pour le voleur seul (5) », « un vol pendant l'intro ne compte pas ») et les 4 vérifications complétées. Puis le smoke test (inchangé) une fois : `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR` (il lit encore `ReglesSolo.DUREE_ETOILE`, héritée ; la phase 9 bis le passe à `Regles.DUREE_ETOILE`).

Run enfin : `grep -n "const DUREE_ETOILE\|func _manche_en_cours\|partie_en_cours and partie.pret" Scripts/Regles*.gd`
Expected : trois lignes, toutes dans `Scripts/Regles.gd` (la constante, la fonction et son corps) : plus de copie dans `ReglesSolo` ni dans `ReglesBataille`.

- [ ] **Step 7 : Commit**

```bash
git add tests/unitaires.gd Scripts/Regles.gd Scripts/ReglesSolo.gd Scripts/ReglesBataille.gd
git commit -m "Règles : vols de cellules comptés pendant la manche, partie au territoire en bataille ; DUREE_ETOILE et _manche_en_cours() montent dans la base

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 3 : feuille de route, point de vigilance soldé par la phase 9

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`

**Ne jamais modifier le fichier du plan** (ce fichier, ni celui de la phase 9 bis) : seule la feuille de route change ici.

- [ ] **Step 1 : le point « la prochaine phase qui touche `Regles.gd`… »**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **la prochaine phase qui touche `Regles.gd`, `ReglesSolo.gd` et `ReglesBataille.gd`** :
  `ReglesBataille.etoile_ramassee` lit `ReglesSolo.DUREE_ETOILE` : les règles de
  bataille ne devraient pas dépendre des règles du solo. Monter `DUREE_ETOILE` dans la base
  `Regles`. De même, `ReglesSolo` répète en ligne le garde-fou
  `partie.partie_en_cours and partie.pret` que `ReglesBataille._manche_en_cours()` a déjà nommé :
  monter `_manche_en_cours()` dans la base `Regles` et le faire utiliser par les deux. Une fois que
  `Scripts/Lion.gd` ne lira plus directement `GameState.DUREE_INVULNERABILITE` (pour le nombre de
  clignotements), descendre cette constante de `GameState` vers `ReglesSolo`, seule règle qui s'en
  sert encore ;
```

par :

```markdown
- **phase 9 bis** : `Scripts/Lion.gd` ne lit plus `GameState.DUREE_INVULNERABILITE` (il clignote
  sur `joueur.invulnerable_restant` depuis la phase 8 bis) : descendre cette constante de
  `GameState` vers `ReglesSolo`, seule règle qui s'en sert encore (`DUREE_ETOILE` et
  `_manche_en_cours()` sont dans la base `Regles` depuis la phase 9) ;
```

- [ ] **Step 2 : Vérifier et committer**

Run : `grep -n "la prochaine phase qui touche" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
Expected : aucune ligne.

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
git commit -m "Feuille de route : DUREE_ETOILE et _manche_en_cours() soldés par la phase 9, DUREE_INVULNERABILITE en 9 bis

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

## Sortie de phase

- Les deux suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR`, localement puis en CI sur la PR ; la ligne de coût du territoire bien sous 60 ms en CI aussi (la relever dans le journal du job).
- `git diff main --stat` : 5 fichiers de code (`Scripts/Territoire.gd`, `Scripts/Regles.gd`, `Scripts/ReglesSolo.gd`, `Scripts/ReglesBataille.gd`, `tests/unitaires.gd`), le `.uid` de `Territoire` et la documentation. `Scripts/Ville.gd`, `Scripts/GerbeTraceuse.gd` et `tests/smoke_test.gd` sont intacts.
- `grep -rn "Territoire\|vol_de_cellules\|compte_le_territoire" Scripts | grep -v "^Scripts/Territoire.gd\|^Scripts/Regles"` : aucune ligne (rien ne branche encore le territoire).
- `grep -nE "GameState|Audio|Parametres|Scores" Scripts/Territoire.gd` : aucune ligne (logique pure).
- Rappeler à l'utilisateur la suite : la phase 9 bis (`docs/superpowers/plans/2026-09-25-phase-09bis-ville.md`) branche le territoire dans la ville, corrige le cache des tampons (point obligatoire) et descend `DUREE_INVULNERABILITE` ; les réglages du territoire sont à revoir sur une vraie manche en phase 10.
