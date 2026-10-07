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

## 2. Les fluides — PARTIEL (lecture et règle : cas ; maillage et presets : pas de cas)

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
- **CE QUI N'A PAS DE CAS** : le MAILLAGE de l'eau (`eau_maillage.gd` : plats sans jonction en T, nappe sous un étage
  flottant, cascades en volume, remous, source). Un greffon qui recalcule l'eau devrait aussi refaire la nappe — c'est
  une seconde réécriture de ~1 000 lignes, sans cas aujourd'hui. **Conseil** : à la 0.9.0, les greffons montrent la
  nappe CUITE (déjà complète) et recalculent les CASES d'eau (règle + cas) ; recalculer la nappe en peignant attend
  qu'`eau_maillage.gd` ait ses cas (ou passe au cœur C++, comme les plats l'ont déjà fait).
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
- **Recalculer la NAPPE d'eau** : pas de cas (§2).
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
