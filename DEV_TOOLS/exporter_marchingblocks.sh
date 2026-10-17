#!/bin/bash
## EXPORTER MARCHINGBLOCKS — LA commande de livraison (charte §0, « la vente ») : les TROIS sorties d'un coup.
##
##   <sortie>/site/        l'exe du SITE (clé exigée, mises à jour vérifiées), sa DLL, LICENSE.txt, les avis tiers
##   <sortie>/installeur/  MarchingBlocks-<version>-setup.exe — l'installeur Inno Setup du site (ce qu'on met en vente)
##   <sortie>/steam/       l'exe STEAM (sans clé) et sa DLL : le dossier que SteamPipe envoie tel quel
##   <sortie>/demo/        la DÉMO (tout, sans enregistrer ni exporter) : l'appli Steam « Demo », et le zip du site
##   <sortie>/steampipe/   les scripts SteamPipe (app_build_*.vdf) du logiciel et de la démo — AppID et dépôts À REMPLIR
##
## LANCEMENT (Git Bash, éditeur Godot FERMÉ — l'export réimporte le projet) :
##   bash DEV_TOOLS/exporter_marchingblocks.sh [sortie]        (défaut : D:/SpannerGames/ATELIER/MarchingBlocks/builds/<version>)
## ⚠ **LES BUILDS NE VIVENT PLUS DANS LE DÉPÔT** (Jordan, 17 octobre 2026 : SpannerGames pilote tous les projets, un dossier
## de projet ne contient que le projet) : `MB_ATELIER` change l'atelier, `D:/SpannerGames/ETAT.md` dit où vit quoi.
##
## CE QU'ELLE REFUSE (et rien ne sort) : la clé du PCK absente ; la clé privée de licence absente, ou qui ne va pas avec
## la clé publique de l'appli ; l'exemple qui ne se prend pas ; la DLL release absente ; UNE SEULE SUITE ROUGE
## (`lancer_les_suites.sh` : toutes, `test_natif` et `test_vente` compris) ; un exe dont le PCK se lit en clair ; un
## dossier sans sa DLL ; un exe qui ne charge pas sa DLL (sonde `--mb-sonde`, et les modules du processus).
## CE QU'ELLE DIT SANS REFUSER : le contrat aux blancs [À COMPLÉTER] (SIRET…), l'URL des mises à jour à remplir.
##
## ⚠ **LA CLÉ DU PCK N'EST JAMAIS DANS LE DÉPÔT.** Elle vit dans `C:/Users/jorda/.marchingblocks/cle_pck.hex`, et c'est
## la MÊME qui a servi à compiler le modèle `D:/godot-src/bin/godot.windows.template_release…`
## (`D:/godot-src/construire_modele.sh`). Une clé différente donne un exe qui ne sait pas ouvrir son propre PCK. Elle
## passe à l'export par `GODOT_SCRIPT_ENCRYPTION_KEY`, jamais par un fichier du projet.
## ⚠ **UN EXPORT « RÉUSSI » NE PROUVE PAS LE CHIFFREMENT** : on cherche dans les octets de chaque exe des chaînes qui
## seraient là en clair sans lui (27 septembre 2026 : 0 sur 7, quand la même recherche en trouve dans l'exe NON chiffré
## de SoluTiles — l'instrument sait voir du clair).

set -u
ICI="$(cd "$(dirname "$0")" && pwd)"
PROJET="$(cd "$ICI/.." && pwd)"
PROJET_W="$(cygpath -m "$PROJET")"
VERSION="$(grep -E '^config/version=' "$PROJET/project.godot" | sed -E 's/.*"(.*)"/\1/')"
ATELIER="${MB_ATELIER:-$(dirname "$PROJET")/SpannerGames/ATELIER/MarchingBlocks}"
SORTIE="${1:-$ATELIER/builds/$VERSION}"
mkdir -p "$SORTIE"
SORTIE="$(cd "$SORTIE" && pwd)"
SORTIE_W="$(cygpath -m "$SORTIE")"
MB="$HOME/.marchingblocks"
CLE="$MB/cle_pck.hex"
GODOT="${GODOT:-/c/Users/jorda/Desktop/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe}"
ISCC="${ISCC:-$(cygpath -u "$LOCALAPPDATA")/Programs/Inno Setup 6/ISCC.exe}"
[ -f "$ISCC" ] || ISCC="/c/Program Files (x86)/Inno Setup 6/ISCC.exe"
JOURNAL="$SORTIE/journal_export"
mkdir -p "$JOURNAL"
DLL_NOM=libmb_natif.windows.template_release.x86_64.dll

stop() { echo "⚠ $* — EXPORT ARRÊTÉ."; exit 1; }

echo "== MarchingBlocks $VERSION → $SORTIE_W"
[ -f "$CLE" ] || stop "clé du PCK introuvable : $CLE (sans elle, le modèle compilé ne lira pas le PCK)"
[ -f "$ISCC" ] || stop "Inno Setup introuvable (winget install JRSoftware.InnoSetup)"
[ -x "$GODOT" ] || stop "Godot introuvable : $GODOT"

# 1. LA CLÉ DE LICENCE : la clé publique de l'appli doit être celle de la clé privée de Jordan (sinon aucune clé
#    vendue ne se vérifierait dans cet exe).
PUB_APPLI="$(grep -E '^const CLE_PUBLIQUE' "$PROJET/app/licence.gd" | sed -E 's/.*"([0-9a-f]+)".*/\1/')"
PUB_PRIVEE="$(PYTHONIOENCODING=utf-8 python "$ICI/licence_signer.py" publique 2>&1)" \
	|| stop "clé privée de licence illisible ($PUB_PRIVEE)"
[ "$PUB_APPLI" = "$PUB_PRIVEE" ] \
	|| stop "la clé publique de app/licence.gd ($PUB_APPLI) n'est pas celle de $MB/licence_ed25519_privee.hex ($PUB_PRIVEE)"
echo "✓ la clé publique de l'appli va avec la clé privée de licence"
grep -q "\[À COMPLÉTER\]\|\[TO BE COMPLETED\]" "$PROJET/app/textes/LICENSE.txt" \
	&& echo "⚠ (à faire avant la vente) le contrat porte encore des blancs [À COMPLÉTER] : SIRET, adresse, e-mail, médiateur"
grep -q "A-REMPLIR" "$PROJET/app/mises_a_jour.gd" \
	&& echo "⚠ (à faire avant la vente) l'URL des mises à jour attend le domaine (app/mises_a_jour.gd, app/vente.gd)"

# 2. L'EXEMPLE LIVRÉ (Jordan, 2 octobre 2026) : repris du projet de Jordan à chaque export, tant que `exemple/FIGE`
#    n'existe pas (le script le dit et garde l'archive en place).
"$GODOT" --headless --path "$PROJET_W" --script res://DEV_TOOLS/prendre_l_exemple.gd > "$JOURNAL/exemple.log" 2>&1
code_exemple=$?
grep -E "EXEMPLE|⚠" "$JOURNAL/exemple.log"
[ $code_exemple -eq 0 ] && [ -f "$PROJET/exemple/exemple.zip" ] || stop "l'exemple n'a pas pu être pris (voir $JOURNAL/exemple.log)"

# 3. LE CŒUR NATIF : la DLL release doit être là (sans elle l'exe marcherait plus lentement, et la version SITE ne
#    vérifierait aucune clé : on ne livre pas ça).
DLL="$PROJET/addons/marchingblocks_core/natif/bin/$DLL_NOM"
[ -f "$DLL" ] || stop "$DLL absente — construire gdextension/ (voir gdextension/README.md)"

# 4. LA BATTERIE : toutes les suites vertes, ou rien ne sort.
JOURNAUX="$JOURNAL/suites" bash "$ICI/lancer_les_suites.sh" "$PROJET" | tee "$JOURNAL/batterie.log"
[ "${PIPESTATUS[0]}" -eq 0 ] || stop "une suite au moins est ROUGE (voir $JOURNAL/batterie.log)"

# 5. LES TROIS EXPORTS, chiffrés.
export GODOT_SCRIPT_ENCRYPTION_KEY=$(tr -d '\r\n' < "$CLE")
for e in site:Site steam:Steam demo:Demo; do
	dossier="${e%%:*}"
	preset="${e##*:}"
	rm -rf "$SORTIE/$dossier"
	mkdir -p "$SORTIE/$dossier"
	"$GODOT" --headless --path "$PROJET_W" --export-release "$preset" "$SORTIE_W/$dossier/MarchingBlocks.exe" \
		> "$JOURNAL/export_$dossier.log" 2>&1
	code=$?
	if [ $code -ne 0 ] || [ ! -f "$SORTIE/$dossier/MarchingBlocks.exe" ]; then
		unset GODOT_SCRIPT_ENCRYPTION_KEY
		stop "export « $preset » échoué (code $code) — voir $JOURNAL/export_$dossier.log"
	fi
done
unset GODOT_SCRIPT_ENCRYPTION_KEY

# 6. CHAQUE SORTIE : chiffrée, avec sa DLL — la même que celle du dépôt —, son contrat et ses avis tiers.
for dossier in site steam demo; do
	exe="$SORTIE/$dossier/MarchingBlocks.exe"
	en_clair=0
	for s in "blocs_maitres" "SUFFIXE_DEHORS" "exterieur_possible" "Sculpt one block" "res://app/editor" \
			"Floor - open air" "pieces_a_sculpter"; do
		n=$(grep -c -a -F "$s" "$exe")
		[ "$n" -gt 0 ] && { echo "⚠ EN CLAIR dans $dossier : $s ($n)"; en_clair=$((en_clair + 1)); }
	done
	[ $en_clair -eq 0 ] || stop "LE CHIFFREMENT NE TIENT PAS dans $dossier : $en_clair chaîne(s) lisible(s)"
	[ -f "$SORTIE/$dossier/$DLL_NOM" ] || stop "$dossier : la DLL n'est pas à côté de l'exe"
	cmp -s "$DLL" "$SORTIE/$dossier/$DLL_NOM" || stop "$dossier : la DLL livrée n'est pas celle du dépôt"
	opt=""
	[ "$dossier" = "site" ] && opt="--installeur"
	"$GODOT" --headless --path "$PROJET_W" --script res://DEV_TOOLS/preparer_livraison.gd -- \
		--sortie="$SORTIE_W/$dossier" $opt > "$JOURNAL/livraison_$dossier.log" 2>&1 \
		|| stop "$dossier : la livraison ne s'est pas préparée (voir $JOURNAL/livraison_$dossier.log)"
	echo "✓ $dossier : $(stat -c %s "$exe") octets, chiffré (0 chaîne témoin sur 7), DLL, LICENSE.txt, THIRD_PARTY_NOTICES.txt"
done

# 7. CHAQUE EXE CHARGE SA DLL — vu de l'intérieur (la sonde dit si MBNatif et MBLicence existent, et l'édition) et de
#    l'extérieur (les modules du processus). ⚠ `--mb-sonde` ne fait rien d'autre : ni contrat, ni projet, ni registre.
#    ⚠ `Process.Modules` SE MET EN CACHE à la première lecture (avant que l'exe ait chargé sa DLL) : `Refresh()` à chaque
#    tour — sans lui, « MODULE_ABSENT » sur une DLL bel et bien chargée (vu le 7 octobre 2026).
for dossier in site steam demo; do
	exe_w="$(cygpath -w "$SORTIE/$dossier/MarchingBlocks.exe")"
	log_w="$(cygpath -w "$JOURNAL/sonde_$dossier.log")"
	sonde="$(powershell -NoProfile -Command "
		\$p = Start-Process -FilePath '$exe_w' -ArgumentList '--headless','--','--mb-sonde' -PassThru -RedirectStandardOutput '$log_w'
		\$vu = \$false
		for (\$i = 0; \$i -lt 80 -and -not \$p.HasExited; \$i++) {
			try { \$p.Refresh(); if (\$p.Modules | Where-Object { \$_.ModuleName -eq '$DLL_NOM' }) { \$vu = \$true } } catch {}
			Start-Sleep -Milliseconds 250
		}
		if (-not \$p.HasExited) { \$p.Kill() }
		if (\$vu) { 'MODULE_CHARGE' } else { 'MODULE_ABSENT' }
	" | tr -d '\r')"
	ligne="$(grep -a "MB-SONDE" "$JOURNAL/sonde_$dossier.log" | tr -d '\r')"
	echo "$dossier : $ligne — $sonde"
	[ "$sonde" = "MODULE_CHARGE" ] || stop "$dossier : la DLL n'apparaît pas dans les modules du processus"
	echo "$ligne" | grep -q "natif=1 licence=1 edition=$dossier version=$VERSION" \
		|| stop "$dossier : la sonde ne dit pas « natif=1 licence=1 edition=$dossier version=$VERSION »"
done

# 7 bis. LA CHAÎNE ENTIÈRE DE LA CLÉ : une clé signée À L'INSTANT par la clé privée de Jordan (`licence_signer.py essai`,
#    non notée au registre) est BONNE pour l'exe du site ; la même, un caractère de sa signature changé, est REFUSÉE.
CLE_ESSAI="$(PYTHONIOENCODING=utf-8 python "$ICI/licence_signer.py" essai | tr -d '\r\n')"
dernier="${CLE_ESSAI: -2:1}"
[ "$dernier" = "A" ] && remplace="B" || remplace="A"
CLE_FAUSSE="${CLE_ESSAI:0:${#CLE_ESSAI}-2}$remplace${CLE_ESSAI: -1}"
exe_site="$SORTIE/site/MarchingBlocks.exe"
bonne="$("$exe_site" --headless -- --mb-sonde "--mb-cle=$CLE_ESSAI" 2>/dev/null | tr -d '\r' | grep -a "MB-SONDE-CLE")"
fausse="$("$exe_site" --headless -- --mb-sonde "--mb-cle=$CLE_FAUSSE" 2>/dev/null | tr -d '\r' | grep -a "MB-SONDE-CLE")"
echo "site, clé signée à l'instant : $bonne · la même, trafiquée : $fausse"
[ "$bonne" = "MB-SONDE-CLE ok nom=Export check" ] || stop "l'exe du site ne reconnaît pas une clé signée par la clé privée"
echo "$fausse" | grep -q "^MB-SONDE-CLE refusee" || stop "l'exe du site accepte une clé trafiquée"

# 8. L'INSTALLEUR DU SITE.
mkdir -p "$SORTIE/installeur"
rm -f "$SORTIE/installeur/"*.exe
# ⚠ MSYS2_ARG_CONV_EXCL : Git Bash prend « /DVersion=… » pour un chemin et le réécrit (« You may not specify more than
# one script filename », vu le 7 octobre 2026).
( cd "$ICI/installeur" && MSYS2_ARG_CONV_EXCL="*" "$ISCC" /Q "/DVersion=$VERSION" "/DSource=$(cygpath -w "$SORTIE/site")" \
	"/DSortie=$(cygpath -w "$SORTIE/installeur")" marchingblocks.iss ) > "$JOURNAL/installeur.log" 2>&1 \
	|| stop "Inno Setup a échoué (voir $JOURNAL/installeur.log)"
INSTALLEUR="$SORTIE/installeur/MarchingBlocks-$VERSION-setup.exe"
[ -f "$INSTALLEUR" ] || stop "l'installeur n'est pas sorti"
echo "✓ installeur : $(cygpath -w "$INSTALLEUR") ($(stat -c %s "$INSTALLEUR") octets)"
# Les icônes et la section du registre ont servi à l'installeur ; le dossier du site reste celui de l'exe.
rm -rf "$SORTIE/site/icones" "$SORTIE/site/associations.iss"

# 9. STEAMPIPE : un script par application (le logiciel, la démo — DÉCIDÉ par Jordan le 7 octobre 2026 : une appli
#    Steam « Demo » à part, gratuite). ⚠ AppID et dépôts À REMPLIR quand les AppID seront payés (4894680 est à River
#    Stones).
mkdir -p "$SORTIE/steampipe"
for e in steam:MarchingBlocks demo:"MarchingBlocks Demo"; do
	dossier="${e%%:*}"
	nom="${e#*:}"
	cat > "$SORTIE/steampipe/app_build_$dossier.vdf" <<VDF
"AppBuild"
{
	"AppID" "APPID_${dossier^^}_A_REMPLIR"
	"Desc" "$nom $VERSION"
	"ContentRoot" "$(cygpath -w "$SORTIE/$dossier")"
	"BuildOutput" "$(cygpath -w "$SORTIE/steampipe/sortie_$dossier")"
	"Depots"
	{
		"DEPOT_${dossier^^}_A_REMPLIR"
		{
			"FileMapping"
			{
				"LocalPath" "*"
				"DepotPath" "."
				"recursive" "1"
			}
		}
	}
}
VDF
done
echo "✓ steampipe : app_build_steam.vdf, app_build_demo.vdf (AppID et dépôts à remplir) — steamcmd +run_app_build <vdf>"
echo "== FINI : site + installeur, Steam, démo — $SORTIE_W"
