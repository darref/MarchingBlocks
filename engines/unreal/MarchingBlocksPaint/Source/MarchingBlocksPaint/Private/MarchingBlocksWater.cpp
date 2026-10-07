// MarchingBlocks Paint for Unreal — une couche d'eau (voir MarchingBlocksWater.h).
//
// ⚠ LA NAPPE CUITE EST EN ESPACE DU FORMAT, comme les cases : importée par le même importeur glTF que tiles.glb, elle porte
// le même repère F — on la pose donc à l'échelle des couches (taille de case / unité du repère), sans autre rotation.
// ⚠ LES CASES D'EAU se déduisent des cases de TOUTES les couches (cachées comprises : la règle le dit) et des sources de
// toutes les couches d'eau dans leur ordre (la première source dans le vide est LA mer).

#include "MarchingBlocksWater.h"

#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "EngineUtils.h"
#include "MarchingBlocksLooks.h"
#include "MarchingBlocksWorld.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "MBCore/MBWater.h"

namespace MarchingBlocksWaterDetail
{
	TArray<AMarchingBlocksWater*> WaterLayers(UWorld* World, FName WorldName)
	{
		TArray<AMarchingBlocksWater*> Out;
		if (!World) return Out;
		for (TActorIterator<AMarchingBlocksWater> It(World); It; ++It)
			if (IsValid(*It) && It->WorldName == WorldName) Out.Add(*It);
		Out.Sort([](const AMarchingBlocksWater& A, const AMarchingBlocksWater& B) { return A.Order != B.Order ? A.Order < B.Order : A.GetName() < B.GetName(); });
		return Out;
	}

	AMarchingBlocksWorld* FirstLayer(UWorld* World, FName WorldName, bool bWithTiles)
	{
		if (!World) return nullptr;
		for (TActorIterator<AMarchingBlocksWorld> It(World); It; ++It)
			if (IsValid(*It) && It->WorldName == WorldName)
			{
				for (AMarchingBlocksWorld* L : It->GetLayers())
					if (!bWithTiles || L->HasTileMeshes()) return L;
				return It->GetLayers()[0];
			}
		return nullptr;
	}

	/** The cells of every layer of the world, hidden ones too. */
	MBPaint::FCellSet AllCells(UWorld* World, FName WorldName)
	{
		MBPaint::FCellSet Out;
		if (AMarchingBlocksWorld* Any = FirstLayer(World, WorldName, false))
			for (AMarchingBlocksWorld* L : Any->GetLayers())
				for (const MBPaint::FCell& C : L->GetCells()) Out.insert(C);
		return Out;
	}
}

AMarchingBlocksWater::AMarchingBlocksWater()
{
	PrimaryActorTick.bCanEverTick = false;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
}

MBPaint::FCellSet AMarchingBlocksWater::WaterCellsOf(UWorld* World, FName InWorldName)
{
	using namespace MarchingBlocksWaterDetail;
	MBPaint::FCellSet Out;
	std::vector<MBPaint::FCell> Sources;
	for (AMarchingBlocksWater* W : WaterLayers(World, InWorldName))
		for (const FIntVector& S : W->Sources) Sources.push_back(MBPaint::FCell(S.X, S.Y, S.Z));
	if (Sources.empty()) return Out;
	const MBPaint::FWaterWorld Result = MBPaint::Water::World(AllCells(World, InWorldName), Sources);
	Out = Result.Sea;
	for (const MBPaint::FWaterBody& B : Result.Bodies) Out.insert(B.Water.begin(), B.Water.end());
	return Out;
}

void AMarchingBlocksWater::RecomputeWater()
{
	using namespace MarchingBlocksWaterDetail;
	WaterCells.clear();
	const TArray<AMarchingBlocksWater*> WaterWorldLayers = WaterLayers(GetWorld(), WorldName);
	std::vector<MBPaint::FCell> AllSources;
	int32 First = 0;
	for (AMarchingBlocksWater* W : WaterWorldLayers)
	{
		if (W == this) First = static_cast<int32>(AllSources.size());
		for (const FIntVector& S : W->Sources) AllSources.push_back(MBPaint::FCell(S.X, S.Y, S.Z));
	}
	const MBPaint::FWaterWorld Result = MBPaint::Water::World(AllCells(GetWorld(), WorldName), AllSources);
	TArray<FString> Said;
	for (int32 K = 0; K < this->Sources.Num(); ++K)
	{
		const MBPaint::FWaterBody& B = Result.Bodies[static_cast<size_t>(First + K)];
		if (!B.Error.empty()) { Said.Add(FString::Printf(TEXT("refused (%s)"), UTF8_TO_TCHAR(B.Error.c_str()))); continue; }
		WaterCells.insert(B.Water.begin(), B.Water.end());
		Said.Add(FString::Printf(TEXT("%s%s %d cell(s)"), UTF8_TO_TCHAR(MBPaint::Water::KindName(B.Kind)),
			B.End != MBPaint::EWaterEnd::None ? *FString::Printf(TEXT(" (%s)"), UTF8_TO_TCHAR(MBPaint::Water::EndName(B.End))) : TEXT(""),
			static_cast<int32>(B.Kind == MBPaint::EWaterKind::River ? B.Course.size() + B.Water.size() : B.Water.size())));
	}
	Status = Said.Num() ? FString::Join(Said, TEXT(" · ")) : FString(TEXT("No source."));
}

void AMarchingBlocksWater::DrawSheet()
{
	using namespace MarchingBlocksWaterDetail;
	if (SheetComponent) { SheetComponent->DestroyComponent(); SheetComponent = nullptr; }
	if (!Sheet) { Status = TEXT("No sheet: import water/<name>.glb from the .mbworld folder and set Sheet."); return; }
	AMarchingBlocksWorld* Frame = FirstLayer(GetWorld(), WorldName, true);
	SheetComponent = NewObject<UStaticMeshComponent>(this, NAME_None, RF_Transient);
	SheetComponent->SetStaticMesh(Sheet);
	SheetComponent->SetupAttachment(GetRootComponent());
	SheetComponent->SetAbsolute(true, true, true);
	SheetComponent->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	// The sheet carries the importer's frame like the tiles: the layers' scale and transform place it.
	if (Frame)
		SheetComponent->SetWorldTransform(FTransform(FQuat::Identity, FVector::ZeroVector, FVector(Frame->ImportedToUnreal())) * Frame->GetActorTransform());
	SheetComponent->RegisterComponent();
	UMaterialInterface* Chosen = Material ? Material.Get() : MarchingBlocksLooks::WaterMaterial(Look);
	if (Chosen)
	{
		UMaterialInstanceDynamic* Mid = UMaterialInstanceDynamic::Create(Chosen, this);
		if (Frame) MarchingBlocksLooks::SetFormatRows(Mid, Frame->FormatToWorld());
		for (int32 Slot = 0; Slot < SheetComponent->GetNumMaterials(); ++Slot) SheetComponent->SetMaterial(Slot, Mid);
	}
	else if (!Material) Status = FString::Printf(TEXT("'%s' is not one of the six presets: the sheet keeps its own material (assign yours in Material)."), *Look);
}

void AMarchingBlocksWater::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	DrawSheet();
	RecomputeWater();
}

#if WITH_EDITOR
void AMarchingBlocksWater::PostEditChangeProperty(FPropertyChangedEvent& Event)
{
	Super::PostEditChangeProperty(Event);
	DrawSheet();
	RecomputeWater();
}
#endif
