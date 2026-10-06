// MarchingBlocks core — cell sets and column tops.
//
// Plain standard C++17: no Godot, no Unreal, no Unity. This is the part of the core meant to be shared
// by the application and the three engine plugins (see CLAUDE.md §0, « le cœur C++ »), so it is written
// in English, like everything a plugin buyer can read.
//
// A cell is three signed integers. They are packed into one 64-bit key, 21 bits per axis, so a world
// may span ±1 048 575 cells on each axis — far beyond what a painted world reaches.
#pragma once

#include <cstdint>
#include <cstddef>
#include <algorithm>
#include <vector>

namespace mbcore {

struct Cell {
	int32_t x = 0, y = 0, z = 0;
};

constexpr int32_t AXIS_OFFSET = 1 << 20;
constexpr uint64_t AXIS_MASK = (uint64_t(1) << 21) - 1;

inline uint64_t pack(int32_t x, int32_t y, int32_t z) {
	return ((uint64_t(uint32_t(x + AXIS_OFFSET)) & AXIS_MASK) << 42) |
			((uint64_t(uint32_t(y + AXIS_OFFSET)) & AXIS_MASK) << 21) |
			(uint64_t(uint32_t(z + AXIS_OFFSET)) & AXIS_MASK);
}

inline uint64_t pack_column(int32_t x, int32_t z) {
	return pack(x, 0, z);
}

inline bool in_range(int32_t v) {
	return v > -AXIS_OFFSET && v < AXIS_OFFSET - 1;
}

// An open-addressing hash map from packed keys to a value (a 32-bit int for cells, a placement for vertices).
// Linear probing, power-of-two capacity, never shrinks. Removal uses backward-shift deletion, so lookups never
// meet tombstones.
template <class V>
class KeyMap {
public:
	static constexpr uint64_t EMPTY = ~uint64_t(0);

	KeyMap() { _rehash(16); }

	size_t size() const { return _count; }
	bool empty() const { return _count == 0; }

	void reserve(size_t n) {
		size_t cap = 16;
		while (cap * 7 < n * 10) {
			cap <<= 1;
		}
		if (cap > _keys.size()) {
			_rehash(cap);
		}
	}

	void clear() {
		std::fill(_keys.begin(), _keys.end(), EMPTY);
		_count = 0;
	}

	// The value at `key`, or `missing` when absent.
	V get(uint64_t key, V missing) const {
		size_t i = _slot(key);
		while (true) {
			const uint64_t k = _keys[i];
			if (k == key) {
				return _values[i];
			}
			if (k == EMPTY) {
				return missing;
			}
			i = (i + 1) & _mask;
		}
	}

	// A pointer to the value at `key`, or nullptr; valid until the next insertion or removal.
	const V *find(uint64_t key) const {
		size_t i = _slot(key);
		while (true) {
			const uint64_t k = _keys[i];
			if (k == key) {
				return &_values[i];
			}
			if (k == EMPTY) {
				return nullptr;
			}
			i = (i + 1) & _mask;
		}
	}

	bool has(uint64_t key) const {
		size_t i = _slot(key);
		while (true) {
			const uint64_t k = _keys[i];
			if (k == key) {
				return true;
			}
			if (k == EMPTY) {
				return false;
			}
			i = (i + 1) & _mask;
		}
	}

	// Sets the value; returns true when the key was new.
	bool set(uint64_t key, V value) {
		if ((_count + 1) * 10 > _keys.size() * 7) {
			_rehash(_keys.size() * 2);
		}
		size_t i = _slot(key);
		while (true) {
			const uint64_t k = _keys[i];
			if (k == key) {
				_values[i] = value;
				return false;
			}
			if (k == EMPTY) {
				_keys[i] = key;
				_values[i] = value;
				_count++;
				return true;
			}
			i = (i + 1) & _mask;
		}
	}

	// Keeps the larger value (used for column tops).
	void set_max(uint64_t key, V value) {
		if ((_count + 1) * 10 > _keys.size() * 7) {
			_rehash(_keys.size() * 2);
		}
		size_t i = _slot(key);
		while (true) {
			const uint64_t k = _keys[i];
			if (k == key) {
				if (value > _values[i]) {
					_values[i] = value;
				}
				return;
			}
			if (k == EMPTY) {
				_keys[i] = key;
				_values[i] = value;
				_count++;
				return;
			}
			i = (i + 1) & _mask;
		}
	}

	bool erase(uint64_t key) {
		size_t i = _slot(key);
		while (true) {
			const uint64_t k = _keys[i];
			if (k == EMPTY) {
				return false;
			}
			if (k == key) {
				break;
			}
			i = (i + 1) & _mask;
		}
		// Backward-shift deletion.
		size_t hole = i;
		size_t j = i;
		while (true) {
			j = (j + 1) & _mask;
			const uint64_t k = _keys[j];
			if (k == EMPTY) {
				break;
			}
			const size_t home = _slot(k);
			// Move k into the hole if its home is not cyclically in (hole, j].
			const bool between = (hole <= j) ? (home > hole && home <= j) : (home > hole || home <= j);
			if (!between) {
				_keys[hole] = k;
				_values[hole] = _values[j];
				hole = j;
			}
		}
		_keys[hole] = EMPTY;
		_count--;
		return true;
	}

	template <typename F>
	void for_each(F &&f) const {
		for (size_t i = 0; i < _keys.size(); i++) {
			if (_keys[i] != EMPTY) {
				f(_keys[i], _values[i]);
			}
		}
	}

private:
	std::vector<uint64_t> _keys;
	std::vector<V> _values;
	size_t _mask = 0;
	size_t _count = 0;

	size_t _slot(uint64_t key) const {
		uint64_t h = key * 0x9E3779B97F4A7C15ull;
		h ^= h >> 29;
		return size_t(h) & _mask;
	}

	void _rehash(size_t capacity) {
		std::vector<uint64_t> old_keys;
		std::vector<V> old_values;
		old_keys.swap(_keys);
		old_values.swap(_values);
		_keys.assign(capacity, EMPTY);
		_values.assign(capacity, V());
		_mask = capacity - 1;
		_count = 0;
		for (size_t i = 0; i < old_keys.size(); i++) {
			if (old_keys[i] != EMPTY) {
				set(old_keys[i], old_values[i]);
			}
		}
	}
};

using CellMap = KeyMap<int32_t>;

inline Cell unpack(uint64_t k) {
	Cell c;
	c.x = int32_t((k >> 42) & AXIS_MASK) - AXIS_OFFSET;
	c.y = int32_t((k >> 21) & AXIS_MASK) - AXIS_OFFSET;
	c.z = int32_t(k & AXIS_MASK) - AXIS_OFFSET;
	return c;
}

} // namespace mbcore
