extends SceneTree
##
## SONDE — l'idée de Jordan : tester le relief sans modéliser, en déformant les blocs témoins.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_relief_blocs.gd
##
## ── LA QUESTION, ET POURQUOI ELLE EST BONNE ─────────────────────────────────────────────────────────
##
## Les neuf blocs maîtres sont parfaitement alignés sur les cellules : leur surface vit sur des plans
## ENTIERS. Ils n'exercent donc **aucun** des chemins qui traitent du relief — ni le contrôle de débord,
## ni le contrôle de couture, ni l'attribution d'un triangle à son octant quand il ne tombe pas sur un
## plan. Tout ce que le trancheur promet à l'artiste est, à cette heure, non mesuré.
##
## Jordan propose de mettre chaque bloc légèrement à l'échelle vers le moindre, pour que chaque tuile
## tombe strictement entre le min et le max de sa case. On mesure trois traitements :
##
##   1. ALIGNÉ              le solide brut, tel que `BlocsMaitres.maillage()` le rend ;
##   2. BLOC MIS À L'ÉCHELLE  un scale uniforme autour du centre du bloc ;
##   3. RELIEF PÉRIODIQUE   chaque face subdivisée, chaque sommet déplacé d'une quantité qui ne dépend
##                          QUE de sa position dans la cellule.
##
## ── CE QU'ON ATTEND, ÉCRIT AVANT DE LANCER ──────────────────────────────────────────────────────────
##
## ⚠ **PRÉDICTION 2 — LE SCALE DU BLOC DOIT ÊTRE REFUSÉ.** Un scale autour du centre déplace chaque plan
## de coupe proportionnellement à sa distance au centre : le plan entre les cellules 1 et 2 ne bouge pas
## comme celui entre 2 et 3. Deux pièces de même configuration de face présentent alors des germes
## différents, et `verifier_couture()` doit le dire. Si elle ne dit rien, c'est le CONTRÔLE qui est trop
## grossier, pas l'idée qui est bonne — et il faudra l'écrire ainsi.
##
## ⚠ **PRÉDICTION 3 — LE RELIEF PÉRIODIQUE DOIT PASSER.** Le déplacement ne dépend que de la position
## modulo la cellule, donc toutes les faces de même configuration reçoivent le même germe. C'est la
## condition du contrat, et elle est satisfaite par construction.
##
## ⚠ **UNE PRÉDICTION QUI TOMBE JUSTE VAUT MIEUX QU'UN RÉSULTAT QU'ON INTERPRÈTE APRÈS COUP** (charte §6).
## Les deux ci-dessus sont écrites ici AVANT le premier lancement.
##
## Elle ne modifie rien. Elle imprime.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Decoupe := preload("res://addons/marchingblocks_core/decoupe.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")
const BlocsMaitres := preload("res://addons/marchingblocks_core/blocs_maitres.gd")

const CELLULE := 1.0

## L'échelle du traitement 2. ⚠ 0,94 sur un bloc de 4 cases fait un débord de −0,24, donc SOUS le demi-
## cellule que le trancheur tolère : le refus, s'il vient, viendra de la COUTURE et non du débord.
const ECHELLE := 0.94

## Le relief du traitement 3 : creux de 0,18 au centre de chaque cellule, nul aux frontières.
const CREUX := 0.18
const SUBDIVISION := 4

## Les blocs sondés — un lisse, un percé, un chaotique. ⚠ Les neuf prendraient dix fois plus longtemps
## pour dire la même chose ; on prend un représentant de chaque famille de forme.
const SONDES := [0, 2, 6]


func _initialize() -> void:
	print("=== SONDE — tester le relief sans modéliser ===\n")
	print("prédiction 2 : le scale du BLOC est REFUSÉ (couture)")
	print("prédiction 3 : le relief PÉRIODIQUE passe\n")

	for i in SONDES:
		var nom: String = BlocsMaitres.BLOCS[i]["nom"]
		print("── %s ──" % nom)
		var creuses: Array = _creuses(i)
		var solide: ArrayMesh = BlocsMaitres.maillage(i)

		_essayer("1. aligné (tel quel)", solide, creuses)

		var centre := Vector3.ONE * (BlocsMaitres.COTE * 0.5)
		var mis: ArrayMesh = Decoupe.poser(solide, Transform3D(
			Basis().scaled(Vector3.ONE * ECHELLE), centre * (1.0 - ECHELLE)))
		_essayer("2. bloc à l'échelle %.2f" % ECHELLE, mis, creuses)

		_essayer("3. relief périodique (creux %.2f, subdiv %d)" % [CREUX, SUBDIVISION],
			_relief_periodique(i), creuses)
		print("")

	print("⚠ LECTURE — un refus au traitement 2 CONFIRME que le contrôle de couture mord ; un silence")
	print("   dirait que le contrôle est trop grossier, pas que l'idée est bonne.")
	print("⚠ Et le traitement 1 doit passer : s'il échoue, c'est la sonde qui est fausse, pas les blocs.")
	quit(0)


func _essayer(quoi: String, mesh: ArrayMesh, creuses: Array) -> void:
	var erreurs: Array = []
	var pieces: Dictionary = Tranchage.trancher(mesh, Vector3i.ONE * BlocsMaitres.COTE,
		CELLULE, creuses, erreurs)
	var couture := 0
	var octants := 0
	var debord := 0
	for e in erreurs:
		var t := String(e)
		if t.begins_with("couture"):
			couture += 1
		elif "octant" in t:
			octants += 1
		else:
			debord += 1
	var boite: AABB = mesh.get_aabb()
	print("   %-44s %2d pièces · %2d erreur(s) [couture %d, octant %d, autre %d]"
		% [quoi, pieces.size(), erreurs.size(), couture, octants, debord])
	print("      boîte %s taille %s" % [str(boite.position).pad_decimals(2),
		str(boite.size).pad_decimals(2)])
	for e in erreurs.slice(0, 3):
		print("      • %s" % String(e).left(150))


## Les cellules VIDES du bloc — ce que `trancher()` appelle `creuses`.
func _creuses(i: int) -> Array:
	var pleines: Dictionary = BlocsMaitres.cases(i)
	var vides: Array = []
	for x in BlocsMaitres.COTE:
		for y in BlocsMaitres.COTE:
			for z in BlocsMaitres.COTE:
				if not pleines.has(Vector3i(x, y, z)):
					vides.append(Vector3i(x, y, z))
	return vides


## LE RELIEF PÉRIODIQUE — la seule déformation gratuite qui respecte le contrat.
##
## Chaque face de la frontière est subdivisée, et chaque sommet est rentré vers la matière d'une
## quantité `CREUX * sin²(πu) * sin²(πv)`, où u et v sont ses coordonnées MONDE dans le plan de la face.
##
## ⚠ **C'EST LA PÉRIODICITÉ QUI SAUVE LA COUTURE, PAS LA PETITESSE DU DÉPLACEMENT.** La quantité ne
## dépend que de la position modulo la cellule : deux faces de même configuration, où qu'elles soient
## dans le bloc, reçoivent donc le même germe. Un scale de bloc, lui, déplace chaque plan d'une quantité
## différente — c'est pour ça qu'il casse, et ce n'est pas une question de réglage.
## ⚠ Le déplacement est NUL aux frontières de cellules (u ou v entier) et MAXIMAL au centre, donc sur
## les plans de coupe. Le germe est franchement déformé : c'est le but, un relief timide ne prouverait
## rien.
func _relief_periodique(i: int) -> ArrayMesh:
	var pleines: Dictionary = BlocsMaitres.cases(i)
	var sommets := PackedVector3Array()
	var normales := PackedVector3Array()

	for c in pleines:
		var p: Vector3i = c
		for axe in 3:
			for cote in [-1, 1]:
				var pas := Vector3i.ZERO
				pas[axe] = cote
				if pleines.has(p + pas):
					continue
				var normale := Vector3.ZERO
				normale[axe] = float(cote)
				var base := Vector3(p)
				if cote > 0:
					base[axe] += 1.0
				var autres: Array = []
				for k in 3:
					if k != axe:
						autres.append(k)
				# La face est subdivisée en SUBDIVISION × SUBDIVISION carreaux.
				for a in SUBDIVISION:
					for b in SUBDIVISION:
						var quad: Array = []
						for pas2 in [[0, 0], [0, 1], [1, 1], [1, 0]]:
							var q := base
							q[autres[0]] += float(a + pas2[0]) / SUBDIVISION
							q[autres[1]] += float(b + pas2[1]) / SUBDIVISION
							# ⚠ LE DÉPLACEMENT, fonction de la position MONDE seule.
							var u: float = q[autres[0]]
							var v: float = q[autres[1]]
							var f: float = pow(sin(PI * u), 2.0) * pow(sin(PI * v), 2.0)
							q[axe] -= float(cote) * CREUX * f
							quad.append(q)
						_quad(sommets, normales, quad, normale)

	var mesh := ArrayMesh.new()
	if sommets.is_empty():
		return mesh
	var tout: Array = []
	tout.resize(Mesh.ARRAY_MAX)
	tout[Mesh.ARRAY_VERTEX] = sommets
	tout[Mesh.ARRAY_NORMAL] = normales
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tout)
	return mesh


## ⚠ Godot enroule ses faces avant dans le sens HORAIRE : le produit vectoriel de l'ordre stocké doit
## pointer à l'opposé de la normale (même règle que `repli_procedural._ajouter_quad`).
func _quad(sommets: PackedVector3Array, normales: PackedVector3Array,
		quad: Array, normale: Vector3) -> void:
	var a: Vector3 = quad[0]
	var b: Vector3 = quad[1]
	var c: Vector3 = quad[2]
	var ordre: Array = quad
	if (b - a).cross(c - a).dot(normale) > 0.0:
		ordre = [quad[3], quad[2], quad[1], quad[0]]
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		for k in triangle:
			sommets.append(ordre[k])
			normales.append(normale)
