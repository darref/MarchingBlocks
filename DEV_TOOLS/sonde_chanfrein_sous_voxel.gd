extends SceneTree

## SONDE — LE CHANFREIN D'UN SOUS-VOXEL, OBTENU SANS CHIRURGIE DE MAILLAGE
##
## ⚠ **LA CIBLE EST LE SCULPT DE JORDAN, MESURÉ, PAS UNE INTENTION** (26 septembre 2026). Il a repris
## le témoin et en a retiré ce qu'il appelle ses contremarches. Son spectre d'angles ne contient que
## **0°, 45° et 90°**, son plus gros triangle vaut `0,25 × 0,25 × √2`, et son compte de lèvres passe de
## 13 à 1 sans que ses autres plats changent d'épaisseur : **un chanfrein à 45° large d'UN sous-voxel,
## et rien d'autre.**
##
## ── LA PISTE, ET POURQUOI ELLE ÉVITE LA CHIRURGIE ───────────────────────────────────────────────────
##
## Biseauter les arêtes d'un maillage demande de couper chaque arête et de recoudre les coins — et la
## charte §4 dit ce que ça coûte : *« là où trois contremarches se rencontrent, le triangle qu'on créera
## rendra beaucoup d'endroits non-manifold »*, et *« un palier d'UN sous-voxel n'a qu'une face, réclamée
## par les chanfreins de ses DEUX côtés »*.
##
## ⚠ **MAIS LE GREFFON SAIT DÉJÀ POSER DES FACES À 45° SANS COUPER QUOI QUE CE SOIT.** C'est exactement
## ce que fait `maillage_direct` : un sommet au milieu de chaque arête dont les deux bouts diffèrent,
## donc un plan à 45° partout où la matière tourne. Appliqué aux CASES, il coupe des cellules entières
## — c'est le geste trop gros que Jordan a signalé. **Appliqué au champ de SOUS-VOXELS, il coupe des
## sous-voxels.** Même code, même règle, une seule échelle change.
##
## ⚠ **TROIS CHOSES PEUVENT LE FAIRE ÉCHOUER, ET C'EST POUR ÇA QU'ON MESURE AVANT DE PROPOSER :**
##   1. `_direct_dans` n'émet RIEN sur un contact diagonal (`sans_contact_diagonal`). Le champ de
##      sous-voxels en contient — la charte en relève 18 sur l'aminci. Chaque sommet muet est un TROU ;
##   2. la surface passe par les CENTRES des sous-voxels, donc elle rentre d'un demi-sous-voxel
##      partout : le volume MAIGRIT, et l'aminci promet à l'artiste une tuile de la moitié de sa case ;
##   3. le contrat de couture : si la récolte ne rend plus les classes, la piste est morte, si beau que
##      soit le chanfrein.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/sonde_chanfrein_sous_voxel.gd

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const RP := preload("res://addons/marchingblocks_core/repli_procedural.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
const Topologie := preload("res://DEV_TOOLS/topologie.gd")

const BLOC := 0


func _initialize() -> void:
	print("=== LE CHANFREIN D'UN SOUS-VOXEL ===\n")
	print("LA CIBLE, mesurée sur le sculpt de Jordan :")
	print("   angles 0° / 45° / 90° seulement · 27,31 case² à 45° · 1 lèvre au lieu de 13")
	print("   boîte (0,250 … 7,750) · aire totale 370,1 case²\n")

	var cases: Dictionary = BM.cases(BLOC)
	_decrire("L'AMINCI — ce qui part aujourd'hui", BM.maillage_moitie(BLOC))

	# ── LA PISTE ────────────────────────────────────────────────────────────────────────────────────
	var pleins: Dictionary = BM.sous_voxels(cases, 0.25)
	var cote_sous: int = BM.COTE * BM.SOUS
	print("champ de sous-voxels : %d sous-voxels pleins sur %d³\n" % [pleins.size(), cote_sous])

	# ⚠ **LES TROUS D'ABORD.** Un maillage percé peut très bien rendre un joli spectre d'angles : si
	# l'on regarde les angles avant les trous, on s'enthousiasme pour une surface qui n'existe pas.
	var porte := 0
	var muet := 0
	for vx in range(-1, cote_sous):
		for vy in range(-1, cote_sous):
			for vz in range(-1, cote_sous):
				var b: int = MB.bits(pleins, Vector3i(vx, vy, vz))
				if not MB.porte_une_surface(b):
					continue
				porte += 1
				if not MB.sans_contact_diagonal(b):
					muet += 1
	print("── LES TROUS ──")
	print("   %d sommet(s) portent une surface, dont %d MUETS (contact diagonal) — %.2f %%"
		% [porte, muet, 100.0 * float(muet) / float(maxi(1, porte))])
	print("   %s\n" % ("✓ aucun trou" if muet == 0 else "⚠ autant de trous dans la surface"))

	# ⚠ **LA LARGEUR DU CHANFREIN EST LE PAS DE LA GRILLE, ET RIEN D'AUTRE.** La surface passe par les
	# milieux des arêtes du réseau : couper un coin lui coûte donc exactement un pas de chaque côté. Il
	# n'y a pas de réglage à inventer — on choisit la RÉSOLUTION, la largeur suit. C'est mesurable, et
	# c'est ce qui distingue ce nombre d'un goût (charte §4 : « 0,35 est mesuré, pas choisi au goût »).
	var pistes: Array = []
	for facteur in [1, 2]:
		var champ: Dictionary = _affiner(pleins, facteur)
		var cote_f: int = cote_sous * facteur
		var brut: ArrayMesh = RP.maillage_direct_du_bloc(champ, cote_f)
		var chanfreine: ArrayMesh = _mettre_a_l_echelle(brut, 1.0 / float(BM.SOUS * facteur))
		_decrire("LA PISTE au pas de 1/%d de case — chanfrein de %.3f case"
			% [BM.SOUS * facteur, 1.0 / float(BM.SOUS * facteur)], chanfreine)
		pistes.append(chanfreine)

	# ── LE CONTRAT DE COUTURE ───────────────────────────────────────────────────────────────────────
	print("── LA RÉCOLTE — le seul juge qui puisse tuer la piste ──")
	_recolter("l'AMINCI", BM.maillage_moitie(BLOC), cases)
	for i in pistes.size():
		_recolter("PISTE 1/%d" % (BM.SOUS * int(pow(2, i))), pistes[i], cases)

	print("⚠ Cette sonde ne dit pas si c'est joli : ça, c'est l'œil de Jordan (charte §6).")
	quit(0)


## Le spectre des angles, l'aire et la boîte — la même lecture que `sonde_spectre_des_angles`.
func _decrire(quoi: String, mesh: ArrayMesh) -> void:
	var v: PackedVector3Array = Topologie.triangles_de(mesh)
	var mini := Vector3.INF
	var maxi := -Vector3.INF
	for p in v:
		mini = mini.min(p)
		maxi = maxi.max(p)
	var par_angle := {}
	var aire_totale := 0.0
	var plus_grand := 0.0
	for i in range(0, v.size() - 2, 3):
		var n: Vector3 = (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
		var aire: float = 0.5 * n.length()
		if aire < 0.0000001:
			continue
		aire_totale += aire
		plus_grand = maxf(plus_grand, aire)
		var deg: int = roundi(rad_to_deg(acos(clampf(absf(n.normalized().y), 0.0, 1.0))))
		par_angle[deg] = float(par_angle.get(deg, 0.0)) + aire
	print("── %s ──" % quoi)
	print("   %d triangle(s) · aire %.1f case² · plus grand triangle %.4f"
		% [v.size() / 3, aire_totale, plus_grand])
	print("   boîte (%.3f, %.3f, %.3f) → (%.3f, %.3f, %.3f)"
		% [mini.x, mini.y, mini.z, maxi.x, maxi.y, maxi.z])
	var angles: Array = par_angle.keys()
	angles.sort()
	var menus := 0.0
	for d in angles:
		if float(par_angle[d]) >= 0.5:
			print("      %3d° : %7.2f case²" % [d, par_angle[d]])
		else:
			menus += float(par_angle[d])
	if menus > 0.0:
		print("      (et %.2f case² éparpillées sur %d autre(s) angle(s))"
			% [menus, angles.size()])
	print("")


## LA RÉCOLTE, par le vrai trancheur — jamais une seconde description du contrat de couture.
func _recolter(quoi: String, solide: ArrayMesh, cases: Dictionary) -> void:
	var Tranchage := load("res://addons/marchingblocks_core/tranchage.gd")
	var fautes: Array = []
	var recolte: Dictionary = Tranchage.trancher(solide, Vector3i.ONE * BM.COTE, 1.0,
		BM.creuses(BLOC), fautes, false)
	var classes := {}
	for nom in recolte:
		classes[nom] = true
	print("   %-10s : %d classe(s) récoltée(s), %d faute(s) de tranchage   %s"
		% [quoi, classes.size(), fautes.size(),
			"" if fautes.is_empty() else "⚠ " + str(fautes[0])])


## ⚠ **ON MET À L'ÉCHELLE LES SOMMETS, PAS LE NŒUD.** Une `Transform3D` sur un `MeshInstance3D`
## laisserait le maillage en unités de sous-voxel : tout lecteur qui prend le maillage seul — le
## trancheur, les sondes — travaillerait quatre fois trop grand sans qu'aucune erreur ne le dise.
func _mettre_a_l_echelle(mesh: ArrayMesh, facteur: float) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var mis := PackedVector3Array()
	mis.resize(v.size())
	for i in v.size():
		mis[i] = v[i] * facteur
	arrays[Mesh.ARRAY_VERTEX] = mis
	var sortie := ArrayMesh.new()
	sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	sortie.surface_set_material(0, RP.matiere())
	return sortie


## AFFINE un champ de voxels en le subdivisant : chaque voxel devient `facteur³` voxels.
##
## ⚠ **ON SUBDIVISE PLUTÔT QUE DE RE-DÉRIVER LE CHAMP À UNE AUTRE RÉSOLUTION.** Rappeler
## `BM.sous_voxels()` avec un autre `SOUS` demanderait de toucher la constante que le mailleur, le
## trancheur et l'export lisent tous : on changerait ce qui part chez l'artiste pour mesurer une piste.
## La subdivision est EXACTE — un voxel plein reste exactement le même volume — et ne touche à rien.
func _affiner(champ: Dictionary, facteur: int) -> Dictionary:
	if facteur <= 1:
		return champ
	var sortie := {}
	for c in champ:
		var p: Vector3i = c
		for i in facteur:
			for j in facteur:
				for k in facteur:
					sortie[Vector3i(p.x * facteur + i, p.y * facteur + j, p.z * facteur + k)] = true
	return sortie
