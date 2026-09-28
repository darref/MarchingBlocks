// MarchingBlocks Paint for Unreal — the world editing tools (see MBTools.h).

#include "MBCore/MBTools.h"

#include <algorithm>
#include <cmath>
#include <limits>

namespace MBPaint
{
	namespace Tools
	{
		namespace
		{
			const FCell ToolFaces[6] = {FCell(1, 0, 0), FCell(-1, 0, 0), FCell(0, 1, 0), FCell(0, -1, 0), FCell(0, 0, 1), FCell(0, 0, -1)};

			int FloorHalf(int Sum)
			{
				return static_cast<int>(std::floor(static_cast<double>(Sum) / 2.0));
			}
		}

		std::vector<FCell> Sorted(const FCellSet& Cells)
		{
			std::vector<FCell> List(Cells.begin(), Cells.end());
			std::sort(List.begin(), List.end());
			return List;
		}

		FHit Ray(const FIsFull& IsFull, double Ox, double Oy, double Oz, double Dx, double Dy, double Dz,
			double Reach, const FCellSet* Ignore)
		{
			const FHit None;
			const double Length = std::sqrt(Dx * Dx + Dy * Dy + Dz * Dz);
			if (Length < 1e-6) return None;
			const double O[3] = {Ox, Oy, Oz};
			const double D[3] = {Dx / Length, Dy / Length, Dz / Length};
			int C[3] = {static_cast<int>(std::floor(Ox)), static_cast<int>(std::floor(Oy)), static_cast<int>(std::floor(Oz))};
			int Step[3] = {0, 0, 0};
			const double Inf = std::numeric_limits<double>::infinity();
			double TMax[3] = {Inf, Inf, Inf};
			double TDelta[3] = {Inf, Inf, Inf};
			for (int A = 0; A < 3; ++A)
			{
				if (std::fabs(D[A]) < 1e-12) continue;
				Step[A] = D[A] > 0.0 ? 1 : -1;
				const double Edge = D[A] > 0.0 ? static_cast<double>(C[A] + 1) : static_cast<double>(C[A]);
				TMax[A] = (Edge - O[A]) / D[A];
				TDelta[A] = std::fabs(1.0 / D[A]);
			}
			while (true)
			{
				// The nearest boundary; on a tie, the lowest axis.
				int A = 0;
				if (TMax[1] < TMax[A]) A = 1;
				if (TMax[2] < TMax[A]) A = 2;
				if (TMax[A] > Reach) return None;
				C[A] += Step[A];
				TMax[A] += TDelta[A];
				const FCell Cell(C[0], C[1], C[2]);
				if ((Ignore == nullptr || Ignore->count(Cell) == 0) && IsFull(Cell))
				{
					int N[3] = {0, 0, 0};
					N[A] = -Step[A];
					FHit Hit;
					Hit.bTouched = true;
					Hit.Cell = Cell;
					Hit.Normal = FCell(N[0], N[1], N[2]);
					return Hit;
				}
			}
		}

		FCell Anchor(EBrushTool Tool, const FHit& Hit)
		{
			return Tool == EBrushTool::Add && Hit.bTouched ? Hit.Cell + Hit.Normal : Hit.Cell;
		}

		std::vector<FCell> Brush(const FCell& Center, const FCell& Normal, int Size, EBrushShape Shape)
		{
			const int R = std::max(0, Size - 1);
			const FCell N = Normal.IsZero() ? FCell(0, 1, 0) : Normal;
			std::vector<FCell> Cells;
			for (int X = -R; X <= R; ++X)
				for (int Y = -R; Y <= R; ++Y)
					for (int Z = -R; Z <= R; ++Z)
					{
						const int L2 = X * X + Y * Y + Z * Z;
						bool bInside = true;
						if (Shape == EBrushShape::Sphere) bInside = L2 <= R * R;
						else if (Shape == EBrushShape::Disc) bInside = L2 <= R * R && X * N.X + Y * N.Y + Z * N.Z == 0;
						if (bInside) Cells.push_back(Center + FCell(X, Y, Z));
					}
			std::sort(Cells.begin(), Cells.end());
			return Cells;
		}

		FChange Modify(EBrushTool Tool, const std::vector<FCell>& Targets, const FIsFull& IsFull)
		{
			FChange Change;
			for (const FCell& C : Targets)
			{
				const bool bFull = IsFull(C);
				if (Tool == EBrushTool::Add && !bFull) Change.Set.insert(C);
				else if (Tool == EBrushTool::Dig && bFull) Change.Clear.insert(C);
			}
			return Change;
		}

		FChange Operate(const FCellSet& Cells, const FCellSet& Selection, ESelectionOp Op)
		{
			FChange Change;
			switch (Op)
			{
			case ESelectionOp::Delete:
				for (const FCell& C : Selection)
					if (Cells.count(C)) Change.Clear.insert(C);
				break;
			case ESelectionOp::ExtrudeUp:
			case ESelectionOp::ExtrudeDown:
			{
				const FCell StepUp(0, Op == ESelectionOp::ExtrudeUp ? 1 : -1, 0);
				for (const FCell& C : Selection)
				{
					const FCell P = C + StepUp;
					if (!Cells.count(P)) Change.Set.insert(P);
					Change.Selection.insert(P);
				}
				break;
			}
			case ESelectionOp::Grow:
				for (const FCell& C : Selection)
				{
					if (Cells.count(C)) Change.Selection.insert(C);
					for (const FCell& F : ToolFaces)
						if (Cells.count(C + F)) Change.Selection.insert(C + F);
				}
				break;
			case ESelectionOp::Shrink:
				for (const FCell& C : Selection)
				{
					if (!Cells.count(C)) continue;
					bool bInner = true;
					for (const FCell& F : ToolFaces)
						if (!Selection.count(C + F)) { bInner = false; break; }
					if (bInner) Change.Selection.insert(C);
				}
				break;
			case ESelectionOp::Fill:
				// The selection stays: fill, extrude, fill is how a room goes up.
				for (const FCell& C : Selection)
				{
					Change.Selection.insert(C);
					if (!Cells.count(C)) Change.Set.insert(C);
				}
				break;
			case ESelectionOp::Connected:
			{
				std::vector<FCell> Stack;
				for (const FCell& C : Selection)
					if (Cells.count(C) && Change.Selection.insert(C).second) Stack.push_back(C);
				while (!Stack.empty())
				{
					const FCell C = Stack.back();
					Stack.pop_back();
					for (const FCell& F : ToolFaces)
					{
						const FCell V = C + F;
						if (Cells.count(V) && Change.Selection.insert(V).second) Stack.push_back(V);
					}
				}
				break;
			}
			}
			return Change;
		}

		FCellSet Box(const FCell& A, const FCell& B, bool bHollow)
		{
			const FCell Lo(std::min(A.X, B.X), std::min(A.Y, B.Y), std::min(A.Z, B.Z));
			const FCell Hi(std::max(A.X, B.X), std::max(A.Y, B.Y), std::max(A.Z, B.Z));
			FCellSet Cells;
			const long long Volume = static_cast<long long>(Hi.X - Lo.X + 1) * (Hi.Y - Lo.Y + 1) * (Hi.Z - Lo.Z + 1);
			if (Volume > BoxVolumeMax) return Cells;
			Cells.reserve(static_cast<size_t>(Volume));
			for (int X = Lo.X; X <= Hi.X; ++X)
				for (int Y = Lo.Y; Y <= Hi.Y; ++Y)
					for (int Z = Lo.Z; Z <= Hi.Z; ++Z)
					{
						if (bHollow && X > Lo.X && X < Hi.X && Y > Lo.Y && Y < Hi.Y && Z > Lo.Z && Z < Hi.Z) continue;
						Cells.insert(FCell(X, Y, Z));
					}
			return Cells;
		}

		FChange Move(const FCellSet& Cells, const FCellSet& Selection, const FCell& Offset)
		{
			FChange Change;
			FCellSet Source;
			for (const FCell& C : Selection)
				if (Cells.count(C)) Source.insert(C);
			for (const FCell& C : Source) Change.Selection.insert(C + Offset);
			for (const FCell& C : Source)
				if (!Change.Selection.count(C)) Change.Clear.insert(C);
			for (const FCell& C : Change.Selection)
				if (!Cells.count(C) || Change.Clear.count(C)) Change.Set.insert(C);
			return Change;
		}

		std::vector<FCell> Copy(const FCellSet& Cells, const FCellSet& Selection)
		{
			std::vector<FCell> Full;
			for (const FCell& C : Selection)
				if (Cells.count(C)) Full.push_back(C);
			if (Full.empty()) return Full;
			FCell Lo = Full[0];
			FCell Hi = Full[0];
			for (const FCell& C : Full)
			{
				Lo = FCell(std::min(Lo.X, C.X), std::min(Lo.Y, C.Y), std::min(Lo.Z, C.Z));
				Hi = FCell(std::max(Hi.X, C.X), std::max(Hi.Y, C.Y), std::max(Hi.Z, C.Z));
			}
			// FLOOR of the half-sum: integer division truncates towards zero and would shift a paste by
			// one cell in negative coordinates.
			const FCell AnchorCell(FloorHalf(Lo.X + Hi.X), Lo.Y, FloorHalf(Lo.Z + Hi.Z));
			std::vector<FCell> Relative;
			for (const FCell& C : Full) Relative.push_back(C - AnchorCell);
			std::sort(Relative.begin(), Relative.end());
			return Relative;
		}

		FChange Paste(const FCellSet& Cells, const std::vector<FCell>& Clipboard, const FCell& AnchorCell)
		{
			FChange Change;
			for (const FCell& D : Clipboard)
			{
				const FCell C = AnchorCell + D;
				Change.Selection.insert(C);
				if (!Cells.count(C)) Change.Set.insert(C);
			}
			return Change;
		}
	}
}
