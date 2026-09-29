// MarchingBlocks Paint for Unreal — THE WORLD EDITING TOOLS, as pure functions.
//
// The same tools as the MarchingBlocks tool: aim at the matter, a brush with a size and a shape, a
// selection (paint, rectangle or box — hollow or not), and what you do with it: fill, delete, extrude,
// grow, shrink, connected, move, copy, paste.
//
// Every function reads cells and RETURNS what changes; nothing is applied. The editor mode applies the
// result inside an undo transaction. Standard C++, no Unreal dependency: Tests/tools_conformance.json
// (computed by the MarchingBlocks tool itself) proves it behaves exactly like the tool; its rules_text
// says every rule in full. Everything is in FORMAT space: cell c covers [c, c+1], +Y is up.

#pragma once

#include "MBCore/MBRule.h"

#include <functional>
#include <vector>

// Unreal defines this per module (export here, import in MarchingBlocksPaintEditor, which calls these tools).
// ⚠ Without it the editor module does not link — measured on Unreal 5.8. Outside Unreal (core-runner) there
// is no module to export from.
#ifndef MARCHINGBLOCKSPAINT_API
#define MARCHINGBLOCKSPAINT_API
#endif

namespace MBPaint
{
	enum class EBrushTool { Add, Dig, Select };
	enum class EBrushShape { Sphere, Cube, Disc };
	enum class ESelectionOp { Delete, ExtrudeUp, ExtrudeDown, Grow, Shrink, Connected, Fill };

	/// What a tool changes: cells to set, cells to clear, and the selection AFTER.
	struct FChange
	{
		FCellSet Set;
		FCellSet Clear;
		FCellSet Selection;
		bool IsEmpty() const { return Set.empty() && Clear.empty(); }
	};

	struct FHit
	{
		bool bTouched = false;
		FCell Cell;
		/// The face the ray entered by. Zero when nothing was touched.
		FCell Normal;
	};

	using FIsFull = std::function<bool(const FCell&)>;

	namespace Tools
	{
		/// A box of more cells returns empty: two corners far apart by accident (a ray lost on the
		/// horizon) would otherwise freeze the editor.
		constexpr long long BoxVolumeMax = 262144;

		MARCHINGBLOCKSPAINT_API std::vector<FCell> Sorted(const FCellSet& Cells);

		/// THE RAY AGAINST THE MATTER — cell by cell (Amanatides & Woo), along the normalised direction.
		/// Aim at the CELLS, never the rendered tiles: those are sculpted and overflow their cell. The
		/// start cell is skipped; on a tie the lowest axis goes first. Ignore is walked through as empty:
		/// what the current Add stroke placed, or dragging would build a tower towards the camera.
		FHit Ray(const FIsFull& IsFull, double Ox, double Oy, double Oz, double Dx, double Dy, double Dz,
			double Reach, const FCellSet* Ignore = nullptr);

		/// Add places AGAINST the face it aims at; the other tools act ON the cell.
		MARCHINGBLOCKSPAINT_API FCell Anchor(EBrushTool Tool, const FHit& Hit);

		/// The cells of a brush, sorted. Size 1 is one cell; the radius is Size - 1. Disc: the sphere cut
		/// by the plane across the normal (horizontal without a normal).
		MARCHINGBLOCKSPAINT_API std::vector<FCell> Brush(const FCell& Center, const FCell& Normal, int Size, EBrushShape Shape);

		/// Add only sets empty cells, Dig only clears full ones, Select changes nothing.
		MARCHINGBLOCKSPAINT_API FChange Modify(EBrushTool Tool, const std::vector<FCell>& Targets, const FIsFull& IsFull);

		/// The operations on a selection. A selection may hold EMPTY cells: a box drawn in the air is a
		/// room not built yet. Operations that need matter filter it.
		MARCHINGBLOCKSPAINT_API FChange Operate(const FCellSet& Cells, const FCellSet& Selection, ESelectionOp Op);

		/// Every cell between two corners, bounds included. Hollow keeps the skin; a box thinner than
		/// three cells on an axis stays solid. Over BoxVolumeMax cells: empty — tell the user.
		MARCHINGBLOCKSPAINT_API FCellSet Box(const FCell& A, const FCell& B, bool bHollow);

		/// Moves the selected matter; overlapping moves are handled, and a move merges, never overwrites.
		MARCHINGBLOCKSPAINT_API FChange Move(const FCellSet& Cells, const FCellSet& Selection, const FCell& Offset);

		/// The selected matter relative to the middle of its bottom face (FLOOR of the half-sum), sorted.
		MARCHINGBLOCKSPAINT_API std::vector<FCell> Copy(const FCellSet& Cells, const FCellSet& Selection);

		/// Only empty cells are set; the selection becomes the pasted cells.
		MARCHINGBLOCKSPAINT_API FChange Paste(const FCellSet& Cells, const std::vector<FCell>& Clipboard, const FCell& AnchorCell);
	}
}
