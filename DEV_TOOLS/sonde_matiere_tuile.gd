extends SceneTree
##
## SONDE — QU'EST-CE QU'UNE TUILE EMPORTE VRAIMENT, UNE FOIS TRANCHÉE ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_matiere_tuile.gd -- --fichier=C:/chemin/vers/le.glb
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## ⚠ **UN FAIT QUE MON DIAGNOSTIC N'EXPLIQUAIT PAS.** Le `.glb` de Jordan rend **texturé** quand on
## affiche le bloc entier (brun et vert, parfaitement lisible), et ses **tuiles rendent noires** —
## même fichier, même éclairage, même caméra. La différence n'est donc pas dans le matériau du fichier :
## elle est dans ce que le DÉCOUPAGE laisse passer.
##
## J'allais corriger `vertex_color_use_as_albedo` sur le matériau importé. ⚠ C'aurait été soigner un
## symptôme dont la cause est ailleurs — et me tromper une quatrième fois d'instrument dans la même
## nuit. On mesure d'abord ce qu'une tuile porte.
##
## ── CE QU'ELLE COMPARE ──────────────────────────────────────────────────────────────────────────────
##
## Trois étages du même objet, dans l'ordre où le pipeline les produit :
##
##   1. le maillage BRUT lu du `.glb` ;
##   2. le maillage EXTRAIT (découpé dans la boîte du bloc) ;
##   3. une TUILE du lot final.
##
## Et pour chacun : matériau présent ? texture ? UV ? couleurs de sommets ? ⚠ Le premier étage où l'un
## d'eux disparaît est la cause — et la charte enregistre déjà ce piège exact : *« `decoupe.gd` doit
## transporter `ARRAY_COLOR` de bout en bout. L'oublier tout en gardant le matériau donne une planche
## blanche, sans une seule erreur. »*
##
## ⚠ **AVEC SON CONTRÔLE NÉGATIF** : la même colonne pour le TÉMOIN, dont les tuiles rendent claires.
## Si le témoin perd les mêmes attributs au même étage, ce n'est pas ça — et l'instrument me l'aura dit.

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const Decoupe := preload("res://addons/marchingblocks_core/decoupe.gd")

var _fichier := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--fichier="):
			_fichier = option.substr("--fichier=".length())

	print("=== QU'EST-CE QU'UNE TUILE EMPORTE ? ===\n")

	# ── LE CONTRÔLE NÉGATIF : le témoin, dont les tuiles rendent CLAIRES ─────────────────────────────
	print("── LE TÉMOIN (contrôle négatif — ses tuiles rendent claires) ──")
	var solide: ArrayMesh = BM.maillage_moitie(0)
	_dire("1. le solide calculé", solide)
	var lot_t: MeshLibrary = (BM.librairie()["lot"] as MeshLibrary)
	_dire_tuile("3. une tuile du lot", lot_t)
	print("")

	if _fichier == "":
		print("(pas de --fichier= : seul le témoin a été mesuré)")
		quit(0)
		return
	if not FileAccess.file_exists(_fichier):
		print("⚠ INTROUVABLE : %s" % _fichier)
		quit(1)
		return

	print("── LE SCULPT de Jordan ──")
	var brut: ArrayMesh = _lire(_fichier)
	if brut == null:
		print("⚠ illisible comme glTF")
		quit(1)
		return
	_dire("1. le maillage BRUT lu du .glb", brut)
	var extrait: ArrayMesh = Decoupe.trancher(brut, BM.boite_du_bloc())
	_dire("2. le maillage EXTRAIT (découpé dans la boîte du bloc)", extrait)
	var bilan: Dictionary = BM.librairie_depuis_glb(_fichier)
	_dire_tuile("3. une tuile du lot", bilan["lot"])

	print("\n⚠ Le PREMIER étage où un attribut disparaît est la cause. Cette sonde ne corrige rien.")
	quit(0)


func _dire_tuile(quoi: String, lot: MeshLibrary) -> void:
	# ⚠ ON PREND UNE TUILE NOMMÉE, PAS LA PREMIÈRE VENUE : `mb_plaque_b4h0` est le SOL, la tuile la plus
	# posée d'un monde réel. Juger sur un échantillon au hasard, c'est risquer de tomber sur un cas
	# particulier et d'en tirer une règle.
	var id: int = lot.find_item_by_name("mb_plaque_b4h0")
	if id < 0:
		print("   %s : « mb_plaque_b4h0 » ABSENTE du lot" % quoi)
		return
	_dire("%s (« mb_plaque_b4h0 », le sol)" % quoi, lot.get_item_mesh(id) as ArrayMesh)


func _dire(quoi: String, mesh: ArrayMesh) -> void:
	if mesh == null or mesh.get_surface_count() == 0:
		print("   %-46s ⚠ VIDE" % quoi)
		return
	var arrays: Array = mesh.surface_get_arrays(0)
	var uv: bool = arrays[Mesh.ARRAY_TEX_UV] != null
	var couleurs: bool = arrays[Mesh.ARRAY_COLOR] != null
	var m: Material = mesh.surface_get_material(0)
	var std := m as StandardMaterial3D

	var dit := "matériau %s" % ("AUCUN" if m == null else m.get_class())
	if std != null:
		dit += ", texture %s" % ("OUI" if std.albedo_texture != null else "aucune")
		dit += ", vcol=%s" % ("oui" if std.vertex_color_use_as_albedo else "NON")
		dit += ", cull=%d" % std.cull_mode
	print("   %-46s UV %-3s  couleurs %-3s  %s"
		% [quoi, "oui" if uv else "NON", "oui" if couleurs else "NON", dit])


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


## ⚠ ON RECONNAÎT UN NŒUD À CE QU'IL SAIT FAIRE : `ImporterMeshInstance3D` N'HÉRITE PAS de
## `MeshInstance3D`, et un `is MeshInstance3D` a déjà déclaré « aucun ArrayMesh » sur un fichier sain.
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
