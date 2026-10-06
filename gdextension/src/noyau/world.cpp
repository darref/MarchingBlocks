// MarchingBlocks core — the world and its diff (see world.h).
#include "world.h"

#include "placement.h"

#include <algorithm>
#include <climits>

namespace mbcore {

namespace {

inline bool cell_less(const Cell &a, const Cell &b) {
	if (a.x != b.x) {
		return a.x < b.x;
	}
	if (a.y != b.y) {
		return a.y < b.y;
	}
	return a.z < b.z;
}

inline bool cell_ok(const Cell &c) {
	return in_range(c.x) && in_range(c.y) && in_range(c.z);
}

} // namespace

// ---------------------------------------------------------------------------------------------- the decision

Placement World::decide(int32_t x, int32_t y, int32_t z) const {
	Placement p;
	const Union u{ this };
	const int32_t owner = vertex_layer(u, x, y, z);
	if (owner < 0) {
		return p;
	}
	const RuleRow &row = _rows[size_t(vertex_bits(u, x, y, z))];
	if (row.cls < 0) {
		return p;
	}
	const Layer &layer = _layers[size_t(owner)];
	const size_t base = size_t(row.cls) * 2;
	const KeyTiles *key = nullptr;
	bool outdoor = false;
	if (row.outdoor && base + 1 < layer.keys.size() && !layer.keys[base + 1].tiles.empty() &&
			under_sky(u, x, y, z, 0, &_tops)) {
		key = &layer.keys[base + 1];
		outdoor = true;
	}
	if (key == nullptr && base < layer.keys.size() && !layer.keys[base].tiles.empty()) {
		key = &layer.keys[base];
	}
	p.layer = owner;
	p.turn = row.turn;
	p.outdoor = outdoor;
	if (key == nullptr) {
		return p; // the error marker: a layer, no tile
	}
	int32_t k = 0;
	const int32_t n = int32_t(key->tiles.size()) - 1;
	if (n > 0) {
		const int32_t chosen = layer.choices.get(pack(x, y, z), -1);
		if (chosen >= 0 && chosen <= n) {
			k = chosen;
		} else {
			k = int32_t(pick_variant(vertex_hash(x, y, z), key->weights));
		}
	}
	p.tile = key->tiles[size_t(k)];
	p.variant = k;
	return p;
}

Placement World::placement_at(const Cell &v) const {
	const Placement *p = _placements.find(pack(v.x, v.y, v.z));
	return p != nullptr ? *p : Placement();
}

// ---------------------------------------------------------------------------------------------- the union

void World::_mark_vertices_of(int32_t x, int32_t y, int32_t z, CellMap &todo) {
	for (int t = 0; t < 8; t++) {
		todo.set(pack(x - CORNERS[t][0], y - CORNERS[t][1], z - CORNERS[t][2]), 0);
	}
}

// A column's highest visible cell went from `before` to `after` (INT32_MIN: empty). A vertex v reads that column
// (as one of its 4) when it is at x in cx-1..cx, z in cz-1..cz, and its answer is « top ≥ v.y + 2 »: only the
// vertices with v.y + 2 between the two tops can change their mind.
void World::_column_top_changed(int32_t cx, int32_t cz, int32_t before, int32_t after, CellMap &todo) {
	if (before == after) {
		return;
	}
	const int32_t lo = std::min(before, after);
	const int32_t hi = std::max(before, after);
	// v.y + 2 in (lo, hi]  ⇔  v.y in [lo - 1, hi - 2]; an empty column reaches down to the lowest vertex.
	const int32_t y0 = lo == INT32_MIN ? _y_low - 1 : lo - 1;
	const int32_t y1 = hi - 2;
	for (int32_t x = cx - 1; x <= cx; x++) {
		for (int32_t z = cz - 1; z <= cz; z++) {
			for (int32_t y = y0; y <= y1; y++) {
				todo.set(pack(x, y, z), 0);
			}
		}
	}
}

void World::_union_add(int32_t x, int32_t y, int32_t z, CellMap &todo) {
	_mark_vertices_of(x, y, z, todo);
	if (!_any || y < _y_low) {
		_y_low = y;
		_any = true;
	}
	const uint64_t col = pack_column(x, z);
	const int32_t count = _column_counts.get(col, 0);
	_column_counts.set(col, count + 1);
	const int32_t top = _tops.get(col, INT32_MIN);
	if (y > top) {
		_tops.set(col, y);
		_column_top_changed(x, z, top, y, todo);
	}
}

void World::_union_remove(int32_t x, int32_t y, int32_t z, CellMap &todo) {
	_mark_vertices_of(x, y, z, todo);
	const uint64_t col = pack_column(x, z);
	const int32_t count = _column_counts.get(col, 0) - 1;
	const int32_t top = _tops.get(col, INT32_MIN);
	if (count <= 0) {
		_column_counts.erase(col);
		_tops.erase(col);
		_column_top_changed(x, z, top, INT32_MIN, todo);
		return;
	}
	_column_counts.set(col, count);
	if (y < top) {
		return;
	}
	// The top left: the next visible cell down the column (the count says there is one).
	const Union u{ this };
	int32_t now = y - 1;
	while (now >= _y_low && !u.has(x, now, z)) {
		now--;
	}
	_tops.set(col, now);
	_column_top_changed(x, z, top, now, todo);
}

void World::_rebuild_union() {
	_tops.clear();
	_column_counts.clear();
	_any = false;
	_owner.for_each([&](uint64_t k, int32_t l) {
		if (!_visible_layer(l)) {
			return;
		}
		const Cell c = unpack(k);
		const uint64_t col = pack_column(c.x, c.z);
		_column_counts.set(col, _column_counts.get(col, 0) + 1);
		_tops.set_max(col, c.y);
		if (!_any || c.y < _y_low) {
			_y_low = c.y;
			_any = true;
		}
	});
}

// ---------------------------------------------------------------------------------------------- deciding again

void World::_redecide(const CellMap &todo, Delta &delta) {
	_last_decided = todo.size();
	todo.for_each([&](uint64_t k, int32_t) {
		const Cell v = unpack(k);
		const Placement now = decide(v.x, v.y, v.z);
		const Placement *was_ptr = _placements.find(k);
		const Placement was = was_ptr != nullptr ? *was_ptr : Placement();
		if (now == was) {
			return;
		}
		delta.placements.push_back(PlacementChange{ v, was, now });
		if (now.exists()) {
			_placements.set(k, now);
		} else {
			_placements.erase(k);
		}
	});
	_sort(delta);
}

void World::_sort(Delta &delta) {
	std::sort(delta.cells.begin(), delta.cells.end(),
			[](const CellChange &a, const CellChange &b) { return cell_less(a.cell, b.cell); });
	std::sort(delta.placements.begin(), delta.placements.end(),
			[](const PlacementChange &a, const PlacementChange &b) { return cell_less(a.vertex, b.vertex); });
}

Delta World::rebuild() {
	Delta delta;
	_rebuild_union();
	KeyMap<Placement> fresh;
	fresh.reserve(_owner.size() * 2);
	CellMap seen;
	seen.reserve(_owner.size() * 3);
	size_t decided = 0;
	_owner.for_each([&](uint64_t k, int32_t l) {
		if (!_visible_layer(l)) {
			return;
		}
		const Cell c = unpack(k);
		for (int t = 0; t < 8; t++) {
			const int32_t x = c.x - CORNERS[t][0], y = c.y - CORNERS[t][1], z = c.z - CORNERS[t][2];
			const uint64_t v = pack(x, y, z);
			if (!seen.set(v, 0)) {
				continue;
			}
			decided++;
			const Placement p = decide(x, y, z);
			if (p.exists()) {
				fresh.set(v, p);
			}
		}
	});
	fresh.for_each([&](uint64_t k, const Placement &p) {
		const Placement *was = _placements.find(k);
		if (was == nullptr || *was != p) {
			delta.placements.push_back(PlacementChange{ unpack(k), was != nullptr ? *was : Placement(), p });
		}
	});
	_placements.for_each([&](uint64_t k, const Placement &p) {
		if (!fresh.has(k)) {
			delta.placements.push_back(PlacementChange{ unpack(k), p, Placement() });
		}
	});
	_placements = fresh;
	_last_decided = decided;
	_sort(delta);
	return delta;
}

// ---------------------------------------------------------------------------------------------- the changes

Delta World::set_rules(const std::array<RuleRow, 256> &rows, int32_t classes) {
	_rows = rows;
	_classes = classes;
	return rebuild();
}

int32_t World::add_layer() {
	_layers.push_back(Layer());
	return int32_t(_layers.size()) - 1;
}

size_t World::cell_count(int32_t layer) const {
	return layer >= 0 && size_t(layer) < _layers.size() ? _layers[size_t(layer)].cells : 0;
}

bool World::is_visible(int32_t layer) const {
	return _visible_layer(layer);
}

Delta World::set_tiles(int32_t layer, const std::vector<KeyTiles> &keys) {
	Delta delta;
	if (layer < 0 || size_t(layer) >= _layers.size()) {
		return delta;
	}
	_layers[size_t(layer)].keys = keys;
	for (KeyTiles &k : _layers[size_t(layer)].keys) {
		k.weights.resize(k.tiles.size(), 1);
		for (int64_t &w : k.weights) {
			w = w < 0 ? 0 : w;
		}
	}
	// Only what the layer places can change: its vertices are exactly its placements.
	CellMap todo;
	_placements.for_each([&](uint64_t k, const Placement &p) {
		if (p.layer == layer) {
			todo.set(k, 0);
		}
	});
	_redecide(todo, delta);
	return delta;
}

Delta World::set_visible(int32_t layer, bool visible) {
	Delta delta;
	if (layer < 0 || size_t(layer) >= _layers.size() || _layers[size_t(layer)].visible == visible) {
		return delta;
	}
	CellMap todo;
	if (visible) {
		_layers[size_t(layer)].visible = true;
		_owner.for_each([&](uint64_t k, int32_t l) {
			if (l == layer) {
				const Cell c = unpack(k);
				_union_add(c.x, c.y, c.z, todo);
			}
		});
	} else {
		// Hidden first (a column's rescan must not find these cells), then out of the union one by one.
		std::vector<Cell> mine;
		_owner.for_each([&](uint64_t k, int32_t l) {
			if (l == layer) {
				mine.push_back(unpack(k));
			}
		});
		_layers[size_t(layer)].visible = false;
		for (const Cell &c : mine) {
			_union_remove(c.x, c.y, c.z, todo);
		}
	}
	_redecide(todo, delta);
	return delta;
}

// Renumbers the layers by `to_new[old]` (-1: gone) in the cells and the placements, so that a diff after a
// reordering only reports what really changed.
static void reindex(CellMap &owner, KeyMap<Placement> &placements, const std::vector<int32_t> &to_new) {
	std::vector<uint64_t> gone;
	owner.for_each([&](uint64_t k, int32_t l) {
		if (to_new[size_t(l)] < 0) {
			gone.push_back(k);
		}
	});
	for (uint64_t k : gone) {
		owner.erase(k);
	}
	CellMap renamed;
	renamed.reserve(owner.size());
	owner.for_each([&](uint64_t k, int32_t l) { renamed.set(k, to_new[size_t(l)]); });
	owner = renamed;
	KeyMap<Placement> moved;
	moved.reserve(placements.size());
	placements.for_each([&](uint64_t k, const Placement &p) {
		Placement q = p;
		q.layer = to_new[size_t(p.layer)];
		if (q.layer >= 0) {
			moved.set(k, q); // a placement of a removed layer is dropped: remove_layer reports it
		}
	});
	placements = moved;
}

Delta World::move_layer(int32_t from, int32_t to) {
	const int32_t n = int32_t(_layers.size());
	if (from < 0 || from >= n || to < 0 || to >= n || from == to) {
		return Delta();
	}
	std::vector<int32_t> order(static_cast<size_t>(n));
	for (int32_t i = 0; i < n; i++) {
		order[size_t(i)] = i;
	}
	order.erase(order.begin() + from);
	order.insert(order.begin() + to, from);
	std::vector<int32_t> to_new(static_cast<size_t>(n));
	std::vector<Layer> layers(static_cast<size_t>(n));
	for (int32_t i = 0; i < n; i++) {
		to_new[size_t(order[size_t(i)])] = i;
		layers[size_t(i)] = _layers[size_t(order[size_t(i)])];
	}
	_layers = layers;
	reindex(_owner, _placements, to_new);
	return rebuild();
}

Delta World::remove_layer(int32_t layer) {
	const int32_t n = int32_t(_layers.size());
	if (layer < 0 || layer >= n) {
		return Delta();
	}
	std::vector<int32_t> to_new(static_cast<size_t>(n));
	for (int32_t i = 0; i < n; i++) {
		to_new[size_t(i)] = i < layer ? i : (i == layer ? -1 : i - 1);
	}
	_layers.erase(_layers.begin() + layer);
	reindex(_owner, _placements, to_new);
	return rebuild();
}

Delta World::set_choice(int32_t layer, const Cell &vertex, int32_t variant) {
	Delta delta;
	if (layer < 0 || size_t(layer) >= _layers.size() || !cell_ok(vertex)) {
		return delta;
	}
	const uint64_t k = pack(vertex.x, vertex.y, vertex.z);
	if (variant < 0) {
		_layers[size_t(layer)].choices.erase(k);
	} else {
		_layers[size_t(layer)].choices.set(k, variant);
	}
	CellMap todo;
	todo.set(k, 0);
	_redecide(todo, delta);
	return delta;
}

int32_t World::choice_at(int32_t layer, const Cell &vertex) const {
	if (layer < 0 || size_t(layer) >= _layers.size()) {
		return -1;
	}
	return _layers[size_t(layer)].choices.get(pack(vertex.x, vertex.y, vertex.z), -1);
}

Delta World::set_cells(int32_t layer, const std::vector<Cell> &cells, const std::vector<Cell> &clear) {
	Delta delta;
	CellMap todo;
	CellMap cleared; // cell -> its entry in delta.cells
	const bool layer_ok = layer >= 0 && size_t(layer) < _layers.size();
	// Clear first: a cell in both lists is set.
	for (const Cell &c : clear) {
		if (!cell_ok(c)) {
			continue;
		}
		const uint64_t k = pack(c.x, c.y, c.z);
		const int32_t before = _owner.get(k, -1);
		if (before < 0) {
			continue;
		}
		_owner.erase(k);
		_layers[size_t(before)].cells--;
		cleared.set(k, int32_t(delta.cells.size()));
		delta.cells.push_back(CellChange{ c, before, -1 });
		if (_layers[size_t(before)].visible) {
			_union_remove(c.x, c.y, c.z, todo);
		}
	}
	if (layer_ok) {
		const bool visible = _layers[size_t(layer)].visible;
		for (const Cell &c : cells) {
			if (!cell_ok(c)) {
				continue;
			}
			const uint64_t k = pack(c.x, c.y, c.z);
			const int32_t before = _owner.get(k, -1);
			if (before == layer) {
				continue;
			}
			// Cleared then set in the same call: one change, from its first owner.
			const int32_t at = cleared.get(k, -1);
			if (at >= 0) {
				delta.cells[size_t(at)].after = layer;
			} else {
				delta.cells.push_back(CellChange{ c, before, layer });
			}
			const bool was_visible = before >= 0 && _layers[size_t(before)].visible;
			if (before >= 0) {
				_layers[size_t(before)].cells--;
			}
			_owner.set(k, layer);
			_layers[size_t(layer)].cells++;
			if (was_visible && visible) {
				_mark_vertices_of(c.x, c.y, c.z, todo); // same union, another rank
			} else if (was_visible) {
				_union_remove(c.x, c.y, c.z, todo);
			} else if (visible) {
				_union_add(c.x, c.y, c.z, todo);
			}
		}
	}
	// A cell cleared then set back to the layer that held it is no change at all.
	delta.cells.erase(std::remove_if(delta.cells.begin(), delta.cells.end(),
							  [](const CellChange &cc) { return cc.before == cc.after; }),
			delta.cells.end());
	_redecide(todo, delta);
	return delta;
}

} // namespace mbcore
