// MarchingBlocks Paint for Unreal — the world import (see MarchingBlocksWorldImport.h).

#include "MarchingBlocksWorldImport.h"

#include "Components/SceneComponent.h"
#include "Engine/World.h"
#include "MarchingBlocksWorld.h"
#include "MBCore/MBFoliage.h"
#include "MBCore/MBJson.h"
#include "MBCore/MBTransitions.h"
#include "MBCore/MBWater.h"
#include "MBCore/MBWorldFile.h"
#include "MarchingBlocksFoliage.h"
#include "MarchingBlocksTransitions.h"
#include "MarchingBlocksWater.h"
#include "Engine/StaticMesh.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"

#if WITH_EDITOR
#include "AssetRegistry/AssetRegistryModule.h"
#include "ScopedTransaction.h"
#endif

DEFINE_LOG_CATEGORY_STATIC(LogMarchingBlocksWorldImport, Log, All);

// A named namespace: Unreal's unity builds glue .cpp files together, and file-local helpers must not collide.
namespace MarchingBlocksWorldImportDetail
{
	/** A content-folder and Outliner-folder name: letters, digits, '_' and '-' only. */
	FString CleanName(const FString& In, const TCHAR* Fallback)
	{
		FString Out;
		for (const TCHAR C : In.ToLower())
			Out.AppendChar(FChar::IsAlnum(C) || C == TEXT('_') || C == TEXT('-') ? C : TEXT('_'));
		return Out.IsEmpty() ? FString(Fallback) : Out;
	}

#if WITH_EDITOR
	/** The first Static Mesh imported under a content folder, or nullptr. */
	UStaticMesh* MeshIn(const FString& Folder)
	{
		FAssetRegistryModule& Registry = FModuleManager::LoadModuleChecked<FAssetRegistryModule>(TEXT("AssetRegistry"));
		TArray<FAssetData> Assets;
		Registry.Get().GetAssetsByPath(FName(*Folder), Assets, true);
		for (const FAssetData& Asset : Assets)
			if (UStaticMesh* Mesh = Cast<UStaticMesh>(Asset.GetAsset())) return Mesh;
		return nullptr;
	}
#endif
}

AMarchingBlocksWorldImport::AMarchingBlocksWorldImport()
{
	PrimaryActorTick.bCanEverTick = false;
	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
	TilesRoot.Path = TEXT("/Game/MarchingBlocks");
	// An editor tool: it is not cooked. The layers it makes are ordinary actors and do not refer to it.
	bIsEditorOnlyActor = true;
}

void AMarchingBlocksWorldImport::ImportWorld()
{
#if WITH_EDITOR
	using namespace MarchingBlocksWorldImportDetail;
	UWorld* EditorWorld = GetWorld();
	if (!EditorWorld) return;
	if (WorldFile.FilePath.IsEmpty())
	{
		Status = TEXT("Choose a World File: the world.json inside a .mbworld folder.");
		return;
	}
	const FString Path = FPaths::ConvertRelativePathToFull(FPaths::ProjectDir(), WorldFile.FilePath);
	FString Text;
	if (!FFileHelper::LoadFileToString(Text, *Path))
	{
		Status = FString::Printf(TEXT("Cannot read %s"), *Path);
		UE_LOG(LogMarchingBlocksWorldImport, Error, TEXT("%s"), *Status);
		return;
	}
	std::vector<MBPaint::FWorldLayer> WorldLayers;
	const std::string Why = MBPaint::FWorldFile::ReadText(TCHAR_TO_UTF8(*Text), WorldLayers);
	if (!Why.empty())
	{
		// The WHOLE file is refused: nothing is made, nothing already in the level is touched.
		Status = FString::Printf(TEXT("world.json refused: %s"), UTF8_TO_TCHAR(Why.c_str()));
		UE_LOG(LogMarchingBlocksWorldImport, Error, TEXT("%s (%s)"), *Status, *Path);
		return;
	}

	MBPaint::FJsonValue Json;
	std::string JsonError;
	MBPaint::ParseJson(TCHAR_TO_UTF8(*Text), Json, JsonError);
	std::vector<MBPaint::FWaterLayer> Waters;
	MBPaint::FTransitions Transitions;
	MBPaint::FFoliage Foliage;
	std::string Refused = MBPaint::Water::Read(Json, Waters);
	if (Refused.empty()) Refused = MBPaint::Transitions::Read(Json, Transitions);
	if (Refused.empty()) Refused = MBPaint::Foliage::Read(Json, Foliage);
	if (!Refused.empty())
	{
		Status = FString::Printf(TEXT("world.json refused: %s"), UTF8_TO_TCHAR(Refused.c_str()));
		UE_LOG(LogMarchingBlocksWorldImport, Error, TEXT("%s (%s)"), *Status, *Path);
		return;
	}

	const FString BaseDir = FPaths::GetPath(Path);
	// "sample.mbworld" → "sample".
	const FString WorldName = CleanName(FPaths::GetBaseFilename(BaseDir), TEXT("world"));
	const FString Root = TilesRoot.Path.IsEmpty() ? FString(TEXT("/Game/MarchingBlocks")) : TilesRoot.Path;

	FScopedTransaction Transaction(NSLOCTEXT("MarchingBlocksPaint", "ImportWorld", "Import MarchingBlocks world"));
	Modify();
	for (AMarchingBlocksWorld* Old : Imported)
		if (IsValid(Old)) EditorWorld->EditorDestroyActor(Old, true);
	Imported.Reset();
	for (AActor* Old : ImportedLooks)
		if (IsValid(Old)) EditorWorld->EditorDestroyActor(Old, true);
	ImportedLooks.Reset();

	TArray<FString> WithoutTiles;
	TArray<FString> FoldersMissingTiles;
	int32 CellCount = 0;
	for (const MBPaint::FWorldLayer& Layer : WorldLayers)
	{
		const FString LayerName = UTF8_TO_TCHAR(Layer.Name.c_str());
		FActorSpawnParameters Params;
		Params.OverrideLevel = GetLevel();
		Params.ObjectFlags |= RF_Transactional;
		AMarchingBlocksWorld* Actor = EditorWorld->SpawnActor<AMarchingBlocksWorld>(AMarchingBlocksWorld::StaticClass(), GetActorTransform(), Params);
		if (!Actor)
		{
			UE_LOG(LogMarchingBlocksWorldImport, Error, TEXT("Layer '%s' could not be placed in the level."), *LayerName);
			continue;
		}
		Actor->SetActorLabel(LayerName.IsEmpty() ? FString(TEXT("Layer")) : LayerName);
		Actor->SetFolderPath(FName(*(FString(TEXT("MarchingBlocks/")) + WorldName)));
		Actor->CellSize = CellSize;
		// The layers are ONE world, in the order MarchingBlocks gave (the first is the highest priority).
		Actor->WorldName = FName(*WorldName);
		Actor->Priority = Imported.Num();

		FString TilesetFile, TilesFolder;
		if (Layer.bHasTileset)
		{
			// The path is RELATIVE to world.json: the tilesets travel inside the .mbworld folder.
			TilesetFile = FPaths::Combine(BaseDir, FString(UTF8_TO_TCHAR(Layer.Tileset.c_str())));
			FPaths::NormalizeFilename(TilesetFile);
			FPaths::CollapseRelativeDirectories(TilesetFile);
			// ".../rock.mbset/tileset.json" → "<Tiles Root>/<world>/rock".
			const FString SetName = CleanName(FPaths::GetBaseFilename(FPaths::GetPath(TilesetFile)), TEXT("tileset"));
			TilesFolder = Root / WorldName / SetName;
		}
		else
			WithoutTiles.Add(LayerName);
		Actor->SetVariants(Layer.Variants);   // step 8: before SetLayer, which rebuilds
		Actor->SetLayer(TilesetFile, TilesFolder, Layer.Cells);
		if (Layer.bHasTileset && !Actor->HasTileMeshes())
			FoldersMissingTiles.AddUnique(FString::Printf(TEXT("%s/tiles.glb → %s"), *FPaths::GetPath(TilesetFile), *TilesFolder));

		if (!Layer.bVisible)
		{
			// Hidden as it was in MarchingBlocks: in the viewport now, at the next editor start, and in game.
			Actor->bHiddenEd = true;
			Actor->SetIsTemporarilyHiddenInEditor(true);
			Actor->SetActorHiddenInGame(true);
		}
		CellCount += static_cast<int32>(Layer.Cells.size());
		Imported.Add(Actor);
	}

	// THE LOOKS: water, transitions, foliage — each an actor of the same world, in the same Outliner folder.
	auto SpawnLook = [&](UClass* Class, const FString& Label) -> AActor*
	{
		FActorSpawnParameters Params;
		Params.OverrideLevel = GetLevel();
		Params.ObjectFlags |= RF_Transactional;
		AActor* A = EditorWorld->SpawnActor<AActor>(Class, GetActorTransform(), Params);
		if (!A) return nullptr;
		A->SetActorLabel(Label);
		A->SetFolderPath(FName(*(FString(TEXT("MarchingBlocks/")) + WorldName)));
		ImportedLooks.Add(A);
		return A;
	};
	TArray<FString> LooksToImport;
	for (size_t I = 0; I < Waters.size(); ++I)
	{
		const MBPaint::FWaterLayer& L = Waters[I];
		AMarchingBlocksWater* W = Cast<AMarchingBlocksWater>(SpawnLook(AMarchingBlocksWater::StaticClass(),
			FString(TEXT("Water - ")) + UTF8_TO_TCHAR(L.Name.c_str())));
		if (!W) continue;
		W->WorldName = FName(*WorldName);
		W->Order = static_cast<int32>(I);
		W->Look = UTF8_TO_TCHAR(L.Look.c_str());
		for (const MBPaint::FCell& S : L.Sources) W->Sources.Add(FIntVector(S.X, S.Y, S.Z));
		if (L.bHasMesh)
		{
			const FString File = UTF8_TO_TCHAR(L.Mesh.c_str());
			const FString Folder = Root / WorldName / TEXT("water") / CleanName(FPaths::GetBaseFilename(File), TEXT("water"));
			W->Sheet = MeshIn(Folder);
			if (!W->Sheet) LooksToImport.Add(FString::Printf(TEXT("%s → %s"), *(BaseDir / File), *Folder));
		}
		if (!L.bVisible)
		{
			W->bHiddenEd = true;
			W->SetIsTemporarilyHiddenInEditor(true);
			W->SetActorHiddenInGame(true);
		}
		W->RerunConstructionScripts();
	}
	if (!Transitions.Pairs.empty() || !Transitions.Choices.empty())
		if (AMarchingBlocksTransitions* T = Cast<AMarchingBlocksTransitions>(SpawnLook(AMarchingBlocksTransitions::StaticClass(), TEXT("Transitions"))))
		{
			T->WorldName = FName(*WorldName);
			auto Settings = [](const MBPaint::FTransitionSettings& S)
			{
				FMarchingBlocksTransitionSettings O;
				O.Softness = static_cast<float>(S.Softness);
				O.Reach = static_cast<float>(S.Reach);
				O.Irregularity = static_cast<float>(S.Irregularity);
				O.Grain = static_cast<float>(S.Grain);
				O.FillsHollows = static_cast<float>(S.FillsHollows);
				return O;
			};
			for (const MBPaint::FTransitionPair& P : Transitions.Pairs)
			{
				FMarchingBlocksTransitionPair O;
				O.A = P.A;
				O.B = P.B;
				O.bActive = P.bActive;
				O.ACoversB = Settings(P.ACoversB);
				O.BCoversA = Settings(P.BCoversA);
				T->Pairs.Add(O);
			}
			for (const MBPaint::FRepresentative& R : Transitions.Representatives)
			{
				FMarchingBlocksRepresentative O;
				O.Color = FLinearColor(static_cast<float>(R.Color[0]), static_cast<float>(R.Color[1]), static_cast<float>(R.Color[2]), static_cast<float>(R.Color[3]));
				O.Scale = static_cast<float>(R.Scale);
				O.Roughness = static_cast<float>(R.Roughness);
				if (R.bHasImage)
				{
					const FString Rel = UTF8_TO_TCHAR(R.Image.c_str());
					O.bHasImage = MarchingBlocksLooks::LoadImageFile(BaseDir / Rel, Rel, O.Image);
					if (!O.bHasImage) UE_LOG(LogMarchingBlocksWorldImport, Warning, TEXT("Representative image missing: %s (plain colour instead)."), *Rel);
				}
				T->Representatives.Add(O);
			}
			for (const auto& C : Transitions.Choices) T->Choices.Add(FIntVector4(C.first.X, C.first.Y, C.first.Z, C.second));
		}
	if (!Foliage.Models.empty() || !Foliage.Plants.empty())
		if (AMarchingBlocksFoliage* F = Cast<AMarchingBlocksFoliage>(SpawnLook(AMarchingBlocksFoliage::StaticClass(), TEXT("Foliage"))))
		{
			F->WorldName = FName(*WorldName);
			for (const MBPaint::FFoliageModel& M : Foliage.Models)
			{
				FMarchingBlocksFoliageModel O;
				O.Id = static_cast<int32>(M.Id);
				O.Name = UTF8_TO_TCHAR(M.Name.c_str());
				O.MeshFile = M.bHasMesh ? FString(UTF8_TO_TCHAR(M.Mesh.c_str())) : FString();
				O.GroundOffset = static_cast<float>(M.GroundOffset);
				O.Scale = static_cast<float>(M.Scale);
				O.ScaleRandom = static_cast<float>(M.ScaleRandom);
				O.Footprint = static_cast<float>(M.Footprint);
				O.Height = static_cast<float>(M.Height);
				O.Wind = static_cast<float>(M.Wind);
				if (M.bHasMesh)
				{
					const FString Folder = Root / WorldName / TEXT("foliage") / CleanName(FPaths::GetBaseFilename(O.MeshFile), TEXT("model"));
					O.Mesh = MeshIn(Folder);
					if (!O.Mesh) LooksToImport.Add(FString::Printf(TEXT("%s (Combine Meshes ON) → %s"), *(BaseDir / O.MeshFile), *Folder));
				}
				else UE_LOG(LogMarchingBlocksWorldImport, Warning, TEXT("Foliage model '%s' was exported without its file: its plants are kept, nothing is drawn."), *O.Name);
				F->Models.Add(O);
			}
			for (const MBPaint::FPlant& P : Foliage.Plants)
			{
				FMarchingBlocksPlant O;
				O.Model = static_cast<int32>(P.Model);
				O.Point = FVector(P.X, P.Y, P.Z);
				O.Yaw = static_cast<float>(P.Yaw);
				O.Scale = static_cast<float>(P.Scale);
				O.bPlanted = P.Mode == MBPaint::EPlantMode::Planted;
				F->Plants.Add(O);
			}
			if (!F->Models.IsEmpty()) F->CurrentModel = F->Models[0].Id;
		}

	// Each layer was rebuilt alone as it arrived: now that every layer holds its cells, the world is rebuilt — the
	// transitions laid over it, the plants and the water drawn on its frame.
	if (Imported.Num() > 0 && IsValid(Imported[0])) Imported[0]->RebuildWorld();
	for (AActor* A : ImportedLooks)
		if (AMarchingBlocksFoliage* F = Cast<AMarchingBlocksFoliage>(A)) F->Rebuild();
		else if (AMarchingBlocksWater* W = Cast<AMarchingBlocksWater>(A)) W->RerunConstructionScripts();
	Status = FString::Printf(TEXT("%d layer(s), %d cell(s) imported from %s."), Imported.Num(), CellCount, *FPaths::GetCleanFilename(BaseDir));
	UE_LOG(LogMarchingBlocksWorldImport, Log, TEXT("%s"), *Status);
	if (WithoutTiles.Num() > 0)
	{
		// Said, never filled in: these layers were exported without a tileset.
		const FString Names = FString::Join(WithoutTiles, TEXT("', '"));
		Status += FString::Printf(TEXT(" Without tiles (cells kept, nothing drawn): '%s'."), *Names);
		UE_LOG(LogMarchingBlocksWorldImport, Warning, TEXT("Layer(s) without tiles — their cells are kept, nothing is drawn: '%s'"), *Names);
	}
	if (ImportedLooks.Num() > 0)
		Status += FString::Printf(TEXT(" %d water layer(s), %s transitions, %d plant(s)."), static_cast<int32>(Waters.size()),
			Transitions.Pairs.empty() ? TEXT("no") : TEXT("with"), static_cast<int32>(Foliage.Plants.size()));
	if (LooksToImport.Num() > 0)
	{
		Status += TEXT(" Import these .glb too, then press Import World again:");
		for (const FString& F : LooksToImport)
		{
			Status += TEXT(" ") + F + TEXT(";");
			UE_LOG(LogMarchingBlocksWorldImport, Warning, TEXT("Not imported yet: %s, then press Import World again."), *F);
		}
	}
	if (FoldersMissingTiles.Num() > 0)
	{
		Status += TEXT(" Import each tiles.glb (Combine Meshes OFF), then press Import World again:");
		for (const FString& F : FoldersMissingTiles)
		{
			Status += TEXT(" ") + F + TEXT(";");
			UE_LOG(LogMarchingBlocksWorldImport, Warning, TEXT("Tiles not imported yet: import %s (Combine Meshes OFF), then press Import World again."), *F);
		}
	}
#endif
}
