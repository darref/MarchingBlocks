// LES CARTES PBR DÉDUITES — les boucles par texel de `cartes_pbr.gd`, en C++.
//
// ⚠ PARTIE PRIVÉE DE L'APPLI (charte §0, « le cœur C++ ») : elle ne part pas dans les greffons.
// ⚠ MÊME ARITHMÉTIQUE QUE LE GDSCRIPT, À L'OCTET : un nombre de GDScript est un double, un PackedFloat32Array range
// des float, un Vector2 / Vector3 calcule en float (real_t). Chaque conversion est écrite là où le GDScript la fait ;
// `DEV_TOOLS/test_natif.gd` compare les images octet pour octet.

#include "../godot/mb_natif.h"

#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

namespace {

inline double clampd(double v, double lo, double hi) {
	return v < lo ? lo : (v > hi ? hi : v);
}

inline int64_t posmod64(int64_t a, int64_t b) {
	int64_t r = a % b;
	return (r < 0) != (b < 0) && r != 0 ? r + b : r;
}

} // namespace

PackedFloat32Array MBNatif::pbr_luminance(const PackedByteArray &px) const {
	const int64_t n = px.size() / 4;
	PackedFloat32Array lum;
	lum.resize(n);
	const uint8_t *s = px.ptr();
	float *d = lum.ptrw();
	for (int64_t i = 0; i < n; i++) {
		const int64_t j = i * 4;
		d[i] = float((s[j] * 0.299 + s[j + 1] * 0.587 + s[j + 2] * 0.114) / 255.0);
	}
	return lum;
}

PackedFloat32Array MBNatif::pbr_hauteur(const PackedFloat32Array &lum, const PackedFloat32Array &b1,
		const PackedFloat32Array &b2, const PackedFloat32Array &b3, double wf, double wm, double wl, double k) const {
	const int64_t n = lum.size();
	PackedFloat32Array haut;
	ERR_FAIL_COND_V(b1.size() != n || b2.size() != n || b3.size() != n, haut);
	haut.resize(n);
	const float *l = lum.ptr();
	const float *p1 = b1.ptr();
	const float *p2 = b2.ptr();
	const float *p3 = b3.ptr();
	float *d = haut.ptrw();
	for (int64_t i = 0; i < n; i++) {
		const double li = l[i], c1 = p1[i], c2 = p2[i], c3 = p3[i];
		d[i] = float(clampd(0.5 + k * (wf * (li - c1) + wm * (c1 - c2) + wl * (c2 - c3)), 0.0, 1.0));
	}
	return haut;
}

Array MBNatif::pbr_depuis_la_hauteur(const PackedFloat32Array &haut, const PackedFloat32Array &cav1,
		const PackedFloat32Array &cav2, int64_t w, int64_t h, bool boucle, double force, double occ, double base,
		double variation) const {
	Array r;
	const int64_t n = w * h;
	ERR_FAIL_COND_V(haut.size() != n || cav1.size() != n || cav2.size() != n, r);
	PackedByteArray nrm, orm, hb;
	nrm.resize(n * 3);
	orm.resize(n * 3);
	hb.resize(n);
	const float *H = haut.ptr();
	const float *c1 = cav1.ptr();
	const float *c2 = cav2.ptr();
	uint8_t *pn = nrm.ptrw();
	uint8_t *po = orm.ptrw();
	uint8_t *ph = hb.ptrw();
	for (int64_t y = 0; y < h; y++) {
		int64_t ym = y - 1, yp = y + 1;
		if (boucle) {
			ym = posmod64(ym, h);
			yp = posmod64(yp, h);
		} else {
			ym = std::max<int64_t>(ym, 0);
			yp = std::min<int64_t>(yp, h - 1);
		}
		for (int64_t x = 0; x < w; x++) {
			int64_t xm = x - 1, xp = x + 1;
			if (boucle) {
				xm = posmod64(xm, w);
				xp = posmod64(xp, w);
			} else {
				xm = std::max<int64_t>(xm, 0);
				xp = std::min<int64_t>(xp, w - 1);
			}
			const int64_t i = y * w + x;
			const double a00 = H[ym * w + xm], a10 = H[ym * w + x], a20 = H[ym * w + xp];
			const double a01 = H[y * w + xm], a21 = H[y * w + xp];
			const double a02 = H[yp * w + xm], a12 = H[yp * w + x], a22 = H[yp * w + xp];
			const double gx = ((a20 + 2.0 * a21 + a22) - (a00 + 2.0 * a01 + a02)) * 0.125;
			const double gy = ((a02 + 2.0 * a12 + a22) - (a00 + 2.0 * a10 + a20)) * 0.125;
			const Vector3 v = Vector3(real_t(-gx * force), real_t(gy * force), real_t(1.0)).normalized();
			pn[i * 3] = uint8_t(int64_t(clampd(127.5 + double(v.x) * 127.5, 0.0, 255.0)));
			pn[i * 3 + 1] = uint8_t(int64_t(clampd(127.5 + double(v.y) * 127.5, 0.0, 255.0)));
			pn[i * 3 + 2] = uint8_t(int64_t(clampd(127.5 + double(v.z) * 127.5, 0.0, 255.0)));
			const double hi = H[i];
			const double creux = std::max(0.0, double(c1[i]) - hi) + 0.5 * std::max(0.0, double(c2[i]) - hi);
			po[i * 3] = uint8_t(int64_t(clampd(1.0 - occ * creux * 2.0, 0.0, 1.0) * 255.0 + 0.5));
			po[i * 3 + 1] = uint8_t(int64_t(clampd(base + variation * (0.5 - hi) * 2.0, 0.02, 1.0) * 255.0 + 0.5));
			po[i * 3 + 2] = 255;
			ph[i] = uint8_t(int64_t(hi * 255.0 + 0.5));
		}
	}
	r.push_back(nrm);
	r.push_back(orm);
	r.push_back(hb);
	return r;
}

PackedFloat32Array MBNatif::pbr_premultiplier(const PackedByteArray &src, const PackedByteArray &md) const {
	const int64_t n = md.size();
	PackedFloat32Array f;
	ERR_FAIL_COND_V(src.size() != n * 4, f);
	f.resize(n * 4);
	const uint8_t *s = src.ptr();
	const uint8_t *m = md.ptr();
	float *d = f.ptrw();
	for (int64_t i = 0; i < n; i++) {
		const double a = m[i] / 255.0;
		d[i * 4] = float(s[i * 4] / 255.0 * a);
		d[i * 4 + 1] = float(s[i * 4 + 1] / 255.0 * a);
		d[i * 4 + 2] = float(s[i * 4 + 2] / 255.0 * a);
		d[i * 4 + 3] = float(a);
	}
	return f;
}

PackedFloat32Array MBNatif::pbr_combler(const PackedFloat32Array &a_, const PackedFloat32Array &b_) const {
	PackedFloat32Array a = a_;
	ERR_FAIL_COND_V(b_.size() != a.size(), a);
	float *A = a.ptrw();
	const float *B = b_.ptr();
	for (int64_t i = 0; i + 3 < a.size(); i += 4) {
		const double reste = 1.0 - double(A[i + 3]);
		if (reste <= 0.0) {
			continue;
		}
		A[i] = float(double(A[i]) + double(B[i]) * reste);
		A[i + 1] = float(double(A[i + 1]) + double(B[i + 1]) * reste);
		A[i + 2] = float(double(A[i + 2]) + double(B[i + 2]) * reste);
		A[i + 3] = float(double(A[i + 3]) + double(B[i + 3]) * reste);
	}
	return a;
}

PackedByteArray MBNatif::pbr_finir_dilatation(const PackedByteArray &src, const PackedByteArray &md,
		const PackedFloat32Array &p) const {
	PackedByteArray sortie = src;
	const int64_t n = md.size();
	ERR_FAIL_COND_V(src.size() != n * 4 || p.size() != n * 4, sortie);
	uint8_t *o = sortie.ptrw();
	const uint8_t *s = src.ptr();
	const uint8_t *m = md.ptr();
	const float *P = p.ptr();
	for (int64_t i = 0; i < n; i++) {
		if (m[i] >= 255) {
			continue;
		}
		const double a = P[i * 4 + 3];
		if (a <= 0.0) {
			continue;
		}
		const double cov = m[i] / 255.0;
		for (int c = 0; c < 3; c++) {
			const double dilate = double(P[i * 4 + c]) / a;
			const double vers = s[i * 4 + c] / 255.0;
			o[i * 4 + c] = uint8_t(int64_t(clampd(dilate + (vers - dilate) * cov, 0.0, 1.0) * 255.0 + 0.5));
		}
		o[i * 4 + 3] = 255;
	}
	return sortie;
}

namespace {

double distance_au_segment(const Vector2 &p, const Vector2 &a, const Vector2 &b) {
	const Vector2 ab = b - a;
	const double l = ab.length_squared();
	const double t = l <= 0.0 ? 0.0 : clampd(double((p - a).dot(ab)) / l, 0.0, 1.0);
	return p.distance_to(a + ab * real_t(t));
}

} // namespace

PackedByteArray MBNatif::pbr_masque(const PackedVector2Array &triangles, int64_t w, int64_t h) const {
	PackedByteArray d;
	d.resize(w * h);
	uint8_t *o = d.ptrw();
	std::fill(o, o + w * h, uint8_t(0));
	const Vector2 echelle = Vector2(real_t(w), real_t(h));
	const int64_t nt = triangles.size();
	for (int64_t t = 0; t + 2 < nt; t += 3) {
		const Vector2 a = triangles[t] * echelle;
		const Vector2 b = triangles[t + 1] * echelle;
		const Vector2 c = triangles[t + 2] * echelle;
		const int64_t x0 = std::clamp<int64_t>(int64_t(std::floor(std::min(double(a.x), std::min(double(b.x), double(c.x))))) - 1, 0, w - 1);
		const int64_t x1 = std::clamp<int64_t>(int64_t(std::ceil(std::max(double(a.x), std::max(double(b.x), double(c.x))))) + 1, 0, w - 1);
		const int64_t y0 = std::clamp<int64_t>(int64_t(std::floor(std::min(double(a.y), std::min(double(b.y), double(c.y))))) - 1, 0, h - 1);
		const int64_t y1 = std::clamp<int64_t>(int64_t(std::ceil(std::max(double(a.y), std::max(double(b.y), double(c.y))))) + 1, 0, h - 1);
		const double aire = (b - a).cross(c - a);
		if (std::abs(aire) < 1e-9) {
			continue;
		}
		const double s = aire > 0.0 ? 1.0 : (aire < 0.0 ? -1.0 : 0.0);
		for (int64_t y = y0; y <= y1; y++) {
			for (int64_t x = x0; x <= x1; x++) {
				const Vector2 p(real_t(x + 0.5), real_t(y + 0.5));
				const bool dans = double((b - a).cross(p - a)) * s >= 0.0 && double((c - b).cross(p - b)) * s >= 0.0 &&
						double((a - c).cross(p - c)) * s >= 0.0;
				if (dans ||
						std::min(distance_au_segment(p, a, b),
								std::min(distance_au_segment(p, b, c), distance_au_segment(p, c, a))) <= 1.0) {
					o[y * w + x] = 255;
				}
			}
		}
	}
	return d;
}
