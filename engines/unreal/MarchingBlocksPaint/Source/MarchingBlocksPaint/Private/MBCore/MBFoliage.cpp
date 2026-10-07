// MarchingBlocks Paint for Unreal — le feuillage (voir MBFoliage.h). Réécrit depuis la règle du cœur (`feuillage.gd` :
// `verifier`, `_semer_un`, `transformation`, `vent_du_plant`, `balancement`, `sol_des_cases` ; `format_monde.gd`,
// `lire_feuillage`) ; éprouvé par Tests/foliage_conformance.json.
//
// ⚠ Préfixe Fol… (les « unity builds » d'Unreal fusionnent les .cpp).

#include "MBCore/MBFoliage.h"

#include <algorithm>
#include <cmath>

namespace MBPaint
{
	namespace
	{
		const double FolTwoPi = 6.283185307179586;
		const double FolBucket = 4.0;

		std::pair<int64_t, int64_t> FolBucketOf(double X, double Z)
		{
			return {static_cast<int64_t>(std::floor(X / FolBucket)), static_cast<int64_t>(std::floor(Z / FolBucket))};
		}

		double FolRadius(const FFoliageModel& M, const FPlant& P) { return M.Footprint * Foliage::ScaleOf(M, P); }

		int FolFloor(double X) { return static_cast<int>(std::floor(X)); }

		double FolPosMod(double X, double M)
		{
			const double R = std::fmod(X, M);
			return R < 0.0 ? R + M : R;
		}

		FJsonValue FolNum(double X) { return FJsonValue::MakeReal(X); }
	}

	FPlantIndex::FPlantIndex(const std::vector<FPlant>& Plants, const FFoliage& Models)
	{
		for (const FPlant& P : Plants) Add(P, Models);
	}

	void FPlantIndex::Add(const FPlant& Plant, const FFoliage& Models)
	{
		Buckets[FolBucketOf(Plant.X, Plant.Z)].push_back(Plant);
		if (const FFoliageModel* M = Models.FindModel(Plant.Model)) RadiusMax = std::max(RadiusMax, FolRadius(*M, Plant));
	}

	std::vector<const FPlant*> FPlantIndex::Near(double X, double Y, double Z, double Reach) const
	{
		std::vector<const FPlant*> Out;
		const auto Lo = FolBucketOf(X - Reach, Z - Reach);
		const auto Hi = FolBucketOf(X + Reach, Z + Reach);
		for (int64_t BX = Lo.first; BX <= Hi.first; ++BX)
			for (int64_t BZ = Lo.second; BZ <= Hi.second; ++BZ)
			{
				const auto Found = Buckets.find({BX, BZ});
				if (Found == Buckets.end()) continue;
				for (const FPlant& Q : Found->second)
					if (std::hypot(Q.X - X, Q.Z - Z) <= Reach && std::fabs(Q.Y - Y) <= Reach + 2.0) Out.push_back(&Q);
			}
		return Out;
	}

	namespace Foliage
	{
		const char* ModeName(EFoliageMode Mode)
		{
			return Mode == EFoliageMode::Air ? "air" : Mode == EFoliageMode::Free ? "free" : "overflow";
		}

		std::string Read(const FJsonValue& World, FFoliage& Out)
		{
			Out = FFoliage();
			if (World.Type != FJsonValue::EType::Object) return "not a MarchingBlocks world";
			const FJsonValue* D = World.Find("foliage");
			if (!D || D->IsNull()) return "";
			if (D->Type != FJsonValue::EType::Object) return "foliage is not an object";
			FFoliage F;
			const FJsonValue* List = D->Find("models");
			if (List && List->Type != FJsonValue::EType::Array) return "foliage: models is not an array";
			if (List)
				for (size_t I = 0; I < List->Size(); ++I)
				{
					const FJsonValue& E = (*List)[I];
					if (E.Type != FJsonValue::EType::Object) return "foliage: a model is not an object";
					if (!E["id"].IsWhole()) return "foliage: a model has no integer id";
					FFoliageModel M;
					M.Id = E["id"].AsInt();
					if (const FJsonValue* Name = E.Find("name"))
					{
						if (Name->Type != FJsonValue::EType::String) return "foliage: a model's name is not a string";
						M.Name = Name->String;
					}
					else M.Name = "Model " + std::to_string(I + 1);
					const FJsonValue& Mesh = E["mesh"];
					if (!Mesh.IsNull() && Mesh.Type != FJsonValue::EType::String) return "foliage: a model's mesh is neither a path nor null";
					M.bHasMesh = Mesh.Type == FJsonValue::EType::String;
					M.Mesh = Mesh.String;
					struct FKey { const char* Name; double* Value; };
					const FKey Keys[] = {{"ground_offset", &M.GroundOffset}, {"scale", &M.Scale}, {"scale_random", &M.ScaleRandom},
						{"footprint", &M.Footprint}, {"height", &M.Height}, {"wind", &M.Wind}};
					for (const FKey& K : Keys)
						if (const FJsonValue* V = E.Find(K.Name))
						{
							if (!V->IsNumber()) return std::string("foliage: a model's ") + K.Name + " is not a number";
							*K.Value = V->AsReal();
						}
					if (F.FindModel(M.Id)) return "foliage: a model id appears twice";
					F.Models.push_back(M);
				}
			const FJsonValue* Flat = D->Find("plants");
			if (Flat && (Flat->Type != FJsonValue::EType::Array || Flat->Size() % 7 != 0))
				return "foliage: plants are not groups of seven numbers";
			if (Flat)
				for (size_t K = 0; K < Flat->Size(); K += 7)
				{
					for (size_t J = 0; J < 7; ++J)
						if (!(*Flat)[K + J].IsNumber()) return "foliage: a plant is not made of numbers";
					FPlant P;
					P.Model = static_cast<int64_t>((*Flat)[K].AsReal());
					if (!F.FindModel(P.Model)) return "foliage: a plant uses a model that does not exist";
					P.X = (*Flat)[K + 1].AsReal();
					P.Y = (*Flat)[K + 2].AsReal();
					P.Z = (*Flat)[K + 3].AsReal();
					P.Yaw = (*Flat)[K + 4].AsReal();
					P.Scale = (*Flat)[K + 5].AsReal();
					P.Mode = static_cast<int64_t>((*Flat)[K + 6].AsReal()) == 0 ? EPlantMode::Air : EPlantMode::Planted;
					F.Plants.push_back(P);
				}
			Out = F;
			return "";
		}

		FJsonValue ToJson(const FFoliage& F)
		{
			FJsonValue Models = FJsonValue::MakeArray();
			for (const FFoliageModel& M : F.Models)
			{
				FJsonValue E = FJsonValue::MakeObject();
				E.Set("id", FJsonValue::MakeInt(M.Id)).Set("name", FJsonValue::MakeString(M.Name))
					.Set("mesh", M.bHasMesh ? FJsonValue::MakeString(M.Mesh) : FJsonValue())
					.Set("ground_offset", FolNum(M.GroundOffset)).Set("scale", FolNum(M.Scale)).Set("scale_random", FolNum(M.ScaleRandom))
					.Set("footprint", FolNum(M.Footprint)).Set("height", FolNum(M.Height)).Set("wind", FolNum(M.Wind));
				Models.Push(E);
			}
			FJsonValue Plants = FJsonValue::MakeArray();
			for (const FPlant& P : F.Plants)
			{
				FJsonValue E = FJsonValue::MakeArray();
				E.Push(FJsonValue::MakeInt(P.Model)).Push(FolNum(P.X)).Push(FolNum(P.Y)).Push(FolNum(P.Z)).Push(FolNum(P.Yaw))
					.Push(FolNum(P.Scale)).Push(FJsonValue::MakeInt(P.Mode == EPlantMode::Air ? 0 : 1));
				Plants.Push(E);
			}
			FJsonValue Out = FJsonValue::MakeObject();
			Out.Set("models", Models).Set("plants", Plants);
			return Out;
		}

		double ScaleOf(const FFoliageModel& M, const FPlant& P) { return M.Scale * P.Scale; }

		double HeightAboveGround(const FFoliageModel& M, const FPlant& P)
		{
			return std::max(0.0, (M.Height + M.GroundOffset) * ScaleOf(M, P));
		}

		void Transform(const FFoliageModel& M, const FPlant& P, double OutColumns[3][3], double OutOrigin[3])
		{
			const double S = ScaleOf(M, P);
			const double C = std::cos(P.Yaw), N = std::sin(P.Yaw);
			// Une rotation autour de +Y, main droite (+Z tourne vers +X) : la colonne x est (cos, 0, −sin).
			const double Columns[3][3] = {{C * S, 0.0, -N * S}, {0.0, S, 0.0}, {N * S, 0.0, C * S}};
			for (int I = 0; I < 3; ++I)
				for (int J = 0; J < 3; ++J) OutColumns[I][J] = Columns[I][J];
			OutOrigin[0] = P.X;
			OutOrigin[1] = P.Y + M.GroundOffset * S;
			OutOrigin[2] = P.Z;
		}

		std::string Check(const FFoliageModel& M, const FPlant& P, double Nx, double Ny, double Nz, EFoliageMode Mode,
			const FFoliageWorld& World, const FPlantIndex& Index, const FFoliage& Models, double Spacing, double MaxSlopeDegrees)
		{
			const double R = FolRadius(M, P);
			// 1. Les voisins, dans TOUS les modes : d'abord le doublon.
			double Reach = std::max(Spacing, Duplicate);
			if (Mode == EFoliageMode::Free) Reach = std::max(Reach, R + Index.LargestRadius());
			for (const FPlant* Q : Index.Near(P.X, P.Y, P.Z, Reach))
			{
				const double D = std::hypot(Q->X - P.X, Q->Z - P.Z);
				if (D < Duplicate) return "already_there";
				if (D < Spacing) return "too_close";
				if (Mode == EFoliageMode::Free)
					if (const FFoliageModel* QM = Models.FindModel(Q->Model))
						if (D < R + FolRadius(*QM, *Q)) return "too_close";
			}
			// 2. Dans l'air : seul le plan de la grille est demandé.
			if (Mode == EFoliageMode::Air)
				return World.IsFull(FCell(FolFloor(P.X), FolFloor(P.Y), FolFloor(P.Z))) ? "in_matter" : "";
			// 3. Planté : la pente, l'eau.
			const double Length = std::sqrt(Nx * Nx + Ny * Ny + Nz * Nz);
			const double NormalY = Length > 0.0 ? Ny / Length : 0.0;
			if (NormalY < std::cos(MaxSlopeDegrees * FolTwoPi / 360.0) - 1e-6) return "too_steep";
			if (World.IsWater && World.IsWater(WaterCell(P.X, P.Y + 0.1, P.Z))) return "in_water";
			if (Mode != EFoliageMode::Free) return "";
			// 4. Voisinage libre : l'empreinte portée par le sol, à peu près à la même hauteur…
			double Edge[EdgeSamples + 1][2] = {{0.0, 0.0}};
			for (int K = 0; K < EdgeSamples; ++K)
			{
				const double A = FolTwoPi * static_cast<double>(K) / static_cast<double>(EdgeSamples);
				Edge[K + 1][0] = std::cos(A) * R;
				Edge[K + 1][1] = std::sin(A) * R;
			}
			for (int K = 1; K <= EdgeSamples; ++K)
			{
				if (Edge[K][0] == 0.0 && Edge[K][1] == 0.0) continue;
				FGround G;
				if (!World.Ground(P.X + Edge[K][0], P.Z + Edge[K][1], P.Y + 1.0, G) || std::fabs(G.Y - P.Y) > GroundTolerance)
					return "at_edge";
			}
			// … et rien de plein au-dessus, sur sa hauteur, au centre et à mi-rayon.
			const double H = HeightAboveGround(M, P);
			const int Y0 = FolFloor(P.Y + 0.3);
			const int Y1 = FolFloor(P.Y + std::max(H, 0.3));
			for (int K = 0; K <= EdgeSamples; ++K)
			{
				const double QX = P.X + Edge[K][0] * 0.5, QZ = P.Z + Edge[K][1] * 0.5;
				for (int Y = Y0; Y <= Y1; ++Y)
					if (World.IsFull(FCell(FolFloor(QX), Y, FolFloor(QZ)))) return "under_matter";
			}
			return "";
		}

		FBrushResult Sow(const FFoliageModel& M, double YTop, const std::vector<std::array<double, 4>>& Candidates, EFoliageMode Mode,
			const FFoliageWorld& World, FPlantIndex& Index, const FFoliage& Models, double Spacing, double MaxSlopeDegrees)
		{
			FBrushResult Out;
			for (const std::array<double, 4>& C : Candidates)
			{
				FPlant P;
				P.Model = M.Id;
				P.X = C[0];
				P.Y = YTop;
				P.Z = C[1];
				FGround G;
				if (Mode != EFoliageMode::Air)
				{
					if (!World.Ground(C[0], C[1], YTop, G)) { ++Out.Refused["no_ground"]; continue; }
					P.Y = G.Y;
				}
				P.Yaw = C[2];
				P.Scale = C[3];
				P.Mode = Mode == EFoliageMode::Air ? EPlantMode::Air : EPlantMode::Planted;
				const std::string Why = Check(M, P, G.Nx, G.Ny, G.Nz, Mode, World, Index, Models, Spacing, MaxSlopeDegrees);
				if (!Why.empty()) { ++Out.Refused[Why]; continue; }
				Out.Plants.push_back(P);
				Index.Add(P, Models);
			}
			return Out;
		}

		bool GroundOfCells(const std::function<bool(const FCell&)>& IsFull, double X, double Z, double YTop, FGround& Out, int YLow)
		{
			const int CX = FolFloor(X), CZ = FolFloor(Z);
			for (int Y = FolFloor(YTop) - 1; Y >= YLow; --Y)
				if (IsFull(FCell(CX, Y, CZ)) && !IsFull(FCell(CX, Y + 1, CZ)))
				{
					Out = FGround();
					Out.Y = static_cast<double>(Y + 1);
					return true;
				}
			return false;
		}

		FCell WaterCell(double X, double Y, double Z) { return FCell(FolFloor(X), FolFloor(Y + WaterOffset), FolFloor(Z)); }

		void WindData(const FFoliageModel& M, const FPlant& P, double Out[4])
		{
			Out[0] = P.Y;
			Out[1] = HeightAboveGround(M, P);
			Out[2] = FolPosMod(P.X * 0.37 + P.Z * 0.71, FolTwoPi);
			Out[3] = M.Wind;
		}

		void Sway(const double P[3], const double N[3], const double Wind[4], double T, double DirX, double DirZ, double Out[3])
		{
			for (int I = 0; I < 3; ++I) Out[I] = P[I];
			const double Height = Wind[1];
			if (Height <= 0.0) return;
			const double H = std::max(0.0, std::min(1.0, (P[1] - Wind[0]) / Height));
			const double Phase = Wind[2];
			const double Amplitude = Wind[3] * Height * 0.05;
			const double B = 0.35 + 0.6 * std::sin(T * 1.1 + Phase) + 0.3 * std::sin(T * 2.3 + Phase * 1.7);
			const double L = std::sqrt(DirX * DirX + DirZ * DirZ);
			const double K = B * Amplitude * H * H / L;
			Out[0] += DirX * K;
			Out[2] += DirZ * K;
			const double Shiver = std::sin(T * 7.0 + Out[0] * 2.1 + Out[1] * 1.7 + Out[2] * 2.9) * 0.015 * Wind[3] * H;
			for (int I = 0; I < 3; ++I) Out[I] += N[I] * Shiver;
		}
	}
}
