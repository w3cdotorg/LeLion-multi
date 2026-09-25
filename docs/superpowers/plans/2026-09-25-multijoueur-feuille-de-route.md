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
| 8 | **Lion de bataille** : crans, gerbe en 3 nuances, 3 zones de contact sur la parabole, étourdissement 1,5 s / 2,5 s + 1 s d'immunité, barbouillage, auto-tamponneuses. | ✏️ `Scripts/Joueur.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scenes/Lion.tscn` ➕ `Scripts/ReglesBataille.gd` ✏️ `tests/unitaires.gd` | tests verts |
| 9 | **Territoire** : logique pure de charge et de vol, grille de propriété dans la ville. | ➕ `Scripts/Territoire.gd` ✏️ `Scripts/Ville.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `tests/unitaires.gd` | tests verts |
| 10 | **Scène de bataille locale en 16:9** : N lions, ciel et caméra calculés, apparitions relatives au viewport, taille du peintre. Test à 4 lions pilotés dans un seul processus. | ✏️ `Scripts/Main.gd` ✏️ `Scripts/Spawner.gd` ✏️ `Scripts/Boss.gd` ➕ `tests/bataille_test.gd` | ◉ manche à 4 |

### C. Réseau

| # | Objet | Fichiers | Sortie |
|---|---|---|---|
| 11 | **Transport** : autoload `Reseau` (ENet 7777, poignée de main, version, attribution des index et couleurs). | ➕ `Scripts/Reseau.gd` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ➕ `tests/reseau/lancer.sh` ➕ `tests/reseau/joueur.gd` | hôte + 2 clients se connectent, version refusée |
| 12 | **Découverte et écran Réseau** : balise UDP 7778, liste des parties, IP en secours, bouton Multijoueur. | ➕ `Scripts/Decouverte.gd` ➕ `Scenes/EcranReseau.tscn` ➕ `Scripts/EcranReseau.gd` ✏️ `Scripts/Titre.gd` ✏️ `Assets/Traductions/traductions.csv` | ◉ écran Réseau |
| 13 | **Salon** : cartes, couleurs, Prêt, niveau, compte à rebours. | ➕ `Scenes/Salon.tscn` ➕ `Scripts/Salon.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Assets/Traductions/traductions.csv` ✏️ `tests/reseau/joueur.gd` | ◉ salon à 3 |
| 14 | **Manche synchronisée** : `MultiplayerSpawner`, `MultiplayerSynchronizer`, commandes par RPC, événements de tampon, scores diffusés. | ✏️ `Scripts/Main.gd` ✏️ `Scenes/Lion.tscn` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Ville.gd` ✏️ `Scripts/ReglesBataille.gd` | ◉ partie à 2 fenêtres |
| 15 | **Test réseau de bout en bout** : 1 hôte + 3 clients headless, empreintes identiques, déconnexion d'un client. Ajouté à la CI. | ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` ✏️ `.github/workflows/ci.yml` | test vert en CI |
| 16 | **Prédiction du lion local** (4 bis) : correction douce, commandes numérotées et redondantes, interpolation, simulateur de latence. | ➕ `Scripts/PredictionLocale.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Lion.gd` ✏️ `tests/reseau/joueur.gd` | test vert sous 80 ms / 40 ms / 5 % |

### D. Fin de manche et livraison

| # | Objet | Fichiers | Sortie |
|---|---|---|---|
| 17 | **HUD de bataille** : vignettes, couronne, chrono de 90 s, tic, musique sur le temps restant. | ➕ `Scenes/HUDBataille.tscn` ➕ `Scripts/HUDBataille.gd` ✏️ `Scripts/Audio.gd` ✏️ `Scripts/ReglesBataille.gd` ✏️ `Assets/Traductions/traductions.csv` | ◉ HUD à 6 |
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
- Phase 8 : réconcilier le `invulnerable_restant` du solo (1,5 s) avec l'`immunite_restante` de la
  bataille (1 s) plutôt que d'ajouter un mécanisme parallèle.
- Phase 11 : `GameState.joueur_local()` renvoie `joueurs[0]` (correct en solo seulement) ; il doit
  choisir le joueur dont `id_reseau` correspond à `multiplayer.get_unique_id()`.
- Phases 10 et 14 : tout lion qui n'est pas celui du joueur local doit recevoir `joueur` et
  `commandes` avant `add_child` (en phase 14 via la `spawn_function` du `MultiplayerSpawner`) ;
  sinon il prend en silence le joueur local et le clavier de ce poste.
- Prochaine phase qui touche `.github/workflows/ci.yml` : envelopper chaque lancement godot dans
  `timeout` (une erreur de script bloque le processus headless) et faire échouer le job si la
  sortie contient `SCRIPT ERROR` ou `SHADER ERROR`.
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
- phase 8 ou 14 : le gestionnaire de contact est copié dans `ColorPickup`, `BonusPickup` et
  `CoeurPickup` ; en faire une base commune quand une de ces phases doit les modifier tous
  (`body is Lion`, désapparition répliquée) ;
- à la sortie des tests headless, Godot signale des ressources audio encore utilisées (sons qui
  jouent au moment de `quit()`) : bruit sans effet sur le code de sortie ; `Audio` pourrait arrêter
  ses lecteurs dans `_exit_tree` ;
- phase 8 : `ReglesBataille.lion_touche_par_ennemi` ignore un joueur déjà étourdi ou immunisé (le
  peintre signale le contact à chaque frame de chevauchement ; sinon l'étourdissement de 2,5 s
  redémarrerait sans fin) ;
- phase 8 : ajouter `class_name Lion` et tester `body is Lion` dans les gestionnaires de
  contact au lieu de supposer `body.joueur`. Les tests `--script` (compilés avant les autoloads)
  continuent de typer les lions en `Node` / `CharacterBody2D`, jamais `Lion` : `Lion.gd` nomme
  `GameState` et `Audio` ;
- phase 14 : le Spawner ne tourne que sur l'hôte ; ennemis et pastilles sont répliqués par l'hôte
  (`MultiplayerSpawner`), jamais simulés côté client (`Coccinelle._ready` tire des valeurs
  aléatoires) ; les gestionnaires de contact sont déjà inertes côté client
  (`multiplayer.is_server()`, phase 4) ;
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
- **phase 8 ou 10 (obligatoire avant la première partie de bataille)** : la mise en place et le
  démontage d'un mode sur `GameState` doivent précéder `Main._enter_tree` (Main y appelle
  `GameState.nouvelle_partie()`, puis Lion, Spawner, HUD et Main s'abonnent à `joueur_local()` dans
  leur `_ready`). Ajouter `GameState.configurer_solo()` / `configurer_bataille(n)`, appelés **avant**
  le changement de scène (règles, nombre de joueurs remplis en place, couleurs et pseudos), avec un
  test unitaire : bataille puis solo rend `ReglesSolo` et un seul joueur, sans couleur (le lion du
  solo retrouve son rendu d'origine) ;
- **phase 14** : les réactions du `Joueur` sont des appels de méthode qui émettent des signaux
  (`debloquer_couleur`, `activer_bonus`, `encaisser_coup`). Un `MultiplayerSynchronizer` qui écrit
  les champs bruts n'émettrait rien chez les clients (HUD, Audio, Lion muets) : choisir des RPC
  d'événement qui appellent les mêmes méthodes du `Joueur`, ou des setters qui émettent. De même,
  `GameState._process` ferait avancer les copies des clients (`Joueur.avancer`) : l'hôte seul décompte ;
- **préexistant, à corriger dès qu'une phase touche `Scripts/Spawner.gd` ou `tests/screenshots.gd`** :
  `Spawner._on_partie_terminee` appelle `stop()` sur `_timer_soucoupe` / `_timer_coccinelle`, qui
  sont `null` si la partie se termine pendant l'intro (`SCRIPT ERROR` dans `tests/screenshots.gd`) ;
  et le coup de `tests/screenshots.gd` (vers la ligne 96) tombe pendant l'intro et n'a aucun effet.
  Relancer `tests/screenshots.gd` à la main après correction (la CI ne le lance pas) ;
- **phase 8** : le barbouillage passe par les uniformes `barbouillage_couleur` /
  `barbouillage_force` du matériau du lion (`Shaders/Lion.gdshader`, déjà prêts à 0). Ce matériau
  n'existe que si le joueur a une couleur, ce qui est toujours vrai en bataille ;
- **phase 10** : le pseudo est une étiquette au-dessus du sprite (38 px au-dessus du lion) : un
  lion collé en haut de l'écran la cache. En bataille, borner `y` à la hauteur de l'étiquette ou la
  passer sous le lion près du bord ;
- **phase 11** : la palette de bataille (planche de la phase 7 : rouge `(0.90, 0.16, 0.16)`, bleu
  `(0.16, 0.39, 0.95)`, jaune `(0.98, 0.82, 0.10)`, vert `(0.18, 0.78, 0.25)`, magenta
  `(0.90, 0.20, 0.85)`, cyan `(0.10, 0.85, 0.90)`) devient une constante unique. En simulation
  deutéranopie, rouge, vert et jaune se confondent (kaki) et magenta et cyan se rapprochent, et le
  jaune est proche du visage du lion : différencier les luminosités (vert plus sombre, jaune plus
  clair, par exemple) et compter aussi sur le pseudo et les vignettes du HUD. Attribuer la couleur
  **avant** l'ajout du lion à l'arbre, ou rappeler `Lion.appliquer_apparence()` (aperçu du salon en
  phase 13) ;
