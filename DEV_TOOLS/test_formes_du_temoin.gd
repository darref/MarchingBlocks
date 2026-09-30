extends SceneTree
## LES FORMES DU TÉMOIN — la table qui bâtit le témoin ET nourrit la légende de l'atelier Witness.
##
## ⚠ Les attendus viennent d'AILLEURS que la fonction éprouvée (charte §6) : les cases du finisseur sont
## celles qu'imprime `planete_paysage.gd` (la réparation, l'atome du finisseur posé en (5,4,5), puis les
## deux atomes des raccords en (1,4,5) et (6,8,3)), recopiées de sa sortie ; les centres et les comptes sont calculés à la main.

const FT := preload("res://addons/marchingblocks_core/formes_du_temoin.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const LegendeFormes := preload("res://app/legende_formes.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== LES FORMES DU TÉMOIN ===\n")

	# ── 1. La table EST le témoin, à la réparation et au finisseur près ────────────────────────────────
	# Sortie de `planete_paysage.gd` : réparation en (3,6,7), (6,7,2), (5,7,4) ; puis « un L, une case sur
	# le COIN » en (5,4,5) — le L (0,0,0) (1,0,0) (0,0,1) et la case (0,1,0) ; puis LES RACCORDS (30
	# septembre 2026) : « un L, une case sur l'AUTRE BOUT » en (1,4,5) — le L et la case (0,1,1) —, et
	# « une case seule » en (6,8,3).
	var attendu := [Vector3i(3, 6, 7), Vector3i(6, 7, 2), Vector3i(5, 7, 4),
		Vector3i(5, 4, 5), Vector3i(6, 4, 5), Vector3i(5, 4, 6), Vector3i(5, 5, 5),
		Vector3i(1, 4, 5), Vector3i(2, 4, 5), Vector3i(1, 4, 6), Vector3i(1, 5, 6), Vector3i(6, 8, 3)]
	attendu.sort()
	_egal(FT.cases_du_finisseur(), attendu,
		"le témoin livré = les formes + les 12 cases de la réparation, du finisseur et des raccords, rien d'autre")
	var temoin: Dictionary = BM.cases(0)
	var rebati: Dictionary = FT.batir()
	for c in attendu:
		rebati[c] = true
	_egal(rebati.size(), temoin.size(), "les formes rebâtissent les 825 cases du témoin")
	_egal(temoin.size(), 825, "le témoin a 825 cases (charte §2)")

	# ── 2. La légende ────────────────────────────────────────────────────────────────────────────────
	var l: Array = FT.legende()
	_egal(l.size(), 23, "22 formes et la carte du finisseur")
	_egal(String(l[-1]["id"]), "finisseur", "le finisseur ferme la légende")
	var ids := {}
	var toutes := {}
	for carte in l:
		ids[carte["id"]] = true
		_vrai(not (carte["cases"] as Array).is_empty(), "%s : une zone à montrer" % carte["nom"])
		_vrai(not (carte["cles"] as Array).is_empty(), "%s : des tuiles tranchées là" % carte["nom"])
		_vrai(String(carte["monde"]).length() > 20, "%s : ce qu'elle devient dans le monde" % carte["nom"])
		_vrai(_ascii(String(carte["nom"]) + String(carte["monde"])),
			"%s : nom et texte en anglais, sans accent (charte §7)" % carte["nom"])
		for k in carte["cles"]:
			toutes[k] = true
	_egal(ids.size(), l.size(), "aucun identifiant de carte en double")
	# 35 d'intérieur + 17 d'air libre (charte §2) : toute tuile du monde vient d'un endroit que la légende montre.
	_egal(toutes.size(), 52, "l'union des cartes rend les 52 tuiles du monde")
	var arche: Dictionary = l.filter(func(c): return c["id"] == "arche")[0]
	_egal((arche["cases"] as Array).size(), 26, "l'arche : deux piles de 10 cases et un tablier de 6")
	# Centre calculé à la main : x = (6·10 + 8·10 + (6+7+8)·2) / 26 = 7 ; y = (4·20 + 7·6) / 26 ; z = 3,5.
	var c_arche: Vector3 = LegendeFormes.centre_de(arche["cases"])
	_vrai(c_arche.is_equal_approx(Vector3(7.5, 122.0 / 26.0 + 0.5, 4.0)), "le centre de l'arche, à la main")
	var plateau: Dictionary = l[0]
	_vrai(not (plateau["cases"] as Array).has(Vector3i(3, 4, 5)),
		"la zone du plateau ne prend pas la salle, qui est DANS le massif")

	# ── 3. L'angle de la photo, et l'écorché ─────────────────────────────────────────────────────────
	var salle: Dictionary = l.filter(func(c): return c["id"] == "salle")[0]
	var centre: Vector3 = LegendeFormes.centre_de(salle["cases"])
	var d: float = LegendeFormes.rayon_de(salle["cases"], centre) * 2.2 + 4.5
	var angle: Vector2 = LegendeFormes.angle_de_vue(salle["cases"])
	var choisi: int = LegendeFormes.cases_cachees(salle["cases"], centre, LegendeFormes.direction_de(angle), d)
	var defaut: int = LegendeFormes.cases_cachees(salle["cases"], centre,
		LegendeFormes.direction_de(Vector2(0.7, 0.55)), d)
	_vrai(choisi <= defaut, "la salle : l'angle choisi cache moins de cases que l'angle par défaut (%d ≤ %d)"
		% [choisi, defaut])
	_vrai(LegendeFormes.a_ecorcher(salle["cases"], angle),
		"la salle est ENFERMÉE dans le massif : sa photo est un écorché")
	var pilier: Dictionary = l.filter(func(c): return c["id"] == "pilier")[0]
	_vrai(LegendeFormes.a_ecorcher(pilier["cases"], LegendeFormes.angle_de_vue(pilier["cases"])),
		"le pilier de salle aussi")
	_vrai(not LegendeFormes.a_ecorcher(arche["cases"], LegendeFormes.angle_de_vue(arche["cases"])),
		"l'arche se voit sans rien couper")
	var aiguille: Dictionary = l.filter(func(c): return c["id"] == "aiguille")[0]
	_egal(LegendeFormes.cases_cachees(aiguille["cases"], LegendeFormes.centre_de(aiguille["cases"]),
		Vector3.UP, 8.0), 0, "l'aiguille vue d'en haut : rien ne la cache")

	# ── 4. Le sens inverse : de quelle forme vient un sommet ─────────────────────────────────────────
	# Le sommet (6, 2, 3) lit les cases x 6..7, y 2..3, z 3..4 : le pied ouest de l'arche (x = 6) ET le
	# fond du canyon (x 6..8, y 2..3). L'arche (26 cases) est plus petite que le canyon (72) : nommée d'abord.
	var ids_pied: Array = FT.cartes_du_sommet(l, Vector3i(6, 2, 3)).map(func(c): return c["id"])
	_egal(ids_pied, ["arche", "canyon"], "le pied de l'arche : l'arche d'abord, puis le canyon")
	_egal(FT.cartes_du_sommet(l, Vector3i(-5, -5, -5)), [], "hors du témoin : aucune forme")
	# CHAQUE SOMMET RÉCOLTÉ a sa carte : sinon World dirait d'une tuile « aucune forme » (vu à l'image :
	# 16 sommets du massif de l'est étaient orphelins). Les sommets récoltés viennent du MODÈLE.
	var t_pleines: Dictionary = BM.cases(0)
	var t_plafond: int = FT.MB.plafond_de(t_pleines)
	var recoltes := 0
	var orphelins: Array = []
	for x in BM.COTE - 1:
		for y in BM.COTE - 1:
			for z in BM.COTE - 1:
				var s := Vector3i(x, y, z)
				if Tranchage.cle_du_sommet(t_pleines, s, t_plafond).is_empty():
					continue
				recoltes += 1
				if FT.cartes_du_sommet(l, s).is_empty():
					orphelins.append(s)
	_egal(recoltes, 549, "549 sommets récoltés (charte §3)")
	_egal(orphelins, [], "chacun appartient à au moins une carte")

	# ── 5. La provenance, portée par le lot ────────────────────────────────────────────────────────────
	# PAR LE NOM. ⚠ Une tuile par clé (charte §3, 30 septembre 2026) : un nom, un sommet.
	var MB := FT.MB
	var cle := ""
	for c in MB.classes():
		if MB.porte_une_surface(c["bits"]) and MB.sans_contact_diagonal(c["bits"]):
			cle = c["nom"]
			break
	var plein := ArrayMesh.new()
	var tri: Array = []
	tri.resize(Mesh.ARRAY_MAX)
	tri[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	plein.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tri)
	var a := Vector3i(1, 1, 1)
	var monte: Dictionary = BM._assembler({cle: plein}, {cle: {"mesh": plein, "sommet": a}})
	var faux_lot: MeshLibrary = monte["lot"]
	_egal(FT.sommet_source(faux_lot, cle), a, "la tuile porte le sommet d'où elle vient")
	_egal(faux_lot.get_item_list().size(), 1, "une clé, un item")
	_egal(FT.sommet_source(load("res://addons/marchingblocks_core/repli_procedural.gd").librairie(), cle), null,
		"le repli procédural ne vient d'aucun témoin")
	# Sur le VRAI lot : chaque tuile vient d'un sommet qui, dans le témoin, porte SA clé. L'attendu vient du
	# modèle (`Tranchage.cle_du_sommet`), pas de la méta qu'on éprouve.
	var vrai: MeshLibrary = BM.librairie()["lot"]
	var pleines: Dictionary = BM.cases(0)
	var plafond: int = MB.plafond_de(pleines)
	var justes := 0
	var items: Array = vrai.get_item_list()
	var vus := {}
	for item in items:
		var nom: String = vrai.get_item_name(item)
		var s: Variant = FT.sommet_source(vrai, nom)
		if s == null:
			continue
		vus[s] = true
		if Tranchage.cle_du_sommet(pleines, s, plafond).get("cle", "") == nom:
			justes += 1
	_egal(items.size(), 52, "le lot du témoin : 52 tuiles, une par clé")
	_egal(justes, 52, "les 52 viennent chacune d'un sommet qui porte leur clé")
	_egal(vus.size(), 52, "et de 52 sommets DIFFÉRENTS")

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("OK" if _echecs == 0 else "ÉCHEC"))
	quit(0 if _echecs == 0 else 1)


func _ascii(s: String) -> bool:
	for i in s.length():
		# Les lettres accentuées (latin étendu) ; un tiret cadratin reste permis.
		if s.unicode_at(i) >= 0xC0 and s.unicode_at(i) <= 0x24F:
			return false
	return true


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
		print("  ✗ %s — obtenu %s, attendu %s" % [quoi, a, b])
