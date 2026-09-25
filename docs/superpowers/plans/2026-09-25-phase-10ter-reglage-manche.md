# Phase 10 ter : bataille locale (3/3), le réglage de la manche à 4, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** la manche à 4 de la phase 10 bis est réglée et propre : une passe pleine vitesse fait compter au territoire à peu près les cellules que compterait la couverture du solo (0,7 à 1,3 fois, sur les 3 niveaux et 4 rayons) et vole au moins 40 % des cellules d'un adversaire dès le premier cran, grâce à l'empreinte du tampon sur le territoire (rayon + une demi-cellule), `GAIN` / `SEUIL_POSSESSION` / `CHARGE_MAX` restant (4, 12, 12) ; le pseudo d'un lion n'est jamais caché en haut de l'écran ; les chocs se décomptent en temps de jeu ; l'écran titre remet le solo (règles, un joueur sans couleur, 2000×648) avant toute partie ; `GameState.prochain_index_couleur()`, sans appelant depuis la 10 bis, disparaît. Sortie : **◉ manche à 4** (captures de la manche pilotée). **Le solo reste strictement identique.**

**Architecture:** `Ville.peindre` tamponne le territoire avec `rayon + EMPREINTE_TERRITOIRE` (`TAILLE_CELLULE / 2`, 4 px) : `Territoire.tamponner` garde sa règle (« le centre de la cellule est à moins du rayon reçu ») et ses tests unitaires, la ville traduit le tampon peint en disque de territoire. `Lion._physics_process` borne `y` à `_marge_haute()` (la hauteur du pseudo quand il s'affiche, 0 sinon). Le délai anti-rafale des chocs compare `Lion._temps` (secondes de jeu, déjà cumulées au tick physique) au lieu de `Time.get_ticks_msec()`. `Titre._ready` appelle `GameState.configurer_solo()` puis applique `GameState.regles.taille_ecran()`. `tests/bataille_test.gd` mesure la passe pleine vitesse avec de vrais lions sur une vraie ville et vérifie les cibles, et capture la manche quand on le lance avec le rendu.

**Tech Stack:** Godot 4.7.2, GDScript typé, tests headless (`tests/bataille_test.gd` avec `--fixed-fps 60`, `tests/smoke_test.gd`, `tests/unitaires.gd`), captures avec le rendu.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§5 pseudo et collisions, §6 propriété et réglage, §7 retour au titre) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 10 ter ; points de vigilance « phase 10 » qui restent) · plan de la phase 10 (découpage, **mesures du réglage**) : `docs/superpowers/plans/2026-09-25-phase-10-bataille-locale.md` · prérequis : phase 10 bis fusionnée (`tests/bataille_test.gd` et ses fonctions `_charger_bataille`, `_attendre_depart`, `_liberer`, `_tester_manche`, `_tester_solo_apres_bataille`, constantes `NB_LIONS`, `TAILLE_BATAILLE`, `HAUTEURS_JET`, `DISTANCE_PASTILLE_TENTANTE`).

## Écarts assumés

1. **Le réglage se fait sur l'empreinte, pas sur les constantes** (mesures du plan de la phase 10) : une passe donne déjà 5 à 7 tampons à chaque cellule de son tracé, donc toutes celles qu'elle touche comptent ; ce qui manquait, ce sont les cellules que le tampon recouvre sans que leur centre soit à moins du rayon (au premier cran, le territoire ne comptait que 0,42 à 0,82 fois la couverture, et une passe ne volait que 8 à 11 % des cellules d'un adversaire). `GAIN = 6` n'y changeait presque rien. La spec §6 est mise à jour. `Territoire.gd` n'est pas modifié ; son commentaire « La phase 10 rerègle ces constantes sur une vraie manche » (ligne 28-29) devient faux : réaffecté à la prochaine phase qui touche `Scripts/Territoire.gd` (phase 14, sa méthode d'affichage) par la Task 4.
2. **Les cibles de réglage** viennent de la spec (« à peu près autant de temps pour peindre une cellule qu'aujourd'hui en solo ») et du but de la fiche de correction de la phase 9 (« une seule passe pleine vitesse vole le centre de son tracé ») : rapport territoire / couverture de 0,7 à 1,3 sur chaque niveau et chaque rayon de 16 à 46 px, et au moins 40 % des cellules d'un adversaire volées par une passe. Mesuré avec l'empreinte : 0,82 à 1,21 et 49 % au moins (Village, 16 px). **Si une mesure sort des cibles** (autre machine, autre réglage des tampons) : ne pas élargir les cibles ; essayer d'abord `EMPREINTE_TERRITOIRE = TAILLE_CELLULE / 2 + 1` (5 px), puis, si le vol reste sous 40 %, `CHARGE_MAX = SEUIL_POSSESSION` inchangé et `GAIN = 6` dans `Scripts/Territoire.gd` (hors des 5 fichiers de la phase : s'arrêter et demander avant) ; noter les nouvelles mesures dans la spec §6.
3. **Le pseudo reste au-dessus du lion** : le lion ne monte plus que jusqu'à la hauteur de son étiquette (38 px) quand elle s'affiche, au lieu de passer l'étiquette sous le lion près du bord (qui cacherait la gerbe) ; 38 px sur 1125 ne gênent pas le jeu. En solo, pas d'étiquette, pas de marge.
4. **Chocs en temps de jeu** (trouvé en préparant le plan de la phase 10) : `Lion._derniers_chocs` datait les chocs à l'horloge murale ; sous `--fixed-fps`, 0,3 s de jeu passent en quelques millisecondes et le délai anti-rafale bloquait presque tous les chocs (4 à 8 par lion sur la manche de 90 s, 46 à 71 au temps de jeu) ; en jeu, une frame qui rame ferait l'inverse. `_temps` est le temps de jeu propre au lion : les deux lions d'un choc ont chacun le leur, comparé à lui-même.
5. **L'écran titre remet le solo à chaque affichage** (`configurer_solo()` : règles du solo, un joueur, couleur transparente ; puis l'écran 2000×648) : toute partie lancée d'ici (Jouer, démo, arcade) est une partie solo configurée avant le changement de scène. Le salon (phase 13) branchera la bataille juste avant de charger la scène de bataille.
6. **Les captures de la manche** (`-- --captures=<dossier>`, rendu réel) montrent aussi les pseudos : la manche donne un pseudo à chaque joueur (« Joueur 1 » à « Joueur 4 ») et le retire à la fin. Le HUD visible est encore celui du solo (phase 17).
7. **Pas de nettoyage préalable (« Step 0 »)** : `Scripts/Lion.gd` (501 lignes) et `tests/bataille_test.gd` (environ 450 lignes après la phase 10 bis) ne reçoivent que des retouches locales et des ajouts, aucune refonte ; le découpage de `Lion.gd` est prévu avant la phase 16. Les lire par morceaux (`offset` / `limit`) : `Lion.gd` dépasse 500 lignes.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations.
- Fichiers de la phase (5) : ✏️ `Scripts/Ville.gd`, ✏️ `Scripts/Lion.gd`, ✏️ `Scripts/Titre.gd`, ✏️ `Scripts/GameState.gd`, ✏️ `tests/bataille_test.gd`. Aucun nouveau script. La spec et la feuille de route ne comptent pas.
- Solo strictement identique : le territoire n'existe qu'en bataille (l'empreinte ne touche pas la couverture) ; sans pseudo, aucune marge ; les chocs n'existent qu'entre lions de bataille ; l'écran titre du solo était déjà en solo. Le smoke test n'est pas modifié et reste vert.
- **Toujours lancer un test Godot avec un délai maximal** et chercher les erreurs dans la sortie :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/bataille_test.gd; O="--fixed-fps 60"; ( godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1 & p=$!; for i in $(seq 1 150); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|MESURE|== " "$TMPDIR/t.log"`
  (`T=tests/smoke_test.gd; O=""` ou `T=tests/unitaires.gd; O=""` pour les deux autres suites). Une `SCRIPT ERROR` ne change pas le code de sortie et une erreur avant `quit()` bloque le processus. Un « resources still in use at exit » final est le bruit connu.
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`** (la CI les cherche dans toute la sortie).
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : `tests/bataille_test.gd` récupère `GameState` et `Scores` par `root.get_node(…)`, type les lions en `Node2D` / `CharacterBody2D` et la ville en `Node2D`, et ne nomme ni `Lion`, ni `Ennemi`, ni la ville ; il peut nommer `Joueur`, `Commandes`, `Territoire`, `Regles`, `ReglesSolo` et `ReglesBataille`.
- Les règles du mode sont branchées **avant** de charger une scène, jamais depuis elle ; `GameState.joueurs` est réinitialisé en place, jamais réassigné ; les pseudos donnés par un test lui sont retirés à la fin de sa section.
- `tests/bataille_test.gd` et le smoke test se valident sur **5 passages consécutifs verts**.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Un réglage qui ne tient que sur un niveau ou un rayon** : le plus serré est le Village au premier cran (0,87 et 49 %), la Métropole au premier cran monte à 1,21. → « une passe fait compter au territoire à peu près les cellules que compterait la couverture du solo (… à …, cible 0.7 à 1.3) » et « une passe pleine vitesse vole au moins 40 % des cellules d'un adversaire, dès le premier cran », mesurés sur 3 niveaux × 4 rayons (Task 1).
2. **L'empreinte qui déborde sur le solo ou sur un client** : la couverture du solo doit rester la même, et un client ne touche jamais au territoire. → smoke test inchangé, 5 passages verts, dont « un tampon isolé ne compte presque pas », « progression >= seuil après avoir tout peint » et « sur un client, la ville dessine les tampons sans toucher au territoire » (Task 1).
3. **Un pseudo caché en haut de l'écran, ou un lion sans pseudo bridé pour rien.** → « un lion collé en haut de l'écran n'y cache pas son pseudo », « un lion sans pseudo monte jusqu'au bord de l'écran » (Task 2).
4. **Des chocs décomptés à l'horloge murale** (frames plus rapides ou plus lentes que le temps réel). → « deux chocs à une demi-seconde de jeu d'écart comptent tous les deux » sous `--fixed-fps` (Task 2) ; « une poussée continue de 2 s ne rafale pas les chocs » du smoke test reste vert.
5. **Un écran titre qui laisse la bataille branchée** : une partie solo lancée après une bataille garderait ses règles, ses joueurs, sa couleur et son écran 16:9. → « l'écran titre remet le solo avant toute partie… », « l'écran titre est en 2000×648 », puis « une partie solo après une bataille repasse en 2000×648, avec un seul lion » sans autre configuration que celle du titre (Task 3).

---

### Task 0 : vérification des plans

Ce plan a été commité par le commit de planification de la phase 10 : ne pas le recommiter, **ne jamais le modifier** (ni réécriture, ni résumé). Pas d'autre étape.

---

### Task 1 : l'empreinte du territoire, réglée sur la couverture du solo

**Files:**
- Modify: `Scripts/Ville.gd` (docstring du fichier, constante, `peindre`)
- Test: `tests/bataille_test.gd` (constantes, `_run`, trois fonctions à la fin)
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§6)

**Interfaces:**
- Consumes : phase 10 bis (`_charger_bataille` n'est pas utilisé ici : scène propre, une ville et deux lions) ; `Territoire.cellules_de`, `Ville.mesurer_progression()`, `Ville.cellules_peintes`, `Ville.territoire`, `Lion.traceuse_shape` (par l'instance), `Joueur.gagner_cran()`, `Joueur.cellules_volees`.
- Produces : `const Ville.EMPREINTE_TERRITOIRE := TAILLE_CELLULE / 2` ; `Ville.peindre` tamponne le territoire avec `rayon + EMPREINTE_TERRITOIRE`. Dans le test : `CIBLE_RAPPORT_COUVERTURE := Vector2(0.7, 1.3)`, `CIBLE_PART_VOLEE := 0.4`, `_passe(lion, haut)`, `_mesurer_passe(niveau, crans) -> Vector2` (x : rapport territoire / couverture, y : part volée), `_tester_reglage_territoire()`.

Procédure de mesure : sur une ville vierge de chaque niveau (écran 2000×1125, skyline en bas), au cran 1, 2, 4 puis 7 (16, 21, 31, 46 px), un premier lion de bataille fait une passe pleine vitesse (350 px/s, élan de 20 frames, de x = 0 à x = 1700) en vomissant à la hauteur de jet médiane du pilote de la démo (200 px au-dessus du haut de la skyline) ; on compte ses cellules au territoire et la couverture du solo (`mesurer_progression`) de la même passe ; puis un second lion fait la même passe : la part des cellules du premier qu'il lui vole. Une ligne `MESURE` par passe.

- [ ] **Step 1 : le test**

1a. Dans `tests/bataille_test.gd`, remplacer :

```gdscript
const DISTANCE_PASTILLE_TENTANTE := 900.0  # le pilote de la manche va chercher une pastille dans ce rayon
```

par :

```gdscript
const DISTANCE_PASTILLE_TENTANTE := 900.0  # le pilote de la manche va chercher une pastille dans ce rayon
## Réglage du territoire (spec §6) : sur une passe pleine vitesse, les cellules que le territoire
## fait compter, rapportées à celles que compte la couverture du solo pour la même passe, restent
## dans ces bornes ; et la même passe sur les cellules d'un adversaire lui en vole au moins cette
## part.
const CIBLE_RAPPORT_COUVERTURE := Vector2(0.7, 1.3)
const CIBLE_PART_VOLEE := 0.4
```

1b. Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	await _tester_peintre()
	await _tester_manche()
```

par :

```gdscript
	await _tester_peintre()
	await _tester_reglage_territoire()
	await _tester_manche()
```

1c. Ajouter à la fin de `tests/bataille_test.gd` :

```gdscript


## Passe pleine vitesse d'un lion en vomissant, de la gauche vers x = 1700, à la hauteur de jet
## médiane du pilote de la démo ; puis la gerbe en vol retombe.
func _passe(lion: CharacterBody2D, haut: float) -> void:
	lion.global_position = Vector2(0, haut + HAUTEURS_JET[1])
	lion.commandes.direction_voulue = Vector2.RIGHT
	await _frames(20)  # l'élan : pleine vitesse avant de vomir
	lion.commandes.vomir_voulu = true
	while lion.global_position.x < 1700.0:
		await physics_frame
	lion.commandes.vomir_voulu = false
	lion.commandes.direction_voulue = Vector2.ZERO
	await _frames(60)


## Sur une ville vierge du niveau, au cran donné : x = cellules que la passe d'un premier lion
## fait compter au territoire, rapportées à celles de la couverture du solo ; y = part de ces
## cellules que la même passe d'un second lion lui vole. Scène propre : une ville, deux lions.
func _mesurer_passe(niveau: int, crans: int) -> Vector2:
	GS.niveau_courant = niveau
	GS.configurer_bataille(2)
	GS.nouvelle_partie()
	GS.pret = true
	var ville: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	root.add_child(ville)
	ville.charger_skyline(load(GS.niveau().texture))
	ville.position = Vector2(TAILLE_BATAILLE.x / 2.0, TAILLE_BATAILLE.y - ville.tex_size.y / 2.0)
	var lions: Array[CharacterBody2D] = []
	for j: Joueur in GS.joueurs:
		for i in range(crans - 1):
			j.gagner_cran()
		var l: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
		l.joueur = j
		l.commandes = Commandes.manuelles()
		l.position = Vector2.ZERO  # en haut à gauche, loin de la bande peinte
		root.add_child(l)
		lions.append(l)
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	var t: Territoire = ville.territoire
	await _passe(lions[0], haut)
	ville.mesurer_progression()
	var cellules_a := t.cellules_de(0)
	var rapport := float(cellules_a) / maxi(ville.cellules_peintes, 1)
	lions[0].global_position = Vector2.ZERO
	await _passe(lions[1], haut)
	var part_volee := float(GS.joueurs[1].cellules_volees) / maxi(cellules_a, 1)
	print("  MESURE niveau %d, rayon %d : territoire %d / couverture %d = %.2f ; volées par une passe : %d (%.0f %%)"
		% [niveau, int(lions[0].traceuse_shape.shape.radius), cellules_a, ville.cellules_peintes, rapport,
			GS.joueurs[1].cellules_volees, 100.0 * part_volee])
	for l in lions:
		l.free()
	ville.free()
	return Vector2(rapport, part_volee)


func _tester_reglage_territoire() -> void:
	print("-- Réglage du territoire sur une passe pleine vitesse")
	root.content_scale_size = Vector2i(TAILLE_BATAILLE)  # l'écran d'une bataille (sans Main dans cette section)
	var rapport_min := INF
	var rapport_max := 0.0
	var part_volee_min := INF
	for niveau in range(GS.NIVEAUX.size()):
		for crans in [1, 2, 4, 7]:
			var mesure := await _mesurer_passe(niveau, crans)
			rapport_min = minf(rapport_min, mesure.x)
			rapport_max = maxf(rapport_max, mesure.x)
			part_volee_min = minf(part_volee_min, mesure.y)
	_check(rapport_min >= CIBLE_RAPPORT_COUVERTURE.x and rapport_max <= CIBLE_RAPPORT_COUVERTURE.y,
		"une passe fait compter au territoire à peu près les cellules que compterait la couverture du solo (%.2f à %.2f, cible %.1f à %.1f)"
			% [rapport_min, rapport_max, CIBLE_RAPPORT_COUVERTURE.x, CIBLE_RAPPORT_COUVERTURE.y])
	_check(part_volee_min >= CIBLE_PART_VOLEE,
		"une passe pleine vitesse vole au moins %.0f %% des cellules d'un adversaire, dès le premier cran (%.0f %%)"
			% [100.0 * CIBLE_PART_VOLEE, 100.0 * part_volee_min])
```

- [ ] **Step 2 : le lancer, il échoue**

Run : la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected : 12 lignes `MESURE niveau …` puis (valeurs relevées à la préparation du plan) `❌ une passe fait compter au territoire à peu près les cellules que compterait la couverture du solo (0.44 à 0.92, cible 0.7 à 1.3)` et `❌ une passe pleine vitesse vole au moins 40 % des cellules d'un adversaire, dès le premier cran (8 %)`, `== 2 échec(s) ==`.

- [ ] **Step 3 : `Scripts/Ville.gd`**

3a. Remplacer :

```gdscript
## peinte (mesure par réduction du masque, à intervalle régulier). En bataille, la même grille
## porte aussi le territoire (`Territoire`) : l'hôte y reporte chaque tampon.
```

par :

```gdscript
## peinte (mesure par réduction du masque, à intervalle régulier). En bataille, la même grille
## porte aussi le territoire (`Territoire`) : l'hôte y reporte chaque tampon, sur toutes les
## cellules qu'il recouvre (`EMPREINTE_TERRITOIRE`).
```

3b. Remplacer :

```gdscript
const COUVERTURE_CELLULE := 0.4
```

par :

```gdscript
const COUVERTURE_CELLULE := 0.4
## Marge ajoutée au rayon d'un tampon pour le territoire : `Territoire.tamponner` touche les
## cellules dont le centre est à moins du rayon reçu ; avec une demi-cellule de plus, il touche
## toutes celles que le tampon recouvre, comme la couverture du solo les compte. Mesuré sur une
## passe pleine vitesse (`tests/bataille_test.gd`, phase 10 ter) : sans cette marge, le territoire
## comptait 0,44 à 0,92 fois les cellules de la couverture et une passe ne volait que 8 % des
## cellules d'un adversaire au premier cran ; avec elle, 0,82 à 1,21 fois et 49 % au moins.
const EMPREINTE_TERRITOIRE := TAILLE_CELLULE / 2
```

3c. Remplacer :

```gdscript
		var volees := territoire.tamponner(peintre.index, Vector2i(px, py), rayon)
```

par :

```gdscript
		var volees := territoire.tamponner(peintre.index, Vector2i(px, py), rayon + EMPREINTE_TERRITOIRE)
```

- [ ] **Step 4 : les cibles sont tenues, le solo n'a pas bougé**

Run : la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected : `✅ une passe fait compter au territoire … (0.82 à 1.21, cible 0.7 à 1.3)`, `✅ … vole au moins 40 % … (49 %)`, `== 0 échec(s) ==`. Si une mesure sort des cibles : appliquer l'écart 2 (repli), jamais élargir les cibles.

Run : 5 fois la commande de délai avec `T=tests/smoke_test.gd; O=""`, puis une fois `T=tests/unitaires.gd; O=""`.
Expected : `== 0 échec(s) ==` à chaque passage (la section « Territoire » du smoke test : les cellules comptent pour leur peintre, le vol est compté exactement, un client ne touche pas au territoire).

- [ ] **Step 5 : spec §6**

5a. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
  1 à 6) et `charge` (0 à `CHARGE_MAX`), en `PackedByteArray`. Un tampon de rayon *r* touche les
  cellules peignables dont le centre est à moins de *r* :
```

par :

```markdown
  1 à 6) et `charge` (0 à `CHARGE_MAX`), en `PackedByteArray`. Un tampon de rayon *r* touche les
  cellules peignables qu'il recouvre : celles dont le centre est à moins de *r* + 4 px (une
  demi-cellule, `Ville.EMPREINTE_TERRITOIRE` ; `Territoire.tamponner` reçoit ce rayon agrandi) :
```

5b. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
  3 pour la prendre), contre 3 en terrain vierge. Calcul entier et déterministe (`Territoire`,
  phase 9).
```

par :

```markdown
  3 pour la prendre), contre 3 en terrain vierge. Calcul entier et déterministe (`Territoire`,
  phase 9). Réglage vérifié sur de vrais lions (phase 10 ter, `tests/bataille_test.gd`) : une
  passe pleine vitesse fait compter au territoire 0,7 à 1,3 fois les cellules que compte la
  couverture du solo pour la même passe (mesuré : 0,82 à 1,21 sur les trois niveaux, de 16 à
  46 px) et vole au moins 40 % des cellules d'un adversaire dès le premier cran (mesuré : 49 %).
  C'est l'empreinte qui manquait (sans la demi-cellule : 0,44 à 0,92 et 8 %) ; `GAIN = 6` n'y
  changeait presque rien.
```

- [ ] **Step 6 : Commit**

```bash
git add Scripts/Ville.gd tests/bataille_test.gd docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md
git commit -m "Ville : le territoire compte toutes les cellules que recouvre un tampon (rayon + une demi-cellule), réglé sur la couverture du solo ; le test de bataille mesure la passe pleine vitesse sur les trois niveaux et vérifie les cibles

<ligne fournie par l'environnement>"
```

---

### Task 2 : pseudo jamais caché, chocs en temps de jeu

**Files:**
- Modify: `Scripts/Lion.gd` (`delai_entre_chocs`, `_temps`, `_derniers_chocs`, `_physics_process`, nouvelle `_marge_haute`, `_on_pare_chocs_area_entered`)
- Test: `tests/bataille_test.gd` (`_run`, une fonction à la fin)

**Interfaces:**
- Consumes : `Lion.etiquette_pseudo` (phase 7, `offset_top = -38` dans `Scenes/Lion.tscn`), `Lion._temps` (cumulé à chaque tick physique), `Joueur.pseudo`, `Joueur.chocs`, `Regles.choc_entre_lions` ; phase 10 bis (`_charger_bataille`, `Main.lions`).
- Produces : `Lion._marge_haute() -> float` (38 quand le pseudo s'affiche, 0 sinon) ; `Lion._derniers_chocs` stocke des secondes de jeu (`float`) ; `@export var delai_entre_chocs` s'entend en secondes de jeu.

- [ ] **Step 1 : le test**

1a. Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	await _tester_peintre()
	await _tester_reglage_territoire()
```

par :

```gdscript
	await _tester_peintre()
	await _tester_pseudos_et_chocs()
	await _tester_reglage_territoire()
```

1b. Ajouter à la fin de `tests/bataille_test.gd` :

```gdscript


func _tester_pseudos_et_chocs() -> void:
	print("-- Pseudos et chocs")
	GS.configurer_bataille(NB_LIONS)  # les joueurs existent avant la scène : leurs pseudos aussi
	for i in range(NB_LIONS):
		GS.joueurs[i].pseudo = "" if i == 3 else "Joueur %d" % (i + 1)
	var main := await _charger_bataille(0)
	var lions: Array = main.lions
	await _attendre_depart()
	# Un lion qui monte tout en haut de l'écran garde son pseudo visible ; sans pseudo, il monte jusqu'au bord
	for i in [1, 3]:
		lions[i].commandes.direction_voulue = Vector2.UP
	await _frames(90)
	var etiquette: Label = lions[1].etiquette_pseudo
	_check(etiquette.visible and etiquette.get_global_rect().position.y >= -0.5,
		"un lion collé en haut de l'écran n'y cache pas son pseudo (haut de l'étiquette à %.1f px)" % etiquette.get_global_rect().position.y)
	_check(not lions[3].etiquette_pseudo.visible and lions[3].global_position.y == 0.0,
		"un lion sans pseudo monte jusqu'au bord de l'écran")
	for i in [1, 3]:
		lions[i].commandes.direction_voulue = Vector2.ZERO

	# Deux chocs à 0,5 s de jeu d'écart comptent tous les deux (délai anti-rafale : 0,3 s de jeu).
	# En --fixed-fps, 0,5 s de jeu passent en quelques millisecondes : un délai mesuré à
	# l'horloge murale bloquait le second.
	var l1: CharacterBody2D = lions[1]
	var l2: CharacterBody2D = lions[2]
	var j1: Joueur = GS.joueurs[1]
	var j2: Joueur = GS.joueurs[2]
	for essai in range(2):
		for l: CharacterBody2D in [l1, l2]:
			l._recul = Vector2.ZERO
			l._vitesse = Vector2.ZERO
		l1.global_position = Vector2(600, 400)
		l2.global_position = Vector2(800, 400)
		await _frames(2)
		l1.commandes.direction_voulue = Vector2.RIGHT
		for i in range(90):
			await physics_frame
			if j1.chocs > essai:
				break
		l1.commandes.direction_voulue = Vector2.ZERO
		await _frames(30)
	_check(j1.chocs == 2 and j2.chocs == 2, "deux chocs à une demi-seconde de jeu d'écart comptent tous les deux (%d, %d)" % [j1.chocs, j2.chocs])
	await _liberer(main)
	for j: Joueur in GS.joueurs:
		j.pseudo = ""
```

(Les lions 1 et 2 ont des commandes manuelles ; le lion 0, celui du joueur local, lit le clavier.)

- [ ] **Step 2 : le lancer, il échoue**

Run : la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected : `❌ un lion collé en haut de l'écran n'y cache pas son pseudo (haut de l'étiquette à -38.0 px)` et `❌ deux chocs à une demi-seconde de jeu d'écart comptent tous les deux (1, 1)`, `== 2 échec(s) ==`.

- [ ] **Step 3 : `Scripts/Lion.gd`**

`Lion.gd` fait 501 lignes : le lire en deux morceaux (lignes 1 à 300, puis 300 à 501) avant de l'éditer.

3a. Remplacer :

```gdscript
## Délai minimal entre deux chocs comptés avec le même autre lion, pour qu'une poussée
## continue ne rafale pas les chocs (la commande maintenue ramène aussitôt l'un vers l'autre).
@export var delai_entre_chocs: float = 0.3
```

par :

```gdscript
## Délai minimal entre deux chocs comptés avec le même autre lion, en secondes de jeu, pour
## qu'une poussée continue ne rafale pas les chocs (la commande maintenue ramène aussitôt l'un vers
## l'autre).
@export var delai_entre_chocs: float = 0.3
```

3b. Remplacer :

```gdscript
var _temps := 0.0
```

par :

```gdscript
var _temps := 0.0  # secondes de jeu écoulées pour ce lion (ticks physiques)
```

3c. Remplacer :

```gdscript
## Horodatage (`Time.get_ticks_msec()`) du dernier choc compté avec chaque autre lion,
## par identifiant d'instance ; entrées des lions libérés nettoyées à la volée.
```

par :

```gdscript
## Instant (`_temps`, en secondes de jeu) du dernier choc compté avec chaque autre lion, par
## identifiant d'instance ; entrées des lions libérés nettoyées à la volée. Le temps de jeu, pas
## l'horloge murale : une frame qui rame ou un test en `--fixed-fps` ne change rien au décompte.
```

3d. Remplacer :

```gdscript
	var y_borne: float = clamp(global_position.y, 0, screen_rect.size.y - sprite_size.y)
```

par :

```gdscript
	var y_borne: float = clamp(global_position.y, _marge_haute(), screen_rect.size.y - sprite_size.y)
```

3e. Remplacer :

```gdscript
## Un lion étourdi ignore ses commandes : il ne se dirige plus et ne vomit plus.
```

par :

```gdscript
## Hauteur gardée libre au-dessus du lion : celle de son pseudo quand il s'affiche (bataille),
## pour qu'un lion collé en haut de l'écran ne le cache pas ; aucune en solo.
func _marge_haute() -> float:
	return -etiquette_pseudo.position.y if etiquette_pseudo.visible else 0.0


## Un lion étourdi ignore ses commandes : il ne se dirige plus et ne vomit plus.
```

3f. Remplacer :

```gdscript
	_nettoyer_derniers_chocs()
	var maintenant := Time.get_ticks_msec()
	var dernier: int = _derniers_chocs.get(autre.get_instance_id(), -1)
	if dernier >= 0 and maintenant - dernier < delai_entre_chocs * 1000.0:
		return
	_derniers_chocs[autre.get_instance_id()] = maintenant
```

par :

```gdscript
	_nettoyer_derniers_chocs()
	var dernier: float = _derniers_chocs.get(autre.get_instance_id(), -1.0)
	if dernier >= 0.0 and _temps - dernier < delai_entre_chocs:
		return
	_derniers_chocs[autre.get_instance_id()] = _temps
```

- [ ] **Step 4 : les tests passent, le solo n'a pas bougé**

Run : `grep -n "Time.get_ticks" Scripts/Lion.gd`
Expected : aucune ligne.

Run : la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected : `== 0 échec(s) ==` ; la ligne `MESURE vols …` montre désormais des dizaines de chocs par lion (46 à 71 à la préparation du plan, au lieu de 4 à 8).

Run : 5 fois la commande de délai avec `T=tests/smoke_test.gd; O=""`.
Expected : `== 0 échec(s) ==` à chaque passage (auto-tamponneuses du smoke test : un choc compté une fois, poussée continue de 2 s sans rafale ; pseudo au-dessus de la tête).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Lion.gd tests/bataille_test.gd
git commit -m "Lion : un lion à pseudo s'arrête sous le haut de l'écran pour ne pas le cacher ; le délai anti-rafale des chocs se mesure en temps de jeu (l'horloge murale bloquait presque tous les chocs en --fixed-fps)

<ligne fournie par l'environnement>"
```

---

### Task 3 : le titre remet le solo ; `prochain_index_couleur()` retiré

**Files:**
- Modify: `Scripts/Titre.gd` (`_ready`)
- Modify: `Scripts/GameState.gd` (docstring de `configurer_solo`, `prochain_index_couleur` supprimée)
- Test: `tests/bataille_test.gd` (`_run`, `_tester_solo_apres_bataille`, une fonction à la fin)

**Interfaces:**
- Consumes : `GameState.configurer_solo()` (phase 8), `Regles.taille_ecran()` (phase 10), `Scores.chemin` / `Scores.effacer()`, `Titre.demo_autorisee`.
- Produces : `Titre._ready` appelle `GameState.configurer_solo()` et applique `GameState.regles.taille_ecran()` à `get_tree().root.content_scale_size` ; `GameState.prochain_index_couleur()` n'existe plus (la règle est `ReglesSolo.pastille_a_offrir()`, phase 10).

- [ ] **Step 1 : le test**

1a. Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	await _tester_manche()
	await _tester_solo_apres_bataille()
```

par :

```gdscript
	await _tester_manche()
	await _tester_retour_au_titre()
	await _tester_solo_apres_bataille()
```

1b. Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	print("-- Solo après une bataille")
	GS.configurer_solo()
```

par :

```gdscript
	print("-- Solo après une bataille")
	# Le solo a été configuré par l'écran titre (section précédente), comme dans le jeu.
```

1c. Ajouter à la fin de `tests/bataille_test.gd` :

```gdscript


func _tester_retour_au_titre() -> void:
	print("-- Retour au titre après une bataille")
	var main := await _charger_bataille(0)
	await _liberer(main)
	_check(GS.regles.compte_le_territoire() and root.content_scale_size == Vector2i(TAILLE_BATAILLE),
		"(pré-condition) une bataille vient de se jouer, en 16:9")
	var scores: Node = root.get_node("Scores")
	scores.chemin = "user://scores_test_bataille.cfg"  # l'écran titre enregistre ses préférences
	scores.effacer()
	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _frames(1)
	_check(GS.regles is ReglesSolo and GS.joueurs.size() == 1 and not GS.joueur_local().a_une_couleur(),
		"l'écran titre remet le solo avant toute partie : ses règles, un seul joueur, sans couleur")
	_check(root.get_visible_rect().size == Vector2(2000, 648), "l'écran titre est en 2000×648")
	titre.free()
	scores.effacer()
```

- [ ] **Step 2 : le lancer, il échoue**

Run : la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected : `❌ l'écran titre remet le solo avant toute partie…`, `❌ l'écran titre est en 2000×648`, puis les trois vérifications de « Solo après une bataille » en échec (la bataille est restée branchée), `== 5 échec(s) ==`.

- [ ] **Step 3 : `Scripts/Titre.gd`**

Remplacer :

```gdscript
func _ready() -> void:
	get_tree().paused = false
```

par :

```gdscript
func _ready() -> void:
	get_tree().paused = false
	# L'écran titre est celui du solo : Jouer, la démo et l'arcade y lancent des parties solo, dont
	# les règles doivent être branchées avant le changement de scène (Main._enter_tree appelle
	# nouvelle_partie), même au retour d'une bataille ; l'écran repasse en 2000×648.
	GameState.configurer_solo()
	get_tree().root.content_scale_size = GameState.regles.taille_ecran()
```

- [ ] **Step 4 : `Scripts/GameState.gd`**

4a. Remplacer :

```gdscript
## `Main._enter_tree` appelle `nouvelle_partie()`, puis Lion, Spawner, HUD et Main s'abonnent à
## `joueur_local()` dans leur `_ready`.
func configurer_solo() -> void:
```

par :

```gdscript
## `Main._enter_tree` appelle `nouvelle_partie()`, puis Lion, Spawner, HUD et Main s'abonnent à
## `joueur_local()` dans leur `_ready`. L'écran titre l'appelle (toute partie qu'il lance est
## une partie solo).
func configurer_solo() -> void:
```

4b. Supprimer (remplacer par rien) :

```gdscript
## Prochaine couleur de l'arc-en-ciel à offrir au joueur local (-1 si toutes sont débloquées).
## Règle du solo, lue par le Spawner (en bataille, les apparitions passeront par les règles).
func prochain_index_couleur() -> int:
	var i := joueur_local().couleurs_debloquees.size()
	return i if i < COULEURS_ARC_EN_CIEL.size() else -1


```

- [ ] **Step 5 : plus aucun appelant de `prochain_index_couleur`**

Chercher chaque forme d'appel (direct, par chaîne, dans les tests et les scènes) :

Run : `grep -rn "prochain_index_couleur" Scripts tests Scenes ; grep -rn "\"prochain_index" Scripts tests`
Expected : aucune ligne.

Run : `godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"`
Expected : aucune ligne.

- [ ] **Step 6 : les tests passent, le solo n'a pas bougé**

Run : la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`, puis 5 fois avec `T=tests/smoke_test.gd; O=""` (le smoke test ouvre l'écran titre trois fois au milieu des parties solo), puis `T=tests/unitaires.gd; O=""`.
Expected : `== 0 échec(s) ==` à chaque passage, sans `SCRIPT ERROR`.

- [ ] **Step 7 : Commit**

```bash
git add Scripts/Titre.gd Scripts/GameState.gd tests/bataille_test.gd
git commit -m "Titre : remet le solo (règles, un joueur sans couleur, écran 2000×648) avant toute partie, même au retour d'une bataille ; GameState.prochain_index_couleur retiré (la règle est ReglesSolo.pastille_a_offrir)

<ligne fournie par l'environnement>"
```

---

### Task 4 : captures de la manche (◉ manche à 4), feuille de route

**Files:**
- Test: `tests/bataille_test.gd` (docstring, constante, variable, `_init`, `_tester_manche`, une fonction à la fin)
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`

**Interfaces:**
- Consumes : Tasks 1 à 3 ; `_tester_manche` (phase 10 bis).
- Produces : `tests/bataille_test.gd -- --captures=<dossier>` écrit `bataille_1.png`, `bataille_2.png`, `bataille_3.png` (2000×1125) à 5, 45 et 88 s de manche ; sans l'option ou en headless, rien.

- [ ] **Step 1 : les captures dans le test**

1a. Dans `tests/bataille_test.gd`, remplacer :

```gdscript
## attendre l'horloge : la manche entière prend quelques secondes.
```

par :

```gdscript
## attendre l'horloge : la manche entière prend quelques secondes. Avec le rendu (sans
## `--headless`) et `-- --captures=<dossier>`, la manche est aussi capturée en PNG (contrôle ◉).
```

1b. Remplacer :

```gdscript
const CIBLE_PART_VOLEE := 0.4
```

par :

```gdscript
const CIBLE_PART_VOLEE := 0.4
const INSTANTS_CAPTURES: Array[float] = [5.0, 45.0, 88.0]  # secondes de manche
```

1c. Remplacer :

```gdscript
var _echecs := 0
var GS: Node
```

par :

```gdscript
var _echecs := 0
var GS: Node
var _dossier_captures := ""
```

1d. Remplacer :

```gdscript
func _init() -> void:
	call_deferred("_run")
```

par :

```gdscript
func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):
			_dossier_captures = arg.trim_prefix("--captures=")
	call_deferred("_run")
```

1e. Remplacer :

```gdscript
	print("-- Manche à 4 lions, pilotée")
	var main := await _charger_bataille(0)
```

par :

```gdscript
	print("-- Manche à 4 lions, pilotée")
	GS.configurer_bataille(NB_LIONS)  # les joueurs existent avant la scène : leurs pseudos aussi
	for i in range(NB_LIONS):
		GS.joueurs[i].pseudo = "Joueur %d" % (i + 1)  # pour les captures : chaque lion porte son pseudo
	var main := await _charger_bataille(0)
```

1f. Remplacer :

```gdscript
		jeux_max_par_frame = maxi(jeux_max_par_frame, ville._tampons.size() - jeux_avant)
```

par :

```gdscript
		jeux_max_par_frame = maxi(jeux_max_par_frame, ville._tampons.size() - jeux_avant)
		for k in range(INSTANTS_CAPTURES.size()):
			if f == int(INSTANTS_CAPTURES[k] * Engine.physics_ticks_per_second):
				await _capturer("bataille_%d" % (k + 1))
```

1g. Remplacer :

```gdscript
	_check(GS.joueurs.any(func(j: Joueur) -> bool: return j.crans > 1), "des pastilles sont ramassées en cours de manche")
	_check(paused and main.get_node_or_null("GameOver") == null, "la fin de manche fige la bataille, sans le bilan du solo")
	await _liberer(main)
```

par :

```gdscript
	_check(GS.joueurs.any(func(j: Joueur) -> bool: return j.crans > 1), "des pastilles sont ramassées en cours de manche")
	_check(paused and main.get_node_or_null("GameOver") == null, "la fin de manche fige la bataille, sans le bilan du solo")
	await _liberer(main)
	for j: Joueur in GS.joueurs:
		j.pseudo = ""
```

1h. Ajouter à la fin de `tests/bataille_test.gd` :

```gdscript


## Avec le rendu et `--captures=<dossier>` seulement : en headless, le viewport n'a pas d'image.
func _capturer(nom: String) -> void:
	if _dossier_captures.is_empty():
		return
	await RenderingServer.frame_post_draw
	var chemin := _dossier_captures.path_join(nom + ".png")
	root.get_texture().get_image().save_png(chemin)
	print("  📸 ", chemin)
```

- [ ] **Step 2 : en headless, rien ne change**

Run : 5 fois la commande de délai avec `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected : `== 0 échec(s) ==` à chaque passage, aucune ligne `📸`.

- [ ] **Step 3 : ◉ la manche à 4, capturée avec le rendu**

Une fenêtre s'ouvre pendant environ deux minutes (le test entier tourne avec le rendu).

Run : `export PATH="/opt/homebrew/bin:$PATH"; mkdir -p "$TMPDIR/captures"; ( godot --fixed-fps 60 --script tests/bataille_test.gd -- --captures="$TMPDIR/captures" > "$TMPDIR/c.log" 2>&1 & p=$!; for i in $(seq 1 300); do kill -0 $p 2>/dev/null || break; sleep 1; done; kill $p 2>/dev/null ); grep -E "❌|SCRIPT ERROR|SHADER ERROR|📸|== " "$TMPDIR/c.log"; python3 -c "import struct,glob; [print(f, struct.unpack('>II', open(f,'rb').read(24)[16:24])) for f in sorted(glob.glob('$TMPDIR/captures/*.png'))]"`
Expected : trois lignes `📸`, `== 0 échec(s) ==`, trois PNG de (2000, 1125).

Regarder les trois captures (outil de lecture d'images) et vérifier, en le notant dans le compte rendu de la phase : quatre lions dans quatre couleurs de crinière, chacun avec son pseudo lisible au-dessus de la tête ; la skyline posée en bas de l'écran sous un grand ciel, peinte dans les nuances des quatre joueurs, bigarrée là où les couloirs se chevauchent ; des ennemis dans le ciel et sur la bande de peinture ; aucun élément coupé par le bord de l'écran. Le HUD du solo (cœurs, arc-en-ciel, chrono qui monte) est attendu (phase 17). Montrer les captures à l'utilisateur : c'est le contrôle visuel de sortie de la phase.

- [ ] **Step 4 : feuille de route, points de vigilance résolus par la phase 10 ter**

4a. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 10** : rerégler `GAIN` / `SEUIL_POSSESSION` / `CHARGE_MAX` sur une vraie manche à 4 lions ;
```

par :

```markdown
- **prochaine phase qui touche `Scripts/Territoire.gd`** (phase 14, méthode d'affichage) : le
  commentaire de `CHARGE_MAX` annonce encore « La phase 10 rerègle ces constantes sur une vraie
  manche » ; la phase 10 ter les a gardées (4, 12, 12) et réglé l'empreinte du tampon dans la ville
  (`Ville.EMPREINTE_TERRITOIRE`, spec §6, cibles vérifiées par `tests/bataille_test.gd`) : le
  corriger ;
```

4b. Remplacer :

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

par :

```markdown
- **phase 13** : le salon appelle `GameState.configurer_bataille(n)` juste avant de charger la
  scène de bataille, jamais depuis elle (`Main._enter_tree` appelle `nouvelle_partie()`, puis Lion,
  Spawner, HUD et Main s'abonnent à `joueur_local()` dans leur `_ready`) ; l'écran titre remet le
  solo avant toute partie (`configurer_solo()` et l'écran 2000×648, phase 10 ter) ; le salon et
  l'écran Réseau passent eux-mêmes en 16:9 (spec §7 : `ReglesBataille.TAILLE_ECRAN`) ;
```

4c. Supprimer (remplacer par rien) :

```markdown
- **phase 10** : le pseudo est une étiquette au-dessus du sprite (38 px au-dessus du lion) : un
  lion collé en haut de l'écran la cache. En bataille, borner `y` à la hauteur de l'étiquette ou la
  passer sous le lion près du bord ;
```

4d. Supprimer (remplacer par rien) :

```markdown
- **phase 10 ter** : `GameState.prochain_index_couleur()` n'a plus d'appelant depuis la phase 10 bis
  (le Spawner lit `GameState.regles.pastille_a_offrir()`, que `ReglesSolo` tient depuis la phase 10,
  vérifications unitaires comprises) : la retirer ;
```

Run : `grep -nE "^- (\*\*)?phases? 10( |\*\*|,)" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
Expected : aucune ligne (tous les points de vigilance de la phase 10 sont résolus ou réaffectés).

- [ ] **Step 5 : Commit**

```bash
git add tests/bataille_test.gd docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
git commit -m "Test de bataille : captures de la manche à 4 avec les pseudos (--captures, contrôle visuel) ; feuille de route : points de vigilance de la phase 10 résolus (réglage, pseudo, retour au solo, prochain_index_couleur), commentaire de Territoire pour la phase 14

<ligne fournie par l'environnement>"
```

---

## Sortie de phase

- Les trois suites : `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR`, localement (test de bataille et smoke test 5 fois de suite chacun) puis en CI sur la PR.
- ◉ : les trois captures de la manche à 4 regardées et montrées à l'utilisateur (Task 4, Step 3).
- `git diff main --stat` : 5 fichiers de code et de test (`Scripts/Ville.gd`, `Scripts/Lion.gd`, `Scripts/Titre.gd`, `Scripts/GameState.gd`, `tests/bataille_test.gd`) plus la spec et la feuille de route.
- `grep -rn "prochain_index_couleur" Scripts tests Scenes` et `grep -n "Time.get_ticks" Scripts/Lion.gd` : aucune ligne.
- `grep -n "EMPREINTE_TERRITOIRE" Scripts/Ville.gd` : la constante et son usage dans `peindre`.
- Rappeler à l'utilisateur : la bataille ne se lance encore que depuis le test (salon : phase 13, réseau : phase 14) ; le HUD, la musique et la fin au chrono de la bataille sont la phase 17, les résultats la phase 18 ; la couleur des pastilles de bataille (au hasard dans l'arc-en-ciel) reste un choix visuel qu'il peut trancher sur les captures.
