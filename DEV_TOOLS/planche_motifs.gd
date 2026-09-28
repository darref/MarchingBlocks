extends SceneTree
##
## LA PLANCHE DES MOTIFS — ce que peindre 1, 2, 4 puis 8 cases donne réellement.
##
## LANCEMENT — ⚠ AVEC FENÊTRE, jamais en headless (le headless ne rend RIEN) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/planche_motifs.gd \
##       -- --fichier=C:/chemin/vers/le.glb --sortie=D:/MarchingBlocks/ART/motifs.png
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## Jordan, 25 septembre 2026 : *« depuis le master bloc unique, peindre ne dessine plus les formes les
## plus simples en priorité »*, et il décrit exactement l'essai : *« peindre une tuile seule faisait bien
## la solo, une bande de 2 faisait bien deux bouts collés, un 2×2 faisait bien 4 coins d'un étage, la
## même chose sur deux étages faisait bien 2×2×2 coins »*.
##
## Cette planche reproduit ces quatre motifs, et les rend **deux fois** : depuis le lot du TÉMOIN et
## depuis le lot d'un `.glb` sculpté.
##
## ⚠ **C'EST LE CONTRÔLE QUI MANQUAIT À TOUT LE DIAGNOSTIC.** Jordan a peint avec le lot importé ; je
## n'ai jamais vérifié que le catalogue du témoin dessine juste. Si les deux lignes sont fausses, le
## défaut est dans la POSE et le sculpt n'y est pour rien ; si seule la ligne du bas l'est, il est dans
## ce que le tranchage tire du relief. Sans cette séparation, on cherche des deux côtés à la fois.
##
## ── CE QU'ELLE N'INVENTE PAS ────────────────────────────────────────────────────────────────────────
##
## ⚠ Elle emploie le **VRAI `MassifPeint`** : elle peint dans sa grille `Cases` et appelle son
## `reconstruire()`. Après trois instruments faux dans la même soirée, je ne réécris pas la pose dans
## l'outil censé la vérifier — une seconde description diverge toujours (charte §6), et ici elle
## divergerait précisément sur ce qu'on cherche.
## ⚠ `Engine.is_editor_hint()` est faux sous `--script`, donc le suivi automatique ne tourne pas : on
## appelle `preparer()` puis `reconstruire()` à la main, dans cet ordre.

const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")

const CASE := Vector2i(340, 340)
const FOND := Color("#101216")
const OR := Color("#ebbb69")

## Les quatre motifs, dans les mots de Jordan. ⚠ Écrits, pas tirés au hasard : ce sont EXACTEMENT les
## gestes qu'il a essayés, et c'est ce qui rend l'image comparable à ce qu'il a vu.
const MOTIFS := [
	{"quoi": "1 case (la solo)", "cases": [Vector3i(0, 0, 0)]},
	{"quoi": "2 collées", "cases": [Vector3i(0, 0, 0), Vector3i(1, 0, 0)]},
	{"quoi": "2x2 (un étage)", "cases": [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1)]},
	{"quoi": "2x2x2 (deux étages)", "cases": [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1),
		Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 1), Vector3i(1, 1, 1)]},
]

## ⚠ **UN `const` NE PEUT PAS APPELER UNE FONCTION — et je l'ai écrit ainsi du premier coup.** Les
## quatre motifs ci-dessus sont littéraux ; le plateau, lui, est DÉRIVÉ, donc il rejoint la liste à
## l'exécution. Recopier trente-six coordonnées à la main aurait été trente-six occasions de se tromper
## d'une case sans que rien ne le signale.
##
## ⚠ **ET C'EST UN CHAMP, PAS UN MOTIF.** Les quatre motifs jugent la FORME, et quatre cases y
## suffisent. Mais les UV sont CUITES dans chaque tuile : une même tuile répète son fragment de texture
## à chaque pose, et **ça ne se voit qu'à partir d'un champ**. Sur 2×2 on ne distingue pas un motif
## d'une répétition.
var _motifs: Array = []


## Un plateau plein de `n`×`n` cases sur un seul étage. ⚠ DÉRIVÉ plutôt qu'écrit à la main : trente-six
## coordonnées recopiées, c'est trente-six occasions de se tromper d'une case sans que rien ne le dise.
static func _plateau(n: int) -> Array:
	var cases: Array = []
	for x in n:
		for z in n:
			cases.append(Vector3i(x, 0, z))
	return cases

var _fichier := ""
var _sortie := "motifs.png"
var _vues: Array = []
var _images := 0


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--fichier="):
			_fichier = option.substr("--fichier=".length())
		if option.begins_with("--sortie="):
			_sortie = option.substr("--sortie=".length())

	var lots: Array = [{"quoi": "TÉMOIN", "lot": (BM.librairie()["lot"] as MeshLibrary)}]
	if _fichier != "":
		if not FileAccess.file_exists(_fichier):
			print("⚠ INTROUVABLE : %s" % _fichier)
			quit(1)
			return
		var bilan: Dictionary = BM.librairie_depuis_glb(_fichier)
		# ⚠ SI LE BLOC N'A PAS ÉTÉ RELU, le lot est le témoin CALCULÉ : la ligne du bas montrerait le
		# témoin en se faisant passer pour le sculpt. On refuse plutôt que de rendre une image qui
		# rassure à tort.
		if not (bilan["absents"] as Array).is_empty():
			print("⚠⚠ le bloc n'a PAS été relu du disque — la ligne du bas serait le témoin calculé.")
			quit(1)
			return
		lots.append({"quoi": "SCULPT", "lot": (bilan["lot"] as MeshLibrary)})
		print("relu du disque : %s\n" % str(bilan["sculptes"]))

	_motifs = MOTIFS.duplicate()
	_motifs.append({"quoi": "plateau 6x6 (la répétition)", "cases": _plateau(6)})

	for source in lots:
		for motif in _motifs:
			var bilan: Dictionary = {}
			_vues.append(_faire_vue(source["lot"], motif["cases"], bilan))
			print("   %-8s %-22s → %s" % [source["quoi"], motif["quoi"], str(bilan)])
	process_frame.connect(_image)


func _image() -> void:
	_images += 1
	if _images < 6:   # ⚠ laisser les SubViewport rendre avant de capturer
		return
	var lignes: int = _vues.size() / _motifs.size()
	var premiere: Image = _vues[0].get_texture().get_image()
	var planche := Image.create(CASE.x * _motifs.size(), CASE.y * lignes, false,
		premiere.get_format())
	planche.fill(FOND)
	for i in _vues.size():
		var img: Image = _vues[i].get_texture().get_image()
		planche.blit_rect(img, Rect2i(Vector2i.ZERO, CASE),
			Vector2i((i % _motifs.size()) * CASE.x, (i / _motifs.size()) * CASE.y))
	if lignes > 1:
		for x in planche.get_width():
			planche.set_pixel(x, CASE.y, OR)
			planche.set_pixel(x, CASE.y - 1, OR)

	var err := planche.save_png(_sortie)
	print("\nplanche %d×%d → %s (%s)"
		% [planche.get_width(), planche.get_height(), _sortie,
			"écrite" if err == OK else "ERREUR %d" % err])
	print("   colonnes : %s"
		% ", ".join(PackedStringArray(_motifs.map(func(m): return m["quoi"]))))
	print("   HAUT = lot du TÉMOIN%s" % ("   ·   BAS = lot du SCULPT" if lignes > 1 else ""))
	print("\n⚠ Si les DEUX lignes sont fausses, le défaut est dans la pose, pas dans le sculpt.")
	quit(0 if err == OK else 1)


## Une vue par motif. ⚠ Le massif est le VRAI nœud du greffon : on peint ses cases et on lui demande de
## se reconstruire, exactement comme l'éditeur le fait.
func _faire_vue(lot: MeshLibrary, cases: Array, bilan: Dictionary) -> SubViewport:
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
	env.ambient_light_energy = 0.8
	var monde := WorldEnvironment.new()
	monde.environment = env
	vue.add_child(monde)

	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-42, -38, 0)
	lumiere.light_energy = 1.2
	vue.add_child(lumiere)

	var massif: Node3D = load("res://addons/marchingblocks_core/massif_peint.gd").new()
	massif.lot = lot
	vue.add_child(massif)
	massif.preparer()
	var grille: GridMap = massif.get_node_or_null("Cases")
	if grille != null and grille.mesh_library != null:
		var id: int = grille.mesh_library.find_item_by_name("case")
		for c in cases:
			grille.set_cell_item(c, id)
		# ⚠ ET ON EFFACE LA GRILLE DE PEINTURE DU RENDU : les cubes translucides « case » masqueraient
		# les pièces qu'on vient justement regarder. C'est un repère d'interface, pas de la matière.
		grille.visible = false
	bilan.merge(massif.reconstruire(), true)

	# ⚠ CADRÉ SUR LE MOTIF, pas sur l'origine : un 2×2×2 déborde d'un 1×1×1, et un cadrage fixe
	# rendrait les grands motifs coupés — on conclurait « faux » sur un défaut de caméra.
	var centre := Vector3.ZERO
	for c in cases:
		centre += Vector3(c)
	centre = centre / float(cases.size()) + Vector3.ONE * 0.5
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.0
	camera.position = centre + Vector3(1.0, 0.8, 1.0).normalized() * 12.0
	vue.add_child(camera)
	camera.look_at_from_position(camera.position, centre, Vector3.UP)
	return vue
