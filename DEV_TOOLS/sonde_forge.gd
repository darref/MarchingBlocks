extends SceneTree
## Sonde de la forge : base subdivisée à N niveaux et arrondie, deux thèmes retouchés au dedans, variantes ; mesure les
## sommets de joint sans partenaire (dans un témoin, et entre deux témoins), les temps, les triangles.
const TL := preload("res://addons/marchingblocks_core/temoin_lie.gd")
const F := preload("res://DEV_TOOLS/forge_temoins.gd")

func _initialize() -> void:
	var niveau := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--niveau="):
			niveau = int(a.substr(9))
	var t0 := Time.get_ticks_msec()
	var base = TL.depuis_le_temoin_calcule(0.0)
	print("calcul %d ms" % (Time.get_ticks_msec() - t0)); t0 = Time.get_ticks_msec()
	print("subdivision : ", F.subdiviser_tout(base, niveau), " %d tris %d ms" % [F.triangles(base), Time.get_ticks_msec() - t0]); t0 = Time.get_ticks_msec()
	print("chanfrein : ", F.chanfreiner(base, 0.85), " %d ms" % (Time.get_ticks_msec() - t0)); t0 = Time.get_ticks_msec()
	print("joints sans partenaire (base) : %d" % _sans_partenaire_entre(base, base))
	var a = base.copie()
	var b = base.copie()
	var bb := F.bruit(5, 3.0)
	var ks := []
	for c in a.tuiles:
		ks.append(F.bosseler(a.tuiles[c], bb, 0.08, Vector3.ZERO, true))
		F.lisser_dedans(b.tuiles[c], 3, 0.6)
	print("retouches %d ms, facteurs min %s" % [Time.get_ticks_msec() - t0, ks.min()]); t0 = Time.get_ticks_msec()
	var v: Dictionary = F.creer_variantes(a, ["mb_plaque_b4h0_dehors", "mb_plaque_b2h2_dehors"], 2, func(m, k):
		F.bosseler(m, F.bruit(100 + k, 2.5), 0.12, Vector3.ZERO))
	print("variantes : ", v)
	print("joints sans partenaire : a %d, b %d, a↔b %d" % [_sans_partenaire_entre(a, a), _sans_partenaire_entre(b, b), _sans_partenaire_entre(a, b)])
	var bouge := 0
	for c in a.tuiles:
		if base.tuiles.has(c) and a.tuiles[c].sommets != base.tuiles[c].sommets: bouge += 1
	print("tuiles retouchées : %d / %d" % [bouge, a.tuiles.size()])
	quit(0)

func _sans_partenaire_entre(ta_: RefCounted, tb_: RefCounted) -> int:
	return _de(ta_, tb_) + (_de(tb_, ta_) if ta_ != tb_ else 0)

func _de(ta_: RefCounted, tb_: RefCounted) -> int:
	var occ_a := {}
	for o in ta_.occurrences: occ_a[o["sommet"]] = o
	var occ_b := {}
	for o in tb_.occurrences: occ_b[o["sommet"]] = o
	var n := 0
	for s in occ_a:
		var oa: Dictionary = occ_a[s]
		for axe in 3:
			for sens in [-1, 1]:
				var e := Vector3i.ZERO
				e[axe] = sens
				if not occ_b.has(s + e): continue
				var ob: Dictionary = occ_b[s + e]
				var tbm: RefCounted = tb_.tuiles[ob["cle"]]
				var index_b := {}
				for j in tbm.sommets.size():
					var pb: Vector3 = (ob["pose"] as Transform3D) * tbm.sommets[j]
					var cb := Vector3i((pb * 1000.0).floor())
					if not index_b.has(cb): index_b[cb] = []
					index_b[cb].append(pb)
				var tam: RefCounted = ta_.tuiles[oa["cle"]]
				var plan: float = float(s[axe]) + 1.0 + 0.5 * sens
				for i in tam.sommets.size():
					var pw: Vector3 = (oa["pose"] as Transform3D) * tam.sommets[i]
					if absf(pw[axe] - plan) > 0.0005: continue
					var ca := Vector3i((pw * 1000.0).floor())
					var trouve := false
					for dx in [-1, 0, 1]:
						for dy in [-1, 0, 1]:
							for dz in [-1, 0, 1]:
								for pb in index_b.get(ca + Vector3i(dx, dy, dz), []):
									trouve = trouve or (pb as Vector3).distance_to(pw) < 1e-5
					if not trouve: n += 1
	return n
