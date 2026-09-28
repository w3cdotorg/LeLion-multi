# Phase 19 : la livraison Windows (l'exe nommé et à l'icône du jeu, le README « Jouer en LAN », les captures versées au dépôt, les restes des revues) et la fiche de l'essai LAN, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** livrer LeLion multi aux joueurs de la LAN : un `.exe` Windows qui porte son nom, sa version et l'icône du jeu (la fenêtre du pare-feu dit « LeLion multi », plus « Godot Engine »), un README qui explique en français comment jouer en LAN (pare-feu au premier `heberger()`, réseau Privé, ports 7777 et 7778, repli par IP, dépannage), les captures de contrôle versées au dépôt et vérifiées par la CI, les restes des revues qui se corrigent et se testent sans la LAN (tables du salon numérotées : M6 de la revue finale 18 ; fenêtre gardée dans l'écran : M7 de la revue finale 14 ; journal de la prédiction hors du jeu livré ; une garde qui fait augmenter la version quand le protocole change ; la vraie diffusion en CI) ; et, pour tout ce que seul un essai sur de vrais PC Windows peut trancher, une fiche d'essai (`docs/essai-lan.md`) qui dit quoi essayer, quoi regarder, et quelle constante chaque réponse fait changer, pour la phase 19 bis. Sortie : **◉ livraison** (captures validées par l'utilisateur) ; les cinq suites vertes 5 fois, le test réseau vert 5 fois sous bash 5 et 5 fois sous bash 3.2, puis la CI de la PR verte 5 fois (vraie diffusion comprise) ; l'`.exe` de la CI essayé par l'utilisateur sous Windows avec la fiche.

**Architecture:**
- **Tables numérotées** (`Reseau`, M6) : l'hôte numérote chaque table du salon qu'il diffuse (`numero_table`), le lancement et le retour au salon portent le numéro de la leur ; un client ne repose jamais une table plus ancienne que la dernière posée (`_poser_salon` → `Pose.PERIMEE`), et une manche se joue toujours sur la table et le niveau de son lancement (`niveau_manche`, que lit `Salon.entrer_en_manche`), même devancés par une table plus récente du canal 0.
- **Garde du protocole** (`tests/unitaires.gd`) : une empreinte de tout ce qui fait le protocole (RPC de chaque script, propriétés répliquées des scènes, scènes apparues, tailles des formats, balise), notée avec sa version ; une empreinte neuve sous la même version fait échouer les tests. La règle de la phase 13 reste (la version est le protocole), désormais tenue par la machine.
- **Fenêtre bornée** (`Regles.appliquer_ecran`, M7) : à chaque écran, une fenêtre se garde dans la zone utile de son écran, barre de titre comprise, réduite à son format et recentrée au besoin (`Regles.taille_bornee`, `Regles.position_dans`, logique pure testée).
- **Journal de la prédiction** (`PredictionLocale.journal_actif`) : tenu dans les builds de débogage (les tests), jamais dans l'`.exe` d'export release.
- **Exe et CI** : `export_presets.cfg` écrit l'icône et les métadonnées (`application/modify_resources`) ; la CI les vérifie dans l'exe exporté (`wrestool`), lance le test réseau avec la vraie diffusion (`DIFFUSION=1`) et le déroulé des captures sans rendu.
- **Captures** : `tests/screenshots.gd` en parties (`--parties=solo,reseau,salon,bataille,resultats`, 37 captures), `tests/deux_fenetres.gd` (un hôte et un client dans deux vraies fenêtres, 11 captures) ; sans rendu, chacun déroule son scénario sans rien écrire (le pas de CI qui les garde en vie).
- **Documents** : `README.md` (le multijoueur, « Jouer en LAN » en français, les tests, la CI), `docs/essai-lan.md` (la fiche de l'essai, en français), la spec et la feuille de route (ligne 19, chaque point de vigilance « phase 19 », ligne 19 bis).

**Tech Stack:** Godot 4.7.2, GDScript typé, `SceneMultiplayer` et RPC ENet (canaux 0 et 1), `DisplayServer` (zone utile, fenêtre, décorations), export Windows Desktop (`application/modify_resources`, PE natif de Godot), GitHub Actions (`ubuntu-latest`, `icoutils` : `wrestool`), tests headless (`tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd`, `tests/prediction_test.gd`, `tests/reseau/lancer.sh` + `joueur.gd` + `relais.gd`), `tests/trace_lions.gd` (hors CI), `actionlint`.

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§4 découverte, poignée de main ; §7 viewport ; §10 tests, visuel, Windows ; §11 build et distribution ; §13 risques) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 19 ; tous les points de vigilance « phase 19 ») · plan précédent : `docs/superpowers/plans/2026-09-27-phase-18-resultats.md` (sa revue finale renvoie ici M6, le bruit `recv_nodes` de son Écart 12 et le jugement de l'écran Résultats) · prérequis : **PR #31 (phase 18) fusionnée** ; ce plan est commité seul sur la branche `phase-19-livraison-windows`, partie de `main`.

## Tri des points « phase 19 »

Chaque point de la ligne 19 de la feuille de route, de ses points de vigilance « phase 19 » (numéros de ligne à `64e806d`), de la spec et de la revue finale 18, dans un seul seau : **(a)** fait et testé dans ce plan ; **(b)** à juger sur de vrais PC Windows : une question de la fiche d'essai (Task 8), dont la réponse s'appliquera en phase 19 bis ; **(c)** plus d'objet, avec sa raison.

| # | Point (source) | Seau | Où, ou pourquoi |
|---|---|---|---|
| 1 | Preset Windows, `.pck` intégré, artefact CI (ligne 19 ; spec §11) | c | Fait en PR #26 : preset « Windows Desktop », `embed_pck`, artefact `LeLion-multi-windows` (le zip de la spec) ; ce qui manquait est le point 2. |
| 2 | Icône et métadonnées de l'exe (`modify_resources=false`, `application/icon` vide ; ligne 19) | a | Task 5 : écrites à l'export, vérifiées par la CI (nom, version, icône). |
| 3 | Taille de la fenêtre par défaut dans `project.godot` (l. 112, l. 400) | a | Task 3 : 1400×454 gardée (la largeur des captures validées des phases 17 et 18), désormais toujours tenue dans l'écran (point 4). |
| 4 | Fenêtre plus grande que la zone utile, 1920×1080 + barre de titre (M7 revue finale 14, l. 450) | a | Task 3 : `Regles.taille_bornee`, `Regles.position_dans`. |
| 5 | Le coup de `tests/screenshots.gd` qui tombe pendant l'intro (l. 237) | a | Task 6 : après `GameState.demarrer` (`GS.pret`). |
| 6 | Captures de l'écran Réseau, script jetable de la phase 12 bis (l. 237) | a | Task 6 : partie `reseau` de `tests/screenshots.gd`. |
| 7 | Captures du salon, script jetable de la phase 13 (l. 237) | a | Task 6 : partie `salon`. |
| 8 | « Captures du fichier jetable dans `tests/screenshots.gd` » (M4 revue finale 12 bis, l. 400) | a | Task 6 (mêmes parties que 6 et 7). |
| 9 | Le script de la partie à 2 fenêtres, phase 14 (l. 435) | a | Task 6 : `tests/deux_fenetres.gd`, prolongé jusqu'aux Résultats et à l'hôte perdu. |
| 10 | `tests/screenshots.gd` étendu : manche à 6 couleurs, résultats (spec §10) | a | Task 6 : parties `bataille` et `resultats` (scripts jetables des phases 17 et 18). |
| 11 | Règle de version du protocole, ou constante `PROTOCOLE` (M7 revue 11, l. 347) | a | Tasks 1 et 2 : la règle reste, tenue par une garde (Écart 3) ; version 0.19. |
| 12 | Tables du salon : une table plus ancienne reposée par un lancement ou un retour en retard (M6 revue finale 18) | a | Task 1 : tables numérotées, `niveau_manche`. |
| 13 | `PredictionLocale._journal` livré dans le jeu (M5 revue finale 16, l. 488) | a | Task 4 : déjà borné (`JOURNAL_MAX`) ; coupé hors des builds de débogage. |
| 14 | `DIFFUSION=1` dans le pas « Test réseau » (l. 355) | a | Task 5 (vert sur ce Mac en préparant ce plan : 172 s) ; 5 fois en CI, Task 9. |
| 15 | README « Jouer en LAN » : pare-feu au premier `heberger()` et à l'écran Réseau, règle de blocage, deux LeLion sur un PC (M8, l. 372) | a | Task 7. |
| 16 | README : ports 7777/7778, SmartScreen, réseau Privé, repli par IP, hôte en Ethernet, Wi-Fi 5 GHz (spec §11) | a | Task 7. |
| 17 | Routeur maillé en /22 : documenter la limite dans le README (l. 355, spec §4 et §13) | a | Task 7 (dépannage). |
| 18 | Découverte sous Windows : PC à carte virtuelle ou VPN, routeur maillé (l. 355) | b | Fiche, § Découverte ; mesh confirmé : les candidats /23 et /22 (point 19). |
| 19 | Balise vers les candidats /23 et /22, et l'identifiant de session I2 (l. 355, I2 revue 12 bis) | b | Seulement si l'essai confirme le /22 (fiche, § Découverte) ; sinon la limite reste documentée (point 17). |
| 20 | Rythme des pastilles, `HAUTEUR_BANDE_HUD` (l. 127-139) | b | Fiche, § Rythme. |
| 21 | Le peintre en bataille : répit, repos (l. 209-216) | b | Fiche, § Rythme. |
| 22 | Ressenti de la prédiction : `DUREE_CORRECTION`, `SEUIL_RECALAGE`, `InterpolationLion.RETARD` (l. 419) | b | Fiche, § Commandes. |
| 23 | Boucle du vomi spatialisée pour les autres lions (l. 429) | b | Fiche, § Sons. |
| 24 | Chez un client qui perd l'hôte, le message sur une ville sans lions (l. 430) | b | Fiche, § Départs (et la capture `client_5_hote_perdu` de la Task 6). |
| 25 | Shaders compilés à la première image après la barrière : à-coup à l'intro (M8 revue finale 14, l. 456) | b | Fiche, § Démarrage : le préchauffage ne se justifie que si l'à-coup se voit sous Windows (l'essai à 3 de l'utilisateur n'en a rien dit). |
| 26 | Lisibilité du HUD de bataille à 1400×788 et en plein écran 1080p, couronne, parts (l. 483) | b | Fiche, § HUD. |
| 27 | Volume des sons neufs à 4-6 (`Audio.DB_AUTRES`, l. 483) | b | Fiche, § Sons. |
| 28 | Lisibilité de l'écran Résultats (l. 513, revue finale 18) | b | Fiche, § Résultats. |
| 29 | Durée de l'animation des Résultats (l. 513) | b | Fiche, § Résultats. |
| 30 | Délai d'1 s avant un choix au clavier (l. 513) | b | Fiche, § Résultats. |
| 31 | Bruit `ERROR: … recv_nodes.has(net_id)` après une revanche ou un retour au salon (Écart 12 phase 18, l. 504) | c | Sans effet, et invisible des joueurs : l'exe n'a pas de console (`export_console_wrapper=0`), les `ERROR` ne vont qu'au journal `godot.log`. Le remède proposé (libérer les nœuds chez l'hôte avant de relancer) ne garantirait pas l'ordre : les disparitions voyagent sur le canal 0 de la réplication, le lancement sur le canal ordonné. La fiche demande les journaux de l'essai (Task 8) : s'ils en montrent d'autres, la phase 19 bis les verra. |
| 32 | Échap de l'hôte sans confirmation sur l'écran Résultats (renvoi de la Task 9 de la phase 18) | c | Résolu en phase 18 (confirmation « Quitter la partie pour tout le monde ? », décision de l'utilisateur du 27/09, revue finale). |

## Écarts assumés

1. **Les fichiers de la phase** : la feuille de route listait `export_presets.cfg`, `ci.yml`, `README.md`, `tests/screenshots.gd` et `project.godot`. S'y ajoutent ceux des restes des revues (`Scripts/Reseau.gd`, `Scripts/Salon.gd`, `Scripts/Regles.gd`, `Scripts/PredictionLocale.gd`), leurs tests, `tests/deux_fenetres.gd` (➕), `tests/reseau/lancer.sh` (un commentaire), `docs/essai-lan.md` (➕), la spec et la feuille de route (liste exacte dans les Global Constraints).
2. **La fenêtre par défaut reste 1400×454** (`window_width_override`, `window_height_override` : le titre est l'écran du solo, 2000×648) : 1400 px est la largeur à laquelle les captures des phases 17 et 18 ont été validées (16 px de texte y font 11 px, 1400×788 en 16:9), et M7 la garde désormais dans l'écran, du premier écran (le titre) à la bataille. Que 1400 px convienne sur les PC de la LAN est une question de la fiche (§ Fenêtre), pas un réglage à l'aveugle.
3. **La règle de version reste, tenue par une garde** (M7 de la revue 11) : une constante `PROTOCOLE` à part ferait deux numéros à tenir à jour au lieu d'un, et les joueurs liraient toujours la version du jeu dans le refus (« Version différente de l'hôte (0.18) ») ; le vrai risque, un changement de protocole sans hausse de version, est ce que la garde attrape (`_tester_protocole`). Elle couvre les RPC (nom, nombre d'arguments, mode, canal), la réplication des scènes, les scènes apparues, les tailles des formats réseau et la balise ; pas le contenu d'un dictionnaire de poignée de main ni l'ordre des champs d'un format de même taille (la revue de chaque phase reste le filet).
4. **M6 par numéro de table, et le niveau du lancement à part** (`Reseau.niveau_manche`) : un lancement devancé par une table plus récente (un départ pendant le chargement, diffusé sur le canal 0) lance quand même la manche sur sa propre table et son niveau, ceux de l'hôte ; seule la table affichée reste la plus récente. Un retour au salon devancé par une table plus récente (une arrivée au salon rouvert) ramène au salon sans la remplacer. Le lancement et le retour portent désormais les places réservées de l'hôte au lieu de les forcer à 0.
5. **Le journal de la prédiction n'est pas retiré** : le banc et le test réseau mesurent l'erreur de prédiction par lui (`erreur_max`, `erreurs_au_dela`, `etats_depuis`) ; il était déjà borné (`JOURNAL_MAX`, 20 000 entrées, 160 Ko). Il n'est plus tenu que dans les builds de débogage (`OS.is_debug_build()` : l'éditeur, les tests), jamais dans l'`.exe` d'export release.
6. **Le README garde l'anglais, sauf « Jouer en LAN »** : la section qu'appelle la spec (§11, « Jouer en LAN », « Exécuter quand même ») sert aux joueurs de la LAN, qui liront les libellés de leur Windows en français ; le reste du README (le solo, les tests, la CI) reste en anglais, et un paragraphe anglais présente le multijoueur (Décision 1 pour l'utilisateur).
7. **Pas de script d'installation du pare-feu** : autoriser l'exe demande les droits d'administrateur, et la fenêtre de Windows au premier hébergement fait déjà la même chose ; le README la décrit, ainsi que la réparation d'un « Annuler ». La règle du pare-feu suit le chemin de l'exe : le README conseille de garder `LeLion-multi.exe` au même endroit d'une version à l'autre (et la CI garde ce nom de fichier).
8. **Les métadonnées de l'exe** (Task 5) : nom « LeLion multi » (produit et description : ce qu'affichent l'explorateur, le gestionnaire des tâches et la fenêtre du pare-feu), éditeur « w3cdotorg », copyright « Copyright 2026 w3cdotorg, GPL-3.0 » (la licence du dépôt), version de fichier et de produit laissées vides : l'export prend `application/config/version` sur quatre nombres (« 0.19.0.0 »), que la CI vérifie (Décision 2 pour l'utilisateur).
9. **Les captures, versées et gardées en vie** : `tests/screenshots.gd` réunit, en parties, le solo d'avant et les scripts jetables des phases 12 bis, 13, 17 et 18, adaptés au code de la phase 18 (l'hébergement de l'écran Réseau mène au salon depuis la phase 13 : sa capture « hébergée » devient celles du salon ; le panneau de fin de la phase 17 est devenu l'écran Résultats) ; `tests/deux_fenetres.gd`, celui de la phase 14, deux processus, prolongé par une manche courte (15 s) jusqu'aux Résultats et à l'hôte perdu, le client attendant l'hôte par un fichier (plus de `sleep`). Sans rendu, les deux déroulent tout sans rien écrire : la CI les lance ainsi (Task 6), pour qu'ils ne pourrissent plus comme leurs prédécesseurs jetables.
10. **Rien ne change du jeu** : aucune règle, aucune constante de jeu, aucun lion. La trace ne change donc pas (`TRACE bataille 1698533818 TRACE solo 185311436 TRACE replique 3757044499`, à chaque tâche). Les réglages que l'essai demandera changeront, eux, la trace de la bataille : la procédure pour la remesurer est dans la fiche (§ Pour la phase 19 bis).
11. **Version 0.19** (`application/config/version`) : la table du salon, le lancement et le retour au salon prennent un argument de plus (M6), et l'exe la porte désormais dans ses métadonnées.
12. **L'export Web reste dans la CI** : il n'est pas dans la ligne 19 et vérifie que le solo s'exporte encore (le multijoueur n'existe pas dans un navigateur, spec §1).

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), commandes depuis `~/Sites/LeLion-multi`, branche `phase-19-livraison-windows`. Le shell est **zsh** : il ne découpe pas une variable non citée en mots ; chaque drapeau d'une commande est donc écrit en toutes lettres (jamais `O="--fixed-fps 60"` puis `$O`).
- Fichiers de la phase : ➕ `tests/deux_fenetres.gd` (+ son `.uid`, généré par l'import), `docs/essai-lan.md` ; ✏️ `Scripts/Reseau.gd`, `Scripts/Salon.gd`, `Scripts/Regles.gd`, `Scripts/PredictionLocale.gd`, `project.godot`, `export_presets.cfg`, `.github/workflows/ci.yml`, `README.md`, `tests/unitaires.gd`, `tests/prediction_test.gd`, `tests/screenshots.gd`, `tests/reseau/lancer.sh` (commentaire d'en-tête seulement), la spec et la feuille de route (Task 9). **Aucun autre fichier ne change** : ni `Scripts/Lion.gd`, `Scripts/Main.gd`, `Scripts/Manche.gd`, `Scripts/Decouverte.gd`, `Scripts/ReglesBataille.gd`, `Scripts/Audio.gd`, `Scripts/Resultats.gd`, `Scripts/HUDBataille.gd`, ni aucune scène, ni `Assets/Traductions/traductions.csv` (aucun texte visible neuf), ni `tests/smoke_test.gd`, `tests/bataille_test.gd`, `tests/trace_lions.gd`, `tests/reseau/joueur.gd`, `tests/reseau/relais.gd`. `Scripts/Reseau.gd` change par les blocs de la Task 1 et jamais autrement.
- **Le jeu ne change pas** (Écart 10) : ni règle, ni constante de jeu, ni lion ; le solo non plus ; aucune vérification existante n'est affaiblie (seuls changent les appels de `_recevoir_manche` et `_recevoir_retour_salon` du test des manches enchaînées, qui prennent les arguments neufs).
- **La trace** : `export PATH="/opt/homebrew/bin:$PATH"; godot --headless --import . > /dev/null 2>&1; for k in 1 2 3; do timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/trace_lions.gd 2>&1 | grep -E "^TRACE|❌|SCRIPT ERROR" | tr '\n' ' '; echo; done`. Verdict : deux passages consécutifs identiques (les deux premiers après un import peuvent différer, phase 15 bis). Référence (Task 0, mesurée sur le Mac de préparation à `64e806d`) : `TRACE bataille 1698533818 TRACE solo 185311436 TRACE replique 3757044499`, inchangée à chaque tâche. Les empreintes dépendent de la plateforme : seule compte celle de la Task 0 sur le poste de l'exécutant, qui ne doit plus changer.
- Identifiants, commentaires, messages de test en français, docstrings `##`, tabulations. Le README reste en anglais hors de « Jouer en LAN » (Écart 6).
- **Aucune séquence d'échappement `\u…` n'est tapée dans un fichier** (les « … », « – » et « © » éventuels sont des caractères). Vérifier après chaque écriture : `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/reseau/lancer.sh README.md docs/essai-lan.md .github/workflows/ci.yml export_presets.cfg` ne sort rien.
- Un test `--script` est compilé **avant** les autoloads : il ne nomme ni `GameState`, ni `Lion`, ni `PredictionLocale`, ni `Main`, ni `Manche`, ni `Salon`, ni `Resultats`, et ne précharge (`preload`) aucune de leurs scènes ; il peut nommer `Regles`, `ReglesBataille`, `EtatPartie`, `Territoire`, `Joueur`, `Commandes`, `EtatLion`, `BilanManche`, `Peinture`. Les autoloads s'y lisent par `root.get_node("…")`, les scripts qui les nomment par `load(...)` à l'exécution.
- Après la création d'un script (`tests/deux_fenetres.gd`) : `godot --headless --import .` avant de le lancer (il génère son `.uid`, à committer avec lui).
- **Toujours lancer un test Godot avec `timeout`, un seul à la fois, jamais en arrière-plan** (sauf les deux postes de `tests/deux_fenetres.gd`, qui vont ensemble), et chercher les erreurs. Les commandes, en toutes lettres :
  - `export PATH="/opt/homebrew/bin:$PATH"; timeout -k 5 300 godot --headless --script tests/unitaires.gd > "$TMPDIR/u.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/u.log"`
  - `export PATH="/opt/homebrew/bin:$PATH"; timeout -k 5 300 godot --headless --script tests/smoke_test.gd > "$TMPDIR/s.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/s.log"`
  - `export PATH="/opt/homebrew/bin:$PATH"; timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/bataille_test.gd > "$TMPDIR/b.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/b.log"`
  - `export PATH="/opt/homebrew/bin:$PATH"; timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/prediction_test.gd > "$TMPDIR/p.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/p.log"`
  - le test réseau, avec la vraie diffusion comme en CI : `export PATH="/opt/homebrew/bin:$PATH"; SECONDS=0; DIFFUSION=1 timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $? en ${SECONDS} s"; grep -E "❌|✅|== |\(chrono\)|\(latence\)" "$TMPDIR/r.log"` (sous bash 3.2 : `/bin/bash tests/reseau/lancer.sh` à la place de `bash tests/reseau/lancer.sh`).
  Une `SCRIPT ERROR` ne change pas le code de sortie ; un script qui ne compile pas sort aussi en `code 0`, sans ligne `== n échec(s) ==`. Bruit connu : « ObjectDB instances were leaked », « resources still in use at exit », les `ERROR` voulues des plans des phases 14 et 16 (dont `ERROR: Lion.avancer hors d'une image physique : ce pas est ignoré`, smoke test ; `Reseau.lancer_manche : fiches de la manche incohérentes`, tests unitaires), celles de la réplication au démontage de chaque scénario du banc (`Attempt to disconnect a nonexistent connection … _visibility_changed`, `!tracked_nodes.has(oid)`), celle de l'Écart 12 de la phase 18 (test réseau), et les `WARNING: Reseau : table du salon illisible, ignorée` voulues des tests unitaires (Task 1).
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`**.
- **Ports** : les suites ouvrent des ports locaux (1777x à 1979x ; `tests/screenshots.gd` 17890, 17891, 17899 ; `tests/deux_fenetres.gd` 17990, 18990) : avant une suite, `pgrep -fl "godot --headless"` ne sort rien.
- Les cinq suites (unitaires, smoke, bataille, banc de la prédiction, trace) se valident sur **5 passages consécutifs verts**, sans relance ; le test réseau 5 fois sous bash 5 et 5 fois sous bash 3.2 (`/bin/bash`, macOS), sans relance ; la CI de la PR 5 fois (Task 9).
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Un lancement ou un retour au salon perdu, puis renvoyé, qui arrive après une table plus récente** (Wi-Fi à pertes : une arrivée au salon rouvert, un départ pendant le chargement, diffusés sur le canal 0 pendant que le canal ordonné renvoie) : le client ne doit jamais reposer la table plus ancienne (le salon qui revient en arrière, une place réservée oubliée), et doit jouer la manche sur la table et le niveau que l'hôte a lancés. → unitaires `_tester_manches_enchainees` : « M6 : un retour au salon plus ancien… », « M6 : un lancement plus ancien… », « une table plus ancienne, ou sans numéro lisible, n'est pas posée » (Task 1) ; scénario 13 du test réseau (deux manches enchaînées et le retour au salon sous 5 % de pertes, Task 1 Step 5).
2. **Deux postes de builds différents** (un `.exe` de CI 0.18 contre un 0.19, ou une version locale dont les RPC ont changé sans hausse de version) : ils doivent se refuser « version différente », jamais s'accepter pour échouer en silence. → unitaires `_tester_protocole` (Task 2 : une empreinte neuve sous la même version échoue, vérifié en remettant le `Reseau.gd` de la phase 18) ; scénario 1 du test réseau (version différente refusée, inchangé).
3. **Une fenêtre plus grande que l'écran** (un portable 1366×768, une fenêtre du solo élargie à la main à 1920 px puis passée en 16:9, un second écran) : elle doit tenir dans la zone utile, au même format, sans rien sous la barre des tâches. → unitaires « une fenêtre qui dépasse la zone utile se réduit à son format… », « … y revient, collée au bord… » (Task 3) ; à l'écran, le script jetable de la Task 3 Step 5 ; sous Windows, la fiche (§ Fenêtre).
4. **Un exe qui dit encore « Godot Engine »** (fenêtre du pare-feu, règles d'« Autoriser une application », Propriétés → Détails) ou porte l'icône de Godot, ou une version qui ne suit pas `config/version` : le joueur autorise alors « Godot Engine » sans savoir que c'est LeLion. → pas « Vérifier l'icône et les métadonnées de l'exécutable Windows » de la CI (Task 5) ; la fiche (§ Avant la soirée).
5. **Des scripts de captures qui pourrissent** (comme les jetables des phases 12 bis à 18, écrits contre un code qui a changé depuis) : chaque capture doit encore se dérouler. → pas « Captures (déroulé sans rendu) » de la CI : 37 lignes `📸` pour `tests/screenshots.gd`, 5 et 6 pour les deux postes de `tests/deux_fenetres.gd`, aucune `SCRIPT ERROR` (Task 6).

---

### Task 0 : vérifications et référence de la trace

Ce plan est commité par le commit de planification : ne pas le recommiter, **ne jamais le modifier**. Vérifier que la phase 18 est fusionnée et la branche prête : `git branch --show-current` donne `phase-19-livraison-windows` ; `git merge-base --is-ancestor 64e806d HEAD && echo ok` donne `ok` ; `grep -c 'config/version="0.18"' project.godot` donne `1` ; `wc -l Scripts/Reseau.gd Scripts/Salon.gd Scripts/Regles.gd Scripts/PredictionLocale.gd tests/unitaires.gd tests/prediction_test.gd tests/screenshots.gd` donne 940, 320, 202, 214, 2342, 586 et 124. Sinon, s'arrêter et le signaler. Les blocs « remplacer » citent le code de `64e806d` (vérifié en appliquant ce plan, bloc par bloc, à une copie de `64e806d` : tests unitaires, smoke, banc, test réseau avec `DIFFUSION=1` verts, les deux scripts de captures déroulés sans rendu) ; la PR fusionnée peut avoir d'autres correctifs : si une ancre a bougé, l'adapter au texte réel sans changer le remplacement, et le noter.

« Step 0 » (règle du projet pour un fichier de plus de 300 lignes : `Scripts/Reseau.gd`, `Scripts/Salon.gd`, `tests/unitaires.gd`, `tests/prediction_test.gd`) : pas de code mort à retirer avant la phase (la phase 18 vient de passer sur ces fichiers). Le vérifier pour les scripts du jeu :

```bash
for f in Scripts/Reseau.gd Scripts/Salon.gd; do
	for n in $(grep -oE "^(const|var|func|static var|static func|@onready var|@export var|signal) [A-Za-z_]+" $f | awk '{print $NF}'); do
		[ "$(grep -rc "\b$n\b" Scripts tests Scenes | awk -F: '{s+=$2} END {print s}')" -lt 2 ] && echo "$f $n"
	done
done; grep -n "print(" Scripts/Reseau.gd Scripts/Salon.gd
```

Expected : rien.

Puis la référence de la trace (commande des Global Constraints), notée dans `$TMPDIR/trace_reference.txt` (jamais commitée). Mesuré sur le Mac de préparation : `TRACE bataille 1698533818 TRACE solo 185311436 TRACE replique 3757044499`. Et le temps du test réseau avant la phase, **sans** la vraie diffusion (`timeout -k 5 300 bash tests/reseau/lancer.sh`), noté aussi (169 à 178 s mesurés en phase 18) : il sert à la Task 9.

---

### Task 1 : les tables du salon numérotées ; une manche se joue sur la table et le niveau de son lancement (`Reseau`, `Salon`, M6 de la revue finale 18, version 0.19)

**Files:**
- Modify: `Scripts/Reseau.gd` (constantes après `CANAL_ORDONNE`, variables après `places_reservees`, `quitter`, `revenir_au_salon`, `_lancer`, `_diffuser_salon`, `_recevoir_salon`, `_poser_salon`, `_recevoir_manche`, `_recevoir_retour_salon`)
- Modify: `Scripts/Salon.gd` (`entrer_en_manche`)
- Modify: `project.godot` (version 0.19)
- Test: `tests/unitaires.gd` (`_tester_manches_enchainees`)

**Interfaces:**
- Consumes : `Reseau.lire_table(table: Variant) -> Array[Dictionary]`, `Reseau.fiches_de_manche(table: Array[Dictionary], id_local: int) -> Array[Dictionary]`, `Reseau.CANAL_ORDONNE`.
- Produces (Tasks 2 et 9) : `enum Reseau.Pose { POSEE, PERIMEE, ILLISIBLE }` ; `var Reseau.numero_table: int` (0 hors session ; chez l'hôte, +1 à chaque `_diffuser_salon`) ; `var Reseau.niveau_manche: int` ; `func _poser_salon(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> Pose` ; les RPC `_recevoir_salon(table, niveau, nb_places, reservees, numero)`, `_recevoir_manche(table, niveau, nb_places, reservees, numero)`, `_recevoir_retour_salon(table, niveau, nb_places, reservees, numero)` (tous `Variant`, canaux inchangés : 0, `CANAL_ORDONNE`, `CANAL_ORDONNE`) ; `Salon.entrer_en_manche` lit `Reseau.niveau_manche` ; `application/config/version="0.19"`.

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	# Ils portent leur table : un client la prend d'eux, même si la table du canal 0 ne les a pas précédés
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
```

par :

```gdscript
	# Ils portent leur table : un client la prend d'eux, même si la table du canal 0 ne les a pas précédés
	reseau.quitter()
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	reseau._recevoir_manche(table, 2)
	_check(lancements.size() == 1 and lancements[0].map(func(f: Dictionary) -> int: return f.id_reseau) == [1, 5] and reseau.niveau_salon == 2
		and reseau.table_salon.size() == 2 and reseau.manche_en_cours,
		"le lancement pose sa table et son niveau, puis lance la manche sur elle")
	reseau._recevoir_retour_salon(table, 1, 4)
	_check(retours[0] == 1 and not reseau.manche_en_cours and reseau.niveau_salon == 1 and reseau.places_salon == 4,
		"le retour au salon pose sa table, son niveau et ses places, puis ramène au salon")
	reseau.manche_lancee.disconnect(sur_lancement)
```

par :

```gdscript
	reseau._recevoir_manche(table, 2, 6, 0, 1)
	_check(lancements.size() == 1 and lancements[0].map(func(f: Dictionary) -> int: return f.id_reseau) == [1, 5] and reseau.niveau_salon == 2
		and reseau.niveau_manche == 2 and reseau.table_salon.size() == 2 and reseau.manche_en_cours and reseau.numero_table == 1,
		"le lancement pose sa table, son niveau et son numéro, puis lance la manche sur elle")
	reseau._recevoir_retour_salon(table, 1, 4, 0, 2)
	_check(retours[0] == 1 and not reseau.manche_en_cours and reseau.niveau_salon == 1 and reseau.places_salon == 4 and reseau.numero_table == 2,
		"le retour au salon pose sa table, son niveau et ses places, puis ramène au salon")
	# M6 (revue finale de la phase 18) : les deux canaux ne s'attendent pas ; une table plus ancienne que
	# la dernière posée n'est jamais reposée. Zoé arrive au salon rouvert (canal 0, table 4, une place
	# encore réservée) avant un retour au salon plus ancien, perdu puis renvoyé (canal ordonné, table 3).
	var avec_zoe := table + [{"id": 7, "index": 2, "couleur": palette[5], "pseudo": "Zoé", "pret": false}]
	reseau._recevoir_salon(avec_zoe, 1, 4, 1, 4)
	reseau._recevoir_retour_salon(table, 0, 6, 0, 3)
	_check(retours[0] == 2 and not reseau.manche_en_cours and reseau.table_salon.size() == 3 and reseau.places_reservees == 1
		and reseau.niveau_salon == 1 and reseau.places_salon == 4 and reseau.numero_table == 4,
		"M6 : un retour au salon plus ancien que la table posée ramène au salon sans la remplacer (Zoé reste, sa place réservée aussi)")
	reseau._recevoir_salon(table, 0, 6, 0, 3)
	reseau._recevoir_salon(avec_zoe, 1, 4, 0, "5")
	_check(reseau.table_salon.size() == 3 and reseau.places_reservees == 1 and reseau.numero_table == 4,
		"une table plus ancienne, ou sans numéro lisible, n'est pas posée")
	# Un lancement plus ancien que la table posée (Zoé partie pendant le chargement : table 6 sur le canal 0,
	# arrivée avant le lancement de la table 5) : la manche se joue sur la table et le niveau du lancement,
	# ceux de l'hôte ; la table plus récente reste posée.
	reseau._recevoir_salon(table, 1, 4, 0, 6)
	reseau._recevoir_manche(avec_zoe, 2, 4, 0, 5)
	_check(lancements.size() == 2 and lancements[1].map(func(f: Dictionary) -> int: return f.id_reseau) == [1, 5, 7] and reseau.niveau_manche == 2
		and reseau.niveau_salon == 1 and reseau.table_salon.size() == 2 and reseau.numero_table == 6 and reseau.manche_en_cours,
		"M6 : un lancement plus ancien que la table posée lance la manche sur sa propre table et son niveau, sans reposer la table")
	reseau.quitter()
	_check(reseau.numero_table == 0 and reseau.niveau_manche == 0, "hors session, plus de numéro de table ni de niveau de manche")
	# Chez l'hôte, chaque table diffusée a un numéro de plus ; le lancement porte celui de sa table
	reseau.ouvrir_salon(0)
	var premier: int = reseau.numero_table
	reseau.definir_niveau(1)
	_check(premier == 1 and reseau.numero_table == 2, "chez l'hôte, chaque table diffusée prend le numéro suivant (%d puis %d)" % [premier, reseau.numero_table])
	reseau.quitter()
	reseau.manche_lancee.disconnect(sur_lancement)
```

- [ ] **Step 2 : les voir échouer**

Run : la commande des tests unitaires (Global Constraints).
Expected : des `SCRIPT ERROR` (`_recevoir_manche` n'accepte que 2 arguments, `numero_table` inconnu) ou des `❌` sur les vérifications neuves.

- [ ] **Step 3 : les tables numérotées (`Scripts/Reseau.gd`)**

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
const CANAL_ORDONNE := 1
```

par :

```gdscript
const CANAL_ORDONNE := 1

## Ce que `_poser_salon` fait d'une table reçue de l'hôte (M6) : posée, plus ancienne que la dernière
## posée (ignorée), ou illisible (ignorée, signalée).
enum Pose { POSEE, PERIMEE, ILLISIBLE }

```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
var places_reservees := 0
## Chez un client : pourquoi l'hôte a été perdu la dernière fois (PERTE_HOTE ou PERTE_EXCLU), posé juste
```

par :

```gdscript
var places_reservees := 0
## Numéro de la table du salon (M6, revue finale de la phase 18) : chez l'hôte, celui de la dernière
## diffusée (un de plus à chaque `_diffuser_salon`) ; chez un client, celui de la dernière posée. La table
## voyage sur deux canaux qui ne s'attendent pas (seule sur le canal 0, avec le lancement et le retour au
## salon sur le canal ordonné) : chez un client, une table plus ancienne que la dernière posée (un
## lancement ou un retour perdu puis renvoyé, arrivé après une table plus récente du canal 0) n'est
## jamais reposée. 0 hors session.
var numero_table := 0
## Le niveau de la manche lancée (index de `EtatPartie.NIVEAUX`) : chez l'hôte, celui du salon au
## lancement ; chez un client, celui que porte le lancement, même quand une table plus récente l'a
## devancé (M6). Ce que charge chaque poste (`Salon.entrer_en_manche`).
var niveau_manche := 0
## Chez un client : pourquoi l'hôte a été perdu la dernière fois (PERTE_HOTE ou PERTE_EXCLU), posé juste
```

Dans `Scripts/Reseau.gd` (`quitter`), remplacer :

```gdscript
	places_reservees = 0
	_exclu = false
```

par :

```gdscript
	places_reservees = 0
	numero_table = 0
	niveau_manche = 0
	_exclu = false
```

Dans `Scripts/Reseau.gd` (`revenir_au_salon`), remplacer :

```gdscript
		_recevoir_retour_salon.rpc(table_salon, niveau_salon, places_salon)
```

par :

```gdscript
		_recevoir_retour_salon.rpc(table_salon, niveau_salon, places_salon, places_reservees, numero_table)
```

Dans `Scripts/Reseau.gd` (`_lancer`), remplacer :

```gdscript
	index_local = inscrits[multiplayer.get_unique_id()].index
	_diffuser_salon()
	if en_ligne():
		_recevoir_manche.rpc(table_salon, niveau_salon)
```

par :

```gdscript
	index_local = inscrits[multiplayer.get_unique_id()].index
	niveau_manche = niveau_salon
	_diffuser_salon()
	if en_ligne():
		_recevoir_manche.rpc(table_salon, niveau_salon, places_salon, places_reservees, numero_table)
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Chez l'hôte : reconstruit `table_salon` depuis `inscrits` (arrivés seulement), la diffuse aux
## clients (`rpc()` ne vise que les pairs connectés, donc arrivés : jamais une place seulement
## réservée, M4) et émet `salon_change` ici.
func _diffuser_salon() -> void:
	if not multiplayer.is_server():
		return
	table_salon = table_de(inscrits)
	places_reservees = inscrits.size() - table_salon.size()
	if en_ligne():
		_recevoir_salon.rpc(table_salon, niveau_salon, places_salon, places_reservees)
	salon_change.emit()
```

par :

```gdscript
## Chez l'hôte : reconstruit `table_salon` depuis `inscrits` (arrivés seulement), la numérote (M6) et la
## diffuse aux clients (`rpc()` ne vise que les pairs connectés, donc arrivés : jamais une place seulement
## réservée, M4), puis émet `salon_change` ici.
func _diffuser_salon() -> void:
	if not multiplayer.is_server():
		return
	table_salon = table_de(inscrits)
	places_reservees = inscrits.size() - table_salon.size()
	numero_table += 1
	if en_ligne():
		_recevoir_salon.rpc(table_salon, niveau_salon, places_salon, places_reservees, numero_table)
	salon_change.emit()
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
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
```

par :

```gdscript
## Chez un client : la table du salon diffusée par l'hôte (ignorée si elle est illisible ou plus ancienne
## que la dernière posée), avec le niveau, les places, les places seulement réservées et son numéro.
@rpc("authority", "call_remote", "reliable")
func _recevoir_salon(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> void:
	if _poser_salon(table, niveau, nb_places, reservees, numero) == Pose.ILLISIBLE:
		push_warning("Reseau : table du salon illisible, ignorée")


## Chez un client : pose la table du salon reçue de l'hôte, son niveau, ses places, ses places seulement
## réservées et son numéro ; ce poste y lit son index et sa couleur, puis `salon_change` (POSEE). Rien ne
## change pour une table illisible (`lire_table`), des valeurs hors plage (ILLISIBLE), ou une table plus
## ancienne que la dernière posée (PERIMEE, M6 : un numéro égal est la même table, arrivée par l'autre
## canal, reposée sans dommage).
func _poser_salon(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> Pose:
	var lue := lire_table(table)
	if lue.is_empty() or not (niveau is int) or niveau < 0 or niveau >= EtatPartie.NIVEAUX.size() \
			or not (nb_places is int) or nb_places < EtatPartie.NB_JOUEURS_MIN or nb_places > EtatPartie.NB_JOUEURS_MAX \
			or not (reservees is int) or reservees < 0 or reservees > EtatPartie.NB_JOUEURS_MAX - lue.size() \
			or not (numero is int) or numero < 1:
		return Pose.ILLISIBLE
	if numero < numero_table:
		return Pose.PERIMEE
	numero_table = numero
	table_salon = lue
```

Dans `Scripts/Reseau.gd` (fin de `_poser_salon`), remplacer :

```gdscript
			couleur_locale = fiche.couleur
	salon_change.emit()
	return true
```

par :

```gdscript
			couleur_locale = fiche.couleur
	salon_change.emit()
	return Pose.POSEE
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Chez un client : l'hôte lance la manche, sur la table compactée et le niveau `table`, `niveau` (phase
## 18 : avec le lancement, sur le canal ordonné, que la table diffusée sur le canal 0 peut ne pas
## précéder). Le chargement commence : silence toléré SILENCE_CHARGEMENT.
@rpc("authority", "call_remote", "reliable", CANAL_ORDONNE)
func _recevoir_manche(table: Variant, niveau: Variant) -> void:
	var fiches := fiches_de_manche(table_salon, multiplayer.get_unique_id()) if _poser_salon(table, niveau, places_salon, 0) else [] as Array[Dictionary]
	if fiches.is_empty():
		push_warning("Reseau : lancement de manche sur une table illisible, ignoré")
		return
	manche_en_cours = true
```

par :

```gdscript
## Chez un client : l'hôte lance la manche, sur la table compactée et le niveau `table`, `niveau` (phase
## 18 : avec le lancement, sur le canal ordonné, que la table diffusée sur le canal 0 peut ne pas
## précéder), ses places, ses places réservées et son numéro. La manche se joue toujours sur la table et
## le niveau du lancement, ceux de l'hôte, même quand une table plus récente du canal 0 (un départ pendant
## le chargement) l'a devancé et reste posée (M6). Le chargement commence : silence toléré
## SILENCE_CHARGEMENT.
@rpc("authority", "call_remote", "reliable", CANAL_ORDONNE)
func _recevoir_manche(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> void:
	var fiches: Array[Dictionary] = []
	if _poser_salon(table, niveau, nb_places, reservees, numero) != Pose.ILLISIBLE:
		fiches = fiches_de_manche(lire_table(table), multiplayer.get_unique_id())
	if fiches.is_empty():
		push_warning("Reseau : lancement de manche sur une table illisible, ignoré")
		return
	niveau_manche = niveau
	manche_en_cours = true
```

Dans `Scripts/Reseau.gd`, remplacer :

```gdscript
## Chez un client : l'hôte ramène tout le monde au salon (phase 18), sur la table `table`, son niveau et
## ses places (la même que celle diffusée juste avant, sur le canal 0 ; aucune place n'est réservée
## pendant une manche). Une table illisible est signalée, le retour a lieu quand même.
@rpc("authority", "call_remote", "reliable", CANAL_ORDONNE)
func _recevoir_retour_salon(table: Variant, niveau: Variant, nb_places: Variant) -> void:
	if not _poser_salon(table, niveau, nb_places, 0):
```

par :

```gdscript
## Chez un client : l'hôte ramène tout le monde au salon (phase 18), sur la table `table`, son niveau, ses
## places, ses places réservées et son numéro (la même que celle diffusée juste avant, sur le canal 0).
## Une table illisible est signalée ; une table plus ancienne que la dernière posée (une arrivée au salon
## rouvert, diffusée sur le canal 0, a devancé ce retour perdu puis renvoyé) est ignorée, sans bruit
## (M6) ; le retour a lieu dans les deux cas.
@rpc("authority", "call_remote", "reliable", CANAL_ORDONNE)
func _recevoir_retour_salon(table: Variant, niveau: Variant, nb_places: Variant, reservees: Variant, numero: Variant) -> void:
	if _poser_salon(table, niveau, nb_places, reservees, numero) == Pose.ILLISIBLE:
```

Dans `Scripts/Reseau.gd` (l'en-tête, le paragraphe « Salon : »), remplacer :

```gdscript
## poignée de main : sur le canal 1, la première table d'un arrivant pouvait devancer la fin de son
## authentification et être jetée (vu en préparant la phase 18, sous le relais du test réseau).
```

par :

```gdscript
## poignée de main : sur le canal 1, la première table d'un arrivant pouvait devancer la fin de son
## authentification et être jetée (vu en préparant la phase 18, sous le relais du test réseau). Phase 19
## (M6) : chaque table est numérotée ; un client ne repose jamais une table plus ancienne que la dernière
## posée, d'où qu'elle vienne, et joue chaque manche sur la table et le niveau de son lancement.
```

- [ ] **Step 4 : le niveau de la manche lancée (`Scripts/Salon.gd`) et la version**

Dans `Scripts/Salon.gd`, remplacer :

```gdscript
## Sur chaque poste, au lancement d'une manche (depuis le salon, ou depuis l'écran Résultats : Revanche,
## Niveau suivant, phase 18) : le niveau du salon devient celui de la partie, les règles de bataille et la
## table des joueurs sont branchées (`GameState.configurer_bataille_reseau`), puis la scène de jeu se
## charge.
static func entrer_en_manche(arbre: SceneTree, fiches: Array[Dictionary]) -> void:
	GameState.niveau_courant = Reseau.niveau_salon
```

par :

```gdscript
## Sur chaque poste, au lancement d'une manche (depuis le salon, ou depuis l'écran Résultats : Revanche,
## Niveau suivant, phase 18) : le niveau de la manche lancée (`Reseau.niveau_manche`, M6) devient celui de
## la partie, les règles de bataille et la table des joueurs sont branchées
## (`GameState.configurer_bataille_reseau`), puis la scène de jeu se charge.
static func entrer_en_manche(arbre: SceneTree, fiches: Array[Dictionary]) -> void:
	GameState.niveau_courant = Reseau.niveau_manche
```

Dans `project.godot`, remplacer `config/version="0.18"` par `config/version="0.19"`.

- [ ] **Step 5 : les voir passer, et le reste**

Run : `export PATH="/opt/homebrew/bin:$PATH"; godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error"`, puis la commande des tests unitaires.
Expected : rien à l'import ; `code 0`, `== 0 échec(s) ==`, dont les six vérifications neuves (« le lancement pose sa table, son niveau et son numéro… », « M6 : un retour au salon plus ancien… », « une table plus ancienne, ou sans numéro lisible, n'est pas posée », « M6 : un lancement plus ancien… », « hors session, plus de numéro… », « chez l'hôte, chaque table diffusée prend le numéro suivant (1 puis 2) ») ; une ligne `WARNING: Reseau : table du salon illisible, ignorée` (le numéro `"5"`, voulue).

Puis, une fois chacune : le smoke test, le test de la bataille, le banc de la prédiction, le test réseau (commande des Global Constraints, avec `DIFFUSION=1`) et la trace.
Expected : `== 0 échec(s) ==` et `code 0` partout ; le test réseau vert (mesuré en préparant ce plan : 172 s, scénario 7 compris, « ✅ découverte en vraie diffusion ») ; la trace de la Task 0.

- [ ] **Step 6 : commit**

```bash
git add Scripts/Reseau.gd Scripts/Salon.gd project.godot tests/unitaires.gd
git commit -m "Tables du salon numérotées (M6 de la revue finale 18) : un client ne repose jamais une table plus ancienne que la dernière posée (un lancement ou un retour au salon perdu puis renvoyé, devancé par une table du canal 0), le lancement et le retour portent les places réservées de l'hôte, et chaque manche se joue sur la table et le niveau de son lancement (niveau_manche) ; version 0.19

<ligne fournie par l'environnement>"
```

---

### Task 2 : la garde du protocole : une empreinte neuve sous la même version fait échouer les tests (`tests/unitaires.gd`)

**Files:**
- Test: `tests/unitaires.gd` (constantes d'en-tête, `_run`, `_tester_protocole` ➕, `_signature_protocole` ➕, `_fichiers_du_dossier` ➕)

**Interfaces:**
- Consumes (Task 1) : les RPC de `Scripts/Reseau.gd` et `Scripts/Manche.gd` tels que la Task 1 les laisse, `application/config/version="0.19"`.
- Produces (Task 9, et chaque phase qui changera le protocole) : `const PROTOCOLE_VERSION := "0.19"`, `const PROTOCOLE_EMPREINTE := 3329073800` ; la ligne `PROTOCOLE <version> <empreinte> (<n> lignes)` dans la sortie des tests unitaires.

- [ ] **Step 1 : la garde, empreinte encore inconnue**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
var _echecs := 0
```

par :

```gdscript
var _echecs := 0
## La version du protocole et son empreinte, mesurées (`_tester_protocole`).
const PROTOCOLE_VERSION := "0.19"
const PROTOCOLE_EMPREINTE := 0
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_manches_enchainees()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_manches_enchainees()
	_tester_protocole()
	print("== %d échec(s) ==" % _echecs)
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
```

par :

```gdscript
## Phase 19 (M7 de la revue de la phase 11) : `application/config/version` est aussi la version du
## protocole, présentée à la poignée de main et dans la balise ; deux postes de versions différentes se
## refusent (« Version différente de l'hôte »), deux postes de la même version doivent donc parler le même
## protocole. Son empreinte (`_signature_protocole`) change avec lui : une empreinte neuve sous la même
## version fait échouer ce test, jusqu'à ce que la version augmente et que PROTOCOLE_VERSION et
## PROTOCOLE_EMPREINTE la notent (la ligne PROTOCOLE de la sortie les donne).
func _tester_protocole() -> void:
	print("-- Version du protocole (phase 19)")
	var lignes := _signature_protocole()
	var empreinte := "\n".join(lignes).hash()
	var version: String = ProjectSettings.get_setting("application/config/version")
	print("PROTOCOLE %s %d (%d lignes)" % [version, empreinte, lignes.size()])
	if version != PROTOCOLE_VERSION:
		_check(false, "la version (%s) n'est plus celle que note ce test (%s) : noter ici la version et l'empreinte de la ligne PROTOCOLE" % [version, PROTOCOLE_VERSION])
	else:
		_check(empreinte == PROTOCOLE_EMPREINTE,
			"le protocole (RPC, réplication, formats réseau, balise) est celui de la version %s ; s'il a changé, augmenter application/config/version, puis noter ici la version et l'empreinte de la ligne PROTOCOLE" % version)


## Ce qui fait le protocole réseau, une ligne par élément, dans un ordre fixe : chaque RPC des scripts qui
## en déclarent (nom, nombre d'arguments, mode, transfert, appel local, canal), les propriétés répliquées
## des scènes (`MultiplayerSynchronizer`) et les scènes que fait apparaître la scène de jeu, les tailles des
## formats réseau, et une balise de découverte.
func _signature_protocole() -> PackedStringArray:
	var lignes := PackedStringArray()
	for fichier in _fichiers_du_dossier("res://Scripts", ".gd"):
		var chemin := "res://Scripts".path_join(fichier)
		if not FileAccess.get_file_as_string(chemin).contains("@rpc"):
			continue
		var script: Script = load(chemin)
		var nb_arguments := {}
		for methode: Dictionary in script.get_script_method_list():
			nb_arguments[String(methode.name)] = methode.args.size()
		var config: Dictionary = script.get_rpc_config()
		var noms: Array[String] = []
		for nom: StringName in config:
			noms.append(String(nom))
		noms.sort()  # des String : un tri de StringName ne suit pas l'ordre alphabétique
		for nom in noms:
			var c: Dictionary = config[StringName(nom)]
			lignes.append("%s %s(%d) %s %s %s %s" % [fichier, nom, nb_arguments.get(nom, -1), c.get("rpc_mode"),
				c.get("transfer_mode"), c.get("call_local"), c.get("channel", 0)])
	for fichier in _fichiers_du_dossier("res://Scenes", ".tscn"):
		for ligne in FileAccess.get_file_as_string("res://Scenes".path_join(fichier)).split("\n"):
			if ligne.begins_with("properties/") or ligne.begins_with("_spawnable_scenes"):
				lignes.append("%s %s" % [fichier, ligne.strip_edges()])
	lignes.append("formats %d %d %d %d %d %d %d %d" % [EtatLion.TAILLE, BilanManche.CHAMPS, BilanManche.TAILLE_LION,
		Commandes.TAILLE_ENTETE, Commandes.TAILLE_COMMANDE, Commandes.REDONDANCE, Peinture.OCTETS_PAR_TAMPON,
		Territoire.OCTETS_PAR_CHANGEMENT])
	lignes.append("balise " + load("res://Scripts/Decouverte.gd").encoder_balise("V", 1, 2, 3, true, 0, "P").get_string_from_utf8())
	return lignes


## Les fichiers du dossier `dossier` qui finissent par `suffixe`, triés.
func _fichiers_du_dossier(dossier: String, suffixe: String) -> PackedStringArray:
	var fichiers := PackedStringArray()
	for f in DirAccess.get_files_at(dossier):
		if f.ends_with(suffixe):
			fichiers.append(f)
	fichiers.sort()
	return fichiers


## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
```

- [ ] **Step 2 : la voir échouer, et mesurer l'empreinte**

Run : la commande des tests unitaires, puis `grep -E "^PROTOCOLE" "$TMPDIR/u.log"` ; deux fois.
Expected : `code 1`, `== 1 échec(s) ==` (le « protocole … est celui de la version 0.19 » en `❌`), et deux fois la même ligne : mesuré en préparant ce plan, `PROTOCOLE 0.19 3329073800 (57 lignes)` (7 RPC de `Reseau.gd`, 11 de `Manche.gd`, 36 lignes de réplication, les scènes apparues, les formats, la balise). Une autre valeur, stable, veut dire que le protocole à `HEAD` diffère de celui de la préparation (un correctif de la PR #31 fusionnée, ou la Task 1 appliquée autrement) : vérifier d'abord la Task 1 contre ses blocs, puis prendre la valeur lue et le noter.

- [ ] **Step 3 : noter l'empreinte**

Dans `tests/unitaires.gd`, remplacer `const PROTOCOLE_EMPREINTE := 0` par `const PROTOCOLE_EMPREINTE := 3329073800` (ou la valeur lue au Step 2).

- [ ] **Step 4 : la voir passer, puis la voir attraper un protocole changé**

Run : la commande des tests unitaires.
Expected : `code 0`, `== 0 échec(s) ==`, `✅ le protocole (RPC, réplication, formats réseau, balise) est celui de la version 0.19…`.

Puis la preuve qu'elle discrimine, sans rien laisser : `git show HEAD~1:Scripts/Reseau.gd > "$TMPDIR/Reseau18.gd"; cp Scripts/Reseau.gd "$TMPDIR/Reseau19.gd"; cp "$TMPDIR/Reseau18.gd" Scripts/Reseau.gd`, la commande des tests unitaires, `grep -E "^PROTOCOLE|protocole" "$TMPDIR/u.log"`, puis **toujours** `cp "$TMPDIR/Reseau19.gd" Scripts/Reseau.gd && git diff --exit-code Scripts/Reseau.gd && echo remis`.
Expected : avec le `Reseau.gd` de la phase 18 (ses trois RPC à moins d'arguments), une autre empreinte et le `❌` du protocole (mesuré : `PROTOCOLE 0.19 2256862498`, `== 1 échec(s) ==`, plus une `SCRIPT ERROR` du test des manches enchaînées, qui appelle ces RPC avec 5 arguments : attendue ici) ; puis `remis`.

- [ ] **Step 5 : commit**

```bash
git add tests/unitaires.gd
git commit -m "Garde du protocole (M7 de la revue de la phase 11) : la version reste celle du protocole, et les tests unitaires tiennent son empreinte (RPC de chaque script, réplication des scènes, scènes apparues, tailles des formats, balise) ; une empreinte neuve sous la même version les fait échouer

<ligne fournie par l'environnement>"
```

---

### Task 3 : la fenêtre gardée dans la zone utile de son écran (`Regles`, M7 de la revue finale 14)

**Files:**
- Modify: `Scripts/Regles.gd` (`appliquer_ecran`, `taille_bornee` ➕, `position_dans` ➕)
- Test: `tests/unitaires.gd` (`_tester_joueur_replique`, à la suite de la vérification de `taille_fenetre`)

**Interfaces:**
- Consumes : `Regles.taille_fenetre(ecran: Vector2i, fenetre: Vector2i) -> Vector2i` (inchangée), `DisplayServer.screen_get_usable_rect`, `window_get_current_screen`, `window_get_size_with_decorations`, `window_get_position_with_decorations`.
- Produces (Tasks 6, 8) : `static func Regles.taille_bornee(fenetre: Vector2i, place: Vector2i) -> Vector2i` ; `static func Regles.position_dans(coin: Vector2i, taille: Vector2i, zone: Rect2i) -> Vector2i` ; `Regles.appliquer_ecran(arbre, taille)` garde toujours la fenêtre dans son écran (appelé par le titre, l'écran Réseau, le salon et la scène de jeu, inchangés).

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
		"hors du solo, la fenêtre prend le format 16:9 (1400×788), et le reprend du solo au retour (1400×454)")
```

par :

```gdscript
		"hors du solo, la fenêtre prend le format 16:9 (1400×788), et le reprend du solo au retour (1400×454)")
	# Phase 19 (M7 de la revue finale 14) : la fenêtre tient dans la zone utile de son écran, au même format
	var place_1080p := Vector2i(1920, 1040 - 31)  # 1080p moins la barre des tâches (40) et la barre de titre (31)
	_check(Regles.taille_bornee(Vector2i(1920, 1080), place_1080p) == Vector2i(1793, 1009)
		and Regles.taille_bornee(Vector2i(1400, 788), place_1080p) == Vector2i(1400, 788)
		and Regles.taille_bornee(Vector2i(1400, 454), Vector2i(1366, 697)) == Vector2i(1366, 442)
		and Regles.taille_bornee(Vector2i(1400, 788), Vector2i.ZERO) == Vector2i(1400, 788),
		"une fenêtre qui dépasse la zone utile se réduit à son format (1920×1080 : 1793×1009 sur un écran 1080p ; 1400×454 : 1366×442 sur 1366 px), une fenêtre qui tient ne change pas")
	var zone := Rect2i(0, 0, 1920, 1040)
	_check(Regles.position_dans(Vector2i(300, 200), Vector2i(1400, 819), zone) == Vector2i(300, 200)
		and Regles.position_dans(Vector2i(700, 400), Vector2i(1400, 819), zone) == Vector2i(520, 221)
		and Regles.position_dans(Vector2i(-50, -10), Vector2i(1400, 819), zone) == Vector2i(0, 0)
		and Regles.position_dans(Vector2i(1920 + 100, 0), Vector2i(1400, 819), Rect2i(1920, 0, 1280, 984)) == Vector2i(1920, 0),
		"une fenêtre qui sort de la zone utile y revient, collée au bord qu'elle dépassait (au coin si elle est plus grande, second écran compris)")
```

- [ ] **Step 2 : les voir échouer**

Run : la commande des tests unitaires.
Expected : `SCRIPT ERROR` (`taille_bornee` et `position_dans` n'existent pas).

- [ ] **Step 3 : l'implémentation**

Dans `Scripts/Regles.gd`, remplacer :

```gdscript
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
```

par :

```gdscript
## Met l'écran à `taille` (`content_scale_size`, spec §7) et, dans une fenêtre (ni plein écran, ni
## maximisée, ni headless) : quand l'écran change de format, règle la hauteur de la fenêtre sur le
## nouveau format en gardant sa largeur (hors du solo, écran Réseau, salon, bataille en 16:9, l'écran ne
## s'affiche plus avec des bandes dans la fenêtre du solo : 1400×454 devient 1400×788, et le titre la
## rend au solo) ; puis, toujours, la garde dans la zone utile de son écran (M7 de la revue finale 14 :
## sans la barre des tâches, barre de titre comprise), réduite au même format et recentrée au besoin (une
## fenêtre du solo élargie à 1920 px passait en 1920×1080 plus sa barre de titre sur un écran 1080p : le
## bas de la ville et le HUD sous la barre des tâches). Une fenêtre qui tient déjà dans son écran, au même
## format, reste telle que le joueur l'a mise. Appelée par le titre (le premier écran du jeu), l'écran
## Réseau, le salon et la scène de jeu.
static func appliquer_ecran(arbre: SceneTree, taille: Vector2i) -> void:
	var avant := arbre.root.content_scale_size
	arbre.root.content_scale_size = taille
	if DisplayServer.get_name() == "headless" or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var fenetre := DisplayServer.window_get_size()
	var voulue := fenetre if avant == taille else taille_fenetre(taille, fenetre)
	var zone := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var bords := DisplayServer.window_get_size_with_decorations() - fenetre
	voulue = taille_bornee(voulue, zone.size - bords)
	if voulue != fenetre:
		DisplayServer.window_set_size(voulue)
	var coin := DisplayServer.window_get_position_with_decorations()
	var place := position_dans(coin, voulue + bords, zone)
	if place != coin:
		DisplayServer.window_set_position(place + DisplayServer.window_get_position() - coin)


## La fenêtre de largeur `fenetre.x` au format de l'écran `ecran`.
static func taille_fenetre(ecran: Vector2i, fenetre: Vector2i) -> Vector2i:
	return Vector2i(fenetre.x, roundi(fenetre.x * float(ecran.y) / ecran.x))


## La fenêtre `fenetre`, réduite à son format pour tenir dans `place` (M7) ; telle quelle si elle y tient
## déjà, ou si `place` n'a pas de surface (écran inconnu). Le côté qui limite prend exactement la place.
static func taille_bornee(fenetre: Vector2i, place: Vector2i) -> Vector2i:
	if place.x <= 0 or place.y <= 0 or (fenetre.x <= place.x and fenetre.y <= place.y):
		return fenetre
	if fenetre.x * place.y >= fenetre.y * place.x:
		return Vector2i(place.x, floori(place.x * float(fenetre.y) / fenetre.x))
	return Vector2i(floori(place.y * float(fenetre.x) / fenetre.y), place.y)


## Le coin d'une fenêtre de taille `taille` (bords compris) posée en `coin`, ramené dans la zone `zone`
## (M7) : inchangé si elle y tient ; collé au bord qu'elle dépasse sinon ; au coin de la zone si elle est
## plus grande qu'elle.
static func position_dans(coin: Vector2i, taille: Vector2i, zone: Rect2i) -> Vector2i:
	return Vector2i(
		clampi(coin.x, zone.position.x, maxi(zone.position.x, zone.end.x - taille.x)),
		clampi(coin.y, zone.position.y, maxi(zone.position.y, zone.end.y - taille.y)))
```

- [ ] **Step 4 : les voir passer**

Run : la commande des tests unitaires, puis le smoke test et le test de la bataille (en headless, `appliquer_ecran` ne touche jamais la fenêtre : rien ne doit changer pour eux).
Expected : `code 0` et `== 0 échec(s) ==` partout, dont les deux vérifications neuves.

- [ ] **Step 5 : à l'écran (rendu réel, script jetable)**

Créer `$TMPDIR/fenetre_m7.gd` (hors du dépôt, jamais commité) :

```gdscript
extends SceneTree
## M7 (phase 19, jetable, jamais commité) : godot --path <dépôt> --rendering-driver opengl3 --script <ce fichier>
## Rendu réel (pas headless) : une fenêtre du solo aussi large que la zone utile de son écran passe en
## 16:9 ; elle doit tenir dans l'écran, barre de titre comprise, au format 16:9 ; puis, poussée hors de
## l'écran, elle y revient au prochain écran.


func _init() -> void:
	call_deferred("_run")


func _images(n: int) -> void:
	for i in range(n):
		await process_frame


func _rect_fenetre() -> Rect2i:
	return Rect2i(DisplayServer.window_get_position_with_decorations(), DisplayServer.window_get_size_with_decorations())


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await _images(5)
	var zone := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	root.content_scale_size = Regles.TAILLE_ECRAN_SOLO
	DisplayServer.window_set_size(Vector2i(zone.size.x, roundi(zone.size.x * 648.0 / 2000.0)))
	DisplayServer.window_set_position(zone.position)
	await _images(10)
	Regles.appliquer_ecran(self, ReglesBataille.TAILLE_ECRAN)
	await _images(10)
	var f := DisplayServer.window_get_size()
	print("zone utile %s ; fenêtre %s, bords compris %s ; format %.3f (16:9 : %.3f)" % [zone, f, _rect_fenetre(), float(f.x) / f.y, 2000.0 / 1125.0])
	print("✅ en 16:9, elle tient dans l'écran" if zone.encloses(_rect_fenetre()) and absf(float(f.x) / f.y - 2000.0 / 1125.0) < 0.01 else "❌ hors de l'écran ou hors du format")
	DisplayServer.window_set_position(zone.end - Vector2i(200, 150))
	await _images(10)
	Regles.appliquer_ecran(self, ReglesBataille.TAILLE_ECRAN)
	await _images(10)
	print("✅ poussée dehors, elle revient dans l'écran %s" % _rect_fenetre() if zone.encloses(_rect_fenetre()) else "❌ toujours dehors %s" % _rect_fenetre())
	quit(0)
```

Run : `export PATH="/opt/homebrew/bin:$PATH"; timeout -k 5 60 godot --path . --rendering-driver opengl3 --script "$TMPDIR/fenetre_m7.gd" 2>&1 | grep -E "✅|❌|zone|SCRIPT ERROR"` (une fenêtre s'ouvre une seconde).
Expected : deux `✅`, aucune `❌` ni `SCRIPT ERROR`. Mesuré en préparant ce plan (écran Retina, zone utile 3420×2148 en (0, 76)) : fenêtre 3420×1924 (1988 de haut avec la barre de titre), format 1,778 ; poussée dehors, ramenée en (0, 236). Sur un écran 16:10 la hauteur suffit ; la réduction elle-même (un écran 1080p) est prouvée par les tests du Step 1 et se revoit sous Windows (fiche, § Fenêtre).

- [ ] **Step 6 : commit**

```bash
git add Scripts/Regles.gd tests/unitaires.gd
git commit -m "Fenêtre gardée dans la zone utile de son écran (M7 de la revue finale 14) : à chaque écran, barre de titre comprise, réduite à son format et ramenée dans l'écran au besoin (une fenêtre du solo élargie à 1920 px ne passe plus sous la barre des tâches en 16:9) ; la fenêtre par défaut reste 1400×454

<ligne fournie par l'environnement>"
```

---

### Task 4 : le journal de la prédiction, hors du jeu livré (`PredictionLocale`, M5 de la revue finale 16)

**Files:**
- Modify: `Scripts/PredictionLocale.gd` (`JOURNAL_MAX`, `journal_actif` ➕, `_recaler`)
- Test: `tests/prediction_test.gd` (`_run`, `_scenario_journal` ➕)

**Interfaces:**
- Consumes : `PredictionLocale.erreur_max`, `etats_depuis`, `etats_recus` (inchangés) ; le banc (`_preparer`, `_pas`, `_presser`, `_relacher`, `_liberer`).
- Produces : `var PredictionLocale.journal_actif: bool` (défaut `OS.is_debug_build()`).

- [ ] **Step 1 : le test**

Dans `tests/prediction_test.gd`, remplacer :

```gdscript
	await _scenario_fin_de_manche()
	GS.configurer_solo()
```

par :

```gdscript
	await _scenario_fin_de_manche()
	await _scenario_journal()
	GS.configurer_solo()
```

Dans `tests/prediction_test.gd`, remplacer :

```gdscript
# --- Les deux postes ---------------------------------------------------------------------------------
```

par :

```gdscript
## Phase 19 (M5 de la revue finale 16) : le journal des erreurs de prédiction est de l'instrumentation de
## test, tenue dans les builds de débogage seulement (les tests, l'éditeur) ; coupé (le jeu livré), il ne
## garde rien, et la prédiction ne change pas (états reçus, recalage, convergence).
func _scenario_journal() -> void:
	print("-- Journal de la prédiction coupé (le jeu livré)")
	_preparer(Vector2(300, 150), Vector2(400, 600), 80.0, 40.0, 5.0, 2100)
	var p: Node = c1.prediction
	_check(p.journal_actif == OS.is_debug_build() and p.journal_actif, "(pré-condition) les tests tournent en build de débogage : le journal y est tenu")
	p.journal_actif = false
	_presser(Vector2.RIGHT)
	for i in range(60):
		await _pas()
	_relacher()
	for i in range(30):
		await _pas()
	_check(p.etats_recus > 30 and p.etats_depuis(0) == 0 and p.erreur_max() == -1.0 and c1.position.distance_to(h1.position) < ECART_MAX,
		"journal coupé : %d états reçus, aucun gardé, et le lion du client rejoint celui de l'hôte (%.2f px)" % [p.etats_recus, c1.position.distance_to(h1.position)])
	await _liberer()


# --- Les deux postes ---------------------------------------------------------------------------------
```

- [ ] **Step 2 : le voir échouer**

Run : la commande du banc de la prédiction.
Expected : une `SCRIPT ERROR` (`journal_actif` n'existe pas) dans « Journal de la prédiction coupé ».

- [ ] **Step 3 : l'implémentation**

Dans `Scripts/PredictionLocale.gd`, remplacer :

```gdscript
## Erreurs de prédiction gardées pour les statistiques (tests).
const JOURNAL_MAX := 20000
```

par :

```gdscript
## Erreurs de prédiction gardées pour les statistiques (tests) : 20 000 (5,5 min de jeu, 160 Ko), assez
## pour une manche de 90 s même sous le relais du test réseau.
const JOURNAL_MAX := 20000
```

Dans `Scripts/PredictionLocale.gd`, remplacer :

```gdscript
## Vrai une fois la manche finie (`arreter`).
var arretee := false
```

par :

```gdscript
## Vrai une fois la manche finie (`arreter`).
var arretee := false
## Vrai si l'erreur de chaque état neuf est gardée dans le journal (`erreur_max`, `erreurs_au_dela`,
## `etats_depuis`) : instrumentation des tests (phase 19, M5 de la revue finale 16), tenue dans les builds
## de débogage (l'éditeur, les tests headless), jamais dans le jeu livré (l'`.exe` d'export release).
var journal_actif := OS.is_debug_build()
```

Dans `Scripts/PredictionLocale.gd` (`_recaler`), remplacer :

```gdscript
		if appliquee.numero == accuse and _journal.size() < JOURNAL_MAX:
```

par :

```gdscript
		if journal_actif and appliquee.numero == accuse and _journal.size() < JOURNAL_MAX:
```

- [ ] **Step 4 : le voir passer, et la trace**

Run : la commande du banc de la prédiction, puis celle de la trace.
Expected : `code 0`, `== 0 échec(s) ==`, dont « (pré-condition) les tests tournent en build de débogage… » et « journal coupé : 52 états reçus, aucun gardé… (0.00 px) » (mesuré en préparant ce plan) ; les `ERROR` de réplication au démontage du scénario neuf sont celles de chaque scénario du banc (Global Constraints) ; la trace de la Task 0.

- [ ] **Step 5 : commit**

```bash
git add Scripts/PredictionLocale.gd tests/prediction_test.gd
git commit -m "Journal de la prédiction hors du jeu livré (M5 de la revue finale 16) : déjà borné, il n'est plus tenu que dans les builds de débogage (les tests, l'éditeur), jamais dans l'exe d'export release ; le banc vérifie qu'une prédiction sans journal ne change pas

<ligne fournie par l'environnement>"
```

---

### Task 5 : l'exe porte le nom, la version et l'icône du jeu ; la CI les vérifie et lance la vraie diffusion (`export_presets.cfg`, `ci.yml`)

**Files:**
- Modify: `export_presets.cfg` (`[preset.1.options]`)
- Modify: `.github/workflows/ci.yml` (pas « Test réseau » ; pas neuf après « Exporter pour Windows »)
- Modify: `tests/reseau/lancer.sh` (commentaire d'en-tête)

**Interfaces:**
- Consumes (Task 1) : `application/config/version="0.19"` ; `config/icon="res://icon.png"` (512×512, inchangée).
- Produces (Tasks 7, 8, 9) : un `LeLion-multi.exe` dont la ressource de version dit « LeLion multi », « w3cdotorg », « 0.19.0.0 », à l'icône du jeu ; le pas « Vérifier l'icône et les métadonnées de l'exécutable Windows » ; le test réseau de la CI avec `DIFFUSION=1`.

Aucun modèle d'export sur ce Mac (spec §11) : l'export et ses vérifications ne tournent qu'en CI (Task 9, une fois la PR ouverte). Ici, le fichier de CI est vérifié par `actionlint`, et le test réseau avec la vraie diffusion localement (Task 1, Step 5). Godot 4.7 modifie lui-même les ressources de l'exe (`platform/windows/export/template_modifier.cpp`, sans `rcedit` : vérifié dans le binaire de l'éditeur de ce Mac, qui ne nomme plus `rcedit`) : `application/modify_resources=true` suffit sur le runner Linux ; `application/icon` vide prend l'icône du projet (`config/icon`), redimensionnée (`icon_interpolation`) ; `file_version` et `product_version` vides prennent la version du projet (« Leave empty to use project version »), sur quatre nombres pour Windows (attendu : « 0.19.0.0 », ce que la CI vérifie).

- [ ] **Step 1 : le preset**

Dans `export_presets.cfg`, remplacer :

```ini
application/modify_resources=false
```

par :

```ini
application/modify_resources=true
```

Dans `export_presets.cfg`, remplacer :

```ini
application/company_name=""
application/product_name="LeLion multi"
application/file_description="LeLion multi"
application/copyright=""
```

par :

```ini
application/company_name="w3cdotorg"
application/product_name="LeLion multi"
application/file_description="LeLion multi"
application/copyright="Copyright 2026 w3cdotorg, GPL-3.0"
```

- [ ] **Step 2 : la CI**

Dans `.github/workflows/ci.yml`, remplacer :

```yaml
      - name: Test réseau (plusieurs processus sur localhost, dont une manche sous latence simulée)
        shell: bash
        run: |
          set -o pipefail
          timeout 300 bash tests/reseau/lancer.sh 2>&1 | tee reseau.log
```

par :

```yaml
      - name: Test réseau (plusieurs processus sur localhost, dont une manche sous latence simulée et la découverte en vraie diffusion)
        shell: bash
        run: |
          set -o pipefail
          DIFFUSION=1 timeout 300 bash tests/reseau/lancer.sh 2>&1 | tee reseau.log
```

Dans `.github/workflows/ci.yml`, remplacer :

```yaml
          test -s export/windows/LeLion-multi.exe
          ls -l export/windows
```

par :

```yaml
          test -s export/windows/LeLion-multi.exe
          ls -l export/windows

      - name: Vérifier l'icône et les métadonnées de l'exécutable Windows
        shell: bash
        run: |
          set -euo pipefail
          sudo apt-get update -qq
          sudo apt-get install -y -qq icoutils > /dev/null
          EXE=export/windows/LeLion-multi.exe
          MODELE="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable/windows_release_x86_64.exe"
          VERSION="$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)"
          # Les chaînes de la ressource de version (UTF-16) : le nom que montrent l'explorateur et la
          # fenêtre du pare-feu, la version du jeu sur quatre nombres.
          wrestool -x --type=16 "$EXE" | strings -el > version_exe.txt
          cat version_exe.txt
          grep -qxF "LeLion multi" version_exe.txt || { echo "::error::le nom LeLion multi manque aux métadonnées de l'exe"; exit 1; }
          grep -qxF "${VERSION}.0.0" version_exe.txt || { echo "::error::la version ${VERSION}.0.0 manque aux métadonnées de l'exe"; exit 1; }
          if [ "$(wrestool -x --type=3 "$EXE" | sha256sum)" = "$(wrestool -x --type=3 "$MODELE" | sha256sum)" ]; then
            echo "::error::l'exe porte encore l'icône de Godot"; exit 1
          fi
```

- [ ] **Step 3 : le commentaire du lanceur**

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
# DIFFUSION=1 (ajoute le scénario 7, balises en vraie diffusion : hors CI, où la diffusion n'a pas
# été mesurée ; le scénario 6 couvre le même chemin en envoi direct vers 127.0.0.1).
```

par :

```bash
# DIFFUSION=1 (ajoute le scénario 7, balises en vraie diffusion ; le pas « Test réseau » de la CI le
# pose depuis la phase 19 ; le scénario 6 couvre le même chemin en envoi direct vers 127.0.0.1).
```

- [ ] **Step 4 : vérifier**

Run : `export PATH="/opt/homebrew/bin:$PATH"; actionlint .github/workflows/ci.yml && echo "actionlint ok"; bash -n tests/reseau/lancer.sh && echo "lanceur ok"; grep -nE "modify_resources|company_name|copyright" export_presets.cfg`
Expected : `actionlint ok` (vérifié en préparant ce plan), `lanceur ok`, `modify_resources=true` et les deux valeurs neuves dans `[preset.1.options]` seulement (le preset Web n'a pas ces clés).

Le vrai verdict vient de la CI de la PR (Task 9, Step 4) : le pas « Exporter pour Windows » vert sans message `rcedit`, puis le pas neuf qui affiche `version_exe.txt` (« LeLion multi », « w3cdotorg », « 0.19.0.0 », le copyright) et passe. Si l'export échoue ou que la vérification ne trouve pas ces chaînes, **ne rien affaiblir** : s'arrêter et rapporter le journal du pas (la cause décidera du remède).

- [ ] **Step 5 : commit**

```bash
git add export_presets.cfg .github/workflows/ci.yml tests/reseau/lancer.sh
git commit -m "Exe Windows à l'icône et au nom du jeu : l'export écrit ses ressources (LeLion multi, w3cdotorg, la version du jeu sur quatre nombres, l'icône du projet), que la CI vérifie dans l'exe (wrestool) ; le test réseau de la CI lance aussi la découverte en vraie diffusion (DIFFUSION=1)

<ligne fournie par l'environnement>"
```

---

### Task 6 : les captures versées au dépôt : `tests/screenshots.gd` en parties, `tests/deux_fenetres.gd`, et leur déroulé en CI (◉ livraison)

**Files:**
- Modify: `tests/screenshots.gd` (réécrit : les parties `solo`, `reseau`, `salon`, `bataille`, `resultats`)
- Create: `tests/deux_fenetres.gd` (+ `tests/deux_fenetres.gd.uid`, généré par l'import)
- Modify: `.github/workflows/ci.yml` (pas neuf « Captures (déroulé sans rendu…) », avant « Exporter en Web »)

**Interfaces:**
- Consumes : `Titre.demo_autorisee`, `Titre.bouton_multijoueur` ; `EcranReseau.port_jeu`, `champ_pseudo`, `champ_ip`, `boutons_parties`, `heberger`, `rejoindre_par_ip` ; `Decouverte.port_balise`, `destinations_forcees`, `parties`, `parties_changees`, `enregistrer_partie(liste, ip, fiche, maintenant_ms)` ; `Reseau.heberger(port)`, `rejoindre(adresse, port)`, `quitter`, `inscrits`, `_sur_pair_connecte`, `definir_pret`, `table_salon`, `niveau_salon`, `places_reservees`, `salon_change`, `refuse`, `REFUS_VERSION`, `version`, `pseudo` ; `Salon.changer_niveau`, `retour(false)`, `basculer_pret`, `bouton_demarrer`, `demarrer` ; `Main.lion`, `lions`, `ville`, `hud_bataille.marquer_parti`, `_oublier_lion`, `resultats`, `menu_pause.ouvrir`/`reprendre`, le nœud `HotePerdu` ; `Resultats.afficher`, `terminer_animation`, `marquer_parti`, `_deplacer_selection`, `bilan` ; `Territoire.appliquer_changements`, `taille_grille`, `_peignables` ; `ReglesBataille.duree_manche`, `DUREE_MANCHE`.
- Produces (Tasks 7, 9) : `godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier=<d> [--parties=…]` (37 captures) ; `tests/deux_fenetres.gd -- --role=hote|client --dossier=<d>` (5 et 6 captures) ; sans rendu, une ligne `📸 <nom> (headless : rien d'écrit)` par capture.

Les scripts jetables des phases 12 bis (Task 3), 13 (Task 5), 14 (Task 9), 17 (Task 8) et 18 (Task 8), versés ici et adaptés au code de la phase 18 (Écart 9) : les ports et les pseudos de leurs captures ne changent pas ; la capture « hébergée » de l'écran Réseau n'existe plus (l'hébergement mène au salon depuis la phase 13 : ses captures sont celles de la partie `salon`), le salon vu d'un client gagne celle du joueur qui arrive (phase 18), la bataille ne capture plus le panneau de fin de la phase 17 (la partie `resultats` le remplace), la partie à deux fenêtres va jusqu'aux Résultats et à l'hôte perdu. Chaque script, sans rendu (`--headless`), déroule tout sans rien écrire : c'est ainsi que la CI les garde en vie.

- [ ] **Step 1 : `tests/screenshots.gd`**

Remplacer tout le contenu de `tests/screenshots.gd` par :

```gdscript
extends SceneTree
## Captures pilotées, avec le vrai rendu (pas headless ; la CI ne les lance pas) :
##   godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier=<dossier> [--parties=solo,reseau,salon,bataille,resultats]
## Écrit ses PNG dans <dossier> (défaut : user://), par partie (toutes par défaut) :
##   solo       le titre, une partie solo (gerbe à 3 puis 7 couleurs, ennemis, pause, défaite), une
##              victoire avec record, le peintre du Village ;
##   reseau     le titre et son bouton Multijoueur, l'écran Réseau (vide, liste, IP invalide, connexion,
##              refus de version, anglais, port des balises occupé ; phase 12 bis) ;
##   salon      l'hôte seul, le salon à 3 (bouton grisé puis actif), à 6 aux pseudos larges, en anglais,
##              vu d'un client (tous prêts, un joueur qui arrive ; phase 13) ;
##   bataille   la manche à 6 couleurs (départ, en jeu : parts, rangs, couronnes, crans, gerbe XXL,
##              étourdi, parti ; les dix dernières secondes), une égalité à 2 en anglais (phase 17) ;
##   resultats  l'écran Résultats d'une bataille à 6 (animation, hôte local, client, hôte en réseau,
##              hôte resté seul), une égalité à 2 en anglais (phase 18).
## La partie à deux vraies fenêtres (un hôte et un client) est dans `tests/deux_fenetres.gd`, une vraie
## manche à 4 capturée dans `tests/bataille_test.gd -- --captures=<dossier>`.
## N'utilise ni le port 7777 ni le 7778 d'une vraie partie, ni les records et réglages du joueur
## (`user://scores_captures.cfg`, effacé à la fin). Ennemis et pastilles écartés en bataille : les
## scores, crans, statistiques et départs sont posés à la main. Compilé avant les autoloads : les lit
## par `root.get_node`, charge les scènes à l'exécution.

const PARTIES := ["solo", "reseau", "salon", "bataille", "resultats"]
const PORT_JEU := 17890
const PORT_SANS_HOTE := 17891
const PORT_BALISE := 17899

var dossier := "user://"
var parties: PackedStringArray = PackedStringArray(PARTIES)
var GS: Node


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dossier="):
			dossier = arg.trim_prefix("--dossier=")
		elif arg.begins_with("--parties="):
			parties = arg.trim_prefix("--parties=").split(",", false)
	call_deferred("_run")


func _attendre(secondes: float) -> void:
	await create_timer(secondes, true).timeout


func _shot(nom: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("📸 %s (headless : rien d'écrit)" % nom)  # le déroulé seul se vérifie
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var chemin := dossier.path_join(nom + ".png")
	image.save_png(chemin)
	print("📸 %s (%dx%d)" % [chemin, image.get_width(), image.get_height()])


func _run() -> void:
	for partie in parties:
		if not PARTIES.has(partie):
			printerr("--parties : « %s » inconnue (%s)" % [partie, ", ".join(PARTIES)])
			quit(1)
			return
	GS = root.get_node("GameState")
	var scores: Node = root.get_node("Scores")
	scores.chemin = "user://scores_captures.cfg"
	scores.effacer()
	root.get_node("Parametres").definir_langue("fr")
	if parties.has("solo"):
		await _solo()
	# Une fenêtre au format du multi, même si les réglages de ce poste demandent le plein écran
	# (préférence non modifiée) : `Regles.appliquer_ecran` ne règle que les fenêtres.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1400, 788))
	if parties.has("reseau"):
		await _reseau()
	if parties.has("salon"):
		await _salon()
	if parties.has("bataille"):
		await _bataille()
	if parties.has("resultats"):
		await _resultats()
	root.get_node("Parametres").definir_langue("fr")
	GS.configurer_solo()
	scores.effacer()
	quit(0)


# --- Solo ------------------------------------------------------------------------------------------


func _solo() -> void:
	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _attendre(0.2)
	await _shot("00_titre")
	titre.free()
	var main: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _attendre(0.15)
	main.get_node("Spawner").spawn_pickup(0, Vector2(900, 250))
	await _attendre(0.1)
	await _shot("01_depart")

	var lion: CharacterBody2D = main.get_node("Lion")
	var spawner: Node = main.get_node("Spawner")
	var ville: Node2D = main.get_node("Ville")
	for i in range(3):
		GS.regles.pastille_ramassee(GS.joueur_local(), i)
	await _attendre(0.1)
	lion.global_position = Vector2(500, ville.position.y - 330)
	Input.action_press("vomir")
	await _attendre(1.00)
	await _shot("02_vomi_droite_3_couleurs")
	Input.action_press("deplacer_droite")
	await _attendre(1.50)
	Input.action_release("deplacer_droite")
	Input.action_release("vomir")
	await _attendre(0.1)
	for i in range(3, 7):
		GS.regles.pastille_ramassee(GS.joueur_local(), i)
	Input.action_press("deplacer_gauche")
	await _attendre(0.1)
	Input.action_press("vomir")
	await _attendre(0.83)
	Input.action_release("deplacer_gauche")
	spawner.spawn_soucoupe(300)
	spawner.spawn_coccinelle(250)
	spawner.spawn_bonus(Vector2(1300, 220))
	spawner.spawn_coeur(Vector2(1600, 300))
	GS.joueur_local().activer_bonus(8.0)
	GS.regles.lion_touche_par_ennemi(GS.joueur_local(), Vector2.INF)
	GS.joueur_local().invulnerable_restant = 0.0
	await _attendre(0.75)
	await _shot("03_vomi_gauche_7_couleurs_ennemis")
	Input.action_release("vomir")
	main.get_node("PauseMenu").ouvrir()
	await _attendre(0.2)
	await _shot("03b_pause")
	main.get_node("PauseMenu").reprendre()
	GS.terminer_partie(false)
	await _attendre(3.5)
	await _shot("04_game_over")

	# Victoire avec record précédent, un coup encaissé en route
	paused = false
	main.free()
	root.get_node("Scores").effacer()
	root.get_node("Scores").enregistrer("skyline/facile", 95.0)
	GS.niveau_courant = 0
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _attendre(0.2)
	for i in range(7):
		GS.regles.pastille_ramassee(GS.joueur_local(), i)
	# Phase 19 : le coup après la fin de l'intro (`GameState.demarrer`) ; pendant l'intro, les règles
	# l'ignorent (la manche n'est pas encore en cours).
	while not GS.pret:
		await process_frame
	GS.temps_ecoule = 71.0
	GS.regles.lion_touche_par_ennemi(GS.joueur_local(), Vector2.INF)
	GS.signaler_progression(0.91)
	await _attendre(1.2)
	await _shot("04b_victoire_animation")
	await _attendre(3.0)
	await _shot("04b_victoire")
	root.get_node("Scores").effacer()
	paused = false
	main.free()

	# Village : le boss au centre
	GS.niveau_courant = 2
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await _attendre(0.2)
	var boss: Node = get_first_node_in_group("boss")
	for i in range(7):
		GS.regles.pastille_ramassee(GS.joueur_local(), i)
	main.get_node("Lion").global_position = Vector2(1500, 150)
	boss.cote = 1
	boss._changer_etat(boss.Etat.ENTREE)
	await _attendre(3.2)
	Input.action_press("vomir")
	await _attendre(0.8)
	await _shot("05_village_boss")
	Input.action_release("vomir")
	main.free()
	current_scene = null


# --- Écran Réseau (phase 12 bis) --------------------------------------------------------------------


func _reseau() -> void:
	var scores: Node = root.get_node("Scores")
	var params: Node = root.get_node("Parametres")
	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	scores.definir_preference("pseudo", "MMMMMMMMMMMM")  # 12 caractères larges : le champ doit les tenir
	decouverte.port_balise = PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])

	var titre: Control = load("res://Scenes/Titre.tscn").instantiate()
	titre.demo_autorisee = false
	root.add_child(titre)
	await _attendre(0.3)
	await _shot("reseau_00_titre_multijoueur")
	titre.bouton_multijoueur.grab_focus()
	await _attendre(0.1)
	await _shot("reseau_01_titre_focus_multijoueur")
	titre.free()

	var ecran: Control = load("res://Scenes/EcranReseau.tscn").instantiate()
	ecran.port_jeu = PORT_JEU
	root.add_child(ecran)
	await _attendre(0.3)
	await _shot("reseau_02_vide")

	var futur := Time.get_ticks_msec() + 600000  # ces parties n'expirent pas pendant les captures
	var zoe := {"version": reseau.version, "port": 7777, "nb_joueurs": 2, "places": 6, "manche_en_cours": false, "niveau": 1, "pseudo": "Zoé"}
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.20", zoe, futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.21", zoe.merged({"pseudo": "Anna", "nb_joueurs": 6}, true), futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.22", zoe.merged({"pseudo": "Bob", "version": "0.10"}, true), futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.23", zoe.merged({"pseudo": "Chloé", "manche_en_cours": true, "niveau": 2}, true), futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.24", zoe.merged({"pseudo": "MMMMMMMMMMMM", "nb_joueurs": 5, "niveau": 0}, true), futur)
	decouverte.parties_changees.emit()
	await _attendre(0.2)
	await _shot("reseau_03_liste")
	ecran.boutons_parties["192.168.1.20:7777"].grab_focus()
	await _attendre(0.1)
	await _shot("reseau_04_focus_partie")

	ecran.champ_ip.text = "lelion.local"
	ecran.rejoindre_par_ip()
	await _attendre(0.1)
	await _shot("reseau_05_ip_invalide")

	ecran.champ_ip.text = "127.0.0.1"
	ecran.port_jeu = PORT_SANS_HOTE
	ecran.rejoindre_par_ip()
	await _attendre(0.1)
	await _shot("reseau_06_connexion")
	reseau.quitter()
	reseau.refuse.emit(reseau.REFUS_VERSION, "0.10")
	await _attendre(0.1)
	await _shot("reseau_07_refus_version")

	params.definir_langue("en")
	decouverte.parties.clear()
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.20", zoe, futur)
	decouverte.enregistrer_partie(decouverte.parties, "192.168.1.21", zoe.merged({"pseudo": "Anna", "nb_joueurs": 6}, true), futur)
	decouverte.parties_changees.emit()
	await _attendre(0.2)
	await _shot("reseau_08_anglais")
	params.definir_langue("fr")
	ecran.free()
	decouverte.parties.clear()

	var intrus := PacketPeerUDP.new()
	intrus.bind(decouverte.port_balise, "0.0.0.0")
	var ecran2: Control = load("res://Scenes/EcranReseau.tscn").instantiate()
	root.add_child(ecran2)
	await _attendre(0.3)
	await _shot("reseau_09_ecoute_impossible")
	ecran2.free()
	intrus.close()


# --- Salon (phase 13) ------------------------------------------------------------------------------


## Un autre joueur arrive au salon de l'hôte (simulé dans `Reseau.inscrits`, comme le smoke test).
func _arrive(reseau: Node, id: int, index: int, couleur: Color, pseudo: String, pret: bool) -> void:
	reseau.inscrits[id] = {"index": index, "couleur": couleur, "pseudo": pseudo, "arrive": false, "pret": false}
	reseau._sur_pair_connecte(id)
	if pret:
		reseau.definir_pret(id, true)


func _salon() -> void:
	var params: Node = root.get_node("Parametres")
	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	var palette: Array[Color] = EtatPartie.PALETTE_BATAILLE
	decouverte.port_balise = PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	GS.niveau_courant = 1

	# L'hôte seul, pseudo de 12 caractères larges : Démarrer grisé, « Il faut au moins 2 joueurs »
	reseau.pseudo = "MMMMMMMMMMMM"
	reseau.heberger(PORT_JEU)
	var salon: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(salon)
	await _attendre(0.4)
	await _shot("salon_00_hote_seul")

	# ◉ Salon à 3 : l'hôte, Bob prêt, Zoé pas encore : Démarrer grisé avec sa raison
	_arrive(reseau, 5, 1, palette[1], "Bob", true)
	_arrive(reseau, 6, 2, palette[4], "Zoé", false)
	await _attendre(0.2)
	await _shot("salon_01_a_3")

	# Tous prêts : Démarrer s'active chez l'hôte
	reseau.definir_pret(1, true)
	reseau.definir_pret(6, true)
	await _attendre(0.3)
	await _shot("salon_02_bouton_actif")
	reseau.definir_pret(6, false)
	await _attendre(0.2)

	# Six joueurs, pseudos larges, niveau Village
	_arrive(reseau, 7, 3, palette[3], "WWWWWWWWWWWW", true)
	_arrive(reseau, 8, 4, palette[2], "Chloé", false)
	_arrive(reseau, 9, 5, palette[5], "Léa-Marie 2", true)
	salon.changer_niveau(1)
	await _attendre(0.2)
	await _shot("salon_03_a_6")
	params.definir_langue("en")
	await _attendre(0.2)
	await _shot("salon_04_anglais")
	params.definir_langue("fr")
	salon.retour(false)
	salon.free()

	# Un client : sa vue de la table (celle que l'hôte lui diffuserait)
	reseau.rejoindre("127.0.0.1", PORT_SANS_HOTE)
	var id_local: int = root.multiplayer.get_unique_id()
	reseau.table_salon.assign([
		{"id": 1, "index": 0, "couleur": palette[0], "pseudo": "Hôte", "pret": true},
		{"id": id_local, "index": 1, "couleur": palette[3], "pseudo": "Moi", "pret": false},
		{"id": 12, "index": 3, "couleur": palette[5], "pseudo": "Tom", "pret": true}])
	reseau.niveau_salon = 0
	var client: Control = load("res://Scenes/Salon.tscn").instantiate()
	root.add_child(client)
	await _attendre(0.4)
	await _shot("salon_05_client")
	reseau.table_salon[1].pret = true
	reseau.salon_change.emit()
	await _attendre(0.2)
	await _shot("salon_06_client_tous_prets")
	# Phase 18 : un joueur arrive encore (une place réservée, sans carte) : le client le sait
	reseau.places_reservees = 1
	reseau.salon_change.emit()
	await _attendre(0.2)
	await _shot("salon_07_client_joueur_qui_arrive")
	client.free()
	reseau.quitter()


# --- Bataille et Résultats (phases 17 et 18) ---------------------------------------------------------


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


## Une bataille locale à `nb` (ce poste est l'hôte, le joueur 1 est « TOI ») sur le niveau `niveau`,
## ennemis et pastilles écartés à chaque image, jusqu'à la fin de l'intro.
func _charger(nb: int, pseudos: Array, niveau: int) -> Node:
	paused = false
	GS.niveau_courant = niveau
	GS.difficulte_courante = 0
	GS.configurer_bataille(nb)
	for i in range(nb):
		GS.joueurs[i].pseudo = pseudos[i]
	change_scene_to_file("res://Scenes/Main.tscn")
	await _attendre(0.3)
	var main: Node = current_scene
	if not physics_frame.is_connected(_ecarter_ennemis):
		physics_frame.connect(_ecarter_ennemis)
	while not GS.pret:
		await process_frame
	return main


func _ecarter_ennemis() -> void:
	for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss") + get_nodes_in_group("pickup"):
		ennemi.queue_free()


func _poser_lions(main: Node, places: Array) -> void:
	for i in range(main.lions.size()):
		var l: Node2D = main.lions[i]
		l.global_position = places[i]
		l.deplacement.vitesse = Vector2.ZERO
		l.deplacement.recul = Vector2.ZERO


func _quitter_la_bataille() -> void:
	physics_frame.disconnect(_ecarter_ennemis)
	paused = false
	if current_scene != null:
		current_scene.free()
		current_scene = null
	GS.configurer_solo()


func _bataille() -> void:
	var params: Node = root.get_node("Parametres")
	var main := await _charger(6, ["Clément", "WWWWWWWWWWWW", "Zoé", "Bob", "Léa-Marie 2", "Max"], 1)
	var t: Territoire = main.ville.territoire
	_poser_lions(main, [Vector2(150, 520), Vector2(620, 600), Vector2(700, 600), Vector2(1250, 450), Vector2(1600, 300), Vector2(1864, 700)])
	await _attendre(0.3)
	await _shot("bataille_01_depart_a_6")

	# ◉ Manche à 6 couleurs : des parts de la ville, des crans, une gerbe XXL, un étourdi, un parti ;
	# deux lions côte à côte
	_poser_scores(t, [260, 410, 180, 90, 410, 30])
	for i in range(3):
		GS.joueurs[0].gagner_cran()
	for i in range(6):
		GS.joueurs[1].gagner_cran()
	GS.joueurs[4].gagner_cran()
	GS.regles.etoile_ramassee(GS.joueurs[0])
	GS.regles.lion_touche_par_ennemi(GS.joueurs[3], Vector2.INF)
	main.hud_bataille.marquer_parti(5)
	var parti: Node = main.lions[5]
	main._oublier_lion(parti)  # comme un départ en réseau : son lion disparaît
	parti.queue_free()
	GS.temps_ecoule = 41.2
	await _attendre(0.4)
	_poser_lions(main, [Vector2(150, 520), Vector2(620, 600), Vector2(712, 600), Vector2(1250, 450), Vector2(1600, 300)])
	await _attendre(0.1)
	await _shot("bataille_02_en_jeu_a_6")

	# Les dix dernières secondes : le chrono rouge
	GS.temps_ecoule = 84.35
	await _attendre(0.2)
	await _shot("bataille_03_dix_dernieres_secondes")

	# À deux, ex æquo, en anglais
	params.definir_langue("en")
	main = await _charger(2, ["Anna", "Bruno"], 0)
	_poser_lions(main, [Vector2(0, 500), Vector2(95, 500)])
	_poser_scores(main.ville.territoire, [300, 300])
	GS.temps_ecoule = 60.0
	await _attendre(0.3)
	await _shot("bataille_04_egalite_a_2_anglais")
	params.definir_langue("fr")
	_quitter_la_bataille()


## Un autre écran Résultats sur la même fin, vu d'un autre poste (`hote`, `en_reseau`), à la place du
## premier.
func _revoir(main: Node, hote: bool, en_reseau: bool) -> CanvasLayer:
	var bilan: BilanManche = main.resultats.bilan
	main.resultats.free()
	var vue: CanvasLayer = load("res://Scenes/Resultats.tscn").instantiate()
	main.add_child(vue)
	main.resultats = vue
	vue.afficher(bilan, hote, en_reseau)
	vue.terminer_animation()
	return vue


func _resultats() -> void:
	var params: Node = root.get_node("Parametres")
	var main := await _charger(6, ["Clément", "WWWWWWWWWWWW", "Zoé", "Bob", "Léa-Marie 2", "Max"], 1)
	_poser_scores(main.ville.territoire, [260, 410, 180, 90, 410, 30])
	var stats := [[3, 120, 9], [5, 340, 4], [0, 60, 12], [1, 0, 2], [5, 280, 4], [0, 0, 1]]
	for i in range(6):
		GS.joueurs[i].etourdissements_infliges = stats[i][0]
		GS.joueurs[i].cellules_volees = stats[i][1]
		GS.joueurs[i].chocs = stats[i][2]
	main.hud_bataille.marquer_parti(5)
	GS.temps_ecoule = 89.5
	while GS.partie_en_cours:
		await process_frame
	await _attendre(0.9)
	await _shot("resultats_01_animation")
	main.resultats.marquer_parti(5)
	await _attendre(3.0)
	await _shot("resultats_02_hote_local_a_6")
	var vue := _revoir(main, false, true)
	vue.marquer_parti(5)
	await _attendre(0.3)
	await _shot("resultats_03_client")
	vue = _revoir(main, true, true)
	vue.marquer_parti(5)
	vue._deplacer_selection(1)
	await _attendre(0.3)
	await _shot("resultats_04_hote_reseau_niveau_suivant")
	for i in range(1, 5):
		vue.marquer_parti(i)
	await _attendre(0.3)
	await _shot("resultats_05_hote_seul")
	params.definir_langue("en")
	main = await _charger(2, ["Anna", "Bruno"], 2)
	_poser_scores(main.ville.territoire, [300, 300])
	GS.joueurs[0].chocs = 6
	GS.joueurs[1].chocs = 6
	GS.temps_ecoule = 89.5
	while GS.partie_en_cours:
		await process_frame
	_revoir(main, true, true)
	await _attendre(0.3)
	await _shot("resultats_06_egalite_a_2_anglais")
	params.definir_langue("fr")
	_quitter_la_bataille()
```

- [ ] **Step 2 : `tests/deux_fenetres.gd`**

Créer `tests/deux_fenetres.gd` :

```gdscript
extends SceneTree
## Une partie à deux vraies fenêtres sur ce poste (◉, phases 14 et 19 ; la CI ne la lance pas) : un hôte
## et un client passent par l'écran Réseau et le salon, jouent une manche courte au clavier simulé,
## voient le même écran Résultats, puis l'hôte quitte et le client le voit partir. Deux processus :
##   godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=hote --dossier=<dossier>
##   godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=client --dossier=<dossier>
## (dans n'importe quel ordre : le client attend que l'hôte héberge). Chaque fenêtre capture sa vue au même instant que l'autre (fichiers
## de rendez-vous dans le dossier) : `hote_*.png`, `client_*.png`. Sans rendu (headless), le déroulé seul
## se vérifie, rien n'est écrit. N'utilise ni le port 7777 ni le 7778 d'une vraie partie, ni les records
## et réglages du joueur.

const PORT := 17990
const PORT_BALISE := 18990
## La manche, raccourcie sur les deux postes (le chrono de l'hôte la termine ; celui du client s'affiche).
const DUREE_MANCHE := 15.0

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
	await create_timer(secondes, true).timeout


func _scene_est(nom: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://Scenes/%s.tscn" % nom and current_scene.is_node_ready()


func _shot(nom: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("📸 %s_%s (headless : rien d'écrit)" % [role, nom])
		return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var chemin := dossier.path_join("%s_%s.png" % [role, nom])
	image.save_png(chemin)
	print("📸 %s (%dx%d, fenêtre %s)" % [chemin, image.get_width(), image.get_height(), DisplayServer.window_get_size()])


## Ce poste a passé l'étape `nom` : un fichier de rendez-vous dans le dossier.
func _signaler(nom: String) -> void:
	FileAccess.open(dossier.path_join("%s_%s" % [role, nom]), FileAccess.WRITE).store_string("ok")


## Attend que l'autre poste ait passé l'étape `nom` (30 s au plus).
func _attendre_l_autre(nom: String) -> void:
	var autre := "client" if role == "hote" else "hote"
	if not await _attendre(func() -> bool: return FileAccess.file_exists(dossier.path_join("%s_%s" % [autre, nom]))):
		printerr("❌ l'autre poste n'a pas passé l'étape « %s »" % nom)


## Les deux postes au même point.
func _rendez_vous(nom: String) -> void:
	_signaler(nom)
	await _attendre_l_autre(nom)


func _run() -> void:
	if dossier.is_empty() or not role in ["hote", "client"]:
		printerr("--role=hote|client et --dossier=<chemin>")
		quit(1)
		return
	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	var scores: Node = root.get_node("Scores")
	var gs: Node = root.get_node("GameState")
	scores.chemin = "user://scores_deux_fenetres_%s.cfg" % role
	scores.effacer()
	root.get_node("Parametres").definir_langue("fr")
	decouverte.port_balise = PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	ReglesBataille.duree_manche = DUREE_MANCHE
	# Une fenêtre, même si les réglages de ce poste demandent le plein écran (préférence non modifiée) :
	# `Regles.appliquer_ecran` ne règle que les fenêtres.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await _pause(0.5)
	DisplayServer.window_set_position(Vector2i(20, 40) if role == "hote" else Vector2i(740, 440))
	DisplayServer.window_set_size(Vector2i(700, 227))  # la fenêtre du solo, en plus petit : deux tiennent à l'écran

	# L'écran Réseau, puis le salon
	change_scene_to_file("res://Scenes/EcranReseau.tscn")
	await _attendre(func() -> bool: return _scene_est("EcranReseau"))
	var ecran: Node = current_scene
	ecran.port_jeu = PORT
	ecran.champ_pseudo.text = "Hôte" if role == "hote" else "Invitée"
	if role == "hote":
		ecran.heberger()
		_signaler("heberge")
	else:
		await _attendre_l_autre("heberge")
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

	# La manche : descendre vers la ville, puis la peindre vers l'autre joueur
	await _attendre(func() -> bool: return _scene_est("Main"))
	var main: Node = current_scene
	await _attendre(func() -> bool: return gs.pret)
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
		main.menu_pause.ouvrir()
		await _pause(0.3)
		await _shot("3_menu_local")
		main.menu_pause.reprendre()

	# La fin au chrono de l'hôte : le même écran Résultats sur les deux postes
	await _attendre(func() -> bool: return main.resultats != null, DUREE_MANCHE + 10.0)
	await _pause(0.3)
	main.resultats.terminer_animation()
	await _pause(0.3)
	await _rendez_vous("resultats")
	await _shot("4_resultats")

	# L'hôte quitte ; le client le voit partir, puis revient au titre
	await _rendez_vous("fin")
	if role == "hote":
		reseau.quitter()
		await _pause(0.5)
	else:
		await _attendre(func() -> bool: return main.get_node_or_null("HotePerdu") != null, 10.0)
		await _pause(0.2)
		await _shot("5_hote_perdu")
		await _attendre(func() -> bool: return _scene_est("Titre"), 5.0)
		await _pause(0.3)
		await _shot("6_titre")
	ReglesBataille.duree_manche = ReglesBataille.DUREE_MANCHE
	scores.effacer()
	quit(0)
```

- [ ] **Step 3 : le déroulé sans rendu, en CI**

Dans `.github/workflows/ci.yml`, remplacer :

```yaml
      - name: Exporter en Web
```

par :

```yaml
      - name: Captures (déroulé sans rendu, les scripts de captures gardés en vie)
        shell: bash
        run: |
          set -o pipefail
          D="$(mktemp -d)"
          timeout 180 godot --headless --script tests/screenshots.gd -- --dossier="$D" 2>&1 | tee captures.log
          timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=client --dossier="$D" > deux_fenetres_client.log 2>&1 &
          CLIENT=$!
          timeout 120 godot --headless --script tests/deux_fenetres.gd -- --role=hote --dossier="$D" 2>&1 | tee deux_fenetres_hote.log
          wait "$CLIENT"
          cat deux_fenetres_client.log
          if grep -nE "SCRIPT ERROR|SHADER ERROR|❌" captures.log deux_fenetres_hote.log deux_fenetres_client.log; then echo "::error::erreur dans un script de captures"; exit 1; fi
          [ "$(grep -c "📸" captures.log)" -eq 37 ] || { echo "::error::tests/screenshots.gd n'a pas déroulé ses 37 captures"; exit 1; }
          [ "$(grep -c "📸" deux_fenetres_hote.log)" -eq 5 ] && [ "$(grep -c "📸" deux_fenetres_client.log)" -eq 6 ] \
            || { echo "::error::tests/deux_fenetres.gd n'a pas déroulé ses captures (5 pour l'hôte, 6 pour le client)"; exit 1; }

      - name: Exporter en Web
```

- [ ] **Step 4 : le déroulé sans rendu, ici**

Run :

```bash
export PATH="/opt/homebrew/bin:$PATH"; godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error"; ls tests/deux_fenetres.gd.uid
actionlint .github/workflows/ci.yml && echo "actionlint ok"
D="$TMPDIR/captures-19-deroule"; rm -rf "$D"; mkdir -p "$D"
timeout -k 5 180 godot --headless --script tests/screenshots.gd -- --dossier="$D" > "$TMPDIR/cap.log" 2>&1; echo "code $?"
(timeout -k 5 120 godot --headless --script tests/deux_fenetres.gd -- --role=client --dossier="$D" > "$TMPDIR/f_client.log" 2>&1 &)
timeout -k 5 120 godot --headless --script tests/deux_fenetres.gd -- --role=hote --dossier="$D" > "$TMPDIR/f_hote.log" 2>&1; echo "code hote $?"
timeout 30 bash -c 'while pgrep -f "deux_fenetres.gd -- --role=client" > /dev/null; do sleep 0.5; done'
grep -E "SCRIPT ERROR|SHADER ERROR|❌" "$TMPDIR/cap.log" "$TMPDIR/f_hote.log" "$TMPDIR/f_client.log"
echo $(grep -c "📸" "$TMPDIR/cap.log") $(grep -c "📸" "$TMPDIR/f_hote.log") $(grep -c "📸" "$TMPDIR/f_client.log")
```

Expected (mesuré en préparant ce plan) : rien à l'import, le `.uid` listé, `actionlint ok`, `code 0` et `code hote 0`, aucune ligne d'erreur, puis `37 5 6` (en une quarantaine de secondes pour le premier, une vingtaine pour les deux postes, qui se lancent dans n'importe quel ordre).

- [ ] **Step 5 : les vraies captures (◉ livraison)**

Run (des fenêtres s'ouvrent le temps des scripts ; si le réglage « plein écran » de ce Mac est actif, les scripts les forcent en fenêtre sans changer la préférence) :

```bash
export PATH="/opt/homebrew/bin:$PATH"; D="$TMPDIR/captures-19"; rm -rf "$D"; mkdir -p "$D/deux_fenetres" "$D/manche"
timeout -k 5 180 godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier="$D" > "$TMPDIR/c1.log" 2>&1; echo "code $?"
(timeout -k 5 120 godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=client --dossier="$D/deux_fenetres" > "$TMPDIR/c2.log" 2>&1 &)
timeout -k 5 120 godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=hote --dossier="$D/deux_fenetres" > "$TMPDIR/c3.log" 2>&1; echo "code $?"
timeout 30 bash -c 'while pgrep -f "deux_fenetres.gd -- --role=client" > /dev/null; do sleep 0.5; done'
timeout -k 5 300 godot --path . --rendering-driver opengl3 --fixed-fps 60 --script tests/bataille_test.gd -- --captures="$D/manche" > "$TMPDIR/c4.log" 2>&1; echo "code $?"
grep -hE "📸|SCRIPT ERROR|❌|== " "$TMPDIR/c1.log" "$TMPDIR/c2.log" "$TMPDIR/c3.log" "$TMPDIR/c4.log"
```

Expected : trois `code 0`, `== 0 échec(s) ==` pour la bataille, aucune `SCRIPT ERROR` ni `❌` ; 37 lignes `📸` pour `tests/screenshots.gd` (`00_titre` à `05_village_boss` en 2000×648, toutes les autres en 2000×1125), 11 pour les deux fenêtres (en 2000×1125, sauf `client_6_titre` en 2000×648 dans une fenêtre revenue au format du solo), et `manche/bataille_1.png` à `_3.png`.

- [ ] **Step 6 : regarder, puis montrer à l'utilisateur**

Vérifier sur les images :
- solo : les captures d'avant (titre, gerbe à 3 puis 7 couleurs, ennemis, pause, défaite, victoire avec record, peintre) ; `04b_victoire` dit désormais « Cœurs perdus 1 / 3 » (le coup, après l'intro ; avant : « 0 / 3 » et « Sans une égratignure ! ») ;
- `reseau_*` (phase 12 bis) : Multijoueur en bas à droite, à hauteur de Jouer (`00`), son contour de focus (`01`) ; « MMMMMMMMMMMM » entier dans le champ, l'indice « Aucune partie trouvée. Pare-feu ? Réseau Privé ? Essaie par IP. » (`02`) ; cinq lignes triées, trois grisées (« complète », « version 0.10 », « manche en cours ») (`03`, `04`) ; « Adresse IP invalide (exemple : 192.168.1.20) » (`05`) ; « Connexion à 127.0.0.1… » (`06`) ; « Version différente de l'hôte (0.10) » (`07`) ; tout en anglais (`08`) ; « Recherche impossible : port 17899 déjà utilisé (un autre LeLion ouvert ?). Rejoins par IP. » (`09`) ;
- `salon_*` (phase 13) : l'hôte seul, Démarrer grisé (`00`) ; **◉ salon à 3** au bouton grisé avec sa raison (`01`) ; le bouton actif en jaune (`02`) ; six cartes, « WWWWWWWWWWWW » entier (`03`) ; l'anglais (`04`) ; la vue d'un client, « TOI » sur sa carte, sans adresses ni bouton (`05`), tous prêts : « Tout le monde est prêt : l'hôte peut démarrer. » (`06`), un joueur qui arrive : « Un joueur est en train d'arriver… » (`07`) ;
- `bataille_*` (phase 17) : six vignettes, 0 % partout (`01`) ; **◉ manche à 6 couleurs** : parts, rangs, couronnes de travers, crans, « ★ XXL », « ★ ÉTOURDI », Max « PARTI » (`02`) ; le chrono rouge (`03`) ; l'égalité à 2 en anglais (`04`) ;
- `resultats_*` (phase 18) : l'animation (`01`), l'écran entier de l'hôte d'une bataille locale (`02`), le client (`03`), l'hôte en réseau, Niveau suivant sélectionné (`04`), l'hôte resté seul (`05`), l'égalité en anglais (`06`) : les mêmes que les captures validées de la phase 18 ;
- `deux_fenetres/*` : le salon des deux côtés (`0_salon`) ; **◉ la partie à 2 fenêtres** : la même scène au même instant (`1_manche`), la même ville peinte (`2_ville_peinte`) ; le menu local de l'hôte (`hote_3_menu_local`) ; le même écran Résultats des deux côtés (`4_resultats`) ; « L'hôte a quitté la partie » chez le client (`client_5_hote_perdu`, sur une ville sans lions : le point 24 du tri, à juger par l'utilisateur) ; le titre au format du solo (`client_6_titre`) ;
- `manche/bataille_1` à `_3` : une vraie manche à 4 (le pilote du test).

Montrer à l'utilisateur au moins `salon_01_a_3`, `bataille_02_en_jeu_a_6`, `resultats_02_hote_local_a_6`, `deux_fenetres/hote_1_manche`, `deux_fenetres/client_1_manche` et `deux_fenetres/client_5_hote_perdu`, et **attendre sa validation explicite** (◉ livraison) avant la Task 9. Ses retours visuels qui demandent un changement du jeu vont dans la fiche de l'essai (Task 8) pour la phase 19 bis, pas dans cette phase (Écart 10).

- [ ] **Step 7 : commit**

```bash
git add tests/screenshots.gd tests/deux_fenetres.gd tests/deux_fenetres.gd.uid .github/workflows/ci.yml
git commit -m "Captures versées au dépôt : tests/screenshots.gd en parties (le solo, son coup désormais après l'intro, l'écran Réseau, le salon, la manche à 6 couleurs, l'écran Résultats), tests/deux_fenetres.gd (un hôte et un client, du salon aux Résultats et à l'hôte perdu) ; sans rendu, chacun déroule tout, et la CI les garde ainsi en vie

<ligne fournie par l'environnement>"
```

---

### Task 7 : le README : le multijoueur, « Jouer en LAN » (en français), les tests et la CI (`README.md`)

**Files:**
- Modify: `README.md` (l'en-tête ; deux sections neuves avant « Running the game » ; « Project layout » ; « Tests » ; « Export and CI »)

**Interfaces:**
- Consumes (Tasks 1, 3, 5, 6) : la version 0.19, la fenêtre bornée, l'exe nommé « LeLion multi » et son artefact, les commandes des captures ; les textes du jeu tels que `Assets/Traductions/traductions.csv` les donne (les messages cités au dépannage, en français, mot pour mot).
- Produces (Task 8, et les joueurs) : les sections `## Multiplayer: a LAN paint battle` (ancre `#multiplayer-a-lan-paint-battle`) et `## Jouer en LAN` (ancre `#jouer-en-lan`), que cite la fiche de l'essai.

Le README hérité du solo est en anglais et ne parle ni du multijoueur, ni de l'exe, ni des suites (il annonçait encore le déploiement Pages, retiré en phase 1). Il reste en anglais, sauf « Jouer en LAN », qui sert les joueurs de la LAN et cite les libellés de leur Windows en français (Écart 6). Chaque message cité au dépannage est celui du jeu, mot pour mot (`RESEAU_AUCUNE_PARTIE`, `RESEAU_ECHEC_CONNEXION`, `RESEAU_REFUS_VERSION`, `RESEAU_ECOUTE_IMPOSSIBLE`, `RESEAU_PORT_OCCUPE`, `RESEAU_REFUS_PLEIN`, `RESEAU_REFUS_MANCHE`, `RESEAU_EXCLU`, `RESEAU_HOTE_PERDU`, `SALON_ADRESSES`, formats `%s` et `%d` remplis) ; les libellés de Windows sont ceux de Windows 10 et 11 en français. Les blocs ci-dessous sont entre quatre accents graves : ils contiennent eux-mêmes des blocs de code.

- [ ] **Step 1 : l'en-tête**

Dans `README.md`, remplacer :

````markdown
# LeLion

[Original inspiration: Laetitia Perez](https://www.instagram.com/p/Dc3SacQDsyM/?igsi=M21jMzRiMmxqdTZl)

A lion has to paint the town by puking a rainbow, while dodging enemies.
An absurd, deliciously colorful game made with [Godot 4](https://godotengine.org).

**Play in your browser: <https://w3cdotorg.github.io/LeLion/>** (deployed by CI on every push to `main`).
````

par :

````markdown
# LeLion multi

[Original inspiration: Laetitia Perez](https://www.instagram.com/p/Dc3SacQDsyM/?igsi=M21jMzRiMmxqdTZl)

A lion has to paint the town by puking a rainbow, while dodging enemies.
An absurd, deliciously colorful game made with [Godot 4](https://godotengine.org).

This fork of [LeLion](https://github.com/w3cdotorg/LeLion) turns it into a **paint battle for 2 to 6
players on a local network**, each on their own Windows PC: see
[Multiplayer](#multiplayer-a-lan-paint-battle), and [Jouer en LAN](#jouer-en-lan) (in French) to set
it up. The solo game below is unchanged; the original plays in a browser at
<https://w3cdotorg.github.io/LeLion/>.
````

- [ ] **Step 2 : le multijoueur et « Jouer en LAN »**

Dans `README.md`, remplacer :

````markdown
## Running the game

Open the folder in Godot 4.4 or newer and run the main scene, or from the command line:
````

par :

````markdown
## Multiplayer: a LAN paint battle

On the title screen, **Multiplayer** (bottom right) opens the network screen: pick a name (up to 12
characters), then **Host a game**, pick a game in the list of games on the network, or type the
host's IP address. In the lobby, each player picks a color (Left/Right) and gets ready (Space); the
host picks the level (Up/Down) and starts (Tab, Start) once at least two players are there, all
ready.

A round lasts 90 seconds, on a 16:9 screen. Every lion pukes in its own color, in three shades, and
the town is split into 8-pixel cells: paint a cell enough and it is yours, paint over someone else's
and you steal it. The most cells at the gong wins (ties are possible). Puking on another lion stuns
it for 1.5 s (then 1 s of immunity); saucers, ladybugs and the painter stun for 2.5 s, then leave
3 s to flee. Color dots add a notch to your spew (1 to 7: a wider brush), the rainbow star doubles
it for eight seconds; there are no hearts. Lions bump into each other like bumper cars. The HUD
shows each player's share of the painted cells, rank and notches; the last ten seconds tick in red.

After the gong, every PC shows the same **Results** screen: the ranking, each player's share, stuns
dealt, cells stolen and bumps, and three titles (the nastiest, the thief, the bumper car). The host
picks **Rematch**, **Next level** or **Back to lobby** for everyone; anyone can quit, and the host
quitting ends the game for everyone (it asks first). Each player uses their own PC's keyboard or
gamepad, with the solo controls; Esc opens a local menu that does not pause the round.

## Jouer en LAN

### Ce qu'il faut

- Un PC Windows par joueur (2 à 6), tous sur **le même réseau local** : la même box, en Wi-Fi ou
  par câble. Pas besoin d'Internet pendant la partie.
- Le même `LeLion-multi.exe` sur chaque PC. Il vient de la CI : sur GitHub, onglet **Actions**, la
  dernière exécution verte de `main` (ou d'une pull request), **Artifacts** → `LeLion-multi-windows`
  (un zip ; il faut être connecté à GitHub), qui contient le seul `LeLion-multi.exe` : le jeu est
  dedans. Deux versions différentes ne jouent pas ensemble (« Version différente de l'hôte (0.19) »).
- Garder l'exe **au même endroit** (par exemple `Documents\LeLion`) et y remplacer le fichier à
  chaque nouvelle version : l'autorisation du pare-feu suit son chemin.

### Premier lancement

1. **SmartScreen** : l'exe n'est pas signé. « Windows a protégé votre ordinateur » →
   **Informations complémentaires** → **Exécuter quand même** (une fois par fichier). Le navigateur
   peut aussi prévenir au téléchargement : conserver le fichier.
2. **Réseau Privé**, sur chaque PC : Paramètres → Réseau et Internet → Wi-Fi (ou Ethernet) → le
   réseau → **Type de profil réseau** (Windows 11) ou **Profil réseau** (Windows 10) → **Privé**. En
   réseau Public, Windows bloque ce que LeLion reçoit.
3. **Pare-feu, sur l'hôte** : au premier **Héberger une partie**, Windows affiche « Le Pare-feu
   Windows Defender a bloqué certaines fonctionnalités de cette application » pour **LeLion multi** :
   laisser **Réseaux privés** coché et cliquer **Autoriser l'accès** (Windows peut demander le mot de
   passe d'un administrateur). Sans cela, les autres voient la partie mais ne peuvent pas la rejoindre.
4. **Pare-feu, sur chaque autre PC** : à la première ouverture de l'écran Multijoueur, la même
   fenêtre (LeLion y écoute les annonces des parties) : **Autoriser l'accès** aussi.

Ces fenêtres ne reviennent plus tant que l'exe reste au même endroit.

### Jouer

- L'hôte : **Multijoueur** → **Héberger une partie**. Son salon affiche ses adresses (« Les autres
  te voient dans leur liste, ou tapent ton adresse : 192.168.1.20 »).
- Les autres : **Multijoueur**. La partie de l'hôte apparaît en une seconde dans « Parties sur le
  réseau » : la choisir. Sinon, taper l'adresse de l'hôte dans **Adresse IP**, puis **Rejoindre**.
- Au salon : Gauche/Droite, la couleur ; Espace, prêt. L'hôte choisit le niveau (Haut/Bas) et
  démarre (Tab ou Start) quand tout le monde est prêt, à deux au moins.
- Ports, en UDP : **7777** (la partie, chez l'hôte) et **7778** (l'annonce des parties, que l'hôte
  diffuse chaque seconde sur le réseau local).
- Pour un jeu fluide : l'hôte en Ethernet si possible, le Wi-Fi en 5 GHz, pas de gros
  téléchargement pendant la partie.

### Dépannage

| Ce qu'on voit | Pourquoi | Quoi faire |
|---|---|---|
| « Aucune partie trouvée. Pare-feu ? Réseau Privé ? Essaie par IP. » | Ce PC ne reçoit pas les annonces : son pare-feu (« Annuler » au premier lancement), un réseau Public, un Wi-Fi invité qui isole les appareils, ou un Wi-Fi maillé (ligne suivante). | Réseau Privé, autoriser LeLion multi (plus bas), ou rejoindre par IP. |
| La partie n'apparaît pas sur un Wi-Fi maillé (TP-Link Deco, eero, Google/Nest Wifi en mode routeur) | Ces réseaux sont souvent plus grands qu'un /24 (par exemple de 192.168.68.0 à 192.168.71.255, masque 255.255.252.0) : l'annonce, envoyée à a.b.c.255, n'en atteint alors qu'une partie. | Rejoindre par IP : l'adresse s'affiche dans le salon de l'hôte. |
| « Pas de réponse de l'hôte. Pare-feu de l'hôte ? Réseau Privé ? » (après 5 s) | Le pare-feu de l'hôte bloque le port 7777 (« Annuler » au premier hébergement, ou un réseau Public chez lui), ou l'adresse tapée n'est pas la sienne. | Sur l'hôte : réseau Privé, autoriser LeLion multi (plus bas) ; vérifier l'adresse dans son salon. |
| « Version différente de l'hôte (x.y) » | Deux versions du jeu. | Le même `LeLion-multi.exe` partout. |
| « Recherche impossible : port 7778 déjà utilisé (un autre LeLion ouvert ?). Rejoins par IP. » | Deux LeLion ouverts sur le même PC : un seul peut lister les parties. | Fermer l'autre, ou rejoindre par IP (127.0.0.1 pour une partie hébergée par ce PC). |
| « Impossible d'héberger : port 7777 occupé » | Un autre LeLion (ou un autre programme) héberge déjà sur ce PC. | Le fermer. |
| « La partie est complète. », « Une manche est en cours : réessaie à la fin. » | 6 joueurs au plus ; on n'arrive pas en pleine manche. | Attendre le retour au salon. |
| « Exclu : ta partie a mis trop de temps à charger. » | Ce PC a mis plus de 20 s à charger la manche. | Fermer les autres programmes, puis rejoindre au retour au salon. |
| « L'hôte a quitté la partie » | L'hôte est parti, ou son PC s'est mis en veille, ou son Wi-Fi a coupé. | Retour au titre ; l'hôte peut héberger de nouveau. |

**Autoriser LeLion multi après un « Annuler »** : Sécurité Windows → Pare-feu et protection du
réseau → **Autoriser une application via le pare-feu** → **Modifier les paramètres** → cocher
**Privé** en face de « LeLion multi » (« Godot Engine » pour un exe de la version 0.18 ou d'avant)
→ OK. Si LeLion reste bloqué : **Pare-feu Windows Defender avec fonctions avancées de sécurité**
(`wf.msc`) → **Règles de trafic entrant** → supprimer les règles « LeLion multi » marquées d'un
sens interdit rouge, puis héberger de nouveau : la fenêtre du premier lancement revient.

Le journal de chaque PC, utile après une soirée qui s'est mal passée :
`%APPDATA%\Godot\app_userdata\LeLion\logs\godot.log`.

## Running the game

Open the folder in Godot 4.7 or newer and run the main scene, or from the command line:
````

- [ ] **Step 3 : l'arborescence, les tests, la CI**

Dans `README.md`, remplacer :

````markdown
```
Scenes/     Titre (title), Main (a game), Intro (READY? VOMIT!), Lion, Ville (town), HUD, PauseMenu,
            Reglages (settings), ControlesTactiles (touch controls), GameOver (CONTINUE? + summary),
            ColorPickup, BonusPickup, CoeurPickup, Soucoupe, Coccinelle, Boss
Scripts/    one script per scene + Pilote (attract-mode autopilot) + autoloads GameState (game, lives,
            levels, difficulties, arcade), Scores (records, preferences), Parametres (settings, CRT layer),
            Audio (sounds, layered music)
Shaders/    Ville.gdshader (paint mask on the skyline), Crt.gdshader (optional CRT filter)
Assets/     Sprites (used), Sons (generated), Traductions (CSV → .translation), src (reference material, ignored by Godot)
tests/      smoke_test.gd (headless) and screenshots.gd (scripted captures)
tools/      generer_sons.py (effects), generer_musique.py (layered chiptune, town + boss themes), generer_skylines.py (skylines, sprites)
```
````

par :

````markdown
```
Scenes/     Titre (title), Main (a game), Intro (READY? VOMIT!), Lion, Ville (town), HUD, HUDBataille (battle HUD),
            Resultats (battle results), EcranReseau (network screen), Salon (lobby), PauseMenu, Reglages (settings),
            ControlesTactiles (touch controls), GameOver (CONTINUE? + summary), ColorPickup, BonusPickup,
            CoeurPickup, Soucoupe, Coccinelle, Boss
Scripts/    one script per scene; the autoloads GameState (game, players, levels, difficulties, arcade), Scores
            (records, preferences), Parametres (settings, CRT layer), Audio (sounds, layered music), Reseau (ENet
            transport, handshake, lobby table) and Decouverte (UDP game announcements); Manche (a networked round);
            pure logic: Joueur (a player), Commandes (inputs), Regles / ReglesSolo / ReglesBataille (rules of each
            mode), Territoire (cell ownership), Peinture (deterministic stamps), EtatLion, InterpolationLion and
            PredictionLocale (lions over the network), BilanManche (end of a round), PlacementPseudos; the lion's
            parts DeplacementLion, PareChocs, GerbeLion; Pilote (attract-mode autopilot)
Shaders/    Ville.gdshader (paint mask on the skyline), Lion.gdshader (mane tint), Crt.gdshader (optional CRT filter)
Assets/     Sprites (used), Sons (generated), Traductions (CSV → .translation), src (reference material, ignored by Godot)
tests/      unitaires, smoke_test, bataille_test, prediction_test, trace_lions (headless), reseau/ (multi-process
            network test, latency relay), screenshots and deux_fenetres (captures)
tools/      generer_sons.py (effects), generer_musique.py (layered chiptune, town + boss themes), generer_skylines.py (skylines, sprites)
docs/       screenshots, the design spec and the phase plans (superpowers/), the LAN test sheet (essai-lan.md, in French)
```
````

Dans `README.md`, remplacer :

````markdown
## Tests

The smoke test loads the main scene without a display, unlocks a color, makes the lion puke on
the town, triggers a defeat and then a victory, and exercises the title screen, settings, touch
controls and the boss:

```sh
godot --headless --script tests/smoke_test.gd
```

For a visual check (opens a window for a few seconds and writes PNGs):

```sh
godot --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier=/output/path
```
````

par :

````markdown
## Tests

Headless suites (the CI runs all but the last one); each ends on `== 0 échec(s) ==` when green
(test messages are in French):

```sh
godot --headless --script tests/unitaires.gd                       # pure logic: territory, rules, lobby table, protocol guard…
godot --headless --script tests/smoke_test.gd                      # solo game, title, network screen, lobby, a networked round
godot --headless --fixed-fps 60 --script tests/bataille_test.gd    # a 4-lion local battle, the Results screen, rematch
godot --headless --fixed-fps 60 --script tests/prediction_test.gd  # client-side prediction under simulated latency
bash tests/reseau/lancer.sh                                        # headless Godot processes on localhost; DIFFUSION=1 adds real broadcast
godot --headless --fixed-fps 60 --script tests/trace_lions.gd      # the lions' fingerprint, for refactors
```

The network test needs GNU `timeout` (coreutils) and takes about three minutes; run one suite at
a time (they share local ports).

Screenshots, with a real renderer (windows open while the scripts run):

```sh
godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier=/output/path [--parties=solo,reseau,salon,bataille,resultats]
godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=hote --dossier=/output/path
godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=client --dossier=/output/path
godot --path . --rendering-driver opengl3 --fixed-fps 60 --script tests/bataille_test.gd -- --captures=/output/path
```

`deux_fenetres.gd` is one host and one client in two real windows (start both, in any order).
Without a renderer (`--headless`), the two capture scripts go through their whole scenario without
writing anything: that is how the CI keeps them working.
````

Dans `README.md`, remplacer :

````markdown
## Export and CI

A Web preset is defined in `export_presets.cfg`. With the export templates installed:

```sh
godot --headless --export-release Web export/web/index.html
```

The workflow in `.github/workflows/ci.yml` installs Godot, runs the smoke test and exports the
Web build on every push and pull request. On `main`, it deploys the result to GitHub Pages.
````

par :

````markdown
## Export and CI

`export_presets.cfg` defines a Windows Desktop preset (a single `.exe` with the game data embedded,
the game's icon, name and version in its file properties) and a Web preset (the solo game). With
the export templates installed:

```sh
godot --headless --export-release "Windows Desktop" export/windows/LeLion-multi.exe
godot --headless --export-release Web export/web/index.html
```

The workflow in `.github/workflows/ci.yml` runs on every pull request and every push to `main`: it
installs Godot 4.7.2 and its export templates, runs the unit tests, the smoke test, the local
battle test, the prediction bench, the network test (real broadcast included) and the two capture
scripts without a renderer, exports both builds, checks the icon and metadata of the Windows
executable, and publishes it as the `LeLion-multi-windows` artifact (kept 30 days). Nothing is
deployed.
````

- [ ] **Step 4 : vérifier**

Run :

```bash
for cle in RESEAU_AUCUNE_PARTIE RESEAU_ECHEC_CONNEXION RESEAU_REFUS_PLEIN RESEAU_EXCLU RESEAU_HOTE_PERDU RESEAU_REFUS_MANCHE; do
	texte="$(grep "^$cle," Assets/Traductions/traductions.csv | cut -d, -f2- | sed -E 's/^"([^"]*)",.*/\1/; s/^([^",]*),.*/\1/')"
	grep -qF "$texte" README.md && echo "ok $cle" || echo "ABSENT $cle : $texte"
done
grep -E "^## " README.md; grep -nE "Pages|Godot 4\.4" README.md
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' README.md
```

Expected : six `ok` (vérifié en préparant ce plan) ; les sections `How to play`, `Multiplayer: a LAN paint battle`, `Jouer en LAN`, `Running the game`, `Project layout`, `Tests`, `Export and CI`, dans cet ordre ; ni « Pages » ni « Godot 4.4 » ; rien de la dernière commande. Relire le rendu (un aperçu Markdown) : les deux ancres de l'en-tête mènent à leur section, le tableau du dépannage a trois colonnes.

- [ ] **Step 5 : commit**

```bash
git add README.md
git commit -m "README : le multijoueur (règles, salon, écran Résultats), « Jouer en LAN » en français (l'exe de la CI, SmartScreen, réseau Privé, le pare-feu de l'hôte et des joueurs, les ports 7777 et 7778, le repli par IP, le Wi-Fi maillé, le dépannage message par message, le journal), l'arborescence, les suites, les captures et la CI

<ligne fournie par l'environnement>"
```

---

### Task 8 : la fiche de l'essai LAN (`docs/essai-lan.md`)

**Files:**
- Create: `docs/essai-lan.md`

**Interfaces:**
- Consumes (Tasks 1 à 7) : les constantes qu'elle nomme, telles que le code de cette phase les laisse (`Regles.taille_bornee` vient de la Task 3), la section « Jouer en LAN » du README (Task 7).
- Produces (la phase 19 bis) : pour chaque point du seau (b) du tri, une question et la table de ce que chaque réponse fait changer (fichier, constante, valeur actuelle) ; la procédure de la trace quand le jeu change.

La fiche est pour l'utilisateur et ses joueurs : en français, sans jargon dans les questions ; le jargon (fichiers, constantes) n'est que dans les tables « Ce que fera la phase 19 bis ». Elle couvre les points 18 à 30 du tri, un par un : 18 et 19 (§ 1), 3 et 4 vus sous Windows (§ 2), 25 (§ 3), 22 (§ 4), 20 et 21 (§ 5), 26 (§ 6), 23 et 27 (§ 7), 28 à 30 (§ 8), 24 (§ 9), et le point 31 par les journaux (§ 10) ; elle vérifie aussi la livraison (Task 5 : les Détails de l'exe, le nom dans la fenêtre du pare-feu).

- [ ] **Step 1 : la fiche**

Créer `docs/essai-lan.md` :

````markdown
# Essai LAN de LeLion multi (phase 19)

Cette fiche sert une soirée de jeu sur de vrais PC Windows, à 4 à 6 si possible : ce qu'il faut
essayer, ce qu'il faut regarder, et, pour chaque réponse, ce que la phase 19 bis changera. Rien
n'y est décidé d'avance : les réglages de la phase 17 (le rythme de la manche, le HUD, les sons) et
de la phase 18 (l'écran Résultats) ont été faits sans essai à plusieurs, et seuls de vrais PC en
Wi-Fi peuvent dire s'ils conviennent.

Comment la remplir : cocher ce qui a été essayé, entourer ou écrire la réponse, noter sur quel PC.
Une réponse « ça va » est une vraie réponse : elle clôt la question. Renvoyer ensuite la fiche
remplie, avec les journaux de la dernière section.

Pour installer et lancer le jeu, suivre la section « Jouer en LAN » du `README.md`.

## Avant la soirée

- [ ] Le même `LeLion-multi.exe` (version 0.19, artefact `LeLion-multi-windows` de la CI) sur chaque
  PC, au même endroit d'une version à l'autre.
- [ ] Sur un PC : clic droit sur l'exe → Propriétés → Détails. Description « LeLion multi », version
  du fichier 0.19.0.0, copyright « Copyright 2026 w3cdotorg, GPL-3.0 » ; dans l'explorateur, l'icône
  du jeu (pas celle de Godot). Sinon, noter ce qui s'affiche : _______________
- [ ] Au premier « Héberger une partie », la fenêtre du pare-feu parle de « LeLion multi » (pas de
  « Godot Engine »). Sinon, noter le nom affiché : _______________

Les PC de la soirée :

| PC | Rôle (hôte ou joueur) | Windows (10 ou 11) | Écran (résolution, mise à l'échelle) | Réseau (Wi-Fi 2,4 ou 5 GHz, Ethernet) | Masque (`ipconfig`, « Masque de sous-réseau ») | VPN ou carte réseau virtuelle |
|---|---|---|---|---|---|---|
| 1 | | | | | | |
| 2 | | | | | | |
| 3 | | | | | | |
| 4 | | | | | | |
| 5 | | | | | | |
| 6 | | | | | | |

Le routeur ou la box : _______________ (un Wi-Fi maillé, TP-Link Deco, eero, Google/Nest Wifi ?)

## 1. Découverte des parties

- [ ] Sur chaque PC, la partie de l'hôte apparaît dans « Parties sur le réseau » en une seconde.
  PC où elle n'apparaît pas : _______________
- [ ] Sur un PC à VPN ou à carte réseau virtuelle (VirtualBox, Hyper-V, WSL), s'il y en a un, elle
  apparaît aussi : oui / non
- [ ] Sur un Wi-Fi maillé, s'il y en a un (masque 255.255.252.0 ou plus large), elle apparaît :
  oui / non
- [ ] Rejoindre par IP (l'adresse affichée dans le salon de l'hôte) marche partout : oui / non

| Réponse | Ce que fera la phase 19 bis |
|---|---|
| Elle apparaît partout | Rien. |
| Absente sur un Wi-Fi maillé seulement (masque en /22 ou plus large) | La balise part aussi vers les candidats /23 et /22 de chaque adresse privée (a.b.(c\|1).255, a.b.(c\|3).255), dédoublonnés (`Decouverte.destinations_balise`, et ses tests unitaires), avec l'identifiant de session de la balise (I2 de la revue finale 12 bis) ; sinon, la limite reste celle du README. |
| Absente sur un PC à VPN ou à carte virtuelle | Noter l'adresse et le nom de chaque carte (`ipconfig /all`) : l'ordre des cartes (`Decouverte._rang_interface`) ou les destinations de la balise (`Decouverte.destinations_balise`). |
| Absente ailleurs, masque 255.255.255.0 | Le pare-feu ou le réseau Public de ce PC (README, « Dépannage ») ; sinon, son journal. |
| Rejoindre par IP échoue | Le pare-feu de l'hôte (README) ; sinon, les journaux de l'hôte et du PC. |

## 2. La fenêtre

- [ ] La fenêtre au lancement (1400 px de large, au format du solo) : trop petite / bien / trop
  grande, sur l'écran de : _______________
- [ ] En passant au Multijoueur (16:9), la fenêtre tient dans l'écran : rien sous la barre des
  tâches, barre de titre visible. PC où elle déborde : _______________
- [ ] Élargir à la main la fenêtre du titre presque à toute la largeur de l'écran, puis
  Multijoueur : elle tient toujours dans l'écran (réduite au format) : oui / non
- [ ] En plein écran (Réglages) : tout se lit et rien n'est coupé : oui / non

| Réponse | Ce que fera la phase 19 bis |
|---|---|
| Trop petite ou trop grande au lancement | `project.godot` : `window/size/window_width_override` (1400) et `window_height_override` (la largeur × 648 / 2000, arrondie). |
| Elle déborde de l'écran | Noter la résolution, la mise à l'échelle et la position de la barre des tâches : `Regles.appliquer_ecran`, `Regles.taille_bornee` (M7, phase 19). |
| Quelque chose est coupé en plein écran | Noter quoi, et la résolution. |

## 3. Le démarrage d'une manche

- [ ] À la première manche après le lancement du jeu, un à-coup (image figée, son qui hoquette) au
  moment de « Prêt ? Vomissez ! » : non / oui, sur les PC _______________, pendant environ ____ s
- [ ] Un joueur « Exclu : ta partie a mis trop de temps à charger. » : non / oui, sur le PC ______

| Réponse | Ce que fera la phase 19 bis |
|---|---|
| Aucun à-coup | Rien : le préchauffage des shaders (M8 de la revue finale 14) n'a pas lieu d'être. |
| Un à-coup | Préchauffer pendant le chargement : une image avec un lion (et sa gerbe active) hors champ, libéré avant `Reseau.signaler_scene_chargee` (`Scripts/Manche.gd`, `Main._preparer_manche_en_reseau`). |
| Un exclu | Noter le PC et sa durée de chargement : `Manche.delai_chargement` (20 s), ou le préchauffage. |

## 4. Les commandes

- [ ] Son propre lion répond tout de suite : oui / non
- [ ] Son propre lion paraît élastique (il glisse encore après l'arrêt, ou revient un peu en
  arrière) : jamais / parfois / souvent
- [ ] Son propre lion saute d'un coup (téléportation) : jamais / parfois / souvent
- [ ] Les autres lions bougent de façon fluide : oui / saccadés / par à-coups quand le Wi-Fi faiblit
- [ ] Les chocs entre lions (le « boing », le recul) paraissent justes : oui / non

| Réponse | Ce que fera la phase 19 bis |
|---|---|
| Élastique | `PredictionLocale.DUREE_CORRECTION` (0,04 s : plus court, le lion se recale plus sec). |
| Des sauts | `PredictionLocale.SEUIL_RECALAGE` (200 px), et les journaux (un recalage est une désynchronisation). |
| Autres lions saccadés | `InterpolationLion.RETARD` (6 ticks, 100 ms : 8 à 10 absorbent un Wi-Fi plus mauvais, au prix d'un peu plus de retard) ; par à-coups pendant une coupure : `InterpolationLion.EXTRAPOLATION_MAX` (3 ticks). |
| Chocs faux | Noter la situation (lion distant qui bouge vite ?) : un choc contre un lion distant est prédit contre sa position affichée, en retard d'environ 140 ms (spec §13). |

## 5. Le rythme de la manche (à 4-6)

- [ ] Les pastilles de couleur : trop / assez / pas assez ; à la fin de la manche, chacun a
  environ ____ crans sur 7
- [ ] Une pastille que personne ne prend disparaît : trop tôt / bien / trop tard
- [ ] Une pastille est née cachée derrière les vignettes du HUD : jamais / parfois
- [ ] Au Village, le peintre : on a le temps de le fuir / on reste étourdi sans relâche
- [ ] La manche de 90 s : trop courte / bien / trop longue
- [ ] Autre chose sur le rythme (ennemis trop fréquents, étourdissements trop longs…) :
  _______________

| Réponse | Ce que fera la phase 19 bis |
|---|---|
| Trop ou pas assez de pastilles | `ReglesBataille.PASTILLES_JUSQU_A_3_JOUEURS` (2), `PASTILLES_A_4_JOUEURS_ET_PLUS` (3), `DELAI_ENTRE_PASTILLES` (4 s). |
| Elles disparaissent trop tôt ou trop tard | `ReglesBataille.DUREE_DE_VIE_PASTILLE` (12 s). |
| Cachées derrière le HUD | `ReglesBataille.HAUTEUR_BANDE_HUD` (175 px, à l'échelle de l'écran de bataille, 1125 px de haut). |
| Étourdi sans relâche par le peintre | `ReglesBataille.DUREE_REPIT_ENNEMI` (3 s de répit), `FACTEUR_REPOS_PEINTRE` (2 : sa pause hors de l'écran, doublée). |
| Étourdissements trop longs ou trop courts | `ReglesBataille.DUREE_ETOURDI_VOMI` (1,5 s), `DUREE_ETOURDI_ENNEMI` (2,5 s), `DUREE_IMMUNITE` (1 s) : ce sont des décisions de la spec (§2), à rediscuter d'abord. |
| Manche trop courte ou trop longue | `ReglesBataille.DUREE_MANCHE` (90 s) : une décision de la spec (§2), à rediscuter d'abord. |

## 6. Le HUD de la bataille

- [ ] Les vignettes (pseudo, part des cellules peintes, rang, crans) se lisent dans la fenêtre :
  oui / non ; en plein écran : oui / non
- [ ] La couronne posée de travers sur le lion des meneurs se voit : oui / non
- [ ] Chacun reconnaît son lion et sa couleur, pseudo compris (daltonisme ?) : oui / non, qui :
  ______
- [ ] Les pseudos au-dessus des lions se lisent : oui / non

| Réponse | Ce que fera la phase 19 bis |
|---|---|
| Vignettes trop petites | `HUDBataille.TAILLE_VIGNETTE` (270 × 112), `HUDBataille.POLICE_PSEUDO` (20), et `ReglesBataille.HAUTEUR_BANDE_HUD` avec elles. |
| Couronne invisible | `HUDBataille.TAILLE_COURONNE` (30 × 20), `PLACE_COURONNE`, `INCLINAISON_COURONNE` (0,38 rad). |
| Couleurs confondues | Noter lesquelles : la palette (`EtatPartie.PALETTE_BATAILLE`, dans `Scripts/GameState.gd`, réglée pour la deutéranopie) ; le pseudo accompagne toujours la couleur. |

## 7. Les sons (à 4-6)

- [ ] Le « boing » des chocs : trop présent / bien / trop discret (celui de son propre lion, puis
  ceux des autres)
- [ ] Le tic des dix dernières secondes, le gong de fin, le son d'étourdissement : bien / trop fort /
  trop faible
- [ ] On aimerait entendre vomir les autres lions (aujourd'hui, seul son propre lion s'entend) :
  oui / non

| Réponse | Ce que fera la phase 19 bis |
|---|---|
| Les sons des autres lions trop forts ou trop faibles | `Audio.DB_AUTRES` (−9 dB par rapport à ceux de son propre lion). |
| Un son trop fort ou trop faible partout | Son gain dans `tools/generer_sons.py` (`boing`, `tic`, `fin`, `etourdi`), le son régénéré. |
| Entendre vomir les autres | Une boucle de vomi par lion, spatialisée et plus basse (`Audio.DB_AUTRES`), jouée par chaque lion distant (`Scripts/Lion.gd`, `Scripts/Audio.gd`). |

## 8. L'écran Résultats

- [ ] Il se lit dans la fenêtre : oui / non ; en plein écran : oui / non
- [ ] L'animation du classement (les lignes qui arrivent, les barres qui montent) : trop longue /
  bien / trop courte
- [ ] Le délai d'une seconde après l'animation avant qu'un choix au clavier compte : gênant (on
  appuie et rien ne se passe) / bien / trop court (un choix fait sans le vouloir)
- [ ] Revanche, Niveau suivant et Retour au salon font ce qu'on attend, chez tout le monde : oui /
  non

| Réponse | Ce que fera la phase 19 bis |
|---|---|
| Illisible | `Resultats.TAILLE_BARRE` (480 × 34), `Resultats.LARGEUR_PSEUDO` (360), les tailles de police de `Scenes/Resultats.tscn`. |
| Animation trop longue ou trop courte | `Resultats.DELAI_LIGNE` (0,3 s entre deux lignes), `Resultats.DUREE_COMPTEUR` (0,45 s), `Resultats.DELAI_TITRE` (0,2 s). |
| Délai gênant ou trop court | `Resultats.DELAI_CHOIX` (1 s). |
| Un choix qui ne fait pas ce qu'on attend | Noter lequel, qui l'a fait, ce qui s'est passé sur chaque PC, et l'heure (pour les journaux). |

## 9. Les départs

- [ ] Un joueur quitte en pleine manche ou sur l'écran Résultats : les autres le voient partir
  (grisé, « PARTI ») : oui / non
- [ ] L'hôte quitte : chez les autres, « L'hôte a quitté la partie » s'affiche sur une ville sans
  lions (le moteur retire les lions à la déconnexion), puis le titre. Gênant : oui / non
- [ ] Un PC mis en veille, ou dont on coupe le Wi-Fi : les autres le voient parti au bout d'environ
  ____ s

| Réponse | Ce que fera la phase 19 bis |
|---|---|
| La ville sans lions gêne | Garder la dernière image sous le message : une copie de l'écran prise dans `Main._sur_hote_perdu`, avant que les lions disparaissent. |
| Un départ vu trop tard (plus de 10 s) | `Reseau.SILENCE_SESSION` (3 à 8 s de silence toléré). |

## 10. Après la soirée

- [ ] Le journal de chaque PC, joint à la fiche : `%APPDATA%\Godot\app_userdata\LeLion\logs\godot.log`
  (noter l'heure des incidents, pour s'y retrouver)
- [ ] Remarques libres :

_______________

## Pour la phase 19 bis

Chaque réponse ci-dessus se change dans le fichier et la constante qu'indique sa ligne, puis se
vérifie par les suites (`tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd`,
`tests/prediction_test.gd`, `tests/reseau/lancer.sh`) et, pour ce qui se voit, par les captures
(`tests/screenshots.gd`, `tests/deux_fenetres.gd`).

**La trace des lions change avec le jeu.** Les constantes de `ReglesBataille` (pastilles, répit,
repos du peintre, étourdissements) changent la bataille de `tests/trace_lions.gd` : son empreinte
`TRACE bataille` change, voulu ; `TRACE solo` et `TRACE replique` ne doivent pas changer (la
réplique ne reçoit aucun état : `InterpolationLion` et `PredictionLocale` n'y entrent pas ; le HUD,
l'écran Résultats et les sons non plus). Pour chaque tâche qui change le jeu :

1. avant le changement, la référence : `export PATH="/opt/homebrew/bin:$PATH"; godot --headless --import . > /dev/null 2>&1; for k in 1 2 3; do timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/trace_lions.gd 2>&1 | grep -E "^TRACE|❌|SCRIPT ERROR" | tr '\n' ' '; echo; done` (deux passages consécutifs identiques ; référence de la phase 19 sur le Mac de préparation : `TRACE bataille 1698533818 TRACE solo 185311436 TRACE replique 3757044499`) ;
2. le changement, puis la même commande : `TRACE bataille` change, les deux autres non, et deux passages consécutifs donnent la même nouvelle valeur ;
3. cette nouvelle valeur devient la référence : la noter dans le plan de la phase 19 bis, le message du commit et la feuille de route ; les tâches suivantes la gardent.

Les mesures de `tests/bataille_test.gd` (lignes `MESURE` : crans en fin de manche, parts, vols)
bougent avec le rythme : relire ses seuils avant de les croire faux. Une constante de
`PredictionLocale` ou d'`InterpolationLion` se juge au banc (`tests/prediction_test.gd`) et au
scénario 12 du test réseau (sous 80 ms, 40 ms et 5 %), dont les seuils d'erreur peuvent devoir
suivre.
````

- [ ] **Step 2 : vérifier que chaque constante nommée existe, avec la valeur dite**

Run :

```bash
for ref in $(grep -oE '`[A-Z][A-Za-z]+\.[A-Za-z_]+`' docs/essai-lan.md | tr -d '`' | grep -v '^README\.' | sort -u); do
	c=${ref%%.*}; n=${ref#*.}; f="Scripts/$c.gd"; [ "$c" = EtatPartie ] && f=Scripts/GameState.gd
	grep -qE "(const|var|func|static var) $n\b" "$f" 2>/dev/null || echo "MANQUE $ref"
done
for n in PASTILLES_A_4_JOUEURS_ET_PLUS DELAI_ENTRE_PASTILLES DUREE_ETOURDI_ENNEMI DUREE_IMMUNITE FACTEUR_REPOS_PEINTRE; do grep -q "const $n " Scripts/ReglesBataille.gd || echo "MANQUE ReglesBataille.$n"; done
for n in PLACE_COURONNE INCLINAISON_COURONNE; do grep -q "const $n " Scripts/HUDBataille.gd || echo "MANQUE HUDBataille.$n"; done
grep -q "window_width_override=1400" project.godot || echo "MANQUE window_width_override"
echo "fiche vérifiée"
```

Expected : `fiche vérifiée` seul (aucune ligne `MANQUE`, vérifié en préparant ce plan). Puis relire les valeurs citées contre le code :

```bash
grep -nE "const (DUREE_ETOURDI_[A-Z]+|DUREE_IMMUNITE|DUREE_REPIT_ENNEMI|PASTILLES_[A-Z0-9_]+|DELAI_ENTRE_PASTILLES|DUREE_DE_VIE_PASTILLE|FACTEUR_REPOS_PEINTRE|HAUTEUR_BANDE_HUD|DUREE_MANCHE) " Scripts/ReglesBataille.gd
grep -nE "const (DUREE_CORRECTION|SEUIL_RECALAGE) " Scripts/PredictionLocale.gd; grep -nE "const (RETARD|EXTRAPOLATION_MAX) " Scripts/InterpolationLion.gd
grep -nE "const (TAILLE_VIGNETTE|POLICE_PSEUDO|TAILLE_COURONNE|INCLINAISON_COURONNE) " Scripts/HUDBataille.gd
grep -nE "const (TAILLE_BARRE|LARGEUR_PSEUDO|DELAI_LIGNE|DUREE_COMPTEUR|DELAI_TITRE|DELAI_CHOIX) " Scripts/Resultats.gd; grep -n "const DB_AUTRES" Scripts/Audio.gd
```

Expected : les valeurs de la fiche (1.5, 2.5, 1.0, 3.0, 2, 3, 4.0, 12.0, 2.0, 175.0, 90.0 ; 0.04, 200.0 ; 6.0, 3.0 ; (270, 112), 20, (30, 20), 0.38 ; (480, 34), 360, 0.3, 0.45, 0.2, 1.0 ; -9.0).

- [ ] **Step 3 : commit**

```bash
git add docs/essai-lan.md
git commit -m "Fiche de l'essai LAN (phase 19) : ce qu'il faut essayer sur de vrais PC Windows (découverte, fenêtre, démarrage d'une manche, commandes, rythme à 4-6, HUD, sons, écran Résultats, départs, journaux) et, pour chaque réponse, la constante que changera la phase 19 bis ; la procédure de la trace quand le jeu change

<ligne fournie par l'environnement>"
```

---

### Task 9 : la spec, la feuille de route (ligne 19, ligne 19 bis, chaque point « phase 19 »), la validation finale et la CI de la PR

**Files:**
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§4 poignée de main et salon ; §7 ; §10 test réseau, visuel, Windows ; §11)
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 19 et ligne 19 bis neuve ; chaque point de vigilance « phase 19 », résolu ou renvoyé à la phase 19 bis avec sa raison ; le temps de la CI ; M6 de la revue finale 18)

**Interfaces:**
- Consumes : les mesures des Tasks 0 à 8 (trace, temps du test réseau, empreinte du protocole, captures validées) et le tri du haut de ce plan.

Chaque point « phase 19 » de la feuille de route prend son statut du tri : « (résolu en phase 19) » pour le seau (a), « **phase 19 bis** » avec la section de la fiche pour le seau (b), « (sans objet, phase 19) » avec sa raison pour le seau (c). Les blocs ci-dessous ont été vérifiés sur les fichiers de `64e806d` (chaque ancien texte y est une seule fois ; après eux, plus aucun « **phase 19** » en gras dans la feuille de route).

- [ ] **Step 1 : la feuille de route et la spec**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
| 19 | **Livraison Windows** : preset, `.pck` intégré, artefact CI, README « Jouer en LAN », captures. | ✏️ `export_presets.cfg` ✏️ `.github/workflows/ci.yml` ✏️ `README.md` ✏️ `tests/screenshots.gd` ✏️ `project.godot` | `.exe` en artefact, testé sur Windows par l'utilisateur |
```

par :

```markdown
| 19 | **Livraison Windows** : l'exe à l'icône, au nom (« LeLion multi », aussi dans la fenêtre du pare-feu) et à la version du jeu, vérifiés par la CI (le preset, le `.pck` intégré et l'artefact venaient de la PR #26) ; README (le multijoueur, « Jouer en LAN » en français : pare-feu de l'hôte et des joueurs, réseau Privé, ports 7777 et 7778, repli par IP, Wi-Fi maillé, dépannage) ; captures versées au dépôt (`tests/screenshots.gd` en parties, `tests/deux_fenetres.gd`) et déroulées sans rendu en CI ; tables du salon numérotées (M6 de la revue finale 18) ; fenêtre gardée dans l'écran (M7 de la revue finale 14) ; journal de la prédiction hors du jeu livré ; garde du protocole (la version reste celle du protocole) ; vraie diffusion en CI ; fiche de l'essai LAN (`docs/essai-lan.md`) ; version 0.19. | ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Salon.gd` ✏️ `Scripts/Regles.gd` ✏️ `Scripts/PredictionLocale.gd` ✏️ `project.godot` ✏️ `export_presets.cfg` ✏️ `.github/workflows/ci.yml` ✏️ `README.md` ✏️ `tests/unitaires.gd` ✏️ `tests/prediction_test.gd` ✏️ `tests/screenshots.gd` ➕ `tests/deux_fenetres.gd` ✏️ `tests/reseau/lancer.sh` ➕ `docs/essai-lan.md` | ◉ livraison, suites vertes 5 fois, test réseau vert 5 fois (bash 3.2 et 5), CI verte 5 fois ; `.exe` de la CI essayé par l'utilisateur sous Windows avec la fiche |
| 19 bis | **Réglages de l'essai LAN** : les réponses de `docs/essai-lan.md` (rythme à 4-6, peintre, `HAUTEUR_BANDE_HUD`, prédiction, HUD, sons, écran Résultats, découverte sous Windows, à-coup de l'intro, hôte perdu), chacune dans la constante que dit la fiche ; la trace de la bataille remesurée à chaque changement du jeu (procédure de la fiche). | selon les réponses | à écrire après l'essai |
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  (`Regles.appliquer_ecran`, 1400×788) ; **phase 19** : la taille de la fenêtre par défaut dans
  `project.godot` reste à régler ;
```

par :

```markdown
  (`Regles.appliquer_ecran`, 1400×788) ; (résolu en phase 19) la fenêtre par défaut reste 1400×454
  (`project.godot`, la largeur des captures validées des phases 17 et 18), toujours gardée dans la zone
  utile de son écran (`Regles.taille_bornee`, M7) ; sa largeur se juge à l'essai LAN
  (`docs/essai-lan.md`, § 2, phase 19 bis) ;
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- (résolu en phase 17, décision de l'utilisateur du 27/09 ; à revoir à l'essai LAN, phase 19) rythme
```

par :

```markdown
- (résolu en phase 17, décision de l'utilisateur du 27/09 ; à revoir à l'essai LAN, phase 19 bis) rythme
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  avec 7 crans pour chacun des 4 lions (le pilote court à chaque pastille) ; **phase 19** : juger en
  vrai le rythme des pastilles, le peintre et `HAUTEUR_BANDE_HUD` ;
```

par :

```markdown
  avec 7 crans pour chacun des 4 lions (le pilote court à chaque pastille) ; à juger en vrai à l'essai
  LAN (`docs/essai-lan.md`, § 5, phase 19 bis) : le rythme des pastilles, le peintre et
  `HAUTEUR_BANDE_HUD` (175 px depuis la revue finale 17) ;
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- (résolu en phase 17, décision de l'utilisateur du 27/09 ; à revoir à l'essai LAN, phase 19) le
```

par :

```markdown
- (résolu en phase 17, décision de l'utilisateur du 27/09 ; à revoir à l'essai LAN, phase 19 bis) le
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  bande est libre un tiers du temps au lieu d'un cinquième. **Phase 19** : le juger en vrai ;
```

par :

```markdown
  bande est libre un tiers du temps au lieu d'un cinquième. À juger en vrai à l'essai LAN
  (`docs/essai-lan.md`, § 5, phase 19 bis) ;
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **prochaine phase qui ajoute un scénario au test réseau** (temps de la CI, phases 16 à 18) : le
  test réseau prend ~170 s sur ce Mac (169 à 178 s mesurés en phase 18 ; ~157 s en phase 17, 140 s
  avant),
```

par :

```markdown
- **prochaine phase qui ajoute un scénario au test réseau** (temps de la CI, phases 16 à 19) : le
  test réseau prend ~175 s sur ce Mac (172 s mesurés en préparant la phase 19, avec le scénario 7 de la
  vraie diffusion, que la CI lance depuis ; 169 à 178 s en phase 18 ; ~157 s en phase 17, 140 s
  avant),
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (qui touche `tests/screenshots.gd`) : le coup de `tests/screenshots.gd` (vers la
  ligne 96) tombe pendant l'intro et n'a aucun effet ; le déplacer après `GS.demarrer()` et relancer
  le script à la main (la CI ne le lance pas). Les minuteries `null` du Spawner quand la partie se
  termine pendant l'intro sont corrigées depuis la phase 10 bis (vérifié par
  `tests/bataille_test.gd`). Y verser aussi les captures de l'écran Réseau (script jetable du plan
  de la phase 12 bis, Task 3 : titre avec Multijoueur, liste, IP invalide, refus, hébergement,
  anglais, port des balises occupé) et du salon (plan de la phase 13, Task 5 : hôte seul, salon à 3
  au bouton grisé, bouton actif, six joueurs aux pseudos larges, anglais, vues d'un client) ;
```

par :

```markdown
- (résolu en phase 19) `tests/screenshots.gd` : le coup de sa partie solo tombe après l'intro
  (`GS.pret` ; pendant l'intro, il ne comptait pas) ; les captures de l'écran Réseau (phase 12 bis), du
  salon (phase 13), de la manche à 6 couleurs (phase 17) et de l'écran Résultats (phase 18) y sont
  versées, en parties (`--parties=solo,reseau,salon,bataille,resultats`, 37 captures) ; la partie à 2
  fenêtres (phase 14) est `tests/deux_fenetres.gd`, jusqu'aux Résultats et à l'hôte perdu. Sans rendu,
  les deux déroulent tout sans rien écrire, et la CI les lance ainsi (pas « Captures ») : ils ne
  pourrissent plus. Les minuteries `null` du Spawner quand la partie se termine pendant l'intro sont
  corrigées depuis la phase 10 bis (vérifié par `tests/bataille_test.gd`) ;
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (protocole, M7 de la revue de la phase 11) : la version présentée à la poignée de
  main est `application/config/version`, « 0.13 » depuis la phase 13, qui a introduit les premiers
  RPC (ceux du salon, sur l'autoload `Reseau`) : deux postes de phases différentes s'y refusent
  désormais « version différente ». Chaque phase qui change les RPC (14, 16, 17, 18) doit encore
  l'augmenter (« 0.14 », « 0.16 », « 0.17 », « 0.18 »…) ; sinon un `.exe` de CI (Windows) et une version locale (Mac) de phases
  différentes s'accepteraient, puis échoueraient en silence sur des RPC ou des caches de nœuds
  incompatibles. Phase 19 : garder cette règle, ou la remplacer par une constante `PROTOCOLE`
  envoyée dans la demande et comparée avec le même refus `REFUS_VERSION` ;
```

par :

```markdown
- (résolu en phase 19, M7 de la revue de la phase 11) la version présentée à la poignée de main (et
  dans la balise) est `application/config/version`, qui est aussi celle du protocole : la règle de la
  phase 13 reste (« 0.13 », « 0.14 », « 0.16 », « 0.17 », « 0.18 », « 0.19 »), désormais tenue par les
  tests unitaires (`_tester_protocole`) : une empreinte du protocole (RPC de chaque script, propriétés
  répliquées des scènes, scènes apparues, tailles des formats réseau, balise) est notée avec sa version
  (`PROTOCOLE_VERSION`, `PROTOCOLE_EMPREINTE`), et une empreinte neuve sous la même version les fait
  échouer. Une constante `PROTOCOLE` à part aurait fait deux numéros à tenir au lieu d'un. **Chaque
  phase qui change le protocole** augmente la version et note la nouvelle empreinte (la ligne
  `PROTOCOLE` de la sortie des tests unitaires) ;
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (qui touche `ci.yml`, phase 12, Écart 5) : le test réseau ne vérifie la vraie diffusion
  (scénario 7 de `tests/reseau/lancer.sh`) qu'avec `DIFFUSION=1`, mesurée sur macOS seulement ; en
  CI, le scénario 6 dirige les balises vers 127.0.0.1. Essayer `DIFFUSION=1` dans le pas « Test
  réseau » (sous Linux, une diffusion revient d'ordinaire aux sockets locales) ; le garder s'il est
  vert 5 fois, sinon le noter ici. Sur Windows, la découverte n'est vérifiée qu'à la main (`.exe` de
  la CI) : deux PC de la LAN, dont un avec une carte réseau virtuelle ou un VPN (la balise part aussi
  en diffusion dirigée a.b.c.255, en supposant des réseaux en /24), **et un PC derrière un routeur
  maillé** (TP-Link Deco, eero : /22 typique, par exemple 192.168.68.0/22 ou 192.168.4.0/22), où
  cette même supposition est fausse (revue finale de la phase 12, constat 3) : `a.b.c.255` n'y est
  pas la diffusion, seulement une adresse unicast du sous-réseau ou une adresse hors lien envoyée à
  la passerelle (RFC 2644). Godot ne donnant pas le masque de sous-réseau
  (`IP.get_local_interfaces()` n'a que les adresses), aucune diffusion dirigée calculée depuis une
  adresse seule n'est fiable au-delà d'un /24 ; sur un tel réseau, seule la saisie par IP fonctionne.
  Si le test manuel confirme le problème, envisager d'envoyer aussi vers les candidats /23 et /22
  de chaque adresse privée (a.b.(c|1).255, a.b.(c|3).255) en plus du /24 et du /16, dédoublonnés (un
  datagramme de plus par seconde vers un hôte muet sur 7778, ou jeté par la passerelle, ne coûte
  rien) ; sinon, documenter la limite dans le README (« Jouer en LAN ») ;
```

par :

```markdown
- (résolu en phase 19, phase 12, Écart 5) le pas « Test réseau » de `ci.yml` lance aussi le scénario 7
  (`DIFFUSION=1`, la vraie diffusion) : vert 5 fois en CI sous Linux (Task 9 de la phase 19), comme sur
  macOS. **Phase 19 bis** : sur Windows, la découverte se vérifie à l'essai LAN (`docs/essai-lan.md`,
  § 1) : un PC à carte réseau virtuelle ou à VPN (la balise part aussi en diffusion dirigée a.b.c.255,
  en supposant des réseaux en /24), et un PC derrière un routeur maillé (TP-Link Deco, eero : /22
  typique, par exemple 192.168.68.0/22 ou 192.168.4.0/22), où cette supposition est fausse (revue finale
  de la phase 12, constat 3 : `a.b.c.255` n'y est qu'une adresse unicast du sous-réseau, ou hors lien,
  RFC 2644) ; Godot ne donnant pas le masque (`IP.get_local_interfaces()` n'a que les adresses), aucune
  diffusion dirigée calculée depuis une adresse seule n'y est fiable, et seule la saisie par IP
  fonctionne. La limite est documentée dans le README (« Jouer en LAN », dépannage) ; si l'essai la
  confirme, envoyer aussi la balise vers les candidats /23 et /22 de chaque adresse privée
  (a.b.(c|1).255, a.b.(c|3).255), dédoublonnés, avec l'identifiant de session I2 (ci-dessous) ;
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (README, M8) : le premier `heberger()` déclenche la fenêtre du pare-feu Windows
  Defender sur l'hôte (port 7777), et la première ouverture de l'écran Réseau la déclenche aussi sur
  chaque client (écoute des balises sur le port 7778, phase 12). « Annuler », ou un réseau classé
  Public : l'hôte n'est pas joignable (les clients voient « Pas de réponse de l'hôte. Pare-feu de
  l'hôte ? Réseau Privé ? » après 5 s) ou le client ne voit aucune partie (« Aucune partie trouvée.
  Pare-feu ? Réseau Privé ? Essaie par IP. »). Le README explique comment autoriser LeLion en réseau
  Privé et retirer une règle de blocage, et que deux LeLion sur un même PC ne peuvent pas lister les
  parties tous les deux (« Recherche impossible : port 7778 déjà utilisé… Rejoins par IP. ») ;
```

par :

```markdown
- (résolu en phase 19, M8) le README (« Jouer en LAN ») explique la fenêtre du pare-feu Windows
  Defender au premier `heberger()` sur l'hôte (port 7777) et à la première ouverture de l'écran Réseau
  sur chaque client (écoute des balises sur le port 7778), le réseau Privé, ce que voient les joueurs
  après un « Annuler » ou sur un réseau Public, la réparation (autoriser « LeLion multi » en Privé,
  retirer une règle de blocage dans `wf.msc`), que deux LeLion sur un même PC ne listent pas les parties
  tous les deux, et que la règle du pare-feu suit le chemin de l'exe. Depuis la phase 19, l'exe porte
  son nom dans cette fenêtre (« LeLion multi », plus « Godot Engine ») ;
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (M4 de la revue finale 12 bis ; la phase 14 règle la fenêtre au format de l'écran,
  `Regles.appliquer_ecran`) : captures du fichier jetable dans `tests/screenshots.gd`, taille de la
  fenêtre par défaut dans `project.godot`.
```

par :

```markdown
- (résolu en phase 19, M4 de la revue finale 12 bis) les captures des fichiers jetables sont dans
  `tests/screenshots.gd` et `tests/deux_fenetres.gd` ; la fenêtre par défaut de `project.godot` reste
  1400×454, gardée dans l'écran (M7, ci-dessous).
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (essai sur la LAN, phase 16) : avant la prédiction, l'utilisateur a joué une manche à 3
```

par :

```markdown
- **phase 19 bis** (essai sur la LAN, phase 16 ; `docs/essai-lan.md`, § 4) : avant la prédiction, l'utilisateur a joué une manche à 3
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
  spatialisée par lion attend que l'essai à 4-6 la réclame, phase 19) ;
```

par :

```markdown
  spatialisée par lion attend que l'essai à 4-6 la réclame : `docs/essai-lan.md`, § 7, phase 19 bis) ;
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (captures ; revue de la phase 14, vérifié en phase 16) : chez un client qui perd
  l'hôte, le moteur fait disparaître les nœuds apparus par le `MultiplayerSpawner` (lions, ennemis,
  pastilles) : le message s'affiche sur une ville sans lions. Sans conséquence pour la prédiction
  (enfant du lion, elle part avec lui ; `Manche._envoyer_commandes` vérifie qu'elle existe encore) ni
  pour le jeu (retour au titre) ; seulement visuel, à revoir avec les captures ;
```

par :

```markdown
- **phase 19 bis** (revue de la phase 14, vérifié en phase 16 ; vu sur la capture `client_5_hote_perdu`
  de `tests/deux_fenetres.gd`, phase 19) : chez un client qui perd l'hôte, le moteur fait disparaître les
  nœuds apparus par le `MultiplayerSpawner` (lions, ennemis, pastilles) : le message s'affiche sur une
  ville sans lions. Sans conséquence pour la prédiction (enfant du lion, elle part avec lui ;
  `Manche._envoyer_commandes` vérifie qu'elle existe encore) ni pour le jeu (retour au titre) ; seulement
  visuel : l'essai LAN dit s'il gêne (`docs/essai-lan.md`, § 9 : garder alors la dernière image sous le
  message) ;
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (captures, phase 14) : le script jetable de la partie à 2 fenêtres (plan de la phase
  14, Task 9) est à verser avec les autres captures ; il force une fenêtre
  (`DisplayServer.window_set_mode`) : `Regles.appliquer_ecran` ne règle pas une fenêtre en plein
  écran (réglage « plein écran » de `Parametres`) ;
```

par :

```markdown
- (résolu en phase 19) la partie à 2 fenêtres de la phase 14 est `tests/deux_fenetres.gd` ; elle force
  une fenêtre (`DisplayServer.window_set_mode`) : `Regles.appliquer_ecran` ne règle pas une fenêtre en
  plein écran (réglage « plein écran » de `Parametres`) ;
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (M7 de la revue finale 14) : en fenêtré, la largeur du 16:9 est gardée et la hauteur
  recalculée (`Regles.appliquer_ecran`) ; sur un écran 1080p, une largeur élargie à 1920 px donne une
  zone client de 1920×1080 plus la barre de titre, qui dépasse la zone utile de Windows (barre des
  tâches, bas de la ville et HUD invisibles) — `SetWindowPos` ne recadre pas. Borner par
  `DisplayServer.screen_get_usable_rect(window_current_screen)` (réduire la largeur pour garder le
  format), puis recentrer si la fenêtre sort de l'écran ;
```

par :

```markdown
- (résolu en phase 19, M7 de la revue finale 14) à chaque écran, une fenêtre se garde dans la zone utile
  de son écran (`DisplayServer.screen_get_usable_rect`, barre de titre comprise), réduite à son format
  (`Regles.taille_bornee`) et ramenée dans l'écran (`Regles.position_dans`) : une fenêtre du solo élargie
  à 1920 px ne passe plus sous la barre des tâches en 16:9 ; à revoir sous Windows à l'essai LAN
  (`docs/essai-lan.md`, § 2) ;
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (M8 de la revue finale 14, avec les captures) : en réseau, aucun lion n'est dessiné
```

par :

```markdown
- **phase 19 bis**, seulement si l'essai LAN voit l'à-coup (M8 de la revue finale 14 ;
  `docs/essai-lan.md`, § 3 ; l'essai à 3 de l'utilisateur n'en a rien dit) : en réseau, aucun lion n'est dessiné
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (essai LAN à 4-6 joueurs, phase 17) : juger en vrai le HUD de la bataille (lisibilité
```

par :

```markdown
- **phase 19 bis** (essai LAN à 4-6 joueurs, phase 17 ; `docs/essai-lan.md`, § 5 à 7) : juger en vrai le HUD de la bataille (lisibilité
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (M5 de la revue finale 16) : `PredictionLocale._journal` (jusqu'à 20 000 entrées par
  manche) et ses statistiques ne sont que de l'instrumentation de test, livrée telle quelle dans le
  jeu ; sans danger, mais à borner ou retirer.
```

par :

```markdown
- (résolu en phase 19, M5 de la revue finale 16) `PredictionLocale._journal` (20 000 entrées au plus,
  160 Ko) n'est tenu que dans les builds de débogage (`PredictionLocale.journal_actif`,
  `OS.is_debug_build()` : les tests, l'éditeur), jamais dans l'`.exe` d'export release ; le banc vérifie
  qu'une prédiction sans journal ne change pas.
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (vu en phase 18, Écart 12 du plan) : après une revanche ou un retour au salon, un
  client peut écrire `ERROR: Condition "!pinfo.recv_nodes.has(net_id)" is true` (des disparitions des
  nœuds de la manche finie arrivées après qu'il a quitté sa scène) : sans effet ; à revoir si la
  console d'un `.exe` sous Windows en montre trop, par exemple en libérant ces nœuds chez l'hôte avant
  de relancer.
```

par :

```markdown
- (sans objet, phase 19 ; vu en phase 18, Écart 12 du plan) après une revanche ou un retour au salon, un
  client peut écrire `ERROR: Condition "!pinfo.recv_nodes.has(net_id)" is true` (des disparitions des
  nœuds de la manche finie arrivées après qu'il a quitté sa scène) : sans effet, et invisible des
  joueurs (l'exe n'a pas de console, `export_console_wrapper=0` ; les `ERROR` ne vont qu'à `godot.log`).
  Libérer ces nœuds chez l'hôte avant de relancer ne garantirait pas l'ordre (les disparitions voyagent
  sur le canal 0 de la réplication, le lancement sur le canal ordonné). Les journaux de l'essai LAN
  (`docs/essai-lan.md`, § 10) diront s'il y a pire.
```

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```markdown
- **phase 19** (essai LAN, phase 18) : juger l'écran Résultats en vrai (lisibilité à 1400×788 et en
  plein écran 1080p, durée de l'animation, délai d'1 s avant un choix au clavier).
```

par :

```markdown
- **phase 19 bis** (essai LAN, phase 18 ; `docs/essai-lan.md`, § 8) : juger l'écran Résultats en vrai
  (lisibilité à 1400×788 et en plein écran 1080p, durée de l'animation, délai d'1 s avant un choix au
  clavier).
- (résolu en phase 19, M6 de la revue finale 18) le lancement et le retour au salon (canal ordonné)
  posaient leur table, places réservées forcées à 0, même quand une table plus récente du canal 0 était
  déjà arrivée : chaque table est désormais numérotée (`Reseau.numero_table`), un client ne repose jamais
  une table plus ancienne que la dernière posée (`Reseau.Pose.PERIMEE`), le lancement et le retour portent
  les places réservées de l'hôte, et une manche se joue toujours sur la table et le niveau de son
  lancement (`Reseau.niveau_manche`, que lit `Salon.entrer_en_manche`).
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
  versions différentes se comprennent encore assez pour se refuser). La version est
  `application/config/version`.
```

par :

```markdown
  versions différentes se comprennent encore assez pour se refuser). La version est
  `application/config/version`, qui est aussi celle du protocole : chaque changement du protocole la
  fait augmenter, ce que tiennent les tests unitaires (une empreinte du protocole notée avec sa version,
  phase 19).
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
  la table, phase 18). Au retour d'une manche
```

par :

```markdown
  la table, phase 18) ; chaque table est numérotée, et un client ne repose jamais une table plus
  ancienne que la dernière posée, d'où qu'elle vienne, ni ne joue une manche sur une autre table ou un
  autre niveau que ceux de son lancement (phase 19). Au retour d'une manche
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
  règles (`Regles.taille_ecran()`) en entrant dans l'arbre ; l'écran titre remet le solo
  (`configurer_solo()`) et son écran.
```

par :

```markdown
  règles (`Regles.taille_ecran()`) en entrant dans l'arbre ; l'écran titre remet le solo
  (`configurer_solo()`) et son écran. Dans une fenêtre, la hauteur suit le format de l'écran, et la
  fenêtre reste dans la zone utile de son écran, barre de titre comprise (réduite à son format au
  besoin, phase 19) ; la fenêtre par défaut fait 1400×454 (le titre, au format du solo).
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
  second écouteur ; la vraie diffusion avec `DIFFUSION=1`, hors CI.
```

par :

```markdown
  second écouteur ; la vraie diffusion avec `DIFFUSION=1`, en CI depuis la phase 19.
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
- **Visuel** : `tests/screenshots.gd` étendu (salon, manche à 6 couleurs, résultats), deux vraies
  fenêtres en localhost pour une partie manuelle.
```

par :

```markdown
- **Visuel** (phase 19) : `tests/screenshots.gd` en parties (le solo, l'écran Réseau, le salon, la
  manche à 6 couleurs, l'écran Résultats : 37 captures) et `tests/deux_fenetres.gd` (un hôte et un
  client dans deux vraies fenêtres, du salon aux Résultats et à l'hôte perdu) ; sans rendu, les deux
  déroulent tout sans rien écrire, et la CI les lance ainsi.
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
- **Windows** : test manuel de l'`.exe` issu de la CI sur un PC de la LAN (le développement se fait
  sur macOS).
```

par :

```markdown
- **Windows** : test manuel de l'`.exe` issu de la CI sur un PC de la LAN (le développement se fait
  sur macOS), avec la fiche de l'essai LAN (`docs/essai-lan.md`, phase 19), dont les réponses font la
  phase 19 bis.
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
- Preset **Windows Desktop** (x86_64) avec `.pck` intégré, donc un seul `.exe`.
```

par :

```markdown
- Preset **Windows Desktop** (x86_64) avec `.pck` intégré, donc un seul `.exe`, à l'icône du jeu, nommé
  « LeLion multi » dans ses propriétés et dans la fenêtre du pare-feu, à la version du jeu sur quatre
  nombres (phase 19 : `application/modify_resources`, vérifiés par la CI).
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
- CI : le job existant (smoke test) + tests unitaires + test réseau, puis export Windows publié
  en artefact `LeLion-multi-windows.zip`. Le déploiement GitHub Pages hérité du solo est retiré.
```

par :

```markdown
- CI : tests unitaires, smoke test, bataille locale, banc de la prédiction, test réseau (vraie
  diffusion comprise), déroulé des captures, puis exports Web (le solo) et Windows, métadonnées de l'exe
  vérifiées, artefact `LeLion-multi-windows` (un zip, 30 jours). Le déploiement GitHub Pages hérité du
  solo est retiré.
```

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```markdown
- README : section « Jouer en LAN » (ports 7777/7778 UDP, SmartScreen « Exécuter quand même »,
  pare-feu Windows sur l'hôte en réseau Privé, repli par IP, hôte en Ethernet si possible, Wi-Fi
  5 GHz).
```

par :

```markdown
- README : section « Jouer en LAN » (ports 7777/7778 UDP, SmartScreen « Exécuter quand même »,
  pare-feu Windows sur l'hôte en réseau Privé, repli par IP, hôte en Ethernet si possible, Wi-Fi
  5 GHz), faite en phase 19 : en français, avec aussi le pare-feu de chaque joueur (port 7778), la
  réparation d'un « Annuler », le Wi-Fi maillé et un dépannage message par message ; le reste du
  README en anglais.
```

Si la CI (Step 4) n'a pas été verte 5 fois avec la vraie diffusion, le point du scénario 7 ne dit pas « vert 5 fois en CI » : remplacer sa première phrase par « (phase 19, phase 12, Écart 5) le scénario 7 (`DIFFUSION=1`) reste hors CI : <ce qu'a montré la CI>. », rendre au pas « Test réseau » de `ci.yml` sa commande d'avant (sans `DIFFUSION=1`, et son nom d'avant) et au commentaire de `tests/reseau/lancer.sh` le sien, et dire de même à la spec (§10 : « la vraie diffusion avec `DIFFUSION=1`, hors CI »).

Vérifier : `grep -nE "\*\*[Pp]hase 19\*\*" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` ne sort rien ; `grep -c "phase 19 bis" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` donne 11 (mesuré en préparant ce plan) ; si le temps du test réseau mesuré au Step 2 sort de « 172 s », écrire la plage mesurée à la place, dans le point du temps de la CI.

- [ ] **Step 2 : la validation finale**

Run, dans cet ordre, un à la fois, sans relance (commandes des Global Constraints) : les tests unitaires 5 fois, le smoke test 5 fois, le test de la bataille 5 fois, le banc de la prédiction 5 fois, la trace (3 passages, deux fois), le test réseau 5 fois sous bash 5 puis 5 fois sous bash 3.2 (`/bin/bash tests/reseau/lancer.sh`), avec `DIFFUSION=1`, en notant chaque temps.
Expected : chaque passage `code 0` et `== 0 échec(s) ==`, sans `SCRIPT ERROR` ni `SHADER ERROR` ; la trace de la Task 0 ; le test réseau vert à chaque passage, « ✅ découverte en vraie diffusion » compris, en 175 s environ (sous le `timeout 300`).

Puis les vérifications d'ensemble :

```bash
git diff --stat main...HEAD
perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd tests/*.gd tests/reseau/*.gd tests/reseau/lancer.sh README.md docs/essai-lan.md .github/workflows/ci.yml export_presets.cfg
grep -n "SCRIPT ERROR\|SHADER ERROR" tests/*.gd tests/reseau/*.gd
```

Expected : `git diff --stat` ne liste que les fichiers des Global Constraints (et `tests/deux_fenetres.gd.uid`, ce plan) ; rien des deux commandes suivantes (aucun message de test ne contient ces mots, vérifié à `64e806d`).

- [ ] **Step 3 : commit**

```bash
git add docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md
git commit -m "Feuille de route et spec : phase 19 faite (exe nommé et à l'icône du jeu, README « Jouer en LAN », captures versées et déroulées en CI, tables du salon numérotées, fenêtre gardée dans l'écran, journal de la prédiction hors du jeu livré, garde du protocole, vraie diffusion en CI, fiche de l'essai LAN, version 0.19) ; chaque point « phase 19 » résolu, sans objet, ou renvoyé à la phase 19 bis (l'essai LAN) ; ligne 19 bis

<ligne fournie par l'environnement>"
```

- [ ] **Step 4 : la CI de la PR, 5 fois**

La CI ne tourne que sur les pull requests et sur `main` (`ci.yml`). Pousser la branche (`git push -u origin phase-19-livraison-windows`) ; si la PR de la phase 19 n'est pas encore ouverte, s'arrêter ici et le signaler (le contrôleur l'ouvre). Puis :

```bash
RUN=$(gh run list --branch phase-19-livraison-windows --workflow CI --limit 1 --json databaseId -q '.[0].databaseId'); echo "$RUN"
gh run watch "$RUN" --exit-status; echo "passage 1 : $?"
gh run view "$RUN" --log | grep -E "Test réseau|découverte en vraie diffusion|== [0-9]+ échec|version_exe|LeLion multi|0\.19\.0\.0|w3cdotorg|::error::" | head -40
```

puis 4 fois : `gh run rerun "$RUN" && sleep 5 && gh run watch "$RUN" --exit-status; echo "passage N : $?"` (sans `sleep` si l'environnement le refuse : `gh run watch` attend de lui-même le départ du nouveau passage).
Expected : 5 passages verts ; dans le journal, « ✅ découverte en vraie diffusion » au pas « Test réseau », les chaînes « LeLion multi », « w3cdotorg » et « 0.19.0.0 » affichées par le pas « Vérifier l'icône et les métadonnées de l'exécutable Windows », 37 captures au pas « Captures », l'artefact `LeLion-multi-windows` publié. Un pas rouge : lire son journal (`gh run view "$RUN" --log-failed`) ; pour la vraie diffusion, voir la fin du Step 1 ; pour l'exe, la Task 5 (Step 4 : ne rien affaiblir, rapporter) ; pour le reste, s'arrêter et rapporter.

- [ ] **Step 5 : la main à l'utilisateur**

Donner à l'utilisateur, pour l'essai : le lien de l'artefact `LeLion-multi-windows` du dernier passage vert, `docs/essai-lan.md` (à imprimer ou à remplir) et la section « Jouer en LAN » du README. La phase 19 bis s'écrira sur ses réponses.

---

## Décisions pour l'utilisateur

1. **La langue du README** (Écart 6) : « Jouer en LAN » en français (ce que nomme la spec, avec les libellés de Windows en français), le reste en anglais comme le README du solo. Autre choix possible : tout en français, ou « Jouer en LAN » doublé d'une version anglaise.
2. **Les métadonnées de l'exe** (Écart 8) : éditeur « w3cdotorg » et copyright « Copyright 2026 w3cdotorg, GPL-3.0 », visibles dans Propriétés → Détails (le nom « LeLion multi » ne change pas). Un autre nom (le vôtre, celui de l'auteur du jeu d'origine) se change dans `export_presets.cfg` avant la Task 5.
