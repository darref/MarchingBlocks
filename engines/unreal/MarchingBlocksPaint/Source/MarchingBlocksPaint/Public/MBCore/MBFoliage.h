// MarchingBlocks Paint for Unreal — FOLIAGE: the "foliage" key of world.json (models and plants), where a plant's
// model sits, the placing rule (three modes, eight refusals, the brush), and the wind data every plant gives the
// wind shader.
//
// Standard C++, no Unreal dependency: Tests/foliage_conformance.json (computed by the MarchingBlocks tool itself)
// proves it; its rules_text says every rule in full. Everything is in FORMAT space (right-handed, +Y up, 1 = a cell):
// the Unreal layer converts with the measured frame.

#pragma once

#include "MBCore/MBJson.h"
#include "MBCore/MBRule.h"

#include <array>
#include <cstdint>
#include <functional>
#include <map>
#include <string>
#include <utility>
#include <vector>

#ifndef MARCHINGBLOCKSPAINT_API
#define MARCHINGBLOCKSPAINT_API
#endif

namespace MBPaint
{
	struct FFoliageModel
	{
		int64_t Id = 0;
		std::string Name;
		/// A .glb path RELATIVE to world.json; empty with bHasMesh false when the author's file was missing.
		bool bHasMesh = false;
		std::string Mesh;
		/// Model units: how far its origin sits ABOVE the ground (negative buries it).
		double GroundOffset = 0.0;
		double Scale = 1.0;
		/// Each plant draws a factor in [1 - a, 1 + a], a <= 0.9.
		double ScaleRandom = 0.2;
		/// The radius on the ground, in cells, at scale 1.
		double Footprint = 0.5;
		/// The top of the model above its origin, model units.
		double Height = 1.0;
		/// 0 still to 1.
		double Wind = 0.5;
	};

	enum class EPlantMode { Air = 0, Planted = 1 };

	struct FPlant
	{
		int64_t Model = 0;
		/// The point ON THE GROUND, format space.
		double X = 0.0, Y = 0.0, Z = 0.0;
		/// Radians around +Y.
		double Yaw = 0.0;
		/// The plant's own draw (the model has its own scale).
		double Scale = 1.0;
		EPlantMode Mode = EPlantMode::Planted;
	};

	struct FFoliage
	{
		std::vector<FFoliageModel> Models;
		std::vector<FPlant> Plants;
		const FFoliageModel* FindModel(int64_t Id) const
		{
			for (const FFoliageModel& M : Models)
				if (M.Id == Id) return &M;
			return nullptr;
		}
	};

	/// The three placing modes: in the air (on the grid plane), planted with a free neighbourhood, planted overflowing.
	enum class EFoliageMode { Air, Free, Overflow };

	/// The ground under a point: its height and normal (format space).
	struct FGround
	{
		double Y = 0.0;
		double Nx = 0.0, Ny = 1.0, Nz = 0.0;
	};

	/// What the placing rule asks of the world. Ground: the ground below YTop at (X, Z), false when there is none.
	/// IsWater may be empty (no water).
	struct FFoliageWorld
	{
		std::function<bool(const FCell&)> IsFull;
		std::function<bool(double X, double Z, double YTop, FGround& Out)> Ground;
		std::function<bool(const FCell&)> IsWater;
	};

	/// The plants already placed, in buckets of 4 cells (never compare a candidate with thousands of plants). The
	/// order is part of the rule: buckets by x then z, plants in the order they joined.
	class MARCHINGBLOCKSPAINT_API FPlantIndex
	{
	public:
		FPlantIndex() = default;
		FPlantIndex(const std::vector<FPlant>& Plants, const FFoliage& Models);
		void Add(const FPlant& Plant, const FFoliage& Models);
		/// The plants within Reach of P in the plane, and within Reach + 2 in height.
		std::vector<const FPlant*> Near(double X, double Y, double Z, double Reach) const;
		double LargestRadius() const { return RadiusMax; }

	private:
		std::map<std::pair<int64_t, int64_t>, std::vector<FPlant>> Buckets;
		double RadiusMax = 0.0;
	};

	/// A stroke of the brush: the accepted plants in order, and the refusals counted by reason.
	struct FBrushResult
	{
		std::vector<FPlant> Plants;
		std::map<std::string, int> Refused;
	};

	namespace Foliage
	{
		constexpr double MaxSlopeDeg = 40.0;
		constexpr double GroundTolerance = 0.35;
		constexpr int EdgeSamples = 8;
		constexpr double Duplicate = 0.05;
		constexpr double WaterOffset = 0.2;
		constexpr int GroundSearchFloor = -64;
		constexpr double WindX = 1.0;
		constexpr double WindZ = 0.35;

		/// Reads the "foliage" key of a decoded world.json. "" and Out filled, or the reason the file is refused (Out
		/// is then empty). Absent: no model, no plant.
		MARCHINGBLOCKSPAINT_API std::string Read(const FJsonValue& World, FFoliage& Out);

		/// The foliage back in the format, normalized — what the conformance cases compare.
		MARCHINGBLOCKSPAINT_API FJsonValue ToJson(const FFoliage& Foliage);

		/// s = model scale × plant scale.
		MARCHINGBLOCKSPAINT_API double ScaleOf(const FFoliageModel& M, const FPlant& P);

		/// max(0, (height + ground_offset) s).
		MARCHINGBLOCKSPAINT_API double HeightAboveGround(const FFoliageModel& M, const FPlant& P);

		/// T = translate(p + (0, ground_offset s, 0)) rotateY(yaw) scale(s): the basis COLUMNS, then the origin.
		MARCHINGBLOCKSPAINT_API void Transform(const FFoliageModel& M, const FPlant& P, double OutColumns[3][3], double OutOrigin[3]);

		/// The refusal ("" = planted): in_matter, too_steep, in_water, at_edge, under_matter, too_close, already_there.
		MARCHINGBLOCKSPAINT_API std::string Check(const FFoliageModel& M, const FPlant& P, double Nx, double Ny, double Nz,
			EFoliageMode Mode, const FFoliageWorld& World, const FPlantIndex& Index, const FFoliage& Models, double Spacing,
			double MaxSlopeDegrees);

		/// The brush without chance: candidates [x, z, yaw, scale] in order. Planted modes look for the ground below
		/// YTop (none: no_ground); air puts the plant at YTop. An accepted plant joins Index AT ONCE.
		MARCHINGBLOCKSPAINT_API FBrushResult Sow(const FFoliageModel& M, double YTop, const std::vector<std::array<double, 4>>& Candidates,
			EFoliageMode Mode, const FFoliageWorld& World, FPlantIndex& Index, const FFoliage& Models, double Spacing,
			double MaxSlopeDegrees);

		/// The ground of CELLS (no tiles): in column (floor x, floor z), from floor(YTop) - 1 down to YLow, the first
		/// full cell whose cell above is empty — ground y + 1, normal up. False: none.
		MARCHINGBLOCKSPAINT_API bool GroundOfCells(const std::function<bool(const FCell&)>& IsFull, double X, double Z, double YTop,
			FGround& Out, int YLow = GroundSearchFloor);

		/// The cell whose water counts at Q: (floor x, floor(y + 0.2), floor z).
		MARCHINGBLOCKSPAINT_API FCell WaterCell(double X, double Y, double Z);

		/// What a plant gives the wind shader: ground (p.y), height above ground, phase ((0.37 x + 0.71 z) mod 2 pi),
		/// amplitude (the model's wind).
		MARCHINGBLOCKSPAINT_API void WindData(const FFoliageModel& M, const FPlant& P, double Out[4]);

		/// A vertex P (normal N, world FORMAT space) of a plant with that wind data, at time T — the wind shader, line by
		/// line. A height of 0 does not move.
		MARCHINGBLOCKSPAINT_API void Sway(const double P[3], const double N[3], const double Wind[4], double T, double DirX,
			double DirZ, double Out[3]);

		MARCHINGBLOCKSPAINT_API const char* ModeName(EFoliageMode Mode);
	}
}
