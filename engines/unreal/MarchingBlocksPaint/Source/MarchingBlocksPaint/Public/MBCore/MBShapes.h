// MarchingBlocks Paint for Unreal — THE SPECIAL SHAPES: tunnel, well, bridge, balcony and stairs.
//
// A tunnel digs into a wall and a well into a floor or a ceiling, square to it; in one click they go
// through to the next cave (or Length cells deep), and Connect joins two faces anywhere — slanted walls
// included — with both ends open. A bridge builds a deck across the air from a wall; a balcony puts a
// slab with its rail against a wall; stairs climb a wall to the clicked height, or join two floors.
//
// Standard C++, no Unreal dependency: Tests/tools_conformance.json (computed by the MarchingBlocks tool)
// proves it gives exactly the tool's cells; its rules_text says every rule in full. Everything is
// INTEGER (cell centres, squared distances in 64 bits): no rounding can differ between languages.
// FORMAT space: cell c covers [c, c+1], +Y is up.

#pragma once

#include "MBCore/MBRule.h"

#include <string>
#include <vector>

#ifndef MARCHINGBLOCKSPAINT_API
#define MARCHINGBLOCKSPAINT_API
#endif

namespace MBPaint
{
	enum class ESpecialShape { Tunnel, Well, Bridge, Balcony, Stairs };
	enum class EShapeProfile { Round, Square, Arch };

	/// What a special shape asks for.
	struct FShapeRequest
	{
		ESpecialShape Shape = ESpecialShape::Tunnel;
		FCell A;
		FCell FaceA;
		bool bConnect = false;
		FCell B;
		FCell FaceB;
		EShapeProfile Profile = EShapeProfile::Round;
		int Size = 2;
		int Length = 8;
		bool bRail = true;
		/// One-click stairs: how deep each step is, 1 to Shapes::StepMax cells.
		int Step = 2;
	};

	/// What it changes, or why it refuses (Error is empty when it does not).
	struct FShapeResult
	{
		FCellSet Set;
		FCellSet Clear;
		std::string Error;
		bool bOpened = false;
		int Repaired = 0;
		bool IsEmpty() const { return Set.empty() && Clear.empty(); }
	};

	namespace Shapes
	{
		constexpr int LengthMax = 64;
		constexpr int SpanMax = 128;
		constexpr int StepMax = 4;
		constexpr long long VolumeMax = 262144;

		MARCHINGBLOCKSPAINT_API bool Digs(ESpecialShape Shape);

		/// The normal of a wall, ESTIMATED: a 45° wall is a staircase of cells whose faces say ±X or ±Z,
		/// never the slant. Sum the exposed horizontal faces of the 3×3×3 window, snap to eight directions.
		MARCHINGBLOCKSPAINT_API FCell WallNormal(const FCellSet& Cells, const FCell& C, const FCell& Face);

		/// The normal a shape keeps for a clicked face, or zero when that face does not suit it. Connected
		/// stairs want a floor (the top face), every other wall shape a horizontal face.
		MARCHINGBLOCKSPAINT_API FCell NormalFor(ESpecialShape Shape, const FCellSet& Cells, const FCell& C, const FCell& Face,
			bool bConnect = false);

		/// The error for an end that NormalFor refuses.
		MARCHINGBLOCKSPAINT_API const char* EndError(ESpecialShape Shape, bool bConnect);

		/// The cells crossed by the axis from P0 to P1, one axis per step; a tie goes to the lowest axis.
		MARCHINGBLOCKSPAINT_API std::vector<FCell> AxisWalk(const FCell& P0, const FCell& P1);

		MARCHINGBLOCKSPAINT_API FShapeResult Build(const FCellSet& Cells, const FShapeRequest& Request);
	}
}
