// MarchingBlocks Paint for Unreal — THE EDITING OPERATIONS of MarchingBlocks 0.9: Extrude (place / extend / shift,
// up / down / facing), Shrink (the edge of the selection), Widen (flat), the Select brush with empty cells, and
// Room from selection (Shapes::RoomFromSelection, in MBShapes.h).
//
// Every function reads cells and RETURNS what changes; nothing is applied. Standard C++, no Unreal dependency:
// Tests/editing_conformance.json (computed by the MarchingBlocks tool itself) proves it behaves exactly like the
// tool; its rules_text says every rule in full. FORMAT space: cell c covers [c, c+1], +Y is up.

#pragma once

#include "MBCore/MBTools.h"

#include <vector>

#ifndef MARCHINGBLOCKSPAINT_API
#define MARCHINGBLOCKSPAINT_API
#endif

namespace MBPaint
{
	/// Which way Extrude goes. Facing: the direction most selected cells face (empty in front, matter behind).
	enum class EExtrudeDirection { Up, Down, Facing };
	/// Place (click): set a cell in front of every full cell of the base. Extend (Shift + click, "Extend selection"):
	/// nothing set, the selection grows by one step. Shift (Alt + click): nothing set, the selection moves one step.
	enum class EExtrudeMode { Place, Extend, Shift };

	struct FExtrudeResult
	{
		FCellSet Set;
		FCellSet Clear;
		/// The selection AFTER.
		FCellSet Selection;
		/// The step taken; zero when nothing changes. The grid floor follows Step.Y.
		FCell Step;
	};

	namespace Editing
	{
		/// EXTRUDE. The BASE is the selection or, with none, the full cells at y = Floor.
		MARCHINGBLOCKSPAINT_API FExtrudeResult Extrude(const FCellSet& Cells, int Floor, EExtrudeDirection Direction,
			const FCellSet& Selection, EExtrudeMode Mode);

		/// The direction Facing chooses (zero: none) — among up, down, +x, -x, +z, -z, that order breaking ties.
		MARCHINGBLOCKSPAINT_API FCell FacingStep(const FCellSet& Cells, int Floor, const FCellSet& Selection);

		/// SHRINK: the selection without its edge (a cell where, on some axis, the selection goes on one side and
		/// stops on the other). Full or empty cells alike.
		MARCHINGBLOCKSPAINT_API FCellSet ShrinkEdge(const FCellSet& Selection);

		/// WIDEN, FLAT: the selection plus the four horizontal neighbours of every cell, empty cells included.
		MARCHINGBLOCKSPAINT_API FCellSet WidenFlat(const FCellSet& Selection);

		/// THE SELECT BRUSH, in place: the brush's cells join the selection — only the full ones, or all with
		/// bIncludeEmpty ("Select empty cells too"); bDeselect (the inverse gesture) removes them, full or empty.
		MARCHINGBLOCKSPAINT_API void SelectBrush(FCellSet& Selection, const std::vector<FCell>& Targets, const FIsFull& IsFull,
			bool bIncludeEmpty, bool bDeselect);
	}
}
