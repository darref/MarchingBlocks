extends SceneTree
##
## SONDE — pourquoi deux mutations du trancheur restent-elles MUETTES ?
##
## LANCEMENT
##   godot --headless --path D:/MarchingBlocks --script res://DEV_TOOLS/sonde_tranchage.gd
##
## ⚠ **QUATRE HYPOTHÈSES DÉMENTIES D'AFFILÉE, CHACUNE AU PRIX D'UN BANC COMPLET.** On arrête de deviner.
## Deux mutations résistent, et cette sonde mesure leur cause au lieu de la supposer :
##
##   1. **« condition borde-le-vide supprimée »** — forcer TOUT octant plein à porter de la surface
##      devrait faussement condamner un octant INTÉRIEUR (trois voisins pleins). Soupçon : `mb_coin_creux`
##      est bien livré, mais son octant intérieur porte quand même de la surface, parce que le bloc
##      d'essai est un empilement de boîtes dont les FACES INTERNES sont conservées (aucun CSG).
##   2. **« origine prise au COIN »** — les deux formules ne divergent que de 0,125 en y sur un bloc à
##      relief. Soupçon : un décalage aussi petit n'AFFAME aucun octant de bord, chacun continuant
##      d'attraper de la géométrie.
##
## Elle ne modifie rien. Elle imprime.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Decoupe := preload("res://addons/marchingblocks_core/decoupe.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")

const CELLULE := 1.0


func _initialize() -> void:
	print("=== SONDE — les deux mutations muettes ===\n")
	_question_un()
	_question_deux()
	quit(0)


# ── 1. l'octant intérieur porte-t-il de la surface ? ────────────────────────────────────────────────

func _question_un() -> void:
	print("── 1. « borde le vide » : y a-t-il un octant INTÉRIEUR, et porte-t-il de la surface ? ──")
	var creuses := [Vector3i(1, 1, 1), Vector3i(2, 2, 2)]
	var erreurs: Array = []
	var pieces: Dictionary = Tranchage.trancher(
		_bloc(Vector3i(3, 3, 3), creuses, 0.0, Vector3(1.7, -0.3, 2.1), true),
		Vector3i(3, 3, 3), CELLULE, creuses, erreurs)

	var par_bits := {}
	for c in MB.classes():
		par_bits[c["nom"]] = c["bits"]

	print("   classes livrées (%d) : %s" % [pieces.size(), str(pieces.keys())])
	var avec_interieur := 0
	for nom in pieces:
		var bits: int = par_bits.get(nom, 0)
		# Les octants PLEINS sans aucun voisin vide : les intérieurs.
		var interieurs: Array = []
		for t in 8:
			if not (bits & (1 << t)):
				continue
			var borde := false
			for axe in 3:
				if not (bits & (1 << (t ^ (1 << axe)))):
					borde = true
			if not borde:
				interieurs.append(t)
		if interieurs.is_empty():
			continue
		avec_interieur += 1
		var trouves := _octants_occupes(pieces[nom])
		var portent: Array = []
		for t in interieurs:
			if trouves.has(t):
				portent.append(t)
		print("   %-22s octants INTÉRIEURS %s → portent de la surface : %s"
			% [nom, str(interieurs), str(portent) if not portent.is_empty() else "AUCUN"])

	print("   → %d classe(s) livrée(s) possèdent un octant intérieur" % avec_interieur)
	if avec_interieur == 0:
		print("   ⚠ CAUSE : aucune classe livrée n'a d'octant intérieur. La mutation est inobservable")
		print("     sur ce sujet — il faut une classe à 7 cellules pleines (mb_coin_creux).")
	else:
		print("   ⚠ Si ces octants PORTENT de la surface, la mutation ne peut pas être vue : le bloc")
		print("     d'essai conserve ses faces internes (empilement de boîtes, pas de CSG).")


# ── 2. un décalage d'origine affame-t-il un octant ? ────────────────────────────────────────────────

func _question_deux() -> void:
	print("\n── 2. « origine au coin » : le décalage affame-t-il un octant de bord ? ──")
	var cases := Vector3i(3, 2, 3)
	var bloc: ArrayMesh = _bloc(cases, [], 0.25, Vector3.ZERO, false)
	var boite: AABB = bloc.get_aabb()
	var attendue := Vector3(cases) * CELLULE
	var au_centre: Vector3 = boite.get_center() - attendue * 0.5
	var au_coin: Vector3 = boite.position
	var ecart: Vector3 = au_centre - au_coin
	print("   AABB %s taille %s (déclarée %s)" % [str(boite.position), str(boite.size), str(attendue)])
	print("   écart entre les deux origines : %s" % str(ecart))

	# ⚠ ON REPRODUIT L'EFFET DE LA MUTATION SANS MUTER : pré-translater le bloc de l'écart fait tomber
	# l'origine « au centre » exactement là où l'origine « au coin » l'aurait mise.
	for essai in [
		{"nom": "origine au CENTRE (sain)", "mesh": bloc},
		{"nom": "origine au COIN (simulée)", "mesh": Decoupe.poser(bloc, Transform3D(Basis(), ecart))},
	]:
		var erreurs: Array = []
		var pieces: Dictionary = Tranchage.trancher(essai["mesh"], cases, CELLULE, [], erreurs)
		var octants := 0
		for e in erreurs:
			if "octant" in String(e):
				octants += 1
		print("   %-28s → %d pièces, %d erreur(s) d'octant, %d au total"
			% [essai["nom"], pieces.size(), octants, erreurs.size()])
		print("      classes : %s" % str(pieces.keys()))

	print("   ⚠ Si les deux lignes donnent le MÊME nombre d'erreurs d'octant, le contrôle est trop")
	print("     grossier pour voir un décalage de cette taille — et c'est un fait sur l'instrument,")
	print("     pas sur le trancheur.")


# ── outils ──────────────────────────────────────────────────────────────────────────────────────────

func _octants_occupes(mesh: ArrayMesh) -> Dictionary:
	var trouves := {}
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] \
			if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		for i in range(0, v.size() - 2, 3):
			var c: Vector3 = (v[i] + v[i + 1] + v[i + 2]) / 3.0
			var t: int = Tranchage.octant_du_triangle(c, n[i] if n.size() > i else Vector3.ZERO)
			if t >= 0:
				trouves[t] = true
	return trouves


func _bloc(cases: Vector3i, creuses: Array, relief: float, decalage: Vector3,
		damier: bool) -> ArrayMesh:
	var absentes := {}
	for c in creuses:
		absentes[Vector3i(c)] = true
	var morceaux: Array = []
	for x in cases.x:
		for y in cases.y:
			for z in cases.z:
				if absentes.has(Vector3i(x, y, z)):
					continue
				var boite := BoxMesh.new()
				boite.size = Vector3.ONE * CELLULE
				var brut := ArrayMesh.new()
				brut.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, boite.surface_get_arrays(0))
				morceaux.append(Decoupe.poser(brut, Transform3D(Basis(),
					(Vector3(x, y, z) + Vector3.ONE * 0.5) * CELLULE + decalage)))
	if relief > 0.0:
		for x in cases.x:
			for z in cases.z:
				if damier and (x + z) % 2 != 0:
					continue
				var bosse := BoxMesh.new()
				bosse.size = Vector3(0.4, relief, 0.4) * CELLULE
				var brut := ArrayMesh.new()
				brut.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bosse.surface_get_arrays(0))
				morceaux.append(Decoupe.poser(brut, Transform3D(Basis(),
					Vector3(x + 0.5, cases.y, z + 0.5) * CELLULE
						+ Vector3.UP * relief * 0.5 + decalage)))
	return Decoupe.fusionner(morceaux)
