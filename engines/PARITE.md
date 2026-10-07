# La parité des greffons — le contrat de la 0.9.0

> **DÉCIDÉ (Jordan, 7 octobre 2026)** : « parité complète des greffons à la 0.9.0 » — toute la LISTE DES GREFFONS À
> FAIRE (`CLAUDE.md`, §0) livrée dans Godot, Unity et Unreal, chacune avec ses cas d'épreuve communs.
> Ce document est la **première étape**, celle dont dépendent les trois moteurs : **ce que le logiciel exporte**, et
> **les cas que chaque greffon doit passer**. Il est écrit pour l'agent (ou la personne) qui portera UN moteur.
> Français pour l'équipe ; les clés, les fichiers et les cas sont en anglais (ils partent chez les acheteurs).

## 0. Ce qui fait foi, et comment on le garde

- **La règle est écrite UNE fois, en GDScript, dans le cœur** (`addons/marchingblocks_core/`). Les cas sont CALCULÉS par
  elle (`addons/marchingblocks_core/epreuve_parite.gd`) et écrits par
  `godot --headless --path <dépôt> --script res://DEV_TOOLS/generer_cas_d_epreuve.gd` dans **les trois greffons** :
  `addons/marchingblocks_paint/`, `engines/unity/com.marchingblocks.paint/Tests/` (chaque fichier a son `.meta` à GUID
  fixe), `engines/unreal/MarchingBlocksPaint/Tests/`.
- **La garde** : `DEV_TOOLS/test_parite.gd` rougit si un fichier livré n'est plus ce que le cœur produit, si les cas
  n'exercent plus ce qu'ils nomment, ou si une **seconde implémentation écrite depuis le seul `rules_text`** (dans le
  test) ne rend plus les mêmes réponses — la preuve que le texte suffit pour la plupart des règles.
- **Si une règle du cœur change** : on régénère, on relance `test_parite`, et les trois bancs des greffons. On ne fige
  jamais le GDScript pour faire plaisir à un banc.
- **Un greffon ne charge RIEN du cœur** (le cœur contient ce qui se vend). Il réimplémente depuis le texte, et passe les
  cas à 100 %.

### Les cinq fichiers (282 cas)

| Fichier | Cas | Sortes |
| --- | --- | --- |
| `transitions_conformance.json` | 93 | `blend` 65, `settings` 4, `table` 4, `cell_texture` 1, `read` 19 |
| `animation_conformance.json` | 43 | `frame` 14, `pulse` 8, `phase` 7, `scroll` 4, `read` 10 |
| `foliage_conformance.json` | 59 | `check` 23, `brush` 4, `place` 3, `wind_data` 2, `sway` 9, `ground_of_cells` 6, `read` 12 |
| `water_conformance.json` | 25 | `water_world` 11, `river_width` 5, `surface_depth` 2, `read` 7 |
| `editing_conformance.json` | 62 | `extrude` 39, `shrink_edge` 6, `widen_flat` 3, `select_brush` 4, `room_from_selection` 10 |
| `water_mesh_conformance.json` (7 octobre 2026, §12) | 14 | `water_mesh` 14 — la nappe recalculée, en ensemble de triangles |

Chaque fichier : `format`, `version` (1), `rules_text` (la règle, ligne à ligne — **à lire en entier**), parfois
`limits` / `constants` / `settings`, des mondes nommés (`world_cells`, `worlds`, `models`), et `cases` :
`{name, kind, input, expected}`. **Comparer** : entiers exacts ; réels à 1e-6 près (1e-5 après un sinus / cosinus) ;
ensembles de cases triés x, puis y, puis z ; un refus de lecture s'écrit `{"error": true}` (la raison est libre).

⚠ **Les fichiers existants ne changent pas** : `conformance.json`, `world_conformance.json`, `tools_conformance.json`
sont identiques à l'octet (les bancs .NET et C++ refusent une sorte inconnue : les nouvelles sortes sont dans des
fichiers à part). Un banc qui veut les nouveaux cas les lit en plus.

### Ce que le logiciel exporte désormais (le format, version inchangée)

- `world.json` gagne deux clés **FACULTATIVES**, comme `water` : `transitions` et `foliage`. Un monde exporté d'avant les
  lit absentes (rien ne se mêle, aucun plant) — **la version reste 1**, et une clé que ces règles ne décrivent pas est
  ignorée. Le dossier `.mbworld/` gagne `transitions/representative_<i>.png` et `foliage/<modèle>.glb`.
- `tiles.glb` (dans chaque `.mbset/`) : l'animation d'un matériau est dans `extras.mb_animation`, **au format qui part**
  (anglais, `format: "marchingblocks-animation"`, `version: 1`) ; **ses images voyagent** dans `<jeu>.mbset/animation/`,
  nommées relativement au `.mbset`. `tileset.json` ne change pas.
- Les règles sont aussi dans les `README.txt` des dossiers exportés (`FormatMonde.regle_transitions()`,
  `regle_feuillage()`, `regle_eau()`, `Anim.regle_animation()`).

## 1. Ce qui est commun aux trois moteurs (à faire d'abord, dans cet ordre)

1. **Les lecteurs** : les clés `water`, `transitions`, `foliage` de `world.json` (cas `read` de trois fichiers), et
   `mb_animation` (cas `read` d'`animation_conformance.json`). Risque faible : même style que `MBWorldFile`.
   ⚠ **`mb_animation` est dans les extras d'un matériau glTF** : Godot les met en méta `extras` (mesuré dans l'appli) ;
   **glTFast (Unity) et l'importeur d'Unreal ne les exposent pas de façon sûre — NON MESURÉ** : le plus sûr est de lire
   le bloc JSON de `tiles.glb` soi-même (en-tête de 12 octets, puis la longueur et le type du premier bloc, puis le
   JSON) et d'associer par le NOM du matériau (plusieurs matériaux du fichier peuvent porter le même nom : ce sont des
   copies du même — même animation).
2. **Les règles pures** (C# pur dans le paquet Unity, C++ standard dans `MBCore` sous les contraintes d'Unreal), chacune
   avec son banc : `editing` (le plus simple, prolonge `MBTools` / `MBShapes`), `animation` (des formules), `transitions`
   (la fonction du fondu, `table`, `settings`), `foliage` (`check`, `brush`, `place`, `wind_data`, `sway`,
   `ground_of_cells`), puis `water` (la plus longue — voir §2).
3. **Le rendu** (shaders, matériaux) — chaque moteur réécrit le sien **sur les mêmes données** ; aucun cas ne le garde
   (un shader ne se juge qu'à l'image, avec fenêtre). C'est là qu'est le risque (§9).
4. **L'UI des éditeurs** (boutons, touches, molette) : jugée souris en main.

⚠ **Le repère** : toutes les règles parlent en **espace du FORMAT** (droitier, +Y en haut, 1 = une case). Un moteur
convertit par le repère MESURÉ `F` (le nœud `mb_frame`, `conformance.json`) : une position monde `P` du moteur est
`F⁻¹(P / taille de case)` en espace du format. **Un shader qui lit une texture 3D des cases, une phase ou un vent doit
faire cette conversion** — Unity (miroir X) et Unreal (Z en haut, centimètres) inversent ou échangent des axes.

## 2. Les fluides — lecture, règle et MAILLAGE : cas (le maillage : §12) ; presets : pas de cas

- **Lire** : la clé `water` (`FormatMonde.lire_eau` ; `regle_eau()` dans `rules_text`) — par couche d'eau `name`,
  `visible`, `look` (une SUGGESTION : `stylized`, `clear`, `reflective`, `lava`, `swamp`, `acid` ; un aspect inconnu est
  accepté), `mesh` (le `.glb` de la nappe CUITE, ou null), `sources`. La nappe porte le contrat : `COLOR_0` r, g =
  courant ; b = genre (0 dormant, 0,5 rivière, 0,75 écume, 1 cascade) ; a = profondeur / 8 (dormant, rivière) ou
  quantité d'écume (cascade, écume) ; `NORMAL` la forme (la nappe courbe des cascades) ; `TEXCOORD_0`.
- **Poser** : chaque nappe `water/<nom>.glb` avec un matériau choisi par l'artiste ; **les six presets réécrits dans
  chaque moteur** (la référence : `addons/marchingblocks_core/eau_presets.gd` — le tronc commun, `motif_cascade`,
  `pente_micro`, le clapot qui soulève AUSSI les cascades) ; dire à l'artiste qu'ils ne sont pas obligatoires.
  Pour Godot, les shaders peuvent être une COPIE générée de `eau_presets.gd` (gardée par un test de péremption, comme
  les icônes) — jamais une copie à la main.
- **Recalculer l'eau quand on peint** : la règle `fluides.gd` (cas `water_world` : corps par source — mer, lac, rivière
  —, refus `in_matter` / `in_water` / `one_sea_only`, fins `leaves` / `joins` / `closed`, cours `flow` / `fall` / `lake`,
  la mer) ; `river_width` (`FL.sources_en_largeur`) ; `surface_depth` (surface, profondeur, pour le contrat). La règle
  est résumée dans `rules_text`, mais **la référence est `fluides.gd` ligne à ligne** : l'ordre des voisins (+x, −x, +z,
  −z, bas, haut) et le tas départagé par l'ordre d'insertion décident de tout. ⚠ La mer d'Unreal peut reprendre
  `gdextension/src/noyau/ocean.h` (déjà en C++ standard, déjà éprouvé contre le GDScript par `test_natif`).
- **LE MAILLAGE DE L'EAU A SES CAS DEPUIS LE 7 OCTOBRE 2026** (`water_mesh_conformance.json`, **§12**) : plats sans
  jonction en T, nappe sous un étage flottant, cascades en volume, remous, source, un seul océan, largeur de rivière. Un
  greffon qui recalcule l'eau refait aussi la nappe — ~1 000 lignes à réécrire, désormais jugées par 14 cas et un
  appariement en sac de triangles. (Avant : « les greffons montrent la nappe CUITE et recalculent les CASES » — c'est
  toujours le minimum livré ; §12 dit comment aller au-delà, et à quel coût.)
- **Vérifié (7 octobre 2026)** : l'export de l'eau est complet pour ce qui est décidé (nappes, presets en aspects,
  cascades en volume dans le maillage, un seul océan) ; seule manquait la phrase « un seul océan » dans `regle_eau()`,
  ajoutée.

## 3. La molette — RÈGLE DÉCRITE, PAS DE CAS (c'est une règle d'interface)

- La règle (`app/editor.gd`, `_molette_du_monde`) est écrite dans `editing_conformance.json` (`rules_text`, « THE
  MOUSE WHEEL ») : la molette seule = zoom, sauf PENDANT UN GESTE (hauteur d'un Rect / d'une Box, étages d'une salle,
  hauteur d'un collage) ; Ctrl = l'étage ; Ctrl + Maj = le pas de l'escalier ; avec une SÉLECTION et un outil de
  sélection : Maj = Extend selection ↑ ↓, Alt ↑ = `widen_flat`, Alt ↓ = `shrink_edge` ; Room : Alt = étages, Maj = monte /
  descend ; autres formes : Alt = taille, Maj = longueur ; Add / Dig / Select : Alt = taille du pinceau, Maj = forme
  suivante. F cadre toute la matière.
- **Les effets sur les cases ont des cas** (`widen_flat`, `shrink_edge`, `extrude` mode `extend`) ; l'aiguillage lui-même
  (quel réglage pour quel modificateur) se juge à la main dans chaque éditeur.
- ⚠ **CE QUI NE PEUT PAS ÊTRE TENU TEL QUEL** : « des panneaux où la molette ne règle rien » est une règle de l'appli sur
  SES panneaux ; l'inspecteur de Unity et le panneau Details d'Unreal ne sont pas à nous — elle ne s'applique qu'aux
  barres des greffons. Et chaque moteur a déjà ses propres molettes dans la vue (Unity : zoom ; Unreal : vitesse de la
  caméra avec le clic droit) : on ne prend la molette QUE quand notre mode est actif et qu'un modificateur ou un geste le
  demande, sinon on la laisse au moteur. Alt + molette sous Windows : jamais mesuré, ni dans l'appli ni ailleurs.

## 4. Les transitions entre couches — FAIT (export, lecture, règle, cas) ; rendu à écrire

- **Lire** `transitions` : `pairs` [{`a` < `b` (indices de couches), `active`, `a_covers_b`, `b_covers_a`}],
  `representatives` (un par couche : `image` relative ou null, `color` [r, g, b, a] qui multiplie l'image TELLE QUELLE,
  `scale` ≥ 0,01, `roughness`), `choices` (x y z L à plat). Réglages : `softness`, `reach`, `irregularity`, `grain`,
  `fills_hollows` (absent → défaut, hors bornes → borné). Seules les couches 0 à 14 se mêlent.
- **L'export** convertit les ids de l'écran en INDICES de `layers` (une paire « 3|7 » dont 7 est avant 3 échange ses
  directions — gardé par `test_parite`), et part avec des représentants **RÉSOLUS** : le défaut « le matériau le plus
  porté par les faces du témoin » demande le témoin, que le greffon n'a pas.
- **La règle** (`Transitions.melange`, et le `SHADER` qui la dit à la lettre) : `blend` — au point p de la tuile du
  sommet v, les huit cases, la propriétaire (plus petit rang), l'autre (la plus grande part, départagée par l'ordre des
  coins), s, les votes du pinceau, `visible()` dont le décalage est nul aux deux bouts, alpha. **Le sommet v est celui
  de la TUILE**, jamais déduit du point (sur un joint, le point appartient à deux tuiles — vu à l'image dans l'appli).
- **Le rendu, par moteur** : une texture 3D d'un octet par case (l'empaquetage RECOMMANDÉ, cas `cell_texture`), la
  table des réglages, les représentants projetés en boîte, posés PAR-DESSUS les matériaux des tuiles. Godot : le même
  `next_pass` que l'appli (⚠ dans une MultiMesh, la `MODEL_MATRIX` de `fragment()` n'a pas la pose de l'instance : le
  sommet se lit dans `vertex()`). Unity et Unreal : voir §9.
- ⚠ **Écart connu, non tranché** : le GDScript emploie UN bruit n pour les deux directions ; le shader en tire un par
  direction (grain de chaque direction). Les cas donnent n ; un moteur suit le shader pour l'image.
- **Les cas** : 65 `blend` (17 écrits pour un point de la règle chacun, 48 générés), `settings`, `table`, `cell_texture`,
  19 `read` (2 acceptés, 17 refus).

## 5. Les demandes du 3 octobre — FAIT (règles et cas) ; UI à écrire

- **Select des cases VIDES** : une case à cocher sous le pinceau Select (« Select empty cells too ») — cas
  `select_brush` (`Outils.selectionner_au_pinceau`, sortie de `vue.gd` pour l'être).
- **Extend selection ↑ ↓** : un bouton = `extrude` en mode `extend` (cas `extrude`). ⚠ « selection » dans le nom : l'ancien
  « Extend up » posait de la matière.
- **Room from selection** : `FS.salle_depuis`, à réécrire en C# et C++ (les greffons ont déjà `Shapes.room` et la
  réparation des contacts diagonaux) — cas `room_from_selection` (réussie, montée / descendue, dans la roche, base sur
  deux hauteurs, carrés par un coin réparés, étages bornés, `too_small`, `empty`).
- **La largeur d'une rivière à la pose** : seulement si un greffon pose de l'eau — cas `river_width`.

## 6. Extrude, et Shrink — FAIT (règles et cas) ; UI à écrire

- **`Etages.extruder`** (haut / bas / face × poser / étendre / décaler), cas `extrude` (39 : les neuf paires, sans
  sélection — la matière de l'étage —, avec sélection mêlée de vide, sur le devant d'un mur épais, en l'air — un sens
  nul). Maj + clic = étendre, Alt + clic = décaler ; l'étage suit `step.y`.
- **`retrecir_bord`** remplace l'ancien `retrecir` (cas `shrink_edge`).
- ⚠ **`tools_conformance.json` garde `extrude_up`, `extrude_down` et `shrink` (l'ancien)** tant que les trois greffons
  les emploient : les retirer du fichier ferait rougir leurs bancs. Quand les TROIS ont migré : retirer les boutons
  Extrude ↑ ↓ des opérations de sélection, puis retirer ces sortes de `epreuve_outils.gd` et l'ancien `retrecir`
  d'`outils.gd`, en une fois, bancs relancés.

## 7. Les textures animées — FAIT (export des images, format, règle, cas) ; shaders à écrire

- **Lire** `extras.mb_animation` d'un matériau de `tiles.glb` (voir §1 pour le moyen) : canaux `albedo`, `normal`, `orm`
  (r AO, g rugosité, b métal), `emission` ; pistes `scroll` {u, v, synced}, `frames` {images, fps, ping_pong, synced},
  `pulse` {frequency, minimum, synced} (l'émission seule). Les images : `animation/<fichier>` relatives au `.mbset`,
  dans l'ordre. Le matériau lui-même montre l'image 0 : un moteur qui ignore l'animation montre juste.
- **La règle** : `image_au_temps`, `pulsation_au_temps`, `phase_de`, `defilement_au_temps` (sortie du shader pour être
  écrite). Le temps est GLOBAL (une horloge pour tous les matériaux). La phase vient de l'ORIGINE de la tuile en espace
  du format (v + piece_offset) — **pas de la position moteur** (repère, centimètres).
- ⚠ **MESURÉ (`test_parite`)** : `phase_de` calculée en flottants 32 bits (ce que fait un shader) s'écarte jusqu'à
  **0,025** de l'attendu double, sur les origines des cas (le produit avant le dernier `fract` dépasse 10⁴). Les cas
  `phase` sont en double : un greffon qui calcule la phase sur le CPU (par instance) les passe ; un shader qui la
  calcule lui-même ne les passera pas au millième — l'appli elle-même est dans ce cas (son shader 32 bits). L'image d'une
  piste décalée peut donc différer d'une image entre l'appli et un moteur sur certaines tuiles : accepté, à dire.
- **Le rendu** : un tableau de textures par piste d'images (Godot `Texture2DArray`, Unity `Texture2DArray`, Unreal
  `UTexture2DArray`), un shader par moteur. Godot peut reprendre le `SHADER` d'`animation_materiau.gd` (copie générée).
  Les UV tournent avec la tuile (un défilement en u suit le quart de tour de chaque copie) — c'est voulu.

## 8. Le feuillage — FAIT (export, lecture, règle, cas) ; rendu et vent à écrire

- **Lire** `foliage` : `models` [{`id`, `name`, `mesh` (`foliage/<nom>.glb`, copié dans le monde ; null si le fichier
  manquait chez l'auteur — l'export le dit), `ground_offset`, `scale`, `scale_random`, `footprint`, `height`, `wind`}],
  `plants` (7 nombres : modèle, x, y, z au SOL, lacet, échelle du plant, mode 0 en l'air / 1 planté). Un plant d'un
  modèle inconnu refuse le fichier.
- **Poser** : T = translate(p + (0, ground_offset·s, 0)) · rotY(lacet) · scale(s), s = scale du modèle × celle du plant
  (cas `place`).
- **Planter dans l'éditeur** (si le greffon plante) : `check` (les trois modes `air`, `free`, `overflow` ; refus
  `in_matter`, `too_steep`, `in_water`, `at_edge`, `under_matter`, `too_close`, `already_there`) et `brush` (le pinceau
  SANS hasard : ses candidats sont donnés dans l'ordre ; aucun moteur ne reproduit le générateur de Godot — l'appli tire
  a, d, puis le sol, puis lacet et échelle). Le sol des cas est le « sol des cases » (`ground_of_cells`) ; sur de vraies
  tuiles, chaque moteur cherche le sol par un rayon vertical contre SES maillages de tuiles posées.
- **Le vent** (cas `wind_data`, `sway`) : par plant (sol, hauteur au-dessus du sol, phase, amplitude), le balancement en
  espace MONDE ∝ h², deux rafales, le frisson le long de la normale (`FE.balancement`, ligne à ligne du shader).
  ⚠ En espace monde du FORMAT : convertir par F (§1).
- ⚠ **L'animation propre du fichier (squelette) n'est pas jouée** — ni dans l'appli (OUVERT), ni dans les greffons.
- ⚠ **Le matériau du vent** : l'appli REPREND chaque matériau du `.glb` dans son shader du vent (couleur, image, alpha,
  rugosité, métal, normale). Dans Unity et Unreal, les matériaux importés appartiennent à l'importeur (glTFast, Interchange) :
  ajouter un déplacement de sommets (Unreal : World Position Offset ; Unity : un shader à soi) oblige à remplacer ces
  matériaux par les nôtres en recopiant leurs paramètres — voir §9.

## 9. Ce qui ne peut pas être fait tel quel, et les risques — DIT, PAS INVENTÉ

- **Unity — un passage par-dessus les matériaux n'existe pas** (pas de `next_pass`). Ajouter un matériau de plus à un
  `MeshRenderer` ne redessine que le DERNIER sous-maillage ; les tuiles en ont plusieurs. Il faut soit un second rendu
  de la géométrie (un renderer de plus par tuile, ou `Graphics.RenderMeshInstanced` / une Renderer Feature d'URP), soit
  un shader à soi qui remplace celui des tuiles. **Et trois pipelines** (Built-in, URP, HDRP) ont trois langages de
  shader : à trancher avec Jordan (proposé : URP d'abord, Built-in ensuite, HDRP non promis). C'est le PLUS RISQUÉ de la
  parité (transitions, animation, vent, presets d'eau : quatre shaders × pipelines).
- **Unreal — les matériaux sont des ASSETS binaires** (`.uasset`), pas du texte : un agent ne les écrit pas comme un
  `.shader`. Deux voies : les construire par script Python d'éditeur (`MaterialEditingLibrary`, déjà mené en
  `UnrealEditor-Cmd -ExecutePythonScript` pour l'import du monde) avec des nœuds Custom HLSL, ou les faire à la main par
  Jordan. L'« Overlay Material » (UE 5.1+) pose un matériau PAR-DESSUS tout un maillage — sur les
  `InstancedStaticMeshComponent`, NON MESURÉ ; « Object Position » d'une instance dans un matériau d'ISM : NON MESURÉ
  (le même piège que la `MODEL_MATRIX` d'une MultiMesh dans Godot). La texture 3D : `UVolumeTexture` (R8), à mesurer.
- **Lire les extras glTF** : seulement Godot est mesuré (§1). Lire le JSON de `tiles.glb` soi-même lève le doute.
- **Recalculer la NAPPE d'eau** : ses cas existent (§12) ; le COÛT est le risque — une grande mer en GDScript se compte
  en secondes (mesuré, §12) : jamais pendant un geste.
- **La molette sur les panneaux du moteur** : pas à nous (§3).
- **Une phase d'animation calculée en 32 bits** diffère jusqu'à 0,025 (§7).
- **Rien de ce qui se VOIT n'est gardé par ces cas** : chaque rendu se juge à l'image, avec fenêtre, dans chaque moteur
  (« le headless ne rend rien », charte §6).

## 10. Hors de ce contrat

- **L'API DE JEU** (entrée de la liste, §0) : elle repose sur `mbcore::World` (le cœur C++) et aura ses propres cas ;
  pas traitée ici.
- **Le cœur C++ dans les greffons** (Godot embarque la GDExtension, Unreal fusionne `MBCore`, Unity passe au natif) :
  l'étape (4) du cœur, indépendante de ces cas — mais une règle portée dans `gdextension/src/noyau/` (l'océan, demain
  l'eau) peut servir directement à Unreal.

## 11. Découpage conseillé du travail des trois agents moteurs

- **Ce qui est commun, ce sont les CAS, pas du code** : rien ne se partage entre GDScript, C# et C++ (sauf, pour Unreal,
  ce qui est déjà dans `gdextension/src/noyau/`). Chaque agent travaille dans SA langue, en parallèle des deux autres, et
  ajoute à son banc (`conformance-runner` .NET, `core-runner` C++, `test_greffon_peinture` pour Godot) la lecture des
  cinq fichiers — un banc qui rencontre une sorte inconnue rougit (il ne saute rien en silence).
- **Une seule règle change à la fois** : si un agent trouve une règle ambiguë ou fausse, il ne la corrige pas dans son
  moteur — il la remonte, on corrige le GDScript, on régénère, et les trois bancs la reçoivent ensemble.
- **Ordre, par moteur** : (1) lecteurs (`read` des trois clés, `mb_animation` par le JSON du `.glb`) ; (2) `editing`
  (Extrude, Shrink, Widen, Select vides, Room from selection) + leurs boutons et Maj / Alt — c'est aussi la molette ;
  (3) `animation` (règle) puis son shader ; (4) `foliage` (pose + vent) puis son rendu ; (5) `transitions` (règle) puis
  son rendu ; (6) `water` (règle des cases), puis les six presets sur la nappe cuite.
- **Le plus risqué** : le rendu Unity (pipelines, pas de passage par-dessus) et les matériaux Unreal (assets, instances) —
  à mesurer TÔT sur une seule chose (le fondu des transitions) avant de tout écrire. Ensuite la règle de l'eau (longue,
  sensible à l'ordre) — l'Unreal peut partir du `noyau/ocean.h`.
- **Godot est le plus court** : mêmes shaders que l'appli (copies générées et gardées), MultiMesh pour le feuillage,
  `next_pass` pour les transitions.

## 12. Le maillage de l'eau — la nappe recalculée (FAIT LE 7 OCTOBRE 2026 : cas, garde, budget ; à écrire dans chaque moteur)

> Les trois greffons montrent la nappe CUITE (six presets) et recalculent les CASES d'eau ; ils ne refaisaient pas la
> NAPPE en peignant, faute de cas pour `eau_maillage.gd`. Ce paragraphe les donne. Il est écrit pour les trois agents
> qui porteront le mailleur — un par moteur.

### Ce qui fait foi

- **`addons/marchingblocks_core/eau_maillage.gd`**, ligne à ligne ; ses cas : **`water_mesh_conformance.json`** (14), écrit
  par `epreuve_parite.gd` (`_maillage_eau`) dans les trois greffons (`.meta` à GUID fixe pour Unity). Le résumé de la règle
  est dans `rules_text` (« THE WATER MESH ») ; les constantes dans `constants` ; les tolérances dans `tolerances`.
- **Ce que les cas décrivent, ce sont les TABLEAUX** (`EauMaillage.tableaux_du_maillage`, sorti de `maillage` pour
  l'être), pas l'`ArrayMesh` : celui de Godot range les couleurs sur 8 bits (0,5 relu 0,498039) et les normales en
  octaèdre (une normale (0, 1, 0) relue avec z = −1,5e−5) — MESURÉ au premier essai, la première version des cas en
  était faussée. Un greffon compare ce qu'il CALCULE, avant de le confier au moteur.
- ⚠ **`eau_poser_les_plats`** (le cœur C++, `gdextension/src/appli/eau.cpp`) est PRIVÉ : il ne part pas dans les greffons.
  Les cas sont calculés avec lui et relus sans lui (`MB_NATIF=0`) : mêmes triangles (`test_parite` vert dans les deux).

### L'entrée d'un cas

`{world, bodies}` : un monde nommé (`worlds`, cases pleines de TOUTES les couches) et les corps d'UNE couche d'eau, **au
format de sortie des `water_world`** (`kind`, `error`, `level`, `end`, `water`, `lakes`, `course`). Le mailleur se teste
donc SANS la règle de l'eau ; dans le greffon, il prend la sortie de sa propre règle (déjà jugée par
`water_conformance.json`). La boîte est celle des cases pleines grandie d'une case. ⚠ L'appli lit la surface de la mer
sur ses TRONÇONS (`colonnes`, `surface_des_colonnes`) ; un greffon ne les a pas : la mer relue de son eau
(`surface_dessinee`) donne les MÊMES triangles — gardé par `test_parite` sur les trois mers des cas.

### La sortie : un SAC DE TRIANGLES canonique — et pourquoi cette forme

`expected` = `{summary, vertices, triangles}`. Dépliés (`vertices[i]` pour chaque indice), ce sont des triangles de trois
coins `[px, py, pz, nx, ny, nz, r, g, b, a, u, v]`, **dans le sens du format** (anti-horaire vu de l'avant, comme le
`.glb` ; Godot range à l'envers), arrondis au millionième. Les sommets et les indices ne sont qu'un rangement compact
(570 Ko au lieu de 1,6 Mo en triangles à plat).

- **Pourquoi pas les tableaux dans l'ordre** : l'ordre des sommets et des triangles dépend des mémoires, du cœur natif,
  de la manière d'écrire la boucle ; un moteur qui les rend dans un autre ordre dessine exactement la même eau. L'exiger
  ferait réécrire des détails sans valeur, et rougir à tort.
- **Pourquoi pas des invariants seuls** (nombre et aire par genre, pas de jonction en T, hauteur des plats) : MESURÉ, sur
  16 mutations réelles du mailleur, **6 laissent le nombre et l'aire de chaque genre IDENTIQUES** — l'écume des cascades
  linéaire au lieu de e², la lèvre la plus basse gardée quand deux cascades se rejoignent, l'anneau du remous sans ses
  0,02 au-dessus de l'eau, le sens des triangles par la normale du 2e coin, la profondeur des bandes à 0 au lieu de 0,05,
  deux bandes sur une même case. Des invariants seuls les laisseraient passer ; le sac les voit toutes.
- **Le sac est honnête** : la géométrie ET les attributs (le contrat COLOR_0 : courant, genre, profondeur, écume ; la
  normale qui fait le volume des cascades ; les UV qui font couler), sans exiger l'ordre ; la réflexion d'un triangle est
  refusée (le sens fait partie du contrat : faces arrière éliminées). Le `summary` (nombre, aire par genre) n'est qu'un
  diagnostic avant l'appariement.
- **Les flottants** : Godot calcule en double et range en 32 bits (Vector3, Color) ; un C# ou un C++ en double s'écarte
  de ~1e−6. Tolérances : position et uv 1e−4, normale 1e−3 (calculée par différences de points 32 bits), couleur 1e−4.
  **Les seuils du mailleur sont loin** — MESURÉ sur les 14 cas : les 112 triangles jetés (|AB × AC| < 1e−7) ont une aire
  EXACTEMENT nulle (deux coins confondus : le centre d'un disque), le plus petit gardé est à 1,0e−3 ; le sens de chaque
  triangle de grille, tranché par un produit scalaire avec la normale de son premier coin, a une marge d'au moins 0,345.
  Les seuils de `_chutes` et `_travers` comparent des multiples de 0,05 avec 0,01 de marge au moins (raisonné, pas
  mesuré). Un moteur en double ne tranche donc autrement nulle part dans ces cas.

### Comparer (ce que chaque banc écrit, ~60 lignes ; la référence est `_meme_sac` dans `test_parite.gd`)

1. Même nombre de triangles. 2. Ranger ses triangles dans des seaux par centre arrondi au centième. 3. Pour chaque triangle
attendu, chercher dans les 27 seaux voisins un triangle NON ENCORE PRIS égal à l'une de ses trois ROTATIONS (A B C, B C A,
C A B), coin par coin aux tolérances. Un banc qui ne trouve pas dit le triangle (ses trois positions). **La comparaison est
elle-même éprouvée** (`test_parite`) : vraie sur le bassin (1 453 triangles) mélangé, tourné, bruité sous la tolérance ;
fausse sur un coin déplacé de 2e−4, un triangle retourné, un triangle doublé à la place d'un autre, des couleurs sur 8 bits.

### Les 14 cas (ce que chacun exerce, gardé par `test_parite` sur les triangles eux-mêmes)

| Cas | Exerce |
| --- | --- |
| a calm lake in a crater | la nappe d'un lac : 9 cases fusionnées en UN rectangle, débord de 0,45 sous la roche |
| a lake that overflows into a river | le lac d'une rivière, ses bandes, deux cascades |
| a river down the stairs | bandes (courant, profondeur 0,05), trois cascades en volume à bouts libres arrondis, remous, la SOURCE |
| a river three cells wide (river_width 3) | trois cascades d'un même plan raccordées (bouts droits au milieu, z de −0,1 à 3,1) |
| a sea around an island | la mer, ses profondeurs, l'horizon (quatre rectangles jusqu'à ±2 000), sans jonction en T |
| one sea only | la seconde source refusée ne dessine RIEN (mêmes triangles que la mer seule) |
| a river joins the sea, in the sea's layer / in a layer of its own | le remous sur la nappe de la mer ; la même rivière avec ou sans la mer |
| the sea under a floating slab | la nappe passe sous l'étage flottant (1,5 ; 2,7 ; 1,5) |
| a lake under the ceiling of a closed cave | la nappe d'un lac sous un plafond, à niveau + 0,7 |
| a waterfall into a basin it fills | la cascade de quatre cases : au-delà de 0,35 devant le plan, rentrée à 0,4 dans la roche, écume 0 → 1, anneau à 1,72 sur la nappe du bassin, puis une seconde cascade au bord du monde |
| a sea above the whole world | la hauteur forcée (niveau au-dessus de la boîte : 6,7 partout) |
| a sea in an empty world | un seul plan, deux triangles |
| a refused source draws nothing | aucun triangle |

Gardé aussi, sur chaque cas : aucune jonction en T entre plats, nappes à rangée + 0,7, bandes à case − 0,15 ; les quatre
genres exercés. ⚠ **NON EXERCÉ** : la cascade « droite » (d = 0, sans sens connu) — d'après la lecture de `fluides.gd`, la
règle ne la produit pas (la lèvre suit toujours un pas horizontal ou un mur voisin) ; sa ligne reste dans `rules_text`.

### Mutations — 17, 16 ROUGES, 1 ÉQUIVALENTE (MESURÉ, `MB_NATIF=0`)

Chacune appliquée à `eau_maillage.gd` : **sans régénérer, le fichier livré rougit** (16 sur 16 : un greffon qui aurait ce
défaut échouerait les cas) ; **régénérée**, 11 rougissent encore par une garde nommée de `test_parite` (jonction en T,
nappe à 0,65, pas de débord en x−, pas de nappe sous l'étage, rangées sans la couleur, horizon à trois rectangles, bouts
non arrondis, rentrée de 0,3 — vue par la marge de sens, 0,042 —, remous jamais sur l'eau dormante, anneau sans ses
0,02, source sans dôme). Les 5 autres (écume linéaire, lèvre la plus basse, 2e coin, bande à 0, deux bandes) ne sont
gardées QUE par les cas — c'est leur rôle. **L'ÉQUIVALENTE, attendue** : garder les sommets orphelins des grilles ne change
aucun triangle (le contrat est en triangles, pas en sommets).

### Le recalcul quand on peint — le budget MESURÉ, et ce qu'on recommande

`DEV_TOOLS/banc_eau_recalcul.gd` sur l'exemple livré (739 481 cases pleines, 3 couches d'eau, 106 sources, une mer de
354 159 cases ; deux passes, machine partagée avec une autre session Godot : des écarts de ×2 entre passes) :

| Ce qu'on refait | GDScript seul (`MB_NATIF=0`, le greffon Godot) | Avec le cœur natif (l'appli) |
| --- | --- | --- |
| La règle en entier (`FL.monde`) | 2,0 – 3,3 s | 1,0 – 2,7 s |
| Les nappes en entier (3 couches) | 3,1 – 3,3 s, dont **la mer seule 1,8 s pour 72 triangles** | 2,7 – 5,7 s |
| Tout refaire (un greffon sans reprise, à chaque geste) | **5,1 – 6,7 s** | 3,7 – 8,4 s |
| Un geste près d'une rivière, avec la reprise de l'appli | 0,7 – 1,2 s (84 sources reprises sur 106) | 0,24 – 0,32 s |
| Un geste loin de l'eau, avec la reprise | 0,7 s (99 reprises) | 0,09 s |

La mer relue de son eau (ce qu'a le greffon) coûte autant que relue de ses tronçons, à ces écarts près. C# et C++ : NON
MESURÉS (attendus plus rapides que GDScript, sans chiffre).

**RECOMMANDÉ (PROPOSÉ, à valider par Jordan)** :
1. **Jamais pendant un geste.** Un trait de pinceau ne touche pas à l'eau ; la nappe se dit PÉRIMÉE (le greffon Godot le
   fait déjà, `stale`).
2. **Un recalcul DIFFÉRÉ à la fin du geste** (relâcher, annuler, refaire), après ~0,5 s sans nouveau geste — sur un fil à
   part si le moteur le permet (fonctions pures sur une COPIE des cases : `WorkerThreadPool`, une `Task` .NET, une tâche
   asynchrone d'Unreal), la nappe échangée sur le fil principal.
3. **La reprise de l'appli, à porter** (`FL.monde` avec `avant` / `changees` ; `_etendre`, `_boite_compatible` ; « une couche
   dont tous les corps sont repris garde sa nappe » ; la mémoire des nappes par corps) : c'est elle qui fait passer un
   geste de ~6 s à moins d'une. Pas de cas propre — elle rend la MÊME sortie que le calcul entier : le banc de chaque
   moteur le vérifie sur des gestes au hasard (incrémental == entier).
4. **Un bouton « Rebuild water » toujours là**, et le suivi automatique (2) qui se COUPE de lui-même quand le dernier
   recalcul a dépassé ~1 s (la nappe reste dite périmée jusqu'au bouton) — une grande mer en GDScript y tombe, un monde
   ordinaire non.
5. **Le contrôle de bout en bout** : dans chaque moteur, la nappe recalculée depuis les sources d'un `world.json` exporté
   doit être le sac de la nappe CUITE de ce monde (`water/<nom>.glb`), couleurs à 1/255 près.

### Découpage conseillé des trois agents moteurs

Un agent par moteur, en parallèle ; les cas sont le commun. Dans chaque moteur, dans cet ordre :

1. **Le banc d'abord** : lire `water_mesh_conformance.json` (une sorte inconnue rougit), l'appariement en sac, et son
   auto-épreuve (mélanger / tourner / bruiter : vrai ; déplacer / retourner / doubler : faux). Godot : passer `water_mesh`
   de `PARITE_A_VENIR` à `PARITE` dans `test_greffon_peinture` ; Unity : un `WaterMeshConformanceCheck` (banc .NET et
   Test Runner) ; Unreal : `core-runner/parity.cpp`.
2. **Le mailleur, du plus simple au plus dur, cas par cas** : SHEET (le lac du cratère, la grotte : 2 triangles) → la mer
   et l'horizon (île, dalle, mer au-dessus de tout, monde vide, un seul océan, refus) → les plats sans jonction en T →
   les bandes et la source (l'escalier) → les cascades (plan, fusion, grille, normales) → l'écume (anneau, embruns) → la
   rivière large, le débordement, la mer rejointe, le bassin. Godot : du GDScript dans `mb_water.gd` (il ne charge rien
   du cœur) ; Unity : C# pur à côté de `MBWater` ; Unreal : C++ standard dans `MBCore` (le C++ privé de l'appli ne part pas).
3. **Le branchement** (2 à 5 ci-dessus) : différé, fil à part, reprise, bouton, coupure au-delà d'~1 s, contrôle de bout
   en bout contre la nappe cuite.
4. **À l'image** : la nappe recalculée sous les six presets, à côté de la nappe cuite du même monde — indiscernables
   (« ce qui se voit se juge à l'image »).

Une règle ambiguë se remonte et se corrige dans `eau_maillage.gd`, puis on régénère : jamais dans un moteur.

**UNITY — FAIT (7 octobre 2026, branche `eau-unity`)** : `MBWaterMesh` 14/14, la reprise portée (banc incrémental = entier),
le branchement (`MBWaterFollow`, Rebuild water), le bout en bout contre la nappe cuite, vu à l'image (charte, « L'eau
recalculée dans Unity »). ⚠ **REMONTÉ, OUVERT** : aucun des 14 cas ne fusionne deux cascades d'un même lieu ni ne voit deux
fois une case de bande (sondé dans le C# : une exception dans ces branches laisse les 14 verts) — les mutations « lèvre la
plus basse » et « deux bandes sur une case » n'y sont donc PAS gardées par les cas, contrairement à ce que dit la liste
ci-dessus. Un cas à ajouter dans `epreuve_parite.gd` (deux rivières sur les mêmes cases, l'une sortant d'un tunnel sous la
cascade de l'autre : le monde de `DEV_TOOLS/preparer_eau_unity.gd` le fait).
