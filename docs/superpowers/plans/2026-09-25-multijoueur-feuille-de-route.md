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
| 14 | **Manche synchronisée** : `MultiplayerSpawner`, `MultiplayerSynchronizer`, commandes par RPC, événements de tampon, scores diffusés. | ✏️ `Scripts/Main.gd` ✏️ `Scenes/Lion.tscn` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Ville.gd` ✏️ `Scripts/ReglesBataille.gd` | ◉ partie à 2 fenêtres |
| 14 bis | **Pastilles vers `body is Lion`** : base commune des trois pastilles (garde hôte, `body is Lion`, premier arrivé, premier servi). | ➕ `Scripts/Pastille.gd` ✏️ `Scripts/ColorPickup.gd` ✏️ `Scripts/BonusPickup.gd` ✏️ `Scripts/CoeurPickup.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
| 15 | **Test réseau de bout en bout** : 1 hôte + 3 clients headless, empreintes identiques, déconnexion d'un client. Le test réseau tourne en CI depuis la phase 11 ter (`ci.yml` n'est plus à toucher). | ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` | test vert en CI |
| 16 | **Prédiction du lion local** (4 bis) : correction douce, commandes numérotées et redondantes, interpolation, simulateur de latence. | ➕ `Scripts/PredictionLocale.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Lion.gd` ✏️ `tests/reseau/joueur.gd` | test vert sous 80 ms / 40 ms / 5 % |

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
- phase 14 : unifier les sons de ramassage. L'étoile et le cœur jouent leur son dans le gestionnaire
  réservé à l'hôte (un client n'entendrait rien) alors que la pastille passe par `Audio` et le signal
  du joueur local : tout passer par `Audio` et les signaux du joueur local (`bonus_change(true)`,
  `vies_changees` en hausse) et retirer `Audio.jouer` des pastilles ;
- **phase 14 bis** : le gestionnaire de contact est copié dans `ColorPickup`, `BonusPickup` et
  `CoeurPickup` ; en faire une base commune `Pastille` (garde hôte, `body is Lion`, premier
  arrivé, premier servi). La désapparition répliquée reste à la phase 14 ;
- à la sortie des tests headless, Godot signale des ressources audio encore utilisées (sons qui
  jouent au moment de `quit()`) : bruit sans effet sur le code de sortie ; `Audio` pourrait arrêter
  ses lecteurs dans `_exit_tree` ;
- **phase 14 bis (pastilles)** : comme la base `Ennemi` de la phase 8 ter (`Scripts/Ennemi.gd`),
  tester `body is Lion` dans le gestionnaire de contact commun au lieu de supposer `body.joueur`.
  Les tests `--script` (compilés avant les autoloads) continuent de typer les lions en `Node` /
  `CharacterBody2D`, et ne nomment ni `Lion`, ni `Ennemi`, ni `Pastille` : ces scripts nomment
  `GameState` (`Lion.gd` aussi `Audio`). Le smoke test vérifie l'héritage d'un script par
  `load(...).get_base_script().resource_path`. Le groupe « lion » ne sert alors plus qu'au
  Spawner ;
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
- **phase 14 bis** (qui touche `tests/smoke_test.gd` ; la phase 12 bis, première à y revenir, les a
  laissés à la phase qui réécrit ces sections de contact) : petits durcissements issus de la revue de
  la phase 8 ter : vérifier que `create_client` renvoie `OK` avant le test de la garde hôte ;
  donner à l'intrus du groupe « lion » un script avec un champ `joueur` pour que la vérification
  échoue d'elle-même sous l'ancien typage ; vérifier la direction du recul (horizontale) après le
  contact continu du peintre au lieu d'appeler `origine_du_coup` directement ; remettre le peintre
  au repos après sa vérification ;
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
- prochaine phase qui touche `Scripts/Boss.gd` : le commentaire de `acceleration_max` (« quand la
  ville est presque peinte ») date d'avant la phase 10 bis : « facteur de durée en fin de partie
  (avancement des règles) » ;
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
- **phase 14** (intérim depuis la phase 13) : quand l'hôte démarre la partie, chaque poste branche la
  même table (`GameState.configurer_bataille_reseau`, index compactés) et charge `Main.tscn`, qui
  se joue alors localement : l'hôte simule tous les lions (les autres immobiles, commandes
  manuelles), un client a son lion local en double et aucun lion d'hôte (point « Phase 14 » sur
  `$Lion` plus haut), peinture et ennemis y sont inertes (`multiplayer.is_server()` faux). Échap
  ouvre encore la pause du solo ; « Revenir au menu » ramène au titre, qui quitte le réseau (les
  autres voient partir ce joueur, ou l'hôte). Un `Reseau.hote_perdu` reçu en manche n'est écouté
  par personne : la phase 14 affiche « L'hôte a quitté la partie » et ramène au titre (spec §9) ;
- **phase 18** (retour au salon, depuis la phase 13) : `Reseau.ouvrir_salon(niveau)` remet déjà,
  chez l'hôte, `manche_en_cours` à faux (arrivées de nouveau acceptées, la balise l'annonce) et
  personne prêt, et le salon de l'hôte l'appelle en s'ouvrant ; il reste à ramener chaque poste au
  salon (un RPC de l'hôte qui change leur scène) : la table (`Reseau.table_salon`) y est toujours,
  index compactés compris ;
- **phase 14** (hôte perdu en manche, phase 12 bis) : sur l'écran Réseau, « L'hôte a quitté la
  partie » ramène à son accueil (Écart 3 du plan 12 bis) ; en manche, spec §9 : message
  (`RESEAU_HOTE_PERDU`) puis retour au titre ;
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
