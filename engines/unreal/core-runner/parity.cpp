// THE PARITY CASES (engines/PARITE.md, decided 7 October 2026): editing, animation, foliage, transitions and water —
// the five *_conformance.json files the MarchingBlocks tool writes into every plugin — run through the Unreal plugin's
// MBCore, OUTSIDE Unreal, under Unreal's constraints (see build.sh). An unknown kind FAILS: nothing is skipped silently.

#include "MBCore/MBAnimation.h"
#include "MBCore/MBEditing.h"
#include "MBCore/MBFoliage.h"
#include "MBCore/MBJson.h"
#include "MBCore/MBShapes.h"
#include "MBCore/MBTools.h"
#include "MBCore/MBTransitions.h"

#include <algorithm>
#include <array>
#include <functional>
#include <cmath>
#include <cstdlib>
#include <cstdio>
#include <fstream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

using namespace MBPaint;

int RunParity(const std::string& Dir);

namespace
{
	bool PLoad(const std::string& Path, FJsonValue& Out)
	{
		std::ifstream In(Path, std::ios::binary);
		if (!In) { std::printf("  cannot read %s\n", Path.c_str()); return false; }
		std::stringstream Buffer;
		Buffer << In.rdbuf();
		std::string Error;
		if (!ParseJson(Buffer.str(), Out, Error)) { std::printf("  %s: %s\n", Path.c_str(), Error.c_str()); return false; }
		return true;
	}

	FCell PVec(const FJsonValue& A)
	{
		return FCell(static_cast<int>(A[0].AsInt()), static_cast<int>(A[1].AsInt()), static_cast<int>(A[2].AsInt()));
	}

	FCellSet PCells(const FJsonValue& A)
	{
		FCellSet S;
		for (const FJsonValue& P : A.Array) S.insert(PVec(P));
		return S;
	}

	std::string PShow(const FCell& C)
	{
		return "(" + std::to_string(C.X) + ", " + std::to_string(C.Y) + ", " + std::to_string(C.Z) + ")";
	}

	std::string PShowList(const std::vector<FCell>& L)
	{
		if (L.size() > 8) return std::to_string(L.size()) + " cells";
		std::string S;
		for (const FCell& C : L) S += PShow(C) + " ";
		return S;
	}

	// A set compared to the expected SORTED list: the expected list must itself be sorted (the files say so).
	std::string PSameSet(const char* What, const FCellSet& Got, const FJsonValue& Expected)
	{
		std::vector<FCell> Want;
		for (const FJsonValue& P : Expected.Array) Want.push_back(PVec(P));
		if (!std::is_sorted(Want.begin(), Want.end())) return std::string(What) + ": the expected list is not sorted";
		const std::vector<FCell> G = Tools::Sorted(Got);
		if (G == Want) return "";
		return std::string(What) + ": expected " + PShowList(Want) + ", got " + PShowList(G);
	}

	struct FTally
	{
		int Cases = 0;
		int Failed = 0;
		std::map<std::string, int> Kinds;
		void Check(const FJsonValue& C, const std::string& Why, const char* File)
		{
			++Cases;
			++Kinds[C["kind"].String];
			if (!Why.empty()) { ++Failed; std::printf("  FAIL %s: %s — %s\n", File, C["name"].String.c_str(), Why.c_str()); }
		}
		void Print(const char* File) const
		{
			std::printf("%s: %d cases (", File, Cases);
			bool bFirst = true;
			for (const auto& K : Kinds) { std::printf("%s%s %d", bFirst ? "" : ", ", K.first.c_str(), K.second); bFirst = false; }
			std::printf("), %d failure(s)\n", Failed);
		}
	};

	// Two JSON values, the same facts: objects by key (order free), arrays in order, numbers within Tolerance
	// (3 and 3.0 are the same number), null, bools and strings exact. "" when equal, else where they differ.
	std::string PSameJson(const FJsonValue& Got, const FJsonValue& Want, double Tolerance, const std::string& At = "")
	{
		using T = FJsonValue::EType;
		if (Got.IsNumber() && Want.IsNumber())
			return std::fabs(Got.AsReal() - Want.AsReal()) <= Tolerance ? ""
				: At + ": expected " + std::to_string(Want.AsReal()) + ", got " + std::to_string(Got.AsReal());
		if (Got.Type != Want.Type) return At + ": not the same type";
		switch (Want.Type)
		{
		case T::Null: return "";
		case T::Bool: return Got.Bool == Want.Bool ? "" : At + ": expected " + (Want.Bool ? "true" : "false");
		case T::String: return Got.String == Want.String ? "" : At + ": expected '" + Want.String + "', got '" + Got.String + "'";
		case T::Array:
			if (Got.Size() != Want.Size())
				return At + ": expected " + std::to_string(Want.Size()) + " items, got " + std::to_string(Got.Size());
			for (size_t I = 0; I < Want.Size(); ++I)
			{
				const std::string Why = PSameJson(Got[I], Want[I], Tolerance, At + "[" + std::to_string(I) + "]");
				if (!Why.empty()) return Why;
			}
			return "";
		case T::Object:
			if (Got.Size() != Want.Size()) return At + ": expected " + std::to_string(Want.Size()) + " keys, got " + std::to_string(Got.Size());
			for (const auto& Entry : Want.Object)
			{
				if (!Got.Find(Entry.first)) return At + ": no key " + Entry.first;
				const std::string Why = PSameJson(Got[Entry.first], Entry.second, Tolerance, At + "." + Entry.first);
				if (!Why.empty()) return Why;
			}
			return "";
		default: return At + ": a number where none is expected";
		}
	}

	std::string PNear(double Got, double Want, double Tolerance)
	{
		return std::fabs(Got - Want) <= Tolerance ? "" : "expected " + std::to_string(Want) + ", got " + std::to_string(Got);
	}

	// ── ANIMATION ────────────────────────────────────────────────────────────────────────────────────────────

	std::string RunAnimationCase(const FJsonValue& C)
	{
		const FJsonValue& I = C["input"];
		const FJsonValue& E = C["expected"];
		const std::string& Kind = C["kind"].String;
		if (Kind == "frame")
		{
			const int Got = Animation::FrameAt(static_cast<int>(I["count"].AsInt()), I["fps"].AsReal(), I["ping_pong"].Bool,
				I["t"].AsReal(), I["phase"].AsReal());
			return Got == E.AsInt() ? "" : "expected " + std::to_string(E.AsInt()) + ", got " + std::to_string(Got);
		}
		if (Kind == "pulse")
			return PNear(Animation::PulseAt(I["frequency"].AsReal(), I["minimum"].AsReal(), I["t"].AsReal(), I["phase"].AsReal()),
				E.AsReal(), 1e-5);
		if (Kind == "phase")
			return PNear(Animation::PhaseOf(I["origin"][0].AsReal(), I["origin"][1].AsReal(), I["origin"][2].AsReal()), E.AsReal(), 1e-6);
		if (Kind == "scroll")
		{
			double U = 0.0, V = 0.0;
			Animation::ScrollAt(I["u"].AsReal(), I["v"].AsReal(), I["t"].AsReal(), I["synced"].Bool, I["phase"].AsReal(), U, V);
			std::string Why = PNear(U, E[0].AsReal(), 1e-6);
			if (Why.empty()) Why = PNear(V, E[1].AsReal(), 1e-6);
			return Why;
		}
		if (Kind == "read") return PSameJson(Animation::ToJson(Animation::Read(I)), E, 1e-6, "animation");
		return "unknown kind " + Kind;
	}

	int RunAnimation(const std::string& Path)
	{
		FJsonValue Conf;
		if (!PLoad(Path, Conf)) return 1;
		if (Conf["format"].String != "marchingblocks-animation-conformance" || Conf["version"].AsInt() != 1)
		{
			std::printf("  FAIL not an animation conformance file this plugin reads\n");
			return 1;
		}
		FTally T;
		const FJsonValue& L = Conf["limits"];
		if (L["frames_max"].AsInt() != Animation::FramesMax || L["fps_max"].AsReal() != Animation::FpsMax
			|| L["scroll_max"].AsReal() != Animation::ScrollMax || L["pixels_max"].AsInt() != Animation::PixelsMax)
		{
			++T.Failed;
			std::printf("  FAIL animation limits differ from the plugin's\n");
		}
		for (const FJsonValue& C : Conf["cases"].Array) T.Check(C, RunAnimationCase(C), "animation");
		T.Print("animation");
		return T.Failed;
	}

	// ── FOLIAGE ──────────────────────────────────────────────────────────────────────────────────────────────

	struct FFoliageBench
	{
		FCellSet World;
		FCellSet Water;
		FFoliage Models;
		FFoliageWorld Ask;
	};

	bool PModeOf(const std::string& S, EFoliageMode& Out)
	{
		if (S == "air") Out = EFoliageMode::Air;
		else if (S == "free") Out = EFoliageMode::Free;
		else if (S == "overflow") Out = EFoliageMode::Overflow;
		else return false;
		return true;
	}

	std::vector<FPlant> PPlants(const FJsonValue& A)
	{
		std::vector<FPlant> Out;
		for (const FJsonValue& E : A.Array)
		{
			FPlant P;
			P.Model = E[0].AsInt();
			P.X = E[1].AsReal();
			P.Y = E[2].AsReal();
			P.Z = E[3].AsReal();
			P.Yaw = E[4].AsReal();
			P.Scale = E[5].AsReal();
			P.Mode = E[6].AsInt() == 0 ? EPlantMode::Air : EPlantMode::Planted;
			Out.push_back(P);
		}
		return Out;
	}

	std::string RunFoliageCase(const FJsonValue& C, const FFoliageBench& B)
	{
		const FJsonValue& I = C["input"];
		const FJsonValue& E = C["expected"];
		const std::string& Kind = C["kind"].String;
		const FFoliageModel* M = B.Models.FindModel(I["model"].AsInt());
		if (Kind == "check" || Kind == "brush" || Kind == "place" || Kind == "wind_data")
			if (!M) return "unknown model";
		if (Kind == "check")
		{
			EFoliageMode Mode;
			if (!PModeOf(I["mode"].String, Mode)) return "unknown mode";
			FPlant P;
			P.Model = M->Id;
			P.X = I["point"][0].AsReal();
			P.Y = I["point"][1].AsReal();
			P.Z = I["point"][2].AsReal();
			P.Yaw = I["yaw"].AsReal();
			P.Scale = I["scale"].AsReal();
			const FPlantIndex Index(PPlants(I["plants"]), B.Models);
			const std::string Got = Foliage::Check(*M, P, I["normal"][0].AsReal(), I["normal"][1].AsReal(), I["normal"][2].AsReal(), Mode,
				B.Ask, Index, B.Models, I["spacing"].AsReal(), I["max_slope"].AsReal());
			return Got == E.String ? "" : "expected '" + E.String + "', got '" + Got + "'";
		}
		if (Kind == "brush")
		{
			EFoliageMode Mode;
			if (!PModeOf(I["mode"].String, Mode)) return "unknown mode";
			std::vector<std::array<double, 4>> Candidates;
			for (const FJsonValue& K : I["candidates"].Array)
				Candidates.push_back({K[0].AsReal(), K[1].AsReal(), K[2].AsReal(), K[3].AsReal()});
			FPlantIndex Index(PPlants(I["plants"]), B.Models);
			const FBrushResult R = Foliage::Sow(*M, I["y_top"].AsReal(), Candidates, Mode, B.Ask, Index, B.Models, I["spacing"].AsReal(),
				I["max_slope"].AsReal());
			FJsonValue Got = FJsonValue::MakeObject();
			FJsonValue Plants = FJsonValue::MakeArray();
			for (const FPlant& P : R.Plants)
			{
				FJsonValue A = FJsonValue::MakeArray();
				A.Push(FJsonValue::MakeReal(P.X)).Push(FJsonValue::MakeReal(P.Y)).Push(FJsonValue::MakeReal(P.Z))
					.Push(FJsonValue::MakeReal(P.Yaw)).Push(FJsonValue::MakeReal(P.Scale));
				Plants.Push(A);
			}
			FJsonValue Refused = FJsonValue::MakeObject();
			for (const auto& Entry : R.Refused) Refused.Set(Entry.first, FJsonValue::MakeInt(Entry.second));
			Got.Set("plants", Plants).Set("refused", Refused);
			return PSameJson(Got, E, 1e-6, "brush");
		}
		if (Kind == "place")
		{
			FPlant P;
			P.Model = M->Id;
			P.X = I["point"][0].AsReal();
			P.Y = I["point"][1].AsReal();
			P.Z = I["point"][2].AsReal();
			P.Yaw = I["yaw"].AsReal();
			P.Scale = I["scale"].AsReal();
			double Columns[3][3], Origin[3];
			Foliage::Transform(*M, P, Columns, Origin);
			for (int K = 0; K < 3; ++K)
				for (int J = 0; J < 3; ++J)
				{
					const std::string Why = PNear(Columns[K][J], E["basis"][static_cast<size_t>(K)][static_cast<size_t>(J)].AsReal(), 1e-5);
					if (!Why.empty()) return "basis column " + std::to_string(K) + ": " + Why;
				}
			for (int J = 0; J < 3; ++J)
			{
				const std::string Why = PNear(Origin[J], E["origin"][static_cast<size_t>(J)].AsReal(), 1e-6);
				if (!Why.empty()) return "origin: " + Why;
			}
			return PNear(Foliage::HeightAboveGround(*M, P), E["height_above_ground"].AsReal(), 1e-6);
		}
		if (Kind == "wind_data")
		{
			FPlant P;
			P.Model = M->Id;
			P.X = I["point"][0].AsReal();
			P.Y = I["point"][1].AsReal();
			P.Z = I["point"][2].AsReal();
			P.Scale = I["scale"].AsReal();
			double W[4];
			Foliage::WindData(*M, P, W);
			for (size_t J = 0; J < 4; ++J)
			{
				const std::string Why = PNear(W[J], E[J].AsReal(), 1e-6);
				if (!Why.empty()) return "[" + std::to_string(J) + "] " + Why;
			}
			return "";
		}
		if (Kind == "sway")
		{
			const double P[3] = {I["vertex"][0].AsReal(), I["vertex"][1].AsReal(), I["vertex"][2].AsReal()};
			const double N[3] = {I["normal"][0].AsReal(), I["normal"][1].AsReal(), I["normal"][2].AsReal()};
			const double W[4] = {I["wind"][0].AsReal(), I["wind"][1].AsReal(), I["wind"][2].AsReal(), I["wind"][3].AsReal()};
			double Out[3];
			Foliage::Sway(P, N, W, I["t"].AsReal(), I["direction"][0].AsReal(), I["direction"][1].AsReal(), Out);
			for (size_t J = 0; J < 3; ++J)
			{
				const std::string Why = PNear(Out[J], E[J].AsReal(), 1e-5);
				if (!Why.empty()) return "[" + std::to_string(J) + "] " + Why;
			}
			return "";
		}
		if (Kind == "ground_of_cells")
		{
			FGround G;
			const bool bFound = Foliage::GroundOfCells(B.Ask.IsFull, I["x"].AsReal(), I["z"].AsReal(), I["y_top"].AsReal(), G);
			if (E.IsNull()) return bFound ? "expected no ground, got " + std::to_string(G.Y) : "";
			if (!bFound) return "expected " + std::to_string(E.AsReal()) + ", got no ground";
			return PNear(G.Y, E.AsReal(), 1e-6);
		}
		if (Kind == "read")
		{
			FFoliage F;
			const std::string Error = Foliage::Read(I, F);
			if (E.Find("error")) return Error.empty() ? "expected a refusal, the file was accepted" : "";
			if (!Error.empty()) return "expected the file to be read, refused: " + Error;
			return PSameJson(Foliage::ToJson(F), E, 1e-6, "foliage");
		}
		return "unknown kind " + Kind;
	}

	int RunFoliage(const std::string& Path)
	{
		FJsonValue Conf;
		if (!PLoad(Path, Conf)) return 1;
		if (Conf["format"].String != "marchingblocks-foliage-conformance" || Conf["version"].AsInt() != 1)
		{
			std::printf("  FAIL not a foliage conformance file this plugin reads%s", "\n");
			return 1;
		}
		FTally T;
		const FJsonValue& K = Conf["constants"];
		if (K["max_slope_deg"].AsReal() != Foliage::MaxSlopeDeg || K["ground_tolerance"].AsReal() != Foliage::GroundTolerance
			|| K["edge_samples"].AsInt() != Foliage::EdgeSamples || K["duplicate"].AsReal() != Foliage::Duplicate
			|| K["water_offset"].AsReal() != Foliage::WaterOffset || K["ground_search_floor"].AsInt() != Foliage::GroundSearchFloor
			|| std::fabs(K["wind_direction"][0].AsReal() - Foliage::WindX) > 1e-6 || std::fabs(K["wind_direction"][1].AsReal() - Foliage::WindZ) > 1e-6)
		{
			++T.Failed;
			std::printf("  FAIL foliage constants differ from the plugin's%s", "\n");
		}
		FFoliageBench B;
		B.World = PCells(Conf["world_cells"]);
		B.Water = PCells(Conf["water_cells"]);
		for (const auto& Entry : Conf["models"].Object)
		{
			const FJsonValue& E = Entry.second;
			FFoliageModel M;
			M.Id = E["id"].AsInt();
			M.Name = E["name"].String;
			M.GroundOffset = E["ground_offset"].AsReal();
			M.Scale = E["scale"].AsReal();
			M.ScaleRandom = E["scale_random"].AsReal();
			M.Footprint = E["footprint"].AsReal();
			M.Height = E["height"].AsReal();
			M.Wind = E["wind"].AsReal();
			B.Models.Models.push_back(M);
		}
		const FCellSet* World = &B.World;
		const FCellSet* Water = &B.Water;
		B.Ask.IsFull = [World](const FCell& X) { return World->count(X) > 0; };
		B.Ask.IsWater = [Water](const FCell& X) { return Water->count(X) > 0; };
		const std::function<bool(const FCell&)> IsFull = B.Ask.IsFull;
		B.Ask.Ground = [IsFull](double X, double Z, double YTop, FGround& Out) { return Foliage::GroundOfCells(IsFull, X, Z, YTop, Out); };
		for (const FJsonValue& C : Conf["cases"].Array) T.Check(C, RunFoliageCase(C, B), "foliage");
		T.Print("foliage");
		return T.Failed;
	}

	// ── TRANSITIONS ──────────────────────────────────────────────────────────────────────────────────────────

	FTransitionTable PTable(const FJsonValue& T)
	{
		FTransitionTable Out;
		for (const auto& Entry : T.Object)
		{
			const size_t Bar = Entry.first.find('|');
			Out[{std::atoi(Entry.first.substr(0, Bar).c_str()), std::atoi(Entry.first.substr(Bar + 1).c_str())}] =
				Transitions::ReadSettings(Entry.second);
		}
		return Out;
	}

	std::vector<std::pair<FCell, int>> PRanked(const FJsonValue& A)
	{
		std::vector<std::pair<FCell, int>> Out;
		for (const FJsonValue& E : A.Array) Out.push_back({PVec(E), static_cast<int>(E[3].AsInt())});
		return Out;
	}

	std::string RunTransitionsCase(const FJsonValue& C)
	{
		const FJsonValue& I = C["input"];
		const FJsonValue& E = C["expected"];
		const std::string& Kind = C["kind"].String;
		if (Kind == "blend")
		{
			int Ranks[8], Choices[8];
			for (size_t K = 0; K < 8; ++K)
			{
				Ranks[K] = static_cast<int>(I["ranks"][K].AsInt());
				Choices[K] = static_cast<int>(I["choices"][K].AsInt());
			}
			const double F[3] = {I["f"][0].AsReal(), I["f"][1].AsReal(), I["f"][2].AsReal()};
			std::map<int, double> H;
			for (const auto& Entry : I["h"].Object) H[std::atoi(Entry.first.c_str())] = Entry.second.AsReal();
			const FBlend B = Transitions::Blend(Ranks, F, Choices, PTable(I["table"]), H, I["n"].AsReal());
			FJsonValue Got = FJsonValue::MakeObject();
			if (B.bDrawn)
				Got.Set("owner", FJsonValue::MakeInt(B.Owner)).Set("other", FJsonValue::MakeInt(B.Other)).Set("s", FJsonValue::MakeReal(B.S))
					.Set("vote", FJsonValue::MakeReal(B.Vote)).Set("alpha", FJsonValue::MakeReal(B.Alpha));
			return PSameJson(Got, E, 1e-6, "blend");
		}
		if (Kind == "settings") return PSameJson(Transitions::SettingsToJson(Transitions::ReadSettings(I)), E, 1e-6, "settings");
		if (Kind == "table")
		{
			std::vector<FTransitionPair> Pairs;
			for (const FJsonValue& P : I["pairs"].Array)
			{
				FTransitionPair Pair;
				Pair.A = static_cast<int>(P["a"].AsInt());
				Pair.B = static_cast<int>(P["b"].AsInt());
				Pair.bActive = P["active"].Bool;
				Pair.ACoversB = Transitions::ReadSettings(P["a_covers_b"]);
				Pair.BCoversA = Transitions::ReadSettings(P["b_covers_a"]);
				Pairs.push_back(Pair);
			}
			FJsonValue Got = FJsonValue::MakeObject();
			for (const auto& Entry : Transitions::Table(Pairs, static_cast<int>(I["layers"].AsInt())))
				Got.Set(std::to_string(Entry.first.first) + "|" + std::to_string(Entry.first.second), Transitions::SettingsToJson(Entry.second));
			return PSameJson(Got, E, 1e-6, "table");
		}
		if (Kind == "cell_texture")
		{
			const FCellTexture D = Transitions::BuildCellTexture(PRanked(I["cells"]), PRanked(I["choices"]));
			FJsonValue Got = FJsonValue::MakeObject();
			FJsonValue Origin = FJsonValue::MakeArray(), Size = FJsonValue::MakeArray(), Bytes = FJsonValue::MakeArray();
			Origin.Push(FJsonValue::MakeInt(D.Origin.X)).Push(FJsonValue::MakeInt(D.Origin.Y)).Push(FJsonValue::MakeInt(D.Origin.Z));
			Size.Push(FJsonValue::MakeInt(D.Size.X)).Push(FJsonValue::MakeInt(D.Size.Y)).Push(FJsonValue::MakeInt(D.Size.Z));
			for (int Z = 0; Z < D.Size.Z; ++Z)
				for (int Y = 0; Y < D.Size.Y; ++Y)
					for (int X = 0; X < D.Size.X; ++X)
					{
						const uint8_t B = D.Bytes[static_cast<size_t>(D.IndexOf(D.Origin + FCell(X, Y, Z)))];
						if (B == 0) continue;
						FJsonValue T = FJsonValue::MakeArray();
						T.Push(FJsonValue::MakeInt(X)).Push(FJsonValue::MakeInt(Y)).Push(FJsonValue::MakeInt(Z)).Push(FJsonValue::MakeInt(B));
						Bytes.Push(T);
					}
			Got.Set("origin", Origin).Set("size", Size).Set("bytes", Bytes);
			return PSameJson(Got, E, 0.0, "cell_texture");
		}
		if (Kind == "read")
		{
			FTransitions T;
			const std::string Error = Transitions::Read(I, T);
			if (E.Find("error")) return Error.empty() ? "expected a refusal, the file was accepted" : "";
			if (!Error.empty()) return "expected the file to be read, refused: " + Error;
			return PSameJson(Transitions::ToJson(T), E, 1e-6, "transitions");
		}
		return "unknown kind " + Kind;
	}

	int RunTransitions(const std::string& Path)
	{
		FJsonValue Conf;
		if (!PLoad(Path, Conf)) return 1;
		if (Conf["format"].String != "marchingblocks-transitions-conformance" || Conf["version"].AsInt() != 1)
		{
			std::printf("  FAIL not a transitions conformance file this plugin reads%s", "\n");
			return 1;
		}
		FTally T;
		const FJsonValue Defaults = Transitions::SettingsToJson(FTransitionSettings());
		if (Conf["limits"]["layers_max"].AsInt() != Transitions::LayersMax || Conf["limits"]["margin"].AsInt() != Transitions::Margin
			|| !PSameJson(Defaults, Conf["settings"]["defaults"], 0.0).empty())
		{
			++T.Failed;
			std::printf("  FAIL transitions limits or defaults differ from the plugin's%s", "\n");
		}
		for (const FJsonValue& C : Conf["cases"].Array) T.Check(C, RunTransitionsCase(C), "transitions");
		T.Print("transitions");
		return T.Failed;
	}

	// ── EDITING ──────────────────────────────────────────────────────────────────────────────────────────────

	std::string RunEditingCase(const FJsonValue& C, const FCellSet& World)
	{
		const FJsonValue& I = C["input"];
		const FJsonValue& E = C["expected"];
		const std::string& Kind = C["kind"].String;
		const FCellSet Cells = I["cells"].Type == FJsonValue::EType::String && I["cells"].String == "world" ? World : PCells(I["cells"]);
		const FCellSet Selection = PCells(I["selection"]);
		if (Kind == "extrude")
		{
			EExtrudeDirection D;
			const std::string& Dir = I["direction"].String;
			if (Dir == "up") D = EExtrudeDirection::Up;
			else if (Dir == "down") D = EExtrudeDirection::Down;
			else if (Dir == "facing") D = EExtrudeDirection::Facing;
			else return "unknown direction " + Dir;
			EExtrudeMode M;
			const std::string& Mode = I["mode"].String;
			if (Mode == "place") M = EExtrudeMode::Place;
			else if (Mode == "extend") M = EExtrudeMode::Extend;
			else if (Mode == "shift") M = EExtrudeMode::Shift;
			else return "unknown mode " + Mode;
			const FExtrudeResult R = Editing::Extrude(Cells, static_cast<int>(I["floor"].AsInt()), D, Selection, M);
			if (R.Step != PVec(E["step"])) return "step: expected " + PShow(PVec(E["step"])) + ", got " + PShow(R.Step);
			std::string Why = PSameSet("set", R.Set, E["set"]);
			if (Why.empty()) Why = PSameSet("clear", R.Clear, E["clear"]);
			if (Why.empty()) Why = PSameSet("selection", R.Selection, E["selection"]);
			return Why;
		}
		if (Kind == "shrink_edge") return PSameSet("selection", Editing::ShrinkEdge(Selection), E);
		if (Kind == "widen_flat") return PSameSet("selection", Editing::WidenFlat(Selection), E);
		if (Kind == "select_brush")
		{
			FCellSet S = Selection;
			std::vector<FCell> Targets;
			for (const FJsonValue& P : I["targets"].Array) Targets.push_back(PVec(P));
			Editing::SelectBrush(S, Targets, [&Cells](const FCell& X) { return Cells.count(X) > 0; }, I["include_empty"].Bool,
				I["deselect"].Bool);
			return PSameSet("selection", S, E);
		}
		if (Kind == "room_from_selection")
		{
			const FShapeResult R = Shapes::RoomFromSelection(Cells, Selection, static_cast<int>(I["floors"].AsInt()), I["up"].Bool);
			if (R.Error != E["error"].String) return "error: expected '" + E["error"].String + "', got '" + R.Error + "'";
			if (R.Repaired != E["repaired"].AsInt())
				return "repaired: expected " + std::to_string(E["repaired"].AsInt()) + ", got " + std::to_string(R.Repaired);
			const FJsonValue& Box = E["box"];
			if (Box.Size() == 0) { if (R.bHasBox) return "a box on an error"; }
			else if (!R.bHasBox || R.BoxLo != PVec(Box[0]) || R.BoxHi != PVec(Box[1]))
				return "box: expected " + PShow(PVec(Box[0])) + " " + PShow(PVec(Box[1])) + ", got " + PShow(R.BoxLo) + " " + PShow(R.BoxHi);
			std::string Why = PSameSet("set", R.Set, E["set"]);
			if (Why.empty()) Why = PSameSet("clear", R.Clear, E["clear"]);
			return Why;
		}
		return "unknown kind " + Kind;
	}

	int RunEditing(const std::string& Path)
	{
		FJsonValue Conf;
		if (!PLoad(Path, Conf)) return 1;
		if (Conf["format"].String != "marchingblocks-editing-conformance" || Conf["version"].AsInt() != 1)
		{
			std::printf("  FAIL not an editing conformance file this plugin reads\n");
			return 1;
		}
		FTally T;
		if (Conf["limits"]["box_volume_max"].AsInt() != Shapes::VolumeMax || Conf["limits"]["room_floors_max"].AsInt() != Shapes::RoomFloorsMax)
		{
			++T.Failed;
			std::printf("  FAIL editing limits differ from the plugin's\n");
		}
		const FCellSet World = PCells(Conf["world_cells"]);
		for (const FJsonValue& C : Conf["cases"].Array) T.Check(C, RunEditingCase(C, World), "editing");
		T.Print("editing");
		return T.Failed;
	}
}

int RunParity(const std::string& Dir)
{
	int Failed = RunEditing(Dir + "/editing_conformance.json");
	Failed += RunAnimation(Dir + "/animation_conformance.json");
	Failed += RunFoliage(Dir + "/foliage_conformance.json");
	Failed += RunTransitions(Dir + "/transitions_conformance.json");
	return Failed;
}
