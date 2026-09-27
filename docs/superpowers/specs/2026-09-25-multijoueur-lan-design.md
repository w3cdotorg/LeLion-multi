# LeLion multi : bataille de peinture en LAN

Date : 2026-09-25 · Statut : validé en brainstorming, à relire avant le plan

## 1. Objectif

Transformer LeLion en jeu de **bataille de peinture pour 2 à 6 joueurs en réseau local**, chacun
sur son PC Windows. Chaque lion a sa couleur, vomit dans sa couleur et cherche à posséder la plus
grande part de la ville en 90 secondes. Les lions se barbouillent et s'étourdissent mutuellement,
et se rentrent dedans façon auto-tamponneuses.

Le **mode solo reste jouable** avec ses sensations actuelles (cœurs, arc-en-ciel, seuils 85/90/95 %,
arcade, attract mode, records).

Contexte d'usage : une petite LAN entre amis, tous sous Windows, en 16:9, **en Wi-Fi** (gigue
et pertes de paquets à prévoir).

### Hors périmètre (YAGNI)

- Navigateur / export Web pour le multi (ENet n'existe pas dans un navigateur). L'abstraction
  `MultiplayerPeer` laisse la porte ouverte à un relais WebSocket plus tard.
- macOS et Linux pour le multi. Le code reste portable, seul le preset Windows est livré.
- Bots IA, plusieurs joueurs sur un même PC, arrivée en cours de manche, migration d'hôte,
  internet (hors LAN), commandes tactiles en multi.
- Rembobinage du monde (autres lions, ennemis : seul le lion local d'un client repart du dernier
  état de l'hôte et rejoue ses propres commandes, voir 4.1) et prédiction des lions distants (ils
  sont interpolés).
- Enchaînement de manches en « 3 manches gagnantes » (possible plus tard).

## 2. Décisions de jeu

| Sujet | Décision |
|---|---|
| Vomi qui touche un autre lion | **Étourdit 1,5 s** : immobile, ne vomit plus, recul, tête barbouillée de la couleur de l'agresseur, étoiles. Puis **1 s d'immunité** (clignotement). |
| Couleurs de vomi | **Une couleur par joueur**, rendue en 3 nuances (foncée, pure, claire). |
| Pastilles de couleur | Donnent **+1 cran de gerbe** (1 à 7 crans ; rayon de peinture de 16 px au premier cran, 5 px de plus par cran, 46 px au septième). Départ à 1 cran. Premier arrivé, premier servi. En solo, chaque couleur débloquée donne aussi un cran : les rayons du solo ne changent pas. En bataille (phase 17, réglé sans essai à 4-6) : 2 à la fois de 2 à 3 joueurs, 3 de 4 à 6, une toutes les 4 s sous ce plafond, qui expire au bout de 12 s si personne ne la prend, loin du centre des lions ; en solo, une à la fois, 6 s après le départ de la précédente. |
| Étoile XXL | Inchangée, par joueur (gerbe × 2 pendant 8 s). |
| Cœurs | Aucun en multi. |
| Ennemis (soucoupe, coccinelle, peintre) | Étourdissent **2,5 s** (sans barbouillage), puis **3 s de répit** (l'immunité : le temps de fuir le peintre, qui couvre la bande de peinture ; phase 17). Le peintre se repose deux fois plus longtemps qu'en solo entre deux passages. |
| Fin de manche | **Chrono de 90 s**, personne n'est éliminé. Le plus de cellules gagne, ex æquo possibles. Seul le chrono de l'hôte termine la manche ; chaque client reçoit sa fin (phase 17). |
| Collisions entre lions | **Auto-tamponneuses** : blocage physique + impulsion de recul proportionnelle à la vitesse relative. Un lion étourdi peut être poussé. |
| Viewport multi | **2000×1125 (16:9)**. Le solo garde 2000×648. |
| Palette | Rouge `(0.81, 0.14, 0.01)`, bleu `(0.24, 0.38, 1.00)`, jaune `(1.00, 0.91, 0.09)`, vert `(0.19, 0.82, 0.34)`, magenta `(0.87, 0.26, 0.73)`, cyan `(0.23, 0.92, 1.00)` (`GameState.PALETTE_BATAILLE`, phase 11 bis). En deutéranopie simulée (Machado 2009), l'écart OKLab minimal entre deux couleurs pures est de 0,186 (0,115 avant réglage) ; sur la crinière, rouge et vert, magenta et cyan ne s'y distinguent que par la clarté : le pseudo accompagne toujours la couleur (étiquette du lion, vignettes du HUD). Sur le territoire de la ville, peint dans les trois nuances de chaque joueur (foncée/pure/claire, `Joueur.nuances`), des paires de nuances de joueurs différents se rapprochent encore plus en deutéranopie : magenta pur ≈ cyan foncé (écart OKLab 0,028), rouge clair ≈ jaune foncé (0,046), rouge pur ≈ vert foncé (0,047). La propriété d'une cellule ne se lit donc pas à sa teinte mais au score du HUD, qui porte le pseudo. |

## 3. Architecture

Principe : **un socle commun, des règles interchangeables, un seul chemin d'autorité**.

Tout le jeu est écrit comme si un hôte faisait autorité. En solo, l'arbre utilise un
`OfflineMultiplayerPeer` : le joueur unique est son propre hôte, `is_server()` est vrai, les RPC
s'exécutent localement. Il n'existe donc pas de branche « réseau / hors réseau » dans la logique
de jeu.

### 3.1 Unités

| Unité | Rôle | Dépend de |
|---|---|---|
| `Joueur` (Resource) | État d'un lion : `id_reseau`, `index` (0-5), `pseudo`, `couleur`, `crans`, `bonus_restant`, `etourdi_restant`, `invulnerable_restant` (l'immunité : une seule minuterie pour le solo et la bataille, voir §5), stats (`etourdissements_infliges`, `cellules_volees`, `chocs`) ; son score (les cellules qu'il possède) est tenu par le territoire de la ville (§6), pas par le `Joueur`. En solo il porte aussi `couleurs_debloquees`, `vies`, et sa `couleur` reste transparente (pas de teinte). | rien |
| `GameState` (autoload, allégé) | État de **partie** : niveau, difficulté, chrono, `pret`, `partie_en_cours`, arcade, démo, liste des `Joueur`. Signaux de partie. | `Joueur` |
| `Commandes` (RefCounted) | Interface `direction() -> Vector2`, `vomir() -> bool`. Deux sources : `LOCALES` (actions InputMap de ce poste) et `MANUELLES` (valeurs écrites par un tiers : pilote de l'attract mode, tests, prédiction du lion local d'un client, et côté hôte les commandes reçues d'un client). Depuis la phase 16, le format des paquets de commandes (la dernière et les 3 précédentes, numérotées) et, chez l'hôte, la file des commandes d'un client : une appliquée par tick, dans l'ordre, jamais deux fois. | Input |
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

### 3.2 Flux d'une frame (bataille)

1. Chaque client applique ses commandes à son lion **immédiatement** (prédiction), puis les envoie
   à l'hôte, numérotées, avec les 3 précédentes, par RPC `unreliable` (non ordonnée : un Wi-Fi qui
   réordonne une rafale de rattrapage ne doit pas faire sauter à tort des numéros manquants) à chaque
   frame physique. L'hôte les écrit dans les commandes manuelles du lion correspondant.
2. L'hôte simule tous les lions (`move_and_slide`, collisions entre lions, ennemis, pastilles).
3. Les traceuses de l'hôte détectent la ville et les autres lions. Les contacts remontent aux
   `Regles`.
4. Les tampons de peinture sont appliqués sur l'hôte et **diffusés sous forme d'événements**.
5. `MultiplayerSynchronizer` réplique l'état de chaque lion (phase 16 : un seul champ,
   `Lion.etat_reseau` : instant de l'hôte, numéro de la dernière commande appliquée, position, vitesse
   commandée, recul, orientation, 33 octets, à 83 Hz au plus) et son état de vomi (les crans passent
   en événement avec les autres réactions du joueur) ; les clients y interpolent les lions distants
   et y recalent leur lion local (4.1). Ennemis et pastilles sont répliqués de même (position ; côté du peintre, couleur
   d'une pastille). L'étourdissement, lui, ne se réplique pas comme un
   champ brut : il voyage en événement (RPC hôte → clients qui appelle `Joueur.etourdir` avec la
   couleur du barbouillage), conformément au point de vigilance transverse de la phase 14 (feuille
   de route) sur les réactions du `Joueur`.

## 4. Réseau et salon

- **Transport** : `ENetMultiplayerPeer`, port UDP **7777**, 6 pairs maximum (hôte compris).
  Canal 0 : état et commandes. Canal 1 (fiable ordonné) : tampons de peinture.
- **Redondance des commandes** : chaque paquet de commandes porte la commande courante et les 3
  précédentes (numérotées). L'hôte ignore les numéros déjà vus : un paquet Wi-Fi perdu ne fait
  pas sauter le lion. Il met chaque commande neuve dans une file et en applique une par tick,
  dans l'ordre (8 au plus en attente : au-delà, les plus anciennes sont sautées).
- **Interpolation** : les lions distants sont affichés avec 100 ms de retard (6 ticks), interpolés
  entre les états reçus : plus que la gigue (40 ms) et deux états perdus de suite.
- **Découverte** : l'hôte émet toutes les secondes une balise UDP broadcast sur le port **7778**
  (vers 255.255.255.255 et la diffusion dirigée a.b.c.255 de chaque réseau privé de l'hôte, en
  supposant un /24 : sous Windows, la diffusion limitée ne sort que par une interface). Cette
  supposition d'un /24 ne tient pas sur un réseau maillé en mode routeur (TP-Link Deco, eero : /22
  typique), où `a.b.c.255` n'est alors qu'une adresse unicast du sous-réseau, pas une diffusion ;
  Godot ne donnant pas le masque de sous-réseau, il reste la saisie par IP (revue finale de la
  phase 12, constat 3 ; feuille de route, phase 19) :
  `LELION|<version>|<port de jeu>|<nb joueurs>|<places>|<manche 0/1>|<index du niveau>|<pseudo hôte>`.
  Le pseudo, seul texte libre, vient en dernier (il peut contenir `|`) ; le port de jeu dit au client
  où rejoindre ; places et manche en cours permettent de griser une partie pleine ou en cours. Une
  balise invalide (autre programme, champs hors plage) est ignorée, 16 parties au plus. L'écran
  Réseau écoute et liste les parties (expiration après 3 s sans balise). Saisie d'IP en secours
  (IPv4 seulement : un nom se résoudrait en bloquant le jeu).
- **Poignée de main** : le client envoie version + pseudo. Version différente : refus avec message
  « Version différente de l'hôte (x.y) ». Salon plein ou manche en cours : refus explicite.
  Elle passe par l'authentification de `SceneMultiplayer` (octets bruts avant tout RPC : deux
  versions différentes se comprennent encore assez pour se refuser). La version est
  `application/config/version`. L'hôte refuse dans l'ordre : demande mal formée (autre programme),
  version différente, manche en cours, partie pleine ; il inscrit l'accepté au moment de répondre
  (deux demandes simultanées ne prennent pas la même place), lui donne le plus petit index libre et
  la première couleur libre de la palette, et coupe son pseudo à 12 caractères. Un refusé ferme
  lui-même la connexion après avoir lu la raison (couper du côté de l'hôte viderait la file d'envoi
  d'ENet, raison comprise) ; un pair muet est coupé au bout de 3 s. Après un refus, un échec ou le
  départ de l'hôte, le poste revient de lui-même hors réseau (`OfflineMultiplayerPeer`) avant de le
  signaler (`Reseau`, phase 11).
- **Parcours** : Titre → *Multijoueur* (bouton en bas à droite, voisin de droite de *Jouer*) →
  écran Réseau, en 16:9 (pseudo mémorisé dans `Scores`, 12 caractères au plus, *Héberger*, liste
  des parties où les pleines, en cours ou d'une autre version sont grisées avec la raison,
  *Rejoindre par IP*, IPv4 seulement) → **Salon**. Le titre remet toujours le poste hors réseau
  (`Reseau.quitter()`) avant le solo.
- **Salon** : 6 cartes synchronisées par l'hôte (pseudo, aperçu du lion teinté, état Prêt, badges
  « HÔTE » et « TOI » ; une place seulement réservée par une poignée de main en cours n'a pas de
  carte). Gauche/droite change de couleur parmi les libres (celles des places réservées sont
  prises), l'hôte arbitre les conflits ; la couleur d'un joueur prêt est figée. L'hôte choisit le
  niveau (haut/bas, en boucle, à tout moment) ; la balise l'annonce. Vomir bascule Prêt. Pas de
  compte à rebours (décision de l'utilisateur du 26/09 : la manche s'ouvre déjà sur l'intro « Prêt ?
  Vomissez ! ») : l'hôte seul a un bouton « Démarrer la partie » (souris, Tab, Start), actif quand au
  moins 2 joueurs sont arrivés, tous prêts, sans place encore réservée ; grisé, il dit pourquoi
  (« Il faut au moins 2 joueurs pour démarrer. », « Un joueur est en train d'arriver… », « Tous les
  joueurs doivent être prêts. »), et les clients voient cette raison ou « Tout le monde est prêt :
  l'hôte peut démarrer. ». Un appui lance aussitôt la manche ; l'hôte revérifie au moment même (un
  joueur parti ou repassé non prêt dans la même image : refusé, le bouton se regrise). Il pose la
  manche en cours (plus aucune arrivée), compacte les index sur 0..n-1 et lance la manche : chaque
  poste branche les règles de bataille et la même table des joueurs (identifiant, pseudo et couleur
  de chaque index, `GameState.configurer_bataille_reseau`), puis charge la scène de jeu. Retour
  (Échap, B) quitte le salon pour l'écran Réseau. Aucun contrôle du salon ne prend le focus : une
  action n'agit qu'à l'appui (ni répétition du clavier, ni stick tenu).
- **Commandes** : chaque joueur utilise les commandes actuelles de son PC (clavier ou manette).
- **Pause** : aucune en réseau. Échap / Start ouvre un menu local (Reprendre, Quitter la partie)
  pendant que le jeu continue.
- **Déconnexions** :
  - hôte perdu : message « L'hôte a quitté la partie », puis retour à l'écran Réseau depuis le salon
    (on peut aussitôt rejoindre une autre partie), au titre depuis une manche ;
  - client perdu en salon : sa carte se libère ;
  - client perdu en manche : son lion disparaît, ses cellules restent, il reste au classement en
    grisé (l'hôte annonce son départ à chaque client, phase 17 ; un exclu de la barrière aussi) ;
  - client qui n'a pas chargé la scène de jeu 20 s après le lancement (barrière de chargement) :
    exclu, l'hôte le déconnecte, la manche commence sans lui (phase 14) ;
  - un départ volontaire est un DISCONNECT fiable d'ENet, renvoyé jusqu'à son accusé de réception ;
    un poste muet est considéré parti après 3 à 8 s, 20 à 30 s pendant le chargement de la manche.

### 4.1 Prédiction du lion local

Objectif : pas de délai perceptible entre la touche et le mouvement de son propre lion, même avec
une gigue Wi-Fi de 30 à 100 ms. Sans prédiction, le retard ressenti serait de 80 à 150 ms
(aller-retour + tampon d'interpolation + gigue).

- **Simulation locale** : le client déplace son lion avec ses commandes dès la frame courante, avec
  exactement le même code de déplacement que l'hôte (`Lion.avancer` : accélération, chocs, bornes de
  l'écran). Il lit ses actions une fois par tick, les numérote et les garde jusqu'à ce que l'hôte les
  ait appliquées (le numéro de la dernière appliquée voyage dans l'état du lion).
- **Recalage et rejeu** : à chaque état neuf de l'hôte, au tick physique suivant (jamais pendant le
  sondage réseau), le client repart de cet état (position, vitesse commandée, recul, orientation) et
  rejoue les commandes que l'hôte n'a pas encore appliquées. Seul le lion local rejoue ; le monde
  n'est pas rembobiné.
- **Correction douce** : l'écart entre l'ancienne prédiction et la nouvelle passe dans un décalage
  d'affichage, amorti de 95 % en 120 ms (constante de temps 40 ms) ; au-delà de 200 px (téléportation,
  désynchronisation grave) : recalage immédiat. Pas de zone morte sous 4 px : l'état physique est
  toujours recalé (vitesse et recul compris), seul l'affichage glisse. Les tests mesurent l'erreur de
  prédiction : la position de l'hôte après une commande, comparée à celle que le client avait prédite
  au tick où il l'a lue.
- **Décisions de l'hôte** : étourdissement, recul d'un coup et fin de manche s'appliquent à
  réception, et arrivent dans ses états. Pendant un étourdissement, le client applique la règle de
  l'hôte (commandes ignorées) à ses pas et à ses rejeux : le lion suit l'hôte.
- **Chocs entre lions** : le client simule le choc de son lion contre la position affichée des
  autres, pour un « boing » immédiat, et le rejoue tant que l'hôte ne l'a pas. L'hôte fait foi, la
  correction douce absorbe l'écart.
- **Gerbe** : les particules du lion local partent dès l'appui (visuel seul). La peinture reste
  décidée par l'hôte ; les 0,6 s de vol du jet masquent la latence.
- **Simulateur de latence** (tests, contrôle à la main) : un relais UDP entre les clients et l'hôte
  d'un même poste (`tests/reseau/relais.gd -- --ecoute=… --vers=… --latence=80 --gigue=40
  --pertes=5`), qui retarde, mélange et jette les datagrammes d'ENet dans les deux sens, sous la
  couche d'envoi : comme en Wi-Fi, un message fiable perdu est renvoyé. Aucun code dans le jeu livré.

## 5. Lion

- **Teinte** : seule la crinière prend la couleur du joueur. Le shader `Lion.gdshader` déduit le
  masque du sprite lui-même, pixel par pixel : la crinière est dans les teintes du violet au rouge,
  le visage dans l'orange et le jaune (exclu par sa teinte), la langue et les reflets sont trop
  clairs, le contour trop sombre. Un seul shader vaut donc pour les deux sprites (repos et vomi),
  sans masque généré. Il mélange `original` et `couleur_joueur × min(1, luminance × gain)` selon
  le masque (la crinière est sombre : sans gain, elle noircit). Paramètres `barbouillage_couleur`
  et `barbouillage_force` pour l'étourdissement. Un joueur sans couleur (alpha 0, le solo) laisse
  le sprite sans matériau. **Repli** si le masque est laid : rotation de teinte de toute la tête.
- **Pseudo** affiché au-dessus du lion, dans sa couleur, pour un joueur qui a une couleur et un
  pseudo : en multi seulement, puisque le joueur du solo n'a pas de couleur.
- **Gerbe** : un émetteur par couleur débloquée, en éventail. En bataille, les règles donnent à
  chaque joueur, au départ de la partie, ses trois nuances (foncée, pure, claire) comme couleurs
  débloquées : 3 émetteurs, et la traceuse peint dans ces nuances. Le rayon de peinture suit les
  crans (§2).
- **Traceuses** : la traceuse de peinture reste au point de chute. En bataille, **3 zones de
  contact** le long de la parabole (même physique que les particules, à 0,2, 0,4 et 0,6 s de vol :
  la dernière au point de chute) détectent le corps des autres lions (63 px) pendant le vomi.
- **Étourdissement** : commandes ignorées, recul, barbouillage, étoiles qui tournent. L'immunité
  réutilise le clignotement actuel. Étourdissement et immunité partagent la minuterie
  d'invulnérabilité du solo : `Joueur.etourdir` la règle sur la durée de l'étourdissement plus
  1 s (3 s de répit après un ennemi en bataille, phase 17), et les règles ignorent un joueur
  étourdi ou invulnérable (le peintre et la gerbe signalent leur contact à chaque frame).
- **Collisions** : les lions partagent une couche de collision dédiée (couche 5) : un pare-chocs
  (`Area2D`) de 45 px au lieu des 63 px du corps. Le corps reste sur la couche 1, où ennemis et
  pastilles le détectent, et ne heurte plus rien (masque 0). Au premier contact, impulsion `recul`
  des deux côtés proportionnelle à la vitesse d'approche relative, son « boing » (sur chaque poste, un
  par choc, plus discret entre deux autres lions que celui de ce poste), petite secousse
  du sprite (pas de secousse d'écran en multi) ; pendant le contact, la part de la vitesse dirigée
  vers l'autre lion est annulée. Un choc ne cause pas d'étourdissement. Un ennemi ne ré-étourdit
  pas un lion immunisé.
- **Apparition** : positions de départ réparties sur la largeur, en haut du ciel.

## 6. Peinture, territoire et synchronisation

- **Grille** : la grille de cellules de 8 px existante (250 colonnes à 2000 px de large, 23 à 40
  rangées selon la skyline, haute de 180 à 320 px ; seules les cellules opaques comptent).
- **Propriété (bataille, hôte uniquement)** : par cellule, `proprietaire` (0 = personne,
  1 à 6) et `charge` (0 à `CHARGE_MAX`), en `PackedByteArray`. Un tampon de rayon *r* touche à peu
  près les cellules peignables qu'il recouvre : celles dont le centre est à moins de *r* + 4 px (une
  demi-cellule, `Ville.EMPREINTE_TERRITOIRE` ; `Territoire.tamponner` reçoit ce rayon agrandi) :
  - cellule au peintre ou vierge : `charge += GAIN` (plafonnée) et propriétaire = peintre ;
  - cellule adverse : `charge -= GAIN`. Si `charge <= 0`, la cellule passe au peintre avec
    `charge = -charge`.
  - une cellule compte dans le score si `charge >= SEUIL_POSSESSION` ; une cellule disputée peut ne
    compter pour personne (deux lions qui tamponnent le même point se déchargent l'un l'autre en
    boucle ; trois lions ou plus sur un terrain vierge peuvent la laisser sans compte) : le HUD et
    les résultats ne comptent que les cellules au-dessus du seuil.
  - **vol** (statistique `cellules_volees`, comptée par les règles pendant la manche) : une
    cellule qui se met à compter pour le peintre alors qu'elle comptait en dernier pour un autre
    joueur. Deux lions qui se disputent une cellule que personne n'a encore possédée ne se volent
    donc rien (compté au passage de `charge <= 0`, chaque tampon de la dispute serait un vol).
  Les valeurs de `GAIN`, `CHARGE_MAX` et `SEUIL_POSSESSION` sont réglées pour qu'il faille à peu
  près autant de temps pour peindre une cellule qu'aujourd'hui en solo : `GAIN = 4` et
  `SEUIL_POSSESSION = 12`, soit 3 tampons sur une cellule vierge, ce qui suit la mesure du solo
  pour une gerbe en mouvement (16 à 46 px de rayon) ; `CHARGE_MAX = SEUIL_POSSESSION` (12, fiche de
  correction du 25/09) : voler une cellule déjà possédée coûte alors 6 tampons (3 pour la vider,
  3 pour la prendre), contre 3 en terrain vierge. Calcul entier et déterministe (`Territoire`,
  phase 9). Réglage vérifié sur de vrais lions (phase 10 ter, `tests/bataille_test.gd`) : une
  passe pleine vitesse fait compter au territoire 0,7 à 1,3 fois les cellules que compte la
  couverture du solo pour la même passe (mesuré : 0,82 à 1,21 sur les trois niveaux, de 16 à
  46 px) et vole au moins 40 % des cellules d'un adversaire dès le premier cran (mesuré : 49 %).
  C'est l'empreinte qui manquait (sans la demi-cellule : 0,44 à 0,92 et 8 %) ; `GAIN = 6` n'y
  changeait presque rien.
- **Visuel** : masque RGBA et `Ville.gdshader` inchangés. Chaque tampon est dessiné dans les
  nuances du peintre et recouvre ce qui est dessous. Les zones disputées apparaissent bigarrées.
- **Synchro des tampons** : l'hôte diffuse chaque tampon `(index joueur u8, x i16, y i16,
  rayon u8, graine u16)`, regroupés par frame, sur le canal fiable. `Ville.peindre` accepte des
  centres négatifs (le tampon déborde du haut ou de la gauche de l'image) : encodés en u16, ils
  boucleraient vers ~65 500 et le client dessinerait au mauvais endroit ou pas du tout pendant que
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
  mêmes scores que l'hôte.
- **Solo** : mesure de couverture actuelle (alpha moyen ≥ 0,4 par cellule) inchangée.

## 7. Viewport multi

- En entrant dans une scène multi (salon compris), `get_tree().root.content_scale_size` passe à
  2000×1125, et revient à 2000×648 au retour au titre. La scène de jeu applique l'écran de ses
  règles (`Regles.taille_ecran()`) en entrant dans l'arbre ; l'écran titre remet le solo
  (`configurer_solo()`) et son écran.
- Le dégradé du ciel et le centre de la caméra sont calculés depuis la taille du viewport. Les
  hauteurs d'apparition des ennemis et des pastilles, réglées pour les 648 px du solo, suivent la
  hauteur de l'écran ; le peintre garde sa taille du solo (65 % de 648 px), comme les lions et
  les skylines, et accélère en bataille avec le temps de la manche.
- Les skylines restent les mêmes PNG, posées en bas de l'écran. La peinture impose de voler
  environ 230 px au-dessus des toits : l'écran se partage entre une bande de peinture exposée et
  un grand ciel pour les duels.

## 8. HUD et fin de manche

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
- **Départ** : l'hôte déclenche l'intro « Prêt ? Vomissez ! » chez tous. Le chrono démarre à la
  fin de l'intro, piloté par l'hôte.
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

## 9. Gestion des erreurs

| Situation | Comportement |
|---|---|
| Port 7777 déjà utilisé à l'hébergement | Message « Impossible d'héberger : port 7777 occupé » |
| Port 7778 déjà utilisé (deux LeLion sur un PC) | Liste impossible : « Recherche impossible : port 7778 déjà utilisé (un autre LeLion ouvert ?). Rejoins par IP. » |
| Adresse saisie qui n'est pas une IPv4 (nom, faute de frappe) | Refusée sans rien tenter : « Adresse IP invalide (exemple : 192.168.1.20) » |
| Connexion à une IP qui ne répond pas | Délai de 5 s puis « Pas de réponse de l'hôte. Pare-feu de l'hôte ? Réseau Privé ? », retour à l'accueil de l'écran Réseau |
| Version différente, salon plein, manche en cours | Refus explicite côté client (textes traduits, clés `Reseau.REFUS_*`) |
| Aucune balise reçue | Liste vide avec l'indice « Pare-feu ? Réseau Privé ? Essaie par IP » |
| Hôte perdu | Message « L'hôte a quitté la partie » puis retour à l'écran Réseau (depuis le salon, ou l'écran Réseau lui-même : son accueil), au titre depuis une manche |
| Client perdu | Voir section 4 |

## 10. Tests

- **Smoke test solo** (`tests/smoke_test.gd`), adapté à la nouvelle structure : filet de
  non-régression du solo.
- **Tests unitaires headless** (`tests/unitaires.gd`) : charge et vol de cellule, seuil de
  possession, attribution et conflits de couleurs, refus de version, sérialisation des événements
  de tampon ; depuis la phase 17, le chrono (affichage, fin chez l'hôte seulement), le classement ex
  æquo, les couches de musique et le placement des pseudos.
- **Tests de prédiction** : un lion prédit sans pertes reste à moins de 4 px de l'hôte ; avec
  80 ms de latence, 40 ms de gigue et 5 % de pertes, l'écart converge sous 4 px en 150 ms après
  l'arrêt des commandes, et aucune commande n'est appliquée deux fois par l'hôte. Depuis la phase 16 :
  le banc de la prédiction (`tests/prediction_test.gd`, en CI, `--fixed-fps 60`) met l'hôte et un
  client dans un seul processus, chacun dans son monde, reliés par des lignes à retard semées
  (parcours sans latence puis sous 80/40/5, étourdissement décidé par l'hôte, choc contre un lion
  distant, écarts imposés par l'hôte, hôte figé) ; le scénario 12 du test réseau joue une manche à
  1 hôte et 2 clients derrière le relais (80/40/5) : aucun recalage, erreur rarement au-delà de 16 px,
  sous 4 px 150 ms après l'arrêt, aucune commande appliquée deux fois, même empreinte partout.
- **Test réseau** (`tests/reseau/lancer.sh` + `tests/reseau/joueur.gd`) : un processus Godot
  headless par poste, sur localhost (ports 17778 et suivants), chacun sous `timeout`, tous tués en
  sortie ; verdict par les codes de sortie et les journaux. Depuis la phase 11, le transport : hôte
  + 2 clients inscrits, version différente, partie pleine (deux demandes pour la dernière place),
  manche en cours, départ d'un client, départ de l'hôte, échec de connexion, place réservée dès la
  réponse de l'hôte puis libérée par le délai de poignée de main (client qui ne la finit jamais).
  Chaque étape s'enchaîne sur un événement observé (ligne d'un journal, compte de l'hôte) ; seules
  restent de courtes fenêtres de vérification d'absence côté client (1 s après un refus, 0,5 s avant
  un départ volontaire), qui ne peuvent pas donner de faux rouge ; en CI depuis la phase 11 ter.
  Depuis la phase 12, la découverte : balise vers 127.0.0.1 (ports de balise 18778 et suivants),
  partie vue puis rejointe par sa balise, balise suivante à 2 joueurs, expiration 3 s après la
  dernière balise alors que le processus de l'hôte vit encore, port des balises occupé par un
  second écouteur ; la vraie diffusion avec `DIFFUSION=1`, hors CI. Depuis la phase 13, le salon
  (scénario 8, par les vraies scènes) : 1 hôte + 3 clients arrivés dans l'ordre, départ d'un client
  (sa carte se libère), deux demandes de couleur au même feu arbitrées par l'hôte, bouton Démarrer
  regrisé par un client repassé non prêt et démarrage alors refusé, puis démarrage par l'hôte, tous
  prêts, manche chargée chez tous avec la même
  table (index compactés), retardataire refusé « manche en cours ». Depuis la phase 14, la manche
  (scénario 9) : 1 hôte + 2 clients + un muet qui ne charge jamais sa scène, l'hôte figé 6,5 s
  pendant le chargement (personne ne le croit parti), le muet exclu par la barrière, une passe de
  peinture au clavier de chaque poste, un client qui part par le menu local (son lion disparaît,
  ses cellules restent), des réactions données par l'hôte ; la même empreinte chez l'hôte et chez
  le client resté (territoire, scores, suite des tampons, lions, apparitions), puis l'hôte perdu.
  De bout en bout (phase 15, scénario 11) : 1 hôte + 3 clients jouent une manche entière (45 s, le
  Village et son peintre) au clavier, chacun selon un programme de commandes au hasard tiré d'une
  graine ; l'hôte orchestre les rencontres que le hasard ne garantit pas, en ne décidant que des lieux
  (pastilles ramassées au vol par chaque client, étoile, soucoupe, sa gerbe sur un client, la gerbe
  d'un client sur lui, un choc) ; un client est arraché en pleine manche (processus tué, sans
  DISCONNECT) : l'hôte le voit parti au bout du silence de session d'ENet (10 s au plus), son lion
  disparaît chez tous, ses cellules restent ; à la fin, l'hôte et les deux clients restés ont la
  même empreinte : propriétaires des cellules, scores, nombre et suite des tampons reçus, lions,
  apparitions, niveau, et les réactions de chaque joueur (étourdissements, crans, gerbes XXL)
  comptées sur chaque poste (aucune perdue ni doublée). Les statistiques de bataille ne sont tenues
  que par l'hôte (phase 18 : les envoyer aux clients). `DUREE11=45` (décision de l'utilisateur, pas
  90 s : marge CI sous le `timeout 300`). Depuis la phase 17 (scénario 13), la fin au chrono de l'hôte
  sous latence simulée : 1 hôte et 2 clients derrière le relais, une manche de 10 s ; chaque client
  reçoit la fin (son chrono pris sur celui de l'hôte, 0,25 s d'écart au plus), le même HUD figé sur
  chaque poste (chrono à 0:00, parts, rangs, tics), puis l'hôte sort par Échap et ses clients le voient
  partir ; l'empreinte de fin de manche des scénarios 9, 11 et 12 compte aussi le HUD (départs compris).
- **Trace des lions** (`tests/trace_lions.gd`, phase 15 bis, hors CI) : une bataille à 4 lions, une
  partie solo et une réplique de client rejouées tick par tick (hasard semé, `--fixed-fps 60`) ; leur
  empreinte (l'état observable de chaque lion à chaque tick) prouve qu'une refonte du lion ne change
  rien. Deux passages consécutifs identiques font le verdict.
- **Visuel** : `tests/screenshots.gd` étendu (salon, manche à 6 couleurs, résultats), deux vraies
  fenêtres en localhost pour une partie manuelle.
- **Windows** : test manuel de l'`.exe` issu de la CI sur un PC de la LAN (le développement se fait
  sur macOS).

## 11. Build et distribution

- Preset **Windows Desktop** (x86_64) avec `.pck` intégré, donc un seul `.exe`.
- CI : le job existant (smoke test) + tests unitaires + test réseau, puis export Windows publié
  en artefact `LeLion-multi-windows.zip`. Le déploiement GitHub Pages hérité du solo est retiré.
- Pas de templates d'export sur le Mac de développement : l'`.exe` vient de la CI (ou d'une
  installation locale des templates si besoin).
- README : section « Jouer en LAN » (ports 7777/7778 UDP, SmartScreen « Exécuter quand même »,
  pare-feu Windows sur l'hôte en réseau Privé, repli par IP, hôte en Ethernet si possible, Wi-Fi
  5 GHz).

## 12. Phases (le découpage exact viendra du plan)

Chaque phase touche 5 fichiers au plus, se termine par les tests verts, et attend une validation.

1. Nettoyage (code mort) puis socle : `Joueur`, `Commandes`, `OfflineMultiplayerPeer`, `GameState`
   allégé. Solo identique.
2. Teinte du lion (masque calculé par le shader), gerbe mono-couleur, étourdissement, collisions.
3. Autoload `Reseau`, écran Réseau, salon, viewport 16:9.
4. `ReglesBataille`, grille de propriété, synchro des tampons et des scores, test réseau (sans
   prédiction).
4 bis. Prédiction du lion local, redondance des commandes, interpolation, simulateur de latence ;
   le test réseau repasse sous latence simulée.
5. HUD bataille, chrono, résultats, musique.
6. Export Windows, CI, README.

## 13. Risques

- **Wi-Fi** : gigue et pertes. Parades : prédiction du lion local, redondance des commandes,
  interpolation (4.1). Conseils le jour J (README) : l'hôte en Ethernet si possible, bande 5 GHz.
- **Correction visible** si l'hôte et le client divergent souvent (chocs en chaîne) : la
  correction douce peut donner un léger effet élastique. Accepté ; seuils réglables
  (`PredictionLocale.DUREE_CORRECTION`, `SEUIL_RECALAGE`, `InterpolationLion.RETARD`). Un choc contre
  un lion distant qui bouge est prédit contre sa position affichée, en retard d'environ 140 ms
  (interpolation et aller) : l'hôte fait foi, l'écart se résorbe en glissant.
- **Broadcast filtré** (réseau classé Public, Wi-Fi invité) : repli par IP, documenté.
- **Réseau maillé en mode routeur** (TP-Link Deco, eero : /22 typique) : la diffusion dirigée
  a.b.c.255 suppose un /24 (4.1) et n'est plus une diffusion sur un /22 ou plus large ; repli par
  IP, comme pour le broadcast filtré (revue finale de la phase 12, constat 3 ; phase 19).
- **Coût du tamponnage** à 6 joueurs sur chaque machine (6 blits par frame + mise à jour de la
  texture) : à mesurer en phase 4. Parade : regrouper la mise à jour de texture par frame (déjà le
  cas avec `_dirty`).
- **Lisibilité des 6 couleurs** sur la skyline sombre et le ciel violet : à valider sur captures.
