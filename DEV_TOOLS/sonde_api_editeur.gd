extends SceneTree
##
## SONDE — quelles API d'éditeur existent réellement, avant de concevoir dessus ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_api_editeur.gd
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## Jordan veut trois choses : que le greffon occupe la DROITE de la vue 3D au lieu de tout l'écran, des
## boutons près de la barre du GridMap, et des opérations (étendre, creuser, extruder) sur un ENSEMBLE
## DE CASES SÉLECTIONNÉES.
##
## ⚠ **J'ai annoncé trois noms d'API de mémoire, et j'ai été pris quatre fois aujourd'hui à supposer
## une API** — `sans_normales` qui laissait passer les tangentes, `ImporterMeshInstance3D` qui n'hérite
## pas de `MeshInstance3D`, un mot cherché dans des octets bruts, une indentation devinée. Concevoir sur
## un nom qui n'existe pas coûterait bien plus qu'une sonde.
##
## ── CE QU'ELLE MESURE ───────────────────────────────────────────────────────────────────────────────
##
##   1. les conteneurs d'ancrage : peut-on se poser sur le CÔTÉ DROIT de l'éditeur 3D ?
##   2. la barre de menus 3D : existe-t-elle comme point d'accrochage ?
##   3. ⚠ **LA QUESTION QUI DÉCIDE DU POINT 3** : `GridMap` expose-t-il la moindre notion de SÉLECTION ?
##      Si oui, les opérations sont faciles. Sinon, il faut écrire notre propre sélection, et c'est un
##      tout autre chantier — que Jordan doit pouvoir arbitrer en connaissance de cause.
##
## Elle ne modifie rien. Elle imprime.


func _initialize() -> void:
	print("=== SONDE — LES API D'ÉDITEUR ===\n")

	# ── 1. les conteneurs d'ancrage ─────────────────────────────────────────────────────────────────
	print("── OÙ UN GREFFON PEUT S'ANCRER ──")
	var conteneurs: Array = []
	for nom in ClassDB.class_get_enum_constants("EditorPlugin", "CustomControlContainer"):
		conteneurs.append(nom)
	if conteneurs.is_empty():
		print("   ⚠ aucune constante lue — l'énumération n'a pas ce nom")
	for nom in conteneurs:
		var marque := ""
		if "SPATIAL" in nom:
			marque = "   ← éditeur 3D"
		print("   %-46s %d%s" % [nom,
			ClassDB.class_get_integer_constant("EditorPlugin", nom), marque])

	# ── 2. les emplacements de dock ─────────────────────────────────────────────────────────────────
	print("\n── LES EMPLACEMENTS DE DOCK ──")
	for nom in ClassDB.class_get_enum_constants("EditorPlugin", "DockSlot"):
		print("   %-46s %d" % [nom, ClassDB.class_get_integer_constant("EditorPlugin", nom)])

	# ── 3. LA QUESTION QUI DÉCIDE : GridMap a-t-il une sélection ? ───────────────────────────────────
	print("\n── `GridMap` EXPOSE-T-IL UNE SÉLECTION ? ──")
	var interessantes: Array = []
	for m in ClassDB.class_get_method_list("GridMap", true):
		var nom: String = m["name"]
		if "select" in nom.to_lower() or "cell" in nom.to_lower():
			interessantes.append(nom)
	interessantes.sort()
	for nom in interessantes:
		print("   %s" % nom)
	var a_selection := false
	for nom in interessantes:
		if "select" in (nom as String).to_lower():
			a_selection = true
	print("\n   ⚠ notion de SÉLECTION exposée : %s" % ("OUI" if a_selection else "NON"))
	if not a_selection:
		print("     → les opérations « étendre / creuser / extruder » ne peuvent PAS lire la sélection")
		print("       en boîte du GridMap : elle appartient à son éditeur C++. Il faudra soit écrire")
		print("       notre propre sélection, soit opérer sur tout le massif ou sur un étage.")

	# ── 4. ce qu'un greffon peut intercepter dans la vue 3D ─────────────────────────────────────────
	print("\n── CE QU'UN GREFFON PEUT INTERCEPTER DANS LA VUE 3D ──")
	var forwards: Array = []
	for m in ClassDB.class_get_method_list("EditorPlugin", true):
		var nom: String = m["name"]
		if nom.begins_with("_forward") or nom.begins_with("_handles") or nom.begins_with("_edit"):
			forwards.append(nom)
	forwards.sort()
	for nom in forwards:
		print("   %s" % nom)

	print("\n⚠ Cette sonde ne conçoit rien. Elle dit ce qui existe.")
	quit(0)
