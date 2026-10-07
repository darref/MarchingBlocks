// MarchingBlocks Paint for Unreal — WATER: the "water" key of world.json (water layers, their baked sheet, their
// sources), and THE WATER RULE — what each source becomes (sea, lake, river) deduced from the cells of every layer.
//
// Standard C++, no Unreal dependency: Tests/water_conformance.json (computed by the MarchingBlocks tool itself) proves
// it; its rules_text summarises the rule, and fluides.gd is the reference line by line: neighbours always in the order
// +x, -x, +z, -z, down, up, heaps tied by insertion order. The sea fill is the core's own (Noyau/ocean.h, a verbatim
// copy of gdextension/src/noyau/ocean.h, kept identical by core-runner). Water never changes cells.
//
// What this does NOT do: rebuild the water SHEET (eau_maillage.gd has no cases yet). The plugin shows the sheet baked by
// MarchingBlocks, and recomputes the water CELLS.

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
	struct FWaterLayer
	{
		std::string Name;
		bool bVisible = true;
		/// A SUGGESTION: "stylized", "clear", "reflective", "lava", "swamp", "acid" — an unknown look is accepted.
		std::string Look;
		/// The baked sheet, a .glb RELATIVE to world.json; bHasMesh false: nothing to draw.
		bool bHasMesh = false;
		std::string Mesh;
		/// Where the water was placed, format space, in order.
		std::vector<FCell> Sources;
	};

	enum class EWaterKind { None, Sea, Lake, River };
	enum class EWaterEnd { None, Leaves, Joins, Closed };
	enum class ECourseKind { Flow, Fall, Lake };

	struct FWaterLake
	{
		int Level = 0;
		FCellSet Cells;
	};

	struct FCourseStep
	{
		FCell Cell;
		ECourseKind Kind = ECourseKind::Flow;
		/// The lake's index for a Lake step, -1 otherwise.
		int Lake = -1;
	};

	/// What one source becomes.
	struct FWaterBody
	{
		EWaterKind Kind = EWaterKind::None;
		/// "" or in_matter, in_water, too_large, too_long, one_sea_only.
		std::string Error;
		/// Sea and lake: the level (the highest row of water cells).
		int Level = 0;
		EWaterEnd End = EWaterEnd::None;
		/// A sea's or a lake's cells; a river's LAKES' cells.
		FCellSet Water;
		std::vector<FWaterLake> Lakes;
		std::vector<FCourseStep> Course;
	};

	struct FWaterWorld
	{
		/// One per source, in order.
		std::vector<FWaterBody> Bodies;
		FCellSet Sea;
	};

	namespace Water
	{
		constexpr int VolumeMax = 64 * 64 * 64;
		constexpr int StepsMax = 4096;
		constexpr int OverflowReach = 4;

		/// Reads the "water" key of a decoded world.json. "" and Out filled, or the reason it is refused.
		MARCHINGBLOCKSPAINT_API std::string Read(const FJsonValue& World, std::vector<FWaterLayer>& Out);
		MARCHINGBLOCKSPAINT_API FJsonValue ToJson(const std::vector<FWaterLayer>& Layers);

		/// One source, against the water already there (Fixed: the sea).
		MARCHINGBLOCKSPAINT_API FWaterBody Source(const FCellSet& Cells, const FCell& S, const FCellSet& Fixed);

		/// THE WATER OF A WORLD: every source, the sea first (the FIRST source in the void; another one is refused,
		/// one_sea_only), then each other source against the sea only — their order does not matter.
		MARCHINGBLOCKSPAINT_API FWaterWorld World(const FCellSet& Cells, const std::vector<FCell>& Sources);

		/// RIVER WIDTH: Width sources side by side across the first horizontal step of the river placed at S (centred,
		/// one more on the + side when even), S first; only neighbours that are rivers stay.
		MARCHINGBLOCKSPAINT_API std::vector<FCell> SourcesInWidth(const FCellSet& Cells, const FCell& S, int Width, const FCellSet& Fixed);

		/// The water cells whose cell above is neither water nor full.
		MARCHINGBLOCKSPAINT_API FCellSet Surface(const FCellSet& WaterCells, const FCellSet& Cells);

		/// The water cells down to the floor (the cell included); -1 when the water reaches the bottom without a floor.
		MARCHINGBLOCKSPAINT_API int Depth(const FCellSet& WaterCells, const FCellSet& Cells, const FCell& C);

		MARCHINGBLOCKSPAINT_API const char* KindName(EWaterKind Kind);
		MARCHINGBLOCKSPAINT_API const char* EndName(EWaterEnd End);
		MARCHINGBLOCKSPAINT_API const char* CourseName(ECourseKind Kind);
	}
}
