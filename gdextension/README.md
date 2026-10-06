# Le cœur natif de MarchingBlocks (GDExtension)

La stratégie, ses décisions et leur statut sont dans la charte (`CLAUDE.md`, §0, « LE CŒUR C++ »). Ce fichier dit
comment c'est rangé, comment on le construit et ce qui est porté.

## Rangement

```
gdextension/
  godot-cpp/          sous-module, épinglé (godot-cpp pour Godot 4.7) — `git submodule update --init`
  SConstruct          la construction (scons)
  src/noyau/          LE CŒUR : C++17 standard, sans moteur, en anglais — destiné aussi aux greffons
    cells.h             la table de cases (clé 64 bits, adressage ouvert)
    placement.h         la règle de pose évaluée : bits, couche, ciel, hachage, tirage des variantes
    ocean.h             l'océan par tronçons de colonne
  src/godot/          le PONT vers Godot (classe MBNatif), en français : il ne part que dans l'exe
addons/marchingblocks_core/
  natif.gd            l'aiguillage : charge la bibliothèque, ou rend null (le GDScript prend la main)
  natif/marchingblocks_natif.gdextension
  natif/bin/          les bibliothèques construites (Linux, Windows ; debug pour l'éditeur, release pour l'exe)
DEV_TOOLS/test_natif.gd   le test différentiel : le natif doit rendre EXACTEMENT ce que rend le GDScript
```

`gdextension/` porte un `.gdignore` : Godot ne le parcourt pas (godot-cpp contient un projet d'essai).

## Construire

Il faut Python, `scons` (`pip install scons`) et un compilateur C++17.

```
cd gdextension
scons platform=windows target=template_debug      # l'éditeur (Windows, MSVC ou mingw)
scons platform=windows target=template_release    # l'exe exporté
scons platform=linux   target=template_debug      # l'éditeur et les suites sous Linux
scons platform=linux   target=template_release
# depuis Linux, la DLL Windows : ajouter use_mingw=yes
```

La première construction compile godot-cpp (quelques minutes) ; les suivantes, seulement `src/`.

⚠ **Après un `git pull` qui touche `gdextension/src/`, reconstruire** (ou reprendre les binaires du dépôt s'ils ont
été poussés avec). Une bibliothèque en retard sur le GDScript, `test_natif.gd` la voit : il compare les deux.

⚠ **L'éditeur charge la bibliothèque au démarrage et la garde** (`reloadable = false`) : pour en essayer une nouvelle,
fermer l'éditeur, reconstruire, rouvrir. Sous Windows, une DLL chargée ne peut pas être réécrite.

## Ce qui est porté (6 octobre 2026)

| GDScript (la référence)                         | natif (`MBNatif`)                    |
|-------------------------------------------------|--------------------------------------|
| `MB.poses`, `MB.poses_en_couches`               | `poses`, `poses_en_couches`          |
| `MB.plafond_de`, `MB.hauts_des_colonnes`        | `plafond_de`, `hauts_des_colonnes`   |
| `MB.contacts_par_arete`                         | `contacts_par_arete`                 |
| `massif_peint.reconstruire` (complète)          | `compter_cases`, `reconstruire`      |
| `massif_peint.reconstruire_autour` / `_sommets` | `refaire`                            |
| `massif_peint._empreinte_des_cases`             | `empreinte_des_cases`                |
| `FL.boite`, `FL.ocean`                          | `boite`, `ocean`                     |

⚠ **Le natif ne décide rien** : la table des 256 configurations lui est donnée par `MB.natif()` depuis
`marching_blocks.gd` ; il évalue, c'est tout. Les noms de tuiles, les orientations, le contexte d'air libre
restent écrits à UN endroit.

⚠ **`refaire` choisit sa route** : peu de sommets dans un grand monde, il lit le Dictionary de Godot tel quel ;
sinon il le recopie dans sa table, avec les hauts des colonnes. Les deux routes rendent la même chose — le test
exige qu'elles soient exercées toutes les deux (`routes()`).

## Éteindre le natif

`MB_NATIF=0` dans l'environnement (ou `Natif.actif = false` dans un script) : tout repasse par le GDScript.
