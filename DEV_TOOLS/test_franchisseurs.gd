extends SceneTree
##
## TEST — la règle des FRANCHISSEURS (`addons/marchingblocks_core/franchisseurs.gd`, 20 octobre 2026).
##
## LANCEMENT
##   godot --headless --path . --script res://DEV_TOOLS/test_franchisseurs.gd
##
## Le monde est écrit à la main : un sol de 10 × 10 cases (y = 0, son dessus à y = 1), un PLATEAU d'une case de haut au
## fond (z ∈ [0, 2], y = 1 : son mur regarde vers +z, en z = 2), une case d'OBSTACLE posée devant le mur en (6, 1, 3), et
## une case qui BOUCHE le palier en (7, 2, 2).
## ⚠ LES ATTENDUS SONT ÉCRITS À LA MAIN (les cases, les coins, les aires) : jamais tirés de la règle elle-même.

const FR := preload("res://addons/marchingblocks_core/franchisseurs.gd")
const ME := preload("res://addons/marchingblocks_core/maillage_edite.gd")

var _ok := 0
var _echecs := 0
var _plein := {}


func _initialize() -> void:
	print("=== TEST — la règle des franchisseurs ===\n")
	for x in 10:
		for z in 10:
			_plein[Vector3i(x, 0, z)] = true
		for z in 3:
			_plein[Vector3i(x, 1, z)] = true
	_plein[Vector3i(6, 1, 3)] = true
	_plein[Vector3i(7, 2, 2)] = true
	var plein := func(c: Vector3i) -> bool: return _plein.has(c)

	print("— le test de pose")
	var esc := FR.modele(1, "Stairs", "escalier")
	_raison(esc, Vector3i(4, 1, 3), 0, plein, {}, "", "au pied du mur, en montant vers lui : posé")
	_raison(esc, Vector3i(4, 1, 3), 2, plein, {}, "pas_de_mur", "tourné vers le large : aucun mur à franchir")
	_raison(esc, Vector3i(4, 1, 5), 0, plein, {}, "pas_de_mur", "trop loin du mur pour une longueur d'une case")
	var long := FR.modele(2, "Long stairs", "escalier", 1, 1, 3)
	_raison(long, Vector3i(4, 1, 5), 0, plein, {}, "", "… mais une rampe de trois cases y arrive")
	var haut := FR.modele(3, "Tall stairs", "escalier", 1, 2, 2)
	_raison(haut, Vector3i(4, 1, 4), 0, plein, {}, "pas_de_mur", "un mur d'une case pour un escalier de deux : refusé")
	_raison(esc, Vector3i(6, 1, 3), 0, plein, {}, "encombre", "une case pleine sur la rampe : encombré")
	_raison(esc, Vector3i(4, 2, 3), 0, plein, {}, "pas_de_sol", "en l'air : rien sous le pied")
	_raison(esc, Vector3i(7, 1, 3), 0, plein, {}, "pas_de_palier", "le haut du mur bouché : pas de palier")
	var large := FR.modele(4, "Wide stairs", "escalier", 2)
	_raison(large, Vector3i(2, 1, 3), 0, plein, {}, "", "deux cases de large, x = 2 et 3 : posé")
	_raison(large, Vector3i(5, 1, 3), 0, plein, {}, "encombre", "deux cases de large dont la seconde sur l'obstacle")
	var modeles := {1: esc, 4: large}
	var deja := [FR.pose(10, 1, Vector3i(4, 1, 3), 0)]
	var prises := FR.prises_de(modeles, deja)
	_raison(esc, Vector3i(4, 1, 3), 0, plein, prises, "deja_pris", "la même case qu'une autre pose : déjà prise")
	_raison(large, Vector3i(3, 1, 3), 0, plein, prises, "deja_pris", "large, sa seconde case sur la pose voisine")
	var p := FR.pose(10, 1, Vector3i(4, 1, 3), 0)
	_vrai(FR.verifier(esc, p, plein, prises) == "", "une pose ne se gêne pas elle-même (même id)")
	var pente := FR.modele(5, "Slope", "pente", 1, 1, 2)
	_raison(pente, Vector3i(1, 1, 4), 0, plein, {}, "", "une pente de deux cases au pied du mur : posée")

	print("\n— l'orientation")
	_vrai(FR.orienter(esc, Vector3i(4, 1, 3), plein, {}, 2) == 0, "visée au pied du mur, elle monte vers lui (quart 0)")
	_vrai(FR.orienter(esc, Vector3i(4, 1, 6), plein) == -1, "loin de tout mur : aucun quart ne convient")
	_vrai(FR.droite(0) == Vector3i(1, 0, 0) and FR.droite(1) == Vector3i(0, 0, 1), "la droite en montant (quarts 0 et 1)")

	print("\n— la transformation (repère du modèle → cases)")
	var t0 := FR.transformation(esc, FR.pose(-1, 1, Vector3i(4, 1, 3), 0))
	_proche(t0 * Vector3(0, 0, 0), Vector3(4, 1, 4), "quart 0 : le pied gauche au coin (4, 1, 4)")
	_proche(t0 * Vector3(1, 1, -1), Vector3(5, 2, 3), "… le haut droit au coin (5, 2, 3)")
	var t1 := FR.transformation(long, FR.pose(-1, 2, Vector3i(2, 1, 5), 1))
	_proche(t1 * Vector3(0, 0, 0), Vector3(2, 1, 5), "quart 1 (montée vers +x) : le pied gauche au coin (2, 1, 5)")
	_proche(t1 * Vector3(0, 1, -3), Vector3(5, 2, 5), "… le haut gauche, trois cases plus loin, au coin (5, 2, 5)")

	print("\n— les maillages de départ")
	_maillage(FR.maillage_de_depart(esc), 1.0 * 2.0 / 3.0, "l'escalier d'une case (trois marches)")
	_maillage(FR.maillage_de_depart(pente), 1.0 * 1.0 * 2.0 / 2.0, "la pente de deux cases")
	_maillage(FR.maillage_de_depart(large), 2.0 * 2.0 / 3.0, "l'escalier de deux cases de large")
	var me: RefCounted = FR.maillage_de_depart(esc)
	var aller: Dictionary = me.vers_dictionnaire()
	var retour: RefCounted = ME.depuis_dictionnaire(aller)
	_vrai(retour != null and retour.faces.size() == me.faces.size() and retour.sommets.size() == me.sommets.size(),
		"il s'enregistre et se relit (.mbmesh)")
	var am: ArrayMesh = me.vers_array_mesh()
	_vrai(am != null and am.get_surface_count() > 0, "il se convertit en maillage Godot")

	print("\n— le projet")
	var esc_s := FR.modele(1, "Stairs", "escalier")
	esc_s["maillage"] = FR.maillage_de_depart(esc_s).vers_dictionnaire()
	var d := FR.vers_donnees([esc_s, pente], [FR.pose(1, 1, Vector3i(4, 1, 3), 0), FR.pose(2, 5, Vector3i(1, 1, 4), 3)])
	var err: Array = []
	var relu := FR.depuis_donnees(JSON.parse_string(JSON.stringify(d)), err)
	_vrai(err.is_empty() and (relu["modeles"] as Array).size() == 2 and (relu["poses"] as Array).size() == 2,
		"modèles et poses passent par le JSON du projet et reviennent")
	_vrai(relu["poses"][1]["bas"] == Vector3i(1, 1, 4) and relu["poses"][1]["quart"] == 3 and relu["poses"][1]["modele"] == 5,
		"… la seconde pose avec sa case, son quart et son modèle")
	_vrai(ME.depuis_dictionnaire(relu["modeles"][0]["maillage"]).faces.size() == FR.maillage_de_depart(esc).faces.size(),
		"… et le maillage sculpté du modèle")
	_vrai(FR.vers_donnees([], []).is_empty(), "sans modèle, rien à écrire (le projet n'a pas la clé)")
	var vide := FR.depuis_donnees(null, err)
	_vrai((vide["modeles"] as Array).is_empty(), "un projet d'avant (sans la clé) se lit sans franchisseur")
	var err2: Array = []
	_vrai(FR.depuis_donnees({"modeles": [{"id": 1, "genre": "ascenseur"}], "poses": []}, err2).is_empty() and not err2.is_empty(),
		"un genre inconnu refuse le tout, et le dit")
	var err3: Array = []
	_vrai(FR.depuis_donnees({"modeles": [esc_s], "poses": [9, 0, 0, 0, 0]}, err3).is_empty() and not err3.is_empty(),
		"une pose d'un modèle absent refuse le tout, et le dit")

	print("\n%d vérifications, %d échec(s)" % [_ok + _echecs, _echecs])
	print("VERDICT : %s" % ("ÉCHEC" if _echecs > 0 else "OK"))
	quit(1 if _echecs > 0 else 0)


func _raison(m: Dictionary, bas: Vector3i, quart: int, plein: Callable, prises: Dictionary, attendu: String,
		quoi: String) -> void:
	var r := FR.verifier(m, FR.pose(-1, int(m["id"]), bas, quart), plein, prises)
	_vrai(r == attendu, "%s (« %s »)" % [quoi, r])


## Fermé (chaque arête dans exactement deux faces, en sens opposés) et tourné vers l'extérieur (volume signé > 0, égal
## à la largeur × l'aire du profil, calculée à la main).
func _maillage(me: RefCounted, volume_attendu: float, quoi: String) -> void:
	var aretes := {}
	var volume := 0.0
	for f in me.faces:
		var n: int = (f as PackedInt32Array).size()
		for k in n:
			var a: int = f[k]
			var b: int = f[(k + 1) % n]
			var cle := Vector2i(a, b)
			aretes[cle] = int(aretes.get(cle, 0)) + 1
		var p0: Vector3 = me.sommets[f[0]]
		for k in range(1, n - 1):
			volume += p0.dot((me.sommets[f[k]] as Vector3).cross(me.sommets[f[k + 1]])) / 6.0
	var ferme := true
	for cle in aretes:
		if aretes[cle] != 1 or not aretes.has(Vector2i(cle.y, cle.x)):
			ferme = false
	_vrai(ferme, "%s : fermé, chaque arête parcourue une fois dans chaque sens" % quoi)
	_vrai(absf(volume - volume_attendu) < 1e-4, "%s : tourné vers l'extérieur, volume %.4f (attendu %.4f)" % [quoi,
		volume, volume_attendu])


func _proche(a: Vector3, b: Vector3, quoi: String) -> void:
	_vrai(a.distance_to(b) < 1e-4, "%s (%s)" % [quoi, a])


func _vrai(v: bool, quoi: String) -> void:
	if v:
		_ok += 1
		print("  ✓ %s" % quoi)
	else:
		_echecs += 1
		print("  ÉCHEC — %s" % quoi)
