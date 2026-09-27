# Phase 17 (et 17 bis) : le HUD de bataille, le chrono qui termine la manche, les sons de bataille, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** en bataille, un HUD à part (celui du solo ne change pas) : une vignette par joueur (pseudo, lion teint de sa couleur et couronné de travers pour chaque meneur, part des cellules peintes (100 % à eux tous), rang, crans, gerbe XXL et ses secondes, étourdissement, départ), la vignette de ce poste mise en évidence, et au centre le chrono de 90 s qui rougit et tique dans les dix dernières secondes ; la manche se termine au chrono **chez l'hôte seul**, qui envoie sa fin à chaque client après ses derniers tampons et son territoire ; une bataille finie garde une sortie (Échap : le titre) jusqu'aux Résultats de la phase 18 ; la musique suit le temps de la manche ; le rythme de la manche est réglé pour 4 à 6 joueurs (pastilles à plusieurs, qui expirent, loin des lions ; répit après le peintre, qui se repose plus) ; les étiquettes de pseudo ne se chevauchent plus et restent dans l'écran ; les sons de bataille (« boing » des chocs sur chaque poste, étourdissement, tic, gong de fin, annonce du peintre chez les clients, boucle du vomi du seul lion local). Sortie : **◉ HUD à 6** (captures validées par l'utilisateur) ; les cinq suites vertes 5 fois, le test réseau vert 5 fois sous bash 5 et 5 fois sous bash 3.2, dont le **scénario 13** (fin au chrono de l'hôte sous latence simulée : même HUD figé chez l'hôte et chaque client).

**Architecture:**
- **Règles** : `ReglesBataille` porte le chrono (`duree_manche`, `temps_restant`, `secondes_restantes`), la fin au chrono (`temps_ecoule_change`, appelé par `GameState._process` chez l'hôte seulement), le classement (`rangs`, ex æquo compris) et les parts (`parts` : les cellules peintes, 100 % à eux tous) ; `Regles.intensite_musique()` donne les couches de musique des deux modes (une par tiers de l'avancement) ; le rythme de la manche passe par les règles (`pastilles_en_meme_temps`, `pastille_peut_arriver`, `delai_entre_pastilles`, `duree_de_vie_pastille`, `pastilles_loin_des_lions`, `facteur_repos_peintre`, `DUREE_REPIT_ENNEMI`) : le Spawner et le peintre les lisent, le solo garde ses valeurs.
- **Présentation** : `Scenes/HUDBataille.tscn` + `Scripts/HUDBataille.gd`, posé par `Main` à la place du HUD du solo (une bataille, locale ou en réseau) ; il lit les scores sur `ville.territoire`, le chrono sur `GameState.temps_ecoule`, les réactions sur les signaux des joueurs, et montre le panneau de fin avec sa sortie. `PlacementPseudos` (logique pure) écarte à l'horizontale les pseudos qui se recouvrent et les garde dans l'écran ; `Main` l'applique à chaque image, à la position affichée de chaque lion.
- **Réseau** : `Manche` diffuse la fin de l'hôte (`_recevoir_fin_manche`, sur le canal fiable ordonné de la peinture, après les derniers tampons et le territoire) et les départs (`_recevoir_depart`, ceux d'avant la barrière en la passant) ; un client prend le chrono de l'hôte et termine sa manche à réception, jamais de lui-même.
- **Sons** : `boing`, `tic`, `fin`, `etourdi` synthétisés par `tools/generer_sons.py` ; `Audio.jouer_boing` / `jouer_etourdi` (un par image, plus discrets pour les autres lions) ; le « boing » part de `PareChocs` sur chaque poste ; l'état du peintre est répliqué (son annonce chez les clients) ; la boucle du vomi n'est qu'au lion local.
- **Tests** : logique pure dans `tests/unitaires.gd` ; sons, réseau côté hôte et HUD en réseau dans `tests/smoke_test.gd` ; HUD, fin au chrono, sortie, pseudos et pastilles dans `tests/bataille_test.gd` ; le scénario 13 de `tests/reseau/lancer.sh` (et le HUD dans l'empreinte des scénarios 9, 11, 12).

**Tech Stack:** Godot 4.7.2, GDScript typé (`class_name`), `CanvasLayer`/`Control` (vignettes construites en code, comme les cartes du salon), `MultiplayerSynchronizer` (l'état du peintre), RPC fiables de la manche, Python 3 (synthèse des sons), tests headless (`tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd`, `tests/prediction_test.gd`, `tests/reseau/lancer.sh` + `joueur.gd` + `relais.gd`), `tests/trace_lions.gd` (hors CI).

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§2 fin de manche, palette ; §4 déconnexions ; §5 collisions, « boing » ; §7 viewport ; §8 HUD et fin de manche, musique ; §10 tests) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (lignes 17 et 17 bis ; tous les points de vigilance « phase 17 », « phase 17 bis », et ceux de la phase 18 sur la fin de manche) · plan précédent : `docs/superpowers/plans/2026-09-27-phase-16-prediction.md` · prérequis : **phase 16 fusionnée** ; nouvelle branche `phase-17-hud-bataille` depuis `main`.

## Écarts assumés

1. **17 et 17 bis réunies** (une branche, une PR) : les sons de bataille touchent les mêmes fichiers que le HUD (`Audio`, `Lion`, `Main`) et le « boing » se vérifie dans les mêmes tests ; la feuille de route listait `Scripts/HUDBataille.gd`, `Scenes/HUDBataille.tscn`, `Audio`, `ReglesBataille`, les traductions (17) et `generer_sons.py`, `boing.wav`, `Audio`, `Lion`, le smoke test (17 bis). Il s'y ajoute `Regles`, `GameState`, `Main`, `Manche`, `PareChocs`, `Boss` (+ sa scène), `Spawner`, `PlacementPseudos` (nouveau), `project.godot` et les tests (liste exacte dans les Global Constraints).
2. **La fin de manche est décidée par l'hôte dès cette phase** : son chrono (`ReglesBataille.temps_ecoule_change`, appelé par `GameState._process` chez l'hôte seulement) termine la manche à 90 s ; `Manche` envoie la fin (chrono et scores de l'hôte) **après ses derniers tampons et son territoire, sur le même canal fiable ordonné** (le canal 1 de la peinture) : chez un client, les scores définitifs sont déjà appliqués quand la fin arrive. Le client prend le chrono de l'hôte (0:00 partout) et termine sa manche ; son propre chrono, parti à la fin de sa propre intro, ne termine jamais rien (point de vigilance « chrono de bataille en réseau »). **Restent à la phase 18** (la feuille de route les y met : désync-report du scénario 11, M2 et M5 de la revue finale 16) : l'état final de chaque lion dans ce même message, l'arrêt explicite de `PredictionLocale`, les statistiques de l'hôte. En attendant, l'arbre du client se met en pause à la réception (la prédiction s'arrête avec lui) ; un lion encore en mouvement au gong peut s'y figer à quelques pixels de sa place chez l'hôte (les tests ne comparent les lions qu'au repos, comme avant).
3. **Une sortie tant que la phase 18 n'existe pas** : à la fin, un panneau (« FIN DE LA MANCHE ! », le gagnant ou les ex æquo) et sa sortie (Échap, Start, ou le bouton à la souris : **le titre**, qui quitte le réseau) ; le menu local se ferme et se tait. L'hôte qui sort ramène ses clients au titre (« L'hôte a quitté la partie ») ; le retour au **salon** attend la phase 18 (il faut le RPC qui change la scène de chaque poste). Le bouton ne prend jamais le focus : un joueur qui tient encore Espace au gong ne quitte pas la partie.
4. **Les vignettes restent dans l'ordre des index** (spec §8), avec en plus le **rang** (« 1er », « 2e »… ; les ex æquo au même rang) et la couronne sur **chaque** meneur : la position ne bouge pas en pleine manche, et le classement se lit sans la couleur (deutéranopie, spec §2). Pas de rang ni de couronne tant qu'un joueur n'a aucune cellule. **Décisions de l'utilisateur du 27/09** : la couronne est **dessinée sur la tête du lion de la vignette, posée de travers** sur sa crinière (pas à côté de la part) ; la part affichée est **celle des cellules peintes** (les cellules du joueur sur toutes celles que possèdent les joueurs : les parts font 100 % à elles toutes, `ReglesBataille.parts`, plus grands restes ; 0 % pour tous tant que personne ne possède rien, sans division par zéro), au lieu du « % de la ville » de la spec §8 (à 4, environ 30 % à eux tous, des nombres à un chiffre). Le rang et la couronne viennent toujours des cellules (`rangs`), jamais des parts arrondies (deux joueurs à « 33 % » peuvent ne pas être ex æquo).
5. **Les secondes de la gerbe XXL sont décomptées par le HUD** (point de vigilance : sur un client, `Joueur.bonus_restant` reste la durée reçue au début) ; sa fin, reçue de l'hôte, les efface.
6. **Un départ est annoncé par l'hôte** (`Manche._recevoir_depart`, nouveau RPC ; ceux d'avant la barrière, un exclu par exemple, en la passant) : le joueur parti reste au classement en grisé sur chaque poste (spec §4). Sans cela, un client ne verrait qu'un lion disparaître (y compris, à tort, quand il perd l'hôte : le moteur y fait disparaître tous les lions).
7. **Les pseudos glissent à l'horizontale seulement** (`PlacementPseudos`) : deux étiquettes qui se recouvrent se serrent en un bloc centré sur leurs places voulues, gardé dans l'écran. Leur hauteur ne change jamais : `Lion._marge_haute()` (la borne haute du déplacement, donc la physique et la prédiction) reste la même, et la trace des lions ne bouge pas. Empiler les étiquettes l'aurait changée.
8. **Quatre sons neufs** (`boing`, `tic`, `fin`, `etourdi`), synthétisés sans hasard (reproductibles) ; `tools/generer_sons.py` prend désormais des noms (`python3 tools/generer_sons.py boing tic fin etourdi`) : le bruit de « mort » n'est pas semé, tout régénérer changerait `mort.wav`. Les chocs et étourdissements entre d'autres lions que celui de ce poste sont 9 dB plus bas ; le vomi des autres lions ne joue rien (une boucle spatialisée par lion serait du YAGNI tant que l'essai à 4-6 ne la réclame pas).
9. **La musique suit `Regles.intensite_musique()`** dans les deux modes : `int(avancement() × 3)`, la formule du solo (`progression / seuil × 3`, identique) et, en bataille, le temps de la manche (arpèges à 30 s de jeu, mélodie à 60 s : « 60 s et 30 s restantes » de la spec §8).
10. **Le rythme de la manche est réglé ici pour 4 à 6 joueurs** (décision de l'utilisateur du 27/09, sans essai à 4-6 : valeurs justifiées dans la Task 6 et dans `ReglesBataille`, à revoir à l'essai LAN de la phase 19) : en bataille, **2 pastilles à la fois de 2 à 3 joueurs, 3 de 4 à 6**, une **toutes les 4 s** sous ce plafond, qui **expire au bout de 12 s** si personne ne la prend (elle ne bloque plus les autres), née loin du **centre** des lions et, si aucun des dix essais n'est à 300 px de tous, au plus loin des dix ; **3 s de répit** après un étourdissement par un ennemi (au lieu de 1 s : le temps de fuir le peintre) et **la pause du peintre doublée** (4 s au lieu de 2). Le solo ne change pas (une pastille à la fois, 6 s après la précédente, coin du lion, dernier essai ; 1,5 s d'invulnérabilité ; sa trace non plus). Mesuré sur la manche pilotée à 4 (un pilote qui court à chaque pastille) : 7 crans pour chacun en fin de manche, au lieu de 2 à 5.
11. **La trace des lions change deux fois, pour la bataille seulement** : sa partie de bataille dure la manche entière (5400 ticks après l'intro), que le chrono termine désormais un tick avant la fin (l'arbre en pause, les lions ne bougent plus) : `TRACE bataille 689790676` → `976004010` à la Task 1 ; puis ses pastilles et son peintre suivent le rythme de la Task 6 : → `2492461451`. Solo (`185311436`) et réplique (`3757044499`) ne changent jamais. Entre la Task 1 et la Task 6, et après la Task 6, chaque tâche garde la trace telle quelle.
12. **Version 0.17** (`application/config/version`) : deux RPC neufs dans la manche et une propriété de plus dans le `Synchro` du peintre.
13. **Test réseau** : le scénario 13 (fin au chrono de l'hôte, 1 hôte + 2 clients derrière le relais, manche de 10 s) ajoute environ 17 s : mesuré 140 s → 156 à 158 s sur ce Mac, sous le `timeout 300` du pas de CI (`ci.yml` inchangé). L'empreinte de fin de manche des scénarios 9, 11 et 12 compte désormais le HUD (`hud=` : chrono, pseudos, parts, rangs, départs) : le même chez l'hôte et chez chaque client.
14. **`ReglesBataille.duree_manche`** est une variable statique réglable par le test réseau (comme `Manche.delai_chargement`), livrée dans le jeu, toujours égale à `DUREE_MANCHE`.
15. **Le HUD de la bataille tourne l'arbre en pause** (`process_mode` « toujours » : le panneau de fin et Échap) mais ne se met pas à jour pendant une pause ; il se rafraîchit une dernière fois à la fin de la manche. En bataille locale, le menu de pause fige donc aussi le HUD.

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), commandes depuis `~/Sites/LeLion-multi`, branche `phase-17-hud-bataille`.
- Fichiers de la phase : ➕ `Scripts/HUDBataille.gd`, `Scenes/HUDBataille.tscn`, `Scripts/PlacementPseudos.gd` (+ les `.uid` des deux scripts, générés par l'import), `Assets/Sons/boing.wav`, `tic.wav`, `fin.wav`, `etourdi.wav` (+ leurs `.import`) ; ✏️ `Scripts/Regles.gd`, `Scripts/ReglesBataille.gd`, `Scripts/GameState.gd`, `Scripts/Audio.gd`, `Scripts/Lion.gd`, `Scripts/PareChocs.gd`, `Scripts/Boss.gd`, `Scenes/Boss.tscn`, `Scripts/Main.gd`, `Scripts/Manche.gd`, `Scripts/Spawner.gd`, `tools/generer_sons.py`, `Assets/Traductions/traductions.csv` (+ les deux `.translation` que l'import régénère), `project.godot`, `tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd`, `tests/reseau/joueur.gd`, `tests/reseau/lancer.sh` ; la spec et la feuille de route (Task 9). **`Scripts/Reseau.gd`, `Scripts/HUD.gd`, `Scenes/HUD.tscn`, `Scenes/Main.tscn`, `tests/trace_lions.gd`, `tests/prediction_test.gd` et `.github/workflows/ci.yml` ne changent pas** ; `Scripts/Reseau.gd` n'est jamais modifié, pas même le temps d'un essai.
- **Le solo ne change pas** : son HUD, sa musique, ses pastilles, son peintre, sa trace (`TRACE solo 185311436`, `TRACE replique 3757044499` à chaque tâche) ; aucune vérification existante n'est affaiblie (seules changent, en bataille, celle des pastilles, mesurée désormais depuis le centre des lions, celle de l'immunité après un ennemi (3 s) et l'attente de la pastille suivante (4 s, Task 6)).
- **La trace** : `export PATH="/opt/homebrew/bin:$PATH"; godot --headless --import . > /dev/null 2>&1; for k in 1 2 3; do timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/trace_lions.gd 2>&1 | grep -E "^TRACE|❌|SCRIPT ERROR" | tr '\n' ' '; echo; done`. Verdict : deux passages consécutifs identiques (les deux premiers après un import peuvent différer, phase 15 bis). Référence avant la phase (Task 0) : `TRACE bataille 689790676 TRACE solo 185311436 TRACE replique 3757044499` ; de la Task 1 à la Task 5 : `TRACE bataille 976004010` ; à partir de la Task 6 : `TRACE bataille 2492461451` (Écart 11) ; solo et réplique inchangés. Les empreintes dépendent de la plateforme : seules comptent celles de ce poste (si la référence de la Task 0 diffère de celle-ci, la bataille doit changer aux Tasks 1 et 6 et nulle part ailleurs ; solo et réplique jamais).
- **Valeurs de la spec** (§2, §8) : manche de 90 s (`ReglesBataille.DUREE_MANCHE`) ; chrono rouge et tic dans les 10 dernières secondes (`SECONDES_TIC`) ; arpèges à 30 s de jeu, mélodie à 60 s ; 6 vignettes au plus, dans l'ordre des index ; palette et pseudos de 12 caractères au plus (`Reseau.PSEUDO_MAX`). **Décisions de l'utilisateur du 27/09** (elles priment) : part = cellules du joueur / cellules possédées par tous (100 % à eux tous, 0 % sans cellule) ; couronne de travers sur la tête du lion de la vignette ; rythme de bataille : 2 pastilles (2-3 joueurs) ou 3 (4-6), 4 s, 12 s de vie, loin du centre des lions, le plus loin des dix essais ; 3 s de répit après un ennemi, pause du peintre × 2.
- Identifiants, commentaires, messages de test et traductions en français (EN à côté), docstrings `##`, tabulations. Tout texte visible neuf passe par `Assets/Traductions/traductions.csv`.
- **Aucune séquence d'échappement `\u…` n'est tapée dans un fichier**. Vérifier après chaque écriture : `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd Scenes/*.tscn tests/*.gd tests/reseau/*.gd tests/reseau/lancer.sh Assets/Traductions/traductions.csv tools/generer_sons.py` ne sort rien.
- Un test `--script` est compilé **avant** les autoloads : il ne nomme ni `GameState`, ni `Lion`, ni `HUDBataille`, ni la ville, ni `Main` (qui nomment des autoloads) ; il peut nommer `ReglesBataille`, `Regles`, `EtatPartie`, `Territoire`, `Joueur`, `Commandes`, `PlacementPseudos`. Les autoloads s'y lisent par `root.get_node("…")`.
- Après la création d'un script à `class_name`, d'une scène ou d'un son : `godot --headless --import .` avant les tests (il génère les `.uid`, les `.import` des sons et les `.translation`, à committer avec eux).
- **Toujours lancer un test Godot avec `timeout`** et chercher les erreurs :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; O=""; timeout -k 5 300 godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd; O=""`, `T=tests/bataille_test.gd; O="--fixed-fps 60"`, `T=tests/prediction_test.gd; O="--fixed-fps 60"` ; le test réseau : `timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $?"; grep -E "❌|✅|== |\(chrono|\(latence" "$TMPDIR/r.log"`). Une `SCRIPT ERROR` ne change pas le code de sortie ; un script qui ne compile pas sort aussi en `code 0`, sans ligne `== n échec(s) ==`. Bruit connu : « ObjectDB instances were leaked », « resources still in use at exit » ; les `ERROR` voulues des plans des phases 14 et 16 (dont `ERROR: Lion.avancer hors d'une image physique : ce pas est ignoré`, smoke test, une fois).
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`**.
- **Ne jamais lancer deux suites en même temps** : les tests unitaires, le smoke test et le test réseau ouvrent des ports locaux (1777x à 1979x) ; deux à la fois se les disputent (vu en préparant ce plan : un faux rouge des unitaires pendant le test réseau).
- **Attentes événementielles** : chaque attente du test réseau porte sur une ligne de journal ou un état observé, bornée ; les tests `--fixed-fps 60` avancent au tick près.
- Les cinq suites (unitaires, smoke, bataille, banc de la prédiction, trace) se valident sur **5 passages consécutifs verts**, sans relance ; le test réseau 5 fois sous bash 5 et 5 fois sous bash 3.2 (`/bin/bash`, macOS), sans relance.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Le chrono d'un client en avance ou en retard sur celui de l'hôte** (il part à la fin de sa propre intro, décalé de la latence ; un Wi-Fi qui retarde la fin) : un client ne termine jamais la manche de lui-même, même son chrono à zéro ; la fin de l'hôte y pose le chrono de l'hôte, et chaque poste finit à 0:00 sur le même HUD. → unitaires `_tester_chrono_bataille` (« sur un client, le chrono passé à zéro ne termine pas la manche », Task 1) ; scénario 13 (`ECART_CHRONO` au plus 0,25 s, lignes `FIN` identiques, Task 7).
2. **Les derniers scores qui arrivent avec la fin** (le dernier territoire et la fin dans la même image chez un client, l'arbre qui se met en pause avant que le HUD n'ait relu le territoire) : le HUD de chaque client montre les scores définitifs de l'hôte. → la fin part sur le canal de la peinture, après les tampons et le territoire, et le HUD se rafraîchit à la fin (Tasks 4 et 5) ; `hud=` dans l'empreinte des scénarios 9, 11, 12 et lignes `FIN` du scénario 13 (Task 7) ; smoke « la fin de manche chez l'hôte : la manche la diffuse… » (Task 5).
3. **Une bataille finie** : Échap (ou Start) doit sortir même l'arbre en pause, le menu local ne doit pas avaler la touche, et un joueur qui tient encore Espace (vomir, valider) au gong ne doit pas quitter la partie par accident. → `tests/bataille_test.gd`, `_tester_hud` : « Espace tenu au gong… ne quitte pas la partie : rien n'a le focus », « Échap, la manche finie : retour au titre », « le menu local se tait » (Task 4) ; scénario 13 : l'hôte sort par Échap, ses clients le voient partir (Task 7).
4. **Deux lions qui se touchent, ou collés à un bord, avec des pseudos larges** (« WWWWWWWWWWWW »), et le lion local d'un client décalé par sa correction douce : les pseudos ne se recouvrent pas, ne sortent pas de l'écran, suivent le lion affiché, et la physique ne change pas. → unitaires `_tester_placement_pseudos` ; `tests/bataille_test.gd` « bord gauche / bord droit : deux pseudos voisins s'écartent… », « le pseudo suit la position affichée du lion » ; trace inchangée (Task 3).
5. **Un joueur qui part avant la barrière (exclu) ou en pleine manche** : il reste au classement en grisé chez l'hôte **et chez chaque client** (qui ne voit qu'un lion disparaître, ou rien du tout pour un exclu). → smoke « (absent) l'exclu reste au classement, en grisé… », « le HUD grise Bob, parti… » (Task 5) ; `hud=…:parti` identique chez l'hôte et chez le client resté du scénario 9 (le muet exclu et le partant) et chez les clients restés du scénario 11 (l'arraché) (Task 7).

---

### Task 0 : vérifications et référence de la trace

Ce plan est commité par le commit de planification : ne pas le recommiter, **ne jamais le modifier**. Vérifier que la phase 16 est fusionnée : `test -f Scripts/PredictionLocale.gd && test -f tests/prediction_test.gd && grep -c 'config/version="0.16"' project.godot` donne `1`, et `wc -l Scripts/Lion.gd Scripts/Manche.gd Scripts/Main.gd` donne 409, 458 et 333. Sinon, s'arrêter et le signaler. Les blocs « remplacer » citent le code tel que la phase 16 le laisse (vérifié en appliquant ce plan, bloc par bloc, à une copie de `origin/phase-16-prediction`) : si une ancre a bougé, l'adapter au texte réel sans changer le remplacement, et le noter.

« Step 0 » (règle du projet pour un fichier de plus de 300 lignes : `Scripts/Lion.gd`, `Scripts/Manche.gd`, `Scripts/Main.gd`, `tests/smoke_test.gd`, `tests/unitaires.gd`, `tests/bataille_test.gd`, `tests/reseau/joueur.gd`) : pas de code mort à retirer (la phase 16 vient de passer sur le lion, la manche et la scène). Le vérifier pour les trois scripts du jeu :

```bash
for f in Scripts/Lion.gd Scripts/Manche.gd Scripts/Main.gd; do
	for n in $(grep -oE "^(const|var|func|static var|@onready var|@export var) [A-Za-z_]+" $f | awk '{print $NF}'); do
		[ "$(grep -rc "\b$n\b" Scripts tests Scenes | awk -F: '{s+=$2} END {print s}')" -lt 2 ] && echo "$f $n"
	done
done; grep -n "print(" Scripts/Lion.gd Scripts/Manche.gd Scripts/Main.gd
```

Expected (mesuré) : rien.

Puis : `git switch -c phase-17-hud-bataille`, et la référence de la trace (commande des Global Constraints), notée dans `$TMPDIR/trace_reference.txt` (jamais commitée). Mesuré sur le Mac de préparation : `TRACE bataille 689790676 TRACE solo 185311436 TRACE replique 3757044499` (trois passages identiques).

---

### Task 1 : le chrono de la manche, sa fin chez l'hôte, le classement, les parts et la musique (`ReglesBataille`, `Regles`, `GameState`)

**Files:**
- Modify: `Scripts/ReglesBataille.gd`, `Scripts/Regles.gd`, `Scripts/GameState.gd`
- Test: `tests/unitaires.gd`

**Interfaces:**
- Consumes : `EtatPartie.temps_ecoule`, `terminer_partie`, `Regles.manche_en_cours()`, `avancement()`.
- Produces (Tasks 4, 5, 7) : `ReglesBataille.SECONDES_TIC` (10) ; `static var ReglesBataille.duree_manche: float` (défaut `DUREE_MANCHE`, réglable par `load("res://Scripts/ReglesBataille.gd").duree_manche = S`) ; `func temps_restant() -> float` ; `func secondes_restantes() -> int` ; `static func rangs(cellules: Array[int]) -> Array[int]` (1 = premier, ex æquo au même rang, 0 = sans cellule) ; `static func parts(cellules: Array[int]) -> Array[int]` (la part de chaque joueur dans les cellules possédées, en pourcents entiers qui font 100, plus grands restes ; toutes nulles sans cellule : décision de l'utilisateur du 27/09) ; `func Regles.intensite_musique() -> int` ; `func Regles.temps_ecoule_change() -> void` (sans effet en solo ; en bataille, `terminer_partie(true)` au chrono), appelé par `GameState._process` chez l'hôte seulement.

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_interpolation_lion()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_interpolation_lion()
	_tester_chrono_bataille()
	print("== %d échec(s) ==" % _echecs)
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
## côtés (l'hôte la tient pour établie à l'accusé de réception de sa réponse) ; 1 s au plus.
func _connecter(
```

par :

```gdscript
## Phase 17 : le chrono de la manche (affichage, fin chez l'hôte seulement), le classement et les
## couches de musique.
func _tester_chrono_bataille() -> void:
	print("-- Chrono et classement de la bataille (phase 17)")
	var gs: Node = root.get_node("GameState")
	gs.configurer_bataille(2)
	gs.nouvelle_partie()
	gs.pret = true
	var r: ReglesBataille = gs.regles
	var affiches: Array[int] = []
	for t in [0.0, 0.5, 80.0, 80.2, 89.99, 90.0, 95.0]:
		gs.temps_ecoule = t
		affiches.append(r.secondes_restantes())
	_check(affiches == [90, 90, 10, 10, 1, 0, 0] and r.temps_restant() == 0.0,
		"le chrono affiche les secondes restantes arrondies au-dessus : 1:30 au départ, 0:01 jusqu'au bout, 0:00 à la fin (%s)" % [affiches])
	var musique: Array[int] = []
	for t in [0.0, 29.9, 30.0, 59.9, 60.0, 90.0]:
		gs.temps_ecoule = t
		musique.append(r.intensite_musique())
	_check(musique == [0, 0, 1, 1, 2, 3], "en bataille, les arpèges entrent à 30 s de jeu, la mélodie à 60 s (%s)" % [musique])
	gs.temps_ecoule = 0.0
	var fins: Array[bool] = []
	var sur_fin := func(v: bool) -> void: fins.append(v)
	gs.partie_terminee.connect(sur_fin)
	# Sur un client : son chrono tourne, jamais il ne termine la manche lui-même
	var api := SceneMultiplayer.new()
	var pair := ENetMultiplayerPeer.new()
	_check(pair.create_client("127.0.0.1", 17796) == OK, "(pré-condition) GameState sur un pair client")
	api.multiplayer_peer = pair
	set_multiplayer(api, gs.get_path())
	gs._process(ReglesBataille.DUREE_MANCHE + 5.0)
	_check(gs.partie_en_cours and fins.is_empty() and r.secondes_restantes() == 0,
		"sur un client, le chrono passé à zéro ne termine pas la manche : elle attend la fin de l'hôte")
	set_multiplayer(null, gs.get_path())
	pair.close()
	# Sur l'hôte (hors réseau compris) : la manche se termine quand le chrono arrive à zéro, pas avant
	gs.nouvelle_partie()
	gs.pret = true
	gs._process(ReglesBataille.DUREE_MANCHE - 0.5)
	_check(gs.partie_en_cours and fins.is_empty(), "sur l'hôte, la manche continue tant que le chrono n'est pas à zéro")
	gs._process(0.5)
	_check(not gs.partie_en_cours and fins == [true], "sur l'hôte, le chrono à zéro termine la manche, une fois (%s)" % [fins])
	gs._process(1.0)
	_check(fins.size() == 1 and is_equal_approx(gs.temps_ecoule, ReglesBataille.DUREE_MANCHE),
		"une manche finie ne se retermine pas, son chrono reste arrêté")
	# Une manche courte (le test réseau) : la durée se règle sur le script des règles
	var script_regles: Script = load("res://Scripts/ReglesBataille.gd")
	script_regles.duree_manche = 10.0
	gs.nouvelle_partie()
	gs.pret = true
	gs._process(10.0)
	_check(not gs.partie_en_cours and fins.size() == 2 and is_equal_approx(r.avancement(), 1.0),
		"une manche réglée sur 10 s (test réseau) se termine à 10 s")
	script_regles.duree_manche = ReglesBataille.DUREE_MANCHE
	gs.partie_terminee.disconnect(sur_fin)
	# En solo, le chrono compte sans jamais finir la partie ; la musique suit la ville peinte
	gs.configurer_solo()
	gs.nouvelle_partie()
	gs.pret = true
	gs._process(500.0)
	gs.progression = gs.seuil_victoire() * 0.7
	_check(gs.partie_en_cours and gs.regles.intensite_musique() == 2,
		"en solo, le chrono ne finit jamais la partie, et la musique suit la ville peinte (une couche par tiers du seuil)")
	gs.progression = 0.0
	gs.partie_en_cours = false
	gs.pret = false

	_check(ReglesBataille.rangs([0, 0, 0]) == [0, 0, 0], "au départ, personne n'est classé (aucune cellule)")
	_check(ReglesBataille.rangs([5, 9, 5, 0]) == [2, 1, 2, 0] and ReglesBataille.rangs([7, 7, 3]) == [1, 1, 3],
		"le plus de cellules est premier ; des ex æquo partagent leur rang, le suivant saute d'autant")
	_check(ReglesBataille.parts([0, 0, 0]) == [0, 0, 0] and ReglesBataille.parts([3, 0]) == [100, 0],
		"la part des cellules peintes : 0 % pour tous tant que personne ne possède rien (aucune division par zéro), 100 % pour le seul peintre")
	var parts_a_4 := ReglesBataille.parts([349, 274, 326, 426])
	_check(ReglesBataille.parts([1, 1, 1]) == [34, 33, 33] and ReglesBataille.parts([2, 1]) == [67, 33]
		and ReglesBataille.parts([5, 9, 5, 0]) == [26, 48, 26, 0] and parts_a_4 == [25, 20, 24, 31],
		"les parts font 100 à elles toutes, le reste de l'arrondi aux plus grands restes, jamais à un joueur sans cellule (%s)" % [parts_a_4])


## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
## côtés (l'hôte la tient pour établie à l'accusé de réception de sa réponse) ; 1 s au plus.
func _connecter(
```

- [ ] **Step 2 : ils échouent**

Run : la commande des Global Constraints avec `T=tests/unitaires.gd; O=""`.
Expected (mesuré) : le script ne compile pas (`SCRIPT ERROR: Parse Error: Static function "rangs()" not found in base "ReglesBataille".`, puis `Failed to load script "res://tests/unitaires.gd"`), `code 0` et aucune ligne `== n échec(s) ==`.

- [ ] **Step 3 : les règles**

Dans `Scripts/ReglesBataille.gd`, remplacer :

```gdscript
## en 16:9 ; une pastille est toujours offerte, l'étoile toujours possible, jamais de cœur. La
## fin de manche au chrono (phase 17) s'y ajoutera.

const DUREE_ETOURDI_VOMI := 1.5
const DUREE_ETOURDI_ENNEMI := 2.5
const DUREE_IMMUNITE := 1.0
## Durée d'une manche (spec §2), dont le temps écoulé fait l'avancement. Le chrono qui la termine
## vient en phase 17.
const DUREE_MANCHE := 90.0
## Écran de la bataille (spec §7) : 16:9, la skyline posée en bas sous un grand ciel.
const TAILLE_ECRAN := Vector2i(2000, 1125)
```

par :

```gdscript
## en 16:9 ; une pastille est toujours offerte, l'étoile toujours possible, jamais de cœur. Le
## chrono termine la manche chez l'hôte (phase 17) ; le plus de cellules gagne, ex æquo possibles
## (`rangs`).

const DUREE_ETOURDI_VOMI := 1.5
const DUREE_ETOURDI_ENNEMI := 2.5
const DUREE_IMMUNITE := 1.0
## Durée d'une manche (spec §2) : son temps écoulé fait l'avancement, et le chrono la termine chez
## l'hôte.
const DUREE_MANCHE := 90.0
## Secondes restantes à partir desquelles le chrono du HUD passe au rouge et tique (spec §8).
const SECONDES_TIC := 10
## Écran de la bataille (spec §7) : 16:9, la skyline posée en bas sous un grand ciel.
const TAILLE_ECRAN := Vector2i(2000, 1125)

## Durée des prochaines manches : DUREE_MANCHE, réglable par le test réseau (une manche courte ; le
## script, `load("res://Scripts/ReglesBataille.gd")`, porte cette variable, comme
## `Manche.delai_chargement`).
static var duree_manche := DUREE_MANCHE
```

Dans `Scripts/ReglesBataille.gd`, remplacer :

```gdscript
func avancement() -> float:
	return partie.temps_ecoule / DUREE_MANCHE
```

par :

```gdscript
func avancement() -> float:
	return partie.temps_ecoule / duree_manche


## Secondes de manche qui restent, jamais négatives.
func temps_restant() -> float:
	return maxf(duree_manche - partie.temps_ecoule, 0.0)


## Le chrono du HUD, en secondes entières : arrondi au-dessus (1:30 pendant la première seconde,
## 0:01 jusqu'au bout, 0:00 une fois la manche finie).
func secondes_restantes() -> int:
	return ceili(temps_restant())


## Le chrono arrivé à zéro termine la manche (spec §2 : personne n'est éliminé). Appelé chez l'hôte
## seulement (`GameState._process`) : le chrono d'un client, parti à la fin de sa propre intro, est
## décalé de la latence ; il attend la fin de l'hôte (`Manche`).
func temps_ecoule_change() -> void:
	if manche_en_cours() and partie.temps_ecoule >= duree_manche:
		partie.terminer_partie(true)


## Le rang de chaque joueur d'après ses cellules (`cellules[i]` : celles du joueur d'index i) : 1
## pour le plus de cellules, les ex æquo au même rang, le suivant sautant d'autant (1, 1, 3) ; 0
## pour un joueur sans cellule, pas classé (au départ, personne ne mène).
static func rangs(cellules: Array[int]) -> Array[int]:
	var resultat: Array[int] = []
	for n in cellules:
		var rang := 0
		if n > 0:
			rang = 1
			for autre in cellules:
				if autre > n:
					rang += 1
		resultat.append(rang)
	return resultat


## La part de chaque joueur dans les cellules possédées (`cellules[i]` : celles du joueur d'index i),
## en pourcents entiers qui font 100 à eux tous : les centièmes perdus à l'arrondi vont aux plus grands
## restes (à égalité, au plus petit index), jamais à un joueur sans cellule ; toutes nulles tant que
## personne ne possède de cellule. Ce qu'affiche le HUD (spec §8) ; le classement vient des cellules
## (`rangs`), pas de ces parts arrondies.
static func parts(cellules: Array[int]) -> Array[int]:
	var total := 0
	for n in cellules:
		total += n
	var resultat: Array[int] = []
	var restes: Array[Vector2i] = []  # (reste, index)
	var distribue := 0
	for i in range(cellules.size()):
		var part := 0 if total <= 0 else cellules[i] * 100 / total
		resultat.append(part)
		distribue += part
		restes.append(Vector2i(0 if total <= 0 else cellules[i] * 100 % total, i))
	if total <= 0:
		return resultat
	restes.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x > b.x or (a.x == b.x and a.y < b.y))
	for k in range(100 - distribue):
		resultat[restes[k].y] += 1
	return resultat
```

Dans `Scripts/Regles.gd`, remplacer :

```gdscript
func avancement() -> float:
	return 0.0
```

par :

```gdscript
func avancement() -> float:
	return 0.0


## Couches de musique à entendre (0 : la base seule, 1 : + arpèges, 2 : + mélodie ; au-delà, `Audio`
## borne) : une par tiers de l'avancement (en solo, la ville peinte rapportée au seuil ; en
## bataille, les arpèges à 30 s de jeu et la mélodie à 60 s, spec §8).
func intensite_musique() -> int:
	return int(avancement() * 3.0)


## Le temps de la partie vient d'avancer (`GameState._process`, chez l'hôte seulement) : sans effet
## par défaut (le chrono du solo ne fait que compter) ; en bataille, le chrono termine la manche.
func temps_ecoule_change() -> void:
	pass
```

Dans `Scripts/GameState.gd`, remplacer :

```gdscript
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
```

par :

```gdscript
## Le chrono tourne sur chaque poste (l'affichage) ; les minuteries des joueurs (étourdissement,
## immunité, gerbe XXL) et la fin de la manche au chrono (`Regles.temps_ecoule_change`) ne sont
## décidées que par l'hôte : un client les reçoit de la manche (`Joueur.recevoir_fin_etourdissement`,
## `recevoir_fin_bonus`, phase 14 ; la fin de manche, phase 17), sans quoi chaque poste émettrait ses
## propres fins, un peu avant ou après celles de l'hôte.
func _process(delta: float) -> void:
	if not partie_en_cours or not pret:
		return
	temps_ecoule += delta
	if not multiplayer.is_server():
		return
	for j in joueurs:
		j.avancer(delta)
	regles.temps_ecoule_change()
```

- [ ] **Step 4 : les tests passent ; la trace de la bataille change (et elle seule)**

Run : les unitaires (commande des Global Constraints), puis `T=tests/smoke_test.gd`, `T=tests/bataille_test.gd; O="--fixed-fps 60"`, `T=tests/prediction_test.gd; O="--fixed-fps 60"`, puis la trace.
Expected (mesuré) : `== 0 échec(s) ==` pour chacune (unitaires : 375 ✅, dont les 13 de la section « Chrono et classement de la bataille (phase 17) », parts comprises) ; la trace, deux passages identiques : `TRACE bataille 976004010 TRACE solo 185311436 TRACE replique 3757044499` (la bataille de la trace dure la manche entière : le chrono la termine désormais, Écart 11 ; solo et réplique inchangés). Noter cette nouvelle référence de la bataille dans `$TMPDIR/trace_reference.txt`.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/ReglesBataille.gd Scripts/Regles.gd Scripts/GameState.gd tests/unitaires.gd
git commit -m "Règles de bataille : le chrono de 90 s termine la manche chez l'hôte seul (un client attend sa fin), secondes restantes arrondies au-dessus, classement avec ex æquo, parts des cellules peintes qui font 100 %, couches de musique au tiers de l'avancement dans les deux modes ; durée réglable par le test réseau

<ligne fournie par l'environnement>"
```

---

### Task 2 : les sons de bataille (17 bis : « boing », étourdissement, gong, tic ; annonce du peintre chez les clients ; boucle du vomi du seul lion local)

**Files:**
- Modify: `tools/generer_sons.py`, `Scripts/Audio.gd`, `Scripts/Lion.gd`, `Scripts/PareChocs.gd`, `Scripts/Boss.gd`, `Scenes/Boss.tscn`
- Create: `Assets/Sons/boing.wav`, `tic.wav`, `fin.wav`, `etourdi.wav` (par le script, avec leurs `.import` par l'import)
- Test: `tests/smoke_test.gd`

**Interfaces:**
- Consumes : `GameState.joueur_local()`, `GameState.regles.compte_le_territoire()`, `Ennemi.est_replique()`.
- Produces (Tasks 3 à 5) : `Audio.SONS` avec `"boing"`, `"tic"`, `"fin"`, `"etourdi"` ; `func Audio.jouer(nom: String, db := 0.0) -> void` ; `func Audio.jouer_boing(concerne_ce_poste: bool) -> void` et `func Audio.jouer_etourdi(ce_poste: bool) -> void` (un par image au plus, `DB_AUTRES` = -9 dB pour un autre lion) ; `Audio._on_partie_terminee` : en bataille, le gong `"fin"` (ni victoire ni mort, la musique gardée) ; `func Lion.est_local() -> bool` ; `Boss.etat` répliqué (propriété `.:etat` du `Synchro`, à chaque changement).

- [ ] **Step 1 : les tests**

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	# Phase 14 : chaque ennemi et chaque pastille porte son MultiplayerSynchronizer (`Synchro`) : position
	# à l'apparition (et ensuite pour les ennemis, qui bougent chez l'hôte), couleur d'une pastille, côté
	# du peintre, inclinaison de la coccinelle.
	var attendues := {
		"Soucoupe": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS]],
		"Coccinelle": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS], [^".:rotation", SceneReplicationConfig.REPLICATION_MODE_ALWAYS]],
		"Boss": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS], [^".:cote", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE]],
```

par :

```gdscript
	# Phase 14 : chaque ennemi et chaque pastille porte son MultiplayerSynchronizer (`Synchro`) : position
	# à l'apparition (et ensuite pour les ennemis, qui bougent chez l'hôte), couleur d'une pastille, côté
	# du peintre, inclinaison de la coccinelle ; l'état du peintre (phase 17 bis : son annonce).
	var attendues := {
		"Soucoupe": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS]],
		"Coccinelle": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS], [^".:rotation", SceneReplicationConfig.REPLICATION_MODE_ALWAYS]],
		"Boss": [[^".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS], [^".:cote", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE],
			[^".:etat", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE]],
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	_check(boss_client.sprite.scale.x < 0.0 and boss_client.cote == -1, "sur un client, le peintre regarde du côté reçu de l'hôte (sprite en miroir)")
```

par :

```gdscript
	_check(boss_client.sprite.scale.x < 0.0 and boss_client.cote == -1, "sur un client, le peintre regarde du côté reçu de l'hôte (sprite en miroir)")
	# Phase 17 bis : l'annonce du peintre, décidée par l'hôte, s'entend aussi chez chaque client (son état
	# est répliqué) ; l'état répété, ou un autre état, ne rejoue rien
	var annonces_avant := _sons.count("boss")
	boss_client.etat = boss_client.Etat.ANNONCE
	boss_client.etat = boss_client.Etat.ANNONCE
	boss_client.etat = boss_client.Etat.ENTREE
	_check(_sons.count("boss") == annonces_avant + 1 and boss_client._tween == null,
		"sur un client, l'annonce du peintre reçue de l'hôte joue son son, une fois, sans lancer de tween")
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	# Étourdissement par un ennemi : immobile, repoussé, étoiles, sans barbouillage
	var materiau_bleu := lb.sprite.material as ShaderMaterial
	lb.commandes.direction_voulue = Vector2.LEFT
	await _frames(5)
	_check(lb.deplacement.vitesse.x < 0.0, "(pré-condition) le lion bleu avance selon ses commandes")
	materiau_bleu.set_shader_parameter("barbouillage_force", 0.5)  # pour un check discriminant : un ennemi doit bien la remettre à 0
	GS.regles.lion_touche_par_ennemi(j_bleu, lb.global_position + lb.CENTRE + Vector2(-80, 0))
```

par :

```gdscript
	# Phase 17 bis : la boucle du vomi n'appartient qu'au lion de ce poste ; un autre lion qui arrête
	# de vomir ne la coupe plus
	lr.commandes.vomir_voulu = true
	lb.commandes.vomir_voulu = true
	for i in range(3):
		await process_frame
	lb.commandes.vomir_voulu = false
	for i in range(3):
		await process_frame
	_check(lr.est_local() and not lb.est_local() and lr.est_en_train_de_vomir and not lb.est_en_train_de_vomir and audio._vomi.playing,
		"un autre lion qui arrête de vomir ne coupe pas la boucle du vomi du lion de ce poste")
	lr.commandes.vomir_voulu = false
	for i in range(3):
		await process_frame
	_check(not audio._vomi.playing, "le lion de ce poste qui arrête de vomir coupe sa boucle")

	# Étourdissement par un ennemi : immobile, repoussé, étoiles, sans barbouillage
	var materiau_bleu := lb.sprite.material as ShaderMaterial
	lb.commandes.direction_voulue = Vector2.LEFT
	await _frames(5)
	_check(lb.deplacement.vitesse.x < 0.0, "(pré-condition) le lion bleu avance selon ses commandes")
	materiau_bleu.set_shader_parameter("barbouillage_force", 0.5)  # pour un check discriminant : un ennemi doit bien la remettre à 0
	var etourdis_avant := _sons.count("etourdi")
	GS.regles.lion_touche_par_ennemi(j_bleu, lb.global_position + lb.CENTRE + Vector2(-80, 0))
	_check(_sons.count("etourdi") == etourdis_avant + 1, "un étourdissement joue son son (phase 17 bis)")
```

(`audio` est la variable de la section « musique » du début de `_run`, `root.get_node("Audio")` : la même fonction.)

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	lr.global_position = Vector2(600, 300)
	lb.global_position = Vector2(800, 300)
	await _frames(2)
	lr.commandes.direction_voulue = Vector2.RIGHT
	for i in range(90):
		await _frames(1)
		if j_rouge.chocs > 0:
			break
```

par :

```gdscript
	lr.global_position = Vector2(600, 300)
	lb.global_position = Vector2(800, 300)
	await _frames(2)
	var boings_avant := _sons.count("boing")
	lr.commandes.direction_voulue = Vector2.RIGHT
	for i in range(90):
		await _frames(1)
		if j_rouge.chocs > 0:
			break
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	lr.commandes.direction_voulue = Vector2.ZERO
	_check(j_rouge.chocs == 1 and j_bleu.chocs == 1, "un choc est compté une fois, pour les deux lions")
```

par :

```gdscript
	lr.commandes.direction_voulue = Vector2.ZERO
	_check(j_rouge.chocs == 1 and j_bleu.chocs == 1, "un choc est compté une fois, pour les deux lions")
	_check(_sons.count("boing") == boings_avant + 1, "un choc fait « boing », une fois pour les deux lions (%d)" % (_sons.count("boing") - boings_avant))
```

- [ ] **Step 2 : ils échouent**

Run : la commande des Global Constraints avec `T=tests/smoke_test.gd; O=""`, mais sous `timeout -k 5 120` (une erreur de script y bloque la coroutine jusqu'au délai).
Expected : `❌ Boss : son Synchro réplique [".:position", ".:cote", ".:etat"] à l'apparition`, `❌ sur un client, l'annonce du peintre reçue de l'hôte joue son son, une fois, sans lancer de tween`, puis une `SCRIPT ERROR` sur `est_local` (fonction absente) et le processus tué par le délai (`code 124`), sans ligne `== n échec(s) ==`.

- [ ] **Step 3 : les sons**

Dans `tools/generer_sons.py`, remplacer :

```python
"""Synthétise les effets sonores du jeu dans Assets/Sons (WAV 44,1 kHz mono 16 bits).

Usage : python3 tools/generer_sons.py   (depuis la racine du projet)
"""
import math
import random
import struct
import wave
```

par :

```python
"""Synthétise les effets sonores du jeu dans Assets/Sons (WAV 44,1 kHz mono 16 bits).

Usage : python3 tools/generer_sons.py [nom…]   (depuis la racine du projet)
Sans nom, tous les effets ; avec des noms, ceux-là seulement (ex. : boing tic fin etourdi). Le bruit
de « mort » n'est pas semé : le regénérer change son fichier.
"""
import math
import random
import struct
import sys
import wave
```

Dans `tools/generer_sons.py`, remplacer :

```python
if __name__ == "__main__":
    pickup()
    vomi()
    mort()
    victoire()
    boss()
    pret()
```

par :

```python
def boing():
    """« Boing » des auto-tamponneuses : une note qui plonge vers le grave en vibrant, comme un ressort."""
    dur, out, ph = 0.35, [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        f = 420 * math.exp(-5 * t) + 110 + 25 * math.sin(2 * math.pi * 22 * t) * math.exp(-6 * t)
        ph += 2 * math.pi * f / SR
        x = math.sin(ph) + 0.3 * math.sin(2 * ph)
        out.append(x * env(t, dur, r=0.12) * math.exp(-3 * t))
    ecrire("boing", out)


def tic():
    """Tic du chrono dans les dix dernières secondes : un clic sec et bref."""
    dur, out = 0.06, []
    for i in range(int(SR * dur)):
        t = i / SR
        x = math.sin(2 * math.pi * 1800 * t) * 0.8 + math.sin(2 * math.pi * 3600 * t) * 0.2
        out.append(x * math.exp(-70 * t))
    ecrire("tic", out, gain=0.6)


def fin():
    """Gong de fin de manche : des partiels inharmoniques qui s'éteignent lentement."""
    dur, out = 1.6, []
    partiels = [(196.0, 1.0), (293.7, 0.6), (392.0, 0.5), (523.3, 0.3), (659.3, 0.2)]
    for i in range(int(SR * dur)):
        t = i / SR
        x = sum(a * math.sin(2 * math.pi * f * t) * math.exp(-(1.5 + k) * t) for k, (f, a) in enumerate(partiels))
        out.append(x * env(t, dur, a=0.003, r=0.3))
    ecrire("fin", out)


def etourdi():
    """Étourdissement : trois tintements qui descendent, les étoiles qui tournent."""
    out = []
    for f in [1320.0, 990.0, 740.0]:
        d = 0.11
        for i in range(int(SR * d)):
            t = i / SR
            out.append((math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2.76 * t)) * math.exp(-18 * t))
    ecrire("etourdi", out, gain=0.6)


EFFETS = {
    "pickup": pickup,
    "vomi": vomi,
    "mort": mort,
    "victoire": victoire,
    "boss": boss,
    "pret": pret,
    "boing": boing,
    "tic": tic,
    "fin": fin,
    "etourdi": etourdi,
}


if __name__ == "__main__":
    for nom in sys.argv[1:] or list(EFFETS):
        EFFETS[nom]()
```

Run : `python3 tools/generer_sons.py boing tic fin etourdi && git status --short Assets/Sons`
Expected (mesuré, Python 3.14) : `boing.wav  0.35 s`, `tic.wav  0.06 s`, `fin.wav  1.60 s`, `etourdi.wav  0.33 s`, et **seulement** ces quatre fichiers neufs (aucun son existant modifié). Sans hasard, deux passages donnent les mêmes octets (mesuré : `md5 -q Assets/Sons/boing.wav` = `5c778d5edbb3ce409601791488ecd347`, `fin.wav` = `aead5ad5c28af7507209c7bb1a2c0b6f` ; une autre version de Python peut différer d'un bit d'arrondi, sans importance). Écouter les quatre (`afplay Assets/Sons/boing.wav`…) : un ressort, un clic, un gong, trois tintements.

Puis, **avant** de toucher à `Audio.gd` : `godot --headless --import . 2>&1 | grep -cE "SCRIPT ERROR|Parse Error"` donne `0` (il crée les `.import` des quatre sons). Dans l'autre ordre, la première passe d'import compile les `preload` du Step 4 avant d'avoir importé les sons et sort quatre `SCRIPT ERROR: Parse Error: Preload file "res://Assets/Sons/boing.wav" has no resource loaders` (vu en préparant le plan ; une seconde passe est propre).

- [ ] **Step 4 : Audio, le lion, le pare-chocs, le peintre**

Dans `Scripts/Audio.gd`, remplacer :

```gdscript
const DB_VOMI := -8.0
const DB_MUSIQUE := -12.0
```

par :

```gdscript
const DB_VOMI := -8.0
## Un choc ou un étourdissement entre d'autres lions que celui de ce poste : plus discret que les siens.
const DB_AUTRES := -9.0
const DB_MUSIQUE := -12.0
```

Dans `Scripts/Audio.gd`, remplacer :

```gdscript
	"pret": preload("res://Assets/Sons/pret.wav"),
}
```

par :

```gdscript
	"pret": preload("res://Assets/Sons/pret.wav"),
	"boing": preload("res://Assets/Sons/boing.wav"),
	"tic": preload("res://Assets/Sons/tic.wav"),
	"fin": preload("res://Assets/Sons/fin.wav"),
	"etourdi": preload("res://Assets/Sons/etourdi.wav"),
}
```

Dans `Scripts/Audio.gd`, remplacer :

```gdscript
var _ramassage_joue_a := -1
```

par :

```gdscript
var _ramassage_joue_a := -1
## Par son (« boing », « etourdi »), la frame où il a été joué pour la dernière fois : les deux lions
## d'un choc le signalent chacun, un seul « boing » part.
var _joues_a: Dictionary[String, int] = {}
```

Dans `Scripts/Audio.gd`, remplacer :

```gdscript
func jouer(nom: String) -> void:
	var lecteur := AudioStreamPlayer.new()
	lecteur.stream = SONS[nom]
	lecteur.volume_db = Parametres.en_db(Parametres.effets)
	lecteur.finished.connect(lecteur.queue_free)
	add_child(lecteur)
	lecteur.play()


func demarrer_vomi() -> void:
```

par :

```gdscript
## Joue l'effet `nom`, `db` décibels au-dessus (ou au-dessous) du volume des effets.
func jouer(nom: String, db := 0.0) -> void:
	var lecteur := AudioStreamPlayer.new()
	lecteur.stream = SONS[nom]
	lecteur.volume_db = Parametres.en_db(Parametres.effets) + db
	lecteur.finished.connect(lecteur.queue_free)
	add_child(lecteur)
	lecteur.play()


## Le « boing » d'un choc entre deux lions (`PareChocs`), sur chaque poste : plus fort si le lion de
## ce poste est l'un des deux (`concerne_ce_poste`). Un par frame au plus : les deux lions d'un choc le
## signalent chacun.
func jouer_boing(concerne_ce_poste: bool) -> void:
	_jouer_une_fois_par_frame("boing", 0.0 if concerne_ce_poste else DB_AUTRES)


## Un lion vient d'être étourdi (`Lion`) : plus fort si c'est celui de ce poste. Un par frame au plus.
func jouer_etourdi(ce_poste: bool) -> void:
	_jouer_une_fois_par_frame("etourdi", 0.0 if ce_poste else DB_AUTRES)


func _jouer_une_fois_par_frame(nom: String, db: float) -> void:
	if _joues_a.get(nom, -1) == Engine.get_process_frames():
		return
	_joues_a[nom] = Engine.get_process_frames()
	jouer(nom, db)


## La boucle du vomi du lion de ce poste (les autres lions n'en jouent pas : `Lion`).
func demarrer_vomi() -> void:
```

Dans `Scripts/Audio.gd`, remplacer :

```gdscript
func _on_partie_terminee(victoire: bool) -> void:
	arreter_vomi()
	jouer("victoire" if victoire else "mort")
```

par :

```gdscript
## Fin du solo : victoire ou défaite ; fin d'une manche de bataille : le gong, sur chaque poste (la
## manche de l'hôte, reçue par chaque client, phase 17), la musique gardée.
func _on_partie_terminee(victoire: bool) -> void:
	arreter_vomi()
	if GameState.regles.compte_le_territoire():
		jouer("fin")
		return
	jouer("victoire" if victoire else "mort")
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
	anim.play("Vomit")
	Audio.demarrer_vomi()


func arreter_vomi() -> void:
	est_en_train_de_vomir = false
	gerbe.arreter()
	anim.play("Idle")
	Audio.arreter_vomi()
```

par :

```gdscript
	anim.play("Vomit")
	if est_local():
		Audio.demarrer_vomi()


## La boucle du vomi (une seule, dans `Audio`) n'est qu'au lion de ce poste : un autre lion qui arrête
## de vomir ne la coupe plus (phase 17 bis).
func arreter_vomi() -> void:
	est_en_train_de_vomir = false
	gerbe.arreter()
	anim.play("Idle")
	if est_local():
		Audio.arreter_vomi()


## Vrai si ce lion est celui du joueur de ce poste (en solo, le seul lion).
func est_local() -> bool:
	return joueur == GameState.joueur_local()
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
	etoiles.visible = true
	_tourner_etoiles()


## Fin de l'étourdissement : barbouillage et étoiles s'en vont, l'immunité clignote.
```

par :

```gdscript
	etoiles.visible = true
	_tourner_etoiles()
	Audio.jouer_etourdi(est_local())


## Fin de l'étourdissement : barbouillage et étoiles s'en vont, l'immunité clignote.
```

Dans `Scripts/PareChocs.gd`, remplacer :

```gdscript
## Seul l'hôte signale un choc aux règles. Sur un client, un lion distant ne fait que secouer son
## sprite au choc (sa position et sa vitesse viennent de l'hôte, interpolées) ; le lion local, prédit
## (phase 16), prend tout de suite son recul et son blocage contre les lions affichés, pour un « boing »
## immédiat : chaque choc simulé part aussi en signal (`choc_simule`), que sa prédiction note pour le
## rejouer tant que l'hôte, qui fait foi, ne l'a pas dans ses états.
```

par :

```gdscript
## Seul l'hôte signale un choc aux règles ; chaque poste joue son « boing » (`Audio.jouer_boing`, un
## par choc). Sur un client, un lion distant ne fait que secouer son sprite au choc (sa position et sa
## vitesse viennent de l'hôte, interpolées) ; le lion local, prédit (phase 16), prend tout de suite son
## recul et son blocage contre les lions affichés, pour un « boing » immédiat : chaque choc simulé part
## aussi en signal (`choc_simule`), que sa prédiction note pour le rejouer tant que l'hôte, qui fait
## foi, ne l'a pas dans ses états.
```

Dans `Scripts/PareChocs.gd`, remplacer :

```gdscript
		deplacement.recul += choc_recul
		_lion.secouer()
```

par :

```gdscript
		deplacement.recul += choc_recul
		_lion.secouer()
		# Sur chaque poste (phase 17 bis) : c'est ce qui le rend immédiat pour le joueur local (spec §4.1).
		Audio.jouer_boing(_lion.est_local() or autre.est_local())
```

Dans `Scripts/Boss.gd`, remplacer :

```gdscript
var etat := Etat.REPOS
```

par :

```gdscript
## Répliqué chez les clients (`Synchro`, à chaque changement) : l'annonce du peintre s'y entend comme
## chez l'hôte (phase 17 bis), qui la joue dans `_changer_etat`.
var etat := Etat.REPOS:
	set(valeur):
		if valeur == etat:
			return
		etat = valeur
		if valeur == Etat.ANNONCE and is_node_ready() and est_replique():
			Audio.jouer("boss")
```

Dans `Scenes/Boss.tscn`, remplacer :

```text
properties/1/path = NodePath(".:cote")
properties/1/spawn = true
properties/1/replication_mode = 2
```

par :

```text
properties/1/path = NodePath(".:cote")
properties/1/spawn = true
properties/1/replication_mode = 2
properties/2/path = NodePath(".:etat")
properties/2/spawn = true
properties/2/replication_mode = 2
```

(À l'apparition, l'état reçu est posé avant `_ready` : `is_node_ready()` est faux, rien ne sonne ; ensuite, chaque changement arrive de façon fiable, `REPLICATION_MODE_ON_CHANGE`.)

- [ ] **Step 5 : les tests passent, la trace ne change pas**

Run : `godot --headless --import . > /dev/null 2>&1` (les `.import` des quatre sons), puis le smoke test, les unitaires, la bataille, le banc, puis la trace.
Expected (mesuré) : `== 0 échec(s) ==` partout (smoke : 384 ✅, dont « un autre lion qui arrête de vomir ne coupe pas la boucle… », « un étourdissement joue son son », « un choc fait « boing », une fois pour les deux lions (1) », « sur un client, l'annonce du peintre… ») ; la trace, celle de la Task 1 (`TRACE bataille 976004010 TRACE solo 185311436 TRACE replique 3757044499`).

- [ ] **Step 6 : Commit**

```bash
git add tools/generer_sons.py Assets/Sons/boing.wav Assets/Sons/boing.wav.import Assets/Sons/tic.wav Assets/Sons/tic.wav.import \
	Assets/Sons/fin.wav Assets/Sons/fin.wav.import Assets/Sons/etourdi.wav Assets/Sons/etourdi.wav.import \
	Scripts/Audio.gd Scripts/Lion.gd Scripts/PareChocs.gd Scripts/Boss.gd Scenes/Boss.tscn tests/smoke_test.gd
git commit -m "Sons de bataille (17 bis) : « boing » de chaque choc sur chaque poste (un par choc, plus discret entre deux autres lions), son d'étourdissement, gong de fin de manche, tic du chrono ; l'annonce du peintre s'entend chez les clients (état répliqué) ; la boucle du vomi n'est qu'au lion de ce poste ; generer_sons.py prend des noms

<ligne fournie par l'environnement>"
```

---

### Task 3 : les pseudos au-dessus des lions ne se chevauchent plus et restent dans l'écran (`PlacementPseudos`)

**Files:**
- Create: `Scripts/PlacementPseudos.gd` (+ `.uid`)
- Modify: `Scripts/Lion.gd`, `Scripts/Main.gd`
- Test: `tests/unitaires.gd`, `tests/bataille_test.gd`

**Interfaces:**
- Consumes : `Lion.etiquette_pseudo` (le `Label` `Visuel/Pseudo`, 220 px de large, texte centré), `Lion.visuel` (décalage d'affichage de la prédiction, phase 16), `Main.lions`.
- Produces : `class_name PlacementPseudos` : `const ECART := 6.0` ; `static func repartir(textes: Array[Rect2], largeur: float) -> Array[float]` (le bord gauche de chaque texte, dans l'ordre reçu) ; `func Lion.rect_pseudo() -> Rect2` (le texte du pseudo à sa place de scène, en pixels de l'écran, suivant `position + visuel.position`) ; `func Lion.placer_pseudo(x_texte: float) -> void` (glisse l'étiquette à l'horizontale seulement) ; `Main._placer_pseudos()` à chaque image dès deux lions.

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_chrono_bataille()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_chrono_bataille()
	_tester_placement_pseudos()
	print("== %d échec(s) ==" % _echecs)
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
## côtés (l'hôte la tient pour établie à l'accusé de réception de sa réponse) ; 1 s au plus.
func _connecter(
```

par :

```gdscript
## Phase 17 : les étiquettes de pseudo de lions qui se touchent s'écartent à l'horizontale, sans
## sortir de l'écran (2000 px).
func _tester_placement_pseudos() -> void:
	print("-- Étiquettes de pseudo (phase 17)")
	var voisins: Array[Rect2] = [Rect2(100, 50, 120, 30), Rect2(180, 50, 120, 30)]
	var xs := PlacementPseudos.repartir(voisins, 2000.0)
	_check(is_equal_approx(xs[0], 77.0) and is_equal_approx(xs[1], 203.0),
		"deux pseudos à la même hauteur qui se recouvrent s'écartent chacun de la moitié de ce qui manque (%s)" % [xs])
	var etages: Array[Rect2] = [Rect2(100, 50, 120, 30), Rect2(150, 90, 120, 30)]
	_check(PlacementPseudos.repartir(etages, 2000.0) == [100.0, 150.0], "deux pseudos l'un au-dessus de l'autre restent où ils sont")
	var bords: Array[Rect2] = [Rect2(-40, 50, 120, 30), Rect2(1950, 400, 120, 30)]
	_check(PlacementPseudos.repartir(bords, 2000.0) == [0.0, 1880.0], "un pseudo qui déborde d'un bord y est ramené")
	var au_bord: Array[Rect2] = [Rect2(-10, 50, 120, 30), Rect2(60, 50, 120, 30)]
	xs = PlacementPseudos.repartir(au_bord, 2000.0)
	_check(xs[0] == 0.0 and is_equal_approx(xs[1], 126.0), "contre le bord, l'autre pseudo prend tout l'écart (%s)" % [xs])
	var tas: Array[Rect2] = []
	for i in range(6):
		tas.append(Rect2(1700 + 3 * i, 50, 260, 30))  # six pseudos de 12 caractères larges, sur le même lion
	xs = PlacementPseudos.repartir(tas, 2000.0)
	var separes := true
	for i in range(6):
		separes = separes and xs[i] >= 0.0 and xs[i] + 260.0 <= 2000.0
		for j in range(6):
			if i != j and xs[i] < xs[j]:
				separes = separes and xs[i] + 260.0 + PlacementPseudos.ECART <= xs[j] + 0.01
	_check(separes, "six pseudos larges en tas contre un bord s'étalent sans se recouvrir, dans l'écran (%s)" % [xs])


## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
## côtés (l'hôte la tient pour établie à l'accusé de réception de sa réponse) ; 1 s au plus.
func _connecter(
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
		GS.joueurs[i].pseudo = "" if i == 3 else "Joueur %d" % (i + 1)
	var main := await _charger_bataille(0)
```

par :

```gdscript
		GS.joueurs[i].pseudo = "" if i == 3 else "Joueur %d" % (i + 1)
	GS.joueurs[2].pseudo = "WWWWWWWWWWWW"  # 12 caractères larges (Reseau.PSEUDO_MAX), plus large que son lion
	var main := await _charger_bataille(0)
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	_check(j1.chocs == 2 and j2.chocs == 2, "deux chocs à une demi-seconde de jeu d'écart comptent tous les deux (%d, %d)" % [j1.chocs, j2.chocs])
	await _liberer(main)
```

par :

```gdscript
	_check(j1.chocs == 2 and j2.chocs == 2, "deux chocs à une demi-seconde de jeu d'écart comptent tous les deux (%d, %d)" % [j1.chocs, j2.chocs])

	# Phase 17 : deux lions côte à côte (sans se toucher) contre chaque bord, dont un pseudo large : leurs
	# pseudos s'écartent sans se recouvrir, dans l'écran
	for bord in ["gauche", "droit"]:
		for l: CharacterBody2D in [l1, l2]:
			l.deplacement.recul = Vector2.ZERO
			l.deplacement.vitesse = Vector2.ZERO
		var x1 := 0.0 if bord == "gauche" else TAILLE_BATAILLE.x - 236.0
		l1.global_position = Vector2(x1, 400)
		l2.global_position = Vector2(x1 + 100.0, 400)
		await _frames(2)
		var a := _texte_pseudo(l1)
		var b := _texte_pseudo(l2)
		_check(a.position.x >= -0.5 and b.end.x <= TAILLE_BATAILLE.x + 0.5 and a.end.x + 5.5 <= b.position.x,
			"bord %s : deux pseudos voisins s'écartent sans se recouvrir, dans l'écran (%.0f à %.0f, puis %.0f à %.0f)"
				% [bord, a.position.x, a.end.x, b.position.x, b.end.x])
	# Le pseudo suit le lion affiché (le décalage de la prédiction d'un client), pas son seul corps
	var avant: Rect2 = l1.rect_pseudo()
	l1.visuel.position = Vector2(40, -10)
	var decale: Rect2 = l1.rect_pseudo()
	l1.visuel.position = Vector2.ZERO
	_check(decale.position - avant.position == Vector2(40, -10), "le pseudo suit la position affichée du lion (corps et décalage d'affichage)")
	await _liberer(main)
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
## Avec le rendu et `--captures=<dossier>` seulement : en headless, le viewport n'a pas d'image.
```

par :

```gdscript
## Le texte du pseudo d'un lion tel qu'il s'affiche, en pixels de l'écran : l'étiquette est plus large
## que son texte, centré.
func _texte_pseudo(lion: Node2D) -> Rect2:
	var etiquette: Label = lion.etiquette_pseudo
	var boite := etiquette.get_global_rect()
	var texte := etiquette.get_minimum_size().x
	return Rect2(boite.position.x + (boite.size.x - texte) / 2.0, boite.position.y, texte, boite.size.y)


## Avec le rendu et `--captures=<dossier>` seulement : en headless, le viewport n'a pas d'image.
```

(Les deux lions sont à 100 px l'un de l'autre : leurs pare-chocs, 2 × 45 px, ne se touchent pas, aucun choc ne s'ajoute aux deux que compte la vérification d'avant. Les deux pseudos, « Joueur 2 » et « WWWWWWWWWWWW » (mesurés 105 et 295 px), se recouvriraient.)

- [ ] **Step 2 : ils échouent**

Run : les unitaires, puis `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected : les unitaires ne compilent pas (`PlacementPseudos` inconnu : `Parse Error`, aucune ligne `== n échec(s) ==`) ; la bataille (mesuré) : `❌ bord gauche : deux pseudos voisins s'écartent sans se recouvrir, dans l'écran (16 à 120, puis 20 à 316)`, `❌ bord droit : … (1780 à 1884, puis 1784 à 2080)`, puis `SCRIPT ERROR: Invalid call. Nonexistent function 'rect_pseudo'` : la section s'interrompt sans libérer sa scène, et les sections suivantes échouent en cascade (`❌ la passe atteint x = 1700 sans être bloquée`…), `code 1`.

- [ ] **Step 3 : le placement**

Créer `Scripts/PlacementPseudos.gd` :

```gdscript
class_name PlacementPseudos
extends RefCounted
## Les étiquettes de pseudo des lions d'une bataille (phase 17) : deux lions qui se touchent ne
## doivent pas mêler leurs pseudos (« Joueur 3Joueur 4 »), ni un lion collé à un bord faire sortir le
## sien de l'écran. Les étiquettes glissent à l'horizontale seulement : leur hauteur, que le lion garde
## libre au-dessus de lui (`Lion._marge_haute`), ne change jamais. Logique pure, que les tests
## unitaires nomment ; la scène de jeu l'applique à chaque image (`Main._placer_pseudos`).

## Écart gardé entre deux textes voisins, en pixels de l'écran.
const ECART := 6.0


## Les textes `textes` (un rectangle par lion, en pixels de l'écran) écartés à l'horizontale pour ne
## pas se recouvrir et gardés dans l'écran, large de `largeur`. Les textes qui se recouvrent en hauteur
## (de proche en proche) forment une rangée ; dans une rangée, des textes qui se recouvrent se serrent
## en un bloc, dans leur ordre, centré sur la moyenne de leurs places voulues (deux textes s'écartent
## chacun de la moitié de ce qui manque) et ramené dans l'écran (contre un bord, l'autre prend tout
## l'écart). Renvoie le bord gauche de chaque texte, dans l'ordre reçu. Des textes plus larges, à eux
## tous, que l'écran débordent encore à droite (six pseudos de 12 caractères larges tiennent).
static func repartir(textes: Array[Rect2], largeur: float) -> Array[float]:
	var xs: Array[float] = []
	xs.resize(textes.size())
	for rangee in _rangees(textes):
		rangee.sort_custom(func(a: int, b: int) -> bool:
			return textes[a].position.x < textes[b].position.x or (textes[a].position.x == textes[b].position.x and a < b))
		# Blocs de textes serrés, de gauche à droite : {"debut", "fin" (dans `rangee`), "x", "largeur",
		# "somme" (des places voulues du bloc, chacune rapportée à son bord gauche)}
		var blocs: Array[Dictionary] = []
		for k in range(rangee.size()):
			var t: Rect2 = textes[rangee[k]]
			var bloc := {"debut": k, "fin": k, "largeur": t.size.x, "somme": t.position.x, "n": 1}
			bloc.x = _dans_l_ecran(t.position.x, t.size.x, largeur)
			while not blocs.is_empty() and blocs[-1].x + blocs[-1].largeur + ECART > bloc.x:
				var avant: Dictionary = blocs.pop_back()
				var decalage: float = avant.largeur + ECART
				var somme: float = avant.somme + bloc.somme - bloc.n * decalage
				var n: int = avant.n + bloc.n
				bloc = {"debut": avant.debut, "fin": bloc.fin, "largeur": decalage + bloc.largeur, "somme": somme, "n": n}
				bloc.x = _dans_l_ecran(somme / n, bloc.largeur, largeur)
			blocs.append(bloc)
		for bloc in blocs:
			var x: float = bloc.x
			for k in range(bloc.debut, bloc.fin + 1):
				xs[rangee[k]] = x
				x += textes[rangee[k]].size.x + ECART
	return xs


## Les rangées : les index des textes qui se recouvrent en hauteur, de proche en proche.
static func _rangees(textes: Array[Rect2]) -> Array[Array]:
	var rangee_de: Array[int] = []
	for i in range(textes.size()):
		rangee_de.append(i)
	for i in range(textes.size()):
		for j in range(i + 1, textes.size()):
			if absf(textes[i].position.y - textes[j].position.y) < minf(textes[i].size.y, textes[j].size.y):
				var vieille := rangee_de[j]
				for k in range(textes.size()):
					if rangee_de[k] == vieille:
						rangee_de[k] = rangee_de[i]
	var rangees: Dictionary[int, Array] = {}
	for i in range(textes.size()):
		if not rangees.has(rangee_de[i]):
			rangees[rangee_de[i]] = []
		rangees[rangee_de[i]].append(i)
	var resultat: Array[Array] = []
	resultat.assign(rangees.values())
	return resultat


static func _dans_l_ecran(x: float, w: float, largeur: float) -> float:
	return clampf(x, 0.0, maxf(largeur - w, 0.0))
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_replique = not multiplayer.is_server()
```

par :

```gdscript
var _rng := RandomNumberGenerator.new()
## Abscisse de l'étiquette du pseudo posée par la scène (centrée sur la tête), d'où `rect_pseudo` part.
var _x_pseudo := 0.0


func _ready() -> void:
	_rng.randomize()
	_x_pseudo = etiquette_pseudo.position.x
	_replique = not multiplayer.is_server()
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
## Hauteur gardée libre au-dessus du lion : celle de son pseudo quand il s'affiche (bataille),
## pour qu'un lion collé en haut de l'écran ne le cache pas ; aucune en solo.
func _marge_haute() -> float:
	return -etiquette_pseudo.position.y if etiquette_pseudo.visible else 0.0
```

par :

```gdscript
## Hauteur gardée libre au-dessus du lion : celle de son pseudo quand il s'affiche (bataille),
## pour qu'un lion collé en haut de l'écran ne le cache pas ; aucune en solo. L'étiquette ne glisse
## qu'à l'horizontale (`placer_pseudo`) : cette hauteur ne change jamais.
func _marge_haute() -> float:
	return -etiquette_pseudo.position.y if etiquette_pseudo.visible else 0.0


## Le texte du pseudo, en pixels de l'écran, là où la scène le pose (centré au-dessus de la tête) :
## il suit la position affichée du lion (`position` et le décalage de la prédiction, `visuel`), pas
## son seul corps.
func rect_pseudo() -> Rect2:
	var texte := etiquette_pseudo.get_minimum_size().x
	var coin := global_position + visuel.position + Vector2(_x_pseudo + (etiquette_pseudo.size.x - texte) / 2.0, etiquette_pseudo.position.y)
	return Rect2(coin, Vector2(texte, etiquette_pseudo.size.y))


## Pose le texte du pseudo à l'abscisse `x_texte` de l'écran (son bord gauche ; `PlacementPseudos`) :
## l'étiquette glisse à l'horizontale, jamais en hauteur.
func placer_pseudo(x_texte: float) -> void:
	var texte := etiquette_pseudo.get_minimum_size().x
	etiquette_pseudo.position.x = x_texte - (etiquette_pseudo.size.x - texte) / 2.0 - global_position.x - visuel.position.x
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
func _process(delta: float) -> void:
	if GameState.demo and GameState.partie_en_cours:
```

par :

```gdscript
func _process(delta: float) -> void:
	if lions.size() > 1:
		_placer_pseudos()
	if GameState.demo and GameState.partie_en_cours:
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
## La musique gagne une couche par tiers du chemin vers la victoire.
```

par :

```gdscript
## Les pseudos des lions d'une bataille, écartés s'ils se recouvrent et gardés dans l'écran
## (`PlacementPseudos`), là où chaque lion est affiché.
func _placer_pseudos() -> void:
	var visibles: Array[Lion] = []
	var textes: Array[Rect2] = []
	for l in lions:
		if l.etiquette_pseudo.visible:
			visibles.append(l)
			textes.append(l.rect_pseudo())
	var xs := PlacementPseudos.repartir(textes, get_viewport_rect().size.x)
	for i in range(visibles.size()):
		visibles[i].placer_pseudo(xs[i])


## La musique gagne une couche par tiers du chemin vers la victoire.
```

(Le solo n'a qu'un lion : rien n'y change. Chaque image repart des places de la scène, `rect_pseudo`, jamais des places de l'image d'avant : aucun effet cumulé. Deux lions qui se croisent échangent l'ordre de leurs pseudos d'un coup, sans conséquence.)

- [ ] **Step 4 : les tests passent, la trace ne change pas**

Run : `godot --headless --import . > /dev/null 2>&1` (la classe `PlacementPseudos`), puis les unitaires, la bataille, le smoke test, le banc, puis la trace.
Expected (mesuré) : `== 0 échec(s) ==` partout (unitaires : 380 ✅ ; bataille : 71 ✅, dont « bord gauche : … (0 à 105, puis 111 à 406) », « bord droit : … (1594 à 1699, puis 1705 à 2000) », « le pseudo suit la position affichée du lion ») ; la trace, celle de la Task 1 (elle compte la visibilité et le texte de chaque étiquette, pas sa place ; `_marge_haute` ne change pas).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/PlacementPseudos.gd Scripts/PlacementPseudos.gd.uid Scripts/Lion.gd Scripts/Main.gd tests/unitaires.gd tests/bataille_test.gd
git commit -m "Pseudos des lions : deux étiquettes qui se recouvrent s'écartent à l'horizontale, en bloc centré sur leurs places, et restent dans l'écran (PlacementPseudos, logique pure) ; elles suivent le lion affiché, décalage de la prédiction compris, et ne changent jamais de hauteur (la borne haute du lion, donc la physique, ne bouge pas)

<ligne fournie par l'environnement>"
```

---

### Task 4 : le HUD de la bataille, la fin au chrono et sa sortie, la musique de la manche (`HUDBataille`, `Main`)

**Files:**
- Create: `Scenes/HUDBataille.tscn`, `Scripts/HUDBataille.gd` (+ `.uid`)
- Modify: `Scripts/Main.gd`, `Assets/Traductions/traductions.csv` (+ les deux `.translation`, régénérés par l'import)
- Test: `tests/bataille_test.gd`

**Interfaces:**
- Consumes (Tasks 1 à 3) : `ReglesBataille.secondes_restantes()`, `SECONDES_TIC`, `rangs()`, `parts()`, `Regles.intensite_musique()`, `Audio.jouer("tic")`, `EtatPartie.formater_temps`, `Territoire.cellules_de`, `nb_peignables`, `Joueur.bonus_change`, `crans`, `est_etourdi()`, les clés `SALON_TOI` et `QUITTER_PARTIE` des traductions.
- Produces (Tasks 5, 7, 8) : `Main.hud_bataille: CanvasLayer` (null en solo), posé par `Main._installer_hud_bataille()` après `charger_skyline` à la place de `$HUD` ; sur `HUDBataille` : `var ville: Node2D` (avant l'ajout), `vignettes: Array[Dictionary]` (`cadre`, `style`, `lion`, `teinte`, `pseudo`, `badge`, `couronne` (enfant du `lion`), `part`, `rang`, `etat`, `points`), `xxl_restant: Array[float]`, `partis: Array[bool]`, `tics_joues: int`, `gauche`, `droite`, `chrono`, `fin`, `gagnant` ; `func marquer_parti(index: int) -> void`, `func rafraichir() -> void`, `func resume() -> String` (« chrono|pseudo:part:rang[:parti]|… »), `func texte_gagnant(meneurs: PackedStringArray) -> String`, `func quitter() -> void`, `static func nom_affiche(joueur: Joueur) -> String`. À la fin d'une bataille, `Main` ferme et désactive le menu local.

- [ ] **Step 1 : les tests**

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	await _tester_manche()
	await _tester_retour_au_titre()
```

par :

```gdscript
	await _tester_manche()
	await _tester_hud()
	await _tester_retour_au_titre()
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
		pire_frame_ms = maxf(pire_frame_ms, (maintenant - instant) / 1000.0)
		instant = maintenant
	GS.terminer_partie(true)
```

par :

```gdscript
		pire_frame_ms = maxf(pire_frame_ms, (maintenant - instant) / 1000.0)
		instant = maintenant
	for f in range(5):  # les 90 s de la boucle, comptées d'une image physique : le chrono finit à une image près
		if not GS.partie_en_cours:
			break
		await physics_frame
	_check(not GS.partie_en_cours and GS.temps_ecoule >= ReglesBataille.DUREE_MANCHE and GS.temps_ecoule < ReglesBataille.DUREE_MANCHE + 0.05,
		"le chrono termine la manche à %d s (%.3f s de jeu)" % [int(ReglesBataille.DUREE_MANCHE), GS.temps_ecoule])
	GS.terminer_partie(true)  # sans effet : la manche est déjà finie
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
func _tester_retour_au_titre() -> void:
```

par :

```gdscript
## Phase 17 : le HUD de la bataille, à la place de celui du solo (vignettes, scores lus sur le
## territoire, crans, gerbe XXL, étourdissement, départ), le chrono qui rougit et tique, la fin au
## chrono et sa sortie (Échap : le titre).
func _tester_hud() -> void:
	print("-- HUD de la bataille")
	var main := await _charger_bataille(0)
	var hud: CanvasLayer = main.hud_bataille
	var ville: Node2D = main.get_node("Ville")
	var t: Territoire = ville.territoire
	_check(hud != null and main.get_node_or_null("HUD") == null and hud.vignettes.size() == NB_LIONS
		and hud.gauche.get_child_count() == NB_LIONS / 2 and hud.droite.get_child_count() == NB_LIONS / 2,
		"en bataille, le HUD de la bataille remplace celui du solo : une vignette par joueur, moitié de chaque côté du chrono")
	_check(range(NB_LIONS).all(func(i: int) -> bool: return hud.vignettes[i].pseudo.text == "Joueur %d" % (i + 1)),
		"sans pseudo (bataille locale), chaque vignette porte « Joueur n »")
	var pseudo: Label = hud.vignettes[0].pseudo
	var largeur_w: float = pseudo.get_theme_font("font").get_string_size("WWWWWWWWWWWW", HORIZONTAL_ALIGNMENT_LEFT, -1,
		pseudo.get_theme_font_size("font_size")).x + 2 * pseudo.get_theme_constant("outline_size")
	var rangee_a_6: float = 6 * hud.vignettes[0].cadre.size.x + hud.chrono.size.x + 7 * hud.get_node("Haut").get_theme_constant("separation") + 24.0
	_check(largeur_w <= pseudo.size.x and rangee_a_6 <= TAILLE_BATAILLE.x,
		"12 caractères larges (« WWWWWWWWWWWW », %d px) tiennent dans une vignette (%d px) ; six vignettes et le chrono dans l'écran (%d px)"
			% [largeur_w, pseudo.size.x, rangee_a_6])
	_check(hud.vignettes[0].badge.text == "TOI" and hud.vignettes[0].style.border_width_top == 6
		and range(1, NB_LIONS).all(func(i: int) -> bool: return hud.vignettes[i].badge.text == "" and hud.vignettes[i].style.border_width_top == 3),
		"la vignette du joueur de ce poste est mise en évidence : « TOI », bordure épaisse")
	_check(hud.chrono.text == "1:30" and not hud.vignettes.any(func(v: Dictionary) -> bool: return v.couronne.visible or v.rang.text != ""),
		"au départ : 1:30, personne n'est classé ni couronné")
	await _attendre_depart()
	var bas: float = ville.position.y + ville.tex_size.y / 2.0 - 30.0
	for k in range(3):
		ville.peindre(Vector2(500, bas), 30, GS.joueurs[1])
	await _frames(1)
	var n1 := t.cellules_de(1)
	_check(n1 > 0 and hud.vignettes[1].part.text == "100 %" and hud.vignettes[0].part.text == "0 %" and hud.vignettes[1].rang.text == "1er"
		and hud.vignettes[1].couronne.visible and not hud.vignettes[0].couronne.visible and hud.vignettes[0].rang.text == "",
		"le HUD lit les scores sur le territoire de la ville : le joueur 2, seul peintre, a 100 %% des cellules peintes (%d), il mène, couronné" % n1)
	_check(hud.vignettes[1].couronne.get_parent() == hud.vignettes[1].lion and hud.vignettes[1].couronne.rotation > 0.2,
		"la couronne est posée de travers sur la tête du lion de la vignette")
	for k in range(3):
		ville.peindre(Vector2(1500, bas), 20, GS.joueurs[3])  # moins de cellules : le joueur 2 mène encore
	await _frames(1)
	var affichees: Array = hud.vignettes.map(func(v: Dictionary) -> int: return int(v.part.text.trim_suffix(" %")))
	var cellules: Array[int] = []
	for i in range(NB_LIONS):
		cellules.append(t.cellules_de(i))
	_check(affichees == ReglesBataille.parts(cellules) and affichees.reduce(func(s: int, n: int) -> int: return s + n, 0) == 100,
		"deux peintres : leurs parts des cellules peintes font 100 %% (%s pour %s cellules)" % [affichees, cellules])
	_check(hud.vignettes[1].couronne.visible and not hud.vignettes[3].couronne.visible and hud.vignettes[3].rang.text == "2e",
		"le rang et la couronne viennent des cellules : le joueur 2 mène, le joueur 4 est deuxième")
	GS.regles.pastille_ramassee(GS.joueurs[1], 0)
	GS.regles.pastille_ramassee(GS.joueurs[1], 0)
	GS.regles.etoile_ramassee(GS.joueurs[2])
	GS.regles.lion_touche_par_ennemi(GS.joueurs[3], Vector2.INF)
	await _frames(1)
	var pleins: Array = hud.vignettes[1].points.filter(func(p: Panel) -> bool: return p.modulate == Color.WHITE)
	_check(pleins.size() == 3, "trois crans : trois points pleins sur sept")
	_check(hud.vignettes[2].etat.text == "★ XXL 8 s" and hud.vignettes[3].etat.text == "★ ÉTOURDI",
		"la gerbe XXL et ses secondes, l'étourdissement (%s, %s)" % [hud.vignettes[2].etat.text, hud.vignettes[3].etat.text])
	# Comme sur un client : `bonus_restant` y reste la durée reçue (seule la fin arrive de l'hôte)
	for f in range(61):
		GS.joueurs[2].bonus_restant = 8.0
		await physics_frame
	_check(hud.vignettes[2].etat.text == "★ XXL 7 s", "le HUD décompte lui-même les secondes de la gerbe XXL (%s)" % hud.vignettes[2].etat.text)
	GS.joueurs[2].recevoir_fin_bonus()
	hud.marquer_parti(3)
	await _frames(1)
	_check(hud.vignettes[2].etat.text == "", "la fin de la gerbe XXL efface ses secondes")
	_check(hud.vignettes[3].cadre.modulate.a < 0.5 and hud.vignettes[3].badge.text == "PARTI", "un joueur parti reste au classement, en grisé")
	_check(hud.texte_gagnant(PackedStringArray()) == "Personne n'a peint la ville." and hud.texte_gagnant(PackedStringArray(["Zoé"])) == "Zoé gagne la manche !"
		and hud.texte_gagnant(PackedStringArray(["Anna", "Bruno"])) == "Égalité : Anna, Bruno !",
		"le panneau de fin nomme le gagnant, les ex æquo, ou personne")
	# Les dix dernières secondes : le chrono rougit et tique, jusqu'à la fin au chrono
	GS.temps_ecoule = ReglesBataille.DUREE_MANCHE - 10.5
	await _frames(1)
	var tics_avant: int = hud.tics_joues
	_check(hud.chrono.text == "0:11" and hud.chrono.modulate == Color.WHITE and root.get_node("Audio").intensite == 2,
		"à 11 s de la fin, le chrono est encore blanc ; la musique a toutes ses couches depuis 60 s")
	for f in range(900):
		if not GS.partie_en_cours:
			break
		await physics_frame
	_check(not GS.partie_en_cours and paused and GS.temps_ecoule < ReglesBataille.DUREE_MANCHE + 0.05,
		"le chrono à zéro termine la manche et fige tout (%.3f s)" % GS.temps_ecoule)
	_check(hud.tics_joues - tics_avant == ReglesBataille.SECONDES_TIC and hud.chrono.text == "0:00" and hud.chrono.modulate != Color.WHITE,
		"dix tics dans les dix dernières secondes (%d), le chrono rouge à 0:00" % (hud.tics_joues - tics_avant))
	_check(hud.fin.visible and hud.gagnant.text == "Joueur 2 gagne la manche !" and not main.menu_pause.visible
		and main.menu_pause.process_mode == Node.PROCESS_MODE_DISABLED,
		"le panneau de fin nomme le gagnant (%s) ; le menu local se tait" % hud.gagnant.text)
	# Espace (vomir, valider) encore tenu au gong ne quitte pas la partie : le bouton ne prend pas le focus
	for action: StringName in [&"vomir", &"ui_accept"]:
		var appui := InputEventAction.new()
		appui.action = action
		appui.pressed = true
		root.push_input(appui)
	await _frames(3)
	_check(current_scene == main and hud.fin.visible and root.gui_get_focus_owner() == null,
		"Espace tenu au gong (vomir, valider) ne quitte pas la partie : rien n'a le focus")
	var scores: Node = root.get_node("Scores")
	scores.chemin = "user://scores_test_bataille.cfg"  # l'écran titre enregistre ses préférences
	var echap := InputEventAction.new()
	echap.action = &"pause"
	echap.pressed = true
	root.push_input(echap)
	for f in range(300):
		if current_scene != null and current_scene.scene_file_path == "res://Scenes/Titre.tscn" and current_scene.is_node_ready():
			break
		await process_frame
	_check(current_scene != null and current_scene.scene_file_path == "res://Scenes/Titre.tscn" and not paused and GS.regles is ReglesSolo,
		"Échap, la manche finie : retour au titre (le solo), en attendant les résultats de la phase 18")
	current_scene.free()
	await _frames(1)
	scores.effacer()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))
	GS.configurer_bataille(NB_LIONS)  # la section suivante part d'une bataille


func _tester_retour_au_titre() -> void:
```

- [ ] **Step 2 : ils échouent**

Run : `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected (mesuré) : « le chrono termine la manche à 90 s » passe déjà (✅ : c'est la Task 1), puis `SCRIPT ERROR: Invalid access to property or key 'hud_bataille'` au début de la section « HUD de la bataille », qui s'interrompt sans libérer sa scène : les trois vérifications de « Solo après une bataille » échouent en cascade, `== 3 échec(s) ==`.

- [ ] **Step 3 : les textes**

À la fin de `Assets/Traductions/traductions.csv`, ajouter :

```text
BATAILLE_JOUEUR,Joueur %d,Player %d
BATAILLE_PARTI,PARTI,LEFT
BATAILLE_ETOURDI,★ ÉTOURDI,★ STUNNED
BATAILLE_XXL,★ XXL %d s,★ XXL %d s
BATAILLE_RANG_1,1er,1st
BATAILLE_RANG_2,2e,2nd
BATAILLE_RANG_3,3e,3rd
BATAILLE_RANG_4,4e,4th
BATAILLE_RANG_5,5e,5th
BATAILLE_RANG_6,6e,6th
BATAILLE_FIN,FIN DE LA MANCHE !,TIME'S UP!
BATAILLE_GAGNANT,%s gagne la manche !,%s wins the round!
BATAILLE_EGALITE,Égalité : %s !,Tie: %s!
BATAILLE_PERSONNE,Personne n'a peint la ville.,Nobody painted the town.
BATAILLE_AIDE_FIN,Échap : quitter la partie,Esc: leave the game
```

(Le fichier finit déjà par un saut de ligne, après `QUITTER_PARTIE` : vérifier avec `tail -c 1 Assets/Traductions/traductions.csv | od -c` qu'il n'y a qu'un `\n`, sans quoi la première ligne ajoutée se collerait à la dernière. Aucune valeur ne contient de virgule : pas de guillemets.)

- [ ] **Step 4 : la scène et le script du HUD**

Créer `Scenes/HUDBataille.tscn` :

```text
[gd_scene load_steps=2 format=3 uid="uid://dlelionhudbat0"]

[ext_resource type="Script" path="res://Scripts/HUDBataille.gd" id="1_hud"]

[node name="HUDBataille" type="CanvasLayer"]
process_mode = 3
layer = 5
script = ExtResource("1_hud")

[node name="Haut" type="HBoxContainer" parent="."]
anchors_preset = 10
anchor_right = 1.0
offset_left = 12.0
offset_top = 10.0
offset_right = -12.0
grow_horizontal = 2
mouse_filter = 2
theme_override_constants/separation = 10
alignment = 1

[node name="Gauche" type="HBoxContainer" parent="Haut"]
layout_mode = 2
mouse_filter = 2
theme_override_constants/separation = 10

[node name="Chrono" type="Label" parent="Haut"]
custom_minimum_size = Vector2(230, 0)
layout_mode = 2
size_flags_vertical = 1
auto_translate_mode = 2
theme_override_colors/font_outline_color = Color(0.1, 0.05, 0.15, 1)
theme_override_constants/outline_size = 12
theme_override_font_sizes/font_size = 72
text = "1:30"
horizontal_alignment = 1
vertical_alignment = 1

[node name="Droite" type="HBoxContainer" parent="Haut"]
layout_mode = 2
mouse_filter = 2
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

Créer `Scripts/HUDBataille.gd` :

```gdscript
extends CanvasLayer
## Le HUD de la bataille (spec §8, phase 17), à la place de celui du solo : en haut de l'écran, une
## vignette par joueur, dans l'ordre des index (moitié à gauche du chrono, moitié à droite) : le lion
## teint de sa couleur (la couronne des meneurs posée de travers sur sa crinière, ex æquo compris), son
## pseudo, sa part des cellules peintes (les parts font 100 % à elles toutes), son rang, ses crans en
## points, la gerbe XXL et ses secondes, l'étourdissement ; la vignette de ce
## poste mise en évidence (« TOI », bordure épaisse), celle d'un joueur parti en grisé. Au centre, le
## chrono qui descend, rouge et qui tique dans les dix dernières secondes. La propriété d'une cellule
## ne se lit qu'ici, au pseudo et à la part (jamais à la teinte de la ville : deutéranopie, spec §2).
## Tout se lit sur chaque poste : les scores sur le territoire de la ville (celui de l'hôte, recopié
## chez chaque client toutes les 0,2 s), le chrono sur `GameState.temps_ecoule` (chez un client, parti
## à la fin de sa propre intro), les réactions par les signaux des joueurs (répliqués par la manche) ;
## les secondes de la gerbe XXL se décomptent ici (sur un client, `Joueur.bonus_restant` reste la
## durée reçue au début de la gerbe). À la fin de la manche (`GameState.partie_terminee`, chez un
## client la fin décidée par l'hôte), le panneau de fin : le gagnant, ou les ex æquo, et la sortie
## (Échap, Start ou le bouton : retour au titre, qui quitte le réseau) jusqu'à l'écran Résultats de la
## phase 18. Tourne aussi l'arbre en pause (le panneau de fin et sa sortie) ; le reste ne bouge pas
## pendant une pause.

const SCENE_TITRE := "res://Scenes/Titre.tscn"
const TEXTURE_LION := preload("res://Assets/Sprites/LionHead.png")
const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
## La couronne sur la tête du lion de la vignette (56 px) : sa place, sa taille et son inclinaison (de
## travers, comme posée sur la crinière), en radians.
const PLACE_COURONNE := Vector2(26, 1)
const TAILLE_COURONNE := Vector2(30, 20)
const INCLINAISON_COURONNE := 0.38
## Une vignette : six tiennent avec le chrono dans les 2000 px ; un pseudo de 12 caractères larges
## (« WWWWWWWWWWWW ») y tient à POLICE_PSEUDO px (vérifié par tests/bataille_test.gd).
const TAILLE_VIGNETTE := Vector2(270, 112)
const POLICE_PSEUDO := 20
const COULEUR_CONTOUR := Color(0.1, 0.05, 0.15, 1)
const COULEUR_CHRONO := Color.WHITE
const COULEUR_CHRONO_FIN := Color(1.0, 0.32, 0.25)
const COULEUR_POINT_VIDE := Color(1, 1, 1, 0.22)
const COULEUR_ETOURDI := Color(0.75, 0.85, 1.0)
const OPACITE_PARTI := 0.4

## La ville de la scène de jeu (son territoire tient les scores), donnée par `Main` avant l'ajout.
var ville: Node2D
## Une vignette par joueur, dans l'ordre des index : {"cadre": PanelContainer, "style": StyleBoxFlat,
## "lion": TextureRect, "teinte": ShaderMaterial, "pseudo": Label, "badge": Label, "couronne": Control (sur le lion), "part": Label,
## "rang": Label, "etat": Label, "points": Array[Panel]}.
var vignettes: Array[Dictionary] = []
## Par index de joueur : les secondes de gerbe XXL qui restent, décomptées ici (0 : pas de gerbe).
var xxl_restant: Array[float] = []
## Par index de joueur : vrai une fois parti (`marquer_parti`).
var partis: Array[bool] = []
## Tics joués (dix dernières secondes), lus par les tests.
var tics_joues := 0

@onready var gauche: HBoxContainer = $Haut/Gauche
@onready var droite: HBoxContainer = $Haut/Droite
@onready var chrono: Label = $Haut/Chrono
@onready var fin: CenterContainer = $Fin
@onready var gagnant: Label = $Fin/Panneau/Colonne/Gagnant

var _secondes_vues := -1
## Le style des points de crans, partagé (un point vide n'est qu'estompé : `modulate`, sans changer
## de thème à chaque image).
var _style_point := StyleBoxFlat.new()


func _ready() -> void:
	_style_point.bg_color = Color.WHITE
	_style_point.set_corner_radius_all(6)
	var fond_fin := StyleBoxFlat.new()
	fond_fin.bg_color = Color(0.05, 0.03, 0.1, 0.82)
	fond_fin.set_corner_radius_all(24)
	fond_fin.set_content_margin_all(48)
	$Fin/Panneau.add_theme_stylebox_override("panel", fond_fin)
	var nb := GameState.joueurs.size()
	for i in range(nb):
		var joueur: Joueur = GameState.joueurs[i]
		var vignette := _creer_vignette(joueur)
		(gauche if i < ceili(nb / 2.0) else droite).add_child(vignette.cadre)
		vignettes.append(vignette)
		xxl_restant.append(0.0)
		partis.append(false)
		joueur.bonus_change.connect(_sur_bonus.bind(i))
	GameState.partie_terminee.connect(_sur_fin)
	_secondes_vues = _secondes()
	rafraichir()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if GameState.partie_en_cours and GameState.pret:
		for i in range(xxl_restant.size()):
			xxl_restant[i] = maxf(xxl_restant[i] - delta, 0.0)
	var secondes := _secondes()
	if secondes < _secondes_vues and secondes >= 1 and secondes <= ReglesBataille.SECONDES_TIC:
		tics_joues += 1
		Audio.jouer("tic")
		chrono.pivot_offset = chrono.size / 2.0
		chrono.scale = Vector2(1.25, 1.25)
		create_tween().tween_property(chrono, "scale", Vector2.ONE, 0.3)
	_secondes_vues = secondes
	rafraichir()


## Échap (ou Start) une fois la manche finie : la sortie (le menu local est désactivé à la fin).
func _unhandled_input(event: InputEvent) -> void:
	if fin.visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		quitter()


## Retour au titre, qui quitte le réseau (en attendant l'écran Résultats de la phase 18).
func quitter() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_TITRE)


## Le joueur d'index `index` a quitté la manche : sa vignette reste, en grisé, avec ses cellules.
func marquer_parti(index: int) -> void:
	if index < 0 or index >= partis.size():
		return
	partis[index] = true
	rafraichir()


## Met chaque vignette et le chrono à jour : parts et rangs lus sur le territoire (les rangs sur les
## cellules, pas sur les parts arrondies), réactions sur les joueurs.
func rafraichir() -> void:
	var cellules := _cellules()
	var rangs := ReglesBataille.rangs(cellules)
	var parts := ReglesBataille.parts(cellules)
	for i in range(vignettes.size()):
		var joueur: Joueur = GameState.joueurs[i]
		var v: Dictionary = vignettes[i]
		v.part.text = "%d %%" % parts[i]
		v.rang.text = tr("BATAILLE_RANG_%d" % rangs[i]) if rangs[i] > 0 else ""
		v.rang.modulate = Styles.JAUNE if rangs[i] == 1 else Color.WHITE
		v.couronne.visible = rangs[i] == 1
		for k in range(v.points.size()):
			(v.points[k] as Panel).modulate = Color.WHITE if k < joueur.crans else COULEUR_POINT_VIDE
		if joueur.est_etourdi():
			v.etat.text = tr("BATAILLE_ETOURDI")
			v.etat.modulate = COULEUR_ETOURDI
		elif xxl_restant[i] > 0.0:
			v.etat.text = tr("BATAILLE_XXL") % ceili(xxl_restant[i])
			v.etat.modulate = Styles.JAUNE
		else:
			v.etat.text = ""
		var badges := PackedStringArray()
		if joueur == GameState.joueur_local():
			badges.append(tr("SALON_TOI"))
		if partis[i]:
			badges.append(tr("BATAILLE_PARTI"))
		v.badge.text = " · ".join(badges)
		v.cadre.modulate.a = OPACITE_PARTI if partis[i] else 1.0
	var secondes := _secondes()
	chrono.text = EtatPartie.formater_temps(secondes)
	chrono.modulate = COULEUR_CHRONO_FIN if secondes <= ReglesBataille.SECONDES_TIC else COULEUR_CHRONO


## Le HUD tel qu'il s'affiche, en une ligne (tests réseau : le même chez l'hôte et chaque client à la
## fin de la manche) : le chrono, puis pour chaque joueur son pseudo, sa part, son rang et s'il est parti.
func resume() -> String:
	var morceaux := PackedStringArray([chrono.text])
	for i in range(vignettes.size()):
		var v: Dictionary = vignettes[i]
		morceaux.append("%s:%s:%s%s" % [v.pseudo.text, v.part.text, v.rang.text, ":parti" if partis[i] else ""])
	return "|".join(morceaux)


## Le nom d'un joueur tel que le HUD l'affiche : son pseudo, ou « Joueur n » sans pseudo (bataille
## locale).
static func nom_affiche(joueur: Joueur) -> String:
	return joueur.pseudo if not joueur.pseudo.is_empty() else TranslationServer.translate("BATAILLE_JOUEUR") % (joueur.index + 1)


## Les cellules de chaque joueur, lues sur le territoire de la ville (aucune sans territoire).
func _cellules() -> Array[int]:
	var cellules: Array[int] = []
	for i in range(vignettes.size()):
		cellules.append(0 if ville == null or ville.territoire == null else ville.territoire.cellules_de(i))
	return cellules


func _secondes() -> int:
	return (GameState.regles as ReglesBataille).secondes_restantes()


func _sur_bonus(actif: bool, index: int) -> void:
	xxl_restant[index] = GameState.joueurs[index].bonus_restant if actif else 0.0


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
	var local := joueur == GameState.joueur_local()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.62 if local else 0.45)
	style.border_color = joueur.couleur
	style.set_border_width_all(6 if local else 3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(11)  # au moins 5 px entre le texte et la bordure épaisse de ce poste
	var cadre := PanelContainer.new()
	cadre.custom_minimum_size = TAILLE_VIGNETTE
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_theme_stylebox_override("panel", style)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 0)
	cadre.add_child(colonne)
	# En haut, sur toute la largeur : le pseudo, dans sa couleur
	var pseudo := _etiquette(POLICE_PSEUDO, joueur.couleur, true)
	pseudo.text = nom_affiche(joueur)
	pseudo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	colonne.add_child(pseudo)
	# Dessous : le lion teint de la couleur du joueur (et la couronne sur sa tête), puis sa part, son
	# état ; son rang, ses crans et le badge
	var rangee := HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 8)
	colonne.add_child(rangee)
	var lion := TextureRect.new()
	lion.texture = TEXTURE_LION
	lion.custom_minimum_size = Vector2(56, 56)
	lion.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lion.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var teinte := ShaderMaterial.new()  # une par vignette : jamais partagée
	teinte.shader = SHADER_TEINTE
	teinte.set_shader_parameter("couleur_joueur", joueur.couleur)
	lion.material = teinte
	rangee.add_child(lion)
	var couronne := Couronne.new()
	couronne.position = PLACE_COURONNE
	couronne.size = TAILLE_COURONNE
	couronne.pivot_offset = TAILLE_COURONNE / 2.0
	couronne.rotation = INCLINAISON_COURONNE
	couronne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lion.add_child(couronne)  # un TextureRect ne range pas ses enfants : la couronne reste où on la pose
	var droite_v := VBoxContainer.new()
	droite_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite_v.add_theme_constant_override("separation", 0)
	rangee.add_child(droite_v)
	var ligne_part := HBoxContainer.new()
	ligne_part.add_theme_constant_override("separation", 8)
	var part := _etiquette(34, Color.WHITE)
	var etat := _etiquette(18, Color.WHITE)  # teinte par `modulate` : jaune (XXL) ou bleutée (étourdi)
	etat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for noeud: Control in [part, etat]:
		ligne_part.add_child(noeud)
	droite_v.add_child(ligne_part)
	var ligne_rang := HBoxContainer.new()
	ligne_rang.add_theme_constant_override("separation", 8)
	var rang := _etiquette(20, Color.WHITE)  # teinte par `modulate` : jaune pour les meneurs
	rang.custom_minimum_size.x = 40
	rang.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var points_ligne := HBoxContainer.new()
	points_ligne.add_theme_constant_override("separation", 4)
	points_ligne.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var points: Array[Panel] = []
	for k in range(Joueur.CRANS_MAX):
		var point := Panel.new()
		point.custom_minimum_size = Vector2(11, 11)
		point.mouse_filter = Control.MOUSE_FILTER_IGNORE
		point.add_theme_stylebox_override("panel", _style_point)
		points_ligne.add_child(point)
		points.append(point)
	var badge := _etiquette(16, Styles.JAUNE)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for noeud: Control in [rang, points_ligne, badge]:
		ligne_rang.add_child(noeud)
	droite_v.add_child(ligne_rang)
	return {"cadre": cadre, "style": style, "lion": lion, "teinte": teinte, "pseudo": pseudo, "badge": badge, "couronne": couronne,
		"part": part, "rang": rang, "etat": etat, "points": points}


## Une étiquette jamais traduite d'elle-même (les textes sont traduits ici, et un pseudo comme
## « PAUSE » n'est pas une clé). `coupee` : coupée au bord de sa vignette, points de suspension
## compris, plutôt que de l'élargir (le pseudo) ; une étiquette coupée n'a plus de largeur minimale,
## elle doit s'étendre : les autres gardent la largeur de leur texte.
func _etiquette(taille: int, couleur: Color, coupee := false) -> Label:
	var etiquette := Label.new()
	etiquette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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


## La couronne des meneurs, dessinée (la police n'a pas de glyphe de couronne) : trois pointes et leurs
## perles, un contour sombre pour se détacher de toutes les crinières (le jaune compris).
class Couronne extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var points := PackedVector2Array([Vector2(1, h - 1), Vector2(1, h * 0.3), Vector2(w * 0.28, h * 0.62),
			Vector2(w * 0.5, 1), Vector2(w * 0.72, h * 0.62), Vector2(w - 1, h * 0.3), Vector2(w - 1, h - 1)])
		draw_colored_polygon(points, Styles.JAUNE)
		points.append(points[0])
		draw_polyline(points, Color(0.1, 0.05, 0.15), 2.0)
		for perle in [Vector2(1, h * 0.3), Vector2(w * 0.5, 1), Vector2(w - 1, h * 0.3)]:
			draw_circle(perle, 2.5, Color.WHITE)
```

Points à ne pas « simplifier » : la couronne est l'enfant du `TextureRect` du lion (qui ne range pas ses enfants), posée de travers sur le haut de sa crinière (`PLACE_COURONNE`, `INCLINAISON_COURONNE` : 0,38 rad, décision de l'utilisateur du 27/09), sans déborder sur le pseudo au-dessus (réglé sur les captures, Task 8) ; la part affichée est `ReglesBataille.parts` (les parts font 100), le rang et la couronne viennent des cellules (`rangs`), jamais des parts arrondies ; une étiquette coupée (`clip_text`) ou à points de suspension n'a plus de largeur minimale : seul le pseudo l'est (il s'étend), sinon la part et le badge disparaissent (vu en préparant le plan) ; les teintes du rang, de l'état, des points et du chrono passent par `modulate`, pas par des surcharges de thème, qui relanceraient la mise en page à chaque image ; le bouton de sortie ne prend jamais le focus (`focus_mode = 0`) ; le HUD est `process_mode = 3` (le panneau de fin et Échap marchent l'arbre en pause) mais ne se met pas à jour pendant une pause, et se rafraîchit une dernière fois à la fin (`_sur_fin`).

- [ ] **Step 5 : la scène de jeu pose le HUD, suit la musique de la manche et garde une sortie**

Dans `Scripts/Main.gd`, remplacer :

```gdscript
const SCENE_LION := preload("res://Scenes/Lion.tscn")
```

par :

```gdscript
const SCENE_LION := preload("res://Scenes/Lion.tscn")
const SCENE_HUD_BATAILLE := preload("res://Scenes/HUDBataille.tscn")
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
## Vrai pour une bataille en réseau (fixé en entrant dans l'arbre).
var en_reseau := false
```

par :

```gdscript
## Vrai pour une bataille en réseau (fixé en entrant dans l'arbre).
var en_reseau := false
## Le HUD d'une bataille (phase 17), à la place de celui du solo ; null en solo.
var hud_bataille: CanvasLayer
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
	_placer_ville()
	_placer_ciel_et_camera()
	if en_reseau:
		_preparer_manche_en_reseau()
		return
```

par :

```gdscript
	_placer_ville()
	_placer_ciel_et_camera()
	if GameState.regles.compte_le_territoire():
		_installer_hud_bataille()
	if en_reseau:
		_preparer_manche_en_reseau()
		return
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
## En réseau : le lion de la scène (celui du solo) s'en va avant tout tick, les lions viendront
```

par :

```gdscript
## Bataille (locale ou en réseau) : le HUD de la bataille remplace celui du solo (cœurs, arc-en-ciel,
## chrono qui monte), une fois la ville chargée (son territoire tient les scores).
func _installer_hud_bataille() -> void:
	var hud_solo: Node = $HUD
	remove_child(hud_solo)
	hud_solo.free()
	hud_bataille = SCENE_HUD_BATAILLE.instantiate()
	hud_bataille.ville = ville
	add_child(hud_bataille)


## En réseau : le lion de la scène (celui du solo) s'en va avant tout tick, les lions viendront
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
	if lions.size() > 1:
		_placer_pseudos()
	if GameState.demo and GameState.partie_en_cours:
```

par :

```gdscript
	if lions.size() > 1:
		_placer_pseudos()
	if hud_bataille != null:
		Audio.definir_intensite(GameState.regles.intensite_musique())  # le temps de la manche
	if GameState.demo and GameState.partie_en_cours:
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
## La musique gagne une couche par tiers du chemin vers la victoire.
func _on_progression_changee(ratio: float) -> void:
	Audio.definir_intensite(int(ratio / GameState.seuil_victoire() * 3.0))
```

par :

```gdscript
## La musique gagne une couche par tiers de l'avancement : en solo, du chemin vers la victoire ; en
## bataille, du temps de la manche (aussi suivi à chaque image, `_process`).
func _on_progression_changee(_ratio: float) -> void:
	Audio.definir_intensite(GameState.regles.intensite_musique())
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
		# Bataille : tout se fige, scores compris. Le bilan du solo ne parle que du joueur local ;
		# les résultats de la bataille, lus sur le territoire, viendront en phase 18.
		get_tree().paused = true
		return
```

par :

```gdscript
		# Bataille : tout se fige, scores compris ; le HUD de la bataille montre la fin et sa sortie
		# (Échap : retour au titre) jusqu'à l'écran Résultats de la phase 18. Le menu local se ferme et
		# se tait : Échap est à la sortie.
		menu_pause.hide()
		menu_pause.process_mode = Node.PROCESS_MODE_DISABLED
		get_tree().paused = true
		return
```

(Le solo garde exactement sa musique : `ReglesSolo.avancement()` vaut `progression / seuil_victoire()`, la formule d'avant. `Scenes/Main.tscn` ne change pas : le HUD du solo y reste, libéré par `_installer_hud_bataille` en bataille, après son propre `_ready` ; ses abonnements aux signaux partent avec lui.)

- [ ] **Step 6 : les tests passent, la trace ne change pas**

Run : `godot --headless --import . > /dev/null 2>&1` (la scène, la classe, les traductions), puis la bataille, le smoke test, les unitaires, le banc, puis la trace.
Expected (mesuré) : `== 0 échec(s) ==` partout (bataille : 93 ✅, dont « le chrono termine la manche à 90 s (90.017 s de jeu) », la section « HUD de la bataille » entière : « 12 caractères larges (« WWWWWWWWWWWW », 239 px) tiennent dans une vignette (248 px) ; six vignettes et le chrono dans l'écran (1944 px) », « le HUD lit les scores sur le territoire de la ville : le joueur 2, seul peintre, a 100 % des cellules peintes (59), il mène, couronné », « la couronne est posée de travers sur la tête du lion de la vignette », « deux peintres : leurs parts des cellules peintes font 100 % ([0, 69, 0, 31] pour [0, 59, 0, 26] cellules) », « le rang et la couronne viennent des cellules… », « dix tics dans les dix dernières secondes (10), le chrono rouge à 0:00 », « Espace tenu au gong (vomir, valider) ne quitte pas la partie : rien n'a le focus », « Échap, la manche finie : retour au titre (le solo)… ») ; la trace, celle de la Task 1.

- [ ] **Step 7 : Commit**

```bash
git add Scenes/HUDBataille.tscn Scripts/HUDBataille.gd Scripts/HUDBataille.gd.uid Scripts/Main.gd Assets/Traductions/traductions.csv \
	Assets/Traductions/traductions.en.translation Assets/Traductions/traductions.fr.translation tests/bataille_test.gd
git commit -m "HUD de la bataille : une vignette par joueur dans l'ordre des index (pseudo, lion teint et couronné de travers pour chaque meneur ex æquo compris, part des cellules peintes (100 % à eux tous), rang, crans en points, gerbe XXL décomptée par le HUD, étourdissement, départ en grisé), celle de ce poste mise en évidence ; chrono de 90 s qui rougit et tique dans les dix dernières secondes ; fin au chrono avec son panneau et sa sortie (Échap : le titre, en attendant les Résultats), menu local tu ; musique au temps de la manche

<ligne fournie par l'environnement>"
```

---

### Task 5 : la fin de la manche et les départs passent de l'hôte aux clients (`Manche`, `Main`, version 0.17)

**Files:**
- Modify: `Scripts/Manche.gd`, `Scripts/Main.gd`, `project.godot`
- Test: `tests/smoke_test.gd`

**Interfaces:**
- Consumes (Tasks 1 et 4) : `GameState.partie_terminee`, `temps_ecoule`, `terminer_partie`, `Territoire.scores()`, `HUDBataille.marquer_parti`, `fin`.
- Produces (Task 7) : sur `Manche` : `signal depart_vu(index: int)` (sur chaque poste), `var finie: bool`, `var ecart_chrono_fin: float` (client : chrono de l'hôte moins celui de ce poste à la réception de la fin), `var _partis: Array[int]` (hôte) ; RPC `_recevoir_fin_manche(temps, scores)` (fiable, `CANAL_PEINTURE`) et `_recevoir_depart(index)` (fiable) ; un client n'envoie plus ses commandes une fois la manche finie. `Main` branche `manche.depart_vu` sur `hud_bataille.marquer_parti`, et cache le panneau de fin quand l'hôte est perdu. Version `0.17`.

- [ ] **Step 1 : les tests**

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
		if essai == "absent":
			_check(not reseau.inscrits.has(7) and main.lions.size() == 1, "(absent) un joueur exclu n'a pas de lion")
```

par :

```gdscript
		var hud: CanvasLayer = main.hud_bataille
		_check(hud != null and hud.vignettes.map(func(v: Dictionary) -> String: return v.pseudo.text) == ["Hôte", "Bob"]
			and hud.vignettes[0].badge.text == "TOI",
			"(%s) le HUD de la bataille : une vignette par joueur de la table, « TOI » sur celle de l'hôte" % essai)
		if essai == "absent":
			_check(not reseau.inscrits.has(7) and main.lions.size() == 1, "(absent) un joueur exclu n'a pas de lion")
			_check(manche._partis == [1] and hud.partis == [false, true] and hud.vignettes[1].badge.text == "PARTI",
				"(absent) l'exclu reste au classement, en grisé ; son départ sera annoncé aux clients en passant la barrière")
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
		_check(not is_instance_valid(lion_bob) and main.lions.size() == 1 and ville.territoire.cellules_de(1) == cellules_bob and cellules_bob > 0,
			"un joueur parti en pleine manche perd son lion, ses cellules restent au territoire (%d)" % cellules_bob)
```

par :

```gdscript
		_check(not is_instance_valid(lion_bob) and main.lions.size() == 1 and ville.territoire.cellules_de(1) == cellules_bob and cellules_bob > 0,
			"un joueur parti en pleine manche perd son lion, ses cellules restent au territoire (%d)" % cellules_bob)
		_check(manche._partis == [1] and hud.partis == [false, true] and hud.vignettes[1].part.text != "0 %",
			"le HUD grise Bob, parti, avec sa part des cellules peintes (%s) ; la manche annonce son départ" % hud.vignettes[1].part.text)
		# La fin de la manche chez l'hôte : la manche la note (elle part vers chaque client prêt, après les
		# derniers tampons et le territoire), tout se fige, le panneau de fin s'affiche
		GS.terminer_partie(true)
		_check(manche.finie and paused and hud.fin.visible and not menu.visible, "la fin de manche chez l'hôte : la manche la diffuse, tout se fige, le panneau de fin s'affiche")
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
		_check(message.text == "RESEAU_HOTE_PERDU" and paused, "l'hôte perdu : « L'hôte a quitté la partie », la partie se fige")
```

par :

```gdscript
		_check(message.text == "RESEAU_HOTE_PERDU" and paused and not hud.fin.visible,
			"l'hôte perdu : « L'hôte a quitté la partie » (à la place du panneau de fin), la partie se fige")
```

(Chez l'hôte seulement, comme toute cette section : l'envoi aux clients et leur réception sont vérifiés de bout en bout par le scénario 13 et l'empreinte des scénarios 9, 11 et 12, Task 7.)

- [ ] **Step 2 : ils échouent**

Run : `T=tests/smoke_test.gd; O=""`.
Expected (mesuré) : « (charge) le HUD de la bataille : une vignette par joueur… » passe déjà (Task 4), puis `SCRIPT ERROR: Invalid access to property or key '_partis' on a base object of type 'Node (Manche.gd)'` : la section de la manche en réseau s'interrompt là, et le smoke test finit quand même sur `== 0 échec(s) ==`, `code 0`. C'est la `SCRIPT ERROR` qui fait l'échec (Global Constraints : une `SCRIPT ERROR` ne change pas le code de sortie).

- [ ] **Step 3 : la manche**

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
## - Départs : un client parti (`Reseau.joueur_parti`) perd son lion chez l'hôte (sa disparition est
##   répliquée), ses cellules restent ; un hôte perdu arrête la manche du client (la scène de jeu
##   affiche le message et revient au titre).
```

par :

```gdscript
## - Départs : un client parti (`Reseau.joueur_parti`) perd son lion chez l'hôte (sa disparition est
##   répliquée), ses cellules restent ; l'hôte annonce son départ à chaque client (`depart_vu` : le HUD
##   le grise, phase 17) ; un hôte perdu arrête la manche du client (la scène de jeu affiche le message
##   et revient au titre).
## - Fin de manche (phase 17) : décidée par l'hôte seul (son chrono, ses règles), elle part après ses
##   derniers tampons et son territoire, sur le même canal fiable ordonné, avec son chrono et ses
##   scores ; chaque client la reçoit, prend le chrono de l'hôte et termine sa manche (tout se fige, le
##   HUD montre la fin), puis n'envoie plus de commandes. Le chrono d'un client, parti à la fin de sa
##   propre intro, ne termine jamais rien lui-même. L'état final de chaque lion viendra avec cette fin
##   en phase 18.
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
signal joueur_parti(index: int)
```

par :

```gdscript
signal joueur_parti(index: int)
## Sur chaque poste : le joueur d'index `index` a quitté la manche (chez l'hôte à son départ ; chez un
## client quand l'hôte l'annonce, en passant la barrière pour un départ d'avant) : le HUD le grise.
signal depart_vu(index: int)
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
var empreinte_tampons := 0
```

par :

```gdscript
var empreinte_tampons := 0
## Vrai une fois la manche finie sur ce poste : chez l'hôte à sa fin (ses règles, ou le test réseau
## qui la fige), chez un client à la fin reçue de l'hôte.
var finie := false
## Client : le chrono de l'hôte moins celui de ce poste quand la fin est arrivée, en secondes (lu par
## le test réseau : le décalage de la latence, sans conséquence, puisque le chrono de ce poste prend
## celui de l'hôte).
var ecart_chrono_fin := 0.0
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
var _exclus: Array[int] = []
```

par :

```gdscript
var _exclus: Array[int] = []
## Hôte : les index des joueurs partis de la manche (exclus compris), annoncés à chaque client prêt.
var _partis: Array[int] = []
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
		Reseau.joueur_parti.connect(_sur_depart_reseau)
	Reseau.signaler_scene_chargee()
```

par :

```gdscript
		Reseau.joueur_parti.connect(_sur_depart_reseau)
		GameState.partie_terminee.connect(_sur_fin_de_partie)
	Reseau.signaler_scene_chargee()
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
			[Reseau.joueur_parti, _sur_depart_reseau]]:
```

par :

```gdscript
			[Reseau.joueur_parti, _sur_depart_reseau], [GameState.partie_terminee, _sur_fin_de_partie]]:
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
	_envoyer(&"_lancer_intro", [])
```

par :

```gdscript
	_envoyer(&"_lancer_intro", [])
	for index in _partis:  # les départs d'avant la barrière (exclus compris)
		_envoyer(&"_recevoir_depart", [index])
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
	if not barriere or _prediction == null or not is_instance_valid(_prediction):
```

par :

```gdscript
	if not barriere or finie or _prediction == null or not is_instance_valid(_prediction):
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
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
```

par :

```gdscript
# --- Fin de manche ------------------------------------------------------------------------------


## Chez l'hôte : la manche est finie (son chrono, ou le test réseau qui la fige). Ses derniers tampons
## et son territoire partent d'abord, puis la fin, sur le même canal fiable ordonné : chez un client,
## la fin arrive après eux, les scores définitifs déjà appliqués.
func _sur_fin_de_partie(_victoire: bool) -> void:
	if not barriere or finie:
		return
	finie = true
	_diffuser_tampons()
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


## Chez l'hôte : le client `id` est parti (ou a été exclu).
func _sur_depart_reseau(id: int) -> void:
	_prets.erase(id)
	for j in GameState.joueurs:
		if j.id_reseau == id:
			_commandes.erase(j.index)
			_recues.erase(j.index)
			joueur_parti.emit(j.index)
			_annoncer_depart(j.index)
	_verifier_barriere()


## Chez l'hôte : le joueur d'index `index` est parti ; chaque client prêt l'apprend (les autres, en
## passant la barrière).
func _annoncer_depart(index: int) -> void:
	if _partis.has(index):
		return
	_partis.append(index)
	depart_vu.emit(index)
	_envoyer(&"_recevoir_depart", [index])


## Chez un client : l'hôte annonce le départ du joueur d'index `index`.
@rpc("authority", "call_remote", "reliable")
func _recevoir_depart(index: Variant) -> void:
	if _joueur_recu(index) != null:
		depart_vu.emit(index)
```

(Pourquoi le canal de la peinture : `_recevoir_territoire` y passe aussi, et ENet ne garantit l'ordre qu'à l'intérieur d'un canal ; sur le canal 0, la fin pourrait arriver avant le dernier territoire, et le HUD figé d'un client montrer des scores d'avant. `_diffuser_territoire` n'envoie rien s'il n'y a aucun changement ; la manche, `process_mode` « toujours », continue de toute façon de diffuser l'arbre en pause.)

- [ ] **Step 4 : la scène de jeu et la version**

Dans `Scripts/Main.gd`, remplacer :

```gdscript
	manche.joueur_parti.connect(_sur_joueur_parti)
```

par :

```gdscript
	manche.joueur_parti.connect(_sur_joueur_parti)
	manche.depart_vu.connect(hud_bataille.marquer_parti)
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
	menu_pause.process_mode = Node.PROCESS_MODE_DISABLED
	var couche := CanvasLayer.new()
	couche.name = "HotePerdu"
```

par :

```gdscript
	menu_pause.process_mode = Node.PROCESS_MODE_DISABLED
	if hud_bataille != null:
		hud_bataille.fin.hide()  # une manche finie : le message remplace le panneau de fin et sa sortie
	var couche := CanvasLayer.new()
	couche.name = "HotePerdu"
```

Dans `project.godot`, remplacer :

```text
config/version="0.16"
```

par :

```text
config/version="0.17"
```

(Deux RPC neufs et une propriété de plus dans le `Synchro` du peintre : deux postes de phases différentes doivent se refuser, point de vigilance M7.)

- [ ] **Step 5 : les tests passent, le réseau aussi**

Run : le smoke test, les unitaires, la bataille, le banc, la trace, puis le test réseau (commande des Global Constraints ; seul, rien d'autre en même temps).
Expected (mesuré) : `== 0 échec(s) ==` partout (smoke : 389 ✅, dont « (absent) l'exclu reste au classement, en grisé… », « le HUD grise Bob, parti, avec sa part des cellules peintes (100 %)… », « la fin de manche chez l'hôte : la manche la diffuse… », « l'hôte perdu : … (à la place du panneau de fin)… ») ; la trace, celle de la Task 1 ; le test réseau vert, ses 11 scénarios (≈ 140 s) : les clients des scénarios 9, 11 et 12 reçoivent désormais la fin quand l'hôte fige sa manche (leur arbre se met en pause), sans rien changer à leurs empreintes (les lions sont au repos depuis 30 ticks, `TICKS_REPOS_AVANT_GEL`).

- [ ] **Step 6 : Commit**

```bash
git add Scripts/Manche.gd Scripts/Main.gd project.godot tests/smoke_test.gd
git commit -m "Manche : la fin décidée par l'hôte part vers chaque client après ses derniers tampons et son territoire (même canal fiable), avec son chrono et ses scores ; le client prend le chrono de l'hôte et se fige, n'envoie plus de commandes ; l'hôte annonce chaque départ (ceux d'avant la barrière en la passant) : le HUD de chaque poste grise le joueur parti ; version 0.17

<ligne fournie par l'environnement>"
```

---

### Task 6 : le rythme de la manche à 4-6 joueurs (pastilles, peintre ; `Spawner`, `Boss`, règles)

Décision de l'utilisateur du 27/09 (à régler maintenant, sans essai à 4-6 ; valeurs justifiées ci-dessous, à revoir à l'essai LAN de la phase 19). Le solo ne change pas, sa trace non plus.

**Files:**
- Modify: `Scripts/Regles.gd`, `Scripts/ReglesBataille.gd`, `Scripts/Spawner.gd`, `Scripts/Boss.gd`
- Test: `tests/unitaires.gd`, `tests/bataille_test.gd`

**Interfaces:**
- Consumes : `Lion.CENTRE`, le groupe « lion » et le groupe « pickup » (les pastilles de couleur), `Pastille._expirer`, `Spawner.zone_pickups`, `distance_min_du_lion` (300 px), `delai_entre_pickups` (6 s), `Boss.duree_repos` (2 s), `facteur_vitesse()`.
- Produces : sur `Regles` (valeur du solo / de la bataille) : `pastilles_loin_des_lions() -> bool` (faux / vrai), `pastilles_en_meme_temps() -> int` (1 / 2 de 2 à 3 joueurs, 3 de 4 à 6), `pastille_peut_arriver(presentes: int) -> bool` (toujours / sous le plafond), `delai_entre_pastilles(delai_du_spawner: float) -> float` (celui du Spawner / `DELAI_ENTRE_PASTILLES` = 4 s), `duree_de_vie_pastille() -> float` (0, illimitée / `DUREE_DE_VIE_PASTILLE` = 12 s), `facteur_repos_peintre() -> float` (1 / `FACTEUR_REPOS_PEINTRE` = 2) ; `ReglesBataille.DUREE_REPIT_ENNEMI` (3 s : l'immunité après un étourdissement par un ennemi, au lieu de 1 s), `PASTILLES_JUSQU_A_3_JOUEURS` (2), `PASTILLES_A_4_JOUEURS_ET_PLUS` (3). `Spawner` : en bataille, la pastille suivante arrive après le délai tant qu'il y en a moins que le plafond, jamais au-delà ; chaque départ (ramassage ou fin de vie) en programme une ; `_position_pickup_aleatoire` loin du **centre** de chaque lion, le plus loin des dix essais sinon. `Boss` : pause entre deux passages × `facteur_repos_peintre()`.

Les valeurs (commentées dans `ReglesBataille`) :
- **2 pastilles à la fois de 2 à 3 joueurs, 3 de 4 à 6** : environ une pour deux joueurs, il y en a toujours une à portée sans cesser de se les disputer ;
- **4 s entre deux arrivées** (6 s en solo) : le plafond est atteint en 9 s, une pastille partie est remplacée en 4 s ; de l'ordre de 20 pastilles par manche au lieu de 13, soit 3 à 4 crans par joueur à 6 au lieu de 2 ;
- **12 s de vie** pour une pastille que personne ne prend : trois délais d'arrivée, plus du double de la traversée de l'écran (2000 px à 350 px/s : moins de 6 s) ; une pastille oubliée ne bloque plus les autres sous le plafond ;
- **pastilles loin du centre des lions, le plus loin des dix essais** (le point de vigilance) : aucune ne naît collée à un lion ;
- **3 s de répit après un ennemi** (1 s après un vomi, inchangé) : à 350 px/s, un lion réveillé sous le peintre parcourt plus de 1000 px, plus de deux fois sa largeur (442 px), avant de pouvoir être réétourdi ; les duels ne changent pas ;
- **pause du peintre ×2** (4 s au lieu de 2, 2,6 s en fin de manche) : son cycle passe de 10 à 12 s, la bande de peinture est libre un tiers du temps au lieu d'un cinquième.

Mesuré sur la manche pilotée de `tests/bataille_test.gd` (4 lions dont le pilote court aux pastilles à moins de 900 px) : crans en fin de manche `[7, 7, 7, 7]` au lieu de `[5, 2, 3, 5]` ; avec des joueurs qui ne courent pas après chaque pastille, moins : c'est le premier réglage à revoir en essai (le rythme et le plafond sont des constantes des règles).

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
		"un trade tête-à-tête dans la même frame étourdit les deux lions (aucun n'est ignoré comme agresseur déjà étourdi)")

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
```

par :

```gdscript
		"un trade tête-à-tête dans la même frame étourdit les deux lions (aucun n'est ignoré comme agresseur déjà étourdi)")

	# Ennemis : 2,5 s sans barbouillage, puis 3 s de répit (phase 17 : le temps de fuir le peintre) ;
	# aucune vie perdue
	for i in range(10):
		r.lion_touche_par_ennemi(bleu, Vector2(1, 2))  # le peintre signale le contact à chaque frame
	_check(bleu.est_etourdi() and is_equal_approx(bleu.etourdi_restant, ReglesBataille.DUREE_ETOURDI_ENNEMI)
		and is_equal_approx(bleu.invulnerable_restant, ReglesBataille.DUREE_ETOURDI_ENNEMI + ReglesBataille.DUREE_REPIT_ENNEMI)
		and barbouillages.size() == 2 and barbouillages[1].a == 0.0 and bleu.vies == 3,
		"un ennemi étourdit 2,5 s sans barbouillage (un seul étourdissement pour dix contacts), sans vie perdue, puis laisse 3 s de répit")
	bleu.avancer(ReglesBataille.DUREE_ETOURDI_ENNEMI + ReglesBataille.DUREE_REPIT_ENNEMI - 0.1)
	r.lion_touche_par_ennemi(bleu, Vector2(1, 2))
	_check(barbouillages.size() == 2, "un ennemi ne ré-étourdit pas un lion pendant son répit (le peintre encore dessus)")
	bleu.avancer(0.2)
	gs.pret = false
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript
		"les parts font 100 à elles toutes, le reste de l'arrondi aux plus grands restes, jamais à un joueur sans cellule (%s)" % [parts_a_4])


## Phase 17 : les étiquettes de pseudo de lions qui se touchent s'écartent à l'horizontale, sans
```

par :

```gdscript
		"les parts font 100 à elles toutes, le reste de l'arrondi aux plus grands restes, jamais à un joueur sans cellule (%s)" % [parts_a_4])

	# Le rythme de la manche (phase 17) : pastilles et peintre ; le solo ne change pas
	var solo := ReglesSolo.new(gs)
	_check(solo.pastilles_en_meme_temps() == 1 and solo.pastille_peut_arriver(5) and solo.delai_entre_pastilles(6.0) == 6.0
		and solo.duree_de_vie_pastille() == 0.0 and solo.facteur_repos_peintre() == 1.0
		and not solo.pastilles_loin_des_lions(),
		"en solo, une pastille à la fois, 6 s après le départ de la précédente, sans fin de vie ; le peintre se repose comme avant")
	var plafonds: Array[int] = []
	for nb in [2, 3, 4, 6]:
		gs.configurer_bataille(nb)
		plafonds.append(gs.regles.pastilles_en_meme_temps())
	var b6: Regles = gs.regles
	_check(plafonds == [2, 2, 3, 3] and b6.pastille_peut_arriver(2) and not b6.pastille_peut_arriver(3),
		"en bataille, deux pastilles à la fois de 2 à 3 joueurs, trois de 4 à 6, jamais plus (%s)" % [plafonds])
	_check(b6.delai_entre_pastilles(6.0) == ReglesBataille.DELAI_ENTRE_PASTILLES and ReglesBataille.DELAI_ENTRE_PASTILLES == 4.0
		and b6.duree_de_vie_pastille() == 12.0 and b6.facteur_repos_peintre() == 2.0 and b6.pastilles_loin_des_lions(),
		"en bataille, une pastille toutes les 4 s, qui expire au bout de 12 s si personne ne la prend ; le peintre se repose deux fois plus")
	gs.configurer_solo()


## Phase 17 : les étiquettes de pseudo de lions qui se touchent s'écartent à l'horizontale, sans
```

(Le « rien n'étourdit pendant l'intro » qui suit repart d'un lion sans immunité : le `avancer(0.2)` la finit, sans quoi la vérification ne dirait plus rien.)

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	await _tester_apparitions()
	await _tester_peintre()
```

par :

```gdscript
	await _tester_apparitions()
	await _tester_rythme_pastilles()
	await _tester_peintre()
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
			dans_zone = false
		if lions.all(func(l: Node2D) -> bool: return p.distance_to(l.global_position) >= spawner.distance_min_du_lion):
			loin_de_tous += 1
	_check(dans_zone and y_max > zone.end.y, "les pastilles apparaissent dans leur zone, à l'échelle de l'écran (y jusqu'à %.0f px)" % y_max)
	_check(loin_de_tous >= 190, "les pastilles apparaissent loin de tous les lions, pas seulement du premier (%d/200)" % loin_de_tous)
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
```

par :

```gdscript
			dans_zone = false
		if lions.all(func(l: Node2D) -> bool: return p.distance_to(l.global_position + l.CENTRE) >= spawner.distance_min_du_lion):
			loin_de_tous += 1
	_check(dans_zone and y_max > zone.end.y, "les pastilles apparaissent dans leur zone, à l'échelle de l'écran (y jusqu'à %.0f px)" % y_max)
	_check(loin_de_tous >= 190, "les pastilles apparaissent loin du centre de tous les lions, pas seulement du premier (%d/200)" % loin_de_tous)
	# Phase 17 : aucun des dix essais assez loin (distance impossible) : le plus loin de tous est gardé
	var distance_du_jeu: float = spawner.distance_min_du_lion
	spawner.distance_min_du_lion = 1.0e6
	var graine := 1717
	var attendue := Vector2.ZERO
	var derniere := Vector2.ZERO
	var ecart_max := -1.0
	while graine < 1737:  # une graine dont le plus loin n'est pas le dernier essai (celui que garde le solo)
		seed(graine)
		ecart_max = -1.0
		for essai in range(10):
			derniere = Vector2(randf_range(zone.position.x, zone.end.x), randf_range(zone.position.y * echelle, zone.end.y * echelle))
			var ecart := INF
			for l: Node2D in lions:
				ecart = minf(ecart, derniere.distance_to(l.global_position + l.CENTRE))
			if ecart > ecart_max:
				ecart_max = ecart
				attendue = derniere
		if attendue != derniere:
			break
		graine += 1
	seed(graine)
	var gardee: Vector2 = spawner._position_pickup_aleatoire()
	spawner.distance_min_du_lion = distance_du_jeu
	seed(20260925)
	_check(gardee == attendue and attendue != derniere,
		"sans essai assez loin, la pastille naît au plus loin des lions des dix essais, pas au dernier (%.0f px du plus proche)" % ecart_max)
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
		"les ennemis apparaissent à l'échelle de l'écran et atteignent la bande de peinture (y de %.0f à %.0f)" % [ys.min(), ys.max()])

	# Pastilles : la suivante arrive après le ramassage, même si aucune couleur n'est débloquée
	spawner.delai_entre_pickups = 0.5
	var premiere: Node2D = null
```

par :

```gdscript
		"les ennemis apparaissent à l'échelle de l'écran et atteignent la bande de peinture (y de %.0f à %.0f)" % [ys.min(), ys.max()])

	# Pastilles : la suivante arrive après le ramassage, même si aucune couleur n'est débloquée (le délai
	# est celui des règles de bataille : `delai_entre_pickups`, celui du solo, n'y compte pas)
	var premiere: Node2D = null
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	var suivante: Node2D = null
	for i in range(90):
		suivante = get_first_node_in_group("pickup")
```

par :

```gdscript
	var suivante: Node2D = null
	for i in range(int((ReglesBataille.DELAI_ENTRE_PASTILLES + 0.5) * Engine.physics_ticks_per_second)):
		suivante = get_first_node_in_group("pickup")
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	GS.joueur_local().bonus_restant = 0.0
	await _liberer(main)
```

par :

```gdscript
	GS.joueur_local().bonus_restant = 0.0
	await _liberer(main)


## Phase 17 : le rythme des pastilles à 4 joueurs, lions immobiles, ennemis écartés : une pastille
## toutes les 4 s jusqu'à trois à la fois, jamais plus ; une pastille que personne ne prend expire au
## bout de 12 s, et une autre la remplace 4 s plus tard.
func _tester_rythme_pastilles() -> void:
	print("-- Rythme des pastilles à 4")
	var main := await _charger_bataille(0)
	var ecarter := func() -> void:
		for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss"):
			ennemi.queue_free()
	physics_frame.connect(ecarter)
	await _attendre_depart()
	var depart: float = GS.temps_ecoule
	var arrivees: Array[float] = []  # secondes de manche de chaque arrivée
	var departs: Array[float] = []
	var vues := {}
	var plus_grand_nombre := 0
	var premiere: Node2D = null
	var ramassees := 0
	var crans_avant := 0
	for j: Joueur in GS.joueurs:
		crans_avant += j.crans
	for f in range(int(26.0 * Engine.physics_ticks_per_second)):
		await physics_frame
		var presentes := get_nodes_in_group("pickup")
		plus_grand_nombre = maxi(plus_grand_nombre, presentes.size())
		var t: float = GS.temps_ecoule - depart
		for p: Node in presentes:
			if not vues.has(p.get_instance_id()):
				vues[p.get_instance_id()] = t
				arrivees.append(t)
				if arrivees.size() == 1:
					premiere = p
		if arrivees.size() >= 1 and not is_instance_valid(premiere) and departs.is_empty():
			departs.append(t)  # (un objet libéré ne se compare pas à null : is_instance_valid seul)
	physics_frame.disconnect(ecarter)
	for j: Joueur in GS.joueurs:
		ramassees += j.crans
	ramassees -= crans_avant
	var arrondies: Array = arrivees.map(func(t: float) -> String: return "%.1f" % t)
	_check(ramassees == 0, "(pré-condition) aucun lion, immobile, ne ramasse de pastille (%d)" % ramassees)
	_check(plus_grand_nombre == ReglesBataille.PASTILLES_A_4_JOUEURS_ET_PLUS and arrivees.size() >= 4
		and absf(arrivees[1] - arrivees[0] - ReglesBataille.DELAI_ENTRE_PASTILLES) < 0.1
		and absf(arrivees[2] - arrivees[1] - ReglesBataille.DELAI_ENTRE_PASTILLES) < 0.1,
		"à 4, une pastille toutes les 4 s jusqu'à trois à la fois, jamais plus (arrivées %s)" % [arrondies])
	_check(not departs.is_empty() and absf(departs[0] - arrivees[0] - ReglesBataille.DUREE_DE_VIE_PASTILLE) < 0.1
		and absf(arrivees[3] - departs[0] - ReglesBataille.DELAI_ENTRE_PASTILLES) < 0.1,
		"une pastille que personne ne prend expire au bout de 12 s (%.1f s), une autre arrive 4 s plus tard (%.1f s)"
			% [departs[0] - arrivees[0] if not departs.is_empty() else -1.0, arrivees[3] - departs[0] if not departs.is_empty() and arrivees.size() >= 4 else -1.0])
	# Au plafond, une arrivée de plus (celle qu'un départ et la suite des arrivées programment parfois en
	# même temps) n'ajoute rien
	var au_plafond := get_nodes_in_group("pickup").size()
	main.get_node("Spawner")._spawn_prochain_pickup()
	await _frames(1)
	_check(au_plafond == ReglesBataille.PASTILLES_A_4_JOUEURS_ET_PLUS and get_nodes_in_group("pickup").size() == au_plafond,
		"au plafond (%d), une pastille de plus ne peut pas arriver" % au_plafond)
	await _liberer(main)
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
		"le peintre étourdit le lion de bataille qu'il touche, sans lui ôter de vie")
	await _liberer(main)
```

par :

```gdscript
		"le peintre étourdit le lion de bataille qu'il touche, sans lui ôter de vie")
	_check(is_equal_approx(j3.invulnerable_restant - j3.etourdi_restant, ReglesBataille.DUREE_REPIT_ENNEMI),
		"puis lui laisse %.0f s de répit pour fuir, même s'il reste dessous (%.2f s)" % [ReglesBataille.DUREE_REPIT_ENNEMI, j3.invulnerable_restant - j3.etourdi_restant])
	# Phase 17 : en bataille, le peintre se repose deux fois plus longtemps hors de l'écran qu'en solo
	boss._changer_etat(boss.Etat.REPOS)
	var attendu: float = boss.duree_repos * ReglesBataille.FACTEUR_REPOS_PEINTRE * boss.facteur_vitesse()
	var ticks := 0
	while boss.etat == boss.Etat.REPOS and ticks < 600:
		await physics_frame
		ticks += 1
	_check(absf(ticks / 60.0 - attendu) < 0.05 and attendu > 3.8,
		"en bataille, la pause du peintre entre deux passages dure deux fois celle du solo (%.2f s, attendu %.2f s)" % [ticks / 60.0, attendu])
	await _liberer(main)
```

Dans `tests/bataille_test.gd`, remplacer :

```gdscript
	print("-- Réglage du territoire sur une passe pleine vitesse")
	root.content_scale_size = Vector2i(TAILLE_BATAILLE)  # l'écran d'une bataille (sans Main dans cette section)
```

par :

```gdscript
	print("-- Réglage du territoire sur une passe pleine vitesse")
	# Les motifs des tampons (couverture du solo) suivent le hasard global : semé ici, cette mesure ne
	# dépend plus de ce que les sections d'avant ont tiré (phase 17 : la section du rythme des pastilles
	# l'avait poussée de 1,22 à 1,29, près de la borne de 1,3)
	seed(20260925)
	root.content_scale_size = Vector2i(TAILLE_BATAILLE)  # l'écran d'une bataille (sans Main dans cette section)
```

(Le test du rythme tire les pastilles du vrai Spawner, lions immobiles et ennemis écartés à chaque image : arrivées à 1, 5 et 9 s, puis la première expire à 13 s et une autre arrive à 17 s (mesuré). Le test des dix essais tire lui-même les dix candidats avec la graine, dans l'ordre du Spawner (x puis y), puis rejoue la graine pour le Spawner : il doit garder exactement le plus éloigné ; une graine dont le plus éloigné serait le dernier ne discriminerait rien (mesuré : 1717 en est une, 1718 non), la boucle choisit la première qui convient ; la graine de la section est reposée ensuite. La pause du peintre se mesure au tick près : `facteur_vitesse()` y vaut encore presque 1. Le réglage du territoire resème le hasard à son début : les motifs des tampons, donc la couverture du solo qu'il compare au territoire, suivaient ce que les sections d'avant avaient tiré ; avec la section du rythme, son rapport le plus haut passait de 1,22 à 1,29 en headless et 1,33 avec le rendu (au-delà de la borne de 1,3 : vu en préparant le plan) ; resemé, 1,20 et 1,21.)

- [ ] **Step 2 : ils échouent**

Run : les unitaires, puis `T=tests/bataille_test.gd; O="--fixed-fps 60"`.
Expected (mesuré) : aucun des deux ne compile (`SCRIPT ERROR: Parse Error: Cannot find member "DUREE_REPIT_ENNEMI" in base "ReglesBataille".` pour les unitaires, `… "DELAI_ENTRE_PASTILLES" …` pour la bataille), `code 0` et aucune ligne `== n échec(s) ==`.

- [ ] **Step 3 : les règles, le Spawner et le peintre**

Dans `Scripts/Regles.gd`, remplacer :

```gdscript
	return false


## Vrai si la partie a des cœurs à ramasser (le Spawner ne programme leurs apparitions que si
```

par :

```gdscript
	return false


## Vrai si une pastille doit apparaître loin du centre de chaque lion, au plus loin des dix essais du
## Spawner quand aucun ne l'est assez ; faux (le solo, inchangé) : loin du coin du lion, le dernier
## essai gardé.
func pastilles_loin_des_lions() -> bool:
	return false


## Pastilles de couleur présentes en même temps au plus : après chaque arrivée, le Spawner en programme
## une autre tant qu'il y en a moins. Une seule par défaut (le solo : la suivante n'arrive qu'après le
## départ de la précédente).
func pastilles_en_meme_temps() -> int:
	return 1


## Vrai si une pastille peut arriver alors que `presentes` sont déjà là : toujours par défaut (le solo,
## inchangé) ; en bataille, sous le plafond (`pastilles_en_meme_temps`).
func pastille_peut_arriver(_presentes: int) -> bool:
	return true


## Délai avant l'arrivée de la pastille suivante (après le départ d'une pastille ou, sous le plafond,
## l'arrivée de la précédente), en secondes : celui du Spawner par défaut (le solo, 6 s).
func delai_entre_pastilles(delai_du_spawner: float) -> float:
	return delai_du_spawner


## Durée de vie d'une pastille de couleur que personne ne ramasse, en secondes ; 0 : illimitée (le
## solo). Sa fin (`Pastille._expirer`) est un départ comme un autre : la suivante est programmée.
func duree_de_vie_pastille() -> float:
	return 0.0


## Facteur de la pause du peintre entre deux passages : 1 par défaut (le solo).
func facteur_repos_peintre() -> float:
	return 1.0


## Vrai si la partie a des cœurs à ramasser (le Spawner ne programme leurs apparitions que si
```

Dans `Scripts/ReglesBataille.gd`, remplacer :

```gdscript
## départ dans les trois nuances de sa couleur ; le vomi d'un autre lion l'étourdit 1,5 s (tête
## barbouillée de la couleur de l'agresseur), un ennemi 2,5 s, puis 1 s d'immunité ; chaque
## pastille donne un cran de gerbe ; l'étoile XXL est celle du solo. La manche se joue au
## territoire, que tient la ville (`Territoire`) : les règles en comptent les vols. L'écran est
## en 16:9 ; une pastille est toujours offerte, l'étoile toujours possible, jamais de cœur. Le
## chrono termine la manche chez l'hôte (phase 17) ; le plus de cellules gagne, ex æquo possibles
```

par :

```gdscript
## départ dans les trois nuances de sa couleur ; le vomi d'un autre lion l'étourdit 1,5 s (tête
## barbouillée de la couleur de l'agresseur) puis l'immunise 1 s, un ennemi l'étourdit 2,5 s puis lui
## laisse 3 s de répit (le temps de fuir le peintre, phase 17) ; chaque
## pastille donne un cran de gerbe ; l'étoile XXL est celle du solo. La manche se joue au
## territoire, que tient la ville (`Territoire`) : les règles en comptent les vols. L'écran est
## en 16:9 ; une pastille est toujours offerte (plusieurs à la fois, qui expirent), l'étoile toujours
## possible, jamais de cœur ; le peintre se repose deux fois plus longtemps qu'en solo. Le
## chrono termine la manche chez l'hôte (phase 17) ; le plus de cellules gagne, ex æquo possibles
```

Dans `Scripts/ReglesBataille.gd`, remplacer :

```gdscript
const DUREE_IMMUNITE := 1.0
## Durée d'une manche (spec §2) : son temps écoulé fait l'avancement, et le chrono la termine chez
```

par :

```gdscript
const DUREE_IMMUNITE := 1.0
## Réglages du rythme de la manche à 4-6 joueurs (phase 17, faits sans essai à 4-6 : à revoir à
## l'essai LAN de la phase 19). Après un étourdissement par un ennemi, le répit (l'immunité) laisse le
## temps de fuir : à 350 px/s, 3 s font plus de 1000 px, plus de deux fois la largeur du peintre
## (442 px) ; l'immunité après un vomi reste de 1 s (les duels ne changent pas).
const DUREE_REPIT_ENNEMI := 3.0
## Pastilles en même temps au plus : environ une pour deux joueurs, pour qu'il y en ait toujours une
## à portée sans cesser de se les disputer.
const PASTILLES_JUSQU_A_3_JOUEURS := 2
const PASTILLES_A_4_JOUEURS_ET_PLUS := 3
## Délai entre deux arrivées (6 s en solo) : le plafond est atteint en 9 s, et une pastille partie
## est remplacée en 4 s ; de l'ordre de 20 pastilles par manche au lieu de 13, 3 à 4 crans par joueur
## à 6 au lieu de 2.
const DELAI_ENTRE_PASTILLES := 4.0
## Durée de vie d'une pastille que personne ne ramasse : trois délais d'arrivée, bien plus que la
## traversée de l'écran (2000 px à 350 px/s : moins de 6 s) ; une pastille oubliée ne bloque plus les
## autres sous le plafond.
const DUREE_DE_VIE_PASTILLE := 12.0
## La pause du peintre hors de l'écran, deux fois celle du solo (4 s au lieu de 2, 2,6 s en fin de
## manche) : la bande de peinture est libre un tiers du temps au lieu d'un cinquième.
const FACTEUR_REPOS_PEINTRE := 2.0
## Durée d'une manche (spec §2) : son temps écoulé fait l'avancement, et le chrono la termine chez
```

Dans `Scripts/ReglesBataille.gd`, remplacer :

```gdscript
	return true


## Pas de vie perdue : l'ennemi étourdit, sans barbouillage.
func lion_touche_par_ennemi(joueur: Joueur, origine: Vector2) -> void:
	if not _peut_etre_etourdi(joueur):
		return
	joueur.etourdir(DUREE_ETOURDI_ENNEMI, DUREE_IMMUNITE, origine, Color.TRANSPARENT)


## Un lion étourdi ne vomit plus : s'il est signalé comme agresseur, il n'étourdit personne, sauf
```

par :

```gdscript
	return true


## À plusieurs, un lion est presque toujours près d'une pastille qui naît : jamais collée à l'un d'eux
## (point de vigilance de la phase 17).
func pastilles_loin_des_lions() -> bool:
	return true


## Deux pastilles à la fois de 2 à 3 joueurs, trois de 4 à 6.
func pastilles_en_meme_temps() -> int:
	return PASTILLES_JUSQU_A_3_JOUEURS if partie.joueurs.size() <= 3 else PASTILLES_A_4_JOUEURS_ET_PLUS


func pastille_peut_arriver(presentes: int) -> bool:
	return presentes < pastilles_en_meme_temps()


func delai_entre_pastilles(_delai_du_spawner: float) -> float:
	return DELAI_ENTRE_PASTILLES


func duree_de_vie_pastille() -> float:
	return DUREE_DE_VIE_PASTILLE


func facteur_repos_peintre() -> float:
	return FACTEUR_REPOS_PEINTRE


## Pas de vie perdue : l'ennemi étourdit, sans barbouillage, puis laisse son répit (le peintre, qui
## couvre la bande de peinture, étourdirait sinon sans relâche un lion qui vient de se réveiller dessous).
func lion_touche_par_ennemi(joueur: Joueur, origine: Vector2) -> void:
	if not _peut_etre_etourdi(joueur):
		return
	joueur.etourdir(DUREE_ETOURDI_ENNEMI, DUREE_REPIT_ENNEMI, origine, Color.TRANSPARENT)


## Un lion étourdi ne vomit plus : s'il est signalé comme agresseur, il n'étourdit personne, sauf
```

Dans `Scripts/Spawner.gd`, remplacer :

```gdscript
@export var delai_premier_pickup := 1.0
## Délai entre le départ d'une pastille (ramassée) et l'arrivée de la suivante.
@export var delai_entre_pickups := 6.0
```

par :

```gdscript
@export var delai_premier_pickup := 1.0
## Délai entre le départ d'une pastille (ramassée) et l'arrivée de la suivante, en solo (en bataille,
## celui des règles : `Regles.delai_entre_pastilles`).
@export var delai_entre_pickups := 6.0
```

Dans `Scripts/Spawner.gd`, remplacer :

```gdscript
	return bonus


## La pastille suivante est programmée quand celle-ci quitte la scène (ramassée) : en bataille,
## un cran de gerbe ne débloque aucune couleur, rien d'autre ne le signalerait. Une scène qui se
## libère fait aussi sortir ses pastilles : rien n'est programmé hors de l'arbre.
func _on_pastille_partie() -> void:
	if is_inside_tree():
		_programmer(delai_entre_pickups, _spawn_prochain_pickup)


func _spawn_prochain_pickup() -> void:
	var index := GameState.regles.pastille_a_offrir()
	if index < 0 or not GameState.partie_en_cours:
		return
	spawn_pickup(index, _position_pickup_aleatoire())


## Hauteur de l'écran rapportée à celle du solo : 1 en solo (hauteurs d'apparition inchangées).
```

par :

```gdscript
	return bonus


## La pastille suivante est programmée quand celle-ci quitte la scène (ramassée, ou expirée en
## bataille) : en bataille, un cran de gerbe ne débloque aucune couleur, rien d'autre ne le
## signalerait. Une scène qui se libère fait aussi sortir ses pastilles : rien n'est programmé hors de
## l'arbre.
func _on_pastille_partie() -> void:
	if is_inside_tree():
		_programmer(GameState.regles.delai_entre_pastilles(delai_entre_pickups), _spawn_prochain_pickup)


## Une pastille arrive, si les règles en offrent une et en laissent arriver une de plus (en bataille,
## sous le plafond) ; tant qu'il y en a moins que `Regles.pastilles_en_meme_temps`, la suivante est
## programmée après le délai (en solo, une seule : la suivante attend le départ de celle-ci).
func _spawn_prochain_pickup() -> void:
	var index := GameState.regles.pastille_a_offrir()
	if index < 0 or not GameState.partie_en_cours:
		return
	var presentes := get_tree().get_nodes_in_group("pickup").size()
	if not GameState.regles.pastille_peut_arriver(presentes):
		return
	spawn_pickup(index, _position_pickup_aleatoire())
	if presentes + 1 < GameState.regles.pastilles_en_meme_temps():
		_programmer(GameState.regles.delai_entre_pastilles(delai_entre_pickups), _spawn_prochain_pickup)


## Hauteur de l'écran rapportée à celle du solo : 1 en solo (hauteurs d'apparition inchangées).
```

Dans `Scripts/Spawner.gd`, remplacer :

```gdscript
	return get_viewport().get_visible_rect().size.y / Regles.TAILLE_ECRAN_SOLO.y


## Au hasard dans la zone des pastilles, à `distance_min_du_lion` de chaque lion si possible
## (dix essais).
func _position_pickup_aleatoire() -> Vector2:
	var lions := get_tree().get_nodes_in_group("lion")
	var echelle := _echelle_hauteur()
	var pos := Vector2.ZERO
	for tentative in range(10):
		pos = Vector2(
			randf_range(zone_pickups.position.x, zone_pickups.end.x),
			randf_range(zone_pickups.position.y * echelle, zone_pickups.end.y * echelle))
		if lions.all(func(l: Node) -> bool: return pos.distance_to((l as Node2D).global_position) >= distance_min_du_lion):
			break
	return pos


func _y_ennemi_aleatoire() -> float:
```

par :

```gdscript
	return get_viewport().get_visible_rect().size.y / Regles.TAILLE_ECRAN_SOLO.y


## Au hasard dans la zone des pastilles, à `distance_min_du_lion` de chaque lion si possible (dix
## essais). En solo, mesurée depuis le coin du lion (`global_position`), le dernier essai gardé si
## aucun ne convient ; en bataille (`Regles.pastilles_loin_des_lions`), depuis le centre de chaque
## lion, et le plus loin de tous des dix essais gardé : une pastille ne naît pas collée à un lion.
func _position_pickup_aleatoire() -> Vector2:
	var lions := get_tree().get_nodes_in_group("lion")
	var echelle := _echelle_hauteur()
	var loin := GameState.regles.pastilles_loin_des_lions()
	var pos := Vector2.ZERO
	var plus_loin := Vector2.ZERO
	var plus_grand_ecart := -1.0
	for tentative in range(10):
		pos = Vector2(
			randf_range(zone_pickups.position.x, zone_pickups.end.x),
			randf_range(zone_pickups.position.y * echelle, zone_pickups.end.y * echelle))
		if not loin:
			if lions.all(func(l: Node) -> bool: return pos.distance_to((l as Node2D).global_position) >= distance_min_du_lion):
				break
			continue
		var ecart := INF
		for l: Node2D in lions:
			ecart = minf(ecart, pos.distance_to(l.global_position + Lion.CENTRE))
		if ecart >= distance_min_du_lion:
			return pos
		if ecart > plus_grand_ecart:
			plus_grand_ecart = ecart
			plus_loin = pos
	return plus_loin if loin else pos


func _y_ennemi_aleatoire() -> float:
```

Dans `Scripts/Spawner.gd`, remplacer :

```gdscript
	get_parent().add_child(pickup, true)
	return pickup
```

par :

```gdscript
	get_parent().add_child(pickup, true)
	# En bataille, une pastille que personne ne ramasse expire (l'arbre en pause, sa minuterie attend)
	var vie: float = GameState.regles.duree_de_vie_pastille()
	if vie > 0.0:
		get_tree().create_timer(vie, false).timeout.connect(pickup._expirer)
	return pickup
```

Dans `Scripts/Boss.gd`, remplacer :

```gdscript
@export var duree_sortie := 3.0
@export var duree_repos := 2.0
@export var acceleration_max := 0.65     # facteur de durée en fin de partie (avancement des règles)
```

par :

```gdscript
@export var duree_sortie := 3.0
@export var duree_repos := 2.0           # en solo ; en bataille, fois `Regles.facteur_repos_peintre`
@export var acceleration_max := 0.65     # facteur de durée en fin de partie (avancement des règles)
```

Dans `Scripts/Boss.gd`, remplacer :

```gdscript
			position.x = _x_hors_ecran()
			_tween.tween_interval(duree_repos * facteur_vitesse())
			_tween.tween_callback(_changer_etat.bind(Etat.ANNONCE))
```

par :

```gdscript
			position.x = _x_hors_ecran()
			_tween.tween_interval(duree_repos * GameState.regles.facteur_repos_peintre() * facteur_vitesse())
			_tween.tween_callback(_changer_etat.bind(Etat.ANNONCE))
```

(Le solo passe exactement par les mêmes calculs qu'avant : `pastille_peut_arriver` toujours vrai, un plafond de 1 qu'une arrivée atteint toujours (aucune suivante programmée), le délai du Spawner, aucune fin de vie, `duree_repos × 1.0` exact en flottant ; la minuterie de fin de vie n'est créée qu'en bataille et s'arrête l'arbre en pause (`create_timer(vie, false)`). Une pastille libérée avant sa fin de vie emporte la connexion de la minuterie.)

- [ ] **Step 4 : les tests passent ; la trace de la bataille change (et elle seule)**

Run : `godot --headless --import . > /dev/null 2>&1`, puis les unitaires, la bataille, le smoke test, le banc, puis la trace.
Expected (mesuré) : `== 0 échec(s) ==` partout (unitaires : 383 ✅ ; bataille : 100 ✅, dont « à 4, une pastille toutes les 4 s jusqu'à trois à la fois, jamais plus (arrivées ["1.0", "5.0", "9.0", "17.0", "21.0", "25.0"]) », « une pastille que personne ne prend expire au bout de 12 s (12.0 s), une autre arrive 4 s plus tard (4.0 s) », « au plafond (3), une pastille de plus ne peut pas arriver », « les pastilles apparaissent loin du centre de tous les lions… (198/200) », « sans essai assez loin… (379 px du plus proche) », « puis lui laisse 3 s de répit pour fuir… (3.00 s) », « en bataille, la pause du peintre… (4.00 s, attendu 4.00 s) ») ; la trace, deux passages identiques : `TRACE bataille 2492461451 TRACE solo 185311436 TRACE replique 3757044499` (la bataille de la trace a ses pastilles et son peintre : elle change, Écart 11 ; le solo et la réplique ne changent pas). Noter la nouvelle référence de la bataille.

Preuve (hors commit, sur une copie jetable) : remplacer `return plus_loin if loin else pos` par `return pos` dans `Scripts/Spawner.gd` : la bataille doit sortir `❌ sans essai assez loin…` ; et supprimer la ligne `if not GameState.regles.pastille_peut_arriver(presentes):` avec son `return` : `❌ au plafond (3), une pastille de plus ne peut pas arriver` (mesuré ; sans elle, un départ et la suite des arrivées programmés ensemble dépasseraient le plafond) ; revenir.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Regles.gd Scripts/ReglesBataille.gd Scripts/Spawner.gd Scripts/Boss.gd tests/unitaires.gd tests/bataille_test.gd
git commit -m "Rythme de la bataille (décision du 27/09, à revoir à l'essai LAN) : pastilles à plusieurs (2 de 2 à 3 joueurs, 3 de 4 à 6), une toutes les 4 s sous le plafond, qui expirent au bout de 12 s, loin du centre des lions et au plus loin des dix essais ; 3 s de répit après un ennemi, pause du peintre doublée ; le solo ne change pas

<ligne fournie par l'environnement>"
```

---

### Task 7 : le test réseau voit la fin au chrono de l'hôte et compare les HUD (scénario 13, `hud=` dans l'empreinte)

**Files:**
- Modify: `tests/reseau/joueur.gd`, `tests/reseau/lancer.sh`

**Interfaces:**
- Consumes (Tasks 1, 4, 5) : `load("res://Scripts/ReglesBataille.gd").duree_manche`, `SECONDES_TIC`, `Main.hud_bataille` (`resume()`, `vignettes`, `fin`, `chrono`, `tics_joues`), `Manche.finie`, `ecart_chrono_fin` ; le relais (`tests/reseau/relais.gd`, phase 16).
- Produces : rôles `chrono-hote` et `chrono-client` (`--duree-manche=S`, `--sens`, `--rester`) ; lignes `ECART_CHRONO <s>` (client) et `FIN <HUD>` (chaque poste) ; `hud=<HUD>` dans chaque ligne `EMPREINTE` ; le scénario 13 de `lancer.sh` (ports `PORT_BASE + 13`, `+ 1013`, relais `+ 2013`).

- [ ] **Step 1 : le scénario et ses rôles**

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
## Rôles : hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client,
## manche-muet, bout-hote, bout-client, latence-hote, latence-client.
```

par :

```gdscript
## Rôles : hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client,
## manche-muet, bout-hote, bout-client, latence-hote, latence-client, chrono-hote, chrono-client.
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads
```

par :

```gdscript
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
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
## Vitesse (px/s) au-delà de laquelle un lion ramasse une pastille « au vol », ou percute l'hôte.
```

par :

```gdscript
## Fin de manche au chrono : écart toléré entre le chrono de l'hôte et celui d'un client quand la fin y
## arrive, en secondes (la latence de l'intro et celle de la fin se compensent : reste la gigue du relais,
## 40 ms, et une image de chaque côté).
const ECART_CHRONO := 0.25
## Vitesse (px/s) au-delà de laquelle un lion ramasse une pastille « au vol », ou percute l'hôte.
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	elif role == "latence-hote" or role == "latence-client":
		await _jouer_latence(role == "latence-hote")
	else:
		_check(false, "rôle inconnu : --role=hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client, manche-muet, bout-hote, bout-client, latence-hote ou latence-client")
```

par :

```gdscript
	elif role == "latence-hote" or role == "latence-client":
		await _jouer_latence(role == "latence-hote")
	elif role == "chrono-hote" or role == "chrono-client":
		await _jouer_chrono(role == "chrono-hote")
	else:
		_check(false, "rôle inconnu : --role=hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client, manche-muet, bout-hote, bout-client, latence-hote, latence-client, chrono-hote ou chrono-client")
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
## (position, orientation, crans, étourdi, gerbe XXL), apparitions (ennemis et pastilles : nom et position),
## niveau et, pour la manche de bout en bout, les réactions de chaque joueur vues ici.
```

par :

```gdscript
## (position, orientation, crans, étourdi, gerbe XXL), apparitions (ennemis et pastilles : nom et position),
## niveau, le HUD de la bataille (phase 17 : chrono, pseudos, parts, rangs, départs) et, pour la manche
## de bout en bout, les réactions de chaque joueur vues ici.
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	return "territoire=%d scores=%s tampons=%d:%d lions=%s apparitions=%s niveau=%d reactions=%s" % [hash(proprietaires), territoire.scores(),
		manche.tampons_diffuses if hote else manche.tampons_recus, manche.empreinte_tampons, ";".join(lions), ";".join(apparitions),
		root.get_node("GameState").niveau_courant, ";".join(reactions)]
```

par :

```gdscript
	return "territoire=%d scores=%s tampons=%d:%d lions=%s apparitions=%s niveau=%d hud=%s reactions=%s" % [hash(proprietaires), territoire.scores(),
		manche.tampons_diffuses if hote else manche.tampons_recus, manche.empreinte_tampons, ";".join(lions), ";".join(apparitions),
		root.get_node("GameState").niveau_courant, main.hud_bataille.resume(), ";".join(reactions)]
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
## Joue le programme de ce poste, image après image, jusqu'à `condition` (au plus `delai` secondes).
```

par :

```gdscript
## Rôles « chrono-hote » et « chrono-client » (phase 17, voir l'en-tête) : une manche courte que le
## chrono de l'hôte termine ; chaque poste la voit finir sur le même HUD, puis l'hôte sort par Échap et
## ses clients le voient partir.
func _jouer_chrono(hote: bool) -> void:
	var duree := float(_option("duree-manche", "10"))
	var script_regles: Script = load("res://Scripts/ReglesBataille.gd")
	script_regles.duree_manche = duree
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
	await _jouer_passe(main, int(_option("sens", "1")))
	_check(await _attendre(func() -> bool: return not gs.partie_en_cours, duree + 10.0), "la manche se termine")
	if hote:
		_check(manche.finie and gs.temps_ecoule >= duree and gs.temps_ecoule < duree + 0.1,
			"le chrono de l'hôte termine la manche à %.0f s (%.3f s)" % [duree, gs.temps_ecoule])
	else:
		print("ECART_CHRONO %.3f" % manche.ecart_chrono_fin)
		_check(manche.finie and absf(manche.ecart_chrono_fin) <= ECART_CHRONO and gs.temps_ecoule >= duree and gs.temps_ecoule < duree + 0.1,
			"la fin de l'hôte termine la manche de ce client, son chrono pris sur celui de l'hôte (%.3f s, écart %.3f s)" % [gs.temps_ecoule, manche.ecart_chrono_fin])
	var tics_attendus := mini(ReglesBataille.SECONDES_TIC, ceili(duree) - 1)
	_check(paused and hud.fin.visible and hud.chrono.text == "0:00" and hud.tics_joues == tics_attendus,
		"tout se fige sur le panneau de fin, le chrono à 0:00, %d tics sur %d attendus" % [hud.tics_joues, tics_attendus])
	print("FIN %s" % hud.resume())
	if hote:
		var rester := _option("rester", "")
		print("HOTE RESTE")
		_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
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
			"puis retour au titre, hors réseau")


## Joue le programme de ce poste, image après image, jusqu'à `condition` (au plus `delai` secondes).
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
# manche synchronisée (phase 14), de bout en bout (phase 15) et de la prédiction sous latence
# simulée (phase 16) : des postes headless sur localhost, un processus Godot par poste
# (tests/reseau/joueur.gd), et pour le scénario 12 le simulateur de latence (tests/reseau/relais.gd),
# scénario après scénario.
```

par :

```bash
# manche synchronisée (phase 14), de bout en bout (phase 15), de la prédiction sous latence
# simulée (phase 16) et de la fin de manche au chrono (phase 17) : des postes headless sur localhost,
# un processus Godot par poste (tests/reseau/joueur.gd), et pour les scénarios 12 et 13 le simulateur de
# latence (tests/reseau/relais.gd), scénario après scénario.
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
# et, pour les balises de découverte, port_de_base + 1000 + n (jamais le 7778) ; le relais du
# scénario 12 écoute sur port_de_base + 2012.
```

par :

```bash
# et, pour les balises de découverte, port_de_base + 1000 + n (jamais le 7778) ; le relais du
# scénario n (12, 13) écoute sur port_de_base + 2000 + n.
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40 ; les
# scénarios 11 et 12, des manches jouées, ont le leur : DUREE11 + 60, DUREE12 + 50),
```

par :

```bash
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40 ; les
# scénarios 11, 12 et 13, des manches jouées, ont le leur : DUREE11 + 60, DUREE12 + 50, DUREE13 + 50),
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
grep -hE "^PREDICTION |^COMMANDES |^RELAIS datagrammes" "$JOURNAUX/a12.log" "$JOURNAUX/b12.log" "$JOURNAUX/hote12.log" "$JOURNAUX/relais12.log" 2>/dev/null | sed 's/^/  (latence) /'
```

par :

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
```

(Le scénario 13 passe derrière le relais, sous 80 ms, 40 ms de gigue et 5 % de pertes : la latence de l'intro (qui fait partir le chrono du client en retard) et celle de la fin (qui arrive en retard) se compensent, reste la gigue : mesuré, `ECART_CHRONO` 0,007 à 0,041 s. `attendre_ligne` accepte une expression : `"^FIN "` ne peut pas prendre une vérification pour la ligne attendue. Les deux clients jouent leur passe, puis l'hôte la sienne avant la fin, de 10 s : 4 s environ de passe, le reste à attendre le gong ; les tics attendus sont 9, de 0:09 à 0:01, sur chaque poste.)

- [ ] **Step 2 : ils passent**

Pas d'étape « il échoue » à part : tout le jeu vérifié ici existe depuis la Task 5 ; la preuve que ce scénario discrimine est au Step 4.

Run : le test réseau (commande des Global Constraints ; seul), une fois.
Expected (mesuré) : `== 0 échec(s) ==`, et à la fin :

```text
  ✅ fin de manche au chrono de l'hôte sous latence simulée : chaque client la reçoit, le même HUD figé partout (chrono, parts, rangs, tics), puis l'hôte sort par Échap
  (chrono) FIN 0:00|Hote13:30 %:2e|Bruno:30 %:2e|Anna:40 %:1er
  (chrono) ECART_CHRONO 0.019
  (chrono) FIN 0:00|Hote13:30 %:2e|Bruno:30 %:2e|Anna:40 %:1er
  (chrono) ECART_CHRONO 0.041
  (chrono) FIN 0:00|Hote13:30 %:2e|Bruno:30 %:2e|Anna:40 %:1er
```

(Les parts (des cellules peintes : elles font 100 %) et les rangs varient d'un passage à l'autre, jamais d'un poste à l'autre ; ici l'hôte et Bruno sont ex æquo, « 2e » tous deux, avec les mêmes cellules. L'ordre des vignettes est celui des index : Bruno a eu la place de l'index 1 au salon.) Les empreintes des scénarios 9, 11 et 12 comptent le HUD, par exemple (mesuré, en gardant les journaux) : `hud=1:25|Hote9:80 %:1er|Muet:0 %::parti|Anna:11 %:2e|Bruno:9 %:3e:parti` chez l'hôte **et** chez Anna (le muet exclu avant la barrière, Bruno parti par le menu, ses cellules comptées), `hud=0:45|Hote11:21 %:2e|Chloe:20 %:3e|Anna:53 %:1er|Bruno:6 %:4e:parti` chez l'hôte et les deux clients restés (Bruno arraché), `hud=1:10|Hote12:0 %:|Bruno:42 %:2e|Anna:58 %:1er` au scénario 12 (l'hôte immobile n'a rien peint : ni rang ni couronne). Le test réseau prend 156 à 158 s (≈ 140 s avant ce scénario) : sous le `timeout 300` du pas de CI.

- [ ] **Step 3 : 5 fois sous chaque bash**

Run : `for i in 1 2 3 4 5; do timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r$i.log" 2>&1; echo "bash5 $i code $?"; grep -cE "❌|SCRIPT ERROR" "$TMPDIR/r$i.log"; done`, puis la même boucle avec `/bin/bash` (3.2, macOS).
Expected : dix `code 0`, aucun `❌` ni `SCRIPT ERROR`, sans relance.

Vu en préparant le plan (copie d'`origin/phase-16-prediction` et de ces tâches) : 15 passages complets, dont 14 verts (bash 5 : 5 sur 5 ; bash 3.2 : 4 sur 5, puis 5 sur 5 de suite) ; le rouge, une fois au scénario 12 : un client de la latence, Bruno, perdu juste après l'intro (sa scène de jeu libérée, l'hôte le voit « parti » ; aucun `SCRIPT ERROR` avant), jamais reproduit sur 12 passages du scénario 12 seul. Sur la phase 16 seule, le scénario 12 seul a échoué 3 fois sur 12 (`les commandes de … : 63 sautées sur 1317`, au-delà des 3 % de la phase 16). Après les décisions du 27/09 (Task 6 : pastilles, répit, peintre), sur la copie finale : 14 passages verts sur 15 (bash 5 : 5 sur 5 ; bash 3.2 : 4 sur 5, et le scénario 11 seul 10 fois sur 10) ; le rouge, une fois au scénario 11 : « la gerbe de l'hôte étourdit le lion de Chloe, qui passe dessous » non obtenu en 15 s (`DELAI_ETAPE`). Cause non établie ; piste : un client étourdi par un ennemi reste désormais invulnérable 5,5 s au lieu de 3,5 s (le répit de 3 s), et l'hôte ne le pose dans sa gerbe qu'une fois cette immunité finie. Un rouge de ce genre ne se relance pas : il se rapporte (journaux gardés par `lancer.sh`), avec la question de savoir s'il vient de cette phase ; s'il revient, compter dans cette boucle les images où l'hôte vomit, où il est étourdi et où le client est invulnérable, avant de toucher au délai.

- [ ] **Step 4 : le scénario discrimine (preuves, sur une copie jetable, jamais commitées)**

Sur une copie du dépôt (`cp -R . "$TMPDIR/mut17"`, jamais le dépôt lui-même), chaque mutation à son tour, le test réseau lancé depuis la copie (`cd "$TMPDIR/mut17" && timeout -k 5 300 bash tests/reseau/lancer.sh`), puis la copie jetée :
- M3 (pas d'annonce des départs chez les clients) : dans `Scripts/Manche.gd`, remplacer le corps de `_recevoir_depart` par `pass`. Attendu (mesuré) : `❌ manche : l'hôte et Anna doivent finir avec la même empreinte` (scénario 9 : `hud=` porte « parti » chez l'hôte seulement), et de même au scénario 11 quand il va jusqu'à son empreinte.
- M2 (un client termine sa manche lui-même) : dans `Scripts/GameState.gd`, déplacer `regles.temps_ecoule_change()` avant `if not multiplayer.is_server():`. Attendu (mesuré) : `❌ la fin de l'hôte termine la manche de ce client, son chrono pris sur celui de l'hôte (10.005 s, écart 0.000 s)` chez le client dont le chrono était en avance (un des deux, selon la gigue) ; la preuve déterministe de ce cas est l'unitaire « sur un client, le chrono passé à zéro ne termine pas la manche » (Task 1), qui échoue à chaque fois sous cette mutation.

(L'ordre de la fin après le dernier territoire tient à la conception, un seul canal ordonné (Task 5) : sur localhost, même derrière le relais, une fin sur le canal 0 arrive presque toujours après ; ce scénario ne le discrimine pas, et n'y prétend pas.)

- [ ] **Step 5 : Commit**

```bash
git add tests/reseau/joueur.gd tests/reseau/lancer.sh
git commit -m "Test réseau : scénario 13, la fin au chrono de l'hôte sous latence simulée (1 hôte + 2 clients derrière le relais, manche de 10 s) : chaque client la reçoit, son chrono pris sur celui de l'hôte, le même HUD figé sur chaque poste (chrono, parts, rangs, tics), puis l'hôte sort par Échap ; l'empreinte de fin de manche compte le HUD (départs compris)

<ligne fournie par l'environnement>"
```

---

### Task 8 : ◉ le HUD à 6, une vraie manche à 4, la fin, l'anglais (non commitée)

**Files:**
- Create (scratchpad de l'exécutant, jamais dans le dépôt) : `<scratchpad>/captures_hud.gd`

**Interfaces:**
- Consumes : Tasks 1 à 6 (`Main.hud_bataille`, `Main._oublier_lion`, `Territoire.appliquer_changements`, les règles), et le mode `--captures` de `tests/bataille_test.gd` (phase 10 ter).
- Produces : 9 captures PNG en 2000×1125 dans `<scratchpad>/captures-17/` et `manche/`, les mêmes réduites à la fenêtre par défaut du multi (1400×788) dans `fenetre_1400x788/`, montrées à l'utilisateur.

- [ ] **Step 1 : le script**

Créer `<scratchpad>/captures_hud.gd` :

```gdscript
extends SceneTree
## ◉ HUD de bataille (phase 17, non commité) : godot --path <dépôt> --rendering-driver opengl3 --script <ce fichier> -- --dossier=<dossier>
## Rendu réel (pas headless), une bataille locale (ce poste est l'hôte, le joueur 1 est « TOI ») ; les
## ennemis sont écartés, scores, crans, gerbe XXL, étourdissement et départ posés à la main.

var dossier := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dossier="):
			dossier = arg.trim_prefix("--dossier=")
	call_deferred("_run")


func _attendre(secondes: float) -> void:
	await create_timer(secondes).timeout


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


func _poser_lions(main: Node, places: Array) -> void:
	for i in range(main.lions.size()):
		var l: Node2D = main.lions[i]
		l.global_position = places[i]
		l.deplacement.vitesse = Vector2.ZERO
		l.deplacement.recul = Vector2.ZERO


func _run() -> void:
	if dossier.is_empty():
		printerr("--dossier=<chemin> manquant")
		quit(1)
		return
	var params: Node = root.get_node("Parametres")
	var gs: Node = root.get_node("GameState")
	params.definir_langue("fr")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1400, 788))
	var pseudos := ["Clément", "WWWWWWWWWWWW", "Zoé", "Bob", "Léa-Marie 2", "Max"]
	var main := await _charger(6, pseudos, 1)
	var t: Territoire = main.ville.territoire
	_poser_lions(main, [Vector2(150, 520), Vector2(620, 600), Vector2(700, 600), Vector2(1250, 450), Vector2(1600, 300), Vector2(1864, 700)])
	await _attendre(0.3)
	await _shot("01_depart_a_6")

	# En jeu : des parts de la ville, des crans, une gerbe XXL, un étourdi, un parti ; deux lions côte à côte
	_poser_scores(t, [260, 410, 180, 90, 410, 30])
	for i in range(3):
		gs.joueurs[0].gagner_cran()
	for i in range(6):
		gs.joueurs[1].gagner_cran()
	gs.joueurs[4].gagner_cran()
	gs.regles.etoile_ramassee(gs.joueurs[0])
	gs.regles.lion_touche_par_ennemi(gs.joueurs[3], Vector2.INF)
	main.hud_bataille.marquer_parti(5)
	var parti: Node = main.lions[5]
	main._oublier_lion(parti)  # comme un départ en réseau : son lion disparaît
	parti.queue_free()
	gs.temps_ecoule = 41.2
	await _attendre(0.4)
	_poser_lions(main, [Vector2(150, 520), Vector2(620, 600), Vector2(712, 600), Vector2(1250, 450), Vector2(1600, 300)])
	await _attendre(0.1)
	await _shot("02_en_jeu_a_6")

	# Les dix dernières secondes : le chrono rouge
	gs.temps_ecoule = 84.35
	await _attendre(0.2)
	await _shot("03_dix_dernieres_secondes")

	# La fin de manche au chrono : le panneau de fin
	gs.temps_ecoule = 89.9
	while gs.partie_en_cours:
		await process_frame
	await _attendre(0.3)
	await _shot("04_fin_de_manche")
	paused = false

	# À deux, ex æquo, en anglais
	params.definir_langue("en")
	main = await _charger(2, ["Anna", "Bruno"], 0)
	t = main.ville.territoire
	_poser_lions(main, [Vector2(0, 500), Vector2(95, 500)])
	_poser_scores(t, [300, 300])
	gs.temps_ecoule = 60.0
	await _attendre(0.3)
	await _shot("05_egalite_a_2_anglais")
	gs.temps_ecoule = 89.9
	while gs.partie_en_cours:
		await process_frame
	await _attendre(0.3)
	await _shot("06_fin_egalite_anglais")
	paused = false
	current_scene.free()
	params.definir_langue("fr")
	gs.configurer_solo()
	quit(0)
```

- [ ] **Step 2 : les captures**

Run (deux fenêtres s'ouvrent l'une après l'autre, le temps des scripts) :

```bash
export PATH="/opt/homebrew/bin:$PATH"; S=<scratchpad>; rm -rf $S/captures-17; mkdir -p $S/captures-17/manche
timeout -k 5 120 godot --path . --rendering-driver opengl3 --script $S/captures_hud.gd -- --dossier=$S/captures-17 > "$TMPDIR/c1.log" 2>&1; echo "code $?"
timeout -k 5 300 godot --path . --rendering-driver opengl3 --fixed-fps 60 --script tests/bataille_test.gd -- --captures=$S/captures-17/manche > "$TMPDIR/c2.log" 2>&1; echo "code $?"
grep -hE "SCRIPT ERROR|❌|== " "$TMPDIR/c1.log" "$TMPDIR/c2.log"; mkdir -p $S/captures-17/fenetre_1400x788
for f in $S/captures-17/*.png $S/captures-17/manche/*.png; do sips -Z 1400 "$f" --out $S/captures-17/fenetre_1400x788/$(basename "$f") > /dev/null; done
ls $S/captures-17 $S/captures-17/manche $S/captures-17/fenetre_1400x788
```

Expected (mesuré) : deux `code 0`, aucune `SCRIPT ERROR` ni `❌`, `== 0 échec(s) ==` pour la bataille ; `01_depart_a_6.png` … `06_fin_egalite_anglais.png`, `manche/bataille_1.png` à `_3.png` (5, 45 et 88 s de la manche pilotée à 4), et leurs réductions.

- [ ] **Step 3 : regarder, puis montrer à l'utilisateur**

Vérifier sur les images (constaté en préparant le plan) :
- `01_depart_a_6` : six vignettes, trois de chaque côté du chrono « 1:30 », 0 % partout (personne ne possède rien), ni rang ni couronne ; celle de Clément (ce poste) à bordure épaisse et « TOI » ; « WWWWWWWWWWWW » entier dans sa vignette ; au-dessus des lions bleu et jaune, côte à côte, « WWWWWWWWWWWW » et « Zoé » écartés sans se recouvrir ;
- `02_en_jeu_a_6` (**◉ HUD à 6**) : les parts des cellules peintes (19, 30, 13, 6, 30, 2 : 100 % à elles toutes), les rangs (« 1er » en jaune pour les deux ex æquo), la couronne posée de travers sur la tête de leur lion (lisible à 2000 et à 1400 px de large), les crans en points, « ★ XXL 8 s » chez Clément, « ★ ÉTOURDI » chez Bob (et ses étoiles), Max parti en grisé (« PARTI », sa part gardée), son lion disparu ;
- `03_dix_dernieres_secondes` : le chrono rouge, « 0:06 » ;
- `04_fin_de_manche` : « 0:00 » rouge, les parts et les couronnes figées, le panneau « FIN DE LA MANCHE ! », « Égalité : WWWWWWWWWWWW, Léa-Marie 2 ! », le bouton « Quitter la partie » et « Échap : quitter la partie » ;
- `05_egalite_a_2_anglais` et `06_fin_egalite_anglais` : à deux, une vignette de chaque côté, « YOU », « 50 % » et « 1st » ex æquo, deux couronnes, « TIME'S UP! », « Tie: Anna, Bruno! » ; les deux pseudos côte à côte contre le bord gauche ;
- `manche/bataille_1` à `_3` : une vraie manche à 4 (pilote du test) : les parts qui bougent (100 % à elles toutes), la couronne qui change de lion, plusieurs pastilles à la fois (rythme de la Task 6 : à 45 s, les quatre lions ont déjà 7 crans), « 0:02 » rouge sur la troisième ;
- `fenetre_1400x788/*` : les mêmes à la taille de la fenêtre par défaut du multi : pseudos et rangs encore lisibles (le texte le plus petit, 16 px, y fait 11 px).

Montrer au moins `02_en_jeu_a_6`, `04_fin_de_manche`, `manche/bataille_3` et leur version 1400×788 à l'utilisateur, avec les choix visuels à trancher (voir le compte rendu de la phase : la couronne de travers, sa taille et sa place ; la taille des vignettes ; le panneau de fin intérimaire ; le rythme des pastilles, généreux avec un pilote qui court à chacune), **et lui proposer de rejouer à la main** (une bataille réseau à deux fenêtres, `godot --path .` deux fois et le port 7777, ou l'`.exe` de la CI sur sa LAN). Rien à commiter.

---

### Task 9 : feuille de route et spec

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`

**Interfaces:**
- Consumes : Tasks 1 à 8, Écarts 1 à 15 ; la feuille de route telle que la phase 16 l'a laissée.
- Produces : lignes 17 et 17 bis faites ; plus aucun point de vigilance « phase 17 » ni « phase 17 bis » ouvert (chacun résolu ; le rythme des pastilles et le peintre, réglés en phase 17 par décision de l'utilisateur du 27/09, gardent une note : les revoir à l'essai LAN de la phase 19) ; points de la phase 18 mis à jour (la fin décidée par l'hôte existe, l'état final des lions et la prédiction y restent) ; nouveaux points (la sortie intérimaire, `Manche.finie` et `duree_manche` pour une manche relancée, l'essai LAN à 4-6) ; spec §2, §3.1, §4, §5, §8, §10 à jour.

- [ ] **Step 1 : la feuille de route**

1a. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
| 17 | **HUD de bataille** : vignettes, couronne, chrono de 90 s, tic, musique sur le temps restant. | ➕ `Scenes/HUDBataille.tscn` ➕ `Scripts/HUDBataille.gd` ✏️ `Scripts/Audio.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `Assets/Traductions/traductions.csv` | ◉ HUD à 6 |
| 17 bis | **Sons de bataille** : « boing » des chocs entre lions (spec §5), synthétisé comme les autres effets. | ✏️ `tools/generer_sons.py` ➕ `Assets/Sons/boing.wav` ✏️ `Scripts/Audio.gd` ✏️ `Scripts/Lion.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
```

par :

```text
| 17 | **HUD de bataille, fin au chrono et sons** (17 et 17 bis réunies) : HUD à part du solo (une vignette par joueur dans l'ordre des index : pseudo, lion teint et couronné de travers pour chaque meneur ex æquo compris, part des cellules peintes (100 % à eux tous), rang, crans en points, gerbe XXL décomptée par le HUD, étourdissement, départ en grisé ; celle de ce poste mise en évidence ; chrono de 90 s rouge et tic dans les 10 dernières secondes) ; la manche finie au chrono de l'hôte seul, sa fin (chrono, scores) envoyée à chaque client après ses derniers tampons et son territoire, les départs annoncés ; panneau de fin et sortie (Échap : le titre) en attendant les Résultats ; musique au tiers du temps de la manche ; pseudos des lions écartés sans se chevaucher, dans l'écran (`PlacementPseudos`) ; rythme de la manche à 4-6 (pastilles à plusieurs, toutes les 4 s, qui expirent, loin du centre des lions ; 3 s de répit après un ennemi, pause du peintre doublée) ; sons (« boing » de chaque choc sur chaque poste, étourdissement, gong, tic, annonce du peintre chez les clients, boucle du vomi du seul lion local) ; scénario 13 du test réseau (fin au chrono sous latence simulée) et HUD dans l'empreinte ; version 0.17. | ➕ `Scenes/HUDBataille.tscn` ➕ `Scripts/HUDBataille.gd` ➕ `Scripts/PlacementPseudos.gd` ➕ `Assets/Sons/boing.wav` `tic.wav` `fin.wav` `etourdi.wav` ✏️ `Scripts/Regles.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `Scripts/GameState.gd` ✏️ `Scripts/Audio.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scripts/PareChocs.gd` ✏️ `Scripts/Boss.gd` ✏️ `Scenes/Boss.tscn` ✏️ `Scripts/Main.gd` ✏️ `Scripts/Manche.gd` ✏️ `Scripts/Spawner.gd` ✏️ `tools/generer_sons.py` ✏️ `Assets/Traductions/traductions.csv` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/bataille_test.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | ◉ HUD à 6, suites vertes 5 fois, test réseau vert 5 fois (bash 3.2 et 5) |
| 17 bis | (réunie avec la 17, même PR) | | |
```

1b. Remplacer :

```text
- **phase 17** (rythme de la manche) : le Spawner fait arriver une pastille à la fois, 6 s après le
  départ de la précédente (phase 10 bis) ; une pastille que personne ne ramasse bloque la suivante,
  comme en solo. À revoir en jeu à 4-6 joueurs (délai propre à la bataille dans les règles, durée
  de vie des pastilles). La distance aux lions (`distance_min_du_lion`) se mesure depuis
  `global_position` (coin du sprite, à ~95 px du centre du corps) et, après dix essais ratés, la
  dernière position est gardée même collée à un lion : en bataille seulement (le solo ne change
  pas), mesurer depuis `global_position + CENTRE` et garder le plus éloigné des dix candidats ;
- **phase 17** : une bataille finie se fige sans issue (arbre en pause, pas d'overlay, Échap
  inactif car `partie_en_cours` est faux). Sans conséquence tant que rien ne termine une bataille ;
  dès que le chrono appelle `terminer_partie`, garder une sortie jusqu'à l'écran Résultats de la
  phase 18 (Échap permis une fois la manche finie, retour au salon ou au titre), ou livrer 17 et 18
  ensemble ;
- **phase 17** (HUD) : les étiquettes de pseudo se chevauchent quand deux lions se touchent (vu sur
  les captures de la phase 10 ter, ◉ manche à 4 : « Joueur 3Joueur 4 » illisible) ; les décaler ou
  les empiler verticalement, ou estomper celle du lion le plus bas ;
- **phase 17** (HUD, étiquettes ; réaffecté par la phase 13, dont l'aperçu n'est pas un `Lion`) :
  l'étiquette de pseudo au-dessus du lion en manche est centrée (`offset_left -42 … offset_right
  178`) sur un lion borné à `x ∈ [0, 2000 - sprite_w]` ; un pseudo de 12 caractères larges la rend
  plus large que ses 220 px et elle déborde des deux côtés, donc sort de l'écran quand le lion est
  collé à un bord. L'hôte coupe tout pseudo à `Reseau.PSEUDO_MAX` (12, phase 11), l'écran Réseau
  et les cartes du salon les tiennent (phases 12 bis et 13 : « WWWWWWWWWWWW » à 24 px dans une
  carte de 310 px) : clamper l'abscisse de l'étiquette dans l'écran, avec le décalage des
  étiquettes qui se chevauchent (point ci-dessus), et le vérifier sur capture aux deux bords ;
```

par :

```text
- (résolu en phase 17, décision de l'utilisateur du 27/09 ; à revoir à l'essai LAN, phase 19) rythme
  de la manche : en bataille, les pastilles arrivent à plusieurs (`Regles.pastilles_en_meme_temps` :
  2 de 2 à 3 joueurs, 3 de 4 à 6), une toutes les 4 s sous ce plafond (`delai_entre_pastilles`, 6 s en
  solo), et une pastille que personne ne ramasse expire au bout de 12 s (`duree_de_vie_pastille`) : elle
  ne bloque plus les autres ; chacune naît loin du **centre** de chaque lion
  (`pastilles_loin_des_lions`) et, si aucun des dix essais n'est à `distance_min_du_lion` de tous, au
  plus loin des dix. Le solo ne change pas (une à la fois, 6 s après le départ de la précédente, coin
  du lion, dernier essai ; sa trace non plus). Réglé sans essai à 4-6 (justifications dans
  `ReglesBataille`) : la manche pilotée de `tests/bataille_test.gd` finit avec 7 crans pour chacun des
  4 lions (le pilote court à chaque pastille) ; **phase 19** : le juger en vrai ;
- (résolu en phase 17) une bataille finie garde une sortie : le panneau de fin du HUD de la bataille
  (« FIN DE LA MANCHE ! », le gagnant ou les ex æquo) et Échap, Start ou le bouton : le titre, qui
  quitte le réseau (l'hôte qui sort ramène ses clients au titre, « L'hôte a quitté la partie ») ; le
  menu local se ferme et se tait à la fin ; le bouton ne prend jamais le focus (Espace tenu au gong ne
  quitte pas). **Phase 18** : l'écran Résultats remplace ce panneau et cette sortie (retour au salon) ;
- (résolu en phase 17) les étiquettes de pseudo de deux lions qui se touchent ne se chevauchent plus
  et restent dans l'écran, aux deux bords (`PlacementPseudos`, appliqué par `Main._placer_pseudos` à
  chaque image : les textes qui se recouvrent se serrent en un bloc centré sur leurs places voulues,
  ramené dans l'écran ; vérifié par `tests/bataille_test.gd`, bord gauche et bord droit, avec
  « WWWWWWWWWWWW », et sur les captures du ◉ HUD à 6). Elles ne glissent qu'à l'horizontale : leur
  hauteur, que borne `Lion._marge_haute()`, ne change jamais (la physique et la trace non plus) ;
```

1c. Remplacer :

```text
  libération) ; le peintre applique le côté reçu (`Boss.cote`, setter). **Phase 17 bis** :
  l'annonce du peintre (`Audio.jouer("boss")`, dans `Boss._changer_etat` de l'hôte) ne s'entend
  que chez l'hôte : la faire entendre aux clients (réplique de `Boss.etat`, ou RPC de la manche) ;
```

par :

```text
  libération) ; le peintre applique le côté reçu (`Boss.cote`, setter). (Résolu en phase 17) son
  état est répliqué (`Boss.etat`, à chaque changement) : son annonce s'entend aussi chez chaque client
  (le setter de la réplique joue `Audio.jouer("boss")`) ;
```

1d. Remplacer :

```text
- **prochaine phase qui ajoute un scénario au test réseau** (temps de la CI, phase 16) : le test
  réseau prend ~150 s sur ce Mac, dont ~52 s pour le scénario 11 (`DUREE11=45`, décision de
  l'utilisateur) et ~38 s pour le scénario 12 (la manche sous latence simulée, `DUREE12=20`), sous le
  `timeout 300` du pas « Test réseau » de `ci.yml` ; le banc de la prédiction (`tests/prediction_test.gd`)
  a son propre pas, ~1 s. Au-delà de ~200 s, raccourcir un scénario ou relever ce `timeout` ;
- **phase 17** (le peintre en bataille, vu en phase 15) : sur le Village, le peintre (421 px de haut,
  posé sur les toits) couvre toute la bande de peinture ; sans fuir, un joueur est étourdi sans
  relâche (le programme du scénario 11 sans fuite, mesuré à 90 s : 21 % de la ville peinte en 90 s
  à 4, contre 58 à 66 % en fuyant). À régler avec le rythme de la manche (délai propre à la
  bataille, taille ou fréquence du peintre en bataille) ;
```

par :

```text
- **prochaine phase qui ajoute un scénario au test réseau** (temps de la CI, phases 16 et 17) : le
  test réseau prend ~157 s sur ce Mac (140 s avant la phase 17), dont ~52 s pour le scénario 11
  (`DUREE11=45`, décision de l'utilisateur), ~38 s pour le scénario 12 (la manche sous latence
  simulée, `DUREE12=20`) et ~17 s pour le scénario 13 (la fin au chrono, `DUREE13=10`), sous le
  `timeout 300` du pas « Test réseau » de `ci.yml` ; le banc de la prédiction (`tests/prediction_test.gd`)
  a son propre pas, ~1 s. Au-delà de ~200 s, raccourcir un scénario ou relever ce `timeout` ;
- (résolu en phase 17, décision de l'utilisateur du 27/09 ; à revoir à l'essai LAN, phase 19) le
  peintre en bataille (vu en phase 15) : sur le Village, il couvre toute la bande de peinture, et un
  joueur qui ne fuyait pas était étourdi sans relâche (le programme du scénario 11 sans fuite, mesuré à
  90 s : 21 % de la ville peinte à 4, contre 58 à 66 % en fuyant). En bataille, un étourdissement par
  un ennemi laisse 3 s de répit (`ReglesBataille.DUREE_REPIT_ENNEMI`, l'immunité ; 1 s après un vomi,
  inchangé) : à 350 px/s, plus de deux fois la largeur du peintre (442 px) ; et le peintre se repose
  deux fois plus longtemps entre deux passages (`Regles.facteur_repos_peintre`, 4 s au lieu de 2) : la
  bande est libre un tiers du temps au lieu d'un cinquième. **Phase 19** : le juger en vrai ;
```

1e. Remplacer :

```text
  le titre. **Phase 17** : le joueur parti reste au classement en grisé (le `Joueur` n'a pas encore
  d'état « parti » ; son lion disparu le dit) ;
```

par :

```text
  le titre. (Résolu en phase 17) le joueur parti reste au classement en grisé sur chaque poste : l'hôte
  annonce chaque départ (`Manche._recevoir_depart`, ceux d'avant la barrière, un exclu, en la
  passant ; `Manche.depart_vu` sur chaque poste), le HUD le grise (`HUDBataille.marquer_parti`) ;
```

1f. Remplacer :

```text
  minuteries des joueurs que sur l'hôte. **Phase 17** : sur un client, `Joueur.bonus_restant`
  reste celui reçu au début de la gerbe XXL (seule sa fin arrive) : le HUD de bataille décompte
  lui-même, ou ne montre pas les secondes ;
```

par :

```text
  minuteries des joueurs que sur l'hôte. (Résolu en phase 17) sur un client, `Joueur.bonus_restant`
  reste celui reçu au début de la gerbe XXL (seule sa fin arrive) : le HUD de la bataille décompte
  lui-même ses secondes (`HUDBataille.xxl_restant`), que la fin reçue efface ;
```

1f bis. Remplacer :

```text
- **phase 17** (HUD) : la palette de bataille est réglée pour la deutéranopie depuis la phase 11 bis
```

par :

```text
- (résolu en phase 17 : les vignettes du HUD portent le pseudo, la part et le rang, pas seulement la
  couleur) la palette de bataille est réglée pour la deutéranopie depuis la phase 11 bis
```

1g. Remplacer :

```text
- **phase 17** : le score d'un joueur se lit sur le territoire de la ville
  (`ville.territoire.cellules_de(joueur.index)`, sur `ville.territoire.nb_peignables` pour un
  pourcentage, comme la manche de `tests/bataille_test.gd`) ; il n'y a pas de `Joueur.cellules`
  (spec §3.1). La couverture du solo reste mesurée en bataille (`GameState.progression`) : le
  peintre et la difficulté des ennemis suivent `Regles.avancement()` depuis la phase 10 bis (le
  temps de la manche en bataille) ; la musique (`Main._on_progression_changee`, encore sur la
  couverture) et le HUD (encore celui du solo en bataille : cœurs, arc-en-ciel, chrono qui monte)
  sont à la phase 17. `int(regles.avancement() × 3)` donne les couches de la spec §8 (arpèges à
  30 s écoulées, mélodie à 60 s), mais au rythme du chrono, pas des mesures de couverture ;
```

par :

```text
- (résolu en phase 17) le score d'un joueur se lit sur le territoire de la ville
  (`ville.territoire.cellules_de(joueur.index)`, sur `ville.territoire.nb_peignables` pour un
  pourcentage) : c'est ce que lit le HUD de la bataille, qui remplace en bataille celui du solo ; il
  n'y a pas de `Joueur.cellules` (spec §3.1). La musique suit `Regles.intensite_musique()`,
  `int(avancement() × 3)` dans les deux modes (la formule du solo ; en bataille, arpèges à 30 s de
  jeu, mélodie à 60 s), à chaque image en bataille (`Main._process`) ;
```

1h. Remplacer :

```text
  chargement (`Reseau.scenes_chargees`, vidée par `lancer_manche`) suppose aussi une scène
  rechargée ;
```

par :

```text
  chargement (`Reseau.scenes_chargees`, vidée par `lancer_manche`) suppose aussi une scène
  rechargée. Depuis la phase 17, la manche d'une scène gardée resterait aussi `finie` (elle
  n'enverrait plus de fin, un client plus de commandes), le HUD figé sur son panneau de fin : une
  scène rechargée règle tout cela d'un coup ;
```

1i. Remplacer :

```text
- **phase 17 bis** : jouer le « boing » dans `PareChocs._on_area_entered` (à côté de `Lion.secouer`), sur chaque machine
  (pas seulement l'hôte) : c'est ce qui le rend immédiat pour le joueur local (spec §4.1) ;
- **prochaine phase qui touche `Scripts/Regles.gd`** : `Titre._ready` applique aussi
  `taille_ecran()` (retour au titre en solo 2000×648) : étendre le docstring de
  `Regles.taille_ecran()` ("appliquée par `Main` en entrant dans la scène de jeu") avec "et par le
  titre" ;
```

par :

```text
- (résolu en phase 17) le « boing » part de `PareChocs._on_area_entered`, à côté de `Lion.secouer`,
  sur chaque poste (`Audio.jouer_boing` : un par choc, les deux pare-chocs le signalant ; 9 dB plus
  bas entre deux autres lions que celui de ce poste) : immédiat pour le joueur local (spec §4.1) ;
- (résolu, constaté en phase 17) le docstring de `Regles.taille_ecran()` dit déjà « appliquée par
  `Main` en entrant dans la scène de jeu, et par le titre (qui remet le solo) » ;
```

1j. Remplacer :

```text
  désormais « version différente ». Chaque phase qui change les RPC (14, 16, 18) doit encore
  l'augmenter (« 0.14 », « 0.16 »…) ; sinon un `.exe` de CI (Windows) et une version locale (Mac) de phases
```

par :

```text
  désormais « version différente ». Chaque phase qui change les RPC (14, 16, 17, 18) doit encore
  l'augmenter (« 0.14 », « 0.16 », « 0.17 »…) ; sinon un `.exe` de CI (Windows) et une version locale (Mac) de phases
```

1k. Remplacer :

```text
- **phase 17 bis** (sons de bataille, depuis la phase 8 bis) : chaque lion, local ou non, appelle
  `Audio.demarrer_vomi` / `arreter_vomi` : un lion qui arrête de vomir coupe la boucle du joueur
  local ; ne la jouer que pour le lion de `joueur_local()` (et un son spatialisé ou plus discret
  pour les autres) ;
```

par :

```text
- (résolu en phase 17) la boucle du vomi n'est qu'au lion de ce poste (`Lion.est_local()`) : un autre
  lion qui arrête de vomir ne la coupe plus ; les autres lions ne jouent rien en vomissant (une boucle
  spatialisée par lion attend que l'essai à 4-6 la réclame, phase 19) ;
```

1l. Remplacer :

```text
- **phase 17** : la fin de manche n'existe pas encore en réseau : le test réseau fige la manche de
  l'hôte par `GameState.terminer_partie` ; les clients ne le savent pas (le chrono de la phase 17
  devra l'annoncer, et `Manche` diffuse déjà ses derniers tampons et son territoire l'arbre en
  pause) ;
- **phase 18** (vu en phase 16, désync-report.md du scénario 11) : la fin de manche devra être une
  décision de l'hôte, appliquée à réception chez chaque client, qui porte l'état final de chaque
  lion. Par conception, la prédiction d'un client ne distingue pas un hôte figé d'un silence Wi-Fi et
```

par :

```text
- (résolu en phase 17) la fin de manche existe en réseau : chez l'hôte, son chrono (ou le test réseau
  qui fige sa manche) appelle `terminer_partie` ; `Manche._sur_fin_de_partie` envoie ses derniers
  tampons, son territoire, puis la fin (`_recevoir_fin_manche` : son chrono et ses scores), sur le même
  canal fiable ordonné ; chaque client prend le chrono de l'hôte et termine sa manche (tout se fige,
  le HUD montre la fin), puis n'envoie plus de commandes (scénario 13 du test réseau) ;
- **phase 18** (vu en phase 16, désync-report.md du scénario 11 ; la décision de l'hôte existe depuis
  la phase 17, `Manche._recevoir_fin_manche`) : la fin de manche devra aussi porter l'état final de
  chaque lion. Par conception, la prédiction d'un client ne distingue pas un hôte figé d'un silence Wi-Fi et
```

1m. Remplacer :

```text
- **phase 17** (chrono de bataille en réseau, précision de la revue finale 14, complète le point
  ci-dessus sur la fin de manche) : à 90 s, le mode intérimaire reste sûr sans le chrono
  (`ReglesBataille.avancement()` dépasse 1, mais le Spawner et le peintre le bornent par `clamp` ;
  aucune fin n'est émise d'un seul côté, aucun écran solo ne s'ouvre) — à dire aux testeurs d'un
  essai LAN avant la phase 17. La fin devra être décidée par l'hôte et envoyée par RPC ; le chrono de
  chaque client démarre à la fin de **sa propre** intro, décalé de la latence : il ne doit rien
  terminer lui-même ;
```

par :

```text
- (résolu en phase 17) chrono de bataille en réseau : la fin est décidée par l'hôte seul
  (`ReglesBataille.temps_ecoule_change`, appelé par `GameState._process` chez l'hôte) et envoyée par
  RPC ; le chrono de chaque client, parti à la fin de **sa propre** intro et décalé de la latence, ne
  termine jamais rien lui-même (`tests/unitaires.gd`) : à la fin reçue, il prend celui de l'hôte
  (mesuré sous le relais, 80/40/5 : écart de 0,007 à 0,019 s) ;
```

1n. Remplacer :

```text
  arrière après un silence plus long (≥ 500 ms), ou en le rendant inutile par le message de fin de
  manche de cette phase (les lions distants reçoivent alors directement leur état final) ;
- **phase 18** (M5 de la revue finale 16) : la décision de fin de manche devra aussi arrêter
```

par :

```text
  arrière après un silence plus long (≥ 500 ms), ou en le rendant inutile par le message de fin de
  manche (`Manche._recevoir_fin_manche`, phase 17), une fois qu'il portera l'état final des lions
  distants ;
- **phase 18** (M5 de la revue finale 16) : la décision de fin de manche (phase 17 : un client se fige
  à sa réception, l'arbre en pause, donc sa prédiction aussi) devra aussi arrêter
```

1o. Remplacer :

```text
- **phase 17** (M5 de la revue finale 16) : tout ce que le HUD ou des effets accrochent au lion local
  doit suivre sa position affichée (`lion.position + lion.visuel.position`), pas son corps seul (le
  décalage de correction, phase 16, ne bouge que l'affichage) ;
```

par :

```text
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
  des vignettes dans la fenêtre par défaut, 1400×788, et en plein écran 1080p ; la couronne posée de travers sur le lion des meneurs, les parts des cellules peintes), le volume des
  sons neufs (« boing », tic, gong, étourdissement ; `Audio.DB_AUTRES`), et surtout le rythme réglé à
  l'aveugle en phase 17 (plafond et délai des pastilles, leur durée de vie, le répit après un ennemi, la
  pause du peintre : constantes de `ReglesBataille`).
```

- [ ] **Step 2 : la spec**

2a. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```text
| Fin de manche | **Chrono de 90 s**, personne n'est éliminé. Le plus de cellules gagne, ex æquo possibles. |
```

par :

```text
| Fin de manche | **Chrono de 90 s**, personne n'est éliminé. Le plus de cellules gagne, ex æquo possibles. Seul le chrono de l'hôte termine la manche ; chaque client reçoit sa fin (phase 17). |
```

2b. Remplacer :

```text
| `Manche` (nœud de la scène de jeu, phase 14) | En réseau : barrière de chargement (exclusion d'un absent), commandes des clients, tampons et territoire diffusés, réactions des joueurs, départs. Hors réseau, inerte. | `Reseau`, `Ville`, `Joueur` |
| `Peinture` (logique pure, phase 14) | Jeux de tampons tirés de leur clé, tirage d'un tampon par sa graine, format réseau des tampons : chaque poste dessine les mêmes. | rien |
```

par :

```text
| `Manche` (nœud de la scène de jeu, phase 14) | En réseau : barrière de chargement (exclusion d'un absent), commandes des clients, tampons et territoire diffusés, réactions des joueurs, départs (annoncés par l'hôte à chaque client depuis la phase 17), fin de manche de l'hôte envoyée après ses derniers tampons et son territoire (phase 17). Hors réseau, inerte. | `Reseau`, `Ville`, `Joueur` |
| `Peinture` (logique pure, phase 14) | Jeux de tampons tirés de leur clé, tirage d'un tampon par sa graine, format réseau des tampons : chaque poste dessine les mêmes. | rien |
| `HUDBataille` (scène, phase 17) | Le HUD d'une bataille, posé par `Main` à la place de celui du solo : vignettes, chrono, panneau de fin et sa sortie (§8). Lit le territoire de la ville, le chrono et les signaux des joueurs sur chaque poste. | `Ville`, `Joueur`, `Regles` |
| `PlacementPseudos` (logique pure, phase 17) | Écarte à l'horizontale les pseudos des lions qui se recouvrent et les garde dans l'écran. | rien |
```

2c. Remplacer :

```text
  - client perdu en manche : son lion disparaît, ses cellules restent, il reste au classement en
    grisé ;
```

par :

```text
  - client perdu en manche : son lion disparaît, ses cellules restent, il reste au classement en
    grisé (l'hôte annonce son départ à chaque client, phase 17 ; un exclu de la barrière aussi) ;
```

2d. Remplacer :

```text
  des deux côtés proportionnelle à la vitesse d'approche relative, son « boing », petite secousse
```

par :

```text
  des deux côtés proportionnelle à la vitesse d'approche relative, son « boing » (sur chaque poste, un
  par choc, plus discret entre deux autres lions que celui de ce poste), petite secousse
```

2e. Remplacer :

```text
| Pastilles de couleur | Donnent **+1 cran de gerbe** (1 à 7 crans ; rayon de peinture de 16 px au premier cran, 5 px de plus par cran, 46 px au septième). Départ à 1 cran. Premier arrivé, premier servi. En solo, chaque couleur débloquée donne aussi un cran : les rayons du solo ne changent pas. |
```

par :

```text
| Pastilles de couleur | Donnent **+1 cran de gerbe** (1 à 7 crans ; rayon de peinture de 16 px au premier cran, 5 px de plus par cran, 46 px au septième). Départ à 1 cran. Premier arrivé, premier servi. En solo, chaque couleur débloquée donne aussi un cran : les rayons du solo ne changent pas. En bataille (phase 17, réglé sans essai à 4-6) : 2 à la fois de 2 à 3 joueurs, 3 de 4 à 6, une toutes les 4 s sous ce plafond, qui expire au bout de 12 s si personne ne la prend, loin du centre des lions ; en solo, une à la fois, 6 s après le départ de la précédente. |
```

2f. Remplacer :

```text
| Ennemis (soucoupe, coccinelle, peintre) | Étourdissent **2,5 s** (sans barbouillage), puis 1 s d'immunité. |
```

par :

```text
| Ennemis (soucoupe, coccinelle, peintre) | Étourdissent **2,5 s** (sans barbouillage), puis **3 s de répit** (l'immunité : le temps de fuir le peintre, qui couvre la bande de peinture ; phase 17). Le peintre se repose deux fois plus longtemps qu'en solo entre deux passages. |
```

2g. Remplacer :

```text
  d'invulnérabilité du solo : `Joueur.etourdir` la règle sur la durée de l'étourdissement plus
  1 s, et les règles ignorent un joueur étourdi ou invulnérable (le peintre et la gerbe signalent
  leur contact à chaque frame).
```

par :

```text
  d'invulnérabilité du solo : `Joueur.etourdir` la règle sur la durée de l'étourdissement plus
  1 s (3 s de répit après un ennemi en bataille, phase 17), et les règles ignorent un joueur
  étourdi ou invulnérable (le peintre et la gerbe signalent leur contact à chaque frame).
```

2h. Remplacer :

```text
- **HUD bataille** : 6 vignettes en ordre fixe (couleur, pseudo, % de la ville, crans en points),
  couronne sur le meneur, vignette locale mise en évidence. Chrono central, rouge avec tic sonore
  dans les 10 dernières secondes.
- **Musique** : les couches suivent le temps restant (arpèges à 60 s, mélodie à 30 s). Thème du
  peintre au Village.
```

par :

```text
- **HUD bataille** (phase 17, `HUDBataille`) : 6 vignettes au plus, en ordre fixe (celui des index),
  moitié de chaque côté du chrono : couleur (bordure, lion teint), pseudo (« Joueur n » sans pseudo),
  **part des cellules peintes** (les cellules du joueur sur toutes celles que possèdent les joueurs,
  en pourcents entiers qui font 100 à eux tous ; 0 % pour tous tant que personne ne possède rien ;
  décision de l'utilisateur du 27/09), **rang** (« 1er », « 2e »… ; ex æquo au même rang ; aucun sans
  cellule ; tiré des cellules, jamais des parts arrondies), couronne posée de travers sur la tête du
  lion de la vignette de chaque meneur, crans en points, gerbe XXL et ses secondes (décomptées par le HUD),
  étourdissement ; vignette locale mise en évidence (bordure épaisse, « TOI ») ; un joueur parti en
  grisé (« PARTI »). Le classement se lit sans la couleur (pseudo, part, rang). Chrono central, rouge
  avec tic sonore dans les 10 dernières secondes. Les pseudos au-dessus des lions ne se recouvrent
  jamais et restent dans l'écran (`PlacementPseudos`).
- **Musique** : les couches suivent le temps de la manche (arpèges à 60 s restantes, mélodie à 30 s :
  `int(avancement × 3)`, `Regles.intensite_musique`). Thème du peintre au Village.
- **Sons** (phase 17 bis) : « boing » des chocs (§5), étourdissement, tic, gong de fin sur chaque
  poste ; annonce du peintre aussi chez les clients ; la boucle du vomi n'est qu'au lion de ce poste.
```

2i. Remplacer :

```text
- **Fin** : à 0, tout se fige, l'hôte envoie les scores définitifs. **Écran Résultats** : podium
```

par :

```text
- **Fin** : à 0 chez l'hôte (son chrono seul décide), tout se fige ; l'hôte envoie à chaque client, après
  ses derniers tampons et son territoire sur le même canal fiable, la fin avec son chrono et ses scores
  définitifs : le client prend ce chrono et se fige (phase 17 ; l'état final de chaque lion viendra en
  phase 18). En attendant l'écran Résultats, un panneau de fin (« FIN DE LA MANCHE ! », le gagnant ou
  les ex æquo) et sa sortie (Échap, Start, bouton : le titre). **Écran Résultats** : podium
```

2j. Remplacer :

```text
- **Tests unitaires headless** (`tests/unitaires.gd`) : charge et vol de cellule, seuil de
  possession, attribution et conflits de couleurs, refus de version, sérialisation des événements
  de tampon.
```

par :

```text
- **Tests unitaires headless** (`tests/unitaires.gd`) : charge et vol de cellule, seuil de
  possession, attribution et conflits de couleurs, refus de version, sérialisation des événements
  de tampon ; depuis la phase 17, le chrono (affichage, fin chez l'hôte seulement), le classement ex
  æquo, les couches de musique et le placement des pseudos.
```

2k. Remplacer :

```text
  que par l'hôte (phase 18 : les envoyer aux clients). `DUREE11=45` (décision de l'utilisateur, pas
  90 s : marge CI sous le `timeout 300`).
```

par :

```text
  que par l'hôte (phase 18 : les envoyer aux clients). `DUREE11=45` (décision de l'utilisateur, pas
  90 s : marge CI sous le `timeout 300`). Depuis la phase 17 (scénario 13), la fin au chrono de l'hôte
  sous latence simulée : 1 hôte et 2 clients derrière le relais, une manche de 10 s ; chaque client
  reçoit la fin (son chrono pris sur celui de l'hôte, 0,25 s d'écart au plus), le même HUD figé sur
  chaque poste (chrono à 0:00, parts, rangs, tics), puis l'hôte sort par Échap et ses clients le voient
  partir ; l'empreinte de fin de manche des scénarios 9, 11 et 12 compte aussi le HUD (départs compris).
```

- [ ] **Step 3 : Commit**

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md
git commit -m "Feuille de route et spec : phases 17 et 17 bis faites (HUD de bataille, fin au chrono décidée par l'hôte et envoyée aux clients, sortie intérimaire, pseudos écartés, parts des cellules peintes et couronne sur le lion, rythme des pastilles et du peintre réglé à 4-6, sons de bataille, scénario 13, version 0.17) ; points de vigilance de la phase 17 résolus (rythme des pastilles et peintre à revoir à l'essai LAN, phase 19) ; points de la phase 18 mis à jour

<ligne fournie par l'environnement>"
```

- [ ] **Step 4 : la validation finale**

Run : les cinq suites 5 fois de suite (unitaires, smoke, bataille, banc, trace), puis le test réseau 5 fois sous bash 5 et 5 fois sous `/bin/bash`, sans relance, jamais deux à la fois.
Expected (mesuré en préparant le plan) : unitaires 383 ✅, smoke 389 ✅, bataille 100 ✅, banc 45 ✅, chaque fois `== 0 échec(s) ==` ; la trace `TRACE bataille 2492461451 TRACE solo 185311436 TRACE replique 3757044499` à chaque passage ; le test réseau vert dix fois (12 scénarios, 156 à 158 s). Aucun `SCRIPT ERROR`, `SHADER ERROR` ni `❌` dans aucun journal.
