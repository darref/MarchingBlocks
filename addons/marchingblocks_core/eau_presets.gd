@tool
extends RefCounted
## LES PRESETS D'EAU — des EXEMPLES, pas une obligation (charte §5, « le mode Fluids »).
##
## **DÉCIDÉ (Jordan, 1er octobre 2026)** : l'artiste est prévenu que ces presets ne sont pas obligatoires ; son
## propre shader, dans son moteur, reçoit les mêmes données (le contrat de `eau_maillage.gd` : courant, genre,
## profondeur, UV). Un shader de Godot ne voyage pas (§4) : chaque preset sera réécrit dans chaque moteur.
##
## « stylise » — L'EAU DE RIVERSTONES (`D:/RollingStones/CLIENT/eau.gd`, du même auteur), reprise et adaptée :
##   - NON ÉCLAIRÉE et OPAQUE : la couleur affichée est la couleur décidée, « profond = sombre » ;
##   - la profondeur vient du TERRAIN RENDU (le tampon de profondeur), en différence VERTICALE : la ligne de
##     rive tombe là où l'eau touche vraiment la roche, sans rien déclarer ;
##   - trois tons fondus, une houle quantifiée en marches qui défile dans le sens du courant, des lignes de
##     courant furtives, un liseré blanc à la rive, des caustiques dans le peu profond.
##   ⚠ Ce qui change : le courant vient des SOMMETS (le contrat), pas d'une carte de flux cuite ; et une
##   CASCADE (genre 1) est une lame verticale, rayée de stries qui tombent.
##   ⚠ `ALPHA = 1.0` est écrit EXPRÈS : il fait passer la nappe dans la passe transparente, la seule où le
##   tampon de profondeur des objets opaques se lit.
##   ⚠ ET `depth_draw_always` PARCE QUE DE LÀ : en passe transparente, la nappe n'écrit plus sa profondeur, et dans
##   UN maillage la bande du fond d'une fosse se dessinait PAR-DESSUS le lac qui la noie (vu à l'image).

##
## « transparent » — L'EAU CLAIRE QUI RÉFRACTE (Jordan, 1er octobre 2026) : on voit le fond À TRAVERS, déformé par
##   les vagues ; la couleur de l'eau monte avec la PROFONDEUR (absorption de Beer-Lambert, sur la profondeur
##   verticale du terrain rendu, comme « stylise »), un liseré clair au rivage, éclairée par le moteur (reflet du
##   soleil). ⚠ Le fond réfracté est lu dans la texture d'ÉCRAN : il est déjà éclairé, il part donc en ÉMISSION
##   (en albédo, la lumière le compterait deux fois). ⚠ Un objet DEVANT la nappe ne doit pas être réfracté dans
##   l'eau : si la profondeur au point décalé est plus proche que la nappe, on ne décale pas.
## « reflechissant » — L'EAU QUI REFLÈTE (Jordan, 1er octobre 2026) : sombre et lisse, son opacité suit FRESNEL
##   (transparente vue d'en haut, miroir en rasant) et la profondeur ; les reflets viennent du ciel de
##   l'environnement et du soleil. ⚠ CE QUI N'Y EST PAS : le reflet du RELIEF. Le SSR de Godot ne s'applique
##   qu'aux matériaux opaques, et une sonde de réflexion par nappe serait une scène à part — à décider à l'image.
##
## LES DEUX NOUVEAUX PARTAGENT les vagues (`hauteur_vagues`) : une somme d'ondes tournées, qui défilent dans le sens
## du courant sur une rivière et dérivent lentement sur une eau dormante ; leur normale déforme la réfraction et les
## reflets. Une CASCADE (genre 1) garde ses stries qui tombent.

##
## TROIS LIQUIDES DE PLUS — DEMANDÉS PAR JORDAN (2 octobre 2026) : « lave, eau de marais, acide luminescent », des presets
## de couche d'eau comme les trois premiers, sur le MÊME contrat (courant, genre, profondeur) et la même règle
## d'écoulement — une lave coule et remplit un creux comme l'eau ; seul l'aspect change.
## « lave » — une CROÛTE sombre fendue de fissures incandescentes (des cellules de Voronoï qui dérivent avec le
##   courant), plus chaude au large qu'au bord (la profondeur du terrain rendu) ; opaque ; l'incandescence est de
##   l'ÉMISSION, que le halo du Play test fait rayonner. ⚠ PROPOSÉ : elle LUIT, elle n'éclaire pas le décor (une
##   lumière par nappe serait une scène à part) ; une cascade de lave est une coulée vive.
## « marais » — une eau TROUBLE (brun-vert, l'absorption forte : le fond disparaît à une demi-case), couverte de plaques
##   de lentilles d'eau qui dérivent lentement, et de rares bulles.
## « acide » — un vert LUMINESCENT (émissif), légèrement translucide, des bulles qui luisent et une écume jaune-vert à
##   la rive. ⚠ PROPOSÉ : il luit, il n'éclaire pas (même raison que la lave).

const PRESETS := ["stylise", "transparent", "reflechissant", "lave", "marais", "acide"]
const NOMS := {"stylise": "Stylized (RiverStones)", "transparent": "Clear (refraction)",
	"reflechissant": "Reflective", "lave": "Lava", "marais": "Swamp water", "acide": "Glowing acid"}

## Les outils communs : bruit, vagues, profondeur verticale, stries de cascade. Insérés par `replace`, jamais
## par `%` (un shader a le droit de contenir un pourcent).
const COMMUN := """
float bruit(vec2 p) {
	return fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453);
}

float bruit_lisse(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	float a = bruit(i);
	float b = bruit(i + vec2(1.0, 0.0));
	float c = bruit(i + vec2(0.0, 1.0));
	float d = bruit(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// La hauteur des vagues en `p` (monde, x z) : trois ondes TOURNÉES l'une par rapport à l'autre (sinon on lit
// un damier), plus un bruit lent ; tout défile le long du courant de `defile`.
float hauteur_vagues(vec2 p, vec2 flux, float defile, float t) {
	vec2 n = vec2(-flux.y, flux.x);
	vec2 q = vec2(dot(p, n), dot(p, flux) - defile);
	float h = 0.50 * sin(q.y * 1.35 + q.x * 0.35 + t * 1.1)
		+ 0.32 * sin(q.y * 2.30 - q.x * 1.10 - t * 1.6)
		+ 0.18 * sin(q.x * 3.10 + q.y * 1.70 + t * 2.3);
	return h + 0.45 * bruit_lisse(q * 1.3);
}

// La normale MONDE de la surface ondulée, par différences finies sur la hauteur.
vec3 normale_vagues(vec2 p, vec2 flux, float defile, float t, float relief) {
	float e = 0.04;
	float h0 = hauteur_vagues(p, flux, defile, t);
	float hx = hauteur_vagues(p + vec2(e, 0.0), flux, defile, t);
	float hz = hauteur_vagues(p + vec2(0.0, e), flux, defile, t);
	return normalize(vec3(-(hx - h0) / e * relief, 1.0, -(hz - h0) / e * relief));
}

// LE MICRO (Jordan, 3 octobre 2026 : « la texture des eaux a une macro mais pas de micro, à l'échelle du stickman ») :
// des rides d'environ 0,14, 0,07 et 0,04 case — trois octaves d'un bruit DÉRIVABLE, tournées l'une par rapport à
// l'autre, qui défilent avec le courant. ⚠ Quatre ondes pures faisaient un QUADRILLAGE de points, lu comme un motif
// imprimé (vu à l'image) : un bruit ne se répète pas. La pente est ANALYTIQUE (les différences finies de
// `normale_vagues`, au pas de 0,04, sont trop grossières ici) ; chaque octave s'EFFACE quand un pixel couvre plus
// d'un quart de ride (`pas` : la taille d'un pixel, en cases) — sinon, au loin, elles scintillent.
vec3 bruit_derive(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	vec2 du = 6.0 * f * (1.0 - f);
	float a = bruit(i);
	float b = bruit(i + vec2(1.0, 0.0));
	float c = bruit(i + vec2(0.0, 1.0));
	float d = bruit(i + vec2(1.0, 1.0));
	float k = a - b - c + d;
	return vec3(a + (b - a) * u.x + (c - a) * u.y + k * u.x * u.y,
		du * vec2(b - a + k * u.y, c - a + k * u.x));
}

// La pente (d/dx, d/dz) des micro-rides, dans le monde.
vec2 pente_micro(vec2 p, vec2 flux, float defile, float t, float pas) {
	vec2 n = vec2(-flux.y, flux.x);
	vec2 q = vec2(dot(p, n), dot(p, flux) - defile * 1.3);
	vec2 g = vec2(0.0);
	float amp = 1.0;
	float fr = 7.0;
	mat2 r = mat2(vec2(1.0, 0.0), vec2(0.0, 1.0));
	mat2 tour = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	for (int o = 0; o < 3; o++) {
		vec3 b = bruit_derive((r * q) * fr + vec2(t * 0.45 * float(o + 1), -t * 0.3));
		float efface = 1.0 - smoothstep(0.15, 0.4, pas * fr);
		g += amp * efface * fr * (transpose(r) * b.yz);
		amp *= 0.5;
		fr *= 1.95;
		r = tour * r;
	}
	return (g.x * n + g.y * flux) * 0.02;
}

// La normale MONDE des vagues ET des micro-rides. `pas` : length(fwidth(position xz)), pris dans fragment().
vec3 normale_eau(vec2 p, vec2 flux, float defile, float t, float relief, float pas, float force_micro) {
	vec3 b = normale_vagues(p, flux, defile, t, relief);
	vec2 g = pente_micro(p, flux, defile, t, pas) * force_micro;
	return normalize(vec3(b.x / b.y - g.x, 1.0, b.z / b.y - g.y));
}

// La profondeur VERTICALE sous ce fragment, jusqu'au terrain rendu (le tampon de profondeur des opaques).
float profondeur_sous(sampler2D tex, vec2 uv, mat4 inv_proj, mat4 inv_vue, float y) {
	float dz = texture(tex, uv).x;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, dz, 1.0);
	vec3 fond = (inv_vue * vec4(v.xyz / v.w, 1.0)).xyz;
	return y - fond.y;
}

// La profondeur de VUE (négative) du terrain rendu en `uv`.
float z_vue(sampler2D tex, vec2 uv, mat4 inv_proj) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, texture(tex, uv).x, 1.0);
	return v.z / v.w;
}

// Un point au hasard dans la case `p` (pour les cellules).
vec2 hasard2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// LES CELLULES (Voronoï) : la distance au BORD de la cellule la plus proche (F2 − F1) — petite sur les fissures.
// Les germes oscillent lentement avec `t` : la croûte respire sans glisser.
float bord_de_cellule(vec2 p, float t) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = 0.5 + 0.5 * sin(t * 0.3 + 6.2831 * hasard2(i + g));
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
}

// UNE BULLE RONDE dans sa case de bruit : ⚠ sans ce disque, chaque bulle était un CARRÉ (vu à l'image).
float bulle_ronde(vec2 q) {
	return 1.0 - smoothstep(0.18, 0.32, length(fract(q) - 0.5));
}

// Les stries d'une cascade, qui tombent (UV.y est la hauteur du monde).
float stries(vec2 uv, float t) {
	return smoothstep(0.5, 0.85, bruit_lisse(vec2(uv.x * 7.0, uv.y * 0.9 + t * 3.0)));
}

// ⚠ UNE CASCADE EST DE L'ÉCUME, PAS DE L'EAU CLAIRE : transparente comme une nappe, la lame n'était qu'un fantôme
// gris contre la falaise (vu à l'image). Elle garde ses stries qui tombent, sur un voile blanc-bleu presque opaque.
vec3 couleur_cascade(vec3 c_eau, vec3 c_ecume, vec2 uv, float t) {
	float voile = bruit_lisse(vec2(uv.x * 2.0, uv.y * 0.4 + t * 2.2));
	return mix(mix(c_eau, c_ecume, 0.35 + 0.25 * voile), c_ecume, stries(uv, t) * 0.75);
}

// LE REFLET DU RELIEF, EN ESPACE ÉCRAN : le SSR du moteur ne voit pas les matériaux transparents, on marche donc
// le rayon réfléchi (repère de VUE) contre le tampon de profondeur. Rend (couleur, poids) ; poids 0 si le rayon
// sort de l'écran, part vers l'œil ou ne touche rien — le ciel de l'environnement prend alors le relais.
vec4 reflet_ecran(vec3 pos, vec3 dir, sampler2D tex_ecran, sampler2D tex_prof, mat4 proj, mat4 inv_proj) {
	if (dir.z > 0.0) {
		return vec4(0.0);
	}
	float pas = 0.2;
	vec3 p = pos;
	for (int i = 0; i < 48; i++) {
		p += dir * pas;
		pas *= 1.07;
		vec4 c = proj * vec4(p, 1.0);
		vec2 uv = c.xy / c.w * 0.5 + 0.5;
		if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
			break;
		}
		float zs = z_vue(tex_prof, uv, inv_proj);
		if (zs > p.z && zs - p.z < pas * 2.0 + 0.2) {
			vec2 bord = min(uv, 1.0 - uv);
			float fondu = smoothstep(0.0, 0.08, min(bord.x, bord.y)) * (1.0 - float(i) / 48.0);
			return vec4(textureLod(tex_ecran, uv, 0.0).rgb, fondu);
		}
	}
	return vec4(0.0);
}
"""

const TRANSPARENT := """
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec3 teinte : source_color = vec3(0.10, 0.42, 0.46);
uniform vec3 teinte_profonde : source_color = vec3(0.02, 0.13, 0.22);
uniform vec3 ecume : source_color = vec3(0.90, 0.97, 1.0);
uniform float absorption = 0.85;
uniform float refraction = 0.035;
uniform float ampleur = 0.08;
uniform float vitesse_riviere = 1.6;
uniform float vitesse_dormante = 0.25;
uniform float clapot = 0.03;

// Les micro-rides, à l'échelle du personnage (`pente_micro`) : 0 les éteint.
uniform float micro = 0.55;
varying vec3 v_monde;
varying vec2 v_courant;
varying float v_genre;

// %COMMUN%

void vertex() {
	v_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_courant = COLOR.rg * 2.0 - 1.0;
	v_genre = COLOR.b;
	// ⚠ LE CLAPOT SOULÈVE AUSSI LES CASCADES (3 octobre 2026) : il ne soulevait que les nappes, et le bord de la
	// lèvre montait et descendait au-dessus du haut FIXE de la lame — un fil sombre le long de chaque cascade.
	// Il dépend de (x, z) seulement : deux sommets à la même place bougent ensemble, la lame suit sa lèvre.
	VERTEX.y += clapot * sin(v_monde.z * 0.55 + v_monde.x * 0.85 + TIME * 1.9);
}

void fragment() {
	float t = TIME;
	bool courante = v_genre > 0.25;
	bool cascade = v_genre > 0.75;
	vec2 flux = length(v_courant) > 0.1 ? normalize(v_courant) : vec2(0.6, 0.8);
	float defile = t * (courante ? vitesse_riviere : vitesse_dormante);
	vec3 nw = cascade ? vec3(0.0, 0.0, 1.0) : normale_eau(v_monde.xz, flux, defile, t, ampleur, length(fwidth(v_monde.xz)), micro);
	float prof = profondeur_sous(depth_tex, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, v_monde.y);
	// La réfraction : le fond lu à côté, d'autant plus que l'eau est profonde (rien au ras de la rive).
	vec2 decal = nw.xz * refraction * clamp(prof, 0.0, 1.0) * (cascade ? 0.0 : 1.0);
	vec2 uv = SCREEN_UV + decal;
	if (z_vue(depth_tex, uv, INV_PROJECTION_MATRIX) > VERTEX.z) {
		uv = SCREEN_UV;   // ce qui est DEVANT la nappe ne se réfracte pas dedans
	}
	vec3 fond = textureLod(ecran, uv, 0.0).rgb;
	float p = max(profondeur_sous(depth_tex, uv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, v_monde.y), 0.0);
	float transmis = exp(-p * absorption);
	vec3 eau = mix(teinte, teinte_profonde, 1.0 - exp(-p * 0.35));
	// Le liseré : là où l'eau touche la roche.
	float rive = 1.0 - smoothstep(0.02, 0.12, max(prof, 0.0));
	float blanc = rive * 0.7;
	ALBEDO = cascade ? couleur_cascade(teinte, ecume, UV, t) : mix(eau * (1.0 - transmis), ecume, blanc);
	EMISSION = cascade ? vec3(0.0) : fond * transmis * (1.0 - blanc);
	ROUGHNESS = cascade ? 0.5 : 0.06;
	SPECULAR = 0.55;
	NORMAL = cascade ? NORMAL : normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALPHA = 1.0;
}
"""

const REFLECHISSANT := """
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec3 teinte : source_color = vec3(0.03, 0.12, 0.18);
uniform vec3 teinte_cascade : source_color = vec3(0.30, 0.55, 0.70);
uniform float force_reflet = 1.0;
uniform float aplati = 0.3;
uniform vec3 ecume : source_color = vec3(0.90, 0.97, 1.0);
uniform float opacite_min = 0.35;
uniform float absorption = 0.9;
uniform float ampleur = 0.06;
uniform float vitesse_riviere = 1.6;
uniform float vitesse_dormante = 0.25;
uniform float clapot = 0.03;

// Les micro-rides, à l'échelle du personnage (`pente_micro`) : 0 les éteint.
uniform float micro = 0.40;
varying vec3 v_monde;
varying vec2 v_courant;
varying float v_genre;

// %COMMUN%

void vertex() {
	v_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_courant = COLOR.rg * 2.0 - 1.0;
	v_genre = COLOR.b;
	// Le clapot, cascades comprises (voir le premier preset).
	VERTEX.y += clapot * sin(v_monde.z * 0.55 + v_monde.x * 0.85 + TIME * 1.9);
}

void fragment() {
	float t = TIME;
	bool courante = v_genre > 0.25;
	bool cascade = v_genre > 0.75;
	vec2 flux = length(v_courant) > 0.1 ? normalize(v_courant) : vec2(0.6, 0.8);
	float defile = t * (courante ? vitesse_riviere : vitesse_dormante);
	vec3 nw = cascade ? vec3(0.0, 0.0, 1.0) : normale_eau(v_monde.xz, flux, defile, t, ampleur, length(fwidth(v_monde.xz)), micro);
	vec3 nv = cascade ? NORMAL : normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float prof = max(profondeur_sous(depth_tex, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, v_monde.y), 0.0);
	// Fresnel (Schlick, eau ≈ 0,02) : transparente vue d'en haut, miroir en rasant.
	float fresnel = 0.02 + 0.98 * pow(1.0 - clamp(dot(nv, VIEW), 0.0, 1.0), 5.0);
	float rive = 1.0 - smoothstep(0.02, 0.12, prof);
	float blanc = cascade ? 1.0 : rive * 0.7;
	// ⚠ LE MIROIR SE REGARDE SUR UNE NORMALE APLATIE : avec toute la houle, le relief reflété partait en taches
	// éparses (vu à l'image, poids du reflet peint en rouge) ; l'éclat du soleil, lui, garde les vagues entières.
	vec3 n_miroir = normalize(mix((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, nv, aplati));
	vec4 r = cascade ? vec4(0.0) : reflet_ecran(VERTEX, reflect(-VIEW, n_miroir), ecran, depth_tex,
		PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
	ALBEDO = cascade ? couleur_cascade(teinte_cascade, ecume, UV, t) : mix(teinte, ecume, blanc);
	// Le relief reflété : pondéré par Fresnel, il REMPLACE le ciel là où le rayon touche quelque chose.
	EMISSION = r.rgb * r.a * fresnel * force_reflet;
	ROUGHNESS = cascade ? 0.5 : mix(0.03, 0.4, blanc);
	METALLIC = 0.0;
	SPECULAR = 0.8 * (1.0 - r.a * 0.8);
	NORMAL = nv;
	ALPHA = cascade ? 0.92 : clamp(max(max(opacite_min, fresnel), max(1.0 - exp(-prof * absorption), blanc)), 0.0, 1.0);
}
"""

const LAVE := """
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec3 croute : source_color = vec3(0.07, 0.035, 0.03);
uniform vec3 roche_chaude : source_color = vec3(0.32, 0.07, 0.02);
uniform vec3 magma : source_color = vec3(1.0, 0.36, 0.06);
uniform float incandescence = 4.0;
uniform float taille_des_plaques = 0.9;
uniform float vitesse_riviere = 0.45;
uniform float vitesse_dormante = 0.06;
uniform float clapot = 0.015;

varying vec3 v_monde;
varying vec2 v_courant;
varying float v_genre;

// %COMMUN%

void vertex() {
	v_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_courant = COLOR.rg * 2.0 - 1.0;
	v_genre = COLOR.b;
	// Le clapot, cascades comprises (voir le premier preset).
	VERTEX.y += clapot * sin(v_monde.z * 0.4 + v_monde.x * 0.6 + TIME * 0.7);
}

void fragment() {
	float t = TIME;
	bool courante = v_genre > 0.25;
	bool cascade = v_genre > 0.75;
	vec2 flux = length(v_courant) > 0.1 ? normalize(v_courant) : vec2(0.6, 0.8);
	float defile = t * (courante ? vitesse_riviere : vitesse_dormante);
	float prof = max(profondeur_sous(depth_tex, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, v_monde.y), 0.0);
	vec2 p = v_monde.xz * taille_des_plaques - flux * defile;
	float bord = bord_de_cellule(p, t);
	float fissure = 1.0 - smoothstep(0.0, 0.13, bord);
	// Plus chaude au large, figée contre la rive : la croûte se referme là où la lave est mince.
	float chaleur = smoothstep(0.05, 0.6, prof) * (0.75 + 0.25 * sin(t * 1.3 + bruit_lisse(p * 2.0) * 6.0));
	vec3 albedo = mix(croute, roche_chaude, bruit_lisse(p * 3.0) * 0.6);
	float lueur = fissure * chaleur + 0.08 * chaleur;
	// La cascade : une coulée vive, rayée de croûte qui tombe.
	float s = stries(UV, t * 0.3);
	ALBEDO = cascade ? mix(roche_chaude, croute, s * 0.7) : albedo;
	EMISSION = magma * incandescence * (cascade ? (1.0 - s * 0.7) * 0.8 : lueur);
	ROUGHNESS = 0.9;
	ALPHA = 1.0;
}
"""

const MARAIS := """
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec3 trouble : source_color = vec3(0.16, 0.19, 0.09);
uniform vec3 trouble_profond : source_color = vec3(0.06, 0.08, 0.04);
uniform vec3 lentilles : source_color = vec3(0.30, 0.45, 0.10);
uniform vec3 boue : source_color = vec3(0.30, 0.24, 0.14);
uniform float absorption = 3.2;
uniform float ampleur = 0.03;
uniform float vitesse_riviere = 0.8;
uniform float vitesse_dormante = 0.04;
uniform float clapot = 0.01;

// Les micro-rides, à l'échelle du personnage (`pente_micro`) : 0 les éteint.
uniform float micro = 0.25;
varying vec3 v_monde;
varying vec2 v_courant;
varying float v_genre;

// %COMMUN%

void vertex() {
	v_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_courant = COLOR.rg * 2.0 - 1.0;
	v_genre = COLOR.b;
	// Le clapot, cascades comprises (voir le premier preset).
	VERTEX.y += clapot * sin(v_monde.z * 0.5 + v_monde.x * 0.7 + TIME * 0.9);
}

void fragment() {
	float t = TIME;
	bool courante = v_genre > 0.25;
	bool cascade = v_genre > 0.75;
	vec2 flux = length(v_courant) > 0.1 ? normalize(v_courant) : vec2(0.6, 0.8);
	float defile = t * (courante ? vitesse_riviere : vitesse_dormante);
	vec3 nw = cascade ? vec3(0.0, 0.0, 1.0) : normale_eau(v_monde.xz, flux, defile, t, ampleur, length(fwidth(v_monde.xz)), micro);
	float prof = max(profondeur_sous(depth_tex, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, v_monde.y), 0.0);
	// Le fond se perd vite : une demi-case suffit à le noyer.
	vec3 fond = textureLod(ecran, SCREEN_UV, 0.0).rgb;
	float transmis = exp(-prof * absorption);
	vec3 eau = mix(trouble, trouble_profond, 1.0 - exp(-prof * 0.8));
	// Les lentilles d'eau : des plaques qui dérivent avec le courant (lentement sur une eau dormante).
	vec2 q = v_monde.xz * 0.9 - flux * defile;
	float plaque = smoothstep(0.58, 0.68, bruit_lisse(q) * 0.7 + bruit_lisse(q * 3.1) * 0.3);
	// De rares bulles, qui naissent et meurent sur place.
	vec2 cb = floor(v_monde.xz * 5.0);
	float bulle = step(0.992, bruit(cb + floor(t * 0.6 + bruit(cb) * 10.0))) * (1.0 - plaque)
		* bulle_ronde(v_monde.xz * 5.0);
	vec3 c = mix(eau * (1.0 - transmis), lentilles * (0.8 + 0.4 * bruit(floor(q * 9.0))), plaque);
	c = mix(c, vec3(0.34, 0.37, 0.24), bulle);
	ALBEDO = cascade ? mix(boue, trouble, stries(UV, t) * 0.6) : c;
	EMISSION = cascade ? vec3(0.0) : fond * transmis * (1.0 - plaque);
	ROUGHNESS = cascade ? 0.7 : mix(0.15, 0.85, plaque);
	SPECULAR = 0.4;
	NORMAL = cascade ? NORMAL : normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALPHA = 1.0;
}
"""

const ACIDE := """
shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform sampler2D ecran : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec3 acide : source_color = vec3(0.35, 1.0, 0.12);
uniform vec3 acide_profond : source_color = vec3(0.05, 0.35, 0.06);
uniform vec3 ecume : source_color = vec3(0.85, 1.0, 0.35);
uniform float luminescence = 1.6;
uniform float absorption = 1.6;
uniform float ampleur = 0.06;
uniform float vitesse_riviere = 1.4;
uniform float vitesse_dormante = 0.2;
uniform float clapot = 0.025;

// Les micro-rides, à l'échelle du personnage (`pente_micro`) : 0 les éteint.
uniform float micro = 0.45;
varying vec3 v_monde;
varying vec2 v_courant;
varying float v_genre;

// %COMMUN%

void vertex() {
	v_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_courant = COLOR.rg * 2.0 - 1.0;
	v_genre = COLOR.b;
	// Le clapot, cascades comprises (voir le premier preset).
	VERTEX.y += clapot * sin(v_monde.z * 0.6 + v_monde.x * 0.9 + TIME * 2.1);
}

void fragment() {
	float t = TIME;
	bool courante = v_genre > 0.25;
	bool cascade = v_genre > 0.75;
	vec2 flux = length(v_courant) > 0.1 ? normalize(v_courant) : vec2(0.6, 0.8);
	float defile = t * (courante ? vitesse_riviere : vitesse_dormante);
	vec3 nw = cascade ? vec3(0.0, 0.0, 1.0) : normale_eau(v_monde.xz, flux, defile, t, ampleur, length(fwidth(v_monde.xz)), micro);
	float prof = max(profondeur_sous(depth_tex, SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, v_monde.y), 0.0);
	vec3 fond = textureLod(ecran, SCREEN_UV + nw.xz * 0.02 * clamp(prof, 0.0, 1.0), 0.0).rgb;
	float transmis = exp(-prof * absorption);
	vec3 teinte = mix(acide, acide_profond, 1.0 - exp(-prof * 0.6));
	// La houle luit plus fort sur ses crêtes.
	float h = hauteur_vagues(v_monde.xz, flux, defile, t);
	float crete = smoothstep(0.4, 1.0, h);
	// Les bulles qui luisent, et l'écume à la rive.
	vec2 cb = floor(v_monde.xz * 6.0);
	float bulle = step(0.985, bruit(cb + floor(t * 1.5 + bruit(cb) * 10.0))) * bulle_ronde(v_monde.xz * 6.0);
	float rive = 1.0 - smoothstep(0.02, 0.15, prof);
	// ⚠ La cascade garde son vert : avec les stries à 0,9 d'écume, elle n'était qu'un aplat jaune (vu à l'image).
	float blanc = cascade ? stries(UV, t) * 0.45 : max(rive * 0.8, bulle);
	ALBEDO = mix(teinte * 0.3, ecume, blanc);
	EMISSION = mix(teinte * luminescence * (0.55 + 0.45 * crete), ecume * luminescence * 1.3, blanc)
		+ fond * transmis * 0.4;
	ROUGHNESS = 0.1;
	SPECULAR = 0.6;
	NORMAL = cascade ? NORMAL : normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALPHA = 1.0;
}
"""

const CAUSTIQUE := """
float caustique(vec2 p, float t, float pied) {
	vec2 q = p + 0.35 * vec2(sin(p.y * 1.3 + t), cos(p.x * 1.1 - t * 0.9));
	mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
	float v = 0.0;
	float w = 0.0;
	float f = 1.0;
	for (int i = 0; i < 3; i++) {
		q = rot * q * 1.62;
		f *= 1.62;
		float a = 1.0 - smoothstep(0.5, 1.3, pied * f);
		v += a * sin(q.x + t * (1.0 + float(i) * 0.27)) * cos(q.y - t * (0.8 + float(i) * 0.19));
		w += a;
	}
	float crete = clamp(1.0 - abs(v / max(w, 1e-3)), 0.0, 1.0);
	float net = 1.0 - smoothstep(0.15, 0.40, pied * f);
	float c = pow(crete, mix(1.5, 4.0, net)) * mix(0.64, 1.0, net);
	return mix(0.44, c, smoothstep(0.0, 0.6, w * 0.3333333));
}
"""

## ⚠ « stylise » garde SES propres bruits (écrits avant le tronc commun) : la retoucher changerait un rendu déjà
## vu et accepté.
const STYLISE := """
shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_always;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

uniform vec3 bleu_clair : source_color = vec3(0.22, 0.53, 0.74);
uniform vec3 bleu_fonce : source_color = vec3(0.06, 0.22, 0.45);
uniform vec3 bleu_frange : source_color = vec3(0.34, 0.61, 0.74);
uniform vec3 couleur_ligne : source_color = vec3(0.96, 0.99, 1.0);
uniform float seuil0 = 0.15;
uniform float seuil1 = 0.72;
uniform float vitesse_riviere = 1.6;
uniform float vitesse_dormante = 0.25;
uniform float force_caustiques = 0.6;
uniform vec3 caustique_couleur : source_color = vec3(0.92, 1.0, 0.96);
uniform float caustique_echelle = 1.15;
uniform float clapot = 0.03;

varying vec3 v_monde;
varying vec2 v_courant;
varying float v_genre;

float bruit(vec2 p) {
	return fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453);
}

float bruit_lisse(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	float a = bruit(i);
	float b = bruit(i + vec2(1.0, 0.0));
	float c = bruit(i + vec2(0.0, 1.0));
	float d = bruit(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// %CAUSTIQUE%

void vertex() {
	v_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_courant = COLOR.rg * 2.0 - 1.0;
	v_genre = COLOR.b;
	// Le clapot : une ondulation légère des nappes, jamais des cascades.
	// Le clapot, cascades comprises (voir le premier preset).
	VERTEX.y += clapot * sin(v_monde.z * 0.55 + v_monde.x * 0.85 + TIME * 1.9);
}

void fragment() {
	float t = TIME;
	// ⚠ TOUT CE QUI DÉRIVE (fwidth, dFdx) EST CALCULÉ HORS DE TOUT BRANCHEMENT PAR PIXEL : une dérivée prise
	// dans un `if` non uniforme lit des voies inactives du quad.
	float dz = texture(depth_tex, SCREEN_UV).x;
	vec4 vue = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
	vec3 pos_fond = (INV_VIEW_MATRIX * vec4(vue.xyz / vue.w, 1.0)).xyz;
	float prof = v_monde.y - pos_fond.y;
	float ps = prof / 1.9;
	float d_rive = abs(ps) / max(fwidth(ps), 1e-5);
	vec2 cp = v_monde.xz * caustique_echelle;
	float pied = max(length(dFdx(cp)), length(dFdy(cp)));

	bool courante = v_genre > 0.25;
	vec2 flux = length(v_courant) > 0.1 ? normalize(v_courant) : vec2(0.6, 0.8);
	float defile = t * (courante ? vitesse_riviere : vitesse_dormante);

	// --- dégradé : grève → bleu clair → bleu profond
	float p = clamp(ps, 0.0, 1.0);
	vec3 c = mix(bleu_frange, bleu_clair, smoothstep(0.0, seuil0, p));
	c = mix(c, bleu_fonce, smoothstep(seuil0 * 0.8, seuil1, p));

	// --- caustiques, dans le peu profond seulement
	float reseau = caustique(cp, t * 0.85, pied);
	float lum = smoothstep(0.30, 0.42, reseau) * 0.42 + smoothstep(0.62, 0.72, reseau) * 0.58;
	c = mix(c, caustique_couleur, lum * (1.0 - smoothstep(0.18, 0.62, p)) * force_caustiques);

	// --- la houle, en marches, qui défile dans le sens du courant
	vec2 n = vec2(-flux.y, flux.x);
	vec2 q = vec2(dot(v_monde.xz, n), (dot(v_monde.xz, flux) - defile) * (courante ? 0.6 : 0.17));
	float houle = 0.52 * (sin(q.x * 1.15 + q.y * 2.3) + 0.65 * sin(q.x * 2.10 - q.y * 1.7 + 1.3)
		+ 0.40 * sin(q.x * 0.55 + q.y * 3.4 - 0.7));
	float marche = floor(clamp(houle * 0.5 + 0.5, 0.0, 0.999) * 3.0) / 2.0;
	float force = courante ? 0.9 : 0.35;
	float ampleur = 0.10 + 0.13 * force;
	float trait = smoothstep(0.86, 1.02, houle);
	float furtif = step(0.40, bruit(vec2(q.x * 0.30, floor(q.y * 0.6))));
	float lignes = trait * furtif * (0.35 + 0.65 * force);

	// --- le liseré de rive et le contact
	float bord_rive = (1.0 - smoothstep(0.7, 2.4, d_rive)) * (1.0 - smoothstep(0.10, 0.28, abs(prof)));
	float autour = (1.0 - smoothstep(0.0, 0.16, max(prof, 0.0))) * (0.35 + 0.5 * force);

	c *= 1.0 - ampleur + ampleur * 2.0 * marche;
	// --- le micro, à l'échelle du personnage (Jordan, 3 octobre 2026) : de courts éclats clairs, étirés en travers
	// du courant, qui défilent ; effacés quand un pixel couvre un éclat (au loin, ils scintilleraient).
	vec2 m = vec2(dot(v_monde.xz, n) * 6.0, (dot(v_monde.xz, flux) - defile * 1.3) * 14.0);
	float pas_m = max(length(dFdx(m)), length(dFdy(m)));
	float eclat = smoothstep(0.80, 0.93, bruit_lisse(m + vec2(t * 0.7, 0.0))) * (1.0 - smoothstep(0.25, 0.6, pas_m));
	c = mix(c, bleu_frange, eclat * 0.45 * (1.0 - 0.5 * p));
	float encre = clamp(max(max(lignes * 0.5, 0.0), max(bord_rive * 0.85, autour)), 0.0, 1.0);
	c = mix(c, couleur_ligne, encre);

	// --- la cascade : une lame rayée de stries qui tombent
	float stries = smoothstep(0.5, 0.85, bruit_lisse(vec2(UV.x * 7.0, UV.y * 0.9 + t * 3.0)));
	float voile = bruit_lisse(vec2(UV.x * 2.0, UV.y * 0.4 + t * 2.2));
	vec3 chute = mix(mix(bleu_clair, bleu_frange, voile), couleur_ligne, stries * 0.85);

	ALBEDO = v_genre > 0.75 ? chute : c;
	ALPHA = 1.0;
}
"""


static func code(preset: String) -> String:
	match preset:
		"transparent":
			return TRANSPARENT.replace("// %COMMUN%", COMMUN)
		"reflechissant":
			return REFLECHISSANT.replace("// %COMMUN%", COMMUN)
		"lave":
			return LAVE.replace("// %COMMUN%", COMMUN)
		"marais":
			return MARAIS.replace("// %COMMUN%", COMMUN)
		"acide":
			return ACIDE.replace("// %COMMUN%", COMMUN)
		_:
			return STYLISE.replace("// %CAUSTIQUE%", CAUSTIQUE)


## LE VOILE DE CHAQUE LIQUIDE, VU DE DEDANS (la caméra sous la nappe, au Play test) : [couleur, densité du brouillard].
## L'eau garde le voile d'avant ; la lave est presque opaque, le marais trouble, l'acide vert et clair.
const VOILES := {
	"lave": [Color("#ff5a10"), 0.9],
	"marais": [Color("#2c3418"), 0.45],
	"acide": [Color("#3fd12a"), 0.25],
}


static var _shaders := {}


## Le matériau d'un preset ; le shader est fabriqué une fois et partagé.
static func materiau(preset: String) -> ShaderMaterial:
	if not _shaders.has(preset):
		var s := Shader.new()
		s.code = code(preset)
		_shaders[preset] = s
	var m := ShaderMaterial.new()
	m.shader = _shaders[preset]
	return m
