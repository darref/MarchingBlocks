# Undermend — charte du greffon

Elle porte les décisions transverses : celles qui doivent survivre à une session et à quelqu'un qui
arrive six mois plus tard avec une bonne idée.

⚠ **Chaque décision porte son statut** :

- **DÉCIDÉ** — voulu par Jordan, ne se rediscute pas sans lui ;
- **PROPOSÉ** — réflexion à valider, avec sa raison ; on peut la jeter, pas l'ignorer ;
- **MESURÉ** — vérifié par un calcul, un test ou une capture, donc vrai quoi qu'on en pense ;
- **OUVERT** — question posée, pas encore tranchée.

Un PROPOSÉ ne devient DÉCIDÉ qu'une fois validé — à l'image de préférence, jamais par ancienneté.

---

## 1. Le greffon en une phrase — DÉCIDÉ

> **Peindre des tuiles 3D NON CUBIQUES dans un GridMap, à partir de blocs que l'artiste modélise
> librement.**

Le GridMap de Godot pose des cubes. Undermend pose des morceaux de paysage — des coudes, des arches,
des angles rentrants, des tunnels — en assemblant automatiquement, selon le voisinage, des tuiles
découpées dans l'art de l'artiste.

⚠ **LA GÉOMÉTRIE PLUTÔT QUE LE PBR (Jordan, 24 septembre 2026).** Le relief est réel et libre, il n'est
pas suggéré par une carte de normales. Le PBR reste prévu pour un **mode simplifié** du greffon, dans le
greffon — pas comme substitut.

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
- **DÉCIDÉ (Jordan, 27 septembre 2026) — LE ROUGE, PAS LA COMPLÉTION.** Peindre une diagonale pose un
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

---

## 4. Le pipeline — l'aller-retour qui prouve tout

```
  exporter_le_bloc()  →  UN .glb, le bloc à l'origine  →  Blender  →  librairie_depuis_glb()
                                                                          ↓
                                   trancher() par case  →  classer  →  MeshLibrary  →  le pinceau
```

- ⚠ **LE BLOC EST RETROUVÉ PAR SA POSITION, PAS PAR SON NOM.** Dans un modeleur on renomme, on joint,
  on fusionne sans y penser : un nom ne survit pas à une séance de travail, une place fixée si. C'est
  aussi la doctrine générale — **on DÉDUIT plutôt qu'on déclare**. Le bloc est à l'origine, et la
  réimportation le redécoupe dans une boîte **tolérante au relief** (`DEBORD_TOLERE`) : découper pile
  sur `COTE³` raboterait le travail de l'artiste au ras des bords.
- ⚠ **LE .glb PART SOUDÉ, SANS NORMALES NI TANGENTES.** Sans normales, la spécification glTF impose
  l'ombrage PLAT : on obtient à la fois la topologie soudée (modifiable dans Blender) et des arêtes
  franches. ⚠ Nuller `ARRAY_NORMAL` **sans** `ARRAY_TANGENT` ne suffit pas.
- **Il part déjà AMINCI** — tuiles ramenées à la moitié de leur case — pour montrer à l'artiste la marge
  dont il dispose. ⚠ **On rétrécit AVANT le tranchage** : chaque cube reste fermé, et les pièces
  voisines se rebouchent. Rétrécir APRÈS les crève, puisqu'elles sont ouvertes sur leurs faces de coupe.
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

---

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
- **DÉCIDÉ (Jordan, 27 septembre 2026) — la boucle a quatre boutons, et leurs noms** : « Générer les
  nœuds » (le témoin calculé, un massif vide à peindre) · « Exporter le témoin… » · « Importer le
  travail… », qui **l'AFFICHE seulement**, dans la vue et tel que le trancheur le lira
  (`BlocsMaitres.travail_depuis_glb()`, la même lecture que le tranchage) · « Trancher, générer et
  peindre », qui relit ce travail au moment du clic, pose les nœuds et **peint les cases du témoin**
  dans la même action d'annulation. Le résultat doit redonner le témoin : c'est la preuve de
  l'aller-retour, à l'œil. Tout est dans une **barre de défilement verticale** : le bas de la bande
  était inatteignable.
  ⚠ Ces libellés sont en français, alors que le §7 veut l'anglais à l'écran : c'est **OUVERT**, et toute
  l'UI est dans le même cas.

---

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

- **Tests** — `godot --headless --path D:/UnderMend --script res://DEV_TOOLS/<test>.gd`, code 0 ou 1.
  Six suites, **7 450 vérifications, 0 échec** (27 septembre 2026, recomptées) :
  `test_marching_blocks` 1 980, `test_repli_procedural` 3 922, `test_blocs_maitres` 1 415,
  `test_massif_peint` 78, `test_tranchage` 40, `test_decoupe` 15.
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

⚠ **Jusqu'au 24 septembre 2026, Undermend était un JEU** : un monde vu de dessus et des grottes vues de
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
   - **MESURÉ (`DEV_TOOLS/sonde_legende_contexte.gd`, 27 septembre 2026, sur la planète paysage de
     820 cases)** : **676 sous roche — 82,4 %** — et l'aminci qui part chez l'artiste peint
     **11 869 de ses 15 560 quads** en teinte souterraine (76,3 %). La légende suit le bloc translaté.
     (Sur l'ancien 8³ : 75,6 % et 6 287 / 8 326.)
   - **DÉCIDÉ (Jordan, 25 septembre 2026) — SIX TEINTES FRANCHES, et c'est contre ma recommandation.**
     Trois orientations × deux contextes : vert / ocre pour les sols, beige-brun / mauve pour les
     parois, bleu / bleu profond pour les plafonds (`repli_procedural.gd`, qui reste leur unique
     source ; le mailleur ne les redéfinit pas).
     ⚠ **CE QUI ÉTAIT ÉCRIT ICI — « on MODULE les trois teintes, on n'en ajoute pas trois ; six teintes
     franches auraient rendu bariolé un témoin dont l'illisibilité est le défaut qu'on corrige » — A
     ÉTÉ RENVERSÉ, et la raison compte plus que le verdict** : mon objection visait une couleur qu'il
     faut DEVINER, et la **légende écrite sous la vue** (`ecran_edition.gd`) y répond en donnant son nom
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

6. **La sélection maison** (§5) : `_forward_3d_gui_input`, un rayon, un étage ou la géométrie, un
   surlignage. C'est ce qui débloque tous les outils au-delà de la case à case.
7. **Le mode PBR simplifié** (§1), pour les machines et les projets qui ne veulent pas de la géométrie.
8. **Ce qu'il faut pour vendre** : une démo, une page, une licence. OUVERT.
