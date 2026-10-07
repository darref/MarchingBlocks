// MarchingBlocks core — the ocean fill, by column runs.
//
// The rule (fluides.gd, `ocean`): inside the world box, at or under `level`, the empty space connected to
// the bottom of the box (the horizon). Each column of the box is cut into RUNS of empty cells; the bottom
// run of every column touches the horizon; a run joins the sea through a horizontal neighbour whose run
// overlaps it. The order of the result (the breadth-first order) is the reference order, kept exactly.
#pragma once

#include <algorithm>
#include <cstdint>
#include <vector>

namespace mbcore {

struct Run {
	int32_t x, z, y0, y1;
};

// `cells_x/y/z`: the painted cells (any order). `lo`, `hi`: the world box (already widened by one cell).
// Returns the sea runs in breadth-first order. `level` must be ≥ lo.y (the caller checks).
inline std::vector<Run> ocean_runs(const std::vector<int32_t> &cells_x, const std::vector<int32_t> &cells_y,
		const std::vector<int32_t> &cells_z, int32_t level, const int32_t lo[3], const int32_t hi[3]) {
	const int32_t top = std::min(level, hi[1]);
	const int64_t nx = int64_t(hi[0]) - lo[0] + 1;
	const int64_t nz = int64_t(hi[2]) - lo[2] + 1;
	std::vector<Run> out;
	if (nx <= 0 || nz <= 0) {
		return out;
	}
	const size_t ncols = size_t(nx * nz);
	auto col_of = [&](int32_t x, int32_t z) -> int64_t {
		if (x < lo[0] || x > hi[0] || z < lo[2] || z > hi[2]) {
			return -1;
		}
		return (int64_t(x) - lo[0]) * nz + (int64_t(z) - lo[2]);
	};

	// The full cells of each column, under the level: counted, then bucketed, then sorted.
	std::vector<uint32_t> start(ncols + 1, 0);
	for (size_t i = 0; i < cells_x.size(); i++) {
		if (cells_y[i] <= top) {
			const int64_t c = col_of(cells_x[i], cells_z[i]);
			if (c >= 0) {
				start[size_t(c) + 1]++;
			}
		}
	}
	for (size_t c = 0; c < ncols; c++) {
		start[c + 1] += start[c];
	}
	std::vector<int32_t> ys(start[ncols]);
	std::vector<uint32_t> fill(start.begin(), start.end() - 1);
	for (size_t i = 0; i < cells_x.size(); i++) {
		if (cells_y[i] <= top) {
			const int64_t c = col_of(cells_x[i], cells_z[i]);
			if (c >= 0) {
				ys[fill[size_t(c)]++] = cells_y[i];
			}
		}
	}

	// The runs, column by column, x then z (the reference order).
	std::vector<Run> runs;
	std::vector<uint32_t> first(ncols), count(ncols);
	for (int64_t ix = 0; ix < nx; ix++) {
		for (int64_t iz = 0; iz < nz; iz++) {
			const size_t c = size_t(ix * nz + iz);
			const int32_t x = int32_t(lo[0] + ix);
			const int32_t z = int32_t(lo[2] + iz);
			first[c] = uint32_t(runs.size());
			int32_t y = lo[1];
			std::sort(ys.begin() + start[c], ys.begin() + start[c + 1]);
			for (uint32_t k = start[c]; k < start[c + 1]; k++) {
				const int32_t f = ys[k];
				if (f > y) {
					runs.push_back({ x, z, y, f - 1 });
				}
				y = f + 1;
			}
			if (y <= top) {
				runs.push_back({ x, z, y, top });
			}
			count[c] = uint32_t(runs.size()) - first[c];
		}
	}

	// The fill, run to run: the bottom of every column first.
	std::vector<uint8_t> in(runs.size(), 0);
	std::vector<uint32_t> queue;
	queue.reserve(runs.size());
	for (size_t i = 0; i < runs.size(); i++) {
		if (runs[i].y0 == lo[1]) {
			in[i] = 1;
			queue.push_back(uint32_t(i));
		}
	}
	static const int32_t HORIZONTAL[4][2] = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } };
	for (size_t n = 0; n < queue.size(); n++) {
		const Run r = runs[queue[n]];
		for (const auto &d : HORIZONTAL) {
			const int64_t c = col_of(r.x + d[0], r.z + d[1]);
			if (c < 0) {
				continue;
			}
			for (uint32_t j = first[size_t(c)]; j < first[size_t(c)] + count[size_t(c)]; j++) {
				if (!in[j] && runs[j].y0 <= r.y1 && runs[j].y1 >= r.y0) {
					in[j] = 1;
					queue.push_back(j);
				}
			}
		}
	}
	out.reserve(queue.size());
	for (uint32_t i : queue) {
		out.push_back(runs[i]);
	}
	return out;
}

} // namespace mbcore
