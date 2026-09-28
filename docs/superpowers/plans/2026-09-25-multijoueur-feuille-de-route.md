# LeLion multi : feuille de route d'implémentation

**Spec :** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`

Le spec couvre plusieurs sous-systèmes (socle, bataille locale, réseau, prédiction, fin de manche,
livraison). Règle du projet (`CLAUDE.md`) : une phase se termine par les vérifications vertes et
attend une validation explicite avant la suivante ; jusqu'à la phase 12 bis, elle touchait au plus
5 fichiers, plafond levé par l'utilisateur à partir de la phase 13 (une phase reste d'un seul
tenant tant qu'elle est cohérente). Chaque phase a son propre plan détaillé, écrit juste avant son
exécution, contre le code réellement produit par la phase précédente :
`docs/superpowers/plans/2026-09-25-phase-NN-<objet>.md`.

## Vérification commune à toutes les phases

Il n'y a ni TypeScript ni ESLint : l'équivalent pour Godot est l'import headless (qui compile tous
les scripts) suivi des tests.

```sh
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-multi
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" && echo "ÉCHEC COMPILATION"
godot --headless --script tests/unitaires.gd     # à partir de la phase 1
godot --headless --script tests/smoke_test.gd
godot --headless --fixed-fps 60 --script tests/bataille_test.gd  # à partir de la phase 10 bis
bash tests/reseau/lancer.sh                                      # à partir de la phase 11
```

Les quatre derniers doivent finir sur `== 0 échec(s) ==` et un code de sortie 0 (chaque commande
Godot sous `timeout`, que `tests/reseau/lancer.sh` applique lui-même à chacun de ses processus).

Leur sortie ne doit contenir ni `SCRIPT ERROR` ni `SHADER ERROR` : en headless, le rendu factice
compile quand même les shaders et signale leurs erreurs sans changer le code de sortie.

## Phases

Légende : ➕ création, ✏️ modification. ◉ = contrôle visuel (captures) en fin de phase.

### A. Socle, solo identique (aucun changement visible)

| # | Objet | Fichiers | Sortie |
|---|---|---|---|
| 1 | **Joueur** : l'état par joueur (couleurs, vies, invulnérabilité, bonus) quitte `GameState` pour une ressource `Joueur`. `GameState` garde une façade transitoire. CI : tests unitaires, déploiement Pages retiré. | ➕ `Scripts/Joueur.gd` ✏️ `Scripts/GameState.gd` ➕ `tests/unitaires.gd` ✏️ `.github/workflows/ci.yml` ✏️ `tests/smoke_test.gd` (Step 0) | tests verts, CI verte |
| 2 | **Commandes et lion** : le lion lit un `Joueur` et une `Commandes` (sources `LOCALES` et `MANUELLES`). Le pilote de démo écrit dans des commandes manuelles. | ➕ `Scripts/Commandes.gd` ✏️ `tests/unitaires.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scripts/Pilote.gd` ✏️ `tests/smoke_test.gd` | tests verts |
| 3 | **Règles** : `Regles` (base, RefCounted) et `ReglesSolo` portent coup, cœur, pastilles, étoile et victoire, pour le joueur reçu. `GameState` détient `regles` et sa façade y délègue. | ➕ `Scripts/Regles.gd` ➕ `Scripts/ReglesSolo.gd` ✏️ `Scripts/GameState.gd` ✏️ `tests/unitaires.gd` | tests verts |
| 4 | **Ennemis et pastille de couleur vers les règles** : chacun signale le joueur du lion touché (`body.joueur`) aux règles. | ✏️ `Scripts/Soucoupe.gd` ✏️ `Scripts/Coccinelle.gd` ✏️ `Scripts/Boss.gd` ✏️ `Scripts/ColorPickup.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
| 5 | **Pastilles restantes et apparitions** : étoile et cœur passent par les règles (doublon `DUREE_BONUS` / `DUREE_ETOILE` retiré), le Spawner lit le joueur local. | ✏️ `Scripts/BonusPickup.gd` ✏️ `Scripts/CoeurPickup.gd` ✏️ `Scripts/ReglesSolo.gd` ✏️ `Scripts/Spawner.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
| 6 | **Abonnés** : HUD, écran de fin, audio et traceuse lisent le joueur local ou celui de leur lion, et ses signaux. | ✏️ `Scripts/HUD.gd` ✏️ `Scripts/GameOver.gd` ✏️ `Scripts/Audio.gd` ✏️ `Scripts/GerbeTraceuse.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
| 6 bis | **Fin de la façade** : `GameState` ne contient plus que l'état de partie. | ✏️ `Scripts/GameState.gd` ✏️ `Scripts/Main.gd` ✏️ `tests/screenshots.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/unitaires.gd` | tests verts |

### B. Bataille, d'abord hors réseau

| # | Objet | Fichiers | Sortie |
|---|---|---|---|
| 7 | **Teinte de la crinière** : masque déduit du sprite par le shader (teinte, valeur, saturation), uniformes de barbouillage prêts, pseudo au-dessus du lion ; le lion d'un joueur sans couleur (solo) n'a aucun matériau. Repli par rotation de teinte si le masque est laid. | ➕ `Shaders/Lion.gdshader` ✏️ `Scripts/Joueur.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scenes/Lion.tscn` ✏️ `tests/smoke_test.gd` | ◉ 6 lions teintés |
| 8 | **Règles et état de bataille** : `ReglesBataille` (étourdissement 1,5 s par le vomi, 2,5 s par un ennemi, puis 1 s d'immunité ; crans ; chocs comptés ; ni vies ni cœurs), `Joueur` (crans, étourdissement, nuances, statistiques ; l'immunité est l'invulnérabilité du solo), événements de vomi et de choc dans `Regles`, `GameState.configurer_solo()` / `configurer_bataille(n)`. | ✏️ `Scripts/Joueur.gd` ✏️ `Scripts/Regles.gd` ➕ `Scripts/ReglesBataille.gd` ✏️ `Scripts/GameState.gd` ✏️ `tests/unitaires.gd` | tests verts |
| 8 bis | **Lion de bataille** : rayon selon les crans (le solo gagne un cran par couleur), gerbe en 3 nuances, étourdissement (commandes ignorées, recul, barbouillage, étoiles, clignotement de l'immunité), 3 zones de contact sur la parabole, auto-tamponneuses, `class_name Lion`. | ✏️ `Scripts/ReglesSolo.gd` ✏️ `tests/unitaires.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scenes/Lion.tscn` ✏️ `tests/smoke_test.gd` | tests verts, ◉ lions étourdis |
| 8 ter | **Ennemis vers `body is Lion`** : base commune `Ennemi` des gestionnaires de contact des ennemis (garde hôte, `body is Lion`, origine du coup redéfinissable) ; le peintre garde ses deux chemins de contact (`body_entered` et contact continu hors repos). | ➕ `Scripts/Ennemi.gd` ✏️ `Scripts/Soucoupe.gd` ✏️ `Scripts/Coccinelle.gd` ✏️ `Scripts/Boss.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
| 9 | **Territoire, logique** : `Territoire` (charge, prise, vol, seuil de possession, scores par joueur, liste des cellules changées), réglé sur la couverture du solo ; règles : vols comptés (`vol_de_cellules`), partie au territoire (`compte_le_territoire`) ; `DUREE_ETOILE` et `_manche_en_cours()` montent dans la base `Regles`. | ➕ `Scripts/Territoire.gd` ✏️ `Scripts/Regles.gd` ✏️ `Scripts/ReglesSolo.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `tests/unitaires.gd` | tests verts |
| 9 bis | **Territoire dans la ville** : tampons en cache par jeu de couleurs (obligatoire), la ville tient le territoire en bataille et le tamponne sur l'hôte, la traceuse peint pour son joueur ; `DUREE_INVULNERABILITE` descend dans `ReglesSolo`. | ✏️ `Scripts/Ville.gd` ✏️ `Scripts/GerbeTraceuse.gd` ✏️ `Scripts/GameState.gd` ✏️ `Scripts/ReglesSolo.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
| 10 | **Règles du mode** : les règles donnent l'écran (16:9 en bataille), l'avancement de la partie (ville peinte en solo, temps de la manche en bataille) et ce qui peut apparaître (pastille, étoile, cœurs) ; `manche_en_cours()` publique ; vérification discriminante de la passe pleine vitesse. Découpage de l'ancienne phase 10 (15 fichiers) et mesures : plan de la phase 10. | ✏️ `Scripts/Regles.gd` ✏️ `Scripts/ReglesSolo.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `Scripts/Ville.gd` ✏️ `tests/unitaires.gd` | tests verts |
| 10 bis | **Scène de bataille locale en 16:9** : N lions (joueur et commandes avant l'ajout), écran, ciel et caméra calculés, apparitions par les règles et relatives au viewport, taille et vitesse du peintre. Test à 4 lions pilotés dans un seul processus (`--fixed-fps 60`), en CI. | ✏️ `Scripts/Main.gd` ✏️ `Scripts/Spawner.gd` ✏️ `Scripts/Boss.gd` ➕ `tests/bataille_test.gd` ✏️ `.github/workflows/ci.yml` | tests verts, CI verte |
| 10 ter | **Réglage de la manche à 4** : empreinte du territoire réglée sur la couverture du solo (mesurée), pseudo jamais caché en haut de l'écran, chocs en temps de jeu, retour au titre en solo 2000×648, `prochain_index_couleur()` retiré, captures. | ✏️ `Scripts/Ville.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scripts/Titre.gd` ✏️ `Scripts/GameState.gd` ✏️ `tests/bataille_test.gd` | ◉ manche à 4 |

### C. Réseau

| # | Objet | Fichiers | Sortie |
|---|---|---|---|
| 11 | **Transport** : autoload `Reseau` (ENet 7777, poignée de main par l'authentification de `SceneMultiplayer`, version, refus explicites, attribution des index et couleurs, départs, retour hors réseau), test à plusieurs processus headless sur localhost. Découpage (10 fichiers avec les points de vigilance « phase 11 ») : plans des phases 11 et 11 bis, puis 11 ter (test réseau durci et en CI). | ➕ `Scripts/Reseau.gd` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ➕ `tests/reseau/lancer.sh` ➕ `tests/reseau/joueur.gd` | hôte + 2 clients se connectent, version refusée |
| 11 bis | **Joueur local par identifiant réseau** : `Joueur.id_reseau`, `GameState.joueur_local()` selon `multiplayer.get_unique_id()`, `Audio` qui suit le joueur local, retour au solo avec le joueur de ce poste, `configurer_bataille(n, couleurs)`, palette réglée pour la deutéranopie. | ✏️ `Scripts/Joueur.gd` ✏️ `Scripts/GameState.gd` ✏️ `Scripts/Audio.gd` ✏️ `tests/unitaires.gd` | tests verts, CI verte, ◉ planche de la palette |
| 11 ter | **Test réseau durci et en CI** : poignées de main échouées comptées par l'hôte de test (`--refus=N`) au lieu de fenêtres d'attente fixes ; scénario 5 à délai de poignée de main de 8 s posé par l'hôte de test (`--delai-poignee`, `Reseau.gd` inchangé), rival démarré d'avance et lancé au feu (`--feu`), client lent qui ne coupe plus lui-même sa poignée de main ; pas « Test réseau » dans la CI, journaux recopiés en cas d'échec. | ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` ✏️ `.github/workflows/ci.yml` | test réseau vert 5 fois (bash 3.2 et 5) ; critère de sortie restant à vérifier une fois la PR ouverte : le job CI (pas « Test réseau » compris) vert |
| 12 | **Découverte** : autoload `Decouverte` (balise UDP 7778 de l'hôte, qui suit `Reseau` ; écoute ; liste des parties qui expirent ; adresse IPv4 saisie validée), test à plusieurs processus (balises vers 127.0.0.1 ; vraie diffusion avec `DIFFUSION=1`, hors CI). Découpage (8 fichiers avec les tests et l'autoload) : plans des phases 12 et 12 bis. | ➕ `Scripts/Decouverte.gd` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | tests verts, test réseau vert 5 fois (bash 3.2 et 5) |
| 12 bis | **Écran Réseau** : pseudo mémorisé, Héberger, liste des parties, Rejoindre par IP, textes des refus et des échecs, bouton Multijoueur du titre, `Titre._ready` hors réseau. | ➕ `Scenes/EcranReseau.tscn` ➕ `Scripts/EcranReseau.gd` ✏️ `Scripts/Titre.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `tests/smoke_test.gd` | ◉ écran Réseau |
| 13 | **Salon** : cartes, couleurs, Prêt, niveau, bouton Démarrer de l'hôte (pas de compte à rebours, décision de l'utilisateur), lancement de la manche chez tous (index compactés, `configurer_bataille_reseau`), table et protocole du salon dans `Reseau`, l'écran Réseau qui passe la main, `rejoindre()` limité aux IPv4, version 0.13. Plafond de 5 fichiers levé. | ➕ `Scenes/Salon.tscn` ➕ `Scripts/Salon.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/GameState.gd` ✏️ `Scripts/Regles.gd` ✏️ `Scripts/EcranReseau.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | ◉ salon à 3, test réseau vert 5 fois (bash 3.2 et 5) |
| 14 | **Manche synchronisée** (après la 14 bis) : lions, ennemis et pastilles apparus chez l'hôte et répliqués (`MultiplayerSpawner`, `MultiplayerSynchronizer` : position, vitesse, orientation, vomi ; côté du peintre, couleur d'une pastille), commandes des clients par RPC (numérotées, silence de 500 ms), tampons diffusés et dessinés à l'identique (`Peinture` : jeux tirés de leur clé, graine u16), territoire et scores diffusés toutes les 0,2 s, réactions des joueurs par RPC, barrière de chargement (exclusion d'un absent), départs et hôte perdu, menu local sans pause, fenêtre en 16:9 hors solo, relais du serveur coupé, départ propre et silences d'ENet, version 0.14. Plafond de 5 fichiers levé. | ➕ `Scripts/Peinture.gd` ➕ `Scripts/Manche.gd` ✏️ `Scripts/Territoire.gd` ✏️ `Scripts/Ville.gd` ✏️ `Scripts/GerbeTraceuse.gd` ✏️ `Scripts/Joueur.gd` ✏️ `Scripts/GameState.gd` ✏️ `Scripts/Regles.gd` ✏️ `Scripts/Titre.gd` ✏️ `Scripts/Salon.gd` ✏️ `Scripts/EcranReseau.gd` ✏️ `Scripts/Reseau.gd` ✏️ `project.godot` ✏️ `Scripts/Ennemi.gd` ✏️ `Scripts/Soucoupe.gd` ✏️ `Scripts/Coccinelle.gd` ✏️ `Scripts/Boss.gd` ✏️ `Scripts/Spawner.gd` ✏️ six scènes d'ennemis et de pastilles ✏️ `Scripts/Lion.gd` ✏️ `Scenes/Lion.tscn` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Main.gd` ✏️ `Scenes/Main.tscn` ✏️ `Scripts/Intro.gd` ✏️ `Scripts/PauseMenu.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | ◉ partie à 2 fenêtres, test réseau vert 5 fois (bash 3.2 et 5) |
| 14 bis | **Pastilles vers `body is Lion`** (exécutée avant la 14) : base commune des trois pastilles (garde hôte, `body is Lion`, premier arrivé, premier servi, une réplique ne se libère pas d'elle-même : `_expirer`), sons de ramassage par `Audio` et les signaux du joueur local (un par frame, le cran de bataille compris), recul du peintre horizontal (il pointait vers la ville), durcissements du smoke test de la revue 8 ter. | ➕ `Scripts/Pastille.gd` ✏️ `Scripts/ColorPickup.gd` ✏️ `Scripts/BonusPickup.gd` ✏️ `Scripts/CoeurPickup.gd` ✏️ `Scripts/Audio.gd` ✏️ `Scripts/Boss.gd` ✏️ `tests/smoke_test.gd` | smoke vert, suites vertes 5 fois |
| 15 | **Test réseau de bout en bout** : scénario 11 (les scénarios 9 et 10 restent) : 1 hôte + 3 clients jouent une manche entière de 45 s sur le Village au clavier, chacun selon un programme de commandes au hasard (graine) ; l'hôte orchestre les rencontres (pastilles ramassées au vol par chaque client, étoile, soucoupe, sa gerbe sur un client, la gerbe d'un client sur lui, un choc) ; un client arraché (KILL) est vu parti au bout du silence de session d'ENet (3,2 à 6,3 s mesurées, 10 s au plus), son lion disparaît chez tous, ses cellules restent ; même empreinte chez l'hôte et les deux clients restés (territoire, scores, suite des tampons, lions, apparitions, niveau, réactions de chaque joueur comptées sur chaque poste) ; jeux de tampons remesurés à 4 postes. `DUREE11=45` (décision de l'utilisateur : marge CI sous le `timeout 300`, pas 90) : test réseau ~110 s (~52 s pour le scénario 11), `ci.yml` inchangé. | ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | test vert 5 fois (bash 3.2 et 5), puis en CI |
| 15 bis | **Découpage de `Lion.gd`** (avant la 16, à comportement identique) : `DeplacementLion` (logique pure : vitesse commandée, recul) et le pas `Lion.avancer`, seul chemin du déplacement sur l'hôte ; `PareChocs` (script du nœud `PareChocs` : chocs, délai anti-rafale, blocage) ; `GerbeLion` (nœud `Gerbe` : émetteurs, traceuse, zones de contact) ; `Lion` garde joueur, commandes, réplication, vomi et présentation (542 → 320 lignes). Outil de trace des lions (`tests/trace_lions.gd`, hors CI) : empreinte identique avant et après chaque étape. | ➕ `Scripts/DeplacementLion.gd` ➕ `Scripts/PareChocs.gd` ➕ `Scripts/GerbeLion.gd` ➕ `tests/trace_lions.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scenes/Lion.tscn` ✏️ `Scripts/GerbeTraceuse.gd` ✏️ `Scripts/Manche.gd` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/bataille_test.gd` | trace inchangée, suites vertes 5 fois, test réseau vert 5 fois (bash 3.2 et 5) |
| 16 | **Prédiction du lion local** (4 bis) : sur un client, le lion local avance tout de suite (`PredictionLocale`, par `Lion.avancer`), se recale sur chaque état neuf de l'hôte et rejoue les commandes que l'hôte n'a pas encore appliquées (avec ses chocs simulés), décalage d'affichage amorti en 120 ms, recalage immédiat au-delà de 200 px ; commandes lues une fois par tick, numérotées, envoyées avec les 3 précédentes, appliquées par l'hôte une par tick dans l'ordre, jamais deux fois (`Commandes` : file) ; un seul état répliqué par lion (`Lion.etat_reseau`, `EtatLion` : instant, dernière commande appliquée, position, vitesse commandée, recul, orientation) ; lions distants interpolés avec 100 ms de retard (`InterpolationLion`) ; simulateur de latence en relais UDP (`tests/reseau/relais.gd`) ; banc de la prédiction dans un seul processus (`tests/prediction_test.gd`, en CI) ; scénario 12 du test réseau sous 80 ms / 40 ms / 5 % ; version 0.16. `Scripts/Reseau.gd` inchangé. | ➕ `Scripts/PredictionLocale.gd` ➕ `Scripts/EtatLion.gd` ➕ `Scripts/InterpolationLion.gd` ➕ `tests/prediction_test.gd` ➕ `tests/reseau/relais.gd` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scripts/PareChocs.gd` ✏️ `Scenes/Lion.tscn` ✏️ `Scripts/Manche.gd` ✏️ `Scripts/Main.gd` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` ✏️ `.github/workflows/ci.yml` | trace inchangée, banc et scénario 12 verts sous 80 ms / 40 ms / 5 %, suites vertes 5 fois, test réseau vert 5 fois (bash 3.2 et 5), ◉ partie à 2 fenêtres sous latence |

### D. Fin de manche et livraison

| # | Objet | Fichiers | Sortie |
|---|---|---|---|
| 17 | **HUD de bataille, fin au chrono et sons** (17 et 17 bis réunies) : HUD à part du solo (une vignette par joueur dans l'ordre des index : pseudo, lion teint et couronné de travers pour chaque meneur ex æquo compris, part des cellules peintes (100 % à eux tous), rang, crans en points, gerbe XXL décomptée par le HUD, étourdissement, départ en grisé ; celle de ce poste mise en évidence ; chrono de 90 s rouge et tic dans les 10 dernières secondes) ; la manche finie au chrono de l'hôte seul, sa fin (chrono, scores) envoyée à chaque client après ses derniers tampons et son territoire, les départs annoncés ; panneau de fin et sortie (Échap : le titre) en attendant les Résultats ; musique au tiers du temps de la manche ; pseudos des lions écartés sans se chevaucher, dans l'écran (`PlacementPseudos`) ; rythme de la manche à 4-6 (pastilles à plusieurs, toutes les 4 s, qui expirent, loin du centre des lions ; 3 s de répit après un ennemi, pause du peintre doublée) ; sons (« boing » de chaque choc sur chaque poste, étourdissement, gong, tic, annonce du peintre chez les clients, boucle du vomi du seul lion local) ; scénario 13 du test réseau (fin au chrono sous latence simulée) et HUD dans l'empreinte ; version 0.17. | ➕ `Scenes/HUDBataille.tscn` ➕ `Scripts/HUDBataille.gd` ➕ `Scripts/PlacementPseudos.gd` ➕ `Assets/Sons/boing.wav` `tic.wav` `fin.wav` `etourdi.wav` ✏️ `Scripts/Regles.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `Scripts/GameState.gd` ✏️ `Scripts/Audio.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scripts/PareChocs.gd` ✏️ `Scripts/Boss.gd` ✏️ `Scenes/Boss.tscn` ✏️ `Scripts/Main.gd` ✏️ `Scripts/Manche.gd` ✏️ `Scripts/Spawner.gd` ✏️ `tools/generer_sons.py` ✏️ `Assets/Traductions/traductions.csv` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/bataille_test.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | ◉ HUD à 6, suites vertes 5 fois, test réseau vert 5 fois (bash 3.2 et 5) |
| 17 bis | (réunie avec la 17, même PR) | | |
| 18 | **Résultats** : la fin de manche de l'hôte porte son bilan (`BilanManche` : chrono ; par joueur, cellules, crans, étourdissements infligés, cellules volées, chocs, départ ; l'état final de chaque lion), que chaque client applique (lions posés, prédiction arrêtée) ; l'écran Résultats sur chaque poste, tiré du seul bilan (classement en barres animées, pseudo, couleur, part des cellules peintes, gagnant ou ex æquo, statistiques, les trois titres ex æquo compris), à la place du HUD et de son panneau de fin ; l'hôte choisit pour tous Revanche, Niveau suivant (deux joueurs au moins : la manche se relance chez tous, la scène de jeu se recharge) ou Retour au salon (la même table), les clients attendent, chacun peut quitter (commandes à l'appui, sans focus, choix au clavier 1 s après l'animation) ; le départ de l'hôte demande confirmation (« Quitter la partie pour tout le monde ? », décision de l'utilisateur du 27/09), pas celui d'un client ; le lancement et le retour au salon, avec leur table, sur le canal ordonné de la manche, rien d'une manche finie dans la suivante ; le lion distant ne recule plus pendant un accroc (M2 de la revue 16) ; les places réservées vues des clients, le stick tenu à l'entrée du salon, les adresses relevées une fois ; l'exclusion dite à l'exclu ; la boucle du vomi arrêtée à l'hôte perdu ; scénario 13 étendu (Résultats identiques, revanche, départ sur l'écran Résultats, retour au salon) ; version 0.18. | ➕ `Scripts/BilanManche.gd` ➕ `Scenes/Resultats.tscn` ➕ `Scripts/Resultats.gd` ✏️ `Scripts/InterpolationLion.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scripts/PredictionLocale.gd` ✏️ `Scripts/Manche.gd` ✏️ `Scripts/Main.gd` ✏️ `Scripts/HUDBataille.gd` ✏️ `Scenes/HUDBataille.tscn` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Salon.gd` ✏️ `Scripts/Titre.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/bataille_test.gd` ✏️ `tests/prediction_test.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | ◉ résultats, suites vertes 5 fois, test réseau vert 5 fois (bash 3.2 et 5) |
| 19 | **Livraison Windows** : l'exe à l'icône, au nom (« LeLion multi », aussi dans la fenêtre du pare-feu) et à la version du jeu, vérifiés par la CI (le preset, le `.pck` intégré et l'artefact venaient de la PR #26) ; README (le multijoueur, « Jouer en LAN » en français : pare-feu de l'hôte et des joueurs, réseau Privé, ports 7777 et 7778, repli par IP, Wi-Fi maillé, dépannage) ; captures versées au dépôt (`tests/screenshots.gd` en parties, `tests/deux_fenetres.gd`) et déroulées sans rendu en CI ; tables du salon numérotées (M6 de la revue finale 18) ; fenêtre gardée dans l'écran (M7 de la revue finale 14) ; journal de la prédiction hors du jeu livré ; garde du protocole (la version reste celle du protocole) ; vraie diffusion en CI ; fiche de l'essai LAN (`docs/essai-lan.md`) ; version 0.19. | ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Salon.gd` ✏️ `Scripts/Regles.gd` ✏️ `Scripts/PredictionLocale.gd` ✏️ `project.godot` ✏️ `export_presets.cfg` ✏️ `.github/workflows/ci.yml` ✏️ `README.md` ✏️ `tests/unitaires.gd` ✏️ `tests/prediction_test.gd` ✏️ `tests/screenshots.gd` ➕ `tests/deux_fenetres.gd` ✏️ `tests/reseau/lancer.sh` ➕ `docs/essai-lan.md` | ◉ livraison, suites vertes 2 fois, test réseau vert sous bash 5 et sous bash 3.2 (`DIFFUSION=1`), CI verte 3 fois ; `.exe` de la CI essayé par l'utilisateur sous Windows avec la fiche |
| 19 bis | **Réglages de l'essai LAN** : les réponses de `docs/essai-lan.md` (rythme à 4-6, peintre, `HAUTEUR_BANDE_HUD`, prédiction, HUD, sons, écran Résultats, découverte sous Windows, à-coup de l'intro, hôte perdu), chacune dans la constante que dit la fiche ; la trace de la bataille remesurée à chaque changement du jeu (procédure de la fiche). | selon les réponses | à écrire après l'essai |
| 19 ter | **Linux et macOS, Release sur tag** (demande de l'utilisateur, 28/09) : presets Linux (x86_64, données intégrées) et macOS (`LeLion.app` universelle, signée ad hoc, non notarisée, avec la demande d'accès au réseau local), vérifiés par la CI (l'exécutable Linux démarre sans rendu ; l'Info.plist, la signature et le binaire universel de l'app) et publiés en artefacts ; un tag `vX.Y` qui suit `config/version` publie une Release GitHub avec les trois jeux ; import ETC2/ASTC activé (exigé pour Apple Silicon, aucune texture compressée en VRAM : rendu et trace inchangés) ; README (Mac, Linux, journaux). | ✏️ `export_presets.cfg` ✏️ `.github/workflows/ci.yml` ✏️ `project.godot` ✏️ `README.md` | l'app de la CI lancée sur le Mac de développement (M2, Metal) ; Release `v0.19` à la demande de l'utilisateur |

## Points de vigilance transverses

- `class_name` : après la création d'un script avec `class_name`, relancer `godot --headless --import .`
  avant les tests, sinon le cache des classes globales ne connaît pas encore la classe.
- Traductions : tout nouveau texte visible passe par `Assets/Traductions/traductions.csv` (FR + EN).
- Identifiants et commentaires en français, comme le reste du code.
- Toute phase pas encore commencée peut être rééquilibrée dans son propre plan si le code des
  phases précédentes change la répartition des fichiers, comme cela a été fait pour les phases 5,
  6 et 6 bis (5 fichiers au plus jusqu'à la phase 12 bis ; plafond levé depuis la phase 13).
- Les fichiers `.uid` générés par Godot à côté des nouveaux scripts sont committés avec eux et ne
  comptent pas dans le plafond de 5 fichiers d'une phase.
- `OfflineMultiplayerPeer` est le pair multijoueur par défaut de Godot 4 : le solo tourne déjà
  dessus, aucun code n'est nécessaire (spec §3/§12).
- Phase 3 (Règles) : `Joueur.encaisser_coup` n'a pas de plancher sur `vies` ; les règles doivent
  conserver le garde-fou `partie_en_cours` de GameState (ou un clamp) pour qu'un lion à 0 vie ne
  soit jamais retouché.
- (résolu en phase 14) en bataille réseau, `$Lion` (le lion du solo) est retiré dès le `_ready` de
  la scène de jeu ; tous les lions apparaissent par le `MultiplayerSpawner` de la scène
  (`Main.apparitions`), par l'index de leur joueur, dont la `spawn_function` (`Main._creer_lion`)
  donne joueur, commandes (`LOCALES` pour `joueur_local()` seulement) et place de départ avant
  l'ajout ; `Main.lion` est le lion de `joueur_local()`. Échap y ouvre un menu local sans pause
  (« La partie continue », « Quitter la partie »), qui suspend les commandes de ce poste
  (`Commandes.suspendues`). Hors du solo, la fenêtre prend le format 16:9
  (`Regles.appliquer_ecran`, 1400×788) ; (résolu en phase 19) la fenêtre par défaut reste 1400×454
  (`project.godot`, la largeur des captures validées des phases 17 et 18), toujours gardée dans la zone
  utile de son écran (`Regles.taille_bornee`, M7) ; sa largeur se juge à l'essai LAN
  (`docs/essai-lan.md`, § 2, phase 19 bis) ;
- (résolu en phase 16) `PredictionLocale` (priorité -10) lit les actions de ce poste une seule fois
  par tick physique (direction et vomir au même tick), les numérote, les écrit dans les commandes
  manuelles du lion local et les garde ; `Manche._envoyer_commandes` (priorité 100) envoie ce paquet
  (`PredictionLocale.paquet` : la commande et les 3 précédentes). La prédiction passe par
  `Lion.avancer`, donc par la même borne `Lion._marge_haute()` que l'hôte ; l'étiquette est visible
  sur chaque poste au même titre (la même table des joueurs) : l'empreinte du test réseau la compte ;
- (résolu en phases 14 et 16) sans paquet de commandes d'un client depuis `Manche.SILENCE_COMMANDES`
  (500 ms), l'hôte remet son lion au repos et vide sa file (`Commandes.remettre_au_repos`) ; le délai
  reste bien au-dessus de la latence simulée (40 ms ± 20 ms par aller) et de trois paquets perdus de
  suite, que la redondance couvre ;
- Les sous-ressources des scènes instanciées plusieurs fois (formes, matériaux) sont partagées :
  les dupliquer ou les marquer `local_to_scene` avant de les modifier par instance (vu en phase 2
  avec la traceuse du lion).
- (résolu en phase 17, décision de l'utilisateur du 27/09 ; à revoir à l'essai LAN, phase 19 bis) rythme
  de la manche : en bataille, les pastilles arrivent à plusieurs (`Regles.pastilles_en_meme_temps` :
  2 de 2 à 3 joueurs, 3 de 4 à 6), une toutes les 4 s sous ce plafond (`delai_entre_pastilles`, 6 s en
  solo), et une pastille que personne ne ramasse expire au bout de 12 s (`duree_de_vie_pastille`) : elle
  ne bloque plus les autres ; chacune naît loin du **centre** de chaque lion
  (`pastilles_loin_des_lions`) et, si aucun des dix essais n'est à `distance_min_du_lion` de tous, au
  plus loin des dix ; elle naît aussi sous la bande du HUD (`HAUTEUR_BANDE_HUD`, 160 px à l'échelle de
  l'écran de bataille, extra de la Task 6 hors brief : `Regles.zone_pickups_ajustee`), une estimation
  du bas des vignettes non mesurée sur une capture réelle. Le solo ne change pas (une à la fois, 6 s
  après le départ de la précédente, coin du lion, dernier essai ; sa trace non plus). Réglé sans essai
  à 4-6 (justifications dans `ReglesBataille`) : la manche pilotée de `tests/bataille_test.gd` finit
  avec 7 crans pour chacun des 4 lions (le pilote court à chaque pastille) ; à juger en vrai à l'essai
  LAN (`docs/essai-lan.md`, § 5, phase 19 bis) : le rythme des pastilles, le peintre et
  `HAUTEUR_BANDE_HUD` (175 px depuis la revue finale 17) ;
- (résolu en phase 17) une bataille finie garde une sortie : le panneau de fin du HUD de la bataille
  (« FIN DE LA MANCHE ! », le gagnant ou les ex æquo) et Échap, Start ou le bouton : le titre, qui
  quitte le réseau (l'hôte qui sort ramène ses clients au titre, « L'hôte a quitté la partie ») ; le
  menu local se ferme et se tait à la fin ; le bouton ne prend jamais le focus (Espace tenu au gong ne
  quitte pas). (Résolu en phase 18) l'écran Résultats (`Resultats`) remplace ce panneau et cette
  sortie : Échap y quitte (le titre), l'hôte y choisit aussi Revanche, Niveau suivant, Retour au salon ;
- (résolu en phase 17) les étiquettes de pseudo de deux lions qui se touchent ne se chevauchent plus
  et restent dans l'écran, aux deux bords (`PlacementPseudos`, appliqué par `Main._placer_pseudos` à
  chaque image : les textes qui se recouvrent se serrent en un bloc centré sur leurs places voulues,
  ramené dans l'écran ; vérifié par `tests/bataille_test.gd`, bord gauche et bord droit, avec
  « WWWWWWWWWWWW », et sur les captures du ◉ HUD à 6). Elles ne glissent qu'à l'horizontale : leur
  hauteur, que borne `Lion._marge_haute()`, ne change jamais (la physique et la trace non plus) ;
- (résolu en phase 14 bis, réaffecté de la phase 14) sons de ramassage : tout passe par `Audio` et
  les signaux du joueur local, sur chaque poste (`couleur_debloquee`, `crans_changes`,
  `bonus_change(true)`, `vies_changees` en hausse, la référence des vies reprise à `partie_prete`),
  un son par frame au plus ; les pastilles ne jouent plus rien ;
- (résolu en phase 14 bis) base commune `Pastille` (garde hôte, `body is Lion`, premier arrivé,
  premier servi) ; la fin de vie d'une étoile ou d'un cœur passe par `Pastille._expirer`, qui ne
  libère la pastille que sur l'hôte. **Phase 14** : la disparition répliquée (le `MultiplayerSpawner`
  de la scène de jeu) s'appuie dessus ;
- à la sortie des tests headless, Godot signale des ressources audio encore utilisées (sons qui
  jouent au moment de `quit()`) : bruit sans effet sur le code de sortie ; `Audio` pourrait arrêter
  ses lecteurs dans `_exit_tree` ;
- (résolu en phase 14 bis) `body is Lion` dans le gestionnaire commun des pastilles ; les tests
  `--script` ne nomment ni `Lion`, ni `Ennemi`, ni `Pastille` et vérifient l'héritage par
  `load(...).get_base_script().resource_path` ; le groupe « lion » ne sert plus qu'au Spawner ;
- (résolu en phase 14) le Spawner ne tourne que sur l'hôte (`Spawner.demarrer()`, appelé par la
  scène de jeu : hors réseau dans son `_ready`, en réseau après la barrière de chargement) ;
  ennemis et pastilles apparaissent chez chaque client par le `MultiplayerSpawner` de la scène de
  jeu (noms lisibles, `add_child(..., true)`), leur `MultiplayerSynchronizer` (`Synchro`) en recopie
  la position (et le côté du peintre, l'inclinaison de la coccinelle, la couleur d'une pastille) ;
  un client ne les simule jamais ;
- (résolu en phase 14) les ennemis ne tournent pas côté client : chacun commence son `_ready` et
  son `_physics_process` par `Ennemi.est_replique()` (ni hasard, ni déplacement, ni tween, ni
  libération) ; le peintre applique le côté reçu (`Boss.cote`, setter). (Résolu en phase 17) son
  état est répliqué (`Boss.etat`, à chaque changement) : son annonce s'entend aussi chez chaque client
  (le setter de la réplique joue `Audio.jouer("boss")`) ;
- (résolu en phase 14 bis) durcissements de la revue 8 ter : `create_client` vérifié `OK`, intrus
  du groupe « lion » avec un champ `joueur` (ennemis et pastilles), recul du peintre vérifié
  horizontal après le contact continu, peintre remis au repos. Le recul vérifié a révélé un défaut :
  `Boss.origine_du_coup` prenait la hauteur du coin du lion (66 px au-dessus de son centre) et
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
- (résolu en phase 15) jeux de tampons : chaque poste génère ses jeux au premier usage
  (`Peinture.generer_tampons`, graine tirée de la clé : le même jeu quel que soit le moment).
  Remesurés par le scénario 11 (1 hôte + 3 clients, crans jusqu'à 5, gerbe XXL, manche entière de
  45 s) : 9 ou 11 jeux générés par poste (2 passages mesurés), frame la plus longue qui en génère
  17 à 61 ms chez l'hôte comme chez un client (lignes `MESURE`) ; la frame la plus longue tout
  court (18 à 70 ms) ne génère pas toujours (quatre processus Godot sur un Mac).
  Pas de pré-génération. Mémoire du cache plein : environ 14,5 Mo pour 6 joueurs ;
- **prochaine phase qui ajoute un scénario au test réseau** (temps de la CI, phases 16 à 19) : le
  test réseau prend ~175 s sur ce Mac (172 s mesurés en préparant la phase 19, avec le scénario 7 de la
  vraie diffusion, que la CI lance depuis ; 169 à 178 s en phase 18 ; ~157 s en phase 17, 140 s
  avant), dont ~52 s pour le scénario 11 (`DUREE11=45`, décision de l'utilisateur), ~38 s pour le
  scénario 12 (la manche sous latence simulée, `DUREE12=20`) et le scénario 13 prolongé en phase 18
  (la fin au chrono, `DUREE13=10`, puis l'écran Résultats, la revanche de 6 s et le retour au salon), sous le
  `timeout 300` du pas « Test réseau » de `ci.yml` ; le banc de la prédiction (`tests/prediction_test.gd`)
  a son propre pas, ~1 s. Au-delà de ~200 s, raccourcir un scénario ou relever ce `timeout` ;
- (résolu en phase 17, décision de l'utilisateur du 27/09 ; à revoir à l'essai LAN, phase 19 bis) le
  peintre en bataille (vu en phase 15) : sur le Village, il couvre toute la bande de peinture, et un
  joueur qui ne fuyait pas était étourdi sans relâche (le programme du scénario 11 sans fuite, mesuré à
  90 s : 21 % de la ville peinte à 4, contre 58 à 66 % en fuyant). En bataille, un étourdissement par
  un ennemi laisse 3 s de répit (`ReglesBataille.DUREE_REPIT_ENNEMI`, l'immunité ; 1 s après un vomi,
  inchangé) : à 350 px/s, plus de deux fois la largeur du peintre (442 px) ; et le peintre se repose
  deux fois plus longtemps entre deux passages (`Regles.facteur_repos_peintre`, 4 s au lieu de 2) : la
  bande est libre un tiers du temps au lieu d'un cinquième. À juger en vrai à l'essai LAN
  (`docs/essai-lan.md`, § 5, phase 19 bis) ;
- **phase 18** (résultats, vu en phase 15) : les statistiques de bataille (`Joueur.chocs`,
  `etourdissements_infliges`, `cellules_volees`) ne sont tenues que par l'hôte (règles) et ne sont
  pas répliquées : l'écran Résultats d'un client doit les recevoir de l'hôte (dans le message de fin
  de manche, par exemple) ;
- (résolu en phase 16) l'hôte du scénario 10 efface ses scores de test avant d'écrire la mesure
  qui le fait arrêter (`ECART_EXCLUSION`) ;
- (résolu en phase 14) un client qui part en cours de manche arrive chez l'hôte par
  `Reseau.joueur_parti(id)` : la manche retrouve son joueur par `Joueur.id_reseau`, oublie ses
  commandes et son lion disparaît chez tous (disparition répliquée) ; un hôte perdu arrive chez
  chaque client par `Reseau.hote_perdu` : « L'hôte a quitté la partie » sur la partie figée, puis
  le titre. (Résolu en phase 17) le joueur parti reste au classement en grisé sur chaque poste : l'hôte
  annonce chaque départ (`Manche._recevoir_depart`, ceux d'avant la barrière, un exclu, en la
  passant ; `Manche.depart_vu` sur chaque poste), le HUD le grise (`HUDBataille.marquer_parti`) ;
- (résolu en phase 14) les réactions d'un joueur (étourdissement et sa fin, crans, gerbe XXL et sa
  fin) partent de l'hôte en RPC fiables de la manche, qui appellent chez chaque client les méthodes
  du `Joueur` qui émettent les mêmes signaux (`etourdir`, `activer_bonus`, `recevoir_crans`,
  `recevoir_fin_etourdissement`, `recevoir_fin_bonus`) ; `GameState._process` ne décompte les
  minuteries des joueurs que sur l'hôte. (Résolu en phase 17) sur un client, `Joueur.bonus_restant`
  reste celui reçu au début de la gerbe XXL (seule sa fin arrive) : le HUD de la bataille décompte
  lui-même ses secondes (`HUDBataille.xxl_restant`), que la fin reçue efface ;
- (résolu en phase 19) `tests/screenshots.gd` : le coup de sa partie solo tombe après l'intro
  (`GS.pret` ; pendant l'intro, il ne comptait pas) ; les captures de l'écran Réseau (phase 12 bis), du
  salon (phase 13), de la manche à 6 couleurs (phase 17) et de l'écran Résultats (phase 18) y sont
  versées, en parties (`--parties=solo,reseau,salon,bataille,resultats`, 37 captures) ; la partie à 2
  fenêtres (phase 14) est `tests/deux_fenetres.gd`, jusqu'aux Résultats et à l'hôte perdu. Sans rendu,
  les deux déroulent tout sans rien écrire, et la CI les lance ainsi (pas « Captures ») : ils ne
  pourrissent plus. Les minuteries `null` du Spawner quand la partie se termine pendant l'intro sont
  corrigées depuis la phase 10 bis (vérifié par `tests/bataille_test.gd`) ;
- les tests `--script` peuvent nommer `Territoire` (logique pure, phase 9) et les règles, jamais
  la ville, le lion ni les ennemis (qui nomment des autoloads). Les couleurs relues sur la ville
  se comparent après un passage par une image RGBA8 (`_rgba8` du smoke test) : `set_pixel`
  tronque sur 8 bits, `Color.to_rgba32()` arrondit ;
- (résolu en phase 17 : les vignettes du HUD portent le pseudo, la part et le rang, pas seulement la
  couleur) la palette de bataille est réglée pour la deutéranopie depuis la phase 11 bis
  (écart OKLab minimal 0,186 entre couleurs pures simulées, vérifié par `tests/unitaires.gd`), mais
  sur la crinière (couleur × luminance du sprite) rouge et vert restent deux kakis que seule la
  clarté sépare, magenta et cyan deux gris bleutés : les vignettes du HUD portent le pseudo, pas
  seulement la couleur, comme l'étiquette au-dessus du lion. Sur le territoire (les trois nuances de
  chaque joueur, `Joueur.nuances`), la confusion se rapproche encore plus entre joueurs différents en
  deutéranopie (magenta pur ≈ cyan foncé 0,028 ; rouge clair ≈ jaune foncé 0,046 ; rouge pur ≈ vert
  foncé 0,047 — M2, revue finale phase 11 bis, garde-fou sur la moyenne des nuances par joueur dans
  `tests/unitaires.gd`) : la propriété d'une cellule se lit au score du HUD (avec le pseudo), jamais
  à sa teinte ;
- (résolu en phase 17) le score d'un joueur se lit sur le territoire de la ville
  (`ville.territoire.cellules_de(joueur.index)`, sur `ville.territoire.nb_peignables` pour un
  pourcentage) : c'est ce que lit le HUD de la bataille, qui remplace en bataille celui du solo ; il
  n'y a pas de `Joueur.cellules` (spec §3.1). La musique suit `Regles.intensite_musique()`,
  `int(avancement() × 3)` dans les deux modes (la formule du solo ; en bataille, arpèges à 30 s de
  jeu, mélodie à 60 s), à chaque image en bataille (`Main._process`) ;
- (résolu en phase 14) un joueur parti garde ses cellules telles quelles (spec §4) : aucune
  opération de `Territoire` n'est nécessaire, les autres peuvent les lui voler ;
- (résolu en phase 18) une nouvelle manche (Revanche, Niveau suivant) recharge la scène de jeu sur
  chaque poste (`Main._sur_choix_resultats` en bataille locale ; `Reseau.relancer_manche` puis
  `Salon.entrer_en_manche` en réseau) : territoire, tampons, Spawner, manche (barrière comprise :
  `Reseau.scenes_chargees` vidé par le lancement), chrono, HUD et prédiction neufs d'un coup (vérifié
  par `tests/bataille_test.gd`, le smoke test et le scénario 13) ; la scène de jeu dépause l'arbre en
  entrant (la fin l'avait figé) ;
- (résolu en phase 14 bis) le commentaire de `Boss.acceleration_max` suit l'avancement des règles ;
- (sans objet depuis la phase 14) aucune couleur ni aucun pseudo de `Joueur` ne change sous un lion
  existant : la table des joueurs est posée avant la scène de jeu et la `spawn_function` la lit ;
  pas de setters `apparence_changee` ;
- activer `rendering/viewport/hdr_2d` changerait les valeurs lues par `Shaders/Lion.gdshader` et
  décalerait ses seuils de masque (valeur, saturation) : refaire alors la planche de contrôle de la
  phase 7 et régler les seuils ;
- (résolu en phase 16) sur un client, un lion distant ne se déplace pas de lui-même : il est interpolé
  entre les états reçus avec 100 ms de retard (`Lion._suivre_l_hote`, `InterpolationLion` ; sa
  `velocity`, que lit le calcul d'approche des chocs, est la vitesse interpolée) et garde ses réactions
  visuelles ; seul le lion local reprend son pas de déplacement (`Lion.avancer`), par sa prédiction.
  Le `Synchro` réplique un seul état par lion (`Lion.etat_reseau`, 33 octets, au plus toutes les
  0,012 s) et le vomi ;
- (résolu en phase 15 bis) `Lion.gd` est découpé : `DeplacementLion` (logique pure, que les tests
  unitaires nomment ; son état tient en deux vecteurs, `vitesse` et `recul`, que la prédiction pourra
  copier et restaurer pour rejouer ses commandes), `PareChocs`, `GerbeLion` ; le lion garde la
  présentation et la réplication. (Résolu en phase 16) `Lion.avancer` reste le seul pas du
  déplacement (l'hôte et la prédiction). Le lion local d'un client part d'un déplacement neutre
  (`PredictionLocale._ready`), puis repart à chaque état de l'hôte de sa vitesse commandée et de son
  recul, répliqués tels quels (`EtatLion`), jamais de sa `velocity` : aucune vitesse ni aucun recul
  fantôme. Les réactions décidées par l'hôte (étourdissement, recul) arrivent dans ses états, jamais
  rejouées par le client ; seuls ses chocs simulés le sont (`PareChocs.choc_simule`). Repasser
  `tests/trace_lions.gd` avant et après chaque modification du lion (deux passages consécutifs
  identiques ; les deux premiers après un import peuvent différer, phase 15 bis, Écart 6) : la
  phase 16 l'a laissée identique (bataille, solo, réplique) ;
- (résolu en phase 16) les états de l'hôte arrivent pendant le sondage réseau : le setter de
  `Lion.etat_reseau` ne fait que les garder, et la prédiction ne rejoue qu'au tick physique suivant ;
  `Lion.avancer` refuse un pas hors d'une image physique (`push_error`, le lion ne bouge pas : ligne
  `ERROR` attendue du smoke test). Pendant un rejeu (`PareChocs.en_rejeu`), `bloquer` ne compte un
  contact présent qu'aux positions rejouées où les pare-chocs se touchent (mesuré au banc : sans
  cela, un choc laisse 46,7 px d'erreur et un aller-retour de 16,4 px de l'affichage ; avec, 0,6 px et
  aucun) ;
- (résolu en phase 16) l'orientation n'est plus répliquée à part : elle voyage dans l'état de
  l'hôte, avec la position et la dernière commande appliquée (`EtatLion`) ; le lion local la reprend
  de l'état au recalage puis la refait en rejouant ses commandes (aucun clignotement : ◉, un tick par
  demi-tour, le temps que la touche soit lue), un lion distant la prend de ses états interpolés ;
- (vu en phase 15 bis, conclusion pratique reprise en phase 16 ci-dessous) : la simulation n'est pas
  reproductible bit à bit d'un processus à l'autre dans tous les cas : l'ordre dans lequel la physique rapporte des contacts
  simultanés semble dépendre d'identifiants d'objets (rejouer la même bataille dans le même processus
  donne une autre empreinte) — cause non établie (Écart 6 de `global-constraints.md`), non reproduite
  en phase 15 bis (revue finale : 3 passages sur 3 identiques dès le premier, sur des copies neuves de
  `main` comme de HEAD). La conclusion pratique reste, elle, acquise : la prédiction d'un client ne
  peut pas compter sur une identité exacte avec l'hôte, même aux mêmes commandes : la correction douce
  (spec §4.1) doit absorber ces écarts, et les tests de prédiction mesurer des écarts de position, pas
  des égalités. (Résolu en phase 16 : le banc et le scénario 12 mesurent l'erreur de prédiction, la
  position de l'hôte après chaque commande accusée comparée à celle que le client avait prédite au tick
  où il l'a lue ; seules les empreintes de fin de manche, lions au repos, sont des égalités : le client
  y reprend exactement l'état de l'hôte) ;
- (résolu en phase 16) seul le lion local simule son choc (`PareChocs._on_area_entered` : recul,
  blocage, secousse), contre les lions affichés ; le choc part en signal (`PareChocs.choc_simule`), la
  prédiction le note au tick où il arrive et le rejoue tant que l'hôte ne l'a pas. Un lion distant
  ne fait que secouer son sprite (sa position vient de l'hôte). Seul l'hôte signale le choc aux
  règles. Pendant un étourdissement, la prédiction applique la règle de l'hôte (`Lion.direction_pour` :
  commandes ignorées) à ses pas comme à ses rejeux : le lion suit l'hôte (banc : 0 px d'erreur une fois
  l'étourdissement connu ; environ 14 px à sa fin, qui arrive avec un aller de retard, absorbés par la
  correction douce) ;
- (résolu en phase 17) le « boing » part de `PareChocs._on_area_entered`, à côté de `Lion.secouer`,
  sur chaque poste (`Audio.jouer_boing` : un par choc, les deux pare-chocs le signalant ; 9 dB plus
  bas entre deux autres lions que celui de ce poste) : immédiat pour le joueur local (spec §4.1) ;
- (résolu, constaté en phase 17) le docstring de `Regles.taille_ecran()` dit déjà « appliquée par
  `Main` en entrant dans la scène de jeu, et par le titre (qui remet le solo) » ;
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
- (résolu en phase 19, M7 de la revue de la phase 11) la version présentée à la poignée de main (et
  dans la balise) est `application/config/version`, qui est aussi celle du protocole : la règle de la
  phase 13 reste (« 0.13 », « 0.14 », « 0.16 », « 0.17 », « 0.18 », « 0.19 »), désormais tenue par les
  tests unitaires (`_tester_protocole`) : une empreinte du protocole (RPC de chaque script, propriétés
  répliquées des scènes, scènes apparues, tailles des formats réseau, balise) est notée avec sa version
  (`PROTOCOLE_VERSION`, `PROTOCOLE_EMPREINTE`), et une empreinte neuve sous la même version les fait
  échouer. Une constante `PROTOCOLE` à part aurait fait deux numéros à tenir au lieu d'un. **Chaque
  phase qui change le protocole** augmente la version et note la nouvelle empreinte (la ligne
  `PROTOCOLE` de la sortie des tests unitaires) ;
- (résolu en phase 19, phase 12, Écart 5) le pas « Test réseau » de `ci.yml` lance aussi le scénario 7
  (`DIFFUSION=1`, la vraie diffusion) : vert 3 fois en CI sous Linux (Task 9 de la phase 19), comme sur
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
- (résolu en phase 19, M8) le README (« Jouer en LAN ») explique la fenêtre du pare-feu Windows
  Defender au premier `heberger()` sur l'hôte (port 7777) et à la première ouverture de l'écran Réseau
  sur chaque client (écoute des balises sur le port 7778), le réseau Privé, ce que voient les joueurs
  après un « Annuler » ou sur un réseau Public, la réparation (autoriser « LeLion multi » en Privé,
  retirer une règle de blocage dans `wf.msc`), que deux LeLion sur un même PC ne listent pas les parties
  tous les deux, et que la règle du pare-feu suit le chemin de l'exe. Depuis la phase 19, l'exe porte
  son nom dans cette fenêtre (« LeLion multi », plus « Godot Engine ») ;
- (résolu en phase 14) l'intérim de la phase 13 est fini : la manche est synchronisée ;
- (résolu en phase 18) retour au salon : `Reseau.revenir_au_salon` (l'hôte, depuis l'écran
  Résultats) rouvre le salon chez lui (`ouvrir_salon` : plus de manche en cours, les arrivées de
  nouveau acceptées et annoncées par la balise, personne prêt, la table diffusée), puis ramène chaque
  client (`_recevoir_retour_salon`, sur le canal ordonné, après la table) ; le salon dépause l'arbre ;
- (résolu en phase 14) hôte perdu en manche : message (`RESEAU_HOTE_PERDU`) sur la partie figée,
  2,5 s, puis retour au titre ;
- (I1 de la revue finale 12 bis, résolu par la phase 13) : `Decouverte.adresses_hote(interfaces)`
  (rang d'interface, physique d'abord, virtuelle en dernier recours), en place depuis la phase
  12 bis dans `Decouverte.gd`, est bien réutilisée par le salon pour afficher l'adresse de l'hôte
  (`Salon.gd:198`) ;
- **prochaine phase qui touche `Scripts/Decouverte.gd`** (I2 de la revue finale 12 bis, toujours
  ouvert : `Decouverte.gd` n'a pas changé en phase 13) : la balise n'a pas d'identifiant de session,
  donc deux hôtes différents sur le même port de jeu ne peuvent pas être distingués par
  `Decouverte` ; l'écran Réseau et le salon ne fusionnent que les balises dont la source est une
  adresse locale de ce poste (son propre hébergement vu par plusieurs interfaces). Ajouter un
  identifiant aléatoire par session à la balise, et dédupliquer dessus en gardant l'adresse source
  du meilleur rang d'interface (I1), à côté du point du /22 ci-dessus ;
- (M9 de la revue finale 12 bis, devenu sans objet en phase 13) : l'écran Réseau n'affiche plus les
  états d'attente ni de nombre de joueurs (remplacés par le salon, qui ne compte que les arrivés) ;
- (résolu en phase 19, M4 de la revue finale 12 bis) les captures des fichiers jetables sont dans
  `tests/screenshots.gd` et `tests/deux_fenetres.gd` ; la fenêtre par défaut de `project.godot` reste
  1400×454, gardée dans l'écran (M7, ci-dessous).
- (résolu en phase 14, M6 de la revue finale 13) barrière « scène de jeu chargée » :
  `Reseau.signaler_scene_chargee` depuis la manche de chaque poste ; l'hôte attend tous les joueurs
  encore là (`Manche._verifier_barriere`), 20 s de jeu au plus (`Manche.delai_chargement`), puis
  exclut les absents (déconnectés) ; lions, Spawner et intro attendent la barrière. (Résolu en phase
  18) l'exclu apprend son exclusion (`Reseau.exclure` : `_recevoir_exclusion`, puis la déconnexion
  0,5 s plus tard ; le silence court de I1 posé tout de suite) et voit « Exclu : ta partie a mis trop
  de temps à charger. » (`Reseau.raison_perte`) ;
- (résolu en phase 14, M5) `server_relay` coupé (`Reseau._ready`) ; un client ne voit que l'hôte
  parmi ses pairs (le test réseau lit les autres joueurs dans la table du salon) ;
- (résolu en phase 14, N9) le commentaire de `Lion.joueur` dit d'où viennent joueur et commandes ;
- (résolu en phase 14, M1) `Reseau.lancer_manche` revérifie ses propres fiches (index compactés,
  `fiches_de_manche` non vide) avant de s'engager ;
- (résolu en phase 18, revue finale 13, M2, M3, M4) les clients voient les places réservées (leur
  nombre part avec la table, `Reseau.places_reservees`, `Reseau.fiches_attente`) ; un stick déjà
  penché à l'entrée du salon n'agit pas (l'état des actions relevé à l'ouverture) ; les adresses de
  l'hôte sont relevées une fois, à l'ouverture du salon.
- **phase 19 bis** (essai sur la LAN, phase 16 ; `docs/essai-lan.md`, § 4) : avant la prédiction, l'utilisateur a joué une manche à 3
  sous Windows en Wi-Fi et trouvé que les commandes « suivent plutôt bien ». Refaire cet essai avec
  l'`.exe` de la phase 16 : si le lion local paraît élastique, régler `PredictionLocale.DUREE_CORRECTION`
  (0,04 s) ; si les lions distants saccadent, `InterpolationLion.RETARD` (6 ticks) ; le relais
  (`tests/reseau/relais.gd`, `--gigue=100`, `--pertes=10`) reproduit un Wi-Fi plus mauvais sur ce Mac.
  Les chocs contre un lion distant qui bouge sont prédits contre sa position affichée, en retard de
  ~140 ms (100 ms d'interpolation et l'aller) : l'hôte fait foi, l'écart se résorbe en glissant
  (spec §13) ;
- (résolu en phase 17) la boucle du vomi n'est qu'au lion de ce poste (`Lion.est_local()`) : un autre
  lion qui arrête de vomir ne la coupe plus ; les autres lions ne jouent rien en vomissant (une boucle
  spatialisée par lion attend que l'essai à 4-6 la réclame : `docs/essai-lan.md`, § 7, phase 19 bis) ;
- **phase 19 bis** (revue de la phase 14, vérifié en phase 16 ; vu sur la capture `client_5_hote_perdu`
  de `tests/deux_fenetres.gd`, phase 19) : chez un client qui perd l'hôte, le moteur fait disparaître les
  nœuds apparus par le `MultiplayerSpawner` (lions, ennemis, pastilles) : le message s'affiche sur une
  ville sans lions. Sans conséquence pour la prédiction (enfant du lion, elle part avec lui ;
  `Manche._envoyer_commandes` vérifie qu'elle existe encore) ni pour le jeu (retour au titre) ; seulement
  visuel : l'essai LAN dit s'il gêne (`docs/essai-lan.md`, § 9 : garder alors la dernière image sous le
  message) ;
- (résolu en phase 19) la partie à 2 fenêtres de la phase 14 est `tests/deux_fenetres.gd` ; elle force
  une fenêtre (`DisplayServer.window_set_mode`) : `Regles.appliquer_ecran` ne règle pas une fenêtre en
  plein écran (réglage « plein écran » de `Parametres`) ;
- (résolu en phase 17) la fin de manche existe en réseau : chez l'hôte, son chrono (ou le test réseau
  qui fige sa manche) appelle `terminer_partie` ; `Manche._sur_fin_de_partie` envoie ses derniers
  tampons, son territoire, puis la fin (`_recevoir_fin_manche` : son chrono et ses scores), sur le même
  canal fiable ordonné ; chaque client prend le chrono de l'hôte et termine sa manche (tout se fige,
  le HUD montre la fin), puis n'envoie plus de commandes (scénario 13 du test réseau) ;
- (résolu en phase 18, vu en phase 16, désync-report.md du scénario 11) la fin de manche porte
  l'état final de chaque lion (le bilan) : chez un client, chaque lion le prend
  (`Lion.poser_etat_final`), le lion local arrête sa prédiction (`PredictionLocale.arreter`) : un
  client qui tient ses touches au gong ne voit plus son lion continuer (le banc de la prédiction et le
  scénario 13, chacun peignant sans lâcher ses touches jusqu'au gong : lions identiques partout). Les
  scénarios 9, 11 et 12 gardent quand même leur repos avant le gel (`TICKS_REPOS_AVANT_GEL`) ;
- (résolu en phase 19, M7 de la revue finale 14) à chaque écran, une fenêtre se garde dans la zone utile
  de son écran (`DisplayServer.screen_get_usable_rect`, barre de titre comprise), réduite à son format
  (`Regles.taille_bornee`) et ramenée dans l'écran (`Regles.position_dans`) : une fenêtre du solo élargie
  à 1920 px ne passe plus sous la barre des tâches en 16:9 ; à revoir sous Windows à l'essai LAN
  (`docs/essai-lan.md`, § 2) ;
- **phase 19 bis**, seulement si l'essai LAN voit l'à-coup (M8 de la revue finale 14 ;
  `docs/essai-lan.md`, § 3 ; l'essai à 3 de l'utilisateur n'en a rien dit) : en réseau, aucun lion n'est dessiné
  pendant le chargement (`Main._preparer_manche_en_reseau` libère celui de la scène avant la
  première image) ; le matériau de teinte, les particules de vomi et les étoiles ne compilent leurs
  shaders qu'à la première image après la barrière, un à-coup sous Windows juste au moment de
  l'intro. Tolérance large (ENet coupe vers ~8 s de silence en session ; mesuré ~35 s pour un
  chargement au maximum de 30 s), d'où la sévérité mineure. Préchauffer pendant le chargement : une
  image avec un lion (et sa gerbe active) hors champ, libéré avant `signaler_scene_chargee` ;
- (résolu en phase 17) chrono de bataille en réseau : la fin est décidée par l'hôte seul
  (`ReglesBataille.temps_ecoule_change`, appelé par `GameState._process` chez l'hôte) et envoyée par
  RPC ; le chrono de chaque client, parti à la fin de **sa propre** intro et décalé de la latence, ne
  termine jamais rien lui-même (`tests/unitaires.gd`) : à la fin reçue, il prend celui de l'hôte
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
- **phase 19 bis** (essai LAN à 4-6 joueurs, phase 17 ; `docs/essai-lan.md`, § 5 à 7) : juger en vrai le HUD de la bataille (lisibilité
  des vignettes dans la fenêtre par défaut, 1400×788, et en plein écran 1080p ; la couronne posée de travers sur le lion des meneurs, les parts des cellules peintes), le volume des
  sons neufs (« boing », tic, gong, étourdissement ; `Audio.DB_AUTRES`), et surtout le rythme réglé à
  l'aveugle en phase 17 (plafond et délai des pastilles, leur durée de vie, le répit après un ennemi, la
  pause du peintre, `HAUTEUR_BANDE_HUD` : constantes de `ReglesBataille`).
- (résolu en phase 19, M5 de la revue finale 16) `PredictionLocale._journal` (20 000 entrées au plus,
  160 Ko) n'est tenu que dans les builds de débogage (`PredictionLocale.journal_actif`,
  `OS.is_debug_build()` : les tests, l'éditeur), jamais dans l'`.exe` d'export release ; le banc vérifie
  qu'une prédiction sans journal ne change pas.
- (résolu en phase 18, M3 de la revue finale 17) l'écran Résultats ne lit que le bilan de la fin,
  arrivé après tout le reste sur le canal ordonné (cellules, crans, statistiques, départs) ; une
  réaction du canal 0 encore en route s'applique à son arrivée (elle précède la fin chez l'hôte) ; le
  HUD figé, caché sous l'écran Résultats, ne compte plus ; les départs sont idempotents (ceux du bilan
  et leurs annonces). Et d'une manche à la suivante : le lancement et le retour au salon partent, avec
  leur table, sur le canal ordonné (`Reseau.CANAL_ORDONNE`), après la fin de la manche finie (la table
  seule reste sur le canal 0 : sur le canal 1, la première table d'un arrivant pouvait devancer la fin
  de son authentification et être jetée) ; une réaction ou un départ reçu avant la barrière d'une
  manche neuve est ignoré (`Manche._joueur_recu`) ; un pair déjà parti dans l'image entre l'ancienne
  manche et la neuve (la nouvelle ne s'abonne à `Reseau.joueur_parti` qu'à `demarrer`) est rattrapé au
  démarrage, par le même chemin qu'un départ normal (revue de la tâche 5) ;
- (résolu en phase 18, M5 de la revue finale 17) `Main._sur_hote_perdu` arrête la boucle du vomi
  (`Audio.arreter_vomi`), et `Titre._ready` aussi, en filet.
- (sans objet, phase 19 ; vu en phase 18, Écart 12 du plan) après une revanche ou un retour au salon, un
  client peut écrire `ERROR: Condition "!pinfo.recv_nodes.has(net_id)" is true` (des disparitions des
  nœuds de la manche finie arrivées après qu'il a quitté sa scène) : sans effet, et invisible des
  joueurs (l'exe n'a pas de console, `export_console_wrapper=0` ; les `ERROR` ne vont qu'à `godot.log`).
  Libérer ces nœuds chez l'hôte avant de relancer ne garantirait pas l'ordre (les disparitions voyagent
  sur le canal 0 de la réplication, le lancement sur le canal ordonné). Les journaux de l'essai LAN
  (`docs/essai-lan.md`, § 10) diront s'il y a pire.
- (résolu en phase 18, décision de l'utilisateur du 27/09) le départ de l'hôte demande désormais
  confirmation sur l'écran Résultats (« Quitter la partie pour tout le monde ? », Oui/Non ; un second
  Échap, vomir, la validation (Entrée/Start) ou Oui confirment, toute autre touche ou Non annulent) ;
  celui d'un client reste immédiat.
- **phase 19 bis** (essai LAN, phase 18 ; `docs/essai-lan.md`, § 8) : juger l'écran Résultats en vrai
  (lisibilité à 1400×788 et en plein écran 1080p, durée de l'animation, délai d'1 s avant un choix au
  clavier).
- (résolu en phase 19, M6 de la revue finale 18) le lancement et le retour au salon (canal ordonné)
  posaient leur table, places réservées forcées à 0, même quand une table plus récente du canal 0 était
  déjà arrivée : chaque table est désormais numérotée (`Reseau.numero_table`), un client ne repose jamais
  une table plus ancienne que la dernière posée (`Reseau.Pose.PERIMEE`), le lancement et le retour portent
  les places réservées de l'hôte, et une manche se joue toujours sur la table et le niveau de son
  lancement (`Reseau.niveau_manche`, que lit `Salon.entrer_en_manche`).
