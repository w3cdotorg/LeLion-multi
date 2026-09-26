# Phase 11 ter : réseau (3/3), le test réseau durci et en CI, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** le test à plusieurs processus de la phase 11 (`tests/reseau/lancer.sh` + `tests/reseau/joueur.gd`) n'attend plus jamais une durée fixe : l'hôte de test compte les poignées de main échouées réelles (`--refus=N`) au lieu de rester ouvert `--attente=S` secondes ; le scénario 5 (client « lent ») garantit au rival sa marge avant le délai de poignée de main (délai de l'hôte de test porté à 8 s, rival démarré d'avance et lancé au feu) et prouve enfin la coupure par le délai **de l'hôte** ; puis le test entre en CI, après le test de bataille. Sortie : **test réseau vert 5 fois (bash 3.2 et bash 5), CI verte**. **Ni le jeu ni `Scripts/Reseau.gd` ne changent.**

**Architecture:** tout se passe dans le harnais. L'hôte de test branche `peer_authentication_failed` de son `SceneMultiplayer` (après le gestionnaire de `Reseau`, qui libère la place), écrit « POIGNEE ECHOUEE n » et attend la n-ième (borné par `DELAI_ETAPE`) avant sa vérification finale. `--delai-poignee=S` pose `auth_timeout` sur l'API de l'hôte juste après `heberger()` (qui vient d'y mettre `Reseau.DELAI_POIGNEE_DE_MAIN`) et avant « HOTE PRET ». Un client `--feu=chemin` démarre, écrit « ATTEND LE FEU », et ne rejoint l'hôte qu'une fois le fichier créé par `lancer.sh`. Le client lent coupe son propre délai (`auth_timeout = 0`), attend que l'hôte le coupe et vérifie que c'est au bout du délai de l'hôte. `lancer.sh` enchaîne chaque étape sur une ligne observée d'un journal (plus de `sleep 3.5`) et recopie les journaux dans sa sortie en cas d'échec ; la CI l'appelle comme ses autres suites.

**Tech Stack:** Godot 4.7.2 (`SceneMultiplayer.auth_timeout`, `peer_authentication_failed`, `ENetMultiplayerPeer`), GDScript typé, bash (3.2 sur le Mac, 5 sur Ubuntu), `timeout` de GNU coreutils (`/opt/homebrew/bin/timeout` sur le Mac, natif sur Ubuntu), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§10 test réseau, §11 CI) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 11 ter ; point de vigilance « phase 11 ter », M1 de la revue finale de la phase 11) · plan de la phase 11 (le test, ses scénarios, écart 9) : `docs/superpowers/plans/2026-09-25-phase-11-reseau.md` · plan de la phase 11 bis, Task 3 (le pas de CI, repris et adapté ici) : `docs/superpowers/plans/2026-09-25-phase-11bis-joueur-local.md` · prérequis : phase 11 bis fusionnée (feuille de route de c972ffc : ligne 11 ter déjà créée, point M1 déjà renommé « phase 11 ter ») ; nouvelle branche `phase-11ter-test-reseau-ci` depuis `main`. Les trois fichiers de la phase sont ceux de `main` ea01f39 : la phase 11 bis n'y touche pas.

## Écarts assumés

1. **Le pas de CI de la phase 11 bis (sa Task 3) est déplacé ici** (décision du contrôleur) : le test ne doit entrer en CI qu'une fois durci (point M1). Le plan de la phase 11 bis n'est pas modifié ; sa Task 3 est remplacée par la Task 3 ci-dessous.
2. **Constat en préparant ce plan : le scénario 5 de `main` ne prouve pas le délai de l'hôte.** Le client lent a son propre `SceneMultiplayer`, dont l'`auth_timeout` vaut 3 s par défaut, comme celui de l'hôte : c'est **le lent lui-même** qui abandonne sa poignée de main au bout de 3 s, et l'hôte ne voit qu'un départ. Mesuré sur une copie : avec l'hôte à 8 s et le lent laissé tel quel, le lent est coupé à 3,0 s. D'où `api.auth_timeout = 0.0` chez le lent (0 = aucun délai) et sa vérification « coupé au bout du délai de l'hôte » (au moins délai − 0,5 s).
3. **Le délai de 8 s est posé par l'hôte de test, pas par `Reseau`** : `--delai-poignee` écrit `auth_timeout` sur l'API de l'hôte après `heberger()`. `Reseau.DELAI_POIGNEE_DE_MAIN` (3 s) reste celui du jeu ; `Scripts/Reseau.gd` n'est ni modifié ni même touché temporairement (toutes les preuves de discrimination ci-dessous mutent le harnais seul). `SceneMultiplayer` relit `auth_timeout` à chaque image : mesuré, la coupure tombe à 8,0 s.
4. **`--feu` en plus du délai allongé** (la feuille de route ne proposait que le délai) : sans lui, la marge du rival est « délai − démarrage d'un processus Godot », et ce démarrage est précisément ce qu'un runner chargé allonge. Démarré en même temps que le lent, le rival ne part qu'au feu : sa marge ne contient plus qu'un tour de scrutation de `lancer.sh` (0,1 s) et un aller-retour UDP local. Le scénario 2 s'en sert aussi : ses deux rivaux partent au même instant, la course pour la dernière place ne dépend plus de leurs démarrages.
5. **L'hôte attend les poignées échouées avant les arrivées** : dans le scénario 5, l'arrivée attendue (le client tardif) ne peut venir qu'après la coupure du lent (8 s) ; attendue en premier, elle mangerait sa fenêtre de 15 s. Les comptes ne font que croître : l'ordre des attentes ne change rien aux autres scénarios.
6. **Le point de vigilance M1 disait « compte les refus »** : l'hôte compte toutes les poignées de main échouées (refus lus par le client, qui ferme lui-même la connexion, et coupures par le délai), seul signal que `SceneMultiplayer` donne à l'hôte sans toucher `Reseau`. Le scénario 5 en attend donc 2 (le refus du rival, la coupure du lent).
7. **`lancer.sh` recopie les journaux dans sa sortie en cas d'échec** : en CI, c'est tout ce qui reste d'un échec (les journaux vivent dans un `mktemp -d` du runner).
8. **Pas de nettoyage préalable (« Step 0 »)** : `tests/reseau/joueur.gd` (252 lignes, environ 295 après la phase) et `tests/reseau/lancer.sh` (189 lignes) font moins de 300 lignes, sans code mort.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), toutes les commandes depuis `~/Sites/LeLion-multi`, sur la branche `phase-11ter-test-reseau-ci`.
- Fichiers de la phase (3) : ✏️ `tests/reseau/joueur.gd`, ✏️ `tests/reseau/lancer.sh`, ✏️ `.github/workflows/ci.yml`. La spec et la feuille de route ne comptent pas. **`Scripts/Reseau.gd` n'est jamais modifié, même temporairement** (ni pour une mesure, ni pour une preuve) ; `git diff main --stat -- Scripts/` doit rester vide.
- Identifiants, commentaires et messages de test en français, docstrings `##`, indentation par tabulations (y compris dans `lancer.sh`).
- `lancer.sh` tourne sous bash 3.2 (`/bin/bash` du Mac) et bash 5 (Ubuntu) : pas de `mapfile`, de `declare -A`, de `${var,,}` ni de `wait -n` ; un tableau éventuellement vide se lit `${T[@]+"${T[@]}"}` (`set -u`). `sed -i` diffère entre BSD et GNU : dans les commandes du plan, `sed -i.orig` (valable sur les deux) ou une copie.
- Chaque processus Godot du test tourne sous `timeout -k 5 "$DELAI"` (40 s par défaut) ; tous sont tués en sortie, interruption comprise (`trap nettoyer EXIT`) ; le scénario n utilise le port `port_de_base + n` (17778 à 17782 par défaut, jamais le 7777 d'une vraie partie ; `bash tests/reseau/lancer.sh 27777` décale tout).
- Aucune durée fixe dans le test : chaque attente guette un événement (une ligne d'un journal, un compte de l'hôte), 15 s au plus (`DELAI_ETAPE` de `joueur.gd`, 150 × 0,1 s dans `lancer.sh`). `DELAI_ETAPE` et `DELAI` ne s'élargissent pas.
- Un test `--script` est compilé **avant** l'enregistrement des autoloads : `joueur.gd` récupère `Reseau` par `root.get_node("Reseau")` et ne nomme ni `Reseau` ni `GameState` ; il peut nommer `EtatPartie`, `SceneMultiplayer`, `ENetMultiplayerPeer`, `MultiplayerPeer`, `OfflineMultiplayerPeer`, `FileAccess`.
- Vérification de la phase : l'import headless (`godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"` : aucune ligne), puis `bash tests/reseau/lancer.sh` qui finit par `== 0 échec(s) ==` et le code 0, **5 passages consécutifs verts sous bash 5 et 5 sous `/bin/bash` (3.2)**. Les trois autres suites (unitaires, smoke, bataille) ne sont pas touchées : un passage vert de chacune suffit, avec la commande habituelle
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/unitaires.gd; O=""; timeout 300 godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/smoke_test.gd; O=""`, `T=tests/bataille_test.gd; O="--fixed-fps 60"`). Bruit connu dans chaque journal de poste : « ObjectDB instances were leaked » et « resources still in use at exit ».
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`** (la CI les cherche dans toute la sortie).
- Les copies mutantes du harnais (preuves de discrimination) vivent dans `tests/reseau/` le temps d'un passage (`lancer.sh` se situe par `dirname "$0"`) et sont supprimées aussitôt : **jamais commitées** ; `git status --short` ne montre ensuite que les fichiers de la tâche.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Le rival du scénario 5 accepté au lieu d'être refusé** sur un runner lent : sa demande arrive après la fin de la réservation du lent. → rival lancé au feu, délai de 8 s, et la preuve que la vérification le voit : feu retardé de 9 s ⇒ « ❌ refusé parce que la partie est pleine, sans course possible (, inscrit) » (Task 2, Step 5, D3).
2. **Un hôte qui quitte avant qu'un refusé ait lu son refus** (le client voit « échec » au lieu de la raison) : c'était le défaut des fenêtres fixes. → `--refus=N` ; sans lui, le scénario 3 échoue (Task 1, Step 2) ; un compte jamais atteint échoue au bout de 15 s, borné (Task 1, Step 5, D5).
3. **La libération du lent prouvée par son propre délai et non par celui de l'hôte** (défaut de `main`, Écart 2). → « l'hôte coupe le client lent au bout de son délai de poignée de main (8.0 s, attendu 8 s) » ; lent sans `auth_timeout = 0` ou hôte sans `--delai-poignee` ⇒ coupure à 3,0 s et « ❌ » (Task 2, Step 5, D1 et D2).
4. **Des processus Godot orphelins ou des ports encore pris** après une interruption (runner annulé, `timeout 300` de la CI) : le passage suivant échoue « port occupé » ou le runner garde des processus. → TERM envoyé au lanceur en plein passage : code 130, aucun processus `godot --headless --script tests/reseau` restant (Task 3, Step 2).
5. **Un échec en CI sans rien pour le comprendre** (journaux restés dans le `mktemp` du runner). → journaux recopiés dans la sortie du lanceur en cas d'échec : « ----- hote3.log » suivi de son contenu (Task 3, Step 2).

---

### Task 0 : vérification des plans

Ce plan a été commité par le commit de planification de la phase 11 ter : ne pas le recommiter, **ne jamais le modifier** (ni réécriture, ni résumé). Les plans des phases 11 et 11 bis ne se modifient pas non plus. Pas d'autre étape.

---

### Task 1 : les poignées de main échouées comptées par l'hôte (`--refus=N`)

**Files:**
- Modify: `tests/reseau/joueur.gd` (en-tête, variables, `_jouer_hote`, un gestionnaire après `_sur_depart`)
- Modify: `tests/reseau/lancer.sh` (options des hôtes 1, 2, 3 et 5)

**Interfaces:**
- Consumes : `SceneMultiplayer.peer_authentication_failed(id: int)` de `root.multiplayer` (émis chez l'hôte quand un pair non authentifié part ou dépasse `auth_timeout`) ; `Reseau._sur_echec_poignee_de_main`, déjà branché dessus dans `Reseau._ready`, qui libère la place (`inscrits.erase(id)`).
- Produces :
  - option d'hôte `--refus=N` (défaut 0) : l'hôte attend (au plus `DELAI_ETAPE`) N poignées de main échouées avant sa vérification finale, puis vérifie qu'il n'y en a ni plus ni moins, pas plus que d'arrivées ; l'option `--attente=S` de l'hôte disparaît ;
  - ligne de journal de l'hôte `POIGNEE ECHOUEE <n> (pair <id>)`, écrite après la libération de la place par `Reseau` (n = compte depuis le début de la session) ;
  - `var _poignees_echouees: Array[int]`, `func _sur_poignee_echouee(id: int) -> void`.

- [ ] **Step 1 : le test d'abord (`lancer.sh`)**

1a. Dans `tests/reseau/lancer.sh`, remplacer :

```sh
lancer hote1 --role=hote --port=$P --pseudo=Hote --clients=2 --partants=1 --attente=1
```

par :

```sh
lancer hote1 --role=hote --port=$P --pseudo=Hote --clients=2 --partants=1 --refus=1
```

1b. Dans `tests/reseau/lancer.sh`, remplacer :

```sh
lancer hote2 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --attente=2
```

par :

```sh
lancer hote2 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --refus=1
```

1c. Dans `tests/reseau/lancer.sh`, remplacer :

```sh
lancer hote3 --role=hote --port=$P --pseudo=Hote --manche --attente=3
```

par :

```sh
lancer hote3 --role=hote --port=$P --pseudo=Hote --manche --refus=1
```

1d. Dans `tests/reseau/lancer.sh`, remplacer :

```sh
lancer hote5 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --attente=1
```

par :

```sh
lancer hote5 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --refus=2
```

(Scénario 5 : le refus du rival, puis la fin de la poignée de main du lent.)

- [ ] **Step 2 : le lancer, il échoue**

Run : `export PATH="/opt/homebrew/bin:$PATH"; bash tests/reseau/lancer.sh 2>&1 | grep -E "^  (✅|❌) |^== [0-9]+ échec"`
Expected : FAIL. L'hôte ignore encore `--refus` et, sans sa pause, quitte dès ses arrivées et départs comptés : au moins `❌ manche en cours : arrivée refusée : tard3 sort en 1` (l'hôte 3, qui n'attend aucune arrivée, est parti avant que `tard3` démarre : son journal dit `RESULTAT echec`), et un `== N échec(s) ==` final avec N ≥ 2.

- [ ] **Step 3 : l'hôte compte les poignées de main échouées (`joueur.gd`)**

3a. Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
##   venu est refusé), --attente=S (secondes gardées ouvertes après les arrivées et départs, pour
##   les demandes qui doivent être refusées). Écrit « HOTE PRET » quand il écoute, puis quitte le
##   réseau (ses clients doivent voir l'hôte partir).
```

par :

```gdscript
##   venu est refusé), --refus=N (poignées de main qui doivent échouer : demandes refusées, dont le
##   client ferme la connexion en lisant le refus, ou jamais finies, coupées par le délai ; l'hôte
##   les compte par `peer_authentication_failed` et reste ouvert jusqu'à la N-ième, DELAI_ETAPE au
##   plus). Écrit « HOTE PRET » quand il écoute et « POIGNEE ECHOUEE n » à chaque poignée de main
##   échouée (n = leur compte, après que `Reseau` a libéré la place), puis quitte le réseau (ses
##   clients doivent voir l'hôte partir).
```

3b. Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
var _departs: Array[int] = []
```

par :

```gdscript
var _departs: Array[int] = []
var _poignees_echouees: Array[int] = []  # hôte : pairs dont la poignée de main a échoué, dans l'ordre
```

3c. Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	var nb_partants := int(_option("partants", "0"))
	reseau.places = int(_option("places", str(EtatPartie.NB_JOUEURS_MAX)))
	reseau.joueur_arrive.connect(_sur_arrivee)
	reseau.joueur_parti.connect(_sur_depart)
```

par :

```gdscript
	var nb_partants := int(_option("partants", "0"))
	var nb_refus := int(_option("refus", "0"))
	reseau.places = int(_option("places", str(EtatPartie.NB_JOUEURS_MAX)))
	reseau.joueur_arrive.connect(_sur_arrivee)
	reseau.joueur_parti.connect(_sur_depart)
	# Branché après le gestionnaire de Reseau (connecté dans son _ready) : quand « POIGNEE ECHOUEE »
	# s'écrit, la place réservée est déjà libérée.
	root.multiplayer.peer_authentication_failed.connect(_sur_poignee_echouee)
```

3d. Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
		and hote.pseudo == reseau.pseudo, "l'hôte s'inscrit lui-même : index 0, première couleur, son pseudo")

	_check(await _attendre(func() -> bool: return _arrivees.size() >= nb_clients),
```

par :

```gdscript
		and hote.pseudo == reseau.pseudo, "l'hôte s'inscrit lui-même : index 0, première couleur, son pseudo")

	# Les poignées de main échouées d'abord : dans le scénario 5, l'arrivée attendue ne peut venir
	# qu'après la dernière (la place du client lent libérée par le délai). Les comptes ne font que
	# croître : l'ordre des attentes ne change rien aux autres scénarios.
	_check(await _attendre(func() -> bool: return _poignees_echouees.size() >= nb_refus),
		"%d poignée(s) de main échouée(s) sur %d attendue(s) (refus lus, ou délai dépassé)" % [_poignees_echouees.size(), nb_refus])
	_check(await _attendre(func() -> bool: return _arrivees.size() >= nb_clients),
```

3e. Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	await _pause(float(_option("attente", "0")))
	_check(_arrivees.size() == nb_clients, "aucune arrivée de trop : %d client(s) en tout" % _arrivees.size())
```

par :

```gdscript
	_check(_arrivees.size() == nb_clients and _poignees_echouees.size() == nb_refus,
		"ni arrivée ni poignée de main échouée de trop : %d client(s), %d échec(s) de poignée de main" % [_arrivees.size(), _poignees_echouees.size()])
```

3f. Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
func _sur_depart(id: int) -> void:
	_departs.append(id)
```

par :

```gdscript
func _sur_depart(id: int) -> void:
	_departs.append(id)


func _sur_poignee_echouee(id: int) -> void:
	_poignees_echouees.append(id)
	print("POIGNEE ECHOUEE %d (pair %d)" % [_poignees_echouees.size(), id])
```

(`_pause` reste : les clients s'en servent.)

- [ ] **Step 4 : compiler, puis le test passe**

Run : `export PATH="/opt/homebrew/bin:$PATH"; godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"; bash tests/reseau/lancer.sh > "$TMPDIR/reseau.log" 2>&1; echo "code $?"; grep -E "^  (✅|❌) |^== [0-9]+ échec" "$TMPDIR/reseau.log"`
Expected : aucune ligne de l'import ; les cinq `✅` de scénario (de « hôte + 2 clients, départ d'un client et de l'hôte, version différente refusée » à « poignée de main jamais finie : réservation à la réponse, puis libération par le vrai délai »), `== 0 échec(s) ==`, `code 0`. (Le scénario 5 garde ici son `sleep 3.5` et le délai de 3 s : c'est la Task 2 qui le durcit.)

- [ ] **Step 5 : la vérification discrimine (harnais seul)**

D5 (un refus attendu qui ne vient jamais) :

```sh
export PATH="/opt/homebrew/bin:$PATH"
sed 's/--manche --refus=1/--manche --refus=2/' tests/reseau/lancer.sh > tests/reseau/mutant.sh
bash tests/reseau/mutant.sh 2>&1 | grep -E "^  ❌"; rm tests/reseau/mutant.sh
```

Expected : `❌ manche en cours : arrivée refusée : hote3 sort en 1`, et dans le journal de `hote3` `❌ 1 poignée(s) de main échouée(s) sur 2 attendue(s) (refus lus, ou délai dépassé)` puis `❌ ni arrivée ni poignée de main échouée de trop : 0 client(s), 1 échec(s) de poignée de main` ; le passage dure environ 15 s de plus (l'attente est bornée). `git status --short` : seulement les deux fichiers de la tâche.

- [ ] **Step 6 : Commit**

```bash
git add tests/reseau/joueur.gd tests/reseau/lancer.sh
git commit -m "Test réseau (M1) : l'hôte de test compte les poignées de main échouées (--refus=N, peer_authentication_failed, « POIGNEE ECHOUEE n ») au lieu de rester ouvert une durée fixe (--attente retiré)

<ligne fournie par l'environnement>"
```

---

### Task 2 : le scénario 5 à marge garantie (délai de l'hôte à 8 s, feu, lent qui ne se coupe plus lui-même)

**Files:**
- Modify: `tests/reseau/joueur.gd` (en-tête, `_jouer_hote`, `_jouer_client`, `_jouer_lent`)
- Modify: `tests/reseau/lancer.sh` (en-tête, `DELAI_POIGNEE_LENT`, scénarios 2 et 5)

**Interfaces:**
- Consumes (Task 1) : `--refus=N`, la ligne `POIGNEE ECHOUEE <n> (pair <id>)` ; `attendre_ligne <nom> <motif>` et `attendre_fin <nom>` de `lancer.sh` (phase 11) ; `Reseau.DELAI_POIGNEE_DE_MAIN` (3.0), lu dynamiquement.
- Produces :
  - option d'hôte `--delai-poignee=S` : `auth_timeout` de l'API de l'hôte pour cette session, posé après `heberger()` et avant « HOTE PRET » ;
  - option de client `--feu=chemin` : écrit `ATTEND LE FEU`, attend (au plus `DELAI_ETAPE`) que le fichier existe, puis rejoint ; la durée d'un `--attendu=echec` se mesure après le feu ;
  - rôle lent : `auth_timeout = 0.0` sur sa propre API ; option `--delai-poignee=S` (le délai attendu de l'hôte, défaut `Reseau.DELAI_POIGNEE_DE_MAIN`) ; ligne `COUPE apres=<x.x> s` ; vérification `coupé et durée ≥ S − 0,5` ; l'option `--attente` du lent disparaît ;
  - `lancer.sh` : `DELAI_POIGNEE_LENT=8`, plus aucun `sleep` dans les scénarios.

- [ ] **Step 1 : le test d'abord (`lancer.sh`)**

1a. Dans `tests/reseau/lancer.sh`, remplacer :

```sh
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40).
```

par :

```sh
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40).
# Aucune fenêtre d'attente fixe : chaque étape attend un événement observé (une ligne d'un journal,
# un compte de l'hôte), 15 s au plus (DELAI_ETAPE de joueur.gd, 150 × 0,1 s ici).
```

1b. Dans `tests/reseau/lancer.sh`, remplacer :

```sh
JOURNAUX="$(mktemp -d "${TMPDIR:-/tmp}/lelion-reseau.XXXXXX")"
```

par :

```sh
JOURNAUX="$(mktemp -d "${TMPDIR:-/tmp}/lelion-reseau.XXXXXX")"
# Délai de poignée de main de l'hôte du scénario 5, en secondes (Reseau.DELAI_POIGNEE_DE_MAIN, 3 s,
# reste celui du jeu). Deux marges en dépendent. Le rival doit être refusé avant qu'il expire :
# démarré d'avance, il part au feu, donné dans les 0,1 s qui suivent « ACCEPTE » (refus mesuré
# 0,07 à 0,16 s après), soit plus de 7,8 s de marge, sans démarrage de Godot dedans. L'hôte doit
# voir la coupure du lent dans son attente des poignées échouées (15 s depuis « HOTE PRET ») :
# 15 - 8 = 7 s pour démarrer le lent (mesuré 0,3 à 0,6 s). Plus long mange la seconde marge, plus
# court la première.
DELAI_POIGNEE_LENT=8
```

1c. Dans `tests/reseau/lancer.sh`, remplacer :

```sh
# 2. Partie à 2 places, deux demandes simultanées : exactement une acceptée, l'autre refusée.
P=$((PORT_BASE + 2))
lancer hote2 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --refus=1
if attendre_hote hote2; then
	lancer rival2a --role=client --port=$P --pseudo=RivalA --attendu=inscrit_ou_plein
	lancer rival2b --role=client --port=$P --pseudo=RivalB --attendu=inscrit_ou_plein
fi
```

par :

```sh
# 2. Partie à 2 places, deux demandes simultanées : exactement une acceptée, l'autre refusée. Les
#    deux rivaux démarrent, puis partent au même feu : la course ne dépend pas de leurs démarrages.
P=$((PORT_BASE + 2))
lancer hote2 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --refus=1
if attendre_hote hote2; then
	lancer rival2a --role=client --port=$P --pseudo=RivalA --attendu=inscrit_ou_plein --feu="$JOURNAUX/feu2"
	lancer rival2b --role=client --port=$P --pseudo=RivalB --attendu=inscrit_ou_plein --feu="$JOURNAUX/feu2"
	attendre_ligne rival2a "ATTEND LE FEU" && attendre_ligne rival2b "ATTEND LE FEU" && touch "$JOURNAUX/feu2"
fi
```

1d. Dans `tests/reseau/lancer.sh`, remplacer :

```sh
#    l'hôte, avant toute arrivée), un rival est refusé « plein » sans course possible (le rival ne
#    part qu'après l'acceptation du lent, vue dans son journal). Après le vrai délai de poignée de
#    main (3 s), l'hôte le libère (vrai peer_authentication_failed) : un troisième client obtient
#    la place, à l'index 1.
P=$((PORT_BASE + 5))
lancer hote5 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --refus=2
if attendre_hote hote5; then
	lancer lent5 --role=lent --port=$P --pseudo=Lent --attente=6
	if attendre_ligne lent5 "ACCEPTE"; then
		lancer rival5 --role=client --port=$P --pseudo=Rival --attendu=refus_plein
		attendre_fin rival5
		sleep 3.5  # laisse passer le vrai auth_timeout (3 s) avant le troisième client
		lancer tard5 --role=client --port=$P --pseudo=Tard --attendu=inscrit
	fi
fi
```

par :

```sh
#    l'hôte, avant toute arrivée), un rival est refusé « plein » sans course possible : démarré en
#    même temps que le lent, il ne part qu'au feu, donné après l'acceptation du lent (vue dans son
#    journal), bien avant la fin du délai de poignée de main de l'hôte (DELAI_POIGNEE_LENT). Ce
#    délai passé, l'hôte coupe le lent et libère sa place (vrai peer_authentication_failed, la
#    deuxième de l'hôte après le refus du rival) : un troisième client, lancé seulement alors,
#    obtient la place, à l'index 1.
P=$((PORT_BASE + 5))
lancer hote5 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --refus=2 --delai-poignee=$DELAI_POIGNEE_LENT
if attendre_hote hote5; then
	lancer lent5 --role=lent --port=$P --pseudo=Lent --delai-poignee=$DELAI_POIGNEE_LENT
	lancer rival5 --role=client --port=$P --pseudo=Rival --attendu=refus_plein --feu="$JOURNAUX/feu5"
	if attendre_ligne lent5 "ACCEPTE" && attendre_ligne rival5 "ATTEND LE FEU"; then
		touch "$JOURNAUX/feu5"
		attendre_fin rival5
		if attendre_ligne hote5 "POIGNEE ECHOUEE 2"; then
			lancer tard5 --role=client --port=$P --pseudo=Tard --attendu=inscrit
		fi
	fi
fi
```

(Attendre « POIGNEE ECHOUEE 2 » de l'hôte plutôt que la coupure vue par le lent : la ligne s'écrit après que `Reseau` a libéré la place, le client tardif ne peut donc pas arriver avant. Si le feu ne vient pas, les clients qui l'attendent échouent d'eux-mêmes au bout de 15 s.)

- [ ] **Step 2 : le lancer, il échoue**

Run : `export PATH="/opt/homebrew/bin:$PATH"; bash tests/reseau/lancer.sh 2>&1 | grep -E "^  (✅|❌) |^== [0-9]+ échec"`
Expected : FAIL : `joueur.gd` ignore encore `--feu` et `--delai-poignee`, entre autres `❌ « ATTEND LE FEU » n'apparaît jamais dans le journal de rival2a` et `❌ « ATTEND LE FEU » n'apparaît jamais dans le journal de rival5`.

- [ ] **Step 3 : délai de l'hôte, feu, lent (`joueur.gd`)**

3a. Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
##   plus). Écrit « HOTE PRET » quand il écoute et « POIGNEE ECHOUEE n » à chaque poignée de main
##   échouée (n = leur compte, après que `Reseau` a libéré la place), puis quitte le réseau (ses
##   clients doivent voir l'hôte partir).
```

par :

```gdscript
##   plus), --delai-poignee=S (délai de poignée de main de cette session, en secondes, au lieu de
##   `Reseau.DELAI_POIGNEE_DE_MAIN`). Écrit « HOTE PRET » quand il écoute et « POIGNEE ECHOUEE n »
##   à chaque poignée de main échouée (n = leur compte, après que `Reseau` a libéré la place), puis
##   quitte le réseau (ses clients doivent voir l'hôte partir).
```

3b. Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
##   et un autre client en vue, quitte de lui-même ; sinon, attend que l'hôte parte). Écrit une
##   ligne « RESULTAT … » que lancer.sh compte d'un poste à l'autre. `refus_plein` est la version
##   déterministe d'`inscrit_ou_plein` (un seul dénouement possible, pas une course).
```

par :

```gdscript
##   et un autre client en vue, quitte de lui-même ; sinon, attend que l'hôte parte), --feu=chemin
##   (écrit « ATTEND LE FEU » puis ne rejoint l'hôte qu'une fois ce fichier créé par lancer.sh,
##   DELAI_ETAPE au plus : le démarrage de Godot est déjà fait quand la demande doit partir). Écrit
##   une ligne « RESULTAT … » que lancer.sh compte d'un poste à l'autre. `refus_plein` est la
##   version déterministe d'`inscrit_ou_plein` (un seul dénouement possible, pas une course).
```

3c. Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
##   jamais. Écrit « ACCEPTE index=N » dès la réponse de l'hôte, puis reste ouvert --attente=S
##   secondes (défaut 6) avant de se fermer. Preuve de bout en bout (Focus 2, Focus 5) que la place
```

par :

```gdscript
##   jamais, et son propre délai de poignée de main est coupé (`auth_timeout` à 0) : seul l'hôte
##   peut y mettre fin. Écrit « ACCEPTE index=N » dès la réponse de l'hôte, puis attend que l'hôte
##   le coupe et vérifie que c'est au bout de --delai-poignee=S secondes (le délai de l'hôte ;
##   défaut `Reseau.DELAI_POIGNEE_DE_MAIN`). Preuve de bout en bout (Focus 2, Focus 5) que la place
```

3d. Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	reseau.manche_en_cours = _options.has("manche")
	print("HOTE PRET")
```

par :

```gdscript
	reseau.manche_en_cours = _options.has("manche")
	if _options.has("delai-poignee"):
		# Après heberger(), qui vient de poser DELAI_POIGNEE_DE_MAIN, et avant « HOTE PRET » : aucune
		# poignée de main n'a commencé. SceneMultiplayer relit auth_timeout à chaque image.
		var api := root.multiplayer as SceneMultiplayer
		api.auth_timeout = float(_option("delai-poignee", ""))
	print("HOTE PRET")
```

3e. Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	var debut := Time.get_ticks_msec()
```

par :

```gdscript
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	if _options.has("feu"):
		var feu := _option("feu", "")
		print("ATTEND LE FEU")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(feu)), "lancer.sh donne le feu (%s)" % feu)
	var debut := Time.get_ticks_msec()
```

3f. Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
			# Jamais de complete_auth ici : la poignée de main ne finit pas, exprès.
		api.multiplayer_peer = pair
		_check(await _attendre(func() -> bool: return etat.accepte), "le client lent reçoit une acceptation, sans jamais finir sa poignée de main")
		await _pause(float(_option("attente", "6")))
	pair.close()
```

par :

```gdscript
			# Jamais de complete_auth ici : la poignée de main ne finit pas, exprès.
		# Son propre délai coupé (0 = aucun) : sinon ce poste abandonnerait lui-même la poignée de
		# main au bout de 3 s (le défaut de SceneMultiplayer), et la coupure ne prouverait plus rien
		# du délai de l'hôte.
		api.auth_timeout = 0.0
		api.multiplayer_peer = pair
		_check(await _attendre(func() -> bool: return etat.accepte), "le client lent reçoit une acceptation, sans jamais finir sa poignée de main")
		if etat.accepte:
			var accepte_a := Time.get_ticks_msec()
			var delai := float(_option("delai-poignee", str(reseau.DELAI_POIGNEE_DE_MAIN)))
			var coupe := await _attendre(func() -> bool: return pair.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED)
			var duree := (Time.get_ticks_msec() - accepte_a) / 1000.0
			print("COUPE apres=%.1f s" % duree)
			_check(coupe and duree >= delai - 0.5,
				"l'hôte coupe le client lent au bout de son délai de poignée de main (%.1f s, attendu %.0f s)" % [duree, delai])
	pair.close()
```

(La borne basse seule discrimine : une coupure par un délai de 3 s tombe à 3,0 s. « Jamais coupé » échoue par `coupe` faux au bout de `DELAI_ETAPE`, 15 s après l'acceptation, soit 7 s au-delà des 8 s attendues.)

- [ ] **Step 4 : compiler, puis le test passe 5 fois sous chaque bash**

Run :

```sh
export PATH="/opt/homebrew/bin:$PATH"
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error"
for b in bash /bin/bash; do for i in 1 2 3 4 5; do
	s=$(date +%s); $b tests/reseau/lancer.sh > "$TMPDIR/reseau_$i.log" 2>&1; c=$?
	echo "$b, passage $i : code $c, $(grep '^== [0-9]' "$TMPDIR/reseau_$i.log" | tail -1), $(( $(date +%s) - s )) s"
done; done
```

Expected : aucune ligne de l'import ; dix lignes `code 0, == 0 échec(s) ==`, chacune en 18 à 20 s sur le Mac (mesuré en préparant le plan : 18,7 à 19,0 s sous bash 5.3 comme sous bash 3.2.57, contre 19,7 s avant la phase : les fenêtres fixes retirées compensent les 5 s de délai en plus du scénario 5).

- [ ] **Step 5 : la vérification discrimine (harnais seul, jamais `Reseau.gd`)**

D1 (le lent garde son propre délai de 3 s) :

```sh
export PATH="/opt/homebrew/bin:$PATH"
sed -i.orig 's/^		api.auth_timeout = 0.0$/		pass/' tests/reseau/joueur.gd
bash tests/reseau/lancer.sh 2>&1 | grep -E "COUPE|l'hôte coupe"; mv tests/reseau/joueur.gd.orig tests/reseau/joueur.gd
```

Expected : `…/lent5.log:8:  ❌ l'hôte coupe le client lent au bout de son délai de poignée de main (3.0 s, attendu 8 s)` (le lanceur n'affiche d'un journal que ses lignes en erreur) : c'est exactement ce que faisait le scénario 5 de `main` (Écart 2). Les motifs des `sed` de D1 et D3 commencent par deux tabulations (l'indentation du fichier), pas par des espaces.

D2 (l'hôte garde le délai du jeu, 3 s) :

```sh
sed 's/--refus=2 --delai-poignee=\$DELAI_POIGNEE_LENT/--refus=2/' tests/reseau/lancer.sh > tests/reseau/mutant.sh
bash tests/reseau/mutant.sh 2>&1 | grep -E "COUPE|l'hôte coupe"; rm tests/reseau/mutant.sh
```

Expected : même `❌ … (3.0 s, attendu 8 s)` : c'est bien `--delai-poignee` qui porte la coupure à 8 s.

D3 (le rival part 9 s après l'acceptation du lent, après la fin de sa réservation) :

```sh
sed 's|		touch "\$JOURNAUX/feu5"|		sleep 9; touch "$JOURNAUX/feu5"|' tests/reseau/lancer.sh > tests/reseau/mutant.sh
bash tests/reseau/mutant.sh 2>&1 | grep -E "^  ❌|❌ refusé parce"; rm tests/reseau/mutant.sh
```

Expected : `❌ rival5 sort en 1`, `❌ refusé parce que la partie est pleine, sans course possible (, inscrit)` : un rival en retard est vu, pas accepté en silence.

Puis `git status --short` : seulement `tests/reseau/joueur.gd` et `tests/reseau/lancer.sh` (ni `mutant.sh`, ni `joueur.gd.orig`).

Marges (mesurées en préparant le plan, horodatages ajoutés sur une copie jetable ; 3 passages de plus sous 16 boucles de calcul actives sur 8 cœurs, tous verts, mêmes valeurs à 0,3 s près) : lent accepté 0,3 à 0,6 s après « HOTE PRET » ; rival refusé 0,07 à 0,16 s après « ACCEPTE » (marge 7,8 s sur 8) ; deuxième poignée échouée 8,3 à 8,6 s après « HOTE PRET » (marge 6,4 s sur la fenêtre de 15 s) ; lent coupé à 8,0 s ; client tardif inscrit 0,3 à 0,5 s après la libération (fenêtre neuve de 15 s). Sur un runner à 2 vCPU, seul le démarrage du lent entre encore dans une marge : il a 7 s. Les processus headless dorment entre deux images (17 % d'un cœur pour tout le passage) : ils ne chargent pas eux-mêmes le runner.

- [ ] **Step 6 : Commit**

```bash
git add tests/reseau/joueur.gd tests/reseau/lancer.sh
git commit -m "Test réseau (M1, scénario 5) : délai de poignée de main de l'hôte de test porté à 8 s (--delai-poignee, Reseau inchangé), rival démarré d'avance et lancé au feu (--feu, aussi pour les deux rivaux du scénario 2), client lent qui ne coupe plus lui-même sa poignée de main (auth_timeout 0) et vérifie la coupure par le délai de l'hôte, client tardif lancé sur « POIGNEE ECHOUEE 2 » au lieu d'un sleep

<ligne fournie par l'environnement>"
```

---

### Task 3 : le test réseau en CI

Reprise adaptée de la Task 3 du plan de la phase 11 bis.

**Files:**
- Modify: `tests/reseau/lancer.sh` (fin : journaux recopiés en cas d'échec)
- Modify: `.github/workflows/ci.yml` (un pas après « Test de la bataille locale »)

**Interfaces:**
- Consumes : `tests/reseau/lancer.sh` (Tasks 1 et 2), le Godot installé par le job dans `/usr/local/bin/godot` (nom par défaut `godot` du lanceur), `timeout` d'Ubuntu, le pas « Importer les ressources » déjà en place.
- Produces : un pas « Test réseau (transport, plusieurs processus sur localhost) » ; les phases 13 à 16 n'y touchent plus : leurs scénarios s'ajoutent à `lancer.sh`.

- [ ] **Step 1 : les journaux dans la sortie en cas d'échec**

Dans `tests/reseau/lancer.sh`, remplacer :

```sh
echo "journaux gardés dans $JOURNAUX"
exit 1
```

par :

```sh
echo "journaux gardés dans $JOURNAUX"
# Recopiés dans la sortie : en CI, c'est tout ce qui reste d'un échec.
for f in "$JOURNAUX"/*.log; do
	echo "----- $(basename "$f")"
	cat "$f"
done
exit 1
```

- [ ] **Step 2 : un échec forcé montre ses journaux ; une interruption ne laisse rien**

```sh
export PATH="/opt/homebrew/bin:$PATH"
sed 's/--manche --refus=1/--manche --refus=2/' tests/reseau/lancer.sh > tests/reseau/mutant.sh
bash tests/reseau/mutant.sh > "$TMPDIR/mutant.log" 2>&1; echo "code $?"; grep -E "^----- |poignée\(s\) de main échouée\(s\) sur 2" "$TMPDIR/mutant.log"; rm tests/reseau/mutant.sh
bash tests/reseau/lancer.sh > "$TMPDIR/int.log" 2>&1 & L=$!; sleep 14; kill -TERM $L; wait $L; echo "code après TERM : $?"
sleep 1; echo "restants : $(ps -A -o command | grep -c '[g]odot --headless --script tests/reseau')"
```

Expected : `code 1`, une ligne `----- <poste>.log` par poste de tous les scénarios (dont `----- hote3.log`) et `❌ 1 poignée(s) de main échouée(s) sur 2 attendue(s) …` recopiée ; puis `code après TERM : 130`, `restants : 0` (le `trap nettoyer EXIT` tue les `timeout`, qui tuent leur Godot ; mesuré en préparant le plan). Le `sleep 14` n'est qu'un moment quelconque du passage, pas une attente du test.

- [ ] **Step 3 : le pas de CI**

Dans `.github/workflows/ci.yml`, remplacer :

```yaml
          if grep -nE "SCRIPT ERROR|SHADER ERROR" bataille_test.log; then echo "::error::erreur de script dans le test de bataille"; exit 1; fi
```

par :

```yaml
          if grep -nE "SCRIPT ERROR|SHADER ERROR" bataille_test.log; then echo "::error::erreur de script dans le test de bataille"; exit 1; fi

      - name: Test réseau (transport, plusieurs processus sur localhost)
        shell: bash
        run: |
          set -o pipefail
          timeout 300 bash tests/reseau/lancer.sh 2>&1 | tee reseau.log
          if grep -nE "SCRIPT ERROR|SHADER ERROR" reseau.log; then echo "::error::erreur de script dans le test réseau"; exit 1; fi
```

Run : `python3 -c "import yaml; d = yaml.safe_load(open('.github/workflows/ci.yml')); print([s.get('name') for s in d['jobs']['test-et-export']['steps']])"`
Expected : `[None, "Installer Godot et les templates d'export", 'Importer les ressources', 'Tests unitaires', 'Smoke test', 'Test de la bataille locale', 'Test réseau (transport, plusieurs processus sur localhost)', 'Exporter en Web']`.

(`bash tests/reseau/lancer.sh` plutôt que `./tests/reseau/lancer.sh` : ne dépend pas du bit exécutable. Le lanceur sort en 1 sur tout échec (poste en erreur, `❌`, `SCRIPT ERROR`, `SHADER ERROR` ou `Parse Error` dans un journal, compte croisé faux) ; `pipefail` le transmet à travers `tee`. Le `grep` sur `reseau.log` reprend celui des autres pas ; sur un passage vert, le lanceur n'affiche aucun journal, il ne trouve donc rien. `timeout 300` : un passage dure une vingtaine de secondes ; si ce plafond tombait quand même, bash reçoit TERM et son `trap` tue tous les processus Godot (Step 2).)

- [ ] **Step 4 : Commit, puis CI**

```bash
git add tests/reseau/lancer.sh .github/workflows/ci.yml
git commit -m "CI : le test réseau (hôte et clients headless sur localhost) après le test de bataille ; le lanceur recopie les journaux des postes dans sa sortie en cas d'échec

<ligne fournie par l'environnement>"
```

Sur la PR, le job doit passer, pas « Test réseau » compris (une vingtaine de secondes). Si seul ce pas échoue en CI, lire les journaux recopiés à la fin de sa sortie avant toute retouche ; ne pas élargir les délais (`DELAI_ETAPE`, `DELAI`, `DELAI_POIGNEE_LENT`) sans en avoir trouvé la cause.

---

### Task 4 : feuille de route et spec

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§10)

**Interfaces:**
- Consumes : Tasks 1 à 3. La feuille de route telle que la laisse la phase 11 bis (c972ffc) : ligne 11 bis déjà sans « test réseau en CI » ni `ci.yml`, ligne 11 ter déjà créée, ligne 15 déjà « depuis la phase 11 ter », point M1 déjà renommé « phase 11 ter ».
- Produces : la ligne 11 ter décrit ce qui a été livré ; le point de vigilance M1, résolu, disparaît ; la spec dit ce que le test couvre et qu'il tourne en CI.

- [ ] **Step 1 : la feuille de route**

Vérifier d'abord l'état de départ : `grep -c "^| 11 ter |" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` doit afficher `1`. (S'il affiche `0`, la phase 11 bis n'est pas fusionnée : s'arrêter et le signaler au contrôleur, les remplacements ci-dessous visent son état.)

1a. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
| 11 ter | **Test réseau durci et en CI** : refus comptés (`--refus=N`) au lieu de fenêtres d'attente fixes, marge garantie du scénario 5 (client lent), pas « Test réseau » dans la CI. | ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` ✏️ `.github/workflows/ci.yml` | test réseau vert en CI |
```

par :

```markdown
| 11 ter | **Test réseau durci et en CI** : poignées de main échouées comptées par l'hôte de test (`--refus=N`) au lieu de fenêtres d'attente fixes ; scénario 5 à délai de poignée de main de 8 s posé par l'hôte de test (`--delai-poignee`, `Reseau.gd` inchangé), rival démarré d'avance et lancé au feu (`--feu`), client lent qui ne coupe plus lui-même sa poignée de main ; pas « Test réseau » dans la CI, journaux recopiés en cas d'échec. | ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` ✏️ `.github/workflows/ci.yml` | test réseau vert 5 fois (bash 3.2 et 5), CI verte |
```

1b. Dans le même fichier, remplacer :

```markdown
Découpage (10 fichiers avec les points de vigilance « phase 11 ») : plans des phases 11 et 11 bis. |
```

par :

```markdown
Découpage (10 fichiers avec les points de vigilance « phase 11 ») : plans des phases 11 et 11 bis, puis 11 ter (test réseau durci et en CI). |
```

1c. Dans le même fichier, supprimer (remplacer par rien) les 11 lignes du point résolu :

```markdown
- **phase 11 ter** (revue finale de la phase 11, M1) : `tests/reseau/lancer.sh` refuse les nouveaux
  venus après des fenêtres d'attente fixes (`--attente=1/2/3`), pas après un compte de refus réels :
  sur un runner de CI chargé (plusieurs processus Godot en parallèle), un démarrage lent donne
  « échec » au lieu du refus attendu, et la consigne interdit d'élargir les délais. Ajouter à
  l'hôte de test une option `--refus=N` qui compte les `peer_authentication_failed` réels et
  attend N refus au plus (borné par `DELAI_ETAPE`) avant sa vérification finale, plutôt qu'une
  pause fixe. Même chose pour le scénario 5 (client « lent ») : le rival doit arriver avant
  l'expiration de la poignée de main du client lent (3 s depuis sa connexion) sans marge
  construite ; sur un runner lent il pourrait être accepté au lieu d'être refusé. Avant que le
  test entre en CI, donner au rival une marge garantie (par exemple un délai de poignée de main
  réglable par l'hôte de test, porté à 8 s dans ce scénario, et le client tardif lancé après) ;
```

Run : `grep -nE "11 ter|--attente|phase 11 bis\*\* \(revue" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
Expected : trois lignes, toutes du tableau : 66 (ligne 11, « puis 11 ter »), 68 (ligne 11 ter, « poignées de main échouées comptées ») et 73 (ligne 15, « depuis la phase 11 ter ») ; aucune qui contienne `--attente`.

- [ ] **Step 2 : la spec (§10)**

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
  manche en cours, départ d'un client, départ de l'hôte, échec de connexion. De bout en bout (phase
```

par :

```markdown
  manche en cours, départ d'un client, départ de l'hôte, échec de connexion, place réservée dès la
  réponse de l'hôte puis libérée par le délai de poignée de main (client qui ne la finit jamais).
  Chaque étape attend un événement observé (ligne d'un journal, compte de l'hôte), jamais une durée
  fixe ; en CI depuis la phase 11 ter. De bout en bout (phase
```

- [ ] **Step 3 : Commit**

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md
git commit -m "Feuille de route et spec : phase 11 ter livrée (poignées de main échouées comptées, marge garantie du scénario 5, test réseau en CI) ; point de vigilance M1 résolu

<ligne fournie par l'environnement>"
```

---

## Sortie de phase

- `bash tests/reseau/lancer.sh` vert 5 fois de suite sous bash 5 et 5 fois sous `/bin/bash` (3.2), sans `SCRIPT ERROR` ni `SHADER ERROR` ; unitaires, smoke et bataille verts une fois ; puis le job CI vert sur la PR, pas « Test réseau » compris.
- Les preuves de discrimination D1, D2, D3 et D5 et l'échec forcé de la Task 3 ont donné les `❌` attendus, sans qu'aucun fichier hors du harnais ait été touché.
- `git diff main --stat` : 3 fichiers de test et de CI (`tests/reseau/joueur.gd`, `tests/reseau/lancer.sh`, `.github/workflows/ci.yml`), plus la feuille de route et la spec ; `git diff main --stat -- Scripts/` vide.
- `grep -n "attente\|sleep" tests/reseau/lancer.sh` : seulement les deux `sleep 0.1` des boucles de scrutation (`attendre_hote`, `attendre_ligne`) et deux commentaires (l'en-tête, « Aucune fenêtre d'attente fixe », et celui de `DELAI_POIGNEE_LENT`) ; `wc -l tests/reseau/joueur.gd tests/reseau/lancer.sh` : 295 et 210 ; `grep -n '"attente"' tests/reseau/joueur.gd` : aucune ligne.
- Rappeler à l'utilisateur : toujours rien de visible en jeu ; la phase 12 (écran Réseau) est la suivante ; ses changements de `Reseau.gd` sont désormais gardés par la CI.
