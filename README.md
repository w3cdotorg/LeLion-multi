# LeLion multi

[Original inspiration: Laetitia Perez](https://www.instagram.com/p/Dc3SacQDsyM/?igsi=M21jMzRiMmxqdTZl)

A lion has to paint the town by puking a rainbow, while dodging enemies.
An absurd, deliciously colorful game made with [Godot 4](https://godotengine.org).

This fork of [LeLion](https://github.com/w3cdotorg/LeLion) turns it into a **paint battle for 2 to 6
players on a local network**, each on their own Windows PC: see
[Multiplayer](#multiplayer-a-lan-paint-battle), and [Jouer en LAN](#jouer-en-lan) (in French) to set
it up. The solo game below is unchanged; the original plays in a browser at
<https://w3cdotorg.github.io/LeLion/>.

A Game Boy Advance port, rewritten in C, lives at [w3cdotorg/lelion-gba](https://github.com/w3cdotorg/lelion-gba).

![Gameplay screenshot](docs/capture.png)

![The giant painter in the Village level](docs/boss.png)

## How to play

Grab the color dots to enrich your spew, then hold the puke button while flying over the town.
You win once enough of the skyline is really covered in paint: 85% on Easy, 90% on Normal,
95% on Hardcore. A yellow tick on the progress bar marks the finish line. Enemies hurt: a saucer or a ladybug costs you a
heart, and they show up faster and faster as the town gets colored.

On the title screen, pick a difficulty: **Easy** (3 hearts, extra hearts respawn, paint 85%),
**Normal** (3 hearts, no extras, paint 90%) or **Hardcore** (one hit and it's over, paint 95%). After a hit, the lion blinks and
stays invulnerable for a second and a half. Pick one of three levels (Skyline, Metropolis,
Village), each showing your best time for the chosen difficulty, then press **Play**. In the Village, a
giant painter joins in: he announces himself on one side of the screen, moves to the center,
pauses, backs out, then comes back from the other side. Paint the half he leaves free, cross
over when he retreats.

A rainbow star appears from time to time: grab it to double the width of your spew for eight
seconds.

**Arcade** (top-left button) chains the nine stages: the three levels on Easy, then Normal,
then Hardcore, with a cumulated time and its own best time. Every stage opens on a
"READY? VOMIT!" intro, and a defeat brings up an arcade-style "CONTINUE?" countdown: press
the puke button to retry, or let it run out to see the summary.

Leave the title screen alone for fifteen seconds and the game plays itself (attract mode);
any key or tap brings the title back. The chiptune soundtrack is layered: the arpeggios join
in at a third of the way to victory, the melody at two thirds, and the Village level has its own
minor-key theme for the painter.

| Action | Keyboard | Gamepad | Touch screen |
|---|---|---|---|
| Move | Arrows, WASD / ZQSD | Left stick, D-pad | Virtual stick: put your thumb on the left half |
| Puke | Space, Enter | A | PUKE button, bottom right |
| Pause (Resume / Settings / Back to menu) | Esc, P | Start | II button, top right |

Touch controls only appear on devices with a touch screen. The **Settings** screen (title
screen or pause menu) has music and sound-effect volumes, fullscreen, an optional CRT filter
(scanlines, curvature, color bleed) and the language (French or English; the default follows
your system). Difficulty, last level, settings and best
times are all saved between sessions: on the web build they live in the browser's IndexedDB,
so they survive closing the tab.

## Multiplayer: a LAN paint battle

On the title screen, **Multiplayer** (bottom right) opens the network screen: pick a name (up to 12
characters), then **Host a game**, pick a game in the list of games on the network, or type the
host's IP address. In the lobby, each player picks a color (Left/Right) and gets ready (Space); the
host picks the level (Up/Down) and starts (Tab, Start) once at least two players are there, all
ready.

A round lasts 90 seconds, on a 16:9 screen. Every lion pukes in its own color, in three shades, and
the town is split into 8-pixel cells: paint a cell enough and it is yours, paint over someone else's
and you steal it. The most cells at the gong wins (ties are possible). Puking on another lion stuns
it for 1.5 s (then 1 s of immunity); saucers, ladybugs and the painter stun for 2.5 s, then leave
3 s to flee. Color dots add a notch to your spew (1 to 7: a wider brush), the rainbow star doubles
it for eight seconds; there are no hearts. Lions bump into each other like bumper cars. The HUD
shows each player's share of the painted cells, rank and notches; the last ten seconds tick in red.

After the gong, every PC shows the same **Results** screen: the ranking, each player's share, stuns
dealt, cells stolen and bumps, and three titles (the nastiest, the thief, the bumper car). The host
picks **Rematch**, **Next level** or **Back to lobby** for everyone; anyone can quit, and the host
quitting ends the game for everyone (it asks first). Each player uses their own PC's keyboard or
gamepad, with the solo controls; Esc opens a local menu that does not pause the round.

## Jouer en LAN

### Ce qu'il faut

- Un PC Windows par joueur (2 à 6), tous sur **le même réseau local** : la même box, en Wi-Fi ou
  par câble. Pas besoin d'Internet pendant la partie.
- Le même `LeLion-multi.exe` sur chaque PC. Il vient de la CI : sur GitHub, onglet **Actions**, la
  dernière exécution verte de `main` (ou d'une pull request), **Artifacts** → `LeLion-multi-windows`
  (un zip ; il faut être connecté à GitHub), qui contient le seul `LeLion-multi.exe` : le jeu est
  dedans. Deux versions différentes ne jouent pas ensemble (« Version différente de l'hôte (0.19) »).
- Garder l'exe **au même endroit** (par exemple `Documents\LeLion`) et y remplacer le fichier à
  chaque nouvelle version : l'autorisation du pare-feu suit son chemin.

### Premier lancement

1. **SmartScreen** : l'exe n'est pas signé. « Windows a protégé votre ordinateur » →
   **Informations complémentaires** → **Exécuter quand même** (une fois par fichier). Le navigateur
   peut aussi prévenir au téléchargement : conserver le fichier.
2. **Réseau Privé**, sur chaque PC : Paramètres → Réseau et Internet → Wi-Fi (ou Ethernet) → le
   réseau → **Type de profil réseau** (Windows 11) ou **Profil réseau** (Windows 10) → **Privé**. En
   réseau Public, Windows bloque ce que LeLion reçoit.
3. **Pare-feu** : à la première ouverture de l'écran **Multijoueur**, sur chaque PC, hôte compris
   (LeLion s'y met à écouter les annonces des parties) : Windows affiche « Le Pare-feu Windows
   Defender a bloqué certaines fonctionnalités de cette application » pour **LeLion multi** :
   laisser **Réseaux privés** coché et cliquer **Autoriser l'accès** (Windows peut demander le mot
   de passe d'un administrateur). Sans cela, les autres voient la partie mais ne peuvent pas la
   rejoindre. Sur l'hôte, Windows peut redemander au tout premier **Héberger une partie** (une
   règle par port) : autoriser de la même façon.

Ces fenêtres ne reviennent plus tant que l'exe reste au même endroit.

### Jouer

- L'hôte : **Multijoueur** → **Héberger une partie**. Son salon affiche ses adresses (« Les autres
  te voient dans leur liste, ou tapent ton adresse : 192.168.1.20 »).
- Les autres : **Multijoueur**. La partie de l'hôte apparaît en une seconde dans « Parties sur le
  réseau » : la choisir. Sinon, taper l'adresse de l'hôte dans **Adresse IP**, puis **Rejoindre**.
- Au salon : Gauche/Droite, la couleur ; Espace, prêt. L'hôte choisit le niveau (Haut/Bas) et
  démarre (Tab ou Start) quand tout le monde est prêt, à deux au moins.
- Ports, en UDP : **7777** (la partie, chez l'hôte) et **7778** (l'annonce des parties, que l'hôte
  diffuse chaque seconde sur le réseau local).
- Pour un jeu fluide : l'hôte en Ethernet si possible, le Wi-Fi en 5 GHz, pas de gros
  téléchargement pendant la partie.

### Dépannage

| Ce qu'on voit | Pourquoi | Quoi faire |
|---|---|---|
| « Aucune partie trouvée. Pare-feu ? Réseau Privé ? Essaie par IP. » | Ce PC ne reçoit pas les annonces : son pare-feu (« Annuler » au premier lancement), un réseau Public, un Wi-Fi invité qui isole les appareils, ou un Wi-Fi maillé (ligne suivante). | Réseau Privé, autoriser LeLion multi (plus bas), ou rejoindre par IP. |
| La partie n'apparaît pas sur un Wi-Fi maillé (TP-Link Deco, eero, Google/Nest Wifi en mode routeur) | Ces réseaux sont souvent plus grands qu'un /24 (par exemple de 192.168.68.0 à 192.168.71.255, masque 255.255.252.0) : l'annonce, envoyée à a.b.c.255, n'en atteint alors qu'une partie. | Rejoindre par IP : l'adresse s'affiche dans le salon de l'hôte. |
| « Pas de réponse de l'hôte. Pare-feu de l'hôte ? Réseau Privé ? » (après 5 s) | Le pare-feu de l'hôte bloque le port 7777 (« Annuler » au premier hébergement, ou un réseau Public chez lui), ou l'adresse tapée n'est pas la sienne. | Sur l'hôte : réseau Privé, autoriser LeLion multi (plus bas) ; vérifier l'adresse dans son salon. |
| « Version différente de l'hôte (x.y) » | Deux versions du jeu. | Le même `LeLion-multi.exe` partout. |
| « Recherche impossible : port 7778 déjà utilisé (un autre LeLion ouvert ?). Rejoins par IP. » | Deux LeLion ouverts sur le même PC : un seul peut lister les parties. | Fermer l'autre, ou rejoindre par IP (127.0.0.1 pour une partie hébergée par ce PC). |
| « Impossible d'héberger : port 7777 occupé » | Un autre LeLion (ou un autre programme) héberge déjà sur ce PC. | Le fermer. |
| « La partie est complète. », « Une manche est en cours : réessaie à la fin. » | 6 joueurs au plus ; on n'arrive pas en pleine manche. | Attendre le retour au salon. |
| « Exclu : ta partie a mis trop de temps à charger. » | Ce PC a mis plus de 20 s à charger la manche. | Fermer les autres programmes, puis rejoindre au retour au salon. |
| « L'hôte a quitté la partie » | L'hôte est parti, ou son PC s'est mis en veille, ou son Wi-Fi a coupé. | Retour au titre ; l'hôte peut héberger de nouveau. |

**Autoriser LeLion multi après un « Annuler »** : Sécurité Windows → Pare-feu et protection du
réseau → **Autoriser une application via le pare-feu** → **Modifier les paramètres** → cocher
**Privé** en face de « LeLion multi » (« Godot Engine » pour un exe de la version 0.18 ou d'avant)
→ OK. Si LeLion reste bloqué : **Pare-feu Windows Defender avec fonctions avancées de sécurité**
(`wf.msc`) → **Règles de trafic entrant** → supprimer les règles « LeLion multi » marquées d'un
sens interdit rouge, puis héberger de nouveau : la fenêtre du premier lancement revient.

Le journal de chaque PC, utile après une soirée qui s'est mal passée :
`%APPDATA%\Godot\app_userdata\LeLion\logs\godot.log`.

## Running the game

Open the folder in Godot 4.7 or newer and run the main scene, or from the command line:

```sh
godot .
```

## Project layout

```
Scenes/     Titre (title), Main (a game), Intro (READY? VOMIT!), Lion, Ville (town), HUD, HUDBataille (battle HUD),
            Resultats (battle results), EcranReseau (network screen), Salon (lobby), PauseMenu, Reglages (settings),
            ControlesTactiles (touch controls), GameOver (CONTINUE? + summary), ColorPickup, BonusPickup,
            CoeurPickup, Soucoupe, Coccinelle, Boss
Scripts/    one script per scene; the autoloads GameState (game, players, levels, difficulties, arcade), Scores
            (records, preferences), Parametres (settings, CRT layer), Audio (sounds, layered music), Reseau (ENet
            transport, handshake, lobby table) and Decouverte (UDP game announcements); Manche (a networked round);
            pure logic: Joueur (a player), Commandes (inputs), Regles / ReglesSolo / ReglesBataille (rules of each
            mode), Territoire (cell ownership), Peinture (deterministic stamps), EtatLion, InterpolationLion and
            PredictionLocale (lions over the network), BilanManche (end of a round), PlacementPseudos; the lion's
            parts DeplacementLion, PareChocs, GerbeLion; Pilote (attract-mode autopilot)
Shaders/    Ville.gdshader (paint mask on the skyline), Lion.gdshader (mane tint), Crt.gdshader (optional CRT filter)
Assets/     Sprites (used), Sons (generated), Traductions (CSV → .translation), src (reference material, ignored by Godot)
tests/      unitaires, smoke_test, bataille_test, prediction_test, trace_lions (headless), reseau/ (multi-process
            network test, latency relay), screenshots and deux_fenetres (captures)
tools/      generer_sons.py (effects), generer_musique.py (layered chiptune, town + boss themes), generer_skylines.py (skylines, sprites)
docs/       screenshots, the design spec and the phase plans (superpowers/), the LAN test sheet (essai-lan.md, in French)
```

The paint is an RGBA mask the size of the skyline, stamped through a native blit wherever the
spew touches the town. Progress is counted on an 8 px cell grid that only covers the opaque
parts of the skyline. A level is just a silhouette PNG: add an entry to `GameState.NIVEAUX` to
create one, with `"boss": true` to invite the painter. His collision is generated from the alpha
of his SVG sprite, so replacing `Assets/Sprites/boss_peintre.svg` is enough to change his shape.

Code identifiers and comments are in French; player-facing text goes through Godot's
translation system, with both languages in `Assets/Traductions/traductions.csv`.

## Tests

Headless suites (the CI runs all but the last one); each ends on `== 0 échec(s) ==` when green
(test messages are in French):

```sh
godot --headless --script tests/unitaires.gd                       # pure logic: territory, rules, lobby table, protocol guard…
godot --headless --script tests/smoke_test.gd                      # solo game, title, network screen, lobby, a networked round
godot --headless --fixed-fps 60 --script tests/bataille_test.gd    # a 4-lion local battle, the Results screen, rematch
godot --headless --fixed-fps 60 --script tests/prediction_test.gd  # client-side prediction under simulated latency
bash tests/reseau/lancer.sh                                        # headless Godot processes on localhost; DIFFUSION=1 adds real broadcast
godot --headless --fixed-fps 60 --script tests/trace_lions.gd      # the lions' fingerprint, for refactors
```

The network test needs GNU `timeout` (coreutils) and takes about three minutes; run one suite at
a time (they share local ports).

Screenshots, with a real renderer (windows open while the scripts run):

```sh
godot --path . --rendering-driver opengl3 --script tests/screenshots.gd -- --dossier=/output/path [--parties=solo,reseau,salon,bataille,resultats]
godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=hote --dossier=/output/path
godot --path . --rendering-driver opengl3 --script tests/deux_fenetres.gd -- --role=client --dossier=/output/path
godot --path . --rendering-driver opengl3 --fixed-fps 60 --script tests/bataille_test.gd -- --captures=/output/path
```

`deux_fenetres.gd` is one host and one client in two real windows (start both, in any order).
Without a renderer (`--headless`), the two capture scripts go through their whole scenario without
writing anything: that is how the CI keeps them working.

Sounds are regenerated with `python3 tools/generer_sons.py`, the music with
`python3 tools/generer_musique.py`, skylines and sprites with `python3 tools/generer_skylines.py`.

## Export and CI

`export_presets.cfg` defines a Windows Desktop preset (a single `.exe` with the game data embedded,
the game's icon, name and version in its file properties) and a Web preset (the solo game). With
the export templates installed:

```sh
godot --headless --export-release "Windows Desktop" export/windows/LeLion-multi.exe
godot --headless --export-release Web export/web/index.html
```

The workflow in `.github/workflows/ci.yml` runs on every pull request and every push to `main`: it
installs Godot 4.7.2 and its export templates, runs the unit tests, the smoke test, the local
battle test, the prediction bench, the network test (real broadcast included) and the two capture
scripts without a renderer, exports both builds, checks the icon and metadata of the Windows
executable, and publishes it as the `LeLion-multi-windows` artifact (kept 30 days). Nothing is
deployed.
