// THE WATER SHEET (engines/PARITE.md §12, 7 October 2026): water_mesh_conformance.json run through MBCore's MBWaterMesh,
// compared as a BAG of triangles (no order, rotations allowed, never a reflection), the comparison itself proven first;
// then THE RESUMPTION (Water::WorldResumed and the sheet memory) against everything computed again, on random gestures;
// then, for every .mbworld folder given after the Tests folder, THE END-TO-END CHECK: the sheet rebuilt from the
// world's sources must be the sheet MarchingBlocks baked into water/<name>.glb (colours to 1/255), with the times.

#include "MBCore/MBJson.h"
#include "MBCore/MBWater.h"
#include "MBCore/MBWaterMesh.h"

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <map>
#include <random>
#include <sstream>
#include <string>
#include <vector>

using namespace MBPaint;

int RunWaterMesh(const std::string& Dir, int WorldCount, char** WorldDirs);

namespace
{
	// A triangle: three corners of [px, py, pz, nx, ny, nz, r, g, b, a, u, v].
	using FTri = std::array<double, 36>;

	struct FTolerances
	{
		double Position = 1e-4, Normal = 1e-3, Color = 1e-4, UV = 1e-4;
	};

	bool WLoad(const std::string& Path, FJsonValue& Out)
	{
		std::ifstream In(Path, std::ios::binary);
		if (!In) { std::printf("  cannot read %s\n", Path.c_str()); return false; }
		std::stringstream Buffer;
		Buffer << In.rdbuf();
		std::string Error;
		if (!ParseJson(Buffer.str(), Out, Error)) { std::printf("  %s: %s\n", Path.c_str(), Error.c_str()); return false; }
		return true;
	}

	FCell WVec(const FJsonValue& A)
	{
		return FCell(static_cast<int>(A[0].AsInt()), static_cast<int>(A[1].AsInt()), static_cast<int>(A[2].AsInt()));
	}

	FCellSet WCells(const FJsonValue& A)
	{
		FCellSet S;
		for (const FJsonValue& P : A.Array) S.insert(WVec(P));
		return S;
	}

	// A body as water_world writes it: {kind, error, level, end, water, lakes [{cells, level}], course [[x, y, z, kind, lake]]}.
	FWaterBody WBody(const FJsonValue& J)
	{
		FWaterBody B;
		const std::string& K = J["kind"].String;
		B.Kind = K == "sea" ? EWaterKind::Sea : K == "lake" ? EWaterKind::Lake : K == "river" ? EWaterKind::River : EWaterKind::None;
		B.Error = J["error"].String;
		B.Level = static_cast<int>(J["level"].AsInt());
		const std::string& E = J["end"].String;
		B.End = E == "leaves" ? EWaterEnd::Leaves : E == "joins" ? EWaterEnd::Joins : E == "closed" ? EWaterEnd::Closed : EWaterEnd::None;
		B.Water = WCells(J["water"]);
		for (const FJsonValue& L : J["lakes"].Array)
		{
			FWaterLake Lake;
			Lake.Level = static_cast<int>(L["level"].AsInt());
			Lake.Cells = WCells(L["cells"]);
			B.Lakes.push_back(Lake);
		}
		for (const FJsonValue& S : J["course"].Array)
		{
			FCourseStep Step;
			Step.Cell = WVec(S);
			const std::string& Ck = S[3].String;
			Step.Kind = Ck == "fall" ? ECourseKind::Fall : Ck == "lake" ? ECourseKind::Lake : ECourseKind::Flow;
			Step.Lake = static_cast<int>(S[4].AsInt());
			B.Course.push_back(Step);
		}
		return B;
	}

	std::vector<FTri> WUnfold(const FWaterMesh& M)
	{
		std::vector<FTri> Out;
		for (size_t K = 0; K + 2 < M.Indices.size(); K += 3)
		{
			FTri T;
			for (int C = 0; C < 3; ++C)
			{
				const FWaterVertex& V = M.Vertices[M.Indices[K + static_cast<size_t>(C)]];
				double* D = &T[static_cast<size_t>(C) * 12];
				for (int I = 0; I < 3; ++I) D[I] = V.Position[I];
				for (int I = 0; I < 3; ++I) D[3 + I] = V.Normal[I];
				for (int I = 0; I < 4; ++I) D[6 + I] = V.Color[I];
				for (int I = 0; I < 2; ++I) D[10 + I] = V.UV[I];
			}
			Out.push_back(T);
		}
		return Out;
	}

	std::vector<FTri> WExpected(const FJsonValue& E)
	{
		std::vector<FTri> Out;
		const FJsonValue& V = E["vertices"];
		for (const FJsonValue& T : E["triangles"].Array)
		{
			FTri Tri;
			for (size_t C = 0; C < 3; ++C)
			{
				const FJsonValue& Vertex = V[static_cast<size_t>(T[C].AsInt())];
				for (size_t I = 0; I < 12; ++I) Tri[C * 12 + I] = Vertex[I].AsReal();
			}
			Out.push_back(Tri);
		}
		return Out;
	}

	bool WCornerNear(const FTri& A, size_t Ca, const FTri& B, size_t Cb, const FTolerances& Tol)
	{
		const double* P = &A[Ca * 12];
		const double* Q = &B[Cb * 12];
		for (int I = 0; I < 3; ++I)
			if (std::fabs(P[I] - Q[I]) > Tol.Position) return false;
		for (int I = 3; I < 6; ++I)
			if (std::fabs(P[I] - Q[I]) > Tol.Normal) return false;
		for (int I = 6; I < 10; ++I)
			if (std::fabs(P[I] - Q[I]) > Tol.Color) return false;
		for (int I = 10; I < 12; ++I)
			if (std::fabs(P[I] - Q[I]) > Tol.UV) return false;
		return true;
	}

	struct FBucket
	{
		int64_t X, Y, Z;
		bool operator<(const FBucket& O) const { return X != O.X ? X < O.X : Y != O.Y ? Y < O.Y : Z < O.Z; }
	};

	FBucket WBucketOf(const FTri& T)
	{
		auto R = [&](size_t I) { return static_cast<int64_t>(std::llround((T[I] + T[12 + I] + T[24 + I]) / 3.0 * 100.0)); };
		return FBucket{R(0), R(1), R(2)};
	}

	std::string WShow(const FTri& T)
	{
		char Buf[256];
		std::snprintf(Buf, sizeof(Buf), "(%.4f %.4f %.4f) (%.4f %.4f %.4f) (%.4f %.4f %.4f) kind %.2f", T[0], T[1], T[2], T[12], T[13], T[14],
			T[24], T[25], T[26], T[8]);
		return Buf;
	}

	// THE BAG (PARITE.md §12, `_meme_sac`): same count; every expected triangle matched to a DISTINCT one of ours equal under
	// one of its three rotations, corner by corner within the tolerances (buckets by centroid at 0.01, 27 neighbours).
	std::string WSameBag(const std::vector<FTri>& Want, const std::vector<FTri>& Got, const FTolerances& Tol)
	{
		if (Want.size() != Got.size()) return std::to_string(Got.size()) + " triangles instead of " + std::to_string(Want.size());
		std::map<FBucket, std::vector<size_t>> Buckets;
		for (size_t I = 0; I < Got.size(); ++I) Buckets[WBucketOf(Got[I])].push_back(I);
		std::vector<bool> Taken(Got.size(), false);
		for (const FTri& T : Want)
		{
			const FBucket K0 = WBucketOf(T);
			bool bFound = false;
			for (int64_t Dx = -1; Dx <= 1 && !bFound; ++Dx)
				for (int64_t Dy = -1; Dy <= 1 && !bFound; ++Dy)
					for (int64_t Dz = -1; Dz <= 1 && !bFound; ++Dz)
					{
						const auto Found = Buckets.find(FBucket{K0.X + Dx, K0.Y + Dy, K0.Z + Dz});
						if (Found == Buckets.end()) continue;
						for (size_t I : Found->second)
						{
							if (Taken[I]) continue;
							for (size_t R = 0; R < 3 && !bFound; ++R)
								if (WCornerNear(T, 0, Got[I], R, Tol) && WCornerNear(T, 1, Got[I], (R + 1) % 3, Tol)
									&& WCornerNear(T, 2, Got[I], (R + 2) % 3, Tol))
								{
									bFound = true;
									Taken[I] = true;
								}
							if (bFound) break;
						}
					}
			if (!bFound)
			{
				// The nearest of ours (positions, any rotation), and by how much each attribute differs from it.
				double Best = 1e30;
				double Diff[4] = {0, 0, 0, 0};
				for (const FTri& O : Got)
					for (size_t R = 0; R < 3; ++R)
					{
						double D[4] = {0, 0, 0, 0};
						for (size_t C = 0; C < 3; ++C)
							for (size_t I = 0; I < 12; ++I)
							{
								const double E = std::fabs(T[C * 12 + I] - O[((C + R) % 3) * 12 + I]);
								const size_t Group = I < 3 ? 0 : I < 6 ? 1 : I < 10 ? 2 : 3;
								D[Group] = std::max(D[Group], E);
							}
						if (D[0] < Best)
						{
							Best = D[0];
							std::copy(D, D + 4, Diff);
						}
					}
				char Buf[200];
				std::snprintf(Buf, sizeof(Buf), " — the nearest differs by position %.2g, normal %.2g, colour %.2g, uv %.2g", Diff[0], Diff[1], Diff[2],
					Diff[3]);
				return "no triangle for " + WShow(T) + Buf;
			}
		}
		return "";
	}

	// The summary: per kind (b of the first corner), triangles and area — a diagnosis, before the bag.
	std::string WSummary(const std::vector<FTri>& Tris)
	{
		std::map<std::string, std::pair<int, double>> S;
		for (const FTri& T : Tris)
		{
			const double B = T[8];
			const char* Kind = B < 0.25 ? "still" : B < 0.625 ? "river" : B < 0.875 ? "foam" : "fall";
			const double Ux = T[12] - T[0], Uy = T[13] - T[1], Uz = T[14] - T[2];
			const double Vx = T[24] - T[0], Vy = T[25] - T[1], Vz = T[26] - T[2];
			const double Cx = Uy * Vz - Uz * Vy, Cy = Uz * Vx - Ux * Vz, Cz = Ux * Vy - Uy * Vx;
			S[Kind].first += 1;
			S[Kind].second += 0.5 * std::sqrt(Cx * Cx + Cy * Cy + Cz * Cz);
		}
		std::string Out;
		for (const auto& E : S)
		{
			char Buf[96];
			std::snprintf(Buf, sizeof(Buf), "%s %d (%.3f) ", E.first.c_str(), E.second.first, E.second.second);
			Out += Buf;
		}
		return Out;
	}

	struct FWTally
	{
		int Checks = 0, Failed = 0;
		void Expect(bool bOk, const std::string& What)
		{
			++Checks;
			if (!bOk) { ++Failed; std::printf("  FAIL water_mesh: %s\n", What.c_str()); }
		}
	};

	double WMs(std::chrono::steady_clock::time_point T0)
	{
		return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - T0).count();
	}

	// ── THE COMPARISON, PROVEN (the reference: test_parite.gd) ──────────────────────────────────────────────

	void WProveBag(const std::vector<FTri>& Basin, const FTolerances& Tol, FWTally& T)
	{
		std::mt19937 Rng(7);
		// Shuffled, rotated, noised under the tolerance: the same bag.
		std::vector<FTri> Mixed = Basin;
		std::shuffle(Mixed.begin(), Mixed.end(), Rng);
		std::uniform_real_distribution<double> Noise(-3e-5, 3e-5);
		for (FTri& Tri : Mixed)
		{
			const int R = static_cast<int>(Rng() % 3);
			FTri Turned;
			for (size_t C = 0; C < 3; ++C)
				for (size_t I = 0; I < 12; ++I) Turned[C * 12 + I] = Tri[((C + static_cast<size_t>(R)) % 3) * 12 + I];
			for (double& V : Turned) V += Noise(Rng);
			Tri = Turned;
		}
		T.Expect(WSameBag(Basin, Mixed, Tol).empty(), "the bag refuses the basin shuffled, rotated and noised under the tolerance: "
			+ WSameBag(Basin, Mixed, Tol));
		// A corner moved by 2e-4: refused.
		std::vector<FTri> Moved = Basin;
		Moved[Moved.size() / 2][13] += 2e-4;
		T.Expect(!WSameBag(Basin, Moved, Tol).empty(), "the bag accepts a corner moved by 2e-4");
		// One triangle reflected (two corners swapped): refused.
		std::vector<FTri> Flipped = Basin;
		for (size_t I = 0; I < 12; ++I) std::swap(Flipped[3][12 + I], Flipped[3][24 + I]);
		T.Expect(!WSameBag(Basin, Flipped, Tol).empty(), "the bag accepts a reflected triangle");
		// One triangle twice, in place of another: refused.
		std::vector<FTri> Doubled = Basin;
		Doubled[10] = Doubled[11];
		T.Expect(!WSameBag(Basin, Doubled, Tol).empty(), "the bag accepts a triangle twice in place of another");
		// Colours in 8 bits: refused.
		std::vector<FTri> Bytes = Basin;
		for (FTri& Tri : Bytes)
			for (size_t C = 0; C < 3; ++C)
				for (size_t I = 6; I < 10; ++I) Tri[C * 12 + I] = std::round(Tri[C * 12 + I] * 255.0) / 255.0;
		T.Expect(!WSameBag(Basin, Bytes, Tol).empty(), "the bag accepts colours in 8 bits");
		// One triangle less: refused.
		std::vector<FTri> Fewer(Basin.begin(), Basin.end() - 1);
		T.Expect(!WSameBag(Basin, Fewer, Tol).empty(), "the bag accepts a triangle less");
	}

	// ── THE RESUMPTION: incremental == whole, on random gestures ─────────────────────────────────────────────

	std::string WSameBody(const FWaterBody& A, const FWaterBody& B)
	{
		if (A.Kind != B.Kind || A.Error != B.Error || A.Level != B.Level || A.End != B.End) return "kind, error, level or end";
		if (A.Water != B.Water) return "water cells";
		if (A.Lakes.size() != B.Lakes.size()) return "lakes";
		for (size_t I = 0; I < A.Lakes.size(); ++I)
			if (A.Lakes[I].Level != B.Lakes[I].Level || A.Lakes[I].Cells != B.Lakes[I].Cells) return "a lake";
		if (A.Course.size() != B.Course.size()) return "course length";
		for (size_t I = 0; I < A.Course.size(); ++I)
			if (A.Course[I].Cell != B.Course[I].Cell || A.Course[I].Kind != B.Course[I].Kind || A.Course[I].Lake != B.Course[I].Lake)
				return "course step " + std::to_string(I);
		return "";
	}

	bool WSameMesh(const FWaterMesh& A, const FWaterMesh& B)
	{
		if (A.Indices != B.Indices || A.Vertices.size() != B.Vertices.size()) return false;
		return A.Vertices.empty() || std::memcmp(A.Vertices.data(), B.Vertices.data(), A.Vertices.size() * sizeof(FWaterVertex)) == 0;
	}

	struct FResumeStats
	{
		int Gestures = 0, Bodies = 0, Reused = 0, SheetsReused = 0;
	};

	// Gestures on World: each adds or removes a small clump of cells, somewhere in (or just outside) the box. Layers: the
	// sources split in consecutive layers (Splits: how many sources per layer).
	void WResume(const std::string& Name, FCellSet World, const std::vector<FCell>& Sources, const std::vector<size_t>& Splits,
		int Gestures, uint32_t Seed, FWTally& T, FResumeStats& Stats)
	{
		std::mt19937 Rng(Seed);
		FWaterState State = Water::WorldResumed(World, Sources, nullptr, nullptr);
		std::vector<FWaterMeshMemory> Memories(Splits.size());
		auto Meshes = [&](const FWaterState& S, const FCellSet& Cells, std::vector<FWaterMeshMemory>* Mem)
		{
			std::vector<FWaterMesh> Out;
			size_t K = 0;
			for (size_t L = 0; L < Splits.size(); ++L)
			{
				std::vector<const FWaterBody*> Bodies;
				for (size_t I = 0; I < Splits[L]; ++I) Bodies.push_back(S.Bodies[K + I].get());
				K += Splits[L];
				Out.push_back(WaterMesh::Build(Bodies, Cells, S.Box, Mem ? &(*Mem)[L] : nullptr));
			}
			return Out;
		};
		Meshes(State, World, &Memories);
		for (int G = 0; G < Gestures; ++G)
		{
			const FWaterBox Box = Water::BoxOf(World);
			FCellSet Changed;
			const bool bAdd = (Rng() % 2) == 0;
			const int Size = 1 + static_cast<int>(Rng() % 3);
			auto Coord = [&](int Lo, int Hi) { return Lo - 1 + static_cast<int>(Rng() % static_cast<uint32_t>(Hi - Lo + 3)); };
			const FCell At(Coord(Box.Lo.X, Box.Hi.X), Coord(Box.Lo.Y, Box.Hi.Y), Coord(Box.Lo.Z, Box.Hi.Z));
			for (int X = 0; X < Size; ++X)
				for (int Y = 0; Y < Size; ++Y)
					for (int Z = 0; Z < Size; ++Z)
					{
						const FCell C = At + FCell(X, Y, Z);
						if (bAdd ? World.insert(C).second : World.erase(C) > 0) Changed.insert(C);
					}
			if (Changed.empty()) continue;
			++Stats.Gestures;
			const FWaterState Next = Water::WorldResumed(World, Sources, &State, &Changed);
			const FWaterWorld Whole = Water::World(World, Sources);
			std::string Why;
			for (size_t I = 0; I < Sources.size() && Why.empty(); ++I)
			{
				const std::string B = WSameBody(*Next.Bodies[I], Whole.Bodies[I]);
				if (!B.empty()) Why = "source " + std::to_string(I) + ": " + B;
			}
			if (Why.empty() && *Next.Sea != Whole.Sea) Why = "the sea";
			std::vector<FWaterMesh> Resumed = Meshes(Next, World, &Memories);
			std::vector<FWaterMesh> Fresh = Meshes(Water::WorldResumed(World, Sources, nullptr, nullptr), World, nullptr);
			for (size_t L = 0; L < Splits.size() && Why.empty(); ++L)
				if (!WSameMesh(Resumed[L], Fresh[L])) Why = "the sheet of layer " + std::to_string(L);
			T.Expect(Why.empty(), Name + ", gesture " + std::to_string(G) + ": resumed != whole (" + Why + ")");
			Stats.Bodies += static_cast<int>(Sources.size());
			Stats.Reused += Next.Reused;
			for (const FWaterMeshMemory& M : Memories) Stats.SheetsReused += M.Reused;
			State = Next;
		}
	}

	// ── THE END-TO-END CHECK: a .mbworld folder, its sources, its baked sheets ──────────────────────────────

	std::string WReadFile(const std::string& Path)
	{
		std::ifstream In(Path, std::ios::binary);
		if (!In) return "";
		std::stringstream Buffer;
		Buffer << In.rdbuf();
		return Buffer.str();
	}

	// The triangles of a .glb (one mesh, one primitive, triangles): POSITION, NORMAL, COLOR_0, TEXCOORD_0 and the indices.
	bool WReadGlb(const std::string& Path, std::vector<FTri>& Out, std::string& Why)
	{
		const std::string Data = WReadFile(Path);
		if (Data.size() < 20 || Data.compare(0, 4, "glTF") != 0) { Why = "not a .glb"; return false; }
		uint32_t JsonLength = 0;
		std::memcpy(&JsonLength, Data.data() + 12, 4);
		FJsonValue J;
		std::string Error;
		if (!ParseJson(Data.substr(20, JsonLength), J, Error)) { Why = Error; return false; }
		const size_t BinStart = 20 + JsonLength + 8;
		const FJsonValue& Prim = J["meshes"][0]["primitives"][0];
		auto Read = [&](int64_t Accessor, int Components, std::vector<double>& Values) -> bool
		{
			const FJsonValue& A = J["accessors"][static_cast<size_t>(Accessor)];
			const FJsonValue& V = J["bufferViews"][static_cast<size_t>(A["bufferView"].AsInt())];
			const size_t Count = static_cast<size_t>(A["count"].AsInt());
			const int Type = static_cast<int>(A["componentType"].AsInt());
			const size_t Size = Type == 5126 || Type == 5125 ? 4 : Type == 5123 || Type == 5122 ? 2 : 1;
			const size_t Stride = V.Find("byteStride") ? static_cast<size_t>(V["byteStride"].AsInt()) : Size * static_cast<size_t>(Components);
			const size_t Offset = BinStart + static_cast<size_t>(V["byteOffset"].AsInt()) + static_cast<size_t>(A["byteOffset"].AsInt());
			const bool bNormalized = A["normalized"].Type == FJsonValue::EType::Bool && A["normalized"].Bool;
			Values.clear();
			for (size_t I = 0; I < Count; ++I)
				for (int C = 0; C < Components; ++C)
				{
					const char* P = Data.data() + Offset + I * Stride + static_cast<size_t>(C) * Size;
					double X = 0.0;
					if (Type == 5126) { float F; std::memcpy(&F, P, 4); X = F; }
					else if (Type == 5125) { uint32_t U; std::memcpy(&U, P, 4); X = U; }
					else if (Type == 5123) { uint16_t U; std::memcpy(&U, P, 2); X = bNormalized ? U / 65535.0 : U; }
					else if (Type == 5121) { uint8_t U; std::memcpy(&U, P, 1); X = bNormalized ? U / 255.0 : U; }
					else return false;
					Values.push_back(X);
				}
			return true;
		};
		const FJsonValue& At = Prim["attributes"];
		std::vector<double> P, N, C, T, I;
		if (!Read(At["POSITION"].AsInt(), 3, P) || !Read(At["NORMAL"].AsInt(), 3, N) || !Read(At["COLOR_0"].AsInt(), 4, C)
			|| !Read(At["TEXCOORD_0"].AsInt(), 2, T) || !Read(Prim["indices"].AsInt(), 1, I))
		{
			Why = "an accessor this reader does not know";
			return false;
		}
		for (size_t K = 0; K + 2 < I.size(); K += 3)
		{
			FTri Tri;
			for (size_t Corner = 0; Corner < 3; ++Corner)
			{
				const size_t V = static_cast<size_t>(I[K + Corner]);
				double* D = &Tri[Corner * 12];
				for (size_t X = 0; X < 3; ++X) D[X] = P[V * 3 + X];
				for (size_t X = 0; X < 3; ++X) D[3 + X] = N[V * 3 + X];
				for (size_t X = 0; X < 4; ++X) D[6 + X] = C[V * 4 + X];
				for (size_t X = 0; X < 2; ++X) D[10 + X] = T[V * 2 + X];
			}
			Out.push_back(Tri);
		}
		return true;
	}

	void WEndToEnd(const std::string& Folder, FWTally& T)
	{
		FJsonValue World;
		if (!WLoad(Folder + "/world.json", World)) { T.Expect(false, Folder + ": no world.json"); return; }
		FCellSet Cells;
		for (const FJsonValue& L : World["layers"].Array)
		{
			const FJsonValue& Flat = L["cells"];
			for (size_t I = 0; I + 2 < Flat.Size(); I += 3)
				Cells.insert(FCell(static_cast<int>(Flat[I].AsInt()), static_cast<int>(Flat[I + 1].AsInt()), static_cast<int>(Flat[I + 2].AsInt())));
		}
		std::vector<FWaterLayer> Layers;
		double Floor = WaterMesh::FloorDefault;
		const std::string Refused = Water::Read(World, Layers, &Floor);
		if (!Refused.empty()) { T.Expect(false, Folder + ": water refused: " + Refused); return; }
		std::vector<FCell> Sources;
		for (const FWaterLayer& L : Layers) Sources.insert(Sources.end(), L.Sources.begin(), L.Sources.end());
		std::printf("  %s: %zu full cells, %zu water layer(s), %zu source(s), floor %g\n", Folder.c_str(), Cells.size(), Layers.size(),
			Sources.size(), Floor);
		// Twice: the first run pays its allocations.
		double RuleMs = 1e30, SheetMs = 1e30, BoxMs = 1e30;
		FWaterState State;
		std::vector<FWaterMesh> Meshes;
		for (int Pass = 0; Pass < 2; ++Pass)
		{
			auto T0 = std::chrono::steady_clock::now();
			const FWaterBox Box = Water::BoxOf(Cells);
			BoxMs = std::min(BoxMs, WMs(T0));
			T0 = std::chrono::steady_clock::now();
			State = Water::WorldResumed(Cells, Sources, nullptr, nullptr, &Box);
			RuleMs = std::min(RuleMs, WMs(T0));
			T0 = std::chrono::steady_clock::now();
			Meshes.clear();
			size_t K = 0;
			for (const FWaterLayer& L : Layers)
			{
				std::vector<const FWaterBody*> Bodies;
				for (size_t I = 0; I < L.Sources.size(); ++I) Bodies.push_back(State.Bodies[K + I].get());
				K += L.Sources.size();
				Meshes.push_back(WaterMesh::Build(Bodies, Cells, Box, nullptr, Floor));
			}
			SheetMs = std::min(SheetMs, WMs(T0));
		}
		std::printf("  WHOLE: box %.0f ms, rule %.0f ms (sea %zu cells), sheets %.0f ms — everything %.0f ms\n", BoxMs, RuleMs,
			State.Sea ? State.Sea->size() : 0, SheetMs, BoxMs + RuleMs + SheetMs);
		FTolerances Glb;
		// The .glb keeps colours in 1/255, TRUNCATED by Godot's ArrayMesh (0.5 → 127/255: measured, a difference of 0.0026 seen
		// on the island's waterfall): one step of 1/255, not half of one.
		Glb.Color = 1.0 / 255.0 + 1e-6;
		for (size_t L = 0; L < Layers.size(); ++L)
		{
			const std::vector<FTri> Got = WUnfold(Meshes[L]);
			if (!Layers[L].bHasMesh)
			{
				T.Expect(Got.empty(), Folder + ", layer '" + Layers[L].Name + "': no baked sheet, yet " + std::to_string(Got.size()) + " triangles");
				continue;
			}
			std::vector<FTri> Baked;
			std::string Why;
			if (!WReadGlb(Folder + "/" + Layers[L].Mesh, Baked, Why)) { T.Expect(false, Folder + "/" + Layers[L].Mesh + ": " + Why); continue; }
			const std::string Bag = WSameBag(Baked, Got, Glb);
			T.Expect(Bag.empty(), Folder + ", layer '" + Layers[L].Name + "': the rebuilt sheet is not the baked one: " + Bag + "\n    baked "
				+ WSummary(Baked) + "\n    rebuilt " + WSummary(Got));
			std::printf("  layer '%s': %zu triangles rebuilt = %zu baked: %s\n", Layers[L].Name.c_str(), Got.size(), Baked.size(),
				Bag.empty() ? "THE SAME SHEET" : "DIFFERENT");
		}
		// A GESTURE, resumed (the plugin's way): a cell set and taken back, near the first source and far from everything.
		if (Sources.empty()) return;
		std::vector<FWaterMeshMemory> Memories(Layers.size());
		{
			size_t K = 0;
			for (size_t L = 0; L < Layers.size(); ++L)
			{
				std::vector<const FWaterBody*> Bodies;
				for (size_t I = 0; I < Layers[L].Sources.size(); ++I) Bodies.push_back(State.Bodies[K + I].get());
				K += Layers[L].Sources.size();
				WaterMesh::Build(Bodies, Cells, State.Box, &Memories[L], Floor);
			}
		}
		const FWaterBox Box0 = Water::BoxOf(Cells);
		std::vector<std::pair<std::string, FCell>> Gestures;
		// Near a river: beside the course of the first river found.
		for (const std::shared_ptr<const FWaterBody>& B : State.Bodies)
			if (B && B->Kind == EWaterKind::River && B->Course.size() > 2)
			{
				const FCell C = B->Course[B->Course.size() / 2].Cell;
				for (const FCell& D : {FCell(1, 0, 0), FCell(-1, 0, 0), FCell(0, 0, 1), FCell(0, 0, -1), FCell(0, 1, 0)})
					if (!Cells.count(C + D)) { Gestures.push_back({"a cell beside a river", C + D}); break; }
				break;
			}
		// Far from the water: on top of the highest column, in the middle of the world.
		{
			FCell Top(0, Box0.Lo.Y, 0);
			for (const FCell& C : Cells)
				if (C.Y > Top.Y || (C.Y == Top.Y && C < Top)) Top = C;
			Gestures.push_back({"a cell on the highest point", Top + FCell(0, 1, 0)});
		}
		for (const auto& Gesture : Gestures)
		{
			const FCell At = Gesture.second;
			Cells.insert(At);
			const FCellSet Changed = {At};
			auto T0 = std::chrono::steady_clock::now();
			const FWaterState Next = Water::WorldResumed(Cells, Sources, &State, &Changed);
			const double Rule = WMs(T0);
			T0 = std::chrono::steady_clock::now();
			size_t K = 0;
			std::vector<FWaterMesh> Resumed;
			int SheetsReused = 0;
			for (size_t L = 0; L < Layers.size(); ++L)
			{
				std::vector<const FWaterBody*> Bodies;
				for (size_t I = 0; I < Layers[L].Sources.size(); ++I) Bodies.push_back(Next.Bodies[K + I].get());
				K += Layers[L].Sources.size();
				Resumed.push_back(WaterMesh::Build(Bodies, Cells, Next.Box, &Memories[L], Floor));
				SheetsReused += Memories[L].Reused;
			}
			const double Sheets = WMs(T0);
			// The same as everything again?
			const FWaterState Whole = Water::WorldResumed(Cells, Sources, nullptr, nullptr);
			std::string Why;
			for (size_t I = 0; I < Sources.size() && Why.empty(); ++I) Why = WSameBody(*Next.Bodies[I], *Whole.Bodies[I]);
			K = 0;
			for (size_t L = 0; L < Layers.size() && Why.empty(); ++L)
			{
				std::vector<const FWaterBody*> Bodies;
				for (size_t I = 0; I < Layers[L].Sources.size(); ++I) Bodies.push_back(Whole.Bodies[K + I].get());
				K += Layers[L].Sources.size();
				if (!WSameMesh(Resumed[L], WaterMesh::Build(Bodies, Cells, Whole.Box, nullptr, Floor))) Why = "the sheet of layer " + std::to_string(L);
			}
			T.Expect(Why.empty(), Folder + ", " + Gesture.first + ": resumed != whole (" + Why + ")");
			std::printf("  GESTURE — %s (%d, %d, %d): rule %.0f ms (%d of %zu sources taken back), sheets %.0f ms (%d sheets taken back), "
				"total %.0f ms\n", Gesture.first.c_str(), At.X, At.Y, At.Z, Rule, Next.Reused, Sources.size(), Sheets, SheetsReused, Rule + Sheets);
			State = Next;
		}
	}
}

int RunWaterMesh(const std::string& Dir, int WorldCount, char** WorldDirs)
{
	FWTally T;
	FJsonValue Conf;
	if (!WLoad(Dir + "/water_mesh_conformance.json", Conf)) return 1;
	if (Conf["format"].String != "marchingblocks-water-mesh-conformance" || Conf["version"].AsInt() != 1)
	{
		std::printf("  FAIL not a water mesh conformance file this plugin reads\n");
		return 1;
	}
	const FJsonValue& K = Conf["constants"];
	using namespace WaterMesh;
	const std::pair<const char*, double> Constants[] = {{"arc", Arc}, {"churn", Churn}, {"flare", Flare}, {"flare_max", FlareMax},
		{"foam_rise", FoamRise}, {"horizon", Horizon}, {"into_rock", IntoRock}, {"overhang", Overhang}, {"overlap", Overlap}, {"river", River},
		{"rounding", Rounding}, {"sheet", Sheet}, {"spray", Spray}, {"spring", Spring}, {"spring_dome", SpringDome}, {"surface", Surface},
		{"floor_default", FloorDefault}, {"thin", Thin}, {"above_floor", AboveFloor}, {"band_depth", BandDepth}};
	T.Expect(K.Size() == sizeof(Constants) / sizeof(Constants[0]), "the file has " + std::to_string(K.Size()) + " constants, the plugin 20");
	for (const auto& C : Constants)
		T.Expect(K.Find(C.first) && K[C.first].AsReal() == C.second, std::string("constant ") + C.first + " differs from the plugin's");
	FTolerances Tol;
	const FJsonValue& Tj = Conf["tolerances"];
	Tol.Position = Tj["position"].AsReal();
	Tol.Normal = Tj["normal"].AsReal();
	Tol.Color = Tj["color"].AsReal();
	Tol.UV = Tj["uv"].AsReal();
	T.Expect(Tol.Position == 1e-4 && Tol.Normal == 1e-3 && Tol.Color == 1e-4 && Tol.UV == 1e-4, "the tolerances are not PARITE.md's");
	std::map<std::string, FCellSet> Worlds;
	for (const auto& Entry : Conf["worlds"].Object) Worlds[Entry.first] = WCells(Entry.second);
	int Cases = 0, CaseFailures = 0;
	std::map<double, int> Floors;
	std::vector<FTri> Basin;
	for (const FJsonValue& C : Conf["cases"].Array)
	{
		++Cases;
		const std::string& Name = C["name"].String;
		if (C["kind"].String != "water_mesh") { ++CaseFailures; T.Expect(false, Name + ": unknown kind " + C["kind"].String); continue; }
		const auto World = Worlds.find(C["input"]["world"].String);
		if (World == Worlds.end()) { ++CaseFailures; T.Expect(false, Name + ": unknown world"); continue; }
		std::vector<FWaterBody> Bodies;
		for (const FJsonValue& B : C["input"]["bodies"].Array) Bodies.push_back(WBody(B));
		// THE FLOOR r of the case (0.25 inset, 0 centred, -0.25 outset).
		const FJsonValue* Fj = C["input"].Find("floor");
		if (!Fj || !Fj->IsNumber()) { ++CaseFailures; T.Expect(false, Name + ": no floor"); continue; }
		const double Floor = Fj->AsReal();
		++Floors[Floor];
		const std::vector<FTri> Got = WUnfold(WaterMesh::Build(Bodies, World->second, Floor));
		const std::vector<FTri> Want = WExpected(C["expected"]);
		if (Want.size() > Basin.size()) Basin = Want;
		const std::string Why = WSameBag(Want, Got, Tol);
		if (!Why.empty()) ++CaseFailures;
		T.Expect(Why.empty(), Name + " — " + Why + "\n    expected " + WSummary(Want) + "\n    got      " + WSummary(Got));
	}
	std::printf("water_mesh_conformance.json: %d cases, %d failure(s)\n", Cases, CaseFailures);
	T.Expect(Cases == 23, "the file has " + std::to_string(Cases) + " cases, PARITE.md says 23");
	T.Expect(Floors.size() == 3 && Floors.count(0.25) && Floors.count(0.0) && Floors.count(-0.25),
		"the cases do not exercise the three floors (inset, centred, outset)");
	// The comparison, proven on the largest case (the basin).
	const int Before = T.Failed;
	WProveBag(Basin, Tol, T);
	std::printf("the bag, proven on %zu triangles: %s\n", Basin.size(), T.Failed == Before ? "ok" : "FAILED");
	// TWO WATERFALLS ON ONE PLACE (rules_text: "Waterfalls with the same (axis, round(plane * 20), along) are ONE: top = max,
	// foot = min, ground = min"). ⚠ MEASURED: no case merges two waterfalls (none of the 14, none of the random gestures) —
	// the "lowest lip kept" mutation stayed green without this check. Two rivers leave the same cliff plane (x = 2,
	// heading -x) at z = 0, one from row 5, one from row 3: one sheet, from 4.85 down to the lower foot.
	{
		auto RiverFrom = [](int Y)
		{
			FWaterBody B;
			B.Kind = EWaterKind::River;
			for (int X : {2, 1})
			{
				FCourseStep S;
				S.Cell = FCell(X, Y, 0);
				B.Course.push_back(S);
			}
			for (int Fy = Y - 1; Fy >= Y - 2; --Fy)
			{
				FCourseStep S;
				S.Cell = FCell(1, Fy, 0);
				S.Kind = ECourseKind::Fall;
				B.Course.push_back(S);
			}
			return B;
		};
		const FWaterMesh Two = WaterMesh::Build(std::vector<FWaterBody>{RiverFrom(5), RiverFrom(3)}, FCellSet());
		float High = -1e9f, Low = 1e9f;
		int Falls = 0;
		for (const FWaterVertex& V : Two.Vertices)
			if (V.Color[2] == WaterMesh::KindFall)
			{
				High = std::max(High, V.Position[1]);
				Low = std::min(Low, V.Position[1]);
				++Falls;
			}
		const FWaterMesh One = WaterMesh::Build(std::vector<FWaterBody>{RiverFrom(5)}, FCellSet());
		int FallsOne = 0;
		for (const FWaterVertex& V : One.Vertices) FallsOne += V.Color[2] == WaterMesh::KindFall ? 1 : 0;
		T.Expect(std::fabs(High - 4.85f) < 1e-5f && std::fabs(Low - 0.7f) < 1e-5f && Falls > FallsOne,
			"two waterfalls on one place: one sheet from the HIGHER lip (4.85) to the LOWER foot (0.7); got " + std::to_string(High) + " .. "
			+ std::to_string(Low));
	}
	// The resumption, on random gestures: the worlds of the cases, with their sources.
	FResumeStats Stats;
	const int ResumeBefore = T.Failed;
	{
		// The sources of the water cases (water_conformance.json) and of the sheet cases (the first cell of their rivers).
		WResume("island", Worlds["island"], {FCell(-1, 2, -1), FCell(4, 4, 4), FCell(9, 1, 9)}, {2, 1}, 200, 1, T, Stats);
		WResume("stairs", Worlds["stairs"], {FCell(0, 3, 1), FCell(0, 3, 0), FCell(0, 3, 2)}, {3}, 200, 2, T, Stats);
		WResume("a cliff above a basin", Worlds["a cliff above a basin"], {FCell(2, 5, 1)}, {1}, 200, 3, T, Stats);
		WResume("craters and a cave", Worlds["crater near the edge"], {FCell(2, 2, 6), FCell(4, 3, 4)}, {1, 1}, 200, 4, T, Stats);
		WResume("a slab on a pillar", Worlds["a slab on a pillar"], {FCell(-1, 2, -1), FCell(2, 4, 2)}, {2}, 200, 5, T, Stats);
		WResume("a closed cave", Worlds["closed cave"], {FCell(2, 2, 2)}, {1}, 200, 6, T, Stats);
	}
	std::printf("the resumption: %d gestures, %d bodies, %d taken back, %d sheets taken back: %s\n", Stats.Gestures, Stats.Bodies, Stats.Reused,
		Stats.SheetsReused, T.Failed == ResumeBefore ? "resumed == whole" : "FAILED");
	T.Expect(Stats.Reused > 0 && Stats.Reused < Stats.Bodies, "the gestures never (or always) take a body back: the resumption is not exercised");
	T.Expect(Stats.SheetsReused > 0, "no sheet was ever taken back from the memory");
	// THE FLOOR READ (world.json "water_floor", FormatMonde.lire_eau): absent 0.25; 0.25, 0, -0.25 kept; anything else refuses.
	{
		auto ReadFloor = [](const std::string& Text, double& Floor) -> std::string
		{
			FJsonValue J;
			std::string Error;
			if (!ParseJson(Text, J, Error)) return "json: " + Error;
			std::vector<FWaterLayer> L;
			return Water::Read(J, L, &Floor);
		};
		double F = 9.0;
		T.Expect(ReadFloor("{\"water\": []}", F).empty() && F == 0.25, "an absent water_floor is not 0.25");
		T.Expect(ReadFloor("{\"water\": [], \"water_floor\": 0}", F).empty() && F == 0.0, "water_floor 0 not read");
		T.Expect(ReadFloor("{\"water_floor\": -0.25}", F).empty() && F == -0.25, "water_floor -0.25 (no water key) not read");
		T.Expect(!ReadFloor("{\"water\": [], \"water_floor\": 0.1}", F).empty(), "water_floor 0.1 accepted");
		T.Expect(!ReadFloor("{\"water\": [], \"water_floor\": \"0\"}", F).empty(), "water_floor as a string accepted");
		T.Expect(!ReadFloor("{\"water_floor\": null}", F).empty(), "water_floor null accepted");
	}
	// ANOTHER FLOOR, THE SAME MEMORY: nothing is taken back (the heights changed) — the sheet is the fresh one.
	{
		const FCellSet& Island = Worlds["island"];
		const std::vector<FCell> Sources = {FCell(-1, 2, -1), FCell(4, 4, 4)};
		const FWaterState S = Water::WorldResumed(Island, Sources, nullptr, nullptr);
		std::vector<const FWaterBody*> Bodies;
		for (const auto& B : S.Bodies) Bodies.push_back(B.get());
		FWaterMeshMemory Memory;
		WaterMesh::Build(Bodies, Island, S.Box, &Memory, 0.25);
		const FWaterMesh Centred = WaterMesh::Build(Bodies, Island, S.Box, &Memory, 0.0);
		T.Expect(Memory.Reused == 0 && WSameMesh(Centred, WaterMesh::Build(Bodies, Island, S.Box, nullptr, 0.0)),
			"another floor reused the sheets of the previous one");
		WaterMesh::Build(Bodies, Island, S.Box, &Memory, 0.0);
		T.Expect(Memory.Reused > 0, "the same floor took nothing back");
	}
	for (int I = 0; I < WorldCount; ++I) WEndToEnd(WorldDirs[I], T);
	std::printf("water_mesh: %d checks, %d failure(s)\n", T.Checks, T.Failed);
	return T.Failed;
}
