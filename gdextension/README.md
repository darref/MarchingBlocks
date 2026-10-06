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
    world.h / .cpp      LE MONDE : couches, cases, décision de chaque sommet, et le DIFF de chaque changement
  tests/              les cas d'épreuve PROPRES au noyau (`./build.sh` : g++ aux drapeaux d'Unreal)
  src/godot/          le PONT vers Godot (classes MBNatif et MBMonde), en français : il ne part que dans l'exe
  src/appli/          la partie PRIVÉE de l'appli (cartes PBR, découpe, eau) : jamais dans les greffons
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

Sous Windows (MSVC 2022 détecté par scons, sans invite de commandes particulière) : les deux commandes `platform=windows`
ci-dessus, depuis Git Bash. MESURÉ le 6 octobre 2026 : la DLL ne dépend que de KERNEL32 (CRT statique).

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
| `CartesPBR.generer`, `depuis_la_hauteur` (boucles par texel) | `pbr_luminance`, `pbr_hauteur`, `pbr_depuis_la_hauteur` |
| `CartesPBR.dilater` (boucles par texel)         | `pbr_premultiplier`, `pbr_combler`, `pbr_finir_dilatation` |
| `CartesPBR.masque_des_triangles`                | `pbr_masque`                         |
| `Decoupe.trancher` (la boucle par triangle)     | `decouper`                           |
| `EauMaillage._poser_les_plats`                  | `eau_poser_les_plats`                |

Étape 2 (6 octobre 2026) : les cartes PBR, la découpe et les plats de l'eau vivent dans `src/appli/`, la partie
PRIVÉE de l'appli — le trancheur est ce qui se vend, il ne partira pas dans la bibliothèque des greffons. Les
`Image.resize` des cartes restent au GDScript (déjà natifs dans Godot).

⚠ **Le natif ne décide rien** : la table des 256 configurations lui est donnée par `MB.natif()` depuis
`marching_blocks.gd` ; il évalue, c'est tout. Les noms de tuiles, les orientations, le contexte d'air libre
restent écrits à UN endroit.

⚠ **`refaire` choisit sa route** : peu de sommets dans un grand monde, il lit le Dictionary de Godot tel quel ;
sinon il le recopie dans sa table, avec les hauts des colonnes. Les deux routes rendent la même chose — le test
exige qu'elles soient exercées toutes les deux (`routes()`).

## Le monde du cœur — `mbcore::World` (étape 3, 6 octobre 2026)

`src/noyau/world.h` : un monde, ce sont des COUCHES dans l'ordre de priorité (chacune ses tuiles, ses poids, ses
choix de variantes), des cases qui n'appartiennent qu'à UNE couche (poser une case la prend aux autres), et la
décision de chaque sommet — la règle de pose, étapes 1 à 8, sur l'union des couches visibles. Chaque changement
(`set_cells`, `set_visible`, `move_layer`, `remove_layer`, `set_choice`, `set_tiles`) rend un `Delta` : les cases
qui ont changé de main et les POSES qui ont changé, avant et après, triées. Un pont n'applique que ça : c'est la
reconstruction incrémentale, écrite une fois pour l'appli et les trois greffons.

Ne sont refaits que les sommets qu'un changement peut atteindre : les 8 sommets d'une case changée et, quand la plus
haute case d'une colonne bouge, ceux dont le ciel peut s'ouvrir ou se fermer (les colonnes x−1..x, z−1..z, entre
l'ancien et le nouveau haut).

Le monde ne connaît aucun nom : classes, tuiles et orientations sont des entiers que le pont lui donne (l'id d'un
item de MeshLibrary et l'orientation de GridMap côté Godot ; un quart de tour du format dans le banc).

**Ses cas d'épreuve** (`tests/world_runner.cpp`, `./build.sh`) — compilé sous les contraintes d'Unreal :
1. les 30 cas de `conformance.json` (18 d'une couche, 6 à variantes, 6 en couches), bâtis dans un `World` ;
2. le chemin INCRÉMENTAL : ces mondes et des mondes au hasard bâtis geste par geste (coups, creusements, vols
   d'une couche à l'autre, couches cachées, montrées, déplacées, retirées, choix de variantes) ; après chaque geste,
   les poses tenues par les seuls diffs doivent égaler ce que pose de zéro une AUTRE implémentation de la même règle
   écrite — `FRule::PlacementsLayered` du greffon Unreal ;
3. quelques règles écrites à la main (un vol, une couche cachée, une dalle retirée qui ouvre le ciel du sol).

**Le pont Godot** : `MBMonde` (`src/godot/mb_monde.*`), et `MB.monde_natif()` qui en rend un, la table donnée.
Le diff passe en tableaux plats (`"cases"` : 5 entiers par case, `"poses"` : 15 par sommet — x, y, z, puis couche, classe, tuile, quart, variante, air libre avant et après) ; `appliquer(diff,
rendus, fautes, id_faute)` le pose dans les grilles de chaque couche. `DEV_TOOLS/test_natif.gd` (section 10) mène
trois couches de l'appli en GDScript et un `MBMonde` par les mêmes gestes, et exige les mêmes grilles.

**Branché dans l'appli (étape 3 b, 6 octobre 2026)** : l'écran tient UN `MBMonde` (`editor._monde_coeur`), donné à
chaque couche (`MassifPeint.monde`). Une couche en couches ne décide plus ses sommets : elle s'INSCRIT au monde à son
rang (ses grilles `Rendu` et `Fautes`, son `_etat` et son `_compte`, tenus par référence) ; le monde suit l'union de
l'écran (`suivre` quelques cases, `resynchroniser` toute) et ses changements attendent en ATTENTE ; `vider_attente` les
pose dans toutes les couches inscrites, grilles, état et comptes compris, comme le GDScript les tiendrait. Le premier
appel d'un geste pose tout, les suivants n'ont plus rien à faire. Un rang qui change de propriétaire (les couches ont
glissé) fait REMPLIR la couche depuis le monde (`remplir_couche`). Un sommet MUET (à la couche, sans surface) est tenu
par le monde (`cls` < 0) : l'état des couches le compte, comme avant.
Une couche CACHÉE (son nœud invisible) DORT : le monde garde une photo de ce qu'elle pose et ne touche plus à ses
grilles ; quand elle reparaît, elle ne reçoit que la différence entre la photo et ce que le monde pose alors. Une
couche dont l'index, les poids et les choix n'ont pas changé (`hash`) n'est pas redécidée. `resynchroniser` passe par
`World::assign` (tout refait d'un coup) quand plus d'un quart des cases diffèrent.
`MB_NATIF=0` rend le GDScript partout ; `DEV_TOOLS/test_natif.gd` §11 mène les deux appli côte à côte (160 gestes) ;
`DEV_TOOLS/sonde_monde_branche.gd` chronomètre cacher / montrer une couche et vérifie le réveil.

⚠ **Déplacer ou retirer une couche** : le pont renumérote d'abord SES couches (ce qui était en `from` est en `to` ;
une couche retirée part avec ses grilles), puis applique le diff — qui ne dit que ce qui est posé autrement.

## Éteindre le natif

`MB_NATIF=0` dans l'environnement (ou `Natif.actif = false` dans un script) : tout repasse par le GDScript.
