@tool
extends Node3D
class_name MassifPeint
## LA PARTIE PEINTURE — tu peins des CASES, le greffon pose les PIÈCES.
##
## **DÉCIDÉ (Jordan, 19 septembre 2026)** — trois grilles, et c'est la conséquence directe du modèle
## dual :
##
##   `Cases`  ce que TU peins. Une seule tuile dans sa palette : « de la matière ». C'est la VÉRITÉ,
##            et c'est l'éditeur GridMap natif de Godot qui la peint — rien de neuf à apprendre.
##   `Rendu`  ce que le greffon en DÉDUIT, décalé d'une demi-case. Tu n'y touches jamais.
##   `Fautes` les croisements que le LOT ne sait pas rendre, en cubes rouges bien visibles.
##
## ⚠ `Rendu` ET `Fautes` SONT JETABLES. Ils sont reconstruits entièrement à chaque changement ; rien ne
## s'y sauvegarde qui ne se redéduise. Une seule autorité sur la forme du monde : `Cases`.
##
## ── CE QUI A CHANGÉ EN PASSANT À MARCHING BLOCKS ────────────────────────────────────────────────────
##
## ⚠ **UNE CASE TOUCHE HUIT SOMMETS, PLUS QUATRE.** Le modèle 2D dual ne regardait que les quatre coins
## d'une case à son propre étage ; le vertical était porté à part par trois bandes. En modèle 3D, une
## cellule influe sur les HUIT pièces qui l'entourent. La moitié du voisinage manquait par construction.
##
## ⚠ **LE DÉCALAGE EST DE +0,5 SUR LES TROIS AXES, ET LE SIGNE A CHANGÉ AUSSI.** L'ancien code portait
## `(-0,5 ; 0 ; -0,5)` : le y à zéro parce que le modèle n'était dual qu'en plan, et le signe négatif
## parce que `Regles.CASES` lisait ses cases avec des décalages −1..0. `MB.COINS` les lit en 0..1, donc
## le sommet lu par `bits(p, v)` siège en `v + (1,1,1)`, une demi-case PLUS LOIN que le centre de la
## case `v`. **MESURÉ** (`DEV_TOOLS/sonde_gridmap_centrage.gd`) : `cell_center_x/y/z` valent tous trois
## `true`, une case occupe [0,1]³, et les huit cellules lues sont bien à une demi-case du sommet.
## Écrit de mémoire, ce décalage aurait déporté tout le rendu d'une case entière.
##
## ⚠ **LES CUBES ROUGES NE SIGNALENT PLUS UNE FAUTE DE PEINTURE.** Le classificateur ne refuse jamais :
## les 256 configurations ont une réponse. Il ne reste donc qu'un seul cas de faute — « le lot ne
## contient pas cette pièce » — et avec le repli procédural par défaut, ce cas ne peut plus se produire.
## **C'est l'invariant du greffon, rendu vrai : peindre une case n'importe où produit toujours un
## résultat déterminé, complet et correct.**

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const RP := preload("res://addons/marchingblocks_core/repli_procedural.gd")

## Le lot de pièces. ⚠ S'il reste vide, le REPLI PROCÉDURAL prend la main : on peut donc peindre le
## monde entier avant d'avoir sculpté quoi que ce soit, et remplacer les classes une à une ensuite.
@export var lot: MeshLibrary:
	set(valeur):
		lot = valeur
		if not reconstruire_au_lot:
			return
		# ⚠ UN LOT AUX MÊMES NOMS SOUS LES MÊMES NUMÉROS NE CHANGE AUCUNE DÉCISION (4 octobre 2026) : la règle ne lit que
		# l'index (`MB.pose_du_sommet`, `MB.tuile_du_sommet`), jamais la forme des tuiles. Un témoin retouché donne un
		# tel lot — ses tuiles changent de forme, pas de nom — et le monde qui le suit se reconstruisait EN ENTIER
		# (~3 s sur la couche de 196 091 cases de l'exemple). On ne change alors que le lot de la grille.
		var rendu := _rendu()
		if _pret and rendu != null and _lot_pose != null and _index_du_lot(lot_courant()) == _index:
			rendu.mesh_library = lot_de_la_grille()
			_lot_pose = rendu.mesh_library
			return
		reconstruire()

## La palette de ce qu'on peint : une seule tuile, « case ». `palette()` en fournit une par défaut.
@export var lot_des_cases: MeshLibrary:
	set(valeur):
		lot_des_cases = valeur
		var cases := _cases()
		if cases != null:
			cases.mesh_library = valeur

## LA COLLISION DES PIÈCES (9 octobre 2026). Vrai (le défaut) : la grille `Rendu` porte le lot tel quel, ses formes
## comprises — un jeu qui marche sur ses grilles. Faux : elle porte une COPIE SANS FORMES du lot (mêmes maillages,
## mêmes noms, mêmes numéros : `lot_de_la_grille`). L'appli met faux : elle ne marche jamais sur ses grilles (son décor
## de visite est à part, couche physique 2), et ces formes — une boîte par octant plein de chaque pièce, un corps par
## octant de GridMap — faisaient PLANTER le moteur physique de Godot (GodotPhysics3D) au premier pas physique d'un
## monde étendu : « FATAL: Index p_index = 4294967294 is out of bounds (count = 32771) ». MESURÉ (Resolve, la dalle
## d'un monde de 784 × 784 colonnes) : planté avec, ouvert sans.
@export var collision_des_pieces := true:
	set(valeur):
		if valeur == collision_des_pieces:
			return
		collision_des_pieces = valeur
		var rendu := _rendu()
		if _pret and rendu != null and rendu.mesh_library != null:
			rendu.mesh_library = lot_de_la_grille()
			_lot_pose = rendu.mesh_library

@export var taille_de_case := 1.0:
	set(valeur):
		taille_de_case = maxf(0.01, valeur)
		_caler()

## ⚠ Coupe la reconstruction automatique si elle gêne (une carte énorme, un profilage).
@export var suivre_en_temps_reel := true

## ⚠ FAUX : poser un `lot` ne reconstruit pas — l'appelant reconstruira lui-même (l'ouverture d'un projet pose le lot de
## chaque couche, puis refait l'union et reconstruit chaque couche UNE fois ; sinon chaque couche se reconstruisait deux
## fois, seule puis en couches — ~1,5 s de perdus sur l'exemple, 4 octobre 2026).
var reconstruire_au_lot := true

var _empreinte: int = -1
## LES COUCHES EXCLUSIVES (Jordan, 2 octobre 2026) — `union` : {case: rang de sa couche}, PARTAGÉE par l'écran entre
## toutes les couches et tenue à jour par lui ; `rang` : la place de celle-ci (0 = prioritaire). Le choix des tuiles
## lit l'union, et cette couche ne pose que les sommets dont elle est la propriétaire (`MB.couche_du_sommet`).
## ⚠ `rang` < 0 : la couche est SEULE — l'ancienne règle, mot pour mot (ses cases seules).
var union := {}
var rang := -1
## LE MONDE DU CŒUR (étape 3 b, Jordan, 6 octobre 2026 : « go pour brancher le monde dans l'appli ») — un `MBMonde`
## (`mbcore::World`) PARTAGÉ par les couches d'un écran (`MB.monde_natif()`), ou null. Branchée, une couche en couches
## (rang ≥ 0) ne décide plus ses sommets elle-même : elle s'INSCRIT au monde (ses grilles, `_etat`, `_compte`, tenus
## par référence), le monde suit l'union, et ses diffs posent ce qui change dans TOUTES les couches inscrites — le
## premier appel le fait, les suivants n'ont plus rien à poser. ⚠ Le GDScript reste la référence et le repli :
## `MB_NATIF=0`, une couche seule (rang < 0), un écran sans monde. `DEV_TOOLS/test_natif.gd` §11 compare les deux.
var monde = null
var _miennes := {}
## {Vector2i(x, z): combien de SES cases dans cette colonne} — tenu avec `_miennes` (`reconstruire`, `reconstruire_autour`).
var _colonnes_miennes := {}
## {y: combien de SES cases à cet étage} — tenu avec `_miennes` ; l'étiquette d'étage le lit (`cases_par_etage`).
var _etages_miens := {}
## LES VARIANTES VOULUES (Jordan, 4 octobre 2026) — `poids` : {clé: [base, var1, …]} (entiers, le tirage) ; `choix` :
## {sommet: rang de variante} (un choix posé dans World, 0 = la base). La règle : `MB.tuile_du_sommet`. Les changer
## demande `reconstruire()` (les poids) ou `reconstruire_sommets()` (des choix).
var poids := {}
var choix := {}
## Combien de reconstructions COMPLÈTES ont eu lieu : le contrôle qui dit que la route locale est bien prise.
var reconstructions_completes := 0
## Combien de sommets la dernière route LOCALE a refaits (le contrôle qui dit que le filtre des colonnes a servi).
var derniers_sommets_refaits := 0
var _dernier_bilan := {"pieces": 0, "fautes": 0, "muets": 0}


func _ready() -> void:
	preparer()
	reconstruire()


## Bâtit les trois grilles et les cale. ⚠ PUBLIQUE EXPRÈS : c'est le bouton du greffon qui doit
## l'appeler AVANT de poser le nœud dans la scène, pour pouvoir ensuite donner un `owner` à chaque
## grille. Un nœud sans propriétaire existe dans l'arbre mais **ne s'affiche pas dans le dock** — donc
## on ne peut pas le sélectionner, donc pas d'éditeur GridMap, donc rien à peindre.
func preparer() -> void:
	_batir_les_enfants()
	_caler()


## ⚠ ON SONDE, ON NE S'ABONNE PAS. Un `GridMap` n'émet aucun signal quand on y peint une case : il n'y
## a rien à écouter. On compare donc une empreinte des cases à chaque image de l'ÉDITEUR.
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or not suivre_en_temps_reel:
		return
	if _empreinte_des_cases() != _empreinte:
		reconstruire()


func _batir_les_enfants() -> void:
	for nom in ["Cases", "Rendu", "Fautes"]:
		if get_node_or_null(nom) == null:
			var grille := GridMap.new()
			grille.name = nom
			add_child(grille)
			if is_inside_tree() and get_tree() != null and get_tree().edited_scene_root != null:
				grille.owner = get_tree().edited_scene_root
	var cases := _cases()
	if cases != null and cases.mesh_library == null:
		cases.mesh_library = lot_des_cases if lot_des_cases != null else palette()
	var rendu := _rendu()
	if rendu != null and rendu.mesh_library == null:
		rendu.mesh_library = lot_de_la_grille()


## ⚠ LE DÉCALAGE EST ICI, ET NULLE PART AILLEURS. Une pièce est centrée sur un SOMMET du réseau, donc
## sur le coin commun à huit cellules : elle vit une demi-case plus loin **sur les trois axes**.
## Changer ce décalage, c'est casser l'alignement de tout le lot.
func _caler() -> void:
	for grille in [_cases(), _rendu(), _fautes()]:
		if grille != null:
			grille.cell_size = Vector3.ONE * taille_de_case
	var demi := Vector3.ONE * 0.5 * taille_de_case
	if _rendu() != null:
		_rendu().position = demi
	if _fautes() != null:
		_fautes().position = demi


## ⚠ LES ACCESSEURS BÂTISSENT CE QUI MANQUE, et ce n'est pas de la ceinture-bretelles. Compter sur
## `_ready()` pour créer les trois grilles a échoué au premier test hors éditeur : le nœud existait,
## ses enfants non, et tout ce qui suivait appelait des méthodes sur `null`. Un nœud dont l'état dépend
## du moment où on l'interroge est un nœud qui marchera « presque toujours ».
func _grille(nom: String) -> GridMap:
	var existante := get_node_or_null(nom) as GridMap
	if existante != null:
		return existante
	var grille := GridMap.new()
	grille.name = nom
	grille.cell_size = Vector3.ONE * taille_de_case
	add_child(grille)
	if is_inside_tree() and get_tree() != null and get_tree().edited_scene_root != null:
		grille.owner = get_tree().edited_scene_root
	return grille


func _cases() -> GridMap:
	return _grille("Cases")


func _rendu() -> GridMap:
	return _grille("Rendu")


func _fautes() -> GridMap:
	return _grille("Fautes")


## Le lot réellement employé : celui qu'on a donné, sinon le REPLI PROCÉDURAL.
## ⚠ C'est ce repli qui rend l'invariant vrai dès le premier jour : il contient les 68 classes de
## surface, donc aucune pièce ne peut manquer.
## ⚠ LE REPLI EST BÂTI UNE FOIS PAR PEINTRE, pas à chaque appel : `RP.librairie()` refait ses 68 maillages, et
## chaque reconstruction d'une couche sans lot les refaisait (et la route locale, qui compare le lot posé à
## celui-ci, ne se reconnaissait jamais).
func lot_courant() -> MeshLibrary:
	if lot != null:
		return lot
	if _repli == null:
		_repli = RP.librairie()
	return _repli


var _repli: MeshLibrary


## Le lot que porte la grille `Rendu` : `lot_courant()`, ou sa copie SANS FORMES de collision si
## `collision_des_pieces` est faux. La copie est gardée tant que le lot ne change pas (le même objet, le même nombre
## de pièces) : la grille garde le même lot d'un appel à l'autre, rien ne se reconstruit pour rien.
func lot_de_la_grille() -> MeshLibrary:
	var source := lot_courant()
	if collision_des_pieces or source == null:
		return source
	if _sans_formes_de != source or _sans_formes.get_item_list().size() != source.get_item_list().size():
		_sans_formes = source.duplicate()  # superficielle : les maillages sont partagés
		for id in _sans_formes.get_item_list():
			_sans_formes.set_item_shapes(id, [])
		_sans_formes_de = source
	return _sans_formes


var _sans_formes_de: MeshLibrary
var _sans_formes: MeshLibrary


## LA PALETTE DE CE QU'ON PEINT — deux tuiles, et deux seulement.
##
## ⚠ C'EST LA PLUS PETITE PALETTE POSSIBLE, ET C'EST VOULU. Le peintre ne choisit pas une forme : il dit
## « ici, de la matière ». Tout le reste — quelle classe, quelle orientation — est déduit. Une palette à
## soixante-huit entrées rendrait le greffon inutile.
##
##   « case »  ce qu'on peint, en translucide : on doit voir le RENDU au travers, sinon on peint à
##             l'aveugle par-dessus son propre travail ;
##   « faute » le cube rouge posé là où le lot ne sait rien rendre.
## ⚠ **CES DEUX TUILES SONT DE L'INTERFACE, PAS DE LA MATIÈRE — ET ELLES ÉTAIENT TRAITÉES COMME DE LA
## MATIÈRE** (Jordan, 24 septembre 2026). Trois défauts se cumulaient, et chacun rendait le repère plus
## sale que le rendu qu'il est censé laisser voir :
##
##   • **AUCUN `shading_mode`** : le cube recevait la lumière directionnelle et l'ambiante. Un repère se
##     retrouvait avec des faces claires et des faces sombres — un volume ÉCLAIRÉ, là où il faut un
##     aplat. Un relief qui ne veut rien dire, puisqu'il ne décrit aucune surface réelle.
##   • **`CULL_DISABLED`** : les faces ARRIÈRE se rendaient par-dessus les faces avant. Deux couches de
##     translucide se superposaient, doublant l'opacité perçue et brouillant les arêtes. C'est ce qui
##     « salissait » le plus.
##   • **alpha trop haut** : 0,28 sur ce qu'on peint, alors que cette tuile existe précisément pour
##     qu'on voie le RENDU au travers.
##
## ⚠ **ET LA FAUTE RESTE FRANCHE, elle.** Sobre — non éclairée, désaturée — mais nettement plus opaque
## que la case : c'est le seul signal qui dise qu'une classe manque au lot. L'effacer autant que le bleu
## la ferait disparaître au moment exact où elle compte.
static func palette() -> MeshLibrary:
	var librairie := MeshLibrary.new()
	var id := 0
	for entree in [
		["case", Color(0.62, 0.78, 0.98, 0.10)],
		["faute", Color(0.92, 0.36, 0.30, 0.42)],
	]:
		var boite := BoxMesh.new()
		boite.size = Vector3.ONE * 0.98  # ⚠ un chouia plus petit : deux cases voisines ne z-fightent pas
		var matiere := StandardMaterial3D.new()
		matiere.albedo_color = entree[1]
		matiere.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# ⚠ NON ÉCLAIRÉ : un repère d'interface n'a ni lumière ni ombre. Sa couleur est sa couleur.
		matiere.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# ⚠ ET LES FACES ARRIÈRE SONT ÉCARTÉES : sans ça on voit l'intérieur du cube à travers son
		# extérieur, et le translucide se compte deux fois.
		matiere.cull_mode = BaseMaterial3D.CULL_BACK
		# ⚠ Pas de reflet spéculaire ni de brillance : ce sont des propriétés de MATIÈRE, et une
		# surcouche d'interface n'en est pas.
		matiere.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, boite.surface_get_arrays(0))
		mesh.surface_set_material(0, matiere)
		librairie.create_item(id)
		librairie.set_item_name(id, entree[0])
		librairie.set_item_mesh(id, mesh)
		id += 1
	return librairie


# ── la déduction ────────────────────────────────────────────────────────────────────────────────────

## Reconstruit `Rendu` et `Fautes` depuis `Cases`. Rend {"pieces", "fautes", "muets"}.
##
## ⚠ `muets` compte les sommets que les règles laissent VOLONTAIREMENT vides : le ventre plein et le
## vide. Ce n'est pas une faute, c'est la règle du ventre creux — et c'est ce qui fait qu'un massif
## coûte sa SURFACE et non son volume. Le distinguer des fautes évite de lire une économie comme une
## panne.
func reconstruire() -> Dictionary:
	var cases := _cases()
	var rendu := _rendu()
	var fautes := _fautes()
	if cases == null or rendu == null or fautes == null:
		return _dernier_bilan
	# ⚠ BRANCHÉE AU MONDE, ses grilles et son état sont DÉJÀ tenus par les diffs : on ne les vide pas (`_au_monde_entier`).
	if not _au_monde():
		rendu.clear()
		fautes.clear()
	var courant := lot_de_la_grille()
	if rendu.mesh_library != courant:
		rendu.mesh_library = courant
	if fautes.mesh_library == null:
		fautes.mesh_library = lot_des_cases if lot_des_cases != null else palette()

	# LE CŒUR NATIF (`MB.natif()`, C++) fait les mêmes comptes et les mêmes décisions, s'il est là ; le GDScript
	# ci-dessous reste la référence et le repli (`DEV_TOOLS/test_natif.gd` compare les deux).
	var natif = MB.natif()
	var miennes := {}
	var pleines: Dictionary
	if natif != null:
		var comptes: Array = natif.compter_cases(cases.get_used_cells())
		miennes = comptes[0]
		pleines = union if rang >= 0 else miennes
		_miennes = miennes
		_colonnes_miennes = comptes[1]
		_etages_miens = comptes[2]
	else:
		for c in cases.get_used_cells():
			miennes[c] = true
		pleines = union if rang >= 0 else miennes
		_miennes = miennes
		_colonnes_miennes = {}
		_etages_miens = {}
		for c: Vector3i in miennes:
			var k2 := Vector2i(c.x, c.z)
			_colonnes_miennes[k2] = int(_colonnes_miennes.get(k2, 0)) + 1
			_etages_miens[c.y] = int(_etages_miens.get(c.y, 0)) + 1

	var id_faute: int = -1
	if fautes.mesh_library != null:
		id_faute = fautes.mesh_library.find_item_by_name("faute")
		if id_faute < 0 and fautes.mesh_library.get_item_list().size() > 0:
			id_faute = fautes.mesh_library.get_item_list()[0]

	# ⚠ **L'INDEX DU LOT SE BÂTIT UNE FOIS PAR RECONSTRUCTION, PAS PAR CASE.**
	# `find_item_by_name()` est un balayage linéaire du lot ; le chercher par case coûterait items × cases
	# à chaque touche de pinceau. Un passage sur le lot, puis un accès direct.
	var index: Dictionary = _index_du_lot(rendu.mesh_library)

	# ⚠ **LA RÈGLE N'EST PLUS ÉCRITE ICI** : elle vit dans `MB.poses()`, qui est aussi la référence des
	# cas d'épreuve du format neutre. Le peintre ne fait plus que POSER ce qu'elle décide — une seconde
	# description de la règle, ici, serait celle qui divergerait des greffons (charte §6).
	_pleines = pleines
	_index = index
	_variantes_par_cle = {}
	_id_faute = id_faute
	_lot_pose = rendu.mesh_library
	if _au_monde():
		return _au_monde_entier(rendu, fautes, id_faute, index)
	_etat.clear()
	_compte = {"pieces": 0, "fautes": 0, "dehors": 0, "touches": 0, "decisions": 0}
	if natif != null:
		var r: Dictionary = natif.reconstruire(pleines, miennes, rang, index, poids, choix, rendu, fautes, id_faute)
		_etat = r["etat"]
		_compte = {"pieces": r["pieces"], "fautes": r["fautes"], "dehors": r["dehors"], "touches": r["touches"],
			"decisions": r["decisions"]}
		_plafond = r["plafond"]
		_y_bas = r["y_bas"]
		_hauts = {}
		reconstructions_completes += 1
		_pret = true
		_empreinte = _empreinte_des_cases()
		return _bilan()
	_plafond = MB.plafond_de(pleines)
	# Les hauteurs des colonnes, le temps de cette reconstruction (`MB.sous_le_ciel`) ; vidées à la fin : la route locale
	# ne les tient pas à jour, elle remonte les colonnes.
	_hauts = MB.hauts_des_colonnes(pleines)
	_y_bas = 2147483647
	for c in pleines:
		_y_bas = mini(_y_bas, (c as Vector3i).y)
	if rang < 0:
		for d in MB.poses(pleines, index):
			if d["cle"] != "":
				d["tuile"] = MB.tuile_du_sommet(d["sommet"], d["cle"], index, poids, choix)
			_etat[d["sommet"]] = d
			_poser(d, 1)
		# Les sommets touchés sans surface (MUETS) : présents dans l'état, vides — c'est ce qui les compte.
		for c in pleines:
			for s in MB.sommets_de(c):
				if not _etat.has(s):
					_etat[s] = {}
	else:
		# EN COUCHES : les sommets de SES cases dont elle est la propriétaire ; les autres appartiennent à une couche
		# de plus petit rang, qui les pose.
		var vus := {}
		for c in miennes:
			for s in MB.sommets_de(c):
				if vus.has(s):
					continue
				vus[s] = true
				var d = _decision(s)
				if d == null:
					continue
				_etat[s] = d
				if not (d as Dictionary).is_empty():
					_poser(d, 1)
	_hauts = {}
	_compte["touches"] = _etat.size()
	reconstructions_completes += 1
	_pret = true

	_empreinte = _empreinte_des_cases()
	return _bilan()


## ── LA RECONSTRUCTION LOCALE — Jordan, 1er octobre 2026 : « une toute petite opération fait lagger » ─────────
## ⚠ MESURÉ (`DEV_TOOLS/sonde_lags_monde.gd`, avec fenêtre, 12 474 cases) : poser UNE case coûtait ~295 ms, dont
## **~278 ms de `reconstruire()`** — tout le monde recalculé et reposé pour une case — et ~18 ms d'enregistrement.
## Le pinceau l'appelait à CHAQUE mouvement de souris.
##
## Une case ne change que les sommets qui la LISENT (`MB.pose_du_sommet`) : ses huit cases sont dans les colonnes
## x..x+1, z..z+1 du sommet, à son étage et au suivant ; le ciel, dans les mêmes colonnes, au-dessus. Une case c
## ne touche donc que les sommets des colonnes x−1..x, z−1..z, d'étage ≤ c.y (la règle écrite dans le format
## neutre pour la reconstruction incrémentale, charte §4). On ne refait qu'eux, avec la même fonction.
## ⚠ `changees` : les cases dont l'état a pu changer, DÉJÀ posées dans `Cases`. Tout autre changement de la
## grille doit passer par `reconstruire()` — l'état gardé ne le verrait pas.
## ⚠ Quand il y a plus de sommets à refaire que l'état n'en compte (au moins `SEUIL_LOCAL`), ou si le lot a changé,
## c'est la reconstruction complète.
const SEUIL_LOCAL := 4096

var _pret := false
var _pleines := {}           # les cases au dernier passage
var _etat := {}              # sommet touché → sa décision ({} : muet)
var _index := {}
var _id_faute := -1
var _lot_pose: MeshLibrary
var _plafond := 0            # ≥ la plus haute case : une borne, jamais une valeur exacte (voir `pose_du_sommet`)
var _y_bas := 0              # ≤ la plus basse case, même raison
var _hauts := {}             # {Vector2i(x, z): plus haute case}, pendant une reconstruction entière seulement
var _variantes_par_cle := {} # {clé: combien de variantes le lot lui donne} — ne dépend que de `_index`
var _compte := {}


## LES CASES DE LA COUCHE, telles que l'état les tient ({case: true}), sans les relire (4 octobre 2026 : sur la
## couche de 491 000 cases de l'exemple, rebâtir ce dictionnaire coûtait ~150 ms à chaque case survolée par une forme
## spéciale, et à chaque opération de sélection). ⚠ À LIRE SEULEMENT : c'est l'état de la couche. Null quand il peut
## ne pas décrire la grille — couche cachée qui attend d'être refaite, ou un compte qui diffère (une case posée par
## une autre route ; jamais bâti : l'état est vide) : l'appelant relit alors la grille. ⚠ Exiger `_pret` en plus était
## une mutation ÉQUIVALENTE (mesurée) : le compte le dit déjà.
func cases_tenues() -> Variant:
	var cases := _cases()
	if cases == null or has_meta("_a_refaire") or has_meta("_tout_refaire"):
		return null
	if cases.get_used_cells().size() != _miennes.size():
		return null
	return _miennes


## {y: combien de cases à cet étage} — l'étiquette d'étage parcourait les 491 000 cases de l'exemple après chaque geste
## (~75 ms). Sans la garde de compte (~7 ms) : une étiquette, que la reconstruction suivante remet juste. Null si l'état
## n'est pas bâti ou attend d'être refait. À LIRE SEULEMENT.
func cases_par_etage() -> Variant:
	var tenus = comptes_tenus()
	return tenus[0] if tenus != null else null


## [{y: combien}, {Vector2i(x, z): combien}] tenus avec ses cases, SANS la garde de compte — null si l'état n'est pas
## bâti ou attend d'être refait. À LIRE SEULEMENT. L'écran en tire la boîte du monde pour l'eau, et vérifie le total.
func comptes_tenus() -> Variant:
	if not _pret or has_meta("_a_refaire") or has_meta("_tout_refaire"):
		return null
	return [_etages_miens, _colonnes_miennes]


## Combien de cases : l'état s'il est tenu (la liste des couches les recomptait après chaque geste), sinon la grille.
func nombre_de_cases() -> int:
	var cases := _cases()
	if cases == null:
		return 0
	if not _pret or has_meta("_a_refaire") or has_meta("_tout_refaire"):
		return cases.get_used_cells().size()
	return _miennes.size()


## `sur` : l'appelant GARANTIT que `changees` est tout ce qui a changé dans la grille depuis le dernier passage — la garde
## de compte (`get_used_cells`, ~7 ms par couche sur les 491 000 cases de l'exemple, payée par CHAQUE couche à CHAQUE
## touche d'un coup de pinceau : ~21 ms sur ~31) est alors sautée. Seul le coup de pinceau le passe (4 octobre 2026) ;
## l'action suivante refait la garde.
var gardes_de_compte := 0   # combien de fois la garde a relu la grille (pour les gardes des tests)


func reconstruire_autour(changees, sur := false) -> Dictionary:
	var cases := _cases()
	var rendu := _rendu()
	if not _pret or cases == null or rendu == null or rendu.mesh_library != lot_de_la_grille() \
			or rendu.mesh_library != _lot_pose:
		return reconstruire()
	# ⚠ UNE COUCHE BÂTIE AVANT D'AVOIR REÇU SON RANG (ou une autre union) lit encore ses seules cases : son état
	# gardé ne décrit pas le monde en couches. Vu en fumée — une couche neuve ne posait plus rien.
	if (rang >= 0) != is_same(_pleines, union):
		return reconstruire()
	# ⚠ EN COUCHES, `_pleines` EST L'UNION, tenue par l'écran : on n'y touche pas ; on tient SES cases à part. Un
	# changement d'une AUTRE couche passe aussi par ici (ses sommets de frontière peuvent changer de propriétaire).
	# Les colonnes où une de SES cases vient de partir : un sommet qui était à elle peut y changer.
	var parties := {}
	for c in changees:
		var p: Vector3i = c
		var k2 := Vector2i(p.x, p.z)
		if cases.get_cell_item(p) != GridMap.INVALID_CELL_ITEM:
			if not _miennes.has(p):
				_miennes[p] = true
				_colonnes_miennes[k2] = int(_colonnes_miennes.get(k2, 0)) + 1
				_etages_miens[p.y] = int(_etages_miens.get(p.y, 0)) + 1
			if rang < 0:
				_pleines[p] = true
		else:
			if _miennes.has(p):
				_miennes.erase(p)
				parties[k2] = true
				var n: int = int(_colonnes_miennes.get(k2, 0)) - 1
				if n > 0:
					_colonnes_miennes[k2] = n
				else:
					_colonnes_miennes.erase(k2)
				var e: int = int(_etages_miens.get(p.y, 0)) - 1
				if e > 0:
					_etages_miens[p.y] = e
				else:
					_etages_miens.erase(p.y)
			if rang < 0:
				_pleines.erase(p)
		if _pleines.has(p):
			_plafond = maxi(_plafond, p.y)
			_y_bas = mini(_y_bas, p.y)
	# ⚠ UNE GRILLE CHANGÉE PAR UNE AUTRE ROUTE (cases posées sans reconstruction) : l'état gardé ne la décrit
	# plus. Un compte suffit à le voir dans presque tous les cas, et coûte peu ; sinon, tout est refait.
	if not sur:
		gardes_de_compte += 1
		if cases.get_used_cells().size() != _miennes.size():
			return reconstruire()
	if _au_monde():
		return _suivre_au_monde(changees)
	# ⚠ CHAQUE COLONNE UNE FOIS (4 octobre 2026) : jusqu'à la plus haute case changée qui la touche. Énumérer la
	# colonne entière pour CHAQUE case insérait des millions de doublons quand une couche entière changeait (cacher les
	# 52 407 cases d'une couche de l'exemple : 3,6 s d'énumération seule, en local). Même ensemble de sommets.
	# ⚠ ET CHAQUE COLONNE CHANGÉE UNE FOIS AVANT DE L'ÉTENDRE AUX QUATRE (4 octobre 2026, la nuit) : quatre entrées par
	# case changée coûtaient ~100 ms par couche pour les 52 407 cases d'une couche cachée. Même maximum par colonne.
	var changees_xz := {}   # Vector2i(x, z) → plus haute case changée de cette colonne
	for c in changees:
		var p: Vector3i = c
		var kc := Vector2i(p.x, p.z)
		if p.y > int(changees_xz.get(kc, -2147483648)):
			changees_xz[kc] = p.y
	var colonnes := {}   # Vector2i(x, z) → plus haute case changée
	for kc: Vector2i in changees_xz:
		var y_c: int = changees_xz[kc]
		for sx in [kc.x - 1, kc.x]:
			for sz in [kc.y - 1, kc.y]:
				var k2 := Vector2i(sx, sz)
				colonnes[k2] = maxi(int(colonnes.get(k2, y_c)), y_c)
	# LA ROUTE LOCALE TANT QU'ELLE COÛTE MOINS QUE TOUT REFAIRE : le nombre de sommets à refaire contre ceux que la
	# reconstruction complète décide (l'état gardé). Un seuil fixe en CASES (4 096) envoyait cacher une couche de
	# l'exemple vers deux reconstructions complètes (7,3 s sur le PC).
	# ⚠ SEULEMENT LES COLONNES QUI LA REGARDENT (4 octobre 2026, le soir) : un sommet (x, y, z) ne lit que les cases
	# des colonnes x..x+1, z..z+1 ; il n'est à cette couche (avant comme après) que si l'une d'elles porte une de SES
	# cases — maintenant, ou partie dans ce geste. Cacher une couche de l'exemple refaisait 192 041 sommets dans
	# chacune des deux autres, quand l'une n'en possédait aucun et l'autre ~5 200 (~0,5 s par couche).
	var a_refaire := 0
	for k2: Vector2i in colonnes.keys():
		var regarde := false
		for dx in 2:
			for dz in 2:
				var k4 := Vector2i(k2.x + dx, k2.y + dz)
				if _colonnes_miennes.has(k4) or parties.has(k4):
					regarde = true
		if not regarde:
			colonnes.erase(k2)
			continue
		a_refaire += int(colonnes[k2]) - _y_bas + 2
	if a_refaire > maxi(_etat.size(), SEUIL_LOCAL):
		return reconstruire()
	derniers_sommets_refaits = a_refaire
	# Beaucoup de sommets (une couche entière cachée ou montrée) : les hauteurs des colonnes, bâties une fois, coûtent
	# moins que de remonter les colonnes à chaque sommet (`MB.sous_le_ciel`). L'union est déjà à jour ici.
	# ⚠ SEULEMENT LES COLONNES LUES (4 octobre 2026, la nuit) quand les balayer coûte moins que tout parcourir : un sommet
	# (x, z) lit les colonnes x..x+1, z..z+1 ; `_y_bas` et `_plafond` bornent toutes les cases de l'union.
	var natif = MB.natif()
	if natif != null:
		# Le cœur natif choisit lui-même entre lire le Dictionary et le recopier (avec ses hauts).
		var sommets: Array[Vector3i] = []
		for k2: Vector2i in colonnes:
			for y in range(_y_bas - 1, int(colonnes[k2]) + 1):
				sommets.append(Vector3i(k2.x, y, k2.y))
		natif.refaire(_pleines, sommets, _etat, rang, _index, poids, choix, _plafond, rendu, _fautes(), _id_faute,
			_compte)
		_empreinte = _empreinte_des_cases() if Engine.is_editor_hint() else _empreinte
		return _bilan()
	if a_refaire > 20000:
		var lues := {}
		for k2: Vector2i in colonnes:
			for dx in 2:
				for dz in 2:
					lues[Vector2i(k2.x + dx, k2.y + dz)] = true
		if lues.size() * (_plafond - _y_bas + 1) < _pleines.size():
			_hauts = MB.hauts_des_colonnes_de(_pleines, lues.keys(), _y_bas, _plafond)
		else:
			_hauts = MB.hauts_des_colonnes(_pleines)
	for k2: Vector2i in colonnes:
		for y in range(_y_bas - 1, int(colonnes[k2]) + 1):
			_refaire(Vector3i(k2.x, y, k2.y))
	_hauts = {}
	_empreinte = _empreinte_des_cases() if Engine.is_editor_hint() else _empreinte
	return _bilan()


## Refait la décision de quelques SOMMETS — un choix de variante posé ou retiré (4 octobre 2026). Les cases n'ont pas
## changé : seule la tuile tirée peut changer. Hors d'état (jamais reconstruit, lot changé), tout est refait.
func reconstruire_sommets(sommets) -> Dictionary:
	var rendu := _rendu()
	if not _pret or rendu == null or rendu.mesh_library != lot_de_la_grille() or rendu.mesh_library != _lot_pose:
		return reconstruire()
	if _au_monde():
		if monde.inscrire(self, rang, rendu, _fautes(), _id_faute, _etat, _compte):
			return reconstruire()
		monde.choisir_sommets(rang, Array(sommets), choix)
		monde.vider_attente()
		return _bilan()
	var natif = MB.natif()
	if natif != null:
		natif.refaire(_pleines, Array(sommets), _etat, rang, _index, poids, choix, _plafond, rendu, _fautes(),
			_id_faute, _compte)
		return _bilan()
	for k in sommets:
		_refaire(k)
	return _bilan()


func _au_monde() -> bool:
	return monde != null and rang >= 0


## LA RECONSTRUCTION COMPLÈTE, BRANCHÉE : le monde reprend les tuiles, les poids et les choix de la couche, et relit
## l'union entière ; ce qui change est posé dans toutes les couches inscrites. ⚠ La couche ne se REMPLIT d'un coup que si
## son rang vient de changer de propriétaire (les couches ont glissé, ou c'est sa première inscription) — sinon ses
## grilles et son état, tenus par les diffs, sont déjà justes : les refaire doublait l'ouverture (mesuré).
func _au_monde_entier(rendu: GridMap, fautes: GridMap, id_faute: int, index: Dictionary) -> Dictionary:
	if _compte.is_empty():
		_compte = {"pieces": 0, "fautes": 0, "dehors": 0, "touches": 0, "decisions": 0}
	var change: bool = monde.inscrire(self, rang, rendu, fautes, id_faute, _etat, _compte)
	monde.definir_couche(rang, index, poids, choix)
	monde.resynchroniser(union)
	if change:
		monde.vider_attente_sauf(rang)   # ce que ses grilles portent n'est pas à ce rang : elle se remplit d'un coup
		monde.remplir_couche(rang)
	else:
		monde.vider_attente()
	reconstructions_completes += 1
	_pret = true
	_empreinte = _empreinte_des_cases()
	return _bilan()


## LA ROUTE DU MONDE : le monde relit l'union pour ces cases (toute l'union si son compte diffère — une couche montrée
## dont les cases n'étaient pas dans `changees`), puis pose ce qui a changé dans toutes les couches inscrites. Un rang
## qui change de propriétaire (les couches ont glissé) : tout est refait.
func _suivre_au_monde(changees) -> Dictionary:
	if monde.inscrire(self, rang, _rendu(), _fautes(), _id_faute, _etat, _compte):
		return reconstruire()
	monde.suivre(union, Array(changees))
	if monde.nombre_de_cases(-1) != union.size():
		monde.resynchroniser(union)
	monde.vider_attente()
	_empreinte = _empreinte_des_cases() if Engine.is_editor_hint() else _empreinte
	return _bilan()


func _refaire(k: Vector3i) -> void:
	var avant = _etat.get(k, null)
	var apres = _decision(k)
	if avant == apres:
		return
	if avant != null:
		_compte["touches"] -= 1
		if not avant.is_empty():
			_poser(avant, -1)
	if apres == null:
		_etat.erase(k)
	else:
		_etat[k] = apres
		_compte["touches"] += 1
		if not apres.is_empty():
			_poser(apres, 1)


## La tuile POSÉE à un sommet (son nom dans le lot), "" s'il n'y en a pas — ce que l'outil Variant de World lit.
func tuile_posee(s: Vector3i) -> String:
	var d: Dictionary = _etat.get(s, {}) if _etat.get(s, null) != null else {}
	return str(d.get("tuile", d.get("cle", "")))


## La clé posée à un sommet ("" s'il n'y en a pas).
func cle_posee(s: Vector3i) -> String:
	var d: Dictionary = _etat.get(s, {}) if _etat.get(s, null) != null else {}
	return str(d.get("cle", ""))


## La décision d'un sommet pour CETTE couche : null s'il n'est pas à elle (aucune case, ou, en couches, une couche
## prioritaire le pose) ; {} s'il est à elle sans surface ; sinon sa pose. ⚠ UNE RÈGLE : `MB.pose_du_sommet`.
func _decision(s: Vector3i) -> Variant:
	if rang >= 0:
		if MB.couche_du_sommet(_pleines, s) != rang:
			return null
	elif MB.bits(_pleines, s) == 0:
		return null
	var d: Dictionary = MB.pose_du_sommet(_pleines, s, _index, _plafond, _hauts)
	if not d.is_empty() and d["cle"] != "":
		var n: int = _variantes_par_cle.get(d["cle"], -1)
		if n < 0:
			n = MB.nombre_de_variantes(d["cle"], _index)
			_variantes_par_cle[d["cle"]] = n
		d["tuile"] = MB.tuile_du_sommet(s, d["cle"], _index, poids, choix, n)
	return d


## Pose (sens = 1) ou retire (sens = −1) une décision dans les grilles, et tient les comptes.
func _poser(d: Dictionary, sens: int) -> void:
	var sommet: Vector3i = d["sommet"]
	_compte["decisions"] += sens
	if d["cle"] == "":
		# ⚠ UNE PIÈCE QUE LES RÈGLES DEMANDENT ET QUE LE LOT N'A PAS : c'est une FAUTE DE LOT, jamais
		# une faute de peinture.
		_compte["fautes"] += sens
		if _id_faute >= 0:
			_fautes().set_cell_item(sommet, _id_faute if sens > 0 else GridMap.INVALID_CELL_ITEM)
		return
	_compte["pieces"] += sens
	if d["dehors"]:
		_compte["dehors"] += sens
	if sens > 0:
		_rendu().set_cell_item(sommet, _index[d.get("tuile", d["cle"])], d["orientation"])
	else:
		_rendu().set_cell_item(sommet, GridMap.INVALID_CELL_ITEM)


## ⚠ `dehors` COMPTE LES VARIANTES RÉELLEMENT POSÉES, pas les sommets à l'air libre. Sur un lot sans
## variantes il vaut 0 alors que le monde est plein de ciel — et c'est exactement ce qu'il doit dire :
## « ce lot n'a rien de spécifique au dehors ». Compter les sommets ferait croire l'inverse.
func _bilan() -> Dictionary:
	_dernier_bilan = {"pieces": _compte["pieces"], "fautes": _compte["fautes"],
		"muets": _compte["touches"] - _compte["decisions"], "dehors": _compte["dehors"]}
	return _dernier_bilan


## Le bilan de la dernière reconstruction, SANS en déclencher une.
## ⚠ `reconstruire()` rend déjà ce bilan, mais l'éditeur l'appelle par `add_do_method()`, qui jette
## la valeur de retour. Un accesseur vaut mieux que reconstruire une seconde fois pour lire un compte.
func dernier_bilan() -> Dictionary:
	return _dernier_bilan


## L'INDEX D'UN LOT — {nom de tuile: id}. Une clé, une tuile, de nom nu (charte §3, 30 septembre 2026).
## ⚠ Un item nommé « …~k » (un lot d'avant, qui portait des exemplaires) n'est pas une clé : il n'est jamais
## posé. Le cache se retranche de toute façon (`Projet.FORMAT_DU_CACHE`).
static func _index_du_lot(lot: MeshLibrary) -> Dictionary:
	var index := {}
	if lot == null:
		return index
	for id in lot.get_item_list():
		index[lot.get_item_name(id)] = id
	return index


## ⚠ UNE EMPREINTE, PAS UNE COPIE. Comparer deux listes de milliers de cases à chaque image coûterait
## cher ; un compte et une somme mêlée suffisent à repérer un changement, et se calculent d'un passage.
func _empreinte_des_cases() -> int:
	var cases := _cases()
	if cases == null:
		return 0
	var natif = MB.natif()
	if natif != null:
		return natif.empreinte_des_cases(cases.get_used_cells())
	var empreinte := 0
	var n := 0
	for c in cases.get_used_cells():
		var p: Vector3i = c
		empreinte = (empreinte * 31 + p.x * 73856093 + p.y * 19349663 + p.z * 83492791) & 0x7FFFFFFF
		n += 1
	return empreinte * 31 + n


func _get_configuration_warnings() -> PackedStringArray:
	var avertissements: PackedStringArray = []
	if lot == null:
		avertissements.append("Aucun lot sculpté : le repli procédural prend la main (68 pièces, "
			+ "aucune ne peut manquer). Tu peux peindre tout de suite.")
	if _dernier_bilan["fautes"] > 0:
		avertissements.append("%d croisement(s) que le lot ne sait pas rendre — les cubes rouges les "
			% _dernier_bilan["fautes"] + "montrent. Avec le repli par défaut, ce cas ne devrait pas exister.")
	return avertissements
