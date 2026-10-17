extends "res://DEV_TOOLS/filmer_ui.gd"
##
## LA STATION SPATIALE — demandée par Jordan (17 octobre 2026) : « un projet entier nouveau comme celui de monde client,
## mais en sci-fi, dans la modélisation comme dans le texturing, avec une partie texture fixe, texture émissive et texture
## animée de très haute qualité, beaucoup de layers, une station spatiale riche ». Ses réponses : textures CC0 + calculées
## (`SpannerGames/PROJETS/MarchingBlocks/01_scripts/textures_station.py`), un projet NEUF à côté de « scifi », la musique
## seule pour les vidéos, le monde client reste l'exemple livré.
##
## Le chemin de `batir_monde_client.gd`, en sci-fi :
##   1. LES TÉMOINS — la même base (témoin calculé au cran neutre, subdivisé par lot, chanfreiné : `forge_temoins.gd`) ;
##      un témoin par couche, ses DEDANS retouchés en panneaux (creux, bossages : de la tôle, pas de la roche), deux
##      variantes voulues du sol, de la paroi et de la lèvre. Trois matériaux par couche (sol, mur, plafond par
##      l'orientation de la face), leurs ensembles PBR COPIÉS dans le projet, l'émission réglée par matériau, et les
##      ANIMÉES : séquences (plasma, écrans, hologramme), défilements (conduits, données), pulsations (lampes de culture,
##      gyrophares).
##   2. LA STATION — des modules à coque de DEUX cases (le thème dedans, la coque Hull dehors) : un hangar à ciel ouvert
##      (on y naît au Play test) et sa navette, la coursive centrale, le poste de commandement (baie vitrée, hologramme,
##      verrière), le labo, le réacteur (son cœur de plasma dans une fosse de liquide de refroidissement), l'hydroponie
##      sous verrière (plantes, rigoles d'eau), les quartiers, le belvédère de verre au bout ; dehors les ailes solaires,
##      l'antenne, les radiateurs. Puis les contacts par une arête réparés, l'eau, les transitions, le feuillage.
##   3. LES PHOTOS et LA MESURE (`perf` dans `rapport.json`).
##
## LANCEMENT (avec fenêtre, sur le PC : les textures et Spirit3D y sont) :
##   Godot_v4.7-stable_win64_console.exe --path <dépôt> --script res://DEV_TOOLS/batir_station.gd -- \
##       --dossier=C:/Users/jorda/Documents/MarchingBlocks/station [--niveau=1] [--seulement=temoins|monde|photos] [--refaire]
## ⚠ Ne pas l'interrompre : il rend `reglages.cfg` à la fin.

const F := preload("res://DEV_TOOLS/forge_temoins.gd")
const TL_ := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const Peinture_ := preload("res://addons/marchingblocks_core/peinture.gd")
const TR_ := preload("res://addons/marchingblocks_core/transitions.gd")
const Anim_ := preload("res://addons/marchingblocks_core/animation_materiau.gd")

const DOSSIER_DEFAUT := "C:/Users/jorda/Documents/MarchingBlocks/station"
const TEX := "D:/SpannerGames/BIBLIOTHEQUE/textures/station/"
const SPIRIT := "D:/Spirit3D/HEART_WORLD/biomes/maps/"

## Les couches, dans l'ORDRE DE PRIORITÉ. sol / mur / plafond : [matière sous TEX, force d'émission] ; « anim » : par
## matière, la piste animée (canal émission) — ["images", ips] (la séquence `<matière>_frames/`), ["defilement", u, v],
## ["pulsation", fréquence, mini] ; « relief » : le dedans des tuiles.
const THEMES := [
	{"nom": "Core", "sol": ["core", 6.0], "mur": ["core", 6.0], "plafond": ["core", 6.0], "relief": "lisse",
		"anim": {"core": ["images", 10.0]}},
	{"nom": "Holo", "sol": ["holo_floor", 5.0], "mur": ["command_floor", 3.0], "plafond": ["command_ceiling", 3.0],
		"relief": "lisse", "anim": {"holo_floor": ["images", 14.0]}},
	{"nom": "Command", "sol": ["command_floor", 3.0], "mur": ["command_screen", 5.0], "plafond": ["command_ceiling", 3.0],
		"relief": "panneaux", "anim": {"command_screen": ["images", 8.0]}},
	{"nom": "Datacore", "sol": ["deck_floor", 3.0], "mur": ["datacore", 5.0], "plafond": ["deck_ceiling", 3.0],
		"relief": "panneaux", "anim": {"datacore": ["defilement", 0.0, -0.12]}},
	{"nom": "Reactor", "sol": ["reactor_floor", 4.0], "mur": ["reactor_conduit", 5.0], "plafond": ["reactor_ceiling", 2.0],
		"relief": "panneaux", "anim": {"reactor_conduit": ["defilement", 0.0, 0.35]}},
	{"nom": "Lab", "sol": ["lab_floor", 2.0], "mur": ["lab_wall", 4.0], "plafond": ["lab_ceiling", 3.0], "relief": "carreaux"},
	{"nom": "Hydroponics", "sol": ["hydro_floor", 2.0], "mur": ["hydro_wall", 2.0], "plafond": ["hydro_ceiling", 4.0],
		"relief": "panneaux", "anim": {"hydro_ceiling": ["pulsation", 0.2, 0.85]}},
	{"nom": "Habitat", "sol": ["habitat_floor", 2.0], "mur": ["habitat_wall", 4.0], "plafond": ["lab_ceiling", 2.5],
		"relief": "carreaux"},
	{"nom": "Hangar", "sol": ["hangar_floor", 2.0], "mur": ["hangar_wall", 5.0], "plafond": ["hangar_ceiling", 2.0],
		"relief": "panneaux", "anim": {"hangar_wall": ["pulsation", 0.9, 0.45]}},
	{"nom": "Deck", "sol": ["deck_floor", 3.0], "mur": ["deck_wall", 4.0], "plafond": ["deck_ceiling", 3.0], "relief": "panneaux"},
	{"nom": "Solar", "sol": ["solar", 1.0], "mur": ["truss", 1.0], "plafond": ["solar", 1.0], "relief": "lisse"},
	{"nom": "Truss", "sol": ["truss", 1.0], "mur": ["truss", 1.0], "plafond": ["truss", 1.0], "relief": "lisse"},
	{"nom": "Hull", "sol": ["hull_top", 3.0], "mur": ["hull_wall", 4.0], "plafond": ["hull_under", 1.0], "relief": "coque"},
	# LE VERRE (comme le monde client) : un matériau sans image, son ALPHA dit la transparence. Le dernier.
	{"nom": "Glass", "verre": Color(0.62, 0.86, 1.0, 0.22), "rugosite": 0.03},
]

const CLES_VARIEES := ["mb_plaque_b4h0_dehors", "mb_plaque_b2h2_dehors", "mb_arete_b2h0_dehors", "mb_plaque_b4h0",
	"mb_plaque_b2h2"]

## LE FEUILLAGE de l'hydroponie : [fichier sous SPIRIT, hauteur voulue en cases].
const PLANTES := [["biome_jungle/obstacles/jungle_plant/jungle_plant.glb", 1.1],
	["biome_savanna/obstacles/savanna_grass_02/savanna_grass_02.glb", 0.8],
	["biome_plains/obstacles/plains_tree_02/plains_tree_02.glb", 3.2]]

## Les paires qui se fondent : le plasma qui déborde sur le sol du réacteur, la coursive et ses baies de données.
const PAIRES := [["Reactor", "Core"], ["Deck", "Datacore"], ["Deck", "Hangar"], ["Command", "Holo"]]

var _dossier_st := DOSSIER_DEFAUT
var _projet_st := ""
var _photos := ""
var _niveau := 1
var _chanfrein := 0.55
var _rapport := {}


func _initialize() -> void:
	var refaire := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seulement="):
			_seulement = a.substr("--seulement=".length())
		elif a.begins_with("--dossier="):
			_dossier_st = a.substr("--dossier=".length())
		elif a.begins_with("--niveau="):
			_niveau = int(a.substr("--niveau=".length()))
		elif a.begins_with("--chanfrein="):
			_chanfrein = float(a.substr("--chanfrein=".length()))
		elif a == "--refaire":
			refaire = true
	_projet_st = _dossier_st.path_join("station.mbproj")
	_photos = _dossier_st.path_join("photos")
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
	if FileAccess.file_exists(REGLAGES):
		DirAccess.copy_absolute(REGLAGES, SAUVEGARDE)
	if _seulement == "" or _seulement == "temoins":
		if FileAccess.file_exists(_projet_st) and not refaire:
			print("⚠ %s existe : relancer avec -- --refaire pour le refaire" % _projet_st)
			_rendre_les_reglages()
			quit(1)
			return
		_vider(_dossier_st)
		DirAccess.make_dir_recursive_absolute(_dossier_st)
		var couches := []
		for i in THEMES.size():
			var poids := {}
			if not THEMES[i].has("verre"):
				for c in CLES_VARIEES:
					poids[c] = [2, 1, 1]
			couches.append({"nom": THEMES[i]["nom"], "source": "", "visible": true, "cases": [], "temoin": "",
				"id": str(i + 1), "poids": poids, "choix": []})
		var f := FileAccess.open(_projet_st, FileAccess.WRITE)
		f.store_string(JSON.stringify({"format": "marchingblocks-project", "version": 3, "active": 0,
			"couches": couches, "eaux": [], "retrait": 0.0}, "\t"))
		f.close()
	DirAccess.make_dir_recursive_absolute(_photos)
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", _projet_st)
	r.set_value("projet", "monde", _projet_st)
	r.save(REGLAGES)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	Input.use_accumulated_input = false
	_derouler.call_deferred()


func _derouler() -> void:
	var debut := Time.get_ticks_msec()
	await _images(30)
	await _ecran._ouvrir(_projet_st)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	if _ecran._legende_formes != null:
		_ecran._legende_formes.basculer(false, false)
	var etapes := ["temoins", "monde", "photos"]
	var depuis := etapes.find(_seulement) if _seulement != "" else 0
	for k in range(maxi(depuis, 0), etapes.size()):
		print("== %s (%d s)" % [etapes[k], (Time.get_ticks_msec() - debut) / 1000])
		await Callable(self, "_st_" + etapes[k]).call()
	_ecran._enregistrer()
	_rapport["duree_s"] = (Time.get_ticks_msec() - debut) / 1000
	var f := FileAccess.open(_dossier_st.path_join("rapport.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_rapport, "\t"))
	f.close()
	print("RAPPORT ", JSON.stringify(_rapport))
	_rendre_les_reglages()
	quit(0)


# ── 1. LES TÉMOINS ─────────────────────────────────────────────────────────────────────────────────

func _st_temoins() -> void:
	var t0 := Time.get_ticks_msec()
	var base: RefCounted = TL_.depuis_le_temoin_calcule(0.0)
	var b1 := F.subdiviser_tout(base, _niveau)
	var b2 := F.chanfreiner(base, _chanfrein)
	print("base : niveau %d, chanfrein %.2f, %d triangles, %s, %s (%d ms)" % [_niveau, _chanfrein, F.triangles(base), b1,
		b2, Time.get_ticks_msec() - t0])
	_rapport["base"] = {"niveau": _niveau, "chanfrein": _chanfrein, "triangles_par_52_tuiles": F.triangles(base),
		"subdivision": b1, "chanfreinage": b2}
	_rapport["temoins"] = {}
	for i in THEMES.size():
		var th: Dictionary = THEMES[i]
		var t1 := Time.get_ticks_msec()
		var t: RefCounted = base.copie()
		var c: Dictionary = _ecran._couches[_couche[th["nom"]]]
		var v := {}
		if th.has("verre"):
			t.materiaux.append({"nom": "glass", "couleur": th["verre"], "rugosite": th["rugosite"], "metal": 0.0,
				"texture": "", "echelle": 1.0, "projection": "boite"})
			F.assigner_par_orientation(t, t.materiaux.size() - 1, t.materiaux.size() - 1, 0.55)
		else:
			for cle in t.tuiles.keys():
				_relief(th["relief"], t.tuiles[cle], cle)
			if th["relief"] != "lisse":
				v = F.creer_variantes(t, CLES_VARIEES, 2, func(m: RefCounted, k: int) -> void:
					_relief_de_variante(m, k))
			var dossier: String = _ecran._chemin_temoin_de(c).get_basename() + "_images"
			var ks := {}
			for role in ["sol", "mur", "plafond"]:
				var nom: String = th[role][0]
				if not ks.has(nom):
					ks[nom] = _materiau(t, th, nom, float(th[role][1]), dossier)
			F.assigner_par_orientation(t, ks[th["sol"][0]], ks[th["mur"][0]], 0.55, ks[th["plafond"][0]])
		c["_temoin"] = t
		var raison: String = _ecran._enregistrer_temoin(c, true)
		print("%s : %d tuiles, %d triangles, variantes %s %s(%d ms)" % [th["nom"], t.tuiles.size(), F.triangles(t),
			v.keys(), ("⚠ " + raison + " ") if raison != "" else "", Time.get_ticks_msec() - t1])
		_rapport["temoins"][th["nom"]] = {"tuiles": t.tuiles.size(), "triangles": F.triangles(t), "ms": Time.get_ticks_msec() - t1}
		await _images(2)
	await _photo_des_temoins()


## LE DEDANS : de la tôle. « panneaux » : un très léger bombé au cœur des faces (une plaque rivetée qui prend la lumière) ;
## « carreaux » : plat ; « coque » : un bossage plus franc (les plaques de blindage) ; « lisse » : rien.
func _relief(genre: String, m: RefCounted, cle: String) -> void:
	var h := hash(cle)
	var dec := Vector3(h % 97, (h / 97) % 89, (h / 9000) % 83) * 1.7
	match genre:
		"panneaux":
			F.bosseler(m, F.bruit(41, 0.9, 1), 0.018, dec, true)
		"coque":
			F.bosseler(m, F.bruit(42, 1.3, 1), 0.03, dec, true)


## Une variante : une plaque en CREUX (k = 1, une trappe, un évent) ou en BOSSAGE (k = 2, un caisson qui sort), au cœur.
func _relief_de_variante(m: RefCounted, k: int) -> void:
	F.retoucher_dedans(m, func(p: Vector3, n: Vector3) -> Vector3:
		var c := 1.0 - clampf(maxf(maxf(absf(p.x), absf(p.y)), absf(p.z)) / 0.5, 0.0, 1.0)
		var plateau := clampf((c - 0.25) / 0.2, 0.0, 1.0)
		return n * ((-0.06 if k == 1 else 0.05) * plateau), 0.12)


## Un matériau : l'ensemble PBR de la matière copié dans le projet ; ses facteurs laissent les cartes décider ; la force
## de l'émission ; et sa piste animée s'il en a une (la séquence copiée par la route de l'atelier Animation).
func _materiau(t: RefCounted, th: Dictionary, nom: String, emission: float, dossier: String) -> int:
	var source := TEX + nom + "/" + nom + "_albedo.png"
	var erreurs: Array = []
	var copie := Peinture_.copier_dans_le_projet(source, dossier, erreurs)
	if copie == "":
		push_warning("%s : %s introuvable (%s)" % [th["nom"], source, erreurs])
	var mat := {"nom": "%s_%s" % [str(th["nom"]).to_lower(), nom], "couleur": Color(1, 1, 1), "rugosite": 1.0,
		"metal": 1.0, "texture": copie, "echelle": 1.0, "projection": "boite", "emission": emission}
	var anim: Array = (th.get("anim", {}) as Dictionary).get(nom, [])
	if not anim.is_empty():
		var a := {}
		match str(anim[0]):
			"images":
				var dossier_images := TEX + nom + "_frames"
				var fichiers := PackedStringArray()
				for f in DirAccess.get_files_at(dossier_images):
					if f.get_extension().to_lower() == "png":
						fichiers.append(dossier_images.path_join(f))
				fichiers.sort()
				var r: Dictionary = Anim_.importer_sequence(fichiers, dossier.path_join("animation"),
					"%s_emission" % mat["nom"])
				if r.has("erreur"):
					push_warning("%s : séquence %s refusée (%s)" % [th["nom"], nom, r["erreur"]])
				else:
					a = Anim_.ajouter({}, "emission", "images", {"images": r["images"], "ips": float(anim[1])})
			"defilement":
				a = Anim_.ajouter({}, "emission", "defilement", {"u": float(anim[1]), "v": float(anim[2]), "synchro": true})
			"pulsation":
				a = Anim_.ajouter({}, "emission", "pulsation", {"frequence": float(anim[1]), "mini": float(anim[2])})
		if a.has("erreur"):
			push_warning("%s : piste %s refusée (%s)" % [th["nom"], nom, a["erreur"]])
		elif not a.is_empty():
			mat["animation"] = a
	t.materiaux.append(mat)
	return t.materiaux.size() - 1


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


# ── 2. LA STATION ──────────────────────────────────────────────────────────────────────────────────

## Les MODULES : [nom, couche, intérieur (lo, hi inclus), drapeaux]. Le sol marchable est à y = 0 (la case y = −1 est
## le plancher). « ouvert » : pas de toit (le hangar). Les couloirs traversent les coques des salles : ce sont les portes.
const MODULES := [
	["hangar", "Hangar", Vector3i(-56, 0, -12), Vector3i(-36, 8, 12), ["ouvert"]],
	["coursive", "Deck", Vector3i(-37, 0, -1), Vector3i(37, 2, 1), []],
	["commandement", "Command", Vector3i(-9, 0, -24), Vector3i(9, 5, -10), []],
	["acces_commandement", "Datacore", Vector3i(-1, 0, -11), Vector3i(1, 2, -1), []],
	["labo", "Lab", Vector3i(-30, 0, -20), Vector3i(-16, 4, -8), []],
	["acces_labo", "Deck", Vector3i(-24, 0, -9), Vector3i(-22, 2, -1), []],
	["reacteur", "Reactor", Vector3i(14, 0, -27), Vector3i(32, 9, -8), []],
	["acces_reacteur", "Deck", Vector3i(22, 0, -9), Vector3i(24, 2, -1), []],
	["hydroponie", "Hydroponics", Vector3i(-31, 0, 8), Vector3i(-15, 5, 24), []],
	["acces_hydroponie", "Deck", Vector3i(-24, 0, 1), Vector3i(-22, 2, 9), []],
	["quartiers", "Habitat", Vector3i(14, 0, 8), Vector3i(30, 3, 20), []],
	["acces_quartiers", "Deck", Vector3i(21, 0, 1), Vector3i(23, 2, 9), []],
	["belvedere", "Glass", Vector3i(38, 0, -7), Vector3i(48, 5, 7), []],
]
const COEUR := [Vector3i(22, -3, -19), Vector3i(24, 9, -17)]     # le pilier de plasma
const FOSSE := [Vector3i(18, -2, -23), Vector3i(28, -1, -13)]    # la fosse de refroidissement autour du cœur
const RIGOLES := [10, 16, 22]                                     # les z des rigoles d'eau de l'hydroponie
const PAD := Vector2(-42.5, 6.5)                                  # là où l'on naît, sur le sol du hangar

var _cases := {}       # Vector3i → couche
var _vides := {}       # Vector3i → vrai (l'air des modules)
var _rangs := {}       # Vector3i → 1 (paroi intérieure) ou 2 (coque) — la première l'emporte


func _st_monde() -> void:
	await _ecran._changer_d_atelier("monde")
	var t0 := Time.get_ticks_msec()
	_concevoir()
	var par := {}
	for th in THEMES:
		par[th["nom"]] = {}
	for c in _cases:
		par[_cases[c]][c] = true
	var total := 0
	_rapport["cases"] = {}
	for nom in par:
		_ecran._activer(_couche[nom])
		_ecran._appliquer({"poser": par[nom], "effacer": {}}, "Add")
		_rapport["cases"][nom] = (par[nom] as Dictionary).size()
		total += (par[nom] as Dictionary).size()
		print("couche %s : %d cases" % [nom, (par[nom] as Dictionary).size()])
		await _images(1)
	print("station : %d cases (%d ms)" % [total, Time.get_ticks_msec() - t0])
	_ecran._activer(_couche["Hull"])
	await _ecran._reparer_les_diagonales(false)
	await _images(2)
	await _eau()
	await _transitions()
	await _feuillage()
	_ecran._enregistrer()


func _poser(c: Vector3i, couche: String, rang := 0) -> void:
	if rang > 0 and _rangs.has(c) and int(_rangs[c]) <= rang:
		return
	_cases[c] = couche
	if rang > 0:
		_rangs[c] = rang


func _boite(lo: Vector3i, hi: Vector3i, couche: String) -> void:
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				_cases[Vector3i(x, y, z)] = couche


func _concevoir() -> void:
	_cases.clear()
	_vides.clear()
	_rangs.clear()
	# Les coques : la paroi intérieure au thème du module, la seconde peau en Hull — une paroi intérieure l'emporte
	# toujours sur une coque (deux modules qui se touchent gardent leurs murs à leur thème).
	for m in MODULES:
		var lo: Vector3i = m[2]
		var hi: Vector3i = m[3]
		var ouvert: bool = "ouvert" in m[4]
		for x in range(lo.x - 2, hi.x + 3):
			for y in range(lo.y - 2, hi.y + 3):
				for z in range(lo.z - 2, hi.z + 3):
					var c := Vector3i(x, y, z)
					if ouvert and y > hi.y:
						continue
					var d := maxi(maxi(maxi(lo.x - x, x - hi.x), maxi(lo.y - y, y - hi.y)), maxi(lo.z - z, z - hi.z))
					if d <= 0:
						continue
					# Le belvédère est une bulle : ses deux peaux sont de verre.
					_poser(c, m[1] if d == 1 or m[1] == "Glass" else "Hull", d)
	for m in MODULES:
		var lo: Vector3i = m[2]
		var hi: Vector3i = m[3]
		for x in range(lo.x, hi.x + 1):
			for y in range(lo.y, hi.y + 1):
				for z in range(lo.z, hi.z + 1):
					_vides[Vector3i(x, y, z)] = true
	for c in _vides:
		_cases.erase(c)
	# Le belvédère : un plancher de coursive sous sa bulle de verre.
	_boite(Vector3i(38, -1, -7), Vector3i(48, -1, 7), "Deck")
	_le_hangar()
	_le_commandement()
	_le_reacteur()
	_l_hydroponie()
	_les_quartiers()
	_les_hublots()
	_dehors()


## LE HANGAR : un pad d'atterrissage, une navette posée (coque, cockpit vitré, deux réacteurs), des caisses.
func _le_hangar() -> void:
	# La navette : un fuselage de 9 × 3 × 5, un cockpit de verre à l'avant (est), deux nacelles.
	_boite(Vector3i(-52, 0, -3), Vector3i(-44, 2, 1), "Hull")
	_boite(Vector3i(-44, 1, -2), Vector3i(-43, 2, 0), "Glass")
	_boite(Vector3i(-51, 0, -5), Vector3i(-47, 1, -5), "Hull")
	_boite(Vector3i(-51, 0, 3), Vector3i(-47, 1, 3), "Hull")
	_boite(Vector3i(-50, 3, -2), Vector3i(-46, 3, 0), "Truss")
	# Des caisses le long du mur nord.
	for i in 4:
		_boite(Vector3i(-54 + i * 4, 0, -11), Vector3i(-53 + i * 4, 1 + (i % 2), -10), "Truss")
	# Deux bras d'amarrage qui sortent du toit ouvert, de part et d'autre.
	for z in [-14, 14]:
		_boite(Vector3i(-50, 9, z), Vector3i(-40, 10, z), "Truss")
		_boite(Vector3i(-50, 11, z), Vector3i(-50, 14, z), "Truss")


## LE COMMANDEMENT : l'hologramme sur son socle, deux pupitres, la baie vitrée au nord, une verrière.
func _le_commandement() -> void:
	_boite(Vector3i(-1, 0, -18), Vector3i(1, 0, -16), "Holo")
	for x in [-6, 5]:
		_boite(Vector3i(x, 0, -21), Vector3i(x + 1, 0, -19), "Command")
	for x in range(-7, 8):
		for y in range(1, 5):
			for z in [-25, -26]:
				_cases[Vector3i(x, y, z)] = "Glass"
	for x in range(-4, 5):
		for z in range(-20, -13):
			for y in [6, 7]:
				_cases[Vector3i(x, y, z)] = "Glass"


## LE RÉACTEUR : le pilier de plasma, la fosse de refroidissement autour (une passerelle au sud y mène), des colonnes.
## ⚠ LA FOSSE EST SOUS UN PLANCHER DE VERRE (vu à l'image, 17 octobre 2026) : ouverte, le liquide débordait de son seuil et
## couvrait le sol jusqu'au hangar (la règle des lacs : un seuil près d'une chute, une rivière). Fermée, c'est une cavité
## close : le liquide reste dans sa rangée, sous le verre, et l'on marche au-dessus.
func _le_reacteur() -> void:
	for x in range(FOSSE[0].x, FOSSE[1].x + 1):
		for z in range(FOSSE[0].z, FOSSE[1].z + 1):
			var passerelle := x >= COEUR[0].x and x <= COEUR[1].x and z > COEUR[1].z
			for y in range(FOSSE[0].y, FOSSE[1].y + 1):
				var c := Vector3i(x, y, z)
				if not passerelle:
					_cases.erase(c)
			if not passerelle:
				_cases[Vector3i(x, FOSSE[1].y, z)] = "Glass"
				_cases[Vector3i(x, FOSSE[0].y - 1, z)] = "Reactor"
				_cases[Vector3i(x, FOSSE[0].y - 2, z)] = "Hull"
	# La fosse est plus large que le plancher à deux peaux : ses bords sont refermés par la coque.
	for x in range(FOSSE[0].x - 1, FOSSE[1].x + 2):
		for z in range(FOSSE[0].z - 1, FOSSE[1].z + 2):
			for y in range(FOSSE[0].y - 2, FOSSE[1].y + 1):
				var c := Vector3i(x, y, z)
				var dans := x >= FOSSE[0].x and x <= FOSSE[1].x and z >= FOSSE[0].z and z <= FOSSE[1].z
				if not dans and not _cases.has(c):
					_cases[c] = "Hull"
	_boite(COEUR[0], COEUR[1], "Core")
	for p in [Vector2i(15, -26), Vector2i(31, -26), Vector2i(15, -9), Vector2i(31, -9)]:
		_boite(Vector3i(p.x, 0, p.y), Vector3i(p.x, 9, p.y), "Reactor")


## L'HYDROPONIE : une verrière sur tout le toit, trois rigoles d'eau dans le sol, des bacs.
func _l_hydroponie() -> void:
	# Une BANDE de verrière au milieu ; le reste du plafond porte les lampes de culture (vu au tournage : tout en verre,
	# la salle était noire — le verre fait de l'ombre, et SDFGI éteint l'ambiante sous un toit).
	for x in range(-26, -19):
		for z in range(10, 23):
			for y in [6, 7]:
				_cases[Vector3i(x, y, z)] = "Glass"
	# ⚠ LES RIGOLES SONT COUVERTES DE VERRE (vu à l'image, 17 octobre 2026) : ouvertes, leur eau débordait et noyait le
	# hangar. Couvertes, chacune est une cavité close : l'eau en y = −2, le verre en y = −1, au ras du sol.
	for z in RIGOLES:
		for x in range(-29, -16):
			_cases[Vector3i(x, -1, z)] = "Glass"
			_cases.erase(Vector3i(x, -2, z))
			_cases[Vector3i(x, -3, z)] = "Hydroponics"
			_cases[Vector3i(x, -4, z)] = "Hull"
		for x in range(-30, -15):
			for dz in [-1, 0, 1]:
				for y in [-3, -4]:
					var c := Vector3i(x, y, z + dz)
					if not _cases.has(c):
						_cases[c] = "Hull"
		for y in [-1, -2, -3]:
			for x in [-30, -16]:
				_cases[Vector3i(x, y, z)] = "Hydroponics"


## LES QUARTIERS : des cloisons de cabines (trois cabines au sud), une table au milieu.
func _les_quartiers() -> void:
	for x in [19, 24]:
		_boite(Vector3i(x, 0, 14), Vector3i(x, 3, 20), "Habitat")
	_boite(Vector3i(20, 0, 10), Vector3i(23, 0, 11), "Truss")


## LES HUBLOTS : la coursive voit l'espace au sud, une fenêtre de trois cases toutes les huit.
func _les_hublots() -> void:
	for x in range(-30, 34, 8):
		if absi(x + 23) <= 3 or absi(x - 22) <= 3:
			continue
		for dx in range(0, 3):
			for z in [2, 3]:
				_cases[Vector3i(x + dx, 1, z)] = "Glass"


## DEHORS : les ailes solaires au nord et au sud, sur leurs poutres ; l'antenne sur le commandement ; les radiateurs du
## réacteur ; une ceinture de poutres le long de la coursive.
func _dehors() -> void:
	# L'aile nord : une poutre qui part du commandement, une traverse, des panneaux (des bandes de 7, un jour de 1).
	_boite(Vector3i(0, 4, -50), Vector3i(0, 4, -27), "Truss")
	_boite(Vector3i(-40, 4, -42), Vector3i(40, 4, -42), "Truss")
	for x0 in range(-40, 41, 8):
		for zs in [[-49, -43], [-41, -35]]:
			_boite(Vector3i(x0 + 1, 4, zs[0]), Vector3i(x0 + 7, 4, zs[1]), "Solar")
	# L'aile sud : une poutre sous la coursive, entre l'hydroponie et les quartiers.
	_boite(Vector3i(0, 1, 4), Vector3i(0, 1, 50), "Truss")
	_boite(Vector3i(-40, 1, 42), Vector3i(40, 1, 42), "Truss")
	for x0 in range(-40, 41, 8):
		for zs in [[35, 41], [43, 49]]:
			_boite(Vector3i(x0 + 1, 1, zs[0]), Vector3i(x0 + 7, 1, zs[1]), "Solar")
	# L'antenne : un mât sur le toit du commandement, une coupelle.
	_boite(Vector3i(6, 8, -14), Vector3i(6, 22, -14), "Truss")
	for x in range(3, 10):
		for z in range(-17, -10):
			if Vector2(x - 6, z + 14).length() <= 3.2:
				_cases[Vector3i(x, 22, z)] = "Truss"
	# Les radiateurs du réacteur : des ailettes sur son toit.
	for x in range(15, 32, 3):
		_boite(Vector3i(x, 12, -25), Vector3i(x, 16, -10), "Truss")


## L'EAU : le liquide de refroidissement (l'acide luminescent) dans la fosse, l'eau claire dans les rigoles.
func _eau() -> void:
	await _ecran._changer_d_atelier("fluides")
	_ecran._eaux[_ecran._eau_active]["preset"] = "acide"
	_ecran._eaux[_ecran._eau_active]["nom"] = "Coolant"
	_ecran._eau_cliquee(Vector3i(FOSSE[0].x, FOSSE[0].y, FOSSE[0].z), MOUSE_BUTTON_LEFT)
	_ecran._nouvelle_eau()
	_ecran._eaux[_ecran._eau_active]["preset"] = "transparent"
	_ecran._eaux[_ecran._eau_active]["nom"] = "Irrigation"
	for z in RIGOLES:
		_ecran._eau_cliquee(Vector3i(-23, -2, z), MOUSE_BUTTON_LEFT)
	await _ecran._recalculer_eau(false)
	_rapport["eau"] = {}
	for e in _ecran._eaux:
		_rapport["eau"][e["nom"]] = {"preset": e["preset"], "sources": (e["sources"] as Array).size()}
		print("eau %s (%s) : %d sources" % [e["nom"], e["preset"], (e["sources"] as Array).size()])
	await _ecran._changer_d_atelier("monde")


func _transitions() -> void:
	for p in PAIRES:
		var ida := str(_ecran._couches[_couche[p[0]]]["id"])
		var idb := str(_ecran._couches[_couche[p[1]]]["id"])
		_ecran._transitions.allumer(TR_.cle_de_paire(ida, idb), true)
	_rapport["transitions"] = PAIRES.size()
	await _images(5)


## LE FEUILLAGE : des rangées de plantes entre les rigoles de l'hydroponie. La verrière est CACHÉE le temps de planter
## (le clic vise ce qui se voit : sinon les plantes poussaient sur le verre).
func _feuillage() -> void:
	await _ecran._changer_d_atelier("feuillage")
	var af = _ecran._feuillage
	_ecran._montrer_couche(_couche["Glass"], false)
	await _images(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2027
	var total := 0
	_rapport["feuillage"] = {}
	for d in PLANTES:
		var fichier: String = SPIRIT + str(d[0])
		if not FileAccess.file_exists(fichier):
			print("feuillage : %s absent, sauté" % fichier)
			continue
		var n0: int = af.modeles.size()
		_ecran._action_fichier = "feuillage"
		_ecran._fichier_choisi(fichier)
		if af.modeles.size() == n0:
			continue
		af.activer(af.modeles.size() - 1)
		var m: Dictionary = af.modele_actif()
		var haut := maxf(float(m["hauteur"]) + float(m["decalage"]), 0.01)
		af._regle("echelle", float(d[1]) / haut)
		# « Planted · overflow » : la pente et l'eau seules comptent (la rangée régulière de l'hydroponie fait l'espacement).
		af._choisir_mode("sol_debord")
		var poses := 0
		for x in range(-29, -16):
			for z in range(9, 24):
				if z in RIGOLES or absi(x + 23) <= 1:
					continue
				var arbre: bool = float(d[1]) > 2.0
				if arbre and not (posmod(x, 6) == 1 and z in [13, 19]):
					continue
				if not arbre and rng.randf() > 0.35:
					continue
				var dessus := Vector3(x + 0.5, 0.0, z + 0.5)
				_poser_camera(dessus, 0.0, 1.45, 14.0)
				var ecran: Vector2 = _vue.camera().unproject_position(dessus + Vector3(rng.randf_range(-0.25, 0.25), 0,
					rng.randf_range(-0.25, 0.25)))
				var n1: int = af.plants.size()
				af.coup(ecran, MOUSE_BUTTON_LEFT, 0)
				af.coup(ecran, MOUSE_BUTTON_LEFT, 2)
				poses += af.plants.size() - n1
		total += poses
		_rapport["feuillage"][str(d[0]).get_file()] = poses
		print("feuillage %s → %d plants" % [str(d[0]).get_file(), poses])
		await _images(1)
	_ecran._montrer_couche(_couche["Glass"], true)
	print("feuillage : %d plants en tout" % total)
	await _ecran._changer_d_atelier("monde")


# ── 3. LES PHOTOS ET LA MESURE ─────────────────────────────────────────────────────────────────────

## [nom, œil, cible] — dehors puis dedans.
const VUES := [
	["ensemble", Vector3(70, 60, 85), Vector3(-4, 0, 0)],
	["ensemble_nord", Vector3(-40, 45, -95), Vector3(0, 2, -15)],
	["hangar", Vector3(-46, 22, 24), Vector3(-46, 0, 0)],
	["coursive", Vector3(-30, 1.4, 0), Vector3(10, 1.0, 0)],
	["commandement", Vector3(6, 3.5, -11), Vector3(-2, 1.5, -22)],
	["labo", Vector3(-17, 3, -9), Vector3(-26, 1, -18)],
	["reacteur", Vector3(16, 6, -10), Vector3(23, 2, -18)],
	["hydroponie", Vector3(-16, 4, 23), Vector3(-26, 0, 12)],
	["quartiers", Vector3(29, 2.5, 9), Vector3(18, 1, 18)],
	["belvedere", Vector3(40, 2, 6), Vector3(60, 2, -20)],
]


func _poser_oeil(oeil: Vector3, cible: Vector3) -> void:
	var d := oeil - cible
	_poser_camera(cible, atan2(d.x, d.z), asin(clampf(d.y / d.length(), -1.0, 1.0)), d.length())


func _st_photos() -> void:
	await _ecran._changer_d_atelier("monde")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _images(60)
	_rapport["vues"] = {}
	for v in VUES:
		_poser_oeil(v[1], v[2])
		await _images(45)
		var t0 := Time.get_ticks_usec()
		var prims := 0
		var appels := 0
		var n := 90
		for i in n:
			await process_frame
			prims = maxi(prims, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
			appels = maxi(appels, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		var ips := n / ((Time.get_ticks_usec() - t0) / 1000000.0)
		_photo(v[0])
		_rapport["vues"][v[0]] = {"ips": snappedf(ips, 0.1), "primitives": prims, "appels": appels}
		print("vue %s : %.1f img/s, %d primitives, %d appels" % [v[0], ips, prims, appels])
	_rapport["memoire_video_mo"] = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
