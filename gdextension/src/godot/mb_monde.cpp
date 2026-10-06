#include "mb_monde.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/core/object.hpp>

#include <string>
#include <utility>
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
	o[1] = p.cls;
	o[2] = p.tile;
	o[3] = p.turn;
	o[4] = p.variant;
	o[5] = p.outdoor ? 1 : 0;
}

template <class T>
T *objet(uint64_t id) {
	if (id == 0) {
		return nullptr;
	}
	return Object::cast_to<T>(ObjectDB::get_instance(id));
}

} // namespace

MBMonde::MBMonde() {
	_vide.make_read_only();
	_k_sommet = String("sommet");
	_k_nom = String("nom");
	_k_cle = String("cle");
	_k_orientation = String("orientation");
	_k_dehors = String("dehors");
	_k_tuile = String("tuile");
	_k_pieces = String("pieces");
	_k_fautes = String("fautes");
	_k_dehors_c = String("dehors");
	_k_touches = String("touches");
	_k_decisions = String("decisions");
}

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

// Chaque changement passe ici : il rejoint l'ATTENTE (le premier « avant » d'un sommet est gardé, le dernier « après »
// le remplace ; un sommet revenu à son état d'avant en sort), et il est rendu en tableaux plats.
void MBMonde::_retenir(const mbcore::Delta &d) {
	for (const mbcore::PlacementChange &x : d.placements) {
		const uint64_t k = mbcore::pack(x.vertex.x, x.vertex.y, x.vertex.z);
		const Attente *a = _attente.find(k);
		if (a == nullptr) {
			_attente.set(k, Attente{ x.before, x.after });
		} else if (a->avant == x.after) {
			_attente.erase(k);
		} else {
			_attente.set(k, Attente{ a->avant, x.after });
		}
	}
}

Dictionary MBMonde::_diff(const mbcore::Delta &d) {
	_retenir(d);
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
		pousser_pose(p + 9, x.after);
		p += PAR_POSE;
	}
	Dictionary r;
	r["cases"] = cases;
	r["poses"] = poses;
	return r;
}

void MBMonde::_assurer(int32_t couches) {
	while (_monde.layer_count() < couches) {
		_monde.add_layer();
	}
	if (int32_t(_noms_tuiles.size()) < couches) {
		_noms_tuiles.resize(size_t(couches));
	}
	if (int32_t(_inscrits.size()) < couches) {
		_inscrits.resize(size_t(couches));
	}
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
	_assurer(_monde.layer_count() + 1);
	return _monde.layer_count() - 1;
}

int64_t MBMonde::nombre_de_couches() const {
	return _monde.layer_count();
}

Dictionary MBMonde::retirer_couche(int64_t couche) {
	if (couche >= 0 && couche < int64_t(_noms_tuiles.size())) {
		_noms_tuiles.erase(_noms_tuiles.begin() + couche);
	}
	if (couche >= 0 && couche < int64_t(_inscrits.size())) {
		_inscrits.erase(_inscrits.begin() + couche);
	}
	return _diff(_monde.remove_layer(int32_t(couche)));
}

std::vector<mbcore::KeyTiles> MBMonde::_tuiles(int32_t couche, const Dictionary &index, const Dictionary &poids) {
	// `MB.pose_du_sommet` et `MB.tuile_du_sommet` : la clé est présente si l'index a son nom ; ses variantes sont
	// « _var1 », « _var2 »… tant que l'index les a (9 au plus) ; poids absent = 1.
	std::vector<mbcore::KeyTiles> cles(_noms.size() * 2);
	std::unordered_map<int32_t, String> &noms = _noms_tuiles[size_t(couche)];
	noms.clear();
	for (size_t k = 0; k < _noms.size(); k++) {
		for (int dehors = 0; dehors < 2; dehors++) {
			const String nom = dehors ? _noms_dehors[k] : _noms[k];
			if (nom.is_empty() || !index.has(nom)) {
				continue;
			}
			mbcore::KeyTiles &t = cles[k * 2 + size_t(dehors)];
			t.tiles.push_back(int32_t(int64_t(index[nom])));
			noms[t.tiles.back()] = nom;
			for (int n = 1; n <= 9; n++) {
				const String v = nom + String("_var") + String::num_int64(n);
				if (!index.has(v)) {
					break;
				}
				t.tiles.push_back(int32_t(int64_t(index[v])));
				noms[t.tiles.back()] = v;
			}
			const Array w = poids.get(nom, Array());
			for (int64_t i = 0; i < int64_t(t.tiles.size()); i++) {
				t.weights.push_back(i < w.size() ? int64_t(w[i]) : 1);
			}
		}
	}
	return cles;
}

Dictionary MBMonde::definir_tuiles(int64_t couche, const Dictionary &index, const Dictionary &poids) {
	ERR_FAIL_COND_V(couche < 0, Dictionary());
	_assurer(int32_t(couche) + 1);
	return _diff(_monde.set_tiles(int32_t(couche), _tuiles(int32_t(couche), index, poids)));
}

Dictionary MBMonde::definir_visible(int64_t couche, bool visible) {
	return _diff(_monde.set_visible(int32_t(couche), visible));
}

bool MBMonde::est_visible(int64_t couche) const {
	return _monde.is_visible(int32_t(couche));
}

Dictionary MBMonde::deplacer_couche(int64_t de, int64_t vers) {
	const int64_t n = _monde.layer_count();
	if (de >= 0 && de < n && vers >= 0 && vers < n && de != vers) {
		// BRANCHÉ (Up / Down de l'écran, 6 octobre 2026) : l'attente va d'abord chez ses propriétaires, dans l'ancienne
		// numérotation ; puis chaque inscrit SUIT sa couche (ses grilles portent déjà ce que le monde y pose : rien à
		// remplir), et le diff ne dit que les sommets des frontières qui changent de propriétaire.
		vider_attente();
		_assurer(int32_t(n));
		auto noms = _noms_tuiles[size_t(de)];
		_noms_tuiles.erase(_noms_tuiles.begin() + de);
		_noms_tuiles.insert(_noms_tuiles.begin() + vers, noms);
		Inscrit ins = _inscrits[size_t(de)];
		_inscrits.erase(_inscrits.begin() + de);
		_inscrits.insert(_inscrits.begin() + vers, ins);
		// Une couche qui DORT garde la photo de ce qu'elle pose : à son nouveau rang, ses poses portent ce rang.
		for (size_t r = 0; r < _inscrits.size(); r++) {
			Inscrit &i = _inscrits[r];
			if (!i.dort) {
				continue;
			}
			mbcore::KeyMap<mbcore::Placement> renumerotee;
			renumerotee.reserve(i.instantane.size());
			i.instantane.for_each([&](uint64_t k, const mbcore::Placement &p) {
				mbcore::Placement q = p;
				q.layer = int32_t(r);
				renumerotee.set(k, q);
			});
			i.instantane = std::move(renumerotee);
		}
	}
	return _diff(_monde.move_layer(int32_t(de), int32_t(vers)));
}

Dictionary MBMonde::choisir(int64_t couche, const Vector3i &sommet, int64_t variante) {
	return _diff(_monde.set_choice(int32_t(couche), cellule(sommet), int32_t(variante)));
}

Dictionary MBMonde::definir_choix(int64_t couche, const Dictionary &choix) {
	ERR_FAIL_COND_V(couche < 0, Dictionary());
	_assurer(int32_t(couche) + 1);
	std::vector<std::pair<mbcore::Cell, int32_t>> liste;
	const Array cles = choix.keys();
	const Array vals = choix.values();
	liste.reserve(size_t(cles.size()));
	for (int64_t i = 0; i < cles.size(); i++) {
		liste.push_back({ cellule(cles[i]), int32_t(int64_t(vals[i])) });
	}
	return _diff(_monde.set_choices(int32_t(couche), liste));
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
	if (couche >= 0) {
		_assurer(int32_t(couche) + 1);
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
	int64_t n = 0;
	_monde.for_each_placement([&](const mbcore::Cell &, const mbcore::Placement &p) {
		if (p.surface()) {
			n++;
		}
	});
	return n;
}

Dictionary MBMonde::pose_au(const Vector3i &sommet) const {
	Dictionary d;
	const mbcore::Placement p = _monde.placement_at(cellule(sommet));
	if (!p.exists()) {
		return d;
	}
	d["couche"] = p.layer;
	d["classe"] = p.cls;
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
		// Retirer d'abord (un sommet qui change de couche quitte l'ancienne), puis poser. Un sommet muet ne pose rien.
		if (p[3] >= 0 && p[4] >= 0) {
			GridMap *g = p[5] >= 0 ? grille(rendus, p[3]) : grille(fautes, p[3]);
			if (g != nullptr) {
				g->set_cell_item(s, GridMap::INVALID_CELL_ITEM);
			}
		}
		if (p[9] >= 0 && p[10] >= 0) {
			if (p[11] >= 0) {
				GridMap *g = grille(rendus, p[9]);
				if (g != nullptr) {
					g->set_cell_item(s, p[11], p[12]);
				}
			} else if (id_faute >= 0) {
				GridMap *g = grille(fautes, p[9]);
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
		if (p.layer != couche || !p.surface()) {
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

// ── branché dans l'appli ─────────────────────────────────────────────────────────────────────────────

bool MBMonde::inscrire(Object *proprio, int64_t rang, GridMap *rendu, GridMap *fautes, int64_t id_faute, Dictionary etat,
		Dictionary compte) {
	ERR_FAIL_COND_V(proprio == nullptr || rang < 0, false);
	_assurer(int32_t(rang) + 1);
	const uint64_t id = proprio->get_instance_id();
	Inscrit &ins = _inscrits[size_t(rang)];
	const bool change = ins.proprio != id;
	if (change) {
		// Ce que le monde a déjà décidé pour les anciens propriétaires va d'abord chez eux.
		vider_attente();
		for (Inscrit &autre : _inscrits) {
			if (autre.proprio == id) {
				autre = Inscrit();
			}
		}
	}
	Inscrit &moi = _inscrits[size_t(rang)];
	if (change) {
		moi.signature = 0;
		moi.dort = false;
		moi.instantane = mbcore::KeyMap<mbcore::Placement>();
	}
	moi.proprio = id;
	moi.rendu = rendu != nullptr ? uint64_t(rendu->get_instance_id()) : 0;
	moi.fautes = fautes != nullptr ? uint64_t(fautes->get_instance_id()) : 0;
	moi.id_faute = int32_t(id_faute);
	moi.etat = etat;
	moi.compte = compte;
	return change;
}

void MBMonde::definir_couche(int64_t rang, const Dictionary &index, const Dictionary &poids, const Dictionary &choix) {
	ERR_FAIL_COND(rang < 0);
	_assurer(int32_t(rang) + 1);
	// Les mêmes tuiles, poids et choix, au même propriétaire : rien à décider de nouveau (une couche reconstruite parce
	// que les autres ont glissé). L'empreinte est remise à zéro quand le rang change de propriétaire (`inscrire`).
	const int64_t signature = int64_t(index.hash()) * 31 * 31 + int64_t(poids.hash()) * 31 + int64_t(choix.hash()) + 1;
	Inscrit &ins = _inscrits[size_t(rang)];
	if (ins.proprio != 0 && ins.signature == signature) {
		return;
	}
	_retenir(_monde.set_tiles(int32_t(rang), _tuiles(int32_t(rang), index, poids)));
	std::vector<std::pair<mbcore::Cell, int32_t>> liste;
	const Array cles = choix.keys();
	const Array vals = choix.values();
	liste.reserve(size_t(cles.size()));
	for (int64_t i = 0; i < cles.size(); i++) {
		liste.push_back({ cellule(cles[i]), int32_t(int64_t(vals[i])) });
	}
	_retenir(_monde.set_choices(int32_t(rang), liste));
	ins.signature = signature;
}

void MBMonde::choisir_sommets(int64_t rang, const Array &sommets, const Dictionary &choix) {
	for (int64_t i = 0; i < sommets.size(); i++) {
		const Vector3i s = sommets[i];
		const Variant k = choix.get(s, Variant());
		_retenir(_monde.set_choice(int32_t(rang), cellule(s), k.get_type() == Variant::NIL ? -1 : int32_t(int64_t(k))));
	}
}

void MBMonde::suivre(const Dictionary &uni, const Array &cases) {
	// Ces cases, relues dans l'union : groupées par rang, une case qui n'y est plus vidée.
	std::vector<std::vector<mbcore::Cell>> par_rang;
	std::vector<mbcore::Cell> a_vider;
	for (int64_t i = 0; i < cases.size(); i++) {
		const Vector3i c = cases[i];
		const mbcore::Cell cc = cellule(c);
		const Variant r = uni.get(c, Variant());
		const int32_t rang = r.get_type() == Variant::NIL ? -1 : int32_t(int64_t(r));
		if (rang == _monde.layer_at(cc)) {
			continue;
		}
		if (rang < 0) {
			a_vider.push_back(cc);
			continue;
		}
		if (int32_t(par_rang.size()) <= rang) {
			par_rang.resize(size_t(rang) + 1);
		}
		par_rang[size_t(rang)].push_back(cc);
	}
	if (!a_vider.empty()) {
		_retenir(_monde.set_cells(-1, {}, a_vider));
	}
	for (size_t r = 0; r < par_rang.size(); r++) {
		if (!par_rang[r].empty()) {
			_assurer(int32_t(r) + 1);
			_retenir(_monde.set_cells(int32_t(r), par_rang[r], {}));
		}
	}
}

void MBMonde::resynchroniser(const Dictionary &uni) {
	// Ce qui diffère entre le monde et l'union : peu de chose, par le chemin incrémental ; beaucoup (l'ouverture, un
	// rang qui glisse), tout d'un coup (`assign`, puis chaque sommet décidé une fois).
	const Array cles = uni.keys();
	const Array vals = uni.values();
	const int64_t n = cles.size();
	std::vector<std::pair<mbcore::Cell, int32_t>> tout;
	tout.reserve(size_t(n));
	std::vector<std::vector<mbcore::Cell>> par_rang;
	mbcore::CellMap vues;
	vues.reserve(size_t(n));
	size_t differences = 0;
	int32_t plus_haut = -1;
	for (int64_t i = 0; i < n; i++) {
		const Vector3i c = cles[i];
		const int32_t rang = int32_t(int64_t(vals[i]));
		const mbcore::Cell cc = cellule(c);
		if (!mbcore::in_range(c.x) || !mbcore::in_range(c.y) || !mbcore::in_range(c.z) || rang < 0) {
			continue;
		}
		tout.push_back({ cc, rang });
		vues.set(mbcore::pack(c.x, c.y, c.z), rang);
		plus_haut = rang > plus_haut ? rang : plus_haut;
		if (_monde.layer_at(cc) != rang) {
			differences++;
			if (int32_t(par_rang.size()) <= rang) {
				par_rang.resize(size_t(rang) + 1);
			}
			par_rang[size_t(rang)].push_back(cc);
		}
	}
	std::vector<mbcore::Cell> a_vider;
	_monde.for_each_cell([&](const mbcore::Cell &c, int32_t) {
		if (!vues.has(mbcore::pack(c.x, c.y, c.z))) {
			a_vider.push_back(c);
		}
	});
	differences += a_vider.size();
	if (differences == 0) {
		return;
	}
	_assurer(plus_haut + 1);
	if (differences * 4 > tout.size()) {
		_retenir(_monde.assign(tout));
		return;
	}
	if (!a_vider.empty()) {
		_retenir(_monde.set_cells(-1, {}, a_vider));
	}
	for (size_t r = 0; r < par_rang.size(); r++) {
		if (!par_rang[r].empty()) {
			_retenir(_monde.set_cells(int32_t(r), par_rang[r], {}));
		}
	}
}

bool MBMonde::dort(int64_t rang) const {
	return rang >= 0 && rang < int64_t(_inscrits.size()) && _inscrits[size_t(rang)].dort;
}

int64_t MBMonde::proprio(int64_t rang) const {
	return rang >= 0 && rang < int64_t(_inscrits.size()) ? int64_t(_inscrits[size_t(rang)].proprio) : 0;
}

int64_t MBMonde::taille_attente() const {
	return int64_t(_attente.size());
}

// La décision d'un sommet telle que `MassifPeint._decision` la rend ({} : muet), avec les noms du lot de sa couche.
Dictionary MBMonde::_decision(const mbcore::Cell &v, const mbcore::Placement &p) const {
	Dictionary d;
	if (!p.surface()) {
		return d;
	}
	d[_k_sommet] = Vector3i(v.x, v.y, v.z);
	d[_k_nom] = _noms[size_t(p.cls)];
	if (p.tile < 0) {
		d[_k_cle] = String();
	} else {
		d[_k_cle] = p.outdoor ? _noms_dehors[size_t(p.cls)] : _noms[size_t(p.cls)];
	}
	d[_k_orientation] = p.turn;
	d[_k_dehors] = p.outdoor;
	if (p.tile >= 0 && size_t(p.layer) < _noms_tuiles.size()) {
		const auto &noms = _noms_tuiles[size_t(p.layer)];
		const auto f = noms.find(p.tile);
		d[_k_tuile] = f != noms.end() ? f->second : String();
	}
	return d;
}

// Pose (sens = 1) ou retire (sens = −1) une décision chez une couche inscrite : ses grilles, son état, et des comptes
// tenus à part (écrits UNE fois à la fin : lire et réécrire un Dictionary par sommet coûtait le tiers du temps) — ce que
// `MassifPeint._poser` et `_refaire` tiennent.
void MBMonde::_poser_dans(Inscrit &ins, Comptes &c, const mbcore::Cell &v, const mbcore::Placement &p, int sens) const {
	const Vector3i s(v.x, v.y, v.z);
	if (sens > 0) {
		ins.etat[s] = _decision(v, p);
	} else {
		ins.etat.erase(s);
	}
	c.touches += sens;
	if (!p.surface()) {
		return;
	}
	c.decisions += sens;
	if (p.tile < 0) {
		c.fautes += sens;
		GridMap *f = objet<GridMap>(ins.fautes);
		if (f != nullptr && ins.id_faute >= 0) {
			f->set_cell_item(s, sens > 0 ? ins.id_faute : GridMap::INVALID_CELL_ITEM);
		}
		return;
	}
	c.pieces += sens;
	if (p.outdoor) {
		c.dehors += sens;
	}
	GridMap *r = objet<GridMap>(ins.rendu);
	if (r != nullptr) {
		if (sens > 0) {
			r->set_cell_item(s, p.tile, p.turn);
		} else {
			r->set_cell_item(s, GridMap::INVALID_CELL_ITEM);
		}
	}
}

void MBMonde::_ecrire_comptes(Inscrit &ins, const Comptes &c) const {
	Dictionary &d = ins.compte;
	d[_k_pieces] = int64_t(d.get(_k_pieces, 0)) + c.pieces;
	d[_k_fautes] = int64_t(d.get(_k_fautes, 0)) + c.fautes;
	d[_k_dehors_c] = int64_t(d.get(_k_dehors_c, 0)) + c.dehors;
	d[_k_touches] = int64_t(d.get(_k_touches, 0)) + c.touches;
	d[_k_decisions] = int64_t(d.get(_k_decisions, 0)) + c.decisions;
}

int64_t MBMonde::vider_attente() {
	return vider_attente_sauf(-1);
}

// Une couche est cachée quand son nœud l'est (l'écran cache la couche elle-même : `MassifPeint.visible`). ⚠ Pas
// `is_visible_in_tree()` sur ses grilles : hors d'un arbre entré (un script `--script`), il répondait « visible ».
bool MBMonde::_visible(const Inscrit &ins) const {
	Node3D *n = objet<Node3D>(ins.proprio);
	return n != nullptr && n->is_visible();
}

// L'état d'une couche qui s'endort : ce que le monde pose à son rang, MOINS l'attente (pas encore posée chez elle).
void MBMonde::_endormir(int32_t rang) {
	Inscrit &ins = _inscrits[size_t(rang)];
	ins.instantane = mbcore::KeyMap<mbcore::Placement>();
	_monde.for_each_placement([&](const mbcore::Cell &v, const mbcore::Placement &p) {
		if (p.layer == rang) {
			ins.instantane.set(mbcore::pack(v.x, v.y, v.z), p);
		}
	});
	_attente.for_each([&](uint64_t k, const Attente &a) {
		if (a.apres.layer == rang) {
			ins.instantane.erase(k);
		}
		if (a.avant.layer == rang) {
			ins.instantane.set(k, a.avant);
		}
	});
	ins.dort = true;
}

// Réveillée : la différence entre ce qu'elle porte (l'instantané) et ce que le monde pose MAINTENANT à son rang.
void MBMonde::_reveiller(int32_t rang) {
	Inscrit &ins = _inscrits[size_t(rang)];
	Comptes c;
	ins.instantane.for_each([&](uint64_t k, const mbcore::Placement &avant) {
		const mbcore::Cell v = mbcore::unpack(k);
		const mbcore::Placement maintenant = _monde.placement_at(v);
		if (maintenant != avant) {
			_poser_dans(ins, c, v, avant, -1);
		}
	});
	_monde.for_each_placement([&](const mbcore::Cell &v, const mbcore::Placement &p) {
		if (p.layer != rang) {
			return;
		}
		const mbcore::Placement *avant = ins.instantane.find(mbcore::pack(v.x, v.y, v.z));
		if (avant == nullptr || *avant != p) {
			_poser_dans(ins, c, v, p, 1);
		}
	});
	_ecrire_comptes(ins, c);
	ins.instantane = mbcore::KeyMap<mbcore::Placement>();
	ins.dort = false;
}

int64_t MBMonde::vider_attente_sauf(int64_t sauf) {
	const int64_t n = int64_t(_attente.size());
	// Les couches cachées s'endorment, les couches montrées se réveillent — avant de poser quoi que ce soit.
	std::vector<char> sautees(_inscrits.size(), 0);
	for (size_t r = 0; r < _inscrits.size(); r++) {
		Inscrit &ins = _inscrits[r];
		if (ins.proprio == 0 || int64_t(r) == sauf) {
			sautees[r] = 1;
			continue;
		}
		const bool visible = _visible(ins);
		if (!ins.dort && !visible) {
			_endormir(int32_t(r));
			sautees[r] = 1;
		} else if (ins.dort && visible) {
			_reveiller(int32_t(r)); // elle reçoit l'état du monde : l'attente qui la concerne y est déjà
			sautees[r] = 1;
		} else if (ins.dort) {
			sautees[r] = 1;
		}
	}
	if (n == 0) {
		return 0;
	}
	std::vector<Comptes> comptes(_inscrits.size());
	auto inscrit = [&](const mbcore::Placement &p) -> bool {
		return p.exists() && size_t(p.layer) < _inscrits.size() && !sautees[size_t(p.layer)];
	};
	// Retirer tout, puis poser tout : un sommet qui change de couche quitte l'ancienne avant d'entrer dans la nouvelle.
	_attente.for_each([&](uint64_t k, const Attente &a) {
		if (inscrit(a.avant)) {
			_poser_dans(_inscrits[size_t(a.avant.layer)], comptes[size_t(a.avant.layer)], mbcore::unpack(k), a.avant, -1);
		}
	});
	_attente.for_each([&](uint64_t k, const Attente &a) {
		if (inscrit(a.apres)) {
			_poser_dans(_inscrits[size_t(a.apres.layer)], comptes[size_t(a.apres.layer)], mbcore::unpack(k), a.apres, 1);
		}
	});
	for (size_t r = 0; r < _inscrits.size(); r++) {
		if (!sautees[r]) {
			_ecrire_comptes(_inscrits[r], comptes[r]);
		}
	}
	// ⚠ L'ATTENTE D'UNE COUCHE ENDORMIE N'EST PAS PERDUE : son réveil compare à l'état du monde, qui l'inclut.
	_attente = mbcore::KeyMap<Attente>();
	return n;
}

void MBMonde::remplir_couche(int64_t rang) {
	ERR_FAIL_COND(rang < 0 || rang >= int64_t(_inscrits.size()));
	Inscrit &ins = _inscrits[size_t(rang)];
	ins.dort = false;
	ins.instantane = mbcore::KeyMap<mbcore::Placement>();
	GridMap *r = objet<GridMap>(ins.rendu);
	GridMap *f = objet<GridMap>(ins.fautes);
	if (r != nullptr) {
		r->clear();
	}
	if (f != nullptr) {
		f->clear();
	}
	ins.etat.clear();
	for (const Variant *k : { &_k_pieces, &_k_fautes, &_k_dehors_c, &_k_touches, &_k_decisions }) {
		ins.compte[*k] = 0;
	}
	Comptes c;
	_monde.for_each_placement([&](const mbcore::Cell &v, const mbcore::Placement &p) {
		if (p.layer == rang) {
			_poser_dans(ins, c, v, p, 1);
		}
	});
	_ecrire_comptes(ins, c);
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
	ClassDB::bind_method(D_METHOD("definir_choix", "couche", "choix"), &MBMonde::definir_choix);
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
	ClassDB::bind_method(D_METHOD("inscrire", "proprio", "rang", "rendu", "fautes", "id_faute", "etat", "compte"),
			&MBMonde::inscrire);
	ClassDB::bind_method(D_METHOD("definir_couche", "rang", "index", "poids", "choix"), &MBMonde::definir_couche);
	ClassDB::bind_method(D_METHOD("choisir_sommets", "rang", "sommets", "choix"), &MBMonde::choisir_sommets);
	ClassDB::bind_method(D_METHOD("suivre", "union", "cases"), &MBMonde::suivre);
	ClassDB::bind_method(D_METHOD("resynchroniser", "union"), &MBMonde::resynchroniser);
	ClassDB::bind_method(D_METHOD("vider_attente"), &MBMonde::vider_attente);
	ClassDB::bind_method(D_METHOD("vider_attente_sauf", "rang"), &MBMonde::vider_attente_sauf);
	ClassDB::bind_method(D_METHOD("taille_attente"), &MBMonde::taille_attente);
	ClassDB::bind_method(D_METHOD("dort", "rang"), &MBMonde::dort);
	ClassDB::bind_method(D_METHOD("proprio", "rang"), &MBMonde::proprio);
	ClassDB::bind_method(D_METHOD("remplir_couche", "rang"), &MBMonde::remplir_couche);
}
