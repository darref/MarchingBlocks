extends SceneTree
##
## TEST — le générateur de mondes (`app/generateur.gd`, la 1.0.0 : Jordan, 19 octobre 2026).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_generateur.gd
##
## ⚠ **CE QUI EST GARDÉ, C'EST CE QUE L'ARTISTE VERRAIT CASSÉ** : un monde différent pour la même graine, des cubes rouges
## (contacts par une arête), une marche de deux cases sur un chemin, une galerie trop basse pour le stickman, deux
## matières sur un même plat sans transition, une salle ouverte sur la mer. Les contrôles relisent les CASES rendues,
## pas les fonctions qui les ont faites.

const G := preload("res://app/generateur.gd")

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== TEST — le générateur de mondes ===\n")
	_la_graine()
	_les_formes()
	_les_regles()
	_les_chemins()
	_le_souterrain()
	_l_eau()
	_le_croquis()
	_les_bornes()
	_l_apercu()
	_le_feuillage()
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


func _vrai(v: bool, quoi: String) -> void:
	if v:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ " + quoi)


func _egal(a, b, quoi: String) -> void:
	if a == b:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ %s — rendu %s, attendu %s" % [quoi, a, b])


## Toutes les cases pleines du monde, tous rôles confondus.
static func _toutes(monde: Dictionary) -> Dictionary:
	var t := {}
	for r in monde["cases"]:
		t.merge(monde["cases"][r])
	return t


static func _empreinte(monde: Dictionary) -> int:
	var lignes: Array = []
	for r in G.ROLES:
		var cles: Array = (monde["cases"][r] as Dictionary).keys()
		cles.sort()
		lignes.append([r, cles])
	return hash(lignes)


## Les contacts par une arête : deux pleines en diagonale dans un carré de quatre cases dont les deux autres sont vides
## (ou l'inverse), dans les trois plans. Compté sur TOUTES les cases du monde.
static func _contacts(pleines: Dictionary) -> int:
	var plans := [[Vector3i(1, 0, 0), Vector3i(0, 1, 0)], [Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
		[Vector3i(0, 1, 0), Vector3i(0, 0, 1)]]
	var vus := {}
	var n := 0
	for c in pleines:
		for pl in plans:
			for u in [Vector3i.ZERO, -pl[0]]:
				for v in [Vector3i.ZERO, -pl[1]]:
					var a: Vector3i = c + u + v
					var cle := [a, pl]
					if vus.has(cle):
						continue
					vus[cle] = true
					var pa := pleines.has(a)
					var pb := pleines.has(a + pl[0])
					var pd := pleines.has(a + pl[1])
					var pe := pleines.has(a + pl[0] + pl[1])
					if pa == pe and pb == pd and pa != pb:
						n += 1
	return n


func _la_graine() -> void:
	print("— la graine")
	var a := G.generer({"graine": 7, "largeur": 48, "profondeur": 48})
	var b := G.generer({"graine": 7, "largeur": 48, "profondeur": 48})
	var c := G.generer({"graine": 8, "largeur": 48, "profondeur": 48})
	_egal(_empreinte(a), _empreinte(b), "la même graine refait EXACTEMENT le même monde, case pour case")
	_vrai(_empreinte(a) != _empreinte(c), "une autre graine fait un autre monde")
	_egal(a["eaux"], b["eaux"], "et la même eau")


func _les_formes() -> void:
	print("— les formes")
	for forme in G.FORMES:
		if forme == "croquis":
			continue
		var m := G.generer({"forme": forme, "largeur": 64, "profondeur": 48, "hauteur": 24, "graine": 3})
		var terre := 0
		var mer := 0
		var hors := 0
		var h: PackedInt32Array = m["h"]
		for v in h:
			if v >= int(m["mer"]) + 1:
				terre += 1
			elif v != G.VIDE:
				mer += 1
		for c in _toutes(m):
			if c.x < -32 or c.x >= 32 or c.z < -24 or c.z >= 24 or c.y < 0 or c.y > 24:
				hors += 1
		_egal(hors, 0, "%s : aucune case hors de 64 × 24 × 48" % forme)
		_vrai(terre > 64 * 48 / 10, "%s : de la terre (%d colonnes)" % [forme, terre])
		if forme in ["ile", "archipel", "plateau"]:
			_vrai(mer > 64 * 48 / 10, "%s : de la mer tout autour (%d colonnes)" % [forme, mer])
	# L'archipel fait PLUSIEURS îles : on compte les morceaux de terre.
	var arch := G.generer({"forme": "archipel", "largeur": 128, "profondeur": 128, "graine": 6}, true)
	_vrai(_morceaux_de_terre(arch) >= 2, "l'archipel a plusieurs îles (%d)" % _morceaux_de_terre(arch))
	_egal(_morceaux_de_terre(G.generer({"forme": "ile", "graine": 5, "lieux": 0}, true)) >= 1, true, "l'île a sa terre")
	# Sans mer : rien sous le niveau zéro, l'île flotte (pas une case de fond).
	var sans := G.generer({"mer": 0, "largeur": 48, "profondeur": 48, "graine": 2})
	var fond := 0
	for v in (sans["h"] as PackedInt32Array):
		if v == 0:
			fond += 1
	_vrai((sans["eaux"] as Array).filter(func(e: Dictionary) -> bool: return e["nom"] == "Sea").is_empty(),
		"sans mer, pas de source de mer")
	# Les falaises : à 0, des marches d'une case partout sur la terre ; à 1, des marches de quatre.
	var douce := G.generer({"falaises": 0.0, "lieux": 0, "lacs": 0, "lave": 0, "graine": 4}, true)
	_egal(_marches_maxi(douce, true), 1, "« Cliffs » à 0 : la terre monte d'une case à la fois")
	var franche := G.generer({"falaises": 1.0, "lieux": 0, "lacs": 0, "lave": 0, "graine": 4}, true)
	_vrai(_hauteurs_multiples(franche, 4), "« Cliffs » à 1 : la terre en paliers de quatre cases")


static func _morceaux_de_terre(m: Dictionary) -> int:
	var w: int = m["largeur"]
	var d: int = m["profondeur"]
	var h: PackedInt32Array = m["h"]
	var mer: int = m["mer"]
	var vu := {}
	var n := 0
	for i in h.size():
		if h[i] < mer + 1 or vu.has(i):
			continue
		var pile := [i]
		var taille := 0
		while not pile.is_empty():
			var j: int = pile.pop_back()
			if vu.has(j) or h[j] < mer + 1:
				continue
			vu[j] = true
			taille += 1
			var x := j % w
			var z := j / w
			if x > 0: pile.append(j - 1)
			if x < w - 1: pile.append(j + 1)
			if z > 0: pile.append(j - w)
			if z < d - 1: pile.append(j + w)
		if taille >= 20:
			n += 1
	return n


## La plus grande marche entre deux colonnes de terre voisines, hors des cuvettes (lacs) et des chemins.
static func _marches_maxi(m: Dictionary, terre_seule: bool) -> int:
	var w: int = m["largeur"]
	var h: PackedInt32Array = m["h"]
	var mer: int = m["mer"]
	var maxi := 0
	for i in h.size():
		if i % w == w - 1 or i + w >= h.size():
			continue
		for j in [i + 1, i + w]:
			if terre_seule and (h[i] <= mer or h[j] <= mer):
				continue
			maxi = maxi(maxi, absi(h[i] - h[j]))
	return maxi


static func _hauteurs_multiples(m: Dictionary, s: int) -> bool:
	var mer: int = m["mer"]
	for v in (m["h"] as PackedInt32Array):
		if v > mer + 1 and (v - mer - 1) % s != 0:
			return false
	return true


func _les_regles() -> void:
	print("— les règles")
	for graine in [1, 2, 3]:
		var m := G.generer({"graine": graine, "largeur": 72, "profondeur": 72, "souterrains": 0.8, "lieux": 4,
			"falaises": 0.6})
		var t := _toutes(m)
		_egal(_contacts(t), 0, "graine %d : aucun contact par une arête dans tout le monde (%d cases)" % [graine, t.size()])
		# UNE MATIÈRE PAR NIVEAU : sur un même plat, seuls les chemins touchent un autre rôle.
		for paire in m["transitions"]:
			_vrai("chemin" in paire, "graine %d : deux matières ne se touchent sur un plat qu'au bord d'un chemin (%s)"
				% [graine, paire])
	var mele := G.generer({"graine": 1, "largeur": 72, "profondeur": 72, "melange": true, "sol2": 0.5, "lieux": 0})
	var hors_chemin := (mele["transitions"] as Array).filter(func(pp: Array) -> bool: return not "chemin" in pp)
	_vrai(not hors_chemin.is_empty(), "« Blend materials » : des matières se touchent sur un plat, et leurs transitions sont "
		+ "rendues (%s)" % [hors_chemin])
	var roche := G.generer({"graine": 1, "largeur": 48, "profondeur": 48, "parois_roche": true, "souterrains": 0.0})
	var sous_le_dessus := 0
	var h: PackedInt32Array = roche["h"]
	var o: Vector2i = roche["origine"]
	for c in roche["cases"]["sol"]:
		if c.y < h[(c.z - o.y) * 48 + (c.x - o.x)]:
			sous_le_dessus += 1
	_egal(sous_le_dessus, 0, "« Rock cliffs » : sous le dessus, tout est roche")


func _les_chemins() -> void:
	print("— les chemins")
	var m := G.generer({"graine": 11, "largeur": 96, "profondeur": 96, "lieux": 5, "boucles": 0.5, "falaises": 0.6}, true)
	_egal((m["lieux"] as Array).size(), 5, "cinq places")
	_vrai(int(m["rapport"].get("chemins", 0)) >= 4, "au moins quatre liaisons (l'arbre) : %s" % m["rapport"].get("chemins"))
	_egal(m["rapport"].get("chemins_marches_hautes", -1), 0, "aucune marche de plus d'une case sur les chemins")
	# Chaque place est reliée à toutes les autres par des colonnes de chemin, une case à monter au plus.
	var w: int = m["largeur"]
	var h: PackedInt32Array = m["h"]
	var r: PackedStringArray = m["role"]
	var o: Vector2i = m["origine"]
	var depart: Vector3i = m["lieux"][0]
	var atteints := {}
	var pile := [Vector2i(depart.x, depart.z) - o]
	while not pile.is_empty():
		var q: Vector2i = pile.pop_back()
		var i := q.y * w + q.x
		if atteints.has(i):
			continue
		atteints[i] = true
		for d in G.DIRS4:
			var n: Vector2i = q + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= int(m["profondeur"]):
				continue
			var j := n.y * w + n.x
			if r[j] == "chemin" and absi(h[j] - h[i]) <= 1:
				pile.append(n)
	for l in m["lieux"]:
		_vrai(atteints.has((l.z - o.y) * w + (l.x - o.x)), "la place %s est atteinte à pied depuis la première" % l)


func _le_souterrain() -> void:
	print("— le souterrain")
	var m := G.generer({"graine": 21, "largeur": 96, "profondeur": 96, "hauteur": 40, "relief": 0.9,
		"souterrains": 1.0, "puits": 0.0})
	var rap: Dictionary = m["rapport"]
	_vrai(int(rap.get("salles", 0)) >= 3, "des salles (%s)" % rap.get("salles"))
	_vrai(int(rap.get("galeries", 0)) >= 1, "des galeries (%s)" % rap.get("galeries"))
	_vrai((m["entrees"] as Array).size() >= 1, "au moins une entrée (%d)" % (m["entrees"] as Array).size())
	var t := _toutes(m)
	var h: PackedInt32Array = m["h"]
	var w: int = m["largeur"]
	var o: Vector2i = m["origine"]
	# TROIS CASES DE HAUT : sur chaque sol creusé (une case vide sous la surface, pleine dessous), les deux cases au-dessus
	# sont vides aussi.
	var bas := 0
	var sols := 0
	for z in int(m["profondeur"]):
		for x in w:
			var top := h[z * w + x]
			for y in range(1, top):
				var c := Vector3i(x + o.x, y, z + o.y)
				if t.has(c) or not t.has(c + Vector3i.DOWN):
					continue
				sols += 1
				if t.has(c + Vector3i.UP) or t.has(c + Vector3i.UP * 2):
					bas += 1
	_vrai(sols > 50, "des sols sous terre (%d)" % sols)
	_egal(bas, 0, "aucun sol souterrain sous un plafond à moins de trois cases")
	# FERMÉ : depuis le vide du dehors, on n'entre dans le souterrain que par une entrée. On remplit le vide à partir
	# d'au-dessus du monde, sans passer par les colonnes d'une entrée.
	var bouches: Dictionary = m["bouches"]
	_vrai(not bouches.is_empty(), "les cases des entrées sont rendues")
	var dehors := {}
	var pile: Array = []
	for z in int(m["profondeur"]):
		for x in w:
			pile.append(Vector3i(x + o.x, h[z * w + x] + 1, z + o.y))
	var rentre := 0
	while not pile.is_empty():
		var c: Vector3i = pile.pop_back()
		if dehors.has(c) or t.has(c) or c.y < 0 or c.x < o.x or c.z < o.y or c.x >= o.x + w or c.z >= o.y + int(m["profondeur"]):
			continue
		if bouches.has(c):
			continue
		dehors[c] = true
		if c.y < h[(c.z - o.y) * w + (c.x - o.x)] - 1:
			rentre += 1
			continue
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i.DOWN]:
			pile.append(c + d)
	_egal(rentre, 0, "le souterrain ne s'ouvre sur le dehors que par ses entrées")
	var sans := G.generer({"graine": 21, "largeur": 48, "profondeur": 48, "souterrains": 0.0})
	_egal(sans["rapport"].get("salles", -1), 0, "« Caves » à 0 : pas de souterrain")


func _l_eau() -> void:
	print("— l'eau")
	var m := G.generer({"graine": 31, "largeur": 96, "profondeur": 96, "lacs": 2, "lave": 2, "sources": 1, "relief": 1.0,
		"hauteur": 40}, true)
	var noms := {}
	for e in m["eaux"]:
		noms[e["nom"]] = e
	_vrai(noms.has("Sea"), "la mer")
	if noms.has("Sea"):
		var s: Vector3i = noms["Sea"]["sources"][0]
		_egal(s.y, int(m["mer"]), "la mer à son niveau")
		_vrai(s.x >= int(m["origine"].x) + int(m["largeur"]), "sa source est dans le vide, hors de la terre")
	_vrai(noms.has("Lakes") and (noms["Lakes"]["sources"] as Array).size() >= 1, "au moins un lac")
	if noms.has("Lava"):
		_egal(noms["Lava"]["preset"], "lave", "la lave a son aspect")
	# Chaque lac est une cuvette : sa source est une case vide au-dessus d'un fond, dont les colonnes voisines sont plus
	# hautes que lui à quelques cases de là.
	var h: PackedInt32Array = m["h"]
	var w: int = m["largeur"]
	var o: Vector2i = m["origine"]
	for s in noms.get("Lakes", {"sources": []})["sources"]:
		var fond := h[(s.z - o.y) * w + (s.x - o.x)]
		_egal(fond, s.y - 1, "la source du lac %s est juste au-dessus de son fond" % s)
	# ⚠ UNE CUVETTE NE FUIT PAS (vu à l'image : une mare de lave couvrait la mer) : depuis sa source, à la hauteur de sa
	# source, l'eau ne passe que sur des colonnes plus basses — elle ne doit jamais atteindre le bord ni la mer.
	var cuvettes: Array = noms.get("Lakes", {"sources": []})["sources"] + noms.get("Lava", {"sources": []})["sources"]
	_vrai(cuvettes.size() >= 2, "des lacs et de la lave à éprouver (%d)" % cuvettes.size())
	for s in cuvettes:
		var vus := {}
		var pile := [Vector2i(s.x, s.z) - o]
		var fuit := false
		while not pile.is_empty() and not fuit:
			var q: Vector2i = pile.pop_back()
			if vus.has(q):
				continue
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= int(m["profondeur"]):
				fuit = true
				break
			var hq := h[q.y * w + q.x]
			if hq >= s.y:
				continue
			if hq < int(m["mer"]):
				fuit = true
				break
			vus[q] = true
			for d in G.DIRS4:
				pile.append(q + d)
		_vrai(not fuit, "la cuvette de %s ne fuit pas (%d colonnes d'eau)" % [s, vus.size()])


func _le_croquis() -> void:
	print("— le croquis")
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color("#2a5fd0"))                        # la mer
	img.fill_rect(Rect2i(12, 12, 40, 40), Color("#4caf50"))   # la terre
	img.fill_rect(Rect2i(30, 14, 14, 14), Color("#9a9a9a"))   # une montagne
	img.fill_rect(Rect2i(16, 40, 4, 4), Color("#e02020"))     # deux places
	img.fill_rect(Rect2i(40, 40, 4, 4), Color("#e02020"))
	var chemin := OS.get_user_data_dir().path_join("test_croquis.png")
	img.save_png(chemin)
	var m := G.generer({"forme": "croquis", "croquis": chemin, "largeur": 64, "profondeur": 64, "graine": 1}, true)
	_egal(m["rapport"].get("croquis"), "lu", "le croquis est lu")
	_egal((m["lieux"] as Array).size(), 2, "ses deux taches rouges sont deux places")
	var h: PackedInt32Array = m["h"]
	var mer: int = m["mer"]
	_vrai(h[2 * 64 + 2] < mer, "le bleu du coin est la mer")
	_vrai(h[32 * 64 + 20] > mer, "le vert du milieu est la terre")
	var montagne := h[20 * 64 + 37]
	var plaine := h[34 * 64 + 22]
	_vrai(montagne > plaine + 2, "le gris est plus haut que le vert (%d contre %d)" % [montagne, plaine])
	var manquant := G.generer({"forme": "croquis", "croquis": "C:/nulle/part.png", "largeur": 32, "profondeur": 32}, true)
	_egal(manquant["rapport"].get("croquis"), "illisible", "un croquis introuvable est dit, le monde se fait quand même")
	DirAccess.remove_absolute(chemin)


func _les_bornes() -> void:
	print("— les bornes")
	var c := G.champs({"largeur": 9999, "hauteur": 2, "forme": "lune", "relief": -3.0, "inconnu": 1})
	_egal(c["largeur"], 256, "la largeur bornée à 256")
	_egal(c["hauteur"], 8, "la hauteur bornée à 8")
	_egal(c["forme"], "ile", "une forme inconnue devient une île")
	_egal(c["relief"], 0.0, "le relief borné à 0")
	_vrai(not c.has("inconnu"), "un champ inconnu n'entre pas")
	var t0 := Time.get_ticks_msec()
	var grand := G.generer({"largeur": 160, "profondeur": 160, "hauteur": 40, "souterrains": 0.6, "lieux": 6, "graine": 9})
	var ms := Time.get_ticks_msec() - t0
	print("    160 × 160 × 40 : %d cases en %d ms (%s)" % [grand["rapport"]["cases"], ms, grand["rapport"]])
	_vrai(ms < 60000, "un monde de 160 × 160 se fait en moins d'une minute (%d ms)" % ms)


func _l_apercu() -> void:
	print("— l'aperçu")
	var m := G.generer({"largeur": 100, "profondeur": 60, "graine": 2}, true)
	var img := G.apercu(m, 256)
	_egal(img.get_width(), 200, "l'aperçu agrandi par un entier (100 → 200)")
	_egal(img.get_height(), 120, "et garde ses proportions")


func _le_feuillage() -> void:
	print("— le feuillage")
	var champs := {"graine": 12, "largeur": 96, "profondeur": 96, "lieux": 4, "lacs": 2, "feuillage": 0.8, "sol2": 0.5}
	var m := G.generer(champs)
	var semis: Array = m["semis"]
	_vrai(semis.size() > 300, "des points à planter (%d)" % semis.size())
	_egal(G.generer(champs)["semis"], semis, "la même graine sème aux mêmes points")
	var h: PackedInt32Array = m["h"]
	var r: PackedStringArray = m["role"]
	var w: int = m["largeur"]
	var o: Vector2i = m["origine"]
	var mal := 0
	var par_role := {}
	for s in semis:
		var i := (int(round(s[1])) - o.y) * w + (int(round(s[0])) - o.x)
		if r[i] == "chemin" or h[i] <= int(m["mer"]) or float(s[2]) < float(h[i]) + 1.0:
			mal += 1
		par_role[s[3]] = int(par_role.get(s[3], 0)) + 1
	_egal(mal, 0, "aucun point sur un chemin, une place ou la mer, et chacun au-dessus de son sol")
	var lacs: Array = []
	for e in m["eaux"]:
		if e["nom"] == "Lakes":
			lacs = e["sources"]
	var dans_un_lac := 0
	for s in semis:
		for l in lacs:
			if Vector2(s[0], s[1]).distance_to(Vector2(l.x, l.z)) < 2.0:
				dans_un_lac += 1
	_egal(dans_un_lac, 0, "aucun point au fond d'un lac")
	_vrai(int(par_role.get("sol2", 0)) * 2 > int(par_role.get("roche", 0)), "le sous-bois est plus dense que la roche (%s)"
		% par_role)
	_egal((G.generer({"graine": 12, "largeur": 48, "profondeur": 48, "feuillage": 0.0})["semis"] as Array).size(), 0,
		"« Foliage » à 0 : rien à planter")
