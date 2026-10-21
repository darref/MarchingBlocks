// MarchingBlocks Paint for Unreal — TRANSITIONS BETWEEN LAYERS: the "transitions" key of world.json, the blend rule
// (which layer's look is laid over a surface, and how much), the table of active directions, and the recommended
// packing of the cells into a volume texture (one byte per cell).
//
// Standard C++, no Unreal dependency: Tests/transitions_conformance.json (computed by the MarchingBlocks tool itself)
// proves it; its rules_text says the rule in full. The GEOMETRY never changes: only the look of the surface does.
// Everything is in FORMAT space.

#pragma once

#include "MBCore/MBJson.h"
#include "MBCore/MBRule.h"

#include <cstdint>
#include <map>
#include <string>
#include <utility>
#include <vector>

#ifndef MARCHINGBLOCKSPAINT_API
#define MARCHINGBLOCKSPAINT_API
#endif

namespace MBPaint
{
	/// How one layer covers another (one direction of a pair).
	struct FTransitionSettings
	{
		double Softness = 0.45;
		double Reach = 0.2;
		double Irregularity = 0.35;
		double Grain = 1.5;
		double FillsHollows = 0.5;
	};

	struct FTransitionPair
	{
		/// Layer indices, A < B.
		int A = 0;
		int B = 1;
		bool bActive = false;
		FTransitionSettings ACoversB;
		FTransitionSettings BCoversA;
	};

	/// The look of a layer laid over another layer's surface: an image projected in a box, times a colour.
	struct FRepresentative
	{
		bool bHasImage = false;
		/// A PNG path RELATIVE to world.json.
		std::string Image;
		/// Multiplies the image AS IS (no sRGB conversion of the colour).
		double Color[4] = {1.0, 1.0, 1.0, 1.0};
		/// World cells per repeat of the image (at least 0.01).
		double Scale = 1.0;
		double Roughness = 1.0;
	};

	struct FTransitions
	{
		std::vector<FTransitionPair> Pairs;
		/// One per layer, in layer order.
		std::vector<FRepresentative> Representatives;
		/// At a vertex, the layer chosen to cover — sorted by vertex.
		std::vector<std::pair<FCell, int>> Choices;
	};

	/// "C|D" → the settings when C covers D, for every direction of an ACTIVE pair whose layers both blend.
	using FTransitionTable = std::map<std::pair<int, int>, FTransitionSettings>;

	/// The blend at a point: nothing drawn (bDrawn false), or the owner of the surface, the other layer, its part s, its
	/// vote, and the alpha of the other layer's look over the surface.
	struct FBlend
	{
		bool bDrawn = false;
		int Owner = -1;
		int Other = -1;
		double S = 0.0;
		double Vote = 0.0;
		double Alpha = 0.0;
	};

	/// The recommended packing: TWO bytes per cell (RG) over the box of the cells grown by Margin; R = rank + 1 (0 empty
	/// or rank >= 255), G = chosen rank + 1 at that vertex (0 none). Texel (x, y, z) = cell - Origin, stored x fastest,
	/// then y, then z; texel i holds Bytes[2 i] (R) and Bytes[2 i + 1] (G).
	struct FCellTexture
	{
		FCell Origin;
		FCell Size = FCell(1, 1, 1);
		std::vector<uint8_t> Bytes;
		/// -1 outside the box.
		int64_t IndexOf(const FCell& C) const;
	};

	namespace Transitions
	{
		constexpr int LayersMax = 255;
		constexpr int Margin = 6;

		/// One direction's settings, read under their English names: a missing one takes its default, one out of
		/// range is clamped. (A setting that is not a number is refused by Read, not here.)
		MARCHINGBLOCKSPAINT_API FTransitionSettings ReadSettings(const FJsonValue& Value);
		MARCHINGBLOCKSPAINT_API FJsonValue SettingsToJson(const FTransitionSettings& S);

		/// Reads the "transitions" key of a decoded world.json. "" and Out filled, or the reason the file is refused.
		/// Absent: no pair, no representative, no choice.
		MARCHINGBLOCKSPAINT_API std::string Read(const FJsonValue& World, FTransitions& Out);
		MARCHINGBLOCKSPAINT_API FJsonValue ToJson(const FTransitions& T);

		/// The active directions of the pairs, for a world of LayerCount layers.
		MARCHINGBLOCKSPAINT_API FTransitionTable Table(const std::vector<FTransitionPair>& Pairs, int LayerCount);

		/// THE BLEND at the point F in [0, 1]^3 of the cell box of the tile's vertex v. Ranks[k] and Choices[k]: corner
		/// k = dx + 2 dy + 4 dz is cell v + d (-1 empty / none). H: the luminance of each layer's look at p (0.5 when
		/// absent, as for a layer not in the map). N: the noise in [0, 1].
		MARCHINGBLOCKSPAINT_API FBlend Blend(const int Ranks[8], const double F[3], const int Choices[8], const FTransitionTable& Table,
			const std::map<int, double>& H, double N);

		/// The packing of the union {cell: rank} and the choices {vertex: rank} (a choice outside the box is dropped).
		MARCHINGBLOCKSPAINT_API FCellTexture BuildCellTexture(const std::vector<std::pair<FCell, int>>& Cells,
			const std::vector<std::pair<FCell, int>>& Choices);
	}
}
