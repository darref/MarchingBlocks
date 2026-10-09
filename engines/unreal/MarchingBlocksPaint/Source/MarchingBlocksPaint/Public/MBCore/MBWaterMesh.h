// MarchingBlocks Paint for Unreal — THE WATER SHEET: what the water rule deduced (MBWater), drawn as triangles —
// the same sheet MarchingBlocks bakes into water/<name>.glb, rebuilt here when you paint.
//
// Standard C++, no Unreal dependency. Tests/water_mesh_conformance.json (computed by the MarchingBlocks tool itself)
// proves it, as a BAG of triangles (no order, rotations allowed, never a reflection); its rules_text summarises the
// rule, and eau_maillage.gd (tableaux_du_maillage) is the reference line by line.
//
// THE WATER CONTRACT, carried by every vertex (any water material may read it; the six presets do):
//   Color r, g — the flow along x and z, from [-1, 1] to [0, 1] (0.5 0.5: still water);
//   Color b    — the KIND: 0 still (lake, sea), 0.5 river, 0.75 foam, 1 waterfall;
//   Color a    — the depth below the surface / 8, capped at 1 (still water, river), or the amount of foam;
//   UV         — x, z of the world on flat water; across / height on a waterfall, so that it flows down.
// Positions and normals are in FORMAT space (right-handed, +Y up, cell c covers [c, c + 1]). Triangles are listed
// COUNTER-CLOCKWISE seen from the front, as in glTF. Draw order: waterfall sheets, flat water, then the foam LAST
// (rings, sprays, springs: transparent, over the rest).

#pragma once

#include "MBCore/MBWater.h"

#include <cstdint>
#include <utility>
#include <vector>

#ifndef MARCHINGBLOCKSPAINT_API
#define MARCHINGBLOCKSPAINT_API
#endif

namespace MBPaint
{
	struct FWaterVertex
	{
		float Position[3] = {0.f, 0.f, 0.f};
		float Normal[3] = {0.f, 0.f, 0.f};
		float Color[4] = {0.f, 0.f, 0.f, 0.f};
		float UV[2] = {0.f, 0.f};
	};

	/// One water layer's sheet. No triangle: nothing to draw.
	struct FWaterMesh
	{
		std::vector<FWaterVertex> Vertices;
		/// Three per triangle, counter-clockwise seen from the front.
		std::vector<uint32_t> Indices;
		bool IsEmpty() const { return Indices.empty(); }
	};

	/// A flat rectangle of still water, [X0, X1] x [Z0, Z1] at height H (what a body's sheet is made of).
	struct FWaterFlat
	{
		double X0 = 0.0, X1 = 0.0, Z0 = 0.0, Z1 = 0.0, H = 0.0;
		float Color[4] = {0.f, 0.f, 0.f, 0.f};
	};

	/// What a rebuild keeps for the next one (one per water layer): the sheet rectangles of each body, by its place in
	/// the layer and its Id — a body taken back by Water::WorldResumed (same Id) has the same rectangles.
	struct FWaterMeshMemory
	{
		std::vector<std::pair<uint64_t, std::vector<FWaterFlat>>> Sheets;
		/// How many bodies' sheets the last Build took back.
		int Reused = 0;
		/// The floor the sheets were made for: another floor, nothing is taken back (the heights changed).
		double Floor = 0.25;
	};

	namespace WaterMesh
	{
		// The constants (the conformance file's "constants" must be these).
		constexpr double Surface = 0.7;      // a sheet at its row + 0.7 (inset floor)
		constexpr double River = -0.15;      // a band at its cell - 0.15 (inset floor)
		// THE FLOOR r (world.json "water_floor"): where the ground of the tiles is drawn - the top of a full cell y - 1 is
		// seen at y - r (0.25 inset, 0 centred, -0.25 outset). Every height follows it; at r = 0.25 they are the above.
		constexpr double FloorDefault = 0.25;
		constexpr double Thin = 0.05;
		constexpr double AboveFloor = 0.1;
		/// A still sheet at its top row + SurfaceAt(r).
		inline double SurfaceAt(double R) { return 1.0 - (R < 0.0 ? -R : R) - Thin; }
		/// A river band at its cell + RiverAt(r).
		inline double RiverAt(double R) { return AboveFloor - R; }
		/// A waterfall leaves the cliff's plane moved by AdvanceAt(r) (it keeps its place in front of inset rock).
		inline double AdvanceAt(double R) { return FloorDefault - R; }
		constexpr double Overlap = 0.45;     // a sheet runs that far under the rock beside it
		constexpr double Sheet = 0.35;       // how far a waterfall leaves its cliff
		constexpr double Arc = 0.7;          // over this drop it curves
		constexpr double Flare = 0.04;       // then spreads by this much per cell of drop
		constexpr double FlareMax = 0.2;
		constexpr double IntoRock = 0.4;     // a free end goes that far into the rock
		constexpr double Rounding = 0.35;    // over this width a free end rounds off
		constexpr double Overhang = 0.1;     // a free end passes its cell by this much
		constexpr double Churn = 0.85;       // the foam ring's width
		constexpr double Spray = 0.9;        // the spray's height
		constexpr double FoamRise = 1.3;     // the foam grows from 0 to 1 over this height above the water
		constexpr double Horizon = 2000.0;   // the sea reaches that far
		constexpr double Spring = 0.7;       // a spring's radius
		constexpr double SpringDome = 0.08;  // and its dome

		constexpr float KindStill = 0.0f;
		constexpr float KindRiver = 0.5f;
		constexpr float KindFoam = 0.75f;
		constexpr float KindFall = 1.0f;

		/// THE SHEET OF ONE WATER LAYER: its bodies (what Water::World made of its sources, in order; nullptr or an error
		/// draws nothing) against the full cells of EVERY layer, Box being their box grown by 1 (Water::BoxOf).
		/// Memory (optional): kept by the caller from one rebuild to the next — same result, fewer sheets recomputed.
		/// Floor: the world's floor r (see FloorDefault).
		MARCHINGBLOCKSPAINT_API FWaterMesh Build(const std::vector<const FWaterBody*>& Bodies, const FCellSet& Cells, const FWaterBox& Box,
			FWaterMeshMemory* Memory = nullptr, double Floor = FloorDefault);

		/// The same, from bodies held by value (the box is computed).
		MARCHINGBLOCKSPAINT_API FWaterMesh Build(const std::vector<FWaterBody>& Bodies, const FCellSet& Cells, double Floor = FloorDefault);

		/// The drawn surface of a still water W of level L: its cells whose cell above is neither water nor full, plus its
		/// cells at row L under a full cell (under a floating storey or a ceiling).
		MARCHINGBLOCKSPAINT_API std::vector<FCell> DrawnSurface(const FCellSet& W, const FCellSet& Cells, int Level);
	}
}
