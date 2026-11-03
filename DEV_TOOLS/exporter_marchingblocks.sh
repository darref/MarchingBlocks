#!/bin/bash
## EXPORTER MARCHINGBLOCKS — LA commande de livraison. MarchingBlocks est OPEN SOURCE (MIT, charte §0, « open source ») :
## une seule édition, sans clé, sans chiffrement, sans démo. Ce qu'elle sort, à joindre à la Release GitHub « v<version> » :
##
##   <sortie>/windows/     l'exe Windows, sa DLL, LICENSE.txt, THIRD_PARTY_NOTICES.txt — et son zip
##   <sortie>/linux/       l'exe Linux, sa .so, LICENSE.txt, THIRD_PARTY_NOTICES.txt — et son zip
##   <sortie>/installeur/  MarchingBlocks-<version>-setup.exe — l'installeur Inno Setup (Windows)
##   <sortie>/greffons/    les TROIS greffons (Godot, Unity, Unreal), un zip chacun, licence MIT dedans
##   <sortie>/exemple/     l'exemple (l'exe ne l'embarque pas) : son zip et example.json
##
## LANCEMENT (Git Bash, éditeur Godot FERMÉ — l'export réimporte le projet ; les modèles d'export OFFICIELS de Godot 4.7
## installés, Windows et Linux) :
##   bash DEV_TOOLS/exporter_marchingblocks.sh [sortie]        (défaut : D:/SpannerGames/ATELIER/MarchingBlocks/builds/<version>)
## `MB_ATELIER` change l'atelier ; `GODOT`, `ISCC` les outils ; `MB_SANS_INSTALLEUR=1` saute Inno Setup.
##
## CE QU'ELLE REFUSE (et rien ne sort) : l'exemple qui ne se prend pas ; la DLL ou la .so release absente ; UNE SEULE
## SUITE ROUGE (`lancer_les_suites.sh`) ; un dossier sans sa bibliothèque native, ou une autre que celle du dépôt ; un exe
## Windows qui ne charge pas sa DLL (sonde `--mb-sonde`, et les modules du processus).

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
SO_NOM=libmb_natif.linux.template_release.x86_64.so

stop() { echo "⚠ $* — EXPORT ARRÊTÉ."; exit 1; }

echo "== MarchingBlocks $VERSION → $SORTIE_W"
[ -x "$GODOT" ] || stop "Godot introuvable : $GODOT"
[ "${MB_SANS_INSTALLEUR:-0}" = "1" ] || [ -f "$ISCC" ] \
	|| stop "Inno Setup introuvable (winget install JRSoftware.InnoSetup, ou MB_SANS_INSTALLEUR=1)"

# 1. L'EXEMPLE (Jordan, 2 octobre 2026) : repris du projet source à chaque export, tant que `exemple/FIGE` n'existe
#    pas (le script le dit et garde l'archive en place).
"$GODOT" --headless --path "$PROJET_W" --script res://DEV_TOOLS/prendre_l_exemple.gd > "$JOURNAL/exemple.log" 2>&1
code_exemple=$?
grep -E "EXEMPLE|⚠" "$JOURNAL/exemple.log"
[ $code_exemple -eq 0 ] && [ -f "$PROJET/exemple/exemple.zip" ] || stop "l'exemple n'a pas pu être pris (voir $JOURNAL/exemple.log)"
#    ⚠ L'EXE NE L'EMBARQUE PAS (Jordan, 18 octobre 2026 : téléchargé depuis l'appli). Depuis l'open source (3 novembre
#    2026), il part dans <sortie>/exemple/ : le zip, À JOINDRE à la Release GitHub « v$VERSION », et `example.json`
#    (adresse, taille, SHA-256), À COPIER dans `exemple/example.json` du dépôt et à pousser sur main — c'est ce que lit
#    le bouton « Example world » (`app/exemple.gd`).
EXEMPLE_NOM="MarchingBlocks-$VERSION-example.zip"
rm -rf "${SORTIE:?}/exemple"
mkdir -p "$SORTIE/exemple"
cp "$PROJET/exemple/exemple.zip" "$SORTIE/exemple/$EXEMPLE_NOM"
printf '{\n "file": "%s",\n "url": "%s",\n "size": %s,\n "sha256": "%s"\n}\n' "$EXEMPLE_NOM" \
	"https://github.com/darref/MarchingBlocks/releases/download/v$VERSION/$EXEMPLE_NOM" \
	"$(stat -c %s "$SORTIE/exemple/$EXEMPLE_NOM")" "$(sha256sum "$SORTIE/exemple/$EXEMPLE_NOM" | cut -d' ' -f1)" \
	> "$SORTIE/exemple/example.json"
echo "✓ l'exemple : $SORTIE_W/exemple/ ($(stat -c %s "$SORTIE/exemple/$EXEMPLE_NOM") octets)"

# 2. LE CŒUR NATIF : la DLL et la .so release doivent être là (sans elles l'exe marcherait, mais plus lentement).
BIN="$PROJET/addons/marchingblocks_core/natif/bin"
[ -f "$BIN/$DLL_NOM" ] || stop "$BIN/$DLL_NOM absente — construire gdextension/ (voir gdextension/README.md)"
[ -f "$BIN/$SO_NOM" ] || stop "$BIN/$SO_NOM absente — construire gdextension/ (voir gdextension/README.md)"

# 3. LA BATTERIE : toutes les suites vertes, ou rien ne sort.
JOURNAUX="$JOURNAL/suites" bash "$ICI/lancer_les_suites.sh" "$PROJET" | tee "$JOURNAL/batterie.log"
[ "${PIPESTATUS[0]}" -eq 0 ] || stop "une suite au moins est ROUGE (voir $JOURNAL/batterie.log)"

# 4. LES EXPORTS (préréglages « Windows » et « Linux », modèles officiels, sans chiffrement), chacun avec sa
#    bibliothèque native — la même que celle du dépôt —, sa licence et ses avis tiers.
for e in windows:Windows:MarchingBlocks.exe:$DLL_NOM linux:Linux:MarchingBlocks.x86_64:$SO_NOM; do
	IFS=: read -r dossier preset exe biblio <<< "$e"
	rm -rf "${SORTIE:?}/${dossier:?}"
	mkdir -p "$SORTIE/$dossier"
	"$GODOT" --headless --path "$PROJET_W" --export-release "$preset" "$SORTIE_W/$dossier/$exe" \
		> "$JOURNAL/export_$dossier.log" 2>&1
	code=$?
	[ $code -eq 0 ] && [ -f "$SORTIE/$dossier/$exe" ] \
		|| stop "export « $preset » échoué (code $code) — voir $JOURNAL/export_$dossier.log"
	[ -f "$SORTIE/$dossier/$biblio" ] || stop "$dossier : la bibliothèque native n'est pas à côté de l'exe"
	cmp -s "$BIN/$biblio" "$SORTIE/$dossier/$biblio" || stop "$dossier : la bibliothèque livrée n'est pas celle du dépôt"
	"$GODOT" --headless --path "$PROJET_W" --script res://DEV_TOOLS/preparer_livraison.gd -- \
		--sortie="$SORTIE_W/$dossier" > "$JOURNAL/livraison_$dossier.log" 2>&1 \
		|| stop "$dossier : la livraison ne s'est pas préparée (voir $JOURNAL/livraison_$dossier.log)"
	echo "✓ $dossier : $exe ($(stat -c %s "$SORTIE/$dossier/$exe") octets), $biblio, LICENSE.txt, THIRD_PARTY_NOTICES.txt"
done

# 5. L'EXE WINDOWS CHARGE SA DLL — vu de l'intérieur (la sonde dit si MBNatif existe, l'édition et la version) et de
#    l'extérieur (les modules du processus). ⚠ `Process.Modules` SE MET EN CACHE à la première lecture : `Refresh()`
#    à chaque tour (vu le 7 octobre 2026).
exe_w="$(cygpath -w "$SORTIE/windows/MarchingBlocks.exe")"
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
[ "$sonde" = "MODULE_CHARGE" ] || stop "windows : la DLL n'apparaît pas dans les modules du processus"
echo "$ligne" | grep -q "natif=1 edition=release version=$VERSION" \
	|| stop "windows : la sonde ne dit pas « natif=1 edition=release version=$VERSION »"

# 6. L'INSTALLEUR (Windows).
if [ "${MB_SANS_INSTALLEUR:-0}" != "1" ]; then
	mkdir -p "$SORTIE/installeur"
	rm -f "${SORTIE:?}/installeur/"*.exe
	"$GODOT" --headless --path "$PROJET_W" --script res://DEV_TOOLS/preparer_livraison.gd -- \
		--sortie="$SORTIE_W/windows" --installeur > "$JOURNAL/livraison_installeur.log" 2>&1 \
		|| stop "les icônes de l'installeur ne se sont pas préparées (voir $JOURNAL/livraison_installeur.log)"
	# ⚠ MSYS2_ARG_CONV_EXCL : Git Bash prend « /DVersion=… » pour un chemin et le réécrit (vu le 7 octobre 2026).
	( cd "$ICI/installeur" && MSYS2_ARG_CONV_EXCL="*" "$ISCC" /Q "/DVersion=$VERSION" \
		"/DSource=$(cygpath -w "$SORTIE/windows")" "/DSortie=$(cygpath -w "$SORTIE/installeur")" marchingblocks.iss ) \
		> "$JOURNAL/installeur.log" 2>&1 || stop "Inno Setup a échoué (voir $JOURNAL/installeur.log)"
	INSTALLEUR="$SORTIE/installeur/MarchingBlocks-$VERSION-setup.exe"
	[ -f "$INSTALLEUR" ] || stop "l'installeur n'est pas sorti"
	echo "✓ installeur : $(cygpath -w "$INSTALLEUR") ($(stat -c %s "$INSTALLEUR") octets)"
	# Les icônes et la section du registre ont servi à l'installeur ; le dossier reste celui de l'exe.
	rm -rf "${SORTIE:?}/windows/icones" "${SORTIE:?}/windows/associations.iss"
fi

# 7. LES ZIPS À JOINDRE À LA RELEASE (le binaire Linux garde son droit d'exécution).
PYTHONIOENCODING=utf-8 python - "$SORTIE" "$VERSION" <<'PY' || stop "les zips ne se sont pas faits"
import os, sys, zipfile
sortie, version = sys.argv[1:3]
for dossier, nom in (("windows", "Windows"), ("linux", "Linux")):
    source = os.path.join(sortie, dossier)
    cible = os.path.join(sortie, "MarchingBlocks-%s-%s.zip" % (version, nom))
    with zipfile.ZipFile(cible, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(os.listdir(source)):
            chemin = os.path.join(source, f)
            if not os.path.isfile(chemin):
                continue
            info = zipfile.ZipInfo.from_file(chemin, "MarchingBlocks/" + f)
            info.compress_type = zipfile.ZIP_DEFLATED
            if f.endswith(".x86_64"):
                info.external_attr = 0o100755 << 16
            with open(chemin, "rb") as e:
                z.writestr(info, e.read())
    print("✓ %s (%d octets)" % (os.path.basename(cible), os.path.getsize(cible)))
PY

# 8. LES GREFFONS (Jordan, 19 octobre 2026) : un zip par moteur, tel qu'on le dépose — Godot : le dossier `addons/` à
#    poser dans le projet ; Unity : le paquet (Package Manager, « Add package from disk ») ; Unreal : le dossier
#    `Plugins/` du projet. Chacun garde sa licence MIT et son README ; rien de compilé ni de cache.
rm -rf "${SORTIE:?}/greffons"
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

echo "== FINI — à joindre à la Release GitHub v$VERSION : les zips Windows et Linux, l'installeur, les greffons, l'exemple."
echo "   Puis copier exemple/example.json dans le dépôt (exemple/example.json) et le pousser sur main — $SORTIE_W"
