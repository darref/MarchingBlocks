extends SceneTree
##
## LA LÉGENDE DU TÉMOIN — le bloc a-t-il des régions lisibles, et à quoi ressemblent-elles ?
##
## LANCEMENT — ⚠ AVEC FENÊTRE (elle rend une image ; le headless ne rend RIEN) :
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks \
##       --script res://DEV_TOOLS/planche_legende.gd -- --sortie=D:/MarchingBlocks/ART/legende.png
##
## Avec `--brut`, le témoin est rendu AVEC SES PROPRES COULEURS — celles qui partent chez l'artiste —
## au lieu d'être repeint en deux teintes franches. C'est la seule façon de juger la légende livrée.
##
## ── POURQUOI ELLE EXISTE ────────────────────────────────────────────────────────────────────────────
##
## En fondant les neuf blocs en un seul, on a gagné les raccords visibles (mesuré : 22/22 germes) et
## **perdu la LÉGENDE**. Les neuf portaient chacun un nom et un rôle — « massif et plateau », « salle de
## grotte », « érosion ». Le bloc unique n'en porte aucun, et Jordan s'est trompé à cause de ça :
## *« j'ai fait un chapeau de champignon en extrudant toutes les faces les plus hautes en pensant
## qu'elles représentaient le massif de base »*. Il a dû deviner, et il a deviné faux.
##
## ⚠ **ON MESURE AVANT DE CONCEVOIR : une légende ne peut désigner que ce qui existe.**
##
##   • si le massif, la falaise et la grotte forment des régions FRANCHES, une légende peut les montrer ;
##   • si elles sont entrelacées case par case, aucune légende n'y suffira et il faudra autre chose.
##
## C'est ce que comptent les COMPOSANTES CONNEXES ci-dessous — « franc » ou « émietté » est une mesure,
## pas une impression.
##
## ── LE CRITÈRE, ET POURQUOI CELUI-LÀ ────────────────────────────────────────────────────────────────
##
## **« ROCHE AU-DESSUS »**, choisi par élimination et mesuré à 0 % de dérive (charte §2). Les deux
## autres candidats ont été disqualifiés : le *vide enclos* déclarait 0 case de tunnel sur 48 comme
## intérieure, et l'*occlusion du ciel* faisait changer d'avis 11 % des sommets entre deux échelles —
## l'artiste aurait sculpté des tuiles que le pinceau n'aurait jamais posées là.
##
## ⚠ **IL EST RECALCULÉ ICI, ce qui fait une seconde description** : le greffon ne porte que
## `MB.exterieur_possible(bits)`, qui parle d'une CLASSE et pas d'une case. Le critère de case n'a
## jamais été rangé dans le module — il vivait dans des sondes. Si la légende est adoptée, il devra
## descendre dans `blocs_maitres.gd` pour n'exister qu'une fois.

const MB := preload("res://addons/marchingblocks_core/marching_blocks.gd")
const BM := preload("res://addons/marchingblocks_core/blocs_maitres.gd")
## ⚠ La lecture des chutes vit LÀ-BAS, et `sonde_reste_t_il_des_marches.gd` lit la même : cette
## planche PEINT ce que la sonde COMPTE, et deux écritures auraient fini par ne plus s'accorder.
const Topologie := preload("res://DEV_TOOLS/topologie.gd")

const CASE := Vector2i(380, 380)
const FOND := Color("#101216")
const OR := Color("#ebbb69")

## ⚠ LES MÊMES COULEURS QUE LA PLANCHE DES NEUF BLOCS : l'or pour ce qui est à ciel ouvert, le bleu pour
## ce qui est sous un plafond. Changer de code couleur entre deux planches du même projet, c'est obliger
## le lecteur à retenir deux conventions pour une seule idée.
const DEHORS := Color("#ebbb69")
const DEDANS := Color("#5b8fd6")

## ⚠ **LES TEINTES DES CHUTES — une par hauteur de contremarche, et une seule idée par couleur.**
## Jordan, 26 septembre 2026 : « je vois toujours des contremarches. » La sonde répond qu'il n'en reste
## AUCUNE sur une chute d'une cellule, et que tout ce qui est vertical siège sur une chute de 2 à 5 —
## donc dans l'OCCUPATION, pas dans le mailleur. Mais un compteur ne dit jamais LESQUELLES le gênent
## (charte §6 : « un compteur vert ne dit jamais qu'une tuile est à SA place »). Cette image les montre
## une par une, pour qu'il puisse désigner.
const CHUTES := [
	Color("#d8452f"),   # 1 cellule — ⚠ ROUGE, et il ne DOIT rien peindre : c'est le contrôle visuel
	Color("#e8913c"),   # 2 cellules
	Color("#e5d24a"),   # 3 cellules
	Color("#7fc26a"),   # 4 cellules
	Color("#4fa6d8"),   # 5 cellules et plus
]
## Ce qui n'est pas une paroi verticale : gris neutre, pour que seules les chutes se voient.
const NEUTRE := Color("#6b6f76")

const ANGLES := [
	{"quoi": "trois quarts haut", "dir": Vector3(1.0, 0.8, 1.0)},
	{"quoi": "trois quarts bas", "dir": Vector3(1.0, 0.18, 1.0)},
	{"quoi": "de face", "dir": Vector3(0.0, 0.15, 1.0)},
	{"quoi": "de dessous", "dir": Vector3(1.0, -0.5, 1.0)},
]

var _sortie := "legende.png"
## ⚠ **`--brut` REND LE TÉMOIN TEL QU'IL PART, SANS RECOLORIAGE.** Cette planche a été écrite pour
## CHERCHER une légende : elle repeint le bloc en deux teintes franches pour montrer ce qu'une légende
## POURRAIT désigner. Depuis, la légende est dans le maillage lui-même — la roche souterraine part
## assombrie et désaturée. Les deux images répondent à deux questions : « une légende est-elle
## possible ? » (sans l'option) et « celle qu'on livre se voit-elle ? » (avec).
## ⚠ Et c'est bien la MÊME planche, pas une seconde : mêmes angles, même cadrage, même fond. Deux
## planches divergeraient au premier réglage, et l'on comparerait deux images qui ne se comparent pas.
var _brut := false
## ⚠ **QUEL BLOC — parce qu'il y en a DEUX depuis le 25 septembre 2026** (le paysage, puis le résidu).
## Cette planche en lisait un seul, en dur. Un paramètre plutôt qu'une seconde planche : sa propre note
## sur `--brut` le dit déjà — deux planches divergeraient au premier réglage, et l'on comparerait alors
## deux images qui ne se comparent pas.
var _bloc := 0
## ⚠ Le témoin en FACES DIRECTES (Jordan, 25 septembre 2026) — la géométrie dérivée de la CLASSE au lieu
## de la coque en sous-voxels, donc sans escaliers. À juger à l'œil, jamais au compteur.
var _direct := false
## ⚠ **`--chutes` PEINT CHAQUE PAROI VERTICALE PAR LA HAUTEUR DE SA CHUTE**, lue dans l'OCCUPATION.
## Il implique `--direct` : c'est le mailleur mis en cause.
var _chutes := false
## ⚠ **`--lisse=0.35` REND LE TÉMOIN CHANFREINÉ** (`maillage_lisse`, suspendu depuis le 25 septembre
## 2026). Il est revenu dans la course le 26, quand Jordan a précisé que les « contremarches » qu'il
## voyait étaient les **lèvres d'un sous-voxel** de l'amincissement : mesuré, le chanfrein en retire 12
## sur 13 sans toucher aux décrochements d'une cellule, là où les faces directes les aplatissent tous.
var _lisse := -1.0
var _vues: Array = []
var _images := 0


func _initialize() -> void:
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--sortie="):
			_sortie = option.substr("--sortie=".length())
		if option.begins_with("--bloc="):
			_bloc = int(option.substr("--bloc=".length()))
		if option == "--brut":
			_brut = true
		if option == "--direct":
			_direct = true
		if option.begins_with("--lisse="):
			_lisse = float(option.substr("--lisse=".length()))
		if option == "--chutes":
			_chutes = true
			# ⚠ La question ne se pose que sur les faces directes : sur la coque en sous-voxels on
			# SAIT déjà qu'il reste des contremarches, la sonde le mesure à 4,31 case².
			_direct = true
	if _bloc < 0 or _bloc >= BM.nombre():
		print("⚠ --bloc=%d : il y a %d bloc(s)" % [_bloc, BM.nombre()])
		quit(1)
		return
	print("bloc %d — « %s »\n" % [_bloc, BM.BLOCS[_bloc]["nom"]])

	var pleines: Dictionary = BM.cases(_bloc)
	var region: Dictionary = _regions(pleines)

	# ── LA MESURE ───────────────────────────────────────────────────────────────────────────────────
	var dehors := 0
	var dedans := 0
	for c in region:
		if region[c]:
			dehors += 1
		else:
			dedans += 1
	print("=== LE BLOC A-T-IL DES RÉGIONS LISIBLES ? ===\n")
	print("critère : « roche au-dessus » — une case est DEDANS si une case pleine la surplombe\n")
	print("%d case(s) pleine(s)  ·  %d à ciel ouvert (%.1f %%)  ·  %d sous roche (%.1f %%)"
		% [region.size(), dehors, 100.0 * float(dehors) / maxf(1.0, float(region.size())),
			dedans, 100.0 * float(dedans) / maxf(1.0, float(region.size()))])

	# ⚠ LES COMPOSANTES CONNEXES DISENT « FRANC » OU « ÉMIETTÉ ». Une région en un seul morceau se
	# désigne du doigt ; la même en quarante miettes ne se désigne pas, et aucune légende n'y suffira.
	for quoi in [true, false]:
		var tailles: Array = _composantes(region, quoi)
		tailles.sort()
		tailles.reverse()
		var nom: String = "à ciel ouvert" if quoi else "sous roche"
		print("   %-15s : %d morceau(x) connexe(s), les plus gros : %s"
			% [nom, tailles.size(), str(tailles.slice(0, 6))])
		if tailles.size() > 0:
			var part: float = 100.0 * float(tailles[0]) / maxf(1.0, float(
				dehors if quoi else dedans))
			print("                     le plus gros porte %.1f %% de la région" % part)

	print("\n⚠ « Franc » se lit dans ces chiffres : une région dont le plus gros morceau porte")
	print("   l'essentiel est désignable ; une région en confettis ne l'est pas.\n")

	# ⚠ `--direct` rend le témoin en FACES DIRECTES au lieu de la coque en sous-voxels : c'est la seule
	# façon de juger si les escaliers ont disparu, et aucun compteur ne le dira (charte §6).
	var temoin: ArrayMesh = BM.maillage_moitie(_bloc)
	if _direct:
		temoin = BM.maillage_direct(_bloc)
	elif _lisse >= 0.0:
		print("⚠ --lisse=%.2f : le témoin est CHANFREINÉ (maillage dual sur les sous-voxels).\n" % _lisse)
		temoin = BM.maillage_lisse(_bloc, 0.5, _lisse)
	if _brut:
		print("⚠ --brut : le témoin est rendu TEL QU'IL PART, avec ses propres couleurs.")
		print("   Ce qu'on juge ici : la roche souterraine se distingue-t-elle d'une face à l'ombre ?\n")
	var rendu: ArrayMesh = temoin
	if _chutes:
		print("⚠ --chutes : chaque paroi VERTICALE est peinte par la hauteur de sa chute.")
		print("   Ce qu'on juge ici : parmi ces marches, lesquelles gênent Jordan ?
")
		rendu = _colorier_chutes(temoin, pleines)
	elif not _brut:
		rendu = _colorier(temoin, region)
	for a in ANGLES:
		_vues.append(_faire_vue(rendu, a["dir"]))
	process_frame.connect(_image)


## Quelles cases sont sous roche. ⚠ On ne regarde QUE la verticale au-dessus : le critère doit répondre
## « oui ou non », jamais « combien » — c'est ce qui le rend stable quand le bloc change d'échelle,
## alors que l'occlusion du ciel faisait changer d'avis 11 % des sommets.
func _regions(pleines: Dictionary) -> Dictionary:
	var region := {}
	for c in pleines:
		var p: Vector3i = c
		var couvert := false
		for y in range(p.y + 1, BM.COTE):
			if pleines.has(Vector3i(p.x, y, p.z)):
				couvert = true
				break
		region[p] = not couvert
	return region


## Les tailles des morceaux connexes d'une région (voisinage à 6 faces).
func _composantes(region: Dictionary, valeur: bool) -> Array:
	var restants := {}
	for c in region:
		if region[c] == valeur:
			restants[c] = true
	var tailles: Array = []
	while not restants.is_empty():
		var depart: Vector3i = restants.keys()[0]
		var pile: Array = [depart]
		restants.erase(depart)
		var n := 0
		while not pile.is_empty():
			var p: Vector3i = pile.pop_back()
			n += 1
			for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
					Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				var q: Vector3i = p + d
				if restants.has(q):
					restants.erase(q)
					pile.append(q)
		tailles.append(n)
	return tailles


## Recolore le maillage RÉEL par région. ⚠ On ne rebâtit pas la coque : on reprend celle qui part chez
## l'artiste et on ne change que `ARRAY_COLOR`. Une seconde description de l'émission aurait divergé, et
## la légende aurait décrit une géométrie que personne ne reçoit.
func _colorier(mesh: ArrayMesh, region: Dictionary) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var couleurs := PackedColorArray()
	couleurs.resize(v.size())
	# ⚠ PAR TRIANGLE, d'après le CENTROÏDE : un sommet posé sur la frontière de deux cases appartient
	# aux deux, et le colorier par sa position le ferait clignoter d'une région à l'autre.
	for t in range(0, v.size() - 2, 3):
		var centre: Vector3 = (v[t] + v[t + 1] + v[t + 2]) / 3.0
		var case := Vector3i(floori(centre.x), floori(centre.y), floori(centre.z))
		var dehors: bool = bool(region.get(case, true))
		var couleur: Color = DEHORS if dehors else DEDANS
		for k in 3:
			couleurs[t + k] = couleur
	arrays[Mesh.ARRAY_COLOR] = couleurs
	var sortie := ArrayMesh.new()
	sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	sortie.surface_set_material(0, m)
	return sortie


## PEINT CHAQUE PAROI VERTICALE PAR LA HAUTEUR DE SA CHUTE. Le reste est gris.
##
## ⚠ **ELLE NE RECALCULE RIEN** : le maillage est celui qui part, la chute est lue par
## `Topologie.chute_de()` — la même fonction que la sonde qui les COMPTE. Une image qui montrerait
## d'autres chutes que celles qui sont mesurées serait pire qu'aucune image.
##
## ⚠ **ET LE ROUGE EST LE CONTRÔLE VISUEL** : il désigne les chutes d'UNE cellule, dont la sonde dit
## qu'il n'en reste aucune. Si du rouge apparaît sur cette planche, c'est la mesure qui est fausse.
func _colorier_chutes(mesh: ArrayMesh, pleines: Dictionary) -> ArrayMesh:
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var couleurs := PackedColorArray()
	couleurs.resize(v.size())
	var compte := {}
	for t in range(0, v.size() - 2, 3):
		var couleur: Color = NEUTRE
		var u: Vector3 = n[t]
		if absf(u.y) < 0.1:
			var centre: Vector3 = (v[t] + v[t + 1] + v[t + 2]) / 3.0
			var h: int = Topologie.chute_de(pleines, centre, u, BM.COTE)
			if h > 0:
				couleur = CHUTES[mini(h, CHUTES.size()) - 1]
				compte[mini(h, CHUTES.size())] = int(compte.get(mini(h, CHUTES.size()), 0)) + 1
		for k in 3:
			couleurs[t + k] = couleur
	var hauteurs: Array = compte.keys()
	hauteurs.sort()
	for h in hauteurs:
		print("   chute de %d cellule(s)%s : %d triangle(s) peints"
			% [h, " et plus" if int(h) == CHUTES.size() else "", compte[h]])
	print("")
	arrays[Mesh.ARRAY_COLOR] = couleurs
	var sortie := ArrayMesh.new()
	sortie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	sortie.surface_set_material(0, m)
	return sortie


func _image() -> void:
	_images += 1
	if _images < 5:
		return
	var premiere: Image = _vues[0].get_texture().get_image()
	var planche := Image.create(CASE.x * ANGLES.size(), CASE.y, false, premiere.get_format())
	planche.fill(FOND)
	for i in _vues.size():
		var img: Image = _vues[i].get_texture().get_image()
		planche.blit_rect(img, Rect2i(Vector2i.ZERO, CASE), Vector2i(i * CASE.x, 0))
	var err := planche.save_png(_sortie)
	print("planche %d×%d → %s (%s)"
		% [planche.get_width(), planche.get_height(), _sortie,
			"écrite" if err == OK else "ERREUR %d" % err])
	if _chutes:
		# ⚠ **L'OMBRE CHANGE LA TEINTE, ET JE L'AI PRISE POUR UN DÉFAUT.** Une large bande OCRE est
		# apparue sur la planche, absente de la légende ; relevé au pixel, `#937f5c` est exactement
		# `#e8913c` — l'orange des chutes de 2 — sous la seule lumière ambiante. C'est donc une vraie
		# contremarche, à l'ombre. La charte §5 le dit déjà pour les six teintes du témoin : « la
		# lumière directionnelle assombrit les faces à l'ombre du même ordre de grandeur ».
		print("   ⚠ à l'ombre les teintes foncent : l'orange y devient OCRE, le jaune OLIVE.")
		print("   ROUGE = chute d'1 cellule (il ne doit y en avoir AUCUNE)  ·  ORANGE = 2  ·")
		print("   JAUNE = 3  ·  VERT = 4  ·  BLEU = 5 et plus  ·  GRIS = tout ce qui n'est pas vertical")
	else:
		print("   OR = à ciel ouvert (massif, falaise)   ·   BLEU = sous roche (grotte)")
	print("   colonnes : %s" % ", ".join(PackedStringArray(ANGLES.map(func(a): return a["quoi"]))))
	print("\n⚠ Ceci est un PROTOTYPE de légende, pas la légende : elle devra voyager DANS le .glb.")
	quit(0 if err == OK else 1)


func _faire_vue(mesh: ArrayMesh, direction: Vector3) -> SubViewport:
	var vue := SubViewport.new()
	vue.size = CASE
	vue.own_world_3d = true
	vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vue)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9aa4b4")
	env.ambient_light_energy = 1.0
	var monde := WorldEnvironment.new()
	monde.environment = env
	vue.add_child(monde)

	var lumiere := DirectionalLight3D.new()
	lumiere.rotation_degrees = Vector3(-42, -38, 0)
	lumiere.light_energy = 1.0
	vue.add_child(lumiere)

	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	vue.add_child(instance)

	var cible := Vector3.ONE * (BM.COTE * 0.5)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = BM.COTE * 1.5
	camera.position = cible + direction.normalized() * 30.0
	vue.add_child(camera)
	camera.look_at_from_position(camera.position, cible, Vector3.UP)
	return vue
