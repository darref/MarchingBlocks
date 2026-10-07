extends RefCounted
## LE SAC DE TRIANGLES DU GREFFON GODOT (7 octobre 2026, l'eau recalculée — PARITE.md §12) : ce que le banc du greffon
## (`test_greffon_peinture`) et son banc de bout en bout (`banc_eau_greffon.gd`) comparent. Écrit DEPUIS `rules_text` de
## `water_mesh_conformance.json` (« COMPARE AS A BAG »), pas copié de `test_parite._meme_sac` : c'est le banc d'un moteur.
##   - un triangle : 36 nombres, trois coins [px, py, pz, nx, ny, nz, r, g, b, a, u, v], dans le sens du FORMAT
##     (anti-horaire vu de l'avant) — les tableaux de Godot sont horaires : retournés ;
##   - même nombre ; chaque triangle attendu apparié à un triangle DISTINCT égal à l'une de ses trois ROTATIONS (jamais
##     une réflexion), coin par coin aux tolérances ; seaux par centre arrondi au centième, 27 voisins.

const TOL := {"position": 1e-4, "normal": 1e-3, "color": 1e-4, "uv": 1e-4}


## Les triangles des TABLEAUX calculés ({v, n, c, uv, i}, ordre de Godot), dans le sens du format.
static func triangles(a: Dictionary) -> Array:
	var v: PackedVector3Array = a["v"]
	var n: PackedVector3Array = a["n"]
	var c: PackedColorArray = a["c"]
	var uv: PackedVector2Array = a["uv"]
	var idx: PackedInt32Array = a["i"]
	var coin := func(k: int) -> Array:
		return [v[k].x, v[k].y, v[k].z, n[k].x, n[k].y, n[k].z, c[k].r, c[k].g, c[k].b, c[k].a, uv[k].x, uv[k].y]
	var sortie: Array = []
	for t in range(0, idx.size(), 3):
		sortie.append(coin.call(idx[t]) + coin.call(idx[t + 2]) + coin.call(idx[t + 1]))
	return sortie


## Les triangles d'un attendu (`vertices` + `triangles`), dépliés.
static func deplier(e: Dictionary) -> Array:
	var v: Array = e["vertices"]
	var sortie: Array = []
	for t in e["triangles"]:
		sortie.append((v[int(t[0])] as Array) + (v[int(t[1])] as Array) + (v[int(t[2])] as Array))
	return sortie


static func _coin_proche(a: Array, ia: int, b: Array, ib: int, tol: Dictionary) -> bool:
	for k in 12:
		var t: float = tol["position"] if k < 3 else (tol["normal"] if k < 6 else (tol["color"] if k < 10 else tol["uv"]))
		if absf(float(a[ia + k]) - float(b[ib + k])) > t:
			return false
	return true


static func _seau(t: Array) -> Vector3i:
	return Vector3i(roundi((float(t[0]) + float(t[12]) + float(t[24])) / 3.0 * 100.0),
		roundi((float(t[1]) + float(t[13]) + float(t[25])) / 3.0 * 100.0),
		roundi((float(t[2]) + float(t[14]) + float(t[26])) / 3.0 * 100.0))


## "" si les deux sacs sont égaux, sinon la raison (le premier triangle attendu sans partenaire).
static func meme_sac(attendu: Array, obtenu: Array, tol: Dictionary = TOL) -> String:
	if attendu.size() != obtenu.size():
		return "%d triangles au lieu de %d" % [obtenu.size(), attendu.size()]
	var seaux := {}
	for i in obtenu.size():
		var k := _seau(obtenu[i])
		if not seaux.has(k):
			seaux[k] = []
		seaux[k].append(i)
	var pris := {}
	for t: Array in attendu:
		var k0 := _seau(t)
		var trouve := false
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					if trouve:
						break
					for i in seaux.get(k0 + Vector3i(dx, dy, dz), []):
						if trouve or pris.has(i):
							continue
						var o: Array = obtenu[i]
						for r in 3:
							if _coin_proche(t, 0, o, 12 * r, tol) and _coin_proche(t, 12, o, 12 * ((r + 1) % 3), tol) \
									and _coin_proche(t, 24, o, 12 * ((r + 2) % 3), tol):
								trouve = true
								pris[i] = true
								break
		if not trouve:
			return "aucun triangle pour %s" % [t.slice(0, 3) + t.slice(12, 15) + t.slice(24, 27)]
	return ""


## Le résumé par genre (b du premier coin) : {genre: [triangles, aire]} — un diagnostic, avant l'appariement.
static func resume(tris: Array) -> Dictionary:
	var noms := {0.0: "still", 0.5: "river", 0.75: "foam", 1.0: "fall"}
	var r := {}
	for t: Array in tris:
		var g: String = noms.get(snappedf(float(t[8]), 0.25), "?")
		var a := Vector3(t[12] - t[0], t[13] - t[1], t[14] - t[2]).cross(Vector3(t[24] - t[0], t[25] - t[1], t[26] - t[2]))
		var e: Array = r.get(g, [0, 0.0])
		r[g] = [e[0] + 1, e[1] + a.length() * 0.5]
	return r
