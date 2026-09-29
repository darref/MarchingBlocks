// MarchingBlocks Paint for Unreal — the world.json reader (see MBWorldFile.h).

#include "MBCore/MBWorldFile.h"

#include <cmath>
#include <limits>

namespace MBPaint
{
	// A named namespace, not `static` functions: Unreal's unity builds glue .cpp files together, and two
	// file-local helpers with the same name would collide.
	namespace WorldFileDetail
	{
		/// A number that is an integer, written 3 or 3.0 alike — the writers of the format may use either.
		bool IsWhole(const FJsonValue& V)
		{
			if (V.Type == FJsonValue::EType::Integer) return true;
			return V.Type == FJsonValue::EType::Real && std::isfinite(V.Real) && std::floor(V.Real) == V.Real;
		}

		/// A cell coordinate: an integer that fits the cell grid's int. Anything else is refused, never
		/// rounded or wrapped.
		bool ReadCoordinate(const FJsonValue& V, int& Out)
		{
			if (!IsWhole(V)) return false;
			const double Low = static_cast<double>(std::numeric_limits<int>::min());
			const double High = static_cast<double>(std::numeric_limits<int>::max());
			if (V.Type == FJsonValue::EType::Integer)
			{
				if (V.Integer < std::numeric_limits<int>::min() || V.Integer > std::numeric_limits<int>::max()) return false;
				Out = static_cast<int>(V.Integer);
				return true;
			}
			if (V.Real < Low || V.Real > High) return false;
			Out = static_cast<int>(V.Real);
			return true;
		}

		std::string ShowCell(const FCell& C)
		{
			return "(" + std::to_string(C.X) + ", " + std::to_string(C.Y) + ", " + std::to_string(C.Z) + ")";
		}
	}

	std::string FWorldFile::Read(const FJsonValue& World, std::vector<FWorldLayer>& OutLayers)
	{
		OutLayers.clear();
		if (World.Type != FJsonValue::EType::Object || World["format"].Type != FJsonValue::EType::String
			|| World["format"].String != Format)
			return "not a MarchingBlocks world";
		const FJsonValue& Version = World["version"];
		if (!WorldFileDetail::IsWhole(Version) || Version.AsReal() < 1.0) return "no valid version";
		if (Version.AsReal() > static_cast<double>(SupportedVersion))
			// Its rule may mean something else: reading it anyway would be a silent lie.
			return "this world uses a format version newer than this plugin's (" + std::to_string(SupportedVersion)
				+ "): update the plugin";
		const FJsonValue& Layers = World["layers"];
		if (Layers.Type != FJsonValue::EType::Array) return "layers is not an array";

		std::vector<FWorldLayer> Parsed;
		Parsed.reserve(Layers.Array.size());
		for (const FJsonValue& L : Layers.Array)
		{
			if (L.Type != FJsonValue::EType::Object || L["name"].Type != FJsonValue::EType::String
				|| L["visible"].Type != FJsonValue::EType::Bool)
				return "a layer has no name or no visibility";
			FWorldLayer Layer;
			Layer.Name = L["name"].String;
			Layer.bVisible = L["visible"].Bool;
			const std::string Where = "layer '" + Layer.Name + "': ";
			const FJsonValue& Tileset = L["tileset"];
			// An ABSENT tileset reads as null, as it does in the reference reader.
			if (Tileset.Type == FJsonValue::EType::String)
			{
				Layer.bHasTileset = true;
				Layer.Tileset = Tileset.String;
			}
			else if (!Tileset.IsNull())
				return Where + "tileset is neither a path nor null";
			const FJsonValue& Flat = L["cells"];
			if (Flat.Type != FJsonValue::EType::Array || Flat.Array.size() % 3 != 0)
				return Where + "cells is not a list of x y z triples";
			FCellSet Seen;
			Layer.Cells.reserve(Flat.Array.size() / 3);
			// Bounded by whole triples: a trailing partial triple is never read as a cell.
			for (size_t I = 0; I + 2 < Flat.Array.size(); I += 3)
			{
				int X = 0, Y = 0, Z = 0;
				if (!WorldFileDetail::ReadCoordinate(Flat.Array[I], X) || !WorldFileDetail::ReadCoordinate(Flat.Array[I + 1], Y)
					|| !WorldFileDetail::ReadCoordinate(Flat.Array[I + 2], Z))
					return Where + "a cell coordinate is not an integer";
				const FCell Cell(X, Y, Z);
				if (!Seen.insert(Cell).second) return Where + "the cell " + WorldFileDetail::ShowCell(Cell) + " appears twice";
				Layer.Cells.push_back(Cell);
			}
			Parsed.push_back(std::move(Layer));
		}
		OutLayers = std::move(Parsed);
		return "";
	}

	std::string FWorldFile::ReadText(const std::string& Text, std::vector<FWorldLayer>& OutLayers)
	{
		OutLayers.clear();
		FJsonValue World;
		std::string Error;
		if (!ParseJson(Text, World, Error)) return "world.json is not valid JSON: " + Error;
		return Read(World, OutLayers);
	}
}
