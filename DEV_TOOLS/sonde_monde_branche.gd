extends SceneTree
## SONDE — où passe le temps de l'appli branchée au monde du cœur (étape 3 b) : cacher une couche, décomposé.
## godot --headless --path . --script res://DEV_TOOLS/sonde_monde_branche.gd

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Peint := preload("res://addons/marchingblocks_core/massif_peint.gd")
const RP := preload("res://addons/marchingblocks_core/repli_procedural.gd")


func _lot() -> MeshLibrary:
	var lot := MeshLibrary.new()
	var mesh: Mesh = RP.librairie().get_item_mesh(0)
	var id := 0
	for k in MB.classes():
		for nom in [k["nom"], MB.nom_en_contexte(k["nom"], true)]:
			lot.create_item(id)
			lot.set_item_name(id, nom)
			lot.set_item_mesh(id, mesh)
			id += 1
	return lot


func _initialize() -> void:
	var lot := _lot()
	var union := {}
	var massifs: Array = []
	var monde = MB.monde_natif()
	var parts: Array = [{}, {}, {}]
	for x in 200:
		for z in 200:
			var h := 3 + int((sin(x * 0.07) + cos(z * 0.05)) * 2.0)
			for y in h:
				parts[2 if y > 3 else int((x / 40 + z / 50) % 2)][Vector3i(x, y, z)] = true
	for r in 3:
		var m: Node3D = Peint.new()
		root.add_child(m)
		m.preparer()
		m.lot = lot
		var cases: GridMap = m.get_node("Cases")
		for c in parts[r]:
			cases.set_cell_item(c, 0)
		massifs.append(m)
	for i in range(2, -1, -1):
		massifs[i].union = union
		massifs[i].monde = monde
		massifs[i].rang = i
		for c in parts[i]:
			union[c] = i
	for m in massifs:
		m.reconstruire()
	var siennes: Array = (massifs[1].get_node("Cases") as GridMap).get_used_cells()
	massifs[1].visible = false
	var tz := Time.get_ticks_usec()
	monde.vider_attente()
	print("endormir seul : %d ms, dort %s, visible %s" % [(Time.get_ticks_usec() - tz) / 1000, monde.dort(1), (massifs[1].get_node("Rendu") as GridMap).is_visible_in_tree()])
	for c in siennes:
		union.erase(c)
	var t0 := Time.get_ticks_usec()
	monde.suivre(union, siennes)
	var t1 := Time.get_ticks_usec()
	var n: int = monde.taille_attente()
	monde.vider_attente()
	var t2 := Time.get_ticks_usec()
	massifs[2].reconstruire_autour(siennes)
	var t3 := Time.get_ticks_usec()
	print("cacher une couche de %d cases : suivre %d ms, %d en attente posées en %d ms ; seconde couche %d ms" % [
		siennes.size(), (t1 - t0) / 1000, n, (t2 - t1) / 1000, (t3 - t2) / 1000])
	massifs[1].visible = true
	for c in siennes:
		union[c] = 1
	var t4 := Time.get_ticks_usec()
	massifs[0].reconstruire_autour(siennes)
	var t5 := Time.get_ticks_usec()
	massifs[2].reconstruire_autour(siennes)
	massifs[1].reconstruire_autour([])
	var t6 := Time.get_ticks_usec()
	print("la montrer : %d ms (la première couche, réveil compris), puis %d ms" % [(t5 - t4) / 1000, (t6 - t5) / 1000])
	var tenu: Dictionary = massifs[1]._etat.duplicate(true)
	massifs[1].monde = null
	massifs[1].reconstruire()
	print("réveillée = reconstruite en entier : ", massifs[1]._etat == tenu, " (", tenu.size(), " sommets)")
	quit(0)
