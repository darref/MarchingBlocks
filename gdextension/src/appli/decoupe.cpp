// LA DÉCOUPE — la boucle par triangle de `Decoupe.trancher` (Sutherland-Hodgman), en C++.
//
// ⚠ PARTIE PRIVÉE DE L'APPLI : c'est le trancheur, ce qui se vend (charte §0) ; jamais dans les greffons.
// ⚠ MÊME ARITHMÉTIQUE QUE LE GDSCRIPT : les distances aux plans en double, les interpolations dans les types de Godot
// (Vector3, Vector2 et Color en float). `DEV_TOOLS/test_natif.gd` compare les tableaux au bit près.

#include "../godot/mb_natif.h"

#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <algorithm>
#include <cmath>
#include <vector>

using namespace godot;

namespace {

constexpr double EPS = 0.000001;

struct Sommet {
	Vector3 p;
	Vector3 n;
	Vector2 uv;
	Color c;
};

inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}

// `Decoupe._peut_toucher` : CONSERVATEUR, « non » est certain.
bool peut_toucher(const Vector3 &a, const Vector3 &b, const Vector3 &c, const Vector3 &debut, const Vector3 &fin) {
	for (int axe = 0; axe < 3; axe++) {
		const double mn = std::min(double(a[axe]), std::min(double(b[axe]), double(c[axe])));
		const double mx = std::max(double(a[axe]), std::max(double(b[axe]), double(c[axe])));
		if (mn > double(fin[axe]) + EPS) {
			return false;
		}
		if (mx < double(debut[axe]) - EPS) {
			return false;
		}
	}
	return true;
}

// `Decoupe._plat`.
bool plat(const Vector3 &a, const Vector3 &b, const Vector3 &c) {
	const double plus_long = std::max(double((b - a).length_squared()),
			std::max(double((c - b).length_squared()), double((a - c).length_squared())));
	return double((b - a).cross(c - a).length()) <= 1e-6 * plus_long;
}

// `Decoupe._entre`.
Sommet entre(const Sommet &a, const Sommet &b, double t) {
	const real_t f = real_t(clampd(t, 0.0, 1.0));
	Sommet s;
	s.p = a.p.lerp(b.p, f);
	s.n = a.n.lerp(b.n, f).normalized();
	s.uv = a.uv.lerp(b.uv, f);
	s.c = a.c.lerp(b.c, float(f));
	return s;
}

// `Decoupe._couper_par_plan`.
void couper_par_plan(const std::vector<Sommet> &polygone, std::vector<Sommet> &sortie, int axe, double seuil,
		bool garder_au_dessus) {
	sortie.clear();
	const size_t n = polygone.size();
	for (size_t i = 0; i < n; i++) {
		const Sommet &a = polygone[i];
		const Sommet &b = polygone[(i + 1) % n];
		const double da = garder_au_dessus ? double(a.p[axe]) - seuil : seuil - double(a.p[axe]);
		const double db = garder_au_dessus ? double(b.p[axe]) - seuil : seuil - double(b.p[axe]);
		const bool a_dedans = da >= -EPS;
		const bool b_dedans = db >= -EPS;
		if (a_dedans) {
			sortie.push_back(a);
		}
		if (a_dedans != b_dedans && std::abs(da - db) > EPS) {
			sortie.push_back(entre(a, b, da / (da - db)));
		}
	}
}

} // namespace

Array MBNatif::decouper(const PackedVector3Array &sommets, const PackedVector3Array &normales,
		const PackedVector2Array &uvs, const PackedColorArray &couleurs, const PackedInt32Array &indices_,
		const Vector3 &debut, const Vector3 &fin) const {
	PackedVector3Array v_out, n_out;
	PackedVector2Array uv_out;
	PackedColorArray c_out;
	const int64_t nv = sommets.size();
	PackedInt32Array indices = indices_;
	if (indices.is_empty()) {
		indices.resize(nv);
		for (int64_t i = 0; i < nv; i++) {
			indices.set(i, int32_t(i));
		}
	}
	const Vector3 *S = sommets.ptr();
	const int32_t *I = indices.ptr();
	const int64_t ni = indices.size();
	std::vector<Sommet> poly, tampon;
	poly.reserve(16);
	tampon.reserve(16);
	for (int64_t t = 0; t + 2 < ni; t += 3) {
		if (!peut_toucher(S[I[t]], S[I[t + 1]], S[I[t + 2]], debut, fin)) {
			continue;
		}
		poly.clear();
		for (int k = 0; k < 3; k++) {
			const int64_t i = I[t + k];
			Sommet s;
			s.p = S[i];
			s.n = normales.size() > i ? normales[i] : Vector3(0, 1, 0);
			s.uv = uvs.size() > i ? uvs[i] : Vector2();
			s.c = couleurs.size() > i ? couleurs[i] : Color(1, 1, 1, 1);
			poly.push_back(s);
		}
		// `Decoupe._couper_polygone` : les six demi-espaces ; un polygone vidé sort tôt.
		for (int axe = 0; axe < 3 && !poly.empty(); axe++) {
			couper_par_plan(poly, tampon, axe, double(debut[axe]), true);
			poly.swap(tampon);
			if (poly.empty()) {
				break;
			}
			couper_par_plan(poly, tampon, axe, double(fin[axe]), false);
			poly.swap(tampon);
		}
		for (size_t k = 1; k + 1 < poly.size(); k++) {
			if (plat(poly[0].p, poly[k].p, poly[k + 1].p)) {
				continue;
			}
			for (const Sommet *s : { &poly[0], &poly[k], &poly[k + 1] }) {
				v_out.push_back(s->p);
				n_out.push_back(s->n);
				uv_out.push_back(s->uv);
				c_out.push_back(s->c);
			}
		}
	}
	Array r;
	r.push_back(v_out);
	r.push_back(n_out);
	r.push_back(uv_out);
	r.push_back(c_out);
	return r;
}
