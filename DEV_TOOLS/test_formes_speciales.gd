extends SceneTree
##
## TEST — les formes spéciales (`addons/marchingblocks_core/formes_speciales.gd`) : tunnel, puits, pont,
## balcon, d'un clic ou en reliant deux ancres, parois diagonales comprises.
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/test_formes_speciales.gd
##
## ⚠ **LES ATTENDUS NE VIENNENT PAS DE LA FONCTION ÉPROUVÉE** (charte §6) : les cas droits sont déroulés à
## la main dans leur commentaire ; les autres sont jugés par des autorités qui n'en dépendent pas — un
## PARCOURS du vide (l'embouchure est-elle ouverte de bout en bout ?), `MB.contacts_par_arete` (aucun
## damier de plus), et la distance de chaque case à la droite voulue.

const FS := preload("res://addons/marchingblocks_core/formes_speciales.gd")
const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")

var _ok := 0
var _echecs := 0


func _initialize() -> void:
	print("=== TEST — les formes spéciales ===\n")
	_normales()
	_tunnel_droit()
	_puits()
	_pont()
	_pont_en_coude()
	_relier_droit()
	_paroi_diagonale()
	_coude()
	_balcon()
	_erreurs()
	_reparation()
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


static func _apres(occ: Dictionary, r: Dictionary) -> Dictionary:
	var d := occ.duplicate()
	for c in r["effacer"]:
		d.erase(c)
	for c in r["poser"]:
		d[c] = true
	return d


## Le vide relie-t-il `de` à `vers` (par les faces), dans la boîte [bas, haut] ?
static func _relies(occ: Dictionary, de: Vector3i, vers: Vector3i, bas: Vector3i, haut: Vector3i) -> bool:
	if occ.has(de) or occ.has(vers):
		return false
	var vus := {de: true}
	var file: Array = [de]
	while not file.is_empty():
		var c: Vector3i = file.pop_back()
		if c == vers:
			return true
		for f in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0),
				Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var v: Vector3i = c + f
			if vus.has(v) or occ.has(v):
				continue
			if v.x < bas.x or v.y < bas.y or v.z < bas.z or v.x > haut.x or v.y > haut.y or v.z > haut.z:
				continue
			vus[v] = true
			file.append(v)
	return false


static func _liste(cases_: Array) -> Dictionary:
	var d := {}
	for c in cases_:
		d[c] = true
	return d


# ── 1. la normale d'une paroi ────────────────────────────────────────────────────────────────────────

func _normales() -> void:
	print("── la normale")
	var plat := {}
	_boite(plat, Vector3i(-3, 0, -4), Vector3i(0, 4, 4))
	_egal(FS.normale_estimee(plat, Vector3i(0, 2, 0), Vector3i(1, 0, 0)), Vector3i(1, 0, 0),
		"une paroi droite rend sa face")
	# L'escalier à 45° : pleines les cases x + z ≤ 0. Chaque case du bord (x + z = 0) expose +X ET +Z ;
	# dans la fenêtre 3³ autour de (0,2,0) il y en a autant de chaque : la somme est (k, 0, k).
	var escalier := {}
	for x in range(-6, 7):
		for z in range(-6, 7):
			if x + z <= 0:
				_boite(escalier, Vector3i(x, 0, z), Vector3i(x, 4, z))
	_egal(FS.normale_estimee(escalier, Vector3i(0, 2, 0), Vector3i(1, 0, 0)), Vector3i(1, 0, 1),
		"un escalier à 45° rend la diagonale (1, 0, 1), cliqué sur sa face +X")
	_egal(FS.normale_estimee(escalier, Vector3i(0, 2, 0), Vector3i(0, 0, 1)), Vector3i(1, 0, 1),
		"… et cliqué sur sa face +Z")
	# Une paroi diagonale MINCE (−1 ≤ x + z ≤ 0). Dans la fenêtre : x + z = 0 → 3 cases par étage, +X et +Z ;
	# x + z = −1 → 2 cases, −X et −Z. Somme (9 − 6, 0, 9 − 6) = (3, 0, 3) → la diagonale. ⚠ Écarter les
	# faces de dos (−X) mais pas les perpendiculaires (−Z) rendait (9, 0, 3) → (1, 0, 0).
	var mince := {}
	for x in range(-6, 7):
		for z in range(-6, 7):
			if x + z <= 0 and x + z >= -1:
				_boite(mince, Vector3i(x, 0, z), Vector3i(x, 4, z))
	_egal(FS.normale_estimee(mince, Vector3i(0, 2, 0), Vector3i(1, 0, 0)), Vector3i(1, 0, 1),
		"une paroi diagonale de deux cases d'épaisseur rend aussi la diagonale")
	_egal(FS.normale_estimee(plat, Vector3i(-3, 2, 0), Vector3i(-1, 0, 0)), Vector3i(-1, 0, 0),
		"l'autre côté d'une paroi droite rend sa face")
	_egal(FS.normale_de("puits", plat, Vector3i(0, 4, 0), Vector3i(0, 1, 0)), Vector3i(0, 1, 0),
		"le puits prend la face d'un sol telle quelle")
	_egal(FS.normale_de("puits", plat, Vector3i(0, 2, 0), Vector3i(1, 0, 0)), Vector3i.ZERO,
		"le puits refuse une paroi")
	_egal(FS.normale_de("tunnel", plat, Vector3i(0, 4, 0), Vector3i(0, 1, 0)), Vector3i.ZERO,
		"le tunnel refuse un sol")


# ── 2. le tunnel droit ───────────────────────────────────────────────────────────────────────────────
#
# Un mur de 3 d'épaisseur (x = 0..2), de l'air des deux côtés. A = (0,3,0), face −X : on creuse vers +X.
# La marche : (1,3,0) plein, (2,3,0) plein, (3,3,0) VIDE → le conduit va de A à (3,3,0), il débouche.
# Segment D = (3,0,0) : u = (0,0,3), v = (0,9,0), t = 3·dx ∈ [0, 9] → dx ∈ 0..3.
#   rond, taille 2 (h = 1) : dz² + dy² ≤ 1 → une croix de 5 cases par tranche ;
#   arche : au-dessus de l'axe le rond, dessous le carré → dy = −1 et 0 : dz ∈ −1..1, dy = 1 : dz = 0 → 7 ;
#   carré : 9.
# Seules les tranches x = 0..2 sont de la roche : 15, 21 et 27 cases creusées.

func _mur() -> Dictionary:
	var d := {}
	_boite(d, Vector3i(0, 0, -4), Vector3i(2, 6, 4))
	return d


func _croix(x0: int, x1: int, y: int, profil: String) -> Dictionary:
	var d := {}
	for x in range(x0, x1 + 1):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				var garde := false
				match profil:
					"rond":
						garde = dy * dy + dz * dz <= 1
					"arche":
						garde = dy <= 0 or dz == 0
					"carre":
						garde = true
				if garde:
					d[Vector3i(x, y + dy, dz)] = true
	return d


func _tunnel_droit() -> void:
	print("── le tunnel droit")
	var mur := _mur()
	for p in [["rond", 15], ["arche", 21], ["carre", 27]]:
		var r: Dictionary = FS.forme(mur, {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0),
			"relier": false, "profil": p[0], "taille": 2, "longueur": 8})
		_egal(r["erreur"], "", "tunnel %s : pas d'erreur" % p[0])
		_egal_ens(r["effacer"], _croix(0, 2, 3, p[0]), "tunnel %s : les %d cases déroulées à la main" % [p[0], p[1]])
		_vrai(r["poser"].is_empty(), "tunnel %s : ne pose rien" % p[0])
		_vrai(r["ouvert"], "tunnel %s : la marche a débouché" % p[0])
		_egal(r["reparees"], 0, "tunnel %s : aucun damier à réparer sur un conduit droit" % p[0])
		_vrai(_relies(_apres(mur, r), Vector3i(-1, 3, 0), Vector3i(3, 3, 0), Vector3i(-1, 0, -4),
			Vector3i(3, 6, 4)), "tunnel %s : les deux côtés du mur sont reliés" % p[0])
	# Aveugle : un mur de 30, longueur 4 → A et quatre cases derrière, rien de plus.
	var epais := {}
	_boite(epais, Vector3i(0, 0, -2), Vector3i(29, 6, 2))
	var r2: Dictionary = FS.forme(epais, {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0),
		"relier": false, "profil": "rond", "taille": 1, "longueur": 4})
	_egal_ens(r2["effacer"], _liste([Vector3i(0, 3, 0), Vector3i(1, 3, 0), Vector3i(2, 3, 0), Vector3i(3, 3, 0),
		Vector3i(4, 3, 0)]), "un tunnel aveugle de taille 1 et de longueur 4 : cinq cases en ligne")
	_vrai(not r2["ouvert"], "… et il le dit : il n'a pas débouché")


# ── 3. le puits ──────────────────────────────────────────────────────────────────────────────────────

func _puits() -> void:
	print("── le puits")
	var sol := {}
	_boite(sol, Vector3i(-3, 0, -3), Vector3i(3, 9, 3))
	# Aveugle, taille 1, longueur 4 : de (0,9,0) vers le bas, (0,5..9,0).
	var r: Dictionary = FS.forme(sol, {"quoi": "puits", "a": Vector3i(0, 9, 0), "face_a": Vector3i(0, 1, 0),
		"relier": false, "profil": "rond", "taille": 1, "longueur": 4})
	_egal_ens(r["effacer"], _liste([Vector3i(0, 5, 0), Vector3i(0, 6, 0), Vector3i(0, 7, 0), Vector3i(0, 8, 0),
		Vector3i(0, 9, 0)]), "un puits aveugle de longueur 4 : cinq cases sous le sol")
	# Une grotte dessous (y = 1..3) : la marche s'arrête au premier vide, (0,3,0).
	var grotte := sol.duplicate()
	_boite(grotte, Vector3i(-2, 1, -2), Vector3i(2, 3, 2), false)
	r = FS.forme(grotte, {"quoi": "puits", "a": Vector3i(0, 9, 0), "face_a": Vector3i(0, 1, 0),
		"relier": false, "profil": "rond", "taille": 1, "longueur": 20})
	_egal_ens(r["effacer"], _liste([Vector3i(0, 4, 0), Vector3i(0, 5, 0), Vector3i(0, 6, 0), Vector3i(0, 7, 0),
		Vector3i(0, 8, 0), Vector3i(0, 9, 0)]), "un puits qui trouve une grotte s'y arrête")
	_vrai(r["ouvert"], "… et il a débouché")
	_vrai(_relies(_apres(grotte, r), Vector3i(0, 10, 0), Vector3i(0, 2, 0), Vector3i(-3, 0, -3),
		Vector3i(3, 10, 3)), "le dessus et la grotte sont reliés")
	# Taille 3 dans la grotte : le puits rond de rayon 2 relie, sans aucun damier de plus.
	r = FS.forme(grotte, {"quoi": "puits", "a": Vector3i(0, 9, 0), "face_a": Vector3i(0, 1, 0),
		"relier": false, "profil": "rond", "taille": 3, "longueur": 20})
	var apres := _apres(grotte, r)
	_vrai(MB.contacts_par_arete(apres) <= MB.contacts_par_arete(grotte), "un puits de taille 3 ne crée aucun damier")
	_vrai(_relies(apres, Vector3i(1, 10, 1), Vector3i(1, 2, 1), Vector3i(-3, 0, -3), Vector3i(3, 10, 3)),
		"… et relie le dessus à la grotte")


# ── 4. le pont ───────────────────────────────────────────────────────────────────────────────────────
#
# Deux parois face à face : x = −3..0 et x = 6..8. A = (0,3,0), face +X ; on remplit vers +X jusqu'à la
# première matière, (6,3,0). D = (6,0,0) : u = (0,0,6), v = (0,36,0) ; tablier taille 2 (h = 1) :
# 36·dz² ≤ 36 → |dz| ≤ 1, 4·1296·dy² ≤ 1296 → dy = 0. Posées : x = 1..5, y = 3, z = −1..1 → 15.
# Garde-corps : la rangée dy = 1, aux bords |dz| = 1 (le milieu dz = 0 est le passage) → +10.

func _gorge() -> Dictionary:
	var d := {}
	_boite(d, Vector3i(-3, 0, -3), Vector3i(0, 5, 3))
	_boite(d, Vector3i(6, 0, -3), Vector3i(8, 5, 3))
	return d


func _pont() -> void:
	print("── le pont")
	var gorge := _gorge()
	var r: Dictionary = FS.forme(gorge, {"quoi": "pont", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0),
		"relier": false, "taille": 2, "longueur": 10})
	var attendu := {}
	_boite(attendu, Vector3i(1, 3, -1), Vector3i(5, 3, 1))
	_egal_ens(r["poser"], attendu, "un pont de taille 2 : le tablier de 5 × 3 déroulé à la main")
	_vrai(r["effacer"].is_empty(), "un pont n'efface rien")
	r = FS.forme(gorge, {"quoi": "pont", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0),
		"relier": false, "taille": 2, "longueur": 10, "garde_corps": true})
	_boite(attendu, Vector3i(1, 4, -1), Vector3i(5, 4, -1))
	_boite(attendu, Vector3i(1, 4, 1), Vector3i(5, 4, 1))
	_egal_ens(r["poser"], attendu, "avec garde-corps : les deux rebords, pas le passage")
	r = FS.forme(gorge, {"quoi": "pont", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0),
		"relier": false, "taille": 2, "longueur": 4})
	_egal(r["erreur"], "rien_en_face", "un pont qui ne trouve rien en face dans sa portée est refusé")
	# Relier deux ancres à des hauteurs différentes : le tablier monte, et reste d'un seul tenant.
	r = FS.forme(gorge, {"quoi": "pont", "a": Vector3i(0, 1, 0), "face_a": Vector3i(1, 0, 0),
		"relier": true, "b": Vector3i(6, 4, 2), "face_b": Vector3i(-1, 0, 0), "taille": 2})
	var apres := _apres(gorge, r)
	_vrai(MB.contacts_par_arete(apres) <= MB.contacts_par_arete(gorge), "un pont en pente ne laisse aucun damier")
	_vrai(_composante(apres, Vector3i(1, 1, 0)).has(Vector3i(5, 4, 2)),
		"un pont en pente relie ses deux bouts par la matière")


## La matière reliée à `de` par les faces.
static func _composante(occ: Dictionary, de: Vector3i) -> Dictionary:
	var vus := {de: true}
	var file: Array = [de]
	while not file.is_empty():
		var c: Vector3i = file.pop_back()
		for f in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0),
				Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var v: Vector3i = c + f
			if occ.has(v) and not vus.has(v):
				vus[v] = true
				file.append(v)
	return vus


# ── 5. relier deux ancres face à face ────────────────────────────────────────────────────────────────
#
# Le même mur, A = (0,3,0) face −X, B = (2,3,0) face +X. Jambes voulues : 2 ; mais chacune est bridée au
# tiers du trajet (3·k·2 ≤ 4 → k = 0) : le chemin est A → B, D = (2,0,0), t ∈ [0,4] → dx ∈ 0..2. La même
# croix que le tunnel droit, sans la tranche x = 3 (de l'air de toute façon).

func _relier_droit() -> void:
	print("── relier deux ancres face à face")
	var mur := _mur()
	var r: Dictionary = FS.forme(mur, {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0),
		"relier": true, "b": Vector3i(2, 3, 0), "face_b": Vector3i(1, 0, 0), "profil": "rond", "taille": 2})
	_egal_ens(r["effacer"], _croix(0, 2, 3, "rond"), "deux ancres face à face : un conduit droit, la croix")
	# L'EMBOUCHURE NE CREUSE PAS LA SALLE. Le mur de 3 posé sur un sol qui le déborde des deux côtés
	# (y = 0, x = −4..6). A = (0,1,0) face −X, B = (2,1,0) face +X, carré de taille 2 : on creuse x = 0..2,
	# y = 0..2, z = −1..1 — le pied du mur compris —, et RIEN du sol des salles (x = −1 ou x = 3).
	var sol := _mur()
	_boite(sol, Vector3i(-4, 0, -4), Vector3i(6, 0, 4))
	var attendu := {}
	_boite(attendu, Vector3i(0, 0, -1), Vector3i(2, 2, 1))
	for relier in [true, false]:
		r = FS.forme(sol, {"quoi": "tunnel", "a": Vector3i(0, 1, 0), "face_a": Vector3i(-1, 0, 0),
			"relier": relier, "b": Vector3i(2, 1, 0), "face_b": Vector3i(1, 0, 0), "profil": "carre", "taille": 2,
			"longueur": 8})
		# ⚠ En un clic, le conduit finissait sur la première case VIDE, (3,1,0) : sa tranche creusait une rigole
		# dans le sol de la salle d'en face. Il finit désormais sur la paroi, (2,1,0) — comme deux ancres.
		_egal_ens(r["effacer"], attendu, "%s : le conduit, et pas une case du sol des deux salles"
			% ("deux ancres" if relier else "un clic"))


# ── 6. la paroi diagonale ────────────────────────────────────────────────────────────────────────────
#
# Une dalle en biais : pleines les cases −8 ≤ x + z ≤ 0, y = 0..6. A = (0,3,0), cliquée sur +X : la
# normale estimée est (1,0,1), donc on creuse vers (−1,0,−1), et la marche débouche en x + z = −10.

func _paroi_diagonale() -> void:
	print("── la paroi diagonale")
	var dalle := {}
	for x in range(-14, 9):
		for z in range(-14, 9):
			if x + z <= 0 and x + z >= -8:
				_boite(dalle, Vector3i(x, 0, z), Vector3i(x, 6, z))
	var r: Dictionary = FS.forme(dalle, {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0),
		"relier": false, "profil": "rond", "taille": 2, "longueur": 12})
	_egal(r["erreur"], "", "tunnel dans une paroi diagonale : pas d'erreur")
	_vrai(r["ouvert"], "… il traverse la dalle")
	var apres := _apres(dalle, r)
	_vrai(_relies(apres, Vector3i(1, 3, 1), Vector3i(-6, 3, -6), Vector3i(-14, 0, -14), Vector3i(8, 6, 8)),
		"… et relie les deux côtés")
	_vrai(MB.contacts_par_arete(apres) <= MB.contacts_par_arete(dalle), "… sans aucun damier de plus")
	# Il suit la DIAGONALE : chaque case creusée est à moins de 2,5 cases (au carré : |x − z|² / 2 ≤ 6,25)
	# de la droite x = z, et à moins de 2,5 du plan y = 3.
	var loin := 0
	for c in r["effacer"]:
		var q: Vector3i = c
		if (q.x - q.z) * (q.x - q.z) > 12 or absi(q.y - 3) > 2:
			loin += 1
	_egal(loin, 0, "… et chacune de ses cases est près de la diagonale, pas d'un axe")
	# Un mur droit, cliqué au même endroit, aurait creusé le long de X : la diagonale est bien une décision.
	_vrai(r["effacer"].has(Vector3i(-2, 3, -2)), "la case (−2,3,−2), sur la diagonale, est creusée")


# ── 7. le coude : deux salles qui ne sont pas en face ────────────────────────────────────────────────

func _coude() -> void:
	print("── le coude")
	# Un massif, deux salles : l'une à l'ouest (x = 1..3), l'autre au nord-est (z = 12..14), décalées.
	var m := {}
	_boite(m, Vector3i(0, 0, 0), Vector3i(16, 8, 16))
	_boite(m, Vector3i(1, 1, 1), Vector3i(3, 4, 5), false)
	_boite(m, Vector3i(10, 3, 12), Vector3i(14, 6, 14), false)
	# A : la paroi est de la première salle, (4,2,3), face −X ; B : la paroi sud de la seconde, (12,4,11),
	# face +Z… vue de la salle, le mur est en z = 11 et regarde vers −Z.
	var r: Dictionary = FS.forme(m, {"quoi": "tunnel", "a": Vector3i(4, 2, 3), "face_a": Vector3i(-1, 0, 0),
		"relier": true, "b": Vector3i(12, 4, 11), "face_b": Vector3i(0, 0, 1), "profil": "arche", "taille": 2})
	_egal(r["erreur"], "", "un coude entre deux salles : pas d'erreur")
	var apres := _apres(m, r)
	_vrai(_relies(apres, Vector3i(2, 2, 3), Vector3i(12, 4, 13), Vector3i(0, 0, 0), Vector3i(16, 8, 16)),
		"… et les deux salles sont reliées, embouchures ouvertes")
	_vrai(MB.contacts_par_arete(apres) <= MB.contacts_par_arete(m), "… sans aucun damier de plus")
	# L'embouchure est PERPENDICULAIRE : les trois cases devant A, le long de +X, sont creusées.
	_vrai(r["effacer"].has(Vector3i(4, 2, 3)) and r["effacer"].has(Vector3i(5, 2, 3)) \
		and r["effacer"].has(Vector3i(6, 2, 3)), "la jambe de A part perpendiculaire à sa paroi (+X)")
	_vrai(r["effacer"].has(Vector3i(12, 4, 11)) and r["effacer"].has(Vector3i(12, 4, 10)) \
		and r["effacer"].has(Vector3i(12, 4, 9)), "la jambe de B part perpendiculaire à sa paroi (−Z)")
	# Rien n'est creusé du côté des salles derrière les ancres (le prisme ne déborde pas d'une embouchure).
	_vrai(not r["effacer"].has(Vector3i(0, 2, 3)), "le mur ouest de la première salle est intact")
	# LE COUDE N'EST PAS ENTAILLÉ : la jambe de A va jusqu'à (6,2,3) — voulu 2, et 3·2·8 = 48 ≤ |B − A|² = 132.
	# Avec un profil carré de demi-côté 1, le prisme PROLONGÉ au joint couvre tout le cube 3³ autour de lui.
	r = FS.forme(m, {"quoi": "tunnel", "a": Vector3i(4, 2, 3), "face_a": Vector3i(-1, 0, 0),
		"relier": true, "b": Vector3i(12, 4, 11), "face_b": Vector3i(0, 0, 1), "profil": "carre", "taille": 2})
	var cube := {}
	_boite(cube, Vector3i(5, 1, 2), Vector3i(7, 3, 4))
	var manque := 0
	for c in cube:
		if not r["effacer"].has(c):
			manque += 1
	_egal(manque, 0, "au coude, le cube 3³ autour du joint (6,2,3) est creusé en entier")


## LE GARDE-CORPS NE BARRE PAS UN COUDE : un pont qui relie deux parois en équerre ; au-dessus de l'axe du
## tablier (la rangée où l'on marche), aucune case posée.
func _pont_en_coude() -> void:
	print("── le pont en coude")
	var d := {}
	_boite(d, Vector3i(-3, 0, -3), Vector3i(0, 5, 10))   # paroi ouest, regarde +X
	_boite(d, Vector3i(-3, 0, 11), Vector3i(12, 5, 13))  # paroi nord, regarde −Z
	var r: Dictionary = FS.forme(d, {"quoi": "pont", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0),
		"relier": true, "b": Vector3i(9, 3, 11), "face_b": Vector3i(0, 0, -1), "taille": 3, "garde_corps": true})
	_egal(r["erreur"], "", "un pont en coude avec garde-corps : pas d'erreur")
	# L'axe : de (0,3,0) à sa jambe (3,3,0), puis à (9,3,8), puis à (9,3,11) — à plat, y = 3.
	var barre := 0
	for p in [[Vector3i(0, 3, 0), Vector3i(3, 3, 0)], [Vector3i(3, 3, 0), Vector3i(9, 3, 8)],
			[Vector3i(9, 3, 8), Vector3i(9, 3, 11)]]:
		for c in FS.traverser(p[0], p[1]):
			if r["poser"].has((c as Vector3i) + Vector3i.UP):
				barre += 1
	_egal(barre, 0, "rien n'est posé au-dessus de l'axe du tablier : le rebord d'une jambe ne barre pas le coude")
	var rebords := 0
	for c in r["poser"]:
		if (c as Vector3i).y == 4:
			rebords += 1
	_vrai(rebords > 10, "… et il a bien des rebords (%d cases)" % rebords)


# ── 8. le balcon ─────────────────────────────────────────────────────────────────────────────────────
#
# La paroi x ≤ 0, A = (0,3,0) face +X, profondeur 3, taille 2 (h = 1) : x = 1..3, y = 3, z = −1..1 → 9.
# Garde-corps : la rangée y = 4 hors du dedans (x = 1..2, z = 0) → x = 3 (3 cases) et x = 1..2, z = ±1
# (4 cases) → 7.

func _balcon() -> void:
	print("── le balcon")
	var plat := {}
	_boite(plat, Vector3i(-3, 0, -4), Vector3i(0, 6, 4))
	var r: Dictionary = FS.forme(plat, {"quoi": "balcon", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0),
		"taille": 2, "longueur": 3})
	var attendu := {}
	_boite(attendu, Vector3i(1, 3, -1), Vector3i(3, 3, 1))
	_egal_ens(r["poser"], attendu, "un balcon 3 × 3 : la dalle déroulée à la main")
	r = FS.forme(plat, {"quoi": "balcon", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0),
		"taille": 2, "longueur": 3, "garde_corps": true})
	_boite(attendu, Vector3i(3, 4, -1), Vector3i(3, 4, 1))
	for c in [Vector3i(1, 4, -1), Vector3i(2, 4, -1), Vector3i(1, 4, 1), Vector3i(2, 4, 1)]:
		attendu[c] = true
	_egal_ens(r["poser"], attendu, "avec garde-corps : le bord et les côtés, pas le passage ni la paroi")
	# Sur l'escalier diagonal : ce qu'il pose est dans l'air, à y = 3 ou 4, devant la paroi, sans damier.
	var escalier := {}
	for x in range(-8, 9):
		for z in range(-8, 9):
			if x + z <= 0:
				_boite(escalier, Vector3i(x, 0, z), Vector3i(x, 6, z))
	r = FS.forme(escalier, {"quoi": "balcon", "a": Vector3i(0, 3, 0), "face_a": Vector3i(1, 0, 0),
		"taille": 2, "longueur": 3})
	var mal := 0
	for c in r["poser"]:
		var q: Vector3i = c
		if escalier.has(q) or q.y != 3 or q.x + q.z <= 0:
			mal += 1
	_egal(mal, 0, "un balcon sur paroi diagonale pose dans l'air, devant elle, au niveau cliqué")
	_vrai(r["poser"].size() >= 5, "… et il en pose (%d cases)" % r["poser"].size())
	_vrai(MB.contacts_par_arete(_apres(escalier, r)) <= MB.contacts_par_arete(escalier), "… sans damier de plus")


# ── 9. les refus ─────────────────────────────────────────────────────────────────────────────────────

func _erreurs() -> void:
	print("── les refus")
	var mur := _mur()
	var base := {"a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0), "relier": false, "taille": 2}
	var r: Dictionary = FS.forme(mur, base.merged({"quoi": "puits"}))
	_egal(r["erreur"], "pas_un_sol", "un puits sur une paroi est refusé")
	r = FS.forme(mur, base.merged({"quoi": "tunnel", "face_a": Vector3i(0, 1, 0)}, true))
	_egal(r["erreur"], "pas_de_paroi", "un tunnel sur un sol est refusé")
	r = FS.forme(mur, base.merged({"quoi": "tunnel", "relier": true, "b": Vector3i(0, 3, 0),
		"face_b": Vector3i(-1, 0, 0)}, true))
	_egal(r["erreur"], "meme_case", "relier une ancre à elle-même est refusé")
	r = FS.forme(mur, base.merged({"quoi": "tunnel", "relier": true, "b": Vector3i(200, 3, 0),
		"face_b": Vector3i(1, 0, 0)}, true))
	_egal(r["erreur"], "trop_long", "relier deux ancres trop éloignées est refusé")
	r = FS.forme(mur, base.merged({"quoi": "escalier"}))
	_egal(r["erreur"], "forme_inconnue", "une forme inconnue est refusée")
	_vrai(r["poser"].is_empty() and r["effacer"].is_empty(), "un refus ne change rien")


# ── 10. la réparation ────────────────────────────────────────────────────────────────────────────────
#
# Le mur de 3, une POCHE vide en (1,4,1) ; un tunnel de taille 1 creuse (0..2, 3, 0). Dans le plan x = 1,
# le carré y = 3..4, z = 0..1 devient un damier : (3,0) et (4,1) vides, (3,1) et (4,0) pleins. Creuser en
# vide la paire pleine : (1,3,1) et (1,4,0). Déroulé : aucun des carrés qui les touchent ne redevient un
# damier — deux cases réparées, pas une de plus.

func _reparation() -> void:
	print("── la réparation")
	var poche := _mur()
	poche.erase(Vector3i(1, 4, 1))
	var r: Dictionary = FS.forme(poche, {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0),
		"relier": false, "profil": "rond", "taille": 1, "longueur": 8})
	_egal_ens(r["effacer"], _liste([Vector3i(0, 3, 0), Vector3i(1, 3, 0), Vector3i(2, 3, 0), Vector3i(1, 3, 1),
		Vector3i(1, 4, 0)]), "le damier né du tunnel et de la poche : sa paire pleine est creusée aussi")
	_egal(r["reparees"], 2, "… deux cases réparées, et le geste le dit")
	_egal(MB.contacts_par_arete(_apres(poche, r)), MB.contacts_par_arete(poche), "… et il n'en reste aucun")
	# Le même geste à côté d'un damier qui PRÉEXISTE loin du conduit : on n'y touche pas.
	var ailleurs := _mur()
	ailleurs.erase(Vector3i(1, 0, -3))
	ailleurs.erase(Vector3i(1, 1, -4))
	r = FS.forme(ailleurs, {"quoi": "tunnel", "a": Vector3i(0, 3, 0), "face_a": Vector3i(-1, 0, 0),
		"relier": false, "profil": "rond", "taille": 1, "longueur": 8})
	_egal(r["reparees"], 0, "un damier qui préexistait loin du conduit n'est pas réparé")
	# Un conduit fin et oblique entre deux ancres décalées : relié par les faces (la traversée de l'axe),
	# sans damier de plus.
	var m := {}
	_boite(m, Vector3i(0, 0, -6), Vector3i(12, 12, 6))
	r = FS.forme(m, {"quoi": "tunnel", "a": Vector3i(0, 2, 0), "face_a": Vector3i(-1, 0, 0),
		"relier": true, "b": Vector3i(12, 9, 4), "face_b": Vector3i(1, 0, 0), "profil": "rond", "taille": 1})
	var apres := _apres(m, r)
	_egal(MB.contacts_par_arete(apres), MB.contacts_par_arete(m), "un conduit fin en biais ne laisse aucun damier")
	_vrai(_relies(apres, Vector3i(-1, 2, 0), Vector3i(13, 9, 4), Vector3i(-1, 0, -6), Vector3i(13, 12, 6)),
		"… et relie ses deux bouts par les faces")
	# La traversée, à la main : (0,0,0) → (2,1,0). Franchissements : x à 1/4 et 3/4, y à 1/2.
	# → x (1,0,0), puis y (1,1,0), puis x (2,1,0).
	_egal(FS.traverser(Vector3i.ZERO, Vector3i(2, 1, 0)), [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0),
		Vector3i(2, 1, 0)] as Array[Vector3i], "la traversée d'un axe oblique, déroulée à la main")
	# Égalité exacte (1,1,0) : x d'abord.
	_egal(FS.traverser(Vector3i.ZERO, Vector3i(1, -1, 0)), [Vector3i(0, 0, 0), Vector3i(1, 0, 0),
		Vector3i(1, -1, 0)] as Array[Vector3i], "une égalité exacte : le plus petit axe d'abord")
	r = FS.forme(m, {"quoi": "pont", "a": Vector3i(12, 2, 0), "face_a": Vector3i(1, 0, 0),
		"relier": true, "b": Vector3i(12, 9, 4), "face_b": Vector3i(1, 0, 0), "taille": 1})
	_egal(MB.contacts_par_arete(_apres(m, r)), MB.contacts_par_arete(m),
		"un pont fin qui fait demi-tour dans l'air ne laisse aucun damier")


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
