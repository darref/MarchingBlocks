// MarchingBlocks core — THE WORLD: layers, their cells, the decision of every vertex, and the DIFF of a change.
//
// What a world is (the tileset rule, steps 1-8, written once in `rules_text`):
//   - a list of LAYERS in priority order (the first wins); each has its own tiles, variant weights and choices;
//   - a cell belongs to ONE layer at most (setting it in a layer takes it from the others);
//   - the rule reads the UNION of the VISIBLE layers; a vertex is placed by the first layer owning one of its
//     8 cells, with that layer's tiles; a hidden layer places nothing and holds nothing back.
//
// Every change (`set_cells`, `set_visible`, `move_layer`, `set_choice`, `set_tiles`) returns a Delta: the cells
// that changed hands and the PLACEMENTS that changed — before and after — sorted by vertex. A bridge (a Godot
// GridMap, Unreal instances, Unity objects) applies the delta and nothing else: that is the incremental rebuild,
// written once. Only the vertices a change can reach are decided again: the 8 vertices of each changed cell,
// and, when a column's highest cell moves, the vertices whose sky it may open or close.
//
// The world knows no names. Classes, tiles and quarter turns are integers the caller gives meaning to (a tile
// index of a MeshLibrary, a GridMap orientation, a quarter-turn count of the format…).
//
// Standard C++17, no exceptions, no RTTI: the constraints of Unreal (see CLAUDE.md §0, « le cœur C++ »).
#pragma once

#include "cells.h"

#include <array>
#include <cstdint>
#include <vector>

namespace mbcore {

// One configuration of the 8 cells around a vertex (the class table, 256 rows).
struct RuleRow {
	int32_t cls = -1; // the class; -1 places nothing (empty or full)
	bool outdoor = false; // the class can be under the sky (has an "_outdoor" key)
	int32_t turn = 0; // the orientation the caller gives this configuration
};

// What sits at a vertex. `layer` < 0: nothing. `tile` < 0 with a layer: the layer lacks the tile the rule asks
// for — an error marker, never a fill-in (§3).
struct Placement {
	int32_t layer = -1;
	int32_t tile = -1;
	int32_t turn = 0;
	int32_t variant = 0; // 0 for the base tile, k for variant k
	bool outdoor = false;

	bool exists() const { return layer >= 0; }
	bool operator==(const Placement &o) const {
		return layer == o.layer && tile == o.tile && turn == o.turn && variant == o.variant && outdoor == o.outdoor;
	}
	bool operator!=(const Placement &o) const { return !(*this == o); }
};

// One key of a layer's tiles: its base tile, then its variants (tiles[k] for variant k), and the weights of the
// draw (one per tile, already ≥ 0). An empty `tiles` means the layer has no tile for this key.
struct KeyTiles {
	std::vector<int32_t> tiles;
	std::vector<int64_t> weights;
};

struct CellChange {
	Cell cell;
	int32_t before = -1; // the layer that held it, -1 for none
	int32_t after = -1;
};

struct PlacementChange {
	Cell vertex;
	Placement before;
	Placement after;
};

struct Delta {
	std::vector<CellChange> cells; // sorted by cell (x, then y, then z)
	std::vector<PlacementChange> placements; // sorted by vertex

	bool empty() const { return cells.empty() && placements.empty(); }
};

class World {
public:
	// The class table, by configuration (bit t = the cell at vertex + CORNERS[t]). `classes`: how many classes.
	// Changing the rules decides every vertex again.
	Delta set_rules(const std::array<RuleRow, 256> &rows, int32_t classes);

	// Appends a layer (the lowest priority), visible, without tiles. Returns its index.
	int32_t add_layer();
	int32_t layer_count() const { return int32_t(_layers.size()); }

	// Removes a layer and its cells; the following layers move up by one. The bridge drops that layer's own
	// storage and renumbers the others FIRST (as for move_layer), then applies the delta: it lists, in the new
	// numbering, what the remaining layers place differently (a vertex the removed layer placed has « nothing »
	// before). Its cells are not listed — they went with the layer.
	Delta remove_layer(int32_t layer);

	// The tiles of a key (cls, outdoor) of a layer. `set_tiles` sets them all at once (index cls * 2 + outdoor,
	// `classes * 2` entries) and decides again what the layer places.
	Delta set_tiles(int32_t layer, const std::vector<KeyTiles> &keys);

	Delta set_visible(int32_t layer, bool visible);
	bool is_visible(int32_t layer) const;

	// Moves a layer to another rank of the priority order (the others shift). The bridge renumbers its own
	// layers first (what was at `from` is at `to`), then applies the delta: only what is placed differently.
	Delta move_layer(int32_t from, int32_t to);

	// The variant CHOSEN at a vertex by a layer (0 = the base tile); < 0 removes the choice (back to the draw).
	// A choice out of range for the key at that vertex is kept but ignored (the draw places), as in the rule.
	Delta set_choice(int32_t layer, const Cell &vertex, int32_t variant);
	int32_t choice_at(int32_t layer, const Cell &vertex) const;

	// Puts `cells` into `layer` (taken from any other layer that held them) and empties `clear` (whatever layer
	// held them). A cell in both lists is set. Cells out of the core's range (±1 048 574) are ignored.
	Delta set_cells(int32_t layer, const std::vector<Cell> &cells, const std::vector<Cell> &clear);

	// The layer holding a cell, -1 when empty (hidden layers included).
	int32_t layer_at(const Cell &cell) const { return _owner.get(pack(cell.x, cell.y, cell.z), -1); }
	size_t cell_count() const { return _owner.size(); }
	size_t cell_count(int32_t layer) const;

	// What sits at a vertex (layer < 0: nothing).
	Placement placement_at(const Cell &vertex) const;
	size_t placement_count() const { return _placements.size(); }

	// Every cell (cell, layer) and every placement (vertex, placement), in storage order.
	template <class F>
	void for_each_cell(F &&f) const {
		_owner.for_each([&](uint64_t k, int32_t l) { f(unpack(k), l); });
	}
	template <class F>
	void for_each_placement(F &&f) const {
		_placements.for_each([&](uint64_t k, const Placement &p) { f(unpack(k), p); });
	}

	// Decides every vertex from scratch (what the incremental route must always agree with).
	Delta rebuild();

	// The decision at one vertex from the current cells — no state read but the cells, the tops and the layers.
	Placement decide(int32_t x, int32_t y, int32_t z) const;

	// How many vertices the last change decided again (for measurements and tests).
	size_t last_decided() const { return _last_decided; }

private:
	struct Layer {
		bool visible = true;
		std::vector<KeyTiles> keys; // cls * 2 + outdoor
		CellMap choices; // vertex -> variant
		size_t cells = 0;
	};

	// The union of the visible layers, as the placement rule reads it: has() and get() (the rank).
	struct Union {
		const World *w;
		bool has(int32_t x, int32_t y, int32_t z) const {
			const int32_t l = w->_owner.get(pack(x, y, z), -1);
			return l >= 0 && w->_layers[size_t(l)].visible;
		}
		int32_t get(int32_t x, int32_t y, int32_t z, int32_t missing) const {
			const int32_t l = w->_owner.get(pack(x, y, z), -1);
			return l >= 0 && w->_layers[size_t(l)].visible ? l : missing;
		}
	};

	std::array<RuleRow, 256> _rows{};
	int32_t _classes = 0;
	std::vector<Layer> _layers;
	CellMap _owner; // cell -> layer
	CellMap _tops; // column -> highest VISIBLE cell
	CellMap _column_counts; // column -> how many visible cells (to know when a column empties)
	KeyMap<Placement> _placements; // vertex -> placement (only existing ones)
	int32_t _y_low = 0; // a bound ≤ every visible cell's y (never raised: an over-estimate only costs visits)
	bool _any = false;
	size_t _last_decided = 0;

	bool _visible_layer(int32_t l) const { return l >= 0 && size_t(l) < _layers.size() && _layers[size_t(l)].visible; }

	// The union gained or lost the cell (x, y, z): keeps the tops and counts; adds the vertices whose sky may
	// change to `todo`.
	void _union_add(int32_t x, int32_t y, int32_t z, CellMap &todo);
	void _union_remove(int32_t x, int32_t y, int32_t z, CellMap &todo);
	void _column_top_changed(int32_t cx, int32_t cz, int32_t before, int32_t after, CellMap &todo);
	static void _mark_vertices_of(int32_t x, int32_t y, int32_t z, CellMap &todo);

	// Decides the vertices of `todo` again and returns the placement changes, sorted.
	void _redecide(const CellMap &todo, Delta &delta);
	void _rebuild_union();
	static void _sort(Delta &delta);
};

} // namespace mbcore
