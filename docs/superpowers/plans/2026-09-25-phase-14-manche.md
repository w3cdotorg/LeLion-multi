# Phase 14 : la manche synchronisée (lions, ennemis et pastilles répliqués, commandes, tampons, territoire, réactions, barrière de chargement, départs), plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** une manche lancée au salon se joue vraiment à plusieurs : l'hôte simule tout (lions, ennemis, pastilles, étourdissements, territoire) ; chaque client envoie ses commandes et voit la même partie : lions, ennemis et pastilles apparus chez l'hôte et répliqués, peinture dessinée à l'identique, même territoire et mêmes scores, mêmes réactions (étourdissement, crans, gerbe XXL) ; l'intro attend que chaque poste ait chargé sa scène (un absent est exclu), un client qui part perd son lion (ses cellules restent), un hôte perdu ramène au titre après son message ; Échap ouvre un menu local sans pause ; la fenêtre passe en 16:9 hors du solo. Sortie : **◉ partie à 2 fenêtres** (captures des deux fenêtres, validées par l'utilisateur), les quatre suites vertes 5 fois (test réseau sous bash 3.2 et 5). **Le solo et la bataille locale restent identiques** (Écart 9 : tirages de la peinture).

**Architecture:** l'autorité est à l'hôte ; en solo et en bataille locale (`OfflineMultiplayerPeer`), ce poste est l'hôte et rien ne change de chemin. Quatre mécanismes :
- **apparitions et état continu** : un `MultiplayerSpawner` dans la scène de jeu (`Main/Apparitions`) fait apparaître chez chaque client les lions (apparition personnalisée, par l'index du joueur : sa `spawn_function` donne joueur, commandes et place avant l'ajout), et, d'eux-mêmes, les ennemis et pastilles que le Spawner de l'hôte ajoute à la scène ; chaque scène répliquée porte un `MultiplayerSynchronizer` (`Synchro`) : position, vitesse, orientation et vomi d'un lion ; position (et côté du peintre, inclinaison de la coccinelle, couleur d'une pastille) des autres. Sur un client, lions et ennemis ne sont que des répliques (`Lion._suivre_l_hote`, `Ennemi.est_replique`) ;
- **la manche** (`Scripts/Manche.gd`, nœud `Main/Manche`, au même chemin sur chaque poste) : barrière de chargement, commandes des clients (RPC `unreliable_ordered` numérotée, chaque tick physique), tampons de la ville de l'hôte (`Ville.tampon_peint`, regroupés par tick, canal fiable 1), cellules changées et scores toutes les 0,2 s, réactions des joueurs (RPC fiables qui appellent les méthodes du `Joueur` émettrices de signaux), départs ;
- **la peinture déterministe** (`Scripts/Peinture.gd`, logique pure) : jeux de tampons tirés de leur clé, variante et coulure tirées de la graine u16 du tampon, format réseau `(index u8, x i16, y i16, rayon u8, graine u16)` ; `Territoire` sait encoder et appliquer ses cellules changées ;
- **`Reseau`** : barrière (`signaler_scene_chargee`, `scenes_chargees`), relais du serveur coupé, départ propre et silences d'ENet réglés, `lancer_manche` qui revérifie ses fiches, version 0.14.

**Tech Stack:** Godot 4.7.2, GDScript typé, `SceneMultiplayer` (`@rpc`, `MultiplayerSpawner`, `MultiplayerSynchronizer` / `SceneReplicationConfig`), `ENetMultiplayerPeer` / `ENetConnection` / `ENetPacketPeer` (`peer_disconnect`, `set_timeout`), `RandomNumberGenerator`, `PackedByteArray.encode_*`, tests headless (`tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd`, `tests/reseau/lancer.sh` + `tests/reseau/joueur.gd`), captures rendues en `opengl3` par un script jetable du scratchpad.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1 unités, §3.2 flux d'une frame, §4 transport, commandes, pause, déconnexions, §4.1 prédiction : pas ici mais pas bloquée, §5 lion, §6 peinture, territoire et synchronisation, §7 viewport multi, §8 départ de manche, §9 erreurs, §10 tests) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 14 ; tous les points de vigilance « phase 14 », « phases 14 et 16 », « phases 14 et 19 », « phase 14 ou prochaine phase qui touche `Reseau.gd` », « prochaine phase qui touche `Territoire.gd` / `Regles.gd` », « avant la phase 16 ») · plan précédent : `docs/superpowers/plans/2026-09-25-phase-14bis-pastilles.md` (base `Pastille`, `Pastille._expirer`, sons de ramassage) · prérequis : **phase 14 bis fusionnée** ; nouvelle branche `phase-14-manche` depuis `main`.

## Écarts assumés

1. **Le plan est scindé** : la ligne 14 bis (pastilles) a son propre plan, exécuté avant celui-ci ; la phase 14 reste d'un seul tenant (le plafond de 5 fichiers est levé), 36 fichiers de code, de scène, de configuration, de traduction et de test (liste dans les Global Constraints), plus les `.uid` et les deux `.translation` régénérés.
2. **Réplication de l'état continu : `MultiplayerSynchronizer`**, pas des RPC d'état faites main. Mesuré en préparant ce plan (deux processus Godot sur localhost, 6 lions, position et vitesse en continu, orientation et vomi à chaque changement, `replication_interval` 0,012 s) : **14,7 Ko/s par client** (77 paquets/s, 192 octets par paquet, en-têtes ENet compris ; environ 17 Ko/s avec IP/UDP), soit environ 75 Ko/s d'envoi pour l'hôte à 6 joueurs (0,6 Mbit/s) : négligeable en Wi-Fi 5 GHz, et du même ordre qu'un format fait main (estimé à 9 Ko/s par client). Le moteur apporte l'état d'apparition (posé avant le `_ready` de la réplique : mesuré), la disparition répliquée et le regroupement par paquet ; l'étourdissement, les crans et la gerbe XXL ne passent pas par lui (ses écritures de champs bruts n'émettraient aucun signal) mais par les RPC de la manche. `replication_interval` 0,012 s (83 Hz au plus) : à 60 images par seconde, chaque image envoie (un intervalle de 1/60 en sauterait une sur deux, selon la gigue des images) ; à 144, une sur deux. Le numéro de la dernière commande traitée (spec §3.2) viendra avec la prédiction (phase 16).
3. **La barrière de chargement passe par `Reseau`** (présent sur chaque poste dès la connexion) : `signaler_scene_chargee`, RPC `_scene_chargee`, `scenes_chargees` ; la manche de l'hôte l'attend. Délai de 20 s **de jeu** (ticks physiques, pas l'horloge murale : un hôte figé ne doit exclure personne en reprenant, mesuré) ; un absent est déconnecté (proprement) et voit « L'hôte a quitté la partie » (sa propre raison : phase 18). Lions, Spawner et intro attendent la barrière ; rien n'est envoyé à un client avant qu'il soit prêt.
4. **Silences et départs d'ENet (M6)** : silence toléré `SILENCE_SESSION` (3 à 8 s) au salon et en manche, `SILENCE_CHARGEMENT` (20 à 30 s) du lancement à l'intro ; départ volontaire par un DISCONNECT fiable (`ENetPacketPeer.peer_disconnect`, renvoyé jusqu'à son accusé de réception, 1 s au plus, en arrière-plan), l'ancien `close()` ne l'envoyant qu'une fois sans garantie. `heberger()` ferme d'abord un départ en cours (son port serait encore pris). La robustesse du départ propre aux pertes ne se vérifie pas sur localhost (raisonnement : ENet renvoie une commande acquittée tant que `_process` sert la session).
5. **Relais du serveur coupé (M5)** : un client ne voit plus les autres clients parmi ses pairs ; le rôle `client --partir` du test réseau (scénario 1) lit donc l'autre client dans la table du salon (Task 4).
6. **Menu local en réseau** : même scène `PauseMenu`, sans mettre l'arbre en pause, titre « La partie continue », bouton « Quitter la partie » (deux clés de traduction) ; tant qu'il est ouvert, les commandes de ce poste valent le repos (`Commandes.suspendues`), sinon naviguer dans le menu ferait avancer et vomir le lion.
7. **Hôte perdu en manche** : « L'hôte a quitté la partie » sur la partie figée, 2,5 s, puis le titre (spec §9). Le moteur fait disparaître les nœuds répliqués d'un client qui perd l'hôte : le message s'affiche sur une ville sans lions (capture ◉).
8. **Territoire** : l'hôte diffuse les cellules changées et les scores ; le client applique les cellules et **vérifie** qu'il a les mêmes scores (`push_error` sinon), sans les adopter : une seule source de vérité. Un joueur parti garde ses cellules telles quelles (aucune opération de `Territoire` : spec §4).
9. **Tirages de la peinture** : les jeux de tampons sont tirés de leur clé et chaque tampon de sa graine, sans consommer le hasard global ; la génération des jeux en consommait des milliers de tirages. En solo, la suite des tirages du Spawner et des ennemis change donc (distribution inchangée) ; le plafond des coulures compte en tampons (40 parmi les 120 derniers) au lieu des coulures en cours (40), pour que chaque poste lance les mêmes. Mesures de `tests/bataille_test.gd` toujours dans leurs cibles (vérifié : rapports de 0,79 à 1,13, vols de 49 % au moins).
10. **L'image de la ville n'est pas comparée entre postes** : les mêmes tampons s'y dessinent pixel pour pixel (smoke test), mais une coulure qui descend encore quand un tampon la recouvre passe dessus ou dessous selon le rythme d'affichage de chaque poste. Le test réseau compare la suite des tampons (empreinte des lots) et le territoire.
11. **Pas de fin de manche en réseau** (chrono : phase 17) : le test réseau fige la manche de l'hôte par `GameState.terminer_partie` pour prendre des empreintes stables ; la manche continue de diffuser l'arbre en pause (`PROCESS_MODE_ALWAYS`).
12. **`Lion.gd` n'est pas découpé ici** (point « avant la phase 16 ») : les ajouts de la phase 14 au lion sont petits et isolés (la réplique, `vomi_de_l_hote`, le setter d'orientation), alors que le découpage réécrirait les fonctions que le smoke test et `tests/bataille_test.gd` lisent par dizaines de champs privés, et noierait la revue du réseau ; il se fait après la phase 15, avec le filet du test réseau de bout en bout, avant la 16 (Task 10).
13. **Sons des clients réaffectés à la phase 17 bis** : l'annonce du peintre ne s'entend que chez l'hôte ; la boucle de vomi reste partagée par tous les lions (défaut de la phase 8 bis). **Jeux de tampons** : mesurés chez un client (3 jeux, frame la plus longue 10 à 16 ms, comme chez l'hôte) : pas de pré-génération, remesure en phase 15.
14. **`config/version` passe à « 0.14 »** : la phase ajoute des RPC (M7).
15. **Pas de nettoyage préalable (« Step 0 »)** : `Scripts/Reseau.gd` (670 lignes) et `Scripts/Lion.gd` (508) reçoivent des ajouts, pas une refonte ; les tests reçoivent des sections. Lire ces fichiers par morceaux (`offset` / `limit`).
16. **Les captures ◉ viennent d'un script jetable du scratchpad** (Task 9) ; les verser dans `tests/screenshots.gd` est réaffecté à la phase 19.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), commandes depuis `~/Sites/LeLion-multi`, branche `phase-14-manche`.
- Fichiers de la phase : ➕ `Scripts/Peinture.gd`, ➕ `Scripts/Manche.gd` (+ `.uid` générés) ; ✏️ `Scripts/Territoire.gd`, `Scripts/Ville.gd`, `Scripts/GerbeTraceuse.gd`, `Scripts/Joueur.gd`, `Scripts/GameState.gd`, `Scripts/Regles.gd`, `Scripts/Titre.gd`, `Scripts/Salon.gd`, `Scripts/EcranReseau.gd`, `Scripts/Reseau.gd`, `project.godot`, `Scripts/Ennemi.gd`, `Scripts/Soucoupe.gd`, `Scripts/Coccinelle.gd`, `Scripts/Boss.gd`, `Scripts/Spawner.gd`, `Scenes/Soucoupe.tscn`, `Scenes/Coccinelle.tscn`, `Scenes/Boss.tscn`, `Scenes/ColorPickup.tscn`, `Scenes/BonusPickup.tscn`, `Scenes/CoeurPickup.tscn`, `Scripts/Lion.gd`, `Scenes/Lion.tscn`, `Scripts/Commandes.gd`, `Scripts/Main.gd`, `Scenes/Main.tscn`, `Scripts/Intro.gd`, `Scripts/PauseMenu.gd`, `Assets/Traductions/traductions.csv` (+ les deux `.translation` régénérés), `tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/reseau/joueur.gd`, `tests/reseau/lancer.sh` ; la spec et la feuille de route (Task 10). **`Scripts/Pastille.gd`, les trois pastilles, `Scripts/Audio.gd`, `Scripts/Decouverte.gd`, `Scripts/HUD.gd`, `tests/bataille_test.gd` et `.github/workflows/ci.yml` ne changent pas** (le pas « Test réseau » de la CI lance déjà `tests/reseau/lancer.sh`, sous `timeout 300` : 53 s mesurées localement).
- **`Scripts/Reseau.gd` ne reçoit que les blocs de la Task 4, jamais de mutation temporaire** (l'environnement l'a déjà refusé) : ses tests discriminent par leur échec avant l'implémentation (Task 4, Step 2, mesuré) et par des mutations du harnais (Task 8). Les autres mutations de preuve ne touchent que les fichiers neufs ou modifiés de la phase, déjà commités, et sont annulées par `git checkout -- <fichier>` : **jamais commitées**.
- Identifiants, commentaires et messages de test en français, docstrings `##`, tabulations. Tout texte visible passe par `traductions.csv` (FR + EN).
- **Aucune séquence d'échappement `\u…` n'est tapée dans un fichier** (l'outillage peut la changer en caractère invisible réel). Vérifier après chaque écriture : `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' <fichiers>` ne sort rien.
- RPC : celles de l'hôte en mode `"authority"`, leurs arguments relus (type, plage) ; celles des clients vérifient l'émetteur (`multiplayer.get_remote_sender_id()`) et leurs arguments. Aucune RPC de la manche n'est envoyée à un client dont la scène n'est pas chargée (`Manche._envoyer`, `_prets`), ni à un client déjà déconnecté.
- Jamais le port 7777 ni le 7778 d'une vraie partie dans un test : unitaires 17788 (hôte) et 17795 (client), smoke test 17798 (hôte) et 7779 (clients jamais connectés, comme avant), test réseau `port_de_base + 9` / `port_de_base + 1009` (scénario 9), captures ◉ 17990 / 18990.
- Un test `--script` est compilé **avant** les autoloads : il récupère `Reseau`, `GameState`, `Scores` par `root.get_node(…)` et ne nomme ni eux, ni `Lion`, `Ennemi`, `Pastille`, la ville, la manche ; il peut nommer `Peinture`, `Territoire`, `Joueur`, `Commandes`, `Regles`, `ReglesBataille`, `EtatPartie`. Le script de la manche se lit par `load("res://Scripts/Manche.gd")`.
- **Toujours lancer un test Godot avec `timeout`** et chercher les erreurs :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; O=""; timeout -k 5 300 godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd; O=""`, `T=tests/bataille_test.gd; O="--fixed-fps 60"` ; le test réseau : `timeout -k 5 300 bash tests/reseau/lancer.sh`). Une `SCRIPT ERROR` ne change pas le code de sortie ; un script qui ne compile pas sort aussi en `code 0`, sans ligne `== n échec(s) ==` : c'est cette absence et la `SCRIPT ERROR` qui font l'échec. Après la création d'un script à `class_name` ou la modification du CSV : `godot --headless --import .` avant les tests. Bruit connu : « ObjectDB instances were leaked », « resources still in use at exit » ; unitaires : `ERROR: Territoire.tamponner : index de joueur hors plage` (×2), `ERROR: Couldn't create an ENet host.`, `ERROR: une bataille se joue de 2 à 6 joueurs : 9 demandés, 6 retenus` et, nouveau, `ERROR: Reseau.lancer_manche : fiches de la manche incohérentes, lancement refusé` (voulus) ; smoke test : `ERROR: Couldn't create an ENet host.`, deux `ERROR: The local port number must be between 0 and 65535 (inclusive).` et, nouveau, `WARNING: Manche : le joueur 7 n'a pas chargé sa scène à temps, exclu` (voulus) ; test réseau : `WARNING: Manche : le joueur … n'a pas chargé sa scène à temps, exclu` dans le journal de `hote9` (voulu). Si un autre test réseau tourne sur la même machine, `bash tests/reseau/lancer.sh 27777` décale tous ses ports.
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`**.
- Les quatre suites se valident sur **5 passages consécutifs verts**, le test réseau sous bash 3.2 (`/bin/bash`, macOS) et bash 5.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Un poste lent à charger (ou un hôte figé par le chargement, la compilation des shaders sous Windows)** : la manche part sans lui, ou il se croit abandonné, ou il est exclu à tort parce que l'hôte relit l'horloge murale en reprenant. → scénario 9 : hôte figé 6,5 s, « personne ne s'est cru abandonné pendant le chargement », « les clients chargés sont prêts, le muet est exclu » (Task 8) ; « (charge) … attend la barrière », « (absent) délai passé : Bob est exclu » (Task 7) ; mutations N1, N2.
2. **Une peinture qui diverge** : un client qui peint aussi ses propres tampons (traceuse d'une réplique), des tirages différents d'un poste à l'autre, un territoire qui dérive. → « la traceuse d'un lion de client … ne peint pas », « pixel pour pixel … coulures comprises », « les mêmes tampons lancent les mêmes coulures » (Task 2) ; « un jeu de tampons est le même d'un poste à l'autre » (Task 1) ; scénario 9, la même empreinte (territoire, scores, suite des tampons) chez l'hôte et chez Anna (Task 8) ; mutations U1, V1 à V4.
3. **Un lion fantôme ou emballé** : le lion d'un client parti reste, ou court et vomit avec sa dernière commande (client planté, paquets perdus), ou une vieille commande arrivée en retard le fait repartir. → « sans commande de Bob depuis 500 ms, son lion revient au repos », « une commande plus ancienne ou déjà vue est ignorée », « un joueur parti en pleine manche perd son lion, ses cellules restent » (Task 7) ; scénario 9, départ de Bruno (Task 8) ; mutations M1, M5.
4. **Le menu local** qui met tout le monde en pause, ou laisse le joueur piloter son lion en naviguant dans le menu (flèches, Entrée = vomir). → « en réseau, Échap ouvre un menu local : la partie continue, les commandes de ce poste sont suspendues » (Task 7), « des commandes suspendues … valent le repos » (Task 6), scénario 9 (Bruno) ; mutations M3, C1.
5. **Un client bloqué par un hôte perdu** dans une partie hors réseau où ses répliques se mettraient à simuler (il est redevenu « hôte » de lui-même). → « l'hôte perdu : « L'hôte a quitté la partie », la partie se fige » (Task 7) ; scénario 9, Anna voit le message puis le titre (Task 8).

---

### Task 0 : vérifications

Ce plan est commité par le commit de planification de la phase 14 : ne pas le recommiter, **ne jamais le modifier**. Vérifier que la phase 14 bis est fusionnée : `grep -n "class_name Pastille" Scripts/Pastille.gd` et `grep -n "func _jouer_ramassage" Scripts/Audio.gd` trouvent chacun une ligne, `grep -n 'config/version="0.13"' project.godot` aussi. Sinon, s'arrêter et le signaler. Les blocs « Remplacer » citent le code et les documents tels que les phases 13 et 14 bis les laissent (vérifié en appliquant ce plan, bloc par bloc, à une copie de `main` + phase 14 bis) : si une ancre a bougé, l'adapter au texte réel sans changer le remplacement, et le noter dans le rapport de la tâche.

Puis : `git switch -c phase-14-manche`.

---

### Task 1 : la peinture déterministe et le territoire en réseau (logique pure)

**Files:**
- Create: `Scripts/Peinture.gd` (+ `.uid`)
- Modify: `Scripts/Territoire.gd` (docstring, `CHARGE_MAX`, `reinitialiser`, trois fonctions à la fin)
- Test: `tests/unitaires.gd` (`_run`, deux fonctions à la fin)

**Interfaces:**
- Consumes : `EtatPartie.NB_JOUEURS_MAX` ; `Territoire.tamponner`, `extraire_changements`, `proprietaire_compte`, `cellules_de` (phase 9).
- Produces (Tasks 2, 7, 8) : `class_name Peinture` : `const NB_TAMPONS := 4`, `CHANCE_COULURE := 0.3`, `OCTETS_PAR_TAMPON := 8`, `GRAINE_MAX := 0xFFFF`, `RAYON_MAX := 255` ; `static func cle_tampons(rayon: int, couleurs: Array[Color]) -> String` ; `static func generer_tampons(rayon: int, couleurs: Array[Color]) -> Array[Image]` ; `static func tirage(graine: int, rayon: int, nb_couleurs: int) -> Dictionary` (`variante`, `coulure`, `dx`, `dy`, `longueur`, `couleur`) ; `static func encoder_tampons(tampons: Array[Dictionary]) -> PackedByteArray`, `static func decoder_tampons(octets: Variant) -> Array[Dictionary]` (tampon : `{"index", "x", "y", "rayon", "graine"}`). `Territoire` : `const OCTETS_PAR_CHANGEMENT := 3`, `func encoder_changements(cellules: PackedInt32Array) -> PackedByteArray`, `func appliquer_changements(octets: Variant) -> bool`, `func scores() -> PackedInt32Array` (index 0 : personne).

- [ ] **Step 1 : le test**

Dans `tests/unitaires.gd` :

1a. Remplacer :

```gdscript
	_tester_salon()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_salon()
	_tester_peinture()
	_tester_territoire_reseau()
	print("== %d échec(s) ==" % _echecs)
```

1b. Remplacer :

```gdscript
		"quitter() oublie la table du salon")
	reseau.pseudo = ""

```

par :

```gdscript
		"quitter() oublie la table du salon")
	reseau.pseudo = ""



## Phase 14 : la peinture identique sur chaque poste (jeux de tampons tirés de leur clé, tirage d'un
## tampon par sa graine) et le format réseau des tampons.
func _tester_peinture() -> void:
	print("-- Peinture (jeux de tampons, tirage, format réseau des tampons)")
	var nuances: Array[Color] = [Color(0.5, 0.1, 0.0), Color(0.81, 0.14, 0.01), Color(0.9, 0.5, 0.4)]
	seed(1)
	var jeu_a := Peinture.generer_tampons(21, nuances)
	seed(2)
	randi()
	var jeu_b := Peinture.generer_tampons(21, nuances)
	var memes := jeu_a.size() == Peinture.NB_TAMPONS and jeu_b.size() == Peinture.NB_TAMPONS
	for i in range(mini(jeu_a.size(), jeu_b.size())):
		memes = memes and jeu_a[i].get_data() == jeu_b[i].get_data()
	_check(memes and jeu_a[0].get_width() == 43, "un jeu de tampons est le même d'un poste à l'autre, quel que soit le hasard global (graine tirée de sa clé)")
	_check(jeu_a[0].get_data() != jeu_a[1].get_data(), "les variantes d'un même jeu diffèrent")
	var autres: Array[Color] = [Color(0.1, 0.2, 0.6), Color(0.24, 0.38, 1.0), Color(0.5, 0.6, 1.0)]
	_check(Peinture.generer_tampons(21, autres)[0].get_data() != jeu_a[0].get_data(), "un autre jeu de couleurs donne d'autres tampons")
	seed(3)
	var etat_global := randi()
	seed(3)
	Peinture.generer_tampons(16, nuances)
	Peinture.tirage(12345, 16, 3)
	_check(randi() == etat_global, "générer un jeu et tirer un tampon ne consomment pas le hasard global (Spawner, ennemis)")
	_check(Peinture.tirage(40000, 30, 3) == Peinture.tirage(40000, 30, 3) and Peinture.tirage(40000, 30, 3) != Peinture.tirage(40001, 30, 3),
		"le tirage d'un tampon ne dépend que de sa graine (le même sur chaque poste)")
	var coulures := 0
	var bornes := true
	for graine in range(2000):
		var t := Peinture.tirage(graine, 30, 3)
		coulures += 1 if t.coulure else 0
		bornes = bornes and t.variante >= 0 and t.variante < Peinture.NB_TAMPONS and t.dx >= -30 and t.dx <= 30 \
			and t.dy >= 0 and t.dy <= 30 and t.longueur >= 14 and t.longueur <= 44 and t.couleur >= 0 and t.couleur < 3
	_check(bornes and absf(coulures / 2000.0 - Peinture.CHANCE_COULURE) < 0.04,
		"tirages dans leurs bornes, une coulure pour %.0f %% des tampons (%d sur 2000)" % [Peinture.CHANCE_COULURE * 100.0, coulures])
	var lot: Array[Dictionary] = [
		{"index": 0, "x": 1000, "y": 150, "rayon": 16, "graine": 0},
		{"index": 5, "x": -40, "y": -12, "rayon": 92, "graine": Peinture.GRAINE_MAX},
		{"index": 3, "x": 2010, "y": 330, "rayon": 46, "graine": 777},
	]
	var octets := Peinture.encoder_tampons(lot)
	_check(octets.size() == 3 * Peinture.OCTETS_PAR_TAMPON and Peinture.decoder_tampons(octets) == lot,
		"un lot de tampons fait 8 octets par tampon et se relit à l'identique, dans l'ordre, centres négatifs compris (i16)")
	var hors_plage: Array[Dictionary] = [{"index": 1, "x": 40000, "y": -40000, "rayon": 300, "graine": 70000}]
	_check(Peinture.decoder_tampons(Peinture.encoder_tampons(hors_plage)) == [{"index": 1, "x": 32767, "y": -32768, "rayon": 255, "graine": 65535}],
		"des valeurs hors de leur plage sont ramenées dans leurs bornes, jamais bouclées")
	var tronque := octets.slice(0, 7)
	var mauvais_joueur := octets.duplicate()
	mauvais_joueur.encode_u8(Peinture.OCTETS_PAR_TAMPON, EtatPartie.NB_JOUEURS_MAX)
	_check(Peinture.decoder_tampons(tronque).is_empty() and Peinture.decoder_tampons(mauvais_joueur).is_empty()
		and Peinture.decoder_tampons("tampons").is_empty() and Peinture.decoder_tampons(PackedByteArray()).is_empty(),
		"un lot tronqué, un index de joueur hors plage ou autre chose qu'un lot d'octets est ignoré en entier")


## Phase 14 : le territoire d'un client suit celui de l'hôte par la liste des cellules changées.
func _tester_territoire_reseau() -> void:
	print("-- Territoire en réseau (cellules changées, scores)")
	var taille := Vector2i(20, 6)
	var peignables := PackedByteArray()
	peignables.resize(taille.x * taille.y)
	peignables.fill(1)
	peignables[0] = 0
	var hote := Territoire.new(taille, peignables, 8)
	var client := Territoire.new(taille, peignables, 8)
	for i in range(3):
		hote.tamponner(0, Vector2i(40, 24), 20)
		hote.tamponner(1, Vector2i(100, 24), 20)
	var premier := hote.extraire_changements()
	_check(client.appliquer_changements(hote.encoder_changements(premier)) and premier.size() > 0,
		"(pré-condition) des cellules changées chez l'hôte, appliquées chez le client")
	for i in range(6):
		hote.tamponner(1, Vector2i(56, 24), 20)  # le joueur 1 vole une partie des cellules du joueur 0
	hote.tamponner(2, Vector2i(140, 30), 12)  # une passe qui ne suffit pas à compter
	var second := hote.extraire_changements()
	var octets := hote.encoder_changements(second)
	_check(octets.size() == second.size() * Territoire.OCTETS_PAR_CHANGEMENT and client.appliquer_changements(octets),
		"3 octets par cellule changée (index u16, propriétaire compté u8)")
	var memes := true
	for i in range(peignables.size()):
		memes = memes and client.proprietaire_compte(i) == hote.proprietaire_compte(i)
	_check(memes and client.scores() == hote.scores() and client.cellules_de(0) == hote.cellules_de(0)
		and client.cellules_de(1) == hote.cellules_de(1) and hote.cellules_de(0) > 0 and hote.cellules_de(1) > 0,
		"le client a le même propriétaire compté par cellule et les mêmes scores que l'hôte (%s)" % [client.scores()])
	var avant := client.scores()
	var mauvaise_cellule := PackedByteArray([0, 0, 1])  # la cellule 0 n'est pas peignable
	var hors_grille := PackedByteArray([0xFF, 0xFF, 1])
	var mauvais_joueur := PackedByteArray([5, 0, EtatPartie.NB_JOUEURS_MAX + 1])
	_check(not client.appliquer_changements(mauvaise_cellule) and not client.appliquer_changements(hors_grille)
		and not client.appliquer_changements(mauvais_joueur) and not client.appliquer_changements(PackedByteArray([1, 0]))
		and not client.appliquer_changements(octets.slice(0, 3) + PackedByteArray([0xFF, 0xFF, 1])) and client.scores() == avant,
		"un lot mal formé (cellule non peignable ou hors grille, joueur hors plage, taille tronquée) est refusé sans rien changer")
	var vide := client.extraire_changements()
	_check(vide.is_empty(), "appliquer les changements de l'hôte n'en crée pas d'autres chez le client")

```

- [ ] **Step 2 : le test échoue**

Run : la commande des Global Constraints avec `T=tests/unitaires.gd`.
Expected (mesuré) : `code 0`, sans ligne `== n échec(s) ==`, et des `SCRIPT ERROR: Parse Error: Identifier "Peinture" not declared in the current scope.` : le script ne compile pas.

- [ ] **Step 3 : `Peinture` et `Territoire`**

Créer `Scripts/Peinture.gd` :

```gdscript
class_name Peinture
extends RefCounted
## La peinture d'un tampon en logique pure (ne nomme aucun autoload : testable dans un test
## `--script`) : les jeux de tampons, le tirage de chaque tampon et le format réseau des tampons que
## l'hôte diffuse (spec §6). Chaque poste doit dessiner exactement le même tampon :
## - un jeu de tampons (NB_TAMPONS images d'un rayon et d'un jeu de couleurs) est tiré d'un
##   générateur dont la graine est dérivée de sa clé (`cle_tampons(...).hash()`) : chaque poste qui
##   le génère, au premier usage, à n'importe quel moment, obtient les mêmes images ;
## - la variante et la coulure d'un tampon viennent de sa graine u16 (`tirage`), tirée par l'hôte
##   (`randi()`) et diffusée avec lui.
## Ni l'un ni l'autre ne consomme le hasard global (`randi`, `randf`), dont dépendent le Spawner et
## les ennemis.

## Variantes d'un jeu de tampons.
const NB_TAMPONS := 4
## Densité des pixels d'un tampon, au centre (plus épars vers le bord).
const DENSITE_TAMPON := 0.5
## Probabilité qu'un tampon lâche une coulure.
const CHANCE_COULURE := 0.3
## Longueur d'une coulure sous le bas du tampon, en pixels (min, max).
const LONGUEUR_COULURE := Vector2i(14, 44)
## Format réseau d'un tampon : index du joueur u8, x i16, y i16 (le centre, en pixels de la ville :
## négatif quand le tampon déborde en haut ou à gauche, ce qu'un u16 ferait boucler vers ~65 500),
## rayon u8, graine u16.
const OCTETS_PAR_TAMPON := 8
const RAYON_MAX := 255
const GRAINE_MAX := 0xFFFF


## Le rayon puis chaque couleur en RGBA 8 bits, dans l'ordre : deux jeux qui ne diffèrent que par
## une couleur ont des clés différentes (le même jeu dans un autre ordre aussi : une entrée de cache
## redondante, pas un mauvais rendu).
static func cle_tampons(rayon: int, couleurs: Array[Color]) -> String:
	var cle := str(rayon)
	for c in couleurs:
		cle += ":%08x" % c.to_rgba32()
	return cle


## Les NB_TAMPONS tampons de ce rayon et de ce jeu de couleurs : denses au centre, épars sur les
## bords, chaque pixel d'une des couleurs. Toujours les mêmes images pour la même clé.
static func generer_tampons(rayon: int, couleurs: Array[Color]) -> Array[Image]:
	var rng := RandomNumberGenerator.new()
	rng.seed = cle_tampons(rayon, couleurs).hash()
	var tampons: Array[Image] = []
	var taille := rayon * 2 + 1
	for t in range(NB_TAMPONS):
		var tampon := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
		tampon.fill(Color(0, 0, 0, 0))
		for y in range(taille):
			for x in range(taille):
				var dx := x - rayon
				var dy := y - rayon
				var d := sqrt(dx * dx + dy * dy) / rayon
				if d > 1.0:
					continue
				# Plus dense au centre, éparse sur les bords.
				if rng.randf() < DENSITE_TAMPON * (1.3 - d):
					var c := couleurs[rng.randi() % couleurs.size()]
					c.a = 1.0
					tampon.set_pixel(x, y, c)
		tampons.append(tampon)
	return tampons


## Le tirage d'un tampon de graine `graine` (0 à GRAINE_MAX), de rayon `rayon`, peint dans
## `nb_couleurs` couleurs : `{"variante": int, "coulure": bool, "dx": int, "dy": int,
## "longueur": int, "couleur": int}` (la coulure part de (dx, dy) autour du centre, dx dans
## [-rayon, rayon], dy dans [0, rayon], et descend de `longueur` px sous le bas du tampon, dans la
## couleur d'index `couleur`). Le même sur chaque poste pour la même graine.
static func tirage(graine: int, rayon: int, nb_couleurs: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	return {
		"variante": rng.randi() % NB_TAMPONS,
		"coulure": rng.randf() < CHANCE_COULURE,
		"dx": rng.randi_range(-rayon, rayon),
		"dy": rng.randi_range(0, rayon),
		"longueur": rng.randi_range(LONGUEUR_COULURE.x, LONGUEUR_COULURE.y),
		"couleur": rng.randi() % maxi(nb_couleurs, 1),
	}


## Les tampons `{"index", "x", "y", "rayon", "graine"}` d'une frame de l'hôte, dans l'ordre, au format
## réseau (OCTETS_PAR_TAMPON octets chacun). Les valeurs sont ramenées dans leur plage (x et y en i16,
## rayon en u8, graine en u16) : la ville n'en produit jamais d'autres.
static func encoder_tampons(tampons: Array[Dictionary]) -> PackedByteArray:
	var octets := PackedByteArray()
	octets.resize(tampons.size() * OCTETS_PAR_TAMPON)
	for i in range(tampons.size()):
		var t: Dictionary = tampons[i]
		var o := i * OCTETS_PAR_TAMPON
		octets.encode_u8(o, clampi(t.index, 0, 255))
		octets.encode_s16(o + 1, clampi(t.x, -32768, 32767))
		octets.encode_s16(o + 3, clampi(t.y, -32768, 32767))
		octets.encode_u8(o + 5, clampi(t.rayon, 0, RAYON_MAX))
		octets.encode_u16(o + 6, clampi(t.graine, 0, GRAINE_MAX))
	return octets


## Les tampons reçus de l'hôte, dans l'ordre ; un tableau vide pour tout ce qui n'est pas un lot
## bien formé (pas un `PackedByteArray`, taille qui n'est pas un multiple de OCTETS_PAR_TAMPON, index
## de joueur hors de [0, `EtatPartie.NB_JOUEURS_MAX`[) : un lot douteux est ignoré en entier.
static func decoder_tampons(octets: Variant) -> Array[Dictionary]:
	var tampons: Array[Dictionary] = []
	if not (octets is PackedByteArray) or octets.size() % OCTETS_PAR_TAMPON != 0:
		return tampons
	for o in range(0, octets.size(), OCTETS_PAR_TAMPON):
		var index: int = octets.decode_u8(o)
		if index >= EtatPartie.NB_JOUEURS_MAX:
			return [] as Array[Dictionary]
		tampons.append({"index": index, "x": octets.decode_s16(o + 1), "y": octets.decode_s16(o + 3),
			"rayon": octets.decode_u8(o + 5), "graine": octets.decode_u16(o + 6)})
	return tampons
```

Dans `Scripts/Territoire.gd` :

3a. Remplacer :

```gdscript
## entier et déterministe (les mêmes tampons dans le même ordre donnent le même territoire), fait
## par l'hôte seulement. Logique pure : ne nomme aucun autoload, ce qui permet de la tester dans
## un test `--script`.
##
```

par :

```gdscript
## entier et déterministe (les mêmes tampons dans le même ordre donnent le même territoire), fait
## par l'hôte seulement ; un client ne tamponne jamais : il reçoit de l'hôte les cellules dont le
## propriétaire compté a changé (`encoder_changements` chez l'hôte, `appliquer_changements` chez
## lui, spec §6), d'où les mêmes scores. Logique pure : ne nomme aucun autoload, ce qui permet de la
## tester dans un test `--script`.
##
```

3b. Remplacer :

```gdscript
## le score ne bougeait pas). Un vol coûte maintenant 6 tampons (3 pour vider, 3 pour prendre)
## contre 3 en terrain vierge, et une seule passe pleine vitesse vole le centre de son tracé. La
## phase 10 rerègle ces constantes sur une vraie manche.
const CHARGE_MAX := SEUIL_POSSESSION
const PERSONNE := -1

var taille_grille: Vector2i
```

par :

```gdscript
## le score ne bougeait pas). Un vol coûte maintenant 6 tampons (3 pour vider, 3 pour prendre)
## contre 3 en terrain vierge, et une seule passe pleine vitesse vole le centre de son tracé. La
## phase 10 ter les a gardées (4, 12, 12) sur une vraie manche et réglé à la place l'empreinte du
## tampon dans la ville (`Ville.EMPREINTE_TERRITOIRE`, spec §6, cibles vérifiées par
## `tests/bataille_test.gd`).
const CHARGE_MAX := SEUIL_POSSESSION
const PERSONNE := -1
## Format réseau d'une cellule changée (spec §6) : son index u16, puis son propriétaire compté u8
## (0 = personne, 1 à 6 = joueurs 0 à 5).
const OCTETS_PAR_CHANGEMENT := 3
## Cellules au plus d'une grille dont les changements passent par le réseau (index u16).
const CELLULES_MAX := 65536

var taille_grille: Vector2i
```

3c. Remplacer :

```gdscript
## Toute la ville redevient vierge (nouvelle manche). Les changements pas encore lus par
## `extraire_changements` sont alors perdus : la phase 14 doit les vider avant d'appeler
## `reinitialiser`, ou envoyer « nouvelle manche » comme son propre message.
func reinitialiser() -> void:
```

par :

```gdscript
## Toute la ville redevient vierge (nouvelle manche). Les changements pas encore lus par
## `extraire_changements` sont alors perdus : la manche qui les diffuse (phase 14) doit les vider
## avant d'appeler `reinitialiser`, ou envoyer « nouvelle manche » comme son propre message (phase
## 18, Revanche).
func reinitialiser() -> void:
```

3d. Remplacer :

```gdscript
	return liste

```

par :

```gdscript
	return liste


## Les cellules `cellules` (de `extraire_changements`) au format réseau : pour chacune, son index u16
## et son propriétaire compté u8 d'à présent (OCTETS_PAR_CHANGEMENT octets par cellule).
func encoder_changements(cellules: PackedInt32Array) -> PackedByteArray:
	assert(_peignables.size() <= CELLULES_MAX, "une grille de plus de 65 536 cellules ne tient pas en u16")
	var octets := PackedByteArray()
	octets.resize(cellules.size() * OCTETS_PAR_CHANGEMENT)
	for k in range(cellules.size()):
		var i := cellules[k]
		octets.encode_u16(k * OCTETS_PAR_CHANGEMENT, i)
		octets.encode_u8(k * OCTETS_PAR_CHANGEMENT + 2, proprietaire_compte(i) + 1)
	return octets


## Chez un client : les changements reçus de l'hôte (`encoder_changements`), appliqués dans l'ordre.
## Le propriétaire compté de chaque cellule est posé tel quel (charge SEUIL_POSSESSION pour un
## joueur, nulle pour personne) : un client ne calcule aucune charge, il ne rejoue jamais
## `tamponner`. Renvoie faux sans rien changer pour un lot mal formé (pas un `PackedByteArray`,
## taille qui n'est pas un multiple de OCTETS_PAR_CHANGEMENT, cellule hors de la grille ou non
## peignable, propriétaire hors de [0, NB_JOUEURS_MAX]).
func appliquer_changements(octets: Variant) -> bool:
	if not (octets is PackedByteArray) or octets.size() % OCTETS_PAR_CHANGEMENT != 0:
		return false
	for o in range(0, octets.size(), OCTETS_PAR_CHANGEMENT):
		var i: int = octets.decode_u16(o)
		if i >= _peignables.size() or _peignables[i] == 0 or octets.decode_u8(o + 2) > EtatPartie.NB_JOUEURS_MAX:
			return false
	for o in range(0, octets.size(), OCTETS_PAR_CHANGEMENT):
		var i: int = octets.decode_u16(o)
		var compte: int = octets.decode_u8(o + 2)
		var avant := _proprietaires[i] if _charges[i] >= SEUIL_POSSESSION else 0
		_proprietaires[i] = compte
		_charges[i] = SEUIL_POSSESSION if compte != 0 else 0
		_cellules[avant] -= 1
		_cellules[compte] += 1
		if compte != 0:
			_dernier_compte[i] = compte
	return true


## Les scores de toute la grille : à l'index 0, les cellules peignables qui ne comptent pour
## personne, puis celles de chaque joueur (index du joueur + 1). L'hôte les diffuse avec les
## changements : un client qui a appliqué les mêmes changements a les mêmes.
func scores() -> PackedInt32Array:
	return _cellules.duplicate()

```

Puis `export PATH="/opt/homebrew/bin:$PATH"; timeout -k 5 120 godot --headless --import . > "$TMPDIR/i.log" 2>&1; grep -E "SCRIPT ERROR|Parse Error" "$TMPDIR/i.log"` ne sort rien (la classe `Peinture` enregistrée).

- [ ] **Step 4 : le test passe**

Run : la commande des Global Constraints avec `T=tests/unitaires.gd`.
Expected (mesuré) : `code 0`, `== 0 échec(s) ==` ; 9 lignes ✅ sous « -- Peinture (jeux de tampons, tirage, format réseau des tampons) », dont « un jeu de tampons est le même d'un poste à l'autre, quel que soit le hasard global (graine tirée de sa clé) » et « une coulure pour 30 % des tampons (… sur 2000) » ; 5 sous « -- Territoire en réseau (cellules changées, scores) », dont « le client a le même propriétaire compté par cellule et les mêmes scores que l'hôte ([79, 8, 32, 0, 0, 0, 0]) ».

- [ ] **Step 5 : Commit, puis le test discrimine**

```bash
git add Scripts/Peinture.gd Scripts/Peinture.gd.uid Scripts/Territoire.gd tests/unitaires.gd
git commit -m "Peinture : jeux de tampons tirés de leur clé, tirage d'un tampon par sa graine u16, format réseau des tampons (i16 pour les centres) ; Territoire : cellules changées au format réseau, appliquées par un client, scores ; tests unitaires

<ligne fournie par l'environnement>"
```

Puis chaque mutation seule, `T=tests/unitaires.gd`, et **`git checkout -- Scripts/`** avant la suivante (mesuré en préparant le plan) :
- U1 : dans `Peinture.generer_tampons`, `rng.seed = cle_tampons(rayon, couleurs).hash()` → `rng.randomize()` ⇒ `❌ un jeu de tampons est le même d'un poste à l'autre, quel que soit le hasard global (graine tirée de sa clé)` ;
- U2 : dans `Peinture.decoder_tampons`, supprimer les deux lignes `if index >= EtatPartie.NB_JOUEURS_MAX:` / `return [] as Array[Dictionary]` ⇒ `❌ un lot tronqué, un index de joueur hors plage ou autre chose qu'un lot d'octets est ignoré en entier` ;
- U3 : dans `Territoire.appliquer_changements`, remplacer les deux lignes du premier `if i >= _peignables.size() … :` / `return false` par `pass` ⇒ `❌ un lot mal formé (cellule non peignable ou hors grille, joueur hors plage, taille tronquée) est refusé sans rien changer`.

Expected ensuite : `git status --short` vide.

---

### Task 2 : la ville et la traceuse : tampons en événements, tampons reçus, coulures identiques

**Files:**
- Modify: `Scripts/Ville.gd` (docstring, signal, constantes, variables, `charger_skyline`, `peindre` découpé, `_tampons_pour` ; `_cle_tampons` et `_generer_tampons` partent dans `Peinture`)
- Modify: `Scripts/GerbeTraceuse.gd` (`_physics_process`)
- Test: `tests/smoke_test.gd` (section « Territoire »)

**Interfaces:**
- Consumes : Task 1 (`Peinture`) ; `GameState.joueurs`, `GameState.regles.manche_en_cours()`.
- Produces (Tasks 7, 8) : `signal Ville.tampon_peint(tampon: Dictionary)` (sur l'hôte, chaque tampon appliqué : `{"index", "x", "y", "rayon", "graine"}`, centre en pixels de la ville) ; `func Ville.peindre_tampon_recu(tampon: Dictionary) -> void` ; `Ville.peindre(position_globale, rayon, peintre)` garde sa signature (graine tirée par `randi()`) ; `const Ville.FENETRE_COULURES := 120`, `var _nb_tampons`, `var _tampons_des_coulures: Array[int]` ; `Ville.NB_TAMPONS` et `Ville.CHANCE_COULURE` valent ceux de `Peinture`.

- [ ] **Step 1 : le test**

Dans `tests/smoke_test.gd` :

1a. Remplacer :

```gdscript
	_check(t.cellules_de(0) > scores_avant[0], "de retour sur l'hôte, les mêmes tampons comptent")

	# Après terminer_partie, partie_en_cours retombe mais pret reste vrai (pas de retour à
	# l'intro) ; un lion peut donc encore peindre. Le tampon visuel doit rester, mais plus aucun
```

par :

```gdscript
	_check(t.cellules_de(0) > scores_avant[0], "de retour sur l'hôte, les mêmes tampons comptent")

	# Phase 14 : chaque tampon de l'hôte part en événement ; un client le dessine à l'identique (même
	# jeu de tampons, même variante, même coulure), centres négatifs compris, sans le rediffuser ni
	# toucher à son territoire. La traceuse d'un lion de client ne peint pas.
	var emis: Array[Dictionary] = []
	var sur_tampon := func(tampon: Dictionary) -> void: emis.append(tampon)
	ville_b.tampon_peint.connect(sur_tampon)
	ville_b.image.fill(Color(0, 0, 0, 0))
	ville_b.coulures.clear()
	ville_b._nb_tampons = 0  # comme une ville neuve : le plafond des coulures compte en tampons peints
	ville_b._tampons_des_coulures.clear()
	var coin_ville: Vector2 = ville_b.position - Vector2(ville_b.tex_size) / 2.0
	ville_b.peindre(coin_ville + Vector2(-10, 40), 30, j_r)  # déborde à gauche : x négatif
	for i in range(40):
		ville_b.peindre(coin_ville + Vector2(200 + 11 * i, 60), 21, j_b)
	ville_b.tampon_peint.disconnect(sur_tampon)
	_check(emis.size() == 41 and emis[0].index == 0 and emis[0].x == -10 and emis[0].rayon == 30 and emis[1].index == 1
		and ville_b.coulures.size() > 0,
		"sur l'hôte, chaque tampon part en événement (index du peintre, centre en pixels de la ville, rayon, graine), coulures comprises")
	var poste_c := Node2D.new()
	poste_c.name = "PosteClientVille"
	root.add_child(poste_c)
	var api_c := SceneMultiplayer.new()
	var pair_c := ENetMultiplayerPeer.new()
	_check(pair_c.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client pour la ville d'un client")
	api_c.multiplayer_peer = pair_c
	set_multiplayer(api_c, poste_c.get_path())
	var ville_c: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	ville_c.position = ville_b.position
	poste_c.add_child(ville_c)
	var emis_client: Array[Dictionary] = []
	ville_c.tampon_peint.connect(func(tampon: Dictionary) -> void: emis_client.append(tampon))
	for tampon in emis:
		ville_c.peindre_tampon_recu(tampon)
	_check(not ville_c.multiplayer.is_server() and ville_c.image.get_data() == ville_b.image.get_data()
		and ville_c.coulures == ville_b.coulures,
		"chez un client, les tampons reçus se dessinent pixel pour pixel comme chez l'hôte, coulures comprises (%d coulures)" % ville_c.coulures.size())
	_check(emis_client.is_empty() and ville_c.territoire.cellules_de(0) == 0 and ville_c.territoire.cellules_de(1) == 0,
		"un client ne rediffuse pas les tampons reçus et ne les compte pas dans son territoire")
	ville_c.peindre_tampon_recu({"index": 7, "x": 500, "y": 50, "rayon": 20, "graine": 1})
	_check(ville_c.image.get_data() == ville_b.image.get_data(), "un tampon reçu pour un joueur inconnu de ce poste est ignoré")
	# Les mêmes 400 tampons, l'un d'un coup, l'autre avec des coulures qui finissent entre deux
	# tampons (un autre rythme d'affichage) : les mêmes coulures sont lancées
	var ville_d: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	var ville_e: Node2D = load("res://Scenes/Ville.tscn").instantiate()
	for v: Node2D in [ville_d, ville_e]:
		v.position = ville_b.position
		poste_c.add_child(v)
	for g in range(400):
		var tampon := {"index": 1, "x": 100 + (g * 7) % 1800, "y": 60, "rayon": 21, "graine": g}
		ville_d.peindre_tampon_recu(tampon)
		ville_e.peindre_tampon_recu(tampon)
		ville_e._avancer_coulures(1.0)
	_check(ville_d._tampons_des_coulures == ville_e._tampons_des_coulures and ville_d._tampons_des_coulures.size() > 0
		and ville_d.coulures.size() > ville_e.coulures.size(),
		"les mêmes tampons lancent les mêmes coulures, quel que soit le rythme d'affichage (plafond compté en tampons)")
	ville_d.free()
	ville_e.free()
	var lion_c: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
	lion_c.joueur = j_r
	lion_c.commandes = Commandes.manuelles()
	poste_c.add_child(lion_c)
	lion_c.global_position = poste_peinture
	await _frames(2)
	emis.clear()
	ville_b.tampon_peint.connect(sur_tampon)
	lion_c.gerbe_traceuse.monitoring = true  # comme un vomi répliqué
	await _frames(5)
	_check(lion_c.gerbe_traceuse.get_overlapping_areas().size() > 0 and emis.is_empty(),
		"la traceuse d'un lion de client, au-dessus de la ville, ne peint pas (seule celle de l'hôte peint)")
	ville_b.tampon_peint.disconnect(sur_tampon)
	lion_c.free()
	set_multiplayer(null, poste_c.get_path())
	pair_c.close()
	poste_c.free()

	# Après terminer_partie, partie_en_cours retombe mais pret reste vrai (pas de retour à
	# l'intro) ; un lion peut donc encore peindre. Le tampon visuel doit rester, mais plus aucun
```

- [ ] **Step 2 : le test échoue**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`.
Expected (mesuré) : les 320 vérifications d'avant passent, puis `SCRIPT ERROR: Invalid access to property or key 'tampon_peint' on a base object of type 'Node2D (Ville.gd)'.` : le smoke test s'arrête sur cette ligne sans quitter, et son `timeout` le coupe (`code 124` ; pour ne pas attendre 300 s, lancer ce passage avec `timeout -k 5 60`).

- [ ] **Step 3 : la ville et la traceuse**

Dans `Scripts/Ville.gd` :

3a. Remplacer :

```gdscript
## cellules qu'il recouvre (`EMPREINTE_TERRITOIRE`).

const TAILLE_CELLULE := 8
const NB_TAMPONS := 4
const DENSITE_TAMPON := 0.5
const CHANCE_COULURE := 0.3
const COULURES_MAX := 40
const VITESSE_COULURE := 70.0  # px/s
```

par :

```gdscript
## cellules qu'il recouvre (`EMPREINTE_TERRITOIRE`).
## En réseau (phase 14), seule la traceuse de l'hôte peint : chaque tampon qu'il applique part en
## événement (`tampon_peint`), que la manche diffuse ; un client dessine les tampons reçus
## (`peindre_tampon_recu`), identiques à ceux de l'hôte (`Peinture` : jeux de tampons tirés de leur
## clé, variante et coulure tirées de la graine du tampon), et son territoire suit celui de l'hôte
## par les cellules changées reçues (`Territoire.appliquer_changements`).

## Sur l'hôte : un tampon vient d'être appliqué. `tampon` : `{"index": int, "x": int, "y": int,
## "rayon": int, "graine": int}` (index du peintre, centre en pixels de la ville), le format que
## `Peinture.encoder_tampons` diffuse.
signal tampon_peint(tampon: Dictionary)

const TAILLE_CELLULE := 8
const NB_TAMPONS := Peinture.NB_TAMPONS
const CHANCE_COULURE := Peinture.CHANCE_COULURE
## Coulures lancées au plus parmi les FENETRE_COULURES derniers tampons de la ville : un plafond
## compté en tampons, pas en coulures encore en cours. Chaque poste peint les mêmes tampons dans le
## même ordre (ceux que diffuse l'hôte) : il lance donc les mêmes coulures, quel que soit son rythme
## d'affichage (qui, lui, fait avancer les coulures).
const COULURES_MAX := 40
const FENETRE_COULURES := 120
const VITESSE_COULURE := 70.0  # px/s
```

3b. Remplacer :

```gdscript
var coulures: Array[Dictionary] = []
## Tampons par rayon et jeu de couleurs (clé : `_cle_tampons`) : deux lions qui ont autant de
## couleurs et le même rayon peignent chacun avec les leurs.
```

par :

```gdscript
var coulures: Array[Dictionary] = []
## Tampons peints depuis la dernière skyline, et le numéro du tampon de chaque coulure récente (voir
## FENETRE_COULURES).
var _nb_tampons := 0
var _tampons_des_coulures: Array[int] = []
## Tampons par rayon et jeu de couleurs (clé : `Peinture.cle_tampons`) : deux lions qui ont autant de
## couleurs et le même rayon peignent chacun avec les leurs.
```

3c. Remplacer :

```gdscript
	coulures.clear()
	_tampons.clear()
```

par :

```gdscript
	coulures.clear()
	_nb_tampons = 0
	_tampons_des_coulures.clear()
	_tampons.clear()
```

3d. Remplacer :

```gdscript
## Applique un tampon de peinture de rayon `rayon`, centré sur une position globale, aux couleurs
## débloquées de `peintre`. En bataille, sur l'hôte seulement, et tant que la manche est en cours,
## le tampon est aussi reporté sur le territoire et ses vols sont signalés aux règles.
func peindre(position_globale: Vector2, rayon: int, peintre: Joueur) -> void:
	var couleurs := peintre.couleurs_debloquees
	if couleurs.is_empty() or rayon <= 0:
		return
	var local := sprite.to_local(position_globale)
	var px := int(local.x + tex_size.x / 2.0)
	var py := int(local.y + tex_size.y / 2.0)
	if px < -rayon or py < -rayon or px >= tex_size.x + rayon or py >= tex_size.y + rayon:
		return

	var tampons := _tampons_pour(rayon, couleurs)
	var tampon: Image = tampons[randi() % tampons.size()]
	var taille := tampon.get_width()
	image.blit_rect_mask(tampon, tampon, Rect2i(0, 0, taille, taille), Vector2i(px - rayon, py - rayon))
	if coulures.size() < COULURES_MAX and randf() < CHANCE_COULURE:
		var c := couleurs[randi() % couleurs.size()]
		c.a = 1.0
		coulures.append({
			"x": px + randi_range(-rayon, rayon), "y": float(py + randi_range(0, rayon)),
			"fin": float(py + rayon + randi_range(14, 44)), "couleur": c,
		})
	_dirty = true
	# Le territoire ne bouge que pendant la manche : après terminer_partie, pret reste vrai et un
	# lion peut encore peindre ; le tampon se dessine, le score reste figé.
	if territoire != null and multiplayer.is_server() and GameState.regles.manche_en_cours():
		var volees := territoire.tamponner(peintre.index, Vector2i(px, py), rayon + EMPREINTE_TERRITOIRE)
```

par :

```gdscript
## Applique un tampon de peinture de rayon `rayon`, centré sur une position globale, aux couleurs
## débloquées de `peintre`. Sa graine (variante et coulure, voir `Peinture.tirage`) est tirée ici
## (`randi`). Sur l'hôte, le tampon part aussi en événement (`tampon_peint`) et, en bataille, tant
## que la manche est en cours, il est reporté sur le territoire et ses vols sont signalés aux règles.
func peindre(position_globale: Vector2, rayon: int, peintre: Joueur) -> void:
	var local := sprite.to_local(position_globale)
	_peindre_en(Vector2i(int(local.x + tex_size.x / 2.0), int(local.y + tex_size.y / 2.0)), rayon, peintre,
		randi() & Peinture.GRAINE_MAX)


## Chez un client : un tampon diffusé par l'hôte (voir `tampon_peint`), dessiné à l'identique ; un
## index de joueur inconnu de ce poste est ignoré.
func peindre_tampon_recu(tampon: Dictionary) -> void:
	if tampon.index < 0 or tampon.index >= GameState.joueurs.size():
		return
	_peindre_en(Vector2i(tampon.x, tampon.y), tampon.rayon, GameState.joueurs[tampon.index], tampon.graine)


## Le tampon de rayon `rayon` et de graine `graine`, centré en `centre` (pixels de la ville,
## éventuellement hors de l'image : un tampon qui déborde est dessiné en partie).
func _peindre_en(centre: Vector2i, rayon: int, peintre: Joueur, graine: int) -> void:
	var couleurs := peintre.couleurs_debloquees
	if couleurs.is_empty() or rayon <= 0:
		return
	var px := centre.x
	var py := centre.y
	if px < -rayon or py < -rayon or px >= tex_size.x + rayon or py >= tex_size.y + rayon:
		return

	var tire := Peinture.tirage(graine, rayon, couleurs.size())
	var tampon: Image = _tampons_pour(rayon, couleurs)[tire.variante]
	var taille := tampon.get_width()
	image.blit_rect_mask(tampon, tampon, Rect2i(0, 0, taille, taille), Vector2i(px - rayon, py - rayon))
	_nb_tampons += 1
	while not _tampons_des_coulures.is_empty() and _tampons_des_coulures[0] <= _nb_tampons - FENETRE_COULURES:
		_tampons_des_coulures.pop_front()
	if tire.coulure and _tampons_des_coulures.size() < COULURES_MAX:
		_tampons_des_coulures.append(_nb_tampons)
		var c := couleurs[tire.couleur]
		c.a = 1.0
		coulures.append({
			"x": px + tire.dx, "y": float(py + tire.dy), "fin": float(py + rayon + tire.longueur), "couleur": c,
		})
	_dirty = true
	if not multiplayer.is_server():
		return
	tampon_peint.emit({"index": peintre.index, "x": px, "y": py, "rayon": rayon, "graine": graine})
	# Le territoire ne bouge que pendant la manche : après terminer_partie, pret reste vrai et un
	# lion peut encore peindre ; le tampon se dessine, le score reste figé.
	if territoire != null and GameState.regles.manche_en_cours():
		var volees := territoire.tamponner(peintre.index, Vector2i(px, py), rayon + EMPREINTE_TERRITOIRE)
```

3e. Remplacer :

```gdscript
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
	for t in range(NB_TAMPONS):
		var tampon := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
		tampon.fill(Color(0, 0, 0, 0))
		for y in range(taille):
			for x in range(taille):
				var dx := x - rayon
				var dy := y - rayon
				var d := sqrt(dx * dx + dy * dy) / rayon
				if d > 1.0:
					continue
				# Plus dense au centre, éparse sur les bords.
				if randf() < DENSITE_TAMPON * (1.3 - d):
					var c := couleurs[randi() % couleurs.size()]
					c.a = 1.0
					tampon.set_pixel(x, y, c)
		tampons.append(tampon)
	return tampons

```

par :

```gdscript
	_dirty = true


## Les NB_TAMPONS tampons de ce rayon et de ce jeu de couleurs (`Peinture.generer_tampons`, les
## mêmes sur chaque poste) : générés au premier usage, puis gardés en cache (TAMPONS_EN_CACHE_MAX
## jeux au plus).
func _tampons_pour(rayon: int, couleurs: Array[Color]) -> Array:
	var cle := Peinture.cle_tampons(rayon, couleurs)
	if not _tampons.has(cle):
		if _tampons.size() >= TAMPONS_EN_CACHE_MAX:
			_tampons.clear()
		_tampons[cle] = Peinture.generer_tampons(rayon, couleurs)
	return _tampons[cle]

```

Dans `Scripts/GerbeTraceuse.gd` :

3f. Remplacer :

```gdscript
## de tampons et le rééquilibrage du territoire du taux de rafraîchissement de l'hôte (30 à 144 Hz).
## En solo, à 60 Hz, rien ne change.
func _physics_process(_delta: float) -> void:
	if not monitoring:
		return
```

par :

```gdscript
## de tampons et le rééquilibrage du territoire du taux de rafraîchissement de l'hôte (30 à 144 Hz).
## En solo, à 60 Hz, rien ne change. Sur l'hôte seulement : sur un client, le lion réplique le vomi
## de l'hôte (la zone surveille donc aussi la ville), mais ses tampons sont ceux que l'hôte diffuse
## (`Ville.peindre_tampon_recu`) ; en peindre ici en ferait un second, tiré par ce poste.
func _physics_process(_delta: float) -> void:
	if not monitoring or not multiplayer.is_server():
		return
```

- [ ] **Step 4 : le test passe**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`, puis `T=tests/bataille_test.gd; O="--fixed-fps 60"` (la manche à 4 et ses mesures, sous `seed(20260925)` : Écart 9).
Expected (mesuré) : `code 0`, `== 0 échec(s) ==` pour les deux, dont « chez un client, les tampons reçus se dessinent pixel pour pixel comme chez l'hôte, coulures comprises (… coulures) », « les mêmes tampons lancent les mêmes coulures, quel que soit le rythme d'affichage (plafond compté en tampons) », « la traceuse d'un lion de client, au-dessus de la ville, ne peint pas » ; dans `tests/bataille_test.gd`, les lignes `MESURE niveau …` dans leurs cibles (rapports entre 0,7 et 1,3, vols de 40 % au moins).

- [ ] **Step 5 : Commit, puis le test discrimine**

```bash
git add Scripts/Ville.gd Scripts/GerbeTraceuse.gd tests/smoke_test.gd
git commit -m "Ville : chaque tampon de l'hôte part en événement, un client dessine les tampons reçus à l'identique (jeux de Peinture, variante et coulure de la graine, plafond des coulures compté en tampons), sans toucher à son territoire ; traceuse sur l'hôte seulement ; smoke test

<ligne fournie par l'environnement>"
```

Puis chaque mutation seule, `T=tests/smoke_test.gd`, et **`git checkout -- Scripts/`** avant la suivante (mesuré) :
- V1 : dans `GerbeTraceuse._physics_process`, `if not monitoring or not multiplayer.is_server():` → `if not monitoring:` ⇒ `❌ la traceuse d'un lion de client, au-dessus de la ville, ne peint pas (seule celle de l'hôte peint)` ;
- V2 : dans `Ville._peindre_en`, `_tampons_pour(rayon, couleurs)[tire.variante]` → `_tampons_pour(rayon, couleurs)[randi() % NB_TAMPONS]` ⇒ `❌ chez un client, les tampons reçus se dessinent pixel pour pixel…` et `❌ un tampon reçu pour un joueur inconnu de ce poste est ignoré` ;
- V3 : dans `Ville._peindre_en`, supprimer les deux lignes `if not multiplayer.is_server():` / `return` ⇒ `❌ sur un client, la ville dessine les tampons sans toucher au territoire` et `❌ un client ne rediffuse pas les tampons reçus et ne les compte pas dans son territoire` ;
- V4 : `if tire.coulure and _tampons_des_coulures.size() < COULURES_MAX:` → `if tire.coulure and coulures.size() < COULURES_MAX:` (l'ancien plafond) ⇒ `❌ les mêmes tampons lancent les mêmes coulures, quel que soit le rythme d'affichage (plafond compté en tampons)`.

Expected ensuite : `git status --short` vide.

---

### Task 3 : le joueur répliqué, les minuteries de l'hôte, la fenêtre en 16:9

**Files:**
- Modify: `Scripts/Joueur.gd` (trois fonctions avant `activer_bonus`)
- Modify: `Scripts/GameState.gd` (`_process`)
- Modify: `Scripts/Regles.gd` (deux fonctions statiques après `taille_ecran`)
- Modify: `Scripts/Titre.gd`, `Scripts/Salon.gd`, `Scripts/EcranReseau.gd`, `Scripts/Main.gd` (une ligne chacun)
- Test: `tests/unitaires.gd` (`_run`, une fonction à la fin)

**Interfaces:**
- Consumes : signaux de `Joueur` (`crans_changes`, `etourdissement_fini`, `bonus_change`) ; `Regles.TAILLE_ECRAN_SOLO`, `ReglesBataille.TAILLE_ECRAN`.
- Produces (Task 7) : `Joueur.recevoir_crans(n: int)`, `Joueur.recevoir_fin_etourdissement(immunite_restante: float)`, `Joueur.recevoir_fin_bonus()` (émettent les signaux de l'hôte, sans effet si rien ne change) ; `GameState._process` ne décompte les minuteries des joueurs que sur l'hôte ; `static func Regles.appliquer_ecran(arbre: SceneTree, taille: Vector2i)`, `static func Regles.taille_fenetre(ecran: Vector2i, fenetre: Vector2i) -> Vector2i`.

- [ ] **Step 1 : le test**

Dans `tests/unitaires.gd` :

1a. Remplacer :

```gdscript
	_tester_territoire_reseau()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_territoire_reseau()
	_tester_joueur_replique()
	print("== %d échec(s) ==" % _echecs)
```

1b. Remplacer :

```gdscript
	_check(vide.is_empty(), "appliquer les changements de l'hôte n'en crée pas d'autres chez le client")

```

par :

```gdscript
	_check(vide.is_empty(), "appliquer les changements de l'hôte n'en crée pas d'autres chez le client")



## Phase 14 : chez un client, les réactions des joueurs viennent de l'hôte (signaux compris), qui seul
## décompte leurs minuteries ; la fenêtre suit le format de l'écran.
func _tester_joueur_replique() -> void:
	print("-- Joueur répliqué (réactions reçues de l'hôte, minuteries de l'hôte)")
	var j := Joueur.new()
	j.reinitialiser(3)
	var journal: Array[String] = []
	j.crans_changes.connect(func(c: int) -> void: journal.append("crans:%d" % c))
	j.etourdissement_fini.connect(func() -> void: journal.append("fin_etourdi"))
	j.bonus_change.connect(func(actif: bool) -> void: journal.append("bonus:%s" % actif))
	j.recevoir_crans(4)
	j.recevoir_crans(4)
	j.recevoir_crans(99)
	_check(journal == ["crans:4", "crans:%d" % Joueur.CRANS_MAX] and j.crans == Joueur.CRANS_MAX,
		"les crans de l'hôte sont posés et signalés une fois, dans leurs bornes (%s)" % [journal])
	journal.clear()
	j.recevoir_fin_etourdissement(0.5)
	j.etourdir(1.5, 1.0, Vector2.INF, Color.RED)
	j.recevoir_fin_etourdissement(0.97)
	j.recevoir_fin_etourdissement(0.9)
	_check(journal == ["fin_etourdi"] and not j.est_etourdi() and is_equal_approx(j.invulnerable_restant, 0.97),
		"la fin d'étourdissement de l'hôte n'est signalée qu'à un joueur étourdi, une fois, avec l'immunité qui reste chez l'hôte")
	journal.clear()
	j.recevoir_fin_bonus()
	j.activer_bonus(8.0)
	j.recevoir_fin_bonus()
	j.recevoir_fin_bonus()
	_check(journal == ["bonus:true", "bonus:false"] and not j.bonus_actif(), "la fin de la gerbe XXL de l'hôte est signalée une fois (%s)" % [journal])

	var gs: Node = root.get_node("GameState")
	gs.configurer_bataille(2)
	gs.nouvelle_partie()
	gs.pret = true
	var joueur: Joueur = gs.joueurs[1]
	joueur.etourdir(1.5, 1.0, Vector2.INF, Color.RED)
	var fins: Array[int] = []
	var sur_fin := func() -> void: fins.append(1)
	joueur.etourdissement_fini.connect(sur_fin)
	var api := SceneMultiplayer.new()
	var pair := ENetMultiplayerPeer.new()
	_check(pair.create_client("127.0.0.1", 17795) == OK, "(pré-condition) GameState sur un pair client")
	api.multiplayer_peer = pair
	set_multiplayer(api, gs.get_path())
	gs._process(2.0)
	_check(is_equal_approx(gs.temps_ecoule, 2.0) and joueur.est_etourdi() and is_equal_approx(joueur.etourdi_restant, 1.5) and fins.is_empty(),
		"sur un client, le chrono tourne mais les minuteries des joueurs attendent l'hôte (aucune fin émise)")
	set_multiplayer(null, gs.get_path())
	pair.close()
	gs._process(2.0)
	_check(not joueur.est_etourdi() and fins.size() == 1, "sur l'hôte (hors réseau compris), GameState décompte les minuteries des joueurs")
	joueur.etourdissement_fini.disconnect(sur_fin)
	gs.configurer_solo()
	gs.nouvelle_partie()
	gs.partie_en_cours = false
	gs.pret = false

	_check(Regles.taille_fenetre(ReglesBataille.TAILLE_ECRAN, Vector2i(1400, 454)) == Vector2i(1400, 788)
		and Regles.taille_fenetre(Regles.TAILLE_ECRAN_SOLO, Vector2i(1400, 788)) == Vector2i(1400, 454),
		"hors du solo, la fenêtre prend le format 16:9 (1400×788), et le reprend du solo au retour (1400×454)")

```

- [ ] **Step 2 : le test échoue**

Run : la commande des Global Constraints avec `T=tests/unitaires.gd`.
Expected (mesuré) : `code 0`, sans ligne `== n échec(s) ==`, et deux `SCRIPT ERROR: Parse Error: Static function "taille_fenetre()" not found in base "Regles".` : le script ne compile pas.

- [ ] **Step 3 : `Joueur`, `GameState`, `Regles` et les quatre écrans**

Dans `Scripts/Joueur.gd` :

3a. Remplacer :

```gdscript
	return [couleur.darkened(ECART_NUANCES), couleur, couleur.lightened(ECART_NUANCES)]


## Active (ou prolonge) la gerbe XXL pour `duree` secondes.
func activer_bonus(duree: float) -> void:
	var etait_actif := bonus_actif()
```

par :

```gdscript
	return [couleur.darkened(ECART_NUANCES), couleur, couleur.lightened(ECART_NUANCES)]


## Chez un client (phase 14) : les réactions décidées par l'hôte, que la manche lui transmet (sur un
## client, seul l'hôte décompte les minuteries : `GameState` n'y appelle pas `avancer`). Chacune pose
## l'état que l'hôte a et émet le même signal que la méthode de l'hôte (Lion, HUD, Audio l'écoutent
## sur chaque poste) ; sans effet ni signal si rien ne change. Le début d'un étourdissement et celui
## d'une gerbe XXL passent par `etourdir` et `activer_bonus`, comme chez l'hôte.


## Les crans de gerbe de l'hôte (ramenés dans [1, CRANS_MAX]).
func recevoir_crans(n: int) -> void:
	var crans_hote := clampi(n, 1, CRANS_MAX)
	if crans_hote == crans:
		return
	crans = crans_hote
	crans_changes.emit(crans)


## Fin de l'étourdissement chez l'hôte : l'immunité qui reste (`invulnerable_restant` de l'hôte) est
## celle que le lion fait clignoter.
func recevoir_fin_etourdissement(immunite_restante: float) -> void:
	if not est_etourdi():
		return
	etourdi_restant = 0.0
	invulnerable_restant = maxf(immunite_restante, 0.0)
	etourdissement_fini.emit()


## Fin de la gerbe XXL chez l'hôte.
func recevoir_fin_bonus() -> void:
	if not bonus_actif():
		return
	bonus_restant = 0.0
	bonus_change.emit(false)


## Active (ou prolonge) la gerbe XXL pour `duree` secondes.
func activer_bonus(duree: float) -> void:
	var etait_actif := bonus_actif()
```

Dans `Scripts/GameState.gd` :

3b. Remplacer :

```gdscript
		joueurs[i].index = i
		joueurs[i].couleur = retenues[i]
	return nb


func _process(delta: float) -> void:
	if not partie_en_cours or not pret:
		return
	temps_ecoule += delta
	for j in joueurs:
		j.avancer(delta)


func nouvelle_partie() -> void:
```

par :

```gdscript
		joueurs[i].index = i
		joueurs[i].couleur = retenues[i]
	return nb


## Le chrono tourne sur chaque poste (l'affichage) ; les minuteries des joueurs (étourdissement,
## immunité, gerbe XXL) ne sont décomptées que par l'hôte, qui décide de leurs fins : un client les
## reçoit de la manche (`Joueur.recevoir_fin_etourdissement`, `recevoir_fin_bonus`, phase 14), sans
## quoi chaque poste émettrait ses propres fins, un peu avant ou après celles de l'hôte.
func _process(delta: float) -> void:
	if not partie_en_cours or not pret:
		return
	temps_ecoule += delta
	if not multiplayer.is_server():
		return
	for j in joueurs:
		j.avancer(delta)


func nouvelle_partie() -> void:
```

Dans `Scripts/Regles.gd` :

3c. Remplacer :

```gdscript
## dans la scène de jeu, et par le titre (qui remet le solo) : celle du solo par défaut.
func taille_ecran() -> Vector2i:
	return TAILLE_ECRAN_SOLO


## Avancement de la partie, de 0 (début) à 1 (fin en vue), qui accélère le peintre et les
```

par :

```gdscript
## dans la scène de jeu, et par le titre (qui remet le solo) : celle du solo par défaut.
func taille_ecran() -> Vector2i:
	return TAILLE_ECRAN_SOLO


## Met l'écran à `taille` (`content_scale_size`, spec §7) et, quand l'écran change de format dans
## une fenêtre (ni plein écran, ni maximisée, ni headless), règle la hauteur de la fenêtre sur le
## nouveau format en gardant sa largeur : hors du solo (écran Réseau, salon, bataille en 16:9),
## l'écran ne s'affiche plus avec des bandes dans la fenêtre du solo (1400×454 devient 1400×788), et
## le titre la rend au solo. Un écran qui ne change pas (du titre au solo) laisse la fenêtre telle que
## le joueur l'a mise. Appelée par le titre, l'écran Réseau, le salon et la scène de jeu.
static func appliquer_ecran(arbre: SceneTree, taille: Vector2i) -> void:
	var avant := arbre.root.content_scale_size
	arbre.root.content_scale_size = taille
	if avant == taille or DisplayServer.get_name() == "headless" \
			or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	DisplayServer.window_set_size(taille_fenetre(taille, DisplayServer.window_get_size()))


## La fenêtre de largeur `fenetre.x` au format de l'écran `ecran`.
static func taille_fenetre(ecran: Vector2i, fenetre: Vector2i) -> Vector2i:
	return Vector2i(fenetre.x, roundi(fenetre.x * float(ecran.y) / ecran.x))


## Avancement de la partie, de 0 (début) à 1 (fin en vue), qui accélère le peintre et les
```

Dans `Scripts/Titre.gd` :

3d. Remplacer :

```gdscript
	GameState.configurer_solo()
	get_tree().root.content_scale_size = GameState.regles.taille_ecran()
	Audio.demarrer_musique("ville", 1)
```

par :

```gdscript
	GameState.configurer_solo()
	Regles.appliquer_ecran(get_tree(), GameState.regles.taille_ecran())
	Audio.demarrer_musique("ville", 1)
```

Dans `Scripts/Salon.gd` :

3e. Remplacer :

```gdscript
func _ready() -> void:
	get_tree().root.content_scale_size = ReglesBataille.TAILLE_ECRAN
	for i in range(EtatPartie.NB_JOUEURS_MAX):
```

par :

```gdscript
func _ready() -> void:
	Regles.appliquer_ecran(get_tree(), ReglesBataille.TAILLE_ECRAN)
	for i in range(EtatPartie.NB_JOUEURS_MAX):
```

Dans `Scripts/EcranReseau.gd` :

3f. Remplacer :

```gdscript
func _ready() -> void:
	get_tree().root.content_scale_size = ReglesBataille.TAILLE_ECRAN
	champ_pseudo.max_length = Reseau.PSEUDO_MAX
```

par :

```gdscript
func _ready() -> void:
	Regles.appliquer_ecran(get_tree(), ReglesBataille.TAILLE_ECRAN)
	champ_pseudo.max_length = Reseau.PSEUDO_MAX
```

Dans `Scripts/Main.gd` :

3g. Remplacer :

```gdscript
		Input.action_release(action)
	get_tree().root.content_scale_size = GameState.regles.taille_ecran()
	GameState.nouvelle_partie()
```

par :

```gdscript
		Input.action_release(action)
	Regles.appliquer_ecran(get_tree(), GameState.regles.taille_ecran())
	GameState.nouvelle_partie()
```

Un écran qui ne change pas de format (du titre au solo) laisse la fenêtre telle que le joueur l'a mise : le solo ne change pas. Une fenêtre en plein écran (réglage « plein écran » de `Parametres`) n'est pas touchée.

- [ ] **Step 4 : le test passe**

Run : la commande des Global Constraints avec `T=tests/unitaires.gd`, puis `T=tests/smoke_test.gd` et `T=tests/bataille_test.gd; O="--fixed-fps 60"` (les écrans en headless : `appliquer_ecran` n'y touche pas la fenêtre).
Expected (mesuré) : `code 0`, `== 0 échec(s) ==` pour les trois ; 7 lignes ✅ sous « -- Joueur répliqué (réactions reçues de l'hôte, minuteries de l'hôte) ».

- [ ] **Step 5 : Commit, puis le test discrimine**

```bash
git add Scripts/Joueur.gd Scripts/GameState.gd Scripts/Regles.gd Scripts/Titre.gd Scripts/Salon.gd Scripts/EcranReseau.gd Scripts/Main.gd tests/unitaires.gd
git commit -m "Joueur : réactions reçues de l'hôte (crans, fins d'étourdissement et de gerbe XXL, avec leurs signaux) ; GameState : minuteries des joueurs décomptées par l'hôte seul ; Regles.appliquer_ecran : la fenêtre prend le format de l'écran hors du solo ; tests unitaires

<ligne fournie par l'environnement>"
```

Puis chaque mutation seule, `T=tests/unitaires.gd`, et **`git checkout -- Scripts/`** avant la suivante (mesuré) :
- J1 : dans `GameState._process`, supprimer les deux lignes `if not multiplayer.is_server():` / `return` ⇒ `❌ sur un client, le chrono tourne mais les minuteries des joueurs attendent l'hôte (aucune fin émise)` ;
- J2 : dans `Joueur.recevoir_fin_etourdissement`, supprimer les deux lignes `if not est_etourdi():` / `return` ⇒ `❌ la fin d'étourdissement de l'hôte n'est signalée qu'à un joueur étourdi…` ;
- J3 : dans `Regles.taille_fenetre`, `roundi(` → `int(` ⇒ `❌ hors du solo, la fenêtre prend le format 16:9 (1400×788)…`.

Expected ensuite : `git status --short` vide.

---

### Task 4 : `Reseau` pour la manche (relais coupé, silences, départ propre, barrière, lancement revérifié, 0.14)

**Files:**
- Modify: `Scripts/Reseau.gd` (docstring, signal `scene_chargee`, constantes, variables, `_ready`, `heberger`, `quitter`, fonctions neuves après `quitter`, `lancer_manche`, `_recevoir_manche`, RPC `_scene_chargee`, `_sur_pair_connecte`, `_sur_connecte_a_l_hote`)
- Modify: `project.godot` (`config/version`)
- Modify: `tests/reseau/joueur.gd` (rôle `client --partir` : l'autre client se lit dans la table ; Écart 5)
- Test: `tests/unitaires.gd` (`_run`, une fonction et une aide à la fin)

**Interfaces:**
- Consumes : phase 13 (`inscrits`, `table_de`, `compacter_index`, `fiches_de_manche`, `salon_pret`, `lancer_manche`, `manche_lancee`).
- Produces (Tasks 7, 8) : `signal Reseau.scene_chargee(id: int)` ; `var scenes_chargees: Array[int]` ; `func signaler_scene_chargee()` ; `const SILENCE_SESSION := Vector2i(3000, 8000)`, `SILENCE_CHARGEMENT := Vector2i(20000, 30000)`, `ESSAIS_SILENCE := 32`, `DELAI_DEPART := 1000` ; `var silence: Vector2i` ; `func definir_silence(bornes: Vector2i)` ; `var _partants: Array[Dictionary]` ; `server_relay` coupé ; `lancer_manche()` refuse des fiches incohérentes (M1) ; `config/version` = « 0.14 ».

- [ ] **Step 1 : le test**

Dans `tests/unitaires.gd` :

1a. Remplacer :

```gdscript
	_tester_joueur_replique()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_joueur_replique()
	_tester_reseau_manche()
	print("== %d échec(s) ==" % _echecs)
```

1b. Remplacer :

```gdscript
		"hors du solo, la fenêtre prend le format 16:9 (1400×788), et le reprend du solo au retour (1400×454)")

```

par :

```gdscript
		"hors du solo, la fenêtre prend le format 16:9 (1400×788), et le reprend du solo au retour (1400×454)")



## Phase 14 : ce que `Reseau` ajoute pour la manche (relais du serveur coupé, fiches revérifiées au
## lancement, silences, barrière de chargement, départ propre).
func _tester_reseau_manche() -> void:
	print("-- Réseau de la manche (relais, lancement revérifié, silences, scènes chargées, départ)")
	var reseau: Node = root.get_node("Reseau")
	var api := root.multiplayer as SceneMultiplayer
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	reseau.pseudo = "Hôte"
	_check(reseau.heberger(17788) == OK and not api.server_relay and reseau.silence == reseau.SILENCE_SESSION,
		"l'hôte écoute, sans relais entre clients (M5), silence de session")
	reseau.inscrits[5] = {"index": 1, "couleur": palette[1], "pseudo": "Bob", "arrive": true, "pret": true}
	reseau.inscrits[9] = {"index": 3, "couleur": palette[2], "pseudo": "Chloé", "arrive": true, "pret": true}
	var hote: Dictionary = reseau.inscrits[1]
	reseau.inscrits.erase(1)  # une table où l'hôte n'est plus : `fiches_de_manche` la refuse
	var lancees: Array = []
	var sur_lancement := func(f: Array[Dictionary]) -> void: lancees.append(f)
	reseau.manche_lancee.connect(sur_lancement)
	_check(reseau.salon_pret(reseau.inscrits) and not reseau.lancer_manche() and not reseau.manche_en_cours and lancees.is_empty()
		and reseau.inscrits[9].index == 3 and reseau.silence == reseau.SILENCE_SESSION,
		"M1 : des fiches de manche incohérentes font refuser le lancement sans rien changer, même quand le salon est prêt (ligne ERROR attendue)")
	hote.pret = true
	reseau.inscrits[1] = hote
	reseau.signaler_scene_chargee()
	_check(reseau.lancer_manche() and reseau.manche_en_cours and lancees.size() == 1 and reseau.scenes_chargees.is_empty()
		and reseau.silence == reseau.SILENCE_CHARGEMENT,
		"au lancement : plus aucune scène chargée d'une manche précédente, silence de chargement")
	var chargees: Array[int] = []
	var sur_scene := func(id: int) -> void: chargees.append(id)
	reseau.scene_chargee.connect(sur_scene)
	reseau.signaler_scene_chargee()
	reseau.signaler_scene_chargee()
	_check(reseau.scenes_chargees == [1] and chargees == [1], "chez l'hôte, sa scène chargée est notée et signalée une fois")
	reseau.scene_chargee.disconnect(sur_scene)
	reseau.manche_lancee.disconnect(sur_lancement)
	reseau.definir_silence(reseau.SILENCE_SESSION)
	_check(reseau.silence == reseau.SILENCE_SESSION, "fin du chargement : silence de session")
	reseau.quitter()
	_check(reseau.scenes_chargees.is_empty() and reseau._partants.is_empty() and reseau.heberger(17788) == OK,
		"quitter oublie les scènes chargées ; sans autre poste connecté, le port se libère aussitôt")
	# Un autre poste connecté au niveau d'ENet (sa poignée de main ne finit jamais) : un départ propre
	# le prévient par un DISCONNECT fiable, renvoyé jusqu'à son accusé de réception.
	var autre := ENetMultiplayerPeer.new()
	_check(autre.create_client("127.0.0.1", 17788) == OK, "(pré-condition) un autre poste se connecte à l'hôte")
	_check(_connecter(autre, reseau), "(pré-condition) connecté au niveau d'ENet")
	reseau.quitter()
	_check(reseau._partants.size() == 1 and not reseau.en_ligne(), "quitter avec un poste connecté : ce poste est hors réseau, son départ part en arrière-plan")
	var prevenu := false
	for i in range(200):
		autre.poll()
		reseau._process(0.0)
		if autre.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED and reseau._partants.is_empty():
			prevenu = true
			break
		OS.delay_msec(5)
	_check(prevenu, "l'autre poste reçoit le départ, qui est clos une fois reçu")
	autre = ENetMultiplayerPeer.new()
	_check(reseau.heberger(17788) == OK and autre.create_client("127.0.0.1", 17788) == OK, "(pré-condition) l'hôte rouvre, l'autre poste se reconnecte")
	var connecte := _connecter(autre, reseau)
	reseau.quitter()
	_check(connecte and reseau._partants.size() == 1 and reseau.heberger(17788) == OK and reseau._partants.is_empty(),
		"héberger aussitôt après un départ en cours : le port de la session quittée est libéré d'abord")
	reseau.quitter()
	autre.close()
	reseau.pseudo = ""



## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
## côtés (l'hôte la tient pour établie à l'accusé de réception de sa réponse) ; 1 s au plus.
func _connecter(autre: ENetMultiplayerPeer, reseau: Node) -> bool:
	var tours_apres := -1
	for i in range(200):
		autre.poll()
		reseau.multiplayer.poll()
		if tours_apres < 0 and autre.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			tours_apres = 0
		if tours_apres >= 0:
			tours_apres += 1
			if tours_apres > 10:
				return true
		OS.delay_msec(5)
	return false

```

- [ ] **Step 2 : le test échoue**

Run : la commande des Global Constraints avec `T=tests/unitaires.gd`.
Expected (mesuré) : `code 1`, `== 2 échec(s) ==` : `❌ l'hôte écoute, sans relais entre clients (M5), silence de session`, `❌ M1 : des fiches de manche incohérentes font refuser le lancement…` (précédé de `SCRIPT ERROR: Out of bounds get index '1' (on base: 'Dictionary[int, Dictionary]')` : l'ancien `lancer_manche` s'engage, puis lit la fiche absente de l'hôte), et `SCRIPT ERROR: Invalid call. Nonexistent function 'signaler_scene_chargee' in base 'Node (Reseau.gd)'.`, qui arrête la fonction. C'est la preuve que ces tests discriminent : `Scripts/Reseau.gd` ne sera jamais muté.

- [ ] **Step 3 : `Reseau`, la version, le harnais**

Dans `Scripts/Reseau.gd` :

3a. Remplacer :

```gdscript
## manche, que l'hôte ne permet que si le salon est prêt (`raison_attente`). Le salon
## (`Scripts/Salon.gd`) affiche la table et porte le bouton de l'hôte ; la manche synchronisée
## (phase 14) s'appuiera sur ses signaux et sur
## `inscrits`. Hors réseau (solo, retour au titre), le pair est un `OfflineMultiplayerPeer` : ce
## poste est son propre hôte (`multiplayer.is_server()` vrai), et `quitter()` y revient toujours.
##
```

par :

```gdscript
## manche, que l'hôte ne permet que si le salon est prêt (`raison_attente`). Le salon
## (`Scripts/Salon.gd`) affiche la table et porte le bouton de l'hôte. Pendant la manche (phase 14),
## la barrière de chargement : chaque poste signale sa scène de jeu chargée
## (`signaler_scene_chargee`), l'hôte les note (`scenes_chargees`) ; la manche synchronisée
## (`Scripts/Manche.gd`) attend tous les joueurs avant l'intro, et suit les départs
## (`joueur_parti`, `hote_perdu`). Hors réseau (solo, retour au titre), le pair est un
## `OfflineMultiplayerPeer` : ce poste est son propre hôte (`multiplayer.is_server()` vrai), et
## `quitter()` y revient toujours.
##
## Départs et silences (M6) : `quitter()` part proprement (un DISCONNECT fiable d'ENet, renvoyé
## jusqu'à son accusé de réception, DELAI_DEPART au plus, en arrière-plan : `_partants`), pas par
## un seul datagramme qu'une perte Wi-Fi ferait passer inaperçu ; un pair muet est considéré parti
## après SILENCE_SESSION (au lieu des 5 à 30 s d'ENet), sauf pendant le chargement de la manche
## (SILENCE_CHARGEMENT : un poste qui charge sa scène ou compile ses shaders ne répond plus). Le
## relais du serveur est coupé (`server_relay`) : tout passe par l'hôte.
##
```

3b. Remplacer :

```gdscript
signal joueur_parti(id: int)
## Chez le client : l'hôte l'a accepté et la connexion est établie (`index_local`, `couleur_locale`).
```

par :

```gdscript
signal joueur_parti(id: int)
## Chez l'hôte, pendant une manche : la scène de jeu du joueur `id` est chargée (l'hôte compris).
signal scene_chargee(id: int)
## Chez le client : l'hôte l'a accepté et la connexion est établie (`index_local`, `couleur_locale`).
```

3c. Remplacer :

```gdscript
const ATTENTE_PRETS := "SALON_ATTENTE_PRETS"
## Pour `adresse_ipv4`, la validation de l'écran Réseau (fonction statique : l'autoload n'est pas
```

par :

```gdscript
const ATTENTE_PRETS := "SALON_ATTENTE_PRETS"
## Silence d'un pair ENet au-delà duquel il est considéré parti (`ENetPacketPeer.set_timeout`, en
## millisecondes : minimum, maximum ; ENet le décide entre les deux selon le temps d'aller-retour).
## Au salon et en manche : un poste planté ou en veille part en 8 s au plus, au lieu des 5 à 30 s
## par défaut d'ENet.
const SILENCE_SESSION := Vector2i(3000, 8000)
## Pendant le chargement de la manche, du lancement à l'intro : un poste qui charge sa scène de jeu
## (ou compile ses shaders, sous Windows) ne répond plus, parfois plus de 5 s.
const SILENCE_CHARGEMENT := Vector2i(20000, 30000)
## Essais de renvoi d'ENet avant de compter le silence (son défaut).
const ESSAIS_SILENCE := 32
## Délai laissé à un départ volontaire pour être reçu (accusé de réception du DISCONNECT), en
## millisecondes.
const DELAI_DEPART := 1000
## Pour `adresse_ipv4`, la validation de l'écran Réseau (fonction statique : l'autoload n'est pas
```

3d. Remplacer :

```gdscript
var index_local := -1
var couleur_locale := Color.TRANSPARENT

## Vrai dès que l'issue d'une connexion est décidée (refus, échec, hôte perdu) : un seul signal
```

par :

```gdscript
var index_local := -1
var couleur_locale := Color.TRANSPARENT
## Chez l'hôte, pendant une manche : les identifiants des joueurs dont la scène de jeu est chargée,
## dans l'ordre (l'hôte compris) ; vidé au lancement de chaque manche et hors réseau.
var scenes_chargees: Array[int] = []
## Silence toléré des pairs de cette session (SILENCE_SESSION ou SILENCE_CHARGEMENT), posé sur
## chaque pair connecté et sur chaque nouveau venu.
var silence := SILENCE_SESSION

## Vrai dès que l'issue d'une connexion est décidée (refus, échec, hôte perdu) : un seul signal
```

3e. Remplacer :

```gdscript
## ni la fermer, ni émettre un signal qui ne la concerne plus.
var _generation := 0
var _delai: Timer


func _ready() -> void:
```

par :

```gdscript
## ni la fermer, ni émettre un signal qui ne la concerne plus.
var _generation := 0
var _delai: Timer
## Sessions quittées dont le départ n'est pas encore reçu : `{"pair": ENetMultiplayerPeer,
## "paquets": Array (ses ENetPacketPeer), "fin": int (ms)}`, servies par `_process` jusqu'à ce que
## chaque autre poste ait accusé réception, ou jusqu'à `fin`, puis fermées.
var _partants: Array[Dictionary] = []


func _ready() -> void:
```

3f. Remplacer :

```gdscript
	var api := _api()
	api.peer_authenticating.connect(_sur_debut_poignee_de_main)
```

par :

```gdscript
	var api := _api()
	api.server_relay = false  # M5 : aucun client ne parle à un autre, tout passe par l'hôte
	api.peer_authenticating.connect(_sur_debut_poignee_de_main)
```

3g. Remplacer :

```gdscript
	quitter()
	places = clampi(places, EtatPartie.NB_JOUEURS_MIN, EtatPartie.NB_JOUEURS_MAX)
```

par :

```gdscript
	quitter()
	_clore_partants()  # une session hébergée qui part encore tient son port : le libérer d'abord
	places = clampi(places, EtatPartie.NB_JOUEURS_MIN, EtatPartie.NB_JOUEURS_MAX)
```

3h. Remplacer :

```gdscript
	return OK


## Quitte le réseau : ferme le pair (les autres postes voient partir ce joueur, ou l'hôte), remet
## `OfflineMultiplayerPeer` et oublie inscrits, table du salon, index, couleur et manche en cours
## (une session hébergée finie n'a plus lieu d'être). Sans effet visible hors réseau : chaque chemin
## de retour au titre peut l'appeler (point de vigilance des phases 12/13).
func quitter() -> void:
	_generation += 1
	_delai.stop()
	var pair := multiplayer.multiplayer_peer
	if pair != null and not (pair is OfflineMultiplayerPeer):
		pair.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_api().auth_callback = Callable()
```

par :

```gdscript
	return OK


## Quitte le réseau : part proprement (les autres postes voient partir ce joueur, ou l'hôte : voir
## `_partir`), remet `OfflineMultiplayerPeer` et oublie inscrits, table du salon, index, couleur,
## scènes chargées et manche en cours (une session hébergée finie n'a plus lieu d'être). Sans effet
## visible hors réseau : chaque chemin de retour au titre peut l'appeler (point de vigilance des
## phases 12/13).
func quitter() -> void:
	_generation += 1
	_delai.stop()
	var pair := multiplayer.multiplayer_peer
	if pair is ENetMultiplayerPeer:
		_partir(pair)
	elif pair != null and not (pair is OfflineMultiplayerPeer):
		pair.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_api().auth_callback = Callable()
```

3i. Remplacer :

```gdscript
	table_salon.clear()
	niveau_salon = 0
```

par :

```gdscript
	table_salon.clear()
	scenes_chargees.clear()
	silence = SILENCE_SESSION
	niveau_salon = 0
```

3j. Remplacer :

```gdscript
	couleur_locale = Color.TRANSPARENT
	manche_en_cours = false
	_issue_decidee = false


## Vrai si ce poste est en réseau (hôte ou client), faux hors réseau (solo).
```

par :

```gdscript
	couleur_locale = Color.TRANSPARENT
	manche_en_cours = false
	_issue_decidee = false


## Départ volontaire d'une session ENet (M6) : chaque autre poste connecté reçoit un DISCONNECT fiable,
## envoyé tout de suite, puis renvoyé par `_process` jusqu'à son accusé de réception (DELAI_DEPART au
## plus) ; la session est alors fermée. `close()` seul n'envoie qu'un datagramme non fiable : perdu
## en Wi-Fi, le départ ne serait vu qu'au bout du silence de l'autre poste.
func _partir(pair: ENetMultiplayerPeer) -> void:
	if pair.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		pair.close()
		return
	var connexion := pair.host
	var paquets: Array = [] if connexion == null else connexion.get_peers().filter(
		func(p: ENetPacketPeer) -> bool: return p.get_state() == ENetPacketPeer.STATE_CONNECTED)
	if paquets.is_empty():
		pair.close()
		return
	for p: ENetPacketPeer in paquets:
		p.peer_disconnect()
	connexion.flush()
	_partants.append({"pair": pair, "paquets": paquets, "fin": Time.get_ticks_msec() + DELAI_DEPART})


## Sert les départs en cours ; ferme ceux qui sont reçus ou dont le délai est passé.
func _process(_delta: float) -> void:
	if _partants.is_empty():
		return
	for partant: Dictionary in _partants.duplicate():
		partant.pair.poll()
		var recus: bool = partant.paquets.all(func(p: ENetPacketPeer) -> bool: return p.get_state() == ENetPacketPeer.STATE_DISCONNECTED)
		if recus or Time.get_ticks_msec() >= partant.fin:
			partant.pair.close()
			_partants.erase(partant)


## Ferme tout de suite les départs en cours (leurs ports se libèrent).
func _clore_partants() -> void:
	for partant: Dictionary in _partants:
		partant.pair.close()
	_partants.clear()


## Pose `bornes` (SILENCE_SESSION ou SILENCE_CHARGEMENT) comme silence toléré de chaque pair connecté
## de cette session, et de chaque nouveau venu (`silence`). Hors réseau, ne fait que le retenir.
func definir_silence(bornes: Vector2i) -> void:
	silence = bornes
	var pair := multiplayer.multiplayer_peer
	if pair is ENetMultiplayerPeer and pair.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED \
			and pair.host != null:
		for p: ENetPacketPeer in pair.host.get_peers():
			if p.get_state() == ENetPacketPeer.STATE_CONNECTED:
				p.set_timeout(ESSAIS_SILENCE, bornes.x, bornes.y)


## La scène de jeu de ce poste est chargée (appelé par la manche, chez chaque joueur) : chez l'hôte,
## noté tout de suite ; un client le fait savoir à l'hôte.
func signaler_scene_chargee() -> void:
	if multiplayer.is_server():
		_noter_scene_chargee(multiplayer.get_unique_id())
	else:
		_scene_chargee.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


func _noter_scene_chargee(id: int) -> void:
	if not scenes_chargees.has(id):
		scenes_chargees.append(id)
		scene_chargee.emit(id)


## Vrai si ce poste est en réseau (hôte ou client), faux hors réseau (solo).
```

3k. Remplacer :

```gdscript
## non prêt dans la même image que l'appui, alors que le bouton n'était pas encore regrisé).
func lancer_manche() -> bool:
	if not multiplayer.is_server() or manche_en_cours or not salon_pret(inscrits):
		return false
	manche_en_cours = true
	compacter_index(inscrits)
```

par :

```gdscript
## non prêt dans la même image que l'appui, alors que le bouton n'était pas encore regrisé).
##
## M1 : les fiches de la manche sont aussi revérifiées avant tout engagement (défense en profondeur) :
## une table que `fiches_de_manche` refuse, une fois les index compactés (l'hôte n'y serait plus,
## par exemple), fait refuser le lancement, sans rien changer. Le chargement commence : le silence
## toléré devient SILENCE_CHARGEMENT, et plus aucune scène n'est chargée.
func lancer_manche() -> bool:
	if not multiplayer.is_server() or manche_en_cours or not salon_pret(inscrits):
		return false
	var essai: Dictionary[int, Dictionary] = inscrits.duplicate(true)
	compacter_index(essai)
	if fiches_de_manche(table_de(essai), multiplayer.get_unique_id()).is_empty():
		push_error("Reseau.lancer_manche : fiches de la manche incohérentes, lancement refusé")
		return false
	manche_en_cours = true
	scenes_chargees.clear()
	definir_silence(SILENCE_CHARGEMENT)
	compacter_index(inscrits)
```

3l. Remplacer :

```gdscript
	salon_change.emit()


## Chez un client : l'hôte lance la manche, sur la table compactée reçue juste avant.
@rpc("authority", "call_remote", "reliable")
func _recevoir_manche() -> void:
	var fiches := fiches_de_manche(table_salon, multiplayer.get_unique_id())
```

par :

```gdscript
	salon_change.emit()


## Chez un client : l'hôte lance la manche, sur la table compactée reçue juste avant. Le chargement
## commence : silence toléré SILENCE_CHARGEMENT.
@rpc("authority", "call_remote", "reliable")
func _recevoir_manche() -> void:
	var fiches := fiches_de_manche(table_salon, multiplayer.get_unique_id())
```

3m. Remplacer :

```gdscript
		push_warning("Reseau : lancement de manche sur une table illisible, ignoré")
		return
	manche_en_cours = true
	manche_lancee.emit(fiches)


func _api() -> SceneMultiplayer:
```

par :

```gdscript
		push_warning("Reseau : lancement de manche sur une table illisible, ignoré")
		return
	manche_en_cours = true
	definir_silence(SILENCE_CHARGEMENT)
	manche_lancee.emit(fiches)


## Chez l'hôte : la scène de jeu d'un joueur de la manche est chargée (barrière avant l'intro).
@rpc("any_peer", "call_remote", "reliable")
func _scene_chargee() -> void:
	var id := multiplayer.get_remote_sender_id()
	if multiplayer.is_server() and manche_en_cours and inscrits.has(id):
		_noter_scene_chargee(id)


func _api() -> SceneMultiplayer:
```

3n. Remplacer :

```gdscript
	if multiplayer.is_server() and inscrits.has(id):
		inscrits[id].arrive = true
```

par :

```gdscript
	if multiplayer.is_server() and inscrits.has(id):
		definir_silence(silence)  # le nouveau venu aussi
		inscrits[id].arrive = true
```

3o. Remplacer :

```gdscript
	_delai.stop()
	inscrit.emit(index_local, couleur_locale)
```

par :

```gdscript
	_delai.stop()
	definir_silence(silence)
	inscrit.emit(index_local, couleur_locale)
```

Dans `project.godot` :

3p. Remplacer :

```ini
config/name="LeLion"
config/version="0.13"
run/main_scene="res://Scenes/Titre.tscn"
```

par :

```ini
config/name="LeLion"
config/version="0.14"
run/main_scene="res://Scenes/Titre.tscn"
```

Le relais du serveur coupé, un client ne voit plus les autres clients parmi ses pairs (mesuré avant ce bloc : `❌ un autre client est en vue (pairs : [1])` au scénario 1) :

Dans `tests/reseau/joueur.gd` :

3q. Remplacer :

```gdscript
##   --version=x.y (se présente avec cette version au lieu de la sienne), --partir (une fois inscrit
##   et un autre client en vue, quitte de lui-même ; sinon, attend que l'hôte parte), --feu=chemin
##   (écrit « ATTEND LE FEU » puis ne rejoint l'hôte qu'une fois ce fichier créé par lancer.sh,
```

par :

```gdscript
##   --version=x.y (se présente avec cette version au lieu de la sienne), --partir (une fois inscrit
##   et un autre client en vue dans la table de l'hôte, quitte de lui-même ; sinon, attend que
##   l'hôte parte), --feu=chemin
##   (écrit « ATTEND LE FEU » puis ne rejoint l'hôte qu'une fois ce fichier créé par lancer.sh,
```

3r. Remplacer :

```gdscript
			if _options.has("partir"):
				_check(await _attendre(func() -> bool: return root.multiplayer.get_peers().size() >= 2),
					"un autre client est en vue (pairs : %s)" % [root.multiplayer.get_peers()])
				await _pause(0.5)
```

par :

```gdscript
			if _options.has("partir"):
				# Sans relais du serveur (phase 14, M5), un client ne voit que l'hôte parmi ses pairs :
				# l'autre client est vu dans la table que l'hôte diffuse (hôte et deux clients).
				_check(await _attendre(func() -> bool: return reseau.table_salon.size() >= 3),
					"un autre client est en vue dans la table de l'hôte (%d joueurs)" % reseau.table_salon.size())
				await _pause(0.5)
```

- [ ] **Step 4 : le test passe**

Run : la commande des Global Constraints avec `T=tests/unitaires.gd`, puis `T=tests/smoke_test.gd`, puis `timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $?"; grep -E "❌|✅|== " "$TMPDIR/r.log"`.
Expected (mesuré) : `code 0`, `== 0 échec(s) ==` partout ; 12 lignes ✅ sous « -- Réseau de la manche (relais, lancement revérifié, silences, scènes chargées, départ) » et une seule ligne `ERROR: Reseau.lancer_manche : fiches de la manche incohérentes, lancement refusé` (voulue) ; le test réseau, 7 lignes ✅, en 31 s environ.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Reseau.gd project.godot tests/reseau/joueur.gd tests/unitaires.gd
git commit -m "Reseau : relais du serveur coupé (M5), départ propre par un DISCONNECT fiable renvoyé jusqu'à son accusé de réception et silences d'ENet réglés, tolérants pendant le chargement (M6), barrière de chargement (scènes chargées), lancement qui revérifie ses fiches (M1) ; version 0.14 ; test réseau : l'autre client se lit dans la table ; tests unitaires

<ligne fournie par l'environnement>"
```

---

### Task 5 : ennemis, pastilles et Spawner : chez l'hôte seulement, répliqués chez les clients

**Files:**
- Modify: `Scripts/Ennemi.gd` (docstring, `est_replique`), `Scripts/Soucoupe.gd`, `Scripts/Coccinelle.gd`, `Scripts/Boss.gd` (gardes, `cote` et son setter), `Scripts/Spawner.gd` (docstring, `demarrer`, noms lisibles)
- Modify: `Scenes/Soucoupe.tscn`, `Scenes/Coccinelle.tscn`, `Scenes/Boss.tscn`, `Scenes/ColorPickup.tscn`, `Scenes/BonusPickup.tscn`, `Scenes/CoeurPickup.tscn` (un `MultiplayerSynchronizer` « Synchro » et sa configuration)
- Modify: `Scripts/Main.gd` (`_ready` : `$Spawner.demarrer()`)
- Test: `tests/smoke_test.gd` (apparitions du solo, bases communes, sous-arbre client)

**Interfaces:**
- Consumes : phase 14 bis (`Pastille._expirer`) ; `multiplayer.is_server()`.
- Produces (Task 7) : `func Ennemi.est_replique() -> bool` ; `Boss.cote` (setter : `_appliquer_cote()` une fois prêt) ; `func Spawner.demarrer()` (une fois, sur l'hôte seulement ; `_ready` n'apparaît plus rien) ; `var Spawner._demarre` ; apparitions ajoutées par `add_child(noeud, true)` ; configurations `Synchro` : soucoupe `.:position` (apparition, continu), coccinelle `.:position` et `.:rotation` (continu), peintre `.:position` (continu) et `.:cote` (à chaque changement), pastille de couleur `.:position` et `.:couleur_index`, étoile et cœur `.:position` (à l'apparition seulement) ; `replication_interval` 0,012 s pour les ennemis.

- [ ] **Step 1 : le test**

Dans `tests/smoke_test.gd` :

1a. Remplacer :

```gdscript
	_check(soucoupe.speed >= spawner.vitesse_soucoupe.x, "la soucoupe reçoit sa vitesse du spawner (%.0f)" % soucoupe.speed)
	soucoupe.queue_free()
	Input.action_release("vomir")
```

par :

```gdscript
	_check(soucoupe.speed >= spawner.vitesse_soucoupe.x, "la soucoupe reçoit sa vitesse du spawner (%.0f)" % soucoupe.speed)
	var soucoupe_bis: Node = spawner.spawn_soucoupe(40)
	_check(not str(soucoupe.name).contains("@") and not str(soucoupe_bis.name).contains("@") and soucoupe.name != soucoupe_bis.name,
		"deux apparitions de la même scène ont des noms lisibles et distincts, que le MultiplayerSpawner peut répliquer (%s, %s)" % [soucoupe.name, soucoupe_bis.name])
	soucoupe.queue_free()
	soucoupe_bis.queue_free()
	Input.action_release("vomir")
```

1b. Remplacer :

```gdscript
		"pastille de couleur, étoile et cœur dérivent de la base Pastille (%s)" % [bases_pastilles])
	# L'intrus a un champ `joueur`, comme un lion : sous l'ancien typage (groupe « lion » puis
```

par :

```gdscript
		"pastille de couleur, étoile et cœur dérivent de la base Pastille (%s)" % [bases_pastilles])
	# Phase 14 : chaque ennemi et chaque pastille porte son MultiplayerSynchronizer (`Synchro`) : position
	# à l'apparition (et ensuite pour les ennemis, qui bougent chez l'hôte), couleur d'une pastille, côté
	# du peintre, inclinaison de la coccinelle.
	var attendues := {
		"Soucoupe": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS]],
		"Coccinelle": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS], [^".:rotation", SceneReplicationConfig.REPLICATION_MODE_ALWAYS]],
		"Boss": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS], [^".:cote", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE]],
		"ColorPickup": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_NEVER], [^".:couleur_index", SceneReplicationConfig.REPLICATION_MODE_NEVER]],
		"BonusPickup": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_NEVER]],
		"CoeurPickup": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_NEVER]],
	}
	for nom: String in attendues:
		var instance: Node = load("res://Scenes/%s.tscn" % nom).instantiate()
		var synchro := instance.get_node_or_null("Synchro") as MultiplayerSynchronizer
		var config: SceneReplicationConfig = null if synchro == null else synchro.replication_config
		var conforme: bool = config != null and config.get_properties().size() == attendues[nom].size()
		for attendue: Array in attendues[nom]:
			conforme = conforme and config.has_property(attendue[0]) and config.property_get_spawn(attendue[0]) \
				and config.property_get_replication_mode(attendue[0]) == attendue[1]
		_check(conforme, "%s : son Synchro réplique %s à l'apparition" % [nom, attendues[nom].map(func(a: Array) -> String: return str(a[0]))])
		instance.free()
	# L'intrus a un champ `joueur`, comme un lion : sous l'ancien typage (groupe « lion » puis
```

1c. Remplacer :

```gdscript
		"sur un client, une étoile en fin de vie ne se libère pas d'elle-même (l'hôte la fait disparaître)")
	set_multiplayer(null, poste_client.get_path())
```

par :

```gdscript
		"sur un client, une étoile en fin de vie ne se libère pas d'elle-même (l'hôte la fait disparaître)")
	# Phase 14 : sur un client, ennemis et Spawner sont inertes : des répliques de ceux de l'hôte, que
	# seul leur Synchro déplace
	var soucoupe_client: Node2D = load("res://Scenes/Soucoupe.tscn").instantiate()
	soucoupe_client.position = Vector2(300, 100)
	poste_client.add_child(soucoupe_client)
	var coccinelle_repl: Node2D = load("res://Scenes/Coccinelle.tscn").instantiate()
	coccinelle_repl.position = Vector2(900, 100)
	poste_client.add_child(coccinelle_repl)
	var boss_client: Node2D = load("res://Scenes/Boss.tscn").instantiate()
	boss_client.cote = -1  # comme l'état d'apparition reçu de l'hôte, posé avant `_ready`
	boss_client.position = Vector2(1000, 300)
	poste_client.add_child(boss_client)
	var spawner_client: Node = load("res://Scripts/Spawner.gd").new()
	poste_client.add_child(spawner_client)
	var enfants_client := poste_client.get_child_count()
	spawner_client.demarrer()
	await _frames(5)
	_check(GS.pret and soucoupe_client.position == Vector2(300, 100) and coccinelle_repl.position == Vector2(900, 100)
		and coccinelle_repl.speed == 0.0 and boss_client.position == Vector2(1000, 300) and boss_client._tween == null,
		"sur un client, un ennemi ne bouge pas de lui-même, ne tire rien au hasard et le peintre ne lance aucun tween")
	_check(boss_client.sprite.scale.x < 0.0 and boss_client.cote == -1, "sur un client, le peintre regarde du côté reçu de l'hôte (sprite en miroir)")
	_check(not spawner_client._demarre and spawner_client._timer_soucoupe == null and poste_client.get_child_count() == enfants_client,
		"sur un client, le Spawner ne fait rien apparaître (tout vient de l'hôte)")
	# Chaque nœud synchronisé quitte le sous-arbre avant que son pair ne change (sinon l'API du client
	# le suivrait encore).
	for noeud: Node in [soucoupe_client, coccinelle_repl, boss_client, spawner_client, pastille_client, etoile_client]:
		noeud.free()
	set_multiplayer(null, poste_client.get_path())
```

- [ ] **Step 2 : le test échoue**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`.
Expected (mesuré) : `❌ deux apparitions de la même scène ont des noms lisibles et distincts … (Soucoupe, @Area2D@…)`, les six `❌ … : son Synchro réplique … à l'apparition`, puis `SCRIPT ERROR: Invalid call. Nonexistent function 'demarrer' in base 'Node (Spawner.gd)'.`, qui arrête le smoke test sans quitter (`code 124` au `timeout` ; lancer ce passage avec `timeout -k 5 60`).

- [ ] **Step 3 : les ennemis, les scènes, le Spawner**

Dans `Scripts/Ennemi.gd` :

3a. Remplacer :

```gdscript
## contact n'est tranché que par l'hôte (en solo, le poste est son propre hôte), ne compte que
## pour un lion (`body is Lion`) et part de `origine_du_coup`, que chaque ennemi peut redéfinir.
## Ce sont les règles qui en décident l'effet : un coup en solo, un étourdissement en bataille.


## Branché sur `body_entered` dans la scène de chaque ennemi.
```

par :

```gdscript
## contact n'est tranché que par l'hôte (en solo, le poste est son propre hôte), ne compte que
## pour un lion (`body is Lion`) et part de `origine_du_coup`, que chaque ennemi peut redéfinir.
## Ce sont les règles qui en décident l'effet : un coup en solo, un étourdissement en bataille.
## Sur un client, un ennemi n'est qu'une réplique de celui de l'hôte (`est_replique`).


## Branché sur `body_entered` dans la scène de chaque ennemi.
```

3b. Remplacer :

```gdscript
		_signaler_si_lion(body)


## Point d'où part le coup, pour le recul du lion : par défaut, la position de l'ennemi.
func origine_du_coup(_lion: Lion) -> Vector2:
	return global_position
```

par :

```gdscript
		_signaler_si_lion(body)


## Vrai sur un client : l'ennemi n'est qu'une réplique de celui de l'hôte, apparu par le
## `MultiplayerSpawner` de la scène de jeu, dont le `MultiplayerSynchronizer` de sa scène (`Synchro`)
## recopie la position. Il ne bouge pas de lui-même, ne tire rien au hasard, ne lance aucun tween et
## ne se libère pas (l'hôte le fait disparaître chez tous). Chaque ennemi commence son `_ready` et son
## `_physics_process` par cette garde : en Godot 4, ceux d'une sous-classe n'appellent pas ceux de la
## base.
func est_replique() -> bool:
	return not multiplayer.is_server()


## Point d'où part le coup, pour le recul du lion : par défaut, la position de l'ennemi.
func origine_du_coup(_lion: Lion) -> Vector2:
	return global_position
```

Dans `Scripts/Soucoupe.gd` :

3c. Remplacer :

```gdscript
func _physics_process(delta: float) -> void:
	position.x += speed * delta
```

par :

```gdscript
func _physics_process(delta: float) -> void:
	if est_replique():
		return
	position.x += speed * delta
```

Dans `Scripts/Coccinelle.gd` :

3d. Remplacer :

```gdscript
func _ready() -> void:
	start_y = position.y
```

par :

```gdscript
func _ready() -> void:
	if est_replique():
		return
	start_y = position.y
```

3e. Remplacer :

```gdscript
func _physics_process(delta: float) -> void:
	time += delta
```

par :

```gdscript
func _physics_process(delta: float) -> void:
	if est_replique():
		return
	time += delta
```

Dans `Scripts/Boss.gd` :

3f. Remplacer :

```gdscript
var etat := Etat.REPOS
var cote := 1                            # 1 = entre par la gauche, -1 = par la droite
var y_sol := 468.0                       # y du haut de la skyline (bas du boss)
```

par :

```gdscript
var etat := Etat.REPOS
## 1 = entre par la gauche, -1 = par la droite. Répliqué chez les clients (`Synchro`) : le peintre y
## regarde vers le centre comme chez l'hôte.
var cote := 1:
	set(valeur):
		cote = valeur
		if is_node_ready():
			_appliquer_cote()
var y_sol := 468.0                       # y du haut de la skyline (bas du boss)
```

3g. Remplacer :

```gdscript
	_generer_collision(echelle)

	cote = 1 if randf() < 0.5 else -1
	_appliquer_cote()
	position = Vector2(_x_hors_ecran(), y_sol - _demi_hauteur)
```

par :

```gdscript
	_generer_collision(echelle)
	_appliquer_cote()  # sur un client : le côté de l'hôte, reçu à l'apparition
	if est_replique():
		return

	cote = 1 if randf() < 0.5 else -1
	position = Vector2(_x_hors_ecran(), y_sol - _demi_hauteur)
```

3h. Remplacer :

```gdscript
func _physics_process(delta: float) -> void:
	if etat == Etat.ANNONCE:
```

par :

```gdscript
func _physics_process(delta: float) -> void:
	if est_replique():
		return
	if etat == Etat.ANNONCE:
```

3i. Remplacer :

```gdscript
func _changer_cote_et_reposer() -> void:
	cote = -cote
	_appliquer_cote()
	_changer_etat(Etat.REPOS)
```

par :

```gdscript
func _changer_cote_et_reposer() -> void:
	cote = -cote  # le setter retourne le sprite et la collision
	_changer_etat(Etat.REPOS)
```

Dans `Scripts/Spawner.gd` :

3j. Remplacer :

```gdscript
## étoile, cœurs) est décidé par les règles de la partie ; les hauteurs d'apparition, réglées pour
## l'écran du solo, suivent la hauteur de l'écran. La difficulté (0 → 1) suit l'avancement de la
## partie (`Regles.avancement`) et le temps écoulé.

@export var color_pickup_scene: PackedScene = preload("res://Scenes/ColorPickup.tscn")
```

par :

```gdscript
## étoile, cœurs) est décidé par les règles de la partie ; les hauteurs d'apparition, réglées pour
## l'écran du solo, suivent la hauteur de l'écran. La difficulté (0 → 1) suit l'avancement de la
## partie (`Regles.avancement`) et le temps écoulé. Il ne tourne que sur l'hôte, à partir de
## `demarrer()` (appelé par la scène de jeu) : en réseau, ennemis et pastilles apparaissent chez
## l'hôte, et le `MultiplayerSpawner` de la scène de jeu les fait apparaître chez chaque client
## (d'où des noms lisibles, `add_child(..., true)` : un nom réservé « @… » ne s'y réplique pas).

@export var color_pickup_scene: PackedScene = preload("res://Scenes/ColorPickup.tscn")
```

3k. Remplacer :

```gdscript
var _facteur_ennemis := 1.0


func _ready() -> void:
	GameState.partie_terminee.connect(_on_partie_terminee)
	if GameState.niveau().get("boss", false):
```

par :

```gdscript
var _facteur_ennemis := 1.0
var _demarre := false


func _ready() -> void:
	GameState.partie_terminee.connect(_on_partie_terminee)


## Les apparitions commencent : le peintre s'il y en a un, puis, à la fin de l'intro, les pastilles,
## les étoiles, les cœurs et les ennemis. Appelé par la scène de jeu : dans son `_ready` hors réseau,
## après la barrière de chargement chez l'hôte d'une manche en réseau (la manche, phase 14). Sans
## effet sur un client (ses ennemis et ses pastilles sont les répliques de ceux de l'hôte) et au
## second appel.
func demarrer() -> void:
	if _demarre or not multiplayer.is_server():
		return
	_demarre = true
	if GameState.niveau().get("boss", false):
```

3l. Remplacer :

```gdscript
	coeur.global_position = position_coeur
	get_parent().add_child(coeur)
	return coeur
```

par :

```gdscript
	coeur.global_position = position_coeur
	get_parent().add_child(coeur, true)
	return coeur
```

3m. Remplacer :

```gdscript
	bonus.global_position = position_bonus
	get_parent().add_child(bonus)
	return bonus
```

par :

```gdscript
	bonus.global_position = position_bonus
	get_parent().add_child(bonus, true)
	return bonus
```

3n. Remplacer :

```gdscript
	var ville: Node2D = get_tree().get_first_node_in_group("ville")
	if ville != null:
		boss.y_sol = ville.position.y - ville.tex_size.y / 2.0
	get_parent().add_child(boss)


func spawn_pickup(index: int, position_pickup: Vector2) -> Node:
```

par :

```gdscript
	var ville: Node2D = get_tree().get_first_node_in_group("ville")
	if ville != null:
		boss.y_sol = ville.position.y - ville.tex_size.y / 2.0
	get_parent().add_child(boss, true)


func spawn_pickup(index: int, position_pickup: Vector2) -> Node:
```

3o. Remplacer :

```gdscript
	pickup.tree_exited.connect(_on_pastille_partie)
	get_parent().add_child(pickup)
	return pickup
```

par :

```gdscript
	pickup.tree_exited.connect(_on_pastille_partie)
	get_parent().add_child(pickup, true)
	return pickup
```

3p. Remplacer :

```gdscript
	soucoupe.speed = lerp(vitesse_soucoupe.x, vitesse_soucoupe.y, difficulte())
	get_parent().add_child(soucoupe)
	return soucoupe
```

par :

```gdscript
	soucoupe.speed = lerp(vitesse_soucoupe.x, vitesse_soucoupe.y, difficulte())
	get_parent().add_child(soucoupe, true)
	return soucoupe
```

3q. Remplacer :

```gdscript
	c.position = Vector2(largeur + 100, y_depart)
	get_parent().add_child(c)
	return c
```

par :

```gdscript
	c.position = Vector2(largeur + 100, y_depart)
	get_parent().add_child(c, true)
	return c
```

Dans `Scripts/Main.gd` :

3r. Remplacer :

```gdscript
	_ajouter_lions()
	if GameState.demo:
```

par :

```gdscript
	_ajouter_lions()
	$Spawner.demarrer()
	if GameState.demo:
```

Dans `Scenes/Soucoupe.tscn` :

3s. Remplacer :

```ini
[gd_scene load_steps=4 format=3 uid="uid://b4bdndd8cklie"]

[ext_resource type="Script" uid="uid://d2qwthjie01pd" path="res://Scripts/Soucoupe.gd" id="1_2newh"]
```

par :

```ini
[gd_scene load_steps=5 format=3 uid="uid://b4bdndd8cklie"]

[ext_resource type="Script" uid="uid://d2qwthjie01pd" path="res://Scripts/Soucoupe.gd" id="1_2newh"]
```

3t. Remplacer :

```ini
radius = 23.0
height = 112.0

[node name="Soucoupe" type="Area2D" groups=["ennemi"]]
```

par :

```ini
radius = 23.0
height = 112.0

[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_synchro"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1

[node name="Soucoupe" type="Area2D" groups=["ennemi"]]
```

3u. Remplacer :

```ini
shape = SubResource("CapsuleShape2D_2newh")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]

```

par :

```ini
shape = SubResource("CapsuleShape2D_2newh")

[node name="Synchro" type="MultiplayerSynchronizer" parent="."]
replication_interval = 0.012
replication_config = SubResource("SceneReplicationConfig_synchro")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]

```

Dans `Scenes/Coccinelle.tscn` :

3v. Remplacer :

```ini
[gd_scene load_steps=4 format=3 uid="uid://c4c5pimuankut"]

[ext_resource type="Script" uid="uid://cv3w5av71kifg" path="res://Scripts/Coccinelle.gd" id="1_dwabj"]
```

par :

```ini
[gd_scene load_steps=5 format=3 uid="uid://c4c5pimuankut"]

[ext_resource type="Script" uid="uid://cv3w5av71kifg" path="res://Scripts/Coccinelle.gd" id="1_dwabj"]
```

3w. Remplacer :

```ini
radius = 44.0
height = 110.0

[node name="Coccinelle" type="Area2D" groups=["ennemi"]]
```

par :

```ini
radius = 44.0
height = 110.0

[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_synchro"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:rotation")
properties/1/spawn = true
properties/1/replication_mode = 1

[node name="Coccinelle" type="Area2D" groups=["ennemi"]]
```

3x. Remplacer :

```ini
shape = SubResource("CapsuleShape2D_lltc3")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]

```

par :

```ini
shape = SubResource("CapsuleShape2D_lltc3")

[node name="Synchro" type="MultiplayerSynchronizer" parent="."]
replication_interval = 0.012
replication_config = SubResource("SceneReplicationConfig_synchro")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]

```

Dans `Scenes/Boss.tscn` :

3y. Remplacer :

```ini
[gd_scene load_steps=3 format=3 uid="uid://dlelionboss00"]

[ext_resource type="Texture2D" path="res://Assets/Sprites/boss_peintre.svg" id="1_boss"]
[ext_resource type="Script" path="res://Scripts/Boss.gd" id="2_boss"]

[node name="Boss" type="Area2D" groups=["boss"]]
```

par :

```ini
[gd_scene load_steps=4 format=3 uid="uid://dlelionboss00"]

[ext_resource type="Texture2D" path="res://Assets/Sprites/boss_peintre.svg" id="1_boss"]
[ext_resource type="Script" path="res://Scripts/Boss.gd" id="2_boss"]

[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_synchro"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:cote")
properties/1/spawn = true
properties/1/replication_mode = 2

[node name="Boss" type="Area2D" groups=["boss"]]
```

3z. Remplacer :

```ini
texture = ExtResource("1_boss")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]

```

par :

```ini
texture = ExtResource("1_boss")

[node name="Synchro" type="MultiplayerSynchronizer" parent="."]
replication_interval = 0.012
replication_config = SubResource("SceneReplicationConfig_synchro")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]

```

Dans `Scenes/ColorPickup.tscn` :

3aa. Remplacer :

```ini
[gd_scene load_steps=4 format=3 uid="uid://ccpm7pmwv1le5"]

[ext_resource type="Texture2D" uid="uid://c5nevupbjsrl0" path="res://Assets/Sprites/circle_white.png" id="1_ejic6"]
```

par :

```ini
[gd_scene load_steps=5 format=3 uid="uid://ccpm7pmwv1le5"]

[ext_resource type="Texture2D" uid="uid://c5nevupbjsrl0" path="res://Assets/Sprites/circle_white.png" id="1_ejic6"]
```

3ab. Remplacer :

```ini
[sub_resource type="CircleShape2D" id="CircleShape2D_gk2im"]
radius = 28.0

[node name="ColorPickup" type="Area2D" groups=["pickup"]]
```

par :

```ini
[sub_resource type="CircleShape2D" id="CircleShape2D_gk2im"]
radius = 28.0

[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_synchro"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 0
properties/1/path = NodePath(".:couleur_index")
properties/1/spawn = true
properties/1/replication_mode = 0

[node name="ColorPickup" type="Area2D" groups=["pickup"]]
```

3ac. Remplacer :

```ini
shape = SubResource("CircleShape2D_gk2im")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]

```

par :

```ini
shape = SubResource("CircleShape2D_gk2im")

[node name="Synchro" type="MultiplayerSynchronizer" parent="."]
replication_config = SubResource("SceneReplicationConfig_synchro")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]

```

Dans `Scenes/BonusPickup.tscn` :

3ad. Remplacer :

```ini
[gd_scene load_steps=4 format=3 uid="uid://dlelionbonus0"]

[ext_resource type="Texture2D" path="res://Assets/Sprites/etoile.png" id="1_etoile"]
```

par :

```ini
[gd_scene load_steps=5 format=3 uid="uid://dlelionbonus0"]

[ext_resource type="Texture2D" path="res://Assets/Sprites/etoile.png" id="1_etoile"]
```

3ae. Remplacer :

```ini
[sub_resource type="CircleShape2D" id="CircleShape2D_bonus"]
radius = 34.0

[node name="BonusPickup" type="Area2D"]
```

par :

```ini
[sub_resource type="CircleShape2D" id="CircleShape2D_bonus"]
radius = 34.0

[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_synchro"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 0

[node name="BonusPickup" type="Area2D"]
```

3af. Remplacer :

```ini
shape = SubResource("CircleShape2D_bonus")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]

```

par :

```ini
shape = SubResource("CircleShape2D_bonus")

[node name="Synchro" type="MultiplayerSynchronizer" parent="."]
replication_config = SubResource("SceneReplicationConfig_synchro")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]

```

Dans `Scenes/CoeurPickup.tscn` :

3ag. Remplacer :

```ini
[gd_scene load_steps=4 format=3 uid="uid://dlelioncoeur0"]

[ext_resource type="Texture2D" path="res://Assets/Sprites/coeur.png" id="1_coeur"]
```

par :

```ini
[gd_scene load_steps=5 format=3 uid="uid://dlelioncoeur0"]

[ext_resource type="Texture2D" path="res://Assets/Sprites/coeur.png" id="1_coeur"]
```

3ah. Remplacer :

```ini
[sub_resource type="CircleShape2D" id="CircleShape2D_coeur"]
radius = 30.0

[node name="CoeurPickup" type="Area2D" groups=["coeur_pickup"]]
```

par :

```ini
[sub_resource type="CircleShape2D" id="CircleShape2D_coeur"]
radius = 30.0

[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_synchro"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 0

[node name="CoeurPickup" type="Area2D" groups=["coeur_pickup"]]
```

3ai. Remplacer :

```ini
shape = SubResource("CircleShape2D_coeur")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]

```

par :

```ini
shape = SubResource("CircleShape2D_coeur")

[node name="Synchro" type="MultiplayerSynchronizer" parent="."]
replication_config = SubResource("SceneReplicationConfig_synchro")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]

```

Sur un client, la réplique d'une étoile ou d'un cœur garde son fondu (visuel) mais ne se libère pas (`Pastille._expirer`, phase 14 bis) : l'hôte la fait disparaître chez tous.

- [ ] **Step 4 : le test passe**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`, puis `T=tests/bataille_test.gd; O="--fixed-fps 60"` (apparitions et peintre de la bataille locale par `Spawner.demarrer()`).
Expected (mesuré) : `code 0`, `== 0 échec(s) ==` pour les deux, dont les six « … : son Synchro réplique … à l'apparition », « deux apparitions de la même scène ont des noms lisibles et distincts … (Soucoupe, Soucoupe2) », « sur un client, un ennemi ne bouge pas de lui-même, ne tire rien au hasard et le peintre ne lance aucun tween », « sur un client, le peintre regarde du côté reçu de l'hôte », « sur un client, le Spawner ne fait rien apparaître », et aucune ligne `ERROR: Attempt to disconnect a nonexistent connection` ni `Condition "!sync"` (chaque nœud synchronisé quitte le sous-arbre client avant que son pair ne change).

- [ ] **Step 5 : Commit, puis le test discrimine**

```bash
git add Scripts/Ennemi.gd Scripts/Soucoupe.gd Scripts/Coccinelle.gd Scripts/Boss.gd Scripts/Spawner.gd Scripts/Main.gd Scenes/Soucoupe.tscn Scenes/Coccinelle.tscn Scenes/Boss.tscn Scenes/ColorPickup.tscn Scenes/BonusPickup.tscn Scenes/CoeurPickup.tscn tests/smoke_test.gd
git commit -m "Ennemis et pastilles : un Synchro par scène (position, côté du peintre, inclinaison de la coccinelle, couleur d'une pastille), répliques inertes sur un client (Ennemi.est_replique) ; Spawner : sur l'hôte seulement, à partir de demarrer(), noms lisibles pour le MultiplayerSpawner ; smoke test

<ligne fournie par l'environnement>"
```

Puis chaque mutation seule, `T=tests/smoke_test.gd`, et **`git checkout -- Scripts/`** avant la suivante (mesuré) :
- E1 : dans `Coccinelle._ready`, supprimer les deux lignes `if est_replique():` / `return` ⇒ `❌ sur un client, un ennemi ne bouge pas de lui-même, ne tire rien au hasard et le peintre ne lance aucun tween` ;
- E2 : dans `Boss._ready`, supprimer les deux lignes `if est_replique():` / `return` ⇒ le même `❌` (le tween du repos part) ;
- E3 : dans `Boss._ready`, supprimer la ligne `_appliquer_cote()  # sur un client : le côté de l'hôte, reçu à l'apparition` ⇒ `❌ sur un client, le peintre regarde du côté reçu de l'hôte (sprite en miroir)` ;
- E4 : dans `Spawner.demarrer`, `if _demarre or not multiplayer.is_server():` → `if _demarre:` ⇒ `❌ sur un client, le Spawner ne fait rien apparaître (tout vient de l'hôte)`.

Expected ensuite : `git status --short` vide.

---

### Task 6 : le lion répliqué, les commandes suspendues

**Files:**
- Modify: `Scripts/Lion.gd` (docstring, `direction_du_lion` et son setter, `vomi_de_l_hote`, commentaire de `joueur` (N9), `_physics_process`, `_process`, `_suivre_l_hote`, `_veut_vomir`, docstring d'`appliquer_apparence`)
- Modify: `Scenes/Lion.tscn` (un `MultiplayerSynchronizer` « Synchro » et sa configuration)
- Modify: `Scripts/Commandes.gd` (`suspendues`)
- Test: `tests/smoke_test.gd` (section « Bataille : lions de bataille »), `tests/unitaires.gd` (`_tester_commandes`)

**Interfaces:**
- Consumes : Task 3 (`Joueur.recevoir_fin_etourdissement`) ; `multiplayer.is_server()`.
- Produces (Task 7) : `Lion.direction_du_lion` (setter qui réoriente le lion une fois prêt), `var Lion.vomi_de_l_hote := false` (écrit par l'hôte à chaque `_process`), `func Lion._suivre_l_hote(delta)` ; le `Synchro` du lion : `.:position`, `.:velocity` (continu), `.:direction_du_lion`, `.:vomi_de_l_hote` (à chaque changement), tous à l'apparition, `replication_interval` 0,012 s ; `var Commandes.suspendues := false`.

- [ ] **Step 1 : le test**

Dans `tests/unitaires.gd` :

1a. Remplacer :

```gdscript
	m.direction_voulue = Vector2(3, 4)
	_check(is_equal_approx(m.direction().length(), 1.0) and m.direction().is_equal_approx(Vector2(0.6, 0.8)),
		"direction() borne les commandes manuelles à une longueur de 1")


func _tester_regles_solo() -> void:
```

par :

```gdscript
	m.direction_voulue = Vector2(3, 4)
	_check(is_equal_approx(m.direction().length(), 1.0) and m.direction().is_equal_approx(Vector2(0.6, 0.8)),
		"direction() borne les commandes manuelles à une longueur de 1")
	# Phase 14 : le menu local d'une manche en réseau suspend les commandes de ce poste
	Input.action_press("deplacer_gauche")
	Input.action_press("vomir")
	m.vomir_voulu = true
	l.suspendues = true
	m.suspendues = true
	_check(l.direction() == Vector2.ZERO and not l.vomir() and m.direction() == Vector2.ZERO and not m.vomir(),
		"des commandes suspendues (menu local ouvert) valent le repos, quelle que soit leur source")
	l.suspendues = false
	m.suspendues = false
	_check(l.direction().x < -0.99 and l.vomir() and m.vomir(), "levée la suspension, elles lisent de nouveau leur source")
	Input.action_release("deplacer_gauche")
	Input.action_release("vomir")


func _tester_regles_solo() -> void:
```

Dans `tests/smoke_test.gd` :

1b. Remplacer :

```gdscript
	_check(lr.est_en_train_de_vomir, "un lion de bataille vomit dès le départ, sans pastille")
	lr.commandes.vomir_voulu = false
```

par :

```gdscript
	_check(lr.est_en_train_de_vomir, "un lion de bataille vomit dès le départ, sans pastille")
	_check(lr.vomi_de_l_hote, "sur l'hôte, l'état de vomi à répliquer suit celui du lion")
	lr.commandes.vomir_voulu = false
```

1c. Remplacer :

```gdscript
		"un lion étourdi est poussé par celui qui le percute (%.0f px)" % (lb.global_position.x - x_bleu))
	_check(distance_min > 2 * 45.0 - 15.0, "même en poussant sans relâche, un lion ne s'enfonce pas dans l'autre (distance min %.0f px)" % distance_min)

	for l in lions_bataille:
```

par :

```gdscript
		"un lion étourdi est poussé par celui qui le percute (%.0f px)" % (lb.global_position.x - x_bleu))
	_check(distance_min > 2 * 45.0 - 15.0, "même en poussant sans relâche, un lion ne s'enfonce pas dans l'autre (distance min %.0f px)" % distance_min)

	# Phase 14 : sur un client, un lion n'est qu'une réplique du lion de l'hôte (position, vitesse,
	# orientation et vomi reçus par son Synchro ; réactions par les signaux de son joueur)
	var synchro_lion := lr.get_node_or_null("Synchro") as MultiplayerSynchronizer
	var config_lion: SceneReplicationConfig = null if synchro_lion == null else synchro_lion.replication_config
	_check(config_lion != null and config_lion.get_properties() == [^".:position", ^".:velocity", ^".:direction_du_lion", ^".:vomi_de_l_hote"]
		and config_lion.property_get_replication_mode(^".:position") == SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		and config_lion.property_get_replication_mode(^".:velocity") == SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		and config_lion.property_get_replication_mode(^".:direction_du_lion") == SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		and config_lion.property_get_replication_mode(^".:vomi_de_l_hote") == SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		and config_lion.get_properties().all(func(p: NodePath) -> bool: return config_lion.property_get_spawn(p)),
		"le Synchro du lion réplique position et vitesse en continu, orientation et vomi à chaque changement, tous à l'apparition")
	var poste_lion := Node2D.new()
	poste_lion.name = "PosteClientLion"
	root.add_child(poste_lion)
	var api_lion := SceneMultiplayer.new()
	var pair_lion := ENetMultiplayerPeer.new()
	_check(pair_lion.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client pour la réplique d'un lion")
	api_lion.multiplayer_peer = pair_lion
	set_multiplayer(api_lion, poste_lion.get_path())
	var j_repl := Joueur.new()
	j_repl.couleur = EtatPartie.PALETTE_BATAILLE[3]
	j_repl.reinitialiser(3, j_repl.nuances())
	var repl: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
	repl.joueur = j_repl
	repl.commandes = Commandes.manuelles()
	repl.direction_du_lion = -1  # comme l'état d'apparition reçu de l'hôte, posé avant `_ready`
	repl.position = Vector2(600, 500)
	poste_lion.add_child(repl)
	await _frames(1)
	_check(repl.sprite.scale.x == -1.0 and repl.bouche.position.x == repl.BOUCHE_X_GAUCHE,
		"sur un client, l'orientation reçue à l'apparition est appliquée (sprite et bouche à gauche)")
	repl.commandes.direction_voulue = Vector2.RIGHT
	repl.commandes.vomir_voulu = true
	await _frames(5)
	_check(repl.position == Vector2(600, 500) and repl.velocity == Vector2.ZERO and not repl.est_en_train_de_vomir,
		"sur un client, un lion ne suit pas ses commandes : il ne bouge ni ne vomit de lui-même")
	repl.position = Vector2(700, 500)  # ce qu'écrit le Synchro
	repl.velocity = Vector2(350, 0)
	repl.direction_du_lion = 1
	repl.vomi_de_l_hote = true
	for i in range(3):
		await process_frame  # le vomi démarre dans _process
	await _frames(1)
	_check(repl.position == Vector2(700, 500) and repl.sprite.scale.x == 1.0 and repl._vitesse == Vector2(350, 0)
		and repl.est_en_train_de_vomir and repl.vomi_container.get_children().all(func(e: GPUParticles2D) -> bool: return e.emitting),
		"la réplique suit l'état reçu : position, vitesse (son animation), orientation, vomi (particules)")
	repl.vomi_de_l_hote = false
	for i in range(3):
		await process_frame
	_check(not repl.est_en_train_de_vomir, "la réplique arrête de vomir avec le lion de l'hôte")
	j_repl.etourdir(ReglesBataille.DUREE_ETOURDI_VOMI, ReglesBataille.DUREE_IMMUNITE, repl.global_position + Vector2(-50, 66), j_rouge.couleur)
	await _frames(2)
	var mat_repl := repl.sprite.material as ShaderMaterial
	_check(repl.etoiles.visible and mat_repl.get_shader_parameter("barbouillage_couleur") == j_rouge.couleur and repl.position == Vector2(700, 500),
		"un étourdissement reçu de l'hôte s'affiche sur la réplique (étoiles, barbouillage), sans la déplacer")
	j_repl.recevoir_fin_etourdissement(ReglesBataille.DUREE_IMMUNITE)
	await _frames(2)
	_check(not repl.etoiles.visible and mat_repl.get_shader_parameter("barbouillage_force") == 0.0
		and repl._clignotement != null and repl._clignotement.is_running(),
		"la fin d'étourdissement reçue efface étoiles et barbouillage, l'immunité clignote")
	repl.free()
	set_multiplayer(null, poste_lion.get_path())
	pair_lion.close()
	poste_lion.free()

	for l in lions_bataille:
```

- [ ] **Step 2 : le test échoue**

Run : la commande des Global Constraints avec `T=tests/unitaires.gd`, puis `T=tests/smoke_test.gd`.
Expected (mesuré) : unitaires : `SCRIPT ERROR: Invalid assignment of property or key 'suspendues' with value of type 'bool' on a base object of type 'RefCounted (Commandes)'.` (la fonction s'arrête ; `== 0 échec(s) ==` s'affiche quand même : c'est la `SCRIPT ERROR` qui fait l'échec) ; smoke test : `SCRIPT ERROR: Invalid access to property or key 'vomi_de_l_hote' on a base object of type 'CharacterBody2D (Lion)'.`, qui l'arrête sans quitter (`code 124` au `timeout` ; `timeout -k 5 60`).

- [ ] **Step 3 : le lion, sa scène, les commandes**

Dans `Scripts/Lion.gd` :

3a. Remplacer :

```gdscript
## Le lion ne décide de rien : sur l'hôte, il signale aux règles les autres lions que touche
## sa gerbe et ceux qu'il percute, comme le font les ennemis et les pastilles.

const ANGLE_GERBE_DEG := 45.0
```

par :

```gdscript
## Le lion ne décide de rien : sur l'hôte, il signale aux règles les autres lions que touche
## sa gerbe et ceux qu'il percute, comme le font les ennemis et les pastilles.
## En réseau (phase 14), seul l'hôte simule les lions ; sur un client, chaque lion est une réplique
## (`_suivre_l_hote`) : position, vitesse, orientation et vomi viennent de l'hôte par son
## `MultiplayerSynchronizer` (`Synchro`), ses réactions (étourdissement, crans, gerbe XXL) par les
## signaux de son joueur, que la manche lui transmet (`Joueur.recevoir_*`).

const ANGLE_GERBE_DEG := 45.0
```

3b. Remplacer :

```gdscript
var est_en_train_de_vomir := false
var direction_du_lion: int = 1  # 1 = droite, -1 = gauche
## État du lion (couleurs, bonus, coups) et source de ses intentions. À fournir avant l'ajout
## à l'arbre ; à défaut, le joueur local et ses commandes (celles du pilote en démo).
var joueur: Joueur:
```

par :

```gdscript
var est_en_train_de_vomir := false
## 1 = droite, -1 = gauche. Répliquée chez les clients (`Synchro`) : le setter y retourne le sprite
## et réoriente la gerbe.
var direction_du_lion: int = 1:
	set(valeur):
		if valeur == direction_du_lion:
			return
		direction_du_lion = valeur
		if is_node_ready():
			_appliquer_direction()
## Sur l'hôte, l'état de vomi du lion ; répliqué chez les clients (`Synchro`), où il fait vomir la
## réplique (particules, animation : sa traceuse ne peint pas, voir `GerbeTraceuse`).
var vomi_de_l_hote := false
## État du lion (couleurs, bonus, coups) et source de ses intentions. À fournir avant l'ajout
## à l'arbre : les lions d'une bataille les reçoivent de la scène de jeu (`Main`), en réseau par la
## `spawn_function` de son `MultiplayerSpawner`, qui les crée chez chaque poste par l'index de leur
## joueur (des commandes de ce poste pour le lion du joueur local, manuelles pour les autres, qu'en
## réseau l'hôte remplit de celles que chaque client lui envoie). À défaut (le lion de la scène, en
## solo), le joueur local et ses commandes (celles du pilote en démo).
var joueur: Joueur:
```

3c. Remplacer :

```gdscript
func _physics_process(delta: float) -> void:
	_temps += delta
	var input_vector := _direction_voulue()

	if input_vector.x != 0:
		var nouvelle_direction := 1 if input_vector.x > 0 else -1
		if nouvelle_direction != direction_du_lion:
			direction_du_lion = nouvelle_direction
			_appliquer_direction()

	_vitesse = _vitesse.move_toward(input_vector * speed, acceleration * delta)
```

par :

```gdscript
func _physics_process(delta: float) -> void:
	_temps += delta
	if not multiplayer.is_server():
		_suivre_l_hote(delta)
		return
	var input_vector := _direction_voulue()

	if input_vector.x != 0:
		direction_du_lion = 1 if input_vector.x > 0 else -1  # le setter réoriente le lion

	_vitesse = _vitesse.move_toward(input_vector * speed, acceleration * delta)
```

3d. Remplacer :

```gdscript
		arreter_vomi()
	if (etoiles.visible or _barbouillage_actif()) and not joueur.est_etourdi():
```

par :

```gdscript
		arreter_vomi()
	if multiplayer.is_server():
		vomi_de_l_hote = est_en_train_de_vomir
	if (etoiles.visible or _barbouillage_actif()) and not joueur.est_etourdi():
```

3e. Remplacer :

```gdscript
	return -etiquette_pseudo.position.y if etiquette_pseudo.visible else 0.0


## Un lion étourdi ignore ses commandes : il ne se dirige plus et ne vomit plus.
func _direction_voulue() -> Vector2:
	return commandes.direction() if GameState.pret and not joueur.est_etourdi() else Vector2.ZERO
```

par :

```gdscript
	return -etiquette_pseudo.position.y if etiquette_pseudo.visible else 0.0


## Sur un client : le lion suit l'hôte. Sa position et sa vitesse sont celles que recopie son
## `Synchro` ; il ne se déplace pas de lui-même, ne se bloque pas contre les autres lions et ne
## signale rien aux règles (la prédiction du lion local viendra en phase 16). Seule l'animation
## (inclinaison, trot) tourne ici, sur la vitesse de l'hôte.
func _suivre_l_hote(delta: float) -> void:
	_vitesse = velocity
	_animer_deplacement(delta)


## Un lion étourdi ignore ses commandes : il ne se dirige plus et ne vomit plus.
func _direction_voulue() -> Vector2:
	return commandes.direction() if GameState.pret and not joueur.est_etourdi() else Vector2.ZERO
```

3f. Remplacer :

```gdscript
func _direction_voulue() -> Vector2:
	return commandes.direction() if GameState.pret and not joueur.est_etourdi() else Vector2.ZERO


func _veut_vomir() -> bool:
	return GameState.pret and not joueur.est_etourdi() and commandes.vomir()


func _on_couleur_debloquee(_couleur: Color) -> void:
```

par :

```gdscript
func _direction_voulue() -> Vector2:
	return commandes.direction() if GameState.pret and not joueur.est_etourdi() else Vector2.ZERO


## Sur un client, la réplique vomit quand le lion de l'hôte vomit.
func _veut_vomir() -> bool:
	if not multiplayer.is_server():
		return vomi_de_l_hote
	return GameState.pret and not joueur.est_etourdi() and commandes.vomir()


func _on_couleur_debloquee(_couleur: Color) -> void:
```

3g. Remplacer :

```gdscript
	mettre_a_jour_degrade_vomi()


## Crinière à la couleur du joueur et pseudo au-dessus de la tête. Lu une fois dans `_ready` ;
## à rappeler si la couleur ou le pseudo du joueur change ensuite (aperçu du salon, phase 13).
func appliquer_apparence() -> void:
	if not is_node_ready():
		return  # sprite et étiquette n'existent pas encore : `_ready` l'appliquera
```

par :

```gdscript
	mettre_a_jour_degrade_vomi()


## Crinière à la couleur du joueur et pseudo au-dessus de la tête. Lu une fois dans `_ready` ; à
## rappeler si la couleur ou le pseudo du joueur change ensuite (jamais en jeu : la table des joueurs
## d'une bataille est posée avant la scène de jeu, et le salon n'a pas de lion).
func appliquer_apparence() -> void:
	if not is_node_ready():
		return  # sprite et étiquette n'existent pas encore : `_ready` l'appliquera
```

Dans `Scenes/Lion.tscn` :

3h. Remplacer :

```ini
[gd_scene load_steps=13 format=3 uid="uid://dmayuumv4a1gh"]

[ext_resource type="Script" uid="uid://dh0gkc6tf8etc" path="res://Scripts/Lion.gd" id="1_3r2l0"]
```

par :

```ini
[gd_scene load_steps=14 format=3 uid="uid://dmayuumv4a1gh"]

[ext_resource type="Script" uid="uid://dh0gkc6tf8etc" path="res://Scripts/Lion.gd" id="1_3r2l0"]
```

3i. Remplacer :

```ini
[sub_resource type="CircleShape2D" id="CircleShape2D_choc"]
radius = 45.0

[node name="Lion" type="CharacterBody2D" groups=["lion"]]
```

par :

```ini
[sub_resource type="CircleShape2D" id="CircleShape2D_choc"]
radius = 45.0

[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_synchro"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:velocity")
properties/1/spawn = true
properties/1/replication_mode = 1
properties/2/path = NodePath(".:direction_du_lion")
properties/2/spawn = true
properties/2/replication_mode = 2
properties/3/path = NodePath(".:vomi_de_l_hote")
properties/3/spawn = true
properties/3/replication_mode = 2

[node name="Lion" type="CharacterBody2D" groups=["lion"]]
```

3j. Remplacer :

```ini
shape = SubResource("CircleShape2D_choc")

```

par :

```ini
shape = SubResource("CircleShape2D_choc")

[node name="Synchro" type="MultiplayerSynchronizer" parent="."]
replication_interval = 0.012
replication_config = SubResource("SceneReplicationConfig_synchro")

```

Dans `Scripts/Commandes.gd` :

3k. Remplacer :

```gdscript
## Lus seulement en source MANUELLES. direction() borne direction_voulue à une longueur de 1.
var direction_voulue := Vector2.ZERO
var vomir_voulu := false


static func locales() -> Commandes:
```

par :

```gdscript
## Lus seulement en source MANUELLES. direction() borne direction_voulue à une longueur de 1.
var direction_voulue := Vector2.ZERO
var vomir_voulu := false
## Vrai tant que ce poste a ouvert son menu local pendant une manche en réseau (la partie continue,
## spec §4) : les commandes valent alors le repos, quelle que soit leur source, pour qu'un joueur qui
## navigue dans le menu ne fasse ni avancer ni vomir son lion.
var suspendues := false


static func locales() -> Commandes:
```

3l. Remplacer :

```gdscript
func direction() -> Vector2:
	if source == Source.LOCALES:
```

par :

```gdscript
func direction() -> Vector2:
	if suspendues:
		return Vector2.ZERO
	if source == Source.LOCALES:
```

3m. Remplacer :

```gdscript
func vomir() -> bool:
	if source == Source.LOCALES:
```

par :

```gdscript
func vomir() -> bool:
	if suspendues:
		return false
	if source == Source.LOCALES:
```

En solo et en bataille locale, le `Synchro` du lion n'a aucun pair à servir : il est inerte, et `multiplayer.is_server()` est vrai, donc rien d'autre ne change.

- [ ] **Step 4 : le test passe**

Run : la commande des Global Constraints avec `T=tests/unitaires.gd`, `T=tests/smoke_test.gd`, puis `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected (mesuré) : `code 0`, `== 0 échec(s) ==` pour les trois, dont « des commandes suspendues (menu local ouvert) valent le repos, quelle que soit leur source », « le Synchro du lion réplique position et vitesse en continu, orientation et vomi à chaque changement, tous à l'apparition », « sur un client, un lion ne suit pas ses commandes : il ne bouge ni ne vomit de lui-même », « la réplique suit l'état reçu : position, vitesse (son animation), orientation, vomi (particules) », « un étourdissement reçu de l'hôte s'affiche sur la réplique … sans la déplacer ».

- [ ] **Step 5 : Commit, puis le test discrimine**

```bash
git add Scripts/Lion.gd Scenes/Lion.tscn Scripts/Commandes.gd tests/smoke_test.gd tests/unitaires.gd
git commit -m "Lion : sur un client, une réplique du lion de l'hôte (position, vitesse, orientation et vomi par son Synchro, réactions par les signaux de son joueur) ; Commandes.suspendues (menu local) ; smoke test et tests unitaires

<ligne fournie par l'environnement>"
```

Puis chaque mutation seule (`T=tests/smoke_test.gd`, sauf C1 : `T=tests/unitaires.gd`), et **`git checkout -- Scripts/`** avant la suivante (mesuré) :
- L1 : dans `Lion._physics_process`, supprimer les trois lignes `if not multiplayer.is_server():` / `_suivre_l_hote(delta)` / `return` ⇒ `❌ sur un client, un lion ne suit pas ses commandes…`, `❌ la réplique suit l'état reçu…`, `❌ un étourdissement reçu de l'hôte s'affiche sur la réplique…` ;
- L2 : dans `Lion._veut_vomir`, supprimer les deux lignes `if not multiplayer.is_server():` / `return vomi_de_l_hote` ⇒ `❌ sur un client, un lion ne suit pas ses commandes…` et `❌ la réplique arrête de vomir avec le lion de l'hôte` ;
- L3 : dans le setter de `direction_du_lion`, remplacer les deux lignes `if is_node_ready():` / `_appliquer_direction()` par `pass` ⇒ `❌ la réplique suit l'état reçu…` ;
- C1 : dans `Commandes.direction`, supprimer les deux lignes `if suspendues:` / `return Vector2.ZERO` ⇒ `❌ des commandes suspendues (menu local ouvert) valent le repos, quelle que soit leur source`.

Expected ensuite : `git status --short` vide.

---

### Task 7 : la manche et la scène de jeu en réseau

**Files:**
- Create: `Scripts/Manche.gd` (+ `.uid`)
- Modify: `Scripts/Main.gd` (docstring, constantes, variables, `_enter_tree`, `_ready`, fonctions neuves, `_repartir_lions`, `_position_de_depart`)
- Modify: `Scenes/Main.tscn` (nœuds `Apparitions` et `Manche`)
- Modify: `Scripts/Intro.gd` (`automatique`, `lancer`)
- Modify: `Scripts/PauseMenu.gd` (menu local en réseau)
- Modify: `Assets/Traductions/traductions.csv` (`PAUSE_RESEAU`, `QUITTER_PARTIE`)
- Test: `tests/smoke_test.gd` (`_run`, une fonction à la fin)

**Interfaces:**
- Consumes : Tasks 1 à 6 (`Peinture.encoder_tampons` / `decoder_tampons`, `Ville.tampon_peint` / `peindre_tampon_recu`, `Territoire.encoder_changements` / `appliquer_changements` / `scores`, `Joueur.recevoir_*`, `Reseau.signaler_scene_chargee` / `scenes_chargees` / `scene_chargee` / `definir_silence` / `SILENCE_SESSION`, `Spawner.demarrer`, `Lion` réplique, `Commandes.suspendues`) ; `Reseau.joueur_parti`, `Reseau.hote_perdu`, `Reseau.inscrits`.
- Produces (Task 8) : nœud `Main/Manche` : `signal barriere_passee()`, `signal joueur_parti(index: int)`, `const DELAI_CHARGEMENT := 20.0`, `SILENCE_COMMANDES := 500`, `INTERVALLE_TERRITOIRE := 0.2`, `CANAL_PEINTURE := 1`, `static var delai_chargement`, `var actif`, `var barriere`, `var tampons_diffuses`, `var tampons_recus`, `var empreinte_tampons`, `var _prets`, `var _exclus`, `func demarrer(ville)`, `func suivre_lion(lion)`, `func joue(index) -> bool`, `func recevoir_commandes_de(index, numero, direction, vomir, maintenant) -> bool`, `func verifier_silences(maintenant)` ; `Main` : `var lion`, `var lions`, `var en_reseau`, `apparitions` (`MultiplayerSpawner`), `manche`, `menu_pause`, `const DELAI_HOTE_PERDU := 2.5`, nœud `HotePerdu/Message` ; `Intro.automatique`, `Intro.lancer()`, `Intro._lancee` ; `PauseMenu` : titre `PAUSE_RESEAU`, bouton `QUITTER_PARTIE` en réseau.

- [ ] **Step 1 : le test**

Dans `tests/smoke_test.gd` :

1a. Remplacer :

```gdscript
	GS.pret = false

	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)
```

par :

```gdscript
	GS.pret = false

	await _tester_manche_reseau()

	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)
```

1b. Remplacer :

```gdscript
	root.push_input(evenement)
	await process_frame

```

par :

```gdscript
	root.push_input(evenement)
	await process_frame


## Phase 14 : la scène de jeu d'une bataille en réseau, chez un hôte (ce poste héberge ; l'autre
## joueur est simulé dans `Reseau.inscrits`, comme au salon) : lion de la scène retiré, lions par le
## MultiplayerSpawner après la barrière de chargement, exclusion d'un absent, départ en cours de
## manche, commandes reçues et leur silence, menu local sans pause. Les échanges entre postes sont
## couverts par tests/reseau/lancer.sh (scénario 9).
func _tester_manche_reseau() -> void:
	print("-- Manche en réseau (hôte)")
	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	var script_manche: Script = load("res://Scripts/Manche.gd")
	var delai_du_jeu: float = script_manche.delai_chargement
	for essai in ["charge", "absent"]:
		reseau.pseudo = "Hôte"
		_check(reseau.heberger(17798) == OK, "(pré-condition, %s) ce poste héberge" % essai)
		reseau.inscrits[7] = {"index": 1, "couleur": palette[3], "pseudo": "Bob", "arrive": true, "pret": true}
		reseau.manche_en_cours = true
		GS.niveau_courant = 0
		GS.configurer_bataille_reseau([{"id_reseau": 1, "pseudo": "Hôte", "couleur": palette[0]},
			{"id_reseau": 7, "pseudo": "Bob", "couleur": palette[3]}] as Array[Dictionary])
		script_manche.delai_chargement = 0.5
		var main: Node = load("res://Scenes/Main.tscn").instantiate()
		root.add_child(main)
		current_scene = main
		await _frames(3)
		var manche: Node = main.get_node("Manche")
		_check(main.en_reseau and main.get_node_or_null("Lion") == null and main.lions.is_empty() and main.lion == null
			and not manche.barriere and reseau.scenes_chargees == [1] and not main.get_node("Intro")._lancee
			and not main.get_node("Spawner")._demarre,
			"(%s) en réseau, la scène retire le lion du solo et attend la barrière : ni lion, ni intro, ni apparition" % essai)
		if essai == "charge":
			reseau._noter_scene_chargee(7)  # comme la RPC de Bob
			await _frames(2)
		else:
			await create_timer(0.7).timeout
			await _frames(2)
			_check(manche._exclus == [7] and not manche.barriere,
				"(absent) délai passé : Bob est exclu, et la barrière attend son départ")
			reseau._sur_pair_deconnecte(7)  # son départ, vu par Reseau
			await _frames(2)
		var noms: Array = main.lions.map(func(l: Node) -> String: return str(l.name))
		var attendus_noms: Array = ["Lion1", "Lion2"] if essai == "charge" else ["Lion1"]
		_check(manche.barriere and noms == attendus_noms and main.lion == main.lions[0] and main.lion.joueur == GS.joueur_local()
			and main.lion.commandes.source == Commandes.Source.LOCALES and main.get_node("Intro")._lancee and main.get_node("Spawner")._demarre,
			"(%s) barrière passée : un lion par joueur encore là (%s), celui de ce poste lit ses commandes, l'intro et les apparitions commencent" % [essai, noms])
		if essai == "absent":
			_check(not reseau.inscrits.has(7) and main.lions.size() == 1, "(absent) un joueur exclu n'a pas de lion")
			main.free()
			await _frames(1)
			reseau.quitter()
			continue
		var lion_bob: CharacterBody2D = main.lions[1]
		_check(lion_bob.joueur == GS.joueurs[1] and lion_bob.commandes.source == Commandes.Source.MANUELLES
			and lion_bob.position.x < main.lion.position.x + 2000.0 and lion_bob.position.y == main.lion.position.y,
			"le lion de Bob porte son joueur et des commandes manuelles, à sa place de départ")
		# Commandes reçues de Bob, numérotées, puis son silence
		var maintenant := Time.get_ticks_msec()
		_check(manche.recevoir_commandes_de(1, 5, Vector2(0.5, 0.0), true, maintenant) and lion_bob.commandes.direction_voulue == Vector2(0.5, 0.0)
			and lion_bob.commandes.vomir_voulu, "une commande de Bob est écrite dans les commandes de son lion")
		_check(not manche.recevoir_commandes_de(1, 4, Vector2(-1, 0), false, maintenant) and not manche.recevoir_commandes_de(1, 5, Vector2(-1, 0), false, maintenant)
			and lion_bob.commandes.direction_voulue == Vector2(0.5, 0.0),
			"une commande plus ancienne ou déjà vue est ignorée")
		_check(not manche.recevoir_commandes_de(1, 6, "gauche", false, maintenant) and not manche.recevoir_commandes_de(1, 6, Vector2(INF, 0), false, maintenant)
			and not manche.recevoir_commandes_de(0, 6, Vector2(1, 0), false, maintenant) and main.lion.commandes.direction() == Vector2.ZERO,
			"une commande mal formée, non finie ou pour le lion de l'hôte est refusée")
		manche.verifier_silences(maintenant + manche.SILENCE_COMMANDES - 10)
		_check(lion_bob.commandes.vomir_voulu, "pas encore de silence : la dernière commande tient")
		manche.verifier_silences(maintenant + manche.SILENCE_COMMANDES + 10)
		_check(lion_bob.commandes.direction_voulue == Vector2.ZERO and not lion_bob.commandes.vomir_voulu,
			"sans commande de Bob depuis %d ms, son lion revient au repos" % manche.SILENCE_COMMANDES)
		# Chaque tampon de la ville de l'hôte part avec la manche
		var avant: int = manche.tampons_diffuses
		GS.pret = true
		var ville: Node2D = main.get_node("Ville")
		ville.peindre(ville.position, 21, GS.joueurs[0])
		await _frames(2)
		_check(manche.tampons_diffuses == avant + 1, "la manche diffuse chaque tampon de la ville de l'hôte")
		# Menu local : la partie continue, les commandes de ce poste sont suspendues
		var menu: CanvasLayer = main.get_node("PauseMenu")
		menu.ouvrir()
		await _frames(1)
		_check(menu.visible and not paused and main.lion.commandes.suspendues
			and menu.get_node("Centre/Colonne/Titre").text == "PAUSE_RESEAU" and menu.get_node("Centre/Colonne/Menu").text == "QUITTER_PARTIE",
			"en réseau, Échap ouvre un menu local : la partie continue, les commandes de ce poste sont suspendues, « Quitter la partie »")
		menu.reprendre()
		await _frames(1)
		_check(not menu.visible and not paused and not main.lion.commandes.suspendues, "le menu fermé, les commandes reprennent")
		# Bob part en pleine manche : son lion disparaît, ses cellules restent
		ville.territoire.tamponner(1, Vector2i(1000, 200), 40)
		ville.territoire.tamponner(1, Vector2i(1000, 200), 40)
		ville.territoire.tamponner(1, Vector2i(1000, 200), 40)
		var cellules_bob: int = ville.territoire.cellules_de(1)
		reseau._sur_pair_deconnecte(7)
		await _frames(2)
		_check(not is_instance_valid(lion_bob) and main.lions.size() == 1 and ville.territoire.cellules_de(1) == cellules_bob and cellules_bob > 0,
			"un joueur parti en pleine manche perd son lion, ses cellules restent au territoire (%d)" % cellules_bob)
		# Un hôte perdu (chez un client) : message, tout se fige
		main._sur_hote_perdu()
		var message: Label = main.get_node("HotePerdu/Message")
		_check(message.text == "RESEAU_HOTE_PERDU" and paused, "l'hôte perdu : « L'hôte a quitté la partie », la partie se fige")
		paused = false
		main.free()
		await _frames(1)
		reseau.quitter()
	script_manche.delai_chargement = delai_du_jeu
	reseau.pseudo = ""
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false
	GS.niveau_courant = 0

```

- [ ] **Step 2 : le test échoue**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`.
Expected (mesuré) : `SCRIPT ERROR: Invalid access to property or key 'delai_chargement' on a base object of type 'null instance'.` (le script de la manche n'existe pas encore) : la fonction s'arrête avant toute vérification de « -- Manche en réseau (hôte) » ; `== 0 échec(s) ==` s'affiche quand même, c'est la `SCRIPT ERROR` qui fait l'échec.

- [ ] **Step 3 : la manche, la scène de jeu, l'intro, le menu local**

Créer `Scripts/Manche.gd` :

```gdscript
extends Node
## La manche synchronisée (phase 14, spec §3.2) : ce qui passe entre l'hôte et les clients pendant
## une manche en réseau, sur ce nœud de la scène de jeu (`/root/Main/Manche`, au même chemin sur
## chaque poste). Hors réseau (solo, bataille locale), la scène de jeu ne l'appelle pas : il ne fait
## rien. L'hôte simule tout (lions, ennemis, pastilles, étourdissements, territoire) ; un client
## n'envoie que ses commandes et affiche ce que l'hôte décide.
## - Barrière de chargement : chaque poste signale sa scène de jeu chargée
##   (`Reseau.signaler_scene_chargee`) ; l'hôte attend tous les joueurs de la manche encore là, au
##   plus `delai_chargement` secondes de jeu, puis exclut les absents (il les déconnecte : leur
##   départ est un départ comme un autre) ; alors seulement (`barriere_passee`, chez l'hôte puis
##   chez chaque client) les lions apparaissent, le Spawner démarre et l'intro se lance chez tous.
## - Commandes : chaque client envoie à chaque tick physique la direction et l'envie de vomir de son
##   lion (RPC `unreliable_ordered`, numérotées : l'hôte ignore un numéro déjà vu, en attendant la
##   redondance de la phase 16) ; l'hôte les écrit dans les commandes manuelles de ce lion, et les
##   remet au repos après SILENCE_COMMANDES sans nouvelle commande.
## - Tampons : chaque tampon de la ville de l'hôte (`Ville.tampon_peint`) est diffusé, regroupé par
##   tick physique, sur le canal fiable 1 (`Peinture.encoder_tampons`) ; un client le dessine
##   (`Ville.peindre_tampon_recu`).
## - Territoire : toutes les INTERVALLE_TERRITOIRE secondes, l'hôte diffuse les cellules dont le
##   propriétaire compté a changé et les scores (même canal fiable) ; un client les applique
##   (`Territoire.appliquer_changements`) et vérifie qu'il a les mêmes scores.
## - Réactions des joueurs : étourdissement et sa fin, crans, gerbe XXL et sa fin partent de l'hôte en
##   RPC fiables, qui appellent chez chaque client les méthodes du `Joueur` qui émettent les mêmes
##   signaux (Lion, HUD, Audio).
## - Départs : un client parti (`Reseau.joueur_parti`) perd son lion chez l'hôte (sa disparition est
##   répliquée), ses cellules restent ; un hôte perdu arrête la manche du client (la scène de jeu
##   affiche le message et revient au titre).
## Nœud de scène : il nomme `Reseau` et `GameState` ; les tests `--script` ne le nomment pas.

## Chez l'hôte puis chez chaque client : la barrière de chargement est passée, la manche commence.
signal barriere_passee()
## Chez l'hôte : le joueur d'index `index` a quitté la manche (déconnecté, ou exclu faute de scène
## chargée à temps).
signal joueur_parti(index: int)

## Délai de la barrière de chargement, en secondes : au-delà, les joueurs dont la scène n'est pas
## chargée sont exclus.
const DELAI_CHARGEMENT := 20.0
## Sans commande d'un client depuis ce délai (ms), l'hôte remet son lion au repos (point de
## vigilance des phases 14 et 16 : un client planté ne laisse pas son lion filer ou vomir).
const SILENCE_COMMANDES := 500
## Période de diffusion du territoire (cellules changées et scores), en secondes (spec §6).
const INTERVALLE_TERRITOIRE := 0.2
## Canal ENet des tampons et du territoire (spec §4 : canal 1, fiable ordonné).
const CANAL_PEINTURE := 1

## Délai de la barrière de chargement de la prochaine manche : DELAI_CHARGEMENT, réglable par les
## tests réseau (le script de la manche, `load("res://Scripts/Manche.gd")`, porte cette variable).
static var delai_chargement := DELAI_CHARGEMENT

## Vrai une fois `demarrer` appelé, jusqu'à ce que l'hôte soit perdu (un client ne devient jamais
## hôte : revenu hors réseau, il attend le retour au titre).
var actif := false
## Vrai une fois la barrière passée (chez l'hôte et chez chaque client).
var barriere := false
## Statistiques de la manche, lues par le test réseau : tampons diffusés (hôte) ou reçus (client),
## et l'empreinte de leur suite (chaque lot, dans l'ordre), la même chez l'hôte et chez chaque client
## qui a tout reçu.
var tampons_diffuses := 0
var tampons_recus := 0
var empreinte_tampons := 0

var _hote := false
var _ville: Node2D
## Hôte : les commandes manuelles du lion de chaque client, par index de joueur. Client : les
## commandes de son lion (celles de ce poste), à l'index de son joueur.
var _commandes: Dictionary[int, Commandes] = {}
## Hôte : par index de joueur, la dernière commande reçue `{"numero": int, "a": int (ms)}`.
var _recues: Dictionary[int, Dictionary] = {}
## Hôte : les clients dont la scène est chargée, destinataires de tout ce que diffuse la manche.
var _prets: Array[int] = []
## Hôte : les clients exclus par la barrière, qui partent.
var _exclus: Array[int] = []
var _tampons: Array[Dictionary] = []
var _temps_territoire := 0.0
## Hôte : temps de jeu (ticks physiques) écoulé depuis le début du chargement. Pas l'horloge
## murale : un hôte figé (chargement, compilation des shaders) n'exclut personne en reprenant, avant
## d'avoir lu les « scène chargée » arrivés pendant qu'il était figé.
var _temps_chargement := 0.0
## Client : numéro de la dernière commande envoyée.
var _numero := 0


func _ready() -> void:
	# Après les lions et leurs traceuses (priorité 0) : les tampons d'un tick partent dans ce tick.
	process_physics_priority = 100


## Commence la manche en réseau, sur la ville `ville` de la scène de jeu : appelé par `Main` en
## réseau seulement, une fois sa scène prête. La manche continue alors même quand l'arbre est en
## pause (fin de manche) : ses derniers tampons et son territoire partent quand même.
func demarrer(ville: Node2D) -> void:
	actif = true
	_ville = ville
	_hote = multiplayer.is_server()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Reseau.hote_perdu.connect(_sur_hote_perdu)
	if _hote:
		Reseau.scene_chargee.connect(_sur_scene_chargee)
		Reseau.joueur_parti.connect(_sur_depart_reseau)
	Reseau.signaler_scene_chargee()
	if _hote:
		_verifier_barriere()


## Les autoloads survivent à la scène de jeu : ne rien leur laisser.
func _exit_tree() -> void:
	for connexion: Array in [[Reseau.hote_perdu, _sur_hote_perdu], [Reseau.scene_chargee, _sur_scene_chargee],
			[Reseau.joueur_parti, _sur_depart_reseau]]:
		if (connexion[0] as Signal).is_connected(connexion[1]):
			(connexion[0] as Signal).disconnect(connexion[1])


## Le lion `lion` vient d'apparaître sur ce poste (appelé par `Main`) : chez l'hôte, les commandes
## manuelles du lion d'un client y seront écrites ; chez un client, les commandes de son propre lion
## partiront vers l'hôte.
func suivre_lion(lion: Lion) -> void:
	var local := lion.joueur == GameState.joueur_local()
	if (_hote and not local) or (not _hote and local):
		_commandes[lion.joueur.index] = lion.commandes


## Chez l'hôte : vrai si le joueur d'index `index` est encore dans la manche (inscrit, ni parti ni
## exclu) : son lion doit apparaître.
func joue(index: int) -> bool:
	if index < 0 or index >= GameState.joueurs.size():
		return false
	var id := GameState.joueurs[index].id_reseau
	return Reseau.inscrits.has(id) and not _exclus.has(id)


func _physics_process(delta: float) -> void:
	if not actif:
		return
	if not _hote:
		_envoyer_commandes()
		return
	if not barriere:
		_temps_chargement += delta
		_verifier_barriere()
		return
	verifier_silences(Time.get_ticks_msec())
	_diffuser_tampons()
	_temps_territoire += delta
	if _temps_territoire >= INTERVALLE_TERRITOIRE:
		_temps_territoire = 0.0
		_diffuser_territoire()


# --- Barrière de chargement (hôte) ---------------------------------------------------------------


func _sur_scene_chargee(_id: int) -> void:
	_verifier_barriere()


## Les identifiants réseau des joueurs de la manche encore inscrits chez l'hôte (hôte compris).
func _attendus() -> Array[int]:
	var ids: Array[int] = []
	for j in GameState.joueurs:
		if Reseau.inscrits.has(j.id_reseau):
			ids.append(j.id_reseau)
	return ids


## Passe la barrière quand chaque joueur encore là a chargé sa scène. Délai passé, les absents sont
## exclus (déconnectés) : la barrière attend alors leur départ, qui les retire des attendus.
func _verifier_barriere() -> void:
	if barriere or not actif:
		return
	var absents := _attendus().filter(func(id: int) -> bool: return not Reseau.scenes_chargees.has(id))
	if not absents.is_empty():
		if _temps_chargement >= delai_chargement:
			for id: int in absents:
				_exclure(id)
		return
	barriere = true
	_prets.clear()
	for id in Reseau.scenes_chargees:
		if id != multiplayer.get_unique_id() and Reseau.inscrits.has(id):
			_prets.append(id)
	Reseau.definir_silence(Reseau.SILENCE_SESSION)
	_ville.tampon_peint.connect(_sur_tampon_peint)
	for j in GameState.joueurs:
		j.etourdi.connect(_sur_etourdi.bind(j))
		j.etourdissement_fini.connect(_sur_fin_etourdissement.bind(j))
		j.crans_changes.connect(_sur_crans.bind(j))
		j.bonus_change.connect(_sur_bonus.bind(j))
	barriere_passee.emit()  # la scène fait apparaître les lions : leurs apparitions partent avant l'intro
	_envoyer(&"_lancer_intro", [])


## Chez l'hôte : `id` n'a pas chargé sa scène à temps. Il est déconnecté (proprement : il le voit
## comme un hôte perdu, et son départ arrive ici par `Reseau.joueur_parti`).
func _exclure(id: int) -> void:
	if _exclus.has(id):
		return
	_exclus.append(id)
	push_warning("Manche : le joueur %d n'a pas chargé sa scène à temps, exclu" % id)
	if multiplayer.get_peers().has(id):
		multiplayer.multiplayer_peer.disconnect_peer(id)


## Chez un client : la barrière est passée chez l'hôte.
@rpc("authority", "call_remote", "reliable")
func _lancer_intro() -> void:
	if not actif or barriere:
		return
	barriere = true
	Reseau.definir_silence(Reseau.SILENCE_SESSION)
	barriere_passee.emit()


# --- Commandes -------------------------------------------------------------------------------------


## Chez un client : les commandes de son lion, une fois par tick physique.
func _envoyer_commandes() -> void:
	if not barriere or _commandes.is_empty():
		return
	var c: Commandes = _commandes.values()[0]
	_numero += 1
	_recevoir_commandes.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, _numero, c.direction(), c.vomir())


## Chez l'hôte : les commandes d'un client, pour son lion.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _recevoir_commandes(numero: Variant, direction: Variant, vomir: Variant) -> void:
	if not _hote:
		return
	var id := multiplayer.get_remote_sender_id()
	for j in GameState.joueurs:
		if j.id_reseau == id:
			recevoir_commandes_de(j.index, numero, direction, vomir, Time.get_ticks_msec())
			return


## Chez l'hôte : écrit la commande `numero` du joueur d'index `index` dans les commandes de son lion,
## reçue à `maintenant` (ms). Refusée (faux) pour un lion inconnu, des arguments d'un autre type ou
## non finis, ou un numéro déjà vu.
func recevoir_commandes_de(index: int, numero: Variant, direction: Variant, vomir: Variant, maintenant: int) -> bool:
	var c: Commandes = _commandes.get(index)
	if c == null or not (numero is int) or not (direction is Vector2) or not (vomir is bool) or not direction.is_finite():
		return false
	if numero <= _recues.get(index, {"numero": 0}).numero:
		return false
	c.direction_voulue = direction  # bornée à une longueur de 1 par `Commandes.direction()`
	c.vomir_voulu = vomir
	_recues[index] = {"numero": numero, "a": maintenant}
	return true


## Chez l'hôte : le lion d'un client dont aucune commande n'est arrivée depuis SILENCE_COMMANDES ms
## (à `maintenant`) revient au repos.
func verifier_silences(maintenant: int) -> void:
	for index: int in _recues:
		if maintenant - int(_recues[index].a) > SILENCE_COMMANDES and _commandes.has(index):
			_commandes[index].direction_voulue = Vector2.ZERO
			_commandes[index].vomir_voulu = false


# --- Tampons et territoire -------------------------------------------------------------------------


func _sur_tampon_peint(tampon: Dictionary) -> void:
	_tampons.append(tampon)


## Chez l'hôte : les tampons de ce tick, en un seul envoi.
func _diffuser_tampons() -> void:
	if _tampons.is_empty():
		return
	var octets := Peinture.encoder_tampons(_tampons)
	tampons_diffuses += _tampons.size()
	empreinte_tampons = hash([empreinte_tampons, octets])
	_envoyer(&"_recevoir_tampons", [octets])
	_tampons.clear()


## Chez un client : les tampons d'un tick de l'hôte, dessinés dans l'ordre.
@rpc("authority", "call_remote", "reliable", CANAL_PEINTURE)
func _recevoir_tampons(octets: Variant) -> void:
	if not actif:
		return
	var tampons := Peinture.decoder_tampons(octets)
	if tampons.is_empty():
		push_warning("Manche : lot de tampons illisible, ignoré")
		return
	for tampon in tampons:
		_ville.peindre_tampon_recu(tampon)
	tampons_recus += tampons.size()
	empreinte_tampons = hash([empreinte_tampons, octets])


## Chez l'hôte : les cellules changées depuis le dernier envoi et les scores.
func _diffuser_territoire() -> void:
	var territoire: Territoire = _ville.territoire
	if territoire == null:
		return
	var changees := territoire.extraire_changements()
	if changees.is_empty():
		return
	_envoyer(&"_recevoir_territoire", [territoire.encoder_changements(changees), territoire.scores()])


## Chez un client : les cellules changées chez l'hôte, appliquées ; les scores doivent alors être
## ceux de l'hôte (sinon, une désynchronisation est signalée).
@rpc("authority", "call_remote", "reliable", CANAL_PEINTURE)
func _recevoir_territoire(octets: Variant, scores: Variant) -> void:
	var territoire: Territoire = null if _ville == null else _ville.territoire
	if not actif or territoire == null:
		return
	if not territoire.appliquer_changements(octets):
		push_warning("Manche : cellules changées illisibles, ignorées")
		return
	if not (scores is PackedInt32Array) or scores != territoire.scores():
		push_error("Manche : territoire désynchronisé de l'hôte (%s au lieu de %s)" % [territoire.scores(), scores])


# --- Réactions des joueurs -------------------------------------------------------------------------


func _sur_etourdi(origine: Vector2, barbouillage: Color, j: Joueur) -> void:
	_envoyer(&"_recevoir_etourdi", [j.index, j.etourdi_restant, j.invulnerable_restant - j.etourdi_restant, origine, barbouillage])


func _sur_fin_etourdissement(j: Joueur) -> void:
	_envoyer(&"_recevoir_fin_etourdissement", [j.index, j.invulnerable_restant])


func _sur_crans(crans: int, j: Joueur) -> void:
	_envoyer(&"_recevoir_crans", [j.index, crans])


func _sur_bonus(actif_: bool, j: Joueur) -> void:
	if actif_:
		_envoyer(&"_recevoir_bonus", [j.index, j.bonus_restant])
	else:
		_envoyer(&"_recevoir_fin_bonus", [j.index])


@rpc("authority", "call_remote", "reliable")
func _recevoir_etourdi(index: Variant, duree: Variant, immunite: Variant, origine: Variant, barbouillage: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null and duree is float and immunite is float and origine is Vector2 and barbouillage is Color:
		j.etourdir(duree, immunite, origine, barbouillage)


@rpc("authority", "call_remote", "reliable")
func _recevoir_fin_etourdissement(index: Variant, immunite: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null and immunite is float:
		j.recevoir_fin_etourdissement(immunite)


@rpc("authority", "call_remote", "reliable")
func _recevoir_crans(index: Variant, crans: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null and crans is int:
		j.recevoir_crans(crans)


@rpc("authority", "call_remote", "reliable")
func _recevoir_bonus(index: Variant, duree: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null and duree is float:
		j.activer_bonus(duree)


@rpc("authority", "call_remote", "reliable")
func _recevoir_fin_bonus(index: Variant) -> void:
	var j := _joueur_recu(index)
	if j != null:
		j.recevoir_fin_bonus()


## Le joueur d'index `index` reçu de l'hôte, ou null (index d'un autre type ou hors de la table).
func _joueur_recu(index: Variant) -> Joueur:
	if not actif or not (index is int) or index < 0 or index >= GameState.joueurs.size():
		return null
	return GameState.joueurs[index]


# --- Départs ----------------------------------------------------------------------------------------


## Chez l'hôte : le client `id` est parti (ou a été exclu).
func _sur_depart_reseau(id: int) -> void:
	_prets.erase(id)
	for j in GameState.joueurs:
		if j.id_reseau == id:
			_commandes.erase(j.index)
			_recues.erase(j.index)
			joueur_parti.emit(j.index)
	_verifier_barriere()


## Chez un client : l'hôte est perdu (ce poste est déjà hors réseau) ; la manche s'arrête là.
func _sur_hote_perdu() -> void:
	actif = false


## Chez l'hôte : appelle la RPC `methode` chez chaque client prêt et encore connecté (jamais chez un
## client dont la scène de jeu n'est pas chargée : le nœud de la manche n'y existe pas encore ; ni
## chez un client déjà déconnecté dont le départ n'est pas encore arrivé ici).
func _envoyer(methode: StringName, arguments: Array) -> void:
	var connectes := multiplayer.get_peers()
	for id in _prets:
		if connectes.has(id):
			callv("rpc_id", [id, methode] + arguments)
```

Dans `Scripts/Main.gd` :

3a. Remplacer :

```gdscript
## Racine de la partie : met l'écran à la taille du mode, place la ville, le ciel, la caméra et
## un lion par joueur, écoute la fin de partie et affiche le bilan du solo.

@export var game_over_scene: PackedScene
```

par :

```gdscript
## Racine de la partie : met l'écran à la taille du mode, place la ville, le ciel, la caméra et
## un lion par joueur, écoute la fin de partie et affiche le bilan du solo.
## En réseau (phase 14), la manche synchronisée (`Manche`) passe entre l'hôte et les clients : le
## lion de la scène (celui du solo) est retiré, tous les lions apparaissent par le
## `MultiplayerSpawner` de la scène (`Apparitions`, par l'index de leur joueur, sa `spawn_function`
## leur donnant joueur et commandes avant l'ajout), comme les ennemis et les pastilles que fait
## apparaître le Spawner de l'hôte ; lions, Spawner et intro attendent la barrière de chargement.
## Échap y ouvre un menu local qui ne met pas la partie en pause ; un hôte perdu ramène au titre
## après son message.

@export var game_over_scene: PackedScene
```

3b. Remplacer :

```gdscript
const SCRIPT_PILOTE := preload("res://Scripts/Pilote.gd")
const SCENE_LION := preload("res://Scenes/Lion.tscn")

@onready var ville: Node2D = $Ville
@onready var lion: Lion = $Lion
@onready var camera: Camera2D = $Camera
@onready var ciel: TextureRect = $Ciel

## Un lion par joueur, dans l'ordre de `GameState.joueurs` : le premier est celui de la scène,
## le lion du joueur local.
var lions: Array[Lion] = []

var _tremblement_restant := 0.0
```

par :

```gdscript
const SCRIPT_PILOTE := preload("res://Scripts/Pilote.gd")
const SCENE_LION := preload("res://Scenes/Lion.tscn")
## Temps pendant lequel « L'hôte a quitté la partie » reste affiché avant le retour au titre.
const DELAI_HOTE_PERDU := 2.5

@onready var ville: Node2D = $Ville
@onready var camera: Camera2D = $Camera
@onready var ciel: TextureRect = $Ciel
@onready var apparitions: MultiplayerSpawner = $Apparitions
@onready var manche: Node = $Manche
@onready var menu_pause: CanvasLayer = $PauseMenu

## Le lion du joueur local : celui de la scène hors réseau ; en réseau, celui qui apparaît pour le
## joueur de ce poste (null avant son apparition).
var lion: Lion
## Un lion par joueur, dans l'ordre de `GameState.joueurs` (des index) : hors réseau, le premier est
## celui de la scène, le lion du joueur local ; en réseau, ceux qui ont apparu, sans les partis.
var lions: Array[Lion] = []
## Vrai pour une bataille en réseau (fixé en entrant dans l'arbre).
var en_reseau := false

var _tremblement_restant := 0.0
```

3c. Remplacer :

```gdscript
		Input.action_release(action)
	Regles.appliquer_ecran(get_tree(), GameState.regles.taille_ecran())
	GameState.nouvelle_partie()


func _ready() -> void:
```

par :

```gdscript
		Input.action_release(action)
	Regles.appliquer_ecran(get_tree(), GameState.regles.taille_ecran())
	GameState.nouvelle_partie()
	en_reseau = Reseau.en_ligne()
	# Avant le `_ready` de l'intro : en réseau, elle attend la barrière de chargement.
	$Intro.automatique = not en_reseau


func _ready() -> void:
```

3d. Remplacer :

```gdscript
	ville.charger_skyline(load(GameState.niveau().texture))
	_placer_ville()
	_placer_ciel_et_camera()
	_ajouter_lions()
	$Spawner.demarrer()
	if GameState.demo:
		_installer_demo()


## Attract mode : un pilote automatique joue, une étiquette clignote, toute touche ramène au titre.
```

par :

```gdscript
	ville.charger_skyline(load(GameState.niveau().texture))
	_placer_ville()
	_placer_ciel_et_camera()
	if en_reseau:
		_preparer_manche_en_reseau()
		return
	lion = $Lion
	_ajouter_lions()
	$Spawner.demarrer()
	if GameState.demo:
		_installer_demo()


## En réseau : le lion de la scène (celui du solo) s'en va avant tout tick, les lions viendront
## d'`apparitions` ; la manche commence (barrière de chargement).
func _preparer_manche_en_reseau() -> void:
	var lion_du_solo: Node = $Lion
	remove_child(lion_du_solo)
	lion_du_solo.free()
	apparitions.spawn_function = _creer_lion
	apparitions.spawned.connect(_sur_apparition)
	manche.barriere_passee.connect(_sur_barriere_passee)
	manche.joueur_parti.connect(_sur_joueur_parti)
	menu_pause.visibility_changed.connect(_suspendre_commandes)
	if not multiplayer.is_server():
		Reseau.hote_perdu.connect(_sur_hote_perdu)
	manche.demarrer(ville)


## La `spawn_function` d'`apparitions`, sur chaque poste : le lion du joueur d'index `index`, avec
## son joueur et ses commandes avant l'ajout à l'arbre (celles de ce poste pour le joueur local,
## manuelles pour les autres), à sa place de départ.
func _creer_lion(index: Variant) -> Node:
	if not (index is int) or index < 0 or index >= GameState.joueurs.size():
		push_error("Main : apparition d'un lion pour un index inconnu (%s)" % [index])
		return null
	var joueur: Joueur = GameState.joueurs[index]
	var nouveau: Lion = SCENE_LION.instantiate()
	nouveau.name = "Lion%d" % (index + 1)
	nouveau.joueur = joueur
	nouveau.commandes = Commandes.locales() if joueur == GameState.joueur_local() else Commandes.manuelles()
	nouveau.position = _position_de_depart(index, GameState.joueurs.size())
	return nouveau


## Barrière passée : chez l'hôte, un lion par joueur encore là, puis les apparitions du Spawner ; sur
## chaque poste, l'intro.
func _sur_barriere_passee() -> void:
	if multiplayer.is_server():
		for i in range(GameState.joueurs.size()):
			if manche.joue(i):
				_enregistrer_lion(apparitions.spawn(i))
		$Spawner.demarrer()
	$Intro.lancer()


## Chez un client : un nœud apparu par `apparitions` (un lion, ou un ennemi, une pastille).
func _sur_apparition(noeud: Node) -> void:
	if noeud is Lion:
		_enregistrer_lion(noeud)


func _enregistrer_lion(nouveau: Lion) -> void:
	lions.append(nouveau)
	lions.sort_custom(func(a: Lion, b: Lion) -> bool: return a.joueur.index < b.joueur.index)
	if nouveau.joueur == GameState.joueur_local():
		lion = nouveau
		_suspendre_commandes()
	manche.suivre_lion(nouveau)
	nouveau.tree_exited.connect(_oublier_lion.bind(nouveau))


func _oublier_lion(parti: Lion) -> void:
	lions.erase(parti)
	if lion == parti:
		lion = null


## Chez l'hôte : le joueur d'index `index` a quitté la manche ; son lion s'en va chez tous (sa
## disparition est répliquée), ses cellules restent au territoire.
func _sur_joueur_parti(index: int) -> void:
	for l in lions:
		if l.joueur.index == index:
			l.queue_free()


## Menu local ouvert pendant une manche en réseau : les commandes de ce poste valent le repos.
func _suspendre_commandes() -> void:
	if lion != null:
		lion.commandes.suspendues = menu_pause.visible


## Chez un client : l'hôte est parti (ce poste est déjà hors réseau). Tout se fige sous le message,
## puis retour au titre (spec §9).
func _sur_hote_perdu() -> void:
	var couche := CanvasLayer.new()
	couche.name = "HotePerdu"
	couche.layer = 10
	couche.process_mode = Node.PROCESS_MODE_ALWAYS
	var message := Label.new()
	message.name = "Message"
	message.text = "RESEAU_HOTE_PERDU"
	message.add_theme_font_size_override("font_size", 56)
	message.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	message.add_theme_constant_override("outline_size", 10)
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	message.grow_vertical = Control.GROW_DIRECTION_BOTH
	couche.add_child(message)
	add_child(couche)
	get_tree().paused = true
	get_tree().create_timer(DELAI_HOTE_PERDU, true).timeout.connect(_revenir_au_titre)


func _revenir_au_titre() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_TITRE)


## Attract mode : un pilote automatique joue, une étiquette clignote, toute touche ramène au titre.
```

3e. Remplacer :

```gdscript
		_repartir_lions()


## Centres des lions régulièrement espacés sur la largeur, tous à la même hauteur.
func _repartir_lions() -> void:
	var taille := get_viewport_rect().size
	for i in range(lions.size()):
		var centre_x := taille.x * (i + 0.5) / lions.size()
		lions[i].position = Vector2(centre_x - Lion.CENTRE.x, taille.y * hauteur_depart_lions)


func _process(delta: float) -> void:
	if GameState.demo and GameState.partie_en_cours:
		_demo_restant -= delta
```

par :

```gdscript
		_repartir_lions()


## Centres des lions régulièrement espacés sur la largeur, tous à la même hauteur.
func _repartir_lions() -> void:
	for i in range(lions.size()):
		lions[i].position = _position_de_depart(i, lions.size())


## Place de départ du lion `i` sur `nb` : centres régulièrement espacés sur la largeur, en haut du ciel.
func _position_de_depart(i: int, nb: int) -> Vector2:
	var taille := get_viewport_rect().size
	return Vector2(taille.x * (i + 0.5) / nb - Lion.CENTRE.x, taille.y * hauteur_depart_lions)


func _process(delta: float) -> void:
	if GameState.demo and GameState.partie_en_cours:
		_demo_restant -= delta
```

Dans `Scenes/Main.tscn` :

3f. Remplacer :

```ini
[gd_scene load_steps=12 format=3 uid="uid://dlelionmain00"]

[ext_resource type="Script" path="res://Scripts/Main.gd" id="1_main"]
```

par :

```ini
[gd_scene load_steps=13 format=3 uid="uid://dlelionmain00"]

[ext_resource type="Script" path="res://Scripts/Main.gd" id="1_main"]
```

3g. Remplacer :

```ini
[ext_resource type="PackedScene" uid="uid://dleliontactil" path="res://Scenes/ControlesTactiles.tscn" id="8_tactile"]
[ext_resource type="PackedScene" uid="uid://dlelionintro0" path="res://Scenes/Intro.tscn" id="9_intro"]

[sub_resource type="Gradient" id="Gradient_ciel"]
```

par :

```ini
[ext_resource type="PackedScene" uid="uid://dleliontactil" path="res://Scenes/ControlesTactiles.tscn" id="8_tactile"]
[ext_resource type="PackedScene" uid="uid://dlelionintro0" path="res://Scenes/Intro.tscn" id="9_intro"]
[ext_resource type="Script" path="res://Scripts/Manche.gd" id="10_manche"]

[sub_resource type="Gradient" id="Gradient_ciel"]
```

3h. Remplacer :

```ini
[node name="Intro" parent="." instance=ExtResource("9_intro")]

```

par :

```ini
[node name="Intro" parent="." instance=ExtResource("9_intro")]

[node name="Apparitions" type="MultiplayerSpawner" parent="."]
_spawnable_scenes = PackedStringArray("res://Scenes/Soucoupe.tscn", "res://Scenes/Coccinelle.tscn", "res://Scenes/Boss.tscn", "res://Scenes/ColorPickup.tscn", "res://Scenes/BonusPickup.tscn", "res://Scenes/CoeurPickup.tscn")
spawn_path = NodePath("..")

[node name="Manche" type="Node" parent="."]
script = ExtResource("10_manche")

```

Dans `Scripts/Intro.gd` :

3i. Remplacer :

```gdscript
@export var duree_etape := 0.7

@onready var texte: Label = $Texte


func _ready() -> void:
	var etapes: Array[String] = [GameState.titre_etape(), tr("PRET"), tr("VOMISSEZ")]
```

par :

```gdscript
@export var duree_etape := 0.7
## Vrai : l'intro se lance d'elle-même (solo, bataille locale). En réseau, la scène de jeu la lance
## chez tous une fois la barrière de chargement passée (`lancer`).
var automatique := true

@onready var texte: Label = $Texte

var _lancee := false


func _ready() -> void:
	if automatique:
		lancer()


func lancer() -> void:
	if _lancee:
		return
	_lancee = true
	var etapes: Array[String] = [GameState.titre_etape(), tr("PRET"), tr("VOMISSEZ")]
```

Dans `Scripts/PauseMenu.gd` :

3j. Remplacer :

```gdscript
extends CanvasLayer
## Menu de pause : Échap (ou Start) l'ouvre et le ferme ; Continuer / Revenir au menu.

const SCENE_TITRE := "res://Scenes/Titre.tscn"
```

par :

```gdscript
extends CanvasLayer
## Menu de pause : Échap (ou Start) l'ouvre et le ferme ; Continuer / Revenir au menu.
## En réseau (spec §4), un menu local : il ne met pas la partie en pause (elle continue chez tous ;
## la scène de jeu suspend les commandes de ce poste tant qu'il est ouvert), et « Quitter la
## partie » ramène au titre, qui quitte le réseau.

const SCENE_TITRE := "res://Scenes/Titre.tscn"
```

3k. Remplacer :

```gdscript
@onready var bouton_reglages: Button = $Centre/Colonne/Reglages

var _reglages_ouverts := false


func _unhandled_input(event: InputEvent) -> void:
```

par :

```gdscript
@onready var bouton_reglages: Button = $Centre/Colonne/Reglages

var _reglages_ouverts := false


func _ready() -> void:
	if Reseau.en_ligne():
		$Centre/Colonne/Titre.text = "PAUSE_RESEAU"
		$Centre/Colonne/Menu.text = "QUITTER_PARTIE"


func _unhandled_input(event: InputEvent) -> void:
```

3l. Remplacer :

```gdscript
func ouvrir() -> void:
	get_tree().paused = true
	visible = true
```

par :

```gdscript
func ouvrir() -> void:
	if not Reseau.en_ligne():
		get_tree().paused = true
	visible = true
```

3m. Remplacer :

```gdscript
	bouton_continuer.grab_focus()


func reprendre() -> void:
	visible = false
	get_tree().paused = false


func ouvrir_reglages() -> void:
	_reglages_ouverts = true
	var reglages := SCENE_REGLAGES.instantiate()
```

par :

```gdscript
	bouton_continuer.grab_focus()


func reprendre() -> void:
	visible = false
	if not Reseau.en_ligne():
		get_tree().paused = false


func ouvrir_reglages() -> void:
	_reglages_ouverts = true
	var reglages := SCENE_REGLAGES.instantiate()
```

Dans `Assets/Traductions/traductions.csv` :

3n. Remplacer :

```text
SALON_ADRESSES,"Les autres te voient dans leur liste, ou tapent ton adresse : %s","Others see you in their list, or type your address: %s"

```

par :

```text
SALON_ADRESSES,"Les autres te voient dans leur liste, ou tapent ton adresse : %s","Others see you in their list, or type your address: %s"
PAUSE_RESEAU,La partie continue,The game goes on
QUITTER_PARTIE,Quitter la partie,Leave the game

```

Puis `export PATH="/opt/homebrew/bin:$PATH"; timeout -k 5 120 godot --headless --import . > "$TMPDIR/i.log" 2>&1; grep -E "SCRIPT ERROR|Parse Error" "$TMPDIR/i.log"` ne sort rien (les deux `.translation` régénérés).

- [ ] **Step 4 : le test passe**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd`, `T=tests/unitaires.gd`, `T=tests/bataille_test.gd; O="--fixed-fps 60"`, puis `timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $?"; grep -E "❌|✅|== " "$TMPDIR/r.log"` (le scénario 8 charge désormais une vraie manche en réseau).
Expected (mesuré) : `code 0`, `== 0 échec(s) ==` partout ; 19 lignes ✅ sous « -- Manche en réseau (hôte) », dont « (charge) barrière passée : un lion par joueur encore là (["Lion1", "Lion2"]) … », « (absent) délai passé : Bob est exclu, et la barrière attend son départ », « sans commande de Bob depuis 500 ms, son lion revient au repos », « en réseau, Échap ouvre un menu local … », « un joueur parti en pleine manche perd son lion, ses cellules restent au territoire (80) », « l'hôte perdu : « L'hôte a quitté la partie », la partie se fige » ; une seule ligne `WARNING: Manche : le joueur 7 n'a pas chargé sa scène à temps, exclu` (voulue) ; le test réseau, 7 lignes ✅.

- [ ] **Step 5 : Commit, puis le test discrimine**

```bash
git add Scripts/Manche.gd Scripts/Manche.gd.uid Scripts/Main.gd Scenes/Main.tscn Scripts/Intro.gd Scripts/PauseMenu.gd Assets/Traductions/traductions.csv Assets/Traductions/traductions.en.translation Assets/Traductions/traductions.fr.translation tests/smoke_test.gd
git commit -m "Manche synchronisée : barrière de chargement (exclusion d'un absent), commandes des clients numérotées et leur silence, tampons et territoire diffusés, réactions des joueurs par RPC, départs ; scène de jeu en réseau : lions par le MultiplayerSpawner (spawn_function par index), intro après la barrière, menu local sans pause, hôte perdu (message puis titre) ; smoke test

<ligne fournie par l'environnement>"
```

Puis chaque mutation seule, `T=tests/smoke_test.gd`, et **`git checkout -- Scripts/`** avant la suivante (mesuré) :
- M1 : dans `Manche.recevoir_commandes_de`, supprimer les deux lignes `if numero <= _recues.get(index, {"numero": 0}).numero:` / `return false` ⇒ `❌ une commande plus ancienne ou déjà vue est ignorée` et `❌ pas encore de silence : la dernière commande tient` ;
- M2 : dans `Main._enter_tree`, `$Intro.automatique = not en_reseau` → `$Intro.automatique = true` ⇒ les deux `❌ (…) en réseau, la scène retire le lion du solo et attend la barrière…` ;
- M3 : dans `PauseMenu.ouvrir`, remplacer les deux lignes `if not Reseau.en_ligne():` / `get_tree().paused = true` par `get_tree().paused = true` ⇒ `❌ en réseau, Échap ouvre un menu local…` et `❌ le menu fermé, les commandes reprennent` ;
- M4 : dans `Manche._verifier_barriere`, remplacer les deux lignes `for id: int in absents:` / `_exclure(id)` par `pass` ⇒ `❌ (absent) délai passé : Bob est exclu, et la barrière attend son départ` ;
- M5 : dans `Main._sur_joueur_parti`, remplacer les deux lignes `if l.joueur.index == index:` / `l.queue_free()` par `pass` ⇒ `❌ un joueur parti en pleine manche perd son lion, ses cellules restent au territoire (80)`.

Expected ensuite : `git status --short` vide.

---

### Task 8 : la manche à plusieurs postes (test réseau, scénario 9)

**Files:**
- Modify: `tests/reseau/joueur.gd` (en-tête, `_run`, `_jouer_manche` et ses aides, `_jouer_muet`, à la fin)
- Modify: `tests/reseau/lancer.sh` (en-tête, scénario 9 avant le bilan)

**Interfaces:**
- Consumes : Tasks 1 à 7 ; harnais existant (`_attendre`, `_pause`, `_scene_est`, `_sur_depart`, `_sur_inscription`, `_ajouter_issue`, `lancer`, `attendre_hote`, `attendre_ligne`, `terminer`, `compter`).
- Produces : rôles `manche-hote` (`--clients=N --gel=S --delai-chargement=S --sens=±1 --rester=chemin`), `manche-client` (`--sens=±1 --partir | --fige=chemin`), `manche-muet` (`--gel=S --delai-chargement=S`) ; lignes de journal `HOTE PRET`, `GEL`, `BARRIERE prets=… exclus=…`, `INTRO`, `MESURE <pseudo> : …`, `DEPART VU`, `EMPREINTE …`, `FIGE`, `HOTE RESTE`, `PARTI`, `EXCLU apres=… s` ; scénario 9 de `lancer.sh` (ports `port_de_base + 9` et `+ 1009`).

- [ ] **Step 1 : les rôles de la manche**

Dans `tests/reseau/joueur.gd` :

1a. Remplacer :

```gdscript
##   godot --headless --script tests/reseau/joueur.gd -- --role=<rôle> [options]
## Rôles : hote, client, lent, ecouteur, salon-hote, salon-client.
## Communes : --port=N (défaut 17777), --pseudo=texte, --port-balise=N (port des balises de
```

par :

```gdscript
##   godot --headless --script tests/reseau/joueur.gd -- --role=<rôle> [options]
## Rôles : hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client,
## manche-muet.
## Communes : --port=N (défaut 17777), --pseudo=texte, --port-balise=N (port des balises de
```

1b. Remplacer :

```gdscript
##   de l'hôte.
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
```

par :

```gdscript
##   de l'hôte.
## Manche (phase 14), par les vraies scènes jusqu'à la scène de jeu, puis une manche jouée au clavier
##   de chaque poste (actions pressées comme un joueur : `Input.action_press`).
##   Manche-hôte : --clients=N (arrivées attendues, le muet compris), --gel=S (fige son processus S
##   secondes dès sa scène de jeu chargée : ses clients, qui chargent, ne doivent pas le croire
##   parti), --delai-chargement=S (délai de la barrière), --rester=chemin. Écrit « HOTE PRET »,
##   « BARRIERE prets=… exclus=… », « DEPART VU », puis, une fois les lions arrêtés et les coulures
##   finies, fige la manche (`terminer_partie`) : « EMPREINTE <territoire, scores, tampons,
##   lions, apparitions> » et « FIGE ».
##   Manche-client : --sens=1|-1 (sa passe de peinture, vers la droite ou la gauche), --partir (quitte
##   la manche par le menu local une fois sa passe faite : « PARTI »), --fige=chemin (une fois ce
##   fichier créé par lancer.sh, attend ses coulures puis écrit sa propre « EMPREINTE »), puis attend
##   le départ de l'hôte (« L'hôte a quitté la partie », puis le titre).
##   Manche-muet : rejoint l'hôte sans scène (pas de salon ni de scène de jeu), se dit prêt, reçoit le
##   lancement de la manche mais ne charge jamais sa scène : l'hôte doit l'exclure après le délai de
##   la barrière (« EXCLU »).
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
```

1c. Remplacer :

```gdscript
		await _jouer_salon(role == "salon-hote")
	else:
		_check(false, "rôle inconnu : --role=hote, client, lent, ecouteur, salon-hote ou salon-client")
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
```

par :

```gdscript
		await _jouer_salon(role == "salon-hote")
	elif role == "manche-hote" or role == "manche-client":
		await _jouer_manche(role == "manche-hote")
	elif role == "manche-muet":
		await _jouer_muet()
	else:
		_check(false, "rôle inconnu : --role=hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client ou manche-muet")
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
```

1d. Remplacer :

```gdscript
	_issue = quoi if _issue.is_empty() else _issue + "+" + quoi

```

par :

```gdscript
	_issue = quoi if _issue.is_empty() else _issue + "+" + quoi



## Rôles « manche-hote » et « manche-client » (phase 14, voir l'en-tête) : du salon à une manche
## jouée, jusqu'au départ de l'hôte.
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
	if hote and _options.has("gel"):
		# Tout le processus se fige, comme un hôte qui charge ou compile ses shaders : ses clients
		# chargent pendant ce temps, et leurs « scène chargée » l'attendent.
		print("GEL")
		OS.delay_msec(int(float(_option("gel", "0")) * 1000.0))
	_check(await _attendre(func() -> bool: return manche.barriere), "la barrière de chargement passe")
	_check(_issue.is_empty(), "personne ne s'est cru abandonné pendant le chargement (%s)" % _issue)
	if hote:
		var exclus: Array = manche._exclus
		print("BARRIERE prets=%s exclus=%s" % [manche._prets, exclus])
		_check(manche._prets.size() == int(_option("clients", "0")) - 1 and exclus.size() == 1,
			"les clients chargés sont prêts, le muet est exclu (%s, %s)" % [manche._prets, exclus])
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size() - 1), "un lion par joueur resté (%d)" % main.lions.size())
	var moi: Joueur = gs.joueur_local()
	_check(main.lion != null and main.lion.joueur == moi and main.lion.commandes.source == Commandes.Source.LOCALES
		and main.lions.all(func(l: Node) -> bool: return l == main.lion or l.commandes.source == Commandes.Source.MANUELLES),
		"le lion de ce poste lit ses commandes, les autres ont des commandes manuelles")
	if not hote:
		_check(root.multiplayer.get_peers() == PackedInt32Array([1]) and not root.multiplayer.is_server(),
			"sans relais du serveur, un client ne voit que l'hôte parmi ses pairs (%s)" % [root.multiplayer.get_peers()])
	_check(await _attendre(func() -> bool: return gs.pret), "l'intro se termine chez tous")
	print("INTRO")
	await _jouer_passe(main, int(_option("sens", "1")))
	if hote:
		await _finir_manche_hote(main, manche, gs)
	elif _options.has("partir"):
		main.get_node("PauseMenu").ouvrir()
		await _pause(0.3)
		_check(main.lion.commandes.suspendues and not paused, "le menu local suspend les commandes sans mettre la partie en pause")
		main.get_node("PauseMenu")._on_menu_pressed()  # « Quitter la partie »
		_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not reseau.en_ligne(), "quitter la partie ramène au titre, hors réseau")
		print("PARTI")
	else:
		await _finir_manche_client(main, manche)
	scores.effacer()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))


## La passe de ce poste : descendre jusqu'à la hauteur de peinture (celle du pilote de la démo, 233 px
## au-dessus des toits ; la position du lion de ce poste est celle que l'hôte lui renvoie), puis
## peindre la ville en allant dans le sens `sens`.
func _jouer_passe(main: Node, sens: int) -> void:
	var ville: Node2D = main.get_node("Ville")
	var cible: float = ville.position.y - ville.tex_size.y / 2.0 - 233.0
	Input.action_press("deplacer_bas")
	_check(await _attendre(func() -> bool: return main.lion.position.y >= cible), "le lion de ce poste descend vers la ville (%.0f)" % main.lion.position.y)
	Input.action_release("deplacer_bas")
	var action := "deplacer_droite" if sens > 0 else "deplacer_gauche"
	Input.action_press(action)
	Input.action_press("vomir")
	var pire := 0.0
	var fin := Time.get_ticks_msec() + 2500
	var avant := Time.get_ticks_msec()
	while Time.get_ticks_msec() < fin:
		await process_frame
		pire = maxf(pire, Time.get_ticks_msec() - avant)
		avant = Time.get_ticks_msec()
	Input.action_release(action)
	Input.action_release("vomir")
	print("MESURE %s : %d jeux de tampons en cache, frame la plus longue %.0f ms pendant la passe" % [reseau.pseudo, main.get_node("Ville")._tampons.size(), pire])


## L'empreinte de la manche sur ce poste : territoire (propriétaire compté de chaque cellule), scores,
## tampons (nombre diffusé par l'hôte ou reçu par un client, et l'empreinte de leur suite), lions
## (position, orientation, crans, étourdi, gerbe XXL), apparitions (ennemis et pastilles : nom et position). Pas l'image
## de la ville : les mêmes tampons y sont dessinés à l'identique (smoke test), mais une coulure qui
## descend encore quand un tampon la recouvre passe dessus ou dessous selon le rythme de chaque poste.
func _empreinte(main: Node, manche: Node, hote: bool) -> String:
	var ville: Node2D = main.get_node("Ville")
	var territoire: Territoire = ville.territoire
	var proprietaires := PackedByteArray()
	proprietaires.resize(territoire.taille_grille.x * territoire.taille_grille.y)
	for i in range(proprietaires.size()):
		proprietaires[i] = territoire.proprietaire_compte(i) + 1
	var lions: Array = main.lions.map(func(l: Node) -> String:
		return "%s:%.1f,%.1f,%d,%d,%s,%s" % [l.name, l.position.x, l.position.y, l.direction_du_lion, l.joueur.crans,
			l.joueur.est_etourdi(), l.joueur.bonus_actif()])
	var scenes: Array[String] = []
	var spawner: MultiplayerSpawner = main.get_node("Apparitions")
	for i in range(spawner.get_spawnable_scene_count()):
		scenes.append(spawner.get_spawnable_scene(i))
	var apparitions: Array[String] = []
	for enfant in main.get_children():
		if scenes.has(enfant.scene_file_path):
			apparitions.append("%s@%.0f,%.0f" % [enfant.name, enfant.position.x, enfant.position.y])
	apparitions.sort()
	return "territoire=%d scores=%s tampons=%d:%d lions=%s apparitions=%s" % [hash(proprietaires), territoire.scores(),
		manche.tampons_diffuses if hote else manche.tampons_recus, manche.empreinte_tampons, ";".join(lions), ";".join(apparitions)]


func _finir_manche_hote(main: Node, manche: Node, gs: Node) -> void:
	var ville: Node2D = main.get_node("Ville")
	_check(await _attendre(func() -> bool: return _departs.size() >= 2), "le client parti en pleine manche (et le muet exclu) sont partis (%d)" % _departs.size())
	var index_parti := -1
	for j: Joueur in gs.joueurs:
		if j.id_reseau == _departs[-1]:
			index_parti = j.index
	var cellules_parti: int = ville.territoire.cellules_de(index_parti)
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size() - 2) and cellules_parti > 0,
		"son lion disparaît, ses cellules restent au territoire (%d)" % cellules_parti)
	print("DEPART VU")
	# Les réactions d'Anna, décidées ici : un cran, la gerbe XXL, un étourdissement (elle les reçoit
	# par la manche ; son empreinte doit les montrer)
	var restants: Array = gs.joueurs.filter(func(j: Joueur) -> bool: return j.id_reseau != 1 and reseau.inscrits.has(j.id_reseau))
	_check(restants.size() == 1, "(pré-condition) il reste un client, Anna")
	if restants.size() == 1:
		var anna: Joueur = restants[0]
		var crans_avant := anna.crans  # une pastille a pu être ramassée pendant sa passe
		gs.regles.pastille_ramassee(anna, 0)
		gs.regles.etoile_ramassee(anna)
		anna.invulnerable_restant = 0.0
		gs.regles.lion_touche_par_ennemi(anna, Vector2.INF)
		_check(anna.crans == mini(crans_avant + 1, Joueur.CRANS_MAX) and anna.bonus_actif() and anna.est_etourdi(),
			"Anna gagne un cran et la gerbe XXL, puis un ennemi l'étourdit")
	var calme := func() -> bool:
		return main.lions.all(func(l: Node) -> bool: return l.velocity == Vector2.ZERO) and ville.coulures.is_empty()
	_check(await _attendre(calme), "les lions s'arrêtent, les coulures finissent")
	await _pause(0.3)
	gs.terminer_partie(false)  # tout se fige chez l'hôte (bataille) ; la manche diffuse encore
	await _pause(1.0)
	_check(ville.territoire.cellules_de(index_parti) == cellules_parti, "les cellules du parti restent jusqu'au bout")
	print("EMPREINTE %s" % _empreinte(main, manche, true))
	print("FIGE")
	if _options.has("rester"):
		var rester := _option("rester", "")
		print("HOTE RESTE")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
	paused = false
	reseau.quitter()


func _finir_manche_client(main: Node, manche: Node) -> void:
	var ville: Node2D = main.get_node("Ville")
	_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("fige", ""))), "l'hôte a figé la manche")
	_check(await _attendre(func() -> bool: return ville.coulures.is_empty()), "les coulures de ce poste finissent")
	await _pause(0.5)  # les dernières positions et cellules de l'hôte figé
	print("EMPREINTE %s" % _empreinte(main, manche, false))
	_check(await _attendre(func() -> bool: return _issue == "hote_perdu"), "l'hôte finit par partir")
	var message: Node = main.get_node_or_null("HotePerdu/Message")
	_check(message != null and message.text == "RESEAU_HOTE_PERDU" and paused, "« L'hôte a quitté la partie » s'affiche, la partie se fige")
	_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not paused and not reseau.en_ligne(),
		"puis retour au titre, hors réseau")


## Rôle « manche-muet » (phase 14) : un joueur prêt qui ne charge jamais sa scène de jeu.
func _jouer_muet() -> void:
	reseau.inscrit.connect(_sur_inscription)
	reseau.hote_perdu.connect(_ajouter_issue.bind("hote_perdu"))
	var lancee := [0]
	reseau.manche_lancee.connect(func(_f: Array[Dictionary]) -> void: lancee[0] = Time.get_ticks_msec())
	_check(reseau.rejoindre("127.0.0.1", int(_option("port", "17777"))) == OK, "le client muet est créé")
	_check(await _attendre(func() -> bool: return _issue == "inscrit"), "le muet est inscrit")
	_check(await _attendre(func() -> bool: return reseau.table_salon.any(func(f: Dictionary) -> bool: return f.id == root.multiplayer.get_unique_id())),
		"le muet est à la table du salon")
	reseau.demander_pret(true)
	_check(await _attendre(func() -> bool: return lancee[0] > 0), "le muet reçoit le lancement de la manche, sans charger de scène")
	var fin := Time.get_ticks_msec() + int((DELAI_ETAPE + float(_option("gel", "0"))) * 1000.0)
	while _issue != "inscrit+hote_perdu" and Time.get_ticks_msec() < fin:
		await process_frame
	var apres: float = (Time.get_ticks_msec() - lancee[0]) / 1000.0
	print("EXCLU apres=%.1f s" % apres)
	_check(_issue == "inscrit+hote_perdu" and apres >= float(_option("delai-chargement", "0")),
		"l'hôte l'exclut après le délai de la barrière (%.1f s)" % apres)

```

- [ ] **Step 2 : le scénario 9**

Dans `tests/reseau/lancer.sh` :

2a. Remplacer :

```bash
#!/usr/bin/env bash
# Test réseau du transport (phase 11), de la découverte (phase 12) et du salon (phase 13) : des
# postes headless sur localhost, un processus Godot par poste (tests/reseau/joueur.gd), scénario
# après scénario.
#   tests/reseau/lancer.sh [port_de_base]
```

par :

```bash
#!/usr/bin/env bash
# Test réseau du transport (phase 11), de la découverte (phase 12), du salon (phase 13) et de la
# manche synchronisée (phase 14) : des postes headless sur localhost, un processus Godot par poste
# (tests/reseau/joueur.gd), scénario après scénario.
#   tests/reseau/lancer.sh [port_de_base]
```

2b. Remplacer :

```bash
	|| echec "salon : le bouton de l'hôte doit s'activer deux fois, et le démarrage être refusé une fois entre les deux"

echo "== $ECHECS échec(s) =="
if [ "$ECHECS" -eq 0 ]; then
```

par :

```bash
	|| echec "salon : le bouton de l'hôte doit s'activer deux fois, et le démarrage être refusé une fois entre les deux"

# 9. Manche synchronisée (phase 14), par les vraies scènes : un hôte, deux clients qui jouent, un
#    muet (prêt au salon, mais qui ne charge jamais sa scène de jeu). L'hôte se fige GEL9 s dès sa
#    scène chargée (ses clients chargent pendant ce temps : ils ne doivent pas le croire parti) ;
#    la barrière de chargement exclut le muet après son délai ; l'intro part chez tous. Chaque poste
#    descend vers la ville et la peint au clavier ; Bruno quitte alors la manche par le menu local :
#    son lion disparaît, ses cellules restent. L'hôte donne à Anna un cran, la gerbe XXL et un
#    étourdissement ; lions arrêtés et coulures finies, il fige la
#    manche et écrit son empreinte (territoire, scores, tampons et leur suite, lions et réactions,
#    apparitions) ; Anna écrit la sienne, qui doit être la même. L'hôte part : Anna voit « L'hôte a
#    quitté la partie », puis le titre.
GEL9=6.5
DELAI_CHARGEMENT9=3
P=$((PORT_BASE + 9))
B=$((PORT_BASE + 1009))
lancer hote9 --role=manche-hote --port=$P --port-balise=$B --pseudo=Hote9 --clients=3 --gel=$GEL9 \
	--delai-chargement=$DELAI_CHARGEMENT9 --sens=1 --rester="$JOURNAUX/rester9"
if attendre_hote hote9; then
	lancer a9 --role=manche-client --port=$P --port-balise=$B --pseudo=Anna --sens=1 --fige="$JOURNAUX/fige9"
	lancer b9 --role=manche-client --port=$P --port-balise=$B --pseudo=Bruno --sens=-1 --partir
	lancer c9 --role=manche-muet --port=$P --port-balise=$B --pseudo=Muet --gel=$GEL9 --delai-chargement=$DELAI_CHARGEMENT9
	# Chaque étape de l'hôte dans ses 15 s : la manche entière en prend plus (le gel, l'intro, les passes).
	if attendre_ligne hote9 "INTRO" && attendre_ligne hote9 "DEPART VU" && attendre_ligne hote9 "FIGE"; then
		touch "$JOURNAUX/fige9"
		attendre_ligne a9 "EMPREINTE" && touch "$JOURNAUX/rester9"
	fi
	touch "$JOURNAUX/fige9" "$JOURNAUX/rester9"
fi
terminer "manche : barrière de chargement (hôte figé, muet exclu), commandes au clavier de chaque poste, tampons, territoire et apparitions répliqués, départ d'un client en pleine manche, hôte perdu"
[ "$(grep -h "^EMPREINTE " "$JOURNAUX/hote9.log" "$JOURNAUX/a9.log" 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
	&& [ "$(compter "^EMPREINTE " hote9 a9)" -eq 2 ] || echec "manche : l'hôte et Anna doivent finir avec la même empreinte"
[ "$(compter "^PARTI" b9)" -eq 1 ] && [ "$(compter "^EXCLU" c9)" -eq 1 ] || echec "manche : Bruno doit partir, le muet être exclu"

echo "== $ECHECS échec(s) =="
if [ "$ECHECS" -eq 0 ]; then
```

- [ ] **Step 3 : le test passe**

Run : `timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $?"; grep -E "❌|✅|== " "$TMPDIR/r.log"`
Expected (mesuré) : `code 0`, 8 lignes ✅ dont « manche : barrière de chargement (hôte figé, muet exclu), commandes au clavier de chaque poste, tampons, territoire et apparitions répliqués, départ d'un client en pleine manche, hôte perdu », `== 0 échec(s) ==`, en 53 s environ (31 s avant : le scénario 9 en ajoute 22, dont le gel de 6,5 s ; dans le `timeout 300` de la CI). Dans les journaux gardés (voir Step 4) : les deux lignes `EMPREINTE territoire=… scores=[…] tampons=N:… lions=Lion1:…;Lion…:… apparitions=…` de `hote9` et `a9` identiques (Anna : un cran de plus que pendant sa passe, gerbe XXL ; étourdie ou non selon que l'hôte fige avant la fin de son étourdissement, la même chose des deux côtés), `BARRIERE prets=[<A>, <B>] exclus=[<muet>]`, `EXCLU apres=9.4 s` chez le muet (le gel plus le délai de 3 s), les lignes `MESURE` (3 jeux de tampons, frame la plus longue 10 à 16 ms chez chaque poste : Écart 13).

- [ ] **Step 4 : Commit, puis le test discrimine**

```bash
git add tests/reseau/joueur.gd tests/reseau/lancer.sh
git commit -m "Test réseau : scénario 9, la manche à plusieurs postes par les vraies scènes (hôte figé pendant le chargement, muet exclu par la barrière, passes de peinture au clavier de chaque poste, réactions données par l'hôte, départ d'un client en pleine manche, mêmes empreintes chez l'hôte et le client resté, hôte perdu)

<ligne fournie par l'environnement>"
```

Puis chaque mutation seule, `bash tests/reseau/lancer.sh` (ou le seul scénario 9 : copier le script sans les scénarios 1 à 8 dans `$TMPDIR`, jamais dans le dépôt), et **`git checkout -- Scripts/ tests/`** avant la suivante (mesuré en préparant le plan ; `Scripts/Reseau.gd` n'est jamais muté) :
- N1 (les silences par défaut d'ENet, par le harnais) : dans `tests/reseau/joueur.gd`, `_jouer_manche`, ajouter `reseau.definir_silence(Vector2i(5000, 30000))` juste après la ligne `var manche: Node = main.get_node("Manche")` ⇒ chez `a9` : `❌ la barrière de chargement passe`, `❌ personne ne s'est cru abandonné pendant le chargement (hote_perdu)` (le client lâche l'hôte figé au bout de 5 s) ;
- N2 : dans `Manche._verifier_barriere`, `if _temps_chargement >= delai_chargement:` → `if Time.get_ticks_msec() / 1000.0 >= delai_chargement:` (l'horloge murale) ⇒ chez `hote9` : `❌ les clients chargés sont prêts, le muet est exclu ([], [<trois identifiants>])` (au réveil de l'hôte figé, tout le monde est exclu) ;
- N3 : dans `Manche._recevoir_crans`, remplacer les deux lignes `if j != null and crans is int:` / `j.recevoir_crans(crans)` par `pass` ⇒ `❌ manche : l'hôte et Anna doivent finir avec la même empreinte` (la comparaison croisée de `lancer.sh` : chez Anna, son lion n'a pas le cran donné par l'hôte).

Pour garder les journaux d'un passage vert (le lanceur les efface) : `sed 's/^\trm -rf "\$JOURNAUX"/\t: rm -rf/' tests/reseau/lancer.sh > "$TMPDIR/garde.sh"`, copier `garde.sh` dans `tests/reseau/` le temps d'un passage, puis le supprimer (jamais commité).

Expected ensuite : `git status --short` vide.

- [ ] **Step 5 : les suites, 5 fois**

Run : 5 fois de suite chacune des trois suites Godot et `bash tests/reseau/lancer.sh`, puis 5 fois `/bin/bash tests/reseau/lancer.sh` (bash 3.2 de macOS).
Expected : chaque fois `code 0` et `== 0 échec(s) ==`, aucune `SCRIPT ERROR` ni `SHADER ERROR` (mesuré en préparant le plan : 5 × 4 suites vertes, et 5 × le test réseau sous bash 3.2 ; unitaires 2 s, smoke test 19 s, bataille 4 s, test réseau 53 s).

---

### Task 9 : ◉ la partie à 2 fenêtres (non commitée)

**Files:**
- Create (scratchpad de l'exécutant, jamais dans le dépôt) : `<scratchpad>/deux_fenetres.gd`

**Interfaces:**
- Consumes : Tasks 1 à 7 (écran Réseau, salon, `Main.lion`, `Main/PauseMenu`, `HotePerdu`).
- Produces : 9 captures PNG dans `<scratchpad>/captures-14/`, montrées à l'utilisateur.

- [ ] **Step 1 : le script**

Créer `<scratchpad>/deux_fenetres.gd` :

```gdscript
extends SceneTree
## ◉ Partie à 2 fenêtres (phase 14, non commité) : deux vraies fenêtres de jeu sur ce Mac, un hôte et
## un client, qui passent par l'écran Réseau et le salon, puis jouent une manche au clavier simulé :
##   godot --path <dépôt> --rendering-driver opengl3 --script <ce fichier> -- --role=hote|client --dossier=<dossier>
## Rendu réel (pas headless). N'utilise ni le port 7777 ni le 7778 d'une vraie partie. Chaque fenêtre
## capture sa vue de la manche au même instant (fichiers de rendez-vous dans le dossier), puis le
## client capture « L'hôte a quitté la partie ».

const PORT := 17990
const PORT_BALISE := 18990

var dossier := ""
var role := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dossier="):
			dossier = arg.trim_prefix("--dossier=")
		elif arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	call_deferred("_run")


func _attendre(condition: Callable, secondes := 30.0) -> bool:
	var fin := Time.get_ticks_msec() + int(secondes * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < fin:
		await process_frame
	return condition.call()


func _pause(secondes: float) -> void:
	await create_timer(secondes).timeout


func _scene_est(nom: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://Scenes/%s.tscn" % nom and current_scene.is_node_ready()


func _shot(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var chemin := dossier.path_join("%s_%s.png" % [role, nom])
	image.save_png(chemin)
	print("📸 %s (%dx%d, fenêtre %s)" % [chemin, image.get_width(), image.get_height(), DisplayServer.window_get_size()])


func _rendez_vous(nom: String) -> void:
	FileAccess.open(dossier.path_join("%s_%s" % [role, nom]), FileAccess.WRITE).store_string("ok")
	var autre := "client" if role == "hote" else "hote"
	await _attendre(func() -> bool: return FileAccess.file_exists(dossier.path_join("%s_%s" % [autre, nom])))


func _run() -> void:
	if dossier.is_empty() or not role in ["hote", "client"]:
		printerr("--role=hote|client et --dossier=<chemin>")
		quit(1)
		return
	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	var scores: Node = root.get_node("Scores")
	root.get_node("Parametres").definir_langue("fr")
	scores.chemin = "user://scores_deux_fenetres_%s.cfg" % role
	decouverte.port_balise = PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	# Une fenêtre, même si les réglages de ce Mac demandent le plein écran (préférence non modifiée) :
	# `Regles.appliquer_ecran` ne règle que les fenêtres.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await _pause(0.5)
	DisplayServer.window_set_position(Vector2i(20, 40) if role == "hote" else Vector2i(740, 440))
	DisplayServer.window_set_size(Vector2i(700, 227))  # la fenêtre du solo, en plus petit : deux tiennent à l'écran
	change_scene_to_file("res://Scenes/EcranReseau.tscn")
	await _attendre(func() -> bool: return _scene_est("EcranReseau"))
	var ecran: Node = current_scene
	ecran.port_jeu = PORT
	ecran.champ_pseudo.text = "Hôte" if role == "hote" else "Invitée"
	if role == "hote":
		ecran.heberger()
	else:
		await _pause(1.0)
		ecran.champ_ip.text = "127.0.0.1"
		ecran.rejoindre_par_ip()
	await _attendre(func() -> bool: return _scene_est("Salon"))
	var salon: Node = current_scene
	if role == "hote":
		await _attendre(func() -> bool: return reseau.table_salon.size() == 2)
	salon.basculer_pret()
	await _pause(0.5)
	await _shot("0_salon")
	if role == "hote":
		await _attendre(func() -> bool: return not salon.bouton_demarrer.disabled)
		salon.demarrer()
	await _attendre(func() -> bool: return _scene_est("Main"))
	var main: Node = current_scene
	var gs: Node = root.get_node("GameState")
	await _attendre(func() -> bool: return gs.pret)
	# La passe : descendre vers la ville, puis la peindre vers l'autre joueur
	var ville: Node2D = main.get_node("Ville")
	var cible: float = ville.position.y - ville.tex_size.y / 2.0 - 233.0
	Input.action_press("deplacer_bas")
	await _attendre(func() -> bool: return main.lion != null and main.lion.position.y >= cible, 5.0)
	Input.action_release("deplacer_bas")
	var sens := "deplacer_droite" if role == "hote" else "deplacer_gauche"
	Input.action_press(sens)
	Input.action_press("vomir")
	await _pause(1.5)
	await _rendez_vous("en_vol")
	await _shot("1_manche")
	await _pause(1.5)
	Input.action_release(sens)
	Input.action_release("vomir")
	await _pause(1.0)
	await _rendez_vous("peint")
	await _shot("2_ville_peinte")
	if role == "hote":
		main.get_node("PauseMenu").ouvrir()
		await _pause(0.3)
		await _shot("3_menu_local")
		await _rendez_vous("fin")
		reseau.quitter()
		await _pause(0.5)
	else:
		await _rendez_vous("fin")
		await _attendre(func() -> bool: return main.get_node_or_null("HotePerdu") != null, 5.0)
		await _shot("3_hote_perdu")
		await _attendre(func() -> bool: return _scene_est("Titre"), 5.0)
		await _pause(0.3)
		await _shot("4_titre")
	scores.effacer()
	quit(0)
```

- [ ] **Step 2 : les captures**

Run : `export PATH="/opt/homebrew/bin:$PATH"; S=<scratchpad>; mkdir -p $S/captures-14; (timeout -k 5 120 godot --path . --rendering-driver opengl3 --script $S/deux_fenetres.gd -- --role=hote --dossier=$S/captures-14 > "$TMPDIR/f_hote.log" 2>&1 &); sleep 2; timeout -k 5 120 godot --path . --rendering-driver opengl3 --script $S/deux_fenetres.gd -- --role=client --dossier=$S/captures-14 > "$TMPDIR/f_client.log" 2>&1; echo "code $?"; sleep 1; grep -hE "📸|SCRIPT ERROR|❌" "$TMPDIR/f_hote.log" "$TMPDIR/f_client.log"`
Expected (mesuré) : `code 0`, 9 lignes 📸 : `hote_0_salon` à `hote_3_menu_local` et `client_0_salon` à `client_3_hote_perdu` en 2000×1125 dans une fenêtre de 700×394 (16:9), `client_4_titre` en 2000×648 dans une fenêtre revenue à 700×226 ; aucune `SCRIPT ERROR`. (Deux fenêtres s'ouvrent le temps du script ; si le réglage « plein écran » de ce Mac est actif, le script les force en fenêtre sans changer la préférence.)

- [ ] **Step 3 : regarder, puis montrer à l'utilisateur**

Vérifier sur les images (constaté en préparant le plan) :
- `hote_1_manche` et `client_1_manche` (**◉ partie à 2 fenêtres**) : la même scène au même instant dans les deux fenêtres : le lion rouge « Hôte » et le lion bleu « Invitée », leurs gerbes, la même peinture sur la ville, le même ennemi ou la même pastille, un étourdissement éventuel (étoiles, barbouillage) visible des deux côtés ;
- `hote_2_ville_peinte` et `client_2_ville_peinte` : la même ville peinte (rouge d'un côté, bleu de l'autre, coulures) ;
- `hote_3_menu_local` : « La partie continue », Continuer / Réglages / Quitter la partie, la partie visible derrière ;
- `client_3_hote_perdu` : « L'hôte a quitté la partie » sur la ville figée (sans lions : Écart 7) ; `client_4_titre` : le titre, fenêtre revenue au format du solo.

Montrer au moins `hote_1_manche`, `client_1_manche`, `hote_3_menu_local` et `client_3_hote_perdu` à l'utilisateur : **l'aspect du menu local (Écart 6) et du message d'hôte perdu (Écart 7), le HUD du solo encore affiché en bataille (phase 17) sont à lui faire valider**. Rien à commiter.

---

### Task 10 : feuille de route et spec

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`

**Interfaces:**
- Consumes : Tasks 1 à 9, Écarts 1 à 16 ; la feuille de route telle que la phase 14 bis l'a laissée.
- Produces : plus aucun point de vigilance « phase 14 » ouvert ; restes réaffectés aux phases 15 (jeux de tampons), 16 (envoi des commandes, silences, interpolation, disparition des répliques, pertes), 17 (joueur parti grisé, secondes de la gerbe XXL chez un client, fin de manche), 17 bis (annonce du peintre, boucle de vomi), 18 (raison de l'exclusion, remise à zéro du territoire et du Spawner), 19 (fenêtre par défaut, captures) ; découpage de `Lion.gd` après la 15.

- [ ] **Step 1 : la feuille de route**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` :

1a. Remplacer :

```text
| 12 bis | **Écran Réseau** : pseudo mémorisé, Héberger, liste des parties, Rejoindre par IP, textes des refus et des échecs, bouton Multijoueur du titre, `Titre._ready` hors réseau. | ➕ `Scenes/EcranReseau.tscn` ➕ `Scripts/EcranReseau.gd` ✏️ `Scripts/Titre.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `tests/smoke_test.gd` | ◉ écran Réseau |
| 13 | **Salon** : cartes, couleurs, Prêt, niveau, bouton Démarrer de l'hôte (pas de compte à rebours, décision de l'utilisateur), lancement de la manche chez tous (index compactés, `configurer_bataille_reseau`), table et protocole du salon dans `Reseau`, l'écran Réseau qui passe la main, `rejoindre()` limité aux IPv4, version 0.13. Plafond de 5 fichiers levé. | ➕ `Scenes/Salon.tscn` ➕ `Scripts/Salon.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/GameState.gd` ✏️ `Scripts/Regles.gd` ✏️ `Scripts/EcranReseau.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | ◉ salon à 3, test réseau vert 5 fois (bash 3.2 et 5) |
| 14 | **Manche synchronisée** : `MultiplayerSpawner`, `MultiplayerSynchronizer`, commandes par RPC, événements de tampon, scores diffusés. | ✏️ `Scripts/Main.gd` ✏️ `Scenes/Lion.tscn` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Ville.gd` ✏️ `Scripts/ReglesBataille.gd` | ◉ partie à 2 fenêtres |
| 14 bis | **Pastilles vers `body is Lion`** (exécutée avant la 14) : base commune des trois pastilles (garde hôte, `body is Lion`, premier arrivé, premier servi, une réplique ne se libère pas d'elle-même : `_expirer`), sons de ramassage par `Audio` et les signaux du joueur local (un par frame, le cran de bataille compris), recul du peintre horizontal (il pointait vers la ville), durcissements du smoke test de la revue 8 ter. | ➕ `Scripts/Pastille.gd` ✏️ `Scripts/ColorPickup.gd` ✏️ `Scripts/BonusPickup.gd` ✏️ `Scripts/CoeurPickup.gd` ✏️ `Scripts/Audio.gd` ✏️ `Scripts/Boss.gd` ✏️ `tests/smoke_test.gd` | smoke vert, suites vertes 5 fois |
| 15 | **Test réseau de bout en bout** : 1 hôte + 3 clients headless, empreintes identiques, déconnexion d'un client. Le test réseau tourne en CI depuis la phase 11 ter (`ci.yml` n'est plus à toucher). | ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | test vert en CI |
| 16 | **Prédiction du lion local** (4 bis) : correction douce, commandes numérotées et redondantes, interpolation, simulateur de latence. | ➕ `Scripts/PredictionLocale.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Lion.gd` ✏️ `tests/reseau/joueur.gd` | test vert sous 80 ms / 40 ms / 5 % |

### D. Fin de manche et livraison
```

par :

```text
| 12 bis | **Écran Réseau** : pseudo mémorisé, Héberger, liste des parties, Rejoindre par IP, textes des refus et des échecs, bouton Multijoueur du titre, `Titre._ready` hors réseau. | ➕ `Scenes/EcranReseau.tscn` ➕ `Scripts/EcranReseau.gd` ✏️ `Scripts/Titre.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `tests/smoke_test.gd` | ◉ écran Réseau |
| 13 | **Salon** : cartes, couleurs, Prêt, niveau, bouton Démarrer de l'hôte (pas de compte à rebours, décision de l'utilisateur), lancement de la manche chez tous (index compactés, `configurer_bataille_reseau`), table et protocole du salon dans `Reseau`, l'écran Réseau qui passe la main, `rejoindre()` limité aux IPv4, version 0.13. Plafond de 5 fichiers levé. | ➕ `Scenes/Salon.tscn` ➕ `Scripts/Salon.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/GameState.gd` ✏️ `Scripts/Regles.gd` ✏️ `Scripts/EcranReseau.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | ◉ salon à 3, test réseau vert 5 fois (bash 3.2 et 5) |
| 14 | **Manche synchronisée** (après la 14 bis) : lions, ennemis et pastilles apparus chez l'hôte et répliqués (`MultiplayerSpawner`, `MultiplayerSynchronizer` : position, vitesse, orientation, vomi ; côté du peintre, couleur d'une pastille), commandes des clients par RPC (numérotées, silence de 500 ms), tampons diffusés et dessinés à l'identique (`Peinture` : jeux tirés de leur clé, graine u16), territoire et scores diffusés toutes les 0,2 s, réactions des joueurs par RPC, barrière de chargement (exclusion d'un absent), départs et hôte perdu, menu local sans pause, fenêtre en 16:9 hors solo, relais du serveur coupé, départ propre et silences d'ENet, version 0.14. Plafond de 5 fichiers levé. | ➕ `Scripts/Peinture.gd` ➕ `Scripts/Manche.gd` ✏️ `Scripts/Territoire.gd` ✏️ `Scripts/Ville.gd` ✏️ `Scripts/GerbeTraceuse.gd` ✏️ `Scripts/Joueur.gd` ✏️ `Scripts/GameState.gd` ✏️ `Scripts/Regles.gd` ✏️ `Scripts/Titre.gd` ✏️ `Scripts/Salon.gd` ✏️ `Scripts/EcranReseau.gd` ✏️ `Scripts/Reseau.gd` ✏️ `project.godot` ✏️ `Scripts/Ennemi.gd` ✏️ `Scripts/Soucoupe.gd` ✏️ `Scripts/Coccinelle.gd` ✏️ `Scripts/Boss.gd` ✏️ `Scripts/Spawner.gd` ✏️ six scènes d'ennemis et de pastilles ✏️ `Scripts/Lion.gd` ✏️ `Scenes/Lion.tscn` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Main.gd` ✏️ `Scenes/Main.tscn` ✏️ `Scripts/Intro.gd` ✏️ `Scripts/PauseMenu.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | ◉ partie à 2 fenêtres, test réseau vert 5 fois (bash 3.2 et 5) |
| 14 bis | **Pastilles vers `body is Lion`** (exécutée avant la 14) : base commune des trois pastilles (garde hôte, `body is Lion`, premier arrivé, premier servi, une réplique ne se libère pas d'elle-même : `_expirer`), sons de ramassage par `Audio` et les signaux du joueur local (un par frame, le cran de bataille compris), recul du peintre horizontal (il pointait vers la ville), durcissements du smoke test de la revue 8 ter. | ➕ `Scripts/Pastille.gd` ✏️ `Scripts/ColorPickup.gd` ✏️ `Scripts/BonusPickup.gd` ✏️ `Scripts/CoeurPickup.gd` ✏️ `Scripts/Audio.gd` ✏️ `Scripts/Boss.gd` ✏️ `tests/smoke_test.gd` | smoke vert, suites vertes 5 fois |
| 15 | **Test réseau de bout en bout** : le scénario 9 de la phase 14 (1 hôte + 2 clients + un muet exclu, empreintes identiques, départ d'un client, hôte perdu) passe à 1 hôte + 3 clients, une manche plus longue avec pastilles ramassées au vol et chocs ; jeux de tampons remesurés chez un client (point de vigilance ci-dessous). Le test réseau tourne en CI depuis la phase 11 ter (`ci.yml` n'est plus à toucher). | ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | test vert en CI |
| 16 | **Prédiction du lion local** (4 bis), après le découpage de `Lion.gd` (étape à part, voir les points de vigilance) : correction douce, commandes redondantes (la phase 14 les numérote déjà), numéro de la dernière commande traitée répliqué, interpolation, simulateur de latence. | ➕ `Scripts/PredictionLocale.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Manche.gd` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Lion.gd` ✏️ `tests/reseau/joueur.gd` | test vert sous 80 ms / 40 ms / 5 % |

### D. Fin de manche et livraison
```

1b. Remplacer :

```text
  soit jamais retouché.
- Phase 14 : tout lion qui n'est pas celui du joueur local doit recevoir `joueur` et `commandes`
  avant `add_child`, via la `spawn_function` du `MultiplayerSpawner` (en local, c'est
  `Main._ajouter_lions` depuis la phase 10 bis, vérifié par `tests/bataille_test.gd`) ; sinon il
  prend en silence le joueur local et le clavier de ce poste. La fenêtre garde sa taille du solo
  (1400×454) : en 16:9, la bataille s'y affiche avec des bandes ; régler la fenêtre pour la partie
  à 2 fenêtres de la phase 14, puis dans `project.godot` en phase 19. En bataille, Échap ouvre
  encore la pause du solo (`PauseMenu` met l'arbre en pause) : en réseau, un menu local sans pause
  (spec §4). Le `$Lion` de `Scenes/Main.tscn` n'est `lions[0]`, `joueurs[0]` et `joueur_local()` à
  la fois que sur l'hôte et en solo : sur un client (`joueur_local()` = `joueurs[k]`, k ≠ 0),
  `_ajouter_lions` ferait deux lions pour `joueurs[k]` et aucun pour l'hôte. En bataille réseau,
  créer tous les lions par le spawner, par index (`joueur = joueurs[i]`, commandes `LOCALES` pour
  `joueur_local()` seulement) ; `Main.lion` devient le lion de `joueur_local()` et `$Lion` ne sert
  plus qu'au solo.
- Phase 16 : `PredictionLocale` lit Input une seule fois par tick physique, l'écrit dans les
  commandes MANUELLES du lion local et envoie exactement cette valeur, numérotée (direction et
  vomir échantillonnés au même tick). La prédiction locale doit appliquer la même borne
  `Lion._marge_haute()` que l'hôte (phase 10 ter) ; cela ne tient que si la visibilité de
  l'étiquette (couleur et pseudo du joueur) est identique sur chaque machine.
- Phases 14 et 16 : sans paquet d'un client depuis N ms, l'hôte remet à zéro les commandes
  manuelles de son lion.
- Les sous-ressources des scènes instanciées plusieurs fois (formes, matériaux) sont partagées :
```

par :

```text
  soit jamais retouché.
- (résolu en phase 14) en bataille réseau, `$Lion` (le lion du solo) est retiré dès le `_ready` de
  la scène de jeu ; tous les lions apparaissent par le `MultiplayerSpawner` de la scène
  (`Main.apparitions`), par l'index de leur joueur, dont la `spawn_function` (`Main._creer_lion`)
  donne joueur, commandes (`LOCALES` pour `joueur_local()` seulement) et place de départ avant
  l'ajout ; `Main.lion` est le lion de `joueur_local()`. Échap y ouvre un menu local sans pause
  (« La partie continue », « Quitter la partie »), qui suspend les commandes de ce poste
  (`Commandes.suspendues`). Hors du solo, la fenêtre prend le format 16:9
  (`Regles.appliquer_ecran`, 1400×788) ; **phase 19** : la taille de la fenêtre par défaut dans
  `project.godot` reste à régler ;
- Phase 16 : `PredictionLocale` lit Input une seule fois par tick physique, l'écrit dans les
  commandes MANUELLES du lion local et envoie exactement cette valeur, numérotée (direction et
  vomir échantillonnés au même tick). La prédiction locale doit appliquer la même borne
  `Lion._marge_haute()` que l'hôte (phase 10 ter) ; cela ne tient que si la visibilité de
  l'étiquette (couleur et pseudo du joueur) est identique sur chaque machine. Depuis la phase 14,
  c'est `Manche._envoyer_commandes` qui envoie, à chaque tick physique (priorité 100, après les
  lions), les commandes du lion de ce poste (`LOCALES`) : `PredictionLocale` doit écrire avant
  (priorité plus basse) et `Manche` envoyer ce qu'elle a écrit, avec les 3 précédentes (le numéro
  existe déjà, `Manche._numero`, et l'hôte ignore un numéro déjà vu) ;
- (résolu en phase 14) sans commande d'un client depuis `Manche.SILENCE_COMMANDES` (500 ms), l'hôte
  remet son lion au repos (`Manche.verifier_silences`). **Phase 16** : garder ce délai au-dessus de
  la latence simulée (80 ms + 40 ms de gigue) ;
- Les sous-ressources des scènes instanciées plusieurs fois (formes, matériaux) sont partagées :
```

1c. Remplacer :

```text
  `load(...).get_base_script().resource_path` ; le groupe « lion » ne sert plus qu'au Spawner ;
- phase 14 : le Spawner ne tourne que sur l'hôte ; ennemis et pastilles sont répliqués par l'hôte
  (`MultiplayerSpawner`), jamais simulés côté client (`Coccinelle._ready` tire des valeurs
  aléatoires) ; les gestionnaires de contact sont déjà inertes côté client
  (`multiplayer.is_server()`, phase 4 ; pour les ennemis, dans la base `Ennemi` depuis la phase
  8 ter, vérifié par le smoke test sur un sous-arbre dont le pair est un client ENet jamais
  connecté : `SceneTree.set_multiplayer(api, chemin)`, technique réutilisable pour les pastilles
  et la ville) ;
- **phase 14** : les ennemis ne doivent pas tourner côté client (`Coccinelle` tire des valeurs
  aléatoires dans `_ready`, la soucoupe et la coccinelle bougent et se libèrent localement, le
  peintre lance ses tweens et `Audio.jouer("boss")`) : `Ennemi` est l'endroit naturel pour cette
  garde, mais en Godot 4 le `_ready` / `_physics_process` d'une sous-classe n'appelle pas celui du
  parent — utiliser `_notification(NOTIFICATION_READY)` (appelé pour chaque script de la chaîne)
  ou des appels `super()` explicites ;
- (résolu en phase 14 bis) durcissements de la revue 8 ter : `create_client` vérifié `OK`, intrus
```

par :

```text
  `load(...).get_base_script().resource_path` ; le groupe « lion » ne sert plus qu'au Spawner ;
- (résolu en phase 14) le Spawner ne tourne que sur l'hôte (`Spawner.demarrer()`, appelé par la
  scène de jeu : hors réseau dans son `_ready`, en réseau après la barrière de chargement) ;
  ennemis et pastilles apparaissent chez chaque client par le `MultiplayerSpawner` de la scène de
  jeu (noms lisibles, `add_child(..., true)`), leur `MultiplayerSynchronizer` (`Synchro`) en recopie
  la position (et le côté du peintre, l'inclinaison de la coccinelle, la couleur d'une pastille) ;
  un client ne les simule jamais ;
- (résolu en phase 14) les ennemis ne tournent pas côté client : chacun commence son `_ready` et
  son `_physics_process` par `Ennemi.est_replique()` (ni hasard, ni déplacement, ni tween, ni
  libération) ; le peintre applique le côté reçu (`Boss.cote`, setter). **Phase 17 bis** :
  l'annonce du peintre (`Audio.jouer("boss")`, dans `Boss._changer_etat` de l'hôte) ne s'entend
  que chez l'hôte : la faire entendre aux clients (réplique de `Boss.etat`, ou RPC de la manche) ;
- (résolu en phase 14 bis) durcissements de la revue 8 ter : `create_client` vérifié `OK`, intrus
```

1d. Remplacer :

```text
  poussait le lion vers la ville ; corrigé (`lion.global_position.y + Lion.CENTRE.y`) ;
- **phase 14** : sur un client, la ville a aussi un territoire (les règles de bataille y sont
  branchées) mais `Ville.peindre` n'y touche pas (`multiplayer.is_server()`, phase 9 bis) : lui
  appliquer la liste des cellules reçue de l'hôte (`Territoire.extraire_changements()` chez
  l'hôte, index u16 + propriétaire u8) par une méthode d'affichage à ajouter à `Territoire`
  (propriétaire compté posé tel quel, sans charge), d'où les mêmes scores chez tous ; ne jamais y
  rejouer `tamponner`. La traceuse ne peint que sur l'hôte (`multiplayer.is_server()` dans
  `GerbeTraceuse._physics_process`, ou appel depuis le relais de `Main`) : sinon le
  `MultiplayerSynchronizer` qui réplique le vomi met `monitoring = true` sur chaque réplique et
  chaque client peindrait localement un premier tampon avec ses propres tirages, en double de
  celui diffusé par l'hôte. Les clients peignent seulement les tampons reçus
  (`Ville.peindre(position, rayon, GameState.joueurs[index])`). Le tampon diffusé porte l'index du
  joueur : `Ville.peindre(position, rayon, peintre)` prend déjà un `Joueur`. Le motif et les
  coulures d'un tampon viennent encore du hasard global (`randi`, `randf`), ce qui ne suffit pas
  avec le cache (chaque machine génère ses `NB_TAMPONS` variantes séparément au premier usage) :
  amorcer `_generer_tampons` avec un `RandomNumberGenerator` dont la graine est dérivée de
  `_cle_tampons(...).hash()`, puis choisir la variante et tirer les coulures avec la graine u16 du
  tampon (spec §6) ;
- **prochaine phase qui touche `Scripts/Territoire.gd`** (phase 14, méthode d'affichage, ou scinder
  la phase 14 si son plafond de fichiers est dépassé — sa ligne (# 14 ci-dessus) compte déjà 5
  fichiers sans `Territoire.gd`) : le commentaire de `CHARGE_MAX` annonce encore « La phase 10
  rerègle ces constantes sur une vraie manche » ; la phase 10 ter les a gardées (4, 12, 12) et réglé
  l'empreinte du tampon dans la ville (`Ville.EMPREINTE_TERRITOIRE`, spec §6, cibles vérifiées par
  `tests/bataille_test.gd`) : le corriger ; même remarque de plafond pour la méthode d'affichage du
  point ci-dessus (« sur un client, la ville a aussi un territoire ») ;
- **phase 14** : jeux de tampons (`Ville._generer_tampons`), mesurés en phase 10 : 0,5 ms (16 px)
  à 3,7 ms (46 px), 14,6 ms pour l'étoile XXL (92 px), 65 ms pour les 14 jeux d'un joueur ; sur la
  manche à 4 pilotée de `tests/bataille_test.gd` (ligne `MESURE jeux de tampons`, 5 passages), 16 à
  18 jeux générés, au plus 2 dans une même frame (2 sur trois passages, 1 sur les deux autres).
  Décision de la phase 10 bis : pas de pré-génération en local. En phase 14, chaque client génère
  aussi ses jeux (graine dérivée de la clé) : les pré-générer pendant l'intro (nuances de joueur, 7
  rayons, ×2) si la mesure sur un client montre des à-coups. Mémoire du cache plein : environ
  14,5 Mo pour 6 joueurs ;
- **phase 14** : un client qui part en cours de manche arrive chez l'hôte par
  `Reseau.joueur_parti(id)` (id réseau, à retrouver par `Joueur.id_reseau`) ; un hôte perdu, chez
  chaque client, par `Reseau.hote_perdu` (le poste est alors déjà hors réseau) ;
- **phase 14** : les réactions du `Joueur` sont des appels de méthode qui émettent des signaux
  (`debloquer_couleur`, `activer_bonus`, `encaisser_coup`, `gagner_cran`, `etourdir`, et `avancer`
  pour `etourdissement_fini`). Un `MultiplayerSynchronizer` qui écrit les champs bruts n'émettrait
  rien chez les clients (HUD, Audio, Lion muets) : choisir des RPC d'événement qui appellent les
  mêmes méthodes du `Joueur`, ou des setters qui émettent. De même, `GameState._process` ferait
  avancer les copies des clients (`Joueur.avancer`) : l'hôte seul décompte ;
- **phase 19** (qui touche `tests/screenshots.gd`) : le coup de `tests/screenshots.gd` (vers la
```

par :

```text
  poussait le lion vers la ville ; corrigé (`lion.global_position.y + Lion.CENTRE.y`) ;
- (résolu en phase 14) sur un client, la ville ne tamponne jamais son territoire : elle applique
  les cellules changées reçues de l'hôte (`Territoire.appliquer_changements`, index u16 +
  propriétaire compté u8) et vérifie les scores reçus avec elles ; la traceuse ne peint que sur
  l'hôte (`GerbeTraceuse._physics_process`), dont chaque tampon part en événement
  (`Ville.tampon_peint`, `{index, x, y, rayon, graine}`) ; un client dessine les tampons reçus
  (`Ville.peindre_tampon_recu`). Jeux de tampons tirés de leur clé
  (`Peinture.generer_tampons`, graine `cle_tampons(...).hash()`), variante et coulure tirées de la
  graine u16 du tampon (`Peinture.tirage`), plafond des coulures compté en tampons (40 sur les
  120 derniers) : chaque poste dessine les mêmes tampons et lance les mêmes coulures ; seule une
  coulure qui descend encore quand un tampon la recouvre peut passer dessus ou dessous selon le
  rythme d'affichage de chaque poste (détail visuel accepté, spec §6) ;
- (résolu en phase 14) le commentaire de `Territoire.CHARGE_MAX` dit ce que la phase 10 ter a
  gardé ; la méthode d'affichage d'un client est `Territoire.appliquer_changements` ;
- **phase 15** (jeux de tampons, mesurés en phase 10, remesurés en phase 14) : chaque client génère
  ses jeux au premier usage (`Peinture.generer_tampons`, graine tirée de la clé : le même jeu
  quel que soit le moment). Scénario 9 de la phase 14 (3 postes au premier cran) : 3 jeux en cache
  chez chaque poste, frame la plus longue 10 à 16 ms pendant la passe, chez l'hôte comme chez un
  client (ligne `MESURE` de chaque poste) ; pas de pré-génération. À remesurer en phase 15 (1 hôte
  + 3 clients, crans et gerbes XXL) : pré-générer pendant l'intro (nuances des joueurs, 7 rayons,
  ×2, un jeu par frame) si un client montre des à-coups. Mémoire du cache plein : environ 14,5 Mo
  pour 6 joueurs ;
- (résolu en phase 14) un client qui part en cours de manche arrive chez l'hôte par
  `Reseau.joueur_parti(id)` : la manche retrouve son joueur par `Joueur.id_reseau`, oublie ses
  commandes et son lion disparaît chez tous (disparition répliquée) ; un hôte perdu arrive chez
  chaque client par `Reseau.hote_perdu` : « L'hôte a quitté la partie » sur la partie figée, puis
  le titre. **Phase 17** : le joueur parti reste au classement en grisé (le `Joueur` n'a pas encore
  d'état « parti » ; son lion disparu le dit) ;
- (résolu en phase 14) les réactions d'un joueur (étourdissement et sa fin, crans, gerbe XXL et sa
  fin) partent de l'hôte en RPC fiables de la manche, qui appellent chez chaque client les méthodes
  du `Joueur` qui émettent les mêmes signaux (`etourdir`, `activer_bonus`, `recevoir_crans`,
  `recevoir_fin_etourdissement`, `recevoir_fin_bonus`) ; `GameState._process` ne décompte les
  minuteries des joueurs que sur l'hôte. **Phase 17** : sur un client, `Joueur.bonus_restant`
  reste celui reçu au début de la gerbe XXL (seule sa fin arrive) : le HUD de bataille décompte
  lui-même, ou ne montre pas les secondes ;
- **phase 19** (qui touche `tests/screenshots.gd`) : le coup de `tests/screenshots.gd` (vers la
```

1e. Remplacer :

```text
  30 s écoulées, mélodie à 60 s), mais au rythme du chrono, pas des mesures de couverture ;
- **phase 14** : quand un joueur quitte la manche, ses cellules restent au classement (spec §4)
  mais `Territoire` n'a pas encore d'opération pour les libérer ou les geler : à décider avec la
  gestion des déconnexions ;
- **phase 18** : le territoire de la ville ne se remet à zéro que dans `charger_skyline` ; si
  « Revanche » ou « Niveau suivant » relance une manche sur la même ville sans y repasser, les
  scores et les tampons dessinés de la manche précédente restent. Chaque nouvelle manche doit donc
  soit repasser par `charger_skyline`, soit appeler `ville.territoire.reinitialiser()` après avoir
  vidé `extraire_changements()` (contrainte déjà notée dans `Territoire.gd:64-66`). Coordonner
  l'ordre de ce message avec la diffusion des scores de la phase 14. Même chose pour le Spawner :
  en fin de manche ses minuteries s'arrêtent et la chaîne des pastilles s'interrompt, et son
  `_ready` (première pastille, création des minuteries) ne repasse pas ; une nouvelle manche
  recharge la scène, ou le Spawner reçoit un `relancer()` explicite ;
- (résolu en phase 14 bis) le commentaire de `Boss.acceleration_max` suit l'avancement des règles ;
- **phase 14** (réaffecté par la phase 13) : `Lion.appliquer_apparence()` se rappelle à la main
  quand la couleur ou le pseudo d'un joueur change. Le salon ne change jamais un `Joueur` sous un
  lion existant (son aperçu est un `TextureRect` teinté par le shader du lion, et
  `configurer_bataille_reseau` écrit la table avant le chargement de la scène de jeu) : si la
  synchronisation de la phase 14 réécrit couleur ou pseudo d'un joueur dont le lion existe déjà,
  donner à `Joueur.couleur` et `Joueur.pseudo` des setters qui émettent `apparence_changee`, auquel
  le lion s'abonne ; sinon, retirer ce point ;
- activer `rendering/viewport/hdr_2d` changerait les valeurs lues par `Shaders/Lion.gdshader` et
  décalerait ses seuils de masque (valeur, saturation) : refaire alors la planche de contrôle de la
  phase 7 et régler les seuils ;
- **phase 14** : sur un client, seul le lion local se déplace (`move_and_slide`, `_recul`,
  blocage entre lions par `_bloquer_contre_les_lions`) ; les lions distants ne reçoivent que les
  réactions visuelles (secousse, étoiles, barbouillage, clignotement) et leur position répliquée.
  `velocity` doit donc être répliquée : le calcul d'approche des chocs
  (`Lion._on_pare_chocs_area_entered`) la lit ;
- **avant la phase 16** : `Lion.gd` a grossi phase après phase (pare-chocs, présentation de
  l'étourdissement, zones de contact de la gerbe) ; le découper en composants avant d'y ajouter la
  prédiction, en une étape à part (≤ 5 fichiers : `Lion.gd`, `Scenes/Lion.tscn`, 2 à 3 nouveaux
  scripts) ;
- **phase 16** : seul le lion local simule son choc, par sa propre prédiction
```

par :

```text
  30 s écoulées, mélodie à 60 s), mais au rythme du chrono, pas des mesures de couverture ;
- (résolu en phase 14) un joueur parti garde ses cellules telles quelles (spec §4) : aucune
  opération de `Territoire` n'est nécessaire, les autres peuvent les lui voler ;
- **phase 18** : le territoire de la ville ne se remet à zéro que dans `charger_skyline` ; si
  « Revanche » ou « Niveau suivant » relance une manche sur la même ville sans y repasser, les
  scores et les tampons dessinés de la manche précédente restent. Chaque nouvelle manche doit donc
  soit repasser par `charger_skyline`, soit appeler `ville.territoire.reinitialiser()` après avoir
  diffusé les derniers changements (`Manche._diffuser_territoire`, toutes les 0,2 s depuis la
  phase 14, y compris l'arbre en pause) et prévenu les clients par leur propre message. Même chose
  pour le Spawner : en fin de manche ses minuteries s'arrêtent et la chaîne des pastilles
  s'interrompt ; `Spawner.demarrer()` (phase 14) ne repart pas une seconde fois : une nouvelle
  manche recharge la scène, ou le Spawner reçoit un `relancer()` explicite ; la barrière de
  chargement (`Reseau.scenes_chargees`, vidée par `lancer_manche`) suppose aussi une scène
  rechargée ;
- (résolu en phase 14 bis) le commentaire de `Boss.acceleration_max` suit l'avancement des règles ;
- (sans objet depuis la phase 14) aucune couleur ni aucun pseudo de `Joueur` ne change sous un lion
  existant : la table des joueurs est posée avant la scène de jeu et la `spawn_function` la lit ;
  pas de setters `apparence_changee` ;
- activer `rendering/viewport/hdr_2d` changerait les valeurs lues par `Shaders/Lion.gdshader` et
  décalerait ses seuils de masque (valeur, saturation) : refaire alors la planche de contrôle de la
  phase 7 et régler les seuils ;
- (phase 14) sur un client, aucun lion ne se déplace de lui-même (`Lion._suivre_l_hote`) : position,
  vitesse, orientation et vomi viennent du `Synchro` du lion (`velocity` comprise, que lit le calcul
  d'approche des chocs) ; chaque réplique garde ses réactions visuelles (secousse du pare-chocs,
  étoiles, barbouillage, clignotement). **Phase 16** : seul le lion local reprend `move_and_slide`,
  `_recul` et `_bloquer_contre_les_lions`, par sa prédiction ; les lions distants sont interpolés
  (le `Synchro` réplique à 83 Hz au plus, `replication_interval` 0,012 s, sans interpolation en
  phase 14) ;
- **avant la phase 16, après la 15** : `Lion.gd` a grossi phase après phase (pare-chocs,
  présentation de l'étourdissement, zones de contact de la gerbe, réplique de la phase 14 : 530
  lignes) ; le découper en composants avant d'y ajouter la prédiction, en une étape à part
  (`Lion.gd`, `Scenes/Lion.tscn`, 2 à 3 nouveaux scripts). Pas en phase 14 : ses ajouts au lion y
  sont petits et isolés (la réplique, deux propriétés répliquées), alors que le découpage réécrit
  les fonctions que le smoke test et `tests/bataille_test.gd` lisent par dizaines de champs privés ;
  le faire après la phase 15 lui donne le filet du test réseau de bout en bout ;
- **phase 16** : seul le lion local simule son choc, par sa propre prédiction
```

1f. Remplacer :

```text
  (pas seulement l'hôte) : c'est ce qui le rend immédiat pour le joueur local (spec §4.1) ;
- **prochaine phase qui touche `Scripts/Regles.gd`** : `Titre._ready` applique aussi
  `taille_ecran()` (retour au titre en solo 2000×648) : étendre le docstring de
  `Regles.taille_ecran()` ("appliquée par `Main` en entrant dans la scène de jeu") avec "et par le
  titre" ;
- la clé du cache des tampons de `Scripts/Ville.gd` dépend de l'ordre des couleurs : le même jeu de
  couleurs dans un ordre différent crée une entrée de cache redondante, pas un mauvais rendu.
  Acceptable en l'état ; à revoir seulement si le cache déborde en pratique.
- **phase 14** (M6 de la revue de la phase 11) : `ENetMultiplayerPeer.close()` (dans `quitter()`)
  envoie `peer_disconnect_now`, un seul datagramme non fiable : en Wi-Fi avec pertes, ou avec un
  poste planté ou en veille, la détection d'un départ repose sur le délai par défaut d'un pair ENet
  (32 essais, 5 à 30 s), donc « l'hôte a quitté la partie » ou la libération d'une carte peuvent
  arriver très en retard. À l'inverse, un hôte dont le thread principal bloque plus de ~5 s (le
  chargement de la scène de manche, la première compilation de shaders sous Windows) déconnecte
  tous ses clients. Régler explicitement `ENetPacketPeer.set_timeout(...)` (court au salon, plus
  tolérant pendant les chargements) et, pour un départ volontaire, utiliser
  `peer_disconnect_later()` (ou un RPC « je pars » fiable avant la fermeture) ;
- **phase 19** (protocole, M7 de la revue de la phase 11) : la version présentée à la poignée de
  main est `application/config/version`, « 0.13 » depuis la phase 13, qui a introduit les premiers
  RPC (ceux du salon, sur l'autoload `Reseau`) : deux postes de phases différentes s'y refusent
  désormais « version différente ». Chaque phase qui change les RPC (14, 16, 18) doit encore
  l'augmenter (« 0.14 »…) ; sinon un `.exe` de CI (Windows) et une version locale (Mac) de phases
  différentes s'accepteraient, puis échoueraient en silence sur des RPC ou des caches de nœuds
```

par :

```text
  (pas seulement l'hôte) : c'est ce qui le rend immédiat pour le joueur local (spec §4.1) ;
- (résolu en phases 13 et 14) le docstring de `Regles.taille_ecran()` nomme le titre ; l'écran est
  appliqué par `Regles.appliquer_ecran` (titre, écran Réseau, salon, scène de jeu) ;
- la clé du cache des tampons de `Scripts/Ville.gd` dépend de l'ordre des couleurs : le même jeu de
  couleurs dans un ordre différent crée une entrée de cache redondante, pas un mauvais rendu.
  Acceptable en l'état ; à revoir seulement si le cache déborde en pratique.
- (résolu en phase 14, M6) `Reseau.quitter()` part proprement : un DISCONNECT fiable d'ENet, envoyé
  tout de suite et renvoyé jusqu'à son accusé de réception (`DELAI_DEPART`, 1 s, en arrière-plan) ;
  un pair muet est considéré parti après `SILENCE_SESSION` (3 à 8 s) au salon et en manche,
  `SILENCE_CHARGEMENT` (20 à 30 s) du lancement de la manche à l'intro (vérifié : un hôte figé
  6,5 s pendant le chargement ne perd personne). **Phase 16** : la robustesse aux pertes du départ
  propre ne se vérifie pas sur localhost ; le simulateur de pertes ne jette que nos propres paquets,
  pas les commandes d'ENet : vérifier à la main en Wi-Fi (phase 19) ;
- **phase 19** (protocole, M7 de la revue de la phase 11) : la version présentée à la poignée de
  main est `application/config/version`, « 0.14 » depuis la phase 14 (« 0.13 » en phase 13, qui a
  introduit les premiers RPC) : deux postes de phases différentes s'y refusent « version
  différente ». Chaque phase qui change les RPC (16, 18) doit encore l'augmenter ; sinon un `.exe` de CI (Windows) et une version locale (Mac) de phases
  différentes s'accepteraient, puis échoueraient en silence sur des RPC ou des caches de nœuds
```

1g. Remplacer :

```text
  parties tous les deux (« Recherche impossible : port 7778 déjà utilisé… Rejoins par IP. ») ;
- **phase 14** (intérim depuis la phase 13) : quand l'hôte démarre la partie, chaque poste branche la
  même table (`GameState.configurer_bataille_reseau`, index compactés) et charge `Main.tscn`, qui
  se joue alors localement : l'hôte simule tous les lions (les autres immobiles, commandes
  manuelles), un client a son lion local en double et aucun lion d'hôte (point « Phase 14 » sur
  `$Lion` plus haut), peinture et ennemis y sont inertes (`multiplayer.is_server()` faux). Échap
  ouvre encore la pause du solo ; « Revenir au menu » ramène au titre, qui quitte le réseau (les
  autres voient partir ce joueur, ou l'hôte). Un `Reseau.hote_perdu` reçu en manche n'est écouté
  par personne : la phase 14 affiche « L'hôte a quitté la partie » et ramène au titre (spec §9) ;
- **phase 18** (retour au salon, depuis la phase 13) : `Reseau.ouvrir_salon(niveau)` remet déjà,
```

par :

```text
  parties tous les deux (« Recherche impossible : port 7778 déjà utilisé… Rejoins par IP. ») ;
- (résolu en phase 14) l'intérim de la phase 13 est fini : la manche est synchronisée ;
- **phase 18** (retour au salon, depuis la phase 13) : `Reseau.ouvrir_salon(niveau)` remet déjà,
```

1h. Remplacer :

```text
  index compactés compris ;
- **phase 14** (hôte perdu en manche, phase 12 bis) : sur l'écran Réseau, « L'hôte a quitté la
  partie » ramène à son accueil (Écart 3 du plan 12 bis) ; en manche, spec §9 : message
  (`RESEAU_HOTE_PERDU`) puis retour au titre ;
- (I1 de la revue finale 12 bis, résolu par la phase 13) : `Decouverte.adresses_hote(interfaces)`
```

par :

```text
  index compactés compris ;
- (résolu en phase 14) hôte perdu en manche : message (`RESEAU_HOTE_PERDU`) sur la partie figée,
  2,5 s, puis retour au titre ;
- (I1 de la revue finale 12 bis, résolu par la phase 13) : `Decouverte.adresses_hote(interfaces)`
```

1i. Remplacer :

```text
  états d'attente ni de nombre de joueurs (remplacés par le salon, qui ne compte que les arrivés) ;
- **phases 14 et 19** (M4 de la revue finale 12 bis) : la fenêtre par défaut (1400×454, phase 10 ter)
  affiche l'écran Réseau (16:9) à 40 % le temps que la fenêtre se règle (phase 14 : passer en 16:9
  hors solo ; phase 19 : captures du fichier jetable dans `tests/screenshots.gd`).
- **phase 14** (revue finale 13, M6) : barrière « scène de jeu chargée ». L'hôte change de scène
  dans l'image où il émet `manche_lancee` ; les clients chargent `Main.tscn` plus tard (aller-retour
  réseau, chargement, compilation des shaders sous Windows). Chaque client envoie un RPC fiable
  `scene_chargee` depuis `Main._ready` ; l'hôte attend tous les arrivés de la manche (avec un délai
  et l'exclusion d'un absent) avant l'intro, les apparitions et la synchronisation ;
- **phase 14** (revue finale 13, M5) : `server_relay` reste actif alors que le jeu n'en a pas besoin
  (tout passe par l'hôte) : le couper (`SceneMultiplayer.server_relay = false`) ;
- **phase 14** (revue finale 13, N9) : commentaire périmé dans `Lion.gd` sur l'origine du joueur
  des lions non locaux, à reprendre avec la `spawn_function` ;
- **phase 14 ou prochaine phase qui touche `Reseau.gd`** (revue finale 13, M1) : `lancer_manche`
  s'engage sans revérifier ses propres fiches (`fiches_de_manche` non vide et cohérent) :
  défense en profondeur, refuser et regriser le bouton sinon ;
- **phase 18** (retour au salon, revue finale 13, M2, M3, M4) : les clients ne voient pas les places
  réservées (pas encore arrivées) ; un stick déjà penché à l'entrée du salon agit une fois ;
  `IP.get_local_interfaces()` est relu à chaque `salon_change` (le mettre en cache à l'ouverture).

```

par :

```text
  états d'attente ni de nombre de joueurs (remplacés par le salon, qui ne compte que les arrivés) ;
- **phase 19** (M4 de la revue finale 12 bis ; la phase 14 règle la fenêtre au format de l'écran,
  `Regles.appliquer_ecran`) : captures du fichier jetable dans `tests/screenshots.gd`, taille de la
  fenêtre par défaut dans `project.godot`.
- (résolu en phase 14, M6 de la revue finale 13) barrière « scène de jeu chargée » :
  `Reseau.signaler_scene_chargee` depuis la manche de chaque poste ; l'hôte attend tous les joueurs
  encore là (`Manche._verifier_barriere`), 20 s de jeu au plus (`Manche.delai_chargement`), puis
  exclut les absents (déconnectés) ; lions, Spawner et intro attendent la barrière. **Phase 18** :
  l'exclu voit « L'hôte a quitté la partie » ; lui envoyer sa raison (RPC avant la déconnexion) ;
- (résolu en phase 14, M5) `server_relay` coupé (`Reseau._ready`) ; un client ne voit que l'hôte
  parmi ses pairs (le test réseau lit les autres joueurs dans la table du salon) ;
- (résolu en phase 14, N9) le commentaire de `Lion.joueur` dit d'où viennent joueur et commandes ;
- (résolu en phase 14, M1) `Reseau.lancer_manche` revérifie ses propres fiches (index compactés,
  `fiches_de_manche` non vide) avant de s'engager ;
- **phase 18** (retour au salon, revue finale 13, M2, M3, M4) : les clients ne voient pas les places
  réservées (pas encore arrivées) ; un stick déjà penché à l'entrée du salon agit une fois ;
  `IP.get_local_interfaces()` est relu à chaque `salon_change` (le mettre en cache à l'ouverture).
- **phase 17 bis** (sons de bataille, depuis la phase 8 bis) : chaque lion, local ou non, appelle
  `Audio.demarrer_vomi` / `arreter_vomi` : un lion qui arrête de vomir coupe la boucle du joueur
  local ; ne la jouer que pour le lion de `joueur_local()` (et un son spatialisé ou plus discret
  pour les autres) ;
- **phase 16** (revue de la phase 14) : chez un client qui perd l'hôte, le moteur fait disparaître
  les nœuds apparus par le `MultiplayerSpawner` (lions, ennemis, pastilles) : le message s'affiche
  sur une ville sans lions (vu sur la capture ◉) ; sans conséquence, la scène revient au titre ;
- **phase 19** (captures, phase 14) : le script jetable de la partie à 2 fenêtres (plan de la phase
  14, Task 9) est à verser avec les autres captures ; il force une fenêtre
  (`DisplayServer.window_set_mode`) : `Regles.appliquer_ecran` ne règle pas une fenêtre en plein
  écran (réglage « plein écran » de `Parametres`) ;
- **phase 17** : la fin de manche n'existe pas encore en réseau : le test réseau fige la manche de
  l'hôte par `GameState.terminer_partie` ; les clients ne le savent pas (le chrono de la phase 17
  devra l'annoncer, et `Manche` diffuse déjà ses derniers tampons et son territoire l'arbre en
  pause) ;

```

- [ ] **Step 2 : la spec**

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` :

2a. Remplacer :

```text
| `Reseau` (autoload) | Pair ENet, poignée de main (version, pseudo), liste des joueurs du salon (la table : arrivés seulement, couleur, Prêt ; tenue par l'hôte, diffusée à chaque changement), attribution des index et couleurs, arbitrage des demandes des clients, relais du niveau et du lancement de la manche, revérifié par l'hôte au moment où il démarre (RPC fiables sur l'autoload, présent sur chaque poste dès la connexion), signaux de connexion / déconnexion et du salon. Le salon (scène) porte le bouton « Démarrer la partie » de l'hôte. | `MultiplayerAPI` |
| `Decouverte` (autoload) | Balise UDP de l'hôte (émise tant que `Reseau` héberge, sans qu'on la relance), écoute et liste des parties entendues, validation d'une adresse IPv4 saisie. Ne nomme aucun autoload (phase 12). | `Reseau` (par son chemin) |
| `Main` | Instancie N lions (via `MultiplayerSpawner` en réseau), applique l'écran des règles branchées avant elle (par le titre ou le salon, jamais par la scène), relaie tampons et scores. | tout le reste |

### 3.2 Flux d'une frame (bataille)
```

par :

```text
| `Reseau` (autoload) | Pair ENet, poignée de main (version, pseudo), liste des joueurs du salon (la table : arrivés seulement, couleur, Prêt ; tenue par l'hôte, diffusée à chaque changement), attribution des index et couleurs, arbitrage des demandes des clients, relais du niveau et du lancement de la manche, revérifié par l'hôte au moment où il démarre (RPC fiables sur l'autoload, présent sur chaque poste dès la connexion), signaux de connexion / déconnexion et du salon. Le salon (scène) porte le bouton « Démarrer la partie » de l'hôte. | `MultiplayerAPI` |
| `Decouverte` (autoload) | Balise UDP de l'hôte (émise tant que `Reseau` héberge, sans qu'on la relance), écoute et liste des parties entendues, validation d'une adresse IPv4 saisie. Ne nomme aucun autoload (phase 12). | `Reseau` (par son chemin) |
| `Main` | Instancie N lions (via `MultiplayerSpawner` en réseau, qui fait aussi apparaître ennemis et pastilles chez les clients), applique l'écran des règles branchées avant elle (par le titre ou le salon, jamais par la scène). | tout le reste |
| `Manche` (nœud de la scène de jeu, phase 14) | En réseau : barrière de chargement (exclusion d'un absent), commandes des clients, tampons et territoire diffusés, réactions des joueurs, départs. Hors réseau, inerte. | `Reseau`, `Ville`, `Joueur` |
| `Peinture` (logique pure, phase 14) | Jeux de tampons tirés de leur clé, tirage d'un tampon par sa graine, format réseau des tampons : chaque poste dessine les mêmes. | rien |

### 3.2 Flux d'une frame (bataille)
```

2b. Remplacer :

```text
4. Les tampons de peinture sont appliqués sur l'hôte et **diffusés sous forme d'événements**.
5. `MultiplayerSynchronizer` réplique position, vitesse, orientation, état de vomi, crans et
   numéro de la dernière commande traitée de chaque lion. Les clients interpolent les lions
   distants et recalent leur lion local (4.1). L'étourdissement, lui, ne se réplique pas comme un
   champ brut : il voyage en événement (RPC hôte → clients qui appelle `Joueur.etourdir` avec la
```

par :

```text
4. Les tampons de peinture sont appliqués sur l'hôte et **diffusés sous forme d'événements**.
5. `MultiplayerSynchronizer` réplique position, vitesse, orientation et état de vomi de chaque lion
   (phase 14, à 83 Hz au plus : environ 15 Ko/s par client à 6 lions, mesurés ; les crans passent en
   événement avec les autres réactions du joueur) ; le numéro de la dernière commande traitée s'y
   ajoute en phase 16, quand les clients interpolent les lions distants et recalent leur lion
   local (4.1). Ennemis et pastilles sont répliqués de même (position ; côté du peintre, couleur
   d'une pastille). L'étourdissement, lui, ne se réplique pas comme un
   champ brut : il voyage en événement (RPC hôte → clients qui appelle `Joueur.etourdir` avec la
```

2c. Remplacer :

```text
  - client perdu en salon : sa carte se libère ;
  - client perdu en manche : son lion disparaît, ses cellules restent, il reste au classement en
    grisé.

### 4.1 Prédiction du lion local
```

par :

```text
  - client perdu en salon : sa carte se libère ;
  - client perdu en manche : son lion disparaît, ses cellules restent, il reste au classement en
    grisé ;
  - client qui n'a pas chargé la scène de jeu 20 s après le lancement (barrière de chargement) :
    exclu, l'hôte le déconnecte, la manche commence sans lui (phase 14) ;
  - un départ volontaire est un DISCONNECT fiable d'ENet, renvoyé jusqu'à son accusé de réception ;
    un poste muet est considéré parti après 3 à 8 s, 20 à 30 s pendant le chargement de la manche.

### 4.1 Prédiction du lion local
```

2d. Remplacer :

```text
  le territoire de l'hôte compte le tampon quand même ; i16 les transporte sans ambiguïté. Chaque
  machine dessine avec la graine reçue : motifs et coulures identiques. Environ 3 Ko/s à 6 joueurs.
- **Synchro du score** : toutes les 0,2 s, l'hôte envoie la liste des cellules dont le
  propriétaire compté a changé (index u16 + propriétaire u8, `Territoire.extraire_changements()`)
  et les scores. Les clients n'effectuent aucun calcul de propriété : leur ville dessine les
  tampons reçus sans toucher à son territoire, auquel elle applique la liste reçue, d'où les
```

par :

```text
  le territoire de l'hôte compte le tampon quand même ; i16 les transporte sans ambiguïté. Chaque
  machine dessine avec la graine reçue : motifs et coulures identiques (phase 14 : jeux de tampons
  tirés de leur clé, plafond des coulures compté en tampons). Seule une coulure qui descend encore
  quand un tampon la recouvre peut passer dessus sur un poste et dessous sur un autre, selon leur
  rythme d'affichage : l'image de la ville peut différer de ce détail, jamais le territoire.
  Environ 3 Ko/s à 6 joueurs.
- **Synchro du score** : toutes les 0,2 s, l'hôte envoie la liste des cellules dont le
  propriétaire compté a changé (index u16 + propriétaire u8, `Territoire.extraire_changements()`)
  et les scores, que le client vérifie après avoir appliqué la liste (désynchronisation signalée). Les clients n'effectuent aucun calcul de propriété : leur ville dessine les
  tampons reçus sans toucher à son territoire, auquel elle applique la liste reçue, d'où les
```

2e. Remplacer :

```text
  prêts, manche chargée chez tous avec la même
  table (index compactés), retardataire refusé « manche en cours ». De bout en bout (phase
  15) : 1 hôte + 3 clients, commandes scriptées ; vérifie à la fin l'empreinte identique des
  propriétaires de cellules chez tous, les scores identiques, le même nombre de tampons reçus, la
```

par :

```text
  prêts, manche chargée chez tous avec la même
  table (index compactés), retardataire refusé « manche en cours ». Depuis la phase 14, la manche
  (scénario 9) : 1 hôte + 2 clients + un muet qui ne charge jamais sa scène, l'hôte figé 6,5 s
  pendant le chargement (personne ne le croit parti), le muet exclu par la barrière, une passe de
  peinture au clavier de chaque poste, un client qui part par le menu local (son lion disparaît,
  ses cellules restent), des réactions données par l'hôte ; la même empreinte chez l'hôte et chez
  le client resté (territoire, scores, suite des tampons, lions, apparitions), puis l'hôte perdu.
  De bout en bout (phase 15) : 1 hôte + 3 clients, commandes scriptées ; vérifie à la fin l'empreinte identique des
  propriétaires de cellules chez tous, les scores identiques, le même nombre de tampons reçus, la
```

- [ ] **Step 3 : Commit**

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md
git commit -m "Feuille de route et spec : phase 14 faite (manche synchronisée) ; points de vigilance résolus ; restes pour les phases 15 (jeux de tampons), 16 (commandes, interpolation, pertes), 17 et 17 bis (HUD, sons des clients), 18 (exclusion, remise à zéro), 19 (fenêtre, captures) ; découpage de Lion.gd après la 15 ; spec : Manche, Peinture, réplication mesurée, exclusion, coulures

<ligne fournie par l'environnement>"
```

---

## Sortie de phase

- Les quatre suites vertes 5 fois de suite localement (test réseau sous bash 3.2 et 5), sans `SCRIPT ERROR` ni `SHADER ERROR`, puis le job CI vert sur la PR, pas « Test réseau » compris.
- ◉ : les 9 captures regardées et montrées à l'utilisateur (Task 9, Step 3).
- Les preuves U1 à U3, V1 à V4, J1 à J3, E1 à E4, L1 à L3, C1, M1 à M5 et N1 à N3 ont donné les `❌` attendus ; `Scripts/Reseau.gd` n'a jamais été muté (Task 4, Step 2 fait la preuve).
- `git diff main --stat` : les 36 fichiers des Global Constraints, `Scripts/Peinture.gd.uid`, `Scripts/Manche.gd.uid`, les deux `.translation`, la spec et la feuille de route ; `git diff main --stat -- Scripts/Pastille.gd Scripts/Audio.gd Scripts/Decouverte.gd Scripts/HUD.gd tests/bataille_test.gd .github/workflows/ci.yml` vide.
- Partie à deux fenêtres, à la main, conseillée avant la revue : `godot --path . &` deux fois ; l'une héberge, l'autre rejoint (liste ou IP) ; au salon, tous prêts, l'hôte démarre : l'intro part chez les deux en même temps ; chacun déplace son lion au clavier (le client voit le sien suivre avec un petit retard : la prédiction est la phase 16), vomit sur la ville, sur l'autre lion (étourdissement et barbouillage des deux côtés), ramasse une pastille ; Échap chez le client : la partie continue ; fermer la fenêtre du client : son lion disparaît chez l'hôte ; recommencer et fermer celle de l'hôte : « L'hôte a quitté la partie », puis le titre.
- Rappeler à l'utilisateur : `config/version` est passée à 0.14 ; l'aspect du menu local et du message d'hôte perdu attend sa validation (Écarts 6 et 7) ; le découpage de `Lion.gd` est proposé après la phase 15 (Écart 12).
