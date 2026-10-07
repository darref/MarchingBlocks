// MarchingBlocks Paint for Unreal — le feuillage d'un monde (voir MarchingBlocksFoliage.h).
//
// ⚠ LA RÈGLE EST CELLE DE MBCore (MBFoliage, éprouvée par foliage_conformance.json) : ici, on ne fait que lui donner le
// monde — les cases de toutes les couches, l'eau recalculée, et le SOL : un rayon vertical contre les maillages de tuiles
// posés (ce que dit la règle : « chaque moteur cherche le sol par un rayon vertical contre SES maillages »), le sol des
// cases quand une couche n'a pas de tuiles.

#include "MarchingBlocksFoliage.h"

#include "Components/InstancedStaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "MarchingBlocksLooks.h"
#include "MarchingBlocksWater.h"
#include "MarchingBlocksWorld.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "MBCore/MBFoliage.h"
#include "Math/RandomStream.h"

#if WITH_EDITOR
#include "ScopedTransaction.h"
#endif

namespace MarchingBlocksFoliageDetail
{
	MBPaint::FFoliageModel ToCore(const FMarchingBlocksFoliageModel& M)
	{
		MBPaint::FFoliageModel C;
		C.Id = M.Id;
		C.Name = TCHAR_TO_UTF8(*M.Name);
		C.GroundOffset = M.GroundOffset;
		C.Scale = M.Scale;
		C.ScaleRandom = M.ScaleRandom;
		C.Footprint = M.Footprint;
		C.Height = M.Height;
		C.Wind = M.Wind;
		return C;
	}

	MBPaint::FPlant ToCore(const FMarchingBlocksPlant& P)
	{
		MBPaint::FPlant C;
		C.Model = P.Model;
		C.X = P.Point.X;
		C.Y = P.Point.Y;
		C.Z = P.Point.Z;
		C.Yaw = P.Yaw;
		C.Scale = P.Scale;
		C.Mode = P.bPlanted ? MBPaint::EPlantMode::Planted : MBPaint::EPlantMode::Air;
		return C;
	}

	FMarchingBlocksPlant FromCore(const MBPaint::FPlant& C)
	{
		FMarchingBlocksPlant P;
		P.Model = static_cast<int32>(C.Model);
		P.Point = FVector(C.X, C.Y, C.Z);
		P.Yaw = static_cast<float>(C.Yaw);
		P.Scale = static_cast<float>(C.Scale);
		P.bPlanted = C.Mode == MBPaint::EPlantMode::Planted;
		return P;
	}

	MBPaint::EFoliageMode ToCore(EMarchingBlocksFoliageMode M)
	{
		return M == EMarchingBlocksFoliageMode::Air ? MBPaint::EFoliageMode::Air
			: M == EMarchingBlocksFoliageMode::Overflow ? MBPaint::EFoliageMode::Overflow : MBPaint::EFoliageMode::Free;
	}

	const TCHAR* Reason(const FString& Code)
	{
		if (Code == TEXT("in_matter")) return TEXT("inside the matter");
		if (Code == TEXT("too_steep")) return TEXT("the ground is too steep");
		if (Code == TEXT("in_water")) return TEXT("in the water");
		if (Code == TEXT("at_edge")) return TEXT("its footprint is not carried by the ground (an edge)");
		if (Code == TEXT("under_matter")) return TEXT("the matter above leaves no room to grow");
		if (Code == TEXT("too_close")) return TEXT("too close to another plant");
		if (Code == TEXT("already_there")) return TEXT("a plant is already there");
		if (Code == TEXT("no_ground")) return TEXT("no ground under it");
		return TEXT("refused");
	}

	/** What the rule asks of the world, for one world of layers. */
	struct FAsk
	{
		TArray<AMarchingBlocksWorld*> Layers;
		MBPaint::FCellSet Full;
		MBPaint::FCellSet Water;
		MBPaint::FFoliageWorld World;
		TSet<const UPrimitiveComponent*> Tiles;
	};

	void Prepare(FAsk& Ask, UWorld* W, FName WorldName, AMarchingBlocksWorld* Frame)
	{
		Ask.Layers = Frame ? Frame->GetLayers() : TArray<AMarchingBlocksWorld*>();
		for (AMarchingBlocksWorld* L : Ask.Layers)
		{
			if (!L->IsLayerVisible()) continue;
			for (const MBPaint::FCell& C : L->GetCells()) Ask.Full.insert(C);
			for (UInstancedStaticMeshComponent* C : L->GetTileComponents())
				if (IsValid(C)) Ask.Tiles.Add(C);
		}
		Ask.Water = AMarchingBlocksWater::WaterCellsOf(W, WorldName);
		const MBPaint::FCellSet* Full = &Ask.Full;
		const MBPaint::FCellSet* Water = &Ask.Water;
		Ask.World.IsFull = [Full](const MBPaint::FCell& C) { return Full->count(C) > 0; };
		Ask.World.IsWater = [Water](const MBPaint::FCell& C) { return Water->count(C) > 0; };
		const TSet<const UPrimitiveComponent*>* Tiles = &Ask.Tiles;
		const std::function<bool(const MBPaint::FCell&)> IsFull = Ask.World.IsFull;
		Ask.World.Ground = [W, Frame, Tiles, IsFull](double X, double Z, double YTop, MBPaint::FGround& Out)
		{
			// A vertical ray against the tiles this world drew; the ground of the cells when it meets none.
			if (W && Frame && Tiles->Num() > 0)
			{
				const FVector Start = Frame->FormatToWorldPosition(FVector(X, YTop, Z));
				const FVector End = Frame->FormatToWorldPosition(FVector(X, MBPaint::Foliage::GroundSearchFloor, Z));
				TArray<FHitResult> Hits;
				FCollisionQueryParams Params(TEXT("MarchingBlocksGround"), true);
				W->LineTraceMultiByChannel(Hits, Start, End, ECC_Visibility, Params);
				for (const FHitResult& H : Hits)
					if (H.GetComponent() && Tiles->Contains(H.GetComponent()))
					{
						const FVector P = Frame->WorldToFormatPosition(H.ImpactPoint);
						const FVector N = (Frame->WorldToFormatPosition(H.ImpactPoint + H.ImpactNormal * 10.0) - P).GetSafeNormal();
						Out.Y = P.Y;
						Out.Nx = N.X;
						Out.Ny = N.Y;
						Out.Nz = N.Z;
						return true;
					}
			}
			return MBPaint::Foliage::GroundOfCells(IsFull, X, Z, YTop, Out);
		};
	}
}

AMarchingBlocksFoliage::AMarchingBlocksFoliage()
{
	PrimaryActorTick.bCanEverTick = false;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
}

AMarchingBlocksFoliage* AMarchingBlocksFoliage::Find(UWorld* World, FName InWorldName)
{
	if (!World || InWorldName.IsNone()) return nullptr;
	for (TActorIterator<AMarchingBlocksFoliage> It(World); It; ++It)
		if (IsValid(*It) && It->WorldName == InWorldName) return *It;
	return nullptr;
}

AMarchingBlocksWorld* AMarchingBlocksFoliage::FrameLayer() const
{
	UWorld* W = GetWorld();
	if (!W) return nullptr;
	for (TActorIterator<AMarchingBlocksWorld> It(W); It; ++It)
		if (IsValid(*It) && It->WorldName == WorldName)
		{
			const TArray<AMarchingBlocksWorld*> WorldLayers = It->GetLayers();
			// The first layer WITH tiles carries the measured frame (a layer without tiles has none).
			for (AMarchingBlocksWorld* L : WorldLayers)
				if (L->HasTileMeshes()) return L;
			return WorldLayers.Num() > 0 ? WorldLayers[0] : nullptr;
		}
	return nullptr;
}

void AMarchingBlocksFoliage::Rebuild()
{
	using namespace MarchingBlocksFoliageDetail;
	for (UInstancedStaticMeshComponent* C : Generated)
		if (IsValid(C)) C->DestroyComponent();
	Generated.Reset();
	WindLooks.Reset();
	AMarchingBlocksWorld* Frame = FrameLayer();
	if (!Frame) { Status = TEXT("No layer of this world in the level: the plants have no frame."); return; }
	UMaterialInterface* Wind = MarchingBlocksLooks::WindMaterial();
	int32 Drawn = 0, Without = 0;
	for (const FMarchingBlocksFoliageModel& Model : Models)
	{
		if (!Model.Mesh)
		{
			for (const FMarchingBlocksPlant& P : Plants) Without += P.Model == Model.Id ? 1 : 0;
			continue;
		}
		UInstancedStaticMeshComponent* C = NewObject<UInstancedStaticMeshComponent>(this, NAME_None, RF_Transient);
		C->SetStaticMesh(Model.Mesh);
		C->SetupAttachment(GetRootComponent());
		C->SetAbsolute(true, true, true);
		// PER INSTANCE: the plant's wind data (ground, height above it, phase, amplitude), in format space.
		C->SetNumCustomDataFloats(4);
		C->RegisterComponent();
		Generated.Add(C);
		for (int32 Slot = 0; Wind && Slot < Model.Mesh->GetStaticMaterials().Num(); ++Slot)
		{
			UMaterialInterface* Imported = Model.Mesh->GetMaterial(Slot);
			TObjectPtr<UMaterialInterface>* Done = WindLooks.Find(Imported);
			if (!Done)
			{
				UMaterialInstanceDynamic* Mid = UMaterialInstanceDynamic::Create(Wind, this);
				MarchingBlocksLooks::CopyImportedLook(Imported, Mid);
				MarchingBlocksLooks::SetFormatRows(Mid, Frame->FormatToWorld());
				Done = &WindLooks.Add(Imported, Mid);
			}
			C->SetMaterial(Slot, *Done);
		}
		const MBPaint::FFoliageModel M = ToCore(Model);
		for (const FMarchingBlocksPlant& Plant : Plants)
		{
			if (Plant.Model != Model.Id) continue;
			const MBPaint::FPlant P = ToCore(Plant);
			double Columns[3][3], Origin[3];
			MBPaint::Foliage::Transform(M, P, Columns, Origin);
			const int32 I = C->AddInstance(Frame->PlacedTransform(FVector(Origin[0], Origin[1], Origin[2]), P.Yaw,
				MBPaint::Foliage::ScaleOf(M, P)), true);
			double Data[4];
			MBPaint::Foliage::WindData(M, P, Data);
			const float Floats[4] = {static_cast<float>(Data[0]), static_cast<float>(Data[1]), static_cast<float>(Data[2]), static_cast<float>(Data[3])};
			C->SetCustomData(I, MakeArrayView(Floats, 4), false);
			++Drawn;
		}
	}
	Status = FString::Printf(TEXT("%d plant(s) drawn%s%s."), Drawn,
		Without > 0 ? *FString::Printf(TEXT(", %d of a model without its mesh (import its .glb, then set Mesh)"), Without) : TEXT(""),
		Wind ? TEXT("") : TEXT(" — the wind material is missing (Content/Materials/M_MB_Wind): they stand still"));
}

bool AMarchingBlocksFoliage::AimedPoint(const FVector& WorldOrigin, const FVector& WorldDirection, FVector& OutFormat) const
{
	AMarchingBlocksWorld* Frame = FrameLayer();
	UWorld* W = GetWorld();
	if (!Frame || !W) return false;
	if (Mode == EMarchingBlocksFoliageMode::Air)
	{
		// In the air: on the grid plane, y = the layer's floor.
		const FVector O = Frame->WorldToFormatPosition(WorldOrigin);
		const FVector D = Frame->WorldToFormatPosition(WorldOrigin + WorldDirection * 100.0) - O;
		if (FMath::Abs(D.Y) < 1e-9) return false;
		const double T = (Frame->Floor - O.Y) / D.Y;
		if (T <= 0.0) return false;
		OutFormat = O + D * T;
		return true;
	}
	TArray<FHitResult> Hits;
	FCollisionQueryParams Params(TEXT("MarchingBlocksAim"), true);
	W->LineTraceMultiByChannel(Hits, WorldOrigin, WorldOrigin + WorldDirection.GetSafeNormal() * 1e6, ECC_Visibility, Params);
	for (const FHitResult& H : Hits)
		if (H.GetActor() && H.GetActor()->IsA<AMarchingBlocksWorld>())
		{
			OutFormat = Frame->WorldToFormatPosition(H.ImpactPoint);
			return true;
		}
	// No tile met: the cells themselves (a layer without tiles).
	const MBPaint::FHit Hit = Frame->RayAgainstCells(WorldOrigin, WorldDirection);
	if (!Hit.bTouched) return false;
	OutFormat = FVector(Hit.Cell.X + 0.5 + Hit.Normal.X * 0.5, Hit.Cell.Y + 0.5 + Hit.Normal.Y * 0.5, Hit.Cell.Z + 0.5 + Hit.Normal.Z * 0.5);
	return true;
}

FString AMarchingBlocksFoliage::PlantAt(const FVector& WorldOrigin, const FVector& WorldDirection)
{
	using namespace MarchingBlocksFoliageDetail;
	const FMarchingBlocksFoliageModel* Model = Models.FindByPredicate([this](const FMarchingBlocksFoliageModel& M) { return M.Id == CurrentModel; });
	if (!Model) { Status = TEXT("Choose a model (Current Model: its Id)."); return TEXT("no_model"); }
	FVector Aim;
	if (!AimedPoint(WorldOrigin, WorldDirection, Aim)) { Status = TEXT("Foliage — point at the world."); return TEXT("no_ground"); }
	FAsk Ask;
	Prepare(Ask, GetWorld(), WorldName, FrameLayer());
	const MBPaint::FFoliageModel M = ToCore(*Model);
	MBPaint::FPlant P;
	P.Model = Model->Id;
	P.X = Aim.X;
	P.Y = Aim.Y;
	P.Z = Aim.Z;
	MBPaint::FGround G;
	if (Mode != EMarchingBlocksFoliageMode::Air)
	{
		if (!Ask.World.Ground(Aim.X, Aim.Z, Aim.Y + 1.0, G)) { Status = TEXT("Foliage — no ground under it."); return TEXT("no_ground"); }
		P.Y = G.Y;
	}
	FRandomStream Draw(static_cast<int32>(Draws++ * 7919u));
	const double A = FMath::Clamp(static_cast<double>(Model->ScaleRandom), 0.0, 0.9);
	P.Yaw = bRandomYaw ? Draw.FRand() * UE_DOUBLE_TWO_PI : 0.0;
	P.Scale = 1.0 + (Draw.FRand() * 2.0 - 1.0) * A;
	P.Mode = Mode == EMarchingBlocksFoliageMode::Air ? MBPaint::EPlantMode::Air : MBPaint::EPlantMode::Planted;
	MBPaint::FFoliage All;
	for (const FMarchingBlocksFoliageModel& X : Models) All.Models.push_back(ToCore(X));
	std::vector<MBPaint::FPlant> There;
	for (const FMarchingBlocksPlant& X : Plants) There.push_back(ToCore(X));
	const MBPaint::FPlantIndex Index(There, All);
	const FString Why = UTF8_TO_TCHAR(MBPaint::Foliage::Check(M, P, G.Nx, G.Ny, G.Nz, ToCore(Mode), Ask.World, Index, All, Spacing, MaxSlope).c_str());
	if (!Why.IsEmpty()) { Status = FString::Printf(TEXT("Foliage — not planted: %s."), Reason(Why)); return Why; }
#if WITH_EDITOR
	FScopedTransaction Transaction(NSLOCTEXT("MarchingBlocksPaint", "Plant", "Plant"));
	Modify();
#endif
	Plants.Add(FromCore(P));
	Rebuild();
	Status = FString::Printf(TEXT("Foliage — planted (%d plant(s))."), Plants.Num());
	return FString();
}

int32 AMarchingBlocksFoliage::SowAt(const FVector& WorldOrigin, const FVector& WorldDirection)
{
	using namespace MarchingBlocksFoliageDetail;
	const FMarchingBlocksFoliageModel* Model = Models.FindByPredicate([this](const FMarchingBlocksFoliageModel& M) { return M.Id == CurrentModel; });
	if (!Model) { Status = TEXT("Choose a model (Current Model: its Id)."); return 0; }
	FVector Centre;
	if (!AimedPoint(WorldOrigin, WorldDirection, Centre)) return 0;
	FAsk Ask;
	Prepare(Ask, GetWorld(), WorldName, FrameLayer());
	// The app's draw: a, d, then yaw and scale, per candidate (the conformance cases give the candidates).
	FRandomStream Draw(static_cast<int32>(Draws++ * 104729u));
	const double A = FMath::Clamp(static_cast<double>(Model->ScaleRandom), 0.0, 0.9);
	std::vector<std::array<double, 4>> Candidates;
	for (int32 I = 0; I < BrushTries; ++I)
	{
		const double Angle = Draw.FRand() * UE_DOUBLE_TWO_PI;
		const double D = FMath::Sqrt(Draw.FRand()) * BrushRadius;
		const double Yaw = bRandomYaw ? Draw.FRand() * UE_DOUBLE_TWO_PI : 0.0;
		const double Scale = 1.0 + (Draw.FRand() * 2.0 - 1.0) * A;
		Candidates.push_back({Centre.X + FMath::Cos(Angle) * D, Centre.Z + FMath::Sin(Angle) * D, Yaw, Scale});
	}
	MBPaint::FFoliage All;
	for (const FMarchingBlocksFoliageModel& X : Models) All.Models.push_back(ToCore(X));
	std::vector<MBPaint::FPlant> There;
	for (const FMarchingBlocksPlant& X : Plants) There.push_back(ToCore(X));
	MBPaint::FPlantIndex Index(There, All);
	// The ground is looked for below the dab (planted), or the plane itself (air).
	const double YTop = Mode == EMarchingBlocksFoliageMode::Air ? Centre.Y : Centre.Y + 1.5;
	const MBPaint::FBrushResult R = MBPaint::Foliage::Sow(ToCore(*Model), YTop, Candidates, ToCore(Mode), Ask.World, Index, All, Spacing, MaxSlope);
	if (R.Plants.empty()) { Status = TEXT("Foliage — nothing planted in this dab."); return 0; }
#if WITH_EDITOR
	FScopedTransaction Transaction(NSLOCTEXT("MarchingBlocksPaint", "Sow", "Sow plants"));
	Modify();
#endif
	for (const MBPaint::FPlant& P : R.Plants) Plants.Add(FromCore(P));
	Rebuild();
	TArray<FString> Refused;
	for (const auto& E : R.Refused) Refused.Add(FString::Printf(TEXT("%d %s"), E.second, UTF8_TO_TCHAR(E.first.c_str())));
	Status = FString::Printf(TEXT("Foliage — %d planted%s."), static_cast<int32>(R.Plants.size()),
		Refused.Num() ? *(TEXT(", refused: ") + FString::Join(Refused, TEXT(", "))) : TEXT(""));
	return static_cast<int32>(R.Plants.size());
}

int32 AMarchingBlocksFoliage::EraseAt(const FVector& WorldOrigin, const FVector& WorldDirection)
{
	FVector Centre;
	if (!AimedPoint(WorldOrigin, WorldDirection, Centre)) return 0;
	TArray<FMarchingBlocksPlant> Kept;
	for (const FMarchingBlocksPlant& P : Plants)
		// The app's rule: within the radius in the plane (and its height band), and within radius + 0.5 in space.
		if (FVector::Dist2D(FVector(P.Point.X, P.Point.Z, 0), FVector(Centre.X, Centre.Z, 0)) <= BrushRadius
			&& FMath::Abs(P.Point.Y - Centre.Y) <= BrushRadius + 2.0 && FVector::Dist(P.Point, Centre) <= BrushRadius + 0.5)
			continue;
		else Kept.Add(P);
	const int32 Removed = Plants.Num() - Kept.Num();
	if (Removed == 0) return 0;
#if WITH_EDITOR
	FScopedTransaction Transaction(NSLOCTEXT("MarchingBlocksPaint", "ErasePlants", "Erase plants"));
	Modify();
#endif
	Plants = MoveTemp(Kept);
	Rebuild();
	Status = FString::Printf(TEXT("Foliage — %d removed, %d left."), Removed, Plants.Num());
	return Removed;
}

void AMarchingBlocksFoliage::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	Rebuild();
}

#if WITH_EDITOR
void AMarchingBlocksFoliage::PostEditChangeProperty(FPropertyChangedEvent& Event)
{
	Super::PostEditChangeProperty(Event);
	Rebuild();
}

void AMarchingBlocksFoliage::PostEditUndo()
{
	Super::PostEditUndo();
	Rebuild();
}
#endif
