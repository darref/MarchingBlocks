// MBMonde — le pont entre `mbcore::World` (le monde du cœur : couches, cases, décision de chaque sommet, DIFF)
// et Godot.
//
// ⚠ IL NE DÉCIDE RIEN : la table des 256 configurations lui est DONNÉE (`definir_regle`, la même que `MB.natif()`
// donne à MBNatif), les tuiles d'une couche aussi (`definir_tuiles` : l'index {nom: id} de son lot, ses poids).
//
// DEUX FAÇONS DE S'EN SERVIR :
//   - à la main (`DEV_TOOLS/test_natif.gd` §10) : chaque changement rend son DIFF, et `appliquer` le pose dans les
//     grilles qu'on lui donne ;
//   - BRANCHÉ DANS L'APPLI (étape 3 b) : chaque `MassifPeint` d'un écran s'INSCRIT à son rang (ses grilles `Rendu` et
//     `Fautes`, son état `_etat` et ses comptes `_compte`, des Dictionary tenus PAR RÉFÉRENCE). Les changements
//     s'accumulent en ATTENTE ; `vider_attente` les pose dans les couches inscrites — grilles, état et comptes, comme
//     le GDScript les tiendrait. Le monde suit l'UNION de l'écran ({case: rang}), relue par `suivre` (quelques cases)
//     ou `resynchroniser` (toute).
//
// Le diff, en tableaux plats (rien n'est alloué par case) :
//   "cases" : PackedInt32Array, par case changée     x, y, z, couche avant, couche après   (−1 : aucune)
//   "poses" : PackedInt32Array, par sommet changé    x, y, z, puis avant et après :
//             couche (−1 : rien), classe (−1 : sommet MUET — à la couche, sans surface), tuile (id du lot ; −1 sur
//             une surface : la tuile manque — un cube rouge), orientation, variante, dehors
//   (3 + 2 × 6 = 15 entiers par sommet)
#pragma once

#include "../noyau/world.h"

#include <godot_cpp/classes/grid_map.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3i.hpp>

#include <unordered_map>
#include <vector>

namespace godot {

class MBMonde : public RefCounted {
	GDCLASS(MBMonde, RefCounted)

public:
	static constexpr int PAR_POSE = 15;
	static constexpr int PAR_CASE = 5;

	MBMonde();

	Dictionary definir_regle(const Array &table);
	int64_t ajouter_couche();
	int64_t nombre_de_couches() const;
	Dictionary retirer_couche(int64_t couche);
	Dictionary definir_tuiles(int64_t couche, const Dictionary &index, const Dictionary &poids);
	Dictionary definir_visible(int64_t couche, bool visible);
	bool est_visible(int64_t couche) const;
	Dictionary deplacer_couche(int64_t de, int64_t vers);
	Dictionary choisir(int64_t couche, const Vector3i &sommet, int64_t variante);
	Dictionary definir_choix(int64_t couche, const Dictionary &choix);
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

	// ── branché dans l'appli ──
	// Inscrit `proprio` (un MassifPeint) au rang `rang`. Rend VRAI si le rang change de propriétaire : ce que le monde
	// y pose n'est pas dans ses grilles, il doit se REMPLIR (`remplir_couche`). L'attente est vidée d'abord vers les
	// anciens propriétaires ; un proprio inscrit ailleurs y est désinscrit.
	bool inscrire(Object *proprio, int64_t rang, GridMap *rendu, GridMap *fautes, int64_t id_faute, Dictionary etat,
			Dictionary compte);
	// Les tuiles, les poids et les choix d'une couche (l'attente reçoit ce qui change).
	void definir_couche(int64_t rang, const Dictionary &index, const Dictionary &poids, const Dictionary &choix);
	// Les choix de quelques sommets, relus dans `choix` (absent : le tirage).
	void choisir_sommets(int64_t rang, const Array &sommets, const Dictionary &choix);
	// Le monde suit l'union {case: rang} pour ces cases, ou toute entière.
	void suivre(const Dictionary &uni, const Array &cases);
	void resynchroniser(const Dictionary &uni);
	// Pose l'attente dans les couches inscrites (grilles, état, comptes).
	int64_t vider_attente();
	// La même, sans toucher la couche de ce rang (qui va se remplir d'un coup).
	int64_t vider_attente_sauf(int64_t rang);
	int64_t taille_attente() const;
	// La couche de ce rang dort-elle (cachée) ? Pour les tests.
	bool dort(int64_t rang) const;
	// L'identifiant de l'objet inscrit à ce rang (0 : personne). Pour les tests.
	int64_t proprio(int64_t rang) const;
	// La couche inscrite à ce rang, remplie d'un coup depuis le monde (grilles vidées, état et comptes refaits).
	void remplir_couche(int64_t rang);

protected:
	static void _bind_methods();

private:
	struct Inscrit {
		uint64_t proprio = 0;
		uint64_t rendu = 0;
		uint64_t fautes = 0;
		int32_t id_faute = -1;
		Dictionary etat;
		Dictionary compte;
		int64_t signature = 0; // l'empreinte des tuiles, poids et choix posés à ce rang (0 : aucun)
		// UNE COUCHE CACHÉE DORT : ses grilles et son état restent tels qu'à l'endormissement (`instantane` : ce que le
		// monde posait alors à ce rang) ; en se réveillant, elle ne reçoit que la différence avec ce qu'il pose.
		bool dort = false;
		mbcore::KeyMap<mbcore::Placement> instantane;
	};
	struct Attente {
		mbcore::Placement avant;
		mbcore::Placement apres;
	};

	mbcore::World _monde;
	// Par classe : son nom (sous roche) et son nom d'air libre — pour lire l'index d'un lot.
	std::vector<String> _noms, _noms_dehors;
	// Par rang : le nom de chaque tuile (id du lot → nom), pour l'état tenu des couches.
	std::vector<std::unordered_map<int32_t, String>> _noms_tuiles;
	std::vector<Inscrit> _inscrits;
	mbcore::KeyMap<Attente> _attente;
	Dictionary _vide;
	Variant _k_sommet, _k_nom, _k_cle, _k_orientation, _k_dehors, _k_tuile;
	Variant _k_pieces, _k_fautes, _k_dehors_c, _k_touches, _k_decisions;

	struct Comptes {
		int64_t pieces = 0, fautes = 0, dehors = 0, touches = 0, decisions = 0;
	};

	static bool _lire_cases(const Variant &v, std::vector<mbcore::Cell> &sortie);
	// Le changement rejoint l'attente ; `_diff` le rend aussi en tableaux plats (les appels publics à la main).
	void _retenir(const mbcore::Delta &d);
	Dictionary _diff(const mbcore::Delta &d);
	void _assurer(int32_t couches);
	Dictionary _decision(const mbcore::Cell &v, const mbcore::Placement &p) const;
	void _poser_dans(Inscrit &ins, Comptes &c, const mbcore::Cell &v, const mbcore::Placement &p, int sens) const;
	void _ecrire_comptes(Inscrit &ins, const Comptes &c) const;
	bool _visible(const Inscrit &ins) const;
	void _endormir(int32_t rang);
	void _reveiller(int32_t rang);
	std::vector<mbcore::KeyTiles> _tuiles(int32_t couche, const Dictionary &index, const Dictionary &poids);
};

} // namespace godot
