// MarchingBlocks Paint for Unreal — THE PLACEMENT RULE, implemented from the tileset format itself.
//
// This file reads nothing but a tileset manifest (tileset.json): its table, corners, classes, context
// and copies. It is standard C++ with no Unreal dependency: Tests/conformance.json (the reference cases,
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
//   5. the copy is picked by a spatial hash of v in 64-bit arithmetic, so a world always looks the same.
//      It is computed UNSIGNED here: in C++ a signed overflow is undefined, an unsigned one wraps, and
//      the low bits the mask keeps are the same either way;
//   6. a missing key gives an empty tile name — show an error marker, never fill in.

#pragma once

#include "MBCore/MBJson.h"

#include <array>
#include <cstddef>
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

	class FRule
	{
	public:
		static constexpr const char* Format = "marchingblocks-tileset";
		static constexpr int SupportedVersion = 1;

		/// "" when the manifest is usable, otherwise the reason. A NEWER format is refused: its rule may
		/// mean something else, and placing anyway would be a silent lie.
		static std::string CheckManifest(const FJsonValue& Manifest);

		/// Tiles: {key: [tile names]} — pass nullptr to use the manifest's own "tiles".
		/// Call CheckManifest first: a manifest it refuses gives an empty rule.
		explicit FRule(const FJsonValue& Manifest, const FJsonValue* Tiles = nullptr);

		/// Every placement for one layer, sorted by vertex. A layer only ever reads its own cells.
		std::vector<FPlacement> Placements(const FCellSet& Cells) const;

		std::array<FCell, 8> Corners;
		FCell PieceOffset = FCell(1, 1, 1);
		std::unordered_map<std::string, std::vector<std::string>> Tiles;

	private:
		bool HasTile(const std::string& Key) const;
		bool IsOutdoor(const FCellSet& Cells, const FCell& V, int Top) const;

		std::array<int, 256> TableClass{};
		std::array<int, 256> TableTurns{};
		std::vector<std::string> ClassIds;
		std::vector<bool> OutdoorPossible;
		int Band = 2;
		std::string OutdoorSuffix = "_outdoor";
		std::array<int64_t, 3> Primes{};
		int64_t Mask = 0;
	};
}
