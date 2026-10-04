// MarchingBlocks Paint for Unreal — THE PLACEMENT RULE, implemented from the tileset format itself.
//
// This file reads nothing but a tileset manifest (tileset.json): its table, corners, classes and
// context. It is standard C++ with no Unreal dependency: Tests/conformance.json (the reference cases,
// shipped with every MarchingBlocks plugin) proves it places exactly what the MarchingBlocks tool places.
//
// Everything here is in FORMAT space: right-handed, +Y up, 1 unit = 1 cell (glTF). Converting to
// Unreal's frame (left-handed, +Z up, centimetres) is the tileset loader's job, measured on the frame
// marker — never assumed.
//
// The rule, in short (the manifest's rules_text says it in full):
//   1. a full cell c touches the 8 vertices c - corners[t];
//   2. at vertex v, bit t is set when cell v + corners[t] is full;
//   3. table[bits] gives [class, quarter_turns]; class -1 places nothing;
//   4. an outdoor-capable class is OUTDOOR when no empty cell among the 8 has a full cell above it,
//      from v.y + band up to the highest full cell of the layer; outdoor tries "<id>_outdoor" first;
//   5. each key has exactly one tile, tiles[key];
//   6. a missing key gives an empty tile name — show an error marker, never fill in;
//   7. layers: the union of the visible layers, a vertex placed by the first layer owning one of its cells;
//   8. variants (optional): a key may have variants (the manifest's "variants"); the layer that places v
//      picks one — its CHOICE at v if it has one, otherwise a weighted draw by a hash of v, never random.

#pragma once

#include "MBCore/MBJson.h"

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace MBPaint
{
	struct FCell
	{
		int X = 0;
		int Y = 0;
		int Z = 0;

		FCell() = default;
		FCell(int InX, int InY, int InZ) : X(InX), Y(InY), Z(InZ) {}

		FCell operator+(const FCell& O) const { return FCell(X + O.X, Y + O.Y, Z + O.Z); }
		FCell operator-(const FCell& O) const { return FCell(X - O.X, Y - O.Y, Z - O.Z); }
		bool operator==(const FCell& O) const { return X == O.X && Y == O.Y && Z == O.Z; }
		bool operator!=(const FCell& O) const { return !(*this == O); }
		/// x, then y, then z — the order every sorted list of the format uses.
		bool operator<(const FCell& O) const { return X != O.X ? X < O.X : Y != O.Y ? Y < O.Y : Z < O.Z; }
		bool IsZero() const { return X == 0 && Y == 0 && Z == 0; }
	};

	struct FCellHash
	{
		size_t operator()(const FCell& C) const
		{
			return static_cast<size_t>((static_cast<unsigned>(C.X) * 73856093u) ^ (static_cast<unsigned>(C.Y) * 19349663u)
				^ (static_cast<unsigned>(C.Z) * 83492791u));
		}
	};

	using FCellSet = std::unordered_set<FCell, FCellHash>;

	struct FPlacement
	{
		FCell Vertex;
		/// The tile name, or empty when the tileset lacks the tile the rule asks for.
		std::string Tile;
		/// Quarter turns about +Y, right-hand rule (+Z turns towards +X), in format space.
		int QuarterTurns = 0;
	};

	class FRule;

	/// A layer's variant settings (the tileset rule, step 8): the weights of the draw per key — [base, variant
	/// 1, …], a missing entry is 1, a negative one 0 — and the variant CHOSEN at a vertex (0 is the base tile).
	struct FVariantSettings
	{
		std::unordered_map<std::string, std::vector<int64_t>> Weights;
		std::unordered_map<FCell, int64_t, FCellHash> Choices;
	};

	/// One layer of a world, for FRule::PlacementsLayered (the tileset rule, step 7).
	struct FLayerInput
	{
		const FCellSet* Cells = nullptr;
		bool bVisible = true;
		/// This layer's tiles — nullptr when its placements are not wanted (a layer without tiles, or another
		/// actor's layer): its cells still count in the union, its list stays empty.
		const FRule* Rule = nullptr;
		/// This layer's variant weights and choices (step 8) — nullptr for none.
		const FVariantSettings* Variants = nullptr;
	};

	class FRule
	{
	public:
		static constexpr const char* Format = "marchingblocks-tileset";
		static constexpr int SupportedVersion = 1;

		/// "" when the manifest is usable, otherwise the reason. A NEWER format is refused: its rule may
		/// mean something else, and placing anyway would be a silent lie.
		static std::string CheckManifest(const FJsonValue& Manifest);

		/// "" when every key of Tiles names exactly one tile (one tile per key), otherwise the reason.
		static std::string CheckTiles(const FJsonValue& Tiles);

		/// Tiles: {key: tile name} — pass nullptr to use the manifest's own "tiles". InVariants: {key: [tile
		/// names]} — nullptr to use the manifest's own "variants" (step 8).
		/// Call CheckManifest first: a manifest it refuses gives an empty rule.
		explicit FRule(const FJsonValue& Manifest, const FJsonValue* InTilesOverride = nullptr,
			const FJsonValue* InVariants = nullptr);

		/// Every placement for one layer alone, sorted by vertex. InSettings: its variant weights and choices.
		std::vector<FPlacement> Placements(const FCellSet& Cells, const FVariantSettings* InSettings = nullptr) const;

		/// Step 8: the tile placed at V for Key, whose base tile is Base. Same world, same tiles: the draw is a
		/// hash of V, never random.
		static std::string VariantTile(const FCell& V, const std::string& Key, const std::string& Base,
			const std::vector<std::string>* List, const FVariantSettings* InSettings);

		/// The vertex hash of step 8, on 64-bit integers.
		static int64_t VertexHash(const FCell& V);

		/// Every placement of a world of LAYERS (step 7), one sorted list per layer, in the same order. The
		/// layers are in PRIORITY order (the first is the highest): steps 1-4 read the union of the visible
		/// layers (a cell in two layers belongs to the first), and a vertex is placed by the first layer owning
		/// one of its 8 cells, with that layer's tiles.
		static std::vector<std::vector<FPlacement>> PlacementsLayered(const std::vector<FLayerInput>& Layers);

		std::array<FCell, 8> Corners;
		FCell PieceOffset = FCell(1, 1, 1);
		std::unordered_map<std::string, std::string> Tiles;
		/// {key: [variant 1, variant 2, …]} — the manifest's "variants" (step 8); empty without.
		std::unordered_map<std::string, std::vector<std::string>> Variants;

	private:
		bool HasTile(const std::string& Key) const;
		bool IsOutdoor(const FCellSet& Cells, const FCell& V, int Top) const;

		std::array<int, 256> TableClass{};
		std::array<int, 256> TableTurns{};
		std::vector<std::string> ClassIds;
		std::vector<bool> OutdoorPossible;
		int Band = 2;
		std::string OutdoorSuffix = "_outdoor";
	};
}
