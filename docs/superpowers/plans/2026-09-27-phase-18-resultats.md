# Phase 18 : l'écran Résultats, la fin de manche qui porte le bilan de l'hôte, la revanche, le niveau suivant et le retour au salon, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** à la fin d'une bataille, sur chaque poste, le même écran Résultats tiré du seul bilan de l'hôte (classement ex æquo compris, pseudo, couleur, part des cellules peintes en barres animées, gagnant ou ex æquo, statistiques de chacun : étourdissements infligés, cellules volées, chocs ; les trois titres « Le plus vicieux », « Le voleur », « L'auto-tamponneur ») ; l'hôte choisit pour tous Revanche (le même niveau), Niveau suivant ou Retour au salon (la même table), chacun peut Quitter ; la fin de manche de l'hôte porte ce bilan et l'état final de chaque lion, que chaque client pose (sa prédiction arrêtée : un joueur qui tient ses touches au gong ne continue plus sur son écran) ; les manches enchaînées ne se mélangent jamais chez un client ; les restes des revues (places réservées vues des clients, stick tenu à l'entrée du salon, adresses relevées une fois, raison de l'exclusion, boucle du vomi après un hôte perdu, lion distant qui recule pendant un accroc du Wi-Fi). Sortie : **◉ résultats** (captures validées par l'utilisateur) ; les cinq suites vertes 5 fois, le test réseau vert 5 fois sous bash 5 et 5 fois sous bash 3.2, dont le **scénario 13 étendu** (fin, bilan et Résultats identiques partout, Revanche, seconde manche, un client qui quitte l'écran Résultats, retour au salon sur la même table).

**Architecture:**
- **Bilan** (`Scripts/BilanManche.gd`, logique pure, que les tests nomment) : ce que l'hôte tient pour définitif au gong (chrono ; par joueur, cellules, crans, étourdissements infligés, cellules volées, chocs, parti ; l'état final de chaque lion encore là, `EtatLion`), son format réseau (`encoder` / `decoder`, qui refuse tout bilan mal formé), et ce que l'écran en tire (`rangs`, `parts`, `classement`, `meneurs`, `laureats`, `record`).
- **Fin de manche** (`Manche`) : l'hôte relève le bilan au gong et l'envoie à la place du chrono et des scores de la phase 17, toujours après ses derniers tampons et son territoire, sur le même canal fiable ordonné ; un client prend le chrono, pose l'état final de chaque lion (`Lion.poser_etat_final`, qui arrête `PredictionLocale`), les crans et les statistiques de l'hôte, voit les départs du bilan ; `Manche.bilan_recu` le donne à l'écran Résultats sur chaque poste. Hors réseau, la scène de jeu relève le bilan elle-même.
- **Écran Résultats** (`Scenes/Resultats.tscn` + `Scripts/Resultats.gd`, posé par `Main` sur la ville figée, à la place du HUD de la bataille, dont le panneau de fin de la phase 17 disparaît) : il n'affiche que le bilan et la table des joueurs ; le choix part en signal (`choix_fait`), `Main` le suit.
- **Manches enchaînées** (`Reseau.relancer_manche`, `Reseau.revenir_au_salon`) : Revanche et Niveau suivant relancent la manche chez tous sans repasser par le salon (la scène de jeu se recharge : territoire, Spawner, chrono, manche et prédiction neufs) ; Retour au salon rouvre le salon chez l'hôte et y ramène chaque client. Le lancement et le retour au salon partent, avec leur table, sur le canal ordonné de la manche (la table seule reste sur le canal 0) ; une réaction ou un départ d'une manche précédente (canal 0) ne touche jamais une manche neuve.
- **Tests** : logique pure et réseau sans scène dans `tests/unitaires.gd` ; réplique posée, fin côté hôte, écran Résultats de l'hôte en réseau et ses choix, salon, hôte perdu dans `tests/smoke_test.gd` ; écran Résultats d'une bataille locale, Revanche et Niveau suivant dans `tests/bataille_test.gd` ; la touche tenue au gong dans `tests/prediction_test.gd` ; le scénario 13 étendu de `tests/reseau/lancer.sh` (+ `joueur.gd`) et la raison de l'exclusion au scénario 9.

**Tech Stack:** Godot 4.7.2, GDScript typé (`class_name`), `CanvasLayer`/`Control` (lignes et cartes construites en code, comme les vignettes du HUD), `Tween` en parallèle (l'animation du bilan du solo), RPC fiables de la manche et de `Reseau` (canaux ENet 0 et 1), `SceneTree.reload_current_scene` / `change_scene_to_file`, tests headless (`tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd`, `tests/prediction_test.gd`, `tests/reseau/lancer.sh` + `joueur.gd` + `relais.gd`), `tests/trace_lions.gd` (hors CI).

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§2 fin de manche ; §3.1 unités, statistiques de `Joueur` ; §4 salon, retour au salon, départs ; §4.1 prédiction ; §8 fin et écran Résultats ; §9 hôte perdu ; §10 tests) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 18 ; tous les points de vigilance « phase 18 ») · plan précédent : `docs/superpowers/plans/2026-09-27-phase-17-hud-bataille.md` · prérequis : **phase 17 fusionnée** ; nouvelle branche `phase-18-resultats` depuis `main`.

## Écarts assumés

1. **Les fichiers de la phase** : la feuille de route listait `Scenes/Resultats.tscn`, `Scripts/Resultats.gd`, `Scripts/Reseau.gd`, `Scripts/ReglesBataille.gd` et les traductions. `ReglesBataille` ne change pas (le classement et les parts y sont depuis la phase 17 : `rangs`, `parts`) ; le bilan est une unité à part, de logique pure (`Scripts/BilanManche.gd`, nommée par les tests), que relèvent la manche de l'hôte et la bataille locale. S'y ajoutent ceux que les points de vigilance « phase 18 » touchent : `Manche`, `Main`, `Lion`, `PredictionLocale`, `InterpolationLion`, `HUDBataille` (+ sa scène), `Salon`, `Titre`, `project.godot` et les tests (liste exacte dans les Global Constraints).
2. **L'écran Résultats est une couche de la scène de jeu** (comme le bilan du solo, `GameOver`), pas une scène à part : la ville figée reste derrière, assombrie ; les départs et l'hôte perdu s'y traitent comme en manche (la manche, qui les annonce, est toujours là) ; Revanche et Niveau suivant rechargent la scène de jeu, Retour au salon charge le salon. Le HUD de la bataille se cache à l'arrivée des Résultats, et son panneau de fin de la phase 17 (« FIN DE LA MANCHE ! », le gagnant, la sortie) disparaît : l'écran Résultats le reprend (le titre, la ligne du gagnant, `texte_gagnant`, la sortie par Échap).
3. **La fin de manche porte le bilan de l'hôte** (`BilanManche`, au lieu du chrono et des scores de la phase 17) : son chrono, par joueur les cellules, crans, étourdissements infligés, cellules volées, chocs et départ, et l'état final de chaque lion encore là (`EtatLion`, 34 octets par lion avec son index). Chaque client pose l'état final de chaque lion (`Lion.poser_etat_final` : position, sens, à l'arrêt ; sa prédiction s'arrête, `PredictionLocale.arreter`) : un client qui tient ses touches au gong ne voit plus son lion continuer (désync-report du scénario 11, M5 de la revue finale 16). L'écran Résultats ne lit que ce bilan : le même sur chaque poste (M3 de la revue finale 17). Les réactions de l'hôte encore en route sur le canal 0 (un étourdissement, un cran de la dernière image) s'appliquent encore à leur arrivée (elles précèdent la fin chez l'hôte : la vue figée converge vers la sienne) ; le HUD figé, qui pouvait différer d'un poste à l'autre, est caché.
4. **Les titres** : chacun va à tous ceux qui en ont le record (ex æquo compris, un par ligne) ; aucun (« Personne ») si le record est nul ; un joueur parti peut en porter un (ses statistiques restent). Les colonnes du classement suivent l'ordre des titres : étourdissements infligés, cellules volées, chocs.
5. **Les commandes de l'écran Résultats** : aucun bouton ne prend le focus (la souris les clique) ; gauche et droite choisissent parmi les choix de l'hôte, vomir (ou Tab, Start) valide, Échap (ou B) quitte ; une action tenue depuis la manche n'agit pas (état relevé à l'ouverture) ; un appui pendant l'animation la termine ; un choix au clavier n'est pris qu'**1 s** après l'animation (`Resultats.DELAI_CHOIX` : un joueur qui martèle Espace au gong ne relance pas la manche sans le vouloir). Un client ne peut que Quitter (Échap ou le bouton, jamais vomir) ; l'hôte qui quitte ramène ses clients au titre (« L'hôte a quitté la partie »), comme en phase 17.
6. **Revanche et Niveau suivant sans repasser par le salon** (`Reseau.relancer_manche`) : la manche reste en cours (aucune arrivée, personne n'a à se redire prêt), les index des joueurs encore là sont recompactés, la table et le lancement repartent comme depuis le salon, et chaque poste recharge la scène de jeu (point de vigilance : territoire, Spawner, manche, barrière et HUD neufs d'un coup). Il faut au moins deux joueurs encore là (sinon ces deux boutons se grisent, « Il faut au moins 2 joueurs pour démarrer. »). Niveau suivant boucle sur les trois niveaux, comme au salon. En bataille locale (sans salon), Revanche et Niveau suivant rechargent la scène, et Retour au salon n'existe pas.
7. **Des manches enchaînées ne se mélangent jamais chez un client** (vu en préparant ce plan) : un tampon, un territoire ou une fin retardés par une perte (canal 1) pouvaient arriver après le lancement de la revanche (canal 0), et une réaction ou un départ de la manche finie (canal 0) dans la manche neuve, dont les index ont pu être recompactés (le mauvais joueur grisé). Le lancement et le retour au salon partent donc sur le canal fiable ordonné de la manche (`Reseau.CANAL_ORDONNE`, le canal 1), après tout ce que la manche finie y a envoyé, avec leur table (que la table diffusée sur le canal 0 peut ne pas précéder). La table seule reste sur le canal 0 : sur le canal 1, la première table d'un arrivant pouvait devancer la fin de son authentification (sur le canal 0 dans `SceneMultiplayer`) et être jetée (`ERROR: Condition "len < 2 || … != SYS_COMMAND_AUTH" is true. Continuing.`, vu en préparant ce plan, sous le relais du test réseau). Et une manche ignore les réactions et les départs reçus avant sa barrière (ceux de la manche neuve partent après son intro, sur le même canal 0).
8. **M2 de la revue finale 16** (`InterpolationLion`) : plus aucun état, un lion distant continue au plus 3 ticks sur sa vitesse puis s'arrête là, sans revenir vers le dernier état reçu (le glissement à reculons, pendant un accroc du Wi-Fi, était le prix d'un correctif de la fin de manche que le bilan rend inutile). La vérification du smoke test qui l'attendait sur le dernier état change avec lui (« 3 ticks plus loin, sans revenir en arrière »).
9. **L'exclusion dite à l'exclu** (point de vigilance de la phase 14) : `Reseau.exclure` (sur l'autoload : l'exclu n'a pas de scène de jeu) lui annonce son exclusion (`_recevoir_exclusion`), puis le déconnecte 0,5 s plus tard (`DELAI_EXCLUSION` : une déconnexion vide la file d'envoi d'ENet) ; son silence court de I1 (phase 14) reste posé tout de suite. Sa perte de l'hôte dit alors « Exclu : ta partie a mis trop de temps à charger. » (`Reseau.raison_perte`), dans la scène de jeu comme au salon.
10. **Le salon au retour d'une manche** (revue finale 13, M2, M3, M4) : la table part avec le nombre de places seulement réservées (`Reseau.places_reservees`, un argument de plus à `_recevoir_salon`) et un client en tient compte (`Reseau.fiches_attente`) ; l'état des actions est relevé à l'ouverture (un stick penché n'agit pas une fois de lui-même) ; les adresses de l'hôte sont relevées une fois ; le salon dépause l'arbre (la fin de manche l'a figé).
11. **Le scénario 13 est étendu, pas doublé** (temps de la CI) : sa manche de 10 s sous le relais continue par l'écran Résultats, une revanche de 6 s, un client qui quitte l'écran Résultats et le retour au salon ; 11 à 22 s de plus, le test réseau entier en 180 s au plus (mesures dans la Task 7).
12. **Bruit connu neuf** : après une revanche ou un retour au salon, un client peut écrire `ERROR: Condition "!pinfo.recv_nodes.has(net_id)" is true. Returning: ERR_UNAUTHORIZED` (`scene_replication_interface.cpp`) : des disparitions des nœuds de la manche finie (lions, ennemis, pastilles), envoyées par l'hôte en quittant sa scène, arrivent après que le client a quitté la sienne. Sans effet (les identifiants de réplication ne se réutilisent pas) ; ni `SCRIPT ERROR` ni `❌`, que seuls comptent les tests.
13. **La trace des lions ne change pas** (`TRACE bataille 1698533818 TRACE solo 185311436 TRACE replique 3757044499` à chaque tâche) : le lion de l'hôte ne change pas, et la réplique de la trace ne reçoit aucun état (son interpolation ne sert pas).
14. **Version 0.18** (`application/config/version`) : la fin de manche, la table du salon et trois RPC neufs (`_recevoir_retour_salon`, `_recevoir_exclusion`) changent le protocole.
15. **Les scénarios 9, 11 et 12 gardent leur repos avant le gel** (`TICKS_REPOS_AVANT_GEL`) : le bilan rend désormais les lions identiques même en mouvement au gong (le scénario 13 le prouve, chacun peignant sans lâcher ses touches), mais aucune vérification existante n'est affaiblie.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), commandes depuis `~/Sites/LeLion-multi`, branche `phase-18-resultats`.
- Fichiers de la phase : ➕ `Scripts/BilanManche.gd`, `Scripts/Resultats.gd` (+ leurs `.uid`, générés par l'import), `Scenes/Resultats.tscn` ; ✏️ `Scripts/InterpolationLion.gd`, `Scripts/Lion.gd`, `Scripts/PredictionLocale.gd`, `Scripts/Manche.gd`, `Scripts/Main.gd`, `Scripts/HUDBataille.gd`, `Scenes/HUDBataille.tscn`, `Scripts/Reseau.gd`, `Scripts/Salon.gd`, `Scripts/Titre.gd`, `Assets/Traductions/traductions.csv` (+ les deux `.translation` que l'import régénère), `project.godot`, `tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd`, `tests/prediction_test.gd`, `tests/reseau/joueur.gd`, `tests/reseau/lancer.sh` ; la spec et la feuille de route (Task 9). **`Scripts/ReglesBataille.gd`, `Scripts/GameOver.gd`, `Scenes/Main.tscn`, `Scripts/Spawner.gd`, `Scripts/Ville.gd`, `Scripts/Territoire.gd`, `tests/trace_lions.gd` et `.github/workflows/ci.yml` ne changent pas.** `Scripts/Reseau.gd` change par les blocs de ce plan (Tasks 5 et 6) et jamais autrement, pas même le temps d'un essai (aucune mutation temporaire de `Reseau.gd` dans les vérifications).
- **Le solo ne change pas** : son bilan (`GameOver`), son HUD, sa trace (`TRACE solo 185311436`) ; aucune vérification existante n'est affaiblie (seules changent celles qui lisaient le panneau de fin de la phase 17, `hud.fin`, que l'écran Résultats remplace, et celle de la réplique arrêtée sur le dernier état reçu, Écart 8).
- **La trace** : `export PATH="/opt/homebrew/bin:$PATH"; godot --headless --import . > /dev/null 2>&1; for k in 1 2 3; do timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/trace_lions.gd 2>&1 | grep -E "^TRACE|❌|SCRIPT ERROR" | tr '\n' ' '; echo; done`. Verdict : deux passages consécutifs identiques (les deux premiers après un import peuvent différer, phase 15 bis). Référence (Task 0, mesurée sur le Mac de préparation) : `TRACE bataille 1698533818 TRACE solo 185311436 TRACE replique 3757044499`, inchangée à chaque tâche (Écart 13). Les empreintes dépendent de la plateforme : seule compte celle de la Task 0 sur le poste de l'exécutant, qui ne doit plus changer.
- **Valeurs de la spec** (§8) : Résultats sur chaque poste, podium en barres colorées animées (l'animation du bilan de `GameOver` : une ligne toutes les 0,3 s, son compteur en 0,45 s), pourcentages (les parts des cellules peintes de la phase 17, 100 % à elles toutes), trois titres (« Le plus vicieux » : étourdissements infligés, « Le voleur » : cellules volées, « L'auto-tamponneur » : chocs) ; l'hôte choisit Revanche, Niveau suivant ou Retour au salon ; les clients voient « En attente de l'hôte… » ; 6 joueurs au plus, pseudos de 12 caractères au plus (`Reseau.PSEUDO_MAX`), 2 joueurs au moins pour une manche (`EtatPartie.NB_JOUEURS_MIN`).
- Identifiants, commentaires, messages de test et traductions en français (EN à côté), docstrings `##`, tabulations. Tout texte visible neuf passe par `Assets/Traductions/traductions.csv`.
- **Aucune séquence d'échappement `\u…` n'est tapée dans un fichier** (les « … » et « – » des traductions et du code sont des caractères). Vérifier après chaque écriture : `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd Scenes/*.tscn tests/*.gd tests/reseau/*.gd tests/reseau/lancer.sh Assets/Traductions/traductions.csv` ne sort rien.
- Un test `--script` est compilé **avant** les autoloads : il ne nomme ni `GameState`, ni `Lion`, ni `Resultats`, ni `HUDBataille`, ni `Main`, ni `Manche`, ni `Salon`, et ne **précharge** (`preload`) aucune de leurs scènes (l'écran Résultats nomme des autoloads) ; il peut nommer `BilanManche`, `EtatLion`, `InterpolationLion`, `ReglesBataille`, `Regles`, `EtatPartie`, `Territoire`, `Joueur`, `Commandes`. Les autoloads s'y lisent par `root.get_node("…")`, les scripts qui les nomment par `load(...)` à l'exécution.
- Après la création d'un script à `class_name` ou d'une scène, ou une modification des traductions : `godot --headless --import .` avant les tests (il génère les `.uid` et les `.translation`, à committer avec eux).
- **Toujours lancer un test Godot avec `timeout`** et chercher les erreurs :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; O=""; timeout -k 5 300 godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd; O=""`, `T=tests/bataille_test.gd; O="--fixed-fps 60"`, `T=tests/prediction_test.gd; O="--fixed-fps 60"` ; le test réseau : `timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $?"; grep -E "❌|✅|== |\(chrono\)|\(latence\)" "$TMPDIR/r.log"`). Une `SCRIPT ERROR` ne change pas le code de sortie ; un script qui ne compile pas sort aussi en `code 0`, sans ligne `== n échec(s) ==`. Bruit connu : « ObjectDB instances were leaked », « resources still in use at exit », les `ERROR` voulues des plans des phases 14 et 16 (dont `ERROR: Lion.avancer hors d'une image physique : ce pas est ignoré`, smoke test, une fois ; `Reseau.lancer_manche : fiches de la manche incohérentes`, tests unitaires, une fois), et celle de l'Écart 12 (test réseau).
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`**.
- **Ne jamais lancer deux suites en même temps**, ni en arrière-plan : les tests unitaires, le smoke test et le test réseau ouvrent des ports locaux (1777x à 1979x) ; deux à la fois se les disputent (vu en préparant ce plan : un autre test réseau lancé sur le même Mac a fait échouer le scénario 13, port du relais pris). Avant une suite, `pgrep -fl "godot --headless"` ne sort rien. Si un autre test réseau doit tourner sur le même Mac, lui donner une autre base de ports (`bash tests/reseau/lancer.sh 36777`).
- **Attentes événementielles** : chaque attente du test réseau porte sur une ligne de journal ou un état observé, bornée ; les tests `--fixed-fps 60` avancent au tick près.
- Les cinq suites (unitaires, smoke, bataille, banc de la prédiction, trace) se valident sur **5 passages consécutifs verts**, sans relance ; le test réseau 5 fois sous bash 5 et 5 fois sous bash 3.2 (`/bin/bash`, macOS), sans relance.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Un client qui tient ses touches au gong, sa fin retardée par le Wi-Fi** (une retransmission d'ENet sous perte) : son lion (prédit) et les lions distants (interpolés) doivent finir exactement où l'hôte les a, sa prédiction arrêtée, et son écran Résultats être celui de l'hôte. → banc `_scenario_fin_de_manche` (la touche tenue, 0 px d'écart, prédiction arrêtée, Task 3) ; smoke « la réplique prend l'état final de l'hôte… » (Task 3) ; scénario 13 : chaque poste peint sans lâcher ses touches jusqu'au gong, lignes `FIN` (HUD, bilan, lions affichés) et `RESULTATS` identiques sur les trois postes, deux fois (Task 7).
2. **Espace tenu ou martelé au gong** : aucun choix ne doit partir sans le vouloir (Revanche relancerait la manche de tous, Quitter ferait quitter), rien ne prend le focus. → `tests/bataille_test.gd`, `_tester_resultats` : « Espace tenu depuis le gong… ne choisit rien », « un appui pendant l'animation la termine », « juste après l'animation, un appui ne choisit encore rien » ; `_tester_hud` : « Espace appuyé au gong… rien n'a le focus » (Task 4).
3. **Un joueur qui quitte l'écran Résultats**, jusqu'à laisser l'hôte seul : sa ligne se grise chez chacun, Revanche et Niveau suivant se grisent sous deux joueurs (et une relance que l'hôte ne peut plus suivre est refusée sans casser l'écran), la revanche recompacte les index. → smoke `_tester_resultats_reseau` (Bob part, relance refusée, Task 5) ; unitaires « Niveau suivant : … index recompactés », « seul, l'hôte ne relance pas » (Task 5) ; scénario 13 (Bruno quitte, l'hôte et Anna le voient, Task 7).
4. **Des paquets d'une manche finie qui arrivent dans la suivante** (un tampon ou une fin retardés sur le canal 1, une réaction ou un départ sur le canal 0, alors que la revanche est déjà lancée) : jamais peints, jamais appliqués à la manche neuve, jamais au mauvais joueur. → unitaires `_tester_manches_enchainees` (canaux des RPC, la table portée par le lancement, réactions et départs ignorés avant la barrière, Task 5) ; scénario 13 (deux manches enchaînées sous 5 % de pertes, empreintes identiques, Task 7).
5. **Le retour au salon** : la manche n'y est plus en cours (arrivées de nouveau acceptées), personne n'y est prêt, la même table sans les partis, l'arbre dépausé, un stick penché ou une place réservée n'y trompent personne. → smoke `_tester_resultats_reseau` (« Retour au salon : … ») et `_tester_salon` (M2, M3, M4, Task 6) ; unitaires « Retour au salon : … » (Task 5) ; lignes `SALON` du scénario 13 (Task 7).

---

### Task 0 : vérifications et référence de la trace

Ce plan est commité par le commit de planification : ne pas le recommiter, **ne jamais le modifier**. Vérifier que la phase 17 est fusionnée : `test -f Scripts/HUDBataille.gd && test -f Scripts/PlacementPseudos.gd && grep -c 'config/version="0.17"' project.godot` donne `1`, et `wc -l Scripts/Manche.gd Scripts/Main.gd Scripts/Reseau.gd Scripts/HUDBataille.gd Scripts/Lion.gd` donne 542, 374, 802, 337 et 439. Sinon, s'arrêter et le signaler. Les blocs « remplacer » citent le code tel que la phase 17 le laisse (vérifié en appliquant ce plan, bloc par bloc, à une copie de `origin/phase-17-hud-bataille` à `4bb6697`, trois correctifs de CI après la revue finale de la phase 17 ; la PR fusionnée peut en avoir d'autres) : si une ancre a bougé, l'adapter au texte réel sans changer le remplacement, et le noter.

« Step 0 » (règle du projet pour un fichier de plus de 300 lignes : `Scripts/Manche.gd`, `Scripts/Main.gd`, `Scripts/Reseau.gd`, `Scripts/HUDBataille.gd`, `Scripts/Lion.gd`, `tests/smoke_test.gd`, `tests/unitaires.gd`, `tests/bataille_test.gd`, `tests/prediction_test.gd`, `tests/reseau/joueur.gd`, `tests/reseau/lancer.sh`) : pas de code mort à retirer avant la phase (la phase 17 vient de passer sur ces fichiers ; celui que la phase 18 rend mort, le panneau de fin du HUD, part avec la Task 4). Le vérifier pour les scripts du jeu :

```bash
for f in Scripts/Lion.gd Scripts/Manche.gd Scripts/Main.gd Scripts/Reseau.gd Scripts/HUDBataille.gd; do
	for n in $(grep -oE "^(const|var|func|static var|static func|@onready var|@export var|signal) [A-Za-z_]+" $f | awk '{print $NF}'); do
		[ "$(grep -rc "\b$n\b" Scripts tests Scenes | awk -F: '{s+=$2} END {print s}')" -lt 2 ] && echo "$f $n"
	done
done; grep -n "print(" Scripts/Lion.gd Scripts/Manche.gd Scripts/Main.gd Scripts/Reseau.gd Scripts/HUDBataille.gd
```

Expected (mesuré) : rien.

Puis : `git switch -c phase-18-resultats`, et la référence de la trace (commande des Global Constraints), notée dans `$TMPDIR/trace_reference.txt` (jamais commitée). Mesuré sur le Mac de préparation : `TRACE bataille 1698533818 TRACE solo 185311436 TRACE replique 3757044499` (trois passages identiques). Et le temps du test réseau avant la phase, noté aussi (mesuré : 158 s ; il sert à la Task 7).

---

### Task 1 : le bilan de la manche (`BilanManche`)

**Files:**
- Create: `Scripts/BilanManche.gd` (+ `Scripts/BilanManche.gd.uid`, généré par l'import)
- Test: `tests/unitaires.gd`

**Interfaces:**
- Consumes : `Joueur` (`index`, `crans`, `etourdissements_infliges`, `cellules_volees`, `chocs`, `Joueur.CRANS_MAX`), `EtatLion.encoder` / `decoder` / `TAILLE` (33), `ReglesBataille.rangs(cellules: Array[int]) -> Array[int]`, `ReglesBataille.parts(cellules: Array[int]) -> Array[int]`.
- Produces (Tasks 3, 4, 5, 7) : `class_name BilanManche extends RefCounted` ; `const CHAMPS := 6`, `const TAILLE_LION := 34`, `const TITRES: Array[StringName] = [&"vicieux", &"voleur", &"tamponneur"]` ; `var temps: float`, `var cellules, crans, etourdissements, volees, chocs: Array[int]`, `var partis: Array[bool]`, `var lions: Dictionary[int, PackedByteArray]` (par index de joueur, un `EtatLion`) ; `static func relever(joueurs: Array[Joueur], cellules_par_joueur: Array[int], index_partis: Array[int], etats: Dictionary[int, PackedByteArray], temps_: float) -> BilanManche` (sans lion pour un parti) ; `func nb_joueurs() -> int` ; `func encoder() -> Array` (`[temps, PackedInt32Array, PackedByteArray]`) ; `static func decoder(recu: Variant, nb: int) -> BilanManche` (null si mal formé) ; `func rangs() -> Array[int]` ; `func parts() -> Array[int]` ; `func classement() -> Array[int]` (les index, le plus de cellules d'abord, à égalité le plus petit index) ; `func meneurs() -> Array[int]` ; `func valeurs(titre: StringName) -> Array[int]` ; `func record(titre: StringName) -> int` ; `func laureats(titre: StringName) -> Array[int]` (tous les ex æquo, aucun si le record est nul) ; `func resume() -> String` (une ligne, pour les tests).

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_placement_pseudos()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_placement_pseudos()
	_tester_bilan_manche()
	print("== %d échec(s) ==" % _echecs)
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
		"deux lions à distance de contact (92 px) : le pseudo large reste sur le lion de droite, jamais basculé sur celui de gauche (%s)" % [xs])


## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
```

par :

```gdscript
		"deux lions à distance de contact (92 px) : le pseudo large reste sur le lion de droite, jamais basculé sur celui de gauche (%s)" % [xs])


## Phase 18 : le bilan de la manche, relevé par l'hôte au gong et envoyé à chaque client (format
## réseau), et ce que l'écran Résultats en tire : classement, parts, meneurs, les trois titres.
func _tester_bilan_manche() -> void:
	print("-- Bilan de la manche (phase 18)")
	var joueurs: Array[Joueur] = []
	for i in range(4):
		var j := Joueur.new()
		j.index = i
		j.reinitialiser(3)
		joueurs.append(j)
	joueurs[1].crans = 5
	joueurs[0].etourdissements_infliges = 3
	joueurs[2].etourdissements_infliges = 3
	joueurs[3].cellules_volees = 120
	joueurs[1].chocs = 7
	var etats: Dictionary[int, PackedByteArray] = {
		0: EtatLion.encoder(900, 0, Vector2(100.5, 200.25), Vector2(350, 0), Vector2.ZERO, 1),
		1: EtatLion.encoder(900, 42, Vector2(640, 300), Vector2.ZERO, Vector2(-80, 10), -1),
		3: EtatLion.encoder(880, 7, Vector2(1500, 410), Vector2.ZERO, Vector2.ZERO, 1)}
	var bilan := BilanManche.relever(joueurs, [300, 900, 300, 0] as Array[int], [3] as Array[int], etats, 90.004)
	_check(bilan.nb_joueurs() == 4 and bilan.cellules == [300, 900, 300, 0] and bilan.crans == [1, 5, 1, 1]
		and bilan.etourdissements == [3, 0, 3, 0] and bilan.volees == [0, 0, 0, 120] and bilan.chocs == [0, 7, 0, 0]
		and bilan.partis == [false, false, false, true] and bilan.lions.keys() == [0, 1] and is_equal_approx(bilan.temps, 90.004),
		"le bilan relève, par joueur, cellules, crans, statistiques de l'hôte et départ ; l'état final des lions encore là (pas celui d'un parti)")
	var recu := BilanManche.decoder(bilan.encoder(), 4)
	_check(recu != null and recu.resume() == bilan.resume() and recu.lions[1] == etats[1],
		"le bilan fait l'aller-retour du format réseau, états des lions compris (%s)" % ("" if recu == null else recu.resume()))
	_check(bilan.encoder()[2].size() == 2 * BilanManche.TAILLE_LION and bilan.resume().contains("L1@640.0,300.0,-1"),
		"deux lions de %d octets ; le résumé donne leur place et leur sens" % BilanManche.TAILLE_LION)
	var e: Array = bilan.encoder()
	var entiers_crans_nuls: PackedInt32Array = (e[1] as PackedInt32Array).duplicate()
	entiers_crans_nuls[1] = 0
	var lions_doubles: PackedByteArray = (e[2] as PackedByteArray).duplicate()
	lions_doubles.append_array((e[2] as PackedByteArray).slice(0, BilanManche.TAILLE_LION))
	var lion_parti: PackedByteArray = (e[2] as PackedByteArray).duplicate()
	lion_parti.append(3)
	lion_parti.append_array(etats[3])
	var lion_illisible: PackedByteArray = (e[2] as PackedByteArray).duplicate()
	lion_illisible[BilanManche.TAILLE_LION - 1] = 0  # l'orientation du premier lion : ni 1 ni -1
	var refuses: Array = [null, "bilan", [], [90.0, e[1]], [NAN, e[1], e[2]], [-1.0, e[1], e[2]], [90.0, e[1], e[2]].slice(0, 2),
		[90.0, (e[1] as PackedInt32Array).slice(1), e[2]], [90.0, entiers_crans_nuls, e[2]], [90.0, e[1], lions_doubles],
		[90.0, e[1], lion_parti], [90.0, e[1], lion_illisible], [90.0, e[1], (e[2] as PackedByteArray).slice(1)], [90, e[1], e[2]]]
	_check(refuses.all(func(r: Variant) -> bool: return BilanManche.decoder(r, 4) == null) and BilanManche.decoder(e, 3) == null,
		"un bilan mal formé est refusé : autre type, chrono non fini, négatif ou entier, champs manquants, crans nuls, lion en double, d'un parti, illisible ou tronqué, autre nombre de joueurs")
	_check(bilan.rangs() == [2, 1, 2, 0] and bilan.parts() == [20, 60, 20, 0] and bilan.meneurs() == [1],
		"rangs, parts et meneurs viennent des cellules du bilan (%s, %s)" % [bilan.rangs(), bilan.parts()])
	_check(bilan.classement() == [1, 0, 2, 3], "le classement : le plus de cellules d'abord, les ex æquo par index, sans cellule à la fin (%s)" % [bilan.classement()])
	_check(bilan.laureats(&"vicieux") == [0, 2] and bilan.record(&"vicieux") == 3 and bilan.laureats(&"voleur") == [3]
		and bilan.laureats(&"tamponneur") == [1] and bilan.record(&"tamponneur") == 7,
		"les trois titres : les ex æquo le partagent, un parti peut le porter (le voleur, parti)")
	var vide := BilanManche.relever(joueurs.slice(0, 2) as Array[Joueur], [0, 0] as Array[int], [] as Array[int], {} as Dictionary[int, PackedByteArray], 90.0)
	for j in joueurs:
		j.reinitialiser(3)
	var calme := BilanManche.relever(joueurs, [0, 0, 0, 0] as Array[int], [] as Array[int], {} as Dictionary[int, PackedByteArray], 90.0)
	_check(vide.meneurs().is_empty() and vide.parts() == [0, 0] and vide.classement() == [0, 1]
		and BilanManche.TITRES.all(func(t: StringName) -> bool: return calme.laureats(t).is_empty() and calme.record(t) == 0),
		"personne n'a peint : aucun meneur, 0 % partout ; personne n'a étourdi, volé ni percuté : aucun titre")


## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
```

- [ ] **Step 2 : les voir échouer**

Run : la commande des Global Constraints avec `T=tests/unitaires.gd; O=""`.
Expected : `SCRIPT ERROR: Parse Error: Identifier "BilanManche" not declared in the current scope.` (le script ne compile pas : aucune ligne `== n échec(s) ==`).

- [ ] **Step 3 : le bilan**

Créer `Scripts/BilanManche.gd` :

```gdscript
class_name BilanManche
extends RefCounted
## Le bilan d'une manche de bataille (phase 18, spec §8 ; logique pure : les tests `--script` le
## nomment) : ce que l'hôte tient pour définitif au gong, et que chaque poste affiche à l'identique sur
## l'écran Résultats. Par joueur, dans l'ordre des index : ses cellules (le territoire de l'hôte), ses
## crans, ses statistiques (étourdissements infligés, cellules volées, chocs : l'hôte seul les tient,
## spec §3.1) et s'il est parti ; et l'état final de chaque lion encore en jeu (`EtatLion`), où chaque
## client pose le sien (sa prédiction arrêtée) et ceux des autres. En réseau, la manche de l'hôte le
## relève au gong et l'envoie avec la fin (`encoder`) ; chaque client le lit (`decoder`). Hors réseau
## (bataille locale), la scène de jeu le relève elle-même. Le classement, les parts et les trois titres
## se calculent ici, sur ces seules valeurs : les mêmes sur chaque poste.

## Entiers par joueur au format réseau : cellules, crans, étourdissements infligés, cellules volées,
## chocs, parti (0 ou 1).
const CHAMPS := 6
## Octets par lion au format réseau : l'index de son joueur, puis son état (`EtatLion.TAILLE`).
const TAILLE_LION := 1 + EtatLion.TAILLE
## Les trois titres de l'écran Résultats (spec §8), dans l'ordre d'affichage : « Le plus vicieux »
## (étourdissements infligés), « Le voleur » (cellules volées), « L'auto-tamponneur » (chocs).
const TITRES: Array[StringName] = [&"vicieux", &"voleur", &"tamponneur"]

## Le chrono de l'hôte au gong, en secondes.
var temps := 0.0
var cellules: Array[int] = []
var crans: Array[int] = []
var etourdissements: Array[int] = []
var volees: Array[int] = []
var chocs: Array[int] = []
var partis: Array[bool] = []
## Par index de joueur, l'état final de son lion (`EtatLion.encoder`) ; aucun pour un joueur parti.
var lions: Dictionary[int, PackedByteArray] = {}


## Le bilan de la partie en cours, relevé chez l'hôte au gong : les joueurs `joueurs` (crans et
## statistiques), leurs cellules `cellules_par_joueur` (dans l'ordre des index), les index des partis
## `index_partis`, l'état final de chaque lion `etats` (par index de joueur) et le chrono `temps_`.
static func relever(joueurs: Array[Joueur], cellules_par_joueur: Array[int], index_partis: Array[int],
		etats: Dictionary[int, PackedByteArray], temps_: float) -> BilanManche:
	var bilan := BilanManche.new()
	bilan.temps = temps_
	for j in joueurs:
		bilan.cellules.append(cellules_par_joueur[j.index] if j.index < cellules_par_joueur.size() else 0)
		bilan.crans.append(j.crans)
		bilan.etourdissements.append(j.etourdissements_infliges)
		bilan.volees.append(j.cellules_volees)
		bilan.chocs.append(j.chocs)
		bilan.partis.append(index_partis.has(j.index))
	for index: int in etats:
		if index >= 0 and index < joueurs.size() and not index_partis.has(index):
			bilan.lions[index] = etats[index]
	return bilan


func nb_joueurs() -> int:
	return cellules.size()


## Le format réseau : `[temps, PackedInt32Array (CHAMPS entiers par joueur), PackedByteArray
## (TAILLE_LION octets par lion, par index croissant)]`.
func encoder() -> Array:
	var entiers := PackedInt32Array()
	for i in range(nb_joueurs()):
		entiers.append_array([cellules[i], crans[i], etourdissements[i], volees[i], chocs[i], 1 if partis[i] else 0])
	var octets := PackedByteArray()
	var index := lions.keys()
	index.sort()
	for i: int in index:
		octets.append(i)
		octets.append_array(lions[i])
	return [temps, entiers, octets]


## Le bilan reçu de l'hôte (`encoder`) pour une partie à `nb` joueurs, ou null s'il est mal formé :
## autre type, chrono non fini ou négatif, pas exactement CHAMPS entiers par joueur, cellules ou
## statistiques négatives, crans hors de [1, Joueur.CRANS_MAX], parti autre que 0 ou 1, lion d'un index
## hors de la partie, en double, d'un parti, ou dont l'état ne se lit pas (`EtatLion.decoder`).
static func decoder(recu: Variant, nb: int) -> BilanManche:
	if not (recu is Array) or recu.size() != 3 or not (recu[0] is float) or not (recu[1] is PackedInt32Array) \
			or not (recu[2] is PackedByteArray):
		return null
	var temps_: float = recu[0]
	var entiers: PackedInt32Array = recu[1]
	var octets: PackedByteArray = recu[2]
	if not is_finite(temps_) or temps_ < 0.0 or nb < 1 or entiers.size() != nb * CHAMPS or octets.size() % TAILLE_LION != 0:
		return null
	var bilan := BilanManche.new()
	bilan.temps = temps_
	for i in range(nb):
		var k := i * CHAMPS
		if entiers[k] < 0 or entiers[k + 1] < 1 or entiers[k + 1] > Joueur.CRANS_MAX or entiers[k + 2] < 0 \
				or entiers[k + 3] < 0 or entiers[k + 4] < 0 or (entiers[k + 5] != 0 and entiers[k + 5] != 1):
			return null
		bilan.cellules.append(entiers[k])
		bilan.crans.append(entiers[k + 1])
		bilan.etourdissements.append(entiers[k + 2])
		bilan.volees.append(entiers[k + 3])
		bilan.chocs.append(entiers[k + 4])
		bilan.partis.append(entiers[k + 5] == 1)
	for debut in range(0, octets.size(), TAILLE_LION):
		var index := octets[debut]
		var etat := octets.slice(debut + 1, debut + TAILLE_LION)
		if index >= nb or bilan.lions.has(index) or bilan.partis[index] or EtatLion.decoder(etat).is_empty():
			return null
		bilan.lions[index] = etat
	return bilan


## Le rang de chaque joueur (`ReglesBataille.rangs` : 1 pour le plus de cellules, ex æquo au même rang,
## 0 sans cellule).
func rangs() -> Array[int]:
	return ReglesBataille.rangs(cellules)


## La part de chaque joueur dans les cellules peintes (`ReglesBataille.parts` : 100 à elles toutes).
func parts() -> Array[int]:
	return ReglesBataille.parts(cellules)


## Les index des joueurs dans l'ordre du classement : le plus de cellules d'abord, à égalité le plus
## petit index (le même ordre sur chaque poste) ; les joueurs sans cellule à la fin.
func classement() -> Array[int]:
	var ordre: Array[int] = []
	for i in range(nb_joueurs()):
		ordre.append(i)
	ordre.sort_custom(func(a: int, b: int) -> bool: return cellules[a] > cellules[b] or (cellules[a] == cellules[b] and a < b))
	return ordre


## Les index des meneurs (rang 1, ex æquo compris) ; aucun si personne n'a de cellule.
func meneurs() -> Array[int]:
	var liste: Array[int] = []
	var r := rangs()
	for i in range(r.size()):
		if r[i] == 1:
			liste.append(i)
	return liste


## Les valeurs du titre `titre` (un de TITRES), par joueur.
func valeurs(titre: StringName) -> Array[int]:
	match titre:
		&"vicieux":
			return etourdissements
		&"voleur":
			return volees
		&"tamponneur":
			return chocs
	return [] as Array[int]


## Le record du titre `titre` : la plus grande de ses valeurs (0 si personne n'en a).
func record(titre: StringName) -> int:
	var plus := 0
	for v in valeurs(titre):
		plus = maxi(plus, v)
	return plus


## Les index de ceux qui portent le titre `titre` : tous ceux qui en ont le record (ex æquo compris),
## aucun si le record est nul (personne n'a étourdi, volé ou percuté personne).
func laureats(titre: StringName) -> Array[int]:
	var liste: Array[int] = []
	var plus := record(titre)
	if plus <= 0:
		return liste
	var v := valeurs(titre)
	for i in range(v.size()):
		if v[i] == plus:
			liste.append(i)
	return liste


## Le bilan en une ligne (tests réseau : la même chez l'hôte et chez chaque client).
func resume() -> String:
	var morceaux := PackedStringArray(["%.3f" % temps])
	for i in range(nb_joueurs()):
		morceaux.append("%d:%d,%d,%d,%d,%d%s" % [i, cellules[i], crans[i], etourdissements[i], volees[i], chocs[i], ":parti" if partis[i] else ""])
	var index := lions.keys()
	index.sort()
	for i: int in index:
		var etat := EtatLion.decoder(lions[i])
		morceaux.append("L%d@%.1f,%.1f,%d" % [i, etat.position.x, etat.position.y, etat.direction])
	return "|".join(morceaux)
```

Puis `godot --headless --import . > /dev/null 2>&1` (il génère `Scripts/BilanManche.gd.uid`).

- [ ] **Step 4 : les voir passer**

Run : la même commande. Expected : `== 0 échec(s) ==`, dont la section « -- Bilan de la manche (phase 18) » (8 vérifications : relevé, aller-retour du format réseau, deux lions de 34 octets, bilans mal formés refusés, rangs et parts, classement, titres ex æquo et d'un parti, aucun titre ni meneur sans cellule ni statistique). Puis la trace (commande des Global Constraints) : inchangée.

- [ ] **Step 5 : commit**

```bash
git add Scripts/BilanManche.gd Scripts/BilanManche.gd.uid tests/unitaires.gd
git commit -m "Bilan de la manche (phase 18) : ce que l'hôte tient pour définitif au gong (chrono, cellules, crans, statistiques et départ de chaque joueur, état final de chaque lion), son format réseau qui refuse tout bilan mal formé, et ce qu'en tire l'écran Résultats (classement stable, parts, meneurs, les trois titres ex æquo compris)

<ligne fournie par l'environnement>"
```

---

### Task 2 : le lion distant ne recule plus pendant un accroc du Wi-Fi (`InterpolationLion`, M2 de la revue finale 16)

**Files:**
- Modify: `Scripts/InterpolationLion.gd` (en-tête, `EXTRAPOLATION_MAX`, `echantillon`)
- Test: `tests/unitaires.gd` (`_tester_interpolation_lion`), `tests/smoke_test.gd` (la réplique d'un lion, section « Bataille : lion »)

**Interfaces:**
- Consumes : rien de neuf.
- Produces (Task 3) : `InterpolationLion.echantillon()` au-delà du dernier état reçu : la position avance sur sa vitesse au plus `EXTRAPOLATION_MAX` (3) ticks, puis reste là, à l'arrêt (`vitesse` nulle) ; jamais de retour vers le dernier état. L'état final d'un lion distant en fin de manche vient du bilan (`Lion.poser_etat_final`, Task 3).

Pourquoi maintenant : le retour vers le dernier état reçu était le correctif du lion figé en fin de manche (désync-report du scénario 11, phase 16) ; il fait glisser un lion distant à reculons (jusqu'à 2,8 px par tick, mesuré ici : -2,84 px) pendant un accroc de 200 à 420 ms, puis sauter en avant à la reprise. Le bilan de la fin (Task 3) pose désormais l'état final de chaque lion : ce retour n'a plus d'objet.

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
		"avec %.1f ticks de retard en moyenne sur l'hôte (le retard d'affichage et la latence)" % retard_moyen)
	# Plus aucun état (un hôte figé, en fin de manche) : le lion va un peu plus loin sur sa vitesse, puis
	# revient sur le dernier état reçu, à l'arrêt, au pixel près (celui de l'hôte figé).
	var dernier_etat := Vector2(dernier_recu * vitesse / 60.0, 100.0)
	var plus_loin := -INF
	for t in range(30):
		interp.avancer(1.0)
		plus_loin = maxf(plus_loin, interp.echantillon().position.x)
	var arret: Dictionary = interp.echantillon()
	interp.avancer(1.0)
	_check(plus_loin > dernier_etat.x and plus_loin <= dernier_etat.x + InterpolationLion.EXTRAPOLATION_MAX * vitesse / 60.0 + 0.01,
		"plus aucun état : le lion continue sur sa vitesse %d ticks au plus (%.2f px au-delà du dernier état)" % [int(InterpolationLion.EXTRAPOLATION_MAX), plus_loin - dernier_etat.x])
	_check(arret.position == dernier_etat and arret.vitesse == Vector2.ZERO and interp.echantillon().position == dernier_etat,
		"puis revient sur le dernier état reçu, à l'arrêt, et y reste : un hôte figé laisse le lion là où il l'a chez lui (x = %.2f pour %.2f)" % [arret.position.x, dernier_etat.x])
	var desordre := InterpolationLion.new(60)
```

par :

```gdscript
		"avec %.1f ticks de retard en moyenne sur l'hôte (le retard d'affichage et la latence)" % retard_moyen)
	# Plus aucun état (un hôte figé) : le lion va un peu plus loin sur sa vitesse, puis s'arrête là, sans
	# jamais revenir en arrière (M2, revue finale phase 16 ; en fin de manche, le bilan de l'hôte pose
	# l'état final de chaque lion, phase 18)
	var dernier_etat := Vector2(dernier_recu * vitesse / 60.0, 100.0)
	var plus_loin := -INF
	var recule := false
	var avant_x := -INF
	for t in range(30):
		interp.avancer(1.0)
		var x: float = interp.echantillon().position.x
		recule = recule or x < avant_x - 0.001
		avant_x = x
		plus_loin = maxf(plus_loin, x)
	var arret: Dictionary = interp.echantillon()
	_check(plus_loin > dernier_etat.x and plus_loin <= dernier_etat.x + InterpolationLion.EXTRAPOLATION_MAX * vitesse / 60.0 + 0.01,
		"plus aucun état : le lion continue sur sa vitesse %d ticks au plus (%.2f px au-delà du dernier état)" % [int(InterpolationLion.EXTRAPOLATION_MAX), plus_loin - dernier_etat.x])
	_check(not recule and is_equal_approx(arret.position.x, plus_loin) and arret.vitesse == Vector2.ZERO,
		"M2 : puis il s'arrête là, sans revenir en arrière vers le dernier état reçu (x = %.2f, dernier état %.2f)" % [arret.position.x, dernier_etat.x])
	# M2 : un accroc du Wi-Fi de 300 ms en pleine course, puis la reprise : l'affichage ne recule jamais
	var accroc := InterpolationLion.new(60)
	var pas_accroc: Array[float] = []
	var x_avant := -INF
	for t in range(240):
		if t < 120 or t >= 138:
			accroc.ajouter(t, Vector2(t * vitesse / 60.0, 100.0), Vector2(vitesse, 0.0), 1)
		accroc.avancer(1.0)
		var vu_accroc := accroc.echantillon()
		if vu_accroc.is_empty():
			continue  # le premier état n'est pas encore affiché (RETARD)
		if x_avant > -INF:
			pas_accroc.append(vu_accroc.position.x - x_avant)
		x_avant = vu_accroc.position.x
	_check(pas_accroc.min() >= -0.001,
		"M2 : pendant un accroc de 300 ms et à la reprise, le lion distant ne recule jamais (plus petit pas %.2f px)" % pas_accroc.min())
	var desordre := InterpolationLion.new(60)
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	var arret_repl: Vector2 = repl.position
	_check(arret_repl.is_equal_approx(Vector2(700 + 11 * pas_repl, 500)) and repl.velocity == Vector2.ZERO,
		"plus aucun état (hôte figé) : la réplique finit arrêtée sur le dernier état reçu, pas au-delà (x = %.1f)" % arret_repl.x)
	repl.vomi_de_l_hote = false
```

par :

```gdscript
	var arret_repl: Vector2 = repl.position
	_check(arret_repl.is_equal_approx(Vector2(700 + (11 + InterpolationLion.EXTRAPOLATION_MAX) * pas_repl, 500)) and repl.velocity == Vector2.ZERO,
		"plus aucun état (hôte figé) : la réplique continue %d ticks sur sa vitesse, puis s'arrête là, sans revenir en arrière (M2, x = %.1f)"
			% [int(InterpolationLion.EXTRAPOLATION_MAX), arret_repl.x])
	repl.vomi_de_l_hote = false
```

- [ ] **Step 2 : les voir échouer**

Run : unitaires, puis smoke (commandes des Global Constraints).
Expected : unitaires `== 2 échec(s) ==` : `❌ M2 : puis il s'arrête là, sans revenir en arrière vers le dernier état reçu (x = 3476.67, dernier état 3476.67)` et `❌ M2 : pendant un accroc de 300 ms et à la reprise, le lion distant ne recule jamais (plus petit pas -2.84 px)` ; smoke `== 1 échec(s) ==` : `❌ plus aucun état (hôte figé) : la réplique continue 3 ticks sur sa vitesse, puis s'arrête là, sans revenir en arrière (M2, x = 764.2)`.

- [ ] **Step 3 : l'interpolation**

Dans `Scripts/InterpolationLion.gd`, remplacer :

```gdscript
## d'ECART_MAX (premier état, gel d'un des postes). Plus aucun état : le lion continue sur sa vitesse
## EXTRAPOLATION_MAX ticks au plus, puis revient au même pas sur le dernier état reçu, où il s'arrête.
## Un hôte figé ou en pause (fin de manche) n'envoie plus d'état neuf : arrêté en avance sur lui, le
## lion resterait chez ce client, jusqu'au bout, EXTRAPOLATION_MAX ticks de sa vitesse plus loin que
## chez l'hôte (mesuré au test réseau : 29 px pour un recul de 580 px/s ; 17,5 px à pleine vitesse).

## Retard d'affichage, en ticks de l'hôte (100 ms à 60 ticks par seconde) : plus que la gigue simulée
## (40 ms) et deux états perdus de suite (2 × 16,7 ms).
const RETARD := 6.0
## Au-delà du dernier état reçu, le lion continue sur sa vitesse au plus autant de ticks, puis revient
## sur cet état en autant de ticks.
const EXTRAPOLATION_MAX := 3.0
```

par :

```gdscript
## d'ECART_MAX (premier état, gel d'un des postes). Plus aucun état : le lion continue sur sa vitesse
## EXTRAPOLATION_MAX ticks au plus, puis s'arrête là, sans jamais revenir en arrière (M2, revue finale
## phase 16 : le retour vers le dernier état reçu faisait glisser le lion à reculons pendant un accroc
## du Wi-Fi, puis sauter en avant à la reprise). À la fin de la manche, l'hôte ne diffuse plus d'état :
## c'est le bilan de sa fin qui pose chez chaque client l'état final de chaque lion
## (`Lion.poser_etat_final`, phase 18).

## Retard d'affichage, en ticks de l'hôte (100 ms à 60 ticks par seconde) : plus que la gigue simulée
## (40 ms) et deux états perdus de suite (2 × 16,7 ms).
const RETARD := 6.0
## Au-delà du dernier état reçu, le lion continue sur sa vitesse au plus autant de ticks, puis s'arrête.
const EXTRAPOLATION_MAX := 3.0
```

Dans `Scripts/InterpolationLion.gd`, remplacer :

```gdscript
			return {"position": a.position.lerp(b.position, t), "vitesse": a.vitesse.lerp(b.vitesse, t), "direction": a.direction}
	# Au-delà du dernier état : EXTRAPOLATION_MAX ticks sur sa vitesse, puis le retour au même pas, et
	# le dernier état lui-même, à l'arrêt (l'horloge d'un hôte figé plafonne à 1 / RATTRAPAGE - 1 -
	# RETARD = 13 ticks au-delà)
	var dernier: Dictionary = _etats[-1]
	var au_dela: float = _horloge - dernier.instant
	var avance := maxf(0.0, EXTRAPOLATION_MAX - absf(au_dela - EXTRAPOLATION_MAX))
	var vitesse: Vector2 = dernier.vitesse if au_dela <= EXTRAPOLATION_MAX else Vector2.ZERO
	return {"position": dernier.position + dernier.vitesse * avance / _ticks_par_seconde, "vitesse": vitesse, "direction": dernier.direction}
```

par :

```gdscript
			return {"position": a.position.lerp(b.position, t), "vitesse": a.vitesse.lerp(b.vitesse, t), "direction": a.direction}
	# Au-delà du dernier état : EXTRAPOLATION_MAX ticks sur sa vitesse au plus, puis à l'arrêt, là (M2)
	var dernier: Dictionary = _etats[-1]
	var au_dela: float = _horloge - dernier.instant
	var avance := minf(au_dela, EXTRAPOLATION_MAX)
	var vitesse: Vector2 = dernier.vitesse if au_dela < EXTRAPOLATION_MAX else Vector2.ZERO
	return {"position": dernier.position + dernier.vitesse * avance / _ticks_par_seconde, "vitesse": vitesse, "direction": dernier.direction}
```

- [ ] **Step 4 : les voir passer**

Run : unitaires, smoke, puis le banc (`T=tests/prediction_test.gd; O="--fixed-fps 60"`) et la trace. Expected : `== 0 échec(s) ==` partout (le banc inchangé : 45 vérifications), la trace inchangée.

- [ ] **Step 5 : commit**

```bash
git add Scripts/InterpolationLion.gd tests/unitaires.gd tests/smoke_test.gd
git commit -m "M2 de la revue finale 16 : plus aucun état, un lion distant continue au plus 3 ticks sur sa vitesse puis s'arrête là, sans jamais revenir vers le dernier état reçu (il glissait à reculons pendant un accroc du Wi-Fi, puis sautait en avant) ; l'état final de fin de manche viendra du bilan de l'hôte

<ligne fournie par l'environnement>"
```

---

### Task 3 : la fin de manche porte le bilan de l'hôte ; chaque client pose l'état final de chaque lion (`Manche`, `Lion`, `PredictionLocale`, version 0.18)

**Files:**
- Modify: `Scripts/Lion.gd` (en-tête, `fige`, setter d'`etat_reseau`, `_physics_process`, `poser_etat_final`), `Scripts/PredictionLocale.gd` (`arretee`, `arreter`), `Scripts/Manche.gd` (en-tête, `bilan_recu`, `bilan`, `_lions`, `suivre_lion`, `_sur_fin_de_partie`, `relever_bilan`, `_lion_de`, `_cellules_par_joueur`, `_recevoir_fin_manche`), `project.godot` (version 0.18)
- Test: `tests/smoke_test.gd` (la réplique d'un lion ; `_tester_manche_reseau`), `tests/prediction_test.gd` (`_scenario_fin_de_manche`), `tests/reseau/joueur.gd` (ligne `FIN` : le bilan et les lions affichés)

**Interfaces:**
- Consumes (Task 1) : `BilanManche.relever`, `encoder`, `decoder`, `resume`, `lions`, `crans`, `etourdissements`, `volees`, `chocs`, `partis`, `nb_joueurs()`, `temps`.
- Produces (Tasks 4, 5, 7) : `Lion.fige: bool` ; `func Lion.poser_etat_final(octets: PackedByteArray) -> bool` (faux sans rien changer pour un état illisible) ; `PredictionLocale.arretee: bool`, `func PredictionLocale.arreter() -> void` ; `signal Manche.bilan_recu(bilan: BilanManche)` (sur chaque poste, une fois la manche finie : chez l'hôte après l'envoi, chez un client après l'avoir appliqué) ; `var Manche.bilan: BilanManche` (null avant la fin) ; `func Manche.relever_bilan() -> BilanManche` ; RPC `Manche._recevoir_fin_manche(recu: Variant)` (un seul argument : `BilanManche.encoder()`), toujours sur `CANAL_PEINTURE` après les derniers tampons et le territoire.

Comportement chez un client à la fin reçue : le chrono de l'hôte ; chaque lion encore là prend son état final (`poser_etat_final` : position, sens, ni vitesse ni recul, `visuel` sans décalage ; le lion local arrête sa prédiction : plus de lecture des actions, plus de pas, plus de paquet) ; chaque joueur les crans (`recevoir_crans`) et les statistiques de l'hôte ; chaque départ du bilan est vu (`depart_vu`, idempotent en aval) ; puis `terminer_partie(true)` et `bilan_recu`. Un bilan illisible (jamais d'un hôte de la même version) est signalé (`push_error`) et la manche se termine sur ce que sait ce poste (`relever_bilan()`). Des cellules qui diffèrent de celles du bilan sont signalées, comme en phase 17.

- [ ] **Step 1 : les tests**

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
		"la fin d'étourdissement reçue efface étoiles et barbouillage, l'immunité clignote")
	repl.free()
```

par :

```gdscript
		"la fin d'étourdissement reçue efface étoiles et barbouillage, l'immunité clignote")
	# Phase 18 : la fin de manche pose sur la réplique l'état final de l'hôte, au pixel près ; elle ne
	# bouge plus, même quand un état de l'hôte encore en route arrive après
	var final_hote := EtatLion.encoder(1011, 0, Vector2(700 + 11 * pas_repl, 500), Vector2(350, 0), Vector2(40, 0), -1)
	_check(not repl.poser_etat_final(PackedByteArray([1, 2, 3])) and not repl.fige and repl.poser_etat_final(final_hote),
		"un état final illisible est refusé sans rien changer ; celui de l'hôte est posé")
	repl.etat_reseau = EtatLion.encoder(1012, 0, Vector2(900, 500), Vector2(350, 0), Vector2.ZERO, 1)
	await _frames(3)
	_check(repl.fige and repl.position == Vector2(700 + 11 * pas_repl, 500) and repl.direction_du_lion == -1 and repl.velocity == Vector2.ZERO
		and repl.deplacement.vitesse == Vector2.ZERO and repl.deplacement.recul == Vector2.ZERO,
		"la réplique prend l'état final de l'hôte (place, sens, à l'arrêt) et ne suit plus les états arrivés après (x = %.1f)" % repl.position.x)
	repl.free()
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
		manche.envois_ordre.clear()
		# La fin de la manche chez l'hôte : la manche la note (elle part vers chaque client prêt, après les
```

par :

```gdscript
		manche.envois_ordre.clear()
		GS.joueurs[0].chocs = 4  # les statistiques de l'hôte, que lui seul tient : elles partent avec la fin
		GS.joueurs[1].cellules_volees = 17
		var bilans_vus: Array = []
		manche.bilan_recu.connect(func(b: RefCounted) -> void: bilans_vus.append(b))
		# La fin de la manche chez l'hôte : la manche la note (elle part vers chaque client prêt, après les
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
			"I2 : les derniers tampons et le territoire partent avant la fin, sur le même canal (%s)" % [manche.envois_ordre])
		# Un hôte perdu (chez un client) : message, tout se fige
```

par :

```gdscript
			"I2 : les derniers tampons et le territoire partent avant la fin, sur le même canal (%s)" % [manche.envois_ordre])
		# Phase 18 : la fin porte le bilan de l'hôte : cellules, crans, statistiques, départs, l'état final
		# de chaque lion encore là (pas celui de Bob, parti)
		var bilan: BilanManche = manche.bilan
		var cellules_fin: Array[int] = [ville.territoire.cellules_de(0), ville.territoire.cellules_de(1)]
		_check(bilan != null and bilans_vus.size() == 1 and bilans_vus[0] == bilan and bilan.cellules == cellules_fin
			and bilan.chocs == [4, 0] and bilan.volees == [0, 17] and bilan.partis == [false, true] and bilan.lions.keys() == [0]
			and EtatLion.decoder(bilan.lions[0]).position == main.lion.position and is_equal_approx(bilan.temps, GS.temps_ecoule),
			"la fin porte le bilan de l'hôte, annoncé sur ce poste : cellules, statistiques, Bob parti, l'état final de son lion (%s)"
				% ("" if bilan == null else bilan.resume()))
		_check(bilan != null and BilanManche.decoder(bilan.encoder(), 2) != null and BilanManche.decoder(bilan.encoder(), 2).resume() == bilan.resume(),
			"le bilan envoyé se relit à l'identique chez un client")
		# Un hôte perdu (chez un client) : message, tout se fige
```

Dans `tests/prediction_test.gd`, remplacer :

```gdscript
	await _scenario_hote_fige()
	GS.configurer_solo()
```

par :

```gdscript
	await _scenario_hote_fige()
	await _scenario_fin_de_manche()
	GS.configurer_solo()
```

À la fin de `tests/prediction_test.gd`, ajouter :

```gdscript


## Phase 18 (M5 de la revue finale 16) : le joueur du client tient encore sa touche au gong. L'hôte se
## fige (la fin de manche) ; sa fin arrive un aller plus tard avec l'état final de chaque lion (le bilan) :
## chaque lion du client prend celui de l'hôte, au pixel près, et le lion prédit ne bouge plus, la touche
## toujours tenue (sa prédiction s'arrête : plus de pas, plus de paquet, aucun décalage).
func _scenario_fin_de_manche() -> void:
	print("-- Fin de manche, la touche tenue au gong, sous 80 ms, 40 ms, 5 %")
	_preparer(Vector2(300, 150), Vector2(400, 600), 80.0, 40.0, 5.0, 1800)
	for i in range(30):
		await _pas()
	_presser(Vector2.RIGHT)
	for i in range(40):
		await _pas()
	_vue_hote.process_mode = Node.PROCESS_MODE_DISABLED  # le gong : tout se fige chez l'hôte
	var final0: PackedByteArray = h0.etat_reseau
	var final1: PackedByteArray = h1.etat_reseau
	for i in range(3):
		await _pas()  # la fin est en route (un aller) ; la touche est toujours tenue
	var avance: float = c1.position.x - h1.position.x
	_check(avance > ECART_MAX, "(pré-condition) la touche tenue, le lion prédit du client est parti devant celui de l'hôte figé (%.1f px)" % avance)
	_check(c0.poser_etat_final(final0) and c1.poser_etat_final(final1), "le bilan de la fin pose l'état final de l'hôte sur chaque lion du client")
	for i in range(30):
		await _pas()
	var p: Node = c1.prediction
	_check(c1.position == h1.position and _affiche(c1) == h1.position and p.arretee and p.decalage() == Vector2.ZERO and p.paquet().is_empty(),
		"la touche toujours tenue, le lion prédit reste sur l'état final de l'hôte, sans décalage ni paquet : la prédiction est arrêtée (%.2f px)"
			% c1.position.distance_to(h1.position))
	_check(c0.position == h0.position and c0.velocity == Vector2.ZERO, "le lion distant est sur celui de l'hôte, à l'arrêt (%.2f px)" % c0.position.distance_to(h0.position))
	_vue_hote.process_mode = Node.PROCESS_MODE_INHERIT
	await _liberer()
```

Et dans le test réseau (la ligne `FIN` du scénario 13 porte aussi le bilan et les lions tels qu'affichés : chaque poste y peint sans lâcher ses touches jusqu'au gong, I2 de la phase 17) :

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
		"tout se fige sur le panneau de fin, le chrono à 0:00, %d tics sur %d attendus" % [hud.tics_joues, tics_attendus])
	print("FIN %s" % hud.resume())
	if hote:
```

par :

```gdscript
		"tout se fige sur le panneau de fin, le chrono à 0:00, %d tics sur %d attendus" % [hud.tics_joues, tics_attendus])
	print("FIN %s bilan=%s lions=%s" % [hud.resume(), manche.bilan.resume() if manche.bilan != null else "", _lions_affiches(main)])
	if hote:
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
			"puis retour au titre, hors réseau")


## Joue le programme de ce poste, image après image, jusqu'à `condition` (au plus `delai` secondes).
```

par :

```gdscript
			"puis retour au titre, hors réseau")


## Les lions de ce poste tels qu'ils s'affichent (le corps et le décalage de la prédiction), en une ligne
## (phase 18 : la même partout une fois l'état final de l'hôte posé, même lancés en pleine course au gong).
func _lions_affiches(main: Node) -> String:
	return ";".join(main.lions.map(func(l: Node) -> String:
		return "%s@%.1f,%.1f,%d" % [l.name, l.position.x + l.visuel.position.x, l.position.y + l.visuel.position.y, l.direction_du_lion]))


## Joue le programme de ce poste, image après image, jusqu'à `condition` (au plus `delai` secondes).
```

- [ ] **Step 2 : les voir échouer**

Run : smoke, puis le banc (`T=tests/prediction_test.gd; O="--fixed-fps 60"`).
Expected : smoke `SCRIPT ERROR: Invalid call. Nonexistent function 'poser_etat_final' in base 'CharacterBody2D (Lion)'.` (la section de la réplique s'interrompt là) ; banc, la même erreur dans « -- Fin de manche, la touche tenue au gong, sous 80 ms, 40 ms, 5 % ».

- [ ] **Step 3 : l'état final du lion et l'arrêt de la prédiction**

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
## lion du joueur local est prédit (`prediction`, `PredictionLocale`) : il avance tout de suite avec les
## commandes de ce poste, par le même pas que l'hôte (`avancer`), et se recale sur ses états.

const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
```

par :

```gdscript
## lion du joueur local est prédit (`prediction`, `PredictionLocale`) : il avance tout de suite avec les
## commandes de ce poste, par le même pas que l'hôte (`avancer`), et se recale sur ses états. À la fin de
## la manche (phase 18), chaque lion d'un client prend l'état final que l'hôte a au gong
## (`poser_etat_final`) et ne bouge plus.

const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
var _interpolation: InterpolationLion
## Chez l'hôte, l'état du lion écrit à chaque tick physique (`EtatLion.encoder`), que le `Synchro`
```

par :

```gdscript
var _interpolation: InterpolationLion
## Sur un client, vrai une fois l'état final de la manche posé (`poser_etat_final`) : le lion ne bouge
## plus et ne garde plus aucun état de l'hôte.
var fige := false
## Chez l'hôte, l'état du lion écrit à chaque tick physique (`EtatLion.encoder`), que le `Synchro`
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
		etat_reseau = valeur
		if not _replique:
			return
```

par :

```gdscript
		etat_reseau = valeur
		if not _replique or fige:
			return
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
	if not multiplayer.is_server():
		if prediction == null:
```

par :

```gdscript
	if not multiplayer.is_server():
		if fige:
			return
		if prediction == null:
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
	_animer_deplacement(delta)


## Sur un client, pour la prédiction : le plus récent des états reçus de l'hôte depuis le dernier appel
```

par :

```gdscript
	_animer_deplacement(delta)


## Sur un client, à la fin de la manche (phase 18) : le lion prend l'état final que l'hôte a au gong
## (`octets`, un `EtatLion` du bilan de la fin, `Manche._recevoir_fin_manche`) : sa position et son
## orientation, ni vitesse ni recul, aucun décalage d'affichage ; sa prédiction s'arrête (un joueur qui
## tient encore ses touches au gong ne le fait plus avancer sur son écran) et plus aucun état de l'hôte
## n'est gardé. Faux, sans rien changer, pour un état illisible.
func poser_etat_final(octets: PackedByteArray) -> bool:
	var etat := EtatLion.decoder(octets)
	if etat.is_empty():
		return false
	fige = true
	_etats_recus.clear()
	if prediction != null:
		prediction.arreter()
	position = etat.position
	direction_du_lion = etat.direction
	velocity = Vector2.ZERO
	deplacement.vitesse = Vector2.ZERO
	deplacement.recul = Vector2.ZERO
	visuel.position = Vector2.ZERO
	return true


## Sur un client, pour la prédiction : le plus récent des états reçus de l'hôte depuis le dernier appel
```

Dans `Scripts/PredictionLocale.gd`, remplacer :

```gdscript
## (étourdissement, recul d'un coup) arrivent dans ses états : jamais notées ni rejouées ici.
## Nœud : il nomme `Lion` ; les tests `--script` ne le nomment pas.
```

par :

```gdscript
## (étourdissement, recul d'un coup) arrivent dans ses états : jamais notées ni rejouées ici.
## À la fin de la manche (phase 18, M5 de la revue finale 16), `arreter` : plus de lecture des actions de
## ce poste, plus de pas ni de rejeu, aucun décalage ; le lion garde l'état final posé par l'hôte.
## Nœud : il nomme `Lion` ; les tests `--script` ne le nomment pas.
```

Dans `Scripts/PredictionLocale.gd`, remplacer :

```gdscript
var rejeu_max := 0

var _lion: Lion
```

par :

```gdscript
var rejeu_max := 0
## Vrai une fois la manche finie (`arreter`).
var arretee := false

var _lion: Lion
```

Dans `Scripts/PredictionLocale.gd`, remplacer :

```gdscript
func _physics_process(delta: float) -> void:
	var suspendues := _lion.commandes.suspendues
```

par :

```gdscript
func _physics_process(delta: float) -> void:
	if arretee:
		return
	var suspendues := _lion.commandes.suspendues
```

Dans `Scripts/PredictionLocale.gd`, remplacer :

```gdscript
	_lion.visuel.position = _decalage


## Le paquet de commandes à envoyer à l'hôte : la dernière lue et jusqu'à REDONDANCE précédentes
```

par :

```gdscript
	_lion.visuel.position = _decalage


## La manche est finie (phase 18, `Lion.poser_etat_final`) : les actions de ce poste ne sont plus lues,
## le lion ne fait plus de pas ni de rejeu, son décalage d'affichage tombe à zéro et plus aucun paquet ne
## part (l'historique est vidé).
func arreter() -> void:
	arretee = true
	_historique.clear()
	_decalage = Vector2.ZERO
	_lion.commandes.direction_voulue = Vector2.ZERO
	_lion.commandes.vomir_voulu = false
	_lion.visuel.position = Vector2.ZERO


## Le paquet de commandes à envoyer à l'hôte : la dernière lue et jusqu'à REDONDANCE précédentes
```

- [ ] **Step 4 : la fin de manche et son bilan**

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
## - Fin de manche (phase 17) : décidée par l'hôte seul (son chrono, ses règles), elle part après ses
##   derniers tampons et son territoire, sur le même canal fiable ordonné, avec son chrono et ses
##   scores ; chaque client la reçoit, prend le chrono de l'hôte et termine sa manche (tout se fige, le
##   HUD montre la fin), puis n'envoie plus de commandes. Le chrono d'un client, parti à la fin de sa
##   propre intro, ne termine jamais rien lui-même. L'état final de chaque lion viendra avec cette fin
##   en phase 18.
## Nœud de scène : il nomme `Reseau` et `GameState` ; les tests `--script` ne le nomment pas.
```

par :

```gdscript
## - Fin de manche (phase 17) : décidée par l'hôte seul (son chrono, ses règles), elle part après ses
##   derniers tampons et son territoire, sur le même canal fiable ordonné, avec son bilan (phase 18,
##   `BilanManche` : son chrono, les cellules, crans et statistiques de chaque joueur, les départs,
##   l'état final de chaque lion) ; chaque client la reçoit, prend le chrono de l'hôte, pose l'état final
##   de chaque lion (sa prédiction s'arrête), les crans et les statistiques de l'hôte, et termine sa
##   manche (tout se fige), puis n'envoie plus de commandes. Sur chaque poste, `bilan_recu` donne ce
##   bilan à l'écran Résultats. Le chrono d'un client, parti à la fin de sa propre intro, ne termine
##   jamais rien lui-même.
## Nœud de scène : il nomme `Reseau` et `GameState` ; les tests `--script` ne le nomment pas.
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
signal depart_vu(index: int)

## Délai de la barrière de chargement, en secondes : au-delà, les joueurs dont la scène n'est pas
```

par :

```gdscript
signal depart_vu(index: int)
## Sur chaque poste, une fois la manche finie (phase 18) : le bilan de l'hôte (chez l'hôte, relevé au
## gong ; chez un client, reçu avec la fin et déjà appliqué), que montre l'écran Résultats.
signal bilan_recu(bilan: BilanManche)

## Délai de la barrière de chargement, en secondes : au-delà, les joueurs dont la scène n'est pas
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
var ecart_chrono_fin := 0.0
## Hôte : la suite des méthodes passées à `_envoyer`, dans l'ordre (I2, revue finale phase 17) : lue
```

par :

```gdscript
var ecart_chrono_fin := 0.0
## Le bilan de la manche une fois finie (`bilan_recu`) ; null avant.
var bilan: BilanManche
## Hôte : la suite des méthodes passées à `_envoyer`, dans l'ordre (I2, revue finale phase 17) : lue
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
var _prediction: PredictionLocale


func _ready() -> void:
```

par :

```gdscript
var _prediction: PredictionLocale
## Sur chaque poste : le lion de chaque joueur, par index (`suivre_lion`) ; chez l'hôte, leur état final
## entre dans le bilan ; chez un client, chacun y prend le sien. Celui d'un joueur parti y reste, libéré :
## chaque lecture passe par `_lion_de`.
var _lions: Dictionary[int, Lion] = {}


func _ready() -> void:
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
func suivre_lion(lion: Lion) -> void:
	var local := lion.joueur == GameState.joueur_local()
```

par :

```gdscript
func suivre_lion(lion: Lion) -> void:
	_lions[lion.joueur.index] = lion
	var local := lion.joueur == GameState.joueur_local()
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
## Chez l'hôte : la manche est finie (son chrono, ou le test réseau qui la fige). Ses derniers tampons
## et son territoire partent d'abord, puis la fin, sur le même canal fiable ordonné : chez un client,
## la fin arrive après eux, les scores définitifs déjà appliqués.
func _sur_fin_de_partie(_victoire: bool) -> void:
```

par :

```gdscript
## Chez l'hôte : la manche est finie (son chrono, ou le test réseau qui la fige). Ses derniers tampons
## et son territoire partent d'abord, puis la fin et son bilan, sur le même canal fiable ordonné : chez
## un client, la fin arrive après eux, les scores définitifs déjà appliqués.
func _sur_fin_de_partie(_victoire: bool) -> void:
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
	_diffuser_territoire()
	var territoire: Territoire = _ville.territoire
	_envoyer(&"_recevoir_fin_manche", [GameState.temps_ecoule, PackedInt32Array() if territoire == null else territoire.scores()])


## Chez un client : la manche est finie chez l'hôte, à son chrono `temps`, sur ses scores `scores`
## (déjà appliqués : la fin suit son dernier territoire sur le même canal ; un écart est signalé). Le
## chrono de ce poste prend celui de l'hôte, puis la manche se termine ici aussi.
@rpc("authority", "call_remote", "reliable", CANAL_PEINTURE)
func _recevoir_fin_manche(temps: Variant, scores: Variant) -> void:
	if not actif or finie or not (temps is float) or not is_finite(temps) or temps < 0.0:
		return
	finie = true
	var territoire: Territoire = null if _ville == null else _ville.territoire
	if territoire != null and (not (scores is PackedInt32Array) or scores != territoire.scores()):
		push_error("Manche : scores de fin désynchronisés de l'hôte (%s au lieu de %s)" % [territoire.scores(), scores])
	ecart_chrono_fin = temps - GameState.temps_ecoule
	GameState.temps_ecoule = temps
	GameState.terminer_partie(true)


# --- Départs ----------------------------------------------------------------------------------------
```

par :

```gdscript
	_diffuser_territoire()
	bilan = relever_bilan()
	_envoyer(&"_recevoir_fin_manche", [bilan.encoder()])
	bilan_recu.emit(bilan)


## Le bilan de la manche tel que ce poste le voit en ce moment : le chrono, les cellules de chaque
## joueur (le territoire), ses crans et ses statistiques, les départs, l'état de chaque lion encore là.
## Celui de l'hôte au gong fait foi (`_sur_fin_de_partie`).
func relever_bilan() -> BilanManche:
	var etats: Dictionary[int, PackedByteArray] = {}
	for index: int in _lions:
		var l := _lion_de(index)
		if l != null:
			etats[index] = EtatLion.encoder(Engine.get_physics_frames(), l.commandes.numero_applique, l.position,
				l.deplacement.vitesse, l.deplacement.recul, l.direction_du_lion)
	return BilanManche.relever(GameState.joueurs, _cellules_par_joueur(), _partis, etats, GameState.temps_ecoule)


## Le lion du joueur d'index `index` s'il est encore dans l'arbre, sinon null (jamais apparu, ou parti :
## libéré).
func _lion_de(index: int) -> Lion:
	var l: Variant = _lions.get(index)
	return l if is_instance_valid(l) and (l as Lion).is_inside_tree() else null


## Les cellules de chaque joueur, dans l'ordre des index, lues sur le territoire (aucune sans lui).
func _cellules_par_joueur() -> Array[int]:
	var territoire: Territoire = null if _ville == null else _ville.territoire
	var cellules: Array[int] = []
	for j in GameState.joueurs:
		cellules.append(0 if territoire == null else territoire.cellules_de(j.index))
	return cellules


## Chez un client : la manche est finie chez l'hôte ; `recu`, son bilan (`BilanManche.encoder`), arrive
## après son dernier territoire sur le même canal (des cellules qui diffèrent sont signalées). Le chrono
## de ce poste prend celui de l'hôte, chaque lion son état final (la prédiction du lion de ce poste
## s'arrête), chaque joueur ses crans et ses statistiques de l'hôte (qui seul les tient) ; les départs
## du bilan sont vus (ceux dont l'annonce, sur un autre canal, n'est pas encore arrivée) ; puis la manche
## se termine ici aussi. Un bilan illisible (jamais d'un hôte de la même version) est signalé, et la
## manche se termine sur ce que sait ce poste. Les réactions de l'hôte encore en route (canal 0)
## s'appliquent encore à leur arrivée : elles précèdent sa fin chez lui ; l'écran Résultats ne lit que le
## bilan.
@rpc("authority", "call_remote", "reliable", CANAL_PEINTURE)
func _recevoir_fin_manche(recu: Variant) -> void:
	if not actif or finie:
		return
	var lu := BilanManche.decoder(recu, GameState.joueurs.size())
	if lu == null:
		push_error("Manche : bilan de fin de l'hôte illisible, la manche se termine sur ce que sait ce poste")
		lu = relever_bilan()
	finie = true
	if _cellules_par_joueur() != lu.cellules:
		push_error("Manche : scores de fin désynchronisés de l'hôte (%s au lieu de %s)" % [_cellules_par_joueur(), lu.cellules])
	ecart_chrono_fin = lu.temps - GameState.temps_ecoule
	GameState.temps_ecoule = lu.temps
	for index: int in lu.lions:
		var l := _lion_de(index)
		if l != null:
			l.poser_etat_final(lu.lions[index])
	for i in range(lu.nb_joueurs()):
		var j: Joueur = GameState.joueurs[i]
		j.recevoir_crans(lu.crans[i])
		j.etourdissements_infliges = lu.etourdissements[i]
		j.cellules_volees = lu.volees[i]
		j.chocs = lu.chocs[i]
		if lu.partis[i]:
			depart_vu.emit(i)
	bilan = lu
	GameState.terminer_partie(true)
	bilan_recu.emit(bilan)


# --- Départs ----------------------------------------------------------------------------------------
```

Et la version du protocole (la fin de manche change de forme) :

Dans `project.godot`, remplacer :

```ini
config/name="LeLion"
config/version="0.17"
run/main_scene="res://Scenes/Titre.tscn"
```

par :

```ini
config/name="LeLion"
config/version="0.18"
run/main_scene="res://Scenes/Titre.tscn"
```

- [ ] **Step 5 : les voir passer**

Run : unitaires, smoke, bataille, banc, la trace, puis le test réseau (commandes des Global Constraints).
Expected : `== 0 échec(s) ==` partout, dont au smoke « la réplique prend l'état final de l'hôte (place, sens, à l'arrêt) et ne suit plus les états arrivés après (x = 764.2) » et « la fin porte le bilan de l'hôte, annoncé sur ce poste : cellules, statistiques, Bob parti, l'état final de son lion (…) », au banc « (pré-condition) la touche tenue, le lion prédit du client est parti devant celui de l'hôte figé (46.7 px) » puis « … la prédiction est arrêtée (0.00 px) » et « le lion distant est sur celui de l'hôte, à l'arrêt (0.00 px) » ; la trace inchangée ; le test réseau `== 0 échec(s) ==`, ses trois lignes `(chrono) FIN …` identiques, lions compris (les places changent d'un passage à l'autre ; un passage mesuré : `lions=Lion1@825.2,608.3,1;Lion2@560.6,701.9,-1;Lion3@1872.0,688.1,1` sur les trois postes, chacun en pleine course au gong).

Contre-épreuve (sans la committer) : remplacer dans `Lion.poser_etat_final` la ligne `prediction.arreter()` par `pass`, relancer le banc : `❌ la touche toujours tenue, le lion prédit reste sur l'état final de l'hôte… (152.33 px)` ; puis `git checkout -- Scripts/Lion.gd`.

- [ ] **Step 6 : commit**

```bash
git add Scripts/Lion.gd Scripts/PredictionLocale.gd Scripts/Manche.gd project.godot tests/smoke_test.gd tests/prediction_test.gd tests/reseau/joueur.gd
git commit -m "Fin de manche : l'hôte envoie son bilan (chrono, cellules, crans, statistiques, départs, état final de chaque lion) après ses derniers tampons et son territoire ; chaque client pose l'état final de chaque lion et arrête sa prédiction (un joueur qui tient ses touches au gong ne continue plus sur son écran), prend crans et statistiques de l'hôte ; bilan_recu sur chaque poste ; version 0.18

<ligne fournie par l'environnement>"
```

---

### Task 4 : l'écran Résultats (`Resultats`), à la place du panneau de fin du HUD ; Revanche et Niveau suivant en bataille locale

**Files:**
- Create: `Scenes/Resultats.tscn`, `Scripts/Resultats.gd` (+ `Scripts/Resultats.gd.uid`, généré par l'import)
- Modify: `Scripts/HUDBataille.gd` (le panneau de fin, sa sortie et `texte_gagnant` s'en vont), `Scenes/HUDBataille.tscn` (le nœud `Fin` s'en va ; plus de `process_mode` « toujours »), `Scripts/Main.gd` (`resultats`, `_afficher_resultats`, `_bilan_local`, `_sur_choix_resultats`, `_sur_depart_vu`, `_enter_tree` qui dépause, `_sur_hote_perdu`, `_on_partie_terminee`), `Assets/Traductions/traductions.csv` (+ les deux `.translation`)
- Test: `tests/bataille_test.gd` (`_tester_hud`, `_tester_resultats` ➕, `_attendre_nouvelle_scene` ➕, `_verifier_manche_neuve` ➕, `_appuyer` ➕), `tests/smoke_test.gd` (`_tester_manche_reseau`), `tests/reseau/joueur.gd` (`_finir_au_chrono`)

**Interfaces:**
- Consumes (Tasks 1, 3) : `BilanManche` (`classement`, `rangs`, `parts`, `meneurs`, `laureats`, `record`, `partis`, `volees`, `etourdissements`, `chocs`, `TITRES`) ; `Manche.bilan_recu` ; `HUDBataille.nom_affiche(joueur)`, `HUDBataille.Couronne`, `PLACE_COURONNE`, `TAILLE_COURONNE`, `INCLINAISON_COURONNE`.
- Produces (Tasks 5, 6, 7, 8) : `Scenes/Resultats.tscn` (un `CanvasLayer`, calque 8, `process_mode` « toujours ») et son script : `signal choix_fait(choix: StringName)` ; `const CHOIX: Array[StringName] = [&"revanche", &"suivant", &"salon", &"quitter"]`, `const DELAI_CHOIX := 1.0`, `const LARGEUR_PSEUDO := 360` ; `var bilan: BilanManche`, `var hote: bool`, `var en_reseau: bool`, `var choix: StringName` (vide tant que rien n'est choisi), `var partis: Array[bool]`, `var lignes: Array[Dictionary]` (`index`, `ligne`, `rang`, `lion`, `couronne`, `pseudo`, `barre`, `part`, `stats` (étourdissements infligés, cellules volées, chocs), `badge`, `cible`), `var cartes_titres: Array[Dictionary]` (`cadre`, `titre`, `nom`, `valeur`), `var selection: StringName`, `var animation_finie: bool` ; `@onready` `titre`, `gagnant`, `tableau`, `rangee_titres`, `boutons`, `etat`, `aide`, `bouton_revanche`, `bouton_suivant`, `bouton_salon`, `bouton_quitter` ; `func afficher(bilan_: BilanManche, hote_: bool, en_reseau_: bool) -> void` ; `func choisir(voulu: StringName) -> void` ; `func annuler_choix() -> void` ; `func marquer_parti(index: int) -> void` ; `func rafraichir() -> void` ; `func possible(voulu: StringName) -> bool` ; `func resume() -> String` (le même sur chaque poste : sans « TOI ») ; `func texte_gagnant(meneurs: PackedStringArray) -> String` ; `func terminer_animation() -> void`. `Main.resultats: CanvasLayer` (null avant la fin) ; `func Main._sur_choix_resultats(choix: StringName) -> void` (en bataille locale : Quitter, Revanche, Niveau suivant ; en réseau, la Task 5 ajoute les siens).

L'écran (captures de la Task 8) : sur la ville figée assombrie, « FIN DE LA MANCHE ! » et la ligne du gagnant ; le classement, une ligne par joueur : rang (« 1er »… ; « – » sans cellule), lion teint (couronné pour chaque meneur), pseudo dans sa couleur (12 caractères larges tiennent), la barre de sa part à sa couleur et le pourcentage (animés de 0 à la part : l'animation du bilan du solo), ses étourdissements infligés, cellules volées et chocs, « TOI » ou « PARTI » (la ligne grisée) ; trois cartes de titres (le titre, le ou les lauréats, un par ligne, leur record) ; les boutons (l'hôte : Revanche, « Niveau suivant : <niveau> », Retour au salon en réseau, Quitter ; un client : Quitter), la ligne d'état (« En attente de l'hôte… » chez un client ; chez l'hôte, pourquoi Revanche est grisée), l'aide des commandes.

- [ ] **Step 1 : les tests**

Dans `tests/bataille_test.gd` (l'écran Résultats remplace le panneau de fin du HUD ; une section neuve pour l'écran d'une bataille locale et ses choix) :

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	await _tester_hud()
	await _tester_retour_au_titre()
```

par :

```gdscript
	await _tester_hud()
	await _tester_resultats()
	await _tester_retour_au_titre()
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	_check(hud.vignettes[3].cadre.modulate.a < 0.5 and hud.vignettes[3].badge.text == "PARTI", "un joueur parti reste au classement, en grisé")
	_check(hud.texte_gagnant(PackedStringArray()) == "Personne n'a peint la ville." and hud.texte_gagnant(PackedStringArray(["Zoé"])) == "Zoé gagne la manche !"
		and hud.texte_gagnant(PackedStringArray(["Anna", "Bruno"])) == "Égalité : Anna, Bruno !",
		"le panneau de fin nomme le gagnant, les ex æquo, ou personne")
	# Les dix dernières secondes : le chrono rougit et tique, jusqu'à la fin au chrono
```

par :

```gdscript
	_check(hud.vignettes[3].cadre.modulate.a < 0.5 and hud.vignettes[3].badge.text == "PARTI", "un joueur parti reste au classement, en grisé")
	# Les dix dernières secondes : le chrono rougit et tique, jusqu'à la fin au chrono
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
		"dix tics dans les dix dernières secondes (%d), le chrono rouge à 0:00" % (hud.tics_joues - tics_avant))
	_check(hud.fin.visible and hud.gagnant.text == "Joueur 2 gagne la manche !" and not main.menu_pause.visible
		and main.menu_pause.process_mode == Node.PROCESS_MODE_DISABLED,
		"le panneau de fin nomme le gagnant (%s) ; le menu local se tait" % hud.gagnant.text)
	# Espace (vomir, valider) encore tenu au gong ne quitte pas la partie : le bouton ne prend pas le focus
	for action: StringName in [&"vomir", &"ui_accept"]:
```

par :

```gdscript
		"dix tics dans les dix dernières secondes (%d), le chrono rouge à 0:00" % (hud.tics_joues - tics_avant))
	var resultats: CanvasLayer = main.resultats
	_check(resultats != null and resultats.visible and not hud.visible and resultats.gagnant.text == "Joueur 2 gagne la manche !"
		and not main.menu_pause.visible and main.menu_pause.process_mode == Node.PROCESS_MODE_DISABLED,
		"phase 18 : l'écran Résultats remplace le HUD et nomme le gagnant (%s) ; le menu local se tait"
			% ("" if resultats == null else resultats.gagnant.text))
	# Espace (vomir, valider) appuyé au gong ne quitte pas la partie : aucun bouton ne prend le focus
	for action: StringName in [&"vomir", &"ui_accept"]:
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	await _frames(3)
	_check(current_scene == main and hud.fin.visible and root.gui_get_focus_owner() == null,
		"Espace tenu au gong (vomir, valider) ne quitte pas la partie : rien n'a le focus")
	var scores: Node = root.get_node("Scores")
	scores.chemin = "user://scores_test_bataille.cfg"  # l'écran titre enregistre ses préférences
	var echap := InputEventAction.new()
	echap.action = &"pause"
	echap.pressed = true
```

par :

```gdscript
	await _frames(3)
	_check(current_scene == main and resultats.visible and resultats.choix.is_empty() and root.gui_get_focus_owner() == null,
		"Espace appuyé au gong (vomir, valider) ne choisit rien et ne quitte pas la partie : rien n'a le focus")
	var scores: Node = root.get_node("Scores")
	scores.chemin = "user://scores_test_bataille.cfg"  # l'écran titre enregistre ses préférences
	var echap := InputEventAction.new()
	echap.action = &"ui_cancel"
	echap.pressed = true
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	_check(current_scene != null and current_scene.scene_file_path == "res://Scenes/Titre.tscn" and not paused and GS.regles is ReglesSolo,
		"Échap, la manche finie : retour au titre (le solo), en attendant les résultats de la phase 18")
	current_scene.free()
```

par :

```gdscript
	_check(current_scene != null and current_scene.scene_file_path == "res://Scenes/Titre.tscn" and not paused and GS.regles is ReglesSolo,
		"Échap, sur l'écran Résultats : retour au titre (le solo)")
	current_scene.free()
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	GS.configurer_bataille(NB_LIONS)  # la section suivante part d'une bataille


func _tester_retour_au_titre() -> void:
```

par :

```gdscript
	GS.configurer_bataille(NB_LIONS)  # la section suivante part d'une bataille


## Phase 18 : l'écran Résultats d'une bataille locale (le bilan de ce poste) : classement, parts,
## statistiques, titres et choix, au clavier comme à la souris ; Niveau suivant puis Revanche relancent
## une manche neuve (territoire, Spawner, chrono), avec les mêmes joueurs.
func _tester_resultats() -> void:
	print("-- Écran Résultats (phase 18)")
	var main := await _charger_bataille(0)
	var ville: Node2D = main.get_node("Ville")
	var t: Territoire = ville.territoire
	await _attendre_depart()
	var bas: float = ville.position.y + ville.tex_size.y / 2.0 - 30.0
	for k in range(3):
		ville.peindre(Vector2(500, bas), 30, GS.joueurs[1])
		ville.peindre(Vector2(1500, bas), 20, GS.joueurs[3])
	await _frames(1)
	var cellules: Array[int] = [t.cellules_de(0), t.cellules_de(1), t.cellules_de(2), t.cellules_de(3)]
	_check(cellules[1] > cellules[3] and cellules[3] > 0 and cellules[0] == 0 and cellules[2] == 0,
		"(pré-condition) les joueurs 2 et 4 ont peint, le 2 plus que le 4 (%s)" % [cellules])
	GS.joueurs[0].etourdissements_infliges = 2
	GS.joueurs[2].etourdissements_infliges = 2
	GS.joueurs[3].cellules_volees = 40
	GS.joueurs[1].chocs = 5
	Input.action_press("vomir")  # Espace tenu au gong
	GS.terminer_partie(true)
	await _frames(1)
	var r: CanvasLayer = main.resultats
	_check(r != null and r.visible and not main.hud_bataille.visible and paused, "la manche finie, l'écran Résultats remplace le HUD, tout figé")
	var parts := ReglesBataille.parts(cellules)
	_check(r.lignes.map(func(l: Dictionary) -> int: return l.index) == [1, 3, 0, 2]
		and r.lignes.map(func(l: Dictionary) -> int: return l.cible) == [parts[1], parts[3], 0, 0] and parts[1] + parts[3] == 100,
		"le classement : le plus de cellules d'abord, les joueurs sans cellule à la fin, par index ; les parts font 100 %% (%s)" % [parts])
	_check(r.lignes[0].rang.text == "1er" and r.lignes[1].rang.text == "2e" and r.lignes[2].rang.text == "–"
		and r.lignes[0].couronne.visible and not r.lignes[1].couronne.visible and r.gagnant.text == "Joueur 2 gagne la manche !",
		"rangs, couronne du meneur et gagnant (%s)" % r.gagnant.text)
	_check(r.lignes[2].stats.map(func(e: Label) -> String: return e.text) == ["2", "0", "0"]
		and r.lignes[1].stats.map(func(e: Label) -> String: return e.text) == ["0", "40", "0"] and r.lignes[2].badge.text == "TOI",
		"chaque ligne : étourdissements infligés, cellules volées, chocs ; « TOI » sur celle de ce poste")
	_check(r.cartes_titres[0].nom.text == "Joueur 1\nJoueur 3" and r.cartes_titres[0].valeur.text == "Étourdissements infligés : 2"
		and r.cartes_titres[1].nom.text == "Joueur 4" and r.cartes_titres[2].nom.text == "Joueur 2" and r.cartes_titres[2].valeur.text == "Chocs : 5",
		"les trois titres, ex æquo compris : le plus vicieux, le voleur, l'auto-tamponneur")
	_check(r.texte_gagnant(PackedStringArray()) == "Personne n'a peint la ville." and r.texte_gagnant(PackedStringArray(["Zoé"])) == "Zoé gagne la manche !"
		and r.texte_gagnant(PackedStringArray(["Anna", "Bruno"])) == "Égalité : Anna, Bruno !",
		"la ligne du gagnant nomme le gagnant, les ex æquo, ou personne")
	var pseudo: Label = r.lignes[0].pseudo
	var largeur_w: float = pseudo.get_theme_font("font").get_string_size("WWWWWWWWWWWW", HORIZONTAL_ALIGNMENT_LEFT, -1,
		pseudo.get_theme_font_size("font_size")).x + 2 * pseudo.get_theme_constant("outline_size")
	_check(largeur_w <= pseudo.size.x and r.tableau.get_combined_minimum_size().x <= TAILLE_BATAILLE.x,
		"12 caractères larges (%d px) tiennent dans la colonne des pseudos (%d px) ; le tableau dans l'écran (%d px)"
			% [largeur_w, pseudo.size.x, r.tableau.get_combined_minimum_size().x])
	_check(r.bouton_revanche.visible and r.bouton_suivant.visible and not r.bouton_salon.visible and r.bouton_quitter.visible
		and not r.bouton_revanche.disabled and r.bouton_suivant.text == "Niveau suivant : Métropole" and r.etat.text == ""
		and [r.bouton_revanche, r.bouton_suivant, r.bouton_quitter].all(func(b: Button) -> bool: return b.focus_mode == Control.FOCUS_NONE),
		"en bataille locale : Revanche, Niveau suivant (Métropole) et Quitter, sans Retour au salon ; aucun ne prend le focus")
	# Au clavier : Espace tenu depuis le gong n'agit pas ; un appui termine l'animation ; un choix n'est pris
	# qu'une seconde après
	await _appuyer(&"vomir", true)  # un événement de plus de la touche tenue
	_check(not r.animation_finie and r.choix.is_empty(), "Espace tenu depuis le gong ne coupe pas l'animation et ne choisit rien")
	await _appuyer(&"vomir", false)
	Input.action_release("vomir")
	await _appuyer(&"deplacer_droite", true)
	await _appuyer(&"deplacer_droite", false)
	_check(r.animation_finie and r.selection == &"revanche", "un appui pendant l'animation la termine, sans changer le choix sélectionné")
	await _appuyer(&"deplacer_droite", true)
	await _appuyer(&"deplacer_droite", false)
	_check(r.selection == &"revanche", "juste après l'animation, un appui ne choisit encore rien (Espace martelé au gong)")
	await _frames(int(r.DELAI_CHOIX * Engine.physics_ticks_per_second) + 5)
	await _appuyer(&"deplacer_droite", true)
	await _appuyer(&"deplacer_droite", false)
	_check(r.selection == &"suivant", "puis droite sélectionne Niveau suivant")
	var avant := main.get_instance_id()
	await _appuyer(&"vomir", true)
	var suivante: Node = await _attendre_nouvelle_scene(avant)
	await _appuyer(&"vomir", false)
	await _verifier_manche_neuve(suivante, 1, "Niveau suivant")
	# Revanche, à la souris : le même niveau
	GS.terminer_partie(true)
	await _frames(1)
	suivante.resultats.choisir(&"revanche")
	var revanche: Node = await _attendre_nouvelle_scene(suivante.get_instance_id())
	await _verifier_manche_neuve(revanche, 1, "Revanche")
	await _liberer(revanche)
	GS.niveau_courant = 0


## La scène de jeu qui remplace celle d'identifiant `avant` (rechargée), une fois prête ; null au-delà de
## 300 images.
func _attendre_nouvelle_scene(avant: int) -> Node:
	for f in range(300):
		if current_scene != null and current_scene.get_instance_id() != avant and current_scene.is_node_ready():
			return current_scene
		await process_frame
	return null


## Une manche relancée depuis l'écran Résultats (`titre`) : sur le niveau `niveau`, les mêmes joueurs,
## tout neuf : aucune cellule, chrono à 1:30, ni écran Résultats ni pause, statistiques à zéro, et le
## Spawner qui repart après l'intro.
func _verifier_manche_neuve(main: Node, niveau: int, titre: String) -> void:
	_check(main != null and main.scene_file_path == "res://Scenes/Main.tscn", "(%s) la scène de jeu est rechargée" % titre)
	if main == null:
		return
	var t: Territoire = main.get_node("Ville").territoire
	_check(GS.niveau_courant == niveau and main.lions.size() == NB_LIONS and GS.joueurs.size() == NB_LIONS
		and range(NB_LIONS).all(func(i: int) -> bool: return t.cellules_de(i) == 0) and t.cellules_de(Territoire.PERSONNE) == t.nb_peignables,
		"(%s) niveau %d, les mêmes 4 joueurs, un territoire vierge" % [titre, niveau])
	_check(not paused and GS.partie_en_cours and GS.temps_ecoule == 0.0 and main.hud_bataille.visible and main.hud_bataille.chrono.text == "1:30"
		and main.resultats == null and GS.joueurs.all(func(j: Joueur) -> bool: return j.chocs == 0 and j.cellules_volees == 0 and j.etourdissements_infliges == 0 and j.crans == 1),
		"(%s) le chrono repart de 1:30, sans écran Résultats ni pause, statistiques et crans remis à zéro" % titre)
	await _attendre_depart()
	var spawner: Node = main.get_node("Spawner")
	_check(GS.pret and spawner._demarre and spawner._timer_soucoupe != null, "(%s) après l'intro, le Spawner repart" % titre)


## Un appui (ou un relâchement) de `action`, comme le clavier ou la manette l'envoient au jeu.
func _appuyer(action: StringName, appuye: bool) -> void:
	var evenement := InputEventAction.new()
	evenement.action = action
	evenement.pressed = appuye
	root.push_input(evenement)
	await process_frame


func _tester_retour_au_titre() -> void:
```

Dans `tests/smoke_test.gd` (la fin chez l'hôte en réseau) :

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
		GS.terminer_partie(true)
		_check(manche.finie and paused and hud.fin.visible and not menu.visible, "la fin de manche chez l'hôte : la manche la diffuse, tout se fige, le panneau de fin s'affiche")
		_check(manche.envois_ordre == ([&"_recevoir_tampons", &"_recevoir_territoire", &"_recevoir_fin_manche"] as Array[StringName]),
```

par :

```gdscript
		GS.terminer_partie(true)
		var resultats: CanvasLayer = main.resultats
		_check(manche.finie and paused and resultats != null and resultats.visible and not hud.visible and not menu.visible,
			"la fin de manche chez l'hôte : la manche la diffuse, tout se fige, l'écran Résultats remplace le HUD")
		_check(manche.envois_ordre == ([&"_recevoir_tampons", &"_recevoir_territoire", &"_recevoir_fin_manche"] as Array[StringName]),
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
			"le bilan envoyé se relit à l'identique chez un client")
		# Un hôte perdu (chez un client) : message, tout se fige
		main._sur_hote_perdu()
		var message: Label = main.get_node("HotePerdu/Message")
		_check(message.text == "RESEAU_HOTE_PERDU" and paused and not hud.fin.visible,
			"l'hôte perdu : « L'hôte a quitté la partie » (à la place du panneau de fin), la partie se fige")
		paused = false
```

par :

```gdscript
			"le bilan envoyé se relit à l'identique chez un client")
		_check(resultats != null and resultats.hote and resultats.en_reseau and resultats.bouton_salon.visible and resultats.partis == [false, true]
			and resultats.bouton_revanche.disabled and resultats.bouton_suivant.disabled and not resultats.bouton_salon.disabled
			and resultats.etat.text == tr("SALON_ATTENTE_JOUEURS"),
			"l'écran Résultats de l'hôte en réseau : Retour au salon ; Bob parti, Revanche et Niveau suivant attendent deux joueurs")
		# Un hôte perdu (chez un client) : message, tout se fige
		main._sur_hote_perdu()
		var message: Label = main.get_node("HotePerdu/Message")
		_check(message.text == "RESEAU_HOTE_PERDU" and paused and not resultats.visible,
			"l'hôte perdu : « L'hôte a quitté la partie » (à la place de l'écran Résultats), la partie se fige")
		paused = false
```

Dans `tests/reseau/joueur.gd` (le scénario 13 : l'écran Résultats à la place du panneau de fin ; l'hôte en sort par Échap, `ui_cancel`) :

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	var tics_attendus := mini(ReglesBataille.SECONDES_TIC, ceili(duree) - 1)
	_check(paused and hud.fin.visible and hud.chrono.text == "0:00" and hud.tics_joues == tics_attendus,
		"tout se fige sur le panneau de fin, le chrono à 0:00, %d tics sur %d attendus" % [hud.tics_joues, tics_attendus])
	print("FIN %s bilan=%s lions=%s" % [hud.resume(), manche.bilan.resume() if manche.bilan != null else "", _lions_affiches(main)])
```

par :

```gdscript
	var tics_attendus := mini(ReglesBataille.SECONDES_TIC, ceili(duree) - 1)
	_check(await _attendre(func() -> bool: return main.resultats != null) and paused and main.resultats.visible and not hud.visible
		and hud.chrono.text == "0:00" and hud.tics_joues == tics_attendus,
		"tout se fige, l'écran Résultats à la place du HUD (le chrono à 0:00, %d tics sur %d attendus)" % [hud.tics_joues, tics_attendus])
	print("FIN %s bilan=%s lions=%s" % [hud.resume(), manche.bilan.resume() if manche.bilan != null else "", _lions_affiches(main)])
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
		var echap := InputEventAction.new()
		echap.action = &"pause"
		echap.pressed = true
		root.push_input(echap)
		_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not paused and not reseau.en_ligne(),
			"Échap, la manche finie : l'hôte revient au titre, hors réseau")
	else:
		_check(await _attendre(func() -> bool: return _issue == "hote_perdu"), "l'hôte finit par partir")
		_check(main.get_node_or_null("HotePerdu/Message") != null and not hud.fin.visible,
			"« L'hôte a quitté la partie » à la place du panneau de fin")
		_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not paused and not reseau.en_ligne(),
```

par :

```gdscript
		var echap := InputEventAction.new()
		echap.action = &"ui_cancel"
		echap.pressed = true
		root.push_input(echap)
		_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not paused and not reseau.en_ligne(),
			"Échap, sur l'écran Résultats : l'hôte revient au titre, hors réseau")
	else:
		_check(await _attendre(func() -> bool: return _issue == "hote_perdu"), "l'hôte finit par partir")
		_check(main.get_node_or_null("HotePerdu/Message") != null and not main.resultats.visible,
			"« L'hôte a quitté la partie » à la place de l'écran Résultats")
		_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not paused and not reseau.en_ligne(),
```

- [ ] **Step 2 : les voir échouer**

Run : bataille (`T=tests/bataille_test.gd; O="--fixed-fps 60"`).
Expected : `SCRIPT ERROR: Invalid access to property or key 'resultats' on a base object of type 'Node2D (Main.gd)'.`, dans « -- HUD de la bataille » puis dans « -- Écran Résultats (phase 18) ».

- [ ] **Step 3 : l'écran Résultats**

Créer `Scenes/Resultats.tscn` :

```ini
[gd_scene load_steps=2 format=3 uid="uid://dlelionresult0"]

[ext_resource type="Script" path="res://Scripts/Resultats.gd" id="1_resultats"]

[node name="Resultats" type="CanvasLayer"]
process_mode = 3
layer = 8
script = ExtResource("1_resultats")

[node name="Fond" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
color = Color(0.05, 0.03, 0.1, 0.8)

[node name="Centre" type="CenterContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="Colonne" type="VBoxContainer" parent="Centre"]
layout_mode = 2
theme_override_constants/separation = 18
alignment = 1

[node name="Titre" type="Label" parent="Centre/Colonne"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.85, 0.2, 1)
theme_override_colors/font_outline_color = Color(0.1, 0.05, 0.15, 1)
theme_override_constants/outline_size = 14
theme_override_font_sizes/font_size = 96
text = "BATAILLE_FIN"
horizontal_alignment = 1

[node name="Gagnant" type="Label" parent="Centre/Colonne"]
layout_mode = 2
auto_translate_mode = 2
theme_override_colors/font_outline_color = Color(0.1, 0.05, 0.15, 1)
theme_override_constants/outline_size = 10
theme_override_font_sizes/font_size = 48
horizontal_alignment = 1

[node name="Tableau" type="VBoxContainer" parent="Centre/Colonne"]
layout_mode = 2
size_flags_horizontal = 4
theme_override_constants/separation = 8

[node name="Titres" type="HBoxContainer" parent="Centre/Colonne"]
layout_mode = 2
theme_override_constants/separation = 24
alignment = 1

[node name="Boutons" type="HBoxContainer" parent="Centre/Colonne"]
layout_mode = 2
theme_override_constants/separation = 20
alignment = 1

[node name="Revanche" type="Button" parent="Centre/Colonne/Boutons"]
custom_minimum_size = Vector2(300, 68)
layout_mode = 2
focus_mode = 0
theme_override_font_sizes/font_size = 30
text = "RESULTATS_REVANCHE"

[node name="Suivant" type="Button" parent="Centre/Colonne/Boutons"]
custom_minimum_size = Vector2(420, 68)
layout_mode = 2
focus_mode = 0
theme_override_font_sizes/font_size = 30
auto_translate_mode = 2

[node name="Salon" type="Button" parent="Centre/Colonne/Boutons"]
custom_minimum_size = Vector2(320, 68)
layout_mode = 2
focus_mode = 0
theme_override_font_sizes/font_size = 30
text = "RESULTATS_SALON"

[node name="Quitter" type="Button" parent="Centre/Colonne/Boutons"]
custom_minimum_size = Vector2(240, 68)
layout_mode = 2
focus_mode = 0
theme_override_font_sizes/font_size = 30
text = "RESULTATS_QUITTER"

[node name="Etat" type="Label" parent="Centre/Colonne"]
layout_mode = 2
auto_translate_mode = 2
theme_override_colors/font_color = Color(1, 0.85, 0.2, 1)
theme_override_colors/font_outline_color = Color(0.1, 0.05, 0.15, 1)
theme_override_constants/outline_size = 6
theme_override_font_sizes/font_size = 28
horizontal_alignment = 1

[node name="Aide" type="Label" parent="Centre/Colonne"]
layout_mode = 2
auto_translate_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.7)
theme_override_font_sizes/font_size = 24
horizontal_alignment = 1

[connection signal="pressed" from="Centre/Colonne/Boutons/Revanche" to="." method="choisir" binds= [&"revanche"]]
[connection signal="pressed" from="Centre/Colonne/Boutons/Suivant" to="." method="choisir" binds= [&"suivant"]]
[connection signal="pressed" from="Centre/Colonne/Boutons/Salon" to="." method="choisir" binds= [&"salon"]]
[connection signal="pressed" from="Centre/Colonne/Boutons/Quitter" to="." method="choisir" binds= [&"quitter"]]
```

Créer `Scripts/Resultats.gd` :

```gdscript
extends CanvasLayer
## L'écran Résultats d'une bataille (phase 18, spec §8), posé par la scène de jeu sur la ville figée, à
## la place du HUD de la bataille, sur chaque poste : le même, tiré du seul bilan de l'hôte
## (`BilanManche`) et de la table des joueurs. En haut, « FIN DE LA MANCHE ! » et le gagnant (ou les ex
## æquo) ; puis le classement, une ligne par joueur (le plus de cellules d'abord) : son rang, son lion
## teint (couronné pour chaque meneur), son pseudo, une barre à sa couleur de sa part des cellules
## peintes (le podium en barres, animé comme le bilan du solo, `GameOver`), ses statistiques
## (étourdissements infligés, cellules volées, chocs), « TOI » ou « PARTI » ; puis les trois titres (« Le plus
## vicieux », « Le voleur », « L'auto-tamponneur ») et les choix. L'hôte choisit pour tous : Revanche
## (le même niveau), Niveau suivant, Retour au salon (en réseau seulement) ; Revanche et Niveau suivant
## demandent au moins deux joueurs encore là. Un client voit « En attente de l'hôte… ». Chacun peut
## quitter (Quitter, Échap : le titre, qui quitte le réseau). Le choix part en signal (`choix_fait`) :
## c'est la scène de jeu qui le suit.
## Commandes : aucun bouton ne prend le focus (la souris les clique) ; gauche et droite choisissent
## parmi les choix de l'hôte, vomir (ou Tab, Start) valide, Échap (ou B) quitte ; une action n'agit qu'à
## l'appui, jamais tenue depuis la manche (Espace tenu au gong ne choisit rien) ; un appui pendant
## l'animation la termine ; un choix au clavier n'est pris que DELAI_CHOIX après la fin de l'animation
## (un joueur qui martèle Espace au gong ne relance pas la manche sans le vouloir). Tourne l'arbre en
## pause (la manche finie le fige).

signal choix_fait(choix: StringName)

const TEXTURE_LION := preload("res://Assets/Sprites/LionHead.png")
const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
const _HUD := preload("res://Scripts/HUDBataille.gd")
const COULEUR_CONTOUR := Color(0.1, 0.05, 0.15, 1)
const COULEUR_NOM := Color(1, 1, 1, 0.7)
const OPACITE_PARTI := 0.45
## Largeur de la barre d'une part de 100 %, et sa hauteur ; largeur de la colonne des pseudos (12
## caractères larges, « WWWWWWWWWWWW », y tiennent : vérifié par tests/bataille_test.gd).
const TAILLE_BARRE := Vector2(480, 34)
const LARGEUR_PSEUDO := 360
## Le rythme du bilan du solo (`GameOver`) : une ligne toutes les DELAI_LIGNE s, sa barre et son
## compteur en DUREE_COMPTEUR s ; puis un titre toutes les DELAI_TITRE s. À 6 joueurs, moins de 3 s en
## tout.
const DELAI_LIGNE := 0.3
const DUREE_COMPTEUR := 0.45
const DELAI_TITRE := 0.2
## Après l'animation, délai avant qu'un choix au clavier soit pris (secondes).
const DELAI_CHOIX := 1.0
## Les choix de l'hôte, dans l'ordre des boutons, puis Quitter (de chacun).
const CHOIX: Array[StringName] = [&"revanche", &"suivant", &"salon", &"quitter"]
const ACTIONS: Array[StringName] = [&"deplacer_gauche", &"deplacer_droite", &"vomir", &"demarrer", &"ui_accept", &"ui_cancel"]

## Le bilan affiché (`afficher`).
var bilan: BilanManche
## Vrai sur le poste qui choisit pour tous (l'hôte ; en bataille locale, ce poste).
var hote := true
## Le choix fait (`choisir`), vide avant : un seul part, jusqu'à `annuler_choix`.
var choix := &""
## Vrai en réseau : Retour au salon existe.
var en_reseau := false
## Par index de joueur : vrai une fois parti (dans le bilan, ou annoncé depuis : `marquer_parti`).
var partis: Array[bool] = []
## Une ligne par joueur, dans l'ordre du classement : {"index": int, "ligne": HBoxContainer, "rang": Label,
## "lion": TextureRect, "couronne": Control, "pseudo": Label, "barre": Panel, "part": Label,
## "stats": Array[Label] (étourdissements infligés, cellules volées, chocs : l'ordre des titres),
## "badge": Label, "cible": int (part en %)}.
var lignes: Array[Dictionary] = []
## Les trois titres, dans l'ordre de BilanManche.TITRES : {"cadre": PanelContainer, "nom": Label, "valeur": Label}.
var cartes_titres: Array[Dictionary] = []
## Le choix sélectionné au clavier (un de CHOIX).
var selection: StringName = &"revanche"
var animation_finie := false

@onready var titre: Label = $Centre/Colonne/Titre
@onready var gagnant: Label = $Centre/Colonne/Gagnant
@onready var tableau: VBoxContainer = $Centre/Colonne/Tableau
@onready var rangee_titres: HBoxContainer = $Centre/Colonne/Titres
@onready var boutons: HBoxContainer = $Centre/Colonne/Boutons
@onready var etat: Label = $Centre/Colonne/Etat
@onready var aide: Label = $Centre/Colonne/Aide
@onready var bouton_revanche: Button = $Centre/Colonne/Boutons/Revanche
@onready var bouton_suivant: Button = $Centre/Colonne/Boutons/Suivant
@onready var bouton_salon: Button = $Centre/Colonne/Boutons/Salon
@onready var bouton_quitter: Button = $Centre/Colonne/Boutons/Quitter

var _tween: Tween
## Temps écoulé depuis la fin de l'animation (secondes) : DELAI_CHOIX avant un choix au clavier.
var _depuis_animation := 0.0
## Actions tenues : une action n'agit qu'à l'appui (voir `_unhandled_input`), jamais tenue depuis la
## manche : l'état de chaque action est relevé à l'ouverture.
var _tenues: Dictionary[StringName, bool] = {}
var _style_selection := StyleBoxFlat.new()


func _ready() -> void:
	for action in ACTIONS:
		_tenues[action] = Input.is_action_pressed(action)
	_style_selection.bg_color = Color(0.32, 0.2, 0.28, 1.0)
	_style_selection.border_color = Styles.JAUNE
	_style_selection.set_border_width_all(4)
	_style_selection.set_corner_radius_all(6)
	_style_selection.set_content_margin_all(8)


## Montre le bilan `bilan_` : `hote_` vrai sur le poste qui choisit pour tous, `en_reseau_` vrai en
## réseau (Retour au salon).
func afficher(bilan_: BilanManche, hote_: bool, en_reseau_: bool) -> void:
	bilan = bilan_
	hote = hote_
	en_reseau = en_reseau_
	partis.assign(bilan.partis)
	var meneurs := PackedStringArray()
	for i in bilan.meneurs():
		meneurs.append(_nom(i))
	gagnant.text = texte_gagnant(meneurs)
	_creer_entete()
	var rangs := bilan.rangs()
	var parts := bilan.parts()
	for i in bilan.classement():
		lignes.append(_creer_ligne(i, rangs[i], parts[i]))
	for t in BilanManche.TITRES:
		cartes_titres.append(_creer_titre(t))
	bouton_salon.visible = hote and en_reseau
	bouton_revanche.visible = hote
	bouton_suivant.visible = hote
	var suivant: Dictionary = GameState.NIVEAUX[posmod(GameState.niveau_courant + 1, GameState.NIVEAUX.size())]
	bouton_suivant.text = tr("RESULTATS_SUIVANT") % tr(suivant.nom)
	aide.text = tr("RESULTATS_AIDE_HOTE" if hote else "RESULTATS_AIDE")
	selection = &"revanche" if hote else &"quitter"
	rafraichir()
	_animer()


func _process(delta: float) -> void:
	if animation_finie:
		_depuis_animation += delta


func _unhandled_input(event: InputEvent) -> void:
	for action in ACTIONS:
		if not event.is_action(action):
			continue
		var appuyee := event.is_action_pressed(action)
		var nouvel_appui: bool = appuyee and not _tenues.get(action, false)
		_tenues[action] = appuyee
		if nouvel_appui:
			get_viewport().set_input_as_handled()
			_agir(action)
		return


## Un appui sur `action` (jamais tenue depuis l'ouverture).
func _agir(action: StringName) -> void:
	if action == &"ui_cancel":
		choisir(&"quitter")
		return
	if not animation_finie:
		terminer_animation()
		return
	if not hote or _depuis_animation < DELAI_CHOIX:
		return
	match action:
		&"deplacer_gauche":
			_deplacer_selection(-1)
		&"deplacer_droite":
			_deplacer_selection(1)
		_:
			choisir(selection)


## Le choix `voulu` (un de CHOIX), au bouton ou au clavier : Quitter pour chacun ; les autres pour
## l'hôte seulement, s'ils sont possibles (`possible`). Part en `choix_fait`, une seule fois : les
## boutons se grisent jusqu'à `annuler_choix`.
func choisir(voulu: StringName) -> void:
	if bilan == null or not choix.is_empty() or not possible(voulu):
		return
	choix = voulu
	rafraichir()
	choix_fait.emit(voulu)


## Le choix fait n'a pas pu se suivre (l'hôte n'a plus assez de joueurs au moment même, par exemple) :
## on peut de nouveau choisir.
func annuler_choix() -> void:
	choix = &""
	rafraichir()


## Le joueur d'index `index` est parti (annoncé par l'hôte après le gong) : sa ligne se grise ; Revanche
## et Niveau suivant attendent deux joueurs encore là.
func marquer_parti(index: int) -> void:
	if index < 0 or index >= partis.size() or partis[index]:
		return
	partis[index] = true
	rafraichir()


## Les boutons et les lignes à jour : départs, choix possibles, sélection.
func rafraichir() -> void:
	for l in lignes:
		var i: int = l.index
		var badges := PackedStringArray()
		if GameState.joueurs[i] == GameState.joueur_local():
			badges.append(tr("SALON_TOI"))
		if partis[i]:
			badges.append(tr("BATAILLE_PARTI"))
		(l.badge as Label).text = " · ".join(badges)
		if animation_finie:  # sinon, l'animation fait apparaître la ligne (et la grise à sa fin)
			(l.ligne as Control).modulate.a = OPACITE_PARTI if partis[i] else 1.0
	for i in range(CHOIX.size()):
		var b: Button = _boutons()[i]
		b.disabled = not choix.is_empty() or not possible(CHOIX[i])
		var choisi := CHOIX[i] == selection and hote
		for nom in ["normal", "hover"]:
			if choisi:
				b.add_theme_stylebox_override(nom, _style_selection)
			else:
				b.remove_theme_stylebox_override(nom)
	if hote:
		etat.text = "" if possible(&"revanche") else tr("SALON_ATTENTE_JOUEURS")
	else:
		etat.text = tr("RESULTATS_ATTENTE_HOTE")


## Vrai si le choix `voulu` peut se faire sur ce poste : Quitter toujours ; Revanche et Niveau suivant
## pour l'hôte, avec au moins deux joueurs encore là ; Retour au salon pour l'hôte, en réseau.
func possible(voulu: StringName) -> bool:
	match voulu:
		&"quitter":
			return true
		&"revanche", &"suivant":
			return hote and partis.count(false) >= EtatPartie.NB_JOUEURS_MIN
		&"salon":
			return hote and en_reseau
	return false


## Le classement tel qu'il s'affiche, en une ligne (tests : le même sur chaque poste, sans le « TOI » de
## chacun) : pour chaque ligne, rang, pseudo, part, statistiques et départ ; puis les lauréats de chaque
## titre.
func resume() -> String:
	var morceaux := PackedStringArray()
	for l in lignes:
		var stats: Array = (l.stats as Array).map(func(e: Label) -> String: return e.text)
		morceaux.append("%s:%s:%d %%:%s%s" % [(l.rang as Label).text, (l.pseudo as Label).text, l.cible, ",".join(stats), ":parti" if partis[l.index] else ""])
	for c in cartes_titres:
		morceaux.append("%s=%s" % [(c.titre as Label).text, (c.nom as Label).text])
	return "|".join(morceaux)


## La ligne du gagnant pour les meneurs `meneurs` (leurs noms) : le gagnant, les ex æquo, ou personne
## (aucune cellule peinte).
func texte_gagnant(meneurs: PackedStringArray) -> String:
	if meneurs.is_empty():
		return tr("BATAILLE_PERSONNE")
	if meneurs.size() == 1:
		return tr("BATAILLE_GAGNANT") % meneurs[0]
	return tr("BATAILLE_EGALITE") % ", ".join(meneurs)


## Affiche tout d'un coup (fin de l'animation, ou un appui qui la coupe).
func terminer_animation() -> void:
	if animation_finie:
		return
	animation_finie = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	for l in lignes:
		(l.ligne as Control).modulate.a = OPACITE_PARTI if partis[l.index] else 1.0
		_ecrire_part(l, float(l.cible))
	for c in cartes_titres:
		(c.cadre as Control).modulate.a = 1.0
	boutons.modulate.a = 1.0


func _animer() -> void:
	for l in lignes:
		(l.ligne as Control).modulate.a = 0.0
		_ecrire_part(l, 0.0)
	for c in cartes_titres:
		(c.cadre as Control).modulate.a = 0.0
	boutons.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	var debut := 0.0
	for l in lignes:
		_tween.tween_property(l.ligne, "modulate:a", OPACITE_PARTI if partis[l.index] else 1.0, 0.15).set_delay(debut)
		_tween.tween_method(func(v: float) -> void: _ecrire_part(l, v), 0.0, float(l.cible), DUREE_COMPTEUR).set_delay(debut)
		debut += DELAI_LIGNE
	debut += DUREE_COMPTEUR - DELAI_LIGNE
	for c in cartes_titres:
		_tween.tween_property(c.cadre, "modulate:a", 1.0, 0.2).set_delay(debut)
		debut += DELAI_TITRE
	_tween.tween_property(boutons, "modulate:a", 1.0, 0.25).set_delay(debut)
	_tween.tween_callback(terminer_animation).set_delay(debut + 0.25)


## La barre et le compteur de la ligne `l` à `part` % (animés de 0 à sa part).
func _ecrire_part(l: Dictionary, part: float) -> void:
	(l.barre as Control).custom_minimum_size.x = maxf(TAILLE_BARRE.x * part / 100.0, 0.0)
	(l.part as Label).text = "%d %%" % int(round(part))


func _deplacer_selection(sens: int) -> void:
	var possibles: Array[StringName] = []
	for c in CHOIX:
		if possible(c) and (_boutons()[CHOIX.find(c)] as Button).visible:
			possibles.append(c)
	if possibles.is_empty():
		return
	var k := possibles.find(selection)
	selection = possibles[posmod(k + sens, possibles.size())] if k >= 0 else possibles[0]
	rafraichir()


func _boutons() -> Array[Button]:
	return [bouton_revanche, bouton_suivant, bouton_salon, bouton_quitter]


func _nom(index: int) -> String:
	return _HUD.nom_affiche(GameState.joueurs[index])


func _creer_entete() -> void:
	var entete := HBoxContainer.new()
	entete.add_theme_constant_override("separation", 16)
	for cle_largeur: Array in [["", 60], ["", 64], ["", LARGEUR_PSEUDO], ["RESULTATS_PART", TAILLE_BARRE.x + 16 + 110],
			["RESULTATS_ETOURDIS", 200], ["RESULTATS_VOLEES", 200], ["RESULTATS_CHOCS", 200], ["", 110]]:
		var e := _etiquette(22, COULEUR_NOM)
		e.text = tr(cle_largeur[0]) if not (cle_largeur[0] as String).is_empty() else ""
		e.custom_minimum_size.x = cle_largeur[1]
		entete.add_child(e)
	tableau.add_child(entete)


func _creer_ligne(index: int, rang: int, part: int) -> Dictionary:
	var joueur: Joueur = GameState.joueurs[index]
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 16)
	var etiquette_rang := _etiquette(34, Styles.JAUNE if rang == 1 else Color.WHITE)
	etiquette_rang.text = tr("BATAILLE_RANG_%d" % rang) if rang > 0 else "–"
	etiquette_rang.custom_minimum_size.x = 60
	var lion := TextureRect.new()
	lion.texture = TEXTURE_LION
	lion.custom_minimum_size = Vector2(64, 64)
	lion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var teinte := ShaderMaterial.new()  # une par ligne : jamais partagée
	teinte.shader = SHADER_TEINTE
	teinte.set_shader_parameter("couleur_joueur", joueur.couleur)
	lion.material = teinte
	var couronne := _HUD.Couronne.new()
	couronne.position = _HUD.PLACE_COURONNE * (64.0 / 56.0)
	couronne.size = _HUD.TAILLE_COURONNE * (64.0 / 56.0)
	couronne.pivot_offset = couronne.size / 2.0
	couronne.rotation = _HUD.INCLINAISON_COURONNE
	couronne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couronne.visible = rang == 1
	lion.add_child(couronne)
	var pseudo := _etiquette(30, joueur.couleur, true)
	pseudo.text = _nom(index)
	pseudo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pseudo.custom_minimum_size.x = LARGEUR_PSEUDO
	var fond_barre := Panel.new()
	fond_barre.custom_minimum_size = TAILLE_BARRE
	fond_barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fond_barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style_fond := StyleBoxFlat.new()
	style_fond.bg_color = Color(1, 1, 1, 0.08)
	style_fond.set_corner_radius_all(8)
	fond_barre.add_theme_stylebox_override("panel", style_fond)
	var barre := Panel.new()
	barre.custom_minimum_size = Vector2(0, TAILLE_BARRE.y)
	barre.size = Vector2(0, TAILLE_BARRE.y)
	barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style_barre := StyleBoxFlat.new()
	style_barre.bg_color = joueur.couleur
	style_barre.set_corner_radius_all(8)
	barre.add_theme_stylebox_override("panel", style_barre)
	var boite_barre := HBoxContainer.new()  # la barre part de la gauche du fond
	boite_barre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boite_barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boite_barre.add_child(barre)
	fond_barre.add_child(boite_barre)
	var etiquette_part := _etiquette(32, Color.WHITE)
	etiquette_part.custom_minimum_size.x = 110
	etiquette_part.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var stats: Array[Label] = []
	for valeur in [bilan.etourdissements[index], bilan.volees[index], bilan.chocs[index]]:  # l'ordre des titres
		var e := _etiquette(30, Color.WHITE)
		e.text = str(valeur)
		e.custom_minimum_size.x = 200
		stats.append(e)
	var badge := _etiquette(22, Styles.JAUNE)
	badge.custom_minimum_size.x = 110
	for noeud: Control in [etiquette_rang, lion, pseudo, fond_barre, etiquette_part]:
		ligne.add_child(noeud)
	for e in stats:
		ligne.add_child(e)
	ligne.add_child(badge)
	tableau.add_child(ligne)
	return {"index": index, "ligne": ligne, "rang": etiquette_rang, "lion": lion, "couronne": couronne, "pseudo": pseudo,
		"barre": barre, "part": etiquette_part, "stats": stats, "badge": badge, "cible": part}


func _creer_titre(t: StringName) -> Dictionary:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)
	style.border_color = Styles.JAUNE
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	var cadre := PanelContainer.new()
	cadre.custom_minimum_size = Vector2(520, 0)
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_theme_stylebox_override("panel", style)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 2)
	cadre.add_child(colonne)
	var etiquette_titre := _etiquette(26, Styles.JAUNE)
	etiquette_titre.text = tr("RESULTATS_" + String(t).to_upper())
	var laureats := bilan.laureats(t)
	# Les lauréats un par ligne (ex æquo compris), chacun dans sa couleur s'il est seul
	var nom := _etiquette(30, GameState.joueurs[laureats[0]].couleur if laureats.size() == 1 else Color.WHITE)
	var noms := PackedStringArray()
	for i in laureats:
		noms.append(_nom(i))
	nom.text = "\n".join(noms) if not noms.is_empty() else tr("RESULTATS_PERSONNE")
	var valeur := _etiquette(22, COULEUR_NOM)
	valeur.text = (tr("RESULTATS_" + String(t).to_upper() + "_VALEUR") % bilan.record(t)) if not laureats.is_empty() else " "
	for noeud: Control in [etiquette_titre, nom, valeur]:
		colonne.add_child(noeud)
	rangee_titres.add_child(cadre)
	return {"cadre": cadre, "titre": etiquette_titre, "nom": nom, "valeur": valeur}


## Une étiquette jamais traduite d'elle-même (les textes sont traduits ici, et un pseudo comme « PAUSE »
## n'est pas une clé), au contour sombre ; `coupee` : coupée au bord plutôt que de s'élargir (un pseudo).
func _etiquette(taille: int, couleur: Color, coupee := false) -> Label:
	var etiquette := Label.new()
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiquette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	etiquette.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	etiquette.clip_text = coupee
	if coupee:
		etiquette.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	etiquette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiquette.add_theme_font_size_override("font_size", taille)
	etiquette.add_theme_color_override("font_color", couleur)
	etiquette.add_theme_color_override("font_outline_color", COULEUR_CONTOUR)
	etiquette.add_theme_constant_override("outline_size", 6)
	return etiquette
```

- [ ] **Step 4 : le HUD sans panneau de fin**

Dans `Scripts/HUDBataille.gd`, remplacer :

```gdscript
## durée reçue au début de la gerbe). À la fin de la manche (`GameState.partie_terminee`, chez un
## client la fin décidée par l'hôte), le panneau de fin : le gagnant, ou les ex æquo, et la sortie
## (Échap, Start ou le bouton : retour au titre, qui quitte le réseau) jusqu'à l'écran Résultats de la
## phase 18. Tourne aussi l'arbre en pause (le panneau de fin et sa sortie) ; le reste ne bouge pas
## pendant une pause.

const SCENE_TITRE := "res://Scenes/Titre.tscn"
const TEXTURE_LION := preload("res://Assets/Sprites/LionHead.png")
```

par :

```gdscript
## durée reçue au début de la gerbe). À la fin de la manche (`GameState.partie_terminee`, chez un
## client la fin décidée par l'hôte), il se rafraîchit une dernière fois ; l'écran Résultats (phase 18,
## `Resultats`) prend alors sa place. Ne bouge pas pendant une pause.

const TEXTURE_LION := preload("res://Assets/Sprites/LionHead.png")
```

Dans `Scripts/HUDBataille.gd`, remplacer :

```gdscript
@onready var chrono: Label = $Haut/Chrono
@onready var fin: CenterContainer = $Fin
@onready var gagnant: Label = $Fin/Panneau/Colonne/Gagnant

var _secondes_vues := -1
```

par :

```gdscript
@onready var chrono: Label = $Haut/Chrono

var _secondes_vues := -1
```

Dans `Scripts/HUDBataille.gd`, remplacer :

```gdscript
	_style_point.set_corner_radius_all(6)
	var fond_fin := StyleBoxFlat.new()
	fond_fin.bg_color = Color(0.05, 0.03, 0.1, 0.82)
	fond_fin.set_corner_radius_all(24)
	fond_fin.set_content_margin_all(48)
	$Fin/Panneau.add_theme_stylebox_override("panel", fond_fin)
	var nb := GameState.joueurs.size()
```

par :

```gdscript
	_style_point.set_corner_radius_all(6)
	var nb := GameState.joueurs.size()
```

Dans `Scripts/HUDBataille.gd`, remplacer :

```gdscript
func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if GameState.partie_en_cours and GameState.pret:
```

par :

```gdscript
func _process(delta: float) -> void:
	if GameState.partie_en_cours and GameState.pret:
```

Dans `Scripts/HUDBataille.gd`, remplacer :

```gdscript
	rafraichir()


## Échap (ou Start) une fois la manche finie : la sortie (le menu local est désactivé à la fin).
func _unhandled_input(event: InputEvent) -> void:
	if fin.visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		quitter()


## Retour au titre, qui quitte le réseau (en attendant l'écran Résultats de la phase 18). Ne dépause
## pas ici (N1, revue finale phase 17) : `Titre._ready` le fait déjà, une fois la scène changée ; sinon
## l'arbre repart pour le pas physique de cette image avant même la libération de la scène (sans effet
## aujourd'hui, mais la phase 18 changera de scène par RPC : Revanche, Salon).
func quitter() -> void:
	get_tree().change_scene_to_file(SCENE_TITRE)


## Le joueur d'index `index` a quitté la manche : sa vignette reste, en grisé, avec ses cellules.
```

par :

```gdscript
	rafraichir()


## Le joueur d'index `index` a quitté la manche : sa vignette reste, en grisé, avec ses cellules.
```

Dans `Scripts/HUDBataille.gd`, remplacer :

```gdscript
## Fin de la manche : les scores définitifs (le dernier territoire de l'hôte est déjà appliqué chez un
## client : il arrive avant la fin, sur le même canal), puis le panneau de fin.
func _sur_fin(_victoire: bool) -> void:
	rafraichir()
	var rangs := ReglesBataille.rangs(_cellules())
	var meneurs := PackedStringArray()
	for i in range(rangs.size()):
		if rangs[i] == 1:
			meneurs.append(nom_affiche(GameState.joueurs[i]))
	gagnant.text = texte_gagnant(meneurs)
	fin.show()


## La ligne du panneau de fin pour les meneurs `meneurs` (leurs noms) : le gagnant, les ex æquo, ou
## personne (aucune cellule peinte).
func texte_gagnant(meneurs: PackedStringArray) -> String:
	if meneurs.is_empty():
		return tr("BATAILLE_PERSONNE")
	if meneurs.size() == 1:
		return tr("BATAILLE_GAGNANT") % meneurs[0]
	return tr("BATAILLE_EGALITE") % ", ".join(meneurs)


func _creer_vignette(joueur: Joueur) -> Dictionary:
```

par :

```gdscript
## Fin de la manche : les scores définitifs (le dernier territoire de l'hôte est déjà appliqué chez un
## client : il arrive avant la fin, sur le même canal) ; l'écran Résultats prend ensuite la place du HUD.
func _sur_fin(_victoire: bool) -> void:
	rafraichir()


func _creer_vignette(joueur: Joueur) -> Dictionary:
```

Dans `Scenes/HUDBataille.tscn`, remplacer :

```ini
[node name="HUDBataille" type="CanvasLayer"]
process_mode = 3
layer = 5
```

par :

```ini
[node name="HUDBataille" type="CanvasLayer"]
layer = 5
```

Dans `Scenes/HUDBataille.tscn`, remplacer :

```ini
theme_override_constants/separation = 10

[node name="Fin" type="CenterContainer" parent="."]
visible = false
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Panneau" type="PanelContainer" parent="Fin"]
layout_mode = 2

[node name="Colonne" type="VBoxContainer" parent="Fin/Panneau"]
layout_mode = 2
theme_override_constants/separation = 24
alignment = 1

[node name="Titre" type="Label" parent="Fin/Panneau/Colonne"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 0.85, 0.2, 1)
theme_override_colors/font_outline_color = Color(0.1, 0.05, 0.15, 1)
theme_override_constants/outline_size = 14
theme_override_font_sizes/font_size = 110
text = "BATAILLE_FIN"
horizontal_alignment = 1

[node name="Gagnant" type="Label" parent="Fin/Panneau/Colonne"]
layout_mode = 2
auto_translate_mode = 2
theme_override_colors/font_outline_color = Color(0.1, 0.05, 0.15, 1)
theme_override_constants/outline_size = 10
theme_override_font_sizes/font_size = 52
horizontal_alignment = 1

[node name="Quitter" type="Button" parent="Fin/Panneau/Colonne"]
custom_minimum_size = Vector2(420, 64)
layout_mode = 2
size_flags_horizontal = 4
focus_mode = 0
theme_override_font_sizes/font_size = 32
text = "QUITTER_PARTIE"

[node name="Aide" type="Label" parent="Fin/Panneau/Colonne"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 0.7)
theme_override_font_sizes/font_size = 26
text = "BATAILLE_AIDE_FIN"
horizontal_alignment = 1

[connection signal="pressed" from="Fin/Panneau/Colonne/Quitter" to="." method="quitter"]
```

par :

```ini
theme_override_constants/separation = 10
```

- [ ] **Step 5 : la scène de jeu montre l'écran Résultats et suit ses choix**

Dans `Scripts/Main.gd`, remplacer :

```gdscript
## Échap y ouvre un menu local qui ne met pas la partie en pause ; un hôte perdu ramène au titre
## après son message.

@export var game_over_scene: PackedScene
```

par :

```gdscript
## Échap y ouvre un menu local qui ne met pas la partie en pause ; un hôte perdu ramène au titre
## après son message. Une bataille finie (phase 18) montre l'écran Résultats (`Resultats`) sur le bilan
## de l'hôte, et suit le choix qu'on y fait.

@export var game_over_scene: PackedScene
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
const SCENE_HUD_BATAILLE := preload("res://Scenes/HUDBataille.tscn")
## Temps pendant lequel « L'hôte a quitté la partie » reste affiché avant le retour au titre.
```

par :

```gdscript
const SCENE_HUD_BATAILLE := preload("res://Scenes/HUDBataille.tscn")
const SCENE_RESULTATS := preload("res://Scenes/Resultats.tscn")
## Temps pendant lequel « L'hôte a quitté la partie » reste affiché avant le retour au titre.
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
var hud_bataille: CanvasLayer

var _tremblement_restant := 0.0
```

par :

```gdscript
var hud_bataille: CanvasLayer
## L'écran Résultats d'une bataille finie (phase 18) ; null avant la fin, et en solo.
var resultats: CanvasLayer

var _tremblement_restant := 0.0
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
func _enter_tree() -> void:
	for action in ACTIONS_DE_JEU:
```

par :

```gdscript
func _enter_tree() -> void:
	# Une manche relancée depuis l'écran Résultats (phase 18) arrive l'arbre encore en pause (la fin l'a
	# figé) : la scène de jeu part toujours dépausée, comme le titre (`Titre._ready`).
	get_tree().paused = false
	for action in ACTIONS_DE_JEU:
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
	manche.joueur_parti.connect(_sur_joueur_parti)
	manche.depart_vu.connect(hud_bataille.marquer_parti)
	menu_pause.visibility_changed.connect(_suspendre_commandes)
```

par :

```gdscript
	manche.joueur_parti.connect(_sur_joueur_parti)
	manche.depart_vu.connect(_sur_depart_vu)
	manche.bilan_recu.connect(_afficher_resultats)
	menu_pause.visibility_changed.connect(_suspendre_commandes)
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
			l.queue_free()


## Menu local ouvert pendant une manche en réseau : les commandes de ce poste valent le repos.
```

par :

```gdscript
			l.queue_free()


## Sur chaque poste : le joueur d'index `index` a quitté la manche (en pleine manche, ou sur l'écran
## Résultats) : le HUD et l'écran Résultats le grisent.
func _sur_depart_vu(index: int) -> void:
	hud_bataille.marquer_parti(index)
	if resultats != null:
		resultats.marquer_parti(index)


## Menu local ouvert pendant une manche en réseau : les commandes de ce poste valent le repos.
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
	menu_pause.process_mode = Node.PROCESS_MODE_DISABLED
	if hud_bataille != null:
		hud_bataille.fin.hide()  # une manche finie : le message remplace le panneau de fin et sa sortie
	var couche := CanvasLayer.new()
```

par :

```gdscript
	menu_pause.process_mode = Node.PROCESS_MODE_DISABLED
	if resultats != null:
		resultats.hide()  # une manche finie : le message remplace l'écran Résultats
	var couche := CanvasLayer.new()
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
	if GameState.regles.compte_le_territoire():
		# Bataille : tout se fige, scores compris ; le HUD de la bataille montre la fin et sa sortie
		# (Échap : retour au titre) jusqu'à l'écran Résultats de la phase 18. Le menu local se ferme et
		# se tait : Échap est à la sortie.
		menu_pause.hide()
		menu_pause.process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().paused = true
		return
```

par :

```gdscript
	if GameState.regles.compte_le_territoire():
		# Bataille : tout se fige, scores compris. Le menu local se ferme et se tait (Échap est à l'écran
		# Résultats). En réseau, l'écran Résultats attend le bilan de l'hôte (`Manche.bilan_recu`, juste
		# après : chez l'hôte, sa manche le relève ; chez un client, il est arrivé avec la fin) ; hors
		# réseau, ce poste le relève lui-même.
		menu_pause.hide()
		menu_pause.process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().paused = true
		if not en_reseau:
			_afficher_resultats(_bilan_local())
		return
```

À la fin de `Scripts/Main.gd`, ajouter :

```gdscript


## Bataille locale : le bilan de la manche, relevé sur ce poste (son territoire, ses joueurs) : ni départ
## ni lion à poser (aucun client).
func _bilan_local() -> BilanManche:
	var cellules: Array[int] = []
	for j in GameState.joueurs:
		cellules.append(ville.territoire.cellules_de(j.index))
	return BilanManche.relever(GameState.joueurs, cellules, [] as Array[int], {} as Dictionary[int, PackedByteArray], GameState.temps_ecoule)


## Une bataille finie : l'écran Résultats sur le bilan `bilan` (celui de l'hôte), à la place du HUD de la
## bataille, les pseudos des lions remis à leur place finale. Une fois.
func _afficher_resultats(bilan: BilanManche) -> void:
	if resultats != null:
		return
	if not lions.is_empty():
		_placer_pseudos()
	hud_bataille.hide()
	resultats = SCENE_RESULTATS.instantiate()
	resultats.choix_fait.connect(_sur_choix_resultats)
	add_child(resultats)
	resultats.afficher(bilan, multiplayer.is_server(), en_reseau)


## Le choix fait sur l'écran Résultats. Quitter : le titre (qui quitte le réseau ; l'hôte qui part ramène
## ses clients au titre, « L'hôte a quitté la partie »). Hors réseau, Revanche et Niveau suivant
## rechargent la scène de jeu, sur le même niveau ou le suivant (en boucle), avec les mêmes joueurs : un
## territoire, un Spawner, un chrono tout neufs.
func _sur_choix_resultats(choix: StringName) -> void:
	match choix:
		&"quitter":
			get_tree().change_scene_to_file(SCENE_TITRE)
		&"revanche", &"suivant":
			if not en_reseau:
				if choix == &"suivant":
					GameState.niveau_courant = posmod(GameState.niveau_courant + 1, GameState.NIVEAUX.size())
				get_tree().reload_current_scene()
```

- [ ] **Step 6 : les textes**

Dans `Assets/Traductions/traductions.csv`, remplacer :

```csv
BATAILLE_PERSONNE,Personne n'a peint la ville.,Nobody painted the town.
BATAILLE_AIDE_FIN,Échap : quitter la partie,Esc: leave the game
```

par :

```csv
BATAILLE_PERSONNE,Personne n'a peint la ville.,Nobody painted the town.
RESULTATS_PART,Part des cellules peintes,Share of painted cells
RESULTATS_VOLEES,Cellules volées,Cells stolen
RESULTATS_ETOURDIS,Étourdissements,Stuns dealt
RESULTATS_CHOCS,Chocs,Bumps
RESULTATS_VICIEUX,LE PLUS VICIEUX,THE MEANEST
RESULTATS_VOLEUR,LE VOLEUR,THE THIEF
RESULTATS_TAMPONNEUR,L'AUTO-TAMPONNEUR,THE BUMPER CAR
RESULTATS_VICIEUX_VALEUR,Étourdissements infligés : %d,Stuns dealt: %d
RESULTATS_VOLEUR_VALEUR,Cellules volées : %d,Cells stolen: %d
RESULTATS_TAMPONNEUR_VALEUR,Chocs : %d,Bumps: %d
RESULTATS_PERSONNE,Personne,Nobody
RESULTATS_REVANCHE,Revanche,Rematch
RESULTATS_SUIVANT,Niveau suivant : %s,Next level: %s
RESULTATS_SALON,Retour au salon,Back to lobby
RESULTATS_QUITTER,Quitter,Quit
RESULTATS_ATTENTE_HOTE,En attente de l'hôte…,Waiting for the host…
RESULTATS_AIDE_HOTE,"Gauche/Droite : choisir   ·   Espace : valider   ·   Échap : quitter","Left/Right: choose   ·   Space: confirm   ·   Esc: quit"
RESULTATS_AIDE,Échap : quitter,Esc: quit
```

Puis `godot --headless --import . > /dev/null 2>&1` (le `.uid` de l'écran et les deux `.translation`).

- [ ] **Step 7 : les voir passer**

Run : unitaires, smoke, bataille, banc, la trace, puis le test réseau.
Expected : `== 0 échec(s) ==` partout, dont à la bataille « -- Écran Résultats (phase 18) » (21 vérifications : classement `[1, 3, 0, 2]`, rangs et couronne, statistiques, titres, gagnant, 12 caractères larges dans la colonne des pseudos (mesuré 352 px sur 360) et le tableau dans l'écran (1912 px), les boutons de la bataille locale sans focus, Espace tenu depuis le gong sans effet, l'animation coupée par un appui, le délai d'1 s, puis Niveau suivant et Revanche : la scène rechargée sur le niveau 1, un territoire vierge, 1:30, statistiques et crans à zéro, le Spawner reparti) ; au smoke « l'écran Résultats de l'hôte en réseau : Retour au salon ; Bob parti, Revanche et Niveau suivant attendent deux joueurs » ; la trace inchangée ; le test réseau vert.

- [ ] **Step 8 : commit**

```bash
git add Scenes/Resultats.tscn Scripts/Resultats.gd Scripts/Resultats.gd.uid Scripts/HUDBataille.gd Scenes/HUDBataille.tscn Scripts/Main.gd Assets/Traductions/traductions.csv Assets/Traductions/traductions.en.translation Assets/Traductions/traductions.fr.translation tests/bataille_test.gd tests/smoke_test.gd tests/reseau/joueur.gd
git commit -m "Écran Résultats (spec §8) sur chaque poste, tiré du seul bilan de l'hôte : classement en barres animées (pseudo, couleur, part des cellules peintes, rang, couronne des meneurs), statistiques de chacun, les trois titres ex æquo compris ; l'hôte choisit, les clients attendent, chacun peut quitter ; commandes à l'appui seulement, sans focus, choix au clavier 1 s après l'animation ; il remplace le panneau de fin du HUD ; en bataille locale, Revanche et Niveau suivant rechargent la scène

<ligne fournie par l'environnement>"
```

---

### Task 5 : Revanche, Niveau suivant et Retour au salon en réseau ; des manches enchaînées qui ne se mélangent pas (`Reseau`, `Main`, `Salon`, `Manche`)

**Files:**
- Modify: `Scripts/Reseau.gd` (en-tête, `salon_rouvert`, `CANAL_ORDONNE`, `manche_en_cours`, `lancer_manche` et `_lancer`, `relancer_manche` ➕, `revenir_au_salon` ➕, `_recevoir_retour_salon` ➕, `_poser_salon` ➕ (tiré de `_recevoir_salon`), `_recevoir_manche` avec sa table et sur le canal ordonné), `Scripts/Main.gd` (`SCENE_SALON`, `_Salon`, branchements réseau, `_exit_tree` ➕, `_sur_manche_relancee` ➕, `_sur_salon_rouvert` ➕, `_sur_choix_resultats`), `Scripts/Salon.gd` (`_ready` qui dépause, `entrer_en_manche` ➕), `Scripts/Manche.gd` (`_joueur_recu` : rien avant la barrière)
- Test: `tests/unitaires.gd` (`_tester_salon`, `_tester_manches_enchainees` ➕), `tests/smoke_test.gd` (`_tester_resultats_reseau` ➕, `_attendre_nouvelle_scene` ➕, `_passer_la_barriere` ➕)

**Interfaces:**
- Consumes (Task 4) : `Resultats.choix_fait`, `choisir`, `annuler_choix`, `possible`, `partis`, `lignes`, `etat` ; `Main._sur_choix_resultats`.
- Produces (Tasks 6, 7) : `signal Reseau.salon_rouvert()` (sur chaque poste, quand l'hôte ramène tout le monde au salon) ; `const Reseau.CANAL_ORDONNE := 1` ; `func Reseau.relancer_manche(niveau: int) -> bool` (chez l'hôte, pendant une manche, au moins `NB_JOUEURS_MIN` joueurs arrivés : le niveau ramené dans la liste, puis comme `lancer_manche`, `manche_lancee` sur chaque poste) ; `func Reseau.revenir_au_salon() -> bool` (chez l'hôte, pendant une manche : silence de session, `ouvrir_salon(niveau_salon)`, `_recevoir_retour_salon` chez chaque client, `salon_rouvert`) ; RPC `_recevoir_manche(table: Variant, niveau: Variant)` et `_recevoir_retour_salon(table: Variant, niveau: Variant, nb_places: Variant)` sur le canal `CANAL_ORDONNE` (la table voyage avec eux ; `_recevoir_salon` reste sur le canal 0) ; `func Reseau._poser_salon(table: Variant, niveau: Variant, nb_places: Variant) -> bool` ; `static func Salon.entrer_en_manche(arbre: SceneTree, fiches: Array[Dictionary]) -> void` ; `Manche._joueur_recu` renvoie null avant la barrière.

Le déroulé, en réseau : l'hôte choisit Revanche (ou Niveau suivant) → `Reseau.relancer_manche` (table recompactée, diffusée sur le canal 0, puis le lancement avec elle sur le canal ordonné : après la fin et le bilan de la manche finie) → chaque poste, par `manche_lancee`, branche la table (`Salon.entrer_en_manche`) et recharge la scène de jeu → la barrière attend chaque joueur, comme au premier lancement. Retour au salon → `Reseau.revenir_au_salon` → chaque poste charge le salon, où l'arbre repart (la fin l'avait figé) ; celui de l'hôte rouvre le salon (`ouvrir_salon`, déjà fait avant l'envoi : ses clients reçoivent la table remise à zéro avant le retour). Une relance que l'hôte ne peut plus suivre au moment même (un départ dans la même image) est refusée : `Resultats.annuler_choix`.

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_bilan_manche()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_bilan_manche()
	_tester_manches_enchainees()
	print("== %d échec(s) ==" % _echecs)
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
		"pendant la manche : ni second lancement, ni couleur, ni Prêt")
	reseau.ouvrir_salon(1)
	_check(not reseau.manche_en_cours and reseau.inscrits.values().all(func(f: Dictionary) -> bool: return not f.pret) and reseau.niveau_salon == 1,
		"rouvrir le salon (retour de manche, phase 18) : arrivées acceptées, personne n'est prêt")
	reseau.manche_lancee.disconnect(sur_lancement)
```

par :

```gdscript
		"pendant la manche : ni second lancement, ni couleur, ni Prêt")
	# Phase 18 : depuis l'écran Résultats, l'hôte relance une manche avec les joueurs encore là (Revanche,
	# Niveau suivant), ou ramène tout le monde au salon
	reseau._sur_pair_deconnecte(5)  # Bob part pendant la manche : un trou à l'index 1
	reseau.scenes_chargees.assign([1, 9])
	var niveau_avant: int = reseau.niveau_salon
	_check(reseau.relancer_manche(niveau_avant + 1 + EtatPartie.NIVEAUX.size()) and reseau.manche_en_cours and lancees.size() == 2
		and reseau.niveau_salon == posmod(niveau_avant + 1, EtatPartie.NIVEAUX.size())
		and lancees[1].map(func(f: Dictionary) -> int: return f.id_reseau) == [1, 9] and reseau.inscrits[9].index == 1
		and reseau.table_salon.map(func(f: Dictionary) -> int: return f.index) == [0, 1] and reseau.scenes_chargees.is_empty()
		and reseau.silence == reseau.SILENCE_CHARGEMENT
		and reseau.examiner_demande({"jeu": reseau.JEU, "version": reseau.version, "pseudo": "Tard"}).raison == reseau.REFUS_MANCHE,
		"Niveau suivant : une manche neuve avec les joueurs encore là (index recompactés), le niveau suivant en boucle, toujours sans arrivée")
	var rouverts := [0]
	var sur_salon := func() -> void: rouverts[0] += 1
	reseau.salon_rouvert.connect(sur_salon)
	_check(reseau.revenir_au_salon() and not reseau.manche_en_cours and rouverts[0] == 1 and reseau.silence == reseau.SILENCE_SESSION
		and reseau.inscrits.values().all(func(f: Dictionary) -> bool: return not f.pret)
		and reseau.table_salon.map(func(f: Dictionary) -> int: return f.id) == [1, 9],
		"Retour au salon : plus de manche en cours (arrivées acceptées), personne n'est prêt, la même table sans les partis")
	_check(not reseau.revenir_au_salon() and not reseau.relancer_manche(0) and rouverts[0] == 1 and lancees.size() == 2,
		"hors d'une manche (au salon), ni retour au salon ni relance : c'est « Démarrer la partie »")
	reseau.manche_en_cours = true
	reseau._sur_pair_deconnecte(9)
	_check(not reseau.relancer_manche(0) and lancees.size() == 2 and reseau.manche_en_cours,
		"seul, l'hôte ne relance pas de manche (Revanche : au moins deux joueurs)")
	reseau.salon_rouvert.disconnect(sur_salon)
	reseau.ouvrir_salon(1)
	_check(not reseau.manche_en_cours and reseau.inscrits.values().all(func(f: Dictionary) -> bool: return not f.pret) and reseau.niveau_salon == 1,
		"rouvrir le salon (à l'ouverture de la scène du salon) : arrivées acceptées, personne n'est prêt")
	reseau.manche_lancee.disconnect(sur_lancement)
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
		"personne n'a peint : aucun meneur, 0 % partout ; personne n'a étourdi, volé ni percuté : aucun titre")


## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
```

par :

```gdscript
		"personne n'a peint : aucun meneur, 0 % partout ; personne n'a étourdi, volé ni percuté : aucun titre")


## Phase 18 : des manches enchaînées depuis l'écran Résultats ne se mélangent pas chez un client. Le
## lancement et le retour au salon partent sur le canal fiable ordonné de la manche (celui de ses
## tampons, de son territoire et de sa fin), avec leur table : une manche relancée n'arrive qu'après tout
## ce que la précédente y a envoyé. La table seule reste sur le canal 0, celui de la poignée de main. Et
## une réaction ou un départ de la manche précédente (canal 0) arrivé après le rechargement de la scène
## ne touche pas la manche neuve tant que sa barrière n'est pas passée.
func _tester_manches_enchainees() -> void:
	print("-- Manches enchaînées (phase 18)")
	var reseau: Node = root.get_node("Reseau")
	var rpc_reseau: Dictionary = reseau.get_script().get_rpc_config()
	var script_manche: Script = load("res://Scripts/Manche.gd")
	var rpc_manche: Dictionary = script_manche.get_rpc_config()
	var canal: int = rpc_manche[&"_recevoir_fin_manche"].get("channel", 0)
	_check(canal == reseau.CANAL_ORDONNE and canal != 0 and rpc_manche[&"_recevoir_tampons"].get("channel", 0) == canal
		and rpc_manche[&"_recevoir_territoire"].get("channel", 0) == canal
		and [&"_recevoir_manche", &"_recevoir_retour_salon"].all(func(m: StringName) -> bool: return rpc_reseau[m].get("channel", 0) == canal)
		and rpc_reseau[&"_recevoir_salon"].get("channel", 0) == 0,
		"le lancement et le retour au salon partent sur le canal des tampons, du territoire et de la fin (%d) ; la table seule, sur celui de la poignée de main (0)" % canal)
	# Ils portent leur table : un client la prend d'eux, même si la table du canal 0 ne les a pas précédés
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	var table := [{"id": 1, "index": 0, "couleur": palette[0], "pseudo": "Moi", "pret": true},
		{"id": 5, "index": 1, "couleur": palette[3], "pseudo": "Bob", "pret": true}]
	var lancements: Array = []
	var sur_lancement := func(f: Array[Dictionary]) -> void: lancements.append(f)
	var retours := [0]
	var sur_retour := func() -> void: retours[0] += 1
	reseau.manche_lancee.connect(sur_lancement)
	reseau.salon_rouvert.connect(sur_retour)
	reseau._recevoir_manche(table, 2)
	_check(lancements.size() == 1 and lancements[0].map(func(f: Dictionary) -> int: return f.id_reseau) == [1, 5] and reseau.niveau_salon == 2
		and reseau.table_salon.size() == 2 and reseau.manche_en_cours,
		"le lancement pose sa table et son niveau, puis lance la manche sur elle")
	reseau._recevoir_retour_salon(table, 1, 4)
	_check(retours[0] == 1 and not reseau.manche_en_cours and reseau.niveau_salon == 1 and reseau.places_salon == 4,
		"le retour au salon pose sa table, son niveau et ses places, puis ramène au salon")
	reseau.manche_lancee.disconnect(sur_lancement)
	reseau.salon_rouvert.disconnect(sur_retour)
	reseau.quitter()
	var gs: Node = root.get_node("GameState")
	gs.configurer_bataille(2)
	gs.nouvelle_partie()
	var manche: Node = script_manche.new()
	manche.actif = true
	manche._recevoir_crans(1, 4)
	manche._recevoir_depart(1)
	var departs := [0]
	manche.depart_vu.connect(func(_i: int) -> void: departs[0] += 1)
	manche._recevoir_depart(1)
	_check(gs.joueurs[1].crans == 1 and departs[0] == 0,
		"avant sa barrière, une manche neuve ignore les réactions et les départs d'une manche précédente arrivés en retard")
	manche.barriere = true
	manche._recevoir_crans(1, 4)
	manche._recevoir_depart(1)
	_check(gs.joueurs[1].crans == 4 and departs[0] == 1, "sa barrière passée, elle les applique")
	manche.free()
	gs.configurer_solo()
	gs.nouvelle_partie()
	gs.partie_en_cours = false


## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	await _tester_manche_reseau()

	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	await _tester_manche_reseau()
	await _tester_resultats_reseau()

	print("== %d échec(s) ==" % _echecs)
```

À la fin de `tests/smoke_test.gd`, ajouter :

```gdscript


## Attend la scène `chemin` qui remplace celle d'identifiant `avant` (la même scène rechargée compte),
## prête ; bornée comme `_attendre_scene`.
func _attendre_nouvelle_scene(chemin: String, avant: int, max_ms: int = 5000) -> Node:
	var fin := Time.get_ticks_msec() + max_ms
	while Time.get_ticks_msec() < fin and (current_scene == null or current_scene.get_instance_id() == avant
			or current_scene.scene_file_path != chemin or not current_scene.is_node_ready()):
		await process_frame
	return current_scene


## Une manche en réseau chez l'hôte (Bob simulé dans `Reseau.inscrits`, comme `_tester_manche_reseau`),
## jusqu'à la barrière passée : la scène de jeu `main` (déjà chargée).
func _passer_la_barriere(main: Node) -> void:
	await _frames(2)
	root.get_node("Reseau")._noter_scene_chargee(7)  # comme la RPC de Bob
	await _frames(2)
	GS.pret = true  # sans attendre l'intro


## Phase 18 : l'écran Résultats chez l'hôte en réseau, et ses choix (les échanges entre postes sont
## couverts par tests/reseau/lancer.sh, scénario 13) : Revanche relance la manche chez tous (la scène de
## jeu se recharge, la barrière attend de nouveau chaque joueur), Niveau suivant de même sur le niveau
## suivant, un choix que l'hôte ne peut plus suivre se regrise, Retour au salon ramène au salon, la même
## table, personne prêt, les arrivées de nouveau acceptées.
func _tester_resultats_reseau() -> void:
	print("-- Écran Résultats en réseau (hôte)")
	var reseau: Node = root.get_node("Reseau")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	reseau.pseudo = "Hôte"
	_check(reseau.heberger(17799) == OK, "(pré-condition) ce poste héberge")
	reseau.inscrits[7] = {"index": 1, "couleur": palette[3], "pseudo": "Bob", "arrive": true, "pret": true}
	reseau.inscrits[1].pret = true
	GS.niveau_courant = 0
	reseau.niveau_salon = 0
	_check(reseau.lancer_manche(), "(pré-condition) l'hôte lance la manche depuis le salon")
	var lancements := [0]
	var compter := func(_f: Array[Dictionary]) -> void: lancements[0] += 1
	reseau.manche_lancee.connect(compter)
	GS.configurer_bataille_reseau(reseau.fiches_de_manche(reseau.table_salon, 1))
	var main: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _passer_la_barriere(main)
	for k in range(3):
		main.get_node("Ville").territoire.tamponner(0, Vector2i(1000, 200), 40)
	_check(main.get_node("Ville").territoire.cellules_de(0) > 0, "(pré-condition) l'hôte a peint pendant la première manche")
	GS.terminer_partie(true)
	await _frames(1)
	_check(main.resultats != null and main.resultats.hote and main.resultats.possible(&"revanche") and main.resultats.possible(&"salon"),
		"(pré-condition) la manche finie, l'écran Résultats de l'hôte, Bob encore là : Revanche possible")
	# Revanche : la manche se relance chez tous, la scène de jeu se recharge et attend chaque joueur
	var id_premiere := main.get_instance_id()
	main.resultats.choisir(&"revanche")
	var revanche: Node = await _attendre_nouvelle_scene("res://Scenes/Main.tscn", id_premiere)
	_check(revanche != null and revanche.get_instance_id() != id_premiere and not is_instance_valid(main) and lancements[0] == 1 and reseau.manche_en_cours
		and not paused and revanche.en_reseau and not revanche.get_node("Manche").barriere and reseau.scenes_chargees == [1]
		and GS.niveau_courant == 0 and GS.joueurs.size() == 2 and GS.joueurs[1].pseudo == "Bob" and revanche.resultats == null,
		"Revanche : la manche se relance (même niveau, mêmes joueurs), la scène de jeu se recharge et attend Bob à la barrière")
	await _passer_la_barriere(revanche)
	_check(revanche.lions.size() == 2 and revanche.get_node("Ville").territoire.cellules_de(0) == 0 and GS.temps_ecoule == 0.0,
		"la barrière passée : les deux lions, un territoire vierge, le chrono à zéro")
	# Niveau suivant : de même, sur le niveau suivant
	GS.terminer_partie(true)
	await _frames(1)
	var id_revanche := revanche.get_instance_id()
	revanche.resultats.choisir(&"suivant")
	var suivante: Node = await _attendre_nouvelle_scene("res://Scenes/Main.tscn", id_revanche)
	_check(suivante != null and lancements[0] == 2 and GS.niveau_courant == 1 and reseau.niveau_salon == 1 and not paused,
		"Niveau suivant : la manche se relance sur le niveau suivant (Métropole), annoncé à chaque poste avec la table")
	await _passer_la_barriere(suivante)
	GS.terminer_partie(true)
	await _frames(1)
	var resultats: CanvasLayer = suivante.resultats
	# Bob part sur l'écran Résultats : il se grise ; seul, l'hôte ne peut plus relancer
	reseau._sur_pair_deconnecte(7)
	await _frames(1)
	_check(resultats.partis == [false, true] and resultats.lignes.any(func(l: Dictionary) -> bool: return l.index == 1 and l.badge.text == "PARTI")
		and not resultats.possible(&"revanche") and resultats.bouton_revanche.disabled and resultats.etat.text == tr("SALON_ATTENTE_JOUEURS"),
		"Bob part sur l'écran Résultats : sa ligne se grise, Revanche et Niveau suivant attendent deux joueurs")
	suivante._sur_choix_resultats(&"revanche")  # l'hôte qui ne peut plus suivre : refusé, rien ne change
	await _frames(2)
	_check(current_scene == suivante and lancements[0] == 2 and resultats.choix.is_empty() and reseau.manche_en_cours,
		"une relance que l'hôte ne peut plus suivre est refusée : l'écran reste, on peut encore choisir")
	# Retour au salon : la même table (Bob en moins), personne prêt, les arrivées de nouveau acceptées
	var balise_manche: bool = reseau.manche_en_cours
	resultats.choisir(&"salon")
	var salon: Node = await _attendre_scene("res://Scenes/Salon.tscn")
	_check(salon != null and salon.scene_file_path == "res://Scenes/Salon.tscn" and not paused and balise_manche and not reseau.manche_en_cours
		and reseau.table_salon.map(func(f: Dictionary) -> int: return f.id) == [1] and not reseau.inscrits[1].pret
		and salon.titre_niveau.text == "Niveau : Métropole",
		"Retour au salon : le salon de l'hôte s'ouvre sur la même table (Bob parti), personne prêt, le niveau gardé, les arrivées acceptées")
	reseau.manche_lancee.disconnect(compter)
	if salon != null:
		salon.free()
	await _frames(1)
	_check(reseau.manche_lancee.get_connections().is_empty() and reseau.salon_rouvert.get_connections().is_empty()
		and reseau.hote_perdu.get_connections().is_empty(),
		"les scènes de jeu fermées et le salon ne laissent aucune connexion aux autoloads")
	reseau.quitter()
	reseau.pseudo = ""
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false
	GS.niveau_courant = 0
```

- [ ] **Step 2 : les voir échouer**

Run : unitaires, puis smoke.
Expected : unitaires `SCRIPT ERROR: Invalid call. Nonexistent function 'relancer_manche' in base 'Node (Reseau.gd)'.` (dans « -- Salon ») et `SCRIPT ERROR: Invalid access to property or key 'CANAL_ORDONNE' on a base object of type 'Node (Reseau.gd)'.` (« -- Manches enchaînées ») ; smoke `❌ Revanche : la manche se relance (même niveau, mêmes joueurs), la scène de jeu se recharge et attend Bob à la barrière` et les suivants de « -- Écran Résultats en réseau (hôte) » (la scène ne se recharge pas : rien ne suit le choix en réseau).

- [ ] **Step 3 : `Reseau` : relancer, revenir au salon, le canal ordonné**

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## (`Scripts/Manche.gd`) attend tous les joueurs avant l'intro, et suit les départs
## (`joueur_parti`, `hote_perdu`). Hors réseau (solo, retour au titre), le pair est un
## `OfflineMultiplayerPeer` : ce poste est son propre hôte (`multiplayer.is_server()` vrai), et
```

par :

```gdscript
## (`Scripts/Manche.gd`) attend tous les joueurs avant l'intro, et suit les départs
## (`joueur_parti`, `hote_perdu`). Après la manche (phase 18, l'écran Résultats), l'hôte en relance une
## avec les mêmes joueurs (`relancer_manche` : Revanche, Niveau suivant) ou ramène chaque poste au salon
## (`revenir_au_salon`). Hors réseau (solo, retour au titre), le pair est un
## `OfflineMultiplayerPeer` : ce poste est son propre hôte (`multiplayer.is_server()` vrai), et
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## soit chargée chez un client l'y attend. Les RPC de l'hôte sont en mode "authority" (le moteur
## rejette tout autre émetteur) ; ceux des clients vérifient l'émetteur et leurs arguments.
##
```

par :

```gdscript
## soit chargée chez un client l'y attend. Les RPC de l'hôte sont en mode "authority" (le moteur
## rejette tout autre émetteur) ; ceux des clients vérifient l'émetteur et leurs arguments. Phase 18 : le
## lancement et le retour au salon partent sur le canal fiable ordonné de la manche (CANAL_ORDONNE,
## celui des tampons, du territoire et de la fin), la table avec eux : chez un client, une manche relancée
## depuis l'écran Résultats n'arrive qu'après tout ce que la précédente a envoyé sur ce canal, sa fin
## comprise (sinon un tampon, un territoire ou une fin retardés par une perte arriveraient dans la
## manche neuve). La table diffusée à chaque changement du salon reste sur le canal 0, celui de la
## poignée de main : sur le canal 1, la première table d'un arrivant pouvait devancer la fin de son
## authentification et être jetée (vu en préparant la phase 18, sous le relais du test réseau).
##
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
signal manche_lancee(fiches: Array[Dictionary])

const PORT := 7777
```

par :

```gdscript
signal manche_lancee(fiches: Array[Dictionary])
## Sur chaque poste en session : l'hôte ramène tout le monde au salon (phase 18, depuis l'écran
## Résultats) ; la table (sans les partis, personne prêt) est déjà arrivée, la manche n'est plus en cours.
signal salon_rouvert()

const PORT := 7777
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
const DELAI_DEPART := 1000
## Pour `adresse_ipv4`, la validation de l'écran Réseau (fonction statique : l'autoload n'est pas
```

par :

```gdscript
const DELAI_DEPART := 1000
## Canal ENet du lancement et du retour au salon, table comprise : le canal fiable ordonné de la manche
## (`Manche.CANAL_PEINTURE`, spec §4), phase 18.
const CANAL_ORDONNE := 1
## Pour `adresse_ipv4`, la validation de l'écran Réseau (fonction statique : l'autoload n'est pas
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
var places := EtatPartie.NB_JOUEURS_MAX
## Posé par la partie (phase 13 au lancement de la manche, phase 18 au retour au salon) : tant
## qu'il est vrai, l'hôte refuse tout nouveau venu (pas d'arrivée en cours de manche, spec §1).
var manche_en_cours := false
```

par :

```gdscript
var places := EtatPartie.NB_JOUEURS_MAX
## Posé au lancement de la manche (phase 13), et gardé tant qu'on enchaîne les manches depuis l'écran
## Résultats ; retiré au retour au salon (phase 18) : tant qu'il est vrai, l'hôte refuse tout nouveau
## venu (pas d'arrivée en cours de manche, spec §1).
var manche_en_cours := false
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
		return false
	var essai: Dictionary[int, Dictionary] = inscrits.duplicate(true)
```

par :

```gdscript
		return false
	return _lancer()


## Chez l'hôte, depuis l'écran Résultats (phase 18) : une manche neuve avec les joueurs encore là, sur le
## niveau `niveau` (ramené dans la liste, en boucle : Revanche, le même ; Niveau suivant, le suivant),
## comme `lancer_manche` (index recompactés, table diffusée, lancement, chargement), sans repasser par le
## salon : la manche reste en cours (aucune arrivée) et personne n'a à se redire prêt. Faux, sans rien
## changer, chez un client, hors d'une manche, ou à moins de NB_JOUEURS_MIN joueurs encore là.
func relancer_manche(niveau: int) -> bool:
	if not multiplayer.is_server() or not manche_en_cours or table_de(inscrits).size() < EtatPartie.NB_JOUEURS_MIN:
		return false
	niveau_salon = posmod(niveau, EtatPartie.NIVEAUX.size())
	return _lancer()


## Chez l'hôte, depuis l'écran Résultats (phase 18) : chaque poste revient au salon, sur la même table
## (les partis en moins) : le salon s'ouvre chez l'hôte (`ouvrir_salon` : plus de manche en cours, les
## arrivées de nouveau acceptées et annoncées par la balise, personne prêt, la table diffusée), puis
## chaque client change de scène (`_recevoir_retour_salon`, sur le canal ordonné, avec la table) ;
## `salon_rouvert` part aussi ici. Faux chez un client, ou hors d'une manche.
func revenir_au_salon() -> bool:
	if not multiplayer.is_server() or not manche_en_cours:
		return false
	definir_silence(SILENCE_SESSION)
	ouvrir_salon(niveau_salon)
	if en_ligne():
		_recevoir_retour_salon.rpc(table_salon, niveau_salon, places_salon)
	salon_rouvert.emit()
	return true


## La manche part (`lancer_manche`, `relancer_manche`), une fois les fiches revérifiées (M1).
func _lancer() -> bool:
	var essai: Dictionary[int, Dictionary] = inscrits.duplicate(true)
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
	if en_ligne():
		_recevoir_manche.rpc()
	manche_lancee.emit(fiches_de_manche(table_salon, multiplayer.get_unique_id()))
```

par :

```gdscript
	if en_ligne():
		_recevoir_manche.rpc(table_salon, niveau_salon)
	manche_lancee.emit(fiches_de_manche(table_salon, multiplayer.get_unique_id()))
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
		definir_pret(multiplayer.get_remote_sender_id(), pret)


## Chez un client : la table du salon diffusée par l'hôte (ignorée si elle est illisible). Ce
## poste y lit son index et sa couleur.
@rpc("authority", "call_remote", "reliable")
func _recevoir_salon(table: Variant, niveau: Variant, nb_places: Variant) -> void:
	var lue := lire_table(table)
	if lue.is_empty() or not (niveau is int) or niveau < 0 or niveau >= EtatPartie.NIVEAUX.size() \
			or not (nb_places is int) or nb_places < EtatPartie.NB_JOUEURS_MIN or nb_places > EtatPartie.NB_JOUEURS_MAX:
		push_warning("Reseau : table du salon illisible, ignorée")
		return
	table_salon = lue
```

par :

```gdscript
		definir_pret(multiplayer.get_remote_sender_id(), pret)


## Chez un client : la table du salon diffusée par l'hôte (ignorée si elle est illisible).
@rpc("authority", "call_remote", "reliable")
func _recevoir_salon(table: Variant, niveau: Variant, nb_places: Variant) -> void:
	if not _poser_salon(table, niveau, nb_places):
		push_warning("Reseau : table du salon illisible, ignorée")


## Chez un client : pose la table du salon reçue de l'hôte, son niveau et ses places ; ce poste y lit
## son index et sa couleur, puis `salon_change`. Faux, sans rien changer, pour une table illisible
## (`lire_table`) ou des valeurs hors plage.
func _poser_salon(table: Variant, niveau: Variant, nb_places: Variant) -> bool:
	var lue := lire_table(table)
	if lue.is_empty() or not (niveau is int) or niveau < 0 or niveau >= EtatPartie.NIVEAUX.size() \
			or not (nb_places is int) or nb_places < EtatPartie.NB_JOUEURS_MIN or nb_places > EtatPartie.NB_JOUEURS_MAX:
		return false
	table_salon = lue
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
	salon_change.emit()


## Chez un client : l'hôte lance la manche, sur la table compactée reçue juste avant. Le chargement
## commence : silence toléré SILENCE_CHARGEMENT.
@rpc("authority", "call_remote", "reliable")
func _recevoir_manche() -> void:
	var fiches := fiches_de_manche(table_salon, multiplayer.get_unique_id())
	if fiches.is_empty():
```

par :

```gdscript
	salon_change.emit()
	return true


## Chez un client : l'hôte lance la manche, sur la table compactée et le niveau `table`, `niveau` (phase
## 18 : avec le lancement, sur le canal ordonné, que la table diffusée sur le canal 0 peut ne pas
## précéder). Le chargement commence : silence toléré SILENCE_CHARGEMENT.
@rpc("authority", "call_remote", "reliable", CANAL_ORDONNE)
func _recevoir_manche(table: Variant, niveau: Variant) -> void:
	var fiches := fiches_de_manche(table_salon, multiplayer.get_unique_id()) if _poser_salon(table, niveau, places_salon) else [] as Array[Dictionary]
	if fiches.is_empty():
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
	manche_lancee.emit(fiches)


## Chez l'hôte : la scène de jeu d'un joueur de la manche est chargée (barrière avant l'intro).
```

par :

```gdscript
	manche_lancee.emit(fiches)


## Chez un client : l'hôte ramène tout le monde au salon (phase 18), sur la table `table`, son niveau et
## ses places (la même que celle diffusée juste avant, sur le canal 0 ; aucune place n'est réservée
## pendant une manche). Une table illisible est signalée, le retour a lieu quand même.
@rpc("authority", "call_remote", "reliable", CANAL_ORDONNE)
func _recevoir_retour_salon(table: Variant, niveau: Variant, nb_places: Variant) -> void:
	if not _poser_salon(table, niveau, nb_places):
		push_warning("Reseau : table du retour au salon illisible, ignorée")
	manche_en_cours = false
	definir_silence(SILENCE_SESSION)
	salon_rouvert.emit()


## Chez l'hôte : la scène de jeu d'un joueur de la manche est chargée (barrière avant l'intro).
```

- [ ] **Step 4 : chaque poste suit les choix de l'hôte**

Dans `Scripts/Main.gd`, remplacer :

```gdscript
const SCENE_TITRE := "res://Scenes/Titre.tscn"
const SCRIPT_PILOTE := preload("res://Scripts/Pilote.gd")
```

par :

```gdscript
const SCENE_TITRE := "res://Scenes/Titre.tscn"
const SCENE_SALON := "res://Scenes/Salon.tscn"
const _Salon := preload("res://Scripts/Salon.gd")
const SCRIPT_PILOTE := preload("res://Scripts/Pilote.gd")
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
	Reseau.hote_perdu.connect(_sur_hote_perdu)
	manche.demarrer(ville)


## La `spawn_function` d'`apparitions`, sur chaque poste : le lion du joueur d'index `index`, avec
```

par :

```gdscript
	Reseau.hote_perdu.connect(_sur_hote_perdu)
	# Phase 18 : depuis l'écran Résultats, l'hôte relance une manche (chaque poste recharge la scène de
	# jeu) ou ramène tout le monde au salon.
	Reseau.manche_lancee.connect(_sur_manche_relancee)
	Reseau.salon_rouvert.connect(_sur_salon_rouvert)
	manche.demarrer(ville)


## Les autoloads survivent à la scène de jeu : ne rien leur laisser.
func _exit_tree() -> void:
	for connexion: Array in [[Reseau.hote_perdu, _sur_hote_perdu], [Reseau.manche_lancee, _sur_manche_relancee],
			[Reseau.salon_rouvert, _sur_salon_rouvert]]:
		if (connexion[0] as Signal).is_connected(connexion[1]):
			(connexion[0] as Signal).disconnect(connexion[1])


## Sur chaque poste : l'hôte relance une manche avec les mêmes joueurs (Revanche, Niveau suivant) : la
## scène de jeu se recharge, comme depuis le salon (`Salon.entrer_en_manche`).
func _sur_manche_relancee(fiches: Array[Dictionary]) -> void:
	_Salon.entrer_en_manche(get_tree(), fiches)


## Sur chaque poste : l'hôte ramène tout le monde au salon.
func _sur_salon_rouvert() -> void:
	get_tree().change_scene_to_file(SCENE_SALON)


## La `spawn_function` d'`apparitions`, sur chaque poste : le lion du joueur d'index `index`, avec
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
## Le choix fait sur l'écran Résultats. Quitter : le titre (qui quitte le réseau ; l'hôte qui part ramène
## ses clients au titre, « L'hôte a quitté la partie »). Hors réseau, Revanche et Niveau suivant
## rechargent la scène de jeu, sur le même niveau ou le suivant (en boucle), avec les mêmes joueurs : un
## territoire, un Spawner, un chrono tout neufs.
func _sur_choix_resultats(choix: StringName) -> void:
	match choix:
		&"quitter":
			get_tree().change_scene_to_file(SCENE_TITRE)
		&"revanche", &"suivant":
			if not en_reseau:
				if choix == &"suivant":
					GameState.niveau_courant = posmod(GameState.niveau_courant + 1, GameState.NIVEAUX.size())
				get_tree().reload_current_scene()
```

par :

```gdscript
## Le choix fait sur l'écran Résultats. Quitter : le titre (qui quitte le réseau ; l'hôte qui part ramène
## ses clients au titre, « L'hôte a quitté la partie »). Revanche et Niveau suivant : la scène de jeu se
## recharge, sur le même niveau ou le suivant (en boucle), avec les mêmes joueurs (les partis en moins) :
## un territoire, un Spawner, un chrono, une manche tout neufs ; en réseau, l'hôte la relance chez tous
## (`Reseau.relancer_manche`, puis `_sur_manche_relancee` sur chaque poste). Retour au salon (l'hôte, en
## réseau) : chaque poste revient au salon, sur la même table (`Reseau.revenir_au_salon`). Un choix que
## l'hôte ne peut plus suivre au moment même (plus assez de joueurs) se regrise.
func _sur_choix_resultats(choix: StringName) -> void:
	var niveau := GameState.niveau_courant + (1 if choix == &"suivant" else 0)
	match choix:
		&"quitter":
			get_tree().change_scene_to_file(SCENE_TITRE)
		&"revanche", &"suivant":
			if en_reseau:
				if not Reseau.relancer_manche(niveau):
					resultats.annuler_choix()
			else:
				GameState.niveau_courant = posmod(niveau, GameState.NIVEAUX.size())
				get_tree().reload_current_scene()
		&"salon":
			if not Reseau.revenir_au_salon():
				resultats.annuler_choix()
```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
func _ready() -> void:
	Regles.appliquer_ecran(get_tree(), ReglesBataille.TAILLE_ECRAN)
```

par :

```gdscript
func _ready() -> void:
	# Au retour de l'écran Résultats (phase 18), l'arbre est encore en pause (la fin de manche l'a figé).
	get_tree().paused = false
	Regles.appliquer_ecran(get_tree(), ReglesBataille.TAILLE_ECRAN)
```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
	bouton_demarrer.disabled = true
	GameState.niveau_courant = Reseau.niveau_salon
	GameState.configurer_bataille_reseau(fiches)
	get_tree().change_scene_to_file(SCENE_JEU)


func _sur_hote_perdu() -> void:
```

par :

```gdscript
	bouton_demarrer.disabled = true
	entrer_en_manche(get_tree(), fiches)


## Sur chaque poste, au lancement d'une manche (depuis le salon, ou depuis l'écran Résultats : Revanche,
## Niveau suivant, phase 18) : le niveau du salon devient celui de la partie, les règles de bataille et la
## table des joueurs sont branchées (`GameState.configurer_bataille_reseau`), puis la scène de jeu se
## charge.
static func entrer_en_manche(arbre: SceneTree, fiches: Array[Dictionary]) -> void:
	GameState.niveau_courant = Reseau.niveau_salon
	GameState.configurer_bataille_reseau(fiches)
	arbre.change_scene_to_file(SCENE_JEU)


func _sur_hote_perdu() -> void:
```

- [ ] **Step 5 : rien d'une manche finie dans la suivante**

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
		j.recevoir_fin_bonus()


## Le joueur d'index `index` reçu de l'hôte, ou null (index d'un autre type ou hors de la table).
func _joueur_recu(index: Variant) -> Joueur:
	if not actif or not (index is int) or index < 0 or index >= GameState.joueurs.size():
		return null
```

par :

```gdscript
		j.recevoir_fin_bonus()


## Le joueur d'index `index` reçu de l'hôte, ou null (index d'un autre type ou hors de la table, ou la
## barrière pas encore passée : phase 18, une réaction ou un départ d'une manche précédente, sur le canal
## 0, arrivé après que ce poste a rechargé la scène pour une revanche, ne touche pas la manche neuve ;
## ceux de la manche neuve partent après son intro, sur le même canal).
func _joueur_recu(index: Variant) -> Joueur:
	if not actif or not barriere or not (index is int) or index < 0 or index >= GameState.joueurs.size():
		return null
```

- [ ] **Step 6 : les voir passer**

Run : unitaires, smoke, bataille, banc, la trace, puis le test réseau.
Expected : `== 0 échec(s) ==` partout, dont aux unitaires « Niveau suivant : une manche neuve avec les joueurs encore là (index recompactés)… », « Retour au salon : plus de manche en cours… », « seul, l'hôte ne relance pas de manche… », « -- Manches enchaînées (phase 18) » (5 vérifications : les canaux, la table portée par le lancement et par le retour au salon, rien avant la barrière) ; au smoke « -- Écran Résultats en réseau (hôte) » (Revanche, Niveau suivant, Bob parti, relance refusée, Retour au salon, aucune connexion laissée aux autoloads) ; le test réseau vert.

- [ ] **Step 7 : commit**

```bash
git add Scripts/Reseau.gd Scripts/Main.gd Scripts/Salon.gd Scripts/Manche.gd tests/unitaires.gd tests/smoke_test.gd
git commit -m "Revanche, Niveau suivant et Retour au salon en réseau : l'hôte relance la manche chez tous sans repasser par le salon (joueurs encore là, index recompactés, deux au moins ; chaque poste recharge la scène de jeu) ou ramène chacun au salon sur la même table ; le lancement et le retour au salon, avec leur table, sur le canal ordonné de la manche, et rien d'une manche finie (réaction, départ) dans la suivante avant sa barrière

<ligne fournie par l'environnement>"
```

---

### Task 6 : le salon au retour d'une manche, la raison de l'exclusion, la boucle du vomi après un hôte perdu (`Reseau`, `Salon`, `Manche`, `Main`, `Titre`)

**Files:**
- Modify: `Scripts/Reseau.gd` (`PERTE_HOTE`, `PERTE_EXCLU`, `DELAI_EXCLUSION`, `places_reservees`, `raison_perte`, `_exclu`, `quitter`, `exclure` ➕, `_deconnecter` ➕, `_recevoir_exclusion` ➕, `fiches_attente` ➕, `_diffuser_salon`, `_recevoir_salon` (un argument de plus), `_repondre`, `_sur_echec_poignee_de_main`, `_fermer_puis_emettre`), `Scripts/Manche.gd` (`_exclure`), `Scripts/Salon.gd` (`_tenues` relevées à l'ouverture, `_adresses_hote`, `_afficher_etat`, la raison de la perte), `Scripts/Main.gd` (`_sur_hote_perdu`), `Scripts/Titre.gd` (`_ready`), `Assets/Traductions/traductions.csv` (+ les deux `.translation`)
- Test: `tests/unitaires.gd` (`_tester_reseau_manche`), `tests/smoke_test.gd` (`_tester_salon`, `_tester_manche_reseau`), `tests/reseau/joueur.gd` (le muet du scénario 9)

**Interfaces:**
- Consumes (Task 5) : `Reseau.CANAL_ORDONNE` (`_recevoir_salon` y reste).
- Produces (Task 7) : `const Reseau.PERTE_HOTE := "RESEAU_HOTE_PERDU"`, `const Reseau.PERTE_EXCLU := "RESEAU_EXCLU"`, `const Reseau.DELAI_EXCLUSION := 0.5` ; `var Reseau.places_reservees: int` (diffusé avec la table : `_recevoir_salon(table, niveau, nb_places, reservees)`) ; `var Reseau.raison_perte: String` (posé juste avant `hote_perdu`) ; `func Reseau.exclure(id: int) -> void` ; `func Reseau.fiches_attente() -> Array` (à donner à `raison_attente`) ; RPC `Reseau._recevoir_exclusion()`.

Les quatre restes, un par point de vigilance : (1) M2 de la revue finale 13 : un client voyait « l'hôte peut démarrer » pendant qu'une place était réservée (le bouton de l'hôte grisé) ; l'hôte diffuse désormais la table à chaque réservation et chaque libération, avec leur nombre, et un client compte une fiche « pas encore arrivé » par place réservée. (2) M3 : un stick déjà penché à l'ouverture du salon (au retour d'une manche) y changeait la couleur une fois : l'état de chaque action est relevé à l'ouverture. (3) M4 : `IP.get_local_interfaces()` était relu à chaque changement du salon : une fois, à l'ouverture. (4) Phase 14 : l'exclu de la barrière voyait « L'hôte a quitté la partie » ; il apprend son exclusion avant d'être déconnecté. Et M5 de la revue finale 17 : la boucle du vomi d'un joueur qui tenait Espace quand l'hôte a disparu continuait sur le titre ; `Main._sur_hote_perdu` l'arrête, et `Titre._ready` aussi, en filet.

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	reseau.manche_lancee.disconnect(sur_lancement)
	reseau.definir_silence(reseau.SILENCE_SESSION)
```

par :

```gdscript
	reseau.manche_lancee.disconnect(sur_lancement)
	# Phase 18 : un exclu de la barrière apprend son exclusion avant d'être déconnecté ; la perte de
	# l'hôte qui suit le dit (`raison_perte`), une fois
	var raisons: Array[String] = []
	var sur_perte := func() -> void: raisons.append(reseau.raison_perte)
	reseau.hote_perdu.connect(sur_perte)
	reseau._recevoir_exclusion()
	reseau._fermer_puis_emettre(&"hote_perdu", [], reseau._generation)
	reseau._fermer_puis_emettre(&"hote_perdu", [], reseau._generation)
	reseau.hote_perdu.disconnect(sur_perte)
	_check(raisons == [reseau.PERTE_EXCLU, reseau.PERTE_HOTE] and not reseau._exclu,
		"l'hôte perdu après une exclusion : « exclu » ; la perte suivante, de nouveau « l'hôte a quitté la partie » (%s)" % [raisons])
	_check(reseau.heberger(17788) == OK, "(pré-condition) l'hôte écoute de nouveau")
	reseau.definir_silence(reseau.SILENCE_SESSION)
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	_check(reseau.heberger(17797) == OK, "(pré-condition) ce poste héberge")
	var salon: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon)
	await process_frame

	# L'hôte seul : sa carte, les places libres, le niveau du titre, ses adresses ; aucun focus
```

par :

```gdscript
	_check(reseau.heberger(17797) == OK, "(pré-condition) ce poste héberge")
	Input.action_press("deplacer_droite")  # phase 18 (M3, revue finale 13) : un stick déjà penché en arrivant
	var salon: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon)
	await process_frame
	await _appuyer(&"deplacer_droite", true)  # un événement de plus du stick toujours penché
	_check(reseau.inscrits[1].couleur == palette[0], "M3 : un stick déjà penché à l'ouverture du salon n'y change pas la couleur")
	await _appuyer(&"deplacer_droite", false)
	Input.action_release("deplacer_droite")

	# L'hôte seul : sa carte, les places libres, le niveau du titre, ses adresses ; aucun focus
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
		"aucun contrôle ne prend le focus : flèches, croix, stick, vomir et démarrer vont au salon")

	# Une place réservée (poignée de main en cours) n'a pas de carte ; un joueur arrivé a la sienne
```

par :

```gdscript
		"aucun contrôle ne prend le focus : flèches, croix, stick, vomir et démarrer vont au salon")
	var adresses_lues: PackedStringArray = salon._adresses_hote
	salon._adresses_hote = PackedStringArray(["10.9.9.9"])
	reseau.salon_change.emit()
	_check(salon.adresses.text.contains("10.9.9.9"), "M4 : les adresses de l'hôte sont relevées une fois, à l'ouverture, pas à chaque changement du salon")
	salon._adresses_hote = adresses_lues

	# Une place réservée (poignée de main en cours) n'a pas de carte ; un joueur arrivé a la sienne
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
		"une place seulement réservée n'a pas de carte (M4) ; un joueur arrivé a la sienne")

	# Couleurs : la voisine libre (celle d'une place réservée est prise) ; une seule par appui
```

par :

```gdscript
		"une place seulement réservée n'a pas de carte (M4) ; un joueur arrivé a la sienne")
	_check(reseau.places_reservees == 1, "phase 18 : la table part avec le nombre de places seulement réservées (%d)" % reseau.places_reservees)

	# Couleurs : la voisine libre (celle d'une place réservée est prise) ; une seule par appui
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	reseau.table_salon[1].pret = true
	reseau.salon_change.emit()
	_check(attente_client == tr("SALON_ATTENTE_PRETS") and salon_client.etat.text == tr("SALON_ATTENTE_HOTE"),
		"un client voit pourquoi la partie attend, puis « l'hôte peut démarrer » (%s | %s)" % [attente_client, salon_client.etat.text])
	reseau.quitter()
```

par :

```gdscript
	reseau.table_salon[1].pret = true
	reseau.places_reservees = 1  # comme la table de l'hôte pendant qu'un joueur arrive
	reseau.salon_change.emit()
	var attente_arrivee: String = salon_client.etat.text
	reseau.places_reservees = 0
	reseau.salon_change.emit()
	_check(attente_client == tr("SALON_ATTENTE_PRETS") and attente_arrivee == tr("SALON_ATTENTE_ARRIVEE") and salon_client.etat.text == tr("SALON_ATTENTE_HOTE"),
		"un client voit pourquoi la partie attend (un joueur pas prêt ; M2 : un joueur qui arrive), puis « l'hôte peut démarrer » (%s | %s | %s)"
			% [attente_client, attente_arrivee, salon_client.etat.text])
	reseau.quitter()
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
				"(absent) l'exclu reste au classement, en grisé ; son départ sera annoncé aux clients en passant la barrière")
			main.free()
```

par :

```gdscript
				"(absent) l'exclu reste au classement, en grisé ; son départ sera annoncé aux clients en passant la barrière")
			# Phase 18 : chez l'exclu, la perte de l'hôte dit pourquoi
			reseau.raison_perte = reseau.PERTE_EXCLU
			main._sur_hote_perdu()
			_check(main.get_node("HotePerdu/Message").text == "RESEAU_EXCLU",
				"chez un exclu, le message dit qu'il a été exclu (sa partie trop longue à charger), pas « L'hôte a quitté la partie »")
			reseau.raison_perte = reseau.PERTE_HOTE
			paused = false
			main.free()
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
			"l'écran Résultats de l'hôte en réseau : Retour au salon ; Bob parti, Revanche et Niveau suivant attendent deux joueurs")
		# Un hôte perdu (chez un client) : message, tout se fige
		main._sur_hote_perdu()
		var message: Label = main.get_node("HotePerdu/Message")
		_check(message.text == "RESEAU_HOTE_PERDU" and paused and not resultats.visible,
			"l'hôte perdu : « L'hôte a quitté la partie » (à la place de l'écran Résultats), la partie se fige")
		paused = false
```

par :

```gdscript
			"l'écran Résultats de l'hôte en réseau : Retour au salon ; Bob parti, Revanche et Niveau suivant attendent deux joueurs")
		# Un hôte perdu (chez un client) : message, tout se fige ; M5 (revue finale phase 17) : la boucle du
		# vomi d'un joueur qui tenait Espace s'arrête
		var audio: Node = root.get_node("Audio")
		audio.demarrer_vomi()
		main._sur_hote_perdu()
		var message: Label = main.get_node("HotePerdu/Message")
		_check(message.text == "RESEAU_HOTE_PERDU" and paused and not resultats.visible and not audio._vomi.playing,
			"l'hôte perdu : « L'hôte a quitté la partie » (à la place de l'écran Résultats), la partie se fige, la boucle du vomi s'arrête")
		paused = false
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
##   lancement de la manche mais ne charge jamais sa scène : l'hôte doit l'exclure après le délai de
##   la barrière (« EXCLU »). --figer=S (I1, revue finale phase 14) : dès le lancement de la manche
##   reçu, fige tout le processus S secondes (« FIGE_MUET ») avant de reprendre et sortir en 0, sans
```

par :

```gdscript
##   lancement de la manche mais ne charge jamais sa scène : l'hôte doit l'exclure après le délai de
##   la barrière (« EXCLU », avec la raison de la perte de l'hôte : exclu, phase 18). --figer=S (I1, revue finale phase 14) : dès le lancement de la manche
##   reçu, fige tout le processus S secondes (« FIGE_MUET ») avant de reprendre et sortir en 0, sans
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	var apres: float = (Time.get_ticks_msec() - lancee[0]) / 1000.0
	print("EXCLU apres=%.1f s" % apres)
	_check(_issue == "inscrit+hote_perdu" and apres >= float(_option("delai-chargement", "0")),
		"l'hôte l'exclut après le délai de la barrière (%.1f s)" % apres)


## Rôles « bout-hote » et « bout-client » (phase 15, voir l'en-tête) : une manche entière à 1 hôte et
```

par :

```gdscript
	var apres: float = (Time.get_ticks_msec() - lancee[0]) / 1000.0
	print("EXCLU apres=%.1f s raison=%s" % [apres, reseau.raison_perte])
	_check(_issue == "inscrit+hote_perdu" and apres >= float(_option("delai-chargement", "0")),
		"l'hôte l'exclut après le délai de la barrière (%.1f s)" % apres)
	_check(reseau.raison_perte == reseau.PERTE_EXCLU,
		"phase 18 : l'exclu l'apprend de l'hôte avant d'être déconnecté (%s, pas « L'hôte a quitté la partie »)" % reseau.raison_perte)


## Rôles « bout-hote » et « bout-client » (phase 15, voir l'en-tête) : une manche entière à 1 hôte et
```

- [ ] **Step 2 : les voir échouer**

Run : unitaires, puis smoke.
Expected : unitaires `SCRIPT ERROR: Invalid call. Nonexistent function '_recevoir_exclusion' in base 'Node (Reseau.gd)'.` ; smoke `❌ M3 : un stick déjà penché à l'ouverture du salon n'y change pas la couleur`, `❌ la carte de l'hôte : pseudo, badges, pas prêt, lion et contour à sa couleur` (le stick l'a changée), puis `SCRIPT ERROR: Invalid access to property or key '_adresses_hote' on a base object of type 'Control (Salon.gd)'.`.

- [ ] **Step 3 : `Reseau` : places réservées, exclusion, raison de la perte**

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Chez le client : l'hôte a quitté la partie ou ne répond plus. Le poste est déjà revenu hors
## réseau quand le signal part. N4 : si le pair ENet de l'hôte tombe lui-même en erreur, ce même
## signal part aussi chez l'hôte (server_disconnected n'y distingue pas les deux cas) ; personne ne
```

par :

```gdscript
## Chez le client : l'hôte a quitté la partie ou ne répond plus. Le poste est déjà revenu hors
## réseau quand le signal part ; `raison_perte` dit pourquoi (phase 18 : un joueur exclu par la barrière
## de chargement le sait). N4 : si le pair ENet de l'hôte tombe lui-même en erreur, ce même
## signal part aussi chez l'hôte (server_disconnected n'y distingue pas les deux cas) ; personne ne
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
const REFUS_DEMANDE := "RESEAU_REFUS_DEMANDE"
## Pourquoi l'hôte ne peut pas encore démarrer la partie (`raison_attente`), en clés de traduction.
```

par :

```gdscript
const REFUS_DEMANDE := "RESEAU_REFUS_DEMANDE"
## Pourquoi l'hôte est perdu (`raison_perte`), en clés de traduction : il est parti (ou ne répond
## plus), ou il a exclu ce poste (barrière de chargement, phase 18).
const PERTE_HOTE := "RESEAU_HOTE_PERDU"
const PERTE_EXCLU := "RESEAU_EXCLU"
## Entre l'annonce de son exclusion à un joueur et sa déconnexion, en secondes : le temps que
## l'annonce arrive, renvoyée au besoin par ENet (une déconnexion vide la file d'envoi).
const DELAI_EXCLUSION := 0.5
## Pourquoi l'hôte ne peut pas encore démarrer la partie (`raison_attente`), en clés de traduction.
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
var places_salon := EtatPartie.NB_JOUEURS_MAX
## Index et couleur de ce poste, attribués par l'hôte (-1 et transparente hors réseau).
```

par :

```gdscript
var places_salon := EtatPartie.NB_JOUEURS_MAX
## Places seulement réservées (une poignée de main en cours, pas encore de carte), diffusées avec la
## table (phase 18, M2 de la revue finale 13 : sans elles, un client lisait « l'hôte peut démarrer »
## pendant qu'un joueur arrivait, le bouton de l'hôte grisé).
var places_reservees := 0
## Chez un client : pourquoi l'hôte a été perdu la dernière fois (PERTE_HOTE ou PERTE_EXCLU), posé juste
## avant `hote_perdu` ; ce que montrent la scène de jeu et le salon.
var raison_perte := PERTE_HOTE
## Index et couleur de ce poste, attribués par l'hôte (-1 et transparente hors réseau).
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
var _partants: Array[Dictionary] = []


func _ready() -> void:
```

par :

```gdscript
var _partants: Array[Dictionary] = []
## Chez un client : vrai une fois son exclusion annoncée par l'hôte (`_recevoir_exclusion`), jusqu'à la
## perte de l'hôte qui suit.
var _exclu := false


func _ready() -> void:
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
	places_salon = EtatPartie.NB_JOUEURS_MAX
	index_local = -1
```

par :

```gdscript
	places_salon = EtatPartie.NB_JOUEURS_MAX
	places_reservees = 0
	_exclu = false
	index_local = -1
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
				p.set_timeout(ESSAIS_SILENCE, bornes.x, bornes.y)


## La scène de jeu de ce poste est chargée (appelé par la manche, chez chaque joueur) : chez l'hôte,
```

par :

```gdscript
				p.set_timeout(ESSAIS_SILENCE, bornes.x, bornes.y)


## Chez l'hôte : le joueur `id` n'a pas chargé sa scène de jeu à temps (la barrière de la manche,
## `Manche._exclure`) : il apprend son exclusion (`_recevoir_exclusion` : il verra PERTE_EXCLU, pas
## « L'hôte a quitté la partie »), puis il est déconnecté DELAI_EXCLUSION plus tard (proprement : son
## départ arrive par `joueur_parti`). I1 (revue finale phase 14) : un pair figé (chargement,
## compilation des shaders) n'acquitte jamais ni l'annonce ni le DISCONNECT ; sans un silence court
## (1 à 2 s, posé tout de suite), ENet ne l'abandonnerait qu'à son silence de chargement
## (SILENCE_CHARGEMENT, 20 à 30 s), et la barrière l'attendrait tout ce temps.
func exclure(id: int) -> void:
	if not multiplayer.is_server() or not multiplayer.get_peers().has(id):
		return
	var pair := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if pair != null:
		pair.get_peer(id).set_timeout(ESSAIS_SILENCE, 1000, 2000)
	_recevoir_exclusion.rpc_id(id)
	get_tree().create_timer(DELAI_EXCLUSION, true).timeout.connect(_deconnecter.bind(id, _generation))


## Chez l'hôte : déconnecte l'exclu `id`, s'il l'est encore, dans la même session (`generation`).
func _deconnecter(id: int, generation: int) -> void:
	if generation == _generation and multiplayer.get_peers().has(id):
		multiplayer.multiplayer_peer.disconnect_peer(id)


## Chez un client : l'hôte l'exclut de la manche (sa scène de jeu pas chargée à temps) ; la perte de
## l'hôte qui suit le dira (`raison_perte`).
@rpc("authority", "call_remote", "reliable")
func _recevoir_exclusion() -> void:
	_exclu = true


## Les fiches dont dépend le démarrage (`raison_attente`) : chez l'hôte, ses inscrits (places réservées
## comprises) ; chez un client, la table du salon, plus une fiche d'arrivant pas encore là par place
## réservée que l'hôte annonce (phase 18, M2 de la revue finale 13).
func fiches_attente() -> Array:
	if multiplayer.is_server():
		return inscrits.values()
	var fiches: Array = table_salon.duplicate()
	for i in range(places_reservees):
		fiches.append({"arrive": false, "pret": false})
	return fiches


## La scène de jeu de ce poste est chargée (appelé par la manche, chez chaque joueur) : chez l'hôte,
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
	table_salon = table_de(inscrits)
	if en_ligne():
		_recevoir_salon.rpc(table_salon, niveau_salon, places_salon)
	salon_change.emit()
```

par :

```gdscript
	table_salon = table_de(inscrits)
	places_reservees = inscrits.size() - table_salon.size()
	if en_ligne():
		_recevoir_salon.rpc(table_salon, niveau_salon, places_salon, places_reservees)
	salon_change.emit()
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
		definir_pret(multiplayer.get_remote_sender_id(), pret)


## Chez un client : la table du salon diffusée par l'hôte (ignorée si elle est illisible).
@rpc("authority", "call_remote", "reliable")
func _recevoir_salon(table: Variant, niveau: Variant, nb_places: Variant) -> void:
	if not _poser_salon(table, niveau, nb_places):
		push_warning("Reseau : table du salon illisible, ignorée")


## Chez un client : pose la table du salon reçue de l'hôte, son niveau et ses places ; ce poste y lit
## son index et sa couleur, puis `salon_change`. Faux, sans rien changer, pour une table illisible
## (`lire_table`) ou des valeurs hors plage.
func _poser_salon(table: Variant, niveau: Variant, nb_places: Variant) -> bool:
	var lue := lire_table(table)
	if lue.is_empty() or not (niveau is int) or niveau < 0 or niveau >= EtatPartie.NIVEAUX.size() \
			or not (nb_places is int) or nb_places < EtatPartie.NB_JOUEURS_MIN or nb_places > EtatPartie.NB_JOUEURS_MAX:
		return false
	table_salon = lue
	niveau_salon = niveau
	places_salon = nb_places
	for fiche in lue:
```

par :

```gdscript
		definir_pret(multiplayer.get_remote_sender_id(), pret)


## Chez un client : la table du salon diffusée par l'hôte (ignorée si elle est illisible), avec le
## niveau, les places et les places seulement réservées.
@rpc("authority", "call_remote", "reliable")
func _recevoir_salon(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant) -> void:
	if not _poser_salon(table, niveau, nb_places, reservees):
		push_warning("Reseau : table du salon illisible, ignorée")


## Chez un client : pose la table du salon reçue de l'hôte, son niveau, ses places et ses places
## seulement réservées ; ce poste y lit son index et sa couleur, puis `salon_change`. Faux, sans rien
## changer, pour une table illisible (`lire_table`) ou des valeurs hors plage.
func _poser_salon(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant) -> bool:
	var lue := lire_table(table)
	if lue.is_empty() or not (niveau is int) or niveau < 0 or niveau >= EtatPartie.NIVEAUX.size() \
			or not (nb_places is int) or nb_places < EtatPartie.NB_JOUEURS_MIN or nb_places > EtatPartie.NB_JOUEURS_MAX \
			or not (reservees is int) or reservees < 0 or reservees > EtatPartie.NB_JOUEURS_MAX - lue.size():
		return false
	table_salon = lue
	niveau_salon = niveau
	places_salon = nb_places
	places_reservees = reservees
	for fiche in lue:
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
func _recevoir_manche(table: Variant, niveau: Variant) -> void:
	var fiches := fiches_de_manche(table_salon, multiplayer.get_unique_id()) if _poser_salon(table, niveau, places_salon) else [] as Array[Dictionary]
	if fiches.is_empty():
```

par :

```gdscript
func _recevoir_manche(table: Variant, niveau: Variant) -> void:
	var fiches := fiches_de_manche(table_salon, multiplayer.get_unique_id()) if _poser_salon(table, niveau, places_salon, 0) else [] as Array[Dictionary]
	if fiches.is_empty():
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
func _recevoir_retour_salon(table: Variant, niveau: Variant, nb_places: Variant) -> void:
	if not _poser_salon(table, niveau, nb_places):
		push_warning("Reseau : table du retour au salon illisible, ignorée")
```

par :

```gdscript
func _recevoir_retour_salon(table: Variant, niveau: Variant, nb_places: Variant) -> void:
	if not _poser_salon(table, niveau, nb_places, 0):
		push_warning("Reseau : table du retour au salon illisible, ignorée")
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
		inscrits[id] = {"index": reponse.index, "couleur": reponse.couleur, "pseudo": reponse.pseudo, "arrive": false, "pret": false}
		salon_change.emit()  # une place réservée : le bouton Démarrer de l'hôte se grise
	_api().send_auth(id, var_to_bytes(reponse))
```

par :

```gdscript
		inscrits[id] = {"index": reponse.index, "couleur": reponse.couleur, "pseudo": reponse.pseudo, "arrive": false, "pret": false}
		_diffuser_salon()  # une place réservée : le bouton Démarrer de l'hôte se grise, ses clients le savent
	_api().send_auth(id, var_to_bytes(reponse))
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
	if multiplayer.is_server() and inscrits.erase(id):
		salon_change.emit()  # la place réservée se libère : le bouton de l'hôte peut revenir


## Chez l'hôte : un accepté a fini sa poignée de main. Il est désormais arrivé : sa carte apparaît
```

par :

```gdscript
	if multiplayer.is_server() and inscrits.erase(id):
		_diffuser_salon()  # la place réservée se libère : le bouton de l'hôte peut revenir, chez ses clients aussi


## Chez l'hôte : un accepté a fini sa poignée de main. Il est désormais arrivé : sa carte apparaît
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
		return
	quitter()
	callv("emit_signal", [nom] + arguments)
```

par :

```gdscript
		return
	var exclu := _exclu
	quitter()
	if nom == &"hote_perdu":
		raison_perte = PERTE_EXCLU if exclu else PERTE_HOTE
	callv("emit_signal", [nom] + arguments)
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
		_envoyer(&"_recevoir_depart", [index])


## Chez l'hôte : `id` n'a pas chargé sa scène à temps. Il est déconnecté (proprement : il le voit
## comme un hôte perdu, et son départ arrive ici par `Reseau.joueur_parti`).
func _exclure(id: int) -> void:
```

par :

```gdscript
		_envoyer(&"_recevoir_depart", [index])


## Chez l'hôte : `id` n'a pas chargé sa scène à temps. Il apprend son exclusion, puis il est déconnecté
## (`Reseau.exclure` : il voit « exclu », pas « L'hôte a quitté la partie ») ; son départ arrive ici par
## `Reseau.joueur_parti`.
func _exclure(id: int) -> void:
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
	push_warning("Manche : le joueur %d n'a pas chargé sa scène à temps, exclu" % id)
	if multiplayer.get_peers().has(id):
		# I1 (revue finale phase 14) : un pair figé (chargement, compilation des shaders) n'acquitte
		# jamais le DISCONNECT ; sans ceci, ENet ne l'abandonne qu'à son propre silence de
		# chargement (SILENCE_CHARGEMENT, 20 à 30 s), et la barrière l'attend tout ce temps. Un
		# silence court (1 à 2 s) avant `disconnect_peer` (sans `force`) : le départ arrive quand
		# même par `peer_disconnected`, puis `Reseau.joueur_parti`, comme un pair réactif.
		var pair := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if pair != null:
			pair.get_peer(id).set_timeout(Reseau.ESSAIS_SILENCE, 1000, 2000)
		multiplayer.multiplayer_peer.disconnect_peer(id)


## Chez un client : la barrière est passée chez l'hôte.
```

par :

```gdscript
	push_warning("Manche : le joueur %d n'a pas chargé sa scène à temps, exclu" % id)
	Reseau.exclure(id)


## Chez un client : la barrière est passée chez l'hôte.
```

- [ ] **Step 4 : le salon, la scène de jeu, le titre**

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
## Actions tenues : une action n'agit qu'à l'appui, pas à la répétition du clavier ni tant que le
## stick reste penché (chaque mouvement du stick au-delà de la zone morte est un nouvel événement).
var _tenues: Dictionary[StringName, bool] = {}


func _ready() -> void:
```

par :

```gdscript
## Actions tenues : une action n'agit qu'à l'appui, pas à la répétition du clavier ni tant que le
## stick reste penché (chaque mouvement du stick au-delà de la zone morte est un nouvel événement) ;
## relevées à l'ouverture (phase 18, M3 de la revue finale 13 : un stick déjà penché en arrivant, d'une
## manche ou de l'écran Résultats, n'agit pas une fois de lui-même).
var _tenues: Dictionary[StringName, bool] = {}
## Chez l'hôte, ses adresses (`Decouverte.adresses_hote`), relevées une fois à l'ouverture (phase 18, M4
## de la revue finale 13 : pas à chaque changement du salon).
var _adresses_hote := PackedStringArray()


func _ready() -> void:
```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
	get_tree().paused = false
	Regles.appliquer_ecran(get_tree(), ReglesBataille.TAILLE_ECRAN)
```

par :

```gdscript
	get_tree().paused = false
	for action in ACTIONS:
		_tenues[action] = Input.is_action_pressed(action)
	Regles.appliquer_ecran(get_tree(), ReglesBataille.TAILLE_ECRAN)
```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
		# L'hôte est parti entre l'inscription et l'arrivée ici : son signal n'a trouvé personne.
		_revenir_au_reseau.call_deferred("RESEAU_HOTE_PERDU")
		return
	if multiplayer.is_server():
		Reseau.ouvrir_salon(GameState.niveau_courant)
```

par :

```gdscript
		# L'hôte est parti entre l'inscription et l'arrivée ici : son signal n'a trouvé personne.
		_revenir_au_reseau.call_deferred(Reseau.raison_perte)
		return
	if multiplayer.is_server():
		_adresses_hote = Decouverte.adresses_hote(IP.get_local_interfaces())
		Reseau.ouvrir_salon(GameState.niveau_courant)
```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
func _sur_hote_perdu() -> void:
	_revenir_au_reseau("RESEAU_HOTE_PERDU")


func _sur_langue_changee(_langue: String) -> void:
```

par :

```gdscript
func _sur_hote_perdu() -> void:
	_revenir_au_reseau(Reseau.raison_perte)


func _sur_langue_changee(_langue: String) -> void:
```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
		# Wi-Fi ; l'écran Réseau utilisait la même liste pour l'hébergement, le salon la reprend ici.
		var liste := ", ".join(Decouverte.adresses_hote(IP.get_local_interfaces()))
		adresses.text = tr("SALON_ADRESSES") % (liste if not liste.is_empty() else "?")
```

par :

```gdscript
		# Wi-Fi ; l'écran Réseau utilisait la même liste pour l'hébergement, le salon la reprend ici.
		var liste := ", ".join(_adresses_hote)
		adresses.text = tr("SALON_ADRESSES") % (liste if not liste.is_empty() else "?")
```

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
## Le bouton de l'hôte et la ligne d'état. L'hôte lit ses inscrits (places réservées comprises) et
## voit pourquoi le bouton est grisé ; un client lit la table : pourquoi la partie attend, ou que
## l'hôte peut démarrer.
func _afficher_etat() -> void:
	var hote := multiplayer.is_server()
	var raison := Reseau.raison_attente(Reseau.inscrits.values() if hote else Reseau.table_salon)
	bouton_demarrer.visible = hote
```

par :

```gdscript
## Le bouton de l'hôte et la ligne d'état. L'hôte lit ses inscrits (places réservées comprises) et
## voit pourquoi le bouton est grisé ; un client lit la table et les places réservées que l'hôte annonce
## (`Reseau.fiches_attente`) : pourquoi la partie attend, ou que l'hôte peut démarrer.
func _afficher_etat() -> void:
	var hote := multiplayer.is_server()
	var raison := Reseau.raison_attente(Reseau.fiches_attente())
	bouton_demarrer.visible = hote
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
## L'hôte est parti, vu d'un client, ou son propre pair ENet en erreur chez l'hôte lui-même (M2 de
## la revue finale) : ce poste est déjà hors réseau. Tout se fige sous le message, puis retour au
## titre (spec §9).
func _sur_hote_perdu() -> void:
	# M1 (revue finale) : ce poste est déjà hors réseau (`Reseau.en_ligne()` est faux) ; sans ceci,
```

par :

```gdscript
## L'hôte est parti, vu d'un client, ou son propre pair ENet en erreur chez l'hôte lui-même (M2 de
## la revue finale) : ce poste est déjà hors réseau. Tout se fige sous le message (« L'hôte a quitté la
## partie », ou l'exclusion de ce poste par la barrière de chargement : `Reseau.raison_perte`, phase 18),
## puis retour au titre (spec §9).
func _sur_hote_perdu() -> void:
	# M5 (revue finale phase 17) : l'arbre se fige avant qu'aucun lion n'arrête la boucle du vomi d'un
	# joueur qui tenait Espace ; elle continuerait sur le titre.
	Audio.arreter_vomi()
	# M1 (revue finale) : ce poste est déjà hors réseau (`Reseau.en_ligne()` est faux) ; sans ceci,
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
	message.name = "Message"
	message.text = "RESEAU_HOTE_PERDU"
	message.add_theme_font_size_override("font_size", 56)
```

par :

```gdscript
	message.name = "Message"
	message.text = Reseau.raison_perte
	message.add_theme_font_size_override("font_size", 56)
```

Dans `Scripts/Titre.gd`, remplacer :

```gdscript
	Reseau.quitter()
	# L'écran titre est celui du solo : Jouer, la démo et l'arcade y lancent des parties solo, dont
```

par :

```gdscript
	Reseau.quitter()
	Audio.arreter_vomi()  # filet (M5, revue finale phase 17) : aucune boucle de vomi ne survit à une partie
	# L'écran titre est celui du solo : Jouer, la démo et l'arcade y lancent des parties solo, dont
```

Dans `Assets/Traductions/traductions.csv`, remplacer :

```csv
RESEAU_HOTE_PERDU,L'hôte a quitté la partie,The host left the game
RESEAU_PORT_OCCUPE,Impossible d'héberger : port %d occupé,Can't host: port %d in use
```

par :

```csv
RESEAU_HOTE_PERDU,L'hôte a quitté la partie,The host left the game
RESEAU_EXCLU,"Exclu : ta partie a mis trop de temps à charger.","Removed: your game took too long to load."
RESEAU_PORT_OCCUPE,Impossible d'héberger : port %d occupé,Can't host: port %d in use
```

Puis `godot --headless --import . > /dev/null 2>&1`.

- [ ] **Step 5 : les voir passer**

Run : unitaires, smoke, bataille, banc, la trace, puis le test réseau.
Expected : `== 0 échec(s) ==` partout, dont au smoke « M3 : … », « M4 : … », « phase 18 : la table part avec le nombre de places seulement réservées (1) », « … (un joueur pas prêt ; M2 : un joueur qui arrive), puis « l'hôte peut démarrer » », « … la boucle du vomi s'arrête », « chez un exclu, le message dit qu'il a été exclu… » ; au test réseau, le muet du scénario 9 : « phase 18 : l'exclu l'apprend de l'hôte avant d'être déconnecté (RESEAU_EXCLU…) », et le scénario 10 toujours sous 2000 ms (`(I1) écart exclusion -> barrière`).

Contre-épreuves (sans les committer ; aucune ne touche `Scripts/Reseau.gd`) : dans `Scripts/Salon.gd`, remplacer les deux lignes `for action in ACTIONS:` / `_tenues[action] = Input.is_action_pressed(action)` de `_ready` par `pass` : `❌ M3 : …` ; remplacer `", ".join(_adresses_hote)` par `", ".join(Decouverte.adresses_hote(IP.get_local_interfaces()))` : `❌ M4 : …` ; dans `Scripts/Main.gd`, retirer `Audio.arreter_vomi()` de `_sur_hote_perdu` : `❌ l'hôte perdu : … la boucle du vomi s'arrête` ; `git checkout -- Scripts/Salon.gd Scripts/Main.gd` après chacune.

- [ ] **Step 6 : commit**

```bash
git add Scripts/Reseau.gd Scripts/Manche.gd Scripts/Salon.gd Scripts/Main.gd Scripts/Titre.gd Assets/Traductions/traductions.csv Assets/Traductions/traductions.en.translation Assets/Traductions/traductions.fr.translation tests/unitaires.gd tests/smoke_test.gd tests/reseau/joueur.gd
git commit -m "Restes des revues pour le retour au salon et les départs : les places réservées partent avec la table (un client ne lit plus « l'hôte peut démarrer » pendant une arrivée), un stick penché à l'ouverture du salon n'y agit pas, les adresses de l'hôte relevées une fois ; l'exclu de la barrière apprend son exclusion ; la boucle du vomi s'arrête quand l'hôte disparaît

<ligne fournie par l'environnement>"
```

---

### Task 7 : le scénario 13 étendu : Résultats identiques, revanche, départ sur l'écran Résultats, retour au salon (`tests/reseau`)

**Files:**
- Modify: `tests/reseau/joueur.gd` (en-tête des rôles « chrono », `_jouer_chrono`, `_jouer_au_chrono` (qui remplace `_finir_au_chrono`), `_pousser` ➕, `_choisir_au_clavier` ➕, `_enchainer` ➕), `tests/reseau/lancer.sh` (en-tête, scénario 13)

**Interfaces:**
- Consumes (Tasks 3 à 6) : `Manche.bilan`, `Resultats.resume`, `hote`, `etat`, `bouton_revanche`, `bouton_salon`, `animation_finie`, `_depuis_animation`, `DELAI_CHOIX`, `selection`, `choix_fait`, `partis`, `lignes`, `possible` ; `Main.resultats` ; `Reseau.table_salon`, `manche_en_cours` ; `Salon.retour`.
- Produces : les lignes de journal du scénario 13 : `FIN …` et `FIN2 …` (HUD, bilan, lions affichés), `RESULTATS FIN …` et `RESULTATS FIN2 …` (l'écran Résultats), `ECART_CHRONO FIN <s>` et `ECART_CHRONO FIN2 <s>` (clients), `QUITTE` (Bruno), `DEPART VU` (l'hôte et Anna), `SALON <table>` (l'hôte et Anna) ; options `--duree-revanche=S`, `--revanche=chemin`, `--salon=chemin` (l'hôte), `--quitte=chemin` (le client qui quitte).

Le scénario, chorégraphié par lancer.sh sur des lignes de journal (jamais une attente à l'aveugle) : la manche de 10 s, chacun peignant sans lâcher ses touches jusqu'au gong ; « RESULTATS FIN » sur les trois postes → `revanche13` : l'hôte choisit Revanche au clavier (vomir, une fois les choix ouverts) ; chaque poste recharge la scène de jeu (vérifié : le même niveau, les mêmes joueurs, ni cellule, ni bilan, le chrono à 0:06) ; la revanche de 6 s ; « RESULTATS FIN2 » sur les trois → `quitte13` : Bruno quitte par Échap (le titre) ; « DEPART VU » chez l'hôte et Anna → `salon13` : l'hôte choisit Retour au salon (droite, droite, vomir) ; « SALON » chez les deux → `rester13` : l'hôte quitte le salon (l'écran Réseau), Anna voit « L'hôte a quitté la partie » ; chacun finit au titre, hors réseau.

- [ ] **Step 1 : les postes**

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
##   rarement au-delà de 16 px, sous 4 px 150 ms après l'arrêt ; puis sa propre « EMPREINTE ».
## Fin de manche au chrono (phase 17), par les vraies scènes : 1 hôte + 2 clients (derrière le relais),
##   une manche courte de --duree-manche=S secondes (`ReglesBataille.duree_manche`, sur chaque poste),
##   sur le niveau --niveau=L choisi par l'hôte. Chaque poste fait sa passe de peinture (--sens), puis
##   attend la fin : chez l'hôte par son chrono, chez un client par la fin reçue de l'hôte (son chrono
##   pris sur celui de l'hôte : « ECART_CHRONO <s> », l'écart qu'il avait) ; tout se fige sur le panneau
##   de fin, 0:00, les tics des dernières secondes comptés ; « FIN <HUD> » (chrono, pseudos, parts,
##   rangs : la même ligne sur chaque poste).
##   Chrono-hôte : --clients=N, --niveau=L, --duree-manche=S, --rester=chemin (« HOTE RESTE », puis,
##   ce fichier créé, sort par Échap : le titre, hors réseau).
##   Chrono-client : --sens=1|-1, --duree-manche=S ; attend le départ de l'hôte (« L'hôte a quitté la
##   partie » à la place du panneau de fin, puis le titre).
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
```

par :

```gdscript
##   rarement au-delà de 16 px, sous 4 px 150 ms après l'arrêt ; puis sa propre « EMPREINTE ».
## Fin de manche au chrono (phase 17), résultats, revanche et retour au salon (phase 18), par les vraies
##   scènes : 1 hôte + 2 clients (derrière le relais), une manche courte de --duree-manche=S secondes
##   (`ReglesBataille.duree_manche`, sur chaque poste), sur le niveau --niveau=L choisi par l'hôte. Chaque
##   poste peint (--sens) sans lâcher ses touches jusqu'à la fin : chez l'hôte par son chrono, chez un
##   client par la fin reçue de l'hôte (son chrono pris sur celui de l'hôte : « ECART_CHRONO FIN <s> »,
##   l'écart qu'il avait) ; tout se fige, 0:00, les tics des dernières secondes comptés, l'écran
##   Résultats à la place du HUD ; « FIN <HUD, bilan, lions affichés> » et « RESULTATS FIN <écran> » (les
##   mêmes lignes sur chaque poste : les lions, lancés au gong, posés sur l'état final de l'hôte). Puis
##   l'hôte choisit Revanche au clavier : chaque poste recharge la scène de jeu (le même niveau, une manche
##   neuve de --duree-revanche=S secondes), qui finit de même (« FIN2 », « RESULTATS FIN2 ») ; le client
##   --quitte quitte l'écran Résultats par Échap (« QUITTE », le titre) ; les autres le voient partir
##   (« DEPART VU ») ; l'hôte choisit Retour au salon : chacun y revient, la même table sans le partant,
##   personne prêt (« SALON <table> », la même ligne) ; puis l'hôte quitte le salon et l'autre client
##   revient à l'écran Réseau, « L'hôte a quitté la partie ».
##   Chrono-hôte : --clients=N, --niveau=L, --duree-manche=S, --duree-revanche=S, --revanche=chemin
##   (choisit Revanche une fois ce fichier créé par lancer.sh), --salon=chemin (Retour au salon, de même),
##   --rester=chemin (quitte le salon, de même).
##   Chrono-client : --sens=1|-1, --duree-manche=S, --duree-revanche=S, --quitte=chemin (quitte le second
##   écran Résultats une fois ce fichier créé).
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	await _finir_manche_client(main, manche)


## Rôles « chrono-hote » et « chrono-client » (phase 17, voir l'en-tête) : une manche courte que le
## chrono de l'hôte termine ; chaque poste la voit finir sur le même HUD, puis l'hôte sort par Échap et
## ses clients le voient partir.
func _jouer_chrono(hote: bool) -> void:
```

par :

```gdscript
	await _finir_manche_client(main, manche)


## Rôles « chrono-hote » et « chrono-client » (phases 17 et 18, voir l'en-tête) : une manche courte que
## le chrono de l'hôte termine, le même écran Résultats partout ; l'hôte choisit Revanche, une seconde
## manche, plus courte, finit de même ; un client (--quitte) quitte alors l'écran Résultats, les autres le
## voient partir ; l'hôte ramène l'autre client au salon, la même table, puis s'en va.
func _jouer_chrono(hote: bool) -> void:
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	var main := await _rejoindre_la_manche(hote)
	if main != null:
		await _finir_au_chrono(main, hote, duree)
	script_regles.duree_manche = ReglesBataille.DUREE_MANCHE
	_effacer_scores()


func _finir_au_chrono(main: Node, hote: bool, duree: float) -> void:
	var gs: Node = root.get_node("GameState")
	var manche: Node = main.get_node("Manche")
	var hud: CanvasLayer = main.hud_bataille
	_check(await _attendre(func() -> bool: return manche.barriere), "la barrière de chargement passe")
	_check(await _attendre(func() -> bool: return gs.pret), "l'intro se termine chez tous")
	print("INTRO")
	_check(hud != null and hud.vignettes.size() == gs.joueurs.size() and gs.joueurs.size() == 3
		and hud.vignettes[gs.joueur_local().index].badge.text == "TOI",
		"le HUD de la bataille : une vignette par joueur (1 hôte et 2 clients), « TOI » sur celle de ce poste")
	_check(await _peindre_jusquau_gong(main, int(_option("sens", "1")), gs, duree + 10.0),
		"la manche se termine (peinte sans s'arrêter jusqu'au gong, I2 : des tampons et une case de territoire en vol quand la fin part)")
	if hote:
		_check(manche.finie and gs.temps_ecoule >= duree and gs.temps_ecoule < duree + 0.1,
			"le chrono de l'hôte termine la manche à %.0f s (%.3f s)" % [duree, gs.temps_ecoule])
	else:
		print("ECART_CHRONO %.3f" % manche.ecart_chrono_fin)
		_check(manche.finie and absf(manche.ecart_chrono_fin) <= ECART_CHRONO and gs.temps_ecoule >= duree and gs.temps_ecoule < duree + 0.1,
			"la fin de l'hôte termine la manche de ce client, son chrono pris sur celui de l'hôte (%.3f s, écart %.3f s)" % [gs.temps_ecoule, manche.ecart_chrono_fin])
	var tics_attendus := mini(ReglesBataille.SECONDES_TIC, ceili(duree) - 1)
	_check(await _attendre(func() -> bool: return main.resultats != null) and paused and main.resultats.visible and not hud.visible
		and hud.chrono.text == "0:00" and hud.tics_joues == tics_attendus,
		"tout se fige, l'écran Résultats à la place du HUD (le chrono à 0:00, %d tics sur %d attendus)" % [hud.tics_joues, tics_attendus])
	print("FIN %s bilan=%s lions=%s" % [hud.resume(), manche.bilan.resume() if manche.bilan != null else "", _lions_affiches(main)])
	if hote:
		var rester := _option("rester", "")
		print("HOTE RESTE")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
		var echap := InputEventAction.new()
		echap.action = &"ui_cancel"
		echap.pressed = true
		root.push_input(echap)
		_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not paused and not reseau.en_ligne(),
			"Échap, sur l'écran Résultats : l'hôte revient au titre, hors réseau")
	else:
		_check(await _attendre(func() -> bool: return _issue == "hote_perdu"), "l'hôte finit par partir")
		_check(main.get_node_or_null("HotePerdu/Message") != null and not main.resultats.visible,
			"« L'hôte a quitté la partie » à la place de l'écran Résultats")
		_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not paused and not reseau.en_ligne(),
			"puis retour au titre, hors réseau")


## Les lions de ce poste tels qu'ils s'affichent (le corps et le décalage de la prédiction), en une ligne
```

par :

```gdscript
	var main := await _rejoindre_la_manche(hote)
	if main != null and await _jouer_au_chrono(main, hote, duree, "FIN"):
		await _enchainer(main, hote, script_regles)
	script_regles.duree_manche = ReglesBataille.DUREE_MANCHE
	_effacer_scores()


## Une manche au chrono, de la barrière à l'écran Résultats : écrit « <etiquette> <HUD, bilan, lions> »
## et « RESULTATS <etiquette> <écran Résultats> » (les mêmes lignes sur chaque poste). Vrai si l'écran
## Résultats est là.
func _jouer_au_chrono(main: Node, hote: bool, duree: float, etiquette: String) -> bool:
	var gs: Node = root.get_node("GameState")
	var manche: Node = main.get_node("Manche")
	var hud: CanvasLayer = main.hud_bataille
	_check(await _attendre(func() -> bool: return manche.barriere), "(%s) la barrière de chargement passe" % etiquette)
	_check(await _attendre(func() -> bool: return gs.pret), "(%s) l'intro se termine chez tous" % etiquette)
	print("INTRO")
	_check(hud != null and hud.vignettes.size() == gs.joueurs.size() and gs.joueurs.size() == 3
		and hud.vignettes[gs.joueur_local().index].badge.text == "TOI",
		"(%s) le HUD de la bataille : une vignette par joueur (1 hôte et 2 clients), « TOI » sur celle de ce poste" % etiquette)
	_check(await _peindre_jusquau_gong(main, int(_option("sens", "1")), gs, duree + 10.0),
		"(%s) la manche se termine (peinte sans s'arrêter jusqu'au gong, I2 : des tampons et une case de territoire en vol quand la fin part)" % etiquette)
	if hote:
		_check(manche.finie and gs.temps_ecoule >= duree and gs.temps_ecoule < duree + 0.1,
			"(%s) le chrono de l'hôte termine la manche à %.0f s (%.3f s)" % [etiquette, duree, gs.temps_ecoule])
	else:
		print("ECART_CHRONO %s %.3f" % [etiquette, manche.ecart_chrono_fin])
		_check(manche.finie and absf(manche.ecart_chrono_fin) <= ECART_CHRONO and gs.temps_ecoule >= duree and gs.temps_ecoule < duree + 0.1,
			"(%s) la fin de l'hôte termine la manche de ce client, son chrono pris sur celui de l'hôte (%.3f s, écart %.3f s)"
				% [etiquette, gs.temps_ecoule, manche.ecart_chrono_fin])
	var tics_attendus := mini(ReglesBataille.SECONDES_TIC, ceili(duree) - 1)
	var resultats_la := await _attendre(func() -> bool: return main.resultats != null)
	_check(resultats_la and paused and main.resultats.visible and not hud.visible and hud.chrono.text == "0:00" and hud.tics_joues == tics_attendus,
		"(%s) tout se fige, l'écran Résultats à la place du HUD (le chrono à 0:00, %d tics sur %d attendus)" % [etiquette, hud.tics_joues, tics_attendus])
	print("%s %s bilan=%s lions=%s" % [etiquette, hud.resume(), manche.bilan.resume() if manche.bilan != null else "", _lions_affiches(main)])
	if resultats_la:
		_check(main.resultats.hote == hote and main.resultats.bouton_revanche.visible == hote and main.resultats.bouton_salon.visible == hote
			and (hote or main.resultats.etat.text == tr("RESULTATS_ATTENTE_HOTE")),
			"(%s) l'hôte choisit (Revanche, Niveau suivant, Retour au salon) ; un client voit « En attente de l'hôte… »" % etiquette)
		print("RESULTATS %s %s" % [etiquette, main.resultats.resume()])
	return resultats_la


## Un appui (ou un relâchement) de `action`, comme le clavier ou la manette l'envoient au jeu.
func _pousser(action: StringName, appuye: bool) -> void:
	var evenement := InputEventAction.new()
	evenement.action = action
	evenement.pressed = appuye
	root.push_input(evenement)
	await process_frame


## L'hôte choisit `choix` sur son écran Résultats au clavier, comme un joueur : droite jusqu'au bouton,
## puis vomir (une fois l'animation finie et le délai des choix passé ; vomir relâché d'abord : il était
## tenu au gong).
func _choisir_au_clavier(resultats: CanvasLayer, choix: StringName) -> void:
	_check(await _attendre(func() -> bool: return resultats.animation_finie and resultats._depuis_animation >= resultats.DELAI_CHOIX),
		"l'animation de l'écran Résultats finie, les choix sont ouverts")
	var essais := 0
	while resultats.selection != choix and essais < 4:
		await _pousser(&"deplacer_droite", true)
		await _pousser(&"deplacer_droite", false)
		essais += 1
	var choisi := [&""]  # l'écran Résultats s'en va avec la scène dès le choix suivi
	resultats.choix_fait.connect(func(c: StringName) -> void: choisi[0] = c)
	await _pousser(&"vomir", false)
	await _pousser(&"vomir", true)
	await _pousser(&"vomir", false)
	_check(choisi[0] == choix, "l'hôte choisit « %s » au clavier (%s)" % [choix, choisi[0]])


## La suite du scénario 13 (phase 18) : Revanche, une seconde manche, un client qui quitte l'écran
## Résultats, le retour au salon, puis le départ de l'hôte.
func _enchainer(premiere: Node, hote: bool, script_regles: Script) -> void:
	var gs: Node = root.get_node("GameState")
	var niveau: int = gs.niveau_courant
	var duree := float(_option("duree-revanche", "6"))
	script_regles.duree_manche = duree  # la seconde manche, sur chaque poste
	var id_premiere := premiere.get_instance_id()
	if hote:
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("revanche", ""))), "chaque poste a son écran Résultats")
		await _choisir_au_clavier(premiere.resultats, &"revanche")
	var nouvelle := func() -> bool:
		return current_scene != null and current_scene.get_instance_id() != id_premiere and _scene_est("Main") and current_scene.is_node_ready()
	_check(await _attendre(nouvelle), "Revanche : la scène de jeu se recharge sur chaque poste")
	if not nouvelle.call():
		reseau.quitter()
		return
	var main: Node = current_scene
	var territoire: Territoire = main.get_node("Ville").territoire
	_check(not paused and gs.niveau_courant == niveau and gs.joueurs.size() == 3 and reseau.manche_en_cours and main.resultats == null
		and range(3).all(func(i: int) -> bool: return territoire.cellules_de(i) == 0)
		and main.hud_bataille.chrono.text == EtatPartie.formater_temps(duree) and main.get_node("Manche").bilan == null,
		"une manche neuve, le même niveau, les mêmes joueurs : ni pause, ni cellule, ni bilan, le chrono à %s" % EtatPartie.formater_temps(duree))
	if not await _jouer_au_chrono(main, hote, duree, "FIN2"):
		reseau.quitter()
		return
	var resultats: CanvasLayer = main.resultats
	if _options.has("quitte"):
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("quitte", ""))), "chaque poste a son second écran Résultats")
		await _pousser(&"ui_cancel", true)
		await _pousser(&"ui_cancel", false)
		_check(await _attendre(func() -> bool: return _scene_est("Titre")) and not reseau.en_ligne(), "Quitter (Échap) sur l'écran Résultats : le titre, hors réseau")
		print("QUITTE")
		return
	var partant := -1
	for j: Joueur in gs.joueurs:
		if j.pseudo == "Bruno":
			partant = j.index
	_check(partant >= 0 and await _attendre(func() -> bool: return resultats.partis[partant]),
		"Bruno quitte l'écran Résultats : chaque poste resté le voit partir")
	_check(resultats.lignes.any(func(l: Dictionary) -> bool: return l.index == partant and l.badge.text.contains(tr("BATAILLE_PARTI")))
		and (not hote or resultats.possible(&"revanche")),
		"sa ligne se grise ; à deux, l'hôte peut encore relancer")
	print("DEPART VU")
	if hote:
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("salon", ""))), "l'autre client a vu partir Bruno")
		await _choisir_au_clavier(resultats, &"salon")
	_check(await _attendre(func() -> bool: return _scene_est("Salon") and current_scene.is_node_ready()), "Retour au salon : chaque poste resté revient au salon")
	if not _scene_est("Salon"):
		reseau.quitter()
		return
	var salon: Node = current_scene
	_check(await _attendre(func() -> bool: return reseau.table_salon.size() == 2 and reseau.table_salon.all(func(f: Dictionary) -> bool: return not f.pret))
		and not reseau.manche_en_cours and not paused,
		"le salon : la même table sans Bruno, personne prêt, plus de manche en cours")
	print("SALON %s" % ";".join(reseau.table_salon.map(func(f: Dictionary) -> String: return "%d:%d:%s:%s" % [f.id, f.index, f.pseudo, f.pret])))
	if hote:
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(_option("rester", ""))), "lancer.sh laisse partir l'hôte")
		salon.retour()
		_check(await _attendre(func() -> bool: return _scene_est("EcranReseau")) and not reseau.en_ligne(), "l'hôte quitte le salon : l'écran Réseau, hors réseau")
	else:
		_check(await _attendre(func() -> bool: return _scene_est("EcranReseau")) and not reseau.en_ligne()
			and current_scene.message.text == tr("RESEAU_HOTE_PERDU"),
			"l'hôte parti du salon : l'écran Réseau, « L'hôte a quitté la partie »")
	change_scene_to_file("res://Scenes/Titre.tscn")  # l'écran Réseau écoute les balises : le titre, non
	_check(await _attendre(func() -> bool: return _scene_est("Titre")), "puis le titre")


## Les lions de ce poste tels qu'ils s'affichent (le corps et le décalage de la prédiction), en une ligne
```

- [ ] **Step 2 : le lanceur**

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
# manche synchronisée (phase 14), de bout en bout (phase 15), de la prédiction sous latence
# simulée (phase 16) et de la fin de manche au chrono (phase 17) : des postes headless sur localhost,
# un processus Godot par poste (tests/reseau/joueur.gd), et pour les scénarios 12 et 13 le simulateur de
```

par :

```bash
# manche synchronisée (phase 14), de bout en bout (phase 15), de la prédiction sous latence
# simulée (phase 16), de la fin de manche au chrono (phase 17) et des manches enchaînées depuis l'écran
# Résultats (phase 18) : des postes headless sur localhost,
# un processus Godot par poste (tests/reseau/joueur.gd), et pour les scénarios 12 et 13 le simulateur de
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40 ; les
# scénarios 11, 12 et 13, des manches jouées, ont le leur : DUREE11 + 60, DUREE12 + 50, DUREE13 + 50),
# DIFFUSION=1 (ajoute le scénario 7, balises en vraie diffusion : hors CI, où la diffusion n'a pas
```

par :

```bash
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40 ; les
# scénarios 11, 12 et 13, des manches jouées, ont le leur : DUREE11 + 60, DUREE12 + 50, DUREE13 +
# DUREE13B + 60),
# DIFFUSION=1 (ajoute le scénario 7, balises en vraie diffusion : hors CI, où la diffusion n'a pas
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
grep -hE "^PREDICTION |^COMMANDES |^RELAIS datagrammes" "$JOURNAUX/a12.log" "$JOURNAUX/b12.log" "$JOURNAUX/hote12.log" "$JOURNAUX/relais12.log" 2>/dev/null | sed 's/^/  (latence) /'

# 13. Fin de manche au chrono (phase 17), par les vraies scènes : un hôte et deux clients, les clients
#     derrière le relais (80 ms d'aller-retour, 40 ms de gigue, 5 % de pertes), jouent une manche courte
#     (DUREE13 s, `ReglesBataille.duree_manche` sur chaque poste) que seul le chrono de l'hôte termine :
#     chaque client reçoit sa fin (son chrono pris sur celui de l'hôte, « ECART_CHRONO », au plus 0,25 s),
#     tout se fige chez tous sur le même HUD (chrono à 0:00, parts, rangs : les lignes « FIN »
#     identiques), les tics des dernières secondes comptés sur chaque poste ; puis l'hôte sort par Échap
#     (le titre) et ses clients le voient partir, puis le relais s'arrête.
DUREE13=10
P=$((PORT_BASE + 13))
B=$((PORT_BASE + 1013))
R=$((PORT_BASE + 2013))
DELAI_AVANT13=$DELAI
DELAI=$((DUREE13 + 50))
lancer_relais relais13 --ecoute=$R --vers=$P --latence=80 --gigue=40 --pertes=5 --graine=13 --fin="$JOURNAUX/fin13"
lancer hote13 --role=chrono-hote --port=$P --port-balise=$B --pseudo=Hote13 --clients=2 --niveau=0 --duree-manche=$DUREE13 \
	--rester="$JOURNAUX/rester13"
if attendre_ligne relais13 "RELAIS PRET" && attendre_hote hote13; then
	lancer a13 --role=chrono-client --port=$R --port-balise=$B --pseudo=Anna --sens=1 --duree-manche=$DUREE13
	lancer b13 --role=chrono-client --port=$R --port-balise=$B --pseudo=Bruno --sens=-1 --duree-manche=$DUREE13
	attendre_ligne hote13 "^FIN " $((DUREE13 + 40)) && attendre_ligne a13 "^FIN " && attendre_ligne b13 "^FIN "
	touch "$JOURNAUX/rester13"
	attendre_fin hote13
	attendre_fin a13
	attendre_fin b13
fi
touch "$JOURNAUX/rester13" "$JOURNAUX/fin13"
terminer "fin de manche au chrono de l'hôte sous latence simulée : chaque client la reçoit, le même HUD figé partout (chrono, parts, rangs, tics), puis l'hôte sort par Échap"
DELAI=$DELAI_AVANT13
[ "$(for nom in hote13 a13 b13; do grep -h "^FIN " "$JOURNAUX/$nom.log"; done 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
	&& [ "$(compter "^FIN " hote13 a13 b13)" -eq 3 ] || echec "fin au chrono : l'hôte et les deux clients doivent finir sur le même HUD"
grep -hE "^FIN |^ECART_CHRONO" "$JOURNAUX/hote13.log" "$JOURNAUX/a13.log" "$JOURNAUX/b13.log" 2>/dev/null | sed 's/^/  (chrono) /'

echo "== $ECHECS échec(s) =="
```

par :

```bash
grep -hE "^PREDICTION |^COMMANDES |^RELAIS datagrammes" "$JOURNAUX/a12.log" "$JOURNAUX/b12.log" "$JOURNAUX/hote12.log" "$JOURNAUX/relais12.log" 2>/dev/null | sed 's/^/  (latence) /'

# 13. Fin de manche au chrono (phase 17), résultats, revanche et retour au salon (phase 18), par les
#     vraies scènes : un hôte et deux clients, les clients derrière le relais (80 ms d'aller-retour, 40 ms
#     de gigue, 5 % de pertes), jouent une manche courte (DUREE13 s, `ReglesBataille.duree_manche` sur
#     chaque poste) que seul le chrono de l'hôte termine, chacun peignant sans lâcher ses touches jusqu'au
#     gong : chaque client reçoit sa fin (son chrono pris sur celui de l'hôte, « ECART_CHRONO »), tout se
#     fige chez tous sur le même HUD, le même bilan et les mêmes lions (posés sur l'état final de l'hôte :
#     les lignes « FIN » identiques), puis le même écran Résultats (« RESULTATS FIN »). L'hôte choisit
#     Revanche : chaque poste recharge la scène de jeu, une manche neuve de DUREE13B s, qui finit de même
#     (« FIN2 », « RESULTATS FIN2 »). Bruno quitte alors l'écran Résultats (le titre) ; l'hôte et Anna le
#     voient partir ; l'hôte choisit Retour au salon : tous deux y reviennent, la même table sans Bruno,
#     personne prêt (« SALON », la même ligne) ; l'hôte quitte le salon, Anna le voit partir, puis le
#     relais s'arrête.
DUREE13=10
DUREE13B=6
P=$((PORT_BASE + 13))
B=$((PORT_BASE + 1013))
R=$((PORT_BASE + 2013))
DELAI_AVANT13=$DELAI
DELAI=$((DUREE13 + DUREE13B + 60))
lancer_relais relais13 --ecoute=$R --vers=$P --latence=80 --gigue=40 --pertes=5 --graine=13 --fin="$JOURNAUX/fin13"
lancer hote13 --role=chrono-hote --port=$P --port-balise=$B --pseudo=Hote13 --clients=2 --niveau=0 --duree-manche=$DUREE13 \
	--duree-revanche=$DUREE13B --revanche="$JOURNAUX/revanche13" --salon="$JOURNAUX/salon13" --rester="$JOURNAUX/rester13"
if attendre_ligne relais13 "RELAIS PRET" && attendre_hote hote13; then
	lancer a13 --role=chrono-client --port=$R --port-balise=$B --pseudo=Anna --sens=1 --duree-manche=$DUREE13 --duree-revanche=$DUREE13B
	lancer b13 --role=chrono-client --port=$R --port-balise=$B --pseudo=Bruno --sens=-1 --duree-manche=$DUREE13 --duree-revanche=$DUREE13B \
		--quitte="$JOURNAUX/quitte13"
	if attendre_ligne hote13 "^RESULTATS FIN " $((DUREE13 + 40)) && attendre_ligne a13 "^RESULTATS FIN " && attendre_ligne b13 "^RESULTATS FIN "; then
		touch "$JOURNAUX/revanche13"
		if attendre_ligne hote13 "^RESULTATS FIN2 " $((DUREE13B + 30)) && attendre_ligne a13 "^RESULTATS FIN2 " && attendre_ligne b13 "^RESULTATS FIN2 "; then
			touch "$JOURNAUX/quitte13"
			if attendre_ligne hote13 "DEPART VU" && attendre_ligne a13 "DEPART VU"; then
				touch "$JOURNAUX/salon13"
				attendre_ligne hote13 "^SALON " && attendre_ligne a13 "^SALON "
			fi
		fi
	fi
	touch "$JOURNAUX/revanche13" "$JOURNAUX/quitte13" "$JOURNAUX/salon13" "$JOURNAUX/rester13"
	attendre_fin hote13
	attendre_fin a13
	attendre_fin b13
fi
touch "$JOURNAUX/revanche13" "$JOURNAUX/quitte13" "$JOURNAUX/salon13" "$JOURNAUX/rester13" "$JOURNAUX/fin13"
terminer "fin de manche au chrono sous latence simulée, résultats, revanche et retour au salon : chaque client reçoit la fin et le bilan de l'hôte, le même écran Résultats partout, une revanche relancée par l'hôte, un client qui quitte l'écran Résultats vu parti, le retour au salon sur la même table"
DELAI=$DELAI_AVANT13
for ligne in "^FIN " "^RESULTATS FIN " "^FIN2 " "^RESULTATS FIN2 "; do
	[ "$(for nom in hote13 a13 b13; do grep -h "$ligne" "$JOURNAUX/$nom.log"; done 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
		&& [ "$(compter "$ligne" hote13 a13 b13)" -eq 3 ] || echec "fin au chrono : l'hôte et les deux clients doivent avoir la même ligne « $ligne» (HUD, bilan, lions, écran Résultats)"
done
[ "$(for nom in hote13 a13; do grep -h "^SALON " "$JOURNAUX/$nom.log"; done 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
	&& [ "$(compter "^SALON " hote13 a13)" -eq 2 ] && [ "$(compter "^QUITTE" b13)" -eq 1 ] \
	|| echec "retour au salon : l'hôte et Anna doivent revenir au salon sur la même table, Bruno être parti"
grep -hE "^FIN |^FIN2 |^RESULTATS |^ECART_CHRONO|^SALON " "$JOURNAUX/hote13.log" "$JOURNAUX/a13.log" "$JOURNAUX/b13.log" 2>/dev/null | sed 's/^/  (chrono) /'

echo "== $ECHECS échec(s) =="
```

- [ ] **Step 3 : le voir passer, et le temps de la CI**

Run : le test réseau (commande des Global Constraints), en notant sa durée (`time`).
Expected : `== 0 échec(s) ==` ; `✅ fin de manche au chrono sous latence simulée, résultats, revanche et retour au salon : …` ; les lignes `(chrono)` : trois `FIN` identiques, trois `RESULTATS FIN` identiques, trois `FIN2`, trois `RESULTATS FIN2`, deux `SALON` identiques (par exemple `SALON 1:0:Hote13:false;<id d'Anna>:2:Anna:false` : Anna garde l'index 2, Bruno parti ; les index ne se recompactent qu'au lancement suivant), et quatre `ECART_CHRONO`. Temps mesuré sur le Mac de préparation : scénario 13, 17 s → 28 s ; test réseau, 158 s → 169 à 180 s (dix passages, bash 5 et 3.2), sous le `timeout 300` du pas « Test réseau » de `ci.yml` (inchangé) ; au-delà de ~200 s, raccourcir un scénario (feuille de route).

- [ ] **Step 4 : commit**

```bash
git add tests/reseau/joueur.gd tests/reseau/lancer.sh
git commit -m "Test réseau : le scénario 13 continue par l'écran Résultats (le même sur les trois postes, lions posés sur l'état final de l'hôte alors que chacun peignait au gong), une revanche choisie au clavier par l'hôte (chaque poste recharge une manche neuve de 6 s), un client qui quitte l'écran Résultats (vu parti par les autres) et le retour au salon sur la même table, personne prêt

<ligne fournie par l'environnement>"
```

---

### Task 8 : ◉ résultats (captures)

**Files:**
- Aucun fichier du dépôt : un script jetable, **hors du dépôt** (`$TMPDIR/captures_resultats.gd`), jamais commité ; les captures dans `$TMPDIR/captures-18/`.

**Interfaces:**
- Consumes (Tasks 3 à 5) : `Main.resultats`, `Main.hud_bataille.marquer_parti`, `Main.ville.territoire`, `Resultats.afficher`, `terminer_animation`, `marquer_parti`, `_deplacer_selection`, `bilan` ; `Territoire.appliquer_changements`.

Le script joue, avec le vrai rendu (pas headless), une bataille locale à 6 (ce poste est l'hôte, le joueur 1 est « TOI ») sur la Métropole, ennemis et pastilles écartés, les parts de la ville (par le chemin d'un client), les statistiques et un départ posés à la main, jusqu'au gong ; puis la même fin vue d'un client en réseau, de l'hôte en réseau (Niveau suivant sélectionné), de l'hôte resté seul, et une égalité à 2 en anglais sur le Village.

- [ ] **Step 1 : le script**

Créer `$TMPDIR/captures_resultats.gd` (hors du dépôt) :

```gdscript
extends SceneTree
## ◉ Résultats (phase 18, jetable, jamais commité) :
##   godot --path <dépôt> --rendering-driver opengl3 --script <ce fichier> -- --dossier=<dossier>
## Rendu réel (pas headless) : une bataille locale à 6 (ce poste est l'hôte, le joueur 1 est « TOI »),
## les ennemis écartés, les parts de la ville, les statistiques et un départ posés à la main, jusqu'au
## gong ; puis la même fin vue d'un client en réseau, une égalité à 2 en anglais (l'hôte en réseau), et
## l'hôte resté seul (Revanche grisée).

## Chargée à l'exécution : un script `--script` est compilé avant les autoloads, que nomme l'écran Résultats.
var scene_resultats: PackedScene

var dossier := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dossier="):
			dossier = arg.trim_prefix("--dossier=")
	call_deferred("_run")


func _attendre(secondes: float) -> void:
	await create_timer(secondes, true).timeout


func _shot(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var chemin := dossier.path_join(nom + ".png")
	image.save_png(chemin)
	print("📸 %s (%dx%d)" % [chemin, image.get_width(), image.get_height()])


## Donne à chaque joueur `parts[i]` cellules peignables de la ville (comptées), par le même chemin
## qu'un client (`Territoire.appliquer_changements`).
func _poser_scores(territoire: Territoire, parts: Array) -> void:
	var cellules: Array[int] = []
	for c in range(territoire.taille_grille.x * territoire.taille_grille.y):
		if territoire._peignables[c] == 1:
			cellules.append(c)
	var octets := PackedByteArray()
	var k := 0
	for i in range(parts.size()):
		for n in range(parts[i]):
			var o := octets.size()
			octets.resize(o + 3)
			octets.encode_u16(o, cellules[k])
			octets.encode_u8(o + 2, i + 1)
			k += 1
	territoire.appliquer_changements(octets)


func _charger(nb: int, pseudos: Array, niveau: int) -> Node:
	var gs: Node = root.get_node("GameState")
	gs.niveau_courant = niveau
	gs.difficulte_courante = 0
	gs.configurer_bataille(nb)
	for i in range(nb):
		gs.joueurs[i].pseudo = pseudos[i]
	change_scene_to_file("res://Scenes/Main.tscn")
	await _attendre(0.3)
	var main: Node = current_scene
	physics_frame.connect(func() -> void:
		for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss") + get_nodes_in_group("pickup"):
			ennemi.queue_free())
	while not gs.pret:
		await process_frame
	return main


## Un autre écran Résultats sur la même fin, vu d'un autre poste (`hote`, `en_reseau`), à la place du
## premier.
func _revoir(main: Node, hote: bool, en_reseau: bool) -> CanvasLayer:
	var bilan: BilanManche = main.resultats.bilan
	main.resultats.free()
	var vue: CanvasLayer = scene_resultats.instantiate()
	main.add_child(vue)
	main.resultats = vue
	vue.afficher(bilan, hote, en_reseau)
	vue.terminer_animation()
	return vue


func _run() -> void:
	if dossier.is_empty():
		printerr("--dossier=<chemin> manquant")
		quit(1)
		return
	scene_resultats = load("res://Scenes/Resultats.tscn")
	var params: Node = root.get_node("Parametres")
	var gs: Node = root.get_node("GameState")
	params.definir_langue("fr")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1400, 788))
	var main := await _charger(6, ["Clément", "WWWWWWWWWWWW", "Zoé", "Bob", "Léa-Marie 2", "Max"], 1)
	_poser_scores(main.ville.territoire, [260, 410, 180, 90, 410, 30])
	var stats := [[3, 120, 9], [5, 340, 4], [0, 60, 12], [1, 0, 2], [5, 280, 4], [0, 0, 1]]
	for i in range(6):
		gs.joueurs[i].etourdissements_infliges = stats[i][0]
		gs.joueurs[i].cellules_volees = stats[i][1]
		gs.joueurs[i].chocs = stats[i][2]
	main.hud_bataille.marquer_parti(5)
	gs.temps_ecoule = 89.5
	while gs.partie_en_cours:
		await process_frame
	await _attendre(0.9)
	await _shot("01_resultats_animation")
	main.resultats.marquer_parti(5)
	await _attendre(3.0)
	await _shot("02_resultats_hote_local_a_6")
	var vue := _revoir(main, false, true)
	vue.marquer_parti(5)
	await _attendre(0.3)
	await _shot("03_resultats_client")
	vue = _revoir(main, true, true)
	vue.marquer_parti(5)
	vue._deplacer_selection(1)
	await _attendre(0.3)
	await _shot("04_resultats_hote_reseau_niveau_suivant")
	for i in range(1, 5):
		vue.marquer_parti(i)
	await _attendre(0.3)
	await _shot("05_resultats_hote_seul")
	paused = false
	params.definir_langue("en")
	main = await _charger(2, ["Anna", "Bruno"], 2)
	_poser_scores(main.ville.territoire, [300, 300])
	gs.joueurs[0].chocs = 6
	gs.joueurs[1].chocs = 6
	gs.temps_ecoule = 89.5
	while gs.partie_en_cours:
		await process_frame
	vue = _revoir(main, true, true)
	await _attendre(0.3)
	await _shot("06_egalite_a_2_anglais")
	params.definir_langue("fr")
	quit(0)
```

- [ ] **Step 2 : les captures**

```bash
export PATH="/opt/homebrew/bin:$PATH"; mkdir -p "$TMPDIR/captures-18"
timeout 120 godot --path . --rendering-driver opengl3 --script "$TMPDIR/captures_resultats.gd" -- --dossier="$TMPDIR/captures-18" 2>&1 | grep -E "📸|SCRIPT ERROR"
```

Expected : six lignes `📸 …(2000x1125)`, aucune `SCRIPT ERROR` : `01_resultats_animation.png` (0,9 s après le gong : les premières lignes arrivent, les barres montent), `02_resultats_hote_local_a_6.png` (l'écran entier de l'hôte d'une bataille locale : deux ex æquo couronnés, « Égalité : WWWWWWWWWWWW, Léa-Marie 2 ! », Max parti en grisé, « TOI » sur Clément, les trois titres dont un partagé, Revanche sélectionnée, Niveau suivant : Village, Quitter), `03_resultats_client.png` (Quitter seul, « En attente de l'hôte… »), `04_resultats_hote_reseau_niveau_suivant.png` (Retour au salon en plus ; Niveau suivant sélectionné), `05_resultats_hote_seul.png` (tous partis sauf l'hôte : Revanche et Niveau suivant grisées, « Il faut au moins 2 joueurs pour démarrer. »), `06_egalite_a_2_anglais.png` (« TIME'S UP! », « Tie: Anna, Bruno! », deux titres « Nobody »). Les captures faites en préparant ce plan sont dans `captures-18-plan/` du bloc-notes de préparation.

- [ ] **Step 3 : validation par l'utilisateur**

Montrer les six captures à l'utilisateur et **attendre sa validation explicite** (◉ résultats) avant la Task 9. Ses retours visuels (voir « Décisions pour l'utilisateur » dans la Task 9) se corrigent ici, dans `Scripts/Resultats.gd` ou `Scenes/Resultats.tscn`, captures refaites, puis toutes les suites relancées (Task 9, Step 2) ; les corrections se committent à part (« Écran Résultats : retours de la revue des captures »).

---

### Task 9 : la spec, la feuille de route (ligne 18, points de vigilance) et la validation finale

**Files:**
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1 : `EtatLion`/`InterpolationLion`, `Reseau`, `Manche`, `BilanManche` ➕, `Resultats` ➕, `HUDBataille` ; §4 salon et déconnexions ; §8 fin et écran Résultats ; §9 hôte perdu ; §10 tests), `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 18 ; chaque point de vigilance « phase 18 », résolu ou renvoyé à la phase 19 avec sa raison ; le temps de la CI ; la règle de version)

**Interfaces:**
- Consumes : les mesures des Tasks 0 à 8 (trace, temps du test réseau, captures validées).

Les points de vigilance « phase 18 » de la feuille de route, et ce que ce plan en fait : les statistiques de l'hôte (bilan, Task 3) ; le territoire, le Spawner, la barrière et la manche d'une scène gardée (la scène rechargée, Tasks 4 et 5) ; le retour au salon (Task 5) ; les places réservées, le stick tenu, les adresses (Task 6) ; l'exclu (Task 6) ; l'état final des lions et l'arrêt de la prédiction (Task 3) ; M2 de la revue 16 (Task 2) ; la sortie de la phase 17 (Task 4) ; M3 de la revue 17 (Tasks 3 et 5) ; M5 de la revue 17 (Task 6) ; le temps de la CI (Task 7) ; la version (Task 3). Renvoyés à la phase 19 (livraison Windows et essai LAN), avec leur raison : le bruit `recv_nodes` de l'Écart 12 (sans effet ; à juger dans la console d'un `.exe`) et le jugement de l'écran Résultats en vrai (lisibilité, durée de l'animation, délai d'1 s, Échap de l'hôte sans confirmation), qui demandent l'essai sur la LAN ; ceux de la phase 19 déjà notés ne changent pas.

- [ ] **Step 1 : la spec et la feuille de route**

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
| `PredictionLocale` (Node, phase 16) | Sur un client, enfant du lion local : lit les actions de ce poste une fois par tick, les numérote, fait avancer le lion tout de suite par `Lion.avancer`, se recale sur chaque état neuf de l'hôte en rejouant les commandes qu'il n'a pas encore appliquées, et lisse l'écart à l'affichage (voir 4.1). Absent chez l'hôte et en solo. | `Lion`, `Commandes` |
| `EtatLion`, `InterpolationLion` (logique pure, phase 16) | L'état d'un lion au format réseau (instant de l'hôte, dernière commande appliquée, position, vitesse commandée, recul, orientation : 33 octets) ; l'affichage d'un lion distant, interpolé entre ses états avec 100 ms de retard. | rien |
| `Lion` (scène) | Déplacement, gerbe, traceuses, teinte, barbouillage. Lit un `Joueur` et une `Commandes`. Ne décide de rien : sur l'hôte, il signale aux `Regles` les lions que touche sa gerbe et ceux qu'il percute, comme les ennemis et les pastilles. Trois composants depuis la phase 15 bis : `DeplacementLion` (logique pure : vitesse commandée, recul ; le pas `Lion.avancer`, seul chemin du déplacement, que rejouera `PredictionLocale`), `PareChocs` (auto-tamponneuses) et `GerbeLion` (émetteurs, traceuse, zones de contact) ; le lion garde la présentation et la réplication. | `Joueur`, `Commandes` |
| `Regles` (RefCounted, détenu par `GameState`) | Reçoit les événements (lion touché par ennemi, par vomi, pastille ramassée, choc, vol de cellules, fin de chrono, progression), chacun pour le `Joueur` concerné, et décide des effets. Donne aussi les couleurs de départ de chaque joueur (aucune en solo, ses trois nuances en bataille), dit si la partie se joue au territoire (en bataille seulement), donne l'écran du mode (2000×648 en solo, 2000×1125 en bataille), l'avancement de la partie (la ville peinte rapportée au seuil en solo, le temps de la manche en bataille : il accélère le peintre et les ennemis) et ce qui peut apparaître (pastille et sa couleur, étoile, cœurs), que lit le Spawner. `ReglesSolo` / `ReglesBataille`. Ses événements s'exécutent sur l'hôte uniquement ; l'écran et le territoire sont lus partout. | `GameState`, `Joueur` |
| `Ville` (scène) | Masque de peinture (visuel), tampons en cache par rayon et jeu de couleurs, + deux comptages : couverture (solo, inchangé) et **grille de propriété** (bataille : un `Territoire`, créé quand les règles se jouent au territoire, tamponné par l'hôte seul, qui tient aussi les scores). Chaque tampon est peint pour un `Joueur`, dans ses couleurs. | `Joueur`, `Territoire`, `Regles` |
| `Reseau` (autoload) | Pair ENet, poignée de main (version, pseudo), liste des joueurs du salon (la table : arrivés seulement, couleur, Prêt ; tenue par l'hôte, diffusée à chaque changement), attribution des index et couleurs, arbitrage des demandes des clients, relais du niveau et du lancement de la manche, revérifié par l'hôte au moment où il démarre (RPC fiables sur l'autoload, présent sur chaque poste dès la connexion), signaux de connexion / déconnexion et du salon. Le salon (scène) porte le bouton « Démarrer la partie » de l'hôte. | `MultiplayerAPI` |
| `Decouverte` (autoload) | Balise UDP de l'hôte (émise tant que `Reseau` héberge, sans qu'on la relance), écoute et liste des parties entendues, validation d'une adresse IPv4 saisie. Ne nomme aucun autoload (phase 12). | `Reseau` (par son chemin) |
| `Main` | Instancie N lions (via `MultiplayerSpawner` en réseau, qui fait aussi apparaître ennemis et pastilles chez les clients), applique l'écran des règles branchées avant elle (par le titre ou le salon, jamais par la scène). | tout le reste |
| `Manche` (nœud de la scène de jeu, phase 14) | En réseau : barrière de chargement (exclusion d'un absent), commandes des clients, tampons et territoire diffusés, réactions des joueurs, départs (annoncés par l'hôte à chaque client depuis la phase 17), fin de manche de l'hôte envoyée après ses derniers tampons et son territoire (phase 17). Hors réseau, inerte. | `Reseau`, `Ville`, `Joueur` |
| `Peinture` (logique pure, phase 14) | Jeux de tampons tirés de leur clé, tirage d'un tampon par sa graine, format réseau des tampons : chaque poste dessine les mêmes. | rien |
| `HUDBataille` (scène, phase 17) | Le HUD d'une bataille, posé par `Main` à la place de celui du solo : vignettes, chrono, panneau de fin et sa sortie (§8). Lit le territoire de la ville, le chrono et les signaux des joueurs sur chaque poste. | `Ville`, `Joueur`, `Regles` |
| `PlacementPseudos` (logique pure, phase 17) | Écarte à l'horizontale les pseudos des lions qui se recouvrent et les garde dans l'écran. | rien |
```

par :

```markdown
| `PredictionLocale` (Node, phase 16) | Sur un client, enfant du lion local : lit les actions de ce poste une fois par tick, les numérote, fait avancer le lion tout de suite par `Lion.avancer`, se recale sur chaque état neuf de l'hôte en rejouant les commandes qu'il n'a pas encore appliquées, et lisse l'écart à l'affichage (voir 4.1). Absent chez l'hôte et en solo. | `Lion`, `Commandes` |
| `EtatLion`, `InterpolationLion` (logique pure, phase 16) | L'état d'un lion au format réseau (instant de l'hôte, dernière commande appliquée, position, vitesse commandée, recul, orientation : 33 octets) ; l'affichage d'un lion distant, interpolé entre ses états avec 100 ms de retard (plus aucun état : 3 ticks sur sa vitesse, puis à l'arrêt, sans revenir en arrière ; phase 18). | rien |
| `Lion` (scène) | Déplacement, gerbe, traceuses, teinte, barbouillage. Lit un `Joueur` et une `Commandes`. Ne décide de rien : sur l'hôte, il signale aux `Regles` les lions que touche sa gerbe et ceux qu'il percute, comme les ennemis et les pastilles. Trois composants depuis la phase 15 bis : `DeplacementLion` (logique pure : vitesse commandée, recul ; le pas `Lion.avancer`, seul chemin du déplacement, que rejouera `PredictionLocale`), `PareChocs` (auto-tamponneuses) et `GerbeLion` (émetteurs, traceuse, zones de contact) ; le lion garde la présentation et la réplication. | `Joueur`, `Commandes` |
| `Regles` (RefCounted, détenu par `GameState`) | Reçoit les événements (lion touché par ennemi, par vomi, pastille ramassée, choc, vol de cellules, fin de chrono, progression), chacun pour le `Joueur` concerné, et décide des effets. Donne aussi les couleurs de départ de chaque joueur (aucune en solo, ses trois nuances en bataille), dit si la partie se joue au territoire (en bataille seulement), donne l'écran du mode (2000×648 en solo, 2000×1125 en bataille), l'avancement de la partie (la ville peinte rapportée au seuil en solo, le temps de la manche en bataille : il accélère le peintre et les ennemis) et ce qui peut apparaître (pastille et sa couleur, étoile, cœurs), que lit le Spawner. `ReglesSolo` / `ReglesBataille`. Ses événements s'exécutent sur l'hôte uniquement ; l'écran et le territoire sont lus partout. | `GameState`, `Joueur` |
| `Ville` (scène) | Masque de peinture (visuel), tampons en cache par rayon et jeu de couleurs, + deux comptages : couverture (solo, inchangé) et **grille de propriété** (bataille : un `Territoire`, créé quand les règles se jouent au territoire, tamponné par l'hôte seul, qui tient aussi les scores). Chaque tampon est peint pour un `Joueur`, dans ses couleurs. | `Joueur`, `Territoire`, `Regles` |
| `Reseau` (autoload) | Pair ENet, poignée de main (version, pseudo), liste des joueurs du salon (la table : arrivés seulement, couleur, Prêt ; tenue par l'hôte, diffusée à chaque changement avec le nombre de places seulement réservées), attribution des index et couleurs, arbitrage des demandes des clients, relais du niveau et du lancement de la manche, revérifié par l'hôte au moment où il démarre (RPC fiables sur l'autoload, présent sur chaque poste dès la connexion), relance d'une manche et retour au salon depuis l'écran Résultats (phase 18 : le lancement et le retour, table comprise, sur le canal fiable ordonné de la manche), exclusion annoncée à l'exclu, signaux de connexion / déconnexion et du salon. Le salon (scène) porte le bouton « Démarrer la partie » de l'hôte. | `MultiplayerAPI` |
| `Decouverte` (autoload) | Balise UDP de l'hôte (émise tant que `Reseau` héberge, sans qu'on la relance), écoute et liste des parties entendues, validation d'une adresse IPv4 saisie. Ne nomme aucun autoload (phase 12). | `Reseau` (par son chemin) |
| `Main` | Instancie N lions (via `MultiplayerSpawner` en réseau, qui fait aussi apparaître ennemis et pastilles chez les clients), applique l'écran des règles branchées avant elle (par le titre ou le salon, jamais par la scène). | tout le reste |
| `Manche` (nœud de la scène de jeu, phase 14) | En réseau : barrière de chargement (exclusion d'un absent), commandes des clients, tampons et territoire diffusés, réactions des joueurs, départs (annoncés par l'hôte à chaque client depuis la phase 17), fin de manche de l'hôte envoyée après ses derniers tampons et son territoire (phase 17) avec son bilan, que chaque client applique (phase 18 : l'état final de chaque lion, crans, statistiques, départs). Hors réseau, inerte. | `Reseau`, `Ville`, `Joueur`, `BilanManche` |
| `BilanManche` (logique pure, phase 18) | Ce que l'hôte tient pour définitif au gong (chrono ; par joueur, cellules, crans, statistiques, départ ; l'état final de chaque lion), son format réseau, et ce qu'en tire l'écran Résultats (classement, parts, meneurs, les trois titres). | `Joueur`, `EtatLion`, `ReglesBataille` |
| `Resultats` (scène, phase 18) | L'écran Résultats, posé par `Main` sur la ville figée à la place du HUD de la bataille, sur chaque poste (§8) : il n'affiche que le bilan de l'hôte et la table des joueurs ; le choix de l'hôte (ou Quitter) part en signal, `Main` le suit. | `BilanManche`, `Joueur` |
| `Peinture` (logique pure, phase 14) | Jeux de tampons tirés de leur clé, tirage d'un tampon par sa graine, format réseau des tampons : chaque poste dessine les mêmes. | rien |
| `HUDBataille` (scène, phase 17) | Le HUD d'une bataille, posé par `Main` à la place de celui du solo : vignettes et chrono (§8) ; il se cache à la fin, sous l'écran Résultats (phase 18). Lit le territoire de la ville, le chrono et les signaux des joueurs sur chaque poste. | `Ville`, `Joueur`, `Regles` |
| `PlacementPseudos` (logique pure, phase 17) | Écarte à l'horizontale les pseudos des lions qui se recouvrent et les garde dans l'écran. | rien |
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
  (Échap, B) quitte le salon pour l'écran Réseau. Aucun contrôle du salon ne prend le focus : une
  action n'agit qu'à l'appui (ni répétition du clavier, ni stick tenu).
- **Commandes** : chaque joueur utilise les commandes actuelles de son PC (clavier ou manette).
```

par :

```markdown
  (Échap, B) quitte le salon pour l'écran Réseau. Aucun contrôle du salon ne prend le focus : une
  action n'agit qu'à l'appui (ni répétition du clavier, ni stick tenu, même déjà penché à l'ouverture
  du salon ; phase 18). Les clients voient aussi les places seulement réservées (leur nombre part avec
  la table, phase 18). Au retour d'une manche (Retour au salon, depuis l'écran Résultats, phase 18) :
  la même table sans les partis, personne prêt, la manche plus en cours (les arrivées de nouveau
  acceptées, la balise l'annonce), le niveau gardé.
- **Commandes** : chaque joueur utilise les commandes actuelles de son PC (clavier ou manette).
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
  - hôte perdu : message « L'hôte a quitté la partie », puis retour à l'écran Réseau depuis le salon
    (on peut aussitôt rejoindre une autre partie), au titre depuis une manche ;
  - client perdu en salon : sa carte se libère ;
  - client perdu en manche : son lion disparaît, ses cellules restent, il reste au classement en
    grisé (l'hôte annonce son départ à chaque client, phase 17 ; un exclu de la barrière aussi) ;
  - client qui n'a pas chargé la scène de jeu 20 s après le lancement (barrière de chargement) :
    exclu, l'hôte le déconnecte, la manche commence sans lui (phase 14) ;
  - un départ volontaire est un DISCONNECT fiable d'ENet, renvoyé jusqu'à son accusé de réception ;
```

par :

```markdown
  - hôte perdu : message « L'hôte a quitté la partie », puis retour à l'écran Réseau depuis le salon
    (on peut aussitôt rejoindre une autre partie), au titre depuis une manche (écran Résultats
    compris) ;
  - client perdu en salon : sa carte se libère ;
  - client perdu en manche : son lion disparaît, ses cellules restent, il reste au classement en
    grisé (l'hôte annonce son départ à chaque client, phase 17 ; un exclu de la barrière aussi) ;
  - client qui n'a pas chargé la scène de jeu 20 s après le lancement (barrière de chargement) :
    exclu, l'hôte le déconnecte, la manche commence sans lui (phase 14) ; l'exclu l'apprend de l'hôte
    avant la déconnexion : « Exclu : ta partie a mis trop de temps à charger. » (phase 18) ;
  - client qui quitte l'écran Résultats (Quitter, Échap) : sa ligne se grise chez les autres ; sous
    deux joueurs, Revanche et Niveau suivant se grisent (phase 18) ;
  - un départ volontaire est un DISCONNECT fiable d'ENet, renvoyé jusqu'à son accusé de réception ;
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
- **Fin** : à 0 chez l'hôte (son chrono seul décide), tout se fige ; l'hôte envoie à chaque client, après
  ses derniers tampons et son territoire sur le même canal fiable, la fin avec son chrono et ses scores
  définitifs : le client prend ce chrono et se fige (phase 17 ; l'état final de chaque lion viendra en
  phase 18). En attendant l'écran Résultats, un panneau de fin (« FIN DE LA MANCHE ! », le gagnant ou
  les ex æquo) et sa sortie (Échap, Start, bouton : le titre). **Écran Résultats** : podium
  en barres colorées animées (réutilise l'animation du bilan de `GameOver`), pourcentages, trois
  titres (« Le plus vicieux » : étourdissements infligés, « Le voleur » : cellules volées,
  « L'auto-tamponneur » : chocs). L'hôte choisit *Revanche*, *Niveau suivant* ou *Retour au
  salon*. Les clients voient « En attente de l'hôte… ».
- **Traductions** : tous les nouveaux textes passent par `traductions.csv` (FR + EN).
```

par :

```markdown
- **Fin** : à 0 chez l'hôte (son chrono seul décide), tout se fige ; l'hôte envoie à chaque client, après
  ses derniers tampons et son territoire sur le même canal fiable, la fin avec son bilan
  (`BilanManche`, phase 18 : son chrono ; par joueur, cellules, crans, statistiques, départ ; l'état
  final de chaque lion) : le client prend ce chrono, pose l'état final de chaque lion (sa prédiction
  s'arrête : un joueur qui tient ses touches au gong ne continue plus sur son écran), les crans et les
  statistiques de l'hôte, et se fige. **Écran Résultats** (phase 18, `Resultats`, sur chaque poste,
  tiré du seul bilan de l'hôte, à la place du HUD, sur la ville figée assombrie) : « FIN DE LA
  MANCHE ! » et le gagnant (ou les ex æquo, ou personne) ; le classement en barres colorées animées
  (l'animation du bilan de `GameOver`), une ligne par joueur, le plus de cellules d'abord : rang, lion
  teint (couronné pour chaque meneur), pseudo, part des cellules peintes, étourdissements infligés,
  cellules volées, chocs, « TOI » ou « PARTI » ; trois titres (« Le plus vicieux » : étourdissements
  infligés, « Le voleur » : cellules volées, « L'auto-tamponneur » : chocs ; tous les ex æquo, aucun
  si personne n'en a). L'hôte choisit pour tous *Revanche* (le même niveau) ou *Niveau suivant* (en
  boucle ; deux joueurs au moins pour l'un comme l'autre : la manche se relance chez tous sans
  repasser par le salon, la scène de jeu se recharge) ou *Retour au salon* (la même table) ; les
  clients voient « En attente de l'hôte… » ; chacun peut *Quitter* (Échap : le titre ; l'hôte qui
  quitte ramène ses clients au titre). Aucun bouton ne prend le focus ; une action n'agit qu'à l'appui,
  jamais tenue depuis la manche, et un choix au clavier n'est pris qu'1 s après l'animation (Espace
  martelé au gong). En bataille locale : Revanche, Niveau suivant, Quitter.
- **Traductions** : tous les nouveaux textes passent par `traductions.csv` (FR + EN).
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
| Aucune balise reçue | Liste vide avec l'indice « Pare-feu ? Réseau Privé ? Essaie par IP » |
| Hôte perdu | Message « L'hôte a quitté la partie » puis retour à l'écran Réseau (depuis le salon, ou l'écran Réseau lui-même : son accueil), au titre depuis une manche |
| Client perdu | Voir section 4 |
```

par :

```markdown
| Aucune balise reçue | Liste vide avec l'indice « Pare-feu ? Réseau Privé ? Essaie par IP » |
| Hôte perdu | Message « L'hôte a quitté la partie » puis retour à l'écran Réseau (depuis le salon, ou l'écran Réseau lui-même : son accueil), au titre depuis une manche (ou son écran Résultats) ; « Exclu : ta partie a mis trop de temps à charger. » pour un joueur exclu par la barrière de chargement |
| Client perdu | Voir section 4 |
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
  partir ; l'empreinte de fin de manche des scénarios 9, 11 et 12 compte aussi le HUD (départs compris).
- **Trace des lions** (`tests/trace_lions.gd`, phase 15 bis, hors CI) : une bataille à 4 lions, une
```

par :

```markdown
  partir ; l'empreinte de fin de manche des scénarios 9, 11 et 12 compte aussi le HUD (départs compris).
  Depuis la phase 18, le scénario 13 continue : chacun peint sans lâcher ses touches jusqu'au gong, et
  le HUD, le bilan, les lions (posés sur l'état final de l'hôte) et l'écran Résultats sont les mêmes
  sur chaque poste ; l'hôte choisit Revanche au clavier, chaque poste recharge une manche neuve de 6 s
  qui finit de même ; un client quitte l'écran Résultats, les autres le voient partir ; l'hôte choisit
  Retour au salon : la même table sans le partant, personne prêt ; puis l'hôte quitte le salon. Le muet
  du scénario 9 apprend son exclusion. Les tests unitaires couvrent aussi le bilan (format réseau,
  classement, titres), la relance et le retour au salon, et les manches enchaînées (canaux, barrière) ;
  le banc de la prédiction, la touche tenue au gong ; `tests/bataille_test.gd`, l'écran Résultats d'une
  bataille locale, Revanche et Niveau suivant (territoire, Spawner, chrono neufs).
- **Trace des lions** (`tests/trace_lions.gd`, phase 15 bis, hors CI) : une bataille à 4 lions, une
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
| 17 bis | (réunie avec la 17, même PR) | | |
| 18 | **Résultats** : podium, trois titres, Revanche / Niveau suivant / Salon. | ➕ `Scenes/Resultats.tscn` ➕ `Scripts/Resultats.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `Assets/Traductions/traductions.csv` | ◉ résultats |
| 19 | **Livraison Windows** : preset, `.pck` intégré, artefact CI, README « Jouer en LAN », captures. | ✏️ `export_presets.cfg` ✏️ `.github/workflows/ci.yml` ✏️ `README.md` ✏️ `tests/screenshots.gd` ✏️ `project.godot` | `.exe` en artefact, testé sur Windows par l'utilisateur |
```

par :

```markdown
| 17 bis | (réunie avec la 17, même PR) | | |
| 18 | **Résultats** : la fin de manche de l'hôte porte son bilan (`BilanManche` : chrono ; par joueur, cellules, crans, étourdissements infligés, cellules volées, chocs, départ ; l'état final de chaque lion), que chaque client applique (lions posés, prédiction arrêtée) ; l'écran Résultats sur chaque poste, tiré du seul bilan (classement en barres animées, pseudo, couleur, part des cellules peintes, gagnant ou ex æquo, statistiques, les trois titres ex æquo compris), à la place du HUD et de son panneau de fin ; l'hôte choisit pour tous Revanche, Niveau suivant (deux joueurs au moins : la manche se relance chez tous, la scène de jeu se recharge) ou Retour au salon (la même table), les clients attendent, chacun peut quitter (commandes à l'appui, sans focus, choix au clavier 1 s après l'animation) ; le lancement et le retour au salon, avec leur table, sur le canal ordonné de la manche, rien d'une manche finie dans la suivante ; le lion distant ne recule plus pendant un accroc (M2 de la revue 16) ; les places réservées vues des clients, le stick tenu à l'entrée du salon, les adresses relevées une fois ; l'exclusion dite à l'exclu ; la boucle du vomi arrêtée à l'hôte perdu ; scénario 13 étendu (Résultats identiques, revanche, départ sur l'écran Résultats, retour au salon) ; version 0.18. | ➕ `Scripts/BilanManche.gd` ➕ `Scenes/Resultats.tscn` ➕ `Scripts/Resultats.gd` ✏️ `Scripts/InterpolationLion.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scripts/PredictionLocale.gd` ✏️ `Scripts/Manche.gd` ✏️ `Scripts/Main.gd` ✏️ `Scripts/HUDBataille.gd` ✏️ `Scenes/HUDBataille.tscn` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Salon.gd` ✏️ `Scripts/Titre.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/bataille_test.gd` ✏️ `tests/prediction_test.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | ◉ résultats, suites vertes 5 fois, test réseau vert 5 fois (bash 3.2 et 5) |
| 19 | **Livraison Windows** : preset, `.pck` intégré, artefact CI, README « Jouer en LAN », captures. | ✏️ `export_presets.cfg` ✏️ `.github/workflows/ci.yml` ✏️ `README.md` ✏️ `tests/screenshots.gd` ✏️ `project.godot` | `.exe` en artefact, testé sur Windows par l'utilisateur |
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  menu local se ferme et se tait à la fin ; le bouton ne prend jamais le focus (Espace tenu au gong ne
  quitte pas). **Phase 18** : l'écran Résultats remplace ce panneau et cette sortie (retour au salon) ;
- (résolu en phase 17) les étiquettes de pseudo de deux lions qui se touchent ne se chevauchent plus
```

par :

```markdown
  menu local se ferme et se tait à la fin ; le bouton ne prend jamais le focus (Espace tenu au gong ne
  quitte pas). (Résolu en phase 18) l'écran Résultats (`Resultats`) remplace ce panneau et cette
  sortie : Échap y quitte (le titre), l'hôte y choisit aussi Revanche, Niveau suivant, Retour au salon ;
- (résolu en phase 17) les étiquettes de pseudo de deux lions qui se touchent ne se chevauchent plus
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  Pas de pré-génération. Mémoire du cache plein : environ 14,5 Mo pour 6 joueurs ;
- **prochaine phase qui ajoute un scénario au test réseau** (temps de la CI, phases 16 et 17) : le
  test réseau prend ~157 s sur ce Mac (140 s avant la phase 17), dont ~52 s pour le scénario 11
  (`DUREE11=45`, décision de l'utilisateur), ~38 s pour le scénario 12 (la manche sous latence
  simulée, `DUREE12=20`) et ~17 s pour le scénario 13 (la fin au chrono, `DUREE13=10`), sous le
  `timeout 300` du pas « Test réseau » de `ci.yml` ; le banc de la prédiction (`tests/prediction_test.gd`)
  a son propre pas, ~1 s. Au-delà de ~200 s, raccourcir un scénario ou relever ce `timeout` ;
- (résolu en phase 17, décision de l'utilisateur du 27/09 ; à revoir à l'essai LAN, phase 19) le
```

par :

```markdown
  Pas de pré-génération. Mémoire du cache plein : environ 14,5 Mo pour 6 joueurs ;
- **prochaine phase qui ajoute un scénario au test réseau** (temps de la CI, phases 16 à 18) : le
  test réseau prend ~175 s sur ce Mac (158 s avant la phase 18), dont ~52 s pour le scénario 11
  (`DUREE11=45`, décision de l'utilisateur), ~38 s pour le scénario 12 (la manche sous latence
  simulée, `DUREE12=20`) et ~28 s pour le scénario 13 (la fin au chrono, `DUREE13=10`, puis l'écran
  Résultats, la revanche de `DUREE13B=6`, le retour au salon : phase 18, étendu plutôt que doublé),
  sous le `timeout 300` du pas « Test réseau » de `ci.yml` ; le banc de la prédiction
  (`tests/prediction_test.gd`) a son propre pas, ~1 s. Au-delà de ~200 s, raccourcir un scénario ou
  relever ce `timeout` ;
- (résolu en phase 17, décision de l'utilisateur du 27/09 ; à revoir à l'essai LAN, phase 19) le
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  bande est libre un tiers du temps au lieu d'un cinquième. **Phase 19** : le juger en vrai ;
- **phase 18** (résultats, vu en phase 15) : les statistiques de bataille (`Joueur.chocs`,
  `etourdissements_infliges`, `cellules_volees`) ne sont tenues que par l'hôte (règles) et ne sont
  pas répliquées : l'écran Résultats d'un client doit les recevoir de l'hôte (dans le message de fin
  de manche, par exemple) ;
- (résolu en phase 16) l'hôte du scénario 10 efface ses scores de test avant d'écrire la mesure
```

par :

```markdown
  bande est libre un tiers du temps au lieu d'un cinquième. **Phase 19** : le juger en vrai ;
- (résolu en phase 18) les statistiques de bataille (`Joueur.chocs`, `etourdissements_infliges`,
  `cellules_volees`) ne sont tenues que par l'hôte (règles) : elles partent dans le bilan de sa fin de
  manche (`BilanManche`, `Manche._recevoir_fin_manche`), avec les cellules, les crans et les départs ;
  chaque client les pose sur ses joueurs, et l'écran Résultats ne lit que ce bilan (le même partout) ;
- (résolu en phase 16) l'hôte du scénario 10 efface ses scores de test avant d'écrire la mesure
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
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
  rechargée. Depuis la phase 17, la manche d'une scène gardée resterait aussi `finie` (elle
  n'enverrait plus de fin, un client plus de commandes), le HUD figé sur son panneau de fin : une
  scène rechargée règle tout cela d'un coup ;
- (résolu en phase 14 bis) le commentaire de `Boss.acceleration_max` suit l'avancement des règles ;
```

par :

```markdown
  opération de `Territoire` n'est nécessaire, les autres peuvent les lui voler ;
- (résolu en phase 18) une nouvelle manche (Revanche, Niveau suivant) recharge la scène de jeu sur
  chaque poste (`Main._sur_choix_resultats` en bataille locale ; `Reseau.relancer_manche` puis
  `Salon.entrer_en_manche` en réseau) : territoire, tampons, Spawner, manche (barrière comprise :
  `Reseau.scenes_chargees` vidé par le lancement), chrono, HUD et prédiction neufs d'un coup (vérifié
  par `tests/bataille_test.gd`, le smoke test et le scénario 13) ; la scène de jeu dépause l'arbre en
  entrant (la fin l'avait figé) ;
- (résolu en phase 14 bis) le commentaire de `Boss.acceleration_max` suit l'avancement des règles ;
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  désormais « version différente ». Chaque phase qui change les RPC (14, 16, 17, 18) doit encore
  l'augmenter (« 0.14 », « 0.16 », « 0.17 »…) ; sinon un `.exe` de CI (Windows) et une version locale (Mac) de phases
  différentes s'accepteraient, puis échoueraient en silence sur des RPC ou des caches de nœuds
```

par :

```markdown
  désormais « version différente ». Chaque phase qui change les RPC (14, 16, 17, 18) doit encore
  l'augmenter (« 0.14 », « 0.16 », « 0.17 », « 0.18 »…) ; sinon un `.exe` de CI (Windows) et une version locale (Mac) de phases
  différentes s'accepteraient, puis échoueraient en silence sur des RPC ou des caches de nœuds
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- (résolu en phase 14) l'intérim de la phase 13 est fini : la manche est synchronisée ;
- **phase 18** (retour au salon, depuis la phase 13) : `Reseau.ouvrir_salon(niveau)` remet déjà,
  chez l'hôte, `manche_en_cours` à faux (arrivées de nouveau acceptées, la balise l'annonce) et
  personne prêt, et le salon de l'hôte l'appelle en s'ouvrant ; il reste à ramener chaque poste au
  salon (un RPC de l'hôte qui change leur scène) : la table (`Reseau.table_salon`) y est toujours,
  index compactés compris ;
- (résolu en phase 14) hôte perdu en manche : message (`RESEAU_HOTE_PERDU`) sur la partie figée,
```

par :

```markdown
- (résolu en phase 14) l'intérim de la phase 13 est fini : la manche est synchronisée ;
- (résolu en phase 18) retour au salon : `Reseau.revenir_au_salon` (l'hôte, depuis l'écran
  Résultats) rouvre le salon chez lui (`ouvrir_salon` : plus de manche en cours, les arrivées de
  nouveau acceptées et annoncées par la balise, personne prêt, la table diffusée), puis ramène chaque
  client (`_recevoir_retour_salon`, sur le canal ordonné, après la table) ; le salon dépause l'arbre ;
- (résolu en phase 14) hôte perdu en manche : message (`RESEAU_HOTE_PERDU`) sur la partie figée,
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  encore là (`Manche._verifier_barriere`), 20 s de jeu au plus (`Manche.delai_chargement`), puis
  exclut les absents (déconnectés) ; lions, Spawner et intro attendent la barrière. **Phase 18** :
  l'exclu voit « L'hôte a quitté la partie » ; lui envoyer sa raison (RPC avant la déconnexion) ;
- (résolu en phase 14, M5) `server_relay` coupé (`Reseau._ready`) ; un client ne voit que l'hôte
```

par :

```markdown
  encore là (`Manche._verifier_barriere`), 20 s de jeu au plus (`Manche.delai_chargement`), puis
  exclut les absents (déconnectés) ; lions, Spawner et intro attendent la barrière. (Résolu en phase
  18) l'exclu apprend son exclusion (`Reseau.exclure` : `_recevoir_exclusion`, puis la déconnexion
  0,5 s plus tard ; le silence court de I1 posé tout de suite) et voit « Exclu : ta partie a mis trop
  de temps à charger. » (`Reseau.raison_perte`) ;
- (résolu en phase 14, M5) `server_relay` coupé (`Reseau._ready`) ; un client ne voit que l'hôte
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  `fiches_de_manche` non vide) avant de s'engager ;
- **phase 18** (retour au salon, revue finale 13, M2, M3, M4) : les clients ne voient pas les places
  réservées (pas encore arrivées) ; un stick déjà penché à l'entrée du salon agit une fois ;
  `IP.get_local_interfaces()` est relu à chaque `salon_change` (le mettre en cache à l'ouverture).
- **phase 19** (essai sur la LAN, phase 16) : avant la prédiction, l'utilisateur a joué une manche à 3
```

par :

```markdown
  `fiches_de_manche` non vide) avant de s'engager ;
- (résolu en phase 18, revue finale 13, M2, M3, M4) les clients voient les places réservées (leur
  nombre part avec la table, `Reseau.places_reservees`, `Reseau.fiches_attente`) ; un stick déjà
  penché à l'entrée du salon n'agit pas (l'état des actions relevé à l'ouverture) ; les adresses de
  l'hôte sont relevées une fois, à l'ouverture du salon.
- **phase 19** (essai sur la LAN, phase 16) : avant la prédiction, l'utilisateur a joué une manche à 3
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  le HUD montre la fin), puis n'envoie plus de commandes (scénario 13 du test réseau) ;
- **phase 18** (vu en phase 16, désync-report.md du scénario 11 ; la décision de l'hôte existe depuis
  la phase 17, `Manche._recevoir_fin_manche`) : la fin de manche devra aussi porter l'état final de
  chaque lion. Par conception, la prédiction d'un client ne distingue pas un hôte figé d'un silence Wi-Fi et
  continue (spec §4.1, YAGNI) : un client qui tient encore ses touches au gong voit son propre lion
  continuer à bouger sur son écran après la fin, pendant que l'hôte et les autres postes le montrent
  déjà arrêté ; sans ce message de fin, cet écart ne se résorbe jamais (le test réseau le contourne en
  n'exigeant l'égalité des empreintes qu'une fois chaque lion au repos, `TICKS_REPOS_AVANT_GEL`, ce
  qui n'est pas une garantie en jeu réel) ;
- **phase 19** (M7 de la revue finale 14) : en fenêtré, la largeur du 16:9 est gardée et la hauteur
```

par :

```markdown
  le HUD montre la fin), puis n'envoie plus de commandes (scénario 13 du test réseau) ;
- (résolu en phase 18, vu en phase 16, désync-report.md du scénario 11) la fin de manche porte
  l'état final de chaque lion (le bilan) : chez un client, chaque lion le prend
  (`Lion.poser_etat_final`), le lion local arrête sa prédiction (`PredictionLocale.arreter`) : un
  client qui tient ses touches au gong ne voit plus son lion continuer (le banc de la prédiction et le
  scénario 13, chacun peignant sans lâcher ses touches jusqu'au gong : lions identiques partout). Les
  scénarios 9, 11 et 12 gardent quand même leur repos avant le gel (`TICKS_REPOS_AVANT_GEL`) ;
- **phase 19** (M7 de la revue finale 14) : en fenêtré, la largeur du 16:9 est gardée et la hauteur
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  (mesuré sous le relais, 80/40/5 : écart de 0,007 à 0,019 s) ;
- **phase 18** (M2 de la revue finale 16, `Scripts/InterpolationLion.gd:90-92`) : pendant un accroc
  Wi-Fi de 200 à 420 ms, le lion distant extrapole 3 ticks puis glisse en arrière (jusqu'à 2,8 px par
  tick) avant de sauter en avant de 21 à 54 px à la reprise ; c'est le prix du correctif du lion figé
  (désync-report du scénario 11), mais visible en jeu normal. À corriger en repoussant le glissement
  arrière après un silence plus long (≥ 500 ms), ou en le rendant inutile par le message de fin de
  manche (`Manche._recevoir_fin_manche`, phase 17), une fois qu'il portera l'état final des lions
  distants ;
- **phase 18** (M5 de la revue finale 16) : la décision de fin de manche (phase 17 : un client se fige
  à sa réception, l'arbre en pause, donc sa prédiction aussi) devra aussi arrêter
  `PredictionLocale` chez chaque client (pas d'API aujourd'hui : se caler sur l'état final, remettre
  `_decalage` à zéro, cesser de lire les actions de ce poste), en plus de donner leur état final aux
  lions distants ; le point déjà noté ci-dessus sur la fin de manche (phase 18) couvre le besoin, pas
  ce crochet côté prédiction ;
- (résolu en phase 17, M5 de la revue finale 16) ce que le HUD accroche aux lions suit leur position
  affichée : les pseudos, enfants de `Lion.visuel`, placés depuis `position + visuel.position`
  (`Lion.rect_pseudo`, vérifié par `tests/bataille_test.gd`) ; les vignettes du HUD ne s'accrochent à
  aucun lion ;
- **phase 18** (sortie de la phase 17) : le panneau de fin du HUD de la bataille et sa sortie vers le
  titre ne sont qu'un intérim : l'écran Résultats les remplace (le bouton « Retour au salon » a
  besoin du RPC qui ramène chaque poste au salon, point ci-dessus) ; la manche finie au chrono y
  arrive par `GameState.partie_terminee` sur chaque poste. `ReglesBataille.duree_manche` (variable
  statique du test réseau, comme `Manche.delai_chargement`) reste à `DUREE_MANCHE` dans le jeu ;
- **phase 19** (essai LAN à 4-6 joueurs, phase 17) : juger en vrai le HUD de la bataille (lisibilité
```

par :

```markdown
  (mesuré sous le relais, 80/40/5 : écart de 0,007 à 0,019 s) ;
- (résolu en phase 18, M2 de la revue finale 16) plus aucun état, un lion distant continue au plus
  3 ticks sur sa vitesse puis s'arrête là (`InterpolationLion.echantillon`), sans plus glisser à
  reculons vers le dernier état reçu pendant un accroc du Wi-Fi ; l'état final de fin de manche vient
  du bilan ;
- (résolu en phase 18, M5 de la revue finale 16) `PredictionLocale.arreter` (appelé par
  `Lion.poser_etat_final` à la fin reçue) : plus de lecture des actions, plus de pas ni de rejeu,
  aucun décalage, plus aucun paquet ;
- (résolu en phase 17, M5 de la revue finale 16) ce que le HUD accroche aux lions suit leur position
  affichée : les pseudos, enfants de `Lion.visuel`, placés depuis `position + visuel.position`
  (`Lion.rect_pseudo`, vérifié par `tests/bataille_test.gd`) ; les vignettes du HUD ne s'accrochent à
  aucun lion ;
- (résolu en phase 18, sortie de la phase 17) l'écran Résultats remplace le panneau de fin du HUD et
  sa sortie ; il arrive par `Manche.bilan_recu` en réseau (sur chaque poste, le bilan de l'hôte), par
  `GameState.partie_terminee` en bataille locale. `ReglesBataille.duree_manche` (variable statique du
  test réseau, comme `Manche.delai_chargement`) reste à `DUREE_MANCHE` dans le jeu ;
- **phase 19** (essai LAN à 4-6 joueurs, phase 17) : juger en vrai le HUD de la bataille (lisibilité
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  jeu ; sans danger, mais à borner ou retirer.
- **phase 18** (M3 de la revue finale 17, `Scripts/Manche.gd:512` `_recevoir_depart` et les RPC de
  réactions `_recevoir_etourdi`/`_recevoir_crans`/`_recevoir_bonus`, canal 0, alors que la fin de
  manche part sur `CANAL_PEINTURE`) : un cran pris, un étourdissement ou un départ dans la dernière
  image avant le gong (ou un paquet du canal 0 retransmis sous perte) peut arriver chez un client
  après sa fin de manche ; le HUD figé de l'hôte le montre déjà, pas celui du client, et
  `HUDBataille.gd:86-88` ne se rafraîchit plus une fois l'arbre en pause (seul `marquer_parti` le
  fait). À corriger en joignant au message de fin l'état final de chaque joueur (crans, étourdi,
  bonus, statistiques de l'hôte) et la liste `_partis`, appliqués par le client avant
  `terminer_partie` ; à défaut, passer `_recevoir_depart` et les réactions sur `CANAL_PEINTURE`, et
  brancher le rafraîchissement du HUD sur les signaux des joueurs pour qu'il suive même en pause.
  L'écran Résultats de la phase 18 construira ses titres sur ces valeurs : à faire avant lui, ou en
  tête de la phase 18 ;
- **phase 18** (M5 de la revue finale 17, antérieur à la branche, `Scripts/Main.gd:186`
  `_sur_hote_perdu`) : si un client tient Espace (vomir) quand l'hôte disparaît en pleine manche,
  l'arbre se met en pause avant qu'aucun lion n'arrête la boucle (`Audio._vomi`, en
  `PROCESS_MODE_ALWAYS`) : elle continue sur le titre. `Audio.arreter_vomi` n'est appelé que par un
  lion, le menu local et la fin normale de partie (`Audio._on_partie_terminee`). À corriger par
  `Audio.arreter_vomi()` dans `Main._sur_hote_perdu`, et/ou en filet de sécurité dans `Titre._ready`.
```

par :

```markdown
  jeu ; sans danger, mais à borner ou retirer.
- (résolu en phase 18, M3 de la revue finale 17) l'écran Résultats ne lit que le bilan de la fin,
  arrivé après tout le reste sur le canal ordonné (cellules, crans, statistiques, départs) ; une
  réaction du canal 0 encore en route s'applique à son arrivée (elle précède la fin chez l'hôte) ; le
  HUD figé, caché sous l'écran Résultats, ne compte plus ; les départs sont idempotents (ceux du bilan
  et leurs annonces). Et d'une manche à la suivante : le lancement et le retour au salon partent, avec
  leur table, sur le canal ordonné (`Reseau.CANAL_ORDONNE`), après la fin de la manche finie (la table
  seule reste sur le canal 0 : sur le canal 1, la première table d'un arrivant pouvait devancer la fin
  de son authentification et être jetée) ; une réaction ou un départ reçu avant la barrière d'une
  manche neuve est ignoré (`Manche._joueur_recu`) ;
- (résolu en phase 18, M5 de la revue finale 17) `Main._sur_hote_perdu` arrête la boucle du vomi
  (`Audio.arreter_vomi`), et `Titre._ready` aussi, en filet.
- **phase 19** (vu en phase 18, Écart 12 du plan) : après une revanche ou un retour au salon, un
  client peut écrire `ERROR: Condition "!pinfo.recv_nodes.has(net_id)" is true` (des disparitions des
  nœuds de la manche finie arrivées après qu'il a quitté sa scène) : sans effet ; à revoir si la
  console d'un `.exe` sous Windows en montre trop, par exemple en libérant ces nœuds chez l'hôte avant
  de relancer.
- **phase 19** (essai LAN, phase 18) : juger l'écran Résultats en vrai (lisibilité à 1400×788 et en
  plein écran 1080p, durée de l'animation, délai d'1 s avant un choix au clavier, Échap de l'hôte qui
  ramène tout le monde au titre sans confirmation).
```

Si les mesures de l'exécutant diffèrent de celles du Mac de préparation (le temps du test réseau : ~175 s, ~28 s pour le scénario 13), mettre les siennes dans le point « prochaine phase qui ajoute un scénario au test réseau ».

- [ ] **Step 2 : la validation finale**

Chacune des cinq suites 5 fois de suite, puis le test réseau 5 fois sous bash 5 et 5 fois sous bash 3.2, sans relance, un seul processus de test à la fois (commandes des Global Constraints ; `pgrep -fl "godot --headless"` vide avant chaque passage) :

```bash
export PATH="/opt/homebrew/bin:$PATH"; godot --headless --import . > /dev/null 2>&1
for k in 1 2 3 4 5; do
	for t in "unitaires:" "smoke_test:" "bataille_test:--fixed-fps 60" "prediction_test:--fixed-fps 60" "trace_lions:--fixed-fps 60"; do
		n=${t%%:*}; o=${t#*:}
		timeout -k 5 300 godot --headless $o --script tests/$n.gd > "$TMPDIR/v_$n.log" 2>&1
		echo "$k $n code=$? $(grep -cE 'SCRIPT ERROR|SHADER ERROR|❌' "$TMPDIR/v_$n.log") $(grep -E '^== [0-9]|^TRACE' "$TMPDIR/v_$n.log" | tr '\n' ' ')"
	done
done
for sh in /opt/homebrew/bin/bash /bin/bash; do
	for k in 1 2 3 4 5; do
		debut=$(date +%s)
		timeout -k 5 300 $sh tests/reseau/lancer.sh > "$TMPDIR/v_reseau.log" 2>&1
		echo "$sh $k code=$? $(( $(date +%s) - debut )) s $(grep -c '❌' "$TMPDIR/v_reseau.log") $(grep -E '^== [0-9]+ .chec' "$TMPDIR/v_reseau.log" | tail -1)"
	done
done
```

Expected : chaque ligne `code=0 0 == 0 échec(s) ==` ; la trace, `TRACE bataille 1698533818 TRACE solo 185311436 TRACE replique 3757044499` (celle de la Task 0) les cinq fois ; le test réseau `code=0 … 0 == 0 échec(s) ==` dix fois, chacun sous 200 s (mesuré sur le Mac de préparation : voir le Step 1). Un seul rouge : ne pas relancer, le diagnostiquer (`superpowers:systematic-debugging`) et recommencer les cinq passages.

- [ ] **Step 3 : commit**

```bash
git add docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
git commit -m "Feuille de route et spec : phase 18 faite (fin de manche qui porte le bilan de l'hôte et l'état final de chaque lion, écran Résultats sur chaque poste, Revanche, Niveau suivant et Retour au salon, manches enchaînées sans mélange, restes des revues 13, 16 et 17, scénario 13 étendu, version 0.18) ; points de vigilance de la phase 18 résolus ou renvoyés à la phase 19

<ligne fournie par l'environnement>"
```

**Décisions pour l'utilisateur** (au ◉ de la Task 8 ; chacune ne change que `Scripts/Resultats.gd` ou `Scenes/Resultats.tscn`, sauf mention) :
1. Le podium : un tableau de barres horizontales, une ligne par joueur, triées par cellules (retenu : il tient 6 joueurs, leurs pseudos de 12 caractères et leurs statistiques dans l'écran), ou un vrai podium en colonnes verticales (les trois premiers sur des marches, les autres en dessous) ?
2. L'arrivée de l'écran : tout de suite au gong, la ville figée derrière un voile sombre (retenu, `Fond` à 80 % d'opacité), ou une ou deux secondes de ville figée seule avant l'écran ? Le voile plus clair ou plus sombre ?
3. Les titres : tous les ex æquo, un par ligne (retenu), ou un seul (le plus petit index) ? « Personne » quand personne n'a étourdi, volé ou percuté, ou la carte cachée ?
4. Le rythme : 0,3 s par ligne, 0,45 s par barre (le bilan du solo : moins de 3 s à 6), et 1 s avant qu'un choix au clavier soit pris ; plus court, plus long ?
5. Les colonnes : étourdissements infligés, cellules volées, chocs (l'ordre des titres) ; y ajouter les étourdissements subis ou les crans de fin ?
6. Échap : l'hôte qui quitte ramène tout le monde au titre sans confirmation (comme la sortie de la phase 17) ; faut-il une confirmation pour l'hôte ?
7. Niveau suivant boucle (après le Village, la Skyline), comme au salon ; ou le bouton se cache au dernier niveau (comme le bilan du solo) ?
