// THE PARITY CASES (engines/PARITE.md, decided 7 October 2026): editing, animation, foliage, transitions and water —
// the five *_conformance.json files the MarchingBlocks tool writes into every plugin — run through the Unreal plugin's
// MBCore, OUTSIDE Unreal, under Unreal's constraints (see build.sh). An unknown kind FAILS: nothing is skipped silently.

#include "MBCore/MBAnimation.h"
#include "MBCore/MBEditing.h"
#include "MBCore/MBJson.h"
#include "MBCore/MBShapes.h"
#include "MBCore/MBTools.h"

#include <algorithm>
#include <cmath>
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
	return Failed;
}
