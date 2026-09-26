#!/usr/bin/env bash
# Test réseau du transport (phase 11) : des postes headless sur localhost, un processus Godot par
# poste (tests/reseau/joueur.gd), scénario après scénario.
#   tests/reseau/lancer.sh [port_de_base]
# Le scénario n utilise le port port_de_base + n (défaut 17777 : jamais le 7777 d'une vraie partie).
# Variables : GODOT (défaut : godot), DELAI (secondes au plus par processus, défaut : 40).
# Sortie 0 si chaque poste sort en 0, sans ❌ ni SCRIPT ERROR ni SHADER ERROR dans son journal, et
# si les comptes croisés entre postes tombent juste. Tous les processus lancés sont tués en sortie.
set -u
cd "$(dirname "$0")/../.." || exit 2

GODOT="${GODOT:-godot}"
PORT_BASE="${1:-17777}"
DELAI="${DELAI:-40}"
JOURNAUX="$(mktemp -d "${TMPDIR:-/tmp}/lelion-reseau.XXXXXX")"
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
trap 'echo "interrompu"; exit 130' INT TERM

echec() {
	echo "  ❌ $1"
	ECHECS=$((ECHECS + 1))
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
lancer hote1 --role=hote --port=$P --pseudo=Hote --clients=2 --partants=1 --attente=1
if attendre_hote hote1; then
	lancer reste1 --role=client --port=$P --pseudo=Reste --attendu=inscrit
	lancer partant1 --role=client --port=$P --pseudo=Partant --attendu=inscrit --partir
	lancer ancien1 --role=client --port=$P --pseudo=Ancien --attendu=refus_version --version=0.0-ancienne
fi
terminer "hôte + 2 clients, départ d'un client et de l'hôte, version différente refusée"

# 2. Partie à 2 places, deux demandes simultanées : exactement une acceptée, l'autre refusée.
P=$((PORT_BASE + 2))
lancer hote2 --role=hote --port=$P --pseudo=Hote --places=2 --clients=1 --attente=2
if attendre_hote hote2; then
	lancer rival2a --role=client --port=$P --pseudo=RivalA --attendu=inscrit_ou_plein
	lancer rival2b --role=client --port=$P --pseudo=RivalB --attendu=inscrit_ou_plein
fi
terminer "deux demandes pour la dernière place"
[ "$(compter "RESULTAT inscrit" rival2a rival2b)" -eq 1 ] || echec "dernière place : il fallait exactement un client inscrit"
[ "$(compter "RESULTAT refus RESEAU_REFUS_PLEIN" rival2a rival2b)" -eq 1 ] || echec "dernière place : il fallait exactement un refus « plein »"

# 3. Manche en cours : tout nouveau venu est refusé.
P=$((PORT_BASE + 3))
lancer hote3 --role=hote --port=$P --pseudo=Hote --manche --attente=3
if attendre_hote hote3; then
	lancer tard3 --role=client --port=$P --pseudo=Tard --attendu=refus_manche
fi
terminer "manche en cours : arrivée refusée"

# 4. Aucun hôte sur le port : la connexion échoue après le délai.
P=$((PORT_BASE + 4))
lancer seul4 --role=client --port=$P --pseudo=Seul --attendu=echec
terminer "sans hôte : échec de connexion après le délai"

echo "== $ECHECS échec(s) =="
if [ "$ECHECS" -eq 0 ]; then
	rm -rf "$JOURNAUX"
	exit 0
fi
echo "journaux gardés dans $JOURNAUX"
exit 1
