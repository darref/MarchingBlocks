extends "res://DEV_TOOLS/filmer_haut.gd"
##
## DEVLOG — L'ATELIER FOLIAGE. Demandé par Jordan (6 octobre 2026) : « fait un dev log pour chaque nouveauté, pour le
## foliage utilises les arbres glb qui sont dans D:\Spirit\HEART_WORLD\biomes\maps ».
##
## ⚠ CE QUE LE LOGICIEL IMPOSE (relevé le 6 octobre 2026, `atelier_feuillage.gd`, `feuillage.gd`, `feuillage_vue.gd`) :
##   - un modèle s'importe en `.glb` et se COPIE dans le projet (`<projet>_foliage/`) : les arbres de Spirit3D ne sont que
##     LUS. « Import .glb… » ouvre le dialogue NATIF de Windows, que le Movie Maker ne filme pas (et qu'un script ne peut
##     pas mener) : la souris va sur le bouton, la carte dit le fichier, et le script prend la route du dialogue
##     (`_fichier_choisi`, comme la fumée) ;
##   - les arbres de Tripo font tous ~1 unité de haut, leur base à 0 : l'import les pose sur leur base, l'ÉCHELLE les fait
##     arbres (5 à 7 cases) ; l'empreinte par défaut suit (0,35 × la plus grande largeur) ;
##   - trois modes : « In the air » (le plan de la grille, PgUp / PgDn), « Planted · free » (refusé sur une pente > 40°,
##     dans l'eau, au bord, sous un surplomb, sur l'empreinte d'un voisin), « Planted · overflow » (la pente et l'eau
##     seules) ; « Spacing » vaut dans tous les modes. Le fantôme est vert (accepté) ou rouge (refusé) ;
##   - le pinceau pose un coup tous les 0,4 rayon parcourus ; le clic droit enlève (le plus proche, ou le disque du
##     pinceau) ; un coup = une annulation ;
##   - le feuillage n'a pas de collision au Play test (on traverse les troncs) et n'est ni dans le `.mbworld` ni dans les
##     greffons : le film ne le suggère pas, et le stickman passe par un SENTIER dégagé au clic droit ;
##   - le beau rendu n'existe qu'au Play test (soleil doré, glow : le réglage du devlog du paysage) ;
##   - une matière ne change que là où la hauteur change (devlog vu de haut) : `_sans_damier`, `_un_niveau_une_matiere`.
##
## LANCEMENT — dans la COPIE de tournage `D:/SpannerGames/ATELIER/MarchingBlocks/worktrees/MB_tournage_feuillage` (1920 × 1080, `use_custom_user_dir`) :
##   cp D:/MarchingBlocks/DEV_TOOLS/filmer_*.gd D:/SpannerGames/ATELIER/MarchingBlocks/worktrees/MB_tournage_feuillage/DEV_TOOLS/
##   Godot_v4.7-stable_win64_console.exe --path D:/SpannerGames/ATELIER/MarchingBlocks/worktrees/MB_tournage_feuillage --fixed-fps 30 \
##       --write-movie D:/SpannerGames/PROJETS/MarchingBlocks/02_rushes/feuillage.avi --script res://DEV_TOOLS/filmer_feuillage.gd
##   `-- --seulement=carte` : la carte du relief en PNG (juger le monde avant de filmer).

const FE := preload("res://addons/marchingblocks_core/feuillage.gd")
const FeuillageVue_ := preload("res://app/feuillage_vue.gd")
const SPIRIT := "D:/Spirit/HEART_WORLD/biomes/maps/"
const CARTE_F := "C:/Users/jorda/AppData/Local/Temp/claude/D--SpannerGames/d195078d-feff-463c-9e41-f90d432ceefa/scratchpad/carte_feuillage.png"

## LE MONDE — une règle, un endroit. x vers l'est, z vers le sud. Les bornes sont celles de filmer_haut (X0..X1, Z0..Z1).
const MER_F := 4                   # l'eau de la mer occupe les cases y = 4 ; la plage (dessus à 5) est au sec
const FOND_F := -2                 # le bas des colonnes
const COTE_F := 25.0               # la côte, à peu près en z = 25 ; la plage est large de 6
const DESERT_C := Vector2(42, 12)  # le désert : un disque bruité au sud-est, jusqu'à la plage
const DESERT_R := 24.0
const PIED_COLLINES := -4.0        # les collines montent au nord de z = -4
## Le sentier du Play test, sur la plaine (plate, à 6) : d'ouest en est, à travers les bouleaux et le bosquet.
const SENTIER_DE := Vector2(-44.5, 12.5)
const SENTIER_A := Vector2(-8.5, 6.5)
## Les mesas du désert : [centre, rayons, dessus].
const MESAS := [[Vector2(38, 4), Vector2(6, 4), 9], [Vector2(38, 4), Vector2(3, 2), 11], [Vector2(48, 14), Vector2(4, 5), 8],
	[Vector2(27, 15), Vector2(3, 2), 7]]
## Les buttes de la plaine : [centre, rayons, montée].
const BUTTES := [[Vector2(-34, 8), Vector2(6, 4), 1], [Vector2(-6, 12), Vector2(5, 3), 1], [Vector2(-22, -1), Vector2(4, 3), 1]]

## LES ARBRES — [fichier sous maps/, échelle, taille au hasard, vent]. Tous générés par Tripo (IA), lus dans Spirit3D.
const ARBRES := {
	"chene": ["biome_plains/obstacles/plains_tree_01/plains_tree_01.glb", 5.0, 0.3, 0.8],
	"bouleau": ["biome_plains/obstacles/plains_tree_04/plains_tree_04.glb", 6.5, 0.25, 0.8],
	"pin": ["biome_woodland/obstacles/woodland_tree_02/woodland_tree_02.glb", 7.0, 0.3, 0.6],
	"parasol": ["biome_woodland/obstacles/woodland_tree_03/woodland_tree_03.glb", 6.5, 0.25, 0.6],
	"sapin": ["biome_woodland/obstacles/woodland_tree_08/woodland_tree_08.glb", 7.5, 0.3, 0.6],
	"palmier": ["biome_desert/resources/obstacles/palm+tree+3d+model_Clone1.glb", 6.5, 0.25, 0.9],
	"saguaro": ["biome_desert/obstacles/desert_cactus_08/desert_cactus_08.glb", 3.0, 0.3, 0.1],
	"cierge": ["biome_desert/obstacles/desert_cactus_10/desert_cactus_10.glb", 4.0, 0.3, 0.1],
}

var _fbm_f := FastNoiseLite.new()
var _af: RefCounted                # l'atelier Foliage de l'écran
var _modele_de := {}               # clé d'ARBRES → indice du modèle dans l'atelier
var _sentier: Array = []           # le sentier du stickman (points au sol), dégagé au clic droit
var _temps_images: Array = []      # la durée de chaque image du Play test (le coût des arbres)
var _prims_maxi := 0
var _photos := 0
const PHOTOS := "C:/Users/jorda/AppData/Local/Temp/claude/D--SpannerGames/d195078d-feff-463c-9e41-f90d432ceefa/scratchpad/photos"
var _appels_maxi := 0


func _derouler() -> void:
	if _seulement == "carte":
		_terrain_f()
		var im := Image.create((X1 - X0 + 1) * 4, (Z1 - Z0 + 1) * 4, false, Image.FORMAT_RGB8)
		var teinte := {"herbe": Color("#3fa34d"), "sable": Color("#d8c27a"), "roche": Color("#7a7a7a")}
		for k in _h:
			var c: Color = (teinte[_m[k]] as Color).darkened(clampf(0.45 - 0.04 * (_h[k] - 4), 0.0, 0.7))
			if _h[k] < MER_F:
				c = Color("#2d6fa8").darkened(0.1 * (MER_F - _h[k]))
			im.fill_rect(Rect2i((k.x - X0) * 4, (k.y - Z0) * 4, 4, 4), c)
		im.save_png(CARTE_F)
		print("carte -> %s" % CARTE_F)
		_rendre_les_reglages()
		quit(0)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--photos="):
			_photos = int(a.substr(9))
			DirAccess.make_dir_recursive_absolute(PHOTOS)
	await _images(30)
	await _ecran._ouvrir(_chemin)
	_ecran._changer_d_atelier("monde")
	_ecran._legende_formes.basculer(false, false)
	_vue = _ecran._vue
	_af = _ecran._feuillage
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	_aides()
	for partie in ["terre", "mer", "import", "modes", "pinceau", "monde", "jeu"]:
		if _seulement != "" and _seulement != partie and not partie in ["terre", "mer", "import"]:
			continue
		_plan(partie)
		await Callable(self, "_f_" + partie).call()
		await _images(int(0.5 * FPS))
	_plan("fin")
	_rapport_du_cout()
	_rendre_les_reglages()
	quit(0)


# ── 1. LE MONDE : trois couches, puis la mer ─────────────────────────────────────────────────────────

func _f_terre() -> void:
	for nom in _couche:
		_ecran._activer(_couche[nom])
		var occ: Dictionary = _ecran._occupees()
		if not occ.is_empty():
			_ecran._appliquer({"poser": {}, "effacer": occ}, "Dig")
	while not _ecran._eaux.is_empty():
		_ecran._retirer_eau(_ecran._eaux[0])
	_terrain_f()
	var par := {"roche": {}, "herbe": {}, "sable": {}}
	for k in _h:
		for y in range(FOND_F, int(_h[k]) + 1):
			par[_m[k]][Vector3i(k.x, y, k.y)] = true
	print("monde : roche %d, herbe %d, sable %d" % [par["roche"].size(), par["herbe"].size(), par["sable"].size()])
	_regarder(Vector3(-20, 62, 78), Vector3(0, 4, -4))
	await _images(10)
	for etape in [["GreyRock", "roche", "Layer GreyRock", "Rock under everything, cliffs, mesas"],
			["Grass", "herbe", "Layer Grass", "Rolling hills, a plain"],
			["Desert", "sable", "Layer Desert", "A beach, a desert"]]:
		_ecran._activer(_couche[etape[0]])
		_montrer(etape[2], etape[3])
		_ecran._appliquer({"poser": par[etape[1]], "effacer": {}}, "Add")
		await _derive_f(1.4)
	_ecran._activer(_couche["GreyRock"])
	await _ecran._reparer_les_diagonales(false)
	_ecran._activer(_couche["Grass"])
	await _derive_f(0.6)


func _derive_f(duree: float) -> void:
	for i in int(duree * FPS):
		_vue._azimut += 0.0012
		_vue._caler()
		await _images(1)


## La mer, comme dans le devlog du paysage : l'étage de l'eau (PgUp / PgDn), un clic dans le vide, un second pour la poser.
func _f_mer() -> void:
	await _cliquer_bouton("Fluids", "Fluids workshop")
	await _images(10)
	await _etage_a(MER_F, "Water height: y = %d" % MER_F)
	var vide := Vector3(-10, MER_F, Z1 + 28.0)
	_regarder(vide + Vector3(30, 46, 40), vide)
	await _images(10)
	_dans_l_image(vide, "la mer")
	await _bouger(_sur(vide), 0.8)
	await _clic(MOUSE_BUTTON_LEFT, "Click the void", "The sea: pick its height")
	await _clic(MOUSE_BUTTON_LEFT, "Click again", "Place the sea")
	await _ecran._recalculer_eau(false)
	print("eaux : %d" % _ecran._eaux.size())
	await _touche(KEY_ESCAPE, "Esc", "Back to World")
	await _bouger(Vector2(root.size.x - 3, root.size.y - 3), 0.3)


## L'étage de la grille par PgUp / PgDn (la mer, le plan de « In the air »).
func _etage_a(y: int, detail: String) -> void:
	var avant := int(_ecran._compteur_etage.value)
	if avant == y:
		return
	_montrer("PgUp / PgDn", detail)
	for i in absi(y - avant):
		var k := KEY_PAGEUP if y > avant else KEY_PAGEDOWN
		_cle(k, true)
		_cle(k, false)
		await _images(2)
	print("étage : %d" % int(_ecran._compteur_etage.value))


# ── 2. L'ATELIER, L'IMPORT, LE SOCLE ────────────────────────────────────────────────────────────────

## Le coin de la plaine qui touche la plage (une marche d'une case : le bord), la mer devant.
var _x_demo := -14
var _z_plage := 18     # la première rangée de plage en x = _x_demo (calculée)


func _f_import() -> void:
	_z_plage = Z0
	for z in range(Z0, Z1 + 1):
		var k := Vector2i(_x_demo, z)
		if _m.get(k, "") == "sable" and int(_h.get(k, 0)) == 5:
			_z_plage = z
			break
	print("plage en x = %d : z = %d" % [_x_demo, _z_plage])
	# De la mer, en biais : la mer devant, la plage, la marche de la plaine, la plaine, les collines au fond.
	_regarder(Vector3(_x_demo + 13.0, 13.5, _z_plage + 10.0), Vector3(_x_demo - 3.0, 6.0, _z_plage - 3.0))
	await _images(10)
	await _cliquer_bouton("Foliage", "The Foliage workshop: the world, and only trees")
	await _images(int(0.8 * FPS))
	await _importer("chene", true)


## Un `.glb` de Spirit3D : la souris sur « Import .glb… », la carte dit le fichier, puis la route du dialogue (le dialogue
## natif ne se filme pas). Puis son échelle et son vent, aux curseurs ; `complet` : tout le socle, pas à pas.
func _importer(cle: String, complet: bool) -> void:
	var a: Array = ARBRES[cle]
	var fichier: String = SPIRIT + a[0]
	var b := _bouton(_ecran, "Import .glb…")
	if b == null:
		print("⚠ pas de bouton Import")
		return
	await _dans_le_panneau(b)
	await _bouger(b.get_global_rect().get_center(), 0.5 if complet else 0.35)
	# ⚠ PAS DE VRAI CLIC : il ouvrirait le dialogue NATIF de Windows, hors du film, et qu'aucun script ne ferme.
	_montrer("Import .glb…", "%s · a Tripo AI model" % fichier.get_file())
	await _images(int((0.9 if complet else 0.5) * FPS))
	var n_avant: int = _af.modeles.size()
	_ecran._action_fichier = "feuillage"
	_ecran._fichier_choisi(fichier)
	if _af.modeles.size() != n_avant + 1:
		print("⚠ import refusé : %s (%s)" % [fichier, _ecran._rapport.text])
		return
	_modele_de[cle] = _af.actif
	var m: Dictionary = _af.modele_actif()
	print("importé %s : %s, haut %.2f, empreinte %.2f, décalage %.3f" % [cle, m["chemin"], m["hauteur"], m["rayon"],
		m["decalage"]])
	await _images(int((1.2 if complet else 0.5) * FPS))
	if complet:
		await _glisser_curseur("decalage", -0.12, "Ground offset", "Sink the roots under the ground")
		await _images(int(0.6 * FPS))
		var assis := _bouton(_ecran, "Sit its base on the ground")
		if assis != null:
			await _dans_le_panneau(assis)
			await _bouger(assis.get_global_rect().get_center(), 0.5)
			await _clic(MOUSE_BUTTON_LEFT, "Click", "Sit its base on the ground")
	await _glisser_curseur("echelle", a[1], "Scale", "%s cells tall" % str(snappedf(float(m["hauteur"]) * a[1], 0.5)),
		0.9 if complet else 0.5)
	if complet:
		await _glisser_curseur("echelle_alea", a[2], "Random size", "Each plant a little different")
	else:
		_af.curseurs["echelle_alea"].value = a[2]
	await _glisser_curseur("vent", a[3], "Wind", "How much it sways", 0.7 if complet else 0.4)
	print("réglé %s : échelle %.2f, au hasard %.2f, vent %.2f, empreinte %.2f" % [cle, m["echelle"], m["echelle_alea"],
		m["vent"], float(m["rayon"]) * float(m["echelle"])])


# ── 3. LES TROIS MODES, AU CLIC ─────────────────────────────────────────────────────────────────────

func _f_modes() -> void:
	var x := _x_demo + 0.5
	var zb := float(_z_plage)
	# Le premier : au milieu de la plaine, le fantôme vert, un clic.
	await _mode("sol_libre", "Planted · free: on the ground, with room around it")
	var p1 = _point_ou("", Vector3(x - 4.0, 7, zb - 4.0), 2.0)
	if p1 != null:
		await _bouger(p1, 1.0)
		await _images(int(0.6 * FPS))
		await _clic(MOUSE_BUTTON_LEFT, "Click", "Green: it may grow here")
	var p2 = _point_ou("", Vector3(x + 1.0, 7, zb - 7.0), 2.0)
	if p2 != null:
		await _bouger(p2, 0.7)
		await _images(int(0.3 * FPS))
		await _clic(MOUSE_BUTTON_LEFT, "Click", "Another one")
	print("plants : %d" % _af.plants.size())
	var arbre1: Vector3 = _af.plants[0]["p"] if not _af.plants.is_empty() else Vector3(x - 3.5, 7, zb - 5.0)
	# Les refus : trop près d'un voisin, au bord de la marche, dans l'eau, sur une pente.
	var refus := [["trop_pres", arbre1 + Vector3(1.6, 0, 0.4), 1.2, "Red: too close to another tree"],
		["au_bord", Vector3(x, 6, zb - 0.6), 2.5, "Red: its footprint hangs over the edge"],
		["dans_l_eau", Vector3(x + 3.0, 4, zb + 8.0), 3.0, "Red: in the water"],
		["trop_pentu", Vector3(x, 6, zb - 0.5), 4.0, "Red: the ground is too steep"]]
	for r in refus:
		var q = _point_ou(r[0], r[1], r[2])
		if q == null:
			print("⚠ aucun point « %s » près de %s" % [r[0], r[1]])
			continue
		await _bouger(q, 0.8)
		await _images(int(0.5 * FPS))
		await _clic(MOUSE_BUTTON_LEFT, "Click", r[3])
		print("refus %s : « %s »" % [r[0], _ecran._rapport.text])
		await _images(int(0.4 * FPS))
	# Débordement : au même bord, il plante.
	await _mode("sol_debord", "Planted · overflow: edges, walls, neighbours")
	var q2 = _point_ou("", Vector3(x + 1.5, 6, zb - 0.6), 2.5)
	if q2 != null:
		await _bouger(q2, 0.7)
		await _images(int(0.5 * FPS))
		await _clic(MOUSE_BUTTON_LEFT, "Click", "It may overflow the edge")
	print("plants : %d" % _af.plants.size())
	# Dans le vide : sur le plan de la grille, au-dessus de la mer.
	await _mode("air", "In the air: on the grid plane, even over nothing")
	var y_air := 10
	await _etage_a(y_air, "The grid plane: y = %d" % y_air)
	var vide := Vector3(x - 3.0, y_air, zb + 3.0)
	_dans_l_image(vide, "le vide")
	await _bouger(_sur(vide), 0.9)
	await _images(int(0.5 * FPS))
	await _clic(MOUSE_BUTTON_LEFT, "Click", "A tree in the air, on the grid plane")
	await _images(int(0.4 * FPS))
	print("plants : %d (dans l'air)" % _af.plants.size())
	await _clic(MOUSE_BUTTON_RIGHT, "Right click", "Remove it")
	await _touche(KEY_Z, "Ctrl + Z", "Undo: it is back", true)
	await _images(int(0.4 * FPS))
	await _touche(KEY_Y, "Ctrl + Y", "Redo: gone again", true)
	print("plants : %d" % _af.plants.size())
	await _etage_a(0, "The grid back down")
	await _mode("sol_libre", "Planted · free")


## Le bouton d'un mode (ou d'un outil) de l'atelier : la souris y va et clique.
func _mode(m: String, detail: String) -> void:
	var b: Button = _af._boutons_mode[m]
	await _cliquer_controle(b, detail)


# ── 4. LE PINCEAU ──────────────────────────────────────────────────────────────────────────────────

func _f_pinceau() -> void:
	var x := _x_demo + 0.5
	var zb := float(_z_plage)
	# Plus haut : la plaine entière entre la plage et les collines.
	await _glisser_camera(Vector3(x, 30, zb + 14), Vector3(x, 6, zb - 10), 1.2)
	await _cliquer_controle(_af._boutons_outil["pinceau"], "Brush: plant many at once")
	await _molette_mod(MOUSE_BUTTON_WHEEL_UP, 5, "alt", "Alt + wheel", "Brush size")
	await _molette_mod(MOUSE_BUTTON_WHEEL_UP, 4, "shift", "Shift + wheel", "Density: tries per dab")
	print("pinceau : %.1f, densité %d" % [_af.curseurs["pinceau_rayon"].value, int(_af.curseurs["pinceau_essais"].value)])
	var n0: int = _af.plants.size()
	await _trait([Vector3(x - 16, 7, zb - 9), Vector3(x - 6, 7, zb - 15), Vector3(x + 6, 7, zb - 10), Vector3(x + 16, 7, zb - 15)],
		MOUSE_BUTTON_LEFT, 2.6, "Left drag", "Paint a grove: every tree keeps its room")
	print("pinceau : %d plants" % (_af.plants.size() - n0))
	await _images(int(0.6 * FPS))
	var n1: int = _af.plants.size()
	await _trait([Vector3(x - 12, 7, zb - 12), Vector3(x + 12, 7, zb - 12)], MOUSE_BUTTON_RIGHT, 1.4, "Right drag",
		"Clear a path")
	print("effacés : %d" % (n1 - _af.plants.size()))
	await _images(int(0.5 * FPS))
	await _touche(KEY_Z, "Ctrl + Z", "One stroke, one undo", true)
	await _images(int(0.6 * FPS))


# ── 5. UN MONDE VARIÉ ──────────────────────────────────────────────────────────────────────────────

func _f_monde() -> void:
	var zb := float(_z_plage)
	if not _af.pinceau:
		await _cliquer_controle(_af._boutons_outil["pinceau"], "Brush")
		await _molette_mod(MOUSE_BUTTON_WHEEL_UP, 5, "alt", "Alt + wheel", "Brush size")
		await _molette_mod(MOUSE_BUTTON_WHEEL_UP, 4, "shift", "Shift + wheel", "Density")
	# La plaine : des bouleaux, clairsemés.
	await _glisser_camera(Vector3(-32, 32, zb + 18), Vector3(-32, 6, zb - 10), 1.2)
	await _importer("bouleau", false)
	await _glisser_curseur("espacement", 4.0, "Spacing", "No two trees closer than 4 cells", 0.5)
	await _trait([Vector3(-46, 7, zb - 8), Vector3(-38, 7, zb - 16), Vector3(-28, 7, zb - 9), Vector3(-24, 7, zb - 18), Vector3(-34, 7, 0)],
		MOUSE_BUTTON_LEFT, 2.2, "Left drag", "Birches on the plain")
	# La forêt : trois arbres, en débordement (sur chaque marche des collines), espacés.
	await _glisser_camera(Vector3(-28, 62, 34), Vector3(-28, 9, -22), 1.5)
	await _mode("sol_debord", "Overflow: a dense forest over every ledge")
	# Trois arbres en bandes qui se chevauchent à moitié (rayon 6 tous les 6) : chacun garde sa part de la forêt.
	var rangs := {"pin": [-6.0, -24.0], "parasol": [-12.0, -30.0], "sapin": [-18.0, -36.0]}
	var ouest := true
	for cle in ["pin", "parasol", "sapin"]:
		await _importer(cle, false)
		await _glisser_curseur("espacement", 3.2, "Spacing", "3 cells between trunks", 0.4)
		for z in rangs[cle]:
			await _trait([Vector3(-54, 10, z), Vector3(-2, 10, z + 2.0)], MOUSE_BUTTON_LEFT, 1.6, "Left drag",
				"A forest on the hills")
		print("forêt %s : %d plants" % [cle, _af.plants.size()])
	# L'est des collines.
	await _glisser_camera(Vector3(28, 62, 32), Vector3(28, 9, -22), 1.5)
	for cle in ["pin", "parasol", "sapin"]:
		await _choisir_modele(cle)
		for z in rangs[cle]:
			await _trait([Vector3(0, 10, z + 2.0), Vector3(54, 10, z)], MOUSE_BUTTON_LEFT, 1.4, "Left drag",
				"The whole range")
	print("forêt : %d plants" % _af.plants.size())
	# Le sentier du stickman : à travers les bouleaux et le bosquet de la plaine, dégagé au clic droit.
	# ⚠ PAS DANS LES COLLINES (cinquième essai) : entre les marches et les surplombs, il restait bloqué, et la caméra
	# finissait dans sa tête (écran violet) ; et les arbres n'ont pas de collision. La plaine est plate, le vol fait le reste.
	_sentier = _route(SENTIER_DE, SENTIER_A)
	await _glisser_camera(Vector3(-25, 36, 42), Vector3(-25, 6, 8), 1.2)
	await _molette_mod(MOUSE_BUTTON_WHEEL_DOWN, 5, "alt", "Alt + wheel", "A smaller brush")
	# Il part de plus à l'ouest : la caméra du Play test est DERRIÈRE lui, et un tronc lui passait devant (sixième essai).
	var pts := [Vector3(SENTIER_DE.x - 7.0, 7, SENTIER_DE.y), Vector3(SENTIER_DE.x, 7, SENTIER_DE.y)]
	pts.append_array(_sentier)
	await _trait(pts, MOUSE_BUTTON_RIGHT, 2.4, "Right drag", "A path through the woods")
	print("sentier : %d points, plants %d" % [_sentier.size(), _af.plants.size()])
	# La plage : des palmiers, en voisinage libre (pas dans l'eau).
	await _mode("sol_libre", "Planted · free")
	await _glisser_camera(Vector3(-19, 38, zb + 48), Vector3(-19, 5, zb + 1), 1.3)
	await _molette_mod(MOUSE_BUTTON_WHEEL_UP, 3, "alt", "Alt + wheel", "Brush size")
	await _importer("palmier", false)
	await _glisser_curseur("espacement", 3.5, "Spacing", "3.5 cells", 0.4)
	await _trait([Vector3(-44, 6, zb + 3), Vector3(-30, 6, zb + 2), Vector3(-10, 6, zb + 3), Vector3(6, 6, zb + 2)],
		MOUSE_BUTTON_LEFT, 2.4, "Left drag", "Palms along the beach — none in the water")
	# Le désert : deux cactus.
	await _glisser_camera(Vector3(40, 40, 42), Vector3(40, 5, 10), 1.4)
	for cle in ["saguaro", "cierge"]:
		await _importer(cle, false)
		await _glisser_curseur("espacement", 4.5, "Spacing", "A sparse desert", 0.4)
		var d := 1.0 if cle == "saguaro" else -1.0
		await _trait([Vector3(24, 6, 6 + 4 * d), Vector3(34, 6, 16 - 3 * d), Vector3(46, 6, 22), Vector3(56, 6, 6 + 5 * d),
			Vector3(46, 6, -4)], MOUSE_BUTTON_LEFT, 2.2, "Left drag", "Cacti in the desert")
	print("monde : %d plants, %d modèles" % [_af.plants.size(), _af.modeles.size()])
	# Le tout.
	await _bouger(Vector2(root.size.x - 3, root.size.y - 3), 0.4)
	_montrer("World", "%d plants, %d models" % [_af.plants.size(), _af.modeles.size()])
	await _orbite_f(Vector3(0, 6, -2), 0.5, 0.55, 0.25, 95.0, 85.0, 5.0)
	_ecran._enregistrer()


## Le modèle d'un arbre déjà importé : un clic sur sa ligne dans la liste MODELS.
func _choisir_modele(cle: String) -> void:
	var nom: String = (ARBRES[cle][0] as String).get_file().get_basename()
	for c in _af.liste.get_children():
		if c is Button and (c as Button).is_visible_in_tree() and (c as Button).text.begins_with(nom):
			await _cliquer_controle(c, nom)
			return
	print("⚠ modèle introuvable dans la liste : %s" % nom)


## La colonne la plus proche de `pres` qu'on atteint à pied depuis `de` (une case à monter au plus, par saut).
func _atteignable_pres_de(de: Vector2, pres: Vector2) -> Vector2:
	var depart := Vector2i(floori(de.x), floori(de.y))
	var vu := {depart: true}
	var file := [depart]
	var i := 0
	var meilleur := depart
	while i < file.size():
		var c: Vector2i = file[i]
		i += 1
		if Vector2(c).distance_to(pres) < Vector2(meilleur).distance_to(pres):
			meilleur = c
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not vu.has(n) and _passe(c, n):
				vu[n] = true
				file.append(n)
	print("atteignable près de %s : %s, h %d" % [pres, meilleur, _h[meilleur]])
	return Vector2(meilleur.x + 0.5, meilleur.y + 0.5)


## La plus haute colonne des collines de l'ouest qu'on atteint à pied depuis `de`.
func _sommet_atteignable(de: Vector2) -> Vector2:
	var depart := Vector2i(floori(de.x), floori(de.y))
	var vu := {depart: true}
	var file := [depart]
	var i := 0
	var meilleur := depart
	while i < file.size():
		var c: Vector2i = file[i]
		i += 1
		if c.x >= -50 and c.x <= -12 and c.y >= -34 and int(_h[c]) > int(_h[meilleur]):
			meilleur = c
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not vu.has(n) and _passe(c, n):
				vu[n] = true
				file.append(n)
	print("sommet atteignable : %s, h %d" % [meilleur, _h[meilleur]])
	return Vector2(meilleur.x + 0.5, meilleur.y + 0.5)


func _orbite_f(cible: Vector3, el: float, az0: float, az1: float, d0: float, d1: float, duree: float) -> void:
	_vue._cible = cible
	_vue._elevation = el
	var n := int(duree * FPS)
	for i in n:
		var t := _doux(float(i) / float(n - 1))
		_vue._azimut = lerpf(az0, az1, t)
		_vue._distance = lerpf(d0, d1, t)
		_vue._caler()
		await _images(1)


# ── 6. LE PLAY TEST : le soleil, le vent, le stickman ──────────────────────────────────────────────

func _f_jeu() -> void:
	var depart := Vector3(SENTIER_DE.x, _dessus_f(SENTIER_DE.x, SENTIER_DE.y), SENTIER_DE.y)
	_vue._cible = depart
	_cam_haut = false
	_cam_d = 6.0
	_cam_e = 0.38
	await _cliquer_bouton("Play test", "Play test: the real light")
	await _bouger(Vector2(root.size.x + 40, root.size.y + 40), 0.3)
	await _images(int(0.6 * FPS))
	_montrer("Render", "A low golden sun")
	for reglage in [["soleil_hauteur", 30.0], ["soleil_azimut", 200.0], ["soleil_couleur", Color(1.0, 0.88, 0.72)],
			["soleil_energie", 1.5], ["ciel_horizon", Color("#f2b98a")], ["glow", true], ["glow_intensite", 1.0]]:
		_vue.regler_rendu(reglage[0], reglage[1])
		await _images(3)
	var p: CharacterBody3D = _vue.personnage
	if p == null:
		print("⚠ pas de personnage")
		return
	_vue._azimut = -PI * 0.5   # vers l'est, le long du sentier
	await _images(int(1.2 * FPS))
	print("stickman en %s" % p.global_position)
	await _aller(_sentier, "W A S D", "Walk the path: every tree sways in the wind", true)
	_cam_d = 7.0
	_cam_e = 0.3
	await _regarder_autour(4.0)
	# L'envol : au-dessus de la forêt, puis la plaine, la plage, le désert.
	await _touche(KEY_F, "F", "Fly")
	# D'abord tout droit vers le haut, au-dessus des cimes, avant d'avancer.
	_montrer("Space", "Up, above the trees")
	_cam_d = 8.0
	_cam_e = 0.32
	_cle(KEY_SPACE, true)
	for i in int(4 * FPS):
		if p.global_position.y > _dessus_f(p.global_position.x, p.global_position.z) + 11.0:
			break
		await _images(1)
	_cle(KEY_SPACE, false)
	print("envol : stickman en %s" % p.global_position)
	var cles := [Vector2(p.global_position.x, p.global_position.z), Vector2(-12, -8), Vector2(-6, -24), Vector2(14, -24),
		Vector2(32, -10), Vector2(42, 2), Vector2(34, 10), Vector2(18, 10), Vector2(4, 8)]
	await _voler_f(cles, "W A S D", "Over the forest, then the desert")
	# La fin : on plane, la caméra recule.
	for k in [KEY_W, KEY_SPACE, KEY_Q]:
		_cle(k, false)
	_cam_d = 24.0
	_cam_e = 0.34
	await _images(int(5.0 * FPS))
	await _touche(KEY_ESCAPE, "Esc", "Back to World")


## Le vol, en poursuite d'un chemin lissé (le devlog du paysage : il vise le point 8 cases devant, jamais un point passé),
## à 9-12 cases au-dessus du sol (au-dessus des cimes : les arbres n'ont pas de collision).
func _voler_f(cles: Array, carte: String, detail: String) -> void:
	var p: CharacterBody3D = _vue.personnage
	var chemin := []
	for i in cles.size() - 1:
		var p0: Vector2 = cles[maxi(i - 1, 0)]
		var p1: Vector2 = cles[i]
		var p2: Vector2 = cles[i + 1]
		var p3: Vector2 = cles[mini(i + 2, cles.size() - 1)]
		var n := maxi(1, int(p1.distance_to(p2)))
		for j in n:
			var t := float(j) / n
			var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
			chemin.append(Vector3(q.x, 0, q.y))
	_montrer(carte, detail)
	_cam_d = 8.0
	_cam_e = 0.3
	_cle(KEY_W, true)
	var k := 0
	for i in int(60 * FPS):
		var pos := p.global_position
		while k < chemin.size() - 1 and Vector2(chemin[k + 1].x - pos.x, chemin[k + 1].z - pos.z).length() \
				< Vector2(chemin[k].x - pos.x, chemin[k].z - pos.z).length():
			k += 1
		if k >= chemin.size() - 2:
			break
		var vise: Vector3 = chemin[mini(k + 8, chemin.size() - 1)]
		var plat := Vector2(vise.x - pos.x, vise.z - pos.z)
		_vue._azimut = lerp_angle(_vue._azimut, atan2(-plat.x, -plat.y), 0.1)
		var devant := pos + Vector3(plat.normalized().x, 0, plat.normalized().y) * 5.0
		var sol := maxf(_dessus_f(pos.x, pos.z), _dessus_f(devant.x, devant.z))
		for d in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
			sol = maxf(sol, _dessus_f(devant.x + d.x, devant.z + d.y))
		var haut := pos.y - sol
		_cle(KEY_SPACE, haut < 10.0)
		_cle(KEY_Q, haut > 13.0)
		if i % int(4 * FPS) == 0:
			print("vol : point %d/%d, stickman en %s" % [k, chemin.size(), pos])
		await _images(1)
	_cle(KEY_W, false)
	_cle(KEY_SPACE, false)
	_cle(KEY_Q, false)


# ── LES GESTES DE L'ATELIER ─────────────────────────────────────────────────────────────────────────

## Un contrôle du panneau de droite : la molette le fait défiler jusqu'à lui (sur une étiquette, jamais sur un curseur ni
## sur le socle, qui prendraient la molette), puis on attend qu'il s'arrête.
func _dans_le_panneau(c: Control) -> void:
	var ecran := Rect2(Vector2(0, 40), Vector2(root.size) - Vector2(0, 40))
	if ecran.encloses(c.get_global_rect()):
		return
	var defile := c.get_parent()
	while defile != null and not defile is ScrollContainer:
		defile = defile.get_parent()
	if defile == null:
		return
	var r := (defile as Control).get_global_rect()
	var ou := _endroit_sur(r)
	await _bouger(ou, 0.3)
	for i in 60:
		if ecran.encloses(c.get_global_rect()):
			break
		var sens := MOUSE_BUTTON_WHEEL_DOWN if c.get_global_rect().end.y > ecran.end.y else MOUSE_BUTTON_WHEEL_UP
		# ⚠ Le défilement déplace ce qui est sous la souris : on revérifie l'endroit à chaque cran.
		var ici := _endroit_sur(r)
		if ici.distance_to(_souris) > 1.0:
			await _bouger(ici, 0.1)
		_presser(sens, true)
		_presser(sens, false)
		await _images(2)
	await _images(12)


## Un endroit du panneau où la molette va au défilement : une marge gauche, hors du socle et des curseurs.
func _endroit_sur(r: Rect2) -> Vector2:
	var interdits: Array = [_af.socle.get_global_rect()]
	for k in _af.curseurs:
		interdits.append((_af.curseurs[k] as Control).get_global_rect().grow(4))
	for dy in range(0, int(r.size.y * 0.45), 16):
		for s in [1, -1]:
			var p := Vector2(r.position.x + 6, r.get_center().y + s * dy)
			if interdits.all(func(q: Rect2) -> bool: return not q.has_point(p)):
				return p
	return Vector2(r.position.x + 6, r.position.y + 50)


func _cliquer_controle(c: Control, detail: String) -> void:
	await _dans_le_panneau(c)
	await _bouger(c.get_global_rect().get_center(), 0.5)
	await _clic(MOUSE_BUTTON_LEFT, "Click", detail)


## Un curseur glissé de sa valeur à `valeur` : la souris prend la poignée, glisse, lâche (Slider de Godot : la valeur suit
## (x − poignée/2) / (largeur − poignée), en échelle log si `exp_edit`).
func _glisser_curseur(cle: String, valeur: float, carte: String, detail: String, duree := 0.9) -> void:
	var c: HSlider = _af.curseurs[cle]
	await _dans_le_panneau(c)
	var r := c.get_global_rect()
	await _bouger(Vector2(_x_du_curseur(c, c.value), r.get_center().y), 0.4)
	_montrer(carte, detail)
	_presser(MOUSE_BUTTON_LEFT, true)
	await _images(2)
	await _bouger(Vector2(_x_du_curseur(c, valeur), r.get_center().y), duree)
	await _images(3)
	_presser(MOUSE_BUTTON_LEFT, false)
	await _images(int(0.3 * FPS))
	print("curseur %s : %.3f (voulu %.3f)" % [cle, c.value, valeur])


func _x_du_curseur(c: HSlider, v: float) -> float:
	var t: float
	if c.exp_edit and c.min_value > 0.0:
		t = (log(v) - log(c.min_value)) / (log(c.max_value) - log(c.min_value))
	else:
		t = (v - c.min_value) / (c.max_value - c.min_value)
	var g := float(c.get_theme_icon("grabber").get_width())
	var r := c.get_global_rect()
	return r.position.x + g * 0.5 + clampf(t, 0.0, 1.0) * (r.size.x - g)


## La molette avec Alt ou Maj (la grandeur de l'outil), sur la vue.
func _molette_mod(sens: int, crans: int, mod: String, carte: String, detail: String) -> void:
	if not Rect2(Vector2(320, 80), Vector2(1260, 900)).has_point(_souris):
		await _bouger(Vector2(900, 560), 0.4)
	_montrer(carte, detail)
	var k := KEY_ALT if mod == "alt" else KEY_SHIFT
	_cle(k, true)
	for i in crans:
		for oui in [true, false]:
			var b := InputEventMouseButton.new()
			b.button_index = sens
			b.pressed = oui
			b.position = _souris
			b.global_position = _souris
			b.alt_pressed = mod == "alt"
			b.shift_pressed = mod == "shift"
			_envoyer(b)
		await _images(5)
	_cle(k, false)
	await _images(6)


## Un glissé (gauche : planter, droit : enlever) le long de points du monde, à vitesse constante.
func _trait(points: Array, bouton: int, duree: float, carte: String, detail: String) -> void:
	# ⚠ UN POINT HORS DE LA VUE (sous un panneau) : le clic tombait sur le panneau, et tout le trait était perdu en silence
	# (troisième essai : ni bouleaux ni palmiers). On ne garde que les points dans la vue.
	var ecran: Array = []
	for w in points:
		var q := Vector3(w.x, _dessus_f(w.x, w.z), w.z) if w.y > 0.0 else (w as Vector3)
		if _dans_l_image(q, detail):
			ecran.append(_sur(q))
	if ecran.size() < 2:
		print("⚠ trait « %s » : moins de deux points dans la vue" % detail)
		return
	var longueur := 0.0
	for i in ecran.size() - 1:
		longueur += (ecran[i] as Vector2).distance_to(ecran[i + 1])
	await _bouger(ecran[0], 0.4)
	_montrer(carte, detail)
	_presser(bouton, true)
	await _images(2)
	var n := maxi(1, int(duree * FPS))
	for f in n:
		var s := longueur * float(f + 1) / float(n)
		var p: Vector2 = ecran[ecran.size() - 1]
		for i in ecran.size() - 1:
			var l := (ecran[i] as Vector2).distance_to(ecran[i + 1])
			if s <= l:
				p = (ecran[i] as Vector2).lerp(ecran[i + 1], s / maxf(l, 0.001))
				break
			s -= l
		var m := InputEventMouseMotion.new()
		var avant := _souris
		_souris = p
		m.position = p
		m.global_position = p
		m.relative = p - avant
		m.button_mask = _masque
		_envoyer(m)
		await _images(1)
	_presser(bouton, false)
	await _images(4)


## La caméra de l'éditeur glisse d'un regard à un autre.
func _glisser_camera(oeil: Vector3, vers: Vector3, duree: float) -> void:
	var cam: Camera3D = _vue._camera
	var o0 := cam.global_position
	var v0: Vector3 = _vue._cible
	var n := int(duree * FPS)
	for i in n:
		var t := _doux(float(i + 1) / float(n))
		_regarder(o0.lerp(oeil, t), v0.lerp(vers, t))
		await _images(1)


## Un point de l'écran près de `autour` (le dessus du relief) où la règle dit `raison` ("" : accepté), pour le plant le
## plus grand ET le plus petit du tirage. La règle est celle de l'atelier (`vise`, `FE.verifier`), lue, pas refaite.
func _point_ou(raison: String, autour: Vector3, portee: float) -> Variant:
	var m: Dictionary = _af.modele_actif()
	var inv: Transform2D = _vue.get_global_transform_with_canvas().affine_inverse()
	var meilleur: Variant = null
	var d_min := INF
	var a := float(m["echelle_alea"])
	var pas := 0.25
	var n := int(portee / pas)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var w := autour + Vector3(i * pas, 0, j * pas)
			if not _h.has(Vector2i(floori(w.x), floori(w.z))):
				continue
			w.y = _dessus_f(w.x, w.z)
			var cam: Camera3D = _vue._camera
			if cam.is_position_behind(w):
				continue
			var g := _sur(w)
			if not Rect2(Vector2(330, 80), Vector2(1240, 880)).has_point(g):
				continue
			var v: Dictionary = _af.vise(inv * g)
			if v.is_empty():
				continue
			var ok := true
			for e in [1.0 + a, 1.0 - a]:
				var pl := FE.plant(-1, int(m["id"]), v["p"], 0.0, e, _af.mode)
				var r: String = FE.verifier(m, pl, v["normale"], _af.mode, _af.monde(), _af._ix, _af._par_id(),
					_af._espacement(), _af._pente())
				if r != raison:
					ok = false
			var d := w.distance_to(autour)
			if ok and d < d_min:
				d_min = d
				meilleur = g
	return meilleur


# ── LE COÛT ──────────────────────────────────────────────────────────────────────────────────────────

func _images(n: int) -> void:
	for i in n:
		var t0 := Time.get_ticks_usec()
		await super._images(1)
		# `-- --photos=N` (mise au point, sans film) : une image PNG toutes les N images, dans le dossier de travail.
		if _photos > 0 and _image % _photos == 0:
			root.get_texture().get_image().save_png(PHOTOS + "/f_%05d.png" % _image)
		if _ecran != null and _ecran._atelier == "jeu":
			_temps_images.append(Time.get_ticks_usec() - t0)
			_prims_maxi = maxi(_prims_maxi, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
			_appels_maxi = maxi(_appels_maxi, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))


func _rapport_du_cout() -> void:
	if _af == null:
		return
	var tris := 0
	for m in _af.modeles:
		var d: Dictionary = FeuillageVue_.charger(str(m["chemin"]))
		var t := 0
		for partie in d["parties"]:
			var me: Mesh = partie[0]
			for s in me.get_surface_count():
				var arr := me.surface_get_arrays(s)
				t += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var n := (_af._plants_de(m) as Array).size()
		print("COÛT %s : %d plants × %d triangles" % [m["nom"], n, t])
		tris += n * t
	var moy := 0.0
	for t in _temps_images:
		moy += t
	if not _temps_images.is_empty():
		moy /= _temps_images.size()
	print("COÛT : %d plants, %d modèles, %.1f M triangles d'arbres ; Play test : %d images, %.1f ms par image en moyenne (rendu + écriture du film)"
		% [_af.plants.size(), _af.modeles.size(), tris / 1e6, _temps_images.size(), moy / 1000.0])
	print("COÛT : au plus %.1f M primitives et %d appels de dessin par image au Play test" % [_prims_maxi / 1e6, _appels_maxi])


# ── LE MONDE ─────────────────────────────────────────────────────────────────────────────────────────

## Le relief et la matière de chaque colonne : la mer au sud, la plage, la plaine et ses buttes, le désert et ses mesas à
## l'est, les collines boisées au nord (la roche où la pente est forte ou le sommet haut).
func _terrain_f() -> void:
	_bruit.seed = 5
	_bruit.frequency = 0.05
	_fbm_f.seed = 17
	_fbm_f.frequency = 0.035
	_fbm_f.fractal_octaves = 4
	_h.clear()
	_m.clear()
	for x in range(X0, X1 + 1):
		for z in range(Z0, Z1 + 1):
			var k := Vector2i(x, z)
			var p := Vector2(x + 0.5, z + 0.5)
			var cote := COTE_F + 3.0 * _bruit.get_noise_2d(p.x * 0.4, 50.0)
			var h := 6
			var m := "herbe"
			if p.y > cote:
				h = maxi(-1, 3 - int(floor((p.y - cote) * 0.45)))
				m = "sable"
			elif p.y > cote - 6.0:
				h = 5
				m = "sable"
			elif p.distance_to(DESERT_C) + 9.0 * _bruit.get_noise_2d(p.x * 0.6 + 200.0, p.y * 0.6) < DESERT_R:
				h = 5
				m = "sable"
				for me in MESAS:
					if _dans(p, me[0], me[1]):
						h = maxi(h, int(me[2]))
						m = "roche"
			elif p.y < PIED_COLLINES:
				var t := clampf((PIED_COLLINES - p.y) / 18.0, 0.0, 1.0)
				var n := clampf(_fbm_f.get_noise_2d(p.x, p.y) * 0.9 + 0.5, 0.0, 1.0)
				h = 6 + int(round(t * (1.5 + 12.0 * pow(n, 1.4)) + 1.2 * t * _bruit.get_noise_2d(p.x * 1.5, p.y * 1.5)))
			else:
				for b in BUTTES:
					if _dans(p, b[0], b[1]):
						h = 6 + int(b[2])
			_h[k] = h
			_m[k] = m
	_sans_damier()
	# La roche des collines : là où la pente est forte, ou le sommet haut.
	for k in _h:
		if _m[k] != "herbe" or k.y >= PIED_COLLINES:
			continue
		var pente := 0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _h.has(k + d):
				pente = maxi(pente, absi(int(_h[k]) - int(_h[k + d])))
		if pente >= 3 or _h[k] >= 16:
			_m[k] = "roche"
	_un_niveau_une_matiere()


## Le dessus d'une colonne du relief, en y (le sol des cases ; les tuiles l'amincissent d'un quart).
func _dessus_f(x: float, z: float) -> float:
	return float(_h.get(Vector2i(floori(x), floori(z)), 6)) + 1.0


## Le chemin du stickman : jamais plus d'une case à monter (haut l'interdisait aussi près de son puits : pas ici).
func _passe(c: Vector2i, n: Vector2i) -> bool:
	return _h.has(n) and int(_h[n]) - int(_h[c]) <= 1 and int(_h[n]) > MER_F
