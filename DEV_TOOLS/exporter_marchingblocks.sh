#!/bin/bash
## EXPORTER MARCHINGBLOCKS — l'exécutable unique et chiffré, puis la preuve qu'il l'est.
##
## LANCEMENT (Git Bash, éditeur Godot FERMÉ — l'export réimporte le projet) :
##   bash DEV_TOOLS/exporter_marchingblocks.sh
##
## ⚠ **LA CLÉ N'EST JAMAIS DANS LE DÉPÔT.** Elle vit dans `C:/Users/jorda/.marchingblocks/cle_pck.hex`,
## et c'est la MÊME qui a servi à compiler le modèle `D:/godot-src/bin/godot.windows.template_release…`
## (`D:/godot-src/construire_modele.sh`). Une clé différente donne un exe qui ne sait pas ouvrir son
## propre PCK. Elle passe à l'export par `GODOT_SCRIPT_ENCRYPTION_KEY`, jamais par un fichier du projet.
##
## ⚠ **UN EXPORT « RÉUSSI » NE PROUVE PAS LE CHIFFREMENT** : on cherche donc dans les octets de l'exe
## des chaînes qui seraient là en clair sans lui. Le 27 septembre 2026 : 0 sur 7, alors que la même
## recherche en trouve dans l'exe NON chiffré de SoluTiles — l'instrument sait donc voir du clair.

set -u
CLE="/c/Users/jorda/.marchingblocks/cle_pck.hex"
GODOT="/c/Users/jorda/Desktop/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe"
SORTIE="D:/MarchingBlocks/build/MarchingBlocks.exe"

if [ ! -f "$CLE" ]; then
	echo "⚠ clé introuvable : $CLE — sans elle, le modèle compilé ne lira pas le PCK."
	exit 1
fi
mkdir -p /d/MarchingBlocks/build
export GODOT_SCRIPT_ENCRYPTION_KEY=$(tr -d '\r\n' < "$CLE")
"$GODOT" --headless --path D:/MarchingBlocks --export-release "Windows Desktop" "$SORTIE" > /tmp/export_mb.log 2>&1
code=$?
unset GODOT_SCRIPT_ENCRYPTION_KEY
if [ $code -ne 0 ] || [ ! -f "$SORTIE" ]; then
	echo "⚠ export échoué (code $code) — voir /tmp/export_mb.log"
	exit 1
fi
echo "exe : $SORTIE ($(stat -c %s "$SORTIE") octets)"

en_clair=0
for s in "blocs_maitres" "SUFFIXE_DEHORS" "exterieur_possible" "Sculpt one block" "res://app/editor" \
		"Floor - open air" "pieces_a_sculpter"; do
	n=$(grep -c -a -F "$s" "$SORTIE")
	[ "$n" -gt 0 ] && { echo "⚠ EN CLAIR dans l'exe : $s ($n)"; en_clair=$((en_clair + 1)); }
done
if [ $en_clair -gt 0 ]; then
	echo "⚠ LE CHIFFREMENT NE TIENT PAS : $en_clair chaîne(s) lisible(s)."
	exit 1
fi
echo "✓ aucune des 7 chaînes témoins n'est lisible dans l'exe"
