extends RefCounted
## LE RENDU DES TRANSITIONS (6 octobre 2026) : la texture 3D des cases, la table des réglages, les représentants, et le
## matériau commun (`TR.SHADER`) que l'écran pose en `next_pass` sur les matériaux des tuiles. La règle est dans
## `transitions.gd`.

const TR := preload("res://addons/marchingblocks_core/transitions.gd")

var materiau: ShaderMaterial
var donnees := {}
var _texture_cases: ImageTexture3D
var _tranches: Array[Image] = []
var _texture_table: ImageTexture
var _representants: Texture2DArray
## Les tranches (z) modifiées depuis le dernier envoi.
var _sales := {}
var _a_reconstruire := true

func _init() -> void:
	var sh := Shader.new()
	sh.code = TR.SHADER
	materiau = ShaderMaterial.new()
	materiau.resource_name = "mb_transitions"
	materiau.shader = sh
	# Après les matériaux de l'artiste : une surface transparente, dessinée par-dessus.
	materiau.render_priority = 1

## Toute la texture, depuis l'union et les choix.
func reconstruire(union: Dictionary, choix: Dictionary) -> void:
	donnees = TR.construire(union, choix)
	_tranches = TR.tranches(donnees)
	_texture_cases = ImageTexture3D.new()
	var n: Vector3i = donnees["taille"]
	_texture_cases.create(Image.FORMAT_RG8, n.x, n.y, n.z, false, _tranches)
	materiau.set_shader_parameter("cases", _texture_cases)
	materiau.set_shader_parameter("origine", donnees["origine"])
	materiau.set_shader_parameter("taille", n)
	_sales = {}
	_a_reconstruire = false

## Une case a changé (rang −1 : vidée). Rend faux si la boîte ne la contient pas : il faut reconstruire.
func case(c: Vector3i, rang: int) -> bool:
	if donnees.is_empty() or not TR.poser_case(donnees, c, rang):
		_a_reconstruire = true
		return false
	_sales[c.z - (donnees["origine"] as Vector3i).z] = true
	return true

func choix(s: Vector3i, rang: int) -> bool:
	if donnees.is_empty() or not TR.poser_choix(donnees, s, rang):
		_a_reconstruire = true
		return false
	_sales[s.z - (donnees["origine"] as Vector3i).z] = true
	return true

func a_reconstruire() -> bool:
	return _a_reconstruire or donnees.is_empty()

## Envoie les tranches modifiées.
func envoyer() -> void:
	if _sales.is_empty() or _texture_cases == null:
		return
	_tranches = TR.tranches(donnees, _sales, _tranches)
	_texture_cases.update(_tranches)
	_sales = {}

## La table des réglages (2·N × N flottants, N = le plus grand rang de la table + 1, au plus `TR.MAXI` : 21 octobre 2026 —
## elle était de 30 × 15 quoi qu'il arrive) : au texel (2·D, C) actif, largeur, avance, bruit ; à (2·D+1, C) creux,
## grain — quand C couvre D. Le shader ne fond pas un rang hors d'elle.
func poser_table(t: Dictionary) -> void:
	var n := 1
	for cle in t:
		for r in String(cle).split("|"):
			n = maxi(n, int(r) + 1)
	n = mini(n, TR.MAXI)
	var img := Image.create_empty(2 * n, n, false, Image.FORMAT_RGBAF)
	for cle in t:
		var cd: PackedStringArray = String(cle).split("|")
		var c := int(cd[0])
		var d := int(cd[1])
		if c >= n or d >= n:
			continue
		var rg: Dictionary = t[cle]
		img.set_pixel(2 * d, c, Color(1.0, rg["largeur"], rg["avance"], rg["bruit"]))
		img.set_pixel(2 * d + 1, c, Color(rg["creux"], rg["grain"], 0.0, 0.0))
	# Au plus 510 × 255 texels (2 Mo) : une texture neuve à chaque fois (`ImageTexture.update` ne garde pas l'image en
	# headless, et la taille change avec le nombre de couches).
	_texture_table = ImageTexture.create_from_image(img)
	materiau.set_shader_parameter("table", _texture_table)

## Les représentants, par rang : [{image: Image ou null, couleur, echelle, rugosite}] — UNE TRANCHE PAR COUCHE RÉELLE (au
## plus `TR.MAXI`) (21 octobre 2026 : 15 tranches quoi qu'il arrive jusque-là). Une tranche de 256² RGBA8 et ses mipmaps : ~350 Ko ;
## 22 couches ~7,7 Mo, 255 couches ~89 Mo (le pire).
func poser_representants(liste: Array) -> void:
	var images: Array[Image] = []
	var n := clampi(liste.size(), 1, TR.MAXI)
	var params := Image.create_empty(n, 2, false, Image.FORMAT_RGBAF)
	for k in n:
		var d: Dictionary = liste[k] if k < liste.size() else {}
		var img: Image = null
		if d.get("image") is Image:
			img = (d["image"] as Image).duplicate()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(256, 256, Image.INTERPOLATE_BILINEAR)
		else:
			img = Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
		img.generate_mipmaps()
		images.append(img)
		params.set_pixel(k, 0, d.get("couleur", Color.WHITE))
		params.set_pixel(k, 1, Color(float(d.get("echelle", 1.0)), float(d.get("rugosite", 0.8)), 0.0, 0.0))
	_representants = Texture2DArray.new()
	_representants.create_from_images(images)
	materiau.set_shader_parameter("representants", _representants)
	materiau.set_shader_parameter("rep_params", ImageTexture.create_from_image(params))
