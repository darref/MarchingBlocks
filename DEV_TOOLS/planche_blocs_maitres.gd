extends SceneTree
##
## LA PLANCHE DES NEUF BLOCS MAÎTRES — ce que l'artiste devra sculpter, vu avant de le sculpter.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, jamais en headless (le headless ne rend rien) :
##   Godot_v4.7-stable_win64_console.exe --path D:/UnderMend \
##       --script res://DEV_TOOLS/planche_blocs_maitres.gd -- --sortie=D:/UnderMend/ART/planche_blocs.png
##
## ── CE QUE CETTE PLANCHE MONTRE, ET CE QU'ELLE NE PROUVE PAS ────────────────────────────────────────
##
## Chaque case rend UN bloc maître, assemblé **pièce par pièce par le classificateur** — pas en cubes.
## C'est donc ce que le trancheur verra quand l'artiste posera son sculpt : une orientation fausse ou une
## classe mal attribuée se voit à l'image.
##
## ⚠ **ELLE NE PROUVE PAS LA COUVERTURE.** Le décompte 68/68 est une mesure de `BlocsMaitres.cumul()`,
## imprimée ci-dessous ; l'image ne peut ni la confirmer ni la démentir. Regarder une image et conclure
## sur un compte serait exactement la tautologie que Jordan avait relevée sur la première planche du
## repli (charte §6). L'image répond à UNE question : **ces neuf formes sont-elles sculptables ?**
##
## ── LE CADRE DIT LE CONTEXTE ────────────────────────────────────────────────────────────────────────
##
## Un liseré OR pour un bloc d'EXTÉRIEUR, BLEU pour un bloc d'INTÉRIEUR. Les blocs d'intérieur sont ceux
## qui fournissent les variantes de grotte des cinq classes ambiguës — sol, mur, pied de mur, rentrant,
## surplomb — puisque « sol de grotte ≠ sol de massif » (Jordan, 23 septembre 2026).
##
## Les couleurs de surface sont celles du repli : VERT ce qui regarde le ciel, BLEU un plafond, BRUN les
## flancs. ⚠ Elles ne prouvent rien non plus (le code les pose d'après la normale, l'image les répète) —
## elles servent à LIRE la forme, pas à la valider.

const MB := preload("res://addons/undermend/marching_blocks.gd")
const BlocsMaitres := preload("res://addons/undermend/blocs_maitres.gd")

const CASE := Vector2i(430, 430)
const COLONNES := 3
const FOND := Color("#101216")
const LISERE_EXT := Color("#ebbb69")   # l'or du logo : à ciel ouvert
const LISERE_INT := Color("#5b8fd6")   # bleu : sous un plafond
const EPAISSEUR := 3

var _vues: Array = []
var _sortie := "planche_blocs.png"
var _images := 0


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--sortie="):
			_sortie = option.substr("--sortie=".length())

	# ⚠ ON DIT D'ABORD CE QUI NE VA PAS. Une planche magnifique d'un jeu de blocs incomplet serait le
	# pire résultat possible : elle rassurerait.
	var fautes: Array = BlocsMaitres.anomalies()
	if fautes.is_empty():
		print("anomalies() : aucune\n")
	else:
		print("⚠ anomalies() : %d\n" % fautes.size())
		for f in fautes:
			print("   • %s" % f)
		print("")

	print("── LES NEUF BLOCS MAÎTRES ──")
	print("   %-20s %-10s %7s %7s %7s" % ["bloc", "contexte", "classes", "neuves", "cumul"])
	for ligne in BlocsMaitres.cumul():
		print("   %-20s %-10s %7d %7d %7d"
			% [ligne["nom"], ligne["contexte"], ligne["classes"], ligne["neuves"], ligne["cumul"]])
	var absentes: Array = BlocsMaitres.manquantes()
	print("   → %d classe(s) qu'aucun bloc ne livre%s"
		% [absentes.size(), "" if absentes.is_empty() else " : " + str(absentes.slice(0, 6))])
	# ⚠ Le contexte se DÉDUIT du modèle depuis que la liste `AMBIGUES` a été invalidée par la mesure.
	var dehors: Array = BlocsMaitres.MB.classes_exterieures()
	print("   → contexte déduit : %d classe(s) possibles à l'air libre, %d intérieures seulement\n"
		% [dehors.size(), BlocsMaitres.MB.pieces_a_sculpter().size() - dehors.size()])

	for i in BlocsMaitres.nombre():
		_vues.append(_faire_vue(i))

	process_frame.connect(_image)


func _image() -> void:
	_images += 1
	if _images < 4:   # ⚠ laisser les SubViewport rendre avant de capturer
		return

	var lignes: int = int(ceil(float(BlocsMaitres.nombre()) / COLONNES))
	var premiere: Image = _vues[0].get_texture().get_image()
	var planche := Image.create(CASE.x * COLONNES, CASE.y * lignes, false, premiere.get_format())
	planche.fill(FOND)

	for i in _vues.size():
		var img: Image = _vues[i].get_texture().get_image()
		var coin := Vector2i((i % COLONNES) * CASE.x, (i / COLONNES) * CASE.y)
		planche.blit_rect(img, Rect2i(Vector2i.ZERO, CASE), coin)
		var couleur: Color = LISERE_INT \
			if BlocsMaitres.BLOCS[i]["contexte"] == BlocsMaitres.INTERIEUR else LISERE_EXT
		_liserer(planche, coin, couleur)

	var err := planche.save_png(_sortie)
	print("planche %d×%d → %s (%s)"
		% [planche.get_width(), planche.get_height(), _sortie,
			"écrite" if err == OK else "ERREUR %d" % err])
	print("\nordre de lecture, de gauche à droite puis de haut en bas :")
	for i in BlocsMaitres.nombre():
		var b: Dictionary = BlocsMaitres.BLOCS[i]
		print("   %d. %-20s [%s]  %s" % [i + 1, b["nom"], b["contexte"], b["quoi"]])
	print("\n   liseré OR = extérieur (à ciel ouvert) · liseré BLEU = intérieur (sous un plafond)")
	print("   vert = ce qui regarde le ciel · bleu = un plafond · brun = une paroi")
	quit(0 if err == OK else 1)


## Le liseré autour d'une case : c'est lui qui porte le contexte.
func _liserer(image: Image, coin: Vector2i, couleur: Color) -> void:
	for e in EPAISSEUR:
		for x in CASE.x:
			image.set_pixel(coin.x + x, coin.y + e, couleur)
			image.set_pixel(coin.x + x, coin.y + CASE.y - 1 - e, couleur)
		for y in CASE.y:
			image.set_pixel(coin.x + e, coin.y + y, couleur)
			image.set_pixel(coin.x + CASE.x - 1 - e, coin.y + y, couleur)


## Une vue par bloc. ⚠ Caméra ORTHOGONALE et identique pour les neuf : une case plus grosse qu'une autre
## ferait croire à un bloc plus gros, alors qu'ils font tous COTE³.
func _faire_vue(i: int) -> SubViewport:
	var vue := SubViewport.new()
	vue.size = CASE
	vue.own_world_3d = true
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vue)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8892a4")
	env.ambient_light_energy = 0.75
	var monde := WorldEnvironment.new()
	monde.environment = env
	vue.add_child(monde)

	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-48, -34, 0)
	lumiere.light_energy = 1.15
	vue.add_child(lumiere)

	# Le bloc occupe [0 ; COTE] sur les trois axes : son centre est en COTE/2.
	var cible := Vector3.ONE * (BlocsMaitres.COTE * 0.5)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = BlocsMaitres.COTE * 1.65
	camera.position = cible + Vector3(1.0, 0.82, 1.0).normalized() * 30.0
	vue.add_child(camera)
	camera.look_at_from_position(camera.position, cible, Vector3.UP)

	var instance := MeshInstance3D.new()
	instance.mesh = BlocsMaitres.maillage(i)
	vue.add_child(instance)
	return vue
