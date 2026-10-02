extends RefCounted
## LES CARTES PBR DÉDUITES — DÉCIDÉ (Jordan, 2 octobre 2026 : « un PBR complet, mais éditer chaque png n'est pas
## propre à la main : l'équivalent d'un Materialize, qui génère les autres cartes à partir de l'albedo »).
##
## ⚠ **LES CARTES NE SE PEIGNENT PAS, ELLES SE DÉDUISENT** (§6, on déduit plutôt qu'on déclare) : on enregistre
## l'albedo (la pile de calques de `peinture.gd`) et une poignée de RÉGLAGES ; la hauteur, la normale, l'occlusion et
## la rugosité en sortent, à chaque fois. Retoucher l'albedo met tout à jour, et aucune carte ne peut diverger de sa
## source. Ce module est PUR : des images et des nombres, aucun nœud, aucun fichier — il tourne sur un autre fil.
##
## ⚠ **LES ALGORITHMES SONT ÉCRITS ICI, AUCUN N'EST REPRIS DE MATERIALIZE** (même règle que pour Blender, §5) : ce
## sont des techniques classiques — passe-bande sur plusieurs échelles, Sobel, cavité.
##
## ⚠ **LE MÉTAL N'EST JAMAIS INVENTÉ** : le canal bleu de l'ORM est BLANC, et le facteur du matériau (son curseur
## « Metal ») reste seul maître — un métal deviné a déjà fait tomber des parois marron au noir (§3, l'éclairage).
##
## ⚠ **DEUX FAÇONS DE LIRE LES BORDS** : une image qui se RÉPÈTE (projection boîte ou plane) se lit en boucle — sinon
## la normale ferait une arête à chaque répétition, donc à chaque joint de tuile ; une image DÉPLIÉE (projection UV)
## a des ÎLOTS : on DILATE d'abord chaque îlot sur le fond (`dilater`), sinon le flou et la pente lisent le fond
## autour de l'îlot et dessinent un bourrelet sur son contour — c'est-à-dire sur les arêtes et les plans de coupe.

## Les réglages par défaut. `fin`, `moyen`, `large` pèsent les trois bandes de la hauteur ; `contraste` l'étire ;
## `inverser` fait des sombres les hauts ; `normale` est la force de la pente ; `occlusion` celle de la cavité ;
## `rugosite` la base et `variation` ce que la hauteur y ajoute (les creux plus rugueux que les bosses).
const DEFAUTS := {"fin": 1.0, "moyen": 0.6, "large": 0.3, "contraste": 1.5, "inverser": false,
	"normale": 4.0, "occlusion": 1.0, "rugosite": 0.8, "variation": 0.3}

## Les bandes : la hauteur est la somme pondérée de L − B(÷4), B(÷4) − B(÷16), B(÷16) − B(÷64), où B(÷k) est l'image
## réduite k fois puis remontée (un flou large de ~k pixels).
const NIVEAUX := [2, 4, 6]   # réductions de moitié : ÷4, ÷16, ÷64


## Les réglages complets (les absents prennent leur défaut).
static func reglages(r: Variant) -> Dictionary:
	var d := DEFAUTS.duplicate()
	if r is Dictionary:
		for k in r:
			if d.has(k):
				d[k] = r[k]
	return d


## LE GÉNÉRATEUR : l'albedo (RGBA8) → {"hauteur": Image L8, "normale": Image RGB8, "orm": Image RGB8}.
## `boucle` : l'image se répète (bords lus en boucle). `masque` (facultatif, L8, même taille) : les texels
## qu'utilisent les îlots — ailleurs l'albedo est d'abord dilaté depuis les îlots.
static func generer(albedo: Image, r: Variant = null, boucle := true, masque: Image = null) -> Dictionary:
	var g := reglages(r)
	var src := albedo.duplicate() as Image
	if src.is_compressed():
		src.decompress()
	src.clear_mipmaps()
	src.convert(Image.FORMAT_RGBA8)
	if masque != null and masque.get_size() == src.get_size():
		src = dilater(src, masque)
	var w := src.get_width()
	var h := src.get_height()
	var n := w * h
	# 1. La luminance.
	var px := src.get_data()
	var lum := PackedFloat32Array()
	lum.resize(n)
	for i in n:
		var j := i * 4
		lum[i] = (px[j] * 0.299 + px[j + 1] * 0.587 + px[j + 2] * 0.114) / 255.0
	# 2. La hauteur : trois bandes.
	var flous := flous_de(lum, w, h, boucle)
	var b1: PackedFloat32Array = flous[0]
	var b2: PackedFloat32Array = flous[1]
	var b3: PackedFloat32Array = flous[2]
	var wf := float(g["fin"])
	var wm := float(g["moyen"])
	var wl := float(g["large"])
	var k := float(g["contraste"]) * (-1.0 if bool(g["inverser"]) else 1.0)
	var haut := PackedFloat32Array()
	haut.resize(n)
	for i in n:
		haut[i] = clampf(0.5 + k * (wf * (lum[i] - b1[i]) + wm * (b1[i] - b2[i]) + wl * (b2[i] - b3[i])), 0.0, 1.0)
	return depuis_la_hauteur(haut, w, h, g, boucle)


## La normale, l'ORM (et la hauteur en image) depuis un champ de hauteur dans [0, 1].
static func depuis_la_hauteur(haut: PackedFloat32Array, w: int, h: int, r: Variant = null, boucle := true) -> Dictionary:
	var g := reglages(r)
	var n := w * h
	var cav := flous_de(haut, w, h, boucle)
	var force := float(g["normale"])
	var occ := float(g["occlusion"])
	var base := float(g["rugosite"])
	var variation := float(g["variation"])
	var nrm := PackedByteArray()
	nrm.resize(n * 3)
	var orm := PackedByteArray()
	orm.resize(n * 3)
	var hb := PackedByteArray()
	hb.resize(n)
	var c1: PackedFloat32Array = cav[0]
	var c2: PackedFloat32Array = cav[1]
	for y in h:
		var ym := y - 1
		var yp := y + 1
		if boucle:
			ym = posmod(ym, h)
			yp = posmod(yp, h)
		else:
			ym = maxi(ym, 0)
			yp = mini(yp, h - 1)
		for x in w:
			var xm := x - 1
			var xp := x + 1
			if boucle:
				xm = posmod(xm, w)
				xp = posmod(xp, w)
			else:
				xm = maxi(xm, 0)
				xp = mini(xp, w - 1)
			var i := y * w + x
			# Sobel, en pixels : gx vers la droite, gy vers le BAS de l'image.
			var a00 := haut[ym * w + xm]
			var a10 := haut[ym * w + x]
			var a20 := haut[ym * w + xp]
			var a01 := haut[y * w + xm]
			var a21 := haut[y * w + xp]
			var a02 := haut[yp * w + xm]
			var a12 := haut[yp * w + x]
			var a22 := haut[yp * w + xp]
			var gx := ((a20 + 2.0 * a21 + a22) - (a00 + 2.0 * a01 + a02)) * 0.125
			var gy := ((a02 + 2.0 * a12 + a22) - (a00 + 2.0 * a10 + a20)) * 0.125
			# ⚠ LA CONVENTION DU glTF ET DE GODOT (« OpenGL ») : +X à droite, +Y vers le HAUT de l'image. La pente
			# vers le bas de l'image entre donc dans Y avec son signe : n = (−∂h/∂x, +∂h/∂y_bas, 1).
			var v := Vector3(-gx * force, gy * force, 1.0).normalized()
			nrm[i * 3] = int(clampf(127.5 + v.x * 127.5, 0.0, 255.0))
			nrm[i * 3 + 1] = int(clampf(127.5 + v.y * 127.5, 0.0, 255.0))
			nrm[i * 3 + 2] = int(clampf(127.5 + v.z * 127.5, 0.0, 255.0))
			var hi := haut[i]
			var creux := maxf(0.0, c1[i] - hi) + 0.5 * maxf(0.0, c2[i] - hi)
			orm[i * 3] = int(clampf(1.0 - occ * creux * 2.0, 0.0, 1.0) * 255.0 + 0.5)
			orm[i * 3 + 1] = int(clampf(base + variation * (0.5 - hi) * 2.0, 0.02, 1.0) * 255.0 + 0.5)
			orm[i * 3 + 2] = 255
			hb[i] = int(hi * 255.0 + 0.5)
	return {"hauteur": Image.create_from_data(w, h, false, Image.FORMAT_L8, hb),
		"normale": Image.create_from_data(w, h, false, Image.FORMAT_RGB8, nrm),
		"orm": Image.create_from_data(w, h, false, Image.FORMAT_RGB8, orm)}


## Les trois flous (÷4, ÷16, ÷64) d'un champ, mêmes dimensions. Réduction par MOITIÉS successives (une moitié exacte
## en bilinéaire moyenne 2 × 2 : un vrai filtre, là où une réduction d'un coup ne lirait que quatre texels), puis
## remontée cubique. Le champ est d'abord ENTOURÉ d'une marge — en boucle ou en prolongeant le bord —, sinon le flou
## lirait le bord de l'image comme un mur.
static func flous_de(champ: PackedFloat32Array, w: int, h: int, boucle: bool) -> Array:
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RF, champ.to_byte_array())
	var marge := maxi(8, maxi(w, h) / 8)
	var pas := 1 << int(NIVEAUX[NIVEAUX.size() - 1])
	var pw := w + 2 * marge
	var ph := h + 2 * marge
	pw += (pas - pw % pas) % pas
	ph += (pas - ph % pas) % pas
	var grand := Image.create(pw, ph, false, Image.FORMAT_RF)
	if boucle:
		# Le motif recopié tout autour (le blit coupe ce qui dépasse).
		for oy in range(-((marge + h - 1) / h) - 1, (ph - marge) / h + 2):
			for ox in range(-((marge + w - 1) / w) - 1, (pw - marge) / w + 2):
				grand.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(marge + ox * w, marge + oy * h))
	else:
		_prolonger(grand, img, marge, w, h)
	var sortie: Array = []
	var courant := grand
	var fait := 0
	for niveau in NIVEAUX:
		while fait < int(niveau):
			courant = courant.duplicate() as Image
			courant.resize(maxi(1, courant.get_width() / 2), maxi(1, courant.get_height() / 2), Image.INTERPOLATE_BILINEAR)
			fait += 1
		# ⚠ REMONTÉE PAR DOUBLEMENTS BILINÉAIRES, PAS D'UN COUP EN CUBIQUE : la cubique de Godot, depuis une image de
		# 2 × 2, DÉPASSE (une image unie à 0,32 en ressortait avec des texels à 0,348 — mesuré) ; une suite de
		# doublements bilinéaires est un filtre en tente, sans dépassement.
		var remonte := courant.duplicate() as Image
		while remonte.get_width() < pw:
			remonte.resize(mini(pw, remonte.get_width() * 2), mini(ph, remonte.get_height() * 2), Image.INTERPOLATE_BILINEAR)
		sortie.append(remonte.get_region(Rect2i(marge, marge, w, h)).get_data().to_float32_array())
	return sortie


## La marge d'une image non répétée : chaque texel de la marge prend le texel du bord le plus proche.
static func _prolonger(grand: Image, img: Image, marge: int, w: int, h: int) -> void:
	var pw := grand.get_width()
	var ph := grand.get_height()
	grand.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(marge, marge))
	# Les bandes gauche et droite : la colonne du bord, recopiée.
	for x in range(0, marge):
		grand.blit_rect(img, Rect2i(0, 0, 1, h), Vector2i(x, marge))
	for x in range(marge + w, pw):
		grand.blit_rect(img, Rect2i(w - 1, 0, 1, h), Vector2i(x, marge))
	# Les bandes haute et basse : la rangée du bord de la bande déjà remplie.
	for y in range(0, marge):
		grand.blit_rect(grand, Rect2i(0, marge, pw, 1), Vector2i(0, y))
	for y in range(marge + h, ph):
		grand.blit_rect(grand, Rect2i(0, marge + h - 1, pw, 1), Vector2i(0, y))


## LA DILATATION DES ÎLOTS (« push-pull ») : hors du masque, chaque texel prend la couleur des îlots les plus
## proches, de plus en plus floue en s'éloignant. Dans le masque, l'image est INTACTE (au bit près).
static func dilater(img: Image, masque: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var m := masque.duplicate() as Image
	m.convert(Image.FORMAT_L8)
	var md := m.get_data()
	var src := img.get_data()
	# Niveau 0 : couleurs PRÉMULTIPLIÉES par la couverture, en flottants (RGBA = r·a, g·a, b·a, a).
	var niveaux: Array = []
	var f := PackedFloat32Array()
	f.resize(w * h * 4)
	for i in w * h:
		var a := md[i] / 255.0
		f[i * 4] = src[i * 4] / 255.0 * a
		f[i * 4 + 1] = src[i * 4 + 1] / 255.0 * a
		f[i * 4 + 2] = src[i * 4 + 2] / 255.0 * a
		f[i * 4 + 3] = a
	var courant := Image.create_from_data(w, h, false, Image.FORMAT_RGBAF, f.to_byte_array())
	niveaux.append(courant)
	while courant.get_width() > 1 or courant.get_height() > 1:
		courant = courant.duplicate() as Image
		courant.resize(maxi(1, courant.get_width() / 2), maxi(1, courant.get_height() / 2), Image.INTERPOLATE_BILINEAR)
		niveaux.append(courant)
	# Remontée : à chaque niveau, ce qui manque (1 − a) est comblé par le niveau du dessous, remonté.
	var plein: Image = niveaux[niveaux.size() - 1]
	for k in range(niveaux.size() - 2, -1, -1):
		var ici: Image = niveaux[k]
		var bas := plein.duplicate() as Image
		bas.resize(ici.get_width(), ici.get_height(), Image.INTERPOLATE_BILINEAR)
		var a := ici.get_data().to_float32_array()
		var b := bas.get_data().to_float32_array()
		for i in range(0, a.size(), 4):
			var reste := 1.0 - a[i + 3]
			if reste <= 0.0:
				continue
			a[i] += b[i] * reste
			a[i + 1] += b[i + 1] * reste
			a[i + 2] += b[i + 2] * reste
			a[i + 3] += b[i + 3] * reste
		plein = Image.create_from_data(ici.get_width(), ici.get_height(), false, Image.FORMAT_RGBAF, a.to_byte_array())
	var p := plein.get_data().to_float32_array()
	var sortie := src.duplicate()
	for i in w * h:
		if md[i] >= 255:
			continue   # dans l'îlot : intact
		var a := p[i * 4 + 3]
		if a <= 0.0:
			continue
		var cov := md[i] / 255.0
		for c in 3:
			var dilate := p[i * 4 + c] / a
			sortie[i * 4 + c] = int(clampf(lerpf(dilate, src[i * 4 + c] / 255.0, cov), 0.0, 1.0) * 255.0 + 0.5)
		sortie[i * 4 + 3] = 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, sortie)


## LE MASQUE DES ÎLOTS : `triangles` = UV à plat, trois par triangle (dans [0, 1]) ; un texel est couvert si son
## centre est dans un triangle — élargi d'un texel, pour que le filtrage au bord d'un îlot lise encore de l'îlot.
static func masque_des_triangles(triangles: PackedVector2Array, taille: Vector2i) -> Image:
	var w := taille.x
	var h := taille.y
	var d := PackedByteArray()
	d.resize(w * h)
	for t in range(0, triangles.size() - 2, 3):
		var a := triangles[t] * Vector2(w, h)
		var b := triangles[t + 1] * Vector2(w, h)
		var c := triangles[t + 2] * Vector2(w, h)
		var x0 := clampi(floori(minf(a.x, minf(b.x, c.x))) - 1, 0, w - 1)
		var x1 := clampi(ceili(maxf(a.x, maxf(b.x, c.x))) + 1, 0, w - 1)
		var y0 := clampi(floori(minf(a.y, minf(b.y, c.y))) - 1, 0, h - 1)
		var y1 := clampi(ceili(maxf(a.y, maxf(b.y, c.y))) + 1, 0, h - 1)
		var aire := (b - a).cross(c - a)
		if absf(aire) < 1e-9:
			continue
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var p := Vector2(x + 0.5, y + 0.5)
				if _dans(p, a, b, c, aire) or _distance_au_triangle(p, a, b, c) <= 1.0:
					d[y * w + x] = 255
	return Image.create_from_data(w, h, false, Image.FORMAT_L8, d)


static func _dans(p: Vector2, a: Vector2, b: Vector2, c: Vector2, aire: float) -> bool:
	var s := signf(aire)
	return (b - a).cross(p - a) * s >= 0.0 and (c - b).cross(p - b) * s >= 0.0 and (a - c).cross(p - c) * s >= 0.0


static func _distance_au_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	return minf(_distance_au_segment(p, a, b), minf(_distance_au_segment(p, b, c), _distance_au_segment(p, c, a)))


static func _distance_au_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l := ab.length_squared()
	var t := 0.0 if l <= 0.0 else clampf((p - a).dot(ab) / l, 0.0, 1.0)
	return p.distance_to(a + ab * t)
