# Phase 15 : le test réseau de bout en bout (1 hôte + 3 clients, une manche entière au clavier, rencontres, un client arraché), plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** le test réseau joue une vraie manche de bataille de bout en bout, comme quatre joueurs sur leur PC : 1 hôte et 3 clients passent par l'écran Réseau et le salon, jouent la manche entière (90 s, sur le Village et son peintre) au clavier, chacun selon un programme de commandes au hasard ; l'hôte provoque les rencontres que le hasard ne garantit pas (pastilles ramassées au vol par chaque client, étoile, soucoupe, sa gerbe sur un client, la gerbe d'un client sur lui, un choc), puis un client est **arraché** (processus tué, sans un paquet de plus) ; l'hôte doit le voir partir dans le silence de session d'ENet, son lion disparaître chez tous, ses cellules rester ; à la fin, l'hôte et les deux clients restés écrivent **la même empreinte** (territoire, scores, suite des tampons, lions, apparitions, niveau, et les réactions de chaque joueur comptées sur chaque poste). Les jeux de tampons sont remesurés à 4 postes (point de vigilance de la phase 15). Sortie : le test réseau vert 5 fois (bash 3.2 et 5), les quatre suites vertes 5 fois, puis le job CI vert sur la PR. **Aucun fichier de jeu ne change.**

**Architecture:** deux fichiers de test seulement. `tests/reseau/joueur.gd` gagne une aide commune aux rôles de manche (`_rejoindre_la_manche` : écran Réseau, salon, niveau choisi par l'hôte, scène de jeu), une attente à délai réglable, et deux rôles : `bout-hote` (programme, rencontres, chronométrage du départ arraché, empreinte) et `bout-client` (programme jusqu'au calme, empreinte), avec un `Programme` de commandes au hasard tirées d'une graine, joué par `Input.action_press`, des compteurs de réactions par joueur branchés à la barrière, et une mesure image par image. `tests/reseau/lancer.sh` gagne `attendre_ligne` à délai réglable, `arracher` (KILL du processus Godot, enfant de son `timeout`) et le scénario 11. La phase 14 a déjà les scénarios 9 (hôte + 2 clients + un muet, départ par le menu, hôte perdu) et 10 (exclusion d'un poste figé) : ils restent tels quels.

**Tech Stack:** Godot 4.7.2, GDScript typé, `SceneMultiplayer` / `ENetMultiplayerPeer`, `Input.action_press`, `RandomNumberGenerator`, tests headless (`tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd`, `tests/reseau/lancer.sh` + `tests/reseau/joueur.gd`), bash 3.2 et 5, GNU `timeout`, `pkill`.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.2 flux d'une frame, §4 déconnexions (« un poste muet est considéré parti après 3 à 8 s »), §4.1 simulateur de latence : phase 16, §6 peinture et territoire, §10 tests, « De bout en bout (phase 15) ») · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 15 ; point de vigilance « phase 15 » des jeux de tampons ; point « avant la phase 16, après la 15 » : le découpage de `Lion.gd`, plan séparé de la phase 15 bis) · plan précédent : `docs/superpowers/plans/2026-09-25-phase-14-manche.md` (scénarios 9 et 10, `_empreinte`, `_finir_manche_client`) · prérequis : **phase 14 fusionnée** ; nouvelle branche `phase-15-bout-en-bout` depuis `main` · plan suivant : `docs/superpowers/plans/2026-09-26-phase-15bis-decoupage-lion.md` (le découpage de `Lion.gd`, avec ce test comme filet).

## Écarts assumés

1. **Ce que la phase 15 ajoute aux scénarios 9 et 10** (évalué contre le code de la phase 14) : le scénario 9 joue 2 × 2,5 s de passe en ligne droite à 3 postes et compare l'empreinte de l'hôte à celle d'**un** client ; ses réactions (cran, gerbe XXL, étourdissement) sont posées par des appels directs aux règles ; son départ est propre (menu local, DISCONNECT fiable). Il manque : (a) **3 clients actifs en même temps** et la même empreinte chez **tous** les postes restés ; (b) une **manche entière** sous charge (4 peintres, crans jusqu'à 4 à 6, gerbe XXL, ~5 500 tampons diffusés) ; (c) des commandes **variées** venues du réseau (huit directions, vomi par périodes) ; (d) les **interactions produites par le jeu** chez l'hôte à partir de commandes de clients : pastille touchée par un lion en mouvement, gerbe d'un client qui étourdit un autre lion, choc, soucoupe (contacts physiques, règles, puis RPC) ; (e) une **déconnexion brutale** (PC planté, Wi-Fi coupé), détectée par le silence d'ENet, pas par un DISCONNECT ; (f) une preuve qu'**aucune réaction n'est perdue ni doublée** vers un client (compteurs par joueur dans l'empreinte) ; (g) le **peintre** (réplication du `Boss`, jamais jouée en réseau jusqu'ici : le scénario 9 est sur la Skyline) ; (h) la **remesure des jeux de tampons** à 4 postes. Le scénario 11 couvre les huit.
2. **Un nouveau scénario (11), pas le 9 agrandi** : le 9 garde ce qui lui est propre (hôte figé pendant le chargement, muet exclu par la barrière, départ par le menu local, hôte perdu), le 10 l'exclusion d'un poste figé. Les rôles de manche partagent désormais leur entrée (`_rejoindre_la_manche`, Task 1) ; le 9 et le 10 ne changent pas de comportement (vérifié).
3. **La manche entière : 90 s (`DUREE11`)**. Mesuré en préparant ce plan : le scénario 11 prend **97 s** (salon, intro, 90 s de jeu, fin), le test réseau passe de 57 s à **155 s**, dans le `timeout 300` du pas « Test réseau » de la CI (`ci.yml` ne change pas). `DUREE11=45` dans `lancer.sh` le ramènerait vers 110 s si la CI se révélait plus lente (décision de l'utilisateur, voir la sortie de phase).
4. **Des rencontres orchestrées par l'hôte, pas espérées du hasard** : sur 90 s de commandes au hasard, rien ne garantit qu'un lion de client ramasse une pastille, que la gerbe d'un client touche un autre lion ou qu'un choc arrive (et un test qui l'espère serait instable). L'hôte ne décide que **des lieux** : il pose une pastille, une étoile, une soucoupe sur le lion d'un client en mouvement et à l'écart des autres (sinon un voisin au contact la prend : vu une fois, d'où `ISOLEMENT`), place un lion sous une gerbe en cours, arrête son propre lion sur la route d'un client lancé à pleine vitesse. Tous les effets passent par le jeu (contacts physiques de l'hôte, règles, RPC de la manche). Chaque rencontre d'étourdissement attend **son propre effet** (un étourdissement sans barbouillage pour la soucoupe, barbouillé de la couleur de l'agresseur pour une gerbe, vu par un signal du `Joueur`) et replace le lion, ou relance une soucoupe, tant qu'il n'est pas venu : une première version, qui s'arrêtait au premier étourdissement de la victime, a échoué 3 fois sur 16 passages (un étourdissement sans rapport, le peintre ou une soucoupe de passage, arrivé pendant qu'elle attendait : mesuré).
5. **Le programme de chaque poste** : une cible au hasard (graine `--graine`) dans la bande de peinture, rejointe en huit directions, remplacée une fois atteinte ou après 1,5 s ; le vomi par périodes de 0,2 à 0,8 s, 3 fois sur 4 ; la fuite d'un ennemi à 280 px et du peintre à 420 px, comme le pilote de la démo. Sans la fuite (mesuré), le peintre du Village, qui couvre la bande de peinture (421 px de haut posés sur les toits), étourdissait les lions sans relâche : 21 % de la ville peinte en 90 s ; avec, 58 à 66 %. Les commandes sont jouées au clavier (`Input.action_press`), comme dans le scénario 9.
6. **« Arracher » un client** : `lancer.sh` tue le processus Godot du poste (`pkill -KILL -P <pid du timeout>`, puis le `timeout`) : ni DISCONNECT, ni aucun autre paquet. L'hôte chronomètre l'écart entre ce KILL (fichier `tue11`) et `Reseau.joueur_parti` : **3,1 à 5,9 s mesurées** (`SILENCE_SESSION` : 3 à 8 s) ; le lanceur exige au plus 10 s (8 s et la marge d'une image). Le poste arraché ne peut pas effacer ses scores de test : l'hôte le fait.
7. **Les réactions comptées sur chaque poste** (`_suivre_reactions`, branché à la barrière) : par joueur, les étourdissements, crans et gerbes XXL (signaux du `Joueur` : décidés par les règles chez l'hôte, reçus par RPC chez un client) entrent dans l'empreinte. Une RPC perdue ou envoyée deux fois la fait diverger (mutation B4).
8. **Pas de simulateur de latence ni de pertes ici** : la spec (§4.1) le place dans « notre couche d'envoi », qui naît avec les commandes redondantes de la phase 16 ; son test « sous 80 ms / 40 ms / 5 % » est la sortie de la phase 16 (feuille de route).
9. **Jeux de tampons (point de vigilance de la phase 15), remesurés** : à 4 postes, crans de 1 à 6 et gerbe XXL, chaque poste a généré **9 à 15 jeux** pendant la manche ; la frame la plus longue **qui génère des jeux** : 14 à 25 ms, chez l'hôte comme chez un client ; la frame la plus longue tout court : 16 à 63 ms, sans génération dans la même frame (quatre processus Godot sur un Mac). **Pas de pré-génération** ; le point est clos (Task 3).
10. **Les statistiques de bataille (chocs, étourdissements infligés, cellules volées) n'existent que chez l'hôte** : elles ne sont pas répliquées, donc pas dans l'empreinte ; l'hôte les écrit (ligne `STATS`). Les résultats de la phase 18 devront les envoyer (nouveau point de vigilance, Task 3).
11. **Une course du harnais corrigée au passage** : un client de manche se déclarait prêt dès l'ouverture de son salon ; si la table de l'hôte n'était pas encore arrivée, le salon n'avait pas sa fiche et `Salon.basculer_pret` ne faisait rien, en silence : « Démarrer la partie » ne s'activait jamais (vu 1 fois sur 10 passages du scénario 11 sous bash 3.2, où trois clients arrivent en même temps ; latent dans le scénario 9). `_rejoindre_la_manche` attend désormais la fiche de ce poste à la table, puis que l'hôte l'enregistre prêt (Task 1). Le jeu lui-même n'est pas en cause : un joueur appuie sur Prêt en voyant sa carte.
12. **Aucun fichier de jeu ne change, `Scripts/Reseau.gd` n'est jamais muté** (l'environnement l'a déjà refusé) : les preuves (Task 2, Step 5) mutent `Scripts/Manche.gd`, `Scripts/Main.gd` et le harnais, commités, et sont annulées par `git checkout -- Scripts/ tests/`.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), commandes depuis `~/Sites/LeLion-multi`, branche `phase-15-bout-en-bout`.
- Fichiers de la phase : ✏️ `tests/reseau/joueur.gd`, ✏️ `tests/reseau/lancer.sh` ; la spec et la feuille de route (Task 3). **Aucun script, aucune scène, ni `project.godot`, ni `.github/workflows/ci.yml` ne change** (`git diff main --stat -- Scripts Scenes project.godot .github` vide en fin de phase).
- **`Scripts/Reseau.gd` n'est jamais muté**, même temporairement. Les mutations de preuve ne touchent que `Scripts/Manche.gd`, `Scripts/Main.gd` et `tests/reseau/joueur.gd`, déjà commités, et sont annulées par `git checkout -- Scripts/ tests/` : **jamais commitées**.
- Identifiants, commentaires et messages de test en français, docstrings `##`, tabulations.
- **Aucune séquence d'échappement `\u…` n'est tapée dans un fichier** (l'outillage peut la changer en caractère invisible réel). Vérifier après chaque écriture : `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' tests/reseau/joueur.gd tests/reseau/lancer.sh` ne sort rien.
- Jamais le port 7777 ni le 7778 d'une vraie partie : le scénario 11 prend `port_de_base + 11` et `port_de_base + 1011`.
- Un test `--script` est compilé **avant** les autoloads : `joueur.gd` récupère `Reseau`, `Decouverte`, `GameState`, `Scores` par `root.get_node(…)` et ne nomme ni eux, ni `Lion`, `Ennemi`, `Pastille`, la ville, la manche ; il peut nommer `Joueur`, `Commandes`, `EtatPartie`, `ReglesBataille`. Il lit les lions par leurs champs publics (`position`, `velocity`, `joueur`, `CENTRE`, `est_en_train_de_vomir`, `direction_du_lion`) et leurs zones de contact par leur nom (`ZoneContact1` à `3`, créées par le code : `find_child(…, true, false)`), jamais par un champ privé : le découpage de `Lion.gd` (phase 15 bis) ne le touchera pas.
- Le test réseau reste **enchaîné sur des événements** (lignes de journal, fichiers de rendez-vous), bash 3.2 et 5 : pas de tableaux associatifs, pas de `${var,,}`, `wait` sur des PID connus.
- **Toujours lancer un test Godot avec `timeout`** et chercher les erreurs :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; O=""; timeout -k 5 300 godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd; O=""`, `T=tests/bataille_test.gd; O="--fixed-fps 60"` ; le test réseau : `timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $?"; grep -E "❌|✅|== |\(bout|\(I1" "$TMPDIR/r.log"`). Une `SCRIPT ERROR` ne change pas le code de sortie ; un script qui ne compile pas sort aussi en `code 0`, sans ligne `== n échec(s) ==` : c'est cette absence et la `SCRIPT ERROR` qui font l'échec. Bruit connu : « ObjectDB instances were leaked », « resources still in use at exit » ; test réseau : `WARNING: Manche : le joueur … n'a pas chargé sa scène à temps, exclu` dans les journaux de `hote9` et `hote10` (voulu).
- **Un scénario seul** (pour itérer ou prouver une mutation), jamais dans le dépôt : `awk 'BEGIN{p=1} /^# 1\. Hôte \+ 2 clients/{p=0} /^# 11\. De bout en bout/{p=1} {if(p)print}' tests/reseau/lancer.sh | sed "s|^cd \"\$(dirname \"\$0\")/../..\" |cd \"$PWD\" |" > "$TMPDIR/s11.sh"; timeout -k 5 300 bash "$TMPDIR/s11.sh"` (un argument, par exemple `27777`, décale tous les ports si un autre test réseau tourne) ; les scénarios 9 et 10 seuls, une fois le 11 écrit : `awk 'BEGIN{p=1} /^# 1\. Hôte \+ 2 clients/{p=0} /^# 9\. Manche synchronisée/{p=1} /^# 11\. De bout en bout/{p=0} /^echo "== \$ECHECS/{p=1} {if(p)print}' tests/reseau/lancer.sh | sed "s|^cd \"\$(dirname \"\$0\")/../..\" |cd \"$PWD\" |" > "$TMPDIR/s9.sh"` (vérifié). Garder les journaux d'un passage vert : insérer `| sed 's/^\trm -rf "\$JOURNAUX"/\t: rm -rf/'` avant le `>` final.
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`**.
- Les quatre suites se valident sur **5 passages consécutifs verts**, le test réseau sous bash 3.2 (`/bin/bash`, macOS) et bash 5.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Une réaction perdue ou doublée pour l'un des clients** (étourdissement, cran, gerbe XXL : RPC fiables vers trois clients, dont un qui part en route) : l'affichage d'un client ment sans que rien ne casse. → compteurs de réactions par joueur dans l'empreinte, la même chez l'hôte, Anna et Chloé (Task 2, Step 2) ; mutation B4 (l'étourdissement envoyé deux fois) ⇒ `❌ de bout en bout : l'hôte, Anna et Chloé doivent finir avec la même empreinte`, mutation B2 (la gerbe XXL jamais reçue) ⇒ même `❌`.
2. **Un client planté (PC gelé, Wi-Fi coupé) en pleine manche** : son lion reste figé chez tous, ou il faut 30 s pour le voir partir, ou ses cellules s'effacent. → « l'hôte voit partir Bruno », `ECART_DEPART` au plus 10 000 ms, « son lion disparaît, ses cellules restent au territoire », « le lion du client arraché a disparu ici aussi » (Task 2) ; mutations B1 (silence de chargement gardé : `❌ l'hôte voit partir Bruno`, écart de 15 000 ms) et B3 (lion jamais retiré : `❌ son lion disparaît…`, `❌ le lion du client arraché a disparu ici aussi (4 lions)`).
3. **Une pastille touchée par le lion d'un client en mouvement** (le contact est tranché chez l'hôte, à la position de l'hôte, pendant que le client avance) : le cran part au mauvais lion, ou n'arrive jamais chez le client. → « le lion de … ramasse au vol une pastille (… px/s) : un cran de plus », deux fois par client, et les crans dans l'empreinte de chaque poste (Task 2).
4. **Une peinture qui diverge sous charge** (4 peintres, crans jusqu'à 6, gerbe XXL, ~5 500 tampons en 90 s, un poste arraché) : un client finit avec un autre territoire ou d'autres scores. → la même empreinte (territoire, scores, suite des tampons) chez les trois postes restés (Task 2) ; et, chez chaque client, la vérification des scores de `Manche._recevoir_territoire` (phase 14) ne crie jamais (aucune `ERROR` dans les journaux).
5. **Les interactions entre lions décidées par des commandes venues du réseau** (la gerbe d'un client, vomie à ses commandes, sur un autre lion ; un client lancé qui percute) : elles ne marchent qu'entre lions de l'hôte. → « la gerbe de …, vomie à ses commandes, étourdit le lion de l'hôte », « le lion de … percute celui de l'hôte : un choc compté pour les deux », « une soucoupe étourdit le lion de … » (Task 2).

---

### Task 0 : vérifications

Ce plan est commité par le commit de planification de la phase 15 : ne pas le recommiter, **ne jamais le modifier**. Vérifier que la phase 14 est fusionnée : `grep -n 'config/version="0.14"' project.godot`, `grep -n "class_name Peinture" Scripts/Peinture.gd` et `grep -n "^# 10\. I1" tests/reseau/lancer.sh` trouvent chacun une ligne. Sinon, s'arrêter et le signaler. Les blocs « Remplacer » citent le code tel que la phase 14 le laisse (vérifié en appliquant ce plan, bloc par bloc, à une copie de la branche `phase-14-manche`) : si une ancre a bougé, l'adapter au texte réel sans changer le remplacement, et le noter dans le rapport de la tâche.

Puis : `git switch -c phase-15-bout-en-bout`.

---

### Task 1 : l'entrée commune des rôles de manche et les aides du lanceur

**Files:**
- Modify: `tests/reseau/joueur.gd` (`_attendre`, `_jouer_manche`, deux fonctions après lui)
- Modify: `tests/reseau/lancer.sh` (`attendre_ligne`, `arracher` après `tuer`)

**Interfaces:**
- Consumes : harnais de la phase 14 (`_check`, `_option`, `_scene_est`, `_sur_depart`, `_ajouter_issue`, `_finir_manche_client`, `lancer`, `tuer`, `terminer`).
- Produces (Task 2) : `func _attendre(condition: Callable, delai := DELAI_ETAPE) -> bool` ; `func _rejoindre_la_manche(hote: bool) -> Node` (la scène de jeu, ou `null` ; l'hôte y choisit `--niveau=L`, défaut 0, avant « HOTE PRET ») ; `func _effacer_scores() -> void` ; dans `lancer.sh`, `attendre_ligne <nom> <motif> [secondes]` (15 par défaut) et `arracher <nom>`.

- [ ] **Step 1 : le harnais**

Dans `tests/reseau/joueur.gd` :

1a. Remplacer :

```gdscript
## Attend (au plus DELAI_ETAPE) que `condition` soit vraie ; renvoie sa dernière valeur.
func _attendre(condition: Callable) -> bool:
	var fin := Time.get_ticks_msec() + int(DELAI_ETAPE * 1000.0)
```

par :

```gdscript
## Attend (au plus `delai` secondes, DELAI_ETAPE par défaut) que `condition` soit vraie ; renvoie sa
## dernière valeur.
func _attendre(condition: Callable, delai := DELAI_ETAPE) -> bool:
	var fin := Time.get_ticks_msec() + int(delai * 1000.0)
```

1b. Remplacer :

```gdscript
func _jouer_manche(hote: bool) -> void:
	var scores: Node = root.get_node("Scores")
	var gs: Node = root.get_node("GameState")
	scores.chemin = "user://scores_reseau_%s.cfg" % reseau.pseudo
	scores.effacer()
	var script_manche: Script = load("res://Scripts/Manche.gd")
	script_manche.delai_chargement = float(_option("delai-chargement", str(script_manche.DELAI_CHARGEMENT)))
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	reseau.joueur_parti.connect(_sur_depart)
	change_scene_to_file("res://Scenes/EcranReseau.tscn")
	_check(await _attendre(func() -> bool: return _scene_est("EcranReseau")), "l'écran Réseau s'ouvre")
	var ecran: Node = current_scene
	ecran.port_jeu = int(_option("port", "17777"))
	ecran.champ_pseudo.text = reseau.pseudo
	if hote:
		ecran.heberger()
	else:
		ecran.champ_ip.text = "127.0.0.1"
		ecran.rejoindre_par_ip()
	_check(await _attendre(func() -> bool: return _scene_est("Salon")), "l'écran Réseau passe la main au salon")
	if not _scene_est("Salon"):
		reseau.quitter()
		return
	var salon: Node = current_scene
	if hote:
		print("HOTE PRET")
		var nb := 1 + int(_option("clients", "0"))
		_check(await _attendre(func() -> bool: return reseau.table_salon.size() == nb), "%d joueurs au salon" % nb)
		salon.basculer_pret()
		var bouton: Button = salon.bouton_demarrer
		_check(await _attendre(func() -> bool: return not bouton.disabled), "tous prêts : « Démarrer la partie » s'active")
		salon.demarrer()
	else:
		salon.basculer_pret()
	_check(await _attendre(func() -> bool: return _scene_est("Main")), "le salon charge la scène de jeu")
	if not _scene_est("Main"):
		reseau.quitter()
		return
	var main: Node = current_scene
	var manche: Node = main.get_node("Manche")
```

par :

```gdscript
func _jouer_manche(hote: bool) -> void:
	var main := await _rejoindre_la_manche(hote)
	if main == null:
		return
	var gs: Node = root.get_node("GameState")
	var manche: Node = main.get_node("Manche")
```

1c. Remplacer (la fin de `_jouer_manche`) :

```gdscript
	else:
		await _finir_manche_client(main, manche)
	scores.effacer()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))


## La passe de ce poste : descendre jusqu'à la hauteur de peinture (celle du pilote de la démo, 233 px
```

par :

```gdscript
	else:
		await _finir_manche_client(main, manche)
	_effacer_scores()


## Du salon à la scène de jeu d'une manche (rôles « manche-… » et « bout-… »), par les vraies scènes :
## l'écran Réseau (Héberger, ou Rejoindre par IP vers 127.0.0.1), le salon (l'hôte y choisit
## --niveau, attend 1 + --clients joueurs et démarre quand tous sont prêts), puis la scène de jeu.
## Renvoie la scène de jeu, ou null si ce poste n'y arrive pas (il a alors quitté le réseau).
func _rejoindre_la_manche(hote: bool) -> Node:
	var scores: Node = root.get_node("Scores")
	scores.chemin = "user://scores_reseau_%s.cfg" % reseau.pseudo  # jamais les préférences du joueur
	scores.effacer()
	var script_manche: Script = load("res://Scripts/Manche.gd")
	script_manche.delai_chargement = float(_option("delai-chargement", str(script_manche.DELAI_CHARGEMENT)))
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	reseau.joueur_parti.connect(_sur_depart)
	change_scene_to_file("res://Scenes/EcranReseau.tscn")
	_check(await _attendre(func() -> bool: return _scene_est("EcranReseau")), "l'écran Réseau s'ouvre")
	var ecran: Node = current_scene
	ecran.port_jeu = int(_option("port", "17777"))
	ecran.champ_pseudo.text = reseau.pseudo
	if hote:
		ecran.heberger()
	else:
		ecran.champ_ip.text = "127.0.0.1"
		ecran.rejoindre_par_ip()
	_check(await _attendre(func() -> bool: return _scene_est("Salon")), "l'écran Réseau passe la main au salon")
	if not _scene_est("Salon"):
		reseau.quitter()
		return null
	var salon: Node = current_scene
	if hote:
		var niveau := int(_option("niveau", "0"))
		while reseau.niveau_salon != niveau:
			salon.changer_niveau(1)
		print("HOTE PRET")
		var nb := 1 + int(_option("clients", "0"))
		_check(await _attendre(func() -> bool: return reseau.table_salon.size() == nb), "%d joueurs au salon" % nb)
		salon.basculer_pret()
		var bouton: Button = salon.bouton_demarrer
		_check(await _attendre(func() -> bool: return not bouton.disabled), "tous prêts : « Démarrer la partie » s'active")
		salon.demarrer()
	else:
		# Se déclarer prêt une fois à la table seulement : avant que la table de l'hôte arrive, le salon
		# n'a pas la fiche de ce poste et `basculer_pret` ne fait rien (vu une fois sur dix, 3 clients).
		var ma_fiche := func() -> bool:
			return reseau.table_salon.any(func(f: Dictionary) -> bool: return f.id == root.multiplayer.get_unique_id())
		_check(await _attendre(ma_fiche), "ce poste est à la table du salon")
		salon.basculer_pret()
		_check(await _attendre(_ma_fiche_pret), "l'hôte enregistre ce poste prêt")
	_check(await _attendre(func() -> bool: return _scene_est("Main")), "le salon charge la scène de jeu")
	if not _scene_est("Main"):
		reseau.quitter()
		return null
	return current_scene


## Les scores de test de ce poste (`_rejoindre_la_manche`) : effacés, fichier compris.
func _effacer_scores() -> void:
	var scores: Node = root.get_node("Scores")
	scores.effacer()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))


## La passe de ce poste : descendre jusqu'à la hauteur de peinture (celle du pilote de la démo, 233 px
```

Expected : `grep -n "scores\|script_manche" tests/reseau/joueur.gd | awk -F: '$1 > 670 && $1 < 725'` ne montre plus que `_effacer_scores()` dans `_jouer_manche` (les autres lignes sont dans `_rejoindre_la_manche`).

Dans `tests/reseau/lancer.sh` :

1d. Remplacer :

```bash
# attendre_ligne <nom> <motif> : attend qu'une ligne contenant <motif> apparaisse dans le journal de
# <nom>, 15 s au plus (par exemple « ACCEPTE » du rôle lent, I2).
attendre_ligne() {
	local i
	for i in $(seq 1 150); do
```

par :

```bash
# attendre_ligne <nom> <motif> [secondes] : attend qu'une ligne contenant <motif> apparaisse dans le
# journal de <nom>, 15 s au plus par défaut (par exemple « ACCEPTE » du rôle lent, I2).
attendre_ligne() {
	local i
	for i in $(seq 1 $((${3:-15} * 10))); do
```

1e. Remplacer :

```bash
# compter <motif> <nom…> : nombre de lignes qui contiennent le motif dans les journaux nommés.
```

par :

```bash
# arracher <nom> : tue sur-le-champ (KILL) le processus Godot du poste nommé, enfant de son timeout,
# puis ce timeout : le poste n'envoie plus rien, pas même un DISCONNECT, comme un PC planté ou un
# Wi-Fi coupé (scénario 11). Comme tuer(), ni son code de sortie ni son journal ne sont vérifiés ici.
arracher() {
	local nom="$1" i
	for i in "${!NOMS[@]}"; do
		if [ "${NOMS[$i]}" = "$nom" ]; then
			pkill -KILL -P "${PIDS[$i]}" 2>/dev/null
			kill -KILL "${PIDS[$i]}" 2>/dev/null
			wait "${PIDS[$i]}" 2>/dev/null
			unset "PIDS[$i]" "NOMS[$i]"
		fi
	done
	PIDS=(${PIDS[@]+"${PIDS[@]}"})
	NOMS=(${NOMS[@]+"${NOMS[@]}"})
}

# compter <motif> <nom…> : nombre de lignes qui contiennent le motif dans les journaux nommés.
```

Expected : `bash -n tests/reseau/lancer.sh && /bin/bash -n tests/reseau/lancer.sh` sans sortie ; la vérification des caractères invisibles (Global Constraints) ne sort rien.

- [ ] **Step 2 : les scénarios de manche passent toujours**

Run (scénarios 9 et 10 seuls, voir les Global Constraints) :

```bash
export PATH="/opt/homebrew/bin:$PATH"
awk 'BEGIN{p=1} /^# 1\. Hôte \+ 2 clients/{p=0} /^# 9\. Manche synchronisée/{p=1} {if(p)print}' tests/reseau/lancer.sh \
	| sed "s|^cd \"\$(dirname \"\$0\")/../..\" |cd \"$PWD\" |" > "$TMPDIR/s9.sh"
timeout -k 5 300 bash "$TMPDIR/s9.sh" > "$TMPDIR/s9.log" 2>&1; echo "code $?"; grep -E "❌|✅|== |\(I1" "$TMPDIR/s9.log"
```

Expected (mesuré) : `code 0`, `✅ manche : barrière de chargement (hôte figé, muet exclu), …, hôte perdu`, `✅ I1 : un poste figé (ENet muet) est exclu, …`, `== 0 échec(s) ==`, en 26 s environ. Le refactor ne change rien à ces deux scénarios (le niveau reste 0 sans `--niveau`).

- [ ] **Step 3 : Commit**

```bash
git add tests/reseau/joueur.gd tests/reseau/lancer.sh
git commit -m "Test réseau : entrée commune des rôles de manche (écran Réseau, salon, niveau choisi par l'hôte, scène de jeu), attente à délai réglable, attendre_ligne à délai réglable et arracher (KILL d'un poste) dans le lanceur

<ligne fournie par l'environnement>"
```

---

### Task 2 : la manche de bout en bout (scénario 11)

**Files:**
- Modify: `tests/reseau/lancer.sh` (en-tête, scénario 11 avant le bilan)
- Modify: `tests/reseau/joueur.gd` (en-tête, constantes, variables, `_run`, `_empreinte`, à la fin)

**Interfaces:**
- Consumes : Task 1 (`_attendre(condition, delai)`, `_rejoindre_la_manche`, `_effacer_scores`, `attendre_ligne … [secondes]`, `arracher`) ; phase 14 (`_empreinte`, `_finir_manche_client`, `_departs`, `manche.barriere`, `manche._prets`, `manche._exclus`, `manche.tampons_*`, `Spawner.spawn_pickup(index, position)`, `spawn_bonus(position)`, `spawn_soucoupe(y)`, `Main.lions`, `Main.lion`, `Lion.CENTRE`, zones `ZoneContact1` à `3`).
- Produces : rôles `bout-hote` (`--clients=N --niveau=L --duree=S --graine=N --partant=pseudo --tue=chemin --rester=chemin`) et `bout-client` (`--graine=N --calme=chemin --fige=chemin`) ; lignes `HOTE PRET`, `INTRO`, `RENCONTRES`, `A TUER`, `ECART_DEPART <ms>`, `DEPART VU`, `MESURE <pseudo> : …`, `CALME`, `CALME VU`, `STATS …`, `EMPREINTE …`, `FIGE`, `HOTE RESTE` ; l'empreinte gagne `niveau=L reactions=i:e,c,b;…` (vide, « reactions= », dans le scénario 9, la même chez ses deux postes) ; scénario 11 (ports `port_de_base + 11` et `+ 1011`).

- [ ] **Step 1 : le scénario 11 (le test)**

Dans `tests/reseau/lancer.sh` :

1a. Remplacer :

```bash
# Test réseau du transport (phase 11), de la découverte (phase 12), du salon (phase 13) et de la
# manche synchronisée (phase 14) : des postes headless sur localhost, un processus Godot par poste
# (tests/reseau/joueur.gd), scénario après scénario.
```

par :

```bash
# Test réseau du transport (phase 11), de la découverte (phase 12), du salon (phase 13), de la
# manche synchronisée (phase 14) et de bout en bout (phase 15) : des postes headless sur localhost,
# un processus Godot par poste (tests/reseau/joueur.gd), scénario après scénario.
```

1b. Remplacer :

```bash
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40),
```

par :

```bash
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40 ; le
# scénario 11, une manche entière, a le sien : DUREE11 + 60),
```

1c. Remplacer :

```bash
# Chaque étape s'enchaîne sur un événement observé (une ligne d'un journal, un compte de l'hôte),
# 15 s au plus (DELAI_ETAPE de joueur.gd, 150 × 0,1 s ici) ; seules restent, côté client
```

par :

```bash
# Chaque étape s'enchaîne sur un événement observé (une ligne d'un journal, un compte de l'hôte),
# 15 s au plus (DELAI_ETAPE de joueur.gd, 150 × 0,1 s ici ; plus pour les étapes de la manche
# entière du scénario 11, qui durent ce que dure le jeu) ; seules restent, côté client
```

1d. Remplacer :

```bash
[ "$ECHECS" -eq "$avant10" ] && echo "  ✅ I1 : un poste figé (ENet muet) est exclu, la barrière passe sans attendre le silence par défaut de la barrière"

echo "== $ECHECS échec(s) =="
```

par :

```bash
[ "$ECHECS" -eq "$avant10" ] && echo "  ✅ I1 : un poste figé (ENet muet) est exclu, la barrière passe sans attendre le silence par défaut de la barrière"

# 11. De bout en bout (phase 15), par les vraies scènes : un hôte et trois clients jouent une manche
#     entière (DUREE11 s) sur le Village (son peintre), chacun au clavier selon son programme (des
#     commandes au hasard, tirées de sa graine). Après 20 s de jeu, l'hôte orchestre les rencontres
#     (pastilles ramassées au vol, étoile, soucoupe, sa gerbe sur un client, celle d'un client sur lui,
#     un choc) ; puis Bruno est arraché (KILL, sans un paquet de plus) : l'hôte doit le voir partir
#     au bout du silence de session d'ENet (SILENCE_SESSION, 3 à 8 s ; ECART_DEPART), son lion
#     disparaître chez tous, ses cellules rester. Le jeu reprend jusqu'au calme, 4 s avant la fin ;
#     la manche arrivée à son terme, l'hôte la fige : l'hôte, Anna et Chloé écrivent la même empreinte
#     (territoire, scores, suite des tampons, lions, apparitions, niveau, réactions de chaque joueur).
DUREE11=90
P=$((PORT_BASE + 11))
B=$((PORT_BASE + 1011))
DELAI_AVANT11=$DELAI
DELAI=$((DUREE11 + 60))
lancer hote11 --role=bout-hote --port=$P --port-balise=$B --pseudo=Hote11 --clients=3 --niveau=2 --duree=$DUREE11 \
	--graine=1 --partant=Bruno --tue="$JOURNAUX/tue11" --rester="$JOURNAUX/rester11"
if attendre_hote hote11; then
	lancer a11 --role=bout-client --port=$P --port-balise=$B --pseudo=Anna --graine=2 --calme="$JOURNAUX/calme11" --fige="$JOURNAUX/fige11"
	lancer b11 --role=bout-client --port=$P --port-balise=$B --pseudo=Bruno --graine=3 --calme="$JOURNAUX/calme11" --fige="$JOURNAUX/fige11"
	lancer c11 --role=bout-client --port=$P --port-balise=$B --pseudo=Chloe --graine=4 --calme="$JOURNAUX/calme11" --fige="$JOURNAUX/fige11"
	if attendre_ligne hote11 "INTRO" 30 && attendre_ligne b11 "INTRO" && attendre_ligne hote11 "A TUER" 60; then
		arracher b11
		touch "$JOURNAUX/tue11"
		# Bruno arraché : son journal n'aura pas de bilan, mais ses vérifications jusque-là comptent.
		grep -HnE "❌|SCRIPT ERROR|SHADER ERROR|Parse Error" "$JOURNAUX/b11.log" && echec "de bout en bout : erreurs dans le journal de b11 avant son arrachement"
		if attendre_ligne hote11 "DEPART VU" 30 && attendre_ligne hote11 "CALME" $DUREE11; then
			touch "$JOURNAUX/calme11"
			if attendre_ligne hote11 "FIGE" 30; then
				touch "$JOURNAUX/fige11"
				attendre_ligne a11 "EMPREINTE" && attendre_ligne c11 "EMPREINTE" && touch "$JOURNAUX/rester11"
			fi
		fi
	fi
	touch "$JOURNAUX/tue11" "$JOURNAUX/calme11" "$JOURNAUX/fige11" "$JOURNAUX/rester11"
	arracher b11  # s'il n'a pas déjà été arraché (échec plus tôt) : il ne doit pas attendre son timeout
fi
terminer "de bout en bout : manche entière à 1 hôte et 3 clients au clavier, rencontres (pastilles au vol, étoile, soucoupe, gerbes croisées, choc), un client arraché en pleine manche, mêmes empreintes chez l'hôte et les clients restés"
DELAI=$DELAI_AVANT11
[ "$(grep -h "^EMPREINTE " "$JOURNAUX/hote11.log" "$JOURNAUX/a11.log" "$JOURNAUX/c11.log" 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
	&& [ "$(compter "^EMPREINTE " hote11 a11 c11)" -eq 3 ] || echec "de bout en bout : l'hôte, Anna et Chloé doivent finir avec la même empreinte"
ecart11=$(grep -o "ECART_DEPART [0-9]*" "$JOURNAUX/hote11.log" 2>/dev/null | head -1 | awk '{print $2}')
echo "  (bout en bout) départ arraché vu par l'hôte au bout de ${ecart11:-?} ms"
[ -n "$ecart11" ] && [ "$ecart11" -le 10000 ] 2>/dev/null \
	|| echec "de bout en bout : départ arraché vu au bout de ${ecart11:-?} ms (attendu au plus 10000 : le silence de session d'ENet, 8 s au plus, et la marge d'une image)"

echo "== $ECHECS échec(s) =="
```

- [ ] **Step 2 : le scénario échoue**

Run (le scénario 11 seul, voir les Global Constraints) : `bash -n tests/reseau/lancer.sh`, puis la commande `$TMPDIR/s11.sh`.
Expected (mesuré) : `code 1` en 17 s environ ; dans le journal de `hote11` (le seul poste lancé), `❌ rôle inconnu : --role=hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client ou manche-muet` ; dans la sortie du lanceur, `❌ l'hôte hote11 n'écoute pas` (il ne se déclare jamais prêt, les clients ne partent pas), `❌ de bout en bout : manche entière … : erreurs dans le journal de hote11`, `❌ de bout en bout : l'hôte, Anna et Chloé doivent finir avec la même empreinte`, `❌ de bout en bout : départ arraché vu au bout de ? ms …`, `== 5 échec(s) ==`.

- [ ] **Step 3 : les rôles de bout en bout**

Dans `tests/reseau/joueur.gd` :

3a. Remplacer :

```gdscript
## Rôles : hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client,
## manche-muet.
```

par :

```gdscript
## Rôles : hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client,
## manche-muet, bout-hote, bout-client.
```

3b. Remplacer :

```gdscript
##   poste dont le fil principal compile ses shaders.
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
```

par :

```gdscript
##   poste dont le fil principal compile ses shaders.
## Manche de bout en bout (phase 15), par les vraies scènes : 1 hôte + 3 clients jouent une manche
##   entière au clavier, chacun selon son programme (des commandes au hasard tirées de --graine=N,
##   voir `Programme`), sur le niveau --niveau=L choisi par l'hôte au salon ; chaque poste mesure sa
##   frame la plus longue (« MESURE ») et compte les réactions de chaque joueur reçues ou décidées.
##   Bout-hôte : --clients=N, --niveau=L, --duree=S (défaut : la manche entière,
##   `ReglesBataille.DUREE_MANCHE`), --partant=pseudo, --tue=chemin, --rester=chemin. Après
##   DEBUT_RENCONTRES s de jeu, orchestre les rencontres (il ne décide que des lieux : il déplace des
##   lions et fait apparaître pastilles, étoile et soucoupe sur eux ; les effets passent par le jeu) :
##   une pastille ramassée au vol par chaque client, une étoile, une soucoupe, sa gerbe sur un client,
##   la gerbe d'un client sur lui, un choc. Écrit « RENCONTRES », puis « A TUER » : lancer.sh arrache
##   le poste de --partant (KILL, sans un paquet de plus) et crée --tue ; l'hôte chronomètre la
##   détection du départ (« ECART_DEPART <ms> ») et écrit « DEPART VU ». À DUREE_CALME s de la fin,
##   écrit « CALME » ; lions arrêtés, coulures finies et la manche arrivée à son terme, il la fige :
##   « STATS … », « EMPREINTE … », « FIGE ».
##   Bout-client : --graine=N, --calme=chemin (joue son programme jusqu'à ce fichier, puis écrit
##   « CALME VU »), --fige=chemin (comme un client de la manche : sa propre « EMPREINTE »).
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
```

3c. Remplacer :

```gdscript
const DELAI_ETAPE := 15.0  # secondes au plus pour chaque attente
```

par :

```gdscript
const DELAI_ETAPE := 15.0  # secondes au plus pour chaque attente
## Manche de bout en bout : secondes de jeu avant les rencontres, puis avant la fin où tout se calme.
const DEBUT_RENCONTRES := 20.0
const DUREE_CALME := 4.0
## Vitesse (px/s) au-delà de laquelle un lion ramasse une pastille « au vol », ou percute l'hôte.
const VITESSE_AU_VOL := 150.0
const VITESSE_CHOC := 250.0
## Une pastille posée sur un lion n'est à lui que si aucun autre lion n'est à moins de cette distance
## (de centre à centre) : deux lions au contact la toucheraient tous les deux, premier arrivé, premier
## servi.
const ISOLEMENT := 200.0
```

3d. Remplacer :

```gdscript
## Salon : la ligne d'état du salon notée après chaque `salon_change`, une fois l'affichage à jour.
var _textes_etat: Array[String] = []
```

par :

```gdscript
## Salon : la ligne d'état du salon notée après chaque `salon_change`, une fois l'affichage à jour.
var _textes_etat: Array[String] = []
## Manche de bout en bout : par index de joueur, les réactions vues sur ce poste depuis la barrière
## (`[étourdissements, crans, gerbes XXL]`, voir `_suivre_reactions`).
var _reactions: Dictionary[int, Array] = {}
## Manche de bout en bout : la frame la plus longue de ce poste (ms), de l'intro au calme, et la plus
## longue de celles qui ont généré des jeux de tampons (point de vigilance de la phase 15).
var _pire_frame_ms := 0.0
var _pire_frame_generation_ms := 0.0
var _instant_frame := 0
var _ville_mesuree: Node2D
var _jeux_vus := 0
var _jeux_generes := 0
```

3e. Remplacer :

```gdscript
	elif role == "manche-muet":
		await _jouer_muet()
	else:
		_check(false, "rôle inconnu : --role=hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client ou manche-muet")
```

par :

```gdscript
	elif role == "manche-muet":
		await _jouer_muet()
	elif role == "bout-hote" or role == "bout-client":
		await _jouer_bout(role == "bout-hote")
	else:
		_check(false, "rôle inconnu : --role=hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client, manche-muet, bout-hote ou bout-client")
```

3f. Remplacer :

```gdscript
## (position, orientation, crans, étourdi, gerbe XXL), apparitions (ennemis et pastilles : nom et position). Pas l'image
```

par :

```gdscript
## (position, orientation, crans, étourdi, gerbe XXL), apparitions (ennemis et pastilles : nom et position),
## niveau et, pour la manche de bout en bout, les réactions de chaque joueur vues ici. Pas l'image
```

3g. Remplacer :

```gdscript
	apparitions.sort()
	return "territoire=%d scores=%s tampons=%d:%d lions=%s apparitions=%s" % [hash(proprietaires), territoire.scores(),
		manche.tampons_diffuses if hote else manche.tampons_recus, manche.empreinte_tampons, ";".join(lions), ";".join(apparitions)]
```

par :

```gdscript
	apparitions.sort()
	var reactions: Array[String] = []
	var indices := _reactions.keys()
	indices.sort()
	for i: int in indices:
		reactions.append("%d:%d,%d,%d" % [i, _reactions[i][0], _reactions[i][1], _reactions[i][2]])
	return "territoire=%d scores=%s tampons=%d:%d lions=%s apparitions=%s niveau=%d reactions=%s" % [hash(proprietaires), territoire.scores(),
		manche.tampons_diffuses if hote else manche.tampons_recus, manche.empreinte_tampons, ";".join(lions), ";".join(apparitions),
		root.get_node("GameState").niveau_courant, ";".join(reactions)]
```

3h. Ajouter à la fin du fichier (après la dernière ligne de `_jouer_muet`, une ligne vide puis deux) :

```gdscript


## Rôles « bout-hote » et « bout-client » (phase 15, voir l'en-tête) : une manche entière à 1 hôte et
## 3 clients, chacun au clavier selon son programme, avec les rencontres de l'hôte et un client
## arraché en pleine manche ; la même empreinte chez l'hôte et chez chaque client resté.
func _jouer_bout(hote: bool) -> void:
	var main := await _rejoindre_la_manche(hote)
	if main == null:
		return
	var gs: Node = root.get_node("GameState")
	var manche: Node = main.get_node("Manche")
	_check(await _attendre(func() -> bool: return manche.barriere), "la barrière de chargement passe")
	_suivre_reactions(gs)
	if hote:
		_check(manche._prets.size() == gs.joueurs.size() - 1 and manche._exclus.is_empty(),
			"chaque client a chargé sa scène, personne n'est exclu (%s)" % [manche._prets])
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size()) and gs.joueurs.size() == 4,
		"un lion par joueur, 1 hôte et 3 clients (%d)" % main.lions.size())
	_check(await _attendre(func() -> bool: return gs.pret), "l'intro se termine chez tous")
	_check(gs.niveau_courant == int(_option("niveau", str(gs.niveau_courant))) and get_first_node_in_group("boss") != null,
		"le niveau choisi au salon (%d), avec son peintre" % gs.niveau_courant)
	print("INTRO")
	_commencer_mesure(main)
	var programme := Programme.new(int(_option("graine", "1")), main.get_node("Ville"))
	if hote:
		await _animer_bout_hote(main, manche, gs, programme)
	else:
		await _animer_bout_client(main, manche, gs, programme)
	_effacer_scores()


## Le programme de jeu d'un poste de la manche de bout en bout : des commandes au hasard, tirées de
## sa graine, jouées au clavier comme un joueur (`Input.action_press`). Une cible au hasard dans la
## bande de peinture (au-dessus des toits, comme le pilote de la démo), rejointe en huit directions et
## remplacée une fois atteinte ou au bout de DUREE_CIBLE ms ; le vomi par périodes de 0,2 à 0,8 s,
## trois fois sur quatre. Comme le pilote de la démo, il fuit d'abord un ennemi proche, et le peintre
## (plus grand) de plus loin : sans quoi le peintre, qui couvre la bande de peinture du Village,
## étourdirait les lions sans relâche et plus personne ne jouerait.
class Programme:
	const DUREE_CIBLE := 1500
	const DISTANCE_DANGER := 280.0
	const DISTANCE_DANGER_PEINTRE := 420.0
	const ACTIONS: Array[String] = ["deplacer_gauche", "deplacer_droite", "deplacer_haut", "deplacer_bas", "vomir"]
	var rng := RandomNumberGenerator.new()
	var bande: Rect2
	var cible := Vector2.ZERO
	var fin_cible := 0
	var fin_vomi := 0

	func _init(graine: int, ville: Node2D) -> void:
		rng.seed = graine
		var haut: float = ville.position.y - ville.tex_size.y / 2.0
		bande = Rect2(100.0, haut - 300.0, 1650.0, 120.0)

	## Une image de jeu pour `lion` (le lion de ce poste, dont la position est celle de l'hôte).
	func piloter(lion: Node2D) -> void:
		var maintenant := Time.get_ticks_msec()
		if maintenant >= fin_cible or lion.position.distance_to(cible) < 30.0:
			cible = Vector2(rng.randf_range(bande.position.x, bande.end.x), rng.randf_range(bande.position.y, bande.end.y))
			fin_cible = maintenant + DUREE_CIBLE
		if maintenant >= fin_vomi:
			_basculer("vomir", rng.randf() < 0.75)
			fin_vomi = maintenant + rng.randi_range(200, 800)
		var ecart := cible - lion.position
		var fuite := _fuite(lion)
		if fuite != Vector2.ZERO:
			ecart = fuite * 100.0
		_basculer("deplacer_gauche", ecart.x < -20.0)
		_basculer("deplacer_droite", ecart.x > 20.0)
		_basculer("deplacer_haut", ecart.y < -20.0)
		_basculer("deplacer_bas", ecart.y > 20.0)

	## La direction qui éloigne `lion` des ennemis et du peintre trop proches (nulle s'il n'y en a pas).
	func _fuite(lion: Node2D) -> Vector2:
		var centre: Vector2 = lion.position + lion.CENTRE
		var fuite := Vector2.ZERO
		for groupe: String in ["ennemi", "boss"]:
			var distance := DISTANCE_DANGER if groupe == "ennemi" else DISTANCE_DANGER_PEINTRE
			for ennemi: Node2D in lion.get_tree().get_nodes_in_group(groupe):
				var ecart: Vector2 = centre - ennemi.global_position
				if ecart.length() < distance:
					fuite += ecart.normalized() * (distance - ecart.length())
		return fuite.normalized()

	## Toutes les touches relâchées : le lion s'arrête et ne vomit plus.
	func relacher() -> void:
		for action in ACTIONS:
			Input.action_release(action)

	static func _basculer(action: String, appuyee: bool) -> void:
		if appuyee:
			Input.action_press(action)
		else:
			Input.action_release(action)


## Joue le programme de ce poste, image après image, jusqu'à `condition` (au plus `delai` secondes).
func _jouer_jusqu_a(main: Node, programme: Programme, condition: Callable, delai: float) -> bool:
	var fin := Time.get_ticks_msec() + int(delai * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < fin:
		if main.lion != null:
			programme.piloter(main.lion)
		await process_frame
	return condition.call()


## Compte, sur ce poste, les réactions de chaque joueur : étourdissements, crans et gerbes XXL. Chez
## l'hôte, celles que décident ses règles ; chez un client, celles que sa manche reçoit de l'hôte.
## Branché dès la barrière passée : les mêmes comptes partout prouvent qu'aucune n'est perdue ni
## doublée en route.
func _suivre_reactions(gs: Node) -> void:
	for j: Joueur in gs.joueurs:
		var comptes := [0, 0, 0]  # un Array, partagé avec les lambdas (capturé par référence)
		_reactions[j.index] = comptes
		j.etourdi.connect(func(_origine: Vector2, _barbouillage: Color) -> void: comptes[0] += 1)
		j.crans_changes.connect(func(_crans: int) -> void: comptes[1] += 1)
		j.bonus_change.connect(func(actif: bool) -> void:
			if actif:
				comptes[2] += 1)


## Mesure de ce poste de l'intro au calme, à chaque image (`process_frame`) : la durée de l'image
## qui s'achève, et si des jeux de tampons y ont été générés (le cache de la ville a grandi).
func _mesurer_frame() -> void:
	var maintenant := Time.get_ticks_usec()
	var jeux: int = _ville_mesuree._tampons.size()
	if _instant_frame > 0:
		var duree := (maintenant - _instant_frame) / 1000.0
		_pire_frame_ms = maxf(_pire_frame_ms, duree)
		if jeux > _jeux_vus:
			_pire_frame_generation_ms = maxf(_pire_frame_generation_ms, duree)
			_jeux_generes += jeux - _jeux_vus
	_jeux_vus = jeux
	_instant_frame = maintenant


func _commencer_mesure(main: Node) -> void:
	_ville_mesuree = main.get_node("Ville")
	_jeux_vus = _ville_mesuree._tampons.size()
	process_frame.connect(_mesurer_frame)


## La mesure de ce poste, de l'intro au calme : jeux de tampons, frame la plus longue.
func _ecrire_mesure() -> void:
	process_frame.disconnect(_mesurer_frame)
	print("MESURE %s : %d jeux de tampons en cache, %d générés pendant la manche ; frame la plus longue %.0f ms, %.0f ms au plus pour une frame qui en génère"
		% [reseau.pseudo, _ville_mesuree._tampons.size(), _jeux_generes, _pire_frame_ms, _pire_frame_generation_ms])


## Vrai si aucun autre lion de la manche n'a son centre à moins d'ISOLEMENT de celui de `lion`.
func _isole(lion: Node2D, main: Node) -> bool:
	var centre: Vector2 = lion.global_position + lion.CENTRE
	return main.lions.all(func(l: Node2D) -> bool: return l == lion or centre.distance_to(l.global_position + l.CENTRE) >= ISOLEMENT)


## La zone de contact `n` (1 à 3, de la bouche au point de chute) de la gerbe d'un lion.
func _zone_de_contact(lion: Node, n: int) -> Node2D:
	return lion.find_child("ZoneContact%d" % n, true, false)


func _animer_bout_hote(main: Node, manche: Node, gs: Node, programme: Programme) -> void:
	var duree := float(_option("duree", str(ReglesBataille.DUREE_MANCHE)))
	var ville: Node2D = main.get_node("Ville")
	_check(await _jouer_jusqu_a(main, programme, func() -> bool: return gs.temps_ecoule >= DEBUT_RENCONTRES, DEBUT_RENCONTRES + 10.0),
		"%.0f s de jeu libre avant les rencontres" % DEBUT_RENCONTRES)
	programme.relacher()
	await _rencontres(main, gs)
	print("RENCONTRES")

	# Un client arraché en pleine manche (KILL : ni DISCONNECT ni aucun autre paquet), comme un PC
	# planté ou un Wi-Fi coupé : l'hôte le voit partir au bout du silence de session d'ENet.
	var partant: Joueur = null
	for j: Joueur in gs.joueurs:
		if j.pseudo == _option("partant", ""):
			partant = j
	_check(partant != null, "(pré-condition) le client à arracher est dans la manche (%s)" % _option("partant", ""))
	if partant == null:
		return
	print("A TUER")
	_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("tue", ""))), "lancer.sh arrache le poste de %s" % partant.pseudo)
	var arrache_a := Time.get_ticks_msec()
	_check(await _attendre(func() -> bool: return _departs.has(partant.id_reseau)), "l'hôte voit partir %s" % partant.pseudo)
	print("ECART_DEPART %d" % (Time.get_ticks_msec() - arrache_a))
	var sans_lui := func() -> bool:
		return main.lions.size() == gs.joueurs.size() - 1 and main.lions.all(func(l: Node) -> bool: return l.joueur != partant)
	var cellules: int = ville.territoire.cellules_de(partant.index)
	_check(await _attendre(sans_lui) and cellules > 0, "son lion disparaît, ses cellules restent au territoire (%d)" % cellules)
	print("DEPART VU")
	# Le poste arraché n'a pas pu effacer ses scores de test (`_rejoindre_la_manche`) : l'hôte le fait.
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://scores_reseau_%s.cfg" % partant.pseudo))

	_check(await _jouer_jusqu_a(main, programme, func() -> bool: return gs.temps_ecoule >= duree - DUREE_CALME, duree),
		"le jeu continue jusqu'à %.0f s de la fin" % DUREE_CALME)
	programme.relacher()
	_ecrire_mesure()
	print("CALME")
	var calme := func() -> bool:
		return main.lions.all(func(l: Node) -> bool: return l.velocity == Vector2.ZERO) and ville.coulures.is_empty()
	_check(await _attendre(calme), "les lions s'arrêtent, les coulures finissent")
	_check(await _attendre(func() -> bool: return gs.temps_ecoule >= duree), "la manche va jusqu'au bout de ses %.0f s" % duree)
	gs.terminer_partie(false)  # tout se fige chez l'hôte (bataille) ; la manche diffuse encore
	await _pause(1.0)
	print("STATS chocs=%s etourdissements=%s vols=%s crans=%s" % [gs.joueurs.map(func(j: Joueur) -> int: return j.chocs),
		gs.joueurs.map(func(j: Joueur) -> int: return j.etourdissements_infliges),
		gs.joueurs.map(func(j: Joueur) -> int: return j.cellules_volees), gs.joueurs.map(func(j: Joueur) -> int: return j.crans)])
	print("EMPREINTE %s" % _empreinte(main, manche, true))
	print("FIGE")
	if _options.has("rester"):
		var rester := _option("rester", "")
		print("HOTE RESTE")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
	paused = false
	reseau.quitter()


## Les rencontres de la manche de bout en bout. L'hôte ne décide que des lieux (il déplace des lions,
## fait apparaître une pastille, une étoile, une soucoupe sur eux) ; les effets passent par le jeu :
## contacts physiques chez l'hôte, règles, réactions diffusées aux clients. Les clients jouent leur
## programme pendant ce temps ; le lion de l'hôte, touches relâchées, sert d'outil.
func _rencontres(main: Node, gs: Node) -> void:
	var spawner: Node = main.get_node("Spawner")
	var lion_hote: Node2D = main.lion
	var moi: Joueur = gs.joueur_local()
	var clients: Array = main.lions.filter(func(l: Node) -> bool: return l != lion_hote)

	# Deux pastilles ramassées au vol par le lion de chaque client, l'une après l'autre
	for l: Node2D in clients + clients:
		var j: Joueur = l.joueur
		var crans_avant := j.crans
		_check(await _attendre(func() -> bool: return l.velocity.length() >= VITESSE_AU_VOL and not j.est_etourdi() and _isole(l, main)),
			"(pré-condition) le lion de %s est en mouvement, à l'écart des autres" % j.pseudo)
		var vitesse: float = l.velocity.length()
		spawner.spawn_pickup(0, l.global_position + l.CENTRE)
		_check(await _attendre(func() -> bool: return j.crans == mini(crans_avant + 1, Joueur.CRANS_MAX)),
			"le lion de %s ramasse au vol une pastille (%.0f px/s) : un cran de plus (%d)" % [j.pseudo, vitesse, j.crans])

	# Une étoile, au vol aussi, pour le troisième client en train de peindre : la gerbe XXL
	var l3: Node2D = clients[2]
	var j3: Joueur = l3.joueur
	var peint_seul := func() -> bool:
		return (l3.velocity.length() >= VITESSE_AU_VOL and l3.est_en_train_de_vomir and not j3.bonus_actif()
			and not j3.est_etourdi() and _isole(l3, main))
	_check(await _attendre(peint_seul), "(pré-condition) le lion de %s vomit en mouvement, à l'écart des autres, sans gerbe XXL" % j3.pseudo)
	spawner.spawn_bonus(l3.global_position + l3.CENTRE)
	_check(await _attendre(func() -> bool: return j3.bonus_actif()), "le lion de %s ramasse une étoile : la gerbe XXL" % j3.pseudo)

	# Une soucoupe sur le lion du premier client : un ennemi l'étourdit (sans barbouillage). Une autre
	# soucoupe tant qu'il n'est pas étourdi par un ennemi : il a pu l'être entre-temps par une gerbe,
	# ou être encore immunisé quand la première est passée.
	var l1: Node2D = clients[0]
	var j1: Joueur = l1.joueur
	var par_ennemi := [false]  # des Array, partagés avec les lambdas
	var sur_ennemi := func(_origine: Vector2, barbouillage: Color) -> void:
		if barbouillage.a == 0.0:
			par_ennemi[0] = true
	j1.etourdi.connect(sur_ennemi)
	var soucoupe: Node2D = null
	var fin := Time.get_ticks_msec() + int(DELAI_ETAPE * 1000.0)
	while not par_ennemi[0] and Time.get_ticks_msec() < fin:
		var centre: Vector2 = l1.global_position + l1.CENTRE
		var partie := soucoupe == null or not is_instance_valid(soucoupe) or soucoupe.global_position.distance_to(centre) > 150.0
		if partie and not j1.est_etourdi() and not j1.est_invulnerable():
			soucoupe = spawner.spawn_soucoupe(centre.y)
			soucoupe.position.x = centre.x
		await physics_frame
	j1.etourdi.disconnect(sur_ennemi)
	_check(par_ennemi[0], "une soucoupe étourdit le lion de %s" % j1.pseudo)

	# La gerbe de l'hôte sur le lion du deuxième client, qu'il place sur la trajectoire tant qu'il peut
	# être étourdi, jusqu'à ce qu'elle l'étourdisse (barbouillé de la couleur de l'hôte : pas un ennemi)
	var l2: Node2D = clients[1]
	var j2: Joueur = l2.joueur
	var par_hote := [false]
	var sur_gerbe_hote := func(_origine: Vector2, barbouillage: Color) -> void:
		if barbouillage == moi.couleur:
			par_hote[0] = true
	j2.etourdi.connect(sur_gerbe_hote)
	lion_hote.global_position = Vector2(600, 250)
	lion_hote.direction_du_lion = 1
	Input.action_press("vomir")
	fin = Time.get_ticks_msec() + int(DELAI_ETAPE * 1000.0)
	while not par_hote[0] and Time.get_ticks_msec() < fin:
		if lion_hote.est_en_train_de_vomir and not j2.est_etourdi() and not j2.est_invulnerable():
			l2.global_position = _zone_de_contact(lion_hote, 2).global_position - l2.CENTRE
		await physics_frame
	Input.action_release("vomir")
	j2.etourdi.disconnect(sur_gerbe_hote)
	_check(par_hote[0], "la gerbe de l'hôte étourdit le lion de %s, qui passe dessous" % j2.pseudo)

	# La gerbe du troisième client (ses commandes, venues du réseau) sur le lion de l'hôte, de même
	var par_client := [false]
	var sur_gerbe_client := func(_origine: Vector2, barbouillage: Color) -> void:
		if barbouillage == j3.couleur:
			par_client[0] = true
	moi.etourdi.connect(sur_gerbe_client)
	fin = Time.get_ticks_msec() + int(DELAI_ETAPE * 1000.0)
	while not par_client[0] and Time.get_ticks_msec() < fin:
		if l3.est_en_train_de_vomir and not j3.est_etourdi() and not moi.est_etourdi() and not moi.est_invulnerable():
			l3.global_position = Vector2(1200, 250)
			lion_hote.global_position = _zone_de_contact(l3, 2).global_position - lion_hote.CENTRE
		await physics_frame
	moi.etourdi.disconnect(sur_gerbe_client)
	_check(par_client[0], "la gerbe de %s, vomie à ses commandes, étourdit le lion de l'hôte" % j3.pseudo)

	# Un choc : un client lancé à pleine vitesse percute le lion de l'hôte, arrêté sur sa route
	var chocs_hote := moi.chocs
	fin = Time.get_ticks_msec() + int(DELAI_ETAPE * 1000.0)
	var percuteur: Node2D = null
	while moi.chocs == chocs_hote and Time.get_ticks_msec() < fin:
		if lion_hote.velocity.length() < 1.0:
			for l: Node2D in clients:
				var dans_le_ciel := Rect2(300, 150, 1300, 550).has_point(l.global_position)
				if l.velocity.length() >= VITESSE_CHOC and not l.joueur.est_etourdi() and dans_le_ciel:
					percuteur = l
					lion_hote.global_position = l.global_position + l.velocity.normalized() * 80.0
					break
		await physics_frame
	_check(moi.chocs > chocs_hote and percuteur != null and percuteur.joueur.chocs > 0,
		"le lion de %s percute celui de l'hôte : un choc compté pour les deux" % ("?" if percuteur == null else percuteur.joueur.pseudo))


func _animer_bout_client(main: Node, manche: Node, gs: Node, programme: Programme) -> void:
	var calme := _option("calme", "")
	_check(await _jouer_jusqu_a(main, programme, func() -> bool: return FileAccess.file_exists(calme), ReglesBataille.DUREE_MANCHE + 30.0),
		"le jeu dure jusqu'au calme annoncé par lancer.sh (%s)" % calme)
	programme.relacher()
	_ecrire_mesure()
	print("CALME VU")
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size() - 1),
		"le lion du client arraché a disparu ici aussi (%d lions)" % main.lions.size())
	await _finir_manche_client(main, manche)
```

Expected : la vérification des caractères invisibles ne sort rien ; `godot --headless --check-only --script tests/reseau/joueur.gd` (sous `timeout 60`) n'écrit aucune `Parse Error`. Remarque : dans une lambda multi-lignes passée en argument, une expression continuée sur la ligne suivante doit être entre parenthèses (d'où `peint_seul`) ; sinon « Expected closing ")" after call arguments ».

- [ ] **Step 4 : le scénario passe**

Run : le scénario 11 seul (`$TMPDIR/s11.sh`, en gardant les journaux : voir les Global Constraints).
Expected (mesuré sur 10 passages du test entier, 5 sous bash 5 et 5 sous bash 3.2, avec les correctifs des Écarts 4 et 11) : `code 0`, `✅ de bout en bout : manche entière à 1 hôte et 3 clients au clavier, …`, `(bout en bout) départ arraché vu par l'hôte au bout de 3181 à 5882 ms`, `== 0 échec(s) ==`, en 97 s environ. Dans les journaux : chez `hote11`, 18 vérifications de rencontres vertes (six pastilles au vol, de 160 à 350 px/s, et leurs pré-conditions, l'étoile, la soucoupe, les deux gerbes, le choc), `ECART_DEPART …`, `STATS chocs=[…] etourdissements=[…] vols=[…] crans=[…]` (par exemple `chocs=[40, 27, 37, 26] etourdissements=[7, 10, 13, 11] vols=[196, 592, 595, 252] crans=[1, 3, 3, 3]`) ; les trois lignes `EMPREINTE territoire=… scores=[…] tampons=5500 à 6300:… lions=Lion1:…;…;… apparitions=Boss@…;… niveau=2 reactions=0:…;1:…;2:…;3:…` de `hote11`, `a11`, `c11` identiques ; `MESURE` de chaque poste : 9 à 15 jeux de tampons générés, frame la plus longue 16 à 63 ms, 14 à 25 ms au plus pour une frame qui génère des jeux (Écart 9) ; `b11.log` s'arrête après `INTRO` sans `❌`.

Puis les scénarios 9 et 10 seuls (commande `$TMPDIR/s9.sh` des Global Constraints, qui coupe avant le 11) : toujours `code 0` ; les deux `EMPREINTE` du 9 finissent désormais par `niveau=0 reactions=` (les mêmes chez l'hôte et Anna).

- [ ] **Step 5 : Commit, puis le test discrimine**

```bash
git add tests/reseau/joueur.gd tests/reseau/lancer.sh
git commit -m "Test réseau : scénario 11, la manche de bout en bout (1 hôte et 3 clients au clavier sur le Village, programmes de commandes au hasard, rencontres orchestrées par l'hôte : pastilles au vol, étoile, soucoupe, gerbes croisées, choc ; un client arraché en pleine manche, départ chronométré ; mêmes empreintes, réactions comprises, chez l'hôte et les clients restés ; jeux de tampons remesurés à 4 postes)

<ligne fournie par l'environnement>"
```

Puis chaque mutation seule, le scénario 11 seul (`$TMPDIR/s11.sh`, régénéré après la mutation s'il s'agit de `lancer.sh`), et **`git checkout -- Scripts/ tests/`** avant la suivante (mesuré en préparant le plan ; `Scripts/Reseau.gd` n'est jamais muté) :
- B1 (le silence de chargement gardé, par le harnais) : dans `tests/reseau/joueur.gd`, `_jouer_bout`, ajouter `reseau.definir_silence(Vector2i(20000, 30000))` juste après la ligne `_check(await _attendre(func() -> bool: return manche.barriere), "la barrière de chargement passe")` ⇒ chez `hote11` : `❌ l'hôte voit partir Bruno` ; `(bout en bout) départ arraché vu par l'hôte au bout de 15002 ms` puis `❌ de bout en bout : départ arraché vu au bout de 15002 ms (attendu au plus 10000 …)` ;
- B2 : dans `Scripts/Manche.gd`, `_recevoir_bonus`, remplacer les deux lignes `if j != null and _duree_valide(duree):` / `j.activer_bonus(duree)` par `pass` ⇒ `❌ de bout en bout : l'hôte, Anna et Chloé doivent finir avec la même empreinte` (les clients ne comptent pas la gerbe XXL de l'étoile) ;
- B3 : dans `Scripts/Main.gd`, `_sur_joueur_parti`, remplacer `l.queue_free()` par `pass` ⇒ `❌ son lion disparaît, ses cellules restent au territoire (…)` chez `hote11`, `❌ le lion du client arraché a disparu ici aussi (4 lions)` chez `a11` et `c11` ;
- B4 : dans `Scripts/Manche.gd`, `_sur_etourdi`, dupliquer la ligne `_envoyer(&"_recevoir_etourdi", [j.index, j.etourdi_restant, j.invulnerable_restant - j.etourdi_restant, origine, barbouillage])` (l'étourdissement part deux fois) ⇒ `❌ de bout en bout : l'hôte, Anna et Chloé doivent finir avec la même empreinte` (les compteurs de réactions des clients doublent).

Expected ensuite : `git status --short` vide.

- [ ] **Step 6 : les suites, 5 fois**

Run : 5 fois de suite chacune des trois suites Godot et `bash tests/reseau/lancer.sh`, puis 5 fois `/bin/bash tests/reseau/lancer.sh` (bash 3.2 de macOS).
Expected : chaque fois `code 0` et `== 0 échec(s) ==`, aucune `SCRIPT ERROR` ni `SHADER ERROR`, 10 lignes ✅ au test réseau (mesuré en préparant le plan : unitaires 2 s, smoke test 19 s, bataille 3 s, test réseau **155 s**, écart du départ arraché de 3,1 à 5,9 s).

---

### Task 3 : feuille de route et spec

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`

**Interfaces:**
- Consumes : Tasks 1 et 2, Écarts 1 à 12 ; la feuille de route telle que la phase 14 l'a laissée.
- Produces : ligne 15 faite ; point de vigilance « phase 15 » des jeux de tampons résolu ; nouveaux points pour les phases 16 (temps de la CI), 17 (le peintre en bataille), 18 (statistiques chez les clients) et la prochaine phase qui touche `tests/reseau/lancer.sh` (scores du scénario 10) ; spec §10 à jour.

- [ ] **Step 1 : la feuille de route**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` :

1a. Remplacer :

```text
| 15 | **Test réseau de bout en bout** : le scénario 9 de la phase 14 (1 hôte + 2 clients + un muet exclu, empreintes identiques, départ d'un client, hôte perdu) passe à 1 hôte + 3 clients, une manche plus longue avec pastilles ramassées au vol et chocs ; jeux de tampons remesurés chez un client (point de vigilance ci-dessous). Le test réseau tourne en CI depuis la phase 11 ter (`ci.yml` n'est plus à toucher). | ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | test vert en CI |
```

par :

```text
| 15 | **Test réseau de bout en bout** : scénario 11 (les scénarios 9 et 10 restent) : 1 hôte + 3 clients jouent une manche entière de 90 s sur le Village au clavier, chacun selon un programme de commandes au hasard (graine) ; l'hôte orchestre les rencontres (pastilles ramassées au vol par chaque client, étoile, soucoupe, sa gerbe sur un client, la gerbe d'un client sur lui, un choc) ; un client arraché (KILL) est vu parti au bout du silence de session d'ENet (3,1 à 5,9 s mesurées, 10 s au plus), son lion disparaît chez tous, ses cellules restent ; même empreinte chez l'hôte et les deux clients restés (territoire, scores, suite des tampons, lions, apparitions, niveau, réactions de chaque joueur comptées sur chaque poste) ; jeux de tampons remesurés à 4 postes. Test réseau : 155 s (97 s pour le scénario 11), `ci.yml` inchangé. | ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | test vert 5 fois (bash 3.2 et 5), puis en CI |
```

1b. Remplacer :

```text
- **phase 15** (jeux de tampons, mesurés en phase 10, remesurés en phase 14) : chaque client génère
  ses jeux au premier usage (`Peinture.generer_tampons`, graine tirée de la clé : le même jeu
  quel que soit le moment). Scénario 9 de la phase 14 (3 postes au premier cran) : 3 jeux en cache
  chez chaque poste, frame la plus longue 10 à 16 ms pendant la passe, chez l'hôte comme chez un
  client (ligne `MESURE` de chaque poste) ; pas de pré-génération. À remesurer en phase 15 (1 hôte
  + 3 clients, crans et gerbes XXL) : pré-générer pendant l'intro (nuances des joueurs, 7 rayons,
  ×2, un jeu par frame) si un client montre des à-coups. Mémoire du cache plein : environ 14,5 Mo
  pour 6 joueurs ;
```

par :

```text
- (résolu en phase 15) jeux de tampons : chaque poste génère ses jeux au premier usage
  (`Peinture.generer_tampons`, graine tirée de la clé : le même jeu quel que soit le moment).
  Remesurés par le scénario 11 (1 hôte + 3 clients, crans de 1 à 6, gerbe XXL, manche entière) :
  9 à 15 jeux générés par poste, frame la plus longue qui en génère 14 à 25 ms chez l'hôte comme
  chez un client (lignes `MESURE`) ; les frames plus longues (jusqu'à 63 ms) ne génèrent rien (quatre
  processus Godot sur un Mac). Pas de pré-génération. Mémoire du cache plein : environ 14,5 Mo pour
  6 joueurs ;
- **phase 16** (temps de la CI, depuis la phase 15) : le test réseau prend 155 s, dont 97 s pour le
  scénario 11 (la manche entière), sous le `timeout 300` du pas « Test réseau » de `ci.yml` ; le test
  sous latence simulée de la phase 16 doit tenir dans ce qui reste (ou raccourcir `DUREE11` dans
  `tests/reseau/lancer.sh`, ou relever ce `timeout` dans `ci.yml`) ;
- **phase 17** (le peintre en bataille, vu en phase 15) : sur le Village, le peintre (421 px de haut,
  posé sur les toits) couvre toute la bande de peinture ; sans fuir, un joueur est étourdi sans
  relâche (le programme du scénario 11 sans fuite : 21 % de la ville peinte en 90 s à 4, contre 58 à
  66 % en fuyant, et encore 15 à 23 étourdissements par lion). À régler avec le rythme de la manche
  (délai propre à la bataille, taille ou fréquence du peintre en bataille) ;
- **phase 18** (résultats, vu en phase 15) : les statistiques de bataille (`Joueur.chocs`,
  `etourdissements_infliges`, `cellules_volees`) ne sont tenues que par l'hôte (règles) et ne sont
  pas répliquées : l'écran Résultats d'un client doit les recevoir de l'hôte (dans le message de fin
  de manche, par exemple) ;
- **prochaine phase qui touche `tests/reseau/lancer.sh`** (vu en phase 15) : le scénario 10 arrête
  ses postes par `tuer`, l'hôte n'efface donc pas `user://scores_reseau_Hote10.cfg` (fichier vide de
  test laissé dans les données utilisateur) ; l'effacer comme le fait l'hôte du scénario 11 pour le
  poste arraché ;
```

- [ ] **Step 2 : la spec**

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```text
  De bout en bout (phase 15) : 1 hôte + 3 clients, commandes scriptées ; vérifie à la fin l'empreinte identique des
  propriétaires de cellules chez tous, les scores identiques, le même nombre de tampons reçus, la
  déconnexion d'un client en cours de manche.
```

par :

```text
  De bout en bout (phase 15, scénario 11) : 1 hôte + 3 clients jouent une manche entière (90 s, le
  Village et son peintre) au clavier, chacun selon un programme de commandes au hasard tiré d'une
  graine ; l'hôte orchestre les rencontres que le hasard ne garantit pas, en ne décidant que des lieux
  (pastilles ramassées au vol par chaque client, étoile, soucoupe, sa gerbe sur un client, la gerbe
  d'un client sur lui, un choc) ; un client est arraché en pleine manche (processus tué, sans
  DISCONNECT) : l'hôte le voit parti au bout du silence de session d'ENet (10 s au plus), son lion
  disparaît chez tous, ses cellules restent ; à la fin, l'hôte et les deux clients restés ont la
  même empreinte : propriétaires des cellules, scores, nombre et suite des tampons reçus, lions,
  apparitions, niveau, et les réactions de chaque joueur (étourdissements, crans, gerbes XXL)
  comptées sur chaque poste (aucune perdue ni doublée). Les statistiques de bataille ne sont tenues
  que par l'hôte (phase 18 : les envoyer aux clients).
```

- [ ] **Step 3 : Commit**

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md
git commit -m "Feuille de route et spec : phase 15 faite (test réseau de bout en bout, scénario 11) ; jeux de tampons remesurés à 4 postes, sans pré-génération ; points de vigilance pour les phases 16 (temps de la CI), 17 (peintre en bataille), 18 (statistiques chez les clients) et le scénario 10 (scores de test laissés)

<ligne fournie par l'environnement>"
```

---

## Sortie de phase

- Les quatre suites vertes 5 fois de suite localement (test réseau sous bash 3.2 et 5), sans `SCRIPT ERROR` ni `SHADER ERROR`, puis le job CI vert sur la PR, pas « Test réseau » compris (relever sa durée : 155 s mesurées localement sous un `timeout 300`).
- Les preuves B1 à B4 ont donné les `❌` attendus ; `Scripts/Reseau.gd` n'a jamais été muté.
- `git diff main --stat` : `tests/reseau/joueur.gd`, `tests/reseau/lancer.sh`, la spec et la feuille de route ; `git diff main --stat -- Scripts Scenes project.godot .github` vide.
- Rappeler à l'utilisateur : le test réseau passe de 57 à 155 s (Écart 3 : `DUREE11=45` le ramènerait vers 110 s) ; le plan de la phase 15 bis (découpage de `Lion.gd`) s'exécute ensuite, sur cette base fusionnée, avec ce test pour filet.
