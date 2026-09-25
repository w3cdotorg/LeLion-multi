# LeLion multi : feuille de route d'implémentation

**Spec :** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`

Le spec couvre plusieurs sous-systèmes (socle, bataille locale, réseau, prédiction, fin de manche,
livraison). Règle du projet (`CLAUDE.md`) : **une phase touche au plus 5 fichiers**, se termine
par les vérifications vertes et attend une validation explicite avant la suivante. Chaque phase a
donc son propre plan détaillé, écrit juste avant son exécution, contre le code réellement produit
par la phase précédente : `docs/superpowers/plans/2026-09-25-phase-NN-<objet>.md`.

## Vérification commune à toutes les phases

Il n'y a ni TypeScript ni ESLint : l'équivalent pour Godot est l'import headless (qui compile tous
les scripts) suivi des tests.

```sh
export PATH="/opt/homebrew/bin:$PATH"
cd ~/Sites/LeLion-multi
godot --headless --import . 2>&1 | grep -E "SCRIPT ERROR|Parse Error|Compile Error" && echo "ÉCHEC COMPILATION"
godot --headless --script tests/unitaires.gd     # à partir de la phase 1
godot --headless --script tests/smoke_test.gd
```

Les deux derniers doivent finir sur `== 0 échec(s) ==` et un code de sortie 0.

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
| 9 | **Territoire** : logique pure de charge et de vol, grille de propriété dans la ville, tampons en cache par jeu de couleurs. | ➕ `Scripts/Territoire.gd` ✏️ `Scripts/Ville.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` | tests verts |
| 10 | **Scène de bataille locale en 16:9** : N lions, ciel et caméra calculés, apparitions relatives au viewport, taille du peintre. Test à 4 lions pilotés dans un seul processus. | ✏️ `Scripts/Main.gd` ✏️ `Scripts/Spawner.gd` ✏️ `Scripts/Boss.gd` ➕ `tests/bataille_test.gd` | ◉ manche à 4 |

### C. Réseau

| # | Objet | Fichiers | Sortie |
|---|---|---|---|
| 11 | **Transport** : autoload `Reseau` (ENet 7777, poignée de main, version, attribution des index et couleurs). | ➕ `Scripts/Reseau.gd` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ➕ `tests/reseau/lancer.sh` ➕ `tests/reseau/joueur.gd` | hôte + 2 clients se connectent, version refusée |
| 12 | **Découverte et écran Réseau** : balise UDP 7778, liste des parties, IP en secours, bouton Multijoueur. | ➕ `Scripts/Decouverte.gd` ➕ `Scenes/EcranReseau.tscn` ➕ `Scripts/EcranReseau.gd` ✏️ `Scripts/Titre.gd` ✏️ `Assets/Traductions/traductions.csv` | ◉ écran Réseau |
| 13 | **Salon** : cartes, couleurs, Prêt, niveau, compte à rebours. | ➕ `Scenes/Salon.tscn` ➕ `Scripts/Salon.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `tests/reseau/joueur.gd` | ◉ salon à 3 |
| 14 | **Manche synchronisée** : `MultiplayerSpawner`, `MultiplayerSynchronizer`, commandes par RPC, événements de tampon, scores diffusés. | ✏️ `Scripts/Main.gd` ✏️ `Scenes/Lion.tscn` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Ville.gd` ✏️ `Scripts/ReglesBataille.gd` | ◉ partie à 2 fenêtres |
| 14 bis | **Pastilles vers `body is Lion`** : base commune des trois pastilles (garde hôte, `body is Lion`, premier arrivé, premier servi). | ➕ `Scripts/Pastille.gd` ✏️ `Scripts/ColorPickup.gd` ✏️ `Scripts/BonusPickup.gd` ✏️ `Scripts/CoeurPickup.gd` ✏️ `tests/smoke_test.gd` | smoke vert |
| 15 | **Test réseau de bout en bout** : 1 hôte + 3 clients headless, empreintes identiques, déconnexion d'un client. Ajouté à la CI. | ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` ✏️ `.github/workflows/ci.yml` | test vert en CI |
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
  phases précédentes change la répartition des fichiers (toujours 5 au plus), comme cela a été
  fait pour les phases 5, 6 et 6 bis.
- Les fichiers `.uid` générés par Godot à côté des nouveaux scripts sont committés avec eux et ne
  comptent pas dans le plafond de 5 fichiers d'une phase.
- `OfflineMultiplayerPeer` est le pair multijoueur par défaut de Godot 4 : le solo tourne déjà
  dessus, aucun code n'est nécessaire (spec §3/§12).
- Phase 3 (Règles) : `Joueur.encaisser_coup` n'a pas de plancher sur `vies` ; les règles doivent
  conserver le garde-fou `partie_en_cours` de GameState (ou un clamp) pour qu'un lion à 0 vie ne
  soit jamais retouché.
- Phase 11 : `GameState.joueur_local()` renvoie `joueurs[0]` (correct en solo seulement) ; il doit
  choisir le joueur dont `id_reseau` correspond à `multiplayer.get_unique_id()`.
- Phases 10 et 14 : tout lion qui n'est pas celui du joueur local doit recevoir `joueur` et
  `commandes` avant `add_child` (en phase 14 via la `spawn_function` du `MultiplayerSpawner`) ;
  sinon il prend en silence le joueur local et le clavier de ce poste.
- Prochaine phase qui touche `.github/workflows/ci.yml` : envelopper chaque lancement godot dans
  `timeout` (une erreur de script bloque le processus headless) et faire échouer le job si la
  sortie contient `SCRIPT ERROR` ou `SHADER ERROR` (une erreur dans un callback de signal, ou dans
  une fonction appelée, ne change pas le code de sortie).
- Phase 16 : `PredictionLocale` lit Input une seule fois par tick physique, l'écrit dans les
  commandes MANUELLES du lion local et envoie exactement cette valeur, numérotée (direction et
  vomir échantillonnés au même tick).
- Phases 14 et 16 : sans paquet d'un client depuis N ms, l'hôte remet à zéro les commandes
  manuelles de son lion.
- Les sous-ressources des scènes instanciées plusieurs fois (formes, matériaux) sont partagées :
  les dupliquer ou les marquer `local_to_scene` avant de les modifier par instance (vu en phase 2
  avec la traceuse du lion).
- phase 10 : les conditions d'apparition (étoile à partir de 2 couleurs, cœurs) passent par les
  règles (par exemple `regles.etoile_peut_apparaitre()`, aucun cœur en bataille) au lieu que le
  Spawner lise le joueur local ;
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
- **phase 9 (obligatoire)** : `Scripts/Ville.gd` met en cache ses tampons par (rayon, nombre de
  couleurs) et non par jeu de couleurs : deux lions ayant autant de couleurs peignent avec les
  tampons du premier (prouvé en revue de phase 6 ; en bataille, chacun a 3 nuances). Mettre les
  tampons en cache par jeu de couleurs (clé rayon + `to_rgba32` de chaque couleur, plusieurs
  entrées), et durcir la vérification du smoke test « la traceuse d'un lion peint avec les
  couleurs de son joueur » en faisant peindre d'abord le lion local avec autant de couleurs que
  l'autre ;
- **phase 11** : `Audio` s'abonne une fois pour toute la session au joueur local (`joueurs[0]`) ;
  quand `joueur_local()` choisira le joueur par `id_reseau`, `Audio` (et tout abonnement pris une
  seule fois) devra se réabonner quand le joueur local change (signal dédié, ou abonnement par
  partie depuis `Main`) ;
- **phase 10** : `Spawner.gd` choisit la prochaine pastille avec `GameState.prochain_index_couleur()`
  (règle du solo) : à faire passer par les règles avec les autres conditions d'apparition.
- **phase 10 (obligatoire avant la première partie de bataille)** : `GameState.configurer_solo()` /
  `configurer_bataille(n)` existent depuis la phase 8 (règles, joueurs redimensionnés en place,
  index et couleurs ; testés). Les appeler **avant** le changement de scène, jamais depuis la scène
  de jeu : `Main._enter_tree` appelle `GameState.nouvelle_partie()`, puis Lion, Spawner, HUD et Main
  s'abonnent à `joueur_local()` dans leur `_ready`. `configurer_bataille(n)` avant la scène de
  bataille, et `configurer_solo()` avant toute partie solo, démo ou arcade lancée depuis le titre
  (sans quoi une partie solo jouée après une bataille garderait les règles et la couleur de la
  bataille) ;
- **phase 14** : les réactions du `Joueur` sont des appels de méthode qui émettent des signaux
  (`debloquer_couleur`, `activer_bonus`, `encaisser_coup`, `gagner_cran`, `etourdir`, et `avancer`
  pour `etourdissement_fini`). Un `MultiplayerSynchronizer` qui écrit les champs bruts n'émettrait
  rien chez les clients (HUD, Audio, Lion muets) : choisir des RPC d'événement qui appellent les
  mêmes méthodes du `Joueur`, ou des setters qui émettent. De même, `GameState._process` ferait
  avancer les copies des clients (`Joueur.avancer`) : l'hôte seul décompte ;
- **préexistant, à corriger dès qu'une phase touche `Scripts/Spawner.gd` ou `tests/screenshots.gd`** :
  `Spawner._on_partie_terminee` appelle `stop()` sur `_timer_soucoupe` / `_timer_coccinelle`, qui
  sont `null` si la partie se termine pendant l'intro (`SCRIPT ERROR` dans `tests/screenshots.gd`) ;
  et le coup de `tests/screenshots.gd` (vers la ligne 96) tombe pendant l'intro et n'a aucun effet.
  Relancer `tests/screenshots.gd` à la main après correction (la CI ne le lance pas) ;
- **la prochaine phase qui touche `Regles.gd`, `ReglesSolo.gd` et `ReglesBataille.gd`** :
  `ReglesBataille.etoile_ramassee` lit `ReglesSolo.DUREE_ETOILE` : les règles de
  bataille ne devraient pas dépendre des règles du solo. Monter `DUREE_ETOILE` dans la base
  `Regles`. De même, `ReglesSolo` répète en ligne le garde-fou
  `partie.partie_en_cours and partie.pret` que `ReglesBataille._manche_en_cours()` a déjà nommé :
  monter `_manche_en_cours()` dans la base `Regles` et le faire utiliser par les deux. Une fois que
  `Scripts/Lion.gd` ne lira plus directement `GameState.DUREE_INVULNERABILITE` (pour le nombre de
  clignotements), descendre cette constante de `GameState` vers `ReglesSolo`, seule règle qui s'en
  sert encore ;
- **phase 10** : le pseudo est une étiquette au-dessus du sprite (38 px au-dessus du lion) : un
  lion collé en haut de l'écran la cache. En bataille, borner `y` à la hauteur de l'étiquette ou la
  passer sous le lion près du bord ;
- **phase 13** : `GameState.configurer_bataille(nb_joueurs)` attribue l'index et la couleur de
  chaque joueur depuis `PALETTE_BATAILLE`, par position ; une fois que le salon attribue les
  couleurs (choix des joueurs), `configurer_bataille` ne doit plus les écraser : lui passer les
  couleurs du salon, par exemple `configurer_bataille(nb_joueurs, couleurs)`. Son `assert` sur le
  nombre de joueurs devra aussi devenir un clamp ou un `push_error` une fois que c'est le salon qui
  l'appelle (un salon mal formé ne doit pas planter la partie) ;
- **phase 11** : la palette de bataille (planche de la phase 7 : rouge `(0.90, 0.16, 0.16)`, bleu
  `(0.16, 0.39, 0.95)`, jaune `(0.98, 0.82, 0.10)`, vert `(0.18, 0.78, 0.25)`, magenta
  `(0.90, 0.20, 0.85)`, cyan `(0.10, 0.85, 0.90)`) est depuis la phase 8 la constante unique
  `GameState.PALETTE_BATAILLE`, attribuée par index par `configurer_bataille(n)` ; le salon
  l'attribuera au choix des joueurs. En simulation
  deutéranopie, rouge, vert et jaune se confondent (kaki) et magenta et cyan se rapprochent, et le
  jaune est proche du visage du lion : différencier les luminosités (vert plus sombre, jaune plus
  clair, par exemple) et compter aussi sur le pseudo et les vignettes du HUD. Attribuer la couleur
  **avant** l'ajout du lion à l'arbre, ou rappeler `Lion.appliquer_apparence()` (aperçu du salon en
  phase 13) ;
- **phase 9** : `Joueur.cellules_volees` existe depuis la phase 8 (remis à zéro par
  `reinitialiser`, jamais incrémenté) : le territoire l'incrémente quand un tampon vole une
  cellule. En bataille, les couleurs débloquées d'un joueur sont ses trois nuances (données par
  `Regles.couleurs_de_depart`) : c'est ce que reçoivent la traceuse et `Ville.peindre` ;
- **phases 13 et 14** : `Lion.appliquer_apparence()` se rappelle à la main quand la couleur ou le
  pseudo d'un joueur change. Quand ces changements viendront du réseau (salon, synchronisation),
  donner à `Joueur.couleur` et `Joueur.pseudo` des setters qui émettent un signal
  `apparence_changee`, auquel le lion s'abonne ;
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
