extends SceneTree
##
## SONDE — POURQUOI LES TUILES D'UN SCULPT RENDENT-ELLES NOIR ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/UnderMend \
##       --script res://DEV_TOOLS/sonde_normales.gd -- --fichier=C:/chemin/vers/le.glb
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## `planche_motifs.gd` a montré la chose que quatre autres instruments n'avaient pas vue : les tuiles
## tirées du `.glb` de Jordan ont **exactement les bonnes formes** — cube, barre, dalle, gros cube, aux
## mêmes places que le témoin — mais elles rendent **presque noires**.
##
## ⚠ **UNE FORME FAUSSE ET UNE MATIÈRE NOIRE NE SE SOIGNENT PAS PAREIL**, et j'ai passé une heure sur la
## première en croyant diagnostiquer la seconde. Deux causes possibles, et elles se comptent :
##
##   • **NORMALES RETOURNÉES** — une surface dont la normale pointe vers l'intérieur ne reçoit plus la
##     lumière. ⚠ Notre export part SANS normales exprès (la spécification glTF impose alors l'ombrage
##     plat) ; le fichier de Jordan en RAPPORTE, recalculées par Blender sur un maillage soudé.
##   • **MATÉRIAU SOMBRE** — le témoin porte `RP.matiere()` ; un `.glb` rapporte celui de Blender, et
##     `decoupe.gd` le transporte de bout en bout. Un albédo noir donne du noir quelle que soit la
##     géométrie.
##
## ⚠ **AVEC SON CONTRÔLE NÉGATIF** : la même mesure sur le témoin, qui rend clair. Si le témoin affiche
## autant de normales retournées que le sculpt, ce n'est pas ça — et l'instrument me l'aura dit au lieu
## de me laisser accuser le fichier de Jordan sur une impression.
##
## ⚠ **ELLE NE CORRIGE RIEN.** Elle compte.

const BM := preload("res://addons/undermend/blocs_maitres.gd")

var _fichier := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--fichier="):
			_fichier = option.substr("--fichier=".length())

	print("=== POURQUOI ÇA REND NOIR ? ===\n")
	print("Convention : Godot enroule ses faces avant dans le sens HORAIRE, donc la normale SORTANTE")
	print("est l'OPPOSÉ du produit vectoriel de l'ordre stocké. S'en dispenser inverserait toute la")
	print("mesure sans qu'aucun compteur ne s'en plaigne.\n")

	# ⚠ LE CONTRÔLE NÉGATIF D'ABORD : le témoin soudé porte des normales, et il rend CLAIR.
	_examiner("LE TÉMOIN soudé (contrôle négatif — rend clair)", BM.souder(BM.maillage_moitie(0)))

	if _fichier == "":
		print("(pas de --fichier= : seul le témoin a été mesuré)")
		quit(0)
		return
	if not FileAccess.file_exists(_fichier):
		print("⚠ INTROUVABLE : %s" % _fichier)
		quit(1)
		return
	var brut: ArrayMesh = _lire(_fichier)
	if brut == null:
		print("⚠ illisible comme glTF")
		quit(1)
		return
	_examiner("LE SCULPT de Jordan", brut)

	print("⚠ Cette sonde ne corrige rien. Elle dit LAQUELLE des deux causes est en jeu.")
	quit(0)


func _examiner(quoi: String, mesh: ArrayMesh) -> void:
	print("── %s ──" % quoi)
	if mesh == null or mesh.get_surface_count() == 0:
		print("   ⚠ maillage vide\n")
		return

	var retournees := 0
	var alignees := 0
	var absentes := 0
	var obliques := 0
	var total := 0

	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] \
			if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
			if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
		if n.is_empty():
			print("   le maillage NE PORTE PAS de normales : ombrage plat imposé par la spécification")
			continue
		for t in range(0, idx.size() - 2, 3):
			var a: int = idx[t]
			var b: int = idx[t + 1]
			var c: int = idx[t + 2]
			# ⚠ SORTANTE = l'OPPOSÉ du produit vectoriel, à cause de l'enroulement horaire.
			var geo: Vector3 = -(v[b] - v[a]).cross(v[c] - v[a])
			if geo.length_squared() < 0.000000001:
				continue
			geo = geo.normalized()
			var stockee: Vector3 = (n[a] + n[b] + n[c])
			if stockee.length_squared() < 0.000001:
				absentes += 1
				total += 1
				continue
			stockee = stockee.normalized()
			var d: float = geo.dot(stockee)
			total += 1
			if d < -0.5:
				retournees += 1
			elif d > 0.5:
				alignees += 1
			else:
				obliques += 1

	if total == 0:
		print("   (aucun triangle mesurable)\n")
		return
	print("   %d triangle(s) mesurés :" % total)
	print("      alignées avec la géométrie : %6d  (%5.1f %%)"
		% [alignees, 100.0 * float(alignees) / float(total)])
	print("      ⚠ RETOURNÉES (vers l'intérieur) : %6d  (%5.1f %%)"
		% [retournees, 100.0 * float(retournees) / float(total)])
	print("      obliques (ni l'un ni l'autre) : %6d  (%5.1f %%)"
		% [obliques, 100.0 * float(obliques) / float(total)])
	print("      normales nulles : %d" % absentes)

	_dire_la_matiere(mesh)
	print("")


## Ce que le matériau du maillage apporte. ⚠ `decoupe.gd` le transporte de bout en bout : celui du
## fichier arrive donc jusqu'à la tuile posée, et un albédo noir donne du noir quelle que soit la forme.
func _dire_la_matiere(mesh: ArrayMesh) -> void:
	var m: Material = mesh.surface_get_material(0)
	if m == null:
		print("   matériau : AUCUN (la tuile prendra celui du moteur par défaut)")
		return
	print("   matériau : %s" % m.get_class())
	var std := m as StandardMaterial3D
	if std == null:
		print("      (ce n'est pas un StandardMaterial3D : rien de plus à lire ici)")
		return
	print("      albédo       : %s" % str(std.albedo_color))
	print("      texture      : %s" % ("OUI" if std.albedo_texture != null else "aucune"))
	print("      cull_mode    : %d   (0=arrière écartées, 1=avant, 2=aucune)" % std.cull_mode)
	print("      shading_mode : %d   (0=non éclairé, 1=par pixel)" % std.shading_mode)
	print("      couleur des sommets employée : %s" % str(std.vertex_color_use_as_albedo))
	# ⚠ LE PIÈGE EXACT : un maillage qui porte `ARRAY_COLOR` mais dont le matériau ne la lit PAS rend
	# la couleur du seul albédo. Le témoin coche cette case ; un matériau venu de Blender, non.
	if not std.vertex_color_use_as_albedo:
		print("      ⚠ la COULEUR DES SOMMETS est ignorée par ce matériau — le vert du dessus,")
		print("        le brun des parois et le bleu des plafonds ne seront pas rendus.")


func _lire(chemin: String) -> ArrayMesh:
	var document := GLTFDocument.new()
	var etat := GLTFState.new()
	if document.append_from_file(chemin, etat) != OK:
		return null
	var scene: Node = document.generate_scene(etat)
	if scene == null:
		return null
	var trouve: ArrayMesh = _chercher(scene)
	scene.queue_free()
	return trouve


## ⚠ ON RECONNAÎT UN NŒUD À CE QU'IL SAIT FAIRE : le chemin glTF de l'éditeur rend des
## `ImporterMeshInstance3D`, qui N'HÉRITENT PAS de `MeshInstance3D`.
func _chercher(noeud: Node) -> ArrayMesh:
	if noeud.has_method("get_mesh"):
		var m = noeud.call("get_mesh")
		if m is ArrayMesh:
			return m
	for enfant in noeud.get_children():
		var t: ArrayMesh = _chercher(enfant)
		if t != null:
			return t
	return null
