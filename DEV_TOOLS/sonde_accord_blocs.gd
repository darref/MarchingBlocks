extends SceneTree
##
## SONDE — `blocs_maitres.gd` et `tranchage.gd` lisent-ils le MÊME bloc ?
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --headless --path D:/UnderMend \
##       --script res://DEV_TOOLS/sonde_accord_blocs.gd
##
## ── LE SOUPÇON, ET IL VIENT D'UNE AUTRE SONDE ───────────────────────────────────────────────────────
##
## `DEV_TOOLS/sonde_relief_blocs.gd` a refusé « massif et plateau » ALIGNÉ, avec 47 erreurs, alors que
## son propre en-tête annonçait que le traitement aligné devait passer. Le message était clair : *« le
## bloc mesure −1,000 de trop sur l'axe 1 »* — sa couche y = 3 est vide, donc son solide fait 4 × 3 × 4
## et déclarer 4 × 4 × 4 est une fausse déclaration.
##
## ⚠ **MAIS ÇA A DÉCOUVERT PLUS GRAVE, ET C'EST L'OBJET DE CETTE SONDE.** Les deux modules ne balaient
## pas le même ensemble de sommets :
##
##   `BlocsMaitres.pieces_de()`  ne lit que les sommets INTÉRIEURS — (COTE−1)³ = 27 — au motif que les
##                               autres dépendent de ce qu'il y a AUTOUR du bloc, qui n'existe pas ;
##   `Tranchage.trancher()`      balaie de −1 à n−1 sur chaque axe — 5³ = 125 sommets — en tenant le
##                               dehors pour VIDE (`MB.bits` lit un dictionnaire d'occupation).
##
## Ce sont deux conventions différentes, et **aucune n'est évidemment fausse** : la mienne dit « je ne
## promets que ce que le bloc contient », la sienne dit « un bloc posé dans le vide a aussi une peau ».
## Mais elles ne peuvent pas être toutes les deux la vérité affichée dans le panneau.
##
## ⚠ **CE QUI EST EN JEU** : le panneau annonce « ce bloc livre N classes » et « cumul 68/68 ». Si le
## trancheur en récolte d'autres, ce chiffre est faux au moment où l'artiste s'en sert — et c'est
## exactement la faute que la charte poursuit : *un compteur vert ne dit jamais qu'une tuile est à SA
## place*, et *deux descriptions d'un même fait divergent au premier réglage*.
##
## ── CE QUE CETTE SONDE MESURE ───────────────────────────────────────────────────────────────────────
##
## Pour chacun des neuf blocs, et pour les DEUX déclarations possibles de ses dimensions :
##   • ce que `classes_de()` annonce ;
##   • ce que `trancher()` récolte réellement du même solide ;
##   • la différence, dans les deux sens, nommée classe par classe.
##
## Elle ne modifie rien. Elle imprime.

const MB := preload("res://addons/undermend/marching_blocks.gd")
const Tranchage := preload("res://addons/undermend/tranchage.gd")
const BlocsMaitres := preload("res://addons/undermend/blocs_maitres.gd")

const CELLULE := 1.0


func _initialize() -> void:
	print("=== SONDE — le panneau et le trancheur parlent-ils du même bloc ? ===\n")

	var total_annonce := {}
	var total_recolte := {}
	var desaccords := 0

	for i in BlocsMaitres.nombre():
		var nom: String = BlocsMaitres.BLOCS[i]["nom"]
		var pleines: Dictionary = BlocsMaitres.cases(i)
		var solide: ArrayMesh = BlocsMaitres.maillage(i)

		# ── ce que le panneau annonce ──────────────────────────────────────────────────────────────────
		var annonce := {}
		for n in BlocsMaitres.classes_de(i):
			annonce[n] = true
			total_annonce[n] = true

		# ── l'étendue RÉELLE du solide, en cellules ────────────────────────────────────────────────────
		# ⚠ C'est ce que le trancheur mesurera sur le `.glb` réimporté, et ce qui doit être DÉCLARÉ.
		var boite: AABB = solide.get_aabb()
		var reelles := Vector3i(
			int(round(boite.size.x / CELLULE)),
			int(round(boite.size.y / CELLULE)),
			int(round(boite.size.z / CELLULE)))

		# ── ce que le trancheur récolte, avec les dimensions DÉCLARÉES 4³ ──────────────────────────────
		var erreurs_cube: Array = []
		var pieces_cube: Dictionary = Tranchage.trancher(solide,
			Vector3i.ONE * BlocsMaitres.COTE, CELLULE, _vides(pleines, BlocsMaitres.COTE), erreurs_cube)

		for n in pieces_cube:
			total_recolte[n] = true

		var manque_au_panneau: Array = []
		for n in pieces_cube:
			if not annonce.has(n):
				manque_au_panneau.append(n)
		var annonce_en_trop: Array = []
		for n in annonce:
			if not pieces_cube.has(n):
				annonce_en_trop.append(n)
		manque_au_panneau.sort()
		annonce_en_trop.sort()

		var accord: bool = manque_au_panneau.is_empty() and annonce_en_trop.is_empty()
		if not accord:
			desaccords += 1

		print("── %s ──" % nom)
		print("   étendue réelle du solide : %d × %d × %d cellules%s"
			% [reelles.x, reelles.y, reelles.z,
				"   ⚠ PAS un cube de %d" % BlocsMaitres.COTE
					if reelles != Vector3i.ONE * BlocsMaitres.COTE else ""])
		print("   panneau annonce %2d classes · trancheur récolte %2d · %d erreur(s) de tranchage"
			% [annonce.size(), pieces_cube.size(), erreurs_cube.size()])
		if not manque_au_panneau.is_empty():
			print("   ⚠ RÉCOLTÉES MAIS NON ANNONCÉES (%d) : %s"
				% [manque_au_panneau.size(), ", ".join(PackedStringArray(manque_au_panneau))])
		if not annonce_en_trop.is_empty():
			print("   ⚠ ANNONCÉES MAIS NON RÉCOLTÉES (%d) : %s"
				% [annonce_en_trop.size(), ", ".join(PackedStringArray(annonce_en_trop))])
		if accord:
			print("   accord.")
		print("")

	print("── BILAN ──")
	print("   blocs en désaccord : %d sur %d" % [desaccords, BlocsMaitres.nombre()])
	print("   union ANNONCÉE  : %d classes" % total_annonce.size())
	print("   union RÉCOLTÉE  : %d classes" % total_recolte.size())
	print("   le modèle en demande : %d" % MB.pieces_a_sculpter().size())
	if desaccords > 0:
		print("\n   ⚠ Le panneau et le trancheur ne décrivent pas le même bloc. Une seule des deux")
		print("     conventions peut être la vérité affichée à l'artiste — à trancher, pas à moyenner.")
	else:
		print("\n   Les deux chemins s'accordent sur les neuf blocs.")
	quit(0)


## Les cellules VIDES d'un cube de côté `cote`, au format que `trancher()` attend.
func _vides(pleines: Dictionary, cote: int) -> Array:
	var vides: Array = []
	for x in cote:
		for y in cote:
			for z in cote:
				if not pleines.has(Vector3i(x, y, z)):
					vides.append(Vector3i(x, y, z))
	return vides
