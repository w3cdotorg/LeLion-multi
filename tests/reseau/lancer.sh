#!/usr/bin/env bash
# Test réseau du transport (phase 11), de la découverte (phase 12) et du salon (phase 13) : des
# postes headless sur localhost, un processus Godot par poste (tests/reseau/joueur.gd), scénario
# après scénario.
#   tests/reseau/lancer.sh [port_de_base]
# Le scénario n utilise le port port_de_base + n (défaut 17777 : jamais le 7777 d'une vraie partie)
# et, pour les balises de découverte, port_de_base + 1000 + n (jamais le 7778).
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40),
# DIFFUSION=1 (ajoute le scénario 7, balises en vraie diffusion : hors CI, où la diffusion n'a pas
# été mesurée ; le scénario 6 couvre le même chemin en envoi direct vers 127.0.0.1).
# Chaque étape s'enchaîne sur un événement observé (une ligne d'un journal, un compte de l'hôte),
# 15 s au plus (DELAI_ETAPE de joueur.gd, 150 × 0,1 s ici) ; seules restent, côté client
# (joueur.gd), de courtes fenêtres de vérification d'absence (1 s après un refus, 0,5 s avant un
# départ volontaire) : elles ne peuvent pas donner de faux rouge.
# Sortie 0 si chaque poste sort en 0, sans ❌ ni SCRIPT ERROR ni SHADER ERROR dans son journal, et
# si les comptes croisés entre postes tombent juste. Tous les processus lancés sont tués en sortie.
set -u
cd "$(dirname "$0")/../.." || exit 2

# N6 : sur un Mac sans coreutils dans le PATH, chaque poste sortirait en 127 (« timeout » introuvable)
# sans indice. `export PATH="/opt/homebrew/bin:$PATH"` avant de lancer ce script s'il manque.
command -v timeout >/dev/null || { echo "il faut la commande GNU 'timeout' (coreutils) dans le PATH" >&2; exit 2; }

GODOT="${GODOT:-godot}"
PORT_BASE="${1:-17777}"
DELAI="${DELAI:-40}"
JOURNAUX="$(mktemp -d "${TMPDIR:-/tmp}/lelion-reseau.XXXXXX")" || { echo "mktemp impossible (TMPDIR plein ou non inscriptible ?)" >&2; exit 2; }
# Délai de poignée de main de l'hôte du scénario 5, en secondes (Reseau.DELAI_POIGNEE_DE_MAIN, 3 s,
# reste celui du jeu). Deux marges en dépendent. Le rival doit être refusé avant qu'il expire :
# démarré d'avance, il part au feu, donné dans les 0,1 s qui suivent « ACCEPTE » (refus mesuré
# 0,07 à 0,16 s après), soit plus de 7,8 s de marge, sans démarrage de Godot dedans. L'hôte doit
# voir la coupure du lent dans son attente des poignées échouées (15 s depuis « HOTE PRET ») :
# 15 - 8 = 7 s pour démarrer le lent (mesuré 0,3 à 0,6 s). Plus long mange la seconde marge, plus
# court la première.
DELAI_POIGNEE_LENT=8
PIDS=()
NOMS=()
ECHECS=0

nettoyer() {
	local pid
	for pid in ${PIDS[@]+"${PIDS[@]}"}; do
		kill "$pid" 2>/dev/null
	done
	wait 2>/dev/null
}
trap nettoyer EXIT
# Deux pièges séparés (plutôt qu'un INT TERM commun) : TERM sort en 143, la convention, sans changer
# le 130 attendu sur INT. Les deux recopient les journaux (recopier_journaux, définie plus bas) :
# c'est le timeout 300 de la CI qui envoie TERM, et sans ça les journaux restaient dans le mktemp du
# runner, perdus.
trap 'echo "interrompu"; recopier_journaux; exit 130' INT
trap 'echo "interrompu"; recopier_journaux; exit 143' TERM

echec() {
	echo "  ❌ $1"
	ECHECS=$((ECHECS + 1))
}

# recopier_journaux : recopie chaque journal de poste dans la sortie du lanceur (JOURNAUX est gardé,
# pas supprimé). En CI, c'est tout ce qui reste d'un échec, y compris d'une interruption (INT/TERM,
# par exemple le timeout 300 du pas de CI) : appelée à la fois en sortie normale et depuis les pièges.
recopier_journaux() {
	echo "journaux gardés dans $JOURNAUX"
	for f in "$JOURNAUX"/*.log; do
		[ -e "$f" ] || continue
		echo "----- $(basename "$f")"
		cat "$f"
	done
}

# lancer <nom> <arguments de joueur.gd…> : un poste en arrière-plan, borné par timeout (TERM au
# bout de DELAI secondes, KILL 5 s plus tard s'il résiste).
lancer() {
	local nom="$1"
	shift
	timeout -k 5 "$DELAI" "$GODOT" --headless --script tests/reseau/joueur.gd -- "$@" >"$JOURNAUX/$nom.log" 2>&1 &
	PIDS+=("$!")
	NOMS+=("$nom")
}

# attendre_hote <nom> : attend que l'hôte écoute (ligne « HOTE PRET »), 15 s au plus.
attendre_hote() {
	local i
	for i in $(seq 1 150); do
		grep -q "HOTE PRET" "$JOURNAUX/$1.log" 2>/dev/null && return 0
		sleep 0.1
	done
	echec "l'hôte $1 n'écoute pas"
	return 1
}

# attendre_ligne <nom> <motif> : attend qu'une ligne contenant <motif> apparaisse dans le journal de
# <nom>, 15 s au plus (par exemple « ACCEPTE » du rôle lent, I2).
attendre_ligne() {
	local i
	for i in $(seq 1 150); do
		grep -q -- "$2" "$JOURNAUX/$1.log" 2>/dev/null && return 0
		sleep 0.1
	done
	echec "« $2 » n'apparaît jamais dans le journal de $1"
	return 1
}

# attendre_fin <nom> : attend la fin d'UN poste déjà lancé, vérifie son code et son journal, et le
# retire des postes suivis (terminer() ne le revérifie donc pas). Pour choréographier un scénario où
# certains postes doivent finir avant que d'autres soient lancés (I2, scénario 5).
attendre_fin() {
	local nom="$1" i code
	for i in "${!NOMS[@]}"; do
		if [ "${NOMS[$i]}" = "$nom" ]; then
			wait "${PIDS[$i]}"
			code=$?
			if [ "$code" -eq 124 ] || [ "$code" -eq 137 ]; then
				echec "$nom n'a pas fini dans les $DELAI s (tué par timeout)"
			elif [ "$code" -ne 0 ]; then
				echec "$nom sort en $code"
			fi
			grep -HnE "❌|SCRIPT ERROR|SHADER ERROR|Parse Error" "$JOURNAUX/$nom.log" && echec "erreurs dans le journal de $nom"
			unset "PIDS[$i]" "NOMS[$i]"
			PIDS=(${PIDS[@]+"${PIDS[@]}"})
			NOMS=(${NOMS[@]+"${NOMS[@]}"})
			return
		fi
	done
	echec "attendre_fin : $nom introuvable parmi les postes suivis"
}

# terminer <titre> : attend chaque poste lancé, vérifie son code de sortie et son journal.
terminer() {
	local titre="$1" i code avant=$ECHECS
	for i in "${!PIDS[@]}"; do
		wait "${PIDS[$i]}"
		code=$?
		if [ "$code" -eq 124 ] || [ "$code" -eq 137 ]; then
			echec "$titre : ${NOMS[$i]} n'a pas fini dans les $DELAI s (tué par timeout)"
		elif [ "$code" -ne 0 ]; then
			echec "$titre : ${NOMS[$i]} sort en $code"
		fi
		if grep -HnE "❌|SCRIPT ERROR|SHADER ERROR|Parse Error" "$JOURNAUX/${NOMS[$i]}.log"; then
			echec "$titre : erreurs dans le journal de ${NOMS[$i]}"
		fi
	done
	PIDS=()
	NOMS=()
	[ "$ECHECS" -eq "$avant" ] && echo "  ✅ $titre"
}

# compter <motif> <nom…> : nombre de lignes qui contiennent le motif dans les journaux nommés.
compter() {
	local motif="$1" nom total=0 n
	shift
	for nom in "$@"; do
		n=$(grep -c -- "$motif" "$JOURNAUX/$nom.log" 2>/dev/null)
		total=$((total + ${n:-0}))
	done
	echo "$total"
}

echo "== test réseau LeLion (journaux : $JOURNAUX) =="

# 1. Hôte + 2 clients ; un troisième se présente avec une autre version. L'un des deux clients
#    repart de lui-même, puis l'hôte quitte : l'autre le voit partir.
P=$((PORT_BASE + 1))
lancer hote1 --role=hote --port=$P --pseudo=Hote --clients=2 --partants=1 --refus=1
if attendre_hote hote1; then
	lancer reste1 --role=client --port=$P --pseudo=Reste --attendu=inscrit
	lancer partant1 --role=client --port=$P --pseudo=Partant --attendu=inscrit --partir
	lancer ancien1 --role=client --port=$P --pseudo=Ancien --attendu=refus_version --version=0.0-ancienne
fi
terminer "hôte + 2 clients, départ d'un client et de l'hôte, version différente refusée"

# 2. Partie à 2 places, deux demandes simultanées : exactement une acceptée, l'autre refusée. Les
#    deux rivaux démarrent, puis partent au même feu : la course ne dépend pas de leurs démarrages.
P=$((PORT_BASE + 2))
lancer hote2 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --refus=1
if attendre_hote hote2; then
	lancer rival2a --role=client --port=$P --pseudo=RivalA --attendu=inscrit_ou_plein --feu="$JOURNAUX/feu2"
	lancer rival2b --role=client --port=$P --pseudo=RivalB --attendu=inscrit_ou_plein --feu="$JOURNAUX/feu2"
	attendre_ligne rival2a "ATTEND LE FEU" && attendre_ligne rival2b "ATTEND LE FEU" && touch "$JOURNAUX/feu2"
fi
terminer "deux demandes pour la dernière place"
[ "$(compter "RESULTAT inscrit" rival2a rival2b)" -eq 1 ] || echec "dernière place : il fallait exactement un client inscrit"
[ "$(compter "RESULTAT refus RESEAU_REFUS_PLEIN" rival2a rival2b)" -eq 1 ] || echec "dernière place : il fallait exactement un refus « plein »"

# 3. Manche en cours : tout nouveau venu est refusé.
P=$((PORT_BASE + 3))
lancer hote3 --role=hote --port=$P --pseudo=Hote --manche --refus=1
if attendre_hote hote3; then
	lancer tard3 --role=client --port=$P --pseudo=Tard --attendu=refus_manche
fi
terminer "manche en cours : arrivée refusée"

# 4. Aucun hôte sur le port : la connexion échoue après le délai.
P=$((PORT_BASE + 4))
lancer seul4 --role=client --port=$P --pseudo=Seul --attendu=echec
terminer "sans hôte : échec de connexion après le délai"

# 5. Réservation à la réponse, vrai auth_timeout (I2, Focus 2 et 5) : un client lent est accepté
#    mais ne finit jamais sa poignée de main. Pendant sa réservation (place prise dès la réponse de
#    l'hôte, avant toute arrivée), un rival est refusé « plein » sans course possible : démarré en
#    même temps que le lent, il ne part qu'au feu, donné après l'acceptation du lent (vue dans son
#    journal), bien avant la fin du délai de poignée de main de l'hôte (DELAI_POIGNEE_LENT). Ce
#    délai passé, l'hôte coupe le lent et libère sa place (vrai peer_authentication_failed, la
#    deuxième de l'hôte après le refus du rival) : un troisième client, lancé seulement alors,
#    obtient la place, à l'index 1.
P=$((PORT_BASE + 5))
lancer hote5 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --refus=2 --delai-poignee=$DELAI_POIGNEE_LENT
if attendre_hote hote5; then
	lancer lent5 --role=lent --port=$P --pseudo=Lent --delai-poignee=$DELAI_POIGNEE_LENT
	lancer rival5 --role=client --port=$P --pseudo=Rival --attendu=refus_plein --feu="$JOURNAUX/feu5"
	if attendre_ligne lent5 "ACCEPTE" && attendre_ligne rival5 "ATTEND LE FEU"; then
		touch "$JOURNAUX/feu5"
		attendre_fin rival5
		if attendre_ligne hote5 "POIGNEE ECHOUEE 2"; then
			lancer tard5 --role=client --port=$P --pseudo=Tard --attendu=inscrit
		fi
	fi
fi
terminer "poignée de main jamais finie : réservation à la réponse, puis libération par le vrai délai"

# 6. Découverte (balises vers 127.0.0.1) : l'hôte émet sa balise ; un écouteur voit sa partie,
#    la rejoint à l'adresse et au port de la balise, voit la balise suivante compter 2 joueurs.
#    Un second écouteur sur le même port de balises (deux LeLion sur un PC) reçoit une erreur,
#    sans planter. Puis l'hôte quitte le réseau mais son processus vit encore 6 s : la partie doit
#    quitter la liste 3 s après sa dernière balise, pas à la fin du processus.
P=$((PORT_BASE + 6))
B=$((PORT_BASE + 1006))
lancer hote6 --role=hote --port=$P --port-balise=$B --pseudo=Hote6 --places=4 --clients=1 --rester="$JOURNAUX/rester6" --apres-depart=6
if attendre_hote hote6; then
	lancer ecouteur6 --role=ecouteur --port=$P --port-balise=$B --hote=Hote6 --places=4 --rejoindre
	if attendre_ligne ecouteur6 "ECOUTE PRETE"; then
		lancer occupe6 --role=ecouteur --port-balise=$B --occupe
		# occupe6 doit tenter son bind() pendant qu'ecouteur6 tient encore le port (le second bind
		# doit échouer, pas juste arriver après coup) : on attend sa vérification avant de laisser
		# partir ecouteur6 (constat 4 de la revue finale de la phase 12).
		attendre_ligne occupe6 "RESULTAT occupe" && attendre_ligne ecouteur6 "PARTIE A 2" && touch "$JOURNAUX/rester6"
	fi
fi
terminer "découverte : partie vue et rejointe par sa balise, comptée à 2, expirée après le départ de l'hôte ; port des balises occupé sans plantage"
[ "$(compter "PARTIE EXPIREE" ecouteur6)" -eq 1 ] || echec "découverte : la partie n'a pas expiré dans la liste"

# 7. (DIFFUSION=1) La même découverte en vraie diffusion (255.255.255.255 et réseaux privés), sans
#    rejoindre : l'adresse vue est l'une de celles de ce PC.
if [ "${DIFFUSION:-0}" = "1" ]; then
	P=$((PORT_BASE + 7))
	B=$((PORT_BASE + 1007))
	lancer hote7 --role=hote --port=$P --port-balise=$B --pseudo=Hote7 --diffusion --rester="$JOURNAUX/rester7"
	if attendre_hote hote7; then
		lancer ecouteur7 --role=ecouteur --port=$P --port-balise=$B --hote=Hote7 --diffusion
		attendre_ligne ecouteur7 "PARTIE VUE" && touch "$JOURNAUX/rester7"
	fi
	terminer "découverte en vraie diffusion"
	[ "$(compter "PARTIE EXPIREE" ecouteur7)" -eq 1 ] || echec "diffusion : la partie n'a pas expiré dans la liste"
else
	echo "  (scénario 7, découverte en vraie diffusion : DIFFUSION=1 pour le lancer)"
fi

# 8. Salon (phase 13), par les vraies scènes : un hôte et trois clients passent par l'écran Réseau
#    et le salon, arrivés dans l'ordre (index 1, 2, 3). B repart du salon par Retour : sa carte se
#    libère chez tous, un trou reste à l'index 2. A et C demandent au même feu la couleur voisine
#    (A la suivante, C la précédente : toutes deux visent celle de B) ; l'hôte arbitre, chacun garde
#    une couleur à lui. Tous prêts : le bouton « Démarrer la partie » de l'hôte s'active ; A repasse
#    non prêt, le bouton se regrise et un démarrage tenté quand même est refusé ; A de nouveau prêt,
#    l'hôte démarre : chaque poste charge la scène de jeu avec les mêmes fiches, index compactés (C
#    passe de 3 à 2). Un retardataire est alors refusé « manche en cours » : c'est le salon qui l'a
#    posée.
P=$((PORT_BASE + 8))
B=$((PORT_BASE + 1008))
lancer hote8 --role=salon-hote --port=$P --port-balise=$B --pseudo=Hote8 --clients=3 --partants=1 --niveau=2 --rester="$JOURNAUX/rester8"
if attendre_hote hote8; then
	lancer a8 --role=salon-client --port=$P --port-balise=$B --pseudo=Anna --voir=4 --reste=3 --couleur=1 --feu="$JOURNAUX/feu8" \
		--annuler="$JOURNAUX/annule8" --relance="$JOURNAUX/relance8" --index=1 --niveau=2
	if attendre_ligne a8 "SALON OUVERT"; then
		lancer b8 --role=salon-client --port=$P --port-balise=$B --pseudo=Bruno --voir=4 --partir
		if attendre_ligne b8 "SALON OUVERT"; then
			lancer c8 --role=salon-client --port=$P --port-balise=$B --pseudo=Chloe --reste=3 --couleur=-1 --feu="$JOURNAUX/feu8" \
				--index=2 --niveau=2
			if attendre_ligne a8 "ATTEND LE FEU" && attendre_ligne c8 "ATTEND LE FEU"; then
				touch "$JOURNAUX/feu8"
				if attendre_ligne hote8 "BOUTON ACTIF"; then
					touch "$JOURNAUX/annule8"
					if attendre_ligne hote8 "DEMARRAGE REFUSE"; then
						touch "$JOURNAUX/relance8"
						if attendre_ligne hote8 "MANCHE" && attendre_ligne a8 "MANCHE" && attendre_ligne c8 "MANCHE"; then
							lancer tard8 --role=client --port=$P --pseudo=Tard --attendu=refus_manche
							attendre_fin tard8
						fi
					fi
				fi
			fi
		fi
	fi
	touch "$JOURNAUX/rester8"
fi
terminer "salon : arrivées, départ (carte libérée), couleurs arbitrées, démarrage refusé tant qu'un joueur n'est pas prêt, manche lancée par l'hôte chez tous, retardataire refusé"
[ "$(grep -h "^MANCHE " "$JOURNAUX/hote8.log" "$JOURNAUX/a8.log" "$JOURNAUX/c8.log" 2>/dev/null | sort -u | wc -l | tr -d ' ')" -eq 1 ] \
	&& [ "$(compter "^MANCHE " hote8 a8 c8)" -eq 3 ] || echec "salon : les trois postes doivent charger la manche avec la même empreinte"
[ "$(compter "BOUTON ACTIF" hote8)" -eq 2 ] && [ "$(compter "DEMARRAGE REFUSE" hote8)" -eq 1 ] && [ "$(compter "PLUS PRET" a8)" -eq 1 ] \
	|| echec "salon : le bouton de l'hôte doit s'activer deux fois, et le démarrage être refusé une fois entre les deux"

echo "== $ECHECS échec(s) =="
if [ "$ECHECS" -eq 0 ]; then
	rm -rf "$JOURNAUX"
	exit 0
fi
recopier_journaux
exit 1
