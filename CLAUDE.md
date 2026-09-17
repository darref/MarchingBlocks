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

### DÉCIDÉ — le rendu : le monde intriqué est le monde VIDÉ DE SA COULEUR

**DÉCIDÉ (Jordan, 16 septembre 2026)** — le monde des ténèbres est un SHADER qui passe la couleur en
NIVEAUX DE GRIS. Pas de permutation de palette : donc aucune palette restreinte à exiger d'un lot acheté,
n'importe quel art y passe, et il n'y a toujours qu'un seul jeu de tuiles à dessiner.

Un shader de tuiles lit une texture d'état à un texel par case et le front de l'onde ; les changements de
FORME (lianes, racines, nœuds visibles) vivent sur un calque à part.

⚠ **CE QUE LE GRIS COÛTE, ET QU'IL FAUT TRANCHER AVANT DE L'ÉCRIRE : dans ce jeu, la couleur EST la
mécanique** (§4). Un rouge fait fondre la glace, un bleu éteint le feu, un violet sur un œil jaune ne fait
rien. Si le shader vide TOUT l'écran de sa couleur, les faisceaux et leurs cibles deviennent
indiscernables, et l'énigme devient injouable là où elle devrait être la plus lisible.
**PROPOSÉ — le gris s'arrête donc au DÉCOR** : les faisceaux, les activables et tout ce qui réagit à la
lumière gardent leur couleur. Sur un monde gris, ils ne ressortiront jamais aussi bien.

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
    - ⚠ **TROIS FAÇONS D'ÊTRE UN ENSEMBLE, et confondre les deux dernières coûte une manche.** Un
      ensemble OPAQUE (terre sur herbe) remplace la matière du dessous. Un RECOUVREMENT (gravier, sable)
      a le fond transparent et se pose par-dessus. Une NAPPE (les trois verts du haut) a sa matière à
      l'EXTÉRIEUR du cadre et le TROU au centre : ce n'est pas une tache à poser, c'est une nappe à
      peindre partout, dont ce qu'on ne peint pas devient une clairière. D'où la carte actuelle : sol en
      herbe sombre, nappe d'herbe claire par-dessus, taches = trous.
    - ⚠ **Une nappe a besoin de sa tuile PLEINE**, et ces ensembles-là n'en contiennent pas — leurs seize
      cases sont toutes des bords, puisque leur centre est le trou. Sans une case unie à quatre coins de
      matière, Godot n'a rien à poser au milieu et recycle des tuiles de bord : apparaissent alors des
      rectangles alignés sur la grille. La case unie est juste sous l'ensemble, dans la planche.
    - ⚠ **Une tuile dont les quatre coins valent « rien » n'existe pas** : c'est le trou, entièrement
      transparent. On la saute — exiger une tuile pour représenter l'absence de tuile n'a pas de sens.
    - **MESURÉ (agrandissement quadrillé)** — à petite taille, un contour organique et le grain d'un lot
      se confondent avec des rectangles de tuiles. On agrandit la capture avec une grille de 32 px : si
      les taches tombent sur les cases, c'est un défaut ; sinon, c'est la texture. ⚠ Ne jamais trancher
      ce genre de doute à l'œil nu sur une image réduite.
    - ⚠ **LA RÈGLE DES CALQUES, ET ELLE PASSE AVANT LA PEINTURE.** Better Terrain ne résout les voisinages
      qu'À L'INTÉRIEUR d'un calque : la pile de calques et la façon de peindre se commandent donc l'une
      l'autre. La règle a DEUX branches, et c'est l'ART qui tranche, pas le goût :
      - **Art de transition OPAQUE → MÊME calque.** Deux matières dont la bordure est dessinée en entier
        (la terre sur l'herbe, l'eau sur ses berges) se fondent sur un seul plan, et Better Terrain fait
        le reste.
      - **Art de transition TRANSPARENT → calque SÉPARÉ, au-dessus.** Les trois ensembles d'herbe et ceux
        de sable et de gravier ont des bordures ajourées : ce qu'on voit par leurs trous, c'est le calque
        du DESSOUS. Leur transparence n'est pas décorative, elle est PORTANTE.
      - ⚠ **MESURÉ, et à mes dépens** : j'avais cru simplifier en fondant les deux herbes sur un seul
        calque — « le trou n'est pas rien, c'est l'autre herbe ». La capture a répondu : clairières en
        escalier, et blocs sombres le long du lac, là où la transparence ne révélait plus que le vide. La
        nappe n'était pas de l'accrétion, elle était imposée par le lot.
      - Un calque de plus se justifie aussi quand l'AUTORITÉ diffère : les objets du catalogue, que
        `CLIENT/niveau.gd` lit comme des règles et non comme du décor.
      - ⚠ **UN MOT, UNE CHOSE.** Le rôle « herbe » (la tuile) et le terrain « herbe » (Better Terrain)
        doivent désigner la MÊME matière. Ils ont un temps désigné l'herbe claire d'un côté et la sombre
        de l'autre : de quoi peindre l'inverse de ce qu'on croit, sans qu'aucune erreur ne le signale.
    - **DÉCIDÉ (Jordan, 16 septembre 2026) — l'auto-tuilage passe à BETTER TERRAIN**, le système natif
      est abandonné. Raison mesurée : le natif exige un match EXACT et n'a que deux modes exclusifs
      (coins OU côtés) ; un lot acheté n'a jamais toutes les pièces, et il retombe alors sur la tuile
      pleine sans un mot d'erreur. Better Terrain accepte les HUIT voisinages à la fois, choisit au
      meilleur score — donc dégrade au lieu de s'effondrer — et connaît les CATÉGORIES : l'eau borde
      « tout ce qui est ferme » (herbe, terre, sable, gravier) au lieu de la seule herbe.
      - ⚠ **Il s'utilise hors éditeur**, mais il faut l'INSTANCIER et l'AJOUTER À L'ARBRE : ses caches
        appellent `add_child()`. Ses données vivent dans les métadonnées du TileSet et des TileData, et
        survivent à l'aller-retour sur disque (vérifié en ligne de commande).
      - **Peindre se fait en DEUX temps** : `set_cells()` pose, `update_terrain_cells()` résout. Poser ne
        raccorde rien, et raccorder sans avoir posé ne voit rien.
      - **Les VARIANTES PONDÉRÉES** (`TileData.probability`) : plusieurs cases pleines par matière, tirées
        au sort, la référence restant dominante. Un sol fait d'une seule tuile répétée montre son damier
        dès qu'on recule. ⚠ **Mais une variante ne CRÉE pas de la variété, elle la RÉVÈLE si le lot en a** :
        très visible sur l'herbe (cinq cases distinctes), invisible sur le sable (les cases du lot y sont
        le même dessin répété). ⚠ Et une variante doit partager le `mur` de sa référence, sinon on sème de
        l'eau où l'on marche, ou des murs invisibles dans une allée.
      - ⚠ **Les SYMÉTRIES : essayées, retirées.** Retourner une bordure multiplierait la couverture, mais
        les motifs de ce lot ont un haut et un bas — la berge est éclairée par le dessus. Pivotés, ils
        donnent des blocs de roche qui flottent dans l'herbe. À ne garder que pour un motif sans
        orientation : un gravier, une mousse.
    - ⚠ **OUVERT — LA RIVE DU LAC RÉSISTE, et voici ce qui a été essayé pour que personne ne recommence.**
      L'eau est déclarée comme terrain et ses bords viennent bien de sa planche, mais le rivage sort en
      MARCHES, avec des fragments de bord isolés au lieu d'un trait continu. Trois approches, trois échecs :
      1. **coins, sans coins rentrants** — la planche de l'eau n'en fournit aucun (elle a des cadres, des
         baies de deux cases, un îlot rond). Un lac convexe s'en passe, un lac organique en réclame partout ;
      2. **côtés** (`TERRAIN_MODE_MATCH_SIDES`, jeu de terrains séparé, puisqu'un jeu n'a qu'un mode) — les
         diagonales cessent de compter, mais les fragments isolés demeurent ;
      3. **côtés sur contour LISSÉ** — un bord bruité case par case fabrique des saillies d'une case, qu'un
         cadre de seize tuiles ne sait pas border ; les retirer a réduit les cas impossibles, sans suffire.
      **Ce qui marchait** : un lac RECTANGULAIRE, dont la rive était propre et complète — mais qui se lit
      comme une piscine. Les issues restantes : assumer un plan d'eau anguleux ; peindre la rive à la main
      dans l'éditeur (le TileSet expose toutes les cases) ; ou prendre un lot d'eau qui fournisse un jeu
      complet de raccords. ⚠ Décision de Jordan, pas une quatrième tentative à l'aveugle.
      - **DÉCIDÉ (Jordan, 16 septembre 2026) — on repeint la zone de départ À LA MAIN**, et les
        générateurs redeviennent ce qu'ils auraient dû rester : une première passe, pas une autorité.
    - ⚠ **CE QU'EST UN LOT « COMPLET », ET ÇA SE COMPTE AVANT D'ACHETER.** Deux lots achetés, deux échecs,
      la même cause : ils livrent un **cadre de 4 × 4 (16 tuiles)**, parfois plus quatre coins rentrants.
      Ça ne borde qu'une tache **convexe**. Un contour organique réclame le **jeu blob de 47 tuiles** —
      les 256 voisinages à huit voisins, dédoublonnés. Notre lot d'eau n'a AUCUN coin rentrant
      (`rentrants: (-1, -1)` dans `faire_surface.gd`) : la rive en escalier était perdue d'avance, et
      aucun réglage ne pouvait la sauver. Ce qu'il faut chercher, par ordre de fiabilité :
      1. **format autotile RPG Maker A2/A4** — des blocs de 2 × 3 « mini-tuiles » qui se déplient
         mathématiquement en 47 cas, donc **complets par construction** ;
      2. les mots **« 47-tile »**, **« blob »**, **« complete autotile »**, **« Godot terrain ready »** ;
      3. **des coins RENTRANTS visibles** sur l'aperçu — un carré 4 × 4 nu est le lot qui échoue ;
      4. **des transitions par PAIRE de matières**, pas seulement matière-contre-rien. Notre lot avait
         raison là-dessus (deux jeux de terre, un par herbe) ; c'est moi qui n'en avais déclaré qu'un,
         et la couverture est passée de 12/36 à 36/36 le jour où j'ai déclaré le second.
      ⚠ **Sur l'aperçu d'une boutique : 4 × 4 seul = incomplet ; bloc 2 × 3 ou 47 tuiles = complet.**
    - **LES MASSIFS — DÉCIDÉ (17 septembre 2026), et mesuré de bout en bout.** Le lot range quatre
      familles de plateau, identifiées non pas à l'œil mais par la couleur moyenne de leur bloc, qui
      tombe sur nos terrains **à un 255ᵉ près** : `#7b9728` herbe claire, `#814f2e` terre, `#59832b`
      herbe sombre, `#d7b775` sable. Ce ne sont pas de nouvelles matières, ce sont nos sols en relief.
      - **Les trois premières sont le MÊME jeu** à six lignes d'écart (114 cases chacune, zéro case en
        propre, cartes d'opacité identiques caractère par caractère). Déclarer une famille les déclare
        toutes les trois.
      - ⚠ **Le sable n'est pas un massif** : 65 cases contre 114, et **rien sous son bloc** — aucune
        bande de falaise. Ce n'est pas un trou du lot, c'est le lot qui dit qu'une dune n'a pas de paroi
        verticale. Il reste un RECOUVREMENT à plat, qui marche déjà à 0 % de repli.
      - ⚠ **PAS DE FORK DE BETTER TERRAIN, et la question s'est posée.** `create_terrain_changeset()`
        accepte un `Dictionary` `case → terrain` mêlant PLUSIEURS terrains : le plateau et sa falaise
        partent en une passe, la couture résolue dedans. L'addon se pilote comme une bibliothèque. Et il
        n'écrit JAMAIS dans une case qu'on ne lui a pas donnée (`update_terrain_cells` ne boucle que sur
        `cells`, élargi d'un anneau par `_widen` pour refermer les coutures) — donc **peindre un plateau
        ne peut pas créer ses falaises**. Cette dérivation est à NOUS, exactement comme `_est_plage()`
        déduit la plage du lac : `falaise(x,y) = plateau(x, y-1) and not plateau(x, y)`.
      - **`MATCH_VERTICES`, et le peering est DÉRIVÉ DES PIXELS.** Ce gabarit ne suit pas la convention
        « cadre 4 × 4 + rentrants 2 × 2 » des ensembles de sol — ses rentrants sont dispersés entre x4 et
        x9. On échantillonne donc les quatre coins de chaque case (8 × 8 px) et l'on classe matière /
        roche / vide. **Aucune table de géométrie écrite à la main**, donc aucune case décalée en silence.
      - ⚠ **Les signatures se dérivent sur l'HERBE CLAIRE et se réutilisent par décalage.** Pour la
        famille brune, matière et roche sont toutes deux brunes : le classeur y échouerait. Les formes
        étant identiques (405 px d'écart sur 116 736), on ne classe jamais la famille brune.
      - ⚠ **ESCALIERS ET PENTES SONT DES BLOCS, PAS DU TERRAIN — et c'est mesuré, pas supposé.** Un
        escalier n'est pas décidé par son voisinage mais par l'endroit où l'on veut monter : c'est une
        intention de niveau. Déclarés comme terrain, Better Terrain les choisissait comme **arêtes
        ordinaires** ; la couverture restait à 0 % de repli et le rendu aurait montré des marches rayées
        au bord d'un plateau. ⚠ **Une pièce posée « avec succès » peut n'avoir rien à faire là** — d'où
        le recensement des cases d'atlas employées, à côté du taux de repli.
      - ⚠ **UNE TUILE D'INTÉRIEUR DOIT ÊTRE UNIE : une seule couleur, ou plusieurs.** `MATCH_VERTICES`
        ne regarde que les COINS, donc une marche d'escalier dont les quatre coins sont de l'herbe est,
        pour lui, un aplat d'herbe. Deux erreurs successives, toutes deux corrigées par la CAPTURE et non
        par un compteur :
        1. j'ai gardé les « presque-aplats » (90 à 94 % de couleur dominante) comme variantes pondérées,
           au nom du damier qu'une tuile unique répétée fabrique. La capture a montré une vingtaine de
           **mouchetures** semées dans les plateaux : ce ne sont pas des variations d'herbe, ce sont des
           marques. C'est la réserve que cette charte portait déjà — *une variante ne CRÉE pas de la
           variété, elle la RÉVÈLE si le lot en a* ;
        2. j'ai justifié le seuil de 90 % par « un saut du lot, pas un chiffre rond ». C'était vrai de
           l'herbe et **faux de la terre** : à formes identiques, les textures diffèrent (61,5 % des
           pixels), la coupure tombe à 90 % pour les herbes et à 87 % pour la terre. Un seuil calibré sur
           l'une et appliqué à l'autre, c'est la faute des deux jeux de terre refaite. « Une seule
           couleur » ne se calibre pas.
      - ⚠ **CE QUI EST DU TERRAIN, ET CE QUI N'EN EST PAS — la carte donnée par Jordan, le 17 septembre.**
        Par famille, en coordonnées relatives :
        ```
          x0..3, rangées +0..+3   la SURFACE du plateau, un cadre de 4 × 4   (16 tuiles)
          x4..5, rangées +0..+1   les quatre COINS RENTRANTS, un par orientation ( 4 tuiles)
          x0..3, rangées +4..+5   la FALAISE, dérivée et non raccordée
          x6 et au-delà            PENTES et ESCALIERS, patchés à la main
        ```
        **Vingt tuiles de terrain, pas davantage.** ⚠ J'en avais déclaré 44, puis 24 : `x4..5` sur les
        rangées +2 et +3 sont des **doublons de bords** — même signature de coins que les bords du cadre,
        à poids égal — et Better Terrain en piochait un pour un bord droit. Il avait raison, ce SONT des
        bords ; l'incohérence graphique sur les flancs venait de ma déclaration, pas de son choix.
      - **MESURÉ** — 20 tuiles : zéro case prise hors du 4 × 4 sur un rectangle, les quatre angles d'une
        croix servis chacun par un rentrant DISTINCT, l'angle d'un L par le sien. Et vu à l'image : le
        cadre se ferme, l'angle rentrant se raccorde sans cassure.
      - **MESURÉ (contre le tileset LIVRÉ)** — 0 % de repli et 0 case sans terrain pour les quatre
        familles, sur neuf formes : disque, **anneau**, **L**, **croix**, bandes de deux puis d'**une
        seule case**, **deux blocs se touchant par un coin**, escalier de blocs, damier lâche. ⚠ Le disque
        seul ne prouve rien : c'est une frontière convexe, et c'est ce qui m'avait fait lire 36/36 pendant
        que la carte réelle était pleine de carrés bruts.
      - ⚠ **DEUX PLATEAUX NE DOIVENT PAS SE TOUCHER PAR UN SEUL COIN.** Les deux combinaisons DIAGONALES
        (`RMMR`, `MRRM`) n'existent pas dans le lot — sur seize combinaisons de coins, neuf seulement sont
        fournies. Au contact, Better Terrain prend donc le meilleur score disponible : ce n'est pas une
        tuile pleine, donc **le compteur lit 0 % de repli**, et le rendu est pourtant une **coupe droite**,
        sans jonction. Règle de peinture, ou pièce à dessiner à la main.
      - ⚠ **LA LEÇON GÉNÉRALE, ET ELLE S'EST REFERMÉE TROIS FOIS DANS LA MÊME JOURNÉE : un compteur vert
        ne dit jamais qu'une tuile est à SA place.** Les escaliers se faisaient choisir comme arêtes
        ordinaires (couverture parfaite, marches rayées au bord d'un plateau) ; les « presque-aplats »
        passaient pour des variantes (couverture parfaite, mouchetures dans les champs) ; le contact en
        diagonale se coupe net (couverture parfaite sur NEUF formes). À chaque fois, seule une image l'a
        montré. **Une mesure de couverture répond à « a-t-on posé quelque chose », jamais à « est-ce la
        bonne chose ».**
      - **Le calque `Massifs` vit entre `Recouvrement` et `Props`** : au-dessus de ce que ses bords
        ajourés révèlent (presque toutes ses cases sont partiellement transparentes — mesuré), mais sous
        les décors, sans quoi un arbre planté sur un plateau aurait l'air enterré dans sa lèvre.
      - ⚠ **LA FALAISE SE DÉRIVE, ELLE NE S'AUTO-TUILE PAS — corrigé par Jordan le 17 septembre, et
        j'avais tout mis à l'envers.** J'avais rangé la paroi DANS le terrain du massif et laissé Better
        Terrain la choisir : elle se peignait alors SUR la dernière rangée du plateau au lieu de PENDRE
        en dessous, d'où la bande d'herbe qu'on voyait entre le plateau et l'escalier. Une falaise n'est
        pas décidée par son voisinage, elle est décidée par **le bord qu'elle prolonge** — c'est la même
        forme de règle que `_est_plage()`, qui déduit la plage du lac.
        - **ON MARCHE SUR TOUT LE 4 × 4** (Jordan) : plus aucun mur dans le terrain du plateau. Le liseré
          est une lisière, pas une paroi. **MESURÉ** : 62 cases praticables = 56 de massif + 6 de marches.
        - **TROIS RÔLES × DEUX RANGÉES** : gauche, milieu, droite — et le lot livre **deux milieux**, que
          la mesure dit interchangeables dans les deux ordres et avec eux-mêmes (joints de 0,013 à 0,069,
          là où un joint franc entre deux pièces vaut 0,56). Le milieu se répète, le pied touche le sol.
        - ⚠ **UNE FALAISE BLOQUE LE SOL, PAS L'ALTITUDE.** Elle pend dans des cases qui sont au niveau du
          sol : on ne marche pas dedans et la lumière n'y passe pas (une seule donnée pour les deux, §6).
          Je l'avais murée à l'altitude 1 — ce qui mettait la paroi **en l'air** au lieu de la mettre en
          travers du chemin. **MESURÉ** : les 10 cases de paroi de la zone d'essai murent bien la grille 0.
        - ⚠ **Retirer la paroi du terrain n'a RIEN cassé** : 0 % de repli sur les six formes, pour les
          quatre familles. Ces tuiles ne servaient donc jamais de bord — la correction retire du code mort
          autant qu'elle corrige un défaut.
        - ⚠ **Les cases de paroi se RÉSERVENT** (`_pris`) : les bosquets sont semés après le plateau et ne
          consultent que ça, donc sans la réservation **un arbre pousse sur la falaise**. Repéré par un
          audit des murs par origine, pas à l'œil. ⚠ Et le générateur ne REPLACE pas un bosquet refusé, il
          l'abandonne : la réservation coûte un arbre (décor passé de 127 à 121 cases murées).
        - **OUVERT — la hauteur d'une falaise est fixée à DEUX rangées** (milieu + pied), faute de quoi
          que ce soit dans la carte qui dise qu'un plateau est haut de trois. Le lot sait répéter le
          milieu ; le jour où une hauteur se peint, c'est `_descendre_la_falaise()` qui la lira.
      - **LE REPORT DU SABLE — FAIT (17 septembre 2026), et c'est une planche DÉRIVÉE.** Le lot ne livre
        au sable ni falaise ni la moitié de ses pièces ; on le **reconstruit** depuis l'herbe claire par
        une table de substitution, et `ART/massif_sable.png` est écrite par `faire_surface.gd`.
        ⚠ **Cette image ne se retouche JAMAIS à la main** : ce serait une seconde description du même
        dessin, et elle divergerait au premier réglage de la table. ⚠ Elle demande un `--import` entre sa
        première écriture et son chargement comme texture, comme `surface_dessinees.png`.
        - **La roche va à l'IDENTITÉ** (onze bruns partagés, mesuré) : pas un pixel touché. Seuls les
          quatre verts se traduisent, plus `#22463d`, un vert-bleu d'ombre qui n'est ni herbe ni roche.
        - ⚠ **LE PLAT S'ÉPINGLE CONTRE LE PLAT.** Classées par luminosité, les deux rampes se décalent
          d'un cran — le plat de l'herbe tombait sur la première ombre du sable, et son rehaut prenait le
          plat. Tout glissait, et la couverture avait pourtant l'air bonne.
        - ⚠ **UN CONTRASTE NE SE TRANSPOSE PAS D'UNE MATIÈRE À L'AUTRE.** Le sable n'a pas de rehaut : je
          l'ai d'abord fabriqué en appliquant le RAPPORT canal par canal de l'herbe, ce qui a saturé le
          rouge à 255 et donné un liseré criard. Le bon rehaut se prend en **prolongeant la rampe du
          sable** (`#d7b876` → `#cfab6f`) d'un pas vers le haut : `#dfc57d`.
        - ⚠ **UNE RÈGLE PLUTÔT QU'UNE LISTE, pour les teintes rares.** Un relevé de palette ignore ce qui
          apparaît moins de 200 fois : vingt pixels verts échappaient ainsi à la table, dont quatorze du
          même ton — une tache verte sur une tuile de sable. Tout vert survivant est désormais reversé
          dans la rampe du sable par luminosité.
        - **MESURÉ** — 48 tuiles, 4 parois, 9 écartées : exactement les chiffres de l'herbe claire, ce qui
          est le bon résultat pour sa recolorisation. 0 % de repli sur les six formes.
      - ⚠ **LA ROCHE RESTE CELLE DE L'HERBE — variante réchauffée ESSAYÉE, PUIS REJETÉE.** Posé, le sable
        m'a paru porter « un mur de roche » plutôt qu'une falaise de sable : ses 65 cases natives emploient
        des bruns plus chauds (`#946837`, `#6a3321`, `#54231c`) que la famille d'herbe. J'ai donc bâti la
        variante et je l'ai regardée côte à côte — **elle est pire**. La bande rocheuse y perd ses creux
        sombres et ses arêtes éclairées, tout s'effondre vers un brun moyen, et la frontière entre la
        surface et la paroi devient molle. ⚠ **Le défaut était réel, le remède supprimait le contraste qui
        fait lire une falaise.** Une observation juste ne valide pas la correction qu'on en tire.
      - **L'ÉLÉVATION EST JOUABLE — DÉCIDÉ (Jordan, 17 septembre 2026).** Le joueur monte.

### L'altitude — DÉCIDÉ : un plateau est une GRILLE, un escalier est un PORTAIL

⚠ **`CORE` N'APPREND RIEN.** Ni altitude, ni troisième axe, ni ordre de mise à jour. `CORE/monde.gd` sait
déjà tenir plusieurs grilles reliées par des portails — c'est ce qui fait marcher les grottes — et un
plateau est exactement ça : un lieu où l'on est ou l'on n'est pas, relié au sol par des passages. La
lumière fait alors gratuitement ce qu'il faut : **un rayon au sol ne traverse pas un plateau, un rayon
sur le plateau ne descend pas au sol.**

- **La grille du dessus porte l'identifiant 1000**, haut exprès : les grottes prennent 1, 2, … dans
  l'ordre de l'arbre et se marcheraient dessus.
- ⚠ **« UNE CASE NON PEINTE EST UN MUR » VAUT AUSSI EN HAUTEUR.** À l'altitude 1, le vide n'est pas du
  sol, c'est du vide — sans quoi on marcherait dans les airs partout où aucun massif n'est posé. Et la
  PAROI d'un massif est murée là-haut aussi : on ne marche pas sur la tranche d'une falaise.
- **Un escalier se reconnaît à son NOM**, jamais à sa position dans l'atlas (§6).
- ⚠ **CE QUI RELIE, ET UN TEST ME L'A APPRIS.** Ma première règle disait « le dessus est du plateau, le
  dessous est du sol praticable ». Or **le sol est praticable PARTOUT**, y compris sous un massif : cette
  condition ne discriminait rien, et tout escalier peint au milieu d'un plateau fabriquait un passage
  vers nulle part. Un escalier relie quand son dessus est le plateau et que **son dessous n'en est
  plus** — c'est-à-dire quand il est posé au BORD. Le peintre n'écrit donc aucune liaison : il pose un
  escalier au bord de son plateau et le lien s'en déduit, exactement comme une entrée déduit sa grotte du
  chemin qui passe dessous.
- **MESURÉ (test)** — `DEV_TOOLS/test_niveau.gd`, 77 vérifications, quatre mutations délibérées, toutes
  rouges : condition du bord retirée (le passage fantôme revient), grille non créée, altitude 1 non
  murée (on marche dans les airs), sens des portails inversés.

⚠ **CE QUE ÇA OUVRE, ET QU'IL FAUDRA TRANCHER :**

- **deux grilles partagent désormais les mêmes x, y.** La table du §2 — « une colonne de grotte par case
  de surface » — ne dit plus **sous quelle altitude** passe une grotte. Tant qu'aucune grotte ne court
  sous un plateau, la question dort ; le jour où l'une le fait, il faudra dire ce que sa table désigne ;
**Ce qui se JOUE — le greybox (17 septembre 2026)**

- ⚠ **UN TROISIÈME CORPS, PAS UNE TROISIÈME VUE.** L'écran n'a que deux vues, surface et grotte (§3) ;
  un plateau, c'est la MÊME vue de dessus à une hauteur différente. Le corps du plateau vit donc dans la
  vue de surface à côté de l'autre, et **un seul des deux bouge** — `pos_surface` se relit sur celui-là.
  Deux corps qui avanceraient ensemble seraient deux vérités sur « où est le joueur ».
- **`altitude` est un ENTIER, pas un second booléen** : il y a trois lieux possibles, et un booléen n'en
  tient que deux. C'est aussi ce qui laissera la place à une altitude 2 sans tout reprendre.
- **Les collisions basculent comme pour les grottes** — `Sol` et `Props` à l'altitude 0, `Massifs` à
  l'altitude 1 — parce que les deux étages occupent les mêmes coordonnées et que le corps se cognerait
  aux murs de celui où il n'est pas. ⚠ `Massifs` peut MANQUER (une zone peinte avant l'altitude n'en a
  pas) et ce n'est pas une faute : on reste au sol.
- **L'escalier passe avant l'entrée** dans `agir` : on est en surface dans les deux cas, et une entrée
  peinte près d'un escalier ferait sinon descendre quand on voulait monter.
- ⚠ **MONTER D'UN CRAN NE MET PAS SUR LE PLATEAU**, et c'est assumé : `vers_haut` désigne la marche du
  dessus. C'est la MARCHE À PIED qui achève le trajet. **MESURÉ** sur la zone d'essai : de la marche
  d'arrivée jusqu'au cœur du massif, la colonne est praticable à l'altitude 1 — donc marcher vers le nord
  y mène par construction. La bande d'herbe qu'on voit entre le plateau et l'escalier est la PROFONDEUR
  de la falaise, pas un décalage.
- **MESURÉ (journal)** — maintenir « agir » ne fait pas osciller le joueur entre les deux altitudes :
  l'action se déclenche sur le front. Une seule montée par pression.
- ⚠ **`DEV_TOOLS/faire_zone.gd --sortie=` et le greybox `--zone=`** permettent d'essayer une carte sans
  toucher à celle qu'on repeint. Le plateau d'essai est généré, pas peint à la main.
- ⚠ **LE RELAIS `_console.exe` AVALE LA SORTIE DANS UN TUBE.** Un lancement du greybox rendait un écran
  vide alors qu'il fonctionnait parfaitement — la capture avait bien été écrite. On redirige donc la
  sortie vers un FICHIER, jamais vers un `|`. (La note de projet le disait déjà pour la fenêtre ; c'est
  vrai aussi de la console.)
- **la projection d'une grotte** (§2) est calculée en coordonnées de surface, donc elle se dessinera au
  même endroit quelle que soit l'altitude du joueur. À juger au greybox.
  - ⚠ **OUVERT — une galerie n'a pas encore de bords en haut et en bas.** Le lot de côté est fait pour
    l'extérieur : tous ses bords supérieurs sont coiffés d'HERBE, ce qui n'a aucun sens sous terre. Les
    extrémités d'une galerie sont creusées avec les deux parois latérales du lot ; le plafond et le sol
    restent de la roche pleine, donc plats. À reprendre à la main, ou avec un lot de grotte.
  - **TRANCHÉ (§5) — le monde intriqué sera un shader en NIVEAUX DE GRIS**, et non une permutation de
    palette. Les lots achetés n'ont donc aucune contrainte de palette à respecter : c'était ma réserve
    d'achat, elle tombe. ⚠ Reste la règle qui va avec : le gris s'arrête au décor, les faisceaux gardent
    leur couleur, sans quoi l'énigme ne se lit plus.
- **La zone de départ est une première passe générée** (`DEV_TOOLS/faire_zone.gd`), faite pour être
  repeinte à la main. L'outil valide sa sortie par le chargeur avant d'écrire — un outil qui ne sait pas
  produire une carte valide n'a pas à la sauvegarder — et refuse d'écraser une zone existante.
### Poser les objets à la main — DÉCIDÉ (Jordan, 16 septembre 2026) : des MARQUEURS, pas des tuiles

La question était ouverte — « l'orientation d'un miroir, est-ce huit tuiles, ou une tuile et une
propriété ? ». **Elle est tranchée, et ce n'est pas par goût : c'est `depend_de` qui décide.**

Une `PORTE_ANTIQUE` dépend d'autres objets, et `CORE/monde.gd` attend la liste de leurs IDENTIFIANTS.
Or ces identifiants sont distribués à la pose, à la file (`_prochain_id`) : ajouter un cristal ailleurs
sur la carte les décale tous. ⚠ **Aucune tuile ne peut porter ça, et une liste de nombres écrite à la
main serait fausse au premier objet ajouté, sans que rien ne le signale.** D'où la règle :

- **ce qui n'a AUCUNE propriété se peint au pinceau** sur le calque `Objets` — aujourd'hui l'entrée
  seule, dont la destination est DÉDUITE et non écrite ;
- **ce qui porte des propriétés est un MARQUEUR** (`CLIENT/marqueur.gd`) : un nœud sous `Marqueurs`,
  avec son `type`, sa `cellule` et ses `proprietes` dans l'inspecteur. Miroirs, vitres, cristaux, yeux,
  portes, rais de ciel.
- ⚠ **LE NOM DU NŒUD EST L'IDENTITÉ**, et `depend_de` cite des NOMS. Godot interdit déjà à deux frères
  de porter le même nom : l'unicité est gratuite et lisible dans l'arbre. `CLIENT/niveau.gd` résout les
  noms en identifiants **une fois TOUT posé** — étape 5, et c'est le seul endroit qui écrit `depend_de`.
- ⚠ **LA CASE EST LA VÉRITÉ, LA POSITION EN EST DÉDUITE.** On règle `cellule` ; le nœud se place seul.
  Lire la case depuis les pixels donnerait deux descriptions d'un même lieu, et un objet à cheval sur
  deux cases au premier glissement de souris.
- **Une seule autorité sur les propriétés** : `Monde.poser()` refuse une propriété mal orthographiée,
  et `CLIENT/niveau.gd` ne fait que nommer le marqueur fautif. `_get_configuration_warnings()` le dit
  en plus DANS l'éditeur, avant même de lancer.
- **MESURÉ (test)** — `DEV_TOOLS/test_niveau.gd`, 60 vérifications.

⚠ **DEUX MUTATIONS N'ONT PAS ROUGI, ET C'EST LA LEÇON LA PLUS CHÈRE DE LA SESSION.**

```
  mutation                                      rougit   ce qu'elle a appris
  tri des marqueurs par case retiré               oui
  résolution des dépendances sautée               oui
  unicité des noms non vérifiée                   oui
  depend_de non vidé avant la pose                NON    les tests ne lui donnaient que du BIEN FORMÉ
  dépendances résolues avant les grottes          NON    aucun test ne traversait les deux vues
```

**Les deux silences disaient la même chose : mes tests n'allaient pas assez loin. Aucun ne disait que le
code était inutile.**

- **La seconde** : aucun test ne faisait dépendre un objet d'une AUTRE vue, alors que c'est la phrase
  même du jeu (§2) — on descend pour réparer ce qu'on voit d'en haut. Un œil au fond d'une grotte qui
  ouvre une porte en surface est la première énigme plausible, et rien ne la gardait.
  `test_dependance_entre_deux_vues()` existe pour ça.
- **La première, et elle m'a eu** : j'en ai conclu « code mort » et je l'ai RETIRÉ. Un test de fumée l'a
  démenti dans l'heure — sur une carte saine l'étape 5 écrase de toute façon, donc rien ne rougit ; sur
  une valeur MAL FORMÉE (une chaîne au lieu d'une liste, ce que la peinture à la main produit), il n'y a
  rien à écraser, `Monde.valider()` lit une chaîne là où il attend un tableau, et **le chargeur plante
  au lieu de signaler**. `test_depend_de_mal_forme()` garde le vidage désormais.

⚠ **LA RÈGLE QUI EN SORT, ET ELLE CORRIGE UNE LECTURE TROP RAPIDE DU §6 DE RIVER STONES.** « Un test
qu'on n'a pas vu rougir ne garde rien » reste vrai. Mais une mutation muette a DEUX lectures — le code
est inutile, ou **le test est trop étroit** — et on ne choisit pas la première parce qu'elle est plus
commode. ⚠ Le départage se fait en donnant au code ce que les tests ne lui donnent jamais : ici, une
carte FAUTIVE, qui est exactement ce qu'on peint à la main.

### Peindre à la main — l'outillage

- **`DEV_TOOLS/verifier_zone.gd`** — charge une zone, appelle `construire()`, imprime les erreurs en
  français avec leurs coordonnées. Code de sortie 0 ou 1, sans fenêtre, en deux secondes.
  ⚠ **Il n'imprime pas que « oui » ou « non »** : il montre ce qu'il a VU — les grilles, les chemins, et
  pour chaque entrée la grotte, la colonne et la bouche qu'il en a DÉDUITES. Une entrée peut être
  parfaitement valide et mener ailleurs qu'on ne croit ; c'est la seule faute qu'aucune erreur ne dira.
- **`CLIENT/grotte.gd` est `@tool`** et dessine son chemin sur la grille de surface pendant qu'on peint.
  Sans lui on posait les entrées à l'aveugle. ⚠ Il appelle `Niveau.chemin()`, la MÊME fonction que le
  chargeur : un gizmo qui recalculerait le trajet à sa façon finirait par mentir. Tous les nœuds d'une
  zone étant à l'origine, une case dessinée en `case × 32` tombe pile sur la grille.

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
