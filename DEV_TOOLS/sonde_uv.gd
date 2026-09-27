extends SceneTree
##
## SONDE — COMMENT LA TEXTURE D'UN SCULPT SE RÉPARTIT-ELLE SUR LES TUILES ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_uv.gd -- --fichier=C:/chemin/vers/le.glb
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## `planche_matiere.gd` a montré ce que quatre autres pistes n'expliquaient pas : le sol du TÉMOIN est
## une dalle uniforme, celui du SCULPT porte un Z vert au milieu du sombre. La texture est plaquée sur
## **le bloc**, et chaque tuile en reçoit le fragment qui se trouvait là.
##
## ⚠ **ET LA CONSÉQUENCE EST ACQUISE PAR CONSTRUCTION, PAS À MESURER** : les UV sont CUITES dans le
## maillage de la tuile. Chaque instance d'une tuile — le sol est posé des centaines de fois dans un
## monde — affiche donc **exactement le même fragment**. Il n'y a rien à vérifier là-dessus ; ce qui se
## mesure, c'est l'AMPLEUR du problème et ce qu'il autorise comme remède.
##
## ── CE QU'ELLE MESURE ───────────────────────────────────────────────────────────────────────────────
##
##   • l'étendue UV du bloc entier — et si elle DÉBORDE de 0–1, donc si la texture se répète déjà ;
##   • l'étendue UV de chaque tuile — un atlas fin (chaque tuile son coin) ou grossier ;
##   • le CHEVAUCHEMENT entre tuiles : si deux tuiles lisent la même zone de texture, une matière
##     uniforme suffirait ; si chacune a la sienne, la répétition sera visible et différente par tuile.
##
## ⚠ **AVEC SON CONTRÔLE NÉGATIF** : le témoin, qui n'a PAS d'UV du tout (mesuré : `UV NON`). Il doit
## donc rendre zéro partout — et si l'instrument lui trouve des UV, c'est l'instrument qui est faux.
##
## ⚠ **ELLE NE DIT PAS SI C'EST BEAU.** Un fragment répété peut très bien passer sur une matière
## uniforme et sauter aux yeux sur une texture dirigée. Ça, seule l'image le dira.

const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")

var _fichier := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--fichier="):
			_fichier = option.substr("--fichier=".length())

	print("=== COMMENT LA TEXTURE SE RÉPARTIT-ELLE SUR LES TUILES ? ===\n")

	# ⚠ LE CONTRÔLE NÉGATIF D'ABORD : le témoin n'a pas d'UV, l'instrument doit le dire.
	var temoin: MeshLibrary = (BM.librairie()["lot"] as MeshLibrary)
	var n_t := 0
	for id in temoin.get_item_list():
		if _boite_uv(temoin.get_item_mesh(id) as ArrayMesh) != null:
			n_t += 1
	print("── LE TÉMOIN (contrôle négatif) ──")
	print("   %d tuile(s) sur %d portent des UV  (attendu : 0 — le témoin n'en a pas)\n"
		% [n_t, temoin.get_item_list().size()])

	if _fichier == "" or not FileAccess.file_exists(_fichier):
		print("il faut --fichier=<un .glb sculpté existant>")
		quit(1)
		return

	var bilan: Dictionary = BM.librairie_depuis_glb(_fichier)
	if not (bilan["absents"] as Array).is_empty():
		print("⚠⚠ le bloc n'a PAS été relu du disque — cette sonde mesurerait le témoin calculé.")
		quit(1)
		return
	var lot: MeshLibrary = bilan["lot"]

	print("── LE SCULPT de Jordan ──")

	# ── l'étendue UV de chaque tuile ────────────────────────────────────────────────────────────────
	var boites: Array = []
	var globale: Rect2 = Rect2()
	var premier := true
	for id in lot.get_item_list():
		var r = _boite_uv(lot.get_item_mesh(id) as ArrayMesh)
		if r == null:
			continue
		var b: Rect2 = r
		boites.append({"nom": lot.get_item_name(id), "boite": b})
		if premier:
			globale = b
			premier = false
		else:
			globale = globale.merge(b)

	if boites.is_empty():
		print("   aucune tuile ne porte d'UV\n")
		quit(0)
		return

	print("   étendue UV de TOUTES les tuiles réunies : de (%.3f, %.3f) à (%.3f, %.3f)"
		% [globale.position.x, globale.position.y,
			globale.position.x + globale.size.x, globale.position.y + globale.size.y])
	# ⚠ DES UV HORS DE 0–1 VEULENT DIRE QUE LA TEXTURE SE RÉPÈTE DÉJÀ. Si c'est le cas, une matière
	# uniforme est probablement l'intention de l'artiste, et le « fragment par tuile » est moins grave.
	var deborde: bool = globale.position.x < -0.001 or globale.position.y < -0.001 \
		or globale.position.x + globale.size.x > 1.001 \
		or globale.position.y + globale.size.y > 1.001
	print("   → %s" % ("⚠ les UV DÉBORDENT de 0–1 : la texture se répète déjà (matière tuilable)"
		if deborde else "les UV tiennent dans 0–1 : c'est un ATLAS, chaque endroit du bloc a sa zone"))

	# ── la taille des fragments ─────────────────────────────────────────────────────────────────────
	var somme := 0.0
	var pire := 0.0
	var mini := 999.0
	for b in boites:
		var r2: Rect2 = b["boite"]
		var aire: float = r2.size.x * r2.size.y
		somme += aire
		pire = maxf(pire, aire)
		mini = minf(mini, aire)
	print("\n   %d tuile(s) avec UV  ·  fragment moyen %.4f de l'espace de texture  ·  du plus petit "
		% [boites.size(), somme / float(boites.size())]
		+ "%.4f au plus grand %.4f" % [mini, pire])

	# ── le chevauchement ────────────────────────────────────────────────────────────────────────────
	#
	# ⚠ C'EST LE CHIFFRE QUI ORIENTE LE REMÈDE. Si les tuiles lisent toutes la même zone, la texture est
	# une matière et le fragment importe peu. Si chacune a sa zone, chaque tuile porte un motif DIFFÉRENT
	# et répétera le sien des centaines de fois.
	var paires := 0
	var croisent := 0
	for i in boites.size():
		for j in range(i + 1, boites.size()):
			paires += 1
			if (boites[i]["boite"] as Rect2).intersects(boites[j]["boite"]):
				croisent += 1
	print("   %d paire(s) de tuiles  ·  %d se chevauchent en UV (%.1f %%)"
		% [paires, croisent, 100.0 * float(croisent) / maxf(1.0, float(paires))])

	print("\n   les cinq tuiles les plus posées d'un monde réel, et leur fragment :")
	for nom in ["mb_plaque_b4h0", "mb_plaque_b0h4", "mb_plaque_b2h2", "mb_arete_b2h0",
			"mb_coin_b1h0"]:
		var trouve := false
		for b in boites:
			if b["nom"] == nom:
				var r3: Rect2 = b["boite"]
				print("      %-22s de (%.3f, %.3f) à (%.3f, %.3f)  aire %.4f"
					% [nom, r3.position.x, r3.position.y,
						r3.position.x + r3.size.x, r3.position.y + r3.size.y,
						r3.size.x * r3.size.y])
				trouve = true
		if not trouve:
			print("      %-22s (pas d'UV)" % nom)

	# ── DÉGÉNÉRÉES, OU ATLAS DENSE ? ────────────────────────────────────────────────────────────────
	#
	# ⚠ **UNE AIRE DE 0,0001 A DEUX LECTURES OPPOSÉES, ET UNE BOÎTE ENGLOBANTE NE LES SÉPARE PAS.**
	#   • l'atlas est très DENSE à cet endroit, la tuile lit un vrai petit carré → c'est le placage
	#     de l'artiste, et il n'y a rien à corriger chez nous ;
	#   • les UV sont ÉCRASÉES, toutes au même point, parce que le découpage les a perdues → c'est
	#     NOTRE bogue, et il se corrige dans `decoupe.gd`.
	# Le nombre de valeurs DISTINCTES tranche : une seule veut dire écrasées.
	print("\n── DÉGÉNÉRÉES, OU ATLAS DENSE ? ──")
	for nom in ["mb_plaque_b4h0", "mb_plaque_b2h2", "mb_coin_b1h0"]:
		var id: int = lot.find_item_by_name(nom)
		if id < 0:
			continue
		var mesh: ArrayMesh = lot.get_item_mesh(id) as ArrayMesh
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var arrays: Array = mesh.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_TEX_UV] == null:
			print("   %-22s (pas d'UV)" % nom)
			continue
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		# ⚠ QUANTIFIÉES pour compter : comparer des flottants à l'identique ne fusionnerait rien, le
		# bruit de calcul suffisant à séparer deux valeurs qu'on voit confondues.
		var distinctes := {}
		for p in uv:
			distinctes["%d,%d" % [roundi(p.x * 100000.0), roundi(p.y * 100000.0)]] = true
		var apercu: Array = []
		for k in mini(4, uv.size()):
			apercu.append("(%.5f, %.5f)" % [uv[k].x, uv[k].y])
		print("   %-22s %d sommet(s), %d valeur(s) UV DISTINCTE(S)  %s"
			% [nom, uv.size(), distinctes.size(),
				"⚠ ÉCRASÉES" if distinctes.size() <= 1 else ""])
		print("      les premières : %s" % ", ".join(PackedStringArray(apercu)))

	print("\n⚠ Les UV sont CUITES : chaque instance d'une tuile montrera ce fragment-là, toujours le même.")
	print("   Si c'est acceptable ne se juge pas ici — seule une image d'un champ peint le dira.")
	quit(0)


## La boîte englobante des UV d'un maillage, ou `null` s'il n'en porte pas.
func _boite_uv(mesh: ArrayMesh):
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_TEX_UV] == null:
		return null
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if uv.is_empty():
		return null
	var mini := uv[0]
	var maxi := uv[0]
	for p in uv:
		mini = Vector2(minf(mini.x, p.x), minf(mini.y, p.y))
		maxi = Vector2(maxf(maxi.x, p.x), maxf(maxi.y, p.y))
	return Rect2(mini, maxi - mini)
