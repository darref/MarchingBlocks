// L'EAU — `EauMaillage._poser_les_plats` en C++ : les nappes horizontales sans jonction en T.
//
// ⚠ PARTIE DE L'APPLI. La règle de l'eau partira un jour dans les greffons (liste des greffons à faire, §0) : ce morceau
// passera alors au noyau, en anglais. Aujourd'hui il lit les Dictionary de l'appli.
// ⚠ MÊME ARITHMÉTIQUE QUE LE GDSCRIPT : les coordonnées en double, rangées en float dans les Vector3 ; comparées en
// vingtièmes (`_k`, arrondi au plus proche, moitiés loin de zéro comme `roundi`). `test_natif.gd` compare au bit près.

#include "../godot/mb_natif.h"

#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <algorithm>
#include <cmath>
#include <map>
#include <utility>
#include <vector>

using namespace godot;

namespace {

inline int64_t vingtiemes(double v) {
	return int64_t(std::round(v * 20.0));
}

using Lignes = std::map<std::pair<int64_t, int64_t>, std::vector<int64_t>>;

const std::vector<int64_t> &ligne(const Lignes &l, int64_t h, int64_t k) {
	static const std::vector<int64_t> vide;
	auto it = l.find({ h, k });
	return it == l.end() ? vide : it->second;
}

// `EauMaillage._entre` : les valeurs triées strictement entre a et b.
void entre(const std::vector<int64_t> &l, int64_t a, int64_t b, std::vector<int64_t> &sortie) {
	sortie.clear();
	for (auto it = std::upper_bound(l.begin(), l.end(), a); it != l.end() && *it < b; ++it) {
		sortie.push_back(*it);
	}
}

} // namespace

Array MBNatif::eau_poser_les_plats(const Array &plats, int64_t base0) const {
	PackedVector3Array V, N;
	PackedColorArray C;
	PackedVector2Array UV;
	PackedInt32Array I;
	const Variant k_pts = String("pts"), k_h = String("h"), k_x0 = String("x0"), k_x1 = String("x1"),
				  k_z0 = String("z0"), k_z1 = String("z1"), k_c = String("couleur");
	Lignes sur_z, sur_x;
	const int64_t np = plats.size();
	for (int64_t j = 0; j < np; j++) {
		const Dictionary r = plats[j];
		if (r.has(k_pts)) {
			// Un Array de Vector3 ou un PackedVector3Array : les deux se lisent ici.
			const Variant vp = r[k_pts];
			const PackedVector3Array pts = vp.get_type() == Variant::PACKED_VECTOR3_ARRAY ? PackedVector3Array(vp)
																				  : PackedVector3Array(Array(vp));
			for (int64_t q = 0; q < pts.size(); q++) {
				const Vector3 p = pts[q];
				sur_z[{ vingtiemes(p.y), vingtiemes(p.z) }].push_back(vingtiemes(p.x));
				sur_x[{ vingtiemes(p.y), vingtiemes(p.x) }].push_back(vingtiemes(p.z));
			}
			continue;
		}
		const int64_t hk = vingtiemes(double(r[k_h]));
		for (const Variant *kx : { &k_x0, &k_x1 }) {
			for (const Variant *kz : { &k_z0, &k_z1 }) {
				const double x = r[*kx];
				const double z = r[*kz];
				sur_z[{ hk, vingtiemes(z) }].push_back(vingtiemes(x));
				sur_x[{ hk, vingtiemes(x) }].push_back(vingtiemes(z));
			}
		}
	}
	for (Lignes *l : { &sur_z, &sur_x }) {
		for (auto &e : *l) {
			std::sort(e.second.begin(), e.second.end());
			e.second.erase(std::unique(e.second.begin(), e.second.end()), e.second.end());
		}
	}
	const Vector3 haut(0, 1, 0);
	std::vector<std::pair<int64_t, int64_t>> tour;
	std::vector<int64_t> tmp;
	for (int64_t j = 0; j < np; j++) {
		const Dictionary r = plats[j];
		if (r.has(k_pts)) {
			continue;
		}
		const double h = r[k_h];
		const double fx0 = r[k_x0], fx1 = r[k_x1], fz0 = r[k_z0], fz1 = r[k_z1];
		const Color c = r[k_c];
		const int64_t hk = vingtiemes(h);
		const int64_t x0 = vingtiemes(fx0), x1 = vingtiemes(fx1), z0 = vingtiemes(fz0), z1 = vingtiemes(fz1);
		tour.clear();
		tour.push_back({ x0, z0 });
		entre(ligne(sur_z, hk, z0), x0, x1, tmp);
		for (int64_t x : tmp) {
			tour.push_back({ x, z0 });
		}
		tour.push_back({ x1, z0 });
		entre(ligne(sur_x, hk, x1), z0, z1, tmp);
		for (int64_t z : tmp) {
			tour.push_back({ x1, z });
		}
		tour.push_back({ x1, z1 });
		entre(ligne(sur_z, hk, z1), x0, x1, tmp);
		for (auto it = tmp.rbegin(); it != tmp.rend(); ++it) {
			tour.push_back({ *it, z1 });
		}
		tour.push_back({ x0, z1 });
		entre(ligne(sur_x, hk, x0), z0, z1, tmp);
		for (auto it = tmp.rbegin(); it != tmp.rend(); ++it) {
			tour.push_back({ x0, *it });
		}
		const int32_t base = int32_t(base0 + V.size());
		if (tour.size() == 4) {
			// `EauMaillage._plat` puis `_quad`.
			const Vector3 p[4] = { Vector3(real_t(fx0), real_t(h), real_t(fz0)), Vector3(real_t(fx1), real_t(h), real_t(fz0)),
				Vector3(real_t(fx1), real_t(h), real_t(fz1)), Vector3(real_t(fx0), real_t(h), real_t(fz1)) };
			const Vector2 uv[4] = { Vector2(real_t(fx0), real_t(fz0)), Vector2(real_t(fx1), real_t(fz0)),
				Vector2(real_t(fx1), real_t(fz1)), Vector2(real_t(fx0), real_t(fz1)) };
			for (int k = 0; k < 4; k++) {
				V.push_back(p[k]);
				N.push_back(haut);
				C.push_back(c);
				UV.push_back(uv[k]);
			}
			const Vector3 x = (p[1] - p[0]).cross(p[2] - p[0]);
			if (double(x.dot(haut)) > 0.0) {
				for (int32_t k : { 0, 2, 1, 0, 3, 2 }) {
					I.push_back(base + k);
				}
			} else {
				for (int32_t k : { 0, 1, 2, 0, 2, 3 }) {
					I.push_back(base + k);
				}
			}
			continue;
		}
		const Vector3 centre(real_t((fx0 + fx1) * 0.5), real_t(h), real_t((fz0 + fz1) * 0.5));
		V.push_back(centre);
		N.push_back(haut);
		C.push_back(c);
		UV.push_back(Vector2(centre.x, centre.z));
		for (const auto &t : tour) {
			const Vector3 p(real_t(double(t.first) / 20.0), real_t(h), real_t(double(t.second) / 20.0));
			V.push_back(p);
			N.push_back(haut);
			C.push_back(c);
			UV.push_back(Vector2(p.x, p.z));
		}
		const int32_t n = int32_t(tour.size());
		for (int32_t k = 0; k < n; k++) {
			I.push_back(base);
			I.push_back(base + 1 + k);
			I.push_back(base + 1 + (k + 1) % n);
		}
	}
	Array out;
	out.push_back(V);
	out.push_back(N);
	out.push_back(C);
	out.push_back(UV);
	out.push_back(I);
	return out;
}
