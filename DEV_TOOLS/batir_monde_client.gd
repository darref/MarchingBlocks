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
	# LE VERRE (16 octobre 2026, Jordan : « rajoute du verre à monde client ») : un matériau sans image, dont l'ALPHA dit
	# la transparence (`MaillageEdite.materiau_godot`). Le dernier : là où il touche la roche, c'est la roche qui pose.
	{"nom": "Glass", "verre": Color(0.7, 0.9, 1.0, 0.34), "rugosite": 0.04},
]

## Les clés qui reçoivent deux variantes (les plus posées d'un monde : le sol, la paroi, la lèvre de falaise), tirées 2 : 1 : 1.
const CLES_VARIEES := ["mb_plaque_b4h0_dehors", "mb_plaque_b2h2_dehors", "mb_arete_b2h0_dehors"]

## LE FEUILLAGE par thème : [fichier sous SPIRIT (ou chemin absolu), hauteur voulue en cases, part des colonnes du thème].
## ⚠ LES TROIS PLUS LOURDS SONT DES CC0 DEPUIS LE 18 OCTOBRE 2026 (Jordan : « remplacer les essences trop lourdes par des
## CC0 optimisés comme dans le monde cartoon », « seulement les plus lourds ») : l'arbre du marais (26 Mo, Tripo) →
## DeadTree_1 de Quaternius (2 Mo), le palmier (24 Mo) → tree_palmTall de Kenney (20 Ko), l'herbe de savane 01 (12 Mo)
## → Grass_Wispy_Tall de Quaternius (40 Ko). Allégés par `D:/SpannerGames/OUTILS/alleger_glb.py` (images ≤ 1024 px,
## une fois chacune) ; le projet en place a été changé par `OUTILS/remplacer_feuillage.py`, plants gardés.
const CC0 := "D:/SpannerGames/BIBLIOTHEQUE/modeles/cc0_optimises/"
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
		[CC0 + "tree_palmTall.glb", 6.0, 0.006]],
	"Mud": [[CC0 + "DeadTree_1.glb", 5.5, 0.02],
		[CC0 + "Grass_Wispy_Tall.glb", 0.8, 0.05]],
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
		var c: Dictionary = _ecran._couches[_couche[th["nom"]]]
		var v := {}
		if th.has("verre"):
			# Le verre : la base telle quelle (lisse, chanfreinée), sans variante, UN matériau translucide.
			t.materiaux.append({"nom": "glass", "couleur": th["verre"], "rugosite": th["rugosite"], "metal": 0.0,
				"texture": "", "echelle": 1.0, "projection": "boite"})
			F.assigner_par_orientation(t, t.materiaux.size() - 1, t.materiaux.size() - 1, 0.55)
		else:
			for cle in cles:
				_relief(th["nom"], t.tuiles[cle], cle)
			v = F.creer_variantes(t, CLES_VARIEES, 2, func(m: RefCounted, k: int) -> void:
				_relief_de_variante(th["nom"], m, k))
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
var _bas := {}     # Vector2i → bas de la colonne (absent : 0)
var _air := {}     # Vector3i → case creusée (le tunnel, la salle)
var _verre := {}   # Vector3i → case de verre (la couche « Glass »)
var _jonction := {}   # Vector3i → coque du tube en PIERRE (« StoneWall ») là où elle borde la terre (pas du verre)
var _axe_tunnel: Array = []   # l'axe du tunnel, points au centre des cases (Vector3)
var _grotte := {}       # Vector3i → thème du creux (les grottes ; ces cases sont aussi dans `_air`)
var _theme_case := {}   # Vector3i → thème d'une case PLEINE qui borde une grotte (sa paroi), à la place de celui de la colonne
var _trou_ciel := {}    # Vector2i → colonne dont le dessus est ouvert sur une grotte (le gouffre, la rampe) : pas de plant

## LE TUNNEL DE VERRE (16 octobre 2026, Jordan : « un tunnel commençant dehors, qui s'enfonce dans la mer puis dans le
## sol, traverse une grande salle et ressort dans l'île ») : il part d'un îlot au sud, plonge, file sous la mer dans un
## tube de verre posé sur un fond marin creusé pour lui, entre dans l'île sous la plage, traverse une salle sous la
## prairie (un puits de lumière en verre dans son plafond), puis remonte et débouche sur la prairie.
const TUNNEL_X := 14
const ILOT := Vector2(14, 108)
const ILOT_RAYON := 5.5
const FOND_MARIN := -7     # le dessus du fond marin, autour du tube
const BAS_PROFOND := -9    # le bas des colonnes de la bande du tunnel
const TUBE_Y := -4         # le milieu du tube sous la mer et sous l'île
const SALLE := [Vector3i(5, -5, 37), Vector3i(23, 3, 51)]   # le creux de la salle (coins inclus)
const PUITS := [Vector2i(10, 40), Vector2i(18, 48)]          # le puits de lumière (colonnes, coins inclus)


func _mc_monde() -> void:
	await _ecran._changer_d_atelier("monde")
	var t0 := Time.get_ticks_msec()
	_relief_monde()
	var par := {}
	for th in THEMES:
		par[th["nom"]] = {}
	for k in _h:
		for y in range(int(_bas.get(k, 0)), int(_h[k]) + 1):
			var c := Vector3i(k.x, y, k.y)
			if not _air.has(c) and not _verre.has(c) and not _jonction.has(c):
				par[_theme_case.get(c, _m[k])][c] = true
	par["Glass"] = _verre.duplicate()
	for c in _jonction:
		par["StoneWall"][c] = true
	# Quatre piliers de pierre dans la salle, du sol au plafond, de part et d'autre du passage.
	for px in [TUNNEL_X - 6, TUNNEL_X + 5]:
		for pz in [SALLE[0].z + 2, SALLE[1].z - 3]:
			for dx in 2:
				for dz in 2:
					for y in range(SALLE[0].y, SALLE[1].y + 1):
						par["StoneWall"][Vector3i(px + dx, y, pz + dz)] = true
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
	_le_fond_marin()
	_sans_damier()
	_le_tunnel()
	_les_grottes()


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
		var dune := sin(x * 0.16 + b * 2.0) * 0.9 + sin(z * 0.11) * 0.7
		h = MER + 3 + (1 if dune > 0.4 else 0)
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
			# EN CORNICHES : des falaises de trois cases et des replats — une pente d'une case par case n'est qu'un
			# escalier, que le chanfrein ne fond pas (une marche entière est dans l'occupation, charte §4).
			var hh := MER + 2 + 3 * int(floor((hm + b * 2.0) / 3.0))
			if hh > h:
				h = hh
				m = "Snow" if h >= 25 else "Rock"
	# LE GLACIER (nord-est) : un plateau de glace.
	var dg := p.distance_to(GLACIER) + b * 4.0
	if dg < 10.0:
		h = 20
		m = "Ice"
	elif dg < 11.5:
		h = 21
		m = "Snow"
	elif dg < 22.0:
		var hs := 21 - 3 * int(ceil((dg - 11.5) / 2.5))
		if hs > h:
			h = hs
			m = "Snow" if hs >= 15 else "Rock"
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
	if dv < 24.0:
		var hv := MER + 3 + 3 * int(floor((1.0 - dv / 24.0) * 22.0 / 3.0))
		if dv < 5.0:
			hv = MER + 18
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


## LE FOND MARIN DU TUNNEL : la bande du tunnel descend à BAS_PROFOND (la salle et le tube passent sous y = 0), un fond
## de sable à FOND_MARIN là où il n'y avait que la mer, et l'îlot de roche d'où part le tunnel.
func _le_fond_marin() -> void:
	for x in range(TUNNEL_X - 20, TUNNEL_X + 21):
		for z in range(-30, 119):
			var k := Vector2i(x, z)
			# ⚠ LE FOND DESCEND EN PENTE, la règle de la plage prolongée (`_colonne`) : posé à plat à FOND_MARIN, la plage
			# finissait en un MUR de sable de dix cases, vu sous la mer (photo `tunnel_sous_la_mer`, 16 octobre 2026).
			if not _h.has(k) or (int(_h[k]) < MER and _m[k] == "Beach"):
				if not _h.has(k) and z < 50:
					continue
				var b := _bruit.get_noise_2d(x, z)
				var continu := (1.0 - Vector2(x, z).length() / RAYON_ILE - b * 0.15) * 18.0 + b * 3.0
				_h[k] = clampi(int(round(MER - 2 + continu * 2.0)), FOND_MARIN, MER - 1)
				_m[k] = "Beach"
			_bas[k] = BAS_PROFOND
	for x in range(int(ILOT.x - ILOT_RAYON) - 1, int(ILOT.x + ILOT_RAYON) + 2):
		for z in range(int(ILOT.y - ILOT_RAYON) - 1, int(ILOT.y + ILOT_RAYON) + 2):
			if Vector2(x + 0.5, z + 0.5).distance_to(ILOT) < ILOT_RAYON:
				_h[Vector2i(x, z)] = MER + 2
				_m[Vector2i(x, z)] = "Rock"


func _plein_terrain(c: Vector3i) -> bool:
	var k := Vector2i(c.x, c.z)
	return _h.has(k) and c.y >= int(_bas.get(k, 0)) and c.y <= int(_h[k]) and not _air.has(c)


func _plein(c: Vector3i) -> bool:
	return _verre.has(c) or _jonction.has(c) or _plein_terrain(c)


func _dans_la_salle(c: Vector3i) -> bool:
	return c.x >= SALLE[0].x and c.x <= SALLE[1].x and c.y >= SALLE[0].y and c.y <= SALLE[1].y \
		and c.z >= SALLE[0].z and c.z <= SALLE[1].z


## La distance d'un point à l'axe du tunnel, ses deux BOUTS OUVERTS (au-delà du premier et du dernier point : rien).
func _distance_a_l_axe(p: Vector3) -> float:
	var d := INF
	for i in _axe_tunnel.size() - 1:
		var a: Vector3 = _axe_tunnel[i]
		var b: Vector3 = _axe_tunnel[i + 1]
		var ab := b - a
		var t := (p - a).dot(ab) / ab.length_squared()
		if (i == 0 and t < 0.0) or (i == _axe_tunnel.size() - 2 and t > 1.0):
			continue
		d = minf(d, p.distance_to(a + ab * clampf(t, 0.0, 1.0)))
	return d


func _le_tunnel() -> void:
	var x := TUNNEL_X + 0.5
	_axe_tunnel = [Vector3(x, 8.5, ILOT.y + ILOT_RAYON + 1.0), Vector3(x, 8.5, ILOT.y + 1.5),
		Vector3(x, TUBE_Y + 0.5, ILOT.y - 8.5), Vector3(x, TUBE_Y + 0.5, SALLE[0].z - 1.5)]
	# La remontée vers le nord, une case par deux, jusqu'à déboucher deux cases au-dessus de la prairie.
	var z := SALLE[0].z - 2
	var y := TUBE_Y
	while z > -20:
		z -= 2
		y += 1
		if y >= int(_h.get(Vector2i(TUNNEL_X, z), -99)) + 2 and y >= int(_h.get(Vector2i(TUNNEL_X, z - 1), -99)) + 2:
			break
	_axe_tunnel.append(Vector3(x, y + 0.5, z + 0.5))
	# La salle : son creux, et du verre là où sa coque ne serait pas dans la matière.
	for cx in range(SALLE[0].x, SALLE[1].x + 1):
		for cy in range(SALLE[0].y, SALLE[1].y + 1):
			for cz in range(SALLE[0].z, SALLE[1].z + 1):
				_air[Vector3i(cx, cy, cz)] = true
	for cx in range(SALLE[0].x - 1, SALLE[1].x + 2):
		for cy in range(SALLE[0].y - 1, SALLE[1].y + 2):
			for cz in range(SALLE[0].z - 1, SALLE[1].z + 2):
				var c := Vector3i(cx, cy, cz)
				if not _air.has(c) and not _plein_terrain(c):
					_verre[c] = true
	# Le tube : creux à 1,5 de l'axe, sa coque à 2,9 (le carré de 5 × 5 d'un tube droit), en verre hors de la matière.
	var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var hi := -lo
	for p in _axe_tunnel:
		lo = lo.min(Vector3i(floori(p.x), floori(p.y), floori(p.z)))
		hi = hi.max(Vector3i(floori(p.x), floori(p.y), floori(p.z)))
	for cx in range(lo.x - 3, hi.x + 4):
		for cy in range(lo.y - 3, hi.y + 4):
			for cz in range(lo.z - 3, hi.z + 4):
				var c := Vector3i(cx, cy, cz)
				if _dans_la_salle(c):
					continue
				var d := _distance_a_l_axe(Vector3(c) + Vector3(0.5, 0.5, 0.5))
				if d <= 1.5:
					_air[c] = true
					_verre.erase(c)
				elif d <= 2.9 and not _air.has(c) and not _plein_terrain(c):
					_verre[c] = true
	# LA JONCTION EN PIERRE (Jordan, 16 octobre 2026 : « la jonction extérieur intérieur en autre chose que du verre, afin
	# qu'on ne voie pas le décor à travers le verre, sous la map ») : la coque du tube qui n'est pas en pleine mer — à
	# moins de quatre colonnes d'une terre émergée (l'îlot, la côte, la prairie de la sortie) — est en mur de pierre.
	# Le verre ne reste que là où le tube file sous la mer, loin des terres.
	for c in _verre.keys():
		if _dans_la_salle_ou_sa_coque(c):
			continue
		var pres_de_la_terre := false
		for dx in range(-4, 5):
			for dz in range(-4, 5):
				if int(_h.get(Vector2i(c.x + dx, c.z + dz), -99)) >= MER:
					pres_de_la_terre = true
					break
			if pres_de_la_terre:
				break
		if pres_de_la_terre:
			_verre.erase(c)
			_jonction[c] = true
	# Le puits de lumière : la roche au-dessus de la salle devient du verre, jusqu'à la prairie.
	for cx in range(PUITS[0].x, PUITS[1].x + 1):
		for cz in range(PUITS[0].y, PUITS[1].y + 1):
			for cy in range(SALLE[1].y + 1, int(_h.get(Vector2i(cx, cz), 0)) + 1):
				_verre[Vector3i(cx, cy, cz)] = true
	var reparees := _sans_contact_autour(lo - Vector3i(4, 4, 4), hi + Vector3i(4, 4, 4))
	# (un vide comblé contre un contact par une arête, près des terres, est de la pierre lui aussi)
	for c in _verre.keys():
		if not _dans_la_salle_ou_sa_coque(c) and _jonction_voisine(c):
			_verre.erase(c)
			_jonction[c] = true
	reparees += _sans_contact_autour(SALLE[0] - Vector3i(3, 3, 3), Vector3i(SALLE[1].x, 16, SALLE[1].z) + Vector3i(3, 3, 3))
	print("tunnel : %d points d'axe, %d cases creusées, %d de verre, %d de pierre à la jonction, %d ajoutées contre les contacts par une arête, sortie en z = %d"
		% [_axe_tunnel.size(), _air.size(), _verre.size(), _jonction.size(), reparees, z])
	_rapport["tunnel"] = {"creusees": _air.size(), "verre": _verre.size(), "jonction": _jonction.size(), "reparees": reparees,
		"chemin": _axe_tunnel.map(func(p: Vector3) -> Array: return [p.x, p.y, p.z])}
	var f := FileAccess.open(_dossier_mc.path_join("tunnel.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"chemin": _rapport["tunnel"]["chemin"], "salle": [[SALLE[0].x, SALLE[0].y,
			SALLE[0].z], [SALLE[1].x, SALLE[1].y, SALLE[1].z]], "puits": [[PUITS[0].x, PUITS[0].y], [PUITS[1].x, PUITS[1].y]]}, "\t"))
		f.close()

# ── LES GROTTES SOUS L'ÎLE ──────────────────────────────────────────────────────────────────────────
## Demandé par Jordan (16 octobre 2026) : « le monde client comme exemple fourni dans le soft, en lui ajoutant un réseau
## de galeries et de grandes salles de toutes tailles et formes originales en dessous de l'île ». Huit salles, chacune sa
## forme et sa roche (la paroi prend le thème de la salle sur une case d'épaisseur : un sommet de la paroi n'a que des
## cases du creux et de cette couronne), reliées par des galeries qui serpentent (pente ≤ 1 pour 2, à pied) ; on y entre
## par un gouffre dans la prairie, par une rampe qui descend du désert, et par la salle du tunnel de verre.
## Tout est SOUS LE NIVEAU DE LA MER : la coque est fermée (colonnes approfondies autour du creux, aucun contact par une
## arête), sinon la mer s'y engouffrerait. Jamais à moins de trois cases du dessus (sauf le gouffre et la rampe), ni à
## moins de 3,5 de l'axe du tunnel.
const GROTTE_SALLES := [
	# [nom, forme, centre, rayons / taille, thème de la paroi]
	["cathedrale", "cathedrale", Vector3(-22, -6, 8), Vector3(10, 7, 9), "Rock"],
	["hypostyle", "hypostyle", Vector3(2, -6, -12), Vector3(11, 2.5, 7), "StoneWall"],
	["anneau", "tore", Vector3(30, -6, 0), Vector3(9, 2.6, 0), "Desert"],
	["spirale", "spirale", Vector3(-6, -10, 22), Vector3(6.5, 8, 12), "Rock"],
	["lentille", "lentille", Vector3(-10, -15, 42), Vector3(14, 3.5, 11), "Mud"],
	["geode", "geode", Vector3(36, -12, -28), Vector3(7, 7, 7), "Ice"],
	["chambre_de_lave", "ellipsoide", Vector3(-42, -9, 8), Vector3(7, 6, 9), "Volcano"],
	["arches", "arches", Vector3(-12, -12, -30), Vector3(13, 6, 9), "Scree"],
]
## Les galeries : l'axe passe à 1,5 au-dessus du sol (le creux va de l'axe − rayon à l'axe + rayon).
const GROTTE_GALERIES := [
	[Vector3(4, -3.5, 44), Vector3(-1, -3.5, 36), Vector3(-6, -4.5, 29)],          # salle du tunnel → spirale (haut)
	[Vector3(-6, -16.5, 22), Vector3(-12, -15, 16), Vector3(-18, -11.5, 11)],      # spirale (bas) → cathédrale
	[Vector3(-6, -16.5, 22), Vector3(-7, -16.5, 32)],                              # spirale (bas) → lentille
	[Vector3(-26, -11.5, 6), Vector3(-31, -12, 9), Vector3(-37, -12.5, 8)],        # cathédrale → chambre de lave
	[Vector3(-20, -11.5, 2), Vector3(-14, -9, -4), Vector3(-6, -6.5, -9)],         # cathédrale → hypostyle
	[Vector3(-4, -6.5, -17), Vector3(2, -8.5, -24), Vector3(-2, -11, -29)],        # hypostyle → arches
	[Vector3(12, -6.5, -8), Vector3(17, -6.5, -4), Vector3(22, -6.5, -2)],         # hypostyle → anneau
	[Vector3(33, -6.5, -8), Vector3(35, -8.5, -16), Vector3(36, -12, -23)],        # anneau → géode
	[Vector3(0, -13, -31), Vector3(14, -14, -35), Vector3(30, -15, -30)],          # arches → géode (la boucle)
]
const GROTTE_GOUFFRE := Vector3(-20, 15, 3.2)    # x, z, rayon : un gouffre de la prairie dans la cathédrale
const GROTTE_RAMPE := Vector3(30, -6.5, 9)        # le départ de la rampe, sur l'anneau ; elle monte vers le sud


func _les_grottes() -> void:
	var t0 := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var bruit := FastNoiseLite.new()
	bruit.seed = 99
	bruit.frequency = 0.12
	var creux := {}   # Vector3i → thème
	var plein := {}   # Vector3i → vrai : gardé plein dans une salle (pilier, arche, rampe, cristal)
	for g in GROTTE_GALERIES:
		_galerie(g, creux, bruit, "Rock")
	for sa in GROTTE_SALLES:
		_salle(sa, creux, plein, bruit, rng)
	# Le gouffre : de la cathédrale jusqu'au ciel.
	var gx := GROTTE_GOUFFRE
	for x in range(int(gx.x - gx.z) - 1, int(gx.x + gx.z) + 2):
		for z in range(int(gx.y - gx.z) - 1, int(gx.y + gx.z) + 2):
			var k := Vector2i(x, z)
			var rr := gx.z + bruit.get_noise_2d(x * 3.0, z * 3.0) * 0.8
			if not _h.has(k) or Vector2(x + 0.5, z + 0.5).distance_to(Vector2(gx.x, gx.y)) > rr:
				continue
			_trou_ciel[k] = true
			for y in range(-6, int(_h[k]) + 1):
				creux[Vector3i(x, y, z)] = "Rock"
	# La rampe : de l'anneau vers le sud, une case de haut pour deux de long, jusqu'au jour.
	var pts := [GROTTE_RAMPE]
	var p: Vector3 = GROTTE_RAMPE
	while p.z < 70:
		p += Vector3(0, 1, 2)
		pts.append(p)
		var k := Vector2i(floori(p.x), floori(p.z))
		if p.y - 1.5 >= int(_h.get(k, -99)) + 1:
			break
	_galerie(pts, creux, bruit, "Rock", true)
	# Le creux pris : jamais dans le tube, jamais hors de l'île.
	var pris := 0
	for c in creux:
		var k := Vector2i(c.x, c.z)
		if not _h.has(k) or plein.has(c):
			continue
		if _distance_a_l_axe(Vector3(c) + Vector3(0.5, 0.5, 0.5)) < 3.5:
			continue
		_air[c] = true
		_verre.erase(c)
		_jonction.erase(c)
		_grotte[c] = creux[c]
		pris += 1
	var poches := _reboucher_les_poches()
	# Les colonnes autour du creux descendent sous lui : la coque est fermée par en dessous et sur les côtés.
	var bas_du_creux := {}
	for c in _grotte:
		var k := Vector2i(c.x, c.z)
		bas_du_creux[k] = mini(int(bas_du_creux.get(k, c.y)), c.y)
	for k in bas_du_creux:
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				var q := Vector2i(k.x + dx, k.y + dz)
				if _h.has(q):
					_bas[q] = mini(int(_bas.get(q, 0)), int(bas_du_creux[k]) - 3)
	var reparees := _sans_contact_des_grottes()
	poches += _reboucher_les_poches()
	reparees += _sans_contact_des_grottes()
	# La paroi : la couronne d'une case autour du creux prend le thème de la salle (pas les trois cases du dessus).
	for c in _grotte:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					var q := Vector3i(c.x + dx, c.y + dy, c.z + dz)
					if _grotte.has(q) or not _plein_terrain(q) or q.y > int(_h[Vector2i(q.x, q.z)]) - 2:
						continue
					var deja: String = _theme_case.get(q, "")
					if deja == "" or deja == "Rock":
						_theme_case[q] = _grotte[c]
	print("grottes : %d salles, %d galeries, %d cases creusées, %d rebouchées contre les contacts par une arête, %d en poches isolées, %d de paroi (%d ms)"
		% [GROTTE_SALLES.size(), GROTTE_GALERIES.size() + 1, _grotte.size(), reparees, poches, _theme_case.size(),
		Time.get_ticks_msec() - t0])
	_rapport["grottes"] = {"salles": GROTTE_SALLES.map(func(sa: Array) -> String: return sa[0]),
		"creusees": _grotte.size(), "rebouchees": reparees, "poches": poches, "paroi": _theme_case.size()}


## Les POCHES : un morceau de creux qui ne rejoint ni le ciel ni la salle du tunnel par le vide (un reste de galerie coupé
## par un pilier, un trou entre deux cristaux) est rebouché — on ne livre pas de vide qu'aucun joueur n'atteindra.
func _reboucher_les_poches() -> int:
	var relie := {}
	var pile: Array = []
	for c in _grotte:
		var k := Vector2i(c.x, c.z)
		if _trou_ciel.has(k) or c.y >= int(_h.get(k, -99)) or (_air.has(c) and not _grotte.has(c)):
			pile.append(c)
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var q: Vector3i = c + d
			if not _grotte.has(q) and not _plein(q):
				pile.append(c)   # elle touche un vide qui n'est pas de la grotte : le tunnel, le ciel
	while not pile.is_empty():
		var c: Vector3i = pile.pop_back()
		if relie.has(c) or not _grotte.has(c):
			continue
		relie[c] = true
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			pile.append(c + d)
	var n := 0
	for c in _grotte.keys():
		if not relie.has(c):
			_grotte.erase(c)
			_air.erase(c)
			n += 1
	return n


## Une galerie : l'axe serpente un peu (un bruit de côté), le rayon respire entre 1,6 et 2,3, le creux est un peu plus
## large que haut (un sol à peu près plat). `ouvert` : elle a le droit de percer le dessus (la rampe).
func _galerie(points: Array, creux: Dictionary, bruit: FastNoiseLite, theme: String, ouvert := false) -> void:
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var n := maxi(int(a.distance_to(b) * 2.0), 1)
		var cote := Vector3(-(b - a).z, 0, (b - a).x).normalized()
		for j in n + 1:
			var t := float(j) / n
			var q := a.lerp(b, t)
			# Le serpentement s'éteint aux bouts (les galeries se raccordent pile à leurs salles).
			var s := sin(t * PI)
			q += cote * bruit.get_noise_3d(q.x, q.y, q.z) * 2.2 * s
			var rayon := 1.95 + bruit.get_noise_3d(q.z * 2.0, q.x * 2.0, 7.0) * 0.35
			_creuser_boule(q, rayon, creux, theme, ouvert)


func _creuser_boule(q: Vector3, rayon: float, creux: Dictionary, theme: String, ouvert: bool) -> void:
	for x in range(floori(q.x - rayon - 1), ceili(q.x + rayon + 1)):
		for y in range(floori(q.y - rayon), ceili(q.y + rayon + 1)):
			for z in range(floori(q.z - rayon - 1), ceili(q.z + rayon + 1)):
				var d := Vector3(x + 0.5 - q.x, (y + 0.5 - q.y) * 1.25, z + 0.5 - q.z)
				if d.length() > rayon:
					continue
				var c := Vector3i(x, y, z)
				if not ouvert and y > int(_h.get(Vector2i(x, z), -99)) - 3:
					continue
				if not creux.has(c):
					creux[c] = theme


## Une salle : sa forme, son thème ; ce qu'elle garde plein (piliers, arches, rampe, cristaux) va dans `plein`.
func _salle(sa: Array, creux: Dictionary, plein: Dictionary, bruit: FastNoiseLite, rng: RandomNumberGenerator) -> void:
	var forme: String = sa[1]
	var o: Vector3 = sa[2]
	var r: Vector3 = sa[3]
	var theme: String = sa[4]
	var etendue := Vector3(r.x, r.y, r.z)
	if forme == "tore":
		etendue = Vector3(r.x + r.y + 1, r.y + 1, r.x + r.y + 1)
	elif forme == "spirale":
		etendue = Vector3(r.x + 1, r.y, r.x + 1)
	var cristaux: Array = []
	if forme == "geode":
		for i in 26:
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			cristaux.append([o + dir * r.x, -dir, rng.randf_range(2.5, 4.5)])
	var stalactites: Array = []
	if forme == "cathedrale":
		for i in 14:
			var ang := rng.randf() * TAU
			var rad := rng.randf_range(2.5, 7.5)
			stalactites.append([Vector2(o.x + cos(ang) * rad, o.z + sin(ang) * rad), rng.randf_range(2.0, 4.5)])
	for x in range(floori(o.x - etendue.x) - 1, ceili(o.x + etendue.x) + 2):
		for y in range(floori(o.y - etendue.y) - 1, ceili(o.y + etendue.y) + 2):
			for z in range(floori(o.z - etendue.z) - 1, ceili(o.z + etendue.z) + 2):
				var c := Vector3i(x, y, z)
				var p := Vector3(x + 0.5, y + 0.5, z + 0.5)
				var n := bruit.get_noise_3d(p.x, p.y, p.z)
				var d := p - o
				var dedans := false
				var garde := false
				match forme:
					"ellipsoide", "geode", "cathedrale", "arches":
						dedans = (d / r).length() <= 1.0 + n * 0.18
					"lentille":
						# Une lentille plate, au sol bosselé.
						var e := Vector3(d.x / r.x, d.y / r.y, d.z / r.z)
						dedans = e.length() <= 1.0 + n * 0.2 and d.y > -r.y + 1.0 + maxf(n, 0.0) * 2.0
					"hypostyle":
						# Un plan en super-ellipse, plafond plat, des piliers carrés tous les cinq.
						var sx := absf(d.x) / r.x
						var sz := absf(d.z) / r.z
						dedans = pow(sx, 4) + pow(sz, 4) <= 1.0 and d.y >= -r.y and d.y < r.y
						garde = dedans and posmod(x - int(o.x) + 1, 5) < 2 and posmod(z - int(o.z) + 1, 5) < 2 \
							and pow(sx, 4) + pow(sz, 4) < 0.8
					"tore":
						var rh := Vector2(d.x, d.z).length() - r.x
						dedans = Vector2(rh, d.y).length() <= r.y + n * 0.4
					"spirale":
						# Un puits rond, un pilier au centre, une rampe hélicoïdale contre la paroi : douze cases par tour.
						var rad := Vector2(d.x, d.z).length()
						dedans = rad <= r.x + n * 0.5 and absf(d.y) <= r.y
						if dedans and rad <= 1.6:
							garde = true
						elif dedans and rad >= 3.2:
							var ang := fposmod(atan2(d.z, d.x), TAU)
							var hy := (o.y - r.y) + ang / TAU * r.z
							var e := fposmod(p.y - hy, r.z)
							garde = e > r.z - 1.0 and p.y > o.y - r.y + 0.5
				if forme == "cathedrale" and dedans:
					# Le pilier du milieu, du sol à la voûte, et des stalactites qui pendent de la voûte.
					if Vector2(d.x, d.z).length() <= 1.7 + n:
						garde = true
					for st in stalactites:
						var hz: float = (o.y + r.y * 0.75) - p.y
						var rs: float = 0.9 * (1.0 - hz / float(st[1]))
						if hz >= 0.0 and hz <= st[1] and Vector2(p.x, p.z).distance_to(st[0]) <= rs + 0.3:
							garde = true
				if forme == "arches" and dedans:
					# Trois arches de pierre qui traversent la salle d'est en ouest.
					for i in 3:
						var az := o.z - 5.0 + i * 5.0
						var ay := o.y + 2.0 - pow(d.x / r.x, 2) * 5.0 - i * 1.0
						if Vector2(p.y - ay, p.z - az).length() <= 1.15:
							garde = true
				if forme == "geode" and dedans:
					for cr in cristaux:
						var base: Vector3 = cr[0]
						var dir: Vector3 = cr[1]
						var t := (p - base).dot(dir)
						if t >= 0.0 and t <= cr[2] and (p - base - dir * t).length() <= 1.1 * (1.0 - t / cr[2]) + 0.35:
							garde = true
				if not dedans:
					continue
				if y > int(_h.get(Vector2i(x, z), -99)) - 3:
					continue
				if garde:
					plein[c] = true
					creux.erase(c)
				else:
					creux[c] = theme


## Aucun contact par une arête autour des grottes (charte §2) : dans un carré de quatre cases à deux pleines en
## diagonale, une des deux vides de la grotte est REBOUCHÉE (de la roche, pas du verre : on est sous terre).
func _sans_contact_des_grottes() -> int:
	var plans := [[Vector3i(1, 0, 0), Vector3i(0, 1, 0)], [Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
		[Vector3i(0, 1, 0), Vector3i(0, 0, 1)]]
	var a_voir := {}
	for c in _grotte:
		for pl in plans:
			for u in [Vector3i.ZERO, -pl[0]]:
				for v in [Vector3i.ZERO, -pl[1]]:
					a_voir[[c + u + v, pl]] = true
	var total := 0
	for tour in 40:
		var suivants := {}
		for cle in a_voir:
			var a: Vector3i = cle[0]
			var pl: Array = cle[1]
			var b: Vector3i = a + pl[0]
			var d: Vector3i = a + pl[1]
			var e: Vector3i = a + pl[0] + pl[1]
			var pa := _plein(a)
			if pa != _plein(e) or _plein(b) != _plein(d) or pa == _plein(b):
				continue
			var vides: Array = [b, d] if pa else [a, e]
			var choix := Vector3i(1 << 20, 0, 0)
			for vv in vides:
				if _grotte.has(vv):
					choix = vv
					break
			if choix.x == 1 << 20:
				continue
			_grotte.erase(choix)
			_air.erase(choix)
			_bas[Vector2i(choix.x, choix.z)] = mini(int(_bas.get(Vector2i(choix.x, choix.z), 0)), choix.y)
			total += 1
			for pl2 in plans:
				for u in [Vector3i.ZERO, -pl2[0]]:
					for v in [Vector3i.ZERO, -pl2[1]]:
						suivants[[choix + u + v, pl2]] = true
		if suivants.is_empty():
			break
		a_voir = suivants
	return total


func _dans_la_salle_ou_sa_coque(c: Vector3i) -> bool:
	return c.x >= SALLE[0].x - 1 and c.x <= SALLE[1].x + 1 and c.y >= SALLE[0].y - 1 and c.z >= SALLE[0].z - 1 \
		and c.z <= SALLE[1].z + 1


func _jonction_voisine(c: Vector3i) -> bool:
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if _jonction.has(c + d):
			return true
	return false


## Aucun contact par une arête dans une boîte (charte §2) : dans chaque carré de quatre cases des trois plans, deux pleines
## en diagonale et deux vides, une des vides devient du verre (pas une case du creux, si l'autre ne l'est pas).
func _sans_contact_autour(lo: Vector3i, hi: Vector3i) -> int:
	var ajoutees := 0
	var plans := [[Vector3i(1, 0, 0), Vector3i(0, 1, 0)], [Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
		[Vector3i(0, 1, 0), Vector3i(0, 0, 1)]]
	for tour in 30:
		var change := 0
		for cx in range(lo.x, hi.x):
			for cy in range(lo.y, hi.y):
				for cz in range(lo.z, hi.z):
					var a := Vector3i(cx, cy, cz)
					for pl in plans:
						var b: Vector3i = a + pl[0]
						var d: Vector3i = a + pl[1]
						var e: Vector3i = a + pl[0] + pl[1]
						var pa := _plein(a)
						if pa != _plein(e) or _plein(b) != _plein(d) or pa == _plein(b):
							continue
						var vides: Array = [b, d] if pa else [a, e]
						var choix: Vector3i = vides[1] if _air.has(vides[0]) and not _air.has(vides[1]) else vides[0]
						_air.erase(choix)
						_verre[choix] = true
						change += 1
		ajoutees += change
		if change == 0:
			break
	return ajoutees


## La caméra à l'ŒIL donné, qui regarde `cible` (le modèle d'orbite de la vue : cible, azimut, élévation, distance).
func _poser_oeil(oeil: Vector3, cible: Vector3) -> void:
	var d := oeil - cible
	_poser_camera(cible, atan2(d.x, d.z), asin(clampf(d.y / d.length(), -1.0, 1.0)), d.length())


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
			var fichier: String = str(d[0]) if str(d[0]).is_absolute_path() else SPIRIT + str(d[0])
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
				# Rien sur l'îlot du tunnel : un plant y tiendrait sur le verre, ou flotterait au-dessus du creux.
				if Vector2(k).distance_to(ILOT) < ILOT_RAYON + 1.5 or _trou_ciel.has(k):
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

## Les plans : [nom, thème dont on vise le centre (ou "" : la position donnée), position, azimut, élévation, distance].
## La cible est posée sur le DESSUS du relief (sinon une caméra fixée à la main finit sous une terrasse — vu).
const VUES := [
	["ensemble", "", Vector2(0, 0), 0.7, 0.75, 150.0],
	["village", "StoneWall", Vector2.ZERO, 0.5, 0.45, 32.0],
	["volcan", "Volcano", Vector2.ZERO, 1.2, 0.42, 52.0],
	["desert", "Scree", Vector2.ZERO, -0.5, 0.38, 42.0],
	["montagnes", "Rock", Vector2.ZERO, 0.3, 0.4, 56.0],
	["glacier", "Ice", Vector2.ZERO, -0.9, 0.55, 34.0],
	["marais", "Mud", Vector2.ZERO, 0.9, 0.42, 30.0],
	["plage", "", Vector2(6, 60), 0.2, 0.3, 26.0],
	["foret", "Forest", Vector2.ZERO, 0.4, 0.35, 24.0],
	["au_sol", "", Vector2(0, 30), 0.0, 0.1, 12.0],
]


## La cible d'un plan : le centre des colonnes du thème (ou la position), sur le dessus du relief.
func _cible(theme: String, pos: Vector2) -> Vector3:
	var c := pos
	if theme != "":
		var somme := Vector2.ZERO
		var n := 0
		for k in _m:
			if _m[k] == theme:
				somme += Vector2(k)
				n += 1
		if n > 0:
			c = somme / n
	var k := Vector2i(int(round(c.x)), int(round(c.y)))
	return Vector3(c.x + 0.5, float(_h.get(k, MER)) + 1.5, c.y + 0.5)


func _mc_photos() -> void:
	await _ecran._changer_d_atelier("monde")
	if _h.is_empty():
		_relief_monde()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _images(60)
	_rapport["vues"] = {}
	for v in VUES:
		_poser_camera(_cible(v[1], v[2]), v[3], v[4], v[5])
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
	# LE TUNNEL DE VERRE : l'entrée sur l'îlot, le tube sous la mer, la salle et son puits de lumière, la sortie.
	var x := TUNNEL_X + 0.5
	for v in [["tunnel_entree", Vector3(x + 7, 13, 126), Vector3(x, 8.5, 112)],
			["tunnel_sous_la_mer", Vector3(x, TUBE_Y + 0.6, 94), Vector3(x + 2.5, TUBE_Y + 1.6, 84)],
			["tunnel_salle", Vector3(x - 6, 1.5, SALLE[1].z - 1.0), Vector3(x + 2, -3.0, SALLE[0].z + 3.0)],
			["tunnel_sortie", Vector3(x + 9, 22, (_axe_tunnel.back() as Vector3).z - 12), _axe_tunnel.back()],
			["grotte_cathedrale", Vector3(-28, -7, 14), Vector3(-20, -9, 4)],
			["grotte_hypostyle", Vector3(-6, -6, -7), Vector3(8, -7, -16)],
			["grotte_spirale", Vector3(-6, -3, 22), Vector3(-3, -15, 20)],
			["grotte_geode", Vector3(33, -13, -24), Vector3(38, -12, -31)],
			["grotte_arches", Vector3(-22, -11, -27), Vector3(-4, -12, -30)],
			["grotte_anneau", Vector3(22, -6, -1), Vector3(29, -6, -9)],
			["grotte_gouffre", Vector3(-28, 16, 22), Vector3(-20, 0, 15)]]:
		_poser_oeil(v[1], v[2])
		await _images(45)
		_photo(v[0])
	_rapport["memoire_video_mo"] = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
	_rapport["memoire_mo"] = int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
