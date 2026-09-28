extends SceneTree
##
## SONDE — D'OÙ VIENT CHAQUE TUILE, ET EN COMBIEN DE MORCEAUX EST-ELLE ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_provenance_pieces.gd -- --fichier=C:/chemin/vers/le.glb
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## Jordan, 25 septembre 2026 : *« la peinture ne recrée pas du tout les bonnes formes »*, après avoir
## peint avec le lot importé de son propre `.glb` sculpté.
##
## ⚠ **ET TOUT EST VERT EN AMONT** : 1 bloc relu, 68 classes, 0 manquante, 0 erreur d'octant, et les
## pièces mesurent la BONNE TAILLE (1,00 case au pire, distribution identique au témoin). Le défaut
## n'est donc ni dans la lecture, ni dans l'extraction, ni dans l'attribution.
##
## ── L'HYPOTHÈSE QU'ELLE ÉPROUVE ─────────────────────────────────────────────────────────────────────
##
## `tranchage.gd` garde la PREMIÈRE pièce rencontrée pour chaque classe (`if pieces.has(nom): continue`)
## et balaie depuis `(0,0,0)`. **Chaque classe est donc prise au premier sommet qui la produit, pas à un
## endroit représentatif.** Sur un bloc sculpté comme un paysage, la tuile de sol plat — 30 % d'un monde
## réel — peut être un bout de paroi percé d'un trou qui traînait dans le coin bas du bloc.
##
## Deux mesures le disent :
##   • la PROVENANCE : à quel sommet chaque classe a été prise ;
##   • le nombre de MORCEAUX DISJOINTS : une tuile de coin propre en a UN ; un fragment d'architecture
##     arbitraire en a plusieurs. La capture de Jordan montre des lamelles séparées.
##
## ⚠ **ET SON CONTRÔLE NÉGATIF** : la même mesure sur le témoin non sculpté. Si le témoin aussi rend des
## pièces en plusieurs morceaux, le défaut est chez nous et le sculpt n'y est pour rien.
##
## ── CE QUE CET INSTRUMENT A DE FRAGILE, ET IL FAUT LE DIRE ──────────────────────────────────────────
##
## ⚠ Le trancheur n'enregistre pas la provenance : je dois donc **RÉÉNUMÉRER les sommets** ici, ce qui
## fait une SECONDE DESCRIPTION du balayage — et deux descriptions d'un même fait divergent toujours
## (charte §6). Je ne duplique que l'ÉNUMÉRATION, jamais la découpe, et je la vérifie : elle doit rendre
## exactement le même jeu de noms que `librairie()`. Si les deux jeux diffèrent, mon énumération ne
## décrit pas le balayage réel et la colonne « provenance » ne vaut rien.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")

var _fichier := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--fichier="):
			_fichier = option.substr("--fichier=".length())

	print("=== D'OÙ VIENT CHAQUE TUILE, ET EN COMBIEN DE MORCEAUX ? ===\n")

	# ── la provenance, et le contrôle de fidélité de mon énumération ─────────────────────────────────
	var provenance: Dictionary = _premier_sommet_par_classe()
	var temoin: Dictionary = BM.librairie()
	var noms_lot: Array = _noms(temoin["lot"])
	var noms_enum: Array = provenance.keys()
	noms_enum.sort()
	print("── FIDÉLITÉ DE MON ÉNUMÉRATION ──")
	print("   classes vues par mon balayage : %d   ·   items dans le lot : %d"
		% [noms_enum.size(), noms_lot.size()])
	if noms_enum == noms_lot:
		print("   ✓ les deux jeux sont IDENTIQUES : mon énumération décrit bien le balayage réel\n")
	else:
		print("   ⚠⚠ LES JEUX DIFFÈRENT — la colonne « provenance » ci-dessous NE VAUT RIEN.")
		print("      vues et pas dans le lot : %s" % str(_sauf(noms_enum, noms_lot).slice(0, 8)))
		print("      dans le lot et pas vues : %s\n" % str(_sauf(noms_lot, noms_enum).slice(0, 8)))

	_examiner("LE TÉMOIN non sculpté (contrôle négatif)", temoin, provenance)

	if _fichier == "":
		print("(pas de --fichier= : seul le témoin a été mesuré)")
		quit(0)
		return
	if not FileAccess.file_exists(_fichier):
		print("⚠ INTROUVABLE : %s" % _fichier)
		quit(1)
		return
	_examiner("LE SCULPT de Jordan", BM.librairie_depuis_glb(_fichier), provenance)

	print("⚠ Cette sonde ne dit pas si une forme est BELLE — seulement si elle est d'un seul tenant")
	print("   et d'où elle a été prise. Le reste ne se voit qu'à l'image.")
	quit(0)


## Le premier sommet qui produit chaque classe, dans l'ordre exact du balayage de `trancher()`.
##
## ⚠ `peau = false` : seuls les sommets dont les huit cellules sont DANS le bloc, donc `0 .. COTE-2`.
func _premier_sommet_par_classe() -> Dictionary:
	var pleines: Dictionary = BM.cases(0)
	var premier := {}
	for vx in range(0, BM.COTE - 1):
		for vy in range(0, BM.COTE - 1):
			for vz in range(0, BM.COTE - 1):
				var v := Vector3i(vx, vy, vz)
				var r: Dictionary = MB.classer(MB.bits(pleines, v))
				if not r["surface"] or premier.has(r["nom"]):
					continue
				premier[r["nom"]] = v
	return premier


func _examiner(quoi: String, bilan: Dictionary, provenance: Dictionary) -> void:
	print("── %s ──" % quoi)
	var lot: MeshLibrary = bilan["lot"]
	var ids: Array = lot.get_item_list()
	if ids.is_empty():
		print("   ⚠ lot VIDE\n")
		return

	var par_morceaux := {}
	var eclatees: Array = []
	for id in ids:
		var mesh: ArrayMesh = lot.get_item_mesh(id) as ArrayMesh
		if mesh == null:
			continue
		var n: int = _morceaux(mesh)
		par_morceaux[n] = int(par_morceaux.get(n, 0)) + 1
		if n > 1:
			var nom: String = lot.get_item_name(id)
			eclatees.append({"nom": nom, "morceaux": n,
				"ou": provenance.get(nom, Vector3i(-1, -1, -1))})

	var cles: Array = par_morceaux.keys()
	cles.sort()
	var apercu: Array = []
	for c in cles:
		apercu.append("%d morceau(x)→%d tuile(s)" % [c, par_morceaux[c]])
	print("   %d tuile(s)  ·  %s" % [ids.size(), ", ".join(PackedStringArray(apercu))])

	# ⚠ ON TRIE PAR NOMBRE DE MORCEAUX : les pires en premier, parce que ce sont elles qu'on verra.
	eclatees.sort_custom(func(a, b): return int(a["morceaux"]) > int(b["morceaux"]))
	if eclatees.is_empty():
		print("   → toutes les tuiles sont d'UN SEUL TENANT")
	else:
		print("   ⚠ %d tuile(s) en PLUSIEURS morceaux — les dix pires, avec le sommet d'où elles viennent :"
			% eclatees.size())
		for e in eclatees.slice(0, 10):
			print("      %-26s %2d morceaux   pris au sommet %s"
				% [e["nom"], int(e["morceaux"]), str(e["ou"])])
	print("")


## Combien de morceaux DISJOINTS un maillage contient — par propagation sur les sommets confondus.
##
## ⚠ Les sommets sont rapprochés par POSITION quantifiée, pas par indice : une pièce sortie du trancheur
## n'est pas forcément indexée, et deux sommets distincts à la même place forment une seule matière —
## c'est ce que l'œil verra.
func _morceaux(mesh: ArrayMesh) -> int:
	if mesh.get_surface_count() == 0:
		return 0
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
		if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
	if idx.is_empty():
		return 0

	var chef := {}          # clé de position → représentant
	var cle_de: Array = []
	for k in v.size():
		cle_de.append("%d,%d,%d" % [roundi(v[k].x * 10000.0), roundi(v[k].y * 10000.0),
			roundi(v[k].z * 10000.0)])
	for c in cle_de:
		if not chef.has(c):
			chef[c] = c

	for t in range(0, idx.size() - 2, 3):
		var a: String = cle_de[idx[t]]
		var b: String = cle_de[idx[t + 1]]
		var c2: String = cle_de[idx[t + 2]]
		_unir(chef, a, b)
		_unir(chef, a, c2)

	var racines := {}
	for c in chef:
		racines[_racine(chef, c)] = true
	return racines.size()


func _racine(chef: Dictionary, x: String) -> String:
	var r: String = x
	while String(chef[r]) != r:
		r = String(chef[r])
	return r


func _unir(chef: Dictionary, a: String, b: String) -> void:
	var ra: String = _racine(chef, a)
	var rb: String = _racine(chef, b)
	if ra != rb:
		chef[ra] = rb


func _noms(lot: MeshLibrary) -> Array:
	var sortie: Array = []
	for id in lot.get_item_list():
		sortie.append(lot.get_item_name(id))
	sortie.sort()
	return sortie


func _sauf(a: Array, b: Array) -> Array:
	var dans_b := {}
	for x in b:
		dans_b[x] = true
	var sortie: Array = []
	for x in a:
		if not dans_b.has(x):
			sortie.append(x)
	return sortie
