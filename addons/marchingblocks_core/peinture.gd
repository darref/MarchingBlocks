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

## ⚠ **LES CALQUES — DÉCIDÉS ET ÉCRITS (Jordan, 2 octobre 2026 : « go pour la gomme et les calques »)**. Une toile est
## une PILE : le FOND (la toile telle qu'elle était avant toute peinture — unie de la couleur du matériau, ou l'image
## lue), puis des calques du bas vers le haut ({nom, image, opacite, visible}). Le pinceau et la gomme n'écrivent que
## dans le calque ACTIF ; « image » est la COMPOSITION, la seule que le rendu lit et que le .glb emporte — le format
## et les greffons ne voient jamais de calques. La gomme rend un calque transparent : sur le calque du bas, elle
## fait donc revenir le fond (la toile d'avant la peinture).
## ⚠ Les calques s'écrivent à côté de l'image (`<image>.layers/`), avec l'empreinte MD5 de la composition écrite :
## une image retouchée hors de l'appli (un autre logiciel) ne correspond plus — ses calques sont MIS DE CÔTÉ, l'image
## devient le calque unique, et on le dit (`calques_ecartes`). On ne recompose jamais par-dessus le travail d'un autre.

## chemin → {"image": Image (la composition), "texture": ImageTexture, "date": int, "sale": bool,
##           "fond": Image, "calques": Array[{nom, image, opacite, visible}], "actif": int, "calques_ecartes": bool}
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
	var t := {"image": img, "texture": ImageTexture.create_from_image(img), "date": date, "sale": false,
		"fond": img.duplicate(), "calques": [_calque("Base", img.duplicate())], "actif": 0, "calques_ecartes": false}
	_toiles[chemin] = t
	_lire_les_calques(chemin, t)
	return t


static func _calque(nom: String, img: Image, opacite := 1.0, visible := true) -> Dictionary:
	return {"nom": nom, "image": img, "opacite": opacite, "visible": visible}


## Le dossier des calques d'une image.
static func dossier_des_calques(chemin: String) -> String:
	return chemin.get_basename() + ".layers"


## Relit la pile écrite à côté de l'image, si elle correspond à la composition sur le disque.
static func _lire_les_calques(chemin: String, t: Dictionary) -> void:
	var dossier := dossier_des_calques(chemin)
	var desc := dossier.path_join("layers.json")
	if not FileAccess.file_exists(desc):
		return
	var lu: Variant = JSON.parse_string(FileAccess.get_file_as_string(desc))
	if not lu is Dictionary or str((lu as Dictionary).get("md5", "")) != FileAccess.get_md5(chemin):
		t["calques_ecartes"] = true
		return
	var taille: Vector2i = (t["image"] as Image).get_size()
	var fond := _lire_png(dossier.path_join("fond.png"), taille)
	var calques: Array = []
	for c in (lu as Dictionary).get("calques", []):
		var img := _lire_png(dossier.path_join(str((c as Dictionary).get("fichier", ""))), taille)
		if img == null:
			t["calques_ecartes"] = true
			return
		calques.append(_calque(str(c.get("nom", "Layer")), img, clampf(float(c.get("opacite", 1.0)), 0.0, 1.0),
			bool(c.get("visible", true))))
	if fond == null or calques.is_empty():
		t["calques_ecartes"] = true
		return
	t["fond"] = fond
	t["calques"] = calques
	t["actif"] = clampi(int((lu as Dictionary).get("actif", 0)), 0, calques.size() - 1)


static func _lire_png(chemin: String, taille: Vector2i) -> Image:
	if not FileAccess.file_exists(chemin):
		return null
	var img := Image.load_from_file(chemin)
	if img == null or img.is_empty() or img.get_size() != taille:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


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
## Peindre, c'est poser la couleur PAR-DESSUS le pixel (alpha droit : un pixel transparent prend la couleur pure,
## à l'alpha du pinceau ; un pixel opaque se mélange comme avant). `gomme` : l'alpha du pixel baisse d'autant,
## sa couleur ne change pas.
static func tamponner(img: Image, centre: Vector2, rayon: float, couleur: Color, durete: float, opacite: float,
		gomme := false) -> Rect2i:
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
			var neuf := ancien
			if gomme:
				neuf.a = ancien.a * (1.0 - a)
			else:
				neuf.a = a + ancien.a * (1.0 - a)
				var c := Color(couleur.r, couleur.g, couleur.b) * a + Color(ancien.r, ancien.g, ancien.b) * (ancien.a * (1.0 - a))
				neuf.r = c.r / neuf.a
				neuf.g = c.g / neuf.a
				neuf.b = c.b / neuf.a
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
		opacite: float, gomme := false) -> Rect2i:
	var pas := maxf(1.0, rayon * 0.33)
	var n := maxi(1, ceili(de.distance_to(a) / pas))
	var zone := Rect2i()
	for i in range(1, n + 1):
		var r := tamponner(img, de.lerp(a, float(i) / n), rayon, couleur, durete, opacite, gomme)
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


## L'annulation : une région d'un CALQUE remise (avant ou après un trait), puis la composition refaite là.
## `calque` est l'image du calque (pas son rang : un calque déplacé reste lui-même) ; null = le calque actif.
static func poser_region(chemin: String, region: Image, position: Vector2i, calque: Image = null) -> void:
	var t := toile(chemin)
	if t.is_empty():
		return
	var cible: Image = calque if calque != null else calque_actif(chemin)
	cible.blit_rect(region, Rect2i(Vector2i.ZERO, region.get_size()), position)
	composer(chemin, Rect2i(position, region.get_size()))


## L'image du calque actif (celle où le pinceau et la gomme écrivent).
static func calque_actif(chemin: String) -> Image:
	var t := toile(chemin)
	if t.is_empty():
		return null
	return (t["calques"][t["actif"]] as Dictionary)["image"]


## Refait la composition dans `zone` (toute l'image si vide) : le fond, puis chaque calque visible PAR-DESSUS, à son
## opacité. Puis la texture partagée la montre, et la toile est à écrire.
static func composer(chemin: String, zone := Rect2i()) -> void:
	var t := toile(chemin)
	if t.is_empty():
		return
	var img: Image = t["image"]
	var tout := Rect2i(Vector2i.ZERO, img.get_size())
	var r := tout if zone.size == Vector2i.ZERO else zone.intersection(tout)
	if r.size.x <= 0 or r.size.y <= 0:
		return
	img.blit_rect(t["fond"], r, r.position)
	for c in t["calques"]:
		if not c["visible"] or float(c["opacite"]) <= 0.0:
			continue
		if float(c["opacite"]) >= 1.0:
			img.blend_rect(c["image"], r, r.position)
		else:
			img.blend_rect(_attenue(c["image"], r, float(c["opacite"])), Rect2i(Vector2i.ZERO, r.size), r.position)
	montrer(chemin)


## La région `r` d'un calque, son alpha multiplié par `opacite`.
static func _attenue(src: Image, r: Rect2i, opacite: float) -> Image:
	var d := src.get_region(r).get_data()
	for i in range(3, d.size(), 4):
		d[i] = int(d[i] * opacite + 0.5)
	return Image.create_from_data(r.size.x, r.size.y, false, Image.FORMAT_RGBA8, d)


## L'ÉTAT DE LA PILE (pour l'annulation des gestes sur les calques) : l'ordre, les noms, opacités, visibilités et le
## calque actif. Les IMAGES sont des références, pas des copies : leurs pixels ne changent que par un trait, qui a sa
## propre annulation par région — un calque supprimé puis rendu est le MÊME objet.
static func etat(chemin: String) -> Dictionary:
	var t := toile(chemin)
	if t.is_empty():
		return {}
	var calques: Array = []
	for c in t["calques"]:
		calques.append((c as Dictionary).duplicate())
	return {"calques": calques, "actif": t["actif"]}


static func poser_etat(chemin: String, e: Dictionary) -> void:
	var t := toile(chemin)
	if t.is_empty() or e.is_empty():
		return
	var calques: Array = []
	for c in e["calques"]:
		calques.append((c as Dictionary).duplicate())
	t["calques"] = calques
	t["actif"] = clampi(int(e["actif"]), 0, calques.size() - 1)
	composer(chemin)


## Un calque neuf, TRANSPARENT, posé juste au-dessus de l'actif, qui devient l'actif. Rend son rang.
static func nouveau_calque(chemin: String, nom := "") -> int:
	var t := toile(chemin)
	if t.is_empty():
		return -1
	var taille: Vector2i = (t["image"] as Image).get_size()
	var img := Image.create(taille.x, taille.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rang: int = int(t["actif"]) + 1
	(t["calques"] as Array).insert(rang, _calque(nom if nom != "" else "Layer %d" % (t["calques"] as Array).size(), img))
	t["actif"] = rang
	composer(chemin)
	return rang


## Retire un calque (jamais le dernier qui reste). L'actif devient celui d'en dessous.
static func supprimer_calque(chemin: String, rang: int) -> bool:
	var t := toile(chemin)
	if t.is_empty() or (t["calques"] as Array).size() <= 1 or rang < 0 or rang >= (t["calques"] as Array).size():
		return false
	(t["calques"] as Array).remove_at(rang)
	t["actif"] = clampi(rang - 1, 0, (t["calques"] as Array).size() - 1)
	composer(chemin)
	return true


## Monte (+1) ou descend (−1) un calque dans la pile ; l'actif le suit.
static func deplacer_calque(chemin: String, rang: int, sens: int) -> bool:
	var t := toile(chemin)
	var cal: Array = t.get("calques", [])
	var vers := rang + sens
	if rang < 0 or rang >= cal.size() or vers < 0 or vers >= cal.size():
		return false
	var c: Variant = cal[rang]
	cal[rang] = cal[vers]
	cal[vers] = c
	if int(t["actif"]) == rang:
		t["actif"] = vers
	elif int(t["actif"]) == vers:
		t["actif"] = rang
	composer(chemin)
	return true


## Règle une propriété d'un calque (« nom », « opacite », « visible ») ; la composition suit.
static func regler_calque(chemin: String, rang: int, cle: String, valeur: Variant) -> void:
	var t := toile(chemin)
	if t.is_empty() or rang < 0 or rang >= (t["calques"] as Array).size():
		return
	var c: Dictionary = t["calques"][rang]
	match cle:
		"nom":
			c["nom"] = str(valeur)
			t["sale"] = true
		"opacite":
			c["opacite"] = clampf(float(valeur), 0.0, 1.0)
			composer(chemin)
		"visible":
			c["visible"] = bool(valeur)
			composer(chemin)


static func choisir_calque(chemin: String, rang: int) -> void:
	var t := toile(chemin)
	if t.is_empty() or rang < 0 or rang >= (t["calques"] as Array).size():
		return
	t["actif"] = rang


## Écrit les toiles où l'on a peint. Rend les chemins écrits (ou la raison d'un échec, préfixée « ! »).
static func enregistrer() -> Array:
	var sortie: Array = []
	for chemin in _toiles:
		var t: Dictionary = _toiles[chemin]
		if not t["sale"]:
			continue
		var err := (t["image"] as Image).save_png(chemin)
		if err == OK:
			err = _ecrire_les_calques(chemin, t)
		if err != OK:
			sortie.append("!%s (%d)" % [chemin, err])
			continue
		t["sale"] = false
		t["calques_ecartes"] = false
		t["date"] = FileAccess.get_modified_time(chemin)
		sortie.append(chemin)
	return sortie


## La pile, à côté de l'image : le fond, chaque calque, et `layers.json` (noms, opacités, visibilités, l'actif, et le
## MD5 de la composition qu'on vient d'écrire). Les PNG d'une pile plus haute qui ne servent plus sont retirés.
static func _ecrire_les_calques(chemin: String, t: Dictionary) -> int:
	var dossier := dossier_des_calques(chemin)
	DirAccess.make_dir_recursive_absolute(dossier)
	var err := (t["fond"] as Image).save_png(dossier.path_join("fond.png"))
	if err != OK:
		return err
	var desc: Array = []
	for i in (t["calques"] as Array).size():
		var c: Dictionary = t["calques"][i]
		var fichier := "layer_%d.png" % i
		err = (c["image"] as Image).save_png(dossier.path_join(fichier))
		if err != OK:
			return err
		desc.append({"nom": c["nom"], "opacite": c["opacite"], "visible": c["visible"], "fichier": fichier})
	for nom in DirAccess.get_files_at(dossier):
		if nom.begins_with("layer_") and nom.ends_with(".png") and int(nom.trim_prefix("layer_").trim_suffix(".png")) >= desc.size():
			DirAccess.remove_absolute(dossier.path_join(nom))
	var f := FileAccess.open(dossier.path_join("layers.json"), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"md5": FileAccess.get_md5(chemin), "actif": t["actif"], "calques": desc}, "\t"))
	f.close()
	return OK


static func a_ecrire() -> bool:
	for chemin in _toiles:
		if _toiles[chemin]["sale"]:
			return true
	return false


## Oublie toutes les toiles (les tests partent d'un état propre).
static func oublier() -> void:
	_toiles.clear()
