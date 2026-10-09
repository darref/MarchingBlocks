// MarchingBlocks Paint for Unreal — WATER: the "water" key of world.json (water layers, their baked sheet, their
// sources), and THE WATER RULE — what each source becomes (sea, lake, river) deduced from the cells of every layer.
//
// Standard C++, no Unreal dependency: Tests/water_conformance.json (computed by the MarchingBlocks tool itself) proves
// it; its rules_text summarises the rule, and fluides.gd is the reference line by line: neighbours always in the order
// +x, -x, +z, -z, down, up, heaps tied by insertion order. The sea fill is the core's own (Noyau/ocean.h, a verbatim
// copy of gdextension/src/noyau/ocean.h, kept identical by core-runner). Water never changes cells.
//
// The SHEET drawn from these bodies is MBWaterMesh. WorldResumed is MarchingBlocks' own RESUMPTION (FL.monde with
// avant / changees): after a gesture, a source whose REACH (the box of every cell it looked at, grown by 1) holds no
// changed cell, under the same world box where it looked, is taken back as it was — the same result as computing
// everything again (core-runner checks it on random gestures), for a fraction of the time.

#pragma once

#include "MBCore/MBJson.h"
#include "MBCore/MBRule.h"

#include <cstdint>
#include <memory>
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

	/// The box of the full cells grown by 1 — its sides and bottom are the HORIZON. Empty when the world is.
	struct FWaterBox
	{
		bool bEmpty = true;
		FCell Lo, Hi;
		bool operator==(const FWaterBox& O) const { return bEmpty == O.bEmpty && (bEmpty || (Lo == O.Lo && Hi == O.Hi)); }
		bool operator!=(const FWaterBox& O) const { return !(*this == O); }
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

		/// Who computed it: 0 unknown; WorldResumed gives each body it computes a new Id and keeps the Id of a body it
		/// takes back (the sheet memory recognises it by that).
		uint64_t Id = 0;
		/// Its REACH: the box of every cell it looked at, grown by 1 (none on an error), and the world box it saw.
		bool bHasReach = false;
		FCell ReachLo, ReachHi;
		FWaterBox Box;
	};

	/// What WorldResumed hands to the next call: the sources, their bodies (shared: a body taken back is not copied),
	/// the sea's cells and the world box.
	struct FWaterState
	{
		bool bValid = false;
		std::vector<FCell> Sources;
		std::vector<std::shared_ptr<const FWaterBody>> Bodies;
		std::shared_ptr<const FCellSet> Sea;
		FWaterBox Box;
		/// How many bodies this call took back.
		int Reused = 0;
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

		/// Reads the "water" key of a decoded world.json. "" and Out filled, or the reason it is refused. Floor (optional):
		/// the top-level "water_floor" — where the ground of the tiles is drawn, 0.25 (inset), 0 (centred) or -0.25
		/// (outset); absent: 0.25 (worlds exported before it); any other value refuses the world.
		MARCHINGBLOCKSPAINT_API std::string Read(const FJsonValue& World, std::vector<FWaterLayer>& Out, double* Floor = nullptr);
		MARCHINGBLOCKSPAINT_API FJsonValue ToJson(const std::vector<FWaterLayer>& Layers);

		/// One source, against the water already there (Fixed: the sea).
		MARCHINGBLOCKSPAINT_API FWaterBody Source(const FCellSet& Cells, const FCell& S, const FCellSet& Fixed);

		/// THE WATER OF A WORLD: every source, the sea first (the FIRST source in the void; another one is refused,
		/// one_sea_only), then each other source against the sea only — their order does not matter.
		MARCHINGBLOCKSPAINT_API FWaterWorld World(const FCellSet& Cells, const std::vector<FCell>& Sources);

		/// The box of the full cells, grown by 1.
		MARCHINGBLOCKSPAINT_API FWaterBox BoxOf(const FCellSet& Cells);

		/// THE SAME WATER AS World, RESUMED (FL.monde with avant / changees): Before the previous result (nullptr or
		/// invalid: everything is computed), Changed the full cells added or removed since (nullptr: everything is
		/// computed). Box: the box of Cells if the caller has it. A source that is not the sea is taken back only when
		/// the sea itself was.
		MARCHINGBLOCKSPAINT_API FWaterState WorldResumed(const FCellSet& Cells, const std::vector<FCell>& Sources, const FWaterState* Before,
			const FCellSet* Changed, const FWaterBox* Box = nullptr);

		/// The cells in one set and not in the other.
		MARCHINGBLOCKSPAINT_API FCellSet ChangedBetween(const FCellSet& Before, const FCellSet& After);

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
