extends SceneTree
##
## TEST — le cœur natif (C++, GDExtension) rend EXACTEMENT ce que rend le GDScript.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_natif.gd
##
## ⚠ L'ATTENDU EST LE GDSCRIPT, JAMAIS LE NATIF (charte §6 : un test ne calcule pas son attendu avec la fonction
## qu'il éprouve). Chaque comparaison éteint `Natif.actif`, calcule, le rallume, recalcule — et exige la même sortie
## au caractère près (`str`, donc les clés DANS LE MÊME ORDRE), pas seulement des contenus égaux.
##
## ⚠ UNE BIBLIOTHÈQUE ABSENTE EST UN ÉCHEC, pas un saut : sans elle, toutes les comparaisons opposeraient le GDScript
## à lui-même et passeraient (le compteur vert du §6). Construire : `gdextension/`, `scons`.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const RP := preload("res://addons/marchingblocks_core/repli_procedural.gd")
const Natif := preload("res://addons/marchingblocks_core/natif.gd")
const Peint := preload("res://addons/marchingblocks_core/massif_peint.gd")
const CP := preload("res://addons/marchingblocks_core/cartes_pbr.gd")
const DC := preload("res://addons/marchingblocks_core/decoupe.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")

var _ok := 0
var _echecs := 0
var _premier := ""
var _sections := 0


func _initialize() -> void:
	print("=== TEST — le cœur natif rend ce que rend le GDScript ===\n")
	if not Natif.disponible():
		_dire(false, "la bibliothèque native n'est pas chargée (%s) — construire gdextension/" % Natif.CHEMIN)
		_fin()
		return
	print("   bibliothèque : %s" % Natif.noyau().version())
	_la_regle_de_pose()
	_les_couches()
	_les_utilitaires()
	_le_massif_complet_et_local()
	_le_massif_en_couches()
	_l_ocean()
	_les_cartes_pbr()
	_la_decoupe()
	_le_maillage_de_l_eau()
	_le_monde_du_coeur()
	_le_monde_branche()
	_dire(_sections == 11, "toutes les sections sont allées au bout (%d sur 11) — une erreur d'exécution en a arrêté une"
		% _sections)
	_mesurer()
	_fin()


func _fin() -> void:
	Natif.actif = true
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	if _echecs > 0:
		print("PREMIER ÉCHEC — %s" % _premier)
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _dire(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_echecs += 1
		if _premier == "":
			_premier = quoi
		print("   ✗ " + quoi)


## La même chose, calculée en GDScript (l'attendu) puis par le natif.
func _les_deux(f: Callable) -> Array:
	Natif.actif = false
	var attendu = f.call()
	Natif.actif = true
	var natif = f.call()
	return [attendu, natif]


func _pareil(f: Callable, quoi: String) -> void:
	var r := _les_deux(f)
	var a := str(r[0])
	var b := str(r[1])
	var ecart := ""
	if a != b:
		var i := 0
		while i < mini(a.length(), b.length()) and a[i] == b[i]:
			i += 1
		ecart = " — premier écart au caractère %d : …%s… contre …%s…" % [i, a.substr(maxi(0, i - 40), 90),
			b.substr(maxi(0, i - 40), 90)]
	_dire(a == b, "%s : le natif diffère du GDScript (%d contre %d caractères)%s" % [quoi, a.length(), b.length(),
		ecart])


# ── les mondes ────────────────────────────────────────────────────────────────────────────────────────

## Un monde au hasard qui exerce tout : relief, falaises de plusieurs cases (le ciel), surplombs, grottes, dalles
## flottantes, contacts par une arête (des fautes), coordonnées négatives.
func _monde(graine: int, cote: int, haut: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var pleines := {}
	var x0 := -cote / 2
	for x in range(x0, x0 + cote):
		for z in range(x0, x0 + cote):
			var h := int(2 + (sin(x * 0.35 + graine) + cos(z * 0.27)) * haut * 0.25 + rng.randi_range(0, 2))
			for y in range(-2, h):
				pleines[Vector3i(x, y, z)] = true
	for k in cote:
		var c := Vector3i(rng.randi_range(x0, x0 + cote), rng.randi_range(-1, haut), rng.randi_range(x0, x0 + cote))
		match rng.randi_range(0, 3):
			0:  # une grotte
				for d in 4:
					pleines.erase(c + Vector3i(d, 0, 0))
					pleines.erase(c + Vector3i(d, 1, 0))
			1:  # une dalle flottante
				for dx in 3:
					for dz in 3:
						pleines[c + Vector3i(dx, haut, dz)] = true
			2:  # un contact par une arête
				pleines[c] = true
				pleines[c + Vector3i(1, 1, 0)] = true
				pleines.erase(c + Vector3i(1, 0, 0))
				pleines.erase(c + Vector3i(0, 1, 0))
			_:  # une case seule en l'air
				pleines[c + Vector3i(0, haut + 2, 0)] = true
	return pleines


## Des clés comme un lot : une sur sept manque (des fautes), les variantes d'air libre, deux variantes voulues.
func _cles(trous: int) -> Dictionary:
	var cles := {}
	var id := 0
	var n := 0
	for c in MB.classes():
		var nom: String = c["nom"]
		if not MB.porte_une_surface(c["bits"]):
			continue
		n += 1
		if trous > 0 and n % trous == 0:
			continue
		for nom_pose in [nom, MB.nom_en_contexte(nom, true)]:
			cles[nom_pose] = id
			id += 1
			if n % 5 == 0:
				for k in [1, 2]:
					cles[MB.nom_de_variante(nom_pose, k)] = id
					id += 1
	return cles


# ── 1. la règle de pose ───────────────────────────────────────────────────────────────────────────────

func _la_regle_de_pose() -> void:
	print("1. MB.poses")
	var fautes := 0
	var dehors := 0
	for graine in 6:
		var pleines := _monde(graine, 14 + graine * 3, 8)
		for trous in [0, 7]:
			var cles := _cles(trous)
			_pareil(func(): return MB.poses(pleines, cles), "poses, monde %d, trous %d" % [graine, trous])
			for d in MB.poses(pleines, cles):
				if d["cle"] == "":
					fautes += 1
				if d["dehors"]:
					dehors += 1
	_pareil(func(): return MB.poses({}, _cles(0)), "poses d'un monde vide")
	_dire(fautes > 0 and dehors > 0, "les mondes doivent exercer les fautes ET l'air libre (%d, %d)" % [fautes, dehors])
	_sections += 1


func _les_couches() -> void:
	print("2. MB.poses_en_couches")
	for graine in 4:
		var pleines := _monde(100 + graine, 16, 8)
		var union := {}
		var rng := RandomNumberGenerator.new()
		rng.seed = graine
		for c in pleines:
			union[c] = rng.randi_range(0, 2) if (c.x + c.z) % 3 != 0 else int(c.y > 3)
		var par_couche: Array = [_cles(0), _cles(7), _cles(3)]
		_pareil(func(): return MB.poses_en_couches(union, par_couche), "poses en couches, monde %d" % graine)
	_sections += 1


func _les_utilitaires() -> void:
	print("3. plafond, hauts des colonnes, contacts par une arête, boîte")
	for graine in 4:
		var pleines := _monde(200 + graine, 18, 9)
		_pareil(func(): return MB.plafond_de(pleines), "plafond_de")
		_pareil(func(): return MB.hauts_des_colonnes(pleines), "hauts_des_colonnes")
		_pareil(func(): return MB.contacts_par_arete(pleines), "contacts_par_arete")
		_pareil(func(): return MB.contacts_par_arete(pleines, 6), "contacts_par_arete bornés à 6")
		_pareil(func(): return FL.boite(pleines), "FL.boite")
	_pareil(func(): return MB.plafond_de({}), "plafond_de d'un monde vide")
	_dire(MB.contacts_par_arete(_monde(203, 18, 9)) > 0, "les mondes doivent porter des contacts par une arête")
	_sections += 1


# ── 4. le massif : reconstruction complète et locale ──────────────────────────────────────────────────

func _lot(cles: Dictionary) -> MeshLibrary:
	var source: MeshLibrary = RP.librairie()
	var lot := MeshLibrary.new()
	var mesh: Mesh = source.get_item_mesh(source.get_item_list()[0])
	for nom in cles:
		lot.create_item(cles[nom])
		lot.set_item_name(cles[nom], nom)
		lot.set_item_mesh(cles[nom], mesh)
	return lot


func _massif(lot: MeshLibrary, cellules: Dictionary) -> Node3D:
	var m: Node3D = Peint.new()
	root.add_child(m)
	m.preparer()
	m.lot = lot
	var cases: GridMap = m.get_node("Cases")
	var id: int = cases.mesh_library.find_item_by_name("case")
	for c in cellules:
		cases.set_cell_item(c, id)
	return m


## Tout ce qu'un massif montre : ses deux grilles (item ET orientation), son bilan, son état (ordre compris).
func _photo(m: Node3D) -> String:
	var t := PackedStringArray()
	for nom in ["Rendu", "Fautes"]:
		var g: GridMap = m.get_node(nom)
		var cs := g.get_used_cells()
		cs.sort()
		for c in cs:
			t.append("%s%s:%d/%d" % [nom[0], c, g.get_cell_item(c), g.get_cell_item_orientation(c)])
	t.append(str(m.dernier_bilan()))
	t.append(str(m._etat))
	t.append(str([m._plafond, m._y_bas, m._colonnes_miennes, m._etages_miens, m._miennes.size()]))
	t.append(str(m._empreinte))
	return "\n".join(t)


func _le_massif_complet_et_local() -> void:
	print("4. le massif : reconstruction complète, puis 120 gestes locaux")
	# ⚠ ASSEZ GRAND pour que la route locale native prenne SES DEUX chemins : lire le Dictionary (un geste d'une
	# case) et le recopier (un coup de trente) — gardé plus bas par `routes()`.
	var cellules := _monde(300, 34, 8)
	var cles := _cles(7)
	var lot := _lot(cles)
	Natif.actif = false
	var gd := _massif(lot, cellules)
	gd.poids = {cles.keys()[10]: [2, 1, 0], cles.keys()[20]: [-1, 3, 1]}
	gd.reconstruire()
	# ⚠ DES CHOIX QUI CHANGENT QUELQUE CHOSE : sur des sommets dont la clé a des variantes, le rang que le tirage
	# n'a PAS donné (sinon ignorer les choix passerait inaperçu).
	var choix := {}
	for s in gd._etat:
		var d: Dictionary = gd._etat[s]
		if d.is_empty() or d["cle"] == "" or not cles.has(MB.nom_de_variante(d["cle"], 2)):
			continue
		var tire := MB.rang_de_variante(d["tuile"])
		choix[s] = (tire + 1) % 3
		if choix.size() >= 12:
			break
	gd.choix = choix
	gd.reconstruire()
	Natif.actif = true
	var na := _massif(lot, cellules)
	na.poids = gd.poids.duplicate(true)
	na.choix = gd.choix.duplicate()
	na.reconstruire()
	var a := _photo(gd)
	_dire(a == _photo(na), "reconstruction complète : le natif diffère du GDScript")
	_dire(int(gd.dernier_bilan()["fautes"]) > 0 and int(gd.dernier_bilan()["dehors"]) > 0,
		"le monde doit exercer les fautes et l'air libre : %s" % gd.dernier_bilan())
	var variantes := 0
	for s in gd._etat:
		if str((gd._etat[s] as Dictionary).get("tuile", "")).contains("_var"):
			variantes += 1
	_dire(variantes > 0, "le monde doit poser des variantes (%d)" % variantes)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261006
	var id: int = (gd.get_node("Cases") as GridMap).mesh_library.find_item_by_name("case")
	var ecarts := 0
	var premier := ""
	var completes_avant: int = na.reconstructions_completes
	var routes_avant: Dictionary = Natif._noyau.routes()
	for g in 120:
		var changees: Array = []
		for j in (1 if rng.randf() < 0.7 else rng.randi_range(2, 30)):
			var p := Vector3i(rng.randi_range(-9, 9), rng.randi_range(-3, 12), rng.randi_range(-9, 9))
			var item: int = id if rng.randf() < 0.5 else GridMap.INVALID_CELL_ITEM
			for m in [gd, na]:
				(m.get_node("Cases") as GridMap).set_cell_item(p, item)
			changees.append(p)
		Natif.actif = false
		gd.reconstruire_autour(changees)
		Natif.actif = true
		na.reconstruire_autour(changees)
		if _photo(gd) != _photo(na):
			ecarts += 1
			if premier == "":
				premier = "geste %d (%s)" % [g, changees]
	_dire(ecarts == 0, "%d geste(s) sur 120 où le natif diffère — %s" % [ecarts, premier])
	var routes: Dictionary = Natif._noyau.routes()
	_dire(int(routes["dict"]) > int(routes_avant["dict"]) and int(routes["copie"]) > int(routes_avant["copie"]),
		"les gestes doivent exercer les deux chemins de la route locale native : %s → %s" % [routes_avant, routes])
	_dire(na.reconstructions_completes == completes_avant,
		"la route locale native n'a pas été prise (%d complètes)" % (na.reconstructions_completes - completes_avant))
	# Les choix d'un sommet, refaits seuls (`reconstruire_sommets`).
	var s: Vector3i = choix.keys()[0]
	var avant_choix: String = gd.tuile_posee(s)
	for m in [gd, na]:
		m.choix[s] = (MB.rang_de_variante(avant_choix) + 1) % 3
	Natif.actif = false
	gd.reconstruire_sommets([s])
	Natif.actif = true
	na.reconstruire_sommets([s])
	_dire(_photo(gd) == _photo(na), "reconstruire_sommets : le natif diffère")
	_dire(choix.size() >= 12 and gd.tuile_posee(s) != avant_choix and avant_choix != "",
		"les choix doivent changer des tuiles (%d choix ; %s → %s)" % [choix.size(), avant_choix, gd.tuile_posee(s)])
	gd.free()
	na.free()
	_sections += 1


func _le_massif_en_couches() -> void:
	print("5. le massif en couches (l'union partagée)")
	var monde := _monde(400, 34, 8)   # assez grand pour que le geste d'une case lise le Dictionary (l'union, ses rangs)
	var cles := _cles(0)
	var lots: Array = [_lot(cles), _lot(_cles(7))]
	var photos: Array = []
	for natif in [false, true]:
		Natif.actif = natif
		var union := {}
		var couches: Array = []
		for r in 2:
			var miennes := {}
			for c in monde:
				if (c.x + 100) % 2 == r or c.y > 5:
					if not union.has(c):
						union[c] = r
						miennes[c] = true
			var m := _massif(lots[r], miennes)
			m.union = union
			m.rang = r
			couches.append(m)
		for m in couches:
			m.reconstruire()
		var t := ""
		for m in couches:
			t += _photo(m)
		# Un geste : la couche 1 prend une case à la couche 0, puis on refait les deux autour.
		var p := Vector3i(0, 5, 0)
		union[p] = 1
		(couches[0].get_node("Cases") as GridMap).set_cell_item(p, GridMap.INVALID_CELL_ITEM)
		(couches[1].get_node("Cases") as GridMap).set_cell_item(p,
			(couches[1].get_node("Cases") as GridMap).mesh_library.find_item_by_name("case"))
		var avant_r: Dictionary = Natif._noyau.routes()
		for m in couches:
			m.reconstruire_autour([p])
		if natif:
			_dire(int(Natif._noyau.routes()["dict"]) >= int(avant_r["dict"]) + 2,
				"en couches, le geste d'une case doit lire l'union telle quelle (%s → %s)" % [avant_r, Natif._noyau.routes()])
		for m in couches:
			t += _photo(m)
			m.free()
		photos.append(t)
	Natif.actif = true
	_dire(photos[0] == photos[1], "en couches : le natif diffère du GDScript")
	_sections += 1


# ── 6. l'océan ────────────────────────────────────────────────────────────────────────────────────────

func _l_ocean() -> void:
	print("6. FL.ocean")
	var tronçons := 0
	for graine in 5:
		var pleines := _monde(500 + graine, 20, 8)
		var b: Dictionary = FL.boite(pleines)
		for niveau in [b["lo"].y - 1, b["lo"].y, 2, 5, 40]:
			_pareil(func(): return FL.ocean(pleines, niveau), "ocean, monde %d, niveau %d" % [graine, niveau])
			tronçons += (FL.ocean(pleines, niveau)["colonnes"] as Array).size()
		# Une boîte donnée plus grande que celle des cases (la boîte tenue par l'écran).
		var large := {"lo": b["lo"] - Vector3i(3, 0, 2), "hi": b["hi"] + Vector3i(1, 4, 5)}
		_pareil(func(): return FL.ocean(pleines, 4, FL.VOLUME_MAXI, large), "ocean dans une boîte élargie")
	_pareil(func(): return FL.ocean({}, 3), "ocean d'un monde vide")
	_dire(tronçons > 100, "les océans doivent avoir des tronçons (%d)" % tronçons)
	_sections += 1


# ── 7. les cartes PBR (étape 2) ───────────────────────────────────────────────────────────────────────

## Une image de bruit et de motifs, aux dimensions données (non carrées, impaires : les bords comptent).
func _image(w: int, h: int, graine: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	for y in h:
		for x in w:
			var v := 0.5 + 0.3 * sin(x * 0.21 + graine) * cos(y * 0.17) + rng.randf() * 0.25 - 0.1
			img.set_pixel(x, y, Color(clampf(v, 0, 1), clampf(v * rng.randf(), 0, 1), clampf(1.0 - v, 0, 1)))
	return img


## Des triangles UV au hasard : petits, grands, hors de [0, 1], dégénérés, dans les deux sens.
func _triangles(graine: int, n: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var t := PackedVector2Array()
	for k in n:
		var c := Vector2(rng.randf_range(-0.1, 1.1), rng.randf_range(-0.1, 1.1))
		var e := rng.randf_range(0.002, 0.2)
		var a := c + Vector2(rng.randf_range(-e, e), rng.randf_range(-e, e))
		var b := c + Vector2(rng.randf_range(-e, e), rng.randf_range(-e, e))
		if k % 11 == 0:
			b = c.lerp(a, 0.5)   # dégénéré
		t.append_array([c, a, b])
	return t


func _octets_differents(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size() or a.get_format() != b.get_format():
		return -1
	var da := a.get_data()
	var db := b.get_data()
	var n := 0
	for i in da.size():
		if da[i] != db[i]:
			n += 1
	return n


func _cartes_pareilles(f: Callable, quoi: String) -> void:
	var r := _les_deux(f)
	for nom in ["hauteur", "normale", "orm"]:
		var e := _octets_differents(r[0][nom], r[1][nom])
		_dire(e == 0, "%s, %s : %d octet(s) différent(s) du GDScript (−1 : taille ou format)" % [quoi, nom, e])


func _les_cartes_pbr() -> void:
	print("7. les cartes PBR")
	for dims in [Vector2i(64, 64), Vector2i(97, 61), Vector2i(128, 40)]:
		var img := _image(dims.x, dims.y, dims.x)
		_cartes_pareilles(func(): return CP.generer(img, null, true), "generer en boucle %s" % dims)
		_cartes_pareilles(func(): return CP.generer(img, {"inverser": true, "contraste": 2.3, "normale": 9.0,
			"occlusion": 1.7, "rugosite": 0.4, "variation": 0.9}, false), "generer sans boucle, réglés %s" % dims)
		var masque := CP.masque_des_triangles(_triangles(dims.y, 30), dims)
		_cartes_pareilles(func(): return CP.generer(img, null, false, masque), "generer avec masque %s" % dims)
	# Le masque, sur des triangles de toutes sortes.
	for graine in 4:
		var tri := _triangles(100 + graine, 60)
		var r := _les_deux(func(): return CP.masque_des_triangles(tri, Vector2i(83, 71)))
		var e := _octets_differents(r[0], r[1])
		_dire(e == 0, "masque_des_triangles %d : %d octet(s) différent(s)" % [graine, e])
	# ⚠ LES ÉGALITÉS EXACTES (une mutation `<= 1.0` → `< 1.0` restait muette sur des triangles au hasard) : des
	# sommets aux demi-texels d'une image de 64 — des flottants exacts —, des centres de texels à 1,0 pile d'un bord.
	var exacts := PackedVector2Array()
	for k in 6:
		var x0 := (10.5 + k * 8) / 64.0
		exacts.append_array([Vector2(x0, 10.5 / 64.0), Vector2(x0 + 4.0 / 64.0, 10.5 / 64.0), Vector2(x0, 20.5 / 64.0)])
	var re := _les_deux(func(): return CP.masque_des_triangles(exacts, Vector2i(64, 64)))
	var ee := _octets_differents(re[0], re[1])
	_dire(ee == 0, "masque_des_triangles aux égalités exactes : %d octet(s) différent(s)" % ee)
	# La dilatation, sur un masque gris (couvertures partielles : la branche du mélange).
	var img := _image(90, 70, 3)
	var gris := Image.create(90, 70, false, Image.FORMAT_L8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var partiels := 0
	for y in 70:
		for x in 90:
			var v := 0.0
			if (x / 9 + y / 7) % 3 == 0:
				v = [1.0, rng.randf(), 0.0][rng.randi_range(0, 2)]
			if v > 0.0 and v < 1.0:
				partiels += 1
			gris.set_pixel(x, y, Color(v, v, v))
	var rd := _les_deux(func(): return CP.dilater(img, gris))
	var ed := _octets_differents(rd[0], rd[1])
	_dire(ed == 0 and partiels > 50, "dilater : %d octet(s) différent(s), %d texels partiels" % [ed, partiels])
	_sections += 1


# ── 8. la découpe (étape 2) ───────────────────────────────────────────────────────────────────────────

## Un maillage de triangles au hasard, normales, UV et couleurs, indexé ou non (les deux chemins de la lecture).
func _soupe(graine: int, indexe: bool, avec_attributs: bool) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	for k in 300:
		var p := Vector3(rng.randf_range(-1, 3), rng.randf_range(-1, 3), rng.randf_range(-1, 3))
		v.append(p)
		n.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized())
		uv.append(Vector2(rng.randf(), rng.randf()))
		c.append(Color(rng.randf(), rng.randf(), rng.randf()))
	# Des sommets posés PILE sur les plans de coupe (les triangles plats de la découpe naissent là).
	for k in 30:
		v[k] = Vector3(float(rng.randi_range(0, 2)), v[k].y, float(rng.randi_range(0, 2)))
	# ⚠ ET À MOINS DE 10⁻⁶ D'UN PLAN, CÔTÉ DEHORS : la tolérance `EPS` les garde (une mutation `>= 0` restait muette).
	for k in range(30, 60):
		var d := -4e-7 if k % 2 == 0 else 4e-7
		v[k] = Vector3(float(rng.randi_range(0, 1)) + (d if k % 4 < 2 else -d), v[k].y, v[k].z)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	if avec_attributs:
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_TEX_UV] = uv
		a[Mesh.ARRAY_COLOR] = c
	if indexe:
		var idx := PackedInt32Array()
		for k in 900:
			idx.append(rng.randi_range(0, 299))
		a[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


func _tableaux_du_maillage(m: ArrayMesh) -> String:
	var t := PackedStringArray()
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR]:
			t.append(var_to_str(a[k]))
	return "\n".join(t)


func _la_decoupe() -> void:
	print("8. Decoupe.trancher")
	var boites: Array = [AABB(Vector3(0, 0, 0), Vector3(1, 1, 1)), AABB(Vector3(0.5, -0.3, 1), Vector3(1.2, 2, 0.7)),
		AABB(Vector3(-0.25, 0.4, -0.1), Vector3(2.5, 0.6, 3))]
	var coupes := 0
	for indexe in [true, false]:
		for attributs in [true, false]:
			var m := _soupe(7 + int(indexe) * 2 + int(attributs), indexe, attributs)
			for b in boites:
				var r := _les_deux(func(): return _tableaux_du_maillage(DC.trancher(m, b)))
				_dire(r[0] == r[1], "trancher une soupe (indexée %s, attributs %s) par %s : le natif diffère"
					% [indexe, attributs, b])
				coupes += (r[0] as String).length()
	# Le vrai bloc : les boîtes des 52 sommets du témoin, sur l'aminci.
	var bloc := BM.maillage_moitie(0)
	var tuiles: Dictionary = BM.tuiles_du_temoin()
	var ecarts := 0
	var premier := ""
	for cle in tuiles:
		var v: Vector3i = tuiles[cle]["sommet"]
		var b := AABB(Vector3(v) + Vector3(0.5, 0.5, 0.5), Vector3.ONE)
		var r := _les_deux(func(): return _tableaux_du_maillage(DC.trancher(bloc, b)))
		if r[0] != r[1]:
			ecarts += 1
			if premier == "":
				premier = cle
	_dire(ecarts == 0, "trancher le témoin : %d tuile(s) sur %d où le natif diffère (%s)" % [ecarts, tuiles.size(), premier])
	_dire(coupes > 1000, "les soupes doivent laisser des morceaux (%d)" % coupes)
	_sections += 1


# ── 9. le maillage de l'eau (étape 2) ─────────────────────────────────────────────────────────────────

func _le_maillage_de_l_eau() -> void:
	print("9. EauMaillage.maillage (les plats)")
	var occ := {}
	for x in 48:
		for z in 48:
			var h := 4 + int((sin(x * 0.19) + cos(z * 0.13)) * 3.0)
			for y in h:
				occ[Vector3i(x, y, z)] = true
	# Une dalle flottante (la nappe sous un étage) et une cuvette.
	for x in range(20, 26):
		for z in range(20, 26):
			occ[Vector3i(x, 12, z)] = true
	var sources: Array = [Vector3i(-3, 3, -3)]
	for k in 12:
		sources.append(Vector3i(4 + (k * 13) % 40, 12, 4 + (k * 29) % 40))
	var w: Dictionary = FL.monde(occ, sources)
	var cascades := 0
	for r in w["corps"]:
		if r != null and r["erreur"] == "" and r["genre"] == "riviere":
			cascades += 1
	var b: Dictionary = FL.boite(occ)
	var r2 := _les_deux(func():
		var m: ArrayMesh = EM.maillage(w["corps"], occ, b)
		return _tableaux_du_maillage(m) + var_to_str(m.surface_get_arrays(0)[Mesh.ARRAY_INDEX]))
	_dire(r2[0] == r2[1], "le maillage de l'eau : le natif diffère du GDScript (%d contre %d caractères)"
		% [(r2[0] as String).length(), (r2[1] as String).length()])
	_dire(cascades > 0, "le monde doit porter des rivières (et leurs cascades) : %d" % cascades)
	_sections += 1


# ── 10. le monde du cœur (mbcore::World, par MBMonde) ─────────────────────────────────────────────────

## Les grilles d'une couche du monde natif, comme `_photo` les lit d'un massif.
func _photo_grilles(rendu: GridMap, fautes: GridMap) -> String:
	var t := PackedStringArray()
	for paire in [["R", rendu], ["F", fautes]]:
		var g: GridMap = paire[1]
		var cs := g.get_used_cells()
		cs.sort()
		for c in cs:
			t.append("%s%s:%d/%d" % [paire[0], c, g.get_cell_item(c), g.get_cell_item_orientation(c)])
	return "\n".join(t)


func _photo_massif(m: Node3D) -> String:
	return _photo_grilles(m.get_node("Rendu"), m.get_node("Fautes"))


## L'ATTENDU EST L'APPLI EN GDSCRIPT : trois massifs qui partagent l'union, menés comme l'écran les mène (une case
## posée la retire des autres couches, `reconstruire_autour` de chaque couche visible ; cacher, déplacer : l'union
## refaite et chaque couche reconstruite). Le monde natif ne reçoit que les mêmes gestes, et ses grilles ne
## reçoivent que ses DIFFS. Après chaque geste, chaque couche doit montrer la même chose, case pour case.
func _le_monde_du_coeur() -> void:
	print("10. le monde du cœur (mbcore::World) : 80 gestes, l'appli en GDScript contre les diffs du natif")
	var monde_ := _monde(500, 30, 8)
	var cles_par: Array = [_cles(0), _cles(7), _cles(3)]
	var lots: Array = []
	for c in cles_par:
		lots.append(_lot(c))
	var couche_de := func(c: Vector3i) -> int:
		return 2 if c.y > 5 else int(posmod(int(floor((c.x + c.z) / 5.0)), 2))
	var parts: Array = [{}, {}, {}]
	for c in monde_:
		parts[couche_de.call(c)][c] = true
	# L'appli (GDScript).
	Natif.actif = false
	var union := {}
	var massifs: Array = []
	for r in 3:
		var m := _massif(lots[r], parts[r])
		massifs.append(m)
	var visibles: Array = [true, true, true]
	var refaire_l_union := func() -> void:
		union.clear()
		for i in range(massifs.size() - 1, -1, -1):
			var m: Node3D = massifs[i]
			m.union = union
			m.rang = i
			if visibles[i]:
				for c in (m.get_node("Cases") as GridMap).get_used_cells():
					union[c] = i
		for i in massifs.size():
			if visibles[i]:
				massifs[i].reconstruire()
			else:
				(massifs[i].get_node("Rendu") as GridMap).clear()
				(massifs[i].get_node("Fautes") as GridMap).clear()
	refaire_l_union.call()
	# ⚠ DES POIDS QUI CHANGENT QUELQUE CHOSE : sur les deux clés à variantes que la couche 1 pose le plus (des clés
	# prises au hasard dans le lot n'avaient pas de variantes, et « poids ignorés » restait muette).
	var vues := {}
	for v in massifs[1]._etat:
		var d: Dictionary = massifs[1]._etat[v]
		if not d.is_empty() and d["cle"] != "" and cles_par[1].has(MB.nom_de_variante(d["cle"], 2)):
			vues[d["cle"]] = int(vues.get(d["cle"], 0)) + 1
	var plus_vues: Array = vues.keys()
	plus_vues.sort_custom(func(a, b): return vues[a] > vues[b])
	_dire(plus_vues.size() >= 2, "la couche 1 doit poser deux clés à variantes (%d)" % plus_vues.size())
	massifs[1].poids = {plus_vues[0]: [0, 1, 3], plus_vues[1]: [5, 0, -2]}
	refaire_l_union.call()
	# Le monde natif.
	Natif.actif = true
	var mn = MB.monde_natif()
	_dire(mn != null, "MB.monde_natif() rend un monde (la classe MBMonde est enregistrée)")
	if mn == null:
		return
	var rendus: Array = []
	var fautes_: Array = []
	var id_faute: int = massifs[0]._id_faute
	for r in 3:
		mn.ajouter_couche()
		mn.definir_tuiles(r, cles_par[r], massifs[r].poids)
		var g := GridMap.new()
		g.mesh_library = lots[r]
		var f := GridMap.new()
		f.mesh_library = (massifs[r].get_node("Fautes") as GridMap).mesh_library
		root.add_child(g)
		root.add_child(f)
		rendus.append(g)
		fautes_.append(f)
	for r in 3:
		mn.appliquer(mn.poser(r, parts[r].keys()), rendus, fautes_, id_faute)
	var photo := func() -> String:
		var t := ""
		for r in 3:
			t += "couche %d\n%s\n" % [r, _photo_massif(massifs[r])]
		return t
	var photo_natif := func() -> String:
		var t := ""
		for r in 3:
			t += "couche %d\n%s\n" % [r, _photo_grilles(rendus[r], fautes_[r])]
		return t
	_dire(photo.call() == photo_natif.call(), "le monde bâti : les couches du natif diffèrent de l'appli")
	_dire(mn.nombre_de_cases(-1) == monde_.size(), "le monde natif porte toutes les cases (%d sur %d)"
		% [mn.nombre_de_cases(-1), monde_.size()])

	var rng := RandomNumberGenerator.new()
	rng.seed = 6102026
	var ecarts := 0
	var premier := ""
	var sortes := {}
	var decides := 0
	var poses_vues := 0
	for g in 80:
		var tirage := rng.randf()
		var quoi := ""
		var diff: Dictionary = {}
		if tirage < 0.55:
			# Un coup : des cases posées dans une couche visible, prises aux autres.
			var r := rng.randi_range(0, 2)
			if not visibles[r]:
				r = visibles.find(true)
			var cases_: Array = []
			var p := Vector3i(rng.randi_range(-14, 14), rng.randi_range(-2, 12), rng.randi_range(-14, 14))
			for j in rng.randi_range(1, 14):
				cases_.append(p + Vector3i(j % 3, (j / 3) % 2, j / 6))
			Natif.actif = false
			for c in cases_:
				for i in 3:
					if i != r:
						(massifs[i].get_node("Cases") as GridMap).set_cell_item(c, GridMap.INVALID_CELL_ITEM)
				var cg: GridMap = massifs[r].get_node("Cases")
				cg.set_cell_item(c, cg.mesh_library.find_item_by_name("case"))
				union[c] = r
			for i in 3:
				if visibles[i]:
					massifs[i].reconstruire_autour(cases_)
			Natif.actif = true
			diff = mn.poser(r, cases_)
			quoi = "coup dans la couche %d" % r
		elif tirage < 0.75:
			# Creuser : des cases retirées, de quelque couche qu'elles soient.
			var cases_: Array = []
			var p := Vector3i(rng.randi_range(-14, 14), rng.randi_range(-2, 8), rng.randi_range(-14, 14))
			for j in rng.randi_range(1, 10):
				cases_.append(p + Vector3i(j % 2, j / 4, (j / 2) % 2))
			Natif.actif = false
			for c in cases_:
				for i in 3:
					(massifs[i].get_node("Cases") as GridMap).set_cell_item(c, GridMap.INVALID_CELL_ITEM)
				union.erase(c)
			for i in 3:
				if visibles[i]:
					massifs[i].reconstruire_autour(cases_)
			Natif.actif = true
			diff = mn.vider(cases_)
			quoi = "creuser"
		elif tirage < 0.85:
			var r := rng.randi_range(0, 2)
			visibles[r] = not visibles[r]
			if visibles.find(true) < 0:
				visibles[r] = true
			Natif.actif = false
			refaire_l_union.call()
			Natif.actif = true
			diff = mn.definir_visible(r, visibles[r])
			quoi = "couche %d %s" % [r, "montrée" if visibles[r] else "cachée"]
		elif tirage < 0.92:
			# Monter une couche d'un cran (Up / Down de l'écran) : l'ordre est la priorité.
			var r := rng.randi_range(1, 2)
			for liste in [massifs, visibles, rendus, fautes_, lots, cles_par]:
				var x = liste[r]
				liste[r] = liste[r - 1]
				liste[r - 1] = x
			Natif.actif = false
			refaire_l_union.call()
			Natif.actif = true
			diff = mn.deplacer_couche(r, r - 1)
			quoi = "couche %d montée" % r
		else:
			# Un choix de variante, sur un sommet posé dont la clé en a (le rang que le tirage n'a pas donné).
			var r := rng.randi_range(0, 2)
			var m: Node3D = massifs[r]
			var s = null
			for v in m._etat:
				var d: Dictionary = m._etat[v]
				if not d.is_empty() and d["cle"] != "" and cles_par[r].has(MB.nom_de_variante(d["cle"], 2)) \
						and rng.randf() < 0.05:
					s = v
					break
			if s == null:
				continue
			var k := (MB.rang_de_variante(m.tuile_posee(s)) + 1) % 3
			m.choix[s] = k
			Natif.actif = false
			m.reconstruire_sommets([s])
			Natif.actif = true
			diff = mn.choisir(r, s, k)
			quoi = "choix %d en %s" % [k, s]
		sortes[quoi.get_slice(" ", 0)] = int(sortes.get(quoi.get_slice(" ", 0), 0)) + 1
		decides += int(mn.derniers_decides())
		poses_vues += int(mn.nombre_de_poses())
		mn.appliquer(diff, rendus, fautes_, id_faute)
		if photo.call() != photo_natif.call():
			ecarts += 1
			if premier == "":
				premier = "geste %d (%s)" % [g, quoi]
	_dire(ecarts == 0, "%d geste(s) sur 80 où les diffs du natif ne rendent pas l'appli — %s" % [ecarts, premier])
	for sorte in ["coup", "creuser", "couche", "choix"]:
		_dire(int(sortes.get(sorte, 0)) >= 3, "les gestes doivent exercer « %s » (%s)" % [sorte, sortes])
	var variantes := 0
	var fautes_vues := 0
	for r in 3:
		for c in (rendus[r] as GridMap).get_used_cells():
			if str(lots[r].get_item_name((rendus[r] as GridMap).get_cell_item(c))).contains("_var"):
				variantes += 1
		fautes_vues += (fautes_[r] as GridMap).get_used_cells().size()
	_dire(variantes > 0 and fautes_vues > 0, "le monde doit poser des variantes et des fautes (%d, %d)" % [variantes, fautes_vues])
	# Le diff est LOCAL : un geste décide une petite part des sommets du monde.
	_dire(decides * 5 < poses_vues, "un geste ne doit décider qu'une part des sommets (%d sur %d)" % [decides, poses_vues])
	for m in massifs:
		m.free()
	for g in rendus + fautes_:
		g.free()
	_sections += 1


# ── 11. le monde du cœur BRANCHÉ dans les couches (MassifPeint.monde) ─────────────────────────────────

## Une scène comme l'écran les mène : des couches qui partagent l'union, et, si `branche`, un monde du cœur partagé.
## Les gestes reprennent ceux de `editor.gd` (`_suivre_les_cases`, `_refaire_l_union`, `_montrer_couche`).
class Scene:
	var massifs: Array = []
	var union := {}
	var visibles: Array = []
	var monde = null
	var branche := false

	func appeler(f: Callable) -> void:
		Natif.actif = branche
		f.call()
		Natif.actif = true

	func suivre(cases_: Array) -> void:
		appeler(func() -> void:
			for c in cases_:
				union.erase(c)
				for i in massifs.size():
					if visibles[i] and (massifs[i].get_node("Cases") as GridMap).get_cell_item(c) != GridMap.INVALID_CELL_ITEM:
						union[c] = i
						break
			for i in massifs.size():
				var m: Node = massifs[i]
				if not visibles[i]:
					var attente: Dictionary = m.get_meta("_a_refaire", {})
					for c in cases_:
						attente[c] = true
					m.set_meta("_a_refaire", attente)
					continue
				m.reconstruire_autour(cases_))

	func refaire_l_union() -> void:
		appeler(func() -> void:
			union.clear()
			for i in range(massifs.size() - 1, -1, -1):
				var m: Node = massifs[i]
				m.union = union
				m.monde = monde
				m.rang = i
				(m as Node3D).visible = visibles[i]
				if visibles[i]:
					for c in (m.get_node("Cases") as GridMap).get_used_cells():
						union[c] = i
			for i in massifs.size():
				var m: Node = massifs[i]
				m.remove_meta("_a_refaire")
				if not visibles[i]:
					m.set_meta("_tout_refaire", true)
					continue
				m.remove_meta("_tout_refaire")
				m.reconstruire())

	func montrer(i: int, oui: bool) -> void:
		visibles[i] = oui
		appeler(func() -> void:
			var m: Node = massifs[i]
			(m as Node3D).visible = oui
			var siennes: Array = (m.get_node("Cases") as GridMap).get_used_cells()
			for c in siennes:
				if oui:
					union[c] = i
				elif union.get(c, -1) == i:
					union.erase(c)
			for j in massifs.size():
				if j == i:
					continue
				if visibles[j]:
					massifs[j].reconstruire_autour(siennes)
				else:
					var attente_j: Dictionary = massifs[j].get_meta("_a_refaire", {})
					for c in siennes:
						attente_j[c] = true
					massifs[j].set_meta("_a_refaire", attente_j)
			if oui:
				var attente: Dictionary = m.get_meta("_a_refaire", {})
				m.remove_meta("_a_refaire")
				if m.get_meta("_tout_refaire", false):
					m.remove_meta("_tout_refaire")
					m.reconstruire()
				else:
					m.reconstruire_autour(attente.keys()))


func _index_de(lot: MeshLibrary) -> Dictionary:
	var index := {}
	for id in lot.get_item_list():
		index[lot.get_item_name(id)] = id
	return index


## Ce qu'une couche VISIBLE montre et tient : ses grilles, son état (sans ordre : `==` sur les Dictionary), son bilan.
func _ce_que_montre(m: Node3D) -> Array:
	return [_photo_massif(m), m._etat, m.dernier_bilan()]


func _le_monde_branche() -> void:
	print("11. le monde du cœur BRANCHÉ dans les couches : 160 gestes, l'appli en GDScript contre l'appli branchée")
	var monde_ := _monde(600, 30, 8)
	var cles_par: Array = [_cles(0), _cles(7), _cles(3)]
	var lots: Array = []
	for c in cles_par:
		lots.append(_lot(c))
	var lot_autre := _lot(_cles(5))
	var parts: Array = [{}, {}, {}]
	for c in monde_:
		parts[2 if c.y > 5 else int(posmod(int(floor((c.x - c.z) / 6.0)), 2))][c] = true
	var scenes: Array = []
	for branche in [false, true]:
		var sc := Scene.new()
		sc.branche = branche
		Natif.actif = true
		sc.monde = MB.monde_natif() if branche else null
		for r in 3:
			sc.massifs.append(_massif(lots[r], parts[r]))
			sc.visibles.append(true)
		sc.massifs[1].poids = {cles_par[1].keys()[12]: [0, 1, 3]}
		sc.refaire_l_union()
		scenes.append(sc)
	var gd: Scene = scenes[0]
	var br: Scene = scenes[1]
	_dire(br.monde != null and br.massifs[0].monde == br.monde, "le monde est branché aux couches de la scène branchée")
	var compare := func(quoi: String) -> String:
		for i in 3:
			if not gd.visibles[i]:
				continue
			var a := _ce_que_montre(gd.massifs[i])
			var b := _ce_que_montre(br.massifs[i])
			if a[0] != b[0]:
				var la: PackedStringArray = (a[0] as String).split("\n")
				var lb: PackedStringArray = (b[0] as String).split("\n")
				var k := 0
				while k < mini(la.size(), lb.size()) and la[k] == lb[k]:
					k += 1
				return "%s : la couche %d ne montre pas la même chose (%d contre %d lignes ; à la ligne %d : %s contre %s)" % [
					quoi, i, la.size(), lb.size(), k, la[k] if k < la.size() else "rien", lb[k] if k < lb.size() else "rien"]
			if a[1] != b[1]:
				return "%s : la couche %d ne tient pas le même état (%d contre %d sommets)" % [quoi, i,
					(a[1] as Dictionary).size(), (b[1] as Dictionary).size()]
			if a[2] != b[2]:
				return "%s : la couche %d, bilan %s contre %s" % [quoi, i, a[2], b[2]]
		return ""
	var premier: String = compare.call("le monde bâti")
	_dire(premier == "", premier)
	_dire(int(br.massifs[0].dernier_bilan()["muets"]) > 0, "les couches doivent tenir des sommets MUETS (%s)"
		% br.massifs[0].dernier_bilan())
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261006
	var ecarts := 0
	var sortes := {}
	var dormies := 0
	var eveillees_cachees := 0
	for g in 160:
		var t := rng.randf()
		var quoi := ""
		if t < 0.4:
			# Un coup dans une couche visible : ses cases prises aux autres (`_vols`), puis l'union suit.
			var r := rng.randi_range(0, 2)
			if not gd.visibles[r]:
				continue
			var p := Vector3i(rng.randi_range(-13, 13), rng.randi_range(-2, 11), rng.randi_range(-13, 13))
			var cases_: Array = []
			for j in rng.randi_range(1, 16):
				cases_.append(p + Vector3i(j % 3, (j / 3) % 2, j / 6))
			for sc in scenes:
				for c in cases_:
					for i in 3:
						var g_: GridMap = sc.massifs[i].get_node("Cases")
						g_.set_cell_item(c, g_.mesh_library.find_item_by_name("case") if i == r else GridMap.INVALID_CELL_ITEM)
				sc.suivre(cases_)
			quoi = "coup"
		elif t < 0.52:
			# Déplacer (Move de l'écran) : des cases d'une couche visible glissent d'un cran, dans UN geste — autant de
			# cases parties que venues (le compte ne change pas), et des sommets qui changent deux fois avant d'être posés.
			var r := rng.randi_range(0, 2)
			if not gd.visibles[r]:
				continue
			var g0: GridMap = gd.massifs[r].get_node("Cases")
			var a_elles: Array = g0.get_used_cells()
			if a_elles.size() < 10:
				continue
			var depart: Vector3i = a_elles[rng.randi_range(0, a_elles.size() - 1)]
			var pas: Vector3i = [Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, -1)][rng.randi_range(0, 2)]
			var parties: Array = []
			for c in a_elles:
				if (c - depart).length_squared() <= 3:
					parties.append(c)
			var libres := true
			for c in parties:
				var d: Vector3i = c + pas
				if not parties.has(d) and gd.union.has(d):
					libres = false
			if not libres:
				continue
			# ⚠ UNE CASE N'APPARTIENT QU'À UNE COUCHE : celles d'une couche CACHÉE sous la tête sont prises (`_vols`).
			var touchees: Array = parties.duplicate()
			for c in parties:
				if not touchees.has(c + pas):
					touchees.append(c + pas)
			for sc in scenes:
				var g_: GridMap = sc.massifs[r].get_node("Cases")
				var id_case := g_.mesh_library.find_item_by_name("case")
				for c in parties:
					g_.set_cell_item(c, GridMap.INVALID_CELL_ITEM)
				for c in parties:
					g_.set_cell_item(c + pas, id_case)
					for i in 3:
						if i != r:
							(sc.massifs[i].get_node("Cases") as GridMap).set_cell_item(c + pas, GridMap.INVALID_CELL_ITEM)
				sc.suivre(touchees)
			quoi = "deplacer"
		elif t < 0.6:
			var p := Vector3i(rng.randi_range(-13, 13), rng.randi_range(-2, 8), rng.randi_range(-13, 13))
			var cases_: Array = []
			for j in rng.randi_range(1, 10):
				cases_.append(p + Vector3i(j % 2, j / 4, (j / 2) % 2))
			for sc in scenes:
				for c in cases_:
					for i in 3:
						(sc.massifs[i].get_node("Cases") as GridMap).set_cell_item(c, GridMap.INVALID_CELL_ITEM)
				sc.suivre(cases_)
			quoi = "creuser"
		elif t < 0.7:
			var r := rng.randi_range(0, 2)
			var oui: bool = not gd.visibles[r]
			if not oui and gd.visibles.count(true) == 1:
				continue
			for sc in scenes:
				sc.montrer(r, oui)
			quoi = "montrer"
		elif t < 0.77:
			# Up / Down : la couche r passe au-dessus de r − 1 (`_echanger_couches`), puis l'union est refaite.
			var r := rng.randi_range(1, 2)
			for sc in scenes:
				for liste in [sc.massifs, sc.visibles]:
					var x = liste[r]
					liste[r] = liste[r - 1]
					liste[r - 1] = x
				sc.refaire_l_union()
			for liste in [lots, cles_par]:
				var x = liste[r]
				liste[r] = liste[r - 1]
				liste[r - 1] = x
			quoi = "monter"
		elif t < 0.89:
			# Un choix de variante (`reconstruire_sommets`), sur un sommet posé dont la clé en a.
			var r := rng.randi_range(0, 2)
			if not gd.visibles[r]:
				continue
			var s = null
			for v in gd.massifs[r]._etat:
				var d: Dictionary = gd.massifs[r]._etat[v]
				if not d.is_empty() and d["cle"] != "" and cles_par[r].has(MB.nom_de_variante(d["cle"], 2)) \
						and rng.randf() < 0.05:
					s = v
					break
			if s == null:
				continue
			var k := (MB.rang_de_variante(gd.massifs[r].tuile_posee(s)) + 1) % 3
			for sc in scenes:
				sc.massifs[r].choix[s] = k
				sc.appeler(func() -> void: sc.massifs[r].reconstruire_sommets([s]))
			quoi = "choix"
		elif t < 0.94:
			# Des poids (`variantes.gd` : puis `reconstruire()`).
			var r := rng.randi_range(0, 2)
			if not gd.visibles[r]:
				continue
			var cle: String = cles_par[r].keys()[rng.randi_range(0, 40) * 2]
			for sc in scenes:
				sc.massifs[r].poids[cle] = [rng.randi_range(0, 2), 2, 1]
			var w: Array = gd.massifs[r].poids[cle]
			for sc in scenes:
				sc.massifs[r].poids[cle] = w.duplicate()
				sc.appeler(func() -> void: sc.massifs[r].reconstruire())
			quoi = "poids"
		else:
			# Un autre lot (un témoin tranché autrement, d'autres noms : le setter reconstruit) ; une fois sur deux, le
			# MÊME index sous un lot neuf (un témoin retouché : le setter ne change que la grille).
			var r := rng.randi_range(0, 2)
			if not gd.visibles[r]:
				continue
			var trous: int = [5, 11][sortes.get("lot", 0) % 2]
			var neuf := _lot(cles_par[r]) if rng.randf() < 0.5 else _lot(_cles(trous))
			for sc in scenes:
				sc.appeler(func() -> void: sc.massifs[r].lot = neuf)
			cles_par[r] = _index_de(neuf)
			lots[r] = neuf
			quoi = "lot"
		sortes[quoi] = int(sortes.get(quoi, 0)) + 1
		# Une couche cachée DORT dans le monde (ses grilles et son état gardés, la différence au réveil) : sans ça, cacher
		# et montrer une couche coûtaient plus qu'avant le branchement (mesuré).
		for i in 3:
			if not br.visibles[i] and int(br.monde.proprio(i)) == br.massifs[i].get_instance_id():
				dormies += 1 if br.monde.dort(i) else 0
				eveillees_cachees += 0 if br.monde.dort(i) else 1
		var e: String = compare.call("geste %d (%s)" % [g, quoi])
		if e != "":
			ecarts += 1
			if ecarts == 1:
				_dire(false, e)
	_dire(ecarts == 0, "%d geste(s) sur 160 où l'appli branchée diffère de l'appli en GDScript" % ecarts)
	for sorte in ["coup", "deplacer", "creuser", "montrer", "monter", "choix", "poids", "lot"]:
		_dire(int(sortes.get(sorte, 0)) >= 2, "les gestes doivent exercer « %s » (%s)" % [sorte, sortes])
	_dire(int(br.monde.taille_attente()) == 0, "rien ne reste en attente après les gestes")
	_dire(dormies > 10 and eveillees_cachees == 0, "une couche cachée dort dans le monde (%d fois, %d éveillée cachée)"
		% [dormies, eveillees_cachees])
	for sc in scenes:
		for m in sc.massifs:
			m.free()
	_sections += 1


# ── la mesure (rien n'y est jugé) ─────────────────────────────────────────────────────────────────────

func _mesurer() -> void:
	print("\n7. mesure (un monde de ~200 000 cases)")
	var pleines := {}
	for x in 200:
		for z in 200:
			var h := 3 + int((sin(x * 0.07) + cos(z * 0.05)) * 2.0)
			for y in h:
				pleines[Vector3i(x, y, z)] = true
	var cles := _cles(0)
	for natif in [false, true]:
		Natif.actif = natif
		var t0 := Time.get_ticks_usec()
		var poses := MB.poses(pleines, cles)
		var t1 := Time.get_ticks_usec()
		var o: Dictionary = FL.ocean(pleines, 4)
		var t2 := Time.get_ticks_usec()
		var m := _massif(_lot(cles), pleines)
		var t3 := Time.get_ticks_usec()
		m.reconstruire()
		var t4 := Time.get_ticks_usec()
		print("   %s : %d cases, poses %d ms (%d), océan %d ms (%d cases), massif %d ms" % [
			"natif   " if natif else "GDScript", pleines.size(), (t1 - t0) / 1000, poses.size(), (t2 - t1) / 1000,
			(o["eau"] as Dictionary).size(), (t4 - t3) / 1000])
		m.free()
	# Le monde du cœur : le même monde posé d'un coup, puis une case posée et retirée (le diff d'un geste),
	# contre un massif qui refait autour d'une case (`reconstruire_autour`, natif).
	var mn = MB.monde_natif()
	mn.ajouter_couche()
	mn.definir_tuiles(0, cles, {})
	var ta := Time.get_ticks_usec()
	mn.poser(0, pleines.keys())
	var tb := Time.get_ticks_usec()
	var geste := Vector3i(100, 0, 100)   # posé SUR le relief : sa colonne change de haut, le ciel des voisins aussi
	while pleines.has(geste):
		geste.y += 1
	var gr := GridMap.new()
	var gf := GridMap.new()
	root.add_child(gr)
	root.add_child(gf)
	var grilles: Array = [gr]
	var fautes_g: Array = [gf]
	mn.remplir(0, gr, gf, 0)
	var tc := Time.get_ticks_usec()
	for k in 50:
		mn.appliquer(mn.poser(0, [geste]), grilles, fautes_g, 0)
		mn.appliquer(mn.vider([geste]), grilles, fautes_g, 0)
	var td := Time.get_ticks_usec()
	gr.free()
	gf.free()
	var m2 := _massif(_lot(cles), pleines)
	m2.reconstruire()
	var cg: GridMap = m2.get_node("Cases")
	var id_case: int = cg.mesh_library.find_item_by_name("case")
	var te := Time.get_ticks_usec()
	for k in 50:
		cg.set_cell_item(geste, id_case)
		m2.reconstruire_autour([geste])
		cg.set_cell_item(geste, GridMap.INVALID_CELL_ITEM)
		m2.reconstruire_autour([geste])
	var tf := Time.get_ticks_usec()
	print("   monde du cœur : posé d'un coup %d ms (%d poses) ; un geste d’une case, diff appliqué %.3f ms (massif natif : %.3f ms)" % [
		(tb - ta) / 1000, mn.nombre_de_poses(), (td - tc) / 100000.0, (tf - te) / 100000.0])
	m2.free()
	# L'APPLI BRANCHÉE (étape 3 b) contre l'appli d'avant (le natif, sans le monde) : trois couches comme l'écran les
	# mène sur ce monde — l'ouverture (l'union refaite), un geste_b d'une case, cacher puis montrer une couche, Up.
	var cles3: Array = [_cles(0), _cles(7), _cles(3)]
	for branche in [false, true]:
		var sc_b := Scene.new()
		sc_b.branche = true   # le natif allumé dans les deux cas ; seul le monde change
		sc_b.monde = MB.monde_natif() if branche else null
		var parts_b: Array = [{}, {}, {}]
		for c in pleines:
			parts_b[2 if c.y > 3 else int((c.x / 40 + c.z / 50) % 2)][c] = true
		for r in 3:
			sc_b.massifs.append(_massif(_lot(cles3[r]), parts_b[r]))
			sc_b.visibles.append(true)
		var ua := Time.get_ticks_usec()
		sc_b.refaire_l_union()
		var ub := Time.get_ticks_usec()
		var geste_b := Vector3i(100, 0, 100)
		while pleines.has(geste_b):
			geste_b.y += 1
		var uc := Time.get_ticks_usec()
		for k in 20:
			var g0_b: GridMap = sc_b.massifs[0].get_node("Cases")
			g0_b.set_cell_item(geste_b, g0_b.mesh_library.find_item_by_name("case"))
			sc_b.suivre([geste_b])
			g0_b.set_cell_item(geste_b, GridMap.INVALID_CELL_ITEM)
			sc_b.suivre([geste_b])
		var ud := Time.get_ticks_usec()
		sc_b.montrer(1, false)
		var ue := Time.get_ticks_usec()
		sc_b.montrer(1, true)
		var uf := Time.get_ticks_usec()
		var x_b = sc_b.massifs[1]
		sc_b.massifs[1] = sc_b.massifs[0]
		sc_b.massifs[0] = x_b
		sc_b.refaire_l_union()
		var ug := Time.get_ticks_usec()
		print("   %s : 3 couches, ouverture %d ms ; un geste_b d'une case %.2f ms ; cacher %d ms, montrer %d ms ; Up %d ms" % [
			"appli branchée au monde" if branche else "appli d'avant (natif)", (ub - ua) / 1000, (ud - uc) / 40000.0,
			(ue - ud) / 1000, (uf - ue) / 1000, (ug - uf) / 1000])
		for m in sc_b.massifs:
			m.free()
	var img := _image(512, 512, 9)
	var tri := _triangles(4, 400)
	for natif in [false, true]:
		Natif.actif = natif
		var t0 := Time.get_ticks_usec()
		CP.generer(img, null, true)
		var t1 := Time.get_ticks_usec()
		var masque := CP.masque_des_triangles(tri, Vector2i(512, 512))
		var t2 := Time.get_ticks_usec()
		CP.generer(img, null, false, masque)
		var t3 := Time.get_ticks_usec()
		var bloc := BM.maillage_moitie(0)
		var t4 := Time.get_ticks_usec()
		for x in 6:
			for y in 6:
				DC.trancher(bloc, AABB(Vector3(x + 1.5, y + 3.5, 5.5), Vector3.ONE))
		var t5 := Time.get_ticks_usec()
		print("   %s : cartes 512² %d ms, masque %d ms, cartes avec masque %d ms, 36 découpes %d ms" % [
			"natif   " if natif else "GDScript", (t1 - t0) / 1000, (t2 - t1) / 1000, (t3 - t2) / 1000, (t5 - t4) / 1000])
	Natif.actif = true
