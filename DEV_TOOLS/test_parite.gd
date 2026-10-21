extends SceneTree
## TEST — LE CONTRAT DE LA PARITÉ DES GREFFONS (Jordan, 7 octobre 2026 : « parité complète des greffons à la 0.9.0 »).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_parite.gd
##
## Ce que les trois greffons recevront, gardé ici :
##   1. LES CINQ FICHIERS DE CAS (`epreuve_parite.gd`) sont à jour dans les TROIS greffons — un cas qui diverge du GDScript
##      (la règle changée sans régénérer) rougit ;
##   2. ILS EXERCENT CE QU'ILS NOMMENT (chaque raison de refus, chaque mode, chaque bout de la règle) ;
##   3. UNE SECONDE IMPLÉMENTATION, écrite ICI depuis le TEXTE des règles (`rules_text`), et pas depuis le cœur, rend les
##      mêmes réponses (le fondu, l'image, la pulsation, la phase, le défilement, la pose, le vent, Shrink, Widen, le
##      pinceau Select, la table) — la preuve que le texte suffit à un greffon, et l'attendu qui ne passe pas par la
##      fonction éprouvée (charte §6) ;
##   3 bis. LE MAILLAGE DE L'EAU (`water_mesh_conformance.json`, 7 octobre 2026) : l'appariement en sac que les greffons
##      emploieront rougit sur ce qu'il doit voir, la mer se relit pareil de son eau ou de ses tronçons, et les triangles
##      montrent ce que chaque cas nomme (plats sans jonction en T, nappe sous la dalle, cascade en volume, source…) ;
##   4. L'EXPORT écrit ce que le contrat dit : `transitions` et `foliage` dans `world.json` (indices, représentants et
##      leurs images, modèles copiés), les images des textures animées dans le `.mbset` — et un monde sans elles se lit
##      toujours.

const EP := preload("res://addons/marchingblocks_core/epreuve_parite.gd")
const FM := preload("res://addons/marchingblocks_core/format_monde.gd")
const FN := preload("res://addons/marchingblocks_core/format_neutre.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Anim := preload("res://addons/marchingblocks_core/animation_materiau.gd")
const FE := preload("res://addons/marchingblocks_core/feuillage.gd")
const TR := preload("res://addons/marchingblocks_core/transitions.gd")
const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")

const DOSSIERS := ["res://addons/marchingblocks_paint", "res://engines/unity/com.marchingblocks.paint/Tests",
	"res://engines/unreal/MarchingBlocksPaint/Tests"]

var _ok := 0
var _echecs := 0
var _premier := ""
var _finies := 0
var _dossier := ""


func _initialize() -> void:
	print("=== TEST — le contrat de la parité des greffons ===\n")
	for chemin in ["res://addons/marchingblocks_core/epreuve_parite.gd", "res://addons/marchingblocks_core/format_monde.gd",
			"res://addons/marchingblocks_core/animation_materiau.gd", "res://addons/marchingblocks_core/feuillage.gd",
			"res://addons/marchingblocks_core/transitions.gd", "res://addons/marchingblocks_core/outils.gd"]:
		var sc: Script = load(chemin)
		_dire(sc != null and sc.can_instantiate(), "%s se charge" % chemin.get_file())
	_dossier = ProjectSettings.globalize_path("user://test_parite")
	# ⚠ VIDÉ D'ABORD (vu le 7 octobre 2026) : une image écrite par une exécution PRÉCÉDENTE rendait muette la mutation
	# « l'image du représentant non écrite » — le test relisait le fichier d'hier.
	_vider(_dossier)
	DirAccess.make_dir_recursive_absolute(_dossier)
	var cas: Dictionary = EP.cas_d_epreuve()
	_dire(not cas.has("erreur"), "les cas se calculent (%s)" % str(cas.get("erreur", "")))
	if cas.has("erreur"):
		_fin()
		return
	# Relus comme un greffon les lira : passés par le JSON.
	var lus := {}
	for sujet in EP.FICHIERS:
		lus[sujet] = JSON.parse_string(JSON.stringify(cas[sujet]))
	_a_jour(lus)
	_transitions(lus["transitions"])
	_animation(lus["animation"])
	_feuillage(lus["foliage"])
	_eau(lus["water"])
	_maillage_de_l_eau(lus["water_mesh"])
	_edition(lus["editing"])
	_l_export_du_monde()
	_l_export_des_images()
	_dire(_finies == 9, "SENTINELLE : les neuf sections sont allées jusqu'au bout (%d)" % _finies)
	_fin()


func _fin() -> void:
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
		if _echecs <= 15:
			print("  ÉCHEC — %s" % quoi)


## Deux valeurs JSON égales, les réels à `tol` près.
static func _proche(a: Variant, b: Variant, tol := 1e-6) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) <= tol
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _proche(a[i], b[i], tol):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _proche(a[k], b[k], tol):
				return false
		return true
	return a == b


static func _par_sorte(f: Dictionary) -> Dictionary:
	var d := {}
	for c in f["cases"]:
		if not d.has(c["kind"]):
			d[c["kind"]] = []
		d[c["kind"]].append(c)
	return d


static func _nomme(f: Dictionary, nom: String) -> Dictionary:
	for c in f["cases"]:
		if c["name"] == nom:
			return c
	return {}


# ── 1. LES FICHIERS LIVRÉS SONT À JOUR, DANS LES TROIS GREFFONS ────────────────────────────────────────

func _a_jour(lus: Dictionary) -> void:
	for sujet in EP.FICHIERS:
		for d in DOSSIERS:
			var chemin: String = d.path_join(EP.FICHIERS[sujet])
			var texte := FileAccess.get_file_as_string(chemin)
			var fichier: Variant = JSON.parse_string(texte) if texte != "" else null
			_dire(fichier is Dictionary and fichier == lus[sujet],
				"%s est à jour (sinon : relancer DEV_TOOLS/generer_cas_d_epreuve.gd)" % chemin)
		var f: Dictionary = lus[sujet]
		_dire(f.get("format", "").begins_with("marchingblocks-") and int(f.get("version", 0)) == 1
			and (f.get("rules_text", []) as Array).size() >= 8, "%s : format, version, règle écrite" % EP.FICHIERS[sujet])
		# ⚠ Unity ignore un fichier de paquet sans son .meta (charte §4) : chacun a le sien.
		_dire(FileAccess.file_exists(DOSSIERS[1].path_join(EP.FICHIERS[sujet]) + ".meta"),
			"%s a son .meta dans le paquet Unity" % EP.FICHIERS[sujet])
		for c in f["cases"]:
			if not (c.has("name") and c.has("kind") and c.has("input") and c.has("expected")):
				_dire(false, "%s : un cas sans nom, sorte, entrée ou attendu" % EP.FICHIERS[sujet])
				break
	_finies += 1


# ── 2 et 3. LES TRANSITIONS ─────────────────────────────────────────────────────────────────────────────

const DEFAUTS_TR := {"softness": 0.45, "reach": 0.2, "irregularity": 0.35, "grain": 1.5, "fills_hollows": 0.5}
const BORNES_TR := {"softness": [0.05, 1.0], "reach": [-0.5, 0.5], "irregularity": [0.0, 1.0], "grain": [0.25, 6.0],
	"fills_hollows": [0.0, 1.0]}


static func _lisse(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## LE FONDU, RÉÉCRIT DEPUIS LE TEXTE de `rules_text` (pas depuis `Transitions.melange`).
static func _fondu(rangs: Array, f: Array, choix: Array, table: Dictionary, h: Dictionary, n: float) -> Dictionary:
	var w: Array = []
	var owner := -1
	for k in 8:
		var dx := k & 1
		var dy := (k >> 1) & 1
		var dz := (k >> 2) & 1
		w.append((f[0] if dx == 1 else 1.0 - f[0]) * (f[1] if dy == 1 else 1.0 - f[1]) * (f[2] if dz == 1 else 1.0 - f[2]))
		var r := int(rangs[k])
		if r >= 0 and (owner < 0 or r < owner):
			owner = r
	if owner < 0:
		return {}
	var w_owner := 0.0
	var parts := {}
	for k in 8:
		var r := int(rangs[k])
		if r == owner:
			w_owner += w[k]
		elif r >= 0:
			parts[r] = float(parts.get(r, 0.0)) + w[k]
	var other := -1
	var meilleure := 0.0
	for k in 8:
		var r := int(rangs[k])
		if r >= 0 and r != owner and parts[r] > meilleure:
			meilleure = parts[r]
			other = r
	if other < 0:
		return {}
	var autre_couvre := "%d|%d" % [other, owner]
	var proprio_couvre := "%d|%d" % [owner, other]
	if not table.has(autre_couvre) or not table.has(proprio_couvre):
		return {}
	var s := meilleure / (meilleure + w_owner)
	var vote := 0.0
	for k in 8:
		var c := int(choix[k])
		var couvre := c if (c == owner or c == other) else owner
		if couvre == other:
			vote += w[k]
	var visible := func(S: Dictionary, x: float, hh: float) -> float:
		var decalage: float = (float(S["reach"]) + float(S["fills_hollows"]) * (0.5 - hh) + float(S["irregularity"]) * (n - 0.5)) \
			* 4.0 * x * (1.0 - x)
		return _lisse(0.5 - float(S["softness"]) / 2.0, 0.5 + float(S["softness"]) / 2.0, x + decalage)
	var h_owner := float(h.get(str(owner), 0.5))
	var h_other := float(h.get(str(other), 0.5))
	var alpha: float = vote * visible.call(table[autre_couvre], s, h_owner) \
		+ (1.0 - vote) * (1.0 - visible.call(table[proprio_couvre], 1.0 - s, h_other))
	return {"owner": owner, "other": other, "s": s, "vote": vote, "alpha": alpha}


static func _reglage_lu(r: Dictionary) -> Dictionary:
	var sortie := {}
	for k in DEFAUTS_TR:
		sortie[k] = clampf(float(r.get(k, DEFAUTS_TR[k])), BORNES_TR[k][0], BORNES_TR[k][1])
	return sortie


func _transitions(f: Dictionary) -> void:
	var s := _par_sorte(f)
	var vides := 0
	var meles := 0
	var entre := 0
	var vote_partiel := 0
	var accord := 0
	for c in s.get("blend", []):
		var i: Dictionary = c["input"]
		var mien := _fondu(i["ranks"], i["f"], i["choices"], i["table"], i["h"], float(i["n"]))
		if _proche(mien, c["expected"]):
			accord += 1
		else:
			_dire(false, "le fondu réécrit depuis le texte ≠ le cas « %s » : %s contre %s" % [c["name"], mien, c["expected"]])
		if (c["expected"] as Dictionary).is_empty():
			vides += 1
		else:
			meles += 1
			var a := float(c["expected"]["alpha"])
			if a > 0.01 and a < 0.99:
				entre += 1
			var v := float(c["expected"]["vote"])
			if v > 0.01 and v < 0.99:
				vote_partiel += 1
	_dire(accord == (s.get("blend", []) as Array).size(), "le fondu réécrit depuis le texte rend tous les cas (%d)" % accord)
	_dire(vides >= 8 and meles >= 30 and entre >= 10 and vote_partiel >= 3,
		"les cas du fondu exercent rien / un mélange / un alpha entre deux / des votes partiels (%d, %d, %d, %d)"
		% [vides, meles, entre, vote_partiel])
	# Les attendus nommés, déroulés À LA MAIN (charte §6).
	_dire(_nomme(f, "blend: two layers, half and half, the middle")["expected"].get("s") == 0.5,
		"au milieu de deux moitiés, s = ½")
	var a_milieu := 1.0 - _lisse(0.275, 0.725, 0.5 + 0.2 * 4.0 * 0.25)
	_dire(absf(float(_nomme(f, "blend: two layers, half and half, the middle")["expected"].get("alpha", -1)) - a_milieu)
		< 1e-9, "au milieu, alpha = 1 − smoothstep(0,275 ; 0,725 ; 0,7), déroulé à la main (%s)" % a_milieu)
	# Au bout de la propriétaire, l'autre n'a AUCUNE part (strictement plus grande que 0) : rien ne se mêle ; à l'autre bout,
	# s = 1, le décalage 4·s·(1 − s) est nul et smoothstep(0, 1, 1) = 1 : alpha 1, quel que soit le vote.
	_dire((_nomme(f, "blend: at the owner's end, settings at their maximum: nothing shows")["expected"] as Dictionary).is_empty()
		and _nomme(f, "blend: at the other's end, settings at their maximum: fully the other")["expected"].get("alpha") == 1.0,
		"aux deux bouts, rien ne bouge, même les réglages au maximum (rien, puis 1)")
	_dire(_nomme(f, "blend: the owner is the SMALLEST rank")["expected"].get("owner") == 1, "la propriétaire est le plus petit rang")
	_dire(_nomme(f, "blend: a choice of a THIRD layer counts as no choice")["expected"].get("vote") == 0.0
		and _nomme(f, "blend: the brush: every corner chose layer 1 to cover")["expected"].get("vote") == 1.0,
		"le choix d'une troisième couche ne vote pas ; huit coins choisis votent 1")
	_dire(_nomme(f, "blend: a tie between two other layers: the first corner wins")["expected"].get("other") == 2,
		"à parts égales, le premier coin dans l'ordre k l'emporte (la couche 2, au coin 1)")
	_dire((_nomme(f, "blend: the pair is off (no direction in the table)")["expected"] as Dictionary).is_empty()
		and (_nomme(f, "blend: half a table (one direction only): nothing")["expected"] as Dictionary).is_empty(),
		"une paire éteinte, une table à moitié : rien")
	var creux_sombre := float(_nomme(f, "blend: fills hollows: a dark owner surface is covered first")["expected"]["alpha"])
	var creux_clair := float(_nomme(f, "blend: fills hollows: a bright owner surface resists")["expected"]["alpha"])
	_dire(creux_sombre > creux_clair + 0.05, "le creux : une surface sombre est couverte d'abord (%s > %s)" % [creux_sombre,
		creux_clair])
	for c in s.get("settings", []):
		_dire(_proche(_reglage_lu(c["input"]), c["expected"]), "réglage relu depuis le texte : %s" % c["name"])
	for c in s.get("table", []):
		var t := {}
		for p in c["input"]["pairs"]:
			if p["active"] and int(p["a"]) < int(f["limits"]["layers_max"]) and int(p["b"]) < int(f["limits"]["layers_max"]):
				t["%d|%d" % [p["a"], p["b"]]] = _reglage_lu(p["a_covers_b"])
				t["%d|%d" % [p["b"], p["a"]]] = _reglage_lu(p["b_covers_a"])
		_dire(_proche(t, c["expected"]), "la table relue depuis le texte : %s" % c["name"])
	var tex: Dictionary = s["cell_texture"][0]["expected"]
	# À la main (DEUX octets par case, 21 octobre 2026) : la case (1, 0, 0) de rang 1, choix 0 → [2, 1] ; (0, 0, 0) rang 0,
	# choix 1 → [1, 2] ; (-3, 2, 5) rang 14, choix 16 → [15, 17] ; (2, -1, 0) rang 15, choix 200 → [16, 201] ; (0, 1, 0)
	# rang 21, choix 255 (au-delà) → [22, 0] ; (1, 1, 0) rang 254 → [255, 0] ; (-1, 0, 0) rang 255 (au-delà) : absente.
	var octets := {}
	for b in tex["texels"]:
		octets[Vector3i(int(b[0]), int(b[1]), int(b[2])) + Vector3i(int(tex["origin"][0]), int(tex["origin"][1]),
			int(tex["origin"][2]))] = [int(b[3]), int(b[4])]
	_dire(octets.get(Vector3i(1, 0, 0)) == [2, 1] and octets.get(Vector3i(0, 0, 0)) == [1, 2]
		and octets.get(Vector3i(-3, 2, 5)) == [15, 17] and octets.get(Vector3i(2, -1, 0)) == [16, 201]
		and octets.get(Vector3i(0, 1, 0)) == [22, 0] and octets.get(Vector3i(1, 1, 0)) == [255, 0]
		and not octets.has(Vector3i(-1, 0, 0)) and octets.size() == 6 and int(f["limits"]["layers_max"]) == 255,
		"la texture des cases déroulée à la main (rang + 1 dans R, choix + 1 dans G, 16e à 255e couches présentes, 256e absente) : %s" % [octets])
	_lectures(s.get("read", []), "transitions", 10)
	_finies += 1


func _lectures(lectures: Array, quoi: String, refus_mini: int) -> void:
	var refus := 0
	var acceptes := 0
	for c in lectures:
		if c["expected"] is Dictionary and (c["expected"] as Dictionary).get("error") == true:
			refus += 1
		else:
			acceptes += 1
	_dire(acceptes >= 2 and refus >= refus_mini, "%s : la lecture accepte (%d) et refuse (%d)" % [quoi, acceptes, refus])


# ── L'ANIMATION ─────────────────────────────────────────────────────────────────────────────────────────

static func _fract(x: float) -> float:
	return x - floor(x)


func _animation(f: Dictionary) -> void:
	var s := _par_sorte(f)
	var reflets := 0
	for c in s["frame"]:
		var i: Dictionary = c["input"]
		var n := int(i["count"])
		var k := int(floor(float(i["t"]) * float(i["fps"]) + float(i["phase"]) * n))
		var image := 0
		if n > 0:
			if i["ping_pong"] and n > 1:
				var p := 2 * n - 2
				k = posmod(k, p)
				image = k if k < n else p - k
				if k >= n:
					reflets += 1
			else:
				image = posmod(k, n)
		_dire(int(c["expected"]) == image, "l'image depuis le texte : %s (%d contre %s)" % [c["name"], image, c["expected"]])
	_dire(reflets >= 2, "l'aller-retour revient vraiment (%d cas au-delà de la dernière image)" % reflets)
	for c in s["pulse"]:
		var i: Dictionary = c["input"]
		var fr := float(i["frequency"])
		var v := 1.0 if fr <= 0.0 else float(i["minimum"]) + (1.0 - float(i["minimum"])) * (0.5 + 0.5 * cos(TAU
			* (float(i["t"]) * fr + float(i["phase"]))))
		_dire(_proche(v, c["expected"], 1e-5), "la pulsation depuis le texte : %s" % c["name"])
	var ecart_32 := 0.0
	for c in s["phase"]:
		var o: Array = c["input"]["origin"]
		var p := Vector3(floor(o[0] + 0.5), floor(o[1] + 0.5), floor(o[2] + 0.5))
		p = Vector3(_fract(p.x * 0.3183099 + 0.71), _fract(p.y * 0.3183099 + 0.113), _fract(p.z * 0.3183099 + 0.419)) * 17.0
		var ph := _fract(p.x * p.y * p.z * (p.x + p.y + p.z))
		_dire(_proche(ph, c["expected"], 1e-6), "la phase depuis le texte : %s" % c["name"])
		ecart_32 = maxf(ecart_32, absf(_phase_32(Vector3(o[0], o[1], o[2])) - float(c["expected"])))
	# ⚠ MESURÉ, PAS JUGÉ : la même formule en flottants 32 bits (ce que calcule un shader) s'écarte de l'attendu double.
	print("  MESURE — la phase en 32 bits (comme un shader) s'écarte du double de %.4f au plus, sur ces origines" % ecart_32)
	for c in s["scroll"]:
		var i: Dictionary = c["input"]
		var m := float(i["t"]) + (0.0 if i["synced"] else 7.0 * float(i["phase"]))
		_dire(_proche([float(i["u"]) * m, float(i["v"]) * m], c["expected"]), "le défilement depuis le texte : %s" % c["name"])
	var vides := 0
	for c in s["read"]:
		if (c["expected"] as Dictionary).is_empty():
			vides += 1
	_dire(vides >= 3 and (s["read"] as Array).size() - vides >= 5, "la lecture de mb_animation refuse (%d) et normalise (%d)"
		% [vides, (s["read"] as Array).size() - vides])
	var bornee: Dictionary = _nomme(f, "read: out of range: clamped")["expected"]
	_dire(bornee.get("albedo", {}).get("scroll", {}).get("u") == 10.0 and bornee.get("albedo", {}).get("frames", {}).get("fps")
		== 60.0 and bornee.get("emission", {}).get("pulse", {}).get("minimum") == 0.0, "bornée : u 10, 60 ips, minimum 0")
	var typee: Dictionary = _nomme(f, "read: values of the wrong type are ignored")["expected"]
	_dire(typee.get("albedo", {}).get("scroll", {}).get("u") == 0.0 and typee.get("albedo", {}).get("scroll", {}).get("synced")
		== true and typee.get("albedo", {}).get("frames", {}).get("images") == ["animation/x.png"],
		"un mauvais type prend le défaut ; une image qui n'est pas un chemin est écartée")
	_finies += 1


## La phase en flottants 32 bits : chaque opération arrondie comme un GPU (PackedFloat32Array arrondit au plus près).
static func _f32(x: float) -> float:
	return PackedFloat32Array([x])[0]


static func _phase_32(o: Vector3) -> float:
	var p := [_f32(floor(o.x + 0.5)), _f32(floor(o.y + 0.5)), _f32(floor(o.z + 0.5))]
	var k := [0.71, 0.113, 0.419]
	for i in 3:
		var a := _f32(_f32(p[i] * _f32(0.3183099)) + _f32(k[i]))
		p[i] = _f32(_f32(a - floor(a)) * 17.0)
	var prod := _f32(_f32(_f32(p[0] * p[1]) * p[2]) * _f32(_f32(p[0] + p[1]) + p[2]))
	return _f32(prod - floor(prod))


# ── LE FEUILLAGE ────────────────────────────────────────────────────────────────────────────────────────

func _feuillage(f: Dictionary) -> void:
	var s := _par_sorte(f)
	var raisons := {}
	var modes := {}
	for c in s["check"]:
		raisons[c["expected"]] = true
		modes[c["input"]["mode"]] = true
	for c in s["brush"]:
		for r in c["expected"]["refused"]:
			raisons[r] = true
		modes[c["input"]["mode"]] = true
		_dire((c["expected"]["plants"] as Array).size() >= 3, "le pinceau plante (%s)" % c["name"])
	for r in ["", "in_matter", "too_steep", "in_water", "at_edge", "under_matter", "too_close", "already_there", "no_ground"]:
		_dire(raisons.has(r), "le feuillage exerce la raison « %s »" % r)
	_dire(modes.size() == 3, "les trois modes sont exercés (%s)" % str(modes.keys()))
	# La pose, la hauteur, le vent : réécrits depuis le texte.
	var modeles: Dictionary = f["models"]
	for c in s["place"]:
		var i: Dictionary = c["input"]
		var m: Dictionary = modeles[str(int(i["model"]))]
		var sc := float(m["scale"]) * float(i["scale"])
		var y := float(i["yaw"])
		var attendu := {"basis": [[cos(y) * sc, 0.0, -sin(y) * sc], [0.0, sc, 0.0], [sin(y) * sc, 0.0, cos(y) * sc]],
			"origin": [i["point"][0], float(i["point"][1]) + float(m["ground_offset"]) * sc, i["point"][2]],
			"height_above_ground": maxf(0.0, (float(m["height"]) + float(m["ground_offset"])) * sc)}
		_dire(_proche(attendu, c["expected"], 1e-5), "la pose depuis le texte : %s" % c["name"])
	for c in s["wind_data"]:
		var i: Dictionary = c["input"]
		var m: Dictionary = modeles[str(int(i["model"]))]
		var sc := float(m["scale"]) * float(i["scale"])
		var p: Array = i["point"]
		var attendu := [p[1], maxf(0.0, (float(m["height"]) + float(m["ground_offset"])) * sc),
			fposmod(0.37 * float(p[0]) + 0.71 * float(p[2]), TAU), m["wind"]]
		_dire(_proche(attendu, c["expected"], 1e-5), "les données du vent depuis le texte : %s" % c["name"])
	var bouge := 0
	for c in s["sway"]:
		var i: Dictionary = c["input"]
		var w: Array = i["wind"]
		var v := Vector3(i["vertex"][0], i["vertex"][1], i["vertex"][2])
		var nn := Vector3(i["normal"][0], i["normal"][1], i["normal"][2])
		var t := float(i["t"])
		var attendu := v
		if float(w[1]) > 0.0:
			var h := clampf((v.y - float(w[0])) / float(w[1]), 0.0, 1.0)
			var b := 0.35 + 0.6 * sin(1.1 * t + float(w[2])) + 0.3 * sin(2.3 * t + 1.7 * float(w[2]))
			var dir := Vector2(i["direction"][0], i["direction"][1]).normalized()
			var dxz := dir * b * float(w[3]) * float(w[1]) * 0.05 * h * h
			attendu = v + Vector3(dxz.x, 0.0, dxz.y)
			attendu += nn * sin(7.0 * t + attendu.dot(Vector3(2.1, 1.7, 2.9))) * 0.015 * float(w[3]) * h
		if not attendu.is_equal_approx(v):
			bouge += 1
		_dire(_proche([attendu.x, attendu.y, attendu.z], c["expected"], 1e-5), "le balancement depuis le texte : %s" % c["name"])
	_dire(bouge >= 4, "des sommets bougent vraiment (%d)" % bouge)
	var nuls := 0
	for c in s["ground_of_cells"]:
		if c["expected"] == null:
			nuls += 1
	_dire(nuls >= 2 and (s["ground_of_cells"] as Array).size() - nuls >= 3, "le sol des cases : trouvé et absent")
	_dire(_nomme(f, "ground_of_cells: x 10.5 z 0.5 below 2.5")["expected"] == null,
		"cherché DEPUIS L'INTÉRIEUR d'une colonne pleine, pas de sol (la mutation d'abord muette du 6 octobre)")
	_lectures(s["read"], "foliage", 8)
	_finies += 1


# ── L'EAU ───────────────────────────────────────────────────────────────────────────────────────────────

func _eau(f: Dictionary) -> void:
	var s := _par_sorte(f)
	var genres := {}
	var erreurs := {}
	var fins := {}
	var cours := {}
	for c in s["water_world"]:
		for b in c["expected"]["bodies"]:
			genres[b["kind"]] = true
			erreurs[b["error"]] = true
			fins[b["end"]] = true
			for x in b["course"]:
				cours[x[3]] = true
	for k in ["sea", "lake", "river"]:
		_dire(genres.has(k), "l'eau exerce le corps « %s »" % k)
	for k in ["in_matter", "in_water", "one_sea_only"]:
		_dire(erreurs.has(k), "l'eau exerce le refus « %s »" % k)
	for k in ["leaves", "joins", "closed"]:
		_dire(fins.has(k), "l'eau exerce la fin « %s »" % k)
	for k in ["flow", "fall", "lake"]:
		_dire(cours.has(k), "un cours exerce « %s »" % k)
	var calme: Dictionary = _nomme(f, "world: a calm lake in a crater")["expected"]["bodies"][0]
	var deborde: Dictionary = _nomme(f, "world: a crater near a fall overflows into a river")["expected"]["bodies"][0]
	_dire(calme["kind"] == "lake" and deborde["kind"] == "river" and (deborde["lakes"] as Array).size() == 1,
		"le même cratère : calme loin d'une chute, il déborde près d'elle")
	# À la main : le cratère de 3 × 3 sous la plaine, un lac de 9 cases au niveau 1.
	_dire(calme["level"] == 1 and (calme["water"] as Array).size() == 9, "le lac du cratère : 9 cases au niveau 1, compté à la main")
	var a: Dictionary = _nomme(f, "world: a river from the island top joins the sea")["expected"]
	var b: Dictionary = _nomme(f, "world: the order of the sources does not matter (the sea first anyway)")["expected"]
	_dire(a["sea"] == b["sea"] and a["bodies"][1] == b["bodies"][0], "l'ordre des sources ne change rien")
	var large: Array = _nomme(f, "river_width: 5 wide: only the rivers stay")["expected"]
	_dire(large.size() == 3 and _nomme(f, "river_width: a lake does not widen")["expected"].size() == 1
		and _proche(_nomme(f, "river_width: 2 wide (one more on the + side)")["expected"], [[0, 3, 1], [0, 3, 2]]),
		"la largeur : seules les rivières restent, un lac ne s'élargit pas, la case de plus du côté +")
	var sans_fond := false
	for c in s["surface_depth"]:
		for d in c["expected"]["depth"]:
			sans_fond = sans_fond or d[3] == -1
	_dire(sans_fond, "une profondeur sans fond (−1) est exercée")
	_lectures(s["read"], "water", 5)
	_finies += 1


# ── LE MAILLAGE DE L'EAU (7 octobre 2026 : le contrat de l'eau recalculée) ──────────────────────────────────
# Ce qui est gardé ici, en plus de la péremption (`_a_jour`) :
#   - LA FORME SE COMPARE : l'appariement en sac (sans ordre, rotations permises, réflexion refusée, tolérances) rend
#     vrai sur un maillage mélangé, tourné et bruité sous la tolérance — et faux sur un coin déplacé de 2e-4, un triangle
#     retourné, un triangle doublé à la place d'un autre, des couleurs rangées sur 8 bits ;
#   - L'ENTRÉE SUFFIT : la mer relue de son eau (sans les tronçons, ce que le greffon a) donne les mêmes triangles que la
#     mer relue de ses tronçons (ce que fait l'appli) ;
#   - LES CAS EXERCENT CE QU'ILS NOMMENT (attendus déroulés à la main sur les triangles, pas sur le code) : aucune jonction
#     en T entre plats, la hauteur des plats, la nappe sous la dalle et sous le plafond, un seul océan, la cascade en
#     volume (devant le plan, rentrée dans la roche), son remous sur la nappe, la source, la largeur de rivière ;
#   - LES SEUILS DU MAILLEUR SONT LOIN : un triangle gardé a une aire très au-dessus de celle qui le ferait jeter, et son
#     sens ne dépend pas d'un produit scalaire proche de zéro — un moteur en double ne tranche pas autrement.

const TOL_MAILLAGE := {"position": 1e-4, "normal": 1e-3, "color": 1e-4, "uv": 1e-4}


## Les triangles d'un attendu, dépliés : 36 nombres chacun.
static func _deplier(e: Dictionary) -> Array:
	var v: Array = e["vertices"]
	var sortie: Array = []
	for t in e["triangles"]:
		sortie.append((v[int(t[0])] as Array) + (v[int(t[1])] as Array) + (v[int(t[2])] as Array))
	return sortie


## Deux coins (12 nombres) égaux aux tolérances.
static func _coin_proche(a: Array, ia: int, b: Array, ib: int) -> bool:
	for k in 12:
		var tol: float = TOL_MAILLAGE["position"] if k < 3 else (TOL_MAILLAGE["normal"] if k < 6 else
			(TOL_MAILLAGE["color"] if k < 10 else TOL_MAILLAGE["uv"]))
		if absf(float(a[ia + k]) - float(b[ib + k])) > tol:
			return false
	return true


static func _cle_centre(t: Array) -> Vector3i:
	return Vector3i(roundi((float(t[0]) + float(t[12]) + float(t[24])) / 3.0 * 100.0),
		roundi((float(t[1]) + float(t[13]) + float(t[25])) / 3.0 * 100.0),
		roundi((float(t[2]) + float(t[14]) + float(t[26])) / 3.0 * 100.0))


## L'APPARIEMENT EN SAC, tel que `rules_text` le demande aux greffons : "" si égal, sinon la raison.
static func _meme_sac(attendu: Array, obtenu: Array) -> String:
	if attendu.size() != obtenu.size():
		return "%d triangles au lieu de %d" % [obtenu.size(), attendu.size()]
	var seaux := {}
	for i in obtenu.size():
		var k := _cle_centre(obtenu[i])
		if not seaux.has(k):
			seaux[k] = []
		seaux[k].append(i)
	var pris := {}
	for t: Array in attendu:
		var k0 := _cle_centre(t)
		var trouve := false
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					for i in seaux.get(k0 + Vector3i(dx, dy, dz), []):
						if trouve or pris.has(i):
							continue
						var o: Array = obtenu[i]
						for r in 3:
							if _coin_proche(t, 0, o, 12 * r) and _coin_proche(t, 12, o, 12 * ((r + 1) % 3)) \
									and _coin_proche(t, 24, o, 12 * ((r + 2) % 3)):
								trouve = true
								pris[i] = true
								break
		if not trouve:
			return "aucun triangle pour %s" % [t.slice(0, 3) + t.slice(12, 15) + t.slice(24, 27)]
	return ""


static func _genre_t(t: Array) -> float:
	return float(t[8])


static func _plat_t(t: Array) -> bool:
	return absf(float(t[4]) - 1.0) < 1e-6 and absf(float(t[1]) - float(t[13])) < 1e-6 \
		and absf(float(t[1]) - float(t[25])) < 1e-6 and (_genre_t(t) == 0.0 or _genre_t(t) == 0.5)


## Le point (x, z) est-il dans le triangle (projeté sur le plan horizontal), bord compris ?
static func _couvre_t(t: Array, p: Vector3) -> bool:
	if absf(float(t[1]) - p.y) > 1e-4:
		return false
	var a := Vector2(t[0], t[2])
	var b := Vector2(t[12], t[14])
	var c := Vector2(t[24], t[26])
	var q := Vector2(p.x, p.z)
	var d1 := (b - a).cross(q - a)
	var d2 := (c - b).cross(q - b)
	var d3 := (a - c).cross(q - c)
	return (d1 >= -1e-9 and d2 >= -1e-9 and d3 >= -1e-9) or (d1 <= 1e-9 and d2 <= 1e-9 and d3 <= 1e-9)


## AUCUNE JONCTION EN T entre les plats d'une même hauteur : aucun sommet de plat n'est STRICTEMENT à l'intérieur d'un
## côté horizontal ou vertical (en x ou en z) d'un triangle plat — compté en vingtièmes, comme le mailleur.
static func _jonctions_en_t(tris: Array) -> int:
	var sur_z := {}   # (h, z) → {x}
	var sur_x := {}   # (h, x) → {z}
	var plats: Array = tris.filter(_plat_t)
	for t: Array in plats:
		for k in 3:
			var h := roundi(float(t[12 * k + 1]) * 20.0)
			var x := roundi(float(t[12 * k]) * 20.0)
			var z := roundi(float(t[12 * k + 2]) * 20.0)
			if not sur_z.has(Vector2i(h, z)):
				sur_z[Vector2i(h, z)] = {}
			sur_z[Vector2i(h, z)][x] = true
			if not sur_x.has(Vector2i(h, x)):
				sur_x[Vector2i(h, x)] = {}
			sur_x[Vector2i(h, x)][z] = true
	var n := 0
	for t: Array in plats:
		for k in 3:
			var a: int = 12 * k
			var b: int = 12 * ((k + 1) % 3)
			var h := roundi(float(t[a + 1]) * 20.0)
			var xa := roundi(float(t[a]) * 20.0)
			var za := roundi(float(t[a + 2]) * 20.0)
			var xb := roundi(float(t[b]) * 20.0)
			var zb := roundi(float(t[b + 2]) * 20.0)
			if za == zb:
				for x in sur_z.get(Vector2i(h, za), {}):
					if x > mini(xa, xb) and x < maxi(xa, xb):
						n += 1
			elif xa == xb:
				for z in sur_x.get(Vector2i(h, xa), {}):
					if z > mini(za, zb) and z < maxi(za, zb):
						n += 1
	return n


func _maillage_de_l_eau(f: Dictionary) -> void:
	var cas := {}
	for c in f["cases"]:
		_dire(c["kind"] == "water_mesh", "maillage : une seule sorte, water_mesh (« %s »)" % c["kind"])
		cas[(c["name"] as String).trim_prefix("mesh: ")] = c
	var soupe := func(nom: String) -> Array:
		var c: Dictionary = cas.get(nom, {})
		_dire(not c.is_empty(), "maillage : le cas « %s » existe" % nom)
		return [] if c.is_empty() else _deplier(c["expected"])
	# ── la forme se compare
	var bassin: Array = soupe.call("a waterfall into a basin it fills")
	var melange: Array = []
	var graine := 7
	for t: Array in bassin:
		var r := graine % 3
		graine = (graine * 1103515245 + 12345) & 0x7FFFFFFF
		var tourne: Array = t.slice(12 * r) + t.slice(0, 12 * r)
		for k in 36:
			var amplitude := 5e-4 if k % 12 >= 3 and k % 12 < 6 else 5e-5
			tourne[k] = float(tourne[k]) + (amplitude if (k + graine) % 2 == 0 else -amplitude)
		melange.insert(graine % (melange.size() + 1), tourne)
	_dire(bassin.size() > 1000 and _meme_sac(bassin, melange) == "",
		"l'appariement : le bassin (%d triangles) mélangé, tourné, bruité sous la tolérance — le même (%s)" % [bassin.size(),
		_meme_sac(bassin, melange)])
	var deplace: Array = bassin.duplicate(true)
	deplace[500][13] = float(deplace[500][13]) + 2e-4
	_dire(_meme_sac(bassin, deplace) != "", "l'appariement : un coin déplacé de 2e-4 — différent")
	var retourne: Array = bassin.duplicate(true)
	retourne[300] = (retourne[300] as Array).slice(0, 12) + (retourne[300] as Array).slice(24, 36) + (retourne[300] as Array).slice(12, 24)
	_dire(_meme_sac(bassin, retourne) != "", "l'appariement : un triangle retourné (le sens fait partie du contrat) — différent")
	var double: Array = bassin.duplicate(true)
	double[10] = double[11]
	_dire(_meme_sac(bassin, double) != "", "l'appariement : un triangle doublé à la place d'un autre — différent")
	var huit_bits: Array = bassin.duplicate(true)
	for t: Array in huit_bits:
		for k in 3:
			for j in range(6, 10):
				t[12 * k + j] = roundf(float(t[12 * k + j]) * 255.0) / 255.0
	_dire(_meme_sac(bassin, huit_bits) != "", "l'appariement : les couleurs rangées sur 8 bits (l'ArrayMesh de Godot) — différent")
	# ── l'entrée suffit : la mer relue de son eau ou de ses tronçons
	for nom in ["a sea around an island", "the sea under a floating slab", "a sea above the whole world"]:
		var c: Dictionary = cas.get(nom, {})
		if c.is_empty():
			continue
		var occ := {}
		for v in f["worlds"][c["input"]["world"]]:
			occ[Vector3i(v[0], v[1], v[2])] = true
		var b := FL.boite(occ)
		var corps: Array = (c["input"]["bodies"] as Array).map(func(x: Dictionary) -> Dictionary: return EP.corps_depuis_en(x))
		var o := FL.ocean(occ, int(corps[0]["niveau"]), FL.VOLUME_MAXI, b)
		_dire(corps[0]["genre"] == "ocean" and o["eau"] == corps[0]["eau"], "%s : la mer du cas est celle de la règle" % nom)
		corps[0]["colonnes"] = o["colonnes"]
		var avec := EP.triangles_canoniques(EM.tableaux_du_maillage(corps, occ, b))
		_dire(_meme_sac(_deplier(c["expected"]), avec) == "",
			"%s : relue de ses tronçons (l'appli), la même nappe que relue de son eau (le greffon)" % nom)
	# ── les cas exercent ce qu'ils nomment
	var genres := {}
	var t_total := 0
	var pire_aire := INF
	var pire_sens := INF
	for nom in cas:
		var tris := _deplier(cas[nom]["expected"])
		t_total += tris.size()
		for t: Array in tris:
			genres[_genre_t(t)] = true
		_dire(_jonctions_en_t(tris) == 0, "%s : aucune jonction en T entre plats (%d)" % [nom, _jonctions_en_t(tris)])
		# Les hauteurs, par cran du sol (9 octobre 2026), écrites à la main : [nappe, bande] en fraction de case. La bande
		# ÉPAISSE (13 octobre 2026) : 0,3 au-dessus du sol dessiné — 0,05 · 0,3 · 0,55 (0,85 · 0,1 · 0,35 avant).
		var sol := float(cas[nom]["input"].get("floor", 0.25))
		var fracs: Array = {0.25: [0.7, 0.05], 0.0: [0.95, 0.3], -0.25: [0.7, 0.55]}[sol]
		var hauteurs_justes := true
		for t: Array in tris.filter(_plat_t):
			var y := float(t[1])
			var frac := y - floorf(y)
			if _genre_t(t) == 0.0:
				hauteurs_justes = hauteurs_justes and absf(frac - float(fracs[0])) < 1e-5
			else:
				hauteurs_justes = hauteurs_justes and absf(frac - float(fracs[1])) < 1e-5
		_dire(hauteurs_justes, "%s : nappes à la rangée + %s, bandes à la case + %s (sol %s)" % [nom, fracs[0], fracs[1], sol])
		# Les seuils : aire d'un triangle gardé, et le sens tranché par la normale du premier coin.
		for t: Array in tris:
			if _plat_t(t):
				continue
			var a := Vector3(t[0], t[1], t[2])
			var x := (Vector3(t[12], t[13], t[14]) - a).cross(Vector3(t[24], t[25], t[26]) - a)
			pire_aire = minf(pire_aire, x.length())
			# Le premier coin de la grille n'est plus connu (rotation canonique) : le PLUS FAVORABLE des trois est
			# le sien (le sens a été choisi pour lui) ; sa marge est le pire cas.
			var meilleur := -INF
			for k in 3:
				meilleur = maxf(meilleur, x.normalized().dot(Vector3(t[12 * k + 3], t[12 * k + 4], t[12 * k + 5])))
			pire_sens = minf(pire_sens, meilleur)
	for g in [0.0, 0.5, 0.75, 1.0]:
		_dire(genres.has(g), "maillage : le genre %s est exercé" % g)
	print("  maillage de l'eau : %d cas, %d triangles ; plus petit |AB × AC| gardé %s (jeté sous 1e-7) ; pire marge de sens %.3f"
		% [cas.size(), t_total, String.num_scientific(pire_aire), pire_sens])
	_dire(pire_aire > 1e-5, "les triangles gardés sont loin du seuil d'aire (%s > 1e-5)" % String.num_scientific(pire_aire))
	_dire(pire_sens > 0.05, "le sens d'aucun triangle ne tient à un produit scalaire proche de zéro (%.3f)" % pire_sens)
	# Un seul océan : la seconde source ne dessine rien.
	_dire(_meme_sac(soupe.call("a sea around an island"), soupe.call("one sea only: the second source draws nothing")) == "",
		"un seul océan : la mer et la source refusée dessinent la mer seule")
	# La rivière dans la couche de la mer, et seule : la même rivière, la mer en plus (96 triangles dormants).
	var avec_mer: Array = soupe.call("a river joins the sea, in the sea's layer")
	var seule: Array = soupe.call("the same river in a layer of its own")
	_dire(_meme_sac(avec_mer.filter(func(t): return _genre_t(t) != 0.0), seule) == ""
		and avec_mer.filter(func(t): return _genre_t(t) == 0.0).size() == 96,
		"la rivière qui rejoint la mer : la même, avec ou sans la mer dans sa couche (son remous sur la nappe, à 2,7 ou 2,72)")
	# Sous la dalle et sous le plafond, la nappe passe — à la main : la mer de niveau 2 en (1,5 ; 2,7 ; 1,5) ; le lac de
	# la grotte de niveau 2 en (2,5 ; 2,7 ; 2,5).
	_dire(soupe.call("the sea under a floating slab").any(func(t): return _couvre_t(t, Vector3(1.5, 2.7, 1.5))),
		"sous la dalle, à 2,7 : la nappe passe")
	_dire(soupe.call("a lake under the ceiling of a closed cave").any(func(t): return _couvre_t(t, Vector3(2.5, 2.7, 2.5))),
		"sous le plafond de la grotte, à 2,7 : la nappe du lac")
	_dire(soupe.call("a sea above the whole world").all(func(t): return absf(float(t[1]) - 6.7) < 1e-5),
		"la mer au-dessus de tout : une nappe à 6,7, partout")
	var vide: Array = soupe.call("a sea in an empty world: one plane")
	_dire(vide.size() == 2 and vide.all(func(t): return absf(absf(float(t[0])) - 2000.0) < 1e-6),
		"le monde vide : un plan, deux triangles, jusqu'à ±2000")
	_dire((soupe.call("a refused source draws nothing") as Array).is_empty(), "une source refusée : aucun triangle")
	_dire(soupe.call("a calm lake in a crater").size() == 2, "le lac du cratère : un rectangle, deux triangles (9 cases fusionnées)")
	# La cascade en volume du bassin, à la main : la falaise en x = 3 (la lèvre est la case (3, 5, 1)), la nappe sort à
	# 0,35 devant dès 0,7 de chute et s'évase, ses bouts libres rentrent à 0,4 dans la roche ; z de −0,1 à 3,1 (une case,
	# + 0,1 à chaque bout libre) ; l'écume de 0 en haut à 1 au pied ; l'anneau posé sur la nappe du bassin, à 1,7 + 0,02.
	# (La première : le bassin plein déborde ensuite et la rivière tombe encore du bord du monde, en x = 8.)
	var chute: Array = bassin.filter(func(t): return _genre_t(t) == 1.0 and float(t[0]) < 5.0)
	var xs := []
	var zs := []
	var ecumes := []
	for t: Array in chute:
		for k in 3:
			xs.append(float(t[12 * k]))
			zs.append(float(t[12 * k + 2]))
			ecumes.append(float(t[12 * k + 9]))
	_dire(not xs.is_empty() and absf(xs.min() - 2.6) < 1e-4 and xs.max() > 3.35 and xs.max() < 3.35 + 0.2 + 1e-4,
		"la cascade du bassin : rentrée à 2,6 dans la roche, sortie au-delà de 3,35 (%s .. %s)" % [xs.min(), xs.max()])
	_dire(not zs.is_empty() and absf(zs.min() - 0.9) < 1e-4 and absf(zs.max() - 2.1) < 1e-4,
		"la cascade du bassin : de z = 0,9 à 2,1 (la case 1, + 0,1 à chaque bout libre) — %s .. %s" % [zs.min(), zs.max()])
	_dire(not ecumes.is_empty() and ecumes.min() == 0.0 and ecumes.max() == 1.0, "la cascade : écume de 0 en haut à 1 au pied")
	_dire(bassin.any(func(t): return _genre_t(t) == 0.75 and absf(float(t[1]) - 1.72) < 1e-5 and absf(float(t[4]) - 1.0) < 1e-6),
		"le remous du bassin : un anneau à plat sur sa nappe, à 1,72")
	# La source de la rivière de l'escalier : elle naît en (0, 3, 1) — le bouillon bombé en (0,5 ; 3,13 ; 1,5) (la bande à
	# 3,05, + 0,08 ; 2,93 avant la bande épaisse).
	var esc: Array = soupe.call("a river down the stairs: bands, three waterfalls, a spring")
	_dire(esc.any(func(t): return (_genre_t(t) == 0.75 and absf(float(t[0]) - 0.5) < 1e-5 and absf(float(t[1]) - 3.13) < 1e-5
		and absf(float(t[2]) - 1.5) < 1e-5 and float(t[9]) == 1.0)), "la source : le bouillon bombé en (0,5 ; 3,13 ; 1,5), écume 1")
	# La rivière large de trois : trois cascades côte à côte ne font qu'une par marche — ses bouts libres seulement aux
	# deux extrémités (z de −0,1 à 3,1), donc moins de triangles que trois rivières seules.
	var large: Array = soupe.call("a river three cells wide down the stairs (river_width 3)")
	var zl := []
	for t: Array in large.filter(func(t): return _genre_t(t) == 1.0):
		for k in 3:
			zl.append(float(t[12 * k + 2]))
	_dire(not zl.is_empty() and absf(zl.min() + 0.1) < 1e-4 and absf(zl.max() - 3.1) < 1e-4
		and large.filter(func(t): return _genre_t(t) == 1.0).size() < 3 * esc.filter(func(t): return _genre_t(t) == 1.0).size(),
		"la rivière large de trois : une cascade de z = −0,1 à 3,1 par marche, raccordée au milieu")
	_deux_rivieres_au_meme_endroit(f, cas)
	_finies += 1


## DEUX RIVIÈRES AU MÊME ENDROIT (7 octobre 2026) — le cas qui manquait : « deux cascades jointes gardent la lèvre la plus
## BASSE » et « deux bandes sur une même case » ne rougissaient sur aucun des 14 premiers cas (mesuré par les trois
## greffons ET dans le cœur). Le cas doit les exercer : vérifié sur son ENTRÉE (deux lèvres de hauteurs différentes à la
## même place d'une même face ; des cases de bande communes aux deux cours) et sur ses TRIANGLES (la nappe monte à la
## plus haute lèvre ; chaque case commune n'est couverte qu'une fois par les bandes).
func _deux_rivieres_au_meme_endroit(f: Dictionary, cas: Dictionary) -> void:
	var nom := "two rivers in one place: one falls from the top, one leaves a gallery below, on the same cells"
	var c: Dictionary = cas.get(nom, {})
	_dire(not c.is_empty(), "maillage : le cas « %s » existe" % nom)
	if c.is_empty():
		return
	var occ := {}
	for v in f["worlds"][c["input"]["world"]]:
		occ[Vector3i(v[0], v[1], v[2])] = true
	var bodies: Array = c["input"]["bodies"]
	# Les lèvres (la case avant chaque suite de « fall ») et leur place sur la face (le plan, le long), d'après rules_text.
	var places := {}   # "axe|plan|le long" → [y des lèvres]
	var bandes := {}   # case de bande → nombre de cours qui la portent
	for b: Dictionary in bodies:
		var course: Array = b["course"]
		var cases_: Array = course.map(func(e: Array) -> Vector3i: return Vector3i(int(e[0]), int(e[1]), int(e[2])))
		var vues := {}
		for i in course.size():
			var ici: Vector3i = cases_[i]
			if course[i][3] != "lake" and occ.has(ici + Vector3i.DOWN) and not vues.has(ici):
				vues[ici] = true
				bandes[ici] = int(bandes.get(ici, 0)) + 1
			if course[i][3] == "fall" and i >= 2 and course[i - 1][3] != "fall":
				var levre: Vector3i = cases_[i - 1]
				var d: Vector3i = levre - cases_[i - 2]
				if d.y == 0 and absi(d.x) + absi(d.z) == 1:
					var plan: int = (levre.x if d.x != 0 else levre.z) + (1 if (d.x + d.z) < 0 else 0)
					var cle := "%s|%d|%d" % ["x" if d.x != 0 else "z", plan, levre.z if d.x != 0 else levre.x]
					if not places.has(cle):
						places[cle] = []
					places[cle].append(levre.y)
	var jointes: Array = places.values().filter(func(ys: Array) -> bool: return ys.min() != ys.max())
	_dire(bodies.size() == 2 and bodies.all(func(b): return b["kind"] == "river") and jointes.size() == 1,
		"deux rivières au même endroit : deux cascades de lèvres différentes à la même place d'une face (%s)" % [places])
	var communes: Array = bandes.keys().filter(func(k: Vector3i) -> bool: return bandes[k] > 1)
	_dire(communes.size() >= 2, "deux rivières au même endroit : des cases de bande communes aux deux cours (%s)" % [communes])
	var tris := _deplier(c["expected"])
	var ys := []
	for t: Array in tris.filter(func(t): return _genre_t(t) == 1.0):
		for k in 3:
			ys.append(float(t[12 * k + 1]))
	var plus_haute: float = (jointes[0] as Array).max() if jointes.size() == 1 else INF
	_dire(not ys.is_empty() and absf(ys.max() - (plus_haute + 0.05)) < 1e-5,
		"deux rivières au même endroit : une seule nappe, depuis la PLUS HAUTE lèvre (haut à %s, attendu %s)" % [
		ys.max() if not ys.is_empty() else null, plus_haute + 0.05])
	var une_fois := true
	for k: Vector3i in communes:
		# Un point quelconque de la case (pas sur une diagonale ni un rayon d'éventail), à la hauteur des bandes.
		var p := Vector3(k.x + 0.37, k.y + 0.05, k.z + 0.61)
		var n := tris.filter(func(t): return _genre_t(t) == 0.5 and _plat_t(t) and _couvre_t(t, p)).size()
		une_fois = une_fois and n == 1
	_dire(une_fois and not communes.is_empty(), "deux rivières au même endroit : une bande par case commune, pas deux")

# ── L'ÉDITION ───────────────────────────────────────────────────────────────────────────────────────────

func _edition(f: Dictionary) -> void:
	var s := _par_sorte(f)
	var monde := {}
	for c in f["world_cells"]:
		monde[Vector3i(c[0], c[1], c[2])] = true
	var paires := {}
	var posees := 0
	var sens_nul := 0
	var face := 0
	for c in s["extrude"]:
		paires["%s|%s" % [c["input"]["direction"], c["input"]["mode"]]] = true
		if not (c["expected"]["set"] as Array).is_empty():
			posees += 1
			_dire(c["input"]["mode"] == "place", "seul « place » pose : %s" % c["name"])
		if _proche(c["expected"]["step"], [0, 0, 0]):
			sens_nul += 1
		elif c["input"]["direction"] == "facing":
			face += 1
	_dire(paires.size() == 9 and posees >= 4 and sens_nul >= 1 and face >= 3,
		"Extrude : les 3 × 3 (sens, mode), des poses, un sens nul, « face » trouve son sens (%d, %d, %d, %d)"
		% [paires.size(), posees, sens_nul, face])
	var front: Dictionary = _nomme(f, "extrude facing, place, on the front of the wall")["expected"]
	_dire(_proche(front["step"], [0, 0, 1]), "« face » sur le devant du mur épais : vers +z, déroulé à la main (%s)" % str(front["step"]))
	for c in s["shrink_edge"]:
		var sel := {}
		for x in c["input"]["selection"]:
			sel[Vector3i(x[0], x[1], x[2])] = true
		var reste: Array = []
		for v: Vector3i in sel:
			var bord := false
			for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1),
					Vector3i(0, 0, -1)]:
				if sel.has(v - d) and not sel.has(v + d):
					bord = true
			if not bord:
				reste.append(v)
		reste.sort()
		_dire(_proche(reste.map(func(v: Vector3i) -> Array: return [v.x, v.y, v.z]), c["expected"]),
			"Shrink depuis le texte : %s" % c["name"])
	_dire((_nomme(f, "shrink_edge: a full 3x3x3 cube")["expected"] as Array).size() == 1
		and (_nomme(f, "shrink_edge: a single cell")["expected"] as Array).size() == 1
		and (_nomme(f, "shrink_edge: a flat 4x4 rectangle")["expected"] as Array).size() == 4,
		"Shrink à la main : le cube garde son cœur, une case reste, un 4 × 4 garde ses 4 du milieu")
	for c in s["widen_flat"]:
		var large := {}
		for x in c["input"]["selection"]:
			var v := Vector3i(x[0], x[1], x[2])
			for d in [Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				large[v + d] = true
		var l: Array = large.keys()
		l.sort()
		_dire(_proche(l.map(func(v: Vector3i) -> Array: return [v.x, v.y, v.z]), c["expected"]), "Widen depuis le texte : %s"
			% c["name"])
	for c in s["select_brush"]:
		var i: Dictionary = c["input"]
		var sel := {}
		for x in i["selection"]:
			sel[Vector3i(x[0], x[1], x[2])] = true
		for x in i["targets"]:
			var v := Vector3i(x[0], x[1], x[2])
			if i["deselect"]:
				sel.erase(v)
			elif i["include_empty"] or monde.has(v):
				sel[v] = true
		var l: Array = sel.keys()
		l.sort()
		_dire(_proche(l.map(func(v: Vector3i) -> Array: return [v.x, v.y, v.z]), c["expected"]),
			"le pinceau Select depuis le texte : %s" % c["name"])
	var erreurs := {}
	var reparees := 0
	var creusees := 0
	for c in s["room_from_selection"]:
		erreurs[c["expected"]["error"]] = true
		reparees += int(c["expected"]["repaired"])
		creusees += (c["expected"]["clear"] as Array).size()
	_dire(erreurs.has("") and erreurs.has("too_small") and erreurs.has("empty") and reparees > 0 and creusees > 0,
		"Room from selection : réussie, too_small, empty, une réparation, un dedans creusé (%s, %d, %d)" % [erreurs.keys(),
		reparees, creusees])
	# À la main : l'empreinte 3 × 3 montée d'un étage — une boîte 3 × 3 × 3, 26 cases de coque, le cœur vide.
	var salle: Dictionary = _nomme(f, "room_from_selection: a 3x3 footprint, rising 1 floor")["expected"]
	_dire((salle["set"] as Array).size() == 26 and _proche(salle["box"], [[0, 0, 0], [2, 2, 2]]),
		"la salle 3 × 3 d'un étage : 26 cases de coque, boîte [0..2]³ (compté à la main)")
	_finies += 1


# ── 4. L'EXPORT ─────────────────────────────────────────────────────────────────────────────────────────

func _l_export_du_monde() -> void:
	var dest := _dossier.path_join("monde")
	DirAccess.make_dir_recursive_absolute(dest)
	# Un modèle de feuillage : un .glb écrit ici (une boîte).
	var glb := dest.path_join("arbre.glb")
	var racine := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.name = "tronc"
	mi.mesh = BoxMesh.new()
	racine.add_child(mi)
	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	doc.append_from_scene(racine, etat)
	doc.write_to_filesystem(etat, glb)
	racine.free()
	var couches := [{"nom": "Rock", "visible": true, "source": "", "lot": null, "cases": [Vector3i(0, 0, 0)]},
		{"nom": "Sand", "visible": true, "source": "", "lot": null, "cases": [Vector3i(1, 0, 0)]},
		{"nom": "Snow", "visible": false, "source": "", "lot": null, "cases": [Vector3i(2, 0, 0)]}]
	# L'état de l'atelier tient des IDS (ici 7, 3, 12 dans l'ordre des couches) : la paire « 3|7 » relie les couches 1 et 0,
	# donc SES DEUX DIRECTIONS S'ÉCHANGENT en indices ; « 3|99 » nomme une couche qui n'existe plus.
	var r_sable := TR.reglages({"largeur": 0.3})
	var r_roc := TR.reglages({"largeur": 0.9, "avance": -0.4})
	var etat_tr := {"paires": {"3|7": {"actif": true, "couvre": {"3": r_sable, "7": r_roc}},
		"3|99": {"actif": true, "couvre": {}}},
		"choix": {Vector3i(1, 0, 0): "3", Vector3i(0, 0, 0): "7", Vector3i(5, 5, 5): "99"}}
	var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.6, 0.2))
	img.set_pixel(1, 2, Color(0.1, 0.2, 0.3))
	var reps := [{"image": null, "couleur": Color(0.5, 0.5, 0.5), "echelle": 2.0, "rugosite": 0.9},
		{"image": img, "couleur": Color.WHITE, "echelle": 0.0, "rugosite": 0.7}, {}]
	var feuillage := FE.vers_donnees([FE.modele(4, "Oak", glb), FE.modele(5, "Lost", dest.path_join("absent.glb"))],
		[FE.plant(1, 4, Vector3(0.5, 1.0, 0.5), 0.25, 1.1, "sol"), FE.plant(2, 5, Vector3(3.0, 6.0, 2.0), 0.0, 1.0, "air")])
	var r := FM.exporter(couches, dest, "parite", "test", [], {"etat": etat_tr, "ids": ["7", "3", "12"],
		"representants": reps}, feuillage)
	_dire(not r.has("erreur"), "le monde s'exporte (%s)" % str(r.get("erreur", "")))
	var cible := dest.path_join("parite.mbworld")
	var monde: Variant = JSON.parse_string(FileAccess.get_file_as_string(cible.path_join("world.json")))
	_dire(monde is Dictionary and monde.get("version") == 1.0, "world.json se relit, toujours en version 1")
	if not monde is Dictionary:
		_finies += 1
		return
	var t: Dictionary = monde.get("transitions", {})
	var p: Array = t.get("pairs", [])
	_dire(p.size() == 1 and p[0]["a"] == 0.0 and p[0]["b"] == 1.0 and p[0]["active"] == true,
		"une paire, en INDICES (0, 1) — la paire d'une couche disparue est laissée (%s)" % str(p))
	if p.size() == 1:
		_dire(is_equal_approx(float(p[0]["a_covers_b"]["softness"]), 0.9) and is_equal_approx(float(
			p[0]["a_covers_b"]["reach"]), -0.4) and is_equal_approx(float(p[0]["b_covers_a"]["softness"]), 0.3),
			"les directions suivent les couches : Rock (id 7, indice 0) couvre Sand avec SES réglages")
	_dire(t.get("choices") == [0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0],
		"les choix en indices, triés par sommet, celui d'une couche disparue laissé (%s)" % str(t.get("choices")))
	var rp: Array = t.get("representatives", [])
	_dire(rp.size() == 3 and rp[0]["image"] == null and rp[1]["image"] == "transitions/representative_1.png"
		and rp[1]["scale"] == 0.01 and rp[2]["image"] == null, "un représentant par couche, l'échelle au moins 0,01")
	var relue := Image.load_from_file(cible.path_join("transitions/representative_1.png"))
	if relue != null:
		relue.convert(Image.FORMAT_RGBA8)
	_dire(relue != null and relue.get_data() == img.get_data(), "l'image du représentant voyage, octet pour octet")
	var fo: Dictionary = monde.get("foliage", {})
	var ms: Array = fo.get("models", [])
	_dire(ms.size() == 2 and ms[0]["mesh"] == "foliage/arbre.glb" and ms[1]["mesh"] == null
		and r.get("feuillage", {}).get("sans_maillage") == ["Lost"], "le modèle trouvé est copié, l'introuvable part sans maillage et c'est dit")
	_dire(FileAccess.get_file_as_bytes(cible.path_join("foliage/arbre.glb")) == FileAccess.get_file_as_bytes(glb),
		"le .glb du modèle est dans le monde, octet pour octet")
	_dire(fo.get("plants") == [4.0, 0.5, 1.0, 0.5, 0.25, 1.1, 1.0, 5.0, 3.0, 6.0, 2.0, 0.0, 1.0, 0.0],
		"les plants : 7 nombres chacun, mode 1 planté, 0 en l'air (%s)" % str(fo.get("plants")))
	_dire(not FM.lire_transitions(monde).has("error") and not FM.lire_feuillage(monde).has("error")
		and not FM.lire(monde).has("error"), "le monde exporté se relit par les trois lectures de référence")
	var readme := FileAccess.get_file_as_string(cible.path_join("README.txt"))
	_dire(readme.contains("THE BLEND at a point") and readme.contains("WIND (each engine") and readme.contains("Only ONE sea"),
		"le README porte les règles des transitions, du feuillage et de l'eau")
	# Un monde sans transitions ni feuillage : les clés sont ABSENTES, et la lecture le dit vide (un monde d'avant).
	var r2 := FM.exporter(couches, dest, "nu", "test")
	var nu: Variant = JSON.parse_string(FileAccess.get_file_as_string(dest.path_join("nu.mbworld/world.json")))
	_dire(not r2.has("erreur") and nu is Dictionary and not nu.has("transitions") and not nu.has("foliage")
		and FM.lire_transitions(nu)["transitions"]["pairs"] == [] and FM.lire_feuillage(nu)["foliage"]["plants"] == [],
		"sans elles, les clés sont absentes et se lisent vides (un monde d'avant reste lisible)")
	_finies += 1


## Les images des textures animées dans le .mbset : deux matériaux, deux dossiers, un nom de fichier en commun.
func _l_export_des_images() -> void:
	var dest := _dossier.path_join("images")
	var images_a: Array = []
	var images_b: Array = []
	var couleurs := [Color.RED, Color.GREEN, Color.BLUE]
	for k in 3:
		for d in ["a", "b"]:
			DirAccess.make_dir_recursive_absolute(dest.path_join(d))
			var img := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
			img.fill(couleurs[k] if d == "a" else couleurs[k].darkened(0.5))
			var chemin := dest.path_join(d).path_join("frame_%d.png" % k)
			img.save_png(chemin)
			(images_a if d == "a" else images_b).append(chemin)
	var lot := MeshLibrary.new()
	var cles: Array = MB.pieces_a_sculpter().slice(0, 2)
	for i in 2:
		var m := StandardMaterial3D.new()
		m.resource_name = "screen" if i == 0 else "glow"
		var a := Anim.ajouter({}, "albedo" if i == 0 else "emission", "images", {"images": images_a if i == 0 else images_b})
		m.set_meta("extras", {"mb_animation": a})
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().get_mesh_arrays())
		mesh.surface_set_material(0, m)
		lot.create_item(i)
		lot.set_item_name(i, cles[i])
		lot.set_item_mesh(i, mesh)
	var r := FN.exporter(lot, dest, "anime", "test")
	_dire(not r.has("erreur") and int(r.get("images", 0)) == 6 and (r.get("images_manquantes", ["?"]) as Array).is_empty(),
		"le .mbset s'écrit avec ses six images (%s)" % str(r))
	var js := _json_du_glb(dest.path_join("anime.mbset/tiles.glb"))
	var par_nom := {}
	for x in js.get("materials", []):
		par_nom[str(x.get("name", ""))] = (x.get("extras", {}) as Dictionary).get("mb_animation", {})
	var ecran: Array = par_nom.get("screen", {}).get("albedo", {}).get("frames", {}).get("images", [])
	var lueur: Array = par_nom.get("glow", {}).get("emission", {}).get("frames", {}).get("images", [])
	_dire(ecran == ["animation/frame_0.png", "animation/frame_1.png", "animation/frame_2.png"], "l'écran : ses trois images (%s)"
		% str(ecran))
	_dire(lueur.size() == 3 and not lueur.has("animation/frame_0.png") and lueur[0] == "animation/frame_0_2.png",
		"la lueur : les mêmes noms venus d'un autre dossier ne s'écrasent pas (« _2 ») : %s" % str(lueur))
	var justes := 0
	for k in 3:
		for e in [[ecran, images_a], [lueur, images_b]]:
			if (e[0] as Array).size() == 3:
				var lu := Image.load_from_file(dest.path_join("anime.mbset").path_join(e[0][k]))
				var original := Image.load_from_file(e[1][k])
				if lu != null and original != null and lu.get_data() == original.get_data():
					justes += 1
	_dire(justes == 6, "chaque image est la BONNE, dans l'ordre, pixel pour pixel (%d sur 6)" % justes)
	_dire(Anim.depuis_format(par_nom.get("screen", {})).get("albedo", {}).get("images", {}).get("ips") == 12.0,
		"relu par la lecture de référence (12 ips par défaut)")
	_dire(FileAccess.get_file_as_string(dest.path_join("anime.mbset/README.txt")).contains("ANIMATED TEXTURES"),
		"le README du .mbset porte la règle de l'animation")
	_finies += 1


static func _vider(dossier: String) -> void:
	if not DirAccess.dir_exists_absolute(dossier):
		return
	for d in DirAccess.get_directories_at(dossier):
		_vider(dossier.path_join(d))
		DirAccess.remove_absolute(dossier.path_join(d))
	for f in DirAccess.get_files_at(dossier):
		DirAccess.remove_absolute(dossier.path_join(f))


func _json_du_glb(chemin: String) -> Dictionary:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return {}
	f.seek(12)
	var longueur := f.get_32()
	f.get_32()
	var lu: Variant = JSON.parse_string(f.get_buffer(longueur).get_string_from_utf8())
	return lu if lu is Dictionary else {}
