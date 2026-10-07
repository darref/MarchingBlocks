@tool
extends RefCounted
## LES TEXTURES ANIMÉES — DÉCIDÉ (Jordan, 6 octobre 2026 : « un atelier d'animation complet avec possibilité de faire
## défilement, mais aussi frames (texture vidéo), pour du sci-fi ou du naturel, pour tout ; animation pour chaque canal
## PBR, dont l'émission fait maintenant partie ; une UI d'atelier où l'on ne crée que ce qu'on utilise, avec des + −).
## Ses réponses : les images viennent de SÉQUENCES ou de PLANCHES (pas de vidéo) ; on PEINT image par image ; un albedo
## animé par images n'a PAS de cartes déduites.
##
## Le cœur, sans écran. Un matériau du témoin porte (ou non) une clé « animation » :
##
##   {canal: {genre: réglages}}     canal ∈ CANAUX, genre ∈ GENRES
##     "defilement" : {"u", "v" (répétitions de l'image par seconde), "synchro": bool}
##     "images"     : {"images": [chemins PNG, dans l'ordre], "ips" (images par seconde), "aller_retour": bool,
##                     "synchro": bool}
##     "pulsation"  : {"frequence" (Hz), "mini" (la force au creux, 0 à 1), "synchro": bool}   — l'émission seule
##
## ⚠ **UN SHADER NE VOYAGE PAS (§4)** : le matériau Godot du témoin reste un `StandardMaterial3D` (`materiau_godot`),
## l'image 0 de chaque canal animé posée dans son emplacement — c'est lui qu'un moteur sans notre shader montre, et lui
## que le glTF écrit, avec les réglages dans ses `extras` (« mb_animation » : Godot écrit et relit la méta « extras »
## d'un matériau — lu dans `gltf_document.cpp`, `_attach_meta_to_extras`). À L'ÉCRAN, un `ShaderMaterial` (`materiau`)
## le remplace, qui garde le statique en méta « repli » : toute écriture glTF repasse par le repli (`statique`), toute
## relecture refait l'animé (`anime`). Les greffons l'attendent (LA LISTE DES GREFFONS À FAIRE).
##
## ⚠ **LE TEMPS EST GLOBAL** (`mb_temps`, un paramètre global de shader) : une pause, une vitesse et une image FORCÉE
## (`mb_image` : on peint l'image k, l'écran montre l'image k) valent pour tous les matériaux à la fois.
## ⚠ **SYNCHRO OU DÉCALÉE** : une tuile revient des centaines de fois ; décalée, chaque copie part d'une phase tirée de
## sa POSITION (jamais `randi()` : le même monde à chaque image). Un défilement synchro reste continu d'une tuile à
## l'autre ; décalé, il casse aux joints — d'où le défaut : défilement synchro, images et pulsation décalées.
## ⚠ **LES QUARTS DE TOUR** : les UV d'une tuile tournent avec elle. Un défilement en v (vertical sur une paroi, en
## Boîte) reste vertical sur toutes les copies ; un défilement en u part dans le sens de CHAQUE copie.

const CANAUX := ["albedo", "normale", "orm", "emission"]
const GENRES := ["defilement", "images", "pulsation"]
## Les noms à l'écran (§7).
const NOMS_CANAUX := {"albedo": "Base colour", "normale": "Normal", "orm": "Roughness · metal · AO",
	"emission": "Emission"}
const NOMS_GENRES := {"defilement": "Scroll", "images": "Frames", "pulsation": "Pulse"}

## Le plus d'images par piste, et de pixels en tout (images × largeur × hauteur) — PROPOSÉ : 256 images de 1024² en
## RGBA font 1 Go de mémoire graphique ; 2²⁶ pixels (64 images de 1024², ~270 Mo avec les mipmaps) est la borne.
const IMAGES_MAXI := 256
const PIXELS_MAXI := 1 << 26
const IPS_MAXI := 60.0
const VITESSE_MAXI := 10.0

const DEFAUTS := {
	"defilement": {"u": 0.0, "v": -0.25, "synchro": true},
	"images": {"images": [], "ips": 12.0, "aller_retour": false, "synchro": false},
	"pulsation": {"frequence": 0.5, "mini": 0.2, "synchro": false},
}


# ── LE MODÈLE ────────────────────────────────────────────────────────────────────────────────────────

## Une piste de ce genre est-elle possible sur ce canal ? (La pulsation est celle de l'émission.)
static func possible(canal: String, genre: String) -> bool:
	return canal in CANAUX and genre in GENRES and (genre != "pulsation" or canal == "emission")


## La forme canonique d'une animation (un Variant venu du JSON, d'un .glb ou de l'écran) : les seuls canaux et genres
## connus, chaque réglage borné et typé, rien de vide. {} = pas d'animation.
static func normaliser(a: Variant) -> Dictionary:
	var sortie := {}
	if not a is Dictionary:
		return sortie
	for canal in CANAUX:
		var c: Variant = (a as Dictionary).get(canal)
		if not c is Dictionary:
			continue
		var pistes := {}
		for genre in GENRES:
			var g: Variant = (c as Dictionary).get(genre)
			if not g is Dictionary or not possible(canal, genre):
				continue
			var r := _reglages(genre, g)
			if genre == "images" and (r["images"] as Array).is_empty():
				continue
			pistes[genre] = r
		if not pistes.is_empty():
			sortie[canal] = pistes
	return sortie


static func _reglages(genre: String, g: Dictionary) -> Dictionary:
	var d: Dictionary = DEFAUTS[genre]
	var r := {}
	match genre:
		"defilement":
			r["u"] = clampf(float(g.get("u", d["u"])), -VITESSE_MAXI, VITESSE_MAXI)
			r["v"] = clampf(float(g.get("v", d["v"])), -VITESSE_MAXI, VITESSE_MAXI)
		"images":
			var liste: Array = []
			var brut: Variant = g.get("images", [])
			if brut is Array:
				for p in brut:
					if p is String and p != "" and liste.size() < IMAGES_MAXI:
						liste.append(p)
			r["images"] = liste
			r["ips"] = clampf(float(g.get("ips", d["ips"])), 0.1, IPS_MAXI)
			r["aller_retour"] = bool(g.get("aller_retour", d["aller_retour"]))
		"pulsation":
			r["frequence"] = clampf(float(g.get("frequence", d["frequence"])), 0.0, 20.0)
			r["mini"] = clampf(float(g.get("mini", d["mini"])), 0.0, 1.0)
	r["synchro"] = bool(g.get("synchro", d["synchro"]))
	return r


## Les pistes, dans l'ordre fixe (canaux puis genres) : [[canal, genre], …].
static func pistes(a: Variant) -> Array:
	var n := normaliser(a)
	var sortie: Array = []
	for canal in CANAUX:
		for genre in GENRES:
			if n.has(canal) and (n[canal] as Dictionary).has(genre):
				sortie.append([canal, genre])
	return sortie


## Une piste de plus (réglages par défaut, `reglages` par-dessus). Rend la NOUVELLE animation, ou {"erreur": …} :
## une piste qui existe déjà, ou impossible sur ce canal. ⚠ Une piste d'images sans image n'existe pas : `reglages`
## doit en porter.
static func ajouter(a: Variant, canal: String, genre: String, reglages := {}) -> Dictionary:
	if not possible(canal, genre):
		return {"erreur": "%s cannot have a %s track" % [NOMS_CANAUX.get(canal, canal), NOMS_GENRES.get(genre, genre).to_lower()]}
	var n := normaliser(a)
	if n.has(canal) and (n[canal] as Dictionary).has(genre):
		return {"erreur": "%s already has a %s track" % [NOMS_CANAUX[canal], NOMS_GENRES[genre].to_lower()]}
	var g: Dictionary = (DEFAUTS[genre] as Dictionary).duplicate(true)
	g.merge(reglages, true)
	if genre == "images" and (g["images"] as Array).is_empty():
		return {"erreur": "a frames track needs at least one frame"}
	if not n.has(canal):
		n[canal] = {}
	n[canal][genre] = g
	return normaliser(n)


static func retirer(a: Variant, canal: String, genre: String) -> Dictionary:
	var n := normaliser(a)
	if n.has(canal):
		(n[canal] as Dictionary).erase(genre)
	return normaliser(n)


## Un réglage d'une piste (borné par `normaliser`). Une piste absente : rien ne change.
static func regler(a: Variant, canal: String, genre: String, cle: String, valeur: Variant) -> Dictionary:
	var n := normaliser(a)
	if not n.has(canal) or not (n[canal] as Dictionary).has(genre):
		return n
	n[canal][genre][cle] = valeur
	return normaliser(n)


## Les images d'un canal ([] s'il n'est pas animé par images).
static func images_de(a: Variant, canal: String) -> Array:
	var n := normaliser(a)
	return (n.get(canal, {}) as Dictionary).get("images", {}).get("images", [])


## L'image k d'une piste de 256 images, au temps t — LA RÈGLE (le shader la suit ligne à ligne, `image_de`).
## `phase` ∈ [0, 1[ : 0 pour une piste synchro.
static func image_au_temps(nombre: int, ips: float, aller_retour: bool, t: float, phase := 0.0) -> int:
	if nombre <= 0:
		return 0
	var k := int(floor(t * ips + phase * float(nombre)))
	if aller_retour and nombre > 1:
		var p := 2 * nombre - 2
		k = posmod(k, p)
		return k if k < nombre else p - k
	return posmod(k, nombre)


## La force de la pulsation au temps t : 1 au sommet, `mini` au creux, un cosinus entre les deux.
static func pulsation_au_temps(frequence: float, mini: float, t: float, phase := 0.0) -> float:
	if frequence <= 0.0:
		return 1.0
	return lerpf(mini, 1.0, 0.5 + 0.5 * cos(TAU * (t * frequence + phase)))


## LE DÉFILEMENT AU TEMPS t : le décalage des UV que le shader ajoute (`lire`, ligne à ligne) — `u`, `v` en répétitions
## de l'image par seconde ; une piste décalée part de 7 × sa phase. ⚠ La règle n'était écrite que dans le shader : la
## voici en GDScript pour les cas d'épreuve des greffons (7 octobre 2026).
static func defilement_au_temps(u: float, v: float, t: float, synchro: bool, phase := 0.0) -> Vector2:
	return Vector2(u, v) * (t + (0.0 if synchro else phase * 7.0))


## La phase d'une copie posée à `origine` (son repère dans le monde) — le hachage du shader, `hacher`, ligne à ligne.
static func phase_de(origine: Vector3) -> float:
	var p := (origine + Vector3(0.5, 0.5, 0.5)).floor()
	p = Vector3(_fract(p.x * 0.3183099 + 0.71), _fract(p.y * 0.3183099 + 0.113), _fract(p.z * 0.3183099 + 0.419)) * 17.0
	return _fract(p.x * p.y * p.z * (p.x + p.y + p.z))


static func _fract(x: float) -> float:
	return x - floor(x)


# ── LES IMAGES : SÉQUENCES ET PLANCHES ───────────────────────────────────────────────────────────────

## Une SÉQUENCE : des fichiers, rangés par leur nom (ordre « naturel » : frame_2 avant frame_10), recopiés dans le
## projet (`dossier`, `base_0000.png`…) à la taille de la PREMIÈRE (un tableau de textures n'a qu'une taille).
## Rend {"images": [chemins]} ou {"erreur": …}.
static func importer_sequence(fichiers: PackedStringArray, dossier: String, base: String) -> Dictionary:
	if fichiers.is_empty():
		return {"erreur": "no image chosen"}
	var tries: Array = Array(fichiers)
	tries.sort_custom(func(x: String, y: String) -> bool: return x.get_file().naturalnocasecmp_to(y.get_file()) < 0)
	var images: Array = []
	for f in tries:
		var img := Image.load_from_file(f)
		if img == null or img.is_empty():
			return {"erreur": "cannot read %s" % (f as String).get_file()}
		images.append(img)
	return _ecrire(images, dossier, base)


## Une PLANCHE : une image découpée en `colonnes` × `rangees` cases, lues de gauche à droite puis de haut en bas ;
## `nombre` (0 = toutes) s'arrête avant les cases vides du bout.
static func importer_planche(fichier: String, colonnes: int, rangees: int, nombre: int, dossier: String,
		base: String) -> Dictionary:
	var img := Image.load_from_file(fichier)
	if img == null or img.is_empty():
		return {"erreur": "cannot read %s" % fichier.get_file()}
	return decouper(img, colonnes, rangees, nombre, dossier, base)


static func decouper(img: Image, colonnes: int, rangees: int, nombre: int, dossier: String, base: String) -> Dictionary:
	if colonnes < 1 or rangees < 1:
		return {"erreur": "a sheet needs at least one column and one row"}
	var w := img.get_width() / colonnes
	var h := img.get_height() / rangees
	if w < 1 or h < 1:
		return {"erreur": "the sheet is smaller than its grid"}
	var total := colonnes * rangees if nombre <= 0 else mini(nombre, colonnes * rangees)
	if img.is_compressed():
		img.decompress()
	var images: Array = []
	for k in total:
		images.append(img.get_region(Rect2i((k % colonnes) * w, (k / colonnes) * h, w, h)))
	return _ecrire(images, dossier, base)


## Des images NEUVES, unies, pour peindre une animation à partir de rien.
static func images_neuves(nombre: int, taille: Vector2i, couleur: Color, dossier: String, base: String) -> Dictionary:
	var images: Array = []
	for k in maxi(1, nombre):
		var img := Image.create(taille.x, taille.y, false, Image.FORMAT_RGBA8)
		img.fill(couleur)
		images.append(img)
	return _ecrire(images, dossier, base)


static func _ecrire(images: Array, dossier: String, base: String) -> Dictionary:
	if images.size() > IMAGES_MAXI:
		return {"erreur": "%d frames — at most %d" % [images.size(), IMAGES_MAXI]}
	var taille: Vector2i = (images[0] as Image).get_size()
	if images.size() * taille.x * taille.y > PIXELS_MAXI:
		return {"erreur": "%d frames of %d × %d is too large (at most %d megapixels in all) — use smaller frames" % [
			images.size(), taille.x, taille.y, PIXELS_MAXI >> 20]}
	DirAccess.make_dir_recursive_absolute(dossier)
	var base_libre := _base_libre(dossier, base.validate_filename())
	var chemins: Array = []
	for k in images.size():
		var img: Image = (images[k] as Image).duplicate()
		if img.is_compressed():
			img.decompress()
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		if img.get_size() != taille:
			img.resize(taille.x, taille.y, Image.INTERPOLATE_BILINEAR)
		var chemin := dossier.path_join("%s_%04d.png" % [base_libre, k])
		if img.save_png(chemin) != OK:
			return {"erreur": "cannot write %s" % chemin}
		chemins.append(chemin)
	return {"images": chemins}


## Un nom de base que rien n'utilise encore dans le dossier (une seconde importation ne recouvre pas la première).
static func _base_libre(dossier: String, base: String) -> String:
	var essai := base
	var n := 2
	while FileAccess.file_exists(dossier.path_join("%s_0000.png" % essai)):
		essai = "%s_%d" % [base, n]
		n += 1
	return essai


## Une image de plus, COPIE de l'image `apres` (on peint la suivante en partant de la précédente), insérée juste
## après elle. Rend la nouvelle liste, ou {"erreur"}.
static func dupliquer_image(images: Array, apres: int, dossier: String) -> Dictionary:
	if images.is_empty() or apres < 0 or apres >= images.size():
		return {"erreur": "no frame to copy"}
	if images.size() >= IMAGES_MAXI:
		return {"erreur": "at most %d frames" % IMAGES_MAXI}
	var Peinture: Script = load("res://addons/marchingblocks_core/peinture.gd")
	var t: Dictionary = Peinture.toile(images[apres])
	var img: Image = (t["image"] as Image).duplicate() if not t.is_empty() else Image.load_from_file(images[apres])
	if img == null or img.is_empty():
		return {"erreur": "cannot read the frame"}
	DirAccess.make_dir_recursive_absolute(dossier)
	var base: String = (images[apres] as String).get_file().get_basename()
	var chemin := dossier.path_join("%s_copy.png" % base)
	var n := 2
	while FileAccess.file_exists(chemin) or images.has(chemin):
		chemin = dossier.path_join("%s_copy%d.png" % [base, n])
		n += 1
	if img.save_png(chemin) != OK:
		return {"erreur": "cannot write %s" % chemin}
	var sortie: Array = images.duplicate()
	sortie.insert(apres + 1, chemin)
	return {"images": sortie}


# ── LES TABLEAUX DE TEXTURES (une couche par image) ─────────────────────────────────────────────────

## clé (chemins joints) → {"tableau": Texture2DArray, "chemins": Array, "taille": Vector2i, "sales": {rang: true}}
static var _tableaux := {}


## Le tableau des images `chemins`, PARTAGÉ (toutes les tuiles, le témoin et le monde lisent le même : peindre une
## image la met à jour partout). Une image peinte et pas encore écrite est lue dans sa TOILE.
static func tableau_de(chemins: Array) -> Texture2DArray:
	if chemins.is_empty():
		return null
	var cle := "|".join(PackedStringArray(chemins))
	if _tableaux.has(cle):
		return _tableaux[cle]["tableau"]
	var images: Array[Image] = []
	var taille := Vector2i.ZERO
	for c in chemins:
		var img := _image_de(c, taille)
		if img == null:
			return null
		taille = img.get_size()
		images.append(img)
	var tab := Texture2DArray.new()
	if tab.create_from_images(images) != OK:
		return null
	_tableaux[cle] = {"tableau": tab, "chemins": chemins.duplicate(), "taille": taille, "sales": {}}
	return tab


## L'image d'un chemin, prête pour une couche : RGBA8, à la taille voulue (celle de la première), avec mipmaps.
static func _image_de(chemin: String, taille: Vector2i) -> Image:
	var Peinture: Script = load("res://addons/marchingblocks_core/peinture.gd")
	var img: Image = null
	if Peinture._toiles.has(chemin):
		img = (Peinture._toiles[chemin]["image"] as Image).duplicate()
	elif FileAccess.file_exists(chemin):
		img = Image.load_from_file(chemin)
	if img == null or img.is_empty():
		if taille == Vector2i.ZERO:
			return null
		img = Image.create(taille.x, taille.y, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)   # une image perdue se VOIT (§3), elle n'est pas comblée en silence
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	if taille != Vector2i.ZERO and img.get_size() != taille:
		img.resize(taille.x, taille.y, Image.INTERPOLATE_BILINEAR)
	img.generate_mipmaps()
	return img


## Une toile a changé (un coup de pinceau) : les tableaux qui la portent seront mis à jour à la prochaine image
## (`suivre` — pas à chaque tampon : refaire les mipmaps d'une image de 1024² coûte).
static func toile_changee(chemin: String) -> void:
	for cle in _tableaux:
		var e: Dictionary = _tableaux[cle]
		var r: int = (e["chemins"] as Array).find(chemin)
		if r >= 0:
			e["sales"][r] = true


## Pose les couches périmées. Appelée à chaque image (`avancer`).
static func suivre() -> void:
	for cle in _tableaux:
		var e: Dictionary = _tableaux[cle]
		if (e["sales"] as Dictionary).is_empty():
			continue
		for r in e["sales"]:
			var img := _image_de(e["chemins"][r], e["taille"])
			if img != null:
				(e["tableau"] as Texture2DArray).update_layer(img, r)
		e["sales"] = {}


# ── LE TEMPS (global : une pause, une vitesse, une image forcée pour tous) ─────────────────────────────

static var temps := 0.0
static var vitesse := 1.0
static var en_pause := false
## L'image montrée de force par toutes les pistes d'images (−1 : aucune) — on peint l'image k, on VOIT l'image k.
static var image_forcee := -1
## Le temps figé à 0 (on peint : un défilement en cours décalerait le trait de ce qu'on voit).
static var fige := false
static var _globales_posees := false


static func _poser_les_globales() -> void:
	if _globales_posees:
		return
	_globales_posees = true
	# ⚠ `global_shader_parameter_get_list` est réservé à l'éditeur (mesuré : une erreur dans l'appli) — la variable
	# statique suffit : on les pose une fois par processus.
	RenderingServer.global_shader_parameter_add(&"mb_temps", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	RenderingServer.global_shader_parameter_add(&"mb_image", RenderingServer.GLOBAL_VAR_TYPE_INT, -1)


## À chaque image (l'écran l'appelle) : le temps avance (sauf en pause ou figé), les couches peintes se posent.
static func avancer(delta: float) -> void:
	_poser_les_globales()
	if not en_pause and not fige:
		temps += delta * vitesse
	suivre()
	RenderingServer.global_shader_parameter_set(&"mb_temps", 0.0 if fige else temps)
	RenderingServer.global_shader_parameter_set(&"mb_image", image_forcee)


# ── LES MATÉRIAUX ────────────────────────────────────────────────────────────────────────────────────

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform float mb_temps;
global uniform int mb_image;

uniform vec4 couleur : source_color = vec4(1.0);
uniform float rugosite : hint_range(0.0, 1.0) = 0.8;
uniform float metal : hint_range(0.0, 1.0) = 0.0;
uniform float force_emission = 1.0;
uniform bool a_normale = false;
uniform bool a_orm = false;
uniform bool a_ao = false;
uniform bool a_emission = false;
// x : fréquence (Hz, 0 = aucune), y : la force au creux, z : 1 synchro, 0 décalée
uniform vec3 pulsation = vec3(0.0, 1.0, 1.0);

#CANAUX#

varying float phase;

// LA PHASE D'UNE COPIE, tirée de sa position (`phase_de`, ligne à ligne).
float hacher(vec3 o) {
	vec3 p = floor(o + 0.5);
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419)) * 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	phase = hacher((MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
}

// L'IMAGE AU TEMPS (`image_au_temps`, ligne à ligne). r.x : nombre d'images, r.y : aller-retour, r.z : synchro.
int image_de(ivec4 r, float ips) {
	int n = r.x;
	if (n <= 0) {
		return 0;
	}
	if (mb_image >= 0) {
		return mb_image % n;
	}
	int k = int(floor(mb_temps * ips + (r.z != 0 ? 0.0 : phase * float(n))));
	if (r.y != 0 && n > 1) {
		int p = 2 * n - 2;
		k = k % p;
		return k < n ? k : p - k;
	}
	return k % n;
}

vec4 lire(sampler2D fixe, sampler2DArray imgs, ivec4 r, vec4 m, vec2 uv) {
	// m.xy : vitesse du défilement, m.z : images par seconde, m.w : défilement synchro (1) ou décalé (0)
	vec2 u = uv + m.xy * (mb_temps + (m.w > 0.5 ? 0.0 : phase * 7.0));
	if (r.x > 0) {
		return texture(imgs, vec3(u, float(image_de(r, m.z))));
	}
	return texture(fixe, u);
}

void fragment() {
	vec4 a = lire(albedo_fixe, albedo_images, albedo_reglages, albedo_mouvement, UV);
	ALBEDO = couleur.rgb * a.rgb;
	float r = rugosite;
	float mt = metal;
	if (a_orm) {
		vec4 o = lire(orm_fixe, orm_images, orm_reglages, orm_mouvement, UV);
		r *= o.g;
		mt *= o.b;
		if (a_ao) {
			AO = o.r;
		}
	}
	ROUGHNESS = r;
	METALLIC = mt;
	if (a_normale) {
		NORMAL_MAP = lire(normale_fixe, normale_images, normale_reglages, normale_mouvement, UV).rgb;
	}
	if (a_emission) {
		float p = 1.0;
		if (pulsation.x > 0.0) {
			float t = mb_temps * pulsation.x + (pulsation.z > 0.5 ? 0.0 : phase);
			p = mix(pulsation.y, 1.0, 0.5 + 0.5 * cos(TAU * t));
		}
		EMISSION = lire(emission_fixe, emission_images, emission_reglages, emission_mouvement, UV).rgb * force_emission * p;
	}
}
"""

## Les uniformes d'un canal (« #CANAUX# »). La couleur de base et l'émission sont des COULEURS (sRGB), la normale et
## l'ORM des données.
const UNIFORMES_CANAL := """
uniform sampler2D #C#_fixe : #COULEUR##DEFAUT#, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray #C#_images : #COULEUR2#filter_linear_mipmap_anisotropic, repeat_enable;
uniform ivec4 #C#_reglages = ivec4(0, 0, 1, 1);
uniform vec4 #C#_mouvement = vec4(0.0, 0.0, 12.0, 1.0);
"""

static var _shader: Shader


static func shader() -> Shader:
	if _shader == null:
		_poser_les_globales()
		var canaux := ""
		for c in CANAUX:
			var couleur: bool = c == "albedo" or c == "emission"
			var defaut: String = {"albedo": "hint_default_white", "normale": "hint_normal", "orm": "hint_default_white",
				"emission": "hint_default_black"}[c]
			canaux += UNIFORMES_CANAL.replace("#C#", c).replace("#COULEUR#", "source_color, " if couleur else "") \
				.replace("#DEFAUT#", defaut).replace("#COULEUR2#", "source_color, " if couleur else "")
		_shader = Shader.new()
		_shader.code = SHADER.replace("#CANAUX#", canaux)
	return _shader


## repli (id d'objet) → ShaderMaterial : le même statique donne toujours le même animé (partagé comme la toile).
static var _animes := {}


## Le matériau ANIMÉ d'un statique : ses valeurs et ses textures (l'image 0 des canaux animés y est déjà), plus les
## pistes. Garde le statique en méta « repli ».
static func materiau(repli: BaseMaterial3D, animation: Variant) -> ShaderMaterial:
	var a := normaliser(animation)
	var cle := "%d|%s" % [repli.get_instance_id(), JSON.stringify(a)]
	if _animes.has(cle):
		return _animes[cle]
	var sm := ShaderMaterial.new()
	sm.shader = shader()
	sm.resource_name = repli.resource_name
	sm.set_meta("repli", repli)
	sm.set_meta("animation", a)
	sm.set_shader_parameter("couleur", repli.albedo_color)
	sm.set_shader_parameter("rugosite", repli.roughness)
	sm.set_shader_parameter("metal", repli.metallic)
	sm.set_shader_parameter("albedo_fixe", repli.albedo_texture)
	var orm := repli.roughness_texture != null
	sm.set_shader_parameter("a_normale", repli.normal_enabled and repli.normal_texture != null)
	sm.set_shader_parameter("normale_fixe", repli.normal_texture)
	sm.set_shader_parameter("a_orm", orm)
	sm.set_shader_parameter("a_ao", orm and repli.ao_enabled)
	sm.set_shader_parameter("orm_fixe", repli.roughness_texture)
	sm.set_shader_parameter("a_emission", repli.emission_enabled and repli.emission_texture != null)
	sm.set_shader_parameter("emission_fixe", repli.emission_texture)
	sm.set_shader_parameter("force_emission", repli.emission_energy_multiplier if repli.emission_enabled else 0.0)
	for canal in CANAUX:
		var c: Dictionary = a.get(canal, {})
		var d: Dictionary = c.get("defilement", {})
		var im: Dictionary = c.get("images", {})
		var tab: Texture2DArray = tableau_de(im.get("images", [])) if not im.is_empty() else null
		var n := tab.get_layers() if tab != null else 0
		sm.set_shader_parameter("%s_images" % canal, tab)
		sm.set_shader_parameter("%s_reglages" % canal, Vector4i(n, 1 if bool(im.get("aller_retour", false)) else 0,
			1 if bool(im.get("synchro", true)) else 0, 1 if bool(d.get("synchro", true)) else 0))
		sm.set_shader_parameter("%s_mouvement" % canal, Vector4(float(d.get("u", 0.0)), float(d.get("v", 0.0)),
			float(im.get("ips", 12.0)), 1.0 if bool(d.get("synchro", true)) else 0.0))
	var p: Dictionary = (a.get("emission", {}) as Dictionary).get("pulsation", {})
	sm.set_shader_parameter("pulsation", Vector3(float(p.get("frequence", 0.0)), float(p.get("mini", 1.0)),
		1.0 if bool(p.get("synchro", true)) else 0.0))
	_animes[cle] = sm
	return sm


## L'animation qu'un matériau importé porte dans ses `extras` glTF ({} sans).
static func animation_des_extras(m: Material) -> Dictionary:
	if m == null or not m.has_meta("extras"):
		return {}
	var e: Variant = m.get_meta("extras")
	return normaliser((e as Dictionary).get("mb_animation")) if e is Dictionary else {}


## Un matériau RELU (d'un .glb) : animé s'il porte une animation dans ses extras, sinon tel quel.
static func anime(m: Material) -> Material:
	if m is BaseMaterial3D:
		var a := animation_des_extras(m)
		if not a.is_empty():
			return materiau(m as BaseMaterial3D, a)
	return m


## Le STATIQUE d'un matériau (pour l'écrire en glTF) : le repli d'un animé, sinon lui-même.
static func statique(m: Material) -> Material:
	if m is ShaderMaterial and m.has_meta("repli"):
		return m.get_meta("repli")
	return m


## Le statique pour un fichier qui QUITTE la machine (`.mbset`, vers les moteurs) : une copie dont les extras portent
## l'animation AU FORMAT QUI PART (`vers_format` : en anglais, versionnée), ses images nommées RELATIVEMENT AU `.mbset`
## (`animation/<fichier>`) — un chemin absolu de l'auteur (C:/Users/…) n'a rien à faire chez l'acheteur.
## ⚠ LES IMAGES VOYAGENT (parité des greffons, 7 octobre 2026 ; jusque-là `tiles.glb` ne portait que l'image 0 et les
## NOMS des autres) : `emportees` reçoit {chemin source: chemin relatif}, et c'est `FormatNeutre.exporter` qui recopie
## les fichiers. Deux images de même nom venues de deux dossiers ne s'écrasent pas : la seconde prend « _2 ».
static func statique_pour_l_export(m: Material, emportees: Dictionary = {}) -> Material:
	var s := statique(m)
	var a := animation_des_extras(s)
	if a.is_empty():
		return s
	var copie: Material = s.duplicate()
	for canal in a:
		var im: Dictionary = (a[canal] as Dictionary).get("images", {})
		if not im.is_empty():
			im["images"] = (im["images"] as Array).map(func(c: String) -> String: return _emportee(c, emportees))
	copie.set_meta("extras", {"mb_animation": vers_format(a)})
	return copie


## Le chemin relatif (au `.mbset`) sous lequel une image part : `animation/<son nom>`, unique.
static func _emportee(chemin: String, emportees: Dictionary) -> String:
	if emportees.has(chemin):
		return emportees[chemin]
	var pris := {}
	for c in emportees:
		pris[emportees[c]] = true
	var nom := chemin.get_file()
	var rel := DOSSIER_EMPORTE + "/" + nom
	var i := 2
	while pris.has(rel):
		rel = "%s/%s_%d.%s" % [DOSSIER_EMPORTE, nom.get_basename(), i, nom.get_extension()]
		i += 1
	emportees[chemin] = rel
	return rel


# ── LE FORMAT QUI PART — `mb_animation` dans les extras d'un matériau de `tiles.glb` ────────────────────
#
# ⚠ PARITÉ DES GREFFONS (7 octobre 2026) : le `.mbset` part chez l'acheteur, donc en ANGLAIS (charte §7) et VERSIONNÉ
# (un greffon refuse une animation plus récente que lui). Le témoin, lui, garde les noms du cœur (son aller-retour avec
# Blender, `animation_des_extras`). La traduction vit ICI ET NULLE PART AILLEURS.

const FORMAT_ANIMATION := "marchingblocks-animation"
const VERSION_ANIMATION := 1
const DOSSIER_EMPORTE := "animation"
const CANAUX_EN := {"albedo": "albedo", "normale": "normal", "orm": "orm", "emission": "emission"}
const GENRES_EN := {"defilement": "scroll", "images": "frames", "pulsation": "pulse"}
## Le réglage → [son nom anglais, son type : "nombre", "booleen" ou "images"].
const REGLAGES_EN := {"u": ["u", "nombre"], "v": ["v", "nombre"], "synchro": ["synced", "booleen"],
	"images": ["images", "images"], "ips": ["fps", "nombre"], "aller_retour": ["ping_pong", "booleen"],
	"frequence": ["frequency", "nombre"], "mini": ["minimum", "nombre"]}


## Une animation du cœur (normalisée d'abord) au format qui part ; {} sans animation.
static func vers_format(a: Variant) -> Dictionary:
	var n := normaliser(a)
	if n.is_empty():
		return {}
	var sortie := {"format": FORMAT_ANIMATION, "version": VERSION_ANIMATION}
	for canal in n:
		var pistes := {}
		for genre in n[canal]:
			var r := {}
			for k in n[canal][genre]:
				r[REGLAGES_EN[k][0]] = n[canal][genre][k]
			pistes[GENRES_EN[genre]] = r
		sortie[CANAUX_EN[canal]] = pistes
	return sortie


## LA LECTURE DE RÉFÉRENCE du format qui part (ce que les trois greffons implémentent) : rend l'animation du cœur,
## normalisée — {} si ce n'est pas une animation ou si sa version est plus récente. Une valeur du mauvais TYPE est
## ignorée (le défaut la remplace), un nombre hors bornes est borné, un canal ou un genre inconnu est ignoré, une piste
## d'images sans image n'existe pas, une pulsation hors de l'émission non plus (`normaliser`).
static func depuis_format(e: Variant) -> Dictionary:
	if not e is Dictionary or str((e as Dictionary).get("format", "")) != FORMAT_ANIMATION:
		return {}
	var v: Variant = e.get("version")
	if not (v is float or v is int) or int(v) != v or int(v) < 1 or int(v) > VERSION_ANIMATION:
		return {}
	var fr := {}
	for canal in CANAUX_EN:
		var c: Variant = e.get(CANAUX_EN[canal])
		if not c is Dictionary:
			continue
		var pistes := {}
		for genre in GENRES_EN:
			var g: Variant = (c as Dictionary).get(GENRES_EN[genre])
			if not g is Dictionary:
				continue
			var r := {}
			for k in REGLAGES_EN:
				var x: Variant = (g as Dictionary).get(REGLAGES_EN[k][0])
				match REGLAGES_EN[k][1]:
					"nombre":
						if x is float or x is int:
							r[k] = float(x)
					"booleen":
						if x is bool:
							r[k] = x
					"images":
						if x is Array:
							r[k] = x
			pistes[genre] = r
		fr[canal] = pistes
	return normaliser(fr)


## LA RÈGLE, ÉCRITE (le README du `.mbset`, les cas d'épreuve des greffons). Une ligne par fait.
static func regle_animation() -> PackedStringArray:
	return PackedStringArray([
		"ANIMATED TEXTURES — a material of tiles.glb may carry extras.mb_animation:",
		"  format \"%s\", version %d (refuse anything newer: ignore the animation, show the still material)."
			% [FORMAT_ANIMATION, VERSION_ANIMATION],
		"  channels: albedo, normal, orm (r ambient occlusion, g roughness, b metal), emission. Each has tracks:",
		"    scroll {u, v (image repeats per second, in [-%s, %s]), synced}" % [VITESSE_MAXI, VITESSE_MAXI],
		"    frames {images (paths RELATIVE to the .mbset folder, in order; at most %d), fps (in [0.1, %s])," % [
			IMAGES_MAXI, IPS_MAXI],
		"            ping_pong, synced}   — a frames track without a frame does not exist",
		"    pulse  {frequency (Hz, in [0, 20]), minimum (in [0, 1]), synced}   — emission only",
		"  A value of the wrong type is ignored (its default takes its place), a number out of range is clamped, an",
		"  unknown channel or track is ignored. Defaults: scroll u 0, v -0.25, synced; frames fps 12, no ping-pong,",
		"  not synced; pulse frequency 0.5, minimum 0.2, not synced.",
		"  The material itself is a standard glTF material showing frame 0: an engine that ignores the animation",
		"  still shows the tile right.",
		"TIME is global (one clock for every material). PHASE of a tile = hash of its ORIGIN in FORMAT space (the",
		"  vertex v + piece_offset): p = floor(o + 0.5); p = fract(p * 0.3183099 + (0.71, 0.113, 0.419)) * 17;",
		"  phase = fract(p.x * p.y * p.z * (p.x + p.y + p.z)). A synced track uses phase 0.",
		"  scroll offset at time t = (u, v) * (t + (synced ? 0 : 7 * phase)), added to the UVs (they repeat).",
		"  frame at time t, n frames: k = floor(t * fps + phase * n); ping_pong and n > 1: p = 2n - 2, k = k mod p,",
		"    frame = k < n ? k : p - k; else frame = k mod n (mod is always >= 0).",
		"  pulse at time t: frequency <= 0 gives 1; else minimum + (1 - minimum) * (0.5 + 0.5 cos(2 pi (t * frequency",
		"    + phase))), multiplying the emission.",
		"  The UVs of a tile turn with it: a v scroll stays vertical on every copy, a u scroll follows each copy's turn.",
	])


## Les surfaces d'un maillage, en place : animées (`anime`) ou statiques (`statique`). Rend combien ont changé.
static func animer_le_maillage(mesh: ArrayMesh) -> int:
	return _remplacer(mesh, anime)


static func figer_le_maillage(mesh: ArrayMesh) -> int:
	return _remplacer(mesh, statique)


static func _remplacer(mesh: ArrayMesh, f: Callable) -> int:
	if mesh == null:
		return 0
	var n := 0
	for s in mesh.get_surface_count():
		var m: Material = mesh.surface_get_material(s)
		var autre: Material = f.call(m)
		if autre != m:
			mesh.surface_set_material(s, autre)
			n += 1
	return n


## Un lot porte-t-il un matériau animé ?
static func lot_anime(lot: MeshLibrary) -> bool:
	for id in lot.get_item_list():
		var mesh := lot.get_item_mesh(id) as ArrayMesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			if mesh.surface_get_material(s) is ShaderMaterial and mesh.surface_get_material(s).has_meta("repli"):
				return true
	return false


## Les matériaux d'un lot, animés ou figés, en place.
static func animer_le_lot(lot: MeshLibrary) -> int:
	var n := 0
	for id in lot.get_item_list():
		n += animer_le_maillage(lot.get_item_mesh(id) as ArrayMesh)
	return n


static func figer_le_lot(lot: MeshLibrary) -> int:
	var n := 0
	for id in lot.get_item_list():
		n += figer_le_maillage(lot.get_item_mesh(id) as ArrayMesh)
	return n


## Oublie tout (les tests partent d'un état propre).
static func oublier() -> void:
	_tableaux = {}
	_animes = {}
	temps = 0.0
	vitesse = 1.0
	en_pause = false
	image_forcee = -1
	fige = false
