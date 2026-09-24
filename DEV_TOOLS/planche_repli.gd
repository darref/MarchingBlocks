extends SceneTree
##
## LA PLANCHE DU REPLI — une COMPARAISON, pas une illustration.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, jamais en headless (le headless ne rend rien) :
##   Godot_v4.7-stable_win64_console.exe --path D:/UnderMend \
##       --script res://DEV_TOOLS/planche_repli.gd -- --sortie=D:/UnderMend/ART/planche_repli.png
##
## ⚠ **POURQUOI LA VERSION PRÉCÉDENTE NE PROUVAIT RIEN (Jordan, 19 septembre 2026).** Elle coloriait
## chaque face d'après sa normale — vert vers le haut, bleu vers le bas, brun sur les flancs — puis on
## regardait l'image et l'on concluait que les normales étaient bonnes. C'est une TAUTOLOGIE : le code
## affirme, l'image répète. Sur un cube isolé comme sur un massif entier, le résultat est le même. Zéro
## information de validité. (Ce qu'elle avait réellement attrapé, c'est le culling — parce que les faces
## DISPARAISSAIENT. Ça, c'était de l'information ; les couleurs, non.)
##
## ── CE QUE CETTE PLANCHE COMPARE, ET POURQUOI C'EST FALSIFIABLE ──────────────────────────────────────
##
## Par construction, la surface du repli EST la frontière de l'union des cellules peintes. Donc deux
## constructions INDÉPENDANTES doivent rendre exactement la même image :
##
##   1. LES CUBES BRUTS — chaque cellule dessinée comme un cube unité. N'emploie ni le classificateur,
##      ni le repli, ni les rotations. Trivialement correct.
##   2. MARCHING BLOCKS — les pièces posées par classe et orientation.
##   3. LE DIFF — pixel à pixel, même caméra, même lumière, et **le même matériau imposé aux deux**,
##      ce qui neutralise les couleurs de bande : il ne reste que la géométrie et les normales.
##
## ⚠ Une normale fausse change l'ombrage ; une face manquante laisse un trou ; une pièce mal orientée
## déplace une arête. **Tout pixel non noir du diff est un défaut réel**, et leur COMPTE est une mesure,
## pas une impression.
##
##   4. LES ORIENTATIONS — chaque pièce teintée selon son index (les quatre quarts : 0, 10, 16, 22).
##      Un run plat doit être d'UNE SEULE couleur ; des rayures trahiraient une orientation qui bat.
##      C'est la version visible du test « les tuiles de run rendent une orientation constante ».

const MB := preload("res://addons/undermend/marching_blocks.gd")
const RP := preload("res://addons/undermend/repli_procedural.gd")

const PANNEAU := Vector2i(700, 520)
const FOND := Color("#101216")
const SEUIL := 8.0 / 255.0   # en deçà, c'est du crénelage de bord, pas un défaut

## Les quatre orientations du modèle orienté, et une teinte par orientation.
const TEINTES := {0: Color("#e0603c"), 10: Color("#4ec27a"), 16: Color("#5b8fd6"), 22: Color("#d8c04a")}

var _cubes: SubViewport
var _blocks: SubViewport
var _orientations: SubViewport
var _sortie := "planche_repli.png"
var _images := 0


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--sortie="):
			_sortie = option.substr("--sortie=".length())

	var pleines := _scene()
	# ⚠ MÊME CIBLE ET MÊME DISTANCE POUR LES TROIS VUES : un diff n'a de sens que si les caméras sont
	# rigoureusement identiques. Une différence d'un pixel de cadrage allumerait toute l'image.
	var cible := Vector3(4.0, 1.5, 4.0)
	_cubes = _faire_vue(cible)
	_poser_les_cubes(_cubes, pleines)
	_blocks = _faire_vue(cible)
	_poser_les_blocks(_blocks, pleines, false)
	_orientations = _faire_vue(cible)
	_poser_les_blocks(_orientations, pleines, true)

	process_frame.connect(_image)


func _image() -> void:
	_images += 1
	if _images < 4:
		return
	var a := _cubes.get_texture().get_image()
	var b := _blocks.get_texture().get_image()
	var o := _orientations.get_texture().get_image()

	# ── LE DIFF, ET SON COMPTE ──────────────────────────────────────────────────────────────────────
	var diff := Image.create(PANNEAU.x, PANNEAU.y, false, a.get_format())
	var differents := 0
	var pire := 0.0
	var ou := {}
	for y in PANNEAU.y:
		for x in PANNEAU.x:
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			var ecart: float = maxf(maxf(absf(pa.r - pb.r), absf(pa.g - pb.g)), absf(pa.b - pb.b))
			pire = maxf(pire, ecart)
			if ecart > SEUIL:
				differents += 1
				ou["%d,%d" % [x, y]] = {"p": Vector2i(x, y), "a": pa, "b": pb, "ecart": ecart}
				diff.set_pixel(x, y, Color(1.0, 0.15, 0.1))
			else:
				# On garde une trace grise de la silhouette, pour situer les défauts s'il y en a.
				var gris: float = pa.get_luminance() * 0.22
				diff.set_pixel(x, y, Color(gris, gris, gris))

	# ⚠ **UN COMPTE NE SUFFIT PAS À CONCLURE, ET MA PREMIÈRE VERSION CONCLUAIT TROP VITE.** Elle
	# déclarait « défaut réel » dès que le compteur dépassait zéro. Or deux triangulations différentes
	# du MÊME plan ne tombent jamais bit à bit : six grands quads par cellule d'un côté, une nuée de
	# quarts d'octant de l'autre, et la règle de remplissage du rasteriseur inclut ou exclut un pixel de
	# frontière. Ce qui distingue un défaut d'un artefact, c'est la FORME du désaccord :
	#
	#   • un défaut géométrique allume une RÉGION CONNEXE — une face manquante vaut des centaines de
	#     pixels, une pièce mal orientée vaut une ligne d'arête ;
	#   • un artefact de rastérisation allume des pixels ISOLÉS, posés sur des bords.
	#
	# On mesure donc la connexité, et on DIT laquelle des deux signatures on observe.
	var groupes := 0
	for cle in ou:
		var p: Vector2i = ou[cle]["p"]
		var voisin := false
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if (dx != 0 or dy != 0) and ou.has("%d,%d" % [p.x + dx, p.y + dy]):
					voisin = true
		if voisin:
			groupes += 1

	var total: int = PANNEAU.x * PANNEAU.y
	print("── DIFF entre les cubes bruts et Marching Blocks ──")
	print("   pixels différents (écart > %.3f) : %d sur %d  (%.4f %%)"
		% [SEUIL, differents, total, 100.0 * differents / total])
	print("   écart maximal observé : %.4f" % pire)
	print("   dont GROUPÉS (au moins un voisin en désaccord) : %d" % groupes)
	var montres := 0
	for cle in ou:
		if montres >= 8:
			break
		var d: Dictionary = ou[cle]
		print("      en %s : cubes %s vs blocks %s (écart %.3f)"
			% [str(d["p"]), str(d["a"]).left(22), str(d["b"]).left(22), d["ecart"]])
		montres += 1
	if differents == 0:
		print("   VERDICT : les deux constructions rendent la MÊME surface, au pixel près")
	elif groupes == 0:
		print("   VERDICT : %d pixel(s) ISOLÉ(S), aucun groupé — signature d'un artefact de" % differents)
		print("             rastérisation sur un bord, PAS d'un défaut de surface")
	else:
		print("   ⚠ VERDICT : %d pixels dont %d GROUPÉS — une région connexe est un défaut RÉEL,"
			% [differents, groupes])
		print("               à localiser aux coordonnées ci-dessus")

	var planche := Image.create(PANNEAU.x * 2, PANNEAU.y * 2, false, a.get_format())
	planche.fill(FOND)
	planche.blit_rect(a, Rect2i(Vector2i.ZERO, PANNEAU), Vector2i.ZERO)
	planche.blit_rect(b, Rect2i(Vector2i.ZERO, PANNEAU), Vector2i(PANNEAU.x, 0))
	planche.blit_rect(diff, Rect2i(Vector2i.ZERO, PANNEAU), Vector2i(0, PANNEAU.y))
	planche.blit_rect(o, Rect2i(Vector2i.ZERO, PANNEAU), Vector2i(PANNEAU.x, PANNEAU.y))
	var err := planche.save_png(_sortie)
	print("\nplanche %d×%d → %s (%s)" % [planche.get_width(), planche.get_height(), _sortie,
		"écrite" if err == OK else "ERREUR %d" % err])
	print("   haut-gauche : cubes bruts   haut-droite : Marching Blocks")
	print("   bas-gauche  : le DIFF       bas-droite  : les orientations")
	quit(0 if err == OK else 1)


## La scène d'essai — les formes qui font mal.
func _scene() -> Dictionary:
	var pleines := {}
	for z in range(0, 6):
		for x in range(0, 6):
			pleines[Vector3i(x, 0, z)] = true          # un plateau 6 × 6
	for z in range(1, 5):
		for x in range(1, 4):
			pleines[Vector3i(x, 1, z)] = true          # une marche
	pleines[Vector3i(2, 2, 2)] = true                  # un bloc posé dessus
	pleines.erase(Vector3i(5, 0, 5))                   # une ENCOCHE : des angles rentrants
	pleines.erase(Vector3i(4, 0, 5))
	for x in range(1, 4):
		pleines[Vector3i(x, 3, 1)] = true              # un SURPLOMB : un vrai plafond dessous
	pleines[Vector3i(8, 0, 1)] = true                  # une case ISOLÉE
	pleines[Vector3i(8, 0, 3)] = true                  # deux cases qui ne se touchent QUE par un coin
	pleines[Vector3i(9, 0, 4)] = true
	return pleines


func _faire_vue(cible: Vector3) -> SubViewport:
	var vue := SubViewport.new()
	vue.size = PANNEAU
	vue.own_world_3d = true
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# ⚠ PAS DE MSAA : le crénelage diffère d'un rendu à l'autre et allumerait le diff pour rien.
	vue.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(vue)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8892a4")
	env.ambient_light_energy = 0.8
	var monde := WorldEnvironment.new()
	monde.environment = env
	vue.add_child(monde)

	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-50, -35, 0)
	lumiere.light_energy = 1.1
	vue.add_child(lumiere)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0
	camera.position = cible + Vector3(1, 0.9, 1).normalized() * 40.0
	vue.add_child(camera)
	camera.look_at_from_position(camera.position, cible, Vector3.UP)
	return vue


## Le matériau IMPOSÉ aux deux rendus comparés. ⚠ C'est lui qui neutralise les couleurs de bande du
## repli : sans ça, le diff comparerait des teintes au lieu de comparer des surfaces.
static func _neutre() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#cfcfcf")
	m.roughness = 0.9
	return m


## LA RÉFÉRENCE : chaque cellule peinte, un cube unité. ⚠ N'emploie ni le classificateur, ni le repli,
## ni les rotations — c'est ce qui en fait une construction INDÉPENDANTE.
func _poser_les_cubes(vue: SubViewport, pleines: Dictionary) -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var matiere := _neutre()
	for c in pleines:
		var instance := MeshInstance3D.new()
		instance.mesh = cube
		instance.material_override = matiere
		# Une cellule `p` occupe [p ; p+1] : son centre est en p + 0,5 (mesuré, sonde_gridmap_centrage).
		instance.position = Vector3(c) + Vector3.ONE * 0.5
		vue.add_child(instance)


## L'ASSEMBLAGE : une pièce par sommet, posée par classe et orientation.
## Le sommet `v` lit les huit cellules v … v+(1,1,1), donc il siège en `v + (1,1,1)`.
func _poser_les_blocks(vue: SubViewport, pleines: Dictionary, par_orientation: bool) -> void:
	var sommets := {}
	for c in pleines:
		for s in MB.sommets_de(c):
			sommets[s] = true

	var grille := GridMap.new()  # ⚠ seulement pour lire les bases d'orientation, jamais pour poser
	var neutre := _neutre()
	var par_teinte := {}
	var poses := 0
	for s in sommets:
		var r: Dictionary = MB.classer(MB.bits(pleines, s))
		if not r["surface"]:
			continue
		var instance := MeshInstance3D.new()
		instance.mesh = RP.maillage(MB.classes()[r["classe"]]["bits"])
		if par_orientation:
			if not par_teinte.has(r["orientation"]):
				var m := StandardMaterial3D.new()
				m.albedo_color = TEINTES.get(r["orientation"], Color("#ffffff"))
				m.roughness = 0.9
				par_teinte[r["orientation"]] = m
			instance.material_override = par_teinte[r["orientation"]]
		else:
			instance.material_override = neutre
		instance.transform = Transform3D(
			grille.get_basis_with_orthogonal_index(r["orientation"]), Vector3(s) + Vector3.ONE)
		vue.add_child(instance)
		poses += 1
	grille.free()
	if par_orientation:
		var comptes := {}
		for s in sommets:
			var r: Dictionary = MB.classer(MB.bits(pleines, s))
			if r["surface"]:
				comptes[r["orientation"]] = comptes.get(r["orientation"], 0) + 1
		print("orientations employées : %s" % str(comptes))
	else:
		print("assemblage : %d cellules, %d sommets, %d pièces" % [pleines.size(), sommets.size(), poses])
