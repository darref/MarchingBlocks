#include "mb_natif.h"

#include "../noyau/ocean.h"
#include "../noyau/placement.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/vector3i.hpp>

#include <climits>
#include <memory>

using namespace godot;

namespace {

// Les cases d'un Dictionary de Godot, lues telles quelles (pour les petits lots de sommets : recopier un monde
// de 700 000 cases pour en relire quarante coûterait plus que les quarante lectures).
struct CasesDict {
	const Dictionary *d;
	bool has(int32_t x, int32_t y, int32_t z) const { return d->has(Vector3i(x, y, z)); }
	int32_t get(int32_t x, int32_t y, int32_t z, int32_t manque) const {
		const Variant v = d->get(Vector3i(x, y, z), Variant());
		return v.get_type() == Variant::NIL ? manque : int32_t(int64_t(v));
	}
};

// Recopie un Dictionary {Vector3i: valeur} dans une table du cœur. `valeurs` : garder la valeur (le rang d'une
// couche dans l'union), sinon 0. Rend faux si une case sort de la portée du cœur (±1 048 575).
bool charger(const Dictionary &d, mbcore::CellMap &m, bool valeurs, int32_t *plafond = nullptr,
		int32_t *y_bas = nullptr) {
	m.clear();
	m.reserve(size_t(d.size()));
	const Array cles = d.keys();
	const Array vals = valeurs ? d.values() : Array();
	int32_t haut = INT32_MIN, bas = INT32_MAX;
	const int64_t n = cles.size();
	for (int64_t i = 0; i < n; i++) {
		const Vector3i c = cles[i];
		if (!mbcore::in_range(c.x) || !mbcore::in_range(c.y) || !mbcore::in_range(c.z)) {
			return false;
		}
		m.set(mbcore::pack(c.x, c.y, c.z), valeurs ? int32_t(int64_t(vals[i])) : 0);
		haut = c.y > haut ? c.y : haut;
		bas = c.y < bas ? c.y : bas;
	}
	if (plafond != nullptr) {
		*plafond = haut;
	}
	if (y_bas != nullptr) {
		*y_bas = bas;
	}
	return true;
}

inline Vector3i deballer(uint64_t k) {
	return Vector3i(int32_t((k >> 42) & mbcore::AXIS_MASK) - mbcore::AXIS_OFFSET,
			int32_t((k >> 21) & mbcore::AXIS_MASK) - mbcore::AXIS_OFFSET,
			int32_t(k & mbcore::AXIS_MASK) - mbcore::AXIS_OFFSET);
}

// Les huit sommets d'une case (`MB.sommets_de`), dans l'ordre des coins.
template <class F>
inline void sommets_de(int32_t x, int32_t y, int32_t z, F &&f) {
	for (int t = 0; t < 8; t++) {
		f(x - mbcore::CORNERS[t][0], y - mbcore::CORNERS[t][1], z - mbcore::CORNERS[t][2]);
	}
}

} // namespace

MBNatif::MBNatif() {
	_vide.make_read_only();
	_k_sommet = String("sommet");
	_k_nom = String("nom");
	_k_cle = String("cle");
	_k_orientation = String("orientation");
	_k_dehors = String("dehors");
	_k_tuile = String("tuile");
	_k_couche = String("couche");
}

String MBNatif::version() const {
	return "mb_natif 1";
}

void MBNatif::definir_regle(const Array &table) {
	ERR_FAIL_COND_MSG(table.size() != 256, "MBNatif : la table doit porter les 256 configurations.");
	for (int b = 0; b < 256; b++) {
		const Dictionary r = table[b];
		_lignes[b].surface = bool(r.get("surface", false));
		_lignes[b].exterieur = bool(r.get("exterieur", false));
		_lignes[b].orientation = int32_t(int64_t(r.get("orientation", 0)));
		_lignes[b].nom = String(r.get("nom", ""));
		_lignes[b].nom_dehors = String(r.get("nom_dehors", ""));
	}
	_pret = true;
}

Dictionary MBNatif::routes() const {
	Dictionary r;
	r["dict"] = _routes_dict;
	r["copie"] = _routes_copie;
	return r;
}

bool MBNatif::est_pret() const {
	return _pret;
}

void MBNatif::_preparer_lot(Lot &lot, const Dictionary &index, const Dictionary &poids, bool avec_variantes) const {
	for (int b = 0; b < 256; b++) {
		for (int dehors = 0; dehors < 2; dehors++) {
			Cle &c = lot.cles[(b << 1) | dehors];
			c.nom = dehors ? _lignes[b].nom_dehors : _lignes[b].nom;
			c.presente = _lignes[b].surface && index.has(c.nom);
			c.tuiles.clear();
			c.ids.clear();
			c.poids.clear();
			c.n = 0;
			if (!c.presente) {
				continue;
			}
			c.tuiles.push_back(c.nom);
			c.ids.push_back(int32_t(int64_t(index[c.nom])));
			if (!avec_variantes) {
				continue;
			}
			// `MB.nombre_de_variantes` : var1, var2… tant que l'index les a (9 au plus).
			while (c.n < 9) {
				const String v = c.nom + "_var" + String::num_int64(c.n + 1);
				if (!index.has(v)) {
					break;
				}
				c.n++;
				c.tuiles.push_back(v);
				c.ids.push_back(int32_t(int64_t(index[v])));
			}
			const Array w = poids.get(c.nom, Array());
			for (int k = 0; k <= c.n; k++) {
				int64_t x = k < w.size() ? int64_t(w[k]) : 1;
				c.poids.push_back(x < 0 ? 0 : x);
			}
		}
	}
}

template <class Cases>
Variant MBNatif::_decision(const Cases &cases, int32_t x, int32_t y, int32_t z, int64_t rang, int32_t plafond,
		const mbcore::CellMap *hauts, const Lot &lot, const Dictionary &choix, bool avec_tuile) const {
	// `massif_peint._decision` : null quand le sommet n'est pas à cette couche (ou sans case).
	if (rang >= 0) {
		if (mbcore::vertex_layer(cases, x, y, z) != rang) {
			return Variant();
		}
	}
	const int b = mbcore::vertex_bits(cases, x, y, z);
	if (rang < 0 && b == 0) {
		return Variant();
	}
	const Ligne &l = _lignes[b];
	if (!l.surface) {
		return _vide;
	}
	// `MB.pose_du_sommet`.
	const Cle *cle = nullptr;
	bool dehors = false;
	if (l.exterieur && lot.cles[(b << 1) | 1].presente && mbcore::under_sky(cases, x, y, z, plafond, hauts)) {
		cle = &lot.cles[(b << 1) | 1];
		dehors = true;
	}
	if (cle == nullptr && lot.cles[b << 1].presente) {
		cle = &lot.cles[b << 1];
	}
	const Vector3i s(x, y, z);
	Dictionary d;
	d[_k_sommet] = s;
	d[_k_nom] = l.nom;
	d[_k_cle] = cle != nullptr ? cle->nom : String();
	d[_k_orientation] = l.orientation;
	d[_k_dehors] = dehors;
	if (avec_tuile && cle != nullptr) {
		// `MB.tuile_du_sommet` : le choix posé, sinon le tirage pesé.
		int k = 0;
		if (cle->n > 0) {
			bool choisi = false;
			if (!choix.is_empty() && choix.has(s)) {
				const int64_t c = int64_t(choix[s]);
				if (c >= 0 && c <= cle->n) {
					k = int(c);
					choisi = true;
				}
			}
			if (!choisi) {
				k = mbcore::pick_variant(mbcore::vertex_hash(x, y, z), cle->poids);
			}
		}
		d[_k_tuile] = cle->tuiles[size_t(k)];
	}
	return d;
}

namespace {

// Ce que `_poser` compte et pose. `sens` : +1 poser, −1 retirer.
struct Poseur {
	GridMap *rendu;
	GridMap *fautes;
	int32_t id_faute;
	const Dictionary *index;
	int64_t pieces = 0, nb_fautes = 0, dehors = 0, decisions = 0;
	Variant k_sommet, k_cle, k_tuile, k_orientation, k_dehors;

	void poser(const Dictionary &d, int sens) {
		const Vector3i s = d[k_sommet];
		decisions += sens;
		const String cle = d[k_cle];
		if (cle.is_empty()) {
			nb_fautes += sens;
			if (id_faute >= 0 && fautes != nullptr) {
				fautes->set_cell_item(s, sens > 0 ? id_faute : GridMap::INVALID_CELL_ITEM);
			}
			return;
		}
		pieces += sens;
		if (bool(d[k_dehors])) {
			dehors += sens;
		}
		if (rendu == nullptr) {
			return;
		}
		if (sens > 0) {
			const Variant t = d.get(k_tuile, cle);
			rendu->set_cell_item(s, int32_t(int64_t((*index)[t])), int32_t(int64_t(d[k_orientation])));
		} else {
			rendu->set_cell_item(s, GridMap::INVALID_CELL_ITEM);
		}
	}
};

} // namespace

Array MBNatif::poses(const Dictionary &pleines, const Dictionary &cles) {
	Array sortie;
	ERR_FAIL_COND_V(!_pret, sortie);
	mbcore::CellMap occ;
	int32_t plafond = INT32_MIN;
	if (!charger(pleines, occ, false, &plafond)) {
		ERR_FAIL_V_MSG(sortie, "MBNatif : une case sort de la portée du cœur.");
	}
	mbcore::CellMap hauts;
	mbcore::column_tops(occ, hauts);
	std::unique_ptr<Lot> lot(new Lot());
	_preparer_lot(*lot, cles, Dictionary(), false);
	const mbcore::MapCells cases{ &occ };
	mbcore::CellMap vus;
	vus.reserve(occ.size() * 2);
	const Array liste = pleines.keys();
	const Dictionary choix;
	for (int64_t i = 0; i < liste.size(); i++) {
		const Vector3i c = liste[i];
		sommets_de(c.x, c.y, c.z, [&](int32_t x, int32_t y, int32_t z) {
			if (!vus.set(mbcore::pack(x, y, z), 0)) {
				return;
			}
			const Variant d = _decision(cases, x, y, z, -1, plafond, &hauts, *lot, choix, false);
			if (d.get_type() == Variant::DICTIONARY && !Dictionary(d).is_empty()) {
				sortie.push_back(d);
			}
		});
	}
	return sortie;
}

Array MBNatif::poses_en_couches(const Dictionary &uni, const Array &cles_par_couche) {
	Array sortie;
	ERR_FAIL_COND_V(!_pret, sortie);
	mbcore::CellMap occ;
	int32_t plafond = INT32_MIN;
	if (!charger(uni, occ, true, &plafond)) {
		ERR_FAIL_V_MSG(sortie, "MBNatif : une case sort de la portée du cœur.");
	}
	std::vector<std::unique_ptr<Lot>> lots;
	for (int64_t r = 0; r < cles_par_couche.size(); r++) {
		lots.emplace_back(new Lot());
		_preparer_lot(*lots.back(), cles_par_couche[r], Dictionary(), false);
	}
	const mbcore::MapCells cases{ &occ };
	mbcore::CellMap vus;
	vus.reserve(occ.size() * 2);
	const Array liste = uni.keys();
	const Dictionary choix;
	for (int64_t i = 0; i < liste.size(); i++) {
		const Vector3i c = liste[i];
		sommets_de(c.x, c.y, c.z, [&](int32_t x, int32_t y, int32_t z) {
			if (!vus.set(mbcore::pack(x, y, z), 0)) {
				return;
			}
			const int32_t rang = mbcore::vertex_layer(cases, x, y, z);
			ERR_FAIL_COND(rang < 0 || rang >= int32_t(lots.size()));
			// ⚠ `MB.poses_en_couches` sonde le ciel en BALAYANT les colonnes (pas de table des hauts).
			const Variant v = _decision(cases, x, y, z, -1, plafond, nullptr, *lots[size_t(rang)], choix, false);
			if (v.get_type() == Variant::DICTIONARY && !Dictionary(v).is_empty()) {
				Dictionary d = Dictionary(v).duplicate();
				d[_k_couche] = rang;
				sortie.push_back(d);
			}
		});
	}
	return sortie;
}

int64_t MBNatif::plafond_de(const Dictionary &pleines) const {
	int64_t haut = INT32_MIN;
	const Array cles = pleines.keys();
	for (int64_t i = 0; i < cles.size(); i++) {
		const Vector3i c = cles[i];
		haut = c.y > haut ? c.y : haut;
	}
	return haut;
}

Dictionary MBNatif::hauts_des_colonnes(const Dictionary &pleines) const {
	// Même ordre d'insertion que le GDScript : la première case de chaque colonne crée l'entrée.
	Dictionary hauts;
	const Array cles = pleines.keys();
	for (int64_t i = 0; i < cles.size(); i++) {
		const Vector3i c = cles[i];
		const Vector2i k(c.x, c.z);
		const Variant v = hauts.get(k, Variant());
		if (v.get_type() == Variant::NIL || int64_t(v) < c.y) {
			hauts[k] = c.y;
		}
	}
	return hauts;
}

int64_t MBNatif::contacts_par_arete(const Dictionary &pleines, int64_t cote) const {
	mbcore::CellMap occ;
	if (!charger(pleines, occ, false)) {
		ERR_FAIL_V_MSG(0, "MBNatif : une case sort de la portée du cœur.");
	}
	static const int32_t AXES[3][2] = { { 0, 1 }, { 0, 2 }, { 1, 2 } };
	mbcore::CellMap vus[3];
	int64_t combien = 0;
	occ.for_each([&](uint64_t cle, int32_t) {
		const Vector3i cc = deballer(cle);
		for (int k = 0; k < 3; k++) {
			int32_t e1[3] = { 0, 0, 0 }, e2[3] = { 0, 0, 0 };
			e1[AXES[k][0]] = 1;
			e2[AXES[k][1]] = 1;
			const int32_t coins[4][3] = {
				{ 0, 0, 0 },
				{ -e1[0], -e1[1], -e1[2] },
				{ -e2[0], -e2[1], -e2[2] },
				{ -e1[0] - e2[0], -e1[1] - e2[1], -e1[2] - e2[2] },
			};
			for (const auto &co : coins) {
				const int32_t px = cc.x + co[0], py = cc.y + co[1], pz = cc.z + co[2];
				const int32_t qx = px + e1[0] + e2[0], qy = py + e1[1] + e2[1], qz = pz + e1[2] + e2[2];
				if (cote > 0 && (px < 0 || py < 0 || pz < 0 || qx > cote - 1 || qy > cote - 1 || qz > cote - 1)) {
					continue;
				}
				if (!vus[k].set(mbcore::pack(px, py, pz), 0)) {
					continue;
				}
				const bool a = occ.has(mbcore::pack(px, py, pz));
				const bool b = occ.has(mbcore::pack(px + e1[0], py + e1[1], pz + e1[2]));
				const bool d = occ.has(mbcore::pack(px + e2[0], py + e2[1], pz + e2[2]));
				const bool e = occ.has(mbcore::pack(qx, qy, qz));
				if ((a && e && !b && !d) || (b && d && !a && !e)) {
					combien++;
				}
			}
		}
	});
	return combien;
}

Array MBNatif::compter_cases(const Array &cases) const {
	// `massif_peint.reconstruire` : {case: true}, {Vector2i(x, z): combien}, {y: combien}, dans l'ordre des cases.
	Dictionary miennes, colonnes, etages;
	for (int64_t i = 0; i < cases.size(); i++) {
		const Vector3i c = cases[i];
		miennes[c] = true;
		const Vector2i k(c.x, c.z);
		colonnes[k] = int64_t(colonnes.get(k, 0)) + 1;
		etages[c.y] = int64_t(etages.get(c.y, 0)) + 1;
	}
	Array r;
	r.push_back(miennes);
	r.push_back(colonnes);
	r.push_back(etages);
	return r;
}

int64_t MBNatif::empreinte_des_cases(const Array &cases) const {
	// `massif_peint._empreinte_des_cases`, en entiers de 64 bits comme le GDScript.
	int64_t empreinte = 0;
	const int64_t n = cases.size();
	for (int64_t i = 0; i < n; i++) {
		const Vector3i p = cases[i];
		empreinte = (empreinte * 31 + int64_t(p.x) * 73856093 + int64_t(p.y) * 19349663 + int64_t(p.z) * 83492791) &
				0x7FFFFFFF;
	}
	return empreinte * 31 + n;
}

Dictionary MBNatif::reconstruire(const Dictionary &pleines, const Dictionary &miennes, int64_t rang,
		const Dictionary &index, const Dictionary &poids, const Dictionary &choix, GridMap *rendu, GridMap *fautes,
		int64_t id_faute) {
	Dictionary r;
	ERR_FAIL_COND_V(!_pret, r);
	mbcore::CellMap occ;
	int32_t plafond = INT32_MIN, y_bas = INT32_MAX;
	if (!charger(pleines, occ, rang >= 0, &plafond, &y_bas)) {
		ERR_FAIL_V_MSG(r, "MBNatif : une case sort de la portée du cœur.");
	}
	mbcore::CellMap hauts;
	mbcore::column_tops(occ, hauts);
	std::unique_ptr<Lot> lot(new Lot());
	_preparer_lot(*lot, index, poids, true);
	const mbcore::MapCells cases{ &occ };
	Poseur p{ rendu, fautes, int32_t(id_faute), &index };
	p.k_sommet = _k_sommet;
	p.k_cle = _k_cle;
	p.k_tuile = _k_tuile;
	p.k_orientation = _k_orientation;
	p.k_dehors = _k_dehors;

	Dictionary etat;
	mbcore::CellMap vus;
	vus.reserve(occ.size() * 2);
	const Array liste = (rang < 0 ? pleines : miennes).keys();
	if (rang < 0) {
		// Comme `MB.poses` puis la boucle des muets : d'abord les poses, dans l'ordre, puis les {} manquants.
		std::vector<Vector3i> muets;
		for (int64_t i = 0; i < liste.size(); i++) {
			const Vector3i c = liste[i];
			sommets_de(c.x, c.y, c.z, [&](int32_t x, int32_t y, int32_t z) {
				if (!vus.set(mbcore::pack(x, y, z), 0)) {
					return;
				}
				const Variant d = _decision(cases, x, y, z, -1, plafond, &hauts, *lot, choix, true);
				if (d.get_type() == Variant::DICTIONARY && !Dictionary(d).is_empty()) {
					etat[Vector3i(x, y, z)] = d;
					p.poser(d, 1);
				} else {
					muets.push_back(Vector3i(x, y, z));
				}
			});
		}
		for (const Vector3i &s : muets) {
			etat[s] = _vide;
		}
	} else {
		for (int64_t i = 0; i < liste.size(); i++) {
			const Vector3i c = liste[i];
			sommets_de(c.x, c.y, c.z, [&](int32_t x, int32_t y, int32_t z) {
				if (!vus.set(mbcore::pack(x, y, z), 0)) {
					return;
				}
				const Variant d = _decision(cases, x, y, z, rang, plafond, &hauts, *lot, choix, true);
				if (d.get_type() == Variant::NIL) {
					return;
				}
				etat[Vector3i(x, y, z)] = d;
				if (!Dictionary(d).is_empty()) {
					p.poser(d, 1);
				}
			});
		}
	}
	r["etat"] = etat;
	r["pieces"] = p.pieces;
	r["fautes"] = p.nb_fautes;
	r["dehors"] = p.dehors;
	r["decisions"] = p.decisions;
	r["touches"] = etat.size();
	r["plafond"] = plafond;
	r["y_bas"] = y_bas;
	return r;
}

void MBNatif::refaire(const Dictionary &pleines, const Array &sommets, Dictionary etat, int64_t rang,
		const Dictionary &index, const Dictionary &poids, const Dictionary &choix, int64_t plafond, GridMap *rendu,
		GridMap *fautes, int64_t id_faute, Dictionary compte) {
	ERR_FAIL_COND(!_pret);
	std::unique_ptr<Lot> lot(new Lot());
	_preparer_lot(*lot, index, poids, true);
	Poseur p{ rendu, fautes, int32_t(id_faute), &index };
	p.k_sommet = _k_sommet;
	p.k_cle = _k_cle;
	p.k_tuile = _k_tuile;
	p.k_orientation = _k_orientation;
	p.k_dehors = _k_dehors;
	int64_t touches = 0;

	auto passer = [&](auto &cases, const mbcore::CellMap *hauts, int32_t plaf) {
		for (int64_t i = 0; i < sommets.size(); i++) {
			const Vector3i k = sommets[i];
			// `massif_peint._refaire`.
			const Variant avant = etat.get(k, Variant());
			const Variant apres = _decision(cases, k.x, k.y, k.z, rang, plaf, hauts, *lot, choix, true);
			if (avant == apres) {
				continue;
			}
			if (avant.get_type() != Variant::NIL) {
				touches -= 1;
				const Dictionary da = avant;
				if (!da.is_empty()) {
					p.poser(da, -1);
				}
			}
			if (apres.get_type() == Variant::NIL) {
				etat.erase(k);
			} else {
				etat[k] = apres;
				touches += 1;
				const Dictionary dp = apres;
				if (!dp.is_empty()) {
					p.poser(dp, 1);
				}
			}
		}
	};

	// Peu de sommets dans un grand monde : on lit le Dictionary tel quel ; sinon on le recopie (avec ses hauts).
	if (int64_t(sommets.size()) * 64 < pleines.size()) {
		_routes_dict++;
		const CasesDict cases{ &pleines };
		passer(cases, nullptr, int32_t(plafond));
	} else {
		_routes_copie++;
		mbcore::CellMap occ;
		int32_t haut = INT32_MIN;
		if (!charger(pleines, occ, rang >= 0, &haut)) {
			ERR_FAIL_MSG("MBNatif : une case sort de la portée du cœur.");
		}
		mbcore::CellMap hauts;
		mbcore::column_tops(occ, hauts);
		const mbcore::MapCells cases{ &occ };
		passer(cases, &hauts, int32_t(plafond));
	}
	compte["pieces"] = int64_t(compte.get("pieces", 0)) + p.pieces;
	compte["fautes"] = int64_t(compte.get("fautes", 0)) + p.nb_fautes;
	compte["dehors"] = int64_t(compte.get("dehors", 0)) + p.dehors;
	compte["decisions"] = int64_t(compte.get("decisions", 0)) + p.decisions;
	compte["touches"] = int64_t(compte.get("touches", 0)) + touches;
}

Dictionary MBNatif::boite(const Dictionary &occupees) const {
	Dictionary r;
	if (occupees.is_empty()) {
		return r;
	}
	Vector3i lo(INT32_MAX, INT32_MAX, INT32_MAX), hi(-INT32_MAX, -INT32_MAX, -INT32_MAX);
	const Array cles = occupees.keys();
	for (int64_t i = 0; i < cles.size(); i++) {
		const Vector3i c = cles[i];
		lo = Vector3i(MIN(lo.x, c.x), MIN(lo.y, c.y), MIN(lo.z, c.z));
		hi = Vector3i(MAX(hi.x, c.x), MAX(hi.y, c.y), MAX(hi.z, c.z));
	}
	r["lo"] = lo - Vector3i(1, 1, 1);
	r["hi"] = hi + Vector3i(1, 1, 1);
	return r;
}

Dictionary MBNatif::ocean(const Dictionary &occupees, int64_t niveau, const Vector3i &lo, const Vector3i &hi) const {
	std::vector<int32_t> xs, ys, zs;
	const Array cles = occupees.keys();
	const int64_t n = cles.size();
	xs.reserve(size_t(n));
	ys.reserve(size_t(n));
	zs.reserve(size_t(n));
	for (int64_t i = 0; i < n; i++) {
		const Vector3i c = cles[i];
		xs.push_back(c.x);
		ys.push_back(c.y);
		zs.push_back(c.z);
	}
	const int32_t blo[3] = { lo.x, lo.y, lo.z };
	const int32_t bhi[3] = { hi.x, hi.y, hi.z };
	const std::vector<mbcore::Run> runs = mbcore::ocean_runs(xs, ys, zs, int32_t(niveau), blo, bhi);
	Dictionary eau;
	Array colonnes;
	colonnes.resize(int64_t(runs.size()));
	int64_t i = 0;
	for (const mbcore::Run &t : runs) {
		Array a;
		a.resize(4);
		a[0] = t.x;
		a[1] = t.z;
		a[2] = t.y0;
		a[3] = t.y1;
		colonnes[i++] = a;
		for (int32_t y = t.y0; y <= t.y1; y++) {
			eau[Vector3i(t.x, y, t.z)] = true;
		}
	}
	Dictionary r;
	r["eau"] = eau;
	r["colonnes"] = colonnes;
	r["erreur"] = String();
	return r;
}

void MBNatif::_bind_methods() {
	ClassDB::bind_method(D_METHOD("version"), &MBNatif::version);
	ClassDB::bind_method(D_METHOD("routes"), &MBNatif::routes);
	ClassDB::bind_method(D_METHOD("definir_regle", "table"), &MBNatif::definir_regle);
	ClassDB::bind_method(D_METHOD("est_pret"), &MBNatif::est_pret);
	ClassDB::bind_method(D_METHOD("poses", "pleines", "cles"), &MBNatif::poses);
	ClassDB::bind_method(D_METHOD("poses_en_couches", "union", "cles_par_couche"), &MBNatif::poses_en_couches);
	ClassDB::bind_method(D_METHOD("plafond_de", "pleines"), &MBNatif::plafond_de);
	ClassDB::bind_method(D_METHOD("hauts_des_colonnes", "pleines"), &MBNatif::hauts_des_colonnes);
	ClassDB::bind_method(D_METHOD("contacts_par_arete", "pleines", "cote"), &MBNatif::contacts_par_arete);
	ClassDB::bind_method(D_METHOD("compter_cases", "cases"), &MBNatif::compter_cases);
	ClassDB::bind_method(D_METHOD("empreinte_des_cases", "cases"), &MBNatif::empreinte_des_cases);
	ClassDB::bind_method(D_METHOD("reconstruire", "pleines", "miennes", "rang", "index", "poids", "choix", "rendu",
								 "fautes", "id_faute"),
			&MBNatif::reconstruire);
	ClassDB::bind_method(D_METHOD("refaire", "pleines", "sommets", "etat", "rang", "index", "poids", "choix",
								 "plafond", "rendu", "fautes", "id_faute", "compte"),
			&MBNatif::refaire);
	ClassDB::bind_method(D_METHOD("boite", "occupees"), &MBNatif::boite);
	ClassDB::bind_method(D_METHOD("ocean", "occupees", "niveau", "lo", "hi"), &MBNatif::ocean);
}
