# MarchingBlocks — la campagne de prise en main

Écrite le 7 octobre 2026, d'après `CLAUDE.md` (lu en entier) et `app/manuel.gd` (les noms à l'écran).

**Pourquoi** : presque tout le logiciel a été éprouvé par des tests et des captures, mais **presque rien n'a été tenu
à la souris par un humain**. La charte le répète à chaque section (« PAS TENU EN MAIN »). Or Steam rembourse sans
discuter tout achat utilisé moins de **2 heures** : ce qu'un acheteur rencontre dans ses deux premières heures (les
séances 1 à 7) doit marcher du premier coup.

**Comment s'en servir** :
- une séance = 30 à 60 min, dans l'ordre (chaque séance prépare la suivante) ;
- chaque point : une case `- [ ]`, le **geste** (les boutons et touches tels qu'ils sont écrits à l'écran), ce qu'on
  doit voir si tout va bien, et une ligne **Noté :** à remplir si ça ne va pas (ou « ok ») ;
- ⚠ = point que **plusieurs endroits de la charte signalent comme risqué** (défaut déjà payé, jamais tenu en main,
  mesure contradictoire) : ils sont en tête de chaque séance, on les fait même si on manque de temps ;
- les touches sont données en AZERTY (Z Q S D) ; l'appli lit les touches par leur PLACE, donc W A S D en QWERTY ;
- le temps : notez l'heure de début et de fin de chaque séance (en haut de la séance). Les séances 1 à 7 sont les deux
  premières heures d'un acheteur.

---

## 0. Avant la première séance (une fois)

### 0.1 Mettre à l'abri ce qui est à toi

L'exe exporté et l'éditeur Godot partagent le même dossier de réglages, et l'appli s'enregistre toute seule : un essai
peut rouvrir et réécrire ton vrai projet (c'est arrivé le 2 octobre 2026, à 07:11 — `test.mbproj` rouvert et réécrit).

- [ ] **Sauvegarder les réglages de l'appli**
  - Geste : copier le dossier `%APPDATA%\Godot\app_userdata\MarchingBlocks` entier vers `D:\MB_sauvegarde\app_userdata\`.
  - Attendu : le dossier contient `reglages.cfg`, `cache\`, `icones\`.
  - Noté :
- [ ] **Sauvegarder la source de l'exemple**
  - Geste : copier `C:\Users\jorda\Documents\MarchingBlocks\test\` vers `D:\MB_sauvegarde\test\` (c'est la source de
    l'exemple livré ; ne l'ouvre jamais avec l'exe d'essai : un projet enregistré par une version plus récente ne
    s'ouvre plus dans une plus ancienne).
  - Attendu : `test.mbproj` et ses fichiers copiés.
  - Noté :
- [ ] **Sauvegarder les deux clés secrètes hors du PC** (la charte le demande depuis le 7 octobre)
  - Geste : copier `C:\Users\jorda\.marchingblocks\licence_ed25519_privee.hex` et `cle_pck.hex` sur une clé USB ou un
    coffre en ligne.
  - Attendu : deux copies hors du PC. Perdue, la clé privée empêche de vendre une seule licence de plus aux exe déjà livrés.
  - Noté :

**Le plus propre (recommandé)** : créer une **session Windows neuve** (Paramètres → Comptes → Famille et autres
utilisateurs → Ajouter un utilisateur sans compte Microsoft, nom « Essai ») et y faire les séances 1 à 3 et 14 : c'est
exactement la machine d'un acheteur (aucun réglage, aucune icône de fichier, `Documents` vide). À défaut, renommer
`%APPDATA%\Godot\app_userdata\MarchingBlocks` en `…MarchingBlocks_mis_de_cote` pour simuler un premier lancement, et
le remettre à la fin.

### 0.2 Obtenir les exe à tester

- [ ] **Lancer l'export complet**
  - Geste : fermer l'éditeur Godot ; dans Git Bash :
    ```
    cd /d/MarchingBlocks
    bash DEV_TOOLS/exporter_marchingblocks.sh
    ```
    (≈ 15 min : toute la batterie de tests passe d'abord). Un autre dossier de sortie se donne en argument :
    `bash DEV_TOOLS/exporter_marchingblocks.sh D:/MB_essai`.
  - Attendu : la commande finit sans « stop » et rappelle (sans refuser) les blancs du contrat et l'adresse du site à
    remplir. Dans `D:\MarchingBlocks\build\` :
    - `site\MarchingBlocks.exe` (+ `libmb_natif.windows.template_release.x86_64.dll`, `LICENSE.txt`, `THIRD_PARTY_NOTICES.txt`)
    - `installeur\MarchingBlocks-0.9.0-setup.exe` — **c'est lui qu'on teste en premier**
    - `steam\MarchingBlocks.exe`, `demo\MarchingBlocks.exe`, `steampipe\`, `journal_export\` (les journaux).
  - ⚠ Ne pas lancer `build\MarchingBlocks.exe` (à la racine de `build`) : c'est un export ancien, d'avant la vente.
  - Si la commande refuse : elle dit pourquoi (clé absente, une suite rouge, exe lisible en clair, DLL absente…). Le
    détail est dans `build\journal_export\`.
  - Noté :

### 0.3 Les clés de licence de test

Il faut `pip install cryptography` une fois.

- [ ] **Signer une clé de test (avec accents)**
  - Geste : dans un terminal, depuis `D:\MarchingBlocks` :
    ```
    python DEV_TOOLS/licence_signer.py signer --nom "Jördan Tèst" --email jordan.ferrad@gmail.com --id TEST-001
    ```
  - Attendu : une ligne `MBK1.…….……` (≈ 200 caractères). Colle-la dans un fichier `D:\MB_sauvegarde\cles_de_test.txt`.
    ⚠ Elle est notée dans `C:\Users\jorda\.marchingblocks\licences_emises.csv` : l'id `TEST-` dit que ce n'est pas une vente.
  - Noté :
- [ ] **Vérifier la clé hors de l'appli**
  - Geste : `python DEV_TOOLS/licence_signer.py verifier "MBK1.…"` (la clé entre guillemets).
  - Attendu : le nom, l'e-mail, l'id, et qu'elle est bonne.
  - Noté :
- [ ] **Préparer les mauvaises clés** (dans le même fichier texte)
  - Geste : (a) la même clé avec UN caractère de la fin changé ; (b) la même coupée en deux lignes avec des espaces,
    comme un e-mail mal copié ; (c) la moitié de la clé seulement ; (d) un texte quelconque (« bonjour »).
  - Attendu : quatre lignes prêtes à coller en séance 2.
  - Noté :

### 0.4 Comment remonter un problème

Pour chaque « Noté : », écris dans cet ordre : **l'atelier** (Project, World, Fluids…), **le geste exact**, **ce que tu
attendais**, **ce que tu as vu**, **l'heure** (pour retrouver la ligne dans le journal), et si possible une capture
(`Win + Maj + S`).

- **La ligne du rapport** (le texte épinglé en bas de la barre de gauche, celui qui « dit » ce qui s'est passé) :
  recopie-la mot pour mot, couleurs comprises si elle est rouge ou orange.
- **Le journal de l'appli** (ce que les développeurs appellent la console) : l'exe exporté n'ouvre pas de fenêtre de
  console ; tout est écrit dans
  - version complète (site ou Steam) : `%APPDATA%\Godot\app_userdata\MarchingBlocks\logs\godot.log`
  - démo : `%APPDATA%\MarchingBlocks Demo\logs\godot.log`

  Après un problème, copie ce fichier tel quel (il est réécrit au lancement suivant ; les précédents sont gardés à
  côté, datés). Toute ligne `ERROR`, `SCRIPT ERROR` ou `SHADER ERROR` est un défaut, même si rien ne s'est vu.
- **Dans les éditeurs des greffons** : Godot → panneau « Output » (en bas) ; Unity → fenêtre « Console » ; Unreal →
  « Output Log » (Window → Output Log). Copier les lignes rouges et jaunes.
- **Un plantage** : noter ce qu'on faisait juste avant, et garder `godot.log` AVANT de relancer.

---

## SÉANCE 1 — L'installeur du site (30 min)

Début : ____ Fin : ____

Ce que l'acheteur du site fait en tout premier. L'installeur n'a **jamais tourné qu'en silencieux** (sans fenêtre) :
aucune de ses pages n'a été vue par un humain.

- [ ] ⚠ **L'avertissement de Windows (SmartScreen)**
  - Geste : double-cliquer `build\installeur\MarchingBlocks-0.9.0-setup.exe`.
  - Attendu : Windows avertit « Windows a protégé votre ordinateur » / éditeur inconnu — c'est NORMAL (l'installeur
    n'est pas signé, OUVERT). « Informations complémentaires » → « Exécuter quand même » doit suffire. Note
    exactement ce que Windows affiche : c'est ce que verra chaque acheteur.
  - Noté :
- [ ] ⚠ **Aucune demande d'administrateur**
  - Geste : continuer.
  - Attendu : PAS de fenêtre « Voulez-vous autoriser cette application à apporter des modifications… » (installation
    par utilisateur).
  - Noté :
- [ ] ⚠ **La page du contrat dans l'installeur** (le contrat est montré deux fois : ici, puis dans l'appli)
  - Geste : lire la page du contrat ; essayer « Suivant » sans accepter, puis accepter.
  - Attendu : le texte de `LICENSE.txt` (français d'abord, puis anglais), lisible ; impossible de continuer sans
    accepter. Repère les blancs « [À COMPLÉTER] » (SIRET, adresse…) : ils sont attendus aujourd'hui, interdits le jour
    de la vente. Note si le double contrat (installeur + appli) te paraît lourd.
  - Noté :
- [ ] **La langue de l'installeur**
  - Geste : regarder la première page.
  - Attendu : français sur ton Windows (l'installeur porte anglais et français).
  - Noté :
- [ ] **Le dossier d'installation**
  - Geste : lire le dossier proposé.
  - Attendu : `C:\Users\jorda\AppData\Local\Programs\MarchingBlocks` (pas `Program Files`).
  - Noté :
- [ ] **La case du raccourci sur le Bureau**
  - Geste : la page des tâches supplémentaires ; laisser la case décochée une fois (puis cocher à la réinstallation, séance 19).
  - Attendu : décochée par défaut ; pas de raccourci Bureau quand elle l'est.
  - Noté :
- [ ] **Fin de l'installation et « Lancer MarchingBlocks »**
  - Geste : terminer, laisser cochée la case de lancement.
  - Attendu : l'appli s'ouvre (splash : le témoin dans ses plans de coupe dorés, signature SpannerGames en bas à droite),
    puis le contrat (séance 2). Ne va pas plus loin, ferme par « Quit » si tu veux faire la séance 2 à part.
  - Noté :
- [ ] **Ce qui a été posé sur le disque**
  - Geste : ouvrir `%LOCALAPPDATA%\Programs\MarchingBlocks`.
  - Attendu : `MarchingBlocks.exe`, la DLL `libmb_natif…dll`, `LICENSE.txt`, `THIRD_PARTY_NOTICES.txt`, `icones\`,
    `unins000.exe`.
  - Noté :
- [ ] **Le menu Démarrer et « Programmes et fonctionnalités »**
  - Geste : touche Windows, taper « MarchingBlocks » ; puis Paramètres → Applications.
  - Attendu : l'entrée MarchingBlocks (et sa désinstallation dans le groupe) ; dans Applications « MarchingBlocks
    0.9.0 », éditeur « SpannerGames » (sans « Inc. »).
  - Noté :
- [ ] **Les propriétés de l'exe**
  - Geste : clic droit sur `MarchingBlocks.exe` → Propriétés → Détails.
  - Attendu : version 0.9.0.0, société et copyright SpannerGames, sans « Inc. ».
  - Noté :

---

## SÉANCE 2 — Premier lancement : le contrat, la clé, About (45 min)

Début : ____ Fin : ____

Rien de tout cela n'a été cliqué à la souris : seulement mené par les tests et vu sur deux captures.

- [ ] ⚠ **Le contrat apparaît seul, par-dessus l'appli**
  - Geste : lancer MarchingBlocks depuis le menu Démarrer (premier lancement).
  - Attendu : « MarchingBlocks — License agreement », la phrase « Please read the license agreement… The French version
    prevails… », le texte en paragraphes (pas en lignes coupées), boutons « I accept » et « Quit ». Aucun projet
    n'est ouvert derrière.
  - Noté :
- [ ] ⚠ **« Quit » au contrat**
  - Geste : cliquer « Quit ».
  - Attendu : l'appli se ferme ; au lancement suivant, le contrat revient (rien n'a été accepté).
  - Noté :
- [ ] **Lire le contrat en entier**
  - Geste : relancer, faire défiler le contrat jusqu'au bout.
  - Attendu : le défilement marche, la molette fait défiler le texte, rien ne déborde de la fenêtre.
  - Noté :
- [ ] ⚠ **« I accept » puis la fenêtre d'activation**
  - Geste : « I accept ».
  - Attendu : « Activate MarchingBlocks », la phrase « Paste the license key from your purchase e-mail. It works
    offline, on every computer you use yourself. », un champ vide qui affiche « MBK1.… », le lien « No key yet? Buy
    MarchingBlocks, or try the free demo », boutons « Activate » et « Quit ». **Le curseur clignote déjà dans le champ**
    (défaut corrigé le 7 octobre : on collait dans le vide).
  - Noté :
- [ ] ⚠ **Coller directement (Ctrl+V) sans cliquer dans le champ**
  - Geste : `Ctrl+V` de la mauvaise clé (d) « bonjour », puis « Activate ».
  - Attendu : le texte arrive dans le champ ; refus avec la raison « This is not a MarchingBlocks license key (it starts
    with MBK1.). » ; la fenêtre reste.
  - Noté :
- [ ] **Le champ vide**
  - Geste : vider le champ, « Activate ».
  - Attendu : « Paste your license key. »
  - Noté :
- [ ] **La clé trafiquée (un caractère changé)**
  - Geste : coller la clé (a), « Activate ».
  - Attendu : « This key is not valid — copy it again, in full, from your purchase e-mail. » (ou « This key is not
    valid. »). Jamais acceptée.
  - Noté :
- [ ] **La clé coupée en deux**
  - Geste : coller la clé (c) (la moitié), « Activate ».
  - Attendu : « This key is incomplete — copy it again, in full, from your purchase e-mail. »
  - Noté :
- [ ] ⚠ **La clé collée depuis un e-mail (retours à la ligne, espaces)**
  - Geste : coller la clé (b), « Activate ».
  - Attendu : ACCEPTÉE (l'appli enlève espaces et retours à la ligne).
  - Noté :
- [ ] **Le lien « No key yet? Buy MarchingBlocks, or try the free demo »**
  - Geste : cliquer le lien (avant d'activer, au lancement suivant si besoin).
  - Attendu aujourd'hui : l'adresse du site n'existe pas encore (« A-REMPLIR » dans `app/vente.gd`). Note ce qui se
    passe (rien, ou un navigateur sur une adresse factice) : le jour de la vente, il doit ouvrir la vraie page.
  - Noté :
- [ ] ⚠ **La bonne clé**
  - Geste : coller la vraie clé de test, « Activate ».
  - Attendu : la fenêtre se ferme, l'appli s'ouvre sur un projet neuf (`Documents\MarchingBlocks\untitled\untitled.mbproj`).
  - Noté :
- [ ] ⚠ **La clé est retenue**
  - Geste : fermer l'appli (croix de la fenêtre), relancer.
  - Attendu : ni contrat ni clé redemandés ; l'appli rouvre ton monde.
  - Noté :
- [ ] ⚠ **« About »**
  - Geste : cliquer « About » dans la barre de titre.
  - Attendu : « About MarchingBlocks », « MarchingBlocks v0.9.0 — Early Access », « Sculpt one block. Paint a world.
    © 2026 SpannerGames. All rights reserved. », « Licensed to Jördan Tèst (jordan.ferrad@gmail.com) » — **les accents
    justes**, et les boutons « Enter another license key », « License agreement », « Third-party notices », « Close ».
  - Noté :
- [ ] **« License agreement » et « Third-party notices » depuis About**
  - Geste : cliquer l'un puis l'autre.
  - Attendu : le contrat ; puis la liste Godot (MIT) et ses composants, godot-cpp, Monocypher — lisible, qui défile.
  - Noté :
- [ ] **« Enter another license key », puis « Cancel »**
  - Geste : About → « Enter another license key » → « Cancel ».
  - Attendu : le bouton s'appelle « Cancel » ici (pas « Quit ») ; l'appli reste ouverte et garde la clé d'avant.
  - Noté :
- [ ] **Changer de clé pour de vrai**
  - Geste : signer une 2e clé (`--nom "Second Test" --id TEST-002`), About → « Enter another license key », la coller.
  - Attendu : About dit maintenant « Licensed to Second Test (…) ».
  - Noté :
- [ ] **La vérification des mises à jour ne gêne pas**
  - Geste : couper le réseau (mode avion), lancer l'appli ; puis relancer avec le réseau.
  - Attendu : aucun délai, aucun message dans les deux cas (l'adresse n'est pas encore remplie, rien ne part). La case
    « Check for updates at launch » est dans l'atelier Project.
  - Noté :
- [ ] **Le titre de la fenêtre et la barre de titre**
  - Geste : regarder la barre de titre.
  - Attendu : le logo SpannerGames détouré tout à droite ; « ✓ Saved » ; « About » ; le bandeau de conseils.
  - Noté :

---

## SÉANCE 3 — Fichiers, projets et l'exemple (45 min)

Début : ____ Fin : ____

- [ ] ⚠ **Les icônes des fichiers dans l'Explorateur** (jamais vues par un humain)
  - Geste : ouvrir `Documents\MarchingBlocks\untitled\` dans l'Explorateur.
  - Attendu : `untitled.mbproj` a l'icône MarchingBlocks (pas une page blanche) ; les `.mbtiles` aussi. Si l'icône
    reste blanche : fermer et rouvrir l'Explorateur, puis noter.
  - Noté :
- [ ] ⚠ **Le double-clic sur un `.mbproj`**
  - Geste : fermer l'appli, double-cliquer `untitled.mbproj`.
  - Attendu : MarchingBlocks s'ouvre SUR ce projet.
  - Noté :
- [ ] ⚠ **« Which world » : My world / Very simple example** (jamais éprouvé dans l'exe)
  - Geste : atelier World, section « Which world », cocher « Very simple example ».
  - Attendu : une barre d'attente nommée (l'exemple pèse ~80 Mo, son ouverture prend 6 à 9 s), puis l'exemple : trois
    couches texturées, AUCUN cube rouge, de l'eau. Il s'installe dans `Documents\MarchingBlocks\Example\<date>\`.
    UNE seule des deux cases est cochée (défaut déjà vu : les deux restaient enfoncées).
  - Noté :
- [ ] ⚠ **L'exemple ne s'impose pas au lancement suivant**
  - Geste : fermer l'appli sur l'exemple, relancer.
  - Attendu : l'appli rouvre TON monde (untitled), jamais l'exemple ; « Which world » coche « My world ».
  - Noté :
- [ ] **Retour à l'exemple : tes changements y sont**
  - Geste : ouvrir l'exemple, poser une case visible, fermer, relancer, rouvrir « Very simple example ».
  - Attendu : la case est toujours là (l'exemple garde tes changements, il n'est jamais écrasé).
  - Noté :
- [ ] ⚠ **« ✓ Saved » / « ● Saving… » / Ctrl+S**
  - Geste : poser une case et regarder la barre de titre ; attendre une seconde ; puis `Ctrl+S`.
  - Attendu : « ● Saving… » pendant ~1 s puis « ✓ Saved » ; `Ctrl+S` répond par une ligne du rapport (il confirme, il ne
    reste jamais muet).
  - Noté :
- [ ] **Fermer juste après un geste**
  - Geste : poser une case et fermer la fenêtre AUSSITÔT ; relancer.
  - Attendu : la case est là (la fermeture écrit ce qui attendait).
  - Noté :
- [ ] **New / Open / Save as / Recent** (atelier Project, section Save · open)
  - Geste : « New » deux fois ; « Save as » vers `D:\MB_essais\mon_monde.mbproj` ; « Open » d'un autre ; la rangée « Recent ».
  - Attendu : « New » crée `untitled 2\`, `untitled 3\`… chacun dans son dossier sous `Documents\MarchingBlocks` ;
    « Save as » écrit là où tu dis et continue d'enregistrer là ; « Recent » rouvre en un clic, sans le projet ouvert ni
    l'exemple.
  - Noté :
- [ ] **« File icons & double-click » (Project)**
  - Geste : décocher la case ; regarder un `.mbproj` dans l'Explorateur ; recocher.
  - Attendu : décochée, « File icons & double-click removed from your Windows account… » et l'icône disparaît (après
    rafraîchissement) ; recochée, elle revient. Relancer l'appli ne la recoche pas toute seule.
  - Noté :
- [ ] **Le mode d'emploi (F1)**
  - Geste : `F1`, parcourir les sept onglets (« 1 · Getting started » à « 7 · Shortcuts »), `Échap`.
  - Attendu : texte lisible, qui défile, aucune phrase qui contredit l'écran (note toute contradiction : nom de bouton
    absent, raccourci qui ne fait pas ce qui est écrit). `Échap` et `F1` le ferment.
  - Noté :
- [ ] **Les six teintes du témoin et leur légende**
  - Geste : atelier Geometry, regarder le témoin et la légende de la barre de gauche.
  - Attendu : six familles nommées (sol, paroi, plafond × air libre / sous roche) qu'on distingue au premier coup d'œil.
  - Noté :
- [ ] **Les ateliers**
  - Geste : cliquer chaque atelier : Project, World, Fluids, Geometry, Texturing, Play test, Transitions, Animation, Foliage.
  - Attendu : chacun change la barre de droite et sa teinte ; aucun ne laisse un panneau vide qui mange la vue ; la
    barre de droite ne déborde jamais du bord droit de l'écran.
  - Noté :

---

## SÉANCE 4 — World : peindre (60 min)

Début : ____ Fin : ____

Sur ton monde (untitled) d'abord, puis sur l'exemple (pour la vitesse). Rien de cette barre n'a été tenu à la souris.

- [ ] ⚠ **La vitesse d'un geste sur l'exemple** (mesurée à ~40 ms, jamais ressentie)
  - Geste : dans l'exemple, poser des cases au clic, `Ctrl+Z`, `Ctrl+Y`, un long coup de pinceau.
  - Attendu : aucune saccade visible après un geste ; un coup de pinceau suit la souris.
  - Noté :
- [ ] ⚠ **La molette sous Windows : Alt + molette** (jamais mesurée sous Windows, dans l'appli ni dans les greffons)
  - Geste : outil Add, `Alt` + molette dans la vue ; puis `Maj` + molette ; puis `Ctrl` + molette.
  - Attendu : Alt change la taille du pinceau, Maj sa forme, Ctrl l'étage de la grille ; à chaque cran, la nouvelle
    valeur s'écrit près du pointeur. Windows ne doit pas voler Alt (menu, son « ding »).
  - Noté :
- [ ] ⚠ **Le premier clic dans un monde vide**
  - Geste : monde neuf, outil Add, visée Grid, clic dans la vue.
  - Attendu : une case posée sur le plan de la grille, un aperçu vert juste avant le clic.
  - Noté :
- [ ] ⚠ **Le clic retenu par la barre d'attente** (corrigé le 6 octobre : un clic tombait sous le panneau et se perdait)
  - Geste : sur l'exemple, refaire plusieurs fois un geste long (cacher / montrer une couche, `Ctrl+Z` d'une grosse
    action) puis cliquer AUSSITÔT au centre de l'écran.
  - Attendu : la barre « Undo »… s'affiche pour les gestes longs ; ton clic suivant n'est jamais perdu.
  - Noté :
- [ ] **Grid et Sculpt (`Tab`)**
  - Geste : `Tab` plusieurs fois.
  - Attendu : alterne Grid et Sculpt seulement. En Sculpt, Add construit contre la face visée ; Dig et Select agissent
    sur la case visée.
  - Noté :
- [ ] **L'étage de la grille**
  - Geste : `PgUp` / `PgDn` ; puis `Ctrl` + clic sur de la matière.
  - Attendu : le plan monte et descend ; `Ctrl` + clic met la grille à la hauteur de la case cliquée sans rien peindre,
    et le rapport le dit.
  - Noté :
- [ ] **Add / Dig / Select (`A` `D` `S`), clic droit = l'inverse**
  - Geste : chaque outil, clic gauche puis clic droit.
  - Attendu : Add ajoute, clic droit creuse ; Dig creuse, clic droit ajoute ; Select peint une sélection bleue.
  - Noté :
- [ ] **Le pinceau : taille et forme**
  - Geste : `[` `]` ; formes sphère, cube, disque ; disque contre une paroi.
  - Attendu : taille 1 à 7 ; l'aperçu montre les cases exactes (vert ajoute, rouge creuse, bleu sélectionne) ; le disque
    remplit une paroi sans l'épaissir.
  - Noté :
- [ ] **Le glissé d'Add ne bâtit pas une tour vers la caméra**
  - Geste : Add, visée Sculpt, glisser sur un sol.
  - Attendu : une peau posée sur la surface, pas une colonne qui monte vers toi.
  - Noté :
- [ ] **Navigate (`Espace`) et le vol**
  - Geste : `Espace`, voler en `Z Q S D`, `A` descend, `E` monte, clic droit glissé pour regarder ; `Espace` à nouveau.
  - Attendu : aucun clic ne peint en vol ; `S`, `D`, `A` ne changent PAS d'outil ; retour à la visée d'avant.
  - Noté :
- [ ] **Vue : tourner, glisser, zoomer, dézoomer loin**
  - Geste : clic du milieu glissé, `Maj` + clic du milieu, molette jusqu'au plus loin.
  - Attendu : on peut reculer très loin (jusqu'à ~1 000 cases) ; les ombres suivent.
  - Noté :
- [ ] **F cadre toute la matière, ² saute sur la matière**
  - Geste : `F` ; puis viser une falaise lointaine et appuyer `²` (la touche sous Échap).
  - Attendu : `F` montre toute la matière ; `²` amène la caméra à quelques cases de la face visée, jamais dedans ; dans le
    vide, rien ne bouge et le rapport le dit.
  - Noté :
- [ ] **Rect (`R`) et Box (`B`), Hollow box**
  - Geste : `R` glissé à plat ; pendant le glissé, molette (le Rect devient une boîte) ; `B` en visée Sculpt ; cocher
    « Hollow box ».
  - Attendu : toute la zone devient la sélection, cases vides comprises ; Hollow ne garde que la peau.
  - Noté :
- [ ] **Fill, Delete (`Suppr`), Clear (`Échap`)**
  - Geste : Rect, Fill ; sélectionner de la matière, `Suppr` ; `Échap`.
  - Attendu : Fill remplit les cases vides de la sélection ; `Suppr` retire la matière ; `Échap` oublie la sélection.
  - Noté :
- [ ] **Extrude up / down / facing, avec Maj et Alt**
  - Geste : sélection d'un sol, « Extrude up » trois clics ; `Maj` + clic ; `Alt` + clic ; « Facing » sur un mur.
  - Attendu : chaque clic pose une rangée, la sélection et l'étage suivent ; Maj étend la sélection sans poser ; Alt la
    décale sans poser ; Facing épaissit un mur.
  - Noté :
- [ ] **Shrink, Widen, Grow, Connected, Extend selection ↑ / ↓**
  - Geste : sur un Rect : Shrink ; Widen ; Extend selection ↑ deux fois puis Fill.
  - Attendu : Shrink enlève le bord (le rectangle perd son pourtour, il ne DISPARAÎT plus — défaut corrigé) ; Extend
    ajoute une rangée au-dessus, cases vides comprises, sans poser de matière ; Fill fait un bloc.
  - Noté :
- [ ] **« Select empty cells too »**
  - Geste : Select, cocher la case, pinceau disque, peindre une empreinte au sol.
  - Attendu : l'air est sélectionné aussi (aperçu compris).
  - Noté :
- [ ] **Copier / couper / coller, flèches**
  - Geste : `Ctrl+C`, `Ctrl+V` (le collage suit la souris), molette pendant le collage, clic ; flèches ; `Maj` + ↑.
  - Attendu : le collage se pose d'un clic, fusionne avec la matière sans l'effacer ; les flèches déplacent dans le sens
    de la caméra ; `Maj` + ↑ lève.
  - Noté :
- [ ] **Les cubes rouges et « Fix diagonal contacts »**
  - Geste : peindre deux cases qui ne se touchent que par une arête ; puis « Fix diagonal contacts » → « Fill », `Ctrl+Z`, « Dig ».
  - Attendu : un cube rouge à l'endroit du contact (rien n'est réparé en silence) ; les boutons le réparent en une
    action et disent combien de cases restent.
  - Noté :
- [ ] **« Clear the layer »**
  - Geste : le bouton, puis `Ctrl+Z`.
  - Attendu : toutes les cases de la couche partent ; `Ctrl+Z` les rend.
  - Noté :
- [ ] **Annuler / refaire en série**
  - Geste : vingt gestes variés, puis vingt `Ctrl+Z`, puis vingt `Ctrl+Y`.
  - Attendu : le monde revient exactement, sans reste visible ni cube rouge orphelin.
  - Noté :
- [ ] **« Where is it from? »**
  - Geste : survoler une tuile dans World ; « Show it in the witness ».
  - Attendu : le bandeau nomme la forme du témoin d'où vient la tuile ; le bouton mène dans Geometry, une boîte blanche
    sur l'endroit.
  - Noté :

---

## SÉANCE 5 — World : formes spéciales et salles (45 min)

Début : ____ Fin : ____

Section « Special shapes » de World. Escalier : **ni vu à l'image, ni tenu en main** (proposé en entier par Claude).

- [ ] ⚠ **Stairs, d'un clic contre une paroi**
  - Geste : « Stairs », cliquer une paroi à la hauteur où l'escalier doit arriver ; « Step » 1 puis 2 ; « Rail ».
  - Attendu : le palier au niveau de la case cliquée, l'escalier descend vers toi jusqu'au sol ; un `Ctrl+Z`.
  - Noté :
- [ ] ⚠ **Stairs, Connect de sol à sol, et le Play test**
  - Geste : « Connect », cliquer un sol bas puis un sol haut ; puis monter l'escalier au Play test (séance 7).
  - Attendu : l'escalier partage la montée ; cliquer une paroi est refusé et dit ; le personnage monte les marches (pas 1
    = pente à 45°, à la limite de ce qu'il gravit).
  - Noté :
- [ ] ⚠ **Stairs contre une paroi en biais** (défaut connu, non corrigé : en taille 1 il ne touche pas la paroi)
  - Geste : une paroi à 45°, Stairs taille 1 puis taille 2.
  - Attendu connu : taille 1 décollée, taille 2 pleine. Note si ça gêne.
  - Noté :
- [ ] **Tunnel, Well, Bridge, Balcony (Straight)**
  - Geste : chaque forme, un clic sur la matière ; profils Round / Square / Arch ; « Size » (`[` `]`) ; « Depth »,
    « Reach », « Length ».
  - Attendu : l'aperçu montre les cases exactes (rouge creuse, vert ajoute) ; un tunnel débouche dans la grotte suivante
    ou finit en cul-de-sac (dit) ; un pont va jusqu'au premier mur en face.
  - Noté :
- [ ] **Connect (deux clics)**
  - Geste : Tunnel en Connect : une paroi, puis une autre ; `Échap` entre les deux.
  - Attendu : l'ancre du premier clic en ambre ; `Échap` ou clic droit l'oublie ; deux bouts ouverts.
  - Noté :
- [ ] **Les formes en biais disent ce qu'elles ajoutent**
  - Geste : un tunnel dans une paroi à 45°.
  - Attendu : il part à 45° ; le rapport dit combien de cases il a ajoutées pour éviter les contacts par une arête.
  - Noté :
- [ ] **Room (tracée)**
  - Geste : « Room », glisser un rectangle d'au moins 3 × 3 sur la grille ; molette pendant le tracé (Floors) ; « Down ».
  - Attendu : une salle creuse, murs d'une case ; rouge = ce qui sera creusé ; une salle trop étroite est refusée et dite.
  - Noté :
- [ ] **Room from selection**
  - Geste : Select + « Select empty cells too » + disque, peindre une empreinte en L ; section Selection : Floors,
    Up / Down, « Room from selection ».
  - Attendu : la salle épouse l'empreinte ; un `Ctrl+Z` ; les réglages Floors sont les mêmes que ceux de Room.
  - Noté :
- [ ] **La molette pendant les formes**
  - Geste : `Alt` / `Maj` + molette sur Tunnel, Stairs (`Ctrl` + `Maj` = Step), Room.
  - Attendu : comme la table « The mouse wheel » du manuel (onglet 7).
  - Noté :
- [ ] **La vitesse de l'aperçu sur l'exemple**
  - Geste : dans l'exemple, survoler la matière avec un tunnel rond de taille 7.
  - Attendu : l'aperçu suit la souris sans traîner.
  - Noté :

---

## SÉANCE 6 — Couches et variantes dans World (45 min)

Début : ____ Fin : ____

- [ ] ⚠ **Cacher / montrer une couche sur l'exemple** (mesuré de 7 s à ~0,4 s ; jamais ressenti)
  - Geste : l'œil d'une couche de l'exemple, plusieurs fois, en alternant deux couches.
  - Attendu : moins d'une demi-seconde ; le monde se referme sans la couche cachée ; en réapparaissant, aucune tuile
    fausse à la frontière (défaut déjà corrigé une fois).
  - Noté :
- [ ] ⚠ **Une case n'appartient qu'à une couche**
  - Geste : deux couches ; peindre dans B des cases de A ; `Ctrl+Z`.
  - Attendu : la case passe à B, la frontière est continue (aucune rainure) ; `Ctrl+Z` la rend à A ; la liste recompte
    les cases des deux couches.
  - Noté :
- [ ] **New layer / Copy witness / Delete layer / renommer**
  - Geste : « New layer », « Copy witness », taper un nom dans le champ sous la liste, « Delete layer », `Ctrl+Z`.
  - Attendu : chaque ligne montre une vignette, l'origine du témoin et son état (« sliced », « slice again »…) ;
    « Delete layer » est grisé quand il ne reste qu'une couche ; `Ctrl+Z` rend la couche.
  - Noté :
- [ ] **Up / Down**
  - Geste : deux couches qui se touchent ; « Up » ; `Ctrl+Z`.
  - Attendu : la frontière change de propriétaire (les coins prennent les tuiles de la couche du haut) ; grisés aux bouts.
  - Noté :
- [ ] **L'outil Variant** (il faut une tuile à variantes : séance 10, ou l'exemple s'il en porte)
  - Geste : section Variants : outil Variant, clic sur une tuile, re-clic, clic droit.
  - Attendu : la tuile passe à la variante suivante puis revient au tirage ; un `Ctrl+Z` par clic.
  - Noté :
- [ ] **Les poids « pour la clé pointée »** (jamais jugé par Jordan)
  - Geste : pointer une tuile, régler ses poids (0 pour la base).
  - Attendu : on comprend sans le manuel de quelle tuile on règle les poids ; un poids 0 la fait disparaître du tirage.
  - Noté :
- [ ] **« On the selection » et « Back to random everywhere »**
  - Geste : sélectionner des cases, Random / Base / Variant k ; puis « Back to random everywhere ».
  - Attendu : les tuiles touchées changent ; tout revient au tirage.
  - Noté :

---

## SÉANCE 7 — Play test (45 min)

Début : ____ Fin : ____

Sur l'exemple. Le ressenti (vitesse, saut, caméra) n'a jamais été jugé « clavier en main ».

- [ ] ⚠ **Entrer dans le Play test sur l'exemple** (mesuré 22 s → 1,5 s)
  - Geste : atelier Play test.
  - Attendu : le personnage (stickman noir, yeux violets) apparaît en ~1,5 s, posé sur la surface ; pas de chute à
    travers le sol en s'éloignant (le décor se bâtit autour de lui).
  - Noté :
- [ ] ⚠ **Les faces vues de dos et les dessous de surplomb** (aucune garde : un trou connu des tests)
  - Geste : marcher sous un surplomb, contre les coupes ouvertes, dans une grotte, sauter contre un plafond.
  - Attendu : jamais de traversée de la roche, jamais de chute dans le vide sous le sol.
  - Noté :
- [ ] ⚠ **Le vol (`F`) et la perte de focus** (un faux défaut du tournage, mais vérifier le vrai)
  - Geste : `F`, voler (`Z`, `Espace`/`E` monte, `A` descend), puis `Alt+Tab` vers une autre fenêtre et revenir.
  - Attendu : en revenant, les touches doivent être ré-appuyées (Windows les relâche) — normal ; le vol reprend dès
    qu'on réappuie, il heurte toujours le décor.
  - Noté :
- [ ] **Marcher, courir, sauter**
  - Geste : `Z Q S D`, `Maj`, `Espace`.
  - Attendu : un saut franchit plus d'une case ; le pas de 0,3 case monte les petites marches. Note si c'est trop lent,
    trop rapide, trop flottant.
  - Noté :
- [ ] **La caméra**
  - Geste : clic gauche glissé (orbite), clic droit glissé (à plat), molette ; se coller à une paroi.
  - Attendu : la caméra ne passe jamais à travers la roche, elle se rapproche sans à-coup et ressort en douceur.
  - Noté :
- [ ] **« Character size »**
  - Geste : le curseur, de 0,4 à 1,5.
  - Attendu : le personnage, sa vitesse et la caméra suivent ; le saut reste le même.
  - Noté :
- [ ] **Nager, plonger, sortir de l'eau, le courant**
  - Geste : entrer dans un lac ; `A` plonge, `Espace` remonte ; nager contre une berge ; marcher dans une rivière.
  - Attendu : il flotte, plonge, la vue se voile sous la surface (orange dans la lave, vert dans l'acide) ; il se hisse
    sur une berge d'une case ; une rivière le pousse dans son sens.
  - Noté :
- [ ] **La météo**
  - Geste : barre de droite, « Weather » : Rain, Blizzard, Hurricane, Slow snow, Hanging particles, Heat, Fog, None.
  - Attendu : chacun se voit ; la phrase « not saved with the project… » ; en quittant le Play test tout s'en va ; en
    revenant, le dernier temps revient. Note si l'ouragan fait ramer.
  - Noté :
- [ ] **Les réglages de rendu, le disque solaire, « Reset »**
  - Geste : bouger soleil, SSAO, SDFGI, « Sun disk size » ; « Reset ».
  - Attendu : tout change à l'écran ; « Reset » rend les défauts et la météo à None ; en quittant, World retrouve son
    éclairage de travail.
  - Noté :
- [ ] **`Retour arrière` et `Échap`**
  - Geste : s'éloigner, `Retour arrière` ; puis `Échap`.
  - Attendu : retour au départ ; puis retour dans World ; aucune case changée.
  - Noté :

**Bilan des deux premières heures** : additionne les durées des séances 1 à 7 (hors notes). Tout ce qui a bloqué ou
fait douter pendant ce temps est prioritaire.

---

## SÉANCE 8 — Fluids : l'eau (60 min)

Début : ____ Fin : ____

Sur une copie de l'exemple (« Save as » vers `D:\MB_essais\eau.mbproj`) et sur un petit monde à toi.

- [ ] ⚠ **La mer : le plan, l'épingle, la pose** (décidé le 4 octobre, jamais tenu)
  - Geste : atelier Fluids ; survoler le VIDE ; clic ; molette, `PgUp`/`PgDn` ; second clic (ou `Entrée`).
  - Attendu : au survol, un plan plat seulement (rien ne se calcule) ; le premier clic épingle la hauteur ; la molette la
    règle ; le second clic pose la mer (barre d'attente), UNE fois. Clic droit ou `Échap` abandonnent (Échap ne quitte
    PAS Fluids à ce moment).
  - Noté :
- [ ] ⚠ **Un seul océan**
  - Geste : poser une mer à une autre hauteur ; puis à la même.
  - Attendu : la mer se DÉPLACE (l'ancienne part dans la même action) ; à la même hauteur, rien, et l'écran le dit
    (« already »).
  - Noté :
- [ ] ⚠ **Le second clic dans Fluids** (le clic rejoué était avalé par le panneau d'attente, corrigé le 6 octobre)
  - Geste : poser plusieurs rivières à la suite, vite.
  - Attendu : chaque clic pose sa rivière ; aucun clic perdu sans un mot.
  - Noté :
- [ ] **Un lac**
  - Geste : clic dans un creux.
  - Attendu : le creux se remplit à ras bord ; un creux près d'une chute (≤ 4 cases) déborde en rivière.
  - Noté :
- [ ] **Une rivière et ses cascades**
  - Geste : clic sur une pente ou un replat ; « River width » 1 puis 5 (ou `Alt` + molette).
  - Attendu : elle descend, tombe en cascade (une nappe courbe, de l'écume au pied, une source au départ), remplit les
    creux ; la largeur pose plusieurs sources côte à côte en UN `Ctrl+Z`.
  - Noté :
- [ ] **L'eau suit le monde**
  - Geste : creuser un chenal dans la berge d'un lac ; `Ctrl+Z`.
  - Attendu : l'eau s'écoule par le chenal, puis revient ; une case d'une couche CACHÉE retient toujours l'eau.
  - Noté :
- [ ] **Retirer l'eau, un clic dans l'eau**
  - Geste : clic droit sur une eau ; clic gauche dans une eau existante.
  - Attendu : le clic droit retire la source ; le clic gauche ne pose rien et le dit.
  - Noté :
- [ ] **« Look » : les six aspects**
  - Geste : pour une couche d'eau, Stylized, Clear, Reflective, Lava, Swamp water, Glowing acid.
  - Attendu : chacun se voit tout de suite ; aucune ligne « SHADER ERROR » dans `godot.log`.
  - Noté :
- [ ] **Les couches d'eau**
  - Geste : « New water layer », œil, Delete.
  - Attendu : chaque couche d'eau a son aspect ; une seconde mer dans une autre couche est dite « other sea ignored ».
  - Noté :
- [ ] **Sortir proprement : `Échap`, « Leave », un autre atelier**
  - Geste : les trois façons.
  - Attendu : retour dans World avec l'outil d'avant : les clics peignent des cases, plus jamais de l'eau.
  - Noté :
- [ ] **La vitesse de l'eau sur l'exemple**
  - Geste : poser / retirer une rivière, `Ctrl+Z`, `Ctrl+Y` sur l'exemple.
  - Attendu : moins d'une seconde chaque fois.
  - Noté :

---

## SÉANCE 9 — Geometry : le modeleur du témoin (60 min)

Début : ____ Fin : ____

Tout ce qui suit est « PAS TENU EN MAIN » dans la charte. Projet neuf (une couche), atelier Geometry.

- [ ] ⚠ **Entrer en édition (`Tab`) et la tuile cliquée**
  - Geste : `Tab` ; cliquer une copie de paroi ; cliquer une copie d'une autre tuile.
  - Attendu : barre d'attente « Opening the witness editor » (~2 s) ; on édite la tuile cliquée, toutes ses copies
    suivent ; une autre tuile change la tuile éditée et vide la sélection.
  - Noté :
- [ ] ⚠ **G sur un sommet de bord : les voisines suivent, aucune fente**
  - Geste : `2` ou `1`, un sommet sur le bord de la tuile, `G` puis bouger, clic ; `Ctrl+Z`.
  - Attendu : le sommet glisse dans son plan ; les tuiles voisines suivent ; aucune fente aux joints ; un `Ctrl+Z` rend
    TOUTES les tuiles.
  - Noté :
- [ ] ⚠ **La bride : « stopped at N% »**
  - Geste : tirer une face de paroi loin de côté (`G` `X` puis un grand nombre, `Entrée`).
  - Attendu : le geste s'arrête avant de replier une face, ici ou dans une autre tuile ; le rapport dit « stopped at
    N% ». Note si l'arrêt surprend ou si la souris « colle » (~50 ms par mouvement mesurés quand la bride cherche).
  - Noté :
- [ ] ⚠ **Le couteau qui traverse les bords (`K`)**
  - Geste : `K`, un clic dans une paroi, un clic AU-DELÀ du bord dans la copie voisine, `Entrée`.
  - Attendu : la coupe passe sur les deux copies (« across 2 copies »), joints fermés, un `Ctrl+Z`. Derrière une autre
    copie, le trait est coupé et dit.
  - Noté :
- [ ] **Sélection : clic, `Maj`, `Alt`+clic, `A`, `Alt+A`, `B`, `Alt+Z`**
  - Geste : chacun, en modes `1` `2` `3`.
  - Attendu : on ne prend que ce qu'on voit, sauf en X-ray (`Alt+Z`).
  - Noté :
- [ ] **Lasso et cercle**
  - Geste : `Ctrl` + clic droit glissé ; `Maj+Ctrl` ; `C`, peindre, molette, clic droit.
  - Attendu : le tracé se dessine ; le cercle se règle à la molette et finit au clic droit / `Échap` / `Entrée`.
  - Noté :
- [ ] **G R S, axes, nombres, `O`**
  - Geste : `G` `Z` `0.1` `Entrée` ; `R` `45` ; `S` ; `O` puis molette pendant un `G`.
  - Attendu : Z monte (comme Blender), même sur une copie tournée ; `Échap` ou clic droit annulent.
  - Noté :
- [ ] **E sur une face de bord (épinglé)**
  - Geste : `3`, une face qui touche le bord, `E` `0.1` `Entrée`.
  - Attendu : le milieu monte, les sommets du bord restent sur leur plan ; aucun trou.
  - Noté :
- [ ] **E sur une arête : refusé sauf au bord d'un trou**
  - Geste : `2`, une arête entre deux faces, `E`.
  - Attendu : refusé et dit.
  - Noté :
- [ ] **M au bord, X, `Ctrl+X` (Dissolve), F, Subdivide, I, `Ctrl+B`, `Ctrl+R`**
  - Geste : chacun sur la paroi.
  - Attendu : M sur un sommet de bord fusionne SUR le bord ; deux sommets de bord à des places différentes : refusé ;
    X ouvre un trou ; `Ctrl+X` le referme d'une face ; chaque geste est un `Ctrl+Z`.
  - Noté :
- [ ] **Fill holes / Fill holes · all tiles**
  - Geste : X sur une face de bord ; lire la ligne qui compte les trous ; « Fill holes ».
  - Attendu : le compteur voit le trou ; le bouton le referme (bord recréé), un `Ctrl+Z` ; ce qui ne se recrée pas est dit.
  - Noté :
- [ ] **« Match other layers to this one »**
  - Geste : deux couches dont l'une sculptée sur un bord ; lire la ligne ; le bouton.
  - Attendu : la ligne compte les points de bord qui divergent ; le bouton les cale, un `Ctrl+Z`.
  - Noté :
- [ ] **Les onglets « The tiles » et « Shapes »**
  - Geste : survoler des cartes, cliquer ; replier le bandeau par sa flèche.
  - Attendu : les copies s'allument ; le clic cadre la copie la plus claire ; les photos et les phrases se lisent.
  - Noté :
- [ ] **« Reset to the computed witness »**
  - Geste : le bouton (« The modelled witness »), `Ctrl+Z`.
  - Attendu : le témoin de la couche repart de zéro ; `Ctrl+Z` le rend.
  - Noté :
- [ ] **Le monde suit son témoin**
  - Geste : sculpter une paroi, passer dans World.
  - Attendu : barre d'attente courte (~0,5 s), le monde montre la paroi sculptée.
  - Noté :

---

## SÉANCE 10 — Geometry : sculpt et variantes (45 min)

Début : ____ Fin : ____

- [ ] ⚠ **Sculpt : un trait sur un bord**
  - Geste : section Sculpt, l'interrupteur, Draw, un trait qui passe sur un bord de tuile ; `Ctrl+Z`.
  - Attendu : le relief suit le pinceau, les voisines suivent sur le bord, aucun joint ouvert ; un `Ctrl+Z` par trait.
    Note la fluidité (~10 ms par coup mesurés sans fenêtre, jamais avec).
  - Noté :
- [ ] **Les cinq pinceaux et les modificateurs**
  - Geste : Draw, Inflate, Smooth, Flatten, Grab ; `Ctrl` creuse ; `Maj` lisse ; rayon, force, dureté ; `Alt`/`Maj` + molette.
  - Attendu : le cercle sous la souris montre le rayon ; chaque pinceau fait ce que son nom dit.
  - Noté :
- [ ] **Texturing éteint le sculpt**
  - Geste : passer dans Texturing pendant que le sculpt est allumé.
  - Attendu : plus de sculpt ; G R S X… ne touchent à rien et l'écran renvoie à Geometry.
  - Noté :
- [ ] **« New variant from this copy »**
  - Geste : cliquer une copie de paroi ; section Variants : « New variant from this copy » ; sculpter son milieu.
  - Attendu : seule cette copie montre la variante ; ses bords restent ceux de la tuile.
  - Noté :
- [ ] **« This copy shows » et « Delete this variant »**
  - Geste : basculer une autre copie sur la variante ; supprimer une variante ; `Ctrl+Z`.
  - Attendu : la variante se juge à côté de ses vraies voisines ; supprimer renumérote les suivantes.
  - Noté :
- [ ] **Les variantes dans World**
  - Geste : passer dans World (séance 6 : l'outil Variant).
  - Attendu : base et variante mêlées par le tirage, le même à chaque reconstruction.
  - Noté :

---

## SÉANCE 11 — Texturing : matériaux, peinture, PBR (60 min)

Début : ____ Fin : ____

- [ ] ⚠ **« Bake base colour » fait quelque chose** (signalé « ne fait rien » le 3 octobre, corrigé)
  - Geste : « Unwrap all tiles (atlas) » ; puis « Bake base colour » ; `Ctrl+Z`.
  - Attendu : sols, parois, plafonds prennent leur couleur, arêtes usées, creux ombrés ; `Ctrl+Z` rend l'ancien. En
    projection Boîte, refusé et dit.
  - Noté :
- [ ] ⚠ **Les ensembles PBR (une image avec ses cartes à côté)**
  - Geste : un matériau, « Image… » → une image `…_color_1k.png` qui a ses `…_normal_gl_1k.png`,
    `…_roughness_1k.png`… à côté (ex. `D:/Spirit3D/HEART_WORLD/`).
  - Attendu : l'image est copiée dans le projet avec ses cartes ; le relief se voit à la lumière (pas seulement
    l'albedo) ; l'original n'est jamais touché par la peinture.
  - Noté :
- [ ] **New material, Assign, projections**
  - Geste : « New material », sélectionner des faces, « Assign » ; Box, Top, Front, Side ; répétition.
  - Attendu : la texture se pose sans dépliage ; une image tuilable se raccorde d'une tuile à l'autre.
  - Noté :
- [ ] **U, l'atlas, « Export UV layout… »**
  - Geste : `U` sur des faces ; « Unwrap all tiles (atlas) » ; « Export UV layout… ».
  - Attendu : `U` prévient si une autre tuile partage le même carré ; le patron PNG s'écrit.
  - Noté :
- [ ] **Peindre (`P`), pipette, gomme**
  - Geste : `P`, glisser sur une copie ; `Alt` + clic ; `E` ; `Ctrl+Z`.
  - Attendu : un trait continu (pas en pointillés), toutes les copies suivent ; la pipette prend la couleur ; la gomme
    rend le fond sur le calque du bas ; un `Ctrl+Z` par trait.
  - Noté :
- [ ] **Le curseur du pinceau et les bandes de couture**
  - Geste : survoler une face dépliée étirée ; « Seam bands » décochée puis cochée.
  - Attendu : une ellipse là où le dépliage étire ; bandes roses rayées sur les plans de coupe ; un petit anneau rouge
    sur une face sans matériau.
  - Noté :
- [ ] **Les calques de peinture**
  - Geste : New, peindre, œil, Up / Down, opacité, « Merge down », Delete, `Ctrl+Z`.
  - Attendu : chaque geste s'annule ; l'image affichée ne change pas à « Merge down ».
  - Noté :
- [ ] **Les cartes PBR déduites**
  - Geste : « Derive PBR maps from the image », bouger « Fine detail », « Contrast »… ; « Reset settings ».
  - Attendu : « PBR maps: updating… » puis le relief apparaît ; la peinture met les cartes à jour un instant après.
  - Noté :
- [ ] **L'émission**
  - Geste : une image `panel_color.png` avec `panel_emission.png` à côté ; curseur « Emission » à 5.
  - Attendu : les parties claires de la carte luisent ; au Play test, le halo.
  - Noté :

---

## SÉANCE 12 — Animation, Transitions, Foliage (60 min)

Début : ____ Fin : ____

- [ ] ⚠ **Transitions : allumer une paire**
  - Geste : deux couches côte à côte au même niveau, de matériaux différents ; atelier Transitions ; cocher la paire.
  - Attendu : un fondu doux, continu d'une tuile à l'autre. ⚠ Regarde de près les joints de la bande : de fins
    pointillés clairs y ont été vus, non expliqués.
  - Noté :
- [ ] ⚠ **Transitions sur l'exemple** (jamais mesuré sur un grand monde)
  - Geste : dans l'exemple, allumer une paire.
  - Attendu : pas de gel de plusieurs secondes ; note le temps.
  - Noté :
- [ ] **Les réglages et le pinceau de Transitions**
  - Geste : Softness, Reach, Irregularity, Grain, Fills hollows dans les deux sens ; le pinceau « … covers », Radius,
    `Alt` + molette, clic droit ; `Échap`.
  - Attendu : chaque réglage se voit ; teinte jaune là où l'on a peint (dans l'atelier seulement) ; `Échap` → World.
  - Noté :
- [ ] **Animation : ajouter une piste**
  - Geste : atelier Animation ; « Add a track » : Base colour → Scroll ; puis Frames from image files… ; Pulse sur l'émission.
  - Attendu : seules les pistes ajoutées apparaissent, chacune avec son « − » ; ça bouge sur le témoin.
  - Noté :
- [ ] **Animation : Playback et peindre image par image**
  - Geste : Pause, Restart, Speed, Hold frame ; « Blank frames to paint », puis dans Texturing « Frame ◀ ▶ » et peindre.
  - Attendu : le temps s'arrête en peignant ; le trait va sur l'image choisie seulement.
  - Noté :
- [ ] **Foliage : importer un modèle**
  - Geste : atelier Foliage, « Import .glb… » (ex. un arbre de `D:/Spirit3D/HEART_WORLD/biomes/maps/`) ; le socle,
    « Ground offset », « Sit its base on the ground ».
  - Attendu : le modèle debout sur le socle, le plan translucide qui prolonge le sol.
  - Noté :
- [ ] **Foliage : les trois modes et le pinceau**
  - Geste : In the air, Planted · free, Planted · overflow ; un clic, puis le pinceau (`Alt` / `Maj` + molette) ; clic
    droit ; `Ctrl+Z`.
  - Attendu : fantôme vert = oui, rouge = non (bord de falaise refusé en « free ») ; les arbres se balancent ; un coup de
    pinceau = un `Ctrl+Z`.
  - Noté :
- [ ] **Foliage : ce qui n'est pas fait, est-ce dit ?**
  - Geste : creuser sous un arbre ; marcher dedans au Play test.
  - Attendu connu : l'arbre reste en l'air, on traverse les troncs — note si c'est gênant pour un acheteur.
  - Noté :

---

## SÉANCE 13 — L'aller-retour avec Blender, et les exports (60 min)

Début : ____ Fin : ____

« Ni la route Blender par Jordan » : jamais faite à la main. Ces exports servent aux séances 16 à 18.

- [ ] ⚠ **Exporter le témoin (étape 1)**
  - Geste : Project, « Export the witness… ».
  - Attendu : un `.glb` écrit ; dans Blender 5.1, File → Import → glTF : 52 maillages liés (modifier une copie modifie
    les autres).
  - Noté :
- [ ] ⚠ **Sculpter dans Blender et revenir**
  - Geste : dans Blender, retoucher une copie (sans la déplacer, sans Join), File → Export → glTF 2.0 (.glb) ; dans
    l'appli « Import the work… » puis « Slice the selected work ».
  - Attendu : le travail s'affiche tel que le trancheur le lira ; tranché, le monde porte ta retouche partout ; le
    rapport liste les remarques de couture.
  - Noté :
- [ ] **Un Join dans Blender est dit**
  - Geste : Join de deux copies dans Blender, réexport, réimport.
  - Attendu : le rapport nomme la tuile dont les copies divergent ; rien n'est départagé en silence.
  - Noté :
- [ ] **« Slice this layer's witness » (étape 3)**
  - Geste : le bouton.
  - Attendu : barre d'attente, l'écran reste vivant pendant le tranchage.
  - Noté :
- [ ] ⚠ **« Export the tileset… » (étape 4)**
  - Geste : exporter la couche active de l'exemple vers `D:\MB_essais\exports\`.
  - Attendu : un dossier `.mbset` avec `tileset.json`, `tiles.glb`, `README.txt` ; ⚠ son icône de dossier dans
    l'Explorateur (jamais vue depuis le bouton d'export).
  - Noté :
- [ ] ⚠ **« Export the world… » (Painted world)**
  - Geste : World, « Export the world… » de l'exemple (et d'un petit monde avec eau, transitions, feuillage, une
    texture animée).
  - Attendu : un dossier `.mbworld` (`world.json`, un `.mbset` par source, `water\`, `foliage\`, `transitions\`) ; le
    panneau d'attente ne reste pas bloqué (il pend dans les tests sans fenêtre).
  - Noté :
- [ ] **Exporter une couche sans tuiles**
  - Geste : une couche neuve vide, « Export the tileset… ».
  - Attendu : refusé et dit ; rien d'écrit.
  - Noté :

---

## SÉANCE 14 — La démo (30 min)

Début : ____ Fin : ____

Lancer `build\demo\MarchingBlocks.exe` (de préférence dans la session Windows « Essai »).

- [ ] ⚠ **Le contrat, pas de clé**
  - Geste : premier lancement.
  - Attendu : le contrat (« I accept » / « Quit »), puis l'appli SANS demander de clé ; la barre de titre dit
    « FREE DEMO — no saving, no export ».
  - Noté :
- [ ] ⚠ **Les refus sont dits**
  - Geste : « Open », « Save as », « Export the witness… », « Export the tileset… », « Export the world… »,
    « Export UV layout… ».
  - Attendu : chaque refus est DIT (« Free demo — everything works, but saving, opening your own projects and exporting
    are in the full version… »), aucun dialogue de fichier ne s'ouvre.
  - Noté :
- [ ] ⚠ **Tout le reste marche**
  - Geste : peindre, l'exemple, l'eau, le Play test, le modeleur.
  - Attendu : comme dans la version complète.
  - Noté :
- [ ] **La fermeture vide tout**
  - Geste : fermer, regarder `%APPDATA%\MarchingBlocks Demo\` et `Documents`.
  - Attendu : le bac `demo_scratch` est vide ; rien dans `Documents` ; tes fichiers `.mbproj` gardent leurs icônes de la
    version complète (la démo ne s'inscrit pas).
  - Noté :
- [ ] **About dans la démo**
  - Geste : « About ».
  - Attendu : « Free demo — saving, opening your own projects and exporting are in the full version. »
  - Noté :

---

## SÉANCE 15 — L'exe Steam (20 min)

Début : ____ Fin : ____

Lancer `build\steam\MarchingBlocks.exe` (sans passer par Steam : aucun DRM aujourd'hui).

- [ ] ⚠ **Contrat, pas de clé**
  - Geste : premier lancement (réglages mis de côté).
  - Attendu : le contrat, puis l'appli directement ; About dit « Licensed through your Steam account. » et
    « MarchingBlocks v0.9.0 — Early Access · Steam » (ou approchant).
  - Noté :
- [ ] **Les associations de fichiers sans installeur**
  - Geste : premier lancement, puis double-clic sur un `.mbproj`.
  - Attendu : l'exe Steam s'inscrit lui-même ; le double-clic l'ouvre.
  - Noté :
- [ ] **Pas de case des mises à jour qui fasse quoi que ce soit**
  - Geste : atelier Project.
  - Attendu : Steam livre les mises à jour ; rien ne doit annoncer « Update … available ».
  - Noté :

---

## SÉANCE 16 — Le greffon Godot (60 min)

Début : ____ Fin : ____

Godot 4.7, un projet NEUF (`D:\essai_greffon_godot`). Le greffon dans l'éditeur n'a jamais été tenu : seulement mené
par de faux événements.

- [ ] ⚠ **Installer et activer**
  - Geste : copier `D:\MarchingBlocks\addons\marchingblocks_paint` dans `addons\` du projet neuf ; Project → Project
    Settings → Plugins → activer « MarchingBlocks Paint ».
  - Attendu : aucune erreur dans « Output » ; UN seul « MarchingBlocks » dans la liste des greffons.
  - Noté :
- [ ] ⚠ **La barre au-dessus de la vue 3D**
  - Geste : ajouter un nœud MarchingBlocksWorld, régler **Tileset** sur le `tileset.json` exporté en séance 13 ;
    sélectionner le nœud.
  - Attendu : une rangée d'icônes MarchingBlocks au-dessus de la vue (visée, outil, pinceau, étage, sélection), l'outil
    enfoncé lisible ; chaque icône a son nom et sa touche au survol.
  - Noté :
- [ ] ⚠ **Peindre dans la vue**
  - Geste : clic dans la vue, glisser, `Ctrl+Z`, `Ctrl+Y`.
  - Attendu : des cases posées là où l'œil l'attend, les tuiles suivent ; un `Ctrl+Z` par coup.
  - Noté :
- [ ] ⚠ **`Tab`, `Espace` et la molette dans l'éditeur Godot**
  - Geste : `Tab` ; `Espace` puis voler comme d'habitude ; molette seule ; `Alt` / `Maj` / `Ctrl` + molette.
  - Attendu : Tab alterne Grid / Sculpt ; Espace rend la souris à Godot ; la molette suit la règle de l'appli, la
    valeur s'écrit près de la souris ; `Alt` + molette marche sous Windows.
  - Noté :
- [ ] **Les outils de la barre**
  - Geste : Add, Dig, Select, Rect, Box, Fill, Extrude ↑ ↓ facing (Maj étend, Alt décale), Shrink, « Select empty
    cells too », Room, Room from selection, formes spéciales, copier / coller.
  - Attendu : comme dans l'appli.
  - Noté :
- [ ] **L'outil Variant (`V`)**
  - Geste : `V`, clic, `Maj` + clic.
  - Attendu : la variante suivante ; `Maj` + clic rend le tirage (le clic droit appartient à la vue de Godot).
  - Noté :
- [ ] ⚠ **« Import MarchingBlocks world... »**
  - Geste : copier le `.mbworld` de la séance 13 dans le projet ; Project → Tools → « Import MarchingBlocks world... »
    → son `world.json`.
  - Attendu : un nœud MarchingBlocksWorld par couche, l'eau (MarchingBlocksWater), les transitions, le feuillage qui
    bouge, la texture animée ; un `Ctrl+Z` défait tout l'import.
  - Noté :
- [ ] **L'eau dans Godot**
  - Geste : peindre près de l'eau ; « Follow Cells ».
  - Attendu : la nappe se dit périmée ; « Follow Cells » montre l'eau des nouvelles cases.
  - Noté :
- [ ] **Ce qui manque, connu**
  - Geste : chercher F (cadrer toute la matière) et un outil pour planter.
  - Attendu connu : ni l'un ni l'autre dans Godot. Note si un acheteur le chercherait.
  - Noté :

---

## SÉANCE 17 — Le greffon Unity (60 min)

Début : ____ Fin : ____

Unity 6.6, un projet NEUF « 3D (Built-in) », puis un « Universal 3D » (URP). La Scene view n'a jamais reçu un vrai clic.

- [ ] ⚠ **Installer**
  - Geste : Package Manager → Unity Registry → glTFast ; puis **+** → « Add package from disk… » →
    `D:\MarchingBlocks\engines\unity\com.marchingblocks.paint\package.json`.
  - Attendu : aucune erreur rouge dans la Console.
  - Noté :
- [ ] ⚠ **« Paint the world » et un vrai clic dans la Scene view**
  - Geste : copier le `.mbset` dans `Assets\` ; un GameObject vide + MarchingBlocks World ; Tileset et Tiles ;
    « Paint the world » ; cliquer et glisser dans la Scene view ; `Ctrl+Z`.
  - Attendu : le bouton devient « Painting — click to stop » ; les cases se posent sous la souris ; un `Ctrl+Z` par coup
    (pas deux coups défaits ensemble — défaut déjà payé).
  - Noté :
- [ ] ⚠ **`Espace`, `Tab` et la molette arrivent-ils au greffon ?**
  - Geste : `Espace`, voler (clic droit + W A S D), `Espace` ; `Tab` ; `Maj` / `Alt` + molette.
  - Attendu : Espace bascule une seule fois même tenu ; `Alt` + molette sous Windows (jamais mesuré).
  - Noté :
- [ ] **Les outils de l'inspecteur**
  - Geste : Add, Dig (Maj = l'inverse, Ctrl retire de la sélection), Rect, Box, Facing, Widen, Shrink, « Select empty
    cells too », Room, Room from selection, Variant (`V`).
  - Attendu : comme dans l'appli ; les boutons sans icône (Facing, Widen) sont en texte.
  - Noté :
- [ ] ⚠ **« Tools > MarchingBlocks > Import World... »**
  - Geste : copier le `.mbworld` dans `Assets\`, le menu, son `world.json`.
  - Attendu : un objet par couche, l'eau, les transitions, les arbres qui bougent, l'animation ; un `Ctrl+Z`.
  - Noté :
- [ ] ⚠ **Le même monde en URP**
  - Geste : refaire l'import dans le projet URP ; regarder plusieurs fois la vue de jeu.
  - Attendu : les tuiles portent leurs matériaux (le PREMIER rendu d'une capture URP a déjà été faux : note si l'écran
    clignote ou montre une mauvaise plaque).
  - Noté :
- [ ] **Ce qui manque, connu**
  - Geste : chercher le pinceau de feuillage et la pose d'eau.
  - Attendu connu : absents dans Unity. HDRP non pris en charge.
  - Noté :

---

## SÉANCE 18 — Le greffon Unreal (60 min)

Début : ____ Fin : ____

Unreal 5.8.3 (`D:\UE_5.8`). Le mode n'a **jamais été ouvert ni cliqué** : il compile, c'est tout.

- [ ] ⚠ **Installer**
  - Geste : un projet NEUF à un chemin COURT (ex. `C:\mbt`, sinon la limite de 260 caractères) ; copier
    `D:\MarchingBlocks\engines\unreal\MarchingBlocksPaint` dans son `Plugins\` ; ouvrir.
  - Attendu : il compile au premier lancement, sans erreur.
  - Noté :
- [ ] ⚠ **Ouvrir le mode et peindre**
  - Geste : importer `tiles.glb` (Combine Meshes OFF) ; poser un acteur **MarchingBlocks World**, régler **Tileset**
    et **Tiles Folder** ; Modes → **MarchingBlocks** ; cliquer, glisser, `Ctrl+Z`.
  - Attendu : le panneau du mode (visée, outil, pinceau, étage, sélection) ; les cases sous la souris ; une transaction
    par coup.
  - Noté :
- [ ] ⚠ **`Espace`, `Tab`, la molette, F**
  - Geste : `Espace` (Navigate), `Tab`, `Alt` / `Maj` + molette, `F`.
  - Attendu : Espace ne fait plus tourner le gizmo ; le cran se dit dans le panneau (pas près de la souris) ; F cadre la
    matière des couches visibles.
  - Noté :
- [ ] **Les touches de l'outil**
  - Geste : `A` `D` `S` `G` `B` ⚠ dans Unreal, Rect est `G` (pas R).
  - Attendu : Add, Dig, Select, Rect, Box.
  - Noté :
- [ ] ⚠ **« MarchingBlocks World Import » → « Import World »**
  - Geste : un acteur MarchingBlocks World Import, **World File** = le `world.json`, « Import World » ; importer les
    `tiles.glb` que son Status nomme ; « Import World » à nouveau.
  - Attendu : un acteur par couche dans `MarchingBlocks/<monde>`, l'eau, les transitions, le feuillage qui bouge ; un
    `Ctrl+Z` ; relancer REMPLACE les couches.
  - Noté :
- [ ] ⚠ **Planter dans Unreal** (jamais tenu)
  - Geste : l'outil Plant : clic, `Ctrl` + clic (pinceau), `Maj` + clic (efface).
  - Attendu : des arbres posés sur le sol visible.
  - Noté :
- [ ] **L'eau dans Unreal**
  - Geste : les six presets sur l'acteur MarchingBlocks Water.
  - Attendu connu : « stylisé » montre un aplat sombre près de l'île, « réfléchissant » utilise les reflets d'Unreal.
    Note si c'est acceptable à la vente.
  - Noté :

---

## SÉANCE 19 — Désinstaller, réinstaller, cohabiter (30 min)

Début : ____ Fin : ____

- [ ] ⚠ **Désinstaller avec l'appli encore ouverte**
  - Geste : laisser MarchingBlocks ouvert ; Paramètres → Applications → MarchingBlocks → Désinstaller.
  - Attendu : l'installeur propose de fermer l'appli ; sinon l'exe reste jusqu'au redémarrage (vu une fois) — note ce
    qui se passe.
  - Noté :
- [ ] ⚠ **Ce que la désinstallation retire, et ce qu'elle laisse**
  - Geste : après désinstallation, regarder `%LOCALAPPDATA%\Programs\MarchingBlocks`, le menu Démarrer, le Bureau, un
    `.mbproj` dans l'Explorateur, `%APPDATA%\Godot\app_userdata\MarchingBlocks`, `Documents\MarchingBlocks`.
  - Attendu : plus d'exe, de raccourcis ni d'icônes de fichiers ; les réglages, la clé de licence et tes projets
    RESTENT. ⚠ Défaut déjà payé : la désinstallation avait emporté les icônes de l'appli de développement.
  - Noté :
- [ ] **Réinstaller : la clé est retenue**
  - Geste : réinstaller (case Bureau cochée cette fois), lancer.
  - Attendu : raccourci sur le Bureau ; le contrat redemandé seulement si sa version a changé ; la clé n'est pas redemandée.
  - Noté :
- [ ] **Site et Steam sur le même PC**
  - Geste : lancer l'exe Steam, puis désinstaller la version du site, puis double-cliquer un `.mbproj`.
  - Attendu connu : la désinstallation retire aussi les icônes que l'exe Steam avait posées ; Project → « File icons &
    double-click » les remet. Note si c'est gênant.
  - Noté :
- [ ] **Remettre tes réglages**
  - Geste : remettre `D:\MB_sauvegarde\app_userdata\` et `D:\MB_sauvegarde\test\` à leur place (ou renommer
    `…MarchingBlocks_mis_de_cote`).
  - Attendu : l'éditeur Godot et l'exemple retrouvés tels quels.
  - Noté :

---

## À JUGER À L'ŒIL

Aucun compteur ne tranche ce qui suit : la charte le laisse à ton œil (« pas jugé par Jordan »).

### Dans l'appli
- [ ] **Les six teintes du témoin** (vert / ocre, beige-brun / mauve, bleu / bleu profond) : se distinguent-elles en
  place, à l'ombre comme au soleil ? — Noté :
- [ ] **Le damier vert / orange des sols sous le pont** (la légende suit la tuile) et **la case ajoutée sur le tablier
  de l'arche** du témoin — Noté :
- [ ] **Les teintes des ateliers** : Project ambre, Geometry violet, Texturing rose, Play test vert (proposées), et
  Transitions citron, Animation orange, Foliage tilleul (proposées) ; World rouge et Fluids bleu (tes choix) — leur
  force. — Noté :
- [ ] **Le splash et l'icône** (repris dans Tripo, déclarés sur Steam) ; la signature SpannerGames en bas à droite, non
  rognée en plein écran. — Noté :
- [ ] **L'éclairage** : SSAO, ambiante, les métaux (une paroi métallique à l'ombre ne doit pas être noire) ; la bande
  de 8 px en bas de l'écran. — Noté :
- [ ] **L'eau, preset par preset** : le stylisé (lac à ras bord, traits blancs au large, écume au pied des cascades),
  Clear (réfraction, absorption), Reflective (gris dans World, ciel bleu-violet au Play test : jamais vu), Lava (taille
  des cellules), Swamp (opacité), Glowing acid ; le rivage contre la matière amincie ; les cascades sur une falaise
  SCULPTÉE (une falaise qui déborde de plus de 0,4 case percerait les bouts) et à un coin saillant (jamais regardé). — Noté :
- [ ] **Le voile sous l'eau, la lave, l'acide** (vu seulement en chiffres). — Noté :
- [ ] **Le liseré des cartes PBR déduites** sur les bosses douces ; **les bandes de couture** (largeur, rose). — Noté :
- [ ] **Les pointillés clairs aux joints des transitions** ; un représentant qui ne ressemble pas à sa couche (liseré
  en bout de bande). — Noté :
- [ ] **La planche des tuiles et le bandeau Shapes** : les photos se lisent-elles ? les phrases de rôle ? — Noté :
- [ ] **Le personnage** (yeux, contour violet), la météo (chaque temps), le disque solaire, l'ouragan sur une petite
  carte graphique. — Noté :
- [ ] **Les arbres qui se balancent** (force du vent, feuilles en découpe). — Noté :
- [ ] **Les 135 cases comblées dans l'exemple** (creux en damier réparés, jamais regardés). — Noté :
- [ ] **Le sol du réacteur de la station** (émission à 4 : trop vif ?). — Noté :
- [ ] **Unreal** : l'aplat sombre du preset stylisé, le reflet du preset réfléchissant. — Noté :

### Les vidéos — `D:\SpannerGames\PROJETS\MarchingBlocks\04_exports\`
Chaque vidéo existe en version avec musique et en version `_muet`. Rien n'est public avant le 21 décembre.
- [ ] **`trailer_final_60s.mp4`** et **`trailer_final_60s_wishlist.mp4`** (carton « WISHLIST ON STEAM ») : le rythme
  (plans de 1 à 2 s), la station dans un trailer d'île, le lac vidé dans les plans larges, la neige et la pluie, les
  arbres Tripo (à déclarer). — Noté :
- [ ] **`trailer_final_2min.mp4`** et sa version `_wishlist` : les mêmes points, plus le carton « COMING TO STEAM ·
  EARLY ACCESS ». — Noté :
- [ ] **`trailer_v1.mp4`** (le premier trailer, 41 s). — Noté :
- [ ] **`haut_v1.mp4`** (« Seen From Above »), **`scifi_v1.mp4`** (« Space Station »), **`timelapse_v1.mp4`** (« Built by
  hand », 2 min 22 : trop court ?), **`formes_v1.mp4`** (le balcon ne se voit pas, intérieurs sombres), **`ui_v1.mp4`**,
  **`cascades_v1.mp4`**, **`galeries_v1.mp4`**. — Noté :
- [ ] **Les devlogs du 6 octobre** : `feuillage_v1.mp4`, `transitions_v1.mp4`, `transitions_v2.mp4`,
  `animation_v1.mp4`, `bords_v1.mp4`, `coeur_v1.mp4` — titre, carton de fin, lisibilité. — Noté :
- [ ] **La boutique** (`D:\SpannerGames\PROJETS\MarchingBlocks\06_boutique\`) : `capsules\`, `captures\`, `presskit\`
  — chaque image regardée en vrai format. — Noté :

## À JUGER À L'OREILLE

Claude n'entend pas : les coupes ont été calées sur des courbes de volume, jamais écoutées.
- [ ] **« Fractured Skygate »** (`D:\SpannerGames\BIBLIOTHEQUE\musique\`) dans `trailer_final_60s` : l'arrêt net à 60 s
  tombe-t-il juste ? Dans `trailer_final_2min` : **le saut musical** (de 112 s à 50 s de la piste) s'entend-il ?
  **L'écho final** de 2,4 s ? — Noté :
- [ ] **« Fractured Skygate »** dans `trailer_v1`, `haut_v1`, `scifi_v1`, `ui_v1` : les coupes sur les temps forts. — Noté :
- [ ] **« Impossible underground zone »** dans `timelapse_v1` et les devlogs Foliage, Transitions, Animation, Bords : la
  fin de la piste et la fin de l'image tombent-elles ensemble ? — Noté :
- [ ] **Une boucle audible** : dans les vidéos plus longues que leur piste (`formes_v1`, 3 min 05), la musique repart
  vers 150 s — s'entend-il ? — Noté :
- [ ] **Le volume** : toutes sont à −14 LUFS ; une vidéo te paraît-elle plus forte ou plus faible qu'une autre ? — Noté :
