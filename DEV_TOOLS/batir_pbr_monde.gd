extends SceneTree
##
## BÂTIR LE PBR ESPACE MONDE — trois tableaux de textures, une couche par teinte du témoin.
##
## LANCEMENT
##   Godot_v4.7-stable_win64_console.exe --path D:/MarchingBlocks --script res://DEV_TOOLS/batir_pbr_monde.gd
##   ⚠ AVEC FENÊTRE : en headless, les couches ressortent VIDES (voir `_ecrire`).
##
## ── CE QU'IL FAIT ───────────────────────────────────────────────────────────────────────────────────
##
## Jordan, 27 septembre 2026 : *« texturer en pbr espace monde : sur le témoin ajoute à chaque couleur
## un full PBR — albedo, normal, ao, roughness et height (POM) — qui s'applique aussi au monde peint,
## car le matériau suit dans les tuiles. Prends des PBR sets dans heartworld pour tester. »*
##
## Il lit un set par teinte dans le `HEART_WORLD` de Spirit3D, et écrit dans `ART/pbr_monde/` :
##   • `albedo.res`  — la couleur, sRGB ;
##   • `normale.res` — la carte de normales, convention OpenGL (Y vers le HAUT de l'image) ;
##   • `orh.res`     — R = occlusion ambiante, G = rugosité, B = hauteur (blanc = haut).
## Chacun est un `Texture2DArray` de SIX couches, dans l'ordre de `RP.TEINTES` — ⚠ l'ordre n'est pas
## écrit ici : on parcourt `RP.TEINTES` et on cherche le set par son nom. Le shader lit ses couches
## dans ce même ordre ; une seconde liste ordonnée finirait par ne plus correspondre.
##
## ⚠ **LES TEXTURES, PAS LE CODE** (mémoire « on garde le lot de Spirit3D, jamais son code ») : on
## n'emprunte à Spirit3D que des images. Et elles ne sont PAS suivies par git (`.gitignore`) : ce sont
## des dérivés d'un lot qui n'est pas le nôtre, régénérables par ce script.
##
## ⚠ **CONVENTION DE NORMALE : `normal_gl` SEULEMENT.** Les sets « Rock_0x » n'ont qu'un `Normal.jpg`
## sans convention déclarée : les prendre, c'était deviner le signe du vert — un relief inversé ne se
## voit qu'à l'image, et ne se signale nulle part.

const RP := preload("res://addons/marchingblocks_core/repli_procedural.gd")
const PBR := preload("res://addons/marchingblocks_core/pbr_monde.gd")

const SOURCE := "D:/Spirit3D/HEART_WORLD/biomes/maps/"
const COTE := 1024

## Le set de chaque teinte, par le NOM de la teinte (`RP.TEINTES`). Changer un set, c'est changer une
## ligne ici et relancer.
const SETS := {
	"Floor - open air": "biome_savanna/grass_04_2k/grass_04",
	"Wall - open air": "biome_savanna/cliff_rocks_03_2k/cliff_rocks_03",
	"Overhang - open air": "biome_highpeaks/cliff_rocks_04_2k/cliff_rocks_04",
	"Floor - underground": "biome_karst/ground_stones_03_2k/ground_stones_03",
	"Wall - underground": "biome_firelands/cliff_rocks_05_2k/cliff_rocks_05",
	"Ceiling - underground": "biome_firelands/cliff_rocks_05_2k/cliff_rocks_05",
}


func _initialize() -> void:
	print("=== LE PBR ESPACE MONDE ===\n")
	var albedos: Array[Image] = []
	var normales: Array[Image] = []
	var orhs: Array[Image] = []
	for teinte in RP.TEINTES:
		var nom: String = teinte["nom"]
		if not SETS.has(nom):
			print("⚠ aucune entrée pour la teinte « %s »" % nom)
			quit(1)
			return
		var racine: String = SOURCE + SETS[nom]
		print("── %s ← %s" % [nom, SETS[nom].get_file()])
		var a: Image = _lire(racine, ["_basecolor_2k", "_baseColor_2k"])
		var n: Image = _lire(racine, ["_normal_gl_2k"])
		var o: Image = _lire(racine, ["_ambientOcclusion_2k", "_ambientocclusion_2k"])
		var r: Image = _lire(racine, ["_roughness_2k"])
		var h: Image = _lire(racine, ["_height_2k"])
		if a == null or n == null or o == null or r == null or h == null:
			quit(1)
			return
		albedos.append(_preparer(a, Image.COMPRESS_SOURCE_SRGB))
		normales.append(_preparer(n, Image.COMPRESS_SOURCE_NORMAL))
		orhs.append(_preparer(_empaqueter(o, r, h), Image.COMPRESS_SOURCE_GENERIC))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PBR.DOSSIER))
	var ok := true
	ok = _ecrire(albedos, "albedo") and ok
	ok = _ecrire(normales, "normale") and ok
	ok = _ecrire(orhs, "orh") and ok
	print("\n%s" % ("✓ trois tableaux de six couches écrits dans %s" % PBR.DOSSIER if ok
		else "⚠ ÉCHEC — voir plus haut"))
	quit(0 if ok else 1)


## Le premier fichier qui existe parmi les suffixes proposés — les sets n'écrivent pas tous la même
## casse (`baseColor` / `basecolor`). ⚠ On le DIT s'il n'y en a aucun, plutôt que de rendre une couche
## noire.
func _lire(racine: String, suffixes: Array) -> Image:
	for s in suffixes:
		var chemin: String = racine + s + ".png"
		if FileAccess.file_exists(chemin):
			var img := Image.load_from_file(chemin)
			if img != null and not img.is_empty():
				img.decompress()
				img.convert(Image.FORMAT_RGBA8)
				img.resize(COTE, COTE, Image.INTERPOLATE_LANCZOS)
				return img
	print("⚠ introuvable : %s{%s}.png" % [racine, "|".join(PackedStringArray(suffixes))])
	return null


## R = AO, G = rugosité, B = hauteur. Trois cartes en niveaux de gris dans une seule image : un seul
## échantillonnage par plan au lieu de trois, et c'est la boucle du POM qui le paie le plus.
func _empaqueter(ao: Image, rugosite: Image, hauteur: Image) -> Image:
	var da: PackedByteArray = ao.get_data()
	var dr: PackedByteArray = rugosite.get_data()
	var dh: PackedByteArray = hauteur.get_data()
	var sortie := PackedByteArray()
	sortie.resize(COTE * COTE * 4)
	for i in range(0, sortie.size(), 4):
		sortie[i] = da[i]
		sortie[i + 1] = dr[i]
		sortie[i + 2] = dh[i]
		sortie[i + 3] = 255
	return Image.create_from_data(COTE, COTE, false, Image.FORMAT_RGBA8, sortie)


## Mipmaps puis compression. ⚠ S3TC et non BPTC : son compresseur tourne sur le PROCESSEUR, donc en
## headless ; et pour une normale il rend du RGTC — deux canaux, X et Y — dont le shader reconstruit Z.
func _preparer(img: Image, source: Image.CompressSource) -> Image:
	img.generate_mipmaps()
	var err := img.compress(Image.COMPRESS_S3TC, source)
	if err != OK:
		print("⚠ compression refusée (%d) : couche laissée brute" % err)
	return img


func _ecrire(couches: Array[Image], nom: String) -> bool:
	var tableau := Texture2DArray.new()
	var err := tableau.create_from_images(couches)
	if err != OK:
		print("⚠ %s : create_from_images a refusé (%d) — formats %s" % [nom, err,
			str(couches.map(func(i): return i.get_format()))])
		return false
	var chemin: String = PBR.DOSSIER + nom + ".res"
	err = ResourceSaver.save(tableau, chemin)
	if err != OK:
		print("⚠ %s : écriture refusée (%d)" % [chemin, err])
		return false
	# ⚠ **UN FICHIER ÉCRIT N'EST PAS UN FICHIER PLEIN — LA PREMIÈRE VERSION A AFFICHÉ « ✓ » SUR TROIS
	# FICHIERS DE 324 OCTETS.** En headless, le serveur de rendu est factice : il ne garde pas les
	# pixels, et un `Texture2DArray` s'enregistre en relisant ses couches CHEZ LUI. On exige donc au
	# moins la taille compressée de la plus grosse mip de chaque couche.
	var attendu: int = couches.size() * couches[0].get_data_size() / 2
	var ecrit: int = FileAccess.get_file_as_bytes(chemin).size()
	print("   %s — %d couches de %d², format %d, %s octets"
		% [chemin, tableau.get_layers(), COTE, couches[0].get_format(), String.num_int64(ecrit)])
	if ecrit < attendu:
		print("   ⚠ VIDE : %d octets pour %d attendus au moins — lancer AVEC FENÊTRE, pas en headless"
			% [ecrit, attendu])
		return false
	return true
