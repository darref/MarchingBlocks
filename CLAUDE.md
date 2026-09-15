# Undermend — charte du projet

Même rôle que la charte de River Stones : porter les décisions transverses, celles qui doivent
survivre à une session et à quelqu'un qui arrive six mois plus tard avec une bonne idée.

⚠ **Le projet naît, donc tout n'a pas le même poids.** Chaque décision porte son statut :

- **DÉCIDÉ** — voulu par Jordan, ne se rediscute pas sans lui ;
- **PROPOSÉ** — réflexion à valider, avec sa raison ; on peut la jeter, pas l'ignorer ;
- **MESURÉ** — vérifié par un calcul ou une capture, donc vrai quoi qu'on en pense ;
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
- **Un coude du chemin est invisible de côté** : la coupe est déroulée. C'est assumé, et ça vaut pour
  la lumière aussi — un rayon horizontal dans la grotte suit la coupe, coudes compris.
- **Le joueur n'existe que dans UN monde à la fois.** L'autre vue montre sa PROJECTION (un repère),
  jamais un second corps. Deux corps synchronisés seraient deux autorités sur une position.
- **OUVERT — les segments en diagonale.** Pour la v0, les chemins sont faits de segments droits
  (horizontaux ou verticaux sur la carte). Une diagonale demande une convention de longueur — une
  colonne par pas diagonal garde les deux grilles alignées, mais le repère de surface y va alors
  √2 fois plus vite que le joueur. À trancher le jour où une grotte en réclame une.

---

## 3. L'écran partagé — UNE seule valeur

**DÉCIDÉ** — trois situations :

- en surface, loin de toute entrée : la vue de dessus seule ;
- en surface, **assez près d'une entrée** : vue de dessus sur 3/4 de la largeur, grotte sur 1/4 ;
- **dans une grotte, quelle que soit la profondeur** : grotte sur 3/4, vue de dessus sur 1/4.

**PROPOSÉ — la surface est toujours À GAUCHE, la grotte toujours À DROITE, et toute la mise en page
est la position d'un SÉPARATEUR.** En pixels de la résolution de base :

```
  x = 320   surface seule            ████████████████████████████████
  x = 240   près d'une entrée        ████████████████████████│░░░░░░░░
  x =  80   dans la grotte           ████████│░░░░░░░░░░░░░░░░░░░░░░░░
             surface ←┘ └→ grotte
```

Passer une entrée ne permute rien : **le séparateur glisse**. Le joueur ne perd jamais où est quel
monde, et il n'y a qu'un nombre à animer — pas une disposition à inverser avec sa moitié qu'on
oublierait.

- ⚠ **HYSTÉRÉSIS OBLIGATOIRE.** La bande apparaît à R cases d'une entrée et ne disparaît qu'à R + une
  marge. Sans ça, un joueur qui marche le long du seuil fait clignoter l'écran. Rayons en CASES,
  jamais en pixels.
- **Près d'une entrée, la bande montre la coupe à la colonne la plus proche** du joueur ; s'il y a
  plusieurs entrées, la plus proche gagne.
- **Rendu** — deux `SubViewport` de 320×180, chacun avec son propre monde 2D, **simulés en
  permanence tous les deux** ; l'affichage ne fait que ROGNER. Chaque caméra centre le joueur (ou sa
  projection) dans la partie VISIBLE de sa vue : quand le séparateur glisse, les caméras glissent
  avec lui sans une ligne de plus.

### La résolution — PROPOSÉ : 320×180, cases de 16 pixels

- **Agrandissement entier partout** : 720p (×4), 1080p (×6), 1440p (×8), 4K (×12). Un pixel art
  agrandi d'un facteur non entier se déforme — c'est le réglage qui décide si le jeu a l'air d'un
  jeu SNES ou d'une capture floue. 480×270, l'autre candidat courant, tombe à ×5,33 en 1440p.
- **Et en écran partagé, la vue principale fait 240×180, soit 15 × 11 cases** — le cadrage même de
  *A Link to the Past* (16 × 14 cases en 256×224). La référence graphique et la mise en page tombent
  d'accord sans qu'on ait eu à les accorder.
- ⚠ **OUVERT — la bande de 1/4 fait 80 pixels, soit CINQ cases de large.** Elle est en portrait : ça
  va très bien à une coupe de grotte (on y voit la profondeur, c'est un puits de lumière), c'est
  serré pour la surface quand la grotte court d'est en ouest. La question se tranche au greybox et
  nulle part ailleurs : **voit-on, depuis la grotte, le miroir de surface qui est au-dessus de
  soi ?** Si non, repli en 480×270 (bande de 7,5 cases), en payant le 1440p.

**PROPOSÉ — rendu `gl_compatibility`.** Un jeu 2D n'a besoin de rien de Forward+, et ce rendu ouvre
le web, le mobile et les machines modestes — les portes que River Stones a payées cher (§10 de sa
charte).

⚠ **`project.godot` ne garde pas de commentaires** : Godot le réécrit en entier au premier
enregistrement. La raison de chaque réglage de projet vit ICI.

---

## 4. La lumière et les miroirs

**DÉCIDÉ** — les premières énigmes consistent à orienter des miroirs, **huit orientations
possibles**, grâce à des pouvoirs acquis au fil de l'avancée.

### MESURÉ — ce que « huit orientations » doit vouloir dire

Un miroir est une ligne à deux faces. Un rayon de direction φ qui frappe un miroir d'angle θ repart
en `2θ − φ`. Les rayons vont dans huit directions (multiples de 45°). Calculé sur tous les cas :

```
  miroir par pas de 45°   (4 orientations)  : les AXES restent des axes,
                                              les DIAGONALES restent des diagonales.
                                              Deux familles qui ne se rencontrent JAMAIS.
  miroir par pas de 22,5° (8 orientations)  : toute direction mène à toutes les autres
                                              (sauf tout droit).
  dans les deux cas : 8 cas rasants (rayon parallèle au miroir), 8 demi-tours.
```

**Donc « huit orientations » = huit positions sur un demi-tour, par pas de 22,5°.** C'est la seule
lecture où les huit directions communiquent. Bonus gratuit : en pixel art ces lignes sont 0, 2:1,
1:1 et 1:2 — les quatre traits les plus propres qu'une grille de pixels sache dessiner.

### PROPOSÉ — la progression des pouvoirs sort du calcul

1. **Tourner** (pas de 45°, 4 orientations) — les rayons restent dans leur famille. On apprend la
   réflexion sur un problème réduit, sans le savoir.
2. **Incliner** (pas de 22,5°, 8 orientations) — les deux familles se rejoignent. L'espace des
   énigmes double d'un coup, et le joueur SENT pourquoi : ce qui était impossible devient possible.
3. **Portée** — orienter un miroir à distance (au-delà d'un gouffre, d'une eau).
4. **Regard croisé** — orienter un miroir de l'AUTRE vue, à travers la bande. ⚠ C'est ce pouvoir qui
   fait de l'écran partagé une MÉCANIQUE : sans lui, la bande n'est qu'une mini-carte.

### Un seul traceur, deux grilles, des portails — PROPOSÉ

- **Le trajet de la lumière est une FONCTION de l'état** (miroirs, zones, portes), recalculée quand
  l'état change. Il n'est jamais simulé : pas de photon qui avance, pas d'ordre de mise à jour.
- **Les puits sont des portails** : un rayon de surface qui entre dans la case d'un puits ressort
  vers le BAS dans la grotte, à la colonne que la table du §2 associe à cette case. Le même traceur
  sert aux deux vues — une seconde implémentation pour la vue de côté divergerait (§6).
- **OUVERT, à trancher avant la première énigme** (valeurs par défaut entre parenthèses) :
  - le rayon rasant (arrêté par la tranche du miroir) ;
  - le rayon diagonal qui passe entre deux coins de mur (arrêté si l'un des deux est plein —
    ce qu'on voit doit être vrai) ;
  - les boucles (détectées par couple case × direction déjà visité ; le rayon s'y arrête).

---

## 5. Les nœuds et l'onde

**DÉCIDÉ** — on peut **défaire ou refaire** un nœud, et chaque geste lance une onde qui convertit la
zone en **vivante** (défait) ou en **intriquée** (refait). Les nœuds inextricables ne cèdent qu'à la
force du ciel.

### PROPOSÉ — l'état appartient aux NŒUDS, l'onde n'est que le moment où une case l'apprend

Une case bascule à l'instant `t0 + d / v` : `t0` le geste, `d` sa distance en cases au nœud (parcours
en largeur dans sa zone), `v` la vitesse de l'onde. Trois conséquences :

- **la sauvegarde ne contient que les nœuds** (état + instant du dernier geste) : aucun historique
  par case, rien à réconcilier ;
- **chaque case appartient à UNE zone**, calculée une fois ; deux ondes ne peuvent donc jamais se
  disputer une case — égalité de distance départagée par l'identifiant du nœud, pas par l'ordre de
  mise à jour ;
- **un nœud rebasculé pendant son onde** en lance une nouvelle, qui remplace l'ancienne.

⚠ **L'EFFET DE JEU ARRIVE AVEC L'ONDE, PAS AU CLIC.** Si une case vivante laisse passer la lumière,
elle ne la laisse passer qu'une fois l'onde arrivée sur elle. Ce qu'on voit est vrai — c'est la leçon
des deux horloges de River Stones (§8), et c'est la lisibilité d'*A Link to the Past*.

### PROPOSÉ — le rendu : *A Link to the Past* l'a déjà fait

Le Monde des Ténèbres d'ALTTP est **la même carte, repeinte par permutation de palette**. C'est
exactement « vivante / intriquée ». Un shader de tuiles lit une texture d'état à un texel par case et
le front de l'onde ; les changements de FORME (lianes, racines, nœuds visibles) vivent sur un calque
à part. Un seul jeu de tuiles à dessiner, pas deux.

⚠ **REFAIRE UN NŒUD DOIT SERVIR, SINON PERSONNE NE LE FERA.** L'état intriqué doit donner quelque
chose : des racines qui font plateforme dans la grotte, des lianes qui arrêtent un rayon mal dirigé,
une eau qui cesse de couler. Toute énigme qui enseigne « refaire » doit L'EXIGER.

- **OUVERT — l'onde traverse-t-elle les vues ?** Proposition : oui, par la table du §2. Un nœud
  défait dans la grotte ranime la surface au-dessus du chemin, et on voit l'onde courir dans les deux
  vues à la fois — c'est l'usage le plus fort de l'écran partagé. À confirmer.
- **OUVERT — la force du ciel.** Ce qu'elle est et comment on l'obtient. Aucune énigme du début n'en
  dépend ; seul le type de nœud doit exister.

---

## 6. Architecture — héritée de River Stones — PROPOSÉ

**Une seule autorité sur les règles.** Les règles d'une énigme vivent dans `CORE/`, sans `Node`, sans
rendu, sans horloge : la grille, la table des grottes, le traceur de lumière, les nœuds et leurs
zones, les pouvoirs. Tout y est **déterministe et testable sans écran**. `CLIENT/` affiche les deux
vues, la bande, les ondes, et ne recalcule JAMAIS une règle.

```
  CORE/        règles et état du monde — aucun Node
  CLIENT/      les deux vues, le séparateur, l'entrée joueur, l'animation
  DEV_TOOLS/   tests et outils (en français)
  MARQUE/      titre.png, embleme.png — images générées, à redessiner en vectoriel avant la boutique
```

- **Une sauvegarde tient en quelques octets** : orientation des miroirs, état des nœuds, pouvoirs,
  position. C'est la version énigme du « une graine et quatre entiers par tour ».
- **Tests** — la règle du §6 de River Stones s'applique telle quelle : un test vert ne prouve rien
  tant qu'on ne l'a pas vu échouer, et toute propriété structurelle (familles de miroirs, portails,
  zones) se garde par un scénario CONSTRUIT, jamais espéré.

## 7. Langue — héritée

La langue du jeu est l'**anglais américain** : toute chaîne qu'un joueur peut lire est en anglais, en
dur dans le code. Restent en français les commentaires, la documentation, les `print()` et tout
`DEV_TOOLS/`. En cas de doute : *un joueur peut-il la lire à l'écran ?*

## 8. Ordre de travail — PROPOSÉ

Le risque n'est pas la durée, c'est la **lisibilité à deux vues** : dessiner un beau monde et
découvrir qu'on ne comprend pas ce qu'on voit dans la bande.

1. **Greybox de l'écran partagé** — deux grilles de couleurs unies, une grotte, une entrée, la table
   de colonnes, le séparateur animé. Tranche la question des cinq cases (§3).
2. **Le traceur dans `CORE/`**, avec ses tests : familles à 45°, connexion à 22,5°, boucles, portail.
3. **Un nœud et son onde.**
4. **Le pixel art, seulement ensuite.**
