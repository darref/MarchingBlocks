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
- **L'ÉDITEUR EST SPANNERGAMES INC. — DÉCIDÉ (Jordan, 29 septembre 2026).** Dans les propriétés de
  l'exe (société, copyright) et tout à droite de la barre de titre, logo DÉTOURÉ
  (`MARQUE/spannergames_detoure.png` : le fond violet opaque de `spannergames.png` ferait un carré).
- **LE SPLASH — DÉCIDÉ (Jordan, 29 septembre 2026) : un fond par logiciel, UNE signature pour tous.**
  - **Le fond de MarchingBlocks** raconte le slogan : le témoin de 12³ flotte dans ses plans de coupe
    dorés, et le monde devient, vers la droite, organique et stylisé. La moitié gauche est RENDUE avec le
    vrai produit (`DEV_TOOLS/rendre_splash.gd` → `MARQUE/splash_fond.png`) ; la droite a été reprise dans
    Tripo par Jordan (`MARQUE/splash_fond_tripo.png`, gardée telle quelle). ⚠ C'est une image de
    présentation : l'interdit de Tripo (§3) porte sur le TÉMOIN qu'on texture, pas sur elle.
  - **La signature** (logo détouré et « SpannerGames Inc. », en bas à droite, sur un voile flou) est
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
  - La variété pourra revenir en VARIANTES VOULUES dont l'appli fige les sections — OUVERT.

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
  - ⚠ **PAS COUVERTS** : E, I, Ctrl+B et la subdivision SUR un bord (ils posent des sommets de bord neufs sans
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
  (« source changée, on retranche »). Gardé : remodeler B laisse les OCTETS du `.glb` de A intacts.
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

### L'ENREGISTREMENT QUI SE DIT, ET LES FICHIERS DANS WINDOWS — DÉCIDÉ (Jordan, 30 septembre 2026), ÉCRIT

- **« Si les enregistrements sont automatiques, il faut le dire au client. »** La barre de titre porte un
  témoin : « ✓ Saved », « ● Saving… » (la seconde où un geste du modeleur attend d'être écrit), « ⚠ Not
  saved » ; sa bulle explique qu'il ne faut pas de Ctrl+S. ⚠ **CTRL+S RÉPOND** : muet, il faisait croire au
  client qu'il n'avait rien enregistré ; il écrit ce qui attendait et le DIT. Le rapport d'ouverture le
  rappelle. Gardé par `fumee_appli` (deux mutations rouges).
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

### Le TERRAIN monolithique et les PROPS rattachés — DÉCIDÉ (Jordan, 28 septembre 2026), PAS ÉCRIT

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
- **OUVERT** : la reconstruction INCRÉMENTALE (écrite dans la règle : seules les colonnes x−1..x, z−1..z
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
    **OUVERT** : la gomme et les calques ; le panneau 2D du patron ; un curseur qui montre la taille du pinceau ;
    les bandes de couture pendant qu'on peint.

### L'appli : couches, projets, barre d'outils — DÉCIDÉ (Jordan, 27 septembre 2026)

- **LE MONDE PEINT NE DÉPEND PLUS DU TRAVAIL QUI L'HABILLE.** Une **couche** = une source de tuiles
  (le témoin calculé ou un `.glb`) et SES cases, dans son propre `MassifPeint` : son voisinage ne
  regarde que ses cases. Trancher change les tuiles de la couche ACTIVE, **jamais ses cases**.
  ⚠ « Slice the work » peignait jusque-là les cases du témoin en les remplaçant : c'était la preuve de
  l'aller-retour. Elle vit désormais dans un bouton à part, **« Paint the witness shape »**.
  ⚠ **ET CETTE PREUVE N'EST PLUS À L'IDENTIQUE DEPUIS LES EXEMPLAIRES** (§3) : le peintre tire
  l'exemplaire d'un sommet par hachage de sa position, pas d'après l'endroit où il fut sculpté [⚠ plus
  vrai depuis le 30 septembre 2026 : une tuile par clé, et avec le témoin lié la preuve est à l'identique]. Même
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
- **OUVERT** : un raccord COURBE (aujourd'hui deux jambes et un segment droit) ; un escalier dans un puits ;
  le coût d'un aperçu sur un long conduit de taille 7 (recalculé à chaque case visée, non mesuré).

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
  Bancs relancés le même jour : .NET et C++ 18 cas / 1 624 poses / 103 cas d'outils / 0 échec, Unity 6.6 26 tests
  sur 26, Unreal 5.8.3 BuildPlugin sans avertissement.
  ⚠ **LE BANC C++ TOURNE AVEC LE clang DE UNITY** (`…/WebGLSupport/BuildTools/Emscripten/llvm/clang++.exe
  --target=x86_64-pc-windows-msvc`, mêmes drapeaux que `build.sh`) ; et **`RunUAT BuildPlugin` ÉCHOUE SOUS UN
  DOSSIER `-Package` PROFOND** (chemins de plus de 260 caractères, « OtherCompilationError » sans une ligne
  d'erreur) : un dossier court, `%TEMP%\ueb`.
  ⚠ **APRÈS UN RENOMMAGE DE DOSSIER, LE CACHE DE CLASSES D'UNE AUTRE MACHINE EST PÉRIMÉ** (`.godot/`,
  hors git) : « Class "MassifPeint" hides a global script class » — `test_massif_peint` rendait **1**
  vérification au lieu de 86 en finissant en code 0, et `fumee_appli` pendait. Mesuré le 28 septembre
  2026, aussi sans les changements du jour. Remède : `godot --headless --editor --quit` une fois, puis
  rendre ce qu'il a réimporté (`git status`).
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
