// The core's OWN conformance cases for mbcore::World (CLAUDE.md §0, « le cœur C++ », step 3).
//
// 1. Every case of conformance.json — single layer, variants, layers — built into a World: the placements must be
//    exactly the expected ones (the cases are computed by the app's GDScript reference, `MB.poses…`).
// 2. The INCREMENTAL route: the same worlds, and random worlds, built gesture by gesture (cells set and cleared,
//    taken from another layer, layers hidden and shown, moved, removed, variant choices). After each gesture the
//    placements kept by applying the DELTAS must equal what an independent implementation places from scratch —
//    the Unreal plugin's FRule::PlacementsLayered, another author of the same written rule.
//
// Build and run: ./build.sh (the flags mimic Unreal: no exceptions, no RTTI, shadowing and narrowing as errors).

#include "../src/noyau/world.h"

#include "MBCore/MBJson.h"
#include "MBCore/MBRule.h"

#include <algorithm>
#include <cstdio>
#include <fstream>
#include <map>
#include <random>
#include <sstream>
#include <string>
#include <unordered_map>
#include <vector>

using mbcore::Cell;

namespace
{
	int Failed = 0;
	int Checks = 0;
	std::map<std::string, int> Kinds; // how many gestures of each kind were verified

	void Check(bool Ok, const std::string& What)
	{
		++Checks;
		if (!Ok)
		{
			++Failed;
			std::printf("  FAIL %s\n", What.c_str());
		}
	}

	bool Load(const std::string& Path, MBPaint::FJsonValue& Out)
	{
		std::ifstream In(Path, std::ios::binary);
		if (!In) return false;
		std::stringstream Buffer;
		Buffer << In.rdbuf();
		std::string Error;
		return MBPaint::ParseJson(Buffer.str(), Out, Error);
	}

	std::string Show(const Cell& C)
	{
		return "(" + std::to_string(C.x) + ", " + std::to_string(C.y) + ", " + std::to_string(C.z) + ")";
	}

	bool Less(const Cell& A, const Cell& B)
	{
		return A.x != B.x ? A.x < B.x : A.y != B.y ? A.y < B.y : A.z < B.z;
	}

	// The rule as data, from the manifest: the class table and the tile names of each tileset.
	struct Rules
	{
		std::array<mbcore::RuleRow, 256> Rows{};
		int32_t Classes = 0;
		std::vector<std::string> ClassIds;
		std::vector<std::string> Names; // tile id -> name
		std::unordered_map<std::string, int32_t> Ids;

		int32_t Id(const std::string& Name)
		{
			const auto F = Ids.find(Name);
			if (F != Ids.end()) return F->second;
			Names.push_back(Name);
			Ids[Name] = static_cast<int32_t>(Names.size()) - 1;
			return Ids[Name];
		}
	};

	Rules ReadRules(const MBPaint::FJsonValue& Conf)
	{
		Rules R;
		const MBPaint::FJsonValue& Classes = Conf["classes"];
		R.Classes = static_cast<int32_t>(Classes.Size());
		for (const MBPaint::FJsonValue& C : Classes.Array) R.ClassIds.push_back(C["id"].String);
		for (size_t B = 0; B < 256; ++B)
		{
			const MBPaint::FJsonValue& Row = Conf["table"][B];
			const int32_t Cls = static_cast<int32_t>(Row[0].AsInt());
			R.Rows[B].cls = Cls;
			R.Rows[B].turn = static_cast<int32_t>(Row[1].AsInt());
			R.Rows[B].outdoor = Cls >= 0 && Classes[static_cast<size_t>(Cls)]["outdoor_possible"].Bool;
		}
		return R;
	}

	// A layer's tiles for the World: per key (cls * 2 + outdoor), the base tile, its variants, their weights.
	std::vector<mbcore::KeyTiles> KeysOf(Rules& R, const MBPaint::FJsonValue& Conf, const std::string& Set,
		const MBPaint::FVariantSettings& Settings)
	{
		std::vector<mbcore::KeyTiles> Keys(static_cast<size_t>(R.Classes) * 2);
		const MBPaint::FJsonValue& Tiles = Conf["tilesets"][Set];
		const MBPaint::FJsonValue* Variants = Conf["tileset_variants"].Find(Set);
		for (int32_t C = 0; C < R.Classes; ++C)
			for (int Outdoor = 0; Outdoor < 2; ++Outdoor)
			{
				const std::string Key = R.ClassIds[static_cast<size_t>(C)] + (Outdoor ? "_outdoor" : "");
				const MBPaint::FJsonValue* Base = Tiles.Find(Key);
				if (Base == nullptr || Base->IsNull()) continue;
				mbcore::KeyTiles& K = Keys[static_cast<size_t>(C) * 2 + static_cast<size_t>(Outdoor)];
				K.tiles.push_back(R.Id(Base->String));
				if (Variants != nullptr && Variants->Find(Key) != nullptr)
					for (const MBPaint::FJsonValue& V : (*Variants)[Key].Array) K.tiles.push_back(R.Id(V.String));
				const auto W = Settings.Weights.find(Key);
				for (size_t I = 0; I < K.tiles.size(); ++I)
					K.weights.push_back(W != Settings.Weights.end() && I < W->second.size() ? W->second[I] : 1);
			}
		return Keys;
	}

	MBPaint::FVariantSettings SettingsOf(const MBPaint::FJsonValue& C)
	{
		MBPaint::FVariantSettings S;
		if (C.Find("variant_weights"))
			for (const auto& Entry : C["variant_weights"].Object)
			{
				std::vector<int64_t> W;
				for (const MBPaint::FJsonValue& X : Entry.second.Array) W.push_back(X.AsInt());
				S.Weights[Entry.first] = W;
			}
		if (C.Find("variant_choices"))
		{
			const MBPaint::FJsonValue& Flat = C["variant_choices"];
			for (size_t I = 0; I + 3 < Flat.Size(); I += 4)
				S.Choices[MBPaint::FCell(static_cast<int>(Flat[I].AsInt()), static_cast<int>(Flat[I + 1].AsInt()),
					static_cast<int>(Flat[I + 2].AsInt()))] = Flat[I + 3].AsInt();
		}
		return S;
	}

	std::vector<Cell> CellsOf(const MBPaint::FJsonValue& A)
	{
		std::vector<Cell> L;
		for (const MBPaint::FJsonValue& P : A.Array)
		{
			Cell C;
			C.x = static_cast<int32_t>(P[0].AsInt());
			C.y = static_cast<int32_t>(P[1].AsInt());
			C.z = static_cast<int32_t>(P[2].AsInt());
			L.push_back(C);
		}
		return L;
	}

	// One placement written like the cases: "x y z tile turns".
	std::string Line(const Rules& R, const Cell& V, const mbcore::Placement& P)
	{
		return Show(V) + " " + (P.tile < 0 ? std::string("null") : R.Names[static_cast<size_t>(P.tile)]) + " " + std::to_string(P.turn);
	}

	std::vector<std::string> LinesOfLayer(const Rules& R, const mbcore::World& W, int32_t Layer)
	{
		std::vector<std::pair<Cell, mbcore::Placement>> All;
		W.for_each_placement([&](const Cell& V, const mbcore::Placement& P) { if (P.layer == Layer && P.surface()) All.push_back({V, P}); });
		std::sort(All.begin(), All.end(), [](const auto& A, const auto& B) { return Less(A.first, B.first); });
		std::vector<std::string> L;
		for (const auto& E : All) L.push_back(Line(R, E.first, E.second));
		return L;
	}

	std::vector<std::string> LinesExpected(const MBPaint::FJsonValue& Expected)
	{
		std::vector<std::string> L;
		for (const MBPaint::FJsonValue& E : Expected.Array)
		{
			Cell V;
			V.x = static_cast<int32_t>(E[0].AsInt());
			V.y = static_cast<int32_t>(E[1].AsInt());
			V.z = static_cast<int32_t>(E[2].AsInt());
			L.push_back(Show(V) + " " + (E[3].IsNull() ? std::string("null") : E[3].String) + " " + std::to_string(E[4].AsInt()));
		}
		return L;
	}

	std::string FirstDifference(const std::vector<std::string>& Want, const std::vector<std::string>& Got)
	{
		for (size_t I = 0; I < std::max(Want.size(), Got.size()); ++I)
		{
			const std::string W = I < Want.size() ? Want[I] : "nothing";
			const std::string G = I < Got.size() ? Got[I] : "nothing";
			if (W != G) return "at " + std::to_string(I) + ": expected " + W + ", got " + G;
		}
		return "";
	}

	// ------------------------------------------------------------------ a world described once, built two ways

	struct LayerSpec
	{
		std::string Set;
		bool Visible = true;
		MBPaint::FVariantSettings Settings;
		std::vector<Cell> Cells;
	};

	void SetChoices(mbcore::World& W, int32_t Layer, const MBPaint::FVariantSettings& S)
	{
		for (const auto& E : S.Choices)
		{
			Cell V;
			V.x = E.first.X;
			V.y = E.first.Y;
			V.z = E.first.Z;
			W.set_choice(Layer, V, static_cast<int32_t>(E.second));
		}
	}

	// The cases list cells per layer; a world holds a cell in ONE layer: the first VISIBLE one that lists it
	// (that is what the union reads), otherwise the first one.
	std::vector<std::vector<Cell>> Exclusive(const std::vector<LayerSpec>& Layers)
	{
		std::map<std::tuple<int32_t, int32_t, int32_t>, size_t> Owner;
		for (int Pass = 0; Pass < 2; ++Pass)
			for (size_t I = 0; I < Layers.size(); ++I)
			{
				if ((Pass == 0) != Layers[I].Visible) continue;
				for (const Cell& C : Layers[I].Cells) Owner.emplace(std::make_tuple(C.x, C.y, C.z), I);
			}
		std::vector<std::vector<Cell>> Out(Layers.size());
		for (const auto& E : Owner)
		{
			Cell C;
			C.x = std::get<0>(E.first);
			C.y = std::get<1>(E.first);
			C.z = std::get<2>(E.first);
			Out[E.second].push_back(C);
		}
		return Out;
	}

	mbcore::World Build(Rules& R, const MBPaint::FJsonValue& Conf, const std::vector<LayerSpec>& Layers)
	{
		mbcore::World W;
		W.set_rules(R.Rows, R.Classes);
		const std::vector<std::vector<Cell>> Own = Exclusive(Layers);
		for (size_t I = 0; I < Layers.size(); ++I)
		{
			const int32_t L = W.add_layer();
			W.set_tiles(L, KeysOf(R, Conf, Layers[I].Set, Layers[I].Settings));
			SetChoices(W, L, Layers[I].Settings);
			W.set_visible(L, Layers[I].Visible);
			W.set_cells(L, Own[I], {});
		}
		return W;
	}

	// ------------------------------------------------------------------ 1. the cases of conformance.json

	void RunCases(Rules& R, const MBPaint::FJsonValue& Conf)
	{
		int Cases = 0;
		size_t Placements = 0;
		for (const char* Kind : {"cases", "variant_cases"})
			for (const MBPaint::FJsonValue& C : Conf[Kind].Array)
			{
				++Cases;
				LayerSpec L;
				L.Set = C["tileset"].String;
				L.Settings = SettingsOf(C);
				L.Cells = CellsOf(C["cells"]);
				const mbcore::World W = Build(R, Conf, {L});
				const std::vector<std::string> Want = LinesExpected(C["expected"]);
				Placements += Want.size();
				const std::string D = FirstDifference(Want, LinesOfLayer(R, W, 0));
				Check(D.empty(), std::string(Kind) + " " + C["name"].String + " — " + D);
			}
		for (const MBPaint::FJsonValue& C : Conf["layered_cases"].Array)
		{
			++Cases;
			std::vector<LayerSpec> Layers;
			for (const MBPaint::FJsonValue& L : C["layers"].Array)
			{
				LayerSpec S;
				S.Set = L["tileset"].String;
				S.Visible = L["visible"].Bool;
				S.Settings = SettingsOf(L);
				S.Cells = CellsOf(L["cells"]);
				Layers.push_back(S);
			}
			const mbcore::World W = Build(R, Conf, Layers);
			for (size_t I = 0; I < Layers.size(); ++I)
			{
				const std::vector<std::string> Want = LinesExpected(C["expected"][I]);
				Placements += Want.size();
				const std::string D = FirstDifference(Want, LinesOfLayer(R, W, static_cast<int32_t>(I)));
				Check(D.empty(), "layered " + C["name"].String + " layer " + std::to_string(I) + " — " + D);
			}
		}
		Check(Cases == 30, "30 cases in conformance.json (18 + 6 + 6), found " + std::to_string(Cases));
		std::printf("1. %d cases of conformance.json, %zu placements\n", Cases, Placements);
	}

	// ------------------------------------------------------------------ 2. the incremental route

	// What the placements must be: FRule::PlacementsLayered of the Unreal plugin, from the cells as they are.
	struct Reference
	{
		const MBPaint::FJsonValue* Conf = nullptr;

		std::map<std::tuple<int32_t, int32_t, int32_t>, std::string> Of(const mbcore::World& W, const std::vector<LayerSpec>& Layers,
			const std::vector<int32_t>& Order, const std::vector<std::map<std::tuple<int32_t, int32_t, int32_t>, int32_t>>& Choices) const
		{
			// Order[rank] = the spec index at that rank.
			const size_t N = Order.size();
			std::vector<MBPaint::FCellSet> Sets(N);
			W.for_each_cell([&](const Cell& C, int32_t L) { Sets[static_cast<size_t>(L)].insert(MBPaint::FCell(C.x, C.y, C.z)); });
			std::vector<MBPaint::FRule> Rules;
			std::vector<MBPaint::FVariantSettings> Settings(N);
			Rules.reserve(N);
			for (size_t I = 0; I < N; ++I)
			{
				const LayerSpec& S = Layers[static_cast<size_t>(Order[I])];
				const MBPaint::FJsonValue* V = (*Conf)["tileset_variants"].Find(S.Set);
				Rules.emplace_back(*Conf, &(*Conf)["tilesets"][S.Set], V);
				Settings[I].Weights = S.Settings.Weights;
				for (const auto& E : Choices[static_cast<size_t>(Order[I])])
					Settings[I].Choices[MBPaint::FCell(std::get<0>(E.first), std::get<1>(E.first), std::get<2>(E.first))] = E.second;
			}
			std::vector<MBPaint::FLayerInput> In(N);
			for (size_t I = 0; I < N; ++I)
			{
				In[I].Cells = &Sets[I];
				In[I].bVisible = W.is_visible(static_cast<int32_t>(I));
				In[I].Rule = &Rules[I];
				In[I].Variants = &Settings[I];
			}
			std::map<std::tuple<int32_t, int32_t, int32_t>, std::string> Out;
			const std::vector<std::vector<MBPaint::FPlacement>> Got = MBPaint::FRule::PlacementsLayered(In);
			for (size_t I = 0; I < N; ++I)
				for (const MBPaint::FPlacement& P : Got[I])
					Out[std::make_tuple(P.Vertex.X, P.Vertex.Y, P.Vertex.Z)] =
						std::to_string(I) + " " + (P.Tile.empty() ? std::string("null") : P.Tile) + " " + std::to_string(P.QuarterTurns);
			return Out;
		}
	};

	// The mirror a bridge keeps: it only ever applies deltas.
	struct Mirror
	{
		std::map<std::tuple<int32_t, int32_t, int32_t>, mbcore::Placement> Placements;
		std::map<std::tuple<int32_t, int32_t, int32_t>, int32_t> Cells;
		int Inconsistent = 0;
		size_t Changes = 0;

		void Apply(const mbcore::Delta& D)
		{
			for (size_t I = 0; I < D.cells.size(); ++I)
			{
				const mbcore::CellChange& C = D.cells[I];
				const auto K = std::make_tuple(C.cell.x, C.cell.y, C.cell.z);
				const auto F = Cells.find(K);
				const int32_t Was = F == Cells.end() ? -1 : F->second;
				if (Was != C.before || C.before == C.after) ++Inconsistent;
				if (I > 0 && !Less(D.cells[I - 1].cell, C.cell)) ++Inconsistent;
				if (C.after < 0) Cells.erase(K); else Cells[K] = C.after;
			}
			for (size_t I = 0; I < D.placements.size(); ++I)
			{
				const mbcore::PlacementChange& C = D.placements[I];
				const auto K = std::make_tuple(C.vertex.x, C.vertex.y, C.vertex.z);
				const auto F = Placements.find(K);
				const mbcore::Placement Was = F == Placements.end() ? mbcore::Placement() : F->second;
				if (Was != C.before || C.before == C.after) ++Inconsistent;
				if (I > 0 && !Less(D.placements[I - 1].vertex, C.vertex)) ++Inconsistent;
				if (C.after.exists()) Placements[K] = C.after; else Placements.erase(K);
				++Changes;
			}
		}

		void Drop(const std::vector<int32_t>& ToNew)
		{
			for (auto I = Placements.begin(); I != Placements.end();)
			{
				const int32_t L = ToNew[static_cast<size_t>(I->second.layer)];
				if (L < 0) I = Placements.erase(I); else { I->second.layer = L; ++I; }
			}
			for (auto I = Cells.begin(); I != Cells.end();)
			{
				const int32_t L = ToNew[static_cast<size_t>(I->second)];
				if (L < 0) I = Cells.erase(I); else { I->second = L; ++I; }
			}
		}

		void Renumber(const std::vector<int32_t>& ToNew)
		{
			for (auto& E : Placements) E.second.layer = ToNew[static_cast<size_t>(E.second.layer)];
			for (auto& E : Cells) E.second = ToNew[static_cast<size_t>(E.second)];
		}

		std::map<std::tuple<int32_t, int32_t, int32_t>, std::string> Lines(const Rules& R) const
		{
			std::map<std::tuple<int32_t, int32_t, int32_t>, std::string> Out;
			for (const auto& E : Placements)
				if (E.second.surface())
					Out[E.first] = std::to_string(E.second.layer) + " " +
					(E.second.tile < 0 ? std::string("null") : R.Names[static_cast<size_t>(E.second.tile)]) + " " + std::to_string(E.second.turn);
			return Out;
		}
	};

	std::string MapDifference(const std::map<std::tuple<int32_t, int32_t, int32_t>, std::string>& Want,
		const std::map<std::tuple<int32_t, int32_t, int32_t>, std::string>& Got)
	{
		if (Want == Got) return "";
		for (const auto& E : Want)
		{
			const auto F = Got.find(E.first);
			if (F == Got.end() || F->second != E.second)
				return "at (" + std::to_string(std::get<0>(E.first)) + ", " + std::to_string(std::get<1>(E.first)) + ", " +
					std::to_string(std::get<2>(E.first)) + "): expected " + E.second + ", got " + (F == Got.end() ? "nothing" : F->second);
		}
		for (const auto& E : Got)
			if (Want.find(E.first) == Want.end())
				return "at (" + std::to_string(std::get<0>(E.first)) + ", " + std::to_string(std::get<1>(E.first)) + ", " +
					std::to_string(std::get<2>(E.first)) + "): expected nothing, got " + E.second;
		return "?";
	}

	// A random world of 2 or 3 layers: rolling hills, a floating slab, a cave, cliffs. Coordinates may be negative.
	std::vector<LayerSpec> RandomWorld(std::mt19937& Rng, int Size)
	{
		std::uniform_int_distribution<int> Coin(0, 99);
		const int N = 2 + Coin(Rng) % 2;
		const char* Sets[3] = {"rich", "varied", "bare"};
		std::vector<LayerSpec> Layers(static_cast<size_t>(N));
		for (int I = 0; I < N; ++I)
		{
			Layers[static_cast<size_t>(I)].Set = Sets[(I + Coin(Rng)) % 3];
			if (Layers[static_cast<size_t>(I)].Set == "varied")
			{
				Layers[static_cast<size_t>(I)].Settings.Weights["slab_b2h2_outdoor"] = {2, 1, 1};
				Layers[static_cast<size_t>(I)].Settings.Weights["slab_b0h4"] = {1, -3, 2, 0};
			}
		}
		const int Off = -Size / 2;
		for (int X = 0; X < Size; ++X)
			for (int Z = 0; Z < Size; ++Z)
			{
				const int H = 1 + (X * 7 + Z * 3 + Coin(Rng) % 3) % 5;
				for (int Y = -1; Y < H; ++Y)
				{
					if (Y == 1 && X > 2 && X < 6 && Z > 1 && Z < 5) continue; // a cave under the hills
					Cell C;
					C.x = X + Off;
					C.y = Y;
					C.z = Z + Off;
					Layers[static_cast<size_t>((X / 3 + Z / 4 + (Y > 2 ? 1 : 0)) % N)].Cells.push_back(C);
				}
				if (X > 1 && X < 5 && Z > 4 && Z < 8) // a floating slab, two cells above the hills
				{
					Cell C;
					C.x = X + Off;
					C.y = 8;
					C.z = Z + Off;
					Layers[static_cast<size_t>(N - 1)].Cells.push_back(C);
				}
			}
		return Layers;
	}

	// Plays gestures on a World; after each one, the mirror (deltas only) must equal the reference from scratch.
	void Play(Rules& R, const MBPaint::FJsonValue& Conf, std::vector<LayerSpec> Layers, std::mt19937& Rng, int Gestures,
		const std::string& Name, size_t& Steps, size_t& Changes, size_t& Local, size_t& Total)
	{
		Reference Ref{&Conf};
		mbcore::World W;
		Mirror M;
		M.Apply(W.set_rules(R.Rows, R.Classes));
		std::vector<int32_t> Order; // rank -> spec index
		std::vector<std::map<std::tuple<int32_t, int32_t, int32_t>, int32_t>> Choices(Layers.size());
		for (size_t I = 0; I < Layers.size(); ++I)
		{
			const int32_t L = W.add_layer();
			Order.push_back(static_cast<int32_t>(I));
			M.Apply(W.set_tiles(L, KeysOf(R, Conf, Layers[I].Set, Layers[I].Settings)));
		}
		std::vector<std::vector<Cell>> Pool = Exclusive(Layers);
		for (auto& P : Pool) std::shuffle(P.begin(), P.end(), Rng);
		std::uniform_int_distribution<int> Coin(0, 99);
		bool Bad = false;
		auto Verify = [&](const std::string& What)
		{
			++Steps;
			std::string Kind;
			for (char Ch : What) if (Ch < '0' || Ch > '9') Kind += Ch;
			++Kinds[Kind];
			const std::string D = MapDifference(Ref.Of(W, Layers, Order, Choices), M.Lines(R));
			if (!D.empty() && !Bad)
			{
				Bad = true;
				Check(false, Name + ", after " + What + " — " + D);
			}
		};
		// Paint every layer by small strokes, with gestures in between.
		bool Painting = true;
		for (int G = 0; G < Gestures || Painting; ++G)
		{
			const int Roll = Coin(Rng);
			Painting = false;
			for (const auto& P : Pool) Painting = Painting || !P.empty();
			if (Painting && Roll < 60)
			{
				const size_t Spec = static_cast<size_t>(Coin(Rng)) % Pool.size();
				if (Pool[Spec].empty()) continue;
				std::vector<Cell> Stroke;
				const size_t K = 1 + static_cast<size_t>(Coin(Rng)) % 12;
				while (!Pool[Spec].empty() && Stroke.size() < K)
				{
					Stroke.push_back(Pool[Spec].back());
					Pool[Spec].pop_back();
				}
				const int32_t L = static_cast<int32_t>(std::find(Order.begin(), Order.end(), static_cast<int32_t>(Spec)) - Order.begin());
				const size_t Before = W.placement_count();
				M.Apply(W.set_cells(L, Stroke, {}));
				Total += Before + W.placement_count();
				Local += W.last_decided();
				Verify("a stroke");
			}
			else if (Roll < 72)
			{
				// Clear some cells (whatever layer holds them), or steal them into another layer.
				std::vector<Cell> Some;
				W.for_each_cell([&](const Cell& C, int32_t) { if (Coin(Rng) < 3 && Some.size() < 10) Some.push_back(C); });
				if (Coin(Rng) < 50) { M.Apply(W.set_cells(0, {}, Some)); Verify("a clear"); }
				else
				{
					const int32_t L = static_cast<int32_t>(static_cast<size_t>(Coin(Rng)) % Order.size());
					M.Apply(W.set_cells(L, Some, {}));
					Verify("a theft into layer " + std::to_string(L));
				}
			}
			else if (Roll < 80)
			{
				const int32_t L = static_cast<int32_t>(static_cast<size_t>(Coin(Rng)) % Order.size());
				M.Apply(W.set_visible(L, !W.is_visible(L)));
				Verify("layer " + std::to_string(L) + " hidden / shown");
			}
			else if (Roll < 88 && Roll >= 86 && Order.size() > 1)
			{
				// A layer removed with its cells: the bridge drops it and renumbers, then applies the delta.
				const int32_t L = static_cast<int32_t>(static_cast<size_t>(Coin(Rng)) % Order.size());
				std::vector<int32_t> ToNew(Order.size());
				for (size_t I = 0; I < Order.size(); ++I)
					ToNew[I] = static_cast<int32_t>(I) < L ? static_cast<int32_t>(I) : (static_cast<int32_t>(I) == L ? -1 : static_cast<int32_t>(I) - 1);
				M.Drop(ToNew);
				Order.erase(Order.begin() + L);
				M.Apply(W.remove_layer(L));
				Verify("layer " + std::to_string(L) + " removed");
			}
			else if (Roll < 86)
			{
				const int32_t From = static_cast<int32_t>(static_cast<size_t>(Coin(Rng)) % Order.size());
				const int32_t To = static_cast<int32_t>(static_cast<size_t>(Coin(Rng)) % Order.size());
				// The bridge renumbers its own layers FIRST (what was at From is now at To, the others shift), then
				// applies the delta, which only lists what really changed.
				if (From != To)
				{
					std::vector<int32_t> Ranks(Order.size());
					for (size_t I = 0; I < Ranks.size(); ++I) Ranks[I] = static_cast<int32_t>(I);
					Ranks.erase(Ranks.begin() + From);
					Ranks.insert(Ranks.begin() + To, From);
					std::vector<int32_t> ToNew(Order.size());
					for (size_t I = 0; I < Ranks.size(); ++I) ToNew[static_cast<size_t>(Ranks[I])] = static_cast<int32_t>(I);
					M.Renumber(ToNew);
					const int32_t S = Order[static_cast<size_t>(From)];
					Order.erase(Order.begin() + From);
					Order.insert(Order.begin() + To, S);
				}
				M.Apply(W.move_layer(From, To));
				Verify("a layer moved from " + std::to_string(From) + " to " + std::to_string(To));
			}
			else
			{
				// A variant choice at a placed vertex (in or out of range), or removed.
				std::vector<std::pair<Cell, mbcore::Placement>> Placed;
				W.for_each_placement([&](const Cell& V, const mbcore::Placement& P) { if (P.surface() && Coin(Rng) < 5 && Placed.size() < 40) Placed.push_back({V, P}); });
				if (Placed.empty()) continue;
				const auto& E = Placed[static_cast<size_t>(Coin(Rng)) % Placed.size()];
				const int32_t Choice = Coin(Rng) % 6 - 1;
				M.Apply(W.set_choice(E.second.layer, E.first, Choice));
				const auto Key = std::make_tuple(E.first.x, E.first.y, E.first.z);
				auto& Ch = Choices[static_cast<size_t>(Order[static_cast<size_t>(E.second.layer)])];
				if (Choice < 0) Ch.erase(Key); else Ch[Key] = Choice;
				Verify("a variant choice");
			}
		}
		Check(M.Inconsistent == 0, Name + ": " + std::to_string(M.Inconsistent) + " delta entries do not follow the mirror (before ≠ kept, no change, unsorted)");
		Changes += M.Changes;
	}

	void RunIncremental(Rules& R, const MBPaint::FJsonValue& Conf)
	{
		std::mt19937 Rng(20261006u);
		size_t Steps = 0, Changes = 0, Local = 0, Total = 0;
		int Worlds = 0;
		for (const MBPaint::FJsonValue& C : Conf["layered_cases"].Array)
		{
			std::vector<LayerSpec> Layers;
			for (const MBPaint::FJsonValue& L : C["layers"].Array)
			{
				LayerSpec S;
				S.Set = L["tileset"].String;
				S.Visible = true;
				S.Settings = SettingsOf(L);
				S.Cells = CellsOf(L["cells"]);
				Layers.push_back(S);
			}
			Play(R, Conf, Layers, Rng, 20, "layered " + C["name"].String, Steps, Changes, Local, Total);
			++Worlds;
		}
		for (int K = 0; K < 6; ++K)
		{
			Play(R, Conf, RandomWorld(Rng, 10 + K * 2), Rng, 60, "random world " + std::to_string(K), Steps, Changes, Local, Total);
			++Worlds;
		}
		for (const char* K : {"a stroke", "a clear", "a theft into layer ", "layer  hidden / shown", "layer  removed",
				 "a layer moved from  to ", "a variant choice"})
			Check(Kinds[K] > 5, std::string("gestures of the kind « ") + K + " »: " + std::to_string(Kinds[K]));
		Check(Changes > 1000, "the gestures change placements (" + std::to_string(Changes) + ")");
		// Incremental means incremental: a stroke decides far fewer vertices than the world holds.
		Check(Local * 4 < Total, "a stroke decides a small part of the world (" + std::to_string(Local) + " of " + std::to_string(Total / 2) + ")");
		std::printf("2. %d worlds, %zu gestures, %zu placement changes applied by deltas\n", Worlds, Steps, Changes);
	}

	// ------------------------------------------------------------------ 3. a few rules written by hand

	void RunByHand(Rules& R, const MBPaint::FJsonValue& Conf)
	{
		mbcore::World W;
		W.set_rules(R.Rows, R.Classes);
		const int32_t A = W.add_layer();
		const int32_t B = W.add_layer();
		W.set_tiles(A, KeysOf(R, Conf, "rich", {}));
		W.set_tiles(B, KeysOf(R, Conf, "rich", {}));
		Cell C0;
		const mbcore::Delta D1 = W.set_cells(A, {C0}, {});
		Check(D1.cells.size() == 1 && D1.cells[0].before == -1 && D1.cells[0].after == A, "one cell set: one cell change");
		Check(D1.placements.size() == 8, "one lone cell: its 8 vertices placed (" + std::to_string(D1.placements.size()) + ")");
		const mbcore::Delta D2 = W.set_cells(B, {C0}, {});
		Check(W.layer_at(C0) == B && W.cell_count(A) == 0 && W.cell_count(B) == 1, "a cell set in B is taken from A");
		Check(D2.cells.size() == 1 && D2.cells[0].before == A && D2.cells[0].after == B, "the theft is in the delta");
		Check(D2.placements.size() == 8, "the 8 vertices change layer");
		const mbcore::Delta D3 = W.set_visible(B, false);
		Check(D3.placements.size() == 8 && W.placement_count() == 0, "hiding B removes its 8 placements");
		Check(W.set_visible(B, false).empty(), "hiding twice changes nothing");
		const mbcore::Delta D4 = W.set_cells(A, {}, {C0});
		Check(D4.cells.size() == 1 && D4.cells[0].after == -1 && D4.placements.empty() && W.layer_at(C0) == -1,
			"clearing a cell of a hidden layer: the cell goes, no placement changes");
		Check(W.set_cells(A, {C0}, {C0}).cells.size() == 1 && W.layer_at(C0) == A, "a cell both set and cleared is set");
		{
			// Held by A, cleared and set in B in one call: ONE change, A → B; cleared and set back in A: none.
			const mbcore::Delta Both = W.set_cells(B, {C0}, {C0});
			Check(Both.cells.size() == 1 && Both.cells[0].before == A && Both.cells[0].after == B,
				"held by A, cleared and set in B in one call: one change A → B (" + std::to_string(Both.cells.size()) + ")");
			const mbcore::Delta Same = W.set_cells(B, {C0}, {C0});
			Check(Same.empty(), "cleared and set back in the layer that held it: no change at all");
			W.set_cells(A, {}, {C0});
		}
		{
			// New tiles for a PAINTED layer: what it places follows, as a world built with those tiles from the start.
			std::vector<LayerSpec> Specs(1);
			Specs[0].Set = "rich";
			for (int32_t X = 0; X < 5; ++X)
				for (int32_t Z = 0; Z < 4; ++Z)
					for (int32_t Y = 0; Y <= (X + Z) % 3; ++Y)
					{
						Cell C;
						C.x = X;
						C.y = Y;
						C.z = Z;
						Specs[0].Cells.push_back(C);
					}
			mbcore::World T = Build(R, Conf, Specs);
			const mbcore::Delta D = T.set_tiles(0, KeysOf(R, Conf, "bare", {}));
			Specs[0].Set = "bare";
			const mbcore::World Fresh = Build(R, Conf, Specs);
			Check(!D.placements.empty() && FirstDifference(LinesOfLayer(R, Fresh, 0), LinesOfLayer(R, T, 0)).empty(),
				"new tiles for a painted layer: it places what a world built with them places (" + std::to_string(D.placements.size()) + " changes)");
		}
		// The sky: a slab 3 cells above a floor — the floor vertices under it are not outdoor; removing the slab
		// opens their sky, though no cell of theirs changed.
		mbcore::World S;
		S.set_rules(R.Rows, R.Classes);
		S.set_tiles(S.add_layer(), KeysOf(R, Conf, "rich", {}));
		std::vector<Cell> Floor, Slab;
		for (int32_t X = 0; X < 6; ++X)
			for (int32_t Z = 0; Z < 6; ++Z)
			{
				Cell F;
				F.x = X;
				F.z = Z;
				Floor.push_back(F);
				if (X >= 2 && X <= 3 && Z >= 2 && Z <= 3)
				{
					Cell T = F;
					T.y = 4;
					Slab.push_back(T);
				}
			}
		S.set_cells(0, Floor, {});
		S.set_cells(0, Slab, {});
		Cell Under;
		Under.x = 2;
		Under.y = 0;
		Under.z = 2;
		Check(S.placement_at(Under).exists() && !S.placement_at(Under).outdoor, "the floor under the slab is not outdoor");
		const mbcore::Delta D5 = S.set_cells(0, {}, Slab);
		Check(S.placement_at(Under).outdoor, "the slab cleared, the floor under it is outdoor");
		bool Seen = false;
		for (const mbcore::PlacementChange& P : D5.placements) Seen = Seen || (P.vertex.x == 2 && P.vertex.y == 0 && P.vertex.z == 2);
		Check(Seen, "and the delta says so");
		{
			// MUTE vertices: a 3³ block owns 8 vertices whose eight cells are all full — the layer's, no surface.
			mbcore::World Blk;
			Blk.set_rules(R.Rows, R.Classes);
			Blk.set_tiles(Blk.add_layer(), KeysOf(R, Conf, "rich", {}));
			std::vector<Cell> Block;
			for (int32_t X = 0; X < 3; ++X)
				for (int32_t Y = 0; Y < 3; ++Y)
					for (int32_t Z = 0; Z < 3; ++Z)
					{
						Cell C;
						C.x = X;
						C.y = Y;
						C.z = Z;
						Block.push_back(C);
					}
			Blk.set_cells(0, Block, {});
			int Mute = 0, Surface = 0;
			Blk.for_each_placement([&](const Cell& V, const mbcore::Placement& P)
			{
				if (P.surface()) ++Surface;
				else if (P.layer == 0 && P.tile < 0 && V.x >= 0 && V.x <= 1 && V.y >= 0 && V.y <= 1 && V.z >= 0 && V.z <= 1) ++Mute;
			});
			// 4³ = 64 vertices touch the block; the 2³ inside are mute, the 56 others carry a surface.
			Check(Mute == 8 && Surface == 56 && Blk.placement_count() == 64,
				"a 3x3x3 block: 8 mute vertices, 56 on its surface (" + std::to_string(Mute) + ", " + std::to_string(Surface) + ")");
		}
		{
			// set_choices = the same choices set one by one; a choice dropped returns to the draw.
			std::mt19937 Rng(7);
			std::vector<LayerSpec> Specs = RandomWorld(Rng, 12);
			mbcore::World One = Build(R, Conf, Specs);
			mbcore::World All = Build(R, Conf, Specs);
			std::vector<std::pair<Cell, int32_t>> Picked;
			One.for_each_placement([&](const Cell& V, const mbcore::Placement& P)
			{
				if (P.surface() && P.layer == 0 && Picked.size() < 60) Picked.push_back({V, static_cast<int32_t>(Picked.size() % 4)});
			});
			for (const auto& E : Picked) One.set_choice(0, E.first, E.second);
			const mbcore::Delta D = All.set_choices(0, Picked);
			bool Same = true;
			One.for_each_placement([&](const Cell& V, const mbcore::Placement& P) { Same = Same && All.placement_at(V) == P; });
			Check(Same && One.placement_count() == All.placement_count() && !D.placements.empty(),
				"set_choices places what the same choices set one by one place (" + std::to_string(D.placements.size()) + " changes)");
			for (size_t I = 0; I < Picked.size(); I += 2) One.set_choice(0, Picked[I].first, -1);
			std::vector<std::pair<Cell, int32_t>> Half;
			for (size_t I = 1; I < Picked.size(); I += 2) Half.push_back(Picked[I]);
			All.set_choices(0, Half);
			Same = true;
			One.for_each_placement([&](const Cell& V, const mbcore::Placement& P) { Same = Same && All.placement_at(V) == P; });
			Check(Same, "set_choices without half of them: those vertices return to the draw");
			// assign: a world built cell by cell = the same cells assigned at once, over another world.
			mbcore::World Other = Build(R, Conf, RandomWorld(Rng, 9));
			std::vector<std::pair<Cell, int32_t>> Cells;
			One.for_each_cell([&](const Cell& C, int32_t L) { Cells.push_back({C, L}); });
			for (int32_t L = 0; L < One.layer_count(); ++L)
			{
				while (Other.layer_count() <= L) Other.add_layer();
				Other.set_tiles(L, KeysOf(R, Conf, Specs[static_cast<size_t>(L)].Set, Specs[static_cast<size_t>(L)].Settings));
			}
			for (const auto& E : Half) Other.set_choice(0, E.first, E.second);
			Other.assign(Cells);
			Same = Other.placement_count() == One.placement_count() && Other.cell_count() == One.cell_count();
			One.for_each_placement([&](const Cell& V, const mbcore::Placement& P) { Same = Same && Other.placement_at(V) == P; });
			Check(Same, "assign over another world = the world built cell by cell");
		}
		{
			// move_layer is INCREMENTAL (only the vertices where the moved layer meets a layer it passes): every move
			// of three touching blocks, up and down, by one and by two ranks, places what a world built in the new
			// order places. Random worlds alone rarely move a layer along a shared border (an `o < hi` mutation
			// stayed green, 6 October 2026).
			std::vector<LayerSpec> Specs(3);
			const char* Sets[3] = {"rich", "bare", "rich"};
			for (int32_t L = 0; L < 3; ++L)
			{
				Specs[static_cast<size_t>(L)].Set = Sets[L];
				// Disjoint blocks (a cell belongs to ONE layer): 0 at x 0..2, 1 at x 3..5 (both z 0..2), 2 at x 1..4,
				// z -3..-1 — each block touches the two others.
				const int32_t X0 = L == 2 ? 1 : 3 * L, X1 = L == 2 ? 5 : 3 * L + 3;
				for (int32_t X = X0; X < X1; ++X)
					for (int32_t Y = 0; Y < 2 + L % 2; ++Y)
						for (int32_t Z = L == 2 ? -3 : 0; Z < (L == 2 ? 0 : 3); ++Z)
						{
							Cell C;
							C.x = X;
							C.y = Y;
							C.z = Z;
							Specs[static_cast<size_t>(L)].Cells.push_back(C);
						}
			}
			int Moves = 0;
			for (int32_t From = 0; From < 3; ++From)
				for (int32_t To = 0; To < 3; ++To)
				{
					if (From == To) continue;
					mbcore::World Moved = Build(R, Conf, Specs);
					const mbcore::Delta D = Moved.move_layer(From, To);
					std::vector<LayerSpec> Order = Specs;
					const LayerSpec S = Order[static_cast<size_t>(From)];
					Order.erase(Order.begin() + From);
					Order.insert(Order.begin() + To, S);
					const mbcore::World Fresh = Build(R, Conf, Order);
					bool Same = Moved.placement_count() == Fresh.placement_count();
					Fresh.for_each_placement([&](const Cell& V, const mbcore::Placement& P) { Same = Same && Moved.placement_at(V) == P; });
					Check(Same && !D.placements.empty(), "three touching blocks, layer " + std::to_string(From) + " moved to " +
						std::to_string(To) + ": the world built in that order (" + std::to_string(D.placements.size()) + " changes)");
					Moves += Same ? 1 : 0;
				}
			Check(Moves == 6, "the six moves of three touching blocks");
		}
		std::printf("3. rules written by hand\n");
	}
}

int main(int Argc, char** Argv)
{
	const std::string Dir = Argc > 1 ? Argv[1] : "../../engines/unreal/MarchingBlocksPaint/Tests";
	MBPaint::FJsonValue Conf;
	if (!Load(Dir + "/conformance.json", Conf))
	{
		std::printf("cannot read %s/conformance.json\n", Dir.c_str());
		return 1;
	}
	Rules R = ReadRules(Conf);
	RunCases(R, Conf);
	RunIncremental(R, Conf);
	RunByHand(R, Conf);
	std::printf("mbcore::World — %d checks, %d failure(s)\n", Checks, Failed);
	return Failed == 0 ? 0 : 1;
}
