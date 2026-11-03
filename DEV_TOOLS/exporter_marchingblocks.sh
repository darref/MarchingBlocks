#!/bin/bash
## EXPORTER MARCHINGBLOCKS — LA commande de livraison. Depuis le 3 novembre 2026, MarchingBlocks est un LOGICIEL LIBRE
## (GPL-3.0, des dons ; Jordan : « MarchingBlocks devient OpenSource […] il n'y a plus besoin de démo ») : UNE sortie,
## publiée sur GitHub Releases. Plus d'éditions (site, Steam, itch, démo), plus de clé, plus de PCK chiffré.
##
##   <sortie>/windows/     l'exe et sa DLL, LICENSE.txt (GPL-3.0), THIRD_PARTY_NOTICES.txt — prêt à zipper
##   <sortie>/installeur/  MarchingBlocks-<version>-setup.exe — l'installeur Inno Setup
##   <sortie>/greffons/    les TROIS greffons (Godot, Unity, Unreal), un zip chacun, licence MIT dedans
##   <sortie>/exemple/     l'exemple (l'exe ne l'embarque plus) : son zip et example.json
##   <sortie>/release/     TOUT CE QUI SE TÉLÉVERSE dans la version GitHub `v<version>` : le zip Windows, l'installeur,
##                         les greffons, l'exemple et example.json (l'appli le lit à
##                         `…/releases/latest/download/example.json`, `app/exemple.gd`)
##
## LANCEMENT (Git Bash, éditeur Godot FERMÉ — l'export réimporte le projet) :
##   bash DEV_TOOLS/exporter_marchingblocks.sh [sortie]        (défaut : D:/SpannerGames/ATELIER/MarchingBlocks/builds/<version>)
## ⚠ **LES BUILDS NE VIVENT PAS DANS LE DÉPÔT** (Jordan, 17 octobre 2026 : SpannerGames pilote tous les projets, un dossier
## de projet ne contient que le projet) : `MB_ATELIER` change l'atelier, `D:/SpannerGames/ETAT.md` dit où vit quoi.
##
## SANS INNO SETUP, elle sort tout SAUF l'installeur, et le dit (logiciel libre : quiconque construit depuis les sources
## n'a pas à l'installer ; le zip suffit).
## CE QU'ELLE REFUSE (et rien ne sort) : l'exemple qui ne se prend pas ; la DLL release absente ; UNE SEULE SUITE ROUGE
## (`lancer_les_suites.sh` : toutes, `test_natif` et `test_a_propos` compris) ; un dossier sans sa DLL ; un exe qui ne
## charge pas sa DLL (sonde `--mb-sonde`, et les modules du processus) ou qui n'embarque pas sa licence.
## ⚠ LE MODÈLE D'EXPORT EST CELUI DE GODOT 4.7 (les « export templates » officiels) : plus le modèle recompilé avec une
## clé de chiffrement (`D:/godot-src`), qui ne servait qu'à cacher le code.

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
GODOT="${GODOT:-/c/Users/jorda/Desktop/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64_console.exe}"
ISCC="${ISCC:-$(cygpath -u "$LOCALAPPDATA")/Programs/Inno Setup 6/ISCC.exe}"
[ -f "$ISCC" ] || ISCC="/c/Program Files (x86)/Inno Setup 6/ISCC.exe"
JOURNAL="$SORTIE/journal_export"
mkdir -p "$JOURNAL"
DLL_NOM=libmb_natif.windows.template_release.x86_64.dll
## La page des versions : l'URL des fichiers de la version `v<version>` (une règle : `app/mises_a_jour.gd`, DEPOT).
DEPOT="$(grep -E '^const DEPOT' "$PROJET/app/mises_a_jour.gd" | sed -E 's/.*"(https:[^"]+)".*/\1/')"
TELECHARGER="$DEPOT/releases/download/v$VERSION"

stop() { echo "⚠ $* — EXPORT ARRÊTÉ."; exit 1; }

echo "== MarchingBlocks $VERSION → $SORTIE_W"
INSTALLEUR_VOULU=1
[ -f "$ISCC" ] || { INSTALLEUR_VOULU=0; echo "⚠ Inno Setup introuvable : PAS D'INSTALLEUR cette fois, le zip suffit (winget install JRSoftware.InnoSetup)"; }
[ -x "$GODOT" ] || stop "Godot introuvable : $GODOT"
[ -n "$DEPOT" ] || stop "le dépôt (const DEPOT) introuvable dans app/mises_a_jour.gd"

# 1. L'EXEMPLE LIVRÉ (Jordan, 2 octobre 2026) : repris du projet de Jordan à chaque export, tant que `exemple/FIGE`
#    n'existe pas (le script le dit et garde l'archive en place).
"$GODOT" --headless --path "$PROJET_W" --script res://DEV_TOOLS/prendre_l_exemple.gd > "$JOURNAL/exemple.log" 2>&1
code_exemple=$?
grep -E "EXEMPLE|⚠" "$JOURNAL/exemple.log"
[ $code_exemple -eq 0 ] && [ -f "$PROJET/exemple/exemple.zip" ] || stop "l'exemple n'a pas pu être pris (voir $JOURNAL/exemple.log)"
#    ⚠ L'EXE NE L'EMBARQUE PLUS (Jordan, 18 octobre 2026 : téléchargé depuis l'appli) : `exemple/*` est exclu du
#    préréglage. Il part dans <sortie>/exemple/ : le zip, et `example.json` (fichier, taille, SHA-256, et l'URL où la
#    version GitHub le sert), tous deux À TÉLÉVERSER dans la version `v<version>`.
EXEMPLE_NOM="MarchingBlocks-$VERSION-example.zip"
rm -rf "$SORTIE/exemple"
mkdir -p "$SORTIE/exemple"
cp "$PROJET/exemple/exemple.zip" "$SORTIE/exemple/$EXEMPLE_NOM"
printf '{\n "file": "%s",\n "size": %s,\n "sha256": "%s",\n "url": "%s"\n}\n' "$EXEMPLE_NOM" \
	"$(stat -c %s "$SORTIE/exemple/$EXEMPLE_NOM")" "$(sha256sum "$SORTIE/exemple/$EXEMPLE_NOM" | cut -d' ' -f1)" \
	"$TELECHARGER/$EXEMPLE_NOM" > "$SORTIE/exemple/example.json"
echo "✓ l'exemple : $SORTIE_W/exemple/ ($(stat -c %s "$SORTIE/exemple/$EXEMPLE_NOM") octets)"

# 2. LE CŒUR NATIF : la DLL release doit être là (sans elle l'exe marcherait bien plus lentement).
DLL="$PROJET/addons/marchingblocks_core/natif/bin/$DLL_NOM"
[ -f "$DLL" ] || stop "$DLL absente — construire gdextension/ (voir gdextension/README.md)"

# 3. LA BATTERIE : toutes les suites vertes, ou rien ne sort.
JOURNAUX="$JOURNAL/suites" bash "$ICI/lancer_les_suites.sh" "$PROJET" | tee "$JOURNAL/batterie.log"
[ "${PIPESTATUS[0]}" -eq 0 ] || stop "une suite au moins est ROUGE (voir $JOURNAL/batterie.log)"

# 4. L'EXPORT.
rm -rf "$SORTIE/windows"
mkdir -p "$SORTIE/windows"
"$GODOT" --headless --path "$PROJET_W" --export-release "Windows" "$SORTIE_W/windows/MarchingBlocks.exe" \
	> "$JOURNAL/export_windows.log" 2>&1
code=$?
[ $code -eq 0 ] && [ -f "$SORTIE/windows/MarchingBlocks.exe" ] \
	|| stop "export « Windows » échoué (code $code) — voir $JOURNAL/export_windows.log"

# 5. LE DOSSIER : sa DLL — la même que celle du dépôt —, sa licence et ses avis tiers (et, pour l'installeur, les
#    icônes et la section du registre).
exe="$SORTIE/windows/MarchingBlocks.exe"
[ -f "$SORTIE/windows/$DLL_NOM" ] || stop "la DLL n'est pas à côté de l'exe"
cmp -s "$DLL" "$SORTIE/windows/$DLL_NOM" || stop "la DLL livrée n'est pas celle du dépôt"
"$GODOT" --headless --path "$PROJET_W" --script res://DEV_TOOLS/preparer_livraison.gd -- \
	--sortie="$SORTIE_W/windows" --installeur > "$JOURNAL/livraison_windows.log" 2>&1 \
	|| stop "la livraison ne s'est pas préparée (voir $JOURNAL/livraison_windows.log)"
echo "✓ windows : $(stat -c %s "$exe") octets, DLL, LICENSE.txt, THIRD_PARTY_NOTICES.txt"

# 6. L'EXE CHARGE SA DLL ET PORTE SA LICENCE — vu de l'intérieur (la sonde) et de l'extérieur (les modules du
#    processus). ⚠ `--mb-sonde` ne fait rien d'autre : ni projet, ni registre.
#    ⚠ `Process.Modules` SE MET EN CACHE à la première lecture (avant que l'exe ait chargé sa DLL) : `Refresh()` à chaque
#    tour — sans lui, « MODULE_ABSENT » sur une DLL bel et bien chargée (vu le 7 octobre 2026).
exe_w="$(cygpath -w "$exe")"
log_w="$(cygpath -w "$JOURNAL/sonde_windows.log")"
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
ligne="$(grep -a "MB-SONDE" "$JOURNAL/sonde_windows.log" | tr -d '\r')"
echo "windows : $ligne — $sonde"
[ "$sonde" = "MODULE_CHARGE" ] || stop "la DLL n'apparaît pas dans les modules du processus"
echo "$ligne" | grep -q "natif=1 gpl=1 version=$VERSION" \
	|| stop "la sonde ne dit pas « natif=1 gpl=1 version=$VERSION »"

# 7. L'INSTALLEUR (s'il y a Inno Setup).
mkdir -p "$SORTIE/installeur"
rm -f "$SORTIE/installeur/"*.exe
INSTALLEUR="$SORTIE/installeur/MarchingBlocks-$VERSION-setup.exe"
if [ $INSTALLEUR_VOULU -eq 1 ]; then
# ⚠ MSYS2_ARG_CONV_EXCL : Git Bash prend « /DVersion=… » pour un chemin et le réécrit (« You may not specify more than
# one script filename », vu le 7 octobre 2026).
( cd "$ICI/installeur" && MSYS2_ARG_CONV_EXCL="*" "$ISCC" /Q "/DVersion=$VERSION" "/DSource=$(cygpath -w "$SORTIE/windows")" \
	"/DSortie=$(cygpath -w "$SORTIE/installeur")" marchingblocks.iss ) > "$JOURNAL/installeur.log" 2>&1 \
	|| stop "Inno Setup a échoué (voir $JOURNAL/installeur.log)"
[ -f "$INSTALLEUR" ] || stop "l'installeur n'est pas sorti"
echo "✓ installeur : $(cygpath -w "$INSTALLEUR") ($(stat -c %s "$INSTALLEUR") octets)"
fi
# Les icônes et la section du registre ont servi à l'installeur ; le dossier redevient celui de l'exe (le zip).
rm -rf "$SORTIE/windows/icones" "$SORTIE/windows/associations.iss"

# 8. LES GREFFONS (gratuits depuis le 19 octobre 2026, MIT) : un zip par moteur, tel qu'on le dépose — Godot : le dossier
#    `addons/` à poser dans le projet ; Unity : le paquet (Package Manager, « Add package from disk ») ; Unreal : le
#    dossier `Plugins/` du projet. Chacun garde sa licence MIT et son README ; rien de compilé ni de cache.
rm -rf "$SORTIE/greffons"
mkdir -p "$SORTIE/greffons"
PYTHONIOENCODING=utf-8 python - "$PROJET" "$SORTIE/greffons" "$VERSION" <<'PY' || stop "les greffons ne se sont pas emballés"
import os, sys, zipfile
projet, sortie, version = sys.argv[1:4]
paquets = [
    ("Godot", os.path.join(projet, "addons", "marchingblocks_paint"), "addons/marchingblocks_paint"),
    ("Unity", os.path.join(projet, "engines", "unity", "com.marchingblocks.paint"), "com.marchingblocks.paint"),
    ("Unreal", os.path.join(projet, "engines", "unreal", "MarchingBlocksPaint"), "Plugins/MarchingBlocksPaint"),
]
exclus = {"Binaries", "Intermediate", "Saved", "Library", "DerivedDataCache", ".vs", "__pycache__"}
for moteur, source, racine in paquets:
    if not os.path.isfile(os.path.join(source, "LICENSE")) and not os.path.isfile(os.path.join(source, "LICENSE.md")):
        sys.exit("pas de licence dans " + source)
    nom = os.path.join(sortie, "MarchingBlocks-Paint-%s-%s.zip" % (moteur, version))
    n = 0
    with zipfile.ZipFile(nom, "w", zipfile.ZIP_DEFLATED) as z:
        for dossier, sous, fichiers in os.walk(source):
            sous[:] = sorted(s for s in sous if s not in exclus)
            for f in sorted(fichiers):
                chemin = os.path.join(dossier, f)
                z.write(chemin, racine + "/" + os.path.relpath(chemin, source).replace(os.sep, "/"))
                n += 1
    print("✓ greffon %s : %s (%d fichiers, %d octets)" % (moteur, os.path.basename(nom), n, os.path.getsize(nom)))
PY

# 9. LA VERSION GITHUB : tout ce qui se téléverse, dans un dossier. Le zip Windows est le dossier `windows/` tel quel.
rm -rf "$SORTIE/release"
mkdir -p "$SORTIE/release"
PYTHONIOENCODING=utf-8 python - "$SORTIE/windows" "$SORTIE/release/MarchingBlocks-$VERSION-windows.zip" <<'PY' \
	|| stop "le zip Windows ne s'est pas fait"
import os, sys, zipfile
source, nom = sys.argv[1:3]
with zipfile.ZipFile(nom, "w", zipfile.ZIP_DEFLATED) as z:
    for f in sorted(os.listdir(source)):
        z.write(os.path.join(source, f), "MarchingBlocks/" + f)
print("✓ zip Windows : %s (%d octets)" % (os.path.basename(nom), os.path.getsize(nom)))
PY
[ -f "$INSTALLEUR" ] && cp "$INSTALLEUR" "$SORTIE/release/"
cp "$SORTIE/greffons/"*.zip "$SORTIE/exemple/$EXEMPLE_NOM" "$SORTIE/exemple/example.json" "$SORTIE/release/"
echo "✓ à téléverser dans la version v$VERSION ($DEPOT/releases/new?tag=v$VERSION) :"
ls -1 "$SORTIE/release" | sed 's/^/    /'
echo "  ⚠ l'étiquette DOIT être v$VERSION (example.json pointe vers $TELECHARGER/), version publiée (ni brouillon ni"
echo "    préversion : l'appli lit releases/latest)."

echo "== FINI : windows, installeur, greffons, exemple, release — $SORTIE_W"
