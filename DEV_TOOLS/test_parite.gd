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
	_edition(lus["editing"])
	_l_export_du_monde()
	_l_export_des_images()
	_dire(_finies == 8, "SENTINELLE : les huit sections sont allées jusqu'au bout (%d)" % _finies)
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
			if p["active"] and int(p["a"]) < 15 and int(p["b"]) < 15:
				t["%d|%d" % [p["a"], p["b"]]] = _reglage_lu(p["a_covers_b"])
				t["%d|%d" % [p["b"], p["a"]]] = _reglage_lu(p["b_covers_a"])
		_dire(_proche(t, c["expected"]), "la table relue depuis le texte : %s" % c["name"])
	var tex: Dictionary = s["cell_texture"][0]["expected"]
	# À la main : la case (1, 0, 0) de rang 1, choix 0 → 0x12 ; (0, 0, 0) rang 0, choix 1 → 0x21 ; la couche 15 : 0.
	var octets := {}
	for b in tex["bytes"]:
		octets[Vector3i(int(b[0]), int(b[1]), int(b[2])) + Vector3i(int(tex["origin"][0]), int(tex["origin"][1]),
			int(tex["origin"][2]))] = int(b[3])
	_dire(octets.get(Vector3i(1, 0, 0)) == 0x12 and octets.get(Vector3i(0, 0, 0)) == 0x21 and octets.get(Vector3i(-3, 2, 5))
		== 15 and not octets.has(Vector3i(2, -1, 0)) and octets.size() == 3,
		"la texture des cases déroulée à la main (rang + 1 en bas, choix + 1 en haut, la 16e couche absente)")
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
		# ⚠ EN `float` (double), JAMAIS DANS UN `Vector3` (32 bits) : c'est ainsi que l'arrondi caché de `phase_de` a passé
		# cette garde (trouvé par le banc C++ d'Unreal, 7 octobre 2026).
		var ajout := [0.71, 0.113, 0.419]
		var q: Array = []
		for k in 3:
			q.append(_fract(floorf(float(o[k]) + 0.5) * 0.3183099 + float(ajout[k])) * 17.0)
		var ph := _fract(float(q[0]) * float(q[1]) * float(q[2]) * (float(q[0]) + float(q[1]) + float(q[2])))
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
