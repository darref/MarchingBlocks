extends SceneTree
##
## SONDE — pourquoi un `.glb` sculpté échoue-t-il au pipeline ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_import.gd -- --fichier=C:/chemin/vers/le.glb
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## Le pipeline dit « ça échoue » ; il ne dit pas OÙ. Entre le fichier sur le disque et les 68 classes,
## il y a six étages, et une panne à n'importe lequel ressemble à la même chose vue de la sortie :
##
##   1. le fichier se lit-il ? (`GLTFDocument.append_from_file`)
##   2. contient-il un maillage, et un seul ?
##   3. ce maillage est-il à la bonne ÉCHELLE et au bon ENDROIT ?
##   4. chaque bloc est-il dans sa boîte ?
##   5. chaque bloc extrait se tranche-t-il sans erreur ?
##   6. les 68 classes sortent-elles ?
##
## ⚠ **ELLE N'EN CORRIGE AUCUNE.** Elle imprime. J'ai déjà supposé deux causes fausses aujourd'hui sur
## des sujets voisins ; ici les hypothèses plausibles sont au moins cinq — échelle en mètres, axe haut
## inversé, origine décalée, bloc déplacé, maillage multiple — et rien ne les départage sans mesure.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const Decoupe := preload("res://addons/marchingblocks_core/decoupe.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")
const BlocsMaitres := preload("res://addons/marchingblocks_core/blocs_maitres.gd")

var _fichier := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--fichier="):
			_fichier = option.substr("--fichier=".length())
	if _fichier == "":
		print("il faut --fichier=<chemin vers un .glb>")
		quit(1)
		return

	print("=== SONDE D'IMPORT ===\n")
	print("fichier : %s" % _fichier)

	# ── 1. le fichier ───────────────────────────────────────────────────────────────────────────────
	if not FileAccess.file_exists(_fichier):
		print("⚠ INTROUVABLE.")
		quit(1)
		return
	print("   taille : %d octets\n" % FileAccess.get_file_as_bytes(_fichier).size())

	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	var err: int = document.append_from_file(_fichier, etat)
	if err != OK:
		print("⚠ append_from_file a rendu %d — le fichier n'est pas lisible comme glTF." % err)
		quit(1)
		return
	var scene: Node = document.generate_scene(etat)
	if scene == null:
		print("⚠ generate_scene rend null.")
		quit(1)
		return

	# ── 2. les maillages ────────────────────────────────────────────────────────────────────────────
	print("── LES MAILLAGES TROUVÉS ──")
	var trouves: Array = []
	_recenser(scene, scene, trouves)
	if trouves.is_empty():
		print("   ⚠ AUCUN maillage dans ce fichier.")
		quit(1)
		return
	for t in trouves:
		print("   « %s »  %d surface(s), %d sommet(s), boîte %s taille %s"
			% [t["chemin"], t["surfaces"], t["sommets"],
				str(t["boite"].position), str(t["boite"].size)])
	if trouves.size() > 1:
		print("   ⚠ PLUSIEURS maillages : le pipeline ne prend QUE le premier rencontré.")
		print("     Dans un logiciel de modélisation, « joindre » les objets en un seul évite ça.")

	var mesh: ArrayMesh = trouves[0]["mesh"]
	var boite: AABB = trouves[0]["boite"]

	# ── 3. l'échelle et la place ────────────────────────────────────────────────────────────────────
	# ⚠ Un bloc UNIQUE, donc une étendue cubique. L'ancienne formule ajoutait le pas de bande sur x,
	# pour neuf blocs alignés : elle n'a plus d'objet.
	var attendue := Vector3(
		float(BlocsMaitres.COTE), float(BlocsMaitres.COTE), float(BlocsMaitres.COTE))
	print("\n── L'ÉCHELLE ET LA PLACE ──")
	print("   étendue attendue : de (0, 0, 0) à %s" % str(attendue))
	print("   étendue trouvée  : de %s à %s" % [str(boite.position), str(boite.position + boite.size)])
	var facteur := Vector3(
		boite.size.x / maxf(attendue.x, 0.001),
		boite.size.y / maxf(attendue.y, 0.001),
		boite.size.z / maxf(attendue.z, 0.001))
	print("   rapport de taille : %s" % str(facteur))
	if absf(facteur.x - 1.0) > 0.1 or absf(facteur.y - 1.0) > 0.1 or absf(facteur.z - 1.0) > 0.1:
		print("   ⚠ LE MAILLAGE N'EST PAS À L'ÉCHELLE ATTENDUE.")
		print("     Un rapport proche de 0,01 veut dire des CENTIMÈTRES ; 100, des unités trop grandes.")
		print("     Un rapport qui permute y et z veut dire un axe HAUT différent (Z-up contre Y-up).")
	if boite.position.length() > 0.6:
		print("   ⚠ L'ORIGINE EST DÉCALÉE de %s — le bloc doit commencer en (0, 0, 0)."
			% str(boite.position))

	# ── 4. les attributs ────────────────────────────────────────────────────────────────────────────
	var arrays: Array = mesh.surface_get_arrays(0)
	print("\n── LES ATTRIBUTS DU PREMIER MAILLAGE ──")
	print("   normales : %s   ·   couleurs : %s   ·   indexé : %s   ·   UV : %s"
		% [arrays[Mesh.ARRAY_NORMAL] != null, arrays[Mesh.ARRAY_COLOR] != null,
			arrays[Mesh.ARRAY_INDEX] != null, arrays[Mesh.ARRAY_TEX_UV] != null])

	# ── 5. le bloc est-il dans sa boîte ? ───────────────────────────────────────────────────────────
	print("\n── LE BLOC DANS SA BOÎTE ──")
	var b: AABB = BlocsMaitres.boite_du_bloc()
	var extrait: ArrayMesh = Decoupe.trancher(mesh, b)
	var aire: float = Decoupe.aire(extrait)
	if extrait.get_surface_count() == 0 or aire <= 0.0001:
		print("   ⚠ BOÎTE VIDE (de %s à %s) — le bloc a été DÉPLACÉ dans le modeleur, ou n'est pas"
			% [str(b.position).pad_decimals(1), str(b.position + b.size).pad_decimals(1)])
		print("     à l'échelle. Le greffon retombera sur la version calculée en le SIGNALANT.")
	else:
		var eb: AABB = extrait.get_aabb()
		print("   %-24s aire %8.2f, boîte %s → %s"
			% [BlocsMaitres.BLOCS[0]["nom"], aire,
				str(eb.position).pad_decimals(1), str(eb.position + eb.size).pad_decimals(1)])

	# ── 6. le tranchage ─────────────────────────────────────────────────────────────────────────────
	print("\n── LE TRANCHAGE ──")
	var bilan: Dictionary = BlocsMaitres.librairie_depuis_glb(_fichier)
	print("   %d bloc(s) relu(s) : %s"
		% [(bilan["sculptes"] as Array).size(), ", ".join(PackedStringArray(bilan["sculptes"]))])
	if not (bilan["absents"] as Array).is_empty():
		print("   ⚠ %d NON relu(s) : %s"
			% [(bilan["absents"] as Array).size(), ", ".join(PackedStringArray(bilan["absents"]))])
	var lot: MeshLibrary = bilan["lot"]
	print("   %d item(s) sur %d classes, %d manquante(s), %d erreur(s)"
		% [lot.get_item_list().size(), MB.pieces_a_sculpter().size(),
			(bilan["manquantes"] as Array).size(), (bilan["erreurs"] as Array).size()])
	for e in (bilan["erreurs"] as Array).slice(0, 15):
		print("      • %s" % String(e).left(170))
	if not (bilan["manquantes"] as Array).is_empty():
		print("   manquantes : %s"
			% ", ".join(PackedStringArray((bilan["manquantes"] as Array).slice(0, 12))))

	scene.queue_free()
	print("\n⚠ Cette sonde ne corrige rien. Elle dit à quel étage ça casse.")
	quit(0)


func _recenser(noeud: Node, racine: Node, sortie: Array) -> void:
	if noeud is MeshInstance3D and (noeud as MeshInstance3D).mesh != null:
		var m: ArrayMesh = (noeud as MeshInstance3D).mesh as ArrayMesh
		if m != null:
			var sommets := 0
			for s in m.get_surface_count():
				var a: Array = m.surface_get_arrays(s)
				if not a.is_empty():
					sommets += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			sortie.append({
				"chemin": String(racine.get_path_to(noeud)),
				"mesh": m,
				"surfaces": m.get_surface_count(),
				"sommets": sommets,
				"boite": m.get_aabb(),
			})
	for enfant in noeud.get_children():
		_recenser(enfant, racine, sortie)
