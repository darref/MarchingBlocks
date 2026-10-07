#!/bin/bash
## LA BATTERIE — toutes les suites (`DEV_TOOLS/test_*.gd` et `fumee_appli.gd`), en headless, une par une.
##
## LANCEMENT (Git Bash) :
##   bash DEV_TOOLS/lancer_les_suites.sh [dossier du projet]     (défaut : le dossier parent de ce script)
##
## Rend 0 si TOUTES sont vertes, 1 sinon. Une suite est verte si elle finit en code 0 ET écrit son bilan
## « N vérifications, 0 échec(s) » (N > 0), sans « VERDICT : ÉCHEC » — charte §6 : le code seul ne suffit pas, une
## erreur de parsing peut finir en 0 sans rien vérifier. (Toutes n'écrivent pas « VERDICT » : `test_fluides`,
## `test_formes_speciales` finissent sur le bilan.)
## ⚠ UNE PAR UNE, PAS EN PARALLÈLE : `fumee_appli` et `test_projet` réécrivent `user://reglages.cfg` (et le rendent).
## Les journaux vont dans `$JOURNAUX` (défaut : un dossier temporaire), un fichier par suite.

set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
PROJET="${1:-$(cd "$ICI/.." && pwd)}"
GODOT="${GODOT:-/c/Users/jorda/Desktop/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe}"
JOURNAUX="${JOURNAUX:-$(mktemp -d)}"
mkdir -p "$JOURNAUX"

rouges=0
total=0
for chemin in "$PROJET"/DEV_TOOLS/test_*.gd "$PROJET"/DEV_TOOLS/fumee_appli.gd; do
	nom="$(basename "$chemin" .gd)"
	total=$((total + 1))
	debut=$(date +%s)
	"$GODOT" --headless --path "$PROJET" --script "res://DEV_TOOLS/$nom.gd" > "$JOURNAUX/$nom.log" 2>&1
	code=$?
	duree=$(( $(date +%s) - debut ))
	bilan="$(grep -a -E "^[0-9 ]+ vérifications" "$JOURNAUX/$nom.log" | tail -1)"
	if [ $code -eq 0 ] && echo "$bilan" | grep -q -E "^[1-9][0-9]* vérifications, 0 échec" \
			&& ! grep -a -q "VERDICT : ÉCHEC" "$JOURNAUX/$nom.log"; then
		echo "✓ $nom — $bilan (${duree} s)"
	else
		echo "✗ $nom — code $code — $bilan (${duree} s) — voir $JOURNAUX/$nom.log"
		rouges=$((rouges + 1))
	fi
done
echo "BATTERIE : $total suites, $rouges rouge(s) — journaux dans $JOURNAUX"
[ $rouges -eq 0 ]
