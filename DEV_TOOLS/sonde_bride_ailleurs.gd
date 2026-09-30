extends SceneTree
## LA BRIDE VIENT-ELLE D'AILLEURS ? — cherche, dans le témoin lié, un sommet de BORD et une direction DANS son
## plan tels qu'une AUTRE tuile se replie nettement AVANT celle du sommet. Sans un tel cas, garder la seule tuile
## en édition passerait pour juste (mutation muette de la fumée, 30 septembre 2026).
##
## Ne conçoit rien : elle rend les cas, du plus net au moins net. La fumée rejoue le premier et REVÉRIFIE sa
## condition (la tuile en édition garde de la marge quand le geste s'arrête).
##
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_bride_ailleurs.gd

const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const Sections := preload("res://addons/marchingblocks_core/sections.gd")
const PAS := 0.01
const LOIN := 0.4


func _initialize() -> void:
	var t: RefCounted = TL.depuis_le_temoin_calcule()
	var s: RefCounted = Sections.new(t)
	s.indexer()
	var photo: Dictionary = s.photo()
	var cas: Array = []
	for k in t.tuiles:
		for i in (s.bords[k] as Dictionary):
			var faces: Array = s.bords[k][i]
			if faces.size() != 1:
				continue
			var axe: int = faces[0]["axe"]
			for a in 3:
				if a == axe:
					continue
				for signe in [1.0, -1.0]:
					var dir := Vector3.ZERO
					dir[a] = signe
					var r := _premiers_replis(t, s, photo, k, i, dir)
					if r[1] < LOIN and r[0] > r[1] + 0.1:
						cas.append([r[0] - r[1], k, i, a, signe, r[0], r[1], r[2]])
					_rendre(t, photo)
	cas.sort_custom(func(x, y): return x[0] > y[0])
	print("%d cas où une autre tuile replie au moins 0,1 case avant celle du sommet" % cas.size())
	for c in cas.slice(0, 10):
		print("  %s sommet %d, axe local %d, sens %+d : la tuile replie à %s, « %s » à %.2f"
			% [c[1], c[2], c[3], int(c[4]), "jamais" if c[5] > 9.0 else "%.2f" % c[5], c[7], c[6]])
	quit(0)


## [amplitude où la tuile du sommet replie (99 si jamais avant LOIN + 0,2), amplitude où une autre replie, laquelle].
func _premiers_replis(t: RefCounted, s: RefCounted, photo: Dictionary, k: String, i: int, dir: Vector3) -> Array:
	var d0: Vector3 = s.projeter(k, i, dir)
	if d0.length() < 0.5:
		return [0.0, 99.0, ""]
	var sonde: Dictionary = s.propager(k, {i: Vector3.ONE})
	var gardes := {}
	for c in sonde:
		var m: RefCounted = t.tuiles[c]
		var choix: Array = []
		for f in m.faces.size():
			for j in m.faces[f]:
				if (sonde[c] as Dictionary).has(j):
					choix.append(f)
					break
		gardes[c] = m.gardes_de_repli(choix)
	var ici := 99.0
	var ailleurs := 99.0
	var qui := ""
	var a := PAS
	while a <= LOIN + 0.2 and (ici > 9.0 or ailleurs > 9.0):
		_rendre(t, photo)
		var r: Dictionary = s.propager(k, {i: s.projeter(k, i, dir * a)})
		s.deplacer(r, photo)
		for c in gardes:
			if (t.tuiles[c]).replie(gardes[c]):
				if c == k and ici > 9.0:
					ici = a
				elif c != k and ailleurs > 9.0:
					ailleurs = a
					qui = c
		a += PAS
	return [ici, ailleurs, qui]


func _rendre(t: RefCounted, photo: Dictionary) -> void:
	for c in photo:
		t.tuiles[c].sommets = (photo[c] as PackedVector3Array).duplicate()
