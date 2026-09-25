# LeLion multi : bataille de peinture en LAN

Date : 2026-09-25 · Statut : validé en brainstorming, à relire avant le plan

## 1. Objectif

Transformer LeLion en jeu de **bataille de peinture pour 2 à 6 joueurs en réseau local**, chacun
sur son PC Windows. Chaque lion a sa couleur, vomit dans sa couleur et cherche à posséder la plus
grande part de la ville en 90 secondes. Les lions se barbouillent et s'étourdissent mutuellement,
et se rentrent dedans façon auto-tamponneuses.

Le **mode solo reste jouable** avec ses sensations actuelles (cœurs, arc-en-ciel, seuils 85/90/95 %,
arcade, attract mode, records).

Contexte d'usage : une petite LAN entre amis, tous sous Windows, en 16:9.

### Hors périmètre (YAGNI)

- Navigateur / export Web pour le multi (ENet n'existe pas dans un navigateur). L'abstraction
  `MultiplayerPeer` laisse la porte ouverte à un relais WebSocket plus tard.
- macOS et Linux pour le multi. Le code reste portable, seul le preset Windows est livré.
- Bots IA, plusieurs joueurs sur un même PC, arrivée en cours de manche, migration d'hôte,
  prédiction côté client, internet (hors LAN), commandes tactiles en multi.
- Enchaînement de manches en « 3 manches gagnantes » (possible plus tard).

## 2. Décisions de jeu

| Sujet | Décision |
|---|---|
| Vomi qui touche un autre lion | **Étourdit 1,5 s** : immobile, ne vomit plus, recul, tête barbouillée de la couleur de l'agresseur, étoiles. Puis **1 s d'immunité** (clignotement). |
| Couleurs de vomi | **Une couleur par joueur**, rendue en 3 nuances (foncée, pure, claire). |
| Pastilles de couleur | Donnent **+1 cran de gerbe** (1 à 7 crans, rayon 16 à 46 px, formule actuelle). Départ à 1 cran. Premier arrivé, premier servi. |
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
| `Joueur` (Resource) | État d'un lion : `id_reseau`, `index` (0-5), `pseudo`, `couleur`, `crans`, `bonus_restant`, `etourdi_restant`, `immunite_restante`, `cellules`, stats (étourdissements infligés, cellules volées, chocs). En solo il porte aussi `couleurs_debloquees`, `vies`. | rien |
| `GameState` (autoload, allégé) | État de **partie** : niveau, difficulté, chrono, `pret`, `partie_en_cours`, arcade, démo, liste des `Joueur`. Signaux de partie. | `Joueur` |
| `Commandes` (RefCounted) | Interface `direction() -> Vector2`, `vomit() -> bool`. Implémentations : `CommandesLocales` (actions InputMap existantes), `CommandesReseau` (dernier état reçu du client), `CommandesPilote` (attract mode, ex-`Pilote.gd`). | Input |
| `Lion` (scène) | Déplacement, gerbe, traceuses, teinte, barbouillage. Lit un `Joueur` et une `Commandes`. Ne connaît ni les règles ni le réseau. | `Joueur`, `Commandes` |
| `Regles` (Node) | Réagit aux événements (lion touché par ennemi, par vomi, pastille ramassée, choc, fin de chrono, progression) et décide des effets. `ReglesSolo` / `ReglesBataille`. S'exécute **sur l'hôte uniquement**. | `GameState`, `Joueur` |
| `Ville` (scène) | Masque de peinture (visuel) + deux comptages : couverture (solo, inchangé) et **grille de propriété** (bataille). | rien |
| `Reseau` (autoload) | Pair ENet, découverte UDP, poignée de main (version, pseudo), liste des joueurs du salon, attribution des index et couleurs, signaux de connexion / déconnexion. | `MultiplayerAPI` |
| `Main` | Instancie N lions via `MultiplayerSpawner`, instancie les `Regles` selon le mode, relaie tampons et scores. | tout le reste |

### 3.2 Flux d'une frame (bataille)

1. Chaque client envoie à l'hôte `(direction, vomit)` par RPC `unreliable_ordered` à chaque frame
   physique. L'hôte les stocke dans la `CommandesReseau` du lion correspondant.
2. L'hôte simule tous les lions (`move_and_slide`, collisions entre lions, ennemis, pastilles).
3. Les traceuses de l'hôte détectent la ville et les autres lions. Les contacts remontent aux
   `Regles`.
4. Les tampons de peinture sont appliqués sur l'hôte et **diffusés sous forme d'événements**.
5. `MultiplayerSynchronizer` réplique position, orientation, état de vomi, étourdissement et
   crans de chaque lion. Les clients interpolent.

## 4. Réseau et salon

- **Transport** : `ENetMultiplayerPeer`, port UDP **7777**, 6 pairs maximum (hôte compris).
  Canal 0 : état et commandes. Canal 1 (fiable ordonné) : tampons de peinture.
- **Découverte** : l'hôte émet toutes les secondes une balise UDP broadcast sur le port **7778** :
  `LELION|<version>|<pseudo hôte>|<nb joueurs>|<id niveau>`. L'écran « Rejoindre » écoute et liste
  les parties (expiration après 3 s sans balise). Saisie d'IP en secours.
- **Poignée de main** : le client envoie version + pseudo. Version différente : refus avec message
  « Version différente de l'hôte (x.y) ». Salon plein ou manche en cours : refus explicite.
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

## 5. Lion

- **Teinte** : seule la crinière prend la couleur du joueur. `tools/generer_masques_lion.py`
  produit un masque par sprite (`LionHead_masque.png`, `LionHeadVomit_masque.png`) à partir de la
  teinte et de la luminance, en excluant le visage. Le shader `Lion.gdshader` mélange
  `original` et `luminance × couleur_joueur` selon le masque. Paramètres `barbouillage_couleur` et
  `barbouillage_force` pour l'étourdissement. **Repli** si le masque est laid : rotation de teinte
  de toute la tête.
- **Pseudo** affiché au-dessus du lion, dans sa couleur, en multi uniquement.
- **Gerbe** : 3 émetteurs (nuances du joueur) en éventail en bataille, un émetteur par couleur
  débloquée en solo.
- **Traceuses** : la traceuse de peinture reste au point de chute. En bataille, **3 zones de
  contact** supplémentaires le long de la parabole (même physique que les particules) détectent
  les autres lions.
- **Étourdissement** : commandes ignorées, recul, barbouillage, étoiles qui tournent. L'immunité
  réutilise le clignotement actuel.
- **Collisions** : les lions partagent une couche de collision dédiée. Forme de contact entre lions
  réduite (rayon ≈ 45 px au lieu de 63). Au contact, impulsion `recul` des deux côtés
  proportionnelle à la vitesse relative, son « boing », petite secousse du sprite (pas de secousse
  d'écran en multi). Un choc ne cause pas d'étourdissement. Un ennemi ne ré-étourdit pas un lion
  immunisé.
- **Apparition** : positions de départ réparties sur la largeur, en haut du ciel.

## 6. Peinture, territoire et synchronisation

- **Grille** : la grille de cellules de 8 px existante (≈ 250 × 81 à 2000 px de large, seules les
  cellules opaques comptent).
- **Propriété (bataille, hôte uniquement)** : par cellule, `proprietaire` (0 = personne,
  1 à 6) et `charge` (0 à `CHARGE_MAX`), en `PackedByteArray`. Un tampon de rayon *r* touche les
  cellules peignables dont le centre est à moins de *r* :
  - cellule au peintre ou vierge : `charge += GAIN` (plafonnée) et propriétaire = peintre ;
  - cellule adverse : `charge -= GAIN`. Si `charge <= 0`, la cellule passe au peintre avec
    `charge = -charge`, et le vol est compté dans les stats.
  - une cellule compte dans le score si `charge >= SEUIL_POSSESSION`.
  Les valeurs de `GAIN`, `CHARGE_MAX` et `SEUIL_POSSESSION` sont réglées pour qu'il faille à peu
  près autant de temps pour peindre une cellule qu'aujourd'hui en solo. Calcul entier et
  déterministe.
- **Visuel** : masque RGBA et `Ville.gdshader` inchangés. Chaque tampon est dessiné dans les
  nuances du peintre et recouvre ce qui est dessous. Les zones disputées apparaissent bigarrées.
- **Synchro des tampons** : l'hôte diffuse chaque tampon `(index joueur u8, x u16, y u16,
  rayon u8, graine u16)`, regroupés par frame, sur le canal fiable. Chaque machine dessine avec la
  graine reçue : motifs et coulures identiques. Environ 3 Ko/s à 6 joueurs.
- **Synchro du score** : toutes les 0,2 s, l'hôte envoie la liste des cellules dont le
  propriétaire compté a changé (index u16 + propriétaire u8) et les scores. Les clients
  n'effectuent aucun calcul de propriété.
- **Solo** : mesure de couverture actuelle (alpha moyen ≥ 0,4 par cellule) inchangée.

## 7. Viewport multi

- En entrant dans une scène multi (salon compris), `get_tree().root.content_scale_size` passe à
  2000×1125, et revient à 2000×648 au retour au titre.
- Le dégradé du ciel et le centre de la caméra, aujourd'hui en dur, sont calculés depuis la taille
  du viewport. Les hauteurs d'apparition des ennemis et des pastilles sont vérifiées.
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
- **Test réseau de bout en bout** (`tests/reseau/lancer.sh` + `tests/reseau/joueur.gd`) : 1 hôte +
  3 clients headless sur localhost, commandes scriptées. Vérifie à la fin : empreinte identique
  des propriétaires de cellules chez tous, scores identiques, même nombre de tampons reçus,
  déconnexion d'un client en cours de manche gérée.
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
  pare-feu Windows sur l'hôte en réseau Privé, repli par IP).

## 12. Phases (le découpage exact viendra du plan)

Chaque phase touche 5 fichiers au plus, se termine par les tests verts, et attend une validation.

1. Nettoyage (code mort) puis socle : `Joueur`, `Commandes`, `OfflineMultiplayerPeer`, `GameState`
   allégé. Solo identique.
2. Teinte du lion (masques, shader), gerbe mono-couleur, étourdissement, collisions.
3. Autoload `Reseau`, écran Réseau, salon, viewport 16:9.
4. `ReglesBataille`, grille de propriété, synchro des tampons et des scores, test réseau.
5. HUD bataille, chrono, résultats, musique.
6. Export Windows, CI, README.

## 13. Risques

- **Sensation de latence** du lion local sans prédiction : négligeable en LAN filaire, à surveiller
  en Wi-Fi. Parade : prédiction du seul lion local.
- **Broadcast filtré** (réseau classé Public, Wi-Fi invité) : repli par IP, documenté.
- **Coût du tamponnage** à 6 joueurs sur chaque machine (6 blits par frame + mise à jour de la
  texture) : à mesurer en phase 4. Parade : regrouper la mise à jour de texture par frame (déjà le
  cas avec `_dirty`).
- **Lisibilité des 6 couleurs** sur la skyline sombre et le ciel violet : à valider sur captures.
