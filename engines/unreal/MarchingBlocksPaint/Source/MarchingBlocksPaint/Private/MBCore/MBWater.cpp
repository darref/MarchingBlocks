// MarchingBlocks Paint for Unreal — l'eau (voir MBWater.h). Réécrite depuis `fluides.gd`, LIGNE À LIGNE (`boite`,
// `dans_le_vide`, `_creux`, `_a_plat`, `source`, `_chute_proche`, `sources_en_largeur`, `monde`, `surface`,
// `profondeur`) et `format_monde.gd` (`lire_eau`) ; la mer est celle du cœur C++ (Noyau/ocean.h, copie conforme de
// gdextension/src/noyau/ocean.h). Éprouvée par Tests/water_conformance.json.
//
// ⚠ L'ORDRE DÉCIDE DE TOUT : voisins +x, −x, +z, −z, bas, haut ; le tas départagé par l'ordre d'insertion (une clé
// entière, priorité dans les 32 bits hauts) ; les tables de hachage ne servent qu'à « est-ce dedans ? », jamais à un
// parcours dont l'ordre compte.
// ⚠ Préfixe Wtr… (les « unity builds » d'Unreal fusionnent les .cpp). L'emprise et la reprise de l'appli (son cache
// geste par geste) ne sont pas portées : elles ne changent pas le résultat.

#include "MBCore/MBWater.h"

#include "Noyau/ocean.h"

#include <algorithm>
#include <climits>
#include <cstdint>
#include <functional>
#include <queue>
#include <unordered_map>

namespace MBPaint
{
	namespace
	{
		const FCell WtrDown(0, -1, 0);
		const FCell WtrHorizontal[4] = {FCell(1, 0, 0), FCell(-1, 0, 0), FCell(0, 0, 1), FCell(0, 0, -1)};
		const FCell WtrNeighbours[6] = {FCell(1, 0, 0), FCell(-1, 0, 0), FCell(0, 0, 1), FCell(0, 0, -1), FCell(0, -1, 0), FCell(0, 1, 0)};
		const int64_t WtrBias = 1 << 20;

		struct FWtrBox
		{
			bool bEmpty = true;
			FCell Lo, Hi;
		};

		FWtrBox WtrBoxOf(const FCellSet& Cells)
		{
			FWtrBox B;
			if (Cells.empty()) return B;
			FCell Lo(INT_MAX, INT_MAX, INT_MAX), Hi(-INT_MAX, -INT_MAX, -INT_MAX);
			for (const FCell& C : Cells)
			{
				Lo = FCell(std::min(Lo.X, C.X), std::min(Lo.Y, C.Y), std::min(Lo.Z, C.Z));
				Hi = FCell(std::max(Hi.X, C.X), std::max(Hi.Y, C.Y), std::max(Hi.Z, C.Z));
			}
			B.bEmpty = false;
			B.Lo = Lo - FCell(1, 1, 1);
			B.Hi = Hi + FCell(1, 1, 1);
			return B;
		}

		// L'horizon : les côtés et le dessous de la boîte — PAS le dessus.
		bool WtrAtEdge(const FWtrBox& B, const FCell& C)
		{
			return C.X == B.Lo.X || C.Y == B.Lo.Y || C.Z == B.Lo.Z || C.X == B.Hi.X || C.Z == B.Hi.Z;
		}

		bool WtrInVoid(const FCellSet& Cells, const FCell& S, const FWtrBox& B)
		{
			if (B.bEmpty) return true;
			FCell C = S;
			while (C.Y > B.Lo.Y)
			{
				C = C + WtrDown;
				if (Cells.count(C)) return false;
			}
			return true;
		}

		FCellSet WtrOcean(const FCellSet& Cells, int Level, const FWtrBox& B)
		{
			FCellSet Out;
			if (B.bEmpty || Level < B.Lo.Y) return Out;
			std::vector<int32_t> X, Y, Z;
			X.reserve(Cells.size());
			Y.reserve(Cells.size());
			Z.reserve(Cells.size());
			for (const FCell& C : Cells)
			{
				X.push_back(C.X);
				Y.push_back(C.Y);
				Z.push_back(C.Z);
			}
			const int32_t Lo[3] = {B.Lo.X, B.Lo.Y, B.Lo.Z};
			const int32_t Hi[3] = {B.Hi.X, B.Hi.Y, B.Hi.Z};
			for (const mbcore::Run& R : mbcore::ocean_runs(X, Y, Z, Level, Lo, Hi))
				for (int32_t Yy = R.y0; Yy <= R.y1; ++Yy) Out.insert(FCell(R.x, Yy, R.z));
			return Out;
		}

		bool WtrHas(const FCellSet& S, const FCell& C) { return S.count(C) > 0; }

		struct FWtrHollow
		{
			std::string Error;
			int Level = 0;
			FCellSet Cells;
			bool bHasThreshold = false;
			FCell Threshold;
			EWaterEnd Issue = EWaterEnd::Closed;
		};

		// LE CREUX : remplissage par priorité depuis C ; l'eau déjà là (Fixed, Lakes) fait office d'issue.
		FWtrHollow WtrHollow(const FCellSet& Cells, const FWtrBox& B, const FCellSet& Fixed, const FCellSet& Lakes, const FCell& C,
			int Ceiling, int Max)
		{
			FWtrHollow R;
			std::priority_queue<int64_t, std::vector<int64_t>, std::greater<int64_t>> Heap;
			std::vector<FCell> Entries = {C};
			FCellSet Seen = {C};
			std::unordered_map<FCell, FCell, FCellHash> Pred;
			std::unordered_map<FCell, int, FCellHash> Prio = {{C, C.Y}};
			auto Key = [](int P, size_t Order) { return ((static_cast<int64_t>(P) + WtrBias) << 32) | static_cast<int64_t>(Order); };
			Heap.push(Key(C.Y, 0));
			std::vector<FCell> Out;
			while (!Heap.empty())
			{
				const int64_t K = Heap.top();
				Heap.pop();
				const int P = static_cast<int>((K >> 32) - WtrBias);
				const FCell U = Entries[static_cast<size_t>(K & 0xFFFFFFFF)];
				const bool bWater = WtrHas(Fixed, U) || WtrHas(Lakes, U);
				if (bWater || WtrAtEdge(B, U))
				{
					// L'issue : tout ce qui est sorti sous P est le lac.
					for (const FCell& S : Out)
						if (Prio[S] < P) R.Cells.insert(S);
					// Le seuil : la première case du chemin dont la priorité atteint P.
					std::vector<FCell> Path;
					FCell W = U;
					while (true)
					{
						Path.push_back(W);
						const auto Found = Pred.find(W);
						if (Found == Pred.end()) break;
						W = Found->second;
					}
					std::reverse(Path.begin(), Path.end());
					for (const FCell& S : Path)
						if (Prio[S] >= P) { R.bHasThreshold = true; R.Threshold = S; break; }
					R.Level = P - 1;
					R.Issue = bWater ? EWaterEnd::Joins : EWaterEnd::Leaves;
					return R;
				}
				Out.push_back(U);
				if (Out.size() > static_cast<size_t>(Max)) { R.Error = "too_large"; return R; }
				for (const FCell& F : WtrNeighbours)
				{
					const FCell V = U + F;
					if (WtrHas(Seen, V) || WtrHas(Cells, V) || V.X < B.Lo.X || V.Y < B.Lo.Y || V.Z < B.Lo.Z || V.X > B.Hi.X
						|| V.Y > B.Hi.Y || V.Z > B.Hi.Z)
						continue;
					Seen.insert(V);
					Pred[V] = U;
					const int Q = std::max(P, V.Y);
					Prio[V] = Q;
					Heap.push(Key(Q, Entries.size()));
					Entries.push_back(V);
				}
			}
			// Cavité close : le lac monte jusqu'au plafond demandé, ou jusqu'au haut de la cavité.
			R.Level = C.Y;
			for (const FCell& S : Out)
				if (Prio[S] <= Ceiling)
				{
					R.Cells.insert(S);
					R.Level = std::max(R.Level, S.Y);
				}
			R.Issue = EWaterEnd::Closed;
			return R;
		}

		struct FWtrFlat
		{
			std::string Error;
			bool bHollow = false;
			std::vector<FCell> Path;
			/// None: it falls next.
			EWaterEnd End = EWaterEnd::None;
		};

		// LA COULÉE À PLAT : le plus court chemin à l'étage de C jusqu'à une case d'où l'eau tombe, rejoint une eau, ou
		// quitte le monde. Ignore : le lac qu'on vient de quitter.
		FWtrFlat WtrFlat(const FCellSet& Cells, const FWtrBox& B, const FCellSet& Fixed, const FCellSet& Lakes, const FCell& C,
			const FCellSet& Ignore, int Max)
		{
			FWtrFlat R;
			std::unordered_map<FCell, FCell, FCellHash> Pred;
			FCellSet Seen = {C};
			std::vector<FCell> Queue = {C};
			size_t I = 0;
			while (I < Queue.size())
			{
				const FCell U = Queue[I++];
				const FCell D = U + WtrDown;
				// 0 : rien encore ; 1 : tombe ; 2 : sort ; 3 : rejoint.
				int Fin = 0;
				if (!WtrHas(Ignore, D) && (WtrHas(Fixed, D) || WtrHas(Lakes, D))) Fin = 3;
				else if (!WtrHas(Cells, D) && !WtrHas(Ignore, D) && D.Y >= B.Lo.Y) Fin = 1;
				else if (WtrAtEdge(B, U)) Fin = 2;
				if (Fin == 0)
					for (const FCell& F : WtrHorizontal)
					{
						const FCell V = U + F;
						if (WtrHas(Cells, V) || V.X < B.Lo.X || V.Z < B.Lo.Z || V.X > B.Hi.X || V.Z > B.Hi.Z || WtrHas(Seen, V)) continue;
						if (WtrHas(Fixed, V) || WtrHas(Lakes, V)) { Fin = 3; break; }
						Seen.insert(V);
						Pred[V] = U;
						Queue.push_back(V);
					}
				if (Fin != 0)
				{
					FCell W = U;
					while (true)
					{
						R.Path.push_back(W);
						const auto Found = Pred.find(W);
						if (Found == Pred.end()) break;
						W = Found->second;
					}
					std::reverse(R.Path.begin(), R.Path.end());
					R.End = Fin == 1 ? EWaterEnd::None : Fin == 2 ? EWaterEnd::Leaves : EWaterEnd::Joins;
					return R;
				}
				if (Queue.size() > static_cast<size_t>(Max)) { R.Error = "too_large"; return R; }
			}
			R.bHollow = true;
			return R;
		}

		// Depuis le seuil d'un lac, une chute (ou une eau, ou le bord) à au plus OverflowReach cases à plat ?
		bool WtrFallNear(const FCellSet& Cells, const FWtrBox& B, const FCellSet& Fixed, const FCellSet& Lakes, const FWtrHollow& H, int Max)
		{
			if (!H.bHasThreshold) return false;
			const int Reach = 2 * Water::OverflowReach + 1;
			const FWtrFlat Flat = WtrFlat(Cells, B, Fixed, Lakes, H.Threshold, H.Cells, std::min(Max, Reach * Reach));
			return Flat.Error.empty() && !Flat.bHollow && static_cast<int>(Flat.Path.size()) - 1 <= Water::OverflowReach;
		}

		FWaterBody WtrRefuse(const char* Error)
		{
			FWaterBody R;
			R.Error = Error;
			return R;
		}

		FWaterBody WtrSource(const FCellSet& Cells, const FCell& S, const FCellSet& Fixed, int Max, const FWtrBox& B)
		{
			FWaterBody R;
			if (WtrHas(Cells, S)) { R.Error = "in_matter"; return R; }
			if (WtrHas(Fixed, S)) { R.Error = "in_water"; return R; }
			if (WtrInVoid(Cells, S, B))
			{
				R.Kind = EWaterKind::Sea;
				R.Level = S.Y;
				R.Water = WtrOcean(Cells, S.Y, B);
				return R;
			}
			FCellSet LakeCells;
			// Le clic au-dessus du sol : on descend jusqu'à lui.
			FCell C = S;
			while (!WtrHas(Cells, C + WtrDown) && C.Y > B.Lo.Y)
			{
				C = C + WtrDown;
				if (WtrHas(Fixed, C)) { R.Error = "in_water"; return R; }
			}
			std::vector<FCourseStep> Course;
			std::vector<FWaterLake> Lakes;
			FCellSet Ignore;
			bool bFirst = true;
			int Steps = 0;
			while (true)
			{
				++Steps;
				if (Steps > Water::StepsMax || Course.size() > static_cast<size_t>(Water::StepsMax)) return WtrRefuse("too_long");
				const FWtrFlat Flat = WtrFlat(Cells, B, Fixed, LakeCells, C, Ignore, Max);
				if (!Flat.Error.empty()) return WtrRefuse("too_large");
				if (Flat.bHollow)
				{
					const FWtrHollow H = WtrHollow(Cells, B, Fixed, LakeCells, C, S.Y, Max);
					if (!H.Error.empty()) return WtrRefuse("too_large");
					FWaterLake L;
					L.Level = H.Level;
					L.Cells = H.Cells;
					Lakes.push_back(L);
					LakeCells.insert(H.Cells.begin(), H.Cells.end());
					if (bFirst && !(H.Issue == EWaterEnd::Leaves && WtrFallNear(Cells, B, Fixed, LakeCells, H, Max)))
					{
						R.Kind = EWaterKind::Lake;
						R.Level = H.Level;
						R.End = H.Issue == EWaterEnd::Closed ? EWaterEnd::Closed : EWaterEnd::None;
						break;
					}
					// Le lac déborde (une chute proche de son seuil) : il est le premier lac d'une rivière.
					bFirst = false;
					R.Kind = EWaterKind::River;
					FCourseStep Step;
					Step.Cell = C;
					Step.Kind = ECourseKind::Lake;
					Step.Lake = static_cast<int>(Lakes.size()) - 1;
					Course.push_back(Step);
					if (H.Issue == EWaterEnd::Closed) { R.End = EWaterEnd::Closed; break; }
					if (WtrHas(Fixed, H.Threshold) || WtrHas(LakeCells, H.Threshold)) { R.End = EWaterEnd::Joins; break; }
					C = H.Threshold;
					Ignore = H.Cells;
					continue;
				}
				bFirst = false;
				R.Kind = EWaterKind::River;
				for (const FCell& K : Flat.Path)
					if (Course.empty() || Course.back().Cell != K)
					{
						FCourseStep Step;
						Step.Cell = K;
						Course.push_back(Step);
					}
				if (Flat.End != EWaterEnd::None) { R.End = Flat.End; break; }
				Ignore.clear();
				// La chute : jusqu'au sol, à une eau, ou hors du monde (par le FOND seulement).
				FCell U = Flat.Path.back();
				EWaterEnd Fin = EWaterEnd::None;
				while (true)
				{
					const FCell V = U + WtrDown;
					if (WtrHas(Fixed, V) || WtrHas(LakeCells, V)) { Fin = EWaterEnd::Joins; break; }
					if (WtrHas(Cells, V)) break;
					FCourseStep Step;
					Step.Cell = V;
					Step.Kind = ECourseKind::Fall;
					Course.push_back(Step);
					U = V;
					if (V.Y == B.Lo.Y) { Fin = EWaterEnd::Leaves; break; }
				}
				if (Fin != EWaterEnd::None) { R.End = Fin; break; }
				C = U;
			}
			R.Course = Course;
			R.Lakes = Lakes;
			R.Water = LakeCells;
			return R;
		}
	}

	namespace Water
	{
		const char* KindName(EWaterKind Kind)
		{
			return Kind == EWaterKind::Sea ? "sea" : Kind == EWaterKind::Lake ? "lake" : Kind == EWaterKind::River ? "river" : "";
		}

		const char* EndName(EWaterEnd End)
		{
			return End == EWaterEnd::Leaves ? "leaves" : End == EWaterEnd::Joins ? "joins" : End == EWaterEnd::Closed ? "closed" : "";
		}

		const char* CourseName(ECourseKind Kind)
		{
			return Kind == ECourseKind::Flow ? "flow" : Kind == ECourseKind::Fall ? "fall" : "lake";
		}

		std::string Read(const FJsonValue& World, std::vector<FWaterLayer>& Out)
		{
			Out.clear();
			if (World.Type != FJsonValue::EType::Object) return "not a MarchingBlocks world";
			const FJsonValue* List = World.Find("water");
			if (!List) return "";
			if (List->Type != FJsonValue::EType::Array) return "water is not an array";
			std::vector<FWaterLayer> Layers;
			for (const FJsonValue& E : List->Array)
			{
				if (E.Type != FJsonValue::EType::Object || E["name"].Type != FJsonValue::EType::String
					|| E["visible"].Type != FJsonValue::EType::Bool || E["look"].Type != FJsonValue::EType::String)
					return "a water layer has no name, visibility or look";
				FWaterLayer L;
				L.Name = E["name"].String;
				L.bVisible = E["visible"].Bool;
				L.Look = E["look"].String;
				const FJsonValue& Mesh = E["mesh"];
				if (!Mesh.IsNull() && Mesh.Type != FJsonValue::EType::String) return "water '" + L.Name + "': mesh is neither a path nor null";
				L.bHasMesh = Mesh.Type == FJsonValue::EType::String;
				L.Mesh = Mesh.String;
				const FJsonValue& Flat = E["sources"];
				if (Flat.Type != FJsonValue::EType::Array || Flat.Size() % 3 != 0)
					return "water '" + L.Name + "': sources is not a list of x y z triples";
				for (size_t I = 0; I < Flat.Size(); I += 3)
				{
					for (size_t J = 0; J < 3; ++J)
						if (!Flat[I + J].IsWhole()) return "water '" + L.Name + "': a source coordinate is not an integer";
					L.Sources.push_back(FCell(static_cast<int>(Flat[I].AsInt()), static_cast<int>(Flat[I + 1].AsInt()), static_cast<int>(Flat[I + 2].AsInt())));
				}
				Layers.push_back(L);
			}
			Out = Layers;
			return "";
		}

		FJsonValue ToJson(const std::vector<FWaterLayer>& Layers)
		{
			FJsonValue Out = FJsonValue::MakeArray();
			for (const FWaterLayer& L : Layers)
			{
				FJsonValue Sources = FJsonValue::MakeArray();
				for (const FCell& S : L.Sources)
				{
					FJsonValue T = FJsonValue::MakeArray();
					T.Push(FJsonValue::MakeInt(S.X)).Push(FJsonValue::MakeInt(S.Y)).Push(FJsonValue::MakeInt(S.Z));
					Sources.Push(T);
				}
				FJsonValue E = FJsonValue::MakeObject();
				E.Set("name", FJsonValue::MakeString(L.Name)).Set("visible", FJsonValue::MakeBool(L.bVisible))
					.Set("look", FJsonValue::MakeString(L.Look)).Set("mesh", L.bHasMesh ? FJsonValue::MakeString(L.Mesh) : FJsonValue())
					.Set("sources", Sources);
				Out.Push(E);
			}
			return Out;
		}

		FWaterBody Source(const FCellSet& Cells, const FCell& S, const FCellSet& Fixed)
		{
			return WtrSource(Cells, S, Fixed, VolumeMax, WtrBoxOf(Cells));
		}

		FWaterWorld World(const FCellSet& Cells, const std::vector<FCell>& Sources)
		{
			FWaterWorld W;
			W.Bodies.resize(Sources.size());
			std::vector<bool> bDone(Sources.size(), false);
			const FWtrBox B = WtrBoxOf(Cells);
			const FCellSet NoWater;
			int Seas = 0;
			for (size_t I = 0; I < Sources.size(); ++I)
			{
				const FCell& S = Sources[I];
				if (WtrHas(Cells, S) || !WtrInVoid(Cells, S, B)) continue;
				bDone[I] = true;
				// UN SEUL OCÉAN : le premier dans l'ordre des sources ; un autre est refusé.
				if (Seas > 0) { W.Bodies[I] = WtrRefuse("one_sea_only"); continue; }
				++Seas;
				W.Bodies[I] = WtrSource(Cells, S, NoWater, VolumeMax, B);
			}
			for (size_t I = 0; I < Sources.size(); ++I)
				if (bDone[I]) W.Sea.insert(W.Bodies[I].Water.begin(), W.Bodies[I].Water.end());
			for (size_t I = 0; I < Sources.size(); ++I)
				if (!bDone[I]) W.Bodies[I] = WtrSource(Cells, Sources[I], W.Sea, VolumeMax, B);
			return W;
		}

		std::vector<FCell> SourcesInWidth(const FCellSet& Cells, const FCell& S, int Width, const FCellSet& Fixed)
		{
			const FWtrBox B = WtrBoxOf(Cells);
			const FWaterBody R = WtrSource(Cells, S, Fixed, VolumeMax, B);
			if (Width <= 1 || R.Kind != EWaterKind::River) return {S};
			FCell Across(1, 0, 0);
			for (size_t I = 1; I < R.Course.size(); ++I)
			{
				const FCell& A = R.Course[I - 1].Cell;
				const FCell& Next = R.Course[I].Cell;
				if (A.X != Next.X || A.Z != Next.Z)
				{
					Across = Next.X != A.X ? FCell(0, 0, 1) : FCell(1, 0, 0);
					break;
				}
			}
			std::vector<FCell> Out = {S};
			const int Low = -((Width - 1) / 2);
			for (int K = Low; K < Low + Width; ++K)
			{
				if (K == 0) continue;
				const FCell C = S + FCell(Across.X * K, Across.Y * K, Across.Z * K);
				if (WtrHas(Cells, C)) continue;
				const FWaterBody RC = WtrSource(Cells, C, Fixed, VolumeMax, B);
				if (RC.Error.empty() && RC.Kind == EWaterKind::River) Out.push_back(C);
			}
			return Out;
		}

		FCellSet Surface(const FCellSet& WaterCells, const FCellSet& Cells)
		{
			FCellSet Out;
			for (const FCell& C : WaterCells)
			{
				const FCell H = C + FCell(0, 1, 0);
				if (!WtrHas(WaterCells, H) && !WtrHas(Cells, H)) Out.insert(C);
			}
			return Out;
		}

		int Depth(const FCellSet& WaterCells, const FCellSet& Cells, const FCell& C)
		{
			int N = 0;
			FCell U = C;
			while (WtrHas(WaterCells, U))
			{
				++N;
				U = U + WtrDown;
			}
			return WtrHas(Cells, U) ? N : -1;
		}
	}
}
