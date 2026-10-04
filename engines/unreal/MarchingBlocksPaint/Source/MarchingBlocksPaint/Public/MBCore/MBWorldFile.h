// MarchingBlocks Paint for Unreal — READS A MARCHINGBLOCKS WORLD (world.json), in standard C++.
//
// A painted world is a `<name>.mbworld/` folder made by MarchingBlocks: world.json, and one `.mbset`
// tileset folder per tile source, inside it. This file only reads world.json; making actors out of it is
// the Unreal layer's job (AMarchingBlocksWorldImport). Tests/world_conformance.json holds the reference
// cases every MarchingBlocks plugin must pass, and core-runner runs them against these very files.
//
// THE RULE (the README of every .mbworld says the same):
//   format   "marchingblocks-world"; version: refuse anything newer than 1.
//   layers   an array, in order. Each layer has a name (a string), visible (true or false), tileset (the
//            path of a tileset.json RELATIVE to world.json, or null: a layer without tiles — its cells
//            still travel; show that it has no tiles, never invent some), and cells: a flat array of
//            integers, x y z per cell, in FORMAT space (cell c covers [c, c+1], +Y up). Its length is a
//            multiple of 3. The same cell never appears twice.
//   Refuse the whole file, and say why, if any of these does not hold.

#pragma once

#include "MBCore/MBJson.h"
#include "MBCore/MBRule.h"

#include <string>
#include <vector>

#ifndef MARCHINGBLOCKSPAINT_API
#define MARCHINGBLOCKSPAINT_API
#endif

namespace MBPaint
{
	struct FWorldLayer
	{
		std::string Name;
		bool bVisible = true;
		/// False for a layer without tiles ("tileset": null). Its cells still travel.
		bool bHasTileset = false;
		/// The tileset.json path, RELATIVE to world.json, exactly as written. Empty when bHasTileset is false.
		std::string Tileset;
		/// In FORMAT space, in the order of the file.
		std::vector<FCell> Cells;
		/// The tileset rule's step 8: the draw's weights per key and the chosen variants (FVariantSettings).
		FVariantSettings Variants;
		/// The chosen variants, sorted by vertex (x, then y, then z): what the file says, in order.
		std::vector<std::pair<FCell, int64_t>> ChoicesSorted;
	};

	class MARCHINGBLOCKSPAINT_API FWorldFile
	{
	public:
		static constexpr const char* Format = "marchingblocks-world";
		static constexpr int SupportedVersion = 1;

		/// Reads a decoded world.json. Returns "" and fills OutLayers, or the reason the file is refused
		/// (OutLayers is then left empty: a refused file gives nothing, never half a world).
		static std::string Read(const FJsonValue& World, std::vector<FWorldLayer>& OutLayers);

		/// The same, from the text of world.json.
		static std::string ReadText(const std::string& Text, std::vector<FWorldLayer>& OutLayers);
	};
}
