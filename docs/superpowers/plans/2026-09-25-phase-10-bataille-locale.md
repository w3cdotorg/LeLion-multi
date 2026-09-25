# Phase 10 : bataille locale (1/3), les règles du mode, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** les règles répondent à toutes les questions de mode que la scène de bataille (phase 10 bis) va leur poser : la taille de l'écran (2000×648 en solo, 2000×1125 en bataille), l'avancement de la partie (la ville peinte rapportée au seuil en solo, le temps de la manche en bataille), ce qui peut apparaître (pastille et sa couleur, étoile, cœurs) ; `manche_en_cours()` devient publique (la ville la lit) ; la vérification « une passe pleine vitesse vole des cellules » des tests unitaires devient discriminante. **Rien ne change encore dans le jeu** : le Spawner, le peintre et `Main` ne lisent ces réponses qu'à partir de la phase 10 bis ; le solo reste strictement identique.

**Architecture:** la base `Regles` gagne six requêtes sans effet (écran du solo, avancement nul, rien n'apparaît) et la constante `TAILLE_ECRAN_SOLO` ; `ReglesSolo` et `ReglesBataille` les redéfinissent. Les réponses du solo reproduisent exactement les conditions que le Spawner code en dur aujourd'hui (elles lisent `partie.joueur_local()`, l'unique joueur du solo) ; celles de la bataille ne dépendent d'aucun joueur. `Regles._manche_en_cours()` est renommée `manche_en_cours()` chez tous ses appelants, dont `Ville.peindre`.

**Tech Stack:** Godot 4.7.2, GDScript typé, tests headless (`tests/unitaires.gd`, `tests/smoke_test.gd`).

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1 `Regles`, §2 fin de manche à 90 s, §7 viewport, §8 musique au temps restant) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (lignes 10, 10 bis, 10 ter ; points de vigilance « phase 10 » et « prochaine phase qui touche `Scripts/Regles.gd` ») · suites : `docs/superpowers/plans/2026-09-25-phase-10bis-scene-bataille.md`, `docs/superpowers/plans/2026-09-25-phase-10ter-reglage-manche.md`.

## Découpage de la phase 10 en trois

La ligne 10 de la feuille de route prévoyait 4 fichiers (`Main.gd`, `Spawner.gd`, `Boss.gd`, `tests/bataille_test.gd`). Le code réel en demande 15 :

- les conditions d'apparition doivent passer par les règles (point de vigilance) : `Regles.gd`, `ReglesSolo.gd`, `ReglesBataille.gd` et leurs tests (`tests/unitaires.gd`) ; toucher `Regles.gd` impose le renommage de `_manche_en_cours()` (point de vigilance « prochaine phase qui touche `Scripts/Regles.gd` »), donc aussi `Ville.gd` ;
- `tests/bataille_test.gd` doit tourner en CI (`.github/workflows/ci.yml`) ;
- le réglage du territoire sur une vraie manche (point de vigilance) touche `Ville.gd` (mesures ci-dessous : c'est l'empreinte des tampons qui manque, pas les constantes), avec son test de mesure dans la même phase ;
- le pseudo caché en haut de l'écran (point de vigilance) et le décompte des chocs à l'horloge murale (trouvé en préparant ce plan) touchent `Lion.gd` ; le retour au solo depuis le titre (point de vigilance « obligatoire ») touche `Titre.gd` ; le retrait de `GameState.prochain_index_couleur()` (point de vigilance) touche `GameState.gd`.

Chaque phase touche au plus 5 fichiers de code ou de test (`CLAUDE.md`) : trois phases, chacune testable seule et validée avant la suivante.

| Phase | Objet | Fichiers | Sortie |
|---|---|---|---|
| **10** (ce plan) | Règles du mode : écran, avancement, apparitions, `manche_en_cours()` publique, vérification discriminante de la passe | ✏️ `Scripts/Regles.gd` ✏️ `Scripts/ReglesSolo.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `Scripts/Ville.gd` ✏️ `tests/unitaires.gd` | tests verts |
| **10 bis** | Scène de bataille locale en 16:9 : N lions, écran, ciel et caméra calculés, apparitions par les règles et à l'échelle de l'écran, taille et vitesse du peintre ; test à 4 lions pilotés dans un seul processus, en CI | ✏️ `Scripts/Main.gd` ✏️ `Scripts/Spawner.gd` ✏️ `Scripts/Boss.gd` ➕ `tests/bataille_test.gd` ✏️ `.github/workflows/ci.yml` | tests verts, CI verte |
| **10 ter** | Réglage de la manche à 4 : empreinte du territoire, pseudo jamais caché, chocs en temps de jeu, retour au titre en solo, `prochain_index_couleur()` retiré | ✏️ `Scripts/Ville.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scripts/Titre.gd` ✏️ `Scripts/GameState.gd` ✏️ `tests/bataille_test.gd` | ◉ manche à 4 |

Pourquoi un fichier de test à part plutôt qu'une section du smoke test : lancé avec `--fixed-fps 60`, `tests/bataille_test.gd` joue une manche entière de 90 s en 2 à 5 secondes (le smoke test, lui, tourne à l'horloge : 90 s de plus à chaque passage, ×5 pour la validation) ; il part d'un `GameState` vierge (le smoke test enchaîne une quinzaine de parties sur le même autoload) ; il vit en 16:9 du début à la fin. Il coûte `ci.yml`, qui tient dans la phase 10 bis.

## Mesures faites pour préparer ce plan (25/09, machine du plan, projet copié hors du dépôt)

Elles fondent les décisions des trois phases ; les tests de la 10 bis et de la 10 ter les reprennent.

1. **Viewport** : en headless, `root.content_scale_size = Vector2i(2000, 1125)` s'applique aussitôt (`get_visible_rect()` et `get_viewport_rect()` d'un nœud valent (2000, 1125) sans attendre de frame) ; retour à (2000, 648) de même. La taille de départ vaut (2000, 648) (`project.godot` ne fixe que la largeur, la hauteur par défaut de Godot est 648).
2. **`--fixed-fps 60`** : 600 ticks physiques en 6 ms au lieu de 10 s. `create_timer`, les tweens et `delta` suivent le temps de jeu ; `Time.get_ticks_msec()` reste l'horloge murale (d'où le point des chocs, phase 10 ter).
3. **Coût de génération d'un jeu de tampons** (`Ville._generer_tampons`, 3 nuances) : 0,5 ms (16 px), 0,8 (21), 1,2 (26), 1,7 (31), 2,3 (36), 3,0 (41), 3,7 (46) ; étoile XXL : 1,8 (32) à 14,6 ms (92). Les 14 jeux d'un joueur : 65 ms. Manche à 4 pilotée (90 s, pastilles et étoiles ramassées) : 15 à 17 jeux générés, jamais plus d'un dans une même frame. Décision (phase 10 bis, Task 5) : **pas de pré-génération en local** ; la phase 14 la réévalue, puisque chaque client générera aussi ses jeux.
4. **Réglage du territoire, passe pleine vitesse** (un lion seul sur une ville vierge, 350 px/s, hauteur de jet médiane du pilote de la démo ; cellules que le territoire fait compter / cellules que compte la couverture du solo pour la même passe ; puis part des cellules d'un premier lion que la même passe d'un second lui vole) :

   | | 16 px | 21 px | 31 px | 46 px |
   |---|---|---|---|---|
   | actuel, Skyline | 0,52 / 9 % | 0,75 / 57 % | 0,68 / 99 % | 0,77 / 97 % |
   | actuel, Métropole | 0,82 / 11 % | 0,85 / 62 % | 0,92 / 100 % | 0,90 / 96 % |
   | actuel, Village | 0,42 / 8 % | 0,66 / 49 % | 0,63 / 97 % | 0,80 / 98 % |
   | empreinte + 4 px, Skyline | 0,90 / 57 % | 0,86 / 88 % | 0,93 / 73 % | 0,94 / 80 % |
   | empreinte + 4 px, Métropole | 1,21 / 62 % | 0,95 / 95 % | 1,15 / 80 % | 1,08 / 82 % |
   | empreinte + 4 px, Village | 0,87 / 49 % | 0,82 / 85 % | 0,90 / 69 % | 0,95 / 79 % |

   `GAIN = 6` (2 tampons pour posséder) ne change presque rien (0,54 au lieu de 0,52 à 16 px) : une passe donne déjà 5 à 7 tampons aux cellules de son tracé, toutes celles qu'elle touche comptent ; ce qui manque, ce sont les cellules que le tampon recouvre sans que leur centre soit à moins du rayon. Décision (phase 10 ter) : `GAIN`, `SEUIL_POSSESSION` et `CHARGE_MAX` restent (4, 12, 12) ; la ville tamponne le territoire avec le rayon + une demi-cellule (4 px).
5. **Manche à 4 pilotée** (90 s, couloirs voisins qui se chevauchent) : chaque lion finit avec des cellules, 1 200 à 1 500 cellules chargées dont 8 à 16 % ne comptent pour personne, des centaines de vols, les crans montent jusqu'à 6 ou 7. Chocs : 4 à 8 par lion à l'horloge murale sous `--fixed-fps`, 46 à 71 au temps de jeu (le délai anti-rafale de 0,3 s mesuré à l'horloge murale bloque presque tous les chocs quand les frames vont plus vite que le temps réel).

## Points de vigilance « phase 10 » de la feuille de route : où chacun est traité

| Point | Traité par |
|---|---|
| Lions non locaux : `joueur` et `commandes` avant `add_child` (phases 10 et 14) | 10 bis, Task 1 (`Main._ajouter_lions`) ; reste la phase 14 (`spawn_function`) |
| Conditions d'apparition par les règles (étoile, cœurs) | 10, Task 2 (règles) ; 10 bis, Task 2 (Spawner) |
| `Spawner` et `GameState.prochain_index_couleur()` | 10, Task 2 (`pastille_a_offrir`) ; 10 bis, Task 2 (Spawner) ; 10 ter, Task 3 (retrait) |
| Rerégler `GAIN` / `SEUIL_POSSESSION` / `CHARGE_MAX` sur une vraie manche à 4 | mesures ci-dessus ; 10 bis, Task 4 (mesures de la manche) ; 10 ter, Task 1 (empreinte, test à cibles) |
| Coût de génération des jeux de tampons | mesures ci-dessus ; 10 bis, Task 4 (mesure dans la manche) et Task 5 (décision, reste réaffecté à la phase 14) |
| `configurer_solo()` / `configurer_bataille(n)` avant la scène (obligatoire) | 10 bis, Task 1 (la scène ne configure pas le mode, le test branche la bataille avant) ; 10 ter, Task 3 (le titre remet le solo) ; le salon (phase 13) garde son point |
| Préexistant : minuteries `null` du Spawner si la partie finit pendant l'intro | 10 bis, Task 2 ; la moitié `tests/screenshots.gd` est réaffectée à la phase 19 (10 bis, Task 5) |
| Pseudo caché en haut de l'écran | 10 ter, Task 2 |
| Scores lus sur le territoire ; ce que la bataille garde de la couverture (phase 10 pour le peintre) | 10 bis, Task 3 (peintre au temps de la manche) et Task 4 (scores lus sur `ville.territoire`) ; musique et HUD restent en phase 17 |
| Prochaine phase qui touche `Scripts/Regles.gd` : renommer `_manche_en_cours()` | 10, Task 1 |
| Vérification unitaire « passe pleine vitesse » non discriminante (revue de la phase 9) | 10, Task 3 |

## Écarts assumés

1. **Les requêtes du solo lisent `partie.joueur_local()`** (l'unique joueur du solo), comme le Spawner aujourd'hui : l'appelant (le Spawner) ne passe pas de joueur. Quand la phase 11 choisira le joueur local par `id_reseau`, ces requêtes suivront sans changement.
2. **La pastille de bataille prend une couleur de l'arc-en-ciel au hasard** (`randi()`), pour l'œil seulement : `ColorPickup` affiche `GameState.couleur(index)` et les règles de bataille ignorent l'index (un cran pour tout le monde). Un aspect propre à la bataille (pastille blanche, arc-en-ciel animé) est un choix visuel laissé à l'utilisateur, hors de ce plan.
3. **`GameState.prochain_index_couleur()` coexiste une phase avec `ReglesSolo.pastille_a_offrir()`** (même règle, deux lignes) : le Spawner lit encore la première jusqu'à la phase 10 bis, qui le fait passer par les règles ; la phase 10 ter la retire (`GameState.gd` n'a pas de place ici). Ses trois vérifications unitaires deviennent celles de `ReglesSolo.pastille_a_offrir()` dès maintenant : la phase 10 ter ne touche pas `tests/unitaires.gd`.
4. **`avancement()` n'est pas borné** : le Spawner et le peintre le bornent eux-mêmes, comme aujourd'hui (`clamp(max(avancement, par_temps), 0, 1)`), ce qui garde `Spawner.difficulte()` identique au flottant près en solo.
5. **`ReglesBataille.DUREE_MANCHE = 90.0` arrive avant le chrono** (phase 17) : l'avancement de la bataille en a besoin dès la phase 10 bis (vitesse du peintre, difficulté des ennemis). `int(avancement() × 3)` donne d'ailleurs les couches de musique de la spec §8 (arpèges à 30 s écoulées, mélodie à 60 s), pour la phase 17.
6. **Pas de nettoyage préalable (« Step 0 »)** : `tests/unitaires.gd` dépasse 300 lignes mais ne reçoit que des vérifications (aucune refonte) ; les scripts touchés font moins de 300 lignes.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`, sur la branche `phase-10-bataille-locale`.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations.
- Fichiers de la phase (5) : ✏️ `Scripts/Regles.gd`, ✏️ `Scripts/ReglesSolo.gd`, ✏️ `Scripts/ReglesBataille.gd`, ✏️ `Scripts/Ville.gd`, ✏️ `tests/unitaires.gd`. Aucun nouveau script, donc aucun `.uid`. La spec et la feuille de route ne comptent pas.
- Solo strictement identique : le jeu ne lit aucune des nouvelles requêtes avant la phase 10 bis ; le renommage ne change aucun comportement. Le smoke test n'est pas modifié et reste vert.
- **Toujours lancer un test Godot avec un délai maximal** (une erreur de script avant `quit()` bloque le processus headless) et chercher les erreurs dans la sortie (une `SCRIPT ERROR` dans une fonction appelée ne change pas le code de sortie) :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/unitaires.gd; O=""; ( godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|MESURE|== " "$TMPDIR/t.log"`
  (`T=tests/smoke_test.gd` pour le smoke test ; une suite qui passe n'affiche que ses deux lignes `== … ==`). Un « resources still in use at exit » final est le bruit connu.
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : `tests/unitaires.gd` nomme les règles, `Joueur`, `Territoire` et `EtatPartie` (qui ne nomment aucun autoload), jamais `Lion`, `Ennemi` ni la ville. Les règles reçoivent l'état de partie (`EtatPartie`, l'autoload `GameState` récupéré par `root.get_node("GameState")`).
- `GameState.joueurs` est réinitialisé en place, jamais réassigné (`Audio` s'abonne une fois à `joueurs[0]`) : les tests appellent `reinitialiser` sur le joueur local, jamais `joueurs = …`.
- Le smoke test se valide sur **5 passages consécutifs verts** (la phase touche `Ville.gd`, qu'il exerce).
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Renommage incomplet** : un appelant garde `_manche_en_cours()` ; la ville ne l'appelle qu'en bataille, en peignant, donc seul le smoke test (section « Territoire ») le verrait, en `SCRIPT ERROR` sans changer le code de sortie. → « manche_en_cours() est publique : la ville la lit » (Task 1) + recherche de `_manche_en_cours` sur `Scripts/` et `tests/` + smoke test lu avec le filtre `SCRIPT ERROR`.
2. **Apparitions du solo qui dérivent** des conditions actuelles du Spawner : étoile dès 2 couleurs et jamais pendant une gerbe XXL, cœurs en Facile seulement et sous `VIES_MAX`, pastille = rang de la prochaine couleur de l'arc-en-ciel, -1 une fois les 7 débloquées. → vérifications « Apparitions du solo » (Task 2).
3. **Bataille qui dépend du joueur local** : étoile refusée parce que le joueur local est en gerbe XXL ou sans couleur, cœurs en Facile, pastille d'index invalide pour `ColorPickup`. → « l'étoile peut toujours apparaître, même si le joueur local… », « aucun cœur en bataille, même en Facile… », « une pastille est toujours offerte, d'une couleur valide… » (Task 2).
4. **Avancement** : borné en solo (la difficulté du Spawner changerait au-delà du seuil) ou lié à la ville peinte en bataille (le peintre accélérerait avec une couverture qui ne dit rien de la fin d'une bataille). → « au-delà du seuil, l'avancement dépasse 1 », « l'avancement de la bataille est le temps de la manche (45 s sur 90), pas la ville peinte » (Task 2).
5. **Vérification de la passe pleine vitesse qui passe même avec l'ancien réglage** (`CHARGE_MAX = 24`), parce que le premier lion ne charge sa bande qu'au seuil. → pré-condition « chargée au maximum » et échec vérifié sous `CHARGE_MAX = 24`, modification temporaire annulée (Task 3).

---

### Task 0 : documentation (spec : ce que donnent les règles)

**Files:**
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1, ligne `Regles`)

Les trois plans de la phase 10 (celui-ci, `2026-09-25-phase-10bis-scene-bataille.md`, `2026-09-25-phase-10ter-reglage-manche.md`) et la mise à jour du tableau de la feuille de route ont été commités par le commit de planification : vérifier (`git log --oneline -1 -- docs/superpowers/plans/2026-09-25-phase-10ter-reglage-manche.md` : une ligne), sans les recommiter. **Ne jamais modifier les fichiers des plans** (ni réécriture, ni résumé) ; seuls la spec (ici) et la feuille de route (Task 4) sont édités.

- [ ] **Step 1 : spec, §3.1 ligne `Regles`**

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
| `Regles` (RefCounted, détenu par `GameState`) | Reçoit les événements (lion touché par ennemi, par vomi, pastille ramassée, choc, vol de cellules, fin de chrono, progression), chacun pour le `Joueur` concerné, et décide des effets. Donne aussi les couleurs de départ de chaque joueur (aucune en solo, ses trois nuances en bataille) et dit si la partie se joue au territoire (en bataille seulement). `ReglesSolo` / `ReglesBataille`. S'exécute **sur l'hôte uniquement**. | `GameState`, `Joueur` |
```

par :

```markdown
| `Regles` (RefCounted, détenu par `GameState`) | Reçoit les événements (lion touché par ennemi, par vomi, pastille ramassée, choc, vol de cellules, fin de chrono, progression), chacun pour le `Joueur` concerné, et décide des effets. Donne aussi les couleurs de départ de chaque joueur (aucune en solo, ses trois nuances en bataille), dit si la partie se joue au territoire (en bataille seulement), donne l'écran du mode (2000×648 en solo, 2000×1125 en bataille), l'avancement de la partie (la ville peinte rapportée au seuil en solo, le temps de la manche en bataille : il accélère le peintre et les ennemis) et ce qui peut apparaître (pastille et sa couleur, étoile, cœurs), que lit le Spawner. `ReglesSolo` / `ReglesBataille`. S'exécute **sur l'hôte uniquement**. | `GameState`, `Joueur` |
```

- [ ] **Step 2 : Vérifier et committer**

Run : `git diff --stat docs/`
Expected : la spec seule, une ligne changée.

```bash
git add docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md
git commit -m "Spec : les règles donnent l'écran du mode, l'avancement de la partie et ce qui peut apparaître

<ligne fournie par l'environnement>"
```

---

### Task 1 : `manche_en_cours()` publique

**Files:**
- Modify: `Scripts/Regles.gd` (fin du fichier)
- Modify: `Scripts/ReglesSolo.gd` (`lion_touche_par_ennemi`)
- Modify: `Scripts/ReglesBataille.gd` (`choc_entre_lions`, `vol_de_cellules`, `_peut_etre_etourdi`)
- Modify: `Scripts/Ville.gd` (`peindre`)
- Test: `tests/unitaires.gd` (`_tester_regles_solo`, règles de base)

**Interfaces:**
- Consumes : `Regles` (phase 9), `Ville.peindre` (phase 9 bis).
- Produces : `Regles.manche_en_cours() -> bool` (partie en cours et intro finie), publique ; plus aucun `_manche_en_cours` dans `Scripts/` ni `tests/`.

- [ ] **Step 1 : le test**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_check(not base.compte_le_territoire() and not ReglesSolo.new(gs).compte_le_territoire(),
		"ni les règles de base ni celles du solo ne se jouent au territoire")
```

par :

```gdscript
	_check(not base.compte_le_territoire() and not ReglesSolo.new(gs).compte_le_territoire(),
		"ni les règles de base ni celles du solo ne se jouent au territoire")
	_check(base.has_method("manche_en_cours") and not base.has_method("_manche_en_cours"),
		"manche_en_cours() est publique : la ville la lit")
```

- [ ] **Step 2 : le lancer, il échoue**

Run : la commande de délai des Global Constraints avec `T=tests/unitaires.gd`.
Expected : `❌ manche_en_cours() est publique : la ville la lit` puis `== 1 échec(s) ==`.

- [ ] **Step 3 : renommer chez tous les appelants**

3a. Dans `Scripts/Regles.gd`, remplacer :

```gdscript
## Vrai pendant le jeu proprement dit : partie en cours et intro « Prêt ? Vomissez ! » finie.
func _manche_en_cours() -> bool:
```

par :

```gdscript
## Vrai pendant le jeu proprement dit : partie en cours et intro « Prêt ? Vomissez ! » finie.
## Lu aussi par la ville, qui ne tamponne le territoire que pendant la manche.
func manche_en_cours() -> bool:
```

3b. Dans `Scripts/ReglesSolo.gd`, remplacer :

```gdscript
	if not _manche_en_cours() or joueur.est_invulnerable():
```

par :

```gdscript
	if not manche_en_cours() or joueur.est_invulnerable():
```

3c. Dans `Scripts/ReglesBataille.gd`, remplacer les trois appels :

```gdscript
	if a == b or not _manche_en_cours():
```

par :

```gdscript
	if a == b or not manche_en_cours():
```

puis :

```gdscript
	if nb > 0 and _manche_en_cours():
```

par :

```gdscript
	if nb > 0 and manche_en_cours():
```

puis :

```gdscript
	return _manche_en_cours() and not joueur.est_etourdi() and not joueur.est_invulnerable()
```

par :

```gdscript
	return manche_en_cours() and not joueur.est_etourdi() and not joueur.est_invulnerable()
```

3d. Dans `Scripts/Ville.gd`, remplacer :

```gdscript
	if territoire != null and multiplayer.is_server() and GameState.regles._manche_en_cours():
```

par :

```gdscript
	if territoire != null and multiplayer.is_server() and GameState.regles.manche_en_cours():
```

- [ ] **Step 4 : vérifier qu'aucun appelant n'est oublié**

Le nom n'apparaît qu'en appel direct : pas de chaîne, de `call()`, de `has_method` (sauf le test), d'interface ni de barrel en GDScript. Chercher chaque forme :

Run : `grep -rn "_manche_en_cours" Scripts tests ; grep -rn "\"manche_en_cours\"\|call(\"_manche" Scripts tests`
Expected : chaque recherche ne trouve que la ligne du test (`tests/unitaires.gd`, `base.has_method("manche_en_cours") and not base.has_method("_manche_en_cours")`).

Run : `godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` (après l'export `PATH`)
Expected : aucune ligne.

- [ ] **Step 5 : les tests passent**

Run : la commande de délai avec `T=tests/unitaires.gd`, puis avec `T=tests/smoke_test.gd` (la section « Territoire » fait peindre la ville de bataille, qui appelle `manche_en_cours()`).
Expected : `== 0 échec(s) ==` pour les deux, aucune ligne `SCRIPT ERROR`.

- [ ] **Step 6 : Commit**

```bash
git add Scripts/Regles.gd Scripts/ReglesSolo.gd Scripts/ReglesBataille.gd Scripts/Ville.gd tests/unitaires.gd
git commit -m "Règles : manche_en_cours() devient publique (la ville la lit pour tamponner le territoire)

<ligne fournie par l'environnement>"
```

---

### Task 2 : les règles donnent l'écran, l'avancement et les apparitions

**Files:**
- Modify: `Scripts/Regles.gd` (constantes, requêtes après `compte_le_territoire`)
- Modify: `Scripts/ReglesSolo.gd` (docstring, constante, requêtes avant `progression_mesuree`)
- Modify: `Scripts/ReglesBataille.gd` (docstring, constantes, requêtes après `compte_le_territoire`, commentaire de fin)
- Test: `tests/unitaires.gd` (`_tester_game_state`, `_tester_regles_solo`, `_tester_regles_bataille`)

**Interfaces:**
- Consumes : `EtatPartie.joueur_local()`, `progression`, `seuil_victoire()`, `temps_ecoule`, `difficulte()`, `nb_couleurs_total()`, `VIES_MAX` ; `Joueur.couleurs_debloquees`, `bonus_actif()`, `vies`.
- Produces (lus par le Spawner, le peintre et `Main` en phase 10 bis) :
  - `const Regles.TAILLE_ECRAN_SOLO := Vector2i(2000, 648)` ;
  - `Regles.taille_ecran() -> Vector2i` : base et solo `TAILLE_ECRAN_SOLO` ; bataille `ReglesBataille.TAILLE_ECRAN = Vector2i(2000, 1125)` ;
  - `Regles.avancement() -> float` (non borné) : base 0 ; solo `progression / seuil_victoire()` ; bataille `temps_ecoule / ReglesBataille.DUREE_MANCHE` (`DUREE_MANCHE := 90.0`) ;
  - `Regles.pastille_a_offrir() -> int` (index de l'arc-en-ciel, -1 = aucune) : base -1 ; solo le nombre de couleurs du joueur local tant qu'il en reste ; bataille `randi() % nb_couleurs_total()` ;
  - `Regles.etoile_peut_apparaitre() -> bool` : base faux ; solo dès `ReglesSolo.COULEURS_POUR_ETOILE` (2) couleurs et hors gerbe XXL ; bataille vrai ;
  - `Regles.coeurs_en_jeu() -> bool` : base et bataille faux ; solo `difficulte().pickups_coeur` ;
  - `Regles.coeur_peut_apparaitre() -> bool` : base et bataille faux ; solo `joueur_local().vies < VIES_MAX`.

- [ ] **Step 1 : les tests**

1a. Les vérifications de `prochain_index_couleur` deviennent celles des règles (écart 3). Dans `tests/unitaires.gd`, supprimer ce bloc de `_tester_game_state` (remplacer par rien) :

```gdscript
	# Prochaine couleur à offrir (lue par le Spawner)
	_check(gs.prochain_index_couleur() == 0, "sans couleur, la prochaine pastille est la première")
	j.debloquer_couleur(gs.couleur(0))
	_check(gs.prochain_index_couleur() == 1, "prochain_index_couleur suit les couleurs du joueur local")
	for i in range(1, gs.nb_couleurs_total()):
		j.debloquer_couleur(gs.couleur(i))
	_check(gs.prochain_index_couleur() == -1, "toutes les couleurs débloquées : plus de pastille à offrir")

```

1b. Règles de base. Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_check(base.has_method("manche_en_cours") and not base.has_method("_manche_en_cours"),
		"manche_en_cours() est publique : la ville la lit")
```

par :

```gdscript
	_check(base.pastille_a_offrir() == -1 and not base.etoile_peut_apparaitre() and not base.coeurs_en_jeu()
		and not base.coeur_peut_apparaitre() and base.avancement() == 0.0 and base.taille_ecran() == Regles.TAILLE_ECRAN_SOLO,
		"les règles de base ne font rien apparaître, rien n'accélère, l'écran est celui du solo (2000×648)")
	_check(base.has_method("manche_en_cours") and not base.has_method("_manche_en_cours"),
		"manche_en_cours() est publique : la ville la lit")
```

1c. Règles du solo. Dans `tests/unitaires.gd`, remplacer :

```gdscript
	# Progression : victoire au seuil, une seule fois
```

par :

```gdscript
	# Apparitions du solo : elles suivent le joueur local, l'unique joueur (lues par le Spawner)
	local.reinitialiser(3)
	_check(r.pastille_a_offrir() == 0 and not r.etoile_peut_apparaitre(),
		"sans couleur, la prochaine pastille est la première de l'arc-en-ciel ; pas d'étoile")
	local.debloquer_couleur(gs.couleur(0))
	_check(r.pastille_a_offrir() == 1 and not r.etoile_peut_apparaitre(),
		"une couleur : la pastille suivante est la deuxième, toujours pas d'étoile")
	local.debloquer_couleur(gs.couleur(1))
	_check(r.pastille_a_offrir() == 2 and r.etoile_peut_apparaitre(), "dès deux couleurs, l'étoile peut apparaître")
	local.activer_bonus(1.0)
	_check(not r.etoile_peut_apparaitre(), "pas d'étoile pendant une gerbe XXL")
	local.bonus_restant = 0.0
	for i in range(2, gs.nb_couleurs_total()):
		local.debloquer_couleur(gs.couleur(i))
	_check(r.pastille_a_offrir() == -1, "toutes les couleurs débloquées : plus de pastille à offrir")
	_check(r.coeurs_en_jeu() and not r.coeur_peut_apparaitre(), "en Facile, des cœurs, mais aucun tant que le joueur a toutes ses vies")
	local.vies = 2
	_check(r.coeur_peut_apparaitre(), "un cœur peut apparaître dès qu'une vie manque")
	gs.difficulte_courante = 1
	var sans_coeur_moyen := not r.coeurs_en_jeu()
	gs.difficulte_courante = 2
	_check(sans_coeur_moyen and not r.coeurs_en_jeu(), "ni en Moyen ni en Hardcore")
	gs.difficulte_courante = 0
	local.reinitialiser(3)
	gs.progression = 0.425
	_check(is_equal_approx(r.avancement(), 0.5), "l'avancement du solo est la ville peinte rapportée au seuil (0,425 / 0,85)")
	gs.progression = 0.9
	_check(r.avancement() > 1.0, "au-delà du seuil, l'avancement dépasse 1 (les appelants le bornent)")
	gs.progression = 0.0
	_check(r.taille_ecran() == Vector2i(2000, 648), "l'écran du solo reste en 2000×648")

	# Progression : victoire au seuil, une seule fois
```

(`local` est le joueur local, déclaré plus haut dans la même fonction : `var local: Joueur = gs.joueur_local()`.)

1d. Règles de bataille. Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_check(rouge.cellules_volees == 5, "un vol pendant l'intro ne compte pas")
	gs.pret = true
```

par :

```gdscript
	_check(rouge.cellules_volees == 5, "un vol pendant l'intro ne compte pas")
	gs.pret = true

	# Apparitions et écran de la bataille : rien ne dépend du joueur local
	var indices_valides := true
	for i in range(50):
		var k := r.pastille_a_offrir()
		if k < 0 or k >= gs.nb_couleurs_total():
			indices_valides = false
	_check(indices_valides, "une pastille est toujours offerte, d'une couleur valide de l'arc-en-ciel (pour l'œil)")
	var local: Joueur = gs.joueur_local()
	local.reinitialiser(1)
	local.activer_bonus(1.0)
	_check(r.etoile_peut_apparaitre(), "l'étoile peut toujours apparaître, même si le joueur local n'a pas de couleur ou est en gerbe XXL")
	_check(gs.difficulte_courante == 0 and not r.coeurs_en_jeu() and not r.coeur_peut_apparaitre(),
		"aucun cœur en bataille, même en Facile et même quand le joueur local a perdu des vies")
	local.reinitialiser(3)
	gs.temps_ecoule = 45.0
	gs.progression = 1.0
	_check(is_equal_approx(r.avancement(), 0.5) and is_equal_approx(ReglesBataille.DUREE_MANCHE, 90.0),
		"l'avancement de la bataille est le temps de la manche (45 s sur 90), pas la ville peinte")
	gs.temps_ecoule = 0.0
	gs.progression = 0.0
	_check(r.avancement() == 0.0, "au départ de la manche, l'avancement est nul")
	_check(r.taille_ecran() == Vector2i(2000, 1125), "l'écran de la bataille est en 16:9 (2000×1125)")
```

- [ ] **Step 2 : les lancer, ils échouent**

Run : la commande de délai avec `T=tests/unitaires.gd`.
Expected : `SCRIPT ERROR: Parse Error: Function "pastille_a_offrir()" not found in base Regles.` (ou la première requête manquante rencontrée) : le script ne se charge pas, Godot rend la main aussitôt.

- [ ] **Step 3 : la base `Regles`**

3a. Dans `Scripts/Regles.gd`, remplacer :

```gdscript
## Durée de la gerbe XXL donnée par une étoile, la même en solo et en bataille.
const DUREE_ETOILE := 8.0
```

par :

```gdscript
## Durée de la gerbe XXL donnée par une étoile, la même en solo et en bataille.
const DUREE_ETOILE := 8.0
## Écran du solo (spec §7) : la taille de référence des hauteurs d'apparition et du peintre, qui
## gardent en bataille leurs dimensions du solo.
const TAILLE_ECRAN_SOLO := Vector2i(2000, 648)
```

3b. Dans `Scripts/Regles.gd`, remplacer :

```gdscript
func compte_le_territoire() -> bool:
	return false
```

par :

```gdscript
func compte_le_territoire() -> bool:
	return false


## Taille de l'écran du mode (`content_scale_size`, spec §7), appliquée par `Main` en entrant
## dans la scène de jeu : celle du solo par défaut.
func taille_ecran() -> Vector2i:
	return TAILLE_ECRAN_SOLO


## Avancement de la partie, de 0 (début) à 1 (fin en vue), qui accélère le peintre et les
## apparitions d'ennemis. Peut dépasser 1 : les appelants le bornent. Nul par défaut (rien
## n'accélère).
func avancement() -> float:
	return 0.0


## Index de la couleur de l'arc-en-ciel de la prochaine pastille à faire apparaître, -1 pour
## aucune (lu par le Spawner quand une pastille est due). Aucune par défaut.
func pastille_a_offrir() -> int:
	return -1


## Vrai si l'étoile XXL peut apparaître maintenant (lu par le Spawner à chaque échéance).
func etoile_peut_apparaitre() -> bool:
	return false


## Vrai si la partie a des cœurs à ramasser (le Spawner ne programme leurs apparitions que si
## c'est le cas).
func coeurs_en_jeu() -> bool:
	return false


## Vrai si un cœur peut apparaître maintenant (lu par le Spawner à chaque échéance, quand la
## partie a des cœurs).
func coeur_peut_apparaitre() -> bool:
	return false
```

- [ ] **Step 4 : `ReglesSolo`**

4a. Dans `Scripts/ReglesSolo.gd`, remplacer :

```gdscript
## victoire quand la ville est peinte au seuil de la difficulté. La durée de l'étoile XXL est
## celle de la base (`Regles.DUREE_ETOILE`).
```

par :

```gdscript
## victoire quand la ville est peinte au seuil de la difficulté. La durée de l'étoile XXL est
## celle de la base (`Regles.DUREE_ETOILE`). Les apparitions suivent le joueur local, l'unique
## joueur du solo.
```

4b. Dans `Scripts/ReglesSolo.gd`, remplacer :

```gdscript
const DUREE_INVULNERABILITE := 1.5
```

par :

```gdscript
const DUREE_INVULNERABILITE := 1.5
## Couleurs débloquées à partir desquelles l'étoile XXL peut apparaître.
const COULEURS_POUR_ETOILE := 2
```

4c. Dans `Scripts/ReglesSolo.gd`, remplacer :

```gdscript
func progression_mesuree(ratio: float) -> void:
```

par :

```gdscript
## La part de la ville peinte, rapportée au seuil de victoire de la difficulté.
func avancement() -> float:
	return partie.progression / partie.seuil_victoire()


## La prochaine couleur de l'arc-en-ciel, dans l'ordre, tant qu'il en reste à débloquer.
func pastille_a_offrir() -> int:
	var i := partie.joueur_local().couleurs_debloquees.size()
	return i if i < partie.nb_couleurs_total() else -1


## Dès deux couleurs, et jamais pendant une gerbe XXL.
func etoile_peut_apparaitre() -> bool:
	var joueur := partie.joueur_local()
	return joueur.couleurs_debloquees.size() >= COULEURS_POUR_ETOILE and not joueur.bonus_actif()


## Selon la difficulté (Facile seulement).
func coeurs_en_jeu() -> bool:
	return partie.difficulte().pickups_coeur


## Tant que le joueur n'a pas toutes ses vies.
func coeur_peut_apparaitre() -> bool:
	return partie.joueur_local().vies < partie.VIES_MAX


func progression_mesuree(ratio: float) -> void:
```

- [ ] **Step 5 : `ReglesBataille`**

5a. Dans `Scripts/ReglesBataille.gd`, remplacer :

```gdscript
## territoire, que tient la ville (`Territoire`) : les règles en comptent les vols. La fin de
## manche au chrono (phase 17) s'y ajoutera.
```

par :

```gdscript
## territoire, que tient la ville (`Territoire`) : les règles en comptent les vols. L'écran est
## en 16:9 ; une pastille est toujours offerte, l'étoile toujours possible, jamais de cœur. La
## fin de manche au chrono (phase 17) s'y ajoutera.
```

5b. Dans `Scripts/ReglesBataille.gd`, remplacer :

```gdscript
const DUREE_IMMUNITE := 1.0
```

par :

```gdscript
const DUREE_IMMUNITE := 1.0
## Durée d'une manche (spec §2), dont le temps écoulé fait l'avancement. Le chrono qui la termine
## vient en phase 17.
const DUREE_MANCHE := 90.0
## Écran de la bataille (spec §7) : 16:9, la skyline posée en bas sous un grand ciel.
const TAILLE_ECRAN := Vector2i(2000, 1125)
```

5c. Dans `Scripts/ReglesBataille.gd`, remplacer :

```gdscript
func compte_le_territoire() -> bool:
	return true
```

par :

```gdscript
func compte_le_territoire() -> bool:
	return true


func taille_ecran() -> Vector2i:
	return TAILLE_ECRAN


## Le temps de la manche : la ville peinte ne dit rien de la fin d'une bataille.
func avancement() -> float:
	return partie.temps_ecoule / DUREE_MANCHE


## Une pastille donne un cran quelle que soit sa couleur : une couleur de l'arc-en-ciel au hasard,
## pour l'œil seulement.
func pastille_a_offrir() -> int:
	return randi() % partie.nb_couleurs_total()


## Chaque lion vomit dès le départ : l'étoile peut toujours apparaître (premier arrivé, premier
## servi), quel que soit l'état du joueur local.
func etoile_peut_apparaitre() -> bool:
	return true
```

5d. Dans `Scripts/ReglesBataille.gd`, remplacer :

```gdscript
# coeur_ramasse et progression_mesuree : ceux de la base, sans effet (aucun cœur en bataille,
# la manche se termine au chrono).
```

par :

```gdscript
# coeur_ramasse, progression_mesuree, coeurs_en_jeu et coeur_peut_apparaitre : ceux de la base,
# sans effet (aucun cœur en bataille, la manche se termine au chrono).
```

- [ ] **Step 6 : les tests passent, le solo n'a pas bougé**

Run : `godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"`
Expected : aucune ligne.

Run : la commande de délai avec `T=tests/unitaires.gd`, puis avec `T=tests/smoke_test.gd`.
Expected : `== 0 échec(s) ==` pour les deux, sans `SCRIPT ERROR`.

Run : `grep -rn "pastille_a_offrir\|etoile_peut_apparaitre\|coeurs_en_jeu\|coeur_peut_apparaitre\|taille_ecran\|\.avancement()" Scripts | grep -v "^Scripts/Regles"`
Expected : aucune ligne (rien ne les lit encore dans le jeu ; la phase 10 bis les branche).

- [ ] **Step 7 : Commit**

```bash
git add Scripts/Regles.gd Scripts/ReglesSolo.gd Scripts/ReglesBataille.gd tests/unitaires.gd
git commit -m "Règles : écran du mode, avancement de la partie et apparitions (pastille, étoile, cœurs) décidés par les règles ; les vérifications de prochain_index_couleur passent à ReglesSolo.pastille_a_offrir

<ligne fournie par l'environnement>"
```

---

### Task 3 : vérification discriminante de la passe pleine vitesse

**Files:**
- Test: `tests/unitaires.gd` (`_tester_territoire`, bloc « Réglage (fiche de correction du 25/09) »)

**Interfaces:**
- Consumes : `Territoire.GAIN`, `Territoire.CHARGE_MAX`, `Territoire.charge`, `Territoire.cellules_de`.
- Produces : rien pour les autres tâches ; la vérification échoue désormais avec `CHARGE_MAX = 24`.

La vérification actuelle charge la bande du premier lion avec `n_prise` tampons (le seuil, 12) : avec l'ancien `CHARGE_MAX = 24`, sa bande reste à 12 et la passe de B vole quand même, si bien que la vérification ne distingue pas les deux réglages (vérifié à la préparation de ce plan : avec `CHARGE_MAX = 24`, les deux lignes « une passe pleine vitesse de B… » restent vertes). Une passe pleine vitesse charge pourtant ses cellules au maximum.

- [ ] **Step 1 : le test durci**

1a. Dans `tests/unitaires.gd`, remplacer :

```gdscript
	for rayon_b in [16, 21]:
		var largeur := 60
```

par :

```gdscript
	var n_saturer := ceili(float(Territoire.CHARGE_MAX) / Territoire.GAIN)
	for rayon_b in [16, 21]:
		var largeur := 60
```

1b. Dans `tests/unitaires.gd`, remplacer :

```gdscript
		for i in range(n_prise):
			v.tamponner(0, Vector2i(largeur * taille_cellule_bande / 2, hauteur * taille_cellule_bande / 2), 400)  # A possède toute la bande
		var avant_a := v.cellules_de(0)
```

par :

```gdscript
		# A charge sa bande au maximum, comme une passe pleine vitesse (5 à 7 tampons par cellule) :
		# chargée au seul seuil (n_prise tampons), la vérification passait aussi avec l'ancien
		# CHARGE_MAX = 24, qu'elle doit refuser.
		for i in range(n_saturer):
			v.tamponner(0, Vector2i(largeur * taille_cellule_bande / 2, hauteur * taille_cellule_bande / 2), 400)
		var avant_a := v.cellules_de(0)
		_check(v.charge(0) == Territoire.CHARGE_MAX and avant_a == largeur * hauteur,
			"(pré-condition) A possède toute la bande, chargée au maximum (%d)" % v.charge(0))
```

- [ ] **Step 2 : il passe avec le réglage actuel**

Run : la commande de délai avec `T=tests/unitaires.gd`.
Expected : `== 0 échec(s) ==` ; la sortie complète (`grep "passe pleine" "$TMPDIR/t.log"`) montre les deux passes et leur pré-condition.

- [ ] **Step 3 : il échoue avec l'ancien réglage (modification temporaire, jamais commitée)**

Run : `sed -i '' 's/^const CHARGE_MAX := SEUIL_POSSESSION/const CHARGE_MAX := 24/' Scripts/Territoire.gd`, puis la commande de délai avec `T=tests/unitaires.gd`.
Expected : entre autres, `❌ une passe pleine vitesse de B (rayon 16) sur la bande d'A lui vole des cellules (B : 0, A : 240 → 52)` et `❌ … (rayon 21) … (B : 0, A : 240 → 0)`.

Run : `git checkout Scripts/Territoire.gd && git status --short Scripts/`
Expected : aucune ligne (`Territoire.gd` intact).

- [ ] **Step 4 : Commit**

```bash
git add tests/unitaires.gd
git commit -m "Tests unitaires : la passe pleine vitesse part d'une bande chargée au maximum (la vérification ne distinguait pas CHARGE_MAX = 24)

<ligne fournie par l'environnement>"
```

---

### Task 4 : feuille de route, points de vigilance de la phase 10

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`

**Ne jamais modifier les fichiers des plans** : seule la feuille de route change ici.

- [ ] **Step 1 : le renommage, résolu (Task 1) ; le retrait de `prochain_index_couleur`, programmé**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **prochaine phase qui touche `Scripts/Regles.gd`** : `Regles._manche_en_cours()` est maintenant
  appelée de l'extérieur des règles, depuis `Scripts/Ville.gd` (phase 9 bis) : la renommer en
  `manche_en_cours()` publique. Chercher tous les appelants (`Regles`, `ReglesSolo`,
  `ReglesBataille`, `Ville`, les tests) ;
```

par :

```markdown
- **phase 10 ter** : `GameState.prochain_index_couleur()` n'a plus d'appelant depuis la phase 10 bis
  (le Spawner lit `GameState.regles.pastille_a_offrir()`, que `ReglesSolo` tient depuis la phase 10,
  vérifications unitaires comprises) : la retirer ;
```

- [ ] **Step 2 : Vérifier et committer**

Run : `grep -n "_manche_en_cours" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
Expected : aucune ligne.

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
git commit -m "Feuille de route : manche_en_cours() publique (phase 10) ; retrait de prochain_index_couleur programmé en 10 ter

<ligne fournie par l'environnement>"
```

---

## Sortie de phase

- Les deux suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR`, localement (smoke test 5 fois de suite) puis en CI sur la PR.
- `git diff main --stat` : 5 fichiers de code (`Scripts/Regles.gd`, `Scripts/ReglesSolo.gd`, `Scripts/ReglesBataille.gd`, `Scripts/Ville.gd`, `tests/unitaires.gd`) plus la spec et la feuille de route (les plans viennent du commit de planification).
- `grep -rn "_manche_en_cours" Scripts tests` : la seule ligne du test `has_method`.
- `grep -rn "prochain_index_couleur" Scripts tests` : `Scripts/GameState.gd` (la définition) et `Scripts/Spawner.gd` (son dernier appel, remplacé en phase 10 bis).
- Rappeler à l'utilisateur : rien ne change encore à l'écran ; la phase 10 bis (`docs/superpowers/plans/2026-09-25-phase-10bis-scene-bataille.md`) branche ces règles dans la scène de bataille ; la couleur des pastilles de bataille (au hasard dans l'arc-en-ciel) est un choix visuel provisoire qu'il peut vouloir trancher.
