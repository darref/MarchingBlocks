// MarchingBlocks Paint for Unreal — the placement rule (see MBRule.h).

#include "MBCore/MBRule.h"

#include <algorithm>
#include <climits>

namespace MBPaint
{
	namespace RuleDetail
	{
		FCell ToCell(const FJsonValue& A)
		{
			return FCell(static_cast<int>(A[0].AsInt()), static_cast<int>(A[1].AsInt()), static_cast<int>(A[2].AsInt()));
		}
	}

	std::string FRule::CheckManifest(const FJsonValue& Manifest)
	{
		if (Manifest.Type != FJsonValue::EType::Object) return "not a MarchingBlocks tileset: not a JSON object";
		const int64_t Version = Manifest["version"].IsNumber() ? Manifest["version"].AsInt() : 0;
		if (Version > SupportedVersion)
			return "made by a newer MarchingBlocks (format " + std::to_string(Version) + ", this plugin reads "
				+ std::to_string(SupportedVersion) + "): update the plugin";
		for (const char* Field : {"corners", "table", "classes", "context"})
			if (!Manifest.Find(Field)) return std::string("not a MarchingBlocks tileset: '") + Field + "' is missing";
		if (Manifest["table"].Type != FJsonValue::EType::Array || Manifest["table"].Size() != 256)
			return "the table must have 256 entries";
		if (Manifest["corners"].Size() != 8) return "corners must have 8 entries";
		if (Manifest.Find("tiles")) return CheckTiles(Manifest["tiles"]);
		return "";
	}

	std::string FRule::CheckTiles(const FJsonValue& InTiles)
	{
		for (const auto& Entry : InTiles.Object)
			if (Entry.second.Type != FJsonValue::EType::String)
				return "tile '" + Entry.first + "' must be one tile name (one tile per key)";
		return "";
	}

	FRule::FRule(const FJsonValue& Manifest, const FJsonValue* InTiles)
	{
		if (!CheckManifest(Manifest).empty()) return;
		for (size_t T = 0; T < 8; ++T) Corners[T] = RuleDetail::ToCell(Manifest["corners"][T]);
		if (Manifest.Find("piece_offset")) PieceOffset = RuleDetail::ToCell(Manifest["piece_offset"]);

		const FJsonValue& Table = Manifest["table"];
		for (size_t B = 0; B < 256; ++B)
		{
			TableClass[B] = static_cast<int>(Table[B][0].AsInt());
			TableTurns[B] = static_cast<int>(Table[B][1].AsInt());
		}
		const FJsonValue& Classes = Manifest["classes"];
		for (const FJsonValue& C : Classes.Array)
		{
			ClassIds.push_back(C["id"].String);
			OutdoorPossible.push_back(C["outdoor_possible"].Bool);
		}
		const FJsonValue& Context = Manifest["context"];
		if (Context.Find("band")) Band = static_cast<int>(Context["band"].AsInt());
		if (Context.Find("outdoor_suffix")) OutdoorSuffix = Context["outdoor_suffix"].String;

		const FJsonValue& Source = InTiles ? *InTiles : Manifest["tiles"];
		if (!CheckTiles(Source).empty())
		{
			ClassIds.clear();   // an empty rule: a refused manifest places nothing
			return;
		}
		for (const auto& Entry : Source.Object) Tiles[Entry.first] = Entry.second.String;
	}

	bool FRule::HasTile(const std::string& Key) const
	{
		const auto Found = Tiles.find(Key);
		return Found != Tiles.end() && !Found->second.empty();
	}

	// Outdoor: every EMPTY cell among the 8 has nothing full above the vertex's band.
	bool FRule::IsOutdoor(const FCellSet& Cells, const FCell& V, int Top) const
	{
		for (const FCell& Corner : Corners)
		{
			const FCell E = V + Corner;
			if (Cells.count(E)) continue;
			for (int Y = V.Y + Band; Y <= Top; ++Y)
				if (Cells.count(FCell(E.X, Y, E.Z))) return false;
		}
		return true;
	}

	std::vector<FPlacement> FRule::Placements(const FCellSet& Cells) const
	{
		std::vector<FLayerInput> One(1);
		One[0].Cells = &Cells;
		One[0].Rule = this;
		return PlacementsLayered(One)[0];
	}

	std::vector<std::vector<FPlacement>> FRule::PlacementsLayered(const std::vector<FLayerInput>& Layers)
	{
		std::vector<std::vector<FPlacement>> Result(Layers.size());
		const FRule* Reference = nullptr;
		for (const FLayerInput& L : Layers)
			if (L.Rule != nullptr && !L.Rule->ClassIds.empty()) { Reference = L.Rule; break; }
		if (Reference == nullptr) return Result;

		// The union of the visible layers: cell -> the first layer that holds it.
		std::unordered_map<FCell, size_t, FCellHash> Owner;
		FCellSet Union;
		for (size_t I = 0; I < Layers.size(); ++I)
			if (Layers[I].bVisible && Layers[I].Cells != nullptr)
				for (const FCell& C : *Layers[I].Cells)
					if (Union.insert(C).second) Owner[C] = I;
		int Top = INT_MIN;
		for (const FCell& C : Union) Top = std::max(Top, C.Y);
		FCellSet Vertices;
		for (const FCell& C : Union)
			for (const FCell& Corner : Reference->Corners) Vertices.insert(C - Corner);

		for (const FCell& V : Vertices)
		{
			int Bits = 0;
			size_t Own = Layers.size();
			for (int T = 0; T < 8; ++T)
			{
				const auto Found = Owner.find(V + Reference->Corners[static_cast<size_t>(T)]);
				if (Found == Owner.end()) continue;
				Bits |= 1 << T;
				if (Found->second < Own) Own = Found->second;
			}
			const FRule* Rule = Layers[Own].Rule;
			if (Rule == nullptr || Rule->ClassIds.empty()) continue;
			const int Class = Rule->TableClass[static_cast<size_t>(Bits)];
			if (Class < 0) continue;
			const std::string& Id = Rule->ClassIds[static_cast<size_t>(Class)];
			std::string Chosen;
			if (Rule->OutdoorPossible[static_cast<size_t>(Class)] && Rule->IsOutdoor(Union, V, Top) && Rule->HasTile(Id + Rule->OutdoorSuffix))
				Chosen = Id + Rule->OutdoorSuffix;
			if (Chosen.empty() && Rule->HasTile(Id)) Chosen = Id;

			FPlacement P;
			P.Vertex = V;
			P.QuarterTurns = Rule->TableTurns[static_cast<size_t>(Bits)];
			if (!Chosen.empty()) P.Tile = Rule->Tiles.at(Chosen);
			Result[Own].push_back(std::move(P));
		}
		for (std::vector<FPlacement>& List : Result)
			std::sort(List.begin(), List.end(), [](const FPlacement& A, const FPlacement& B) { return A.Vertex < B.Vertex; });
		return Result;
	}
}
