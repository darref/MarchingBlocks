extends SceneTree
##
## BANC — les points chauds de l'étape 2 du cœur natif (charte §0, « le cœur C++ »), mesurés AVANT d'y toucher.
##
##   godot --headless --path . --script res://DEV_TOOLS/banc_points_chauds.gd
##
## Il ne juge rien : il chronomètre, en GDScript (MB_NATIF=0) ou avec le natif, ce qui coûte. Headless : sans carte
## graphique, les relectures GPU ne coûtent rien ici (la charte, « les lags d'une seconde »).

const CP := preload("res://addons/marchingblocks_core/cartes_pbr.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")
const Natif := preload("res://addons/marchingblocks_core/natif.gd")
const TR := preload("res://addons/marchingblocks_core/tranchage.gd")
const DC := preload("res://addons/marchingblocks_core/decoupe.gd")
const MB_ := preload("res://addons/marchingblocks_core/marching_blocks.gd")


func _initialize() -> void:
	print("=== BANC — points chauds (natif %s) ===" % ("actif" if Natif.noyau() != null else "éteint"))
	_cartes()
	_tranchage()
	_tranchage_detail()
	_eau()
	_eau_detail()
	quit(0)


func _chrono(quoi: String, f: Callable) -> Variant:
	var t := Time.get_ticks_usec()
	var r = f.call()
	print("   %-44s %8.1f ms" % [quoi, (Time.get_ticks_usec() - t) / 1000.0])
	return r


func _image(taille: int) -> Image:
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in taille:
		for x in taille:
			var v := 0.5 + 0.25 * sin(x * 0.05) * cos(y * 0.07) + rng.randf() * 0.2
			img.set_pixel(x, y, Color(v, v * 0.9, v * 0.7))
	return img


func _cartes() -> void:
	print("1. cartes PBR")
	var img := _image(1024)
	_chrono("generer 1024² en boucle", func(): return CP.generer(img, null, true))
	var tri := PackedVector2Array()
	for k in 200:
		var c := Vector2(fmod(k * 0.137, 1.0), fmod(k * 0.291, 1.0))
		tri.append_array([c, c + Vector2(0.05, 0.0), c + Vector2(0.0, 0.05)])
	var masque: Image = _chrono("masque_des_triangles (200)", func(): return CP.masque_des_triangles(tri, Vector2i(1024, 1024)))
	_chrono("dilater 1024²", func(): return CP.dilater(img, masque))
	_chrono("generer 1024² avec masque", func(): return CP.generer(img, null, false, masque))


func _tranchage() -> void:
	print("2. tranchage du témoin")
	_chrono("BlocsMaitres.tuiles_du_temoin", func(): return BM.tuiles_du_temoin())


func _eau() -> void:
	print("3. l'eau, sur un monde de collines 160 × 160")
	var occ := {}
	for x in 160:
		for z in 160:
			var h := 4 + int((sin(x * 0.09) + cos(z * 0.07)) * 3.0)
			for y in h:
				occ[Vector3i(x, y, z)] = true
	var sources: Array = [Vector3i(-5, 3, -5)]
	for k in 30:
		sources.append(Vector3i(10 + (k * 37) % 140, 12, 10 + (k * 53) % 140))
	var w: Dictionary = _chrono("FL.monde (une mer, 30 sources)", func(): return FL.monde(occ, sources))
	_chrono("EauMaillage.maillage", func(): return EM.maillage(w["corps"], occ))


## Le tranchage, décomposé : la découpe seule (52 boîtes sur le bloc aminci), puis les contrôles.
func _tranchage_detail() -> void:
	var mesh: ArrayMesh = _chrono("maillage_moitie (le bloc aminci)", func(): return BM.maillage_moitie(0))
	var sources: Dictionary = BM.tuiles_du_temoin()
	DC.memoriser(true)
	_chrono("Decoupe.trancher × %d" % sources.size(), func():
		for cle in sources:
			var v: Vector3i = sources[cle]["sommet"]
			DC.trancher(mesh, TR.boite_du_sommet(v, 1.0))
		return null)
	DC.memoriser(false)
	var pieces := {}
	var vues := {}
	for cle in sources:
		pieces[cle] = sources[cle]["mesh"]
		vues[cle] = MB_.classes()[MB_.classer(MB_.bits(TR.occupation(Vector3i.ONE * BM.COTE, BM.creuses(0)), sources[cle]["sommet"]))["classe"]]["bits"]
	var rem: Array = []
	var err: Array = []
	_chrono("verifier_octants", func(): TR.verifier_octants(pieces, vues, err); return null)
	_chrono("verifier_couture", func(): TR.verifier_couture(pieces, vues, rem); return null)
	_chrono("verifier_sections", func(): TR.verifier_sections(pieces, vues, rem); return null)
	_chrono("verifier_couture_texture", func(): TR.verifier_couture_texture(pieces, rem); return null)


## Le maillage de l'eau, décomposé : un premier appel (tout à faire), puis l'état stable d'un geste (la mémoire sert).
func _eau_detail() -> void:
	print("4. l'eau, décomposée")
	var occ := {}
	for x in 160:
		for z in 160:
			var h := 4 + int((sin(x * 0.09) + cos(z * 0.07)) * 3.0)
			for y in h:
				occ[Vector3i(x, y, z)] = true
	var sources: Array = [Vector3i(-5, 3, -5)]
	for k in 30:
		sources.append(Vector3i(10 + (k * 37) % 140, 12, 10 + (k * 53) % 140))
	var w: Dictionary = FL.monde(occ, sources)
	var erreurs := 0
	for r in w["corps"]:
		if r == null or r["erreur"] != "":
			erreurs += 1
	print("   corps : %d, en erreur : %d" % [(w["corps"] as Array).size(), erreurs])
	var b: Dictionary = FL.boite(occ)
	var memoire := {}
	_chrono("maillage, premier appel (mémoire vide)", func(): return EM.maillage(w["corps"], occ, b, memoire))
	_chrono("maillage, second appel (mémoire pleine)", func(): return EM.maillage(w["corps"], occ, b, memoire))
	var plats: Array = []
	for j in (w["corps"] as Array).size():
		var r = w["corps"][j]
		if r != null and r["erreur"] == "":
			plats.append_array(EM._nappes_du_corps(r, occ, b))
	print("   plats : %d" % plats.size())
	_chrono("_poser_les_plats", func(): EM._poser_les_plats(EM._tableaux(), plats); return null)
	_chrono("_nappes_du_corps (tous)", func():
		for r in w["corps"]:
			if r != null and r["erreur"] == "":
				EM._nappes_du_corps(r, occ, b)
		return null)
