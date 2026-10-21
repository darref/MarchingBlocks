extends SceneTree
##
## TEST — les préformes de l'atelier Preshape (`app/preshapes/`, la 1.1.0 : Jordan, 21 octobre 2026).
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_preshapes.gd
##
## ⚠ CE QUI EST GARDÉ, C'EST CE QUE L'ARTISTE VERRAIT CASSÉ : une forme vide ou gigantesque, des cubes rouges (contacts
## par une arête), une forme différente pour la même graine, un pack qui règle un facteur qui n'existe pas (une faute de
## frappe : le pack ne ferait rien), deux matières sur un même plat d'un relief, une arche comblée par l'ancrage, un
## fantôme trop lent pour suivre le curseur. Les contrôles relisent les CASES rendues.

const C := preload("res://app/preshapes/catalogue.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")

## LE FANTÔME (la forme sans réparation, puis sa coquille : ce que l'atelier recalcule à chaque cran de curseur) à ses
## réglages par défaut et dans ses packs ; la POSE (avec la réparation des contacts) ; et le pire cas, aux maxima de
## tous ses facteurs, que l'atelier doit encore tenir. Mesuré en headless, éditeur de débogage : l'exe est plus rapide.
const BUDGET_MS := 400
const BUDGET_POSE_MS := 1500
const BUDGET_MAXI_MS := 4000

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== TEST — les préformes ===\n")
	_le_catalogue()
	_les_formes()
	_le_controle_rougit()
	_l_ancrage()
	_le_quart_de_tour()
	_les_valeurs()
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


func _vrai(v: bool, quoi: String) -> void:
	if v:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ " + quoi)


func _le_catalogue() -> void:
	print("— le catalogue")
	var ids := {}
	for f in C.formes():
		_vrai(not ids.has(f.id), "%s : id unique" % f.id)
		ids[f.id] = true
		_vrai(f.nom != "" and f.aide != "", "%s : un nom et une aide" % f.id)
		_vrai(f.famille in C.FAMILLES, "%s : une famille connue (%s)" % [f.id, f.famille])
		var cles := {}
		for d in f.facteurs():
			_vrai(not cles.has(d["cle"]), "%s.%s : facteur unique" % [f.id, d["cle"]])
			cles[d["cle"]] = true
			_vrai(str(d.get("aide", "")) != "", "%s.%s : une aide" % [f.id, d["cle"]])
			if not d.has("choix") and not d.get("bool", false):
				_vrai(float(d["mini"]) <= float(d["defaut"]) and float(d["defaut"]) <= float(d["maxi"]),
					"%s.%s : le défaut est dans les bornes" % [f.id, d["cle"]])
		_vrai(not f.packs().is_empty(), "%s : au moins un pack" % f.id)
		for p in f.packs():
			for k in p[1]:
				_vrai(cles.has(k), "%s, pack « %s » : le facteur « %s » existe" % [f.id, p[0], k])
	for fam in C.FAMILLES:
		_vrai(not C.de_la_famille(fam).is_empty(), "la famille %s a des formes" % fam)
	print("  %d formes, %d familles" % [C.formes().size(), C.FAMILLES.size()])


## Chaque forme, à ses défauts, dans chacun de ses packs, et à ses maxima.
func _les_formes() -> void:
	print("— chaque forme, ses packs, ses maxima")
	var pire := ["", 0]
	for f in C.formes():
		var essais: Array = [["défaut", {}]]
		for p in f.packs():
			essais.append(["pack « %s »" % p[0], p[1]])
		var maxi := {}
		for d in f.facteurs():
			if d.has("choix"):
				maxi[d["cle"]] = (d["choix"] as Array).size() - 1
			elif d.get("bool", false):
				maxi[d["cle"]] = true
			else:
				maxi[d["cle"]] = d["maxi"]
		essais.append(["maxima", maxi])
		for e in essais:
			var quoi := "%s (%s)" % [f.id, e[0]]
			var t0 := Time.get_ticks_msec()
			var fantome := C.construire(f.id, e[1], 7, 0, 0, false)
			C.coquille(C.pleines(fantome))
			var ms_f := Time.get_ticks_msec() - t0
			t0 = Time.get_ticks_msec()
			var r := C.construire(f.id, e[1], 7)
			var ms := Time.get_ticks_msec() - t0
			var maxima: bool = e[0] == "maxima"
			_vrai(ms_f <= (BUDGET_MAXI_MS if maxima else BUDGET_MS), "%s : le fantôme en %d ms" % [quoi, ms_f])
			_vrai(ms <= (BUDGET_MAXI_MS if maxima else BUDGET_POSE_MS), "%s : la pose en %d ms" % [quoi, ms])
			if ms_f > int(pire[1]) and not maxima:
				pire = [quoi, ms_f]
			_vrai(int(r["compte"]) > 0 or not (r["creuser"] as Dictionary).is_empty(), "%s : pas vide" % quoi)
			_vrai(int(r["compte"]) < C.CASES_MAXI, "%s : %d cases (< %d)" % [quoi, r["compte"], C.CASES_MAXI])
			for role in r["cases"]:
				_vrai(role in C.ROLES, "%s : rôle connu (%s)" % [quoi, role])
			var t := C.pleines(r)
			var contacts: int = MB.contacts_par_arete(t)
			_vrai(contacts == 0, "%s : aucun contact par une arête après réparation (%d)" % [quoi, contacts])
			if f.famille == "reliefs":
				var plats := _deux_matieres_sur_un_plat(r)
				_vrai(plats == 0, "%s : jamais deux matières sur un même plat (%d paires)" % [quoi, plats])
			var r2 := C.construire(f.id, e[1], 7)
			_vrai(_empreinte(r2) == _empreinte(r), "%s : la même graine refait la même forme" % quoi)
			_vrai(C.vignette(r, 32).get_used_rect().size.x > 0 or int(r["compte"]) == 0, "%s : une vignette" % quoi)
	print("  le fantôme le plus lent (hors maxima) : %s, %d ms" % pire)


## ⚠ UN CONTRÔLE QU'ON N'A PAS VU ROUGIR NE GARDE RIEN : deux cases qui se touchent par une arête comptent, et la
## réparation du catalogue les défait.
func _le_controle_rougit() -> void:
	print("— le contrôle des contacts rougit")
	var r := {"cases": {"pierre": {Vector3i(0, 0, 0): true, Vector3i(1, 1, 0): true}}, "creuser": {}}
	_vrai(MB.contacts_par_arete(C.pleines(r)) > 0, "un damier compte comme contact")
	var n := C.reparer_les_diagonales(r)
	_vrai(n > 0 and MB.contacts_par_arete(C.pleines(r)) == 0, "la réparation le comble (%d case(s))" % n)
	var plat := {"cases": {"sol": {Vector3i(0, 0, 0): true}, "roche": {Vector3i(1, 0, 0): true}}, "creuser": {}}
	_vrai(_deux_matieres_sur_un_plat(plat) == 1, "deux matières côte à côte sur un plat comptent")


## L'ANCRAGE : sous les colonnes de la base, jusqu'au sol du monde ; jamais sous une arche ni une île flottante.
func _l_ancrage() -> void:
	print("— l'ancrage au sol")
	var sol_bas := func(c: Vector3i) -> bool: return c.y < -4   # le monde : plein sous y = −4
	var r := C.construire("collines", {}, 1)
	var fo := C.fondations(r, Vector3i.ZERO, sol_bas)
	_vrai(not fo.is_empty(), "la colline descend jusqu'au sol (%d cases)" % fo.size())
	var bas_ok := true
	for c in fo:
		if c.y < -4 or c.y > -1:
			bas_ok = false
	_vrai(bas_ok, "les fondations restent entre le sol et la forme")
	var arche := C.construire("arche", {"pieds": 0}, 1)
	var fa := C.fondations(arche, Vector3i.ZERO, sol_bas)
	var sous_l_arche := 0
	for c in fa:
		if absi(c.x) <= 2:
			sous_l_arche += 1
	_vrai(sous_l_arche == 0, "rien sous la voûte de l'arche (%d cases)" % sous_l_arche)
	var ile := C.construire("ile_flottante", {"satellites": 0}, 1)
	_vrai(C.fondations(ile, Vector3i.ZERO, sol_bas).is_empty(), "l'île flottante n'est pas ancrée")
	var sol_haut := func(c: Vector3i) -> bool: return c.y < 0
	_vrai(C.fondations(r, Vector3i.ZERO, sol_haut).is_empty(), "posée sur un sol plat : aucune fondation")


func _le_quart_de_tour() -> void:
	print("— le quart de tour")
	var a := C.construire("maison", {}, 3, 0)
	var b := C.construire("maison", {}, 3, 1)
	_vrai(int(a["compte"]) == int(b["compte"]), "même nombre de cases après un quart de tour")
	var ta := C.pleines(a)
	var tb := C.pleines(b)
	var tous := true
	for c in ta:
		if not tb.has(C.tourner(c, 1)):
			tous = false
			break
	_vrai(tous, "chaque case tournée est là")
	var e := C.construire("maison", {}, 3, 0, 2)
	_vrai((e["boite"] as AABB).position.y == (a["boite"] as AABB).position.y - 2, "l'enfoncement descend la forme")


func _les_valeurs() -> void:
	print("— les valeurs ramenées à leurs bornes")
	var f := C.forme("montagne")
	var v := C.valeurs(f, {"hauteur": 9999, "pics": -5, "inconnu": 3, "erosion": "abc"})
	_vrai(int(v["hauteur"]) == 64 and int(v["pics"]) == 1, "au-delà des bornes : ramené")
	_vrai(not v.has("inconnu"), "un facteur inconnu est ignoré")
	_vrai(is_equal_approx(float(v["erosion"]), 0.35), "une valeur illisible prend le défaut")


## Les paires de colonnes voisines dont le dessus est à la même hauteur et d'une matière différente.
static func _deux_matieres_sur_un_plat(r: Dictionary) -> int:
	var haut := {}
	for role in r["cases"]:
		for c in r["cases"][role]:
			var k := Vector2i(c.x, c.z)
			if not haut.has(k) or c.y > int(haut[k][0]):
				haut[k] = [c.y, role]
	var n := 0
	for k in haut:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var o: Variant = haut.get(k + d)
			if o != null and int(o[0]) == int(haut[k][0]) and o[1] != haut[k][1]:
				n += 1
	return n


static func _empreinte(r: Dictionary) -> int:
	var cles: Array = []
	for role in r["cases"]:
		for c in r["cases"][role]:
			cles.append("%s%s" % [role, c])
	for c in r["creuser"]:
		cles.append("-%s" % c)
	cles.sort()
	return hash(cles)
