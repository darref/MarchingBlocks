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
		reconstruire()

## La palette de ce qu'on peint : une seule tuile, « case ». `palette()` en fournit une par défaut.
@export var lot_des_cases: MeshLibrary:
	set(valeur):
		lot_des_cases = valeur
		var cases := _cases()
		if cases != null:
			cases.mesh_library = valeur

@export var taille_de_case := 1.0:
	set(valeur):
		taille_de_case = maxf(0.01, valeur)
		_caler()

## ⚠ Coupe la reconstruction automatique si elle gêne (une carte énorme, un profilage).
@export var suivre_en_temps_reel := true

var _empreinte: int = -1
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
		rendu.mesh_library = lot_courant()


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
func lot_courant() -> MeshLibrary:
	return lot if lot != null else RP.librairie()


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
	rendu.clear()
	fautes.clear()
	var courant := lot_courant()
	if rendu.mesh_library != courant:
		rendu.mesh_library = courant
	if fautes.mesh_library == null:
		fautes.mesh_library = lot_des_cases if lot_des_cases != null else palette()

	var pleines := {}
	for c in cases.get_used_cells():
		pleines[c] = true

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
	var poses := 0
	var manquantes := 0
	var dehors_poses := 0
	var decisions: Array = MB.poses(pleines, index)
	for d in decisions:
		var sommet: Vector3i = d["sommet"]
		if d["cle"] == "":
			# ⚠ UNE PIÈCE QUE LES RÈGLES DEMANDENT ET QUE LE LOT N'A PAS : c'est une FAUTE DE LOT, jamais
			# une faute de peinture.
			manquantes += 1
			if id_faute >= 0:
				fautes.set_cell_item(sommet, id_faute)
			continue
		var id: int = index[d["cle"]]
		if d["dehors"]:
			dehors_poses += 1
		rendu.set_cell_item(sommet, id, d["orientation"])
		poses += 1
	var muets: int = _sommets_touches(pleines) - decisions.size()

	_empreinte = _empreinte_des_cases()
	# ⚠ `dehors` COMPTE LES VARIANTES RÉELLEMENT POSÉES, pas les sommets à l'air libre. Sur un lot sans
	# variantes il vaut 0 alors que le monde est plein de ciel — et c'est exactement ce qu'il doit dire :
	# « ce lot n'a rien de spécifique au dehors ». Compter les sommets ferait croire l'inverse.
	_dernier_bilan = {"pieces": poses, "fautes": manquantes, "muets": muets, "dehors": dehors_poses}
	return _dernier_bilan


## Combien de sommets les cases touchent — pour compter les MUETS (sommets sans surface), que `MB.poses`
## ne rend pas.
static func _sommets_touches(pleines: Dictionary) -> int:
	var sommets := {}
	for c in pleines:
		for s in MB.sommets_de(c):
			sommets[s] = true
	return sommets.size()


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
