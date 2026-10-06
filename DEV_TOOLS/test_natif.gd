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
	_dire(_sections == 6, "toutes les sections sont allées au bout (%d sur 6) — une erreur d'exécution en a arrêté une"
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
	Natif.actif = true
