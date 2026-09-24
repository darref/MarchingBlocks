extends SceneTree
##
## SONDE — le témoin exporté est-il SOUDÉ, MANIFOLD, et ses boucles d'arêtes ininterrompues ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/UnderMend \
##       --script res://DEV_TOOLS/sonde_topologie_export.gd
##
## ⚠ ELLE NE MODIFIE RIEN.
##
## ── L'EXIGENCE (Jordan) ─────────────────────────────────────────────────────────────────────────────
##
## « n'importe quelle sélection de boucle d'arête doit être ininterrompue, là où c'est une boucle ».
## Dans Blender, Alt+clic propage une boucle à travers les sommets de **valence 4** et s'arrête à tout
## pôle. Il faut donc : **soudé**, **manifold**, et **valence 4 le long des boucles**.
##
## ⚠ **« 100 % DE VALENCE 4 » N'EXISTE PAS sur une surface fermée** — Euler l'interdit, et un coin de
## cube est un pôle de valence 3 par nature. Mesuré ici : les pôles du solide sont **11 coins convexes**
## (valence 3, une seule cellule autour) et **3 coins rentrants** (valence 5). La formulation de Jordon
## *« là où c'est une boucle »* en tenait déjà compte ; ma lecture, non.
##
## ── CE QUI A ÉTÉ MESURÉ, ET LES DEUX INSTRUMENTS QUI ONT MENTI AVANT D'ÊTRE RÉPARÉS ─────────────────
##
## ⚠ **1. LES VALENCES SUR TRIANGLES NE VEULENT RIEN DIRE.** Chaque quad porte sa DIAGONALE, qui ajoute
## une arête à ses deux bouts : un sommet de valence 4 en quads apparaît en valence 6 en triangles. Mon
## premier rapport annonçait « 8 % de valence 4 » sur un solide parfait. C'est aussi pourquoi
## « Tris to Quads » rétablit les boucles : il supprime exactement ces diagonales.
##
## ⚠ **2. L'APPARIEMENT GLOUTON MARIAIT DEUX QUADS VOISINS.** Il parcourait les arêtes dans l'ordre du
## dictionnaire et laissait 26 à 36 triangles orphelins sur des maillages faits UNIQUEMENT de
## rectangles — géométriquement impossible. Corrigé par le critère de la plus longue arête, mutuelle.
##
## ── LES VERDICTS ────────────────────────────────────────────────────────────────────────────────────
##
##   le SOLIDE tel qu'émis        manifold ✓, 0 trou, 81 % de valence 4 (14 pôles de coin)  → CONFORME
##   l'AMINCI tel qu'émis         ⚠ 139 arêtes à 3+ faces : il émet les SIX faces de chaque cellule,
##                                soit 144 faces enterrées sur 216                          → ÉCHOUE
##   l'AMINCI cullé naïvement     ⚠ 16 arêtes de BORD : des trous, là où deux cellules voisines ont
##                                des retraits différents (le commentaire du code avait raison)
##   l'AMINCI en SOUS-VOXELS      manifold ✓, 0 trou, 98 % de valence 4, récolte IDENTIQUE  → REMÈDE

const BM := preload("res://addons/undermend/blocs_maitres.gd")
const MB := preload("res://addons/undermend/marching_blocks.gd")
const Tranchage := preload("res://addons/undermend/tranchage.gd")
## ⚠ La coque en sous-voxels et le bilan vivent dans un module PARTAGÉ avec `verifier_bloc_unique.gd`.
const Topo := preload("res://DEV_TOOLS/topologie.gd")

## Le retrait de l'amincissement, repris de `maillage_moitie(i, cote := 0.5)` : `d = cote * 0.5`.
const RETRAIT := 0.25

## ⚠ Le retrait vaut un QUART de cellule, donc quatre sous-voxels par cellule représentent exactement
## les boîtes rentrées, sans le moindre arrondi.
const SOUS := 4

var _cases: Dictionary = {}


func _initialize() -> void:
	print("=== SONDE — LA TOPOLOGIE DU MAILLAGE EXPORTÉ ===\n")
	var cases: Dictionary = BM.cases(0)
	_cases = cases
	print("bloc 0 « %s » : %d cellules pleines\n" % [BM.BLOCS[0]["nom"], cases.size()])

	_examiner("1. le SOLIDE tel qu'émis", BM.sans_normales(BM.souder(BM.maillage(0))), true)
	print("")
	_examiner("3. l'AMINCI tel qu'émis", BM.sans_normales(BM.souder(BM.maillage_moitie(0))))
	print("")
	_examiner("4. l'AMINCI en COQUE SEULE (cull naïf)",
		BM.sans_normales(BM.souder(_coque(cases, true))))
	print("")
	_examiner("5. l'AMINCI en SOUS-VOXELS (le remède candidat)",
		BM.sans_normales(BM.souder(_coque_sous_voxels(cases, true))), true)
	_pipeline(cases)
	_les_neuf()
	quit(0)


## ⚠ DÉLÉGATION vers le module partagé — pas une seconde description de la règle. Elle ajoute juste
## `_cases`, dont le module se sert pour classer les pôles.
func _bilan(mesh: ArrayMesh) -> Dictionary:
	return Topo.bilan(mesh, _cases)


func _texte_valences(val: Dictionary) -> String:
	var liste: Array = val.keys()
	liste.sort()
	var texte := ""
	for d in liste:
		texte += "%d→%d  " % [d, val[d]]
	return texte


func _examiner(quoi: String, mesh: ArrayMesh, montrer_poles := false) -> void:
	print("── %s ──" % quoi)
	var b: Dictionary = _bilan(mesh)
	if b["sommets"] == 0:
		print("   (aucune surface)")
		return
	print("   %d sommets, %d triangles   ·   soudure : %s"
		% [b["sommets"], b["triangles"],
			"100 % SOUDÉ" if b["doubles"] == 0 else "⚠ %d en double" % b["doubles"]])
	print("   manifold : %d arêtes — %d de BORD, %d à 3 faces ou plus → %s"
		% [b["aretes"], b["bords"], b["multiples"],
			"MANIFOLD ✓" if b["bords"] == 0 and b["multiples"] == 0
			else ("⚠ TROUS" if b["bords"] > 0 else "⚠ faces enterrées")])
	var q4: int = int((b["q_val"] as Dictionary).get(4, 0))
	print("   ── APRÈS « TRIS TO QUADS » : %d quads, %d orphelin(s) ──" % [b["quads"], b["orphelins"]])
	print("      manifold : %d arêtes — %d de BORD, %d à 3+ → %s"
		% [b["q_aretes"], b["q_bords"], b["q_multiples"],
			"MANIFOLD ✓" if b["q_bords"] == 0 and b["q_multiples"] == 0 else "⚠ PAS manifold"])
	print("      valences : %s" % _texte_valences(b["q_val"]))
	print("      → %d sommets sur %d en valence 4 (%.0f %%), %d pôle(s)"
		% [q4, b["q_sommets"], 100.0 * float(q4) / float(maxi(1, b["q_sommets"])),
			b["q_sommets"] - q4])
	if not montrer_poles:
		return
	var par_nature := {}
	for p in (b["poles"] as Array):
		var cle := "valence %d, %d cellule(s) pleine(s) autour" % [p["valence"], p["autour"]]
		par_nature[cle] = int(par_nature.get(cle, 0)) + 1
	var formes: Array = par_nature.keys()
	formes.sort()
	print("      les pôles, par nature :")
	for f in formes:
		print("        %-44s ×%d" % [f, par_nature[f]])


# ── LES NEUF BLOCS — « manifold par construction » est une affirmation UNIVERSELLE ──────────────────
#
# ⚠ Je l'ai tirée d'un seul bloc. Or trois de mes affirmations « par construction » ont été réfutées
# aujourd'hui : le jpg « doublon » qui ne l'était pas, la connexité que j'avais mal diagnostiquée deux
# fois, et le bruit prétendument forcé par le manque de place. **Un échantillon ne prouve rien sur les
# huit autres.**
func _les_neuf() -> void:
	print("\n── LES NEUF BLOCS : LE SOLIDE ET LA COQUE EN SOUS-VOXELS ──")
	print("   ⚠ Le SOLIDE est mesuré ici sur les neuf lui aussi : j'avais déclaré « conforme » à partir")
	print("     du bloc 0 seul, la même faute d'échantillon unique qui vient de m'être réfutée.")
	print("")
	print("   bloc                  contacts   SOLIDE            SOUS-VOXELS")
	print("                         d'arête    bords  3+  val4   bords  3+  val4")
	var mauvais: Array = []
	for i in BM.nombre():
		_cases = BM.cases(i)
		# ⚠ La règle vit dans le MODÈLE (`MB.contacts_par_arete`), plus dans cette sonde : deux copies
		# auraient divergé. Le contrôle de fidélité est le résultat lui-même — il doit rendre les mêmes
		# 19 / 13 / 13 qu'avant l'extraction, sans quoi ce n'était pas une extraction.
		var contacts: int = MB.contacts_par_arete(_cases)
		var s: Dictionary = _bilan(BM.sans_normales(BM.souder(BM.maillage(i))))
		var w: Dictionary = _bilan(BM.sans_normales(BM.souder(_coque_sous_voxels(_cases, true))))
		var s4: int = int((s["q_val"] as Dictionary).get(4, 0))
		var w4: int = int((w["q_val"] as Dictionary).get(4, 0))
		var bon: bool = s["q_bords"] == 0 and s["q_multiples"] == 0 \
			and w["q_bords"] == 0 and w["q_multiples"] == 0
		if not bon:
			mauvais.append(BM.BLOCS[i]["nom"])
		print("   %-20s %8d %7d %3d %4.0f %% %7d %3d %4.0f %%   %s"
			% [BM.BLOCS[i]["nom"], contacts,
				s["q_bords"], s["q_multiples"], 100.0 * float(s4) / float(maxi(1, s["q_sommets"])),
				w["q_bords"], w["q_multiples"], 100.0 * float(w4) / float(maxi(1, w["q_sommets"])),
				"✓" if bon else "⚠"])
	if mauvais.is_empty():
		print("   → ✅ les neuf sont manifold, solide comme sous-voxels")
	else:
		print("   → ⚠ échouent : %s" % ", ".join(PackedStringArray(mauvais)))
	print("\n   ⚠ LA PRÉDICTION À VÉRIFIER : si les blocs fautifs sont EXACTEMENT ceux qui ont des")
	print("     contacts d'arête, la cause est dans l'OCCUPATION et aucun mailleur ne la corrigera.")
	print("     Si les deux colonnes ne se correspondent pas, mon explication est fausse.")


## Les contacts par ARÊTE SEULE dans l'occupation : deux cases diagonales dans un plan, les deux
## complémentaires vides. Quatre faces se rejoignent alors sur l'arête commune.
##
## ⚠ **LE MODÈLE CONNAÎT DÉJÀ CE CAS SOUS UN AUTRE NOM** : c'est la « face ambiguë » de
## `PONT_SUR_FACE_AMBIGUE` — deux massifs qui ne se touchent que par un coin, et dont le projet a
## DÉCIDÉ qu'ils laissent le passage ouvert. Il est donc **légal**, et il apparaîtra aussi dans les
## blocs que l'artiste sculptera. Ce n'est pas un défaut de nos témoins à corriger en douce.
func _contacts_par_arete(cases: Dictionary) -> int:
	var combien := 0
	var paires := [[0, 1], [0, 2], [1, 2]]
	for x in range(-1, BM.COTE):
		for y in range(-1, BM.COTE):
			for z in range(-1, BM.COTE):
				var p := Vector3i(x, y, z)
				for paire in paires:
					var e1 := Vector3i.ZERO
					e1[paire[0]] = 1
					var e2 := Vector3i.ZERO
					e2[paire[1]] = 1
					var a: bool = cases.has(p)
					var b: bool = cases.has(p + e1)
					var c: bool = cases.has(p + e2)
					var d: bool = cases.has(p + e1 + e2)
					# Exactement les deux diagonales, dans un sens ou dans l'autre.
					if (a and d and not b and not c) or (b and c and not a and not d):
						combien += 1
	return combien


# ── LES CONSTRUCTIONS ───────────────────────────────────────────────────────────────────────────────

## La COQUE : seules les faces qui bordent du vide. `moitie` applique le même retrait que
## `maillage_moitie` — rentré uniquement sur les côtés qui donnent sur du vide.
## ⚠ Recalculé ICI et non appelé au module : lui demander de se juger lui-même ne prouverait rien.
func _coque(cases: Dictionary, moitie: bool) -> ArrayMesh:
	var sommets := PackedVector3Array()
	for c in cases:
		var p: Vector3i = c
		var mini := Vector3(p)
		var maxi := Vector3(p) + Vector3.ONE
		if moitie:
			for axe in 3:
				var avant := Vector3i.ZERO
				avant[axe] = -1
				if not cases.has(p + avant):
					mini[axe] += RETRAIT
				var apres := Vector3i.ZERO
				apres[axe] = 1
				if not cases.has(p + apres):
					maxi[axe] -= RETRAIT
		for axe in 3:
			for signe in [-1, 1]:
				var d := Vector3i.ZERO
				d[axe] = signe
				if cases.has(p + d):
					continue   # ⚠ LE CULL : la face donne sur une voisine pleine
				_quad(sommets, mini, maxi, axe, signe)
	return _en_mesh(sommets)


## ⚠ **LE REMÈDE : la frontière de l'union, construite en SOUS-VOXELS.** Le cull naïf ouvre 16 trous là
## où deux cellules voisines ont des retraits différents ; il faudrait alors émettre à la main l'anneau
## de raccord, une différence de rectangles à réussir du premier coup. Une frontière d'union de voxels
## est **manifold et fermée par construction** : il n'y a rien à réussir.
##
## Bonus mesuré, et c'est lui qui répond à l'exigence : une face plane subdivisée gagne des sommets
## INTÉRIEURS de valence 4 — 98 % contre 81 % pour une face par cellule, donc de vraies boucles longues.
## ⚠ TROIS DÉLÉGATIONS vers le module partagé. Leurs corps vivaient ici ; les recopier pour mesurer
## aussi le bloc unique de 8³ en aurait fait deux descriptions du même calcul.
func _coque_sous_voxels(cases: Dictionary, moitie: bool) -> ArrayMesh:
	return Topo.coque_sous_voxels(cases, RETRAIT if moitie else 0.0)


func _quad(sommets: PackedVector3Array, mini: Vector3, maxi: Vector3, axe: int, signe: int) -> void:
	Topo.quad(sommets, mini, maxi, axe, signe)


func _en_mesh(sommets: PackedVector3Array) -> ArrayMesh:
	return Topo.en_mesh(sommets)


# ── LE VRAI PIPELINE ────────────────────────────────────────────────────────────────────────────────

## ⚠ **LA TOPOLOGIE NE SUFFIT PAS : LE REMÈDE DOIT SURVIVRE AU TRANCHEUR.** `librairie()` tranche
## `maillage_moitie(i)` ; cinq fois plus de géométrie peut changer la RÉCOLTE, faire apparaître des
## erreurs d'octant, ou exploser le temps. Même bloc, même appel, `peau = false` comme la vraie
## librairie : la comparaison est contrôlée.
func _pipeline(cases: Dictionary) -> void:
	print("\n── LE VRAI PIPELINE : les deux versions dans `Tranchage.trancher()` ──")
	var creuses: Array = BM.creuses(0)
	var releves: Array = []
	for essai in [
		{"nom": "aminci ACTUEL (six faces par cellule)", "mesh": BM.maillage_moitie(0)},
		{"nom": "aminci en SOUS-VOXELS", "mesh": _coque_sous_voxels(cases, true)},
	]:
		var mesh: ArrayMesh = essai["mesh"]
		var erreurs: Array = []
		var remarques: Array = []
		var t0: int = Time.get_ticks_msec()
		var pieces: Dictionary = Tranchage.trancher(mesh, Vector3i.ONE * BM.COTE, 1.0,
			creuses, erreurs, false, remarques)
		var ms: int = Time.get_ticks_msec() - t0
		var noms: Array = pieces.keys()
		noms.sort()
		print("   %-42s %6d triangles, %5d ms" % [essai["nom"], _triangles(mesh), ms])
		print("      %d classe(s), %d erreur(s) d'OCTANT, %d remarque(s) de couture"
			% [pieces.size(), erreurs.size(), remarques.size()])
		if not erreurs.is_empty():
			print("      ⚠ %s" % str(erreurs.slice(0, 2)))
		releves.append(noms)

	var en_a := {}
	for n in releves[0]:
		en_a[n] = true
	var perdues: Array = []
	var gagnees: Array = []
	var en_b := {}
	for n in releves[1]:
		en_b[n] = true
	for n in releves[0]:
		if not en_b.has(n):
			perdues.append(n)
	for n in releves[1]:
		if not en_a.has(n):
			gagnees.append(n)
	print("\n   récoltes : %d classes contre %d — %d perdue(s), %d gagnée(s)"
		% [(releves[0] as Array).size(), (releves[1] as Array).size(), perdues.size(), gagnees.size()])
	if not perdues.is_empty():
		print("      ⚠ PERDUES : %s" % str(perdues))
	if perdues.is_empty() and gagnees.is_empty():
		print("      ✅ RÉCOLTE IDENTIQUE — le remède ne change pas ce que le greffon livre")

	var t_actuel := 0
	var t_voxels := 0
	for i in BM.nombre():
		t_actuel += _triangles(BM.maillage_moitie(i))
		t_voxels += _triangles(_coque_sous_voxels(BM.cases(i), true))
	print("   coût pour la bande des %d blocs : %d triangles → %d (×%.1f)"
		% [BM.nombre(), t_actuel, t_voxels, float(t_voxels) / float(maxi(1, t_actuel))])


func _triangles(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	var arrays: Array = mesh.surface_get_arrays(0)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
		if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if not idx.is_empty():
		return idx.size() / 3
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
