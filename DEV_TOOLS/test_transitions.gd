extends SceneTree
## TEST — LES TRANSITIONS ENTRE COUCHES (`transitions.gd`, Jordan, 6 octobre 2026).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_transitions.gd
##
## ⚠ LES ATTENDUS NE PASSENT PAS PAR LA RÈGLE (charte §6) : poids trilinéaires écrits à la main, et la CONTINUITÉ jugée par
## son effet — en un point d'une face commune à deux tuiles voisines, la part de chaque couche dans l'aspect doit être la
## même vue de l'une et de l'autre (sinon une marche à chaque joint), sur des mondes au hasard (graine fixe).
## ⚠ LE SHADER NE SE COMPILE PAS EN HEADLESS : son TEXTE est lu (les mêmes étapes que `melange`), l'image se juge avec
## fenêtre (`DEV_TOOLS/capture_transitions.gd`).

const TR := preload("res://addons/marchingblocks_core/transitions.gd")
const Rendu := preload("res://addons/marchingblocks_core/transitions_rendu.gd")

var _ok := 0
var _echecs := 0
var _premier := ""
var _finies := 0


func _initialize() -> void:
	print("=== TEST — les transitions entre couches ===\n")
	# ⚠ UN SCRIPT QUI NE COMPILE PAS FAIT ÉCHOUER CHAQUE APPEL EN SILENCE, ET LA SUITE CONCLUAIT « OK » (vu : 14 sur 14,
	# le cœur ne compilait pas) : on exige d'abord qu'il se charge.
	for chemin in ["res://addons/marchingblocks_core/transitions.gd", "res://addons/marchingblocks_core/transitions_rendu.gd",
			"res://app/transitions.gd"]:
		var sc: Script = load(chemin)
		_dire(sc != null and sc.can_instantiate(), "%s se charge" % chemin.get_file())
	_les_poids()
	_la_regle()
	_la_continuite()
	_la_table()
	_la_texture()
	_le_shader()
	_le_representant()
	_dire(_finies == 7, "SENTINELLE : les sept sections sont allées jusqu'au bout (%d) — une erreur d'exécution abandonne une fonction en silence" % _finies)
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
		if _echecs <= 12:
			print("  ÉCHEC — %s" % quoi)


const R := {"largeur": 0.5, "avance": 0.0, "bruit": 0.0, "grain": 1.0, "creux": 0.0}


## « C|D » : C couvre D. `ra` : quand 0 couvre 1 ; `rb` : quand 1 couvre 0.
func _table_ab(ra := R, rb := R) -> Dictionary:
	return {"0|1": ra, "1|0": rb}


func _les_poids() -> void:
	var f := Vector3(0.25, 0.5, 0.75)
	var somme := 0.0
	for k in 8:
		somme += TR.poids(k, f)
	_dire(absf(somme - 1.0) < 1e-9, "les huit poids font 1 (%f)" % somme)
	_dire(absf(TR.poids(0, f) - 0.75 * 0.5 * 0.25) < 1e-9, "coin (0,0,0) : (1−fx)(1−fy)(1−fz), à la main")
	_dire(absf(TR.poids(7, f) - 0.25 * 0.5 * 0.75) < 1e-9, "coin (1,1,1) : fx·fy·fz")
	_dire(absf(TR.poids(1, f) - 0.25 * 0.5 * 0.25) < 1e-9, "coin (1,0,0) : fx(1−fy)(1−fz)")
	_finies += 1


func _la_regle() -> void:
	var rien: Array = [-1, -1, -1, -1, -1, -1, -1, -1]
	var a_seul: Array = [0, 0, 0, 0, -1, -1, -1, -1]
	_dire(TR.melange(a_seul, Vector3(0.5, 0.5, 0.5), rien, _table_ab()).is_empty(), "une seule couche : rien ne se mêle")
	# Moitié 0 (x = 0), moitié 1 (x = 1), au milieu : s = ½.
	var moitie: Array = [0, 1, 0, 1, 0, 1, 0, 1]
	_dire(TR.melange(moitie, Vector3(0.5, 0.5, 0.5), rien, {}).is_empty(), "une paire éteinte (table vide) : rien")
	_dire(TR.melange(moitie, Vector3(0.5, 0.5, 0.5), rien, {"0|1": R}).is_empty(),
		"une seule direction dans la table (paire à moitié décrite) : rien")
	var m: Dictionary = TR.melange(moitie, Vector3(0.5, 0.5, 0.5), rien, _table_ab())
	_dire(m["proprio"] == 0 and m["autre"] == 1, "la propriétaire est le plus petit rang (0), l'autre le 1")
	_dire(absf(float(m["s"]) - 0.5) < 1e-9, "au milieu, la part de l'autre est ½")
	# Par défaut, 0 (prioritaire) couvre : l'autre (1) se voit avec 1 − visible(½) = ½ sans décalage.
	_dire(absf(float(m["vote"])) < 1e-9 and absf(float(m["alpha"]) - 0.5) < 1e-9,
		"par défaut la prioritaire couvre ; au milieu, sans décalage, l'alpha vaut ½ (%f)" % m["alpha"])
	# L'avance : la couvrante déborde. Prioritaire 0, avance 0,3 : visible_0(½) = smoothstep(¼, ¾, ½ + 0,3) = 1.
	var avance := R.duplicate()
	avance["avance"] = 0.3
	var m2: Dictionary = TR.melange(moitie, Vector3(0.5, 0.5, 0.5), rien, _table_ab(avance, R))
	_dire(absf(float(m2["alpha"])) < 1e-9, "0 couvre avec une avance de 0,3 : au milieu, plus rien de 1 (%f)" % m2["alpha"])
	# Le pinceau : les huit coins choisissent 1 → c'est 1 qui couvre, avec SES réglages (avance 0,3 dans « 1|0 »).
	var tout_1: Array = [1, 1, 1, 1, 1, 1, 1, 1]
	var m3: Dictionary = TR.melange(moitie, Vector3(0.5, 0.5, 0.5), tout_1, _table_ab(R, avance))
	_dire(absf(float(m3["vote"]) - 1.0) < 1e-9 and absf(float(m3["alpha"]) - 1.0) < 1e-9,
		"le pinceau fait couvrir 1 partout : ses réglages, l'autre se voit tout entière (%f)" % m3["alpha"])
	# Un choix d'une TROISIÈME couche compte comme la priorité.
	var tiers: Array = [5, 5, 5, 5, 5, 5, 5, 5]
	_dire(absf(float(TR.melange(moitie, Vector3(0.5, 0.5, 0.5), tiers, _table_ab())["vote"])) < 1e-9,
		"un choix d'une couche qui n'est pas là compte comme la priorité")
	# Aux bouts, plus rien : sur la face x = 0 (que des 0), l'alpha est nul quels que soient les réglages.
	var fort := {"largeur": 1.0, "avance": 0.5, "bruit": 1.0, "grain": 1.0, "creux": 1.0}
	var bout: Dictionary = TR.melange(moitie, Vector3(0.0, 0.3, 0.7), rien, _table_ab(fort, fort), {0: 0.0, 1: 0.0}, 1.0)
	_dire(bout.is_empty() or absf(float(bout["alpha"])) < 1e-9, "sur la face des seules cases 0, rien de 1, même réglages au maximum")
	var bout1: Dictionary = TR.melange(moitie, Vector3(1.0, 0.3, 0.7), rien, _table_ab(fort, fort), {0: 1.0, 1: 1.0}, 0.0)
	_dire(not bout1.is_empty() and absf(float(bout1["alpha"]) - 1.0) < 1e-9, "sur la face des seules cases 1 : tout 1")
	# Le creux : la couvrante (0) remplit d'abord les creux de la couverte (1) — un creux sombre (h = 0) la fait gagner.
	var creux := R.duplicate()
	creux["creux"] = 0.6
	var sombre: Dictionary = TR.melange(moitie, Vector3(0.5, 0.5, 0.5), rien, _table_ab(creux, R), {1: 0.0})
	var clair: Dictionary = TR.melange(moitie, Vector3(0.5, 0.5, 0.5), rien, _table_ab(creux, R), {1: 1.0})
	_dire(float(sombre["alpha"]) < float(clair["alpha"]),
		"creux : dans le sombre de 1, la couvrante 0 l'emporte plus (alpha de 1 : %f < %f)" % [sombre["alpha"], clair["alpha"]])
	# Des cases vides ne comptent pas : 0 et 1 sur la rangée du bas, rien au-dessus — la part reste ½ au milieu.
	var vide_dessus: Array = [0, 1, -1, -1, 0, 1, -1, -1]
	_dire(absf(float(TR.melange(vide_dessus, Vector3(0.5, 0.5, 0.5), rien, _table_ab())["s"]) - 0.5) < 1e-9,
		"les cases vides ne comptent pas dans la part")


## LA CONTINUITÉ, par son effet : en un point d'une face commune à deux sommets voisins, la part de chaque rang dans
## l'aspect (1 − α pour la propriétaire, α pour l'autre) est la même vue des deux tuiles.
	_finies += 1


func _la_continuite() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 610
	var rg_a := {"largeur": 0.4, "avance": 0.25, "bruit": 0.6, "grain": 1.0, "creux": 0.5}
	var rg_b := {"largeur": 0.7, "avance": -0.2, "bruit": 0.3, "grain": 2.0, "creux": 0.2}
	var table := _table_ab(rg_a, rg_b)
	var essais := 0
	var ecarts := 0
	var pire := 0.0
	for monde in 60:
		var cases := {}
		var choix := {}
		for x in 4:
			for y in 4:
				for z in 4:
					var t := rng.randi() % 3
					if t > 0:
						cases[Vector3i(x, y, z)] = t - 1
					if rng.randf() < 0.3:
						choix[Vector3i(x, y, z)] = rng.randi() % 2
		for v in [Vector3i(0, 0, 0), Vector3i(1, 1, 1), Vector3i(0, 1, 2), Vector3i(2, 0, 1)]:
			for axe in 3:
				var e := Vector3i.ZERO
				e[axe] = 1
				for n_point in 4:
					var f := Vector3(rng.randf(), rng.randf(), rng.randf())
					f[axe] = 1.0
					var g := f
					g[axe] = 0.0
					# Une face dont les quatre cases sont vides ne porte aucune surface : rien à raccorder.
					var face_pleine := false
					for k in 8:
						if (k >> axe) & 1 == 1 and cases.has(v + Vector3i(k & 1, (k >> 1) & 1, (k >> 2) & 1)):
							face_pleine = true
					if not face_pleine:
						continue
					var h := {0: rng.randf(), 1: rng.randf()}
					var bruit := rng.randf()
					var p1 := _parts(TR.melange(_huit(cases, v), f, _huit(choix, v), table, h, bruit), _huit(cases, v))
					var p2 := _parts(TR.melange(_huit(cases, v + e), g, _huit(choix, v + e), table, h, bruit), _huit(cases, v + e))
					if p1.is_empty() or p2.is_empty():
						continue
					essais += 1
					var d := 0.0
					for r in [0, 1]:
						d = maxf(d, absf(float(p1.get(r, 0.0)) - float(p2.get(r, 0.0))))
					pire = maxf(pire, d)
					if d > 1e-6:
						ecarts += 1
	_dire(essais > 500 and ecarts == 0, "aux joints de deux tuiles, chaque couche a la même part des deux côtés (%d points, %d écarts, pire %f)" % [essais, ecarts, pire])
	_finies += 1


func _huit(d: Dictionary, v: Vector3i) -> Array:
	var sortie: Array = []
	for k in 8:
		sortie.append(int(d.get(v + Vector3i(k & 1, (k >> 1) & 1, (k >> 2) & 1), -1)))
	return sortie


## {rang: part dans l'aspect} — la propriétaire seule si rien ne se mêle ; {} si le point ne touche aucune case.
func _parts(m: Dictionary, rangs: Array) -> Dictionary:
	if m.is_empty():
		var seul := 999
		for r in rangs:
			if int(r) >= 0:
				seul = mini(seul, int(r))
		return {} if seul == 999 else {seul: 1.0}
	return {m["proprio"]: 1.0 - float(m["alpha"]), m["autre"]: float(m["alpha"])}


func _la_table() -> void:
	var paires := {"1|2": {"actif": true, "couvre": {"1": {"avance": 0.1}, "2": {"avance": -0.1}}},
		"1|3": {"actif": false, "couvre": {}}}
	var t: Dictionary = TR.table(paires, {"1": 0, "2": 3, "3": 1})
	_dire(t.size() == 2 and t.has("0|3") and t.has("3|0"), "une paire active : ses deux directions, par RANG (%s)" % [t.keys()])
	_dire(absf(float(t["0|3"]["avance"]) - 0.1) < 1e-6 and absf(float(t["3|0"]["avance"]) + 0.1) < 1e-6,
		"chaque direction garde SES réglages (« 1 couvre » : 0,1 ; « 2 couvre » : −0,1)")
	_dire(absf(float(t["0|3"]["largeur"]) - TR.REGLAGES["largeur"]) < 1e-6, "un réglage absent prend sa valeur par défaut")
	_dire(TR.table(paires, {"1": 0}).is_empty(), "une couche supprimée : la paire ne dessine plus rien")
	_dire(TR.cle_de_paire("12", "3") == "3|12" and TR.cle_de_paire("3", "12") == "3|12", "la clé d'une paire : ids croissants (en nombres)")
	_dire(absf(float(TR.reglages({"largeur": 9.0})["largeur"]) - 1.0) < 1e-6, "un réglage hors bornes est ramené dedans")
	_finies += 1


func _la_texture() -> void:
	var union := {Vector3i(0, 0, 0): 0, Vector3i(3, -2, 5): 2, Vector3i(-4, 1, 1): 1}
	var d: Dictionary = TR.construire(union, {Vector3i(0, 0, 0): 1})
	_dire(d["origine"] == Vector3i(-4, -2, 0) - Vector3i.ONE * TR.MARGE, "l'origine : le coin bas de l'union moins la marge")
	_dire(d["taille"] == Vector3i(8, 4, 6) + Vector3i.ONE * 2 * TR.MARGE, "la taille : la boîte de l'union plus deux marges")
	var o: PackedByteArray = d["octets"]
	var n3: Vector3i = d["taille"]
	_dire(o.size() == 2 * n3.x * n3.y * n3.z, "DEUX octets par case (RG8, 21 octobre 2026)")
	_dire(o[2 * TR.indice(d, Vector3i(3, -2, 5))] == 3 and o[2 * TR.indice(d, Vector3i(-4, 1, 1))] == 2,
		"chaque case porte rang + 1 (octet R)")
	var i0 := 2 * TR.indice(d, Vector3i(0, 0, 0))
	_dire(o[i0] == 1 and o[i0 + 1] == 2, "le choix (rang 1) au coin (0,0,0), de rang 0 : R = 1, G = 2")
	_dire(TR.rang_lu(d, Vector3i(0, 0, 0)) == 0 and TR.choix_lu(d, Vector3i(0, 0, 0)) == 1, "… relus : rang 0, choix 1")
	_dire(o[2 * TR.indice(d, Vector3i(1, 0, 0))] == 0 and o[2 * TR.indice(d, Vector3i(1, 0, 0)) + 1] == 0, "une case vide : 0, 0")
	TR.poser_choix(d, Vector3i(0, 0, 0), -1)
	_dire(o.size() == (d["octets"] as PackedByteArray).size() and (d["octets"] as PackedByteArray)[i0] == 1
		and (d["octets"] as PackedByteArray)[i0 + 1] == 0, "effacer le choix garde le rang")
	TR.poser_case(d, Vector3i(0, 0, 0), 14)
	_dire(TR.rang_lu(d, Vector3i(0, 0, 0)) == 14, "le rang 14 (la dernière couche fondue avant le 21 octobre)")
	# ⚠ LES 255 COUCHES (Jordan, 21 octobre 2026) : le rang 15 et au-delà se fondent ; le choix aussi.
	TR.poser_case(d, Vector3i(0, 0, 0), 15)
	TR.poser_choix(d, Vector3i(0, 0, 0), 21)
	_dire(TR.rang_lu(d, Vector3i(0, 0, 0)) == 15 and TR.choix_lu(d, Vector3i(0, 0, 0)) == 21,
		"le rang 15 et le choix 21 entrent dans la texture (%d, %d)" % [TR.rang_lu(d, Vector3i(0, 0, 0)),
		TR.choix_lu(d, Vector3i(0, 0, 0))])
	TR.poser_case(d, Vector3i(0, 0, 0), TR.MAXI - 1)
	_dire(TR.rang_lu(d, Vector3i(0, 0, 0)) == 254 and TR.choix_lu(d, Vector3i(0, 0, 0)) == 21,
		"le plus haut rang (254) tient dans l'octet R, sans toucher G")
	TR.poser_choix(d, Vector3i(0, 0, 0), -1)
	TR.poser_case(d, Vector3i(0, 0, 0), TR.MAXI)
	_dire(TR.MAXI == 255 and TR.rang_lu(d, Vector3i(0, 0, 0)) == -1, "une couche au-delà de MAXI (255) n'entre pas")
	TR.poser_case(d, Vector3i(0, 0, 0), 0)
	_dire(TR.indice(d, Vector3i(100, 0, 0)) < 0 and not TR.poser_case(d, Vector3i(100, 0, 0), 1),
		"hors de la boîte : refusé (il faudra reconstruire)")
	_dire(TR.poser_case(d, Vector3i(100, 0, 0), -1), "vider une case hors de la boîte ne demande rien")
	var tr: Array = TR.tranches(d)
	_dire(tr.size() == (d["taille"] as Vector3i).z and (tr[0] as Image).get_width() == (d["taille"] as Vector3i).x,
		"une tranche par z, de la largeur x")
	var t: Vector3i = Vector3i(3, -2, 5) - (d["origine"] as Vector3i)
	_dire((tr[t.z] as Image).get_format() == Image.FORMAT_RG8 and int(round((tr[t.z] as Image).get_pixel(t.x, t.y).r * 255.0)) == 3,
		"la case relue dans SA tranche (RG8), à SA place")
	var t0: Vector3i = Vector3i(0, 0, 0) - (d["origine"] as Vector3i)
	TR.poser_choix(d, Vector3i(0, 0, 0), 200)
	var px: Color = (TR.tranches(d)[t0.z] as Image).get_pixel(t0.x, t0.y)
	_dire(int(round(px.r * 255.0)) == 1 and int(round(px.g * 255.0)) == 201, "le choix 200 relu dans le canal G de sa tranche")
	TR.poser_choix(d, Vector3i(0, 0, 0), -1)
	# Une mise à jour : seule la tranche touchée est refaite, et elle porte la nouvelle valeur.
	TR.poser_case(d, Vector3i(3, -2, 5), -1)
	var tr2: Array = TR.tranches(d, {t.z: true}, tr)
	_dire(tr2[0] == tr[0] and tr2[t.z] != tr[t.z] and int(round((tr2[t.z] as Image).get_pixel(t.x, t.y).r * 255.0)) == 0,
		"la mise à jour ne refait que la tranche touchée")


## LE SHADER DIT LA MÊME RÈGLE : ses étapes, lues dans son texte.
	_finies += 1


func _le_shader() -> void:
	var s: String = TR.SHADER
	for morceau in ["rang_en(b + o, 0)", "(canal == 0 ? v.r : v.g)", "max(proprio, autre) >= textureSize(table, 0).y",
			"texelFetch(rep_params, ivec2(k, 0), 0)", "r[k] < proprio", "if (part > meilleur)", "meilleur / (meilleur + w_proprio)",
			"min(proprio, autre)", "vote_autre += w[k]", "* 4.0 * s_c * (1.0 - s_c)",
			"smoothstep(0.5 - p1.g * 0.5, 0.5 + p1.g * 0.5, s_c + decalage)",
			"vote_autre * a_autre + (1.0 - vote_autre) * a_proprio", "ivec2(2 * proprio, autre)", "ivec2(2 * autre, proprio)",
			"vue.xyz *= 1.0 - 2e-4", "POSITION = PROJECTION_MATRIX * vue", "centre = MODEL_MATRIX[3].xyz", "round(centre - vec3(1.0))",
			"clamp(p_monde - vec3(b) - vec3(0.5), vec3(0.0), vec3(1.0))"]:
		_dire(s.contains(morceau), "le shader : « %s »" % morceau)
	# ⚠ LES FILS CLAIRS (21 octobre 2026) : poussé le long de sa normale, le passage se rétractait d'un cheveu sur chaque pli
	# et la tuile native transparaissait. Il est tiré le long du rayon de vue ; jamais plus poussé le long de la normale.
	_dire(not s.contains("VERTEX += NORMAL") and not s.contains("VERTEX +="),
		"le passage n'est plus poussé le long de sa normale (les fils clairs le long des joints)")
	var sh := Shader.new()
	sh.code = s
	_dire(sh.get_mode() == Shader.MODE_SPATIAL, "le shader se lit (mode spatial)")
	var rendu = Rendu.new()
	rendu.reconstruire({Vector3i(0, 0, 0): 0, Vector3i(1, 0, 0): 1}, {})
	# ⚠ DES RÉGLAGES DIFFÉRENTS PAR DIRECTION : avec les mêmes, une table transposée ne se voyait pas (mutation d'abord muette).
	rendu.poser_table(TR.table({"1|2": {"actif": true, "couvre": {"1": {"largeur": 0.2, "creux": 0.1},
		"2": {"largeur": 0.8}}}}, {"1": 0, "2": 1}))
	var img: Image = (rendu.materiau.get_shader_parameter("table") as Texture2D).get_image()
	_dire(img.get_pixel(0, 1).r > 0.5 and absf(img.get_pixel(0, 1).g - 0.8) < 1e-6 and img.get_pixel(0, 0).r < 0.5,
		"la table : « 1 couvre 0 » (l'id 2) au texel (2·0, 1), sa largeur 0,8 ; rien sur la diagonale (%s)" % img.get_pixel(0, 1))
	_dire(img.get_pixel(2, 0).r > 0.5 and absf(img.get_pixel(2, 0).g - 0.2) < 1e-6,
		"… et « 0 couvre 1 » (l'id 1) au texel (2·1, 0), sa largeur 0,2")
	_dire(absf(img.get_pixel(3, 0).r - 0.1) < 1e-6, "… son creux au texel (2·1 + 1, 0)")
	# ⚠ LES 255 COUCHES (21 octobre 2026) : la table et les représentants ont le NOMBRE RÉEL de couches.
	var rangs22 := {}
	for k in 22:
		rangs22[str(k + 1)] = k
	var t22 := TR.table({"17|22": {"actif": true, "couvre": {"17": {"largeur": 0.3}, "22": {"largeur": 0.7}}}}, rangs22)
	_dire(t22.has("16|21") and t22.has("21|16"), "une paire de rangs 16 et 21 a ses deux directions (%s)" % [t22.keys()])
	rendu.poser_table(t22)
	var img22: Image = (rendu.materiau.get_shader_parameter("table") as Texture2D).get_image()
	_dire(img22.get_width() == 44 and img22.get_height() == 22, "la table de 22 couches : 44 × 22 (%d × %d)"
		% [img22.get_width(), img22.get_height()])
	_dire(img22.get_pixel(2 * 21, 16).r > 0.5 and absf(img22.get_pixel(2 * 21, 16).g - 0.3) < 1e-6
		and absf(img22.get_pixel(2 * 16, 21).g - 0.7) < 1e-6, "« 16 couvre 21 » au texel (42, 16), « 21 couvre 16 » au (32, 21)")
	var reps: Array = []
	for k in 22:
		reps.append({"image": null, "couleur": Color(k / 21.0, 0.5, 0.25), "echelle": 1.0 + k, "rugosite": 0.5})
	rendu.poser_representants(reps)
	var arr: Texture2DArray = rendu.materiau.get_shader_parameter("representants")
	var prm: Image = (rendu.materiau.get_shader_parameter("rep_params") as Texture2D).get_image()
	_dire(arr.get_layers() == 22 and prm.get_width() == 22, "22 représentants : 22 tranches, 22 réglages (%d, %d)"
		% [arr.get_layers(), prm.get_width()])
	_dire(absf(prm.get_pixel(21, 0).r - 1.0) < 1e-6 and absf(prm.get_pixel(21, 1).r - 22.0) < 1e-6,
		"le représentant de rang 21 : sa couleur et son échelle à la colonne 21")
	_finies += 1


const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")
const AppTR := preload("res://app/transitions.gd")


## Un faux témoin : `tuiles` {nom: MaillageEdite}, `materiaux`, `occurrences` [{cle}] — ce que lit le représentant.
class FauxTemoin extends RefCounted:
	var tuiles := {}
	var materiaux: Array = [{}, {}, {}]
	var occurrences: Array = []


## Une tuile : un carré de dessus (côté `d`, matériau `m_dessus`) et quatre parois de 1 × 1 (matériau `m_paroi`).
func _tuile(d: float, m_dessus: int, m_paroi: int) -> RefCounted:
	var m: RefCounted = ME.new()
	var h := d * 0.5
	var s := PackedVector3Array([Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)])
	m.sommets = s
	m._ajouter(PackedInt32Array([0, 3, 2, 1]), Color.WHITE, m_dessus)   # vue de dehors, normale +Y (écrit à la main)
	for i in 4:
		var b: int = m.sommets.size()
		var x := float(i)
		m.sommets.append_array(PackedVector3Array([Vector3(x, -1, 5), Vector3(x + 1, -1, 5), Vector3(x + 1, 0, 5), Vector3(x, 0, 5)]))
		m._ajouter(PackedInt32Array([b, b + 1, b + 2, b + 3]), Color.WHITE, m_paroi)  # normale +Z
	return m


## LE REPRÉSENTANT PAR DÉFAUT EST LE DESSUS (13 octobre 2026) — attendus écrits à la main. La paroi (matériau 2) porte
## plus de FACES (4 contre 1) : l'ancienne règle la choisissait (la bande brune de `fonction_transitions.gif`).
func _le_representant() -> void:
	var t := FauxTemoin.new()
	t.tuiles["a"] = _tuile(1.0, 1, 2)
	t.occurrences = [{"cle": "a"}]
	_dire(t.tuiles["a"].normale(0).normalized().y > 0.99, "le dessus du faux témoin regarde +Y (l'attendu dépend de lui)")
	_dire(AppTR.representant_par_defaut(t) == 1, "le dessus (1) l'emporte sur la paroi (2), qui porte plus de faces : %d" % AppTR.representant_par_defaut(t))
	# Deux dessus : le matériau 0 couvre 0,25 sur une tuile vue 3 fois (0,75), le 1 couvre 1 sur une tuile vue une fois.
	var t2 := FauxTemoin.new()
	t2.tuiles["a"] = _tuile(1.0, 1, 2)
	t2.tuiles["b"] = _tuile(0.5, 0, 2)
	t2.occurrences = [{"cle": "a"}, {"cle": "b"}, {"cle": "b"}, {"cle": "b"}]
	_dire(AppTR.representant_par_defaut(t2) == 1, "aire × occurrences : 1 (1,0) devant 0 (0,75) — %d" % AppTR.representant_par_defaut(t2))
	t2.occurrences = [{"cle": "a"}, {"cle": "b"}, {"cle": "b"}, {"cle": "b"}, {"cle": "b"}, {"cle": "b"}]
	_dire(AppTR.representant_par_defaut(t2) == 0, "aire × occurrences : 0 (1,25) devant 1 (1,0) — %d" % AppTR.representant_par_defaut(t2))
	# Une tuile jamais vue ne compte pas.
	t2.occurrences = [{"cle": "a"}]
	_dire(AppTR.representant_par_defaut(t2) == 1, "une tuile sans occurrence ne pèse rien")
	# Aucun dessus porteur d'un matériau : l'ancienne règle (le plus de faces).
	var t3 := FauxTemoin.new()
	t3.tuiles["a"] = _tuile(1.0, -1, 2)
	t3.occurrences = [{"cle": "a"}]
	_dire(AppTR.representant_par_defaut(t3) == 2, "sans dessus matériau : le plus de faces (2)")
	t3.materiaux = []
	_dire(AppTR.representant_par_defaut(t3) == -1, "sans matériau : la légende (−1)")
	_finies += 1
