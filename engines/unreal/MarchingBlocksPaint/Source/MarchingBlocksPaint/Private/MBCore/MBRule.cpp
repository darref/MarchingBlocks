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
		for (const char* Field : {"corners", "table", "classes", "context", "copies"})
			if (!Manifest.Find(Field)) return std::string("not a MarchingBlocks tileset: '") + Field + "' is missing";
		if (Manifest["table"].Type != FJsonValue::EType::Array || Manifest["table"].Size() != 256)
			return "the table must have 256 entries";
		if (Manifest["corners"].Size() != 8) return "corners must have 8 entries";
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
		const FJsonValue& Copies = Manifest["copies"];
		for (size_t P = 0; P < 3; ++P) Primes[P] = Copies["hash"][P].AsInt();
		Mask = Copies["mask"].AsInt();

		const FJsonValue& Source = InTiles ? *InTiles : Manifest["tiles"];
		for (const auto& Entry : Source.Object)
		{
			std::vector<std::string>& Names = Tiles[Entry.first];
			for (const FJsonValue& N : Entry.second.Array) Names.push_back(N.String);
		}
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
		std::vector<FPlacement> Result;
		if (ClassIds.empty()) return Result;
		int Top = INT_MIN;
		for (const FCell& C : Cells) Top = std::max(Top, C.Y);
		FCellSet Vertices;
		for (const FCell& C : Cells)
			for (const FCell& Corner : Corners) Vertices.insert(C - Corner);

		for (const FCell& V : Vertices)
		{
			int Bits = 0;
			for (int T = 0; T < 8; ++T)
				if (Cells.count(V + Corners[static_cast<size_t>(T)])) Bits |= 1 << T;
			const int Class = TableClass[static_cast<size_t>(Bits)];
			if (Class < 0) continue;
			const std::string& Id = ClassIds[static_cast<size_t>(Class)];
			std::string Chosen;
			if (OutdoorPossible[static_cast<size_t>(Class)] && IsOutdoor(Cells, V, Top) && HasTile(Id + OutdoorSuffix))
				Chosen = Id + OutdoorSuffix;
			if (Chosen.empty() && HasTile(Id)) Chosen = Id;

			FPlacement P;
			P.Vertex = V;
			P.QuarterTurns = TableTurns[static_cast<size_t>(Bits)];
			if (!Chosen.empty())
			{
				const std::vector<std::string>& List = Tiles.at(Chosen);
				const uint64_t H = (static_cast<uint64_t>(static_cast<int64_t>(V.X)) * static_cast<uint64_t>(Primes[0]))
					^ (static_cast<uint64_t>(static_cast<int64_t>(V.Y)) * static_cast<uint64_t>(Primes[1]))
					^ (static_cast<uint64_t>(static_cast<int64_t>(V.Z)) * static_cast<uint64_t>(Primes[2]));
				P.Tile = List[static_cast<size_t>((H & static_cast<uint64_t>(Mask)) % List.size())];
			}
			Result.push_back(std::move(P));
		}
		std::sort(Result.begin(), Result.end(), [](const FPlacement& A, const FPlacement& B) { return A.Vertex < B.Vertex; });
		return Result;
	}
}
