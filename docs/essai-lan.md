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

- [ ] Les captures d'écran de la phase 19 (l'écran Réseau, le salon, une manche à plusieurs
  couleurs, l'écran Résultats) ne sont pas dans le dépôt : la personne qui pilote cette phase te
  les montrera avant de commencer. Elles correspondent à ce qui est décrit dans cette fiche et
  dans le README : oui / non
- [ ] Le même `LeLion-multi.exe` (version 0.19, artefact `LeLion-multi-windows` de la CI) sur chaque
  PC, au même endroit d'une version à l'autre.
- [ ] Sur un PC : clic droit sur l'exe → Propriétés → Détails. Description « LeLion multi », version
  du fichier 0.19.0.0, copyright « Copyright 2026 w3cdotorg, GPL-3.0 » ; dans l'explorateur, l'icône
  du jeu (pas celle de Godot). Sinon, noter ce qui s'affiche : _______________
- [ ] La fenêtre du pare-feu (écran Multijoueur, ou Héberger) parle de « LeLion multi » (pas de
  « Godot Engine »). Noter QUAND elle est apparue (à l'écran Multijoueur, ou seulement au premier
  Héberger, sur quel PC) : _______________ Sinon, noter le nom affiché : _______________

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
- [ ] Chez l'hôte, Échap ouvre une confirmation (« Quitter la partie pour tout le monde ? ») au
  lieu de quitter tout de suite. Un second Échap, ou le bouton Oui, confirment aussitôt ; vomir
  (Espace), démarrer (Tab/Start) et Entrée sont ignorés pendant la première seconde après
  l'ouverture, puis confirment ensuite ; toute autre touche ou bouton de manette, ou Non, annule
  et revient à l'écran Résultats. Chez un joueur (pas l'hôte), Échap quitte tout de suite, sans
  confirmation (son départ n'affecte que lui). Ça se passe comme décrit : oui / non, sur le
  PC : _______

| Réponse | Ce que fera la phase 19 bis |
|---|---|
| Illisible | `Resultats.TAILLE_BARRE` (480 × 34), `Resultats.LARGEUR_PSEUDO` (360), les tailles de police de `Scenes/Resultats.tscn`. |
| Animation trop longue ou trop courte | `Resultats.DELAI_LIGNE` (0,3 s entre deux lignes), `Resultats.DUREE_COMPTEUR` (0,45 s), `Resultats.DELAI_TITRE` (0,2 s). |
| Délai gênant ou trop court | `Resultats.DELAI_CHOIX` (1 s). |
| Un choix qui ne fait pas ce qu'on attend | Noter lequel, qui l'a fait, ce qui s'est passé sur chaque PC, et l'heure (pour les journaux). |
| La confirmation d'Échap ne se passe pas comme décrit | Noter la touche pressée, le PC et ce qui s'est passé : `Resultats.DELAI_CHOIX` (1 s), `Resultats._agir` (le second Échap confirme aussitôt, vomir ou la validation seulement après DELAI_CHOIX, toute autre touche mappée annule). |

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
