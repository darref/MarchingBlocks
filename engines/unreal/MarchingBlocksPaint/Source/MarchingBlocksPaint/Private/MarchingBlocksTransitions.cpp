// MarchingBlocks Paint for Unreal — les transitions entre couches (voir MarchingBlocksTransitions.h).
//
// ⚠ L'EMPAQUETAGE EST CELUI RECOMMANDÉ PAR LES CAS (cell_texture) : un octet par case sur la boîte de l'union élargie de 6,
// quartet bas = rang + 1 de sa couche, quartet haut = rang + 1 choisi à ce sommet ; MBCore le construit
// (Transitions::BuildCellTexture), éprouvé par le banc. La table et les représentants suivent la disposition du shader de
// l'appli (transitions_rendu.gd) : quand C couvre D, texel (2D, C) = (active, softness, reach, irregularity), (2D + 1, C) =
// (fills_hollows, grain).

#include "MarchingBlocksTransitions.h"

#include "Components/InstancedStaticMeshComponent.h"
#include "Engine/Texture2D.h"
#include "Engine/Texture2DArray.h"
#include "TextureResource.h"
#include "Engine/VolumeTexture.h"
#include "EngineUtils.h"
#include "MarchingBlocksWorld.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "MBCore/MBTransitions.h"

namespace MarchingBlocksTransitionsDetail
{
	MBPaint::FTransitionSettings ToCore(const FMarchingBlocksTransitionSettings& S)
	{
		MBPaint::FJsonValue V = MBPaint::FJsonValue::MakeObject();
		V.Set("softness", MBPaint::FJsonValue::MakeReal(S.Softness)).Set("reach", MBPaint::FJsonValue::MakeReal(S.Reach))
			.Set("irregularity", MBPaint::FJsonValue::MakeReal(S.Irregularity)).Set("grain", MBPaint::FJsonValue::MakeReal(S.Grain))
			.Set("fills_hollows", MBPaint::FJsonValue::MakeReal(S.FillsHollows));
		// Bounded by MBCore, the same clamps as the file.
		return MBPaint::Transitions::ReadSettings(V);
	}

	UTexture2D* FloatTexture(int32 W, int32 H, const TArray<FLinearColor>& Texels)
	{
		UTexture2D* T = UTexture2D::CreateTransient(W, H, PF_A32B32G32R32F);
		if (!T) return nullptr;
		T->SRGB = false;
		T->Filter = TF_Nearest;
		T->AddressX = TA_Clamp;
		T->AddressY = TA_Clamp;
		FTexture2DMipMap& Mip = T->GetPlatformData()->Mips[0];
		void* Data = Mip.BulkData.Lock(LOCK_READ_WRITE);
		FMemory::Memcpy(Data, Texels.GetData(), static_cast<int64>(Texels.Num()) * sizeof(FLinearColor));
		Mip.BulkData.Unlock();
		T->UpdateResource();
		return T;
	}
}

AMarchingBlocksTransitions::AMarchingBlocksTransitions()
{
	PrimaryActorTick.bCanEverTick = false;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
}

AMarchingBlocksTransitions* AMarchingBlocksTransitions::Find(UWorld* World, FName InWorldName)
{
	if (!World || InWorldName.IsNone()) return nullptr;
	for (TActorIterator<AMarchingBlocksTransitions> It(World); It; ++It)
		if (IsValid(*It) && It->WorldName == InWorldName) return *It;
	return nullptr;
}

void AMarchingBlocksTransitions::Apply()
{
	using namespace MarchingBlocksTransitionsDetail;
	UWorld* W = GetWorld();
	if (!W) return;
	TArray<AMarchingBlocksWorld*> WorldLayers;
	for (TActorIterator<AMarchingBlocksWorld> It(W); It; ++It)
		if (IsValid(*It) && It->WorldName == WorldName) { WorldLayers = It->GetLayers(); break; }
	auto Clear = [&WorldLayers]()
	{
		for (AMarchingBlocksWorld* L : WorldLayers)
			for (UInstancedStaticMeshComponent* C : L->GetTileComponents())
				if (IsValid(C)) C->SetOverlayMaterial(nullptr);
	};
	Mids.Reset();
	if (WorldLayers.Num() == 0) { Status = TEXT("No layer of this world in the level."); return; }

	// The active directions (MBCore): without one, the blend is not even laid.
	std::vector<MBPaint::FTransitionPair> CorePairs;
	for (const FMarchingBlocksTransitionPair& P : Pairs)
	{
		MBPaint::FTransitionPair C;
		C.A = P.A;
		C.B = P.B;
		C.bActive = P.bActive;
		C.ACoversB = ToCore(P.ACoversB);
		C.BCoversA = ToCore(P.BCoversA);
		CorePairs.push_back(C);
	}
	const MBPaint::FTransitionTable Table = MBPaint::Transitions::Table(CorePairs, WorldLayers.Num());
	if (Table.empty()) { Clear(); Status = TEXT("No active pair: nothing blends."); return; }
	UMaterialInterface* Base = MarchingBlocksLooks::TransitionMaterial();
	if (!Base) { Clear(); Status = TEXT("The plugin's transition material is missing (Content/Materials/M_MB_Transition)."); return; }

	// The union of the VISIBLE layers: a cell belongs to the first layer holding it; its rank is the layer's index.
	std::vector<std::pair<MBPaint::FCell, int>> Union;
	MBPaint::FCellSet Seen;
	for (int32 I = 0; I < WorldLayers.Num(); ++I)
	{
		if (!WorldLayers[I]->IsLayerVisible()) continue;
		for (const MBPaint::FCell& C : WorldLayers[I]->GetCells())
			if (Seen.insert(C).second) Union.push_back({C, I});
	}
	std::vector<std::pair<MBPaint::FCell, int>> Chosen;
	for (const FIntVector4& C : Choices) Chosen.push_back({MBPaint::FCell(C.X, C.Y, C.Z), C.W});
	const MBPaint::FCellTexture Packed = MBPaint::Transitions::BuildCellTexture(Union, Chosen);

	CellsTexture = UVolumeTexture::CreateTransient(Packed.Size.X, Packed.Size.Y, Packed.Size.Z, PF_G8);
	if (!CellsTexture) { Clear(); Status = TEXT("The cell texture could not be made."); return; }
	CellsTexture->SRGB = false;
	CellsTexture->Filter = TF_Nearest;
	{
		FTexture2DMipMap& Mip = CellsTexture->GetPlatformData()->Mips[0];
		void* Data = Mip.BulkData.Lock(LOCK_READ_WRITE);
		FMemory::Memcpy(Data, Packed.Bytes.data(), static_cast<int64>(Packed.Bytes.size()));
		Mip.BulkData.Unlock();
		CellsTexture->UpdateResource();
	}

	const int32 Max = MBPaint::Transitions::LayersMax;
	TArray<FLinearColor> TableTexels;
	TableTexels.Init(FLinearColor(0.f, 0.f, 0.f, 0.f), 2 * Max * Max);
	for (const auto& Entry : Table)
	{
		const int32 C = Entry.first.first, D = Entry.first.second;
		const MBPaint::FTransitionSettings& S = Entry.second;
		TableTexels[C * 2 * Max + 2 * D] = FLinearColor(1.f, static_cast<float>(S.Softness), static_cast<float>(S.Reach), static_cast<float>(S.Irregularity));
		TableTexels[C * 2 * Max + 2 * D + 1] = FLinearColor(static_cast<float>(S.FillsHollows), static_cast<float>(S.Grain), 0.f, 0.f);
	}
	TableTexture = FloatTexture(2 * Max, Max, TableTexels);

	TArray<const FMarchingBlocksImage*> Images;
	TArray<FLinearColor> RepTexels;
	RepTexels.Init(FLinearColor(1.f, 1.f, 1.f, 1.f), 2 * Max);
	for (int32 I = 0; I < Max; ++I)
	{
		const FMarchingBlocksRepresentative* R = Representatives.IsValidIndex(I) ? &Representatives[I] : nullptr;
		// No image: a plain colour, so a WHITE slice that the colour multiplies.
		Images.Add(R && R->bHasImage ? &R->Image : nullptr);
		if (R)
		{
			RepTexels[I] = R->Color;
			RepTexels[Max + I] = FLinearColor(FMath::Max(R->Scale, 0.01f), FMath::Clamp(R->Roughness, 0.f, 1.f), R->bHasImage ? 1.f : 0.f, 0.f);
		}
		else RepTexels[Max + I] = FLinearColor(1.f, 1.f, 0.f, 0.f);
	}
	RepsTexture = MarchingBlocksLooks::MakeArray(Images, true, this, FColor::White);
	RepParamsTexture = FloatTexture(Max, 2, RepTexels);

	int32 Laid = 0;
	for (AMarchingBlocksWorld* L : WorldLayers)
	{
		// One per layer: each layer actor has its own frame and transform.
		UMaterialInstanceDynamic* Mid = UMaterialInstanceDynamic::Create(Base, this);
		Mid->SetTextureParameterValue(TEXT("MB_Cells"), CellsTexture);
		Mid->SetVectorParameterValue(TEXT("MB_CellsOrigin"), FLinearColor(Packed.Origin.X, Packed.Origin.Y, Packed.Origin.Z, 0.f));
		Mid->SetVectorParameterValue(TEXT("MB_CellsSize"), FLinearColor(Packed.Size.X, Packed.Size.Y, Packed.Size.Z, 0.f));
		Mid->SetTextureParameterValue(TEXT("MB_Table"), TableTexture);
		if (RepsTexture) Mid->SetTextureParameterValue(TEXT("MB_Reps"), RepsTexture);
		Mid->SetTextureParameterValue(TEXT("MB_RepParams"), RepParamsTexture);
		Mid->SetScalarParameterValue(TEXT("MB_ShowChoices"), bShowChoices ? 1.f : 0.f);
		MarchingBlocksLooks::SetFormatRows(Mid, L->FormatToWorld());
		Mids.Add(Mid);
		for (UInstancedStaticMeshComponent* C : L->GetTileComponents())
			if (IsValid(C)) { C->SetOverlayMaterial(Mid); ++Laid; }
	}
	Status = FString::Printf(TEXT("%d active direction(s), %d cell(s) in %d layer(s), laid over %d tile set(s)."),
		static_cast<int32>(Table.size()), static_cast<int32>(Union.size()), WorldLayers.Num(), Laid);
}

void AMarchingBlocksTransitions::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	Apply();
}

#if WITH_EDITOR
void AMarchingBlocksTransitions::PostEditChangeProperty(FPropertyChangedEvent& Event)
{
	Super::PostEditChangeProperty(Event);
	Apply();
}
#endif
