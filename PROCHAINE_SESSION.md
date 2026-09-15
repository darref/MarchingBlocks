# Consigne pour la prochaine session — laissée les 15 et 16 septembre 2026

Lis d'abord `CLAUDE.md` : le §3 (l'écran partagé) est le sujet, le §4 décrit le moteur déjà construit.

⚠ **Ce fichier est une CONSIGNE, pas une charte.** Une fois la tâche faite, commitée et poussée,
supprime-le, ainsi que la ligne qui y renvoie en tête de `CLAUDE.md`. Ce qui doit durer va dans la
charte ; ce qui est une commande à exécuter meurt ici.

---

## La tâche — demande de Jordan, mot pour mot

Le 15 septembre :

> qu il fasse l'animation balayage de gauche a droite ou de droite a gauche de la demarquation entre
> les deux vues , a chaque fois que ça se produit , ( agrandissement , retrecissement , de chacun des
> 2 viewport , en temps réel , optimisé haut FPS et fluide , et les deux vues plein ecran chacune de
> l un ou de l autre quand aucune raison de voir autre chose) la fenetre de jeu doit toujours etre en
> 2:1 pour supporter correctement le split quand il est la . mode plein ecran avec des andes noires en
> haut et en bas pour garder le 2:1. fenetré redimensionable mais avec clamp minimal , et 2:1 conservé
> pendant tout redimensionnement. et ensuite push commit

Précisé le 16 septembre — ⚠ **c'est cette version qui fait foi** pour ce qu'on voit :

> dans la grotte on voit toujours la surface aussi , mais dans la surface on ne voit la grotte que soit
> quand on est proche de l entrée , soit quand ne resolution de noeud ou un autre type d evenement de
> resolution dynamique est en train d 'etre montré au joueur.

Soit, en clair :

1. **la démarcation entre les deux vues BALAIE** (gauche → droite ou droite → gauche) à chaque
   changement de mise en page — les deux vues s'agrandissent et rétrécissent en temps réel, de façon
   fluide, à haut FPS ;
2. **dans une grotte, on voit TOUJOURS les deux** (grotte 3/4, surface 1/4). **En surface, la surface
   seule en plein écran**, sauf quand on est proche d'une entrée ou qu'un événement de résolution
   dynamique (un nœud, ou autre) est montré au joueur : la grotte revient alors sur 1/4. ⚠ La grotte
   n'est JAMAIS seule à l'écran — « les deux vues plein écran » de la première demande est remplacé ;
3. **la fenêtre est TOUJOURS en 2:1** ;
4. **plein écran** : bandes noires en haut et en bas pour garder le 2:1 ;
5. **fenêtré** : redimensionnable, taille minimale imposée, 2:1 conservé pendant tout le
   redimensionnement ;
6. **puis commit et push.**

---

## Environnement — à enregistrer en mémoire dès le début

Ta mémoire de projet est neuve : rien de ce qui suit n'y est. Ce sont des faits appris dans
RollingStones, sur la même machine.

- **Godot 4.7** : `C:\Users\jorda\Desktop\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe`.
  ⚠ `Godot_v4.7-stable_win64.exe` est un **DOSSIER**, l'exécutable est dedans. Prendre la variante
  `_console.exe`, la seule dont la sortie revient dans le terminal. Lancer par PowerShell.
- **Code de sortie en PowerShell 5.1** : avec `Start-Process -PassThru`, `ExitCode` revient VIDE si l'on
  n'a pas lu `$p.Handle` juste après le lancement. Écrire `$null = $p.Handle`.
- ⚠ **NE JAMAIS TUER UN PROCESSUS PAR NOM D'IMAGE** (`taskkill /IM`, `Stop-Process -Name`). Jordan garde
  son propre Godot ouvert en permanence : ne tuer que le PID qu'on a lancé soi-même.
- **Tests** : `godot --headless --path D:/UnderMend --script res://DEV_TOOLS/test_lumiere.gd` → code 0,
  « TOUT PASSE — 248 vérifications ». Ils doivent le rester.
- **Le mode headless ne rend RIEN.** Tout ce qui se voit — le balayage, les bandes noires, le
  redimensionnement — se vérifie en lançant AVEC fenêtre, et le redimensionnement à la souris ne se
  juge qu'avec Jordan. Ne jamais déclarer « fluide » ce qu'on n'a pas vu.
- **Git** : `origin` = `git@github.com:darref/UnderMend.git`, branche `main`. Ajouter les fichiers
  PAR NOM, jamais `git add -A` ni `commit -a` (habitude de RollingStones, où d'autres sessions commitent
  dans le même arbre). Messages de commit en français.

---

## Ordre proposé

1. **`project.godot` en 2:1.** Base **320×160** (le calcul est au §3 de la charte : c'est la seule base
   2:1 dont la pleine largeur s'agrandit d'un facteur ENTIER sur 720p, 1080p, 1440p et 4K), étirement
   `viewport`, aspect `keep` (c'est lui qui pose les bandes noires), taille minimale de fenêtre.
   Vérifier que les tests restent verts.

2. **La logique de mise en page, PURE et testée** — un script sans `Node`, par exemple
   `CLIENT/mise_en_page.gd` :
   - la cible du séparateur : **320, 240 ou 80** pixels de base, à partir de trois entrées — le joueur
     est-il sous terre, est-il près d'une entrée (avec hystérésis), un événement de grotte est-il en
     train d'être montré (avec son maintien) ;
   - l'avancée du balayage d'une image à l'autre, **interruptible** ;
   - la taille 2:1 d'une fenêtre demandée, avec plancher.

   Et `DEV_TOOLS/test_mise_en_page.gd`, **vu échouer par mutation** avant d'être déclaré utile
   (règle §6 de River Stones, reprise au §6 de la charte).

3. **La scène greybox de l'écran partagé** : deux `SubViewport` de 320×160, une grille de couleur unie
   par vue, la composition, le trait de démarcation, et des touches de mise au point pour descendre ou
   remonter, s'approcher d'une entrée, et déclencher un événement de grotte.
   ⚠ **Pour l'événement, utilise le VRAI moteur plutôt qu'un faux** : un `Monde` à deux grilles, un rai
   et un pilier de glace dans la grille de la grotte, et une touche qui pose le rai. `resoudre()` rend
   alors un vrai « transforme » qui porte `grille` et `case` — exactement ce que le jeu lira.

4. **La fenêtre 2:1 pendant le redimensionnement.**

5. **La mesure du FPS** : une scène qui fait balayer la démarcation en continu, un temps d'image relevé
   sur plusieurs passes. ⚠ Le bruit de mesure est à sens unique — une charge étrangère ne peut
   qu'AJOUTER du temps — donc on compare les MINIMUMS de plusieurs passes, jamais une moyenne ni une
   passe isolée (leçon de River Stones, §8).

6. **La charte à jour** (§3), **ce fichier supprimé**, **commit**, **push**.

---

## Pièges connus d'avance

- ⚠ **Ne JAMAIS redimensionner un `SubViewport` pendant le balayage.** Changer sa taille réalloue sa
  cible de rendu, à chaque image : c'est exactement ce qui fait tomber le FPS. Les deux vues rendent à
  pleine taille, et l'affichage ne fait que ROGNER — par une découpe, ou par un shader plein écran qui
  lit les deux textures et une seule valeur de séparation.
- **La grotte entièrement cachée (surface en plein écran) cesse de se rendre** (`render_target_update_mode`
  désactivé) mais continue d'être simulée. C'est ce qui rend le plein écran de la surface gratuit.
- **Le balayage est interruptible.** Si la cible change en plein mouvement, on repart de la position
  COURANTE vers la nouvelle cible, jamais d'un saut. Deux `Tween` qui se disputent la même valeur
  donnent une saccade : soit on tue le précédent, soit on anime à la main dans `_process` avec `delta`,
  ce qui ne crée aucun objet par changement et s'interrompt tout seul.
- **La position se quantifie au pixel de base.** L'agrandissement entier garde le trait net, et à la
  vitesse d'un balayage le pas ne se voit pas. `snap_2d_transforms_to_pixel` est déjà activé.
- ⚠ **L'aspect `keep` garantit que le CONTENU reste en 2:1** (bandes noires), même quand la fenêtre ne
  l'est pas. **Le 2:1 de la FENÊTRE elle-même pendant le glisser est une autre affaire** : Godot ne sait
  pas contraindre un rapport pendant que Windows pilote le redimensionnement. Il faut recaler la taille
  à chaque `size_changed`, et ça peut TREMBLER. Si ça tremble, recaler au relâchement. À juger avec
  Jordan.
- **Mode entier et fenêtré se contredisent en un point.** Une fenêtre 2:1 de 1000×500 s'agrandit ×3 en
  960×480 : il reste une fine bande tout autour. Trois issues : (a) agrandissement entier partout, en
  acceptant ces bandes ; (b) tailles de fenêtre calées sur des multiples de 320×160, sans bandes mais
  par crans ; (c) agrandissement fractionnaire en fenêtré seulement. Proposer (a) par défaut, et
  demander.

---

## Questions à poser à Jordan — sans bloquer le reste

1. **Combien de temps la bande reste-t-elle ouverte après un événement ?** Proposer : la durée de son
   animation, plus un maintien d'une demi-seconde environ.
2. **Plusieurs événements dans des grottes différentes au même moment** : laquelle montre-t-on ?
3. **Sous terre, un événement de SURFACE** change-t-il la mise en page, ou la surface à 1/4 suffit-elle ?
   Par défaut, rien ne bouge.
4. **En fenêtré** : bandes internes (a), crans (b) ou fractionnaire (c) ?
5. **Le toucher du balayage** : durée et courbe. Proposer environ 0,3 s, départ et arrivée adoucis, et
   régler à l'œil avec lui.
6. **La démarcation se voit-elle ?** Un trait d'un ou deux pixels de base, à l'or du logo, ou rien
   qu'une coupure nette ?
