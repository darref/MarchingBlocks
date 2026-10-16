extends SceneTree
## Sonde : subdiviser TOUTES les tuiles d'un témoin calculé d'un coup, puis UNE complétion des sections — au lieu de
## tuile par tuile (qui s'emballait, mesuré le 16 octobre 2026 : 10 min, 2,6 Go). Dit faces, triangles, temps, absences.
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const S := preload("res://addons/marchingblocks_core/sections.gd")

func _tris(t) -> int:
	var n := 0
	for c in t.tuiles:
		for f in t.tuiles[c].faces:
			n += (f as PackedInt32Array).size() - 2
	return n

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var t = TL.depuis_le_temoin_calcule(0.0)
	print("témoin : %d tuiles, %d triangles (%d ms)" % [t.tuiles.size(), _tris(t), Time.get_ticks_msec() - t0])
	var s = S.new(t)
	print("absences au départ : %d" % s.absences())
	for niveau in 2:
		t0 = Time.get_ticks_msec()
		for c in t.tuiles:
			var m = t.tuiles[c]
			m.subdiviser(range(m.faces.size()))
		var t1 := Time.get_ticks_msec()
		var r: Dictionary = s.completer()
		print("niveau %d : %d triangles ; subdiviser %d ms, compléter %d ms (%d coupes, %d échecs), absences %d" % [
			niveau + 1, _tris(t), t1 - t0, Time.get_ticks_msec() - t1, r["coupes"], r["echecs"], s.absences()])
	quit(0)
