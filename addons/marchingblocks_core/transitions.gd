extends RefCounted
## LES TRANSITIONS ENTRE COUCHES — DÉCIDÉ (Jordan, 6 octobre 2026 : « go pour l'atelier transitions »), sur ce qui avait
## été proposé et discuté le même jour (charte §5, « les bords partagés entre couches », la suite proposée) :
##
##   • des tuiles de transition SCULPTÉES sont hors de portée — deux couches dans un sommet font 6 050 configurations, au
##     moins 1 513 classes sous les quarts de tour. La transition porte donc sur l'ASPECT : la géométrie reste celle de la
##     couche qui pose le sommet (la règle des couches exclusives, inchangée) ;
##   • une PAIRE de couches (non ordonnée) a DEUX RÉGLAGES — Jordan : « un désert qui empiète sur la roche n'est pas la
##     même chose qu'une roche qui empiète sur le désert » : quand A couvre B, quand B couvre A ;
##   • qui couvre ? LA PRIORITÉ par défaut (la couche la plus haute de la liste), sauf là où un pinceau l'a choisi, sommet
##     par sommet ;
##   • chaque couche a un MATÉRIAU REPRÉSENTANT (une image tuilable projetée en boîte : un UV déplié ne se transporte pas sur
##     une autre géométrie) ; c'est lui qui se mêle à la surface de l'autre couche.
##
## Le rendu (la texture, la table, les représentants, le matériau commun) est dans `transitions_rendu.gd`.
## LA RÈGLE, EN TEMPS CONSTANT, AU FRAGMENT — et c'est pourquoi elle n'ajoute ni tuile ni maillage : le shader
## (`SHADER`, posé en `next_pass` sur les matériaux des tuiles) lit, au point p de la surface, les HUIT cases qui
## l'entourent dans une texture 3D des cases (`construire`), dont chaque texel porte le rang de sa couche et, au sommet, le
## rang de la couche qui y a été choisie pour couvrir. Les huit cases autour de p sont celles du sommet dont la tuile
## porte p (la tuile du sommet v occupe [v+½, v+1½]) : leur couche de plus petit rang est donc la PROPRIÉTAIRE de la
## surface, sans rien déclarer au matériau — un même matériau partagé par deux couches marche.
##   • s = la part de l'AUTRE couche, par interpolation trilinéaire de ses cases (cases vides ignorées) — continue d'une
##     tuile à sa voisine : sur leur face commune, elle ne lit que les quatre cases de cette face ; le sommet est celui de la
##     TUILE (lu dans sa matrice), jamais déduit du point — sur un joint, le point appartient aux deux ;
##   • qui couvre : chaque coin vote (son poids) pour la couche choisie au pinceau, sinon la prioritaire ;
##   • pour chaque direction, la couvrante C, la couverte D, s_C sa part ; décalage = (avance + creux·(½ − hauteur de D) + bruit·(n − ½))·4·s_C·(1 − s_C)
##     — NUL aux deux bouts : là où il n'y a qu'une couche, rien ne change (sinon une marche aux plans des centres de case) ;
##   • visible_C = smoothstep(½ − largeur/2, ½ + largeur/2, s_C + décalage) ; sur la surface de la propriétaire, l'aspect de
##     l'autre se pose avec l'alpha visible_C si l'autre couvre, 1 − visible_C sinon — les deux directions mêlées par les
##     votes. Les deux surfaces qui se rencontrent disent donc la même chose au même point.
## `melange` est cette règle en GDScript (les tests la jugent) ; le shader la dit à la lettre.
## ⚠ UNE PAIRE ÉTEINTE NE CHANGE RIEN : sans aucune paire active, le passage n'est même pas posé.
## ⚠ AU PLUS 15 COUCHES (`MAXI`) : le rang et le choix tiennent chacun dans quatre bits d'un octet (la texture). Au-delà,
## rien.

const MAXI := 15

## Les réglages d'une direction (quand une couche couvre l'autre), et leurs bornes. PROPOSÉS, à juger à l'œil :
##   largeur  : la largeur du fondu (0 : une frontière nette, 1 : un dégradé sur toute la bande) ;
##   avance   : jusqu'où la couvrante déborde au-delà du milieu (négatif : elle recule) ;
##   bruit    : l'irrégularité de la frontière ; grain : la taille de ce bruit (par case) ;
##   creux    : la couvrante remplit d'abord les CREUX de la couverte (les sombres de son image) — le sable dans les
##              fissures de la roche.
const REGLAGES := {"largeur": 0.45, "avance": 0.2, "bruit": 0.35, "grain": 1.5, "creux": 0.5}
const BORNES := {"largeur": [0.05, 1.0], "avance": [-0.5, 0.5], "bruit": [0.0, 1.0], "grain": [0.25, 6.0],
	"creux": [0.0, 1.0]}


## LES NOMS QUI PARTENT (`world.json`, les cas d'épreuve des greffons — charte §7, en anglais) : ceux de l'écran
## (Softness, Reach, Irregularity, Grain, Fills hollows). La traduction vit ICI ET NULLE PART AILLEURS (parité des
## greffons, 7 octobre 2026).
const NOMS_EN := {"largeur": "softness", "avance": "reach", "bruit": "irregularity", "grain": "grain",
	"creux": "fills_hollows"}


## Des réglages bornés, sous leurs noms anglais.
static func reglages_en(r: Variant) -> Dictionary:
	var fr := reglages(r)
	var sortie := {}
	for k in NOMS_EN:
		sortie[NOMS_EN[k]] = fr[k]
	return sortie


## Des réglages lus sous leurs noms anglais (absent : le défaut ; hors bornes : borné), rendus sous les noms du cœur.
static func reglages_depuis_en(r: Variant) -> Dictionary:
	var d: Dictionary = r if r is Dictionary else {}
	var fr := {}
	for k in NOMS_EN:
		if d.has(NOMS_EN[k]):
			fr[k] = d[NOMS_EN[k]]
	return reglages(fr)


## La clé d'une paire de couches (leurs `id`, dans l'ordre croissant) : une paire n'a pas de sens.
static func cle_de_paire(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if int(a) < int(b) or (int(a) == int(b) and a < b) else "%s|%s" % [b, a]


## Des réglages complets et bornés, quoi qu'on lise.
static func reglages(r: Variant) -> Dictionary:
	var d: Dictionary = r if r is Dictionary else {}
	var sortie := {}
	for k in REGLAGES:
		var v := float(d.get(k, REGLAGES[k]))
		sortie[k] = clampf(v, BORNES[k][0], BORNES[k][1])
	return sortie


## Une paire neuve : éteinte, les mêmes réglages dans les deux sens.
static func paire_neuve(a: String, b: String) -> Dictionary:
	return {"actif": false, "couvre": {a: REGLAGES.duplicate(), b: REGLAGES.duplicate()}}


# ── LA RÈGLE ─────────────────────────────────────────────────────────────────────────────────────────

## Le poids trilinéaire du coin k (k = dx + 2·dy + 4·dz) au point f ∈ [0,1]³ de la maille.
static func poids(k: int, f: Vector3) -> float:
	var o := Vector3(k & 1, (k >> 1) & 1, (k >> 2) & 1)
	return (f.x if o.x > 0 else 1.0 - f.x) * (f.y if o.y > 0 else 1.0 - f.y) * (f.z if o.z > 0 else 1.0 - f.z)


## LA RÈGLE en un point. `rangs` : les huit rangs autour du point (−1 : vide), dans l'ordre des coins de `poids` ; `f` : le
## point dans la maille ; `choix` : les huit rangs choisis pour couvrir aux mêmes coins (−1 : la priorité) ; `table` :
## {"C|D": réglages} pour chaque direction ACTIVE (C couvre D) ; `h` : {rang: hauteur de son représentant en ce point} ;
## `n` : le bruit. Rend {} quand rien ne se mêle, sinon {proprio, autre, s (la part de l'autre), alpha (de l'autre)}.
## ⚠ LE CHOIX EST UN CHAMP, LUI AUSSI : lu au seul sommet de la tuile, deux tuiles voisines liraient deux sommets
## différents, et la couvrante changerait d'un coup au joint. Chaque coin VOTE (son poids trilinéaire) pour la couche qui
## y couvre — la choisie, sinon la prioritaire —, et l'alpha est la moyenne des deux directions pesée par ces votes : sur
## une face commune, seuls ses quatre coins votent, les mêmes des deux côtés.
static func melange(rangs: Array, f: Vector3, choix: Array, table: Dictionary, h: Dictionary = {}, n := 0.5) -> Dictionary:
	var proprio := 999
	for r in rangs:
		if int(r) >= 0 and int(r) < proprio:
			proprio = int(r)
	if proprio == 999:
		return {}
	var w_proprio := 0.0
	var parts := {}
	for k in 8:
		var r := int(rangs[k])
		if r < 0:
			continue
		if r == proprio:
			w_proprio += poids(k, f)
		else:
			parts[r] = float(parts.get(r, 0.0)) + poids(k, f)
	var autre := -1
	var meilleur := 0.0
	# ⚠ LE DÉPARTAGE DU SHADER : les coins dans l'ordre, la première part strictement plus grande l'emporte.
	for k in 8:
		var r := int(rangs[k])
		if r >= 0 and r != proprio and float(parts[r]) > meilleur:
			meilleur = parts[r]
			autre = r
	if autre < 0:
		return {}
	var cle_ao := "%d|%d" % [autre, proprio]
	var cle_oa := "%d|%d" % [proprio, autre]
	if not table.has(cle_ao) or not table.has(cle_oa):
		return {}
	var s: float = meilleur / (meilleur + w_proprio)
	var prioritaire := mini(proprio, autre)
	var vote_autre := 0.0
	for k in 8:
		var c := int(choix[k]) if k < choix.size() else -1
		var couvrant: int = c if c == proprio or c == autre else prioritaire
		if couvrant == autre:
			vote_autre += poids(k, f)
	var a_autre := _visible(table[cle_ao], s, float(h.get(proprio, 0.5)), n)            # l'autre couvre
	var a_proprio := 1.0 - _visible(table[cle_oa], 1.0 - s, float(h.get(autre, 0.5)), n)   # la propriétaire couvre
	return {"proprio": proprio, "autre": autre, "s": s, "vote": vote_autre,
		"alpha": vote_autre * a_autre + (1.0 - vote_autre) * a_proprio}


## La part VISIBLE de la couvrante, sa part de cases étant `s_c` et `h` la hauteur de la couverte.
static func _visible(rg: Dictionary, s_c: float, h: float, n: float) -> float:
	var decalage: float = (float(rg["avance"]) + float(rg["creux"]) * (0.5 - h) + float(rg["bruit"]) * (n - 0.5)) \
		* 4.0 * s_c * (1.0 - s_c)
	return smoothstep(0.5 - float(rg["largeur"]) * 0.5, 0.5 + float(rg["largeur"]) * 0.5, s_c + decalage)


## La table de la règle et du shader, depuis l'état de l'écran : {"C|D": réglages} pour chaque direction d'une paire
## ACTIVE dont les deux couches ont un rang. `rang_de` : {id: rang}.
static func table(paires: Dictionary, rang_de: Dictionary) -> Dictionary:
	var sortie := {}
	for cle in paires:
		var p: Dictionary = paires[cle]
		if not bool(p.get("actif", false)):
			continue
		var ids: PackedStringArray = String(cle).split("|")
		if ids.size() != 2 or not rang_de.has(ids[0]) or not rang_de.has(ids[1]):
			continue
		for i in 2:
			var c: String = ids[i]
			var d: String = ids[1 - i]
			var ra := int(rang_de[c])
			var rb := int(rang_de[d])
			if ra >= MAXI or rb >= MAXI:
				continue
			sortie["%d|%d" % [ra, rb]] = reglages((p.get("couvre", {}) as Dictionary).get(c, {}))
	return sortie


# ── LA TEXTURE DES CASES ──────────────────────────────────────────────────────────────────────────────
## UN octet par case, sur la boîte de l'union élargie de `MARGE` : ses quatre bits bas = rang + 1 de sa couche (0 : vide),
## ses quatre bits hauts = rang + 1 de la couche choisie pour couvrir au COIN de même indice (0 : la priorité). Le texel
## (x, y, z) est la case origine + (x, y, z).
## Un seul canal : deux fois moins de mémoire que deux octets par case (~10 Mo sur l'exemple au lieu de ~20).
## ⚠ UNE FAUSSE PISTE, À NE PAS REPRENDRE : on a cru que la carte ne lisait pas le canal G d'une texture RG8 — la capture
## peignait des sommets ENFOUIS sous un bloc, invisibles quoi que fasse le shader. Rien n'a été mesuré contre RG8.

const MARGE := 6


## {origine, taille, octets} pour l'union {case: rang} et les choix {sommet: rang}.
static func construire(union: Dictionary, choix: Dictionary) -> Dictionary:
	if union.is_empty():
		return {"origine": Vector3i.ZERO, "taille": Vector3i.ONE, "octets": PackedByteArray([0, 0])}
	var mini := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var maxi := -mini
	for c in union:
		mini = mini.min(c)
		maxi = maxi.max(c)
	var origine := mini - Vector3i.ONE * MARGE
	var taille := maxi - mini + Vector3i.ONE * (2 * MARGE + 1)
	var o := PackedByteArray()
	o.resize(taille.x * taille.y * taille.z)
	var d := {"origine": origine, "taille": taille, "octets": PackedByteArray()}
	for c in union:
		o[indice(d, c)] = _quartet(int(union[c]))
	for s in choix:
		var i := indice(d, s)
		if i >= 0:
			o[i] = (o[i] & 0x0F) | (_quartet(int(choix[s])) << 4)
	d["octets"] = o
	return d


## rang + 1, ou 0 (vide, ou une couche au-delà de `MAXI`).
static func _quartet(rang: int) -> int:
	return rang + 1 if rang >= 0 and rang < MAXI else 0


## Ce que la texture dit d'une case : son rang (−1 : vide), et le rang choisi pour couvrir à ce coin (−1 : la priorité).
static func rang_lu(d: Dictionary, c: Vector3i) -> int:
	var i := indice(d, c)
	return ((d["octets"] as PackedByteArray)[i] & 0x0F) - 1 if i >= 0 else -1


static func choix_lu(d: Dictionary, c: Vector3i) -> int:
	var i := indice(d, c)
	return ((d["octets"] as PackedByteArray)[i] >> 4) - 1 if i >= 0 else -1


static func indice(d: Dictionary, c: Vector3i) -> int:
	var t: Vector3i = c - (d["origine"] as Vector3i)
	var n: Vector3i = d["taille"]
	if t.x < 0 or t.y < 0 or t.z < 0 or t.x >= n.x or t.y >= n.y or t.z >= n.z:
		return -1
	return (t.z * n.y + t.y) * n.x + t.x


## Pose le rang d'une case (−1 : vide). Rend faux si elle sort de la boîte (il faut tout reconstruire).
static func poser_case(d: Dictionary, c: Vector3i, rang: int) -> bool:
	return _poser(d, c, rang, 0)


static func poser_choix(d: Dictionary, s: Vector3i, rang: int) -> bool:
	return _poser(d, s, rang, 1)


## ⚠ UN `PackedByteArray` LU DANS UN DICTIONNAIRE EST PARTAGÉ : y écrire en fait une COPIE (perdue, vu : une texture vide),
## et le recopier à chaque case coûterait la texture entière. Il est retiré du dictionnaire, écrit, puis remis — seul
## détenteur, il s'écrit en place.
static func _poser(d: Dictionary, c: Vector3i, rang: int, canal: int) -> bool:
	var i := indice(d, c)
	if i < 0:
		return rang < 0
	var o: PackedByteArray = d["octets"]
	d["octets"] = PackedByteArray()
	o[i] = (o[i] & 0xF0) | _quartet(rang) if canal == 0 else (o[i] & 0x0F) | (_quartet(rang) << 4)
	d["octets"] = o
	return true


## Les tranches de la texture (une Image par z), comme les attend `ImageTexture3D`.
static func tranches(d: Dictionary, seulement: Dictionary = {}, avant: Array = []) -> Array[Image]:
	var n: Vector3i = d["taille"]
	var par := n.x * n.y
	var sortie: Array[Image] = []
	for z in n.z:
		if not seulement.is_empty() and not seulement.has(z) and z < avant.size():
			sortie.append(avant[z])
			continue
		sortie.append(Image.create_from_data(n.x, n.y, false, Image.FORMAT_R8,
			(d["octets"] as PackedByteArray).slice(z * par, (z + 1) * par)))
	return sortie


# ── LE SHADER ────────────────────────────────────────────────────────────────────────────────────────
## Le passage posé PAR-DESSUS les matériaux des tuiles (`next_pass`) : il ne dessine que l'aspect de l'autre couche, en
## transparence, là où la règle le demande, et jette tout le reste. ⚠ LE SOMMET EST POUSSÉ DE 2 MILLIÈMES LE LONG DE SA
## NORMALE : deux passages sur la même géométrie peuvent ne pas calculer la même profondeur au bit près.

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform sampler3D cases : filter_nearest, repeat_disable;
uniform ivec3 origine;
uniform ivec3 taille;
uniform sampler2D table : filter_nearest, repeat_disable;
uniform sampler2DArray representants : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 rep_couleur[15];
uniform float rep_echelle[15];
uniform float rep_rugosite[15];
uniform bool montrer_choix = false;

varying vec3 p_monde;
varying vec3 n_monde;
varying flat vec3 centre;

void vertex() {
	VERTEX += NORMAL * 0.002;
	p_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	centre = MODEL_MATRIX[3].xyz;
}

float hache(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.13));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float bruit3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hache(i), hache(i + vec3(1, 0, 0)), f.x), mix(hache(i + vec3(0, 1, 0)), hache(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hache(i + vec3(0, 0, 1)), hache(i + vec3(1, 0, 1)), f.x), mix(hache(i + vec3(0, 1, 1)), hache(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

vec4 aspect(int k, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	float e = max(rep_echelle[k], 0.01);
	vec4 c = texture(representants, vec3(p.zy / e, float(k))) * w.x
		+ texture(representants, vec3(p.xz / e, float(k))) * w.y
		+ texture(representants, vec3(p.xy / e, float(k))) * w.z;
	return c * rep_couleur[k];
}

float visible(vec4 p1, vec4 p2, float s_c, float h, float n) {
	float decalage = (p1.b + p2.r * (0.5 - h) + p1.a * (n - 0.5)) * 4.0 * s_c * (1.0 - s_c);
	return smoothstep(0.5 - p1.g * 0.5, 0.5 + p1.g * 0.5, s_c + decalage);
}

int rang_en(ivec3 c, int canal) {
	ivec3 t = c - origine;
	if (t.x < 0 || t.y < 0 || t.z < 0 || t.x >= taille.x || t.y >= taille.y || t.z >= taille.z) {
		return -1;
	}
	int v = int(round(texelFetch(cases, t, 0).r * 255.0));
	return (canal == 0 ? (v & 15) : (v >> 4)) - 1;
}

void fragment() {
	// ⚠ LE SOMMET DE LA TUILE, PAS CELUI DU POINT (vu à l'image : des pointillés clairs à chaque joint de la bande) : sur le bord
	// d'une tuile, floor(p − ½) bascule dans la maille de la voisine, le passage s'y jette, et la tuile native transparaît. La
	// tuile du sommet v est posée en v + 1 (son centre) : on le lit dans sa matrice, et le point est borné à sa maille (un
	// relief qui déborde de sa case, règle (A), prend la couleur de son bord). ⚠ LU DANS vertex() : dans fragment(), la
	// MODEL_MATRIX d'une MultiMesh (celle du GridMap) n'a pas la pose de l'instance (vu : plus aucun fondu).
	ivec3 b = ivec3(round(centre - vec3(1.0)));
	vec3 f = clamp(p_monde - vec3(b) - vec3(0.5), vec3(0.0), vec3(1.0));
	int r[8];
	float w[8];
	int proprio = 999;
	for (int k = 0; k < 8; k++) {
		ivec3 o = ivec3(k & 1, (k >> 1) & 1, (k >> 2) & 1);
		r[k] = rang_en(b + o, 0);
		vec3 g = mix(vec3(1.0) - f, f, vec3(o));
		w[k] = g.x * g.y * g.z;
		if (r[k] >= 0 && r[k] < proprio) {
			proprio = r[k];
		}
	}
	if (proprio == 999) {
		discard;
	}
	float w_proprio = 0.0;
	float meilleur = 0.0;
	int autre = -1;
	for (int k = 0; k < 8; k++) {
		if (r[k] == proprio) {
			w_proprio += w[k];
		} else if (r[k] >= 0) {
			float part = 0.0;
			for (int j = 0; j < 8; j++) {
				if (r[j] == r[k]) {
					part += w[j];
				}
			}
			if (part > meilleur) {
				meilleur = part;
				autre = r[k];
			}
		}
	}
	if (autre < 0) {
		discard;
	}
	vec4 ao1 = texelFetch(table, ivec2(2 * proprio, autre), 0);
	vec4 oa1 = texelFetch(table, ivec2(2 * autre, proprio), 0);
	if (ao1.r < 0.5 || oa1.r < 0.5) {
		discard;
	}
	vec4 ao2 = texelFetch(table, ivec2(2 * proprio + 1, autre), 0);
	vec4 oa2 = texelFetch(table, ivec2(2 * autre + 1, proprio), 0);
	float s = meilleur / (meilleur + w_proprio);
	int prioritaire = min(proprio, autre);
	float vote_autre = 0.0;
	bool peint = false;
	for (int k = 0; k < 8; k++) {
		int c = rang_en(b + ivec3(k & 1, (k >> 1) & 1, (k >> 2) & 1), 1);
		peint = peint || c >= 0;
		int couvrant = (c == proprio || c == autre) ? c : prioritaire;
		if (couvrant == autre) {
			vote_autre += w[k];
		}
	}
	float n = bruit3(p_monde * ao2.g);
	float h_proprio = dot(aspect(proprio, p_monde, n_monde).rgb, vec3(0.299, 0.587, 0.114));
	float h_autre = dot(aspect(autre, p_monde, n_monde).rgb, vec3(0.299, 0.587, 0.114));
	float a_autre = visible(ao1, ao2, s, h_proprio, n);
	float a_proprio = 1.0 - visible(oa1, oa2, 1.0 - s, h_autre, bruit3(p_monde * oa2.g));
	float a = vote_autre * a_autre + (1.0 - vote_autre) * a_proprio;
	if (a < 0.004) {
		discard;
	}
	vec3 couleur = aspect(autre, p_monde, n_monde).rgb;
	if (montrer_choix && peint) {
		couleur = mix(couleur, vec3(1.0, 0.85, 0.2), 0.35);
	}
	ALBEDO = couleur;
	ROUGHNESS = rep_rugosite[autre];
	ALPHA = a;
}
"""
