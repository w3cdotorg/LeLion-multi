# Phase 8 : règles et état de la bataille, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** la logique de la bataille existe et est testée sans réseau ni scène de bataille : `ReglesBataille` (étourdissement de 1,5 s par le vomi d'un autre lion, de 2,5 s par un ennemi, puis 1 s d'immunité ; un cran de gerbe par pastille ; chocs comptés ; ni vies ni cœurs), un `Joueur` qui porte crans, étourdissement, nuances et statistiques, et la mise en place d'un mode sur `GameState` (`configurer_solo()` / `configurer_bataille(n)`), à appeler avant le chargement de la scène de jeu. **Le solo reste strictement identique** : aucune ligne de `ReglesSolo`, du lion ni des scènes ne change dans cette phase.

**Architecture:** une seule minuterie de protection : l'`invulnerable_restant` du solo **est** l'immunité de la bataille. `Joueur.etourdir(duree, duree_immunite, …)` règle `etourdi_restant = duree` et `invulnerable_restant = duree + duree_immunite`, puis émet `etourdi(origine, barbouillage)` ; `avancer` émet `etourdissement_fini` quand l'étourdissement tombe à zéro, l'immunité continue seule. Les règles de bataille ignorent un joueur étourdi ou invulnérable, ce qui règle aussi le peintre qui signale son contact à chaque frame. La base `Regles` gagne trois événements sans effet (`couleurs_de_depart`, `lion_touche_par_vomi`, `choc_entre_lions`) ; `GameState.nouvelle_partie()` réinitialise chaque joueur avec `regles.couleurs_de_depart(j)` : aucune couleur en solo, les trois nuances du joueur en bataille. Un joueur de bataille a donc dès le départ ses trois nuances comme couleurs débloquées, et le lion, sa gerbe et sa traceuse, qui lisent déjà `couleurs_debloquees`, vomiront et peindront dans ces nuances sans autre changement (phase 8 bis). `configurer_bataille(n)` redimensionne `joueurs` en place (le joueur 0, auquel `Audio` est abonné, reste le même objet) et donne à chacun son index et la couleur de `PALETTE_BATAILLE`.

**Tech Stack:** Godot 4.7.2, GDScript, tests unitaires headless.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§2 décisions, §3.1 `Joueur` et `Regles`, §5 « Lion ») · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (phase 8 ; points de vigilance mis à jour dans le commit de ce plan, Task 0) · suite : `docs/superpowers/plans/2026-09-25-phase-08bis-lion.md`

## Découpage : phase 8 et phase 8 bis

La ligne 8 de la feuille de route (Joueur, Lion, Lion.tscn, ReglesBataille, tests unitaires) ne tient pas en 5 fichiers une fois comptés tout ce qu'elle demande : la mise en place des modes (`GameState`), les nouveaux événements de la base (`Regles`), le cran du solo (`ReglesSolo`) et le smoke test des comportements du lion. Elle est coupée en deux phases de 5 fichiers, chacune testable et fusionnable seule :

| Phase | Objet | Fichiers |
|---|---|---|
| **8** (ce plan) | Règles et état : logique pure, tests unitaires | ✏️ `Scripts/Joueur.gd` ✏️ `Scripts/Regles.gd` ➕ `Scripts/ReglesBataille.gd` ✏️ `Scripts/GameState.gd` ✏️ `tests/unitaires.gd` |
| **8 bis** | Lion de bataille : rayon selon les crans (le solo gagne un cran par couleur), étourdissement visible, zones de contact, auto-tamponneuses | ✏️ `Scripts/ReglesSolo.gd` ✏️ `tests/unitaires.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scenes/Lion.tscn` ✏️ `tests/smoke_test.gd` |

À la fin de la phase 8, rien n'appelle encore `ReglesBataille` ni `configurer_bataille` hors des tests : le jeu est inchangé.

Hors des deux phases, reportés dans la feuille de route (Task 0) : le son « boing » des chocs (**17 bis**, il faut synthétiser un son : `tools/generer_sons.py`, `Assets/Sons/boing.wav`, `Audio.gd`, `Lion.gd`), le passage des gestionnaires de contact à `body is Lion` (**8 ter** pour les trois ennemis, **14 bis** pour les trois pastilles : six fichiers de gestionnaires et leurs bases ne tiennent pas dans une phase), et le branchement de `configurer_solo()` / `configurer_bataille(n)` dans le parcours (**phase 10**, avec la première scène de bataille).

## Écarts assumés

1. **Pas de champ `immunite_restante`** (spec §3.1) : l'immunité de la bataille est l'`invulnerable_restant` du solo (point de vigilance « réconcilier… plutôt que d'ajouter un mécanisme parallèle »). La durée vient des règles : 1,5 s après un coup en solo (inchangé), l'étourdissement plus 1 s en bataille. Le spec est corrigé (Task 0).
2. **Les trois nuances sont les couleurs débloquées du joueur de bataille**, données au départ de chaque partie par `Regles.couleurs_de_depart` (spec §5 « Gerbe » : « 3 émetteurs (nuances du joueur) »). La réinitialisation reste silencieuse : ni son de pastille (`Audio`), ni pastille programmée (`Spawner`). Aucune nouvelle méthode « couleurs de gerbe » n'est nécessaire, et `GerbeTraceuse.gd` ne change pas. Nuances : `couleur.darkened(0.35)`, `couleur`, `couleur.lightened(0.35)`.
3. **Palette provisoire dans `GameState`** (`PALETTE_BATAILLE`, les six couleurs de la planche de la phase 7) : `configurer_bataille(n)` doit donner une couleur à chaque joueur, et il n'existe pas encore de salon. La phase 11 garde cette constante unique, l'attribue au salon et règle ses luminosités (vigilance mise à jour). `configurer_bataille` ne touche pas aux pseudos (salon, phase 13).
4. **`cellules_volees` est déclaré dès maintenant** dans `Joueur` (remis à zéro, jamais incrémenté) : la phase 9 le compte depuis le territoire sans avoir à rouvrir `Joueur.gd`.
5. **Mode choisi par `configurer_*`, pas par un indicateur** : il n'y a pas de `GameState.mode`. Les règles branchées et la couleur des joueurs suffisent (le lion teste `joueur.a_une_couleur()` depuis la phase 7).

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations.
- Solo strictement identique : `ReglesSolo.gd`, `Lion.gd`, les scènes et le smoke test ne changent pas ; le smoke test reste vert tel quel.
- Fichiers de la phase (5) : ✏️ `Scripts/Joueur.gd`, ✏️ `Scripts/Regles.gd`, ➕ `Scripts/ReglesBataille.gd`, ✏️ `Scripts/GameState.gd`, ✏️ `tests/unitaires.gd`. Le `Scripts/ReglesBataille.gd.uid` généré est commité avec le script, hors plafond.
- **Toujours lancer un test Godot avec un délai maximal** (une erreur de script bloque le processus headless), et chercher `SCRIPT ERROR` et `SHADER ERROR` dans la sortie (une erreur dans une fonction appelée ne change pas le code de sortie, la suite peut finir sur `== 0 échec(s) ==` malgré elle) :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/unitaires.gd; ( godot --headless --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|SHADER ERROR|== " "$TMPDIR/t.log"`
  (`T=tests/smoke_test.gd` pour le smoke test ; une suite qui passe n'affiche que ses deux lignes `== … ==`). Un « resources still in use at exit » final est le bruit connu.
- Après la création de `ReglesBataille.gd` (`class_name`) : `godot --headless --import .` avant les tests, sinon le cache des classes globales ne la connaît pas.
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : `ReglesBataille.gd` ne nomme aucun autoload (il reçoit l'état de partie par `partie: EtatPartie`, comme `ReglesSolo`), et les tests continuent d'atteindre `GameState` par `root.get_node("GameState")`.
- Le smoke test n'est pas modifié : un passage vert suffit (la règle des 5 passages vaut pour toute modification du smoke test).
- Commits en français, terminés par la ligne `Co-Authored-By:` qu'impose l'environnement de l'auteur du commit.

## Review Focus

1. **Une seule minuterie de protection** : `etourdir` couvre l'étourdissement **et** l'immunité par `invulnerable_restant` ; `avancer` signale une seule fois la fin de l'étourdissement ; le solo (`encaisser_coup`, 1,5 s) est inchangé. → vérifications « étourdi 1,5 s, et invulnérable pendant l'étourdissement puis 1 s d'immunité », « la fin de l'étourdissement est signalée… », « l'immunité s'arrête… » (Task 1) + les tests solo existants.
2. **Pas de ré-étourdissement sans fin** : dix contacts de suite (le peintre signale le sien à chaque frame, la gerbe fera de même) ne donnent qu'un étourdissement ; un joueur immunisé est ignoré ; un agresseur étourdi n'étourdit personne ; rien pendant l'intro ni après la fin de manche. → Task 2.
3. **Mise en place des modes** : en place (même tableau `joueurs`, même joueur 0, auquel `Audio` est abonné), bataille puis solo rend `ReglesSolo`, un seul joueur, sans couleur ; une nouvelle partie de bataille donne à chacun un cran et ses trois nuances, en silence. → Task 3.
4. **Solo inchangé** : `nouvelle_partie` en solo ne donne aucune couleur de départ ; smoke test vert sans modification. → Task 3, Step 5.
5. **Contrat de la base `Regles`** : les nouveaux événements sont sans effet dans la base ; `ReglesBataille` les redéfinit avec les mêmes signatures ; `ReglesBataille.gd` ne nomme aucun autoload. → Task 2 + relecture.

---

### Task 0 : documentation (commit de ce plan et de celui de la phase 8 bis)

**Files:**
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
- Create: `docs/superpowers/plans/2026-09-25-phase-08-bataille.md` (ce plan)
- Create: `docs/superpowers/plans/2026-09-25-phase-08bis-lion.md` (plan de la phase 8 bis)

Les documents ne comptent pas dans le plafond de 5 fichiers. Les deux plans sont déjà écrits : les committer tels quels. **Ne jamais modifier le fichier du plan** (ni celui-ci ni celui de la phase 8 bis : ni réécriture, ni résumé) ; seuls le spec et la feuille de route sont édités ici.

- [ ] **Step 1 : spec, §2 « Décisions de jeu »**

Remplacer la ligne :

```markdown
| Pastilles de couleur | Donnent **+1 cran de gerbe** (1 à 7 crans, rayon 16 à 46 px, formule actuelle). Départ à 1 cran. Premier arrivé, premier servi. |
```

par :

```markdown
| Pastilles de couleur | Donnent **+1 cran de gerbe** (1 à 7 crans ; rayon de peinture de 16 px au premier cran, 5 px de plus par cran, 46 px au septième). Départ à 1 cran. Premier arrivé, premier servi. En solo, chaque couleur débloquée donne aussi un cran : les rayons du solo ne changent pas. |
```

- [ ] **Step 2 : spec, §3.1 « Unités »**

2a. Ligne `Joueur` : remplacer `` `etourdi_restant`, `immunite_restante`, `cellules`, stats (étourdissements infligés, cellules volées, chocs).`` par `` `etourdi_restant`, `invulnerable_restant` (l'immunité : une seule minuterie pour le solo et la bataille, voir §5), `cellules`, stats (`etourdissements_infliges`, `cellules_volees`, `chocs`).``

2b. Ligne `Lion` : remplacer `Lit un `Joueur` et une `Commandes`. Ne connaît ni les règles ni le réseau.` par `Lit un `Joueur` et une `Commandes`. Ne décide de rien : sur l'hôte, il signale aux `Regles` les lions que touche sa gerbe et ceux qu'il percute, comme les ennemis et les pastilles.`

2c. Ligne `Regles` : remplacer `chacun pour le `Joueur` concerné, et décide des effets.` par `chacun pour le `Joueur` concerné, et décide des effets. Donne aussi les couleurs de départ de chaque joueur (aucune en solo, ses trois nuances en bataille).`

- [ ] **Step 3 : spec, §5 « Lion »**

3a. Remplacer :

```markdown
- **Pseudo** affiché au-dessus du lion, dans sa couleur, en multi uniquement.
- **Gerbe** : 3 émetteurs (nuances du joueur) en éventail en bataille, un émetteur par couleur
  débloquée en solo.
- **Traceuses** : la traceuse de peinture reste au point de chute. En bataille, **3 zones de
  contact** supplémentaires le long de la parabole (même physique que les particules) détectent
  les autres lions.
- **Étourdissement** : commandes ignorées, recul, barbouillage, étoiles qui tournent. L'immunité
  réutilise le clignotement actuel.
- **Collisions** : les lions partagent une couche de collision dédiée. Forme de contact entre lions
  réduite (rayon ≈ 45 px au lieu de 63). Au contact, impulsion `recul` des deux côtés
  proportionnelle à la vitesse relative, son « boing », petite secousse du sprite (pas de secousse
  d'écran en multi). Un choc ne cause pas d'étourdissement. Un ennemi ne ré-étourdit pas un lion
  immunisé.
```

par :

```markdown
- **Pseudo** affiché au-dessus du lion, dans sa couleur, pour un joueur qui a une couleur et un
  pseudo : en multi seulement, puisque le joueur du solo n'a pas de couleur.
- **Gerbe** : un émetteur par couleur débloquée, en éventail. En bataille, les règles donnent à
  chaque joueur, au départ de la partie, ses trois nuances (foncée, pure, claire) comme couleurs
  débloquées : 3 émetteurs, et la traceuse peint dans ces nuances. Le rayon de peinture suit les
  crans (§2).
- **Traceuses** : la traceuse de peinture reste au point de chute. En bataille, **3 zones de
  contact** le long de la parabole (même physique que les particules, à 0,2, 0,4 et 0,6 s de vol :
  la dernière au point de chute) détectent le corps des autres lions (63 px) pendant le vomi.
- **Étourdissement** : commandes ignorées, recul, barbouillage, étoiles qui tournent. L'immunité
  réutilise le clignotement actuel. Étourdissement et immunité partagent la minuterie
  d'invulnérabilité du solo : `Joueur.etourdir` la règle sur la durée de l'étourdissement plus
  1 s, et les règles ignorent un joueur étourdi ou invulnérable (le peintre et la gerbe signalent
  leur contact à chaque frame).
- **Collisions** : les lions partagent une couche de collision dédiée (couche 5) : un pare-chocs
  (`Area2D`) de 45 px au lieu des 63 px du corps. Le corps reste sur la couche 1, où ennemis et
  pastilles le détectent, et ne heurte plus rien (masque 0). Au premier contact, impulsion `recul`
  des deux côtés proportionnelle à la vitesse d'approche relative, son « boing », petite secousse
  du sprite (pas de secousse d'écran en multi) ; pendant le contact, la part de la vitesse dirigée
  vers l'autre lion est annulée. Un choc ne cause pas d'étourdissement. Un ennemi ne ré-étourdit
  pas un lion immunisé.
```

- [ ] **Step 4 : feuille de route, lignes des phases**

4a. Remplacer la ligne qui commence par `| 8 | **Lion de bataille**` par les trois lignes :

```markdown
| 8 | **Règles et état de bataille** : `ReglesBataille` (étourdissement 1,5 s par le vomi, 2,5 s par un ennemi, puis 1 s d'immunité ; crans ; chocs comptés ; ni vies ni cœurs), `Joueur` (crans, étourdissement, nuances, statistiques ; l'immunité est l'invulnérabilité du solo), événements de vomi et de choc dans `Regles`, `GameState.configurer_solo()` / `configurer_bataille(n)`. | ✏️ `Scripts/Joueur.gd` ✏️ `Scripts/Regles.gd` ➕ `Scripts/ReglesBataille.gd` ✏️ `Scripts/GameState.gd` ✏️ `tests/unitaires.gd` | tests verts |
| 8 bis | **Lion de bataille** : rayon selon les crans (le solo gagne un cran par couleur), gerbe en 3 nuances, étourdissement (commandes ignorées, recul, barbouillage, étoiles, clignotement de l'immunité), 3 zones de contact sur la parabole, auto-tamponneuses, `class_name Lion`. | ✏️ `Scripts/ReglesSolo.gd` ✏️ `tests/unitaires.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scenes/Lion.tscn` ✏️ `tests/smoke_test.gd` | tests verts, ◉ lions étourdis |
| 8 ter | **Ennemis vers `body is Lion`** : base commune des gestionnaires de contact des ennemis (garde hôte, `body is Lion`, origine du coup). | ➕ `Scripts/Ennemi.gd` ✏️ `Scripts/Soucoupe.gd` ✏️ `Scripts/Coccinelle.gd` ✏️ `Scripts/Boss.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
```

4b. Remplacer la ligne qui commence par `| 9 | **Territoire**` par (le smoke test y est nécessaire pour le point de vigilance obligatoire de la phase 9) :

```markdown
| 9 | **Territoire** : logique pure de charge et de vol, grille de propriété dans la ville, tampons en cache par jeu de couleurs. | ➕ `Scripts/Territoire.gd` ✏️ `Scripts/Ville.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` | tests verts |
```

4c. Juste après la ligne qui commence par `| 14 | **Manche synchronisée**`, ajouter :

```markdown
| 14 bis | **Pastilles vers `body is Lion`** : base commune des trois pastilles (garde hôte, `body is Lion`, premier arrivé, premier servi). | ➕ `Scripts/Pastille.gd` ✏️ `Scripts/ColorPickup.gd` ✏️ `Scripts/BonusPickup.gd` ✏️ `Scripts/CoeurPickup.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
```

4d. Juste après la ligne qui commence par `| 17 | **HUD de bataille**`, ajouter :

```markdown
| 17 bis | **Sons de bataille** : « boing » des chocs entre lions (spec §5), synthétisé comme les autres effets. | ✏️ `tools/generer_sons.py` ➕ `Assets/Sons/boing.wav` ✏️ `Scripts/Audio.gd` ✏️ `Scripts/Lion.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
```

- [ ] **Step 5 : feuille de route, points de vigilance résolus ou recadrés**

5a. Supprimer l'item résolu par cette phase (Task 1) :

```markdown
- Phase 8 : réconcilier le `invulnerable_restant` du solo (1,5 s) avec l'`immunite_restante` de la
  bataille (1 s) plutôt que d'ajouter un mécanisme parallèle.
```

5b. Remplacer (retour à la ligne et ponctuation comme les items voisins) :

```markdown
- Prochaine phase qui touche `.github/workflows/ci.yml` : envelopper chaque lancement godot dans
  `timeout` (une erreur de script bloque le processus headless) et faire échouer le job si la
  sortie contient `SCRIPT ERROR` ou `SHADER ERROR` (une erreur dans un callback de signal ne change pas le code de sortie) ;
```

par :

```markdown
- Prochaine phase qui touche `.github/workflows/ci.yml` : envelopper chaque lancement godot dans
  `timeout` (une erreur de script bloque le processus headless) et faire échouer le job si la
  sortie contient `SCRIPT ERROR` ou `SHADER ERROR` (une erreur dans un callback de signal, ou dans
  une fonction appelée, ne change pas le code de sortie).
```

5c. Remplacer :

```markdown
- phase 8 ou 14 : le gestionnaire de contact est copié dans `ColorPickup`, `BonusPickup` et
  `CoeurPickup` ; en faire une base commune quand une de ces phases doit les modifier tous
  (`body is Lion`, désapparition répliquée) ;
```

par :

```markdown
- **phase 14 bis** : le gestionnaire de contact est copié dans `ColorPickup`, `BonusPickup` et
  `CoeurPickup` ; en faire une base commune `Pastille` (garde hôte, `body is Lion`, premier
  arrivé, premier servi). La désapparition répliquée reste à la phase 14 ;
```

5d. Supprimer l'item résolu par cette phase (Task 2) :

```markdown
- phase 8 : `ReglesBataille.lion_touche_par_ennemi` ignore un joueur déjà étourdi ou immunisé (le
  peintre signale le contact à chaque frame de chevauchement ; sinon l'étourdissement de 2,5 s
  redémarrerait sans fin) ;
```

5e. Remplacer :

```markdown
- phase 8 : ajouter `class_name Lion` et tester `body is Lion` dans les gestionnaires de
  contact au lieu de supposer `body.joueur`. Les tests `--script` (compilés avant les autoloads)
  continuent de typer les lions en `Node` / `CharacterBody2D`, jamais `Lion` : `Lion.gd` nomme
  `GameState` et `Audio` ;
```

par :

```markdown
- **phase 8 bis** : ajouter `class_name Lion` (les zones de contact et le pare-chocs s'en servent).
  **Phases 8 ter (ennemis) et 14 bis (pastilles)** : tester `body is Lion` dans les gestionnaires
  de contact au lieu de supposer `body.joueur`. Les tests `--script` (compilés avant les
  autoloads) continuent de typer les lions en `Node` / `CharacterBody2D`, jamais `Lion` : `Lion.gd`
  nomme `GameState` et `Audio` ;
```

5f. Remplacer :

```markdown
- **phase 8 ou 10 (obligatoire avant la première partie de bataille)** : la mise en place et le
  démontage d'un mode sur `GameState` doivent précéder `Main._enter_tree` (Main y appelle
  `GameState.nouvelle_partie()`, puis Lion, Spawner, HUD et Main s'abonnent à `joueur_local()` dans
  leur `_ready`). Ajouter `GameState.configurer_solo()` / `configurer_bataille(n)`, appelés **avant**
  le changement de scène (règles, nombre de joueurs remplis en place, couleurs et pseudos), avec un
  test unitaire : bataille puis solo rend `ReglesSolo` et un seul joueur, sans couleur (le lion du
  solo retrouve son rendu d'origine) ;
```

par :

```markdown
- **phase 10 (obligatoire avant la première partie de bataille)** : `GameState.configurer_solo()` /
  `configurer_bataille(n)` existent depuis la phase 8 (règles, joueurs redimensionnés en place,
  index et couleurs ; testés). Les appeler **avant** le changement de scène, jamais depuis la scène
  de jeu : `Main._enter_tree` appelle `GameState.nouvelle_partie()`, puis Lion, Spawner, HUD et Main
  s'abonnent à `joueur_local()` dans leur `_ready`. `configurer_bataille(n)` avant la scène de
  bataille, et `configurer_solo()` avant toute partie solo, démo ou arcade lancée depuis le titre
  (sans quoi une partie solo jouée après une bataille garderait les règles et la couleur de la
  bataille) ;
```

5g. Remplacer :

```markdown
- **phase 14** : les réactions du `Joueur` sont des appels de méthode qui émettent des signaux
  (`debloquer_couleur`, `activer_bonus`, `encaisser_coup`). Un `MultiplayerSynchronizer` qui écrit
  les champs bruts n'émettrait rien chez les clients (HUD, Audio, Lion muets) : choisir des RPC
  d'événement qui appellent les mêmes méthodes du `Joueur`, ou des setters qui émettent. De même,
  `GameState._process` ferait avancer les copies des clients (`Joueur.avancer`) : l'hôte seul décompte ;
```

par :

```markdown
- **phase 14** : les réactions du `Joueur` sont des appels de méthode qui émettent des signaux
  (`debloquer_couleur`, `activer_bonus`, `encaisser_coup`, `gagner_cran`, `etourdir`, et `avancer`
  pour `etourdissement_fini`). Un `MultiplayerSynchronizer` qui écrit les champs bruts n'émettrait
  rien chez les clients (HUD, Audio, Lion muets) : choisir des RPC d'événement qui appellent les
  mêmes méthodes du `Joueur`, ou des setters qui émettent. De même, `GameState._process` ferait
  avancer les copies des clients (`Joueur.avancer`) : l'hôte seul décompte ;
```

5h. Remplacer :

```markdown
- **phase 8** : le barbouillage passe par les uniformes `barbouillage_couleur` /
```

par :

```markdown
- **phase 8 bis** : le barbouillage passe par les uniformes `barbouillage_couleur` /
```

5i. Remplacer les trois premières lignes de l'item de la palette :

```markdown
- **phase 11** : la palette de bataille (planche de la phase 7 : rouge `(0.90, 0.16, 0.16)`, bleu
  `(0.16, 0.39, 0.95)`, jaune `(0.98, 0.82, 0.10)`, vert `(0.18, 0.78, 0.25)`, magenta
  `(0.90, 0.20, 0.85)`, cyan `(0.10, 0.85, 0.90)`) devient une constante unique. En simulation
```

par (la suite de l'item, à partir de `  deutéranopie, rouge, vert et jaune`, ne change pas) :

```markdown
- **phase 11** : la palette de bataille (planche de la phase 7 : rouge `(0.90, 0.16, 0.16)`, bleu
  `(0.16, 0.39, 0.95)`, jaune `(0.98, 0.82, 0.10)`, vert `(0.18, 0.78, 0.25)`, magenta
  `(0.90, 0.20, 0.85)`, cyan `(0.10, 0.85, 0.90)`) est depuis la phase 8 la constante unique
  `GameState.PALETTE_BATAILLE`, attribuée par index par `configurer_bataille(n)` ; le salon
  l'attribuera au choix des joueurs. En simulation
```

- [ ] **Step 6 : feuille de route, nouveaux points de vigilance**

Ajouter à la fin de la liste :

```markdown
- **phase 9** : `Joueur.cellules_volees` existe depuis la phase 8 (remis à zéro par
  `reinitialiser`, jamais incrémenté) : le territoire l'incrémente quand un tampon vole une
  cellule. En bataille, les couleurs débloquées d'un joueur sont ses trois nuances (données par
  `Regles.couleurs_de_depart`) : c'est ce que reçoivent la traceuse et `Ville.peindre` ;
- **phases 13 et 14** : `Lion.appliquer_apparence()` se rappelle à la main quand la couleur ou le
  pseudo d'un joueur change. Quand ces changements viendront du réseau (salon, synchronisation),
  donner à `Joueur.couleur` et `Joueur.pseudo` des setters qui émettent un signal
  `apparence_changee`, auquel le lion s'abonne ;
- activer `rendering/viewport/hdr_2d` changerait les valeurs lues par `Shaders/Lion.gdshader` et
  décalerait ses seuils de masque (valeur, saturation) : refaire alors la planche de contrôle de la
  phase 7 et régler les seuils ;
```

- [ ] **Step 7 : Vérifier les documents**

```sh
grep -n "immunite_restante\|phase 8 ou\|Phase 8 :\|phase 8 :" docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
```

Expected : aucune ligne. Relire le diff (`git diff docs/`) : seuls le spec et la feuille de route ont changé, les deux plans sont nouveaux et intacts.

- [ ] **Step 8 : Commit**

```bash
git add docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md docs/superpowers/plans/2026-09-25-phase-08-bataille.md docs/superpowers/plans/2026-09-25-phase-08bis-lion.md
git commit -m "Plans des phases 8 et 8 bis (règles de bataille, lion de bataille) ; spec : immunité = invulnérabilité, nuances au départ, pare-chocs ; feuille de route : phases 8 bis, 8 ter, 14 bis, 17 bis et vigilance

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 1 : `Joueur` : crans, étourdissement, nuances, statistiques

**Files:**
- Modify: `Scripts/Joueur.gd`
- Modify: `tests/unitaires.gd` (fin de `_tester_joueur`)

**Interfaces:**
- Consumes : `Joueur` existant (`couleur`, `a_une_couleur`, `invulnerable_restant`, `avancer`, `reinitialiser`).
- Produces :
  - `Joueur.CRANS_MAX := 7`, `Joueur.ECART_NUANCES := 0.35` ;
  - champs `crans` (1 au départ), `etourdi_restant`, `etourdissements_infliges`, `cellules_volees`, `chocs` ;
  - signaux `crans_changes(crans: int)`, `etourdi(origine: Vector2, barbouillage: Color)`, `etourdissement_fini()` ;
  - `reinitialiser(vies_depart: int, couleurs_depart: Array[Color] = [])` (silencieux, les couleurs remplies **en place**) ;
  - `gagner_cran() -> bool`, `etourdir(duree: float, duree_immunite: float, origine: Vector2, barbouillage: Color)`, `est_etourdi() -> bool`, `nuances() -> Array[Color]`.

- [ ] **Step 1 : `tests/unitaires.gd`, les vérifications**

Dans `_tester_joueur()`, juste après les deux dernières lignes de la fonction :

```gdscript
	_check(j.vies == 1 and not j.bonus_actif() and j.couleurs_debloquees.is_empty() and j.coups_recus == 0,
		"reinitialiser remet vies, bonus, couleurs et coups à l'état de départ")
```

ajouter une ligne vide puis :

```gdscript
	# Crans de gerbe : de 1 à CRANS_MAX, signalés
	var crans_recus: Array[int] = []
	j.crans_changes.connect(func(c: int) -> void: crans_recus.append(c))
	_check(j.crans == 1, "un joueur réinitialisé a un cran de gerbe")
	for i in range(Joueur.CRANS_MAX - 1):
		j.gagner_cran()
	_check(j.crans == Joueur.CRANS_MAX and crans_recus == [2, 3, 4, 5, 6, 7], "chaque cran gagné est signalé, jusqu'à 7 (%s)" % [crans_recus])
	_check(not j.gagner_cran() and j.crans == Joueur.CRANS_MAX and crans_recus.size() == 6, "au maximum, un cran de plus est refusé sans signal")

	# Nuances de la gerbe de bataille
	j.couleur = Color(0.16, 0.39, 0.95)
	var n: Array[Color] = j.nuances()
	_check(n.size() == 3 and n[1] == j.couleur and n[0].get_luminance() < n[1].get_luminance()
		and n[2].get_luminance() > n[1].get_luminance() and n.all(func(c: Color) -> bool: return c.a == 1.0),
		"trois nuances opaques : foncée, la couleur du joueur, claire")

	# Étourdissement puis immunité : une seule minuterie de protection
	var etourdissements: Array[String] = []
	j.etourdi.connect(func(o: Vector2, b: Color) -> void: etourdissements.append("etourdi:%d,%d:%s" % [int(o.x), int(o.y), b.to_html()]))
	j.etourdissement_fini.connect(func() -> void: etourdissements.append("fini"))
	j.etourdir(1.5, 1.0, Vector2(5, 6), Color.RED)
	_check(etourdissements == ["etourdi:5,6:%s" % Color.RED.to_html()], "etourdir signale l'origine et la couleur du barbouillage (%s)" % [etourdissements])
	_check(j.est_etourdi() and is_equal_approx(j.etourdi_restant, 1.5) and j.est_invulnerable() and is_equal_approx(j.invulnerable_restant, 2.5),
		"étourdi 1,5 s, et invulnérable pendant l'étourdissement puis 1 s d'immunité")
	j.avancer(1.0)
	_check(j.est_etourdi() and etourdissements.size() == 1, "l'étourdissement dure encore")
	j.avancer(0.6)
	_check(not j.est_etourdi() and j.etourdi_restant == 0.0 and etourdissements.back() == "fini",
		"la fin de l'étourdissement est signalée, jamais en négatif")
	_check(j.est_invulnerable() and is_equal_approx(j.invulnerable_restant, 0.9), "puis l'immunité continue seule (0,9 s restantes)")
	j.avancer(1.0)
	_check(not j.est_invulnerable() and etourdissements.size() == 2, "l'immunité s'arrête, la fin n'est signalée qu'une fois")

	# Réinitialiser : crans, étourdissement et statistiques repartent de zéro, en silence
	j.gagner_cran()
	j.etourdir(1.5, 1.0, Vector2.ZERO, Color.TRANSPARENT)
	j.etourdissements_infliges = 2
	j.cellules_volees = 30
	j.chocs = 4
	crans_recus.clear()
	etourdissements.clear()
	j.reinitialiser(3)
	_check(j.crans == 1 and not j.est_etourdi() and not j.est_invulnerable() and j.etourdissements_infliges == 0
		and j.cellules_volees == 0 and j.chocs == 0 and crans_recus.is_empty() and etourdissements.is_empty(),
		"reinitialiser remet crans, étourdissement et statistiques à zéro sans signal")
	j.reinitialiser(3, j.nuances())
	_check(j.couleurs_debloquees == j.nuances() and recues.is_empty(), "reinitialiser peut donner des couleurs de départ, sans les signaler")
	var avant: Array[Color] = j.couleurs_debloquees
	j.reinitialiser(3)
	_check(j.couleurs_debloquees.is_empty() and is_same(avant, j.couleurs_debloquees),
		"les couleurs sont remises à zéro en place (le tableau lu par le lion et le HUD reste le même)")
```

(`recues` est le tableau des couleurs signalées déclaré plus haut dans la fonction, vidé juste avant le `reinitialiser(1)` qui précède.)

- [ ] **Step 2 : Lancer les tests unitaires (échec attendu)**

Run : les tests unitaires avec délai (30 s suffisent).
Expected : `SCRIPT ERROR: Parse Error: Cannot find member "CRANS_MAX" in base "Joueur".` (plusieurs fois), `Too many arguments for "reinitialiser()" call`, puis `Failed to load script "res://tests/unitaires.gd"`. Aucune vérification ne tourne.

- [ ] **Step 3 : `Scripts/Joueur.gd`**

3a. Remplacer les lignes de docstring 3 et 4 :

```gdscript
## État d'un lion : identité (index, pseudo, couleur) et, pendant une partie, couleurs
## débloquées, vies, invulnérabilité, bonus.
```

par :

```gdscript
## État d'un lion : identité (index, pseudo, couleur) et, pendant une partie, couleurs
## débloquées, crans de gerbe, vies, invulnérabilité, étourdissement, bonus et statistiques.
```

3b. Juste après `signal touche(origine: Vector2)`, ajouter :

```gdscript
signal crans_changes(crans: int)
## Début d'un étourdissement (bataille). `barbouillage` = couleur de l'agresseur, transparente
## si c'est un ennemi (pas de barbouillage).
signal etourdi(origine: Vector2, barbouillage: Color)
signal etourdissement_fini()

## Crans de gerbe : de 1 (départ, rayon de peinture minimal) à CRANS_MAX.
const CRANS_MAX := 7
## Écart des nuances foncée et claire autour de la couleur du joueur (voir `nuances`).
const ECART_NUANCES := 0.35
```

3c. Remplacer :

```gdscript
var couleurs_debloquees: Array[Color] = []
var vies := 3
var coups_recus := 0
var invulnerable_restant := 0.0
var bonus_restant := 0.0
```

par :

```gdscript
var couleurs_debloquees: Array[Color] = []
var crans := 1
var vies := 3
var coups_recus := 0
## Invulnérabilité, appelée immunité en bataille : ni coup ni étourdissement ne porte tant
## qu'elle dure. Une seule minuterie pour les deux modes ; ce sont les règles qui choisissent sa
## durée (1,5 s après un coup en solo ; en bataille, l'étourdissement puis 1 s).
var invulnerable_restant := 0.0
var etourdi_restant := 0.0
var bonus_restant := 0.0
# Statistiques de bataille, pour les titres de l'écran Résultats (les cellules volées sont
# comptées par le territoire, phase 9).
var etourdissements_infliges := 0
var cellules_volees := 0
var chocs := 0
```

3d. Remplacer :

```gdscript
## Remet le joueur à l'état de départ d'une partie, sans émettre de signal.
func reinitialiser(vies_depart: int) -> void:
	couleurs_debloquees.clear()
	vies = vies_depart
	coups_recus = 0
	invulnerable_restant = 0.0
	bonus_restant = 0.0
```

par :

```gdscript
## Remet le joueur à l'état de départ d'une partie, sans émettre de signal.
## `couleurs_depart` : couleurs vomies d'emblée (les trois nuances en bataille, aucune en solo).
func reinitialiser(vies_depart: int, couleurs_depart: Array[Color] = []) -> void:
	couleurs_debloquees.assign(couleurs_depart)
	crans = 1
	vies = vies_depart
	coups_recus = 0
	invulnerable_restant = 0.0
	etourdi_restant = 0.0
	bonus_restant = 0.0
	etourdissements_infliges = 0
	cellules_volees = 0
	chocs = 0
```

(`assign` remplit le tableau existant : le lion, le HUD et la traceuse lisent `joueur.couleurs_debloquees` à chaque fois, le tableau ne doit pas être remplacé.)

3e. Remplacer :

```gdscript
## Décompte invulnérabilité et bonus ; signale la fin de la gerbe XXL.
func avancer(delta: float) -> void:
	if invulnerable_restant > 0.0:
		invulnerable_restant = max(0.0, invulnerable_restant - delta)
```

par :

```gdscript
## Décompte invulnérabilité, étourdissement et bonus ; signale la fin de l'étourdissement et
## celle de la gerbe XXL.
func avancer(delta: float) -> void:
	if invulnerable_restant > 0.0:
		invulnerable_restant = max(0.0, invulnerable_restant - delta)
	if etourdi_restant > 0.0:
		etourdi_restant = max(0.0, etourdi_restant - delta)
		if etourdi_restant == 0.0:
			etourdissement_fini.emit()
```

3f. Juste avant `func gagner_vie(vies_max: int) -> bool:`, ajouter :

```gdscript
## Un cran de gerbe de plus, jusqu'à CRANS_MAX. Renvoie false (sans signal) au maximum.
func gagner_cran() -> bool:
	if crans >= CRANS_MAX:
		return false
	crans += 1
	crans_changes.emit(crans)
	return true


## Étourdit le joueur `duree` secondes puis l'immunise `duree_immunite` secondes : son
## invulnérabilité couvre les deux (une seule minuterie de protection, voir `invulnerable_restant`).
func etourdir(duree: float, duree_immunite: float, origine: Vector2, barbouillage: Color) -> void:
	etourdi_restant = duree
	invulnerable_restant = duree + duree_immunite
	etourdi.emit(origine, barbouillage)


```

3g. Juste avant `func bonus_actif() -> bool:`, ajouter :

```gdscript
func est_etourdi() -> bool:
	return etourdi_restant > 0.0


```

3h. Remplacer :

```gdscript
func a_une_couleur() -> bool:
	return couleur.a > 0.0
```

par :

```gdscript
func a_une_couleur() -> bool:
	return couleur.a > 0.0


## Les trois nuances de la gerbe d'un joueur de bataille, dans l'ordre de l'éventail :
## foncée, pure, claire (spec §2).
func nuances() -> Array[Color]:
	return [couleur.darkened(ECART_NUANCES), couleur, couleur.lightened(ECART_NUANCES)]
```

Garder deux lignes vides entre les fonctions.

- [ ] **Step 4 : Vérifier**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` (aucune ligne), puis les tests unitaires avec délai : `== 0 échec(s) ==`, sans `SCRIPT ERROR`, avec les 13 nouvelles vérifications (`✅`) dans `$TMPDIR/t.log`. Puis le smoke test (inchangé) : vert.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Joueur.gd tests/unitaires.gd
git commit -m "Joueur : crans de gerbe, étourdissement (immunité = invulnérabilité du solo), nuances et statistiques de bataille ; couleurs de départ silencieuses

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 2 : événements de la base `Regles` et `ReglesBataille`

**Files:**
- Modify: `Scripts/Regles.gd`
- Create: `Scripts/ReglesBataille.gd`
- Modify: `tests/unitaires.gd` (`_run`, `_tester_regles_solo`, nouvelle fonction `_tester_regles_bataille`)

**Interfaces:**
- Consumes : Task 1 (`Joueur.etourdir`, `est_etourdi`, `est_invulnerable`, `gagner_cran`, `nuances`, statistiques), `EtatPartie` (`partie_en_cours`, `pret`), `ReglesSolo.DUREE_ETOILE`.
- Produces :
  - `Regles.couleurs_de_depart(joueur) -> Array[Color]` (vide), `Regles.lion_touche_par_vomi(victime, agresseur, origine)`, `Regles.choc_entre_lions(a, b)` : sans effet ;
  - `ReglesBataille` (`class_name`, `extends Regles`) : `DUREE_ETOURDI_VOMI := 1.5`, `DUREE_ETOURDI_ENNEMI := 2.5`, `DUREE_IMMUNITE := 1.0`, et les redéfinitions `couleurs_de_depart`, `lion_touche_par_ennemi`, `lion_touche_par_vomi`, `choc_entre_lions`, `pastille_ramassee`, `etoile_ramassee`. `coeur_ramasse` et `progression_mesuree` restent ceux de la base (aucun cœur ; la manche se terminera au chrono, phase 17).

- [ ] **Step 1 : `tests/unitaires.gd`, les vérifications**

1a. Dans `_run`, remplacer :

```gdscript
	_tester_regles_solo()
	_tester_delegation_regles()
```

par :

```gdscript
	_tester_regles_solo()
	_tester_regles_bataille()
	_tester_delegation_regles()
```

1b. Dans `_tester_regles_solo()`, juste après les trois lignes :

```gdscript
	j.vies = 2
	_check(not base.coeur_ramasse(j) and j.vies == 2, "coeur_ramasse des règles de base n'a aucun effet, même sous le maximum")
	j.vies = 3
```

ajouter :

```gdscript
	var autre := Joueur.new()
	autre.reinitialiser(3)
	base.lion_touche_par_vomi(j, autre, Vector2.ZERO)
	base.choc_entre_lions(j, autre)
	_check(base.couleurs_de_depart(j).is_empty() and not j.est_etourdi() and not j.est_invulnerable()
		and autre.etourdissements_infliges == 0 and j.chocs == 0 and autre.chocs == 0,
		"sans règles de mode, ni couleur de départ, ni effet du vomi ou des chocs")
```

1c. Juste avant `func _tester_delegation_regles() -> void:`, ajouter :

```gdscript
func _tester_regles_bataille() -> void:
	print("-- Règles de bataille")
	var gs: Node = root.get_node("GameState")
	gs.difficulte_courante = 0
	gs.nouvelle_partie()
	gs.pret = true
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)
	var r := ReglesBataille.new(gs)
	var rouge := Joueur.new()
	rouge.couleur = Color(0.90, 0.16, 0.16)
	var bleu := Joueur.new()
	bleu.couleur = Color(0.16, 0.39, 0.95)
	for j: Joueur in [rouge, bleu]:
		j.reinitialiser(3, r.couleurs_de_depart(j))
	_check(rouge.couleurs_debloquees == rouge.nuances() and bleu.couleurs_debloquees == bleu.nuances(),
		"en bataille, chaque joueur vomit dès le départ dans ses trois nuances")
	var barbouillages: Array[Color] = []
	bleu.etourdi.connect(func(_o: Vector2, b: Color) -> void: barbouillages.append(b))

	# Vomi : 1,5 s d'étourdissement, barbouillé de la couleur de l'agresseur, puis 1 s d'immunité
	r.lion_touche_par_vomi(bleu, rouge, Vector2(7, 8))
	_check(bleu.est_etourdi() and is_equal_approx(bleu.etourdi_restant, ReglesBataille.DUREE_ETOURDI_VOMI)
		and is_equal_approx(bleu.invulnerable_restant, ReglesBataille.DUREE_ETOURDI_VOMI + ReglesBataille.DUREE_IMMUNITE)
		and barbouillages == [rouge.couleur],
		"le vomi d'un autre lion étourdit 1,5 s, barbouille de la couleur de l'agresseur, puis immunise 1 s")
	_check(rouge.etourdissements_infliges == 1 and bleu.vies == 3 and fins.is_empty(),
		"l'étourdissement compte pour l'agresseur ; aucune vie perdue, la manche continue")
	for i in range(10):
		r.lion_touche_par_vomi(bleu, rouge, Vector2(7, 8))
	_check(barbouillages.size() == 1 and rouge.etourdissements_infliges == 1 and is_equal_approx(bleu.etourdi_restant, ReglesBataille.DUREE_ETOURDI_VOMI),
		"un lion déjà étourdi n'est pas ré-étourdi (contact signalé à chaque frame)")
	bleu.avancer(ReglesBataille.DUREE_ETOURDI_VOMI + 0.1)
	r.lion_touche_par_vomi(bleu, rouge, Vector2(7, 8))
	_check(not bleu.est_etourdi() and bleu.est_invulnerable() and barbouillages.size() == 1 and rouge.etourdissements_infliges == 1,
		"un lion immunisé n'est pas étourdi et ne compte pas")
	bleu.avancer(ReglesBataille.DUREE_IMMUNITE)
	r.lion_touche_par_vomi(rouge, rouge, Vector2.ZERO)
	_check(not rouge.est_etourdi() and rouge.etourdissements_infliges == 1, "son propre vomi n'étourdit pas")
	rouge.etourdir(1.0, 1.0, Vector2.ZERO, Color.TRANSPARENT)
	r.lion_touche_par_vomi(bleu, rouge, Vector2.ZERO)
	_check(not bleu.est_etourdi() and rouge.etourdissements_infliges == 1, "un lion étourdi n'étourdit personne")
	rouge.avancer(2.0)

	# Ennemis : 2,5 s sans barbouillage, puis 1 s d'immunité ; aucune vie perdue
	for i in range(10):
		r.lion_touche_par_ennemi(bleu, Vector2(1, 2))  # le peintre signale le contact à chaque frame
	_check(bleu.est_etourdi() and is_equal_approx(bleu.etourdi_restant, ReglesBataille.DUREE_ETOURDI_ENNEMI)
		and is_equal_approx(bleu.invulnerable_restant, ReglesBataille.DUREE_ETOURDI_ENNEMI + ReglesBataille.DUREE_IMMUNITE)
		and barbouillages.size() == 2 and barbouillages[1].a == 0.0 and bleu.vies == 3,
		"un ennemi étourdit 2,5 s sans barbouillage (un seul étourdissement pour dix contacts), sans vie perdue")
	bleu.avancer(ReglesBataille.DUREE_ETOURDI_ENNEMI + 0.5)
	r.lion_touche_par_ennemi(bleu, Vector2(1, 2))
	_check(barbouillages.size() == 2, "un ennemi ne ré-étourdit pas un lion immunisé")
	bleu.avancer(1.0)
	gs.pret = false
	r.lion_touche_par_ennemi(bleu, Vector2(1, 2))
	r.lion_touche_par_vomi(bleu, rouge, Vector2.ZERO)
	_check(barbouillages.size() == 2, "rien n'étourdit pendant l'intro")
	gs.pret = true

	# Chocs : comptés des deux côtés, jamais d'étourdissement
	r.choc_entre_lions(rouge, bleu)
	_check(rouge.chocs == 1 and bleu.chocs == 1 and not rouge.est_etourdi() and not bleu.est_etourdi(),
		"un choc compte pour les deux lions et n'étourdit personne")
	r.choc_entre_lions(rouge, rouge)
	_check(rouge.chocs == 1, "un lion ne se choque pas lui-même")

	# Pastilles, étoile, cœur, progression
	_check(r.pastille_ramassee(rouge, 5) and rouge.crans == 2 and rouge.couleurs_debloquees == rouge.nuances(),
		"une pastille donne un cran de gerbe, quelle que soit sa couleur, sans débloquer de couleur")
	for i in range(10):
		r.pastille_ramassee(rouge, 0)
	_check(rouge.crans == Joueur.CRANS_MAX and not r.pastille_ramassee(rouge, 0), "les crans plafonnent à 7")
	r.etoile_ramassee(bleu)
	_check(bleu.bonus_actif() and is_equal_approx(bleu.bonus_restant, ReglesSolo.DUREE_ETOILE), "l'étoile XXL est celle du solo")
	bleu.vies = 2
	_check(not r.coeur_ramasse(bleu) and bleu.vies == 2, "aucun cœur en bataille")
	r.progression_mesuree(1.0)
	_check(fins.is_empty() and gs.partie_en_cours, "peindre toute la ville ne termine pas la manche (elle finit au chrono)")
	gs.terminer_partie(false)
	bleu.invulnerable_restant = 0.0
	bleu.etourdi_restant = 0.0
	r.lion_touche_par_ennemi(bleu, Vector2.ZERO)
	r.choc_entre_lions(rouge, bleu)
	_check(not bleu.est_etourdi() and bleu.chocs == 1, "après la fin de manche, plus d'étourdissement ni de choc compté")

	gs.partie_terminee.disconnect(sur_fin)
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false


```

- [ ] **Step 2 : Lancer les tests unitaires (échec attendu)**

Run : les tests unitaires avec délai (30 s).
Expected : `SCRIPT ERROR: Parse Error:` qui nomme `ReglesBataille` (identifiant ou classe introuvable), puis `Failed to load script "res://tests/unitaires.gd"`. Aucune vérification ne tourne.

- [ ] **Step 3 : `Scripts/Regles.gd`, les nouveaux événements**

3a. Remplacer :

```gdscript
## Un ennemi (soucoupe, coccinelle, peintre) touche le lion du joueur. `origine` = position de
## l'ennemi, pour le recul (Vector2.INF si inconnue).
func lion_touche_par_ennemi(_joueur: Joueur, _origine: Vector2) -> void:
	pass
```

par :

```gdscript
## Couleurs que le joueur vomit dès le départ d'une partie (lu par `nouvelle_partie`).
func couleurs_de_depart(_joueur: Joueur) -> Array[Color]:
	return []


## Un ennemi (soucoupe, coccinelle, peintre) touche le lion du joueur. `origine` = position de
## l'ennemi, pour le recul (Vector2.INF si inconnue). Le peintre le signale à chaque frame de
## chevauchement : un joueur déjà frappé doit être ignoré.
func lion_touche_par_ennemi(_joueur: Joueur, _origine: Vector2) -> void:
	pass


## Le vomi du lion d'`agresseur` touche le lion de `victime`, à `origine` (point de la gerbe,
## pour le recul). Signalé à chaque frame de contact, comme le peintre.
func lion_touche_par_vomi(_victime: Joueur, _agresseur: Joueur, _origine: Vector2) -> void:
	pass


## Les lions de `a` et `b` viennent de se rentrer dedans (signalé une fois par contact).
func choc_entre_lions(_a: Joueur, _b: Joueur) -> void:
	pass
```

3b. Dans la docstring de `pastille_ramassee`, remplacer `l'arc-en-ciel ; les règles de bataille l'ignoreront.` par `l'arc-en-ciel ; les règles de bataille l'ignorent.`

- [ ] **Step 4 : `Scripts/ReglesBataille.gd`**

```gdscript
class_name ReglesBataille
extends Regles
## Règles de la bataille de peinture (spec §2) : ni vies ni cœurs. Chaque joueur vomit dès le
## départ dans les trois nuances de sa couleur ; le vomi d'un autre lion l'étourdit 1,5 s (tête
## barbouillée de la couleur de l'agresseur), un ennemi 2,5 s, puis 1 s d'immunité ; chaque
## pastille donne un cran de gerbe ; l'étoile XXL est celle du solo. Le territoire (phase 9) et
## la fin de manche au chrono (phase 17) s'y ajouteront.

const DUREE_ETOURDI_VOMI := 1.5
const DUREE_ETOURDI_ENNEMI := 2.5
const DUREE_IMMUNITE := 1.0


func _init(partie_: EtatPartie) -> void:
	assert(partie_ != null, "ReglesBataille a besoin de l'état de partie")
	super(partie_)


func couleurs_de_depart(joueur: Joueur) -> Array[Color]:
	return joueur.nuances()


## Pas de vie perdue : l'ennemi étourdit, sans barbouillage.
func lion_touche_par_ennemi(joueur: Joueur, origine: Vector2) -> void:
	if not _peut_etre_etourdi(joueur):
		return
	joueur.etourdir(DUREE_ETOURDI_ENNEMI, DUREE_IMMUNITE, origine, Color.TRANSPARENT)


## Un lion étourdi ne vomit plus : s'il est signalé comme agresseur (contact de la frame où il
## a été étourdi), il n'étourdit personne.
func lion_touche_par_vomi(victime: Joueur, agresseur: Joueur, origine: Vector2) -> void:
	if victime == agresseur or agresseur.est_etourdi() or not _peut_etre_etourdi(victime):
		return
	victime.etourdir(DUREE_ETOURDI_VOMI, DUREE_IMMUNITE, origine, agresseur.couleur)
	agresseur.etourdissements_infliges += 1


## Un choc n'étourdit jamais (spec §5) ; il compte pour le titre « L'auto-tamponneur ».
func choc_entre_lions(a: Joueur, b: Joueur) -> void:
	if a == b or not _manche_en_cours():
		return
	a.chocs += 1
	b.chocs += 1


## Un cran de gerbe de plus (jusqu'à Joueur.CRANS_MAX) ; l'index de couleur ne compte pas.
func pastille_ramassee(joueur: Joueur, _index_couleur: int) -> bool:
	return joueur.gagner_cran()


func etoile_ramassee(joueur: Joueur) -> void:
	joueur.activer_bonus(ReglesSolo.DUREE_ETOILE)


# coeur_ramasse et progression_mesuree : ceux de la base, sans effet (aucun cœur en bataille,
# la manche se termine au chrono).


func _manche_en_cours() -> bool:
	return partie.partie_en_cours and partie.pret


## Un joueur déjà étourdi ou encore immunisé est ignoré : le peintre et la gerbe signalent leur
## contact à chaque frame, l'étourdissement ne doit pas redémarrer sans fin.
func _peut_etre_etourdi(joueur: Joueur) -> bool:
	return _manche_en_cours() and not joueur.est_etourdi() and not joueur.est_invulnerable()
```

(`est_etourdi()` est redondant avec `est_invulnerable()` tant que seul `etourdir` règle ces minuteries, qui couvre toujours l'étourdissement ; il est gardé pour que la règle se lise telle que le spec l'énonce.)

- [ ] **Step 5 : Vérifier**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` (aucune ligne ; `Scripts/ReglesBataille.gd.uid` existe), puis les tests unitaires avec délai : `== 0 échec(s) ==`, sans `SCRIPT ERROR`, avec les 19 nouvelles vérifications (1 dans « -- Règles », 18 dans « -- Règles de bataille »). Puis le smoke test (inchangé) : vert.

- [ ] **Step 6 : Commit**

```bash
git add Scripts/Regles.gd Scripts/ReglesBataille.gd Scripts/ReglesBataille.gd.uid tests/unitaires.gd
git commit -m "Règles de bataille : étourdissements (vomi 1,5 s, ennemi 2,5 s, puis 1 s d'immunité), crans, chocs comptés ; la base reçoit vomi, choc et couleurs de départ

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

### Task 3 : `GameState` : mise en place des modes

**Files:**
- Modify: `Scripts/GameState.gd`
- Modify: `tests/unitaires.gd` (`_run`, nouvelle fonction `_tester_modes`)

**Interfaces:**
- Consumes : Task 1 (`reinitialiser(vies, couleurs_depart)`, `nuances`), Task 2 (`ReglesBataille`, `Regles.couleurs_de_depart`).
- Produces :
  - `EtatPartie.NB_JOUEURS_MAX := 6`, `EtatPartie.PALETTE_BATAILLE: Array[Color]` (6 couleurs) ;
  - `configurer_solo()` : `ReglesSolo`, `joueurs` ramené à un joueur en place, sans couleur ;
  - `configurer_bataille(nb_joueurs: int)` (2 à 6) : `ReglesBataille`, joueurs ajoutés ou retirés en place, `index` et `couleur` de la palette ; pseudos inchangés ;
  - `nouvelle_partie()` réinitialise chaque joueur avec `regles.couleurs_de_depart(j)`.

- [ ] **Step 1 : `tests/unitaires.gd`, les vérifications**

1a. Dans `_run`, remplacer :

```gdscript
	_tester_delegation_regles()
	_tester_facade_retiree()
```

par :

```gdscript
	_tester_delegation_regles()
	_tester_modes()
	_tester_facade_retiree()
```

1b. Juste avant `func _tester_facade_retiree() -> void:`, ajouter :

```gdscript
func _tester_modes() -> void:
	print("-- Mise en place des modes")
	var gs: Node = root.get_node("GameState")
	var tableau: Array[Joueur] = gs.joueurs
	var local: Joueur = gs.joueur_local()
	gs.configurer_bataille(4)
	_check(gs.regles is ReglesBataille and gs.joueurs.size() == 4, "configurer_bataille(4) branche les règles de bataille pour 4 joueurs")
	_check(is_same(tableau, gs.joueurs) and gs.joueur_local() == local,
		"les joueurs sont ajoutés en place : même tableau, joueur local inchangé (Audio y est abonné)")
	var indices: Array = gs.joueurs.map(func(j: Joueur) -> int: return j.index)
	var couleurs: Array = gs.joueurs.map(func(j: Joueur) -> Color: return j.couleur)
	_check(indices == [0, 1, 2, 3] and couleurs == gs.PALETTE_BATAILLE.slice(0, 4),
		"chaque joueur a son index et sa couleur de la palette (%s)" % [indices])
	var troisieme: Joueur = gs.joueurs[2]
	gs.nouvelle_partie()
	_check(gs.joueurs.all(func(j: Joueur) -> bool: return j.crans == 1 and j.couleurs_debloquees == j.nuances()),
		"une nouvelle partie de bataille donne à chacun un cran et ses trois nuances")
	gs.pret = true
	troisieme.etourdir(1.0, 1.0, Vector2.ZERO, Color.TRANSPARENT)
	gs._process(0.4)
	_check(is_equal_approx(troisieme.etourdi_restant, 0.6), "GameState fait avancer tous les joueurs, pas seulement le joueur local")
	gs.configurer_bataille(2)
	_check(gs.joueurs.size() == 2 and is_same(tableau, gs.joueurs) and gs.joueur_local() == local, "moins de joueurs : retirés en place")
	gs.configurer_solo()
	_check(gs.regles is ReglesSolo and gs.joueurs.size() == 1 and gs.joueur_local() == local and is_same(tableau, gs.joueurs),
		"bataille puis solo : règles du solo et un seul joueur, le même")
	gs.nouvelle_partie()
	_check(not local.a_une_couleur() and local.couleurs_debloquees.is_empty() and local.crans == 1,
		"le joueur du solo n'a plus de couleur (son lion retrouve son rendu d'origine) et repart sans couleur débloquée")
	gs.partie_en_cours = false
	gs.pret = false


```

(La fonction se termine en solo : `_tester_facade_retiree` et le smoke test, lancé à part, trouvent l'état par défaut.)

- [ ] **Step 2 : Lancer les tests unitaires (échec attendu)**

Run : les tests unitaires avec délai (30 s).
Expected : `SCRIPT ERROR: Invalid call. Nonexistent function 'configurer_bataille' in base 'Node (EtatPartie)'.` La fonction s'arrête là, **mais la suite continue et finit sur `== 0 échec(s) ==`** : c'est le `SCRIPT ERROR` qui signale l'échec (d'où le grep).

- [ ] **Step 3 : `Scripts/GameState.gd`**

3a. Juste après `const VIES_MAX := 3`, ajouter :

```gdscript
const NB_JOUEURS_MAX := 6
## Palette de bataille, attribuée par index de joueur (planche de la phase 7). Provisoire : la
## phase 11 en fait l'attribution du salon et règle les luminosités (deutéranopie).
const PALETTE_BATAILLE: Array[Color] = [
	Color(0.90, 0.16, 0.16), Color(0.16, 0.39, 0.95), Color(0.98, 0.82, 0.10),
	Color(0.18, 0.78, 0.25), Color(0.90, 0.20, 0.85), Color(0.10, 0.85, 0.90),
]
```

3b. Remplacer :

```gdscript
## Règles de la partie : celles du solo par défaut ; la bataille branchera les siennes.
var regles: Regles
```

par :

```gdscript
## Règles de la partie : celles du solo par défaut ; `configurer_solo` et `configurer_bataille`
## les changent.
var regles: Regles
```

3c. Juste avant `func _process(delta: float) -> void:`, ajouter :

```gdscript
## Prépare une partie solo : règles du solo, un seul joueur, sans couleur (son lion garde son
## rendu d'origine). Comme `configurer_bataille`, à appeler AVANT de charger la scène de jeu :
## `Main._enter_tree` appelle `nouvelle_partie()`, puis Lion, Spawner, HUD et Main s'abonnent à
## `joueur_local()` dans leur `_ready`.
func configurer_solo() -> void:
	regles = ReglesSolo.new(self)
	joueurs.resize(1)  # en place : joueurs[0] reste le même objet
	joueur_local().couleur = Color.TRANSPARENT


## Prépare une bataille à `nb_joueurs` (2 à NB_JOUEURS_MAX) : règles de bataille, joueurs
## ajoutés ou retirés en place, index et couleur de la palette. Les pseudos ne changent pas.
func configurer_bataille(nb_joueurs: int) -> void:
	assert(nb_joueurs >= 2 and nb_joueurs <= NB_JOUEURS_MAX, "une bataille se joue de 2 à %d" % NB_JOUEURS_MAX)
	regles = ReglesBataille.new(self)
	var nb_avant := joueurs.size()
	joueurs.resize(nb_joueurs)
	for i in range(nb_joueurs):
		if i >= nb_avant:
			joueurs[i] = Joueur.new()
		joueurs[i].index = i
		joueurs[i].couleur = PALETTE_BATAILLE[i]


```

3d. Dans `nouvelle_partie()`, remplacer :

```gdscript
	for j in joueurs:
		j.reinitialiser(difficulte().vies)
```

par :

```gdscript
	for j in joueurs:
		j.reinitialiser(difficulte().vies, regles.couleurs_de_depart(j))
```

(L'invariant documenté au-dessus de `var joueurs` — rempli ou réinitialisé en place, jamais réassigné — est respecté par `resize`, qui garde les premiers éléments.)

- [ ] **Step 4 : Vérifier (tests unitaires)**

`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` (aucune ligne), puis les tests unitaires avec délai : `== 0 échec(s) ==`, sans `SCRIPT ERROR`, avec les 8 vérifications de « -- Mise en place des modes ».

- [ ] **Step 5 : Vérifier le solo (smoke test inchangé)**

Le smoke test avec délai : `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR`. En solo, `nouvelle_partie` passe `ReglesSolo.couleurs_de_depart` (vide, celle de la base) : le joueur repart sans couleur, comme avant.

- [ ] **Step 6 : Commit**

```bash
git add Scripts/GameState.gd tests/unitaires.gd
git commit -m "GameState : configurer_solo() / configurer_bataille(n), joueurs redimensionnés en place, palette de bataille ; nouvelle_partie donne les couleurs de départ des règles

Co-Authored-By: <ligne imposée par l'environnement>"
```

---

## Sortie de phase

- Les deux suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR`, localement puis en CI sur la PR.
- `git diff main --stat` : 5 fichiers de code (`Scripts/Joueur.gd`, `Scripts/Regles.gd`, `Scripts/ReglesBataille.gd`, `Scripts/GameState.gd`, `tests/unitaires.gd`), le `.uid` de `ReglesBataille` et la documentation. `Scripts/ReglesSolo.gd`, `Scripts/Lion.gd`, les scènes et `tests/smoke_test.gd` sont intacts.
- `grep -rn "configurer_bataille\|ReglesBataille" Scripts | grep -v "^Scripts/ReglesBataille.gd\|^Scripts/GameState.gd"` : aucune ligne (rien ne branche encore la bataille).
- Rappeler à l'utilisateur la suite : la phase 8 bis (`docs/superpowers/plans/2026-09-25-phase-08bis-lion.md`) branche ces règles sur le lion ; les reports nommés sont dans la feuille de route (8 ter, 14 bis, 17 bis, branchement des modes en phase 10).
