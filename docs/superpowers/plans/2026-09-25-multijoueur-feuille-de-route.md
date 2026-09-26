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
| 15 | **Test réseau de bout en bout** : le scénario 9 de la phase 14 (1 hôte + 2 clients + un muet exclu, empreintes identiques, départ d'un client, hôte perdu) passe à 1 hôte + 3 clients, une manche plus longue avec pastilles ramassées au vol et chocs ; jeux de tampons remesurés chez un client (point de vigilance ci-dessous). Le test réseau tourne en CI depuis la phase 11 ter (`ci.yml` n'est plus à toucher). | ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | test vert en CI |
| 16 | **Prédiction du lion local** (4 bis), après le découpage de `Lion.gd` (étape à part, voir les points de vigilance) : correction douce, commandes redondantes (la phase 14 les numérote déjà), numéro de la dernière commande traitée répliqué, interpolation, simulateur de latence. | ➕ `Scripts/PredictionLocale.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Manche.gd` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Lion.gd` ✏️ `tests/reseau/joueur.gd` | test vert sous 80 ms / 40 ms / 5 % |

### D. Fin de manche et livraison

| # | Objet | Fichiers | Sortie |
|---|---|---|---|
| 17 | **HUD de bataille** : vignettes, couronne, chrono de 90 s, tic, musique sur le temps restant. | ➕ `Scenes/HUDBataille.tscn` ➕ `Scripts/HUDBataille.gd` ✏️ `Scripts/Audio.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `Assets/Traductions/traductions.csv` | ◉ HUD à 6 |
| 17 bis | **Sons de bataille** : « boing » des chocs entre lions (spec §5), synthétisé comme les autres effets. | ✏️ `tools/generer_sons.py` ➕ `Assets/Sons/boing.wav` ✏️ `Scripts/Audio.gd` ✏️ `Scripts/Lion.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
| 18 | **Résultats** : podium, trois titres, Revanche / Niveau suivant / Salon. | ➕ `Scenes/Resultats.tscn` ➕ `Scripts/Resultats.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `Assets/Traductions/traductions.csv` | ◉ résultats |
| 19 | **Livraison Windows** : preset, `.pck` intégré, artefact CI, README « Jouer en LAN », captures. | ✏️ `export_presets.cfg` ✏️ `.github/workflows/ci.yml` ✏️ `README.md` ✏️ `tests/screenshots.gd` ✏️ `project.godot` | `.exe` en artefact, testé sur Windows par l'utilisateur |

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
  les dupliquer ou les marquer `local_to_scene` avant de les modifier par instance (vu en phase 2
  avec la traceuse du lion).
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
  libération) ; le peintre applique le côté reçu (`Boss.cote`, setter). **Phase 17 bis** :
  l'annonce du peintre (`Audio.jouer("boss")`, dans `Boss._changer_etat` de l'hôte) ne s'entend
  que chez l'hôte : la faire entendre aux clients (réplique de `Boss.etat`, ou RPC de la manche) ;
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
  ligne 96) tombe pendant l'intro et n'a aucun effet ; le déplacer après `GS.demarrer()` et relancer
  le script à la main (la CI ne le lance pas). Les minuteries `null` du Spawner quand la partie se
  termine pendant l'intro sont corrigées depuis la phase 10 bis (vérifié par
  `tests/bataille_test.gd`). Y verser aussi les captures de l'écran Réseau (script jetable du plan
  de la phase 12 bis, Task 3 : titre avec Multijoueur, liste, IP invalide, refus, hébergement,
  anglais, port des balises occupé) et du salon (plan de la phase 13, Task 5 : hôte seul, salon à 3
  au bouton grisé, bouton actif, six joueurs aux pseudos larges, anglais, vues d'un client) ;
- les tests `--script` peuvent nommer `Territoire` (logique pure, phase 9) et les règles, jamais
  la ville, le lion ni les ennemis (qui nomment des autoloads). Les couleurs relues sur la ville
  se comparent après un passage par une image RGBA8 (`_rgba8` du smoke test) : `set_pixel`
  tronque sur 8 bits, `Color.to_rgba32()` arrondit ;
- **phase 17** (HUD) : la palette de bataille est réglée pour la deutéranopie depuis la phase 11 bis
  (écart OKLab minimal 0,186 entre couleurs pures simulées, vérifié par `tests/unitaires.gd`), mais
  sur la crinière (couleur × luminance du sprite) rouge et vert restent deux kakis que seule la
  clarté sépare, magenta et cyan deux gris bleutés : les vignettes du HUD portent le pseudo, pas
  seulement la couleur, comme l'étiquette au-dessus du lion. Sur le territoire (les trois nuances de
  chaque joueur, `Joueur.nuances`), la confusion se rapproche encore plus entre joueurs différents en
  deutéranopie (magenta pur ≈ cyan foncé 0,028 ; rouge clair ≈ jaune foncé 0,046 ; rouge pur ≈ vert
  foncé 0,047 — M2, revue finale phase 11 bis, garde-fou sur la moyenne des nuances par joueur dans
  `tests/unitaires.gd`) : la propriété d'une cellule se lit au score du HUD (avec le pseudo), jamais
  à sa teinte ;
- **phase 17** : le score d'un joueur se lit sur le territoire de la ville
  (`ville.territoire.cellules_de(joueur.index)`, sur `ville.territoire.nb_peignables` pour un
  pourcentage, comme la manche de `tests/bataille_test.gd`) ; il n'y a pas de `Joueur.cellules`
  (spec §3.1). La couverture du solo reste mesurée en bataille (`GameState.progression`) : le
  peintre et la difficulté des ennemis suivent `Regles.avancement()` depuis la phase 10 bis (le
  temps de la manche en bataille) ; la musique (`Main._on_progression_changee`, encore sur la
  couverture) et le HUD (encore celui du solo en bataille : cœurs, arc-en-ciel, chrono qui monte)
  sont à la phase 17. `int(regles.avancement() × 3)` donne les couches de la spec §8 (arpèges à
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
  (`Lion._on_pare_chocs_area_entered` : recul, secousse) ; un lion distant ne simule jamais de
  choc localement (voir le point de la phase 14 ci-dessus), il ne fait que rejouer la réaction
  visuelle reçue. Seul l'hôte signale le choc aux règles ; l'étourdissement, lui, ne vient que
  des règles de l'hôte (`Joueur.etourdir`) : `PredictionLocale` suspend la prédiction tant que
  `joueur.est_etourdi()` (spec §4.1) ;
- **phase 17 bis** : jouer le « boing » dans `Lion._on_pare_chocs_area_entered`, sur chaque machine
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
  incompatibles. Phase 19 : garder cette règle, ou la remplacer par une constante `PROTOCOLE`
  envoyée dans la demande et comparée avec le même refus `REFUS_VERSION` ;
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
- **phase 19** (README, M8) : le premier `heberger()` déclenche la fenêtre du pare-feu Windows
  Defender sur l'hôte (port 7777), et la première ouverture de l'écran Réseau la déclenche aussi sur
  chaque client (écoute des balises sur le port 7778, phase 12). « Annuler », ou un réseau classé
  Public : l'hôte n'est pas joignable (les clients voient « Pas de réponse de l'hôte. Pare-feu de
  l'hôte ? Réseau Privé ? » après 5 s) ou le client ne voit aucune partie (« Aucune partie trouvée.
  Pare-feu ? Réseau Privé ? Essaie par IP. »). Le README explique comment autoriser LeLion en réseau
  Privé et retirer une règle de blocage, et que deux LeLion sur un même PC ne peuvent pas lister les
  parties tous les deux (« Recherche impossible : port 7778 déjà utilisé… Rejoins par IP. ») ;
- (résolu en phase 14) l'intérim de la phase 13 est fini : la manche est synchronisée ;
- **phase 18** (retour au salon, depuis la phase 13) : `Reseau.ouvrir_salon(niveau)` remet déjà,
  chez l'hôte, `manche_en_cours` à faux (arrivées de nouveau acceptées, la balise l'annonce) et
  personne prêt, et le salon de l'hôte l'appelle en s'ouvrant ; il reste à ramener chaque poste au
  salon (un RPC de l'hôte qui change leur scène) : la table (`Reseau.table_salon`) y est toujours,
  index compactés compris ;
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
- **phase 19** (M7 de la revue finale 14) : en fenêtré, la largeur du 16:9 est gardée et la hauteur
  recalculée (`Regles.appliquer_ecran`) ; sur un écran 1080p, une largeur élargie à 1920 px donne une
  zone client de 1920×1080 plus la barre de titre, qui dépasse la zone utile de Windows (barre des
  tâches, bas de la ville et HUD invisibles) — `SetWindowPos` ne recadre pas. Borner par
  `DisplayServer.screen_get_usable_rect(window_current_screen)` (réduire la largeur pour garder le
  format), puis recentrer si la fenêtre sort de l'écran ;
- **phase 19** (M8 de la revue finale 14, avec les captures) : en réseau, aucun lion n'est dessiné
  pendant le chargement (`Main._preparer_manche_en_reseau` libère celui de la scène avant la
  première image) ; le matériau de teinte, les particules de vomi et les étoiles ne compilent leurs
  shaders qu'à la première image après la barrière, un à-coup sous Windows juste au moment de
  l'intro. Tolérance large (ENet coupe vers ~8 s de silence en session ; mesuré ~35 s pour un
  chargement au maximum de 30 s), d'où la sévérité mineure. Préchauffer pendant le chargement : une
  image avec un lion (et sa gerbe active) hors champ, libéré avant `signaler_scene_chargee` ;
- **phase 17** (chrono de bataille en réseau, précision de la revue finale 14, complète le point
  ci-dessus sur la fin de manche) : à 90 s, le mode intérimaire reste sûr sans le chrono
  (`ReglesBataille.avancement()` dépasse 1, mais le Spawner et le peintre le bornent par `clamp` ;
  aucune fin n'est émise d'un seul côté, aucun écran solo ne s'ouvre) — à dire aux testeurs d'un
  essai LAN avant la phase 17. La fin devra être décidée par l'hôte et envoyée par RPC ; le chrono de
  chaque client démarre à la fin de **sa propre** intro, décalé de la latence : il ne doit rien
  terminer lui-même.
