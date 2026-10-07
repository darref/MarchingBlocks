// MarchingBlocks Paint for Unreal — the special shapes. See MBShapes.h, and rules_text in
// Tests/tools_conformance.json for every rule in full.
//
// ⚠ Helpers are prefixed (Shp…): Unreal's "unity builds" merge .cpp files, and two file-local functions
// with the same name in MBTools.cpp and here would collide.

#include "MBCore/MBShapes.h"

#include <algorithm>
#include <cstdlib>
#include <initializer_list>

namespace MBPaint
{
	namespace
	{
		long long ShpDot(const FCell& A, const FCell& B)
		{
			return static_cast<long long>(A.X) * B.X + static_cast<long long>(A.Y) * B.Y + static_cast<long long>(A.Z) * B.Z;
		}

		int ShpSign(long long X) { return X > 0 ? 1 : (X < 0 ? -1 : 0); }

		FCell ShpMul(const FCell& A, int K) { return FCell(A.X * K, A.Y * K, A.Z * K); }

		FCell ShpNeg(const FCell& A) { return FCell(-A.X, -A.Y, -A.Z); }

		bool ShpIsZero(const FCell& A) { return A.X == 0 && A.Y == 0 && A.Z == 0; }

		bool ShpHas(const FCellSet& S, const FCell& C) { return S.count(C) > 0; }

		enum class EShpProfile { Round, Square, Arch, Deck };

		int ShpLeg(const FCell& Start, const FCell& Dir, const FCell& Other, int H)
		{
			const long long Want = H + 1;
			const long long NN = ShpDot(Dir, Dir);
			int K = 0;
			while (static_cast<long long>(K) * K * NN < Want * Want) ++K;
			const long long W = ShpDot(Dir, Other - Start);
			const long long DD = ShpDot(Other - Start, Other - Start);
			while (K > 0 && W > 0 && 3LL * K * W > DD) --K;
			return K;
		}

		FCellSet ShpSweep(const std::vector<FCell>& Points, int H, EShpProfile Profile, bool bRail, std::string& OutError)
		{
			FCellSet Body;
			FCellSet Rails;
			FCellSet Walkway;
			const bool bWithRail = Profile == EShpProfile::Deck && bRail && H >= 1;
			if (Points.size() < 2) { OutError = "same_cell"; return Body; }
			const size_t Last = Points.size() - 1;
			const long long H2 = static_cast<long long>(H) * H;
			for (size_t I = 0; I < Last; ++I)
			{
				const FCell P0 = Points[I];
				const FCell P1 = Points[I + 1];
				const long long E0 = I > 0 ? H : 0;
				const long long E1 = I + 1 < Last ? H : 0;
				const int Margin = H + 2 + static_cast<int>(std::max(E0, E1));
				const FCell Lo(std::min(P0.X, P1.X) - Margin, std::min(P0.Y, P1.Y) - Margin, std::min(P0.Z, P1.Z) - Margin);
				const FCell Hi(std::max(P0.X, P1.X) + Margin, std::max(P0.Y, P1.Y) + Margin, std::max(P0.Z, P1.Z) + Margin);
				const long long Volume = static_cast<long long>(Hi.X - Lo.X + 1) * (Hi.Y - Lo.Y + 1) * (Hi.Z - Lo.Z + 1);
				if (Volume > Shapes::VolumeMax) { OutError = "too_large"; return Body; }
				const FCell DV = P1 - P0;
				const long long DDV = ShpDot(DV, DV);
				FCell U(1, 0, 0);
				FCell V(0, 0, 1);
				if (DV.X != 0 || DV.Z != 0)
				{
					U = FCell(-DV.Z, 0, DV.X);
					V = FCell(-DV.X * DV.Y, DV.X * DV.X + DV.Z * DV.Z, -DV.Y * DV.Z);
				}
				const long long UU = ShpDot(U, U);
				const long long VV = ShpDot(V, V);
				for (const FCell& Q : Shapes::AxisWalk(P0, P1)) Body.insert(Q);
				for (int X = Lo.X; X <= Hi.X; ++X)
					for (int Y = Lo.Y; Y <= Hi.Y; ++Y)
						for (int Z = Lo.Z; Z <= Hi.Z; ++Z)
						{
							const FCell Q(X, Y, Z);
							const FCell D = Q - P0;
							const long long T = ShpDot(D, DV);
							if (T < 0 && (E0 == 0 || T * T > E0 * E0 * DDV)) continue;
							if (T > DDV && (E1 == 0 || (T - DDV) * (T - DDV) > E1 * E1 * DDV)) continue;
							const long long CA = ShpDot(D, U);
							const long long CB = ShpDot(D, V);
							const long long A2 = CA * CA;
							const long long B2 = CB * CB;
							switch (Profile)
							{
							case EShpProfile::Round:
								if (A2 * VV + B2 * UU <= H2 * UU * VV) Body.insert(Q);
								break;
							case EShpProfile::Square:
								if (A2 <= H2 * UU && B2 <= H2 * VV) Body.insert(Q);
								break;
							case EShpProfile::Arch:
								if (CB >= 0) { if (A2 * VV + B2 * UU <= H2 * UU * VV) Body.insert(Q); }
								else if (A2 <= H2 * UU && B2 <= H2 * VV) Body.insert(Q);
								break;
							case EShpProfile::Deck:
								if (A2 <= H2 * UU && 4 * B2 <= VV) Body.insert(Q);
								else if (bWithRail && CB > 0 && 4 * B2 <= 9 * VV && A2 <= H2 * UU)
								{
									if (A2 > static_cast<long long>(H - 1) * (H - 1) * UU) Rails.insert(Q);
									else Walkway.insert(Q);
								}
								break;
							}
						}
			}
			for (const FCell& Q : Rails)
				if (!ShpHas(Walkway, Q)) Body.insert(Q);
			return Body;
		}

		FCellSet ShpBalcony(const FCell& A, const FCell& N, int Depth, int H, bool bRail)
		{
			FCellSet Body;
			const long long NN = ShpDot(N, N);
			const FCell M(-N.Z, 0, N.X);
			const bool bWithRail = bRail && H >= 1 && Depth >= 2;
			const int Reach = Depth + H + 1;
			for (int X = -Reach; X <= Reach; ++X)
				for (int Z = -Reach; Z <= Reach; ++Z)
				{
					const FCell D(X, 0, Z);
					const long long Along = ShpDot(D, N);
					const long long Side = ShpDot(D, M);
					if (Along <= 0 || Along * Along > static_cast<long long>(Depth) * Depth * NN
						|| Side * Side > static_cast<long long>(H) * H * NN)
						continue;
					Body.insert(A + D);
					if (bWithRail)
					{
						const bool bInner = Along * Along <= static_cast<long long>(Depth - 1) * (Depth - 1) * NN
							&& Side * Side <= static_cast<long long>(H - 1) * (H - 1) * NN;
						if (!bInner) Body.insert(A + D + FCell(0, 1, 0));
					}
				}
			return Body;
		}

		// A stairs column: its top and every empty cell below it down to the ground; with no ground within
		// LengthMax cells, the top and the cell under it. A full top adds nothing. An edge carries the rail.
		void ShpColumn(const FCellSet& Cells, FCellSet& Body, const FCell& Top, bool bEdge)
		{
			if (ShpHas(Cells, Top)) return;
			Body.insert(Top);
			std::vector<FCell> Below;
			bool bGround = false;
			for (int K = 1; K <= Shapes::LengthMax; ++K)
			{
				const FCell Q(Top.X, Top.Y - K, Top.Z);
				if (ShpHas(Cells, Q)) { bGround = true; break; }
				Below.push_back(Q);
			}
			if (bGround) Body.insert(Below.begin(), Below.end());
			else Body.insert(FCell(Top.X, Top.Y - 1, Top.Z));
			if (bEdge) Body.insert(FCell(Top.X, Top.Y + 1, Top.Z));
		}

		// One-click stairs against a wall: they ARRIVE level with the clicked cell. Row J (the smallest
		// J >= 1 with (d.n)^2 <= J^2 |n|^2) has its top at A.Y - (J - 1) / Step; they end at the first row
		// whose top cells are all full already (the ground), or after Length rows.
		FCellSet ShpStairs(const FCellSet& Cells, const FCell& A, const FCell& N, int Length, int Step, int H, bool bRail)
		{
			const long long NN = ShpDot(N, N);
			const FCell M(-N.Z, 0, N.X);
			const int Reach = Length + H + 1;
			std::vector<std::vector<FCell>> Rows(static_cast<size_t>(Length) + 1);
			for (int X = -Reach; X <= Reach; ++X)
				for (int Z = -Reach; Z <= Reach; ++Z)
				{
					const FCell D(X, 0, Z);
					const long long Along = ShpDot(D, N);
					const long long Side = ShpDot(D, M);
					if (Along <= 0 || Side * Side > static_cast<long long>(H) * H * NN) continue;
					int J = 1;
					while (Along * Along > static_cast<long long>(J) * J * NN) ++J;
					if (J > Length) continue;
					Rows[static_cast<size_t>(J)].push_back(D);
				}
			FCellSet Body;
			for (int J = 1; J <= Length; ++J)
			{
				const std::vector<FCell>& Row = Rows[static_cast<size_t>(J)];
				if (Row.empty()) continue;
				const int Top = A.Y - (J - 1) / Step;
				bool bGrounded = true;
				for (const FCell& D : Row)
					if (!ShpHas(Cells, FCell(A.X + D.X, Top, A.Z + D.Z))) { bGrounded = false; break; }
				if (bGrounded) break;
				for (const FCell& D : Row)
				{
					const long long Side = ShpDot(D, M);
					const bool bEdge = bRail && H >= 1 && Side * Side > static_cast<long long>(H - 1) * (H - 1) * NN;
					ShpColumn(Cells, Body, FCell(A.X + D.X, Top, A.Z + D.Z), bEdge);
				}
			}
			return Body;
		}

		// Connected stairs, floor to floor, straight across from the lower end L to the higher H. False when
		// steeper than one cell up per cell across (too_steep).
		bool ShpStairsBetween(const FCellSet& Cells, const FCell& A, const FCell& B, int H, bool bRail, FCellSet& Body)
		{
			const FCell Lo = A.Y <= B.Y ? A : B;
			const FCell Hi = A.Y <= B.Y ? B : A;
			const FCell LoFlat(Lo.X, 0, Lo.Z);
			const FCell DV(Hi.X - Lo.X, 0, Hi.Z - Lo.Z);
			const long long DDV = ShpDot(DV, DV);
			const long long Rise = static_cast<long long>(Hi.Y) - Lo.Y;
			if (Rise * Rise > DDV) return false;
			const FCell U(-DV.Z, 0, DV.X);
			FCellSet Columns;
			for (int X = std::min(Lo.X, Hi.X) - H - 1; X <= std::max(Lo.X, Hi.X) + H + 1; ++X)
				for (int Z = std::min(Lo.Z, Hi.Z) - H - 1; Z <= std::max(Lo.Z, Hi.Z) + H + 1; ++Z)
				{
					const FCell D(X - Lo.X, 0, Z - Lo.Z);
					const long long T = ShpDot(D, DV);
					const long long Side = ShpDot(D, U);
					if (T >= 0 && T <= DDV && Side * Side <= static_cast<long long>(H) * H * DDV) Columns.insert(FCell(X, 0, Z));
				}
			for (const FCell& Q : Shapes::AxisWalk(LoFlat, FCell(Hi.X, 0, Hi.Z))) Columns.insert(Q);
			for (const FCell& C : Columns)
			{
				const FCell D = C - LoFlat;
				const long long T = std::max(0LL, std::min(DDV, ShpDot(D, DV)));
				const long long Side = ShpDot(D, U);
				const bool bEdge = bRail && H >= 1 && Side * Side > static_cast<long long>(H - 1) * (H - 1) * DDV;
				ShpColumn(Cells, Body, FCell(C.X, static_cast<int>(Lo.Y + T * Rise / DDV), C.Z), bEdge);
			}
			return true;
		}

		// No two cells may touch by an edge only. By rounds, order-free: every 2×2 checkerboard around a
		// cell changed in the previous round; dig clears its full pair, add sets its empty pair.
		int ShpRepair(const FCellSet& Cells, FCellSet& Set, FCellSet& Clear, bool bDig)
		{
			const auto Full = [&](const FCell& C) { return ShpHas(Set, C) || (ShpHas(Cells, C) && !ShpHas(Clear, C)); };
			static const FCell Planes[3][2] = {
				{FCell(1, 0, 0), FCell(0, 1, 0)}, {FCell(1, 0, 0), FCell(0, 0, 1)}, {FCell(0, 1, 0), FCell(0, 0, 1)}};
			std::vector<FCell> Front(bDig ? Clear.begin() : Set.begin(), bDig ? Clear.end() : Set.end());
			int Added = 0;
			while (!Front.empty())
			{
				FCellSet Change;
				for (const FCell& C : Front)
					for (const auto& Plane : Planes)
					{
						const FCell E1 = Plane[0];
						const FCell E2 = Plane[1];
						const FCell Origins[4] = {C, C - E1, C - E2, C - E1 - E2};
						for (const FCell& O : Origins)
						{
							const FCell P00 = O, P10 = O + E1, P01 = O + E2, P11 = O + E1 + E2;
							const bool F00 = Full(P00), F10 = Full(P10), F01 = Full(P01), F11 = Full(P11);
							if (F00 == F11 && F10 == F01 && F00 != F10)
							{
								if (F00 == bDig) { Change.insert(P00); Change.insert(P11); }
								else { Change.insert(P10); Change.insert(P01); }
							}
						}
					}
				Front.clear();
				for (const FCell& Q : Change)
				{
					if (bDig) Clear.insert(Q);
					else Set.insert(Q);
					Front.push_back(Q);
					++Added;
				}
				if (Added > Shapes::VolumeMax) break;
			}
			return Added;
		}
	}

	namespace Shapes
	{
		FShapeResult Room(const FCellSet& Cells, const FCell& A, const FCell& B, int Floors, bool bUp)
		{
			FShapeResult Res;
			const int X0 = std::min(A.X, B.X), X1 = std::max(A.X, B.X), Z0 = std::min(A.Z, B.Z), Z1 = std::max(A.Z, B.Z);
			if (X1 - X0 < 2 || Z1 - Z0 < 2) { Res.Error = "too_small"; return Res; }
			const int E = std::max(1, std::min(Floors, RoomFloorsMax));
			const int Y0 = bUp ? A.Y : A.Y - E - 1;
			const int Y1 = Y0 + E + 1;
			if (static_cast<long long>(X1 - X0 + 1) * (Z1 - Z0 + 1) * (E + 2) > VolumeMax) { Res.Error = "too_large"; return Res; }
			for (int X = X0; X <= X1; ++X)
				for (int Z = Z0; Z <= Z1; ++Z)
					for (int Y = Y0; Y <= Y1; ++Y)
					{
						const FCell C(X, Y, Z);
						if (X == X0 || X == X1 || Z == Z0 || Z == Z1 || Y == Y0 || Y == Y1)
						{
							if (!Cells.count(C)) Res.Set.insert(C);
						}
						else if (Cells.count(C)) Res.Clear.insert(C);
					}
			Res.Repaired = ShpRepair(Cells, Res.Set, Res.Clear, false);
			return Res;
		}

		FShapeResult RoomFromSelection(const FCellSet& Cells, const FCellSet& Selection, int Floors, bool bUp)
		{
			FShapeResult Res;
			if (Selection.empty()) { Res.Error = "empty"; return Res; }
			// L'empreinte vue de dessus (x, z), dans une case de y = 0 ; la base : le plus bas en montant, le plus haut en descendant.
			FCellSet Footprint;
			int Base = 0;
			bool bFirst = true;
			for (const FCell& C : Selection)
			{
				Footprint.insert(FCell(C.X, 0, C.Z));
				if (bFirst || (bUp ? C.Y < Base : C.Y > Base)) { Base = C.Y; bFirst = false; }
			}
			FCellSet Inside;
			for (const FCell& P : Footprint)
				if (Footprint.count(P + FCell(1, 0, 0)) && Footprint.count(P + FCell(-1, 0, 0)) && Footprint.count(P + FCell(0, 0, 1))
					&& Footprint.count(P + FCell(0, 0, -1)))
					Inside.insert(P);
			if (Inside.empty()) { Res.Error = "too_small"; return Res; }
			const int E = std::max(1, std::min(Floors, RoomFloorsMax));
			const int Y0 = bUp ? Base : Base - E - 1;
			const int Y1 = Y0 + E + 1;
			if (static_cast<long long>(Footprint.size()) * (E + 2) > VolumeMax) { Res.Error = "too_large"; return Res; }
			FCell Lo(2147483647, Y0, 2147483647), Hi(-2147483647, Y1, -2147483647);
			for (const FCell& P : Footprint)
			{
				Lo.X = std::min(Lo.X, P.X);
				Lo.Z = std::min(Lo.Z, P.Z);
				Hi.X = std::max(Hi.X, P.X);
				Hi.Z = std::max(Hi.Z, P.Z);
				for (int Y = Y0; Y <= Y1; ++Y)
				{
					const FCell C(P.X, Y, P.Z);
					if (Y == Y0 || Y == Y1 || !Inside.count(P))
					{
						if (!Cells.count(C)) Res.Set.insert(C);
					}
					else if (Cells.count(C)) Res.Clear.insert(C);
				}
			}
			Res.Repaired = ShpRepair(Cells, Res.Set, Res.Clear, false);
			Res.bHasBox = true;
			Res.BoxLo = Lo;
			Res.BoxHi = Hi;
			return Res;
		}

		bool Digs(ESpecialShape Shape) { return Shape == ESpecialShape::Tunnel || Shape == ESpecialShape::Well; }

		FCell WallNormal(const FCellSet& Cells, const FCell& C, const FCell& Face)
		{
			static const FCell Horizontal[4] = {FCell(1, 0, 0), FCell(-1, 0, 0), FCell(0, 0, 1), FCell(0, 0, -1)};
			long long SX = 0, SZ = 0;
			for (int X = -1; X <= 1; ++X)
				for (int Y = -1; Y <= 1; ++Y)
					for (int Z = -1; Z <= 1; ++Z)
					{
						const FCell Q = C + FCell(X, Y, Z);
						if (!ShpHas(Cells, Q)) continue;
						for (const FCell& F : Horizontal)
							if (!ShpHas(Cells, Q + F)) { SX += F.X; SZ += F.Z; }
					}
			const long long M = std::max(std::llabs(SX), std::llabs(SZ));
			if (M == 0) return Face;
			const FCell N(2 * std::llabs(SX) >= M ? ShpSign(SX) : 0, 0, 2 * std::llabs(SZ) >= M ? ShpSign(SZ) : 0);
			return ShpDot(N, Face) <= 0 ? Face : N;
		}

		FCell NormalFor(ESpecialShape Shape, const FCellSet& Cells, const FCell& C, const FCell& Face, bool bConnect)
		{
			if (Shape == ESpecialShape::Well)
				return Face.X == 0 && Face.Z == 0 && Face.Y != 0 ? Face : FCell();
			if (Shape == ESpecialShape::Stairs && bConnect)
				return Face.X == 0 && Face.Y == 1 && Face.Z == 0 ? Face : FCell();
			if (Face.Y != 0 || (Face.X == 0 && Face.Z == 0)) return FCell();
			return WallNormal(Cells, C, Face);
		}

		const char* EndError(ESpecialShape Shape, bool bConnect)
		{
			if (Shape == ESpecialShape::Well) return "needs_floor_or_ceiling";
			if (Shape == ESpecialShape::Stairs && bConnect) return "needs_a_floor";
			return "needs_a_wall";
		}

		std::vector<FCell> AxisWalk(const FCell& P0, const FCell& P1)
		{
			const FCell D = P1 - P0;
			const long long AD[3] = {std::llabs(D.X), std::llabs(D.Y), std::llabs(D.Z)};
			const int S[3] = {ShpSign(D.X), ShpSign(D.Y), ShpSign(D.Z)};
			long long K[3] = {0, 0, 0};
			FCell C = P0;
			std::vector<FCell> Out{C};
			const long long Steps = AD[0] + AD[1] + AD[2];
			for (long long Step = 0; Step < Steps; ++Step)
			{
				int Best = -1;
				for (int I = 0; I < 3; ++I)
				{
					if (K[I] >= AD[I]) continue;
					if (Best < 0 || (2 * K[I] + 1) * AD[Best] < (2 * K[Best] + 1) * AD[I]) Best = I;
				}
				if (Best == 0) C.X += S[0];
				else if (Best == 1) C.Y += S[1];
				else C.Z += S[2];
				++K[Best];
				Out.push_back(C);
			}
			return Out;
		}

		FShapeResult Build(const FCellSet& Cells, const FShapeRequest& R)
		{
			FShapeResult Res;
			if (R.Shape == ESpecialShape::Room) { Res.Error = "unknown_shape"; return Res; }
			const int H = std::max(1, std::min(7, R.Size)) - 1;
			const int Length = std::max(1, std::min(LengthMax, R.Length));
			const bool bDig = Digs(R.Shape);
			const bool bConnect = R.bConnect && R.Shape != ESpecialShape::Balcony;
			const FCell NA = NormalFor(R.Shape, Cells, R.A, R.FaceA, bConnect);
			if (ShpIsZero(NA)) { Res.Error = EndError(R.Shape, bConnect); return Res; }
			FCellSet Chosen;
			if (R.Shape == ESpecialShape::Balcony)
				Chosen = ShpBalcony(R.A, NA, Length, H, R.bRail);
			else if (R.Shape == ESpecialShape::Stairs)
			{
				if (bConnect)
				{
					if (ShpIsZero(NormalFor(R.Shape, Cells, R.B, R.FaceB, true))) { Res.Error = "needs_a_floor"; return Res; }
					if (R.B == R.A) { Res.Error = "same_cell"; return Res; }
					if (ShpDot(R.B - R.A, R.B - R.A) > static_cast<long long>(SpanMax) * SpanMax) { Res.Error = "too_far"; return Res; }
					if (!ShpStairsBetween(Cells, R.A, R.B, H, R.bRail, Chosen)) { Res.Error = "too_steep"; return Res; }
				}
				else
				{
					const int Step = std::max(1, std::min(StepMax, R.Step));
					Chosen = ShpStairs(Cells, R.A, NA, Length, Step, H, R.bRail);
				}
			}
			else
			{
				std::vector<FCell> Points;
				if (bConnect)
				{
					const FCell NB = NormalFor(R.Shape, Cells, R.B, R.FaceB);
					if (ShpIsZero(NB)) { Res.Error = EndError(R.Shape, false); return Res; }
					if (R.B == R.A) { Res.Error = "same_cell"; return Res; }
					if (ShpDot(R.B - R.A, R.B - R.A) > static_cast<long long>(SpanMax) * SpanMax) { Res.Error = "too_far"; return Res; }
					const FCell DA = bDig ? ShpNeg(NA) : NA;
					const FCell DB = bDig ? ShpNeg(NB) : NB;
					const FCell EA = R.A + ShpMul(DA, ShpLeg(R.A, DA, R.B, H));
					const FCell EB = R.B + ShpMul(DB, ShpLeg(R.B, DB, R.A, H));
					for (const FCell& Q : {R.A, EA, EB, R.B})
						if (Points.empty() || Points.back() != Q) Points.push_back(Q);
				}
				else
				{
					// One click: dig to the far wall cell before the first empty cell (or Length deep); a
					// bridge runs to the first full cell in front.
					const FCell S = bDig ? ShpNeg(NA) : NA;
					FCell End;
					bool bFound = false;
					for (int K = 1; K <= Length; ++K)
					{
						const FCell Q = R.A + ShpMul(S, K);
						if (ShpHas(Cells, Q) != bDig)
						{
							End = bDig && K > 1 ? Q - S : Q;
							bFound = true;
							break;
						}
					}
					if (!bFound)
					{
						if (!bDig) { Res.Error = "nothing_in_front"; return Res; }
						End = R.A + ShpMul(S, Length);
					}
					Res.bOpened = bFound;
					Points.push_back(R.A);
					Points.push_back(End);
				}
				const EShpProfile Profile = R.Shape == ESpecialShape::Bridge ? EShpProfile::Deck
					: R.Profile == EShapeProfile::Square ? EShpProfile::Square
					: R.Profile == EShapeProfile::Arch ? EShpProfile::Arch : EShpProfile::Round;
				std::string Error;
				Chosen = ShpSweep(Points, H, Profile, R.bRail, Error);
				if (!Error.empty()) { Res.Error = Error; return Res; }
			}
			for (const FCell& Q : Chosen)
			{
				if (bDig && ShpHas(Cells, Q)) Res.Clear.insert(Q);
				else if (!bDig && !ShpHas(Cells, Q)) Res.Set.insert(Q);
			}
			Res.Repaired = ShpRepair(Cells, Res.Set, Res.Clear, bDig);
			return Res;
		}
	}
}
