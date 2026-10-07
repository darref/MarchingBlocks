// Runs conformance.json through the Unreal plugin's FRule, tools_conformance.json through its Tools and
// world_conformance.json through its FWorldFile, and checks the aim / navigation switches, OUTSIDE Unreal: it compiles the very files the plugin ships (Source/MarchingBlocksPaint/.../MBCore).
// Exits 1 on any divergence. Build and run: ./build.sh (see there for the flags that mimic Unreal).

#include "MBCore/MBFrame.h"
#include "MBCore/MBJson.h"
#include "MBCore/MBRule.h"
#include "MBCore/MBShapes.h"
#include "MBCore/MBTools.h"
#include "MBCore/MBWorldFile.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <sstream>
#include <map>
#include <string>
#include <vector>

using namespace MBPaint;

// parity.cpp: the five parity files (editing, animation, foliage, transitions, water).
int RunParity(const std::string& Dir);
int RunWaterMesh(const std::string& Dir, int WorldCount, char** WorldDirs);

namespace
{
	bool Load(const std::string& Path, FJsonValue& Out)
	{
		std::ifstream In(Path, std::ios::binary);
		if (!In) { std::printf("  cannot read %s\n", Path.c_str()); return false; }
		std::stringstream Buffer;
		Buffer << In.rdbuf();
		std::string Error;
		if (!ParseJson(Buffer.str(), Out, Error)) { std::printf("  %s: %s\n", Path.c_str(), Error.c_str()); return false; }
		return true;
	}

	FCell Vec(const FJsonValue& A)
	{
		return FCell(static_cast<int>(A[0].AsInt()), static_cast<int>(A[1].AsInt()), static_cast<int>(A[2].AsInt()));
	}

	FCellSet Cells(const FJsonValue& A)
	{
		FCellSet S;
		for (const FJsonValue& P : A.Array) S.insert(Vec(P));
		return S;
	}

	std::string Show(const FCell& C)
	{
		return "(" + std::to_string(C.X) + ", " + std::to_string(C.Y) + ", " + std::to_string(C.Z) + ")";
	}

	std::string ShowList(const std::vector<FCell>& L)
	{
		if (L.size() > 8) return std::to_string(L.size()) + " cells";
		std::string S;
		for (const FCell& C : L) S += Show(C) + " ";
		return S;
	}

	// Lists (brush, clipboard) must come out sorted AND equal; sets are compared sorted.
	std::string Same(const char* What, const std::vector<FCell>& Got, const FJsonValue& Expected, bool bMustBeSorted)
	{
		std::vector<FCell> Want = Tools::Sorted(Cells(Expected));
		std::vector<FCell> Sorted = Got;
		std::sort(Sorted.begin(), Sorted.end());
		if (bMustBeSorted && Sorted != Got) return std::string(What) + " is not sorted";
		if (Sorted == Want) return "";
		return std::string(What) + ": expected " + ShowList(Want) + ", got " + ShowList(Sorted);
	}

	std::string SameChange(const FChange& Change, const FJsonValue& E)
	{
		std::string Why = Same("set", Tools::Sorted(Change.Set), E["set"], false);
		if (Why.empty()) Why = Same("clear", Tools::Sorted(Change.Clear), E["clear"], false);
		if (Why.empty()) Why = Same("selection", Tools::Sorted(Change.Selection), E["selection"], false);
		return Why;
	}

	bool ToolOf(const std::string& S, EBrushTool& Out)
	{
		if (S == "add") Out = EBrushTool::Add;
		else if (S == "dig") Out = EBrushTool::Dig;
		else if (S == "select") Out = EBrushTool::Select;
		else return false;
		return true;
	}

	bool ShapeOf(const std::string& S, EBrushShape& Out)
	{
		if (S == "sphere") Out = EBrushShape::Sphere;
		else if (S == "cube") Out = EBrushShape::Cube;
		else if (S == "disc") Out = EBrushShape::Disc;
		else return false;
		return true;
	}

	bool OpOf(const std::string& S, ESelectionOp& Out)
	{
		if (S == "delete") Out = ESelectionOp::Delete;
		else if (S == "extrude_up") Out = ESelectionOp::ExtrudeUp;
		else if (S == "extrude_down") Out = ESelectionOp::ExtrudeDown;
		else if (S == "grow") Out = ESelectionOp::Grow;
		else if (S == "shrink") Out = ESelectionOp::Shrink;
		else if (S == "connected") Out = ESelectionOp::Connected;
		else if (S == "fill") Out = ESelectionOp::Fill;
		else return false;
		return true;
	}

	bool SpecialShapeOf(const std::string& S, ESpecialShape& Out)
	{
		if (S == "tunnel") Out = ESpecialShape::Tunnel;
		else if (S == "well") Out = ESpecialShape::Well;
		else if (S == "bridge") Out = ESpecialShape::Bridge;
		else if (S == "balcony") Out = ESpecialShape::Balcony;
		else if (S == "stairs") Out = ESpecialShape::Stairs;
		else return false;
		return true;
	}

	bool ProfileOf(const std::string& S, EShapeProfile& Out)
	{
		if (S == "round") Out = EShapeProfile::Round;
		else if (S == "square") Out = EShapeProfile::Square;
		else if (S == "arch") Out = EShapeProfile::Arch;
		else return false;
		return true;
	}

	std::string RunToolCase(const FJsonValue& C, const FCellSet& World, const std::map<std::string, FCellSet>& ShapeWorlds)
	{
		const FJsonValue& I = C["input"];
		const FJsonValue& E = C["expected"];
		const std::string Kind = C["kind"].String;
		const FCellSet Own = I.Find("cells") && I["cells"].Type == FJsonValue::EType::Array ? Cells(I["cells"]) : FCellSet();
		const FCellSet& Here = I.Find("world") ? ShapeWorlds.at(I["world"].String)
			: I.Find("cells") && I["cells"].Type == FJsonValue::EType::Array ? Own : World;
		const FIsFull IsFull = [&Here](const FCell& X) { return Here.count(X) > 0; };
		if (Kind == "ray")
		{
			const FCellSet Ignore = Cells(I["ignore"]);
			const FHit Hit = Tools::Ray(IsFull, I["origin"][0].AsReal(), I["origin"][1].AsReal(), I["origin"][2].AsReal(),
				I["direction"][0].AsReal(), I["direction"][1].AsReal(), I["direction"][2].AsReal(), I["reach"].AsReal(), &Ignore);
			const std::string Got = std::string(Hit.bTouched ? "hit " : "miss ") + Show(Hit.Cell) + " " + Show(Hit.Normal);
			const std::string Want = std::string(E["hit"].Bool ? "hit " : "miss ") + Show(Vec(E["cell"])) + " " + Show(Vec(E["normal"]));
			return Got == Want ? "" : "expected " + Want + ", got " + Got;
		}
		if (Kind == "tile_vertex")
		{
			const FCell Got = Tools::TileVertex(I["origin"][0].AsReal(), I["origin"][1].AsReal(), I["origin"][2].AsReal(),
				I["direction"][0].AsReal(), I["direction"][1].AsReal(), I["direction"][2].AsReal(), Vec(I["cell"]), Vec(I["normal"]));
			return Got == Vec(E["vertex"]) ? "" : "expected " + Show(Vec(E["vertex"])) + ", got " + Show(Got);
		}
		if (Kind == "anchor")
		{
			EBrushTool Tool;
			if (!ToolOf(I["tool"].String, Tool)) return "unknown tool";
			FHit Hit;
			Hit.bTouched = I["hit"].Bool;
			Hit.Cell = Vec(I["cell"]);
			Hit.Normal = Vec(I["normal"]);
			const FCell Got = Tools::Anchor(Tool, Hit);
			return Got == Vec(E["anchor"]) ? "" : "expected " + Show(Vec(E["anchor"])) + ", got " + Show(Got);
		}
		if (Kind == "brush")
		{
			EBrushShape Shape;
			if (!ShapeOf(I["shape"].String, Shape)) return "unknown shape";
			return Same("cells", Tools::Brush(Vec(I["anchor"]), Vec(I["normal"]), static_cast<int>(I["size"].AsInt()), Shape),
				E["cells"], true);
		}
		if (Kind == "change")
		{
			EBrushTool Tool;
			if (!ToolOf(I["tool"].String, Tool)) return "unknown tool";
			const FChange Change = Tools::Modify(Tool, Tools::Sorted(Cells(I["targets"])), IsFull);
			std::string Why = Same("set", Tools::Sorted(Change.Set), E["set"], false);
			if (Why.empty()) Why = Same("clear", Tools::Sorted(Change.Clear), E["clear"], false);
			return Why;
		}
		if (Kind == "selection")
		{
			ESelectionOp Op;
			if (!OpOf(I["op"].String, Op)) return "unknown op";
			return SameChange(Tools::Operate(Here, Cells(I["selection"]), Op), E);
		}
		if (Kind == "box")
		{
			const FCellSet Box = Tools::Box(Vec(I["a"]), Vec(I["b"]), I["hollow"].Bool);
			const long long Count = static_cast<long long>(E["count"].AsInt());
			if (static_cast<long long>(Box.size()) != Count)
				return "expected " + std::to_string(Count) + " cells, got " + std::to_string(Box.size());
			return E.Find("cells") ? Same("cells", Tools::Sorted(Box), E["cells"], false) : "";
		}
		if (Kind == "move") return SameChange(Tools::Move(Here, Cells(I["selection"]), Vec(I["offset"])), E);
		if (Kind == "copy") return Same("clipboard", Tools::Copy(Here, Cells(I["selection"])), E["clipboard"], true);
		if (Kind == "paste")
			return SameChange(Tools::Paste(Here, Tools::Sorted(Cells(I["clipboard"])), Vec(I["anchor"])), E);
		if (Kind == "wall_normal")
		{
			const FCell Got = Shapes::WallNormal(Here, Vec(I["cell"]), Vec(I["face"]));
			return Got == Vec(E["normal"]) ? "" : "expected " + Show(Vec(E["normal"])) + ", got " + Show(Got);
		}
		if (Kind == "room")
		{
			const FShapeResult R = Shapes::Room(Here, Vec(I["a"]), Vec(I["b"]), static_cast<int>(I["floors"].AsInt()), I["up"].Bool);
			const std::string Got = R.Error + "/" + std::to_string(R.Repaired);
			const std::string Want = E["error"].String + "/" + std::to_string(E["repaired"].AsInt());
			if (Got != Want) return "error/repaired: expected " + Want + ", got " + Got;
			std::string Why = Same("set", Tools::Sorted(R.Set), E["set"], false);
			if (Why.empty()) Why = Same("clear", Tools::Sorted(R.Clear), E["clear"], false);
			return Why;
		}
		if (Kind == "special_shape")
		{
			FShapeResult R;
			FShapeRequest Q;
			if (!SpecialShapeOf(I["shape"].String, Q.Shape)) R.Error = "unknown_shape";
			else
			{
				if (!ProfileOf(I["profile"].String, Q.Profile)) return "unknown profile";
				Q.A = Vec(I["a"]);
				Q.FaceA = Vec(I["face_a"]);
				Q.bConnect = I["connect"].Bool;
				if (Q.bConnect) { Q.B = Vec(I["b"]); Q.FaceB = Vec(I["face_b"]); }
				Q.Size = static_cast<int>(I["size"].AsInt());
				Q.Length = static_cast<int>(I["length"].AsInt());
				Q.bRail = I["rail"].Bool;
				Q.Step = static_cast<int>(I["step"].AsInt());
				R = Shapes::Build(Here, Q);
			}
			const std::string Got = R.Error + "/" + (R.bOpened ? "true" : "false") + "/" + std::to_string(R.Repaired);
			const std::string Want = E["error"].String + "/" + (E["opened"].Bool ? "true" : "false") + "/" + std::to_string(E["repaired"].AsInt());
			if (Got != Want) return "error/opened/repaired: expected " + Want + ", got " + Got;
			std::string Why = Same("set", Tools::Sorted(R.Set), E["set"], false);
			if (Why.empty()) Why = Same("clear", Tools::Sorted(R.Clear), E["clear"], false);
			return Why;
		}
		return "unknown kind " + Kind;
	}

	// A case's or a layer's variant_weights and variant_choices (x y z c, flat): the tileset rule, step 8.
	FVariantSettings SettingsOf(const FJsonValue& C)
	{
		FVariantSettings S;
		if (C.Find("variant_weights"))
			for (const auto& Entry : C["variant_weights"].Object)
			{
				std::vector<int64_t> W;
				for (const FJsonValue& X : Entry.second.Array) W.push_back(X.AsInt());
				S.Weights[Entry.first] = W;
			}
		if (C.Find("variant_choices"))
		{
			const FJsonValue& Flat = C["variant_choices"];
			for (size_t I = 0; I + 3 < Flat.Size(); I += 4)
				S.Choices[FCell(static_cast<int>(Flat[I].AsInt()), static_cast<int>(Flat[I + 1].AsInt()),
					static_cast<int>(Flat[I + 2].AsInt()))] = Flat[I + 3].AsInt();
		}
		return S;
	}

	std::string FirstDifference(const FJsonValue& Expected, const std::vector<FPlacement>& Got)
	{
		for (size_t I = 0; I < std::max(Got.size(), Expected.Size()); ++I)
		{
			std::string W = "nothing", G = "nothing";
			if (I < Expected.Size())
			{
				const FJsonValue& E = Expected[I];
				W = Show(Vec(E)) + " " + (E[3].IsNull() ? std::string("null") : E[3].String) + " " + std::to_string(E[4].AsInt());
			}
			if (I < Got.size())
				G = Show(Got[I].Vertex) + " " + (Got[I].Tile.empty() ? std::string("null") : Got[I].Tile) + " " + std::to_string(Got[I].QuarterTurns);
			if (W != G) return "at " + std::to_string(I) + ": expected " + W + ", got " + G;
		}
		return "";
	}

	// The VARIANT cases of conformance.json (step 8). They must exercise it: variants AND base tiles placed, and
	// each case must place something else without step 8.
	int RunVariants(const std::string& Path)
	{
		FJsonValue Conf;
		if (!Load(Path, Conf)) return 1;
		int Cases = 0, Failed = 0, NeedStep8 = 0;
		size_t Placements = 0, InVariant = 0;
		for (const FJsonValue& C : Conf["variant_cases"].Array)
		{
			++Cases;
			const std::string& Name = C["tileset"].String;
			const FRule Rule(Conf, &Conf["tilesets"][Name], &Conf["tileset_variants"][Name]);
			const FCellSet Set = Cells(C["cells"]);
			const FVariantSettings Settings = SettingsOf(C);
			const FJsonValue& Expected = C["expected"];
			Placements += Expected.Size();
			for (const FJsonValue& E : Expected.Array)
				if (!E[3].IsNull() && E[3].String.find("_var") != std::string::npos) ++InVariant;
			const std::string First = FirstDifference(Expected, Rule.Placements(Set, &Settings));
			if (!First.empty()) { ++Failed; std::printf("  FAIL variants %s — %s\n", C["name"].String.c_str(), First.c_str()); }
			const FRule Bare(Conf, &Conf["tilesets"][Name]);
			if (!FirstDifference(Expected, Bare.Placements(Set)).empty()) ++NeedStep8;
		}
		if (Cases < 6) { ++Failed; std::printf("  FAIL conformance.json has %d variant case(s)\n", Cases); }
		if (InVariant == 0 || InVariant >= Placements) { ++Failed; std::printf("  FAIL the variant cases must place variants AND base tiles\n"); }
		if (NeedStep8 != Cases) { ++Failed; std::printf("  FAIL only %d of %d variant cases need step 8\n", NeedStep8, Cases); }
		std::printf("%d variant cases, %zu placements (%zu in a variant), %d failure(s)\n", Cases, Placements, InVariant, Failed);
		return Failed;
	}

	int RunRule(const std::string& Path)
	{
		FJsonValue Conf;
		if (!Load(Path, Conf)) return 1;
		int Cases = 0, Failed = 0;
		size_t Placements = 0;
		for (const FJsonValue& C : Conf["cases"].Array)
		{
			++Cases;
			const FRule Rule(Conf, &Conf["tilesets"][C["tileset"].String]);
			const std::vector<FPlacement> Got = Rule.Placements(Cells(C["cells"]));
			const FJsonValue& Expected = C["expected"];
			Placements += Expected.Size();
			std::string First;
			for (size_t I = 0; I < std::max(Got.size(), Expected.Size()) && First.empty(); ++I)
			{
				std::string W = "nothing", G = "nothing";
				if (I < Expected.Size())
				{
					const FJsonValue& E = Expected[I];
					W = Show(Vec(E)) + " " + (E[3].IsNull() ? std::string("null") : E[3].String) + " " + std::to_string(E[4].AsInt());
				}
				if (I < Got.size())
					G = Show(Got[I].Vertex) + " " + (Got[I].Tile.empty() ? std::string("null") : Got[I].Tile) + " " + std::to_string(Got[I].QuarterTurns);
				if (W != G) First = "at " + std::to_string(I) + ": expected " + W + ", got " + G;
			}
			if (!First.empty()) { ++Failed; std::printf("  FAIL %s — %s\n", C["name"].String.c_str(), First.c_str()); }
		}
		// A newer format must be refused.
		FJsonValue Newer = Conf;
		for (auto& Entry : Newer.Object)
			if (Entry.first == "version") Entry.second.Integer = FRule::SupportedVersion + 1;
		if (FRule::CheckManifest(Newer).empty()) { ++Failed; std::printf("  FAIL a newer format is accepted\n"); }
		// One tile per key: a list of copies per key must be refused, never misread.
		FJsonValue Copies;
		Copies.Type = FJsonValue::EType::Object;
		FJsonValue List;
		List.Type = FJsonValue::EType::Array;
		List.Array.resize(2);
		for (FJsonValue& N : List.Array) { N.Type = FJsonValue::EType::String; N.String = "corner_b1h0"; }
		Copies.Object.push_back({"corner_b1h0", List});
		if (FRule::CheckTiles(Copies).find("one tile per key") == std::string::npos)
		{ ++Failed; std::printf("  FAIL a list of copies is accepted\n"); }
		FJsonValue One;
		One.Type = FJsonValue::EType::Object;
		FJsonValue Name;
		Name.Type = FJsonValue::EType::String;
		Name.String = "corner_b1h0";
		One.Object.push_back({"corner_b1h0", Name});
		if (!FRule::CheckTiles(One).empty()) { ++Failed; std::printf("  FAIL one tile per key is refused\n"); }
		std::printf("%d cases, %zu placements, %d failure(s)\n", Cases, Placements, Failed);
		return Failed;
	}

	// The LAYERED cases of conformance.json: worlds of several layers (the tileset rule, step 7). The cases must
	// exercise what they name: layers that place something else than alone, a hidden layer that places nothing.
	int RunLayered(const std::string& Path)
	{
		FJsonValue Conf;
		if (!Load(Path, Conf)) return 1;
		int Cases = 0, Failed = 0, DifferAlone = 0;
		size_t Placements = 0;
		bool bHiddenEmpty = false;
		const FJsonValue& All = Conf["layered_cases"];
		for (const FJsonValue& C : All.Array)
		{
			++Cases;
			const FJsonValue& Layers = C["layers"];
			std::vector<FCellSet> Sets;
			std::vector<FRule> Rules;
			std::vector<FVariantSettings> Settings;
			Sets.reserve(Layers.Size());
			Rules.reserve(Layers.Size());
			Settings.reserve(Layers.Size());
			for (const FJsonValue& L : Layers.Array)
			{
				Sets.push_back(Cells(L["cells"]));
				const std::string& Name = L["tileset"].String;
				Rules.emplace_back(Conf, &Conf["tilesets"][Name],
					Conf["tileset_variants"].Find(Name.c_str()) ? &Conf["tileset_variants"][Name] : nullptr);
				Settings.push_back(SettingsOf(L));
			}
			std::vector<FLayerInput> In(Layers.Size());
			for (size_t I = 0; I < In.size(); ++I)
			{
				In[I].Cells = &Sets[I];
				In[I].bVisible = Layers[I]["visible"].Bool;
				In[I].Rule = &Rules[I];
				In[I].Variants = &Settings[I];
			}
			const std::vector<std::vector<FPlacement>> Got = FRule::PlacementsLayered(In);
			for (size_t I = 0; I < In.size(); ++I)
			{
				const FJsonValue& Expected = C["expected"][I];
				Placements += Expected.Size();
				std::string First;
				for (size_t K = 0; K < std::max(Got[I].size(), Expected.Size()) && First.empty(); ++K)
				{
					std::string W = "nothing", G = "nothing";
					if (K < Expected.Size())
					{
						const FJsonValue& E = Expected[K];
						W = Show(Vec(E)) + " " + (E[3].IsNull() ? std::string("null") : E[3].String) + " " + std::to_string(E[4].AsInt());
					}
					if (K < Got[I].size())
						G = Show(Got[I][K].Vertex) + " " + (Got[I][K].Tile.empty() ? std::string("null") : Got[I][K].Tile) + " " + std::to_string(Got[I][K].QuarterTurns);
					if (W != G) First = "layer " + std::to_string(I) + " at " + std::to_string(K) + ": expected " + W + ", got " + G;
				}
				if (!First.empty()) { ++Failed; std::printf("  FAIL layers %s — %s\n", C["name"].String.c_str(), First.c_str()); }
				if (!In[I].bVisible) { if (Expected.Size() == 0) bHiddenEmpty = true; }
				else
				{
					const std::vector<FPlacement> Alone = Rules[I].Placements(Sets[I], &Settings[I]);
					bool bSame = Alone.size() == Got[I].size();
					for (size_t K = 0; bSame && K < Alone.size(); ++K)
						bSame = Alone[K].Vertex == Got[I][K].Vertex && Alone[K].Tile == Got[I][K].Tile && Alone[K].QuarterTurns == Got[I][K].QuarterTurns;
					if (!bSame) ++DifferAlone;
				}
			}
		}
		if (Cases < 5) { ++Failed; std::printf("  FAIL conformance.json has %d layered case(s)\n", Cases); }
		if (DifferAlone < 4) { ++Failed; std::printf("  FAIL the layered cases do not exercise the union\n"); }
		if (!bHiddenEmpty) { ++Failed; std::printf("  FAIL no hidden layer that places nothing\n"); }
		std::printf("%d layered cases, %zu placements, %d failure(s)\n", Cases, Placements, Failed);
		return Failed;
	}

	int RunTools(const std::string& Path)
	{
		FJsonValue Conf;
		if (!Load(Path, Conf)) return 1;
		if (Conf["format"].String != "marchingblocks-tools-conformance" || Conf["version"].AsInt() > 1)
		{
			std::printf("  FAIL not a tools conformance file this plugin reads\n");
			return 1;
		}
		int Failed = 0, Cases = 0;
		if (Conf["limits"]["box_volume_max"].AsInt() != Tools::BoxVolumeMax)
		{
			++Failed;
			std::printf("  FAIL box_volume_max differs from the plugin's\n");
		}
		const FCellSet World = Cells(Conf["world"]);
		std::map<std::string, FCellSet> ShapeWorlds;
		if (Conf.Find("shape_worlds"))
			for (const auto& Entry : Conf["shape_worlds"].Object) ShapeWorlds[Entry.first] = Cells(Entry.second);
		if (Conf["limits"]["shape_length_max"].AsInt() != Shapes::LengthMax || Conf["limits"]["shape_span_max"].AsInt() != Shapes::SpanMax)
		{
			++Failed;
			std::printf("  FAIL shape limits differ from the plugin's\n");
		}
		for (const FJsonValue& C : Conf["cases"].Array)
		{
			++Cases;
			const std::string Why = RunToolCase(C, World, ShapeWorlds);
			if (!Why.empty()) { ++Failed; std::printf("  FAIL tools: %s — %s\n", C["name"].String.c_str(), Why.c_str()); }
		}
		std::printf("%d tools cases, %d failure(s)\n", Cases, Failed);
		return Failed;
	}
	// THE WORLD FILE: every case is a world.json and what the reference reader made of it — a refusal
	// ({"error": true}; the REASON is not imposed) or the layers, cells in the order of the file.
	int RunWorld(const std::string& Path)
	{
		FJsonValue Conf;
		if (!Load(Path, Conf)) return 1;
		if (Conf["format"].String != "marchingblocks-world-conformance" || Conf["version"].AsInt() > FWorldFile::SupportedVersion)
		{
			std::printf("  FAIL not a world conformance file this plugin reads\n");
			return 1;
		}
		int Failed = 0, Cases = 0, Refused = 0, Layers = 0, WeightsRead = 0, ChoicesRead = 0;
		size_t CellCount = 0;
		for (const FJsonValue& C : Conf["cases"].Array)
		{
			++Cases;
			// Pre-filled on purpose: a refused file must give NOTHING, not what the caller's vector held.
			std::vector<FWorldLayer> Got(1);
			Got[0].Name = "left over";
			const std::string Error = FWorldFile::Read(C["world"], Got);
			const FJsonValue& E = C["expected"];
			std::string Why;
			if (E.Find("error"))
			{
				++Refused;
				if (Error.empty()) Why = "expected a refusal, the file was accepted";
				else if (!Got.empty()) Why = "refused, but layers were returned anyway";
			}
			else if (!Error.empty()) Why = "expected the file to be read, refused: " + Error;
			else if (Got.size() != E["layers"].Size())
				Why = "expected " + std::to_string(E["layers"].Size()) + " layers, got " + std::to_string(Got.size());
			else
			{
				for (size_t L = 0; L < Got.size() && Why.empty(); ++L)
				{
					const FJsonValue& W = E["layers"][L];
					const FWorldLayer& G = Got[L];
					++Layers;
					if (G.Name != W["name"].String) Why = "layer " + std::to_string(L) + ": name '" + G.Name + "'";
					else if (G.bVisible != W["visible"].Bool) Why = "layer '" + G.Name + "': visibility";
					else if (G.bHasTileset != !W["tileset"].IsNull() || G.Tileset != W["tileset"].String)
						Why = "layer '" + G.Name + "': tileset '" + G.Tileset + "'";
					else
					{
						std::vector<FCell> Want;
						for (const FJsonValue& P : W["cells"].Array) Want.push_back(Vec(P));
						CellCount += Want.size();
						if (G.Cells != Want) Why = "layer '" + G.Name + "': cells: expected " + ShowList(Want) + ", got " + ShowList(G.Cells);
					}
					// Step 8: the weights as given, the choices sorted by vertex.
					if (Why.empty())
					{
						const FJsonValue& EW = W["variant_weights"];
						if (EW.Object.size() != G.Variants.Weights.size()) Why = "layer '" + G.Name + "': variant weights";
						for (const auto& Entry : EW.Object)
						{
							const auto Found = G.Variants.Weights.find(Entry.first);
							bool bSame = Found != G.Variants.Weights.end() && Found->second.size() == Entry.second.Size();
							for (size_t K = 0; bSame && K < Entry.second.Size(); ++K) bSame = Found->second[K] == Entry.second[K].AsInt();
							if (!bSame) Why = "layer '" + G.Name + "': the variant weights of '" + Entry.first + "'";
							else ++WeightsRead;
						}
						const FJsonValue& EC = W["variant_choices"];
						if (EC.Size() != G.ChoicesSorted.size()) Why = "layer '" + G.Name + "': variant choices";
						else
							for (size_t K = 0; K < EC.Size(); ++K)
							{
								if (!(Vec(EC[K]) == G.ChoicesSorted[K].first) || EC[K][3].AsInt() != G.ChoicesSorted[K].second)
								{ Why = "layer '" + G.Name + "': variant choice " + std::to_string(K); break; }
								++ChoicesRead;
							}
					}
				}
			}
			if (!Why.empty()) { ++Failed; std::printf("  FAIL world: %s — %s\n", C["name"].String.c_str(), Why.c_str()); }
		}
		if (WeightsRead == 0 || ChoicesRead == 0) { ++Failed; std::printf("  FAIL the world cases read no variant weights or choices\n"); }
		std::printf("%d world cases (%d refusals, %d layers read, %zu cells), %d failure(s)\n", Cases, Refused, Layers, CellCount, Failed);
		return Failed;
	}

	// THE FRAME, on a synthetic importer that MIRRORS and works in CENTIMETRES — what a left-handed,
	// +Z-up engine necessarily does. The expected values come from the frame we build, not from FFrame.
	int RunFrame()
	{
		int Failed = 0;
		auto Fail = [&Failed](const char* What) { ++Failed; std::printf("  FAIL frame: %s\n", What); };
		auto Near = [](const FVec3& A, const FVec3& B) { return (A - B).Length() < 1e-9; };
		// Format +X → Unreal +Y, +Y (up) → +Z, +Z → −X, times 100: determinant < 0.
		const FVec3 FX(0, 100, 0), FY(0, 0, 100), FZ(-100, 0, 0);
		auto F = [&](double X, double Y, double Z) { return FX * X + FY * Y + FZ * Z; };
		FFrame Frame;
		std::string Error;
		const std::vector<FVec3> Marker = {F(0, 0, 3), F(0, 0, 0), F(1, 0, 0), F(0, 2, 0), F(1, 0, 0), F(0, 0, 0)};
		if (!FFrame::Measure(Marker, Frame, Error)) { Fail(Error.c_str()); return Failed; }
		if (!Near(Frame.AxisX, FX) || !Near(Frame.AxisY, FY) || !Near(Frame.AxisZ, FZ)) Fail("the axes are not read back");
		if (std::fabs(Frame.Unit - 100.0) > 1e-9) Fail("the unit is not 100");
		if (!Frame.IsMirrored()) Fail("a mirror is not seen as one");
		const FVec3 P(1.5, -2.0, 3.25);
		if (!Near(Frame.ToImported(P), F(1.5, -2.0, 3.25))) Fail("ToImported is not F");
		if (!Near(Frame.ToFormat(Frame.ToImported(P)), P)) Fail("ToFormat does not undo ToImported");
		for (int Q = 0; Q < 4; ++Q)
		{
			const std::array<FVec3, 3> M = Frame.QuarterTurn(Q);
			auto Apply = [&M](const FVec3& V) { return M[0] * V.X + M[1] * V.Y + M[2] * V.Z; };
			const double Det = M[0].X * (M[1].Y * M[2].Z - M[1].Z * M[2].Y) - M[0].Y * (M[1].X * M[2].Z - M[1].Z * M[2].X)
				+ M[0].Z * (M[1].X * M[2].Y - M[1].Y * M[2].X);
			if (std::fabs(Det - 1.0) > 1e-9) Fail("a quarter turn is not a proper rotation (determinant +1)");
			// Written by hand: 0 → +Z stays, 1 → +Z goes to +X, 2 → −Z, 3 → −X — IN FORMAT SPACE.
			const FVec3 Want[4] = {F(0, 0, 1), F(1, 0, 0), F(0, 0, -1), F(-1, 0, 0)};
			if (!Near(Apply(F(0, 0, 1)), Want[Q])) Fail("a quarter turn does not send format +Z where the rule says");
			if (!Near(Apply(F(0, 1, 0)), F(0, 1, 0))) Fail("a quarter turn moves format up");
		}
		// Any yaw (the plants): Turn(q pi / 2) is the quarter turn, and a yaw a sends format +Z to (sin a, 0, cos a).
		for (int Q = 0; Q < 4; ++Q)
		{
			const std::array<FVec3, 3> A = Frame.QuarterTurn(Q), B = Frame.Turn(Q * 1.5707963267948966);
			for (size_t K = 0; K < 3; ++K)
				if ((A[K] - B[K]).Length() > 1e-9) Fail("Turn(q pi / 2) is not QuarterTurn(q)");
		}
		{
			const double Yaw = 0.7;
			const std::array<FVec3, 3> M = Frame.Turn(Yaw);
			auto Apply = [&M](const FVec3& V) { return M[0] * V.X + M[1] * V.Y + M[2] * V.Z; };
			if (!Near(Apply(F(0, 0, 1)), F(std::sin(Yaw), 0, std::cos(Yaw)))) Fail("Turn(a) does not send format +Z to (sin a, 0, cos a)");
			if (!Near(Apply(F(0, 1, 0)), F(0, 1, 0))) Fail("Turn(a) moves format up");
		}
		FFrame Broken;
		if (FFrame::Measure({F(0, 0, 0), F(1, 0, 0), F(0, 2, 0)}, Broken, Error)) Fail("a marker missing a point is accepted");
		if (FFrame::Measure({F(1, 0, 0), F(0, 2, 0), F(0, 0, 3), F(0, 0, 5)}, Broken, Error)) Fail("a stray point is accepted");
		std::printf("frame: mirrored centimetre importer, %d failure(s)\n", Failed);
		return Failed;
	}

	// THE AIM AND NAVIGATION (decided 29 September 2026): Tab alternates Grid ↔ Sculpt only, Space switches
	// navigation without touching the aim, choosing an aim leaves navigation. Every expected state is
	// written by hand, never computed by the functions under test.
	int RunAim()
	{
		int Failed = 0, Checks = 0;
		auto State = [](EAim Aim, bool bNavigating) { FAimState S; S.Aim = Aim; S.bNavigating = bNavigating; return S; };
		auto Expect = [&](const FAimState& Got, const FAimState& Want, const char* What)
		{
			++Checks;
			if (!(Got == Want)) { ++Failed; std::printf("  FAIL aim: %s\n", What); }
		};
		const FAimState Grid = State(EAim::Grid, false), Sculpt = State(EAim::Sculpt, false);
		const FAimState GridFlying = State(EAim::Grid, true), SculptFlying = State(EAim::Sculpt, true);

		// Tab: two aims, never navigation — however many times it is pressed.
		Expect(Tools::Tab(Grid), Sculpt, "Tab from Grid is not Sculpt");
		Expect(Tools::Tab(Sculpt), Grid, "Tab from Sculpt is not Grid (Tab must never enter navigation)");
		FAimState S = Grid;
		for (int I = 0; I < 6; ++I)
		{
			S = Tools::Tab(S);
			Expect(S, I % 2 == 0 ? Sculpt : Grid, "Tab pressed again and again leaves the Grid ↔ Sculpt cycle");
		}
		// Tab while navigating is choosing an aim: it leaves navigation, and alternates.
		Expect(Tools::Tab(GridFlying), Sculpt, "Tab while navigating from Grid is not Sculpt, painting");
		Expect(Tools::Tab(SculptFlying), Grid, "Tab while navigating from Sculpt is not Grid, painting");

		// Space: on, then off, and the aim comes back unchanged.
		Expect(Tools::ToggleNavigate(Grid), GridFlying, "Space does not switch navigation on (Grid)");
		Expect(Tools::ToggleNavigate(Sculpt), SculptFlying, "Space does not switch navigation on (Sculpt)");
		Expect(Tools::ToggleNavigate(GridFlying), Grid, "Space does not switch navigation off (Grid)");
		Expect(Tools::ToggleNavigate(SculptFlying), Sculpt, "the aim is lost after switching navigation off (Sculpt)");
		Expect(Tools::ToggleNavigate(Tools::ToggleNavigate(Sculpt)), Sculpt, "Space twice does not give Sculpt back");

		// Choosing an aim leaves navigation — the current aim included.
		Expect(Tools::ChooseAim(GridFlying, EAim::Sculpt), Sculpt, "choosing Sculpt while navigating does not leave navigation");
		Expect(Tools::ChooseAim(SculptFlying, EAim::Sculpt), Sculpt, "choosing the current aim while navigating does not leave navigation");
		Expect(Tools::ChooseAim(SculptFlying, EAim::Grid), Grid, "choosing Grid while navigating does not leave navigation");
		Expect(Tools::ChooseAim(Grid, EAim::Sculpt), Sculpt, "choosing Sculpt does not set Sculpt");
		Expect(Tools::ChooseAim(Sculpt, EAim::Grid), Grid, "choosing Grid does not set Grid");

		std::printf("aim: %d checks, %d failure(s)\n", Checks, Failed);
		return Failed;
	}
}

int main(int Argc, char** Argv)
{
	const std::string Dir = Argc > 1 ? Argv[1] : "../MarchingBlocksPaint/Tests";
	int Failed = RunRule(Dir + "/conformance.json");
	Failed += RunLayered(Dir + "/conformance.json");
	Failed += RunVariants(Dir + "/conformance.json");
	Failed += RunTools(Dir + "/tools_conformance.json");
	Failed += RunWorld(Dir + "/world_conformance.json");
	Failed += RunFrame();
	Failed += RunAim();
	Failed += RunParity(Dir);
	// The water sheet; every further argument is an exported .mbworld folder for the end-to-end check.
	Failed += RunWaterMesh(Dir, Argc > 2 ? Argc - 2 : 0, Argv + 2);
	std::printf(Failed == 0 ? "VERDICT: OK\n" : "VERDICT: FAILED\n");
	return Failed == 0 ? 0 : 1;
}
