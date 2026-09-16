# Undermend — charte du projet

Même rôle que la charte de River Stones : porter les décisions transverses, celles qui doivent
survivre à une session et à quelqu'un qui arrive six mois plus tard avec une bonne idée.

⚠ **Le projet naît, donc tout n'a pas le même poids.** Chaque décision porte son statut :

- **DÉCIDÉ** — voulu par Jordan, ne se rediscute pas sans lui ;
- **PROPOSÉ** — réflexion à valider, avec sa raison ; on peut la jeter, pas l'ignorer ;
- **MESURÉ** — vérifié par un calcul, un test ou une capture, donc vrai quoi qu'on en pense ;
- **OUVERT** — question posée, pas encore tranchée.

Un PROPOSÉ ne devient DÉCIDÉ qu'une fois validé — au greybox de préférence, jamais par ancienneté.

---

## 1. Le jeu en une phrase — DÉCIDÉ

> **Vous réparez le monde vu de dessus en résolvant les énigmes enfouies dans les profondeurs, vues
> de côté.**

**Le lore.** La lumière n'a pas atteint les profondeurs depuis si longtemps que des nœuds y sont
apparus. Certains sont inextricables : seule une force venue du ciel lui-même peut les défaire, la
lumière seule n'y parvient pas. Pour tous les autres, vous emmènerez la lumière du ciel là où elle
n'arrive plus.

Ce que le lore impose au jeu, et qui n'est pas de la couleur :

- **la lumière est l'outil ordinaire**, la force du ciel est l'exception — les énigmes courantes
  sont donc des énigmes de TRAJET DE LUMIÈRE ;
- **un nœud a un type** dès la première ligne de code (ordinaire / inextricable), même si le second
  n'est défaisable que tard dans le jeu ;
- **le titre porte déjà le principe** : *to undermine*, c'est affaiblir en creusant dessous ;
  *undermend*, c'est réparer en creusant dessous.

---

## 2. Un seul monde, deux projections

**DÉCIDÉ** — la surface se joue vue de dessus (à la *A Link to the Past*), les grottes se jouent vues
de côté, et **se déplacer dans une grotte fait défiler la vue de dessus**.

**DÉCIDÉ — une ENTRÉE est le seul lien entre les deux vues.** Le joueur y passe, l'onde d'un nœud
y passe et nulle part ailleurs (§5). **PROPOSÉ, et c'est ce que fait déjà le moteur :** la lumière
aussi (§4). Une seule porte entre deux mondes, c'est une seule chose à lire pour le joueur et une
seule chose à valider pour le code.

**PROPOSÉ — une grotte est un CHEMIN sur la grille de surface, et sa vue de côté en est la coupe
DÉROULÉE.** Chaque colonne de la vue de côté correspond à exactement une case de surface :

```
  colonne de grotte :   0     1     2     3     4     5  ...
  case de surface   : (12,4)(13,4)(14,4)(14,5)(14,6)(15,6) ...
```

- ⚠ **C'est une TABLE D'ENTIERS, pas une courbe.** Un `Curve2D` échantillonné en flottants serait
  une seconde description du même lieu, et deux descriptions d'un même lieu divergent au premier
  réglage (charte de River Stones, §8, corollaire général). La table est la seule vérité : la
  longueur de la vue de côté s'en DÉDUIT, elle ne s'écrit pas à côté.
- ⚠ **Cette table sert au DÉFILEMENT, jamais au passage.** Elle dit où placer la caméra de surface
  quand on marche dans la grotte ; ce qui traverse d'une vue à l'autre passe par une entrée, et par
  elle seule.
- **Où vit la table** : sur le nœud de la grotte (`CLIENT/grotte.gd`) — une case de départ et des
  segments DROITS, réglables dans l'inspecteur. La coupe peinte doit faire exactement sa longueur, et
  `CLIENT/niveau.gd` le vérifie plutôt que de deviner (§6, « Les niveaux peints »).
- **Un coude du chemin est invisible de côté** : la coupe est déroulée, et c'est assumé.
- **Le joueur n'existe que dans UN monde à la fois.** L'autre vue montre sa PROJECTION (un repère),
  jamais un second corps. Deux corps synchronisés seraient deux autorités sur une position.
- **OUVERT — les segments en diagonale.** Pour la v0, les chemins sont faits de segments droits
  (horizontaux ou verticaux sur la carte). Une diagonale demande une convention de longueur — une
  colonne par pas diagonal garde les deux grilles alignées, mais le repère de surface y va alors
  √2 fois plus vite que le joueur. À trancher le jour où une grotte en réclame une.

### Les grottes entre elles — PROPOSÉ (question de Jordan, 16 septembre 2026)

**PROPOSÉ — deux grottes ne se voient JAMAIS, et ce n'est pas une limite technique : leur position
relative N'EXISTE PAS.** Une coupe est DÉROULÉE : ses colonnes suivent un chemin qui tourne. Deux
grottes qui se croisent sur la carte de dessus n'ont aucun repère commun, et dessiner l'une dans la vue
de l'autre demanderait de répondre à « à quelle distance, dans quelle direction ? » — une question sans
réponse, puisque la distance dépend du chemin parcouru, pas de la géométrie.

**Ce qu'on fait quand on VEUT voir deux galeries à la fois : c'est UNE grotte.** Une coupe a dix
rangées ; deux tunnels superposés y tiennent, et ce n'est que de la peinture — pas une mécanique de
plus. Une salle où deux boyaux se rejoignent est une grotte dont la coupe est creusée plus haut à cet
endroit.

- ⚠ **Conséquence** : deux grottes ne passent jamais sous la même case de surface (le chargeur le refuse
  déjà, §6), et le pourtour de roche d'une coupe se remplit sans se soucier des voisines.
- **PROPOSÉ — on remplit ce que la caméra peut voir.** Au-delà du jeu, un calque « Decor » porte de la
  roche (une falaise en surface) sur la largeur que la caméra peut atteindre : huit colonnes de chaque
  côté d'une coupe, dix cases autour de la surface. ⚠ **Ce calque n'est PAS le monde** : `CLIENT/niveau.gd`
  ne le lit jamais. Il remplit l'œil et arrête les pieds ; le moteur, lui, tient déjà pour plein tout ce
  qui est hors grille. Remplir la grille elle-même casserait « une colonne par case de surface ».

---

## 3. L'écran partagé — UNE seule valeur

**DÉCIDÉ** (version du 16 septembre 2026, qui remplace les précédentes) — ce qu'on voit :

- **dans une grotte, TOUJOURS les deux** : grotte sur 3/4 de la largeur, vue de dessus sur 1/4, quelle
  que soit la profondeur. La grotte n'est jamais seule à l'écran ;
- **en surface, la vue de dessus seule, en plein écran**, SAUF dans deux cas où la grotte revient sur
  1/4 :
  - quand on est **proche d'une entrée** ;
  - quand **une résolution dynamique est en train d'être montrée au joueur** — la résolution d'un
    nœud, ou tout autre événement de résolution qui se produit dans une grotte ;
- **la démarcation BALAIE** l'écran, de gauche à droite ou de droite à gauche, à chaque changement :
  les deux vues s'agrandissent et rétrécissent en temps réel, de façon fluide, à haut FPS.

⚠ **L'asymétrie est le sujet.** On descend pour réparer ce qu'on voit d'en haut : sous terre, la
surface reste donc toujours sous les yeux. En haut, la grotte ne s'impose que quand elle a quelque
chose à dire — on s'en approche, ou elle change.

**PROPOSÉ — la surface est toujours À GAUCHE, la grotte toujours À DROITE, et toute la mise en page
est la position d'un SÉPARATEUR.** Trois positions, en pixels de la résolution de base :

```
  x = 320   surface seule                      ████████████████████████████████
  x = 240   surface, près d'une entrée         ████████████████████████│░░░░░░░░
            ou pendant un événement de grotte
  x =  80   dans une grotte                    ████████│░░░░░░░░░░░░░░░░░░░░░░░░
             surface ←┘ └→ grotte
```

Passer d'une situation à l'autre ne permute rien : **le séparateur glisse**. Le joueur ne perd jamais
où est quel monde, et il n'y a qu'un nombre à animer — pas une disposition à inverser avec sa moitié
qu'on oublierait. Le plein écran de la surface n'est pas un mode à part : c'est le séparateur poussé
au bord.

- ⚠ **HYSTÉRÉSIS OBLIGATOIRE.** La bande apparaît à R cases d'une entrée et ne disparaît qu'à R + une
  marge. Sans ça, un joueur qui marche le long du seuil fait balayer l'écran en boucle. Rayons en
  CASES, jamais en pixels.
- **Près d'une entrée, la bande montre la grotte à la bouche de cette entrée** ; s'il y en a
  plusieurs, la plus proche gagne.
- **Pendant un événement, la bande montre la grotte LÀ OÙ il se produit.** ⚠ C'est ce qui a imposé que
  chaque événement rendu par `resoudre()` porte sa `grille` et sa `case` : un objet DÉTRUIT n'est plus
  dans le monde, et sans ça plus rien ne pourrait dire où il était.
- **PROPOSÉ — pendant un événement près d'une entrée, l'événement l'emporte sur la bouche** ; la bande
  revient à la bouche quand il est fini. Pendant la fermeture, la bande garde ce qu'elle montrait.
- **PROPOSÉ — la bande reste ouverte le temps que l'événement soit montré, plus un MAINTIEN de 0,5 s**,
  puis se referme ; un événement qui arrive pendant la fermeture la rouvre depuis sa position
  courante, sans saut.
  - ⚠ **L'horloge d'un événement ne tourne que bande OUVERTE.** Le balayage d'ouverture ne mange pas
    le temps que le joueur doit le voir : sinon, sur 0,6 s de fonte, il en raterait la moitié.
  - **Les événements passent en FILE, dans l'ordre de `resoudre()`** — la fonte, PUIS l'allumage —
    chacun sa durée (greybox : 0,6 s pour une transformation, 0,4 s pour un allumage). D'une grotte à
    l'autre, la bande coupe sans se refermer.
- **OUVERT** — plusieurs événements dans des grottes différentes au même moment : la file ci-dessus est
  un défaut, pas une décision. Et sous terre, un événement de SURFACE change-t-il la mise en page ?
  Par défaut, rien ne bouge : sous terre la mise en page ignore les événements, et **descendre vide la
  file** (on a choisi de regarder la grotte où l'on est).
- **MESURÉ (test)** — tout ce qui précède est une fonction pure de `CLIENT/mise_en_page.gd`, gardée par
  `DEV_TOOLS/test_mise_en_page.gd` (48 vérifications, dix mutations qui rougissent toutes).

### Le balayage — PROPOSÉ

- **Un seul nombre animé, et interruptible.** Si la cible change en plein mouvement, on repart de la
  position COURANTE vers la nouvelle, jamais d'un saut.
  - **MESURÉ (test) — chaque trajet est une courbe d'Hermite** qui part de la position ET de la vitesse
    courantes, et arrive à vitesse nulle en `DUREE_BALAYAGE` (PROPOSÉ : 0,3 s, départ et arrivée
    adoucis). Changer de cible ne fait ni saut de position ni à-coup de vitesse, et n'alloue rien.
  - ⚠ **Un élan fort vers une cible toute proche la dépasserait** : la courbe ne reste monotone que si
    élan × durée ≤ 3 × écart. L'élan est plafonné là, et le séparateur ne dépasse jamais sa cible.
  - **La position est une FONCTION du temps écoulé, pas une intégration** : à 30 ou à 240 images par
    seconde, le séparateur est au même endroit au même instant.
- ⚠ **On ne redimensionne JAMAIS un `SubViewport` pendant le balayage.** Changer sa taille réalloue sa
  cible de rendu, à chaque image. Les deux vues rendent à pleine taille, simulées en permanence, et
  l'affichage ne fait que ROGNER (`CLIENT/ecran_partage.gd` : deux rectangles de texture).
- **Une vue entièrement cachée cesse de se rendre**, mais continue d'être simulée : le plein écran
  d'une vue rend l'autre gratuite à l'écran. ⚠ Elle se remet à rendre dès que la CIBLE la montre, sans
  attendre son premier pixel visible : sinon sa première colonne serait une image périmée.
- **La position se quantifie au pixel de base** : l'agrandissement entier garde le trait net, et à la
  vitesse d'un balayage le pas ne se voit pas.
- **Chaque caméra centre le joueur (ou sa projection) dans la partie VISIBLE de sa vue** : quand le
  séparateur glisse, les caméras glissent avec lui sans une ligne de plus.
- **PROPOSÉ — la démarcation est un trait d'un pixel de base, à l'or du logo (`#EBBB69`)**, posé sur la
  première colonne de la grotte : séparateur au bord, il sort de l'écran de lui-même.

**MESURÉ — le balayage ne coûte rien ; redimensionner les vues coûte trois fois l'image.**
`DEV_TOOLS/mesure_balayage.gd`, greybox en 1280×640 sans vsync, RTX 2060, minimum de cinq passes
entrelacées, deux séries le 16 septembre 2026 :

```
  situation                            ms par image        par rapport à la bande fixe
  surface seule (grotte non rendue)    0,578 / 0,564        −11 % / −13 %
  bande fixe (240)                     0,651 / 0,649          0
  sous terre fixe (80)                 0,665 / 0,656         +2 % / +1 %
  balayage continu                     0,662 / 0,650         +2 % / +0 %
  balayage en redimensionnant les vues 2,174 / 2,254       +234 % / +247 %
```

Le balayage tombe dans le bruit des deux positions fixes ; l'interdit du redimensionnement épargne plus
des deux tiers de l'image. ⚠ Ce sont des temps d'image, pas une impression : le TOUCHER du balayage
(durée, courbe) ne se juge qu'à l'œil, avec Jordan.

### La fenêtre — DÉCIDÉ : toujours en 2:1

Pour que le partage tienne correctement quand il est là :

- **plein écran** : bandes noires en haut et en bas pour garder le 2:1 ;
- **fenêtré** : redimensionnable, avec une taille minimale, et le 2:1 conservé pendant tout le
  redimensionnement.

Comment c'est tenu — `CLIENT/fenetre.gd`, en autoload, et F11 ou Alt+Entrée pour le plein écran :

- **le CONTENU** reste en 2:1 par l'étirement `viewport`, l'aspect `keep` et l'agrandissement entier de
  `project.godot`. **MESURÉ (capture)** : plein écran sur 1920×1080, image ×6 nette, bandes noires de
  60 px en haut et en bas (Godot ajoute deux pixels à sa fenêtre plein écran sous Windows : client
  1920×1082) ;
- **la FENÊTRE** reste en 2:1 par recalage : la dimension qu'on a le plus tirée commande (une case de
  hauteur vaut deux de largeur), plancher **640×320** (PROPOSÉ : deux fois la base), plafond l'écran.
  **MESURÉ (capture)** : fenêtre forcée par `SetWindowPos` à 1000×700 → client 984×492 ; à 1500×640 →
  1484×742 ; à 500×300 → 640×320 ;
- ⚠ **MESURÉ — `size_changed` ne sert à rien ici.** Avec l'étirement `viewport`, le viewport racine
  garde sa taille de base quand la fenêtre change : branché sur ce signal, le recalage n'a jamais eu
  lieu. On lit `Window.size` à chaque image ;
- **une fenêtre maximisée n'est pas recalée** : l'écran impose sa taille, l'aspect pose les bandes ;
- **OUVERT — le recalage pendant le glisser à la souris tremble-t-il ?** Windows pilote le
  redimensionnement, Godot ne corrige qu'après coup. Si ça tremble, `RECALER_PENDANT_LE_GLISSER = false`
  recale au relâchement. Ne se juge qu'avec Jordan ;
- **OUVERT — les bandes internes en fenêtré.** Une fenêtre 2:1 qui n'est pas un multiple de 320×160
  garde une fine bande tout autour (1000×500 → image ×3 de 960×480). Défaut en place : (a)
  agrandissement entier partout, en acceptant ces bandes. Les autres issues : (b) tailles calées sur
  les multiples, par crans ; (c) agrandissement fractionnaire en fenêtré seulement.

### La résolution — PROPOSÉ : 640×320, cases de 32 pixels (remplace 320×160)

**Changé le 16 septembre 2026, et par les TUILES, pas par un goût** : le lot acheté pour la surface est
en 32×32. Garder une base de 320×160 aurait montré 10 × 5 cases à l'écran — injouable. On double donc la
base et la case : **le compte de cases ne bouge pas** (20 × 10, comme avant), ni le 2:1, ni le partage.

**MESURÉ (calcul) — l'agrandissement reste ENTIER sur tous les écrans courants**, parce que 640 divise
1280, 1920, 2560 et 3840 :

```
  écran             agrandissement   image 2:1      bandes haut et bas
  1280×720          ×2               1280×640       40 px
  1920×1080         ×3               1920×960       60 px
  2560×1440         ×4               2560×1280      80 px
  3840×2160         ×6               3840×1920      120 px
  1920×1200 (16:10) ×3               1920×960       120 px

  les bases 2:1 qui cassent :  720×360 → ×2,67 en 1080p
                               960×480 → ×2,67 en 1440p
                               768×384 → ×3,33 en 1440p
```

Un pixel art agrandi d'un facteur non entier se déforme : c'est ce réglage qui décide si le jeu a
l'air d'un jeu SNES ou d'une capture floue. ⚠ Une case de 32 pixels sur une base de 640 donne le MÊME
cadrage qu'une case de 16 sur une base de 320 — c'est la même décision, exprimée dans l'unité du lot
de tuiles qu'on a fini par acheter.

- En écran partagé, la vue principale fait **480×320, soit 15 × 10 cases**. ⚠ Le 2:1 coûte quatre
  cases de hauteur par rapport à ALTTP (16 × 14) : c'est le prix du partage, et il est assumé.
- ⚠ **OUVERT — la bande de 1/4 fait 160 pixels, soit CINQ cases de large** sur dix de haut. Elle est en
  portrait : ça va très bien à une coupe de grotte (on y voit la profondeur, c'est un puits de
  lumière), c'est serré pour la surface quand la grotte court d'est en ouest. La question se tranche
  au greybox et nulle part ailleurs : **voit-on, depuis la grotte, le miroir de surface qui est
  au-dessus de soi ?** Premier indice du greybox : la bande ouverte sur un pilier qui fond ne montre
  pas l'œil qu'il libère, trois cases plus loin — c'est la file d'événements qui y amène la caméra, à
  son tour.
- **`project.godot` est en 320×160** depuis le 16 septembre 2026, fenêtre de départ 1280×640 ; sa scène
  principale est pour l'instant le greybox de l'écran partagé (`DEV_TOOLS/greybox_ecran_partage.tscn`).

**PROPOSÉ — rendu `gl_compatibility`.** Un jeu 2D n'a besoin de rien de Forward+, et ce rendu ouvre
le web, le mobile et les machines modestes — les portes que River Stones a payées cher (§10 de sa
charte).

⚠ **`project.godot` ne garde pas de commentaires** : Godot le réécrit en entier au premier
enregistrement. La raison de chaque réglage de projet vit ICI.

---

## 4. La lumière, les miroirs et les activables

**DÉCIDÉ** — on commence par :

- des **miroirs**, **huit orientations**, orientés grâce à des pouvoirs acquis au fil de l'avancée ;
- des **vitres** ;
- des **lasers**, qui peuvent **détruire** des choses — parfois les miroirs eux-mêmes, les cristaux
  activables, ou les **yeux sacrés**, faits de technologie antique. **Une vitre peut devenir un
  laser**, et **une boucle peut en devenir un** ;
- une **lumière de différentes couleurs**, qui agit sur des objets de type **Activable** selon sa
  couleur : un rouge fait fondre un pilier de glace, un bleu éteint une colonne de feu, un violet sur
  un œil jaune ne fait rien ;
- un type d'activable qui **dépend de l'état activé d'autres activables, toujours directement**.

On construit le reste au fur et à mesure, et **la voie doit l'accueillir sans revenir en arrière** —
c'est la contrainte qui a décidé de toute la forme du moteur, ci-dessous.

### MESURÉ — ce que « huit orientations » doit vouloir dire

Un miroir est une ligne à deux faces. Un rayon de direction φ qui frappe un miroir d'angle θ repart
en `2θ − φ`. Les rayons vont dans huit directions (multiples de 45°). Calculé sur tous les cas, et
refait par `test_lumiere.gd` contre une réflexion vectorielle indépendante :

```
  miroir par pas de 45°   (4 orientations)  : les AXES restent des axes,
                                              les DIAGONALES restent des diagonales.
                                              Deux familles qui ne se rencontrent JAMAIS.
  miroir par pas de 22,5° (8 orientations)  : toute direction mène à toutes les autres
                                              (sauf tout droit).
  dans les deux cas : 8 cas rasants (rayon parallèle au miroir), 8 demi-tours.
```

**Donc « huit orientations » = huit positions sur un demi-tour, par pas de 22,5°.** C'est la seule
lecture où les huit directions communiquent — et dans ces unités la réflexion s'écrit
`orientation − direction`, en entiers, sans un flottant. Bonus gratuit : en pixel art ces lignes
sont 0, 2:1, 1:1 et 1:2, les quatre traits les plus propres qu'une grille de pixels sache dessiner.

### PROPOSÉ — la progression des pouvoirs sort du calcul

1. **Tourner** (pas de 45°, 4 orientations) — les rayons restent dans leur famille. On apprend la
   réflexion sur un problème réduit, sans le savoir.
2. **Incliner** (pas de 22,5°, 8 orientations) — les deux familles se rejoignent. L'espace des
   énigmes double d'un coup, et le joueur SENT pourquoi : ce qui était impossible devient possible.
3. **Portée** — orienter un miroir à distance (au-delà d'un gouffre, d'une eau).
4. **Regard croisé** — orienter un miroir de l'AUTRE vue, à travers la bande. ⚠ C'est ce pouvoir qui
   fait de l'écran partagé une MÉCANIQUE : sans lui, la bande n'est qu'une mini-carte.

### Le moteur — construit dans `CORE/`, gardé par `DEV_TOOLS/test_lumiere.gd`

**Le catalogue est écrit en DONNÉES** (`catalogue.gd`). Le traceur et la résolution ne connaissent
AUCUN objet par son nom : ils lisent une optique (miroir, vitre, bloque, traverse, traverse si
actif, portail), une émission, des réactions par couleur, un drapeau « destructible », un drapeau
« dépend ». **Ajouter un activable, c'est ajouter une entrée**, jamais du code — c'est ce qui rend
le « au fur et à mesure » gratuit. Aujourd'hui : rai de ciel, miroir, vitre, pilier de glace et
flaque, colonne de feu et colonne éteinte, œil sacré, cristal, porte antique, entrée.

**Le trajet de la lumière est une FONCTION de l'état**, recalculée quand l'état change. Pas de
photon qui avance, pas d'ordre de mise à jour.

**PROPOSÉ — la couleur est faite de trois bits** (rouge, vert, bleu : huit couleurs, le jaune est
rouge + vert, le violet rouge + bleu). Une vitre ne garde que ce qu'elle laisse passer — un ET —
donc un bleu ne traverse pas une vitre rouge, et deux vitres se composent toutes seules (jaune puis
cyan donne vert). Aucune table à écrire, et une logique que le joueur devine.

**PROPOSÉ — une cible réagit à la couleur EXACTE, faisceau par faisceau.** Un blanc ne fait pas
fondre la glace ; un rouge et un bleu sur la même cible ne s'additionnent pas en violet. Ce qu'on voit
est vrai : un trait rouge touche la glace, la glace fond. ⚠ C'est la décision la plus susceptible de
changer, donc elle est ISOLÉE : `Couleur.convient()`, une ligne, et un test qui rougit si on la
touche.

**⚠ DEUX FAMILLES D'EFFETS, ET LA RÈGLE QUI GARANTIT QU'UNE RÉSOLUTION SE TERMINE.**

- ce qui est **MAINTENU** — un œil actif tant qu'on l'éclaire, un cristal qui relaie, une porte
  antique ouverte tant que ses yeux le sont. État DÉRIVÉ : jamais sauvegardé, recalculé depuis zéro ;
- ce qui est **IRRÉVERSIBLE** — la glace fond, le feu s'éteint, le laser détruit. État STOCKÉ.

**Ce qui est maintenu ne peut qu'AJOUTER de la lumière** (émettre, laisser passer) ; tout ce qui en
retire est irréversible. Le catalogue ne sait pas écrire l'inverse — il n'existe ni « bloque si
actif », ni « émet si inactif », ni condition « aucun » — et `Catalogue.verifier()` refuse qu'on
essaie. Il en découle deux boucles, qui s'arrêtent chacune pour une raison qu'on peut énoncer :

1. à état stocké fixé, on part de « rien n'est actif » : les actifs ne font que croître, donc on
   atteint le **plus petit point fixe**, unique. C'est ce qui fait qu'**un cristal qui ne s'éclaire
   que lui-même reste éteint** et qu'**un montage n'a pas de mémoire** : retirer la lumière qui
   l'allumait l'éteint, boucle ou pas ;
2. sur ce point fixe, on récolte les transformations, on les applique EN BLOC, et l'on recommence ;
   chaque objet descend un graphe de transformations sans cycle, ou disparaît.

⚠ Et **« irréversible » veut dire « pendant une résolution »**, pas « pour toujours ». Entre deux
résolutions, le JOUEUR peut changer l'état stocké — tourner un miroir, refaire un nœud. Ce sont des
gestes, pas des effets de lumière, et la garantie ne les concerne pas.

**Les conflits ont UNE règle chacun, écrite dans le code** — jamais l'ordre des sources :

- **la destruction l'emporte** sur une transformation ; un laser et un rouge sur le même pilier de
  glace le détruisent, dans les deux ordres ;
- **un objet n'a qu'UN destin** (au plus un « devient » par type) — sinon le premier faisceau tracé
  trancherait ;
- **un laser sur un destructible le détruit avant de l'allumer** : un cristal frappé par un laser de
  sa propre couleur disparaît, il ne s'allume jamais.

**Destructible est un défaut par type, surchargeable objet par objet** — « parfois les miroirs
eux-mêmes ». PROPOSÉ : miroirs non destructibles par défaut, cristaux et yeux sacrés destructibles.

**« Toujours directement » — lecture à confirmer :** un dépendant ne lit que des activables allumés
par la LUMIÈRE, jamais un autre dépendant. Pas de chaîne de portes, donc pas de cycle, et une seule
passe suffit à les évaluer. `Monde.valider()` le garde au chargement d'une énigme. Si l'intention
était autre, c'est une ligne de `valider()` à retirer.

**Les rencontres de la lumière avec une entrée** : un faisceau qui entre dans une ENTRÉE ressort dans
l'autre vue, à sa bouche d'arrivée. La bouche est VIDE (validé) : on y apparaît, on n'y traite rien,
sinon deux entrées face à face se renverraient le faisceau à l'infini.

**Trois cas limites tranchés par défaut, chacun gardé par un test :**

- le **rayon rasant** (parallèle au miroir) est arrêté par la tranche ;
- une **diagonale** ne passe pas entre deux coins si l'un des deux est un mur — un trait qui frôle un
  coin a l'air de le traverser, et ce qu'on voit doit être vrai ;
- une **boucle** n'est pas une erreur, c'est une information : le traceur la termine et la SIGNALE,
  avec l'endroit où elle se referme (`fin = BOUCLE`, `boucle_depuis`). **DÉCIDÉ : ce qu'elle
  devient appartient à la trame de chaque énigme** — laser, piège ou rien.

### MESURÉ — le test a su échouer

246 vérifications, vertes. Six défauts réintroduits exprès, un par un, **chacun a rougi** :

```
  mutation                                           rougit
  point fixe parti des actifs précédents             2   le cristal auto-entretenu reste allumé
  destruction sans écrasement                        1   flaque dans un ordre, détruit dans l'autre
  couleur par inclusion au lieu d'exacte             2   le blanc fait fondre la glace
  diagonale arrêtée seulement si les deux coins      1
  détection de cycle retirée du catalogue            1
  propriétés d'objet non vérifiées                   2   « orientaton » posée en silence
```

⚠ La deuxième ne rougit que dans UN des deux ordres de pose : c'est exactement le §6 de River Stones —
un test d'indépendance à l'ordre qui ne construit pas les deux ordres ne voit rien.

### Où se branche la suite — sans revenir sur ce qui existe

- **un activable, un obstacle** → une entrée du catalogue, et son test ;
- **la boucle qui devient laser** → une règle qui lit `fin == BOUCLE` et `boucle_depuis` : le traceur
  fournit déjà tout ce qu'il faut ;
- **un nœud défait par la lumière** → un type avec « devient » ; **le refaire** → un geste qui modifie
  l'état stocké, comme `Monde.tourner()` ;
- **l'onde** → une suite de modifications d'état stocké, datées, chacune suivie de `resoudre()`. La
  résolution reste instantanée ; c'est l'onde qui porte le temps ;
- **les pouvoirs** → le JEU décide combien de crans `tourner()` a le droit de faire. Le monde ne
  connaît pas le joueur ;
- **la force du ciel** → un émetteur, ou un geste ; un nœud inextricable est simplement un type qui ne
  réagit à aucune lumière ordinaire.

⚠ **Ce qui ne rentre PAS : un effet maintenu qui RETIRERAIT de la lumière.** Si une énigme en réclame
un, il ne se glisse pas dans le catalogue — il se rediscute, parce que c'est la garantie de
terminaison qui est en jeu, et avec elle l'absence d'ordre de mise à jour.

---

## 5. Les nœuds et l'onde

**DÉCIDÉ** — on peut **défaire ou refaire** un nœud, et chaque geste lance une onde qui convertit la
zone en **vivante** (défait) ou en **intriquée** (refait). Les nœuds inextricables ne cèdent qu'à la
force du ciel.

**DÉCIDÉ — l'onde passe d'une vue à l'autre par son seul moyen : une entrée.** Un nœud défait dans la
grotte ne ranime la surface qu'à travers une entrée, jamais à travers le sol. On voit alors l'onde
courir dans les deux vues à la fois — et elle dit au joueur, au passage, où sont les entrées.

**DÉCIDÉ — à quoi sert de refaire un nœud dépend de la trame, et ce sera rarement la même chose.**
Conséquence pour le code : **aucun effet de l'état intriqué n'est câblé**. Ce que fait une zone
intriquée est une donnée de l'énigme, exactement comme « devient » dans le catalogue.

### PROPOSÉ — l'état appartient aux NŒUDS, l'onde n'est que le moment où une case l'apprend

Une case bascule à l'instant `t0 + d / v` : `t0` le geste, `d` sa distance en cases au nœud (parcours
en largeur dans sa zone, entrées comprises), `v` la vitesse de l'onde. Trois conséquences :

- **la sauvegarde ne contient que les nœuds** (état + instant du dernier geste) : aucun historique
  par case, rien à réconcilier ;
- **chaque case appartient à UNE zone**, calculée une fois ; deux ondes ne peuvent donc jamais se
  disputer une case — égalité de distance départagée par l'identifiant du nœud, pas par l'ordre de
  mise à jour ;
- **un nœud rebasculé pendant son onde** en lance une nouvelle, qui remplace l'ancienne.

⚠ **L'EFFET DE JEU ARRIVE AVEC L'ONDE, PAS AU CLIC.** Si une case vivante laisse passer la lumière,
elle ne la laisse passer qu'une fois l'onde arrivée sur elle. Ce qu'on voit est vrai — c'est la leçon
des deux horloges de River Stones (§8), et c'est la lisibilité d'*A Link to the Past*. Dans le moteur,
c'est une modification d'état stocké par front d'onde, suivie d'une résolution (§4).

### PROPOSÉ — le rendu : *A Link to the Past* l'a déjà fait

Le Monde des Ténèbres d'ALTTP est **la même carte, repeinte par permutation de palette**. C'est
exactement « vivante / intriquée ». Un shader de tuiles lit une texture d'état à un texel par case et
le front de l'onde ; les changements de FORME (lianes, racines, nœuds visibles) vivent sur un calque
à part. Un seul jeu de tuiles à dessiner, pas deux.

- **OUVERT — la force du ciel.** Ce qu'elle est et comment on l'obtient. Aucune énigme du début n'en
  dépend ; seul le type de nœud doit exister.

---

## 6. Architecture — héritée de River Stones

**Une seule autorité sur les règles.** Les règles d'une énigme vivent dans `CORE/`, sans `Node`, sans
rendu, sans horloge. Tout y est **déterministe et testable sans écran**. `CLIENT/` affiche les deux
vues, la bande, les faisceaux et les ondes, et ne recalcule JAMAIS une règle : il lit
`Monde.faisceaux`, `Monde.actifs` et les événements rendus par `resoudre()`.

```
  CORE/couleur.gd      les huit couleurs, le filtre, et la seule règle de correspondance
  CORE/direction.gd    les huit directions et la seule formule de réflexion
  CORE/catalogue.gd    tout ce qui se pose, en données — et ce qu'il refuse d'écrire
  CORE/traceur.gd      le trajet d'un faisceau
  CORE/resolution.gd   le point fixe, les transformations en bloc, les événements
  CORE/monde.gd        l'état (grilles, objets), la seule porte pour le changer
  CLIENT/entrees.gd        autoload : la carte des entrées, clavier ET manette
  CLIENT/mise_en_page.gd   le séparateur, le balayage, les événements montrés, la fenêtre 2:1 — PUR
  CLIENT/ecran_partage.gd  les deux vues rendues à pleine taille, rognées à l'affichage
  CLIENT/fenetre.gd        autoload : la fenêtre recalée en 2:1, le plein écran
  CLIENT/niveau.gd         la carte peinte → les grilles et les objets de CORE — PUR (pas un Node)
  CLIENT/zone.gd           la scène d'une zone peinte : surface, grottes, et rien d'autre
  CLIENT/grotte.gd         une grotte peinte : son chemin de surface et sa coupe
  CLIENT/              (à venir) les faisceaux dessinés, l'entrée joueur, l'animation
  ART/                 le lot de tuiles temporaire, GÉNÉRÉ (tuiles.png, tuiles.tres)
  NIVEAUX/             les zones peintes (zone_depart.tscn)
  DEV_TOOLS/           tests et outils (en français), dont le greybox de l'écran partagé et sa mesure
  MARQUE/              titre.png, embleme.png — images générées, à redessiner en vectoriel
```

- **Deux sortes d'état** : STOCKÉ (grilles, objets — on le sauvegarde) et DÉRIVÉ (actifs, faisceaux —
  jamais). Un état dérivé qu'on sauvegarde est un état qui finit par mentir.
- **Une sauvegarde tient en quelques octets** : orientation des miroirs, état des objets, pouvoirs,
  position. C'est la version énigme du « une graine et quatre entiers par tour ».
- **Pas de `class_name` dans `CORE/`** : les tests tournent en `--script`, avant que l'éditeur ait
  indexé les classes globales. On `preload`, comme River Stones.
- **Tests** — `godot --headless --path D:/UnderMend --script res://DEV_TOOLS/test_lumiere.gd` (le moteur,
  248 vérifications) et `res://DEV_TOOLS/test_mise_en_page.gd` (l'écran partagé, 48), code de sortie 0
  ou 1. ⚠ Le headless ne rend rien : `mesure_balayage.gd` et le greybox se lancent AVEC fenêtre. La règle du §6 de River Stones s'applique telle quelle : un test vert ne prouve rien
  tant qu'on ne l'a pas vu échouer, et toute propriété structurelle se garde par un scénario
  CONSTRUIT, jamais espéré.

### Les niveaux peints — DÉCIDÉ : la carte est la vérité

**DÉCIDÉ (16 septembre 2026)** — on peint dans l'éditeur, et `CLIENT/niveau.gd` DÉDUIT de ce qui est
peint les grilles et les objets de `CORE`. Jamais l'inverse, et jamais les deux à la fois : une carte
peinte à côté d'un monde écrit en code, ce sont deux descriptions du même lieu, et elles divergent au
premier mur déplacé.

- **Le contrat d'une tuile**, et il tient en trois données personnalisées : `nom` (String), `mur`
  (bool) — ce qui arrête la lumière et le joueur — et `objet` (String) — un type du catalogue posé par
  cette tuile, sinon "". ⚠ **On ne cherche JAMAIS une tuile par sa position dans l'atlas, toujours par
  son `nom`** : le jour où un lot acheté remplace le lot temporaire, seules les positions changent.
- ⚠ **Une case non peinte est un MUR.** Le vide est plein : on ne peut pas oublier de fermer le bord du
  monde, et une carte à trous ne laisse pas fuir la lumière.
- ⚠ **La COLLISION est déduite de `mur`, jamais posée tuile par tuile.** `mur` dit ce qui arrête la
  lumière, la collision dit ce qui arrête les pieds : ce sont deux descriptions d'un même fait, donc
  elles sont générées ensemble (une couche physique, le carré plein) et vérifiées ensemble par un test
  qui lit le lot RÉELLEMENT livré. Les séparer donnerait un mur qui arrête la lumière et laisse passer
  le joueur — et ça ne se verrait qu'en jouant.
- ⚠ **Une entrée ne dit pas où elle mène : ON LE DÉDUIT.** La case peinte est cherchée dans le chemin de
  chaque grotte — celle qui passe dessous est la sienne, la colonne est l'indice dans la table, et la
  bouche est la première case non murée de cette colonne, en descendant. Le peintre creuse un puits, la
  lumière tombe où il l'a creusé. Deux grottes sous la même case rendraient une entrée ambiguë : c'est
  une erreur signalée.
- **La coupe d'une grotte doit faire exactement la longueur de son chemin**, et c'est vérifié, pas
  deviné : la table reste la seule vérité (§2). Le chemin vit sur le nœud de la grotte — case de départ
  et segments DROITS — et se règle dans l'inspecteur.
- **MESURÉ (test)** — `DEV_TOOLS/test_niveau.gd` peint ses cartes en code, saines et fautives :
  23 vérifications, sept mutations délibérées, toutes rouges — y compris l'indépendance à l'ORDRE de
  peinture, gardée par un scénario qui construit les deux ordres.
- **DEUX lots achetés, DEUX tilesets, et une table de rôles pour chacun** (16 septembre 2026) :
  `DEV_TOOLS/faire_surface.gd` bâtit `ART/surface.tres` sur le *Top-Down 32x32 RPG Asset Pack*,
  `DEV_TOOLS/faire_coupe.gd` bâtit `ART/coupe.tres` sur *Pixel Art Platformer — Village Props*. Le lot
  généré à la main (`faire_tuiles.gd`) ne sert plus qu'à dépanner.
  - ⚠ **TOUT le lot est déclaré, pas seulement les rôles nommés** : sinon on ne pourrait peindre que la
    poignée de tuiles qu'un outil a baptisées, sur des planches qui en comptent des centaines. Les cases
    anonymes arrivent sans nom. Pour la COUPE, `mur` se déduit de l'opacité (dans un lot de roche, une
    case pleine est de la roche) ; pour la SURFACE, non — l'herbe est opaque et se traverse — donc elles
    arrivent traversables, et une falaise peinte à la main doit être marquée dans l'éditeur.
  - ⚠ **PLANCHE DE CONTRÔLE, et c'est une méthode, pas un confort.** Chaque générateur écrit une image
    (`ART/planche_*.png`) montrant chaque rôle, les blocs RECONSTITUÉS, puis des CANDIDATS — des cases
    dont on hésite. On regarde avant de peindre une zone entière. C'est ce qui a montré qu'un trou
    d'entrée n'est pas une tuile mais un bloc de 2 × 2, et qu'un « sol de grotte » pris dans un lot de
    plateforme arrivait coiffé d'herbe.
  - Les tuiles de FOND ne sont pas choisies à l'œil : un outil repère celles qui sont opaques, peu
    contrastées et se raccordent à elles-mêmes bord à bord. C'est mesurable, donc c'est mesuré.
  - **MESURÉ (vu à l'image) — l'auto-tuilage natif est branché, et ce ne sont PAS les bitmasks de Godot 3.**
    Godot 4 a des TERRAINS : chaque tuile déclare ce que valent ses quatre COINS, et
    `set_cells_terrain_connect()` choisit ensuite la tuile qui se raccorde. Les chemins de terre ont donc
    des bords organiques au lieu d'escaliers, et n'ont plus à être rectangulaires. Mode
    `TERRAIN_MODE_MATCH_CORNERS` : ce lot décrit ses transitions par coins, pas par côtés.
    - ⚠ **Les seize cas ne sont pas saisis à la main, ils sont CALCULÉS.** Le lot range toutes ses
      transitions de la même façon — un cadre de 4 × 4 dont l'intérieur est plein, puis un bloc de 2 × 2
      pour les coins RENTRANTS — donc chaque coin se déduit de la position de la case dans le cadre. Une
      table de seize lignes saisie à la main est exactement l'endroit où l'on se trompe d'une case sans
      jamais s'en apercevoir. Ajouter une matière, c'est ajouter une ligne à `TRANSITIONS`.
    - **Un SECOND jeu de terrains, pour les RECOUVREMENTS** (gravier, sable). Ces ensembles-là ont le
      fond transparent : ils ne remplacent pas l'herbe, ils se posent par-dessus, et c'est le calque du
      dessous qui se voit sur leurs bords. Leur fond n'est donc pas un terrain mais « rien » (-1), et ils
      vivent sur un calque `Recouvrement`, entre le sol et les décors — que le chargeur ne lit pas,
      puisqu'on marche dessus. Les plages et les plaques d'entrée en sortent, sans un seul angle droit.
    - ⚠ **LE PIÈGE, ET IL COÛTE DEUX PASSES SI ON NE LE CONNAÎT PAS : le terrain PROPRE d'une tuile est
      la MATIÈRE à laquelle elle appartient, jamais la valeur d'un de ses coins.** Quand on peint un
      terrain, Godot ne retient comme candidates que les tuiles dont le terrain propre est celui qu'on
      peint. Une tuile de bord déclarée « rien » disparaît donc des candidates : la moitié des bords
      manque, le raccord retombe sur des tuiles approchantes, et le rivage devient un peigne de dents
      carrées parfaitement régulières. ⚠ **Aucune erreur n'est signalée** — c'est la planche
      `ART/planche_terrains.png`, qui dessine les quatre coins déclarés de chaque tuile, qui l'a montré.
    - ⚠ **OUVERT — la rive du LAC elle-même.** L'eau reste un aplat opaque posé sur le sol : elle
      rencontre le sable par une arête droite. Ses ensembles à elle sont des cadres opaques (de la terre
      percée d'un trou d'eau), donc une troisième façon de faire, à traiter à part.
  - ⚠ **OUVERT — une galerie n'a pas encore de bords en haut et en bas.** Le lot de côté est fait pour
    l'extérieur : tous ses bords supérieurs sont coiffés d'HERBE, ce qui n'a aucun sens sous terre. Les
    extrémités d'une galerie sont creusées avec les deux parois latérales du lot ; le plafond et le sol
    restent de la roche pleine, donc plats. À reprendre à la main, ou avec un lot de grotte.
  - ⚠ **OUVERT — la permutation de palette (§5) ne tient plus telle quelle.** Elle supposait une palette
    restreinte et PARTAGÉE ; les lots achetés n'en ont pas. Deux issues : une transformation de couleur
    par shader (teinte, saturation, luminosité) qui marche sur n'importe quel art mais ne permute rien ;
    ou deux jeux de tuiles, donc deux fois le travail à chaque décor. À trancher avant de dessiner le
    monde intriqué.
- **La zone de départ est une première passe générée** (`DEV_TOOLS/faire_zone.gd`), faite pour être
  repeinte à la main. L'outil valide sa sortie par le chargeur avant d'écrire — un outil qui ne sait pas
  produire une carte valide n'a pas à la sauvegarder — et refuse d'écraser une zone existante.
- **OUVERT — les objets du catalogue ne sont pas encore peignables**, seules les entrées le sont.
  Miroirs, vitres et cristaux viendront avec la première énigme (§8, étape 3), et poseront leur propre
  question : l'orientation d'un miroir, est-ce huit tuiles, ou une tuile et une propriété ?

### Les entrées — DÉCIDÉ : clavier ET manette, toujours les deux

**DÉCIDÉ (16 septembre 2026)** — le jeu se joue ENTIÈREMENT au clavier (ZQSD, Maj, Espace) ou
ENTIÈREMENT à la manette, et Jordan teste indifféremment avec l'un ou l'autre.

- ⚠ **La carte des entrées vit dans `CLIENT/entrees.gd`, PAS dans `project.godot`.** Une seule
  autorité, et celle-là garde ses commentaires — `project.godot` les perd au premier enregistrement.
  L'InputMap est rempli au démarrage par un autoload. ⚠ **L'ORDRE des autoloads ne se garantit pas** —
  l'éditeur le réécrit quand il enregistre `project.godot` — donc `fenetre.gd` vérifie que l'action
  existe avant de s'en servir, au lieu de compter sur qui se charge en premier.
- ⚠ **On lie des POSITIONS de touches (`physical_keycode`), jamais des lettres gravées.** Godot nomme
  les positions d'après un clavier américain : W, A, S, D. Sur un clavier français, ces positions SONT
  Z, Q, S, D. Une seule ligne sert donc ZQSD ici et WASD ailleurs, et personne ne reconfigure rien.
- **MESURÉ (test) — toute action de JEU a au moins une touche ET au moins un bouton ou un axe.** La
  promesse « les deux périphériques » est ainsi STRUCTURELLE : on ne peut pas ajouter une action
  jouable à un seul périphérique sans faire rougir `DEV_TOOLS/test_entrees.gd`. Le même test garde les
  positions contre les lettres, l'absence de liaison partagée entre deux actions, et l'effacement des
  liaisons PÉRIMÉES quand on réinstalle la carte — 73 vérifications, cinq mutations délibérées, toutes
  rouges.
  - ⚠ **Une sixième n'a PAS rougi, et c'est écrit ici** : remplacer `ZONE_MORTE` par le défaut de Godot
    ne change rien, puisque c'est la même valeur (0,2) — cette vérification ne garde donc que contre une
    valeur aberrante. De même, réinstaller ne peut pas DOUBLER une liaison (Godot ignore un événement
    déjà présent dans une action) : le vrai risque est la liaison périmée, et c'est elle qu'on teste.
- **Les actions SYSTÈME (le plein écran) restent au clavier**, et c'est voulu : pas de bascule par un
  pouce égaré sur une manette posée.
- **PROPOSÉ — la carte de départ**, zone morte 0,2 (qui est aussi le défaut de Godot) : marcher (ZQSD ou flèches, stick gauche ou croix),
  courir (Maj, B ou gâchette droite — maintenu, pas basculé), agir (Espace ou A) pour descendre par une
  entrée et remonter, et plus tard prendre et parler.
- **OUVERT — orienter un miroir** (§4) n'a pas encore d'entrée : il y faudra deux sens, peut-être deux
  crans, et le « regard croisé » qui vise un miroir de l'AUTRE vue. À trancher quand les miroirs
  deviendront jouables (§8, étape 3).

## 7. Langue — héritée

La langue du jeu est l'**anglais américain** : toute chaîne qu'un joueur peut lire est en anglais, en
dur dans le code. Restent en français les commentaires, la documentation, les `print()` et tout
`DEV_TOOLS/`. En cas de doute : *un joueur peut-il la lire à l'écran ?*

## 8. Ordre de travail

Le risque n'est pas la durée, c'est la **lisibilité à deux vues** : dessiner un beau monde et
découvrir qu'on ne comprend pas ce qu'on voit dans la bande.

1. ~~**Le moteur de lumière dans `CORE/`**, avec ses tests~~ — fait : miroirs, vitres, lasers,
   couleurs, activables, dépendants, entrées (§4).
2. ~~**L'écran partagé**~~ — fait (§3) : fenêtre 2:1, plein écran à bandes noires, fenêtré recalé,
   balayage interruptible et mesuré, surface seule quand la grotte n'a rien à dire, les deux vues
   toujours sous terre. ⚠ **Reste à JUGER avec Jordan, dans le greybox** : le toucher du balayage, le
   trait de démarcation, le glisser de la fenêtre à la souris, et la question des cinq cases.
3. **Les faisceaux de `Monde.faisceaux` dessinés dans les deux vues**, et une première énigme jouable —
   deux miroirs, une vitre, un pilier de glace, un œil : le joueur tourne, la lumière suit. C'est là
   que les cas limites du §4 se jugent à l'œil.
4. **Un nœud et son onde** (§5).
5. **Le pixel art, seulement ensuite.**
