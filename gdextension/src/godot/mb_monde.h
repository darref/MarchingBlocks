// MBMonde — le pont entre `mbcore::World` (le monde du cœur : couches, cases, décision de chaque sommet, DIFF)
// et Godot.
//
// ⚠ IL NE DÉCIDE RIEN : la table des 256 configurations lui est DONNÉE (`definir_regle`, la même que `MB.natif()`
// donne à MBNatif), les tuiles d'une couche aussi (`definir_tuiles` : l'index {nom: id} de son lot, ses poids).
// Chaque changement rend un DIFF ; `appliquer` le pose dans les grilles (`Rendu` et `Fautes` de chaque couche).
//
// Le diff, en tableaux plats (rien n'est alloué par case) :
//   "cases" : PackedInt32Array, par case changée     x, y, z, couche avant, couche après   (−1 : aucune)
//   "poses" : PackedInt32Array, par sommet changé    x, y, z, puis avant et après :
//             couche, tuile (id du lot ; −1 : la tuile manque — un cube rouge), orientation, variante, dehors
//   (5 + 2 × 5 = 13 entiers par sommet ; une couche −1 : rien n'y est posé)
#pragma once

#include "../noyau/world.h"

#include <godot_cpp/classes/grid_map.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3i.hpp>

#include <vector>

namespace godot {

class MBMonde : public RefCounted {
	GDCLASS(MBMonde, RefCounted)

public:
	static constexpr int PAR_POSE = 13;
	static constexpr int PAR_CASE = 5;

	Dictionary definir_regle(const Array &table);
	int64_t ajouter_couche();
	int64_t nombre_de_couches() const;
	Dictionary retirer_couche(int64_t couche);
	Dictionary definir_tuiles(int64_t couche, const Dictionary &index, const Dictionary &poids);
	Dictionary definir_visible(int64_t couche, bool visible);
	bool est_visible(int64_t couche) const;
	Dictionary deplacer_couche(int64_t de, int64_t vers);
	Dictionary choisir(int64_t couche, const Vector3i &sommet, int64_t variante);
	int64_t choix_de(int64_t couche, const Vector3i &sommet) const;

	// `cases` : un Array de Vector3i, ou un PackedInt32Array plat (x, y, z…).
	Dictionary poser(int64_t couche, const Variant &cases);
	Dictionary vider(const Variant &cases);
	Dictionary changer(int64_t couche, const Variant &poser, const Variant &vider);

	int64_t couche_de(const Vector3i &c) const;
	int64_t nombre_de_cases(int64_t couche) const;
	int64_t nombre_de_poses() const;
	Dictionary pose_au(const Vector3i &sommet) const;
	Dictionary tout_refaire();
	int64_t derniers_decides() const;

	// Pose un diff dans les grilles : `rendus[c]` / `fautes[c]` sont celles de la couche c (null : sautée).
	void appliquer(const Dictionary &diff, const Array &rendus, const Array &fautes, int64_t id_faute) const;
	// Les grilles d'une couche, remplies d'un coup (vidées d'abord) depuis l'état du monde.
	void remplir(int64_t couche, GridMap *rendu, GridMap *fautes, int64_t id_faute) const;

protected:
	static void _bind_methods();

private:
	mbcore::World _monde;
	// Par classe : son nom (sous roche) et son nom d'air libre — pour lire l'index d'un lot.
	std::vector<String> _noms, _noms_dehors;

	static bool _lire_cases(const Variant &v, std::vector<mbcore::Cell> &sortie);
	static Dictionary _diff(const mbcore::Delta &d);
};

} // namespace godot
