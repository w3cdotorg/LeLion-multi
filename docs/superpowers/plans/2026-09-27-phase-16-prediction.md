# Phase 16 : la prédiction du lion local (commandes redondantes, interpolation, simulateur de latence), plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** sur un client, le lion du joueur local répond à la touche dans la frame même, avec le même pas de déplacement que l'hôte (`Lion.avancer`), et se recale sans à-coup sur l'état de l'hôte, qui fait foi ; les commandes partent numérotées et redondantes, l'hôte les applique une par tick, jamais deux fois ; les lions distants sont interpolés ; un simulateur de latence (relais UDP) permet de le vérifier sur ce Mac. Sortie : **banc de la prédiction et scénario 12 du test réseau verts sous 80 ms d'aller-retour, 40 ms de gigue et 5 % de pertes** ; la trace des lions inchangée (solo, bataille locale et hôte identiques) ; les cinq suites vertes 5 fois, le test réseau vert 5 fois sous bash 5 et 5 fois sous bash 3.2 ; **◉ partie à 2 fenêtres sous latence** (captures validées par l'utilisateur).

**Architecture:**
- **Chez l'hôte**, rien ne change à la simulation : chaque lion de client applique, au début de son tick, la commande suivante de sa file (`Commandes.appliquer_suivante` ; `Commandes.recevoir` y met chaque numéro neuf d'un paquet redondant, `Manche.recevoir_paquet_de`), puis écrit son état (`Lion.etat_reseau`, format `EtatLion` : instant, numéro de la dernière commande appliquée, position, vitesse commandée, recul, orientation), seul champ continu de son `Synchro` avec le vomi.
- **Sur un client**, un lion distant garde ses états et les rejoue avec 100 ms de retard, interpolés (`InterpolationLion`, dans `Lion._suivre_l_hote`). Le lion local a une `PredictionLocale` (enfant du lion, priorité physique -10) : elle lit les actions de ce poste une fois par tick, les numérote et les garde, les écrit dans les commandes manuelles du lion (la manche envoie la commande et les 3 précédentes, `PredictionLocale.paquet`), fait le pas du lion ; à chaque état neuf de l'hôte, au tick suivant, elle repart de cet état et rejoue les commandes pas encore appliquées (avec les chocs simulés à ces ticks), puis l'écart d'affichage s'amortit (95 % en 120 ms ; au-delà de 200 px, recalage immédiat).
- **Tests** : logique pure dans `tests/unitaires.gd` ; un banc à deux postes dans un seul processus (`tests/prediction_test.gd` : deux `SubViewport`, lignes à retard semées, en CI) ; un relais UDP qui retarde, mélange et jette les datagrammes d'ENet (`tests/reseau/relais.gd`), sous lequel le scénario 12 du test réseau joue une manche à 1 hôte et 2 clients.

**Tech Stack:** Godot 4.7.2, GDScript typé (`class_name`), `MultiplayerSynchronizer` (un `PackedByteArray` répliqué), `SubViewport` (un monde physique par poste dans le banc), `UDPServer` / `PacketPeerUDP` (le relais), tests headless (`tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd`, `tests/prediction_test.gd`, `tests/reseau/lancer.sh` + `joueur.gd` + `relais.gd`), `tests/trace_lions.gd` (hors CI).

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1 unités : `Commandes`, `PredictionLocale`, `Lion` ; §3.2 flux d'une frame ; §4 redondance, interpolation ; §4.1 prédiction du lion local ; §10 tests de prédiction ; §13 risques) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (ligne 16 ; tous les points de vigilance « phase 16 ») · plan précédent : `docs/superpowers/plans/2026-09-26-phase-15bis-decoupage-lion.md` (`Lion.avancer`, `DeplacementLion`, la trace) · prérequis : **phase 15 bis fusionnée** ; nouvelle branche `phase-16-prediction` depuis `main`.

## Écarts assumés

1. **Le lion local rejoue ses commandes** (la spec §1 mettait « rembobinage avec rejeu des commandes » hors périmètre) : sans rejeu, un recalage sur un état de l'hôte en retard d'un aller-retour ramène le lion en arrière de toute sa course pendant ce temps (≈ 30 px à pleine vitesse sous 80 ms), à chaque état ; la feuille de route l'anticipe (« son état tient en deux vecteurs […] que la prédiction pourra copier et restaurer pour rejouer ses commandes »). Seul le lion local rejoue ses propres commandes ; le monde (autres lions, ennemis) n'est jamais rembobiné. La spec est mise à jour (Task 8).
2. **Un seul état répliqué par lion** (`Lion.etat_reseau`, 33 octets, `EtatLion`) au lieu de `position`, `velocity` et `direction_du_lion` : d'un seul tenant, l'état porte le numéro de la dernière commande appliquée **avec** la position qui en résulte (le recalage en a besoin, spec §3.2), la vitesse commandée et le recul (le lion local en repart, jamais de la vitesse totale : point de vigilance de la phase 15 bis), l'orientation (plus d'orientation répliquée à part, donc plus de clignotement pendant un demi-tour : point de vigilance) et l'instant de l'hôte (l'interpolation s'y cale, pas sur l'heure d'arrivée, qui porte la gigue). Débit : environ 44 octets par lion et par envoi (33 octets et l'en-tête d'un `PackedByteArray`) au lieu de 24 (position et vitesse), soit de l'ordre de +80 % sur les ~15 Ko/s mesurés par client à 6 lions en phase 14 (estimation, non remesurée), encore loin de ce que tient un Wi-Fi.
3. **Chez l'hôte, une file de commandes par client** (`Commandes`, `FILE_MAX` = 8) : une commande appliquée par tick, dans l'ordre ; file vide, la dernière tient encore un tick (et la file s'allonge d'autant : elle absorbe d'elle-même la gigue) ; au-delà de 8, les plus anciennes sont sautées. La spec ne disait que « l'hôte ignore les numéros déjà vus » ; écrire la dernière commande reçue, comme en phase 14, appliquerait deux commandes arrivées ensemble en un seul tick et fausserait le numéro accusé. Invariant vérifié partout : `appliquees + sautees == numero_applique` (aucune commande appliquée deux fois).
4. **Pas de zone morte sous 4 px** (spec §4.1 : « écart inférieur à 4 px : rien ») : l'état physique est recalé à chaque état neuf (vitesse et recul compris, qu'une zone morte laisserait dériver) ; seul l'affichage glisse, par un décalage amorti (constante de temps 40 ms : 95 % en 120 ms, dans les « 100 à 150 ms » de la spec) ; au-delà de 200 px, recalage immédiat (spec). Les 4 px deviennent le seuil des tests.
5. **L'erreur de prédiction** que mesurent les tests : la position de l'hôte après une commande accusée, comparée à celle que le client avait prédite **au tick où il l'a lue** (ce que le joueur a vu), pas à une prédiction refaite depuis par un rejeu (qui ne mesurerait que l'écart d'un ou deux ticks : mesuré, elle laissait passer les mutations M1 et M2 de la Task 5).
6. **Pendant un étourdissement, la prédiction applique la règle de l'hôte** (commandes ignorées, `Lion.direction_pour`) au lieu d'être « suspendue » : le lion suit exactement l'hôte (son état, avancé du recul amorti des ticks pas encore accusés). Mesuré au banc : 0 px d'erreur une fois l'étourdissement connu ; environ 14 px à la fin, qui arrive au client avec un aller de retard pendant que l'hôte applique déjà ses commandes (absorbés par la correction douce).
7. **Les chocs simulés par le lion local sont notés et rejoués** (`PareChocs.choc_simule`) tant que l'hôte ne les a pas, et un pas rejoué ne bute que contre un lion que son pare-chocs touche à la position rejouée (`PareChocs.en_rejeu`) : mesuré au banc, sans cela un choc laisse 46,7 px d'erreur et un aller-retour de 16,4 px de l'affichage (M5) ; sans la note, 18,2 px (M4) ; avec les deux, 0,6 px et aucun aller-retour.
8. **L'interpolation garde 100 ms** (6 ticks) au lieu d'« environ 2 envois (≈ 50 ms) » (spec §4) : il faut couvrir la gigue simulée (40 ms d'étendue) et deux états perdus de suite (2 × 16,7 ms). Mesuré (unitaires, banc) : un lion distant à pleine vitesse avance de 5,06 à 6,34 px par tick pour 5,83, sans recul ni saut. En contrepartie, un choc contre un lion distant **qui bouge** se prédit contre une position en retard d'environ 140 ms : l'hôte fait foi, l'écart glisse (spec §13 complétée).
9. **Le simulateur de latence est un relais UDP de test** (`tests/reseau/relais.gd`), pas une option de lancement du jeu dans « notre couche d'envoi » (spec §4.1) : sous ENet, une perte simulée au-dessus d'ENet ferait disparaître pour de bon un message fiable (peinture, réactions) qu'en Wi-Fi ENet renverrait ; sous ENet, elle est fidèle (renvois compris). Aucun code dans le jeu livré, et `Scripts/Reseau.gd` n'est pas touché (la feuille de route le listait ; rien n'y est nécessaire : canaux, silences et poignée de main ne changent pas). Le relais sert aussi le contrôle à la main (◉, Task 7). Modèle : chaque datagramme part avec un retard de `latence / 2 ± gigue / 2` (tiré au hasard : l'ordre peut changer), ou se perd (`pertes` %), dans chaque sens ; « 80 / 40 / 5 » donne donc un aller-retour de 40 à 120 ms.
10. **Deux tests de prédiction** : le banc (`tests/prediction_test.gd`, un seul processus, lignes à retard semées, reproductible au tick près, `--fixed-fps 60`, ~1 s, en CI dans son propre pas) pour les cas précis (parcours, étourdissement, choc, écarts, hôte figé) et leurs mutations ; le scénario 12 du test réseau (vraies scènes, vrai ENet, vrai relais, ~38 s) pour le bout en bout. Le test réseau passe de ~110 s à ~150 s sur ce Mac, sous le `timeout 300` du pas de CI (point de vigilance « temps de la CI »).
11. **La trace des lions ne change pas, ni son script** : la bataille, le solo **et la réplique** gardent leur empreinte (une réplique qui n'a reçu aucun état garde la position qu'on lui écrit, comme avant ; l'interpolation est couverte par les unitaires, le smoke test et le banc).
12. **`Lion.avancer` renvoie un booléen** (faux, et une ligne `ERROR` par `push_error`, hors d'une image physique : le lion ne bouge pas). Le smoke test le vérifie une fois : ligne `ERROR: Lion.avancer hors d'une image physique : ce pas est ignoré` attendue dans sa sortie (pas une `SCRIPT ERROR`).
13. **Version 0.16** (`application/config/version`) : la RPC des commandes change de signature et la réplication du lion aussi ; deux postes de phases différentes doivent se refuser (point de vigilance M7). La phase 15 bis n'avait rien changé du protocole.
14. **Points de vigilance voisins traités ici** : l'hôte du scénario 10 efface ses scores de test (point « prochaine phase qui touche `lancer.sh` ») ; l'empreinte du test réseau compte la visibilité de l'étiquette de chaque lion (la borne `_marge_haute` de la prédiction suppose la même visibilité partout) ; le scénario 11 écrit la prédiction de chaque client resté (mesure seule : l'hôte y déplace les lions, recalages attendus).
15. **Contexte** : l'utilisateur a joué une manche à 3 sous Windows en Wi-Fi avec la version sans prédiction et trouvé que les commandes « suivent plutôt bien » ; il maintient la phase 16. Le réglage fin (`DUREE_CORRECTION`, `RETARD`) se fera sur son prochain essai (nouveau point de vigilance, phase 19).

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), commandes depuis `~/Sites/LeLion-multi`, branche `phase-16-prediction`.
- Fichiers de la phase : ➕ `Scripts/EtatLion.gd`, `Scripts/InterpolationLion.gd`, `Scripts/PredictionLocale.gd`, `tests/prediction_test.gd`, `tests/reseau/relais.gd` (+ leurs `.uid`, générés par l'import) ; ✏️ `Scripts/Commandes.gd`, `Scripts/Lion.gd`, `Scripts/PareChocs.gd`, `Scenes/Lion.tscn`, `Scripts/Manche.gd`, `Scripts/Main.gd`, `project.godot`, `tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/reseau/joueur.gd`, `tests/reseau/lancer.sh`, `.github/workflows/ci.yml` ; la spec et la feuille de route (Task 8). **`Scripts/Reseau.gd`, `tests/trace_lions.gd` et `tests/bataille_test.gd` ne changent pas** ; `Scripts/Reseau.gd` n'est jamais modifié, pas même le temps d'un essai.
- **Solo, bataille locale et hôte identiques** : après chaque tâche qui touche le lion (3, 4, 5), la trace est celle de la référence (Task 0) ; aucune vérification existante n'est affaiblie (seules changent celles qui décrivent l'ancienne réplication ou l'ancien envoi des commandes, remplacées par des vérifications du nouveau contrat).
- **La trace** : `export PATH="/opt/homebrew/bin:$PATH"; godot --headless --import . > /dev/null 2>&1; for k in 1 2 3; do timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/trace_lions.gd 2>&1 | grep -E "^TRACE|❌|SCRIPT ERROR" | tr '\n' ' '; echo; done`. Verdict : deux passages consécutifs identiques, égaux à la référence (règle de la phase 15 bis : les deux premiers après un import peuvent différer).
- **Seuils de la spec** (§4.1, §10) : 4 px (erreur de prédiction sans pertes ; convergence), 150 ms = 9 ticks (convergence après l'arrêt des commandes), 200 px (recalage immédiat), 100 à 150 ms (correction douce : `DUREE_CORRECTION` = 0,04 s), 3 commandes précédentes par paquet (`Commandes.REDONDANCE`), 80 ms / 40 ms / 5 % (latence aller-retour, gigue, pertes), 500 ms (silence d'un client, inchangé).
- Identifiants, commentaires et messages de test en français, docstrings `##`, tabulations.
- **Aucune séquence d'échappement `\u…` n'est tapée dans un fichier**. Vérifier après chaque écriture : `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd Scenes/Lion.tscn tests/*.gd tests/reseau/*.gd tests/reseau/lancer.sh` ne sort rien.
- Un test `--script` est compilé **avant** les autoloads : il ne nomme ni `GameState`, ni `Lion`, ni `PareChocs`, ni `PredictionLocale` (ils nomment des autoloads), ni la ville ; il peut nommer `Commandes`, `EtatLion`, `InterpolationLion`, `DeplacementLion`, `Joueur`, `Territoire`, `ReglesBataille`. Le banc charge la prédiction par `load("res://Scripts/PredictionLocale.gd")`.
- Après la création d'un script à `class_name` ou une modification de scène : `godot --headless --import .` avant les tests (il génère aussi le `.uid` du nouveau script, à committer avec lui).
- **Toujours lancer un test Godot avec `timeout`** et chercher les erreurs :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; O=""; timeout -k 5 300 godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd; O=""`, `T=tests/bataille_test.gd; O="--fixed-fps 60"`, `T=tests/prediction_test.gd; O="--fixed-fps 60"` ; le test réseau : `timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $?"; grep -E "❌|✅|== |\(bout|\(I1|\(latence" "$TMPDIR/r.log"`). Une `SCRIPT ERROR` ne change pas le code de sortie ; un script qui ne compile pas sort aussi en `code 0`, sans ligne `== n échec(s) ==`. Bruit connu : « ObjectDB instances were leaked », « resources still in use at exit » ; les `ERROR` voulues listées au plan de la phase 14, et désormais `ERROR: Lion.avancer hors d'une image physique : ce pas est ignoré` (smoke test, une fois).
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`**.
- **Attentes événementielles** : chaque attente du test réseau porte sur une ligne de journal ou un état observé (bornée), jamais une durée à l'aveugle ; le banc avance au tick près (`--fixed-fps 60`).
- Les cinq suites (unitaires, smoke, bataille, banc, trace) se valident sur **5 passages consécutifs verts**, sans relance ; le test réseau 5 fois sous bash 5 et 5 fois sous bash 3.2 (`/bin/bash`, macOS), sans relance.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Des paquets de commandes en rafale, en retard, en double, dans le désordre ou perdus au-delà de la redondance** (le Wi-Fi) : chaque commande appliquée au plus une fois, dans l'ordre, les sautées comptées, la file bornée. → unitaires `_tester_commandes_reseau` (Task 1) ; `_verifier_commandes` du banc (Tasks 4 et 5) ; lignes `COMMANDES` du scénario 12 (Task 6).
2. **Un étourdissement décidé par l'hôte pendant que le client prédit** : ni recul appliqué deux fois, ni commandes suivies pendant l'étourdissement, reprise immédiate à sa fin. → banc, scénario « étourdissement » (Task 5) ; mutations M1 (rejeu sans la règle) et M2 (recul de l'hôte noté comme choc local).
3. **Un choc contre un lion distant interpolé** : « boing » immédiat, sans attendre l'hôte, sans aller-retour de l'affichage. → banc, scénario « choc » (Task 5, écrit avant `en_rejeu`, qui le fait passer) ; mutations M4 et M5.
4. **Un écart imposé par l'hôte** (lion déplacé, téléporté) : glissade douce sous 200 px, recalage franc au-delà, jamais une glissade de 500 px. → banc, scénario « écarts » (Task 5) ; mutations M7 (jamais de recalage) et M8 (sans décalage d'affichage).
5. **Un hôte figé ou en pause** (gel, fin de manche) pendant que le client joue : aucun rejeu du même état, historique borné, recalage franc au dégel, aucune commande appliquée deux fois. → banc, scénario « hôte figé » (Task 5) ; mutation M3 (sans recalage).

---

### Task 0 : vérifications et référence de la trace

Ce plan est commité par le commit de planification : ne pas le recommiter, **ne jamais le modifier**. Vérifier que la phase 15 bis est fusionnée : `test -f Scripts/DeplacementLion.gd && test -f tests/trace_lions.gd && grep -c "func avancer(direction: Vector2, delta: float) -> void:" Scripts/Lion.gd` donne `1`, et `wc -l Scripts/Lion.gd` donne 325. Sinon, s'arrêter et le signaler. Les blocs « remplacer » citent le code tel que la phase 15 bis le laisse (vérifié en appliquant ce plan, bloc par bloc, à une copie de `origin/phase-15bis-decoupage-lion`) : si une ancre a bougé, l'adapter au texte réel sans changer le remplacement, et le noter.

« Step 0 » (règle du projet pour un fichier de plus de 300 lignes : `Scripts/Lion.gd`, `Scripts/Manche.gd`, `tests/smoke_test.gd`, `tests/unitaires.gd`, `tests/reseau/joueur.gd`) : pas de code mort à retirer (la phase 15 bis vient de passer sur le lion). Le vérifier pour les deux scripts du jeu :

```bash
for f in Scripts/Lion.gd Scripts/Manche.gd; do
	for n in $(grep -oE "^(const|var|func|static var|@onready var|@export var) [A-Za-z_]+" $f | awk '{print $NF}'); do
		[ "$(grep -rc "\b$n\b" Scripts tests | awk -F: '{s+=$2} END {print s}')" -lt 2 ] && echo "$f $n"
	done
done; grep -n "print(" Scripts/Lion.gd Scripts/Manche.gd
```

Expected (mesuré) : rien (aucun identifiant n'est cité qu'à sa seule déclaration ; aucun `print(`).

Puis : `git switch -c phase-16-prediction`, et la référence de la trace (commande des Global Constraints), notée dans `$TMPDIR/trace_reference.txt` (jamais commitée). Mesuré sur le Mac de préparation : `TRACE bataille 689790676 TRACE solo 185311436 TRACE replique 3757044499` (trois passages identiques) ; les empreintes dépendent de la plateforme : seules comptent celles de ce poste.

---

### Task 1 : les commandes numérotées, redondantes, en file (`Commandes`)

**Files:**
- Modify: `Scripts/Commandes.gd` (réécrit)
- Test: `tests/unitaires.gd`

**Interfaces:**
- Consumes : rien de neuf.
- Produces (Tasks 3 à 6) : `Commandes.REDONDANCE` (3), `FILE_MAX` (8), `TAILLE_ENTETE` (5), `TAILLE_COMMANDE` (9) ; `static func encoder_paquet(dernier: int, commandes: Array) -> PackedByteArray` (`commandes` : `[direction: Vector2, vomir: bool]`, de la plus ancienne à la dernière, 1 à 4) ; `static func decoder_paquet(octets: Variant) -> Array[Dictionary]` (`{numero, direction, vomir}`, vide si mal formé) ; `func recevoir(numero: int, direction: Vector2, vomir: bool) -> bool` ; `func appliquer_suivante() -> void` ; `func en_attente() -> int` ; `func remettre_au_repos() -> void` ; champs `numero_applique`, `dernier_recu`, `appliquees`, `sautees`, `file_max_vue` (int). `direction()`, `vomir()`, `suspendues`, `locales()`, `manuelles()` inchangés.

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_reseau_manche()
	_tester_deplacement_lion()
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)
```

par :

```gdscript
	_tester_reseau_manche()
	_tester_deplacement_lion()
	_tester_commandes_reseau()
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript


## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
## côtés (l'hôte la tient pour établie à l'accusé de réception de sa réponse) ; 1 s au plus.
```

par :

```gdscript


## Phase 16 : les commandes d'un client, numérotées et redondantes (la dernière et les 3 précédentes
## dans chaque paquet) ; chez l'hôte, une file dont le lion applique une commande par tick, dans
## l'ordre, jamais deux fois.
func _tester_commandes_reseau() -> void:
	print("-- Commandes numérotées et redondantes (phase 16)")
	var octets := Commandes.encoder_paquet(7, [[Vector2(0.5, 0.0), false], [Vector2(1, 0), true], [Vector2(0, -1), false], [Vector2(0.6, 0.8), true]])
	var paquet := Commandes.decoder_paquet(octets)
	_check(octets.size() == Commandes.TAILLE_ENTETE + 4 * Commandes.TAILLE_COMMANDE and paquet.size() == 4
		and paquet.map(func(c: Dictionary) -> int: return c.numero) == [4, 5, 6, 7]
		and paquet[3].direction == Vector2(0.6, 0.8) and paquet[3].vomir and paquet[1].vomir and not paquet[0].vomir,
		"un paquet porte la dernière commande et les 3 précédentes, numérotées, de la plus ancienne à la dernière (%d octets)" % octets.size())
	var cinq: Array = []
	for i in range(5):
		cinq.append([Vector2.ZERO, false])
	_check(Commandes.decoder_paquet(octets.slice(0, octets.size() - 1)).is_empty() and Commandes.decoder_paquet(Commandes.encoder_paquet(9, cinq)).is_empty()
		and Commandes.decoder_paquet(Commandes.encoder_paquet(3, [[Vector2(INF, 0), false]])).is_empty()
		and Commandes.decoder_paquet(Commandes.encoder_paquet(0, [[Vector2.ZERO, false]])).is_empty()
		and Commandes.decoder_paquet("paquet").is_empty() and Commandes.decoder_paquet(PackedByteArray()).is_empty(),
		"un paquet tronqué, trop long, non fini, numéroté sous 1 ou d'un autre type est refusé")

	var c := Commandes.manuelles()
	_check(_recevoir_paquet(c, 2, [[Vector2.RIGHT, false], [Vector2.DOWN, true]]) == 2 and _recevoir_paquet(c, 4, [[Vector2.RIGHT, false],
		[Vector2.DOWN, true], [Vector2.LEFT, false], [Vector2.UP, true]]) == 2 and c.en_attente() == 4 and c.numero_applique == 0,
		"deux paquets qui se chevauchent : chaque commande entre une fois dans la file (4 en attente)")
	_check(_recevoir_paquet(c, 3, [[Vector2.RIGHT, false], [Vector2.DOWN, true], [Vector2.LEFT, false]]) == 0 and c.en_attente() == 4,
		"un paquet en retard, déjà couvert par un plus récent, n'ajoute rien")
	var vues: Array[int] = []
	for i in range(4):
		c.appliquer_suivante()
		vues.append(c.numero_applique)
	_check(vues == [1, 2, 3, 4] and c.direction() == Vector2.UP and c.vomir() and c.appliquees == 4 and c.sautees == 0,
		"une commande par tick, dans l'ordre (%s)" % [vues])
	c.appliquer_suivante()
	_check(c.numero_applique == 4 and c.direction() == Vector2.UP and c.appliquees == 4,
		"file vide (commande en retard) : la dernière appliquée tient encore un tick, sans être comptée deux fois")
	_recevoir_paquet(c, 10, [[Vector2.LEFT, false], [Vector2.LEFT, false], [Vector2.LEFT, false], [Vector2(3, 4), true]])
	for i in range(4):
		c.appliquer_suivante()
	_check(c.numero_applique == 10 and c.sautees == 2 and c.appliquees + c.sautees == c.numero_applique
		and c.direction().is_equal_approx(Vector2(0.6, 0.8)),
		"trois paquets perdus de suite (5 à 9) : 5 et 6 manquent, sautés et comptés ; aucune commande n'est appliquée deux fois ; la direction reçue reste bornée")
	var neuves := 0
	for dernier in range(14, 31, 4):
		neuves += _recevoir_paquet(c, dernier, [[Vector2.RIGHT, false], [Vector2.RIGHT, false], [Vector2.RIGHT, false], [Vector2.RIGHT, true]])
	_check(c.en_attente() == Commandes.FILE_MAX and neuves == 20 and c.file_max_vue == Commandes.FILE_MAX,
		"un rattrapage d'un coup (20 commandes neuves) : la file garde les %d plus récentes" % Commandes.FILE_MAX)
	c.appliquer_suivante()
	_check(c.numero_applique == 30 - Commandes.FILE_MAX + 1 and c.appliquees + c.sautees == c.numero_applique,
		"les plus anciennes sont sautées, comptées, jamais appliquées (reprise à la %d)" % c.numero_applique)
	c.remettre_au_repos()
	_check(c.en_attente() == 0 and c.direction() == Vector2.ZERO and not c.vomir() and not c.recevoir(30, Vector2.RIGHT, true)
		and c.recevoir(31, Vector2.RIGHT, true), "client muet : repos, file vidée ; les numéros déjà reçus restent refusés, les suivants passent")


func _recevoir_paquet(c: Commandes, dernier: int, commandes: Array) -> int:
	var neuves := 0
	for commande in Commandes.decoder_paquet(Commandes.encoder_paquet(dernier, commandes)):
		if c.recevoir(commande.numero, commande.direction, commande.vomir):
			neuves += 1
	return neuves


## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
## côtés (l'hôte la tient pour établie à l'accusé de réception de sa réponse) ; 1 s au plus.
```


- [ ] **Step 2 : ils échouent**

Run : la commande des Global Constraints avec `T=tests/unitaires.gd`.
Expected (mesuré) : des `SCRIPT ERROR: Parse Error: Static function "encoder_paquet()" not found in base "Commandes".`, `… "decoder_paquet()" …`, `Cannot find member "FILE_MAX" in base "Commandes".`, aucune ligne `== n échec(s) ==`.

- [ ] **Step 3 : les commandes**

Remplacer tout le contenu de `Scripts/Commandes.gd` par :

```gdscript
class_name Commandes
extends RefCounted
## Intentions d'un lion : direction voulue et envie de vomir. Le lion ne lit jamais Input
## lui-même. Deux sources : les actions de ce poste (clavier, manette, tactile), ou des valeurs
## écrites par un tiers (pilote de la démo, tests, prédiction du lion local d'un client, et chez
## l'hôte les commandes reçues d'un client).
## Chez l'hôte (phase 16), les commandes d'un client arrivent numérotées, par paquets redondants (la
## dernière et jusqu'à REDONDANCE précédentes, `encoder_paquet`) : chaque numéro neuf entre dans une
## file (`recevoir`), dont le lion applique une commande par tick physique, dans l'ordre
## (`appliquer_suivante`) ; aucune n'est appliquée deux fois, et `numero_applique` (la dernière
## appliquée) part avec l'état du lion vers le client, qui y recale sa prédiction.

enum Source { LOCALES, MANUELLES }

## Commandes précédentes renvoyées avec chaque commande (spec §4 : la commande courante et les 3
## précédentes) : un paquet perdu en Wi-Fi ne fait pas sauter le lion.
const REDONDANCE := 3
## File d'attente maximale chez l'hôte, en commandes (ticks) : au-delà (un client qui rattrape d'un
## coup un retard de plusieurs images), les plus anciennes sont sautées, pour ne pas garder un retard
## que rien ne résorberait.
const FILE_MAX := 8
## Octets d'un paquet : numéro de la dernière commande (u32), nombre de commandes (u8), puis pour
## chacune, de la plus ancienne à la dernière, direction (deux f32) et vomir (u8).
const TAILLE_ENTETE := 5
const TAILLE_COMMANDE := 9

var source := Source.MANUELLES
## Lus seulement en source MANUELLES. direction() borne direction_voulue à une longueur de 1.
var direction_voulue := Vector2.ZERO
var vomir_voulu := false
## Vrai tant que ce poste a ouvert son menu local pendant une manche en réseau (la partie continue,
## spec §4) : les commandes valent alors le repos, quelle que soit leur source, pour qu'un joueur qui
## navigue dans le menu ne fasse ni avancer ni vomir son lion.
var suspendues := false
## Chez l'hôte : le numéro de la dernière commande appliquée (0 : aucune), le plus grand numéro reçu,
## et les comptes que lisent les tests (chaque numéro jusqu'à `numero_applique` est appliqué une fois
## ou sauté, jamais deux fois : `appliquees + sautees == numero_applique`).
var numero_applique := 0
var dernier_recu := 0
var appliquees := 0
var sautees := 0
## La plus longue file vue (tests).
var file_max_vue := 0
var _file: Array[Dictionary] = []


static func locales() -> Commandes:
	var c := Commandes.new()
	c.source = Source.LOCALES
	return c


static func manuelles() -> Commandes:
	return Commandes.new()


func direction() -> Vector2:
	if suspendues:
		return Vector2.ZERO
	if source == Source.LOCALES:
		return Input.get_vector("deplacer_gauche", "deplacer_droite", "deplacer_haut", "deplacer_bas")
	# Bornée : une valeur reçue du réseau pourrait dépasser 1 et rendre un lion plus rapide que sa
	# vitesse.
	return direction_voulue.limit_length(1.0)


func vomir() -> bool:
	if suspendues:
		return false
	if source == Source.LOCALES:
		return Input.is_action_pressed("vomir")
	return vomir_voulu


## Chez l'hôte : la commande `numero` d'un client entre dans la file, si elle est neuve (plus grande
## que toutes celles déjà reçues) et finie. Faux sinon (déjà vue, ou refusée).
func recevoir(numero: int, direction_recue: Vector2, vomir_recu: bool) -> bool:
	if numero <= dernier_recu or not direction_recue.is_finite():
		return false
	dernier_recu = numero
	_file.append({"numero": numero, "direction": direction_recue, "vomir": vomir_recu})
	while _file.size() > FILE_MAX:
		_file.pop_front()  # sautée : l'écart de numéros est compté par `appliquer_suivante`
	file_max_vue = maxi(file_max_vue, _file.size())
	return true


## Chez l'hôte, au début du tick physique du lion : la commande suivante de la file devient celle du
## lion. File vide (commande en retard ou perdue) : la dernière appliquée tient encore un tick.
func appliquer_suivante() -> void:
	if _file.is_empty():
		return
	var c: Dictionary = _file.pop_front()
	sautees += c.numero - numero_applique - 1
	numero_applique = c.numero
	appliquees += 1
	direction_voulue = c.direction
	vomir_voulu = c.vomir


## Commandes en attente dans la file (tests).
func en_attente() -> int:
	return _file.size()


## Chez l'hôte, un client muet depuis trop longtemps (`Manche.SILENCE_COMMANDES`) : son lion revient
## au repos et sa file se vide ; les numéros déjà reçus restent refusés.
func remettre_au_repos() -> void:
	direction_voulue = Vector2.ZERO
	vomir_voulu = false
	_file.clear()


## Le paquet d'un client : ses commandes `commandes` (`[direction: Vector2, vomir: bool]`, de la plus
## ancienne à la dernière, 1 à REDONDANCE + 1), dont la dernière porte le numéro `dernier` et les
## précédentes les numéros qui le précèdent.
static func encoder_paquet(dernier: int, commandes: Array) -> PackedByteArray:
	var octets := PackedByteArray()
	octets.resize(TAILLE_ENTETE + TAILLE_COMMANDE * commandes.size())
	octets.encode_u32(0, dernier)
	octets.encode_u8(4, commandes.size())
	for i in range(commandes.size()):
		var debut := TAILLE_ENTETE + TAILLE_COMMANDE * i
		var direction_envoyee: Vector2 = commandes[i][0]
		octets.encode_float(debut, direction_envoyee.x)
		octets.encode_float(debut + 4, direction_envoyee.y)
		octets.encode_u8(debut + 8, 1 if commandes[i][1] else 0)
	return octets


## Le paquet `octets` reçu d'un client : ses commandes `{numero, direction, vomir}`, de la plus
## ancienne à la dernière ; vide pour un paquet mal formé (autre type, taille, nombre de commandes
## hors de 1 à REDONDANCE + 1, numéros sous 1, direction non finie).
static func decoder_paquet(octets: Variant) -> Array[Dictionary]:
	var commandes: Array[Dictionary] = []
	if not (octets is PackedByteArray) or octets.size() < TAILLE_ENTETE:
		return commandes
	var nb: int = octets.decode_u8(4)
	var dernier: int = octets.decode_u32(0)
	if nb < 1 or nb > REDONDANCE + 1 or octets.size() != TAILLE_ENTETE + TAILLE_COMMANDE * nb or dernier < nb:
		return commandes
	for i in range(nb):
		var debut := TAILLE_ENTETE + TAILLE_COMMANDE * i
		var direction_recue := Vector2(octets.decode_float(debut), octets.decode_float(debut + 4))
		if not direction_recue.is_finite():
			return [] as Array[Dictionary]
		commandes.append({"numero": dernier - nb + 1 + i, "direction": direction_recue, "vomir": octets.decode_u8(debut + 8) != 0})
	return commandes
```


(`direction()` et `vomir()` ne changent pas : le solo, la démo et la bataille locale lisent leurs commandes comme avant ; une file vide ne touche à rien.)

- [ ] **Step 4 : ils passent, la trace ne change pas**

Run : `godot --headless --import .`, puis les unitaires, le smoke test et la trace.
Expected : `== 0 échec(s) ==` partout, dont « une commande par tick, dans l'ordre ([1, 2, 3, 4]) », « trois paquets perdus de suite (5 à 9) : 5 et 6 manquent, sautés et comptés… », « un rattrapage d'un coup (20 commandes neuves) : la file garde les 8 plus récentes », « les plus anciennes sont sautées, comptées, jamais appliquées (reprise à la 23) » ; la trace égale à la référence.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/Commandes.gd tests/unitaires.gd
git commit -m "Commandes : paquets numérotés et redondants (la commande et les 3 précédentes), file de l'hôte qui en applique une par tick, dans l'ordre, jamais deux fois ; tests unitaires

<ligne fournie par l'environnement>"
```

---

### Task 2 : l'état d'un lion au format réseau et l'interpolation (`EtatLion`, `InterpolationLion`)

**Files:**
- Create: `Scripts/EtatLion.gd`, `Scripts/InterpolationLion.gd` (+ `.uid`)
- Test: `tests/unitaires.gd`

**Interfaces:**
- Consumes : rien.
- Produces (Tasks 3 à 5) : `EtatLion.TAILLE` (33) ; `static func encoder(instant: int, commande: int, position: Vector2, vitesse: Vector2, recul: Vector2, direction: int) -> PackedByteArray` ; `static func decoder(octets: Variant) -> Dictionary` (`{instant, commande, position, vitesse, recul, direction}`, vide si mal formé). `InterpolationLion.new(ticks_par_seconde := 60)` ; constantes `RETARD` (6.0), `EXTRAPOLATION_MAX` (3.0), `RATTRAPAGE` (0.05), `ECART_MAX` (30.0), `TAMPON_MAX` (32) ; `func ajouter(instant: int, position: Vector2, vitesse: Vector2, direction: int) -> void` ; `func avancer(ticks: float) -> void` ; `func echantillon() -> Dictionary` (`{position, vitesse, direction}`, vide tant qu'aucun état) ; `func retard() -> float`.

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd`, remplacer :

```gdscript
	_tester_deplacement_lion()
	_tester_commandes_reseau()
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)
```

par :

```gdscript
	_tester_deplacement_lion()
	_tester_commandes_reseau()
	_tester_etat_lion()
	_tester_interpolation_lion()
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)
```

Dans `tests/unitaires.gd`, remplacer :

```gdscript


## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
## côtés (l'hôte la tient pour établie à l'accusé de réception de sa réponse) ; 1 s au plus.
```

par :

```gdscript


## Phase 16 : l'état d'un lion chez l'hôte, au format réseau (ce que recopie son `Synchro`).
func _tester_etat_lion() -> void:
	print("-- État d'un lion au format réseau (phase 16)")
	var octets := EtatLion.encoder(123456, 789, Vector2(512.5, -30.25), Vector2(350, -12.5), Vector2(-700, 0), -1)
	var e := EtatLion.decoder(octets)
	_check(octets.size() == EtatLion.TAILLE and e.instant == 123456 and e.commande == 789 and e.position == Vector2(512.5, -30.25)
		and e.vitesse == Vector2(350, -12.5) and e.recul == Vector2(-700, 0) and e.direction == -1,
		"instant, dernière commande appliquée, position, vitesse commandée, recul et orientation font l'aller-retour (%d octets)" % octets.size())
	var nan := EtatLion.encoder(1, 0, Vector2(NAN, 0), Vector2.ZERO, Vector2.ZERO, 1)
	var sans_sens := EtatLion.encoder(1, 0, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 0)
	_check(EtatLion.decoder(nan).is_empty() and EtatLion.decoder(sans_sens).is_empty() and EtatLion.decoder(octets.slice(1)).is_empty()
		and EtatLion.decoder("état").is_empty(), "un état non fini, sans orientation, tronqué ou d'un autre type est refusé")


## Phase 16 : un lion distant sur un client, interpolé entre les états reçus avec RETARD ticks de
## retard ; ici sous une gigue de ±1,2 tick (±20 ms) autour de 3 ticks de latence et 5 % de pertes.
func _tester_interpolation_lion() -> void:
	print("-- Interpolation d'un lion distant (phase 16)")
	var interp := InterpolationLion.new(60)
	interp.avancer(1.0)
	_check(interp.echantillon().is_empty(), "sans état reçu, rien à afficher (le lion garde sa place)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 16
	var vitesse := 350.0
	var en_route: Array = []  # [tick d'arrivée, instant de l'hôte]
	var xs: Array[float] = []
	var retards: Array[float] = []
	for t in range(600):
		if rng.randf() >= 0.05:
			en_route.append([t + 3.0 + rng.randf_range(-1.2, 1.2), t])
		for m: Array in en_route:
			if m[0] <= t:
				interp.ajouter(m[1], Vector2(m[1] * vitesse / 60.0, 100.0), Vector2(vitesse, 0.0), 1)
		en_route = en_route.filter(func(m: Array) -> bool: return m[0] > t)
		interp.avancer(1.0)
		var vu := interp.echantillon()
		if not vu.is_empty():
			xs.append(vu.position.x)
			retards.append(t - vu.position.x * 60.0 / vitesse)
	var pas_min := INF
	var pas_max := -INF
	for i in range(120, xs.size()):
		pas_min = minf(pas_min, xs[i] - xs[i - 1])
		pas_max = maxf(pas_max, xs[i] - xs[i - 1])
	var retard_moyen := 0.0
	for i in range(120, retards.size()):
		retard_moyen += retards[i] / (retards.size() - 120)
	_check(pas_min > 0.8 * vitesse / 60.0 and pas_max < 1.2 * vitesse / 60.0,
		"sous la gigue et les pertes, le lion affiché avance d'un pas régulier, sans recul ni saut (%.2f à %.2f px par tick, pour %.2f)" % [pas_min, pas_max, vitesse / 60.0])
	_check(retard_moyen > InterpolationLion.RETARD + 1.0 and retard_moyen < InterpolationLion.RETARD + 5.0,
		"avec %.1f ticks de retard en moyenne sur l'hôte (le retard d'affichage et la latence)" % retard_moyen)
	var fin := xs[-1]
	for t in range(30):
		interp.avancer(1.0)
	var arret: Vector2 = interp.echantillon().position
	interp.avancer(1.0)
	_check(arret == interp.echantillon().position and arret.x <= 599 * vitesse / 60.0 + InterpolationLion.EXTRAPOLATION_MAX * vitesse / 60.0 + 0.01 and arret.x > fin,
		"plus aucun état : le lion continue sur sa vitesse %d ticks au plus, puis s'arrête" % int(InterpolationLion.EXTRAPOLATION_MAX))
	var desordre := InterpolationLion.new(60)
	desordre.ajouter(10, Vector2(0, 0), Vector2.ZERO, 1)
	desordre.ajouter(12, Vector2(20, 0), Vector2.ZERO, -1)
	desordre.ajouter(11, Vector2(100, 0), Vector2.ZERO, 1)  # arrivé après le 12
	desordre.ajouter(11, Vector2(999, 0), Vector2.ZERO, 1)  # doublon
	for t in range(int(InterpolationLion.RETARD)):
		desordre.avancer(1.0)
	var horloge := 12.0 - desordre.retard()
	var milieu: Dictionary = desordre.echantillon()
	_check(horloge > 10.0 and horloge < 11.0 and is_equal_approx(milieu.position.x, (horloge - 10.0) * 100.0) and milieu.direction == 1,
		"un état arrivé en retard se range à son instant, un doublon est ignoré (x = %.1f à l'instant %.2f)" % [milieu.position.x, horloge])
	desordre.ajouter(200, Vector2(200, 0), Vector2.ZERO, 1)
	desordre.avancer(1.0)
	_check(is_equal_approx(desordre.retard(), InterpolationLion.RETARD), "un saut de plus d'ECART_MAX ticks (un poste figé) recale l'horloge d'un coup")


## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
## côtés (l'hôte la tient pour établie à l'accusé de réception de sa réponse) ; 1 s au plus.
```


- [ ] **Step 2 : ils échouent**

Run : les unitaires. Expected (mesuré) : des `SCRIPT ERROR: Parse Error: Cannot infer the type of "octets" variable because the value doesn't have a set type.` (de même pour `interp`, `vu`, `desordre`… : `EtatLion` et `InterpolationLion` n'existent pas encore), aucune ligne `== n échec(s) ==`.

- [ ] **Step 3 : l'état et l'interpolation**

Créer `Scripts/EtatLion.gd` :

```gdscript
class_name EtatLion
extends RefCounted
## L'état d'un lion chez l'hôte, au format réseau (phase 16, logique pure : les tests `--script` le
## nomment). L'hôte l'écrit à chaque tick physique dans `Lion.etat_reseau`, que le `Synchro` du lion
## recopie chez chaque client, d'un seul tenant : l'instant (tick physique de l'hôte), le numéro de la
## dernière commande du client appliquée à ce lion (0 : aucune, ou le lion de l'hôte), la position, la
## vitesse commandée et le recul (`DeplacementLion`), l'orientation. Un client y interpole les lions
## distants (`InterpolationLion`) et y recale la prédiction de son lion (`PredictionLocale`), qui
## repart de la vitesse commandée et du recul de l'hôte, jamais de sa vitesse totale.

## Octets : instant (u32), commande (u32), position, vitesse, recul (deux f32 chacun), orientation (s8).
const TAILLE := 33


static func encoder(instant: int, commande: int, position: Vector2, vitesse: Vector2, recul: Vector2, direction: int) -> PackedByteArray:
	var octets := PackedByteArray()
	octets.resize(TAILLE)
	octets.encode_u32(0, instant)
	octets.encode_u32(4, commande)
	octets.encode_float(8, position.x)
	octets.encode_float(12, position.y)
	octets.encode_float(16, vitesse.x)
	octets.encode_float(20, vitesse.y)
	octets.encode_float(24, recul.x)
	octets.encode_float(28, recul.y)
	octets.encode_s8(32, direction)
	return octets


## L'état `octets` reçu de l'hôte : `{instant, commande, position, vitesse, recul, direction}`, ou un
## dictionnaire vide s'il est mal formé (autre type, taille, valeur non finie, orientation autre que
## 1 ou -1).
static func decoder(octets: Variant) -> Dictionary:
	if not (octets is PackedByteArray) or octets.size() != TAILLE:
		return {}
	var etat := {"instant": octets.decode_u32(0), "commande": octets.decode_u32(4),
		"position": Vector2(octets.decode_float(8), octets.decode_float(12)),
		"vitesse": Vector2(octets.decode_float(16), octets.decode_float(20)),
		"recul": Vector2(octets.decode_float(24), octets.decode_float(28)), "direction": octets.decode_s8(32)}
	if not (etat.position.is_finite() and etat.vitesse.is_finite() and etat.recul.is_finite()) or absi(etat.direction) != 1:
		return {}
	return etat
```


Créer `Scripts/InterpolationLion.gd` :

```gdscript
class_name InterpolationLion
extends RefCounted
## L'affichage d'un lion distant sur un client (phase 16, spec §4, logique pure : les tests
## `--script` la nomment) : les états reçus de l'hôte (`EtatLion`), rangés par instant de l'hôte,
## sont rejoués avec RETARD ticks de retard, par interpolation entre les deux qui encadrent l'instant
## affiché. Ce retard absorbe la gigue et les pertes du Wi-Fi : un état en retard ou perdu tombe entre
## deux autres, qui suffisent. L'horloge d'affichage avance d'un tick par tick physique du client et se
## recale en douceur sur le dernier instant reçu (RATTRAPAGE de l'écart par tick), d'un coup au-delà
## d'ECART_MAX (premier état, gel d'un des postes). Plus aucun état : le lion continue sur sa vitesse
## EXTRAPOLATION_MAX ticks au plus, puis s'arrête.

## Retard d'affichage, en ticks de l'hôte (100 ms à 60 ticks par seconde) : plus que la gigue simulée
## (40 ms) et deux états perdus de suite (2 × 16,7 ms).
const RETARD := 6.0
const EXTRAPOLATION_MAX := 3.0
const RATTRAPAGE := 0.05
const ECART_MAX := 30.0
const TAMPON_MAX := 32

var _ticks_par_seconde := 60.0
## États reçus (`{instant, position, vitesse, direction}`), par instant croissant, sans doublon.
var _etats: Array[Dictionary] = []
## Instant affiché, en ticks de l'hôte (négatif tant qu'aucun état n'est arrivé).
var _horloge := -1.0
var _dernier := -1


func _init(ticks_par_seconde := 60) -> void:
	_ticks_par_seconde = float(ticks_par_seconde)


## Un état reçu de l'hôte, à son instant `instant` : `vitesse` est la vitesse totale du lion
## (commandée et recul), que lisent son animation et le pare-chocs du lion local. Un état plus ancien
## que ceux qu'on affiche déjà, ou déjà reçu, est ignoré.
func ajouter(instant: int, position: Vector2, vitesse: Vector2, direction: int) -> void:
	if (_horloge >= 0.0 and instant < _horloge - 1.0) or _etats.any(func(e: Dictionary) -> bool: return e.instant == instant):
		return
	var i := _etats.size()
	while i > 0 and _etats[i - 1].instant > instant:
		i -= 1
	_etats.insert(i, {"instant": instant, "position": position, "vitesse": vitesse, "direction": direction})
	while _etats.size() > TAMPON_MAX:
		_etats.pop_front()
	_dernier = maxi(_dernier, instant)


## Un tick physique du client (`ticks` ticks de l'hôte, 1 à la même cadence) : l'horloge avance et se
## recale sur le dernier instant reçu, moins RETARD ; les états trop vieux s'en vont (on garde celui
## qui précède l'instant affiché).
func avancer(ticks: float) -> void:
	if _dernier < 0:
		return
	var cible := _dernier - RETARD
	if _horloge < 0.0:
		_horloge = cible
	else:
		_horloge += ticks
		var ecart := cible - _horloge
		if absf(ecart) > ECART_MAX:
			_horloge = cible
		else:
			_horloge += ecart * RATTRAPAGE
	while _etats.size() > 2 and _etats[1].instant <= _horloge:
		_etats.pop_front()


## Ce qu'affiche le lion à l'instant de l'horloge : `{position, vitesse, direction}`, ou un
## dictionnaire vide tant qu'aucun état n'est arrivé.
func echantillon() -> Dictionary:
	if _etats.is_empty() or _horloge < 0.0:
		return {}
	var a: Dictionary = _etats[0]
	if _horloge <= a.instant:
		return {"position": a.position, "vitesse": a.vitesse, "direction": a.direction}
	for i in range(_etats.size() - 1):
		var b: Dictionary = _etats[i + 1]
		if _horloge <= b.instant:
			a = _etats[i]
			var t: float = (_horloge - a.instant) / float(b.instant - a.instant)
			return {"position": a.position.lerp(b.position, t), "vitesse": a.vitesse.lerp(b.vitesse, t), "direction": a.direction}
	var dernier: Dictionary = _etats[-1]
	var avance := minf(_horloge - dernier.instant, EXTRAPOLATION_MAX)
	return {"position": dernier.position + dernier.vitesse * avance / _ticks_par_seconde, "vitesse": dernier.vitesse, "direction": dernier.direction}


## Retard de l'affichage sur le dernier état reçu, en ticks de l'hôte (tests).
func retard() -> float:
	return _dernier - _horloge
```


- [ ] **Step 4 : ils passent**

Run : `godot --headless --import .` (deux `class_name` neufs), puis les unitaires.
Expected : `== 0 échec(s) ==`, dont (mesuré) « instant, dernière commande appliquée, position, vitesse commandée, recul et orientation font l'aller-retour (33 octets) », « sous la gigue et les pertes, le lion affiché avance d'un pas régulier, sans recul ni saut (5.06 à 6.34 px par tick, pour 5.83) », « avec 9.5 ticks de retard en moyenne sur l'hôte… », « un état arrivé en retard se range à son instant, un doublon est ignoré (x = 29.8 à l'instant 10.30) ».

- [ ] **Step 5 : Commit**

```bash
git add Scripts/EtatLion.gd Scripts/EtatLion.gd.uid Scripts/InterpolationLion.gd Scripts/InterpolationLion.gd.uid tests/unitaires.gd
git commit -m "EtatLion : l'état d'un lion au format réseau (instant, dernière commande appliquée, position, vitesse commandée, recul, orientation) ; InterpolationLion : un lion distant rejoué avec 100 ms de retard, sous la gigue et les pertes ; tests unitaires

<ligne fournie par l'environnement>"
```

---

### Task 3 : le lion écrit son état, les lions distants sont interpolés (`Lion`, `PareChocs`, `Lion.tscn`)

**Files:**
- Modify: `Scripts/Lion.gd`, `Scripts/PareChocs.gd`, `Scenes/Lion.tscn`
- Test: `tests/smoke_test.gd`

**Interfaces:**
- Consumes : Task 1 (`Commandes.appliquer_suivante`, `numero_applique`), Task 2 (`EtatLion.encoder` / `decoder`, `InterpolationLion`).
- Produces (Tasks 4 à 6) : `Lion.etat_reseau: PackedByteArray` (répliqué, seul champ continu du `Synchro` avec `vomi_de_l_hote`) ; `Lion.ETATS_RECUS_MAX` (64) ; `func avancer(direction: Vector2, delta: float) -> bool` (faux hors d'une image physique) ; `func direction_pour(voulue: Vector2) -> Vector2` ; `Lion._etats_recus: Array[Dictionary]` (états décodés reçus depuis le dernier tick, sur un client) ; `PareChocs.choc_simule(vitesse: Vector2, recul: Vector2)` (signal). Chez l'hôte, chaque lion applique `commandes.appliquer_suivante()` en tête de tick et écrit `etat_reseau` en fin de tick.

- [ ] **Step 1 : les tests**

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	lr.deplacement.vitesse = Vector2.ZERO
	lr.global_position = Vector2(600, 300)

	# Phase 14 : sur un client, un lion n'est qu'une réplique du lion de l'hôte (position, vitesse,
	# orientation et vomi reçus par son Synchro ; réactions par les signaux de son joueur)
	var synchro_lion := lr.get_node_or_null("Synchro") as MultiplayerSynchronizer
	var config_lion: SceneReplicationConfig = null if synchro_lion == null else synchro_lion.replication_config
	_check(config_lion != null and config_lion.get_properties() == [^".:position", ^".:velocity", ^".:direction_du_lion", ^".:vomi_de_l_hote"]
		and config_lion.property_get_replication_mode(^".:position") == SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		and config_lion.property_get_replication_mode(^".:velocity") == SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		and config_lion.property_get_replication_mode(^".:direction_du_lion") == SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		and config_lion.property_get_replication_mode(^".:vomi_de_l_hote") == SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		and config_lion.get_properties().all(func(p: NodePath) -> bool: return config_lion.property_get_spawn(p)),
		"le Synchro du lion réplique position et vitesse en continu, orientation et vomi à chaque changement, tous à l'apparition")
	var poste_lion := Node2D.new()
	poste_lion.name = "PosteClientLion"
```

par :

```gdscript
	lr.deplacement.vitesse = Vector2.ZERO
	lr.global_position = Vector2(600, 300)
	# Phase 16 : hors d'une image physique (le sondage réseau, où arrivent les états de l'hôte), le pas
	# est refusé : `move_and_slide` y intégrerait le delta de traitement
	await process_frame
	var x_hors: float = lr.global_position.x
	_check(not lr.avancer(Vector2.RIGHT, dt_pas) and lr.global_position.x == x_hors and lr.deplacement.vitesse == Vector2.ZERO,
		"hors d'une image physique, le pas est refusé : le lion ne bouge pas (ligne ERROR attendue)")
	await _frames(1)
	# Phase 16 : chez l'hôte, chaque tick écrit l'état du lion, que son Synchro recopie chez les clients
	lr.global_position = Vector2(640, 320)
	await _frames(2)
	var etat_lr: Dictionary = EtatLion.decoder(lr.etat_reseau)
	_check(not etat_lr.is_empty() and etat_lr.position == lr.position and etat_lr.vitesse == lr.deplacement.vitesse
		and etat_lr.recul == lr.deplacement.recul and etat_lr.direction == lr.direction_du_lion and etat_lr.commande == 0,
		"chaque tick, l'hôte écrit l'état du lion : position, vitesse commandée, recul, orientation (aucune commande de client)")

	# Phase 14 : sur un client, un lion n'est qu'une réplique du lion de l'hôte (état et vomi reçus par
	# son Synchro ; réactions par les signaux de son joueur). Phase 16 : il est interpolé entre les états
	var synchro_lion := lr.get_node_or_null("Synchro") as MultiplayerSynchronizer
	var config_lion: SceneReplicationConfig = null if synchro_lion == null else synchro_lion.replication_config
	_check(config_lion != null and config_lion.get_properties() == [^".:etat_reseau", ^".:vomi_de_l_hote"]
		and config_lion.property_get_replication_mode(^".:etat_reseau") == SceneReplicationConfig.REPLICATION_MODE_ALWAYS
		and config_lion.property_get_replication_mode(^".:vomi_de_l_hote") == SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
		and not config_lion.property_get_spawn(^".:etat_reseau") and config_lion.property_get_spawn(^".:vomi_de_l_hote"),
		"le Synchro du lion réplique son état en continu (sans rien à l'apparition) et son vomi à chaque changement (dès l'apparition)")
	var poste_lion := Node2D.new()
	poste_lion.name = "PosteClientLion"
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	_check(repl.position == Vector2(600, 500) and repl.velocity == Vector2.ZERO and not repl.est_en_train_de_vomir,
		"sur un client, un lion ne suit pas ses commandes : il ne bouge ni ne vomit de lui-même")
	repl.position = Vector2(700, 500)  # ce qu'écrit le Synchro
	repl.velocity = Vector2(350, 0)
	repl.direction_du_lion = 1
	repl.vomi_de_l_hote = true
	for i in range(3):
		await process_frame  # le vomi démarre dans _process
	await _frames(1)
	_check(repl.position == Vector2(700, 500) and repl.sprite.scale.x == 1.0 and repl.deplacement.vitesse == Vector2(350, 0)
		and repl.est_en_train_de_vomir and repl.gerbe.vomi_container.get_children().all(func(e: GPUParticles2D) -> bool: return e.emitting),
		"la réplique suit l'état reçu : position, vitesse (son animation), orientation, vomi (particules)")
	repl.vomi_de_l_hote = false
	for i in range(3):
```

par :

```gdscript
	_check(repl.position == Vector2(600, 500) and repl.velocity == Vector2.ZERO and not repl.est_en_train_de_vomir,
		"sur un client, un lion ne suit pas ses commandes : il ne bouge ni ne vomit de lui-même")
	# Ce qu'écrit le Synchro : un état par tick de l'hôte, le lion filant vers la droite à 350 px/s
	var pas_repl := 350.0 / 60.0
	for i in range(12):
		repl.etat_reseau = EtatLion.encoder(1000 + i, 0, Vector2(700 + i * pas_repl, 500), Vector2(350, 0), Vector2.ZERO, 1)
		await _frames(1)
	repl.vomi_de_l_hote = true
	for i in range(3):
		await process_frame  # le vomi démarre dans _process
	await _frames(1)
	_check(repl.position.y == 500.0 and repl.position.x > 700.0 and repl.position.x < 700.0 + 11 * pas_repl and repl.sprite.scale.x == 1.0
		and repl.velocity == Vector2(350, 0) and repl.deplacement.vitesse == Vector2(350, 0)
		and repl.est_en_train_de_vomir and repl.gerbe.vomi_container.get_children().all(func(e: GPUParticles2D) -> bool: return e.emitting),
		"la réplique suit les états reçus, interpolés avec un peu de retard (x = %.1f) : position, vitesse (son animation), orientation, vomi (particules)" % repl.position.x)
	await _frames(30)
	var arret_repl: Vector2 = repl.position
	_check(arret_repl.is_equal_approx(Vector2(700 + (11 + InterpolationLion.EXTRAPOLATION_MAX) * pas_repl, 500)),
		"plus aucun état : la réplique continue sur sa vitesse %d ticks, puis s'arrête (x = %.1f)" % [int(InterpolationLion.EXTRAPOLATION_MAX), arret_repl.x])
	repl.vomi_de_l_hote = false
	for i in range(3):
```

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	await _frames(2)
	var mat_repl := repl.sprite.material as ShaderMaterial
	_check(repl.etoiles.visible and mat_repl.get_shader_parameter("barbouillage_couleur") == j_rouge.couleur and repl.position == Vector2(700, 500),
		"un étourdissement reçu de l'hôte s'affiche sur la réplique (étoiles, barbouillage), sans la déplacer")
	j_repl.recevoir_fin_etourdissement(ReglesBataille.DUREE_IMMUNITE)
```

par :

```gdscript
	await _frames(2)
	var mat_repl := repl.sprite.material as ShaderMaterial
	_check(repl.etoiles.visible and mat_repl.get_shader_parameter("barbouillage_couleur") == j_rouge.couleur and repl.position == arret_repl,
		"un étourdissement reçu de l'hôte s'affiche sur la réplique (étoiles, barbouillage), sans la déplacer")
	j_repl.recevoir_fin_etourdissement(ReglesBataille.DUREE_IMMUNITE)
```


- [ ] **Step 2 : ils échouent**

Run : le smoke test, avec `timeout -k 5 60` au lieu de 300 (une erreur de script arrête la coroutine du test, qui ne quitte plus : il sort par le délai, code 124). Expected (mesuré) : `❌ hors d'une image physique, le pas est refusé : le lion ne bouge pas (ligne ERROR attendue)`, puis `SCRIPT ERROR: Invalid access to property or key 'etat_reseau' on a base object of type 'CharacterBody2D (Lion)'.`, sans ligne `== n échec(s) ==`.

- [ ] **Step 3 : le lion**

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
## Le lion ne décide de rien : sur l'hôte, il signale aux règles les autres lions que touche
## sa gerbe et ceux qu'il percute, comme le font les ennemis et les pastilles.
## En réseau (phase 14), seul l'hôte simule les lions ; sur un client, chaque lion est une réplique
## (`_suivre_l_hote`) : position, vitesse, orientation et vomi viennent de l'hôte par son
## `MultiplayerSynchronizer` (`Synchro`), ses réactions (étourdissement, crans, gerbe XXL) par les
## signaux de son joueur, que la manche lui transmet (`Joueur.recevoir_*`).

const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
```

par :

```gdscript
## Le lion ne décide de rien : sur l'hôte, il signale aux règles les autres lions que touche
## sa gerbe et ceux qu'il percute, comme le font les ennemis et les pastilles.
## En réseau (phase 14), l'hôte simule les lions et écrit à chaque tick l'état de chacun
## (`etat_reseau`, `EtatLion` : position, vitesse commandée, recul, orientation, dernière commande
## appliquée), que son `MultiplayerSynchronizer` (`Synchro`) recopie chez chaque client avec son vomi ;
## ses réactions (étourdissement, crans, gerbe XXL) arrivent par les signaux de son joueur, que la
## manche lui transmet (`Joueur.recevoir_*`). Sur un client (phase 16), un lion distant est affiché
## avec un peu de retard, interpolé entre les états reçus (`_suivre_l_hote`, `InterpolationLion`) ; le
## lion du joueur local est prédit (`prediction`, `PredictionLocale`) : il avance tout de suite avec les
## commandes de ce poste, par le même pas que l'hôte (`avancer`), et se recale sur ses états.

const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
const DUREE_SECOUSSE := 0.25
const AMPLITUDE_SECOUSSE := 6.0

@export var inclinaison_max: float = 0.14  # radians
```

par :

```gdscript
const DUREE_SECOUSSE := 0.25
const AMPLITUDE_SECOUSSE := 6.0
## États de l'hôte gardés au plus entre deux ticks physiques d'un client.
const ETATS_RECUS_MAX := 64

@export var inclinaison_max: float = 0.14  # radians
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript

var est_en_train_de_vomir := false
## 1 = droite, -1 = gauche. Répliquée chez les clients (`Synchro`) : le setter y retourne le sprite
## et réoriente la gerbe.
var direction_du_lion: int = 1:
	set(valeur):
```

par :

```gdscript

var est_en_train_de_vomir := false
## 1 = droite, -1 = gauche. Le setter retourne le sprite et réoriente la gerbe. Sur un client, celle
## d'un lion distant vient de ses états interpolés, celle du lion local de sa prédiction (jamais
## remise à l'ancienne orientation de l'hôte pendant un demi-tour).
var direction_du_lion: int = 1:
	set(valeur):
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
			return
		joueur = valeur
var commandes: Commandes
## Vitesse commandée et recul du lion (logique pure) : ce que `avancer` fait avancer d'un pas.
var deplacement := DeplacementLion.new()
```

par :

```gdscript
			return
		joueur = valeur
## Chez l'hôte, un lion de client applique une commande reçue par tick (`Commandes.appliquer_suivante`) ;
## sur un client, le lion local a des commandes manuelles, que remplit sa prédiction.
var commandes: Commandes
## Vrai sur un client (fixé dans `_ready`) : les états reçus de l'hôte y sont gardés pour le prochain
## tick physique.
var _replique := false
## Sur un client : les états reçus de l'hôte depuis le dernier tick physique (décodés, dans l'ordre
## d'arrivée), rejoués dans ce tick : par l'interpolation d'un lion distant, ou par la prédiction.
var _etats_recus: Array[Dictionary] = []
## Sur un client, l'affichage d'un lion distant.
var _interpolation: InterpolationLion
## Chez l'hôte, l'état du lion écrit à chaque tick physique (`EtatLion.encoder`), que le `Synchro`
## recopie chez chaque client ; sur un client, le setter garde chaque état reçu pour le prochain tick
## physique (jamais appliqué pendant le sondage réseau : `avancer` ne se rejoue que dans une image
## physique).
var etat_reseau := PackedByteArray():
	set(valeur):
		etat_reseau = valeur
		if not _replique:
			return
		var etat := EtatLion.decoder(valeur)
		if etat.is_empty():
			push_warning("Lion : état de l'hôte illisible, ignoré")
		elif _etats_recus.size() < ETATS_RECUS_MAX:
			_etats_recus.append(etat)
## Vitesse commandée et recul du lion (logique pure) : ce que `avancer` fait avancer d'un pas.
var deplacement := DeplacementLion.new()
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
func _ready() -> void:
	_rng.randomize()
	if joueur == null:
		joueur = GameState.joueur_local()
```

par :

```gdscript
func _ready() -> void:
	_rng.randomize()
	_replique = not multiplayer.is_server()
	if _replique:
		_interpolation = InterpolationLion.new(Engine.physics_ticks_per_second)
	if joueur == null:
		joueur = GameState.joueur_local()
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
		_suivre_l_hote(delta)
		return
	avancer(_direction_voulue(), delta)
	_animer_deplacement(delta)
	gerbe.signaler_vomi_sur_les_lions()


## Un pas de déplacement du lion vers `direction` (longueur 1 au plus), de `delta` secondes : son
## orientation, sa vitesse (commandée, recul, contacts avec les autres lions), `move_and_slide`, puis
## les bords de l'écran. Le seul chemin du déplacement sur l'hôte (tick physique) ; la prédiction du
## lion local (phase 16) rejouera les mêmes pas, ses commandes en main.
## À appeler seulement dans une image physique, avec `delta` égal au tick physique : `move_and_slide()`
## intègre avec le delta du moteur, pas celui reçu en argument, donc un appel hors `_physics_process`
## (ex. depuis le `poll` multijoueur) fausse la distance parcourue. Un rejeu de prédiction (phase 16)
## se fait donc dans `_physics_process` ; `pare_chocs.bloquer()` ne rejoue pas des contacts passés,
## il ne lit que l'état physique et les positions actuelles au moment de l'appel.
func avancer(direction: Vector2, delta: float) -> void:
	if direction.x != 0:
		direction_du_lion = 1 if direction.x > 0 else -1  # le setter réoriente le lion
```

par :

```gdscript
		_suivre_l_hote(delta)
		return
	commandes.appliquer_suivante()
	avancer(_direction_voulue(), delta)
	_animer_deplacement(delta)
	gerbe.signaler_vomi_sur_les_lions()
	etat_reseau = EtatLion.encoder(Engine.get_physics_frames(), commandes.numero_applique, position,
		deplacement.vitesse, deplacement.recul, direction_du_lion)


## Un pas de déplacement du lion vers `direction` (longueur 1 au plus), de `delta` secondes : son
## orientation, sa vitesse (commandée, recul, contacts avec les autres lions), `move_and_slide`, puis
## les bords de l'écran. Le seul chemin du déplacement : sur l'hôte (tick physique) et dans la
## prédiction du lion local d'un client (`PredictionLocale`, qui rejoue aussi les pas pas encore
## appliqués par l'hôte).
## Seulement dans une image physique, avec `delta` égal au tick physique : `move_and_slide()` intègre
## avec le delta du moteur, pas celui reçu en argument, donc un appel hors d'une image physique (ex.
## depuis le `poll` multijoueur, où arrivent les états de l'hôte) fausserait la distance parcourue ;
## refusé (faux, le lion ne bouge pas). `pare_chocs.bloquer()` ne rejoue pas des contacts passés, il ne
## lit que l'état physique et les positions actuelles au moment de l'appel.
func avancer(direction: Vector2, delta: float) -> bool:
	if not Engine.is_in_physics_frame():
		push_error("Lion.avancer hors d'une image physique : ce pas est ignoré")
		return false
	if direction.x != 0:
		direction_du_lion = 1 if direction.x > 0 else -1  # le setter réoriente le lion
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
	global_position.x = x_borne
	global_position.y = y_borne


```

par :

```gdscript
	global_position.x = x_borne
	global_position.y = y_borne
	return true


```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript


## Sur un client : le lion suit l'hôte. Sa position et sa vitesse sont celles que recopie son
## `Synchro` ; il ne se déplace pas de lui-même, ne se bloque pas contre les autres lions et ne
## signale rien aux règles (la prédiction du lion local viendra en phase 16). Seule l'animation
## (inclinaison, trot) tourne ici, sur la vitesse de l'hôte.
func _suivre_l_hote(delta: float) -> void:
	deplacement.vitesse = velocity
	_animer_deplacement(delta)


## Un lion étourdi ignore ses commandes : il ne se dirige plus et ne vomit plus.
func _direction_voulue() -> Vector2:
	return commandes.direction() if GameState.pret and not joueur.est_etourdi() else Vector2.ZERO


```

par :

```gdscript


## Sur un client, un lion distant suit l'hôte : position, vitesse (totale) et orientation viennent de
## ses états, interpolés avec un peu de retard (`InterpolationLion`) ; tant qu'aucun n'est arrivé, il
## garde les siennes. Il ne se déplace pas de lui-même, ne se bloque pas contre les autres lions et ne
## signale rien aux règles. L'animation (inclinaison, trot) tourne sur la vitesse affichée.
func _suivre_l_hote(delta: float) -> void:
	for etat in _etats_recus:
		_interpolation.ajouter(etat.instant, etat.position, etat.vitesse + etat.recul, etat.direction)
	_etats_recus.clear()
	_interpolation.avancer(delta * Engine.physics_ticks_per_second)
	var vu := _interpolation.echantillon()
	if not vu.is_empty():
		position = vu.position
		velocity = vu.vitesse
		direction_du_lion = vu.direction
	deplacement.vitesse = velocity
	_animer_deplacement(delta)


## La direction que suit le lion pour la commande `voulue` : aucune avant la fin de l'intro ni pendant
## un étourdissement (commandes ignorées). La même règle chez l'hôte et dans la prédiction d'un client,
## qui rejoue ses commandes avec elle.
func direction_pour(voulue: Vector2) -> Vector2:
	return voulue if GameState.pret and not joueur.est_etourdi() else Vector2.ZERO


func _direction_voulue() -> Vector2:
	return direction_pour(commandes.direction())


```


- [ ] **Step 4 : le pare-chocs**

La logique du choc ne change pas (mêmes calculs, dans le même ordre : la trace le vérifie) ; ce qu'il ajoute à la vitesse commandée et au recul part aussi en signal, que la prédiction notera (Task 4). Sur l'hôte et pour un lion distant, personne ne l'écoute.

Dans `Scripts/PareChocs.gd`, remplacer :

```gdscript
## cet autre lion (un lion étourdi reste poussable). Pendant le contact, `bloquer` retire de la vitesse
## du lion ce qui l'enfoncerait dans l'autre et écarte deux lions qui se chevauchent.
## Seul l'hôte signale un choc aux règles. Sur un client, le contact de deux répliques ne fait que
## secouer leur sprite : leur position et leur vitesse viennent de l'hôte (la prédiction du lion
## local, en phase 16, y reprendra le recul et le blocage).

## Recul de chaque lion au choc = vitesse d'approche relative × facteur_choc.
```

par :

```gdscript
## cet autre lion (un lion étourdi reste poussable). Pendant le contact, `bloquer` retire de la vitesse
## du lion ce qui l'enfoncerait dans l'autre et écarte deux lions qui se chevauchent.
## Seul l'hôte signale un choc aux règles. Sur un client, un lion distant ne fait que secouer son
## sprite au choc (sa position et sa vitesse viennent de l'hôte, interpolées) ; le lion local, prédit
## (phase 16), prend tout de suite son recul et son blocage contre les lions affichés, pour un « boing »
## immédiat : chaque choc simulé part aussi en signal (`choc_simule`), que sa prédiction note pour le
## rejouer tant que l'hôte, qui fait foi, ne l'a pas dans ses états.

## Un choc vient de changer la vitesse commandée et le recul de ce lion (ce qui leur a été ajouté).
signal choc_simule(vitesse: Vector2, recul: Vector2)

## Recul de chaque lion au choc = vitesse d'approche relative × facteur_choc.
```

Dans `Scripts/PareChocs.gd`, remplacer :

```gdscript
	var approche := (_lion.velocity - autre.velocity).dot(-normale)
	var vers_autre := deplacement.vitesse.dot(-normale)
	if vers_autre > 0.0:
		deplacement.vitesse += normale * vers_autre
	if approche < approche_min_choc:
		return
	_nettoyer_derniers_chocs()
	var dernier: float = _derniers_chocs.get(autre.get_instance_id(), -1.0)
	if dernier >= 0.0 and _lion.temps - dernier < delai_entre_chocs:
		return
	_derniers_chocs[autre.get_instance_id()] = _lion.temps
	deplacement.recul += normale * approche * facteur_choc
	_lion.secouer()
	# Un seul signalement par choc : celui des deux lions dont l'identifiant est le plus petit.
	if multiplayer.is_server() and _lion.get_instance_id() < autre.get_instance_id():
		GameState.regles.choc_entre_lions(_lion.joueur, autre.joueur)


```

par :

```gdscript
	var approche := (_lion.velocity - autre.velocity).dot(-normale)
	var vers_autre := deplacement.vitesse.dot(-normale)
	var choc_vitesse := Vector2.ZERO
	if vers_autre > 0.0:
		choc_vitesse = normale * vers_autre
		deplacement.vitesse += choc_vitesse
	var choc_recul := Vector2.ZERO
	if _compte_comme_choc(autre, approche):
		choc_recul = normale * approche * facteur_choc
		deplacement.recul += choc_recul
		_lion.secouer()
		# Un seul signalement par choc : celui des deux lions dont l'identifiant est le plus petit.
		if multiplayer.is_server() and _lion.get_instance_id() < autre.get_instance_id():
			GameState.regles.choc_entre_lions(_lion.joueur, autre.joueur)
	if choc_vitesse != Vector2.ZERO or choc_recul != Vector2.ZERO:
		choc_simule.emit(choc_vitesse, choc_recul)


## Vrai si le contact avec `autre`, à la vitesse d'approche `approche`, compte comme un choc (assez
## rapide, délai anti-rafale passé avec cet autre lion) ; il est alors noté pour ce délai.
func _compte_comme_choc(autre: Lion, approche: float) -> bool:
	if approche < approche_min_choc:
		return false
	_nettoyer_derniers_chocs()
	var dernier: float = _derniers_chocs.get(autre.get_instance_id(), -1.0)
	if dernier >= 0.0 and _lion.temps - dernier < delai_entre_chocs:
		return false
	_derniers_chocs[autre.get_instance_id()] = _lion.temps
	return true


```


- [ ] **Step 5 : la réplication**

Dans `Scenes/Lion.tscn`, remplacer :

```text

[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_synchro"]
properties/0/path = NodePath(".:position")
properties/0/spawn = true
properties/0/replication_mode = 1
properties/1/path = NodePath(".:velocity")
properties/1/spawn = true
properties/1/replication_mode = 1
properties/2/path = NodePath(".:direction_du_lion")
properties/2/spawn = true
properties/2/replication_mode = 2
properties/3/path = NodePath(".:vomi_de_l_hote")
properties/3/spawn = true
properties/3/replication_mode = 2

[node name="Lion" type="CharacterBody2D" groups=["lion"]]
```

par :

```text

[sub_resource type="SceneReplicationConfig" id="SceneReplicationConfig_synchro"]
properties/0/path = NodePath(".:etat_reseau")
properties/0/spawn = false
properties/0/replication_mode = 1
properties/1/path = NodePath(".:vomi_de_l_hote")
properties/1/spawn = true
properties/1/replication_mode = 2

[node name="Lion" type="CharacterBody2D" groups=["lion"]]
```


- [ ] **Step 6 : les tests passent, la trace ne change pas, le réseau non plus**

Run : `godot --headless --import .`, puis les unitaires, le smoke test, la bataille (`--fixed-fps 60`), la trace, puis `bash tests/reseau/lancer.sh`.
Expected : `== 0 échec(s) ==` partout, dont « hors d'une image physique, le pas est refusé : le lion ne bouge pas (ligne ERROR attendue) » précédée de `ERROR: Lion.avancer hors d'une image physique : ce pas est ignoré`, « la réplique suit les états reçus, interpolés avec un peu de retard (x = 734.7) … », « plus aucun état : la réplique continue sur sa vitesse 3 ticks, puis s'arrête (x = 781.7) » ; la trace égale à la référence (bataille, solo **et** réplique) ; le test réseau vert, 10 lignes ✅ (mesuré : 110 s). Dans cet état intermédiaire, le lion local d'un client est interpolé comme les autres (la prédiction arrive en Task 4) et l'hôte écrit encore directement les commandes reçues (file vide : `appliquer_suivante` ne fait rien).

- [ ] **Step 7 : Commit**

```bash
git add Scripts/Lion.gd Scripts/PareChocs.gd Scenes/Lion.tscn tests/smoke_test.gd
git commit -m "Lion : l'hôte écrit l'état de chaque lion à chaque tick (etat_reseau, seul champ continu du Synchro avec le vomi) et applique une commande de sa file par tick ; sur un client, les lions sont interpolés entre les états reçus ; avancer refusé hors d'une image physique ; PareChocs : le choc simulé part en signal ; trace inchangée

<ligne fournie par l'environnement>"
```

---

### Task 4 : la prédiction du lion local (`PredictionLocale`, `Main`, `Manche`) et son banc

**Files:**
- Create: `Scripts/PredictionLocale.gd` (+ `.uid`), `tests/prediction_test.gd` (+ `.uid`)
- Modify: `Scripts/Lion.gd`, `Scripts/Main.gd`, `Scripts/Manche.gd`, `project.godot`, `.github/workflows/ci.yml`
- Test: `tests/smoke_test.gd`, `tests/reseau/joueur.gd`, `tests/prediction_test.gd`

**Interfaces:**
- Consumes : Tasks 1 à 3.
- Produces (Tasks 5 à 7) : `PredictionLocale` (`class_name`, `Node`, enfant `Prediction` du lion local d'un client) : constantes `SEUIL_RECALAGE` (200.0), `DUREE_CORRECTION` (0.04), `DECALAGE_NEGLIGEABLE` (0.5), `HISTORIQUE_MAX` (120), `JOURNAL_MAX` (20000) ; champs `numero`, `numero_accuse`, `etats_recus`, `recalages`, `rejeu_max` (int) ; `func paquet() -> PackedByteArray` ; `func decalage() -> Vector2` ; `func remettre_statistiques() -> void` ; `func erreur_max(depuis := 1, jusqu_a := 1 << 30) -> float` (-1 si aucun état) ; `func erreurs_au_dela(seuil: float, depuis := 0) -> int` ; `func etats_depuis(depuis: int) -> int`. `Lion.prediction: PredictionLocale` (donnée par `Main` avant l'ajout) ; `Lion.dernier_etat_recu() -> Dictionary`. `Manche.recevoir_paquet_de(index: int, octets: Variant, maintenant: int) -> int` (remplace `recevoir_commandes_de`) ; RPC `Manche._recevoir_commandes(octets: Variant)`. Le banc : `godot --headless --fixed-fps 60 --script tests/prediction_test.gd`, lignes `MESURE parcours (…)`.

- [ ] **Step 1 : le banc (parcours) et les tests de la manche**

Créer `tests/prediction_test.gd` :

```gdscript
extends SceneTree
## Banc de la prédiction du lion local (phase 16, spec §4.1 et §10), dans un seul processus :
##   godot --headless --fixed-fps 60 --script tests/prediction_test.gd
## Deux postes côte à côte, chacun dans son propre monde (une `SubViewport` de 2000×1125, dont la
## physique ne voit pas l'autre) : l'hôte (H0, le lion de son joueur ; H1, celui du client, qui applique
## les commandes reçues) et le client (C0, réplique interpolée de H0 ; C1, son lion, prédit, joué au
## clavier comme un joueur). Entre eux, des lignes à retard semées (`Ligne`), au tick près et
## reproductibles : les états de chaque lion de l'hôte (non fiables), les paquets de commandes du
## client (non fiables et ordonnés : un paquet plus ancien que le dernier livré est jeté, comme
## `unreliable_ordered`), les réactions de l'hôte (fiables : retardées, renvoyées après une perte,
## jamais perdues ni mélangées). Latence (aller-retour), gigue (étendue de chaque aller) et pertes :
## celles du simulateur du test réseau (`tests/reseau/relais.gd`).
## Mesure l'erreur de prédiction (la position de l'hôte après chaque commande accusée, comparée à
## celle que le client avait prédite pour elle), les recalages, les à-coups de l'affichage, la
## convergence après l'arrêt des commandes, la régularité d'un lion distant ; vérifie qu'aucune
## commande n'est appliquée deux fois. Chaque scénario écrit sa ligne « MESURE ».
## Compilé avant les autoloads : ne nomme ni `GameState`, ni `Lion`, ni `PredictionLocale`.

const TICK_MS := 1000.0 / 60.0
const PAS := 350.0 / 60.0  # px par tick à pleine vitesse
## Spec §4.1 et §10 : sans pertes, le lion prédit reste à moins de 4 px de l'hôte ; sous 80 ms, 40 ms
## et 5 %, l'écart converge sous 4 px en 150 ms (9 ticks) après l'arrêt des commandes.
const ECART_MAX := 4.0
const TICKS_CONVERGENCE := 9
## Au-delà, un saut de l'affichage d'un tick à l'autre (pleine vitesse, et moitié en plus) est un à-coup.
const A_COUP := PAS * 1.5
## Le programme du joueur du client : `[ticks, direction]`, joué au clavier ; il passe par un bord
## (en haut, sous son pseudo).
const PROGRAMME: Array = [[30, Vector2.ZERO], [90, Vector2.RIGHT], [40, Vector2(1, 1)], [60, Vector2.LEFT],
	[20, Vector2.ZERO], [120, Vector2.UP], [45, Vector2(1, -1)], [90, Vector2(-1, 1)], [60, Vector2.DOWN]]

var _echecs := 0
var GS: Node
var _t := 0.0  # ms, temps du banc
var _tick := 0
var _vue_hote: SubViewport
var _vue_client: SubViewport
var _pair: ENetMultiplayerPeer
var h0: CharacterBody2D
var h1: CharacterBody2D
var c0: CharacterBody2D
var c1: CharacterBody2D
var _joueurs_client: Array[Joueur] = []
var _etats: Array[Ligne] = []
var _commandes: Ligne
var _reactions: Ligne
## Mesures du scénario en cours : sauts de l'affichage de C1, pas de C0 pendant la course de H0.
var _a_coups := 0
var _pas_c0: Array[float] = []
var _affiche_avant := Vector2.INF
var _c0_avant := Vector2.INF


## Une ligne à retard entre les deux postes : chaque message part avec un retard d'une demi-latence,
## plus ou moins une demi-gigue (tirée au hasard, semée : l'ordre d'arrivée peut changer), et se perd
## avec la probabilité `pertes` (%). Fiable : jamais perdu (une perte coûte un aller-retour de plus,
## le renvoi) et jamais doublé par un message plus récent. Ordonnée : un message qui arrive après un
## plus récent est jeté.
class Ligne:
	var rng := RandomNumberGenerator.new()
	var latence := 0.0
	var gigue := 0.0
	var pertes := 0.0
	var fiable := false
	var ordonnee := false
	var envoyes := 0
	var perdus := 0
	var _en_route: Array = []  # [arrivée (ms), numéro d'envoi, message]
	var _dernier_livre := 0
	var _derniere_arrivee := 0.0

	func _init(graine: int, latence_ms: float, gigue_ms: float, pertes_pc: float, est_fiable: bool, est_ordonnee: bool) -> void:
		rng.seed = graine
		latence = latence_ms
		gigue = gigue_ms
		pertes = pertes_pc
		fiable = est_fiable
		ordonnee = est_ordonnee

	func envoyer(message: Variant, maintenant: float) -> void:
		envoyes += 1
		var retard := latence / 2.0 + rng.randf_range(-gigue / 2.0, gigue / 2.0)
		if rng.randf() * 100.0 < pertes:
			perdus += 1
			if not fiable:
				return
			retard += latence  # le renvoi
		var arrivee := maintenant + retard
		if fiable:
			arrivee = maxf(arrivee, _derniere_arrivee)
			_derniere_arrivee = arrivee
		_en_route.append([arrivee, envoyes, message])

	func recevoir(maintenant: float) -> Array:
		var arrives := _en_route.filter(func(m: Array) -> bool: return m[0] <= maintenant)
		_en_route = _en_route.filter(func(m: Array) -> bool: return m[0] > maintenant)
		arrives.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		var livres: Array = []
		for m: Array in arrives:
			if ordonnee and m[1] < _dernier_livre:
				continue
			_dernier_livre = maxi(_dernier_livre, m[1])
			livres.append(m[2])
		return livres


func _init() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _run() -> void:
	print("== banc de la prédiction LeLion ==")
	GS = root.get_node("GameState")
	await _scenario_parcours("lien parfait", 0.0, 0.0, 0.0)
	await _scenario_parcours("80 ms, 40 ms de gigue, 5 % de pertes", 80.0, 40.0, 5.0)
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


# --- Les deux postes ---------------------------------------------------------------------------------


## Les deux postes d'une partie à 2 : H0 et C0 partent de `depart0`, H1 et C1 de `depart1` ; les lignes
## à retard sous `latence` (ms, aller-retour), `gigue` (ms) et `pertes` (%), semées par `graine`.
func _preparer(depart0: Vector2, depart1: Vector2, latence: float, gigue: float, pertes: float, graine: int) -> void:
	GS.configurer_bataille(2)
	for i in range(2):
		GS.joueurs[i].pseudo = "Joueur %d" % (i + 1)
	GS.nouvelle_partie()
	GS.pret = true
	_t = 0.0
	_tick = 0
	_vue_hote = _vue("Hote")
	_vue_client = _vue("Client")
	# Le client : son propre pair (jamais connecté), comme la réplique du smoke test ; ses nœuds ne
	# sont pas l'hôte (`multiplayer.is_server()` faux).
	var api := SceneMultiplayer.new()
	_pair = ENetMultiplayerPeer.new()
	_check(_pair.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client pour le poste client")
	api.multiplayer_peer = _pair
	set_multiplayer(api, _vue_client.get_path())
	_joueurs_client.clear()
	for j: Joueur in GS.joueurs:
		var copie := Joueur.new()
		copie.index = j.index
		copie.pseudo = j.pseudo
		copie.couleur = j.couleur
		copie.reinitialiser(j.vies, j.couleurs_debloquees.duplicate())
		_joueurs_client.append(copie)
	h0 = _lion(_vue_hote, GS.joueurs[0], depart0, false)
	h1 = _lion(_vue_hote, GS.joueurs[1], depart1, false)
	c0 = _lion(_vue_client, _joueurs_client[0], depart0, false)
	c1 = _lion(_vue_client, _joueurs_client[1], depart1, true)
	_check(c1 != null and c1.get_node_or_null("Prediction") != null, "(pré-condition) le lion du client est prédit (PredictionLocale)")
	_etats = [Ligne.new(graine, latence, gigue, pertes, false, false), Ligne.new(graine + 1, latence, gigue, pertes, false, false)]
	_commandes = Ligne.new(graine + 2, latence, gigue, pertes, false, true)
	_reactions = Ligne.new(graine + 3, latence, gigue, pertes, true, false)
	for j: Joueur in GS.joueurs:
		j.etourdi.connect(func(origine: Vector2, barbouillage: Color) -> void:
			_reactions.envoyer(["etourdi", j.index, j.etourdi_restant, j.invulnerable_restant - j.etourdi_restant, origine, barbouillage], _t))
		j.etourdissement_fini.connect(func() -> void: _reactions.envoyer(["fin", j.index, j.invulnerable_restant], _t))
	_a_coups = 0
	_pas_c0.clear()
	_affiche_avant = Vector2.INF
	_c0_avant = Vector2.INF
	_relacher()


func _vue(nom: String) -> SubViewport:
	var vue := SubViewport.new()
	vue.name = "Poste" + nom
	vue.size = Vector2i(2000, 1125)
	vue.disable_3d = true
	root.add_child(vue)
	return vue


func _lion(vue: SubViewport, j: Joueur, depart: Vector2, predit: bool) -> CharacterBody2D:
	var l: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
	l.joueur = j
	l.commandes = Commandes.manuelles()
	l.position = depart
	if predit:
		l.prediction = load("res://Scripts/PredictionLocale.gd").new()
	vue.add_child(l)
	return l


func _liberer() -> void:
	_relacher()
	for j: Joueur in GS.joueurs:
		for s: Signal in [j.etourdi, j.etourdissement_fini]:
			for c: Dictionary in s.get_connections():
				if (c.callable as Callable).get_object() == self:
					s.disconnect(c.callable)
	set_multiplayer(null, _vue_client.get_path())
	_pair.close()
	_vue_hote.free()
	_vue_client.free()
	await physics_frame


## Un tick du banc, au début de l'image physique (avant la prédiction, à -10, et les lions) : chaque
## ligne livre ce qui arrive, puis part ce que chaque poste a produit au tick précédent (les états
## écrits par les lions de l'hôte, le paquet de la prédiction), comme le sondage réseau entre deux
## images physiques. Puis l'image physique suit.
func _pas() -> void:
	await physics_frame
	_tick += 1
	_t = _tick * TICK_MS
	for k in range(2):
		for octets: PackedByteArray in _etats[k].recevoir(_t):
			(c0 if k == 0 else c1).etat_reseau = octets
	for octets: PackedByteArray in _commandes.recevoir(_t):
		for c: Dictionary in Commandes.decoder_paquet(octets):
			h1.commandes.recevoir(c.numero, c.direction, c.vomir)
	for r: Array in _reactions.recevoir(_t):
		var j: Joueur = _joueurs_client[r[1]]
		if r[0] == "etourdi":
			j.etourdir(r[2], r[3], r[4], r[5])
		else:
			j.recevoir_fin_etourdissement(r[2])
	_etats[0].envoyer(h0.etat_reseau, _t)
	_etats[1].envoyer(h1.etat_reseau, _t)
	var paquet: PackedByteArray = c1.prediction.paquet()
	if not paquet.is_empty():
		_commandes.envoyer(paquet, _t)
	# Mesures : sauts de l'affichage du lion prédit, pas du lion distant
	if _affiche_avant.is_finite() and c1.position.distance_to(_affiche_avant) > A_COUP + c1.deplacement.recul.length() / 60.0:
		_a_coups += 1
	_affiche_avant = c1.position
	if _c0_avant.is_finite():
		_pas_c0.append(c0.position.x - _c0_avant.x)
	_c0_avant = c0.position


func _presser(direction: Vector2) -> void:
	_basculer("deplacer_droite", direction.x > 0.0)
	_basculer("deplacer_gauche", direction.x < 0.0)
	_basculer("deplacer_bas", direction.y > 0.0)
	_basculer("deplacer_haut", direction.y < 0.0)


func _relacher() -> void:
	for action in ["deplacer_gauche", "deplacer_droite", "deplacer_haut", "deplacer_bas", "vomir"]:
		Input.action_release(action)


static func _basculer(action: String, appuyee: bool) -> void:
	if appuyee:
		Input.action_press(action)
	else:
		Input.action_release(action)


## Le numéro de la première commande lue après cet appel.
func _prochain_numero() -> int:
	return c1.prediction.numero + 1


## Attend `ticks` ticks au repos, puis vérifie la convergence (spec §10) : les états qui accusent une
## commande lue au moins TICKS_CONVERGENCE ticks après `arret` (la première commande au repos) ont
## une erreur sous ECART_MAX, et le lion affiché est là où l'hôte a posé le sien.
func _verifier_convergence(titre: String, arret: int, ticks: int) -> void:
	for i in range(ticks):
		await _pas()
	var apres: float = c1.prediction.erreur_max(arret + TICKS_CONVERGENCE)
	_check(c1.prediction.etats_depuis(arret + TICKS_CONVERGENCE) > 0 and apres >= 0.0 and apres < ECART_MAX,
		"(%s) 150 ms après l'arrêt des commandes, l'erreur de prédiction reste sous %.0f px (au plus %.2f px)" % [titre, ECART_MAX, apres])
	_check(c1.position.distance_to(h1.position) < ECART_MAX and c1.prediction.decalage() == Vector2.ZERO,
		"(%s) au repos, le lion affiché du client est sur celui de l'hôte (%.2f px), sans décalage résiduel" % [titre, c1.position.distance_to(h1.position)])


## Aucune commande appliquée deux fois par l'hôte : chaque numéro jusqu'à la dernière appliquée l'est
## une fois ou est sauté, et les sautées restent rares (redondance).
func _verifier_commandes(titre: String, sautees_max: int) -> void:
	var c: Commandes = h1.commandes
	_check(c.appliquees + c.sautees == c.numero_applique and c.sautees <= sautees_max and c.numero_applique > 0,
		"(%s) aucune commande appliquée deux fois : %d appliquées, %d sautées, jusqu'à la %d (file au plus %d)"
		% [titre, c.appliquees, c.sautees, c.numero_applique, c.file_max_vue])


# --- Scénarios ---------------------------------------------------------------------------------------


## Le programme du joueur du client, pendant que le lion de l'hôte file à pleine vitesse (le lion
## distant du client doit en montrer une course régulière), puis le repos.
func _scenario_parcours(titre: String, latence: float, gigue: float, pertes: float) -> void:
	print("-- Parcours : %s" % titre)
	_preparer(Vector2(300, 150), Vector2(900, 500), latence, gigue, pertes, 1600)
	var vomi_avant_hote := -1
	for segment: Array in PROGRAMME:
		_presser(segment[1])
		for i in range(segment[0]):
			h0.commandes.direction_voulue = Vector2.RIGHT if _tick >= 60 and _tick < 300 else Vector2.ZERO
			if _tick == 200:
				Input.action_press("vomir")
			await _pas()
			if _tick == 202:
				vomi_avant_hote = 1 if c1.est_en_train_de_vomir and (latence == 0.0 or not h1.est_en_train_de_vomir) else 0
			if _tick == 260:
				Input.action_release("vomir")
	_relacher()
	var arret := _prochain_numero()
	var p: Node = c1.prediction
	var etats: int = p.etats_depuis(1)
	var pas_c0 := _pas_c0.slice(110, 290)
	var pas_min: float = pas_c0.min()
	var pas_max: float = pas_c0.max()
	print("MESURE parcours (%s) : erreur max %.2f px, %d états sur %d au-delà de %.0f px, %d au-delà de 16 px ; recalages %d ; à-coups %d ; rejeu le plus long %d pas ; lion distant : %.2f à %.2f px par tick (%.2f) ; commandes sautées %d, file au plus %d"
		% [titre, p.erreur_max(), p.erreurs_au_dela(ECART_MAX), etats, ECART_MAX, p.erreurs_au_dela(16.0), p.recalages, _a_coups, p.rejeu_max,
			pas_min, pas_max, PAS, h1.commandes.sautees, h1.commandes.file_max_vue])
	if latence == 0.0:
		_check(p.erreur_max() < ECART_MAX and etats > 500,
			"(%s) sans latence ni pertes, le lion prédit reste à moins de %.0f px de l'hôte (au plus %.2f px sur %d états)" % [titre, ECART_MAX, p.erreur_max(), etats])
	else:
		_check(p.erreurs_au_dela(16.0) <= etats / 50 and p.erreur_max() < 30.0,
			"(%s) pendant la course, l'erreur de prédiction reste petite (au plus %.2f px ; %d états sur %d au-delà de 16 px)" % [titre, p.erreur_max(), p.erreurs_au_dela(16.0), etats])
	_check(p.recalages == 0 and _a_coups <= 3, "(%s) ni recalage ni à-coup visible (%d recalages, %d à-coups)" % [titre, p.recalages, _a_coups])
	_check(vomi_avant_hote == 1, "(%s) la gerbe du lion local part dès l'appui, sans attendre l'hôte" % titre)
	_check(pas_min > 0.7 * PAS and pas_max < 1.3 * PAS,
		"(%s) le lion distant (interpolé) court d'un pas régulier, sans recul ni saut (%.2f à %.2f px par tick, pour %.2f)" % [titre, pas_min, pas_max, PAS])
	await _verifier_convergence(titre, arret, 90)
	_verifier_commandes(titre, h1.commandes.numero_applique / 100)
	await _liberer()
```


Dans `tests/smoke_test.gd`, remplacer :

```gdscript
			and lion_bob.position.x < main.lion.position.x + 2000.0 and lion_bob.position.y == main.lion.position.y,
			"le lion de Bob porte son joueur et des commandes manuelles, à sa place de départ")
		# Commandes reçues de Bob, numérotées, puis son silence
		var maintenant := Time.get_ticks_msec()
		_check(manche.recevoir_commandes_de(1, 5, Vector2(0.5, 0.0), true, maintenant) and lion_bob.commandes.direction_voulue == Vector2(0.5, 0.0)
			and lion_bob.commandes.vomir_voulu, "une commande de Bob est écrite dans les commandes de son lion")
		_check(not manche.recevoir_commandes_de(1, 4, Vector2(-1, 0), false, maintenant) and not manche.recevoir_commandes_de(1, 5, Vector2(-1, 0), false, maintenant)
			and lion_bob.commandes.direction_voulue == Vector2(0.5, 0.0),
			"une commande plus ancienne ou déjà vue est ignorée")
		_check(not manche.recevoir_commandes_de(1, 6, "gauche", false, maintenant) and not manche.recevoir_commandes_de(1, 6, Vector2(INF, 0), false, maintenant)
			and not manche.recevoir_commandes_de(0, 6, Vector2(1, 0), false, maintenant) and main.lion.commandes.direction() == Vector2.ZERO,
			"une commande mal formée, non finie ou pour le lion de l'hôte est refusée")
		manche.verifier_silences(maintenant + manche.SILENCE_COMMANDES - 10)
		_check(lion_bob.commandes.vomir_voulu, "pas encore de silence : la dernière commande tient")
```

par :

```gdscript
			and lion_bob.position.x < main.lion.position.x + 2000.0 and lion_bob.position.y == main.lion.position.y,
			"le lion de Bob porte son joueur et des commandes manuelles, à sa place de départ")
		# Commandes reçues de Bob, numérotées et redondantes (phase 16), puis son silence
		var maintenant := Time.get_ticks_msec()
		var paquet_bob := Commandes.encoder_paquet(5, [[Vector2(-1, 0), false], [Vector2(0.5, 0.0), true]])
		_check(manche.recevoir_paquet_de(1, paquet_bob, maintenant) == 2 and lion_bob.commandes.en_attente() <= 2,
			"un paquet de Bob (ses commandes 4 et 5) entre dans la file des commandes de son lion")
		_check(manche.recevoir_paquet_de(1, paquet_bob, maintenant) == 0, "le même paquet reçu deux fois n'ajoute rien")
		_check(manche.recevoir_paquet_de(1, "gauche", maintenant) == -1
			and manche.recevoir_paquet_de(1, Commandes.encoder_paquet(6, [[Vector2(INF, 0), false]]), maintenant) == -1
			and manche.recevoir_paquet_de(0, Commandes.encoder_paquet(6, [[Vector2(1, 0), false]]), maintenant) == -1
			and main.lion.commandes.direction() == Vector2.ZERO,
			"un paquet mal formé, non fini ou pour le lion de l'hôte est refusé")
		await _frames(3)
		_check(lion_bob.commandes.numero_applique == 5 and lion_bob.commandes.appliquees == 2 and lion_bob.commandes.direction_voulue == Vector2(0.5, 0.0)
			and lion_bob.commandes.vomir_voulu and EtatLion.decoder(lion_bob.etat_reseau).commande == 5,
			"le lion de Bob applique une commande par tick, dans l'ordre (la 4, puis la 5), et son état accuse la 5")
		manche.verifier_silences(maintenant + manche.SILENCE_COMMANDES - 10)
		_check(lion_bob.commandes.vomir_voulu, "pas encore de silence : la dernière commande tient")
```


Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size() - 1), "un lion par joueur resté (%d)" % main.lions.size())
	var moi: Joueur = gs.joueur_local()
	_check(main.lion != null and main.lion.joueur == moi and main.lion.commandes.source == Commandes.Source.LOCALES
		and main.lions.all(func(l: Node) -> bool: return l == main.lion or l.commandes.source == Commandes.Source.MANUELLES),
		"le lion de ce poste lit ses commandes, les autres ont des commandes manuelles")
	if not hote:
		_check(root.multiplayer.get_peers() == PackedInt32Array([1]) and not root.multiplayer.is_server(),
```

par :

```gdscript
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size() - 1), "un lion par joueur resté (%d)" % main.lions.size())
	var moi: Joueur = gs.joueur_local()
	var lion_local_ok: bool = main.lion != null and main.lion.joueur == moi and (
		main.lion.commandes.source == Commandes.Source.LOCALES and main.lion.prediction == null if hote
		else main.lion.commandes.source == Commandes.Source.MANUELLES and main.lion.prediction != null)
	_check(lion_local_ok and main.lions.all(func(l: Node) -> bool:
			return l == main.lion or (l.commandes.source == Commandes.Source.MANUELLES and l.prediction == null)),
		"le lion de ce poste lit ses commandes (hôte) ou les prédit (client, phase 16) ; les autres ont des commandes manuelles")
	if not hote:
		_check(root.multiplayer.get_peers() == PackedInt32Array([1]) and not root.multiplayer.is_server(),
```


- [ ] **Step 2 : ils échouent**

Run : `godot --headless --import .`, puis le banc (`T=tests/prediction_test.gd; O="--fixed-fps 60"`) et le smoke test.
Expected (mesuré) : le banc, `SCRIPT ERROR: Attempt to call function 'new' in base 'null instance' on a null instance.` (le script de la prédiction n'existe pas), `❌ (pré-condition) le lion du client est prédit (PredictionLocale)` à chaque parcours, des centaines de `SCRIPT ERROR` sur `prediction` et `etat_reseau`, et `== 2 échec(s) ==` ; le smoke test, `SCRIPT ERROR: Invalid call. Nonexistent function 'recevoir_paquet_de' in base 'Node (Manche.gd)'.` Le bilan du smoke test peut dire `== 0 échec(s) ==` : une erreur de script abandonne la fonction de test en cours sans compter d'échec ; c'est la `SCRIPT ERROR` qui fait l'échec (la CI la cherche).

- [ ] **Step 3 : la prédiction**

Créer `Scripts/PredictionLocale.gd` :

```gdscript
class_name PredictionLocale
extends Node
## La prédiction du lion local sur un client (phase 16, spec §4.1) : ce lion avance dès la frame
## courante avec les commandes de ce poste, par le même pas que l'hôte (`Lion.avancer`), sans attendre
## l'aller-retour du réseau. Enfant du lion du joueur local, sur un client seulement (ni chez l'hôte, ni
## en solo, ni en bataille locale) ; ajouté par le lion quand `Main` le lui donne.
## À chaque tick physique, avant les lions (priorité -10) et avant la manche qui envoie (priorité 100) :
## 1. les actions de ce poste sont lues une seule fois (direction et vomir au même tick), numérotées,
##    écrites dans les commandes manuelles du lion et gardées dans l'historique (`paquet()` en donne
##    la dernière et jusqu'à 3 précédentes, que la manche envoie à l'hôte) ;
## 2. si un état neuf de l'hôte est arrivé (`Lion.etat_reseau`, reçu pendant le sondage réseau, donc
##    rejoué ici, dans une image physique), le lion repart de cet état (position, vitesse commandée,
##    recul, orientation) et rejoue les commandes que l'hôte n'a pas encore appliquées (numéros au-delà
##    de celui de l'état), avec les chocs qu'il avait simulés à ces ticks ; l'écart entre l'ancienne
##    prédiction et la nouvelle passe dans un décalage d'affichage ;
## 3. le lion fait son pas de ce tick ; le décalage s'amortit (DUREE_CORRECTION : 95 % en 120 ms),
##    sauf au-delà de SEUIL_RECALAGE (téléportation, désynchronisation grave) : recalage immédiat.
## Le lion ne suit que les commandes qu'accepte l'hôte : rien avant la fin de l'intro, rien pendant un
## étourdissement (le rejeu applique la même règle, `Lion.direction_pour` : pendant un étourdissement,
## le lion suit l'hôte). Ses chocs contre les autres lions (affichés, interpolés) sont simulés tout de
## suite par son pare-chocs (`PareChocs.choc_simule`), notés au tick où ils arrivent et rejoués avec
## lui ; l'hôte fait foi, le recalage absorbe l'écart. Les réactions décidées par l'hôte
## (étourdissement, recul d'un coup) arrivent dans ses états : jamais notées ni rejouées ici.
## Nœud : il nomme `Lion` ; les tests `--script` ne le nomment pas.

## Au-delà de cet écart (px) entre l'ancienne prédiction et la nouvelle, le lion est recalé d'un coup.
const SEUIL_RECALAGE := 200.0
## Constante de temps (s) du décalage d'affichage : e^(-0,12 / 0,04) = 5 % restent après 120 ms.
const DUREE_CORRECTION := 0.04
## Décalage résiduel (px) remis à zéro : invisible.
const DECALAGE_NEGLIGEABLE := 0.5
## Commandes gardées au plus pour le rejeu (2 s) : un hôte figé n'en accuse plus aucune.
const HISTORIQUE_MAX := 120
## Erreurs de prédiction gardées pour les statistiques (tests).
const JOURNAL_MAX := 20000

## Numéro de la dernière commande lue (0 : aucune encore).
var numero := 0
## Numéro de la dernière commande appliquée par l'hôte, selon son dernier état reçu.
var numero_accuse := 0
## Statistiques lues par les tests : états neufs reçus, recalages immédiats, plus long rejeu (pas).
var etats_recus := 0
var recalages := 0
var rejeu_max := 0

var _lion: Lion
## Les actions de ce poste, lues une fois par tick.
var _locales := Commandes.locales()
## Commandes pas encore appliquées par l'hôte, de la plus ancienne à la dernière :
## `{numero, direction, vomir, choc_vitesse, choc_recul, predite}` (predite : la position prédite après
## son pas, au tick où elle a été lue, sans le décalage d'affichage : ce que le joueur a vu).
var _historique: Array[Dictionary] = []
## Chocs simulés depuis le dernier tick (notés avec la commande de ce tick).
var _choc_vitesse := Vector2.ZERO
var _choc_recul := Vector2.ZERO
## Écart d'affichage (px) entre la position montrée et la position prédite.
var _decalage := Vector2.ZERO
## Instant (tick de l'hôte) du dernier état utilisé.
var _instant_utilise := -1
## `Vector2(numéro accusé, erreur)` de chaque état neuf : l'erreur de prédiction est l'écart entre la
## position de l'hôte après la commande accusée et celle que ce poste avait prédite pour elle au tick
## où il l'a lue (ce que le joueur a vu, pas une prédiction refaite depuis par un rejeu).
var _journal: PackedVector2Array = []


func _ready() -> void:
	process_physics_priority = -10
	_lion = get_parent() as Lion
	_lion.pare_chocs.choc_simule.connect(_sur_choc_simule)
	# Sur un client, le déplacement du lion n'avait jamais servi : il part d'un état neutre, jamais
	# d'une vitesse reçue de l'hôte (vitesse totale, recul déjà joué).
	_lion.deplacement.vitesse = Vector2.ZERO
	_lion.deplacement.recul = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_lion.position -= _decalage
	var suspendues := _lion.commandes.suspendues
	var direction_lue := Vector2.ZERO if suspendues else _locales.direction()
	var vomir_lu := false if suspendues else _locales.vomir()
	numero += 1
	var commande: Dictionary = {"numero": numero, "direction": direction_lue, "vomir": vomir_lu,
		"choc_vitesse": _choc_vitesse, "choc_recul": _choc_recul, "predite": Vector2.ZERO}
	_choc_vitesse = Vector2.ZERO
	_choc_recul = Vector2.ZERO
	_historique.append(commande)
	if _historique.size() > HISTORIQUE_MAX:
		_historique.pop_front()
	_lion.commandes.direction_voulue = direction_lue
	_lion.commandes.vomir_voulu = vomir_lu
	var etat := _lion.dernier_etat_recu()
	if not etat.is_empty() and etat.instant > _instant_utilise:
		_recaler(etat, delta)
	_lion.avancer(_lion.direction_pour(direction_lue), delta)
	commande.predite = _lion.position
	_decalage *= exp(-delta / DUREE_CORRECTION)
	if _decalage.length() < DECALAGE_NEGLIGEABLE:
		_decalage = Vector2.ZERO
	_lion.position += _decalage


## Le paquet de commandes à envoyer à l'hôte : la dernière lue et jusqu'à REDONDANCE précédentes
## (`Commandes.encoder_paquet`) ; vide avant la première.
func paquet() -> PackedByteArray:
	if _historique.is_empty():
		return PackedByteArray()
	var envoi := _historique.slice(maxi(0, _historique.size() - Commandes.REDONDANCE - 1))
	return Commandes.encoder_paquet(envoi[-1].numero, envoi.map(func(c: Dictionary) -> Array: return [c.direction, c.vomir]))


## Écart (px) entre la position affichée et la position prédite.
func decalage() -> Vector2:
	return _decalage


## Remet les statistiques à zéro (tests, contrôle à la main).
func remettre_statistiques() -> void:
	etats_recus = 0
	recalages = 0
	rejeu_max = 0
	_journal.clear()


## La plus grande erreur de prédiction des états qui accusent une commande de `depuis` à `jusqu_a`
## (tests) ; -1 si aucun.
func erreur_max(depuis := 1, jusqu_a := 1 << 30) -> float:
	var pire := -1.0
	for e in _journal:
		if int(e.x) >= depuis and int(e.x) <= jusqu_a:
			pire = maxf(pire, e.y)
	return pire


## Nombre d'états neufs qui accusent au moins la commande `depuis` et dont l'erreur dépasse `seuil`
## (tests).
func erreurs_au_dela(seuil: float, depuis := 0) -> int:
	var n := 0
	for e in _journal:
		if int(e.x) >= depuis and e.y > seuil:
			n += 1
	return n


## Nombre d'états neufs qui accusent au moins la commande `depuis` (tests).
func etats_depuis(depuis: int) -> int:
	var n := 0
	for e in _journal:
		if int(e.x) >= depuis:
			n += 1
	return n


## Le lion repart de l'état `etat` de l'hôte et rejoue les commandes que l'hôte n'a pas encore
## appliquées, sauf celle de ce tick (son pas suit).
func _recaler(etat: Dictionary, delta: float) -> void:
	_instant_utilise = etat.instant
	etats_recus += 1
	var accuse: int = etat.commande
	numero_accuse = accuse
	var avant: Vector2 = _lion.position
	while not _historique.is_empty() and _historique[0].numero <= accuse:
		var appliquee: Dictionary = _historique.pop_front()
		if appliquee.numero == accuse and _journal.size() < JOURNAL_MAX:
			_journal.append(Vector2(accuse, (etat.position as Vector2).distance_to(appliquee.predite)))
	_lion.position = etat.position
	_lion.deplacement.vitesse = etat.vitesse
	_lion.deplacement.recul = etat.recul
	_lion.direction_du_lion = etat.direction
	for i in range(_historique.size()):
		var c: Dictionary = _historique[i]
		_lion.deplacement.vitesse += c.choc_vitesse
		_lion.deplacement.recul += c.choc_recul
		if i == _historique.size() - 1:
			break  # la commande de ce tick : son pas suit, dans `_physics_process`
		_lion.avancer(_lion.direction_pour(c.direction), delta)
	rejeu_max = maxi(rejeu_max, _historique.size() - 1)
	var ecart := avant - _lion.position
	if ecart.length() > SEUIL_RECALAGE:
		recalages += 1
		_decalage = Vector2.ZERO
	else:
		_decalage += ecart


## Un choc simulé par le pare-chocs du lion (entre deux ticks) : noté avec la commande du prochain tick,
## pour le rejouer tant que l'hôte ne l'a pas.
func _sur_choc_simule(vitesse: Vector2, recul: Vector2) -> void:
	_choc_vitesse += vitesse
	_choc_recul += recul
```


- [ ] **Step 4 : le lion prédit**

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
## sur un client, le lion local a des commandes manuelles, que remplit sa prédiction.
var commandes: Commandes
## Vrai sur un client (fixé dans `_ready`) : les états reçus de l'hôte y sont gardés pour le prochain
## tick physique.
```

par :

```gdscript
## sur un client, le lion local a des commandes manuelles, que remplit sa prédiction.
var commandes: Commandes
## Sur un client, la prédiction du lion du joueur local (phase 16) : donnée par `Main` avant l'ajout à
## l'arbre, ajoutée par `_ready` comme enfant du lion. Nulle ailleurs (hôte, solo, bataille locale, lions
## distants).
var prediction: PredictionLocale
## Vrai sur un client (fixé dans `_ready`) : les états reçus de l'hôte y sont gardés pour le prochain
## tick physique.
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
	_rng.randomize()
	_replique = not multiplayer.is_server()
	if _replique:
		_interpolation = InterpolationLion.new(Engine.physics_ticks_per_second)
	if joueur == null:
```

par :

```gdscript
	_rng.randomize()
	_replique = not multiplayer.is_server()
	if _replique and prediction == null:
		_interpolation = InterpolationLion.new(Engine.physics_ticks_per_second)
	if joueur == null:
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript
	gerbe.reconstruire()
	appliquer_apparence()


func _physics_process(delta: float) -> void:
	temps += delta
	if not multiplayer.is_server():
		_suivre_l_hote(delta)
		return
	commandes.appliquer_suivante()
```

par :

```gdscript
	gerbe.reconstruire()
	appliquer_apparence()
	if prediction != null:
		prediction.name = "Prediction"
		add_child(prediction)


func _physics_process(delta: float) -> void:
	temps += delta
	if not multiplayer.is_server():
		if prediction == null:
			_suivre_l_hote(delta)
		else:
			_animer_deplacement(delta)  # le pas de ce tick est déjà fait, par la prédiction (priorité -10)
		return
	commandes.appliquer_suivante()
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript


## La direction que suit le lion pour la commande `voulue` : aucune avant la fin de l'intro ni pendant
## un étourdissement (commandes ignorées). La même règle chez l'hôte et dans la prédiction d'un client,
```

par :

```gdscript


## Sur un client, pour la prédiction : le plus récent des états reçus de l'hôte depuis le dernier appel
## (vide s'il n'en est arrivé aucun).
func dernier_etat_recu() -> Dictionary:
	var dernier := {}
	for etat in _etats_recus:
		if dernier.is_empty() or etat.instant > dernier.instant:
			dernier = etat
	_etats_recus.clear()
	return dernier


## La direction que suit le lion pour la commande `voulue` : aucune avant la fin de l'intro ni pendant
## un étourdissement (commandes ignorées). La même règle chez l'hôte et dans la prédiction d'un client,
```

Dans `Scripts/Lion.gd`, remplacer :

```gdscript


## Sur un client, la réplique vomit quand le lion de l'hôte vomit.
func _veut_vomir() -> bool:
	if not multiplayer.is_server():
		return vomi_de_l_hote
	return GameState.pret and not joueur.est_etourdi() and commandes.vomir()
```

par :

```gdscript


## Un lion étourdi ne vomit plus. Sur un client, un lion distant vomit quand le lion de l'hôte vomit ;
## le lion local, prédit, dès l'appui (particules seulement : la peinture reste décidée par l'hôte).
func _veut_vomir() -> bool:
	if not multiplayer.is_server() and prediction == null:
		return vomi_de_l_hote
	return GameState.pret and not joueur.est_etourdi() and commandes.vomir()
```


- [ ] **Step 5 : la scène de jeu donne la prédiction au lion local d'un client**

Dans `Scripts/Main.gd`, remplacer :

```gdscript

## La `spawn_function` d'`apparitions`, sur chaque poste : le lion du joueur d'index `index`, avec
## son joueur et ses commandes avant l'ajout à l'arbre (celles de ce poste pour le joueur local,
## manuelles pour les autres), à sa place de départ.
func _creer_lion(index: Variant) -> Node:
	if not (index is int) or index < 0 or index >= GameState.joueurs.size():
```

par :

```gdscript

## La `spawn_function` d'`apparitions`, sur chaque poste : le lion du joueur d'index `index`, avec
## son joueur et ses commandes avant l'ajout à l'arbre, à sa place de départ. Chez l'hôte, le lion du
## joueur local lit les actions de ce poste, les autres des commandes manuelles (celles que chaque
## client envoie) ; sur un client, le lion du joueur local est prédit (phase 16) : sa prédiction lit
## les actions de ce poste une fois par tick et les écrit dans ses commandes manuelles.
func _creer_lion(index: Variant) -> Node:
	if not (index is int) or index < 0 or index >= GameState.joueurs.size():
```

Dans `Scripts/Main.gd`, remplacer :

```gdscript
	nouveau.name = "Lion%d" % (index + 1)
	nouveau.joueur = joueur
	nouveau.commandes = Commandes.locales() if joueur == GameState.joueur_local() else Commandes.manuelles()
	nouveau.position = _position_de_depart(index, GameState.joueurs.size())
	return nouveau
```

par :

```gdscript
	nouveau.name = "Lion%d" % (index + 1)
	nouveau.joueur = joueur
	var local := joueur == GameState.joueur_local()
	nouveau.commandes = Commandes.locales() if local and multiplayer.is_server() else Commandes.manuelles()
	if local and not multiplayer.is_server():
		nouveau.prediction = PredictionLocale.new()
	nouveau.position = _position_de_depart(index, GameState.joueurs.size())
	return nouveau
```


- [ ] **Step 6 : la manche envoie le paquet de la prédiction, l'hôte le met en file**

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
##   départ est un départ comme un autre) ; alors seulement (`barriere_passee`, chez l'hôte puis
##   chez chaque client) les lions apparaissent, le Spawner démarre et l'intro se lance chez tous.
## - Commandes : chaque client envoie à chaque tick physique la direction et l'envie de vomir de son
##   lion (RPC `unreliable_ordered`, numérotées : l'hôte ignore un numéro déjà vu, en attendant la
##   redondance de la phase 16) ; l'hôte les écrit dans les commandes manuelles de ce lion, et les
##   remet au repos après SILENCE_COMMANDES de temps de jeu sans nouvelle commande (pas l'horloge
##   murale, M4 de la revue finale : un rattrapage de ticks physiques après un gel de l'hôte ne doit
##   pas se lire comme un silence).
## - Tampons : chaque tampon de la ville de l'hôte (`Ville.tampon_peint`) est diffusé, regroupé par
##   tick physique, sur le canal fiable 1 (`Peinture.encoder_tampons`) ; un client le dessine
```

par :

```gdscript
##   départ est un départ comme un autre) ; alors seulement (`barriere_passee`, chez l'hôte puis
##   chez chaque client) les lions apparaissent, le Spawner démarre et l'intro se lance chez tous.
## - Commandes (phase 16) : chaque client envoie à chaque tick physique la commande que la prédiction
##   de son lion vient de lire, numérotée, avec les 3 précédentes (`PredictionLocale.paquet`, RPC
##   `unreliable_ordered`) ; l'hôte met chaque numéro neuf dans la file des commandes manuelles de ce
##   lion (`Commandes.recevoir`), qui en applique une par tick, dans l'ordre, jamais deux fois, et
##   renvoie le numéro de la dernière appliquée dans l'état du lion (`Lion.etat_reseau`) ; il remet le
##   lion au repos après SILENCE_COMMANDES de temps de jeu sans paquet (pas l'horloge murale, M4 de la
##   revue finale : un rattrapage de ticks physiques après un gel de l'hôte ne doit pas se lire comme
##   un silence).
## - Tampons : chaque tampon de la ville de l'hôte (`Ville.tampon_peint`) est diffusé, regroupé par
##   tick physique, sur le canal fiable 1 (`Peinture.encoder_tampons`) ; un client le dessine
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
## Sans commande d'un client depuis ce délai (ms de temps de jeu, pas l'horloge murale : M4 de la
## revue finale), l'hôte remet son lion au repos (point de vigilance des phases 14 et 16 : un client
## planté ne laisse pas son lion filer ou vomir).
const SILENCE_COMMANDES := 500
## Période de diffusion du territoire (cellules changées et scores), en secondes (spec §6).
```

par :

```gdscript
## Sans commande d'un client depuis ce délai (ms de temps de jeu, pas l'horloge murale : M4 de la
## revue finale), l'hôte remet son lion au repos (point de vigilance des phases 14 et 16 : un client
## planté ne laisse pas son lion filer ou vomir). Bien au-dessus de la latence du Wi-Fi simulée par
## les tests (40 ms ± 20 ms par sens) et de trois paquets perdus de suite, que la redondance couvre.
const SILENCE_COMMANDES := 500
## Période de diffusion du territoire (cellules changées et scores), en secondes (spec §6).
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
## commandes de son lion (celles de ce poste), à l'index de son joueur.
var _commandes: Dictionary[int, Commandes] = {}
## Hôte : par index de joueur, la dernière commande reçue `{"numero": int, "a": int (ms)}`.
var _recues: Dictionary[int, Dictionary] = {}
## Hôte : les clients dont la scène est chargée, destinataires de tout ce que diffuse la manche.
var _prets: Array[int] = []
```

par :

```gdscript
## commandes de son lion (celles de ce poste), à l'index de son joueur.
var _commandes: Dictionary[int, Commandes] = {}
## Hôte : par index de joueur, l'instant (ms de temps de jeu) du dernier paquet de commandes reçu.
var _recues: Dictionary[int, int] = {}
## Hôte : les clients dont la scène est chargée, destinataires de tout ce que diffuse la manche.
var _prets: Array[int] = []
```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript
## des commandes et remettrait chaque lion distant au repos pour rien.
var _temps_manche := 0.0
## Client : numéro de la dernière commande envoyée.
var _numero := 0


func _ready() -> void:
	# Après les lions et leurs traceuses (priorité 0) : les tampons d'un tick partent dans ce tick.
	process_physics_priority = 100

```

par :

```gdscript
## des commandes et remettrait chaque lion distant au repos pour rien.
var _temps_manche := 0.0
## Client : la prédiction du lion de ce poste, qui lit ses commandes et les numérote.
var _prediction: PredictionLocale


func _ready() -> void:
	# Après les lions et leurs traceuses (priorité 0) : les tampons d'un tick partent dans ce tick ; et
	# après la prédiction du lion local d'un client (priorité -10) : la commande de ce tick part dans ce
	# tick.
	process_physics_priority = 100

```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript

## Le lion `lion` vient d'apparaître sur ce poste (appelé par `Main`) : chez l'hôte, les commandes
## manuelles du lion d'un client y seront écrites ; chez un client, les commandes de son propre lion
## partiront vers l'hôte.
func suivre_lion(lion: Lion) -> void:
	var local := lion.joueur == GameState.joueur_local()
	if (_hote and not local) or (not _hote and local):
		_commandes[lion.joueur.index] = lion.commandes


```

par :

```gdscript

## Le lion `lion` vient d'apparaître sur ce poste (appelé par `Main`) : chez l'hôte, les commandes
## manuelles du lion d'un client y seront écrites ; chez un client, les commandes de son propre lion,
## lues et numérotées par sa prédiction, partiront vers l'hôte.
func suivre_lion(lion: Lion) -> void:
	var local := lion.joueur == GameState.joueur_local()
	if (_hote and not local) or (not _hote and local):
		_commandes[lion.joueur.index] = lion.commandes
	if not _hote and local:
		_prediction = lion.prediction


```

Dans `Scripts/Manche.gd`, remplacer :

```gdscript


## Chez un client : les commandes de son lion, une fois par tick physique.
func _envoyer_commandes() -> void:
	if not barriere or _commandes.is_empty():
		return
	var c: Commandes = _commandes.values()[0]
	_numero += 1
	_recevoir_commandes.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, _numero, c.direction(), c.vomir())


## Chez l'hôte : les commandes d'un client, pour son lion.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _recevoir_commandes(numero: Variant, direction: Variant, vomir: Variant) -> void:
	if not _hote:
		return
	var id := multiplayer.get_remote_sender_id()
	for j in GameState.joueurs:
		if j.id_reseau == id:
			recevoir_commandes_de(j.index, numero, direction, vomir, int(_temps_manche * 1000.0))
			return


## Chez l'hôte : écrit la commande `numero` du joueur d'index `index` dans les commandes de son lion,
## reçue à `maintenant` (ms de temps de jeu). Refusée (faux) pour un lion inconnu, des arguments
## d'un autre type ou non finis, ou un numéro déjà vu.
func recevoir_commandes_de(index: int, numero: Variant, direction: Variant, vomir: Variant, maintenant: int) -> bool:
	var c: Commandes = _commandes.get(index)
	if c == null or not (numero is int) or not (direction is Vector2) or not (vomir is bool) or not direction.is_finite():
		return false
	if numero <= _recues.get(index, {"numero": 0}).numero:
		return false
	c.direction_voulue = direction  # bornée à une longueur de 1 par `Commandes.direction()`
	c.vomir_voulu = vomir
	_recues[index] = {"numero": numero, "a": maintenant}
	return true


## Chez l'hôte : le lion d'un client dont aucune commande n'est arrivée depuis SILENCE_COMMANDES ms
## de temps de jeu (à `maintenant`) revient au repos.
func verifier_silences(maintenant: int) -> void:
	for index: int in _recues:
		if maintenant - int(_recues[index].a) > SILENCE_COMMANDES and _commandes.has(index):
			_commandes[index].direction_voulue = Vector2.ZERO
			_commandes[index].vomir_voulu = false


```

par :

```gdscript


## Chez un client : la commande de ce tick, lue par la prédiction du lion de ce poste, avec les 3
## précédentes, une fois par tick physique.
func _envoyer_commandes() -> void:
	if not barriere or _prediction == null or not is_instance_valid(_prediction):
		return
	var octets := _prediction.paquet()
	if not octets.is_empty():
		_recevoir_commandes.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, octets)


## Chez l'hôte : un paquet de commandes d'un client, pour son lion.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _recevoir_commandes(octets: Variant) -> void:
	if not _hote:
		return
	var id := multiplayer.get_remote_sender_id()
	for j in GameState.joueurs:
		if j.id_reseau == id:
			recevoir_paquet_de(j.index, octets, int(_temps_manche * 1000.0))
			return


## Chez l'hôte : le paquet de commandes `octets` du joueur d'index `index` (la dernière et jusqu'à 3
## précédentes, `Commandes.encoder_paquet`), reçu à `maintenant` (ms de temps de jeu) : chaque
## commande neuve entre dans la file des commandes de son lion, qui en applique une par tick. Renvoie
## le nombre de commandes neuves, ou -1 pour un lion inconnu ou un paquet mal formé.
func recevoir_paquet_de(index: int, octets: Variant, maintenant: int) -> int:
	var c: Commandes = _commandes.get(index)
	var paquet := Commandes.decoder_paquet(octets)
	if c == null or paquet.is_empty():
		return -1
	var neuves := 0
	for commande in paquet:
		if c.recevoir(commande.numero, commande.direction, commande.vomir):
			neuves += 1
	_recues[index] = maintenant
	return neuves


## Chez l'hôte : le lion d'un client dont aucun paquet de commandes n'est arrivé depuis
## SILENCE_COMMANDES ms de temps de jeu (à `maintenant`) revient au repos, sa file vidée.
func verifier_silences(maintenant: int) -> void:
	for index: int in _recues:
		if maintenant - _recues[index] > SILENCE_COMMANDES and _commandes.has(index):
			_commandes[index].remettre_au_repos()


```


- [ ] **Step 7 : la version et la CI**

Dans `project.godot`, remplacer :

```ini

config/name="LeLion"
config/version="0.14"
run/main_scene="res://Scenes/Titre.tscn"
config/features=PackedStringArray("4.7", "Mobile")
```

par :

```ini

config/name="LeLion"
config/version="0.16"
run/main_scene="res://Scenes/Titre.tscn"
config/features=PackedStringArray("4.7", "Mobile")
```


Dans `.github/workflows/ci.yml`, remplacer :

```yaml
          if grep -nE "SCRIPT ERROR|SHADER ERROR" bataille_test.log; then echo "::error::erreur de script dans le test de bataille"; exit 1; fi

      - name: Test réseau (transport, plusieurs processus sur localhost)
        shell: bash
```

par :

```yaml
          if grep -nE "SCRIPT ERROR|SHADER ERROR" bataille_test.log; then echo "::error::erreur de script dans le test de bataille"; exit 1; fi

      - name: Banc de la prédiction (latence simulée, un seul processus)
        shell: bash
        run: |
          set -o pipefail
          timeout 300 godot --headless --fixed-fps 60 --script tests/prediction_test.gd 2>&1 | tee prediction_test.log
          if grep -nE "SCRIPT ERROR|SHADER ERROR" prediction_test.log; then echo "::error::erreur de script dans le banc de la prédiction"; exit 1; fi

      - name: Test réseau (transport, plusieurs processus sur localhost)
        shell: bash
```


- [ ] **Step 8 : les tests passent, la trace ne change pas, le réseau non plus**

Run : `godot --headless --import .`, puis les unitaires, le smoke test, la bataille, le banc, la trace, puis `bash tests/reseau/lancer.sh`.
Expected : `== 0 échec(s) ==` partout ; le banc (mesuré, reproductible au tick près) :

```text
MESURE parcours (lien parfait) : erreur max 0.00 px, 0 états sur 550 au-delà de 4 px, 0 au-delà de 16 px ; recalages 0 ; à-coups 0 ; rejeu le plus long 3 pas ; lion distant : 5.83 à 5.83 px par tick (5.83) ; commandes sautées 0, file au plus 1
MESURE parcours (80 ms, 40 ms de gigue, 5 % de pertes) : erreur max 5.83 px, 5 états sur 347 au-delà de 4 px, 0 au-delà de 16 px ; recalages 0 ; à-coups 0 ; rejeu le plus long 10 pas ; lion distant : 5.44 à 6.16 px par tick (5.83) ; commandes sautées 0, file au plus 4
```

et ses 18 lignes ✅ (dont « (lien parfait) sans latence ni pertes, le lion prédit reste à moins de 4 px de l'hôte (au plus 0.00 px sur 550 états) », « (80 ms, 40 ms de gigue, 5 % de pertes) 150 ms après l'arrêt des commandes, l'erreur de prédiction reste sous 4 px (au plus 0.00 px) », « … la gerbe du lion local part dès l'appui, sans attendre l'hôte », « … aucune commande appliquée deux fois : 639 appliquées, 0 sautées, jusqu'à la 639 (file au plus 4) ») ; la trace égale à la référence ; le test réseau vert, 10 lignes ✅ (les clients des scénarios 9 et 11 prédisent leur lion ; les empreintes restent égales : au repos, le lion prédit reprend exactement l'état de l'hôte).

- [ ] **Step 9 : Commit**

```bash
git add Scripts/PredictionLocale.gd Scripts/PredictionLocale.gd.uid Scripts/Lion.gd Scripts/Main.gd Scripts/Manche.gd project.godot .github/workflows/ci.yml tests/prediction_test.gd tests/prediction_test.gd.uid tests/smoke_test.gd tests/reseau/joueur.gd
git commit -m "Prédiction du lion local : sur un client, le lion avance tout de suite par Lion.avancer, se recale sur chaque état neuf de l'hôte en rejouant les commandes pas encore appliquées, correction douce de l'affichage (95 % en 120 ms, recalage au-delà de 200 px) ; commandes lues une fois par tick, envoyées avec les 3 précédentes, mises en file par l'hôte ; banc de la prédiction (en CI) ; version 0.16

<ligne fournie par l'environnement>"
```

---

### Task 5 : les cas durs (étourdissement, choc, écarts, hôte figé) et les preuves

**Files:**
- Modify: `Scripts/PareChocs.gd`, `Scripts/PredictionLocale.gd`
- Test: `tests/prediction_test.gd`

**Interfaces:**
- Consumes : Task 4 (le banc, `PredictionLocale`).
- Produces : `PareChocs.en_rejeu: bool` (vrai pendant un rejeu de `PredictionLocale._recaler`) ; les scénarios du banc `_scenario_etourdissement`, `_scenario_choc`, `_scenario_ecarts`, `_scenario_hote_fige` (Review Focus 2 à 5) et leurs lignes `MESURE`.

- [ ] **Step 1 : les scénarios**

Dans `tests/prediction_test.gd`, remplacer :

```gdscript
	await _scenario_parcours("lien parfait", 0.0, 0.0, 0.0)
	await _scenario_parcours("80 ms, 40 ms de gigue, 5 % de pertes", 80.0, 40.0, 5.0)
	GS.configurer_solo()
	GS.nouvelle_partie()
```

par :

```gdscript
	await _scenario_parcours("lien parfait", 0.0, 0.0, 0.0)
	await _scenario_parcours("80 ms, 40 ms de gigue, 5 % de pertes", 80.0, 40.0, 5.0)
	await _scenario_etourdissement()
	await _scenario_choc()
	await _scenario_ecarts()
	await _scenario_hote_fige()
	GS.configurer_solo()
	GS.nouvelle_partie()
```

Dans `tests/prediction_test.gd`, remplacer :

```gdscript
	_verifier_commandes(titre, h1.commandes.numero_applique / 100)
	await _liberer()
```

par :

```gdscript
	_verifier_commandes(titre, h1.commandes.numero_applique / 100)
	await _liberer()


## Un ennemi étourdit le lion du client chez l'hôte pendant qu'il court : la prédiction suit l'hôte
## (commandes ignorées, même règle que l'hôte), sans appliquer le recul deux fois, puis repart dès la
## fin de l'étourdissement reçue.
func _scenario_etourdissement() -> void:
	print("-- Étourdissement décidé par l'hôte, sous 80 ms, 40 ms, 5 %")
	_preparer(Vector2(300, 150), Vector2(400, 500), 80.0, 40.0, 5.0, 1700)
	_presser(Vector2.RIGHT)
	var j_hote: Joueur = GS.joueurs[1]
	var j_client: Joueur = _joueurs_client[1]
	var tick_etourdi := -1
	var tick_fin := -1
	var repart := -1
	var bouge_etourdi := 0.0
	var x_etourdi := 0.0
	var recul_hote := 0.0
	var numero_suivi := -1
	var numero_fin := -1
	for i in range(420):
		if _tick == 60:
			GS.regles.lion_touche_par_ennemi(j_hote, h1.global_position + h1.CENTRE + Vector2(-80, 0))
			recul_hote = h1.deplacement.recul.x
		await _pas()
		if tick_etourdi < 0 and j_client.est_etourdi():
			tick_etourdi = _tick
			x_etourdi = c1.position.x
		if tick_etourdi >= 0 and _tick == tick_etourdi + 2:
			numero_suivi = c1.prediction.numero
		if tick_etourdi >= 0 and tick_fin < 0 and j_client.est_etourdi():
			bouge_etourdi = c1.position.x - x_etourdi
		if tick_etourdi >= 0 and tick_fin < 0 and not j_client.est_etourdi():
			tick_fin = _tick
			numero_fin = c1.prediction.numero
		if tick_fin >= 0 and repart < 0 and c1.deplacement.vitesse.x > 0.0:
			repart = _tick - tick_fin
	_relacher()
	var arret := _prochain_numero()
	var p: Node = c1.prediction
	# Les commandes lues pendant l'étourdissement connu de ce poste, sauf les 12 dernières : la fin de
	# l'étourdissement arrive ici avec un aller simple de retard, et l'hôte applique déjà les commandes
	# que ce poste croit encore ignorées (un écart attendu, qu'absorbe le recalage).
	var pendant: float = p.erreur_max(numero_suivi, numero_fin - 12)
	print("MESURE étourdissement : reçu au tick %d, fini au tick %d, recul de l'hôte %.0f px/s ; le lion du client recule de %.1f px pendant l'étourdissement ; erreur max %.2f px, %.2f px pendant l'étourdissement ; recalages %d ; à-coups %d"
		% [tick_etourdi, tick_fin, recul_hote, bouge_etourdi, p.erreur_max(), pendant, p.recalages, _a_coups])
	_check(tick_etourdi > 60 and tick_fin > tick_etourdi, "(pré-condition) l'étourdissement de l'hôte arrive au client, puis sa fin")
	# Le recul de l'hôte (700 px/s, amorti en 0,19 s) arrive dans ses états ; rejoué une seconde fois
	# par le client, ou ses commandes suivies malgré l'étourdissement, le lion prédit partirait devant.
	_check(numero_suivi > 0 and pendant >= 0.0 and pendant < ECART_MAX and p.recalages == 0 and p.erreur_max() < 30.0,
		"étourdi, le lion du client suit l'hôte : un seul recul, ses commandes ignorées (erreur au plus %.2f px pendant l'étourdissement, %.2f px en tout), sans recalage" % [pendant, p.erreur_max()])
	_check(repart >= 0 and repart <= 2, "la fin de l'étourdissement reçue, le lion repart aussitôt à ses commandes (%d tick(s))" % repart)
	await _verifier_convergence("étourdissement", arret, 90)
	_verifier_commandes("étourdissement", h1.commandes.numero_applique / 100)
	await _liberer()


## Le lion du client percute celui de l'hôte, arrêté sur sa route : le choc est simulé tout de suite
## contre le lion affiché (interpolé), sans attendre l'hôte ; l'hôte le compte ; la prédiction converge.
func _scenario_choc() -> void:
	print("-- Choc contre un lion distant, sous 80 ms, 40 ms, 5 %")
	_preparer(Vector2(1200, 500), Vector2(700, 500), 80.0, 40.0, 5.0, 1800)
	for i in range(30):
		await _pas()  # le lion distant s'affiche à sa place
	_presser(Vector2.RIGHT)
	var tick_client := -1
	var tick_hote := -1
	var arret := -1
	var x_min := INF
	var rebond := 0.0
	for i in range(150):
		await _pas()
		if tick_client < 0 and c1.deplacement.recul.x < 0.0:
			tick_client = _tick
			_relacher()  # le joueur lâche tout au choc : son lion repart en arrière, puis s'arrête
			arret = _prochain_numero()
		if tick_hote < 0 and h1.deplacement.recul.x < 0.0:
			tick_hote = _tick
		if tick_client >= 0:
			x_min = minf(x_min, c1.position.x)
			rebond = maxf(rebond, c1.position.x - x_min)
	var p: Node = c1.prediction
	print("MESURE choc : simulé chez le client au tick %d, chez l'hôte au tick %d ; erreur max %.2f px ; rebond de l'affichage %.2f px ; recalages %d ; à-coups %d"
		% [tick_client, tick_hote, p.erreur_max(), rebond, p.recalages, _a_coups])
	_check(tick_client > 0 and tick_hote > 0 and tick_client <= tick_hote and GS.joueurs[1].chocs >= 1,
		"le choc est simulé chez le client sans attendre l'hôte (tick %d, l'hôte au tick %d), et l'hôte le compte" % [tick_client, tick_hote])
	# Le lion repart en arrière et s'arrête, sans revenir vers le lion percuté : le choc simulé, noté,
	# est rejoué tant que l'hôte ne l'a pas (oublié, le lion reviendrait avant de repartir).
	_check(p.recalages == 0 and rebond < ECART_MAX and p.erreur_max() < ECART_MAX,
		"le choc ne fait ni recalage ni aller-retour visible (rebond de %.2f px ; erreur au plus %.2f px)" % [rebond, p.erreur_max()])
	await _verifier_convergence("choc", arret, 90)
	await _liberer()


## L'hôte déplace le lion du client : de 60 px, le lion glisse jusqu'à lui en 100 à 150 ms
## (correction douce) ; de plus de 200 px (téléportation), il est recalé d'un coup, sans glisser.
func _scenario_ecarts() -> void:
	print("-- Écarts imposés par l'hôte (correction douce, recalage), sous 80 ms, 40 ms, 5 %")
	_preparer(Vector2(300, 150), Vector2(700, 600), 80.0, 40.0, 5.0, 1900)
	for i in range(30):
		await _pas()
	h1.global_position += Vector2(60, 0)
	var debut := -1
	var pas_max := 0.0
	var ecart_apres := -1.0
	for i in range(40):
		var avant: Vector2 = c1.position
		await _pas()
		var pas: float = c1.position.distance_to(avant)
		if debut < 0 and pas > 0.0:
			debut = _tick
		pas_max = maxf(pas_max, pas)
		if debut >= 0 and _tick == debut + TICKS_CONVERGENCE:
			ecart_apres = c1.position.distance_to(h1.position)
	print("MESURE écarts : 60 px résorbés en glissant, %.1f px au plus par tick, %.2f px restants 150 ms après" % [pas_max, ecart_apres])
	_check(c1.prediction.recalages == 0 and debut > 0 and pas_max < 30.0 and ecart_apres >= 0.0 and ecart_apres < ECART_MAX,
		"un écart de 60 px se résorbe en douceur : le lion glisse vers celui de l'hôte (%.1f px par tick au plus) et l'a rejoint 150 ms après (%.2f px)" % [pas_max, ecart_apres])
	h1.global_position += Vector2(500, -300)
	var saut := 0.0
	for i in range(30):
		var avant: Vector2 = c1.position
		await _pas()
		saut = maxf(saut, c1.position.distance_to(avant))
	var p: Node = c1.prediction
	_check(p.recalages == 1 and saut > 500.0 and c1.position.distance_to(h1.position) < ECART_MAX and p.decalage() == Vector2.ZERO,
		"au-delà de %.0f px, le lion est recalé d'un coup sur l'hôte (%d recalage, un saut de %.0f px), sans glisser jusqu'à lui" % [p.SEUIL_RECALAGE, p.recalages, saut])
	await _liberer()


## L'hôte se fige 2 s (gel, fin de manche) pendant que le client joue : aucun rejeu pendant le gel (le
## même état revient, jamais rejoué), un historique borné, puis un recalage franc sur l'hôte.
func _scenario_hote_fige() -> void:
	print("-- Hôte figé pendant que le client joue, sous 80 ms, 40 ms, 5 %")
	_preparer(Vector2(300, 150), Vector2(400, 600), 80.0, 40.0, 5.0, 2000)
	for i in range(30):
		await _pas()
	_vue_hote.process_mode = Node.PROCESS_MODE_DISABLED
	for i in range(10):
		await _pas()  # les derniers états d'avant le gel arrivent
	var etats_avant: int = c1.prediction.etats_recus
	var rejeu_avant: int = c1.prediction.rejeu_max
	_presser(Vector2.RIGHT)
	for i in range(110):
		await _pas()
	_relacher()
	var etats_pendant: int = c1.prediction.etats_recus - etats_avant
	for i in range(20):
		await _pas()
	_vue_hote.process_mode = Node.PROCESS_MODE_INHERIT
	var arret := _prochain_numero()
	await _verifier_convergence("hôte figé", arret, 60)
	var p: Node = c1.prediction
	print("MESURE hôte figé : %d états neufs pendant le gel, rejeu le plus long %d pas (avant le gel %d), %d recalage(s)"
		% [etats_pendant, p.rejeu_max, rejeu_avant, p.recalages])
	_check(etats_pendant == 0 and p.rejeu_max <= p.HISTORIQUE_MAX and p.recalages == 1,
		"pendant le gel, le même état ne se rejoue pas ; l'historique reste borné (%d pas au plus) ; au dégel, un recalage franc" % p.rejeu_max)
	_verifier_commandes("hôte figé", h1.commandes.numero_applique)
	await _liberer()
```


- [ ] **Step 2 : le choc échoue**

Run : le banc. Expected (mesuré) : `❌ le choc ne fait ni recalage ni aller-retour visible (rebond de 16.39 px ; erreur au plus 46.67 px)` : rejoués après le contact, les pas d'avant le contact butent contre le lion percuté, toujours dans la liste des contacts présents ; les trois autres scénarios passent.

- [ ] **Step 3 : le rejeu ne bute que contre un pare-chocs qu'il touche**

Dans `Scripts/PareChocs.gd`, remplacer :

```gdscript
@onready var _lion: Lion = get_parent()

## Instant (`Lion.temps`, en secondes de jeu) du dernier choc compté avec chaque autre lion, par
## identifiant d'instance du lion ; entrées des lions libérés nettoyées à la volée. Le temps de jeu,
```

par :

```gdscript
@onready var _lion: Lion = get_parent()

## Vrai pendant qu'une prédiction rejoue des pas passés du lion (`PredictionLocale`) : `bloquer` ne
## voit que les contacts présents, qu'il ne compte alors qu'aux positions rejouées où les deux
## pare-chocs se touchent (un pas rejoué d'avant le contact ne doit pas buter contre lui).
var en_rejeu := false
## Instant (`Lion.temps`, en secondes de jeu) du dernier choc compté avec chaque autre lion, par
## identifiant d'instance du lion ; entrées des lions libérés nettoyées à la volée. Le temps de jeu,
```

Dans `Scripts/PareChocs.gd`, remplacer :

```gdscript
		var autre := zone.get_parent() as Lion
		if autre == null or autre == _lion:
			continue
		var normale := _normale_de_choc(autre)
```

par :

```gdscript
		var autre := zone.get_parent() as Lion
		if autre == null or autre == _lion:
			continue
		if en_rejeu and global_position.distance_to(autre.pare_chocs.global_position) > 2.0 * rayon:
			continue
		var normale := _normale_de_choc(autre)
```


Dans `Scripts/PredictionLocale.gd`, remplacer :

```gdscript
	_lion.deplacement.recul = etat.recul
	_lion.direction_du_lion = etat.direction
	for i in range(_historique.size()):
		var c: Dictionary = _historique[i]
```

par :

```gdscript
	_lion.deplacement.recul = etat.recul
	_lion.direction_du_lion = etat.direction
	_lion.pare_chocs.en_rejeu = true
	for i in range(_historique.size()):
		var c: Dictionary = _historique[i]
```

Dans `Scripts/PredictionLocale.gd`, remplacer :

```gdscript
			break  # la commande de ce tick : son pas suit, dans `_physics_process`
		_lion.avancer(_lion.direction_pour(c.direction), delta)
	rejeu_max = maxi(rejeu_max, _historique.size() - 1)
	var ecart := avant - _lion.position
```

par :

```gdscript
			break  # la commande de ce tick : son pas suit, dans `_physics_process`
		_lion.avancer(_lion.direction_pour(c.direction), delta)
	_lion.pare_chocs.en_rejeu = false
	rejeu_max = maxi(rejeu_max, _historique.size() - 1)
	var ecart := avant - _lion.position
```


- [ ] **Step 4 : le banc passe, la trace ne change pas**

Run : `godot --headless --import .`, le banc, le smoke test, la bataille et la trace.
Expected : `== 0 échec(s) ==` partout ; le banc (mesuré) ajoute :

```text
MESURE étourdissement : reçu au tick 62, fini au tick 213, recul de l'hôte 700 px/s ; le lion du client recule de 21.5 px pendant l'étourdissement ; erreur max 14.17 px, 0.00 px pendant l'étourdissement ; recalages 0 ; à-coups 2
MESURE choc : simulé chez le client au tick 105, chez l'hôte au tick 110 ; erreur max 0.64 px ; rebond de l'affichage 0.00 px ; recalages 0 ; à-coups 0
MESURE écarts : 60 px résorbés en glissant, 20.4 px au plus par tick, 0.93 px restants 150 ms après
MESURE hôte figé : 0 états neufs pendant le gel, rejeu le plus long 14 pas (avant le gel 9), 1 recalage(s)
```

(`en_rejeu` n'est vrai que pendant un rejeu, sur un client : l'hôte ne le voit jamais, la trace ne bouge pas.)

- [ ] **Step 5 : Commit**

```bash
git add Scripts/PareChocs.gd Scripts/PredictionLocale.gd tests/prediction_test.gd
git commit -m "Prédiction : un pas rejoué ne bute que contre un lion que son pare-chocs touche ; banc : étourdissement décidé par l'hôte, choc contre un lion distant, écarts imposés par l'hôte (glissade, recalage), hôte figé

<ligne fournie par l'environnement>"
```

- [ ] **Step 6 : le banc discrimine**

Chaque mutation seule, puis le banc, puis **`git checkout -- Scripts/`** avant la suivante (mesuré en préparant le plan) :
- M1 : dans `Scripts/PredictionLocale.gd`, `_recaler`, `_lion.avancer(_lion.direction_pour(c.direction), delta)` → `_lion.avancer(c.direction, delta)` ⇒ `❌ étourdi, le lion du client suit l'hôte : un seul recul, ses commandes ignorées (erreur au plus 40.83 px pendant l'étourdissement, 40.83 px en tout), sans recalage` ;
- M2 : dans `Scripts/Lion.gd`, `_on_etourdi`, ajouter après `_reculer(origine)` la ligne `pare_chocs.choc_simule.emit(Vector2.ZERO, deplacement.recul)` ⇒ `❌ étourdi, le lion du client suit l'hôte : … (erreur au plus 77.67 px pendant l'étourdissement, 77.67 px en tout)…` ;
- M3 : dans `Scripts/PredictionLocale.gd`, `_physics_process`, `_recaler(etat, delta)` → `pass` ⇒ douze `❌`, dont « (lien parfait) sans latence ni pertes, le lion prédit reste à moins de 4 px de l'hôte (au plus -1.00 px sur 0 états) » et « (hôte figé) au repos, le lion affiché du client est sur celui de l'hôte (641.67 px)… » ;
- M4 : dans `Scripts/PredictionLocale.gd`, `_ready`, supprimer la ligne `_lion.pare_chocs.choc_simule.connect(_sur_choc_simule)` ⇒ `❌ le choc ne fait ni recalage ni aller-retour visible (rebond de 0.00 px ; erreur au plus 18.22 px)` ;
- M5 : dans `Scripts/PredictionLocale.gd`, `_recaler`, `_lion.pare_chocs.en_rejeu = true` → `_lion.pare_chocs.en_rejeu = false` ⇒ `❌ le choc ne fait ni recalage ni aller-retour visible (rebond de 16.39 px ; erreur au plus 46.67 px)` ;
- M7 : dans `Scripts/PredictionLocale.gd`, `_recaler`, `if ecart.length() > SEUIL_RECALAGE:` → `if false:` ⇒ `❌ au-delà de 200 px, le lion est recalé d'un coup sur l'hôte (0 recalage, un saut de 199 px), sans glisser jusqu'à lui` et `❌ pendant le gel, le même état ne se rejoue pas…` ;
- M8 : dans `Scripts/PredictionLocale.gd`, `_recaler`, `		_decalage += ecart` → `		pass` ⇒ `❌ un écart de 60 px se résorbe en douceur : le lion glisse vers celui de l'hôte (60.0 px par tick au plus) et l'a rejoint 150 ms après (0.00 px)`.

Expected ensuite : `git status --short` vide ; le banc de nouveau vert.

---

### Task 6 : le simulateur de latence et la manche sous latence (scénario 12)

**Files:**
- Create: `tests/reseau/relais.gd` (+ `.uid`)
- Modify: `tests/reseau/joueur.gd`, `tests/reseau/lancer.sh`, `.github/workflows/ci.yml`

**Interfaces:**
- Consumes : Tasks 1 à 5 (`PredictionLocale` et ses statistiques, `Commandes` et ses comptes, `Lion.etiquette_pseudo`).
- Produces (Task 7) : `godot --headless --script tests/reseau/relais.gd -- --ecoute=<port> --vers=<port> [--latence=80] [--gigue=40] [--pertes=5] [--graine=N] [--fin=<fichier>] [--duree=<s>]` (« RELAIS PRET … », puis « RELAIS datagrammes=… perdus=… (… %) retard_moyen=… ms liaisons=… ») ; rôles `latence-hote` et `latence-client` de `joueur.gd` (lignes « PREDICTION … », « COMMANDES … ») ; `Programme.new(graine, ville, moitie := -1)` ; scénario 12 de `lancer.sh` (ports `PORT_BASE + 12`, `+ 1012`, relais `+ 2012`, `DUREE12=20`).

- [ ] **Step 1 : le scénario 12 et ses rôles**

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
#!/usr/bin/env bash
# Test réseau du transport (phase 11), de la découverte (phase 12), du salon (phase 13), de la
# manche synchronisée (phase 14) et de bout en bout (phase 15) : des postes headless sur localhost,
# un processus Godot par poste (tests/reseau/joueur.gd), scénario après scénario.
#   tests/reseau/lancer.sh [port_de_base]
# Le scénario n utilise le port port_de_base + n (défaut 17777 : jamais le 7777 d'une vraie partie)
# et, pour les balises de découverte, port_de_base + 1000 + n (jamais le 7778).
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40 ; le
# scénario 11, une manche entière, a le sien : DUREE11 + 60),
# DIFFUSION=1 (ajoute le scénario 7, balises en vraie diffusion : hors CI, où la diffusion n'a pas
# été mesurée ; le scénario 6 couvre le même chemin en envoi direct vers 127.0.0.1).
```

par :

```bash
#!/usr/bin/env bash
# Test réseau du transport (phase 11), de la découverte (phase 12), du salon (phase 13), de la
# manche synchronisée (phase 14), de bout en bout (phase 15) et de la prédiction sous latence
# simulée (phase 16) : des postes headless sur localhost, un processus Godot par poste
# (tests/reseau/joueur.gd), et pour le scénario 12 le simulateur de latence (tests/reseau/relais.gd),
# scénario après scénario.
#   tests/reseau/lancer.sh [port_de_base]
# Le scénario n utilise le port port_de_base + n (défaut 17777 : jamais le 7777 d'une vraie partie)
# et, pour les balises de découverte, port_de_base + 1000 + n (jamais le 7778) ; le relais du
# scénario 12 écoute sur port_de_base + 2012.
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40 ; les
# scénarios 11 et 12, des manches jouées, ont le leur : DUREE11 + 60, DUREE12 + 50),
# DIFFUSION=1 (ajoute le scénario 7, balises en vraie diffusion : hors CI, où la diffusion n'a pas
# été mesurée ; le scénario 6 couvre le même chemin en envoi direct vers 127.0.0.1).
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
	shift
	timeout -k 5 "$DELAI" "$GODOT" --headless --script tests/reseau/joueur.gd -- "$@" >"$JOURNAUX/$nom.log" 2>&1 &
	PIDS+=("$!")
	NOMS+=("$nom")
```

par :

```bash
	shift
	timeout -k 5 "$DELAI" "$GODOT" --headless --script tests/reseau/joueur.gd -- "$@" >"$JOURNAUX/$nom.log" 2>&1 &
	PIDS+=("$!")
	NOMS+=("$nom")
}

# lancer_relais <nom> <arguments de relais.gd…> : le simulateur de latence en arrière-plan, borné
# comme un poste.
lancer_relais() {
	local nom="$1"
	shift
	timeout -k 5 "$DELAI" "$GODOT" --headless --script tests/reseau/relais.gd -- "$@" >"$JOURNAUX/$nom.log" 2>&1 &
	PIDS+=("$!")
	NOMS+=("$nom")
```

Dans `tests/reseau/lancer.sh`, remplacer :

```bash
[ "$(for nom in hote11 $restes11; do grep -h "^EMPREINTE " "$JOURNAUX/$nom.log"; done 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
	&& [ "$(compter "^EMPREINTE " hote11 $restes11)" -eq 3 ] || echec "de bout en bout : l'hôte et les deux clients restés doivent finir avec la même empreinte"
ecart11=$(grep -o "ECART_DEPART [0-9]*" "$JOURNAUX/hote11.log" 2>/dev/null | head -1 | awk '{print $2}')
echo "  (bout en bout) départ arraché vu par l'hôte au bout de ${ecart11:-?} ms"
[ -n "$ecart11" ] && [ "$ecart11" -le 10000 ] 2>/dev/null \
	|| echec "de bout en bout : départ arraché vu au bout de ${ecart11:-?} ms (attendu au plus 10000 : le silence de session d'ENet, 8 s au plus, et la marge d'une image)"

echo "== $ECHECS échec(s) =="
```

par :

```bash
[ "$(for nom in hote11 $restes11; do grep -h "^EMPREINTE " "$JOURNAUX/$nom.log"; done 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
	&& [ "$(compter "^EMPREINTE " hote11 $restes11)" -eq 3 ] || echec "de bout en bout : l'hôte et les deux clients restés doivent finir avec la même empreinte"
for nom in $restes11; do
	grep -h "^PREDICTION " "$JOURNAUX/$nom.log" 2>/dev/null | sed 's/^/  (bout en bout) /'
done
ecart11=$(grep -o "ECART_DEPART [0-9]*" "$JOURNAUX/hote11.log" 2>/dev/null | head -1 | awk '{print $2}')
echo "  (bout en bout) départ arraché vu par l'hôte au bout de ${ecart11:-?} ms"
[ -n "$ecart11" ] && [ "$ecart11" -le 10000 ] 2>/dev/null \
	|| echec "de bout en bout : départ arraché vu au bout de ${ecart11:-?} ms (attendu au plus 10000 : le silence de session d'ENet, 8 s au plus, et la marge d'une image)"

# 12. Prédiction sous latence simulée (phase 16), par les vraies scènes : un hôte et deux clients, les
#     clients derrière le relais (80 ms d'aller-retour, 40 ms de gigue, 5 % de pertes dans chaque
#     sens). Chaque client joue au clavier son programme au hasard (graine), dans sa moitié de la bande
#     de peinture ; l'hôte reste immobile et écarte les ennemis. Au calme, chaque client vérifie sa
#     prédiction (aucun recalage, l'erreur rarement au-delà de 16 px, sous 4 px 150 ms après l'arrêt de
#     ses commandes), l'hôte les commandes reçues (aucune appliquée deux fois, presque aucune sautée) ;
#     puis la même empreinte chez l'hôte et les deux clients. L'hôte part (ses clients le voient partir
#     à travers le relais), puis le relais s'arrête.
DUREE12=20
P=$((PORT_BASE + 12))
B=$((PORT_BASE + 1012))
R=$((PORT_BASE + 2012))
DELAI_AVANT12=$DELAI
DELAI=$((DUREE12 + 50))
lancer_relais relais12 --ecoute=$R --vers=$P --latence=80 --gigue=40 --pertes=5 --graine=12 --fin="$JOURNAUX/fin12"
lancer hote12 --role=latence-hote --port=$P --port-balise=$B --pseudo=Hote12 --clients=2 --niveau=0 --duree=$DUREE12 \
	--rester="$JOURNAUX/rester12"
if attendre_ligne relais12 "RELAIS PRET" && attendre_hote hote12; then
	lancer a12 --role=latence-client --port=$R --port-balise=$B --pseudo=Anna --graine=5 --moitie=0 --calme="$JOURNAUX/calme12" --fige="$JOURNAUX/fige12"
	lancer b12 --role=latence-client --port=$R --port-balise=$B --pseudo=Bruno --graine=6 --moitie=1 --calme="$JOURNAUX/calme12" --fige="$JOURNAUX/fige12"
	if attendre_ligne hote12 "INTRO" 30 && attendre_ligne hote12 "CALME" $((DUREE12 + 10)); then
		touch "$JOURNAUX/calme12"
		if attendre_ligne a12 "PREDICTION" && attendre_ligne b12 "PREDICTION" && attendre_ligne hote12 "FIGE" 30; then
			touch "$JOURNAUX/fige12"
			attendre_ligne a12 "EMPREINTE" && attendre_ligne b12 "EMPREINTE" && touch "$JOURNAUX/rester12"
		fi
	fi
	touch "$JOURNAUX/calme12" "$JOURNAUX/fige12" "$JOURNAUX/rester12"
	attendre_fin hote12
	attendre_fin a12
	attendre_fin b12
fi
touch "$JOURNAUX/fin12"
terminer "prédiction sous latence simulée (80 ms, 40 ms de gigue, 5 % de pertes) : lion local prédit et recalé, commandes redondantes appliquées une fois, mêmes empreintes chez l'hôte et les clients"
DELAI=$DELAI_AVANT12
[ "$(for nom in hote12 a12 b12; do grep -h "^EMPREINTE " "$JOURNAUX/$nom.log"; done 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
	&& [ "$(compter "^EMPREINTE " hote12 a12 b12)" -eq 3 ] || echec "prédiction sous latence : l'hôte et les deux clients doivent finir avec la même empreinte"
grep -hE "^PREDICTION |^COMMANDES |^RELAIS datagrammes" "$JOURNAUX/a12.log" "$JOURNAUX/b12.log" "$JOURNAUX/hote12.log" "$JOURNAUX/relais12.log" 2>/dev/null | sed 's/^/  (latence) /'

echo "== $ECHECS échec(s) =="
```


Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
##   godot --headless --script tests/reseau/joueur.gd -- --role=<rôle> [options]
## Rôles : hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client,
## manche-muet, bout-hote, bout-client.
## Communes : --port=N (défaut 17777), --pseudo=texte, --port-balise=N (port des balises de
##   découverte, émises par un hôte et écoutées par un écouteur ; défaut : --port + 1000),
```

par :

```gdscript
##   godot --headless --script tests/reseau/joueur.gd -- --role=<rôle> [options]
## Rôles : hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client,
## manche-muet, bout-hote, bout-client, latence-hote, latence-client.
## Communes : --port=N (défaut 17777), --pseudo=texte, --port-balise=N (port des balises de
##   découverte, émises par un hôte et écoutées par un écouteur ; défaut : --port + 1000),
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
##   Bout-client : --graine=N, --calme=chemin (joue son programme jusqu'à ce fichier, puis écrit
##   « CALME VU »), --fige=chemin (comme un client de la manche : sa propre « EMPREINTE »).
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
## `Reseau`, `Decouverte`, `GameState` et `Scores` par `root.get_node`, ne nomme ni `Reseau`, ni
```

par :

```gdscript
##   Bout-client : --graine=N, --calme=chemin (joue son programme jusqu'à ce fichier, puis écrit
##   « CALME VU »), --fige=chemin (comme un client de la manche : sa propre « EMPREINTE »).
## Prédiction sous latence simulée (phase 16), par les vraies scènes : 1 hôte + 2 clients, les clients
##   passant par le relais de `tests/reseau/relais.gd` (leur --port est celui du relais), sur le niveau
##   --niveau=L choisi par l'hôte au salon.
##   Latence-hôte : --clients=N, --niveau=L, --duree=S, --rester=chemin. Reste immobile, écarte les
##   ennemis (la prédiction se mesure sur les commandes des joueurs ; un étourdissement est couvert par
##   `tests/prediction_test.gd`) ; à DUREE_CALME s de la fin, écrit « CALME » ; lions arrêtés, coulures
##   finies, la manche à son terme, il écrit pour chaque client « COMMANDES <pseudo> … » (aucune
##   commande appliquée deux fois, presque aucune sautée), fige la manche : « EMPREINTE … », « FIGE ».
##   Latence-client : --graine=N, --moitie=0|1 (sa moitié de la bande de peinture : les deux clients
##   ne se croisent pas), --calme=chemin (joue son programme jusqu'à ce fichier, puis lâche tout),
##   --fige=chemin. Une fois ses commandes d'après l'arrêt accusées par l'hôte, écrit « PREDICTION … »
##   (erreurs de prédiction, recalages, à-coups, plus long rejeu) et vérifie : aucun recalage, l'erreur
##   rarement au-delà de 16 px, sous 4 px 150 ms après l'arrêt ; puis sa propre « EMPREINTE ».
## Code de sortie 0 si toutes ses vérifications passent. Compilé avant les autoloads : récupère
## `Reseau`, `Decouverte`, `GameState` et `Scores` par `root.get_node`, ne nomme ni `Reseau`, ni
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
const DEBUT_RENCONTRES := 20.0
const DUREE_CALME := 4.0
## Vitesse (px/s) au-delà de laquelle un lion ramasse une pastille « au vol », ou percute l'hôte.
const VITESSE_AU_VOL := 150.0
```

par :

```gdscript
const DEBUT_RENCONTRES := 20.0
const DUREE_CALME := 4.0
## Prédiction sous latence : l'erreur de prédiction doit converger sous ECART_PREDICTION px en
## TICKS_CONVERGENCE ticks (150 ms) après l'arrêt des commandes (spec §10) ; au-delà d'A_COUP px d'une
## image physique à l'autre (pleine vitesse et moitié en plus), l'affichage du lion local saute.
const ECART_PREDICTION := 4.0
const TICKS_CONVERGENCE := 9
const A_COUP := 350.0 / 60.0 * 1.5
## Vitesse (px/s) au-delà de laquelle un lion ramasse une pastille « au vol », ou percute l'hôte.
const VITESSE_AU_VOL := 150.0
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	elif role == "bout-hote" or role == "bout-client":
		await _jouer_bout(role == "bout-hote")
	else:
		_check(false, "rôle inconnu : --role=hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client, manche-muet, bout-hote ou bout-client")
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		and root.multiplayer.is_server() and reseau.inscrits.is_empty() and reseau.index_local == -1
```

par :

```gdscript
	elif role == "bout-hote" or role == "bout-client":
		await _jouer_bout(role == "bout-hote")
	elif role == "latence-hote" or role == "latence-client":
		await _jouer_latence(role == "latence-hote")
	else:
		_check(false, "rôle inconnu : --role=hote, client, lent, ecouteur, salon-hote, salon-client, manche-hote, manche-client, manche-muet, bout-hote, bout-client, latence-hote ou latence-client")
	_check(not reseau.en_ligne() and root.multiplayer.multiplayer_peer is OfflineMultiplayerPeer
		and root.multiplayer.is_server() and reseau.inscrits.is_empty() and reseau.index_local == -1
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	_check(await _attendre(func() -> bool: return manche.barriere), "la barrière de chargement passe")
	if mesurer_exclusion and ticks_exclu >= 0:
		print("ECART_EXCLUSION %d" % (Time.get_ticks_msec() - ticks_exclu))
	_check(_issue.is_empty(), "personne ne s'est cru abandonné pendant le chargement (%s)" % _issue)
	if hote:
```

par :

```gdscript
	_check(await _attendre(func() -> bool: return manche.barriere), "la barrière de chargement passe")
	if mesurer_exclusion and ticks_exclu >= 0:
		var ecart_exclusion := Time.get_ticks_msec() - ticks_exclu
		# lancer.sh arrête ce poste dès la mesure écrite (scénario 10) : ses scores de test s'effacent avant.
		_effacer_scores()
		print("ECART_EXCLUSION %d" % ecart_exclusion)
	_check(_issue.is_empty(), "personne ne s'est cru abandonné pendant le chargement (%s)" % _issue)
	if hote:
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
		proprietaires[i] = territoire.proprietaire_compte(i) + 1
	var lions: Array = main.lions.map(func(l: Node) -> String:
		return "%s:%.1f,%.1f,%d,%d,%s,%s" % [l.name, l.position.x, l.position.y, l.direction_du_lion, l.joueur.crans,
			l.joueur.est_etourdi(), l.joueur.bonus_actif()])
	var scenes: Array[String] = []
	var spawner: MultiplayerSpawner = main.get_node("Apparitions")
```

par :

```gdscript
		proprietaires[i] = territoire.proprietaire_compte(i) + 1
	var lions: Array = main.lions.map(func(l: Node) -> String:
		return "%s:%.1f,%.1f,%d,%d,%s,%s,%s" % [l.name, l.position.x, l.position.y, l.direction_du_lion, l.joueur.crans,
			l.joueur.est_etourdi(), l.joueur.bonus_actif(), l.etiquette_pseudo.visible])
	var scenes: Array[String] = []
	var spawner: MultiplayerSpawner = main.get_node("Apparitions")
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	var fin_vomi := 0

	func _init(graine: int, ville: Node2D) -> void:
		rng.seed = graine
		var haut: float = ville.position.y - ville.tex_size.y / 2.0
		bande = Rect2(100.0, haut - 300.0, 1650.0, 120.0)

	## Une image de jeu pour `lion` (le lion de ce poste, dont la position est celle de l'hôte).
```

par :

```gdscript
	var fin_vomi := 0

	## `moitie` : 0 ou 1 pour ne jouer que dans la moitié gauche ou droite de la bande (assez loin de
	## l'autre pour que deux lions ne s'y touchent pas), -1 pour toute la bande.
	func _init(graine: int, ville: Node2D, moitie := -1) -> void:
		rng.seed = graine
		var haut: float = ville.position.y - ville.tex_size.y / 2.0
		bande = Rect2(100.0, haut - 300.0, 1650.0, 120.0)
		if moitie >= 0:
			bande = Rect2(100.0 + moitie * 970.0, haut - 300.0, 680.0, 120.0)

	## Une image de jeu pour `lion` (le lion de ce poste, dont la position est celle de l'hôte).
```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
		else:
			Input.action_release(action)


```

par :

```gdscript
		else:
			Input.action_release(action)


## Rôles « latence-hote » et « latence-client » (phase 16, voir l'en-tête) : une manche à 1 hôte et 2
## clients, les clients derrière le simulateur de latence ; chaque client mesure sa prédiction, l'hôte
## les commandes reçues ; la même empreinte chez tous.
func _jouer_latence(hote: bool) -> void:
	var main := await _rejoindre_la_manche(hote)
	if main == null:
		return
	var gs: Node = root.get_node("GameState")
	var manche: Node = main.get_node("Manche")
	_check(await _attendre(func() -> bool: return manche.barriere), "la barrière de chargement passe")
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size()) and gs.joueurs.size() == 3,
		"un lion par joueur, 1 hôte et 2 clients (%d)" % main.lions.size())
	_check(await _attendre(func() -> bool: return gs.pret), "l'intro se termine chez tous")
	print("INTRO")
	if hote:
		await _animer_latence_hote(main, manche, gs)
	else:
		await _animer_latence_client(main, manche)
	_effacer_scores()


func _animer_latence_hote(main: Node, manche: Node, gs: Node) -> void:
	var duree := float(_option("duree", "20"))
	var ville: Node2D = main.get_node("Ville")
	var spawner: Node = main.get_node("Spawner")
	var ecarter_ennemis := func() -> bool:
		for t: Timer in [spawner._timer_soucoupe, spawner._timer_coccinelle]:
			if t != null:
				t.stop()
		for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss"):
			ennemi.queue_free()
		return gs.temps_ecoule >= duree - DUREE_CALME
	_check(await _attendre(ecarter_ennemis, duree + 10.0), "le jeu dure jusqu'à %.0f s de la fin, sans ennemis" % DUREE_CALME)
	print("CALME")
	var calme := func() -> bool:
		return main.lions.all(func(l: Node) -> bool: return l.velocity == Vector2.ZERO) and ville.coulures.is_empty()
	_check(await _attendre(calme), "les lions s'arrêtent, les coulures finissent")
	_check(await _attendre(func() -> bool: return gs.temps_ecoule >= duree), "la manche va jusqu'au bout de ses %.0f s" % duree)
	for l: Node in main.lions:
		if l == main.lion:
			continue
		var c: Commandes = l.commandes
		print("COMMANDES %s appliquees=%d sautees=%d numero=%d file_max=%d" % [l.joueur.pseudo, c.appliquees, c.sautees, c.numero_applique, c.file_max_vue])
		_check(c.numero_applique > 600 and c.appliquees + c.sautees == c.numero_applique and c.sautees * 100 <= c.numero_applique,
			"les commandes de %s : aucune appliquée deux fois, %d sautées sur %d (redondance)" % [l.joueur.pseudo, c.sautees, c.numero_applique])
	gs.terminer_partie(false)
	await _pause(1.0)
	print("EMPREINTE %s" % _empreinte(main, manche, true))
	print("FIGE")
	var rester := _option("rester", "")
	print("HOTE RESTE")
	_check(await _attendre(func() -> bool: return FileAccess.file_exists(rester)), "lancer.sh laisse partir l'hôte (%s)" % rester)
	paused = false
	reseau.quitter()


func _animer_latence_client(main: Node, manche: Node) -> void:
	var calme := _option("calme", "")
	var programme := Programme.new(int(_option("graine", "1")), main.get_node("Ville"), int(_option("moitie", "-1")))
	var prediction: Node = main.lion.prediction
	var a_coups := [0, main.lion.position]  # partagé avec la lambda : à-coups, position de l'image d'avant
	var mesurer := func() -> void:
		if main.lion != null:
			if main.lion.position.distance_to(a_coups[1]) > A_COUP + main.lion.deplacement.recul.length() / 60.0:
				a_coups[0] += 1
			a_coups[1] = main.lion.position
	physics_frame.connect(mesurer)
	_check(await _jouer_jusqu_a(main, programme, func() -> bool: return FileAccess.file_exists(calme), ReglesBataille.DUREE_MANCHE),
		"le jeu dure jusqu'au calme annoncé par lancer.sh (%s)" % calme)
	programme.relacher()
	var arret: int = prediction.numero + 1
	_check(await _attendre(func() -> bool: return prediction.numero_accuse >= arret + 60),
		"l'hôte accuse les commandes d'après l'arrêt (%d, arrêt à la %d)" % [prediction.numero_accuse, arret])
	physics_frame.disconnect(mesurer)
	var etats: int = prediction.etats_depuis(1)
	var apres: float = prediction.erreur_max(arret + TICKS_CONVERGENCE)
	print("PREDICTION %s : erreur max %.2f px, %d états sur %d au-delà de 4 px, %d au-delà de 16 px ; %.2f px au plus 150 ms après l'arrêt ; recalages %d ; à-coups %d ; rejeu le plus long %d pas"
		% [reseau.pseudo, prediction.erreur_max(), prediction.erreurs_au_dela(ECART_PREDICTION), etats, prediction.erreurs_au_dela(16.0), apres,
			prediction.recalages, a_coups[0], prediction.rejeu_max])
	_check(etats > 600 and prediction.recalages == 0, "le lion prédit n'est jamais recalé d'un coup (%d états de l'hôte)" % etats)
	# Un à-coup de l'hôte (une image longue : il rattrape plusieurs ticks d'un coup, sa file se vide) lui
	# fait répéter une commande, donc une erreur de quelques pas (mesuré sur 20 clients : jusqu'à 110 px,
	# au plus 18 états sur 696 au-delà de 16 px), que la correction douce absorbe. Une prédiction cassée
	# dépasse 16 px presque à chaque état : au plus 10 % des états au-delà de 16 px.
	_check(prediction.erreurs_au_dela(16.0) * 10 <= etats, "l'erreur de prédiction dépasse rarement 16 px (%d fois sur %d)" % [prediction.erreurs_au_dela(16.0), etats])
	_check(apres >= 0.0 and apres < ECART_PREDICTION, "150 ms après l'arrêt de ses commandes, l'erreur de prédiction reste sous %.0f px (%.2f px)" % [ECART_PREDICTION, apres])
	await _finir_manche_client(main, manche)


```

Dans `tests/reseau/joueur.gd`, remplacer :

```gdscript
	programme.relacher()
	_ecrire_mesure()
	print("CALME VU")
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size() - 1),
```

par :

```gdscript
	programme.relacher()
	_ecrire_mesure()
	var prediction: Node = main.lion.prediction
	# Mesure seule (phase 16) : sans latence, mais avec les rencontres, où l'hôte déplace les lions
	# (recalages attendus) et les chocs.
	print("PREDICTION %s (sans latence, rencontres comprises) : erreur max %.2f px, %d états sur %d au-delà de 4 px ; recalages %d ; rejeu le plus long %d pas"
		% [reseau.pseudo, prediction.erreur_max(), prediction.erreurs_au_dela(ECART_PREDICTION), prediction.etats_depuis(1), prediction.recalages,
			prediction.rejeu_max])
	print("CALME VU")
	_check(await _attendre(func() -> bool: return main.lions.size() == gs.joueurs.size() - 1),
```


- [ ] **Step 2 : il échoue**

Run : `bash tests/reseau/lancer.sh`. Expected (mesuré) : les scénarios 1 à 11 verts ; le 12 : `❌ « RELAIS PRET » n'apparaît jamais dans le journal de relais12` (le script du relais n'existe pas), puis l'hôte, que personne ne rejoint, échoue (`❌ prédiction sous latence simulée … : hote12 sort en 1`, dont `❌ 3 joueurs au salon`), et `❌ prédiction sous latence : l'hôte et les deux clients doivent finir avec la même empreinte`.

- [ ] **Step 3 : le relais**

Créer `tests/reseau/relais.gd` :

```gdscript
extends SceneTree
## Le simulateur de latence (phase 16, spec §4.1) : un relais UDP, sur ce poste, entre des clients et un
## hôte, qui retarde, mélange et jette les datagrammes d'ENet dans les deux sens :
##   godot --headless --script tests/reseau/relais.gd -- --ecoute=<port> --vers=<port de l'hôte>
##       [--latence=80] [--gigue=40] [--pertes=5] [--graine=1] [--fin=<fichier>] [--duree=<s>]
## Les clients rejoignent 127.0.0.1 sur le port --ecoute ; chacun (adresse et port source) a sa liaison,
## avec son propre port vers l'hôte (127.0.0.1, port --vers). Chaque datagramme part avec un retard
## d'une demi-latence (--latence est l'aller-retour, en ms), plus ou moins une demi-gigue (--gigue : son
## étendue sur chaque aller), tirée au hasard, donc dans un ordre qui peut changer ; ou se perd, avec la
## probabilité --pertes (%). Comme en Wi-Fi : sous ENet, un datagramme fiable perdu est renvoyé (la
## peinture, les réactions, la poignée de main arrivent, en retard) ; un état ou un paquet de commandes
## perdu ne l'est pas (les suivants le remplacent, la redondance des commandes le couvre).
## Écrit « RELAIS PRET » quand il écoute ; s'arrête quand le fichier --fin existe (vérifié toutes les
## 0,1 s) ou au bout de --duree secondes (défaut 300), et écrit « RELAIS datagrammes=… perdus=…
## retard_moyen=… ms liaisons=… ». Aucun autoload n'est nommé ; rien du jeu n'est chargé.
## Hors du test réseau, il sert le contrôle à la main (◉) : un hôte sur son port, un client qui rejoint
## celui du relais.

var _options := {}
var _rng := RandomNumberGenerator.new()
var _latence := 80.0
var _gigue := 40.0
var _pertes := 5.0
var _datagrammes := 0
var _perdus := 0
var _retard_total := 0.0
## Datagrammes en route : `[instant d'envoi (µs), pair de sortie, octets]`.
var _en_route: Array = []


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var morceaux := arg.trim_prefix("--").split("=", true, 1)
		_options[morceaux[0]] = morceaux[1] if morceaux.size() > 1 else "oui"
	call_deferred("_run")


func _run() -> void:
	var ecoute := int(_options.get("ecoute", "0"))
	var vers := int(_options.get("vers", "0"))
	_latence = float(_options.get("latence", "80"))
	_gigue = float(_options.get("gigue", "40"))
	_pertes = float(_options.get("pertes", "5"))
	_rng.seed = int(_options.get("graine", "1"))
	var fin: String = _options.get("fin", "")
	var limite := Time.get_ticks_usec() + int(float(_options.get("duree", "300")) * 1000000.0)
	var serveur := UDPServer.new()
	if ecoute <= 0 or vers <= 0 or serveur.listen(ecoute, "127.0.0.1") != OK:
		printerr("  ❌ relais : --ecoute et --vers requis, port %d libre" % ecoute)
		quit(1)
		return
	print("RELAIS PRET ecoute=%d vers=%d latence=%.0f gigue=%.0f pertes=%.1f" % [ecoute, vers, _latence, _gigue, _pertes])
	var liaisons: Array = []  # [aval (vers le client), amont (vers l'hôte)]
	var controle := 0
	while Time.get_ticks_usec() < limite:
		var maintenant := Time.get_ticks_usec()
		if maintenant >= controle:
			if not fin.is_empty() and FileAccess.file_exists(fin):
				break
			controle = maintenant + 100000
		serveur.poll()
		while serveur.is_connection_available():
			var aval := serveur.take_connection()
			var amont := PacketPeerUDP.new()
			amont.connect_to_host("127.0.0.1", vers)
			liaisons.append([aval, amont])
		for liaison: Array in liaisons:
			var aval: PacketPeerUDP = liaison[0]
			var amont: PacketPeerUDP = liaison[1]
			while aval.get_available_packet_count() > 0:
				_programmer(amont, aval.get_packet(), maintenant)
			while amont.get_available_packet_count() > 0:
				_programmer(aval, amont.get_packet(), maintenant)
		var restants: Array = []
		for datagramme: Array in _en_route:
			if datagramme[0] <= maintenant:
				(datagramme[1] as PacketPeerUDP).put_packet(datagramme[2])
			else:
				restants.append(datagramme)
		_en_route = restants
		OS.delay_usec(250)
	var envoyes := _datagrammes - _perdus
	print("RELAIS datagrammes=%d perdus=%d (%.1f %%) retard_moyen=%.1f ms liaisons=%d" % [_datagrammes, _perdus,
		100.0 * _perdus / maxi(_datagrammes, 1), _retard_total / maxi(envoyes, 1), liaisons.size()])
	serveur.stop()
	quit(0)


## Un datagramme `octets` arrivé à `maintenant` (µs), à faire suivre par `sortie` : retardé, ou perdu.
func _programmer(sortie: PacketPeerUDP, octets: PackedByteArray, maintenant: int) -> void:
	_datagrammes += 1
	if _rng.randf() * 100.0 < _pertes:
		_perdus += 1
		return
	var retard := maxf(0.0, _latence / 2.0 + _rng.randf_range(-_gigue / 2.0, _gigue / 2.0))
	_retard_total += retard
	_en_route.append([maintenant + int(retard * 1000.0), sortie, octets])
```


Dans `.github/workflows/ci.yml`, remplacer :

```yaml
          if grep -nE "SCRIPT ERROR|SHADER ERROR" prediction_test.log; then echo "::error::erreur de script dans le banc de la prédiction"; exit 1; fi

      - name: Test réseau (transport, plusieurs processus sur localhost)
        shell: bash
        run: |
```

par :

```yaml
          if grep -nE "SCRIPT ERROR|SHADER ERROR" prediction_test.log; then echo "::error::erreur de script dans le banc de la prédiction"; exit 1; fi

      - name: Test réseau (plusieurs processus sur localhost, dont une manche sous latence simulée)
        shell: bash
        run: |
```


- [ ] **Step 4 : le test réseau passe, 5 fois sous chaque bash**

Run : `godot --headless --import .`, puis 5 fois de suite `bash tests/reseau/lancer.sh` (bash 5) et 5 fois `/bin/bash tests/reseau/lancer.sh` (bash 3.2), sans relance.
Expected : chaque fois `code 0`, `== 0 échec(s) ==`, 11 lignes ✅ dont « prédiction sous latence simulée (80 ms, 40 ms de gigue, 5 % de pertes) : lion local prédit et recalé, commandes redondantes appliquées une fois, mêmes empreintes chez l'hôte et les clients », et les mesures, par exemple (mesuré) :

```text
  (latence) PREDICTION Anna : erreur max 6.31 px, 11 états sur 708 au-delà de 4 px, 0 au-delà de 16 px ; 0.00 px au plus 150 ms après l'arrêt ; recalages 0 ; à-coups 0 ; rejeu le plus long 11 pas
  (latence) PREDICTION Bruno : erreur max 5.83 px, 4 états sur 723 au-delà de 4 px, 0 au-delà de 16 px ; 0.00 px au plus 150 ms après l'arrêt ; recalages 0 ; à-coups 0 ; rejeu le plus long 10 pas
  (latence) COMMANDES Anna appliquees=1316 sautees=0 numero=1316 file_max=6
  (latence) COMMANDES Bruno appliquees=1317 sautees=0 numero=1317 file_max=5
  (latence) RELAIS datagrammes=9955 perdus=482 (4.8 %) retard_moyen=40.0 ms liaisons=2
```

Mesuré en préparant le plan (10 passages sans relance, 5 sous bash 5 et 5 sous bash 3.2, sur une copie de `origin/phase-15bis-decoupage-lion` avec ce plan appliqué) : 137 à 148 s par passage (~110 s avant la phase ; ~38 s pour le scénario 12). Relais : 4,8 à 4,9 % de datagrammes perdus, 40,0 ms de retard moyen par aller. Par client (20 mesures) : erreur de prédiction maximale de 0 à 110 px (un pas, 5,83 px au plus, dans 13 cas sur 20 ; 53 à 110 px dans 6 cas, quand l'hôte, à l'étroit avec quatre autres processus Godot sur le Mac, rattrape plusieurs ticks d'un coup et répète une commande : une seule glissade vers l'avant, jamais un recalage) ; 0 à 18 états sur ~700 au-delà de 16 px (2,6 % au pire, pour un seuil à 10 %) ; 0,00 px partout 150 ms après l'arrêt ; aucun recalage ; rejeu de 9 à 11 pas. Commandes : 0 à 2 sautées sur ~1 316, file au plus 4 à 6. Le scénario 11 (sans latence, rencontres comprises) écrit aussi la prédiction de chaque client resté : 1 à 3 recalages (les lions que l'hôte déplace pour ses rencontres) et des erreurs de plusieurs centaines de px à ces instants, attendues.

- [ ] **Step 5 : Commit**

```bash
git add tests/reseau/relais.gd tests/reseau/relais.gd.uid tests/reseau/joueur.gd tests/reseau/lancer.sh .github/workflows/ci.yml
git commit -m "Test réseau : simulateur de latence (relais UDP qui retarde, mélange et jette les datagrammes d'ENet) ; scénario 12, une manche à 1 hôte et 2 clients sous 80 ms, 40 ms de gigue et 5 % de pertes (prédiction, commandes appliquées une fois, mêmes empreintes) ; prédiction mesurée au scénario 11 ; l'hôte du scénario 10 efface ses scores ; l'empreinte compte l'étiquette de chaque lion

<ligne fournie par l'environnement>"
```

- [ ] **Step 6 : les suites, 5 fois**

Run : 5 fois de suite chacune des quatre suites Godot (unitaires, smoke, bataille, banc) et la trace, sans relance.
Expected : chaque fois `code 0` et `== 0 échec(s) ==`, aucune `SCRIPT ERROR` ni `SHADER ERROR`, la trace égale à la référence.

Mesuré (5 passages) : unitaires 1 à 2 s, smoke test 19 à 20 s, bataille 3 à 4 s, banc 0 à 1 s (42 lignes ✅), trace 2 à 3 s, égale à la référence à chaque passage.

---

### Task 7 : ◉ la partie à 2 fenêtres sous latence (non commitée)

**Files:**
- Create (scratchpad de l'exécutant, jamais dans le dépôt) : `<scratchpad>/deux_fenetres_latence.gd`

**Interfaces:**
- Consumes : Tasks 1 à 6 (écran Réseau, salon, `Main.lion`, `Lion.prediction` et ses statistiques, le relais).
- Produces : 12 captures PNG dans `<scratchpad>/captures-16/`, montrées à l'utilisateur, et trois mesures (`ORIENTATION`, `CHOC`, `PREDICTION`).

- [ ] **Step 1 : le script**

Créer `<scratchpad>/deux_fenetres_latence.gd` :

```gdscript
extends SceneTree
## ◉ Partie à 2 fenêtres sous latence simulée (phase 16, non commité) : deux vraies fenêtres de jeu sur
## ce Mac, un hôte et un client, le client derrière le simulateur de latence (tests/reseau/relais.gd,
## lancé à part : 80 ms d'aller-retour, 40 ms de gigue, 5 % de pertes) :
##   godot --path <dépôt> --rendering-driver opengl3 --script <ce fichier> -- --role=hote|client --dossier=<dossier>
## Rendu réel (pas headless). L'hôte écoute sur PORT, le client rejoint le relais (PORT_RELAIS) ; l'hôte
## écarte les ennemis (un étourdissement sous latence est couvert par tests/prediction_test.gd). Après
## l'intro, chacun descend vers la ville ; le client fait des demi-tours en vomissant (son lion doit
## se retourner à l'appui, jamais revenir en arrière) puis percute le lion de l'hôte, arrêté (le choc
## doit partir tout de suite). Captures au même instant dans les deux fenêtres (fichiers de
## rendez-vous), et une rafale de 6 captures du client pendant ses demi-tours.

const PORT := 17990
const PORT_RELAIS := 17991
const PORT_BALISE := 18990

var dossier := ""
var role := ""


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dossier="):
			dossier = arg.trim_prefix("--dossier=")
		elif arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	call_deferred("_run")


func _attendre(condition: Callable, secondes := 30.0) -> bool:
	var fin := Time.get_ticks_msec() + int(secondes * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < fin:
		await process_frame
	return condition.call()


func _pause(secondes: float) -> void:
	await create_timer(secondes).timeout


func _scene_est(nom: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == "res://Scenes/%s.tscn" % nom and current_scene.is_node_ready()


func _shot(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var chemin := dossier.path_join("%s_%s.png" % [role, nom])
	image.save_png(chemin)
	print("📸 %s" % chemin)


func _rendez_vous(nom: String) -> void:
	FileAccess.open(dossier.path_join("%s_%s" % [role, nom]), FileAccess.WRITE).store_string("ok")
	var autre := "client" if role == "hote" else "hote"
	await _attendre(func() -> bool: return FileAccess.file_exists(dossier.path_join("%s_%s" % [autre, nom])))


func _presser(action: String, appuyee: bool) -> void:
	if appuyee:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _run() -> void:
	if dossier.is_empty() or not role in ["hote", "client"]:
		printerr("--role=hote|client et --dossier=<chemin>")
		quit(1)
		return
	var reseau: Node = root.get_node("Reseau")
	var decouverte: Node = root.get_node("Decouverte")
	var scores: Node = root.get_node("Scores")
	root.get_node("Parametres").definir_langue("fr")
	scores.chemin = "user://scores_deux_fenetres_%s.cfg" % role
	decouverte.port_balise = PORT_BALISE
	decouverte.destinations_forcees = PackedStringArray(["127.0.0.1"])
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await _pause(0.5)
	DisplayServer.window_set_position(Vector2i(20, 40) if role == "hote" else Vector2i(740, 440))
	DisplayServer.window_set_size(Vector2i(700, 227))
	change_scene_to_file("res://Scenes/EcranReseau.tscn")
	await _attendre(func() -> bool: return _scene_est("EcranReseau"))
	var ecran: Node = current_scene
	ecran.champ_pseudo.text = "Hôte" if role == "hote" else "Invitée"
	if role == "hote":
		ecran.port_jeu = PORT
		ecran.heberger()
	else:
		await _pause(1.0)
		ecran.port_jeu = PORT_RELAIS
		ecran.champ_ip.text = "127.0.0.1"
		ecran.rejoindre_par_ip()
	await _attendre(func() -> bool: return _scene_est("Salon"))
	var salon: Node = current_scene
	if role == "hote":
		await _attendre(func() -> bool: return reseau.table_salon.size() == 2)
	else:
		# Sous latence, la table de l'hôte arrive après l'ouverture du salon : sans sa fiche, le salon
		# ne peut pas encore basculer ce poste prêt.
		await _attendre(func() -> bool: return reseau.table_salon.any(func(f: Dictionary) -> bool: return f.id == root.multiplayer.get_unique_id()))
	salon.basculer_pret()
	await _pause(0.5)
	if role == "hote":
		await _attendre(func() -> bool: return not salon.bouton_demarrer.disabled)
		salon.demarrer()
	await _attendre(func() -> bool: return _scene_est("Main"))
	var main: Node = current_scene
	var gs: Node = root.get_node("GameState")
	await _attendre(func() -> bool: return gs.pret and main.lion != null)
	if role == "hote":
		physics_frame.connect(func() -> void:
			for ennemi in get_nodes_in_group("ennemi") + get_nodes_in_group("boss"):
				ennemi.queue_free())
	var ville: Node2D = main.get_node("Ville")
	var cible: float = ville.position.y - ville.tex_size.y / 2.0 - 233.0
	_presser("deplacer_bas", true)
	await _attendre(func() -> bool: return main.lion.position.y >= cible, 5.0)
	_presser("deplacer_bas", false)
	if role == "hote":
		# L'hôte se gare à gauche du client, puis l'attend
		var garage := func() -> bool:
			var ecart: float = 800.0 - main.lion.position.x
			_presser("deplacer_droite", ecart > 10.0)
			_presser("deplacer_gauche", ecart < -10.0)
			return absf(ecart) <= 10.0
		await _attendre(garage, 5.0)
		_presser("deplacer_droite", false)
		_presser("deplacer_gauche", false)
		await _rendez_vous("gare")
		await _rendez_vous("demi_tours")
		await _shot("1_demi_tours")
		await _rendez_vous("choc")
		await _pause(0.05)
		await _shot("2_choc")
		await _pause(1.5)
		await _rendez_vous("repos")
		await _shot("3_repos")
		await _rendez_vous("fin")
		reseau.quitter()
		await _pause(0.5)
	else:
		var prediction: Node = main.lion.prediction
		# Des demi-tours en vomissant, à sa place (à droite de l'hôte) : le lion doit se retourner à l'appui
		await _rendez_vous("gare")
		prediction.remettre_statistiques()
		var retournements := [0, 0]  # ticks physiques où le lion regarde à l'opposé de la touche tenue, ticks vus
		var sens := [1]
		var suivre := func() -> void:
			retournements[1] += 1
			if main.lion.direction_du_lion != sens[0]:
				retournements[0] += 1
		physics_frame.connect(suivre)
		_presser("vomir", true)
		for i in range(6):
			sens[0] = 1 if i % 2 == 0 else -1
			_presser("deplacer_droite", sens[0] > 0)
			_presser("deplacer_gauche", sens[0] < 0)
			await process_frame  # le sens change à la prochaine image physique
			await _pause(0.45)
			if i == 3:
				await _rendez_vous("demi_tours")
				await _shot("1_demi_tours")
				for k in range(6):
					await _pause(0.05)
					await _shot("1_rafale_%d" % k)
		physics_frame.disconnect(suivre)
		_presser("vomir", false)
		print("ORIENTATION %d tick(s) sur %d où le lion regarde à l'opposé de la touche tenue (6 demi-tours)" % retournements)
		# Le choc : droit sur le lion garé de l'hôte, à sa gauche
		_presser("deplacer_droite", false)
		_presser("deplacer_gauche", true)
		var hote_lion: Node2D = null
		for l: Node2D in main.lions:
			if l != main.lion:
				hote_lion = l
		await _attendre(func() -> bool: return main.lion.deplacement.recul.x > 0.0 and main.lion.position.distance_to(hote_lion.position) < 150.0, 8.0)
		_presser("deplacer_gauche", false)
		await _rendez_vous("choc")
		await _pause(0.05)
		await _shot("2_choc")
		print("CHOC simulé ici, écart au lion de l'hôte affiché %.0f px" % main.lion.position.distance_to(hote_lion.position))
		await _pause(1.5)
		await _rendez_vous("repos")
		await _shot("3_repos")
		print("PREDICTION erreur max %.2f px, %d états au-delà de 4 px sur %d ; recalages %d ; rejeu le plus long %d pas"
			% [prediction.erreur_max(), prediction.erreurs_au_dela(4.0), prediction.etats_depuis(1), prediction.recalages, prediction.rejeu_max])
		await _rendez_vous("fin")
		await _attendre(func() -> bool: return _scene_est("Titre"), 8.0)
	scores.effacer()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))
	quit(0)
```


- [ ] **Step 2 : les captures**

Run (le relais d'abord, puis l'hôte, puis le client ; deux fenêtres s'ouvrent le temps du script) :

```bash
export PATH="/opt/homebrew/bin:$PATH"; S=<scratchpad>; rm -rf $S/captures-16; mkdir -p $S/captures-16
(timeout -k 5 150 godot --headless --script tests/reseau/relais.gd -- --ecoute=17991 --vers=17990 --latence=80 --gigue=40 --pertes=5 --fin=$S/captures-16/fin > "$TMPDIR/f_relais.log" 2>&1 &)
(timeout -k 5 120 godot --path . --rendering-driver opengl3 --script $S/deux_fenetres_latence.gd -- --role=hote --dossier=$S/captures-16 > "$TMPDIR/f_hote.log" 2>&1 &)
sleep 2; timeout -k 5 120 godot --path . --rendering-driver opengl3 --script $S/deux_fenetres_latence.gd -- --role=client --dossier=$S/captures-16 > "$TMPDIR/f_client.log" 2>&1; echo "code $?"
touch $S/captures-16/fin; sleep 1; grep -hE "SCRIPT ERROR|❌|ORIENTATION|CHOC|PREDICTION|RELAIS d" "$TMPDIR/f_relais.log" "$TMPDIR/f_hote.log" "$TMPDIR/f_client.log"; ls $S/captures-16/*.png | wc -l
```

Expected (mesuré) : `code 0`, 12 captures, aucune `SCRIPT ERROR`, et :

```text
RELAIS datagrammes=2029 perdus=118 (5.8 %) retard_moyen=40.2 ms liaisons=1
ORIENTATION 5 tick(s) sur 188 où le lion regarde à l'opposé de la touche tenue (6 demi-tours)
CHOC simulé ici, écart au lion de l'hôte affiché 101 px
PREDICTION erreur max 11.67 px, 4 états au-delà de 4 px sur 209 ; recalages 0 ; rejeu le plus long 11 pas
```

(ORIENTATION : au plus un tick par demi-tour, le temps que la touche soit lue ; un lion remis dans l'ancien sens par l'hôte en compterait cinq à huit par demi-tour.)

- [ ] **Step 3 : regarder, puis montrer à l'utilisateur**

Vérifier sur les images (constaté en préparant le plan) :
- `client_1_demi_tours` et `client_1_rafale_0` à `_5` : le lion bleu « Invitée » vomit, tourné du côté de sa course dans chaque capture ; `hote_1_demi_tours` : le même instant vu de l'hôte (le lion du client un peu en retard, normal : 40 ms d'aller et le retard de l'interpolation ne jouent que chez l'autre) ;
- `client_2_choc` et `hote_2_choc` (**◉ partie à 2 fenêtres sous latence**) : les deux lions au contact, à la même place dans les deux fenêtres, à quelques pixels près ;
- `client_3_repos` et `hote_3_repos` : les mêmes positions, la même peinture.

Montrer au moins `client_1_rafale_*`, `client_2_choc`, `hote_2_choc` et les trois lignes mesurées à l'utilisateur, **et lui proposer de rejouer à la main** (le relais lancé seul, `--duree=600`, puis un hôte et un client par l'écran Réseau, le client rejoignant `127.0.0.1` sur le port du relais : `ecran.port_jeu` n'est réglable que par script, d'où ce script ; à défaut, deux fenêtres `godot --path .` et le port 7777 sans latence). Rien à commiter.

---

### Task 8 : feuille de route et spec

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`

**Interfaces:**
- Consumes : Tasks 1 à 7, Écarts 1 à 15 ; la feuille de route telle que la phase 15 bis l'a laissée.
- Produces : ligne 16 faite ; plus aucun point de vigilance « phase 16 » ouvert (chacun résolu, ou réaffecté avec sa raison : l'affichage d'un client qui perd l'hôte à la phase 19, avec les captures) ; nouveaux points (essai sur la LAN à refaire avec la prédiction, phase 19 ; temps de la CI pour la prochaine phase qui ajoute un scénario) ; spec §1, §3.1, §3.2, §4, §4.1, §10, §13 à jour.

- [ ] **Step 1 : la feuille de route**

1a. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
| 16 | **Prédiction du lion local** (4 bis), après le découpage de `Lion.gd` (étape à part, voir les points de vigilance) : correction douce, commandes redondantes (la phase 14 les numérote déjà), numéro de la dernière commande traitée répliqué, interpolation, simulateur de latence. | ➕ `Scripts/PredictionLocale.gd` ✏️ `Scripts/Reseau.gd` ✏️ `Scripts/Manche.gd` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Lion.gd` ✏️ `tests/reseau/joueur.gd` | test vert sous 80 ms / 40 ms / 5 % |
```

par :

```text
| 16 | **Prédiction du lion local** (4 bis) : sur un client, le lion local avance tout de suite (`PredictionLocale`, par `Lion.avancer`), se recale sur chaque état neuf de l'hôte et rejoue les commandes que l'hôte n'a pas encore appliquées (avec ses chocs simulés), décalage d'affichage amorti en 120 ms, recalage immédiat au-delà de 200 px ; commandes lues une fois par tick, numérotées, envoyées avec les 3 précédentes, appliquées par l'hôte une par tick dans l'ordre, jamais deux fois (`Commandes` : file) ; un seul état répliqué par lion (`Lion.etat_reseau`, `EtatLion` : instant, dernière commande appliquée, position, vitesse commandée, recul, orientation) ; lions distants interpolés avec 100 ms de retard (`InterpolationLion`) ; simulateur de latence en relais UDP (`tests/reseau/relais.gd`) ; banc de la prédiction dans un seul processus (`tests/prediction_test.gd`, en CI) ; scénario 12 du test réseau sous 80 ms / 40 ms / 5 % ; version 0.16. `Scripts/Reseau.gd` inchangé. | ➕ `Scripts/PredictionLocale.gd` ➕ `Scripts/EtatLion.gd` ➕ `Scripts/InterpolationLion.gd` ➕ `tests/prediction_test.gd` ➕ `tests/reseau/relais.gd` ✏️ `Scripts/Commandes.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scripts/PareChocs.gd` ✏️ `Scenes/Lion.tscn` ✏️ `Scripts/Manche.gd` ✏️ `Scripts/Main.gd` ✏️ `project.godot` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/reseau/joueur.gd` ✏️ `tests/reseau/lancer.sh` ✏️ `.github/workflows/ci.yml` | trace inchangée, banc et scénario 12 verts sous 80 ms / 40 ms / 5 %, suites vertes 5 fois, test réseau vert 5 fois (bash 3.2 et 5), ◉ partie à 2 fenêtres sous latence |
```


1b. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
- Phase 16 : `PredictionLocale` lit Input une seule fois par tick physique, l'écrit dans les
  commandes MANUELLES du lion local et envoie exactement cette valeur, numérotée (direction et
  vomir échantillonnés au même tick). La prédiction locale doit appliquer la même borne
  `Lion._marge_haute()` que l'hôte (phase 10 ter) ; cela ne tient que si la visibilité de
  l'étiquette (couleur et pseudo du joueur) est identique sur chaque machine. Depuis la phase 14,
  c'est `Manche._envoyer_commandes` qui envoie, à chaque tick physique (priorité 100, après les
  lions), les commandes du lion de ce poste (`LOCALES`) : `PredictionLocale` doit écrire avant
  (priorité plus basse) et `Manche` envoyer ce qu'elle a écrit, avec les 3 précédentes (le numéro
  existe déjà, `Manche._numero`, et l'hôte ignore un numéro déjà vu) ;
```

par :

```text
- (résolu en phase 16) `PredictionLocale` (priorité -10) lit les actions de ce poste une seule fois
  par tick physique (direction et vomir au même tick), les numérote, les écrit dans les commandes
  manuelles du lion local et les garde ; `Manche._envoyer_commandes` (priorité 100) envoie ce paquet
  (`PredictionLocale.paquet` : la commande et les 3 précédentes). La prédiction passe par
  `Lion.avancer`, donc par la même borne `Lion._marge_haute()` que l'hôte ; l'étiquette est visible
  sur chaque poste au même titre (la même table des joueurs) : l'empreinte du test réseau la compte ;
```


1c. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
- (résolu en phase 14) sans commande d'un client depuis `Manche.SILENCE_COMMANDES` (500 ms), l'hôte
  remet son lion au repos (`Manche.verifier_silences`). **Phase 16** : garder ce délai au-dessus de
  la latence simulée (80 ms + 40 ms de gigue) ;
```

par :

```text
- (résolu en phases 14 et 16) sans paquet de commandes d'un client depuis `Manche.SILENCE_COMMANDES`
  (500 ms), l'hôte remet son lion au repos et vide sa file (`Commandes.remettre_au_repos`) ; le délai
  reste bien au-dessus de la latence simulée (40 ms ± 20 ms par aller) et de trois paquets perdus de
  suite, que la redondance couvre ;
```


1d. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
- **phase 16** (temps de la CI, depuis la phase 15) : le test réseau prend ~110 s, dont ~52 s pour
  le scénario 11 (la manche entière de 45 s, `DUREE11` dans `tests/reseau/lancer.sh` : décision de
  l'utilisateur, pas 90 s, pour garder la marge sous le `timeout 300` du pas « Test réseau » de
  `ci.yml`) ; le test sous latence simulée de la phase 16 doit tenir dans ce qui reste (ou
  raccourcir encore `DUREE11`, ou relever ce `timeout` dans `ci.yml`) ;
```

par :

```text
- **prochaine phase qui ajoute un scénario au test réseau** (temps de la CI, phase 16) : le test
  réseau prend ~150 s sur ce Mac, dont ~52 s pour le scénario 11 (`DUREE11=45`, décision de
  l'utilisateur) et ~38 s pour le scénario 12 (la manche sous latence simulée, `DUREE12=20`), sous le
  `timeout 300` du pas « Test réseau » de `ci.yml` ; le banc de la prédiction (`tests/prediction_test.gd`)
  a son propre pas, ~1 s. Au-delà de ~200 s, raccourcir un scénario ou relever ce `timeout` ;
```


1e. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
- (phase 14) sur un client, aucun lion ne se déplace de lui-même (`Lion._suivre_l_hote`) : position,
  vitesse, orientation et vomi viennent du `Synchro` du lion (`velocity` comprise, que lit le calcul
  d'approche des chocs) ; chaque réplique garde ses réactions visuelles (secousse du pare-chocs,
  étoiles, barbouillage, clignotement). **Phase 16** : seul le lion local reprend son pas de
  déplacement (`Lion.avancer` : `DeplacementLion`, `PareChocs.bloquer`, `move_and_slide`, bords de
  l'écran, phase 15 bis), par sa prédiction ; les lions distants sont interpolés
  (le `Synchro` réplique à 83 Hz au plus, `replication_interval` 0,012 s, sans interpolation en
  phase 14) ;
```

par :

```text
- (résolu en phase 16) sur un client, un lion distant ne se déplace pas de lui-même : il est interpolé
  entre les états reçus avec 100 ms de retard (`Lion._suivre_l_hote`, `InterpolationLion` ; sa
  `velocity`, que lit le calcul d'approche des chocs, est la vitesse interpolée) et garde ses réactions
  visuelles ; seul le lion local reprend son pas de déplacement (`Lion.avancer`), par sa prédiction.
  Le `Synchro` réplique un seul état par lion (`Lion.etat_reseau`, 33 octets, au plus toutes les
  0,012 s) et le vomi ;
```


1f. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
  présentation et la réplication. **Phase 16** : garder `Lion.avancer` comme seul pas du déplacement
  (l'hôte et la prédiction) ; `recul` et `vitesse` sont aussi modifiés par les réactions
  (`_on_etourdi`, `_on_lion_touche`) et par le pare-chocs (`PareChocs._on_area_entered`), pas
  seulement par `avancer`. Sur un client, `deplacement` n'est pas un état fiable : `vitesse` y reçoit
  la vitesse totale de l'hôte (commandée, recul et blocage confondus, après le bornage), pas la
  vitesse commandée, et `recul` ne s'amortit jamais (`vitesse_du_pas` ne tourne que sur l'hôte). À
  chaque (re)prise de la prédiction, remettre `deplacement.recul` à zéro et repartir d'une `vitesse`
  cohérente (commandée, pas la `velocity` reçue de l'hôte), sous peine d'appliquer un recul ou une
  vitesse fantôme déjà joués par l'hôte. Repasser `tests/trace_lions.gd` avant et après chaque
  modification du lion (deux passages consécutifs identiques ; les deux premiers après un import
  peuvent différer, phase 15 bis, Écart 6 — cause non établie, voir plus bas) ;
```

par :

```text
  présentation et la réplication. (Résolu en phase 16) `Lion.avancer` reste le seul pas du
  déplacement (l'hôte et la prédiction). Le lion local d'un client part d'un déplacement neutre
  (`PredictionLocale._ready`), puis repart à chaque état de l'hôte de sa vitesse commandée et de son
  recul, répliqués tels quels (`EtatLion`), jamais de sa `velocity` : aucune vitesse ni aucun recul
  fantôme. Les réactions décidées par l'hôte (étourdissement, recul) arrivent dans ses états, jamais
  rejouées par le client ; seuls ses chocs simulés le sont (`PareChocs.choc_simule`). Repasser
  `tests/trace_lions.gd` avant et après chaque modification du lion (deux passages consécutifs
  identiques ; les deux premiers après un import peuvent différer, phase 15 bis, Écart 6) : la
  phase 16 l'a laissée identique (bataille, solo, réplique) ;
```


1g. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
- **phase 16** (vu en phase 15 bis) : `avancer(direction, delta)` n'utilise son `delta` que pour la
  vitesse commandée ; `move_and_slide()` intègre, lui, avec le delta du moteur (le delta physique
  dans une image physique, le delta de traitement en dehors). Un rejeu de prédiction hors d'une
  image physique (le signal `synchronized` du `MultiplayerSynchronizer` et les RPC arrivent pendant
  le `poll` multijoueur, donc en image de traitement) déplace le lion d'un facteur
  `delta traitement / delta physique` à chaque pas rejoué — une dérive silencieuse, sans erreur, que
  la correction douce masquera en partie et qu'on attribuera à tort à la latence. Poser en phase 16
  un garde-fou peu coûteux en tête de `avancer` : `if not Engine.is_in_physics_frame(): push_error(...)`.
  Noter aussi que `pare_chocs.bloquer()` ne rejoue pas des contacts passés (il ne lit que l'état
  physique et les positions actuelles au moment de l'appel), donc plusieurs pas rejoués dans une même
  image voient tous les mêmes contacts, ceux du présent ;
```

par :

```text
- (résolu en phase 16) les états de l'hôte arrivent pendant le sondage réseau : le setter de
  `Lion.etat_reseau` ne fait que les garder, et la prédiction ne rejoue qu'au tick physique suivant ;
  `Lion.avancer` refuse un pas hors d'une image physique (`push_error`, le lion ne bouge pas : ligne
  `ERROR` attendue du smoke test). Pendant un rejeu (`PareChocs.en_rejeu`), `bloquer` ne compte un
  contact présent qu'aux positions rejouées où les pare-chocs se touchent (mesuré au banc : sans
  cela, un choc laisse 46,7 px d'erreur et un aller-retour de 16,4 px de l'affichage ; avec, 0,6 px et
  aucun) ;
```


1h. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
- **phase 16** (vu en phase 15 bis) : `direction_du_lion` est une propriété répliquée (mode « au
  changement ») dont l'hôte fait foi. Un client qui prédit son lion et retourne son sprite à l'appui
  de la touche le verra remis dans l'autre sens par chaque état en retard de l'hôte : sprite, bouche
  et gerbe clignotent à chaque demi-tour, le temps d'un aller-retour réseau. À traiter en phase 16 :
  soit ne plus répliquer l'orientation vers le lion local, soit ignorer l'orientation reçue tant que
  la prédiction est active ;
```

par :

```text
- (résolu en phase 16) l'orientation n'est plus répliquée à part : elle voyage dans l'état de
  l'hôte, avec la position et la dernière commande appliquée (`EtatLion`) ; le lion local la reprend
  de l'état au recalage puis la refait en rejouant ses commandes (aucun clignotement : ◉, un tick par
  demi-tour, le temps que la touche soit lue), un lion distant la prend de ses états interpolés ;
```


1i. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
  (spec §4.1) doit absorber ces écarts, et les tests de prédiction mesurer des écarts de position, pas
  des égalités ;
```

par :

```text
  (spec §4.1) doit absorber ces écarts, et les tests de prédiction mesurer des écarts de position, pas
  des égalités. (Résolu en phase 16 : le banc et le scénario 12 mesurent l'erreur de prédiction, la
  position de l'hôte après chaque commande accusée comparée à celle que le client avait prédite au tick
  où il l'a lue ; seules les empreintes de fin de manche, lions au repos, sont des égalités : le client
  y reprend exactement l'état de l'hôte) ;
```


1j. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
- **phase 16** : seul le lion local simule son choc, par sa propre prédiction
  (`PareChocs._on_area_entered` : recul, secousse ; phase 15 bis) ; un lion distant ne simule jamais de
  choc localement (voir le point de la phase 14 ci-dessus), il ne fait que rejouer la réaction
  visuelle reçue. Seul l'hôte signale le choc aux règles ; l'étourdissement, lui, ne vient que
  des règles de l'hôte (`Joueur.etourdir`) : `PredictionLocale` suspend la prédiction tant que
  `joueur.est_etourdi()` (spec §4.1) ;
```

par :

```text
- (résolu en phase 16) seul le lion local simule son choc (`PareChocs._on_area_entered` : recul,
  blocage, secousse), contre les lions affichés ; le choc part en signal (`PareChocs.choc_simule`), la
  prédiction le note au tick où il arrive et le rejoue tant que l'hôte ne l'a pas. Un lion distant
  ne fait que secouer son sprite (sa position vient de l'hôte). Seul l'hôte signale le choc aux
  règles. Pendant un étourdissement, la prédiction applique la règle de l'hôte (`Lion.direction_pour` :
  commandes ignorées) à ses pas comme à ses rejeux : le lion suit l'hôte (banc : 0 px d'erreur une fois
  l'étourdissement connu ; environ 14 px à sa fin, qui arrive avec un aller de retard, absorbés par la
  correction douce) ;
```


1k. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
- **phase 16** (revue de la phase 14) : chez un client qui perd l'hôte, le moteur fait disparaître
  les nœuds apparus par le `MultiplayerSpawner` (lions, ennemis, pastilles) : le message s'affiche
  sur une ville sans lions (vu sur la capture ◉) ; sans conséquence, la scène revient au titre ;
```

par :

```text
- **phase 19** (captures ; revue de la phase 14, vérifié en phase 16) : chez un client qui perd
  l'hôte, le moteur fait disparaître les nœuds apparus par le `MultiplayerSpawner` (lions, ennemis,
  pastilles) : le message s'affiche sur une ville sans lions. Sans conséquence pour la prédiction
  (enfant du lion, elle part avec lui ; `Manche._envoyer_commandes` vérifie qu'elle existe encore) ni
  pour le jeu (retour au titre) ; seulement visuel, à revoir avec les captures ;
```


1l. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
- **prochaine phase qui touche `tests/reseau/lancer.sh`** (vu en phase 15) : le scénario 10 arrête
  ses postes par `tuer`, l'hôte n'efface donc pas `user://scores_reseau_Hote10.cfg` (fichier vide de
  test laissé dans les données utilisateur) ; l'effacer comme le fait l'hôte du scénario 11 pour le
  poste arraché ;
```

par :

```text
- (résolu en phase 16) l'hôte du scénario 10 efface ses scores de test avant d'écrire la mesure
  qui le fait arrêter (`ECART_EXCLUSION`) ;
```


1m. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
  l'augmenter (« 0.14 »…) ; sinon un `.exe` de CI (Windows) et une version locale (Mac) de phases
```

par :

```text
  l'augmenter (« 0.14 », « 0.16 »…) ; sinon un `.exe` de CI (Windows) et une version locale (Mac) de phases
```


1n. Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`, remplacer :

```text
- **phase 17 bis** (sons de bataille, depuis la phase 8 bis) : chaque lion, local ou non, appelle
```

par :

```text
- **phase 19** (essai sur la LAN, phase 16) : avant la prédiction, l'utilisateur a joué une manche à 3
  sous Windows en Wi-Fi et trouvé que les commandes « suivent plutôt bien ». Refaire cet essai avec
  l'`.exe` de la phase 16 : si le lion local paraît élastique, régler `PredictionLocale.DUREE_CORRECTION`
  (0,04 s) ; si les lions distants saccadent, `InterpolationLion.RETARD` (6 ticks) ; le relais
  (`tests/reseau/relais.gd`, `--gigue=100`, `--pertes=10`) reproduit un Wi-Fi plus mauvais sur ce Mac.
  Les chocs contre un lion distant qui bouge sont prédits contre sa position affichée, en retard de
  ~140 ms (100 ms d'interpolation et l'aller) : l'hôte fait foi, l'écart se résorbe en glissant
  (spec §13) ;
- **phase 17 bis** (sons de bataille, depuis la phase 8 bis) : chaque lion, local ou non, appelle
```


Vérifier : `grep -n "phase 16\*\*\|Phase 16\*\*\|Phase 16 :" docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` ne trouve plus aucun point ouvert (seulement des « (résolu en phase 16) » et des mentions historiques).

- [ ] **Step 2 : la spec**

2a. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```text
- Rembobinage avec rejeu des commandes (le lion local est prédit avec une correction douce, voir
  4.1) et prédiction des lions distants (ils sont interpolés).
```

par :

```text
- Rembobinage du monde (autres lions, ennemis : seul le lion local d'un client repart du dernier
  état de l'hôte et rejoue ses propres commandes, voir 4.1) et prédiction des lions distants (ils
  sont interpolés).
```


2b. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```text
| `Commandes` (RefCounted) | Interface `direction() -> Vector2`, `vomir() -> bool`. Deux sources : `LOCALES` (actions InputMap de ce poste) et `MANUELLES` (valeurs écrites par un tiers : pilote de l'attract mode, tests, et côté hôte les commandes reçues d'un client, numérotées et dédoublonnées en phase 16). | Input |
| `PredictionLocale` (Node) | Sur un client, simule le lion local sans attendre l'hôte et le recale en douceur sur l'état autoritaire (voir 4.1). Absent chez l'hôte et en solo. | `Lion`, `Reseau` |
```

par :

```text
| `Commandes` (RefCounted) | Interface `direction() -> Vector2`, `vomir() -> bool`. Deux sources : `LOCALES` (actions InputMap de ce poste) et `MANUELLES` (valeurs écrites par un tiers : pilote de l'attract mode, tests, prédiction du lion local d'un client, et côté hôte les commandes reçues d'un client). Depuis la phase 16, le format des paquets de commandes (la dernière et les 3 précédentes, numérotées) et, chez l'hôte, la file des commandes d'un client : une appliquée par tick, dans l'ordre, jamais deux fois. | Input |
| `PredictionLocale` (Node, phase 16) | Sur un client, enfant du lion local : lit les actions de ce poste une fois par tick, les numérote, fait avancer le lion tout de suite par `Lion.avancer`, se recale sur chaque état neuf de l'hôte en rejouant les commandes qu'il n'a pas encore appliquées, et lisse l'écart à l'affichage (voir 4.1). Absent chez l'hôte et en solo. | `Lion`, `Commandes` |
| `EtatLion`, `InterpolationLion` (logique pure, phase 16) | L'état d'un lion au format réseau (instant de l'hôte, dernière commande appliquée, position, vitesse commandée, recul, orientation : 33 octets) ; l'affichage d'un lion distant, interpolé entre ses états avec 100 ms de retard. | rien |
```


2c. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```text
5. `MultiplayerSynchronizer` réplique position, vitesse, orientation et état de vomi de chaque lion
   (phase 14, à 83 Hz au plus : environ 15 Ko/s par client à 6 lions, mesurés ; les crans passent en
   événement avec les autres réactions du joueur) ; le numéro de la dernière commande traitée s'y
   ajoute en phase 16, quand les clients interpolent les lions distants et recalent leur lion
   local (4.1).
```

par :

```text
5. `MultiplayerSynchronizer` réplique l'état de chaque lion (phase 16 : un seul champ,
   `Lion.etat_reseau` : instant de l'hôte, numéro de la dernière commande appliquée, position, vitesse
   commandée, recul, orientation, 33 octets, à 83 Hz au plus) et son état de vomi (les crans passent
   en événement avec les autres réactions du joueur) ; les clients y interpolent les lions distants
   et y recalent leur lion local (4.1).
```


2d. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```text
- **Redondance des commandes** : chaque paquet de commandes porte la commande courante et les 3
  précédentes (numérotées). L'hôte ignore les numéros déjà vus : un paquet Wi-Fi perdu ne fait
  pas sauter le lion.
- **Interpolation** : les lions distants sont affichés avec un tampon d'environ 2 envois
  (≈ 50 ms), pour lisser la gigue.
```

par :

```text
- **Redondance des commandes** : chaque paquet de commandes porte la commande courante et les 3
  précédentes (numérotées). L'hôte ignore les numéros déjà vus : un paquet Wi-Fi perdu ne fait
  pas sauter le lion. Il met chaque commande neuve dans une file et en applique une par tick,
  dans l'ordre (8 au plus en attente : au-delà, les plus anciennes sont sautées).
- **Interpolation** : les lions distants sont affichés avec 100 ms de retard (6 ticks), interpolés
  entre les états reçus : plus que la gigue (40 ms) et deux états perdus de suite.
```


2e. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```text
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
```

par :

```text
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
```


2f. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```text
- **Tests de prédiction** : un lion prédit sans pertes reste à moins de 4 px de l'hôte ; avec
  80 ms de latence, 40 ms de gigue et 5 % de pertes, l'écart converge sous 4 px en 150 ms après
  l'arrêt des commandes, et aucune commande n'est appliquée deux fois par l'hôte.
```

par :

```text
- **Tests de prédiction** : un lion prédit sans pertes reste à moins de 4 px de l'hôte ; avec
  80 ms de latence, 40 ms de gigue et 5 % de pertes, l'écart converge sous 4 px en 150 ms après
  l'arrêt des commandes, et aucune commande n'est appliquée deux fois par l'hôte. Depuis la phase 16 :
  le banc de la prédiction (`tests/prediction_test.gd`, en CI, `--fixed-fps 60`) met l'hôte et un
  client dans un seul processus, chacun dans son monde, reliés par des lignes à retard semées
  (parcours sans latence puis sous 80/40/5, étourdissement décidé par l'hôte, choc contre un lion
  distant, écarts imposés par l'hôte, hôte figé) ; le scénario 12 du test réseau joue une manche à
  1 hôte et 2 clients derrière le relais (80/40/5) : aucun recalage, erreur rarement au-delà de 16 px,
  sous 4 px 150 ms après l'arrêt, aucune commande appliquée deux fois, même empreinte partout.
```


2g. Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`, remplacer :

```text
- **Correction visible** si l'hôte et le client divergent souvent (chocs en chaîne) : la
  correction douce peut donner un léger effet élastique. Accepté ; seuils réglables.
```

par :

```text
- **Correction visible** si l'hôte et le client divergent souvent (chocs en chaîne) : la
  correction douce peut donner un léger effet élastique. Accepté ; seuils réglables
  (`PredictionLocale.DUREE_CORRECTION`, `SEUIL_RECALAGE`, `InterpolationLion.RETARD`). Un choc contre
  un lion distant qui bouge est prédit contre sa position affichée, en retard d'environ 140 ms
  (interpolation et aller) : l'hôte fait foi, l'écart se résorbe en glissant.
```


- [ ] **Step 3 : Commit**

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md
git commit -m "Feuille de route et spec : phase 16 faite (prédiction du lion local avec rejeu et correction douce, commandes redondantes en file, état répliqué d'un seul tenant, interpolation des lions distants, simulateur de latence, banc et scénario 12) ; points de vigilance de la phase 16 résolus ou réaffectés ; essai LAN à refaire (phase 19)

<ligne fournie par l'environnement>"
```

---

## Sortie de phase

- La trace égale à la référence après les Tasks 1, 3, 4, 5 et en fin de phase ; les cinq suites vertes 5 fois de suite, le test réseau vert 5 fois sous bash 5 et 5 fois sous bash 3.2, sans `SCRIPT ERROR` ni `SHADER ERROR`, puis le job CI vert sur la PR (pas « Banc de la prédiction » compris, pas « Test réseau » sous son `timeout 300`).
- Les mutations M1 à M5, M7 et M8 ont donné les `❌` attendus.
- `git diff main --stat` : les 17 fichiers des Global Constraints, les cinq `.uid`, la spec et la feuille de route ; `git diff main --stat -- Scripts/Reseau.gd tests/trace_lions.gd tests/bataille_test.gd` vide ; `grep -c "config/version=\"0.16\"" project.godot` : 1.
- ◉ montré à l'utilisateur (Task 7), avec la proposition d'un essai à la main sous latence.
- Rappeler à l'utilisateur : l'essai Windows en Wi-Fi est à refaire avec l'`.exe` de cette phase (nouveau point de vigilance, phase 19) ; les réglages de la correction (`DUREE_CORRECTION`) et de l'interpolation (`RETARD`) sont des constantes à ajuster sur son ressenti.
