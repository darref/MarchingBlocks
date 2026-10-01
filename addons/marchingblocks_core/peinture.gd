extends RefCounted
## LA PEINTURE DU TÉMOIN — DÉCIDÉ (Jordan, 1er octobre 2026 : « de quoi dessiner la texture ou dessiner sur l'UV
## avec les outils de peinture classiques de tout soft 3D »). Le cœur, sans écran : les TOILES et le PINCEAU.
##
## ⚠ **UNE TOILE EST L'IMAGE D'UN MATÉRIAU, ET ELLE EST PARTAGÉE** : toutes les tuiles qui portent le matériau
## lisent la même `ImageTexture` (`texture_de`, appelée par `MaillageEdite.materiau_godot`). Peindre une copie
## peint donc toutes les copies d'une tuile — et toutes les tuiles qui portent ce matériau là où le rendu lit le
## même texel (une projection Boîte répète l'image : ce qu'on y peint se répète).
## ⚠ **ON PEINT LÀ OÙ LE RENDU LIT** : le point touché est ramené à l'UV que le rendu donne à ce point
## (`MaillageEdite.uv_au_point`, la même règle que `vers_array_mesh_de`), puis au texel, image REPLIÉE comme la
## répétition de la texture.

## chemin → {"image": Image, "texture": ImageTexture, "date": int, "sale": bool}
static var _toiles := {}

## La taille d'une toile neuve.
const TAILLE := 1024


## La texture d'un chemin d'image, PARTAGÉE (null si le fichier n'existe pas et qu'aucune toile ne le porte).
## Un fichier changé sur le disque depuis sa lecture est relu, sauf si on y a peint sans l'avoir écrit.
static func texture_de(chemin: String) -> Texture2D:
	var t := toile(chemin)
	return t.get("texture", null)


static func toile(chemin: String) -> Dictionary:
	if chemin == "":
		return {}
	if _toiles.has(chemin):
		var t: Dictionary = _toiles[chemin]
		if t["sale"] or not FileAccess.file_exists(chemin) or FileAccess.get_modified_time(chemin) == t["date"]:
			return t
	if not FileAccess.file_exists(chemin):
		return {}
	var img := Image.load_from_file(chemin)
	if img == null or img.is_empty():
		return {}
	return _inscrire(chemin, img, FileAccess.get_modified_time(chemin))


static func _inscrire(chemin: String, img: Image, date: int) -> Dictionary:
	if img.is_compressed():
		img.decompress()
	if img.has_mipmaps():
		img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var t := {"image": img, "texture": ImageTexture.create_from_image(img), "date": date, "sale": false}
	_toiles[chemin] = t
	return t


## Une toile neuve, unie, écrite tout de suite (le matériau peut la citer).
static func nouvelle_toile(chemin: String, couleur: Color, taille := TAILLE) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(chemin.get_base_dir())
	var img := Image.create(taille, taille, false, Image.FORMAT_RGBA8)
	img.fill(couleur)
	img.save_png(chemin)
	return _inscrire(chemin, img, FileAccess.get_modified_time(chemin))


## L'UV ramené au texel : l'image est REPLIÉE, comme la répétition de la texture.
static func vers_pixel(img: Image, uv: Vector2) -> Vector2:
	return Vector2(fposmod(uv.x, 1.0) * img.get_width(), fposmod(uv.y, 1.0) * img.get_height())


## Le poids du pinceau à la distance relative t (0 au centre, 1 au bord) : plein jusqu'à la dureté, puis une
## descente douce jusqu'au bord.
static func poids(t: float, durete: float) -> float:
	if t >= 1.0:
		return 0.0
	if t <= durete:
		return 1.0
	return 1.0 - smoothstep(durete, 1.0, t)


## Un tampon, centré sur le texel `centre` (en pixels, non replié), de `rayon` pixels. Les pixels hors de l'image
## sont REPLIÉS. Rend le rectangle touché (l'image entière sur un axe que le tampon a franchi).
static func tamponner(img: Image, centre: Vector2, rayon: float, couleur: Color, durete: float, opacite: float) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var r := maxf(0.5, rayon)
	var x0 := floori(centre.x - r)
	var x1 := ceili(centre.x + r)
	var y0 := floori(centre.y - r)
	var y1 := ceili(centre.y + r)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(centre)
			var a := poids(d / r, durete) * opacite * couleur.a
			if a <= 0.0:
				continue
			var px := posmod(x, w)
			var py := posmod(y, h)
			var ancien := img.get_pixel(px, py)
			var neuf := ancien.lerp(Color(couleur.r, couleur.g, couleur.b, 1.0), a)
			neuf.a = maxf(ancien.a, a)
			img.set_pixel(px, py, neuf)
	var rx := Vector2i(x0, x1 + 1)
	var ry := Vector2i(y0, y1 + 1)
	if x0 < 0 or x1 >= w:
		rx = Vector2i(0, w)
	if y0 < 0 or y1 >= h:
		ry = Vector2i(0, h)
	return Rect2i(rx.x, ry.x, rx.y - rx.x, ry.y - ry.x).intersection(Rect2i(0, 0, w, h))


## Un trait de `de` à `a` (en pixels non repliés, sur une même face) : des tampons espacés d'un tiers de rayon.
## Rend le rectangle touché.
static func trait_(img: Image, de: Vector2, a: Vector2, rayon: float, couleur: Color, durete: float,
		opacite: float) -> Rect2i:
	var pas := maxf(1.0, rayon * 0.33)
	var n := maxi(1, ceili(de.distance_to(a) / pas))
	var zone := Rect2i()
	for i in range(1, n + 1):
		var r := tamponner(img, de.lerp(a, float(i) / n), rayon, couleur, durete, opacite)
		zone = r if zone.size == Vector2i.ZERO else zone.merge(r)
	return zone


## L'EMPREINTE DU TAMPON SUR LA FACE — le curseur du pinceau (Jordan, 1er octobre 2026 : « voir la taille du
## pinceau »). Les `n` points, dans le repère de la TUILE et dans le plan de la face `f` au point `p`, où le tampon
## de `rayon` pixels s'arrête sur une toile de `taille` pixels.
## ⚠ CE N'EST PAS UN CERCLE : le rayon est en pixels de la TOILE, et l'UV d'une face n'a ni la même échelle dans
## les deux sens (un îlot déplié peut être étiré) ni la même d'une face à l'autre. On prend l'application LINÉAIRE
## que la face fait de son plan vers la toile (`uv_au_point`, la règle du rendu, en deux différences), et l'on
## suit, dans chaque direction du plan, la distance qui y vaut `rayon` pixels : une ellipse, exacte sur un
## triangle. Vide si la face ne se peint pas (pas de matériau) ou si son UV est dégénéré.
static func empreinte(tuile: RefCounted, f: int, p: Vector3, rayon: float, taille: Vector2, n := 48) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var uv0: Vector2 = tuile.uv_au_point(f, p)
	if not uv0.is_finite():
		return pts
	var nrm: Vector3 = tuile.normale(f)
	if nrm.length_squared() < 1e-12:
		return pts
	var e1 := nrm.cross(Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT).normalized()
	var e2 := nrm.cross(e1).normalized()
	const H := 0.01
	var j1: Vector2 = (tuile.uv_au_point(f, p + e1 * H) - uv0) / H * taille
	var j2: Vector2 = (tuile.uv_au_point(f, p + e2 * H) - uv0) / H * taille
	if absf(j1.cross(j2)) < 1e-9:
		return pts
	for i in n:
		var a := TAU * i / n
		var d := e1 * cos(a) + e2 * sin(a)
		var px := (j1 * cos(a) + j2 * sin(a)).length()
		pts.append(p + d * (maxf(0.5, rayon) / px))
	return pts


## Le trait ou le tampon est fini : la texture partagée montre l'image, et la toile est à écrire.
static func montrer(chemin: String) -> void:
	if not _toiles.has(chemin):
		return
	var t: Dictionary = _toiles[chemin]
	(t["texture"] as ImageTexture).update(t["image"])
	t["sale"] = true


## La pipette : la couleur au point.
static func couleur_au(chemin: String, uv: Vector2) -> Color:
	var t := toile(chemin)
	if t.is_empty():
		return Color.WHITE
	var img: Image = t["image"]
	var p := vers_pixel(img, uv)
	return img.get_pixel(clampi(int(p.x), 0, img.get_width() - 1), clampi(int(p.y), 0, img.get_height() - 1))


## L'annulation : une région de l'image remise (avant ou après un trait).
static func poser_region(chemin: String, region: Image, position: Vector2i) -> void:
	var t := toile(chemin)
	if t.is_empty():
		return
	(t["image"] as Image).blit_rect(region, Rect2i(Vector2i.ZERO, region.get_size()), position)
	montrer(chemin)


## Écrit les toiles où l'on a peint. Rend les chemins écrits (ou la raison d'un échec, préfixée « ! »).
static func enregistrer() -> Array:
	var sortie: Array = []
	for chemin in _toiles:
		var t: Dictionary = _toiles[chemin]
		if not t["sale"]:
			continue
		var err := (t["image"] as Image).save_png(chemin)
		if err != OK:
			sortie.append("!%s (%d)" % [chemin, err])
			continue
		t["sale"] = false
		t["date"] = FileAccess.get_modified_time(chemin)
		sortie.append(chemin)
	return sortie


static func a_ecrire() -> bool:
	for chemin in _toiles:
		if _toiles[chemin]["sale"]:
			return true
	return false


## Oublie toutes les toiles (les tests partent d'un état propre).
static func oublier() -> void:
	_toiles.clear()
