extends SceneTree
##
## SONDE — LES PIÈCES TIRÉES D'UN SCULPT TIENNENT-ELLES DANS LEUR CASE ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_pieces_sculptees.gd -- --fichier=C:/chemin/vers/le.glb
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## Jordan, 25 septembre 2026, capture à l'appui : *« la peinture ne recrée pas du tout les bonnes
## formes »*. Chaque case peinte rend un gros morceau complexe, à trous et à redans, là où une case
## seule devrait donner huit petites pièces de coin.
##
## ⚠ **ET TOUS LES COMPTEURS SONT VERTS** : `sonde_import.gd` rend « 1 bloc relu, 68 item(s), 0
## manquante, 0 erreur » sur ce même fichier. C'est le cas que la charte §6 décrit mot pour mot — *un
## compteur vert ne dit jamais qu'une tuile est à SA place*. Il faut donc mesurer les pièces
## elles-mêmes, pas leur nombre.
##
## ── CE QU'ELLE MESURE ───────────────────────────────────────────────────────────────────────────────
##
## La BOÎTE ENGLOBANTE de chaque pièce du lot. Une pièce Marching Blocks est centrée sur un sommet et
## couvre les huit demi-cases autour : elle tient donc dans **1 × 1 × 1**. Le relief a le droit de
## déborder (règle (A)), mais d'une fraction de case — pas de plusieurs cases.
##
## ⚠ **ET ELLE LE FAIT AVEC SON CONTRÔLE NÉGATIF** : la même mesure sur le lot du TÉMOIN non sculpté.
## Sans lui, j'accuserais le fichier de Jordan sur une impression, alors que le défaut peut être dans
## notre extraction — auquel cas les deux lots déborderaient pareil. Un contrôle qui s'inverse invalide
## l'instrument, pas le sujet.

const BM := preload("res://addons/marching_blocks_plugin_godot/blocs_maitres.gd")

var _fichier := ""


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--fichier="):
			_fichier = option.substr("--fichier=".length())

	print("=== LES PIÈCES TIENNENT-ELLES DANS LEUR CASE ? ===\n")
	print("Une pièce couvre les huit demi-cases autour d'un sommet : elle doit tenir dans 1 × 1 × 1.")
	print("Le relief peut déborder (règle A), mais d'une fraction de case — pas de plusieurs.\n")

	# ⚠ LE CONTRÔLE NÉGATIF D'ABORD, pour savoir à quoi ressemble « correct » avant de juger le sculpt.
	var temoin: Dictionary = BM.librairie()
	_examiner("LE TÉMOIN non sculpté (contrôle négatif)", temoin)

	if _fichier == "":
		print("\n(pas de --fichier= : seul le témoin a été mesuré)")
		quit(0)
		return
	if not FileAccess.file_exists(_fichier):
		print("\n⚠ INTROUVABLE : %s" % _fichier)
		quit(1)
		return

	var sculpte: Dictionary = BM.librairie_depuis_glb(_fichier)
	print("relu du disque : %s   ·   absent(s) : %s"
		% [str(sculpte["sculptes"]), str(sculpte["absents"])])
	_examiner("LE SCULPT de Jordan", sculpte)

	print("\n⚠ Cette sonde ne corrige rien. Elle dit si les pièces ont la bonne TAILLE,")
	print("   jamais si elles ont la bonne FORME — ça, seule une image le dit.")
	quit(0)


func _examiner(quoi: String, bilan: Dictionary) -> void:
	print("── %s ──" % quoi)
	var lot: MeshLibrary = bilan["lot"]
	var ids: Array = lot.get_item_list()
	if ids.is_empty():
		print("   ⚠ lot VIDE\n")
		return

	var debordent: Array = []
	var pire := 0.0
	var somme := 0.0
	var boites := {}
	for id in ids:
		var mesh: Mesh = lot.get_item_mesh(id)
		if mesh == null:
			continue
		var b: AABB = mesh.get_aabb()
		var plus_grand: float = maxf(b.size.x, maxf(b.size.y, b.size.z))
		somme += plus_grand
		pire = maxf(pire, plus_grand)
		# on range par demi-case, pour voir la distribution d'un coup d'œil
		var casier := "%.1f" % (floorf(plus_grand * 2.0) / 2.0)
		boites[casier] = int(boites.get(casier, 0)) + 1
		if plus_grand > 1.25:   # 1 case + un quart de débord toléré
			debordent.append({"nom": lot.get_item_name(id), "taille": b.size, "coin": b.position})

	var cles: Array = boites.keys()
	cles.sort()
	print("   %d pièce(s)  ·  plus grand côté moyen %.2f  ·  PIRE %.2f case(s)"
		% [ids.size(), somme / float(ids.size()), pire])
	var apercu: Array = []
	for c in cles:
		apercu.append("%s→%d" % [c, boites[c]])
	print("   distribution du plus grand côté : %s" % ", ".join(PackedStringArray(apercu)))
	print("   ⚠ %d pièce(s) dépassent 1,25 case" % debordent.size())
	for d in debordent.slice(0, 8):
		print("      %-26s taille %s   coin %s"
			% [d["nom"], str(d["taille"]).pad_decimals(2), str(d["coin"]).pad_decimals(2)])
	print("")
