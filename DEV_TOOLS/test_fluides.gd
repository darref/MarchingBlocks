extends SceneTree
##
## TEST — les fluides (`addons/marchingblocks_core/fluides.gd`) : lac, rivière, océan, déduits des cases.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_fluides.gd
##
## ⚠ **LES ATTENDUS NE VIENNENT PAS DE LA FONCTION ÉPROUVÉE** (charte §6) : chaque monde est petit, et ses
## lacs, ses cours et ses océans sont déroulés À LA MAIN dans le commentaire du cas — case par case pour les
## cours, par dénombrement pour les volumes.

const FL := preload("res://addons/marchingblocks_core/fluides.gd")
const EM := preload("res://addons/marchingblocks_core/eau_maillage.gd")
const EP := preload("res://addons/marchingblocks_core/eau_presets.gd")
const FMonde := preload("res://addons/marchingblocks_core/format_monde.gd")

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== TEST — les fluides ===\n")
	_cuvette()
	_cuvette_echancree()
	_portee_du_debordement()
	_cuvette_qui_deborde()
	_cuvette_a_poche()
	_departage()
	_eau_voisine()
	_du_haut_du_mur()
	_escalier()
	_riviere_large()
	_riviere_par_un_lac()
	_ocean()
	_ocean_par_colonnes()
	_riviere_vers_l_ocean()
	_cavite_close()
	_reprise()
	_refus()
	_maillage()
	_nappes_fusionnees()
	_surface_pour_nager()
	_presets()
	_export_du_monde()
	_cout()
	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	quit(1 if _echecs > 0 else 0)


# ── les mondes ───────────────────────────────────────────────────────────────────────────────────────

static func _boite(d: Dictionary, a: Vector3i, b: Vector3i, plein := true) -> void:
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for z in range(a.z, b.z + 1):
				if plein:
					d[Vector3i(x, y, z)] = true
				else:
					d.erase(Vector3i(x, y, z))


static func _ens(cases_: Array) -> Dictionary:
	var d := {}
	for c in cases_:
		d[c] = true
	return d


## Une cuvette : un plancher 5×5 en y = 0, un anneau de murs (x ou z ∈ {0, 4}) en y = 1..2.
## L'intérieur (x, z ∈ 1..3) est vide aux rangées 1 et 2.
func _monde_cuvette() -> Dictionary:
	var m := {}
	_boite(m, Vector3i(0, 0, 0), Vector3i(4, 2, 4))
	_boite(m, Vector3i(1, 1, 1), Vector3i(3, 2, 3), false)
	return m


## LA MÊME CUVETTE, CALME : noyée dans un plateau (y = 0..2, x et z de −6 à 10) au ras de ses murs. Le seuil, sur le
## haut d'un mur, est à au moins 7 cases à plat de la première chute (le bord du plateau) : plus que
## `PORTEE_DE_DEBORD` (4), le lac ne déborde pas. (La cuvette nue, elle, donne sur le vide : elle déborde.)
func _monde_cuvette_calme() -> Dictionary:
	var m := {}
	_boite(m, Vector3i(-6, 0, -6), Vector3i(10, 2, 10))
	_boite(m, Vector3i(1, 1, 1), Vector3i(3, 2, 3), false)
	return m


static func _cours(r: Dictionary) -> Array:
	var a: Array = []
	for e in r["cours"]:
		a.append([e["case"], e["genre"]])
	return a


# ── les cas ──────────────────────────────────────────────────────────────────────────────────────────

## La cuvette se remplit jusqu'à ras bord : le bord est en y = 2, donc la première case qui déborde est en
## y = 3 et le lac est au niveau 2 — les 3 × 3 × 2 = 18 cases de l'intérieur. Pas de rivière.
func _cuvette() -> void:
	var m := _monde_cuvette_calme()
	var attendu := {}
	_boite(attendu, Vector3i(1, 1, 1), Vector3i(3, 2, 3))
	for depart in [Vector3i(2, 1, 2), Vector3i(2, 2, 2), Vector3i(1, 9, 3)]:
		var r := FL.source(m, depart)
		_egal(r["genre"], "lac", "cuvette depuis %s : un lac" % depart)
		_egal(r["niveau"], 2, "cuvette depuis %s : à ras bord (niveau 2)" % depart)
		_egal_ens(r["eau"], attendu, "cuvette depuis %s : les 18 cases de l'intérieur" % depart)
		_egal(r["cours"].size(), 0, "cuvette depuis %s : un lac ne coule pas" % depart)
	var r := FL.source(m, Vector3i(2, 1, 2))
	# Surface : la rangée du haut, 9 cases ; profondeur sous (2, 2, 2) : 2 cases puis le plancher.
	var attendue := {}
	_boite(attendue, Vector3i(1, 2, 1), Vector3i(3, 2, 3))
	_egal_ens(_ens(FL.surface(r["eau"], m)), attendue, "la surface de la cuvette : sa rangée du haut")
	_egal(FL.profondeur(r["eau"], m, Vector3i(2, 2, 2)), 2, "profondeur sous la surface : 2 cases")


## Une échancrure en (2, 2, 0) dans le mur de la cuvette NUE : le bord tombe à y = 1, le lac au niveau 1 — 9 cases.
## ⚠ ET IL DÉBORDE (Jordan, 2 octobre 2026 : « un lac qui a une digue qui donne sur une falaise ») : par l'échancrure,
## l'eau passe en (2, 2, 0) puis (2, 2, −1), au-dessus du vide, et tombe — (2, 1, −1), (2, 0, −1), (2, −1, −1), le
## bas du monde.
func _cuvette_echancree() -> void:
	var m := _monde_cuvette()
	m.erase(Vector3i(2, 2, 0))
	var attendu := {}
	_boite(attendu, Vector3i(1, 1, 1), Vector3i(3, 1, 3))
	var r := FL.source(m, Vector3i(2, 1, 2))
	_egal(r["genre"], "riviere", "échancrée sur le vide : le lac déborde, c'est une rivière")
	_egal(r["lacs"].size(), 1, "échancrée : un lac, le sien")
	if r["lacs"].size() == 1:
		_egal(r["lacs"][0]["niveau"], 1, "échancrée : le seuil descend à 1")
		_egal_ens(r["lacs"][0]["cases"], attendu, "échancrée : la rangée du bas seule")
	var cours := _cours(r)
	_egal(cours.slice(cours.size() - 5), [[Vector3i(2, 2, 0), "coule"], [Vector3i(2, 2, -1), "coule"],
		[Vector3i(2, 1, -1), "chute"], [Vector3i(2, 0, -1), "chute"], [Vector3i(2, -1, -1), "chute"]],
		"échancrée : l'eau passe par l'échancrure et tombe au pied de la digue")
	_egal(r["fin"], "sort", "échancrée : la chute quitte le monde")
	# La même, CALME : l'échancrure donne sur le plateau, au ras de la digue — plus d'issue à l'étage 2.
	var calme := _monde_cuvette_calme()
	calme.erase(Vector3i(2, 2, 0))
	var rc := FL.source(calme, Vector3i(2, 1, 2))
	_egal([rc["genre"], rc["cours"].size()], ["lac", 0], "dans le plateau : un lac calme, rien ne coule")


## LA PORTÉE DU DÉBORDEMENT (PROPOSÉ : `PORTEE_DE_DEBORD` = 4). Un chenal (murs z = ±1 et x = −1, y = 0..2), une
## dalle y = 0 sur x = 0..n, un plateau y = 1 sur x = 1..n : la fosse (0, 1, 0) est un lac d'une case. Son issue est
## au-dessus du plateau, à l'étage 2 ; le seuil est (0, 2, 0), et la première chute est en (n + 1, 2, 0) — à n + 1
## cases. Déroulé à la main pour n = 3 (à 4 cases, il déborde) : le lac, puis (0..4, 2, 0) à plat, et la chute
## (4, 1, 0), (4, 0, 0), (4, −1, 0) — le bas du monde. Pour n = 4 (à 5 cases) : un lac calme.
func _portee_du_debordement() -> void:
	for n in [3, 4]:
		var m := {}
		_boite(m, Vector3i(-1, 0, -1), Vector3i(n, 2, -1))
		_boite(m, Vector3i(-1, 0, 1), Vector3i(n, 2, 1))
		_boite(m, Vector3i(-1, 0, 0), Vector3i(-1, 2, 0))
		_boite(m, Vector3i(0, 0, 0), Vector3i(n, 0, 0))
		_boite(m, Vector3i(1, 1, 0), Vector3i(n, 1, 0))
		var r := FL.source(m, Vector3i(0, 1, 0))
		if n == 3:
			_egal(r["genre"], "riviere", "chute à 4 cases du seuil : le lac déborde")
			_egal(_cours(r), [[Vector3i(0, 1, 0), "lac"], [Vector3i(0, 2, 0), "coule"], [Vector3i(1, 2, 0), "coule"],
				[Vector3i(2, 2, 0), "coule"], [Vector3i(3, 2, 0), "coule"], [Vector3i(4, 2, 0), "coule"],
				[Vector3i(4, 1, 0), "chute"], [Vector3i(4, 0, 0), "chute"], [Vector3i(4, -1, 0), "chute"]],
				"chute à 4 cases : le cours, case par case")
			_egal_ens(r["eau"], _ens([Vector3i(0, 1, 0)]), "chute à 4 cases : le lac d'une case")
			_egal(r["fin"], "sort", "chute à 4 cases : elle quitte le monde")
		else:
			_egal([r["genre"], r["niveau"], r["cours"].size()], ["lac", 1, 0], "chute à 5 cases : un lac calme")


## La cuvette NUE, sans échancrure : à ras bord (18 cases, niveau 2), elle déborde par-dessus un mur et tombe au
## pied de la cuvette — une rivière qui quitte le monde.
func _cuvette_qui_deborde() -> void:
	var m := _monde_cuvette()
	var attendu := {}
	_boite(attendu, Vector3i(1, 1, 1), Vector3i(3, 2, 3))
	var r := FL.source(m, Vector3i(2, 1, 2))
	_egal(r["genre"], "riviere", "cuvette posée sur le vide : elle déborde")
	_vrai(r["lacs"].size() == 1 and r["lacs"][0]["niveau"] == 2, "… après s'être remplie à ras bord (niveau 2)")
	_egal_ens(r["eau"], attendu, "… ses 18 cases")
	var chutes: Array = r["cours"].filter(func(e): return e["genre"] == "chute")
	_vrai(chutes.size() == 4 and chutes.all(func(e): return not attendu.has(e["case"]) and not m.has(e["case"]))
		and (chutes[-1]["case"] as Vector3i).y == -1, "… et tombe de 4 cases, hors de la cuvette, jusqu'au bas du monde")
	_egal(r["fin"], "sort", "… elle quitte le monde")


## DÉCIDÉ (vases communicants) : une poche ouverte SOUS l'eau se remplit. Le plancher s'étend jusqu'à
## x = 6 ; le mur (4, 1, 2) est ouvert sous son linteau (4, 2, 2) vers la poche (5, 1, 2), close par
## (6, 1, 2), (5, 1, 1), (5, 1, 3) et le toit (5, 2, 2). Lac : 18 + 2 = 20 cases ; la surface ne compte
## ni l'ouverture ni la poche, qui sont sous la roche.
func _cuvette_a_poche() -> void:
	# Dans le plateau (le lac reste calme) : la poche y est déjà close de toutes parts, on la creuse.
	var m := _monde_cuvette_calme()
	m.erase(Vector3i(4, 1, 2))
	m.erase(Vector3i(5, 1, 2))
	var attendu := {}
	_boite(attendu, Vector3i(1, 1, 1), Vector3i(3, 2, 3))
	attendu[Vector3i(4, 1, 2)] = true
	attendu[Vector3i(5, 1, 2)] = true
	var r := FL.source(m, Vector3i(2, 1, 2))
	_egal(r["niveau"], 2, "poche : le niveau ne change pas")
	_egal_ens(r["eau"], attendu, "poche : ouverte sous l'eau, elle est noyée")
	_egal(FL.surface(r["eau"], m).size(), 9, "poche : sous la roche, pas de surface")


## LE DÉPARTAGE : une fosse (2..4, 1, 0) entre deux barrages ÉGAUX (1, 1, 0) et (5, 1, 0), dans un chenal
## (murs z = ±1, y = 1..3, x = 0..6) sur une dalle y = 0 ; les deux bouts sont ouverts. Deux seuils de même
## hauteur : c'est l'ordre d'insertion qui choisit. Déroulé à la main depuis (2, 1, 0), voisins +X −X +Z −Z
## bas haut : (3,1,0) s1, (2,2,0) s2 ; (4,1,0) s3, (3,2,0) s4 ; (4,2,0) s5. À l'altitude 2, dans l'ordre
## d'insertion : (2,2,0) pousse (1,2,0) s6 ; (4,2,0) pousse (5,2,0) s9 ; (1,2,0) pousse (0,2,0) s11 ;
## (5,2,0) pousse (6,2,0) s13 ; (0,2,0) pousse (−1,2,0) s15, l'horizon, tiré avant (7,2,0) s18 : l'issue est
## du côté −X, et le seuil — la première case du chemin à l'altitude 2 — est (2, 2, 0).
## ⚠ Départager à l'envers (le dernier inséré d'abord) file en profondeur vers +X et rend (4, 2, 0). Depuis
## le milieu (3, 1, 0), les deux ordres tombaient d'accord : le cas ne gardait rien.
func _departage() -> void:
	var m := {}
	_boite(m, Vector3i(0, 0, 0), Vector3i(6, 0, 0))
	_boite(m, Vector3i(0, 1, -1), Vector3i(6, 3, -1))
	_boite(m, Vector3i(0, 1, 1), Vector3i(6, 3, 1))
	m[Vector3i(1, 1, 0)] = true
	m[Vector3i(5, 1, 0)] = true
	var r: Dictionary = FL._creux(m, FL.boite(m), {}, {}, Vector3i(2, 1, 0), 1, FL.VOLUME_MAXI)
	_egal([r["niveau"], r["issue"], r["seuil"]], [1, "sort", Vector3i(2, 2, 0)],
		"deux seuils égaux : le premier inséré l'emporte, côté −X")
	_egal(r["cases"].size(), 3, "deux seuils égaux : la fosse jusqu'aux barrages")


## Une eau déjà là, AU MÊME ÉTAGE que la coulée (une `eau_fixe` passée par l'appelant) : on s'y arrête, on ne
## la traverse pas. Dalle y = 0 (x = 0..4), murs z = ±1 ; source (0, 1, 0), eau en (2, 1, 0). (1, 1, 0) est
## tirée avant (−1, 1, 0) — d'où l'on tomberait — et touche l'eau : la rivière la rejoint là.
## (Par `monde()`, ce cas n'arrive pas : une case de rivière voisine d'un océan à son étage EST de l'océan.)
func _eau_voisine() -> void:
	var m := {}
	_boite(m, Vector3i(0, 0, 0), Vector3i(4, 0, 0))
	_boite(m, Vector3i(0, 1, -1), Vector3i(4, 2, -1))
	_boite(m, Vector3i(0, 1, 1), Vector3i(4, 2, 1))
	var r := FL.source(m, Vector3i(0, 1, 0), _ens([Vector3i(2, 1, 0)]))
	_egal([_cours(r), r["fin"]], [[[Vector3i(0, 1, 0), "coule"], [Vector3i(1, 1, 0), "coule"]], "rejoint"],
		"une eau au même étage : la rivière s'y arrête")


## Du haut du mur de la cuvette, en (0, 3, 0) : la case (1, 3, 0) est poussée la première (+X) mais repose
## sur le mur ; la seconde, (−1, 3, 0), est au-dessus du vide : l'eau y va, et tombe jusqu'au bas du monde
## (y = −1, l'horizon). Une rivière d'une case à plat et quatre de chute.
func _du_haut_du_mur() -> void:
	var r := FL.source(_monde_cuvette(), Vector3i(0, 3, 0))
	_egal(r["genre"], "riviere", "du haut du mur : une rivière")
	_egal(_cours(r), [[Vector3i(0, 3, 0), "coule"], [Vector3i(-1, 3, 0), "coule"],
		[Vector3i(-1, 2, 0), "chute"], [Vector3i(-1, 1, 0), "chute"], [Vector3i(-1, 0, 0), "chute"],
		[Vector3i(-1, -1, 0), "chute"]], "du haut du mur : le cours, case par case")
	_egal(r["fin"], "sort", "du haut du mur : elle quitte le monde")


## Un escalier dans un chenal : marches de hauteur 3, 3, 2, 2, 1, 1 en x = 0..5 (z = 0), murs de hauteur 5
## en z = ±1 et en x = −1. L'eau posée sur la marche du haut coule, tombe d'une case, coule, tombe…
##   y = 3 : (0,3,0) (1,3,0) (2,3,0) — sous (2,3,0), (2,2,0) est vide : chute en (2,2,0) ;
##   y = 2 : (3,2,0) (4,2,0) — chute en (4,1,0) ;
##   y = 1 : (5,1,0) (6,1,0) — au bout du chenal, chute en (6,0,0) puis (6,−1,0), l'horizon.
func _escalier() -> void:
	var m := {}
	var h := [3, 3, 2, 2, 1, 1]
	for x in 6:
		_boite(m, Vector3i(x, 0, 0), Vector3i(x, h[x] - 1, 0))
	_boite(m, Vector3i(-1, 0, -1), Vector3i(5, 4, -1))
	_boite(m, Vector3i(-1, 0, 1), Vector3i(5, 4, 1))
	_boite(m, Vector3i(-1, 0, 0), Vector3i(-1, 4, 0))
	var r := FL.source(m, Vector3i(0, 3, 0))
	_egal(r["genre"], "riviere", "escalier : une rivière")
	_egal(_cours(r), [[Vector3i(0, 3, 0), "coule"], [Vector3i(1, 3, 0), "coule"], [Vector3i(2, 3, 0), "coule"],
		[Vector3i(2, 2, 0), "chute"], [Vector3i(3, 2, 0), "coule"], [Vector3i(4, 2, 0), "coule"],
		[Vector3i(4, 1, 0), "chute"], [Vector3i(5, 1, 0), "coule"], [Vector3i(6, 1, 0), "coule"],
		[Vector3i(6, 0, 0), "chute"], [Vector3i(6, -1, 0), "chute"]], "escalier : le cours, case par case")
	_egal(r["fin"], "sort", "escalier : elle quitte le monde")
	_egal(r["eau"].size(), 0, "escalier : aucun lac en route")


## LA LARGEUR À LA POSE (Jordan, 3 octobre 2026). Une marche large : x = 0..2 haute de 3 (y = 0..2), x = 3..5 haute
## de 1 (y = 0), sur z = −3..3 ; un mur derrière (x = −1, y = 0..4). L'eau posée en (0, 3, 0) coule vers +X (3 pas
## jusqu'à la chute en x = 3, contre 4 jusqu'au bord en z = 4) : les sources se rangent EN TRAVERS, le long de Z.
## Attendus écrits à la main.
func _riviere_large() -> void:
	var m := {}
	_boite(m, Vector3i(0, 0, -3), Vector3i(2, 2, 3))
	_boite(m, Vector3i(3, 0, -3), Vector3i(5, 0, 3))
	_boite(m, Vector3i(-1, 0, -3), Vector3i(-1, 4, 3))
	var s := Vector3i(0, 3, 0)
	_egal(FL.sources_en_largeur(m, s, 1), [s], "largeur 1 : la source seule")
	_egal(FL.sources_en_largeur(m, s, 3), [s, Vector3i(0, 3, -1), Vector3i(0, 3, 1)],
		"largeur 3 : en travers du courant (+X), le long de Z, centrée")
	_egal(FL.sources_en_largeur(m, s, 4), [s, Vector3i(0, 3, -1), Vector3i(0, 3, 1), Vector3i(0, 3, 2)],
		"largeur 4 (paire) : une case de plus du côté +")
	_egal(FL.sources_en_largeur(m, s, 9).size(), 7,
		"largeur 9 : les deux bouts au-dessus du vide (z = ±4) seraient une MER — écartés")
	m[Vector3i(0, 3, 1)] = true
	_egal(FL.sources_en_largeur(m, s, 3), [s, Vector3i(0, 3, -1)], "une voisine dans la matière : écartée")
	m.erase(Vector3i(0, 3, 1))
	# Un lac ne s'élargit pas : la cuvette CALME (la nue déborde sur le vide : c'est une rivière).
	var c := _monde_cuvette_calme()
	_egal(FL.source(c, Vector3i(2, 1, 2))["genre"], "lac", "(la cuvette calme est bien un lac)")
	_egal(FL.sources_en_largeur(c, Vector3i(2, 1, 2), 5), [Vector3i(2, 1, 2)], "un lac : la source seule")
	# Le maillage d'une rivière large : plusieurs bandes, sans doublon (deux sources ne posent pas deux eaux).
	var corps: Array = []
	for src in FL.sources_en_largeur(m, s, 3):
		corps.append(FL.source(m, src))
	var largeurs := {}
	for r in corps:
		for e in r["cours"]:
			if e["genre"] == "chute":
				largeurs[(e["case"] as Vector3i).z] = true
	_vrai(largeurs.size() == 3, "largeur 3 : la cascade tombe sur trois colonnes en z (%s)" % [largeurs.keys()])


## La rivière remplit un creux en route, puis en déborde. Une dalle y = 0 (x = 0..10, z = −1..1), des murs
## de chenal en z = ±1 et un fond en x = 0 (y = 1..4), une plate-forme x = 1..3 (y = 1..2), un barrage
## (7, 1, 0). Entre plate-forme et barrage, la fosse x = 4..6.
##   y = 3 : (1,3,0) … (4,3,0) — chute en (4,2,0), (4,1,0) : le fond de la fosse ;
##   à l'étage 1 rien ne tombe : la fosse est un creux. Son bord est le barrage (y = 1), donc elle déborde
##   à y = 2 : lac au niveau 1 = (4,1,0) (5,1,0) (6,1,0). Le seuil est (6, 2, 0), au-dessus du lac ;
##   y = 2 : (6,2,0) (7,2,0) (8,2,0) — chute en (8,1,0) ;
##   y = 1 : (9,1,0) (10,1,0) (11,1,0) — au bout de la dalle, chute en (11,0,0), (11,−1,0).
func _riviere_par_un_lac() -> void:
	var m := {}
	_boite(m, Vector3i(0, 0, -1), Vector3i(10, 0, 1))
	_boite(m, Vector3i(0, 1, -1), Vector3i(10, 4, -1))
	_boite(m, Vector3i(0, 1, 1), Vector3i(10, 4, 1))
	_boite(m, Vector3i(0, 1, 0), Vector3i(0, 4, 0))
	_boite(m, Vector3i(1, 1, 0), Vector3i(3, 2, 0))
	m[Vector3i(7, 1, 0)] = true
	var r := FL.source(m, Vector3i(1, 3, 0))
	_egal(r["genre"], "riviere", "par un lac : une rivière")
	_egal(_cours(r), [[Vector3i(1, 3, 0), "coule"], [Vector3i(2, 3, 0), "coule"], [Vector3i(3, 3, 0), "coule"],
		[Vector3i(4, 3, 0), "coule"], [Vector3i(4, 2, 0), "chute"], [Vector3i(4, 1, 0), "chute"],
		[Vector3i(4, 1, 0), "lac"], [Vector3i(6, 2, 0), "coule"], [Vector3i(7, 2, 0), "coule"],
		[Vector3i(8, 2, 0), "coule"], [Vector3i(8, 1, 0), "chute"], [Vector3i(9, 1, 0), "coule"],
		[Vector3i(10, 1, 0), "coule"], [Vector3i(11, 1, 0), "coule"], [Vector3i(11, 0, 0), "chute"],
		[Vector3i(11, -1, 0), "chute"]], "par un lac : le cours, case par case")
	_egal(r["lacs"].size(), 1, "par un lac : un lac en route")
	if r["lacs"].size() == 1:
		_egal(r["lacs"][0]["niveau"], 1, "par un lac : au niveau du barrage")
		_egal_ens(r["lacs"][0]["cases"], _ens([Vector3i(4, 1, 0), Vector3i(5, 1, 0), Vector3i(6, 1, 0)]),
			"par un lac : la fosse jusqu'au barrage")
	_egal(r["fin"], "sort", "par un lac : elle quitte le monde")


## Une île pleine x, z = 0..6, y = 0..3, avec une cavité CLOSE (2, 1, 2), et une galerie (4..6, 1, 3) ouverte
## sur le flanc x = 7, qui monte en (4, 2, 3) sous le toit (4, 3, 3).
## Boîte : x, z ∈ −1..7, y ∈ −1..4. Océan au niveau 2 : les 9 × 4 × 9 = 324 cases de y = −1..2, moins la
## roche à y = 0..2 (7 × 3 × 7 = 147, moins les 5 cases creusées = 142), moins la cavité close : 181.
## Surface : l'anneau autour de l'île à y = 2, 81 − 49 = 32 ; la galerie est sous la roche.
func _monde_ile() -> Dictionary:
	var m := {}
	_boite(m, Vector3i(0, 0, 0), Vector3i(6, 3, 6))
	for c in [Vector3i(2, 1, 2), Vector3i(4, 1, 3), Vector3i(5, 1, 3), Vector3i(6, 1, 3), Vector3i(4, 2, 3)]:
		m.erase(c)
	return m


func _ocean() -> void:
	var m := _monde_ile()
	_vrai(FL.dans_le_vide(m, Vector3i(10, 2, 10)), "au large : dans le vide")
	_vrai(not FL.dans_le_vide(m, Vector3i(3, 9, 3)), "au-dessus de l'île : pas dans le vide")
	var r := FL.source(m, Vector3i(10, 2, 10))
	_egal(r["genre"], "ocean", "au large : un océan")
	_egal(r["niveau"], 2, "au large : au niveau du clic")
	var eau: Dictionary = r["eau"]
	_egal(eau.size(), 181, "niveau 2 : 181 cases")
	_vrai(not eau.has(Vector3i(2, 1, 2)), "niveau 2 : la cavité close reste sèche")
	_vrai(eau.has(Vector3i(4, 2, 3)), "niveau 2 : la galerie ouverte sous l'eau est noyée jusqu'au niveau")
	_egal(FL.surface(eau, m).size(), 32, "niveau 2 : la surface cerne l'île")
	_egal(FL.profondeur(eau, m, Vector3i(4, 2, 3)), 2, "profondeur dans la galerie : 2 puis la roche")
	_egal(FL.profondeur(eau, m, Vector3i(-1, 2, -1)), -1, "profondeur au large : sans fond")
	eau = FL.source(m, Vector3i(10, 1, 10))["eau"]
	_vrai(eau.has(Vector3i(4, 1, 3)) and not eau.has(Vector3i(4, 2, 3)),
		"niveau 1 : la galerie noyée, la chambre au-dessus du niveau sèche")
	# Niveau 0 : y = −1..0, 162 cases, moins la roche de y = 0 (49) : 113 ; la galerie (y = 1) est sèche.
	eau = FL.source(m, Vector3i(10, 0, 10))["eau"]
	_egal(eau.size(), 113, "niveau 0 : 113 cases")
	_egal(FL.source(m, Vector3i(10, -5, 10))["eau"].size(), 0, "sous le monde : aucune case, un plan seul")


## L'île et un océan au niveau 1 ; une source sur le toit (3, 4, 3). Le bord le plus proche est à 4 cases
## dans les quatre directions : 5 cases à plat, puis la chute — (x, 3), (x, 2) — et (x, 1) est l'océan.
## L'OCÉAN PAR TRONÇONS (2 octobre 2026) rend EXACTEMENT ce que rendait le remplissage case par case. L'attendu est
## ce remplissage, réécrit ICI : depuis un coin de la boîte, voisins par les faces, sans dépasser le niveau, ni sortir
## de la boîte, ni entrer dans la roche. Mondes au hasard (graine fixe), troués de grottes, de surplombs et d'arches ;
## et la surface lue sur les tronçons (`EM.surface_des_colonnes`) = `FL.surface` + `FL.profondeur`.
func _ocean_par_colonnes() -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 20261002
	var ecarts := 0
	var surfaces := 0
	var grottes := 0
	for essai in 12:
		var m := {}
		for x in 14:
			for z in 14:
				var h := hasard.randi_range(0, 6)
				for y in h:
					if hasard.randf() > 0.25:   # des trous dans la roche : grottes, surplombs, arches
						m[Vector3i(x, y, z)] = true
		var niveau := hasard.randi_range(0, 5)
		var b := FL.boite(m)
		var lo: Vector3i = b["lo"]
		var hi: Vector3i = b["hi"]
		var attendu := {lo: true}
		var file: Array = [lo]
		var i := 0
		while i < file.size():
			var c: Vector3i = file[i]
			i += 1
			for f in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1),
					Vector3i(0, 0, -1)]:
				var v: Vector3i = c + f
				if v.y > niveau or attendu.has(v) or m.has(v) or v.x < lo.x or v.y < lo.y or v.z < lo.z 						or v.x > hi.x or v.y > hi.y or v.z > hi.z:
					continue
				attendu[v] = true
				file.append(v)
		var o := FL.ocean(m, niveau)
		var eau: Dictionary = o["eau"]
		if eau.size() != attendu.size() or not attendu.keys().all(func(k): return eau.has(k)):
			ecarts += 1
		# Des grottes sous la roche reliées à la mer : le cas qui exerce le passage d'un tronçon à son voisin.
		for k: Vector3i in eau:
			if m.has(k + Vector3i.UP) and k.y > lo.y and not eau.has(k + Vector3i.DOWN):
				grottes += 1
		var lue: Dictionary = EM.surface_des_colonnes(o["colonnes"], m, b)
		var faite := {}
		for k in FL.surface(eau, m):
			faite[k] = FL.profondeur(eau, m, k)
		if lue != faite:
			surfaces += 1
	_egal(ecarts, 0, "océan par tronçons : le même ensemble que le remplissage case par case, sur 12 mondes au hasard")
	_egal(surfaces, 0, "océan par tronçons : la même surface, les mêmes profondeurs")
	_vrai(grottes > 0, "… et ces mondes ont des grottes noyées perchées sur la roche (%d cases) : le passage d'un tronçon à l'autre est exercé" % grottes)


func _riviere_vers_l_ocean() -> void:
	var m := {}
	_boite(m, Vector3i(0, 0, 0), Vector3i(6, 3, 6))
	var w := FL.monde(m, [Vector3i(3, 4, 3), Vector3i(20, 1, 20)])
	var r: Dictionary = w["corps"][0]
	_egal(r["genre"], "riviere", "vers l'océan : une rivière")
	_egal(r["fin"], "rejoint", "vers l'océan : elle le rejoint")
	var coule := 0
	var chute := 0
	for e in r["cours"]:
		if e["genre"] == "coule":
			coule += 1
		elif e["genre"] == "chute":
			chute += 1
	_egal([coule, chute], [5, 2], "vers l'océan : 5 cases à plat, 2 de chute")
	if not r["cours"].is_empty():
		_egal(r["cours"][0]["case"], Vector3i(3, 4, 3), "vers l'océan : elle part de la source")
		var der: Vector3i = r["cours"][-1]["case"]
		_vrai((w["ocean"] as Dictionary).has(der + Vector3i(0, -1, 0)), "vers l'océan : elle finit dessus")
	_egal(w["corps"][1]["genre"], "ocean", "le second corps est l'océan")
	var w2 := FL.monde(m, [Vector3i(20, 1, 20), Vector3i(3, 4, 3)])
	_egal(_cours(w2["corps"][1]), _cours(r), "l'ordre des sources ne change rien")
	# Une source dans l'eau d'un océan, sur un fond de roche : refusée, l'eau est déjà là.
	var ile := _monde_ile()
	var w3 := FL.monde(ile, [Vector3i(20, 2, 20), Vector3i(4, 1, 3)])
	_egal(w3["corps"][1]["erreur"], "dans_l_eau", "dans la galerie noyée : déjà de l'eau")


## Une cavité close (2, 1..2, 2) dans un bloc plein 0..4³ : aucune issue. Le lac monte jusqu'à la hauteur du
## clic — 2 cases depuis (2, 2, 2), une seule depuis (2, 1, 2) —, et le dit (« ferme »).
func _cavite_close() -> void:
	var m := {}
	_boite(m, Vector3i(0, 0, 0), Vector3i(4, 4, 4))
	m.erase(Vector3i(2, 1, 2))
	m.erase(Vector3i(2, 2, 2))
	var r := FL.source(m, Vector3i(2, 2, 2))
	_egal([r["genre"], r["fin"], r["niveau"]], ["lac", "ferme", 2], "cavité close, clic en haut")
	_egal_ens(r["eau"], _ens([Vector3i(2, 1, 2), Vector3i(2, 2, 2)]), "cavité close : pleine")
	r = FL.source(m, Vector3i(2, 1, 2))
	_egal([r["niveau"], r["eau"].size()], [1, 1], "cavité close, clic en bas : une case")


## LA REPRISE (`FL.monde(…, avant, changees)`, 2 octobre 2026) ne change RIEN au résultat : après chaque geste d'une
## suite au hasard (graine fixe), le rendu repris est comparé à un calcul COMPLET (sans `avant`) — genre, niveau,
## eau, cours, fin, et l'eau des océans. Et elle reprend vraiment : peindre au-dessus de la mer, loin du lac, ne
## recalcule ni la mer ni le lac (le même dictionnaire, `is_same`).
## Le monde : une île 0..16 en x et z, roche jusqu'à y = 6, un creux 7..9 × 5..6 × 7..9 dans son dos (le lac,
## calme : la première chute est à plus de 4 cases de sa rive), une colonne (la rivière) ; la mer au niveau 1.
func _reprise() -> void:
	var m := {}
	_boite(m, Vector3i(0, 0, 0), Vector3i(16, 6, 16))
	_boite(m, Vector3i(7, 5, 7), Vector3i(9, 6, 9), false)
	_boite(m, Vector3i(14, 7, 14), Vector3i(14, 11, 14))
	var sources: Array = [Vector3i(-3, 1, -3), Vector3i(8, 5, 8), Vector3i(14, 12, 14)]
	var w := FL.monde(m, sources)
	_vrai(w["corps"][0]["genre"] == "ocean" and w["corps"][1]["genre"] == "lac" and w["corps"][2]["genre"] == "riviere",
		"reprise : une mer, un lac, une rivière")
	# Peindre au-dessus de la mer, loin du lac et de la rivière : tout est repris.
	var avant := m.duplicate()
	m[Vector3i(1, 10, 1)] = true   # au-dessus de l'emprise du lac (ses cases vues montent à la rangée 8, + 1)
	var w2 := FL.monde(m, sources, FL.VOLUME_MAXI, w, FL.changees_entre(avant, m))
	_vrai(is_same(w2["corps"][0], w["corps"][0]) and is_same(w2["corps"][1], w["corps"][1]) and is_same(w2["ocean"], w["ocean"]),
		"peindre au-dessus de la mer, loin du lac : ni la mer ni le lac ne sont recalculés")
	# Creuser la digue du lac : le lac est recalculé, la mer non.
	avant = m.duplicate()
	m[Vector3i(8, 7, 6)] = true
	var w3 := FL.monde(m, sources, FL.VOLUME_MAXI, w2, FL.changees_entre(avant, m))
	_vrai(is_same(w3["corps"][0], w2["corps"][0]) and not is_same(w3["corps"][1], w2["corps"][1]),
		"poser une case contre la rive du lac : le lac est recalculé, la mer reprise")
	# Creuser le FOND du lac : une case pleine, jamais « vue » par le remplissage — c'est la marge d'une case de
	# l'emprise qui la couvre. Le lac doit être recalculé, et descendre d'une case (19 cases au lieu de 18).
	avant = m.duplicate()
	m.erase(Vector3i(8, 4, 8))
	var w4 := FL.monde(m, sources, FL.VOLUME_MAXI, w3, FL.changees_entre(avant, m))
	_vrai(not is_same(w4["corps"][1], w3["corps"][1]) and w4["corps"][1]["eau"].size() == FL.monde(m, sources)["corps"][1]["eau"].size(),
		"creuser le fond du lac : il est recalculé (%d cases)" % w4["corps"][1]["eau"].size())
	w3 = w4
	# Peindre AU-DESSUS DE TOUT monte le dessus de la boîte du monde : le lac, qui n'y est jamais monté, est repris.
	avant = m.duplicate()
	m[Vector3i(1, 20, 1)] = true
	var w5 := FL.monde(m, sources, FL.VOLUME_MAXI, w3, FL.changees_entre(avant, m))
	_vrai(FL.boite(m) != FL.boite(avant) and is_same(w5["corps"][1], w3["corps"][1]),
		"peindre au-dessus de tout (la boîte monte) : le lac est repris")
	m.erase(Vector3i(1, 20, 1))
	w3 = FL.monde(m, sources, FL.VOLUME_MAXI, w5, FL.changees_entre(avant, m).merged({Vector3i(1, 20, 1): true}))
	# Une suite de gestes au hasard, chacun comparé à un calcul complet ; un sur trois loin dehors, pour que les faces
	# de la boîte bougent.
	var hasard := RandomNumberGenerator.new()
	hasard.seed = 1002
	var ecarts := 0
	var reprises := 0
	var prec := w3
	for geste in 150:
		avant = m.duplicate()
		for n in hasard.randi_range(1, 3):
			var c := Vector3i(hasard.randi_range(-1, 17), hasard.randi_range(0, 12), hasard.randi_range(-1, 17))
			if hasard.randi() % 3 == 0:
				c = Vector3i(hasard.randi_range(-4, 20), hasard.randi_range(-3, 16), hasard.randi_range(-4, 20))
			if m.has(c):
				m.erase(c)
			elif not sources.has(c):
				m[c] = true
		# Un geste sur quatre RETIRE une case lointaine (hors de l'île) : la boîte du monde rétrécit, ses faces rentrent.
		if hasard.randi() % 4 == 0:
			var loin: Array = m.keys().filter(func(k: Vector3i) -> bool:
				return k.x < 0 or k.z < 0 or k.x > 16 or k.z > 16 or k.y > 11)
			if not loin.is_empty():
				m.erase(loin[hasard.randi() % loin.size()])
		var repris := FL.monde(m, sources, FL.VOLUME_MAXI, prec, FL.changees_entre(avant, m))
		var complet := FL.monde(m, sources)
		for i in sources.size():
			var a: Dictionary = repris["corps"][i]
			var b: Dictionary = complet["corps"][i]
			if is_same(a, prec["corps"][i]):
				reprises += 1
			if [a["genre"], a["erreur"], a["niveau"], a["fin"], _cours(a)] != [b["genre"], b["erreur"], b["niveau"], b["fin"], _cours(b)] 					or a["eau"].size() != b["eau"].size() or not b["eau"].keys().all(func(k): return a["eau"].has(k)):
				ecarts += 1
		if repris["ocean"].size() != complet["ocean"].size():
			ecarts += 1
		prec = repris
	_egal(ecarts, 0, "150 gestes au hasard : le rendu repris est celui d'un calcul complet")
	_vrai(reprises > 50, "… et la reprise a servi (%d sources reprises sur 450)" % reprises)


func _refus() -> void:
	var m := _monde_cuvette()
	_egal(FL.source(m, Vector3i(0, 0, 0))["erreur"], "dans_la_matiere", "dans la roche : refusé")
	_egal(FL.source(_monde_ile(), Vector3i(10, 2, 10), {}, 50)["erreur"], "trop_grand", "océan trop grand : refusé")
	var r := FL.source(_monde_ile(), Vector3i(10, 2, 10), {}, 50)
	_egal([r["genre"], r["eau"].size()], ["", 0], "un refus ne rend rien")
	_egal(FL.source({}, Vector3i(0, 3, 0))["genre"], "ocean", "sans monde : un océan, un plan seul")


## LE MAILLAGE (`eau_maillage.gd`). Attendus écrits à la main depuis les hauteurs de la charte : nappe en
## rangée + 0,7, bande de rivière en rangée − 0,15, débord de 0,45 sous une voisine pleine de même rangée,
## lame de cascade 0,1 en retrait du plan entre la lèvre et la case d'où l'eau vient, du haut de la bande jusqu'à
## la dernière chute − 0,3 ; une bande sur chaque case du cours qui repose sur la matière (jamais sur une lèvre).
func _maillage() -> void:
	# La cuvette : ses 9 cases de surface à 2,7, FUSIONNÉES en une nappe (même profondeur partout) ; le bord avance
	# de 0,45 sous chaque mur → x, z ∈ [0,55 ; 4,45] ; profondeur 2 partout (2 cases d'eau, puis le plancher) → 2 / 8.
	var m := _monde_cuvette_calme()
	var q := _quads(EM.maillage([FL.source(m, Vector3i(2, 1, 2))], m))
	_egal(q.size(), 1, "cuvette : une seule nappe (9 cases fusionnées)")
	_vrai(_meme_boite(_boite_de(q), [Vector3(0.55, 2.7, 0.55), Vector3(4.45, 2.7, 4.45)]), "cuvette : à 2,7, sous les murs")
	_vrai(q.all(func(e): return _couleur_proche(e["c"], Color(0.5, 0.5, 0.0, 0.25))),
		"cuvette : dormante, profondeur 2 cases")
	_vrai(_bien_tournes(q), "cuvette : faces avant horaires, normales en haut")
	# Un couvercle sur une rangée de la cuvette (x 1..3, y 3, z 1) : le lac est le même, et sa nappe passe dessous.
	var couverte := _monde_cuvette_calme()
	_boite(couverte, Vector3i(1, 3, 1), Vector3i(3, 3, 1))
	var lac_couvert := FL.source(couverte, Vector3i(2, 1, 2))
	_egal([lac_couvert["genre"], lac_couvert["niveau"]], ["lac", 2], "cuvette couverte d'une rangée : le même lac")
	_egal(_quads(EM.maillage([lac_couvert], couverte)).filter(func(e): return _couvre(e, Vector3(2.5, 2.7, 1.5))).size(), 1,
		"cuvette couverte : la nappe passe sous le couvercle")

	# L'escalier : 6 bandes — (0,3) (1,3), la retombée (2,2) et (3,2), la retombée (4,1) et (5,1) ; ni les lèvres
	# (2,3) (4,2) (6,1), au-dessus du vide, ni (6,0) (6,−1), qui tombent hors du monde — et 3 lames.
	var esc := {}
	var h := [3, 3, 2, 2, 1, 1]
	for x in 6:
		_boite(esc, Vector3i(x, 0, 0), Vector3i(x, h[x] - 1, 0))
	_boite(esc, Vector3i(-1, 0, -1), Vector3i(5, 4, -1))
	_boite(esc, Vector3i(-1, 0, 1), Vector3i(5, 4, 1))
	_boite(esc, Vector3i(-1, 0, 0), Vector3i(-1, 4, 0))
	q = _quads(EM.maillage([FL.source(esc, Vector3i(0, 3, 0))], esc))
	_egal(q.size(), 12, "escalier : 6 bandes, 3 lames, 3 lèvres")
	for c in [Vector3i(2, 2, 0), Vector3i(4, 1, 0)]:
		_egal(q.filter(func(e): return _meme_boite(_boite_de([e]), [Vector3(c.x - 0.45, c.y - 0.15, -0.45),
			Vector3(c.x + 1, c.y - 0.15, 1.45)])).size(), 1,
			"escalier : la marche %s, où l'eau retombe, est mouillée (et s'avance sous la marche d'au-dessus)" % c)
	# Sur une lèvre, seule la LÈVRE de la cascade s'avance, de 0,3 au plus : aucune bande ne la couvre.
	for c in [Vector3i(2, 3, 0), Vector3i(4, 2, 0), Vector3i(6, 1, 0)]:
		_vrai(q.all(func(e): return not is_equal_approx(_boite_de([e])[0].y, c.y - 0.15) or _boite_de([e])[1].x < c.x + 0.3001),
			"escalier : aucune bande ne flotte sur la lèvre %s (la lèvre de la cascade s'arrête à 0,3)" % c)
	# La bande de (0,3,0) : sous le mur du fond (x −0,45) et les deux murs du chenal (z −0,45 … 1,45), à 2,85,
	# courant vers +X.
	var bande := q.filter(func(e): return _meme_boite(_boite_de([e]), [Vector3(-0.45, 2.85, -0.45), Vector3(1, 2.85, 1.45)]))
	_egal(bande.size(), 1, "escalier : la bande de la première case, à sa place")
	if bande.size() == 1:
		_vrai(_couleur_proche(bande[0]["c"], Color(1.0, 0.5, 0.5, 0.05)), "… courant +X, genre rivière")
	# Les lames, 0,3 DEVANT le plan de la falaise (x = 2,3 ; 4,3 ; 6,3), élargies de 0,3 aux deux bouts (aucune voisine
	# sur leur plan) : z ∈ [−0,3 ; 1,3] ; de 2,85 à 1,7, de 1,85 à 0,7, de 0,85 à −1,3. Et leurs lèvres, à plat, du plan
	# de la falaise à la lame, à la hauteur de la bande.
	for l in [[2.3, 2.85, 1.7], [4.3, 1.85, 0.7], [6.3, 0.85, -1.3]]:
		var lame := q.filter(func(e): return _meme_boite(_boite_de([e]), [Vector3(l[0], l[2], -0.3), Vector3(l[0], l[1], 1.3)]))
		_vrai(lame.size() == 1 and _couleur_proche(lame[0]["c"], Color(1.0, 0.5, 1.0, 0.05)), "escalier : la lame en x = %s, de %s à %s" % l)
		var levre := q.filter(func(e): return _meme_boite(_boite_de([e]), [Vector3(l[0] - 0.3, l[1], -0.3), Vector3(l[0], l[1], 1.3)]))
		_vrai(levre.size() == 1 and _couleur_proche(levre[0]["c"], Color(1.0, 0.5, 0.5, 0.05)),
			"escalier : la lèvre de la lame en x = %s, de x = %s à la lame, à %s" % [l[0], l[0] - 0.3, l[1]])
	_vrai(_bien_tournes(q), "escalier : faces avant horaires")
	_vrai(_sans_jonction_en_t(EM.maillage([FL.source(esc, Vector3i(0, 3, 0))], esc)),
		"escalier : aucune jonction en T (la lèvre est plus large que la bande qu'elle prolonge)")
	# DEUX RIVIÈRES AU MÊME ENDROIT n'en dessinent qu'une (charte : « une case, une bande »).
	_egal(_quads(EM.maillage([FL.source(esc, Vector3i(0, 3, 0)), FL.source(esc, Vector3i(0, 3, 0))], esc)).size(), 12,
		"escalier : deux fois la même rivière — les mêmes 12 morceaux, rien en double")

	# L'océan autour de l'île, niveau 2 : ses 32 cases de surface fusionnées, et 4 rectangles jusqu'à ±2000.
	var ile := _monde_ile()
	q = _quads(EM.maillage([FL.source(ile, Vector3i(10, 2, 10))], ile))
	_vrai(q.size() > 4 and q.size() < 32 + 4, "océan : moins d'une nappe par case (%d quads pour 32 cases)" % q.size())
	_vrai(_meme_boite(_boite_de(q), [Vector3(-2000, 2.7, -2000), Vector3(2000, 2.7, 2000)]),
		"océan : jusqu'à l'horizon, à 2,7 — %s" % [_boite_de(q)])
	_vrai(_bien_tournes(q), "océan : faces avant horaires")
	_vrai(_sans_jonction_en_t(EM.maillage([FL.source(ile, Vector3i(10, 2, 10))], ile)),
		"océan : aucune jonction en T entre les nappes fusionnées et le large (Jordan : « des bandes fines de vide »)")
	_egal(EM.maillage([FL.source(_monde_cuvette(), Vector3i(0, 0, 0))], {}), null, "un refus : rien à dessiner")

	# SOUS UN ÉTAGE FLOTTANT (Jordan, 3 octobre 2026 : « un mauvais raccord là où l'océan passe une case de gap sous
	# un étage flottant ») : une dalle (0..4, 3, 0..4) sur un pilier (2, 0..2, 2), la mer au niveau 2 ; sous la dalle,
	# la case (1, 2, 1) est de la mer, sous un plafond : la nappe y passe, à 2,7 (la dalle ne se voit qu'à 3,25).
	var dalle := {}
	_boite(dalle, Vector3i(0, 3, 0), Vector3i(4, 3, 4))
	_boite(dalle, Vector3i(2, 0, 2), Vector3i(2, 2, 2))
	var mer := FL.source(dalle, Vector3i(10, 2, 10))
	_egal(mer["genre"], "ocean", "la dalle sur son pilier : une mer au niveau 2")
	q = _quads(EM.maillage([mer], dalle))
	_egal(q.filter(func(e): return _couvre(e, Vector3(1.5, 2.7, 1.5))).size(), 1, "sous la dalle, à 2,7 : la nappe passe")
	_vrai(_sans_jonction_en_t(EM.maillage([mer], dalle)), "sous la dalle : aucune jonction en T")
	# Une galerie noyée PLUS BAS que le niveau, sous un plafond : pas de nappe (l'eau y touche la roche).
	q = _quads(EM.maillage([FL.source(ile, Vector3i(10, 2, 10))], ile))
	_egal(q.filter(func(e): return _couvre(e, Vector3(4.5, 1.7, 3.5))).size(), 0,
		"la galerie de l'île sous le niveau : aucune nappe dans la roche")
	_egal(q.filter(func(e): return _couvre(e, Vector3(4.5, 2.7, 3.5))).size(), 1,
		"la chambre de l'île AU niveau, sous son plafond : la nappe y est")

	# UN SEUL OCÉAN (Jordan, 3 octobre 2026) : deux sources de mer à deux hauteurs — la première l'est, l'autre refusée.
	var w := FL.monde(ile, [Vector3i(10, 2, 10), Vector3i(-8, 0, -8)])
	_egal([w["corps"][0]["genre"], w["corps"][1]["erreur"]], ["ocean", "un_seul_ocean"],
		"deux mers : la première est LA mer, la seconde est refusée")
	_egal((w["ocean"] as Dictionary).size(), 181, "… et l'eau de la mer est celle du niveau 2 seulement")
	w = FL.monde(ile, [Vector3i(-8, 0, -8), Vector3i(10, 2, 10)])
	_egal([w["corps"][0]["niveau"], w["corps"][1]["erreur"]], [0, "un_seul_ocean"], "… dans l'autre ordre, celle du niveau 0")


## LES NAPPES FUSIONNÉES (Jordan, 2 octobre 2026 : « pas un plan par tuile ») — le dessin ne change PAS. L'attendu est
## la règle d'avant, recalculée ICI (hors de `eau_maillage.gd`) : un carré par case de surface, avancé de 0,45 sous
## chaque voisine pleine, à la rangée + 0,7, de la couleur de sa profondeur. On compare point par point, sur une grille
## fine décalée des bords : l'ENSEMBLE des couleurs qui couvrent chaque point doit être le même.
func _nappes_fusionnees() -> void:
	var fond_varie := {}
	for x in range(0, 14):
		for z in range(0, 14):
			_boite(fond_varie, Vector3i(x, 0, z), Vector3i(x, (x * 7 + z * 3) % 4, z))
	_boite(fond_varie, Vector3i(5, 0, 5), Vector3i(8, 6, 8))   # un îlot qui perce
	var cas := [["l'île, niveau 2", _monde_ile(), Vector3i(10, 2, 10)], ["l'île, niveau 1", _monde_ile(), Vector3i(10, 1, 10)],
		["la cuvette", _monde_cuvette(), Vector3i(2, 1, 2)], ["un fond varié", fond_varie, Vector3i(30, 4, 30)]]
	for c in cas:
		var m: Dictionary = c[1]
		var r: Dictionary = FL.source(m, c[2])
		var eau: Dictionary = r["eau"]
		var carres: Array = []
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for k: Vector3i in FL.surface(eau, m):
			var p: int = FL.profondeur(eau, m, k)
			var x0 := k.x - (0.45 if m.has(k + Vector3i(-1, 0, 0)) else 0.0)
			var x1 := k.x + 1 + (0.45 if m.has(k + Vector3i(1, 0, 0)) else 0.0)
			var z0 := k.z - (0.45 if m.has(k + Vector3i(0, 0, -1)) else 0.0)
			var z1 := k.z + 1 + (0.45 if m.has(k + Vector3i(0, 0, 1)) else 0.0)
			carres.append([x0, x1, z0, z1, k.y + 0.7, 1.0 if p < 0 else p / 8.0])
			lo = Vector2(minf(lo.x, x0), minf(lo.y, z0))
			hi = Vector2(maxf(hi.x, x1), maxf(hi.y, z1))
		var rects: Array = EM.rectangles_de_nappe(eau, m)
		var ecarts := 0
		var points := 0
		var x := lo.x - 0.5 + 0.0333
		while x < hi.x + 0.5:
			var z := lo.y - 0.5 + 0.0333
			while z < hi.y + 0.5:
				var attendu := {}
				for q in carres:
					if x > q[0] and x < q[1] and z > q[2] and z < q[3]:
						attendu["%.2f|%.3f" % [q[4], q[5]]] = true
				var lu := {}
				for q in rects:
					if x > q["x0"] and x < q["x1"] and z > q["z0"] and z < q["z1"]:
						lu["%.2f|%.3f" % [q["h"], (q["couleur"] as Color).a]] = true
				points += 1
				if attendu.keys().size() != lu.keys().size() or not attendu.keys().all(func(e): return lu.has(e)):
					ecarts += 1
				z += 0.1
			x += 0.1
		_vrai(ecarts == 0 and carres.size() > 0, "%s : %d carrés → %d rectangles, le même dessin en %d points (%d écarts)"
			% [c[0], carres.size(), rects.size(), points, ecarts])
		_vrai(rects.size() < carres.size() or carres.size() <= 1, "%s : la fusion réduit (%d < %d)" % [c[0], rects.size(), carres.size()])


## LA SURFACE OÙ L'ON NAGE (`niveau_au_point`) : la hauteur DESSINÉE de la nappe (rangée du haut + 0,7).
func _surface_pour_nager() -> void:
	var m := _monde_cuvette()
	var lac: Dictionary = FL.source(m, Vector3i(2, 1, 2))["eau"]
	var b := FL.boite(m)
	_vrai(is_equal_approx(EM.niveau_au_point(lac, [], b, Vector3(2.5, 1.2, 2.5)), 2.7),
		"au fond de la cuvette : la nappe est à 2,7 (rangée 2 + 0,7)")
	_vrai(is_equal_approx(EM.niveau_au_point(lac, [], b, Vector3(1.5, 2.9, 3.5)), 2.7),
		"dans la case du haut, au-dessus de la nappe : 2,7 quand même (c'est l'appelant qui compare)")
	_egal(EM.niveau_au_point(lac, [], b, Vector3(2.5, 3.5, 2.5)), -INF, "au-dessus du lac : pas d'eau")
	_egal(EM.niveau_au_point(lac, [], b, Vector3(0.5, 1.5, 0.5)), -INF, "dans le mur : pas d'eau")
	# Le mur ouest occupe x = 0..1, l'eau commence en x = 1 ; la nappe dessinée s'avance de 0,45 sous le mur.
	_vrai(is_equal_approx(EM.niveau_au_point(lac, [], b, Vector3(0.7, 1.5, 2.5)), 2.7),
		"dans la case du mur, à 0,3 de l'eau : DANS l'eau, comme la nappe dessinée qui s'y avance")
	_egal(EM.niveau_au_point(lac, [], b, Vector3(0.4, 1.5, 2.5)), -INF, "à 0,6 de l'eau, au-delà du débord : dans le mur")
	var ile := _monde_ile()
	var mer: Dictionary = FL.source(ile, Vector3i(10, 2, 10))["eau"]
	var bi := FL.boite(ile)
	_vrai(is_equal_approx(EM.niveau_au_point(mer, [2], bi, Vector3(-30.0, -4.0, 55.0)), 2.7),
		"au large, hors de la boîte du monde : la mer à 2,7")
	_egal(EM.niveau_au_point(mer, [2], bi, Vector3(-30.0, 3.2, 55.0)), -INF, "au large mais au-dessus de la rangée 2 : pas d'eau")
	_vrai(is_equal_approx(EM.niveau_au_point(mer, [2], bi, Vector3(4.5, 1.5, 3.5)), 2.7),
		"dans la galerie noyée : la colonne d'eau monte jusqu'à la rangée 2")
	_egal(EM.niveau_au_point(mer, [2], bi, Vector3(2.5, 1.5, 2.5)), -INF, "dans la cavité close : sèche")
	_egal(EM.niveau_au_point({}, [], {}, Vector3.ZERO), -INF, "sans eau : nulle part")


## Les MORCEAUX d'un maillage — chaque rectangle, lame ou lèvre est un groupe de sommets que ses triangles relient (un
## quad, ou un éventail autour de son centre quand des sommets voisins y sont insérés) : [{"p": ses sommets, "c": la
## couleur du premier, "n": sa normale}].
func _quads(mesh: ArrayMesh) -> Array:
	var q: Array = []
	if mesh == null:
		return q
	var a := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var parent: Array = range(v.size())
	var racine := func(i: int) -> int:
		while parent[i] != i:
			i = parent[i]
		return i
	for t in range(0, idx.size(), 3):
		var r0: int = racine.call(idx[t])
		for k in [1, 2]:
			var rk: int = racine.call(idx[t + k])
			if rk != r0:
				parent[rk] = r0
	var groupes := {}
	for i in v.size():
		var r: int = racine.call(i)
		if not groupes.has(r):
			groupes[r] = []
		groupes[r].append(i)
	for r in groupes:
		var membres: Array = groupes[r]
		var p: Array = []
		for i in membres:
			p.append(v[i])
		q.append({"p": p, "c": (a[Mesh.ARRAY_COLOR] as PackedColorArray)[membres[0]],
			"n": (a[Mesh.ARRAY_NORMAL] as PackedVector3Array)[membres[0]], "mesh": mesh})
	return q


## Le morceau horizontal `e` couvre-t-il le point p (à sa hauteur, strictement dans sa boîte) ?
func _couvre(e: Dictionary, p: Vector3) -> bool:
	var b := _boite_de([e])
	return absf(b[0].y - p.y) < 1e-4 and absf(b[1].y - p.y) < 1e-4 and p.x > b[0].x and p.x < b[1].x \
		and p.z > b[0].z and p.z < b[1].z


## AUCUNE JONCTION EN T : aucun sommet du maillage n'est posé STRICTEMENT à l'intérieur d'une arête d'un triangle (sur
## les faces horizontales, là où les nappes se touchent). Attendu recalculé ici, sur les triangles tels qu'ils sont.
func _sans_jonction_en_t(mesh: ArrayMesh) -> bool:
	var a := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nor: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var points := {}
	for i in v.size():
		if nor[i].y > 0.5:
			points[v[i]] = true
	for t in range(0, idx.size(), 3):
		if nor[idx[t]].y < 0.5:
			continue
		for k in 3:
			var p0: Vector3 = v[idx[t + k]]
			var p1: Vector3 = v[idx[t + (k + 1) % 3]]
			var l := p0.distance_to(p1)
			for p: Vector3 in points:
				if absf(p.y - p0.y) > 1e-4:
					continue
				var u := (p - p0).dot(p1 - p0) / (l * l)
				if u <= 1e-5 or u >= 1.0 - 1e-5:
					continue
				if (p0 + (p1 - p0) * u).distance_to(p) < 1e-3:
					print("    jonction en T : ", p, " sur ", p0, " → ", p1)
					return false
	return true


## [min, max] des sommets. ⚠ PAS ARRONDIS : `snappedf(0,001)` sur un Vector3 (flottants 32 bits) écarte −2000 de
## 1,2·10⁻⁴ — l'arrondi faussait la comparaison qu'il devait rendre sûre.
func _boite_de(q: Array) -> Array:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for e in q:
		for p: Vector3 in e["p"]:
			lo = lo.min(p)
			hi = hi.max(p)
	return [lo, hi]


## ⚠ LES POSITIONS SONT EN FLOTTANTS 32 BITS (2,7 n'y est pas exact) : on compare au dix-millième.
func _meme_boite(a: Array, b: Array) -> bool:
	return (a[0] as Vector3).distance_to(b[0]) < 1e-4 and (a[1] as Vector3).distance_to(b[1]) < 1e-4


## ⚠ LES COULEURS DE SOMMET SONT STOCKÉES SUR 8 BITS (0,25 y devient 64/255) : le contrat de données est
## quantifié au 1/255, et on compare à un demi-pas près.
func _couleur_proche(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.003 and absf(a.g - b.g) < 0.003 and absf(a.b - b.b) < 0.003 and absf(a.a - b.a) < 0.003


## Chaque triangle : produit vectoriel de l'ordre stocké À L'OPPOSÉ de la normale (charte §4).
func _bien_tournes(q: Array) -> bool:
	if q.is_empty():
		return false
	var a: Array = (q[0]["mesh"] as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	for t in range(0, idx.size(), 3):
		var x := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
		if x.dot(nn[idx[t]]) >= 0.0:
			return false
	return true


## LES PRESETS. ⚠ LE COMPILATEUR DE SHADERS NE TOURNE PAS EN HEADLESS : un shader faux ne se voit qu'avec fenêtre
## (`capture_fluides.gd`, qui doit sortir sans une ligne « SHADER ERROR »). Ce qui se garde ici, c'est ce qui se
## lit dans le TEXTE — dont le piège payé deux fois en écrivant les presets : un paramètre de fonction qui porte
## le nom d'un uniforme (« Redefinition of 'ampleur' », puis « 'ecume' »).
func _presets() -> void:
	# LE MICRO (Jordan, 3 octobre 2026 : « une macro mais pas de micro à l'échelle du stickman ») : les presets à
	# normale passent par `normale_eau` (vagues + micro-rides, effacées selon la taille du pixel), le stylisé a ses
	# éclats ; la lave, visqueuse, n'en a pas. Ce qu'ils DONNENT se juge à l'image (Vulkan) : ici, qu'ils y sont.
	for preset in ["transparent", "reflechissant", "marais", "acide"]:
		var code_p: String = EP.code(preset)
		_vrai(code_p.contains("normale_eau(v_monde.xz") and code_p.contains("fwidth(v_monde.xz)")
			and code_p.contains("uniform float micro") and not code_p.contains("normale_vagues(v_monde.xz"),
			"« %s » : la normale porte les micro-rides, effacées au loin" % preset)
	_vrai(EP.code("stylise").contains("float eclat"), "le stylisé a ses éclats")
	_vrai(not EP.code("lave").contains("normale_eau(v_monde"), "la lave, visqueuse, n'a pas de rides")
	var re_uniforme := RegEx.create_from_string("(?m)^\\s*(?:uniform|varying)\\s+\\w+\\s+(\\w+)")
	var re_fonction := RegEx.create_from_string("(?m)^\\w+\\s+(\\w+)\\s*\\(([^)]*)\\)\\s*\\{")
	var codes := {}
	for preset in EP.PRESETS:
		_vrai(EP.NOMS.has(preset), "le preset « %s » a un nom à l'écran" % preset)
		var code: String = EP.code(preset)
		codes[code] = true
		_vrai(code.contains("shader_type spatial") and not code.contains("%COMMUN%") and not code.contains("%CAUSTIQUE%"),
			"« %s » : un shader spatial, marqueurs remplacés" % preset)
		var globaux := {}
		for m in re_uniforme.search_all(code):
			globaux[m.get_string(1)] = true
		var masques: Array = []
		for m in re_fonction.search_all(code):
			for parametre in m.get_string(2).split(",", false):
				var nom: String = parametre.strip_edges().split(" ")[-1]
				if globaux.has(nom):
					masques.append("%s(%s)" % [m.get_string(1), nom])
		_egal(masques, [], "« %s » : aucun paramètre de fonction ne porte le nom d'un uniforme" % preset)
		# Le contrat : chaque preset lit le courant, le genre et la profondeur du terrain.
		_vrai(code.contains("COLOR.rg") and code.contains("COLOR.b") and code.contains("hint_depth_texture"),
			"« %s » lit le contrat (courant, genre) et la profondeur du terrain" % preset)
		# Le clapot soulève TOUT (cascades comprises) : réservé aux nappes, il décollait la lèvre du haut de la lame — un
		# fil sombre le long de chaque cascade (vu à l'image, 3 octobre 2026).
		var vertex: String = code.substr(code.find("void vertex()"), code.find("void fragment()") - code.find("void vertex()"))
		_vrai(vertex.contains("clapot") and not vertex.contains("v_genre <") and not vertex.contains("v_genre >"),
			"« %s » : le clapot ne dépend pas du genre (la lame suit sa lèvre)" % preset)
	_egal(codes.size(), EP.PRESETS.size(), "un shader différent par preset")
	# Les trois liquides du 2 octobre 2026 : présents, exportés sous leur nom anglais, et un voile chacun.
	_egal(EP.PRESETS, ["stylise", "transparent", "reflechissant", "lave", "marais", "acide"], "six liquides")
	var aspects: Array = []
	for preset in EP.PRESETS:
		aspects.append(FMonde.ASPECTS.get(preset, "?"))
	_egal(aspects, ["stylized", "clear", "reflective", "lava", "swamp", "acid"],
		"chaque liquide part dans le .mbworld sous son nom anglais")
	_vrai(EP.code("lave").contains("EMISSION") and EP.code("acide").contains("EMISSION")
		and EP.code("lave").contains("bord_de_cellule"), "la lave et l'acide luisent ; la lave est fendue en cellules")
	_egal(EP.VOILES.keys(), ["lave", "marais", "acide"], "un voile par liquide qui n'est pas de l'eau")
	_vrai(EP.code("transparent").contains("hint_screen_texture") and EP.code("reflechissant").contains("reflet_ecran"),
		"le transparent réfracte l'écran, le réfléchissant y cherche le relief")


## L'EXPORT DU MONDE (étape 4) : l'eau part CUITE dans le `.mbworld` — `world.json` la décrit, un `.glb` par couche
## d'eau porte la nappe et son contrat. Attendus : la nappe relue a les mêmes sommets que celle qu'on a écrite
## (positions en espace du format, couleurs au 1/255 près) ; le lecteur du greffon Godot, qui ne connaît pas
## encore l'eau, lit ce monde sans le refuser.
func _export_du_monde() -> void:
	var ile := _monde_ile()
	var w := FL.monde(ile, [Vector3i(20, 2, 20), Vector3i(3, 4, 3)])
	var nappe := EM.maillage(w["corps"], ile)
	var dossier := "user://test_fluides"
	DirAccess.make_dir_recursive_absolute(dossier)
	var cases: Array = ile.keys()
	var r: Dictionary = FMonde.exporter([{"nom": "Rock", "visible": true, "source": "", "lot": null, "cases": cases}],
		dossier, "ile", "test", [
			{"nom": "Sea & river", "visible": true, "preset": "transparent",
				"sources": [Vector3i(20, 2, 20), Vector3i(3, 4, 3)], "maillage": nappe},
			{"nom": "Empty", "visible": false, "preset": "reflechissant", "sources": [], "maillage": null},
		])
	_vrai(not r.has("erreur") and r["eaux"] == 2 and r["nappes"] == 1, "export : deux couches d'eau, une nappe")
	var texte := FileAccess.get_file_as_string(str(r.get("dossier", "")).path_join("world.json"))
	var monde = JSON.parse_string(texte)
	var lu: Dictionary = FMonde.lire_eau(monde)
	_vrai(not lu.has("error") and lu["water"].size() == 2, "world.json : la clé water se relit")
	if lu.has("water") and lu["water"].size() == 2:
		var a: Dictionary = lu["water"][0]
		_egal([a["name"], a["visible"], a["look"], a["mesh"]], ["Sea & river", true, "clear", "water/sea___river.glb"],
			"la première : nom, visible, aspect en anglais, nappe en chemin RELATIF")
		_egal(a["sources"], [[20, 2, 20], [3, 4, 3]], "ses sources, dans l'ordre où elles ont été posées")
		_egal([lu["water"][1]["mesh"], lu["water"][1]["look"], lu["water"][1]["visible"]], [null, "reflective", false],
			"une couche d'eau sans nappe voyage quand même, sans maillage")
	_vrai(FileAccess.get_file_as_string(str(r.get("dossier", "")).path_join("README.txt")).contains("COLOR_0 b"),
		"le README écrit le contrat de l'eau")
	# Le greffon Godot (qui ne lit pas encore l'eau) ne refuse pas ce monde.
	var lecteur = load("res://addons/marchingblocks_paint/mb_world_file.gd")
	var par_le_greffon: Dictionary = lecteur.read(monde)
	_vrai(not par_le_greffon.has("error") and par_le_greffon["layers"].size() == 1,
		"le lecteur du greffon Godot lit ce monde sans le refuser")
	# La nappe relue.
	var doc := GLTFDocument.new()
	var etat := GLTFState.new()
	var e := doc.append_from_file(str(r.get("dossier", "")).path_join("water/sea___river.glb"), etat)
	_egal(e, OK, "la nappe .glb se relit")
	var relue: Array = []
	for m in etat.get_meshes():
		var im: ImporterMesh = (m as GLTFMesh).mesh
		relue.append(im.get_surface_arrays(0))
	_egal(relue.size(), 1, "un maillage dans la nappe")
	# ⚠ LES NOMS SE LISENT DANS LE JSON DU FICHIER : l'importeur de Godot compose le sien (« nœud_maillage »).
	var j: Dictionary = _json_du_glb(str(r.get("dossier", "")).path_join("water/sea___river.glb"))
	_egal([j["meshes"][0].get("name"), j["materials"][0].get("name")], ["sea___river", "mb_water_clear"],
		"dans le fichier : le maillage nommé (l'importeur d'Unreal en a besoin), le matériau nommé par l'aspect")
	_vrai((j["meshes"][0]["primitives"][0]["attributes"] as Dictionary).has("COLOR_0"), "dans le fichier : COLOR_0")
	if relue.size() == 1:
		var avant := nappe.surface_get_arrays(0)
		var pv: PackedVector3Array = avant[Mesh.ARRAY_VERTEX]
		var pr: PackedVector3Array = relue[0][Mesh.ARRAY_VERTEX]
		var cv: PackedColorArray = avant[Mesh.ARRAY_COLOR]
		var cr = relue[0][Mesh.ARRAY_COLOR]
		_egal(pr.size(), pv.size(), "autant de sommets relus qu'écrits")
		_vrai(cr is PackedColorArray and (cr as PackedColorArray).size() == cv.size(), "les couleurs (le contrat) voyagent")
		# Comparés en ENSEMBLE (l'exporteur peut réordonner) : chaque sommet écrit, avec sa couleur, se retrouve.
		var ecrits := {}
		for i in pv.size():
			ecrits["%s|%s" % [pv[i].snappedf(0.001), _q(cv[i])]] = true
		var manquants := 0
		if cr is PackedColorArray and pr.size() == pv.size():
			for i in pr.size():
				if not ecrits.has("%s|%s" % [pr[i].snappedf(0.001), _q(cr[i])]):
					manquants += 1
		_egal(manquants, 0, "chaque sommet relu est un sommet écrit : même place (espace du format), même contrat")
	# Les refus de la lecture de l'eau.
	for cas in [
		[{"water": 3}, "water n'est pas une liste"],
		[{"water": [{"name": "a", "visible": true, "look": "clear", "mesh": 4, "sources": []}]}, "mesh ni chemin ni null"],
		[{"water": [{"name": "a", "visible": true, "look": "clear", "mesh": null, "sources": [1, 2]}]}, "sources pas en triplets"],
		[{"water": [{"name": "a", "visible": true, "look": "clear", "mesh": null, "sources": [1, 2, 0.5]}]}, "source fractionnaire"],
		[{"water": [{"name": "a", "look": "clear", "mesh": null, "sources": []}]}, "sans visibilité"],
	]:
		_vrai(FMonde.lire_eau(cas[0]).has("error"), "refusé : " + cas[1])
	_vrai(not FMonde.lire_eau({"water": [{"name": "a", "visible": true, "look": "lava", "mesh": null, "sources": []}]}).has("error"),
		"un aspect inconnu est accepté : c'est une suggestion")
	_egal(FMonde.lire_eau({}), {"water": []}, "un monde sans clé water n'a pas d'eau")


## Le bloc JSON d'un .glb (en-tête de 12 octets, puis la longueur du bloc et son type).
func _json_du_glb(chemin: String) -> Dictionary:
	var b := FileAccess.get_file_as_bytes(chemin)
	if b.size() < 20:
		return {"meshes": [{}], "materials": [{}]}
	var n := b.decode_u32(12)
	var j = JSON.parse_string(b.slice(20, 20 + n).get_string_from_utf8())
	return j if j is Dictionary else {"meshes": [{}], "materials": [{}]}


## Une couleur au 1/255 (la précision du contrat).
func _q(c: Color) -> String:
	return "%d,%d,%d,%d" % [roundi(c.r * 255), roundi(c.g * 255), roundi(c.b * 255), roundi(c.a * 255)]


## LE COÛT, mesuré et pas jugé : un monde de 48 × 8 × 48 cases plein, creusé d'un bassin, avec un océan.
func _cout() -> void:
	var m := {}
	_boite(m, Vector3i(0, 0, 0), Vector3i(47, 7, 47))
	_boite(m, Vector3i(10, 4, 10), Vector3i(30, 7, 30), false)
	var t := Time.get_ticks_usec()
	var w := FL.monde(m, [Vector3i(60, 5, 60), Vector3i(20, 5, 20)])
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	print("  coût : océan %d cases + lac %d cases en %.1f ms" % [w["ocean"].size(), w["corps"][1]["eau"].size(), ms])
	_egal(w["corps"][1]["genre"], "lac", "le bassin : un lac")
	_egal(w["corps"][1]["eau"].size(), 21 * 21 * 4, "le bassin : plein jusqu'au bord (21 × 21 × 4)")


# ── outillage ────────────────────────────────────────────────────────────────────────────────────────

func _vrai(v: bool, quoi: String) -> void:
	if v:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ ", quoi)


func _egal(a: Variant, b: Variant, quoi: String) -> void:
	if a == b:
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ %s — obtenu %s, attendu %s" % [quoi, a, b])


func _egal_ens(a: Dictionary, b: Dictionary, quoi: String) -> void:
	var manque: Array = []
	var trop: Array = []
	for c in b:
		if not a.has(c):
			manque.append(c)
	for c in a:
		if not b.has(c):
			trop.append(c)
	if manque.is_empty() and trop.is_empty():
		_ok += 1
	else:
		_echecs += 1
		print("  ✗ %s — manquent %s, en trop %s" % [quoi, manque.slice(0, 8), trop.slice(0, 8)])
