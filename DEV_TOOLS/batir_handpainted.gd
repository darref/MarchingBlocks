extends "res://DEV_TOOLS/filmer_ui.gd"
##
## LE MONDE « HAND-PAINTED » DES DEVLOGS DE LA 0.9.2 — demandé par Jordan (16 octobre 2026) : « fais au mieux pour un
## monde coloré façon handpainted ». Un projet NEUF, bâti par le logiciel lui-même (les fonctions que mènent ses
## boutons : subdiviser, le sculpt Smooth propagé par les sections partagées, l'atlas, la cuisson de l'albedo depuis le
## relief, les calques de peinture, le pinceau du monde, l'eau, le feuillage, les transitions), puis photographié.
##
## LES TÉMOINS (une couche = un témoin) :
##   1. chaque tuile SUBDIVISÉE (une annulation, la complétion des sections faite par le modeleur) ;
##   2. ARRONDIE : des coups de Smooth sur toute la tuile — le chemin du sculpt (bord ramené dans son plan, propagé aux
##      autres tuiles par groupe, un coup qui replierait une face est refait plus doux) ;
##   3. UN matériau sur tout le témoin, DÉPLIÉ EN ATLAS, sa couleur de base CUITE depuis le relief, aux couleurs franches ;
##   4. un calque « Brush » : des taches et des traînées de pinceau, plus claires et plus sombres, qui suivent
##      l'orientation (strates sur les parois, touffes sur les sols) — ÉTEINTES le long des plans de coupe, la discipline
##      des raccords (charte §3).
##
## LANCEMENT (avec fenêtre) :
##   godot --path <projet> --script res://DEV_TOOLS/batir_handpainted.gd -- --dossier=<dossier du projet> [--seulement=…]
##   --seulement : temoins, monde, photos (la suite des étapes ; « photos » seule rouvre le projet déjà bâti).
##   --refaire : obligatoire si le dossier porte déjà un projet (on n'écrase pas un monde sans le dire).

const HP_DEFAUT := "C:/Users/jorda/Documents/MarchingBlocks/handpainted"
const Peinture_ := preload("res://addons/marchingblocks_core/peinture.gd")
const TL_ := preload("res://addons/marchingblocks_core/temoin_lie.gd")

## Les couches, leur palette (sol, paroi, plafond, usure) et le caractère de leur pinceau.
const COUCHES_HP := [
	{"nom": "Meadow", "sol": Color("#7cc44a"), "paroi": Color("#b8794a"), "plafond": Color("#6e4a3a"),
		"arete": Color("#f2dc8c"), "clair": Color("#d6ef6a"), "sombre": Color("#3d8a3a"), "paroi_clair": Color("#e0a468"),
		"paroi_sombre": Color("#7a4a34"), "passes": 3},
	{"nom": "Stone", "sol": Color("#9fb0c8"), "paroi": Color("#8a7fb0"), "plafond": Color("#4e4670"),
		"arete": Color("#eae4f6"), "clair": Color("#c8d6ea"), "sombre": Color("#6c7ca0"), "paroi_clair": Color("#b4a8d8"),
		"paroi_sombre": Color("#564c80"), "passes": 2},
	{"nom": "Sand", "sol": Color("#f2d488"), "paroi": Color("#e0a560"), "plafond": Color("#a86c48"),
		"arete": Color("#fff0c0"), "clair": Color("#fff2b4"), "sombre": Color("#d6a85c"), "paroi_clair": Color("#f4c47c"),
		"paroi_sombre": Color("#b0703c"), "passes": 4},
]
const TAILLE_TOILE := 2048

var _dossier_hp := HP_DEFAUT
var _projet_hp := ""
var _photos := ""


func _initialize() -> void:
	var refaire := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seulement="):
			_seulement = a.substr("--seulement=".length())
		elif a.begins_with("--dossier="):
			_dossier_hp = a.substr("--dossier=".length())
		elif a == "--refaire":
			refaire = true
	_projet_hp = _dossier_hp.path_join("handpainted.mbproj")
	_photos = _dossier_hp.path_join("photos")
	if FileAccess.file_exists(SAUVEGARDE):
		DirAccess.copy_absolute(SAUVEGARDE, REGLAGES)
	if FileAccess.file_exists(REGLAGES):
		DirAccess.copy_absolute(REGLAGES, SAUVEGARDE)
	var neuf := _seulement == "" or _seulement == "temoins"
	if neuf:
		if FileAccess.file_exists(_projet_hp) and not refaire:
			print("⚠ %s existe : relancer avec -- --refaire pour le refaire" % _projet_hp)
			_rendre_les_reglages()
			quit(1)
			return
		_vider(_dossier_hp)
		DirAccess.make_dir_recursive_absolute(_dossier_hp)
		var couches := []
		for i in COUCHES_HP.size():
			couches.append({"nom": COUCHES_HP[i]["nom"], "source": "", "visible": true, "cases": [], "temoin": "",
				"id": str(i + 1)})
		var f := FileAccess.open(_projet_hp, FileAccess.WRITE)
		f.store_string(JSON.stringify({"format": "marchingblocks-project", "version": 3, "active": 0,
			"couches": couches, "eaux": [], "retrait": 0.0}, "\t"))
		f.close()
	DirAccess.make_dir_recursive_absolute(_photos)
	var r := ConfigFile.new()
	r.set_value("projet", "dernier", _projet_hp)
	r.set_value("projet", "monde", _projet_hp)
	r.save(REGLAGES)
	_ecran = load("res://app/editor.tscn").instantiate()
	root.add_child(_ecran)
	Input.use_accumulated_input = false
	_derouler.call_deferred()


func _derouler() -> void:
	await _images(30)
	await _ecran._ouvrir(_projet_hp)
	_vue = _ecran._vue
	for i in _ecran._couches.size():
		_couche[str(_ecran._couches[i].get("nom", ""))] = i
	if _ecran._legende_formes != null:
		_ecran._legende_formes.basculer(false, false)
	for etape in ["temoins", "monde", "photos"]:
		if _seulement != "" and _seulement != etape and not (_seulement == "temoins" and etape != "photos"):
			if not (_seulement == "monde" and etape == "photos"):
				continue
		print("== %s" % etape)
		await Callable(self, "_hp_" + etape).call()
	_ecran._enregistrer()
	_rendre_les_reglages()
	quit(0)


# ── 1. LES TÉMOINS ─────────────────────────────────────────────────────────────────────────────────

func _hp_temoins() -> void:
	for d in COUCHES_HP:
		var debut := Time.get_ticks_msec()
		_ecran._activer(_couche[d["nom"]])
		await _ecran._changer_d_atelier("witness")
		_ecran._regler_edition(true)
		await _images(5)
		var mo = _ecran._modeleur
		var t = mo.temoin
		_subdiviser_tout(mo, t)
		var bilan := _arrondir_tout(mo, t, int(d["passes"]))
		print("%s : subdivisé et arrondi — %s (%d ms)" % [d["nom"], bilan, Time.get_ticks_msec() - debut])
		await _images(2)
		_habiller(mo, t, d)
		print("%s : habillé (%d ms)" % [d["nom"], Time.get_ticks_msec() - debut])
		_ecran._temoin_modifie(t)
		_ecran._enregistrer_le_temoin_modele(true)
		await _photo_temoin(d["nom"])
		_ecran._regler_edition(false)
	await _ecran._changer_d_atelier("monde")


## Chaque tuile, toutes ses faces subdivisées : la route du bouton Subdivide (la complétion des sections comprise).
func _subdiviser_tout(mo, t) -> void:
	for c in t.tuiles.keys():
		mo.activer(int(t.occurrences_de(c)[0]))
		mo.choisir_mode("face")
		mo.tout_choisir(true)
		mo.operer("subdiviser")


## Les coups de Smooth : sur chaque tuile, `passes` fois, tout le maillage sous le pinceau (rayon 1, dureté 1).
func _arrondir_tout(mo, t, passes: int) -> Dictionary:
	var bilan := {"coups": 0, "adoucis": 0, "refuses": 0}
	for p in passes:
		for c in t.tuiles.keys():
			mo.activer(int(t.occurrences_de(c)[0]))
			var force := 0.6
			while true:
				var ok: bool = _coup_lisse(mo, t, force)
				if ok:
					bilan["coups"] += 1
					break
				force *= 0.5
				bilan["adoucis"] += 1
				if force < 0.05:
					bilan["refuses"] += 1
					break
	return bilan


## UN COUP DE SMOOTH sur la tuile en édition — ce que fait `_coup_de_sculpt` d'un coup de pinceau (bord ramené dans son
## plan et propagé par groupe), sans la souris. Rend faux (et défait tout) si une face d'une tuile s'est repliée.
func _coup_lisse(mo, t, force: float) -> bool:
	var m = mo.maillage
	var sections = mo.sections
	mo._sections_du_geste = sections != null
	if sections != null:
		sections.indexer()
		mo._photo = sections.photo()
	mo._depart = (m.sommets as PackedVector3Array).duplicate()
	mo._touchees = {}
	mo._candidats = []
	var avant = m.copie()
	var gardes := {}
	for c in t.tuiles:
		var tu = t.tuiles[c]
		gardes[c] = tu.gardes_de_repli(range(tu.faces.size()))
	var d: Dictionary = m.pinceau_sculpt("smooth", Vector3.ZERO, Vector3.UP, 1.0, force, 1.0)
	if d.is_empty():
		mo._sections_du_geste = false
		return true
	for j in d:
		m.sommets[j] += d[j]
	mo._ids = d.keys()
	mo._contraindre_et_propager()
	var replie := false
	for c in gardes:
		if (t.tuiles[c] as RefCounted).replie(gardes[c]):
			replie = true
			break
	if replie:
		m.sommets = avant.sommets
		if sections != null:
			for c in mo._touchees:
				mo._tuile_indexee(c).sommets = (mo._photo[c] as PackedVector3Array).duplicate()
		mo._sections_du_geste = false
		mo._touchees = {}
		return false
	if not mo._touchees.is_empty():
		mo._emettre_le_lot(avant, "Sculpt")
		for c in mo._touchees:
			mo._rafraichir_tuile(c)
	else:
		mo._emettre(avant, "Sculpt")
	mo._sections_du_geste = false
	mo._touchees = {}
	mo.redessiner()
	return true


## UN matériau sur tout le témoin, déplié en atlas, sa base cuite depuis le relief, puis le calque de pinceau.
func _habiller(mo, t, d: Dictionary) -> void:
	var k: int = mo.nouveau_materiau()
	mo.regler_materiau(k, "nom", str(d["nom"]).to_lower() + "_painted")
	mo.regler_materiau(k, "rugosite", 0.95)
	mo.regler_materiau(k, "metal", 0.0)
	for c in t.tuiles:
		var tu = t.tuiles[c]
		tu.assigner(range(tu.faces.size()), k)
	mo.materiau_courant = k
	mo.deplier_en_atlas()
	var chemin: String = mo.dossier_toiles.path_join("%s_painted.png" % str(d["nom"]).to_lower())
	Peinture_.nouvelle_toile(chemin, Color.WHITE, TAILLE_TOILE)
	mo.regler_materiau(k, "texture", chemin)
	mo.regler_materiau(k, "couleur", Color.WHITE)
	mo.regler_materiau(k, "relief", {"sol": _rgb(d["sol"]), "paroi": _rgb(d["paroi"]), "plafond": _rgb(d["plafond"]),
		"arete": _rgb(d["arete"]), "usure": 0.85, "cavite": 0.7, "largeur": 0.09})
	mo.cuire_le_relief()
	_peindre_les_touches(t, k, chemin, d)
	mo._rafraichir_les_tuiles_qui_portent(k)
	mo.redessiner()


static func _rgb(c: Color) -> Array:
	return [c.r, c.g, c.b]


## LE CALQUE « Brush » : sur chaque face, des tampons doux tirés au hasard (graine fixe : le même témoin à chaque fois),
## dont la couleur suit l'orientation ; les parois en traînées horizontales (strates), les sols en taches (touffes),
## le haut des parois éclairci. Rien à moins de 0,1 case d'un plan de coupe (la voisine du monde n'y est pas celle du
## témoin).
func _peindre_les_touches(t, k: int, chemin: String, d: Dictionary) -> void:
	Peinture_.nouveau_calque(chemin, "Brush")
	var img: Image = Peinture_.calque_actif(chemin)
	var taille := Vector2(img.get_size())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(d["nom"])
	var touches := 0
	for c in t.tuiles:
		var tu = t.tuiles[c]
		for f in tu.faces.size():
			if tu.mat(f) != k:
				continue
			var u: PackedVector2Array = tu.uv(f)
			var face: PackedInt32Array = tu.faces[f]
			if u.size() != face.size():
				continue
			var n: Vector3 = tu.normale(f)
			# L'aire de la face en pixels de la toile : combien de touches elle reçoit.
			var aire_px := 0.0
			for i in range(1, u.size() - 1):
				aire_px += absf((u[i] - u[0]).cross(u[i + 1] - u[0])) * 0.5
			aire_px *= taille.x * taille.y
			var nb := clampi(int(aire_px / 260.0), 1, 40)
			for s in nb:
				# Un point au hasard dans un triangle de l'éventail.
				var i := rng.randi_range(1, u.size() - 2)
				var a := rng.randf()
				var b := rng.randf()
				if a + b > 1.0:
					a = 1.0 - a
					b = 1.0 - b
				var p: Vector3 = tu.sommets[face[0]] + (tu.sommets[face[i]] - tu.sommets[face[0]]) * a \
					+ (tu.sommets[face[i + 1]] - tu.sommets[face[0]]) * b
				if maxf(absf(p.x), maxf(absf(p.y), absf(p.z))) > 0.5 - 0.1:
					continue
				var uv: Vector2 = u[0] + (u[i] - u[0]) * a + (u[i + 1] - u[0]) * b
				var px := Vector2(uv.x * taille.x, uv.y * taille.y)
				var couleur: Color
				var rayon := rng.randf_range(4.0, 9.0)
				if n.y > 0.6:
					couleur = d["clair"] if rng.randf() < 0.55 else d["sombre"]
					Peinture_.tamponner(img, px, rayon, couleur, 0.2, 0.45)
				elif n.y < -0.6:
					continue
				else:
					# Une strate : une traînée le long de l'horizontale de la paroi, vue dans l'atlas.
					var haut := p.y > 0.15
					couleur = d["paroi_clair"] if (haut or rng.randf() < 0.35) else d["paroi_sombre"]
					var h := Vector3(-n.z, 0, n.x).normalized() * 0.08
					var uv2 := _uv_au_point(tu, f, p + h, u)
					var px2 := Vector2(uv2.x * taille.x, uv2.y * taille.y) if uv2 != Vector2.INF else px
					Peinture_.trait_(img, px, px2, rayon * 0.6, couleur, 0.15, 0.4)
				touches += 1
	Peinture_.composer(chemin)
	print("  « Brush » : %d touches" % touches)


## L'UV d'un point du plan de la face (par les coordonnées barycentriques du triangle de l'éventail qui le contient).
static func _uv_au_point(tu, f: int, p: Vector3, u: PackedVector2Array) -> Vector2:
	var face: PackedInt32Array = tu.faces[f]
	for i in range(1, face.size() - 1):
		var a: Vector3 = tu.sommets[face[0]]
		var b: Vector3 = tu.sommets[face[i]]
		var c: Vector3 = tu.sommets[face[i + 1]]
		var v0 := b - a
		var v1 := c - a
		var v2 := p - a
		var d00 := v0.dot(v0)
		var d01 := v0.dot(v1)
		var d11 := v1.dot(v1)
		var d20 := v2.dot(v0)
		var d21 := v2.dot(v1)
		var den := d00 * d11 - d01 * d01
		if absf(den) < 1e-12:
			continue
		var bv := (d11 * d20 - d01 * d21) / den
		var bw := (d00 * d21 - d01 * d20) / den
		if bv >= -0.05 and bw >= -0.05 and bv + bw <= 1.05:
			return u[0] + (u[i] - u[0]) * bv + (u[i + 1] - u[0]) * bw
	return Vector2.INF


func _photo_temoin(nom: String) -> void:
	await _images(20)
	_photo("temoin_%s" % nom.to_lower())


func _photo(nom: String) -> void:
	var im := root.get_texture().get_image()
	if im != null:
		im.save_png(_photos.path_join(nom + ".png"))
		print("  photo : %s" % _photos.path_join(nom + ".png"))


# ── 2. LE MONDE : une île en terrasses ─────────────────────────────────────────────────────────────
##
## La mer à MER ; une plage de sable (Sand) au ras de l'eau ; des prairies (Meadow) en terrasses de deux cases, aux
## falaises de terre ; une montagne de pierre (Stone) au nord, dont un lac déborde en rivière et en cascades vers la mer.
## Chaque colonne est d'une seule matière ; là où le sable et l'herbe se touchent au même niveau, la transition les mêle.

const MER := 3
const RAYON_ILE := 34.0
const MONTAGNE := Vector2(-4, -14)
const LAC_HP := Vector2i(-4, -12)

var _bruit_hp := FastNoiseLite.new()
var _h_hp := {}       # Vector2i → hauteur du dessus (−1 : rien)
var _m_hp := {}       # Vector2i → nom de couche


func _hp_monde() -> void:
	await _ecran._changer_d_atelier("monde")
	_relief_hp()
	var par := {}
	for d in COUCHES_HP:
		par[d["nom"]] = {}
	for k in _h_hp:
		var h: int = _h_hp[k]
		for y in range(0, h + 1):
			par[_m_hp[k]][Vector3i(k.x, y, k.y)] = true
	for nom in par:
		_ecran._activer(_couche[nom])
		_ecran._appliquer({"poser": par[nom], "effacer": {}}, "Add")
		print("couche %s : %d cases" % [nom, (par[nom] as Dictionary).size()])
	_ecran._activer(_couche["Stone"])
	await _ecran._reparer_les_diagonales(false)
	await _images(2)
	# L'EAU, par le clic de l'atelier Fluids : la mer (épinglée puis posée), puis la rivière du lac de la montagne.
	await _ecran._changer_d_atelier("fluides")
	var large := Vector3i(int(RAYON_ILE) + 8, MER, 0)
	_ecran._eau_cliquee(large, MOUSE_BUTTON_LEFT)
	_ecran._eau_cliquee(large, MOUSE_BUTTON_LEFT)
	_ecran._eaux[_ecran._eau_active]["preset"] = "stylise"
	var hl: int = _h_hp[LAC_HP]
	_ecran._eau_cliquee(Vector3i(LAC_HP.x, hl + 1, LAC_HP.y), MOUSE_BUTTON_LEFT)
	for e in _ecran._eaux:
		print("eau %s (%s) : %d sources" % [e["nom"], e["preset"], (e["sources"] as Array).size()])
	await _ecran._recalculer_eau(false)
	await _ecran._changer_d_atelier("monde")
	# LA TRANSITION herbe / sable, allumée comme par sa case.
	var TR := preload("res://addons/marchingblocks_core/transitions.gd")
	var ida := str(_ecran._couches[_couche["Meadow"]]["id"])
	var idb := str(_ecran._couches[_couche["Sand"]]["id"])
	_ecran._transitions.allumer(TR.cle_de_paire(ida, idb), true)
	var ids := str(_ecran._couches[_couche["Stone"]]["id"])
	_ecran._transitions.allumer(TR.cle_de_paire(ida, ids), true)
	await _feuillage_hp()
	_ecran._enregistrer()


func _relief_hp() -> void:
	_bruit_hp.seed = 92
	_bruit_hp.frequency = 0.05
	_bruit_hp.fractal_octaves = 4
	var n := int(RAYON_ILE) + 6
	for x in range(-n, n + 1):
		for z in range(-n, n + 1):
			var k := Vector2i(x, z)
			var p := Vector2(x, z)
			var b := _bruit_hp.get_noise_2d(x, z)
			var r := p.length() / RAYON_ILE + b * 0.18
			var h := -1
			var m := "Sand"
			if r < 1.15:
				# Le fond de la mer, la plage, puis les terrasses de prairie (deux cases par marche).
				var continu := (1.0 - r) * 14.0 + b * 3.0
				if continu < 0.6:
					h = clampi(int(round(MER - 1 + continu * 1.5)), 0, MER - 1)
				elif continu < 2.2:
					h = MER + 1
				else:
					h = MER + 2 + 2 * int(floor((continu - 2.2) / 2.6))
					m = "Meadow"
				# La montagne : de la pierre, en gradins d'une case, et un lac dans son épaule.
				var dm := p.distance_to(MONTAGNE)
				if dm < 15.0:
					var hm := MER + 4 + (1.0 - dm / 15.0) * 18.0 + b * 2.0
					if hm > h:
						h = int(round(hm))
						m = "Stone" if h >= MER + 9 else m
				var dl := p.distance_to(Vector2(LAC_HP))
				if dl < 3.2:
					h = MER + 13
					m = "Stone"
				elif dl < 4.6:
					h = maxi(h, MER + 15)
					m = "Stone"
			if h >= 0:
				_h_hp[k] = h
				_m_hp[k] = m
	# Une échancrure dans le bord du lac, vers le sud : l'eau déborde et descend les gradins.
	for z in range(LAC_HP.y + 3, LAC_HP.y + 6):
		_h_hp[Vector2i(LAC_HP.x, z)] = MER + 13
	_sans_damier_hp()


## Aucun contact par une arête : dans chaque carré de quatre colonnes, si une diagonale est plus haute que l'autre
## entière, la plus haute de l'autre monte jusqu'à elle (charte §2 : le monde n'a pas de diagonale).
func _sans_damier_hp() -> void:
	var change := true
	var tours := 0
	while change and tours < 50:
		change = false
		tours += 1
		for k in _h_hp.keys():
			var a := k
			var b := k + Vector2i(1, 0)
			var c := k + Vector2i(0, 1)
			var d := k + Vector2i(1, 1)
			var ha: int = _h_hp.get(a, -1)
			var hb: int = _h_hp.get(b, -1)
			var hc: int = _h_hp.get(c, -1)
			var hd: int = _h_hp.get(d, -1)
			for paire in [[ha, hd, b, c, hb, hc, a], [hb, hc, a, d, ha, hd, b]]:
				var bas := mini(paire[0], paire[1])
				var haut_autre := maxi(paire[4], paire[5])
				if bas > haut_autre:
					var cible: Vector2i = paire[2] if paire[4] >= paire[5] else paire[3]
					_h_hp[cible] = bas
					_m_hp[cible] = _m_hp.get(paire[6], "Sand")
					change = true
					break


## LE FEUILLAGE : des arbres de Spirit3D (Tripo) sur les prairies, au pinceau de la règle (mode « free »). Sauté sans
## les fichiers (hors du PC).
const SPIRIT_HP := "D:/Spirit3D/HEART_WORLD/biomes/maps/"
const ARBRES_HP := [["biome_plains/obstacles/plains_tree_01/plains_tree_01.glb", 4.5],
	["biome_plains/obstacles/plains_tree_04/plains_tree_04.glb", 5.5],
	["biome_woodland/obstacles/woodland_tree_02/woodland_tree_02.glb", 6.0]]


func _feuillage_hp() -> void:
	if not FileAccess.file_exists(SPIRIT_HP + ARBRES_HP[0][0]):
		print("feuillage : Spirit3D absent, sauté")
		return
	await _ecran._changer_d_atelier("feuillage")
	var af = _ecran._feuillage
	var ids: Array = []
	for a in ARBRES_HP:
		_ecran._action_fichier = "feuillage"
		_ecran._fichier_choisi(SPIRIT_HP + a[0])
		ids.append(af.actif)
		af._regle("echelle", a[1])
	# Planter au clic, vu de haut : la souris au-dessus de chaque colonne choisie (le même chemin qu'un clic).
	_poser_camera(Vector3(0, 6, 0), 0.0, 1.45, 110.0)
	await _images(10)
	var cam: Camera3D = _vue.camera()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var poses := 0
	for k in _h_hp:
		if _m_hp[k] != "Meadow" or rng.randf() > 0.07:
			continue
		var h: int = _h_hp[k]
		af.activer(ids[rng.randi() % ids.size()])
		var ecran := cam.unproject_position(Vector3(k.x + 0.5, h + 1.0, k.y + 0.5))
		var n0: int = af.plants.size()
		af.coup(ecran, MOUSE_BUTTON_LEFT, 0)
		af.coup(ecran, MOUSE_BUTTON_LEFT, 2)
		poses += af.plants.size() - n0
	print("feuillage : %d arbres" % poses)
	await _ecran._changer_d_atelier("monde")


# ── 3. LES PHOTOS ──────────────────────────────────────────────────────────────────────────────────

func _hp_photos() -> void:
	await _ecran._changer_d_atelier("monde")
	await _images(30)
	for v in [["ile_sud", Vector3(0, 6, 0), 0.0, 0.62, 80.0], ["ile_est", Vector3(0, 6, -4), 1.7, 0.5, 62.0],
			["montagne", Vector3(-4, 12, -12), 0.6, 0.42, 30.0], ["plage", Vector3(18, 4, 18), -0.6, 0.32, 22.0]]:
		_poser_camera(v[1], v[2], v[3], v[4])
		await _images(40)
		_photo(v[0])
