// MBNatif — le pont entre le cœur C++ (`src/noyau/`) et l'appli Godot.
//
// ⚠ IL NE DÉCIDE RIEN : la table des 256 configurations lui est DONNÉE par `marching_blocks.gd`
// (`definir_regle`), et chaque méthode rend EXACTEMENT ce que rend la fonction GDScript qu'elle remplace —
// mêmes clés, même ordre. Le GDScript reste la référence ; `DEV_TOOLS/test_natif.gd` compare les deux.
#pragma once

#include "../noyau/cells.h"

#include <godot_cpp/classes/grid_map.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <vector>

namespace godot {

class MBNatif : public RefCounted {
	GDCLASS(MBNatif, RefCounted)

public:
	MBNatif();

	String version() const;
	Dictionary routes() const; // combien de fois `refaire` a lu le Dictionary / l'a recopié (pour les tests)
	void definir_regle(const Array &table);
	bool est_pret() const;

	// marching_blocks.gd
	Array poses(const Dictionary &pleines, const Dictionary &cles);
	Array poses_en_couches(const Dictionary &uni, const Array &cles_par_couche);
	int64_t plafond_de(const Dictionary &pleines) const;
	Dictionary hauts_des_colonnes(const Dictionary &pleines) const;
	int64_t contacts_par_arete(const Dictionary &pleines, int64_t cote) const;

	// massif_peint.gd
	Array compter_cases(const Array &cases) const;
	int64_t empreinte_des_cases(const Array &cases) const;
	Dictionary reconstruire(const Dictionary &pleines, const Dictionary &miennes, int64_t rang,
			const Dictionary &index, const Dictionary &poids, const Dictionary &choix,
			GridMap *rendu, GridMap *fautes, int64_t id_faute);
	void refaire(const Dictionary &pleines, const Array &sommets, Dictionary etat, int64_t rang,
			const Dictionary &index, const Dictionary &poids, const Dictionary &choix, int64_t plafond,
			GridMap *rendu, GridMap *fautes, int64_t id_faute, Dictionary compte);

	// fluides.gd
	Dictionary boite(const Dictionary &occupees) const;
	Dictionary ocean(const Dictionary &occupees, int64_t niveau, const Vector3i &lo, const Vector3i &hi) const;

protected:
	static void _bind_methods();

private:
	struct Ligne {
		bool surface = false;
		bool exterieur = false;
		int32_t orientation = 0;
		String nom;
		String nom_dehors;
	};
	Ligne _lignes[256];
	bool _pret = false;
	int64_t _routes_dict = 0;
	int64_t _routes_copie = 0;

	// Ce qu'un lot (index) dit d'une clé, préparé une fois par appel.
	struct Cle {
		bool presente = false;
		String nom;
		int n = 0; // variantes
		std::vector<String> tuiles; // base, var1…
		std::vector<int32_t> ids; // id de chaque tuile dans l'index (−1 si absent)
		std::vector<int64_t> poids; // n + 1, ≥ 0
	};
	struct Lot {
		Cle cles[512]; // (bits << 1) | dehors
	};
	void _preparer_lot(Lot &lot, const Dictionary &index, const Dictionary &poids, bool avec_variantes) const;

	Dictionary _vide; // le {} muet partagé, en lecture seule
	Variant _k_sommet, _k_nom, _k_cle, _k_orientation, _k_dehors, _k_tuile, _k_couche;

	template <class Cases>
	Variant _decision(const Cases &cases, int32_t x, int32_t y, int32_t z, int64_t rang, int32_t plafond,
			const mbcore::CellMap *hauts, const Lot &lot, const Dictionary &choix, bool avec_tuile) const;
};

} // namespace godot
