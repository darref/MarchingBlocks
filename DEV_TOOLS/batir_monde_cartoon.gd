extends "res://DEV_TOOLS/filmer_ui.gd"
##
## LE MONDE CARTOON — demandé par Jordan (18 octobre 2026) : « un monde avec autant voire plus de matières différentes que
## monde client, mais avec un style chanfreiné et relief simple, sauf des petits morceaux de reliefs sculptés qui sortent
## bien du lot et donnent un aspect caractéristique à chaque matière, et surtout de la peinture handpainted, c'est-à-dire
## pas de texture toute prête, plutôt un aspect cartoon minimaliste genre Pokémon, dans une grande map carrée avec un réseau
## souterrain large et des reliefs qui sortent de la heightmap en surface — quelques arches, corridors, enfoncements dans
## des falaises —, sinon globalement comme le monde client au niveau du style », puis « ne mets pas de motif répétitif sur
## toutes les textures, il faut certaines avec la majorité de couleur unie ou presque ».
##
## Un projet NEUF (`Documents/MarchingBlocks/monde_cartoon/`), bâti par le logiciel lui-même, comme le monde client :
##   1. LES TÉMOINS — la base commune du monde client (subdivisée au niveau 1, chanfreinée), puis, par matière, un DEDANS
##      retouché à sa manière (coussins d'herbe, rides de sable, facettes de roche, strates de canyon, craquelures de lave,
##      pointes de cristal…), et des VARIANTES rares (poids 6 : 1 : 1) qui portent UN morceau sculpté franc — une butte, un
##      rocher qui sort de la paroi, une corniche, une pointe de glace, une bouche de lave —, sur le sol, la paroi et la
##      lèvre de falaise à l'air libre, et sur le sol et la paroi sous roche (les grottes). Deux matériaux par matière (sol,
##      paroi), PEINTS par `SpannerGames/PROJETS/MarchingBlocks/01_scripts/textures_cartoon.py` (rien de téléchargé).
##   2. LE MONDE — une île CARRÉE de 160 × 160 colonnes en terrasses de trois cases : la prairie fleurie et son bourg pavé au
##      centre, la forêt et le bois d'automne au nord-ouest, les montagnes (roche, neige, lac de glace) au nord-est, le canyon
##      rouge à l'est, le désert au sud-est, le marais au sud-ouest, le volcan à l'ouest, les plages tout autour. Par-dessus
##      la heightmap : des ARCHES (prairie, canyon, une arche de mer), un CORRIDOR qui traverse la montagne, des ALCÔVES
##      creusées au pied des falaises, et sous l'île un RÉSEAU de galeries larges (six cases) et de salles — cristal,
##      champignons, une salle à piliers, une grande caverne sous la montagne — où l'on entre par des alcôves. L'eau (mer,
##      lac, lave, marais — pas de rivière, voir `_eau`), les transitions entre matières voisines, le feuillage CC0 (`FEUILLAGE`).
##   3. LES PHOTOS et LA MESURE (images par seconde, primitives, appels), dans `perf` du rapport.
##
## LANCEMENT (avec fenêtre, sur le PC) :
##   Godot_v4.7-stable_win64_console.exe --path <dépôt> --script res://DEV_TOOLS/batir_monde_cartoon.gd -- \
##       [--dossier=<dossier>] [--niveau=1] [--sans-feuillage] [--seulement=temoins|monde|photos] [--refaire]
## ⚠ Ne pas l'interrompre : il rend `reglages.cfg` à la fin.

const F := preload("res://DEV_TOOLS/forge_temoins.gd")
const MC := preload("res://DEV_TOOLS/modeles_cartoon.gd")
const TL_ := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const Peinture_ := preload("res://addons/marchingblocks_core/peinture.gd")
const TR_ := preload("res://addons/marchingblocks_core/transitions.gd")

const DOSSIER_DEFAUT := "C:/Users/jorda/Documents/MarchingBlocks/monde_cartoon"
const PEINT := "D:/SpannerGames/BIBLIOTHEQUE/textures/cartoon/"

## Les dix-sept matières, dans l'ordre de priorité des couches. [nom, image peinte, force de l'émission (0 : rien)].
## ⚠ LES TROIS MATIÈRES SOUTERRAINES EN TÊTE : un sommet est posé par la couche de plus petit rang parmi ses huit cases
## (charte §5) ; derrière l'herbe, le plafond d'une galerie qui touche une case d'herbe était posé par l'herbe — des
## morceaux de berge pendaient sous terre (vu à l'image). Leurs cases ne sont que sous terre : en tête, elles ne prennent
## rien à la surface.
const THEMES := [
	["Crystal", "crystal", 1.6], ["Mushroom", "mushroom", 1.6], ["Cavern", "cavern", 0.0],
	["Cobble", "cobble", 0.0], ["Path", "path", 0.0], ["Flowers", "flowers", 0.0], ["Grass", "grass", 0.0],
	["Autumn", "autumn", 0.0], ["Forest", "forest", 0.0], ["Sand", "sand", 0.0], ["Beach", "beach", 0.0],
	["Canyon", "canyon", 0.0], ["Mud", "mud", 0.0], ["Snow", "snow", 0.0], ["Ice", "ice", 0.0], ["Rock", "rock", 0.0],
	["Volcano", "volcano", 2.2],
]

## Les clés qui reçoivent deux variantes : le sol, la paroi et la lèvre à l'air libre ; le sol et la paroi sous roche.
const CLES_VARIEES := ["mb_plaque_b4h0_dehors", "mb_plaque_b2h2_dehors", "mb_arete_b2h0_dehors", "mb_plaque_b4h0",
	"mb_plaque_b2h2"]
const POIDS_VARIANTES := [6, 1, 1]

## LE FEUILLAGE par matière (Jordan, 18 octobre 2026 : « trouver du foliage CC0 de haute qualité et pas trop lourd pour en
## mettre beaucoup ») : deux packs CC0 rangés dans `SpannerGames/BIBLIOTHEQUE/modeles/` — le Stylized Nature MegaKit
## [Standard] de Quaternius (peint, glTF converti en .glb ici) et la Nature Kit 2.1 de Kenney (couleurs unies, 5 à 30 Ko) —,
## et les cristaux calculés (`modeles_cartoon.gd`) pour la glace. [source, hauteur voulue en cases, part des colonnes, mode].
## Les petites plantes « en débordement » (seules la pente et l'eau les refusent), les arbres « libres ».
const QN := "D:/SpannerGames/BIBLIOTHEQUE/modeles/cc0_quaternius_nature/glTF/"
const KN := "D:/SpannerGames/BIBLIOTHEQUE/modeles/cc0_kenney_nature/Models/GLTF format/"
const FEUILLAGE := {
	"Grass": [["q:CommonTree_1", 4.5, 0.008, "sol_libre"], ["q:CommonTree_3", 4.0, 0.006, "sol_libre"],
		["q:Bush_Common", 1.0, 0.03, "sol_debord"], ["q:Grass_Common_Tall", 0.5, 0.22, "sol_debord"],
		["q:Grass_Wispy_Tall", 0.6, 0.12, "sol_debord"], ["q:Clover_2", 0.25, 0.05, "sol_debord"]],
	"Flowers": [["q:Flower_3_Group", 0.5, 0.18, "sol_debord"], ["q:Flower_4_Group", 0.5, 0.16, "sol_debord"],
		["q:Bush_Common_Flowers", 1.1, 0.04, "sol_debord"], ["q:Grass_Common_Short", 0.35, 0.2, "sol_debord"],
		["q:CommonTree_5", 4.2, 0.005, "sol_libre"]],
	"Path": [["q:Grass_Common_Short", 0.3, 0.04, "sol_debord"], ["q:Pebble_Round_2", 0.2, 0.03, "sol_debord"]],
	"Forest": [["q:Pine_1", 6.0, 0.03, "sol_libre"], ["q:Pine_3", 5.0, 0.025, "sol_libre"],
		["q:CommonTree_2", 5.0, 0.02, "sol_libre"], ["q:Fern_1", 0.7, 0.18, "sol_debord"],
		["q:Mushroom_Common", 0.35, 0.04, "sol_debord"], ["k:mushroom_redGroup", 0.5, 0.02, "sol_debord"],
		["k:stump_old", 0.6, 0.008, "sol_libre"]],
	"Autumn": [["k:tree_oak_fall", 4.5, 0.035, "sol_libre"], ["k:tree_default_fall", 4.0, 0.03, "sol_libre"],
		["k:tree_detailed_fall", 4.2, 0.02, "sol_libre"], ["q:Grass_Wispy_Short", 0.4, 0.12, "sol_debord"],
		["k:plant_bushLarge", 0.9, 0.02, "sol_debord"]],
	"Sand": [["k:cactus_tall", 2.2, 0.012, "sol_libre"], ["k:cactus_short", 1.2, 0.015, "sol_libre"],
		["q:Rock_Medium_1", 0.8, 0.006, "sol_debord"]],
	"Beach": [["k:tree_palmTall", 5.0, 0.008, "sol_libre"], ["k:tree_palmBend", 4.5, 0.006, "sol_libre"],
		["q:Pebble_Round_4", 0.25, 0.02, "sol_debord"]],
	"Canyon": [["k:rock_tallA", 2.4, 0.008, "sol_debord"], ["k:rock_tallG", 1.6, 0.01, "sol_debord"],
		["k:cactus_short", 1.1, 0.008, "sol_libre"]],
	"Mud": [["q:DeadTree_1", 4.5, 0.012, "sol_libre"], ["q:DeadTree_3", 4.0, 0.01, "sol_libre"],
		["q:Grass_Wispy_Tall", 0.8, 0.2, "sol_debord"], ["q:Fern_1", 0.6, 0.06, "sol_debord"]],
	"Rock": [["q:Rock_Medium_3", 1.1, 0.02, "sol_debord"], ["k:stone_tallB", 2.2, 0.006, "sol_debord"],
		["q:Pine_5", 4.0, 0.006, "sol_libre"]],
	"Snow": [["q:Pine_2", 4.5, 0.02, "sol_debord"], ["c:cristal", 1.4, 0.006, "sol_debord"]],
	"Ice": [["c:cristal", 1.6, 0.02, "sol_debord"]],
	"Volcano": [["k:rock_tallC", 1.6, 0.01, "sol_debord"], ["q:DeadTree_5", 3.5, 0.006, "sol_libre"]],
}

var _dossier := DOSSIER_DEFAUT
var _projet := ""
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
			_dossier = a.substr("--dossier=".length())
		elif a.begins_with("--niveau="):
			_niveau = int(a.substr("--niveau=".length()))
		elif a == "--sans-feuillage":
			_sans_feuillage = true
		elif a == "--refaire":
			refaire = true
	_projet = _dossier.path_join("monde_cartoon.mbproj")
	_photos = _dossier.path_join("photos")
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
	if FileAccess.file_exists(REGLAGES):
		DirAccess.copy_absolute(REGLAGES, SAUVEGARDE)
	if _seulement == "" or _seulement == "temoins":
		if FileAccess.file_exists(_projet) and not refaire:
			print("⚠ %s existe : relancer avec -- --refaire pour le refaire" % _projet)
			_rendre_les_reglages()
			quit(1)
			return
		_vider(_dossier)
		DirAccess.make_dir_recursive_absolute(_dossier)
		var couches := []
		for i in THEMES.size():
			var poids := {}
			for c in CLES_VARIEES:
				poids[c] = POIDS_VARIANTES
			couches.append({"nom": THEMES[i][0], "source": "", "visible": true, "cases": [], "temoin": "",
				"id": str(i + 1), "poids": poids, "choix": []})
		var f := FileAccess.open(_projet, FileAccess.WRITE)
		f.store_string(JSON.stringify({"format": "marchingblocks-project", "version": 3, "active": 0,
			"couches": couches, "eaux": [], "retrait": 0.0}, "\t"))
		f.close()
	DirAccess.make_dir_recursive_absolute(_photos)
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", _projet)
	r.set_value("projet", "monde", _projet)
	r.save(REGLAGES)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	Input.use_accumulated_input = false
	_derouler.call_deferred()


func _derouler() -> void:
	var debut := Time.get_ticks_msec()
	await _images(30)
	await _ecran._ouvrir(_projet)
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
	var f := FileAccess.open(_dossier.path_join("rapport.json"), FileAccess.WRITE)
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
	print("base : niveau %d, %d triangles, %s, %s (%d ms)" % [_niveau, F.triangles(base), b1, b2, Time.get_ticks_msec() - t0])
	_rapport["base"] = {"niveau": _niveau, "chanfrein": _chanfrein, "triangles_par_52_tuiles": F.triangles(base),
		"subdivision": b1, "chanfreinage": b2}
	_rapport["temoins"] = {}
	for th in THEMES:
		var nom: String = th[0]
		var t1 := Time.get_ticks_msec()
		var t: RefCounted = base.copie()
		var cles: Array = t.tuiles.keys()
		var c: Dictionary = _ecran._couches[_couche[nom]]
		for cle in cles:
			_relief(nom, t.tuiles[cle], cle)
		var v := F.creer_variantes(t, CLES_VARIEES, 2, func(m: RefCounted, k: int) -> void:
			_morceau_sculpte(nom, m, k))
		var dossier: String = _ecran._chemin_temoin_de(c).get_basename() + "_images"
		var k_sol := _materiau(t, th, "ground", dossier)
		var k_paroi := _materiau(t, th, "wall", dossier)
		F.assigner_par_orientation(t, k_sol, k_paroi, 0.55)
		c["_temoin"] = t
		var raison: String = _ecran._enregistrer_temoin(c, true)
		print("%s : %d tuiles, %d triangles, variantes %s %s(%d ms)" % [nom, t.tuiles.size(), F.triangles(t), v.keys(),
			("⚠ " + raison + " ") if raison != "" else "", Time.get_ticks_msec() - t1])
		_rapport["temoins"][nom] = {"tuiles": t.tuiles.size(), "triangles": F.triangles(t), "ms": Time.get_ticks_msec() - t1}
		await _images(2)
	await _photo_des_temoins()


## LE DEDANS DE CHAQUE MATIÈRE — un relief SIMPLE, qui dit la matière sans charger (les bords ne bougent pas).
func _relief(nom: String, m: RefCounted, cle: String) -> void:
	var h := hash(cle)
	var dec := Vector3(h % 97, (h / 97) % 89, (h / 9000) % 83) * 1.7
	match nom:
		"Grass", "Flowers", "Autumn":
			F.bosseler(m, F.bruit(11, 1.6, 2), 0.05, dec, true, Vector3.UP)
		"Forest", "Mushroom":
			F.bosseler(m, F.bruit(12, 2.2, 2), 0.06, dec, true)
		"Path":
			F.bosseler(m, F.bruit(13, 3.0, 1), 0.015, dec)
		"Cobble":
			F.bosseler(m, F.bruit(14, 4.0, 1), 0.035, dec, true)
		"Beach":
			F.bosseler(m, F.bruit(15, 1.2, 1), 0.02, dec)
		"Sand":
			# Des rides de dune : une onde sur ce qui regarde le ciel.
			F.retoucher_dedans(m, func(p: Vector3, n: Vector3) -> Vector3:
				return Vector3.UP * (0.045 * sin(TAU * (1.5 * p.x + 0.6 * p.z) + dec.x) * clampf(n.y, 0.0, 1.0)))
		"Snow":
			F.bosseler(m, F.bruit(16, 1.2, 1), 0.07, dec, true, Vector3.UP)
		"Mud":
			F.bosseler(m, F.bruit(17, 2.5, 2), 0.05, dec)
		"Ice":
			F.bosseler(m, F.bruit(18, 1.4, 1), 0.05, dec)
		"Rock", "Crystal", "Cavern":
			# Des FACETTES : un bruit posterisé en trois paliers (la roche taillée de Pokémon).
			var bf := F.bruit(19 if nom == "Rock" else 20, 2.4, 2)
			var amp := 0.11 if nom == "Crystal" else 0.09
			F.retoucher_dedans(m, func(p: Vector3, n: Vector3) -> Vector3:
				return n * (amp * round(bf.get_noise_3dv(p + dec) * 3.0) / 3.0))
		"Canyon":
			# Des STRATES : sur les parois, une bande sur deux avance, l'autre recule.
			var bs := F.bruit(21, 1.5, 1)
			F.retoucher_dedans(m, func(p: Vector3, n: Vector3) -> Vector3:
				var paroi := 1.0 - absf(n.y)
				var bande := 1.0 if p.y > 0.0 else -0.5    # une strate par case (deux étaient trop serrées, vu à l'image)
				return n * (0.07 * bande * paroi + 0.03 * bs.get_noise_3dv(p + dec) * (1.0 - paroi)))
		"Volcano":
			# Des CRAQUELURES : un bruit « en crête » qui creuse le long de ses lignes.
			var bc := F.bruit(22, 2.2, 2)
			F.retoucher_dedans(m, func(p: Vector3, n: Vector3) -> Vector3:
				return -n * (0.08 * pow(1.0 - absf(bc.get_noise_3dv(p + dec)), 4.0)))


## Un renflement autour de `c` (rayon `r`, hauteur `a`) le long de la normale ; `paliers` > 0 : posterisé (taillé).
static func _bosse(m: RefCounted, c: Vector3, r: float, a: float, paliers := 0, pointe := false, forme := 1.5) -> void:
	F.retoucher_dedans(m, func(p: Vector3, n: Vector3) -> Vector3:
		var d := p.distance_to(c) / r
		if d >= 1.0:
			return Vector3.ZERO
		var w := (1.0 - d) if pointe else pow(1.0 - d * d, forme)
		if paliers > 0:
			w = ceil(w * paliers) / paliers
		return n * (a * w))


## LE MORCEAU SCULPTÉ D'UNE VARIANTE — UN relief franc, celui qui fait reconnaître la matière de loin.
## ⚠ REMODELÉ SANS PALIERS (Jordan, 20 octobre 2026 : « tu les remodelises ») : les bosses taillées en deux ou trois
## marches (`paliers`) se voyaient de dessus en CARRÉS EN ESCALIER, pris pour de gros pixels dans WaterDrop (monde agrandi
## trois fois), et le smooth shading les gardait vives (des angles droits, au-delà des 40°). Les rochers sont maintenant
## des masses arrondies (`forme` < 1 : un dôme aux flancs raides, qui reste un rocher sans marches), la corniche un bourrelet
## au profil adouci, la bouche du volcan un cône lisse. Statique : la palette de WaterDrop s'en sert (`remodeler_variantes`).
static func _morceau_sculpte(nom: String, m: RefCounted, k: int) -> void:
	var c := Vector3(0.08, 0.05, -0.06) if k == 1 else Vector3(-0.1, -0.04, 0.09)
	match nom:
		"Grass", "Flowers", "Autumn", "Forest", "Path", "Beach":
			if k == 1:
				_bosse(m, c, 0.32, 0.2)                                  # une butte ronde
			else:
				_bosse(m, c, 0.22, 0.17, 0, false, 0.7)                  # un rocher qui affleure, arrondi
				_bosse(m, c + Vector3(0.14, 0, 0.12), 0.12, 0.09, 0, false, 0.7)
		"Sand", "Snow", "Mud", "Mushroom":
			if k == 1:
				_bosse(m, c, 0.34, 0.24)                                 # une dune, une congère, une bulle de boue, un coussin
			else:
				_bosse(m, c, 0.2, 0.16)
				_bosse(m, -c, 0.16, 0.12)
		"Rock", "Canyon", "Cobble", "Cavern":
			if k == 1:
				_bosse(m, c, 0.3, 0.24, 0, false, 0.6)                   # un bloc de roche qui sort, aux arêtes roulées
				_bosse(m, c + Vector3(-0.12, 0.0, 0.1), 0.14, 0.1, 0, false, 0.6)
			else:
				# Une corniche : un bourrelet horizontal qui avance, au profil adouci (plus de marche franche).
				F.retoucher_dedans(m, func(p: Vector3, n: Vector3) -> Vector3:
					var e := 1.0 - smoothstep(0.05, 0.16, absf(p.y - 0.06))
					return n * (0.18 * e) * (1.0 - absf(n.y)))
		"Ice", "Crystal":
			if k == 1:
				_bosse(m, c, 0.26, 0.42, 0, true)                        # une pointe
			else:
				_bosse(m, c, 0.18, 0.3, 0, true)
				_bosse(m, -c, 0.16, 0.26, 0, true)
		"Volcano":
			if k == 1:
				_bosse(m, c, 0.3, 0.22, 0, false, 0.9)                   # une bouche : un cône lisse…
				_bosse(m, c, 0.12, -0.2)                                 # … creusé en son milieu
			else:
				_bosse(m, c, 0.26, 0.2, 0, false, 0.6)


## Un matériau du témoin : l'image PEINTE (et son émission) copiée dans le projet.
func _materiau(t: RefCounted, th: Array, quoi: String, dossier: String) -> int:
	var nom := "%s_%s" % [th[1], quoi]
	var source: String = PEINT + nom + "/" + nom + "_color.png"
	var erreurs: Array = []
	var copie := Peinture_.copier_dans_le_projet(source, dossier, erreurs)
	if copie == "":
		push_warning("%s : %s introuvable (%s)" % [th[0], source, erreurs])
	var d := {"nom": nom, "couleur": Color(1, 1, 1), "rugosite": 0.95, "metal": 0.0, "texture": copie, "echelle": 1.0,
		"projection": "boite"}
	if float(th[2]) > 0.0:
		d["emission"] = th[2]
	t.materiaux.append(d)
	return t.materiaux.size() - 1


func _photo_des_temoins() -> void:
	await _ecran._changer_d_atelier("witness")
	for th in THEMES:
		_ecran._activer(_couche[th[0]])
		await _images(30)
		_photo("temoin_%s" % str(th[0]).to_lower())


func _photo(nom: String) -> void:
	var im := root.get_texture().get_image()
	if im != null:
		im.save_png(_photos.path_join(nom + ".png"))
		print("  photo : %s" % _photos.path_join(nom + ".png"))


# ── 2. LE MONDE ────────────────────────────────────────────────────────────────────────────────────

const MER := 4
const DEMI := 80                # l'île : x et z de −DEMI à DEMI − 1
const PLAINE := 15              # le dessus de la prairie
## Les régions : [nom, centre, poids] — la plus proche (distance / poids, contours bruités) l'emporte.
const REGIONS := [
	["plaine", Vector2(0, 4), 1.35], ["foret", Vector2(-46, -46), 1.0], ["automne", Vector2(-58, -12), 0.75],
	["montagne", Vector2(36, -48), 1.15], ["canyon", Vector2(56, 10), 0.95], ["desert", Vector2(42, 52), 1.0],
	["marais", Vector2(-44, 48), 0.95], ["volcan", Vector2(-56, 16), 0.7],
]
const VOLCAN := Vector2(-56, 16)
const LAC := Vector2(-8, 26)
const LAC_GLACE := Vector2(46, -40)
const PICS := [Vector4(30, -52, 27, 20), Vector4(52, -58, 21, 16), Vector4(16, -40, 12, 11), Vector4(60, -34, 15, 12)]

var _bruit := FastNoiseLite.new()
var _bruit2 := FastNoiseLite.new()
var _h := {}           # Vector2i → dessus de la colonne
var _m := {}           # Vector2i → matière de la colonne
var _region := {}      # Vector2i → région
var _air := {}         # Vector3i → case creusée (alcôves, corridor, grottes)
var _sous_terre := {}  # Vector3i → matière de la paroi d'une grotte (le creux lui-même est dans `_air`)
var _extra := {}       # Vector3i → matière d'une case POSÉE au-dessus de la heightmap (arches, maisons)
var _theme_case := {}  # Vector3i → matière d'une case pleine (paroi de grotte) à la place de celle de la colonne
var _mares: Array = []
var _couvert := {}     # Vector2i → colonne couverte par une arche (pas de plant)
var _entrees: Array = []   # les alcôves qui ouvrent sur le réseau (Vector3 : le fond de l'alcôve)
var _vues := {}        # des points pour les photos et le tournage


func _mc_monde() -> void:
	await _ecran._changer_d_atelier("monde")
	var t0 := Time.get_ticks_msec()
	_relief_monde()
	var par := {}
	for th in THEMES:
		par[th[0]] = {}
	for k in _h:
		for y in range(0, int(_h[k]) + 1):
			var c := Vector3i(k.x, y, k.y)
			if not _air.has(c):
				par[_theme_case.get(c, _m[k])][c] = true
	for c in _extra:
		if not _air.has(c):
			par[_extra[c]][c] = true
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
	_rapport["colonnes"] = _h.size()
	_rapport["total_cases"] = total
	_ecran._activer(_couche["Grass"])
	await _ecran._reparer_les_diagonales(false)
	await _images(2)
	await _eau()
	await _transitions()
	if not _sans_feuillage:
		await _feuillage()
	_ecrire_les_vues()
	_ecran._enregistrer()


func _region_de(x: int, z: int) -> String:
	var p := Vector2(x, z) + Vector2(_bruit2.get_noise_2d(x, z), _bruit2.get_noise_2d(z + 300, x)) * 14.0
	var best := ""
	var bd := INF
	for r in REGIONS:
		var d: float = p.distance_to(r[1]) / float(r[2])
		if d < bd:
			bd = d
			best = r[0]
	return best


## La distance au bord du carré (en colonnes), bruitée : la côte n'est pas une règle.
func _au_bord(x: int, z: int) -> float:
	var d := float(mini(mini(x + DEMI, DEMI - 1 - x), mini(z + DEMI, DEMI - 1 - z)))
	return d + _bruit.get_noise_2d(x * 1.7, z * 1.7) * 3.0


func _relief_monde() -> void:
	_bruit.seed = 2718
	_bruit.frequency = 0.035
	_bruit.fractal_octaves = 3
	_bruit2.seed = 99
	_bruit2.frequency = 0.02
	for x in range(-DEMI - 6, DEMI + 6):
		for z in range(-DEMI - 6, DEMI + 6):
			_colonne(x, z)
	_le_bourg()
	_les_chemins()
	_sans_damier()
	_les_arches()
	_le_corridor()
	_les_alcoves()
	_le_reseau()
	var rep := _sans_contact(_air.keys() + _extra.keys())
	print("relief 3D : %d cases creusées, %d posées, %d ajoutées contre les contacts par une arête" % [_air.size(),
		_extra.size(), rep])
	_rapport["relief_3d"] = {"creusees": _air.size(), "posees": _extra.size(), "reparees": rep}


func _colonne(x: int, z: int) -> void:
	var k := Vector2i(x, z)
	var de := _au_bord(x, z)
	if de < -2.0:
		return
	var b := _bruit.get_noise_2d(x, z)
	var reg := _region_de(x, z)
	var h: int
	var m := "Grass"
	if de < 2.0:
		h = clampi(MER - 3 + int(de), 0, MER - 1)          # le fond de la mer près du bord
		m = "Beach"
	elif de < 7.0:
		h = MER + 1
		m = "Beach"
	else:
		# Les terrasses de la côte : trois cases par marche, jusqu'à la prairie.
		h = mini(MER + 2 + 3 * int(floor((de - 7.0) / 5.0)), PLAINE)
		var colline := int(floor((_bruit.get_noise_2d(x * 0.6 + 50, z * 0.6) + 0.15) * 2.2))
		if de > 26.0 and colline > 0:
			h += 3 * colline
		match reg:
			"plaine":
				m = "Flowers" if _bruit.get_noise_2d(x * 1.3 + 900, z * 1.3) > 0.2 else "Grass"
			"foret":
				m = "Forest"
			"automne":
				m = "Autumn"
			"marais":
				h = mini(h, PLAINE - 3)
				m = "Mud"
				if de > 10.0 and _bruit.get_noise_2d(x * 2.6, z * 2.6) > 0.3:
					h -= 1
					_mares.append(k)
			"desert":
				m = "Sand"
				h = mini(h, PLAINE) + (1 if sin(x * 0.18 + b * 2.0) + sin(z * 0.13) > 0.9 else 0)
			"canyon":
				# Des MESAS rouges, entre elles des couloirs (le fond à la prairie − 3).
				m = "Canyon"
				var mesa := _bruit.get_noise_2d(x * 2.2 + 400, z * 2.2)
				if de > 14.0:
					if mesa > 0.05:
						h = PLAINE + 9 if mesa > 0.3 else PLAINE + 6
					elif mesa > -0.25:
						h = PLAINE
					else:
						h = PLAINE - 3
			"montagne":
				m = "Rock"
				var hm := 0.0
				for pic in PICS:
					var dp := Vector2(x, z).distance_to(Vector2(pic.x, pic.y)) + b * 5.0
					if dp < pic.w:
						hm = maxf(hm, pic.z * pow(1.0 - dp / pic.w, 1.1))
				if de > 10.0:
					h = maxi(h, PLAINE + 3 * int(floor(hm / 3.0)))
				if h >= PLAINE + 15:
					m = "Snow"
				var dl := Vector2(x, z).distance_to(LAC_GLACE)
				if dl < 6.5 + b * 2.0:
					h = PLAINE + 6
					m = "Ice"
				elif dl < 9.0:
					h = maxi(h, PLAINE + 9)
					m = "Snow"
			"volcan":
				m = "Volcano"
				var dv := Vector2(x, z).distance_to(VOLCAN) + b * 2.0
				if dv < 22.0 and de > 8.0:
					h = maxi(h, PLAINE + 3 * int(floor((1.0 - dv / 22.0) * 18.0 / 3.0)))
					if dv < 4.5:
						h = PLAINE + 9           # le cratère : trois cases sous le rebord
	# Le lac de la prairie : une cuvette.
	if reg == "plaine" and Vector2(x, z).distance_to(LAC) < 7.0 + b * 2.0:
		h = PLAINE - 2
		m = "Beach"
	_h[k] = h
	_m[k] = m
	_region[k] = reg


## LE BOURG : une place pavée au centre de la prairie, quatre tours de pavés, un muret.
func _le_bourg() -> void:
	var c := Vector2i(0, 0)
	for x in range(-7, 8):
		for z in range(-7, 8):
			var k := c + Vector2i(x, z)
			_h[k] = PLAINE
			_m[k] = "Cobble"
	for coin in [Vector2i(-7, -7), Vector2i(5, -7), Vector2i(-7, 5), Vector2i(5, 5)]:
		for dx in 3:
			for dz in 3:
				for y in range(PLAINE + 1, PLAINE + 5):
					_extra[Vector3i(coin.x + dx, y, coin.y + dz)] = "Cobble"
	# Une fontaine : un bassin d'une case de haut, creux.
	for x in range(-2, 3):
		for z in range(-2, 3):
			if absi(x) == 2 or absi(z) == 2:
				_extra[Vector3i(x, PLAINE + 1, z)] = "Cobble"
	_vues["bourg"] = Vector3(0.5, PLAINE + 1.0, 0.5)


## LES CHEMINS : du bourg vers chaque région, en terre battue.
func _les_chemins() -> void:
	for r in REGIONS:
		if r[0] == "plaine":
			continue
		var fin: Vector2 = r[1]
		var n := int(fin.length())
		for i in range(8, n):
			var q := Vector2.ZERO.lerp(fin, float(i) / n) + Vector2(sin(i * 0.2) * 2.5, cos(i * 0.17) * 2.0)
			for dx in range(-1, 1):
				for dz in range(-1, 1):
					var k := Vector2i(int(round(q.x)) + dx, int(round(q.y)) + dz)
					if _m.get(k, "") in ["Grass", "Flowers"]:
						_m[k] = "Path"


## Aucun contact par une arête dans la heightmap (charte §2) : la paire basse d'un damier remonte.
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
					_m[cible] = _m.get(paire[6], "Grass")
					change = true
					break


func _plein(c: Vector3i) -> bool:
	if _air.has(c):
		return false
	if _extra.has(c):
		return true
	var k := Vector2i(c.x, c.z)
	return _h.has(k) and c.y >= 0 and c.y <= int(_h[k])


## LES ARCHES — un arc de cercle posé sur le sol (ou d'une rive à l'autre), d'épaisseur `ep`, de largeur `la`.
func _arche(a: Vector3, b: Vector3, hauteur: float, ep: float, la: float, theme: String) -> void:
	var n := int(a.distance_to(b) * 3.0) + 6
	var lateral := Vector3(-(b - a).z, 0, (b - a).x).normalized()
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t) + Vector3.UP * (hauteur * sin(PI * t))
		for x in range(floori(p.x - la - ep), ceili(p.x + la + ep) + 1):
			for y in range(floori(p.y - ep), ceili(p.y + ep) + 1):
				for z in range(floori(p.z - la - ep), ceili(p.z + la + ep) + 1):
					var q := Vector3(x + 0.5, y + 0.5, z + 0.5) - p
					var le_long := q.dot(lateral)
					var reste := q - lateral * le_long
					if absf(le_long) <= la and reste.length() <= ep:
						var c := Vector3i(x, y, z)
						if not _plein(c):
							_extra[c] = theme
							_couvert[Vector2i(x, z)] = true
	# Les pieds descendent jusqu'au sol (une arche posée sur une pente n'a pas de jour sous la jambe basse).
	for p in [a, b]:
		for x in range(floori(p.x - la), ceili(p.x + la) + 1):
			for z in range(floori(p.z - ep), ceili(p.z + ep) + 1):
				var k := Vector2i(x, z)
				for y in range(int(_h.get(k, 0)) + 1, int(p.y) + 1):
					if not _plein(Vector3i(x, y, z)):
						_extra[Vector3i(x, y, z)] = theme


func _sol(x: float, z: float) -> float:
	return float(_h.get(Vector2i(floori(x), floori(z)), MER)) + 1.0


func _les_arches() -> void:
	# Dans la prairie : une arche de roche, au nord du bourg.
	_arche(Vector3(-9, _sol(-9, -24), -24), Vector3(8, _sol(8, -24), -24), 9.0, 1.6, 1.2, "Rock")
	_vues["arche_prairie"] = Vector3(0, PLAINE + 6, -24)
	# Le canyon : deux arches rouges qui enjambent un couloir.
	var n := 0
	for k in _h.keys():
		if n >= 2:
			break
		if _region.get(k, "") != "canyon" or _h[k] != PLAINE - 3 or _au_bord(k.x, k.y) < 20.0:
			continue
		# Un couloir assez long en x : une mesa haute de part et d'autre, à moins de sept colonnes.
		var g := -1
		var d := -1
		for i in range(2, 8):
			if g < 0 and int(_h.get(k + Vector2i(-i, 0), 0)) >= PLAINE + 6:
				g = i
			if d < 0 and int(_h.get(k + Vector2i(i, 0), 0)) >= PLAINE + 6:
				d = i
		if g < 0 or d < 0:
			continue
		var y0 := float(PLAINE + 6)
		_arche(Vector3(k.x - g + 0.5, y0, k.y + 0.5), Vector3(k.x + d + 0.5, y0, k.y + 0.5), 3.0, 1.3, 1.0, "Canyon")
		_vues["arche_canyon_%d" % n] = Vector3(k.x + 0.5, y0, k.y + 0.5)
		n += 1
	# Une grande arche dans le canyon, posée au fond.
	var ca := Vector2(56, 10)
	_arche(Vector3(ca.x - 7, _sol(ca.x - 7, ca.y + 6), ca.y + 6), Vector3(ca.x + 7, _sol(ca.x + 7, ca.y + 6), ca.y + 6),
		11.0, 1.8, 1.4, "Canyon")
	_vues["grande_arche"] = Vector3(ca.x, PLAINE + 8, ca.y + 6)
	# L'arche de mer : de la plage au sud, une jambe dans la mer.
	_arche(Vector3(-20, MER + 2, DEMI - 6), Vector3(-6, 0, DEMI + 3), 9.0, 1.6, 1.3, "Rock")
	_vues["arche_mer"] = Vector3(-13, MER + 6, DEMI - 1)
	_rapport["arches"] = 4 + n


## LE CORRIDOR — une galerie droite et large qui traverse la montagne, du canyon à la vallée des pics, sol plat.
func _le_corridor() -> void:
	var a := Vector3(66, PLAINE + 1, -10)
	var b := Vector3(22, PLAINE + 1, -32)
	var n := int(a.distance_to(b) * 2.0)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for x in range(floori(p.x - 3), ceili(p.x + 3) + 1):
			for y in range(int(p.y), int(p.y) + 4):
				for z in range(floori(p.z - 3), ceili(p.z + 3) + 1):
					var q := Vector2(x + 0.5 - p.x, z + 0.5 - p.z)
					var r := 2.4 - maxf(0.0, (y - p.y - 2.0)) * 0.6   # une voûte : plus étroit en haut
					if q.length() <= r:
						_air[Vector3i(x, y, z)] = true
	_vues["corridor"] = [a, b]


## LES ALCÔVES — creusées au pied des falaises d'au moins quatre cases : trois de large, trois de haut, quatre de fond.
## Les premières de chaque grande région ouvrent ensuite sur le réseau souterrain.
func _les_alcoves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var choisies: Array = []
	var cles := _h.keys()
	cles.sort()
	for k in cles:
		if _au_bord(k.x, k.y) < 14.0 or _couvert.has(k) or rng.randf() > 0.25:
			continue
		# Jamais là où une eau dormante pourrait entrer : le marais (ses mares), le bord du lac.
		if _region.get(k, "") == "marais" or Vector2(k).distance_to(LAC) < 14.0:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var bas: int = int(_h.get(k - d, 999))
			if int(_h[k]) - bas < 4 or bas <= MER:
				continue
			var p := Vector2(k)
			var loin := true
			for q in choisies:
				if p.distance_to(q[0]) < 12.0:
					loin = false
					break
			if not loin:
				continue
			choisies.append([p, d, bas])
			break
	var n := 0
	for ch in choisies:
		var k := Vector2i(ch[0])
		var d: Vector2i = ch[1]
		var sol: int = ch[2] + 1
		var cote := Vector2i(-d.y, d.x)
		var fond := 4 + n % 2
		for i in range(0, fond):
			var larg := 1 if i < fond - 1 else 0
			for s in range(-larg - 1, larg + 2):
				for y in range(sol, sol + 3 - (1 if i == fond - 1 else 0)):
					var q := k + d * i + cote * s
					if y <= int(_h.get(q, -1)) - 2:
						_air[Vector3i(q.x, y, q.y)] = true
		_entrees.append(Vector3(k.x + d.x * (fond - 1) + 0.5, sol, k.y + d.y * (fond - 1) + 0.5))
		n += 1
	_rapport["alcoves"] = n
	print("alcôves : %d" % n)


# ── LE RÉSEAU SOUTERRAIN ───────────────────────────────────────────────────────────────────────────
## Des galeries LARGES (rayon 2,8 : six cases, sol plat) entre de grandes salles ; on y entre par les alcôves les plus
## proches. Tout est au-dessus de la mer (le sol à MER + 2 au moins) : aucune nappe ne s'y engouffre. Jamais à moins de
## trois cases du dessus.
const SALLES := [
	# [nom, centre, rayons, matière de la paroi, forme]
	["cristal", Vector3(-20, 9.5, -22), Vector3(13, 4.0, 10), "Crystal", "geode"],
	["champignons", Vector3(22, 9.5, 22), Vector3(12, 4.0, 10), "Mushroom", "coussins"],
	["piliers", Vector3(-24, 9.5, 18), Vector3(11, 3.5, 9), "Cavern", "piliers"],
	["caverne", Vector3(36, 14.0, -44), Vector3(14, 8.0, 12), "Crystal", "geode"],
	["sous_le_bourg", Vector3(4, 9.0, -6), Vector3(9, 3.2, 8), "Mushroom", "coussins"],
]
const GALERIES := [
	[Vector3(-20, 7.8, -22), Vector3(-6, 7.8, -12), Vector3(4, 7.8, -6)],
	[Vector3(4, 7.8, -6), Vector3(14, 7.8, 8), Vector3(22, 7.8, 22)],
	[Vector3(4, 7.8, -6), Vector3(-10, 7.8, 6), Vector3(-24, 7.8, 18)],
	[Vector3(-24, 7.8, 18), Vector3(-30, 7.8, -2), Vector3(-20, 7.8, -22)],
	[Vector3(4, 7.8, -6), Vector3(18, 9.0, -22), Vector3(30, 11.0, -36), Vector3(36, 8.5, -44)],
]


func _le_reseau() -> void:
	var t0 := Time.get_ticks_msec()
	var bruit := FastNoiseLite.new()
	bruit.seed = 7
	bruit.frequency = 0.1
	var creux := {}
	for g in GALERIES:
		_galerie(g, creux, bruit, "Cavern")
	for s in SALLES:
		_salle(s, creux, bruit)
	# Les entrées : chaque alcôve à moins de 30 colonnes d'un point du réseau y est reliée par une galerie qui descend.
	var points: Array = []
	for g in GALERIES:
		for p in g:
			points.append(p)
	var reliees := 0
	for e in _entrees:
		var best := Vector3.ZERO
		var bd := INF
		for p in points:
			var d := Vector2(e.x, e.z).distance_to(Vector2(p.x, p.z))
			if d < bd:
				bd = d
				best = p
		if bd > 30.0:
			continue
		_galerie([Vector3(e.x, e.y + 1.3, e.z), best], creux, bruit, "Cavern", true)
		reliees += 1
	var pris := 0
	for c in creux:
		var k := Vector2i(c.x, c.z)
		if not _h.has(k) or c.y < MER + 2:
			continue
		if creux[c] == "":
			continue
		_air[c] = true
		_sous_terre[c] = creux[c]
		pris += 1
	# La paroi : la couronne d'une case autour du creux prend la matière de la salle (pas les deux cases du dessus).
	for c in _sous_terre:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					var q := Vector3i(c.x + dx, c.y + dy, c.z + dz)
					if _air.has(q) or _extra.has(q):
						continue
					var k := Vector2i(q.x, q.z)
					if not _h.has(k) or q.y > int(_h[k]) - 2:
						continue
					var deja: String = _theme_case.get(q, "")
					if deja == "" or deja == "Cavern":
						_theme_case[q] = _sous_terre[c]
	print("réseau : %d salles, %d galeries, %d entrées, %d cases creusées (%d ms)" % [SALLES.size(), GALERIES.size(),
		reliees, pris, Time.get_ticks_msec() - t0])
	_rapport["reseau"] = {"salles": SALLES.map(func(s: Array) -> String: return s[0]), "galeries": GALERIES.size(),
		"entrees": reliees, "creusees": pris}


func _galerie(points: Array, creux: Dictionary, bruit: FastNoiseLite, theme: String, ouvert := false) -> void:
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var n := maxi(int(a.distance_to(b) * 2.0), 1)
		var cote := Vector3(-(b - a).z, 0, (b - a).x).normalized()
		for j in n + 1:
			var t := float(j) / n
			var q := a.lerp(b, t) + cote * bruit.get_noise_3d(a.x + t * 40.0, 0, a.z) * 3.0 * sin(t * PI)
			var rayon := 2.8 + bruit.get_noise_3d(q.z * 2.0, q.x * 2.0, 7.0) * 0.4
			_creuser(q, rayon, creux, theme, ouvert)


## Un creux large et plat : une demi-boule écrasée sur un sol plat (le sol à l'axe − 1,5).
func _creuser(q: Vector3, rayon: float, creux: Dictionary, theme: String, ouvert: bool) -> void:
	for x in range(floori(q.x - rayon - 1), ceili(q.x + rayon + 1)):
		for y in range(floori(q.y - 1.5), ceili(q.y + rayon * 0.9) + 1):
			for z in range(floori(q.z - rayon - 1), ceili(q.z + rayon + 1)):
				var d := Vector3(x + 0.5 - q.x, maxf(0.0, y + 0.5 - q.y) * 1.25, z + 0.5 - q.z)
				if d.length() > rayon or float(y) < q.y - 1.5:
					continue
				# Jamais à moins de trois cases du dessus ; deux pour une galerie d'entrée (elle part d'une alcôve, au pied
				# d'une falaise) : un toit reste toujours, la surface n'est jamais percée.
				if y > int(_h.get(Vector2i(x, z), -99)) - (2 if ouvert else 3):
					continue
				var c := Vector3i(x, y, z)
				if not creux.has(c):
					creux[c] = theme


func _salle(s: Array, creux: Dictionary, bruit: FastNoiseLite) -> void:
	var o: Vector3 = s[1]
	var r: Vector3 = s[2]
	var theme: String = s[3]
	var forme: String = s[4]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(s[0])
	var pointes: Array = []
	if forme == "geode":
		for i in 18:
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized()
			pointes.append([o + Vector3(dir.x * r.x, dir.y * r.y, dir.z * r.z), -dir, rng.randf_range(2.5, 4.0)])
	for x in range(floori(o.x - r.x) - 1, ceili(o.x + r.x) + 2):
		for y in range(floori(o.y - r.y), ceili(o.y + r.y) + 2):
			for z in range(floori(o.z - r.z) - 1, ceili(o.z + r.z) + 2):
				var p := Vector3(x + 0.5, y + 0.5, z + 0.5)
				var d := p - o
				# Une salle au SOL PLAT (à o.y − r.y) et en voûte au-dessus.
				var e := Vector3(d.x / r.x, maxf(d.y, 0.0) / r.y, d.z / r.z)
				var dedans := e.length() <= 1.0 + bruit.get_noise_3dv(p) * 0.15 and p.y >= o.y - r.y
				if not dedans:
					continue
				if y > int(_h.get(Vector2i(x, z), -99)) - 3:
					continue
				var garde := false
				match forme:
					"piliers":
						garde = posmod(x - int(o.x), 6) < 2 and posmod(z - int(o.z), 6) < 2 and e.length() < 0.8
					"geode":
						for pt in pointes:
							var t := (p - (pt[0] as Vector3)).dot(pt[1])
							if t >= 0.0 and t <= pt[2] and (p - pt[0] - (pt[1] as Vector3) * t).length() <= 1.0 * (1.0 - t / pt[2]) + 0.3:
								garde = true
					"coussins":
						# Des bosses molles au sol (de gros champignons de pierre).
						garde = p.y < o.y - r.y + 1.5 and bruit.get_noise_2d(p.x * 2.0, p.z * 2.0) > 0.45
				var c := Vector3i(x, y, z)
				if garde:
					creux[c] = ""
				elif creux.get(c, null) != "":
					creux[c] = theme
	_vues["salle_" + str(s[0])] = o


## Aucun contact par une arête autour des cases changées (charte §2) : dans un carré de quatre cases, deux pleines en
## diagonale et deux vides — une des vides est COMBLÉE (une case creusée est rendue, sinon une case est posée, de la
## matière de sa voisine posée ou de la colonne). Toujours plus plein : ça termine.
func _sans_contact(cases: Array) -> int:
	var plans := [[Vector3i(1, 0, 0), Vector3i(0, 1, 0)], [Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
		[Vector3i(0, 1, 0), Vector3i(0, 0, 1)]]
	var a_voir := {}
	for c in cases:
		for pl in plans:
			for u in [Vector3i.ZERO, -pl[0]]:
				for v in [Vector3i.ZERO, -pl[1]]:
					a_voir[[c + u + v, pl]] = true
	var total := 0
	for tour in 50:
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
			var pleines: Array = [a, e] if pa else [b, d]
			var vides: Array = [b, d] if pa else [a, e]
			var choix: Vector3i = vides[0]
			for vv in vides:
				if _air.has(vv):
					choix = vv
					break
			if _air.has(choix):
				# ⚠ UNE CASE DE GROTTE REBOUCHÉE GARDE LA MATIÈRE DE SA GROTTE (vu à l'image) : avec celle de sa colonne (la
				# forêt, la prairie), ses sommets étaient posés par cette couche — des bouts de berge pendaient sous la voûte.
				if _sous_terre.has(choix):
					_theme_case[choix] = _sous_terre[choix]
				_air.erase(choix)
				_sous_terre.erase(choix)
			else:
				var theme := ""
				for pp in pleines:
					if _extra.has(pp):
						theme = _extra[pp]
				if theme == "":
					var k := Vector2i(choix.x, choix.z)
					theme = _theme_case.get(pleines[0], _m.get(k, _m.get(Vector2i(pleines[0].x, pleines[0].z), "Rock")))
				_extra[choix] = theme
			total += 1
			for pl2 in plans:
				for u in [Vector3i.ZERO, -pl2[0]]:
					for v in [Vector3i.ZERO, -pl2[1]]:
						suivants[[choix + u + v, pl2]] = true
		if suivants.is_empty():
			break
		a_voir = suivants
	return total


## L'EAU par les clics de l'atelier Fluids : la mer, le lac de la prairie, la rivière de la montagne, la lave du cratère,
## les mares du marais.
func _eau() -> void:
	await _ecran._changer_d_atelier("fluides")
	var large := Vector3i(DEMI + 12, MER, 0)
	_ecran._eau_cliquee(large, MOUSE_BUTTON_LEFT)
	_ecran._eau_cliquee(large, MOUSE_BUTTON_LEFT)
	_ecran._eaux[_ecran._eau_active]["preset"] = "stylise"
	_ecran._eaux[_ecran._eau_active]["nom"] = "Sea"
	var cl := Vector2i(LAC)
	_ecran._eau_cliquee(Vector3i(cl.x, _h[cl] + 1, cl.y), MOUSE_BUTTON_LEFT)
	# ⚠ PAS DE RIVIÈRE (vu à l'image le 18 octobre 2026) : celle de la montagne entrait par une alcôve et NOYAIT tout le
	# réseau souterrain (une rivière suit la pente jusqu'à la première chute — ici, la bouche d'une galerie).
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
		if vues.has(k):
			continue
		var pile := [k]
		var hk: int = _h[k]
		while not pile.is_empty():
			var q: Vector2i = pile.pop_back()
			if vues.has(q) or _h.get(q, -1) != hk:
				continue
			vues[q] = true
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				pile.append(q + d)
		_ecran._eau_cliquee(Vector3i(k.x, hk + 1, k.y), MOUSE_BUTTON_LEFT)
	await _ecran._recalculer_eau(false)
	_rapport["eau"] = {}
	for e in _ecran._eaux:
		_rapport["eau"][e["nom"]] = {"preset": e["preset"], "sources": (e["sources"] as Array).size()}
		print("eau %s (%s) : %d sources" % [e["nom"], e["preset"], (e["sources"] as Array).size()])
	await _ecran._changer_d_atelier("monde")


## La source de la rivière : une colonne de roche de la montagne, à la prairie + 6, au bord d'une terrasse qui descend
## vers le sud (une chute à moins de quatre cases : elle part en rivière).
func _source_de_riviere() -> Vector3i:
	var cles := _h.keys()
	cles.sort()
	for k in cles:
		if _region.get(k, "") != "montagne" or int(_h[k]) != PLAINE + 6 or _au_bord(k.x, k.y) < 20.0:
			continue
		if k.x < 18 or k.x > 30 or k.y < -36:
			continue
		var plat := true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			if int(_h.get(k + d, -1)) < int(_h[k]):
				plat = false
		if plat and int(_h.get(k + Vector2i(0, 3), 99)) < int(_h[k]):
			return Vector3i(k.x, int(_h[k]) + 1, k.y)
	return Vector3i.ZERO


func _transitions() -> void:
	# Les paires qui se touchent vraiment (plus de trente colonnes voisines), calculées sur la heightmap.
	var compte := {}
	for k in _h:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var q: Vector2i = k + d
			if not _m.has(q) or _m[q] == _m[k]:
				continue
			var p := [_m[k], _m[q]]
			p.sort()
			compte[p] = int(compte.get(p, 0)) + 1
	var allumees := 0
	for p in compte:
		if compte[p] < 30:
			continue
		var ida := str(_ecran._couches[_couche[p[0]]]["id"])
		var idb := str(_ecran._couches[_couche[p[1]]]["id"])
		_ecran._transitions.allumer(TR_.cle_de_paire(ida, idb), true)
		allumees += 1
	_rapport["transitions"] = allumees
	print("transitions : %d paires" % allumees)
	await _images(5)


## LE FEUILLAGE CARTOON : les modèles écrits par `modeles_cartoon.gd`, importés par la route du bouton, plantés au clic.
func _feuillage() -> void:
	var dossier_m := _dossier.path_join("_modeles")
	var modeles := MC.ecrire_tout(dossier_m)
	await _ecran._changer_d_atelier("feuillage")
	var af = _ecran._feuillage
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var par_theme := {}
	for k in _h:
		if not par_theme.has(_m[k]):
			par_theme[_m[k]] = []
		par_theme[_m[k]].append(k)
	for t in par_theme:
		par_theme[t].sort()
	_rapport["feuillage"] = {}
	var total := 0
	var importes := {}
	for nom in FEUILLAGE:
		for d in FEUILLAGE[nom]:
			var fichier := _source_du_modele(str(d[0]), modeles, dossier_m)
			if fichier == "":
				print("feuillage : %s introuvable, sauté" % d[0])
				continue
			var cle := "%s@%s" % [d[0], d[1]]
			if not importes.has(cle):
				var n0: int = af.modeles.size()
				_ecran._action_fichier = "feuillage"
				_ecran._fichier_choisi(fichier)
				if af.modeles.size() == n0:
					print("feuillage : %s refusé" % fichier)
					continue
				importes[cle] = af.modeles.size() - 1
				af.activer(importes[cle])
				var m: Dictionary = af.modele_actif()
				var haut := maxf(float(m["hauteur"]) + float(m["decalage"]), 0.01)
				af._regle("echelle", float(d[1]) / haut)
			af.activer(importes[cle])
			af._choisir_mode(str(d[3]))
			var poses := 0
			for k in par_theme.get(nom, []):
				if rng.randf() > float(d[2]) or int(_h[k]) <= MER or _couvert.has(k):
					continue
				if _air.has(Vector3i(k.x, int(_h[k]), k.y)) or _extra.has(Vector3i(k.x, int(_h[k]) + 1, k.y)):
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
			_rapport["feuillage"]["%s/%s" % [nom, d[0]]] = poses
			print("feuillage %s : %s → %d plants" % [nom, d[0], poses])
			await _images(1)
	print("feuillage : %d plants en tout" % total)
	_rapport["plants"] = total
	await _ecran._changer_d_atelier("monde")


## Le .glb d'un modèle : « c:nom » calculé, « k:nom » Kenney (déjà en .glb), « q:nom » Quaternius (un .gltf et son .bin,
## converti ici en .glb qui embarque ses images — l'atelier Foliage ne prend que le .glb).
func _source_du_modele(id: String, calcules: Dictionary, dossier: String) -> String:
	var nom := id.substr(2)
	match id.substr(0, 2):
		"c:":
			return calcules.get(nom, "")
		"k:":
			var k := KN + nom + ".glb"
			return k if FileAccess.file_exists(k) else ""
		"q:":
			var src := QN + nom + ".gltf"
			var dst := dossier.path_join(nom + ".glb")
			if FileAccess.file_exists(dst):
				return dst
			if not FileAccess.file_exists(src):
				return ""
			var doc := GLTFDocument.new()
			var etat := GLTFState.new()
			if doc.append_from_file(src, etat) != OK:
				return ""
			if doc.write_to_filesystem(etat, dst) != OK:
				return ""
			return dst
	return ""


## Les points remarquables, pour le tournage (`filmer_monde_cartoon.gd`).
func _ecrire_les_vues() -> void:
	var sortie := {}
	for k in _vues:
		var v = _vues[k]
		if v is Vector3:
			sortie[k] = [v.x, v.y, v.z]
		elif v is Array:
			sortie[k] = v.map(func(p: Vector3) -> Array: return [p.x, p.y, p.z])
	sortie["entrees"] = _entrees.map(func(p: Vector3) -> Array: return [p.x, p.y, p.z])
	sortie["galeries"] = GALERIES.map(func(g: Array) -> Array: return g.map(func(p: Vector3) -> Array: return [p.x, p.y, p.z]))
	var f := FileAccess.open(_dossier.path_join("vues.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(sortie, "\t"))
	f.close()


# ── 3. LES PHOTOS ET LA MESURE ─────────────────────────────────────────────────────────────────────

func _poser_oeil(oeil: Vector3, cible: Vector3) -> void:
	var d := oeil - cible
	_poser_camera(cible, atan2(d.x, d.z), asin(clampf(d.y / d.length(), -1.0, 1.0)), d.length())


func _mc_photos() -> void:
	await _ecran._changer_d_atelier("monde")
	if _h.is_empty():
		_relief_monde()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _images(60)
	_rapport["vues"] = {}
	var plans := [
		["ensemble", Vector3(0, 12, 0), 0.7, 0.8, 190.0],
		["bourg", Vector3(0.5, PLAINE + 1, 0.5), 0.6, 0.5, 34.0],
		["arche_prairie", Vector3(0, PLAINE + 4, -24), 0.3, 0.3, 30.0],
		["canyon", Vector3(56, PLAINE + 4, 10), -0.6, 0.45, 46.0],
		["montagnes", Vector3(36, PLAINE + 10, -46), 0.4, 0.45, 60.0],
		["volcan", Vector3(-56, PLAINE + 8, 16), 1.2, 0.42, 52.0],
		["desert", Vector3(42, PLAINE, 52), -0.4, 0.4, 44.0],
		["marais", Vector3(-44, PLAINE - 3, 48), 0.9, 0.42, 36.0],
		["foret", Vector3(-46, PLAINE + 2, -46), 0.4, 0.4, 36.0],
		["automne", Vector3(-58, PLAINE + 2, -12), 1.0, 0.4, 32.0],
		["arche_mer", Vector3(-13, MER + 4, DEMI - 1), 0.2, 0.3, 34.0],
	]
	for v in plans:
		_poser_camera(v[1], v[2], v[3], v[4])
		await _images(45)
		var t0 := Time.get_ticks_usec()
		var prims := 0
		var appels := 0
		var n := 60
		for i in n:
			await process_frame
			prims = maxi(prims, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
			appels = maxi(appels, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		var ips := n / ((Time.get_ticks_usec() - t0) / 1000000.0)
		_photo(v[0])
		_rapport["vues"][v[0]] = {"ips": snappedf(ips, 0.1), "primitives": prims, "appels": appels}
		print("vue %s : %.1f img/s, %d primitives, %d appels" % [v[0], ips, prims, appels])
	# Sous terre : l'œil dans chaque salle.
	for s in SALLES:
		var o: Vector3 = s[1]
		var r: Vector3 = s[2]
		_poser_oeil(o + Vector3(-r.x * 0.7, -r.y * 0.4, r.z * 0.5), o + Vector3(r.x * 0.3, -r.y * 0.5, -r.z * 0.3))
		await _images(45)
		_photo("salle_" + str(s[0]))
	var g: Array = GALERIES[0]
	_poser_oeil(g[0] + Vector3(2, 0.3, 1), g[1])
	await _images(45)
	_photo("galerie")
	_rapport["memoire_video_mo"] = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
