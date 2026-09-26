# Phase 15 bis : le découpage de `Lion.gd` (déplacement, pare-chocs, gerbe), à comportement identique, plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Scripts/Lion.gd` (542 lignes, 37 fonctions) est découpé en trois composants cohérents, **sans rien changer au comportement** du solo, de la bataille locale ni du réseau, et prépare la prédiction du lion local (phase 16) : un pas de déplacement unique et nommé (`Lion.avancer(direction, delta)`) dont l'état (vitesse commandée, recul) vit dans un objet de logique pure (`DeplacementLion`) que les tests unitaires nomment et que la prédiction pourra rejouer. La preuve de l'identité : un outil de trace (`tests/trace_lions.gd`) qui rejoue tick par tick une bataille à 4 lions, une partie solo et une réplique de client, et dont l'empreinte reste celle d'avant le découpage après chaque tâche ; les quatre suites vertes 5 fois, le test réseau de bout en bout (scénario 11) vert 5 fois sous bash 3.2 et 5.

**Architecture:** trois composants, un par responsabilité, et un lion qui orchestre :
- `DeplacementLion` (`Scripts/DeplacementLion.gd`, `RefCounted`, logique pure, `class_name`) : vitesse commandée et recul (`vitesse_du_pas`, `arreter`, `repousser`) ; le lion en tient un (`Lion.deplacement`) et en fait un pas par tick physique sur l'hôte dans `Lion.avancer` (orientation, vitesse, `pare_chocs.bloquer`, `move_and_slide`, bords de l'écran) : le seul chemin du déplacement ;
- `PareChocs` (`Scripts/PareChocs.gd`, script du nœud `PareChocs` existant, `class_name`) : les auto-tamponneuses (choc au premier contact, délai anti-rafale, signalement aux règles sur l'hôte, `bloquer` pendant le contact) et leurs quatre réglages exportés ;
- `GerbeLion` (`Scripts/GerbeLion.gd`, script d'un nouveau nœud `Gerbe` posé à l'origine du lion, `class_name`) : émetteurs, traceuse de peinture et zones de contact (créées sous lui), orientation, taille XXL, départ et arrêt, signalement des lions touchés ; ses nœuds (bouche, émetteurs, traceuse) lui sont donnés par la scène (propriétés exportées).
`Lion` garde son joueur et ses commandes, les propriétés répliquées, l'écoute des signaux de son joueur (qu'il répartit entre les composants), le vomi (état, animation, son) et la présentation (teinte, pseudo, étoiles, barbouillage, clignotement, secousse, trot) : 320 lignes. Aucun nœud existant n'est renommé ni déplacé (le `Synchro`, `GerbeTraceuse.gd` et le test réseau lisent la scène par ses noms).

**Tech Stack:** Godot 4.7.2, GDScript typé (`class_name`, propriétés `@export` de type nœud avec `node_paths` dans la scène), tests headless (`tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd`, `tests/reseau/lancer.sh` + `tests/reseau/joueur.gd`), nouvel outil `tests/trace_lions.gd` (`--fixed-fps 60`).

**Spec:** `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` (§3.1 unités : `Lion`, `PredictionLocale` ; §4.1 prédiction : « exactement le même code de déplacement que l'hôte » ; §5 lion : gerbe, traceuses, étourdissement, collisions ; §10 tests) · feuille de route : `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` (point « avant la phase 16, après la 15 » : le découpage ; points « phase 16 » qui nomment `_recul`, `_bloquer_contre_les_lions`, `Lion._on_pare_chocs_area_entered` ; point « phase 17 bis » du « boing ») · plan précédent : `docs/superpowers/plans/2026-09-26-phase-15-bout-en-bout.md` (le scénario 11, le filet réseau) · prérequis : **phase 15 fusionnée** ; nouvelle branche `phase-15bis-decoupage-lion` depuis `main`.

## Écarts assumés

1. **Une phase à part (15 bis), pas un morceau de la 15** : la feuille de route le demande (« en une étape à part ») ; le test de bout en bout de la phase 15, fusionné avant, en est le filet. Fichiers : 3 scripts neufs et l'outil de trace (et leurs `.uid`), `Lion.gd`, `Lion.tscn`, deux commentaires (`GerbeTraceuse.gd`, `Manche.gd`), trois fichiers de test, la spec et la feuille de route.
2. **Trois composants, pas quatre** : la présentation (teinte, pseudo, étoiles, barbouillage, clignotement, secousse, trot, ~110 lignes) reste dans `Lion` : elle ne sert qu'au lion, les tests la lisent par dizaines (`sprite`, `etoiles`, `etiquette_pseudo`, `_clignotement`, `_secousse_restante`), et la prédiction n'y touche pas. La réplication (`direction_du_lion`, `vomi_de_l_hote`, `_suivre_l_hote`) reste aussi dans `Lion` : le `Synchro` réplique des propriétés du lion (`.:direction_du_lion`, `.:vomi_de_l_hote`), et l'interpolation des lions distants (phase 16) s'y greffera.
3. **`DeplacementLion` est un `RefCounted` de logique pure, pas un nœud** : les tests `--script` peuvent le nommer (comme `Territoire`, `Peinture`), la prédiction peut en garder des copies. Ses réglages (`speed` 350, `acceleration` 2400, `force_recul` 700) quittent les `@export` de `Lion` pour des variables de `DeplacementLion` : aucune scène ne les surchargeait (vérifié : `Lion.tscn` n'a pas ces propriétés, aucun script ni test ne les écrit), et les garder à deux endroits dupliquerait l'état. Ceux des chocs restent exportés, sur le nœud `PareChocs`.
4. **`Lion.avancer(direction, delta)` est le pas de déplacement** (orientation, vitesse, blocage, `move_and_slide`, bords) ; l'animation (inclinaison, trot) et le signalement des lions touchés par la gerbe en sortent, dans `_physics_process` : ce sont les mêmes calculs, dans un ordre équivalent (l'animation ne lit ni la position ni `velocity`), vérifié par la trace. La prédiction de la phase 16 rejouera `avancer` ; `move_and_slide` n'est pas remplacé par une intégration faite main (le corps du lion ne heurte rien, masque 0, mais `move_and_slide` resterait le code de l'hôte, et une intégration différente changerait les derniers bits des positions).
5. **Rien n'est renommé dans la scène** ; un seul nœud apparaît, `Gerbe` (un `Node2D` à l'origine du lion, dernier enfant), parent des zones de contact créées par le code (`ZoneContact1` à `3`, mêmes noms, mêmes positions dans le repère du lion). `GerbeTraceuse.gd` lit toujours le lion par `get_parent()` ; la réplication (`Synchro`) ne change pas. Les tests lisent désormais `lion.deplacement.recul`, `lion.deplacement.vitesse`, `lion.pare_chocs.rayon`, `lion.gerbe.traceuse_shape`, `lion.gerbe.vomi_container`, `lion.gerbe.zones_contact`, `lion.gerbe.traceuse`, `lion.gerbe.bouche`, `lion.gerbe.BOUCHE_X_GAUCHE` (réécriture mécanique, comptes vérifiés) ; `Lion.temps` devient public (le pare-chocs le lit pour son délai anti-rafale), `Lion.secouer()` apparaît.
6. **L'outil de trace est committé, hors CI** : il sert ici et servira à la phase 16. Il lit le lion par les nœuds de sa scène et ses champs publics, jamais par un champ privé : le même fichier avant et après chaque tâche. Pas en CI : il compare un code à un autre, pas à une valeur de référence (les empreintes dépendent de la plateforme et de la version de Godot). **Mesuré en préparant ce plan** : les deux passages qui suivent immédiatement un import (ou la copie du dépôt) de scripts modifiés peuvent donner d'autres empreintes (5 passages sur environ 110 mesurés, tous parmi les deux premiers d'une série) ; ensuite, 30 passages sur 30 identiques, y compris sous charge (six en parallèle) et ralentis (2 ms par tick). Cause non établie : l'ordre dans lequel la physique rapporte des contacts simultanés dépend d'identifiants d'objets (rejouer la même bataille une seconde fois dans le même processus donne une autre empreinte, toujours la même). D'où la règle de la trace (Global Constraints) : **deux passages consécutifs identiques** font le verdict ; `--etats=<fichier>` écrit l'état de chaque tick pour trouver le premier qui diffère.
7. **Pas de nettoyage préalable (« Step 0 »)** : `Lion.gd` n'a ni code mort, ni import inutile, ni trace de débogage (vérifié, Task 0) ; le découpage lui-même est la refonte, en trois tâches vérifiées chacune par la trace.
8. **Aucun comportement ne change, donc aucune version de protocole** (`config/version` reste « 0.14 » : ni RPC ni propriété répliquée ne bouge ; les chemins de nœuds répliqués sont ceux du lion et des scènes qui apparaissent, inchangés).

## Global Constraints

- Godot 4.7.2 (`export PATH="/opt/homebrew/bin:$PATH"`), commandes depuis `~/Sites/LeLion-multi`, branche `phase-15bis-decoupage-lion`.
- Fichiers de la phase : ➕ `tests/trace_lions.gd`, ➕ `Scripts/DeplacementLion.gd`, ➕ `Scripts/PareChocs.gd`, ➕ `Scripts/GerbeLion.gd` (+ leurs `.uid`, générés par l'import) ; ✏️ `Scripts/Lion.gd`, `Scenes/Lion.tscn`, `Scripts/GerbeTraceuse.gd` (un commentaire), `Scripts/Manche.gd` (un commentaire), `tests/unitaires.gd`, `tests/smoke_test.gd`, `tests/bataille_test.gd` ; la spec et la feuille de route (Task 6). **`tests/reseau/joueur.gd`, `tests/reseau/lancer.sh`, `Scripts/Reseau.gd`, `project.godot` et `.github/workflows/ci.yml` ne changent pas.**
- **Comportement strictement identique** en solo, en bataille locale et en réseau : après chaque tâche de code (2 à 5), la trace est celle de la référence (Task 1) ; les quatre suites restent vertes sans qu'aucune vérification existante ne soit affaiblie (seuls les chemins d'accès des tests changent, par les réécritures données).
- **La trace** : `export PATH="/opt/homebrew/bin:$PATH"; godot --headless --import . > /dev/null 2>&1; for k in 1 2 3; do timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/trace_lions.gd 2>&1 | grep -E "^TRACE|❌|SCRIPT ERROR" | tr '\n' ' '; echo; done`. Verdict : **deux passages consécutifs identiques** (si les deux derniers diffèrent, en faire un quatrième, un cinquième ; au-delà, c'est un défaut à chercher) ; leurs trois lignes `TRACE bataille …`, `TRACE solo …`, `TRACE replique …` doivent être celles de la référence. Pour trouver le premier tick qui diffère : `… --script tests/trace_lions.gd -- --etats="$TMPDIR/etats.txt"`, puis `cmp "$TMPDIR/etats_reference.txt" "$TMPDIR/etats.txt"` (le numéro de ligne est le tick).
- Les nœuds de `Lion.tscn` gardent leurs noms et leur place : `Sprite2D`, `AnimationPlayer`, `CollisionShape2D`, `VomiParticlesContainer`, `GerbeTraceuse`, `Bouche`, `Pseudo`, `Etoiles`, `PareChocs`, `Synchro` ; seul `Gerbe` s'ajoute, en dernier.
- Identifiants, commentaires et messages de test en français, docstrings `##`, tabulations.
- **Aucune séquence d'échappement `\u…` n'est tapée dans un fichier**. Vérifier après chaque écriture : `perl -CSD -ne 'print "$ARGV:$.\n" if /[\x{200B}-\x{200F}\x{202A}-\x{202E}\x{2060}-\x{206F}\x{FEFF}]/' Scripts/*.gd Scenes/Lion.tscn tests/*.gd` ne sort rien.
- Un test `--script` est compilé **avant** les autoloads : il ne nomme ni `GameState`, ni `Lion`, ni `PareChocs`, ni `GerbeLion` (ils nomment des autoloads), ni la ville, ni les ennemis ; il peut nommer `DeplacementLion` (logique pure), `Joueur`, `Commandes`, `Territoire`, `ReglesBataille`.
- Après la création d'un script à `class_name` ou une modification de scène : `godot --headless --import .` avant les tests (il génère aussi le `.uid` du nouveau script, à committer avec lui).
- **Toujours lancer un test Godot avec `timeout`** et chercher les erreurs :
  `export PATH="/opt/homebrew/bin:$PATH"; T=tests/smoke_test.gd; O=""; timeout -k 5 300 godot --headless $O --script $T > "$TMPDIR/t.log" 2>&1; echo "code $?"; grep -E "❌|SCRIPT ERROR|SHADER ERROR|Parse Error|== " "$TMPDIR/t.log"`
  (`T=tests/unitaires.gd; O=""`, `T=tests/bataille_test.gd; O="--fixed-fps 60"` ; le test réseau : `timeout -k 5 300 bash tests/reseau/lancer.sh > "$TMPDIR/r.log" 2>&1; echo "code $?"; grep -E "❌|✅|== |\(bout|\(I1" "$TMPDIR/r.log"`). Une `SCRIPT ERROR` ne change pas le code de sortie ; un script qui ne compile pas sort aussi en `code 0`, sans ligne `== n échec(s) ==`. Bruit connu : « ObjectDB instances were leaked », « resources still in use at exit » ; les `ERROR` voulues des unitaires et du smoke test listées au plan de la phase 14.
- **Aucun message de test ne contient les mots `SCRIPT ERROR` ni `SHADER ERROR`**.
- Les quatre suites se valident sur **5 passages consécutifs verts**, le test réseau sous bash 3.2 (`/bin/bash`, macOS) et bash 5.
- Commits en français, terminés par la ligne `Co-Authored-By:` que fournit l'environnement de l'exécutant (dans les blocs ci-dessous : `<ligne fournie par l'environnement>`).

## Review Focus

1. **Un comportement qui dérive sans qu'aucun test ciblé ne le voie** (un calcul réordonné, un signal branché ailleurs, un état remis à zéro au mauvais moment) en solo, en bataille locale ou sur une réplique. → la trace identique à la référence après chaque tâche (Tasks 2 à 5) ; les mutations S1, S2 et S5 (Task 5) changent la trace.
2. **Un état par lion devenu partagé entre les lions** (la forme de la traceuse de `Lion.tscn`, les zones de contact, le déplacement). → « une pastille donne un cran : 5 px de plus, pour ce lion seulement », « chaque lion a ses propres formes de zones de contact » (existants), « (pré-condition) chaque lion a son propre déplacement » (Task 2) ; mutation S3 (la forme de la traceuse non dupliquée) ⇒ deux `❌`.
3. **Un lion libéré dont le joueur survit** (départ d'un client, fin de manche : `GameState` garde le `Joueur`) et qui reçoit encore ses signaux, par le lion ou un composant. → « un lion libéré n'est plus abonné aux signaux de son joueur » puis des signaux émis sans `SCRIPT ERROR` (Task 5) ; mutation S4 (lions retirés sans être libérés) ⇒ `❌ … (12 abonnements restants)`.
4. **Le pas de déplacement, point d'entrée de la prédiction (phase 16)** : un pas qui ne fait pas ce que fait le tick, oublie de réorienter la gerbe ou laisse une vitesse fantôme contre un bord. → tests unitaires de `DeplacementLion`, « un pas vers la droite : … », « un pas vers la gauche retourne le lion et sa gerbe », « un pas hors de l'écran le ramène au bord, sans vitesse fantôme » (Task 2) ; mutations S1 (amortissement du recul) et S5 (vitesse fantôme).
5. **Une réplique de client qui se remettrait à simuler** (bouger, se bloquer, signaler des chocs ou des gerbes aux règles) après le déplacement du code dans les composants. → section « réplique » du smoke test (« sur un client, un lion ne suit pas ses commandes… »), partie `replique` de la trace, scénarios 9 et 11 du test réseau (Task 5, 5 fois sous bash 3.2 et 5).

---

### Task 0 : vérifications

Ce plan est commité par le commit de planification : ne pas le recommiter, **ne jamais le modifier**. Vérifier que la phase 15 est fusionnée : `grep -n "^# 11\. De bout en bout" tests/reseau/lancer.sh` et `grep -n "func _jouer_bout" tests/reseau/joueur.gd` trouvent chacun une ligne, et `wc -l Scripts/Lion.gd` donne 542. Sinon, s'arrêter et le signaler. Les blocs « Remplacer » citent le code tel que la phase 15 le laisse (vérifié en appliquant ce plan, bloc par bloc, à une copie de `phase-14-manche` + phase 15) : si une ancre a bougé, l'adapter au texte réel sans changer le remplacement, et le noter.

« Step 0 » (règle du projet pour un fichier de plus de 300 lignes) : pas de code mort à retirer. Le vérifier :

```bash
for n in $(grep -oE "^(const|var|func|@onready var|@export var) [A-Za-z_]+" Scripts/Lion.gd | awk '{print $NF}'); do
	[ "$(grep -c "\b$n\b" Scripts/Lion.gd)" -lt 2 ] && echo "$n"
done
```

Expected : seulement `_physics_process` (rappel du moteur) ; aucun `print(` dans `Scripts/Lion.gd`.

Puis : `git switch -c phase-15bis-decoupage-lion`.

---

### Task 1 : l'outil de trace et la référence

**Files:**
- Create: `tests/trace_lions.gd` (+ `.uid`)

**Interfaces:**
- Consumes : `GameState.configurer_bataille(n)`, `configurer_solo()`, `joueurs`, `joueur_local()`, `pret`, `partie_en_cours`, `terminer_partie` ; `Main.lions`, `Main.lion` ; `Spawner.spawn_pickup`, `spawn_bonus`, `spawn_soucoupe` ; `Lion.CENTRE`, `commandes`, `joueur`, `direction_du_lion`, `est_en_train_de_vomir`, `vomi_de_l_hote`, `velocity` ; les nœuds du lion par leur nom ; `Territoire.scores()`.
- Produces (Tasks 2 à 5) : `godot --headless --fixed-fps 60 --script tests/trace_lions.gd [-- --etats=<fichier>]` écrit `TRACE bataille <n>`, `TRACE solo <n>`, `TRACE replique <n>` et `== 0 échec(s) ==` ; la référence de ce poste, notée dans `$TMPDIR/trace_reference.txt` (jamais commitée).

- [ ] **Step 1 : l'outil**

Créer `tests/trace_lions.gd` :

```gdscript
extends SceneTree
## Trace des lions, l'outil de non-régression des refontes du lion (phase 15 bis) :
##   godot --headless --fixed-fps 60 --script tests/trace_lions.gd
## Rejoue dans un seul processus, tick par tick, trois parties scriptées et reproductibles (hasard
## global semé, `--fixed-fps 60`) qui passent par tout le code du lion : une bataille locale à 4 lions
## sur le Village (couloirs de peinture, pastilles, étoile, soucoupe, gerbes croisées, chocs, poussée
## continue, bords de l'écran, peintre), une partie solo (couleurs débloquées, coups, clignotement,
## étoile) et la réplique d'un lion sur un client (état et réactions reçus de l'hôte). À chaque tick,
## l'état observable de chaque lion (corps, sprite, étoiles, gerbe, traceuse, zones de contact,
## matériau, étiquette, joueur) et le territoire entrent dans une empreinte ; chaque partie écrit
## « TRACE <partie> <empreinte> ». Deux passages du même code donnent les mêmes empreintes ; une
## refonte qui ne change rien au comportement aussi. N'y entre pas le décalage de la secousse
## (`sprite.offset`, tiré par le générateur propre à chaque lion, semé au hasard).
## Lit le lion par les nœuds de sa scène (noms stables) et ses champs publics, jamais par ses champs
## privés : le même script sert avant et après une refonte. Les vérifications (« ✅ ») disent
## seulement que chaque partie est bien passée par ce qu'elle doit couvrir.
## `-- --etats=<fichier>` écrit aussi l'état de chaque tick, une ligne par tick (`var_to_str`) : deux
## fichiers qui diffèrent se comparent ligne à ligne pour trouver le premier tick qui change.
## Compilé avant les autoloads : ne nomme ni `GameState`, ni `Lion`, ni la ville, ni les ennemis.

const NB_LIONS := 4
const TICKS_BATAILLE := 5400  # la manche entière (90 s), après l'intro
const TICKS_SOLO := 1800
const TICKS_REPLIQUE := 240
const HAUTEURS_JET: Array[float] = [-233.0, -200.0, -270.0]  # y du lion sous le haut de la skyline

var _echecs := 0
var GS: Node
var _empreinte := 0
## Réactions vues pendant la partie en cours (signaux des joueurs), pour les vérifications.
var _vus := {}
var _fichier_etats := ""
var _etats: PackedStringArray = []


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--etats="):
			_fichier_etats = arg.trim_prefix("--etats=")
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		_echecs += 1
		printerr("  ❌ ", msg)


func _run() -> void:
	print("== trace des lions LeLion ==")
	GS = root.get_node("GameState")
	var scores: Node = root.get_node("Scores")
	scores.chemin = "user://scores_trace.cfg"  # la fin du solo enregistre un temps : jamais les scores du joueur
	scores.effacer()
	await _tracer_bataille()
	await _tracer_solo()
	await _tracer_replique()
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false
	scores.effacer()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scores.chemin))
	if not _fichier_etats.is_empty():
		FileAccess.open(_fichier_etats, FileAccess.WRITE).store_string("\n".join(_etats))
	print("== %d échec(s) ==" % _echecs)
	quit(1 if _echecs > 0 else 0)


## L'état observable d'un lion à ce tick, par les nœuds de sa scène.
func _etat(l: Node) -> Array:
	var sprite: Sprite2D = l.get_node("Sprite2D")
	var etoiles: Node2D = l.get_node("Etoiles")
	var traceuse: Area2D = l.get_node("GerbeTraceuse")
	var conteneur: Node2D = l.get_node("VomiParticlesContainer")
	var etiquette: Label = l.get_node("Pseudo")
	var j: Joueur = l.joueur
	var etat: Array = [l.position, l.velocity, l.direction_du_lion, l.est_en_train_de_vomir, l.vomi_de_l_hote,
		sprite.position, sprite.rotation, sprite.scale, sprite.modulate, sprite.texture.resource_path,
		etoiles.visible, etoiles.get_child(0).position, traceuse.position, traceuse.monitoring,
		(traceuse.get_node("CollisionShape2D").shape as CircleShape2D).radius, conteneur.position,
		(l.get_node("Bouche") as Node2D).position, etiquette.visible, etiquette.text,
		j.crans, j.vies, j.etourdi_restant, j.invulnerable_restant, j.bonus_restant, j.chocs,
		j.etourdissements_infliges, j.cellules_volees, j.couleurs_debloquees.size()]
	for e: GPUParticles2D in conteneur.get_children():
		var m := e.process_material as ParticleProcessMaterial
		etat.append_array([e.emitting, e.amount, m.direction, m.scale_min, m.scale_max, m.color_ramp.gradient.get_color(0)])
	for n in range(1, 4):
		var z: Area2D = l.find_child("ZoneContact%d" % n, true, false)  # créées par le code : sans propriétaire
		etat.append_array([z.position, z.monitoring, (z.get_child(0).shape as CircleShape2D).radius])
	var mat := sprite.material as ShaderMaterial
	if mat != null:
		etat.append_array([mat.get_shader_parameter("couleur_joueur"), mat.get_shader_parameter("barbouillage_couleur"),
			mat.get_shader_parameter("barbouillage_force")])
	return etat


func _tracer_tick(lions: Array, ville: Node2D) -> void:
	var etats: Array = lions.map(func(l: Node) -> Array: return _etat(l))
	if ville != null and ville.territoire != null:
		etats.append(ville.territoire.scores())
	_empreinte = hash([_empreinte, var_to_bytes(etats)])
	if not _fichier_etats.is_empty():
		_etats.append(var_to_str(etats).replace("\n", " "))


## Compte les réactions des joueurs de la partie (étourdissements par un ennemi ou par une gerbe,
## coups, crans, gerbes XXL, couleurs) pour les vérifications de couverture.
func _suivre(joueurs: Array) -> void:
	_vus = {"ennemi": 0, "gerbe": 0, "touche": 0, "cran": 0, "xxl": 0, "couleur": 0}
	for j: Joueur in joueurs:
		j.etourdi.connect(func(_o: Vector2, barbouillage: Color) -> void: _vus["gerbe" if barbouillage.a > 0.0 else "ennemi"] += 1)
		j.touche.connect(func(_o: Vector2) -> void: _vus.touche += 1)
		j.crans_changes.connect(func(_c: int) -> void: _vus.cran += 1)
		j.bonus_change.connect(func(actif: bool) -> void:
			if actif:
				_vus.xxl += 1)
		j.couleur_debloquee.connect(func(_c: Color) -> void: _vus.couleur += 1)


func _oublier(joueurs: Array) -> void:
	for j: Joueur in joueurs:
		for s: Signal in [j.etourdi, j.touche, j.crans_changes, j.bonus_change, j.couleur_debloquee]:
			for c: Dictionary in s.get_connections():
				if (c.callable as Callable).get_object() == self:
					s.disconnect(c.callable)


func _charger_main() -> Node:
	var main: Node = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	return main


func _liberer(main: Node) -> void:
	paused = false
	main.free()
	await physics_frame


## Couloirs de peinture, comme la manche de `tests/bataille_test.gd` : chaque lion balaie le sien en
## vomissant et change de hauteur à chaque demi-tour ; les couloirs voisins se chevauchent.
func _piloter(lion: Node2D, couloir: Dictionary, haut: float) -> void:
	var centre: Vector2 = lion.global_position + lion.CENTRE
	if centre.x >= couloir.max:
		couloir.sens = -1.0
		couloir.rangee = (couloir.rangee + 1) % HAUTEURS_JET.size()
	elif centre.x <= couloir.min:
		couloir.sens = 1.0
		couloir.rangee = (couloir.rangee + 1) % HAUTEURS_JET.size()
	var ecart_y: float = haut + HAUTEURS_JET[couloir.rangee] - lion.global_position.y
	lion.commandes.direction_voulue = Vector2(couloir.sens, clampf(ecart_y / 60.0, -1.0, 1.0)).normalized()
	lion.commandes.vomir_voulu = true


func _tracer_bataille() -> void:
	print("-- Bataille locale à 4 lions sur le Village")
	seed(20260926)
	_empreinte = 0
	GS.niveau_courant = 2
	GS.difficulte_courante = 0
	GS.configurer_bataille(NB_LIONS)
	for i in range(NB_LIONS):
		GS.joueurs[i].pseudo = "Joueur %d" % (i + 1)
	var main := _charger_main()
	var lions: Array = main.lions
	lions[0].commandes = Commandes.manuelles()
	var ville: Node2D = main.get_node("Ville")
	var spawner: Node = main.get_node("Spawner")
	_suivre(GS.joueurs)
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	var couloirs: Array[Dictionary] = []
	for i in range(NB_LIONS):
		var centre := 2000.0 * (i + 0.5) / NB_LIONS
		couloirs.append({"min": maxf(centre - 350.0, 150.0), "max": minf(centre + 350.0, 1850.0),
			"sens": 1.0 if i % 2 == 0 else -1.0, "rangee": i % HAUTEURS_JET.size()})
	var l0: Node2D = lions[0]
	var l1: Node2D = lions[1]
	var l2: Node2D = lions[2]
	var l3: Node2D = lions[3]
	var bords := 0
	var chevauchements := 0
	var f := -1  # ticks depuis la fin de l'intro
	while f < TICKS_BATAILLE:
		if GS.pret:
			f += 1
		if f >= 0:
			for i in range(NB_LIONS):
				_piloter(lions[i], couloirs[i], haut)
		# La gerbe du lion 1 sur le lion 2, placé sous la trajectoire
		if f >= 600 and f < 660:
			if f == 600:
				l0.global_position = Vector2(500, 300)
				l0.direction_du_lion = 1
			l0.commandes.direction_voulue = Vector2.ZERO
			l0.commandes.vomir_voulu = true
			if f >= 605:
				l1.global_position = l0.find_child("ZoneContact2", true, false).global_position - l1.CENTRE
				l1.commandes.direction_voulue = Vector2.ZERO
		# Un choc de face, puis une poussée continue contre un lion arrêté
		if f >= 900 and f < 1120:
			if f == 900 or f == 1000:
				l2.global_position = Vector2(600, 400)
				l3.global_position = Vector2(900, 400)
			l2.commandes.direction_voulue = Vector2.RIGHT
			l3.commandes.direction_voulue = Vector2.LEFT if f < 1000 else Vector2.ZERO
			l2.commandes.vomir_voulu = false
			l3.commandes.vomir_voulu = false
		if f == 1200:
			var soucoupe: Node2D = spawner.spawn_soucoupe(l1.global_position.y + l1.CENTRE.y)
			soucoupe.position.x = l1.global_position.x + l1.CENTRE.x
		if f == 1300:
			spawner.spawn_bonus(l2.global_position + l2.CENTRE)
		if f == 1400 or f == 1410 or f == 1420:
			spawner.spawn_pickup(0, l3.global_position + l3.CENTRE)
		# Les bords de l'écran : en haut à gauche, puis en bas à droite
		if f >= 1500 and f < 1620:
			l0.commandes.direction_voulue = Vector2(-1, -1).normalized()
		if f >= 1620 and f < 1740:
			l1.commandes.direction_voulue = Vector2(1, 1).normalized()
		await physics_frame
		_tracer_tick(lions, ville)
		for l: Node2D in lions:
			if l.global_position.x == 0.0 or l.global_position.y == -(l.get_node("Pseudo") as Control).position.y:
				bords += 1
		if l2.get_node("PareChocs").global_position.distance_to(l3.get_node("PareChocs").global_position) < 90.0:
			chevauchements += 1
	GS.terminer_partie(true)
	var chocs: int = GS.joueurs.reduce(func(n: int, j: Joueur) -> int: return n + j.chocs, 0)
	print("TRACE bataille %d" % _empreinte)
	print("  (bataille) %s, chocs %d, ticks aux bords %d, pare-chocs chevauchés %d, scores %s"
		% [_vus, chocs, bords, chevauchements, ville.territoire.scores()])
	_check(_vus.gerbe > 0 and _vus.ennemi > 0 and _vus.cran >= 3 and _vus.xxl > 0 and chocs > 0 and bords > 0 and chevauchements > 0,
		"la bataille passe par les gerbes, les ennemis, les pastilles, l'étoile, les chocs, les bords et les pare-chocs")
	_oublier(GS.joueurs)
	await _liberer(main)
	for j: Joueur in GS.joueurs:
		j.pseudo = ""


func _tracer_solo() -> void:
	print("-- Partie solo sur la Skyline")
	seed(20260927)
	_empreinte = 0
	GS.configurer_solo()
	GS.niveau_courant = 0
	GS.difficulte_courante = 0
	var main := _charger_main()
	var lion: Node2D = main.lion
	lion.commandes = Commandes.manuelles()
	var ville: Node2D = main.get_node("Ville")
	var spawner: Node = main.get_node("Spawner")
	_suivre([GS.joueur_local()])
	GS.joueur_local().vies = 9  # la partie dure jusqu'au bout des ticks, malgré les ennemis
	var haut: float = ville.position.y - ville.tex_size.y / 2.0
	var couloir := {"min": 150.0, "max": 1850.0, "sens": 1.0, "rangee": 0}
	var f := -1
	while f < TICKS_SOLO:
		if GS.pret:
			f += 1
		if f >= 0:
			_piloter(lion, couloir, haut)
		if f == 120 or f == 130 or f == 140:
			spawner.spawn_pickup((f - 120) / 10, lion.global_position + lion.CENTRE)
		if f == 400 or f == 1000:
			var soucoupe: Node2D = spawner.spawn_soucoupe(lion.global_position.y + lion.CENTRE.y)
			soucoupe.position.x = lion.global_position.x + lion.CENTRE.x
		if f == 700:
			spawner.spawn_bonus(lion.global_position + lion.CENTRE)
		await physics_frame
		_tracer_tick([lion], null)
	print("TRACE solo %d" % _empreinte)
	print("  (solo) %s, vies %d, couverture %.3f" % [_vus, GS.joueur_local().vies, ville.progression()])
	_check(_vus.couleur >= 3 and _vus.touche >= 2 and _vus.xxl > 0 and GS.partie_en_cours,
		"le solo passe par les couleurs, les coups et l'étoile, sans finir la partie")
	_oublier([GS.joueur_local()])
	GS.terminer_partie(false)
	await _liberer(main)


func _tracer_replique() -> void:
	print("-- Réplique d'un lion sur un client")
	seed(20260928)
	_empreinte = 0
	GS.configurer_bataille(2)
	GS.nouvelle_partie()
	GS.pret = true
	var poste := Node2D.new()
	poste.name = "PosteTrace"
	root.add_child(poste)
	var api := SceneMultiplayer.new()
	var pair := ENetMultiplayerPeer.new()
	_check(pair.create_client("127.0.0.1", 7779) == OK, "(pré-condition) un pair client, jamais connecté")
	api.multiplayer_peer = pair
	set_multiplayer(api, poste.get_path())
	var j: Joueur = GS.joueurs[1]
	var repl: CharacterBody2D = load("res://Scenes/Lion.tscn").instantiate()
	repl.joueur = j
	repl.commandes = Commandes.manuelles()
	repl.direction_du_lion = -1
	repl.position = Vector2(600, 500)
	poste.add_child(repl)
	_suivre([j])
	var etoiles_vues := 0
	var emission_vue := 0
	for f in range(TICKS_REPLIQUE):
		# Ce qu'écrirait le Synchro : une course en huit, le vomi par moments
		repl.position = Vector2(600 + 300 * sin(f * 0.05), 500 + 120 * sin(f * 0.1))
		repl.velocity = Vector2(15 * cos(f * 0.05), 12 * cos(f * 0.1)) * 60.0
		repl.direction_du_lion = 1 if cos(f * 0.05) >= 0.0 else -1
		repl.vomi_de_l_hote = (f / 30) % 2 == 1
		repl.commandes.direction_voulue = Vector2.LEFT  # ignorées par une réplique
		if f == 60:
			j.etourdir(1.5, 1.0, repl.global_position + Vector2(-50, 66), GS.joueurs[0].couleur)
		if f == 150:
			j.recevoir_fin_etourdissement(1.0)
		if f == 170:
			j.recevoir_crans(3)
		if f == 180:
			j.activer_bonus(2.0)
		if f == 200:
			j.recevoir_fin_bonus()
		await physics_frame
		_tracer_tick([repl], null)
		if repl.get_node("Etoiles").visible:
			etoiles_vues += 1
		if repl.est_en_train_de_vomir:
			emission_vue += 1
	print("TRACE replique %d" % _empreinte)
	_check(etoiles_vues > 0 and emission_vue > 0 and _vus.gerbe == 1 and _vus.cran == 1 and _vus.xxl == 1,
		"la réplique passe par le vomi reçu, l'étourdissement, les crans et la gerbe XXL reçus")
	_oublier([j])
	repl.free()
	set_multiplayer(null, poste.get_path())
	pair.close()
	poste.free()
```

Note : les zones de contact sont lues par leur numéro, pas triées par nom : un tri de `StringName` compare des adresses, et l'ordre changeait d'un passage à l'autre (mesuré).

- [ ] **Step 2 : la référence**

Run : l'import, puis la trace (Global Constraints) trois fois, puis une fois de plus avec les états :

```bash
export PATH="/opt/homebrew/bin:$PATH"
godot --headless --import . > /dev/null 2>&1
for k in 1 2 3; do timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/trace_lions.gd 2>&1 | grep -E "^TRACE|❌|SCRIPT ERROR|== " | tr '\n' ' '; echo; done
timeout -k 5 300 godot --headless --fixed-fps 60 --script tests/trace_lions.gd -- --etats="$TMPDIR/etats_reference.txt" 2>&1 | grep -E "^TRACE" > "$TMPDIR/trace_reference.txt"
cat "$TMPDIR/trace_reference.txt"; wc -l "$TMPDIR/etats_reference.txt"
```

Expected (mesuré sur le Mac de développement ; les nombres peuvent différer sur une autre machine, c'est leur égalité qui compte) : les passages 2, 3 et 4 identiques, `TRACE bataille 689790676`, `TRACE solo 185311436`, `TRACE replique 3757044499`, `== 0 échec(s) ==`, 3 s chacun ; `etats_reference.txt` de 7 695 lignes (un tick par ligne). Les lignes `(bataille)` et `(solo)` du journal montrent ce que chaque partie couvre (par exemple `{ "ennemi": 47, "gerbe": 14, … "cran": 4, "xxl": 1 … }, chocs 220, ticks aux bords 65, pare-chocs chevauchés 502`).

- [ ] **Step 3 : Commit**

```bash
git add tests/trace_lions.gd tests/trace_lions.gd.uid
git commit -m "Outil de trace des lions (tests/trace_lions.gd, hors CI) : une bataille à 4 lions, une partie solo et une réplique de client rejouées tick par tick, dont l'empreinte prouve qu'une refonte du lion ne change rien

<ligne fournie par l'environnement>"
```

---

### Task 2 : le déplacement (`DeplacementLion`) et le pas `Lion.avancer`

**Files:**
- Create: `Scripts/DeplacementLion.gd` (+ `.uid`)
- Modify: `Scripts/Lion.gd` (exports, variables, `_physics_process`, nouveau `avancer`, `_suivre_l_hote`, `_animer_deplacement`, `_on_etourdi`, `_reculer`, `_on_pare_chocs_area_entered`, `_bloquer_contre_les_lions`)
- Test: `tests/unitaires.gd` (`_run`, une fonction), `tests/smoke_test.gd` (accès réécrits, une section), `tests/bataille_test.gd` (accès réécrits)

**Interfaces:**
- Consumes : Task 1 (la trace et sa référence).
- Produces (Tasks 3 à 5, phase 16) : `class_name DeplacementLion extends RefCounted` : `var speed := 350.0`, `var acceleration := 2400.0`, `var force_recul := 700.0`, `var vitesse := Vector2.ZERO`, `var recul := Vector2.ZERO`, `func vitesse_du_pas(direction: Vector2, delta: float) -> Vector2`, `func arreter() -> void`, `func repousser(centre: Vector2, origine: Vector2, direction_du_lion: int) -> void` ; `Lion.deplacement: DeplacementLion` ; `func Lion.avancer(direction: Vector2, delta: float) -> void`.

- [ ] **Step 1 : les tests**

Dans `tests/unitaires.gd` :

1a. Remplacer :

```gdscript
	_tester_reseau_manche()
	print("== %d échec(s) ==" % _echecs)
```

par :

```gdscript
	_tester_reseau_manche()
	_tester_deplacement_lion()
	print("== %d échec(s) ==" % _echecs)
```

1b. Remplacer :

```gdscript
## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
```

par :

```gdscript
## Phase 15 bis : le déplacement d'un lion, en logique pure (`DeplacementLion`), que `Lion.avancer`
## fait avancer d'un pas par tick et que la prédiction du lion local rejouera (phase 16).
func _tester_deplacement_lion() -> void:
	print("-- Déplacement d'un lion (logique pure)")
	var d := DeplacementLion.new()
	var dt := 1.0 / 60.0
	var v := d.vitesse_du_pas(Vector2.RIGHT, dt)
	_check(is_equal_approx(v.x, d.acceleration * dt) and v.y == 0.0 and d.recul == Vector2.ZERO,
		"un pas vers la droite : la vitesse commandée gagne une accélération d'un tick (%.1f px/s)" % v.x)
	for i in range(30):
		v = d.vitesse_du_pas(Vector2.RIGHT, dt)
	_check(v == Vector2(d.speed, 0.0), "elle plafonne à la vitesse du lion (%s)" % v)
	d.arreter()
	_check(d.vitesse == Vector2.ZERO, "arrêter annule la vitesse commandée (début d'un étourdissement)")
	d.repousser(Vector2(100, 100), Vector2(40, 100), 1)
	_check(d.recul == Vector2(d.force_recul, 0.0), "un coup venu de la gauche repousse vers la droite, de toute la force du recul")
	d.repousser(Vector2(100, 100), Vector2.INF, 1)
	_check(d.recul == Vector2(-d.force_recul, 0.0), "origine inconnue : recul vers l'arrière du lion (tourné à droite)")
	d.repousser(Vector2(100, 100), Vector2(100, 100), -1)
	_check(d.recul == Vector2(d.force_recul, 0.0), "origine confondue avec le centre : recul vers l'arrière du lion (tourné à gauche)")
	var pas := 0
	while d.recul != Vector2.ZERO and pas < 60:
		v = d.vitesse_du_pas(Vector2.ZERO, dt)
		pas += 1
	_check(pas == ceili(d.force_recul / (d.acceleration * 1.5 * dt)) and v == Vector2.ZERO,
		"sans commande, le recul s'amortit jusqu'à zéro en %d ticks, et le lion s'arrête" % pas)
	var a := DeplacementLion.new()
	var b := DeplacementLion.new()
	for i in range(20):
		a.vitesse_du_pas(Vector2(1, 1).normalized(), dt)
		b.vitesse_du_pas(Vector2(1, 1).normalized(), dt)
	_check(a.vitesse == b.vitesse and a.recul == b.recul, "les mêmes commandes donnent les mêmes pas (ce que rejouera la prédiction)")


## Sert l'hôte (`Reseau`) et le pair `autre` jusqu'à ce que la connexion d'ENet soit établie des deux
```

Dans `tests/smoke_test.gd` :

1c. Réécrire les accès à l'état de déplacement du lion, puis vérifier les comptes :

```bash
perl -pi -e 's/\._recul\b/.deplacement.recul/g; s/\._vitesse\b/.deplacement.vitesse/g' tests/smoke_test.gd tests/bataille_test.gd
grep -c "deplacement\.recul\|deplacement\.vitesse" tests/smoke_test.gd tests/bataille_test.gd
grep -n "\._recul\|\._vitesse" tests/*.gd
```

Expected : `tests/smoke_test.gd:20`, `tests/bataille_test.gd:2`, puis aucune ligne.

1d. Remplacer (le commentaire, qui nommait les anciens champs) :

```gdscript
	# correction, seul `_recul` s'opposait à `_vitesse` (qui ramenait aussitôt vers l'autre) et
	# chaque re-contact comptait, jusqu'à 14 chocs en 2 s ; `_vitesse` doit maintenant se
```

par :

```gdscript
	# correction, seul le recul s'opposait à la vitesse commandée (qui ramenait aussitôt vers l'autre) et
	# chaque re-contact comptait, jusqu'à 14 chocs en 2 s ; la vitesse commandée doit maintenant se
```

1e. Remplacer :

```gdscript
	_check(distance_min > 2 * 45.0 - 15.0, "même en poussant sans relâche, un lion ne s'enfonce pas dans l'autre (distance min %.0f px)" % distance_min)

```

par :

```gdscript
	_check(distance_min > 2 * 45.0 - 15.0, "même en poussant sans relâche, un lion ne s'enfonce pas dans l'autre (distance min %.0f px)" % distance_min)

	# Phase 15 bis : le pas de déplacement (`Lion.avancer`), seul chemin du déplacement sur l'hôte, que
	# rejouera la prédiction du lion local (phase 16) ; chaque lion a son propre état de déplacement
	j_bleu.etourdi_restant = 0.0
	j_bleu.invulnerable_restant = 0.0
	lr.commandes.direction_voulue = Vector2.ZERO
	lr.global_position = Vector2(400, 300)
	lb.global_position = Vector2(1400, 300)
	await _frames(30)  # reculs amortis, contacts des pare-chocs oubliés
	_check(lr.deplacement != lb.deplacement and lr.deplacement.recul == Vector2.ZERO and lr.velocity == Vector2.ZERO,
		"(pré-condition) chaque lion a son propre déplacement ; le lion rouge est à l'arrêt")
	var x_avant_pas: float = lr.global_position.x
	var dt_pas := 1.0 / Engine.physics_ticks_per_second
	lr.avancer(Vector2.RIGHT, dt_pas)
	_check(lr.deplacement.vitesse == Vector2(lr.deplacement.acceleration * dt_pas, 0.0) and lr.velocity == lr.deplacement.vitesse
		and absf(lr.global_position.x - x_avant_pas - lr.velocity.x * dt_pas) < 0.001 and lr.direction_du_lion == 1,
		"un pas vers la droite : la vitesse gagne une accélération d'un tick, le lion avance d'autant (%.3f px)" % (lr.global_position.x - x_avant_pas))
	lr.avancer(Vector2.LEFT, dt_pas)
	_check(lr.direction_du_lion == -1 and lr.sprite.scale.x == -1.0 and lr.bouche.position.x == lr.BOUCHE_X_GAUCHE,
		"un pas vers la gauche retourne le lion et sa gerbe")
	lr.global_position = Vector2(-50, -50)
	lr.avancer(Vector2(-1, -1).normalized(), dt_pas)
	_check(lr.global_position == Vector2(0, -lr.etiquette_pseudo.position.y if lr.etiquette_pseudo.visible else 0.0)
		and lr.velocity == Vector2.ZERO, "un pas hors de l'écran le ramène au bord, sans vitesse fantôme (%s)" % lr.global_position)
	lr.deplacement.vitesse = Vector2.ZERO
	lr.global_position = Vector2(600, 300)

```

(`x_avant_pas` et `dt_pas`, pas `x_avant` ni `dt` : le smoke test est une seule fonction, et `x_avant` y existe déjà. La tolérance de 0,001 px : la position est en flottants 32 bits, 0,66666 px au lieu de 0,66667 à x = 400.)

- [ ] **Step 2 : les tests échouent**

Run : les unitaires, puis le smoke test (commande des Global Constraints, mais `timeout -k 5 60` : une erreur d'exécution arrête le déroulé du test sans quitter Godot).
Expected (mesuré) : les unitaires, `SCRIPT ERROR: Parse Error: Identifier "DeplacementLion" not declared in the current scope.`, sortie aussitôt, sans ligne `== n échec(s) ==` ; le smoke test, `SCRIPT ERROR: Invalid access to property or key 'deplacement' on a base object of type 'CharacterBody2D (Lion)'.` (vers la ligne 300), puis `code 124` au bout des 60 s, sans ligne `== n échec(s) ==`.

- [ ] **Step 3 : le déplacement**

Créer `Scripts/DeplacementLion.gd` :

```gdscript
class_name DeplacementLion
extends RefCounted
## Le déplacement d'un lion, en logique pure (aucun nœud, aucun autoload : les tests `--script` le
## nomment) : la vitesse commandée, qui suit la direction voulue avec une accélération bornée, et le
## recul (coup, étourdissement, choc), qui s'amortit de lui-même. `Lion.avancer` en fait un pas par
## tick physique sur l'hôte ; la prédiction du lion local (phase 16) rejouera les mêmes pas.

var speed := 350.0
var acceleration := 2400.0
var force_recul := 700.0
## Vitesse née des commandes (px/s).
var vitesse := Vector2.ZERO
## Vitesse née des coups et des chocs (px/s), amortie une fois et demie plus vite que la vitesse
## commandée ne se reprend.
var recul := Vector2.ZERO


## Un pas de `delta` secondes vers la direction voulue `direction` (longueur 1 au plus) : la vitesse
## commandée s'en rapproche, le recul s'amortit ; renvoie leur somme, la vitesse du lion avant les
## contacts avec les autres lions (`PareChocs.bloquer`).
func vitesse_du_pas(direction: Vector2, delta: float) -> Vector2:
	vitesse = vitesse.move_toward(direction * speed, acceleration * delta)
	recul = recul.move_toward(Vector2.ZERO, acceleration * 1.5 * delta)
	return vitesse + recul


## Le lion s'arrête net (début d'un étourdissement) ; son recul continue.
func arreter() -> void:
	vitesse = Vector2.ZERO


## Recul d'un coup parti de `origine` sur un lion de centre `centre`, tourné vers `direction_du_lion`
## (1 = droite, -1 = gauche) : à l'opposé du coup, ou vers l'arrière du lion si l'origine est inconnue
## (`Vector2.INF`) ou confondue avec son centre.
func repousser(centre: Vector2, origine: Vector2, direction_du_lion: int) -> void:
	var direction_recul := Vector2(-direction_du_lion, 0.0)
	if origine.is_finite():
		direction_recul = (centre - origine).normalized()
		if direction_recul.length() < 0.1:
			direction_recul = Vector2(-direction_du_lion, 0.0)
	recul = direction_recul * force_recul
```

(`PareChocs.bloquer` n'existe qu'en Task 3 : jusque-là, la docstring nomme ce que sera la suite du pas ; aucun code n'en dépend.)

Dans `Scripts/Lion.gd` :

3a. Remplacer :

```gdscript
@export var speed: float = 350.0
@export var acceleration: float = 2400.0
@export var force_recul: float = 700.0
@export var inclinaison_max: float = 0.14  # radians
```

par :

```gdscript
@export var inclinaison_max: float = 0.14  # radians
```

3b. Remplacer :

```gdscript
var zones_contact: Array[Area2D] = []
var _vitesse := Vector2.ZERO
var _recul := Vector2.ZERO
var _temps := 0.0  # secondes de jeu écoulées pour ce lion (ticks physiques)
```

par :

```gdscript
var zones_contact: Array[Area2D] = []
## Vitesse commandée et recul du lion (logique pure) : ce que `avancer` fait avancer d'un pas.
var deplacement := DeplacementLion.new()
var _temps := 0.0  # secondes de jeu écoulées pour ce lion (ticks physiques)
```

3c. Remplacer :

```gdscript
	var input_vector := _direction_voulue()

	if input_vector.x != 0:
		direction_du_lion = 1 if input_vector.x > 0 else -1  # le setter réoriente le lion

	_vitesse = _vitesse.move_toward(input_vector * speed, acceleration * delta)
	_recul = _recul.move_toward(Vector2.ZERO, acceleration * 1.5 * delta)
	velocity = _bloquer_contre_les_lions(_vitesse + _recul)
	move_and_slide()
	_animer_deplacement(delta)

	var screen_rect := get_viewport_rect()
```

par :

```gdscript
	avancer(_direction_voulue(), delta)
	_animer_deplacement(delta)
	_signaler_vomi_sur_les_lions()


## Un pas de déplacement du lion vers `direction` (longueur 1 au plus), de `delta` secondes : son
## orientation, sa vitesse (commandée, recul, contacts avec les autres lions), `move_and_slide`, puis
## les bords de l'écran. Le seul chemin du déplacement sur l'hôte (tick physique) ; la prédiction du
## lion local (phase 16) rejouera les mêmes pas, ses commandes en main.
func avancer(direction: Vector2, delta: float) -> void:
	if direction.x != 0:
		direction_du_lion = 1 if direction.x > 0 else -1  # le setter réoriente le lion
	velocity = _bloquer_contre_les_lions(deplacement.vitesse_du_pas(direction, delta))
	move_and_slide()
	var screen_rect := get_viewport_rect()
```

3d. Remplacer :

```gdscript
	global_position.x = x_borne
	global_position.y = y_borne
	_signaler_vomi_sur_les_lions()
```

par :

```gdscript
	global_position.x = x_borne
	global_position.y = y_borne
```

3e. Remplacer :

```gdscript
func _suivre_l_hote(delta: float) -> void:
	_vitesse = velocity
```

par :

```gdscript
func _suivre_l_hote(delta: float) -> void:
	deplacement.vitesse = velocity
```

3f. Remplacer :

```gdscript
	var cible: float = (_vitesse.x / speed) * inclinaison_max * signf(sprite.scale.x)
	sprite.rotation = lerp(sprite.rotation, cible, min(1.0, 10.0 * delta))
	var en_mouvement := _vitesse.length() > speed * 0.2
```

par :

```gdscript
	var cible: float = (deplacement.vitesse.x / deplacement.speed) * inclinaison_max * signf(sprite.scale.x)
	sprite.rotation = lerp(sprite.rotation, cible, min(1.0, 10.0 * delta))
	var en_mouvement := deplacement.vitesse.length() > deplacement.speed * 0.2
```

3g. Remplacer :

```gdscript
func _on_etourdi(origine: Vector2, barbouillage: Color) -> void:
	_vitesse = Vector2.ZERO
```

par :

```gdscript
func _on_etourdi(origine: Vector2, barbouillage: Color) -> void:
	deplacement.arreter()
```

3h. Remplacer :

```gdscript
func _reculer(origine: Vector2) -> void:
	var direction_recul := Vector2(-direction_du_lion, 0.0)
	if origine.is_finite():
		direction_recul = (global_position + CENTRE - origine).normalized()
		if direction_recul.length() < 0.1:
			direction_recul = Vector2(-direction_du_lion, 0.0)
	_recul = direction_recul * force_recul
```

par :

```gdscript
func _reculer(origine: Vector2) -> void:
	deplacement.repousser(global_position + CENTRE, origine, direction_du_lion)
```

3i. Remplacer :

```gdscript
	var vers_autre := _vitesse.dot(-normale)
	if vers_autre > 0.0:
		_vitesse += normale * vers_autre
```

par :

```gdscript
	var vers_autre := deplacement.vitesse.dot(-normale)
	if vers_autre > 0.0:
		deplacement.vitesse += normale * vers_autre
```

3j. Remplacer `	_recul += normale * approche * facteur_choc` par `	deplacement.recul += normale * approche * facteur_choc`, et `		var vitesse_ecartement: float = minf(maxf(enfoncement, 0.0) * raideur_choc, speed)` par `		var vitesse_ecartement: float = minf(maxf(enfoncement, 0.0) * raideur_choc, deplacement.speed)`.

Expected : `grep -n "_vitesse\|_recul\b\|\bspeed\b\|acceleration\|force_recul" Scripts/Lion.gd` ne montre plus que les trois lignes `deplacement.speed` (deux dans `_animer_deplacement`, une dans `_bloquer_contre_les_lions`).

- [ ] **Step 4 : les tests passent, la trace ne change pas**

Run : `godot --headless --import .`, puis les unitaires, le smoke test, le test de bataille, puis la trace (Global Constraints).
Expected (mesuré) : `== 0 échec(s) ==` partout, dont « -- Déplacement d'un lion (logique pure) » (8 ✅ : « … (40.0 px/s) », « … ((350.0, 0.0)) », « … en 12 ticks, et le lion s'arrête ») et, dans le smoke test, « (pré-condition) chaque lion a son propre déplacement … », « un pas vers la droite : … (0.667 px) », « un pas vers la gauche retourne le lion et sa gerbe », « un pas hors de l'écran le ramène au bord, sans vitesse fantôme ((0.0, 0.0)) » ; la trace : deux passages consécutifs identiques à `$TMPDIR/trace_reference.txt`.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/DeplacementLion.gd Scripts/DeplacementLion.gd.uid Scripts/Lion.gd tests/unitaires.gd tests/smoke_test.gd tests/bataille_test.gd
git commit -m "Lion : le déplacement en logique pure (DeplacementLion : vitesse commandée, recul) et le pas Lion.avancer, seul chemin du déplacement sur l'hôte, que rejouera la prédiction ; comportement identique (trace des lions inchangée) ; tests unitaires du déplacement, smoke test du pas

<ligne fournie par l'environnement>"
```

---

### Task 3 : le pare-chocs (`PareChocs`)

**Files:**
- Create: `Scripts/PareChocs.gd` (+ `.uid`)
- Modify: `Scripts/Lion.gd` (exports des chocs, `pare_chocs`, `_rayon_choc`, `temps`, `_derniers_chocs`, `_ready`, `_physics_process`, `avancer`, `_animer_deplacement`, `_tourner_etoiles`, fonctions des chocs)
- Modify: `Scenes/Lion.tscn` (script du nœud `PareChocs`)
- Test: `tests/smoke_test.gd` (un accès réécrit)

**Interfaces:**
- Consumes : Task 2 (`Lion.deplacement`, `DeplacementLion.vitesse`, `recul`, `speed`).
- Produces : `class_name PareChocs extends Area2D` (script du nœud `PareChocs`) : `@export var facteur_choc`, `raideur_choc`, `approche_min_choc`, `delai_entre_chocs` (mêmes valeurs), `var rayon: float` (45), `func bloquer(v: Vector2) -> Vector2` ; `Lion.pare_chocs: PareChocs`, `var Lion.temps: float` (public), `func Lion.secouer() -> void`.

- [ ] **Step 1 : le test**

Dans `tests/smoke_test.gd` :

```bash
perl -pi -e 's/\._rayon_choc\b/.pare_chocs.rayon/g' tests/smoke_test.gd
grep -n "pare_chocs\.rayon" tests/smoke_test.gd
```

Expected : une ligne (`and is_equal_approx(lr.pare_chocs.rayon, 45.0) and lr.get_node("CollisionShape2D").shape.radius > 60.0,`).

- [ ] **Step 2 : le test échoue**

Run : le smoke test, sous `timeout -k 5 60`. Expected : `SCRIPT ERROR: Invalid access to property or key 'rayon' on a base object of type 'Area2D'.` (le nœud `PareChocs` n'a pas encore de script), puis `code 124`, sans ligne `== n échec(s) ==`.

- [ ] **Step 3 : le pare-chocs**

Créer `Scripts/PareChocs.gd` :

```gdscript
class_name PareChocs
extends Area2D
## Le pare-chocs d'un lion, ses auto-tamponneuses (spec §5) : un cercle de 45 px (au lieu des 63 px
## du corps) sur la couche des lions (couche 5), qui ne voit que les pare-chocs des autres lions.
## Au premier contact avec un autre lion, la part de la vitesse commandée qui pointait vers lui est
## annulée (sinon la commande maintenue y ramène aussitôt et re-déclenche un choc à chaque frame,
## ~7/s en pratique) : le lion doit réaccélérer avant de retraverser. Le choc n'est compté, secoué et
## signalé aux règles que si l'approche était assez rapide et que le délai anti-rafale est passé avec
## cet autre lion (un lion étourdi reste poussable). Pendant le contact, `bloquer` retire de la vitesse
## du lion ce qui l'enfoncerait dans l'autre et écarte deux lions qui se chevauchent.
## Seul l'hôte signale un choc aux règles. Sur un client, le contact de deux répliques ne fait que
## secouer leur sprite : leur position et leur vitesse viennent de l'hôte (la prédiction du lion
## local, en phase 16, y reprendra le recul et le blocage).

## Recul de chaque lion au choc = vitesse d'approche relative × facteur_choc.
@export var facteur_choc: float = 1.2
## Vitesse d'écartement de deux lions qui se chevauchent, par pixel d'enfoncement.
@export var raideur_choc: float = 8.0
## Vitesse d'approche minimale (px/s) pour qu'un contact compte comme un choc ; en dessous,
## les lions se bloquent quand même (`bloquer`), sans secousse ni décompte.
@export var approche_min_choc: float = 100.0
## Délai minimal entre deux chocs comptés avec le même autre lion, en secondes de jeu, pour
## qu'une poussée continue ne rafale pas les chocs (la commande maintenue ramène aussitôt l'un vers
## l'autre).
@export var delai_entre_chocs: float = 0.3

## Rayon du pare-chocs (celui de sa forme).
@onready var rayon: float = ($CollisionShape2D.shape as CircleShape2D).radius
@onready var _lion: Lion = get_parent()

## Instant (`Lion.temps`, en secondes de jeu) du dernier choc compté avec chaque autre lion, par
## identifiant d'instance du lion ; entrées des lions libérés nettoyées à la volée. Le temps de jeu,
## pas l'horloge murale : une frame qui rame ou un test en `--fixed-fps` ne change rien au décompte.
var _derniers_chocs: Dictionary = {}


func _ready() -> void:
	area_entered.connect(_on_area_entered)


## Pendant le contact, la vitesse `v` du lion ne l'enfonce pas dans un autre lion (la part dirigée
## vers lui est annulée), et deux lions qui se chevauchent s'écartent.
func bloquer(v: Vector2) -> Vector2:
	for zone in get_overlapping_areas():
		var autre := zone.get_parent() as Lion
		if autre == null or autre == _lion:
			continue
		var normale := _normale_de_choc(autre)
		var vers_autre := v.dot(-normale)
		if vers_autre > 0.0:
			v += normale * vers_autre
		var enfoncement := 2.0 * rayon - global_position.distance_to(autre.pare_chocs.global_position)
		var vitesse_ecartement: float = minf(maxf(enfoncement, 0.0) * raideur_choc, _lion.deplacement.speed)
		v += normale * vitesse_ecartement
	return v


func _on_area_entered(zone: Area2D) -> void:
	var autre := zone.get_parent() as Lion
	if autre == null or autre == _lion:
		return
	var deplacement := _lion.deplacement
	var normale := _normale_de_choc(autre)
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


## Entrées du dictionnaire des délais anti-rafale dont l'autre lion n'existe plus (déconnexion,
## fin de manche) : nettoyées à la volée, jamais par une passe périodique dédiée.
func _nettoyer_derniers_chocs() -> void:
	for id in _derniers_chocs.keys():
		if instance_from_id(id) == null:
			_derniers_chocs.erase(id)


## Direction de l'autre lion vers celui-ci ; deux lions superposés s'écartent quand même,
## chacun de son côté.
func _normale_de_choc(autre: Lion) -> Vector2:
	var ecart := global_position - autre.pare_chocs.global_position
	if ecart.length() > 0.01:
		return ecart.normalized()
	return Vector2.LEFT if _lion.get_instance_id() < autre.get_instance_id() else Vector2.RIGHT
```

(Les identifiants comparés et les clés du délai anti-rafale restent ceux des **lions**, pas du pare-chocs : `_lion.get_instance_id()`, `autre.get_instance_id()`.)

Dans `Scripts/Lion.gd` :

3a. Remplacer :

```gdscript
@export var inclinaison_max: float = 0.14  # radians
## Auto-tamponneuses : recul de chaque lion = vitesse d'approche relative × facteur_choc.
@export var facteur_choc: float = 1.2
## Vitesse d'écartement de deux lions qui se chevauchent, par pixel d'enfoncement.
@export var raideur_choc: float = 8.0
## Vitesse d'approche minimale (px/s) pour qu'un contact compte comme un choc ; en dessous,
## les lions se bloquent quand même (`_bloquer_contre_les_lions`), sans secousse ni décompte.
@export var approche_min_choc: float = 100.0
## Délai minimal entre deux chocs comptés avec le même autre lion, en secondes de jeu, pour
## qu'une poussée continue ne rafale pas les chocs (la commande maintenue ramène aussitôt l'un vers
## l'autre).
@export var delai_entre_chocs: float = 0.3
```

par :

```gdscript
@export var inclinaison_max: float = 0.14  # radians
```

3b. Remplacer :

```gdscript
@onready var pare_chocs: Area2D = $PareChocs
@onready var _rayon_choc: float = ($PareChocs/CollisionShape2D.shape as CircleShape2D).radius
```

par :

```gdscript
@onready var pare_chocs: PareChocs = $PareChocs
```

3c. Remplacer :

```gdscript
var _temps := 0.0  # secondes de jeu écoulées pour ce lion (ticks physiques)
```

par :

```gdscript
## Secondes de jeu écoulées pour ce lion (ticks physiques) : trot, étoiles, délai entre deux chocs.
var temps := 0.0
```

3d. Remplacer :

```gdscript
var _rng := RandomNumberGenerator.new()
## Instant (`_temps`, en secondes de jeu) du dernier choc compté avec chaque autre lion, par
## identifiant d'instance ; entrées des lions libérés nettoyées à la volée. Le temps de jeu, pas
## l'horloge murale : une frame qui rame ou un test en `--fixed-fps` ne change rien au décompte.
var _derniers_chocs: Dictionary = {}
```

par :

```gdscript
var _rng := RandomNumberGenerator.new()
```

3e. Supprimer la ligne `	pare_chocs.area_entered.connect(_on_pare_chocs_area_entered)` de `_ready` (le pare-chocs se branche lui-même, dans son `_ready`, avant celui du lion ; il est seul sur ce signal).

3f. Remplacer `	_temps += delta` par `	temps += delta` ; `	velocity = _bloquer_contre_les_lions(deplacement.vitesse_du_pas(direction, delta))` par `	velocity = pare_chocs.bloquer(deplacement.vitesse_du_pas(direction, delta))` ; `	var bob := sin(_temps * 14.0) * 3.0 if en_mouvement else 0.0` par `	var bob := sin(temps * 14.0) * 3.0 if en_mouvement else 0.0` ; `		var angle := _temps * VITESSE_ETOILES + TAU * i / nb` par `		var angle := temps * VITESSE_ETOILES + TAU * i / nb`.

3g. Remplacer (le choc et le nettoyage, jusqu'à la docstring de `_barbouillage_actif` exclue) :

```gdscript
## Auto-tamponneuses, à chaque contact : la part de la vitesse commandée qui pointait vers
## l'autre lion est annulée (sinon la commande maintenue y ramène aussitôt et re-déclenche un
## choc à chaque frame, ~7/s en pratique) ; le lion doit donc réaccélérer avant de retraverser.
## Le choc n'est compté, secoué et signalé aux règles que si l'approche était assez rapide et
## que le délai anti-rafale est passé avec cet autre lion (un lion étourdi reste poussable).
func _on_pare_chocs_area_entered(zone: Area2D) -> void:
	var autre := zone.get_parent() as Lion
	if autre == null or autre == self:
		return
	var normale := _normale_de_choc(autre)
	var approche := (velocity - autre.velocity).dot(-normale)
	var vers_autre := deplacement.vitesse.dot(-normale)
	if vers_autre > 0.0:
		deplacement.vitesse += normale * vers_autre
	if approche < approche_min_choc:
		return
	_nettoyer_derniers_chocs()
	var dernier: float = _derniers_chocs.get(autre.get_instance_id(), -1.0)
	if dernier >= 0.0 and _temps - dernier < delai_entre_chocs:
		return
	_derniers_chocs[autre.get_instance_id()] = _temps
	deplacement.recul += normale * approche * facteur_choc
	_secousse_restante = DUREE_SECOUSSE
	# Un seul signalement par choc : celui des deux lions dont l'identifiant est le plus petit.
	if multiplayer.is_server() and get_instance_id() < autre.get_instance_id():
		GameState.regles.choc_entre_lions(joueur, autre.joueur)


## Entrées du dictionnaire des délais anti-rafale dont l'autre lion n'existe plus (déconnexion,
## fin de manche) : nettoyées à la volée, jamais par une passe périodique dédiée.
func _nettoyer_derniers_chocs() -> void:
	for id in _derniers_chocs.keys():
		if instance_from_id(id) == null:
			_derniers_chocs.erase(id)


```

par :

```gdscript
## Petite secousse du sprite, au choc avec un autre lion (`PareChocs`) ; pas de secousse d'écran.
func secouer() -> void:
	_secousse_restante = DUREE_SECOUSSE


```

3h. Supprimer, juste avant `func _on_crans_changes(_crans: int) -> void:`, les deux fonctions de blocage (elles vivent dans `PareChocs`) :

```gdscript
## Pendant le contact, un lion ne s'enfonce pas dans l'autre (la part de sa vitesse dirigée
## vers lui est annulée), et deux lions qui se chevauchent s'écartent.
func _bloquer_contre_les_lions(v: Vector2) -> Vector2:
	for zone in pare_chocs.get_overlapping_areas():
		var autre := zone.get_parent() as Lion
		if autre == null or autre == self:
			continue
		var normale := _normale_de_choc(autre)
		var vers_autre := v.dot(-normale)
		if vers_autre > 0.0:
			v += normale * vers_autre
		var enfoncement := 2.0 * _rayon_choc - pare_chocs.global_position.distance_to(autre.pare_chocs.global_position)
		var vitesse_ecartement: float = minf(maxf(enfoncement, 0.0) * raideur_choc, deplacement.speed)
		v += normale * vitesse_ecartement
	return v


## Direction de l'autre lion vers celui-ci ; deux lions superposés s'écartent quand même,
## chacun de son côté.
func _normale_de_choc(autre: Lion) -> Vector2:
	var ecart := pare_chocs.global_position - autre.pare_chocs.global_position
	if ecart.length() > 0.01:
		return ecart.normalized()
	return Vector2.LEFT if get_instance_id() < autre.get_instance_id() else Vector2.RIGHT


```

Expected : `grep -n "_temps\|_derniers\|_rayon_choc\|_bloquer\|_normale\|facteur_choc\|raideur\|_on_pare_chocs" Scripts/Lion.gd` ne sort rien.

Dans `Scenes/Lion.tscn` :

3i. Remplacer `[gd_scene load_steps=14 format=3 uid="uid://dmayuumv4a1gh"]` par `[gd_scene load_steps=15 format=3 uid="uid://dmayuumv4a1gh"]`.

3j. Remplacer :

```text
[ext_resource type="Texture2D" uid="uid://dy0pggnw08ymx" path="res://Assets/Sprites/etoile.png" id="10_etoile"]
```

par :

```text
[ext_resource type="Texture2D" uid="uid://dy0pggnw08ymx" path="res://Assets/Sprites/etoile.png" id="10_etoile"]
[ext_resource type="Script" path="res://Scripts/PareChocs.gd" id="11_parechocs"]
```

(sans `uid` : Godot résout le script par son chemin ; le `.uid` du script, généré par l'import, est commité avec lui.)

3k. Remplacer :

```text
[node name="PareChocs" type="Area2D" parent="."]
position = Vector2(68, 66)
collision_layer = 16
collision_mask = 16
```

par :

```text
[node name="PareChocs" type="Area2D" parent="."]
position = Vector2(68, 66)
collision_layer = 16
collision_mask = 16
script = ExtResource("11_parechocs")
```

- [ ] **Step 4 : les tests passent, la trace ne change pas**

Run : `godot --headless --import .` (aucune `SCRIPT ERROR`), puis le smoke test, le test de bataille, puis la trace.
Expected (mesuré) : `== 0 échec(s) ==`, dont « les lions se heurtent sur leur couche dédiée, à 45 px ; … », « un choc est compté une fois, pour les deux lions », « une poussée continue de 2 s ne rafale pas les chocs », « deux chocs à une demi-seconde de jeu d'écart comptent tous les deux (2, 2) » (bataille) ; la trace : deux passages consécutifs identiques à la référence.

- [ ] **Step 5 : Commit**

```bash
git add Scripts/PareChocs.gd Scripts/PareChocs.gd.uid Scripts/Lion.gd Scenes/Lion.tscn tests/smoke_test.gd
git commit -m "Lion : le pare-chocs devient un composant (PareChocs, script du nœud PareChocs : chocs, délai anti-rafale, blocage, réglages exportés) ; Lion.temps public, Lion.secouer ; comportement identique (trace des lions inchangée)

<ligne fournie par l'environnement>"
```

---

### Task 4 : la gerbe (`GerbeLion`)

**Files:**
- Create: `Scripts/GerbeLion.gd` (+ `.uid`)
- Modify: `Scripts/Lion.gd` (réécrit entier, sa forme finale)
- Modify: `Scenes/Lion.tscn` (nœud `Gerbe`)
- Modify: `Scripts/GerbeTraceuse.gd` (un commentaire)
- Test: `tests/smoke_test.gd`, `tests/bataille_test.gd` (accès réécrits)

**Interfaces:**
- Consumes : Tasks 2 et 3.
- Produces : `class_name GerbeLion extends Node2D` (nœud `Gerbe`) : les constantes de la gerbe (`ANGLE_GERBE_DEG`, …, `BOUCHE_X_DROITE`, `BOUCHE_X_GAUCHE`, `COUCHE_CORPS_LIONS`), `@export var vomi_container: Node2D`, `traceuse: Area2D`, `traceuse_shape: CollisionShape2D`, `bouche: Marker2D`, `var zones_contact: Array[Area2D]`, `func preparer()`, `orienter()`, `reconstruire()`, `placer_traceuse()`, `appliquer_taille_particules()`, `demarrer()`, `arreter()`, `signaler_vomi_sur_les_lions()` ; `Lion.gerbe: GerbeLion`. `Lion.demarrer_vomi()`, `arreter_vomi()`, `appliquer_apparence()` restent publics.

- [ ] **Step 1 : les tests**

```bash
perl -pi -e 's/\.traceuse_shape\b/.gerbe.traceuse_shape/g; s/\.vomi_container\b/.gerbe.vomi_container/g; s/\.zones_contact\b/.gerbe.zones_contact/g; s/\.gerbe_traceuse\b/.gerbe.traceuse/g; s/\b(repl|lr)\.bouche\b/$1.gerbe.bouche/g; s/\b(repl|lr)\.BOUCHE_X_GAUCHE\b/$1.gerbe.BOUCHE_X_GAUCHE/g' tests/smoke_test.gd tests/bataille_test.gd
grep -c "\.gerbe\." tests/smoke_test.gd tests/bataille_test.gd
grep -n "traceuse_shape\|vomi_container\|zones_contact\|gerbe_traceuse\|\.bouche\|BOUCHE" tests/*.gd | grep -v "\.gerbe\."
```

Expected : `tests/smoke_test.gd:28`, `tests/bataille_test.gd:1` ; la dernière commande ne sort rien.

- [ ] **Step 2 : les tests échouent**

Run : le smoke test, sous `timeout -k 5 60`. Expected : `SCRIPT ERROR: Invalid access to property or key 'gerbe' on a base object of type 'CharacterBody2D (Lion)'.` (dès la section solo, vers la ligne 245), puis `code 124`, sans ligne `== n échec(s) ==`.

- [ ] **Step 3 : la gerbe**

Créer `Scripts/GerbeLion.gd` :

```gdscript
class_name GerbeLion
extends Node2D
## La gerbe d'un lion : un émetteur de particules par couleur débloquée (en bataille, les trois
## nuances du joueur), en éventail, partant de la bouche à 45° vers le bas ; la traceuse de peinture
## au point de chute, son rayon selon les crans (16 px au premier, 5 px de plus par cran, 46 px au
## plus) et la gerbe XXL ; les zones de contact le long de la parabole, avec la même physique que les
## particules, qui signalent aux règles de l'hôte les autres lions que la gerbe touche.
## Nœud posé à l'origine du lion : ses zones de contact (ses enfants, créées par le code) sont dans le
## repère du lion, comme la bouche, les émetteurs et la traceuse (des nœuds du lion, que la scène lui
## donne). Le lion la prépare (`preparer`), la réoriente (`orienter`), la reconstruit quand son joueur
## débloque une couleur (`reconstruire`), la fait partir et l'arrête (`demarrer`, `arreter`).

const ANGLE_GERBE_DEG := 45.0
const ECART_EVENTAIL_DEG := 24.0
const VITESSE_GERBE := 320.0
const GRAVITE_GERBE := 300.0
const DUREE_GERBE := 0.6
const PARTICULES_PAR_COULEUR := 400
const RAYON_TRACEUSE := Vector2i(16, 46)  # min, max
const FACTEUR_BONUS := 2.0
const TEXTURE_PARTICULE := preload("res://Assets/Sprites/circle_white.png")
const BOUCHE_X_DROITE := 89.0
const BOUCHE_X_GAUCHE := 47.0
const PAS_RAYON_PAR_CRAN := 5
const NB_ZONES_CONTACT := 3
const RAYON_ZONE_CONTACT := 22.0
const COUCHE_CORPS_LIONS := 1  # couche du corps des lions, celle que détectent ennemis et pastilles

## Les nœuds du lion que la gerbe place et anime (donnés par `Scenes/Lion.tscn`).
@export var vomi_container: Node2D
@export var traceuse: Area2D
@export var traceuse_shape: CollisionShape2D
@export var bouche: Marker2D

## Zones de contact de la gerbe, de la bouche au point de chute (la dernière y rejoint la traceuse).
var zones_contact: Array[Area2D] = []

@onready var _lion: Lion = get_parent()


## Appelé une fois par le lion, dans son `_ready` : la forme de la traceuse de Lion.tscn est partagée
## par toutes les instances, chaque lion a besoin de son propre rayon ; puis les zones de contact.
func preparer() -> void:
	traceuse_shape.shape = traceuse_shape.shape.duplicate()
	_creer_zones_contact()


## Déplace la bouche du côté où regarde le lion, puis réoriente émetteurs, traceuse et zones.
func orienter() -> void:
	bouche.position.x = BOUCHE_X_DROITE if _lion.direction_du_lion > 0 else BOUCHE_X_GAUCHE
	vomi_container.position = bouche.position
	_orienter_emetteurs()
	placer_traceuse()


## Reconstruit un émetteur par couleur débloquée (en bataille, les trois nuances du joueur,
## débloquées dès le départ : voir `Regles.couleurs_de_depart`).
func reconstruire() -> void:
	for child in vomi_container.get_children():
		vomi_container.remove_child(child)
		child.queue_free()

	for couleur in _lion.joueur.couleurs_debloquees:
		var gradient := Gradient.new()
		gradient.set_color(0, couleur)
		gradient.set_color(1, Color(couleur, 0.0))
		gradient.add_point(0.75, couleur)
		var gradient_texture := GradientTexture1D.new()
		gradient_texture.gradient = gradient

		var material := ParticleProcessMaterial.new()
		material.color_ramp = gradient_texture
		material.spread = 6.0
		material.initial_velocity_min = VITESSE_GERBE * 0.9
		material.initial_velocity_max = VITESSE_GERBE * 1.1
		material.gravity = Vector3(0, GRAVITE_GERBE, 0)
		material.scale_min = 0.6 * _facteur_bonus()
		material.scale_max = 1.4 * _facteur_bonus()

		var emitter := GPUParticles2D.new()
		emitter.texture = TEXTURE_PARTICULE
		emitter.process_material = material
		emitter.amount = PARTICULES_PAR_COULEUR
		emitter.lifetime = DUREE_GERBE
		emitter.emitting = _lion.est_en_train_de_vomir
		vomi_container.add_child(emitter)

	_orienter_emetteurs()
	placer_traceuse()


## Traceuse au point de chute ; rayon de peinture selon les crans et le bonus. Zones de contact
## réparties sur la parabole.
func placer_traceuse() -> void:
	traceuse.position = _point_de_gerbe(DUREE_GERBE)
	if traceuse_shape.shape is CircleShape2D:
		var rayon: float = clamp(RAYON_TRACEUSE.x + (_lion.joueur.crans - 1) * PAS_RAYON_PAR_CRAN, RAYON_TRACEUSE.x, RAYON_TRACEUSE.y)
		traceuse_shape.shape.radius = rayon * _facteur_bonus()
	for i in range(zones_contact.size()):
		zones_contact[i].position = _point_de_gerbe(DUREE_GERBE * (i + 1) / zones_contact.size())
		(zones_contact[i].get_child(0).shape as CircleShape2D).radius = RAYON_ZONE_CONTACT * _facteur_bonus()


## Gerbe XXL (ou sa fin) : particules plus grosses ou normales.
func appliquer_taille_particules() -> void:
	for emitter in vomi_container.get_children():
		var mat := emitter.process_material as ParticleProcessMaterial
		if mat != null:
			mat.scale_min = 0.6 * _facteur_bonus()
			mat.scale_max = 1.4 * _facteur_bonus()


## La gerbe part : la traceuse et les zones de contact surveillent, les émetteurs émettent.
func demarrer() -> void:
	traceuse.monitoring = true
	for zone in zones_contact:
		zone.monitoring = true
	for emitter in vomi_container.get_children():
		emitter.emitting = true


func arreter() -> void:
	traceuse.monitoring = false
	for zone in zones_contact:
		zone.monitoring = false
	for emitter in vomi_container.get_children():
		emitter.emitting = false


## Sur l'hôte : chaque autre lion que touche la gerbe est signalé aux règles, à chaque frame
## de contact (les règles ignorent un lion déjà étourdi ou immunisé).
func signaler_vomi_sur_les_lions() -> void:
	if not _lion.est_en_train_de_vomir or not multiplayer.is_server():
		return
	for zone in zones_contact:
		for corps in zone.get_overlapping_bodies():
			var victime := corps as Lion
			if victime != null and victime != _lion:
				GameState.regles.lion_touche_par_vomi(victime.joueur, _lion.joueur, zone.global_position)


func _facteur_bonus() -> float:
	return FACTEUR_BONUS if _lion.joueur.bonus_actif() else 1.0


func _angle_gerbe(index: int, count: int) -> float:
	var base := ANGLE_GERBE_DEG if _lion.direction_du_lion > 0 else 180.0 - ANGLE_GERBE_DEG
	var offset: float = lerp(-ECART_EVENTAIL_DEG / 2, ECART_EVENTAIL_DEG / 2, float(index) / max(count - 1, 1))
	return deg_to_rad(base + offset * _lion.direction_du_lion)


## Position, dans le repère du lion, d'une particule tirée à 45° après `t` secondes de vol
## (même physique que le ParticleProcessMaterial). `t = DUREE_GERBE` : le point de chute.
func _point_de_gerbe(t: float) -> Vector2:
	var v := Vector2.from_angle(deg_to_rad(ANGLE_GERBE_DEG)) * VITESSE_GERBE
	var point := Vector2(v.x * t, v.y * t + 0.5 * GRAVITE_GERBE * t * t)
	point.x *= _lion.direction_du_lion
	return bouche.position + point


## Zones qui détectent le corps des autres lions sur la trajectoire de la gerbe, pendant le
## vomi. Créées par le code : chaque lion a ses propres formes (leur rayon suit son bonus).
func _creer_zones_contact() -> void:
	for i in range(NB_ZONES_CONTACT):
		var zone := Area2D.new()
		zone.name = "ZoneContact%d" % (i + 1)
		zone.collision_layer = 0  # rien ne la détecte (ennemis, pastilles, ville)
		zone.collision_mask = COUCHE_CORPS_LIONS
		zone.monitorable = false
		zone.monitoring = false
		var forme := CollisionShape2D.new()
		forme.shape = CircleShape2D.new()
		zone.add_child(forme)
		add_child(zone)
		zones_contact.append(zone)


func _orienter_emetteurs() -> void:
	var emitters := vomi_container.get_children()
	for index in range(emitters.size()):
		var mat := emitters[index].process_material as ParticleProcessMaterial
		if mat != null:
			var angle := _angle_gerbe(index, emitters.size())
			mat.direction = Vector3(cos(angle), sin(angle), 0)
```

Remplacer tout le contenu de `Scripts/Lion.gd` par sa forme finale :

```gdscript
class_name Lion
extends CharacterBody2D
## Le lion : son joueur et ses commandes, son déplacement, son vomi ; en bataille, crinière à la
## couleur de son joueur, pseudo au-dessus de la tête, étourdissement. Trois composants (phase 15 bis) :
## - `deplacement` (`DeplacementLion`, logique pure) : vitesse commandée et recul, dont `avancer` fait
##   un pas par tick physique sur l'hôte (la prédiction du lion local, phase 16, rejouera ces pas) ;
## - `pare_chocs` (`PareChocs`, le nœud `PareChocs`) : les auto-tamponneuses (chocs, blocage) ;
## - `gerbe` (`GerbeLion`, le nœud `Gerbe`) : émetteurs, traceuse de peinture au point de chute et
##   zones de contact le long de la parabole.
## Le lion écoute son joueur et répartit ses réactions entre eux ; la présentation (teinte, pseudo,
## étoiles, barbouillage, clignotement, secousse, trot) reste ici.
## Le lion ne décide de rien : sur l'hôte, il signale aux règles les autres lions que touche
## sa gerbe et ceux qu'il percute, comme le font les ennemis et les pastilles.
## En réseau (phase 14), seul l'hôte simule les lions ; sur un client, chaque lion est une réplique
## (`_suivre_l_hote`) : position, vitesse, orientation et vomi viennent de l'hôte par son
## `MultiplayerSynchronizer` (`Synchro`), ses réactions (étourdissement, crans, gerbe XXL) par les
## signaux de son joueur, que la manche lui transmet (`Joueur.recevoir_*`).

const SHADER_TEINTE := preload("res://Shaders/Lion.gdshader")
const CENTRE := Vector2(68, 66)  # centre du corps, dans le repère du lion
const FORCE_BARBOUILLAGE := 0.7
const RAYON_ETOILES := Vector2(40, 12)
const VITESSE_ETOILES := 5.0  # radians par seconde
const DUREE_SECOUSSE := 0.25
const AMPLITUDE_SECOUSSE := 6.0

@export var inclinaison_max: float = 0.14  # radians

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var etiquette_pseudo: Label = $Pseudo
@onready var etoiles: Node2D = $Etoiles
@onready var pare_chocs: PareChocs = $PareChocs
@onready var gerbe: GerbeLion = $Gerbe

var est_en_train_de_vomir := false
## 1 = droite, -1 = gauche. Répliquée chez les clients (`Synchro`) : le setter y retourne le sprite
## et réoriente la gerbe.
var direction_du_lion: int = 1:
	set(valeur):
		if valeur == direction_du_lion:
			return
		direction_du_lion = valeur
		if is_node_ready():
			_appliquer_direction()
## Sur l'hôte, l'état de vomi du lion ; répliqué chez les clients (`Synchro`), où il fait vomir la
## réplique (particules, animation : sa traceuse ne peint pas, voir `GerbeTraceuse`).
var vomi_de_l_hote := false
## État du lion (couleurs, bonus, coups) et source de ses intentions. À fournir avant l'ajout
## à l'arbre : les lions d'une bataille les reçoivent de la scène de jeu (`Main`), en réseau par la
## `spawn_function` de son `MultiplayerSpawner`, qui les crée chez chaque poste par l'index de leur
## joueur (des commandes de ce poste pour le lion du joueur local, manuelles pour les autres, qu'en
## réseau l'hôte remplit de celles que chaque client lui envoie). À défaut (le lion de la scène, en
## solo), le joueur local et ses commandes (celles du pilote en démo).
var joueur: Joueur:
	set(valeur):
		# `is_node_ready()` vaut déjà true pendant `_ready()` lui-même (pas seulement après) :
		# le garde-fou ne bloque donc que le remplacement d'un joueur déjà fixé, pas le repli
		# par défaut fait par `_ready()` ci-dessous.
		if is_node_ready() and joueur != null:
			push_error("Lion.joueur se fixe avant l'ajout à l'arbre")
			return
		joueur = valeur
var commandes: Commandes
## Vitesse commandée et recul du lion (logique pure) : ce que `avancer` fait avancer d'un pas.
var deplacement := DeplacementLion.new()
## Secondes de jeu écoulées pour ce lion (ticks physiques) : trot, étoiles, délai entre deux chocs.
var temps := 0.0
var _clignotement: Tween
var _secousse_restante := 0.0
## Générateur propre au lion pour la secousse du sprite : ne pas consommer la séquence globale
## de `randf_range`, dont dépendent le Spawner et les ennemis.
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if joueur == null:
		joueur = GameState.joueur_local()
	if commandes == null:
		commandes = Commandes.manuelles() if GameState.demo else Commandes.locales()
	gerbe.preparer()
	joueur.couleur_debloquee.connect(_on_couleur_debloquee)
	joueur.bonus_change.connect(_on_bonus_change)
	joueur.touche.connect(_on_lion_touche)
	joueur.crans_changes.connect(_on_crans_changes)
	joueur.etourdi.connect(_on_etourdi)
	joueur.etourdissement_fini.connect(_on_etourdissement_fini)
	_appliquer_direction()
	gerbe.reconstruire()
	appliquer_apparence()


func _physics_process(delta: float) -> void:
	temps += delta
	if not multiplayer.is_server():
		_suivre_l_hote(delta)
		return
	avancer(_direction_voulue(), delta)
	_animer_deplacement(delta)
	gerbe.signaler_vomi_sur_les_lions()


## Un pas de déplacement du lion vers `direction` (longueur 1 au plus), de `delta` secondes : son
## orientation, sa vitesse (commandée, recul, contacts avec les autres lions), `move_and_slide`, puis
## les bords de l'écran. Le seul chemin du déplacement sur l'hôte (tick physique) ; la prédiction du
## lion local (phase 16) rejouera les mêmes pas, ses commandes en main.
func avancer(direction: Vector2, delta: float) -> void:
	if direction.x != 0:
		direction_du_lion = 1 if direction.x > 0 else -1  # le setter réoriente le lion
	velocity = pare_chocs.bloquer(deplacement.vitesse_du_pas(direction, delta))
	move_and_slide()
	var screen_rect := get_viewport_rect()
	var sprite_size := sprite.texture.get_size()
	var x_borne: float = clamp(global_position.x, 0, screen_rect.size.x - sprite_size.x)
	var y_borne: float = clamp(global_position.y, _marge_haute(), screen_rect.size.y - sprite_size.y)
	# Un lion plaqué contre un bord n'a plus de vitesse fantôme sur cet axe : move_and_slide()
	# ne connaît pas ce bord (ce n'est pas une collision), il ne l'a donc pas déjà annulée.
	if x_borne != global_position.x:
		velocity.x = 0.0
	if y_borne != global_position.y:
		velocity.y = 0.0
	global_position.x = x_borne
	global_position.y = y_borne


func _process(delta: float) -> void:
	if _veut_vomir():
		if not est_en_train_de_vomir:
			demarrer_vomi()
	elif est_en_train_de_vomir:
		arreter_vomi()
	if multiplayer.is_server():
		vomi_de_l_hote = est_en_train_de_vomir
	if (etoiles.visible or _barbouillage_actif()) and not joueur.est_etourdi():
		# L'étourdissement peut finir sans passer par le signal (`Joueur.reinitialiser` en plein
		# étourdissement, par exemple, qui n'émet rien) : les effets visuels se corrigent d'eux-mêmes.
		_on_etourdissement_fini()
	if etoiles.visible:
		_tourner_etoiles()
	if _secousse_restante > 0.0:
		_secousse_restante = max(0.0, _secousse_restante - delta)
		var amplitude := AMPLITUDE_SECOUSSE * _secousse_restante / DUREE_SECOUSSE
		sprite.offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * amplitude


## Hauteur gardée libre au-dessus du lion : celle de son pseudo quand il s'affiche (bataille),
## pour qu'un lion collé en haut de l'écran ne le cache pas ; aucune en solo.
func _marge_haute() -> float:
	return -etiquette_pseudo.position.y if etiquette_pseudo.visible else 0.0


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


## Sur un client, la réplique vomit quand le lion de l'hôte vomit.
func _veut_vomir() -> bool:
	if not multiplayer.is_server():
		return vomi_de_l_hote
	return GameState.pret and not joueur.est_etourdi() and commandes.vomir()


func demarrer_vomi() -> void:
	if joueur.couleurs_debloquees.is_empty():
		return
	est_en_train_de_vomir = true
	gerbe.demarrer()
	anim.play("Vomit")
	Audio.demarrer_vomi()


func arreter_vomi() -> void:
	est_en_train_de_vomir = false
	gerbe.arreter()
	anim.play("Idle")
	Audio.arreter_vomi()


## Crinière à la couleur du joueur et pseudo au-dessus de la tête. Lu une fois dans `_ready` ; à
## rappeler si la couleur ou le pseudo du joueur change ensuite (jamais en jeu : la table des joueurs
## d'une bataille est posée avant la scène de jeu, et le salon n'a pas de lion).
func appliquer_apparence() -> void:
	if not is_node_ready():
		return  # sprite et étiquette n'existent pas encore : `_ready` l'appliquera
	_appliquer_teinte()
	etiquette_pseudo.text = joueur.pseudo
	etiquette_pseudo.add_theme_color_override("font_color", joueur.couleur)
	etiquette_pseudo.visible = joueur.a_une_couleur() and not joueur.pseudo.is_empty()


## Petite secousse du sprite, au choc avec un autre lion (`PareChocs`) ; pas de secousse d'écran.
func secouer() -> void:
	_secousse_restante = DUREE_SECOUSSE


## Un joueur sans couleur (le solo) laisse le sprite sans matériau : le lion s'affiche
## exactement comme ses sprites d'origine. Sinon, le lion crée son propre matériau (jamais
## partagé entre instances de Lion.tscn) ; il vaut pour les deux sprites, repos et vomi.
func _appliquer_teinte() -> void:
	if not joueur.a_une_couleur():
		sprite.material = null
		return
	var mat := sprite.material as ShaderMaterial
	if mat == null or mat.shader != SHADER_TEINTE:
		mat = ShaderMaterial.new()
		mat.shader = SHADER_TEINTE
		sprite.material = mat
	mat.set_shader_parameter("couleur_joueur", joueur.couleur)


## Retourne le sprite et réoriente la gerbe (bouche, émetteurs, traceuse, zones de contact).
func _appliquer_direction() -> void:
	sprite.scale.x = direction_du_lion
	gerbe.orienter()


## Penche le lion dans le sens de la course et le fait trottiner.
func _animer_deplacement(delta: float) -> void:
	var cible: float = (deplacement.vitesse.x / deplacement.speed) * inclinaison_max * signf(sprite.scale.x)
	sprite.rotation = lerp(sprite.rotation, cible, min(1.0, 10.0 * delta))
	var en_mouvement := deplacement.vitesse.length() > deplacement.speed * 0.2
	var bob := sin(temps * 14.0) * 3.0 if en_mouvement else 0.0
	sprite.position.y = lerp(sprite.position.y, 67.0 + bob, min(1.0, 12.0 * delta))


func _on_couleur_debloquee(_couleur: Color) -> void:
	gerbe.reconstruire()


func _on_crans_changes(_crans: int) -> void:
	gerbe.placer_traceuse()


func _on_bonus_change(_actif: bool) -> void:
	gerbe.placer_traceuse()
	gerbe.appliquer_taille_particules()


## Recul et clignotement pendant l'invulnérabilité qui suit un coup (solo).
func _on_lion_touche(origine: Vector2) -> void:
	Audio.jouer("mort")
	_reculer(origine)
	_clignoter(joueur.invulnerable_restant)


## Étourdi (bataille) : immobile, repoussé, tête barbouillée de la couleur de l'agresseur
## (aucune pour un ennemi), étoiles qui tournent. Le vomi s'arrête au `_process` suivant
## (`_veut_vomir` est faux pendant l'étourdissement) ; d'ici là, les règles n'ignorent un
## agresseur étourdi que depuis une frame physique antérieure (un échange simultané étourdit
## les deux lions).
func _on_etourdi(origine: Vector2, barbouillage: Color) -> void:
	deplacement.arreter()
	_reculer(origine)
	_barbouiller(barbouillage)
	etoiles.visible = true
	_tourner_etoiles()


## Fin de l'étourdissement : barbouillage et étoiles s'en vont, l'immunité clignote.
func _on_etourdissement_fini() -> void:
	_barbouiller(Color.TRANSPARENT)
	etoiles.visible = false
	_clignoter(joueur.invulnerable_restant)


func _reculer(origine: Vector2) -> void:
	deplacement.repousser(global_position + CENTRE, origine, direction_du_lion)


## Clignotement de l'invulnérabilité : le même après un coup (solo) et pour l'immunité qui suit
## un étourdissement (bataille).
func _clignoter(duree: float) -> void:
	var nb_clignotements := int(duree / 0.15)
	if nb_clignotements <= 0:
		return
	if _clignotement != null:
		_clignotement.kill()
	sprite.modulate.a = 1.0
	_clignotement = create_tween()
	for i in range(nb_clignotements):
		_clignotement.tween_property(sprite, "modulate:a", 0.25, 0.075)
		_clignotement.tween_property(sprite, "modulate:a", 1.0, 0.075)


## Toute la tête vire à `couleur` (uniformes du shader de teinte) ; une couleur transparente
## efface le barbouillage. Sans matériau (joueur sans couleur), rien à barbouiller.
func _barbouiller(couleur: Color) -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("barbouillage_couleur", couleur)
	mat.set_shader_parameter("barbouillage_force", FORCE_BARBOUILLAGE if couleur.a > 0.0 else 0.0)


## Vrai si la tête porte encore un barbouillage visible (couleur d'agresseur appliquée).
## `get_shader_parameter` renvoie `null` tant que `_barbouiller` ne l'a jamais fixé.
func _barbouillage_actif() -> bool:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return false
	var force: Variant = mat.get_shader_parameter("barbouillage_force")
	return force != null and force > 0.0


func _tourner_etoiles() -> void:
	var nb := etoiles.get_child_count()
	for i in range(nb):
		var angle := temps * VITESSE_ETOILES + TAU * i / nb
		etoiles.get_child(i).position = Vector2(cos(angle) * RAYON_ETOILES.x, sin(angle) * RAYON_ETOILES.y)
```

Ordres gardés, qui comptent pour la trace : dans `_ready`, `gerbe.preparer()` (duplication de la forme de la traceuse, puis création des zones : les mêmes ressources physiques, créées dans le même ordre qu'avant), puis les six branchements sur le joueur dans leur ordre, `_appliquer_direction()`, `gerbe.reconstruire()`, `appliquer_apparence()` ; dans `demarrer_vomi`, la surveillance et les émetteurs avant l'animation et le son (sans interaction).

Dans `Scenes/Lion.tscn` :

3a. Remplacer `[gd_scene load_steps=15 format=3 uid="uid://dmayuumv4a1gh"]` par `[gd_scene load_steps=16 format=3 uid="uid://dmayuumv4a1gh"]`.

3b. Remplacer :

```text
[ext_resource type="Script" path="res://Scripts/PareChocs.gd" id="11_parechocs"]
```

par :

```text
[ext_resource type="Script" path="res://Scripts/PareChocs.gd" id="11_parechocs"]
[ext_resource type="Script" path="res://Scripts/GerbeLion.gd" id="12_gerbe"]
```

3c. Ajouter à la fin du fichier (après les trois lignes du nœud `Synchro` ; le bloc commence par une ligne vide) :

```text

[node name="Gerbe" type="Node2D" parent="." node_paths=PackedStringArray("vomi_container", "traceuse", "traceuse_shape", "bouche")]
script = ExtResource("12_gerbe")
vomi_container = NodePath("../VomiParticlesContainer")
traceuse = NodePath("../GerbeTraceuse")
traceuse_shape = NodePath("../GerbeTraceuse/CollisionShape2D")
bouche = NodePath("../Bouche")
```

Dans `Scripts/GerbeTraceuse.gd`, remplacer `## Le rayon de peinture est celui de sa forme de collision (réglé par le lion).` par `## Le rayon de peinture est celui de sa forme de collision (réglé par la gerbe du lion, `GerbeLion`).`

- [ ] **Step 4 : les tests passent, la trace ne change pas**

Run : `godot --headless --import .` (aucune `SCRIPT ERROR`), puis les unitaires, le smoke test, le test de bataille, puis la trace.
Expected (mesuré) : `== 0 échec(s) ==` partout, dont « trois zones de contact sur la parabole, la dernière au point de chute, inertes hors du vomi », « chaque lion a ses propres formes de zones de contact », « sur un client, l'orientation reçue à l'apparition est appliquée (sprite et bouche à gauche) », « un pas vers la gauche retourne le lion et sa gerbe » ; `wc -l Scripts/Lion.gd` : 320 ; la trace : deux passages consécutifs identiques à la référence (mesuré : le premier passage après cet import a différé une fois, les suivants jamais ; Écart 6).

- [ ] **Step 5 : Commit**

```bash
git add Scripts/GerbeLion.gd Scripts/GerbeLion.gd.uid Scripts/Lion.gd Scenes/Lion.tscn Scripts/GerbeTraceuse.gd tests/smoke_test.gd tests/bataille_test.gd
git commit -m "Lion : la gerbe devient un composant (GerbeLion, nœud Gerbe : émetteurs, traceuse, zones de contact, orientation, gerbe XXL, lions touchés) ; Lion garde le joueur, les commandes, la réplication, le vomi et la présentation (320 lignes) ; comportement identique (trace des lions inchangée)

<ligne fournie par l'environnement>"
```

---

### Task 5 : le lion libéré, les preuves, les suites et le réseau

**Files:**
- Modify: `tests/smoke_test.gd` (une section avant la libération des lions de bataille)
- Modify: `Scripts/Manche.gd` (un commentaire)

**Interfaces:**
- Consumes : Tasks 1 à 4.
- Produces : la vérification « un lion libéré n'est plus abonné aux signaux de son joueur » ; les preuves S1 à S5 ; les suites vertes 5 fois, le test réseau vert 5 fois sous bash 3.2 et 5.

- [ ] **Step 1 : le lion libéré (garde-fou de non-régression)**

Dans `tests/smoke_test.gd`, remplacer :

```gdscript
	for l in lions_bataille:
		l.free()
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false

	# Territoire : la ville d'une bataille tient la grille de propriété, dans une scène propre
```

par :

```gdscript
	# Phase 15 bis : un lion libéré (départ d'un joueur, fin de manche) alors que son joueur reste
	# (GameState le garde) ne doit plus rien recevoir de lui : ni le lion ni ses composants
	var ids_lions: Array = lions_bataille.map(func(l: Node) -> int: return l.get_instance_id()) \
		+ lions_bataille.map(func(l: Node) -> int: return l.gerbe.get_instance_id()) \
		+ lions_bataille.map(func(l: Node) -> int: return l.pare_chocs.get_instance_id())
	for l in lions_bataille:
		l.free()
	var restes := 0
	for j: Joueur in [j_rouge, j_bleu]:
		for s: Signal in [j.couleur_debloquee, j.bonus_change, j.touche, j.crans_changes, j.etourdi, j.etourdissement_fini]:
			restes += s.get_connections().filter(func(c: Dictionary) -> bool: return ids_lions.has((c.callable as Callable).get_object_id())).size()
	_check(restes == 0, "un lion libéré n'est plus abonné aux signaux de son joueur (%d abonnements restants)" % restes)
	j_rouge.etourdir(1.0, 1.0, Vector2.INF, j_bleu.couleur)
	j_rouge.activer_bonus(1.0)
	j_bleu.recevoir_crans(3)
	j_bleu.recevoir_fin_etourdissement(0.0)
	GS.configurer_solo()
	GS.nouvelle_partie()
	GS.partie_en_cours = false
	GS.pret = false

	# Territoire : la ville d'une bataille tient la grille de propriété, dans une scène propre
```

(Elle passe déjà : le moteur retire les branchements d'un objet libéré. Elle garde la propriété pour les refontes suivantes, par exemple un composant qui garderait une référence ou un `RefCounted` branché au joueur ; la mutation S4 prouve qu'elle échoue quand un lion n'est pas libéré.)

Dans `Scripts/Manche.gd`, remplacer `	# `Lion._reculer` la gère), jamais bornée à `is_finite()`.` par `	# `DeplacementLion.repousser` la gère), jamais bornée à `is_finite()`.`

Run : le smoke test. Expected : `== 0 échec(s) ==`, dont « un lion libéré n'est plus abonné aux signaux de son joueur (0 abonnements restants) », sans `SCRIPT ERROR` (les signaux émis ensuite ne touchent aucun objet libéré).

- [ ] **Step 2 : Commit**

```bash
git add tests/smoke_test.gd Scripts/Manche.gd
git commit -m "Smoke test : un lion libéré n'est plus abonné aux signaux de son joueur (ni ses composants) ; Manche : commentaire du recul à jour

<ligne fournie par l'environnement>"
```

- [ ] **Step 3 : le découpage discrimine**

Chaque mutation seule, les suites indiquées et la trace (deux passages consécutifs), puis **`git checkout -- Scripts/ tests/`** avant la suivante (mesuré en préparant le plan) :
- S1 : dans `Scripts/DeplacementLion.gd`, `recul = recul.move_toward(Vector2.ZERO, acceleration * 1.5 * delta)` → `recul = recul.move_toward(Vector2.ZERO, acceleration * delta)` ⇒ unitaires : `❌ sans commande, le recul s'amortit jusqu'à zéro en 18 ticks, et le lion s'arrête` ; la trace diffère de la référence ;
- S2 : dans `Scripts/PareChocs.gd`, `_on_area_entered`, supprimer les deux lignes `if dernier >= 0.0 and _lion.temps - dernier < delai_entre_chocs:` / `return` ⇒ smoke : `❌ une poussée continue de 2 s ne rafale pas les chocs (9, 9)` ; la trace diffère ;
- S3 : dans `Scripts/GerbeLion.gd`, `preparer`, supprimer la ligne `traceuse_shape.shape = traceuse_shape.shape.duplicate()` ⇒ smoke : `❌ le bonus du joueur local ne touche pas un lion lié à un autre joueur`, `❌ une pastille donne un cran : 5 px de plus, pour ce lion seulement` ;
- S4 (par le harnais) : dans `tests/smoke_test.gd`, section de la Step 1, remplacer `		l.free()` par `		root.remove_child(l)` ⇒ `❌ un lion libéré n'est plus abonné aux signaux de son joueur (12 abonnements restants)` ;
- S5 : dans `Scripts/Lion.gd`, `avancer`, supprimer les deux lignes `if x_borne != global_position.x:` / `velocity.x = 0.0` ⇒ smoke : `❌ un pas hors de l'écran le ramène au bord, sans vitesse fantôme ((0.0, 0.0))` ; la trace diffère.

Expected ensuite : `git status --short` vide ; la trace de nouveau égale à la référence (deux passages).

- [ ] **Step 4 : les suites, 5 fois, et le réseau**

Run : 5 fois de suite chacune des trois suites Godot et la trace, puis 5 fois `bash tests/reseau/lancer.sh`, puis 5 fois `/bin/bash tests/reseau/lancer.sh` (bash 3.2 de macOS).
Expected : chaque fois `code 0` et `== 0 échec(s) ==`, aucune `SCRIPT ERROR` ni `SHADER ERROR`, la trace égale à la référence à chaque passage (après l'import, voir l'Écart 6), 10 lignes ✅ au test réseau dont « manche : barrière de chargement … » (scénario 9) et « de bout en bout : manche entière à 1 hôte et 3 clients … » (scénario 11), l'écart du départ arraché au plus 10 000 ms (mesuré en préparant le plan : unitaires 2 s, smoke test 19 s, bataille 3 s, trace 3 s, test réseau 155 s, sous bash 5 comme sous bash 3.2).

---

### Task 6 : feuille de route et spec

**Files:**
- Modify: `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md`
- Modify: `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md`

**Interfaces:**
- Consumes : Tasks 1 à 5, Écarts 1 à 8 ; la feuille de route telle que la phase 15 l'a laissée.
- Produces : ligne 15 bis ; point « avant la phase 16, après la 15 » résolu ; points des phases 16 et 17 bis qui nommaient les anciens champs et fonctions du lion, à jour ; nouveau point pour la phase 16 (la trace et la simulation non bit à bit) ; spec §3.1 et §10 à jour.

- [ ] **Step 1 : la feuille de route**

Dans `docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md` :

1a. Après la ligne du tableau qui commence par `| 15 | **Test réseau de bout en bout**` (celle que la phase 15 a écrite), ajouter la ligne :

```text
| 15 bis | **Découpage de `Lion.gd`** (avant la 16, à comportement identique) : `DeplacementLion` (logique pure : vitesse commandée, recul) et le pas `Lion.avancer`, seul chemin du déplacement sur l'hôte ; `PareChocs` (script du nœud `PareChocs` : chocs, délai anti-rafale, blocage) ; `GerbeLion` (nœud `Gerbe` : émetteurs, traceuse, zones de contact) ; `Lion` garde joueur, commandes, réplication, vomi et présentation (542 → 320 lignes). Outil de trace des lions (`tests/trace_lions.gd`, hors CI) : empreinte identique avant et après chaque étape. | ➕ `Scripts/DeplacementLion.gd` ➕ `Scripts/PareChocs.gd` ➕ `Scripts/GerbeLion.gd` ➕ `tests/trace_lions.gd` ✏️ `Scripts/Lion.gd` ✏️ `Scenes/Lion.tscn` ✏️ `Scripts/GerbeTraceuse.gd` ✏️ `Scripts/Manche.gd` ✏️ `tests/unitaires.gd` ✏️ `tests/smoke_test.gd` ✏️ `tests/bataille_test.gd` | trace inchangée, suites vertes 5 fois, test réseau vert 5 fois (bash 3.2 et 5) |
```

1b. Remplacer :

```text
  étoiles, barbouillage, clignotement). **Phase 16** : seul le lion local reprend `move_and_slide`,
  `_recul` et `_bloquer_contre_les_lions`, par sa prédiction ; les lions distants sont interpolés
```

par :

```text
  étoiles, barbouillage, clignotement). **Phase 16** : seul le lion local reprend son pas de
  déplacement (`Lion.avancer` : `DeplacementLion`, `PareChocs.bloquer`, `move_and_slide`, bords de
  l'écran, phase 15 bis), par sa prédiction ; les lions distants sont interpolés
```

1c. Remplacer :

```text
- **avant la phase 16, après la 15** : `Lion.gd` a grossi phase après phase (pare-chocs,
  présentation de l'étourdissement, zones de contact de la gerbe, réplique de la phase 14 : 530
  lignes) ; le découper en composants avant d'y ajouter la prédiction, en une étape à part
  (`Lion.gd`, `Scenes/Lion.tscn`, 2 à 3 nouveaux scripts). Pas en phase 14 : ses ajouts au lion y
  sont petits et isolés (la réplique, deux propriétés répliquées), alors que le découpage réécrit
  les fonctions que le smoke test et `tests/bataille_test.gd` lisent par dizaines de champs privés ;
  le faire après la phase 15 lui donne le filet du test réseau de bout en bout ;
```

par :

```text
- (résolu en phase 15 bis) `Lion.gd` est découpé : `DeplacementLion` (logique pure, que les tests
  unitaires nomment ; son état tient en deux vecteurs, `vitesse` et `recul`, que la prédiction pourra
  copier et restaurer pour rejouer ses commandes), `PareChocs`, `GerbeLion` ; le lion garde la
  présentation et la réplication. **Phase 16** : garder `Lion.avancer` comme seul chemin du
  déplacement (l'hôte et la prédiction), et repasser `tests/trace_lions.gd` avant et après chaque
  modification du lion (deux passages consécutifs identiques ; les deux premiers après un import
  peuvent différer, phase 15 bis, Écart 6) ;
- **phase 16** (vu en phase 15 bis) : la simulation n'est pas reproductible bit à bit d'un
  processus à l'autre dans tous les cas : l'ordre dans lequel la physique rapporte des contacts
  simultanés dépend d'identifiants d'objets (rejouer la même bataille dans le même processus donne une
  autre empreinte). La prédiction d'un client ne peut donc pas compter sur une identité exacte avec
  l'hôte, même aux mêmes commandes : la correction douce (spec §4.1) doit absorber ces écarts, et les
  tests de prédiction mesurer des écarts de position, pas des égalités ;
```

1d. Remplacer :

```text
- **phase 16** : seul le lion local simule son choc, par sa propre prédiction
  (`Lion._on_pare_chocs_area_entered` : recul, secousse) ; un lion distant ne simule jamais de
```

par :

```text
- **phase 16** : seul le lion local simule son choc, par sa propre prédiction
  (`PareChocs._on_area_entered` : recul, secousse ; phase 15 bis) ; un lion distant ne simule jamais de
```

1e. Remplacer :

```text
- **phase 17 bis** : jouer le « boing » dans `Lion._on_pare_chocs_area_entered`, sur chaque machine
```

par :

```text
- **phase 17 bis** : jouer le « boing » dans `PareChocs._on_area_entered` (à côté de `Lion.secouer`), sur chaque machine
```

- [ ] **Step 2 : la spec**

Dans `docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md` :

2a. Remplacer :

```text
| `Lion` (scène) | Déplacement, gerbe, traceuses, teinte, barbouillage. Lit un `Joueur` et une `Commandes`. Ne décide de rien : sur l'hôte, il signale aux `Regles` les lions que touche sa gerbe et ceux qu'il percute, comme les ennemis et les pastilles. | `Joueur`, `Commandes` |
```

par :

```text
| `Lion` (scène) | Déplacement, gerbe, traceuses, teinte, barbouillage. Lit un `Joueur` et une `Commandes`. Ne décide de rien : sur l'hôte, il signale aux `Regles` les lions que touche sa gerbe et ceux qu'il percute, comme les ennemis et les pastilles. Trois composants depuis la phase 15 bis : `DeplacementLion` (logique pure : vitesse commandée, recul ; le pas `Lion.avancer`, seul chemin du déplacement, que rejouera `PredictionLocale`), `PareChocs` (auto-tamponneuses) et `GerbeLion` (émetteurs, traceuse, zones de contact) ; le lion garde la présentation et la réplication. | `Joueur`, `Commandes` |
```

2b. Remplacer :

```text
- **Visuel** : `tests/screenshots.gd` étendu (salon, manche à 6 couleurs, résultats), deux vraies
```

par :

```text
- **Trace des lions** (`tests/trace_lions.gd`, phase 15 bis, hors CI) : une bataille à 4 lions, une
  partie solo et une réplique de client rejouées tick par tick (hasard semé, `--fixed-fps 60`) ; leur
  empreinte (l'état observable de chaque lion à chaque tick) prouve qu'une refonte du lion ne change
  rien. Deux passages consécutifs identiques font le verdict.
- **Visuel** : `tests/screenshots.gd` étendu (salon, manche à 6 couleurs, résultats), deux vraies
```

- [ ] **Step 3 : Commit**

```bash
git add docs/superpowers/plans/2026-09-25-multijoueur-feuille-de-route.md docs/superpowers/specs/2026-09-25-multijoueur-lan-design.md
git commit -m "Feuille de route et spec : phase 15 bis faite (Lion.gd découpé en DeplacementLion, PareChocs et GerbeLion, à comportement identique ; outil de trace des lions) ; points des phases 16 et 17 bis à jour ; simulation non reproductible bit à bit (phase 16)

<ligne fournie par l'environnement>"
```

---

## Sortie de phase

- La trace égale à la référence après chaque tâche de code et en fin de phase ; les quatre suites vertes 5 fois de suite localement, le test réseau vert 5 fois sous bash 5 et 5 fois sous bash 3.2, sans `SCRIPT ERROR` ni `SHADER ERROR`, puis le job CI vert sur la PR.
- Les preuves S1 à S5 ont donné les `❌` (et les traces différentes) attendus.
- `git diff main --stat` : les 11 fichiers des Global Constraints, les quatre `.uid`, la spec et la feuille de route ; `git diff main --stat -- tests/reseau Scripts/Reseau.gd project.godot .github` vide ; `wc -l Scripts/Lion.gd` : 320.
- Partie à la main, conseillée avant la revue : un solo (le lion bouge, vomit, débloque des couleurs, clignote après un coup) ; une bataille à deux fenêtres (`godot --path . &` deux fois) : chocs, gerbes croisées, étoile ; rien ne doit se voir différent d'avant.
- Rappeler à l'utilisateur : l'outil de trace reste hors CI (Écart 6) ; la phase 16 part de `Lion.avancer` et de `DeplacementLion`.
