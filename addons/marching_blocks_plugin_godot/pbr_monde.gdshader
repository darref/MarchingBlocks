// LE PBR ESPACE MONDE — un set complet par teinte du témoin, projeté en triplanaire.
//
// ⚠ LA COULEUR DE SOMMET CHOISIT LE SET, ET C'EST CE QUI LE FAIT SUIVRE DANS LES TUILES. Le trancheur
// recopie le matériau et les couleurs de sommet de chaque morceau ; un matériau PAR SURFACE, lui, se
// perdrait, puisque le tranchage fond tout en une surface. La teinte la plus PROCHE gagne : une couleur
// passée par des flottants ne revient pas bit pour bit (même règle que `RP.teinte_de`).
//
// ⚠ ESPACE MONDE : les coordonnées de texture viennent de la position dans le MONDE, jamais des UV. Deux
// tuiles voisines, quelle que soit leur rotation dans le GridMap, lisent donc la même texture au même
// endroit : aucune couture là où le trancheur a coupé.
//
// ⚠ LA NORMALE VIENT DE LA GÉOMÉTRIE (dérivées de la position), pas du maillage. Un maillage soudé porte
// une normale MOYENNE par sommet (charte §4) : projeter là-dessus arrondirait les arêtes franches que le
// témoin revendique, et mélangerait les trois projections sur chaque arête.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2DArray albedos : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normales : filter_linear_mipmap_anisotropic, repeat_enable;
// R = occlusion ambiante, G = rugosité, B = hauteur (blanc = haut).
uniform sampler2DArray orh : filter_linear_mipmap_anisotropic, repeat_enable;

// Les six teintes, dans l'ordre des couches. ⚠ Écrites par `pbr_monde.gd` depuis `RP.TEINTES`,
// jamais ici : une seconde copie des couleurs mentirait au premier réglage.
uniform vec3 teintes[6];

// Répétitions de la texture par unité de monde. 0,5 : un motif couvre deux cases.
uniform float echelle = 0.5;
// La profondeur du relief simulé, en unités de MONDE — un quart de la marge que l'amincissement laisse.
uniform float profondeur = 0.06;
uniform int pas_pom = 16;
uniform float force_normale : hint_range(0.0, 2.0) = 1.0;
// Plus c'est grand, plus la transition entre deux projections est courte.
uniform float nettete = 6.0;

varying vec3 p_monde;

void vertex() {
	p_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

int couche_de(vec3 c) {
	int meilleure = 0;
	float ecart = 1e9;
	for (int i = 0; i < 6; i++) {
		vec3 d = c - teintes[i];
		float e = dot(d, d);
		if (e < ecart) {
			ecart = e;
			meilleure = i;
		}
	}
	return meilleure;
}

// Le POM d'UN plan de projection. `a` et `b` sont les directions du monde le long desquelles u et v
// croissent, `nn` la normale sortante du plan. ⚠ Le décalage est calculé dans CES axes-là : il est donc
// juste même quand la projection est vue en miroir (face tournée vers −X, −Y ou −Z).
vec2 pom(vec2 uv0, vec3 v_monde, vec3 a, vec3 b, vec3 nn, float c, vec2 gx, vec2 gy) {
	vec3 vt = vec3(dot(v_monde, a), dot(v_monde, b), dot(v_monde, nn));
	float n = float(pas_pom);
	float d_couche = 1.0 / n;
	vec2 delta = vt.xy / max(vt.z, 0.08) * (profondeur * echelle) / n;
	vec2 uv = uv0;
	float prof = 0.0;
	float h = 1.0 - textureGrad(orh, vec3(uv, c), gx, gy).b;
	vec2 uv_avant = uv;
	float h_avant = h;
	float prof_avant = 0.0;
	for (int i = 0; i < pas_pom; i++) {
		if (prof >= h) {
			break;
		}
		uv_avant = uv;
		h_avant = h;
		prof_avant = prof;
		uv -= delta;
		prof += d_couche;
		h = 1.0 - textureGrad(orh, vec3(uv, c), gx, gy).b;
	}
	// Interpolation entre les deux dernières couches : sans elle, le relief se lit en marches.
	float apres = h - prof;
	float avant = h_avant - prof_avant;
	float t = apres / min(apres - avant, -1e-4);
	return mix(uv, uv_avant, clamp(t, 0.0, 1.0));
}

void fragment() {
	vec3 n_geo = normalize(cross(dFdx(p_monde), dFdy(p_monde)));
	vec3 vers_camera = normalize(CAMERA_POSITION_WORLD - p_monde);
	// ⚠ Le signe du produit vectoriel dépend du sens de l'écran : on le règle sur la caméra, qui voit
	// toujours la face avant d'un maillage opaque rendu en `cull_back`.
	if (dot(n_geo, vers_camera) < 0.0) {
		n_geo = -n_geo;
	}
	float c = float(couche_de(COLOR.rgb));

	vec3 w = pow(abs(n_geo), vec3(nettete));
	w /= (w.x + w.y + w.z);

	// Les trois plans : (a, b) les axes de u et v, choisis pour que « haut » dans l'image soit +Y sur
	// les parois ; `nn` suit le côté de la face.
	vec3 ax[3] = vec3[3](vec3(0.0, 0.0, 1.0), vec3(1.0, 0.0, 0.0), vec3(1.0, 0.0, 0.0));
	vec3 bx[3] = vec3[3](vec3(0.0, -1.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.0, -1.0, 0.0));
	vec3 nx[3] = vec3[3](vec3(sign(n_geo.x), 0.0, 0.0), vec3(0.0, sign(n_geo.y), 0.0),
		vec3(0.0, 0.0, sign(n_geo.z)));
	float wx[3] = float[3](w.x, w.y, w.z);

	vec3 albedo = vec3(0.0);
	vec3 normale = vec3(0.0);
	float ao = 0.0;
	float rugosite = 0.0;
	for (int k = 0; k < 3; k++) {
		vec2 uv0 = vec2(dot(p_monde, ax[k]), dot(p_monde, bx[k])) * echelle;
		// ⚠ Les dérivées sont prises AVANT toute branche : dans une boucle ou un `if`, elles ne sont
		// plus définies, et `textureGrad` les réemploie partout.
		vec2 gx = dFdx(uv0);
		vec2 gy = dFdy(uv0);
		if (wx[k] < 0.01) {
			continue;
		}
		vec2 uv = pas_pom > 0 ? pom(uv0, vers_camera, ax[k], bx[k], nx[k], c, gx, gy) : uv0;
		vec3 coord = vec3(uv, c);
		albedo += textureGrad(albedos, coord, gx, gy).rgb * wx[k];
		vec4 m = textureGrad(orh, coord, gx, gy);
		ao += m.r * wx[k];
		rugosite += m.g * wx[k];
		// ⚠ RGTC : deux canaux seulement, Z se reconstruit. Convention OpenGL : le vert monte vers le
		// HAUT de l'image, c'est-à-dire vers −b, puisque v croît vers le bas de l'image.
		vec2 xy = (textureGrad(normales, coord, gx, gy).rg * 2.0 - 1.0) * force_normale;
		float z = sqrt(max(0.0, 1.0 - dot(xy, xy)));
		normale += (ax[k] * xy.x - bx[k] * xy.y + nx[k] * z) * wx[k];
	}

	ALBEDO = albedo;
	ROUGHNESS = rugosite;
	METALLIC = 0.0;
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(normale), 0.0)).xyz);
}
