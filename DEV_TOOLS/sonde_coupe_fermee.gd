extends SceneTree
##
## SONDE — une pièce tranchée est-elle FERMÉE sur ses faces de coupe ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_coupe_fermee.gd
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## Le lot d'essai « pièces écartées » sort en purée de cubes translucides, très majoritairement BLEUS —
## la couleur des faces tournées vers le bas, donc l'INTÉRIEUR des pièces. L'explication évidente est
## dans le commentaire de `decoupe.gd` : *« on ne referme pas la coupe, et c'est voulu »*.
##
## ⚠ **MAIS UN COMMENTAIRE N'EST PAS UNE MESURE**, et j'ai déjà affirmé deux mécanismes faux
## aujourd'hui. On compte donc, plutôt que de citer.
##
## ── CE QU'ON MESURE ─────────────────────────────────────────────────────────────────────────────────
##
## Un cube unité plein a une aire de 6. Tranché par une boîte qui en garde la moitié :
##   • si la coupe est REFERMÉE, la moitié a une aire de 3 (moitiés de 4 faces) + 1 (le capot) + 1 (la
##     face opposée entière) = 4,0 ;
##   • si la coupe est OUVERTE, il manque le capot : 3,0.
##
## On compte aussi les triangles dont les trois sommets touchent le plan de coupe : un capot en a, une
## coupe ouverte n'en a aucun. Deux instruments indépendants pour une même question.
##
## Elle ne modifie rien. Elle imprime.

const Decoupe := preload("res://addons/marchingblocks_core/decoupe.gd")
const BlocsMaitres := preload("res://addons/marchingblocks_core/blocs_maitres.gd")

const EPS := 0.0005


func _initialize() -> void:
	print("=== SONDE — la coupe est-elle refermée ? ===\n")

	# ── 1. un cube plein, tranché en deux ───────────────────────────────────────────────────────────
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var plein := ArrayMesh.new()
	plein.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cube.surface_get_arrays(0))
	var aire_pleine: float = Decoupe.aire(plein)
	print("cube unité plein : aire %.4f (6,0 attendu)" % aire_pleine)

	# Le cube va de −0,5 à +0,5 ; on garde x ≤ 0.
	var moitie: ArrayMesh = Decoupe.trancher(plein, AABB(Vector3(-1, -1, -1), Vector3(1.0, 2, 2)))
	var aire_moitie: float = Decoupe.aire(moitie)
	print("moitié tranchée  : aire %.4f" % aire_moitie)
	print("   si la coupe est REFERMÉE : 4,0 attendu")
	print("   si la coupe est OUVERTE  : 3,0 attendu")

	# ── 2. des triangles sur le plan de coupe ? ─────────────────────────────────────────────────────
	var sur_le_plan: int = _triangles_sur_le_plan(moitie, 0, 0.0)
	print("\ntriangles dont les TROIS sommets touchent le plan x = 0 : %d" % sur_le_plan)
	print("   un capot en a ; une coupe ouverte n'en a aucun")

	var ferme: bool = absf(aire_moitie - 4.0) < 0.01 and sur_le_plan > 0
	var ouvert: bool = absf(aire_moitie - 3.0) < 0.01 and sur_le_plan == 0
	print("\nVERDICT : %s" % ("la coupe est REFERMÉE" if ferme
		else ("la coupe est OUVERTE" if ouvert else "indécis — les deux instruments ne s'accordent pas")))

	# ── 3. et sur une VRAIE pièce du catalogue ──────────────────────────────────────────────────────
	print("\n── sur les pièces réellement livrées ──")
	var bilan: Dictionary = BlocsMaitres.librairie()
	var lot: MeshLibrary = bilan["lot"]
	var regardes := 0
	for id in lot.get_item_list():
		if regardes >= 5:
			break
		var mesh: Mesh = lot.get_item_mesh(id)
		if mesh == null:
			continue
		var ouverts := 0
		for axe in 3:
			for cote in [-0.5, 0.5]:
				if _triangles_sur_le_plan(mesh, axe, cote) == 0:
					ouverts += 1
		print("   %-26s %d face(s) de coupe sur 6 SANS aucun triangle"
			% [lot.get_item_name(id), ouverts])
		regardes += 1

	print("\n⚠ LECTURE — une pièce ouverte sur ses coupes est parfaitement correcte TANT QU'ELLE RESTE")
	print("   COLLÉE à ses voisines : leurs ouvertures se bouchent mutuellement. L'écarter la crève.")
	quit(0)


## Combien de triangles ont leurs TROIS sommets sur le plan `axe = position` ?
func _triangles_sur_le_plan(mesh: Mesh, axe: int, position: float) -> int:
	var compte := 0
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in range(0, v.size() - 2, 3):
			if absf(v[i][axe] - position) < EPS and absf(v[i + 1][axe] - position) < EPS \
					and absf(v[i + 2][axe] - position) < EPS:
				compte += 1
	return compte
