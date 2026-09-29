# MarchingBlocks — charte du greffon

Elle porte les décisions transverses : celles qui doivent survivre à une session et à quelqu'un qui
arrive six mois plus tard avec une bonne idée.

⚠ **Chaque décision porte son statut** :

- **DÉCIDÉ** — voulu par Jordan, ne se rediscute pas sans lui ;
- **PROPOSÉ** — réflexion à valider, avec sa raison ; on peut la jeter, pas l'ignorer ;
- **MESURÉ** — vérifié par un calcul, un test ou une capture, donc vrai quoi qu'on en pense ;
- **OUVERT** — question posée, pas encore tranchée.

Un PROPOSÉ ne devient DÉCIDÉ qu'une fois validé — à l'image de préférence, jamais par ancienneté.

---

## 0. Le produit : le logiciel MarchingBlocks — DÉCIDÉ (Jordan, 27 septembre 2026)

> **Le projet devient un LOGICIEL, MarchingBlocks, vendu 60 € en UN exécutable chiffré.** Il fait
> tout ce que fait le greffon, reprend l'écran de SoluTiles (`D:/AbsoluTiles`, « le même genre de
> projet, mais 3D au lieu de 2D »), et exportera vers TROIS greffons de peinture — Godot, Unity,
> Unreal — **écrits APRÈS lui**.

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
- **OUVERT** : la licence ; l'icône et le splash ; les
  textures PBR de test (retirées avec le PBR le 29 septembre 2026) venaient de HEART_WORLD.

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

### La moitié du contrat qui n'était PAS écrite : les EXEMPLAIRES — DÉCIDÉ (Jordan, 27 septembre 2026)

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

### Le TERRAIN monolithique et les PROPS rattachés — DÉCIDÉ (Jordan, 28 septembre 2026), PAS ÉCRIT

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
  tileset.json   la règle ET les tuiles : table des 256, coins, décalage, classes, contexte, hachage,
                 rules_text, et tiles = {clé: [noms des exemplaires]}, missing
  tiles.glb      un nœud par tuile, maillage centré sur l'origine, nœud à l'identité, matériaux
  README.txt     la règle en clair
```

- ⚠ **LE FICHIER PORTE LA RÈGLE.** Trois greffons qui réécriraient la classification, c'est la seconde
  description qui diverge (§6). La table est PRÉ-CALCULÉE ; le contexte et l'exemplaire, qui se
  recalculent en jeu, sont ÉCRITS (`FormatNeutre.regle()`, ligne à ligne) et gardés par des cas
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
  `mb_arete_creuse_b2h2_dehors` → `edge_inner_b2h2_outdoor`, exemplaires `_2`, `_3`… La traduction vit
  dans `format_neutre.gd` ET NULLE PART AILLEURS ; les greffons ne décodent jamais un nom, ils lisent
  `tiles`. Gardé : aucun id en double, aucun hors de l'alphabet.
- ⚠ **UN SHADER DE GODOT NE VOYAGE PAS** : une tuile à `ShaderMaterial` part avec un matériau standard
  lisant ses couleurs de sommet ; le travail de l'artiste part avec SES matériaux — **et sa texture arrive,
  MESURÉ jusque dans Unity** (voir le faux travail d'artiste, plus bas).
- **Un format plus récent est REFUSÉ** par les greffons : sa règle peut vouloir dire autre chose.
- **LES CAS D'ÉPREUVE** (`FormatNeutre.cas_d_epreuve()`, écrits par `DEV_TOOLS/generer_cas_d_epreuve.gd`
  dans `conformance.json`, LIVRÉ AVEC CHAQUE GREFFON) : 9 mondes (case seule, sol, falaise de 3,
  surplomb, tunnel, grotte close, contact diagonal, coordonnées négatives, relief irrégulier) × 2 jeux
  (riche : variantes d'air libre et 3 exemplaires ; nu : noms nus seuls) = 18 cas, **1 624 poses — 460
  d'air libre, 203 exemplaires au-delà du premier, 46 marqueurs**. Un greffon doit les passer à 100 %.
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
- **OUVERT** : l'export des MONDES peints (`world.json` : couches, jeu de tuiles, cases), proposé en
  option ; la reconstruction INCRÉMENTALE (écrite dans la règle : seules les colonnes x−1..x, z−1..z
  jusqu'à la hauteur de la case changent) — ni l'appli ni les greffons ne la font encore (le Unity pose
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

### L'appli : couches, projets, barre d'outils — DÉCIDÉ (Jordan, 27 septembre 2026)

- **LE MONDE PEINT NE DÉPEND PLUS DU TRAVAIL QUI L'HABILLE.** Une **couche** = une source de tuiles
  (le témoin calculé ou un `.glb`) et SES cases, dans son propre `MassifPeint` : son voisinage ne
  regarde que ses cases. Trancher change les tuiles de la couche ACTIVE, **jamais ses cases**.
  ⚠ « Slice the work » peignait jusque-là les cases du témoin en les remplaçant : c'était la preuve de
  l'aller-retour. Elle vit désormais dans un bouton à part, **« Paint the witness shape »**.
  ⚠ **ET CETTE PREUVE N'EST PLUS À L'IDENTIQUE DEPUIS LES EXEMPLAIRES** (§3) : le peintre tire
  l'exemplaire d'un sommet par hachage de sa position, pas d'après l'endroit où il fut sculpté. Même
  forme, mêmes classes ; un coin sculpté ici peut reparaître là.
- **LE PROJET** (`app/projet.gd`, `.mbproj` en JSON) porte les couches et leurs cases, **s'enregistre
  après chaque changement** (branché sur l'historique) et se rouvre au lancement. On écrit à côté puis
  on remplace. ⚠ Un projet qui ne s'ouvre pas n'est jamais écrasé : on en commence un autre.
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
- **LES QUATRE ÉTAPES À GAUCHE (Jordan, 28 septembre 2026)** : Export · Import · Slice · Export to
  engines, numérotées, et les imports gardés en LISTE (réimporter un même fichier le remplace). La
  liste ne survit pas à la session : OUVERT.
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
  ⚠ **LES GREFFONS (Godot, Unity, Unreal) GARDENT NAVIGATE COMME TROISIÈME VISÉE** : le changement du 29
  n'a porté que sur l'appli. **OUVERT** — les aligner ? Dans Unity et Unreal, Navigate REND la souris au
  moteur, dont la vue vole déjà nativement.
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
  - ⚠ **VU À L'IMAGE, PAS TENU EN MAIN** : `capture_app.gd` photographie le personnage posé, en marche,
    en saut, de près et de face (yeux et contour lisibles). Le ressenti — vitesse, hauteur de saut, le pas
    de 0,3 case, la caméra qui se rapproche contre les parois — se juge clavier en main, par Jordan.
- **LA BARRE DE GAUCHE ET LE CONTEXTE — DEMANDÉ PAR JORDAN (29 septembre 2026).**
  - **L'ATELIER EST ÉPINGLÉ EN HAUT** : il ne défile jamais.
  - **DEUX ZONES, CHACUNE SON DÉFILEMENT** : en haut ce qui compte (le projet, les couches, les quatre
    étapes, le Play test, et le rapport épinglé dessous), en bas la RÉFÉRENCE (le témoin et sa légende,
    les raccourcis), dans un rapport d'étirement de 3 contre 1 — les 75 % demandés, qui suivent la taille
    de la fenêtre. **De gros séparateurs** (titre gras sur filet épais) marquent les groupes : WORKSPACE,
    PROJECT, THE ROUND TRIP, REFERENCE.
  - **TOUTE LA BARRE DE DROITE S'OUVRE DÉPLIÉE** (« Shape operations » était repliée).
  - **CE QUI NE SERT PAS ICI NE S'AFFICHE PAS** — une seule fonction, `_contexte()`, avec son tableau :
    Witness montre le projet, les étapes 1-2 et la section Witness ; World montre le projet, les couches,
    les quatre étapes, les raccourcis et la barre de droite ; Play test ne montre que ses commandes et le
    rapport. ⚠ **LA BARRE DE DROITE ÉTAIT UN CADRE VIDE DANS LE TÉMOIN** : ses sections se cachaient, le
    panneau restait et mangeait un quart de la vue. Dans les outils, le pinceau (taille, forme) disparaît
    pour Rect et Box, « Hollow » n'apparaît qu'avec Box. « Show the witness » n'apparaît que quand on
    regarde un travail ; « Slice the selected work » est grisé tant que rien n'est importé, « Delete » tant
    qu'il ne reste qu'une couche.
  - **Gardé par `fumee_appli`** (92 vérifications) — mutations rouges : Tab sur trois visées, E qui ne
    monte plus, Witness partout, Hollow partout, A qui choisit Add en vol, barre de droite partout,
    ateliers dans le défilement. **Vu à l'image** (`capture_app.gd`, Witness et World) : c'est là qu'on a
    vu le titre PROJECT doublé par la bande « Project » (devenue « Save · open ») et le rapport qui gardait
    les touches du jeu après en être sorti.
- ⚠ **RIEN DE CECI N'A ÉTÉ TENU EN MAIN PAR JORDAN.** Les captures (`capture_app.gd`) montrent les
  panneaux, l'aperçu et la grille locale ; que le rayon tombe où l'œil l'attend, ça se juge souris
  en main.

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
  Douze suites, **7 846 vérifications, 0 échec** (29 septembre 2026, recomptées après la navigation
  sortie des visées et la passe de contexte de l'écran), plus trois bancs hors Godot : .NET (`engines/unity/conformance-runner` :
  18 cas de pose, 69 d'outils), g++ (`engines/unreal/core-runner` : les mêmes, et le repère) et Unity 6.6
  (10 tests), et un essai Blender (`essai_blender.gd`, il lui faut Blender) :
  `test_marching_blocks` 2 027, `test_repli_procedural` 3 922, `test_blocs_maitres` 1 432,
  `test_massif_peint` 86, `test_tranchage` 53, `test_decoupe` 17, `test_etages` 7, `test_projet` 31,
  `test_outils` 57, `fumee_appli` 92, `test_greffon_peinture` 87, `test_faux_artiste` 35.
  ⚠ **APRÈS UN RENOMMAGE DE DOSSIER, LE CACHE DE CLASSES D'UNE AUTRE MACHINE EST PÉRIMÉ** (`.godot/`,
  hors git) : « Class "MassifPeint" hides a global script class » — `test_massif_peint` rendait **1**
  vérification au lieu de 86 en finissant en code 0, et `fumee_appli` pendait. Mesuré le 28 septembre
  2026, aussi sans les changements du jour. Remède : `godot --headless --editor --quit` une fois, puis
  rendre ce qu'il a réimporté (`git status`).
  ⚠ **`fumee_appli` CHARGE L'APPLI ENTIÈRE** et la mène sans souris. Elle pointe `reglages.cfg` sur un
  projet jetable et le rend à la fin : l'appli s'enregistre à chaque geste, et une fumée qui rouvrirait
  le vrai dernier projet l'écraserait. `capture_app.gd` fait de même, AVEC fenêtre.
  ⚠ Les trois suites qui ont grossi portent les gardes des exemplaires : `test_marching_blocks` §16
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

6. ~~**LES EXEMPLAIRES**~~ — **FAITS** (27 septembre 2026). Le trancheur ne jette plus rien : **52 clés,
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
9 bis. **LE TERRAIN MONOLITHIQUE ET LES PROPS RATTACHÉS** (§3) — DÉCIDÉ, pas écrit. D'abord les deux
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
    ⚠ **MARCHÉ — MESURÉ À MOITIÉ, PROPOSÉ pour le reste** : l'Asset Library officielle de Godot
    est GRATUITE uniquement (un registre de liens, elle n'encaisse rien), donc un addon payant
    passe par itch.io ou Gumroad. ⚠ **La vraie différence n'est pas la commission, c'est la
    DÉCOUVERTE** : l'Asset Store Unity prend 30 % mais met l'outil devant des gens qui le
    cherchent ; sur itch on amène son public soi-même. **OUVERT** — le nouveau « Godot Asset
    Store » accepte-t-il le payant ? À vérifier chez eux, pas de mémoire.
