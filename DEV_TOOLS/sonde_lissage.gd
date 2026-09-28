extends SceneTree
##
## SONDE — LE LISSAGE TIENT-IL SES TROIS PROMESSES ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_lissage.gd
##
## ── LA PRÉDICTION DE JORDAN, QUI EST L'OBJET DE CETTE SONDE ─────────────────────────────────────────
##
## Jordan, 25 septembre 2026 : *« je pense que là où trois contremarches se rencontrent, le triangle
## qu'on créera en chanfreinant rendra beaucoup d'endroits non manifold. »*
##
## ⚠ **ELLE EST JUSTE POUR LE GESTE LITTÉRAL, et cette sonde ne sert pas à la contredire** : elle sert
## à vérifier que la méthode choisie à la place — le maillage DUAL — la rend structurellement
## impossible. Si les arêtes non-manifold AUGMENTENT, la méthode est mauvaise et Jordan avait raison
## jusqu'au bout.
##
## **La référence est connue et mesurée : 18 arêtes ambiguës sur la coque actuelle.** Elles viennent de
## l'OCCUPATION (deux cellules qui ne se touchent que par une arête, `PONT_SUR_FACE_AMBIGUE`), pas du
## mailleur — le lissage n'a donc aucune raison de les faire disparaître, mais il n'a pas le droit d'en
## ajouter.
##
## ── LES TROIS PROMESSES, ET AUCUNE NE SE DÉDUIT DES AUTRES ──────────────────────────────────────────
##
##   1. TOPOLOGIE   soudé, sans trou, arêtes non-manifold pas plus nombreuses qu'avant ;
##   2. RÉCOLTE     les mêmes classes sortent du trancheur, avec zéro erreur d'octant ;
##   3. ESCALIERS   les paliers d'un sous-voxel ont bien disparu — sinon le lissage n'a rien réglé.
##
## ⚠ **ET UNE PROMESSE QU'ELLE NE PEUT PAS TENIR** : dire si ça a l'air JUSTE. Trois fois dans ce
## projet la couverture était parfaite et le rendu faux ; seule une image l'a montré. Voir
## `planche_lissage.gd`, à lancer AVEC fenêtre.

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const Topo := preload("res://DEV_TOOLS/topologie.gd")
const Tranchage := preload("res://addons/marchingblocks_core/tranchage.gd")


## De combien on lisse. ⚠ **LE DÉFAUT EST 1,0 ET C'ÉTAIT UN PIÈGE** : toute la table de topologie et la
## récolte des 68 classes avaient été mesurées à pleine force, alors que la force retenue à l'image est
## bien plus basse. La connectivité ne dépend pas du réglage, mais les POSITIONS si — donc
## l'appariement en quads, le gauchissement et surtout la RÉCOLTE peuvent différer. Donner les chiffres
## du fondu pour ceux du chanfrein aurait été exactement le genre de glissement que cette charte
## interdit (§6).
var _force := 1.0


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--force="):
			_force = option.substr("--force=".length()).to_float()

	print("=== LE LISSAGE TIENT-IL SES TROIS PROMESSES ? ===\n")
	print("force du lissage mesurée : %.2f\n" % _force)

	var cases: Dictionary = BM.cases(0)
	var actuel: ArrayMesh = BM.souder(BM.maillage_moitie(0))
	var lisse: ArrayMesh = BM.souder(BM.maillage_lisse(0, 0.5, _force))

	# ── 1. TOPOLOGIE ────────────────────────────────────────────────────────────────────────────────
	print("── 1. TOPOLOGIE ──")
	var a: Dictionary = Topo.bilan(actuel, cases)
	var b: Dictionary = Topo.bilan(lisse, cases)
	print("   %-34s %12s %12s" % ["", "ACTUEL", "LISSÉ"])
	for ligne in [
		["sommets", "sommets"], ["triangles", "triangles"],
		["sommets en double (non soudés)", "doubles"],
		["arêtes de BORD (= des trous)", "bords"],
		["arêtes NON-MANIFOLD (3+ faces)", "multiples"],
		["quads appariés (règle COPLANAIRE)", "quads"],
		["triangles orphelins (coplanaire)", "orphelins"],
		["quads appariés (règle TOLÉRANTE)", "quads_tolerants"],
		["triangles orphelins (tolérante)", "orphelins_tolerants"],
		["arêtes de bord, en QUADS", "q_bords"],
		["arêtes non-manifold, en QUADS", "q_multiples"],
	]:
		print("   %-34s %12s %12s" % [ligne[0], str(a[ligne[1]]), str(b[ligne[1]])])

	# ⚠ **DEUX VALENCES, ET SEULE LA SECONDE VAUT POUR LE LISSÉ.** La première retire du graphe les
	# diagonales des seuls quads COPLANAIRES ; sur un maillage dual, dont les quads ne sont pas plans,
	# elle laisse donc des diagonales en place et gonfle les valences. C'est le chiffre qui répond à
	# l'exigence de Jordan pour Blender — le mesurer avec la mauvaise règle serait accuser le maillage
	# d'un défaut de l'instrument (charte §6).
	for regle in [["valence 4 — règle COPLANAIRE", "q_val", "q_sommets"],
			["valence 4 — règle TOLÉRANTE", "q_val_tolerant", "q_sommets_tolerant"]]:
		var va: Dictionary = a[regle[1]]
		var vb: Dictionary = b[regle[1]]
		print("   %-34s %11.1f%% %11.1f%%" % [regle[0],
			100.0 * float(int(va.get(4, 0))) / maxf(1.0, float(int(a[regle[2]]))),
			100.0 * float(int(vb.get(4, 0))) / maxf(1.0, float(int(b[regle[2]])))])
	print("   %-34s %12s %12s" % ["écart au plan le plus fort",
		"%.4f" % float(a["plat_mini"]), "%.4f" % float(b["plat_mini"])])

	var verdict_topo: bool = int(b["multiples"]) <= int(a["multiples"]) and int(b["bords"]) == 0 \
		and int(b["doubles"]) == 0
	print("   → %s" % ("les arêtes ambiguës n'ont PAS augmenté, aucun trou, tout soudé"
		if verdict_topo else "⚠ LA PRÉDICTION DE JORDAN TIENT : le lissage dégrade la topologie"))

	# ── 2. RÉCOLTE ──────────────────────────────────────────────────────────────────────────────────
	#
	# ⚠ C'est le contrat de couture qui se joue ici : le lissage déplace la surface d'un demi-sous-voxel
	# PARTOUT, plans de coupe compris. Si les classes récoltées changent, les tuiles ne se raccordent
	# plus, et aucun compteur de topologie ne l'aurait dit.
	print("\n── 2. RÉCOLTE (le contrat de couture) ──")
	var noms_a: Array = _recolter(BM.maillage_moitie(0), cases, "actuel")
	var noms_b: Array = _recolter(BM.maillage_lisse(0, 0.5, _force), cases, "lissé")
	var dans_b := {}
	for n in noms_b:
		dans_b[n] = true
	var perdues: Array = []
	for n in noms_a:
		if not dans_b.has(n):
			perdues.append(n)
	var dans_a := {}
	for n in noms_a:
		dans_a[n] = true
	var gagnees: Array = []
	for n in noms_b:
		if not dans_a.has(n):
			gagnees.append(n)
	print("   classes récoltées : %d en actuel, %d en lissé" % [noms_a.size(), noms_b.size()])
	if perdues.is_empty() and gagnees.is_empty():
		print("   → les DEUX jeux sont IDENTIQUES : le lissage ne change pas ce que le trancheur voit")
	else:
		if not perdues.is_empty():
			print("   ⚠ %d PERDUE(S) : %s"
				% [perdues.size(), ", ".join(PackedStringArray(perdues.slice(0, 10)))])
		if not gagnees.is_empty():
			print("   ⚠ %d APPARUE(S) : %s"
				% [gagnees.size(), ", ".join(PackedStringArray(gagnees.slice(0, 10)))])

	# ── 3. LES ESCALIERS ONT-ILS DISPARU ? ──────────────────────────────────────────────────────────
	#
	# ⚠ Sans ce troisième contrôle, un lissage qui ne lisse RIEN passerait les deux premiers avec les
	# félicitations du jury : topologie intacte et récolte identique sont exactement ce que rend une
	# fonction qui ne fait rien.
	print("\n── 3. LES MARCHES ONT-ELLES DISPARU ? ──")
	_compter_les_marches("actuel", actuel)
	_compter_les_marches("lissé ", lisse)
	# ⚠ **CE COMPTEUR SATURE, ET IL FAUT LE DIRE OÙ IL S'IMPRIME.** Il demande « cette face est-elle
	# inclinée ? », jamais « de combien ». Dès que la force quitte zéro, presque toutes les faces sont
	# inclinées : 0,35 rend 63,0 % et 1,00 rend 63,2 %. Il prouve donc que le lissage AGIT, mais il est
	# incapable de distinguer un chanfrein discret d'un fondu complet — seule l'image le fait.
	print("   ⚠ ce compteur sature : il dit SI une face penche, jamais DE COMBIEN. Voir la planche.")

	# ── 4. LE CONTRÔLE NÉGATIF DU RÉGLAGE ───────────────────────────────────────────────────────────
	#
	# ⚠ **SANS LUI, LE RÉGLAGE POURRAIT NE RIEN RÉGLER SANS QUE RIEN NE LE DISE.** Le centre d'un cube
	# dual tombe sur un coin du réseau, là même où la coque à facettes pose ses sommets : à force = 0,
	# le lissage DOIT donc rendre 0 % de pentes. S'il en rend, le réglage est faux et les colonnes
	# ci-dessus ne mesurent pas ce que je crois.
	print("\n── 4. CONTRÔLE NÉGATIF DU RÉGLAGE ──")
	print("   attendu : force 0 → 0,0 %% de pentes (la coque à facettes, reproduite)")
	for f in [0.0, 0.35, 0.6, 1.0]:
		_compter_les_marches("force %.2f" % f, BM.souder(BM.maillage_lisse(0, 0.5, f)))

	print("\n⚠ Aucun de ces compteurs ne dit si ça a l'air JUSTE : voir planche_lissage.gd.")
	quit(0)


func _recolter(solide: ArrayMesh, _cases: Dictionary, quoi: String) -> Array:
	var fautes: Array = []
	var recolte: Dictionary = Tranchage.trancher(solide, Vector3i.ONE * BM.COTE, 1.0,
		BM.creuses(0), fautes, false)
	if not fautes.is_empty():
		print("   ⚠ %s : %d faute(s) de tranchage, dont « %s »"
			% [quoi, fautes.size(), String(fautes[0]).left(110)])
	var noms: Array = recolte.keys()
	noms.sort()
	return noms


## Combien de faces sont encore parfaitement horizontales ou verticales ? ⚠ Une marche est faite de
## deux faces alignées sur les axes ; une pente ne l'est pas. Compter les normales OBLIQUES dit donc
## directement si le lissage a produit des faces directes, sans avoir à définir « une marche ».
func _compter_les_marches(quoi: String, mesh: ArrayMesh) -> void:
	if mesh.get_surface_count() == 0:
		print("   %s : maillage vide" % quoi)
		return
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
		if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
	var alignees := 0
	var obliques := 0
	for t in range(0, idx.size() - 2, 3):
		# ⚠ Normale GÉOMÉTRIQUE : souder impose une moyenne par sommet, et s'y fier a déjà coûté
		# 23 erreurs d'octant dans ce projet.
		var n: Vector3 = (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
		if n.length_squared() < 0.000000001:
			continue
		n = n.normalized()
		var axe_pur: bool = false
		for axe in 3:
			if absf(absf(n[axe]) - 1.0) < 0.001:
				axe_pur = true
		if axe_pur:
			alignees += 1
		else:
			obliques += 1
	var total: int = alignees + obliques
	print("   %s : %d triangle(s) alignés sur les axes, %d OBLIQUES (%.1f %% de pentes)"
		% [quoi, alignees, obliques, 100.0 * float(obliques) / maxf(1.0, float(total))])
