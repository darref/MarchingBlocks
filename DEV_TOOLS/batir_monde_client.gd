extends "res://DEV_TOOLS/filmer_ui.gd"
##
## LE MONDE D'UN CLIENT — demandé par Jordan (16 octobre 2026) : « modéliser et peindre des témoins avec leur thème,
## plaine désert roche volcan plage boue gravier rocaille mur de pierre glace neige, avec un niveau de subdivision sweet
## spot pour qu'un monde tienne sans lagger, et utiliser toutes les fonctions du soft — variantes, transitions —, pour
## finir un monde tel qu'il sera dans le jeu vidéo d'un client, et aussi le foliage ».
##
## Un projet NEUF, bâti par le logiciel lui-même, puis photographié et MESURÉ (images par seconde, primitives) :
##   1. LES TÉMOINS — une BASE commune (le témoin calculé au cran neutre, subdivisé par lot, arrondi : `forge_temoins.gd`),
##      puis, par thème, une copie dont seul le DEDANS est retouché (bosses, rocaille, dunes lissées…) — les bords restent
##      ceux de la base : les douze couches se raccordent entre elles par construction. Deux VARIANTES voulues du sol, de la
##      paroi et de la lèvre de falaise, au dedans retouché autrement, tirées 2 : 1 : 1. Deux matériaux par thème (le sol
##      pour ce qui regarde le ciel, la paroi pour le reste), aux ensembles PBR de Spirit3D, projetés en boîte (une
##      répétition par case : le raccord d'une tuile à l'autre), COPIÉS dans le projet et ramenés à 1 024² (la mémoire
##      vidéo de douze couches).
##   2. LE MONDE — une île : prairies en terrasses au centre et leur village muré (mur de pierre, chemins de gravier), une
##      forêt, des montagnes de roche aux sommets enneigés et un glacier au nord, un lac de montagne qui descend en rivière
##      jusqu'à la mer, un volcan et son lac de lave à l'ouest, un désert de dunes et ses mesas de rocaille à l'est, un
##      marais de boue au sud-ouest, des plages tout autour. Les transitions entre les couches qui se touchent, le feuillage
##      de chaque biome (Spirit3D), l'eau (mer, rivière, lave, marais).
##   3. LES PHOTOS et LA MESURE — un plan par biome, et dans chacun les images par seconde (synchro verticale coupée), les
##      primitives et les appels de dessin, écrits dans `perf.json`.
##
## LANCEMENT (avec fenêtre, sur le PC : Spirit3D y est) :
##   Godot_v4.7-stable_win64_console.exe --path <dépôt> --script res://DEV_TOOLS/batir_monde_client.gd -- \
##       --dossier=<dossier> [--niveau=1] [--sans-feuillage] [--seulement=temoins|monde|photos] [--refaire]
##   --niveau : la subdivision de la base (0, 1, 2). --refaire : obligatoire si le dossier porte déjà un projet.
## ⚠ Ne pas l'interrompre : il rend `reglages.cfg` à la fin.

const F := preload("res://DEV_TOOLS/forge_temoins.gd")
const TL_ := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const Peinture_ := preload("res://addons/marchingblocks_core/peinture.gd")
const TR_ := preload("res://addons/marchingblocks_core/transitions.gd")

const DOSSIER_DEFAUT := "C:/Users/jorda/Documents/MarchingBlocks/monde_client"
const SPIRIT := "D:/Spirit3D/HEART_WORLD/biomes/maps/"
const TAILLE_TEXTURE := 1024

## Les douze thèmes, dans l'ORDRE DE PRIORITÉ des couches (le haut gagne une case disputée — il n'y en a pas : chaque
## colonne est à une couche). sol / paroi : [image couleur sous SPIRIT, teinte, rugosité].
const THEMES := [
	{"nom": "StoneWall", "sol": ["biome_waterfalls/ground_tiles_01_2k/ground_tiles_01_color_2k.png", Color(1, 1, 1), 0.9],
		"paroi": ["biome_petrified/stone_bricks_wall_03_2k/stone_bricks_wall_03_color_2k.png", Color(1, 1, 1), 0.9]},
	{"nom": "Gravel", "sol": ["biome_saltflats/ground_01_2k/ground_01_color_2k.png", Color(0.92, 0.9, 0.88), 0.95],
		"paroi": ["biome_saltflats/ground_02_2k/ground_02_color_2k.png", Color(1, 1, 1), 0.95]},
	{"nom": "Meadow", "sol": ["biome_plains/grass_with_rocks_01_2k/grass_with_rocks_01_color_2k.png", Color(1, 1, 1), 0.9],
		"paroi": ["biome_desert/cliff_rocks_01_1k/cliff_rocks_01_color_1k.png", Color(0.82, 0.72, 0.62), 0.9]},
	{"nom": "Forest", "sol": ["biome_moorland/moss_ground_01_2k/moss_groud_01_Base_Color_2k.png", Color(0.85, 0.92, 0.85), 0.9],
		"paroi": ["biome_jungle/ground_with_roots_01_2k/ground_with_roots_01_color_2k.png", Color(0.8, 0.75, 0.7), 0.9]},
	{"nom": "Desert", "sol": ["biome_desert/sand_03_2k/sand_03_color_2k.png", Color(1, 1, 1), 0.95],
		"paroi": ["biome_desert/cliff_rocks_01_1k/cliff_rocks_01_color_1k.png", Color(1, 1, 1), 0.9]},
	{"nom": "Scree", "sol": ["biome_highpeaks/ground_with_rocks_02_2k/ground_with_rocks_02_color_2k.png", Color(1, 1, 1), 0.9],
		"paroi": ["biome_savanna/cliff_rocks_03_2k/cliff_rocks_03_baseColor_2k.png", Color(1, 1, 1), 0.9]},
	{"nom": "Beach", "sol": ["biome_submerged/sand_02_2k/sand_02_color_2k.png", Color(1, 1, 1), 0.95],
		"paroi": ["biome_desert/sand_03_2k/sand_03_color_2k.png", Color(0.9, 0.85, 0.78), 0.95]},
	{"nom": "Mud", "sol": ["biome_saltflats/ground_02_2k/ground_02_color_2k.png", Color(0.6, 0.48, 0.38), 0.5],
		"paroi": ["biome_jungle/ground_with_roots_01_2k/ground_with_roots_01_color_2k.png", Color(0.62, 0.52, 0.42), 0.7]},
	{"nom": "Volcano", "sol": ["biome_firelands/lava_rocks_01_2k/lava_rocks_01_color_2k.png", Color(1, 1, 1), 0.85],
		"paroi": ["biome_firelands/cliff_rocks_05_2k/cliff_rocks_05_basecolor_2k.png", Color(0.45, 0.42, 0.48), 0.85]},
	{"nom": "Rock", "sol": ["biome_waterfalls/concrete_wall_10_2k/concrete_wall_10_basecolor_2k.png", Color(1, 1, 1), 0.9],
		"paroi": ["biome_firelands/cliff_rocks_05_2k/cliff_rocks_05_basecolor_2k.png", Color(0.85, 0.85, 0.9), 0.9]},
	{"nom": "Snow", "sol": ["biome_tundra/snow_01_2k/snow_01_color_2k.png", Color(1, 1, 1), 0.85],
		"paroi": ["biome_highpeaks/cliff_rocks_04_2k/cliff_rocks_04_baseColor_2k.png", Color(0.9, 0.92, 0.95), 0.9]},
	{"nom": "Ice", "sol": ["biome_taiga/snow_01_2k/snow_01_color_2k.png", Color(0.7, 0.9, 1.0), 0.2],
		"paroi": ["biome_taiga/snow_01_2k/snow_01_color_2k.png", Color(0.5, 0.78, 0.98), 0.15]},
]

## Les clés qui reçoivent deux variantes (les plus posées d'un monde : le sol, la paroi, la lèvre de falaise), tirées 2 : 1 : 1.
const CLES_VARIEES := ["mb_plaque_b4h0_dehors", "mb_plaque_b2h2_dehors", "mb_arete_b2h0_dehors"]

## LE FEUILLAGE par thème : [fichier sous SPIRIT, hauteur voulue en cases, part des colonnes du thème].
const FEUILLAGE := {
	"Meadow": [["biome_plains/obstacles/plains_tree_01/plains_tree_01.glb", 4.5, 0.012],
		["biome_plains/obstacles/plains_tree_02/plains_tree_02.glb", 4.0, 0.012],
		["biome_plains/obstacles/plains_tree_04/plains_tree_04.glb", 5.0, 0.012],
		["biome_savanna/obstacles/savanna_grass_02/savanna_grass_02.glb", 0.7, 0.06]],
	"Forest": [["biome_jungle/obstacles/jungle_tree_01/jungle_tree_01.glb", 6.5, 0.06],
		["biome_jungle/obstacles/jungle_tree_02/jungle_tree_02.glb", 5.5, 0.06],
		["biome_jungle/obstacles/jungle_plant/jungle_plant.glb", 1.0, 0.08]],
	"Desert": [["biome_desert/obstacles/desert_cactus_01/desert_cactus_01.glb", 2.2, 0.008],
		["biome_desert/obstacles/desert_cactus_06/desert_cactus_06.glb", 1.6, 0.008],
		["biome_desert/obstacles/desert_cactus_08/desert_cactus_08.glb", 1.2, 0.008]],
	"Beach": [["biome_lakeshore/obstacles/spiral+seashell+3d+model.glb", 0.3, 0.02],
		["biome_lakeshore/obstacles/starfish+3d+model.glb", 0.2, 0.02],
		["biome_desert/resources/obstacles/palm+tree+3d+model_Clone1.glb", 6.0, 0.006]],
	"Mud": [["biome_swamps/obstacles/tree+3d+model.glb", 5.5, 0.02],
		["biome_savanna/obstacles/savanna_grass_01/savanna_grass_01.glb", 0.8, 0.05]],
	"Rock": [["biome_waterfalls/obstacles/waterfall_boulder_01/waterfall_boulder_01.glb", 1.2, 0.015],
		["biome_waterfalls/obstacles/waterfall_rock_02/waterfall_rock_02.glb", 0.9, 0.015]],
	"Scree": [["biome_saltflats/obstacles/saltflat_rock_01/saltflat_rock_01.glb", 0.9, 0.03],
		["biome_waterfalls/obstacles/waterfall_rock_04/waterfall_rock_04.glb", 0.6, 0.03]],
	"Gravel": [["biome_waterfalls/obstacles/waterfall_pebble_02/waterfall_pebble_02.glb", 0.4, 0.04]],
	"Volcano": [["biome_firelands/obstacles/volcano_prop_01/volcano_prop_01.glb", 1.8, 0.02],
		["biome_firelands/obstacles/volcano_prop_07/volcano_prop_07.glb", 1.4, 0.02]],
	"Snow": [["biome_ice/obstacles/ice_crystal_01/ice_crystal_01.glb", 1.6, 0.02],
		["biome_ice/obstacles/ice_shard_01/ice_shard_01.glb", 1.0, 0.02]],
	"Ice": [["biome_ice/obstacles/ice_serac_04/ice_serac_04.glb", 2.5, 0.03],
		["biome_ice/obstacles/ice_crystal_04/ice_crystal_04.glb", 1.2, 0.02]],
}

## Les paires de couches qui se touchent et se fondent (transitions).
const PAIRES := [["Meadow", "Forest"], ["Meadow", "Beach"], ["Meadow", "Gravel"], ["Meadow", "Mud"],
	["Meadow", "Desert"], ["Meadow", "Rock"], ["Meadow", "Volcano"], ["Desert", "Scree"], ["Desert", "Beach"],
	["Desert", "Gravel"], ["Rock", "Snow"], ["Rock", "Ice"], ["Snow", "Ice"], ["Volcano", "Rock"], ["Mud", "Beach"],
	["Forest", "Rock"], ["Gravel", "StoneWall"], ["Meadow", "StoneWall"], ["Volcano", "Gravel"], ["Beach", "Rock"]]

var _dossier_mc := DOSSIER_DEFAUT
var _projet_mc := ""
var _photos := ""
var _niveau := 1
var _sans_feuillage := false
var _chanfrein := 0.85
var _rapport := {}


func _initialize() -> void:
	var refaire := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seulement="):
			_seulement = a.substr("--seulement=".length())
		elif a.begins_with("--dossier="):
			_dossier_mc = a.substr("--dossier=".length())
		elif a.begins_with("--niveau="):
			_niveau = int(a.substr("--niveau=".length()))
		elif a.begins_with("--chanfrein="):
			_chanfrein = float(a.substr("--chanfrein=".length()))
		elif a == "--sans-feuillage":
			_sans_feuillage = true
		elif a == "--refaire":
			refaire = true
	_projet_mc = _dossier_mc.path_join("monde_client.mbproj")
	_photos = _dossier_mc.path_join("photos")
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
	if FileAccess.file_exists(REGLAGES):
		DirAccess.copy_absolute(REGLAGES, SAUVEGARDE)
	if _seulement == "" or _seulement == "temoins":
		if FileAccess.file_exists(_projet_mc) and not refaire:
			print("⚠ %s existe : relancer avec -- --refaire pour le refaire" % _projet_mc)
			_rendre_les_reglages()
			quit(1)
			return
		_vider(_dossier_mc)
		DirAccess.make_dir_recursive_absolute(_dossier_mc)
		var couches := []
		for i in THEMES.size():
			var poids := {}
			for c in CLES_VARIEES:
				poids[c] = [2, 1, 1]
			couches.append({"nom": THEMES[i]["nom"], "source": "", "visible": true, "cases": [], "temoin": "",
				"id": str(i + 1), "poids": poids, "choix": []})
		var f := FileAccess.open(_projet_mc, FileAccess.WRITE)
		f.store_string(JSON.stringify({"format": "marchingblocks-project", "version": 3, "active": 0,
			"couches": couches, "eaux": [], "retrait": 0.0}, "\t"))
		f.close()
	DirAccess.make_dir_recursive_absolute(_photos)
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", _projet_mc)
	r.set_value("projet", "monde", _projet_mc)
	r.save(REGLAGES)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	Input.use_accumulated_input = false
	_derouler.call_deferred()


func _derouler() -> void:
	var debut := Time.get_ticks_msec()
	await _images(30)
	await _ecran._ouvrir(_projet_mc)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	if _ecran._legende_formes != null:
		_ecran._legende_formes.basculer(false, false)
	var etapes := ["temoins", "monde", "photos"]
	var depuis := etapes.find(_seulement) if _seulement != "" else 0
	for k in range(maxi(depuis, 0), etapes.size()):
		print("== %s (%d s)" % [etapes[k], (Time.get_ticks_msec() - debut) / 1000])
		await Callable(self, "_mc_" + etapes[k]).call()
	_ecran._enregistrer()
	_rapport["duree_s"] = (Time.get_ticks_msec() - debut) / 1000
	var f := FileAccess.open(_dossier_mc.path_join("rapport.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_rapport, "\t"))
	f.close()
	print("RAPPORT ", JSON.stringify(_rapport))
	_rendre_les_reglages()
	quit(0)


# ── 1. LES TÉMOINS ─────────────────────────────────────────────────────────────────────────────────

func _mc_temoins() -> void:
	var t0 := Time.get_ticks_msec()
	var base: RefCounted = TL_.depuis_le_temoin_calcule(0.0)
	var b1 := F.subdiviser_tout(base, _niveau)
	var b2 := F.chanfreiner(base, _chanfrein)
	print("base : niveau %d, %d triangles, %s, %s (%d ms)" % [_niveau, F.triangles(base), b1, b2,
		Time.get_ticks_msec() - t0])
	_rapport["base"] = {"niveau": _niveau, "chanfrein": _chanfrein, "triangles_par_52_tuiles": F.triangles(base),
		"subdivision": b1, "chanfreinage": b2}
	_rapport["temoins"] = {}
	for i in THEMES.size():
		var th: Dictionary = THEMES[i]
		var t1 := Time.get_ticks_msec()
		var t: RefCounted = base.copie()
		var cles: Array = t.tuiles.keys()
		for c in cles:
			_relief(th["nom"], t.tuiles[c], c)
		var v: Dictionary = F.creer_variantes(t, CLES_VARIEES, 2, func(m: RefCounted, k: int) -> void:
			_relief_de_variante(th["nom"], m, k))
		var c: Dictionary = _ecran._couches[_couche[th["nom"]]]
		var dossier: String = _ecran._chemin_temoin_de(c).get_basename() + "_images"
		var k_sol := _materiau(t, th, "sol", dossier)
		var k_paroi := _materiau(t, th, "paroi", dossier)
		F.assigner_par_orientation(t, k_sol, k_paroi, 0.55)
		c["_temoin"] = t
		var raison: String = _ecran._enregistrer_temoin(c, true)
		print("%s : %d tuiles, %d triangles, variantes %s %s(%d ms)" % [th["nom"], t.tuiles.size(), F.triangles(t),
			v.keys(), ("⚠ " + raison + " ") if raison != "" else "", Time.get_ticks_msec() - t1])
		_rapport["temoins"][th["nom"]] = {"tuiles": t.tuiles.size(), "triangles": F.triangles(t), "ms": Time.get_ticks_msec() - t1}
		await _images(2)
	await _photo_des_temoins()


## LE DEDANS PROPRE À CHAQUE THÈME (les bords ne bougent pas). Un décalage par clé : deux clés n'ont pas les mêmes bosses.
func _relief(nom: String, m: RefCounted, cle: String) -> void:
	var h := hash(cle)
	var dec := Vector3(h % 97, (h / 97) % 89, (h / 9000) % 83) * 1.7
	match nom:
		"Meadow":
			F.bosseler(m, F.bruit(11, 2.2), 0.05, dec)
		"Forest":
			F.bosseler(m, F.bruit(12, 2.6), 0.07, dec)
		"Desert", "Beach":
			F.bosseler(m, F.bruit(13, 1.2, 2), 0.06, dec, false, Vector3.UP)
		"Snow":
			F.bosseler(m, F.bruit(14, 1.6, 2), 0.05, dec, true)
		"Mud":
			F.bosseler(m, F.bruit(15, 3.5), 0.04, dec)
		"Gravel":
			F.bosseler(m, F.bruit(16, 7.0, 2), 0.025, dec, true)
		"Scree":
			F.bosseler(m, F.bruit(17, 4.0), 0.11, dec, true)
		"Rock":
			F.bosseler(m, F.bruit(18, 3.2, 4), 0.1, dec, true)
		"Volcano":
			F.bosseler(m, F.bruit(19, 2.6, 4), 0.09, dec)
		"Ice":
			F.bosseler(m, F.bruit(20, 1.4, 1), 0.07, dec)
		"StoneWall":
			pass


## Le dedans d'une variante : une bosse ou un creux marqués (une butte, un rocher qui affleure, une brèche).
func _relief_de_variante(nom: String, m: RefCounted, k: int) -> void:
	var dec := Vector3(31.7 * k, 17.3 * k, 5.1 * k)
	var amp := 0.14 if nom in ["Rock", "Scree", "Volcano", "Ice"] else 0.1
	F.bosseler(m, F.bruit(200 + k + hash(nom) % 50, 2.0, 3), amp, dec, k == 1)


## Un matériau du témoin : l'image (et son ensemble PBR) copiée dans le projet, ramenée à TAILLE_TEXTURE.
func _materiau(t: RefCounted, th: Dictionary, quoi: String, dossier: String) -> int:
	var d: Array = th[quoi]
	var source: String = SPIRIT + str(d[0])
	var erreurs: Array = []
	var copie := Peinture_.copier_dans_le_projet(source, dossier, erreurs)
	if copie == "":
		push_warning("%s : %s introuvable (%s)" % [th["nom"], source, erreurs])
		copie = ""
	else:
		_reduire_le_dossier(copie.get_base_dir())
	t.materiaux.append({"nom": "%s_%s" % [str(th["nom"]).to_lower(), "ground" if quoi == "sol" else "wall"],
		"couleur": d[1], "rugosite": d[2], "metal": 0.0, "texture": copie, "echelle": 1.0, "projection": "boite"})
	return t.materiaux.size() - 1


## Les images d'un dossier copié (la couleur et ses cartes) ramenées à TAILLE_TEXTURE — une fois.
func _reduire_le_dossier(dossier: String) -> void:
	for f in DirAccess.get_files_at(dossier):
		if f.get_extension().to_lower() not in ["png", "jpg", "jpeg"]:
			continue
		var chemin := dossier.path_join(f)
		var img := Image.load_from_file(chemin)
		if img == null or img.get_width() <= TAILLE_TEXTURE:
			continue
		img.resize(TAILLE_TEXTURE, TAILLE_TEXTURE, Image.INTERPOLATE_LANCZOS)
		img.save_png(chemin)


func _photo_des_temoins() -> void:
	await _ecran._changer_d_atelier("witness")
	for th in THEMES:
		_ecran._activer(_couche[th["nom"]])
		await _images(30)
		_photo("temoin_%s" % str(th["nom"]).to_lower())


func _photo(nom: String) -> void:
	var im := root.get_texture().get_image()
	if im != null:
		im.save_png(_photos.path_join(nom + ".png"))
		print("  photo : %s" % _photos.path_join(nom + ".png"))


# ── 2. LE MONDE ────────────────────────────────────────────────────────────────────────────────────

const MER := 4
const RAYON_ILE := 70.0
const VOLCAN := Vector2(-46, 6)
const LAC_MONTAGNE := Vector2i(-12, -40)
const GLACIER := Vector2(26, -46)
const VILLAGE := Rect2i(-9, 2, 18, 14)
## Les pics du nord : (x, z, hauteur au-dessus de la plaine, rayon).
const PICS := [Vector4(-24, -46, 26, 18), Vector4(4, -52, 30, 20), Vector4(-42, -30, 16, 13), Vector4(14, -32, 16, 13),
	Vector4(44, -40, 20, 15), Vector4(-6, -30, 10, 10)]
const MESAS := [Vector2(40, -8), Vector2(52, 14), Vector2(34, 22)]

var _bruit := FastNoiseLite.new()
var _bruit_foret := FastNoiseLite.new()
var _h := {}       # Vector2i → hauteur du dessus (−1 : rien)
var _m := {}       # Vector2i → thème
var _mares: Array = []


func _mc_monde() -> void:
	await _ecran._changer_d_atelier("monde")
	var t0 := Time.get_ticks_msec()
	_relief_monde()
	var par := {}
	for th in THEMES:
		par[th["nom"]] = {}
	for k in _h:
		for y in range(0, int(_h[k]) + 1):
			par[_m[k]][Vector3i(k.x, y, k.y)] = true
	var total := 0
	_rapport["cases"] = {}
	for nom in par:
		_ecran._activer(_couche[nom])
		_ecran._appliquer({"poser": par[nom], "effacer": {}}, "Add")
		_rapport["cases"][nom] = (par[nom] as Dictionary).size()
		total += (par[nom] as Dictionary).size()
		print("couche %s : %d cases" % [nom, (par[nom] as Dictionary).size()])
		await _images(1)
	print("monde : %d colonnes, %d cases (%d ms)" % [_h.size(), total, Time.get_ticks_msec() - t0])
	_ecran._activer(_couche["Meadow"])
	await _ecran._reparer_les_diagonales(false)
	await _images(2)
	await _eau()
	await _transitions()
	if not _sans_feuillage:
		await _feuillage()
	_ecran._enregistrer()


func _relief_monde() -> void:
	_bruit.seed = 1609
	_bruit.frequency = 0.03
	_bruit.fractal_octaves = 4
	_bruit_foret.seed = 77
	_bruit_foret.frequency = 0.06
	var n := int(RAYON_ILE) + 8
	for x in range(-n, n + 1):
		for z in range(-n, n + 1):
			_colonne(x, z)
	# La rigole du lac de montagne : elle descend vers le sud, le lac déborde par elle (une chute à moins de quatre cases).
	for z in range(LAC_MONTAGNE.y + 3, LAC_MONTAGNE.y + 16):
		for dx in range(-1, 1):
			var k := Vector2i(LAC_MONTAGNE.x + dx, z)
			if _h.has(k):
				_h[k] = mini(_h[k], 19 - (z - LAC_MONTAGNE.y - 3) / 2)
	_le_village()
	_les_chemins()
	_sans_damier()


func _colonne(x: int, z: int) -> void:
	var k := Vector2i(x, z)
	var p := Vector2(x, z)
	var b := _bruit.get_noise_2d(x, z)
	var r := p.length() / RAYON_ILE + b * 0.15
	if r > 1.12:
		return
	var continu := (1.0 - r) * 18.0 + b * 3.0
	var h: int
	var m := "Meadow"
	if continu < 0.8:
		h = clampi(int(round(MER - 2 + continu * 2.0)), 0, MER - 1)
		m = "Beach"
	elif continu < 2.4:
		h = MER + 1
		m = "Beach"
	else:
		# Les terrasses de la prairie : deux cases par marche.
		h = MER + 2 + 2 * int(floor((continu - 2.4) / 3.2))
		if _bruit_foret.get_noise_2d(x, z) > 0.18 and z < 10:
			m = "Forest"
	# LE MARAIS (sud-ouest) : bas et plat, des mares.
	if x < -8 and z > 22 and m != "Beach":
		h = MER + 1
		m = "Mud"
		if _bruit_foret.get_noise_2d(x * 2.3, z * 2.3) > 0.32:
			h = MER
			_mares.append(k)
	# LE DÉSERT (est) : des dunes douces, et ses mesas de rocaille.
	if x > 22 and m != "Beach":
		var dune := sin(x * 0.22 + b * 2.0) * 1.6 + sin(z * 0.17) * 1.2
		h = MER + 3 + int(round(dune + 1.5))
		m = "Desert"
		for c in MESAS:
			var dm := p.distance_to(c) + b * 3.0
			if dm < 6.0:
				h = MER + 11
				m = "Scree"
			elif dm < 8.0:
				h = maxi(h, MER + 6)
				m = "Scree"
	# LES MONTAGNES (nord) : des pics de roche, la neige au-dessus de 25.
	if z < -14 and r < 1.02:
		var hm := 0.0
		for pic in PICS:
			var dp := p.distance_to(Vector2(pic.x, pic.y)) + b * 5.0
			if dp < pic.w:
				hm = maxf(hm, pic.z * pow(1.0 - dp / pic.w, 1.25))
		if hm > 0.5:
			var hh := MER + 2 + int(round(hm + b * 2.0))
			if hh > h:
				h = hh
				m = "Snow" if h >= 25 else "Rock"
	# LE GLACIER (nord-est) : un plateau de glace.
	var dg := p.distance_to(GLACIER) + b * 4.0
	if dg < 10.0:
		h = 20
		m = "Ice"
	elif dg < 12.0 and h < 22:
		h = 22
		m = "Snow"
	# LE LAC DE MONTAGNE : une cuvette, échancrée au sud.
	var dl := p.distance_to(Vector2(LAC_MONTAGNE))
	if dl < 3.5:
		h = 19
		m = "Rock"
	elif dl < 5.5:
		h = maxi(h, 21)
		m = "Rock"
	# LE VOLCAN (ouest) : un cône, un cratère de lave.
	var dv := p.distance_to(VOLCAN) + b * 2.0
	if dv < 20.0:
		var hv := MER + 3 + int(round((1.0 - dv / 20.0) * 24.0))
		if dv < 4.5:
			hv = MER + 20
		if hv >= h:
			h = hv
			m = "Volcano"
	_h[k] = h
	_m[k] = m


## LE VILLAGE MURÉ : la prairie aplanie, un rempart de pierre de deux cases (une porte au sud), une tour à chaque coin.
func _le_village() -> void:
	var sol: int = _h.get(Vector2i(VILLAGE.get_center()), MER + 6)
	for x in range(VILLAGE.position.x - 3, VILLAGE.end.x + 3):
		for z in range(VILLAGE.position.y - 3, VILLAGE.end.y + 3):
			_h[Vector2i(x, z)] = sol
			if _m.get(Vector2i(x, z), "") != "Gravel":
				_m[Vector2i(x, z)] = "Meadow"
	for x in range(VILLAGE.position.x, VILLAGE.end.x):
		for z in range(VILLAGE.position.y, VILLAGE.end.y):
			var bord := x == VILLAGE.position.x or x == VILLAGE.end.x - 1 or z == VILLAGE.position.y or z == VILLAGE.end.y - 1
			if bord and not (z == VILLAGE.end.y - 1 and absi(x) <= 1):
				_h[Vector2i(x, z)] = sol + 2
				_m[Vector2i(x, z)] = "StoneWall"
	for coin in [VILLAGE.position, Vector2i(VILLAGE.end.x - 3, VILLAGE.position.y),
			Vector2i(VILLAGE.position.x, VILLAGE.end.y - 3), VILLAGE.end - Vector2i(3, 3)]:
		for dx in 3:
			for dz in 3:
				_h[coin + Vector2i(dx, dz)] = sol + 4
				_m[coin + Vector2i(dx, dz)] = "StoneWall"
	# La place du village, pavée de gravier.
	for x in range(-3, 4):
		for z in range(6, 12):
			_m[Vector2i(x, z)] = "Gravel"


## LES CHEMINS DE GRAVIER : du village à la plage du sud, au désert, au pied du volcan, aux montagnes.
func _les_chemins() -> void:
	var porte := Vector2(0, VILLAGE.end.y)
	for fin in [Vector2(0, 62), Vector2(30, 6), Vector2(-28, 8), Vector2(-6, -20)]:
		var depart: Vector2 = porte if fin.y > 20 else Vector2(VILLAGE.get_center())
		var n := int(depart.distance_to(fin))
		for i in n + 1:
			var q := depart.lerp(fin, float(i) / n) + Vector2(sin(i * 0.25) * 2.0, 0)
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var k := Vector2i(int(round(q.x)) + dx, int(round(q.y)) + dz)
					if _h.has(k) and _m[k] in ["Meadow", "Forest", "Desert", "Beach"] and _h[k] > MER:
						if not Rect2i(VILLAGE.position, VILLAGE.size).has_point(k):
							_m[k] = "Gravel"


## Aucun contact par une arête (charte §2) : dans chaque carré de quatre colonnes, si une diagonale est plus haute que
## l'autre entière, la plus haute de l'autre monte jusqu'à elle.
func _sans_damier() -> void:
	var change := true
	var tours := 0
	while change and tours < 60:
		change = false
		tours += 1
		for k in _h.keys():
			var a: Vector2i = k
			var b: Vector2i = k + Vector2i(1, 0)
			var c: Vector2i = k + Vector2i(0, 1)
			var d: Vector2i = k + Vector2i(1, 1)
			var ha: int = _h.get(a, -1)
			var hb: int = _h.get(b, -1)
			var hc: int = _h.get(c, -1)
			var hd: int = _h.get(d, -1)
			for paire in [[ha, hd, b, c, hb, hc, a], [hb, hc, a, d, ha, hd, b]]:
				var bas: int = mini(paire[0], paire[1])
				var haut_autre: int = maxi(paire[4], paire[5])
				if bas > haut_autre:
					var cible: Vector2i = paire[2] if paire[4] >= paire[5] else paire[3]
					_h[cible] = bas
					_m[cible] = _m.get(paire[6], "Meadow")
					change = true
					break


## L'EAU par les clics de l'atelier Fluids : la mer, le lac de montagne (et sa rivière), le lac de lave, les mares du marais.
func _eau() -> void:
	await _ecran._changer_d_atelier("fluides")
	var large := Vector3i(int(RAYON_ILE) + 12, MER, 0)
	_ecran._eau_cliquee(large, MOUSE_BUTTON_LEFT)
	_ecran._eau_cliquee(large, MOUSE_BUTTON_LEFT)
	_ecran._eaux[_ecran._eau_active]["preset"] = "transparent"
	_ecran._eaux[_ecran._eau_active]["nom"] = "Sea"
	_ecran._eau_cliquee(Vector3i(LAC_MONTAGNE.x, _h[LAC_MONTAGNE] + 1, LAC_MONTAGNE.y), MOUSE_BUTTON_LEFT)
	_ecran._nouvelle_eau()
	_ecran._eaux[_ecran._eau_active]["preset"] = "lave"
	_ecran._eaux[_ecran._eau_active]["nom"] = "Lava"
	var cv := Vector2i(VOLCAN)
	_ecran._eau_cliquee(Vector3i(cv.x, _h[cv] + 1, cv.y), MOUSE_BUTTON_LEFT)
	_ecran._nouvelle_eau()
	_ecran._eaux[_ecran._eau_active]["preset"] = "marais"
	_ecran._eaux[_ecran._eau_active]["nom"] = "Swamp"
	var vues := {}
	for k in _mares:
		if vues.has(k) or _h.get(k, -1) != MER:
			continue
		# Une source par mare (la première case rencontrée) : le reste de la mare se remplit avec elle.
		var pile := [k]
		while not pile.is_empty():
			var q: Vector2i = pile.pop_back()
			if vues.has(q) or _h.get(q, -1) != MER:
				continue
			vues[q] = true
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				pile.append(q + d)
		_ecran._eau_cliquee(Vector3i(k.x, MER + 1, k.y), MOUSE_BUTTON_LEFT)
	await _ecran._recalculer_eau(false)
	_rapport["eau"] = {}
	for e in _ecran._eaux:
		_rapport["eau"][e["nom"]] = {"preset": e["preset"], "sources": (e["sources"] as Array).size()}
		print("eau %s (%s) : %d sources" % [e["nom"], e["preset"], (e["sources"] as Array).size()])
	await _ecran._changer_d_atelier("monde")


func _transitions() -> void:
	var allumees := 0
	for p in PAIRES:
		var ida := str(_ecran._couches[_couche[p[0]]]["id"])
		var idb := str(_ecran._couches[_couche[p[1]]]["id"])
		_ecran._transitions.allumer(TR_.cle_de_paire(ida, idb), true)
		allumees += 1
	_rapport["transitions"] = allumees
	print("transitions : %d paires" % allumees)
	await _images(5)


## LE FEUILLAGE : chaque modèle importé (la route du bouton « Import .glb… »), mis à la hauteur voulue, puis planté au
## clic (« Planted · free ») sur une part des colonnes de son thème — la caméra au-dessus de chaque plant, le clic là
## où la souris montre le dessus de la colonne.
func _feuillage() -> void:
	await _ecran._changer_d_atelier("feuillage")
	var af = _ecran._feuillage
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var par_theme := {}
	for k in _h:
		if not par_theme.has(_m[k]):
			par_theme[_m[k]] = []
		par_theme[_m[k]].append(k)
	_rapport["feuillage"] = {}
	var total := 0
	for nom in FEUILLAGE:
		for d in FEUILLAGE[nom]:
			var fichier: String = SPIRIT + str(d[0])
			if not FileAccess.file_exists(fichier):
				print("feuillage : %s absent, sauté" % fichier)
				continue
			var n0: int = af.modeles.size()
			_ecran._action_fichier = "feuillage"
			_ecran._fichier_choisi(fichier)
			if af.modeles.size() == n0:
				print("feuillage : %s refusé" % fichier)
				continue
			af.activer(af.modeles.size() - 1)
			var m: Dictionary = af.modele_actif()
			var haut := maxf(float(m["hauteur"]) + float(m["decalage"]), 0.01)
			af._regle("echelle", float(d[1]) / haut)
			af._choisir_mode("sol_libre")
			var poses := 0
			for k in par_theme.get(nom, []):
				if rng.randf() > float(d[2]) or int(_h[k]) <= MER:
					continue
				var dessus := Vector3(k.x + 0.5, int(_h[k]) + 1.0, k.y + 0.5)
				_poser_camera(dessus, 0.0, 1.45, 18.0)
				var ecran: Vector2 = _vue.camera().unproject_position(dessus + Vector3(rng.randf_range(-0.3, 0.3), 0,
					rng.randf_range(-0.3, 0.3)))
				var n1: int = af.plants.size()
				af.coup(ecran, MOUSE_BUTTON_LEFT, 0)
				af.coup(ecran, MOUSE_BUTTON_LEFT, 2)
				poses += af.plants.size() - n1
			total += poses
			_rapport["feuillage"][str(d[0]).get_file()] = poses
			print("feuillage %s : %s → %d plants" % [nom, str(d[0]).get_file(), poses])
			await _images(1)
	print("feuillage : %d plants en tout" % total)
	await _ecran._changer_d_atelier("monde")


# ── 3. LES PHOTOS ET LA MESURE ─────────────────────────────────────────────────────────────────────

const VUES := [
	["ensemble", Vector3(0, 8, 0), 0.7, 0.75, 150.0],
	["village", Vector3(0, 11, 9), 0.5, 0.45, 32.0],
	["volcan", Vector3(-46, 18, 6), 1.2, 0.42, 48.0],
	["desert", Vector3(40, 10, 8), -0.5, 0.38, 42.0],
	["montagnes", Vector3(0, 20, -38), 0.3, 0.4, 52.0],
	["glacier", Vector3(26, 22, -46), -0.9, 0.5, 30.0],
	["marais", Vector3(-30, 6, 38), 0.9, 0.42, 30.0],
	["plage", Vector3(8, 6, 58), 0.2, 0.3, 28.0],
	["foret", Vector3(-14, 10, -6), 0.4, 0.32, 26.0],
	["au_sol", Vector3(0, 10, 22), 3.14, 0.12, 14.0],
]


func _mc_photos() -> void:
	await _ecran._changer_d_atelier("monde")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _images(60)
	_rapport["vues"] = {}
	for v in VUES:
		_poser_camera(v[1], v[2], v[3], v[4])
		await _images(45)
		var t0 := Time.get_ticks_usec()
		var prims := 0
		var appels := 0
		var pire := 0
		var n := 90
		for i in n:
			var ti := Time.get_ticks_usec()
			await process_frame
			pire = maxi(pire, Time.get_ticks_usec() - ti)
			prims = maxi(prims, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
			appels = maxi(appels, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		var ips := n / ((Time.get_ticks_usec() - t0) / 1000000.0)
		_photo(v[0])
		_rapport["vues"][v[0]] = {"ips": snappedf(ips, 0.1), "pire_ms": snappedf(pire / 1000.0, 0.1),
			"primitives": prims, "appels": appels}
		print("vue %s : %.1f img/s (pire %.1f ms), %d primitives, %d appels" % [v[0], ips, pire / 1000.0, prims, appels])
	_rapport["memoire_video_mo"] = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
	_rapport["memoire_mo"] = int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
