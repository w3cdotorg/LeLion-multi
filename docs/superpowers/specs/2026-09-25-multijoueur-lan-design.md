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
- Rembobinage avec rejeu des commandes (le lion local est prédit avec une correction douce, voir
  4.1) et prédiction des lions distants (ils sont interpolés).
- Enchaînement de manches en « 3 manches gagnantes » (possible plus tard).

## 2. Décisions de jeu

| Sujet | Décision |
|---|---|
| Vomi qui touche un autre lion | **Étourdit 1,5 s** : immobile, ne vomit plus, recul, tête barbouillée de la couleur de l'agresseur, étoiles. Puis **1 s d'immunité** (clignotement). |
| Couleurs de vomi | **Une couleur par joueur**, rendue en 3 nuances (foncée, pure, claire). |
| Pastilles de couleur | Donnent **+1 cran de gerbe** (1 à 7 crans ; rayon de peinture de 16 px au premier cran, 5 px de plus par cran, 46 px au septième). Départ à 1 cran. Premier arrivé, premier servi. En solo, chaque couleur débloquée donne aussi un cran : les rayons du solo ne changent pas. |
| Étoile XXL | Inchangée, par joueur (gerbe × 2 pendant 8 s). |
| Cœurs | Aucun en multi. |
| Ennemis (soucoupe, coccinelle, peintre) | Étourdissent **2,5 s** (sans barbouillage), puis 1 s d'immunité. |
| Fin de manche | **Chrono de 90 s**, personne n'est éliminé. Le plus de cellules gagne, ex æquo possibles. |
| Collisions entre lions | **Auto-tamponneuses** : blocage physique + impulsion de recul proportionnelle à la vitesse relative. Un lion étourdi peut être poussé. |
| Viewport multi | **2000×1125 (16:9)**. Le solo garde 2000×648. |
| Palette | Rouge, bleu, jaune, vert, magenta, cyan (valeurs à valider sur captures, y compris simulation deutéranopie). |

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
| `Commandes` (RefCounted) | Interface `direction() -> Vector2`, `vomir() -> bool`. Deux sources : `LOCALES` (actions InputMap de ce poste) et `MANUELLES` (valeurs écrites par un tiers : pilote de l'attract mode, tests, et côté hôte les commandes reçues d'un client, numérotées et dédoublonnées en phase 16). | Input |
| `PredictionLocale` (Node) | Sur un client, simule le lion local sans attendre l'hôte et le recale en douceur sur l'état autoritaire (voir 4.1). Absent chez l'hôte et en solo. | `Lion`, `Reseau` |
| `Lion` (scène) | Déplacement, gerbe, traceuses, teinte, barbouillage. Lit un `Joueur` et une `Commandes`. Ne décide de rien : sur l'hôte, il signale aux `Regles` les lions que touche sa gerbe et ceux qu'il percute, comme les ennemis et les pastilles. | `Joueur`, `Commandes` |
| `Regles` (RefCounted, détenu par `GameState`) | Reçoit les événements (lion touché par ennemi, par vomi, pastille ramassée, choc, vol de cellules, fin de chrono, progression), chacun pour le `Joueur` concerné, et décide des effets. Donne aussi les couleurs de départ de chaque joueur (aucune en solo, ses trois nuances en bataille), dit si la partie se joue au territoire (en bataille seulement), donne l'écran du mode (2000×648 en solo, 2000×1125 en bataille), l'avancement de la partie (la ville peinte rapportée au seuil en solo, le temps de la manche en bataille : il accélère le peintre et les ennemis) et ce qui peut apparaître (pastille et sa couleur, étoile, cœurs), que lit le Spawner. `ReglesSolo` / `ReglesBataille`. Ses événements s'exécutent sur l'hôte uniquement ; l'écran et le territoire sont lus partout. | `GameState`, `Joueur` |
| `Ville` (scène) | Masque de peinture (visuel), tampons en cache par rayon et jeu de couleurs, + deux comptages : couverture (solo, inchangé) et **grille de propriété** (bataille : un `Territoire`, créé quand les règles se jouent au territoire, tamponné par l'hôte seul, qui tient aussi les scores). Chaque tampon est peint pour un `Joueur`, dans ses couleurs. | `Joueur`, `Territoire`, `Regles` |
| `Reseau` (autoload) | Pair ENet, découverte UDP, poignée de main (version, pseudo), liste des joueurs du salon, attribution des index et couleurs, signaux de connexion / déconnexion. | `MultiplayerAPI` |
| `Main` | Instancie N lions (via `MultiplayerSpawner` en réseau), applique l'écran des règles branchées avant elle (par le titre ou le salon, jamais par la scène), relaie tampons et scores. | tout le reste |

### 3.2 Flux d'une frame (bataille)

1. Chaque client applique ses commandes à son lion **immédiatement** (prédiction), puis les envoie
   à l'hôte, numérotées, avec les 3 précédentes, par RPC `unreliable_ordered` à chaque frame
   physique. L'hôte les écrit dans les commandes manuelles du lion correspondant.
2. L'hôte simule tous les lions (`move_and_slide`, collisions entre lions, ennemis, pastilles).
3. Les traceuses de l'hôte détectent la ville et les autres lions. Les contacts remontent aux
   `Regles`.
4. Les tampons de peinture sont appliqués sur l'hôte et **diffusés sous forme d'événements**.
5. `MultiplayerSynchronizer` réplique position, vitesse, orientation, état de vomi, crans et
   numéro de la dernière commande traitée de chaque lion. Les clients interpolent les lions
   distants et recalent leur lion local (4.1). L'étourdissement, lui, ne se réplique pas comme un
   champ brut : il voyage en événement (RPC hôte → clients qui appelle `Joueur.etourdir` avec la
   couleur du barbouillage), conformément au point de vigilance transverse de la phase 14 (feuille
   de route) sur les réactions du `Joueur`.

## 4. Réseau et salon

- **Transport** : `ENetMultiplayerPeer`, port UDP **7777**, 6 pairs maximum (hôte compris).
  Canal 0 : état et commandes. Canal 1 (fiable ordonné) : tampons de peinture.
- **Redondance des commandes** : chaque paquet de commandes porte la commande courante et les 3
  précédentes (numérotées). L'hôte ignore les numéros déjà vus : un paquet Wi-Fi perdu ne fait
  pas sauter le lion.
- **Interpolation** : les lions distants sont affichés avec un tampon d'environ 2 envois
  (≈ 50 ms), pour lisser la gigue.
- **Découverte** : l'hôte émet toutes les secondes une balise UDP broadcast sur le port **7778** :
  `LELION|<version>|<pseudo hôte>|<nb joueurs>|<id niveau>`. L'écran « Rejoindre » écoute et liste
  les parties (expiration après 3 s sans balise). Saisie d'IP en secours.
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
- **Parcours** : Titre → *Multijoueur* → écran Réseau (pseudo mémorisé dans `Scores`,
  *Héberger*, liste des parties, *Rejoindre par IP*) → **Salon**.
- **Salon** : 6 cartes synchronisées par l'hôte (pseudo, aperçu du lion teinté, état Prêt).
  Gauche/droite change de couleur parmi les libres, l'hôte arbitre les conflits. L'hôte choisit le
  niveau (haut/bas). Vomir bascule Prêt. Dès que ≥ 2 joueurs sont inscrits et que tous sont prêts,
  compte à rebours de 3 s, annulé si quelqu'un repasse non prêt. Retour quitte le salon.
- **Commandes** : chaque joueur utilise les commandes actuelles de son PC (clavier ou manette).
- **Pause** : aucune en réseau. Échap / Start ouvre un menu local (Reprendre, Quitter la partie)
  pendant que le jeu continue.
- **Déconnexions** :
  - hôte perdu : message « L'hôte a quitté la partie » puis retour au titre ;
  - client perdu en salon : sa carte se libère ;
  - client perdu en manche : son lion disparaît, ses cellules restent, il reste au classement en
    grisé.

### 4.1 Prédiction du lion local

Objectif : pas de délai perceptible entre la touche et le mouvement de son propre lion, même avec
une gigue Wi-Fi de 30 à 100 ms. Sans prédiction, le retard ressenti serait de 80 à 150 ms
(aller-retour + tampon d'interpolation + gigue).

- **Simulation locale** : le client déplace son lion avec ses commandes dès la frame courante, avec
  exactement le même code de déplacement que l'hôte (`Lion`, accélération, bornes de l'écran).
- **Correction douce** : à chaque état reçu, le client compare la position autoritaire à sa
  position prédite. Écart inférieur à 4 px : rien. Au-delà : il rapproche son lion de la position
  de l'hôte sur 100 à 150 ms. Au-delà de 200 px (téléportation, désynchronisation grave) :
  recalage immédiat.
- **Décisions de l'hôte** : étourdissement, recul d'un coup et fin de manche s'appliquent à
  réception. Pendant un étourdissement, la prédiction est suspendue et le lion suit l'hôte.
- **Chocs entre lions** : le client simule le choc de son lion contre la position affichée des
  autres, pour un « boing » immédiat. L'hôte fait foi, la correction douce absorbe l'écart.
- **Gerbe** : les particules du lion local partent dès l'appui (visuel seul). La peinture reste
  décidée par l'hôte ; les 0,6 s de vol du jet masquent la latence.
- **Simulateur de latence** (debug) : option de lancement `--latence=80 --gigue=40 --pertes=5`
  qui retarde, mélange et jette des paquets dans notre couche d'envoi, pour tester en localhost.

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
  1 s, et les règles ignorent un joueur étourdi ou invulnérable (le peintre et la gerbe signalent
  leur contact à chaque frame).
- **Collisions** : les lions partagent une couche de collision dédiée (couche 5) : un pare-chocs
  (`Area2D`) de 45 px au lieu des 63 px du corps. Le corps reste sur la couche 1, où ennemis et
  pastilles le détectent, et ne heurte plus rien (masque 0). Au premier contact, impulsion `recul`
  des deux côtés proportionnelle à la vitesse d'approche relative, son « boing », petite secousse
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
  machine dessine avec la graine reçue : motifs et coulures identiques. Environ 3 Ko/s à 6 joueurs.
- **Synchro du score** : toutes les 0,2 s, l'hôte envoie la liste des cellules dont le
  propriétaire compté a changé (index u16 + propriétaire u8, `Territoire.extraire_changements()`)
  et les scores. Les clients n'effectuent aucun calcul de propriété : leur ville dessine les
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

- **HUD bataille** : 6 vignettes en ordre fixe (couleur, pseudo, % de la ville, crans en points),
  couronne sur le meneur, vignette locale mise en évidence. Chrono central, rouge avec tic sonore
  dans les 10 dernières secondes.
- **Musique** : les couches suivent le temps restant (arpèges à 60 s, mélodie à 30 s). Thème du
  peintre au Village.
- **Départ** : l'hôte déclenche l'intro « Prêt ? Vomissez ! » chez tous. Le chrono démarre à la
  fin de l'intro, piloté par l'hôte.
- **Fin** : à 0, tout se fige, l'hôte envoie les scores définitifs. **Écran Résultats** : podium
  en barres colorées animées (réutilise l'animation du bilan de `GameOver`), pourcentages, trois
  titres (« Le plus vicieux » : étourdissements infligés, « Le voleur » : cellules volées,
  « L'auto-tamponneur » : chocs). L'hôte choisit *Revanche*, *Niveau suivant* ou *Retour au
  salon*. Les clients voient « En attente de l'hôte… ».
- **Traductions** : tous les nouveaux textes passent par `traductions.csv` (FR + EN).

## 9. Gestion des erreurs

| Situation | Comportement |
|---|---|
| Port 7777 déjà utilisé à l'hébergement | Message « Impossible d'héberger : port 7777 occupé » |
| Connexion à une IP qui ne répond pas | Délai de 5 s puis message, retour à l'écran Réseau |
| Version différente, salon plein, manche en cours | Refus explicite côté client |
| Aucune balise reçue | Liste vide avec l'indice « Pare-feu ? Réseau Privé ? Essaie par IP » |
| Hôte perdu | Message puis retour au titre |
| Client perdu | Voir section 4 |

## 10. Tests

- **Smoke test solo** (`tests/smoke_test.gd`), adapté à la nouvelle structure : filet de
  non-régression du solo.
- **Tests unitaires headless** (`tests/unitaires.gd`) : charge et vol de cellule, seuil de
  possession, attribution et conflits de couleurs, refus de version, sérialisation des événements
  de tampon.
- **Tests de prédiction** : un lion prédit sans pertes reste à moins de 4 px de l'hôte ; avec
  80 ms de latence, 40 ms de gigue et 5 % de pertes, l'écart converge sous 4 px en 150 ms après
  l'arrêt des commandes, et aucune commande n'est appliquée deux fois par l'hôte.
- **Test réseau** (`tests/reseau/lancer.sh` + `tests/reseau/joueur.gd`) : un processus Godot
  headless par poste, sur localhost (ports 17778 et suivants), chacun sous `timeout`, tous tués en
  sortie ; verdict par les codes de sortie et les journaux. Depuis la phase 11, le transport : hôte
  + 2 clients inscrits, version différente, partie pleine (deux demandes pour la dernière place),
  manche en cours, départ d'un client, départ de l'hôte, échec de connexion. De bout en bout (phase
  15) : 1 hôte + 3 clients, commandes scriptées ; vérifie à la fin l'empreinte identique des
  propriétaires de cellules chez tous, les scores identiques, le même nombre de tampons reçus, la
  déconnexion d'un client en cours de manche.
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
  correction douce peut donner un léger effet élastique. Accepté ; seuils réglables.
- **Broadcast filtré** (réseau classé Public, Wi-Fi invité) : repli par IP, documenté.
- **Coût du tamponnage** à 6 joueurs sur chaque machine (6 blits par frame + mise à jour de la
  texture) : à mesurer en phase 4. Parade : regrouper la mise à jour de texture par frame (déjà le
  cas avec `_dirty`).
- **Lisibilité des 6 couleurs** sur la skyline sombre et le ciel violet : à valider sur captures.
