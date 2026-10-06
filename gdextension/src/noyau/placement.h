// MarchingBlocks core — the placement rule, on any cell container.
//
// The rule itself (which class, which quarter turn, which context, which variant) is described ONCE, in
// `FormatNeutre.regle()` / `rules_text`; the 256-entry class table travels as DATA (the app hands it over
// from `marching_blocks.gd`, the plugins read it from `tileset.json`). This file only evaluates it fast.
//
// `Cells` is any type with `bool has(int32_t x, int32_t y, int32_t z) const` and
// `int32_t get(int32_t x, int32_t y, int32_t z, int32_t missing) const` (the layer rank, for layered worlds).
#pragma once

#include "cells.h"

#include <climits>
#include <cstdint>
#include <vector>

namespace mbcore {

// Bit t is the cell at vertex + CORNERS[t], t = x + 2y + 4z. Y is up.
constexpr int32_t CORNERS[8][3] = {
	{ 0, 0, 0 }, { 1, 0, 0 }, { 0, 1, 0 }, { 1, 1, 0 },
	{ 0, 0, 1 }, { 1, 0, 1 }, { 0, 1, 1 }, { 1, 1, 1 },
};

// One row of the class table, by configuration (8 bits).
struct ClassRow {
	bool surface = false; // neither empty nor full
	bool outdoor = false; // can be under the sky (no empty bottom cell capped inside the 8)
	int32_t orientation = 0; // GridMap orthogonal index (0, 10, 16, 22 for the oriented group)
};

template <class Cells>
inline int vertex_bits(const Cells &cells, int32_t x, int32_t y, int32_t z) {
	int b = 0;
	for (int t = 0; t < 8; t++) {
		if (cells.has(x + CORNERS[t][0], y + CORNERS[t][1], z + CORNERS[t][2])) {
			b |= 1 << t;
		}
	}
	return b;
}

// The layer that places a vertex: the smallest rank among its eight cells, -1 when none is painted.
template <class Cells>
inline int32_t vertex_layer(const Cells &cells, int32_t x, int32_t y, int32_t z) {
	int32_t r = -1;
	for (int t = 0; t < 8; t++) {
		const int32_t v = cells.get(x + CORNERS[t][0], y + CORNERS[t][1], z + CORNERS[t][2], -1);
		if (v >= 0 && (r < 0 || v < r)) {
			r = v;
		}
	}
	return r;
}

// Does the EMPTY space the piece borders see the sky? Only the empty cells of the eight are probed, each
// column from y + 2 up to `ceiling` (any bound ≥ the highest cell). With `tops` (the highest cell of each
// column), « a full cell from y + 2 up » becomes « the top is at y + 2 or above »: the same answer.
template <class Cells>
inline bool under_sky(const Cells &cells, int32_t x, int32_t y, int32_t z, int32_t ceiling, const CellMap *tops) {
	for (int t = 0; t < 8; t++) {
		const int32_t bx = x + CORNERS[t][0];
		const int32_t by = y + CORNERS[t][1];
		const int32_t bz = z + CORNERS[t][2];
		if (cells.has(bx, by, bz)) {
			continue;
		}
		if (tops != nullptr) {
			if (tops->get(pack_column(bx, bz), INT32_MIN) >= y + 2) {
				return false;
			}
			continue;
		}
		for (int32_t yy = y + 2; yy <= ceiling; yy++) {
			if (cells.has(bx, yy, bz)) {
				return false;
			}
		}
	}
	return true;
}

// The vertex hash of the variant draw (rules_text, step 8): Teschner's spatial hash, then two mixes.
// 64-bit arithmetic, masked to 31 bits, exactly as written in the rule.
inline int64_t vertex_hash(int32_t x, int32_t y, int32_t z) {
	int64_t h = ((int64_t(x) * 73856093) ^ (int64_t(y) * 19349663) ^ (int64_t(z) * 83492791)) & 0x7FFFFFFF;
	h = ((h ^ (h >> 16)) * 0x45D9F3B) & 0x7FFFFFFF;
	h = ((h ^ (h >> 16)) * 0x45D9F3B) & 0x7FFFFFFF;
	return h ^ (h >> 16);
}

// The weighted draw: `weights` has n + 1 entries (base, var1…), already clamped to ≥ 0. Returns the rank.
inline int pick_variant(int64_t hash, const std::vector<int64_t> &weights) {
	int64_t total = 0;
	for (int64_t w : weights) {
		total += w;
	}
	if (total <= 0) {
		return 0;
	}
	int64_t r = hash % total;
	for (size_t k = 0; k < weights.size(); k++) {
		r -= weights[k];
		if (r < 0) {
			return int(k);
		}
	}
	return 0;
}

// The CellMap seen as a cell container.
struct MapCells {
	const CellMap *map;
	bool has(int32_t x, int32_t y, int32_t z) const { return map->has(pack(x, y, z)); }
	int32_t get(int32_t x, int32_t y, int32_t z, int32_t missing) const { return map->get(pack(x, y, z), missing); }
};

// Column tops of a whole map.
inline void column_tops(const CellMap &cells, CellMap &tops) {
	tops.clear();
	tops.reserve(cells.size() / 4 + 16);
	cells.for_each([&](uint64_t key, int32_t) {
		const int32_t y = int32_t((key >> 21) & AXIS_MASK) - AXIS_OFFSET;
		tops.set_max((key & ~(AXIS_MASK << 21)) | (uint64_t(AXIS_OFFSET) << 21), y);
	});
}

} // namespace mbcore
