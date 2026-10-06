#include "mb_monde.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <string>
#include <unordered_map>

using namespace godot;

namespace {

inline mbcore::Cell cellule(const Vector3i &v) {
	mbcore::Cell c;
	c.x = v.x;
	c.y = v.y;
	c.z = v.z;
	return c;
}

inline void pousser_pose(int32_t *o, const mbcore::Placement &p) {
	o[0] = p.layer;
	o[1] = p.tile;
	o[2] = p.turn;
	o[3] = p.variant;
	o[4] = p.outdoor ? 1 : 0;
}

} // namespace

bool MBMonde::_lire_cases(const Variant &v, std::vector<mbcore::Cell> &sortie) {
	sortie.clear();
	if (v.get_type() == Variant::PACKED_INT32_ARRAY) {
		const PackedInt32Array a = v;
		ERR_FAIL_COND_V_MSG(a.size() % 3 != 0, false, "MBMonde : des cases à plat vont par trois.");
		const int32_t *p = a.ptr();
		sortie.reserve(size_t(a.size() / 3));
		for (int64_t i = 0; i + 2 < a.size(); i += 3) {
			mbcore::Cell c;
			c.x = p[i];
			c.y = p[i + 1];
			c.z = p[i + 2];
			sortie.push_back(c);
		}
		return true;
	}
	if (v.get_type() == Variant::NIL) {
		return true;
	}
	const Array a = v;
	sortie.reserve(size_t(a.size()));
	for (int64_t i = 0; i < a.size(); i++) {
		sortie.push_back(cellule(a[i]));
	}
	return true;
}

Dictionary MBMonde::_diff(const mbcore::Delta &d) {
	PackedInt32Array cases, poses;
	cases.resize(int64_t(d.cells.size()) * PAR_CASE);
	int32_t *c = cases.ptrw();
	for (const mbcore::CellChange &x : d.cells) {
		c[0] = x.cell.x;
		c[1] = x.cell.y;
		c[2] = x.cell.z;
		c[3] = x.before;
		c[4] = x.after;
		c += PAR_CASE;
	}
	poses.resize(int64_t(d.placements.size()) * PAR_POSE);
	int32_t *p = poses.ptrw();
	for (const mbcore::PlacementChange &x : d.placements) {
		p[0] = x.vertex.x;
		p[1] = x.vertex.y;
		p[2] = x.vertex.z;
		pousser_pose(p + 3, x.before);
		pousser_pose(p + 8, x.after);
		p += PAR_POSE;
	}
	Dictionary r;
	r["cases"] = cases;
	r["poses"] = poses;
	return r;
}

Dictionary MBMonde::definir_regle(const Array &table) {
	ERR_FAIL_COND_V_MSG(table.size() != 256, Dictionary(), "MBMonde : la table doit porter les 256 configurations.");
	// Les classes se DÉDUISENT des noms : une classe par nom distinct des configurations à surface.
	std::array<mbcore::RuleRow, 256> lignes{};
	std::unordered_map<std::string, int32_t> classes;
	_noms.clear();
	_noms_dehors.clear();
	for (int b = 0; b < 256; b++) {
		const Dictionary r = table[b];
		if (!bool(r.get("surface", false))) {
			continue;
		}
		const String nom = r.get("nom", "");
		const std::string cle(nom.utf8().get_data());
		auto f = classes.find(cle);
		if (f == classes.end()) {
			f = classes.emplace(cle, int32_t(_noms.size())).first;
			_noms.push_back(nom);
			_noms_dehors.push_back(String(r.get("nom_dehors", "")));
		}
		lignes[size_t(b)].cls = f->second;
		lignes[size_t(b)].outdoor = bool(r.get("exterieur", false));
		lignes[size_t(b)].turn = int32_t(int64_t(r.get("orientation", 0)));
	}
	return _diff(_monde.set_rules(lignes, int32_t(_noms.size())));
}

int64_t MBMonde::ajouter_couche() {
	return _monde.add_layer();
}

int64_t MBMonde::nombre_de_couches() const {
	return _monde.layer_count();
}

Dictionary MBMonde::retirer_couche(int64_t couche) {
	return _diff(_monde.remove_layer(int32_t(couche)));
}

Dictionary MBMonde::definir_tuiles(int64_t couche, const Dictionary &index, const Dictionary &poids) {
	// `MB.pose_du_sommet` et `MB.tuile_du_sommet` : la clé est présente si l'index a son nom ; ses variantes sont
	// « _var1 », « _var2 »… tant que l'index les a (9 au plus) ; poids absent = 1.
	std::vector<mbcore::KeyTiles> cles(_noms.size() * 2);
	for (size_t k = 0; k < _noms.size(); k++) {
		for (int dehors = 0; dehors < 2; dehors++) {
			const String nom = dehors ? _noms_dehors[k] : _noms[k];
			if (nom.is_empty() || !index.has(nom)) {
				continue;
			}
			mbcore::KeyTiles &t = cles[k * 2 + size_t(dehors)];
			t.tiles.push_back(int32_t(int64_t(index[nom])));
			for (int n = 1; n <= 9; n++) {
				const String v = nom + String("_var") + String::num_int64(n);
				if (!index.has(v)) {
					break;
				}
				t.tiles.push_back(int32_t(int64_t(index[v])));
			}
			const Array w = poids.get(nom, Array());
			for (int64_t i = 0; i < int64_t(t.tiles.size()); i++) {
				t.weights.push_back(i < w.size() ? int64_t(w[i]) : 1);
			}
		}
	}
	return _diff(_monde.set_tiles(int32_t(couche), cles));
}

Dictionary MBMonde::definir_visible(int64_t couche, bool visible) {
	return _diff(_monde.set_visible(int32_t(couche), visible));
}

bool MBMonde::est_visible(int64_t couche) const {
	return _monde.is_visible(int32_t(couche));
}

Dictionary MBMonde::deplacer_couche(int64_t de, int64_t vers) {
	return _diff(_monde.move_layer(int32_t(de), int32_t(vers)));
}

Dictionary MBMonde::choisir(int64_t couche, const Vector3i &sommet, int64_t variante) {
	return _diff(_monde.set_choice(int32_t(couche), cellule(sommet), int32_t(variante)));
}

int64_t MBMonde::choix_de(int64_t couche, const Vector3i &sommet) const {
	return _monde.choice_at(int32_t(couche), cellule(sommet));
}

Dictionary MBMonde::poser(int64_t couche, const Variant &cases) {
	return changer(couche, cases, Variant());
}

Dictionary MBMonde::vider(const Variant &cases) {
	return changer(-1, Variant(), cases);
}

Dictionary MBMonde::changer(int64_t couche, const Variant &a_poser, const Variant &a_vider) {
	std::vector<mbcore::Cell> p, v;
	if (!_lire_cases(a_poser, p) || !_lire_cases(a_vider, v)) {
		return Dictionary();
	}
	return _diff(_monde.set_cells(int32_t(couche), p, v));
}

int64_t MBMonde::couche_de(const Vector3i &c) const {
	return _monde.layer_at(cellule(c));
}

int64_t MBMonde::nombre_de_cases(int64_t couche) const {
	return couche < 0 ? int64_t(_monde.cell_count()) : int64_t(_monde.cell_count(int32_t(couche)));
}

int64_t MBMonde::nombre_de_poses() const {
	return int64_t(_monde.placement_count());
}

Dictionary MBMonde::pose_au(const Vector3i &sommet) const {
	Dictionary d;
	const mbcore::Placement p = _monde.placement_at(cellule(sommet));
	if (!p.exists()) {
		return d;
	}
	d["couche"] = p.layer;
	d["tuile"] = p.tile;
	d["orientation"] = p.turn;
	d["variante"] = p.variant;
	d["dehors"] = p.outdoor;
	return d;
}

Dictionary MBMonde::tout_refaire() {
	return _diff(_monde.rebuild());
}

int64_t MBMonde::derniers_decides() const {
	return int64_t(_monde.last_decided());
}

void MBMonde::appliquer(const Dictionary &diff, const Array &rendus, const Array &fautes, int64_t id_faute) const {
	const PackedInt32Array poses = diff.get("poses", PackedInt32Array());
	const int32_t *p = poses.ptr();
	const int64_t n = poses.size() / PAR_POSE;
	auto grille = [](const Array &a, int32_t c) -> GridMap * {
		if (c < 0 || c >= a.size()) {
			return nullptr;
		}
		return Object::cast_to<GridMap>(a[c]);
	};
	for (int64_t i = 0; i < n; i++, p += PAR_POSE) {
		const Vector3i s(p[0], p[1], p[2]);
		// Retirer d'abord (un sommet qui change de couche quitte l'ancienne), puis poser.
		if (p[3] >= 0) {
			GridMap *g = p[4] >= 0 ? grille(rendus, p[3]) : grille(fautes, p[3]);
			if (g != nullptr) {
				g->set_cell_item(s, GridMap::INVALID_CELL_ITEM);
			}
		}
		if (p[8] >= 0) {
			if (p[9] >= 0) {
				GridMap *g = grille(rendus, p[8]);
				if (g != nullptr) {
					g->set_cell_item(s, p[9], p[10]);
				}
			} else if (id_faute >= 0) {
				GridMap *g = grille(fautes, p[8]);
				if (g != nullptr) {
					g->set_cell_item(s, int32_t(id_faute));
				}
			}
		}
	}
}

void MBMonde::remplir(int64_t couche, GridMap *rendu, GridMap *fautes, int64_t id_faute) const {
	if (rendu != nullptr) {
		rendu->clear();
	}
	if (fautes != nullptr) {
		fautes->clear();
	}
	_monde.for_each_placement([&](const mbcore::Cell &v, const mbcore::Placement &p) {
		if (p.layer != couche) {
			return;
		}
		const Vector3i s(v.x, v.y, v.z);
		if (p.tile >= 0) {
			if (rendu != nullptr) {
				rendu->set_cell_item(s, p.tile, p.turn);
			}
		} else if (fautes != nullptr && id_faute >= 0) {
			fautes->set_cell_item(s, int32_t(id_faute));
		}
	});
}

void MBMonde::_bind_methods() {
	ClassDB::bind_method(D_METHOD("definir_regle", "table"), &MBMonde::definir_regle);
	ClassDB::bind_method(D_METHOD("ajouter_couche"), &MBMonde::ajouter_couche);
	ClassDB::bind_method(D_METHOD("nombre_de_couches"), &MBMonde::nombre_de_couches);
	ClassDB::bind_method(D_METHOD("retirer_couche", "couche"), &MBMonde::retirer_couche);
	ClassDB::bind_method(D_METHOD("definir_tuiles", "couche", "index", "poids"), &MBMonde::definir_tuiles);
	ClassDB::bind_method(D_METHOD("definir_visible", "couche", "visible"), &MBMonde::definir_visible);
	ClassDB::bind_method(D_METHOD("est_visible", "couche"), &MBMonde::est_visible);
	ClassDB::bind_method(D_METHOD("deplacer_couche", "de", "vers"), &MBMonde::deplacer_couche);
	ClassDB::bind_method(D_METHOD("choisir", "couche", "sommet", "variante"), &MBMonde::choisir);
	ClassDB::bind_method(D_METHOD("choix_de", "couche", "sommet"), &MBMonde::choix_de);
	ClassDB::bind_method(D_METHOD("poser", "couche", "cases"), &MBMonde::poser);
	ClassDB::bind_method(D_METHOD("vider", "cases"), &MBMonde::vider);
	ClassDB::bind_method(D_METHOD("changer", "couche", "poser", "vider"), &MBMonde::changer);
	ClassDB::bind_method(D_METHOD("couche_de", "case"), &MBMonde::couche_de);
	ClassDB::bind_method(D_METHOD("nombre_de_cases", "couche"), &MBMonde::nombre_de_cases);
	ClassDB::bind_method(D_METHOD("nombre_de_poses"), &MBMonde::nombre_de_poses);
	ClassDB::bind_method(D_METHOD("pose_au", "sommet"), &MBMonde::pose_au);
	ClassDB::bind_method(D_METHOD("tout_refaire"), &MBMonde::tout_refaire);
	ClassDB::bind_method(D_METHOD("derniers_decides"), &MBMonde::derniers_decides);
	ClassDB::bind_method(D_METHOD("appliquer", "diff", "rendus", "fautes", "id_faute"), &MBMonde::appliquer);
	ClassDB::bind_method(D_METHOD("remplir", "couche", "rendu", "fautes", "id_faute"), &MBMonde::remplir);
}
