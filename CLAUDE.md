# MarchingBlocks — charte du greffon

Elle porte les décisions transverses : celles qui doivent survivre à une session et à quelqu'un qui
arrive six mois plus tard avec une bonne idée.

⚠ **Chaque décision porte son statut** :

- **DÉCIDÉ** — voulu par Jordan, ne se rediscute pas sans lui ;
- **PROPOSÉ** — réflexion à valider, avec sa raison ; on peut la jeter, pas l'ignorer ;
- **MESURÉ** — vérifié par un calcul, un test ou une capture, donc vrai quoi qu'on en pense ;
- **OUVERT** — question posée, pas encore tranchée.

Un PROPOSÉ ne devient DÉCIDÉ qu'une fois validé — à l'image de préférence, jamais par ancienneté.

## SpannerGames pilote — DÉCIDÉ (Jordan, 17 octobre 2026)

- **L'ÉTAT DE TOUS LES PROJETS DE `D:/` VIT DANS `D:/SpannerGames/ETAT.md`** : une session de MarchingBlocks le lit en
  arrivant et met à jour SA ligne (celle de MarchingBlocks, pas les autres) quand l'état du produit change. Le détail
  technique reste ici. La charte des médias (vidéos, GIF, posts) est `D:/SpannerGames/CLAUDE.md` et
  `D:/SpannerGames/PROJETS/MarchingBlocks/CLAUDE.md` ; on se sert de `D:/SpannerGames/OUTILS/` plutôt que d'en réécrire.
- **CE DÉPÔT NE CONTIENT QUE LE PROJET.** Tout ce qui en dérive vit sous `D:/SpannerGames` : les médias dans
  `PROJETS/MarchingBlocks/` (`01_scripts` … `07_publication`), le reste, hors git, dans `ATELIER/MarchingBlocks/` —
  `builds/<version>` (la sortie par défaut de `exporter_marchingblocks.sh` depuis le 17 octobre 2026 ; l'export 0.9.3 y
  est rangé), `worktrees/` (les tournages), `agents/`, `unity/` (les projets URP d'essai), `copies/`, `sauvegarde/`,
  `essais/`. `MARQUE/` reste ici : l'appli l'embarque. ⚠ Un chemin `D:/MB_*`, `D:/MarchingBlocks_*` ou
  `D:/MarchingBlocks/build` écrit plus bas date d'avant ce rangement (le tableau de `ETAT.md` dit où il est allé).

---

## 0. Le produit : le logiciel MarchingBlocks — DÉCIDÉ (Jordan, 27 septembre 2026)

> **Le projet devient un LOGICIEL, MarchingBlocks, vendu 60 € en UN exécutable chiffré.** Il fait
> tout ce que fait le greffon, reprend l'écran de SoluTiles (`D:/AbsoluTiles`, « le même genre de
> projet, mais 3D au lieu de 2D »), et exportera vers TROIS greffons de peinture — Godot, Unity,
> Unreal — **écrits APRÈS lui**.

- **LES DÉCISIONS DU 7 OCTOBRE 2026 — DÉCIDÉ (Jordan, en réponse à l'inventaire du lancement).** Le but : amener
  MarchingBlocks à « il ne reste vraiment plus rien à faire à part publier sur Steam après avoir payé la marque et poster
  partout » (la marque ~190 €, l'AppID 100 $ et le domaine attendent l'argent ; la playlist YouTube est en PRIVÉ).
  - ~~**GEL DES FONCTIONS, MAINTENANT** : plus aucun atelier ni fonction neuve avant la 0.9.0 — corrections, finition, vente
    seulement. Props, Houses et toute idée neuve partent à la 1.0. Le logiciel est fini : **les greffons commencent**.~~
    **LEVÉ — DÉCIDÉ (Jordan, 18 octobre 2026 : « on a déjà dégelé et on est déjà en démo 0.9.3, et les prochaines modifs
    passeront en 0.9.4 »)**. Les fonctions neuves reviennent, version par version (0.9.x → 1.0) ; voir « 0.9.4 » plus bas.
    ⚠ Les mentions « malgré le gel » ou « gel du 7 octobre » écrites plus loin datent d'avant cette levée.
  - **PARITÉ COMPLÈTE DES GREFFONS À LA 0.9.0** : toute la LISTE DES GREFFONS À FAIRE (ci-dessous) est livrée dans
    Godot, Unity et Unreal pour le lancement — fluides et leurs presets, molette, transitions, demandes du 3 octobre,
    Extrude / Shrink, textures animées, feuillage —, chacune avec ses cas d'épreuve communs.
  - **UN INSTALLEUR INNO SETUP** (gratuit) livre l'exe et sa DLL, les raccourcis, les associations de fichiers, et une
    désinstallation propre qui les retire. Steam livre le dossier tel quel. (Tranche l'OUVERT « un exécutable », §0.)
  - **LE TRAILER FINAL EST CONSTRUIT PAR CLAUDE, PAR SCRIPT, MAINTENANT** (60 s et 2 min), comme les devlogs — plus le
    monde filmé à la souris en décembre de la stratégie de lancement.
- **LES GREFFONS ATTENDENT LA FIN DU LOGICIEL — DÉCIDÉ (Jordan, 1er octobre 2026)** : « les greffons à faire
  quand tout le dev du soft sera terminé, sinon allers-retours incessants ». Une fonction neuve du logiciel ne
  se porte plus dans Godot, Unity et Unreal au fil de l'eau : on la note dans **LA LISTE DES GREFFONS À FAIRE**
  (ci-dessous), et tout part d'un bloc quand le logiciel est fini. ⚠ Ce qui est DÉJÀ dans les greffons n'est pas
  abandonné : un changement du logiciel ne doit pas les CASSER (un format lu par eux reste lisible, les gardes
  de `test_greffon_peinture` et des bancs restent vertes) — il ne les fait simplement plus AVANCER.
- **LA LISTE DES GREFFONS À FAIRE** (à tenir à jour à chaque fonction ajoutée au logiciel) :
  - **les couches en UNE passe — FAIT DANS GODOT (20 octobre 2026, Jordan : « fais le correctif du greffon dans
    MarchingBlocks »), À PORTER dans Unity et Unreal s'ils refont la règle couche par couche (non vérifié)** : chaque couche
    refaisait `Rule.placements_layered` sur TOUT le monde pour n'en garder que sa liste — Cartoon Island (17 couches,
    331 467 cases) bâtissait ses tuiles en 56,4 s dans WaterDrop, ~2,85 s par couche. `rebuild_world()` fait une passe et
    distribue les listes (`_ready`, `apply_cells`, l'import, la mise à jour en direct) ; `test_greffon_peinture` vérifie
    qu'elle pose exactement ce que posent les couches une à une (462 vérifications vertes, vu rougir sur une variante
    fausse). **MESURÉ dans WaterDrop : 56,4 s → 9,6 s (Cartoon Island), 18,3 → 8,7 s (l'île verte)** ; le reste n'est plus
    la règle (sans doute le chargement des 17 jeux de tuiles et la pose dans les grilles : à mesurer). Pas de numéro de
    version monté, rien de réexporté ni d'envoyé sur itch.io : c'est à Jordan de dire si les greffons repartent.
    **Puis (même jour, Jordan : « réduis le chargement des îles »)** : la règle lit la plus haute case de chaque colonne
    au lieu de remonter la colonne à chaque coin vide (même réponse : 2,98 → 2,50 s sur Cartoon Island), et une couche
    VIDE ne charge plus son jeu de tuiles (11 des 17 couches de l'île verte, ~0,1 s chacune). `test_greffon_peinture` vert.
    Puis le **CACHE DES TUILES**, au choix d'un jeu (`tile_cache_dir`, vide par défaut : l'éditeur ne s'en sert pas) :
    clé = les cases, la visibilité et l'ordre des couches, chaque jeu de tuiles et sa date, les variantes ; testé (relues,
    les mêmes tuiles ; une case de plus, une autre clé — vu rougir avec une clé qui ignorait les cases). Dans WaterDrop,
    Cartoon Island revue : la construction des couches 9,0 → 5,0 s.
  - **le relief (POM)** (Jordan, 18 octobre 2026 : le relief du Play test part aussi dans les jeux ; §0, « 0.9.4 »). Le
    glTF ne porte pas de carte de hauteur : **le contrat est à écrire d'abord, dans le logiciel** (PROPOSÉ : la hauteur
    de chaque matériau écrite à côté du .glb du monde, et citée par NOM de matériau dans `world.json`, avec une
    profondeur conseillée ; `regle()` et `world_conformance.json` la portent). Puis chaque moteur la pose : Godot
    (`heightmap_*` + deep parallax de StandardMaterial3D, comme le Play test), Unity (le Lit d'URP n'a qu'un parallax
    simple : un POM à écrire dans les presets, ou le simple assumé — OUVERT), Unreal (la fonction de matériau
    `ParallaxOcclusionMapping`). Désactivable dans chaque moteur, avec ses cas d'épreuve communs.
  - **les fluides** (§5, « le mode Fluids ») : lire la clé `water` de `world.json` (règle `regle_eau()`, et la
    porter dans `regle()` et `world_conformance.json`) ; poser chaque nappe `water/<nom>.glb` avec un matériau
    choisi par l'artiste, et les SIX presets réécrits dans chaque moteur (stylisé, clair, réfléchissant, et depuis
    le 2 octobre 2026 lave, marais, acide luminescent — leurs aspects exportés : `lava`, `swamp`, `acid`) qui
    lisent le contrat (COLOR_0 : courant, genre, profondeur) ; un emplacement de matériau par genre d'eau ; plus
    tard, recalculer l'eau quand on peint (`fluides.gd` réécrit en C# et C++, avec ses cas d'épreuve ; la NAPPE a ses cas
    depuis le 7 octobre 2026, « le contrat de l'eau recalculée » ci-dessous) ; prévenir
    l'artiste que les presets ne sont pas obligatoires. Et depuis le 3 octobre 2026 : **un seul océan** (une
    seconde source de mer est refusée, `un_seul_ocean`) ; la nappe **sous un étage flottant** (`surface_dessinee`) ;
    les plats **sans jonction en T** ; le **clapot sur les cascades aussi** (§5, « l'eau du 3 octobre »).
    Et **les cascades en volume** (§5, « les cascades du 3 octobre ») : la nappe courbe refermée dans la roche, son
    remous, la source — le contrat change (genre 0,75 = écume ; COLOR_0 a = l'écume sur une cascade), et le motif
    `motif_cascade` est à réécrire dans chaque preset.
    - ✓ **Unity — FAIT SAUF LA POSE (7 octobre 2026)** — nappe cuite et six aspects sur le contrat, cases d'eau recalculées, et **la NAPPE RECALCULÉE quand on peint** (`MBWaterMesh`, 14/14 cas ; après le geste, sur un fil, avec la reprise ; « Rebuild water ») ; ⚠ l'eau ne se POSE toujours pas dans l'éditeur (pas d'outil de source). Voir « Le greffon Unity à parité » et « L'eau recalculée dans Unity ».
  - **La molette du contexte** (§5, « la molette ») : la même règle dans les trois éditeurs (pendant un geste, Alt, Maj,
    Ctrl), F qui cadre toute la matière, et des panneaux où la molette ne règle rien.
    - **Unity : FAIT (7 octobre 2026)** — l'aiguillage (`MBWheel`) et ses effets ; jamais tenu souris en main.
    - ✓ **Godot — FAIT (7 octobre 2026, branche `eau-godot`)** : lecture de `water`, la nappe cuite et les SIX presets (copie générée), le matériau de l'artiste, la règle des cases (25/25 cas) ; **la NAPPE RECALCULÉE** (`mb_water_mesh.gd`, 14/14 cas en sac de triangles), la reprise portée, recalcul différé sur un fil à part, « Rebuild water », coupure au-delà d'1 s ; = la nappe cuite de l'exemple exporté. Vu à l'image (six presets). Voir « L'eau recalculée dans le greffon Godot ».
    - ✓ **Unreal — FAIT (7 octobre 2026, branche `eau-unreal`)** : lecture de `water` (acteur MarchingBlocks Water par couche), la nappe cuite et les SIX presets réécrits en HLSL (`Tools/build_materials.py`), le matériau de l'artiste, la règle des cases (`MBWater`, 25/25 ; la mer est `noyau/ocean.h` lui-même) ; **la NAPPE RECALCULÉE** (`MBCore/MBWaterMesh`, C++ standard, 14/14 cas en sac), la reprise portée (`Water::WorldResumed`), recalcul différé sur une tâche d'Unreal, « Rebuild water » (acteur et panneau du mode), coupure au-delà d'1 s ; = la nappe cuite de l'île ET de l'exemple exportés (66 151, 5 073, 72 triangles). Vu à l'image (six presets, cuite et refaite à une image d'écart). ⚠ « réfléchissant » sans la marche en espace écran de l'appli ; l'aplat sombre de « stylisé » près de l'île était la nappe CUITE importée, pas le mailleur (la refaite ne l'a pas). Voir « L'eau recalculée dans le greffon Unreal ».
  - **La molette du contexte** (§5, « la molette ») : la même règle dans les trois éditeurs (pendant un geste, Alt, Maj,
    Ctrl), F qui cadre toute la matière, et des panneaux où la molette ne règle rien.
    - ✓ **Godot — FAIT sauf F (7 octobre 2026)** : la règle de l'appli dans `mb_editor.gd` (`wheel`), éprouvée par de vrais événements. ⚠ F : la caméra de la vue 3D appartient à l'éditeur de Godot (pas d'API pour la poser).
    - ✓ **Unreal — FAIT sauf « près de la souris » (7 octobre 2026)** : la règle de l'appli (`UMarchingBlocksEdMode::Wheel`), seule elle reste au moteur ; F cadre la matière des couches visibles. ⚠ Le cran se dit dans le panneau et en haut de la vue (dessiner près de la souris demande l'interface de gizmo d'Unreal). Jamais tenue souris en main.
  - ~~**la salle**~~ — **FAITE (2 octobre 2026)**, voir §4, « la salle dans les greffons ».
  - ~~**la règle multicouche**~~ — **FAITE (2 octobre 2026)**, voir §4, « la règle multicouche dans les greffons ».
  - **Les transitions entre couches** (§5, « L'atelier Transitions ») : lire la clé `transitions` d'un monde exporté (à
    écrire d'abord dans `world.json` : paires, réglages par direction, représentants, choix peints), réécrire la règle
    (`Transitions.melange`, ses cas d'épreuve) et le shader (texture 3D d'un octet par case, table des réglages) dans
    chaque moteur, et le poser par-dessus les matériaux des tuiles. Un shader ne voyage pas (§4).
    - **Unity : FAIT (7 octobre 2026)** — Built-in et URP, vu à l'image.
    - ✓ **Godot — FAIT (7 octobre 2026)** : lecture, règle (93/93 cas), le shader de l'appli en `next_pass` sur les matériaux des tuiles, qui suit les cases peintes. Vu à l'image.
    - ✓ **Unreal — FAIT (7 octobre 2026)** : lecture, règle (93/93), Overlay Material `M_MB_Transition` sur les instances (mesuré : il se dessine), texture 3D d'un octet par case, sommet de la tuile par instance. Vu à l'image.
  - **Les demandes du 3 octobre 2026** (§5, « les demandes du 3 octobre ») : le pinceau Select qui prend aussi les
    cases VIDES (une case à cocher), « Extend selection ↑ ↓ » (le mode « étendre » d'`Etages.extruder`, en bouton), et,
    si les greffons posent un jour de l'eau, la largeur d'une rivière à la pose (`FL.sources_en_largeur`, ses cas) ; et
    « Room from selection » (`FS.salle_depuis`, réécrite en C# et en C++, avec ses cas).
    - **Unity : FAIT (7 octobre 2026)** — Select des vides, Extend selection, Room from selection ; la largeur d'une rivière : la règle seulement (Unity ne pose pas d'eau).
    - ✓ **Godot — FAIT (7 octobre 2026)** : « Select empty cells too », Extend selection (Maj + clic / Maj + molette), Room from selection. La largeur d'une rivière : la règle et ses cas seulement (le greffon ne pose pas d'eau).
    - ✓ **Unreal — FAIT (7 octobre 2026)** : « Select empty cells too », Extend selection (Maj + clic, Maj + molette), Room from selection ; largeur d'une rivière : règle et cas seulement (le greffon ne pose pas d'eau).
  - **Extrude, et Shrink** (§5, « Extrude, une seule fois ») : les trois greffons ont encore Extrude ↑ ↓ dans les
    opérations de sélection et l'ancien Shrink (`retrecir`, gardé dans `outils.gd` pour leurs cas d'épreuve). Il
    faut : `Etages.extruder` (poser / étendre / décaler, haut / bas / face) réécrite en C# et en C++, `retrecir_bord`
    à la place de `retrecir`, leurs cas dans `tools_conformance.json`, et Maj / Alt dans les trois éditeurs.
    - **Unity : FAIT (7 octobre 2026)** — Extrude ↑ ↓ Facing, Maj / Alt, Shrink du bord ; l'ancien retiré de l'interface Unity.
    - ✓ **Godot — FAIT (7 octobre 2026)** : Extrude ↑ ↓ face (Maj étend, Alt décale), Shrink du bord ; les anciens Extrude ↑ ↓ et Shrink quittent sa barre (leurs fonctions restent pour `tools_conformance.json`).
    - ✓ **Unreal — FAIT (7 octobre 2026)** : Extrude haut / bas / face (Maj étend, Alt décale), Shrink du bord, Widen ; les anciens ExtrudeUp / Down et Shrink de `MBTools` restent pour `tools_conformance.json`.
  - ~~**Les variantes voulues**~~ — **FAITES (5 octobre 2026)**, voir §3, « les variantes dans les greffons ».
  - **Les textures animées** (§5, « l'atelier Animation ») : lire `mb_animation` dans les `extras` du matériau glTF
    (défilement u/v, images — ips, aller-retour —, pulsation de l'émission, synchro ou décalée par la position, la phase
    de `phase_de`), et le shader de chaque moteur (la règle : `image_au_temps`, `pulsation_au_temps`) ; EMPORTER LES
    IMAGES dans le `.mbset` (aujourd'hui `tiles.glb` ne porte que l'image 0 et les noms de fichiers des autres) ; leurs
    cas d'épreuve.
    - **Unity : FAIT (7 octobre 2026)** — lecture du `.glb` lui-même, Texture2DArray, phase par tuile ; Built-in et URP.
  - **Le feuillage** (§5, « l'atelier Foliage ») : porter les modèles et les plants dans le `.mbworld` (le `.glb` copié
    dedans, comme les jeux de tuiles), la règle `feuillage.gd` (les trois modes, le pinceau, ses cas d'épreuve), le
    vent (le shader réécrit dans chaque moteur, sur les mêmes données : sol, hauteur, phase, amplitude par plant).
    - ✓ **Unity : FAIT (7 octobre 2026, branche `finitions-greffons`)** — pose et vent (vus à l'image), la règle de plantation, et l'outil Plant de l'inspecteur (`MBPlanting.cs` : le modèle, les trois modes, clic / Ctrl pinceau / Maj effacer, un Ctrl+Z par trait). Voir « Le greffon Unity à parité ».
    - ✓ **Godot — FAIT (7 octobre 2026)** : `mb_animation` lu dans le JSON du `.glb` (repli : la méta `extras`), le shader de l'appli (copie générée, phase en espace du format), 43/43 cas. Vu à l'image.
    - ✓ **Unreal — FAIT (7 octobre 2026)** : `mb_animation` lu dans le JSON du `tiles.glb` (gardé dans le niveau, images en PNG), `M_MB_Animated` (images, défilement, pulsation), phase par instance calculée sur le CPU (précision mixte de la règle). Vu à l'image (deux instants).
  - **Le feuillage** (§5, « l'atelier Foliage ») : porter les modèles et les plants dans le `.mbworld` (le `.glb` copié
    dedans, comme les jeux de tuiles), la règle `feuillage.gd` (les trois modes, le pinceau, ses cas d'épreuve), le
    vent (le shader réécrit dans chaque moteur, sur les mêmes données : sol, hauteur, phase, amplitude par plant).
    - ✓ **Godot — FAIT (7 octobre 2026, branche `finitions-greffons`)** : lecture, pose en MultiMesh, le vent (shader de l'appli), la règle de placement et du pinceau (59/59 cas), et l'outil Plant de la barre (`mb_planting.gd` : le modèle, les trois modes, clic / Ctrl pinceau / Maj effacer, un Ctrl+Z par trait, le sol par rayon contre les tuiles posées). Vu à l'image.
    - ✓ **Unreal — FAIT (7 octobre 2026)** : lecture, pose (`FFrame::Turn`), vent `M_MB_Wind` (World Position Offset, données par instance), plantation dans le mode (clic, pinceau Ctrl, effacer Maj) avec la règle `MBFoliage` (59/59) et le sol par rayon contre les tuiles. Vu à l'image (vent). ⚠ Plantation jamais tenue souris en main.
  - **UNE API DE JEU — PROPOSÉ (4 octobre 2026), validée comme entrée de la liste par Jordan le même jour** (« pour
    que les game dev puissent simplement faire leur jeu par-dessus »). Les trois greffons sont des OUTILS D'ÉDITEUR :
    leur surface publique n'a jamais été conçue comme une API (Godot `cells` / `apply_cells` / `cell_under_ray` /
    `rebuild` ; Unity `Cells` / `SetCell` / `Apply` / `CellUnderRay` ; Unreal : rien pour les Blueprints — ses
    `UFUNCTION` sont `CallInEditor`, le reste prend des types `MBPaint::`). Ce qui manque, la MÊME dans les trois :
    - `GetCell` / `SetCells` / `ClearCells`, `Raycast` (case ET face touchées), `TileAt(sommet)` (nom anglais,
      quart de tour, contexte), la surface au-dessus d'un point, un événement `OnCellsChanged` (et « reconstruit »),
      `SaveCells` / `LoadCells` d'un état modifié en jeu, à part du niveau ; côté Unreal, `BlueprintCallable` ;
    - **la reconstruction INCRÉMENTALE en jeu** (§4, OUVERT — l'appli la fait, `MassifPeint.reconstruire_autour`) :
      sans elle, creuser en jeu reconstruit tout le monde ; et Unity pose un GameObject par tuile (à mesurer) ;
    - la COLLISION des tuiles posées en jeu, garantie et éprouvée dans chaque moteur ;
    - leurs cas d'épreuve (`tools_conformance.json` ou un fichier à part), et un exemple minimal par moteur
      (creuser au clic, un personnage posé sur la surface). Une seule règle : les noms et sens de l'API s'écrivent
      UNE fois, comme `rules_text`, et se traduisent dans les trois langues.
    - ⚠ **OUVERT** : ce que l'API dit de l'eau (rien tant que les greffons ne posent pas les fluides) et des variantes.

- **LE CŒUR C++ — DÉCIDÉ (Jordan, 6 octobre 2026 : « le cœur en C++, l'API haut niveau pour les trois greffons, afin
  qu'on gagne à la fois la performance du soft et des greffons, et l'API pour construire un jeu par-dessus »), PREMIÈRE
  ÉTAPE ÉCRITE LE MÊME JOUR.** Le détail, les commandes de construction et l'état : `gdextension/README.md`.
  - **UN SEUL CŒUR, TROIS PONTS — PROPOSÉ.** Ce qui se calcule sur des cases (la règle de pose, la reconstruction
    INCRÉMENTALE, l'eau, puis les outils et les formes) s'écrit UNE fois en C++17 standard, sans moteur
    (`gdextension/src/noyau/`, en ANGLAIS : il partira dans les greffons), sous les contraintes d'Unreal (ni exceptions
    ni RTTI, masquage et rétrécissement en erreurs — celles de `core-runner`). Puis, par moteur, un PONT mince :
    Godot — la GDExtension (l'appli ET le greffon gratuit, la même bibliothèque) ; Unreal — le module compile le
    noyau tel quel (le `MBCore` d'aujourd'hui y FUSIONNE : une seule règle C++, pas deux) ; Unity — une bibliothèque
    native à interface C (`extern "C"`), appelée par P/Invoke derrière la même API C#. ⚠ Pour Unity c'est un binaire
    par plateforme (Windows, macOS, Linux, Android, iOS en statique, WebGL par emscripten) : **OUVERT, à Jordan** —
    garder le C# actuel en repli là où il n'y a pas de binaire serait une SECONDE DESCRIPTION (§6), donc la
    recommandation est le natif partout, construit par une CI (GitHub Actions) qui sort la matrice.
  - **L'API DE JEU REPOSE SUR UN ÉTAT DU MONDE DANS LE CŒUR — PROPOSÉ.** `mbcore::World` : les couches, leurs cases,
    la décision de chaque sommet ; `SetCells` rend un DIFF de poses (ajoutées, retirées, changées) que chaque pont
    applique à sa façon (GridMap, instances d'Unreal, objets ou lots de Unity). C'est ce qui donne aux trois greffons
    la reconstruction incrémentale qui leur manque (§4, OUVERT) — écrite une fois. `GetCell`, `Raycast`, `TileAt`,
    `OnCellsChanged`, `SaveCells` / `LoadCells` (l'entrée « UNE API DE JEU », ci-dessus) en sont des méthodes ; les
    noms et le sens s'écrivent UNE fois (dans le noyau, et ses cas d'épreuve), les ponts ne font que traduire.
  - **CE QUI SE VEND NE PART PAS DANS LES GREFFONS** : le noyau partagé ne porte que ce que le format ouvert dit déjà
    (la règle, l'eau, les outils) ; le trancheur, le témoin et le modeleur, s'ils passent en C++, vivent dans une
    partie PRIVÉE de la GDExtension de l'appli (une seconde cible de build), jamais dans la bibliothèque des greffons.
    ⚠ Une DLL native n'est pas dans le PCK chiffré (elle est à côté de l'exe) : du code compilé reste plus dur à lire
    qu'un GDScript, donc c'est plutôt un gain pour l'exe — mais le rempart reste la licence (§0, le chiffrement).
  - ⚠ **« UN EXÉCUTABLE » (§0) NE TIENT PLUS TEL QUEL — OUVERT, À JORDAN.** Godot ne sait pas embarquer une
    bibliothèque native dans l'exe : l'export pose `libmb_natif….dll` À CÔTÉ de `MarchingBlocks.exe`. On livre donc un
    dossier (ou un zip, ou un installeur). Sans la DLL l'exe marche quand même — le GDScript prend la main —, mais plus
    lentement. `exporter_marchingblocks.sh` refuse désormais d'exporter sans la DLL release, ou si `test_natif` rougit.
  - **LE GDSCRIPT RESTE LA RÉFÉRENCE ET LE REPLI.** Chaque fonction accélérée garde son corps GDScript, qui sert quand
    la bibliothèque manque et qui est l'ATTENDU de `DEV_TOOLS/test_natif.gd` (sortie identique au caractère près,
    l'ordre des clés compris). `Natif.actif = false` — ou `MB_NATIF=0` dans l'environnement — rend le GDScript
    partout. On n'efface un corps GDScript que le jour où le noyau a ses PROPRES cas d'épreuve (les greffons).
  - **L'ORDRE — PROPOSÉ** : (1) l'appli d'abord, par les points chauds MESURÉS, module par module, chacun gardé par le
    test différentiel — **FAIT LE 6 OCTOBRE : la règle de pose, le massif (complet et local), l'océan** ; (2) les autres
    points chauds de l'appli — **FAIT LE 6 OCTOBRE : les cartes PBR, la découpe, les plats de l'eau** (ci-dessous) ; (3) `mbcore::World` et son diff, d'abord dans l'appli (il y remplace les dictionnaires de cases) — **LE MONDE ET SON
    DIFF ÉCRITS LE 6 OCTOBRE, AVEC SES PROPRES CAS D'ÉPREUVE, ET BRANCHÉS DANS L'APPLI LE MÊME JOUR** (ci-dessous) ;
    (4) les greffons, QUAND LE LOGICIEL SERA FINI (« les greffons attendent la fin du logiciel », ci-dessus) : Godot
    embarque la GDExtension, Unreal fusionne `MBCore`, Unity passe au natif ; (5) l'API de jeu par-dessus, avec ses
    cas d'épreuve communs et un exemple par moteur.
  - **MESURÉ (6 octobre 2026, Linux, headless, Godot 4.7 et godot-cpp épinglé)** : `test_natif` 83 (mondes au hasard :
    relief, falaises, grottes, dalles flottantes, contacts par une arête, coordonnées négatives ; poses avec et sans trous,
    en couches ; le massif complet puis 120 gestes locaux, poids et choix de variantes compris ; l'océan à cinq niveaux et
    dans une boîte élargie) ; les 22 suites vertes AVEC le natif et avec `MB_NATIF=0`, aux mêmes comptes (fumée 803).
    Sur un monde de 120 821 cases : `MB.poses` 850 → 236 ms, l'océan 284 → 73 ms, la reconstruction complète du massif
    1 866 → 330 ms. **Dix mutations du C++, toutes rouges** (le ciel décalé, le balayage raccourci, le hachage sans
    second brassage, l'ordre de l'océan, les hauts mal rangés, les muets mal rangés, les poids négatifs, les étages,
    les choix ignorés, la lecture de l'union). ⚠ **DEUX D'ABORD MUETTES, ET C'ÉTAIT LE TEST** : les choix tombaient
    sur des sommets sans variante, et le monde était trop petit pour que la route locale lise jamais le Dictionary —
    `routes()` exige désormais les deux chemins. ⚠ Les DLL Windows sont construites par mingw ici (seules dépendances :
    KERNEL32, msvcrt), **jamais chargées sous Windows** ; ni l'exe exporté, ni l'éditeur de Jordan n'ont été essayés.
  - **L'ÉTAPE 2 — FAITE (Jordan, 6 octobre 2026 : « go pour l'étape 2, porte les autres points chauds »), MESURÉE
    D'ABORD** (`DEV_TOOLS/banc_points_chauds.gd`, headless) : cartes PBR 1 024² 1,7 s (3,1 s avec masque, dont
    `dilater` 1,4 s et le masque 0,45 s) ; trancher le témoin 1,5 s, dont la découpe 0,95 s et `verifier_couture`
    0,12 s (qui découpe aussi) ; un geste d'eau à mémoire pleine 72 ms, dont `_poser_les_plats` 65 ms. **PORTÉS, dans
    `gdextension/src/appli/`** (la partie PRIVÉE : le trancheur se vend, il n'ira pas dans les greffons) : les boucles
    par texel des cartes PBR (luminance, hauteur, normale et ORM, dilatation, masque — les `Image.resize` restent au
    GDScript), la boucle par triangle de `Decoupe.trancher`, `EauMaillage._poser_les_plats`. **APRÈS** : cartes 1,7 →
    0,23 s, avec masque 3,1 → 0,33 s, `dilater` 1,4 → 0,33 s, le masque 0,45 → 0,02 s ; le témoin tranché 1,5 → 0,49 s
    (la découpe 0,95 → 0,09 s, `verifier_couture` 0,12 → 0,01 s) ; le geste d'eau 72 → 11 ms. Sorties IDENTIQUES À
    L'OCTET (images) et au bit près (tableaux) — `test_natif` 132 ; douze mutations rouges (Sobel sans boucle, ORM sans
    arrondi, luminance en float, dilatation sans mélange, `combler` qui saute, normales non renormalisées, triangles
    plats gardés, tolérance des plans, points des cascades ignorés, éventail retourné, doublons gardés, distance au
    masque stricte). ⚠ **DEUX D'ABORD MUETTES, PAR LE TEST** : aucun centre de texel à 1,0 PILE d'un bord (des sommets aux
    demi-texels d'une image de 64 l'ont fait rougir) ; aucun sommet à moins de 10⁻⁶ d'un plan côté dehors. ⚠ **UNE
    ÉQUIVALENTE** : la couleur par défaut de la découpe — elle ne sort que si la source a des couleurs. **PAS PORTÉS,
    MESURÉS** : la propagation des sections (quelques ms par geste), `_nappes_du_corps` (~50 ms, seulement pour les corps
    qui changent), `maillage_moitie` (~0,25 s, une fois).
  - **L'ÉTAPE 3 — `mbcore::World` (Jordan, 6 octobre 2026 : « go pour l'étape 3 »), ÉCRITE DANS LE NOYAU** (`gdextension/
    src/noyau/world.*`, en anglais, sous les contraintes d'Unreal) : des COUCHES dans l'ordre de priorité (tuiles, poids,
    choix de variantes chacune), des cases EXCLUSIVES (poser prend aux autres couches), la décision de chaque sommet sur
    l'union des couches visibles — la règle, étapes 1 à 8. Chaque changement (poser / vider des cases, cacher, montrer,
    déplacer, retirer une couche, un choix, des tuiles) rend un DIFF trié : les cases qui changent de main, les POSES
    qui changent (avant, après). Ne sont refaits que les 8 sommets de chaque case changée et, quand le haut d'une
    colonne bouge, les sommets des colonnes x−1..x, z−1..z dont `y + 2` passe entre l'ancien et le nouveau haut. Le
    monde ne connaît aucun nom : classes, tuiles, orientations sont des entiers que le pont lui donne. Le pont Godot :
    `MBMonde` (`MB.monde_natif()`), le diff en tableaux plats, `appliquer` le pose dans les grilles de chaque couche.
    - ⚠ **DÉPLACER OU RETIRER UNE COUCHE** : le pont renumérote d'abord SES couches, puis applique le diff (qui ne dit
      que ce qui est posé autrement). Écrit dans `world.h`, éprouvé par le banc.
    - **SES PROPRES CAS D'ÉPREUVE** (`gdextension/tests/`, `./build.sh`, g++ aux drapeaux d'Unreal) — la condition que
      la charte met pour effacer un jour un corps GDScript : les **30 cas de `conformance.json`** (18 d'une couche, 6 à
      variantes, 6 en couches, 2 998 poses) bâtis dans un `World` ; **le chemin incrémental** sur ces mondes et six
      mondes au hasard (~1 600 gestes : coups, creusements, vols, couches cachées / montrées / déplacées / retirées,
      choix) — après CHAQUE geste, les poses tenues par les seuls diffs égalent ce que pose de zéro une AUTRE
      implémentation de la règle écrite, `FRule::PlacementsLayered` du greffon Unreal ; chaque sorte de geste exercée
      au moins six fois ; un trait ne décide qu'une petite part des sommets ; et des règles écrites à la main (un vol,
      une couche cachée qui ne retient rien, une dalle retirée qui ouvre le ciel du sol d'en dessous). 73 vérifications.
    - **CONTRE L'APPLI** (`test_natif` §10) : trois couches menées comme l'écran les mène, en GDScript (`MassifPeint`,
      l'union partagée, `reconstruire_autour`, l'union refaite pour cacher ou monter une couche), et un `MBMonde` par
      les mêmes 80 gestes ; ses grilles ne reçoivent que ses diffs ; après chaque geste, les mêmes grilles, case pour
      case (item et orientation), variantes, poids et fautes compris. `test_natif` 143 ; les 23 suites vertes avec le
      natif (fumée 803), `test_marching_blocks` et `test_massif_peint` aussi avec `MB_NATIF=0`.
    - **MESURÉ** (headless) : un monde de 509 440 cases en trois couches, bâti en 0,9 s ; **un geste d'une case
      0,015 ms** (11 sommets décidés), un de 30 cases 0,14 ms, cacher une couche 0,22 s. Dans Godot (120 821 cases), un
      geste d'une case, diff posé dans la grille : **~0,01 ms, contre ~3 à 6 ms** pour `reconstruire_autour` natif.
    - **MUTATIONS** : noyau 12 rouges (ciel non propagé, bande du ciel raccourcie, haut de colonne non recalculé,
      changement de rang non vu, choix ignoré, déplacement sans renumérotation, tuiles sans nouvelle décision, poids
      négatifs gardés, choix sans nouvelle décision, une case vidée puis reposée comptée deux fois, une couche « cachée »
      jamais marquée comme telle, une pose vide gardée) ; pont 4 rouges (retrait oublié, retrait dans la mauvaise grille,
      variantes non lues, poids ignorés) et deux du noyau rejouées par `test_natif`. ⚠ **DEUX D'ABORD MUETTES, PAR LE
      TEST** : les tuiles d'une couche déjà PEINTE (le banc ne les posait qu'avant les cases) et une case vidée puis
      reposée dans le même appel ; et **« poids ignorés » côté pont** — les poids du test tombaient sur des clés sans
      variantes : ils portent désormais sur les deux clés à variantes que la couche pose le plus. ⚠ **DEUX
      ÉQUIVALENTES** : la bande du ciel commencée un cran plus haut (à `lo` au lieu de `lo − 1`, ou à `_y_low` dans une
      colonne vide) — un sommet à `y = lo − 1` a le haut de la colonne pour coin, donc soit ce coin ferme sa propre
      case vide du bas (sa classe ne peut pas être à l'air libre), soit la colonne n'est pas sondée. La borne prudente
      reste.
  - **LE BRANCHEMENT DANS L'APPLI (étape 3 b) — FAIT (Jordan, 6 octobre 2026 : « go pour brancher le monde dans
    l'appli »).** Le détail : `gdextension/README.md`.
    - **CE QUI CHANGE** : l'écran tient UN `MBMonde` (`editor._monde_coeur`, recréé avec le projet), donné à chaque
      couche (`MassifPeint.monde`). Une couche en couches ne décide plus ses sommets : elle s'INSCRIT au monde à son rang
      (ses grilles, son `_etat`, son `_compte`, tenus par référence) ; le monde suit l'union de l'écran (`suivre` les
      cases d'un geste, `resynchroniser` toute l'union, par `World::assign` au-delà d'un quart de cases différentes) ;
      ses changements s'accumulent en ATTENTE (le premier « avant », le dernier « après ») et `vider_attente` les pose
      dans TOUTES les couches inscrites comme le GDScript les poserait — le premier appel d'un geste pose tout. Un rang
      qui change de propriétaire fait remplir la couche depuis le monde. Une couche CACHÉE DORT (une photo de ce
      qu'elle pose ; au réveil, la seule différence). Une couche dont index, poids et choix n'ont pas bougé n'est pas
      redécidée. Les sommets MUETS (à la couche, sans surface) sont tenus par le noyau (`cls` < 0). Le noyau gagne
      `set_choices`, `assign`, les muets ; `remove_layer` est simplifié (renuméroter puis tout refaire).
    - **LE GDSCRIPT RESTE** : `MB_NATIF=0` (ou une couche sans monde, `rang` < 0) prend la route d'avant, mot pour mot.
    - ⚠ **UN DÉFAUT RÉEL DE L'APPLI, TROUVÉ PAR LE TEST DIFFÉRENTIEL** : `_montrer_couche` ne prévenait pas les AUTRES
      couches cachées — montrer B pendant que A est cachée changeait des sommets de A (la frontière), que A, en
      reparaissant, ne refaisait pas : un rendu faux jusqu'à la prochaine reconstruction complète. Le monde avait raison
      (comparé à une reconstruction complète GDScript). Corrigé (les cases de B s'ajoutent à `_a_refaire` des autres
      couches cachées) ; gardé par `fumee_appli` (deux blocs côte à côte, cacher B, cacher A, montrer B, montrer A :
      l'état = une reconstruction complète, avec et sans natif) — deux rouges sans la correction.
    - **MESURÉ** : `test_natif` 157 (§11 : l'écran mené deux fois — GDScript et branché — par 160 gestes au hasard :
      coups, déplacements, creusements, cacher / montrer, Up / Down, choix, poids, lot ; après CHAQUE geste les mêmes
      grilles, le même état dictionnaire pour dictionnaire, le même bilan ; des muets existent ; chaque sorte au moins
      deux fois ; l'attente vide ; les couches cachées dorment) ; `fumee_appli` 812 ; le noyau 77 (+4 : `set_choices`,
      `assign`, un bloc de 3³ aux 8 muets, une case vidée puis reposée) ; les 22 suites vertes avec le natif, et
      `test_massif_peint` 124, `test_marching_blocks` 1 988 et `fumee_appli` 811 avec `MB_NATIF=0` (la garde du branchement n'y a pas lieu ; `test_natif` allume et éteint le natif lui-même).
    - **MUTATIONS** : rouges — l'inscription jamais « changée », pas désinscrite ailleurs, l'attente sans retrait, les
      muets non comptés, la clé d'air libre mal nommée, `suivre` qui ne vide rien, l'attente qui garde le dernier
      « avant », la couche sans ses tuiles, sans resynchroniser, les choix hors du monde, jamais dormir.
      ⚠ **DEUX D'ABORD MUETTES, PAR LE TEST** (`suivre` qui ne vide rien, le dernier « avant ») : aucun geste ne gardait
      le compte des cases — le geste « déplacer » les a fait rougir. ⚠ **DEUX ÉQUIVALENTES** sous les routes de l'écran :
      la resynchronisation au compte (l'écran tient l'union à jour avant le geste), le rang changé sans remplir (le
      rang ne change qu'avec `_refaire_l_union`, qui reconstruit).
    - **MESURÉ, 120 821 cases en trois couches, headless** (route native d'avant → branchée) : un geste d'une case
      5,9 → 2,8 ms ; cacher 226 → 215 ms ; montrer 293 → 215 ms ; ouvrir 490 → 518 ms ; ⚠ **Up / Down 585 → 854 ms,
      PLUS LENT** : tout refait par `assign`, puis deux couches remplies. Le noyau passe 37 % dans `decide`.
    - ⚠ **PAS TENU EN MAIN** ; la DLL Windows n'a toujours pas été chargée sous Windows.
  - **INTÉGRÉ DANS `main` ET CHARGÉ SOUS WINDOWS — MESURÉ (6 octobre 2026, session SpannerGames, à la demande de
    Jordan : « pull la, complète, adapte, intègre, et exporte que je puisse tester »).** La branche cloud fusionnée sans
    conflit par-dessus l'émission PBR ; les DLL Windows RECONSTRUITES PAR MSVC 2022 (scons, godot-cpp épinglé ; seule
    dépendance : KERNEL32, le CRT est statique) à la place de celles de mingw. Sous Windows 10, Godot 4.7 headless :
    `test_natif` vert (mb_natif chargé ; 120 821 cases : poses 220 ms, océan 66 ms, massif 355 ms, un geste du monde
    du cœur 0,010 ms contre 3,98 ms) ; les 22 suites vertes avec le natif (fumée 816). MSVC laisse des `.exp` / `.lib`
    à côté de la DLL : ignorés par git.
  - **UP / DOWN OPTIMISÉ — FAIT ET MESURÉ (Jordan, 6 octobre 2026 : « Up/Down est lent, optimise-le »).** Branché, Up
    refaisait TOUT : l'union reconstruisait chaque couche, le monde redécidait chaque sommet (`assign`), puis deux
    couches se remplissaient. Or seul l'ORDRE change, et la décision d'un sommet ne lit l'ordre que par son propriétaire
    (le plus petit rang parmi ses coins visibles). **Désormais** : `World::move_layer` renumérote ses cartes EN PLACE et
    ne redécide que les sommets où la couche déplacée touche une couche qu'elle passe ; le pont (`deplacer_couche`) vide
    d'abord l'attente, fait suivre à chaque inscrit sa couche (une couche qui dort garde sa photo, renumérotée) ; l'écran
    (`_echanger_couches` → `_renumeroter_l_union`) ne renumérote l'union que pour les couches entre les deux rangs, sans
    rien reconstruire — si chaque couche visible est inscrite au monde à son rang (`_toutes_au_monde`), sinon la route
    d'avant. **MESURÉ** (Windows, headless, 120 821 cases en trois couches, `test_natif` §7) : **Up 555 → 70 ms**
    (854 ms au relevé de la session cloud ; la route native sans monde : ~500 ms) — dont le monde 30 ms (105 ms avant
    la renumérotation en place et la lecture unique de chaque sommet), l'union 16 ms, la pose des 4 920 sommets changés
    10 ms. Noyau 84 (+7 : trois blocs qui se touchent, les six déplacements contre un monde bâti dans le nouvel ordre),
    `test_natif` 158 (§11 : l'écran branché passe par cette route, ≥ 2 fois), `fumee_appli` +1 (le vrai bouton Up passe
    par le monde) ; les 22 suites vertes avec le natif, `fumee_appli`, `test_massif_peint` et `test_marching_blocks`
    aussi avec `MB_NATIF=0`. **MUTATIONS** : noyau 3 rouges (la borne basse, la borne haute, rien redécidé) — la borne
    haute d'abord MUETTE : les mondes au hasard ne déplaçaient presque jamais une couche le long d'une frontière, d'où
    les trois blocs ; écran 3 rouges (l'union non renumérotée, l'attente non posée, le rang non changé). ⚠ **DEUX
    ÉQUIVALENTES** : parcourir les cases des AUTRES couches (un sur-ensemble, plus lent) ; ôter la vérification des
    inscrits dans `_toutes_au_monde` — sous les routes de l'écran, toute couche visible est inscrite : une garde.
  - **LA COHABITATION AVEC LA SESSION DU BUREAU** : le cœur vit dans des fichiers NEUFS (`gdextension/`,
    `addons/marchingblocks_core/natif*`) ; un fichier GDScript existant ne reçoit que son AIGUILLAGE (trois lignes en tête
    de la fonction accélérée). Si une session change une fonction déjà portée, `test_natif.gd` rougit : on reporte le
    changement dans le C++, on ne fige jamais le GDScript. ⚠ **Après un `git pull`, reconstruire la bibliothèque** si
    `gdextension/src` a changé (sinon le natif d'hier répond, et `test_natif` le dit).

- **LES TEXTURES EN TRIPLANAIRE DANS LE GREFFON GODOT — FAIT (20 octobre 2026, cherché dans WaterDrop)** : les UV du
  `.glb` sont la projection en boîte choisie FACE PAR FACE ; sur une tuile sculptée et courbe (les variantes à bosse),
  l'axe change d'une face à l'autre et la texture se casse en plaques — vues de dessus, des carrés « pixellisés ». Réglage
  `triplanar` de chaque couche (allumé par défaut) : les matériaux projetés en boîte mêlent les trois projections en
  coordonnées du MONDE, à la répétition relue dans les UV du fichier (`Tileset.repeat_of`) × la taille de case × l'échelle
  de la couche. Vu à l'image : plus un carré. ⚠ **À PORTER** : l'appli elle-même (le Play test et la vue du monde ont
  le même défaut, non vérifié à l'image), Unity, Unreal. Et l'exemple cartoon : variantes remodelées (sans paliers,
  subdivisées, sculptées après l'attribution sol / paroi — `sculpter_les_variantes`), à reconstruire pour la prochaine
  sortie de l'exemple.
- **MARCHINGBLOCKS N'EST PAS FINI : L'ATELIER DES FRANCHISSEURS — DÉCIDÉ (Jordan, 20 octobre 2026 : « Mb n'est pas fini,
  il faut un workshop de franchiseurs (escaliers, pentes) éditables, et placables par dessus le terrain là où le test le
  permet »)**. Il revient sur « marching blocks est fini » (19 octobre). Né d'un manque vu dans WaterDrop : agrandi trois
  fois, une marche d'une case y fait 3 m, et les chemins du générateur montent d'une case à la fois.
  **PROPOSÉ (Claude, 20 octobre 2026), à discuter avec Jordan avant la première ligne** :
  - un atelier « Crossings » à côté de Foliage et Generate : des FRANCHISSEURS paramétrés — escalier (largeur en cases,
    hauteur à franchir, nombre et profondeur des marches), pente (largeur, hauteur, longueur), la matière d'une couche ;
    éditables après coup comme un plant (sélection, réglages, Ctrl+Z) ;
  - posés PAR-DESSUS le terrain, comme le feuillage, jamais dans les tuiles (la règle de pose ne change pas) ; **le test**
    (lecture de Claude, à confirmer) : un franchisseur ne se pose que si le bas et le haut sont des sols à ciel ouvert,
    séparés de la hauteur voulue, et que son volume ne traverse rien — vert ou rouge sous le curseur, comme le pinceau du
    feuillage ;
  - exportés dans le `.mbworld` (une clé `crossings`, dans `regle()` et `world_conformance.json`), posés par les trois
    greffons (Godot d'abord), avec leur collision ;
  - Generate en pose de lui-même aux marches de ses chemins.
  **TRANCHÉ (Jordan, 20 octobre 2026 : « Test de pose, sculpté, commençons avec pente et escaliers »)** : « le test » est
  le TEST DE POSE ; les franchisseurs sont SCULPTÉS (par l'artiste, comme un témoin, pas calculés par l'appli) ; on
  commence par la PENTE et l'ESCALIER. **OUVERT** : la version qui les porte ; échelle, pont, colimaçon plus tard.
  **L'ARCHITECTURE — PROPOSÉ (Claude, 20 octobre 2026), sur le patron de l'atelier Foliage** (relevé du code le même jour) :
  1. **LA RÈGLE, PURE** : `addons/marchingblocks_core/franchisseurs.gd` (comme `feuillage.gd` : fonctions statiques, le
     monde lu par des Callables). Un MODÈLE : {id, nom, genre « escalier » | « pente », maillage (un `MaillageEdite`
     sculpté, `.mbmesh` dans le projet), largeur, hauteur franchie, longueur — en cases}. Une POSE : {modèle, case du bas,
     quart de tour}. **LE TEST DE POSE** (`verifier`, rend "" ou une raison) : la case du bas est un sol (pleine dessous,
     vide dessus) ; le palier du haut, à `longueur` cases devant et `hauteur` plus haut, aussi ; entre les deux, le mur à
     franchir est plein et le volume au-dessus de la rampe est vide ; pas de chevauchement avec une autre pose.
  2. **LES DEUX MODÈLES DE DÉPART, SCULPTÉS** : un escalier et une pente bâtis une fois par le code (marches chanfreinées,
     pente aux arêtes roulées), puis ÉDITABLES dans le modeleur comme un maillage libre (`modeleur.charger(m)` : le chemin
     du maillage seul existe mais dort — à réessayer). L'artiste les resculpte ; le test de pose ne lit que leurs cases.
  3. **L'ATELIER** `app/atelier_franchisseurs.gd` (bouton « Crossings », l'icône « escalier » existe) : la liste des
     modèles, « Edit » (le modeleur), largeur / hauteur / longueur ; au survol, le fantôme vert ou rouge orienté de
     lui-même vers le mur ; clic : poser, clic droit : retirer, Ctrl+Z ; clé `franchisseurs` dans le `.mbproj`.
  4. **L'EXPORT** : clé `crossings` du `world.json` (`regle_franchisseurs()`, `world_conformance.json`), un `.glb` par
     modèle ; le greffon Godot pose un nœud « Crossings », un maillage par pose ET SA COLLISION (aujourd'hui le greffon
     n'en donne à rien). Unity et Unreal à la liste.
  5. Puis Generate en pose aux marches de ses chemins ; WaterDrop s'en sert pour ses marches de 3 m.
  ⚠ À ne pas confondre avec l'outil « Stairs » de World (`formes_speciales.gd`), qui taille des CASES en escalier.
  **AVANCEMENT — MESURÉ (20 octobre 2026)** :
  - **Étape 1 FAITE** : `addons/marchingblocks_core/franchisseurs.gd` (test de pose, orientation, transformation, les deux
    maillages de départ en prismes fermés, l'enregistrement) ; `test_franchisseurs` 36 vérifications (attendus écrits à
    la main ; vu rougir sur des faces non orientées).
  - **Étape 2 FAITE, SAUF LE MODELEUR** : `app/atelier_franchisseurs.gd`, bouton « Crossings » (13ᵉ atelier : la bande
    des ateliers resserrée, texte de 9, pour tenir dans 1100 × 680 — vu par la fumée) ; à la première entrée, un escalier
    et une pente ; dimensions (la forme de départ rebâtie, annulable) ; fantôme vert ou rouge orienté de lui-même vers le
    mur ; clic, clic droit, Ctrl+Z ; clé `franchisseurs` du `.mbproj`. **Batterie : 31 suites, 0 rouge.** Sonde dans la
    vraie appli sur une copie de la palette de WaterDrop (`ATELIER/MarchingBlocks/sonde_crossings.gd`, photos
    `ATELIER/MarchingBlocks/essais/crossings/photos/`) : 11 sur 11 — fantôme, pose, refus d'une seconde pose au même
    endroit, Ctrl+Z / Ctrl+Y, enregistré et relu.
  - **Étape 2 bis FAITE** : « Edit shape » — le modeleur sur le maillage du modèle seul (`temoin = null`), les gestes
    deviennent des actions annulables du modèle, « Done » / Tab / Échap rendent le monde ; sonde : geste, Ctrl+Z / Ctrl+Y,
    forme gardée après réouverture. ⚠ La barre ne montre pas encore les outils du modeleur (modes, pinceaux) : les
    raccourcis seuls ; la caméra cadre le modèle de loin.
  - **Étape 4 FAITE** : clé `crossings` du `world.json` (`regle_franchisseurs`, un `.glb` par modèle, la matière d'une
    couche — choisie, ou celle du sol sous son pied), greffon Godot `mb_crossings.gd` + `mb_crossings_node.gd` (un
    StaticBody3D par pose, collision des triangles, textures en triplanaire) ; `test_franchisseurs` 44 vérifications, dont
    la parité de pose appli / greffon à chaque quart. **MESURÉ DANS WATERDROP** : 96 pentes posées sur les chemins de
    l'île verte (`poser_franchisseurs.gd`, `FR.poser_partout`) ; la goutte en monte 3 sur 4 (2,9 m, une case du monde
    agrandi trois fois).
  - **RESTE** : 5 Generate ; Unity et Unreal ; la quatrième pente de la sonde (pas montée, à comprendre).
  - **LES LÈVRES PAR MATIÈRE — DÉCIDÉ (Jordan, 20 octobre 2026 : « tu n'hésiteras pas à faire des lèvres différentes selon
    les matières selon une réflexion cohérente, comme par exemple des bordures de plateaux comme dans les Zelda top down,
    ou autre »)** : à faire dans les témoins (les clés de lèvre, `mb_arete_*`), matière par matière.
  - ~~**RESTE** : 2 bis « Edit shape » (le modeleur sur le maillage libre du modèle, chemin qui dort) ; 4 l'export
    (`crossings` du `world.json`) et le greffon Godot avec collision ; 5 Generate.~~
- **LA FIN DU DÉVELOPPEMENT — DÉCIDÉ (Jordan, 2 octobre 2026)** : le logiciel est COMPLET en fonctions. L'ordre
  qui reste : **les greffons et les optimisations** (quand tout est fini), **puis les tests** (Jordan, en main),
  **puis la commercialisation**. Lancement en **accès anticipé, 0.9.0** (ci-dessous). **LES PROPS SONT ABANDONNÉS
  POUR LA 0.9 / 1.0 ET REMIS À UNE MISE À JOUR FUTURE** (§3, « le terrain monolithique et les props »).
  ⚠ **PRÉCISÉ (Jordan, 6 octobre 2026)** : la 1.0.0, vendue au prix plein, apportera DEUX ATELIERS NEUFS — **Props**
  (objets en tout genre, végétaux compris) et **Houses** — offerts aux acheteurs de la 0.9.0, ce qu'il faut ANNONCER dès
  le lancement (document de stratégie). **OUVERT** : leur lien avec les props rattachés du §3.
  ⚠ **REMPLACÉ (Jordan, 19 octobre 2026 : « la 1.0.0 va être juste après avoir fini cela, et après avoir ajouté le
  smooth shading des tuiles »)** — **LA 1.0.0 = L'ATELIER DE GÉNÉRATION DE MONDE (sans IA) + LE SMOOTH SHADING DES
  TUILES, et elle sort juste après eux.** **Props et Houses passent APRÈS la 1.0** (Jordan, même jour), en mises à jour
  toujours offertes aux acheteurs de l'accès anticipé (le contrat couvre déjà « la 1.0 et toute mise à jour
  ultérieure »). Le détail : « UN ATELIER DE GÉNÉRATION DE MONDE », plus bas.
- **L'EXEMPLE LIVRÉ — DÉCIDÉ (Jordan, 2 octobre 2026), ÉCRIT LE MÊME JOUR** : « un mode Exemple qui garde le
  projet `C:/Users/jorda/Desktop/test.mbproj` et continue de le mettre à jour avec les modifications que je vais
  continuer de faire tant que le dev n'est pas clos, figé ensuite ».
  - `DEV_TOOLS/prendre_l_exemple.gd` emballe ce projet dans `exemple/exemple.zip` — LANCÉ PAR
    `exporter_marchingblocks.sh` avant chaque export (un échec arrête l'export). Il ne fait que LIRE chez Jordan
    (MD5 vérifiés). Les chemins absolus deviennent `{EXEMPLE}/…`, le nom « test » devient « example ».
  - ⚠ **LE .glb DE CHAQUE TÉMOIN EST REFAIT DEPUIS SON .mbtiles** : chez Jordan `test_witness.glb` n'existe pas
    (la couche tient de son CACHE, que l'acheteur n'a pas) — sans lui, l'exemple s'ouvrait en cubes rouges
    (mesuré par mutation : Hills, 0 tuile, 75 153 fautes).
  - **L'appli** (`app/exemple.gd` ; « The example » dans World — le bouton à part dans Project a été RETIRÉ, Jordan, 2
    octobre 2026 : « on a l'exemple dans exemple, plus besoin de l'exemple en projet séparé » ; et le manuel) l'installe dans
    `user://example/<STAMP>/`, chemins réécrits, et l'ouvre comme un projet ordinaire. ⚠ **JAMAIS ÉCRASÉE** :
    l'exemple s'enregistre tout seul ; un exemple plus récent (autre STAMP) s'installe à côté.
  - **L'EXEMPLE NE S'IMPOSE PAS — DÉCIDÉ (Jordan, 2 octobre 2026 : « un bouton exemple et un bouton world dans
    World, le soft ne doit pas forcer l'exemple à l'arrivée »), ÉCRIT LE MÊME JOUR.** Le défaut : ouvrir l'exemple
    le retenait comme « dernier projet », et chaque lancement suivant le rouvrait. `reglages.cfg` retient désormais
    À PART ton monde (`projet/monde`, jamais l'exemple — `est_l_exemple` : sous `Exemple.RACINE`), et c'est lui qu'on
    rouvre au lancement ; un réglage d'avant qui ne retient que l'exemple est écarté (projet neuf). Dans World, deux
    boutons, **My world** et **Example** (le projet ouvert enfoncé), seulement si l'exe porte un exemple.
    `--open-example` reste (la démo). Gardé par `fumee_appli` (547, +7, sans l'archive : un faux exemple dans
    `user://example`, les réglages réécrits puis rendus) ; trois mutations rouges (l'exemple retenu comme ton monde,
    le lancement qui ne l'écarte pas, les boutons partout). ⚠ **LES DEUX RESTAIENT ENFONCÉS (vu par Jordan, 2 octobre 2026)** :
    `set_pressed_no_signal` IGNORE le ButtonGroup ; `_dire_le_projet` règle désormais les deux. Gardé par `fumee_appli`
    (le code d'avant rejoué : deux rouges).
    **UN CHOIX SOUS SA SECTION, PLUS DEUX BOUTONS (Jordan, 2 octobre 2026 : « My world et Example devraient être un
    choix sous une section plutôt que des boutons collés aux ateliers, c'est pas clair »)** : la section « Which
    world » de World, deux cases rondes (My world · The example). ⚠ Pas tenu en main, ni
    éprouvé dans l'exe (l'archive n'existe que sur le PC).
  - **`MarchingBlocks.exe --open-example`** l'ouvre au lancement (une démo, et l'épreuve de l'exe sans clic).
    **ÉPROUVÉ DANS L'EXE CHIFFRÉ** : l'archive est lue depuis le PCK chiffré, installée (7 fichiers), le monde
    s'ouvre texturé, 2 couches, aucun cube rouge (capture d'écran) ; `test.mbproj` intact (MD5).
  - **SES TÉMOINS ONT ÉTÉ RÉPARÉS (Jordan, 2 octobre 2026 : « des trous qui datent de quand la subdivision ne se
    répandait pas à tout le témoin »)** — `DEV_TOOLS/reparer_temoins.gd` (mesure seule par défaut ; `--ecrire` garde
    chaque original en `.avant_reparation`, `.glb` compris). **MESURÉ, les deux couches identiques** : 159 points
    absents de leur classe de sections, tous dans la classe 5, et 366 sommets de joint sans partenaire. ⚠ **CE
    N'ÉTAIT PAS QUE DES SECTIONS** : `completer` échouait 159 fois sur 159 (les points de la subdivision d'alors
    avaient été DÉPLACÉS hors des arêtes des autres faces), et trois tuiles étaient ABÎMÉES dans leur maillage —
    `arete_b2h0_dehors`, `coin_b1h0_dehors`, `equerre_b3h0_dehors` : 26 arêtes ouvertes hors des coupes, 29 à plus
    de deux faces (faces en double retournées l'une contre l'autre, faces superposées). Ôter les doublons ne les
    refermait pas.
    - **DÉCIDÉ (Jordan) : les remettre à neuf.** Le témoin CALCULÉ ne convenait pas (sa section diffère de la
      sculpture propagée jusque sur les arêtes de case : 278 absences, 3 faces repliées) ; elles reprennent la
      géométrie de leur JUMELLE sous roche, même forme, saine et déjà calée (`--depuis=mb_arete_b2h0:mb_arete_b2h0_dehors,…`).
      Leur sculpture et leur peinture d'air libre sont perdues — à refaire.
    - `_conformer` (la section portée par le plus de faces fait foi ; les points manquants prennent les intrus les plus
      proches, par paires, jusqu'à 0,1 case ; les autres glissent dans leur plan) n'a plus eu qu'un sommet à déplacer,
      de 0,004 case. **Après, relu sur le disque : 0 absence, 0 sommet de joint sans partenaire, 0 arête ouverte, 0 à
      plus de deux faces, 0 face repliée.** Vu à l'image dans l'exemple remballé (`DEV_TOOLS/capture_exemple.gd`).
    - ⚠ Pas de mutation : un outil de réparation à usage unique, jugé par des mesures qui ne passent pas par lui
      (`_sans_partenaire` recopié de `test_sections`, `_variete`). ⚠ Pas jugé par Jordan.
  - **POUR LE FIGER** : créer `exemple/FIGE` (l'emballeur ne reprend plus rien), retirer `exemple/exemple.zip` du
    `.gitignore` et le commiter — tant qu'il vit, il n'entre pas au dépôt (repris à chaque export).
  - **ÉDITER L'EXEMPLE PENDANT LE DÉV — DEMANDÉ PAR JORDAN (3 octobre 2026) ET ÉCRIT** : « un moyen qui ne se retrouve
    pas dans le produit final d'éditer l'exemple pendant le dev et de le maintenir dans le soft ». Puis : on itère sur
    un PROJET PREUVE jusqu'à la perfection, et c'est lui qui devient l'exemple du produit.
    - **LA SOURCE** est un projet ordinaire n'importe où ; son chemin est dans `~/.marchingblocks/exemple_source.txt`
      (HORS du dépôt, comme la clé), sinon `C:/Users/jorda/Documents/MarchingBlocks/test/test.mbproj`.
      ⚠ **RANGÉE LE 4 OCTOBRE 2026 (Jordan : « faire le ménage sur le Bureau »)** : `test.mbproj` et ses 18 fichiers
      (témoins, `.glb`, dossiers `_images`, sauvegardes `.avant_*`) sont passés du Bureau à
      `Documents/MarchingBlocks/test/` ; les chemins absolus réécrits dans 7 fichiers texte (`.mbproj`, `.mbtiles`), les
      réglages de l'appli et le pointeur aussi. Partout où la charte dit `Desktop/test.mbproj`, c'est ce projet. `prendre_l_exemple.gd` lit la même
      (`dev_exemple.gd` : `source()`).
    - **LE MODE DEV** (`DEV_TOOLS/dev_exemple.gd`, EXCLU DE L'EXPORT avec tout `DEV_TOOLS/*`) : lancé par
      **`DEV_TOOLS/editer_l_exemple.cmd`** (Godot sur les sources, `-- --dev-example`). Il ouvre la SOURCE au lancement,
      la compte comme « l'exemple » (« Which world » coche The example, et « The example » ouvre la source, pas la copie
      installée), montre une section **DEV · EXAMPLE** (la source, *Open the example source*, *Use this project as the
      example* — qui réécrit le pointeur —, *Repack the example now*) et **RÉEMBALLE `exemple/exemple.zip` À LA
      FERMETURE** si la source a été ouverte. ⚠ L'écran ne le charge que sans modèle d'export ET avec le drapeau : les
      suites ne l'allument jamais (elles n'ouvriront pas la vraie source). `exemple/FIGE` arrête aussi ce réemballage.
    - ⚠ **LES TRAVAUX IMPORTÉS** (la liste de l'étape 2, enregistrée dans le projet depuis le même jour) sont des
      raccourcis de l'auteur : l'emballeur les retire du `.mbproj` (sinon leurs `.glb` partiraient dans l'archive).
    - **MESURÉ** : `test_projet` (+8 : pointeur absent / désigné / refusé, le drapeau éteint, `DEV_TOOLS/` exclu, un
      vrai réemballage, sans la liste des travaux) ; `fumee_appli` (+5, pointeur et archive JETABLES —
      `pointeur_force`, `archive_force` : « The example » ouvre la source, elle compte comme l'exemple, jamais retenue
      comme ton monde, la fermeture réemballe) ; deux mutations rouges (l'emballeur qui garde les travaux, la fermeture
      qui ne réemballe pas). ⚠ Le lanceur `.cmd` et la section DEV n'ont pas été menés avec fenêtre ni à la main.
    - ⚠ **L'EXEMPLE ACTUEL** (repris le 3 octobre) porte une couche « Grass » SANS CASE (toutes prises par GreyRock,
      couches exclusives) : la fumée l'exigeait peinte — corrigée, une couche vide ne pose rien.
  - **MESURÉ** : 7 fichiers, 865 Ko ; `test_projet` 72 (archive bâtie à la main : chemins réécrits, image octet pour
    octet, pas d'écrasement, un STAMP neuf à côté, refus) ; `fumee_appli` 535 (la VRAIE archive par le bouton, dans
    un dossier de données vierge : 2 couches, leurs cases, leurs tuiles, 0 faute, rien de « missing »). Quatre
    mutations rouges (chemins non réécrits, installation écrasée, STAMP ignoré, `.glb` non refaits).
  - ⚠ **UN LANCEMENT DE L'EXE A OUVERT `test.mbproj` (2 octobre 2026, 07:11)** : le projet d'essai passé en argument
    était refusé (mauvais `format`), et l'appli est retombée sur le DERNIER projet ouvert. Il a été réécrit à la
    fermeture ; ses deux couches n'ont aucune case commune, donc la migration des couches exclusives n'a rien pu
    lui retirer. Pour éprouver l'exe : un projet d'essai VALIDE, et `reglages.cfg` sauvé et rendu.

- **LA CLÔTURE DE LA 1.1.0, AVANT TOUTE COMMUNICATION — DÉCIDÉ (Jordan, 1er octobre 2026)**, transmis par une
  autre session à celle qui tient la stratégie de commercialisation : au moment de clore le développement de la
  1.1.0, et AVANT que la communication commence, on fait **un monde entier, de taille raisonnable**, créé dans le
  logiciel et/ou peint dans les **trois greffons** (Godot, Unity, Unreal), **en se filmant** pendant qu'on le fait ;
  puis on **monte la vidéo du trailer** à partir de ces prises. C'est une étape du plan de sortie : le trailer
  vient du vrai produit en train de servir, pas d'images arrangées.
  - ⚠ Elle tombe APRÈS « les greffons attendent la fin du logiciel » (ci-dessus) : les trois greffons doivent
    avoir rattrapé le logiciel avant qu'on y peigne pour la caméra.
  - **PROPOSÉ (2 octobre 2026), dans la stratégie de lancement** (le document Claude « MarchingBlocks — stratégie de
    lancement », section « La clôture de la 1.1.0 et le trailer », et son calendrier) : gel le 13 novembre, les
    greffons rattrapent du 16 novembre au 4 décembre, le monde filmé du 7 au 13 décembre, le montage du 14 au 18,
    et RIEN DE PUBLIC avant : la communication commence avec la page Steam et le trailer le 21 décembre, lancement
    le 12 janvier 2027.
  - ⚠ **LE 21 DÉCEMBRE EST ABANDONNÉ — DÉCIDÉ (Jordan, 17 octobre 2026 : « oublie le 21, je sors ça dès que j'ai
    l'argent pour Steam et l'INPI »)** : rien de public avant le dépôt de la marque et l'AppID, puis sortie TOUT DE SUITE
    (page Steam, trailer, publications). Les « 21 décembre » de cette charte sont l'ancien plan. L'état global :
    `D:/SpannerGames/ETAT.md`. Une île d'environ 64 × 24 × 64 cases ; Jordan à la souris (les plans de caméra peuvent être
    scriptés) ; OBS Studio et DaVinci Resolve ; 60 s, et une version de 2 min.
  - ⚠ **OUVERT, À JORDAN** : la charte dit « 1.1.0 », l'appli affiche v0.1.0 et le document numérotait l'accès
    anticipé 0.1 ; le document propose que la 1.1.0 soit la version de lancement.
  - **DÉCIDÉ (Jordan, 2 octobre 2026) : le lancement est un ACCÈS ANTICIPÉ, en 0.9.0** ; 1.0.0 à sa sortie (le prix
    plein). Posé le même jour dans `project.godot` (`config/version`) et dans les propriétés de l'exe
    (`export_presets.cfg`, 0.9.0.0). ⚠ La version entre dans l'empreinte du témoin calculé (`Projet.empreinte`) : à
    la première ouverture, son lot est retranché une fois ; et l'exe se réinscrit dans Windows (version changée). Un 1.x se lit « fini », ce qu'un accès anticipé
    dit justement ne pas être ; et un 1.1.0 sans 1.0 publié fait demander où est passée la 1.0.
  - **0.9.2 (Jordan, 16 octobre 2026 : « monte en 0.9.2 et exporte »)** : `config/version` et les propriétés des trois
    préréglages (0.9.2.0). Les devlogs de cette version montrent les fonctions venues après l'export du 10 octobre.
  - **0.9.3 (Jordan, 16 octobre 2026 : « passer à la 0.9.3 après avoir mis tous les boutons d'atelier dans une bande à
    gauche de la barre de gauche, afin de libérer de l'espace pour la barre de gauche elle-même, qui est trop remplie »)** :
    `config/version` et les trois préréglages (0.9.3.0). **LA BANDE DES ATELIERS** (`editor._batir_rail`, `LARGEUR_RAIL`
    76) : les onze ateliers, icône au-dessus du nom, l'un sous l'autre dans l'ordre d'avant, épinglés, au bord de la
    fenêtre ; la barre de gauche commence après elle (300 px gardés), sans le titre WORKSPACE ni la grille de deux
    (~290 px de haut rendus à la barre). La légende des formes et le guide partent de `BORD_GAUCHE`. Gardé par
    `fumee_appli` (au bord, la barre juste après, sa largeur gardée, le dernier atelier tient, aucun atelier dans la barre).
    ⚠ Ni vu à l'image ni tenu en main ; à 680 px de haut, les onze tiennent de justesse (11 × 51 px).
    **EXPORTÉE (16 octobre 2026, sur le PC, `D:/MarchingBlocks/build`, rangée le 17 dans `D:/SpannerGames/ATELIER/MarchingBlocks/builds/0.9.3`)** : 28 suites vertes (`fumee_appli` 1117, avec
    l'exemple = le monde client), les trois exe de 334,6 Mo (l'exemple pèse : il était à ~175 Mo), chiffrés (0 chaîne
    sur 7), la sonde « natif=1 licence=1 edition=site|steam|demo version=0.9.3 » et la DLL dans les modules, la clé signée
    acceptée et la trafiquée refusée, l'installeur `MarchingBlocks-0.9.3-setup.exe` (285 Mo), les `.vdf`. Le zip de la
    démo : `04_exports/demo/MarchingBlocks_Demo_0.9.3_Windows.zip` (278,6 Mo, contre 132,6 Mo en 0.9.2). ⚠ Aucun des exe
    n'a été lancé à la main ; le contrat a toujours ses blancs.
  - **0.9.4 — DÉCIDÉ (Jordan, 18 octobre 2026)** : la prochaine version. Toute modification du logiciel faite après
    l'export 0.9.3 y part. Au moment d'exporter : `config/version` et les trois préréglages (0.9.4.0), comme pour la
    0.9.3. **POSÉE le 18 octobre 2026** (Jordan : « aligne tout ce qui a été fait dans MB sur le PC et ici, POM etc., 0.9.4 ») :
    `config/version` et les trois préréglages (0.9.4.0). **EXPORTÉE LE 18 OCTOBRE 2026** (`ATELIER/MarchingBlocks/builds/0.9.4`) :
    28 suites vertes, les trois exe de **79 Mo** (334,6 en 0.9.3 : l'exemple n'est plus dedans), chiffrés, la sonde
    « natif=1 licence=1 version=0.9.4 », la clé signée acceptée et la trafiquée refusée, l'installeur (29 Mo) ; le zip de la
    démo `04_exports/demo/MarchingBlocks_Demo_0.9.4_Windows.zip` (36,6 Mo). **TROIS EXEMPLES À TÉLÉCHARGER** (Jordan : « l'exemple
    monde client, l'exemple cartoon et l'exemple station v2, tous les trois sur itch ») : `prendre_l_exemple.gd -- --projet=…
    --sortie=… --nom=…` → `builds/0.9.4/exemples/` (client 174 Mo, cartoon 246 Mo, station 204 Mo) ; chacun installé dans un
    dossier jetable et ouvert dans l'appli (17, 13, 14 couches ; 0 chemin cité absent). L'upload : `C:/Users/jorda/
    pousser_itch.cmd` (butler, après `butler login` par Jordan).
  - **0.9.4.1 — LE CORRECTIF DES EXEMPLES DÉZIPPÉS (Jordan, 18 octobre 2026 : « le build 0.9.4 installé n'arrive pas à
    ouvrir le projet exemple cartoon »)**. Le zip décompressé sur le Bureau, son `.mbproj` ouvert : les 17 couches en cubes
    rouges (« {EXEMPLE}/… is missing ») — seul « Open… » sur le .zip remplaçait la marque. `Exemple.installer_sur_place`,
    appelé par `_ouvrir` : un projet qui contient encore `{EXEMPLE}` voit ses `.mbproj` et `.mbtiles` réécrits vers son
    propre dossier. **EXPORTÉE ET POUSSÉE (18 octobre 2026)** : 28 suites vertes (`test_projet` 147), sonde « version=0.9.4.1 »,
    l'installeur `builds/0.9.4.1/installeur/MarchingBlocks-0.9.4.1-setup.exe` ; les trois zips de la 0.9.4 décompressés à la
    main puis réécrits : 0 marque restante, 0 chemin absent (114, 76, 161 cités). La démo sur itch (`windows-demo`) ; les
    exemples inchangés. ⚠ La page itch s'appelle désormais `spannergames/marchingblocks-free-demo`.
  - **0.9.4.2 — LE RELIEF QUI MARCHE SUR LES TROIS EXEMPLES (Jordan, 18 octobre 2026 : « il n'y en a aucun effet visible
    quand on l'active dans cartoon », puis « passe les 3 exemples en leur produisant toutes les maps PBR possibles y compris
    la hauteur »)**. MESURÉ par `sonde_relief.gd` sur l'exemple cartoon dézippé : **0 matériau à hauteur sur 34**. Deux causes :
    - ⚠ **L'EMBALLEUR NE PRENAIT QUE LES IMAGES CITÉES** : le témoin cite l'albedo ; normale, rugosité, occlusion, métal,
      hauteur et ÉMISSION se trouvent À CÔTÉ par leur nom. La station perdait ainsi ses normales et sa lueur, le monde client
      ses ensembles Poly Haven complets. `prendre_l_exemple.gd` emporte désormais les compagnons de chaque image
      (`Peinture.fichiers_de_l_ensemble`) ; gardé par `test_projet` (vu rouge sans : seul l'albedo partait).
    - Le cartoon n'avait QUE la couleur, la station tout SAUF la hauteur : `SpannerGames/PROJETS/MarchingBlocks/01_scripts/
      cartes_pbr_exemples.py` les calcule (bibliothèque ET copies dans les projets, sans rien écraser). Cartoon : hauteur =
      détail fin de la luminance (un aplat reste plat ; ce qui LUIT est un creux), normale, AO, rugosité par matière, métal
      noir. Station (usinée) : plaques plates, JOINTS creusés là où sa normale change d'un coup. ⚠ Vu au Play test : la
      hauteur intégrée de la normale (Frankot-Chellappa, corrélation 0,84-0,99) faisait onduler la coque — abandonnée.
    - **L'ÉCRAN DIT CE QUE LE RELIEF ALLUME** (`Vue.relief_compte` → `editor._dire_le_relief`) : « Relief (POM) on N of M
      material(s) », ou pourquoi rien ne s'allume. Gardé par `fumee_appli`.
    - **MESURÉ, exemples dézippés à la main** : cartoon **34 / 34**, monde client **24 / 25**, station **27 / 28** (le
      matériau restant de chacun : NON IDENTIFIÉ, probablement animé, sans POM) ; photos sans / avec regardées
      (les pavés, les briques, les joints de coque se creusent, les lignes de la coque restent droites).
    - **LE RELIEF DES TEXTURES EN PLAY TEST ET EN PLAY EDIT** (Jordan, 18 octobre 2026 : « on peut rajouter du parallax
      activable en play test et play edit ? »). **LE POM — DÉCIDÉ (Jordan, 18 octobre 2026 : « oui »), FAIT ET MESURÉ**
      (détail plus bas). Le choix, proposé par Claude : le POM plutôt que le parallax simple. Le parallax
      simple décale la texture d'un seul cran : ça fait illusion de face, mais ça glisse et se déforme dès qu'on regarde
      de biais, ce qui est justement la vue du personnage. Le POM (parallax occlusion mapping, le « deep parallax » de
      `StandardMaterial3D` : `heightmap_enabled`, `heightmap_deep_parallax`, couches mini/maxi) marche la carte de hauteur
      par pas et masque les creux : des joints de dalles et des pavés qui ont l'air vraiment creusés. Le coût est par
      pixel ; une RTX 2060 le tient, et une case qui le coupe garde les petites machines. Rien ne manque côté données :
      les cartes de hauteur existent déjà (`cartes_pbr.gd` les calcule depuis l'albedo et les reconnaît à l'import :
      `height`, `displacement`, `disp`, `bump`). Les matériaux sont en UV et non en triplanaire, or le relief de Godot ne
      marche pas en triplanaire. Où le poser : une case « Relief (POM) » et un curseur de profondeur dans
      `REGLAGES_RENDU` (`vue.gd`), qui sert déjà au Play test et au Play edit ; décochée par défaut, et non enregistrée,
      comme les autres réglages de cette barre. ⚠ Ce que le POM ne fait pas : la silhouette reste plate (un bord de
      falaise ne se dentelle pas), et aux angles rasants il se tasse.
      **COMMENT C'EST FAIT (18 octobre 2026).** ⚠ Les tuiles du Play test ne sont PAS les matériaux de
      `MaillageEdite.materiau_godot` : elles sont TRANCHÉES DU .glb du témoin (et relues du cache `user://cache/*.res`),
      et le glTF ne porte pas la hauteur. Une méta posée sur le matériau du témoin n'arrivait donc jamais jusqu'au jeu ;
      la sonde l'a montré. L'écran retrouve la hauteur par le NOM du matériau (le nom que le .glb a gardé), dans le
      témoin de la couche : `Vue.fournisseur_de_hauteur` → `editor._hauteur_du_materiau` → `MaillageEdite.hauteur_de`
      (même choix que `materiau_godot` : l'ensemble PBR s'il donne le relief et qu'il a une normale, sinon la carte
      déduite, `Peinture.cartes_de(…)["texture_hauteur"]`, tenue à jour avec les autres cartes). `Vue._appliquer_relief`
      allume le POM (couches 8 → 32, profondeur du curseur, 4 par défaut) sur les matériaux à hauteur ET à normale (le POM
      lit les tangentes), et l'éteint en quittant le Play test : ces matériaux sont aussi ceux du travail.
      **MESURÉ** : la fumée (le monde n'a que la légende : cocher n'allume rien, contrôle négatif) ; et
      `DEV_TOOLS/sonde_relief.gd`, avec fenêtre, sur une COPIE du monde client (`SpannerGames/ATELIER/MarchingBlocks/
      essais/relief/`) : **40 matériaux à hauteur sur 42, les 40 allumés**, photos sans/avec à la même pose
      (`essais/relief/photos/`) : les briques du rempart et les galets de l'herbe prennent du creux, sans artefact
      visible à la profondeur 4. ⚠ Pas encore tenu en main par Jordan ; un matériau ANIMÉ (shader) n'a pas de POM.
      ⚠ La sonde rouvre un projet que l'appli vient d'ouvrir d'elle-même : deux erreurs « previously freed » dans
      `_habiller_couche` (un tranchage en fond de la première ouverture). Elles sont dues à la sonde, mais elles montrent
      qu'ouvrir un projet pendant le tranchage en fond du précédent n'est pas gardé — CORRIGÉ le même jour (« une ouverture de projet à la fois », plus bas).
      **LE RELIEF PART AUSSI DANS LES JEUX — DÉCIDÉ (Jordan, 18 octobre 2026 : « oui »)** : une ligne de plus dans la
      LISTE DES GREFFONS À FAIRE (« le relief »).
    - **UN ATELIER DE GÉNÉRATION DE MONDE** (Jordan, 18 octobre 2026 : « un workshop AI avec un modèle à nous, pour faire
      ce que tu es en train de faire en créant un monde, avec une liste de champs à remplir et le modèle fait tout »).
      **C'EST LA 1.0.0, SANS IA — DÉCIDÉ (Jordan, 19 octobre 2026)** : l'étape 1 ci-dessous, avec le smooth shading des
      tuiles ; l'étape 2 (le modèle local) reste OUVERTE, après la 1.0. **Ce que le générateur règle — DÉCIDÉ (Jordan,
      19 octobre 2026 : « des mondes de taille / forme / réseaux de chemins / souterrains / aspects différents ?
      contrôlables ? » — « fais-le »)** :
      - **Taille** (cases en x, y, z ; la borne est la mémoire et le temps, l'exemple fait 739 481 cases) ; **forme**
        (île, archipel, continent, vallée, plateau, ou un croquis en image ; la « station fermée » proposée n'est pas
        écrite : ce n'est pas un relief) ; **relief** (hauteur,
        falaises franches ou douces, étages, bosses 3D qui débordent comme la montagne de `filmer_formes`) ;
      - **chemins** : des lieux posés (village, ruines…) reliés par des routes CALCULÉES sur le relief, jamais plus
        d'une case à monter (le `_route` de `filmer_haut`), ponts et escaliers taillés ;
      - **souterrains** : galeries, salles, puits, entrées cachées, salles noyées, par les VRAIES formes spéciales sur
        un graphe de salles (comme `filmer_galeries`) ;
      - **eau** : mer, sources, lacs en altitude, cascades (bassins échancrés), lave, marais — le calcul de l'appli
        fait couler ; **aspect** : biomes et leurs parts, textures par couche, feuillage, transitions, météo.
      - **Trois niveaux de contrôle** : (1) des curseurs et une GRAINE (même graine, même monde) ; (2) un CROQUIS peint
        à plat (mer, montagne, village, trait de rivière) que le générateur remplit ; (3) VERROUILLER une zone et
        regénérer le reste. Le monde généré est un monde ordinaire : on le reprend aux outils habituels.
      - **Les règles qu'il tient (payées par les tournages)** : une matière par niveau (pas deux couches côte à côte au
        même étage, sauf transition cochée) ; « Fix diagonal contacts » sur chaque monde ; marches d'une case et
        tunnels d'au moins 3 cases (le stickman passe) ; un bassin ne déborde que par son point le plus bas. Un monde
        généré est donc JOUABLE d'office.
      **ÉCRIT ET MESURÉ (19 octobre 2026, commit `b19338d`) — l'atelier « Generate »** (rail, entre Fluids et Geometry) :
      - `app/generateur.gd` (pur) : formes île, archipel, continent, vallée, plateau et CROQUIS (une image peinte
        ailleurs : bleu mer, vert terre, gris montagne, blanc pics, jaune rivages, taches rouges = places) ; massifs par un
        bruit lent, élévation ÉTIRÉE (la colonne du 99,5e centile touche le haut) ; falaises = palier ET marche maximale
        (1 à 4) ; neige et roche en PARTS de la terre (15 % et 35 % à fond), pas en hauteur fixe ; places reliées par
        `AStarGrid2D` (pente chère, mer fermée), tranchées et remblais d'une case par pas ; souterrain : salles, galeries
        3 × 3, escaliers et puits, parois « souterrain », fermé hors des entrées ; mer (source dans le vide), lacs et mares
        de lave en cuvettes à digue FIGÉE, sources sur un haut près d'une chute ; contacts réparés (colonnes, puis sous
        terre en creusant d'abord) ; un rôle par plat. 160 × 160 × 40 : ~195 000 cases en 1 à 2 s.
      - `app/atelier_generation.gd` : les champs (sliders, graine, « New seed », forme, « Sketch image… », « Blend
        materials », « Rock under the surface », « Replace the whole world » — par défaut : toutes les cases de toutes les
        couches et tous les plants partent), l'aperçu vu de haut (0,3 s après le dernier cran), la COUCHE DE CHAQUE RÔLE
        (proposée par son nom : grass, rock, sand, snow, path, cave… ; sinon le repli). `editor._poser_le_monde_genere` :
        les cases en UNE action, l'eau et les plants dans une seconde ; les transitions demandées allumées. Les champs
        partent avec le `.mbproj` (`"generateur"`).
      - **MESURÉ** : `test_generateur` (72 : graine, formes, contacts sur TOUTES les cases, chemins atteints à pied,
        plafonds de trois cases, souterrain fermé, cuvettes qui ne fuient pas — chacun VU ROUGIR par mutation), fumée
        (1137 : l'atelier par l'écran, la boîte, le monde entier, deux Ctrl+Z case pour case), `test_projet` (155). À
        L'IMAGE : `DEV_TOOLS/sonde_generation.gd` sur une copie du monde cartoon (`SpannerGames/ATELIER/MarchingBlocks/
        essais/generation/`) : 112 × 112 posé en 6 s, île, lacs, mare de lave, chemins, roche, neige, Play test sur une place.
      - ⚠ VU À L'IMAGE ET CORRIGÉ : une mare de lave semblait couvrir la mer (l'ancien monde restait autour de la boîte et
        la source de mer tombait sur sa terre → « Replace the whole world » par défaut) ; la digue d'une cuvette était
        rabotée par `_relacher` (elle est figée) ; le rail débordait avec douze ateliers (icône 16, marges 2 et 1).
      - **PAS ENCORE** : le feuillage n'est pas généré ; le croquis se peint AILLEURS (pas de toile dans l'atelier) ;
        « verrouiller une zone » n'existe que comme « Replace the whole world » décoché (seule la boîte change) ; pas de
        page au manuel (F1) ni au site ; les arches et étages en surplomb ne sont pas générés.
      **LE SMOOTH SHADING DES TUILES — DÉCIDÉ (Jordan, 19 octobre 2026), À ÉCRIRE.** Aujourd'hui tout est en normales
      PAR FACE (le .glb part sans normales : ombrage plat imposé par glTF ; le manuel dit « ne pas lisser »). ⚠ Lisser
      demande des normales qui S'ACCORDENT d'une tuile à l'autre et d'une couche à l'autre (les bords sont partagés,
      §« bords partagés ») — sinon chaque joint se voit en ligne d'ombre ; et un angle de coupure pour garder les
      arêtes vives. Le .glb, les trois greffons et la page 6 du manuel suivent.
      **ÉCRIT ET MESURÉ (19 octobre 2026)** : `TemoinLie.lissage` (angle de coupure, 0 = plat, dans le `.mbtiles`, rien
      d'écrit s'il est plat), donné à chaque tuile ; `MaillageEdite.normales_des_coins` : éventails autour de chaque
      sommet coupés aux arêtes plus vives que l'angle, moyenne pondérée par l'angle du coin ; la projection des UV garde
      la normale de la FACE. **LE BORD** (une face de la case, ±0,5) : la normale ne vient que de la COUPE partagée —
      dans le plan de la case, perpendiculaire aux deux sommets de coupe voisins, du côté de l'éventail ; sur une arête
      de la case, l'axe restant. Les deux tuiles voisines calculent donc la même, quelle que soit la voisine que le monde
      pose (plus simple que la moyenne par classes de `sections.gd` que proposait l'exploration : les cartes 2D y
      auraient dû passer en 3D). Prix connu : une pente qui traverse un bord y paraît un peu plus droite, sur une bande.
      Interface : Texturing › Shading (« Smooth shading », « Sharp above », 40° par défaut, annulable). Le greffon Godot
      ne passe plus par `ImporterMesh.get_mesh()` (14° de travers : une couture à chaque joint). **MESURÉ** :
      `test_lissage` (12 : arête vive gardée, courbe lisse, normales unitaires, BORD COMMUN entre deux tuiles au relief
      différent — VU ROUGIR sans la règle du bord —, le témoin le garde), batterie 30 suites vertes ; à l'image
      (`DEV_TOOLS/sonde_ombrage_lisse.gd`, copie du monde cartoon, `SpannerGames/ATELIER/MarchingBlocks/essais/
      lissage/photos/`) : à 45°, chanfreins et bosses arrondis, aucune ligne d'ombre aux joints. ⚠ PAS VU dans Unity ni
      Unreal (ils doivent importer les normales du fichier, le manuel le dit).
      **LE FEUILLAGE GÉNÉRÉ (Jordan, 19 octobre 2026 : « fais le feuillage d'abord »), `eb81b5d`** : des points semés
      par rôle (`generateur._semer`), les modèles du projet rangés par leur nom (mots anglais ET français — vu à l'image,
      les « cristal » du monde cartoon poussaient dans l'herbe), vérifiés comme le pinceau, dans l'action de l'eau.
      **LA 1.0.0 EXPORTÉE (19 octobre 2026), À VENDRE SUR ITCH.IO — DÉCIDÉ (Jordan : « exporte la 1.0.0 en mode non
      démo mais release, que je vais vendre depuis itch à côté de la démo au prix que tu vas calculer, et à côté des 3
      greffons qui sont gratuits »)** : une ÉDITION ITCH (`Edition.ITCH`, préréglage « Itch », `9a71183`) — sans clé
      ni DRM, comme Steam : itch livre un fichier, pas nos clés nominatives. `builds/1.0.0/itch/` et
      `builds/1.0.0/greffons/` (trois zips, licence MIT). Batterie 30 suites vertes, quatre exe chiffrés qui chargent
      leur DLL. **LE PRIX — PROPOSÉ (Claude) : 39 $** (la stratégie : 39 € tant que l'outil n'a pas fait ses preuves, 60
      seulement sur des avis et des ventes — il n'y en a encore aucun), −20 % la première semaine. ⚠ AVANT LA PREMIÈRE
      VENTE : les blancs du contrat (SIRET, adresse, e-mail, médiateur) puis un réexport — et la déclaration de
      l'activité (micro-entreprise), que le contrat suppose.
      **L'ancien plan (PROPOSÉ par Claude le 18 octobre), dont l'étape 1 est retenue :**
      1. **D'abord un générateur procédural SANS IA.** Une liste de champs (taille, biomes, relief et falaises,
         rivières, mer, étages, densité du feuillage, textures par couche, graine), et des règles écrites par nous qui
         bâtissent le monde avec les vrais outils du cœur, comme le font `batir_station.gd` et `batir_monde_client.gd`.
         C'est l'essentiel de ce qu'on veut, ça tourne sur toutes les machines, et un monde se refait à l'identique
         depuis sa graine.
      2. **Ensuite, en option, un modèle ouvert local** (Qwen ou Mistral sous Apache 2.0, de 2 à 5 Go, via llama.cpp)
         qui transforme une phrase (« une île volcanique avec un lac en altitude ») en valeurs pour ces champs ; le
         générateur fait le reste. « Notre modèle » = ce modèle ré-entraîné (LoRA) sur nos propres mondes d'exemple ;
         en créer un de zéro est hors de portée. ⚠ Un petit modèle embarqué ne saura pas écrire le script entier comme
         le fait Claude : il remplit des champs, il ne construit pas.
      ⚠ Ce que coûte l'étape 2 : plusieurs Go de plus dans l'exe, une carte graphique correcte chez l'acheteur, du
      contenu « généré en direct » à déclarer sur Steam (avec ses garde-fous), et une partie des développeurs
      indépendants qui rejettent l'IA générative. « Generator, no AI » se vend peut-être mieux. **OUVERT, À JORDAN.**
    - **UN JEU EN VUE DE DESSUS AVEC UN MONDE DE MARCHINGBLOCKS — PAR LE PRINCIPE, pas encore vu à l'image**
      (question de Jordan, 18 octobre 2026). Le monde exporté est de la vraie géométrie : une caméra en perspective qui
      regarde droit vers le bas montre les flancs des falaises de plus en plus vers les bords de l'écran (aucun au
      centre), et d'autant plus que le FOV grandit ; ils glissent quand la caméra se déplace (le parallax naturel). En
      orthographique, jamais. Les réglages courants : un petit FOV (20 à 35°) et une caméra lointaine pour un léger
      relief sans déformation, ou une caméra inclinée de 50 à 70° qui montre toujours les flancs sud. Les textures
      « mur » des falaises comptent donc autant que celles du sol.
    - **L'EXE ALLÉGÉ — DÉCIDÉ (Jordan, 18 octobre 2026 : « alléger l'exécutable en supprimant les foliages vraiment trop
      lourds, en passant l'exemple fourni avec le soft en téléchargeable depuis le soft ouvert avec un bouton, et en
      remplaçant les essences d'arbres trop lourdes par des CC0 optimisés », puis « dans SpannerGames, seulement les plus
      lourds, maintenant »).** MESURÉ, l'exe 0.9.3 (334,6 Mo) : l'exemple embarqué 234 Mo, le modèle Godot 68 Mo, les
      images importées 26 Mo, dont 19 Mo qui ne servaient à rien (`MARQUE/reseaux/`, le `.mbset` d'essai à la racine).
      1. **L'EXPORT N'EMBARQUE PLUS L'EXEMPLE** (`exemple/*` exclu des trois préréglages, et les deux dossiers inutiles).
         `exporter_marchingblocks.sh` le met dans `<build>/exemple/` : `MarchingBlocks-<version>-example.zip` et
         `example.json` (nom, taille, SHA-256). Attendu : l'exe vers ~80 Mo (à MESURER au prochain export).
         `res://exemple/exemple.zip` reste dans le dépôt pour le développement (bancs, fumée, mode dev).
      2. **LE BOUTON « Example world » LE TÉLÉCHARGE** (`app/exemple.gd`, `editor._telecharger_l_exemple`) : il lit
         `example.json` sur le site de SpannerGames, à côté de `latest.json` (même domaine, une seule URL à remplir :
         `MisesAJour.URL`), télécharge le zip qu'il nomme par `/api/example` (un lien R2 présigné, sans compte,
         `SITE/functions/api/example.js`), la barre d'attente suit l'avancée, et le fichier n'est gardé que si sa taille
         et son SHA-256 sont les annoncés. Une fois téléchargé, il ne se retélécharge plus. **Tant que le site n'est pas
         en ligne** (URL à A-REMPLIR) : le bouton le dit, et « Open… » accepte un `.zip` d'exemple téléchargé à la main
         (à mettre sur la page itch.io de la démo, à côté de l'exe). Le bouton n'est plus caché quand l'exe n'a pas
         l'exemple. MESURÉ : `test_vente` (161 vérifications), dont la description fausse refusée et un SHA-256
         différent refusé, **vu rougir** (`conforme` sans le SHA). ⚠ Le téléchargement réel n'a pas tourné : le site
         n'est pas en ligne.
      3. **LES TROIS MODÈLES DE FEUILLAGE LES PLUS LOURDS DE L'EXEMPLE SONT DES CC0** (au-delà de 10 Mo chacun ; tous des
         Tripo, donc de l'IA générative à déclarer) : l'arbre du marais `tree+3d+model` (26 Mo, image 4096²) →
         `DeadTree_1` de Quaternius (2 Mo) ; le palmier (24 Mo) → `tree_palmTall` de Kenney (20 Ko) ; l'herbe de savane
         `savanna_grass_01` (12 Mo) → `Grass_Wispy_Tall` de Quaternius (40 Ko). Allégés par
         `SpannerGames/OUTILS/alleger_glb.py` (images ≤ 1024 px, chacune une fois), posés dans le monde client par
         `SpannerGames/OUTILS/remplacer_feuillage.py` (même modèle, mêmes plants : 9 arbres, 5 palmiers, 48 touffes ;
         la hauteur voulue en cases gardée ; sauvegarde dans `ATELIER/MarchingBlocks/sauvegarde/
         monde_client_feuillage_2026-10-18/`), et `batir_monde_client.gd` les nomme. **MESURÉ** : l'exemple passe de
         234 à **174 Mo** (le feuillage de 140 à 79 Mo). Vu à l'image (`batir_monde_client.gd --seulement=photos` sur
         une copie) : les arbres morts vont au marais ; ⚠ **le palmier de Kenney, en low-poly à aplats, jure avec les
         textures réalistes** (OUVERT, à Jordan). Restent au-dessus de 5 Mo : `jungle_plant` (7,7), `ice_crystal_01`
         (6,8), `starfish` (5,5), `desert_cactus_01` et `saltflat_rock_01` (5,0) ; et `plains_tree_01` / `_04` ont
         46 000 triangles chacun (4 Mo).
      4. **UNE OUVERTURE DE PROJET À LA FOIS** (`editor._ouvrir`), trouvé en chemin : une seconde ouverture demandée
         pendant les `await` de la première (l'appli rouvre son dernier projet au lancement, et un script en ouvre un
         autre) vidait le projet puis ajoutait les couches DEUX fois — une copie du monde client est passée de 13 à 22
         puis 43 couches, enregistrées. Corrigé (la seconde attend la première), MESURÉ : la même suite ne donne plus
         d'erreur « previously freed », et la copie garde ses 13 couches.

- **L'écran vit dans `app/`** (`editor.tscn`, `editor.gd`, `vue.gd`) : barre de titre avec bandeau de
  conseils, vue 3D en plein cadre, deux panneaux POSÉS dessus et translucides au repos (gauche = ce
  qu'on regarde et l'aller-retour avec l'artiste, droite = la main), trois ateliers — **Witness**,
  **World** (ex-« Test world », renommé par Jordan le 29 septembre 2026) et **Play test** (§5) —, panneau
  d'attente nommé. Chaînes d'écran en ANGLAIS (§7).
- **RENOMMÉ (Jordan, 27 septembre 2026)** : le dépôt vit dans `D:/MarchingBlocks` (ex-`D:/UnderMend`).
- **LE CŒUR : `addons/marchingblocks_core/` — DÉCIDÉ (Jordan, 28 septembre 2026).** Il s'appelait
  `addons/undermend/`, puis `addons/marching_blocks_plugin_godot/`, et portait AUSSI un écran de greffon
  d'éditeur (`plugin.cfg`, `PluginMarchingBlocks.gd`, `ecran_edition.gd`). **Cet écran est SUPPRIMÉ** :
  l'appli fait tout ce qu'il faisait, et il faisait apparaître un second « MarchingBlocks » dans la liste
  des greffons, à côté du vrai greffon gratuit. Le dossier n'est plus un greffon mais une BIBLIOTHÈQUE —
  le modèle, le témoin, le trancheur, le format — que l'appli charge ; il porte le nom de ce qu'il est.
  ⚠ Ce qu'on distribue gratuitement, c'est `addons/marchingblocks_paint/` (§4) ; le cœur, lui, contient
  le trancheur, c'est-à-dire ce qui se vend, et ne sort que dans l'exe chiffré.
- ⚠ **LE CŒUR N'EST PAS RECOPIÉ** : l'appli appelle `addons/marchingblocks_core/`. Ce qui vivait dans
  l'ancien écran de greffon et devait servir aux deux en était SORTI (`etages.gd`, gardé par `test_etages`).
- ⚠ **LE PINCEAU EST À NOUS** : sans l'éditeur Godot, plus de pinceau natif de GridMap. Un clic est un
  rayon coupé contre le plan de l'étage courant (`vue.gd`), un coup entier s'annule d'un Ctrl+Z.
- ⚠ **LE CHIFFREMENT DEMANDE DES MODÈLES D'EXPORT RECOMPILÉS.** L'onglet « Chiffrement » des presets
  chiffre le PCK, mais les modèles officiels ne savent pas le lire : il faut les compiler avec la même
  clé (`SCRIPT_AES256_ENCRYPTION_KEY`). Sources dans `D:/godot-src` (4.7-stable exact), script
  `construire_modele.sh`, sans D3D12 ni AccessKit. **La clé vit HORS du dépôt**
  (`C:/Users/jorda/.marchingblocks/cle_pck.hex`) et ne doit jamais y entrer.
  ⚠ **CE QUE LE CHIFFREMENT NE FAIT PAS** : la clé est forcément dans l'exe, qui doit se déchiffrer
  lui-même — des outils publics l'en extraient. Il arrête le curieux, pas le déterminé ; le rempart
  commercial reste la licence.
- **DÉCIDÉ (Jordan, 27 septembre 2026) — FORMAT OUVERT, GREFFONS GRATUITS.** Ce qui se vend, c'est
  l'outil qui FABRIQUE les tuiles (le témoin, le trancheur, l'aller-retour), et il vit dans l'exe chiffré.
  Cacher la règle ne protégerait rien : elle est un calcul (70 orbites), et un greffon doit l'EXÉCUTER
  chez l'acheteur — un addon Godot part en source, une DLL Unity se décompile. Des greffons gratuits vont
  là où l'on cherche (Asset Library Godot, Asset Store Unity, Fab) : c'est la DÉCOUVERTE du §10. Le
  format est décrit au §4.
- **L'ÉDITEUR EST SPANNERGAMES — DÉCIDÉ (Jordan, 29 septembre 2026), SANS « Inc. » DEPUIS LE 3 OCTOBRE 2026** (il
  n'y a pas de société : « Inc. » annonçait une société américaine qui n'existe pas). Dans les propriétés de
  l'exe (société, copyright) et tout à droite de la barre de titre, logo DÉTOURÉ
  (`MARQUE/spannergames_detoure.png` : le fond violet opaque de `spannergames.png` ferait un carré).
- **LE SPLASH — DÉCIDÉ (Jordan, 29 septembre 2026) : un fond par logiciel, UNE signature pour tous.**
  - **Le fond de MarchingBlocks** raconte le slogan : le témoin de 12³ flotte dans ses plans de coupe
    dorés, et le monde devient, vers la droite, organique et stylisé. La moitié gauche est RENDUE avec le
    vrai produit (`DEV_TOOLS/rendre_splash.gd` → `MARQUE/splash_fond.png`) ; la droite a été reprise dans
    Tripo par Jordan (`MARQUE/splash_fond_tripo.png`, gardée telle quelle). ⚠ C'est une image de
    présentation : l'interdit de Tripo (§3) porte sur le TÉMOIN qu'on texture, pas sur elle.
  - **La signature** (logo détouré et « SpannerGames », en bas à droite, sur un voile flou) est
    collée par `MARQUE/composer_splash.py`, tailles proportionnelles à la hauteur. ⚠ **CE SCRIPT SE
    COPIE TEL QUEL dans chaque logiciel de Jordan**, avec le logo détouré : le retoucher dans un seul
    projet, c'est une signature qui diverge (§6). On ne colle jamais la signature à la main, et on
    n'envoie jamais à un générateur d'images un fond déjà signé : il la déformerait.
  - ⚠ **« COVER », PAS « KEEP »** (`boot_splash/stretch_mode=4`) : une fenêtre maximisée est plus large
    que 16:9 (la barre des tâches lui prend de la hauteur), et « Keep » laissait des bandes sur les côtés
    — vu par Jordan. « Cover » rogne en haut et en bas, d'où la marge de sûreté de la signature (0,065 de
    la hauteur).
- **OUVERT** : la licence ; l'icône (remplacée en `362ae23`, pas encore validée ici) ; les textures PBR de test (retirées avec le PBR le 29 septembre 2026)
  venaient de HEART_WORLD.

### LA VENTE — fait le 7 octobre 2026 (branche `vente`, à la demande de Jordan : « rends MarchingBlocks vendable »)

Ce qui reste à faire pour vendre, sorti des décisions du 3 et du 7 octobre (§0 et §10 : clé signée nominative, hors ligne,
sans limite de machines ; site + Steam ; démo ; installeur Inno Setup). Le code : `app/edition.gd`, `licence.gd`,
`contrat.gd`, `demo.gd`, `mises_a_jour.gd`, `avis_tiers.gd`, `vente.gd` (ce que l'acheteur voit) ; `gdextension/src/appli/
licence.*` ; `DEV_TOOLS/exporter_marchingblocks.sh`, `preparer_livraison.gd`, `installeur/marchingblocks.iss`,
`licence_signer.py`, `lancer_les_suites.sh`, `test_vente.gd`.

- **LE PRIX : 39,00 €, LE MÊME SUR LE SITE ET SUR STEAM — DÉCIDÉ (Jordan, 7 octobre 2026).** Il n'apparaît nulle part
  dans l'appli ni dans l'installeur (rien à changer le jour où il change) ; s'il y entre un jour, c'est celui-là.
- **TROIS ÉDITIONS, UNE BASE DE CODE — PROPOSÉ (Claude), ÉCRIT ET MESURÉ.** Trois préréglages d'export (`Site`, `Steam`,
  `Demo`) posent chacun leur balise (`edition_site`, `edition_steam`, `edition_demo`), cuite dans le PCK chiffré ;
  `Edition.nom()` la lit. Le site exige la clé et vérifie les mises à jour ; Steam ne demande rien (le compte Steam tient
  lieu de licence, Steam livre les mises à jour) ; la démo ne garde rien. L'éditeur et les suites sont « dev » : rien de
  tout cela. ⚠ **UN EXE EXPORTÉ SANS BALISE EST UN EXE DU SITE** (clé exigée) : un préréglage oublié ou recopié ne livre
  jamais le logiciel complet sans clé ; deux balises ensemble → la plus restreinte (démo, puis site). L'ancien préréglage
  « Windows Desktop » est remplacé par les trois.
- **LA CLÉ DE LICENCE — ÉCRITE ET MESURÉE.** `MBK1.<charge base64url>.<signature base64url>` ; la charge, du JSON
  (`product`, `name`, `email`, `id`, `issued`) ; la signature, Ed25519 (RFC 8032) de « MBK1. » + charge (le préfixe est
  signé : une signature d'un autre format ne sert pas). Vérifiée HORS LIGNE par la clé publique de `app/licence.gd`
  (`CLE_PUBLIQUE`) : aucune activation, aucun serveur, aucune limite de machines. Une clé collée depuis un e-mail (coupée,
  espaces) se lit ; un autre produit, un nom vide, une clé révoquée (`REVOQUEES`, par son `id` : le contrat, art. 11) sont
  refusés, chacun avec sa raison à l'écran.
  - **POURQUOI ED25519 EN C++ (MONOCYPHER) — PROPOSÉ, la raison** : Godot n'a pas Ed25519 (son `Crypto` fait RSA et ECDSA
    par mbedTLS) ; une signature RSA ferait une clé de 400 caractères au lieu de ~200, et l'ECDSA demande un aléa sûr à
    chaque signature (le site le ferait en JavaScript). **Monocypher 4.0.2** (`gdextension/src/appli/monocypher/`,
    BSD-2 ou CC0, audité par Cure53 en 2020, un seul fichier C, recopié tel quel et comparé au tag GitHub) donne l'Ed25519
    de la RFC 8032 — celui de Python `cryptography`, de libsodium, de la Web Crypto des fonctions Cloudflare : le site
    signera avec n'importe lequel. Dans la partie PRIVÉE de la GDExtension (`MBLicence` : `verifier`, `publique_de`,
    `signer`), jamais dans les greffons. ⚠ Sans la DLL, aucune clé n'est bonne — l'export refuse un exe sans elle.
  - ⚠ **CE QUE ÇA NE FAIT PAS** (comme le chiffrement, §0) : un déterminé modifie l'exe. La clé rend l'achat honnête
    simple ; le rempart reste le contrat.
  - **L'OUTIL DE JORDAN** : `python DEV_TOOLS/licence_signer.py signer --nom "…" --email … [--id COMMANDE]` imprime la
    clé et la note dans `C:/Users/jorda/.marchingblocks/licences_emises.csv` ; `verifier "MBK1…"` dit ce qu'elle porte.
    **LA CLÉ PRIVÉE VIT HORS DU DÉPÔT** : `C:/Users/jorda/.marchingblocks/licence_ed25519_privee.hex` (générée le 7 octobre
    2026 par `generer`, qui refuse d'écraser). ⚠ **À SAUVEGARDER HORS DU PC** : perdue, aucune clé neuve ne se vérifie dans
    les exe livrés ; volée, n'importe qui signe — il faudrait une paire neuve et une mise à jour. L'export REFUSE si la clé
    publique de l'appli n'est pas celle de cette clé privée. ⚠ Le jour du site, sa fonction (après le webhook de Paddle)
    signe de la même façon, avec la même clé privée posée en secret chez Cloudflare (OUVERT).
  - **À L'ÉCRAN (version site)** : au premier lancement, après le contrat, « Activate MarchingBlocks » (coller la clé ;
    « Quit » ferme l'appli) ; une clé retenue qui ne se vérifie plus est redemandée ; « About » dit « Licensed to Nom
    (e-mail) » et « Enter another license key ».
- **LA DÉMO : UN EXE À PART, PAS UN DRAPEAU — PROPOSÉ (Claude), puis DÉCIDÉ POUR STEAM (Jordan, 7 octobre 2026 : « une
  démo au lancement, appli Steam Demo à part, gratuite »).** La raison : Steam l'exige de toute façon (une démo est une
  application à part, son AppID, son dépôt) ; le fichier gratuit du site n'est pas l'exe payant ; aucune clé, aucun
  argument ne la change en version complète ; un même exe « sans clé = démo » mêlerait les parcours (un acheteur qui a mal
  collé sa clé se croirait floué de ses enregistrements). Ce qu'elle fait : TOUT, dans un bac jetable
  (`user://demo_scratch`, vidé au lancement et à la fermeture ; ses données dans `%APPDATA%/MarchingBlocks Demo`, à part
  de la version complète — réglage par balise dans `project.godot`) : le projet neuf et l'exemple y vivent, l'enregistrement
  automatique y écrit, donc tous les ateliers marchent. Ce qu'elle refuse, en le disant : ouvrir un projet d'ailleurs,
  « Save as », le témoin pour Blender, le jeu de tuiles, le monde, le patron UV — trois portes (`_demander`,
  `_fichier_choisi`, `_ecrire_le_projet`). Ni associations de fichiers, ni « ton monde » rouvert. La barre de titre dit
  « FREE DEMO — no saving, no export ». ⚠ PAS UN VERROU : le bac est un dossier ordinaire pendant la séance (ce qui y vaut
  pour un moteur, le `.mbset`, ne s'y écrit jamais).
- **LA DÉMO ENREGISTRE — DÉCIDÉ (Jordan, 16 octobre 2026 : « une démo 0.9.2 qui peut tout faire sauf exporter », « il faut
  proposer quelque chose d'utilitaire maintenant »), ÉCRIT LE MÊME JOUR. RENVERSE le bac jetable ci-dessus.** Ses projets vont
  dans `Documents/MarchingBlocks` comme ceux de la version complète, qui les ouvre tels quels ; elle rouvre « ton monde »,
  « Open », « Save as », importe de Blender. Seules les SORTIES sont refusées, en le disant : le témoin pour Blender, le
  `.mbset`, le `.mbworld`, le patron UV (`Demo.REFUSEES`, deux portes : `_demander`, `_fichier_choisi`). Ses réglages restent
  à part (`MarchingBlocks Demo`). ⚠ Le `.glb` lié écrit à côté d'un projet porte les tuiles (sans règle ni manifeste). Gardé
  par `test_vente` 148 (rouge, 8, si le monde et le patron passent). **MESURÉ** : l'export complet (28 suites vertes, sonde
  `edition=demo version=0.9.2`, DLL chargée), le zip `04_exports/demo/MarchingBlocks_Demo_0.9.2_Windows.zip` (132,6 Mo), la
  page itch.io `06_boutique/itch_demo.md` (SpannerGames). ⚠ L'exe de la démo n'a PAS été lancé à la main ; le contrat montré
  au premier lancement a encore ses blancs.
- **LES MISES À JOUR (site) — ÉCRITES ET MESURÉES.** Au lancement, un JSON du site (`{"version", "date", "notes",
  "download"}`, `MisesAJour.URL`) ; plus récente (les NOMBRES comparés : 0.9.10 > 0.9.9), la barre de titre dit « Update
  0.9.1 available », un clic ouvre « My downloads » ; rien ne se télécharge. Case « Check for updates at launch » dans
  Project. ⚠ **JAMAIS BLOQUANTE** : la requête part sans attendre (mesuré < 500 ms pour la lancer), hors ligne on se tait.
  Un lien qui n'est pas en https n'est pas gardé. ⚠ **L'URL ATTEND LE DOMAINE** : `https://A-REMPLIR.example/…` dans
  `app/mises_a_jour.gd` (et `URL_SITE` dans `app/vente.gd`, le lien « Buy / demo » du dialogue de la clé) — tant qu'elle
  porte « A-REMPLIR », rien ne part et l'export le rappelle.
- **LE CONTRAT LIVRÉ — ÉCRIT.** `app/textes/LICENSE.txt` : le modèle OUTIL de `D:/SpannerGames/LEGAL` (français qui fait
  foi, puis anglais), au nom de MarchingBlocks, l'article 8 (données) écrit pour lui (la vérification des mises à jour, la
  clé qui porte nom et e-mail sans rien transmettre). Montré et ACCEPTÉ au premier lancement dans les trois éditions
  (« I accept » / « Quit »), retenu dans `reglages.cfg` avec sa VERSION (`Contrat.VERSION` : à monter quand le fond
  change, chacun le relira) ; livré à côté de l'exe et montré par l'installeur. ⚠ **SES BLANCS [À COMPLÉTER] (SIRET,
  adresse, e-mail du studio, médiateur) ATTENDENT LA MICRO-ENTREPRISE** : l'export le rappelle à chaque fois.
- **LES AVIS DES LICENCES TIERCES — ÉCRITS.** `app/avis_tiers.gd`, UN texte : Godot (MIT) et ses 102 composants tels que
  le moteur les déclare (`Engine.get_copyright_info`, polices comprises — Open Sans, Noto Sans, Inter, JetBrains Mono,
  DroidSans, Vazirmatn —, FreeType, HarfBuzz, mbedTLS…), godot-cpp (MIT), Monocypher (BSD-2). Dans « About » et dans le
  dossier livré (`THIRD_PARTY_NOTICES.txt`). ⚠ Le fichier livré est écrit par l'éditeur Godot : un sur-ensemble de ce
  qu'embarque le modèle recompilé (sans D3D12 ni AccessKit), jamais un oubli. Une bibliothèque C++ ajoutée s'ajoute à
  `PROPRES`.
- **LES GREFFONS GRATUITS PORTENT LEUR MIT** (`LEGAL/LICENCE_GREFFONS_MIT.txt`) : `addons/marchingblocks_paint/LICENSE`,
  `engines/unreal/MarchingBlocksPaint/LICENSE`, `engines/unity/com.marchingblocks.paint/LICENSE.md` (+ `.meta`, et
  `"license": "MIT"` dans `package.json`).
- **L'INSTALLEUR INNO SETUP (site) — ÉCRIT ET MESURÉ.** `DEV_TOOLS/installeur/marchingblocks.iss`, compilé par l'export.
  **PROPOSÉ : UNE INSTALLATION PAR UTILISATEUR** (`PrivilegesRequired=lowest`) — aucune demande d'administrateur, le
  programme dans `%LOCALAPPDATA%\Programs\MarchingBlocks`, ses clés dans HKEY_CURRENT_USER : LES MÊMES que celles que
  l'appli pose elle-même sans installeur (la section `[Registry]` est ÉCRITE d'après `Associations.TYPES` par
  `preparer_livraison.gd` : une règle, un endroit), donc la case « File icons » de Project les retire et les remet de la
  même façon. Raccourci du menu Démarrer (et du Bureau, case à cocher), le contrat à accepter, `.mbproj` / `.mbtiles` et
  leurs icônes (`{app}\icones`), le double-clic ; la désinstallation retire l'exe, la DLL, les raccourcis, les clés
  (« uninsdeletekey » sur les types, la valeur et la clé vide sur les extensions) et les icônes ; elle LAISSE les
  réglages, la clé de licence et les projets. Installée, l'appli ne s'inscrit pas par-dessus (`unins000.exe` à côté de
  l'exe), et ses dossiers exportés prennent les icônes de `{app}\icones`. L'`AppId` ne change jamais (une version
  remplace l'autre). ⚠ **NON SIGNÉ** : SmartScreen avertira (OUVERT).
- **STEAM : LE DOSSIER TEL QUEL** (exe + DLL + LICENSE.txt + avis), et la démo de même ; `steampipe/app_build_steam.vdf`
  et `app_build_demo.vdf` écrits par l'export, AppID et dépôts À REMPLIR (`steamcmd +run_app_build`). Sans installeur,
  l'exe Steam s'inscrit lui-même (comme avant).
- **LA COMMANDE UNIQUE** : `bash DEV_TOOLS/exporter_marchingblocks.sh [sortie]` (défaut `D:/SpannerGames/ATELIER/MarchingBlocks/builds/<version>`, hors du dépôt). Elle REFUSE : clé du PCK
  absente ; clé publique de l'appli ≠ clé privée de licence ; exemple non pris ; DLL release absente ; UNE suite rouge
  (`lancer_les_suites.sh`, les 26) ; un exe lisible en clair (les 7 chaînes, dans chacun des trois) ; une DLL absente ou
  différente de celle du dépôt ; un exe qui ne charge pas sa DLL — la SONDE (`MarchingBlocks.exe --headless --
  --mb-sonde` : « MB-SONDE natif=1 licence=1 edition=… version=… », rien d'autre) et les modules du processus
  (`Get-Process … .Modules`). Puis l'installeur, puis SteamPipe. Elle DIT sans refuser : les blancs du contrat, l'URL à
  remplir.
- **LA BATTERIE** : `bash DEV_TOOLS/lancer_les_suites.sh` — une par une (elles réécrivent `reglages.cfg`) ; verte = code 0
  ET « N vérifications, 0 échec(s) » (N > 0) ET pas de « VERDICT : ÉCHEC » (`test_fluides` et `test_formes_speciales`
  n'écrivent pas de VERDICT : le premier jet du runner les donnait rouges à tort).
- **MESURÉ (7 octobre 2026, Windows 10, Godot 4.7, DLL reconstruites par MSVC 2022)** :
  - `test_vente` **153** (la 26e suite) : l'Ed25519 natif contre les 3 vecteurs de la RFC 8032 et 24 signatures d'OpenSSL
    (Python `cryptography`) — mêmes publiques, mêmes signatures octet pour octet, un bit changé refusé (message, R, S, clé),
    S + L (malléable) refusée, tailles fausses refusées ; les clés signées par Python (noms accentués, japonais, guillemets)
    lues ; les éditions (7 cas de balises) ; les mises à jour (12 comparaisons, réponses, hors ligne : < 500 ms pour lancer,
    rien dit) ; le contrat ; les avis ; la démo (règles et bac) ; et L'APPLI MENÉE dans les trois éditions (site : contrat
    → clé → projet, la clé retenue au lancement suivant, une clé qui ne se vérifie plus redemandée, About ; démo : six
    refus dits, deux choix de fichier forcés et un `Save as` forcé sans rien écrire, un projet hors du bac jamais écrit,
    le geste écrit dans le bac, « ton monde » intact au MD5, la fermeture qui vide le bac ; Steam : contrat, pas de clé).
  - **LA BATTERIE : 26 SUITES VERTES** sur la branche (`lancer_les_suites.sh`), dont `fumee_appli` 937, `test_natif` 158,
    `test_projet` 134, `test_vente` 153 — lancées par la commande d'export elle-même.
  - **TRENTE MUTATIONS, TOUTES ROUGES** — GDScript (26) : le préfixe non signé, le produit, la révocation, les espaces,
    le nom vide, la signature ignorée ; l'exe sans balise rendu « dev », Steam avant la démo ; la comparaison des versions
    en texte, le lien http gardé, l'URL à remplir ignorée, la case ignorée ; la version du contrat ignorée ; le site sans
    clé, le contrat jamais montré, une mauvaise clé acceptée, l'écran qui n'attend pas la vente ; les trois portes de la
    démo, le projet neuf hors du bac, « ton monde » rouvert, le bac non vidé à la fermeture, le bac qui bute sur un fichier
    en lecture seule ; l'installeur ignoré par les associations ; Monocypher oublié des avis. C++ (4, DLL reconstruite) :
    `verifier` qui dit toujours oui, S ≥ L accepté dans Monocypher, la signature d'un octet de moins, les tailles non
    gardées. ⚠ **QUATRE D'ABORD FAUSSES, PAR LE TEST** : trois mutations de la démo rougissaient pour la MAUVAISE raison
    (un essai d'avant avait écrit dans le dossier jetable — il repart vide désormais) ; « le bac en lecture seule » et
    « les tailles non gardées » étaient MUETTES (aucun fichier en lecture seule ; des tableaux vides au lieu d'une signature
    de 65 octets) — le test les fait rougir.
  - **L'EXPORT, LANCÉ POUR DE VRAI** (sortie `D:/MB_wt_vente_sorties`, pas le défaut) : la batterie verte, les trois exe
    (~175 Mo : l'exemple pèse aujourd'hui 81 Mo), chiffrés (0 chaîne sur 7 dans chacun), la DLL à côté, identique à celle
    du dépôt ; la sonde dit « natif=1 licence=1 edition=site|steam|demo version=0.9.0 » et la DLL est dans les modules de
    chaque processus — **ROUGE VU** : la DLL retirée du dossier, la sonde dit « natif=0 licence=0 » et « MODULE_ABSENT ».
    L'exe du site reconnaît une clé signée à l'instant par la clé privée de Jordan (« ok nom=Export check ») et refuse la
    même, un caractère de sa signature changé. ⚠ **DEUX DÉFAUTS DE LA COMMANDE, TROUVÉS EN LA LANÇANT** : `Process.Modules`
    se met en cache à sa première lecture (« MODULE_ABSENT » sur une DLL chargée : `Refresh()` à chaque tour) ; Git Bash
    réécrivait `/DVersion=…` d'Inno en chemin (`MSYS2_ARG_CONV_EXCL`).
  - **L'INSTALLEUR, INSTALLÉ ET DÉSINSTALLÉ SUR LE PC** (silencieux, 125 Mo) : les fichiers dans
    `%LOCALAPPDATA%\Programs\MarchingBlocks` (exe, DLL, LICENSE, avis, `icones/`), les quatre clés et leurs valeurs
    (`.mbproj` → `MarchingBlocks.Project`, l'icône, `"…\MarchingBlocks.exe" "%1"`), le menu Démarrer, le Bureau, l'entrée
    « Programmes » (MarchingBlocks 0.9.0, SpannerGames) ; l'exe installé charge sa DLL. Désinstallé : plus rien — ni
    dossier, ni clé, ni raccourci, ni entrée. ⚠ **UN EXE ENCORE OUVERT RESTE** jusqu'au redémarrage (vu une fois, l'exe
    venait d'être lancé) : interactif, l'installeur propose de fermer l'appli (`CloseApplications`). ⚠ **UN DÉFAUT RÉEL,
    PAYÉ SUR LE PC DE JORDAN** : la désinstallation emportait aussi les icônes des données de l'appli
    (`app_userdata/MarchingBlocks/icones`), que désignait encore son exe de développement — retiré de l'installeur ; les
    icônes réécrites par `Associations.ecrire_les_icones`, et ses clés `.mbproj` / `.mbtiles` (sauvées avant l'essai)
    remises telles quelles.
  - **VU À L'IMAGE** (exe du site lancé, captures d'écran) : le contrat (« MarchingBlocks — License agreement », « I accept »
    / « Quit ») par-dessus l'appli, aucun projet ouvert derrière ; puis « Activate MarchingBlocks ». Corrigé après : le
    champ de la clé prend le focus (on collait dans le vide), le contrat en paragraphes (les lignes coupées du Markdown
    se lisaient mal dans la boîte). **La démo**, lancée de même : ses données dans `%APPDATA%\MarchingBlocks Demo` (la
    balise de `project.godot` tient dans l'exe), le projet neuf dans le bac, « FREE DEMO — no saving, no export » dans la
    barre et le rapport qui le dit ; fermée par la fenêtre, le bac est VIDE, rien dans Documents, les clés de fichiers de
    Jordan intactes.
- **CE QUE JORDAN DOIT FAIRE** :
  - **SAUVEGARDER `C:/Users/jorda/.marchingblocks/licence_ed25519_privee.hex`** hors du PC (avec `cle_pck.hex`).
  - Signer une clé : `python DEV_TOOLS/licence_signer.py signer --nom "Prénom Nom" --email adresse@… --id COMMANDE` (il
    faut `pip install cryptography`) ; l'envoyer telle quelle à l'acheteur. En attendant le site, c'est à la main.
  - Avant la vente : remplir les blancs du contrat (SIRET, adresse, e-mail, médiateur — `D:/SpannerGames/LEGAL`, puis
    recopier dans `app/textes/LICENSE.txt` ; monter `Contrat.VERSION` si le fond change) ; le domaine dans
    `MisesAJour.URL` et `Vente.URL_SITE` ; les AppID et dépôts (logiciel ET démo) dans les `.vdf`.
  - Lancer l'export : `bash DEV_TOOLS/exporter_marchingblocks.sh` (≈ 15 min : la batterie d'abord).
  - Tenir en main : le contrat, la clé, About, la démo, l'installeur interactif (rien de cela n'a été cliqué à la
    souris ; l'installeur n'a tourné qu'en silencieux).
- **OUVERT** :
  - **LE SITE QUI SIGNE** : la fonction (webhook Paddle → clé → e-mail) n'existe pas ; elle signera au même format, la clé
    privée en secret chez Cloudflare.
  - **LA SIGNATURE DE CODE** : l'exe et l'installeur ne sont pas signés — SmartScreen avertira (« éditeur inconnu ») ; un
    certificat coûte (≈ 100 à 300 € par an, ou Azure Trusted Signing ≈ 10 $ / mois s'il accepte un entrepreneur français).
  - **STEAM SANS DRM** : le dossier Steam copié marche ailleurs sans clé (le choix courant des outils ; l'enveloppe DRM
    de Steamworks est possible, à trancher par Jordan).
  - **LE ZIP DE LA DÉMO DU SITE** : le dossier `demo/` est prêt ; l'archive à poser sur le site n'est pas faite.
  - **LES `.so` LINUX** n'ont pas `MBLicence` (WSL hors service sur le PC) : sous Linux, `test_vente` rougit tant qu'ils ne
    sont pas reconstruits (`scons platform=linux target=template_debug|template_release`).
  - **LE CONTRAT DEUX FOIS** pour qui installe (l'installeur le montre, l'appli le fait accepter) : voulu prudent ; à
    alléger si Jordan le trouve lourd (l'installeur pourrait marquer l'acceptation).
  - Un PC qui a la version Steam ET la version du site : la désinstallation du site retire les clés de fichiers que la
    version Steam avait posées (les mêmes) ; la case de Project les remet.
### LE CONTRAT DE LA PARITÉ — FAIT LE 7 OCTOBRE 2026 (première étape de « parité complète des greffons à la 0.9.0 »)

La spécification lisible par l'agent de chaque moteur est **`engines/PARITE.md`** (entrée par entrée : ce qu'il faut
lire, la règle, les cas, le rendu, ce qui ne peut pas être fait). Ici, ce qui a été fait et mesuré.

- **CE QUE LE LOGICIEL EXPORTE DÉSORMAIS — ÉCRIT** (`format_monde.gd`, `format_neutre.gd`, `animation_materiau.gd`) :
  - `world.json` gagne **`transitions`** (paires en INDICES de `layers` — les ids de l'écran convertis, une paire dont
    l'ordre s'inverse échange ses directions —, réglages par direction sous les noms de l'écran en anglais `softness`,
    `reach`, `irregularity`, `grain`, `fills_hollows`, un représentant RÉSOLU par couche et son image dans
    `transitions/`, les choix peints) et **`foliage`** (les modèles COPIÉS dans `foliage/`, comme les jeux de tuiles ; un
    modèle introuvable part sans maillage et l'export le dit ; les plants à plat par sept). **FACULTATIVES comme `water`**
    (PROPOSÉ, Claude) : la version reste 1, un monde d'avant les lit absentes, une clé inconnue est ignorée.
  - le `.mbset` **emporte les images des textures animées** (`animation/`, deux images de même nom venues de deux
    dossiers ne s'écrasent pas : « _2 ») et `mb_animation` part **au format qui part** — anglais, `format`
    « marchingblocks-animation », `version` 1 (`Anim.vers_format` / `depuis_format`, la traduction à un endroit). Le
    témoin garde les noms du cœur (son aller-retour avec Blender ne change pas). Une image introuvable est dite.
  - les lectures de référence `FormatMonde.lire_transitions`, `lire_feuillage` (celle du projet, `FE.depuis_donnees`,
    sous les noms anglais) ; « un seul océan » ajouté à `regle_eau()` (la seule phrase qui manquait à l'eau). Les quatre
    règles sont dans les `README.txt` exportés.
  - **SORTI DE L'ÉCRAN VERS LE CŒUR**, pour qu'une règle des greffons ne vive pas dans `app/` : `Outils.elargir_a_plat`
    (Alt + molette), `Outils.selectionner_au_pinceau` (Select des cases vides), `FE.vent_du_plant`, `FE.balancement`,
    `FE.SENS_DU_VENT`, `FE.case_d_eau`, `FE.semer_candidats` (le pinceau sans hasard, même corps `_semer_un` que `semer`,
    même ordre des tirages), `Anim.defilement_au_temps` (le défilement n'était écrit que dans le shader). L'écran les
    appelle ; comportement identique (fumée 937 avant et après).
- **LES CAS — 282, EN CINQ FICHIERS NEUFS** (`epreuve_parite.gd`, écrits par `generer_cas_d_epreuve.gd` dans les trois
  greffons, un `.meta` à GUID fixe pour Unity) : `transitions_conformance.json` 93 (65 `blend` dont 48 générés par un
  congruentiel ÉCRIT — les greffons lisent les entrées —, `settings`, `table`, `cell_texture`, 19 `read`),
  `animation_conformance.json` 43, `foliage_conformance.json` 59 (les trois modes, les huit refus, le pinceau sur des
  candidats donnés, la pose, le vent), `water_conformance.json` 25 (`Fluides.monde` : mer, lac calme, lac qui déborde,
  rivière, grotte close, un seul océan, refus ; `sources_en_largeur` ; surface et profondeur), `editing_conformance.json`
  62 (`Etages.extruder` 3 × 3, `retrecir_bord`, `elargir_a_plat`, le pinceau Select, `FS.salle_depuis`). **Les trois
  fichiers existants n'ont pas bougé d'un octet** (les bancs refusent une sorte inconnue : d'où des fichiers à part).
- **LA GARDE : `test_parite` (186)** — les cinq fichiers à jour dans les trois greffons ; chaque raison, mode, fin, refus
  exercé ; une **SECONDE IMPLÉMENTATION écrite dans le test depuis le seul `rules_text`** (le fondu, l'image, la
  pulsation, la phase, le défilement, la pose, le vent, Shrink, Widen, Select, la table) rend tous les cas ; des attendus
  déroulés à la main ; l'export de bout en bout (indices, directions échangées, image du représentant octet pour octet,
  modèle copié, les six images animées dans l'ordre, un monde sans les clés qui se lit vide).
- **MESURÉ** : les 26 suites vertes (dont `fumee_appli` 937, `test_greffon_peinture` 282, `test_animation` 76 — son
  contrôle du `.mbset` suit le nouveau format et vérifie la copie des images) ; banc .NET et banc C++ (clang de Unity,
  drapeaux d'Unreal) verts, inchangés (18 + 6 + 6 cas de pose, 128 d'outils, 14 de monde). Unity 6.6 et Unreal non
  relancés (rien de ce qu'ils lisent n'a changé). ⚠ **`phase_de` en flottants 32 bits** (un shader) **s'écarte jusqu'à
  0,025** de l'attendu double sur les origines des cas — l'appli elle-même est dans ce cas ; les cas `phase` sont en
  double (un greffon qui la calcule sur le CPU les passe).
- **MUTATIONS — 24, 23 ROUGES, 1 ÉQUIVALENTE** : le fondu (décalage sans 1 − s, départage au dernier coin — rendues par
  la seconde implémentation, cas RÉGÉNÉRÉS), l'aller-retour non replié (sans régénérer : fichier périmé ; régénéré : le
  texte), la phase, le défilement sans 7 × phase, la phase du vent, le balancement ∝ h, la pose sans l'échelle, l'eau du
  feuillage jamais vue, Widen en hauteur, Shrink sans « s'arrête de l'autre », Select qui prend les vides, l'eau sans
  débordement ; l'export (directions non échangées, modèle non copié, image du représentant non écrite, choix d'une
  couche disparue gardés, images animées non recopiées, deux images de même nom écrasées) ; deux lectures (paire a = b,
  animation plus récente — sans régénérer) ; le générateur sans eau dans le monde du feuillage. ⚠ **« L'IMAGE DU
  REPRÉSENTANT NON ÉCRITE » D'ABORD MUETTE, PAR LE TEST** : il relisait l'image d'une exécution précédente — il vide son
  dossier d'abord. ⚠ **UNE ÉQUIVALENTE** : faire voter le choix d'une troisième couche pour elle-même — le vote ne compte
  que les coins où l'AUTRE couvre, donc une troisième couche et « pas de choix » ne votent ni l'une ni l'autre.
  ⚠ Les lectures (`read`) ne sont gardées que par la péremption et les bancs des moteurs : une lecture mutée PUIS
  régénérée passerait `test_parite`.
- **CE QUI RESTE PARTIEL OU IMPOSSIBLE TEL QUEL, ET POURQUOI** (le détail : `engines/PARITE.md` §9) : le MAILLAGE de
  l'eau (`eau_maillage.gd`) n'a pas de cas — conseillé : la nappe cuite à la 0.9.0, les cases d'eau recalculées ; la
  molette n'a de cas que pour ses effets (l'aiguillage est une règle d'interface ; les panneaux de Unity et d'Unreal ne
  sont pas à nous) ; les shaders ne voyagent pas et ne sont gardés par aucun cas ; **Unity n'a pas de passage
  par-dessus un matériau** (un matériau de plus ne redessine que le dernier sous-maillage) et a trois pipelines ;
  **les matériaux d'Unreal sont des assets binaires** (Overlay Material sur des instances, « Object Position » d'une
  instance : NON MESURÉS) ; lire les extras glTF n'est mesuré que dans Godot (lire le JSON de `tiles.glb` soi-même lève
  le doute) ; le GDScript des transitions emploie un bruit pour les deux directions, le shader un par direction
  (OUVERT). **L'API DE JEU** n'est pas dans ce contrat.
- **LE DÉCOUPAGE CONSEILLÉ** (PROPOSÉ) : un agent par moteur, en parallèle ; les cas sont le commun, pas du code. Dans
  chaque moteur : lecteurs → `editing` (+ boutons, Maj / Alt, molette) → `animation` → `foliage` → `transitions` →
  `water` (règle des cases, puis les six presets sur la nappe cuite). Le plus risqué, à mesurer TÔT sur le seul fondu des
  transitions : le rendu Unity et les matériaux Unreal ; puis la règle de l'eau (longue, sensible à l'ordre — Unreal peut
  partir de `gdextension/src/noyau/ocean.h`). Godot est le plus court (copies générées des shaders de l'appli). Une règle
  ambiguë se remonte et se corrige dans le GDScript, jamais dans un moteur.
- ⚠ **PAS TENU EN MAIN** : l'export du monde par le bouton (le panneau d'attente pend en headless, comme avant) — mené
  par `test_parite` sur `FormatMonde.exporter` directement, avec ce que l'écran lui passe (`_exporter_le_monde`, relu).

### LE CONTRAT DE L'EAU RECALCULÉE — FAIT LE 7 OCTOBRE 2026 (branche `contrat-eau` ; la parité des greffons, le seul écart)

Les trois greffons montraient la nappe CUITE sans la refaire en peignant : le mailleur (`eau_maillage.gd`) n'avait pas de
cas. La spécification pour les trois agents moteurs : **`engines/PARITE.md` §12**. Ici, ce qui est fait et mesuré.

- **LES CAS — 14, DANS UN SIXIÈME FICHIER** (`water_mesh_conformance.json`, `epreuve_parite.gd` `_maillage_eau`, écrit dans les
  trois greffons, `.meta` à GUID fixe) : à partir de corps d'eau DONNÉS au format des `water_world` (le mailleur se juge
  sans la règle), la nappe en **SAC DE TRIANGLES canonique** — sens du format (glTF), coins `[position, normale, COLOR_0,
  UV]`, arrondis au millionième, rangés en sommets + indices (570 Ko). Comparaison sans ordre, rotations permises, réflexion
  refusée, tolérances (position, uv 1e−4 ; normale 1e−3 ; couleur 1e−4). Couvre mer, lac, rivière, cascade en volume
  (nappe courbe, rentrée dans la roche, remous, source), plats sans jonction en T, nappe sous un étage flottant et sous un
  plafond, un seul océan, largeur de rivière, mer au-dessus de tout, monde vide, refus. Les cinq fichiers d'avant n'ont
  pas bougé d'un octet.
- **POURQUOI CETTE FORME (PROPOSÉ, Claude)** : l'ordre des triangles n'est pas la règle (mémoires, natif) ; des invariants
  seuls ne suffisent pas — **MESURÉ : 6 mutations réelles sur 16 laissent nombre et aire par genre identiques** (écume
  linéaire, lèvre la plus basse, anneau sans ses 0,02, sens par le 2e coin, bande à profondeur 0, deux bandes par case).
- ⚠ **LES CAS DÉCRIVENT LES TABLEAUX, PAS L'ArrayMesh — UN PIÈGE PAYÉ AU PREMIER ESSAI** : relus de l'`ArrayMesh`, les
  couleurs étaient sur 8 bits (0,5 → 0,498039) et les normales en octaèdre ((0, 1, 0) → z = −1,5e−5). `maillage` est coupé
  en deux : `tableaux_du_maillage` (ce que les cas décrivent) puis l'ArrayMesh — même sortie pour l'appli.
- **LA GARDE : `test_parite` (279)** — le sixième fichier à jour dans les trois greffons ; l'appariement en sac éprouvé
  (vrai mélangé / tourné / bruité, faux sur un coin à 2e−4, un triangle retourné, un doublé, des couleurs sur 8 bits) ;
  **la mer relue de son eau (ce qu'a un greffon) = relue de ses tronçons (l'appli)** ; et, sur les triangles mêmes, ce que
  chaque cas nomme (aucune jonction en T, hauteurs, la nappe sous la dalle à 2,7, la cascade du bassin de 2,6 à > 3,35 et de
  z 0,9 à 2,1, écume 0 → 1, anneau à 1,72, le bouillon de la source, la rivière large raccordée, un seul océan, la même
  rivière avec ou sans la mer). Vert avec le cœur natif ET sans (`MB_NATIF=0`).
- **MESURÉ — LES SEUILS SONT LOIN** : les 112 triangles jetés ont une aire exactement nulle, le plus petit gardé 1,0e−3 (le
  seuil : 1e−7) ; la marge de sens la plus faible 0,345. Un moteur en double ne tranche autrement nulle part.
- **MUTATIONS — 17, 16 ROUGES, 1 ÉQUIVALENTE** : toutes rougissent sans régénérer (le fichier livré les voit) ; régénérées, 11
  rougissent encore par une garde nommée ; l'équivalente, attendue : garder les sommets orphelins (le contrat est en
  triangles). ⚠ La « jonction en T » d'abord ABSENTE de la campagne (motif mal indenté, dit par le script) : relancée seule,
  rouge.
- **LE BUDGET, MESURÉ** (`DEV_TOOLS/banc_eau_recalcul.gd`, l'exemple : 739 481 cases, 106 sources, mer de 354 159 cases ;
  machine partagée, ×2 d'une passe à l'autre) : en GDScript seul (le greffon Godot), **tout refaire 5,1 à 6,7 s** (la mer
  seule : 1,8 s de nappe pour 72 triangles) ; **un geste avec la reprise de l'appli 0,7 à 1,2 s**. Avec le cœur natif, un
  geste 0,09 à 0,32 s. C# et C++ : non mesurés.
- **RECOMMANDÉ (PROPOSÉ, à valider par Jordan)** : jamais pendant un geste (la nappe se dit périmée) ; un recalcul DIFFÉRÉ
  à la fin du geste (~0,5 s de calme, sur un fil à part) ; la REPRISE de l'appli portée (incrémental == entier vérifié
  par chaque banc) ; un bouton « Rebuild water » toujours là, le suivi automatique coupé au-delà d'~1 s ; contrôle de bout
  en bout contre la nappe cuite d'un monde exporté.
- **LE DÉCOUPAGE CONSEILLÉ** : un agent par moteur ; le banc et l'appariement d'abord, puis le mailleur du lac du cratère au
  bassin, puis le branchement, puis l'image (nappe recalculée et nappe cuite indiscernables sous les six presets).
  `test_greffon_peinture` porte le fichier en `PARITE_A_VENIR` (livré, compté, PAS ENCORE REJOUÉ) : l'agent Godot le passe
  dans `PARITE` quand `mb_water.gd` maille.
- ⚠ **NON EXERCÉ** : la cascade « droite » (sans sens connu) — la règle ne semble pas la produire (lu, pas prouvé).
- **LE 15e CAS, « DEUX RIVIÈRES AU MÊME ENDROIT » — MESURÉ LE 7 OCTOBRE 2026 (branche `cas-eau`)** : les trois greffons avaient
  trouvé deux mutations du mailleur muettes sur les 14 cas (« lèvre la plus BASSE gardée », « deux bandes sur une même
  case ») — « 16 sur 16 rouges sans régénérer » était faux pour elles. Ajouté dans `epreuve_parite.gd` : le monde « a cliff
  pierced by a gallery » (la garde maison du greffon Godot) et son cas (deux cascades sur la même face, lèvres en y = 6 et
  2 ; deux cases de bande communes ; 1 279 triangles). Seul `water_mesh_conformance.json` change (les 14 premiers cas
  identiques). `test_parite` 287/0 (natif et `MB_NATIF=0`), avec des gardes nommées (deux lèvres au même endroit, cases
  communes, la nappe à 5,85, une bande par case). **Les deux mutations ROUGISSENT** : dans le cœur (`MB_NATIF=0` : les trois
  fichiers livrés périmés + la garde nommée), et dans chaque greffon par le 15e cas (Godot, Unity C#, Unreal C++ : 1 093 ou
  1 295 triangles au lieu de 1 279). **Les trois greffons passent 15/15 sans correction** : `test_greffon_peinture` (299 cas
  communs), banc .NET et Unity 6.6 en batch (65/65), `core-runner` Unreal sous MSVC 2022 (`cl /std:c++17 /EHs-c- /GR- /W4
  /WX /D_HAS_EXCEPTIONS=0` — sans ce dernier drapeau, que pose Unreal, la STL avertit C4530 et `/WX` refuse). Batterie `lancer_les_suites.sh` : 28 suites vertes (⚠ dans un
  worktree neuf, `test_projet` rougit tant que `godot --headless --import` n'a pas rempli `.godot/imported`).
- ⚠ **VU EN PASSANT** : l'exemple livré a 739 481 cases et une mer de 354 159 cases (`sonde_eau_exemple.gd` disait 2,4 millions le 4 octobre :
  OUVERT — l'exemple a changé, ou la mer était comptée autrement ; non vérifié).

### L'EAU RECALCULÉE DANS LE GREFFON GODOT — FAIT LE 7 OCTOBRE 2026 (branche `eau-godot`, sur le contrat ci-dessus)

La dernière entrée de la parité pour Godot. Le greffon ne charge toujours RIEN du cœur : le mailleur est réécrit en
anglais depuis `eau_maillage.gd` (`addons/marchingblocks_paint/mb_water_mesh.gd`), la reprise de `fluides.gd` portée
dans `mb_water.gd`, le branchement dans `mb_water_node.gd`.

- **LES 14 CAS — MESURÉ : 14 SUR 14** (`test_greffon_peinture` : `water_mesh` passe de `PARITE_A_VENIR` à `PARITE`, 298 cas
  communs en tout) ; l'appariement en sac écrit DEPUIS `rules_text` (`DEV_TOOLS/eau_sac.gd`, pas copié de `test_parite`) et
  éprouvé avant d'être cru (vrai mélangé / tourné / bruité ; faux sur un coin à 2e−4, un triangle retourné, un doublé, des
  couleurs sur 8 bits). Passés d'un coup : le portage est ligne à ligne (32 bits là où le cœur range en 32 bits —
  `_chutes` en `PackedFloat32Array`, les points en `Vector3`).
- **LA REPRISE, PORTÉE** : `Water.world(cells, sources, max, before, changed, box)` (emprise, `_box_compatible`, la mer
  reprise d'abord) ; « une couche dont tous les corps sont repris garde sa nappe » ; la mémoire des nappes par corps, des
  cascades et des sources. **Incrémental = entier, MESURÉ** : 68 gestes (64 au hasard, graine fixe, 4 imposés) sur sept
  mondes — mêmes corps, même sac par couche, même boîte, même empreinte.
- **LE BRANCHEMENT (DÉCIDÉ par la coordination)** : la première couche d'eau mène pour toutes ; pendant un geste (bouton
  de souris tenu) rien ne part et la nappe se dit périmée (avertissement de l'inspecteur) ; après 0,5 s de calme, calcul
  sur `WorkerThreadPool` à partir d'une COPIE (`get_used_cells` de chaque couche, copie native), nappes échangées sur le
  fil principal ; bouton « Rebuild water » (`@export_tool_button`) toujours là ; `auto_limit` (1 s) : une reprise plus
  lente COUPE le suivi jusqu'au bouton (un bouton rapide le rétablit). `follow_cells` (les cubes bleus) est retiré.
- **CE QU'UN GESTE COÛTE, C'EST CE QU'IL CHANGE** (MESURÉ au premier essai : 1,6 à 2 s par geste, dont ~1 s de différence
  de cases et ~1 s d'empreinte triée sur 739 481 cases) : une couche dont `get_used_cells` est le même tableau est sautée ;
  sinon on ne compare que le MILIEU des deux tableaux (une GridMap liste ses cases dans l'ordre d'insertion) ; la boîte et
  l'empreinte (désormais une SOMME de hachages, sans ordre) suivent les cases changées. ⚠ L'empreinte a changé de
  formule : un monde importé avant se dit périmé une fois (un calcul entier, sur le fil).
- **LES TEMPS, MESURÉS sur l'exemple** (`DEV_TOOLS/banc_eau_greffon.gd` ; 739 481 cases, 3 couches de tuiles, 106 sources,
  mer de 354 159 cases ; machine partagée, ×2 d'une passe à l'autre) : **tout refaire 3,0 à 8,9 s** ; **un geste avec la
  reprise 0,04 à 0,35 s** (près d'une rivière 0,17 s, loin de l'eau 0,08 s, 84 à 99 sources reprises) ; un geste qui
  touche la mer ou le bord de la boîte (une case au fond) refait la mer : 2,1 à 4,2 s — le suivi s'y coupe, comme décidé.
  Chaque geste mesuré = le calcul entier.
- **LE BOUT EN BOUT** : dans `test_greffon_peinture`, l'appli exporte l'île (mer et rivière, deux couches) avec ses nappes
  cuites, le greffon l'importe et refait : chaque nappe = le `.glb` relu (couleurs à 1/255) ; puis le branchement mené
  pas à pas (geste, délai, souris tenue, fil, échange, coupure, bouton). Sur l'EXEMPLE (le banc) : les trois nappes
  refaites = celles du cœur (au millionième) ET les `.glb` cuits par `FormatMonde.exporter` (66 151, 5 073, 72 triangles).
- **VU À L'IMAGE** (`DEV_TOOLS/capture_eau_greffon.gd`, avec fenêtre : deux SubViewport, même caméra, même instant ; cuite
  à gauche, refaite à droite) : le bassin (écart maximal 1/255), l'île (moins de 0,05 % des valeurs à plus de 8/255), une
  cascade de l'exemple (moins de 0,4 %), sous les SIX presets — indiscernables à l'œil ; l'écart restant est celui du
  `.glb` (couleurs sur 8 bits) et de l'ordre des triangles transparents.
- **MUTATIONS — 23, 23 ROUGES** (mailleur 13, reprise 3, nœud 7). ⚠ **CINQ ÉTAIENT D'ABORD MUETTES** : « une couche gardée
  si UN corps est repris », « l'emprise oublie la coulée à plat », « une case retirée au bord ne rebalaye pas la boîte »
  — rouges depuis des gestes imposés (une couche à deux corps, un détour hors de la boîte, une case posée haut puis ôtée)
  et la boîte comparée à chaque geste ; et **deux que LES 14 CAS COMMUNS NE VOIENT PAS** : « deux cascades jointes gardent
  la lèvre la plus BASSE » et « deux bandes sur une même case » — mesuré aussi dans le CŒUR (`MB_NATIF=0`, la même
  mutation dans `eau_maillage.gd` : `test_parite` 279/0, le fichier livré inchangé). Aucun cas n'a deux rivières au même
  endroit : **ce que disait le contrat (« 16 sur 16 rouges sans régénérer ») est faux pour ces deux-là.** Gardé dans
  `test_greffon_peinture` contre le cœur (une falaise percée d'une galerie, deux rivières sur la même face) ;
  ~~OUVERT : un cas commun à ajouter~~ **✓ FAIT : le 15e cas commun** (branche `cas-eau`, « Le contrat de l'eau recalculée »).
- ⚠ **PAS TENU EN MAIN** : dans l'éditeur de Godot lui-même (vraie souris, inspecteur, bouton cliqué) — le branchement est
  mené par `tick(now, stroke)` ; et la détection d'un changement lit l'empreinte que chaque couche prend à sa
  reconstruction (`live_update`, `apply_cells`) : une couche sans `live_update` ne fait pas suivre l'eau (ni ses tuiles).
  ⚠ Le greffon reconstruit encore TOUTES les tuiles à chaque geste (§4, OUVERT) : sur l'exemple, c'est lui le goulot, plus l'eau.

### LE GREFFON UNITY À PARITÉ — FAIT LE 7 OCTOBRE 2026 (branche `greffon-unity`), PARTIEL SUR L'EAU ET LE PINCEAU DE FEUILLAGE

La spécification : `engines/PARITE.md`. Ici, entrée par entrée, ce qui est fait dans Unity, mesuré, et ce qui ne l'est pas.

- **LES RÈGLES, EN C# PUR — FAIT, MESURÉ** (compilées telles quelles par le banc .NET et le Test Runner) : `MBTools.Extrude`,
  `SelectionOp.ShrinkEdge`, `WidenFlat`, `SelectBrush`, `MBShapes.RoomFromSelection` ; `MBAnimation` (lecture de
  `mb_animation`, le bloc JSON du `.glb` lu SOI-MÊME et associé par nom de matériau — glTFast n'est pas interrogé sur les
  extras) ; `MBTransitions` (fondu, réglages, table, texture des cases, lecture) ; `MBFoliage` ; `MBWater` (`fluides.gd`
  ligne à ligne) ; `MBWheel` (l'aiguillage de la molette). **Banc .NET : 284 cas sur 284** (editing 63, animation 44,
  transitions 93, foliage 59, water 25 — trois cas ajoutés, ci-dessous), plus 22 vérifications de la molette écrites à la
  main depuis le texte ; les anciens fichiers inchangés et verts. Un banc qui rencontre une sorte inconnue rougit
  (`ParityCheck`).
- **CE QUE LE C# A TROUVÉ DANS LE CONTRAT** :
  - ⚠ **LA PHASE N'ÉTAIT PAS EN DOUBLE** : le texte disait « double », `phase_de` rangeait ses calculs dans un `Vector3`
    (32 bits) — un C# qui suit le texte s'écartait jusqu'à 0,0017 sur les 7 cas. Corrigé une première fois ici (la
    référence en double), puis **tranché autrement sur `main`** (3b582d3) : la précision mixte EXACTE est écrite dans
    `rules_text`, les valeurs ne bougent pas. Le greffon suit le texte corrigé (`(float)` sur a_i et sur q_i) ; mutations
    « ×17 en double » et « a_i en double » rouges.
  - **TROIS GARDES MUETTES, TROIS CAS AJOUTÉS** (`epreuve_parite.gd`, régénérés dans les trois greffons, `test_parite`
    188/0) : une égalité de « face » (le haut avant +z), une origine de phase non entière, un choix au-delà de la 15e
    couche dans la texture des cases.
  - **DEUX CAS QUI MANQUENT ENCORE, NON AJOUTÉS** (dits par les bancs du feuillage et de l'eau) : un plant au bord d'un
    surplomb, centre dégagé mais bord couvert à MI-rayon (« under_matter au rayon entier » passe muet) ; un creux
    ASYMÉTRIQUE dont le seuil dépend de l'ordre des voisins (« z avant x dans le creux » passe muet).
  - Une mutation ÉQUIVALENTE : le vote « prioritaire » remplacé par « propriétaire » — la propriétaire est déjà le plus
    petit rang.
- **LE RENDU, DEUX PIPELINES — FAIT, VU À L'IMAGE** (Built-in : le projet d'essai ; URP 17.6 : un projet d'essai HORS
  DÉPÔT, `D:/SpannerGames/ATELIER/MarchingBlocks/unity/unity_urp`, copie de celui-ci avec URP, monté par un script `MBUrpSetup`). **HDRP : NON PRIS EN CHARGE,
  NON MESURÉ** (aucune SubShader HDRP). Les shaders portent une SubShader URP (`PackageRequirements` : rien ne casse dans
  un projet sans URP — 0 message de compilation mesuré dans les deux) et une Built-in.
  - **Transitions** : Unity n'a pas de passage par-dessus un matériau, et un matériau ajouté ne redessine que le dernier
    sous-maillage ⇒ **un second renderer** (enfant, jamais sauvé) sur les seules tuiles où deux couches d'une paire
    active se touchent (36 sur le monde d'essai), le matériau `MarchingBlocks/Transition Overlay` sur CHAQUE
    sous-maillage, le sommet de la tuile et le repère en `MaterialPropertyBlock`. Éclairé comme les tuiles :
    `UNITY_BRDF_PBS` (Built-in), `UniversalFragmentPBR` (URP) — un éclairage maison laissait une bande plus claire (vu).
    Le bruit suit le shader de l'appli (un par direction, PARITE §4).
  - ⚠ **UN VRAI DÉFAUT, VU À L'IMAGE** : les réglages des représentants posés en tableaux (`SetVectorArray`) sur le
    matériau du fondu, propriétés NON DÉCLARÉES, étaient **perdus dès qu'Unity reconstruisait les propriétés du matériau**
    (un import d'asset après l'habillage) — le fondu ne dessinait plus rien, et le compte des renderers ne le voyait
    pas. Tout est désormais en textures DÉCLARÉES ; la garde est une image (pixels avec et sans le fondu).
  - **Textures animées** : `MarchingBlocks/Lit` (le matériau glTF recopié de l'importeur par noms de propriétés —
    glTFast d'abord, puis les noms usuels), images en `Texture2DArray` (assets générés dans
    `<jeu>.mbset/MarchingBlocks generated/`, un `MBAnimatedSet`), défilement, pulsation ; **la phase de chaque tuile
    calculée sur le CPU** (précision de la règle) et posée par renderer ; une horloge (`_Time`, ou `_MBClock` pour les
    essais). ⚠ L'export Godot écrit UN matériau par maillage (« lava », « lava2 »…) : autant de copies animées.
  - **Feuillage** : `MarchingBlocksFoliage` pose les plants (T de la règle, converti par le repère MESURÉ sur le jeu de
    tuiles d'une couche — le même importeur a lu les modèles) ; le vent dans `MarchingBlocks/Lit` (`_MB_WIND`,
    `MBFoliage.Sway` ligne à ligne, en espace du format).
  - **Eau** : `MarchingBlocksWater` montre la nappe CUITE ; les six aspects (`MarchingBlocks/Water`) réécrits sur le
    CONTRAT. ⚠ **PARTIEL, DIT** : la profondeur vient du contrat (COLOR_0 a), pas du tampon de profondeur ; ni réfraction
    ni reflet du relief en espace écran ; le fond se voit par transparence. Les CASES d'eau sont recalculées quand on
    peint (`MBWater.World`, gizmos) ; la NAPPE l'est depuis le 7 octobre au soir (« L'eau recalculée dans Unity », ci-dessous).
  - **MESURÉ** : glTFast retourne v (v' = 1 − v, lu sur la nappe : 1,85 → −0,85) ; les shaders reviennent aux UV glTF.
  - ⚠ **LE PREMIER RENDU D'UNE CAPTURE URP EST FAUX** (des tuiles avec le matériau de l'autre couche, une plaque
    différente à chaque passage), les suivants justes : un rendu à blanc précède chaque capture.
- **L'ÉDITEUR — FAIT, MENÉ PAR LES TESTS, PAS TENU EN MAIN** : Extrude ↑ ↓ Facing (la sélection, ou la matière de
  l'étage ; Maj + clic étend, Alt + clic décale, l'étage suit, un Ctrl+Z par clic), Shrink (le bord), Widen, Room from
  selection, « Select empty cells too », F, et la molette (seule : le zoom d'Unity ; Maj + molette lue AUSSI en
  défilement horizontal, ce que Windows en fait). Les anciens Extrude ↑ ↓ et Shrink ne sont plus dans l'interface Unity
  (leurs sortes restent dans `tools_conformance.json` tant que les TROIS greffons n'ont pas migré, PARITE §6). Les
  nouveaux boutons ~~sont en TEXTE (Facing, Widen)~~ — **leurs icônes sont faites** (finitions, ci-dessous).
- **UNITY 6.6 : 51 TESTS SUR 51 EN BUILT-IN, 51 SUR 51 EN URP** (dont `ParityWorldTests`, 10, sur le monde écrit par
  `DEV_TOOLS/preparer_parite_unity.gd` : Rock et Sand qui se mêlent, Lava animée, un lac, cinq arbres). **Mutations dans
  Unity : 9, toutes rouges** (réglages non déclarés, phase jamais posée, plants sans le repère, molette seule volée,
  Extrude sans groupe d'annulation, Select qui prend les vides, fondu qui ne dessine rien, vent immobile, images hors
  du temps). **Captures regardées** (`ParityCaptures`, `-executeMethod ParityCaptures.CaptureAll -mbOut <dossier>`) :
  vue d'ensemble, bordure, lave à deux instants, lac, les six aspects d'eau — en Built-in et en URP.
- **CE QUI N'EST PAS FAIT** : ~~le PINCEAU DE FEUILLAGE dans l'éditeur Unity~~ (**FAIT**, finitions, ci-dessous) ; poser de l'eau dans l'éditeur (la règle `river_width` est portée, sans
  outil) ; recalculer la nappe ; HDRP ; Alt + molette sous Windows et tout ce qui est souris en main — jamais tenu.
### L'EAU RECALCULÉE DANS UNITY — FAITE LE 7 OCTOBRE 2026 (branche `eau-unity`, PARITE §12 ; la dernière entrée de la parité)

- **LE MAILLEUR, EN C# PUR — FAIT, MESURÉ** : `Runtime/MBWaterMesh.cs`, `eau_maillage.gd` (`tableaux_du_maillage`) ligne à
  ligne, calcul en double, rangement en 32 bits comme Godot (points, couleurs, `_chutes` en `PackedFloat32Array`,
  différences des normales). Sortie en espace du FORMAT, sens glTF. **14 cas sur 14 du premier coup** (banc
  `WaterMeshConformanceCheck` : appariement en sac, seaux par centre, rotations, ni réflexion ni doublon ; les tolérances
  et les 16 constantes du fichier relues et comparées ; l'appariement lui-même éprouvé sur le bassin : mélangé / tourné /
  bruité vrai, coin à 2e−4 / triangle retourné / doublé / couleurs 8 bits faux ; une sorte inconnue rougit ; un échec dit
  le triangle le plus proche et son écart par attribut).
- **MUTATIONS DU MAILLEUR : 24, 22 ROUGES PAR LES CAS, 2 MUETTES — ET UN TROU DU CONTRAT, MESURÉ** : « la lèvre la plus basse
  gardée » (fusion de deux cascades d'un même lieu) et « deux bandes sur une case » restent vertes sur les 14 cas. SONDÉ :
  une exception posée dans ces deux branches laisse les 14 cas verts — **aucun cas ne fusionne deux cascades ni ne voit deux
  fois une case de bande** (aucun cas n'a deux rivières sur une même case). Le greffon Godot l'a mesuré de son côté
  (« L'eau recalculée dans le greffon Godot ») : PARITE §12 se trompait en les disant gardées par les cas — ✓ **BOUCHÉ par le
  15e cas commun (branche `cas-eau`) ; ce qui suit est l'état d'avant** — OUVERT, à
  trancher dans `epreuve_parite.gd` (un cas à deux rivières sur les mêmes cases, dont l'une sort
  d'un tunnel sous la cascade de l'autre), PAS dans le greffon. En attendant, le greffon Unity les garde par le monde
  exporté ci-dessous (4 + 5 cases vues deux fois, 1 fusion, comptées par le préparateur) : **les deux deviennent ROUGES**.
- **LA REPRISE, PORTÉE** (`MBWater.World(cells, sources, before, changed)`) : l'EMPRISE de chaque source (`_etendre` :
  coulées à plat, creux, débord, chutes, élargie d'une case ; la mer : la boîte jusqu'à niveau + 1), la boîte vue
  (`_boite_compatible`), « la mer reprise, sinon rien d'autre », un seul océan partagé ; `MBWaterMesh` garde les nappes
  par corps (même OBJET), les cascades par leur signature, les sources par case (`memoire`). **Banc « incrémental =
  entier » (`WaterIncrementalCheck`, 6 020 gestes)** : SCRIPTÉS sur des mondes faits pour (un cratère profond dont le
  rebord est au-dessus de la source, un trou à côté du chemin d'une rivière sur un plateau, un conduit LOIN d'une rivière
  qui rend sa mare marine ou non, une rivière sur trois qui s'arrête, un bassin rehaussé sous sa cascade), SYSTÉMATIQUES
  (chaque case au contact de l'eau basculée puis remise) et AU HASARD ; règle, mer et nappe comparées au calcul entier.
  ⚠ **LE PREMIER BANC (gestes au hasard seuls) LAISSAIT MUETTES 6 MUTATIONS SUR 10** : il ne touchait presque jamais le bord
  d'une emprise. ⚠ **Deux « mutations » de la mémoire des cascades n'éprouvaient RIEN** (champ retiré d'`Equals` mais pas
  du hachage : la recherche ratait, on recalculait) — refaites sur les deux. **Mutations de la reprise : 10, 9 ROUGES, 1
  ÉQUIVALENTE** (l'emprise de la mer jusqu'à niveau au lieu de niveau + 1 : relue de son eau, la nappe d'une mer ne lit
  pas la rangée du dessus — `surface_dessinee` reprend les cases du niveau sous un plafond ; raisonné, gardé pour la
  fidélité à `fluides.gd`).
- **LE BRANCHEMENT (la décision de coordination)** : `MBWaterFollow` (C# pur, 16 vérifications) — jamais pendant un geste
  (`GUIUtility.hotControl` tenu : la nappe se dit PÉRIMÉE), 0,5 s de calme, une `Task` .NET sur une COPIE des cases (la
  nappe échangée sur le fil principal), un résultat dépassé par un nouveau geste n'est PAS posé, le suivi se COUPE au-delà
  d'1 s (temps compté jusqu'aux maillages posés) jusqu'au bouton **Rebuild water** (inspecteur `MarchingBlocksWaterEditor`,
  ou `RebuildWater()`), qui le réarme s'il est rapide. La nappe refaite est un `Mesh` en espace de l'IMPORTEUR (repère
  mesuré : glTFast X → −X, v retourné, sens inversé par le miroir) : posée exactement comme la cuite, mêmes matériaux.
  Jusqu'au premier recalcul, la nappe cuite se montre.
- **LE CONTRÔLE DE BOUT EN BOUT** : `DEV_TOOLS/preparer_eau_unity.gd` exporte un monde (mer et large, dalle sur la mer,
  tunnel sous une cascade, lac profond, trois rivières dans un escalier ; trois couches d'eau, 2 103 triangles) ; Unity
  recalcule depuis les sources = **la nappe cuite telle que glTFast l'a lue**, en sac, en espace du format. ⚠ **MESURÉ : les
  couleurs du .glb sont TRONQUÉES, pas arrondies** (écart 2,8e−3, plus qu'un demi-pas de 1/255) : tolérance 1/255. Le banc
  .NET relit aussi les triangles de la référence de ce monde (hors git, sauté s'il manque).
- **LES TEMPS, MESURÉS** (C#, l'exemple livré : 739 481 cases, 106 sources, mer de 354 159 cases ; `dotnet run -c Release --
  --water-timing <vidage>`) : **tout refaire 0,40 s** (règle 92 ms, nappes 309 ms dont la mer 267 ms pour 72 triangles)
  contre 5,1–6,7 s en GDScript ; **un geste près d'une rivière, avec la reprise : 13 ms** (84 sources reprises sur 106) ;
  loin de l'eau : 4 ms ; copie des cases 8 ms, leur comparaison (sur le fil) 107 ms. Dans Unity (monde exporté) : bouton
  4–10 ms ; un trait sur l'escalier : 15 ms dont 0,2–3 ms sur le fil principal pour partir. La coupure d'1 s ne devrait
  donc pas tomber sur l'exemple — non vu dans Unity (l'exemple n'y a pas été importé).
- **UNITY 6.6 : 65 TESTS SUR 65 EN BUILT-IN ET EN URP, APRÈS LA FUSION DE `main`** (58 avant elle) (dont `WaterRebuildTests`, 4 : bout en bout, le trait qui périme puis
  se recalcule hors du fil, le résultat dépassé non posé, la coupure et le bouton ; et dans le paquet la reprise et
  `MBWaterFollow`). ⚠ **Les trois tests À L'IMAGE du monde de la parité rendent du NOIR avec `-nographics`** (0,00 par
  pixel) : les lancer SANS ce drapeau (le README du projet d'essai le dit à tort). **Mutations dans Unity : 6, toutes
  rouges** (v non retourné, sens non inversé par le miroir, geste tenu ignoré, sans la reprise au bouton, sans la reprise
  sur le fil, nappe dépassée posée quand même), avec une passe de RÉFÉRENCE verte — qui a d'abord rougi : le geste de mon
  test était dans l'emprise de la mer (niveau + 1), la reprise avait raison.
- **VU À L'IMAGE** (`WaterCaptures.CaptureAll`, Built-in et URP) : nappe cuite et nappe refaite sous les six aspects, la
  cascade fusionnée, l'escalier, le lac, la mer sous la dalle — **indiscernables** (0,00 à 0,25 d'écart moyen par pixel, des
  bords de 8 bits). URP : un projet hors dépôt, `D:/SpannerGames/ATELIER/MarchingBlocks/unity/eau_unity_urp` (comme `D:/SpannerGames/ATELIER/MarchingBlocks/unity/unity_urp`).
- **CE QUI N'EST PAS FAIT** : poser une source d'eau dans l'éditeur Unity ; tenir le pinceau en main (la reprise et le fil
  sont menés par les tests, jamais à la souris).

### LE GREFFON GODOT À PARITÉ — FAIT LE 7 OCTOBRE 2026 (branche `greffon-godot`, sur le contrat ci-dessus)

Le greffon gratuit (`addons/marchingblocks_paint/`) porte la liste des greffons, entrée par entrée (cochées dans la
liste, §0). **Il ne charge toujours RIEN du cœur** : chaque règle y est réécrite depuis `rules_text` (en anglais, elle
part chez l'acheteur), et les cinq fichiers de cas communs la jugent.

- **LES RÈGLES — MESURÉ : 282 CAS SUR 282** (`test_greffon_peinture`, qui lit les cinq fichiers ; une sorte inconnue
  rougit, le nombre de cas de chaque fichier est vérifié) : `mb_tools.gd` (Extrude poser / étendre / décaler × haut /
  bas / face, `shrink_edge`, `widen_flat`, `select_brush`), `mb_shapes.gd` (`room_from_selection`), `mb_animation.gd`,
  `mb_transitions.gd`, `mb_foliage.gd`, `mb_water.gd` (la règle de `fluides.gd`, sans le natif ni la reprise).
- **LES SHADERS SONT CEUX DE L'APPLI, COPIÉS PAR UN GÉNÉRATEUR** (`DEV_TOOLS/generer_shaders_greffon.gd` →
  `mb_shaders.gd`, gardé par la péremption dans `test_greffon_peinture`, comme les icônes) : l'animation, les
  transitions, le vent, les six presets d'eau. **Deux transformations seulement**, chacune refusée si son motif manque :
  chaque `MODEL_MATRIX` passe par `mb_world_to_format` (l'animation et les transitions : un nœud du greffon peut être
  déplacé, tourné, à case ≠ 1 — l'appli, elle, est en espace du format) ; l'horloge de l'appli (`mb_temps`, `mb_image`)
  devient le `TIME` de Godot (le greffon ne peint pas d'images). Le vent et l'eau partent tels quels.
- **L'IMPORT D'UN MONDE** (`mb_world_file.gd`, `read_all`) lit `water`, `transitions`, `foliage` (une clé malformée refuse
  le monde) et pose à côté des couches : **MarchingBlocksWater** (la nappe cuite, le preset de son aspect ou le matériau
  de l'artiste ; elle se dit PÉRIMÉE quand les cases changent, et `follow_cells` montre l'eau recalculée — éteint par
  défaut : une mer de millions de cases en GDScript), **MarchingBlocksTransitions** (le passage en `next_pass` sur
  TOUS les matériaux des tuiles des couches, qui suit les cases peintes dans l'éditeur), **MarchingBlocksFoliage**
  (MultiMesh, le vent ; le sol et la hauteur passés dans le monde de Godot). Un jeu de tuiles animé : `mb_animation` lu
  dans le JSON du `.glb` (repli : la méta `extras`), ses images dans `animation/`. Les maillages d'une couche qui change
  un matériau deviennent les SIENS (`Tileset.own`) : un autre monde qui charge le même `.glb` n'est pas touché.
- **L'ÉDITION** : la barre a Extrude ↑ ↓ face (clic pose, Maj étend, Alt décale ; sur la sélection ou la matière de
  l'étage), Shrink du bord, « Select empty cells too », Room from selection ; les anciens Extrude ↑ ↓ et Shrink QUITTENT
  la barre de Godot (leurs fonctions restent pour `tools_conformance.json`, PARITE §6). **La molette** suit la règle de
  l'appli (`mb_editor.wheel`), sa valeur dite près de la souris. Éprouvé par de vrais événements (350 vérifications).
- **VU À L'IMAGE** (un projet d'essai avec le greffon seul, un monde exporté par l'appli, rendu avec fenêtre) : le fondu
  sable / roche (avec et sans passage, puis un représentant rouge pour voir OÙ il dessine), l'animation décalée tuile par
  tuile à deux instants, les arbres qui se balancent à trois instants, les SIX presets d'eau, et la barre
  (`ART/barre_greffon.png`, refaite).
- **MUTATIONS — 24, 24 ROUGES** : le fondu (départage, décalage sans 1 − s), la table au-delà de 15, la marge de la
  texture, l'aller-retour, la phase, une version plus récente, le défilement sans 7 × phase, le balancement ∝ h, un plant
  d'un modèle inconnu, le pinceau qui n'indexe pas, l'ordre des voisins de l'eau, deux mers, le lac qui ne déborde
  jamais, Extrude face, Shrink, Select, Room from selection, la molette (Alt ↑ inversé, le zoom volé), la copie des
  shaders retouchée, le passage non posé, la nappe sans son preset. ⚠ **UNE ÉTAIT D'ABORD MUETTE** : lire l'eau sous un
  plant au point même au lieu de p + 0,1 ne change AUCUN cas `check` (leurs plants sont à y = 1). Gardée dans
  `test_greffon_peinture` contre la référence du cœur (un sol à y = 0,75) — **les cas communs ne la gardent pas : à
  ajouter dans `epreuve_parite.gd`** (OUVERT : régénérer touche les trois greffons).
- ⚠ **UNE AMBIGUÏTÉ DE LA RÈGLE, TROUVÉE — OUVERT, À TRANCHER DANS LE CŒUR** : `phase_de` range `fract(p · 0,3183099 + k)`
  puis `× 17` dans un `Vector3` — en FLOTTANTS 32 BITS — alors que `rules_text` dit « computed in DOUBLE precision ».
  Mesuré : en double pur, l'origine (130, 64, −90) donne 0,32110 au lieu de 0,32080 attendu (et (1, 1, 1) 0,99927 au lieu
  de 0,99919) : **un greffon C# ou C++ écrit depuis le texte ÉCHOUE les cas `phase`**. Godot les passe parce que son
  `Vector3` arrondit pareil. Deux voies : dire l'arrondi 32 bits dans le texte, ou calculer `phase_de` en double (les
  cas changent). Aucune ne change le rendu de l'appli (son shader calcule à part).
- ⚠ **CE QUI RESTE, ET POURQUOI** : F (cadrer toute la matière) — la caméra de la vue 3D appartient à l'éditeur de Godot,
  sans API pour la poser (son F à lui centre la sélection) ; ~~PLANTER dans l'éditeur~~ (**FAIT**, finitions, ci-dessous) ; la NAPPE d'eau recalculée — attend les cas
  du mailleur (PARITE §2) ; le bruit des transitions — un par direction dans le shader, un seul dans les cas (PARITE §4,
  le greffon suit le shader) ; le vent d'un monde TOURNÉ tourne avec lui (exact pour un monde déplacé et mis à
  l'échelle).
- ⚠ **VU EN PASSANT** : l'export glTF de l'appli donne un matériau PAR MAILLAGE (« sand », « sand2 »… « sand52 »), chacun
  avec ses extras — l'association par nom marche, mais un moteur reçoit 52 matériaux pour un (le greffon partage
  au moins leurs tableaux d'images). À regarder pour Unity et Unreal (lots d'appels de dessin).
- ⚠ **PAS TENU EN MAIN** : le greffon dans l'éditeur de Godot lui-même (souris, molette réelle sous Windows, Alt +
  molette) — tout ce qu'il relaie est éprouvé par événements, l'aiguillage de l'éditeur ne se teste pas en headless.

### LE GREFFON UNREAL À PARITÉ — FAIT LE 7 OCTOBRE 2026 (branche `greffon-unreal`, sur le contrat ci-dessus)

Le greffon gratuit (`engines/unreal/MarchingBlocksPaint/`) porte la liste des greffons (cochée, §0). **Il ne charge rien
du cœur GDScript** : chaque règle est réécrite en C++ standard dans `MBCore` (ni exceptions ni RTTI), depuis `rules_text`.

- **LES RÈGLES — MESURÉ : 282 CAS SUR 282, PUIS 285 SUR 285 après la fusion de la branche Unity** (`core-runner/parity.cpp`, qui lit les cinq fichiers ; une sorte inconnue
  rougit ; limites et constantes vérifiées) : `MBEditing` (Extrude × 3 × 3, ShrinkEdge, WidenFlat, SelectBrush) et
  `Shapes::RoomFromSelection` 62/62 ; `MBAnimation` 43/43 (avec la lecture du JSON d'un `.glb`) ; `MBFoliage` 59/59 ;
  `MBTransitions` 93/93 ; `MBWater` 25/25 — la règle de `fluides.gd` ligne à ligne, **la mer étant `noyau/ocean.h`
  lui-même** : copie conforme dans `Private/MBCore/Noyau/`, le banc rougit si elle diffère d'un octet (pas de troisième
  copie écrite à la main). Plus `FFrame::Turn` (un lacet quelconque, éprouvé contre `QuarterTurn`). Les anciens cas
  (1 624 poses, 128 d'outils, 14 de monde, repère, visée) toujours verts.
- **LE BANC TOURNE SOUS MSVC** (`cl /std:c++17 /EHs-c- /GR- /W4 /WX`, masquage et rétrécissement en erreurs) : ni g++ ni
  clang ne sont nécessaires ; `build.sh` liste les nouveaux fichiers.
- **MUTATIONS — 33, 32 ROUGES, 1 ÉQUIVALENTE** : édition 5 (Facing départagé au dernier sens, poser sans sélection qui en fait
  une, Shrink sur tout bord ouvert, Select sans les vides, base de la salle toujours la plus basse), animation 6
  (aller-retour non replié, phase toute en double, défilement sans 7 × phase, pulsation hors émission, version plus
  récente acceptée…), feuillage 6, transitions 6 (décalage sans 1 − s, départage au dernier coin, choix ignorés, choix
  dans le quartet bas, paire a = b, couche au-delà de la 15e), eau 9 (ordre des voisins horizontaux, tas pris par le haut,
  plusieurs mers, débord sans portée, dessus de la boîte en horizon, profondeur sans fond, source fractionnaire, chute
  sortant au bas + 1, copie de `ocean.h` périmée). ⚠ **« PHASE SANS + 0,5 » D'ABORD MUETTE, PAR LES CAS** (toutes les origines étaient entières) : rouge depuis le cas
  d'origine non entière venu de la branche Unity (285 cas). ⚠ **UNE ÉQUIVALENTE, CHERCHÉE** : échanger bas et haut dans
  l'ordre des voisins du CREUX ne change rien — 400 000 mondes au hasard (reliefs à corniches, grottes à 55 et 70 % de
  plein) comparés à une seconde version de `MBWater` : aucune différence. Le lac (tout ce qui sort sous P) et P ne
  dépendent pas de l'ordre ; aucun cas n'a été ajouté, faute de monde qui le départage.
- **UNE RÈGLE AMBIGUË, TRANCHÉE SUR MAIN** : `phase_de` rangeait le vecteur intermédiaire dans un `Vector3` (32 bits)
  alors que le texte disait « double » — le banc C++ l'a vu (7 cas rouges). Corrigé sur main par le texte (précision
  mixte écrite) ; `Animation::PhaseOf` la suit.
- **UN BUG D'AVANT, TROUVÉ À L'IMPORT** : `Rebuild` parcourait `PlacementsLayered(In)[Mine]` dans un range-for — une
  référence dans un temporaire détruit avant la boucle. L'import d'un monde à tuiles plantait (allocation de 20 Po) :
  jamais mené avant avec des tuiles dans l'éditeur.
- **LA COUCHE UNREAL** : l'acteur du monde (Extrude, Widen, Shrink du bord, Room from selection, Select des vides ;
  données PAR INSTANCE — sommet de la tuile et phase — ; matériaux animés) ; trois acteurs neufs, faits par l'import du
  monde dans la même annulation : **MarchingBlocks Water** (nappe cuite et preset, cases recalculées), **Transitions**
  (Overlay Material), **Foliage** (ISM, vent, plantation). Le mode : la molette, F, la hauteur du collage, l'outil Plant.
  Un fichier dont `water`, `transitions` ou `foliage` brisent la règle est refusé en entier.
- **LES MATÉRIAUX SONT ÉCRITS PAR UN SCRIPT** (`Tools/build_materials.py`, MaterialEditingLibrary + nœuds Custom HLSL),
  livrés dans `Content/Materials` (9 assets binaires : `M_MB_Animated`, `M_MB_Transition`, `M_MB_Wind`, six
  `M_MB_Water_*`). La conversion monde → format passe par les paramètres `MB_ToFormat0..2` / `MB_ToWorld0..2`.
- **MESURÉ (§9 de PARITE.md)** : l'**Overlay Material se dessine sur une InstancedStaticMeshComponent** ; les **données
  par instance** (PerInstanceCustomData) se lisent dans le passage overlay et dans le World Position Offset ; on n'a donc
  jamais eu à lire la position d'une instance dans un matériau. `UVolumeTexture::CreateTransient` (PF_G8) et
  `UTexture2DArray::CreateTransient` marchent. Interchange nomme les paramètres du matériau glTF `BaseColorTexture`,
  `MetallicFactor`, `RoughnessFactor` (parent `MI_Default_Opaque`).
- **VU À L'IMAGE** (projet d'essai `C:\mbu`, rendu hors écran SceneCapture2D, monde fait d'exports réels : l'île de
  `test_fluides` et sa nappe, `rock.mbset`, `lava.mbset` aux images remplacées par quatre rayures distinctes, l'arbre de
  `test_parite` — un cube) : la bande de transition irrégulière entre roche et lave, dessus et flancs ; les tuiles de
  lave qui changent d'image à 0,3 s d'écart, chacune à sa phase ; le cube qui se balance (haut mobile, pied fixe) ; les
  six presets d'eau, distincts. ⚠ « stylisé » : un aplat sombre près de l'île (profondeur lue), à reprendre ; « réfléchissant »
  sans la marche en espace écran de l'appli (les reflets d'Unreal à la place). Captures : le dossier `captures/` du
  scratchpad de la session (non versionné).
- **CONSTRUIT** : `RunUAT BuildPlugin` (UE 5.8.3, Win64) **BUILD SUCCESSFUL, aucun avertissement**, les 9 matériaux empaquetés ⚠ un premier passage a échoué là où la construction du projet passait : sans « unity build », `TextureResource.h` manquait (`FTexture2DMipMap`) ; le projet d'essai se construit par
  `Build.bat UnrealEditor … -Project=C:\mbu\mbu.uproject` (chemin court : 260 caractères).
- ⚠ **PAS TENU EN MAIN** : aucun clic, aucune molette, aucune plantation à la souris dans l'éditeur ; tout a été mené par
  script (import, rendu). ⚠ **NON FAIT** : ~~la nappe d'eau recalculée~~ (faite depuis, branche `eau-unreal`), le texte du cran « près de la souris »,
  ~~les icônes « Facing » / « Widen » / « Plant »~~ (**FAITES**, finitions, ci-dessous), un jeu empaqueté.

### LES FINITIONS DES GREFFONS — FAIT LE 7 OCTOBRE 2026 (branche `finitions-greffons`) : LES ICÔNES, LE PINCEAU DE PLANTATION

Les deux trous de la parité hors de l'eau (l'eau : une autre branche, pas touchée ici).

- **LES ICÔNES — FAIT, VU À L'IMAGE.** `generer_icones_greffons.gd` écrit trois icônes de plus dans les TROIS greffons à
  la fois, depuis celles de l'appli : `facing` (`extruder_face`), `widen` (`elargir`), `plant` (`arbre`) — 48 icônes ; les
  45 d'avant inchangées octet pour octet. Branchées : Godot (Extrude facing, qui empruntait `move` ; Widen, qui n'avait
  PAS de bouton — Alt + molette seulement ; l'outil Plant et sa barre), Unity (Facing, Widen, l'outil Plant), Unreal
  (`ExtrudeOp("facing")`, `Op("widen")`, `ToolToggle("plant")` : l'outil Plant devient une bascule comme les autres ;
  `TextButton` retiré, plus d'appelant). Plus aucun bouton neuf en texte (les −X … +Z de Move de Unity et d'Unreal sont
  d'avant : des libellés d'axes). **Garde** (`test_greffon_peinture`) : chaque source demande les trois noms, aucune ne
  garde `GUIContent("Facing" | "Widen" | "Plant")`, `TextButton(` ni le `move` de Facing.
- **LE PINCEAU DE PLANTATION, GODOT — FAIT.** `mb_planting.gd` (nouveau) donne à la règle `mb_foliage.gd` le monde du
  greffon : les cases de toutes les couches visibles, l'eau (les cases que déduisent les nœuds MarchingBlocksWater), et le
  SOL — un rayon vertical contre les triangles des tuiles posées (index par colonne, une fois par trait), le sol des cases
  à défaut ; puis les trois gestes (un plant, un coup de pinceau — les essais tirés dans le disque dans l'ordre de l'appli —,
  effacer). `mb_editor.gd` : l'outil « plant » — clic : un plant ; Ctrl + clic (et glisser, un coup tous les 0,4 rayon) :
  le pinceau ; Maj + clic (et glisser) : effacer ; **UN Ctrl+Z par trait** (la propriété `plants` du nœud) ; Alt + molette
  la taille du pinceau, Maj + molette la densité (Ctrl reste l'étage). La barre : l'icône Plant parmi les outils, et sa
  barre — le MODÈLE (un menu des modèles du feuillage du monde, le courant coché, « Random rotation »), les trois modes
  (`up` dans l'air, `plant` libre, `widen` débordement), Brush · Density · Spacing · Slope. ⚠ Le nœud du feuillage doit
  rester où l'import l'a mis (son espace EST celui du format) ; Maj, pas le clic droit de l'appli (le clic droit vole la
  vue de Godot) — comme Unreal.
- **LE PINCEAU DE PLANTATION, UNITY — FAIT.** `Editor/MBPlanting.cs` (le même partage : `Asked` — cases, eau, sol par rayon
  vertical contre les maillages des tuiles posées, Möller–Trumbore —, `AimedPoint`, `PlantAt`, `SowAt`, `EraseAt`) ;
  l'inspecteur : l'icône Plant au bout de la rangée TOOL, la section PLANT (le modèle en liste, les trois modes en icônes,
  Brush size, Density, Spacing, Max slope, Random rotation) ; la vue : clic / Ctrl / Maj comme Godot et Unreal,
  `Undo.RecordObject` du feuillage, un groupe d'annulation par trait, le feuillage redessiné après un Ctrl+Z ; Alt / Maj
  + molette sur le pinceau (avant `MBWheel`, qui n'a pas bougé : le banc .NET non plus).
- **MESURÉ** : `test_greffon_peinture` 353 → **416** (le pinceau de plantation dans la vue, 44 vérifications, par de VRAIS
  clics à travers une caméra sur le monde complet exporté par l'appli — un plant sur la surface VUE à 1,75 et non sur les
  cases à 2, là où l'on a cliqué, Ctrl+Z / Ctrl+Y, refusé au bord en « free » et dit, accepté en « overflow », refusé dans
  le lac du cratère, sur un plant, dans la matière en l'air, accepté en l'air au-dessus du vide, le modèle choisi, un trait
  de pinceau de deux coups sans empiètement et UN Ctrl+Z, l'effacement exact et rendu, la molette, la barre et son menu,
  un monde sans feuillage dit ; plus la garde des icônes) ; **Unity 6.6 : 58 tests sur 58** (51 + `PlantToolTests` 7, sur le
  monde de la parité importé par glTFast, mêmes épreuves) ; banc .NET inchangé et vert ; les 28 suites Godot vertes (`fumee_appli` 937 :
  rouge une fois sur « Espace lâchée, il PLANE » pendant qu'un build Unreal chargeait la machine — le vol du Play test,
  hors du greffon —, verte relancée seule).
- **MUTATIONS — GODOT 12, TOUTES ROUGES** : le sol aux cases, l'eau jamais vue, le décalage de la grille des tuiles oublié,
  le point visé au centre de sa case, l'effacement sans rayon, le trait sans annulation, le glissé sans second coup, le
  modèle choisi ignoré, Maj sans effacer, le mode toujours libre, le menu des modèles inerte, la molette laissée à
  l'éditeur. ⚠ **« LE POINT VISÉ AU CENTRE DE SA CASE » D'ABORD MUETTE, PAR LE TEST** : tous les clics étaient en x,5 — le
  premier clic est désormais hors du centre. **UNITY 8, TOUTES ROUGES** (`PlantToolTests`) : le sol aux cases, l'eau
  jamais vue, le point visé au centre de sa case, l'effacement sans rayon, le trait sans regroupement d'annulation, le
  glissé sans second coup, le modèle choisi ignoré, la molette laissée à Unity. ⚠ **« LE TRAIT SANS REGROUPEMENT » D'ABORD
  MUETTE** : Unity ouvre un groupe d'annulation à chaque événement GUI, le test n'en ouvrait pas entre deux coups — il le
  fait désormais.
  ⚠ **UN ÉVÉNEMENT DE LA VUE FABRIQUÉ HORS D'UNE PASSE GUI SE LIT « Ignore »** dans Unity (son `rawType` reste MouseDown) :
  `ScenePlant` n'y voyait rien. Les tests mènent ce qu'il appelle (`StartPlant`, `PlantDrag`, `EndPlant`), comme
  `ShapeEditorTests` mène `ClickShape`.
- **VU À L'IMAGE** : la barre de Godot en quatre états (`ART/barre_greffon.png`, refaite : Add, Box, une sélection — Widen,
  Extrude facing —, l'outil Plant et sa barre ; les quatre nombres d'abord muets, nommés dans leur boîte depuis) ;
  l'inspecteur de Unity, AVEC fenêtre (`PanelCapture.Capture`, nouveau : l'icône Plant dans TOOL,
  Facing dans EXTRUDE, Widen dans SELECTION, la section PLANT et son modèle « Tree ») ; les icônes d'Unreal sur une planche (`Resources/Icons`, même trait que les
  autres). ⚠ **Le panneau d'Unreal n'a pas été vu** (aucune capture de Slate hors éditeur ouvert) : ce qui y est changé (trois noms d'icônes, la bascule Plant) est gardé par le texte des sources, et
  **`RunUAT BuildPlugin` (UE 5.8.3, Win64) : BUILD SUCCESSFUL, aucun avertissement**, les 48 icônes empaquetées.
- ⚠ **PAS TENU EN MAIN** : aucun des trois pinceaux à la souris dans un vrai éditeur ; le sol cherché sur de vrais arbres
  importés par l'artiste ; la performance d'un trait sur un très grand monde (l'eau et l'index des tuiles sont recalculés
  une fois par trait, en GDScript pour Godot).

### L'EAU RECALCULÉE DANS LE GREFFON UNREAL — FAITE LE 7 OCTOBRE 2026 (branche `eau-unreal`, PARITE §12 ; la dernière entrée de la parité)

Le greffon ne charge rien du cœur GDScript ni de la partie privée du cœur C++ (`gdextension/src/appli/eau.cpp` n'est pas
copié) : le mailleur est réécrit en C++ standard depuis `eau_maillage.gd` (`MBCore/MBWaterMesh.h/.cpp`, ni exceptions ni
RTTI), la reprise de `fluides.gd` portée dans `MBWater` (`WorldResumed`), le branchement dans `AMarchingBlocksWater`.

- **LES 14 CAS — MESURÉ : 14 SUR 14 AU PREMIER PASSAGE** (`core-runner/water_mesh.cpp`, sous MSVC aux drapeaux d'Unreal) ;
  l'appariement en sac écrit depuis `rules_text` et ÉPROUVÉ (vrai mélangé / tourné / bruité ; faux sur un coin à 2e−4, un
  triangle retourné, un doublé, des couleurs sur 8 bits, un triangle de moins). Flottants comme Godot : scalaires en
  double, points et normales en 32 bits (`_chutes` en float). Les tableaux de Godot (triangles horaires) sont retournés à
  la fin : le format est anti-horaire.
- **LA REPRISE, PORTÉE ET MESURÉE** : l'emprise tenue pendant le calcul (`vus` des coulées et des creux, les chutes, la
  dernière case, élargie d'une case ; la mer : la boîte sous son niveau + 1), `_boite_compatible`, la mer reprise d'abord,
  un `Id` par corps (un corps repris garde le sien) ; la mémoire des nappes par corps. **Reprise = entier** : 637 gestes
  au hasard (graine fixe) sur six mondes des cas — mêmes corps, même mer, mêmes tableaux de nappe à l'octet.
- **LE BOUT EN BOUT** (le banc prend des dossiers `.mbworld` en arguments) : l'île de `test_fluides` (583 triangles) et
  l'EXEMPLE livré exporté par `FormatMonde.exporter` (739 481 cases, 106 sources : 66 151, 5 073, 72 triangles) — la nappe
  refaite = le `.glb` cuit, **couleurs à 1/255 : un pas ENTIER, pas un demi** (MESURÉ : l'ArrayMesh de Godot TRONQUE,
  0,5 → 127/255 ; un écart de 0,0026 vu sur une cascade de l'île).
- **LES TEMPS, MESURÉS (C++, l'exemple)** : tout refaire **0,28 à 0,67 s** (boîte 31–62 ms, règle 110–307 ms, nappes
  134–301 ms ; machine partagée, quatre passes) — contre 5,1 à 6,7 s en GDScript ; **un geste avec la reprise 0,06 à 0,13 s** (près d'une
  rivière : 84 sources sur 106 reprises ; sur le sommet : 99). Dans l'éditeur (la copie des cases et leur différence
  comprises) : Rebuild Water entier 0,76 s ; un geste qui vide une couche entière (52 407 cases, la mer s'étend) 6,8 s —
  le suivi se coupe, comme décidé, et Rebuild Water rend l'eau en 0,86 s.
- **LE BRANCHEMENT (DÉCIDÉ par la coordination)** : chaque changement de cases (`RebuildWorld`, l'annulation, l'import,
  les sources d'une couche d'eau) dit l'eau périmée ; le mode dit quand un geste est ouvert (trait ou boîte tenus) — rien
  ne part pendant ; ~0,5 s de calme après (`mb.Water.Calm`), une tâche `UE::Tasks` calcule sur une COPIE (les `TArray` des
  couches ; la différence avec la copie d'avant donne les cases changées), le résultat est posé sur le fil du jeu ; une
  couche d'eau dont aucun corps n'a changé garde sa nappe ; **coupure** quand un recalcul automatique dépasse 1 s
  (`mb.Water.AutoRebuildLimit`, mesuré sur le seul calcul, pas l'attente du fil du jeu) : la nappe reste dite périmée
  jusqu'à « Rebuild water » (bouton de l'acteur et du panneau du mode, toujours là ; il rétablit le suivi s'il tient sous
  la seconde). **Mené dans l'éditeur** (script, l'île) : geste → recalcul posé 0,53 s après ; annulation → idem ; limite
  forcée à 0,1 ms → coupure, l'annulation suivante ne recalcule pas (« STALE ») ; le bouton → rétabli.
- ⚠ **LES COULEURS DE SOMMET, UN PIÈGE PAYÉ** (MESURÉ par `CompareWithBakedSheet`) : Interchange lit `COLOR_0` comme du
  sRGB et le range LINÉARISÉ (0,498 → 0,212) ; la construction le réencode en octets sRGB, que lisent les presets. La nappe
  refaite stockée brute aurait donné 0,735 au lieu de 0,5 — une autre eau. Elle est linéarisée de même ; la comparaison
  relit en sRGB. **Dans l'éditeur, nappe refaite = nappe cuite importée** (583 triangles sur 583, aucun retourné : le sens
  des triangles est le bon), y compris après un geste et son annulation.
- **VU À L'IMAGE** (`C:\mbw`, SceneCapture2D ; la refaite puis une copie de la cuite avec le MÊME matériau, à une image
  d'écart, quatre vues, six presets) : mêmes formes, mêmes cascades et remous ; **l'aplat sombre près de l'île, noté sous
  « stylisé », est sur la nappe CUITE seulement** — le grand rectangle d'horizon importé rend uni et sombre (plusieurs
  presets), la refaite y montre le motif. Pas le mailleur ; cause présumée : UV ±2 000 en demi-flottants dans la
  construction complète de l'importeur (NON MESURÉ). Les écarts de pixels restants sont l'animation (une image) et
  l'ordre des triangles transparents (la construction complète les réordonne).
- **MUTATIONS — 25, 23 ROUGES, 2 ÉQUIVALENTES** (mailleur 19, reprise et mémoire 6). ⚠ **« deux cascades jointes gardent la
  lèvre la plus BASSE » D'ABORD MUETTE** : instrumenté, AUCUN des 14 cas ni des gestes au hasard ne joint deux cascades
  (même constat que le greffon Godot) — rouge depuis une vérification écrite d'après `rules_text` (deux rivières qui
  quittent la même falaise de deux hauteurs : une nappe de 4,85 au pied le plus bas). « Deux bandes sur une case » n'est
  rouge que par l'exemple (bout en bout). Équivalentes : les sommets orphelins gardés (attendu) ; l'emprise de la mer sans
  sa rangée du dessus (la surface d'un greffon est relue de l'eau, ses débords lisent la même rangée — raisonné).
- **CONSTRUIT** : `RunUAT BuildPlugin` (UE 5.8.3, Win64) **BUILD SUCCESSFUL, aucun avertissement** (⚠ la cible JEU a d'abord échoué là où l'éditeur passait : le constructeur
  `FStaticMaterial` à nom de slot importé n'existe qu'en éditeur ; et la fusion de `main` avait retiré `TextButton` du panneau) ; les modules `MeshDescription` et
  `StaticMeshDescription` passent au runtime (la nappe se construit en jeu aussi, « fast build »).
- **EN PASSANT** : `Clear cells` ne reconstruisait QUE sa couche (bords des autres, transitions, eau oubliés) : il passe par
  `RebuildWorld`.
- ⚠ **OUVERT** : un monde SANS jeu de tuiles n'a pas de repère mesuré — la nappe cuite est posée par l'importeur, la refaite
  dans le repère par défaut : elles ne coïncident pas (un tel monde ne montre pas non plus de tuiles). Le coût d'un geste
  qui agrandit la mer (la profondeur relue case par case sous chaque case de surface). ~~Le cas commun « deux rivières au
  même endroit » à ajouter~~ (✓ fait, branche `cas-eau` : le 15e cas, rouge sous les deux mutations du C++). ⚠ **PAS TENU EN MAIN** : aucun trait à la souris — le branchement est
  mené par script (Clear cells, annuler, la console).

## 1. Le greffon en une phrase — DÉCIDÉ

> **Peindre des tuiles 3D NON CUBIQUES dans un GridMap, à partir de blocs que l'artiste modélise
> librement.**

Le GridMap de Godot pose des cubes. MarchingBlocks pose des morceaux de paysage — des coudes, des arches,
des angles rentrants, des tunnels — en assemblant automatiquement, selon le voisinage, des tuiles
découpées dans l'art de l'artiste.

⚠ **LA GÉOMÉTRIE PLUTÔT QUE LE PBR (Jordan, 24 septembre 2026).** Le relief est réel et libre, il n'est
pas suggéré par une carte de normales. ⚠ **LE PBR EST RETIRÉ, MODE SIMPLIFIÉ COMPRIS — DÉCIDÉ (Jordan,
29 septembre 2026) : « on n'en a plus besoin ».** Le PBR espace monde, son POM, sa case à cocher, son
shader et ses outils sont partis (§9.8) ; `git show 72d1764 -- addons/marchingblocks_core/pbr_monde.gd`
les rend.
⚠ **DES CARTES PBR REVIENNENT LE 2 OCTOBRE 2026, AUTREMENT** (Jordan) : déduites de l'albedo, par matériau, dans le
glTF standard — ni shader maison, ni POM (§5, « les cartes PBR déduites »).

---

## 2. Le modèle — MESURÉ : des marching blocks, pas des marching cubes

Une pièce est centrée sur un **SOMMET** du réseau, le coin commun à **huit cases**. L'état de ces huit
cases (pleine / vide) fait **2⁸ = 256 configurations**, qu'on réduit par rotation :

```
  groupe        rotations   classes   avec surface   ce que ça veut dire
  "libre"          24          23          21        sol = mur = plafond
  "vertical"        8          43          41        le mur se distingue, le plafond est le sol retourné
  "oriente"         4          70          68        sol ≠ mur ≠ plafond           ← DÉFAUT, DÉCIDÉ
```

**DÉCIDÉ (Jordan) — c'est « oriente » : sol, mur et plafond doivent être différents, et même un sol de
GROTTE doit différer d'un sol de MASSIF.** C'est ce qui interdit les deux autres groupes, où le plafond
n'est qu'un sol retourné.

- ⚠ **Les plans de coupe passent par les CENTRES des cases**, sur les trois axes. La case `p` occupe
  `[p, p+1]` ; le sommet `v` est en `v+(1,1,1)`. Une pièce est donc à cheval sur huit demi-cases.
- ⚠ **MESURÉ (Burnside, vérifié sur les trois groupes)** : 23, 43 et 70 orbites, et pour le groupe
  retenu, orbite × stabilisateur = 4 sur les 70 sans exception.
- ⚠ **MESURÉ, et c'est une jolie boucle** : le filtre « garde le haut » rend exactement les index
  [0, 10, 16, 22] — les quarts qu'employait le modèle 2D du temps où ce projet portait un jeu. Le modèle
  orienté EST la grille duale 2D remontée en 3D.

### LE MONDE SANS CONTACT DIAGONAL : 52 tuiles — DÉCIDÉ (Jordan, 25 septembre 2026), APPLIQUÉ le 27

Deux cellules qui ne se touchent que par une arête sont interdites dans le monde. Ce que ça achète,
mesuré : **35 classes d'intérieur + 17 variantes d'air libre = 52 tuiles au lieu de 90**, et un témoin
**manifold par construction** — les 33 classes en contact diagonal étaient la seule source d'arêtes à
quatre faces. Ce que ça coûte, assumé : plus d'éperon qui se touche par une pointe, plus d'érosion en
damier.

- ⚠ **`pieces_a_sculpter()` DIT LE MONDE (35), `classes_de_surface()` DIT LE MODÈLE (68).** La décision
  est restée deux jours sans atteindre cette fonction : tant qu'elle disait 68, un témoin juste passait
  pour incomplet de 33 classes, et c'est ce qui faisait traîner un SECOND témoin bourré de diagonales.
- ⚠ **UNE CLASSE DIAGONALE N'EST PAS « MANQUANTE », ELLE EST HORS DU MONDE** : `librairie()` ne la
  réclame pas, mais le peintre qui en rencontre une pose toujours un cube rouge (§3).
- **DÉCIDÉ (Jordan, 27 septembre 2026) — LE ROUGE, PAS LA COMPLÉTION.** (Depuis le 3 octobre 2026, un BOUTON
  « Fix diagonal contacts » répare à la demande — §5, « la passe du 3 octobre » ; le pinceau, lui, ne répare rien.) Peindre une diagonale pose un
  cube rouge, et le pinceau ne retouche rien de lui-même. `MB.completer_les_carres()` reste (le
  vérificateur s'en sert) mais **le pinceau ne l'appelle pas** : la réponse d'avant — « on complète le
  trou pour qu'il soit carré » — est retirée. C'est aussi la ligne du §3 : l'absence doit se VOIR là où
  elle arrive, jamais être comblée en silence.

### UN témoin UNIQUE : la planète paysage de 12³ — MESURÉ (27 septembre 2026)

`blocs_maitres.gd` porte **un seul bloc de 12³**, fait de FORMES qu'on reconnaît — canyon, arche,
pont, bouche de grotte, cheminée, auvent… — et **tout le reste en est dérivé**. Il n'est pas écrit à
la main dans `BLOCS` : il est la sortie de `DEV_TOOLS/planete_paysage.gd --couches`, **collée telle
quelle**. On retouche les formes là-bas, on recolle.

⚠ **ET LA COUVERTURE N'EST PAS LA LIVRAISON — les deux ont déjà divergé ici** (la machine annonçait
90/90 quand le greffon en livrait 73). Ce qui est mesuré, par le vrai trancheur sur l'aminci
(`test_blocs_maitres`, « livraison ») : **`librairie()` rend exactement les 52 tuiles du monde, aucune
en trop, 0 erreur de tranchage, 0 contact diagonal** sur 820 cases.

⚠ **IL Y A EU DEUX TÉMOINS, DU 25 AU 27 SEPTEMBRE 2026** : un paysage lisible (27 tuiles sur 90) et un
« résidu » sorti du finisseur (63), fait presque entièrement de contacts diagonaux — que le monde avait
déjà interdits. **Le second témoin fabriquait des tuiles que personne ne posera.** Jordan : un bloc
unique. ⚠ **Et « l'arche doit être visible comme une arche »** : un placeur minimal rendait 50/50 en
dix coups et un cube blanc, toute sa substance enfermée dans une cavité invisible. On bâtit un paysage,
et la couverture se mesure ensuite.

⚠ **L'ANCIEN 8³ (90 tuiles, avec diagonales) AVAIT ÉTÉ MESURÉ ainsi** : 90 items, 22 germes sur 22.
`verifier_bloc_unique.gd` reste, parce qu'il porte le finisseur et son élagage, mais il n'engendre plus
le témoin, et son mode `--residu` refuse de tourner.

⚠ **IL Y EN A EU NEUF, DE 4³.** Ils couvraient bien 68/68, mais ne pouvaient pas livrer les deux
CONTEXTES — mesuré, 10 classes à double contexte sur les 90 nécessaires — et leur alignement sur une
bande n'existait que pour les transporter ensemble.

- ⚠ **« Un paysage lisible est localement répétitif. »** La variété vient de l'IRRÉGULARITÉ, pas du
  volume : mesuré, 4³ donnait 18 classes sur 68, 5³ en donnait 19, 6³ en donnait 19 — passer de 27 à
  125 sommets achetait **une** classe. ⚠ **Et cette leçon s'est retournée contre moi en écrivant le
  bloc de 8³** : en remplaçant un boyau tordu par une grande salle lisse, j'ai gagné du volume et perdu
  dix-huit classes. Elle était écrite ici, sous mes yeux.
- **LA MÉTHODE : la main tient la FORME, une recherche complète la COUVERTURE.** La silhouette est
  écrite à la main ; un finisseur contraint ne touche qu'aux cases déclarées libres, jamais à la
  silhouette ; puis un **élagage** annule toute retouche non indispensable. 23/90 → 90/90.
  ⚠ Sans l'élagage, le finisseur rendait du bruit — 90/90 et un socle en dentelle. **Un compteur vert
  ne dit jamais qu'une tuile est à SA place.**
- ⚠ **L'ÉTENDUE RÉELLE EST DÉRIVÉE DES CASES OCCUPÉES, jamais du cube déclaré.** Prendre le cube
  déclaré décale l'origine d'une demi-case et **déplace TOUS les plans de coupe** — défaut réel, corrigé.

### Le CONTEXTE : 90 tuiles, pas 68 ni 136 — MESURÉ

Sol de grotte ≠ sol de massif, et cette distinction **n'est pas dans les huit bits** : c'est la même
configuration. Elle se DÉDUIT (`MB.exterieur_possible`), et le compte est **exact, pas estimé** :

> **22 classes peuvent être à l'air libre, 46 ne le peuvent jamais** (un plafond n'est pas sous le
> ciel). Le jeu à deux contextes demande donc **68 + 22 = 90 tuiles**.

- ⚠ **LE CRITÈRE A ÉTÉ CHOISI PAR ÉLIMINATION.** Le *vide enclos* (connexité) déclare **0 case de
  tunnel sur 48** comme intérieure sur un tunnel débouchant : disqualifié. L'*occlusion du ciel* sépare
  bien tunnel (3,5 %) et surplomb (19,9 %), mais **11 % des sommets changent d'avis** entre un bloc de
  7³ et le même volume enrobé de roche — l'artiste sculpterait des tuiles que le pinceau ne poserait
  jamais là : disqualifié. **ROCHE AU-DESSUS : 0 % de dérive**, parce qu'il ne demande pas COMBIEN.
- ⚠ **UNE LISTE `AMBIGUES` ÉCRITE À L'OBSERVATION A VÉCU ICI**, annonçant « 5 classes ambiguës ». Sa
  prémisse était fausse : **10** sur les blocs eux-mêmes, **35** dans un seul monde d'essai. On ne
  dimensionne pas sur l'observé quand le calcul est exact.

---

## 3. Le contrat avec l'artiste — DÉCIDÉ (Jordan, 24 septembre 2026)

C'est le partage de responsabilité, et il a été énoncé par Jordan mot pour mot :

> le MBS fourni (en mode aminci de préférence) dit déjà tout ce qu'il doit savoir à l'artiste, en plus
> du fait qu'on lui notifie à l'avance qu'il a **toute liberté pour chaque tuile mais à l'intérieur de
> sa case**, et que **la connectivité globale est SA responsabilité**. Ensuite le pipeline prend les
> cases une par une et les tranche, et c'est tout. Une vérification du trancheur ne devrait vérifier
> **que ce qu'il a fait lui-même** : bien trancher tout droit et tout net.

- ⚠ **LE TRANCHEUR NE JUGE PAS L'ART.** Une vérification de « couture » qui compare les germes de deux
  faces juge la modélisation, pas la découpe : elle a été rétrogradée de `erreurs` en `remarques`.
  J'avais même proposé de NORMALISER les germes — c'était pire : le greffon aurait modifié l'art.
- **Règle (A)** — le relief a le droit de **déborder** d'une case ; seul le contrat de couture fait foi.
- **Convention (A)** (`peau = false`) — on ne récolte que les sommets dont les huit cases sont DANS le
  bloc. Les sommets de bord récolteraient la face de sciage plate du bloc, pas de l'art.
- ⚠ **AUCUN REPLI PROCÉDURAL (Jordan, 23 septembre 2026).** L'artiste modélise tout ; une classe
  qu'aucun bloc ne livre est **signalée**, et le peintre voit un cube rouge. Combler en silence rendrait
  le trou invisible jusqu'à ce qu'un joueur tombe dedans. Le pinceau à tuile neutre et sa résolution en
  temps réel restent une affaire séparée.
- ⚠ **L'OCCUPATION DES CASES N'APPARTIENT PAS À L'ARTISTE.** Il sculpte le relief ; c'est le
  remplissage qui fixe les classes, et le changer changerait la couverture sans prévenir.

### La moitié du contrat qui n'était PAS écrite : les EXEMPLAIRES — DÉCIDÉ (Jordan, 27 septembre 2026)

⚠ **RENVERSÉ LE 30 SEPTEMBRE 2026** par « une tuile par clé, en copies liées » (section suivante), **ET RETIRÉ
DU CODE LE MÊME JOUR** (étape 5) : ce qui suit est de l'HISTOIRE — plus de nom `~k`, plus de tirage par
hachage, ni dans l'appli, ni dans le format, ni dans les trois greffons.

Le contrat disait « toute liberté pour chaque tuile, à l'intérieur de sa case ». Il ne disait pas ce
qu'il advient de **deux cases de MÊME CLASSE sculptées différemment** — et c'est la première chose
qu'un artiste fait, puisque « sculpter un paysage » veut dire rendre ce coin-ci différent de celui-là.

⚠ **LA RÉPONSE ÉTAIT : ON JETTE, EN SILENCE.** `tranchage.gd` tenait un `if pieces.has(cle): continue`
— il s'arrêtait au PREMIER sommet de chaque clé. **MESURÉ sur la planète paysage : 541 sommets
récoltables pour 52 clés, donc 489 morceaux sculptés jetés sans une erreur ni une remarque.** Et le
survivant n'était pas le meilleur : le balayage étant `vx, vy, vz` croissants, c'était **le plus petit
`vx`**. Tout ce que l'artiste sculptait au fond du bloc était perdu.

**DÉCIDÉ — ON GARDE TOUT.** Chaque sommet récoltable livre son morceau ; une clé porte autant
d'**exemplaires** que le modèle lui donne de sommets, et le peintre en **tire un par la POSITION**.

- ⚠ **« EXEMPLAIRE » ET NON « VARIANTE », ET LE MOT EST LE FOND** (§6, un mot une chose).
  « Variante » désigne déjà la variante d'AIR LIBRE, qui est une autre CLASSE de tuile (`_dehors`).
  Un exemplaire, c'est la même classe, le même contexte, une autre SCULPTURE.
- ⚠ **LE NOM NU EST L'EXEMPLAIRE 0, ET CE N'EST PAS UNE COMMODITÉ.** Un nom s'écrit
  `<classe>[_dehors][~k]` ; nommer la première « ...~0 » ferait poser des cubes rouges sur des lots
  parfaitement sains — le repli procédural, tout lot d'avant cette version (même raison qu'au §9.4).
- ⚠ **LE TIRAGE EST DÉTERMINÉ PAR LA POSITION, JAMAIS `randi()`.** Le massif se reconstruit à chaque
  case peinte, à chaque Ctrl+Z et à chaque rechargement : un tirage aléatoire redessinerait un AUTRE
  monde à chaque fois, et l'artiste ne pourrait ni juger ce qu'il voit ni le retrouver demain. Hachage
  spatial de Teschner — trois grands premiers mêlés par OU-exclusif ; ne pas mêler les axes rendrait
  des exemplaires en **bandes régulières**, c'est-à-dire le motif visible qu'on cherche à casser.
- ⚠ **LE RISQUE EST LA FISSURE, ET IL EXISTAIT DÉJÀ.** Deux exemplaires d'une même clé dont les plans
  de coupe ne s'accordent pas font une fissure là où ils se rencontrent. Ce n'est pas nouveau — les 52
  tuiles venaient déjà de 52 endroits différents — mais les exemplaires multiplient les occasions de
  la rencontrer. ~~C'est `verifier_couture` qui la voit~~ — **FAUX, MESURÉ LE 29 SEPTEMBRE 2026** : sur
  un travail qui en était plein, elle n'a rien dit pour 39 097 arêtes ouvertes. C'est
  **`verifier_sections`** qui la voit (§4, « les fentes entre tuiles »).
- ⚠ **ET `verifier_couture` N'AVAIT JAMAIS ÉTÉ LUE DE SA VIE.** Les deux appelants de `trancher()` ne
  passaient pas le paramètre `remarques` : elle écrivait dans le tableau par DÉFAUT, neuf à chaque
  appel et relu par personne. **Le seul contrôle qui juge l'accord des coutures tournait pour rien**,
  et c'est précisément celui dont les exemplaires ont besoin. Il s'affiche désormais dans le panneau.
- **MESURÉ (27 septembre 2026)** : `librairie()` rend **52 clés, 541 items, 489 exemplaires en plus**,
  et **0 remarque de couture** — sur le témoin procédural, tous les exemplaires d'une clé s'accordent
  à leurs plans de coupe. ⚠ C'est mesuré sur le maillage CALCULÉ ; sur de l'art sculpté, c'est ce
  chiffre-là qu'il faut regarder, et il n'a été mesuré sur AUCUN `.glb` réel.
- ⚠ **CE QUE ÇA NE RÈGLE PAS** : un détail UNIQUE reste impossible. Une clé vue 81 fois porte 81
  exemplaires, pas 81 emplacements : le tirage choisit lequel, jamais où. Une clé de voûte sculptée à
  UN endroit réapparaîtra ailleurs. **Un atlas ne porte pas d'unicité** — c'est le modèle, pas un
  défaut, et l'acheteur doit le lire AVANT d'acheter.

### UNE TUILE PAR CLÉ, EN COPIES LIÉES AU TÉMOIN — DÉCIDÉ (Jordan, 30 septembre 2026), ÉCRIT LE MÊME JOUR

⚠ **CECI RENVERSE « ON GARDE TOUT » (ci-dessus).** Le constat, MESURÉ sur `testtripotextured`
(`DEV_TOOLS/sonde_tuiles_falaise.gd`) : une falaise droite était bien `plaque_b2h2` partout, au bon
contexte, mais chaque case tirait par hachage un exemplaire parmi 30 (51 sous une dalle), découpés à 30
endroits du témoin et peints en conséquence — une mosaïque que rien ne justifie. Et **aucun** de ces
exemplaires n'est au milieu d'une paroi droite, même à 4³. Choisir l'exemplaire par voisinage (proposé
puis abandonné) réduisait le désordre sans l'éliminer, et le raccord de deux exemplaires qui ne se
sont jamais touchés au témoin ne se VOIT nulle part pendant qu'on sculpte.

**DÉCIDÉ** : une seule tuile par clé, et le témoin devient le MONDE PEINT DE SA PROPRE FORME — chaque
occurrence d'une clé (1 048 sommets, bords compris) EST la tuile livrée, en copie liée : on en sculpte
une, toutes suivent pendant le geste, rotations comprises. Plus de décor, plus rien de jeté, et le
témoin montre ce que le monde montrera.

- ⚠ **LE RACCORD DEVIENT GARANTI PAR CONSTRUCTION, À UNE CONDITION MESURABLE** : dans chaque seau de
  `verifier_sections` (axe, motif), les nœuds (clé, pose, face) doivent être RELIÉS par des joints du
  témoin — l'égalité des sections est transitive, donc un témoin étanche rend tout monde étanche. Un
  joint vaut pour ses quarts de tour seulement si base(Q·b) = Q·base(b) aux deux bouts.
  **MESURÉ** (`sonde_raccords_lies.gd`, planète de 12³) : 2 124 joints, **23 seaux sur 36 d'un seul
  tenant** ; les 13 autres laissent chacun un morceau de 1 ou 2 nœuds, qui se ramènent à **4 groupes**
  sur des clés rares — `tetra_b3h1`/`vrille_d_b3h1`, `vrille_g_b1h3`/`equerre_creuse_b3h2_a_dehors`,
  `pointe_creuse_b3h3`/`tetra_b1h3`, `vrille_d_b3h1_dehors`.
  **FAIT (30 septembre 2026) — LES RACCORDS** : la règle vit dans le cœur (`Tranchage.raccords_du_temoin`),
  et `planete_paysage.gd` a une quatrième étape après le finisseur, même discipline (des atomes ajoutés,
  aucun contact diagonal, ni tuile gagnée ni perdue), cherchée près des clés en cause. **Deux atomes,
  cinq cases** : un L surmonté en (1,4,5) sur la paroi ouest de la salle, une case sur le tablier de
  l'arche en (6,8,3). **36 seaux sur 36 d'un seul tenant.** Le témoin passe à **825 cases** et **549
  sommets récoltés** (les « 820 » et « 541 » écrits ailleurs ici décrivent le témoin d'avant) ; la carte
  « Twists » les porte (déduites). Gardé par `test_blocs_maitres` §16 — l'attendu négatif (sans les cinq
  cases : 23 reliés, 14 en trop, sept clés rares) vient de la sonde écrite à part. Quatre mutations
  rouges : aucun quart de tour transféré, quarts de tour sans condition (24 au lieu de 23 : la condition
  compte), côté oublié, nœuds du témoin au lieu de ceux du monde. ⚠ **Pas jugé à l'œil par Jordan** :
  la case sur l'arche se voit à peine sur la vignette.
  ⚠ C'est une condition SUFFISANTE : un morceau que le contexte empêcherait de rencontrer les autres
  n'aurait pas besoin d'être relié.
- **MESURÉ — LES COPIES LIÉES SURVIVENT À BLENDER 5.1** (`sonde_copies_liees.gd` + `.py`) : 1 048 nœuds sur
  52 maillages partagés → Blender importe **52 maillages liés** ; une retouche sur UNE occurrence est suivie
  par les autres ; l'export par défaut rend 52 maillages partagés, **0 pose de nœud changée**, la retouche
  dans le fichier. ⚠ **L'EXPORT DE GODOT NE PARTAGE RIEN** (1 048 maillages pour 1 048 nœuds, mesuré) :
  on relie dans le `GLTFState` après `append_from_scene`.
- ⚠ **LE TÉMOIN LIÉ PART EN .glb, PLUS EN OBJ** : l'OBJ n'a pas d'instances. Il n'est plus un maillage
  soudé mais des tuiles jointives. Un « Join » ou un « Apply » dans Blender casse les liens : deux
  occurrences d'une clé qui divergent se SIGNALENT, jamais ne se départagent en silence.
- **FAIT (30 septembre 2026) — L'EXPORT ET LA RELECTURE LIÉS** (`BlocsMaitres.exporter_le_temoin_lie`,
  `tuiles_liees`, branchée en tête de `librairie_depuis_glb`). L'étape 1 de l'appli écrit ce `.glb`.
  - ⚠ **IL SE RELIT TUILE PAR TUILE, SANS TRANCHER** : retrancher l'assemblage couperait un relief qui
    déborde sur la voisine et l'attribuerait à elle — ses copies divergeraient. La clé d'un nœud vient de
    sa POSITION (centre du sommet) ; la tuile est (pose attendue)⁻¹ × (pose lue) × maillage. Des copies
    déliées mais identiques restent une tuile ; une copie sculptée seule, déplacée ou tournée est une
    ERREUR qui nomme la clé, et la version du plus grand nombre est gardée. Un fichier est lié si la
    moitié des places du témoin au moins y sont occupées (un bloc d'un seul tenant posé à l'origine
    tombait sur la place (−1,−1,−1) — vu rougir). Le tranchage reste pour un travail non lié.
  - **La tuile d'une clé** est l'exemplaire le plus PUR du témoin calculé (le moins de cases de ses 4³
    qui s'écartent de sa configuration prolongée) : sinon une marche taillée par un voisin absent se
    répéterait à chaque occurrence. Les UV canoniques passent par `_uv_de_la_piece`, la règle de l'OBJ.
  - **MESURÉ** : 1 056 occurrences, 52 maillages, 264 Ko, export 15 s (il tranche le témoin calculé
    pour choisir), relecture **0,2 s** au lieu de ~17 s, 52 tuiles identiques à celles parties. **Dans
    Blender 5.1** (`sonde_copies_liees`, sur le VRAI export) : 52 maillages liés, avec ou sans « Merge
    Vertices » ; une retouche d'UNE copie suivie par les 244 ; relu : 52 tuiles, 0 erreur, seule la tuile
    retouchée a changé. **Dans l'appli, avec fenêtre** (`capture_temoin_lie.gd`) : Export → Import d'un
    retour de Blender → Slice → monde peint : le monde montre ce que montrait le témoin, à l'image.
  - ⚠ **UN DÉFAUT VU EN MENANT L'APPLI, QU'AUCUN TEST NE LISAIT** : `_tous_les_maillages` faisait une
    surface par objet, et Godot plafonne un maillage à 256 : l'écran n'affichait que 5 710 triangles sur
    31 472. Fusion par matériau ; gardé (§17).
  - ⚠ **LA LÉGENDE SUIT LA TUILE, PLUS LA FACE** : chaque occurrence porte les teintes de sa clé, dont le
    contexte se décide par SOMMET. À la lisière d'un surplomb (sous le pont) les sols font un damier
    vert / orange — c'est ce que le monde posera. Pas jugé par Jordan.
  - Gardé par `test_blocs_maitres` §17 (14 vérifications, attendus recomptés hors des fonctions éprouvées,
    fichiers fautifs bâtis en retouchant l'état glTF) ; six mutations rouges.
- **FAIT (30 septembre 2026) — LE MODELEUR PAR TUILE, PROPAGÉ EN DIRECT.** Le modèle vit dans le cœur
  (`temoin_lie.gd` : 52 `MaillageEdite` dans le repère de référence de leur clé, UN tableau de matériaux
  partagé par référence, les occurrences DÉDUITES, le rayon, l'assemblage, le `.glb` lié par
  `BlocsMaitres.ecrire_le_temoin_lie` — la même écriture que l'export). Il s'enregistre en
  `<projet>_witness.mbtiles` ; ⚠ un ancien `.mbmesh` (témoin d'un seul tenant) n'est ni converti ni écrasé,
  et l'écran le dit.
  - **L'écran** (`modeleur.gd`) édite la tuile de l'occurrence cliquée : ce qui dessine l'édition est posé
    à l'occurrence (`_edition`), les autres sont une MultiMesh PAR TUILE qui partage son maillage
    (`_propager`, à chaque mouvement de souris). ⚠ **TOUT CE QUI PARLE À LA CAMÉRA PASSE PAR LA POSE** :
    « G X 1 » va vers +X DU MONDE sur une copie tournée. Changer de tuile vide la sélection. L'annulation
    est par tuile (instantané marqué de sa clé) : un Ctrl+Z défait un geste sur une tuile qu'on n'édite
    plus. La boîte B écarte ce qu'une AUTRE copie cache.
  - `BlocsMaitres.tuiles_du_temoin` ne découpe plus que les 52 sommets retenus (`Tranchage.trancher(…,
    seuls)`, la même route) : **1,8 s au lieu de 15 s, 52 tuiles identiques** (mêmes sommets, mêmes formes).
  - **MESURÉ** : entrée en édition 2,2 s ; un G sur la paroi à l'air libre (16 faces, 244 copies) coûte
    **0,5 ms** par mouvement (l'ancien redessin complet : ~250 ms). Vu à l'image (`capture_modeleur_lie.gd`) :
    toutes les copies de la paroi suivent, et les fentes des joints s'ouvrent sous l'œil.
  - Gardé par `test_temoin_lie` (18, rayon comparé à une recherche BRUTE sur le témoin assemblé) et
    `fumee_appli` (181 : clic qui active l'occurrence, copies qui suivent, autre tuile, annulation croisée,
    copie tournée, B et l'occlusion, enregistrement relu lié, réouverture). **Sept mutations rouges** ; deux
    d'abord MUETTES, par des tests trop étroits : « les axes ne sont pas ramenés à la tuile » (Z ne le
    prouve pas — un quart de tour autour de +Y garde le haut : il fallait G X sur une copie tournée), et
    « poser une tuile ne re-partage pas les matériaux » (compter les matériaux ne voit pas une COPIE de
    même taille : il fallait `is_same`).
  - ⚠ **LA GARDE D'OCCLUSION A MENTI DEUX FOIS AVANT D'ÊTRE JUSTE** : une occurrence entièrement cachée
    (0 face vue), puis des rayons tirés de l'œil alors que la vue de face est ORTHOGRAPHIQUE.
  - ⚠ **PAS TENU EN MAIN.** Ni le modeleur lié souris en main, ni la route Blender par Jordan.
- **FAIT (30 septembre 2026) — LA PLANCHE DES TUILES** (`app/planche_tuiles.gd`), l'onglet « The tiles » du
  bandeau de Witness, à côté de « Shapes ». Une carte par tuile, dans l'ordre du modèle : la PHOTO de la
  tuile dans sa case, avec en fantôme (gris neutre) les demi-cases pleines de sa classe ; son nom anglais
  (`FormatNeutre`), air libre / sous roche, ce qu'elle fait dans un monde, et ×copies. Survol : toutes ses
  copies allumées en PETITS cubes (`remplir_zone(…, taille)`) ; clic : la vue cadre la copie la plus pure,
  et en édition elle passe en édition. Photos reprises après chaque enregistrement.
  - ⚠ **« CE QU'ELLE FAIT » N'EST ÉCRIT QUE POUR LES FAMILLES SÛRES** (dalles, arêtes, coins, équerres
    simples) ; les autres disent « un passage tordu entre deux niveaux », sans inventer de paysage.
  - ⚠ Bâtie à la demande (premier passage sur l'onglet), sur le témoin qu'on édite s'il est chargé, sinon sur
    le témoin calculé, que le modeleur reprend ensuite (pas de second calcul).
  - **Vu à l'image, trois défauts corrigés** : fantômes de la même couleur que la zone allumée ; les 244 copies
    d'une paroi allumées en cubes d'une case faisaient une masse ; une tuile de PLAFOND photographiée
    d'au-dessus était de dos, donc invisible (on la prend par en dessous quand le haut est plus plein).
    Et un masquage : le membre `onglet` était caché par une variable locale du même nom — la fumée PENDAIT
    au lieu d'échouer.
  - Gardé par `fumee_appli` (193 ; attendus : les listes du modèle, les copies recomptées par
    `cle_du_sommet`, les fantômes comptés sur les bits). Cinq mutations rouges.
  - ⚠ Pas jugé par Jordan : lisibilité des photos, phrases de rôle.
- **FAIT (30 septembre 2026) — LES EXEMPLAIRES RETIRÉS DE BOUT EN BOUT** (étape 5). ⚠ Pas seulement du
  format : si le format ne portait plus d'exemplaires mais que l'appli continuait d'en tirer, l'appli
  peindrait une mosaïque et les moteurs une tuile — deux descriptions du même monde (§6).
  - **Le trancheur choisit AVANT de découper** : pour chaque clé, le sommet le plus PUR (`MB.purete`, qui vit
    désormais dans le MODÈLE — elle ne lit que les cases), à égalité le premier du balayage ; il ne découpe
    que ceux-là. `tuiles_du_temoin` n'est plus qu'un appel au trancheur (une seule règle de choix), et
    `librairie()` rend **52 items, un par clé, de nom nu**. Un travail NON LIÉ (tout joint, un .obj) ne
    livre donc que la copie la plus lisible de chaque tuile, et le rapport le DIT (remarque « non lié »).
  - **Le peintre** pose le nom nu, sans tirage (`MB.poses` lit la seule PRÉSENCE d'une clé, et ne rend plus
    d'indice) ; un lot d'avant qui traîne des `~k` n'en pose aucun. Le cache passe au format 3.
  - **Le format neutre, toujours v1** (rien n'est publié) : `tiles = {clé: nom}`, plus de champ `copies`,
    plus d'étape « Copy » dans la règle écrite (l'étape 5 dit « une tuile par clé »). Un manifeste qui porte
    encore une LISTE par clé est REFUSÉ par les trois greffons, avec sa raison. Cas d'épreuve régénérés :
    18 cas, 1 624 poses, 460 d'air libre, 46 marqueurs — et chaque tuile attendue est LA tuile d'une clé.
  - **MESURÉ** : les 15 suites Godot vertes ; banc .NET 18 cas / 1 624 poses / 0 échec ; banc C++ (clang de
    Unity, drapeaux d'Unreal) 18 / 1 624 / 0 ; **Unity 6.6 : 22 tests sur 22** (sur le projet d'essai du
    worktree, réimporté de zéro) ; **Unreal 5.8.3 : `RunUAT BuildPlugin`, BUILD SUCCESSFUL, aucun avertissement**
    (l'en-tête public `MBRule.h` a changé). ⚠ Ni Unity ni Unreal n'ont été TENUS EN MAIN.
  - **Mutations, toutes rouges** : Godot et cœur — le trancheur qui prend le premier du balayage (18 / 52
    justes), l'égalité départagée à l'envers (47 / 52), la pureté qui ne prolonge pas, la pose qui rend un
    indice, le peintre qui range les `~k` sous leur clé (170 cases), le greffon qui accepte une liste ou ne
    retombe pas sur le nom nu, la remarque « non lié » tue ; .NET et C++ — pas de repli sur le nom nu, une
    liste de copies acceptée, le contexte d'air libre ignoré.
  - ⚠ **LE §14 DE `test_blocs_maitres` ÉPROUVE LE CHOIX** : il recalcule la pureté AUTREMENT (min/max, sans
    `MB.purete`) et exige des clés où le plus pur n'est PAS le premier du balayage (34 sur 52) — sinon
    « prendre le premier » passerait pour juste.
  - ⚠ **LE §15 (UV CANONIQUES) A CHANGÉ D'AUTORITÉ** : le lot ne porte plus qu'une copie par clé, donc la
    cohérence entre copies se juge sur l'OBJ du témoin, relu tel quel (549 occurrences, repère recalculé
    dans le test), puis la tuile du lot doit porter ces UV-là (0 écart).
  - ⚠ **`preparer_essai_unity.gd` ÉCRIVAIT DANS UN CHEMIN EN DUR** (`D:/MarchingBlocks/…`) : lancé depuis un
    autre checkout, il aurait fait éprouver à Unity l'ANCIEN paquet. Il dérive désormais du projet ouvert.
  - ⚠ **`global_blender_bevel_and_tripo_texture.mbset`** (le jeu exporté par Jordan, dans le dépôt) est au
    format d'avant — des LISTES par clé : les greffons le refusent désormais. À réexporter depuis l'appli.
  - ~~La variété pourra revenir en VARIANTES VOULUES dont l'appli fige les sections — OUVERT.~~ **FAIT le 4 octobre
    2026** : section suivante.

### LES VARIANTES VOULUES — DÉCIDÉ (Jordan, 4 octobre 2026), ÉCRIT LE MÊME JOUR

Jordan : « un système de tuiles alternatives pour les parties qui se répètent beaucoup, comme le plein de falaise, les
runs de corner, les pleins de ground, simplement avec un mode choix en monde et un mode choix aléatoire », puis, aux
trois questions posées (où se sculpte une variante, comment on choisit dans World, les poids) : « choisis le mieux ».
**Les trois réponses sont donc PROPOSÉES par délégation** : sur place dans le témoin ; un outil par tuile ET une
application à la sélection ; des poids entiers réglables par variante, 1 par défaut.

- **CE N'EST PAS LE RETOUR DES EXEMPLAIRES** (renversés le 30 septembre) : un exemplaire était découpé là où le hasard
  du témoin l'avait mis ; une variante est CRÉÉE (« New variant from this copy »), une à une, sur la clé qu'on veut, et
  ses bords sont ceux de sa clé PAR CONSTRUCTION — elle entre dans les classes de sections de sa clé
  (`Sections._faces_de` lit `MB.cle_de_tuile`), donc un sommet de bord déplacé dans la variante entraîne la base et
  toutes les tuiles d'en face, et inversement. Le raccord reste garanti dans tout monde.
- **LE NOM** : `<clé>_var<k>` (k de 1 à `MB.VARIANTES_MAXI` = 9), « slab_b2h2_outdoor_var1 » en anglais. ⚠ Un mot, une
  chose (§6) : la « variante d'air libre » (`_dehors`) reste une autre CLÉ. `MB.nom_nu` retire les deux suffixes.
- **LE TÉMOIN** (`temoin_lie.gd`) : une variante est une tuile de plus dans `tuiles` ; `affectation` = {sommet du témoin:
  k} dit quelles occurrences la montrent (chaque occurrence a `cle` — la TUILE montrée — et `modele` — sa clé). Le
  témoin montre donc la variante POSÉE parmi ses vraies voisines : c'est là qu'on juge son raccord. Supprimer une
  variante renumérote les suivantes (une var3 sans var2 n'est jamais posée). Le `.mbtiles` porte l'affectation.
- **LE .glb LIÉ** : l'occurrence affectée reçoit le maillage nommé « …_var<k> » ; à la relecture (`tuiles_liees`) la
  clé vient toujours de la POSITION, et la variante du NOM DU MAILLAGE (un « .001 » de Blender toléré). ⚠ **C'EST LA
  SEULE CHOSE QUI SE DÉCLARE** ici, contre la doctrine (§4) — rien d'autre ne distingue deux sculptures voulues d'une
  copie abîmée. Un nom perdu (Join, renommage) ramène la copie à sa clé, où elle diverge : l'erreur « ne montrent plus
  la même tuile » est dite, jamais un départage en silence (mesuré par mutation : 244 occurrences, 2 formes).
- **LE MONDE** (`MB.tuile_du_sommet`, appelée par le peintre APRÈS `pose_du_sommet`, qui ne change pas) : un CHOIX posé
  à ce sommet l'emporte s'il désigne une tuile que le lot a (0 = la base) ; sinon le TIRAGE — poids entiers de la
  couche (`poids` = {clé: [base, var1, …]}, absent = 1, négatif = 0), et `hachage_du_sommet` (Teschner, puis deux
  brassages : sans eux `h mod n` dessinait des bandes). Jamais `randi()` : le même monde à chaque reconstruction.
  Poids et choix appartiennent à la COUCHE (`.mbproj` : `poids`, `choix` à plat par quatre), les variantes à son
  témoin. ⚠ **PROPOSÉ** : un choix est attaché au SOMMET, pas à la tuile — si l'on repeint autour et que la clé du
  sommet change, le choix s'applique à la nouvelle clé (s'il a ce rang de variante), sinon retombe sur le tirage.
- **L'ÉCRAN** (`app/variantes.gd`, branché par quelques lignes dans `editor.gd`) : Witness geometry → « Variants »
  (la copie montre base / variante k, « New variant from this copy », « This copy shows », « Delete this variant »,
  UNE annulation chacun) ; World → « Variants » (l'outil Variant : clic = la suivante, clic droit = le tirage ; les
  POIDS de la clé pointée ; « On the selection » : Random / Base / Variant k sur les sommets des cases sélectionnées ;
  « Back to random everywhere »). L'icône `variante`. Le manuel (F1) a ses deux paragraphes.
- **LES FORMATS** : `tileset.json` garde `tiles` = {clé: SA BASE} et ajoute `variants` = {clé: [var1, var2…]} et
  `variants_rules_text` ; `world.json` ajoute par couche `variant_weights` et `variant_choices` (`FormatMonde.
  lire_variantes`, refus d'un sommet choisi deux fois, de choix qui ne vont pas par quatre, d'un poids non entier).
  ⚠ ~~PAS DANS `regle()` NI DANS LES CAS D'ÉPREUVE~~ — **ILS Y SONT DEPUIS LE 5 OCTOBRE 2026** (ci-dessous).
- **MESURÉ** : `test_variantes` (76 : noms ; hachage contre des valeurs calculées en PYTHON ; tirage 2:1:1 sur 6 400
  sommets à 3 points près, deux voisins identiques 0,375 du temps ± 0,04 — sans bandes ; poids nuls, négatifs,
  absents ; choix ; le peintre contre `MB.poses` + le tirage déroulé ; choix refait localement = reconstruction
  complète ; le témoin : variante, affectation, 0 absence de section, cœur sculpté sans toucher la base, un bord de
  variante propagé → 0 joint ouvert recompté à part ; `.mbtiles`, `.glb` lié, lot, témoin relu de Blender ; suppression
  et renumérotation ; annulation ; les deux formats). `test_projet` 95 (+5). `fumee_appli` 740 (+22, par les vrais
  boutons : la variante, Ctrl+Z / Ctrl+Y, le monde peint de la forme du témoin — 244 parois, base et variante selon
  le tirage, l'outil Variant (suivante, retour, Ctrl+Z, clic droit), un poids à 0, Ctrl+Z, la sélection, l'enregistrement).
  **21 MUTATIONS, TOUTES ROUGES** : le cœur 9 (choix ignoré, hachage sans brassage, peintre sans variantes, lot sans
  variantes, relecture sans le nom — 244 occurrences « en 2 formes » —, écriture sans affectation, sections par nom de
  tuile, suppression sans renumérotation, poids ignorés) ; les formats 3 et le projet 2 ; l'écran 7 (clic non branché,
  choix sans reconstruction, geste du témoin sans annulation, Add qui ne relâche pas l'outil, poids non enregistrés,
  la sélection qui pose la base, un poids qui ne retire rien). ⚠ **« `tiles` PORTE LES VARIANTES » D'ABORD MUETTE, PAR
  LE TEST** : il cherchait la clé fautive sous son nom juste, alors que `id_de_cle` d'une variante rend
  « slab_b2h2_dehors_var1 » — il compte désormais les entrées. **Vu à l'image** (`DEV_TOOLS/capture_variantes.gd`,
  Xvfb, OpenGL) : une variante rouge du sol et de la paroi, mêlées par le tirage dans le monde, toutes posées par la
  sélection ; dans le témoin, seule la copie désignée la montre.
- ⚠ **PAS TENU EN MAIN, PAS JUGÉ PAR JORDAN** : la lisibilité de la section, le geste de l'outil, si les poids se
  règlent bien « pour la clé pointée ». La planche des tuiles montre aussi les variantes (une carte chacune), sans test.
- **LES VARIANTES DANS LES GREFFONS — FAITES (5 octobre 2026, Jordan : « go » pour les greffons, les variantes d'abord)** :
  - **la règle est l'ÉTAPE 8 de `rules_text`** (`FormatNeutre.regle()`) : la couche qui POSE le sommet décide — son choix
    s'il est dans [0, n], sinon le tirage pesé sur le hachage (64 bits). `regle_des_variantes()` et le champ
    `variants_rules_text` sont retirés (une seule règle écrite). `FormatMonde.regle()` décrit `variant_weights` /
    `variant_choices`, et `FormatMonde.lire` les rend (les choix triés par sommet) ou refuse le fichier.
    ⚠ **LE HACHAGE N'EST PLUS QUE CELUI DE L'ÉTAPE 8** : le contrôle « la règle écrite ne tire plus de copie par hachage »
    (les exemplaires) refuse désormais un hachage AVANT l'étape 8, plus le mot.
  - **les cas** (`conformance.json`) : un jeu « varied » (« rich » + 2, 1 et 3 variantes sur les trois clés les plus posées,
    `tileset_variants`) ; `variant_cases` (6 : tirage par défaut sur quatre mondes, coordonnées négatives comprises ;
    des poids 2:1:1, une base NÉGATIVE à côté d'une variante, des poids tous ≤ 0 ; des choix dans la portée, hors de
    portée, sur une clé sans variante, sur un sommet vide) — 794 poses, 174 en variante ; un cas multicouche aux poids
    et choix différents par couche ; `world_conformance.json` : un bon monde à variantes et cinq refus de plus.
    Chaque contrôle exige que les cas EXERCENT l'étape 8 (variantes ET bases posées ; sans l'étape 8, chaque cas pose
    autre chose).
  - **la tuile sous la souris** sort de l'appli (`Vue.tuile_sous`) en règle partagée : `Outils.sommet_touche` (v = ⌊p − ½⌋
    sur la face touchée), et la sorte `tile_vertex` des cas d'outils (8 cas, 128 en tout, treize sortes).
  - **Godot** : `MBRule.variant_tile` / `vertex_hash`, `placements(…, variants, weights, choices)` ; le chargeur prend les
    tuiles variantes ; `MarchingBlocksWorld.variant_weights` / `variant_choices` (exportés) et `variant_at` ; l'import
    d'un `.mbworld` les pose ; l'outil **Variant (V)** : clic = la suivante, **Maj + clic = le tirage** (le clic droit
    appartient à la vue libre de Godot — « Shift fait l'inverse », comme les autres outils du greffon), une annulation.
  - **Unity** : `Rule.VariantTile` / `VertexHash`, `VariantSettings`, `Placements(…, settings)` ; `MarchingBlocksWorld` :
    `variantWeights` (inspecteur) et les choix sérialisés, `SetVariantChoice`, `VariantAt`, `TileUnderRay` ;
    `MBWorldFile` lit les variantes, l'importeur les pose (`SetVariants`, sans reconstruire une couche inactive) ;
    `Mode.Variant` (V, et son icône dans la rangée des outils — index 5 de la rangée, pas `Mode.Shape`).
    ⚠ **UN DÉFAUT RÉEL TROUVÉ DANS UNITY** : deux clics dans la même image tombaient dans le même groupe d'annulation
    (Unity groupe par événement) — un Ctrl+Z défaisait les deux. `Undo.IncrementCurrentGroup()` à chaque clic.
  - **Unreal** : `FRule::VariantTile` / `VertexHash`, `FVariantSettings`, `FLayerInput::Variants` ; `FWorldFile` lit les
    variantes ; `AMarchingBlocksWorld` : `VariantWeights` (Details, `FMarchingBlocksVariantWeights`), `VariantChoices`
    sauvés avec le niveau, `ClickVariant` en UNE transaction ; `EMarchingBlocksTool::Variant` (DERNIER, rien de
    renuméroté), V dans le mode, un bouton dans le panneau Slate. ⚠ Un local `Index` aurait masqué le membre
    (`FCellSet Index`, C4458) : renommé avant de compiler.
  - **MESURÉ** : `test_greffon_peinture` 282 (+27 : les cas à variantes, le multicouche à variantes, `tile_vertex`, et de
    bout en bout — l'appli exporte un lot dont la clé du sol a deux variantes, le greffon pose sur un sol 6 × 6 avec des
    poids ce que pose la référence, puis l'outil Variant mené par de VRAIS clics à travers une caméra : suivante,
    suivante, Ctrl+Z, Ctrl+Y, Maj + clic, aucun autre sommet changé) ; banc .NET et banc C++ (clang de Unity, drapeaux
    d'Unreal) : 18 + 6 + 6 cas de pose, 128 d'outils, 14 de monde, 0 échec ; **Unity 6.6 : 35 tests sur 35** (dont
    `VariantTests` sur un `varied.mbset` écrit par `preparer_essai_unity.gd` : les poses de la référence, l'outil,
    l'annulation, la tuile sous un rayon) ; **Unreal 5.8.3 : BuildPlugin, BUILD SUCCESSFUL, aucun avertissement**.
  - **MUTATIONS, TOUTES ROUGES** : Godot 10 (choix ignorés, hachage sans second brassage, poids négatifs gardés, poids de
    la première couche partout, tuiles variantes non chargées, choix du monde perdus, Maj ignorée, pas d'annulation,
    sommet sans le demi, rang courant toujours 0) ; .NET 5 et C++ 5 (choix ignorés, poids négatifs gardés, réglages
    de la couche 0 partout / hachage sans second brassage, sommet sans le demi, choix du monde perdus) ; Unity 3, DANS
    Unity (un clic sans son groupe d'annulation, le monde sans ses réglages de variantes, la variante posée lue comme la base). ⚠ **« POIDS NÉGATIFS
    GARDÉS » D'ABORD MUETTE, ET C'ÉTAIT LE CAS** : le seul poids négatif était dans une clé aux poids tous ≤ 0, où 0 et
    la valeur absolue posent la même base — une base négative à côté d'une variante l'a fait rougir dans les trois.
    ⚠ Une mutation Godot ne compilait plus (une boucle vidée) : récrite, elle n'éprouvait rien.
  - ⚠ **PAS TENU EN MAIN** : ni la barre Godot dans l'éditeur, ni la Scene view d'Unity au vrai clic (le test appelle
    `ClickVariant` avec le sommet qu'un clic trouverait), ni le mode Unreal (seul compile). Les poids se règlent dans
    l'inspecteur / le panneau Details, sans l'interface « clé pointée » de l'appli.

### LES SECTIONS PARTAGÉES — DEMANDÉ PAR JORDAN (30 septembre 2026), ÉCRIT EN TROIS POINTS ET LA BRIDE

Jordan : les sommets du bord d'une paroi doivent être partagés avec ceux du bord correspondant d'un coin,
d'une lèvre de plateau… — « la seule manière d'avoir un witness monolithique sans trous ». Les copies liées
tiennent une tuile identique à elle-même ; elles ne tiennent rien ENTRE deux clés (vu à l'image : tirer une
paroi ouvre une fente à chaque joint). Il faut que la section d'une face — ses sommets sur le plan de coupe
— soit UNE donnée partagée par toutes les faces qui peuvent se trouver face à face dans un monde.

**MESURÉ** (`DEV_TOOLS/sonde_sections_partagees.gd`, sur les 52 tuiles du témoin calculé) :
- **246 faces de référence** (clé, axe, signe) au motif ni vide ni plein ; reliées par les 36 seaux de
  `verifier_sections` sous CHAQUE pose du peintre (une face tombe dans un seau par pose), elles forment
  **10 classes** de 12 à 32 faces, chacune touchant 7 à 24 tuiles.
- **8 classes sans contrainte, 2 qui imposent une SYMÉTRIE d'ordre 2** (deux chemins donnent deux cartes :
  la section doit se superposer à elle-même par leur écart).
- **1 230 sommets de bord ; dans chaque classe, chaque point existe dans CHAQUE face, et les deux classes
  symétriques le sont** : 0 absence, 0 point hors symétrie. Tout le système des coutures tient en
  **50 points** (3 à 7 par classe). **Contrôle négatif** : un seul sommet de paroi décalé d'un centième
  dans son plan → 30 absences dans sa classe de 30 faces (vu rougir).
- 246 sommets sont sur une ARÊTE de case (deux plans à la fois : ils ne pourront glisser que le long de
  l'arête, et lient deux classes) ; aucun sur un coin de case ; aucun bord posé sur une face de motif vide
  ou plein.
- ⚠ **CE QUE ÇA NE COUVRE PAS** : la route Blender (des objets distincts n'y partagent aucun sommet — il n'y
  restera que la vérification) ; et un relief qui FRANCHIT un plan de coupe (règle (A)) n'a pas de sommet
  sur le plan : `verifier_sections` ne le juge pas, le partage non plus.
- **DÉCIDÉ (Jordan, 30 septembre 2026)** : les trois points, dans l'ordre — le cœur, le modeleur, les coupes.
- **POINT 1, ÉCRIT — LE CŒUR** (`addons/marchingblocks_core/sections.gd`) :
  - **les classes**, calculées UNE fois (elles ne dépendent que des clés et des poses) : pour chaque nœud, sa
    classe et sa CARTE vers la racine ; pour chaque classe, son GROUPE de symétries ;
  - **l'index des points** (`indexer`, à rebâtir quand la géométrie change) : chaque sommet de bord ramené
    dans le repère de sa classe puis à un représentant CANONIQUE de son orbite sous le groupe ;
  - `correspondants`, `projeter` (dans le plan, sur l'arête s'il en touche deux, et moyenné sur le
    STABILISATEUR quand une symétrie fixe le point), `propager` (de proche en proche : un sommet d'arête
    passe d'une classe à l'autre ; les composantes reçues par ses deux faces se FUSIONNENT), `deplacer`
    (depuis les positions de départ, jamais cumulé), `photo`.
  - **MESURÉ** (`DEV_TOOLS/test_sections.gd`, 12 au point 1) — attendus hors de `sections.gd` : les chiffres de la sonde
    (246 nœuds, 10 classes de tailles [12 … 32], 8 + 2 symétriques) ; et les **VRAIS JOINTS du témoin** : deux
    occurrences voisines posées dans le monde, **10 384 paires** de sommets qui y coïncident, chacune
    retrouvée parmi les correspondants ; 984 sommets de bord (738 sur une face, 246 sur une arête) restent
    dans leur plan une fois projetés ; **13 déplacements propagés à 531 sommets, 0 conflit, 0 joint ouvert,
    0 remarque de `verifier_sections`** — dont un point fixé par une symétrie et un sommet d'arête. Contrôle :
    le même déplacement sans propagation ouvre 5 joints.
  - **Mutations** : cinq rouges (normale gardée, symétrie canonique ignorée, pas de proche en proche, pas de
    moyenne sur le stabilisateur, carte au lieu de son inverse). ⚠ **« écraser au lieu de fusionner » est
    MUETTE, et c'est une mutation ÉQUIVALENTE** : tout sommet posé sur une arête touche DEUX faces à classe
    (246 sur 246, aucun bord sur une face morte), son déplacement est donc déjà projeté sur l'arête, et ses
    deux faces lui transportent le même vecteur. La fusion reste, contre un état incohérent.
- **POINT 2, ÉCRIT — LE MODELEUR** (`app/modeleur.gd`). Pendant **G, R, S** (édition proportionnelle
  comprise), chaque sommet de BORD qui bouge est projeté (dans son plan, sur son arête), et ses correspondants
  de TOUTES les tuiles suivent, à chaque mouvement de souris, depuis les positions de départ. Au début du geste,
  une propagation-sonde dit ce qui PEUT bouger : les autres tuiles à redessiner, et les sommets de la tuile en
  édition entraînés par ses propres bords (la face x+ d'une paroi et sa face x− se correspondent). Confirmé,
  le geste émet un `TL.Lot` (toutes les tuiles touchées, avant et après) : **UN Ctrl+Z rend tout** ; Échap
  rend les autres tuiles depuis la photo de départ.
  - ⚠ **PAS PENDANT UNE EXTRUSION** : E pose des sommets neufs SUR ceux qu'il extrude, qui n'ont pas de
    correspondants — c'est de la topologie, le point 3.
  - ⚠ **LA PROPAGATION COÛTAIT 86 ms** (un G qui suivait la souris à 10 images/s, 328 sommets dans 49 tuiles)
    : les cartes étaient recomposées à chaque visite, et chaque sommet atteint relisait toute la liste de son
    point (une trentaine de membres). Cartes précalculées à l'indexation, point canonique traité UNE fois :
    **2,6 ms** — et **9,1 ms par mouvement** mesurés dans l'appli avec fenêtre (tirer les faces de la paroi).
  - **Vu à l'image** (`capture_modeleur_lie.gd`, les faces avant et arrière de la paroi tirées — d'une demi-case alors, 0,1 depuis le point 3) :
    plus AUCUNE fente aux joints, là où la même capture en ouvrait une à chacun avant ce point.
  - Gardé par `fumee_appli` (203 au point 2, +10 : un sommet de bord de la paroi mené au CLAVIER — G, un axe, 0.1,
    Entrée). ⚠ **L'attendu est hors de `sections.gd`** : les VRAIS joints du témoin restent fermés ; 23 autres
    tuiles suivent ; le long de la normale le sommet ne bouge pas ; un Ctrl+Z rend les 52 tuiles, Ctrl+Y le
    refait ; Échap rend tout. **Cinq mutations rouges** (sans contrainte ni propagation, sans projection, les
    autres tuiles qui ne suivent pas, Échap qui ne les rend pas, une annulation pour la seule tuile en
    édition) — et les six du cœur rejouées après l'optimisation, plus une nouvelle (traiter un point pour
    toute la classe), toutes rouges.
  - ⚠ **PAS TENU EN MAIN.**
- **POINT 3, ÉCRIT — LES COUPES SUR LES BORDS** (`Sections.completer`, appelée par le modeleur après un **loop
  cut** et un **couteau**). Une coupe qui pose un sommet sur un bord laisse, dans chaque autre face de sa classe,
  un point absent : la complétion prend l'ORBITE de chaque point canonique (le groupe de symétries de la classe),
  et pour chaque nœud qui ne l'a pas, le ramène dans le repère de la tuile (l'INVERSE de sa carte), trouve
  l'arête de bord qui le contient et l'y insère. Chaque tuile coupée est sauvée AVANT d'être touchée : la
  coupe et ses reports font UN `TL.Lot`, un Ctrl+Z. Un point sans arête qui le porte est un ÉCHEC compté et
  DIT à l'écran, jamais inventé.
  - **MESURÉ** (`test_sections`, 30) — attendu hors de `sections.gd` : les VRAIS joints du témoin (tout sommet
    de joint retrouve son partenaire dans le monde). Témoin complet : la complétion ne fait rien. Une coupe
    simulée sur la paroi laisse **244** sommets de joint sans partenaire (contrôle), complétée : **29 coupes dans
    24 tuiles, 0 échec, 0 sans partenaire** ; dans une classe SYMÉTRIQUE : 31 → 0, 47 coupes dans 14 tuiles ;
    le sommet neuf, déplacé puis propagé, ne rouvre aucun joint ; un vrai loop cut à travers un bord : 57 coupes
    reportées. Dans l'appli (`fumee_appli` 211) : Ctrl+R et K sur un bord de la paroi reportés dans les autres
    tuiles, joints appariés, UN Ctrl+Z défait la coupe dans les 52 tuiles, Ctrl+Y la refait.
  - **Mutations rouges** : orbite oubliée (seuls les points canoniques), carte au lieu de son inverse, le
    modeleur qui ne complète pas, les tuiles coupées non sauvées, et l'instrument lui-même (absences toujours
    nulles : les contrôles rougissent).
  - ⚠ **[RÉGLÉ LE 1er OCTOBRE 2026 : tout geste topologique passe par `_completer_apres` — voir « LES GESTES
    TOPOLOGIQUES ROMPAIENT LES SECTIONS PARTAGÉES »]** **PAS COUVERTS** : E, I, Ctrl+B et la subdivision SUR un bord (ils posent des sommets de bord neufs sans
    les reporter) — `verifier_sections` le dira au tranchage. Un sommet inséré dans une face à plus de quatre
    côtés la laisse pentagone, sans la fendre.
  - **Vu à l'image** (`capture_modeleur_lie.gd`) : paroi tirée, loop cut à travers un bord, boucle tirée — pas
    une fente. La capture compte désormais les pixels sombres enclavés dont le premier triangle est vu de DOS.
  - ⚠ **CE COMPTEUR A TROUVÉ UNE LIMITE, PAS UN DÉFAUT** : avec la paroi tirée d'une DEMI-case et la boucle d'un
    quart, des faces d'AUTRES tuiles se REPLIENT (normale nulle) et le fond passe au travers. Le déplacement
    propagé est juste — c'est le même vecteur dans la section partagée —, mais une tuile voisine n'a pas la
    place : dans `mb_equerre_b2h1_a`, le point reporté au milieu d'une arête de 0,25, poussé de 0,25, dépasse
    son bout. Avec des tirages dans la marge (0,1), zéro tache.
  - **DÉCIDÉ (Jordan, 30 septembre 2026) — (a), LA BRIDE : un geste s'arrête à la plus grande amplitude qui ne
    replie AUCUNE face, dans AUCUNE tuile** (les autres réponses étaient : le laisser faire et le dire, ou rien,
    comme Blender). ÉCRIT LE MÊME JOUR :
    - **le critère vit dans le cœur** (`MaillageEdite.gardes_de_repli` / `replie`) : au début du geste, pour
      chaque face qui PEUT bouger — dans la tuile en édition et dans chaque tuile que la propagation-sonde
      atteint —, ses triangles de départ (ceux que `trianguler` dessine) et sa normale ; la face est repliée dès
      qu'un triangle s'ÉCRASE ou se retourne (aire orientée ≤ 10⁻⁷). ⚠ Une face déjà écrasée au départ n'est pas
      gardée : on ne bride pas un geste pour ce qu'il n'a pas fait ;
    - **le modeleur parcourt le geste** : G, R et S sont des FAMILLES de transformations paramétrées par leur
      amplitude s (déplacement, angle, écart d'échelle) ; si s = 1 replie, on avance par pas de 1/8 jusqu'au
      premier qui replie, puis huit dichotomies ; le geste s'arrête au dernier point sain (`bride`, et le
      rapport dit « stopped at N% »). C'est le PREMIER repli le long du geste ; un repli qui naîtrait et
      disparaîtrait dans un même huitième peut échapper ;
    - ⚠ **LA TUILE QU'ON ÉDITE EST BRIDÉE AUSSI** (« dans aucune tuile ») : un S négatif (miroir) ou une face
      poussée à travers sa voisine s'arrêtent. Deux vérifications de la fumée tiraient d'une et deux cases — elles
      REPLIAIENT (mesuré hors du code éprouvé : un triangle de `mb_coin_b0h1` écrasé à 4·10⁻⁶ de son aire) ; elles
      éprouvent le SENS des axes et passent à 0,1 ;
    - ⚠ rappelé en plein geste (la molette du proportionnel), la préparation repart des positions de départ,
      tuiles entraînées comprises : sinon ses gardes seraient prises sur un état déplacé, et une tuile sortie du
      lot resterait déplacée (défaut du point 2, vu en écrivant ceci, pas gardé par un test).
  - **MESURÉ** : `test_maillage_edite` (160, +7 : le cube, attendus écrits à la main — à 0,5 sain, à 0,001 sain,
    à 0 écrasé, à −0,5 retourné, deux faces écrasées au départ non gardées) ; `fumee_appli` (223, +12 : les faces
    ±Z de la paroi glissées de côté au clavier ; à 0,1 rien n'est bridé ; à 0,5 le geste s'arrête à **0,2498**
    case ; aucune face repliée dans aucune tuile ; joints fermés ; un Ctrl+Z rend tout. Attendu hors du code
    éprouvé : éventail et normales de départ recalculés dans la fumée).
  - ⚠ **« LA BRIDE NE GARDE QUE LA TUILE EN ÉDITION » ÉTAIT MUETTE, ET C'ÉTAIT LE TEST** : la dalle de la paroi
    s'écrase EN MÊME TEMPS que ses voisines (même marge d'un quart de case partout), donc garder la seule tuile en
    édition l'arrêtait aussi. Il fallait un geste qu'une AUTRE tuile arrête seule : `sonde_bride_ailleurs.gd` en
    trouve **46** (un sommet de bord, un axe de son plan) ; la fumée rejoue le plus net — le sommet 3 de
    `mb_vrille_d_b3h1_dehors` vers −X de la tuile, qui ne replie jamais, quand `mb_coin_b1h0` replie à 0,25 — et
    REVÉRIFIE sa condition (bridé à 0,625 du geste, la tuile en édition garde toute son aire). **Vu à l'image** (`capture_modeleur_lie.gd`, avec fenêtre) :
    0 pixel vu à travers une face de dos, sur les quatre photos, dont celle du geste bridé.
  - **COÛT MESURÉ** (avec fenêtre) : un mouvement non bridé ~11 ms (9,1 avant) ; un mouvement que la bride doit
    chercher **~50 ms** (une quinzaine d'essais à ~3 ms) — à juger souris en main.
  - **Mutations rouges** : un triangle écrasé qui ne compte pas comme repli, les faces écrasées au départ gardées,
    pas de bride, la bride qui ne garde que la tuile en édition (après la sonde), la bride qui rend le premier
    point qui replie. ⚠ Le rappel en plein geste (molette) et le pas régulier avant la dichotomie n'ont pas de garde.
  - ⚠ **PAS TENU EN MAIN.**
  - ⚠ **PAS TENU EN MAIN.**

### UN TÉMOIN PAR COUCHE, ET LA LISTE DES COUCHES DANS LES DEUX ATELIERS — DÉCIDÉ (Jordan, 30 septembre 2026), ÉCRIT

Jordan : « un layer devrait conserver son witness pour pouvoir le retrouver et le remodifier », et « il faut
un moyen d'afficher et de choisir ces témoins / couches, car elles vont ensemble ».

- ⚠ **LE DÉFAUT QUI LE JUSTIFIAIT** : le témoin modélisé était UN par PROJET (`<projet>_witness.glb`). Le
  remodeler pour une couche changeait la source d'une autre, retranchée EN SILENCE au chargement suivant
  (« source changée, on retranche »). Gardé : remodeler B laisse les OCTETS du `.glb` de A intacts — ⚠ **SAUF SUR UN BORD
  depuis le 6 octobre 2026** : les couches partagent leurs bords (« les bords partagés entre couches », plus bas).
- **UNE COUCHE = UN TÉMOIN + UN MONDE PEINT.** `projet.gd` : chaque couche a un `id` STABLE (il nomme ses
  fichiers, jamais son nom) et `temoin`, le chemin de SON `.mbtiles` ; son `.glb` lié est à côté
  (`<projet>_layer<id>.*`). Un projet d'avant se relit (ni `id` ni `temoin`), et son témoin unique
  (`<projet>_witness.mbtiles`) est CONFIÉ à la couche qui le tranchait, sinon à l'active — désigné, ni
  copié ni écrasé, et le rapport le dit.
- **Le témoin se charge à la demande** (`_temoin_de`) : son `.mbtiles` ; sinon le `.glb` lié qu'on lui a
  tranché ; sinon une COPIE du témoin calculé. ⚠ **PAS DE MÉTA « couche » SUR LE TÉMOIN** : la couche garde
  son témoin, et l'inverse faisait un CYCLE jamais libéré (vu en fuite à la sortie de la fumée : 58 objets,
  matériaux et textures) — on retrouve la couche d'un témoin en cherchant dans la liste.
- **Witness édite le témoin de la couche active, et le dit** (« Witness of layer « Rock » — modelled »).
  Changer de couche change le témoin en édition (geste en cours abandonné, témoins modifiés écrits d'abord)
  et la planche des tuiles. ⚠ **L'ANNULATION VISE LE TÉMOIN D'OÙ VIENT LE GESTE** : un Ctrl+Z après avoir
  changé de couche défait le geste dans SON témoin et l'écrit, sans toucher l'édition en cours.
- **La liste des couches est dans Witness ET World** : vignette de son témoin (photographiée une fois,
  reprise à chaque enregistrement), origine (computed witness · modelled · from Blender (linked) · unlinked
  work), état (cases · not sliced / sliced / witness changed · slice again / tiles from <fichier>) —
  l'empreinte du lot POSÉ contre celle du fichier, sans relire le cache du disque. « New layer » (témoin
  calculé), « Copy witness » (copie du témoin de l'active, sans cases), « Delete layer ».
- **L'aller-retour** : l'étape 1 exporte le témoin de la couche active ; l'étape 3 « Slice this layer's
  witness » ; un `.glb` LIÉ tranché dans une couche DEVIENT son témoin (l'ancien gardé en `.previous`), et
  un travail non lié reste une simple source. Le témoin modélisé n'entre plus dans la liste des travaux.
- **UN TÉMOIN RELU DE BLENDER GARDE SA PEINTURE** (`TemoinLie.depuis_glb`, `MaillageEdite.depuis(…,
  materiau_de)`) : chaque matériau devient UNE entrée partagée, avec ses UV ; son image est écrite en PNG ;
  les teintes de la légende redeviennent des teintes — celles de l'export (nommées) comme celle du modeleur
  (UN matériau « legend », teintes en couleur de sommet : lu comme un vrai matériau, il peignait TOUTE la
  légende en blanc, vu rougir). ⚠ Un matériau qu'aucune face ne porte ne voyage pas (pas de primitive).
- **LE MONDE SUIT SON TÉMOIN (Jordan, 1er octobre 2026 : « le monde ne se met pas à jour avec les changements
  de son witness »)** : chaque écriture du témoin d'une couche (une seconde après le dernier geste) la rhabille
  par `librairie_depuis_glb` sur son `.glb` lié — la route du tranchage, qui ne coûte que la relecture.
  **MESURÉ** sur le monde de test (4 635 cases) : 114 ms d'écriture, 217 de relecture, 83 de reconstruction.
  Une couche sans tuiles ou sur le témoin calculé passe à son témoin ; une couche habillée par un travail
  EXTERNE non lié le garde. L'étape 3 « Slice this layer's witness » fait la même chose à la demande.
  Gardé par `fumee_appli` (la paroi posée dans le monde EST celle du témoin, au millième ; Ctrl+Z suivi ; le
  monde de A intact ; le travail externe gardé) ; deux mutations rouges.
- **LE MONDE S'ÉCLAIRE COMME LE MODELEUR (Jordan, 1er octobre 2026 : « les matériaux du monde se mettent parfois
  mal à jour dans certaines tuiles, sur les lèvres, pas le même shading »).** `DEV_TOOLS/sonde_ombrage_monde.gd`
  compare, tuile par tuile, ce que dessine le modeleur et ce que pose le monde (relu du `.glb`). Sur son témoin :
  ⚠ **TROIS DÉFAUTS RÉELS, TOUS CORRIGÉS** —
  - la COULEUR DE SOMMET était écrite sur toutes les surfaces : en COLOR_0 sur chaque primitive, l'import faisait
    multiplier les matériaux de l'artiste par la teinte de la légende, et rendait la légende SANS ce drapeau
    (blanche). Écrite sur la seule légende ; à la relecture, la légende le retrouve et les autres le perdent
    (`_rendre_la_legende` : dans le modeleur, seule la légende lit la couleur de sommet) ;
  - chaque tuile avait SON cache de matériaux Godot : un matériau du témoin partait en une copie par tuile
    (« Green », « Green2 »…). Un cache commun au témoin (`_partager`) ;
  - ⚠ **`ImporterMesh.get_mesh()` FAUSSE LES NORMALES** — mesuré : (0,008 ; 1 ; 0,008), juste dans le fichier
    ET dans les tableaux de l'ImporterMesh, en ressortait (0,008 ; 0,97 ; 0,241), 14° de travers, sur des faces
    sculptées. `_en_array_mesh` bâtit le maillage depuis les tableaux ; ça vaut aussi pour un travail de Blender.
    Et le `.glb` du monde porte les normales du modeleur (une par FACE) : recalculées par triangle, une face
    non plane s'éclairait autrement.
  - En route : le témoin modélisé partait vers Blender en SOUPE de triangles (insculptable) ; `vers_glb(…,
    pour_blender)` l'écrit soudé, sans normales.
  Sonde après correction : 0 matériau, 0 normale différents sur les 52 tuiles. Gardé par `test_temoin_lie` (31 :
  témoin construit, un sommet relevé de 4 millièmes) ; quatre mutations rouges, dont `get_mesh()` remis. ⚠ La
  couleur de sommet réécrite partout est une mutation ÉQUIVALENTE pour l'éclairage (le drapeau forcé la neutralise).
- **LES LAGS D'UNE SECONDE — MESURÉS ET CORRIGÉS (Jordan, 1er octobre 2026 : « des lags d'environ 1 seconde à des
  moments différents, en édition de maillage, sélection, assignation de matériaux »).** `DEV_TOOLS/sonde_lags_appli.gd`
  (AVEC fenêtre, projet jetable) chronomètre chaque image après chaque geste. ⚠ **LES GESTES N'Y ÉTAIENT POUR RIEN**
  (3 à 30 ms) : c'était **L'ENREGISTREMENT DIFFÉRÉ**, une seconde après le dernier geste — d'où « à des moments
  différents » —, qui **gelait l'appli 3,6 s**. Trois causes :
  - ⚠ **AVEC UNE CARTE GRAPHIQUE, RELIRE UN `ArrayMesh` LE REDESCEND DU GPU, ET EN FABRIQUER UN L'Y RENVOIE.** En
    headless tout reste en mémoire : les sondes headless ne le voyaient pas (`assemble` 40 ms headless, **4,6 s**
    avec fenêtre). `_tous_les_maillages` relisait, refabriquait et relisait le maillage de CHACUN des 1 056 nœuds
    pour 52 maillages ; `append_from_scene` convertissait chaque nœud (1,1 s) ; `tuiles_liees` et
    `verifier_sections` relisaient trois fois chaque tuile qu'ils venaient de fabriquer (0,9 s). Désormais : une
    lecture par maillage distinct, la pose sur les TABLEAUX (`_tableaux_poses`), un maillage par clé dans la scène
    exportée, et les tableaux passés au contrôle des sections. ⚠ **UN `Packed*Array` SE PASSE PAR RÉFÉRENCE** :
    le premier jet transformait en place les tableaux en cache — `test_blocs_maitres` §17 et `test_temoin_lie` ont
    rougi, ils gardent ce refactor.
  - ⚠ **LE .glb ET LE MONDE ATTENDENT QU'ON LES REGARDE** : l'enregistrement différé n'écrit plus que le
    `.mbtiles` (ce qui fait foi, 10 ms) ; la couche est marquée `_glb_perime`, et `_rhabiller` réécrit son `.glb`
    et rhabille son monde quand on passe dans World ou Play test, avant un export, un tranchage, à Ctrl+S, au
    changement de projet et à la FERMETURE — qui n'écrivait RIEN : fermer moins d'une seconde après un geste le
    perdait. La liste dit « follows its witness when you open World ».
  - La vignette : une image de 2,2 s à son premier rendu (compilation des shaders), une fois par session.
  **Mesuré après, avec fenêtre** : enregistrement différé **61 ms** (3 638 avant) ; le monde suit en ~0,35 s au
  passage dans World. Gardé par `fumee_appli` (l'enregistrement différé ne touche ni le `.glb` ni le monde, le
  geste est sur disque, la liste le dit, World rhabille) ; deux mutations rouges.
- **LES GESTES TOPOLOGIQUES ROMPAIENT LES SECTIONS PARTAGÉES — MESURÉ ET CORRIGÉ (Jordan, 1er octobre 2026 : « la
  subdivision sans qu'elle ne subdivise aussi ses voisines ne rompt-elle pas les sections partagées et fait des
  trous ? »)**. Oui : seuls le loop cut et le couteau reportaient leurs points de bord (`Sections.completer`).
  `DEV_TOOLS/sonde_operations_et_sections.gd` compte les absences après chaque geste sur une face de bord de la
  paroi : subdiviser 54, biseauter une arête qui touche le bord 51, fusionner 32 — un point droit sur l'arête d'en
  face tant qu'il ne bouge pas (une jonction en T), une fente dès qu'il bouge. **Le report les répare tous** (0
  échec ; fusion : 30 sur 32). Tout geste topologique passe donc par `_completer_apres` (X, M, F, subdiviser, E, I,
  Ctrl+B ; ~60 ms). ⚠ **CE QU'AUCUN REPORT NE RÉPARE** : extruder ou supprimer une face de bord change la FORME de
  la section (108 et 2 échecs) — les tuiles d'en face n'ont pas cette forme. L'écran le DIT (« changed the shape of
  a tile border… the world will show a gap there »), on ne comble pas (§3). Gardé par `fumee_appli` (subdiviser une
  face de bord par le vrai bouton : 0 sommet de joint sans partenaire, UN Ctrl+Z ; supprimer : le message) ; deux
  mutations rouges (488 sommets sans partenaire sans le report).
- **L'ÉCLAIRAGE — SSAO + SSIL, AMBIANTE 1,1 (Jordan, 1er octobre 2026 : « une lumière ambiante afin que tout soit
  au moins légèrement visible, voire du SDFGI pour le witness […] afin de bien voir les reliefs », puis « en mode
  World aussi, on n'y voit rien »).** Jugé à l'image (`DEV_TOOLS/capture_eclairage.gd`, Witness et World) : les
  faces à l'ombre s'éclaircissent, les creux prennent une ombre douce, le relief se lit. ⚠ **LE SDFGI A ÉTÉ ESSAYÉ ET
  ÉCARTÉ, MESURÉ** : il ne voit PAS une géométrie modifiée (une dalle émissive posée après coup ne teinte rien ; le
  contrôle — l'éteindre et le rallumer — la fait rougir partout) ; et le reconstruire après chaque geste NOIRCIT les
  ombres ~45 images (0,75 s, écart moyen 137 à l'image 0). À ×1 il assombrit même les faces à l'ombre (le fond est
  presque noir). ⚠ L'ambiante seule à 1,5 aplatit le relief. ⚠ Rien n'a été vu sur le monde texturé de Jordan.
  **REPRIS LE MÊME JOUR, après les retours de Jordan :**
  - « la lumière était bonne, c'était le MÉTALLIQUE sur les parois marron qui est trop fort » — ses matériaux du
    modeleur portent du métal (`Material 2`, le marron : 0,57 ; `Material 3` : 1,0). ⚠ **UN MÉTAL REFLÈTE, IL NE
    DIFFUSE PAS** : il reflétait le fond presque noir et tombait au noir à l'ombre. Les reflets viennent désormais
    d'un CIEL NEUTRE de la teinte de l'ambiante (`reflected_light_source = SKY`), le fond reste uni. Vu à l'image :
    un pavé marron à métal 0,57 s'éclaire comme son jumeau mat. (Un essai d'ombre portée adoucie a été RETIRÉ.)
  - « le SSAO n'est visible qu'à l'ombre, car aucun mode smooth normals » — ⚠ **CE N'ÉTAIT PAS LES NORMALES** :
    Godot n'applique l'occlusion qu'à l'AMBIANTE par défaut (`ssao_light_affect` = 0), qui ne pèse presque rien au
    soleil. `ssao_light_affect` 0,6, intensité 2,5. Lisser les normales arrondirait les arêtes vives sans rien y
    changer.
  - **LE CIEL DU PLAY TEST** : un `ProceduralSkyMaterial` bleu-violet en haut (`#2e1a6e`), turquoise tirant sur le
    bleu-violet à l'horizon (`#3c86b4`), un sol de ciel qui garde la teinte de l'horizon et ne s'assombrit que bas
    (`ground_curve` 0,6). Montré EN JEU seulement (`background_mode`), où il sert aussi aux reflets ; l'ambiante
    reste sa couleur. Vu à l'image (`capture_eclairage.gd`, personnage posé sur le plateau).
  - **LE MODE D'EMPLOI DIT COMMENT OBTENIR LE MÊME RENDU (Jordan : « il faudra le tenir à jour […] fais la liste »)** :
    la page 6 du manuel, « The same look in your engine » — normales par face (les importer, ne pas lisser),
    soleil, ambiante, SSAO et son effet sur la lumière directe, SSIL, reflets, ciel du Play test, MSAA, et ce qui
    est écarté exprès (SDFGI, lightmaps). ⚠ **UNE SEULE SOURCE** : les valeurs sont des constantes de `vue.gd`
    (`SOLEIL_ENERGIE`, `AMBIANTE_COULEUR`…), que la vue applique et que la page cite. Gardé par `fumee_appli` :
    l'attendu est lu sur l'environnement et le soleil POSÉS dans la vue ; une vue qui n'applique plus une valeur
    rougit (mutation : `ssao_light_affect` à 0).
  - **LA BANDE DU BAS (Jordan : « afin qu'on ne confonde pas les défilements qui filent sous leur limite avec un
    logiciel qui dépasse de l'écran »)** : 8 px, teinte de la barre de titre, filet en haut ; les deux panneaux
    s'arrêtent au-dessus. Gardé par `fumee_appli` (rectangles posés), une mutation rouge, vu à l'image.
- Gardé par `test_projet` (35), `test_temoin_lie` (25) et `fumee_appli` (249). **Neuf mutations rouges** ;
  C7 (« le chemin enregistré ignoré ») d'abord MUETTE : pour une couche ordinaire le chemin enregistré et
  celui de l'id sont les mêmes, et le test ne relisait pas l'ancien témoin repris — ni n'y écrivait. Vu à
  l'image (`capture_modeleur_lie.gd`). ⚠ Pas tenu en main par Jordan.

### LES BORDS PARTAGÉS ENTRE COUCHES — DEMANDÉ PAR JORDAN (6 octobre 2026), ÉCRIT LE MÊME JOUR

Jordan, en discutant d'un atelier de transitions : « pas la peine de sonder, il y a des fentes, je les ai vues, fais comme
tu as dit pour les éviter ». Les sections partagées (§3) tenaient étanche UN témoin ; depuis les couches exclusives (§5),
une tuile de la couche A touche une tuile de la couche B, venue d'un AUTRE témoin — et rien n'obligeait leurs bords à
coïncider. Sculpter les bords d'une couche ouvrait une fente à chaque frontière avec les autres.

- **LES CLASSES NE DÉPENDENT QUE DU MODÈLE, ELLES VALENT POUR TOUS LES TÉMOINS** : `Sections.new(temoin, autres)` indexe
  les tuiles des autres témoins sous un nom PRÉFIXÉ « @<j>/<tuile> » (`cles`, `tuile`, `temoin_de`, `nom_de`) ; celles
  du témoin édité gardent leur nom nu. Propager, compléter (les coupes sur un bord), `manquants` (Fill holes) et
  `absences` passent donc par tous les témoins sans autre changement.
- **LE MODELEUR** reçoit les témoins des AUTRES couches (`regler_les_autres_temoins`, donné par l'écran à l'entrée en
  édition, au changement de couche, à l'import d'un témoin lié — `_donner_les_autres_temoins`) : tirer un bord (G R S,
  proportionnel, sculpt) les entraîne, une coupe sur un bord (Ctrl+R, K, subdiviser, Fill holes…) y est reportée. Ils ne
  sont pas dessinés. ⚠ **UNE COUCHE HABILLÉE PAR UN TRAVAIL EXTERNE NON LIÉ N'EN EST PAS** (`_suit_son_temoin`) : ses
  tuiles ne viennent pas de son témoin.
- **L'ANNULATION** : `TL.Lot.ailleurs` = {témoin : {tuile : copie}} ; l'écran pose chaque part dans SON témoin
  (`_remplacer_temoin`), y compris quand le témoin entraîné est devenu celui qu'on édite (on a changé de couche), et
  marque chacun à réécrire. Leur monde suit à l'entrée dans World (`_glb_perime`), comme pour la couche active.
- **CE QUI DIVERGE DÉJÀ** (un projet d'avant, un témoin revenu de Blender, une couche neuve sur le témoin calculé quand
  l'active est sculptée) : la section Mesh de Geometry compte les points de bord qui manquent quelque part
  (`Sections.absences` sur tous les témoins, relu au plus une fois par seconde après un changement), et **Match other layers
  to this one** les cale (`Sections.conformer`, repris de `_conformer` de `DEV_TOOLS/reparer_temoins.gd`) : dans chaque
  classe, la section du témoin ÉDITÉ fait foi ; chaque point manquant prend l'intrus le plus proche (jusqu'à 0,1 case),
  les autres intrus glissent sur la section de référence, un manquant restant est inséré sur l'arête de bord la plus
  proche ; puis la complétion reporte l'orbite. UNE annulation. Ce qui ne se cale pas (`sur_arete`, `non_inseres`,
  `restants`) et les faces repliées sont DITS.
  - ⚠ **LES DÉPLACEMENTS D'ABORD, LES INSERTIONS ENSUITE** : une garde de repli désigne ses triangles par leur rang dans la
    face ; un point inséré les décale, et la garde criait au repli sur une face intacte (5 « replis » qu'aucun triangle
    retourné ne confirmait).
  - ⚠ **UN POINT REPORTÉ VA À LA POSITION EXACTE DE CELUI QUI FAIT FOI, PAS AU CRAN DE L'INDEX** (`Sections.exacts`) : un
    sommet sculpté est entre deux crans du dix-millième ; son report posé au cran en était à 7·10⁻⁵, et la frontière ne
    coïncidait plus (8 sommets, puis 244 avec une coupe posée entre deux crans). ⚠ **ÇA VALAIT AUSSI DANS UN SEUL TÉMOIN** :
    la complétion posait au cran le report d'une coupe sculptée — invisible aux tests, dont les coupes tombaient au milieu
    d'arêtes du témoin calculé.
  - ⚠ Un sommet posé sur une ARÊTE de case n'est déplacé que si sa cible reste sur ses deux plans.
- ⚠ **CE QUE ÇA RETIRE** : remodeler B ne laisse plus A intact quand le geste touche un BORD — c'est le but. La garde
  d'avant (`_les_couches_et_leurs_temoins` : « le témoin de A n'a PAS bougé ») porte désormais sur une face du DEDANS.
- **MESURÉ** : `test_sections` 51 (+12). L'AUTORITÉ NE PASSE PAS PAR `sections.gd` : `_sans_partenaire_entre(A, B)` pose les
  occurrences des deux témoins et compte, à chaque joint, les sommets d'une tuile de A sans partenaire À MOINS DE 10⁻⁵
  dans la tuile de B d'en face, et l'inverse. Contrôle : un bord de A tiré dans A seul (l'appli d'avant) — A étanche, la
  frontière ouverte. Propagé à travers les témoins : B suit, frontière fermée. Une coupe sur un bord de A, posée entre
  deux crans : reportée dans B. Deux témoins divergents (A : douze bords tirés ; B : une coupe dans une classe symétrique)
  calés sur A : frontière fermée, A et B étanches, aucun sommet de A déplacé, rien de laissé, aucun repli, une seconde
  passe ne fait rien. `fumee_appli` (+16, une SENTINELLE) : une couche neuve, une divergence construite dans le témoin de
  B, la ligne qui la dit, le VRAI bouton, Ctrl+Z / Ctrl+Y ; G au clavier sur un bord de A — les tuiles de B suivent, la
  frontière reste fermée, Ctrl+Z les rend ; un Ctrl+Z APRÈS être passé sur B (le témoin entraîné est devenu celui qu'on
  édite).
- **MUTATIONS, TOUTES ROUGES** (rejouées dans une copie à dossier de données isolé) : le cœur 4 — les autres témoins
  ignorés, la référence prise à la majorité de tous (A bouge : 50 tuiles), la cible appariée au cran, le report au cran ;
  l'écran 4 — le lot qui range tout dans le témoin édité (les tuiles « @1/… » posées DANS A), l'écran qui ignore
  `ailleurs`, le modeleur sans les autres témoins, le bouton débranché. ⚠ **« LE REPORT AU CRAN » D'ABORD MUETTE, PAR LE
  TEST** : l'autorité arrondissait au dix-millième (deux points à 3·10⁻⁵ tombent souvent dans le même cran) et la coupe
  tombait juste — un partenaire à moins de 10⁻⁵, une coupe à 0,47 cran, et elle rougit. ⚠ **DEUX ÉQUIVALENTES, RETIRÉES
  DU CODE** : glisser un intrus au cran de l'index (la position exacte rend le cran inutile) ; redonner les autres témoins
  quand la couche active ne change pas (aucun chemin de l'appli ne change la liste des couches sans changer l'active).
- **SUITES** (6 octobre 2026, 22 suites, 0 échec) : `test_sections` 51, `fumee_appli` 843, `test_greffon_peinture` 282, les
  autres inchangées.
- **LE COÛT, MESURÉ** (headless, témoin calculé) : indexer 27 ms pour un témoin, 56 pour deux, 85 pour trois (au début
  de chaque geste, et deux fois dans une complétion) ; `absences` 44 / 104 / 167 ms — d'où la ligne de Geometry relue
  seulement à l'entrée, au changement de couche, après « Match » et après une annulation qui touche d'autres couches,
  jamais après chaque geste ; propager 0,2 / 0,4 / 0,6 ms. ⚠ Pas mesuré sur des témoins sculptés (plus de sommets).
- ⚠ **PAS TENU EN MAIN, NI VU À L'IMAGE.** Les greffons n'ont rien à porter (c'est le modeleur, dans l'appli seule).
- **LA SUITE PROPOSÉE (6 octobre 2026) : UN ATELIER « TRANSITIONS »** — discuté avec Jordan avant ceci ; **DÉCIDÉ ET ÉCRIT LE
  MÊME JOUR** (Jordan : « go pour l'atelier transitions ») : voir §5, « L'atelier Transitions ». Le texte qui suit est la
  proposition d'alors.
  Des tuiles de transition SCULPTÉES sont hors de portée (deux couches dans un sommet : Σ C(8,k)(2ᵏ − 2) = 6 050
  configurations, au moins 1 513 classes sous les quarts de tour) ; la transition porterait sur le MATÉRIAU, la géométrie
  restant celle de la couche qui pose le sommet. Une PAIRE non ordonnée par couple de couches, mais DEUX RÉGLAGES (Jordan :
  « un désert qui empiète sur la roche n'est pas la même chose qu'une roche qui empiète sur le désert ») — A sur B, B sur
  A, chacun ses matériaux représentants (projection boîte : un UV déplié ne se transporte pas sur une autre géométrie),
  largeur, bruit, mélange par hauteur ; la priorité décide lequel par défaut, un pinceau de transition le choisit par
  sommet (comme les choix de variantes). Le poids d'un sommet du maillage : l'interpolation trilinéaire des 8
  appartenances, en temps constant. ⚠ Un shader ne voyage pas : à porter dans les trois greffons (la liste, §0).
  **OUVERT** : un sommet à trois couches.

### L'ENREGISTREMENT QUI SE DIT, ET LES FICHIERS DANS WINDOWS — DÉCIDÉ (Jordan, 30 septembre 2026), ÉCRIT

- **« Si les enregistrements sont automatiques, il faut le dire au client. »** La barre de titre porte un
  témoin : « ✓ Saved », « ● Saving… » (la seconde où un geste du modeleur attend d'être écrit), « ⚠ Not
  saved » ; sa bulle explique qu'il ne faut pas de Ctrl+S. ⚠ **CTRL+S RÉPOND** : muet, il faisait croire au
  client qu'il n'avait rien enregistré ; il écrit ce qui attendait et le DIT. Le rapport d'ouverture le
  rappelle. Gardé par `fumee_appli` (deux mutations rouges).
- **LA FERMETURE PROPRE — DEUX DÉFAUTS MESURÉS ET CORRIGÉS (2 octobre 2026)**, trouvés par une sonde qui ferme
  l'appli juste après un geste (`WM_CLOSE_REQUEST` propagé, avec fenêtre sous Xvfb) :
  - **« Unable to start the timer because it's not inside the scene tree » À CHAQUE FERMETURE** : libérer
    l'historique (`NOTIFICATION_PREDELETE`, l'écran déjà hors de l'arbre) émet `version_changed`, et
    `_enregistrer_plus_tard` relançait la minuterie du projet. Il ne relance plus rien hors de l'arbre (la fermeture
    a déjà tout écrit). Gardé par `fumee_appli` (548 : l'écran retiré de l'arbre, un changement d'historique — la
    barre reste à « ✓ Saved ») ; mutation rouge. ⚠ **D'ABORD MUETTE** : la garde lisait « la minuterie reste
    arrêtée », or hors de l'arbre `Timer.start()` ÉCHOUE sans démarrer — l'erreur sort, la minuterie reste arrêtée.
  - **52 `Node3D` ORPHELINS À CHAQUE ÉCRITURE DU TÉMOIN LIÉ** (`BlocsMaitres.ecrire_le_temoin_lie`) : un nœud créé
    puis REMPLACÉ par un `MeshInstance3D` pour la première copie de chaque clé — jamais libéré. Gardé par
    `test_temoin_lie` (32, +1 : le compteur d'orphelins du moteur inchangé par une écriture) ; mutation rouge
    (4 225 → 5 281).
- **LES FICHIERS DANS WINDOWS** (« au premier lancement, double-clic oui, dossiers aussi ») — `app/associations.gd` :
  icônes de `.mbproj` (et le double-clic qui l'ouvre), `.mbtiles`, et des DOSSIERS `.mbset/` / `.mbworld/`
  (un `desktop.ini` posé à l'export). Dessinées depuis l'emblème par `MARQUE/generer_icones_fichiers.py`
  (une seule source), converties en `.ico` (PNG dedans) dans les données de l'appli.
  - ⚠ **UNE ICÔNE DE FICHIER VIENT DU REGISTRE, PAS DU FICHIER** : sans installateur, l'appli s'inscrit
    elle-même, dans HKEY_CURRENT_USER SEULEMENT (ni administrateur, ni autres comptes), par un `.reg` en
    UTF-16 importé par `reg import` (des arguments de `reg add` auraient livré guillemets et « %1 » à la
    citation de la ligne de commande ; un chemin accentué exige l'Unicode). Au premier lancement, puis si
    l'exe change de place ou de version ; jamais après un refus (la case « File icons & double-click » de
    Project, qui retire tout et s'en souvient).
  - ⚠ **JAMAIS DEPUIS L'ÉDITEUR NI LES TESTS** (`OS.has_feature("template")`) : c'est l'exécutable de Godot
    qui ouvrirait alors les projets. Vérifié : 16 suites passées, la clé `.mbproj` absente du registre.
  - Le double-clic : `projet_en_argument` — un `.mbproj` qui EXISTE, passé au lancement, l'emporte sur le
    dernier projet ouvert.
  - Gardé par `test_projet` (+14 : le `.ico` relu octet par octet, le `.reg` lu tel qu'écrit — partie
    utilisateur seule, échappements, accents —, le `desktop.ini`, l'argument, la décision de s'inscrire).
    Cinq mutations rouges.
  - **ÉPROUVÉ DANS L'EXE CHIFFRÉ (1er octobre 2026)** — reconstruit par `exporter_marchingblocks.sh` (journal
    sans erreur, 0 chaîne témoin sur 7 en clair), lancé UNE fois sur `test.mbproj`, aucun geste, refermé par
    WM_CLOSE (2 s) :
    - **le registre** : avant, aucune clé ; après, dans HKCU et dans la vue fusionnée HKEY_CLASSES_ROOT (celle
      de l'Explorateur), `.mbproj` → `MarchingBlocks.Project`, `.mbtiles` → `MarchingBlocks.Witness`, leurs
      `DefaultIcon` sur les `.ico` écrits dans `…/app_userdata/MarchingBlocks/icones/`, la commande
      `"D:\MarchingBlocks\build\MarchingBlocks.exe" "%1"` ; rien dans HKLM ; `reglages.cfg` retient exe et
      version. ⚠ `assoc` et `ftype` disent « introuvable » : ils ne lisent que HKLM — ce n'est pas un défaut.
      ⚠ Et une lecture par Git Bash avec `//ve` rendait « introuvable » sur des clés présentes : contre-vérifié
      par PowerShell avant de conclure.
    - ⚠ **L'OUVERTURE A RÉÉCRIT `test.mbproj` SANS GESTE** : la migration prévue (couche « Layer 1 » : `id` 1,
      `temoin` = `test_witness.mbtiles`), rien d'autre — cases et témoins identiques au bit près.
    - ⚠ **UN DÉFAUT RÉEL, VU LÀ ET NULLE PART AILLEURS : L'ICÔNE DES DOSSIERS NE POUVAIT PAS MARCHER.**
      `marquer_dossier` posait les attributs par `attrib` via `OS.execute`, qui met chaque argument entre
      guillemets ; `attrib` refuse « "+h" » (« Format incorrect du paramètre »)… en rendant 0. Le `desktop.ini`
      était écrit, rien n'était posé : sans dossier en lecture seule, Windows ne le lit pas. Corrigé par
      `FileAccess.set_hidden_attribute` / `set_read_only_attribute` (Godot ne sait pas poser « système », dont
      l'icône n'a pas besoin). Gardé par `test_projet` (+6, Windows seulement : attributs relus par `attrib`,
      re-marquage d'un `desktop.ini` caché, UTF-16, un dossier qui n'est ni `.mbset` ni `.mbworld`) ; trois
      mutations rouges (l'ancienne route `attrib`, dossier sans lecture seule, `desktop.ini` caché non
      découvert avant réécriture). La garde elle-même laissait d'abord son dossier jetable : un `FileAccess`
      resté ouvert empêchait le ménage. L'exe a été reconstruit avec la correction, PAS relancé.
  - ⚠ **RESTE À L'ŒIL DE JORDAN** : les icônes VUES dans l'Explorateur (cache d'icônes, `ie4uinit`) ; le
    double-clic sur un `.mbproj` ; l'icône d'un dossier exporté DEPUIS L'APPLI (la fonction a été menée sur des
    dossiers jetables, pas par le bouton d'export, qui demandait un geste) ; la case qui retire tout ; et, dans
    l'exe, les couches avec leur témoin et « ✓ Saved » / Ctrl+S.

- **TES FICHIERS DANS `Documents/MarchingBlocks` — DÉCIDÉ (Jordan, 4 octobre 2026 : « que l'exe crée un dossier simple
  dans Documents pour y mettre tous les fichiers qu'il crée automatiquement, pour rester propre »), ÉCRIT LE MÊME JOUR.**
  Les projets « untitled » s'empilaient en vrac dans les données de l'appli (sur le PC : `untitled 2…14`, leurs `.glb`,
  `.mbtiles`, dossiers `_images`, mêlés au cache et aux restes des suites). Choisi par Jordan entre trois portées :
  - **ce qui est À L'UTILISATEUR va dans `Documents/MarchingBlocks/`** (`app/dossiers.gd`) : chaque projet neuf DANS
    SON DOSSIER (`untitled/untitled.mbproj`, ses témoins à côté de lui), et l'exemple installé (`Example/`) ;
  - ⚠ **LE CACHE, LES RÉGLAGES, LES ICÔNES RESTENT DANS LES DONNÉES DE L'APPLI** : la convention de Windows, et Documents
    est souvent synchronisé par OneDrive (un cache de plusieurs Mo y repartirait à chaque tranchage) ;
  - ⚠ **SEULEMENT DANS L'EXE** (`OS.has_feature("template")`) : depuis l'éditeur et les suites, `user://`, comme avant ;
  - ⚠ **PAS RETENU** (le second choix proposé) : un projet enregistré AILLEURS (le `test.mbproj` du Bureau) sème
    toujours ses fichiers à côté de lui (`test_layerN.*`, `_images`) — les ranger dans un sous-dossier changerait les
    chemins enregistrés et demanderait une migration ;
  - un exemple installé à l'ancienne place (`user://example`, un exe d'avant) reste reconnu comme l'exemple ; un dossier
    qui ne fait que COMMENCER comme celui de l'exemple (`…/Examples/`) ne l'est plus (la comparaison prend la barre) ;
  - les projets « untitled » déjà dans les données de l'appli ne sont pas déplacés (ils restent dans « Recent »).
  - **MESURÉ** : `test_projet` 105 (+10, attendus à la main : Documents dans l'exe, barres de Windows redressées, rien
    hors de l'exe ni sans Documents, `untitled/`, `untitled 2/` même si le dossier est vide, un ancien `untitled 3.mbproj`
    à plat non recouvert) ; `fumee_appli` 756 (+2 : `_chemin_libre` dans un dossier jetable, l'ancienne place de
    l'exemple). Trois mutations rouges (l'exe ignoré, le projet à plat, l'ancienne place oubliée — avec `_chemin_libre`
    qui ignore la racine). **ÉPROUVÉ DANS L'EXE CHIFFRÉ (reconstruit le 4 octobre 2026, 11:55)**, `reglages.cfg`
    sauvé et rendu, `test.mbproj` intact (MD5) : `--open-example` installe dans `Documents/MarchingBlocks/Example/<STAMP>/`
    (rien de neuf dans AppData) ; lancé sans projet à rouvrir, il crée `Documents/MarchingBlocks/untitled/untitled.mbproj`
    et le retient ; journal sans erreur. ⚠ Lancé par ssh, l'exe n'a pas de fenêtre à fermer : tué de force, donc la
    fermeture propre n'a pas été rejouée. Ni « New » cliqué à la main.

### Le TERRAIN monolithique et les PROPS rattachés — DÉCIDÉ (Jordan, 28 septembre 2026), PAS ÉCRIT

⚠ **REPORTÉ (Jordan, 2 octobre 2026) : abandonné pour la 0.9 / 1.0, remis à une MISE À JOUR FUTURE.** Tout ce qui
suit reste la conception retenue pour ce jour-là.

⚠ **ÉCRIT AVANT « UNE TUILE PAR CLÉ » (30 septembre 2026)** : là où ce qui suit dit « exemplaire », lire
« tuile ». La condition sur les CLÉS tient toujours ; la réserve sur les exemplaires tombe avec eux.

La question posée : un rocher sculpté À CHEVAL sur un plan de coupe peut-il se retrouver dans le monde
peint tel qu'il était dans le témoin ? Aujourd'hui, NON : le trancheur le coupe en deux, la découpe ne
referme pas la coupe (§4, voulu), et chaque moitié part avec son exemplaire. Posée à côté d'une voisine
qui n'a pas l'autre moitié, elle fait une **demi-coque ouverte**, et sa matière devient du « sol de
roche » de la clé qui l'a reçue.

⚠ **« QUEL QUE SOIT L'AGENCEMENT » EST IMPOSSIBLE, ET CE N'EST PAS UNE AFFAIRE DE CODE.** Une tuile ne
connaît que ses 8 cases ; ce qui traverse une coupe dépend des DEUX côtés. Si le monde met côte à côte
deux voisinages qui ne se sont jamais rencontrés dans le témoin, personne n'a sculpté ce qui va là.
Élargir le voisinage (3³ cases) ferait passer de 2⁸ à 2²⁷ configurations. Ce qu'on peut tenir :
**exact partout où le monde reprend un voisinage du témoin, absent ailleurs.**

**DÉCIDÉ — deux sortes de matière dans le travail :**

- **LE TERRAIN est MONOLITHIQUE** : D'UN SEUL TENANT, et rien de plus. Il est tranché comme aujourd'hui ;
  **la règle de pose des tuiles ne change pas**.
  ⚠ **MONOLITHIQUE NE VEUT DIRE NI LISSE, NI FERMÉ, NI « SANS DÉPASSEMENT » — PRÉCISÉ PAR JORDAN (29
  septembre 2026)** : *« tout dépassement de faces rattaché au volume et fusionné, qui rend le volume non
  lisse »* — un liseré d'herbe qui sort du volume, une lame, une écaille, une arête vive — est du TERRAIN.
  Il a le droit de sortir de sa case (règle (A)) ; seule la couture fait foi.
  ⚠ **ET LA COUTURE DIT CE QUE ÇA VEUT DIRE, MESURÉ SUR LE FAUX TRAVAIL D'ARTISTE** (§4) : **ce qui
  FRANCHIT un plan de coupe ne doit dépendre que du germe de cette face.** Un liseré posé « là où le ciel
  est ouvert » (une condition hors des huit cases), ou assez large pour entrer dans une région dont le
  germe est VIDE — une tuile qui n'existe pas —, a rendu 579 remarques de couture, toutes justes : sa
  pointe se serait perdue, ou aurait flotté à côté d'une voisine qui ne la porte pas.
- **TOUT LE RESTE EST UN PROP** : rochers, souches, décor. Jamais tranché, il part ENTIER, peut
  traverser les coupes et déborder sur les voisines.
- ⚠ **LE MONOLITHE REND LES PROPS DÉDUCTIBLES — c'est ce qui le justifie.** Toute composante connexe
  du `.glb` autre que la coque de terrain est un prop, quels que soient son nom et l'objet Blender qui
  la porte (§4 : on déduit, on ne déclare pas ; un nom ne survit pas à une séance de travail).
- ⚠ **UN ROCHER FUSIONNÉ PAR BOOLÉEN EST DU TERRAIN** : il sera tranché, et la demi-coque revient —
  `verifier_couture` le voit en remarque. On le dit à l'artiste : *garde tes props séparés*.

**DÉCIDÉ — le rattachement, « niveau 2 » :**

- Un prop est rattaché au **sommet dont la région contient son ANCRE** et voyage avec la clé,
  l'exemplaire et le quart de tour de cette tuile. L'ancre (centre de sa boîte, ou point le plus bas)
  est **OUVERTE, à mesurer**.
- ⚠ **IL RETIENT LES CLÉS DES SOMMETS SUR LESQUELS IL DÉBORDE dans le témoin, et ne se pose que si le
  monde porte les mêmes** (au quart de tour du rattachement près). Un rocher ABSENT vaut mieux qu'un
  rocher planté dans une falaise qui n'était pas là au témoin — c'est la ligne du §3 : l'absence se
  voit, jamais un faux.
- ⚠ **LA CONDITION PORTE SUR LES CLÉS, PAS SUR LES EXEMPLAIRES.** Le tirage étant haché par position,
  une condition d'exemplaire n'aboutirait presque jamais ; près d'une coupe, le contrat de couture rend
  les exemplaires d'une clé interchangeables. ⚠ Le risque restant : un exemplaire qui s'écarte beaucoup
  de son profil LOIN de la coupe laisse flotter un prop qui déborde jusque-là. Responsabilité de
  l'artiste, comme la connectivité.
- ⚠ **UN PROP S'AJOUTE, IL NE REMPLACE RIEN** : aucun arbitrage entre candidats, aucune tuile ne
  change, et la reconstruction reste déterministe et locale (§3, « le tirage est déterminé par la
  position »). C'est pourquoi ce niveau a été préféré aux « ensembles » de tuiles posés d'un bloc, qui
  demandaient de changer la règle de pose et une résolution de conflits.
- **Le pipeline qui doit suivre** : l'import sépare les composantes ; le tranchage ne voit que le
  terrain ; la récolte des props se fait par exemplaire (ancre, sommet, clés débordées) ; le format
  neutre les porte (props et condition dans `tileset.json`, maillages dans `tiles.glb` — encore v1,
  rien n'est publié) ; **les trois greffons posent les props dont la condition tient**, et
  `conformance.json` le garde, avec les trois bancs. Preuve de bout en bout : sur la forme du témoin,
  chaque prop se retrouve triangle pour triangle (l'empreinte, §4).
- **Deux mesures AVANT le code** : (1) le témoin exporté est-il lui-même d'UN SEUL TENANT ? S'il part
  en plusieurs composantes, « tout le reste est un prop » prendrait des morceaux de terrain pour des
  rochers ; (2) un `.glb` d'essai portant un rocher à cheval sur une coupe : l'import l'isole-t-il, et
  le terrain se tranche-t-il comme avant ?

### La TEXTURE : la discipline de l'artiste — DÉCIDÉ (Jordan, 28 septembre 2026)

Ce que l'artiste peint au CŒUR d'une tuile arrive tel quel dans le monde : `decoupe.gd` transporte les
UV, chaque tuile emporte sa part du dessin. Tout se joue aux COUPES, où la voisine du monde n'est pas
celle du témoin — une autre clé, un autre exemplaire, un autre quart de tour.

- **DÉCIDÉ — pas de fondu, pas de projection en jeu : c'est la DISCIPLINE DE L'ARTISTE.** Écartées :
  une bande de fondu vers une matière de base projetée en espace monde (elle demandait un shader dans
  chacun des trois greffons) et la texture entièrement projetée (elle interdisait tout dessin propre à
  une tuile).
- **LA RÈGLE À LUI ÉCRIRE** : *le long de chaque plan de coupe, la texture doit être la MÊME pour toutes
  les tuiles — sur les quatre bords, dans les deux sens.* En pratique : près des coupes, une matière
  tuilable projetée ; le dessin libre au cœur. Les props, entiers, n'y sont pas soumis.
- ⚠ **ON PRÉVIENT : LE TÉMOIN NE S'ENVOIE PAS À UN TEXTUREUR AUTOMATIQUE (Tripo et semblables).** Un tel
  outil peint le bloc comme UN objet : la texture est continue à travers les coupes, donc parfaite dans
  le témoin et cassée à chaque couture du monde peint. Le témoin MENT alors sur le rendu. Ça s'écrit
  dans la documentation de l'artiste et sur la page de vente, AVANT l'achat (§10).
  ⚠ **ET LA FORME AUSSI — MESURÉ (29 septembre 2026)** : Tripo REMAILLE le bloc (arêtes arrondies,
  relief), donc le bord de la matière sur un plan de coupe change d'un endroit du témoin à l'autre. Le
  monde peint avec `test_textured_by_tripo.glb` montrait une fente fine à CHAQUE joint (§4, « les fentes
  entre tuiles »). Ce n'est pas seulement la peinture qui casse : c'est l'étanchéité.
- **ÉCRIT ET MESURÉ (29 septembre 2026) — LA REMARQUE DE COUTURE DE TEXTURE** (`Tranchage.
  verifier_couture_texture`, appelée par `trancher()`). Elle échantillonne l'image de chaque tuile sur
  ses arêtes posées SUR un plan de coupe et compare toutes les tuiles au même point du plan, REPLIÉ par
  ce que la pose peut faire (quarts de tour autour de +Y, les deux côtés d'un plan). Une remarque, jamais
  une erreur (§3). Une tuile sans texture n'est pas jugée : le témoin calculé n'en porte pas.
  Mesuré : 0 remarque sur le faux travail discipliné, 218 122 points sur le même peint sans discipline ;
  le repli est gardé par un cas construit (deux tuiles en miroir, rouge contre bleu), vu rougir.
- **PROPOSÉ, non tranché** : le MODE CANONIQUE — griser au témoin tous les exemplaires sauf un par clé
  (52 à peindre au lieu de 541), le choix canonique vivant à UN endroit du cœur (« quart de tour 0
  d'abord » à mesurer). Il réduit le nombre de raccords à tenir ; il ne les supprime pas.
- **PROPOSÉ, ÉCRIT ET MESURÉ (28 septembre 2026) — LES UV CANONIQUES, la forme du mode canonique qui ne
  grise rien.** Le témoin part en OBJ avec des UV où chaque point ne dépend que de sa CLÉ, de sa position
  ramenée à la RÉFÉRENCE de sa pièce (la rotation inverse du trancheur) et du sens de sa face
  (`BlocsMaitres._uv_du_temoin`). Peindre une copie peint donc les 541 : 52 tuiles à peindre, chacune
  identique partout où elle revient. L'atlas : six carrés par clé (un par sens), clés dans l'ordre de
  `MB.classes()`, le nom nu avant l'air libre, un carré de plus pour les sommets de bord non récoltés.
  - ⚠ **LA CLÉ D'UN SOMMET EST SORTIE DU TRANCHEUR** (`Tranchage.cle_du_sommet`) pour que l'export lise la
    même règle que la récolte ; `trancher()` l'appelle, sortie inchangée.
  - ⚠ **L'OBJ SE RELIT AVEC SES UV** (`vt`), et `normales_plates` les transporte : jusqu'ici le retour
    OBJ gardait la seule position, donc un `.obj` peint revenait sans sa peinture, sans un mot. Le
    `.glb` écrit pour `DEV_TOOLS/` part toujours SANS UV.
  - **MESURÉ** (`test_blocs_maitres` §15, par le VRAI trancheur sur l'OBJ relu) : 541 items, **0 coin où
    deux exemplaires d'une clé divergent, 0 triangle chez une autre clé, 0 recouvrement dans un
    exemplaire**. Quatre mutations, toutes rouges : UV prises dans le repère du monde (27 410 coins
    incohérents), une seule clé pour tout l'atlas, le sens de face ignoré, le lecteur qui oublie `vt`.
  - ⚠ **CE QUE ÇA NE FAIT PAS** : supprimer les raccords (voir plus haut), ni donner de la variété aux
    exemplaires — ils partagent la même peinture tant que l'artiste ne redéplie pas l'un d'eux, ce que
    le trancheur accepte. **OUVERT** : livrer une image-guide de l'atlas (le nom de chaque clé dans ses
    carrés) ; rien n'a été vu dans Blender ni à l'image.

---

## 4. Le pipeline — l'aller-retour qui prouve tout

```
  exporter_le_bloc()  →  UN .obj, le bloc à l'origine  →  Blender  →  .glb  →  librairie_depuis_glb()
                                                                          ↓
                                   trancher() par case  →  classer  →  MeshLibrary  →  le pinceau
```

- ⚠ **LE BLOC EST RETROUVÉ PAR SA POSITION — DANS LA SCÈNE, POSE DU NŒUD COMPRISE —, PAS PAR SON NOM.** Dans un modeleur on renomme, on joint,
  on fusionne sans y penser : un nom ne survit pas à une séance de travail, une place fixée si. C'est
  aussi la doctrine générale — **on DÉDUIT plutôt qu'on déclare**. Le bloc est à l'origine, et la
  réimportation le redécoupe dans une boîte **tolérante au relief** (`DEBORD_TOLERE`) : découper pile
  sur `COTE³` raboterait le travail de l'artiste au ras des bords.
- ⚠ **« LE .glb PART SOUDÉ » ÉTAIT FAUX DEPUIS L'AJOUT DES SIX TEINTES — MESURÉ LE 27 SEPTEMBRE 2026 SUR
  LES OCTETS DU FICHIER** (`sonde_soudure_glb.gd`, et confirmé par un import dans Blender 5.1) : `par_teinte`
  recopiait les trois sommets de chaque triangle, et le témoin partait en **soupe de triangles** — 93 360
  sommets pour 15 546 positions, chaque arête une couture. Corrigé (indices gardés) : **18 891**. ⚠ **ET CE
  QUI RESTE EST UNE LIMITE DU FORMAT, PAS DU CODE** : en glTF, un matériau est une primitive, et Blender
  ne partage aucun sommet entre primitives — **6 610 coutures aux bords de couleur**, même quand les six
  primitives lisent le MÊME tampon de sommets (mesuré). Un sommet glTF porte UNE valeur de chaque
  attribut : tout ce qui change d'une face à l'autre (matériau, UV, couleur) coupe le maillage. Soudé à
  100 % mesuré dans Blender : l'OBJ (15 546 sommets, 0 couture, six matériaux) ou le .glb importé avec
  « Merge Vertices ».
- ⚠ **REMPLACÉ LE 30 SEPTEMBRE 2026 : le témoin part en .glb LIÉ** (§3, une tuile par clé) — l'OBJ n'a pas
  de copies liées. `exporter_le_bloc` reste, pour `DEV_TOOLS/` et le travail non lié.
- **DÉCIDÉ (Jordan, 27 septembre 2026) — LE TÉMOIN PART EN OBJ, LE TRAVAIL REVIENT EN .glb.** Le témoin
  n'est qu'une ébauche (de la géométrie, six teintes) : l'OBJ ne lui coûte rien et arrive soudé. Le
  retour garde tout ce que le glTF porte — textures, UV, normales, PBR. Un `.obj` est accepté au retour
  aussi. `.glb` reste écrit par `exporter_le_bloc` quand on le lui demande, pour `DEV_TOOLS/`.
  **MESURÉ, aller-retour complet OBJ → Blender 5.1 → .glb → trancheur : 541 items, 0 erreur de
  tranchage, 0 remarque de couture, 0 sommet déplacé.** Gardé par `test_blocs_maitres`
  (`_le_temoin_part_soude`, lu dans le TEXTE du fichier, sans le lecteur du module), vu rougir.
- ⚠ **ET CET ALLER-RETOUR A DÉBUSQUÉ UN DÉFAUT DU LECTEUR, PAS DE L'OBJ.** L'importeur OBJ de Blender
  convertit les axes par une ROTATION D'OBJET (+90° en X), et le .glb qu'il réécrit la garde sur le
  nœud. `_premier_maillage` rendait le maillage BRUT, sans la pose de son nœud : l'œuvre revenait
  couchée — 41 erreurs, 2 393 sommets déplacés. La pose est désormais cuite dans les sommets
  (`_transformer`, miroir compris) : **on lit ce que l'artiste VOIT**, et un objet tourné ou déplacé sans
  « Apply » n'est plus un piège. Gardé par `_la_pose_du_noeud_est_lue`, vu rougir.
- ⚠ **LE .glb PART SANS NORMALES NI TANGENTES.** Sans normales, la spécification glTF impose
  l'ombrage PLAT : on obtient à la fois la topologie soudée (modifiable dans Blender) et des arêtes
  franches. ⚠ Nuller `ARRAY_NORMAL` **sans** `ARRAY_TANGENT` ne suffit pas.
- **Il part déjà AMINCI** — tuiles ramenées à la moitié de leur case — pour montrer à l'artiste la marge
  dont il dispose. ⚠ **On rétrécit AVANT le tranchage** : chaque cube reste fermé, et les pièces
  voisines se rebouchent. Rétrécir APRÈS les crève, puisqu'elles sont ouvertes sur leurs faces de coupe.
- ⚠ **RENVERSÉ LE 9 OCTOBRE 2026 : TROIS CRANS, LE NEUTRE PAR DÉFAUT** (section suivante). Ce qui suit reste vrai pour
  ce qu'il dit : export, catalogue et repli lisent le MÊME appel (`BM.maillage_du_temoin(i, retrait)`), au cran du monde.
- ⚠ **L'AMINCI EST LE SEUL MODE — DÉCIDÉ (Jordan, 25 septembre 2026).** Une case à cocher offrait le
  solide brut à la place. Ce n'était pas un réglage mais une façon de mentir à l'artiste sur sa marge.
  ⚠ **Et le paramètre cachait un défaut réel** : l'export amincissait par défaut tandis que le repli de
  `librairie_depuis_glb()` rendait le solide PLEIN — un bloc absent du `.glb` revenait donc dans une
  géométrie DIFFÉRENTE de celle qui était partie. **Export, catalogue et repli lisent désormais le même
  appel**, donc sont d'accord par construction et non par vigilance.
- ⚠ **LA GÉOMÉTRIE EST UNE COQUE EN SOUS-VOXELS** (4 par cellule, le retrait valant un quart de case).
  L'ancienne version émettait une face par face de cellule : l'aminci en sortait **non-manifold**, avec
  144 faces enterrées sur 216. Et culler naïvement ouvrait **16 trous**, là où deux cellules voisines
  n'ont pas le même retrait. La coque ferme la surface sans culler ni boucher.
  ⚠ Coût mesuré : **×5 en triangles**, et la RÉCOLTE est identique (mêmes classes, 0 erreur d'octant).

### LES TROIS CRANS DE LA SURFACE DU TÉMOIN — DÉCIDÉ (Jordan, 9 octobre 2026), ÉCRIT LE MÊME JOUR (branche `amincissement`)

La question de Jordan : « est-ce le mode dual qui fait que les coins et arêtes d'un massif sont peu chanfreinables, ou parce
que le témoin a été ramené plus loin qu'à mi-tuile ? » — **C'ÉTAIT L'AMINCISSEMENT, PAS LE DUAL.** Un chanfrein ne peut pas
franchir un plan de coupe (sinon c'est la section de toutes les parois qui change, §3) : son budget est la distance de
l'arête au plan, 0,5 − retrait de chaque côté. L'aminci (surface à −0,25 dans la tuile) ne laissait que **0,25** à raboter,
et « on a l'impression que tout va rester presque cubique ». Le dual est au contraire ce qui met l'arête au MILIEU d'une
tuile (en primal elle serait à cheval sur quatre). La marge pour bomber vers l'air est l'inverse (0,5 + retrait).

- **DÉCIDÉ (Jordan) : trois crans, 0 par défaut** — Inset (retrait 0,25, l'aminci d'avant : 0,25 à raboter, 0,75 à bomber),
  **Centred** (0 : la surface au bord des cases, à mi-chemin des plans de coupe, 0,5 et 0,5), Outset (−0,25 : 0,75 et
  0,25). ⚠ **±0,5 SONT INTERDITS** : la surface tomberait SUR un plan de coupe (une case seule sans épaisseur, deux masses
  séparées d'une case vide qui se touchent, des sections partagées indéfinies) ; ±0,75 sort de la tuile. Les trois crans
  tombent sur la grille des sous-voxels (`SOUS` = 4). `BM.RETRAITS`, `BM.cran`, `BM.maillage_du_temoin(i, retrait)` ;
  `librairie`, `tuiles_du_temoin`, `exporter_le_temoin_lie`, `exporter_le_bloc`, `librairie_depuis_glb` (son repli),
  `ecart_au_temoin`, `TL.depuis_le_temoin_calcule` prennent le cran (défaut : le neutre). `maillage_moitie` reste l'aminci
  par son nom (les sondes de `DEV_TOOLS/`).
- **LE CRAN ÉPAIS FAIT DÉBORDER LA COQUE** dans les cases vides voisines (`sous_voxels`, retrait négatif) ; sans contact
  diagonal rien ne se percute (l'écart le plus étroit, une case vide entre deux pleines, tombe à 0,5).
  ⚠ **LE CONTRÔLE DES OCTANTS DU TRANCHEUR ROUGISSAIT À TORT** (52 erreurs, une par tuile, « la matière a été déplacée ») :
  la paroi épaisse est dans l'octant VIDE. Il juge désormais une face RECULÉE contre sa normale de `RECUL_D_ATTRIBUTION`
  (0,375) — la matière est derrière une surface ; une rotation fausse pose la matière derrière des octants vides, reculer
  ne la sauve pas. **Mesuré : 52 tuiles, 0 erreur, 0 remarque de couture aux trois crans.**
- **UN CRAN PAR MONDE, PAS PAR COUCHE — DÉCIDÉ (Jordan, 9 octobre 2026), APRÈS MESURE.** Écrit d'abord par couche : la fumée
  a mesuré qu'une couche aminci à côté d'une neutre laisse **1 928 sommets de joint sans partenaire** à leur frontière
  (leurs parois sont à −0,25 et 0), que « Match other layers » ne rattrape pas (il ne cale qu'à 0,1 près). `.mbproj`
  **version 3**, clé `retrait` du projet (absente : l'AMINCI — un monde déjà peint ne bouge pas ; un exe d'avant refuse le
  fichier plutôt que de le réécrire sans elle). Un projet neuf est au neutre. Le cran ne touche que les témoins CALCULÉS :
  un témoin modelé (ou revenu de Blender) garde sa forme, et le panneau nomme ces couches (« a gap where they meet »).
  Le lot du témoin calculé a sa source par cran : « witness » (l'aminci, les caches d'avant restent bons), « witness@0.0 »,
  « witness@-0.25 » (`Projet.source_du_temoin`).
- **L'ÉCRAN** : Witness geometry, section **Witness surface** (Inset · Centred · Outset, UNE annulation) ; changer de cran
  refait le témoin calculé de chaque couche qui n'a pas le sien, son monde suit (son `.glb`, ou le lot au cran), la vue,
  et l'eau. Le manuel (F1) a son paragraphe.
- **L'EAU SUIT LE CRAN** (`EauMaillage.nappe`, `riviere`, `avancee`) — elle était réglée sur l'aminci : au neutre, une
  rivière aurait coulé SOUS le sol. La règle, qui retombe EXACTEMENT sur les valeurs d'avant à l'aminci : la nappe d'un lac
  0,05 sous le plus bas du dessus de sa rive (L + 1 − r) et du dessous d'un étage flottant (L + 1 + r) — L + 1 − |r| −
  0,05 (0,70 · 0,95 · 0,70) ; la bande d'une rivière 0,10 au-dessus de son sol (y + 0,1 − r) ; une cascade part du plan de
  la falaise décalé de 0,25 − r (la place qu'elle avait devant la roche amincie). Le Play test nage à la même hauteur.
  `world.json` gagne **`water_floor`** (0,25 · 0 · −0,25 ; absent : 0,25 ; autre chose refuse le monde), lu par les
  greffons qui refont la nappe.
- **LES RIVIÈRES ONT UNE ÉPAISSEUR — DEMANDÉ PAR JORDAN, LE MÊME JOUR** (« la bande est un plan contre le sol sans
  refermement sur les flancs ») : `EauMaillage._bande`. Chaque côté d'une bande, selon sa voisine du même étage : pleine,
  la bande s'avance de 0,45 sous la roche ; de l'eau posée sur la matière, rien ; de l'eau au-dessus du vide (la lèvre
  d'une cascade), jusqu'où la cascade part ; SÈCHE avec du sol dessous, la bande s'arrête au bord de sa case et descend en
  un FLANC jusqu'à 0,05 sous le sol ; sèche au-dessus du vide (une corniche), elle s'arrête 0,05 hors de la roche et y
  descend. ⚠ Les rivières des cas d'avant coulaient toutes dans des chenaux murés : aucune n'avait de côté sec — les
  flancs n'y changent rien.
- **LES CAS COMMUNS** : `water_mesh_conformance.json` passe de 15 à **23 cas** (chacun porte `floor` ; un chenal sur un
  plateau aux trois crans, l'escalier, le lac qui déborde et l'île au neutre, la dalle flottante et le bassin à l'épais),
  la règle écrite (`rules_text`) décrit le sol, les bandes et les flancs ; les 15 d'avant (à 0,25) inchangés en triangles
  sauf là où un flanc apparaît. Régénérés dans les trois greffons.
- **MESURÉ** : `test_blocs_maitres` 1 475 (+7 : boîte du témoin écrite à la main par cran, 52 / 0 / 0 aux trois crans),
  `test_sections` 59 (+8 : chaque témoin calculé étanche à ses joints, deux crans différents NON, la paroi en −r),
  `test_fluides` 293 (+41, attendus à la main : bandes, flancs, cascade, nappe, nage aux trois crans, la corniche, `water_floor` lu et refusé),
  `test_projet` 143, `test_parite` 311 (hauteurs par cran), `fumee_appli` 946 (+21 et une SENTINELLE, par les vrais
  boutons : Inset → Centred → Outset, la vue, le témoin lié de la couche, la paroi qui avance de 0,25, Ctrl+Z / Ctrl+Y,
  trancher → « witness@-0.25 », changer de cran retranche, la mer à 2,95 / 2,7, le projet relu). ⚠ **LA FUMÉE EST AMINCIE**
  (son monde d'essai écrit `retrait` 0,25) : ses hauteurs écrites à la main (10,75, 2,34, 20,75…) sont celles d'un sol
  aminci. **Le greffon Godot** : la règle portée (`mb_water_mesh.gd` : `surface`, `river`, `advance`, `_band`),
  `water_floor` lu (`mb_water.gd`), le nœud d'eau le garde (`floor_kind`) et ne reprend rien d'un autre sol ;
  `test_greffon_peinture` 459 — **les 23 cas du premier coup**.
- **UNITY** (`MBWaterMesh.cs` : `SheetHeight`, `BandHeight`, `Advance`, `Band` ; `MBWater.ReadFloor` ; le composant
  `MarchingBlocksWater.waterFloor` ; l'importeur refuse un `water_floor` faux) : banc .NET **23 / 23** du premier coup
  (et la mémoire bâtie pour un autre sol rend les mêmes triangles ; 7 lectures de `water_floor`), le monde d'eau exporté
  2 147 triangles (2 103 avant les flancs) ; **Unity 6.6 : 65 tests sur 65** en Built-in ; 10 mutations rouges. ⚠ Les
  préparateurs des mondes d'essai (`preparer_*_unity.gd`) sont désormais AMINCIS en le disant : leurs attendus (un plant à
  1,75…) sont ceux d'un sol aminci — deux tests de plantation rougissaient au neutre. URP non relancé.
- **UNREAL** (`MBCore/MBWaterMesh` : `SurfaceAt`, `RiverAt`, `AdvanceAt`, `WmBand` ; `Water::Read` lit `water_floor` ;
  l'acteur `WaterFloor`, l'import le pose) : `core-runner` sous MSVC aux drapeaux d'Unreal **23 / 23** du premier coup,
  un monde exporté aux trois crans = sa nappe cuite (mer, lac, rivières) ; **BuildPlugin 5.8.3 : BUILD SUCCESSFUL, aucun
  avertissement** ; 7 mutations rouges. ⚠ **UN MONDE EXPORTÉ AVANT LES FLANCS** ne retrouve plus sa nappe cuite sur ses
  RIVIÈRES (mer, lacs, cascades identiques) : la nappe refaite a des flancs que la cuite n'a pas — attendu. Rien mené dans
  l'éditeur d'Unreal.
- **ONZE MUTATIONS, TOUTES ROUGES** : le recul d'attribution nul et la coque qui ne déborde jamais (`test_blocs_maitres`),
  le témoin calculé qui ignore son cran (`test_sections`), pas de flanc, la bande qui ignore le cran, la cascade sans
  l'avancée, la nappe sans valeur absolue, la corniche sans retrait (`test_fluides`), un projet d'avant relu neutre
  (`test_projet`), le greffon Godot sans flanc et qui ignore le sol (`test_greffon_peinture`). ⚠ Quatre ont d'abord RIEN
  éprouvé (« motif absent ») : leur motif portait un retour à la ligne, et ces fichiers sont en CRLF — rejouées sur une ligne.
- **LE NEUTRE RESTE LE DÉFAUT, ET LA CAGE DE LA TUILE MONTRE LA MARGE — DÉCIDÉ (Jordan, 10 octobre 2026)**, après une
  question : « garder Outset par défaut et montrer la grille 3D en transparence pour montrer qu'on peut enfler ? ».
  PROPOSÉ puis retenu : l'impression « ça va rester cubique » vient de ce qu'on VOIT (un tas de cubes, à tous les crans),
  pas du cran ; Outset ne laisse que 0,25 pour enfler (une corniche, un rocher qui sort) et resserre les couloirs. La
  cage montre la règle elle-même : « ta tuile, c'est cette boîte ». ÉCRIT LE MÊME JOUR (`vue.gd`, `_cage`,
  `centre_de_la_cage`) : la boîte d'une case autour de la tuile — sous la souris hors édition (le rayon contre les cases
  du témoin, puis `Outils.sommet_touche`, la règle de l'outil Variant), la tuile qu'on édite en édition (sa pose) —, un
  voile et douze arêtes DORÉES vus à travers la matière ; « Show the tile's cage » (cochée) dans Witness surface ;
  seulement dans Witness geometry. ⚠ **LA POSITION DE LA SOURIS VIENT DES MOUVEMENTS REÇUS PAR LA VUE** : avec une
  fenêtre, `get_local_mouse_position` lit la souris de Windows, qu'un survol envoyé ne déplace pas (vu à l'image : pas de
  cage). ⚠ **LA TEINTE PÂLE DES PLANS DE COUPE NE SE VOYAIT PAS** sur les sols verts : dorée franche. Gardé par
  `fumee_appli` (un vrai survol du dessus de la case la plus haute : la cage centrée sur le point entier le plus proche,
  écrit à la main ; décochée, rien ; en édition, le sommet de l'occurrence + 1 ; dans World, rien) ; mutation rouge (la
  cage jamais montrée : 2 échecs). Vu à l'image (`DEV_TOOLS/capture_cage.gd` : Centred, Outset, Inset, en édition).
  ⚠ Pas tenue en main.
- ⚠ **CE QUI A ÉTÉ TROUVÉ EN ROUTE** : à l'ouverture d'un projet, la vue du témoin ne suivait pas son cran (vu par la fumée).
- ⚠ **PAS VU À L'IMAGE, PAS TENU EN MAIN.** Ni l'eau aux nouveaux crans ni les flancs n'ont été regardés avec fenêtre.

### Le CHANFREIN : un maillage DUAL à 0,35 — ESSAYÉ puis SUSPENDU (Jordan, 25 septembre 2026)

Le témoin partait avec des **escaliers**, et Jordan les a croisés en rouge sur une capture : *« il
faudrait que les deux arêtes soient reliées par des faces directes plutôt que par deux faces formant un
escalier. »*

⚠ **IL A ÉTÉ BRANCHÉ SUR L'EXPORT UNE HEURE, PUIS DÉBRANCHÉ** : *« je voulais plus aucun angle et tu as
fait des angles moins obtus. »* Une marche remplacée par une pente reste une **arête** ; ce qui était
demandé, c'est que les deux arêtes **fusionnent en une face**. Le maillage dual adoucit, il ne supprime
pas. **Le code et les mesures restent** — elles sont justes, c'est l'objectif qu'elles n'atteignent pas.
⚠ **Et la leçon de méthode est là** : j'ai livré ce que ma méthode savait faire, pas ce qui était
demandé, sans voir l'écart avant qu'il ne le dise. La priorité est revenue à **éprouver le pipeline
entier** sur le témoin unique.

- ⚠ **CES ESCALIERS SONT UN ARTEFACT DE L'AMINCISSEMENT, PAS LA FORME VOULUE — MESURÉ.** Le solide n'a
  **aucune** petite marche : ses 244 contremarches sont à 100 % des multiples d'une cellule.
  L'amincissement les porte à 398 en coupant chaque marche de 4 sous-voxels en une paire **1 + 3**, et
  crée **91 paliers larges d'un seul sous-voxel** sur 261.
- ⚠ **LE GESTE LITTÉRAL EST IMPOSSIBLE, et Jordan l'avait pressenti** : *« là où trois contremarches se
  rencontrent, le triangle qu'on créera rendra beaucoup d'endroits non-manifold. »* Pire encore — un
  palier d'UN sous-voxel n'a qu'une face, **réclamée par les chanfreins de ses deux côtés**.
- **LE REMÈDE EST UN MAILLAGE DUAL** (*surface nets*) sur le champ de sous-voxels : un sommet par cube
  dual traversé, **un quad par arête primale traversée**. Une arête du maillage sépare donc exactement
  deux quads : ⚠ la non-manifoldité n'est pas évitée au cas par cas, **elle n'a pas de place où naître**.
  Mesuré : **18 arêtes ambiguës avant, 18 après**, 0 trou, tout soudé, **68 classes récoltées** des deux
  côtés — le contrat de couture tient.
- ⚠ **0,35 EST MESURÉ, PAS CHOISI AU GOÛT.** Jusqu'à **0,60** le lissé est strictement identique à la
  coque à facettes (8 364 quads, 0 orphelin, 89,3 % de valence 4) ; à 0,80 apparaissent 390 orphelins,
  à 1,00 il y en a 528. **Le plafond esthétique est plus bas que le technique** : à 1,00 la surface FOND
  — contours ondulants, trou rectangulaire devenu ovale — et à 0,20 le chanfrein chuchote.
- ⚠ **AUCUN COMPTEUR NE POUVAIT TRANCHER LA FORCE.** Celui des pentes **sature** : il dit SI une face
  penche, jamais DE COMBIEN, et rend 63,0 % à 0,35 comme 63,2 % à 1,00. **Seule l'image l'a tranché.**
- ⚠ **ET CE QUE LE CHANFREIN NE RÈGLE PAS** : les décrochements d'une **cellule entière** restent des
  marches, simplement adoucies. Aucune force ne les enlèvera — ils sont dans l'occupation des cases,
  qui n'appartient pas à l'artiste (§3).

### Ce que le témoin NE POUVAIT PAS être — MESURÉ, et devenu sans objet le 27 septembre 2026

⚠ **TOUTE CETTE SECTION DÉCRIT LE MONDE AVEC DIAGONALES.** Le monde sans contact diagonal (§2) l'a
retournée : la planète paysage part avec **15 560 quads, 0 trou, 0 arête à trois faces ou plus**
(`sonde_cout_du_dernier_contexte.gd`, aminci). Elle reste écrite parce que ses leçons de mesure valent.

⚠ **UN TÉMOIN COMPLET CONTIENT NÉCESSAIREMENT DES ARÊTES NON-MANIFOLD.** Ce n'est pas un défaut à
corriger : **33 des 68 classes SONT des contacts diagonaux** (`diagonale`, `damier`, `chicane`,
`biais`, `crochet`…) — deux cellules qui ne se touchent que par une arête, où quatre faces se
rejoignent. Interdire ces contacts fait tomber la couverture à **52/90**, trois essais sur trois.
C'est l'ambiguïté que le modèle nomme `PONT_SUR_FACE_AMBIGUE`.

**DÉCIDÉ (Jordan, 25 septembre 2026) — on livre le témoin COMPLET et on le DIT à l'artiste.** Mesuré
sur ce qui part réellement : **15 arêtes ambiguës sur 8 326 quads (0,2 %), 0 trou, 100 % soudé,
valence 4 à 91 %**.

⚠ **CES CHIFFRES ÉTAIENT 18 SUR 8 364 ET 89 % JUSQU'AU 25 septembre 2026** : ils décrivaient la grille
de 267 cases, remplacée par la sortie du finisseur (262 cases). La 90ᵉ tuile — `mb_arete_creuse_b4h2`,
la dernière classe extérieure — a été gagnée **en RÉDUISANT** les arêtes ambiguës, pas en les payant.
J'avais annoncé l'inverse en opposant « 44 contacts par arête » (qui porte sur l'OCCUPATION) aux « 18
ambiguës » (qui porte sur le MAILLAGE AMINCI) : deux instruments différents, une conclusion fausse.
`DEV_TOOLS/sonde_cout_du_dernier_contexte.gd` les rend désormais dans la même unité.

⚠ **ET UNE PHRASE A ÉTÉ RETIRÉE D'ICI FAUTE DE SE REPRODUIRE** : « le nombre d'arêtes non-manifold du
solide ÉGALE exactement le nombre de contacts d'arête de l'occupation ». Mesuré sur les deux grilles,
le rapport est de **4 pour 1** (60 contacts → 240 ; 44 → 176), jamais de 1 pour 1. Le fait sous-jacent
tient toujours — la cause est dans la forme voulue, jamais dans le mailleur — mais l'égalité annoncée
n'a pas été retrouvée, et une charte qui affirme un chiffre invérifiable vaut moins que son silence.

⚠ **Et les valences se comptent sur les QUADS, pas sur les triangles.** Chaque quad porte sa diagonale,
qui ajoute une arête à ses deux bouts : un sommet de valence 4 y apparaît en valence 6. C'est pourquoi
« Tris to Quads » (Alt+J) rétablit les boucles d'arêtes — il supprime exactement ces diagonales.

### Les pièges de moteur, mesurés et payés

- ⚠ **Les faces avant de Godot sont dans le sens HORAIRE** : le produit vectoriel de l'ordre stocké doit
  pointer À L'OPPOSÉ de la normale sortante.
- ⚠ **`ImporterMeshInstance3D` N'HÉRITE PAS de `MeshInstance3D`.** Le chemin glTF de l'éditeur en
  produit, le headless produit des `MeshInstance3D`. Un `is MeshInstance3D` rendait « aucun ArrayMesh »
  sur un fichier parfaitement valide. **On reconnaît un nœud à ce qu'il SAIT FAIRE**, pas à sa classe.
- ⚠ **La découpe ne REFERME pas la coupe, et c'est voulu** — mesuré : aire 3,0 au lieu de 4,0, zéro
  triangle dans le plan. Les pièces voisines se bouchent mutuellement.
- ⚠ **Souder force une normale MOYENNE par sommet.** L'attribution d'un triangle à son octant doit donc
  se faire sur la normale **géométrique** (produit vectoriel des sommets), pas sur la normale stockée.
  Mesuré : revenir à la normale stockée fait réapparaître exactement 23 erreurs.
- ⚠ **`decoupe.gd` doit transporter `ARRAY_COLOR`** de bout en bout. L'oublier tout en gardant le
  matériau donne une planche blanche, sans une seule erreur.
- ⚠ **LE COÛT DU TRANCHAGE ÉTAIT DANS L'ALLOCATION, PAS DANS LA GÉOMÉTRIE — MESURÉ (27 septembre
  2026).** `Decoupe.trancher` bâtissait **trois dictionnaires par triangle** avant de découvrir dans
  Sutherland-Hodgman que le triangle était à dix cases de la boîte. Avec les exemplaires (541 découpes
  au lieu de 52), un `trancher()` complet demandait **203 s** — l'éditeur aurait gelé trois minutes et
  demie sur un clic. Un rejet par boîte englobante AVANT de construire quoi que ce soit le ramène à
  **17,7 s**, sortie identique. ⚠ Le test est CONSERVATEUR (boîte contre boîte) : il ne peut écarter
  un triangle qui contribuerait, donc c'est une accélération et **pas une règle**. Il profite aussi à
  l'ancien chemin. ⚠ **Et 17,7 s reste long** : ça n'a été mesuré que sur le témoin de 12³.

---

### LE FORMAT NEUTRE v1 — DÉCIDÉ (Jordan, 27 septembre 2026)

Ce que l'appli livre aux moteurs (« Export to engines », la couche ACTIVE) : un dossier `<nom>.mbset/`.

```
  tileset.json   la règle ET les tuiles : table des 256, coins, décalage, classes, contexte,
                 rules_text, et tiles = {clé: nom de SA tuile}, missing
  tiles.glb      un nœud par tuile, maillage centré sur l'origine, nœud à l'identité, matériaux
  README.txt     la règle en clair
```

- ⚠ **LE FICHIER PORTE LA RÈGLE.** Trois greffons qui réécriraient la classification, c'est la seconde
  description qui diverge (§6). La table est PRÉ-CALCULÉE ; le contexte, qui se
  recalcule en jeu, est ÉCRIT (`FormatNeutre.regle()`, ligne à ligne) et gardés par des cas
  d'épreuve.
- ⚠ **LA RÉFÉRENCE EST `MB.poses()`**, extraite de `massif_peint.gd` pour l'être : le peintre de l'appli
  l'appelle, et les cas d'épreuve sont calculés par elle. Une référence qu'on ne peut pas appeler sans
  `GridMap` n'en était pas une.
- **Repère glTF** : droitier, +Y en haut, 1 unité = 1 case. **Quarts de tour autour de +Y, main droite
  (+Z va vers +X)** — MESURÉ : les index de `GridMap` 0, 16, 10, 22 donnent 0, 1, 2, 3, et
  `quarts_de_tour()` le DÉRIVE de la base au lieu de le recopier. ⚠ Un moteur d'un autre repère doit
  convertir la grille des cases par la MÊME application que son importeur glTF applique aux maillages ; un
  repère miroir inverse le sens des quarts de tour.
- ⚠ **LE REPÈRE TÉMOIN : LA CONVERSION DE L'IMPORTEUR SE MESURE, ELLE NE SE SUPPOSE PAS.** Unity est
  gaucher, Unreal gaucher en +Z et en centimètres, et chaque importeur glTF convertit à sa façon — dans
  les sommets ou dans la pose des nœuds. `tiles.glb` porte un nœud `mb_frame`, un tétraèdre aux sommets
  (0,0,0), (1,0,0), (0,2,0), (0,0,3) (`frame_marker` dans le manifeste) : le greffon lit où l'importeur
  les a posés, les LONGUEURS 1, 2, 3 disent quel axe est lequel, la plus courte donne l'échelle. Cette
  application F EST la conversion ; une pièce se pose en F(v + piece_offset), tournée de F·R·F⁻¹ —
  une vraie rotation même quand F est un miroir. Ajouté avant toute publication, donc toujours v1.
- ⚠ **LES NOMS SORTENT EN ANGLAIS ET EN `[a-z0-9_]`** (§7, et certains moteurs refusent `~` ou `.`) :
  `mb_arete_creuse_b2h2_dehors` → `edge_inner_b2h2_outdoor` (une tuile par clé : son nom EST l'id de la
  clé ; les exemplaires `_2`, `_3`… ont vécu du 27 au 30 septembre 2026). La traduction vit
  dans `format_neutre.gd` ET NULLE PART AILLEURS ; les greffons ne décodent jamais un nom, ils lisent
  `tiles`. Gardé : aucun id en double, aucun hors de l'alphabet.
- ⚠ **UN SHADER DE GODOT NE VOYAGE PAS** : une tuile à `ShaderMaterial` part avec un matériau standard
  lisant ses couleurs de sommet ; le travail de l'artiste part avec SES matériaux — **et sa texture arrive,
  MESURÉ jusque dans Unity** (voir le faux travail d'artiste, plus bas).
- **Un format plus récent est REFUSÉ** par les greffons : sa règle peut vouloir dire autre chose.
- **LES CAS D'ÉPREUVE** (`FormatNeutre.cas_d_epreuve()`, écrits par `DEV_TOOLS/generer_cas_d_epreuve.gd`
  dans `conformance.json`, LIVRÉ AVEC CHAQUE GREFFON) : 9 mondes (case seule, sol, falaise de 3,
  surplomb, tunnel, grotte close, contact diagonal, coordonnées négatives, relief irrégulier) × 2 jeux
  (riche : toutes les clés, variantes d'air libre comprises ; nu : noms nus seuls) = 18 cas, **1 624 poses
  — 460 d'air libre, 46 marqueurs** (régénérés le 30 septembre 2026 sans exemplaires : du 27 au 30, le jeu
  riche portait 3 exemplaires par clé). Un greffon doit les passer à 100 %.
  ⚠ Le test vérifie AUSSI que les cas exercent ce qu'ils prétendent : un cas qui ne pose aucune tuile
  d'air libre ne garderait pas le contexte (§6).
  ⚠ **ET IL ROUGIT SI LE FICHIER LIVRÉ EST PÉRIMÉ** : changer la règle sans régénérer les cas est vu.
- **LE GREFFON GODOT GRATUIT** : `addons/marchingblocks_paint/`, **un addon NEUF ET SÉPARÉ** — l'addon
  historique porte le trancheur, qui est ce qui se vend. Il ne charge RIEN du cœur : `mb_rule.gd`
  réimplémente la règle depuis le TEXTE du format, `mb_tileset.gd` charge un `.mbset`, `mb_world.gd` est
  le nœud `MarchingBlocksWorld` (on peint `Cells` au pinceau natif du GridMap, `Tiles` suit, `Errors`
  montre les cubes rouges). En anglais, commentaires compris : sa source part chez l'acheteur.
  **MESURÉ de bout en bout** (`test_greffon_peinture`) : l'appli exporte le témoin (541 tuiles), le
  greffon le charge et pose **1 048 tuiles sur la forme du témoin, 0 écart** avec ce que pose l'appli.
  **Cinq mutations** : pas de repli sur le nom nu, hachage sans masque, rotations ignorées, référence
  changée sans régénérer — rouges ; ⚠ **la bande de contexte ramenée de 2 à 1 est MUETTE, et c'est une
  mutation ÉQUIVALENTE, pas un trou** : `outdoor_possible` exclut déjà toute classe dont une case vide du
  bas est coiffée dans les 8, donc la seule rangée que `v.y + 1` ajoute est vide pour toute classe qui
  atteint ce test. Bande 1 ou 2, même règle sur tout manifeste cohérent.
- **LE GREFFON UNITY GRATUIT** : `engines/unity/com.marchingblocks.paint/`, un paquet UPM (manifeste,
  `.asmdef`, `.meta` à GUID STABLES — sans eux Unity ignore les fichiers d'un paquet installé depuis git).
  `engines/` porte un `.gdignore` : Godot ne le voit pas. La règle (`MBRule.cs`) et le lecteur JSON
  (`MBJson.cs`) sont du C# PUR, sans `UnityEngine` ; `MBTileset.cs` charge un `.mbset` importé et MESURE
  le repère ; `MarchingBlocksWorld.cs` est le composant (cellules en espace du FORMAT, tuiles régénérées,
  jamais sauvées dans la scène) ; `MarchingBlocksWorldEditor.cs` est le pinceau de la Scene view (Unity
  n'a pas de GridMap : un rayon coupé contre le plan de l'étage, converti par F ; Maj efface ; PgUp/PgDn).
  **MESURÉ hors Unity** (`engines/unity/conformance-runner`, `dotnet run -c Release`, SDK .NET 10, les
  MÊMES fichiers que le paquet) : **18 cas, 1 624 poses, 0 échec**. Mutations : hachage sans masque et
  absence de repli sur le nom nu — rouges ; ⚠ **le hachage TRONQUÉ À 32 BITS est MUET, et c'est une
  mutation ÉQUIVALENTE** : le masque ne garde que les 31 bits bas, et en complément à deux les bits bas
  d'un produit ne dépendent pas de la largeur. Des entiers 32 bits qui débordent en boucle suffiraient
  donc — mais en C++ un débordement SIGNÉ est indéfini : la règle garde « 64 bits » pour Unreal.
  **MESURÉ DANS UNITY 6.6 (6000.6.3f1) avec glTFast 6.20.0, sur le VRAI témoin** —
  `engines/unity/test-project/` (paquet référencé depuis le disque, manifeste minimal ; le témoin, ses
  cases et l'attendu sont écrits par `DEV_TOOLS/preparer_essai_unity.gd`, hors git) : **6 tests sur 6**,
  en mode batch. glTFast convertit par **X → −X** (mesuré par le repère : unité 1, +Y gardé) :
  - le repère est une RÉFLEXION et garde le haut — une conversion droitier → gaucher l'est
    NÉCESSAIREMENT, c'est de la géométrie, pas notre code ;
  - **1 048 poses identiques** à celles de MarchingBlocks (tuile, position, quart de tour) ;
  - **l'empreinte de la géométrie posée** — le centre de chaque triangle en espace du format, × 1 200
    (des entiers EXACTS : le témoin est en multiples de 1/12), trié, MD5 — **est celle de Godot** :
    90 651 triangles, `c3876f4f…`.
  **Vu rougir DANS UNITY** : ôter la conjugaison F·R·F⁻¹ fait échouer exactement les trois tests qui en
  dépendent (485 poses fausses, empreinte différente, quart de tour du miroir synthétique), et laisse
  verts les trois qui n'en dépendent pas.
  ⚠ **UN CONTRÔLE D'ÉTANCHÉITÉ A ÉTÉ ÉCRIT, PUIS JETÉ, PARCE QU'IL ÉTAIT AVEUGLE.** « Les tuiles posées se
  referment : 0 arête ouverte » — mesuré 0 côté Godot… et encore 0 en annulant TOUTES les rotations.
  Les tuiles du témoin aminci sont des boîtes CLOSES et DISJOINTES (sa matière rentre d'un quart de case
  et ne traverse jamais un plan de coupe) : n'importe quelle rotation les laisse fermées. C'est le
  §6 mot pour mot — un contrôle qui ne peut pas échouer ne garde rien —, et c'est l'empreinte qui l'a
  remplacé. ⚠ Il faudra un témoin SCULPTÉ, dont la matière franchit les coupes, pour éprouver les
  coutures elles-mêmes.
  ⚠ **ET DEUX « BLOCAGES » N'EN ÉTAIENT PAS** : un script Godot planté dans `_initialize` (le `_ready()`
  d'un nœud n'y a pas encore tourné) n'appelle jamais `quit()` et pend — sa sortie, tamponnée dans un
  pipe, meurt avec lui. Lancer avec `--log-file` : l'erreur y est écrite.
  ⚠ **CE QUI N'A PAS ÉTÉ TENU EN MAIN** : le pinceau de la Scene view (le clic, le glissé, PgUp/PgDn,
  Ctrl+Z) et le rendu sous URP/HDRP. Unity lance aussi le test du paquet `TheFrameIsMeasured…` (repère
  en miroir ×100, synthétique), vert.
  ⚠ Unity RÉÉCRIT le manifeste d'un projet neuf avec son gabarit (une cinquantaine de modules) : il est
  remis au minimum, et reste stable aux ouvertures suivantes.
- **LES OUTILS D'ÉDITION DE MONDE DANS LES GREFFONS — DEMANDÉ PAR JORDAN (28 septembre 2026).** Godot,
  Unity et Unreal reçoivent les outils de l'appli : visée Grid / Sculpt / Navigate, Add, Dig, Select, Rect, Box
  (creuse ou non), pinceau sphère / cube / disque de 1 à 7, Fill, Delete, Extrude ↑ ↓ (l'étage suit),
  Grow, Shrink, Connected, déplacer (les flèches suivent la caméra), copier / couper / coller.
  ⚠ **TROIS IMPLÉMENTATIONS, UNE RÉFÉRENCE : `outils.gd`.** Même parade que pour la règle de pose :
  `epreuve_outils.gd` CALCULE les cas avec `outils.gd` et les écrit en anglais dans
  `tools_conformance.json` (69 cas : rayons, ancre, pinceaux, modifications, sept opérations de
  sélection, boîtes, déplacer, copier, coller), livré avec les TROIS greffons. `test_greffon_peinture`
  rougit s'il est PÉRIMÉ, et vérifie qu'il exerce ce qu'il nomme — rayons qui touchent ET qui manquent,
  égalité exacte, borne dépassée, boîte réellement évidée, chaque opération. La traduction des noms
  (`remplir` → `fill`…) vit dans `epreuve_outils.gd` ET NULLE PART AILLEURS.
  ⚠ **LES RAYONS SONT ÉCRITS EN FLOTTANTS EXACTS** (dyadiques) : Godot vise en `Vector3`, donc en 32 bits,
  les greffons en 64. Le générateur REFUSE un rayon dont la réponse change sous une perturbation de
  10⁻³ de la direction — sauf l'égalité exacte VOULUE, écrite dans la règle.
  ⚠ **UNE MUTATION EST RESTÉE MUETTE, ET C'ÉTAIT LE TEST** : départager une égalité à l'envers (`<=`)
  ne changeait aucun cas, parce que les seules égalités exercées étaient celles d'un rayon parallèle à
  un axe, où deux composantes sont à l'infini. Un rayon diagonal (|dx| = |dy|) départage bel et bien un
  franchissement simultané — ajouté, il rougit.
  - **Godot** : `mb_tools.gd` (les outils, en anglais, sans rien charger du cœur), `mb_editor.gd` (visée,
    coups, boîte, collage, touches, aperçu — un nœud autonome, donc éprouvable en headless) et
    `plugin.gd` (la barre au-dessus de la vue 3D, le relais de `_forward_3d_gui_input`). Le pinceau natif
    du GridMap reste, sur l'enfant `Cells`. **MESURÉ** (`test_greffon_peinture`) : 69 cas sur 69, et les
    GESTES menés par une vraie caméra et de vrais événements — un clic Grid pose, Ctrl+Z et Ctrl+Y,
    Sculpt contre la face, le verrou de coup, Rect → Fill → Extrude avec l'étage qui suit et revient à
    l'annulation, Navigate qui laisse le clic à l'éditeur. **Huit mutations, toutes rouges.**
    ⚠ **LES DEUX ANNULATIONS DE GODOT NE PARLENT PAS PAREIL** : `UndoRedo.add_do_method` prend un
    `Callable`, `EditorUndoRedoManager.add_do_method` prend (objet, méthode, arguments). Supposé
    identique, vu faux au premier essai ; `_call_in_undo` parle à chacune sa langue.
    ⚠ **UNE SECTION DE TEST A SAUTÉ EN SILENCE ET LA SUITE A DIT « OK »** : `mb_editor.gd` ne compilait
    pas, `.new()` a levé une erreur d'exécution, Godot a abandonné la fonction et continué le reste. La
    suite exige désormais que chaque script du greffon se CHARGE avant de l'éprouver — et cette garde a
    aussitôt attrapé un `match` en ligne que `plugin.gd` ne savait pas lire.
    ⚠ **CE QUI N'EST PAS ÉPROUVÉ** : `plugin.gd` dans l'éditeur (la barre, le relais) — un greffon
    d'éditeur ne se teste pas en headless ; il se juge souris en main.
  - **Unity** : `MBTools.cs` (C# pur, classe `MBTools` et enum `BrushTool` — ⚠ `Tools` et `Tool` entrent
    en collision avec `UnityEditor.Tools` et `UnityEditor.Tool`, mesuré à la compilation : le code d'un
    acheteur qui écrit `using UnityEditor; using MarchingBlocks.Paint;` aurait buté dessus). Le
    composant garde la liste sérialisée pour seule vérité et un INDEX à côté ; `Apply` réécrit la liste
    en une passe (retirer case par case d'une `List` est quadratique). La Scene view : Shift fait
    l'inverse (le clic droit y fait voler la caméra), Ctrl retire de la sélection.
    **MESURÉ** : banc .NET 69/69 ; **Unity 6.6, 9 tests sur 9**, dont l'éditeur compilé, `Apply` repris
    par `Undo`, et **la visée à travers le miroir de glTFast sur le vrai témoin**. Mutations rouges :
    copie tronquée, verrou de coup ignoré, égalité inversée, creux ignoré, borne ôtée (banc .NET), et
    visée sans défaire le miroir (dans Unity : seul ce test rougit, les 8 autres restent verts).
  - **Unreal** : `engines/unreal/MarchingBlocksPaint/`, un greffon à deux modules. Le CŒUR est du C++
    STANDARD (`MBCore/` : JSON, règle, outils, repère), sans Unreal, et `engines/unreal/core-runner`
    (`./build.sh`, g++) le compile SOUS LES CONTRAINTES D'UNREAL — sans exceptions, sans RTTI, masquage
    et rétrécissement en erreurs. **MESURÉ : 1 624 poses, 69 cas d'outils, le repère sur un importeur
    miroir en centimètres — 0 échec**, et treize mutations toutes rouges (repli sur le nom nu, hachage
    sans masque, quarts ignorés, les cinq des outils, la conjugaison F·R·F⁻¹ ôtée de deux façons, l'axe
    non divisé). ⚠ **LE REPÈRE A ÉTÉ SORTI DE L'ACTEUR POUR POUVOIR ÊTRE ÉPROUVÉ** : c'est lui qui a
    rougi dans Unity quand il était faux, et le laisser dans du code Unreal non compilable l'aurait
    laissé sans garde. L'acteur n'en garde qu'une conversion `FVector` ↔ `FVec3`.
    La couche Unreal : `AMarchingBlocksWorld` (cases en espace du FORMAT, copie du manifeste et repère
    mesuré SAUVÉS avec le niveau pour qu'un jeu empaqueté reconstruise sans le fichier, une
    `UInstancedStaticMeshComponent` par tuile, transitoires), réglages et opérations de sélection en
    `UPROPERTY` et boutons `CallInEditor` du panneau Details — donc AUCUN Slate à écrire ; et le mode
    `UMarchingBlocksEdMode` (un `UEdMode` : viser, glisser, aperçu, une transaction par coup).
    **MESURÉ — ELLE COMPILE, SUR UNREAL 5.8.3 (29 septembre 2026)** : `RunUAT BuildPlugin -TargetPlatforms=Win64`
    sur le PC (`D:/UE_5.8`, Build Tools de Visual Studio 2022), **BUILD SUCCESSFUL, aucun avertissement**,
    les deux modules. Il a fallu, dans l'ordre où ils sont apparus :
    - le **.NET Framework 4.8 SDK** dans les Build Tools (installé avec l'accord de Jordan) — sans lui,
      Unreal Build Tool s'arrête AVANT le greffon (« Could not find NetFxSDK install dir ») ;
    - ⚠ **`UEdMode` NE DÉCLARE PLUS `InputKey`, `MouseMove`, `Render` EN 5.8** : le gestionnaire de modes
      caste chaque mode vers `ILegacyEdModeViewportInterface` (souris, touches) et
      `ILegacyEdModeDrawHelperInterface` (`Draw`) — lu dans `EditorModeManager.cpp`. Le mode en hérite ;
    - ⚠ **LES OUTILS DU CŒUR N'ÉTAIENT PAS EXPORTÉS** : le module éditeur ne se liait pas (six
      `LNK2019`). `MARCHINGBLOCKSPAINT_API` devant `MBPaint::Tools`, défini à vide hors d'Unreal —
      `core-runner` compile et passe toujours.
    ⚠ **CE QUI N'EST PAS ÉPROUVÉ** : le mode dans l'éditeur (viser, peindre, Ctrl+Z), l'import de
    `tiles.glb`, un jeu empaqueté ; et les versions antérieures à 5.8 — l'héritage explicite pourrait y
    doubler une base. Le README dit « 5.8, antérieures non vérifiées ». Elle a été
    écrite pour Unreal 5.3+ en évitant ce qu'on sait piéger (masquage C4456–C4459, macros `check`,
    `verify`, `IN`, `OUT`, fonctions `static` homonymes fusionnées par les « unity builds », `FChange` et
    `FJsonValue` qui existent aussi dans Unreal — tout est qualifié `MBPaint::`). Son README le dit.
  ⚠ **`tiles.glb` NE NOMMAIT AUCUN MAILLAGE** — mesuré sur le fichier : seuls les NŒUDS portaient les
  noms. Godot et Unity lisent les nœuds ; l'importeur d'Unreal fait un `StaticMesh` par MAILLAGE : les
  tuiles y seraient arrivées indiscernables. Corrigé dans `FormatNeutre.exporter`, gardé par
  `test_greffon_peinture` (lu dans le JSON du fichier). ⚠ **ET LA PREMIÈRE CORRECTION ÉTAIT FAUSSE** :
  l'export glTF de Godot tient UN espace de noms pour nœuds et maillages — nommer le maillage dans la
  scène renommait le NŒUD en « …_22 », 14 tuiles introuvables, vu rougir. Le nom est posé dans l'état
  glTF, APRÈS `append_from_scene`, en recopiant celui du nœud (`GLTFMesh.resource_name`).
- **L'UI DES TROIS GREFFONS RESSEMBLE AU LOGICIEL, EN COMPACT — DEMANDÉ PAR JORDAN (29 septembre 2026)** :
  « en plus compact, et forcément minimale car on ne fait que peindre ». La barre de droite de l'appli,
  repliée : ses ICÔNES, ses groupes (visée · outil · pinceau · étage · sélection), son olive, et **seulement
  ce que l'outil courant utilise** (le pinceau pour Add · Dig · Select, Hollow pour la Box, la sélection
  quand il y en a une, Paste quand on a copié) — la règle de `_contexte()`.
  - Godot : `mb_toolbar.gd`, UNE rangée d'icônes au-dessus de la vue 3D. ⚠ **SORTIE DE `plugin.gd` POUR
    ÊTRE ÉPROUVÉE** : `EditorPlugin` ne s'instancie pas hors de l'éditeur, et la section de test qui le
    tentait s'arrêtait EN SILENCE sur « null » — une sentinelle le voit désormais. ⚠ **PAS `flat`** : Godot
    ne dessine AUCUNE stylebox sur un bouton plat, et l'outil enfoncé n'était qu'une teinte olive
    illisible (vu à l'image, `DEV_TOOLS/capture_barre_greffon.gd`) ; il porte la plaque olive de l'appli.
  - Unity : l'inspecteur, bouton « Paint the world », rangées d'icônes segmentées. Unreal : un
    `FModeToolkit` (`MarchingBlocksModeToolkit`, Slate) dans la boîte à outils du mode, qui lit l'acteur
    SÉLECTIONNÉ à chaque dessin ; les réglages restent sur l'acteur (enregistrés avec le niveau).
  - ⚠ **LES ICÔNES ONT UNE SEULE SOURCE, `app/icones.gd`** : `DEV_TOOLS/generer_icones_greffons.gd` écrit
    les tracés SVG pour Godot (`mb_icons.gd`), des PNG en base64 pour Unity (`MBIcons.cs` — le SVG
    demanderait un paquet, un PNG d'un paquet immuable des réglages d'import figés) et des PNG pour
    Unreal (`Resources/Icons`, style Slate enregistré par le module éditeur). `test_greffon_peinture`
    rougit si un fichier est PÉRIMÉ et si une source demande une icône qui n'existe pas (lu dans le TEXTE
    des trois sources).
  - **MESURÉ** : `test_greffon_peinture` (la barre : ce qui s'affiche par outil, l'état relu, un clic mène
    l'éditeur, aucun bouton sans icône) ; **huit mutations, toutes rouges** (Hollow partout, pinceau
    partout, sélection toujours, forme non relue, une icône mal nommée dans CHACUN des trois greffons, un
    tracé retouché dans l'appli sans relancer). Unity 6.6 : **21 tests sur 21** (dont les 32 PNG décodés).
    Unreal 5.8.3 : **BuildPlugin sans avertissement**, 32 icônes empaquetées.
  - ⚠ **RIEN N'A ÉTÉ VU DANS LES TROIS ÉDITEURS** : la barre Godot a été photographiée hors de l'éditeur
    (thème par défaut) ; l'inspecteur Unity et le panneau Unreal n'ont été ni dessinés ni cliqués.
- **LE FORMAT DU MONDE PEINT v1 — DÉCIDÉ (Jordan, 29 septembre 2026)** : « dans WORLD, une section
  pour gérer le monde peint, déjà l'exporter vers les trois addons ». `addons/marchingblocks_core/
  format_monde.gd` écrit un dossier `<projet>.mbworld/` : `world.json` (les couches DANS L'ORDRE : nom,
  visibilité, jeu de tuiles, cases) et un `.mbset` par SOURCE distincte, DANS le dossier.
  - ⚠ **LE MONDE SE SUFFIT À LUI-MÊME** : `world.json` désigne ses jeux par un chemin RELATIF. Un monde
    qui pointerait vers un `.mbset` ailleurs sur le disque arriverait chez l'acheteur sans ses tuiles.
  - ⚠ **UNE SOURCE, UN DOSSIER** : deux couches tranchées du même travail partagent le même `.mbset`.
    ⚠ La garde qui le vérifiait comptait les jeux PAR SOURCE dans le bilan, qui restait à 1 même quand
    chaque couche réécrivait son dossier — mutation muette. On compte désormais les dossiers SUR LE DISQUE.
  - ⚠ **UNE COUCHE SANS TUILES VOYAGE QUAND MÊME** (`"tileset": null`) : ses cases sont du travail. Le
    greffon la rebâtit sans tuiles et le DIT (§3 : l'absence se voit).
  - Les cases sont en espace du FORMAT, à plat par triplets, TRIÉES : un même monde s'écrit toujours
    pareil. Un format plus récent est refusé ; toute entrée malformée refuse le fichier ENTIER, avec sa
    raison.
  - **LA RÈGLE DE LECTURE VIT À UN ENDROIT** (`FormatMonde.lire`), et ses réponses partent en
    `world_conformance.json` avec les trois greffons (9 cas : un monde à case négative, couche cachée,
    couche sans tuiles, couche vide ; huit refus). Le greffon Godot la réimplémente dans
    `mb_world_file.gd` (sans rien charger du cœur) et bâtit un nœud MarchingBlocksWorld par couche
    (Project → Tools → Import MarchingBlocks world…, une seule annulation).
  - **MESURÉ (`test_greffon_peinture`, 117 vérifications)** : les 9 cas ; puis l'appli exporte un monde de
    trois couches (Rock = témoin, Ice cachée de même source, Draft sans tuiles), le greffon le rebâtit :
    cases identiques, visibilité rendue, UN dossier de tuiles, **1 048 poses de Rock identiques à celles
    de l'appli**, Draft sans tuiles et nommée. Mutations rouges : version plus récente acceptée, case en
    double acceptée, visibilité ignorée, chemin du jeu non relatif, un dossier par couche.
  - ⚠ **L'EXPORT DE L'APPLI N'EST PAS MENÉ PAR LA FUMÉE** : il passe par le panneau d'attente, qui pend en
    headless (`frame_post_draw`). Le bouton est gardé par le contexte ; l'écriture, par le test du greffon.
  - **UNITY — MESURÉ** : `MBWorldFile.cs` (C# pur, sur `MBJson`) et `Tools/MarchingBlocks/Import World...`
    (`MBWorldImporter.cs` : une racine, un enfant `MarchingBlocksWorld` par couche, rempli INACTIF puis
    activé selon `visible`, UN groupe d'annulation ; `MarchingBlocksWorld.SetCells` réécrit la liste en
    une passe). Banc .NET : **9 cas de monde sur 9** (avec les 18 de pose et les 69 d'outils). Unity 6.6
    en batch : **15 tests sur 15** — la couche Rock pose **1 048 poses sur 1 048** comme MarchingBlocks,
    Ice (cachée) 20 sur 20. Treize mutations, toutes rouges (dont : l'activer AVANT de lui donner ses
    cases la bâtit à vide). Le monde d'essai est écrit par `preparer_essai_unity.gd`. ⚠ Non tenu en
    main : le menu lui-même, et `ToAssetPath`, sans test.
  - **UNREAL — MESURÉ** : `MBCore/MBWorldFile` (C++ standard) et l'acteur éditeur **MarchingBlocks World
    Import** (bouton `CallInEditor` « Import World » : un `AMarchingBlocksWorld` par couche, dans l'ordre,
    une transaction, relancer REMPLACE ses couches). `core-runner` : **9 cas de monde, 0 échec**, et les
    mutations rouges — dont une que le RUNNER rendait muette (retirer le `clear()` d'un refus : il passait
    un vecteur vide ; il le pré-remplit désormais). **Compilé par `RunUAT BuildPlugin` sur Unreal 5.8.3,
    sans avertissement** — après un C4458 : un local `Layers` masquait `AActor::Layers`, le piège annoncé.
    Mené dans l'éditeur (`UnrealEditor-Cmd -ExecutePythonScript -nullrhi`, projet jetable) sur le vrai
    monde exporté : **Rock 1 048 tuiles**, Ice 20 et masquée, Draft « no tiles », un Ctrl+Z par import.
    ⚠ Seul le NOMBRE de tuiles y est comparé, pas les poses ; aucune mutation dans la couche Unreal ; le
    bouton n'a jamais été cliqué. ⚠ **IL N'Y A PAS DE g++ SUR CE PC** : le banc a tourné avec le clang 22
    livré avec Unity (cible MSVC), mêmes drapeaux (`-fno-exceptions -fno-rtti -Wshadow -Wconversion
    -Werror`).
  - ⚠ **L'EMPREINTE DE GÉOMÉTRIE DU §4 EST PÉRIMÉE** : le témoin rend aujourd'hui **31 120 triangles,
    `819204827d6121ec7e13d41aefdd4dcc`** (mesuré dans Godot ET Unity, qui s'accordent), et non 90 651 /
    `c3876f4f…`. Probablement la découpe sans triangles plats (`cb59fab`) — NON vérifié.
- **LA RÈGLE MULTICOUCHE DANS LES GREFFONS — FAITE (2 octobre 2026)**, rattrapage des couches exclusives (§5) :
  - **la règle écrite** : l'étape 7 de `FormatNeutre.regle()` (les étapes 1-4 lisent l'UNION des couches visibles,
    une case dans deux couches est à la première, un sommet est posé par la première couche, dans l'ordre de priorité,
    qui possède une de ses huit cases, avec SES tuiles ; une couche cachée ne pose rien) ; `FormatMonde.regle()` dit
    que l'ordre de `world.json` est la priorité. ⚠ Rien d'autre ne change dans les formats : un monde d'une couche
    suit la même règle, et un monde déjà exporté se lit tel quel.
  - **les cas** : `conformance.json` porte `layered_cases` (5 mondes : côte à côte avec deux jeux, la priorité
    inversée, une dalle d'une autre couche par-dessus, une couche cachée, une case dans deux couches — 466 poses),
    calculés par `FN.attendu_en_couches` sur `MB.poses_en_couches`. Les trois contrôles exigent qu'ils EXERCENT
    l'union (au moins quatre couches posent autre chose que seules, une couche cachée ne pose rien).
  - **Godot** : `MBRule.placements_layered` (`placements` en est le cas à une couche) ; les `MarchingBlocksWorld`
    FRÈRES d'un même parent sont les couches d'un monde, l'ordre des enfants est la priorité ; `apply_cells` retire
    aux autres couches ce qu'il pose et le REND, l'éditeur le remet à l'annulation (action ET coup de pinceau) ;
    l'import d'un `.mbworld` écrit les cases telles quelles (sans vol) puis rebâtit le monde. ⚠ **LE TEST A DÛ
    CHANGER** : deux essais posés sous la même racine devenaient un seul monde — chacun a son parent.
  - **Unity** : `Rule.PlacementsLayered` ; les composants des GameObjects FRÈRES sont les couches, un GameObject
    inactif est caché ; `Apply` retire aux autres (`Take`) et rebâtit le monde ; le pinceau enregistre TOUTES les
    couches (`Undo.RecordObjects(World.LayerObjects())`). `preparer_essai_unity.gd` calcule l'attendu du monde
    importé par la référence multicouche (la couche cachée Ice : rien).
  - **Unreal** : `FRule::PlacementsLayered` (MBCore) ; les acteurs de même **World Name** sont un monde, ordonné par
    **Priority** (l'import les remplit ; un nom vide garde l'acteur seul) ; `Apply` `Modify()` et vide les autres
    couches dans la même transaction ; `PostEditUndo` rebâtit le monde. ⚠ Deux masquages évités : un local
    `Format` (membre statique de `FRule`, vu rougir par `-Wshadow`) et un local `Layers` (`AActor::Layers`).
  - **MESURÉ** : `test_greffon_peinture` 242 (les 5 cas, et deux nœuds frères sur le VRAI jeu exporté : poses = la
    référence du cœur, le contrôle « seule elle poserait autre chose », le vol par `_commit`, Ctrl+Z / Ctrl+Y, le
    coup déjà appliqué rendu par `_record`, la couche cachée) ; banc .NET et banc C++ (clang de Unity, drapeaux
    d'Unreal) : 18 + 5 cas, 0 échec ; **Unity 6.6 : 28 tests sur 28** (dont `SiblingLayersAreOneWorld` sur le vrai
    témoin, Undo compris) ; **Unreal 5.8.3 : BuildPlugin, BUILD SUCCESSFUL, aucun avertissement**.
  - **MUTATIONS, TOUTES ROUGES** : Godot 7 (propriétaire au plus grand rang, cachée comptée, union réduite à soi,
    pas de vol, pas d'annulation du vol, import par `apply_cells`, dernier au lieu du premier) ; .NET 3 et C++ 3
    (plus grand rang, cachée comptée, dernier au lieu du premier) ; Unity 3 (pas de vol, union réduite à soi,
    cachée comptée).
  - ⚠ **PAS ÉPROUVÉ** : l'acteur et le mode Unreal dans l'éditeur (ni import, ni geste, ni Ctrl+Z) — seule la règle
    l'est, par le banc C++ ; dans Unity, le pinceau de la Scene view n'est pas mené (le test reproduit ce qu'il fait :
    `RecordObjects` puis `Apply`). Rien de tout cela n'a été tenu en main.
- **LA SALLE DANS LES GREFFONS — FAITE (2 octobre 2026)**, rattrapage de la forme « Room » (§5) :
  - **la règle et ses cas** : `epreuve_outils.gd` écrit la règle `room(cells, a, b, floors, up)` (en anglais, dans
    `rules_text`), la borne `room_floors_max` et SIX cas de la sorte `room` (montée, descendue dans la roche — 18 cases
    creusées —, réparée contre une case touchée par une arête, étages bornés, `too_small`, `too_large`), calculés par
    `FS.salle`. Le contrôle exige que les cas EXERCENT chacun de ces six points ; douze sortes de fonctions.
  - **la règle** : `Shapes.room` (Godot), `MBShapes.Room` (C#), `Shapes::Room` (C++) — la coque posée, le dedans
    creusé, la réparation des contacts diagonaux comme une forme qui AJOUTE.
  - **le geste**, tracé comme le Rect, à plat sur la grille QUELLE QUE SOIT LA VISÉE (appuyer, glisser, relâcher —
    UNE annulation) ; réglages Floors (`[` `]`) et Up / Down ; l'aperçu montre la coque. Godot : `special == "room"`
    (barre : bouton Room, Floors, Up / Down) ; Unity : `SpecialShape.Room` (AJOUTÉ EN DERNIER), `SceneRoom` et
    `ApplyRoom` ; Unreal : `EMarchingBlocksSpecialShape::Room` (dernier), `RoomFloors` / `bRoomUp` sur l'acteur,
    `ApplyRoom` en une transaction, le panneau Slate. `Build` refuse `Room` (`unknown_shape`) : elle se trace.
    L'icône `room` (celle de la salle de l'appli) part dans les trois.
  - **MESURÉ** : `test_greffon_peinture` 255 (les six cas ; et le VRAI glissé, en visée Sculpt : la salle montée,
    puis descendue dans un bloc de roche — attendus de `FS.salle` —, un Ctrl+Z, trop étroite refusée et dite) ; banc
    .NET et banc C++ (drapeaux d'Unreal) : 121 cas d'outils, 0 échec ; **Unity 6.6 : 31 tests sur 31** (trois de la
    salle, attendus à la main : 82 cases de coque, 6 creusées, un Undo) ; **Unreal 5.8.3 : BuildPlugin, BUILD
    SUCCESSFUL, aucun avertissement**, 44 icônes.
  - **MUTATIONS, TOUTES ROUGES À LA FIN** : la règle × 3 dans chaque greffon (descente décalée d'un étage, pas de
    réparation, pas de borne d'étages) ; l'éditeur Godot × 3 et Unity × 3 (visée au lieu du sol, sens ignoré, creux
    oublié, pas d'annulation). ⚠ **DEUX D'ABORD MUETTES, ET C'ÉTAIT LE TEST** : en visée Grid, viser la matière tombe
    aussi sur le sol (il fallait Sculpt) ; et sous la grille il n'y avait rien à creuser (il fallait un bloc de roche).
  - ⚠ **PAS ÉPROUVÉ** : le mode Unreal (seul compile) ; la Scene view d'Unity au vrai glissé (le test appelle
    `ApplyRoom`) ; rien tenu en main.
- **OUVERT** : la reconstruction INCRÉMENTALE (écrite dans la règle : seules les colonnes x−1..x, z−1..z
  jusqu'à la hauteur de la case changent) — l'APPLI la fait depuis le 1er octobre 2026 (§5, « Le geste d'une
  case »), les greffons ne la font pas encore (le Unity pose
  un GameObject par tuile : à mesurer sur une vraie carte) ; **éprouver le greffon Unreal dans l'éditeur** (il compile
  sur 5.8, voir plus haut).

### LE FAUX TRAVAIL D'ARTISTE — MESURÉ (29 septembre 2026)

Toutes les mesures du retour venaient du témoin lui-même, dont aucun triangle ne chevauche une coupe et
qui ne porte ni texture ni second objet. `DEV_TOOLS/faux_artiste.gd` fabrique ce qu'un artiste renverrait :
un relief (le gradient d'un champ périodique et invariant par les quarts de tour — un artiste
« discipliné »), un liseré d'herbe SOUDÉ au volume qui sort de sa case, une texture peinte sur les UV
canoniques. `test_faux_artiste` le tranche par le vrai pipeline, chaque garde avec son contrôle négatif
(un relief quelconque, une texture sans discipline, un liseré trop large).

- ⚠ **IL A TROUVÉ TROIS DÉFAUTS RÉELS, que le témoin ne pouvait pas montrer :**
  - **L'ORIGINE DU TRANCHEUR ÉTAIT DÉDUITE DE LA BOÎTE DU MAILLAGE** : un relief qui déborde légalement
    d'un côté du bloc la décalait, et **tous les plans de coupe avec elle** (« le bloc mesure 1,000 de
    trop », 579 remarques). Le bloc est à l'origine PAR CONTRAT : `trancher(…, origine)` la reçoit.
  - **LE LECTEUR NE PRENAIT QUE LE PREMIER MAILLAGE DU FICHIER** : une herbe rangée dans un second objet
    placé d'abord faisait perdre le TERRAIN sans un mot — 2 676 triangles relus sur 33 428. Il lit tout
    (`_tous_les_maillages`), et le bilan le DIT : tous les objets sont tranchés comme du terrain tant que
    les props entiers (§9 bis) n'existent pas.
  - **L'OBJ ÉCRIVAIT `v` SANS LE RETOURNER** : l'OBJ compte depuis le bas, Godot et le glTF depuis le
    haut. Nos propres relectures ne le voyaient pas — elles se trompaient dans les deux sens. Blender, oui.
- **MESURÉ** : relief jusqu'à 0,084 case, 202 triangles à cheval sur une coupe, 1 336 triangles de liseré
  hors de leur case — **541 items, 0 erreur, 0 remarque**, texture et UV sur chaque tuile, tranché en
  ~22 s. Le relief maladroit : 23 remarques ; le liseré trop large : 322.
- ⚠ **L'AIRE DANS UNE BANDE A DES FAUX POSITIFS, MESURÉS** : un liseré qui retombe PRÈS d'un plan de
  coupe sans le franchir entre dans la bande de 0,08 case et fait parler `verifier_couture`, alors qu'il
  ne casse rien. C'est la réserve n°1 de ce contrôle (« une condition nécessaire ») vue sur pièce.
- **MESURÉ DANS BLENDER 5.1** (`DEV_TOOLS/essai_blender.gd` + `.py`, sur le PC) : le témoin OBJ importé
  et réexporté en .glb revient avec **0 UV fausse sur 31 120 triangles** ; le faux travail relu et
  réécrit par Blender se tranche en **541 items, 0 erreur, 0 remarque**. Sans le retournement de `v` :
  31 120 UV fausses, vu rougir.
- **MESURÉ DANS UNITY 6.6** : `TheArtistsTextureArrivesOnEveryTile` — la texture et les UV de l'artiste
  sur les 541 tuiles, par glTFast. ⚠ **IL A D'ABORD ROUGI SUR UN VRAI DÉFAUT** : glTFast ne lit un PNG
  qu'avec les modules intégrés *Image Conversion* et *Unity Web Request Texture* — absents d'un projet
  au manifeste minimal, et la console ne disait que « Failed to import (see inspector) ». Le paquet les
  DÉCLARE désormais, et le test lit le rapport de l'importeur par réflexion pour dire POURQUOI.
  ⚠ Et un faux rouge juste après : un `tiles.glb` au contenu identique n'est pas réimporté, donc il
  gardait l'échec d'avant — le « sujet a-t-il changé » du §6, une fois de plus.

### LES FENTES ENTRE TUILES — MESURÉ (29 septembre 2026)

Jordan a vu, dans le monde peint, des fentes **fines, rectilignes et régulières** à chaque joint de tuile.
La question était « est-ce le trancheur ? ». **Non** — et la réponse a été tranchée par
`DEV_TOOLS/sonde_fentes.gd`, qui assemble le monde peint en espace monde par le VRAI peintre, compte ses
arêtes ouvertes, et le REND deux fois sur fond magenta : en GridMap, puis fusionné en un seul maillage.

- **LE TÉMOIN CALCULÉ EST ÉTANCHE AU BIT PRÈS** : 1 048 tuiles, 0 arête ouverte, et GridMap = fusionné à
  l'image — en OpenGL, en Vulkan logiciel, et sur la RTX 2060 du PC (par `ssh pcjordan`).
- **LE TRAVAIL DE JORDAN ÉTAIT `test_textured_by_tripo.glb`** (lu dans le projet ouvert, `test.mbproj`) :
  **39 097 arêtes ouvertes, 99 % sur un plan de coupe, larges de 0,0026 case en médiane** (90 % sous
  0,008). Et le rendu fusionné montre EXACTEMENT les mêmes fentes que le GridMap (104 pixels contre 104) :
  ⚠ **ce n'est pas le GPU, c'est de la géométrie**, et ce n'est pas la découpe — c'est l'art (§3, Tripo).
- ⚠ **L'INSTRUMENT QUI POUVAIT MENTIR A ÉTÉ CONTRE-VÉRIFIÉ** : le premier rendu montrait un quadrillage
  clair entre TOUTES les tuiles — c'était la grille `Cases` (cubes translucides de 0,98), que l'appli
  masque (`vue.gd`). Et une hypothèse « la grille d'étage se dessine sur les sols » a été démentie à
  l'image, à trois étages.

**CE QUE ÇA A RÉVÉLÉ CHEZ NOUS, ET QUI EST CORRIGÉ :**

- ⚠ **`verifier_couture` ÉTAIT AVEUGLE AUX FENTES** : AUCUNE remarque pour 39 097 arêtes ouvertes (la
  seule remarque du bilan était celle de texture — je l'ai d'abord comptée comme de couture). Une aire
  dans une bande de 0,08 case ne voit pas un bord décalé de trois millièmes ; et ses seaux (le germe
  orienté) ne réunissent même pas les faces qui SE RENCONTRENT — la face x+ d'une tuile et la face x− de
  sa voisine lisent les mêmes quatre cases, mais sont deux germes dès que le motif n'est pas symétrique.
- **ÉCRIT : `Tranchage.verifier_sections`** (appelée par `trancher()`, une REMARQUE préfixée
  « couture »). La SECTION d'une tuile sur un plan, ce sont les arêtes que la découpe y a laissées. Le
  seau est ce que le monde met FACE À FACE : l'axe du plan et le motif de ses quatre cases vu du plan,
  le côté oublié ; chaque tuile y entre sous chacune des orientations que le peintre lui donne vraiment
  (`MB.classer` sur l'orbite). Toutes les sections d'un seau doivent coïncider à `ECART_DE_SECTION` près
  (0,001 case, **PROPOSÉ**), dans les deux sens. Et une face aux quatre cases toutes vides ou toutes
  pleines doit avoir une section VIDE : en face, le sommet est souvent muet, rien ne bouchera.
  - **MESURÉ** : témoin 0 remarque ; faux travail discipliné 0 ; faux maladroit 7 945 faces ; coût
    1,3 s sur les 541 tuiles. **Et `test_textured_by_tripo.glb`, sur le PC : 7 070 faces, pire écart
    0,0166 case** — là où `verifier_couture` se taisait.
  - **Gardé par `test_tranchage` §10**, sujets bâtis à la main dans le repère de RÉFÉRENCE de leur classe
    (⚠ le premier jet ne l'était pas — un mur aux cases x = 0, alors que la référence est la plus petite
    configuration de l'orbite, z = 0 — et le contrôle l'a refusé à juste titre). Six mutations rouges :
    le côté dans le seau, les faces vides ignorées, la tolérance ×10, un seul sens, une seule pose, et les
    triangles plats gardés (`test_decoupe` §7). ⚠ **« UN SEUL SENS » ET « UNE SEULE POSE » ÉTAIENT
    MUETTES** — le test était trop étroit (§6) : il fallait une section qui en CONTIENT une autre
    (l'aileron), et deux CLASSES qui ne se rencontrent que sous un quart de tour (un sol bombé en x² et
    une arête) — un quart de tour tourne toutes les tuiles d'une classe ensemble, donc les poses tournées
    ne servent qu'entre classes.
- ⚠ **LA DÉCOUPE FABRIQUAIT DES TRIANGLES PLATS PAR MILLIERS** : un sommet posé SUR un plan de coupe est
  gardé des deux côtés, et le triangle voisin qui touche la boîte par une arête laissait un polygone
  réduit à un segment, que l'éventail triangulait. **32 190 triangles d'aire nulle sur 49 802** dans les
  tuiles du témoin, tous sur les joints. `Decoupe._plat` les écarte : **17 612 triangles, 0 plat**, et le
  tranchage passe de 17,7 s à 16,8 s. ⚠ **Ils faussaient aussi la sonde** : sur le faux travail d'artiste,
  leurs arêtes sans partenaire faisaient 109 « fentes » de plus de 0,05 case ; sans eux, il reste des
  jonctions en T sous 0,001 case (90 % sous 0,00004) — deux triangulations qui se croisent, invisibles.
- **OUVERT** : afficher QUELLES faces ne raccordent pas (aujourd'hui : un compte, le pire écart et une
  paire) ; les jonctions en T entre deux triangulations peuvent encore scintiller d'un pixel sur un GPU,
  sans avoir été vues.

## 5. L'éditeur — ce que GridMap donne, et ce qu'il faut écrire

**MESURÉ (`DEV_TOOLS/sonde_api_editeur.gd`)**, et c'est la réponse à la question de Jordan :

- **L'API de DONNÉES du GridMap est COMPLÈTE** : `set_cell_item`, `get_cell_item`, `get_used_cells`,
  `get_used_cells_by_item`, `get_cell_item_orientation`… Tout est lisible, tout est modifiable : on peut
  bâtir **n'importe quel outil** dessus.
- ⚠ **Ce qui manque n'est pas la donnée, c'est l'INTERACTION** : `GridMap` n'expose **aucune notion de
  sélection** (13 méthodes de cases, pas une de sélection). La sélection en boîte appartient à son
  éditeur C++.

**DÉCIDÉ — on COMPLÈTE, on ne remplace pas.** Le pinceau natif pose et efface une case très bien ; ce
qu'il faut écrire, c'est la couche au-dessus — tout ce qui porte sur plus d'une case.

- ⚠ **En 3D, un clic est un RAYON, pas une case** : il faut une profondeur. Deux voies — contre le plan
  de **l'étage courant** (ce que fait l'éditeur natif avec son niveau de sol, et ce que fait déjà notre
  compteur d'étage), ou contre la **géométrie posée** (plus naturel pour extruder une paroi, plus cher).
- `_forward_3d_gui_input`, `_forward_3d_draw_over_viewport` et `_handles` existent : une sélection
  maison est faisable. **OUVERT** — elle n'est pas écrite.
- **DÉCIDÉ (Jordan, 24 septembre 2026)** — en attendant, les opérations portent sur un **ÉTAGE** :
  étendre vers le haut, vers le bas, élargir, creuser. C'est le geste qu'on fait le plus en montant un
  massif.
- ⚠ **Le greffon occupe la BANDE DE DROITE de la vue 3D** (`CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT`), plus
  l'écran entier. Avec `_has_main_screen()` il REMPLAÇAIT la vue 3D : on ne pouvait pas peindre et voir
  ses outils en même temps, ce qui est pourtant tout l'usage.
- ⚠ **TOUTE opération passe par `get_undo_redo()`.** Un bouton qui réécrit des cases sans que Ctrl+Z les
  rattrape abîme une peinture sans retour. Et l'on reconstruit **dans les deux sens**, sinon annuler
  laisse un rendu qui ne correspond plus à ses cases.
- ⚠ **L'UI RESTE MINIMALE (Jordan, 24 septembre 2026).** Elle a compté deux onglets, une vue 3D
  orbitale, un catalogue et un panneau de tranchage : chaque pièce se justifiait seule, ensemble elles
  noyaient ce qu'on veut faire. Il reste la boucle complète et rien d'autre.
- **DÉCIDÉ (Jordan, 27 septembre 2026) — la boucle a quatre boutons, et leurs noms** : « Trancher le
  témoin pour tester » (le témoin calculé, un massif vide à peindre) · « Exporter le témoin… » ·
  « Importer le travail… », qui **l'AFFICHE seulement**, dans la vue et tel que le trancheur le lira
  (`BlocsMaitres.travail_depuis_glb()`, la même lecture que le tranchage) · « Trancher le travail »,
  qui relit ce travail au moment du clic, pose les nœuds et **peint les cases du témoin**
  dans la même action d'annulation. Le résultat doit redonner le témoin : c'est la preuve de
  l'aller-retour, à l'œil. Tout est dans une **barre de défilement verticale** : le bas de la bande
  était inatteignable.
  ⚠ **ET TOUT TEXTE Y EST REPLIABLE (`_assouplir`), sinon le panneau DÉBORDE À DROITE sous la vue 3D.**
  Sans défilement horizontal, la barre prend la largeur minimale de son texte le plus long — mesuré,
  **647 px** pour l'étiquette d'étage allongée, **16 px** une fois repliable. Le défaut n'apparaissait
  que « parfois » : quand l'étage ou le nom du fichier importé s'allongeait.
  ⚠ Mesurer une taille minimale hors de l'arbre rend la valeur en CACHE : la première mesure disait
  « rien ne change ». Elle se prend dans l'arbre, une image plus tard.
  ⚠ Ces libellés sont en français, alors que le §7 veut l'anglais à l'écran : c'est **OUVERT**, et toute
  l'UI est dans le même cas.

---

### LE MODELEUR DU TÉMOIN — DÉCIDÉ (Jordan, 29 septembre 2026), PAS ÉCRIT

Jordan : « une barre de droite pleine d'outils de modélisation du témoin dans le mode Witness — imiter
toutes les fonctions de modélisation et raccourcis de Blender, ainsi que matériaux et texturing ».

- **IL REMPLACE BLENDER.** L'artiste ne quitte plus l'appli : le maillage du témoin devient une DONNÉE
  qu'on édite, enregistrée dans le projet, et le trancheur la lit directement. L'export `.obj` et
  l'import `.glb` restent pour qui préfère Blender. C'est aussi l'occasion de faire respecter le contrat
  PENDANT qu'on modélise — plans de coupe visibles, props séparés (§3), raccords de texture vérifiés.
- **PALIER 1 : L'ÉDITION DE MAILLAGE** — modes sommet / arête / face (1 2 3), sélection (clic, Maj, B, A,
  Alt+clic en boucle), G R S avec contrainte d'axe X Y Z et saisie numérique, E extrude, I inset, Ctrl+B
  bevel, Ctrl+R loop cut, K knife, M merge, X delete, F fill, subdivide, O proportionnel, vues du pavé
  numérique, Tab objet / édition.
- **LE TEXTURING = MATÉRIAUX + PROJECTIONS** : des matières tuilables assignées et projetées (UV, box),
  réglées pour tenir la discipline des coupes (§3). La peinture sur maillage n'est PAS demandée.
- ⚠ **LE CODE DE BLENDER NE SE RECOPIE PAS, ET CE N'EST PAS UNE PRÉFÉRENCE : Blender est sous GPL.** Le
  reprendre ou le traduire dans un exe vendu et chiffré obligerait à publier tout MarchingBlocks sous
  GPL. On reproduit le COMPORTEMENT (gestes, raccourcis, résultats) — libre —, avec des algorithmes
  écrits ici, et chaque geste gardé par un test.
- **ORDRE (Jordan)** : l'export du monde d'abord, le modeleur ensuite.
- **PALIER 1 — ÉCRIT (29 septembre 2026)** :
  - **Le cœur, `addons/marchingblocks_core/maillage_edite.gd`** : des sommets, des faces à N côtés
    trigonométriques vues de dehors (l'INVERSE de Godot : la conversion vit dans `depuis()` et
    `vers_array_mesh()` seulement), une teinte par face, PAS d'arête libre. La lecture RECOLLE les quads
    (toute paire de triangles coplanaires, convexe, qui partage une arête en sens opposés) : le témoin
    revient en **15 560 quads, étanche et orienté**. Opérations : G R S (avec proportionnel), extrusion de
    RÉGION et d'arêtes, inset à bissectrice, supprimer, fusionner, remplir orienté par ses voisines,
    subdiviser sans fente en T, anneau et loop cut, boucle d'arêtes, rayon.
    **`test_maillage_edite`, 77 vérifications**, jugées par des invariants qui ne passent pas par le
    code (étanche, orienté, Euler, volume par la divergence, positions à la main). Huit mutations
    rouges ; DEUX ONT D'ABORD ÉTÉ MUETTES, par un test trop étroit : F n'était essayé que dans un ordre
    qui tombait juste, et l'anneau que sur un cube, où il se referme avant d'exercer son second sens.
    ⚠ **TROIS DÉFAUTS ONT ÉTÉ TROUVÉS PAR CES TESTS** : le recollage ne reconnaissait qu'un motif (un cube
    relu revenait en triangles), l'anneau prenait la mauvaise arête opposée (la coupe zigzaguait), et un
    attendu de boucle était faux — la boucle d'une rangée intérieure traverse la rangée, comme Blender.
  - **L'écran, `app/modeleur.gd`**, et une barre de droite propre à l'atelier Witness. Tab entre en
    édition ; 1 2 3 (par leur PLACE) ; clic sur ce qu'on VOIT (le rayon trouve la face, puis le sommet ou
    l'arête de cette face), Maj+clic, Alt+clic (boucle), A, Alt+A, B ; G R S avec X Y Z et saisie
    numérique, Entrée ou clic pour valider, Échap ou clic droit pour annuler ; E, I, Ctrl+R, X, M, F,
    subdiviser, O ; vues du pavé (1 3 7, Ctrl, 5, « . »). **Z MONTE, comme dans Blender** (`AXES`).
    Chaque geste est UNE annulation de l'historique de l'appli.
  - **LE TÉMOIN MODÉLISÉ PREND LA ROUTE DES TRAVAUX** : il s'enregistre (une seconde après le dernier
    geste) en `<projet>_witness.glb` et entre dans la liste de l'étape 2, où on le tranche. Une seconde
    route de tranchage trancherait autrement (§6).
  - ⚠ **MESURÉ : UN REDESSIN COMPLET DU TÉMOIN COÛTE ~250 ms** — un G qui suit la souris aurait tourné à
    quatre images par seconde. Pendant un geste, ce qui ne bouge pas est dessiné UNE fois, et seul ce qui
    bouge est redessiné : **2,6 ms par mouvement de souris**. ⚠ L'inset (I) change la topologie à chaque
    mouvement et redessine encore TOUT : plus lent, à mesurer à la main.
  - **Gardé par `fumee_appli`** (20 vérifications, avec de vraies touches et un vrai clic sur le témoin :
    E 1, Ctrl+Z / Ctrl+Y, G Z 2, Échap, X, Ctrl+R, l'enregistrement relu). Mutations rouges : Z = Z de
    Godot, Échap qui ne rend rien, geste sans annulation, clic sur la mauvaise face.
  - ⚠ **LA MINUTERIE D'ENREGISTREMENT A FAUSSÉ LA FUMÉE** : elle réécrivait le témoin modélisé APRÈS sa
    suppression, et le passage suivant partait d'un témoin déjà coupé. La fumée et la capture partent
    désormais d'un état propre.
  - ⚠ **LA FUMÉE CONCLUAIT « OK » SUR UN ÉCRAN QUI NE COMPILAIT PAS** (98 vérifications, 0 échec). Elle
    exige d'abord que `editor.gd` se charge, et s'arrête net sinon — vu rougir.
  - **LE BISEAU (Ctrl+B) ET LE COUTEAU (K) — ÉCRITS LE 29 SEPTEMBRE 2026.** Biseau : chaque coin touché
    recule de la largeur sur l'AUTRE arête (point partagé avec la voisine), ou à l'ONGLET quand ses deux
    arêtes sont biseautées ; chaque arête devient un quad ; les trous des bouts sont rebouchés à l'envers
    de leurs bords. ⚠ Au bout d'une chaîne, un petit triangle COPLANAIRE garde le sommet d'origine, là où
    Blender couperait le coin : même forme, une face de plus. Couteau : des points SUR les arêtes, deux
    points consécutifs sur une même face ; sinon RIEN n'est coupé (retour arrière complet), et on le dit.
    **MESURÉ par des volumes écrits à la main** : une arête biseautée de 0,25 → 0,96875 ; les quatre du
    dessus → 0,75 + 0,25/3 (1 + 0,25 + 0,5). `test_maillage_edite` 94, cinq mutations rouges (onglet sans
    sinus, bouts non rebouchés, quad retourné, point du couteau dans une seule face, pas de retour
    arrière) ; la fumée mène Ctrl+B 0.1 et K sur le vrai témoin (125), deux mutations rouges.
  - **LES MATÉRIAUX ET LES PROJECTIONS — ÉCRITS LE 29 SEPTEMBRE 2026.** Chaque face porte un indice de
    matériau (`mats`, −1 = la teinte de la légende), qui suit la teinte dans CHAQUE opération (une face née
    d'une autre prend son matériau). Un matériau : couleur, rugosité, métal, image facultative, échelle.
    ⚠ **LES UV NE SONT PAS STOCKÉS, ILS SE PROJETTENT DEPUIS LA POSITION** (boîte, axe dominant de la
    normale, le signe de l'axe dans u pour que deux murs opposés ne soient pas en miroir) : une face née
    d'une extrusion est texturée sans rien déplier, et une image tuilable dont la répétition divise la case
    se raccorde d'une tuile à l'autre. Une SURFACE par matériau ; la barre du modeleur a sa section
    Materials (New, Assign, nom, couleur, rugosité, métal, répétition, image), et une rafale de retouches
    fait UNE annulation.
    **MESURÉ, LE TRAJET ENTIER** (`test_maillage_edite`) : un matériau posé dans le modeleur arrive dans
    les tuiles TRANCHÉES, puis dans celles que le GREFFON Godot charge depuis `tiles.glb`. Vu à l'image : une
    texture projetée sur les 2 965 faces du dessus, continue sur tout le bloc.
    ⚠ **LE MODÈLE S'ENREGISTRE EN `.mbmesh` (JSON), ET LE .glb N'EN EST QU'UNE SORTIE** : relire le .glb
    regroupe les faces par surface, et l'assignation se serait perdue à chaque réouverture.
    ⚠ **TROIS DÉFAUTS VUS AVANT D'ÊTRE LIVRÉS** : un `material_override` unique (la couleur de sommet)
    effaçait tous les matériaux, à l'écran ET dans le .glb — chaque surface porte désormais le sien, la
    légende comprise ; les couleurs passaient par l'hexadécimal, arrondi à 1/255, et les teintes de la
    légende auraient dérivé à chaque enregistrement ; et `_ajouter` complète `mats` avant d'ajouter, sinon
    un maillage bâti à la main décalait les matériaux sur les mauvaises faces.
    Mutations rouges : projection sans le signe, côtés extrudés sans matériau, surface sans son matériau,
    retour de l'hexadécimal, override à l'export, `.mbmesh` non relu, une annulation par retouche — et
    « supprimer oublie les matériaux », d'abord MUETTE : le test comptait les matériaux, pas LA face qui
    le portait.
  - **L'ACCÉLÉRATEUR DE RAYONS, LA BOÎTE QUI IGNORE LE CACHÉ, ET LES PROJECTIONS PLANES (29 septembre 2026).**
    ⚠ Un rayon brut testait les 15 560 faces (~25 ms). Une GRILLE range chaque face dans les cases de sa
    boîte ; le rayon ne teste que les cases qu'il traverse (Amanatides & Woo) et s'arrête quand un impact
    est plus proche que la sortie de la case. **MESURÉ** : sur 300 rayons au hasard, la même face et la
    même distance que le rayon brut, qui reste la référence, et au moins cinq fois plus vite. ⚠ La mutation
    « s'arrêter au premier impact » était MUETTE sur les rayons au hasard : un PIÈGE construit à la main
    (une grande face pentue rangée dès la première case, touchée loin ; une petite, plus proche, plus
    loin dans la grille) la fait rougir.
    La boîte B ne prend plus que ce qu'on VOIT (un rayon par élément) ; **Alt+Z** (X-ray) prend tout, faces
    de dos comprises, comme Blender — l'X-ray écartait encore les faces de dos, vu en mutation. La garde
    de l'occlusion compare aux faces TOURNÉES VERS L'ŒIL, pas au X-ray : « moins qu'en X-ray » restait vrai
    sans un seul rayon.
    L'inset et le biseau ne redessinent plus que les faces qu'ils touchent : **~60 ms** par mouvement de
    souris au lieu de plus de 250.
    Projections : Boîte, Dessus, Face, Côté — les planes appliquent une formule à toutes les faces.
  - **LE MANUEL (F1) LE DIT** : un onglet « Modelling the witness » (édition, transformations, maillage,
    matériaux, vue — et l'avertissement sur les textureurs automatiques), l'export du monde dans « Layers &
    projects », et des raccourcis rangés par atelier (World, Witness, Play test). Vu à l'image.
  - **LE DÉPLIAGE (U) — DEMANDÉ PAR JORDAN (29 septembre 2026)**, pour peindre des textures qui ne se
    répètent pas. ⚠ **CE N'EST PAS LE « UNWRAP » EXACT DE BLENDER (LSCM)** mais l'équivalent de son « Smart
    UV Project » : des ÎLOTS de faces voisines dont la normale reste à moins de 66° de celle qui a lancé
    l'îlot ; chacun mis À PLAT sur son plan moyen ; rangés par étagères dans [0,1] à UNE échelle.
    Les UV sont stockés par coin de face, gardés quand une face est seulement DÉPLACÉE, effacés quand elle
    est déformée (on ne devine pas l'UV d'un point neuf) : la face retombe sur la boîte et l'écran dit
    combien sont à redéplier. Le matériau prend une projection « UV » ; **Export UV layout…** écrit le
    patron en PNG (2048²), à peindre ailleurs. **MESURÉ** : tout dans [0,1], aucun texel dans deux îlots
    (compté en pixels), une échelle unique, les carrés restent carrés, aucun îlot en MIROIR ; le témoin
    entier en 366 îlots, 248 ms ; vu à l'image. Mutations rouges : étagère qui ne descend pas, îlot en
    miroir, ménage qui efface tout, U ignoré — et « une échelle par îlot », d'abord MUETTE sur le cube
    (îlots tous égaux) : un pavé 2×1×1 la fait rougir.
    ⚠ `trait` est devenu un MOT RÉSERVÉ de GDScript 4.7 : `var trait :=` ne compilait plus.
  - **LE COUTEAU TRAVERSANT — DEMANDÉ PAR JORDAN ET ÉCRIT (2-3 octobre 2026 : « le knife sur une edge de bord de tuile
    répétée […] pour créer des motifs qui traversent les bords, afin que les bords soient masqués par des formes, et
    que ça noie l'aspect quadrillé des massifs »).** ⚠ **AUCUN PLANTAGE REPRODUIT** (`DEV_TOOLS/sonde_couteau_bords.gd` :
    toutes les coupes de bord sur les 52 tuiles ; `sonde_couteau_ecran.gd` : 48 couteaux menés à la souris, avec et sans
    fenêtre). Ce qui empêchait les motifs : **un clic sur la copie voisine, au-delà d'un bord, était ignoré sans un
    mot**, et un pas entre deux points sans face commune faisait refuser toute la coupe.
    - **le clic vise la copie sous la souris** (`temoin.rayon`), posé sur l'arête la plus proche, dans le repère de SA tuile ;
    - **le tracé** (`_trace_du_couteau`) : deux points d'une même copie qui partagent une face, directement ; sinon le
      trait est suivi À L'ÉCRAN, comme Blender — chaque changement de (copie, face) trouvé par dichotomie : l'arête
      commune dans une copie, l'arête de BORD des deux côtés d'une copie à sa voisine ;
    - **chaque copie traversée coupe SA tuile** (`MaillageEdite.couper_aux_positions` : les points retrouvés sur le
      maillage tel qu'il est au moment de les insérer), puis `Sections.completer` reporte les points de bord ; UN
      Ctrl+Z (`TL.Lot`) pour toutes les tuiles ; un morceau qui échoue rend tout, et l'écran dit pourquoi ;
    - ⚠ **UN DÉFAUT RÉEL, TROUVÉ EN ÉCRIVANT** : `couper` lisait toutes les arêtes AVANT la première insertion ; deux points
      qui se suivent sur la même arête (un trait qui la longe) — le second ne retrouvait plus son arête, et toute la coupe
      était refusée. Et un clic pile sur un bord, compté dans les deux copies, laissait à l'une un morceau d'un seul
      point, qui faisait tout refuser : il est sauté.
    - **MESURÉ** : sur les 48 couteaux de la sonde, 44 coupent (4 : les trois clics de la sonde tombent au même endroit),
      0 sommet de joint sans partenaire, chaque Ctrl+Z complet. Gardé par `test_maillage_edite` (170 : la coupe par
      positions sur le cube, attendus à la main) et `fumee_appli` (620 : K, un clic dans la paroi, un clic AU-DELÀ du
      bord, Entrée — « across 2 copies », joints fermés, UN Ctrl+Z). Cinq mutations rouges (la copie voisine ignorée,
      pas de passage d'une copie à l'autre, pas de report, l'annulation sans les autres tuiles, la coupe par arêtes
      figées). Tests lancés dans une COPIE à dossier de données isolé (d'autres sessions travaillaient dans le dépôt).
    - ⚠ **PAS TENU EN MAIN.** Le trait suit ce que la caméra VOIT : une copie cachée derrière une autre coupe le trait
      (« crosses empty space », « hidden behind another »). Un point dans une face est collé à son arête la plus proche.
  - **LE LASSO ET LE CERCLE — DEMANDÉS PAR JORDAN ET ÉCRITS (2 octobre 2026)** : « la sélection en mode Geometry de
    Witness des vertices, edges ou faces au lasso, ou cercle ». Jordan : c'est la DERNIÈRE fonction du logiciel.
    - les gestes de Blender : **Ctrl + clic droit glissé** = lasso (Maj + Ctrl retire), ou le bouton « Lasso » puis
      le clic gauche ; **C** = le cercle : on PEINT au clic gauche, Maj ou le clic du milieu retire, la molette règle le
      rayon, clic droit / Échap / Entrée finit. Le tracé se dessine sur un calque 2D de la vue.
    - **UNE SEULE RÈGLE** (`_choisir_si`) pour la boîte, le lasso et le cercle : sommet par son point, face par son
      centre (et la règle des faces de dos), arête par ses DEUX bouts (boîte, lasso) ou par son MILIEU (le cercle,
      qu'on promène comme un pinceau) ; seulement ce qu'on voit, sauf en X-ray (Alt+Z). Le cercle AVALE les touches,
      comme Blender.
    - **MESURÉ** : `fumee_appli` 455, par de VRAIS événements de souris, attendus calculés par la caméra seule en X-ray
      (le triangle, le disque, les milieux d'arêtes). Sept mutations rouges ; ⚠ deux pièges du TEST, pas du code : posé
      au centre de l'écran, le triangle ne couvrait aucun sommet (« exactement eux » passait sur 0 = 0), et vue de face
      depuis le bloc entier, une tuile de paroi faisait 3 pixels de large (les points du lasso tombaient à moins de
      4 pixels) — caméra en perspective, tout près de la tuile. « Les arêtes par leurs deux bouts » d'abord MUETTE :
      aucun test en mode arête. Vu à l'image (le contour du lasso, le cercle).
    - ⚠ **PAS TENU EN MAIN.**
  - **PAS ENCORE ÉCRIT** : une projection cylindrique ; un vrai LSCM ; un rangement plus serré (la marge
    visée laisse ~20 % de patron vide). Rien n'a été tenu en main.
  - **WITNESS GEOMETRY ET WITNESS TEXTURING — DÉCIDÉ (Jordan, 1er octobre 2026), ÉCRIT LE MÊME JOUR** : « faire
    sortir du mode Witness, renommé Witness geometry, un second mode Witness texturing, vu que je compte y
    rajouter de quoi dessiner la texture ou dessiner sur l'UV avec les outils de peinture classiques ». Cinq
    ateliers (Project · World / Geometry · Texturing / Play test), le même témoin et la même édition dans les
    deux ; seule la barre de droite change. Geometry : modes, sélection, transformations, maillage, vue, le
    témoin modélisé. Texturing : modes, sélection, Materials (projection, dépliage U, patron UV) — et la
    peinture à venir. Ce qui existe dans les deux barres (Tab, 1 2 3) se suit. ⚠ **DANS TEXTURING ON NE MODÈLE
    PAS** : G R S E I K X M F O ne touchent à rien et l'écran renvoie à Geometry (`Modeleur.geometrie`) ; A, B,
    U, 1 2 3 marchent. Gardé par `fumee_appli` (+9), deux mutations rouges ; vu à l'image (`capture_app.gd`).
  - **LA PEINTURE — DÉCIDÉ ET ÉCRIT (Jordan, 1er octobre 2026 : « go pour la peinture »), PALIER 1 : en 3D, sans
    calques.** Le cœur, `addons/marchingblocks_core/peinture.gd` : une TOILE par chemin d'image, PARTAGÉE (toutes les
    tuiles qui portent le matériau lisent la même `ImageTexture` — `MaillageEdite.materiau_godot` la demande) ; le
    tampon (dureté, opacité, l'image REPLIÉE comme la répétition de la texture), le trait, la pipette, l'écriture.
    ⚠ **ON PEINT LÀ OÙ LE RENDU LIT** : `MaillageEdite.uv_au_point` rend l'UV que `vers_array_mesh_de` donne au point
    touché (UV dépliés interpolés, sinon la projection du matériau). Dans Texturing, **P** : le clic gauche glissé
    peint, Alt+clic lit la couleur ; un matériau sans image reçoit une toile de 1024² de sa couleur et passe au
    BLANC (sinon sa couleur multiplierait la peinture) ; une face de la légende refuse, et le dit. UN Ctrl+Z par trait
    — l'historique garde la RÉGION touchée, avant et après, pas l'image entière. Les toiles s'écrivent avec le témoin
    (dans `<couche>_images/`), avant son `.glb`, qui les embarque : le monde les porte.
    ⚠ **DEUX DÉFAUTS VUS À L'IMAGE, AUCUN TEST NE LES AURAIT DITS** (`DEV_TOOLS/capture_peinture.gd`, avec fenêtre) :
    un trait parti d'une face de la légende ne peignait plus rien, même passé sur la matière ; et les traits sortaient
    en POINTILLÉS — un trait n'était relié que sur une même face, et les faces des tuiles sont petites. Le mouvement
    est désormais coupé en deux tant que deux impacts sont à plus d'un demi-rayon sur la toile.
    ⚠ **LE HEADLESS NE GARDE PAS `ImageTexture.update`** (mesuré : avec fenêtre, si) : les gardes vérifient que la
    texture du matériau EST la toile ; l'affichage se juge à l'image.
    **MESURÉ** : `test_peinture` (19 : un tampon dur = les 45 texels du disque, mi-opacité, douceur, repli aux quatre
    coins, trait sans trou, l'UV de `uv_au_point` = celle des tableaux du RENDU au centre de chaque triangle en Boîte,
    plane et dépliée, toile partagée, annulation au bit près, écriture relue) ; `fumee_appli` (+11 : un vrai trait à la
    souris sur une copie de la paroi, Ctrl+Z / Ctrl+Y, disque, `.glb`, pipette, Geometry qui éteint le pinceau). Six
    mutations rouges.
    ⚠ **LIMITES, À DIRE** : en Boîte, l'image se répète, donc la peinture aussi (un long trait dessine un motif) ; et
    **le dépliage (U) range chaque tuile dans le MÊME carré** — deux tuiles d'un même matériau en projection UV
    partagent leur peinture.
  - **L'ATLAS DU TÉMOIN — ÉCRIT LE MÊME JOUR** (Jordan : « go ») : `TemoinLie.deplier_en_atlas` range les îlots de
    TOUTES les tuiles ensemble, à une échelle ; le bouton « Unwrap all tiles (atlas) » le fait pour le matériau
    courant et le passe en UV, UNE annulation pour toutes les tuiles. Le dépliage d'une tuile a été coupé en
    `ilots_a_plat` · `ranger` · `poser_uvs` (sortie inchangée, `test_maillage_edite` 160 vert). **MESURÉ**
    (`test_peinture` +5) : tout dans [0,1], densité égale à 2 % près, **0 texel revendiqué par deux tuiles**
    (pixellisé à part, grille de 512) — et le contrôle, tuile par tuile, en partage des milliers ; mutation (un
    rangement par tuile) : 7,8 millions de texels partagés, densité ×7. `fumee_appli` +2 (le bouton, un Ctrl+Z).
    Vu à l'image (`capture_peinture.gd`, `2_atlas`). ⚠ **CE QUE ÇA NE DONNE PAS** : l'unicité par COPIE — une tuile
    de plateau revient des centaines de fois, et sa peinture avec elle (« une tuile par clé »).
  - **LE CURSEUR ET LES BANDES DE COUTURE — DÉCIDÉ ET ÉCRIT (Jordan, 1er octobre 2026 : « go pour la taille du
    pinceau et les bandes de couture »).**
    - **LE CURSEUR EST L'EMPREINTE DU TAMPON, PAS UN CERCLE** (`Peinture.empreinte`) : le rayon est en pixels de la
      TOILE, et la face fait de son plan vers la toile une application linéaire (deux différences de
      `uv_au_point`, la règle du rendu) ; dans chaque direction du plan, la distance qui y vaut le rayon. Une
      ELLIPSE où l'îlot est étiré, un cercle de taille × répétition / largeur en Boîte. Contour blanc = le bord,
      contour de la couleur du pinceau = la dureté ; un petit anneau rouge sur une face de la légende. Dessiné
      dans le plan de la face, à l'occurrence, sans test de profondeur, à chaque mouvement de souris.
    - **LES BANDES** : un calque (`material_overlay`, un shader) sur l'édition ET sur chaque MultiMesh des
      occurrences, posé quand on PEINT (case « Seam bands » de la section Paint, cochée par défaut). Dans le
      repère du modeleur, les plans de coupe sont aux DEMI-ENTIERS (une occurrence est posée au sommet + (1,1,1),
      sa tuile coupée à ±0,5) : le calque raye la bande où un plan TRAVERSE la surface (la normale du fragment,
      par `dFdx`/`dFdy`, n'est pas celle du plan) et trace le plan lui-même. Demi-largeur 1/16 de case —
      **PROPOSÉ**. ⚠ Il ne juge rien : c'est `verifier_couture_texture` qui juge, au tranchage.
    - **MESURÉ** : `test_peinture` (+5 : un îlot étiré 3 : 1 posé À LA MAIN rend une ellipse de 20/192 × 20/64
      case ; ce que `tamponner` peint VRAIMENT — peint à 90 % de l'empreinte, rien à 110 % ; la Boîte, un cercle
      de 20/512 ; la légende, rien) ; `fumee_appli` (+5 : survoler la paroi montre un cercle de taille /
      largeur × répétition dans le plan de la face, attendu par la formule de la Boîte ; les bandes sur
      l'édition et les 52 tuiles ; décoché, plus rien ; recoché ; Geometry éteint bandes et curseur). **Cinq
      mutations rouges** : cercle à l'échelle moyenne, rayon pris sur un seul axe, bandes sur l'édition seule,
      curseur jamais mis à jour, bandes sans le pinceau. Vu à l'image sous Xvfb, OpenGL
      (`capture_peinture.gd`, `3_curseur_et_bandes`) : les bandes aux joints des tuiles, dessus et parois,
      l'ellipse et l'anneau de dureté sous la souris. Le manuel (F1) le dit.
    - ⚠ **PAS TENU EN MAIN** ; ni vu en Vulkan sur le PC. La largeur des bandes et leur rose se jugent à l'œil.
  - **LA GOMME ET LES CALQUES — DÉCIDÉS ET ÉCRITS (Jordan, 2 octobre 2026 : « go pour 1 et 2 »).**
    - **UNE TOILE EST UNE PILE** (`peinture.gd`) : le FOND (la toile d'avant toute peinture : unie de la couleur du
      matériau, ou l'image lue), puis les calques du bas vers le haut ({nom, image, opacite, visible}). Le pinceau
      et la gomme n'écrivent que dans l'ACTIF ; « image » est la COMPOSITION (`composer`, par région pendant un
      trait), la seule que le rendu lit et que le `.glb` emporte : **le format et les greffons ne voient jamais de
      calques** — rien à porter dans la liste des greffons.
    - ⚠ **PEINDRE EST UN VRAI « PAR-DESSUS » EN ALPHA DROIT** : l'ancien `lerp` posait, sur un pixel transparent, une
      couleur ASSOMBRIE par son noir. Sur un pixel opaque le résultat est le même qu'avant (les 29 vérifications
      d'avant restent vertes).
    - **LA GOMME** (E tant que le pinceau est allumé, et un bouton) baisse l'alpha de l'actif : sur le calque du bas,
      le FOND revient. **Les calques** : New (transparent, au-dessus de l'actif), Up, Down, Delete (jamais le
      dernier), l'œil, le nom, l'opacité (appliquée au LÂCHER du curseur : recomposer 1024² à chaque cran coûterait
      trop). Chaque geste est UNE annulation : l'ÉTAT de la pile (ordre, noms, opacités, visibilités, actif), les
      images par RÉFÉRENCE — un calque supprimé puis rendu est le même objet ; un trait s'annule par région DANS SON
      calque (désigné par son image, pas par son rang).
    - **L'ÉCRITURE** : la composition à son chemin, la pile à côté (`<image>.layers/` : fond, `layer_<i>.png`,
      `layers.json` avec le MD5 de la composition écrite). ⚠ **UNE IMAGE RETOUCHÉE AILLEURS** (MD5 différent) : la
      pile est MISE DE CÔTÉ, l'image devient l'unique calque, et l'écran le dit — on ne recompose jamais par-dessus
      le travail d'un autre logiciel. Une image d'avant les calques se lit en un calque « Base ».
    - **MESURÉ** : `test_peinture` (48, +19 ; attendus à la main : couleur pure sur du transparent, mi-opacité,
      lerp(bleu, rouge, ½) pour un calque à 50 %, caché, la gomme du haut et celle du bas, l'ordre, l'insertion,
      l'état rendu, l'écriture relue, l'image retouchée ailleurs, l'image sans pile) ; `fumee_appli` (540, +13 : par
      les VRAIS boutons et la touche E, un trait dans le calque actif, la gomme, Ctrl+Z, l'œil, Delete et son
      annulation, la pile écrite). **Huit mutations rouges** : fond oublié, opacité ignorée, l'ancien mélange,
      pile non écrite, empreinte non vérifiée, trait écrit dans la composition, E ignorée, geste sans annulation.
      ⚠ **« PILE NON ÉCRITE » ÉTAIT D'ABORD MUETTE** : le dossier de test survit d'un lancement à l'autre, et la
      pile du lancement d'avant était relue. ⚠ **ET LA FUMÉE A ATTRAPÉ UN VRAI DÉFAUT EN L'ÉCRIVANT** : la copie
      « avant » d'un trait était prise APRÈS son premier tampon — Ctrl+Z ne défaisait pas le premier point.
    - ⚠ **PAS TENU EN MAIN.**
  - **LES CARTES PBR DÉDUITES, ET L'ALBEDO CUIT DEPUIS LE RELIEF — DÉCIDÉ (Jordan, 2 octobre 2026), ÉCRIT LE MÊME
    JOUR.** Jordan : « un PBR complet, mais éditer chaque png n'est pas propre à la main : l'équivalent d'un
    Materialize, qui génère les autres cartes à partir de l'albedo ». Puis : « 1 go, 2 oui, 3 auto, 4 possibilité de
    déduire aussi l'albedo du relief géométrique ». ⚠ **CE N'EST PAS LE PBR RETIRÉ LE 29 SEPTEMBRE** (§1) : celui-là
    était un shader maison en espace monde, avec POM ; celui-ci, ce sont des cartes PAR MATÉRIAU dans le glTF
    standard, que les trois moteurs lisent tels quels. Le relief reste dans la géométrie, les cartes l'habillent.
    - **LES CARTES NE SE PEIGNENT PAS, ELLES SE DÉDUISENT** (`addons/marchingblocks_core/cartes_pbr.gd`, PUR) : de
      l'albedo COMPOSÉ, la hauteur (passe-bande sur trois échelles ÷4, ÷16, ÷64, chacune pesée, contraste,
      « Dark is high »), la normale (Sobel, convention glTF/Godot : +Y vers le HAUT de l'image), l'ORM — R occlusion
      (cavité de la hauteur), G rugosité (base + variation : les creux plus rugueux), **B métal BLANC : le métal
      n'est jamais deviné**, le curseur « Metallic » reste seul maître (le métal deviné a déjà mis des parois marron
      au noir, §3). Seuls des RÉGLAGES s'enregistrent (`pbr` dans le matériau). Algorithmes écrits ici, rien repris
      de Materialize (même règle que Blender, §5).
    - **DEUX FAÇONS DE LIRE LES BORDS** : une image qui se RÉPÈTE (boîte, plan) se lit en boucle — sinon une arête à
      chaque répétition, donc à chaque joint ; une image DÉPLIÉE (UV) a des îlots : on les DILATE d'abord
      (« push-pull », `dilater`) sur un masque rasterisé depuis les triangles UV du témoin (`triangles_uv_de`,
      élargi d'un texel), sinon le flou lit le fond et dessine un bourrelet sur les arêtes et les plans de coupe.
    - **AUTOMATIQUE (point 3), PAS PENDANT LE GESTE** (`peinture.gd`, « LES CARTES PBR DÉDUITES ») : une toile
      retouchée est périmée ; la génération part sur un AUTRE FIL quand la composition n'a plus bougé depuis 350 ms
      (`CALME_MS`, PROPOSÉ), ~1,7 s sur 1024² (headless, mesuré). Les textures sont PARTAGÉES comme la toile et
      remplacées EN PLACE (`set_image`) : le matériau ne change pas. Une génération dépassée (un curseur bougé
      pendant qu'elle tournait) se MONTRE mais ne vaut pas « à jour ». L'écran dit « PBR maps: updating… ».
    - **ÉCRITES À CÔTÉ DE L'IMAGE** (`<image>.pbr/`, `.pbr_uv/` pour une image dépliée : normal, orm, height, et
      `pbr.json` — la SIGNATURE : MD5 de l'image écrite, réglages, bouclage) : relues sans calcul quand elle tient.
      La hauteur n'est lue par aucun moteur (le glTF n'en porte pas) : elle est pour l'artiste. L'enregistrement
      différé n'écrit que des cartes déjà à jour ; un enregistrement COMPLET (Ctrl+S, fermeture, tranchage) les finit
      d'abord, et `TemoinLie.vers_glb` aussi — APRÈS avoir bâti les maillages, qui sont ce qui les DEMANDE (appelé
      avant eux, rien n'était à refaire et le .glb partait neutre : vu rougir).
    - ⚠ **LES TANGENTES** : une carte de normales les lit. `MaillageEdite.avec_tangentes` (MikkTSpace, via
      `SurfaceTool.generate_tangents` — la convention que les importeurs recalculent) pour les matériaux à cartes ;
      et `BlocsMaitres._tableaux_poses` les RECALCULE après la pose quand la source en portait. ⚠ **« GODOT LES
      RECALCULE » ÉTAIT ÉCRIT LÀ, ET C'EST FAUX À L'AFFICHAGE** : seul l'export glTF les recalcule.
    - **L'ALBEDO DU RELIEF (point 4)** — `TemoinLie.albedo_du_relief`, bouton **Bake base colour** : pour chaque
      texel d'un îlot (projection UV : un texel = UN point d'une tuile), l'ORIENTATION de sa face (sols, parois,
      plafonds, une couleur chacun), la CONVEXITÉ (usure près d'une arête saillante, selon l'angle et la distance),
      la CONCAVITÉ (ombre près d'une arête rentrante). ⚠ **ÉTEINT LE LONG DES PLANS DE COUPE** (1/16 de case) : la
      voisine du monde n'y est pas celle du témoin — la discipline des coupes (§3) par construction ; une arête posée
      SUR un plan de coupe n'a pas de voisine dans la tuile, elle n'est rien. Il remplace le FOND de la toile (sous
      les calques peints), UNE annulation. **Refusé en boîte ou en plan** (l'image s'y répète), et l'écran le dit.
      ⚠ C'est un autre algorithme que Materialize (qui part d'une image) : il lit la GÉOMÉTRIE.
      ⚠ **IL NE FAISAIT RIEN À L'ÉCRAN — MESURÉ ET CORRIGÉ (Jordan, 3 octobre 2026 : « bake color base ne fait
      rien »)** : il réécrivait le FOND, mais le calque du bas (« Base ») était une copie OPAQUE de la toile, posée
      dessus — le fond changeait sous lui, l'image composée restait la même. Et la garde ne lisait QUE le fond : le
      compteur vert du §6. **Le calque du bas naît désormais TRANSPARENT** (le fond porte la toile d'origine ; la
      peinture reste dessus ; la gomme sur Base fait toujours revenir le fond) ; une pile écrite avant (`layers.json`
      sans « version » 2) voit son Base VIDÉ là où il égale le fond octet pour octet — l'image composée ne change pas
      d'un octet, un fond recuit s'y voit là où rien n'est peint. Gardé par `test_peinture` (52, +4 : un fond recuit
      se voit hors de la peinture et pas dessous ; une pile à l'ancienne écrite à la main, migrée sans changer
      l'image) et `fumee_appli` (la cuisson change l'IMAGE AFFICHÉE, un Ctrl+Z la rend octet pour octet). Mutations
      rouges : Base opaque (le défaut), migration absente.
    - **LE TRAJET ENTIER, MESURÉ** : témoin lié → .glb → relecture liée → lot du monde → `.mbset` → greffon Godot
      gratuit : normale, occlusion, métal-rugosité et TANGENT à chaque étape (`test_cartes_pbr`). **Unity 6.6 /
      glTFast** : `TheDerivedPbrMapsArriveInUnity`, les 52 tuiles portent normale, occlusion, métal-rugosité et
      tangentes — 32 tests sur 32 ; vu rougir (0 / 52 avec un jeu préparé sans cartes). **Unreal 5.8.3**, import
      standard (Interchange glTF) mené par `UnrealEditor-Cmd -ExecutePythonScript -nullrhi` sur un projet jetable :
      le matériau importé porte `NormalTexture`, `OcclusionTexture` et `MetallicRoughnessTexture` (l'ORM). ⚠ Ni les
      tangentes ni le SENS de la normale n'ont été regardés dans Unreal. **Les greffons n'ont RIEN à porter** : des
      textures glTF standard, lues par chaque importeur — rien dans LA LISTE DES GREFFONS À FAIRE (§0).
    - **VU À L'IMAGE** (`DEV_TOOLS/capture_cartes_pbr.gd`, avec fenêtre, RTX 2060 Vulkan) : la même toile à bosses
      claires, sans et avec cartes, le soleil en haut à gauche — chaque bosse s'éclaire sur son flanc haut-gauche et
      s'ombre en bas à droite : le sens de la normale et des tangentes est juste. Les bosses douces prennent un léger
      LISERÉ (le passe-bande souligne les bords) : à juger par Jordan.
    - **MESURÉ** : `test_cartes_pbr` 54 (attendus d'ailleurs : une rampe et sa normale calculée ici ; le SENS comparé
      à `Image.bump_map_to_normal_map`, l'autorité du moteur ; l'invariance par translation d'une image en boucle,
      au pas de la pyramide ; la couleur d'un texel recalculée depuis la géométrie lue dans le test, au CENTRE du texel
      ramené sur la face) ; `fumee_appli` (+15, par les vrais contrôles : la case, le curseur, deux Ctrl+Z, Ctrl+Y, la
      cuisson refusée en boîte et dite, puis faite sur l'atlas et annulée octet pour octet, les cartes écrites et dans
      le .glb ; une SENTINELLE — une mutation laissait d'abord la section abandonner en silence sur une erreur
      d'exécution). **23 MUTATIONS ROUGES** (cœur 17, écran 6). ⚠ **TROIS D'ABORD MUETTES, PAR DES TESTS TROP
      ÉTROITS** : l'extinction aux coupes (aucun point près d'un plan n'était jugé), une génération dépassée dite à
      jour, le masque non élargi (le compte d'aire passait) — chacune a reçu son cas. ⚠ **UNE ÉQUIVALENTE** : la
      dilatation qui ne saute pas l'îlot (dans l'îlot le mélange rend la source au bit près).
    - ⚠ **DEUX DÉFAUTS TROUVÉS EN ÉCRIVANT LES TESTS** : la remontée CUBIQUE de Godot depuis une image de 2 × 2
      DÉPASSE (une image unie à 0,32 rendait des texels à 0,348) — remontée par doublements bilinéaires ; et un écart
      de 3 ou 4 sur 255 entre une image et son décalage d'une demi-largeur n'était pas un défaut de bouclage mais la
      grille de la pyramide (le test décale au pas de ÷64).
    - ⚠ **UN PLANTAGE À LA SORTIE, CAUSE MESURÉE** : `Peinture.fournisseur_de_masque`, variable STATIQUE, gardait une
      fonction anonyme du modeleur jusqu'au démontage du moteur — `fumee_appli` finissait « VERDICT : OK » puis code
      139 (vu par une autre session ; reproduit, puis disparu une fois la variable effacée dans `_exit_tree`).
    - ⚠ **CE QUI N'EST PAS FAIT** : ~~un témoin relu de BLENDER perd ses réglages PBR~~ (fait le 3 octobre 2026 : ses
      cartes reviennent en ensemble, ses réglages par le nom du matériau) ; pas de masque métal (palier 2 ; l'émission est FAITE le 6 octobre 2026, ci-dessous) ; la génération coûte
      ~1,7 s par toile de 1024² (2,7 s avec masque) — à mesurer sur 2048², avec fenêtre. **PAS TENU EN MAIN.**
    - **LES ENSEMBLES PBR — ÉCRITS (Jordan, 3 octobre 2026 : « sur les ensembles PBR appliqués aux UV d'un witness de
      test, je ne vois toujours que l'albedo, et le rendu est vraiment pauvre »).** Ses textures (HEART_WORLD :
      `cliff_rocks_01_color_1k.png`, et à côté `…_normal_gl_1k`, `…_roughness_1k`, `…_ambient_occlusion_1k`…) sont des
      ENSEMBLES faits depuis le vrai relief ; l'appli les ignorait et ne faisait que DEVINER des cartes depuis l'albedo.
      - **trouvés par leur NOM** (`Cartes.compagnons`, pur) : le mot de la couleur (`color`, `albedo`, `diff`,
        `base_color`…, un morceau entier) remplacé par celui de chaque carte ; normale OpenGL préférée, une normale
        DirectX seule a son vert inversé ; une carte « ARM » est prise telle quelle. Lus une fois
        (`Peinture.ensemble_de`), rangés en ORM (la convention des cartes déduites : R occlusion, G rugosité, B métal,
        blanc s'il manque — le facteur reste maître). **Automatique** ; ils l'EMPORTENT sur les cartes déduites ; la
        case « Use the maps found next to the image » (section PBR maps) les écarte (`ensemble: false`). Les
        tangentes suivent (`MaillageEdite.a_des_cartes`).
      - **un monde tranché avant** porte encore l'albedo seul : à l'ouverture, une couche dont le lot n'a pas la normale
        de l'ensemble (comparée au pixel, `_ensembles_en_retard`) voit son `.glb` réécrit UNE fois, et le rapport le dit.
        Sur la copie du projet de Jordan : 11 → 24 Mo par `.glb` (les cartes 2k du gazon).
      - **une image choisie part en BLANC** : sa couleur la multiplie, et le « Material 2 » de Jordan gardait un gris à
        0,39 — la falaise à 40 % de sa luminosité. ⚠ Le projet de Jordan n'a PAS été retouché : à faire par lui.
      - **MESURÉ** : `test_cartes_pbr` 67 (+13, noms et pixels écrits à la main, de vrais fichiers) ; quatre mutations
        rouges (le drapeau DirectX, l'ensemble ignoré, l'ORM inversé, les tangentes non calculées — ⚠ D'ABORD MUETTE :
        Godot rend un tableau de tangentes même quand on n'en donne pas ; la garde juge leur SENS). Vu à l'image sur la
        copie du projet de Jordan (gazon et falaise en relief). ⚠ Pas jugé par Jordan.
      - ⚠ **VU EN PASSANT, PAS CORRIGÉ** : peindre sur une image de bibliothèque écrit ses calques et ses cartes À CÔTÉ
        D'ELLE (`D:/Spirit3D/…/cliff_rocks_01_color_1k.layers/`, `.pbr_uv/`) — hors du projet.
    - **L'ÉMISSION — DEMANDÉE PAR JORDAN (6 octobre 2026 : « ajouter l'emission et l'inclure dans le PBR, je ne sais pas
      pourquoi il n'y est pas déjà »), relayée par la session vidéos pour un devlog sci-fi, ÉCRITE LE MÊME JOUR.**
      - **une carte de l'ENSEMBLE**, trouvée par son nom comme les autres (`Cartes.MOTS_CARTES["emission"]` : `emission`,
        `emissive`, `emit`, `glow`, `illumination`, `selfillum` — `panel_color.png` à côté de `panel_emission.png`) ; le
        noir ne luit pas, toute autre couleur luit dans sa couleur. Une émission SEULE fait un ensemble SANS relief :
        les cartes déduites restent possibles à côté d'elle (`materiau_godot` ne laisse l'ensemble l'emporter que s'il
        porte une normale ou un ORM).
      - **la FORCE est un réglage du matériau** (`"emission"`, 1 par défaut, 0 à 20 : le curseur « Emission » de la
        section PBR maps, visible quand l'ensemble a une émission ; une annulation). Au-delà de 1, le halo (seuil HDR 1)
        la fait rayonner.
      - ⚠ **MESURÉ AVANT D'ÉCRIRE : LE glTF DE GODOT 4.7 LA PORTE TOUT SEUL** — `emissiveTexture`, `emissiveFactor` et
        `KHR_materials_emissive_strength`, écrits ET relus. Aucun code d'export : le .glb du témoin, le lot du monde, le
        `.mbset` et le greffon Godot la reçoivent. Un témoin revenu de Blender l'écrit à côté de son albedo
        (`<base>_emission.png`) et garde sa force. ⚠ La COULEUR de l'émission est la carte seule (`emission` = blanc) :
        un `emissiveFactor` coloré venu de Blender est perdu ; pas d'émission sans image d'albedo (l'ensemble s'accroche
        à elle). Un monde tranché avant se rhabille une fois (`_ensembles_en_retard_` compare aussi l'émission ; sans test).
      - **MESURÉ** : `test_cartes_pbr` 97 (+19 ; noms, une bande jaune posée à la main, la force 4 puis 3,5 dans le JSON du
        .glb, le lot du monde, tiles.glb, le greffon Godot, le retour de Blender ; une sentinelle) ; `fumee_appli` (+4, par
        le vrai curseur : caché sans carte, à 1, 5 → le matériau luit, un Ctrl+Z). **Six mutations rouges** (le mot
        `emissive`, la force ignorée, la carte non écrite au retour, la force non reprise, l'ensemble d'émission qui
        écarte les cartes déduites, l'émission jamais lue). Le manuel (F1) le dit.
      - ⚠ **LES GREFFONS N'ONT RIEN À PORTER** (une texture glTF standard), **mais rien n'a été regardé** dans Unity
        (glTFast) ni Unreal (Interchange) — `KHR_materials_emissive_strength` y est censé être lu. ⚠ Pas vu à l'image,
        pas tenu en main.
    **OUVERT** : le panneau 2D du patron. (Fusionner un calque sur celui du dessous : fait le 3 octobre 2026.)

### L'ATELIER ANIMATION — LES TEXTURES ANIMÉES — DÉCIDÉ (Jordan, 6 octobre 2026), ÉCRIT LE MÊME JOUR

Jordan : « un atelier d'animation complet avec possibilité de faire défilement, mais aussi frames (texture vidéo), pour
du sci-fi ou du naturel, pour tout ; animation pour chaque canal PBR, dont l'émission fait maintenant partie ; une UI
d'atelier où l'on ne crée que ce qu'on utilise, avec des + − ». Ses réponses aux trois questions posées : les images
viennent de **SÉQUENCES ou de PLANCHES** (pas de fichier vidéo : Godot ne lit que l'Ogg Theora, le mp4 demanderait
ffmpeg) ; on **PEINT IMAGE PAR IMAGE** ; un albedo animé par images n'a **PAS DE CARTES DÉDUITES**.

- **LE CŒUR** (`addons/marchingblocks_core/animation_materiau.gd`) : un matériau du témoin porte (ou non) une clé
  `animation` = {canal: {genre: réglages}} — canaux `albedo`, `normale`, `orm`, `emission` ; genres `defilement`
  (u, v en répétitions par seconde), `images` (la liste des PNG, ips, aller-retour), `pulsation` (l'émission seule :
  fréquence, minimum) ; chacun `synchro` ou décalé. `normaliser` borne et écarte ce qui est vide ou inconnu ; `ajouter`
  refuse une piste en double, une pulsation hors de l'émission, des images sans image. **PROPOSÉ** : défilement
  synchro par défaut (continu d'une tuile à l'autre), images et pulsation décalées ; au plus 256 images et 2²⁶ pixels
  par piste ; 60 images/s.
- ⚠ **UN SHADER NE VOYAGE PAS (§4) — DEUX MATÉRIAUX** : `MaillageEdite.materiau_godot` reste un `StandardMaterial3D`, l'image
  0 de chaque canal animé posée dans son emplacement et l'animation dans la méta `extras` (`mb_animation`) — **Godot
  écrit et relit la méta « extras » d'un matériau glTF** (lu dans `gltf_document.cpp`). `materiau_affiche` rend à l'écran
  un `ShaderMaterial` (`Anim.materiau`) qui garde le statique en méta `repli`. **Toute écriture glTF repasse par le
  statique** (`BM.ecrire_le_temoin_lie`, `FormatNeutre` — par `statique_pour_l_export` : les images n'y sont nommées que
  par leur NOM, jamais par un chemin de l'auteur) ; **toute relecture refait l'animé** (`BM._rendre_la_legende`) ; **le
  cache du lot s'écrit statique et se relit animé** (`Projet.mettre_en_cache` / `lire_cache` : sinon le shader et ses
  tableaux partaient dans le cache, copiés). Un témoin relu de Blender garde l'animation de ses extras, sinon la reprend
  du témoin d'avant par le nom du matériau (`reprendre_les_reglages`).
- **LES IMAGES** : un `Texture2DArray` par piste, PARTAGÉ (le témoin et le monde lisent le même) ; une image perdue est
  MAGENTA (§3). Importées : une séquence rangée par ordre NATUREL des noms (frame_2 avant frame_10), une planche lue de
  gauche à droite puis de haut en bas, ou des images neuves à peindre — toutes recopiées dans
  `<couche>_images/animation/`, à la taille de la première.
- **LE TEMPS EST GLOBAL** (paramètres globaux de shader `mb_temps`, `mb_image`) : pause, vitesse, une image tenue pour
  toutes les pistes. ⚠ `global_shader_parameter_get_list` est réservé à l'éditeur (une erreur dans l'appli, mesuré) : posés
  une fois par processus. **La phase d'une copie** est tirée de la case de son origine (`phase_de`, la formule du shader
  ligne à ligne) — jamais `randi()`.
- **PEINDRE IMAGE PAR IMAGE** : `Modeleur.chemin_peint` — avec un albedo animé par images, le pinceau peint l'image
  `image_peinte` (chaque image est une toile, avec ses calques et son annulation) ; la rangée **Frame ◀ ▶** (et « copier
  l'image ») de la section Paint de Texturing la choisit ; l'écran montre cette image, le temps figé
  (`Anim.image_forcee`, `Anim.fige`). Une toile peinte prévient les tableaux (`Peinture.montrer` → `toile_changee`), mis à
  jour à l'image suivante (pas à chaque tampon). Seule la couleur de base se peint ; les autres canaux s'importent.
- **L'ATELIER** (`app/animation.gd`, sur le modèle de Transitions ; `editor.gd` n'en garde que les branchements) : un
  septième atelier, **Animation**, teinte orange (**PROPOSÉ**), qui montre le témoin de la couche active en édition, sans
  outils de géométrie. Le matériau (le même courant que Texturing) ; **Tracks** — rien tant qu'on n'ajoute pas, une
  rangée « Add a track » (canal, source : Scroll, Frames from image files…, Frames from a sheet…, Blank frames to paint,
  Pulse — seulement ce que le canal n'a pas encore), une carte par piste avec son **−** et SES seuls réglages ;
  **Playback** — Pause, Restart, Speed, Hold frame. Chaque geste est UNE annulation ; un curseur, une par rafale.
  Le manuel (F1) a sa partie.
- ⚠ **LES QUARTS DE TOUR** : les UV d'une tuile tournent avec elle — un défilement en v (vertical sur une paroi, en Boîte)
  va dans le même sens sur toutes les copies, un défilement en u suit le tour de chacune. Dit à l'écran et au manuel.
- **MESURÉ** : `test_animation` 75 (attendus déroulés à la main : l'image au temps, l'aller-retour, la pulsation ; la phase
  recalculée par la formule écrite à nouveau ; l'ordre naturel, une planche de couleurs connues ; le statique, l'animé, ses
  réglages ; le .glb lu dans le JSON du FICHIER ; le lot, le cache écrit statique, le `.mbset` sans chemin, le témoin relu) ;
  **avec fenêtre, RTX 2060 Vulkan** (`DEV_TOOLS/capture_animation.gd`) : le shader compile, l'image forcée 0…3 se lit au
  centre, la lecture passe de l'image 0 à l'image 1, le défilement déplace l'image — et un contrôle d'instrument (un
  matériau ordinaire rouge se lit rouge) : ⚠ **LA CAPTURE A D'ABORD MENTI**, elle lisait des pixels d'une fenêtre de 320 ×
  320 alors que le projet l'ouvre maximisée ; `fumee_appli` 901 (+23, par les vrais boutons : « + » écrit trois images
  dans le dossier du projet, Ctrl+Z / Ctrl+Y, plus que le défilement proposé ensuite, la paroi montrée animée, « − »,
  Pause, Frame ▶ ▶ puis un trait qui peint l'image 3 et pas l'image 1, Ctrl+Z, le monde animé). Les suites voisines
  vertes (`test_peinture` 66, `test_cartes_pbr` 97, `test_temoin_lie` 46, `test_maillage_edite` 206, `test_projet` 131,
  `test_blocs_maitres` 1 468, `test_greffon_peinture` 282, `test_tranchage` 53, `test_faux_artiste` 36).
  **Mutations, toutes rouges** : cœur et shader 16 (aller-retour ignoré, phase changée, l'image 0 pas posée, pas
  d'extras, cartes déduites gardées, .glb écrit animé, relecture statique, cache écrit animé, cache relu statique, toile qui
  ne prévient pas, `.mbset` aux chemins absolus, témoin relu sans extras, réglages non repris, pause qui n'arrête rien ;
  avec fenêtre : l'image forcée ignorée, le défilement ignoré) ; écran 4, par la fumée (le pinceau qui ignore les images,
  le temps pas figé en peignant, un geste sans annulation, le maillage dessiné qui porte le statique). ⚠ **« CARTES
  DÉDUITES GARDÉES » D'ABORD MUETTE, PAR LE TEST** : le matériau d'essai n'avait pas d'image fixe, la branche n'était
  jamais atteinte. Mutations rejouées dans une COPIE à dossier de données isolé (deux autres sessions travaillaient dans
  le dépôt).
- **VU À L'IMAGE** (`DEV_TOOLS/capture_atelier_animation.gd`, dans l'appli, avec fenêtre) : l'atelier, ses quatre cartes
  et leurs −, le damier qui défile sur les dessus du témoin, les bandes d'émission qui luisent ; dans Texturing, les
  bandes de couture par-dessus le matériau animé.
- ⚠ **PAS TENU EN MAIN, PAS JUGÉ PAR JORDAN** (la teinte, la lisibilité des cartes, le ressenti de la lecture). Les
  greffons montrent l'image 0 : dans LA LISTE DES GREFFONS À FAIRE.

### L'appli : couches, projets, barre d'outils — DÉCIDÉ (Jordan, 27 septembre 2026)

- **LE MONDE PEINT NE DÉPEND PLUS DU TRAVAIL QUI L'HABILLE.** Une **couche** = une source de tuiles
  (le témoin calculé ou un `.glb`) et SES cases, dans son propre `MassifPeint`. ~~Son voisinage ne regarde que
  ses cases~~ — **RENVERSÉ le 2 octobre 2026** (« les couches exclusives », ci-dessous). Trancher change les
  tuiles de la couche ACTIVE, **jamais ses cases**.
- **LES COUCHES EXCLUSIVES, PRIORITÉ PAR L'ORDRE — DÉCIDÉ (Jordan, 2 octobre 2026 : « les layers de cases ne
  devraient pas s'écraser les uns les autres à la repeinture ? la superposition est une idée moyenne », puis « go,
  cases exclusives avec priorité par l'ordre »), ÉCRIT LE MÊME JOUR.**
  - ⚠ **LE DÉFAUT QUI LE JUSTIFIAIT** : deux couches pouvaient porter la MÊME case (deux tuiles l'une dans l'autre),
    et chacune, ne voyant que ses cases, fermait sa surface à la frontière : deux parois face à face, une RAINURE
    visible là où deux couches se touchent (vu à l'image, `capture_couches_exclusives.gd`, photo 2).
  - **UNE CASE N'APPARTIENT QU'À UNE COUCHE** : la poser dans la couche active la retire des autres, DANS LA MÊME
    ANNULATION (`_vols`, action comme coup de pinceau ; un Ctrl+Z rend la case à celle qui l'avait). Creuser ne
    touche que la couche active.
  - **LE CHOIX DES TUILES LIT L'UNION DES COUCHES VISIBLES** (`MassifPeint.union`, un dictionnaire {case: rang}
    PARTAGÉ par l'écran, vidé et rempli, jamais remplacé) ; **un sommet est posé par la couche de plus petit rang
    parmi ses huit cases** (`MB.couche_du_sommet`), avec SES tuiles. Une frontière ne porte donc rien : le monde
    est fermé comme s'il n'y avait qu'une couche. La référence pour les greffons : `MB.poses_en_couches`.
  - **L'ORDRE DE LA LISTE EST LA PRIORITÉ** (le haut gagne), et **Up / Down** (Jordan, 2 octobre 2026 : « go pour
    les boutons ↑ ↓ ») déplacent la couche active d'un cran — UNE action, un Ctrl+Z ; ses cases et son témoin ne
    bougent pas (`_deplacer_couche`, `Vue.deplacer_couche`). Gardé par `fumee_appli` (527 : par le vrai bouton,
    grisés aux bouts, la frontière change de propriétaire, Ctrl+Z) ; trois mutations rouges (union pas refaite,
    pas d'annulation, la vue pas déplacée). Vu à l'image (`capture_couches_exclusives.gd`, `1b_B_au_dessus`). Une couche CACHÉE sort de l'union : le monde se
    referme sans elle. Supprimer, rendre, cacher, montrer refont l'union et les rangs (`_refaire_l_union`) ; un
    geste ne refait que les alentours des cases changées, dans CHAQUE couche (`_suivre_les_cases`).
  - ⚠ `rang` < 0 : la couche est seule — l'ancienne règle mot pour mot (le greffon Godot, les sondes, les tests).
  - ⚠ **UN PROJET D'AVANT** peut porter une case dans plusieurs couches : à l'ouverture la plus haute la garde, les
    autres la perdent, et le rapport le dit (`_rendre_exclusives`).
  - ⚠ **UN DÉFAUT VU EN FUMÉE** : une couche neuve est bâtie AVANT de recevoir son rang ; sa reconstruction locale
    lisait encore ses seules cases, et ne posait plus RIEN. `reconstruire_autour` refait tout quand son état ne
    lit pas l'union qu'il devrait (`is_same`).
  - ⚠ **LA LISTE DES COUCHES NE RECOMPTAIT JAMAIS SES CASES après un geste** (« 0 cells » sur une couche peinte,
    vu à l'image) ; depuis le vol, un geste change le compte d'une AUTRE couche. Rafraîchie une fois par image.
  - ⚠ **L'EAU N'A PAS CHANGÉ** : elle lit toutes les couches, cachées comprises (« une case d'une autre couche, même
    cachée, retient l'eau »).
  - **MESURÉ** : `test_massif_peint` (§13, 96 : l'attendu par `MB.poses` sur l'union et un propriétaire recalculé
    à la main ; seules, les deux couches posaient des tuiles en trop à la frontière ; reconstruction locale = complète,
    y compris pour une couche rangée après sa construction) ; `fumee_appli` (le vol par une action et par un coup,
    Ctrl+Z / Ctrl+Y, aucune case dans deux couches, les sommets posés par chaque couche = ceux dont elle est la
    propriétaire — recalculés depuis les GRILLES, sans `couche_du_sommet` ni l'union de l'écran —, local = complet,
    cachée / montrée, supprimée / rendue, la liste qui recompte, un projet d'avant migré et dit — 509).
  - **DIX MUTATIONS, TOUTES ROUGES** (rejouées dans une copie) : la garde `is_same` ôtée, pas de vol, seule la
    couche active refaite, la couche cachée gardée dans l'union, la migration qui ne retire rien, le coup sans
    ses vols, la priorité au PLUS GRAND rang, la suppression sans refaire les rangs, une couche neuve sans rang,
    la liste qui ne recompte pas. ⚠ La première passe de M8 n'a RIEN éprouvé : l'outil de mutation lisait son
    motif par `unicode_escape`, qui déforme les accents (« MOTIF ABSENT ») — rejouée sur un motif ASCII.
  - **Vu à l'image** (`capture_couches_exclusives.gd`, avec fenêtre) : deux couches tranchées sur le témoin, l'une
    peinte par-dessus l'autre — en couches, une surface continue ; chacune seule, la rainure.
  - ⚠ **LES GREFFONS NE LE FONT PAS ENCORE** : un monde exporté y montre la rainure — dans LA LISTE DES GREFFONS
    À FAIRE (§0). ⚠ Pas tenu en main par Jordan.
  ⚠ « Slice the work » peignait jusque-là les cases du témoin en les remplaçant : c'était la preuve de
  l'aller-retour. Elle vit désormais dans un bouton à part, **« Paint the witness shape »**.
  ⚠ **ET CETTE PREUVE N'EST PLUS À L'IDENTIQUE DEPUIS LES EXEMPLAIRES** (§3) : le peintre tire
  l'exemplaire d'un sommet par hachage de sa position, pas d'après l'endroit où il fut sculpté [⚠ plus
  vrai depuis le 30 septembre 2026 : une tuile par clé, et avec le témoin lié la preuve est à l'identique]. Même
  forme, mêmes classes ; un coin sculpté ici peut reparaître là.
- **LE PROJET** (`app/projet.gd`, `.mbproj` en JSON) porte les couches et leurs cases, **s'enregistre
  une seconde après le dernier changement** (branché sur l'historique ; avant le 1er octobre 2026, à CHAQUE
  changement) et se rouvre au lancement. On écrit à côté puis
  on remplace. ⚠ Un projet qui ne s'ouvre pas n'est jamais écrasé : on en commence un autre.
- **LES LAGS D'ÉDITION SUR UN GROS MONDE — MESURÉS ET CORRIGÉS (Jordan, 2 octobre 2026 : « même dans le soft en
  global il y a encore trop d'algos lents pendant l'édition »).** `DEV_TOOLS/sonde_lags_edition.gd` (AVEC fenêtre,
  l'exemple installé dans son propre dossier : 194 692 cases dans « Hills ») chronomètre chaque geste et les 30 images
  qui suivent. AVANT → APRÈS (pire image) :
  - **tout geste (poser, Ctrl+Z, pinceau) : ~0,9 s → ~0,4 s.** C'était l'ENREGISTREMENT DIFFÉRÉ : 584 076 nombres posés
    UN PAR LIGNE par `JSON.stringify` indenté (4,8 Mo). Les cases s'écrivent d'un bloc (`Projet.vers_texte` :
    un `PackedInt32Array` que le moteur écrit lui-même, même format relu) et l'écriture différée part sur un AUTRE FIL
    (`_enregistrer(true)`, `WorkerThreadPool`) ; toute autre écriture reste synchrone et attend la précédente.
    Activer, montrer, renommer une couche, régler l'eau attendent aussi la seconde de calme ;
  - **une boîte de 256 cases : 8,1 s → 0,4 s** (l'eau, ci-dessus) ;
  - **cacher / montrer une couche : 4,5 s → 0,6 s.** `_montrer_couche` ne refait plus TOUTES les couches en entier :
    les autres se refont autour des cases de celle-ci ; la couche cachée garde son état et, en reparaissant, se
    refait autour de ce qui a changé pendant qu'elle était cachée (`_a_refaire`), ou en entier si l'union a été
    refaite entre-temps (`_tout_refaire`). Gardé par `fumee_appli` (refaite par morceaux = reconstruite en entier,
    deux tours) ; deux mutations rouges ;
  - ⚠ **CE QUI RESTE** : ~0,4 s après chaque geste sur ce monde (non découpé : le reste du recalcul de l'eau, l'index
    des corps), ~27 images/s au repos, l'ouverture (8,7 s, dont le tranchage de deux témoins hors cache), et le
    coup de pinceau (~190 ms pour 20 touches). ⚠ Pas tenu en main.
- **LE GESTE D'UNE CASE — MESURÉ ET CORRIGÉ (Jordan, 1er octobre 2026 : « une stratégie de sauvegarde meilleure
  que tout le monde à chaque opération, qui fait lagger pour une toute petite opération »).**
  `DEV_TOOLS/sonde_lags_monde.gd` (AVEC fenêtre, les 12 474 cases de `test.mbproj`) : poser UNE case coûtait
  **~295 ms**, dont **~278 ms de reconstruction de la couche entière** et ~18 ms d'enregistrement. ⚠ **CE N'ÉTAIT
  DONC PAS SURTOUT LA SAUVEGARDE** — et le pinceau reconstruisait tout à CHAQUE mouvement de souris.
  - **LA RECONSTRUCTION LOCALE** (`MassifPeint.reconstruire_autour`) : seuls les sommets des colonnes x−1..x,
    z−1..z, d'étage ≤ celui de la case, sont refaits — par `MB.pose_du_sommet`, la décision d'UN sommet SORTIE de
    `MB.poses` (sortie inchangée : une règle, un endroit). Le peintre garde son état (cases, décision par sommet,
    comptes) ; au-delà de 4 096 cases, si le lot a changé, ou si `Cases` ne compte plus ce que l'état connaît
    (une case posée par une autre route), c'est la reconstruction complète. L'action de l'historique et le
    coup de pinceau ne passent plus que les cases qu'ils touchent.
  - ⚠ **UN DÉFAUT QUE LA SONDE A TROUVÉ, PAS LE TEST** : sans lot, `lot_courant()` rebâtissait les 68 maillages
    du repli à CHAQUE appel — chaque reconstruction complète les payait, et la route locale ne reconnaissait
    jamais son lot (premier passage : toujours ~330 ms). Le repli est bâti une fois par peintre.
  - ⚠ Une couche SANS SOURCE rouverte n'était reconstruite par personne (le prochain geste le faisait en
    entier) : `_habiller_couche` la reconstruit.
  - **L'ENREGISTREMENT ATTEND UNE SECONDE DE CALME** (`_enregistrer_plus_tard`, comme le témoin) : vingt Ctrl+Z
    font UNE écriture. Écrit tout de suite : Ctrl+S, la fermeture, le changement de projet (`_vider_le_projet`),
    tout `_toujours_ecrire`. La barre dit « ● Saving… » tant qu'une écriture (projet ou témoin) attend.
    L'écriture hors du fil principal a été écartée : ~18 ms une fois la seconde passée ne se sent pas.
  - **MESURÉ APRÈS, avec fenêtre** : poser une case **~4 ms**, Ctrl+Z ~3,5 ms (au lieu de ~300).
  - Gardé par `test_massif_peint` §11 (une suite de 162 gestes au hasard, graine fixe, comparée après CHAQUE
    geste à un second massif reconstruit EN ENTIER — grilles `Rendu`, `Fautes`, orientations, bilan —, avec un
    lot construit pour avoir des variantes d'air libre ET des fautes, puis sans lot ; un couvercle posé six
    étages au-dessus d'un sol ; une case posée par une autre route) et `fumee_appli` (le geste ne reconstruit
    pas tout, ne réécrit pas le disque tout de suite, la seconde passée le disque porte la case, Ctrl+Z attend,
    Ctrl+S écrit). **Mutations rouges** : colonne x seule, ciel ignoré, plafond ou étage bas non relevés, garde
    de compte ôtée, retrait non défait, route locale jamais prise, repli rebâti à chaque appel ; dans l'appli,
    l'historique qui réécrit tout de suite, Ctrl+S qui ne vide pas l'attente, l'action qui reconstruit tout.
  - ⚠ **SANS GARDE** : le coup de pinceau qui repasserait par la reconstruction complète (il ne serait que lent),
    l'écriture au changement de projet par « New project », et « Saving… » tenu quand le témoin s'écrit avant le
    projet. ⚠ La reconstruction COMPLÈTE coûte toujours ~280 ms (ouverture, changement de lot, « Clear »).
    ⚠ **PAS TENU EN MAIN.**
- **LE LOT TRANCHÉ N'EST QU'EN CACHE** (`user://cache`), marqué de l'empreinte de sa source — le MD5
  du `.glb`, pas sa date, précise à la seconde seulement. Source changée : on retranche. Source
  disparue : l'ancien lot en le DISANT, sinon un lot vide, donc des cubes rouges — jamais le repli.
- **LA BARRE D'OUTILS** (règle pure : `addons/.../outils.gd`, partagée avec le greffon) : deux VISÉES,
  **Grid** (le plan de l'étage) et **Sculpt** (la matière, par un rayon case à case contre
  l'OCCUPATION, jamais contre le rendu), les mêmes OUTILS (Add, Dig, Select — le clic droit fait
  l'inverse), un pinceau sphère / cube / disque de taille 1 à 7, et un aperçu des cases exactes qui
  changeront. La sélection (un état d'écran, ni enregistré ni annulable) a ses opérations, et **les
  opérations d'étage portent sur elle quand elle existe**.
  - ⚠ **Add voit toutes les couches visibles, Dig et Select la seule active.**
  - **LE DÉZOOM DU MONDE (Jordan, 2 octobre 2026 : « on doit pouvoir dézoomer beaucoup plus loin »)** : la molette
    recule jusqu'à 1 000 cases dans World (`Vue.DISTANCE_MAXI_MONDE`, 120 avant ; le témoin garde 120), et la portée
    des ombres suit (deux fois le recul, 100 au moins). Gardé par `fumee_appli`, mutation rouge.
  - **CTRL+CLIC CALE LA GRILLE SUR LA MATIÈRE (Jordan, 1er octobre 2026)** : l'étage devient le `y` de la case
    touchée (rayon contre les couches VISIBLES, quels que soient l'outil et la visée), rien n'est peint, et
    l'écran le dit (aussi quand le rayon ne touche rien, ou hors de −64..64). Gardé par `fumee_appli` (vrai
    clic sur une colonne), une mutation rouge. ⚠ Pas tenu en main.
  - ⚠ **LE VERROU DE COUP** : ce qu'un coup d'ajout pose est transparent à son propre rayon, sinon
    glisser bâtit une tour vers la caméra.
  - ⚠ **TOUT CE QUI CHANGE DES CASES PASSE PAR `_appliquer`.** Trois routes écrivaient chacune leur
    annulation, et l'une reconstruisait la couche ACTIVE au lieu de celle qu'elle touchait : un Ctrl+Z
    après avoir changé de couche laissait un rendu faux. **Vu rougir** dans `fumee_appli`.
  - **PHASE 3, FAITE** : la **boîte** (B — en Sculpt ses deux coins sont sur la matière, donc elle est
    3D ; Maj ajoute, clic droit retire), **déplacer** (boutons X/Y/Z, et les flèches, qui SUIVENT LA
    CAMÉRA — « haut » éloigne de soi ; Maj + haut/bas lève), **copier / couper / coller** (Ctrl+C/X/V ;
    le presse-papiers n'appartient à aucune couche, le collage suit la souris et se pose d'un clic).
    ⚠ Déplacer ou coller sur de la matière FUSIONNE, jamais n'écrase. ⚠ Un déplacement qui recouvre sa
    source n'efface que sa queue et ne pose que sa tête. ⚠ Le milieu d'un presse-papiers s'arrondit
    par `floori`, pas par division entière : en négatif, celle-ci décalait le collage d'une case.
- **LA BOÎTE PREND LE VOLUME, PLUS LA MATIÈRE (Jordan, 28 septembre 2026).** Un pavé vide n'existait
  pas : on ne pouvait désigner une pièce avant de la bâtir. `Outils.volume_de_la_boite` rend toutes
  les cases entre deux coins, avec **Hollow** (la peau seule, pour une salle) ; le **Rect** (R) se pose
  toujours à plat sur l'étage, quelle que soit la visée. **Fill** pose la matière dans les cases vides
  de la sélection sans la déplacer, et **Extrude** fait monter l'étage avec elle : Fill, Extrude, Fill.
  ⚠ Le volume est BORNÉ (`VOLUME_MAXI`, 64³) : au-delà la boîte rend vide et l'écran le DIT — deux
  coins perdus à l'horizon gèleraient l'appli. ⚠ La sélection se DESSINE cases vides comprises.
- **EXTRUDE, UNE SEULE FOIS — DÉCIDÉ (Jordan, 2 octobre 2026 : « Extend up / down et Extrude ↑ / ↓, on ne sait pas
  lequel fait quoi », puis « Maj étend et Alt décale »), ÉCRIT LE MÊME JOUR.** C'était une REDONDANCE : mêmes cases
  posées, mêmes icônes ; seul Extrude suivait (sélection et étage), et seulement sur une sélection. Il ne reste que
  **Extrude up / down / facing**, dans Shape operations (`Etages.extruder`) : sur la sélection, sinon sur la matière
  de l'étage ; clic = pose devant la MATIÈRE de la base, la sélection et l'étage suivent ; **Maj + clic = étend la
  sélection d'un cran** (cases vides comprises), **Alt + clic = la décale**, sans rien poser. Les boutons Extrude de
  la section Selection sont retirés. Gardé par `test_etages` (27, attendus à la main) et `fumee_appli` (le vrai bouton,
  de vraies touches Maj / Alt — ⚠ `Input.parse_input_event` ne vaut qu'après `Input.flush_buffered_events()`, et un
  événement ne s'envoie pas deux fois dans la même image). Six mutations rouges (étendre = poser, décaler qui ne
  décale pas, poser devant une case vide, Maj ignorée, Alt ignorée, et Shrink qui exige tous les voisins). ⚠ **« ALT
  IGNORÉE » D'ABORD MUETTE, PAR LE TEST** : Alt + Extrude down sous une sélection posée sur la matière ne posait rien
  non plus en clic normal, qui décale aussi la sélection — rejoué vers le haut. ⚠ Et une mutation écrite `false and A
  or B` n'éprouvait rien (`(false and A) or B`).
- **SHRINK RETIRE LE BORD — CORRIGÉ (Jordan, 2 octobre 2026 : « shrink la sélection ne fonctionne pas, il la
  supprime »).** Il ne gardait que les cases PLEINES dont les SIX voisines étaient sélectionnées : sur une sélection
  mince (un Rect, une peau peinte), plus rien. `retrecir_bord` : une case est du bord quand, sur un axe, la sélection
  continue d'un côté et s'arrête de l'autre — un rectangle perd son pourtour, une ligne ses bouts, un cube sa peau,
  une case seule reste, les cases vides comptent. ⚠ L'ancien `retrecir` reste dans `outils.gd` pour les cas d'épreuve
  des greffons (liste des greffons à faire). Gardé par `test_outils` (62, attendus à la main).
- **« PAINT THE WITNESS SHAPE » RETIRÉ (Jordan, 2 octobre 2026 : « est nul, il faut le retirer »)** : le bouton et
  sa ligne du manuel. La fonction reste pour les captures de `DEV_TOOLS/`.
- **LES QUATRE ÉTAPES À GAUCHE (Jordan, 28 septembre 2026)** : Export · Import · Slice · Export to
  engines, numérotées, et les imports gardés en LISTE (réimporter un même fichier le remplace). La
  liste survit à la session depuis le 3 octobre 2026 (§5, « la passe du 3 octobre »).
- **NAVIGATE — DEMANDÉ PAR JORDAN (28 septembre 2026), SORTI DES VISÉES LE 29.** Elle ne vise rien :
  clic droit glissé pour regarder, aucun clic ne peint. Elle était la troisième visée du cycle de Tab ;
  **DÉCIDÉ (Jordan, 29 septembre 2026)** : Tab n'alterne plus que Grid et Sculpt, qui restent ensemble, et
  Navigate est un INTERRUPTEUR basculé par **Espace** (et un bouton sous les visées). On vole en
  **AZEQSD** : Z S avancent et reculent, Q D vont de côté, A descend, E monte (QWEASD sur un QWERTY). La
  visée d'avant revient telle quelle ; choisir Grid ou Sculpt, au clic ou par Tab, sort du vol.
  ⚠ **LES TOUCHES SE LISENT PAR LEUR PLACE** (`physical_keycode`) : ZQSD sur un AZERTY, WASD sur un
  QWERTY. ⚠ **S, D ET A SONT AUSSI SELECT, DIG ET ADD** : en Navigate, les touches de vol ne choisissent
  pas d'outil, sinon reculer ou descendre changeait d'outil en silence. ⚠ Espace passe par `_input`,
  comme Tab : un bouton qui a le clavier l'aurait pris pour un clic. ⚠ **ON DÉPLACE LA CIBLE, PAS L'ŒIL** : regarder
  fait pivoter la cible autour de la caméra, et repasser en Grid retrouve une orbite cohérente. Avancer
  reste À PLAT. Gardé par `fumee_appli` (Tab sur deux visées seulement, Espace allume et éteint sans
  toucher à la visée, aucun clic ne peint, l'œil reste en place, vol à plat, E / A / Z TENUES pour de vrai
  montent, descendent, avancent, S et A ne choisissent pas d'outil). ⚠ **« TENIR UNE TOUCHE NE SE SIMULE
  PAS EN HEADLESS » ÉTAIT ÉCRIT ICI, ET C'EST FAUX** : `Input.parse_input_event` d'un `InputEventKey`
  appuyé met la touche à l'état tenu pour `Input.is_physical_key_pressed`, jusqu'à son relâché — mesuré
  le 29 septembre 2026. ⚠ **LA GARDE « A NE CHOISIT PAS ADD » ÉTAIT MUETTE** : l'outil était déjà Add.
  Elle part désormais de Dig.
  **LES TROIS GREFFONS SONT ALIGNÉS — DEMANDÉ PAR JORDAN (29 septembre 2026).** Tab n'alterne plus que Grid
  et Sculpt, Espace bascule Navigate (qui garde la visée et rend la souris au moteur), choisir une visée
  sort du vol. **MESURÉ** — Godot (`test_greffon_peinture` 120 : Espace pris, visée gardée, cycle à deux,
  Tab en vol) ; Unity (la transition en C# pur, `AimState`, 24 vérifications au banc .NET, et 20 tests sur
  20 dans Unity 6.6 dont 4 qui envoient de VRAIS événements à l'éditeur de scène ; Espace tenu ne bascule
  qu'une fois) ; Unreal (la transition dans MBCore, 20 vérifications au core-runner, BuildPlugin 5.8.3 sans
  avertissement). Mutations rouges partout (2 Godot, 11 Unity, 4 Unreal).
  ⚠ Unreal : un niveau enregistré avec l'ancienne visée Navigate se relit en Grid + vol (la valeur d'enum
  reste, masquée) ; et dans le mode MarchingBlocks, Espace ne fait plus tourner le gizmo d'Unreal.
  ⚠ **RIEN DE CECI N'A ÉTÉ TENU EN MAIN** dans les trois éditeurs — en particulier, qu'Espace arrive bien
  jusqu'au greffon dans la Scene view d'Unity et la vue d'Unreal.
- **LE PLAY TEST — DEMANDÉ PAR JORDAN (29 septembre 2026).** Un troisième atelier : on MARCHE dans le
  monde peint, ZQSD (par leur place), Espace saute, Maj court ; caméra à la troisième personne qui tourne
  autour du personnage en LACET au clic droit glissé, molette pour rapprocher ou éloigner ; Échap rend
  World, Retour arrière ramène au départ. Aucune case n'y change. Le personnage (`app/personnage.gd`) :
  un stickman Funko Pop tout noir, yeux violets émissifs, contour violet de la même couleur (coque
  inversée : `next_pass`, `CULL_FRONT`, `grow`), animé en PROCÉDURAL — repos, marche, course, saut,
  écrasement à l'atterrissage. Bâti en primitives : aucun modèle emprunté, rien à importer.
  - ⚠ **IL FOULE CE QU'ON VOIT, PAS LES CASES.** Les grilles `Rendu` portent une boîte par octant plein
    (`RP.collision`) : la case entière, alors que la matière de l'aminci est un quart de case en retrait.
    Un décor à part (couche de collision 2) est bâti à l'entrée avec les TRIANGLES des tuiles posées,
    rotations comprises. **MESURÉ** : sur le témoin tranché, il se pose à y = 10,75 sur un sol d'étage
    10 ; sur les boîtes des cases, à 11,00.
  - ⚠ **LA MUTATION « IL FOULE LES CASES » ÉTAIT MUETTE SUR LE REPLI PROCÉDURAL**, où surface rendue et
    boîtes coïncident (11,00 des deux côtés) : le test était trop étroit, pas le code inutile (§6). La
    fumée tranche désormais le témoin dans la couche avant de jouer, et la mutation rougit.
  - ⚠ **LA VUE A LE CLAVIER EN PLAY TEST**, sinon Espace re-cliquait le bouton « Play test ». Elle ne
    doit donc avaler que la SOURIS : avaler ses touches privait l'écran d'Échap — vu rougir, parce que la
    fumée envoie Échap par `Input.parse_input_event` et non par un appel direct, qui ne l'aurait jamais vu.
  - ⚠ **`_trancher_temoin` PEND EN HEADLESS** : son panneau d'attente guette `frame_post_draw`, qui ne
    vient jamais sans rendu. La fumée pendait sans un mot ; elle pose le lot directement.
  - **Gardé par `fumee_appli`** (14 vérifications : refus d'un monde vide, apparition, pose sur la
    surface rendue, avance, saut de plus d'une case, rotation, molette, Échap, aucune case changée).
    Mutations rouges : décor vide, vue qui avale les touches, saut trop faible, collision sur les cases.
    ⚠ **Une mutation reste MUETTE, et c'est un trou** : sans `backface_collision`, rien ne rougit — on
    ne l'a éprouvé que sur un sol vu d'en haut. Les faces vues de dos (coupes ouvertes, dessous d'un
    surplomb) n'ont aucune garde.
  - **LE BRAS-RESSORT ET LE CLIC GAUCHE — DEMANDÉS PAR JORDAN (29 septembre 2026).** Clic gauche glissé :
    la caméra tourne en lacet ET en hauteur (le clic droit reste en lacet seul). La caméra est tenue par
    un bras-ressort : une SPHÈRE (rayon du plan proche) lancée du personnage vers l'œil contre le décor —
    un rayon ne voyait que l'axe, et le plan proche, qui a une largeur, traversait la paroi. Elle rentre
    sans délai et ressort en douceur.
    ⚠ **LE RAYON DE CAMÉRA D'AVANT N'AVAIT JAMAIS TOURNÉ** : `SubViewport.world_3d` est NUL quand la vue a
    son propre monde (`own_world_3d`) ; c'est `find_world_3d()` qui le rend. Et la fumée n'en disait rien.
    ⚠ **UNE ERREUR D'EXÉCUTION ABANDONNE LA FONCTION EN SILENCE** : la fumée a conclu « OK » avec cinq
    vérifications de moins. Une SENTINELLE exige désormais que le Play test aille jusqu'au bout.
    ⚠ **« L'ŒIL RESTE AU-DESSUS DU SOL » ÉTAIT UN MAUVAIS CRITÈRE** : près du bord, l'œil passe légitimement
    sous le plateau en le contournant. La garde vérifie qu'il n'y a RIEN entre le personnage et l'œil, ni
    autour de l'œil. Mutations rouges : bras ôté, retour de `world_3d`, clic gauche ignoré.
    ⚠ **UNE SECONDE SPHÈRE SUR LA CAMÉRA NE SERT À RIEN ICI** (question de Jordan, 29 septembre 2026) :
    lancer une sphère couvre déjà la largeur du plan proche sur tout le trajet. Le vrai trou était
    ailleurs : le bras partait de `_cible`, le pivot LISSÉ, qui traîne derrière la tête et peut être
    dans la roche — et une sphère lancée de l'intérieur bute sur la face par DESSOUS, donc garde l'œil
    dedans (mesuré). Ce que `cast_motion` fait d'une forme qui CHEVAUCHE déjà une face n'est pas mesuré. Le bras part désormais de la
    VRAIE tête, qui est libre par construction (sphère de 0,15 < capsule de 0,19), vers le pivot, puis
    du pivot vers l'œil. Gardé par la fumée (pivot posé DANS la dalle du sol, la sphère plus fine que la
    capsule), mutations rouges : bras lancé du pivot lissé (œil à y = 10,6 dans la dalle), rayon de 0,2.
  - **LA TAILLE DU PERSONNAGE — DEMANDÉE PAR JORDAN (6 octobre 2026 : « régler le scale du stickman, et le mettre un
    peu plus petit, ×0,65 par défaut, histoire que le monde paraisse un peu plus grand »), ÉCRITE LE MÊME JOUR.** Le
    curseur « Character size » (0,4 à 1,5) de la section Play test, gardé le temps de la session. Suivent la taille :
    le modèle, la capsule, la flottaison et l'immersion, les vitesses de marche, course et nage, la cadence des pas, et
    la caméra (pivot, distance, sphère du bras, plan proche — le bras reste plus fin que la capsule, le plan proche sous
    lui). ⚠ **NE SUIVENT PAS (PROPOSÉ)** : le saut (1,45 case), le pas (0,3), la sortie de l'eau, le vol — sinon un petit
    personnage ne franchirait plus les marches d'une case. La sonde de l'eau ne descend jamais sous +0,3 (elle doit
    sortir de la case pleine du plancher). Gardé par `fumee_appli` (821 : la vitesse de 2,08 cases/s, la capsule et le
    modèle à ×1 et ×0,4 par le vrai curseur, la caméra qui recule d'autant ; flottaison à 2,34) ; deux mutations
    rouges (vitesse non mise à l'échelle, curseur débranché). ⚠ Ni vu à l'image ni tenu en main.
  - **LE VOL — DEMANDÉ PAR JORDAN (1er octobre 2026), ÉCRIT LE MÊME JOUR.** **F** (ou le bouton « Fly ») bascule ;
    en vol, ni gravité ni pas : Espace ou E montent, A descend (Q / E sur un QWERTY, les touches de Navigate), Maj
    va plus vite. ⚠ **IL HEURTE TOUJOURS LE DÉCOR** (`move_and_slide`) : traverser la roche ne dirait rien du monde.
    ⚠ Pas Ctrl pour descendre : Ctrl+Z (avancer en AZERTY) aurait annulé. Pose de vol : tout le corps couché avec
    la vitesse, bras en ailes, jambes qui traînent. Gardé par `fumee_appli` (373 : F, monter, planer une fois
    lâché, le sol qui arrête la descente, retomber hors du vol) ; trois mutations rouges (gravité en vol, vol à
    travers le décor, F non branché). ⚠ Ni vu à l'image ni tenu en main.
    ⚠ **« LE VOL S'ARRÊTE NET » (tournage du trailer final, 7 octobre 2026) N'ÉTAIT PAS LE PERSONNAGE — MESURÉ.** Sous
    Windows, une autre application qui prend la main fait relâcher à Godot toutes les touches enfoncées (sonde : W
    injectée, le Bloc-notes par-dessus, `is_physical_key_pressed` passe à faux) ; le pilote du tournage n'enfonçait W
    qu'une fois pour 50 s de vol, et renvoyait Espace et A à chaque image — d'où x et z figés, y qui monte encore.
    Reproduit en headless sur le vrai tournage (W relâchée au milieu du vol : la prise 5 au millionième), corrigé dans
    le pilote (`filmer_ui._process` renfonce chaque touche tenue). Gardé par `test_pilote_tournage` (6) ; deux mutations
    rouges (pas de renfoncement : 2 échecs, dont « il avance encore » 0,61 case au lieu de 3,65 ; touche lâchée renfoncée).
  - ⚠ **VU À L'IMAGE, PAS TENU EN MAIN** : `capture_app.gd` photographie le personnage posé, en marche,
    en saut, de près et de face (yeux et contour lisibles). Le ressenti — vitesse, hauteur de saut, le pas
    de 0,3 case, la caméra qui se rapproche contre les parois — se juge clavier en main, par Jordan.
- **UNE TEINTE PAR ATELIER — DÉCIDÉ (Jordan, 2 octobre 2026), ÉCRIT LE MÊME JOUR** : « une palette vraiment
  différente et cohérente à chaque atelier : Fluids en bleu, World en rouge […] seule la barre de droite, qui est ce qui
  est interne à l'atelier, doit changer de palette ; le soft garde en global sa palette », puis « la barre de droite et
  le bouton de l'atelier lui-même ».
  - **LES TEINTES** (`Palette.TEINTES_ATELIER`) : Project ambre, World rouge (un cramoisi, pas le rouge orangé du
    DANGER — un « Clear » s'y lit encore), Fluids bleu, Geometry violet, Texturing rose, Play test vert. **PROPOSÉ** pour
    les quatre que Jordan n'a pas choisies.
  - **LA PALETTE GLOBALE NE BOUGE PAS** : `Palette.theme(accent)` rend, pour l'OLIVE, les constantes d'avant (les bandes
    et filets aussi, `bande_de`) ; la barre de gauche, la barre de titre et le reste gardent l'olive.
  - **CHAQUE BARRE DE DROITE** (`habiller_barre`, une fois, après sa construction) reçoit le thème de sa teinte (boutons,
    curseurs, champs, cases, focus), un fond à peine teinté avec un filet de sa couleur, et ce que l'écran avait peint
    en olive EN DUR dans ses descendants (valeurs, en-têtes de section, filets) passe à sa teinte (`_teinter`). ⚠ Une
    étiquette olive créée PLUS TARD dans une barre (une liste rebâtie) garde l'olive : les boutons suivent le thème,
    pas les surcharges posées après coup. **CHAQUE BOUTON D'ATELIER** (`habiller_bouton_d_atelier`) porte sa teinte
    même au repos (icône, filet gauche), pleine une fois choisi.
  - **MESURÉ** : `fumee_appli` (+19 : rouge pour World et bleu pour Fluids, écrits dans le test ; six teintes
    distinctes, aucune olive ; chaque barre enfonce dans sa teinte, ses en-têtes la portent, chaque bouton aussi ; la
    barre de gauche et ses sections gardent l'olive). Quatre mutations rouges (barres non habillées, boutons non
    habillés, en-têtes non teintés, thème qui ignore l'accent). Vu à l'image (`DEV_TOOLS/capture_teintes_ateliers.gd`,
    les six ateliers). ⚠ Pas jugé par Jordan (les quatre teintes choisies, leur force).
- **LA BARRE DE GAUCHE ET LE CONTEXTE — DEMANDÉ PAR JORDAN (29 septembre 2026).**
  - **L'ATELIER EST ÉPINGLÉ EN HAUT** : il ne défile jamais.
  - **DEUX ZONES, CHACUNE SON DÉFILEMENT** : en haut ce qui compte (le projet, les couches, les quatre
    étapes, le Play test, et le rapport épinglé dessous), en bas la RÉFÉRENCE (le témoin et sa légende,
    les raccourcis), dans un rapport d'étirement de 3 contre 1 — les 75 % demandés, qui suivent la taille
    de la fenêtre. **De gros séparateurs** (titre gras sur filet épais) marquent les groupes : WORKSPACE,
    PROJECT, THE ROUND TRIP, REFERENCE.
  - **TOUTE LA BARRE DE DROITE S'OUVRE DÉPLIÉE** (« Shape operations » était repliée).
  - **L'ATELIER PROJECT — DÉCIDÉ PAR JORDAN (29 septembre 2026)** : quatre ateliers (Project, Witness,
    World, Play test, en grille de deux), et **Project est le SEUL à montrer Save · open et l'aller-retour**
    (les quatre étapes ; 3 et 4 visent la couche active, choisie dans World). Choisir un travail importé
    reste dans Project.
  - **CE QUI NE SERT PAS ICI NE S'AFFICHE PAS** — une seule fonction, `_contexte()`, avec son tableau :
    Project montre Save · open, les quatre étapes et la section Witness ; Witness, la section Witness ;
    World, les couches, les raccourcis et la barre de droite ; Play test, ses commandes et le rapport. ⚠ **LA BARRE DE DROITE ÉTAIT UN CADRE VIDE DANS LE TÉMOIN** : ses sections se cachaient, le
    panneau restait et mangeait un quart de la vue. Dans les outils, le pinceau (taille, forme) disparaît
    pour Rect et Box, « Hollow » n'apparaît qu'avec Box. « Show the witness » n'apparaît que quand on
    regarde un travail ; « Slice the selected work » est grisé tant que rien n'est importé, « Delete » tant
    qu'il ne reste qu'une couche.
  - **Gardé par `fumee_appli`** (93 vérifications) — mutations rouges : Tab sur trois visées, E qui ne
    monte plus, Witness partout, Hollow partout, A qui choisit Add en vol, barre de droite partout,
    ateliers dans le défilement, Save · open dans Witness, étapes 3-4 dans World. **Vu à l'image** (`capture_app.gd`, Witness et World) : c'est là qu'on a
    vu le titre PROJECT doublé par la bande « Project » (devenue « Save · open ») et le rapport qui gardait
    les touches du jeu après en être sorti.
- **LA LÉGENDE DES FORMES — DEMANDÉE PAR JORDAN (29 septembre 2026)** : « on ne reconnaît pas du premier
  coup d'œil ce qu'il faut altérer au witness pour retrouver quoi et où dans le monde ». Dans Witness, un
  bandeau en haut de la vue, entre les deux barres (`app/legende_formes.gd`) : une carte par forme — une
  PHOTO du vrai témoin cadrée sur elle, un renvoi qui pointe la zone, le nom, ce qu'elle devient dans le
  monde, le nombre de tuiles tranchées là. Une flèche qui longe son bord le replie. **Ajouté (PROPOSÉ)** :
  survoler une carte allume la zone dans la vue, à travers la roche ; un clic y cadre, sous l'angle de la photo.
  - ⚠ **LES FORMES VIVENT DANS LE CŒUR** (`formes_du_temoin.gd`) : `planete_paysage.gd` les lit pour bâtir
    le témoin (sortie `--couches` IDENTIQUE, mesuré par `diff`), la légende aussi. Ce qu'aucune forme
    n'explique (la réparation, l'atome du finisseur : 7 cases) se DÉDUIT par différence → la carte « Twists ».
  - **MESURÉ** : l'union des 23 cartes rend les **52 tuiles** — aucune ne vient d'un endroit que la légende
    ne montre pas. Presque aucune n'est propre à UNE carte (les formes se chevauchent).
  - ⚠ **LES PHOTOS SONT PRISES À L'OUVERTURE**, une `SubViewport` par carte rendue une fois — pas des PNG
    livrés, qui mentiraient au prochain témoin. L'angle est choisi parmi seize pour montrer le plus de cases
    de la forme ; si plus d'un quart reste caché, le plan proche fait un ÉCORCHÉ (salle, pilier, banquette).
    ⚠ Un seul regard tiré du centre passait par la bouche de grotte et déclarait la salle visible : vu rougir.
  - Gardé par `test_formes_du_temoin` (107) et `fumee_appli` (+11). Sept mutations rouges (forme déplacée
    dans la table, zone du plateau qui avale la salle, un seul regard, carte oubliée, légende partout, zone
    allumée hors du témoin, flèche muette). Vu à l'image (`capture_legende_formes.gd`). ⚠ Pas tenu en main ;
    le manuel (F1) n'en parle pas encore.
  - **LE SENS INVERSE, DANS WORLD — DEMANDÉ PAR JORDAN (29 septembre 2026).** Le même bandeau (« WHERE IS IT
    FROM? ») dit, pour la tuile sous la souris dans la couche active, la forme d'où elle vient, sa photo, un
    renvoi vers le coin EXACT, « copy k of N », et **Show it in the witness** (Witness, la vue cadrée sur ce
    coin, une boîte blanche à sa place, la carte encadrée).
    - ⚠ **ON LIT CE QUI EST POSÉ** : l'item de la grille `Rendu` au sommet, puis son NOM dans la méta du lot
      (`BlocsMaitres.META_SOMMETS`, écrite par `_assembler` depuis les exemplaires du trancheur). PAR LE NOM,
      pas par l'indice : un exemplaire vide est sauté sans renuméroter, et le peintre tasse les trous.
    - ⚠ **LE CACHE PASSE AU FORMAT 2** (`Projet.FORMAT_DU_CACHE`) : un lot d'avant ne porte pas la
      provenance, il est périmé et se retranche.
    - ⚠ **LE VIDE N'EFFACE PAS** : pour atteindre le bouton, la souris traverse du ciel.
    - **MESURÉ** : les 541 tuiles du témoin remontent à 541 sommets DIFFÉRENTS qui portent, dans le modèle,
      leur clé ; et chacun appartient à une carte. ⚠ **16 N'EN AVAIENT AUCUNE**, vu à l'image (« this corner
      belongs to no named shape ») : la zone du plateau ignorait le massif de l'est. Corrigé, gardé.
    - Gardé par `test_formes_du_temoin` (117), `test_projet` (32), `fumee_appli` (170). Sept mutations
      rouges (exemplaires tassés, cache d'un vieux format cru, cartes non triées, sommet sans le
      demi-décalage, le vide qui efface, zone de l'est ôtée, carte non encadrée).
- ⚠ **RIEN DE CECI N'A ÉTÉ TENU EN MAIN PAR JORDAN.** Les captures (`capture_app.gd`) montrent les
  panneaux, l'aperçu et la grille locale ; que le rayon tombe où l'œil l'attend, ça se juge souris
  en main.

### LES FORMES SPÉCIALES — DÉCIDÉ (Jordan, 1er octobre 2026), ÉCRIT LE MÊME JOUR

Jordan : garder « Shape operations », et un onglet **Special shapes** — un balcon contre une paroi ; un puits
dans un sol et un tunnel dans une paroi, PERPENDICULAIRES, capables de rejoindre deux salles en restant
ouverts aux deux embouchures ; un pont entre deux parois face à face. Et sa généralisation : une case sur
une paroi, une case sur une autre, même diagonale, un PROFIL, et l'outil les relie.

- **TUNNEL, PUITS ET PONT SONT UNE SEULE OPÉRATION** (`addons/marchingblocks_core/formes_speciales.gd`) : deux
  ANCRES (une case, la normale de sa paroi) ; une JAMBE perpendiculaire à chaque paroi (`taille` cases, jamais
  plus du tiers du trajet), un raccord droit entre leurs bouts ; un PROFIL balayé (rond, carré, arche — sol
  plat et voûte —, et le tablier du pont avec son garde-corps), haut verrouillé sur +Y. Tunnel et puits
  CREUSENT, pont et balcon REMPLISSENT. Un clic : tout droit, jusqu'au premier vide (tunnel, puits — sinon
  `longueur` cases, un cul-de-sac DIT) ou la première matière en face (pont). Le balcon : une dalle à rebord.
- **LA PAROI DIAGONALE** : un escalier de cases n'a que des faces ±X ±Z ; la normale est ESTIMÉE (somme des
  faces horizontales exposées de la fenêtre 3³, arrondie à huit directions). ⚠ **UN PREMIER JET ÉCARTAIT LES
  FACES DE DOS, ET C'ÉTAIT FAUX** — trouvé en cherchant à faire rougir sa mutation : sur une paroi en biais de
  deux cases d'épaisseur il gardait les −Z (perpendiculaires) et pas les −X, et rendait (1,0,0). Sans filtre,
  l'avant et l'arrière d'une paroi mince s'annulent symétriquement.
- **TOUT EST EN ENTIERS** (centres de cases, distances au carré sur 64 bits) : la règle est réécrite en C# et
  en C++, et un départage flottant aurait divergé sur les cases du bord.
- ⚠ **SANS LA TRAVERSÉE DE L'AXE, UN CONDUIT FIN EN BIAIS ÉTAIT TROUÉ** : un profil de taille 1 ne gardait que
  les cases dont le centre est SUR l'axe. Chaque segment ajoute les cases que son axe traverse, un axe à la fois
  (égalité : le plus petit axe) — le conduit est toujours relié par les faces.
- **DÉCIDÉ (Jordan, 1er octobre 2026) — LA FORME RÉPARE ELLE-MÊME LES CONTACTS DIAGONAUX QU'ELLE CRÉE** : par
  tours, sans ordre (tous les damiers autour des cases changées au tour d'avant, appliqués d'un coup) ; creuser
  vide la paire pleine, remplir comble la paire vide. Un damier qui préexistait loin d'elle n'est pas touché.
  Ce n'est pas la complétion retirée au pinceau (§2) : c'est la forme générée qui doit être propre, et
  l'écran DIT combien de cases il a ajoutées.
- ⚠ **DEUX DÉFAUTS VUS EN ÉCRIVANT LES TESTS** : en un clic, le tunnel finissait sur la première case VIDE, et sa
  dernière tranche creusait une rigole dans le sol de la salle atteinte (il finit sur la paroi d'en face) ; et
  les boîtes du parcours de connexité débordaient du massif — le vide passait par l'extérieur, et « sans
  traversée » restait muette.
- **L'APPLI** : la section « Special shapes » sous « Shape operations » (World) ; Straight / Connect, le profil,
  Size (`[ ]`), Depth / Reach, Rail — seulement ce que la forme lit. La forme vise TOUJOURS la matière de la
  couche active ; l'aperçu montre les cases exactes, l'ancre d'un Connect en ambre ; un clic droit ou Échap
  l'oublie ; une forme posée est UNE action (`_appliquer`), un Ctrl+Z. Le manuel (F1) en a une page.
- **DÉCIDÉ (Jordan) — LES TROIS GREFFONS LES ONT** : `mb_shapes.gd`, `MBShapes.cs`, `MBCore/MBShapes.{h,cpp}`,
  et leurs éditeurs (barre Godot, inspecteur Unity, panneau Slate et mode Unreal — réglages sur l'acteur).
  `tools_conformance.json` porte 34 cas de plus (normales et formes), leurs mondes écrits UNE fois
  (`shape_worlds`) : recopiés dans chaque cas, ils portaient le fichier à 1 Mo. Le générateur écrit une case par
  ligne (186 Ko). `test_greffon_peinture` exige que les cas exercent chaque forme, droite et reliée, chaque
  profil, chaque refus sauf « trop grand », un débouché et un cul-de-sac, une diagonale, une réparation.
- **MESURÉ** : `test_formes_speciales` 79 (attendus déroulés à la main, ou jugés par un parcours du vide et par
  `MB.contacts_par_arete`) ; `fumee_appli` (vrais clics par la caméra : aperçu de 15 cases, tunnel, Connect,
  Échap, puits refusé — aussi en première ancre —, pont, balcon, `[ ]`) ; greffon Godot 103 cas et ses gestes ;
  banc .NET et banc C++ (clang, drapeaux d'Unreal) 103 cas, 0 échec ; **Unity 6.6 : 26 tests sur 26** (dont
  `ShapeEditorTests`, Undo compris) ; **Unreal 5.8.3 : BuildPlugin, BUILD SUCCESSFUL, aucun avertissement**.
- **MUTATIONS, TOUTES ROUGES À LA FIN** : 20 sur le cœur, 7 sur l'appli, 3 par greffon sur la règle, 7 sur
  l'éditeur Godot, 3 sur l'éditeur Unity. ⚠ **CINQ ONT D'ABORD ÉTÉ MUETTES** : le prolongement aux ancres et la
  jambe sans bride (les embouchures donnaient sur de l'air : il fallait un sol de salle contre elles), la
  traversée (le parcours débordait), le filtre de dos (c'était le code qui avait tort), l'ancre de Connect sans
  validation (le refus n'était éprouvé qu'en un clic — dans l'appli ET dans le greffon). ⚠ **ET TROIS
  « MUTATIONS » N'ONT RIEN ÉPROUVÉ** : un `sed` à la mauvaise indentation (rien remplacé, compté vert), un
  `dotnet run --no-incremental` (le drapeau partait au programme, qui ne trouvait pas son fichier), une
  mutation C++ qui ne compilait plus (`-Werror`). Rejouées avec un outil qui EXIGE le motif.
- ⚠ **PAS TENU EN MAIN** : ni par Jordan ni dans les éditeurs des greffons — la barre Godot et l'inspecteur Unity
  n'ont pas été dessinés, le mode Unreal ni ouvert ni cliqué. Vu à l'image dans l'appli seulement
  (`capture_formes_speciales.gd`) : tunnel en coude, paroi à 45° percée, pont, balcon, puits, aperçu d'un pont
  en Connect.
- **LA SALLE (« Room ») — DEMANDÉE PAR JORDAN ET ÉCRITE (2 octobre 2026)** : « tracer une sélection en surface à plat
  sur la grille, et extruder vers le haut ou le bas de tant d'étages, tout en conservant le creux dans le volume ».
  - **la règle** (`FS.salle`) : un rectangle d'au moins 3 × 3 sur le plan de l'étage ; vers le HAUT il est le sol,
    vers le BAS le plafond ; `etages` = la hauteur LIBRE (1 à 32) ; murs, sol et plafond d'une case, le dedans creux
    (la roche qui s'y trouvait est creusée) ; la coque répare les contacts par une arête qu'elle crée. ⚠ HORS DE
    `QUOI` et de `forme()` : elle se trace, elle ne s'ancre pas — et les cas d'épreuve des greffons n'ont pas bougé
    (« les greffons attendent la fin du logiciel », §0 ; elle est dans la liste des greffons à faire).
  - **l'écran** : le bouton Room, un glissé sur la grille comme Rect, l'aperçu de la coque (vert) et de ce qui sera
    creusé (rouge), Floors et Up / Down, `[` `]` pour les étages, UN Ctrl+Z ; le manuel (F1) la décrit. Elle n'a pas
    de porte : on en ouvre une au tunnel. ⚠ **SIX FORMES EN UNE RANGÉE ÉLARGISSAIENT TOUTE LA BARRE DE DROITE**, qui
    débordait de l'écran (vu à l'image) : `_rangee_de_choix(…, colonnes)`, deux rangées de trois.
  - **MESURÉ** : `test_formes_speciales` 122 (attendus à la main : coque de 26 cases et son dedans, vers le bas, le dedans
    creusé dans la roche, la réparation jugée par `MB.contacts_par_arete`, les refus, la borne) ; `fumee_appli` 437 (un
    VRAI glissé : 68 cases, le creux, Ctrl+Z, Down, une salle trop étroite refusée et dite, `]`). Sept mutations rouges ;
    la fumée a d'abord attrapé l'aide qui disait encore « rises » après Down. Vu à l'image (aperçu, coupe du creux).
  - ⚠ **PAS TENU EN MAIN.**
- **OUVERT** : un raccord COURBE (aujourd'hui deux jambes et un segment droit) ; un escalier dans un puits ;
  ~~le coût d'un aperçu sur un long conduit de taille 7~~ — mesuré et divisé par cinq le 3 octobre 2026 (22 ms).

#### STAIRS — DEMANDÉ PAR JORDAN (1er octobre 2026 : « ajoute une special shape Stairs »), ÉCRIT LE MÊME JOUR

La demande tenait en une ligne ; **TOUTE LA FORME EST PROPOSÉE**, à valider à l'image et souris en main.
- **D'UN CLIC, CONTRE UNE PAROI, IL ARRIVE AU NIVEAU CLIQUÉ** : on clique la paroi là où l'escalier doit
  déboucher ; le palier est la rangée devant la case cliquée, et chaque rangée plus loin descend — `pas`
  rangées par marche (« Step », 1 à `PAS_MAXI` = 4, 2 par défaut). La rangée est la distance à la paroi
  arrondie AU-DESSUS (la règle du balcon : parois diagonales comprises). Il finit à la première rangée dont
  tous les dessus sont déjà pleins (il a rejoint le sol), sinon au bout de « Length » rangées.
- **CONNECT : DE SOL À SOL** (deux cases cliquées par leur DESSUS — une paroi est refusée, `pas_un_dessus`) :
  de la plus basse à la plus haute, en ligne droite à plat, les marches se partagent la longueur
  (dessus = L.y + t·R / D·D, en entiers) ; plus raide qu'une case par case est refusé (`trop_raide`). Le `pas`
  n'y sert pas. Comme les conduits, la traversée de l'axe garde un escalier fin relié par les faces.
- **CHAQUE COLONNE EST PLEINE JUSQU'AU SOL** ; au-dessus du vide (pas de sol à moins de 64 cases), une volée de
  DEUX cases d'épaisseur — une seule laisserait deux marches voisines se toucher par une arête. Le garde-corps
  (« Rail ») : une case au-dessus du dessus, sur les deux bords. L'escalier ne fait que REMPLIR : s'il entre
  dans la roche, c'est au tunnel de dégager la tête.
- ⚠ **SUR UNE PAROI DIAGONALE, UN ESCALIER DE TAILLE 1 NE TOUCHE PAS LA PAROI** : la bande latérale ne garde
  que les cases de la diagonale, dont la plus proche est à la rangée 2. C'est la même règle que le balcon ;
  la taille 2 y est pleine. Non corrigé.
- **ÉCRIT PARTOUT OÙ VIVENT LES FORMES** : le cœur (`formes_speciales.gd`, `normale_de(…, relier)` et
  `erreur_d_ancre`), l'appli (bouton Stairs, réglage Step, messages, page du manuel), et les trois greffons
  (`mb_shapes.gd` / barre et éditeur Godot ; `MBShapes.cs` / inspecteur Unity ; `MBCore/MBShapes` / acteur,
  mode et panneau Slate Unreal — `Stairs` AJOUTÉ EN DERNIER dans chaque énumération, pour ne pas renuméroter
  ce qu'un niveau ou une scène a sauvé). L'icône `escalier` (`app/icones.gd`) part dans les trois.
  `tools_conformance.json` : **115 cas** (+12 : un clic pas 1 et 2, Length, le vide, au pied de la paroi, la
  paroi à 45° ; Connect droit, cliqué du haut, en biais ; trois refus) et le champ `step` ; quatre mondes de
  plus (`falaise`, `plateau`, `pente`, `butte`). `test_greffon_peinture` exige `stairs` et `stairs+connect`.
- **MESURÉ** : `test_formes_speciales` 110 (+31, attendus déroulés à la main : pas 1 et 2, Length, trois de
  large avec garde-corps, le vide, la paroi diagonale, Connect dans les deux sens ; et une MARCHE À PIED sur la
  surface — la butte ne se gravit pas sans l'escalier, se gravit avec) ; `fumee_appli` (+6 : un vrai clic pose
  palier, marche, garde-corps et passage, un Ctrl+Z, Connect refuse une paroi et le dit) ; greffon Godot, banc
  .NET et banc C++ (clang, drapeaux d'Unreal) **115 cas, 0 échec** ; **Unity 6.6 : 26 sur 26** ; **Unreal
  5.8.3 : BuildPlugin, BUILD SUCCESSFUL, aucun avertissement**.
- **MUTATIONS, TOUTES ROUGES** : dix sur le cœur (pas ignoré, jamais au sol, volée d'une case, pas de bascule
  bas/haut, pas de `trop_raide`, sans traversée, garde-corps partout ×2, Connect qui accepte une paroi, rangée
  arrondie en dessous), deux par greffon, une sur l'appli. ⚠ **« ARRONDIE EN DESSOUS » A D'ABORD ÉTÉ MUETTE** :
  la paroi diagonale n'était jugée que par des propriétés (dans l'air, sans damier, une case par marche), que
  l'autre arrondi respecte aussi — un cas déroulé à la main l'a fait rougir. ⚠ **ET L'OUTIL DE MUTATION A
  MENTI DEUX FOIS** : un remplacement par un texte présent ailleurs dans le fichier ne pouvait pas être défait
  (fichier laissé muté, réparé et vérifié en le régénérant), et `dotnet run --no-incremental` — le piège déjà
  écrit ici — a rendu deux « rouges » sans rien compiler. Il rend désormais le contenu d'origine, et refuse
  si quelqu'un d'autre a touché le fichier pendant la mesure (arrivé une fois sur `vue.gd`).
- ⚠ **PAS TENU EN MAIN, NI VU À L'IMAGE** — ni dans l'appli, ni dans les trois éditeurs. Ni le ressenti dans le
  Play test (une pente de pas 1 est à 45°, à la limite de ce que le personnage gravit).

### LE MODE FLUIDS — DÉCIDÉ EN PARTIE (Jordan, 1er octobre 2026), PAS ÉCRIT

- **UN ATELIER, PLUS UNE SECTION DE WORLD — DÉCIDÉ (Jordan, 2 octobre 2026 : « le mode Fluids aurait dû être un mode
  plutôt qu'une section, et devrait se désactiver proprement quand on le demande »), ÉCRIT LE MÊME JOUR.** Le bouton
  Water, une fois enfoncé, ne se relâchait plus (son clic le ré-enfonçait). Six ateliers : Project · Play test,
  World · Fluids, Geometry · Texturing. Fluids montre le monde et SA barre de droite (couches d'eau, Look, Leave) ;
  y entrer prend l'outil Water (`_entrer_dans_les_fluides`), en sortir — Échap, Leave, n'importe quel autre atelier,
  tout passe par `_aller_a` — rend l'outil de World d'avant (`_sortir_des_fluides`). Dans Fluids, seuls Espace
  (Navigate), PgUp / PgDn et Échap. Gardé par `fumee_appli` (561) ; mutation rouge (ne pas en sortir : trois
  rouges). ⚠ « New layer » mène à World, donc sort de Fluids. ⚠ Pas tenu en main.
- **LE LAC DÉBORDE SI UNE CHUTE EST PROCHE — DÉCIDÉ (Jordan, 2 octobre 2026 : « un lac qui a une digue qui donne sur une
  falaise ne déborde pas vers le bas comme une coulée, ce qui empêche de faire simplement des lacs avec des chutes
  d'eau là où la matière laisse une ouverture » ; choisi entre « tout lac déborde », « réglage par couche » et
  celui-ci).** Rempli à son seuil, un lac regarde à plat depuis le seuil (la coulée de la rivière) : une chute, une
  autre eau ou le bord du monde à au plus `PORTEE_DE_DEBORD` = 4 cases (**PROPOSÉ** : « quelques cases ») → il est le
  premier lac d'une RIVIÈRE qui part du seuil ; sinon (un cratère dans une plaine) il reste calme. Renverse « un lac ne
  déborde jamais ». ⚠ Une cuvette posée sur le vide déborde donc par-dessus son mur : les tests qui voulaient un lac
  calme l'ont noyée dans un plateau. Gardé par `test_fluides` (déroulés à la main : l'échancrure sur le vide, la
  portée à 4 et à 5 cases, la cuvette nue) ; deux mutations rouges (jamais de débordement, portée stricte).
- **LA MER SE CHOISIT AVANT DE SE CALCULER — DEMANDÉ PAR JORDAN (4 octobre 2026 : « les opérations d'eau coûtent trop
  cher, surtout pour l'océan ; un preview pour choisir la hauteur avant de valider, et que le calcul ne se lance
  qu'après »), ÉCRIT LE MÊME JOUR.** ⚠ Survoler le vide REMPLISSAIT L'OCÉAN ENTIER à chaque case visée (`FL.source`),
  plus la boîte du monde (un balayage de toutes les cases, 57 ms sur l'exemple) à chaque `dans_le_vide` ; le clic le
  refaisait, puis le recalcul une troisième fois.
  - **le survol du vide montre un PLAN** (`Vue.montrer_plan_mer`, à rangée + `NAPPE`, sur la boîte du monde + 24 cases),
    rien n'est calculé ; sur une mer déjà là, son plan en rouge (plus sa surface case par case) ;
  - **un premier clic épingle la hauteur** (`_mer_choisie`) ; la molette seule (un geste, §5 « la molette »), PgUp / PgDn
    ou ↑ ↓ la règlent ; **un second clic ou Entrée la pose** — seul moment où l'eau se recalcule, UNE fois, barre
    d'attente forcée ; clic droit ou Échap l'abandonnent (Échap ne quitte pas Fluids). La source garde la colonne cliquée
    si elle reste dans le vide à cette hauteur, sinon une colonne juste hors de la boîte ;
  - **la boîte du monde est gardée** (`_boite_eau`, rendue par `FL.monde` sous `"boite"`) ; `sources_en_largeur` la reçoit ;
  - ⚠ **UN DÉFAUT D'AVANT, TROUVÉ PAR LA FUMÉE** : un clic se classait contre `_occ_eau`, qui ne suivait les gestes qu'au
    recalcul différé — un clic sur une colonne posée dans la même image la voyait vide, se croyait « dans le vide » (une
    mer), et ne devenait la rivière voulue qu'au recalcul. Le survol et le clic tiennent les cases à jour sans
    recalculer l'eau (`_tenir_occ_eau`), ce qu'ils appliquent reste noté pour la reprise.
  - **MESURÉ** : `fumee_appli` (+11 : le survol pose un plan sans cases ni calcul, le clic épingle sans rien poser, deux
    crans → 2, PgDn ×2 → 0, la souris ne déplace plus, le second clic pose et lance le calcul, clic droit et Échap
    abandonnent, la mer déplacée, Entrée à la même hauteur dit « already ») ; `test_fluides` 244, `test_greffon_peinture`
    255. **Cinq mutations rouges**, rejouées dans une COPIE à dossier de données isolé (une autre session travaillait
    dans le dépôt — la première passe, dans le dépôt, partageait ses réglages et rendait des échecs étrangers) : le survol
    qui remplit l'océan, le premier clic qui pose, la molette non branchée, le clic sur des cases en retard, PgDn ignoré.
    ⚠ Le gain n'a pas été chronométré avec fenêtre ; **PAS TENU EN MAIN**. Le manuel (F1) le décrit.
- **LA LENTEUR DE L'EAU — MESURÉE ET CORRIGÉE (Jordan, 2 octobre 2026 : « les algos d'eau sont beaucoup trop
  lents »).** `DEV_TOOLS/sonde_cout_eau.gd` sur `test.mbproj` (1 723 cases, une mer de 41 306 cases) : ~180 ms par
  recalcul (mer 90 ms, maillage 87 ms), refait à CHAQUE geste.
  - **la mer par tronçons de colonne** (`FL.ocean`) : un intervalle vertical de vide par colonne ; le bas de chaque
    colonne est l'horizon, les autres tronçons rejoignent la mer par un voisin dont l'intervalle chevauche. Même
    ensemble (gardé contre un remplissage case par case écrit dans le test, 12 mondes troués au hasard) ; le maillage
    lit surface et profondeur sur les tronçons (`EM.surface_des_colonnes`). 90 → 35 ms ;
  - **le tri de la surface par clé entière** (`EM._triees`) : un `sort_custom` appelait une fonction GDScript par
    comparaison. Maillage 87 → 30 ms ;
  - **LA REPRISE** (`FL.monde(…, avant, changees)`) : chaque source rend son EMPRISE (la boîte de ce qu'elle a
    regardé, + 1) ; un geste dont aucune case n'y tombe, sous la même boîte du monde (et les mers toutes reprises pour
    un lac ou une rivière), la reprend telle quelle, et sa couche garde son maillage. Peindre au-dessus de la mer ne
    recalcule plus rien. Gardé par `test_fluides` (60 gestes au hasard comparés à un calcul complet ; le fond du lac
    creusé) et `fumee_appli` (une case loin du lac : même corps, même maillage). Mutations rouges : reprise aveugle aux
    changements, mers reprises changées, emprise sans la chute, tronçons sans passage latéral, profondeur fausse, la
    nappe toujours refaite ; ⚠ **« emprise sans + 1 » D'ABORD MUETTE** : le fond d'un lac est une case PLEINE, jamais
    « vue » — aucun geste au hasard ne la creusait. Cas construit.
  - **SUR L'EXEMPLE (196 415 cases, 6 sources)** : un calcul complet passait de 7,5 s à 2,3 s — la boîte du monde
    calculée UNE fois par `monde()` (57 ms par appel, trois appels par source) ; l'eau lue dans deux dictionnaires au
    lieu d'un `Callable` appelé à chaque case visitée ; le tas de priorité sur des clés entières (priorité, ordre
    d'insertion) au lieu de tableaux comparés par une fonction — même ordre, mêmes cours case par case.
  - **UNE FACE DE LA BOÎTE QUI BOUGE LOIN D'UNE SOURCE NE LA FAIT PLUS RECALCULER** (`_boite_compatible`) : peindre
    au-dessus du point le plus haut montait le dessus de la boîte et refaisait toute l'eau (8 s sur l'exemple, mesuré
    à la fenêtre). Gardé par `test_fluides` (150 gestes au hasard, dont des faces qui sortent et qui rentrent) ;
    deux mutations rouges. ⚠ **DEUX MUETTES** : ne regarder que l'ANCIENNE place d'une face qui a bougé (côtés, puis
    dessus). Elle ne compte que quand la boîte RÉTRÉCIT vers une source et que deux seuils de même hauteur existent —
    pas construit. La condition prudente est gardée.
  - **L'APPLI NE RELIT PLUS LE MONDE ENTIER** : chaque geste note ses cases (`_noter_pour_l_eau`), et l'eau tient
    ses cases à jour au lieu de relire ~196 000 cases et de les comparer (~150 ms par geste). Deux mutations rouges
    (le coup de pinceau, l'historique).

Jordan : un clic pose du liquide — un plan animé, légèrement déformé, sous shader — qui reconnaît s'il est
dans un creux fermé (lac, flaque), dans un creux qui déborde (rivière, cascade) ou dans le vide (océan qui
cerne la matière à sa hauteur jusqu'à l'horizon) ; la coulée suit le monde en temps réel.

- **PROPOSÉ — ON ENREGISTRE LA SOURCE, JAMAIS LA SURFACE** : (case, niveau, preset). Lacs, rivières et
  océans en sont DÉDUITS à chaque changement de cases (seules les étendues dont la boîte touche les cases
  changées). Une seule opération : remplissage horizontal à la hauteur du clic — enfermé = lac ; une issue
  plus basse = le lac redescend à son seuil et une rivière part de là en suivant la pente (*priority-flood*),
  chaque chute verticale une cascade ; clic dans le vide = océan, rempli DEPUIS L'HORIZON. Seule l'animation
  coule (carte de flux, comme `D:/RollingStones/CLIENT/eau.gd`) ; le plan ne fait que d'ondes légères.
- ⚠ **L'EAU NE TOUCHE JAMAIS AUX CASES** (§3) ; une rivière sans issue ou une source sous la matière est DITE.
- **DÉCIDÉ — UNE CAVITÉ EST SÈCHE SI AUCUN CONDUIT QUI Y MÈNE N'EST OUVERT SOUS L'EAU.** Reliée sous le
  niveau, elle se remplit jusqu'au niveau (vases communicants : pas de poche d'air piégée) ; au-dessus, rien.
- **DÉCIDÉ — L'EAU APPARTIENT AU MONDE ENTIER, DANS SES PROPRES COUCHES D'EAU**, indépendantes des couches de
  tuiles : une couche d'eau = nom, visibilité, preset, sources. **PROPOSÉ** : elle se calcule contre TOUTES les
  couches de tuiles, visibles ou non — cacher une couche pour travailler ne doit pas inonder le monde.
- **DÉCIDÉ — ORDRE** : l'appli d'abord, l'eau CUITE à l'export (maillages + son contrat de données) ; la règle
  dans les trois greffons ensuite, avec ses cas d'épreuve (comme les formes spéciales). ⚠ **« ENSUITE » = QUAND LE
  LOGICIEL ENTIER SERA FINI** (Jordan, 1er octobre 2026, §0) : l'étape 5 est dans la liste des greffons à faire.
- **PROPOSÉ — LE CONTRAT DE DONNÉES DE L'EAU** : chaque maillage exporté porte en attributs le vecteur de flux,
  le type (lac, rivière, cascade, océan), la profondeur et un masque de rivage ; le greffon a UN emplacement de
  matériau par type. ⚠ **UN SHADER NE VOYAGE PAS** (§4) : les trois presets — stylisé (RiverStones), transparent
  à réfraction, réfléchissant — s'écrivent dans chaque moteur, et l'artiste est prévenu qu'ils sont des
  EXEMPLES : son propre shader reçoit les mêmes données.
- **ÉTAPE 1 ÉCRITE (1er octobre 2026) — LA RÈGLE DANS LE CŒUR** (`addons/marchingblocks_core/fluides.gd`), en
  entiers, voisins dans un ordre fixe, tas départagé par l'ORDRE D'INSERTION (elle sera réécrite en C# et C++) :
  - **la boîte du monde** est celle des cases pleines élargie d'une case ; ses côtés et son dessous sont
    l'HORIZON. ⚠ **PAS SON DESSUS** : l'eau qui coule sur le toit le plus haut n'a pas quitté le monde ;
  - **océan** : la source n'a rien de plein sous elle (`dans_le_vide`) ; remplissage depuis un coin de la boîte,
    sans dépasser le niveau. Un océan sous le monde entier n'a aucune case : un plan seul ;
  - **lac** : l'eau tombée au sol ne trouve à son étage aucune case d'où tomber ; remplissage PAR PRIORITÉ
    (priorité = la plus haute altitude franchie) jusqu'à la première case qui touche l'horizon ou une autre eau
    (P) : le lac est tout ce qui est sorti sous P, niveau P − 1. Un lac ne déborde pas ; dans une cavité close il
    monte jusqu'à la hauteur du clic (« ferme ») ;
  - **rivière** : à son étage, le plus court chemin vers une case d'où tomber, la chute, et ainsi de suite ; un
    creux en route se remplit et déborde par son SEUIL (la première case du chemin à l'altitude P). ⚠ **LA CHUTE
    NE S'ARRÊTE QU'AU FOND DE LA BOÎTE** : arrêtée au côté, une cascade au pied d'une falaise du bord du monde
    s'interrompait en l'air (vu rougir dans trois cas) ;
  - **`monde()`** calcule les océans d'abord, puis chaque autre source contre les océans SEULS : l'ordre des
    sources ne change rien. `surface()` (pas sous la roche) et `profondeur()` (−1 au large) pour le contrat.
  - **MESURÉ** (`DEV_TOOLS/test_fluides.gd`, 66) — attendus déroulés à la main : cuvette à ras bord (18 cases,
    depuis le fond, le milieu et le ciel), échancrée (9), poche noyée sous le linteau (20), le départage de deux
    seuils égaux, du haut d'un mur, un escalier et une rivière qui traverse une fosse — case par case —, une île
    (181 cases d'océan, la cavité close sèche, la galerie noyée jusqu'au niveau, 32 de surface), une rivière qui
    rejoint l'océan, une cavité close, les refus. Coût : océan de 3 676 cases + lac de 1 764 en **80 ms**
    (48 × 8 × 48, headless).
  - **16 mutations, toutes rouges.** ⚠ **TROIS D'ABORD MUETTES** : le départage à l'envers (la fosse était
    SYMÉTRIQUE depuis son milieu, les deux ordres y tombaient d'accord — départ décalé d'une case) ; l'eau
    voisine à l'étage (inatteignable par `monde()` — une case de rivière voisine d'un océan à son étage EST de
    l'océan —, gardée par une `eau_fixe` construite) ; et le départ ramené au haut de la boîte, mutation
    ÉQUIVALENTE, retirée du code. ⚠ « Jamais dans le vide » faisait PENDRE la suite : la descente du clic au sol
    n'avait pas de borne ; bornée au fond de la boîte.
  - ⚠ **CE QUI N'EST PAS DÉCIDÉ ET A ÉTÉ CHOISI POUR ÉCRIRE** (PROPOSÉ) : une rivière fait UNE case de large ;
    elle suit le plus court chemin à plat, ce qui fait d'un clic sur une grande plaine une rivière qui rampe
    jusqu'à la falaise la plus proche ; deux rivières se recouvrent sans se rejoindre.
- **ÉTAPE 2 ÉCRITE (1er octobre 2026) — LE MODE FLUIDS DANS L'APPLI** : la section « Fluids » de la barre de
  droite (World), l'outil **Water**, les couches d'eau (œil, active, New, Delete), le preset.
  - **le clic** : la source est la case DEVANT la face visée (toutes les couches visibles), sinon sur le plan de
    l'étage ; l'aperçu montre la surface et le cours à venir (rouge sur une eau déjà là) ; le clic droit retire
    la source de l'eau visée ; un clic dans une eau existante ne pose rien et le dit. Chaque geste est UNE action
    de l'historique.
  - **l'eau suit le monde** : `_eau_perimee` (une fois par image) est appelée par `_reconstruire` (toute action
    de cases, dans les deux sens) ET par `_touche` — ⚠ un coup de pinceau n'est PAS rejoué par l'historique, et
    la garde qui ne passait que par `_appliquer` laissait muette l'absence de ce second appel. Elle se calcule
    contre les cases de TOUTES les couches de tuiles, cachées comprises.
  - **le projet** porte `eaux` (nom, visible, preset, id, SOURCES) ; un projet d'avant se relit sans eau ; une
    entrée malformée refuse le fichier entier.
  - **le maillage** (`addons/marchingblocks_core/eau_maillage.gd`) : nappe en rangée + 0,7 (sous le dessus du bord,
    vu à 0,75), bande de rivière en rangée − 0,15, avancée de 0,45 sous chaque voisine pleine, l'océan prolongé à
    ±2000 hors de la boîte. Le **contrat** dans les sommets : COLOR.rg le courant, COLOR.b le genre (0 / 0,5 / 1),
    COLOR.a la profondeur / 8 — ⚠ **QUANTIFIÉ AU 1/255** (les couleurs de sommet sont stockées sur 8 bits : 0,25
    y vaut 64/255).
  - **le preset « stylise »** (`eau_presets.gd`) : l'eau de RiverStones (`D:/RollingStones/CLIENT/eau.gd` —
    `D:/RiverStones` n'existe pas), courant lu dans les sommets, cascades en stries qui tombent. ⚠ `ALPHA = 1`
    exprès (la passe transparente lit la profondeur), donc `depth_draw_always` : sans lui, la bande noyée au fond
    d'une fosse se dessinait PAR-DESSUS le lac (vu à l'image).
  - ⚠ **DEUX DÉFAUTS VUS À L'IMAGE, QU'AUCUN TEST NE LISAIT** (`DEV_TOOLS/capture_fluides.gd`, avec fenêtre) :
    une bande par case « coule » mettait la bande de la LÈVRE en l'air au-dessus de chaque cascade, et laissait
    sèche la case où l'eau retombe. Règle : une bande sur toute case du cours qui REPOSE SUR LA MATIÈRE ; la lame
    est 0,1 en retrait du plan de la lèvre, recouverte par la bande d'en haut. Gardé (`test_fluides`, trois
    mutations rouges).
  - **MESURÉ** : `test_fluides` 86 (le maillage : hauteurs, débords, lames, sens des faces, contrat — attendus à la
    main), `test_projet` 62, `fumee_appli` (de vrais clics : lac de 18, aperçu de 9, échancrure creuse → 9 puis
    refermée → 18, une case d'une AUTRE couche CACHÉE retient l'eau, un vrai coup de pinceau, rivière qui sort puis
    REJOINT la mer posée après, clic droit et Ctrl+Z, couche cachée, enregistrée, ROUVERTE). **23 mutations
    rouges** (écran, vue, maillage, projet) ; ⚠ une d'abord MUETTE (le coup de pinceau, ci-dessus), une d'abord
    INVALIDE (le motif ne couvrait que le début d'une ligne : l'appli ne compilait plus — un échec de compilation
    n'est pas une garde qui rougit).
  - ⚠ **UNE AUTRE SESSION TRAVAILLAIT EN MÊME TEMPS DANS LE DÉPÔT** (l'escalier des formes spéciales) : les
    mutations qui réécrivent un fichier partagé pendant des minutes ont été rejouées dans une COPIE ; et deux
    sessions qui lancent fumée et captures se passent `user://reglages.cfg` — la valeur « rendue » à la fin peut
    être celle, provisoire, de l'autre. Une copie avec `config/use_custom_user_dir` n'en partage rien.
  - ⚠ **PAS TENU EN MAIN, PAS JUGÉ PAR JORDAN** : le rendu (le lac à ras bord, les traits blancs au large, l'écume
    au pied des cascades), les hauteurs de nappe sur de l'ART sculpté, le coût du recalcul sur une grande carte
    pendant un coup de pinceau. Pas de nage au Play test.
- **ÉTAPE 3 ÉCRITE (1er octobre 2026) — DEUX PRESETS DE PLUS** (`eau_presets.gd`, choisis par couche d'eau dans
  « Look », enregistrés avec elle) :
  - **« transparent »** (Clear) : le fond lu dans la texture d'écran, décalé par la normale des vagues, en
    ÉMISSION (il est déjà éclairé) ; absorption de Beer-Lambert sur la profondeur verticale ; ce qui est DEVANT la
    nappe n'est pas réfracté dedans ; éclairée (reflet du soleil) ;
  - **« reflechissant »** (Reflective) : sombre et lisse, opacité = max(Fresnel, profondeur) ; reflets du ciel de
    l'environnement, et du RELIEF par un rayon réfléchi marché contre le tampon de profondeur (le SSR du moteur
    ignore les transparents). ⚠ Le miroir se calcule sur une normale APLATIE (`aplati` 0,3) : avec toute la houle,
    le reflet partait en taches (vu au diagnostic, poids du reflet peint en rouge). ⚠ **DANS WORLD LE CIEL EST LE
    CIEL NEUTRE GRIS** (la charte l'a voulu pour les métaux) : l'eau y paraît grise ; au Play test, elle reflète le
    ciel bleu-violet — NON VU ;
  - les deux partagent `COMMUN` (bruit, vagues tournées qui défilent dans le sens du courant, profondeur, stries) ;
    une cascade y est de l'ÉCUME presque opaque — transparente comme une nappe, elle n'était qu'un fantôme gris
    (vu à l'image).
  - ⚠ **LE COMPILATEUR DE SHADERS NE TOURNE PAS EN HEADLESS** : deux fois, un paramètre de fonction portait le nom
    d'un uniforme (« Redefinition of 'ampleur' », puis « 'ecume' ») et seule la capture avec fenêtre l'a dit.
    `test_fluides` lit désormais le TEXTE de chaque preset (aucun paramètre au nom d'un uniforme ou d'un varying,
    marqueurs remplacés, contrat lu) — vu rougir en remettant `ecume`. Une capture qui sort une ligne « SHADER
    ERROR » est un échec.
  - **MESURÉ** : `test_fluides` 100, `fumee_appli` 375 (la liste propose trois presets, Reflective change le shader
    de la nappe, le preset s'enregistre) ; trois mutations rouges (preset ignoré, non enregistré, shader échangé).
    Vu à l'image (`capture_fluides.gd`, dans une copie du projet). Le manuel (F1) décrit les trois.
  - ⚠ **PAS JUGÉ PAR JORDAN** ; les réglages (absorption, réfraction, `aplati`, opacité mini) sont des choix à l'œil.
- **ÉTAPE 4 ÉCRITE (1er octobre 2026) — L'EAU CUITE DANS LE MONDE EXPORTÉ** (`format_monde.gd`) :
  - ⚠ **DANS LE `.mbworld`, PAS DANS UN `.mbset`** : un jeu de tuiles appartient à une couche de tuiles, l'eau au
    monde entier. `world.json` gagne une clé `water` : par couche d'eau, nom, visibilité, `look` (« stylized »,
    « clear », « reflective » — une SUGGESTION, un aspect inconnu est accepté), `mesh` (chemin RELATIF de
    `water/<nom>.glb`, ou null) et `sources` (à plat, DANS L'ORDRE de pose). Chaque `.glb` : un nœud et un maillage
    NOMMÉS (Unreal), un matériau `mb_water_<look>` à remplacer, et le contrat dans COLOR_0 et TEXCOORD_0, en espace
    du format. La règle est écrite dans le README (`regle_eau()`).
  - ⚠ **PAS ENCORE DANS `regle()` NI DANS `world_conformance.json`** : les trois lecteurs des greffons ne lisent que
    `layers` (vérifié dans leur source), la clé en plus ne les fait pas refuser — gardé pour Godot (`mb_world_file`
    lit ce monde). Les y mettre rendrait périmés les cas d'épreuve des trois greffons : c'est l'étape 5.
  - ⚠ **LES NOMS SE LISENT DANS LE JSON DU FICHIER** : relu par l'importeur de Godot, le maillage s'appelle
    « nœud_maillage » — la garde qui passait par lui rougissait sur un fichier juste.
  - **MESURÉ** : `test_fluides` 121 (exporter un vrai monde, relire `world.json`, la nappe : mêmes sommets à la même
    place, même contrat au 1/255 ; les refus de `lire_eau`) ; huit mutations rouges (chemin absolu, maillage sans
    nom, sources perdues, aspect non traduit, source fractionnaire acceptée, pas de clé, README sans contrat, nappe
    sans couleurs). Le BOUTON d'export ne passe pas par la fumée (panneau d'attente) : mené avec fenêtre par
    `capture_fluides.gd`, qui relit ce qu'il a écrit.
- **LA NAGE AU PLAY TEST — DEMANDÉE ET ÉCRITE (Jordan, 1er octobre 2026)** :
  - **la règle dans le cœur** (`EauMaillage.niveau_au_point`) : la surface DESSINÉE de la colonne d'eau qui contient
    un point (rangée du haut + 0,7), le large hors de la boîte pour les océans, −INF ailleurs. Seule l'eau DORMANTE
    des couches d'eau VISIBLES compte (lacs, lacs des rivières, océans) : une bande de rivière est une lame, on y
    marche. L'écran la donne à la vue avant de jouer (`_eau_pour_le_jeu`).
  - **le personnage** (`personnage.gd`, un troisième régime à côté de la marche et du vol) : immergé de plus de
    0,35, il nage — flottaison les pieds 0,55 sous la nappe, 2,2 cases/s (3,4 avec Maj), plongée avec la touche de
    descente du vol (A en AZERTY), Espace pour remonter, et il se hisse sur une berge d'au plus une case en nageant
    contre elle (la berge d'un lac à ras bord est 0,6 au-dessus de ses pieds). Une brasse à l'animation, du
    surplace à l'arrêt. **Sous la nappe, la caméra voit à travers un voile** (le brouillard de l'environnement).
  - ⚠ **SONDER LE TORSE, PAS LES PIEDS — VU ROUGIR** : au fond d'un lac, les pieds sont sur le dessus VU du plancher
    (0,75 dans sa case) ; un point à +0,2 tombe dans la case PLEINE du plancher, hors de l'eau pour la règle, et il
    marchait au fond.
  - ⚠ **LA RÈGLE DIT CE QUE LE DESSIN MONTRE — UN DÉFAUT RÉEL, TROUVÉ PAR UNE MUTATION MUETTE** : « ne se hisse
    pas » restait verte, parce que le test (« x < 61 ») était satisfait par un nageur COLLÉ à la face amincie du mur
    (60,94). Resserré (il doit franchir le mur), il a rougi sur le vrai code : le centre du corps était entré dans la
    case du mur, « hors de l'eau » pour la règle — il retombait au fond et ne sortait JAMAIS. Désormais un point
    d'une case pleine à moins de `DEBORD` (0,45, l'avancée de la nappe dessinée sous la roche) d'une case d'eau est
    dans cette eau.
  - **MESURÉ** : `test_fluides` 132 (la surface : au fond, au-dessus de la nappe dans la case du haut, au-dessus du
    lac, dans le mur, à 0,3 de l'eau dans la case du mur, au large, la galerie noyée, la cavité close) ;
    `fumee_appli` 402 (de vraies touches : il flotte à 2,15 sans toucher le fond, plonge, la caméra se voile, il nage
    au fond, remonte, nage moins vite qu'il ne marche, se hisse et FRANCHIT le mur ; hors du jeu, jamais de voile).
    Onze mutations rouges (jamais nager, sonde aux pieds, ne se hisse pas, ne plonge pas, vitesse de marche, jamais
    de voile, eau non donnée au jeu, nappe sans 0,7, pas de large, règle sans débord ×2).
  - ⚠ **PAS TENU EN MAIN** : le ressenti (vitesse, flottaison, la sortie de l'eau), le voile. Pas de courant dans
    une rivière, pas d'éclaboussure, pas de nage dans une couche d'eau cachée (sans garde).
- **OUVERT** : le rivage se juge à l'image (la matière amincie est en retrait d'un quart de case — l'écume par
  profondeur devrait le régler sans rien déclarer) ; la hauteur exacte du plan dans sa case ; l'océan au bord du
  vide ; nager dans le Play test ; d'autres liquides (lave, marécage) comme simples presets.

- **PAS UN PLAN PAR CASE — DEMANDÉ PAR JORDAN (2 octobre 2026) : « pour l'océan précisément il ne faut pas un plan
  par tuile », ÉCRIT LE MÊME JOUR.** Une nappe (océan, lac, lac d'une rivière) posait un carré par case de sa surface :
  `EauMaillage.rectangles_de_nappe` les FUSIONNE — dans une rangée, les cases contiguës de même couleur (profondeur) et
  de mêmes débords en z ; puis les bandes voisines en z de même étendue et de même couleur. Chaque union joint deux
  rectangles qui partagent un côté ENTIER : l'aire couverte, la couleur en chaque point et les UV (x, z du monde) sont
  ceux d'avant. ⚠ **PAS UN PLAN UNIQUE** : il traverserait les grottes sèches au niveau de l'eau. Ordre fixe (y, z, x).
  - **MESURÉ** : l'océan autour du plateau 12 × 12 passe de 266 sommets-triplets à 12, le lac de la cuvette (9 cases) à
    UNE nappe ; `test_fluides` (156, +8) compare À LA RÈGLE D'AVANT recalculée dans le test (un carré par case, débords
    de 0,45, couleur de profondeur), point par point sur une grille fine décalée des bords — l'ensemble des couleurs
    qui couvrent chaque point est le même, sur l'île à deux niveaux, la cuvette et un fond varié qu'un îlot perce.
    Trois mutations rouges (couleur ignorée, débord du dernier oublié, débords en z non comparés). ⚠ « bandes unies
    malgré un débord vers le bas » était MUETTE, et ÉQUIVALENTE : deux bandes de même étendue ont les mêmes cases, et
    celle d'en dessous est de l'eau — la condition a été retirée.
  - ⚠ **LE REFUS SUR UN PETIT MONDE N'EST PAS REPRODUIT** (sonde hors dépôt : une case, une île, un plateau, une
    cuvette, huit clics chacun — jamais d'erreur). Mais un clic SUR l'île vise la case au-dessus de la matière : l'eau
    y devient un lac ou une rivière, jamais un océan — un océan naît d'un clic dans le VIDE. OUVERT : le message exact
    vu par Jordan.
- **LES DEMANDES DU 3 OCTOBRE 2026 — ÉCRITES LE MÊME JOUR** (Jordan : « il faut copier l'image qu'on choisit ? et les
  waterfalls n'ont pas de largeur réglable à la pose […] pas de bouton simple pour étendre verticalement une sélection
  depuis qu'on a fusionné Extrude […] pas de radius de peinture de sélection pour le mode Select dans World, afin de
  peindre une sélection pour en faire ce qu'on veut, comme une room quelconque ») :
  - **L'IMAGE CHOISIE EST COPIÉE DANS LE PROJET** (`Peinture.copier_dans_le_projet`) : l'albedo ET son ensemble PBR
    (les cartes trouvées à côté) dans `<couche>_images/<nom de l'albedo>/`, noms inchangés (l'ensemble s'y retrouve) ;
    une copie identique (MD5) est reprise, une autre image du même nom va dans `<nom>_2/` ; un dossier resté VIDE se
    reprend (⚠ défaut vu par une mutation : il poussait la copie en `_3`). Peindre ne touche plus jamais l'original
    (le « vu en passant » des ensembles PBR, ci-dessus, est réglé). `test_peinture` 58 (+6, de vrais fichiers) ; trois
    mutations rouges.
  - **LA LARGEUR D'UNE RIVIÈRE À LA POSE** (`FL.sources_en_largeur`, réglage « River width » 1 à 9 dans Fluids) :
    autant de sources côte à côte, EN TRAVERS du premier pas horizontal de la rivière, centrées (une de plus du côté +
    si paire) ; seules restent les voisines qui sont des RIVIÈRES (ni matière, ni lac, ni mer, ni eau déjà là). UNE
    annulation pour toutes ; l'aperçu montre la rivière entière. Un lac et la mer ne s'élargissent pas. `test_fluides`
    210 (+8, une marche large écrite à la main) ; trois mutations rouges (le long du courant, toute voisine acceptée,
    pas centrée). ⚠ La cuvette NUE des tests déborde (c'est une rivière) : le cas « un lac » prend la cuvette calme.
  - **« Extend selection ↑ » / « ↓ »** dans la section Selection : le mode « étendre » d'Extrude (Maj + clic), en
    bouton, cases vides comprises, sans rien poser. ⚠ « SELECTION » DANS LE NOM : l'ancien « Extend up » posait de la
    matière comme Extrude, et c'est cette ambiguïté qui l'avait fait retirer le 2 octobre — la garde interdit toujours
    les anciens noms.
  - **« Select empty cells too »** (sous le pinceau, visible avec Select) : le pinceau Select prend aussi l'AIR
    (`Vue.selection_vide`), aperçu compris — peindre l'empreinte d'une pièce sur la grille (pinceau Disque), puis
    Extend selection ↑ et Fill.
  - Gardé par `fumee_appli` (627, +16, de vrais clics à travers la caméra et les vrais boutons : l'air pris ou non,
    ↑ ×2 et ↓ sans rien poser, Fill qui peint une colonne dans l'air, trois sources en travers et UN Ctrl+Z, l'image
    copiée avec sa normale) ; quatre mutations (voir le commit).
  - **ROOM FROM SELECTION — DEMANDÉE PAR JORDAN (« la special shape Room a-t-elle une fonction pour dessiner une sélection
    quelconque à plat, et l'extruder en room verticalement ? » — non ; « go »), ÉCRITE LE MÊME JOUR.** `FS.salle_depuis` :
    l'EMPREINTE est la sélection vue d'en haut ; sa base, la plus basse rangée vers le haut, la plus haute vers le bas ;
    le sol et le plafond couvrent l'empreinte, les MURS sont ses cases de bord (un voisin horizontal hors d'elle), le
    reste est creux ; les contacts par arête qu'elle crée sont comblés comme pour `salle` (à un angle rentrant, les deux
    murs). Dans Selection : Floors et Up / Down (les MÊMES réglages que la forme Room, synchronisés dans les deux sens) et
    le bouton. `test_formes_speciales` 140 (+11 : l'empreinte 3 × 3 = la salle du rectangle, haut et bas ; un L de 21
    cases — 6 intérieures, 72 de coque et 4 de réparation, compté à la main ; dans la roche, les 12 cases du dedans
    creusées ; une ligne refusée ; la base sur deux hauteurs ; deux carrés par un coin réparés) ; `fumee_appli` 683 (+4 :
    le vrai bouton, 76 cases, une annulation, les réglages synchronisés). Cinq mutations rouges. ⚠ Mon premier décompte
    du L (19 cases, 64) était FAUX — la règle avait raison.
  - **LE MICRO DE L'EAU** (Jordan : « la texture des eaux a une macro mais pas de micro, à l'échelle du stickman ») :
    les vagues allaient de 2 à 5 cases (et un bruit de ~0,8) ; rien de plus fin. `pente_micro` (tronc commun) : trois
    octaves d'un bruit DÉRIVABLE (~0,14 / 0,07 / 0,04 case), tournées, qui défilent avec le courant ; pente analytique ;
    chaque octave s'EFFACE quand un pixel couvre plus d'un quart de ride. `normale_eau` l'ajoute aux vagues dans les
    presets clair, réfléchissant, marais et acide (uniform `micro`, 0 l'éteint) ; le stylisé a de courts ÉCLATS clairs à
    la même échelle ; la lave n'en a pas. ⚠ **QUATRE ONDES PURES FAISAIENT UN QUADRILLAGE DE POINTS** (vu à l'image) :
    remplacées par le bruit. ⚠ Sous Xvfb (OpenGL), les shaders à texture d'écran sont dégradés : le rendu se juge en
    Vulkan. Gardé par `test_fluides` (216 : l'appel par preset, au TEXTE) ; une mutation rouge.
  - **LE SCULPT — DÉCIDÉ (Jordan : « 1 et 2 », oui aux outils de sculpt) ET ÉCRIT LE MÊME JOUR.** Dans Witness geometry,
    une section **Sculpt** : un interrupteur, cinq pinceaux (**Draw**, **Inflate**, **Smooth**, **Flatten**, **Grab**),
    rayon (cases), force, dureté ; Ctrl creuse, Maj lisse, comme dans Blender ; un cercle sous la souris. Le pinceau
    agit sur la tuile où le trait commence ; toutes ses copies suivent (une tuile par clé).
    - **Le cœur** (`MaillageEdite.pinceau_sculpt`, pur) : le déplacement de chaque sommet sous le pinceau. Draw le long
      de la normale VISÉE, Inflate le long de la normale de CHAQUE sommet, Smooth vers la moyenne des voisins, Flatten
      vers le plan moyen pondéré, Grab le glissé ; un coup Draw à force 1 pousse de 10 % du rayon.
    - **Le modeleur** suit les routes de G : sommets de bord ramenés dans leur plan et propagés aux autres tuiles, BRIDE
      (un coup qui replierait une face s'arrête au dernier point sain, par dichotomie), UN Ctrl+Z par trait pour toutes
      les tuiles.
    - ⚠ **UN DÉFAUT DE FOND, TROUVÉ PAR LA FUMÉE : 4 742 SOMMETS DE JOINT SANS PARTENAIRE APRÈS UN TRAIT.** Un pinceau
      donne des déplacements DIFFÉRENTS aux membres d'un même point de section (les faces x+ et x− d'une paroi), et
      `propager_plusieurs` les posait tous puis gardait le premier venu. Une moyenne par point n'en laissait que 1 572
      (deux classes se contredisaient sur leurs sommets d'arête communs). **`Sections.propager_par_groupe`** : les
      sources une par une, de la plus déplacée à la moins, chacune seulement si la propagation des précédentes ne l'a
      pas atteinte — chaque groupe relié reçoit le mouvement de son membre le plus déplacé. Utilisée par TOUS les
      gestes (`_contraindre_et_propager`) : pour un G rigide, c'est la même chose ; ⚠ **L'ÉDITION PROPORTIONNELLE avait
      le même défaut, jamais éprouvé** — elle passe désormais par là aussi.
    - ⚠ **LE COÛT : 91 MS PAR COUP** au premier jet (un bord de paroi atteint 48 tuiles). La portée d'un sommet de bord
      et les gardes d'une face sont mises en cache pour le trait (la topologie ne change pas ; les gardes sont prises
      à la première atteinte, donc sur la forme de départ, comme G) ; les AUTRES tuiles se redessinent au plus dix fois
      par seconde pendant le trait, toutes au relâcher. **Mesuré sans fenêtre : ~10 ms par coup avec un grand pinceau
      sur un bord (+ ~30 ms de redessin des voisines dix fois par seconde), ~2 ms avec un petit loin des bords.**
    - **MESURÉ** : `test_maillage_edite` 180 (+10 ; une grille plate de 5 × 5 et le cube, attendus à la main) ;
      `test_sections` 33 (+3 : 16 sources différentes sur la paroi propagées par groupe, 0 conflit, tous les VRAIS joints
      fermés ; le plus déplacé garde son mouvement ; contrôle : propagées ensemble, des conflits et des joints ouverts) ;
      `fumee_appli` 639 (+12 : de vrais traits à la souris sur une copie de la paroi, par le vrai bouton — des sommets
      bougent, d'autres tuiles suivent, 0 sommet de joint sans partenaire, 0 face repliée, UN Ctrl+Z rend les 52 tuiles,
      Ctrl+Y, un petit trait, Texturing éteint le sculpt). Mutations rouges : Inflate sur la normale visée, Smooth à
      l'envers, Flatten sur le point visé, dureté ignorée, Draw sur la normale des sommets (⚠ d'abord MUETTE sur la
      grille plate : le coin du cube l'a fait rougir), pas de saut par groupe, ordre inversé, le sculpt avec l'ancienne
      propagation. ⚠ **La bride du sculpt n'a pas de garde qui la fasse rougir seule** (aucun trait de la fumée ne
      replie sans elle) ; les gardes de repli et la dichotomie sont celles de G, éprouvées.
    - ⚠ **PAS TENU EN MAIN, NI VU AVEC FENÊTRE** : le ressenti, la force, le cercle.
- **L'EAU DU 3 OCTOBRE 2026 — DEMANDÉE PAR JORDAN ET ÉCRITE** (« il ne doit y avoir qu'un seul océan à un seul niveau
  Y ; des bandes fines de vide là où la découpe se fait ; un mauvais raccord là où l'océan passe une case de gap sous un
  étage flottant ; les cascades ont des bugs de construction »). Vu d'abord à l'image, sur une COPIE de son projet
  (`test.mbproj` : une mer au niveau 13, une autre au niveau 0, une dalle flottante au niveau 14, ~80 rivières).
  - **UN SEUL OCÉAN** : dans `FL.monde`, la première source de mer (dans l'ordre des couches d'eau) l'est, les autres
    sont refusées (`un_seul_ocean` ; la liste des couches d'eau dit « other sea ignored »). Un clic dans le vide
    DÉPLACE la mer (`_poser_la_mer` : les autres sources de mer, toutes couches, partent dans la même action) ; à la
    même hauteur, rien, et l'écran le dit. Un projet d'avant n'est pas migré : la seconde mer est ignorée, pas effacée.
  - **SOUS UN ÉTAGE FLOTTANT** : une case d'eau AU NIVEAU de son eau sous une case pleine porte la nappe
    (`surface_dessinee`, `surface_des_colonnes(…, niveau)`) — la dalle ne se voit qu'à 0,55 au-dessus. Une galerie
    noyée plus bas que le niveau n'en a toujours pas.
  - **LES FENTES** : les rectangles fusionnés (et le large, et les bandes) posaient des JONCTIONS EN T ;
    `_poser_les_plats` insère les sommets voisins sur chaque côté et dessine en éventail autour du centre.
  - **LES CASCADES** : (1) la lame passe 0,3 DEVANT le plan de la falaise (elle était 0,1 derrière, à 0,15 de la roche
    amincie — le relief sculpté de Jordan la perçait de pointes noires à chaque case) ; une LÈVRE plate la relie à la
    bande d'en haut ; élargie de 0,3 au bout sans voisine (les coins saillants se rejoignent) ; (2) deux rivières au
    même endroit ne posent plus deux bandes ni deux lames ; (3) ⚠ **UN FIL SOMBRE LE LONG DU HAUT DE CHAQUE CASCADE,
    DANS LES SIX PRESETS** : le clapot du vertex shader ne soulevait que les nappes — le bord de la lèvre bougeait,
    le haut de la lame non. Il soulève tout (il ne dépend que de x, z).
  - **MESURÉ** : `test_fluides` 202 (+23 ; attendus à la main, et `_sans_jonction_en_t` recalculé sur les triangles) ;
    `fumee_appli` 623 (+4 : la mer déplacée par un vrai clic, « already », Ctrl+Z). **Huit mutations rouges** (pas
    d'éventail, pas de nappe sous un plafond ×2, pas de déduplication, lame derrière la falaise, deux mers acceptées,
    l'ancienne mer gardée, le clapot réservé aux nappes) ; ⚠ « pas de surface dessinée pour un LAC » d'abord MUETTE —
    aucun lac couvert n'était éprouvé : la cuvette a reçu un couvercle. Vu à l'image (les pointes et le fil disparus,
    l'eau continue sous la dalle). ⚠ Pas tenu en main par Jordan.
- **LES CASCADES DU 3 OCTOBRE 2026 — DEMANDÉES PAR JORDAN ET ÉCRITES** (« les waterfalls sont trop carrées, sans
  remous, texture animée moche, sans volume, et pas refermées contre la façade », puis « il manque aussi la source »).
  Vues d'abord à l'image (`DEV_TOOLS/capture_cascades.gd`, avec fenêtre : une falaise de sept cases, un chenal de trois,
  un bassin au pied, une rivière d'une case, la mer) : une lame plate posée 0,3 devant la falaise, sans côtés, des
  taches floues étirées, rien au pied.
  - **LA NAPPE COURBE** (`eau_maillage.gd`, `_poser_les_lames`) : elle part du plan de la falaise au bout de la bande,
    se courbe vers l'avant (`LAME` 0,35 × √(chute / 0,7)), puis tombe en s'évasant un peu ; ses rangées sont fines en
    haut. **À UN BOUT SANS VOISINE, ELLE S'ARRONDIT ET RENTRE DANS LA ROCHE** (0,4 derrière le plan, la falaise amincie
    est à 0,25) : de profil, plus de jour entre l'eau et la paroi. Deux cascades voisines sur un plan se rejoignent à
    plat. Normales par sommet (le volume se lit à la lumière).
  - **LE REMOUS** (genre **0,75**, un nouveau genre) : un anneau d'écume à plat sur l'eau où elle tombe, qui fait le tour
    des bouts arrondis, et des embruns qui montent de 0,9 devant le pied (effacés sur les bouts : ils y faisaient deux
    ailerons). Transparents, posés EN DERNIER dans le maillage, ÉCARTÉS sous un seuil d'alpha (sinon leur profondeur
    trouait la nappe dessinée après). ⚠ **TOMBÉE DANS UN CREUX QU'ELLE REMPLIT, LA CHUTE FINIT AU FOND** : le remous y
    était sous la nappe, invisible (vu à l'image) — il se pose sur la nappe de l'eau dormante qui noie son pied.
  - **LA SOURCE** : la première case d'une rivière qui coule sur la matière porte un disque d'écume bombé (0,7 de
    rayon) et un petit voile — l'eau ne sort plus de nulle part. Pas de source pour une rivière née d'un lac.
  - **LE MOTIF** (`EauPresets.CASCADE`, `motif_cascade`, dans les six presets) : trois couches de filets de plus en plus
    fins et rapides, une eau lisse sur la lèvre (là où la normale regarde en haut), l'écume (COLOR.a) qui bouillonne et
    monte au pied. Le stylisé (non éclairé) peint un modelé ; le marais tombe en eau boueuse (noire avant).
  - **LE CONTRAT CHANGE** (`FormatMonde.regle_eau`) : genre 0,75 = l'écume ; sur une cascade et sur l'écume, COLOR_0 a
    est la quantité d'écume, plus une profondeur ; NORMAL porte la forme. Dans la liste des greffons à faire.
  - ⚠ **DEUX DÉFAUTS TROUVÉS PAR LES TESTS** : le haut de la nappe posait des jonctions en T sur le bout de la bande
    (ses sommets y sont insérés, en multiples de 0,05 — `_poser_les_plats` accepte des points seuls) ; et le centre du
    disque de source n'était employé par aucun triangle — l'export glTF l'ôtait (`_sans_orphelins`).
  - **MESURÉ** : `test_fluides` 244 (l'escalier : la nappe part du plan, 0,35 devant à 0,7 de chute, ses bouts à 0,4
    dans la roche, l'écume de (1 − 1/1,3)² en haut à 1 au pied, l'anneau à plat sur la bande de la marche, les embruns,
    la source ; le bassin : l'anneau sur sa nappe à 1,72 ; le texte des six presets — attendus à la main). **Neuf
    mutations rouges** (bouts hors de la roche, lame droite, pas de remous, remous au fond du bassin, pas de source,
    jonctions en T, orphelins, écume plate, remous non écarté). `fumee_appli` 690 / 692 (les deux échecs : l'exemple
    et ses contacts diagonaux, connus), `test_greffon_peinture` 255, `test_projet` 96. Vu à l'image, six presets, RTX
    2060 Vulkan.
  - ⚠ **PAS TENU EN MAIN, NI JUGÉ PAR JORDAN** ; ni vu sur de l'art sculpté (une falaise qui déborde de plus de 0,4
    percerait les bouts) ; une cascade qui tombe à un coin saillant n'a pas été regardée.
- **TROIS PRESETS DE FLUIDES DE PLUS — DEMANDÉ PAR JORDAN (2 octobre 2026)**, transmis par une autre session :
  **lave**, **eau de marais**, **acide luminescent**. Ce sont des presets de couche d'eau, à côté des trois qui
  existent (`eau_presets.gd`) : ça répond au « d'autres liquides (lave, marécage) comme simples presets » laissé
  OUVERT ci-dessus. ⚠ Ils entrent dans **LA LISTE DES GREFFONS À FAIRE** (§0), comme les trois premiers : chacun
  réécrit dans chaque moteur, sur le même contrat COLOR_0.
  - **ÉCRITS (2 octobre 2026)** — `eau_presets.gd`, choisis par couche d'eau dans « Look » comme les trois autres,
    sur le même contrat COLOR_0 (courant, genre, profondeur) et le même `COMMUN` :
    - **« lave »** (Lava) : une CROÛTE sombre fendue en cellules (Voronoi, `bord_de_cellule`) dont les fentes
      luisent en ÉMISSION, plus chaudes où c'est profond, qui dérivent avec le courant ; une cascade est une coulée
      incandescente ;
    - **« marais »** (Swamp water) : une eau trouble lue dans la texture d'écran, très absorbante, des plaques de
      lentilles d'eau qui dérivent, des bulles RONDES (`bulle_ronde`), une cascade boueuse ;
    - **« acide »** (Glowing acid) : un vert lumineux en ÉMISSION, des crêtes plus claires, des bulles, une écume de
      rive ; ⚠ la cascade garde son vert (stries à 0,45) — à 0,9 d'écume elle n'était qu'un aplat jaune (vu à l'image).
    - le `.mbworld` les écrit sous leurs aspects anglais (`FormatMonde.ASPECTS`, `regle_eau()` les nomme) ; le manuel
      (F1) les décrit.
  - **PROPOSÉ (points ouverts tranchés par défaut)** : au Play test, la lave et l'acide se NAGENT comme l'eau — pas
    de dégâts, pas de mort (un outil de jugement, pas un jeu) ; l'acide et la lave LUISENT (émission) sans poser de
    vraie lumière qui éclaire le décor (une lumière par case d'eau coûterait cher et ne voyagerait pas dans les
    greffons) ; sous la surface, le VOILE est celui du liquide (`EauPresets.VOILES` : lave orange presque opaque,
    marais brun-vert, acide vert ; l'eau garde le sien). Pour le voile, chaque case d'eau donnée au jeu porte le
    preset de sa couche, et la case traversée se trouve par la MÊME règle que la surface
    (`EauMaillage.case_d_eau_au_point`, sortie de `niveau_au_point`).
  - **MESURÉ** : `test_fluides` 148 (six liquides, leurs aspects exportés écrits à la main, émission de la lave et de
    l'acide, un voile chacun) ; `fumee_appli` (la liste « Look » porte les six noms ; plongé dans un lac de LAVE, le
    voile est orange). Vu à l'image avec fenêtre (`DEV_TOOLS/capture_meteo.gd`) : lave sur le plateau, acide en
    rivière et cascades, mer de marais ; aucune ligne « SHADER ERROR ».
    Cinq mutations rouges : la lave qui rend le shader stylisé, la lave sans nom anglais, pas de voile pour le marais,
    le voile toujours celui de l'eau, les cases données au jeu sans leur preset.
  - ⚠ **PAS JUGÉ PAR JORDAN** : les couleurs, la taille des cellules de lave, l'opacité du marais ; le voile n'a été
    vu qu'en chiffres (la fumée), pas à l'image.

### L'ATELIER TRANSITIONS — DÉCIDÉ (Jordan, 6 octobre 2026 : « go pour l'atelier transitions »), ÉCRIT LE MÊME JOUR

Discuté d'abord (§3, « les bords partagés entre couches », la suite proposée) : Jordan voulait un atelier qui reprenne les
paires de couches, leurs matériaux, et choisisse en temps constant l'aspect de la frontière quand les transitions sont
activées ; puis « un désert qui empiète sur la roche n'est pas la même chose qu'une roche qui empiète sur le désert ».

- **CE QUI EST DÉCIDÉ, ET POURQUOI** :
  - **pas de tuiles de transition sculptées** : deux couches dans un sommet font 6 050 configurations, au moins 1 513
    classes sous les quarts de tour. La transition porte sur l'ASPECT ; la géométrie reste celle de la couche qui pose
    le sommet (les couches exclusives, inchangées) ;
  - **une paire non ordonnée, DEUX réglages** (quand A couvre B, quand B couvre A) : Softness, Reach, Irregularity,
    Grain, Fills hollows (`Transitions.REGLAGES`, défauts et bornes **PROPOSÉS**) ;
  - **qui couvre** : la couche la plus haute de la liste par défaut, sauf là où le PINCEAU l'a choisi, sommet par sommet ;
  - **un matériau représentant par couche** (PROPOSÉ : par couche, pas par paire — c'est lui qui se mêle à la surface de
    l'autre) : par défaut le plus porté par les faces de son témoin, sinon la teinte du dessus de la légende ; projeté
    en boîte (un UV déplié ne se transporte pas sur une autre géométrie) ;
  - **rien n'est dessiné tant qu'aucune paire n'est allumée** : le passage n'est même pas posé.
- **LA RÈGLE, EN TEMPS CONSTANT AU FRAGMENT** (`addons/marchingblocks_core/transitions.gd`, `melange` en GDScript pour les
  tests, `SHADER` qui la dit à la lettre) : le shader est posé en `next_pass` sur chaque matériau des tuiles posées
  (`app/transitions.gd`, `_brancher`, relu deux fois par seconde), il lit les HUIT cases de la tuile dans une texture 3D
  (`transitions_rendu.gd` : un octet par case — rang + 1 en quatre bits, rang choisi au coin en quatre bits ; une
  tranche par z ; seules les tranches touchées sont refaites). La propriétaire est le plus petit rang des huit — le
  passage n'a rien à savoir de sa couche, un matériau partagé par deux couches marche ;
  - la part de l'autre couche : interpolation trilinéaire de ses cases (cases vides ignorées) ;
  - ⚠ **LE CHOIX EST UN CHAMP AUSSI** : lu au seul sommet, deux tuiles voisines liraient deux sommets et la couvrante
    changerait d'un coup au joint. Chaque coin vote (son poids) pour la couche choisie, sinon la prioritaire ;
  - décalage = (avance + creux·(½ − hauteur de la couverte) + bruit·(n − ½))·4·s·(1 − s) — **nul aux deux bouts** ;
  - ⚠ **LE SOMMET EST CELUI DE LA TUILE, LU DANS `vertex()`** : déduit du point, il basculait dans la maille de la voisine
    sur un joint ; et dans `fragment()`, la `MODEL_MATRIX` d'une MultiMesh (le GridMap) n'a pas la pose de l'instance
    (vu : plus aucun fondu).
- **L'ATELIER** (le septième, teinte citron **PROPOSÉE**) : la liste des couches (son ordre dit qui couvre), PAIRS OF
  LAYERS (une case pour allumer), les deux réglages de la paire choisie, REPRESENTATIVE MATERIALS, BRUSH (« … covers » /
  By priority, Radius et Alt + molette, clic gauche glissé, clic droit = la priorité ; une teinte jaune montre les
  endroits peints, dans cet atelier seulement). Échap ramène à World. Chaque geste est UNE annulation ; tout est dans le
  `.mbproj` (`transitions` : paires, représentants, choix à plat par quatre — absent s'il est vide ; abîmé, le fichier
  est refusé). Le manuel (F1) a sa page.
- ⚠ **CE QUE L'ŒIL VERRA** : sur la surface de la couche PROPRIÉTAIRE d'une tuile mixte, c'est son matériau NATIF qui
  est dessous, et le représentant de l'AUTRE qui se pose dessus. Un représentant qui ne ressemble pas à ce que sa couche
  montre fait un liseré au bout de la bande. Et sans transition, la frontière visible est à une demi-case dans la couche
  de plus grand rang (les tuiles mixtes appartiennent à la prioritaire) — c'était déjà le cas.
- **MESURÉ** : `test_transitions` 61 (poids à la main ; la règle — une couche seule, une paire éteinte ou décrite à moitié,
  la propriétaire, ½ au milieu, l'avance, le pinceau, un choix d'une troisième couche, rien aux bouts même réglages au
  maximum, le creux, les cases vides ; **la continuité jugée par son effet** : 60 mondes au hasard, en des points des
  faces communes à deux tuiles, chaque couche a la même part des deux côtés ; la table ; la texture relue à la main ; le
  texte du shader) ; `test_projet` (+8, l'aller-retour et deux refus) ; `fumee_appli` (+31 et une SENTINELLE : l'atelier,
  sa barre, la ligne de la paire, cochée → chaque matériau des tuiles porte le passage, Ctrl+Z l'éteint et le retire,
  une case posée ensuite entre dans la texture, le pinceau seulement à la frontière, dans la texture, UN Ctrl+Z, le clic
  droit, un curseur → la table du shader, le projet relu, Échap).
- **MUTATIONS, ROUGES** (rejouées dans une copie à dossier de données isolé) : le cœur 5 — les votes du pinceau ignorés, le
  décalage sans 4·s·(1 − s) (128 écarts aux joints), la propriétaire au plus grand rang, les choix non écrits dans la
  texture, la table transposée ; l'écran 7 — le passage jamais posé, les cases qui ne suivent pas, le pinceau partout,
  l'annulation qui oublie la texture, le passage jamais retiré, le projet sans transitions, Échap ignorée. ⚠ **DEUX
  D'ABORD MUETTES, PAR LE TEST** : la table transposée (les deux directions avaient les mêmes réglages) et « jamais retiré »
  (la fumée comptait la liste de l'atelier, pas le `next_pass` des matériaux). ⚠ **UNE ÉQUIVALENTE, GARDÉE** : exiger les
  deux directions dans la table — sans elle, une table à moitié écrite (que `table()` ne produit jamais) fait planter la
  règle, qui rend {} — le même résultat, avec une erreur dans la console. ⚠ Et `test_transitions` concluait « OK » sur un
  cœur qui ne compilait pas (une classe interne ne voit pas les fonctions statiques de son fichier) : il exige d'abord
  que ses trois scripts se chargent, et que ses six sections aillent au bout.
- **VU À L'IMAGE** (`DEV_TOOLS/capture_transitions.gd`, avec fenêtre, RTX 2060 Vulkan ; le témoin de B habillé d'un damier
  bleu) : un fondu doux, continu d'une tuile à l'autre, qui suit les marches ; Reach le déplace ; peint « B couvre », le
  bleu s'avance sur A et la teinte jaune le montre ; dans World la transition reste, la teinte s'en va. ⚠ **DE FINS
  POINTILLÉS CLAIRS À CERTAINS JOINTS DE LA BANDE, PAS EXPLIQUÉS** (ni la poussée le long de la normale, ni le sommet lu au
  point : essayés). ⚠ Une fausse piste notée dans le code : on a cru la carte aveugle au canal G d'une texture RG8 — la
  capture peignait des sommets enfouis.
- **LE REPRÉSENTANT PAR DÉFAUT EST LE DESSUS — CORRIGÉ (13 octobre 2026)**, vu par Jordan sur `fonction_transitions.gif`
  (`D:/SpannerGames/PROJETS/MarchingBlocks/04_exports/reddit/gif/`) : « les transitions sont parfois visibles sur le bord
  droit de la ligne de démarcation ». Ce n'était PAS le filmage : une bande brune, nette du côté de la couche native —
  le représentant par défaut, « le plus porté par les faces du témoin », était la FALAISE (Material 2) des trois couches
  de l'exemple (relevé par `filmer_transitions_v2.gd -- --seulement=materiaux`) ; le tournage le corrigeait à la main.
  Désormais (`representant_par_defaut`) : l'AIRE des faces tournées vers le haut × les occurrences de leur tuile ; sans
  dessus, l'ancienne règle. Sur l'exemple : Material 1 (le dessus) pour les trois. Gardé par `test_transitions` (70, un
  faux témoin écrit à la main) ; deux mutations rouges (l'ancienne règle, les occurrences ignorées). ⚠ Les GIF sont à
  REFILMER. ⚠ **LES POINTILLÉS CLAIRS** le long de la bande (visibles aussi sur le GIF) restent NON EXPLIQUÉS.
- ⚠ **PAS TENU EN MAIN, PAS JUGÉ PAR JORDAN.** Pas mesuré sur l'exemple (la texture fait ~10 Mo, sa construction parcourt
  l'union : ~740 000 cases). Pas exporté : dans la liste des greffons à faire (§0).

### LA BARRE DE PROGRESSION, LA BARRE DE RENDU DU PLAY TEST, UNE PASSE D'OPTIMISATION — DEMANDÉES ET ÉCRITES (Jordan, 1er octobre 2026)

**La barre de progression** (« dans tout processus qui dépasse 0,4 s ») — `editor.gd` :
- une PILE d'attentes (un tranchage pendant l'ouverture d'un projet) ; une barre À ÉTAPES qui avance entre deux étapes
  (l'écran est repeint), ou qui DÉFILE pour un travail d'un seul tenant fait sur un autre fil (`_en_fond`,
  WorkerThreadPool). ⚠ Sur le fil principal, un travail d'un seul tenant gèle tout, barre comprise.
- **le tranchage passe sur un autre fil** : mesuré avec fenêtre, l'écran reste à 25 images/s pendant tout le tranchage,
  52 tuiles, aucune erreur de fil (`DEV_TOOLS/capture_progres.gd`). ⚠ Le fil coûte ~40 % de plus (les appels au
  RenderingServer s'y sérialisent) : choisi pour un écran vivant.
- à étapes : l'ouverture d'un projet (une couche par étape), le monde qui suit son témoin avant World, le Play test
  et les exports (`_rhabiller_avec_attente`) ; l'entrée dans le modeleur (~2 s) ; le départ du Play test et l'eau
  s'il ont dépassé 0,4 s la dernière fois (`_durees`). ⚠ **`_aller_a` ET `_regler_edition` RESTENT SYNCHRONES** :
  appelées d'endroits qui enchaînent juste après ; la barre passe par des enveloppes réservées aux gestes
  (`_changer_d_atelier`, `_basculer_edition`). ⚠ **SANS FENÊTRE, `frame_post_draw` NE VIENT JAMAIS** : `_attendre`
  ne l'attend plus en headless (la fumée pendait sur tout ce qui attendait).
- ⚠ Avec le seul thème, la barre défilante n'était qu'un trait de quelques pixels (vu à l'image) : piste et
  remplissage explicites.

**La barre de rendu du Play test** — `Vue.REGLAGES_RENDU` (une liste, l'écran la montre) : soleil (direction,
hauteur, force, couleur, ombres), ambiante, les trois couleurs du ciel, SSAO, SSIL, SDFGI, SSR, halo, brouillard,
brouillard volumique, tone mapping, exposition, luminosité, contraste, saturation, et Reset. ⚠ Les défauts SONT les
constantes déjà décidées ; les réglages ne valent qu'au Play test — en le quittant, `_rendre_le_travail` rend
l'éclairage du travail. ⚠ Le voile sous l'eau l'emporte sur le brouillard choisi, et le rend en remontant (un seul
endroit décide du brouillard). Le SDFGI, écarté du travail, est proposé ici (rien ne change pendant qu'on joue).
Gardé par `fumee_appli` (411) ; trois mutations rouges. Vu à l'image.

**La passe d'optimisation** (un audit en lecture seule, puis des mesures) :
- ⚠ **AVEC UNE CARTE GRAPHIQUE, TRANCHER LE TÉMOIN COÛTAIT 16,9 s, CONTRE 1,8 s SANS FENÊTRE — MESURÉ** : la découpe
  relisait le bloc ENTIER depuis le GPU une fois par clé, et chaque pièce une fois par face. **La mémoire des
  relectures** (`Decoupe.tableaux`, active le temps d'un `Tranchage.trancher`) et **les deux poses composées en une**
  (une permutation de signes : exacte) : **7,8 s**. Sortie identique au bit près : `test_blocs_maitres` 1 468,
  `test_tranchage`, `test_decoupe`, `test_faux_artiste`, `test_temoin_lie`, `test_massif_peint` verts. ⚠ On mémorise CE
  QUE LA RELECTURE REND (couleurs 8 bits, normales compressées), pas l'envoi : sinon la sortie changerait. ⚠ Le
  conteneur rendu est une COPIE — la garde de `test_blocs_maitres` était muette (rien ne relit un maillage déjà posé)
  ; `test_decoupe` construit le cas (poser deux fois : 10..12 au lieu de 5..7 sans la copie, vu rougir).
- **l'eau** : sans source, plus aucun recalcul ; pendant un coup de pinceau, en direct si le calcul est rapide
  (< 50 ms), à la fin du coup sinon ; `_eau_sous` par un index ; le Play test ne recalcule l'eau que périmée.
- **LES RELECTURES GPU SOUS UN RENDU QUI OCCUPE LA CARTE — MESURÉ ET CORRIGÉ (2 octobre 2026)** (Jordan : « opti »).
  - ⚠ **UNE MESURE A MENTI, ET C'EST LA LEÇON** : trancher le témoin prenait 7,8 s avec fenêtre ; une réorganisation
    (toutes les découpes, puis toutes les poses) l'a fait tomber à 1,7 s… puis l'ANCIEN code aussi, à 1,6 s. La
    différence n'était pas le code mais la CHARGE de la carte : l'appli de Jordan tournait pendant la première mesure
    (il testait). Reproduite exprès — l'exe ouvert sur l'exemple à côté —, les deux versions font 7,8 s :
    l'ordre n'y était pour rien, il a été retiré. **Ce que l'appli vit vraiment, c'est ce cas-là** : elle tranche
    pendant qu'elle dessine.
  - **LA CAUSE** : sous charge, chaque RELECTURE d'un maillage (le redescendre du GPU) attend la carte. **LE
    REMÈDE** (`Decoupe._retenir`) : pendant un tranchage, ce que la découpe FABRIQUE est retenu tel qu'envoyé ; la
    pose, les contrôles le relisent en mémoire. Seul le maillage d'entrée est relu de la carte. **Sous charge, en
    alternance : 7,7 et 7,9 s → 1,6 s. Empreinte du lot (positions, normales, UV, couleurs, indices) identique au
    bit près** (`ba0f50c8…`) — la crainte de la mémoire du 1er octobre (« garder l'envoi changerait la sortie ») ne
    s'est pas vérifiée ici. Gardé par `test_decoupe` (22 : découper, poser, mesurer ne coûte qu'UNE relecture réelle,
    `relectures_gpu`) ; mutation rouge (3 relectures).
  - **LA RELECTURE D'UN TÉMOIN LIÉ** (à chaque passage dans World, à chaque Ctrl+S) : 2,2 s sous charge, dont 2,0 s
    dans `verifier_couture_texture` — `get_image()` redescendait l'image de la carte pour CHAQUE surface de chaque
    tuile. Une image par texture, et les tableaux que la relecture liée a déjà (`tableaux_de`) : **0,3 à 0,46 s,
    remarques et lot identiques**. ⚠ Pas de garde dédiée (le compte d'images lues n'est pas exposé) : les suites
    vertes et la comparaison de sortie.
- **RESTE DE L'AUDIT, À MESURER AVANT D'Y TOUCHER** (impact estimé, rien de mesuré) : la découpe entière sur des
  tableaux (le reste des 7,8 s : un envoi + une relecture par pièce et par face de couture) ; la règle de pose
  (`sous_le_ciel` qui rebalaye chaque colonne, un dictionnaire alloué par sommet dans `classer`) ; « Slice this
  layer's witness » et l'import lié qui relisent deux fois ; les 52 vignettes refaites à chaque enregistrement du
  témoin ; les aperçus au survol (occupation rebâtie, MultiMesh rempli instance par instance) ; `FL.boite` recalculée
  à chaque appel ; le décor du Play test rebâti à chaque entrée ; le MD5 du `.glb` à chaque rafraîchissement des
  couches (⚠ pas de cache par date : la charte l'a déjà écarté, la date n'est précise qu'à la seconde).
  ⚠ `FL.boite` et le MD5 de la liste : FAITS le 4 octobre 2026 (ci-dessous).
- **LA PASSE D'OPTIMISATION DU 4 OCTOBRE 2026 — DEMANDÉE PAR JORDAN (« go pour les optimisations »), MESURÉE D'ABORD.**
  Sur l'EXEMPLE (277 709 cases, 3 couches, 3 couches d'eau, 106 sources), sur le PC (RTX 2060, avec fenêtre, l'appli de
  Jordan FERMÉE — la charte a déjà payé une mesure faussée par elle) : `sonde_lags_edition.gd`, puis `sonde_saccade.gd`
  (chaque image horodatée après un geste) pour trouver la cause, puis des bancs headless (`banc_eau_maillage.gd`,
  `banc_couches.gd`, `banc_temoin_suit.gd`, l'archive de l'exemple copiée dans `exemple/`).
  - **UNE SACCADE D'UNE SECONDE APRÈS CHAQUE GESTE (poser, Ctrl+Z, pinceau, boîte) : ~1 050 → ~40 ms.** Ce n'était PAS
    l'enregistrement (7 ms sur le fil principal) mais le recalcul de l'eau, différé à l'image suivante :
    - ⚠ **7 SOURCES EN ERREUR** (une seconde mer, des rivières refusées) : `FL.monde` ne reprend jamais un corps en
      erreur, il le refait à chaque geste — donc il n'est jamais « le même objet », et l'écran REMAILLAIT les trois
      couches d'eau à chaque geste (880 ms pour celle aux 100 rivières). Deux corps en erreur se valent
      (`_meme_corps_dessine` : ils ne dessinent rien). Gardé par `fumee_appli` (une source dans la roche, une case loin
      du lac : la nappe n'est pas remaillée) ; mutation rouge ;
    - **la nappe d'un corps repris est gardée** (`EauMaillage.maillage(…, memoire)`, une mémoire par couche d'eau) :
      elle ne lit que des cases de son emprise, et un corps n'est repris que si rien n'y a changé. La nappe de l'océan
      coûtait ~0,6 s à chaque remaillage. Gardé par `test_fluides` (150 gestes au hasard : maillage avec mémoire =
      maillage complet, au bit près) ; mutation rouge (144 maillages faux) ;
    - **la boîte du monde n'est plus rebalayée** (~70 ms par appel, une fois par `FL.monde` et une par couche d'eau) :
      `FL.monde(…, boite_)` et `EauMaillage.maillage(…, boite)` la reçoivent, et l'écran la TIENT geste par geste
      (`_tenir_occ_eau` : une case posée l'élargit, une case retirée au bord la fait refaire). Gardé par `fumee_appli`
      (attendu : `FL.boite` recalculée) ; mutation rouge.
  - **LA LISTE DES COUCHES, après chaque geste : ~114 ms de moins** — elle relisait le MD5 de chaque `.glb` (24 Mo).
    `_empreinte_pour_la_liste` le garde tant que date et taille ne bougent pas, et toute écriture du `.glb` par l'appli
    (`_rhabiller`, l'export du témoin) le vide. ⚠ Pour l'ÉTIQUETTE seulement : le cache de tranchage garde le MD5
    complet. Gardé par `fumee_appli`. Activer une couche : ~125 → ~17 ms.
  - **CACHER / MONTRER UNE COUCHE : 7,3 → 2,0 s.** Les autres couches se refaisaient en ENTIER (52 407 cases changées,
    seuil fixe de 4 096). `reconstruire_autour` énumère chaque colonne UNE fois (avant : la colonne entière par case,
    des millions de doublons) et prend la route locale tant qu'elle a moins de sommets à refaire que l'état n'en
    compte. Gardé par `test_massif_peint` (une roche de 25 600 cases sous une herbe de 4 900 : route locale prise,
    rend la complète, cachée puis remontrée) ; deux mutations rouges (le seuil fixe, la colonne prise à la dernière case
    au lieu de la plus haute).
  - **LE MONDE QUI SUIT SON TÉMOIN (passer de Geometry à World après une retouche) : `_suivre_son_temoin` 7,1 → 2,0 s.**
    Poser le lot reconstruisait toute la couche (196 091 cases). Un lot aux MÊMES NOMS sous les MÊMES NUMÉROS ne
    change aucune décision (la règle ne lit que l'index) : `MassifPeint.lot` ne change alors que le lot de la grille.
    Gardé par `test_massif_peint` (pas de reconstruction, la grille porte le lot, le monde = une reconstruction
    complète ; un lot qui a perdu une tuile reconstruit) ; mutation rouge.
  - **OUVRIR L'EXEMPLE : 16,6 → 8,9 s** (les mêmes causes, puis deux de plus) :
    - **l'ouverture reconstruisait chaque couche DEUX FOIS** : seule, en recevant son lot (`_habiller_couche`), puis sur
      l'union (`_refaire_l_union`). Pendant `_ouverture`, le lot est posé sans reconstruire
      (`MassifPeint.reconstruire_au_lot`), et une couche sans source n'est plus reconstruite seule ;
    - **LA RÈGLE DE POSE REMONTAIT LES COLONNES** : `MB.sous_le_ciel` coûtait 65 % de la décision d'un sommet (4,1 s sur
      6,3, en local, sur les 263 026 sommets de la grande couche). `MB.hauts_des_colonnes` (la plus haute case de chaque
      colonne, bâtie UNE fois par reconstruction entière, par `MB.poses` et par une grande reconstruction locale) : « une
      case pleine de y + 2 au plafond » ⇔ « la plus haute est à y + 2 ou plus ». Et `classer`, le nom d'air libre et le
      compte des variantes sont gardés (256 configurations ; le compte ne dépend que du lot). Une reconstruction
      complète : ×4 à ×5. ⚠ **MÊME SORTIE, BIT POUR BIT** : `test_marching_blocks` §18 (30 mondes au hasard, chaque
      sommet, les deux réponses exercées — mutation rouge : 2 412 écarts), et `test_greffon_peinture` recalcule les cas
      d'épreuve des greffons avec `MB.poses` : inchangés. Les greffons gardent l'ancienne façon (même sortie) : une
      optimisation à porter avec eux.
  - Sur le PC, au bout de la passe : un geste ~40 ms, cacher / montrer une couche ~1,6 s, ouvrir l'exemple ~8,9 s.
  - **PUIS L'OUVERTURE ENCORE (Jordan : « go pour les trois ») : 6,6 s (9,1 s la première fois), et l'eau juste après
    4,4 → 3,3 s.**
    - **les vignettes de la liste des couches sont gardées sur disque** (`user://cache/vignettes/<MD5 du .mbtiles>.png`,
      capturées une image après leur rendu, avec fenêtre seulement) : un témoin pas encore chargé, déjà photographié
      tel quel, se montre sans être chargé (~1,2 s : les trois témoins de l'exemple étaient chargés pour 84 × 56 pixels).
      Un témoin modifié et pas encore écrit n'est pas gardé. Gardé par `fumee_appli` (une image posée à la main sous
      l'empreinte d'un `.mbtiles` factice) ; mutation rouge ;
    - **le verdict « à jour » de `_ensembles_en_retard` est gardé** (`user://cache/ensembles_a_jour.cfg`), sous une clé
      de ce qui pourrait le faire changer : l'empreinte du lot posé, celle du `.mbtiles`, les cartes trouvées à côté de
      chaque image (chemins et dates) — ~1,4 s à chaque ouverture pour une migration faite une fois. Gardé par
      `fumee_appli` (clé stable, verdict écrit sous elle — l'entrée effacée d'abord : celle d'un passage précédent
      passait pour neuve, vu en mutation —, un autre lot change la clé) ; mutation rouge ;
    - **l'eau de mer n'est plus recopiée** : la mer de l'exemple fait **2 376 713 cases** (le niveau 13 dans une boîte
      de 465 × 358) ; `FL.monde` en recopiait l'eau dans un second dictionnaire pour les rivières (~2,8 s en local à
      chaque calcul complet). Il n'y a qu'un océan : son eau EST l'eau de mer, partagée (personne ne la modifie). Gardé
      par `test_fluides` (`is_same`) ; mutation rouge.
    - **ENTRER DANS LE PLAY TEST : 22 → 1,5 s, à CHAQUE entrée** (`DEV_TOOLS/sonde_ateliers.gd`, sur le PC). Le décor
      foulé était UNE forme de collision portant les triangles de toutes les tuiles posées : 7,9 millions sur
      l'exemple ; la construire coûtait 16 s en local, les rassembler 0,9 s. Il est désormais EN MORCEAUX de 8 × 8
      colonnes (`Vue.MORCEAU_DECOR`), bâtis autour du personnage : 3 × 3 à l'entrée (il doit se poser), puis, à chaque
      image, ceux qui manquent à moins de 3 morceaux, les plus proches d'abord, dans 6 ms (au moins un par image). Les
      triangles sont les mêmes : il foule toujours ce qu'on voit. Les images qui suivent l'entrée : < 40 ms. Gardé par
      `fumee_appli` (un îlot lointain : son morceau n'est pas bâti à l'entrée ; porté dessus, il s'y pose à 10,75) ;
      mutation rouge (sans la construction au fil du jeu, il tombe à travers, y = −13). Les autres ateliers : ~30 ms.
    - ⚠ **CE QUI RESTE** : l'océan lui-même (~3 s en local) inscrit ses 2,4 millions de cases une à une dans un
      dictionnaire. Le représenter par ses tronçons de colonne changerait la règle de l'eau — celle que les trois
      greffons réécriront : à décider avec eux.
  - **CE QUI RESTE, MESURÉ, PAS FAIT** : ~~`vers_glb` ~3,5 s sur le PC quand le monde suit son témoin (l'encodage des
    textures en PNG, ~2,5 s en local — changer de format changerait le fichier)~~ — FAIT le soir, même fichier (ci-dessous) ; Ctrl+S ~2,3 s (il marque d'office le
    témoin en édition comme modifié et le réécrit : une ceinture de sécurité, GARDÉE) ; ~~cacher une couche ~2 s (la
    décision de 192 041 sommets par couche, dans la règle de pose — la référence des greffons)~~ — FAIT le soir, sans
    toucher à la règle (ci-dessous) ; à l'ouverture, les
    vignettes, la vérification des ensembles PBR et la recopie de la mer — FAITS ensuite (ci-dessous).
  - ⚠ **UN TEST INSTABLE, VU EN PASSANT** : `fumee_appli`, « Espace lâchée, il s'arrête vite et PLANE » a échoué une fois
    sur quatre (0,52 case de dérive pour un seuil de 0,5 : le pas de la physique suit la charge de la machine).
  - **LA SUITE DE LA PASSE (4 octobre 2026, le soir, sur le PC, une session seule)** — les trois points « mesurés, pas
    faits », dans l'ordre, chacun mesuré avant d'y toucher :
    - **1. LES GESTES DE L'EAU SUR L'EXEMPLE : ~470 → 65 à 95 ms la pire image** (`sonde_eau_exemple.gd`, avec fenêtre :
      poser une rivière, Ctrl+Z, Ctrl+Y, la retirer). MESURÉ d'abord (`DEV_TOOLS/banc_eau_rivieres.gd`, headless) : le
      remaillage de la couche d'eau 0 (l'océan et 93 rivières) coûtait ~450 ms, dont **~320 ms à calculer ses 469
      cascades** (point et normale par différences, en GDScript), ~120 ms à POSER des grilles (cascades, remous, sources)
      sommet par sommet, ~20 ms à retirer les orphelins sur tout le maillage.
      - **`memoire["lames"]`** : une cascade ne dépend que de ses champs une fois ses voisines connues (axe, sens, plan,
        place, haut, pied, sol, sens du courant, ses deux bouts libres) ; sous la même clé, les mêmes grilles. Seules
        celles de l'appel courant restent. **`memoire["sources"]`** : les grilles d'une source, par case ;
      - **les grilles sont COMPILÉES une fois** (`_grille_compilee` : tableaux tassés, indices depuis 0, ses orphelins
        déjà retirés) et posées par `append_array` (`_poser`). ⚠ **`_sans_orphelins` (le ménage du maillage entier) EST
        RETIRÉ** : seules les grilles laissent des orphelins (`_quad` et l'éventail des plats emploient tous leurs
        sommets), et une grille ne référence que ses sommets — le ménage par grille rend le même maillage ;
      - **MESURÉ : 450 → 57 ms headless ; le maillage de l'exemple, couche par couche, IDENTIQUE au bit près à celui du
        code d'avant** (relu par une comparaison faite une fois avec l'ancien `eau_maillage.gd`, avec et sans mémoire) ;
      - gardé par `test_fluides` 252 (`_memoire_des_cascades` : huit sources au bord d'un plateau dont les cascades sont
        voisines sur un même plan, un bassin au pied dont le rebord monte d'une rangée, 60 gestes au hasard — le maillage
        avec mémoire = sans mémoire, la mémoire a servi, les bouts libres ont changé (déduits des SOURCES, pas de la
        clé), aucun sommet sans triangle compté sur les indices). **Sept mutations rouges** (clé sans les bouts libres,
        avec un seul, sans le sol, sans le pied, orphelins gardés, source reprise sans regarder sa case, indices non
        décalés). ⚠ **« SANS LE SOL » D'ABORD MUETTE, PAR LE TEST** : le niveau d'eau au pied ne changeait jamais sans
        changer le pied — il a fallu le bassin dont le rebord monte. ⚠ **ET DEUX D'ABORD FAUSSEMENT ROUGES** : le test
        lisait la disposition de la clé (`cle[8]`) ; une clé raccourcie le faisait planter, pas mentir.
      - ⚠ **UN DÉFAUT DU TEST, TROUVÉ EN ÉCRIVANT** : `_reprise` parcourait toutes les clés de la mémoire ; avec « lames »
        elle s'arrêtait sur une erreur d'exécution — **en silence, la suite finissait « 0 échec »** (§6). Une SENTINELLE
        exige désormais que `_reprise` et `_memoire_des_cascades` aillent au bout.
      - Ce qui reste du geste (~60 ms) : les plats (~40 ms, 1 522 rectangles), les bandes, le calcul des corps.
    - **2. ÉCRIRE LE .glb DU TÉMOIN (le monde qui suit son témoin) : 3,3 s → 0,46 s** (`sonde_lags_appli.gd -- --exemple`,
      avec fenêtre). MESURÉ d'abord : les maillages 24 ms, `append_from_scene` 47 ms, **`write_to_filesystem` 3,2 s** —
      l'encodage PNG de sept textures (1k et 2k) qu'une retouche de géométrie ne change pas.
      - **`addons/marchingblocks_core/png_en_memoire.gd`** : une `GLTFDocumentExtension`, un format d'image à nous
        (`MB_PNG`) qui fait ce que fait le PNG de Godot (`save_png_to_buffer`, « image/png », la texture qui cite son
        image) mais retient les octets sous l'empreinte des PIXELS (MD5 des données, format, mipmaps, taille), en mémoire
        et sur le disque (`user://cache/png/`, 512 Mo au plus, les plus anciens partent d'abord ; écrit à côté puis
        remplacé). ⚠ **BRANCHÉE AVANT `append_from_scene`** : c'est là que Godot choisit qui sauvera les images — branchée
        après, « Unknown image format » et un `.glb` SANS IMAGES (vu à la sonde ; l'exemple installé par la sonde en
        gardait la trace : il a fallu effacer ce dossier jetable). ⚠ Enregistrée le temps d'une écriture seulement.
        ⚠ Sans `_serialize_texture_json`, la texture ne citait plus son image (comparé dans le JSON, sur un cas minimal).
      - **MESURÉ** : seconde écriture 0 image encodée, 7 reprises ; une nouvelle session (cache disque) : 0,46 s dès la
        première. Seule une PREMIÈRE écriture d'images neuves encode (~2,9 s, comme avant).
      - gardé par `test_temoin_lie` 38 (`_les_png_sont_gardes` : deux images posées sur des faces ; l'attendu est
        l'écriture de GODOT telle quelle (`actif` faux) — octet pour octet en mémoire, depuis le disque dans une « autre
        session », et après une image changée (elle seule réencodée, le fichier de Godot pour ce nouvel état)). **Six
        mutations rouges** (clé sans les pixels, texture sans source, sans mimeType, jamais repris, disque jamais lu,
        branchée après `append_from_scene`). Seul `ecrire_le_temoin_lie` l'emploie ; l'export vers les moteurs et le
        `.mbworld` écrivent comme avant.
      - ⚠ **UN TEST DE LA FUMÉE ÉCHOUAIT SUR UN RESTE** : « exporter une couche sans tuiles est refusé, et rien n'est
        écrit » trouvait un `layer_2.mbset` laissé le matin par un passage précédent (marqué en lecture seule). Il juge
        désormais ce que CET export écrit (le dossier absent, ou son `tileset.json` à la même date).
    - **3. CACHER / MONTRER UNE COUCHE : 1,57 → 0,42 s, et 1,73 → 0,47 s** (`sonde_lags_edition.gd`, avec fenêtre).
      MESURÉ d'abord (instrumentation provisoire) : cacher la couche aux 52 407 cases faisait refaire **192 041 sommets
      dans CHACUNE des deux autres couches** — la couche 0 partait en reconstruction complète (1,03 s : son état, 48 546,
      était sous le compte), la couche 2 en locale (0,44 s) — or **la couche 2 n'en possédait AUCUN, la couche 0 ~5 200**.
      - **`MassifPeint` tient `_colonnes_miennes`** ({colonne : combien de SES cases}, avec `_miennes`), et la route
        locale ne refait que les colonnes de sommets dont l'une des quatre colonnes lues (x..x+1, z..z+1) porte une de
        ses cases — maintenant, ou partie dans ce geste (`parties`). Un sommet n'est à une couche que si l'une de ses huit
        cases est à elle : la sortie est la même. Après : la couche 0 refait 26 744 sommets (~0,18 s), la couche 2 aucun.
      - ⚠ **DEUX PISTES ESSAYÉES ET ÉCARTÉES, MESURÉES** : (1) l'ensemble EXACT des sommets que la règle peut changer
        (les huit sommets de chaque case changée, plus ceux dont `y + 2` passe entre l'ancienne et la nouvelle plus haute
        case de leur colonne) — 185 677 au lieu de 192 041 (la couche cachée est une nappe mince : chaque case porte ses
        sommets), et plus lent à bâtir (2,1 s) ; rendu. (2) comparer le seuil de la route complète à l'UNION plutôt qu'à
        l'état (en couches, la reconstruction complète relit toute l'union) : 1,6 → 1,18 s avant le filtre, mais sa
        mutation est MUETTE après lui (la couche 0 ne refait plus que 26 744 sommets, sous son état) — retiré, faute d'un
        cas mesuré qui le demande.
      - gardé par `test_massif_peint` 110 (`_les_colonnes_qui_la_regardent` : roche, herbe dessus, un caillou contre
        l'herbe avec une case ISOLÉE, une couche lointaine ; cacher l'herbe — la lointaine ne refait aucun sommet, le
        caillou moins de 400, route locale = complète photo pour photo ; retirer la case isolée — les colonnes
        « parties »). **Quatre mutations rouges** (sans les colonnes parties, la seule colonne du sommet, le compte non
        tenu à l'ajout, pas de filtre). ⚠ Le test a d'abord échoué sur LUI-MÊME : la roche n'était pas refaite quand
        l'herbe était cachée (l'écran refait toutes les couches visibles) — le code d'avant échouait pareil.
      - Ce qui reste du geste (~0,4 s) : la couche 0 (~0,18 s, dont la table des hauteurs de toute l'union, ~0,1 s) et
        le reste de l'écran.
    - **SUITES** : 21 vertes après chaque point — au bout, **9 846 vérifications, 0 échec** (`fumee_appli` 800, `test_fluides` 252, `test_massif_peint` 110, `test_temoin_lie` 38). Bancs hors Godot non relancés : rien de
      ce qu'ils lisent n'a changé (`test_greffon_peinture` 255, cas d'épreuve inchangés).
  - **ET ENCORE (4 octobre 2026, la nuit — Jordan : « exporte, et pendant que je teste continue les optis de la
    liste »)**. L'exe a été exporté d'abord (exemple repris, 0 chaîne en clair sur 7). ⚠ **TOUT A ÉTÉ MESURÉ EN HEADLESS,
    DANS DES COPIES À DOSSIER DE DONNÉES ISOLÉ** (`config/use_custom_user_dir`) : Jordan testait l'exe, qui partage
    `user://reglages.cfg` avec le projet ; une sonde avec fenêtre aurait aussi chargé sa carte graphique. Sur
    l'exemple d'aujourd'hui : **491 000 cases dans la couche active, 739 481 dans le monde**.
    - **L'APERÇU D'UNE FORME SPÉCIALE ET DE ROOM : ~150 → ~14 ms par case survolée** (`DEV_TOOLS/banc_apercu_forme.gd`).
      La forme elle-même coûte 0 à 1 ms ; c'était `_occupees_actives`, qui rebâtissait le dictionnaire de TOUTES les
      cases de la couche. Les opérations de sélection (Extrude, Move, Copy, Paste, Shrink à la molette, Room from
      selection…) passaient par le même rebâtissage (`editor._occupees`). Désormais elles lisent l'état que la couche
      tient déjà pour sa reconstruction locale (`MassifPeint.cases_tenues` → `_miennes`), À LIRE SEULEMENT (vérifié :
      formes, étages, outils ne modifient jamais ce qu'ils reçoivent ; la réparation des diagonales, qui part sur un
      autre fil, en prend une copie). Null — la grille est relue — quand la couche attend d'être refaite (cachée) ou que
      son compte diffère de la grille (les ~14 ms restants : `get_used_cells().size()`, gardé par sûreté). ⚠ Exiger en
      plus que l'état soit bâti était une mutation ÉQUIVALENTE (le compte le dit déjà) : retirée.
    - **APRÈS CHAQUE GESTE : l'étiquette d'étage ~75 → ~15 ms, la liste des couches ~26 → ~4 ms.** L'étiquette parcourait
      les cases de la couche ; elle lit un compte PAR ÉTAGE tenu avec `_miennes` (`_etages_miens`, `cases_par_etage`). La
      liste recomptait chaque grille ; elle lit `nombre_de_cases` (l'état, sinon la grille).
    - **LA PLANCHE DES TUILES** se reprenait à CHAQUE enregistrement du témoin (une seconde après chaque geste du
      modeleur) : les maillages des 52 tuiles refaits (~22 ms headless, plus l'envoi à la carte) et leurs 52 photos.
      Désormais rien tant qu'elle n'est pas à l'écran (elle se reprend en se montrant), et seul le maillage d'une tuile
      dont l'empreinte (`empreinte_de` : géométrie, teintes, matériaux, UV) a changé est refait ; les photos sont toutes
      reprises (une peinture change la texture sans toucher au maillage). ⚠ Pas mesuré avec fenêtre.
    - **L'ENREGISTREMENT DU PROJET — LE FORMAT PASSE EN VERSION 2.** Mesuré : la tâche d'écriture, en BASSE priorité,
      attendait jusqu'à **3,4 s** de démarrer derrière les tâches de l'ouverture (vraisemblablement les cartes PBR) — un
      Ctrl+S ou une fermeture l'attendaient avec elle (~3,9 s) ; son texte coûtait ~440 ms, dont ~340 pour `str()` des
      2,2 millions de nombres ; et sa reprise bloquait ~470 ms le fil principal. Désormais : **haute priorité**, et les
      cases en BINAIRE — `cases_b64`, les octets du `PackedInt32Array` (x, y, z, petit-boutiste) en base64 (~70 ms) —,
      sortis du texte avant l'analyse JSON à la relecture (sinon l'analyseur parcourt 12 Mo de base64 caractère par
      caractère, plus lent que les nombres). **Mesuré : la pire image après un enregistrement ~470 → ~8 à 28 ms, un
      Ctrl+S ~490 à 3 900 → ~290 ms, la relecture des cases ~455 → ~390 ms.**
      ⚠ **LA VERSION PASSE À 2, ET C'EST UNE GARDE** : un exe d'avant ne trouverait pas `cases`, ouvrirait des couches
      VIDES et les enregistrerait ; la version le lui fait refuser. La version 1 reste lue. ⚠ Un projet enregistré par
      cette version ne s'ouvre plus dans l'exe exporté ce soir-là. Le `.mbproj` reste du JSON lisible, sauf ses cases.
    - **MESURÉ** : `test_massif_peint` 119 (+9 : 40 gestes au hasard — l'état tenu, le compte par étage et le nombre
      de cases relus dans la GRILLE ; une case posée par une autre route, une couche qui attend : null ; un étage vidé
      par la route locale) ; `test_projet` 117 (+6 : le base64 attendu calculé en PYTHON, la version 2, la version 1
      relue, trois `cases_b64` abîmés refusés, un nom de couche qui contient la marque) ; `fumee_appli` 806 (+6 : les
      formes et les opérations lisent l'état de la couche, qui est la grille après Ctrl+Z ; une tuile sculptée = un
      maillage refait, aucun sans geste ; planche cachée qui attend, reprise en se montrant). **Quinze mutations** —
      rouges : état rendu sans le compte, sans les attentes de la couche cachée, décompte par étage oublié, ajout non
      compté, nombre faux, vue sans l'état tenu, planche qui refait tout, planche cachée reprise, pas de reprise en se
      montrant, l'ancien `str()`, la version 1, pas d'extraction ; ⚠ **MUETTES** : « un étage vidé gardé à 0 » (le
      test était trop étroit — aucun geste au hasard ne vidait un étage par la route locale : cas construit, rouge), et
      deux ÉQUIVALENTES retirées du code (exiger l'état bâti ; refuser une taille non multiple de 12 octets, que le
      contrôle des triplets refuse déjà).
    - **LE COUP DE PINCEAU : 20 touches ~565 → ~58 ms** (`sonde_lags_edition.gd`, headless). ~21 ms des ~31 d'une touche
      étaient la GARDE DE COMPTE de la reconstruction locale : chacune des trois couches relisait sa grille
      (`get_used_cells().size()`, ~7 ms) pour voir une case posée « par une autre route ». Le coup sait ce qu'il a
      changé : `reconstruire_autour(changees, sur)` la saute pour ses touches ; toute action (et l'action suivante)
      la refait.
    - **RETIRER UNE CASE AU BORD DE LA BOÎTE DU MONDE (le sommet, ou l'annulation d'un ajout là) : ~250 → ~5 ms**, et
      ~50 ms la première fois. C'était l'image lente qui suivait chaque Ctrl+Z de la sonde : `FL.boite` rebalayait les
      739 483 cases (~240 ms) pour l'eau. L'écran tient des comptes par x, y, z des cases de l'eau (`_eau_par_axe`),
      bâtis depuis les comptes par étage et par colonne que chaque couche tient déjà (`MassifPeint.comptes_tenus`, total
      vérifié — sinon un balayage), puis case par case ; la boîte en est les clés extrêmes, élargies d'une case.
    - **MESURÉ, EN PLUS** : `test_massif_peint` 121 (+2 : 20 gestes « sûrs » sur 40 ne relisent pas la grille, rendu =
      reconstruction complète) ; `fumee_appli` 809 (+3 : une touche ne relit pas la grille ; deux cases sur le plan du
      bord, une retirée — la boîte ne bouge pas —, l'autre — elle rétrécit —, attendu `FL.boite` recalculée, sans
      rebalayage). **Quatre mutations, toutes rouges** : le décompte par axe oublié, la boîte jamais relue dans les
      comptes, x et z échangés, la touche qui refait la garde de compte. L'étiquette d'étage lit désormais les comptes
      tenus SANS garde de compte (`comptes_tenus` : une étiquette, que la reconstruction suivante remet juste).
    - **SUITES** : 21 vertes, **9 892 vérifications, 0 échec** (`fumee_appli` 809, `test_massif_peint` 121,
      `test_projet` 117). Bancs hors Godot non relancés : rien de ce qu'ils lisent n'a changé.
    - ⚠ **CE QUI RESTE, MESURÉ** (`sonde_lags_edition.gd` en headless) : cacher / montrer une couche ~0,7 s ; poser une
      case ~40 ms (dont les gardes de compte de trois couches, ~21 ms : gardées pour les actions) ; Ctrl+S ~2,4 s (le
      témoin réécrit d'office, GARDÉ) ; l'océan à l'ouverture. Pas fait : les relectures doubles de l'import et du
      tranchage liés (gestes rares).
  - **ET APRÈS L'EXPORT DE 22:17 (4 octobre 2026, la nuit — Jordan : « continue les optis de la liste pendant que je
    teste »)**, mesuré en headless dans une COPIE à dossier de données isolé (`DEV_TOOLS/sonde_ctrl_s.gd`, dans la copie) :
    - ⚠ **CTRL+S N'EST PAS LE POINT LENT QU'ON CROYAIT** : ~0,29 s une fois les cartes PBR à jour (le projet). Les ~2,5 s
      mesurées avant venaient des cartes PBR de l'exemple fraîchement installé (générées puis écrites une fois).
    - **LE MONDE QUI SUIT SON TÉMOIN (retour dans World après une retouche), `_suivre_son_temoin` : ~1,05 → ~0,57 s** (le
      `.glb` écrit à part, ~0,29 s). Décomposé avant : relecture du `.glb` lié ~0,5 s (dont `append_from_file` ~0,18 —
      ~0,36 quand la machine est chargée —, presque tout à décoder ses PNG ; `verifier_sections` ~0,22), écriture du
      cache ~0,27, pose du lot ~0,27 (le GridMap refait ses octants : laissé). Après : relecture ~0,28, pose ~0,27.
      ⚠ L'écriture reportée du cache se paie au Ctrl+S suivant (~0,3 s de plus, une fois).
      - **les PNG déjà décodés sont repris** (`images_relues.gd`, une `GLTFDocumentExtension` branchée le temps de
        `tuiles_liees`, le pendant de `png_en_memoire.gd` à la lecture) : gardés sous le MD5 de leurs octets, puis les
        octets comparés, rendus en copie ; tout autre format laissé à Godot ; en mémoire seulement, 512 Mo au plus.
        Banc (`banc_images_glb.gd`, dans la copie) : `append_from_file` d'un `.glb` de l'exemple 360 → 53 ms ;
      - **le cache du lot est REPORTÉ** (`_ecrire_les_caches` : Ctrl+S, la fermeture, le changement de projet — tout
        `_toujours_ecrire`). Le lot est marqué tout de suite de l'empreinte du `.glb` relu (`Projet.marquer`), que la
        liste des couches lit ; `mettre_en_cache(…, empreinte_)` écrit le lot sous l'empreinte relevée À CE MOMENT : un
        cache en retard (appli coupée) se voit périmé, la couche se relit de son `.glb`. ⚠ **PAS SUR UN AUTRE FIL** :
        écrire un `ArrayMesh` relit ses surfaces au RenderingServer, qui ne répond qu'au fil principal — l'attendre à la
        fermeture serait un interblocage ;
      - **`verifier_sections` ne juge qu'une fois une même section** dans un seau (948 entrées, 337 distinctes) : ~200 ms
        de moins, même sortie.
    - **LA LISTE DES COUCHES APRÈS CTRL+S : ~90 → ~20 ms** — `_rhabiller` oubliait l'empreinte de TOUS les `.glb` (et
      pour chaque couche, même pas périmée) ; il n'oublie plus que celle du `.glb` qu'il réécrit.
    - **UN DÉFAUT DE L'EXE DE 22:17** : une couche VIDE (un projet neuf) faisait crier `raw_to_base64` à chaque
      enregistrement (une ERREUR dans la console ; rien d'abîmé : "" se relisait en zéro case). Elle s'écrit "".
    - **MESURÉ** : `test_projet` 121 (+4 : la couche vide sans erreur du moteur — un `Logger` (`OS.add_logger`) compte les
      erreurs —, un lot écrit sous l'empreinte d'avant est périmé, `marquer`) ; `fumee_appli` 814 (+5 : le cache pas
      encore écrit, le lot marqué du MD5 du `.glb`, la liste « sliced », Ctrl+S l'écrit à jour, l'empreinte d'une autre
      couche gardée) ; `test_tranchage` 53 ; `test_temoin_lie` 46 (+8, `_les_images_relues` : les pixels de GODOT
      (`actif` faux) à la première et à la seconde relecture, la seconde ne décode rien, une image changée — unie d'une
      autre couleur, pour que son PNG ait la MÊME LONGUEUR — seule décodée, `tuiles_liees` qui les reprend). **Trois
      mutations rouges** de plus pour les images : la clé par la longueur sans comparer les octets (⚠ d'abord MUETTE : les
      PNG du test n'avaient pas la même longueur), jamais repris, la relecture liée non branchée. ⚠ « Rien n'est rendu »
      est ÉQUIVALENTE : une image laissée vide est décodée par Godot lui-même — juste, seulement plus lent. **Six mutations rouges** (couche vide, empreinte ignorée, sections mémorisées
      par leur taille, Ctrl+S sans les caches, lot non marqué, tout oublier). ⚠ Une première mutation des sections
      (l'écart de la référence écrasé) était MUETTE : aucun seau des tests ne repasse par la section de référence.
    - **CACHER / MONTRER UNE COUCHE : ~0,95 → ~0,33 s** (headless ; la couche de 52 407 cases, `sonde_couche.gd` dans la
      copie). Décomposé : la couche 0 ~0,7 s, dont **~350 ms à bâtir la table des hauteurs de TOUTE l'union** (739 481
      cases) pour en lire ~1 100 colonnes, et ~100 ms par couche à énumérer les colonnes (quatre entrées par case changée).
      - **`MB.hauts_des_colonnes_de`** : la table des seules colonnes LUES (x..x+1, z..z+1 de chaque colonne refaite),
        chacune balayée du plafond à `_y_bas` — choisie quand ce balayage coûte moins que de tout parcourir. Même réponse
        tant que `_plafond` et `_y_bas` bornent l'union (ce que la route locale exige déjà) ;
      - chaque colonne changée UNE fois (sa plus haute case), puis étendue aux quatre ;
      - **mêmes bilans** sur l'exemple (pièces, fautes, air libre, au chiffre près) avant et après.
      - Gardé par `test_massif_peint` 124 (+3, `_la_table_des_colonnes_lues` : une roche, une herbe de 75 × 75 cachée, une
        case FLOTTANTE au plafond juste HORS des colonnes changées, une masse lointaine dans l'union — le sommet voisin
        de la case flottante pose la tuile de la reconstruction complète, toute la roche aussi). **Trois mutations
        rouges** (les colonnes lues sans leurs voisines, le balayage qui commence sous le plafond, la colonne prise à sa
        première case changée). ⚠ **LES DEUX PREMIÈRES ÉTAIENT MUETTES AVANT CE CAS** : la garde des colonnes qui
        regardent la couche ne passait jamais par la table (moins de 20 000 sommets).

### LA PASSE DU 3 OCTOBRE 2026 — AVANT LE PROJET PREUVE (Jordan : « corrige tous les manquements que tu rencontres,
### perfectionne le soft, ensuite tu me dis quand je pars sur un projet preuve »)

- **LA LISTE DES TRAVAUX IMPORTÉS SURVIT** (étape 2) : `Projet.vers_texte(…, travaux)` les écrit (`"travaux"`, chemins
  dans l'ordre ; une entrée qui n'est pas un texte est écartée, le projet s'ouvre) ; rouverts, ils reviennent dans la
  liste et ne sont RELUS qu'au premier regard (`_travail_maillage`). Un fichier disparu ne revient pas.
- **LES PROJETS RÉCENTS** : six, dans `reglages.cfg` (`projet/recents`, jamais l'exemple), une rangée « Recent » sous
  New · Open · Save as (sans le projet ouvert).
- **« New layer » RESTE DANS L'ATELIER** (World, Geometry, Texturing, Fluids) : il menait toujours à World.
- **UNE ÉTIQUETTE OLIVE NÉE PLUS TARD DANS UNE BARRE DE DROITE PREND SA TEINTE** (`Palette.teinter_ce_qui_arrive` :
  `node_added`, un nœud sous une barre habillée — méta `teinte_d_atelier` — est teinté à l'image suivante).
- **UN TÉMOIN REVENU DE BLENDER GARDE SES CARTES** : la normale et l'ORM du matériau glTF sont écrits À CÔTÉ de l'albedo
  sous des noms d'ENSEMBLE (`…_color.png`, `…_normal_gl.png`, `…_arm.png`) — `Peinture.ensemble_de` les retrouve ; et
  `TemoinLie.reprendre_les_reglages` reprend du témoin d'avant, PAR LE NOM du matériau, ce que le glTF ne porte pas
  (`pbr`, `ensemble`, `echelle`) — un matériau aux cartes DÉDUITES les redéduit (même rendu) plutôt que de garder la
  copie figée. `test_cartes_pbr` (+11, dont normale et ORM revenues comparées à celles parties) ; deux mutations
  rouges — ⚠ la première d'abord MUETTE : les cartes d'un passage précédent restaient dans le dossier du test.
- **MERGE DOWN** (calques de peinture, `Peinture.fusionner_vers_le_bas`) : l'image ne change pas ; le calque du dessous
  est remplacé par une image NEUVE (son opacité cuite) — l'annulation, qui garde les images par référence, rend les
  deux intacts. Refusé sur le calque du bas ou si l'un est caché. `test_peinture` (+8, attendus à la main), fumée (le
  vrai bouton, Ctrl+Z).
- **U PRÉVIENT** quand une autre tuile porte le même matériau déplié (le même carré 0–1 : leurs peintures se
  recouvrent) et nomme l'atlas. Fumée (+2).
- **LE COURANT DES RIVIÈRES AU PLAY TEST** : `EauMaillage.courants` (les cases qui portent une bande, au sens
  `sens_du_cours` — la règle SORTIE de `_riviere`, une seule pour la bande et le courant) ; la vue le lit sous les pieds
  (`courant_au_point`), le personnage dérive de `COURANT` = 1,6 case/s (**PROPOSÉ**), au sol seulement. `test_fluides`
  (+1, cours écrit à la main), fumée (+2 : il dérive dans le sens, sans courant il reste).
- **L'APERÇU D'UNE FORME SPÉCIALE, ~5 FOIS PLUS RAPIDE — MESURÉ** (`DEV_TOOLS/sonde_cout_apercu_forme.gd`, massif plein
  de 40³) : tunnel rond de taille 7 sur 32 cases **114 → 22 ms**, carré 170 → 34. Ce n'était PAS le balayage (1 ms)
  mais la réparation des damiers : 48 appels d'une fonction anonyme par case. `plein` écrit en ligne ; une case dont
  les six voisines par une face ont changé comme elle est sautée (un damier n'a jamais deux coins voisins égaux —
  ⚠ tester les dix-huit voisines était une mutation ÉQUIVALENTE, mesurée) ; un segment sur un axe se balaie par
  tranches. Sortie identique : les cas d'épreuve des greffons, recalculés par `test_greffon_peinture`, n'ont pas
  bougé ; mutation rouge (tout sauter : 13 échecs). ⚠ Lire une grille 3×3 par plan était PLUS LENT (70 ms) : retiré.
  ⚠ Les greffons gardent l'ancien algorithme (même sortie) : une optimisation à porter avec eux.
- **LE MANUEL ET L'ÉCRAN D'ACCORD** (un audit, 3 octobre 2026) : « Slice the work », « Slice the witness » dans World,
  « Extend up », « Save as… », « the Witness workspace », « 52 » écrit en dur, la boîte B qui « prend aussi le caché »
  (infobulle et invite — c'est l'X-ray qui le fait), le couteau « face par face », R absent des outils, P / E / U /
  Alt+clic absents de la table, « SDFGI not used » alors que le Play test l'offre — corrigés ; ajoutés : Rect, Hollow
  box, Select empty cells, Extend selection, Clear, les flèches, Clear the layer, Size et Rail, Delete layer et le
  renommage, River width, une seule mer, New / Open / Recent, ⚠ Not saved, UV (unwrapped), Export UV layout, Image… ,
  Merge down, Reset settings, les ensembles PBR, Reset to the computed witness, le bandeau Shapes et « Where is it
  from? ». **L'ÉCRAN PARLAIT FRANÇAIS** : le rapport et l'annulation des opérations disaient « elargir »,
  « retrecir_bord »… (`NOMS_OPERATIONS`) ; fumée (+2).
- **« FIX DIAGONAL CONTACTS » — DÉCIDÉ PAR JORDAN (3 octobre 2026 : « un bouton fix diagonals errors dans World ? »),
  ÉCRIT LE MÊME JOUR.** Deux boutons dans Shape operations, **Fill** et **Dig**, sur tout le monde VISIBLE, UNE action
  (`FS.reparer_les_diagonales`) : combler pose les deux cases vides de chaque damier dans la couche active ; creuser
  retire les deux pleines si elles sont toutes deux de la couche active, sinon comble ; jamais une case d'une couche
  cachée (on la lui volerait) ; une case ne change qu'une fois, donc ça termine ; ce qui reste est compté et DIT.
  ⚠ **CE N'EST PAS LE RETOUR DE LA COMPLÉTION** (§2, « le rouge, pas la complétion ») : le pinceau ne répare toujours
  rien de lui-même ; le bouton est un geste voulu. `test_formes_speciales` (+6, attendus à la main, l'escalier jugé par
  `MB.contacts_par_arete`) ; fumée (+5, les vrais boutons, Ctrl+Z) ; mutation rouge (creuser une autre couche).
- **LA BARRE POUR TOUT GESTE QUI DURE — DEMANDÉE PAR JORDAN (3 octobre 2026 : « il y a encore la majorité des moments
  où quelque chose se fait en durant sans qu'une barre de progression se montre »), ÉCRITE LE MÊME JOUR.** Les barres
  posées une à une (ouverture, tranchage, eau, Play test…) ne couvraient pas le reste. Désormais :
  - **chaque geste** — une touche (par atelier), un bouton (par son texte), un clic dans la vue (atelier, outil) — est
    repéré dans `_input` de l'écran, AVANT l'interface (c'est le seul `_input` de l'appli), et chronométré jusqu'à
    l'image qui suit la sienne ; `app/durees.gd` (PUR) apprend son coût RAPPORTÉ À LA TAILLE DU MONDE (secondes par
    case + 1 000), moyenne à moitié, et l'écrit dans `reglages.cfg` (section « durees ») : une session apprend pour la
    suivante ;
  - **un geste connu pour dépasser 0,4 s est RETENU** : le panneau d'attente s'affiche, on attend qu'il soit DESSINÉ,
    puis l'événement est rejoué (`Input.parse_input_event`, marqué) — et tout ce qui arrive pendant l'attente est
    retenu avec lui, dans l'ordre (le relâcher d'un clic après son appui). Deux images de délai, pour les seuls gestes
    longs. ⚠ **LA PREMIÈRE FOIS QU'UN GESTE EST LONG, IL N'A PAS DE BARRE** : il n'était pas connu ;
  - ⚠ **LE DESSIN FORCÉ (`RenderingServer.force_draw`) A ÉTÉ ESSAYÉ ET ÉCARTÉ — VU À L'IMAGE** : le panneau
    apparaissait bien, mais avec le texte d'une attente d'avant (« Opening the project ») — un texte changé ne se
    redessine qu'en fin d'image. `DEV_TOOLS/capture_attente_forcee.gd` (avec fenêtre) photographie désormais le
    panneau d'un vrai geste retenu : son nom y est.
  - **MESURÉ** : `test_projet` (+7, attendus à la main : l'échelle par la taille, le seuil, le négligeable, la moyenne,
    les réglages abîmés) ; `fumee_appli` (+4 : un geste qui a bloqué 0,5 s s'apprend sans barre ; un vrai Ctrl+Z
    appris long montre « Undo » sans encore rien défaire, puis est rejoué UNE fois). Mutation rouge (ne jamais
    retenir). ⚠ « Rejouer sans la marque » est MUETTE et ÉQUIVALENTE : le geste rejoué arrive pendant son propre
    chronométrage, donc n'est jamais retenu deux fois ; la marque reste en garde-fou. ⚠ Sans fenêtre, rien n'est appris
    ni montré (les suites ne touchent pas aux réglages). ⚠ PAS TENU EN MAIN.
  - ⚠ **LE CLIC REJOUÉ ÉTAIT AVALÉ PAR LE PANNEAU — TROUVÉ PAR LA SESSION VIDÉOS ET CORRIGÉ (6 octobre 2026)** : le
    second clic d'eau dans Fluids ne posait rien, sans un mot. Le geste retenu est rejoué panneau ENCORE à l'écran (il
    s'en va deux images plus tard), et le panneau, centré, prenait la souris : un clic qui tombait sous lui était perdu.
    Le panneau et ses enfants ignorent désormais la souris (`_sans_souris`). Gardé par `fumee_appli` (815 : un vrai clic
    routé par l'interface au centre du panneau montré arrive à la vue) ; vu rougir sans le correctif (0 événement sur 2).
- **« VERY SIMPLE EXAMPLE » (Jordan, 3 octobre 2026)** : le choix de World et le manuel nomment ainsi l'exemple.
- **LA BARRE DE DROITE DÉBORDAIT À DROITE EN WORLD — MESURÉ ET CORRIGÉ (Jordan, 3 octobre 2026)**
  (`DEV_TOOLS/sonde_largeur_droite.gd`, avec fenêtre) : avec une sélection, 358 px au lieu de 308 (les deux « Extend
  selection » côte à côte, 158 px chacun), puis 311 une fois ceux-ci mis un par ligne — l'ascenseur vertical, apparu
  parce que la barre devenait plus haute que l'écran, ajoutait sa largeur. Désormais le défilement de la barre de
  droite est « jamais montré » en largeur (le contenu ne peut plus l'élargir), sa marge passe de 8 à 4 (le plus large,
  Shape operations, 275 px, tient : 285 demandés, 286 disponibles avec l'ascenseur), et elle grandirait vers la
  GAUCHE (`grow_horizontal`), jamais hors de l'écran. Fumée (+1 : largeur et bord droit avec une sélection).
- **LES CASES DÉCOCHÉES ÉTAIENT INVISIBLES** (vu sur la même image) : les icônes par défaut de Godot sont gris foncé sur
  fond sombre. `Palette._case` les dessine (contour clair décoché, teinte de l'atelier cochée ; ronde pour un choix
  exclusif). Fumée (+1 : une case décochée a une icône claire). Vu à l'image.
- ~~**L'EXEMPLE REPRIS À L'EXPORT DU 3 OCTOBRE PORTE 89 CONTACTS DIAGONAUX**~~ — **RÉPARÉ (Jordan, 3 octobre 2026 :
  « répare les contacts diagonaux de l'exemple »)** par `DEV_TOOLS/reparer_diagonales_exemple.gd` (mesure seule par
  défaut ; `--ecrire` garde l'original en `test.mbproj.avant_diagonales`) : la règle de « Fix diagonal contacts », mode
  COMBLER, sur l'union des couches visibles — rien n'est retiré ; chaque case ajoutée va à la couche de ses voisines.
  **MESURÉ** sur la source du soir (277 574 cases visibles) : 69 contacts par arête, 135 cases ajoutées (toutes dans
  « Desert »), 0 contact relu sur le disque (`MB.contacts_par_arete`, hors de la règle). Réemballé (12 fichiers, 75,5 Mo) ;
  `fumee_appli` 694 / 694. ⚠ Pas regardé à l'image : les 135 cases comblent des creux d'une case en damier.
- **L'OCÉAN N'EST JAMAIS REFUSÉ POUR SA TAILLE — DÉCIDÉ PAR JORDAN (3 octobre 2026)** : `FL.ocean` ne rend plus
  « trop_grand » (il va par tronçons de colonne, il ne s'emballe pas) ; les LACS et les rivières gardent leur garde
  (`FL.VOLUME_MAXI`, case par case). `test_fluides` : un océan au-delà de la borne est rendu, un lac au-delà est refusé.
- **LES SÉLECTIONS NE REFUSENT QUE LE DÉMESURÉ — DÉCIDÉ PAR JORDAN (3 octobre 2026)** : `Outils.VOLUME_MAXI` passe de
  64³ (262 144 : une boîte de 100 × 30 × 100 était refusée) à **128 × 64 × 128 = 1 048 576** (**PROPOSÉ** : la sélection
  se dessine case par case, au-delà l'écran rame). Boîte, Rect, salle et balayage des formes la lisent. ⚠ **LA MÊME
  BORNE DANS LES TROIS GREFFONS** (`mb_tools`, `mb_shapes`, `MBTools.cs`, `MBShapes.cs`, `MBTools.h`, `MBShapes.h`) et
  dans leurs cas d'épreuve (régénérés : la boîte à la limite, celle au-delà, une salle trop grande de 201 × 201 × 34).
  Vert : les suites Godot, le banc .NET (121 cas d'outils) et le banc C++ (clang de Unity, drapeaux d'Unreal) ; Unity
  et Unreal non relancés (une constante).


### FILL HOLES — DEMANDÉ PAR JORDAN (3 octobre 2026), ÉCRIT LE MÊME JOUR

Jordan : « il ne manquerait pas un bouton en Geometry pour boucher les trous que l'édition du witness peut créer ? », puis
« on pourrait quand même recréer les vertices nécessaires, forcément sur le plan de coupe, et essayer de les relier en
faces au maillage d'à côté ». Avant : F sur un rebord choisi à la main, et rien ne disait qu'il y avait un trou.

- **CE QU'EST UN TROU** (`MaillageEdite.trous`, `boucher_les_trous`) : une arête ouverte HORS des plans de coupe. Celles
  qui sont SUR un plan (x, y, z = ±0,5 dans le repère de la tuile) sont sa section, refermée par la voisine du monde.
  **MESURÉ : les 52 tuiles saines du témoin calculé n'en ont aucun.**
- **UN TROU INTÉRIEUR** : une face qui suit la boucle à l'envers ; plane, un polygone, sinon un éventail autour de son
  centre (un polygone gauche se replierait). Teinte et matériau de la face qui borde le trou.
- **UN TROU QUI TOUCHE UN PLAN** a emporté un morceau de section, entre A et B. On la RECRÉE avec les points que la
  section partagée attend (`Sections.manquants` : ceux de la classe, orbite comprise, que cette face n'a plus), rangés le
  long du chemin, puis une face relie ce morceau au rebord. ⚠ PAS UNE LIGNE DROITE : elle n'est que le dernier recours,
  une autre forme ouvrirait une fente à chaque joint. Le chemin : sur le plan commun de A et B ; ou par un COIN (deux
  plans d'axes différents, un point attendu sur les deux, sinon l'arête de case au milieu) ; ou par DEUX coins (deux
  plans parallèles : toute la bande d'un plan arrachée). ⚠ **UN BOUT POSÉ SUR DEUX PLANS LAISSE PLUSIEURS CHEMINS**, et
  le premier venu passait à côté (au hasard : 132 / 156) — on garde celui qui RETROUVE le plus de points attendus.
- **L'ÉCRAN** (Geometry, section Mesh) : **Fill holes** (la tuile en édition) et **Fill holes · all tiles**, UN Ctrl+Z
  pour toutes (`Modeleur.boucher_les_trous`, puis la complétion des sections) ; une ligne compte les trous de la tuile
  (relue quatre fois par seconde) ; ce qui reste (des points de section non recréés) est DIT — une fente restera là.
  Le manuel (F1) le décrit.
- **MESURÉ** : `test_maillage_edite` 189 (+9, attendus à la main : le cube, son trou plan et son rebord gauche en
  éventail de 6, une tuile plate dont on ôte la moitié x > 0 — sans point attendu rien n'est inventé, avec les deux du
  plan x+ la tuile revient, aire 1) ; `test_sections` 39 (+6, sur les VRAIS joints du témoin, hors du code éprouvé : une
  face loin des plans, au bord, au coin, toute la bande du plan x+ — 488 et 1 342 sommets de joint sans partenaire
  ramenés à 0 —, puis **153 arrachages sur 156** au hasard refermés jusque dans le monde) ; `fumee_appli` 729 (+6 : le
  vrai bouton après X sur une face de bord, le compteur, les joints refermés, Ctrl+Z, Ctrl+Y).
- ⚠ **CE QUI RESTE (3 sur 156)** : deux trous d'une même tuile qui se disputent des points ; un arrachage dont le nouveau
  rebord tombe PILE sur le plan (il n'a alors aucune arête « hors plan » : rien n'est vu comme un trou). L'écran dit les
  points non recréés.
- ⚠ **PAS TENU EN MAIN.** Les greffons n'ont rien à porter (c'est le modeleur, dans l'appli seule).

### LES GESTES QUI GARDENT LE BORD — DEMANDÉ PAR JORDAN (4 octobre 2026), ÉCRIT LE MÊME JOUR

Jordan : « identifie les gestes dans la geometry qui peuvent faire des trous, et s'il y a un moyen gratuit de les éviter,
pour utiliser très peu Fill holes », puis « go pour 1 à 4 ».

- **MESURÉ AVANT** (`DEV_TOOLS/sonde_gestes_et_trous.gd`, chaque geste rejoué comme le modeleur, sur la paroi, loin du
  bord puis au contact d'un plan de coupe) : sans risque — E de faces loin du bord, I, Ctrl+B, subdiviser, Ctrl+R, F,
  M de sommets intérieurs (0 trou, 0 sommet de joint sans partenaire). Fautifs : **X** (un trou, et 488 à 732 sommets de
  joint sans partenaire au bord) ; **M** au bord (1 trou ; 244 pour un sommet de bord + un intérieur, 488 pour deux de
  bord) ; ⚠ **E D'UNE FACE DE BORD : 976 SOMMETS SANS PARTENAIRE ET 0 TROU** — Fill holes ne le voyait pas ; ⚠ **E
  D'UNE ARÊTE À DEUX FACES : UN AILERON** (arête à trois faces, trois arêtes ouvertes) que `trous()` comptait 0 ; E d'une
  arête de bord, 732.
- **LES QUATRE REMÈDES** :
  1. **M au bord** (`MaillageEdite.point_de_fusion`) : un sommet sur un plan de coupe ne le quitte pas, les autres le
     rejoignent (« Merge at the border vertex ») ; deux sommets de bord à des places différentes : refusé et dit.
  2. **E de faces, bord épinglé** (`extruder_faces(…, epingler)`, le modeleur l'allume) : les sommets posés sur un plan ne
     sont ni dédoublés ni déplacés ; le dedans monte, les côtés touchant le bord deviennent des triangles. Toutes les
     faces au bord : refusé et dit.
  3. **E d'arêtes au rebord d'un trou seulement** (`arete_extrudable`) : ni arête à deux faces, ni arête posée sur un
     plan ; les autres sont écartées et dites. Et **`trous()` compte les chaînes ouvertes** qui ne se referment pas
     (l'aileron) ; Fill holes les compte en échecs.
  4. **Dissolve, Ctrl+X** (`dissoudre_faces`, comme Blender) : les faces choisies — celles des arêtes ou des sommets
     choisis — disparaissent et leur contour est refermé d'UNE face (un éventail s'il n'est pas plan) ; les arêtes du
     contour posées sur un plan restent. Un anneau ou un contour qui se touche est refusé. X reste, et dit que Dissolve
     ne troue pas.
- **MESURÉ APRÈS** (la sonde) : les quatre, 0 trou et 0 sommet de joint sans partenaire. `test_maillage_edite` 206 (+17,
  une tuile plate 3 × 3 écrite à la main : 17 sommets et 11 faces après E épinglé, les 12 sommets de bord à leur place,
  sans épingler 20 ; M au centre = 1 trou (le contrôle) ; l'aileron compté ; la croix dissoute en UNE face de 12 côtés,
  aire 1 par la triangulation du rendu, orientée ; l'anneau refusé) ; `fumee_appli` (+16 et une SENTINELLE, de vraies
  touches sur la paroi : E 0.1, E sur une arête refusé, M, M refusé, Ctrl+X, les Ctrl+Z ; attendus par
  `_sans_partenaire`). **Mutations** — cœur : 7 rouges (épingler ignoré, M sans refus, M jamais au bord, la coupe ignorée
  par `arete_extrudable`, `trous()` aveugle aux chaînes, dissoudre sans refus d'anneau, dissoudre à l'envers) ; ⚠ une
  ÉQUIVALENTE, retirée du code : ne pas poser le côté entre deux sommets épinglés (`nettoyer` ôte déjà ce côté écrasé).
  Modeleur : 5 rouges (E de faces non épinglé, E d'arêtes sans filtre, M au centre malgré le bord, M sans refus, Ctrl+X
  non branché).
- ⚠ **PAS TENU EN MAIN.** ⚠ Un contour dissous CONCAVE à quatre sommets serait triangulé en éventail (`trianguler`
  n'appelle la découpe en oreilles qu'au-delà de quatre) — défaut d'avant, F l'a aussi, pas corrigé.

### UN SENS PAR MODIFICATEUR, ET LE GUIDE EN ARBRE — DÉCIDÉ (Jordan, 13 octobre 2026), ÉCRIT LE MÊME JOUR

Jordan : « Ctrl, Alt et Maj devraient être les modificateurs contextuels, une utilisation différente selon l'atelier et
l'outil […] faire un état des lieux de tous les raccourcis, laisser les moins importants dans la section Shortcuts, afficher
les plus courants en texte flottant en haut à gauche de la vue, qui se confirme au modificateur pressé […] peu de touches
pour tous les raccourcis, selon le contexte », puis, sur l'état des lieux proposé : « d'accord pour ta répartition, mais il
faut guider en arbre l'utilisateur en montrant des propositions de shortcuts selon le contexte ».

- **LA RÉPARTITION (DÉCIDÉE)** : **Alt = la TAILLE** (pinceau, forme, rayon ; avec une sélection : élargir / Shrink à plat) ;
  **Maj = la HAUTEUR ou « en plus »** (étendre ↑ ↓, étages, profondeur ; au clic : ajouter ; au jeu : courir) ; **Ctrl =
  DÉPLACER ce qui est en jeu, ou l'INVERSE** (la sélection, sinon la grille ; au sculpt : creuser).
- **CE QUI A CHANGÉ POUR LA TENIR** : Ctrl + molette, avec une sélection sous Select / Rect / Box, la DÉPLACE d'une case en
  hauteur (le « grab ») — sinon l'étage, comme avant ; **Ctrl** + clic sur Extrude décale la sélection (c'était Alt, qui
  voulait dire « élargir » à la molette) ; Room : Maj + molette = les étages (Alt ne règle plus rien ; Up / Down au
  bouton) ; **retirés** : Maj + molette = la forme du pinceau (les boutons), Ctrl + Maj + molette = le pas de l'escalier
  (le bouton) — la seule combinaison à deux modificateurs. Geometry et Texturing gardent les gestes de Blender (Maj ajoute,
  Ctrl le lasso et l'inverse, Alt la boucle, la pipette) : ils tombent déjà dans la répartition, sauf Alt (la boucle, le
  X-ray, la pipette), exception assumée.
- **LE GUIDE** (`app/guide.gd`, PUR — `entrees(contexte)` est LA table : [modificateur, geste, effet, essentiel]) : en haut à
  gauche de la vue (`_batir_guide`, à droite de la barre de gauche, sans souris), les gestes essentiels du contexte (atelier,
  outil, forme, sélection, Navigate, collage, glissé, la mer en choix, l'édition, le geste du modeleur, sculpt, pinceau),
  puis une BRANCHE par modificateur (« Ctrl ▸ move the selection up · down ») ; TENIR le modificateur déplie la sienne (ses
  gestes essentiels, puis les autres). Réécrit seulement quand le contexte ou la touche tenue change. Case « Shortcut guide
  in the view » (Shortcuts, `reglages.cfg` [guide]) ; caché dans Project et sous le manuel.
- **LA SECTION SHORTCUTS** se remplit de la même table : tout ce qui n'est PAS au guide (`Guide.le_reste`), pour le contexte
  — elle est désormais visible aussi dans Geometry et Texturing. ⚠ **LE MANUEL (F1) RESTE UNE SECONDE DESCRIPTION** : ses
  tables ont été corrigées à la main (la molette, Extrude), pas dérivées de `Guide` — à faire.
- **MESURÉ** : `fumee_appli` (le guide : Add au repos, Select + sélection et ses trois branches, Ctrl et Maj VRAIMENT tenus
  qui déplient la leur, relâchés la racine, la section Shortcuts sans ce que le guide montre, Geometry, décoché, Project ; la
  molette : Ctrl + molette monte la sélection sans bouger l'étage, Maj ne change plus la forme, Room à Maj, l'escalier sans
  pas ; Ctrl + Extrude) — 995 vérifications, 0 échec. **Quatre mutations, rouges** : le modificateur tenu ignoré, la
  boîte sur la seule copie active, Ctrl + molette toujours l'étage, Extrude décalé par Alt. ⚠ Le guide n'a pas été VU
  À L'IMAGE ni tenu en main ; ses mots sont des propositions.

### TOUT RACCOURCI A SON BOUTON — DEMANDÉ PAR JORDAN (13 octobre 2026), ÉCRIT LE 14

« Rien qui est faisable en shortcut ne doit être pas faisable en bouton dans le soft. »

- **LA TABLE** (`Guide.BOUTONS`, `app/guide.gd`) : pour chaque raccourci CLAVIER de `Guide.entrees` (une seule table de
  raccourcis, celle du guide), le début du texte des boutons qui font la même chose ; `Guide.SANS_BOUTON` dit ce qui n'en a
  pas, et pourquoi — les touches PENDANT un geste (X Y Z, les nombres, Entrée, Échap : aller chercher un bouton déplacerait
  le geste), les touches de MOUVEMENT tenues (marcher, voler, courir), et [ ] (le curseur de taille est là).
- **LES BOUTONS NEUFS** : **Undo / Redo** dans la barre de titre (tous les ateliers) ; une rangée **Frame all · Jump to
  matter · Grid to matter · Floor ↓ · Floor ↑** dans World, Fluids, Transitions et Foliage ; **Cancel paste** (Selection),
  **Forget the anchor** (Special shapes) ; la mer en choix dans Fluids (**Sea ↓ · Sea ↑ · Lay the sea · Cancel the sea**,
  actifs seulement quand une mer est épinglée) ; Geometry : **Back · Left · Bottom** (Ctrl + pavé), **X-ray**, **Loop
  select** ; Sculpt : **Invert** (le Ctrl tenu) ; Paint : **Pick colour**.
- ⚠ **CE QUI DÉPEND DU CURSEUR (², Ctrl + clic, Alt + clic) A UN BOUTON QUI ARME LE PROCHAIN CLIC** (`Vue.clic_arme`,
  `Modeleur.boucle_armee`, `pipette_armee`) ; une bascule qu'une touche peut aussi changer (X-ray, Invert…) est relue à
  chaque image (`_bascules_suivies`).
- ⚠ **UN DÉFAUT PAYÉ, VU PAR LA FUMÉE** : `_bouton` replie son texte ; réduits à leur largeur minimale dans la barre de titre,
  « Undo · Ctrl+Z » passait sur plusieurs lignes, la barre grandissait, les panneaux descendaient sous la bande du bas et le
  centre de la vue bougeait (deux échecs). Undo / Redo sont sur une ligne, sans le raccourci dans le texte (il est dans la bulle).
- **MESURÉ (14 octobre 2026, sur pcjordan, Windows, headless)** : `fumee_appli` **1011, 0 échec** (+8, une SENTINELLE :
  chaque raccourci au clavier de ~60 contextes — World, Play edit avec chaque outil, avec et sans sélection, les formes, le
  collage, les glissés, Navigate, Fluids et la mer, Transitions, Foliage, Geometry et Texturing, leurs gestes modaux, le
  sculpt, le pinceau, le Play test — a son bouton dans l'écran ou son exemption ; Grid to matter arme un vrai clic, qui met la
  grille à la matière cliquée sans rien peindre et désarme ; Undo et Redo sont dans la barre de titre). Sans le diff : 1003, 0.
  ⚠ Le premier attendu du clic armé était faux (une matière à y = 66, hors de −64..64 : refusée à bon droit).
- ⚠ **PAS VU À L'IMAGE, PAS TENU EN MAIN** : la place des boutons, la longueur des barres de droite qui en ont reçu. Les
  bascules X-ray, Invert, Pick colour et la mer aux boutons n'ont pas de garde propre (la table dit seulement qu'ils existent).

### LA BOÎTE, LE LASSO ET LE CERCLE À TRAVERS LES COPIES — DEMANDÉ PAR JORDAN (13 octobre 2026), ÉCRIT LE MÊME JOUR

« On ne peut pas sélectionner plusieurs faces du même bloc à travers des clones différents dans le witness pour les éditer
ensemble. » Le clic le pouvait déjà (Maj + clic sur une autre copie de la MÊME tuile garde la sélection), mais la boîte B,
le lasso et le cercle ne regardaient que la copie EN ÉDITION. `Modeleur._choisir_si` essaie désormais chaque copie de la
tuile sous sa pose (une copie dont le centre est hors du champ est sautée) : un élément entouré sur n'importe laquelle EST
l'élément de la tuile. Gardé par `fumee_appli` (B autour d'une AUTRE copie, loin de l'active : ses faces sont prises, la
copie en édition ne change pas ; les attendus du lasso et du cercle recomptés sur toutes les copies à l'écran).
**LA SÉLECTION SUR PLUSIEURS TUILES — DEMANDÉE (Jordan, 13 octobre 2026 : « la sélection multi-tuiles, go »), ÉCRITE LE MÊME
JOUR.** Maj + clic sur une copie d'une AUTRE tuile garde ce qui était choisi : la sélection de l'ancienne tuile est mise de
côté (`Modeleur.ailleurs` = {clé: {pose de la copie où on l'a faite, s, a, f}}), dessinée à cette pose (un voile et ses
arêtes, en orange), et reprise si l'on revient sur une copie de cette tuile ; un clic sans Maj, A ou Alt+A oublient tout ;
1 2 3 convertissent aussi les sélections mises de côté.
- **G, R, S les mènent toutes** : la même transformation du MONDE, ramenée dans le repère de chaque copie
  (P⁻¹ · P_active · T · P_active⁻¹ · P) ; le pivot est la moyenne de TOUT ce qui bouge ; les sommets de bord sont projetés
  dans leur plan, et la propagation prend des sources dans plusieurs tuiles (`Sections.propager_par_groupe_plusieurs` —
  pour une seule tuile, l'ordre d'avant : `test_sections` 59 inchangé) ; la bride garde aussi les faces des autres tuiles ;
  UN Ctrl+Z (un `TL.Lot`) rend tout. ⚠ **E, I, Ctrl+B ne portent que sur la tuile en édition** — l'écran le dit, les
  autres sélections restent.
- **MESURÉ** : `fumee_appli` 1 002 (un vrai clic, un Maj + clic sur une autre tuile — « mb_arete_b2h0_dehors » gardée —,
  G Z 0.05 Entrée : les deux faces montent dans le monde de l'attendu calculé dans le test — 0,05 par sommet, 0 pour un
  sommet posé sur un plan de coupe horizontal, que sa section y tient —, aucun joint ouvert, UN Ctrl+Z, un clic simple
  oublie) ; mutation rouge (les autres tuiles immobiles). ⚠ Le premier attendu (« le centre monte de 0,05 ») était FAUX : la face choisie touchait un plan de coupe.
  ⚠ Le test laissait la vue en orthographique, et le couteau traversant, éprouvé après, échouait : il rend la vue.
- ⚠ **PAS TENU EN MAIN.** La boîte, le lasso et le cercle ne prennent que la tuile en édition (et ses copies).

### LA MOLETTE — DEMANDÉE PAR JORDAN (3 octobre 2026), DÉCIDÉE ET ÉCRITE LE MÊME JOUR

Jordan : « une utilisation du déroulement de la molette intelligemment pensée, et probablement différente pour les
cibles […] faire un tour d'horizon global et inventer dans tout le soft là où c'est possible et utile ». Un état des lieux
d'abord (la molette ne faisait que zoomer, plus le cercle C et le proportionnel du modeleur), puis ses réponses.

- **LA RÈGLE — DÉCIDÉE** (`Editor._molette`, relayée par `Vue.molette_contextuelle`) :
  - la molette SEULE reste le zoom, sauf PENDANT UN GESTE, dont elle règle la dimension : la hauteur d'un glissé de Rect
    ou de Box (un Rect à plat devient une boîte, sans changer de visée), les étages d'une salle qu'on trace, la hauteur
    d'un collage ;
  - ALT + molette : la grandeur principale de l'outil (taille du pinceau, d'une forme, largeur de rivière, étages de
    Room, rayon du sculpt, taille du pinceau de peinture) ; MAJ + molette : la seconde (forme du pinceau, Depth / Reach /
    Length, Up / Down de Room, force du sculpt, dureté de la peinture) ; CTRL + MAJ : le pas de l'escalier ;
  - CTRL + molette : l'étage de la grille (World, Fluids) ;
  - avec une SÉLECTION et un outil de sélection (Select, Rect, Box), elle FAÇONNE la sélection : Maj l'étend en hauteur
    (Extend selection ↑ ↓), Alt l'élargit d'une couronne À PLAT ou retire son bord (Shrink) — cases vides comprises,
    rien n'est posé. ⚠ **PAS « Grow »**, qui ne garde que la matière : un Rect dans l'air disparaissait (vu en fumée) ;
  - chaque cran est dit près de la souris (`Vue.montrer_valeur`) ; une taille de pinceau (sculpt, peinture) est
    MULTIPLIÉE par 1,15 par cran (de 1 à 200 pixels, un par cran serait trop lent) ; un réglage entier avance d'un.
- **NON (Jordan)** : pas de fonctions nouvelles nées de la molette (tourner un collage, plusieurs coupes au loop cut,
  plusieurs segments au biseau).
- **LES PANNEAUX — DÉCIDÉ (Jordan : « les ScrollContainer défilent si on est dessus et qu'on molette simple, et
  uniquement eux »)**. MESURÉ (une sonde, Godot 4.7) : un curseur survolé changeait de valeur ET laissait défiler — en
  descendant une barre, on déréglait ce qui passait sous la souris ; un compteur qui avait le focus prenait le cran et
  bloquait le défilement. Tout `Slider` perd sa molette (`scrollable`), tout `SpinBox` lâche le focus au premier cran
  (`_sans_molette`, branché sur `node_added` : ce qui naît plus tard aussi).
- **F CADRE TOUTE LA MATIÈRE** (Jordan : « pour recentrer le monde sur voir toute la matière », puis « c'était F, pas
  . ») — World et Fluids : la boîte de toutes les cases des couches visibles, sous l'angle où l'on regarde
  (`Vue.cadrer_toute_la_matiere`). F reste le vol au Play test et Fill dans Geometry.
- **² SAUTE SUR LA MATIÈRE — DEMANDÉ PAR JORDAN ET ÉCRIT (4 octobre 2026 : « se téléporter là où le curseur pointe vers
  de la matière, à une distance raisonnable pour ne pas s'enfoncer dans la matière avec la caméra »)** — World et Fluids,
  la touche lue par sa PLACE (sous Échap : ² en AZERTY, ` en QWERTY). `Vue.teleporter_vers` : le rayon de la souris
  contre l'occupation VISIBLE (portée 3 000, pas `PORTEE` : on saute de loin) ; la cible = le point touché SUR sa face ;
  l'œil recule le long du rayon (déjà parcouru à vide) de `RECUL_TELEPORT` = 8 cases (**PROPOSÉ**), moins si l'on était
  plus près, jamais plus loin que l'œil d'origine ; l'élévation bornée pouvant écarter l'œil du rayon, un second rayon
  cible → œil raccourcit le recul s'il touche. Rien sous la souris : rien ne bouge, et c'est dit. Gardé par
  `fumee_appli` (+7, attendus relus dans les grilles : cible sur une face, recul ≤ 8, aucun point plein entre cible et
  œil, hors de la vue refusé, la touche branchée) ; trois mutations rouges (recul = distance courante, touche non
  branchée, cible au centre de la case). ⚠ PAS TENU EN MAIN.
- Le manuel (F1) a sa table « The mouse wheel ».
- **MESURÉ** : `fumee_appli` (+29, de vrais crans dans la vue et sur un curseur de la barre : zoom seul, Alt / Maj /
  Ctrl, un Rect haussé de deux crans → 27 cases, Maj → 36, Alt → 84 (une couronne à plat, compté à la main), une salle
  tracée avec un cran → 82 cases de coque, Room / tunnel / escalier, le collage, Fluids, F au centre de la boîte relue
  dans les grilles, aucun curseur ni compteur qui prend la molette, sculpt × 1,15, peinture 24 → 28). **Dix mutations
  rouges** (pas de relais, curseurs, compteurs, relâché sans la hauteur, collage, F, Ctrl, facteur, couronne verticale,
  salle) ; ⚠ la première passe du relais n'a RIEN éprouvé (« motif absent ») : une ligne de `vue.gd` avait été écrite
  sans ses retours à la ligne — rejouée sur le bon texte.
- ⚠ **DES LIGNES RECOLLÉES DANS LE DÉPÔT** : un script qui écrivait du GDScript laissait « \ + retour à la ligne »
  disparaître — la condition restait valide, sur UNE ligne avec des tabulations au milieu. Trois autres du même genre,
  d'avant (`editor.gd`, `eau_maillage.gd`, `test_fluides.gd`), remises sur plusieurs lignes.
- ⚠ **PAS TENU EN MAIN.** En particulier : Alt + molette sur Windows (le système ne la prend pas, mesuré nulle part).

### LE DISQUE SOLAIRE DU PLAY TEST — DEMANDÉ PAR JORDAN (3 octobre 2026), ÉCRIT LE MÊME JOUR

« Un soleil visible réglable, le disque solaire en Play test. » Le ciel procédural dessine le disque à la taille de
`light_angular_distance` de la lumière — à 0 ici, d'où l'absence de disque. ⚠ **CET ANGLE ADOUCIT AUSSI LES OMBRES** :
le soleil passe en `SKY_MODE_LIGHT_ONLY` (il n'éclaire que le monde) et une SECONDE lumière, ENFANT de lui (même
direction, même hauteur), en `SKY_MODE_SKY_ONLY`, ne fait que le disque — elle n'éclaire rien. Trois réglages dans la
barre de rendu (Light) : **Sun disk in the sky** (oui), **Sun disk size** (2°, de 0,3 à 12), **Sun disk brightness** (4,
de 0,2 à 16) ; il prend la couleur du soleil et la météo le voile du même facteur. ⚠ **CACHÉ HORS DU PLAY TEST** : le
ciel de World sert aux reflets des métaux, un soleil y ferait des taches. Gardé par `fumee_appli` (679, +5 : le disque au
départ, les curseurs qui le règlent sans toucher l'angle du vrai soleil, la case, World sans disque, la pluie qui le
voile à 45 %) ; trois mutations rouges (la taille portée aussi par le vrai soleil, le disque laissé en World, la météo
qui ne le voile pas). Photo dans `capture_meteo.gd` (« soleil_1_defaut », « soleil_2_gros »).

### L'ATELIER FOLIAGE — DEMANDÉ PAR JORDAN (6 octobre 2026), ÉCRIT LE MÊME JOUR

Jordan : « l'atelier Foliage (un placement dans le monde de foliages comme des arbres dont on importe le fichier 3D comme
glb et on place dans cet atelier sur un socle qui représente le sol pour cerner à quel offset l'objet sera placé par
rapport au sol, et ensuite prévoir toutes les règles intelligentes de placement ; l'atelier Foliage a le monde dans sa
vue comme World mais il ne pourra que placer des foliages, n'importe où avec des modes : dans le vide, planté au sol
voisinage libre, planté au sol débordement) », « je préfère que tu commences par l'atelier Foliage car j'ai besoin de
faire des devlogs avec du décor d'arbres animé ». L'atelier **Props** (des objets attachés aux tuiles, emportés avec
elles, dans une couche de la tuile qui garde l'étanchéité) est demandé ENSUITE : **OUVERT, pas commencé.**

- **UN SEPTIÈME ATELIER** (teinte vert tilleul, **PROPOSÉ**), le monde dans la vue comme World ; on n'y fait QUE planter :
  l'outil devient « feuillage » en entrant, celui de World revient en sortant (Échap, Leave, un autre atelier — comme
  Fluids). Espace (Navigate), PgUp / PgDn (le plan de « In the air »), F, ², Ctrl+molette (l'étage) y marchent.
  Rien dans `editor.gd` que des branchements : l'atelier vit dans `app/atelier_feuillage.gd` (comme `variantes.gd`).
- **LA RÈGLE, DANS LE CŒUR** (`addons/marchingblocks_core/feuillage.gd`, pure, des `Callable` pour lire le monde — elle
  partira dans les greffons). Un MODÈLE : décalage (en unités du modèle : son origine au-dessus du sol), échelle, taille
  au hasard, EMPREINTE (rayon en cases), hauteur (le haut du modèle, mesuré), vent. Un PLANT : son point AU SOL, lacet,
  tirage d'échelle, mode. Les trois modes (**PROPOSÉ**, le sens précis) :
  - **In the air** : sur le plan de l'étage de la grille, n'importe où, même au-dessus du vide ; refusé seulement DANS
    la matière ;
  - **Planted · free** : sur le sol VU ; refusé si le sol penche plus que « Max slope » (40° par défaut), dans l'eau, si
    l'empreinte n'est pas portée par le sol à ±0,35 case (huit points de son bord : un bord de falaise, un pied de mur),
    si la matière l'empêche de pousser (sa hauteur, au centre et à mi-rayon), ou si l'empreinte d'un autre plant empiète ;
  - **Planted · overflow** : sur le sol VU, la pente et l'eau seules comptent — il déborde des bords, des murs et des
    voisins.
  Partout : jamais deux plants au même point (0,05), et « Spacing » (une distance minimale, le pinceau). Un clic plante
  un plant (son lacet au hasard si « Random rotation ») ; le **pinceau** (taille, « Density » = les essais par coup) tire
  des points dans son disque, chacun posé sur le sol et vérifié — les acceptés entrent dans l'index au fur et à mesure.
  Un coup de pinceau se repose quand la souris a parcouru 0,4 de son rayon. Le clic droit enlève (le plus proche, ou
  tout le disque du pinceau). Chaque coup est UNE annulation.
- ⚠ **ON PLANTE SUR CE QU'ON VOIT, PAS SUR LES CASES** : le rayon de la souris trouve la case (l'occupation, comme
  Sculpt), puis le sol est cherché par un rayon VERTICAL contre les triangles des tuiles posées (couches visibles, rangés
  par seaux de 4 × 4 en cache) — sur l'aminci, un quart de case sous le dessus des cases. Sans tuiles, le dessus des cases.
  ⚠ **UN DÉFAUT TROUVÉ PAR LA FUMÉE** : la descente s'arrêtait avant le premier niveau (une borne initialisée « très
  haut ») — aucun clic ne plantait. Gardé (mutation rouge).
- **LE SOCLE** (`app/socle_feuillage.gd`) : un disque de pierre dont le dessus EST le sol, un plan translucide qui le
  prolonge (on voit les racines dessous), l'anneau de l'empreinte, le modèle tel qu'il sera planté (vent compris).
  « Ground offset » l'enfonce ou le lève ; « Sit its base on the ground » pose son point le plus bas sur le sol (c'est
  aussi le défaut à l'import). L'empreinte par défaut : 0,35 × sa plus grande largeur (**PROPOSÉ** : deux couronnes
  voisines se frôlent).
- **LE VENT — DES ARBRES ANIMÉS** (`app/feuillage_vue.gd`) : un shader en espace MONDE, balancement ∝ carré de la
  hauteur au-dessus du SOL du plant (deux rafales désaccordées, une phase par plant), plus un frisson des feuilles. Chaque
  matériau du fichier y est repris (couleur, image, couleur de sommet, découpe ou mélange alpha, double face, rugosité,
  métal et leurs canaux, normale). Rendu en MULTIMESH, une par partie du modèle : des milliers d'arbres, quelques appels
  de dessin. ⚠ **Une MultiMesh n'a pas de matériau par surface** : une COPIE du maillage les porte. ⚠ **L'animation PROPRE
  du fichier (squelette, AnimationPlayer) n'est pas jouée : OUVERT.**
- **LE PROJET** : `"feuillage"` dans le `.mbproj` (modèles, plants à plat par sept nombres) ; absent tant qu'il n'y a pas
  de modèle ; une entrée malformée, ou un plant d'un modèle inconnu, refuse le fichier entier. Le `.glb` est COPIÉ dans
  `<projet>_foliage/` (le même fichier repris, un autre du même nom à côté). Le feuillage appartient au monde entier, pas
  à une couche (**PROPOSÉ**, comme l'eau) ; il se voit dans World, Fluids, Foliage et le Play test (pas dans le témoin).
- ⚠ **CE QUI N'EST PAS FAIT, ET L'ÉCRAN LE DIT** : un plant ne SUIT pas le sol (creuser dessous le laisse en l'air) ; pas
  de collision au Play test (on traverse les troncs) ; pas dans le `.mbworld` ni dans les greffons (dans la liste) ; les
  réglages d'un modèle (curseurs) ne sont pas annulables (comme le « Look » de l'eau) ; un `.gltf` (fichiers à côté) n'est
  pas accepté, seulement le `.glb`.
- **MESURÉ** : `test_feuillage` 70 (le sol des cases, les trois modes, les voisins, la transformation, le pinceau — paires
  et régions recalculées sans la règle —, le fichier, le décalage dans la hauteur ; le rendu sur un ARBRE D'ESSAI écrit en
  `.glb` par `DEV_TOOLS/arbre_d_essai.gd`, mesures écrites à la main : sa boîte, les réglages déduits, le shader des
  feuilles en découpe double face et de l'écorce opaque, ce que chaque plant donne à la MultiMesh) ; `test_projet` 118
  (+3) ; `fumee_appli` 846 (+34 et une SENTINELLE ; la septième teinte et sa barre comprises ; par de VRAIS clics à travers la caméra sur un plateau habillé du témoin :
  l'import par la route du dialogue et sa copie, un plant sur la surface VUE à y = 20,75, Ctrl+Z / Ctrl+Y, refusé au
  bord en « free » et dit, accepté en « overflow », dans le vide sur le plan de l'étage, le clic droit, un coup de
  pinceau — jamais deux à moins de deux empreintes, tous sur le plateau, UN Ctrl+Z —, le décalage, l'enregistrement et
  la réouverture, invisible dans le témoin, Échap). **27 MUTATIONS, TOUTES ROUGES** : le cœur 12 (pas de bord, pas de
  dégagement, voisins sans empreintes, espacement, pente, eau, transformation et hauteur sans décalage, le pinceau qui
  n'indexe pas, un modèle inconnu accepté, le sol des cases sans case vide au-dessus, le doublon) ; l'écran 15 (le sol
  aux cases, la descente arrêtée, pas de copie, pas d'annulation, l'outil non rendu, le pinceau ignoré, le clic droit
  inerte, les curseurs sans effet, le feuillage toujours visible, le relâché non relayé, le projet et l'ouverture sans
  feuillage, le vent sans hauteur, l'alpha ignoré, pas posé sur sa base). ⚠ **« LE SOL SANS CASE VIDE AU-DESSUS »
  D'ABORD MUETTE, PAR LE TEST** : aucun point n'était cherché depuis l'INTÉRIEUR d'une colonne — une colonne de trois
  cases l'a fait rougir.
- **VU À L'IMAGE** (`DEV_TOOLS/capture_feuillage.gd`, Xvfb, OpenGL) : 79 arbres plantés au pinceau en « free » sur un
  plateau du témoin, aucun au bord ; le fantôme rouge refusé au bord ; le socle dans la barre. Les 23 suites vertes. Entre deux photos à
  0,6 s, ~1 % des pixels de la vue changent (les couronnes bougent). ⚠ **PAS TENU EN MAIN, PAS JUGÉ PAR JORDAN** : la
  force du vent, l'aspect sur de vrais arbres (feuillages en découpe alpha), le ressenti du pinceau.

### PLAY EDIT — DEMANDÉ PAR JORDAN (9 octobre 2026), ÉCRIT LE MÊME JOUR

« Un mode Play Edit qui permet de contrôler le stickman pour se promener, et d'avoir la barre de droite de l'atelier World
pour éditer le monde, mais depuis la vue du personnage. » ⚠ Écrit malgré le GEL DES FONCTIONS du 7 octobre (§0) : c'est
Jordan qui le demande. **Tout le détail est PROPOSÉ** (la demande tenait en une phrase).

- **UN ATELIER DE PLUS, « Play edit »** (teinte turquoise, PROPOSÉE ; `JEUX` = « jeu », « jeu_edit » dans `editor.gd`) : le
  personnage du Play test, la section Play test à gauche (avec une note), et **la barre de droite de World** à droite (outils,
  pinceau, sélection, formes spéciales). Passer du Play test au Play edit GARDE le personnage où il est.
- **LA SOURIS** (`Vue._camera_du_jeu_edit`) : clic gauche = l'outil de World, clic droit = l'inverse (comme World) ; la
  caméra au **CLIC DU MILIEU** glissé (lacet et hauteur, souris capturée) ; la molette seule rapproche ou éloigne (jusqu'à 40
  cases), avec Alt / Maj / Ctrl ou pendant un geste c'est la molette du contexte de World. `Vue.peint()` dit où la souris
  peint (World, Play edit). En entrant, la visée passe en **Sculpt** (la matière qu'on voit), Navigate disparaît ; la visée
  de World revient en sortant. L'aperçu suit la caméra qui suit le personnage (pas pour les formes spéciales, l'eau ni le
  feuillage : leur aperçu coûte trop pour chaque image).
- **LE CLAVIER EST AU PERSONNAGE** (ZQSD, A, E, Espace, Maj) : les lettres de World qui s'y heurtent (A, D, S) ne choisissent
  pas d'outil ; restent B, R, [ ], PgUp / PgDn, Suppr, Tab (la visée), les flèches (la sélection), Ctrl+Z / Y / C / X / V, F
  (le vol), Retour arrière. Échap annule d'abord collage, ancre ou sélection, puis rend World. Ctrl tenu n'avance pas
  (Ctrl+Z en AZERTY). Espace sur un bouton de la barre qui a gardé le clavier : la main rendue à la vue, le saut a lieu.
- **CE QU'IL FOULE SUIT LES GESTES** : `_noter_pour_l_eau` (le passage de chaque geste, l'historique compris) prévient la vue
  (`decor_perime`) ; à l'image suivante, les morceaux du décor de collision touchés (x − 1..x, z − 1..z de chaque case) sont
  relus dans les grilles de rendu et rebâtis (`_rebatir_le_decor_perime`, `_batir_morceau` sorti de `_tenir_le_decor`). L'eau
  où l'on nage suit aussi (`eau_du_jeu` refaite après chaque recalcul de l'eau).
- ⚠ **ON PEINT DANS LA COUCHE ACTIVE CHOISIE DANS WORLD** (la liste des couches n'est pas montrée : cacher une couche
  laisserait le décor périmé). Le rapport la nomme en entrant.
- ⚠ **UN DÉFAUT RÉEL DE WORLD, TROUVÉ PAR CETTE GARDE** : depuis `eaf3a20` (27 septembre 2026), `_vue.coup_fini` n'était plus
  connecté à l'écran — un coup de pinceau peint À LA SOURIS n'entrait jamais dans l'historique, et Ctrl+Z défaisait l'action
  d'AVANT. Les suites appelaient `_coup_fini()` à la main, d'où leur silence. Rebranché ; la fumée reste verte.
- **MESURÉ** : `fumee_appli` 953 (+16 et une SENTINELLE, par de vrais clics à travers la caméra du personnage — le même
  personnage depuis le Play test, la barre de World, Sculpt sans Navigate, une case posée deux cases devant lui, le décor
  foulé qui monte de 10,75 à 11,75 et redescend, le clic du milieu qui tourne sans peindre, le clic droit qui creuse, deux
  Ctrl+Z, S qui ne choisit pas Select, B la boîte, Échap qui rend World et la visée Grid). **Deux mutations rouges** : le
  décor jamais prévenu (10,75 → 10,75), et `coup_fini` débranché (l'état d'avant la correction : les deux Ctrl+Z, et sept
  échecs en cascade). ⚠ **PAS VU À L'IMAGE, PAS TENU EN MAIN.** Le coût du rebâtissage sur un grand monde n'est pas mesuré
  (8 × 8 colonnes × la hauteur des grilles, par morceau touché, une fois par image).

### LA MÉTÉO DU PLAY TEST — DEMANDÉE PAR JORDAN (2 octobre 2026), ÉCRITE LE MÊME JOUR

Transmise par une autre session. Dans le Play test, une **météo réglable**, dans la **barre de droite** (celle des
réglages de rendu) : **Rain**, **Blizzard**, **Hurricane**, **Slow snow**, **Hanging particles**, **Heat**, **Fog**,
et **None** (rien).

- ⚠ **ELLE N'EST PAS EXPORTABLE, ET L'ÉCRAN LE DIT** (demandé tel quel par Jordan) : ni dans le `.mbworld`, ni dans
  les greffons. Elle sert à juger un monde peint sous différents temps, comme les réglages de rendu, et ne vaut
  qu'au Play test. Elle n'entre donc PAS dans la liste des greffons à faire.
- **PROPOSÉ (les points ouverts, tranchés par défaut)** : UN temps à la fois ; intensité et vent FIXES ; sur
  l'IMAGE seulement (le personnage n'est ni poussé ni ralenti) ; retenue le temps de la SESSION (on la retrouve en
  revenant au Play test, jamais enregistrée) ; « Reset » de la barre la remet à None.
- **ÉCRIT** (`app/vue.gd` : `METEOS`, `METEO_PARTICULES`, `METEO_BROUILLARD`, `METEO_SOLEIL`, `regler_meteo`) : la
  section « Weather » en tête de la barre de droite du Play test, une liste et la phrase « not saved with the
  project, not exported to the .mbworld, and the engine plugins do not have it ». Pluie et ouragan : des traits
  alignés sur leur vitesse (l'ouragan en biais) ; blizzard, neige lente, particules suspendues, chaleur : des disques
  doux (`_disque_doux`). Les particules SUIVENT L'ŒIL (la boîte d'émission bouge avec la caméra, les gouttes lâchées
  restent dans le monde). Chaque temps ASSOMBRIT (ou force, la chaleur) le soleil RÉGLÉ par un facteur, sans toucher
  au réglage. En quittant le Play test, tout s'en va.
- **UN SEUL ENDROIT DÉCIDE DU BROUILLARD** (`_appliquer_brouillard`), dans cet ordre : sous une nappe, le voile de
  son liquide ; sinon le brouillard de la météo (Fog 0,07, Blizzard 0,08, Hurricane 0,05, Rain 0,02, Heat une brume
  chaude 0,018) ; sinon celui de la barre de rendu. « Fog » n'ajoute donc rien : il REMPLACE, le temps qu'on le choisit.
- ⚠ **LA CHALEUR N'EST PAS UNE ONDULATION DE L'IMAGE — VU À L'IMAGE** : un quad plein écran qui relisait l'écran
  le relit AVANT les objets transparents, et il EFFAÇAIT la lave et la mer. Retiré : une brume chaude, un soleil
  plus fort et des poussières qui montent. ⚠ Et les premières densités (2 500 gouttes dans 28 cases de côté) ne
  montraient qu'une douzaine de traits : boîte resserrée autour de l'œil, nombres montés (9 000 à 12 000).
- **MESURÉ** : `fumee_appli` (les huit temps proposés, la phrase dite, Rain : 9 000 gouttes, brouillard 0,02, soleil
  1,15 × 0,45, les gouttes suivent l'œil ; Heat ; la barre cochée sous Heat garde la brume, Fog l'emporte, None rend
  celui de la barre ; hors du Play test plus rien ; de retour, le blizzard revient ; Reset). Attendus recopiés à la
  main, pas lus dans la vue. Vu à l'image (`capture_meteo.gd`, les huit temps).
  **Huit mutations rouges** : le brouillard de la barre avant la météo, la météo pas reposée en entrant, gardée en
  sortant, sans particules, le soleil sans facteur, Reset qui la garde, la liste qui ne règle rien, et les particules
  qui ne suivent pas l'œil — ⚠ celle-ci d'abord MUETTE : le test regardait juste après la création, où la boîte est
  déjà sur l'œil ; il déplace désormais le personnage de six cases avant de regarder.
- ⚠ **PAS TENU EN MAIN** : le ressenti, le coût des particules sur une petite carte graphique (12 000 traits pour
  l'ouragan), et le rendu de chaque temps se jugent à l'œil.

### LE MONDE D'UN CLIENT, DOUZE TÉMOINS À THÈME — DEMANDÉ PAR JORDAN (16 octobre 2026), ÉCRIT LE MÊME JOUR (branche `monde-client`)

« Modéliser et peindre des témoins avec leur thème (plaine, désert, roche, volcan, plage, boue, gravier, rocaille, mur de
pierre, glace, neige…), avec un niveau de subdivision sweet spot pour qu'un monde tienne sans lagger, et toutes les
fonctions du soft — variantes, transitions, feuillage —, un monde tel qu'il sera dans le jeu d'un client », puis « ça manque
de gros chanfreins, c'est trop blocky ». Rien n'est ajouté au logiciel (gel du 7 octobre) : `DEV_TOOLS/forge_temoins.gd`
mène les gestes du modeleur sur toutes les tuiles à la fois, `DEV_TOOLS/batir_monde_client.gd` bâtit et mesure le monde.

- **LA SUBDIVISION PAR LOT — MESURÉ** : subdiviser tuile après tuile en complétant après chacune s'emballait (10 min,
  2,6 Go). TOUTES les tuiles d'abord, puis UNE complétion : 0 coupe à reporter, 0 absence, 0,6 s (niveau 1), 2,6 s (niveau 2).
- **LE CHANFREIN FRANC — MESURÉ, PUIS VU À L'IMAGE** : le Laplacien n'arrondit presque rien (15 passes au niveau 1, 30 au
  niveau 2 : un rayon d'environ 0,2 case — les plats retiennent les arêtes). Chaque sommet est projeté (Newton) sur la surface
  iso-0,5 du champ TRILINÉAIRE des huit cases de sa tuile (le profil « marching cubes »). ⚠ **LE RACCORD TIENT PAR
  CONSTRUCTION** : sur un plan de coupe, ce champ ne dépend que des quatre cases du plan, que la tuile d'en face partage, et
  un sommet de bord n'y glisse que dans le plan. Mesuré : 0 sommet de joint sans partenaire, dans un témoin et entre deux
  thèmes ; contrôle : deux témoins chanfreinés à 0,85 et 0,5 → 20 104. **0,85 du chemin (PROPOSÉ)** : 1,0 fait une pointe
  sur chaque case isolée, 0,65 des biseaux secs.
- **UNE BASE COMMUNE, DES DEDANS PAR THÈME (PROPOSÉ)** : les couches partagent leurs bords (§3) ; la base (subdivisée,
  chanfreinée) est la même pour les douze, chaque thème ne retouche que le DEDANS (bruit le long de la normale, poids nul sur
  un plan de coupe), ses deux variantes du sol, de la paroi et de la lèvre aussi (poids 2 : 1 : 1). Deux matériaux par thème
  (n.y > 0,55 : le sol), les ensembles PBR de Spirit3D projetés en boîte (une répétition par case), copiés dans le projet et
  ramenés à 1 024².
- **LE SWEET SPOT : NIVEAU 1 — MESURÉ** (PC, RTX 2060, avec fenêtre, synchro coupée ; île de 19 130 colonnes, ~176 000 cases,
  12 couches, sans feuillage ; images/s par plan) : niveau 0 (37 triangles par tuile en moyenne) 18 à 125 ; **niveau 1 (151)
  18 à 93** — presque partout les mêmes images que le niveau 0 ; niveau 2 (605) 9 à 36 — divisé par deux. ⚠ **CE QUI LIMITE
  N'EST PAS LA GÉOMÉTRIE MAIS LES APPELS DE DESSIN** : ~40 000 dans la vue d'ensemble aux trois niveaux (12 couches × ~58
  maillages × deux surfaces × les octants des GridMap), 18 images/s même au niveau 0. Le feuillage (545 plants Tripo) coûte
  de 10 à 30 % selon le plan. **OUVERT** : réduire les appels (moins de couches visibles, un matériau par couche, un rendu
  lointain cuit, les octants) — à mesurer, pas fait.
- **LE RELIEF** : une pente d'une case par case n'est qu'un escalier, que le chanfrein ne fond pas (une marche entière est
  dans l'occupation) — vu à l'image sur la première île. Montagnes et volcan en **corniches de trois cases**, dunes à deux
  niveaux. Eau : la mer (« transparent »), un lac de montagne qui part en rivière et en cascade, un lac de lave et sa coulée,
  25 mares de marais ; 20 paires de transitions ; 27 modèles de feuillage.
- **SUR LE PC** : le projet `C:/Users/jorda/Documents/MarchingBlocks/monde_client/` (photos, `rapport.json`), les mesures
  `mesure_n0|n1|n2/`, le worktree `D:/SpannerGames/ATELIER/MarchingBlocks/worktrees/MB_wt_monde_client`, la tâche planifiée `MBMondeClient` (lance `C:/Users/jorda/mc.cmd`
  dans la session de Jordan : un processus lancé par ssh n'a pas de fenêtre). Une construction complète : ~4 min.
- **LE VERRE ET LE TUNNEL — DEMANDÉS PAR JORDAN (16 octobre 2026), ÉCRITS LE MÊME JOUR.** ⚠ **L'ALPHA D'UN MATÉRIAU DU TÉMOIN
  ÉTAIT GARDÉ, JAMAIS RENDU** (le sélecteur le réglait, le `.mbtiles` l'écrivait) : `MaillageEdite.materiau_godot` se mélange
  désormais quand l'alpha de la couleur est sous `OPAQUE` (0,995) — rien à déclarer ; le glTF le porte (alphaMode BLEND), le
  monde et les moteurs le reçoivent. Un curseur **Opacity** dans Materials (l'alpha de la couleur, une donnée, un endroit).
  Gardé par `test_temoin_lie` 54 (+8, lus dans le JSON du `.glb` et dans le lot relu ; une pierre reste opaque) — rouge sans
  la correction (3) — et `fumee_appli` (le vrai curseur, Ctrl+Z). ⚠ Un matériau ANIMÉ ignore l'alpha (son shader). Dans le
  monde client : une 13e couche **Glass** (la base lisse, alpha 0,34) ; un îlot au sud, un tube de verre qui plonge, file sous
  la mer sur un fond marin en pente (la bande du tunnel descend à −9), entre sous la plage, traverse une salle de 19 × 9 × 15
  (quatre piliers de pierre, un puits de lumière en verre), remonte et débouche sous une coupole de verre près du village.
  `sonde_tunnel_client.gd` (PC, 3 s) : 0 case du creux noyée, 0 contact par une arête, l'axe toujours dans le creux. Le GIF :
  `filmer_tunnel_client.gd` (l'axe lu dans `tunnel.json`), `01_scripts/gif_tunnel_client.py` → `04_exports/gif/
  monde_client_tunnel.{gif,mp4}` (20 s ; le GIF en 480 px à 10 i/s, 18,8 Mo). Pas jugé par Jordan.
- **L'INTRO DE CHAQUE GIF — DÉCIDÉ (Jordan, 16 octobre 2026 : « une demi-seconde au début où l'on voit le soft en entier avec
  son UI et une petite manipulation qui passe du witness de base à celui sculpté, pour chaque prochain gif »).** Le rush :
  `DEV_TOOLS/filmer_intro_temoin.gd` (Witness, en édition : une couche neuve montre le témoin calculé, un vrai clic sur
  « Meadow » montre le sculpté). ⚠ **HORS ÉDITION, WITNESS MONTRE TOUJOURS LE TÉMOIN CALCULÉ**, quelle que soit la couche
  (les photos `temoin_*.png` du bâtisseur le montrent aussi). ⚠ **L'APPLI MET ~0,45 s ENTRE LE CLIC ET LE NOUVEAU TÉMOIN** :
  l'intro garde le geste (×2) et le basculement, pas l'attente. ⚠ **FENÊTRE MAXIMISÉE = 1 038 px : L'ENREGISTREUR (1 080) ROGNE
  ~40 px DE CHAQUE CÔTÉ DE L'UI** — l'intro se tourne en `--fullscreen`. Montage : `01_scripts/intro_gif.py` (`avec_intro`,
  l'icône Tripo de la barre de titre masquée).
- **LES GROTTES SOUS L'ÎLE, ET LE MONDE CLIENT DEVIENT L'EXEMPLE — DEMANDÉ PAR JORDAN (16 octobre 2026 : « prendre le monde
  client comme exemple fourni dans le soft à la place de celui qui est moche actuellement, en lui ajoutant un réseau de
  galeries et de grandes salles de toutes tailles et formes originales en dessous de l'île »), ÉCRIT LE MÊME JOUR**
  (`batir_monde_client.gd`, `_les_grottes`). Huit salles, chacune sa forme et sa roche (la paroi prend le thème de la salle
  sur une case d'épaisseur — un sommet de paroi n'a que du creux et cette couronne) : une **cathédrale** (pilier central,
  stalactites ; Rock), une **salle hypostyle** (super-ellipse, piliers tous les cinq ; StoneWall), un **anneau** (un tore
  autour d'un noyau ; Desert), un **puits en spirale** (rampe hélicoïdale de douze cases par tour, pilier ; Rock), une
  **lentille** plate au sol bosselé (Mud), une **géode** hérissée de cristaux (Ice), une **chambre de lave** (Volcano),
  une **salle des arches** (trois arches de pierre ; Scree) ; dix galeries qui serpentent (pente ≤ 1 pour 2). On y entre par
  un **gouffre** dans la prairie, une **rampe** qui monte au désert, et la salle du tunnel de verre. Sous le niveau de la mer :
  les colonnes descendent de trois cases sous le creux, aucun contact par une arête (une case de grotte rebouchée, jamais
  du verre), les poches que rien n'atteint sont rebouchées. **MESURÉ** (`DEV_TOOLS/sonde_grottes_client.gd`, recompté hors
  du bâtisseur) : 15 993 cases creusées, 0 noyée par la mer, 0 contact par une arête, 0 case non atteinte depuis le ciel du
  gouffre, la salle du tunnel atteinte ; ~267 000 cases pleines.
  **LA JONCTION EN PIERRE (Jordan, le même jour : « la jonction extérieur intérieur en autre chose que du verre afin qu'on
  ne voie pas le décor à travers le verre, sous la map »)** : la coque du tube à moins de quatre colonnes d'une terre
  émergée (l'îlot, la côte, la sortie dans la prairie) est en mur de pierre (`_jonction`, couche StoneWall) ; le verre ne
  reste qu'en pleine mer (614 cases, 293 de pierre) et au puits de lumière. `sonde_tunnel_client` : 0 noyée, 0 contact.
  ⚠ Pas vu à l'image ni parcouru au Play test.
  **L'EXEMPLE** : `~/.marchingblocks/exemple_source.txt` désigne désormais `Documents/MarchingBlocks/monde_client/
  monde_client.mbproj` (avant : `test/test.mbproj`) — le prochain export emballe le monde client. **MESURÉ** : 77 fichiers,
  archive de **223 Mo** (252,7 Mo décompressés : le feuillage Spirit3D 133 Mo, dont trois modèles 59 Mo ; les 13 couches
  ~95 Mo) contre 81 Mo avant — l'exe grossit d'autant (OUVERT, à Jordan). `fumee_appli` sur le PC avec cette archive :
  **1117 vérifications, 0 échec** (l'exemple s'ouvre, ses 13 couches, aucun cube rouge). ⚠ **DEUX DÉFAUTS DE LA FUMÉE,
  pas de l'appli** : elle lisait les cases de l'archive dans `cases` (un projet de format 2+ les porte en `cases_b64`), et
  laissait l'exemple ouvert pour les sections suivantes, qui passaient tant qu'il était petit (30 rouges sur le monde
  client) — elle rouvre le projet d'avant. Le choix dans World s'appelle désormais **« Example world »** (Jordan, 16 octobre 2026), le manuel aussi.
- ⚠ **PAS FAIT** : l'export `.mbworld` du monde vers les greffons ; aucune garde dans les suites (la forge est mesurée par
  `sonde_forge.gd`, pas par un test qu'on a vu rougir) ; la frontière sol / paroi en dents de scie sur les lèvres chanfreinées
  (le seuil de normale) ; **PAS TENU EN MAIN, PAS JUGÉ PAR JORDAN.**

### LA STATION SPATIALE — DEMANDÉE PAR JORDAN (17 octobre 2026), ÉCRITE LE MÊME JOUR (`DEV_TOOLS/batir_station.gd`, `filmer_station.gd`)

« Un projet entier nouveau comme monde client, mais en sci-fi, dans la modélisation comme dans le texturing, avec une partie
texture fixe, texture émissive et texture animée de très haute qualité ; beaucoup de layers, une station spatiale riche ; à la
fin un play test en vidéo de deux minutes et une autre de 2 minutes en play edit », puis « de la lumière ambiante suffisante
avec du SDFGI quand tu filmes » et « une musique sci-fi CC0 du style Metroid ». Ses réponses : textures **CC0 + calculées**,
un projet **neuf** (`Documents/MarchingBlocks/station/`, « scifi » du 6 octobre intact), **musique seule**, le monde client
**reste** l'exemple livré. Rien n'est ajouté au logiciel (gel du 7 octobre) : ce sont des scripts de `DEV_TOOLS/`.

- **LES TEXTURES** (`SpannerGames/PROJETS/MarchingBlocks/01_scripts/textures_station.py` → `BIBLIOTHEQUE/textures/station/`,
  hors git, refaites par le script) : 23 bases **ambientCG (CC0)** en 2K ramenées à 1 024², et par-dessus des finitions
  CALCULÉES (caissons, bandes lumineuses, plaques, chevrons de danger, hexagones) fondues dans la normale ; 25 matières fixes
  dont la plupart émissives ; trois SÉQUENCES de 32 images (plasma du cœur, écrans du commandement, hologramme) ; des
  défilements (conduits, colonnes de données) et des pulsations (lampes de culture, gyrophares). ⚠ **JUGÉES À L'IMAGE, DEUX
  PASSES** : des bases sales écartées (`MetalPlates008` en camouflage, `DiamondPlate006C` rouillé, `PaintedMetal016`), la teinte
  posée sur la luminance (une tôle bleue × beige virait au menthe), la cage du plasma calculée (la base n'avait pas de jours : le
  plasma restait noir), les grilles lues par leur carte d'opacité, plus de feux de position sur la coque (un semis qui
  scintille de loin).
- **LE BÂTISSEUR** : la forge du monde client (base subdivisée au niveau 1, chanfrein 0,55, dedans en tôle, deux variantes
  2 : 1 : 1) ; **14 couches** (Core, Holo, Command, Datacore, Reactor, Lab, Hydroponics, Habitat, Hangar, Deck, Solar, Truss,
  Hull, Glass), trois matériaux chacune par l'orientation des faces, les pistes animées posées par `Anim.importer_sequence`
  et `Anim.ajouter` (la route de l'atelier). La station : des modules à coque de DEUX peaux (le thème dedans, Hull dehors) —
  un hangar à ciel ouvert (on y naît) et sa navette, la coursive et ses hublots, le commandement (baie, hologramme, verrière),
  le labo, le réacteur (cœur de plasma, fosse de refroidissement), l'hydroponie (102 plants Spirit3D, rigoles), les
  quartiers, un belvédère de verre ; dehors ailes solaires, antenne, radiateurs. **25 148 cases. MESURÉ (RTX 2060)** : 52 à
  163 img/s selon la vue, 2,7 Go de mémoire vidéo ; 0 absence, 0 repli à la forge.
  - ⚠ **UN LIQUIDE OUVERT DANS UNE STATION LA NOIE** (vu deux fois à l'image) : la fosse du réacteur, puis les rigoles,
    débordaient par leur seuil jusqu'au hangar (la règle des lacs). Elles sont **sous un plancher de verre** : des cavités
    closes, le liquide reste dans sa rangée. Et un sol noyé refusait le feuillage (7 plants au lieu de 102).
- **LES VIDÉOS** (`filmer_station.gd --prise=jeu|edit`, sur une COPIE du projet ; ciel noir, SDFGI, ambiante 3,0,
  exposition 1,4, halo) : `04_exports/station_playtest_v2.mp4` (**120 s**, du hangar à l'hydroponie, au labo, au
  commandement, aux quartiers et au réacteur) et `station_playedit_v2.mp4` (**81 s** : muret et Ctrl+Z, tunnel, salle,
  escalier gravi, verre, toit creusé, recul), musique **« Galactic Temple » de yd (OpenGameArt, CC0)** — `verifier` OK pour les
  deux (1080p, −14 LUFS). ⚠ **LE PLAY EDIT FAIT 81 s, PAS 2 min** : le personnage piétinait 37 s au seuil du tunnel, coupé.
  ⚠ **SDFGI ÉTEINT L'AMBIANTE SOUS UN TOIT** : la lumière vient de l'émission des matières (des tubes et rampes ajoutés pour ça).
  ⚠ **TROIS PIÈGES DU PILOTE, PAYÉS** : `filmer_haut._images` ne règle la caméra qu'en atelier « jeu » (pas « jeu_edit ») ; un
  point du monde choisi d'avance tombait hors de la vue (le clic ouvrait le manuel) — `_viser` cadre d'abord ; un bouton
  d'une barre qui défile se manque — outils et formes choisis par l'écran, la carte le dit.
- ⚠ **PAS JUGÉ PAR JORDAN** : les textures, la station, les deux vidéos. Des modèles Tripo (feuillage Spirit3D) sont à l'image.

### LE MONDE CARTOON — DEMANDÉ PAR JORDAN (18 octobre 2026), ÉCRIT LE MÊME JOUR (`DEV_TOOLS/batir_monde_cartoon.gd`, `modeles_cartoon.gd`, `filmer_monde_cartoon.gd`)

« Un monde avec autant voire plus de matières que monde client, style chanfreiné et relief simple sauf des petits morceaux
sculptés qui sortent du lot et donnent un aspect caractéristique à chaque matière, de la peinture handpainted (pas de texture
toute prête), un aspect cartoon minimaliste genre Pokémon, une grande map carrée avec un réseau souterrain large et des
reliefs qui sortent de la heightmap (arches, corridors, enfoncements dans les falaises) », puis « pas de motif répétitif sur
toutes les textures, certaines presque unies », « du foliage CC0 de haute qualité et pas trop lourd pour en mettre
beaucoup », « la SDFGI au tournage, une torche pour les intérieurs ». Rien n'est ajouté au logiciel (gel du 7 octobre).

- **LES TEXTURES SONT PEINTES PAR SCRIPT** (`SpannerGames/PROJETS/MarchingBlocks/01_scripts/textures_cartoon.py` →
  `BIBLIOTHEQUE/textures/cartoon/`) : aplats posterisés, motifs cernés, sans couture ; herbe, fleurs, automne, chemin,
  sable, plage, neige, glace, boue PRESQUE UNIES ; motifs aux pavés, à la roche, au canyon, à la lave (émission), aux
  berges en strates. ⚠ **LE CRISTAL ET LA CAVERNE SONT PRESQUE UNIS AUSSI** : des facettes répétées à chaque case
  faisaient un damier dans une salle entière (vu deux fois à l'image).
- **17 COUCHES** (Crystal, Mushroom, Cavern, Cobble, Path, Flowers, Grass, Autumn, Forest, Sand, Beach, Canyon, Mud, Snow,
  Ice, Rock, Volcano) sur la base du monde client (niveau 1, chanfrein 0,85) ; un dedans par matière (coussins, rides,
  facettes, strates, craquelures) et des VARIANTES RARES (6 : 1 : 1) à UN morceau sculpté franc (butte, bloc taillé,
  corniche, pointe, bouche de lave), sur cinq clés dont le sol et la paroi sous roche. ⚠ **LES COUCHES SOUTERRAINES EN
  TÊTE DE PRIORITÉ** : derrière l'herbe, le plafond d'une galerie était posé par l'herbe (des berges pendaient sous terre) ;
  et une case de grotte REBOUCHÉE contre un contact par une arête garde la matière de sa grotte.
- **LE MONDE** : une île carrée de 160 × 160 en terrasses de trois cases, huit régions, un bourg pavé, 6 arches (prairie,
  canyon, une arche de mer), un corridor dans la montagne, 16 alcôves au pied des falaises, un réseau de galeries larges
  (six cases) et cinq salles, au-dessus de la mer, où mènent 10 alcôves ; mer, lac, lave, 46 mares ; 27 paires de
  transitions. **331 467 cases. MESURÉ (RTX 2060)** : 8 img/s la vue d'ensemble (73 000 appels), 17 à 97 ailleurs.
  ⚠ **PAS DE RIVIÈRE** : celle de la montagne entrait par une alcôve et noyait le réseau ; aucune alcôve au marais ni au lac.
- **LE FEUILLAGE CC0** (`BIBLIOTHEQUE/modeles/`) : Quaternius, Stylized Nature MegaKit [Standard] (glTF converti en .glb
  par le bâtisseur), et Kenney, Nature Kit 2.1 ; les cristaux calculés. **3 889 plants**, sans perte d'images par seconde
  mesurable. ⚠ Aucun modèle Tripo dans ce monde.
- **LA VIDÉO** (`filmer_monde_cartoon.gd`, plein écran, l'UI masquée, SDFGI, une torche et une lueur avant accrochées à la
  caméra sous terre) et `01_scripts/montage_cartoon.py` : `04_exports/monde_cartoon.mp4` et le GIF du tour de l'île, sur
  « Happy Adventure (Loop) » de TinyWorlds (CC0). ⚠ **LA PREMIÈRE PRISE ÉTAIT NOIRE SOUS TERRE** (torche à 3,2) ; un mode
  `--seulement=sous_terre` en fait l'essai en photos.
- ⚠ **PAS JUGÉ PAR JORDAN.**

### LES GRANDS MONDES NE PLANTENT PLUS — DEMANDÉ PAR JORDAN (9 octobre 2026, depuis le jeu Resolve : « règle le problème de MB
### qui plante, il ne doit pas planter » ; « je ne veux pas avoir plusieurs sous-maps »), ÉCRIT LE MÊME JOUR

Le monde de Resolve (`D:/Resolve/Resolve_MB_project/val_de_resolve.mbproj` — le jeu s'appelle désormais The Story of Knil,
`D:/TheStoryOfKnil/Knil_MB_project/monde_knil.mbproj` : 784 × 784 colonnes, 11 couches, 1,36 M
cases, 3 350 arbres) faisait planter l'appli juste après l'ouverture : « FATAL: Index p_index = 4294967294 is out of
bounds (count = 32771) », puis signal 4. Mesuré par bissection (banc de Resolve, `outils/banc_ouverture_mb.gd`, qui
ouvre un projet dans `app/editor.tscn` et remet les réglages) :

- ⚠ **CE N'ÉTAIT NI LA MÉMOIRE, NI LE NOMBRE DE CASES, NI L'EAU, LE FEUILLAGE OU LES TRANSITIONS** : la dalle plate seule
  (une case d'épaisseur sur 784²) plantait ; un morceau de 512 m à 494 000 cases aussi ; 400 m tenait. C'était l'ÉTENDUE
  × les couches. Plante aussi `--headless` (pas le rendu) ; tient avec le serveur physique coupé, et avec Jolt : c'est
  **le moteur physique de Godot (GodotPhysics3D)** qui déborde au premier pas. Les grilles `Rendu` portaient les FORMES
  du lot (une boîte par octant plein de chaque pièce, `RP.collision`) : un corps par octant de GridMap, des centaines
  de milliers de formes. Les mettre hors de toute couche physique ne suffit pas (elles restent dans la structure).
- **LE REMÈDE** : `MassifPeint.collision_des_pieces` (vrai par défaut : le greffon, qui sert aux jeux, ne change pas) ;
  faux, la grille `Rendu` porte une COPIE SANS FORMES du lot (`lot_de_la_grille` : mêmes maillages, noms, numéros ;
  gardée tant que le lot ne change pas). **L'appli met faux** (`Vue.ajouter_couche`) : elle ne marche jamais sur ses
  grilles — son décor de visite est à part (couche 2, `_decor`), et rien ne lit les formes du lot. Gardé par
  `test_massif_peint` §15 (6 ; vu rougir : 544 formes sur la grille si le réglage est ignoré).
- **LE FEUILLAGE PAR MORCEAUX** (`feuillage_vue.gd`, `MORCEAU` 32, `PORTEE` 400) : une MultiMesh par partie ET par
  morceau — une seule pour tout le monde n'était jamais écartée du rendu (sa boîte couvre la carte) : 3 350 arbres de
  20 000 à 46 000 triangles à chaque passe, **299 M primitives, 4 img/s même de près** ; plus loin que `PORTEE`, un
  morceau n'est plus dessiné ; et les maillages du vent ont leurs LOD (`ImporterMesh.generate_lods` : un `.glb` lu à
  l'exécution n'en a pas). `multimeshes(id)` rend les morceaux à la suite ; `test_feuillage` 70, `fumee_appli` 937.
- **MESURÉ, le Val entier (RTX 2060)** : ouvert en 5,6 s ; bâti en ~50 s ; 4,1 Go. Vue d'ouverture (recul 26) :
  **25 img/s** (7,2 M primitives, 8 600 appels) au lieu de 4 ; recul 60 : 12 ; recul 150 : 5 ; tout le monde cadré
  (F) : 1. Avant : planté.
- **OUVERT — LES VUES LOINTAINES** : ce sont les 1,7 M pièces des GridMap, dessinées SANS LOD (384 000 appels, 321 M
  primitives tout cadré). Des octants plus grands (`cell_octant_size` 16, 32) divisent les appels par 2 et 4 sans
  gagner d'images ; refaire chaque pièce du lot avec ses LOD (`ImporterMesh`) a été essayé depuis le banc : trop long sur
  ce monde (arrêté à 15 min, 6,9 Go). La voie : une vue LOINTAINE cuite (un maillage simplifié par région, comme la
  cuisson de Resolve), montrée au-delà d'une distance. À décider.

## 6. Méthode — ce qui a été payé cher

⚠ **UN TEST QU'ON N'A PAS VU ROUGIR NE GARDE RIEN.** Toute propriété se garde par un scénario
CONSTRUIT, jamais espéré, et se prouve par une mutation délibérée qui rougit.

⚠ **UNE MUTATION MUETTE A DEUX LECTURES** — le code est inutile, **ou le test est trop étroit** — et on
ne choisit pas la première parce qu'elle est plus commode. Le départage se fait en donnant au code ce
que les tests ne lui donnent jamais : une entrée MAL FORMÉE. (Une fois, j'ai conclu « code mort » et
supprimé ; un test de fumée m'a démenti dans l'heure.)

⚠ **UN COMPTEUR VERT NE DIT JAMAIS QU'UNE TUILE EST À SA PLACE.** Une mesure de couverture répond à
« a-t-on posé quelque chose », jamais à « est-ce la bonne chose ». Trois fois dans la même journée, la
couverture était parfaite et le rendu faux — **seule une image l'a montré**. Le maillage d'un bloc
tunnel qui ne montrait aucun tunnel n'a été vu qu'à l'image, lui aussi.

⚠ **UN CONTRÔLE QUI S'INVERSE INVALIDE L'INSTRUMENT, PAS LE SUJET.** Deux instruments ont menti avec
assurance le même jour : une moyenne de joint calculée sur 3 pixels de pièces ajourées (bruit), et un
rendu jugé contre un fond que la pièce n'aurait jamais en place. **Un rendu de contrôle doit reproduire
le CONTEXTE, pas seulement la pièce.**

⚠ **ET MES PROPRES FILTRES M'ONT FAIT ÉNONCER DES FAITS NON MESURÉS — trois fois.** Une recherche de
mot dans des octets bruts a rapporté « NORMAL présent » alors qu'elle appariait `"normalized":false`.
Un `grep` lancé depuis le mauvais dossier a rendu une liste de références partielle que j'ai failli
prendre pour complète. Et j'ai annoncé « doublon pur, zéro perte » sur deux fichiers aux octets
identiques mais aux **référents différents** : les supprimer a cassé 22 ressources.
**Avant d'énoncer un fait, vérifier que l'instrument mesure bien ce qu'on croit.**

⚠ **ET VÉRIFIER QUE LE SUJET N'A PAS CHANGÉ ENTRE DEUX MESURES.** Le même chemin de fichier, lu à vingt
minutes d'écart, a rendu deux résultats opposés — *UV oui, texture OUI* puis *UV NON, texture aucune*.
J'en ai conclu que la lecture des `.glb` était **instable**, et j'ai suspendu trois conclusions justes.
Les deux mesures étaient bonnes : le `.glb` sculpté avait été **écrasé par l'export brut** entre les
deux. Ce n'était pas l'instrument, c'était la **tenue de registre**. Une empreinte du sujet relevée à
chaque mesure l'aurait dit en une ligne ; trois tours ont été dépensés à chercher une instabilité qui
n'existait pas.

⚠ **UN TEST NE CALCULE JAMAIS SON ATTENDU AVEC LA FONCTION QU'IL ÉPROUVE.** Le contrôle du choix de
contexte appelait `MB.sous_le_ciel()` pour bâtir son attendu. Muter cette fonction déplaçait donc
l'attendu ET le mesuré ensemble : la mutation restait **muette**, et le test se comparait à lui-même.
L'attendu doit venir d'ailleurs — recalculé à la main, ou dérivé d'une autre autorité. ⚠ Et le même
piège a une seconde forme : un contrôle d'instrument qui n'a de valeur que s'il peut **s'inverser**.
Compter les contextes avec `exterieur_possible(bits)`, qui ne dépend que des bits, ne pouvait
structurellement jamais trouver une classe à double contexte — c'était une tautologie déguisée en
mesure.

⚠ **QUAND UNE HYPOTHÈSE SURVIT À PLUSIEURS MESURES SANS ÊTRE CONFIRMÉE, SOUPÇONNER L'INSTRUMENT AVANT
LE SUJET.** Dix-sept classes manquaient au témoin. J'ai accusé la silhouette, puis le score du
finisseur, puis la taille du bloc — quatre tours, une silhouette redessinée pour rien, un plancher de
contrainte posé pour rien. Le défaut était dans `sous_le_ciel()`, **que j'avais écrit la veille** : il
faisait coiffer chaque pièce par sa propre couche haute, donc 5 classes extérieures atteignables sur
22, quelle que soit la forme du bloc. **Le témoin n'avait jamais eu tort.** Le premier réflexe doit être
de mesurer si ce qu'on cherche est seulement ATTEIGNABLE — ici, l'énumération exhaustive tenait en
vingt lignes et aurait tout tranché d'emblée.

⚠ **UNE SUITE QUI NE SE CHARGE PAS NE ROUGIT PAS — ELLE SE TAIT.** Une erreur de parsing dans
`massif_peint.gd` (un `var k` éclipsant un itérateur `for k` plus bas) a rendu `test_massif_peint`
**muet** dans la boucle des six suites : aucune ligne, aucun compte, et **le tout a fini en code 0**.
C'est le piège du `--check-only` sous un autre masque : l'absence de verdict se lit comme un verdict.
Une boucle de test doit dire **« MUET »** quand une suite ne rend pas son compte, jamais l'omettre.

⚠ **UN CONTRÔLE NÉGATIF TRANCHE CE QU'UNE IMPRESSION NE TRANCHE PAS.** Huit erreurs « already has a
parent » ont été attribuées à nos modifications ; greffon désactivé, il y en avait **huit aussi**. Elles
ne sont pas à nous.

⚠ **AVANT DE RÉPARER, DEMANDER SI LE DÉFAUT EST DANS LE PÉRIMÈTRE.** Quatre passes de mesure ont été
dépensées sur un problème qui était hors sujet, et la réponse tenait en une phrase.

⚠ **UNE SECONDE DESCRIPTION D'UN MÊME FAIT DIVERGE TOUJOURS.** On DÉDUIT plutôt qu'on déclare ; quand
deux appelants partagent une règle, elle vit à UN seul endroit. ⚠ Et **une extraction qui change sa
sortie n'est pas une extraction** : c'est la règle partagée qui devient l'autorité, pas l'inverse.

⚠ **UN MOT, UNE CHOSE.** Deux sens pour un même nom, c'est peindre l'inverse de ce qu'on croit sans
qu'aucune erreur ne le signale.

⚠ **ON NE FORKE JAMAIS UN ADDON TIERS** : un fork, c'est un conflit à chaque mise à jour amont. On s'en
sert comme d'une bibliothèque, et le greffon reste le nôtre.

### Outillage

- **Tests** — `godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/<test>.gd`, code 0 ou 1.
  Dix-huit suites, **8 672 vérifications, 0 échec** (1er octobre 2026, relevées après les formes spéciales),
  plus trois bancs hors Godot : .NET (`engines/unity/conformance-runner` :
  18 cas de pose, 103 d'outils dont 34 de formes), g++ (`engines/unreal/core-runner` : les mêmes, et le repère)
  et Unity 6.6 (26 tests), et un essai Blender (`essai_blender.gd`, il lui faut Blender) :
  `test_marching_blocks` 1 986, `test_repli_procedural` 3 922, `test_blocs_maitres` 1 468,
  `test_massif_peint` 82, `test_tranchage` 53, `test_decoupe` 17, `test_etages` 15, `test_projet` 55,
  `test_outils` 57, `fumee_appli` 322, `test_greffon_peinture` 218, `test_faux_artiste` 36,
  `test_maillage_edite` 160, `test_formes_du_temoin` 117, `test_temoin_lie` 31, `test_sections` 30, `test_peinture` 24, `test_formes_speciales` 79.
  ⚠ **Plus `test_fluides` 86 (1er octobre 2026, après le relevé)** ; `test_projet` 62 et `fumee_appli` 373 depuis
  le mode Fluids (et l'escalier d'une autre session) : le total ci-dessus n'a pas été relevé.
  **Relevé suite par suite le 1er octobre 2026 au soir, après le geste d'une case (§5)**, 19 suites, 0 échec :
  `test_massif_peint` 90, `fumee_appli` 391, `test_fluides` 121, `test_formes_speciales` 110,
  `test_greffon_peinture` 221, `test_peinture` 29 ; les autres comme ci-dessus.
  **Relevé le 2 octobre 2026, après les trois liquides et la météo**, 19 suites, **8 981 vérifications, 0 échec** :
  `test_fluides` 148, `fumee_appli` 426, `test_decoupe` 20 ; les autres comme au relevé du 1er octobre au soir.
  Bancs relancés le même jour : .NET et C++ 18 cas / 1 624 poses / 103 cas d'outils / 0 échec, Unity 6.6 26 tests
  sur 26, Unreal 5.8.3 BuildPlugin sans avertissement.
  **Relevé le 3 octobre 2026, après la passe d'avant le projet preuve**, 20 suites, 0 échec : `fumee_appli` 681,
  `test_cartes_pbr` 78, `test_fluides` 217, `test_peinture` 66, `test_projet` 96 ; les autres inchangées (1 468, 22, 27,
  36, 117, 129, 255, 180, 1 986, 96, 62, 3 922, 33, 32, 53). Bancs hors Godot non relancés (les greffons n'ont pas bougé).
  **Relevé suite par suite le 2 octobre 2026 au soir, après les couches exclusives**, 19 suites, **9 118
  vérifications, 0 échec** : `test_massif_peint` 96, `fumee_appli` 535 (après Up / Down et l'exemple), `test_projet` 72, `test_formes_speciales`
  122, `test_peinture` 29, `test_greffon_peinture` 221 ; les autres comme au relevé précédent. Bancs hors Godot
  non relancés (rien de ce qu'ils lisent n'a changé).
  **Une vingtième suite, `test_cartes_pbr` (54), le 2 octobre 2026 au soir** (les cartes PBR déduites, §5) ; relancées
  avec elle, 0 échec : `test_peinture` 48, `test_maillage_edite` 160, `test_temoin_lie` 32, `test_blocs_maitres` 1 468,
  `test_greffon_peinture` 255, `test_massif_peint` 96, `fumee_appli` 594 ; Unity 6.6 32 tests sur 32.
  ⚠ **LE BANC C++ TOURNE AVEC LE clang DE UNITY** (`…/WebGLSupport/BuildTools/Emscripten/llvm/clang++.exe
  --target=x86_64-pc-windows-msvc`, mêmes drapeaux que `build.sh`) ; et **`RunUAT BuildPlugin` ÉCHOUE SOUS UN
  DOSSIER `-Package` PROFOND** (chemins de plus de 260 caractères, « OtherCompilationError » sans une ligne
  d'erreur) : un dossier court, `%TEMP%\ueb`.
  ⚠ **APRÈS UN RENOMMAGE DE DOSSIER, LE CACHE DE CLASSES D'UNE AUTRE MACHINE EST PÉRIMÉ** (`.godot/`,
  hors git) : « Class "MassifPeint" hides a global script class » — `test_massif_peint` rendait **1**
  vérification au lieu de 86 en finissant en code 0, et `fumee_appli` pendait. Mesuré le 28 septembre
  2026, aussi sans les changements du jour. Remède : `godot --headless --editor --quit` une fois, puis
  rendre ce qu'il a réimporté (`git status`).
  ⚠ **LA FUMÉE OUVRAIT LA COPIE INSTALLÉE DE L'EXEMPLE DE L'UTILISATEUR (vu le 2 octobre 2026)** : elle comparait
  ses retouches à l'archive (« Hills » : 2 cases de moins) et l'appli la réenregistrait en fermant. Elle installe
  désormais le sien dans `user://fumee/example` (`editor.gd`, `racine_exemple`, une variable statique).
  ⚠ **UNE SONDE QUI RÉÉCRIT `reglages.cfg` LE COPIE SUR LE DISQUE D'ABORD** (`sonde_lags_edition.gd`) : interrompue,
  une sonde qui ne le gardait qu'en mémoire a perdu les réglages de l'utilisateur (2 octobre 2026 ; la section
  `associations` a été refaite d'après le registre, le dernier projet ouvert n'a pas pu l'être).
  ⚠ **`fumee_appli` CHARGE L'APPLI ENTIÈRE** et la mène sans souris. Elle pointe `reglages.cfg` sur un
  projet jetable et le rend à la fin : l'appli s'enregistre à chaque geste, et une fumée qui rouvrirait
  le vrai dernier projet l'écraserait. `capture_app.gd` fait de même, AVEC fenêtre.
  ⚠ [30 septembre 2026 : ces gardes sont REMPLACÉES par celles d'« une tuile par clé » — §16 la pureté et
  la pose sans tirage, §10 le peintre qui pose le nom nu, §14 la tuile du sommet le plus pur.]
  Les trois suites qui ont grossi portent les gardes des exemplaires : `test_marching_blocks` §16
  (nommage et tirage), `test_massif_peint` §10 (le peintre les pose, et un lot sans exemplaires marche
  encore), `test_blocs_maitres` §14 (aucun morceau sculpté n'est jeté). **Onze mutations délibérées,
  toutes rouges** — dont la seule qui compte vraiment : remettre le `if pieces.has(cle): continue`
  rend « le modèle rend 541 sommets récoltables, le lot ne porte que 52 items ».
  ⚠ **L'ATTENDU DU §14 EST RECOMPTÉ SOMMET PAR SOMMET, SANS LE TRANCHEUR.** Comparer « exemplaires en
  plus » au nombre d'items du lot aurait été une TAUTOLOGIE : remettre le `continue` rendrait 0 = 0,
  et la mutation serait restée muette. L'autorité est le MODÈLE (charte §6).
  ⚠ `test_blocs_maitres` a presque triplé avec le bloc de 12³, pour la même raison qu'en dessous : ses
  boucles par cellule et par pièce assertent une fois par élément, et il y a 820 cases.
  ⚠ **`test_blocs_maitres` EST PASSÉ DE 597 À 589 SANS QU'AUCUNE ASSERTION NE SOIT TOUCHÉE**, en
  collant la grille du finisseur. Deux de ses boucles assertent **une fois par élément** — une par
  cellule (« sort du cube ») et une par pièce (« le sommet n'est pas intérieur ») — et ces deux
  populations ont rétréci : **267 → 262 cellules (−5)** et **282 → 279 pièces (−3)**, soit exactement
  les huit. Mesuré sur les deux grilles, pas déduit par soustraction : raisonner « −5 aux cellules donc
  −3 aux pièces » aurait supposé qu'aucune autre boucle du fichier n'assertit par élément.
  ⚠ **LE TOTAL ÉCRIT ICI A MENTI, ET C'EST UN CAS DE « TENUE DE REGISTRE ».** Il annonçait 6 686 alors
  que les suites en rendaient 6 597 : personne n'avait recompté après une suite retouchée. Un chiffre
  de charte se relève, il ne se reporte pas.
- ⚠ **UNE MUTATION REJOUÉE PAR UN BINAIRE PÉRIMÉ MENT AVEC ASSURANCE.** Cinq mutations du banc .NET ont
  rendu le MÊME échec : `Copy-Item` garde la date du fichier source, MSBuild a jugé le binaire à jour et
  a rejoué la première mutation cinq fois. Un banc de mutations force la recompilation
  (`--no-incremental`) — et cinq verdicts identiques pour cinq défauts différents sont un signal.
- ⚠ **UN `-Werror` PEUT FAIRE PASSER UNE MUTATION POUR ROUGE** : ôter l'usage d'un paramètre ne compilait
  plus (« unused parameter »), et l'échec de COMPILATION n'est pas un test qui rougit. La mutation se
  réécrit pour compiler (`|| true`, `&& false`), puis on lit QUEL cas rougit.
- **Pas de `class_name`** dans le code testé : les tests tournent en `--script`, avant que l'éditeur ait
  indexé les classes globales. On `preload`.
- ⚠ **`--check-only --script` rend TOUJOURS le code 0**, même sur une erreur de parsing : **seul le
  TEXTE fait foi**. Une boucle qui teste `$?` déclare « compile » sur tout.
- ⚠ **`--import` ET `--editor --quit` RÉÉCRIVENT `project.godot`** depuis les réglages chargés. Toute
  édition de ce fichier doit donc venir **après** la dernière exécution de l'éditeur, sinon elle est
  silencieusement annulée.
- ⚠ **Dans un test lancé par `--script`, `_ready()` n'a pas encore tourné** pendant `_initialize()`.
- ⚠ **UN GREFFON D'ÉDITEUR NE SE TESTE PAS EN HEADLESS.** On vérifie qu'il compile et que les règles
  qu'il appelle sont justes ; qu'il apparaisse et que les boutons agissent se juge dans l'éditeur.
- ⚠ **Le headless ne rend RIEN** : tout ce qui se voit se vérifie avec fenêtre.
- **Les sondes** (`DEV_TOOLS/sonde_*.gd`) ne conçoivent rien : elles disent ce qui EXISTE. Écrites parce
  que supposer une API a coûté quatre erreurs en une journée.

---

## 7. Langue

Le français pour les commentaires, la documentation, les `print()` et tout `DEV_TOOLS/`. **L'anglais
pour toute chaîne qu'un utilisateur du greffon peut lire à l'écran.** En cas de doute : *est-ce qu'un
acheteur du greffon peut la lire ?*

---

## 8. Ce que ce projet a été — et où le retrouver

⚠ **Jusqu'au 24 septembre 2026, Undermend — le nom du projet jusqu'au 27 — était un JEU** : un monde vu de dessus et des grottes vues de
côté en écran partagé, un moteur d'énigmes de lumière (miroirs, vitres, lasers, couleurs sur trois bits,
activables), des nœuds et des ondes, un auto-tuilage 2D par Better Terrain.

**DÉCIDÉ (Jordan, 24 septembre 2026) — ce versant est SUPPRIMÉ.** `CORE/`, `CLIENT/`, les outils et les
suites de tests 2D, les lots de tuiles 2D et l'ancienne approche « lot3d » sont partis. Le projet est
désormais le greffon.

- ⚠ **TOUT EST RÉCUPÉRABLE DANS GIT** : `git show 8552bc0:CLAUDE.md` rend la charte du jeu, et
  `git checkout 8552bc0 -- CORE CLIENT` rend le moteur. Rien n'a été perdu, tout a été rangé.
- ⚠ **`addons/better-terrain/` avait déjà disparu du disque** alors que le greffon l'appelait encore :
  le bouton « Falaises » plantait à la première pression, et **rien ne le signalait tant qu'on ne
  cliquait pas**. Il est parti avec le reste.
- **`TILESOURCES/lot3d_simple_ground/` et `HEART_WORLD/` sont GARDÉS** : lot 3D acheté, non suivi par
  git, plus référencé par aucun code. ⚠ Ses 22 `.res` pointent vers le jpg de `HEART_WORLD/` tandis que
  `shared_material.tres` pointe vers la copie de `TILESOURCES/` : **les deux copies sont nécessaires**,
  malgré des octets identiques. Supprimer l'une casse l'autre — mesuré, à mes dépens.

---

## 9. Ordre de travail

1. ~~Le modèle, le bloc maître unique de 8³, le tranchage, la classification~~ — fait, 68/68.
2. ~~L'aller-retour `.glb` avec Blender~~ — fait, et vérifié sur le fichier réel de Jordan.
3. ~~Le panneau dans la bande de droite, les opérations d'étage~~ — fait.
4. ~~**La récolte à deux contextes**~~ — **FAITE** (`503b768`, redressée par `75eae30` et `2f0258d`).
   Le trancheur récolte par (classe, contexte), `_assembler()` nomme la variante, et le peintre cherche
   la variante PUIS retombe sur le nom nu. ⚠ **Ce repli n'est pas une commodité** : un lot sans
   variantes — le repli procédural, un lot d'avant cette version — doit continuer de marcher mot pour
   mot, sinon des cubes rouges apparaissent sur des lots parfaitement valides.
   **MESURÉ (27 septembre 2026)** : `librairie()` livre les 52 tuiles du monde, variantes comprises.
   ⚠ **`sous_le_ciel()` POSAIT DES MURS DE GROTTE SUR TOUTES LES FALAISES — CORRIGÉ LE 26 SEPTEMBRE
   2026.** Il sondait les HUIT colonnes d'un sommet ; sur une paroi, quatre d'entre elles SONT la falaise,
   qui continue vers le haut. Mesuré sur le monde peint de Jordan : **85 % des murs d'un paysage étaient
   des murs d'intérieur**. La question juste est « le VIDE que borde la pièce voit-il le ciel ? » — on ne
   sonde que les colonnes vides. Ça reste un oui-ou-non, donc ça ne rouvre pas le débat de l'occlusion.
   ⚠ **IL A SURVÉCU PARCE QUE LE TÉMOIN N'AVAIT QU'UNE À DEUX CASES DE RELIEF**, où les deux règles
   rendent exactement la même chose — et il n'est apparu qu'à l'IMAGE, en peignant la légende par
   occlusion. Gardé par `test_marching_blocks` §15, une falaise de TROIS cases, **vu rougir** en
   rétablissant les huit colonnes ; le contrôle négatif (un surplomb au-dessus du vide) garde que la
   correction n'est pas une simple permissivité.
   ⚠ **DEUX RÉSERVES QUI SURVIVENT À LA TÂCHE, à ne pas perdre avec elle** :
   - **le coût de `sous_le_ciel()` sur une carte réelle n'a été mesuré sur AUCUN monde** (`503b768`).
     Il balaie la verticale des huit cellules d'un sommet, par pièce ; ça ne doit pas être supposé
     négligeable ;
   - **le score du finisseur est AVEUGLE AU CONTEXTE** (mesuré, `75eae30`) : une classe d'intérieur
     gagnée y vaut exactement une classe d'extérieur perdue, alors que la marge est de ×4,53 dedans
     contre ×0,95 dehors. Le grimpeur rebouche donc le ciel pour gagner dedans, et **redessiner les
     couches ne sert à rien** tant que le score ne distingue pas les deux contextes.
     ⚠ **LE REMÈDE EST POSÉ, ET CETTE RÉSERVE NE L'EST PLUS QU'À MOITIÉ** : `_finir` et `_elaguer`
     imposent un **PLANCHER de sommets sous le ciel** (`ciel_plancher`), dérivé de la silhouette écrite
     à la main et vérifié à CHAQUE coup, jamais constaté à la fin. Le score reste aveugle — c'est
     assumé : le plancher l'empêche de nuire, là où pondérer la rareté aurait demandé de choisir un
     poids arbitraire. La seconde branche (pondérer) reste donc OUVERTE, mais elle n'est plus
     nécessaire. ⚠ **Et depuis le 27 septembre 2026, le finisseur n'engendre plus le témoin livré** :
     cette réserve ne vaut que pour `verifier_bloc_unique.gd`.

5. **LA LÉGENDE DU TÉMOIN — EN COURS.** Le solide qui part chez l'artiste peint sa roche SOUTERRAINE
   d'une AUTRE TEINTE. ⚠ **La raison est un défaut observé, pas un ornement** : rien ne disait à
   l'artiste quelle part de son bloc est souterraine, et c'est ce qui lui a fait extruder le haut en
   croyant tenir le massif de base.
   - **DÉCIDÉ (Jordan, 27 septembre 2026) — LA LÉGENDE EST PAR FACE : « le VIDE que borde la face
     voit-il le ciel ? »** (`MB.face_sous_le_ciel()`). Elle était par CASE (`case_sous_roche()`) : une
     case de falaise, ayant la falaise au-dessus d'elle, se disait souterraine — le défaut de
     `sous_le_ciel()` d'avant le 26, resté dans la légende. Invisible en couleurs plates ; le PBR espace
     monde l'a rendu flagrant, avec des falaises RAYÉES toutes les deux cases dans le monde peint, parce
     que la paroi à l'air libre (`mb_plaque_b2h2_dehors`) portait 135 couleurs de falaise et 135 de
     grotte. Un PLAFOND garde la question de sa dalle — dessous de surplomb contre plafond de grotte.
     ⚠ **12 % DES FACES DE L'AMINCI (1 819 sur 15 560) NE BORDENT PAS LA CASE D'EN FACE** : ce sont les
     marches que l'amincissement taille dans une case PLEINE voisine. Le vide bordé est alors la case
     qui a causé la marche (`BlocsMaitres.vide_borde()`) ; l'ignorer rend exactement les 135 rayures.
   - **MESURÉ (`sonde_legende_contexte.gd`, 27 septembre 2026, planète paysage)** : l'aminci peint
     **6 370 de ses 15 560 quads** en teinte souterraine — **40,9 %**, contre 76,3 % par case : les
     falaises ont cessé d'être comptées comme grotte. La légende suit le bloc translaté.
   - **MESURÉ — `test_blocs_maitres` §10, réécrit à la face, a su échouer trois fois** : revenir à la
     légende par case, `vide_borde` qui ignore les bandes de marche, les plafonds traités comme des
     parois. L'attendu est un balayage écrit à la main, jugé sur la coque SANS retrait.
   - **DÉCIDÉ (Jordan, 25 septembre 2026) — SIX TEINTES FRANCHES, et c'est contre ma recommandation.**
     Trois orientations × deux contextes : vert / ocre pour les sols, beige-brun / mauve pour les
     parois, bleu / bleu profond pour les plafonds (`repli_procedural.gd`, qui reste leur unique
     source ; le mailleur ne les redéfinit pas).
     ⚠ **CE QUI ÉTAIT ÉCRIT ICI — « on MODULE les trois teintes, on n'en ajoute pas trois ; six teintes
     franches auraient rendu bariolé un témoin dont l'illisibilité est le défaut qu'on corrige » — A
     ÉTÉ RENVERSÉ, et la raison compte plus que le verdict** : mon objection visait une couleur qu'il
     faut DEVINER, et la **légende écrite sous la vue** (ancien `ecran_edition.gd` ; aujourd'hui l'appli) y répond en donnant son nom
     à chacune. Six teintes nommées valent mieux que trois modulées ; six teintes muettes auraient
     effectivement été pires.
     ⚠ **ET LA MODULATION NE POUVAIT PAS SUFFIRE, c'est ce qui rend le renversement juste** : la lumière
     directionnelle assombrit déjà les faces à l'ombre du même ordre de grandeur, si bien qu'une paroi
     de grotte et une paroi extérieure à l'ombre se confondaient. Des TEINTES distinctes ne se
     confondent pas — aucun compteur ne l'aurait dit, seul l'œil.
   - ⚠ **`case_sous_roche()` VIT DANS `marching_blocks.gd` ET NULLE PART AILLEURS.** L'écrire dans le
     mailleur en ferait une SECONDE description du critère de contexte — la faute que le vérificateur
     du bloc a déjà coûtée (§6). Elle est VOISINE de `sous_le_ciel()` sans lui être égale : l'une
     qualifie un LIEU DE POSE, l'autre un MORCEAU DE MATIÈRE, et `test_marching_blocks` §14 construit
     exprès un auvent où les deux répondent différemment au même endroit.
   - **MESURÉ — les deux gardes ont su échouer**, cinq mutations délibérées chacune, toutes rouges :
     côté `test_blocs_maitres` §10, le retour de la division entière (qui fait porter DEUX légendes à
     la case (−7,0,0)), `case_sous_roche` bloquée à vrai puis à faux, son balayage réduit d'un cran, et
     la teinte souterraine retirée de `_quad` (l'ASSOMBRISSEMENT, à l'époque où la légende modulait) ;
     côté `test_marching_blocks` §14, la régression
     `sommet.y + 2` → `+ 1` (celle qui a coûté quatre tours), **la fusion des deux fonctions**
     (`case_sous_roche := not sous_le_ciel`), les deux décalages du balayage de matière, et
     `sous_le_ciel` bloquée à vrai.
   - ⚠ **RESTE À JUGER À L'IMAGE, AVEC JORDAN — ET RIEN DE CE QUI SUIT N'A ENCORE ÉTÉ VU D'UN ŒIL
     HUMAIN** : le headless ne rend rien, et aucun compteur ne dira si les six teintes se distinguent
     réellement en place (§6 — c'est déjà ce qui a tranché la force du chanfrein). Trois choses
     attendent ce jugement, toutes écrites et compilées, aucune éprouvée :
     **les six teintes**, **la vue orbitale carrée** de la bande de droite avec sa légende écrite
     dessous, et **le sens du glissé**, dont Jordan a signalé qu'il partait à l'envers et dont les deux
     signes ont été inversés sans que je puisse le vérifier autrement qu'en le lisant.
     ⚠ **MES MESURES DE PIXELS ONT ÉCHOUÉ DEUX FOIS SUR CE MÊME SUJET** : c'est l'œil de Jordan qui
     tranche, pas une comparaison d'images que je fabrique et que je juge seul.

   - **À JUGER AUSSI À L'IMAGE** : la planète paysage elle-même (`ART/paysage.png`), et la légende
     peinte par occlusion (`planete_paysage.gd --ao`, `ART/paysage_ao.png`) — une LÉGENDE, qui informe
     sans décider ; l'occlusion reste écartée comme critère de pose (§2).
   - ⚠ **UN `.glb` SCULPTÉ SUR L'ANCIEN 8³ NE REVIENT PLUS** : le bloc est retrouvé par sa POSITION
     dans une boîte de 12³ (§4), et sa forme a changé. Il faut réexporter le témoin avant de sculpter.

6. ~~**LES EXEMPLAIRES**~~ — **FAITS** (27 septembre 2026), **RETIRÉS le 30** (§3, une tuile par clé). Le trancheur ne jette plus rien : **52 clés,
   541 items, 489 exemplaires** là où 489 morceaux sculptés partaient à la poubelle sans un mot
   (§3). Le peintre en tire un par hachage de la POSITION, donc identique à chaque reconstruction.
   Les remarques de couture s'affichent pour la première fois.
   ⚠ **TROIS RÉSERVES QUI SURVIVENT À LA TÂCHE** :
   - **rien n'a été vu à l'image.** Les exemplaires changent l'aspect d'un monde peint et aucun
     compteur ne dira si c'est mieux — c'est déjà ce qui a tranché la force du chanfrein (§6) ;
   - **les 0 remarques de couture sont mesurées sur le témoin PROCÉDURAL**, jamais sur un `.glb`
     sculpté. C'est là que les fissures apparaîtront, s'il y en a ;
   - **`librairie()` coûte 17,7 s** après le rejet précoce de `decoupe.gd` (203 s avant). Mesuré sur
     le témoin de 12³ seulement ; un bloc plus gros n'a pas été essayé.

7. **La sélection maison** (§5) : `_forward_3d_gui_input`, un rayon, un étage ou la géométrie, un
   surlignage. C'est ce qui débloque tous les outils au-delà de la case à case.
8. ~~**LE PBR ESPACE MONDE**~~ — **RETIRÉ (Jordan, 29 septembre 2026), et le mode PBR simplifié (ancien
   point 9) avec lui** (§1). Ce qu'il a appris reste vrai et reste ici en une ligne : le POM est un effet
   par PIXEL, il ne change jamais une silhouette — le relief réel est à l'artiste. Il a aussi révélé la
   légende par case (point 5), corrigée. `git show 72d1764` rend son code et ses mesures.
9 bis. **LE TERRAIN MONOLITHIQUE ET LES PROPS RATTACHÉS** (§3) — DÉCIDÉ, pas écrit ; **REPORTÉ à une mise à jour
   future (Jordan, 2 octobre 2026)**. D'abord les deux
   mesures, puis l'import et la récolte, puis le format et les trois greffons.
   - **MESURÉ (29 septembre 2026) — le témoin EST d'un seul tenant** : l'aminci soudé forme UNE
     composante connexe, ses 31 120 triangles. « Tout le reste est un prop » ne prendra donc aucun
     morceau du témoin pour un rocher.
   - **À MOITIÉ MESURÉ — le second objet** : le lecteur ne prenait que le premier maillage (§4, le faux
     travail d'artiste) ; il lit désormais TOUS les objets et les tranche comme du terrain, en le disant.
     Un rocher rangé à part revient donc aujourd'hui en demi-coques : c'est exactement ce que ce point
     doit remplacer. Reste à mesurer qu'un rocher à cheval sur une coupe s'isole par la connexité.
10. **Ce qu'il faut pour vendre** : une démo, une page, une licence. OUVERT.
    ⚠ **ET LA TEXTURE : LE TÉMOIN NE S'ENVOIE PAS À TRIPO** ni à aucun textureur automatique (§3) —
    à écrire sur la page avant la vente. ⚠ Et pas seulement pour la texture : sa géométrie remaillée ouvre
    une fente à chaque joint du monde peint (§4, MESURÉ).
    ⚠ **ET UNE LIMITE À ÉCRIRE AVANT LA VENTE, PAS APRÈS** : un atlas ne porte pas d'unicité
    (§3). Une clé vue 81 fois porte 81 exemplaires, pas 81 emplacements — un détail sculpté à UN
    endroit réapparaît ailleurs. L'acheteur doit le lire avant d'acheter, jamais le découvrir.
    (Depuis le 4 octobre 2026, les VARIANTES VOULUES atténuent la répétition — jusqu'à dix sculptures par tuile, mêlées
    ou choisies — sans la supprimer : la limite reste à écrire, avec elles comme réponse.)
    ⚠ **MARCHÉ — MESURÉ À MOITIÉ, PROPOSÉ pour le reste** : l'Asset Library officielle de Godot
    est GRATUITE uniquement (un registre de liens, elle n'encaisse rien), donc un addon payant
    passe par itch.io ou Gumroad. ⚠ **La vraie différence n'est pas la commission, c'est la
    DÉCOUVERTE** : l'Asset Store Unity prend 30 % mais met l'outil devant des gens qui le
    cherchent ; sur itch on amène son public soi-même. ~~**OUVERT** — le nouveau « Godot Asset
    Store » accepte-t-il le payant ?~~ **RELEVÉ LE 3 OCTOBRE 2026 : PAS ENCORE** (état de mai 2026) —
    le store officiel (store.godotengine.org) existe, s'intègre à l'éditeur dès 4.7, mais le payant
    viendra d'abord pour des créateurs choisis, puis pour tous. Sans effet sur le greffon GRATUIT, qui
    peut y aller dès maintenant. (Le site tiers « Godot Marketplace » ferme le 30 octobre 2026.)
    **LA VENTE ET LA PROMOTION — RECHERCHÉ LE 3 OCTOBRE 2026, À LA DEMANDE DE JORDAN** (« ça change très
    vite »). ⚠ **CES FAITS VIENNENT SURTOUT DE COMPARATIFS ET DE BLOGS DATÉS 2026** : à relire sur les pages
    officielles avant d'agir, et à reprendre si ce point attend plus de quelques mois. ⚠ Le document Claude
    « MarchingBlocks — stratégie de lancement » (§0) date du 2 octobre et n'a PAS été repris ici.
    - **DÉCIDÉ PAR DÉLÉGATION (Jordan, 3 octobre 2026 : « décide de ce qu'on va faire, je n'y connais rien en
      commercialisation »)** — tout ce qui suit marqué PROPOSÉ l'est désormais, et le DÉTAIL vit dans le document
      de stratégie (https://claude.ai/artifact/94nRFCsyzdAaE5ApoMz9Y2, section « Les décisions du 3 octobre
      2026 »), mis à jour le même jour : 39 € en accès anticipé, −20 % la semaine du lancement ; 60 € à la 1.0
      SEULEMENT si l'outil a fait ses preuves (avis, démos changées en achats — tranché en avril 2027 sur les
      chiffres, sinon on reste à 39 €), la 1.0 offerte aux premiers acheteurs ;
      site + Steam le même jour ; Paddle ; clé signée nominative, hors ligne, SANS limite de machines (le
      document disait 3) ; greffons gratuits sur les quatre boutiques ; démo ; **le splash et l'icône, issus de
      Tripo, DÉCLARÉS sur Steam (Jordan, 3 octobre 2026 : « je déclare les images »)** ; X et Bluesky à la main, deux
      posts par semaine ; démarchage préparé par Claude, envoyé par Jordan, cinq par semaine dès le 21 décembre ;
      aucune publicité au lancement ; aucun outil qui poste ou répond à notre place. Le calendrier ne bouge pas.
      Le Next Fest semble réservé aux JEUX (les règles ne parlent que de jeux) : on ne compte pas dessus.
    - **L'ICÔNE VIENT AUSSI DE TRIPO** : avec le splash, déclarée dans le formulaire d'IA de Steam (contenu
      pré-généré, page et marketing) — DÉCIDÉ (Jordan, 3 octobre 2026), plutôt que les refaire.
    - ⚠ **IL N'Y A PAS DE SOCIÉTÉ (Jordan, 3 octobre 2026)** : « SpannerGames Inc. » (§0, propriétés de l'exe, barre
      de titre) annonçait une société américaine ou canadienne qui n'existe pas. **« Inc. » RETIRÉ (Jordan, 3 octobre
      2026)** : `export_presets.cfg` (société, copyright), la barre de titre (`editor.gd`), `composer_splash.py` (son
      nom par défaut — ⚠ À RECOPIER dans les autres logiciels de Jordan, la signature ne doit pas diverger), et
      `MARQUE/splash.png` recomposé (fond Tripo remis en 1920 × 1080, vu à l'image). **PROPOSÉ** : une
      micro-entreprise au nom de Jordan, « SpannerGames » en nom commercial ; Steamworks et Paddle demandent le
      SIRET : c'est la première étape des comptes.
      **VENTE OU PRESTATION ? RECHERCHÉ, PAS TRANCHÉ PAR UN TEXTE.** Le BOFiP ne nomme pas les logiciels : la
      première catégorie (203 100 € en 2026) est le commerce de « marchandises, objets, fournitures et denrées »,
      tout le reste va à la seconde (83 600 €). Une licence n'est ni un objet ni une marchandise, et pour la TVA la
      concession d'une licence de logiciel EST une prestation de services. Des guides disent « vente », d'autres
      « prestation » (21,2 % de cotisations). **PROPOSÉ** : déclarer en PRESTATION DE SERVICES BIC (la lecture
      prudente — se tromper dans l'autre sens, c'est un redressement) et poser la question écrite à l'URSSAF à la
      création ; la différence ne compte qu'au-delà de 83 600 € par an.
    - **DÉCIDÉ (Jordan, 3 octobre 2026) — LE LOGICIEL SE TÉLÉCHARGE SUR NOTRE SITE** : « pas de site si on y
      télécharge pas le soft, c'est contre-productif ». **PROPOSÉ, le comment** : le paiement s'ouvre en
      surcouche sur notre page, tenu par un *merchant of record* (vendeur légal : TVA par pays, factures,
      fraude, remboursements) ; son webhook inscrit l'acheteur ; « My downloads » par lien magique envoyé à
      l'e-mail (des connexions Google / Discord / GitHub en option) ; le fichier sert depuis un stockage
      (Cloudflare R2) par lien signé de quelques minutes ; la même page porte les versions de l'accès anticipé.
      Et une clé de licence SIGNÉE (Ed25519, clé publique dans l'exe), vérifiée HORS LIGNE. ⚠ Comme le
      chiffrement (§0), rien de cela n'empêche de copier l'exe : ça rend l'achat honnête simple.
    - **LE VENDEUR LÉGAL** : **Paddle**, 5 % + 0,50 $ tout compris, stable — **PROPOSÉ**. ⚠ **PAS LEMON
      SQUEEZY** : racheté par Stripe (2024), qui ouvre en février 2026 *Stripe Managed Payments* (préversion,
      vendeurs de l'UE acceptés, ~6,4 % + 0,30 $, 8 %+ à l'international), bâti par son équipe et annoncé comme
      son « avenir » — y commencer, c'est s'imposer une migration. À regarder quand il sortira de préversion.
    - **STEAM** (la page du 21 décembre, §0) : des clés Steam peuvent aller aux acheteurs directs — prix pas plus
      bas que sur Steam, environ 5 000 clés, jamais un commerce de clés sans offre sur Steam. Les Next Fest sont en
      février, juin, octobre (celui de février 2027 tombe APRÈS le lancement du 12 janvier : à reconsidérer).
      ⚠ **L'IA SE DÉCLARE SUR STEAM, PAGE ET MARKETING COMPRIS** (règles du 17 janvier 2026 : les outils de
      développement — le code écrit avec Claude — sont exemptés ; ce que le joueur VOIT ne l'est pas). **LE SPLASH
      L'EST** : sa moitié droite a été reprise dans Tripo (§0). À déclarer, ou à refaire.
    - **X (TWITTER)** : ⚠ **LES THREADS NE SONT PLUS LE FORMAT QUI PORTE** — l'algorithme de 2026 préfère un long
      post unique ; un lien dans le post coûte 30 à 50 % de portée (bien plus, selon des essais) : le lien va en
      PREMIÈRE RÉPONSE ; une réponse pèse ~150 fois un like, donc on écrit pour faire répondre. Ce qui marche pour
      les outils de jeu : de courts GIF d'UN geste satisfaisant (une falaise peinte, une cascade qui se forme),
      #ScreenshotSaturday, les ratés montrés. ⚠ **LES BOTS DE RÉPONSE SONT INTERDITS** (avril 2026 : réponses
      automatiques sur mots-clés bannies, réponses par API seulement si l'on est mentionné ; 42 000 comptes
      supprimés) — les « outils qui s'annoncent sur Twitter » pour répondre à notre place font perdre le compte.
      Permis : programmer, rédiger avec l'IA, publier soi-même. **PROPOSÉ** : pousser de 100 à 200 $ les seuls
      posts qui ont déjà pris seuls (« paid organic »).
    - **DÉMARCHER AVEC CLAUDE** : des agents (Claude Code et ses « skills ») trouvent des contacts, écrivent et
      envoient. ⚠ **EN FRANCE** : le B2B sans consentement est permis si le message touche le MÉTIER du
      destinataire, expéditeur identifié, désinscription simple traitée sous 10 jours ; le profilage par l'IA est un
      traitement RGPD ; **les pixels d'ouverture exigent un consentement depuis la recommandation CNIL du 12 mars
      2026**. Les chiffres de réponse annoncés (15 à 25 %) viennent des vendeurs de ces outils. **PROPOSÉ** : Claude
      pour PRÉPARER — la liste des chaînes YouTube Godot / Unity / Unreal, des newsletters gamedev, des studios qui
      font du voxel ou de la tuile, un message propre à chacun — et Jordan qui ENVOIE, peu et bien, sans pixel. Un
      envoi automatique en masse vers des créateurs, c'est le spam qui fait fermer les portes du §10.
    - **LES CRÉATEURS** : Keymailer (55 000 créateurs inscrits, gratuit jusqu'à 10 demandes par mois) et Lurkit
      (campagnes payées, ~89 $/mois, remise indé) — conçus pour des JEUX ; un outil de gamedev a peut-être plus à
      gagner à écrire directement aux chaînes de tutoriels Godot / Unity / Unreal (OUVERT).
    - **REDDIT** : r/godot accepte l'autopromotion avec mesure, r/gamedev la restreint ; l'IA pour aider à écrire
      est admise sur le site, chaque sous-forum peut l'interdire ; la règle 90/10 (contribuer bien plus que
      promouvoir) et dire qui l'on est.
