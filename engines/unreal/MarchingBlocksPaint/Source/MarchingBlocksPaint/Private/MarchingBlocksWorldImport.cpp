// MarchingBlocks Paint for Unreal — the world import (see MarchingBlocksWorldImport.h).

#include "MarchingBlocksWorldImport.h"

#include "Components/SceneComponent.h"
#include "Engine/World.h"
#include "MarchingBlocksWorld.h"
#include "MBCore/MBWorldFile.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"

#if WITH_EDITOR
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

	const FString BaseDir = FPaths::GetPath(Path);
	// "sample.mbworld" → "sample".
	const FString WorldName = CleanName(FPaths::GetBaseFilename(BaseDir), TEXT("world"));
	const FString Root = TilesRoot.Path.IsEmpty() ? FString(TEXT("/Game/MarchingBlocks")) : TilesRoot.Path;

	FScopedTransaction Transaction(NSLOCTEXT("MarchingBlocksPaint", "ImportWorld", "Import MarchingBlocks world"));
	Modify();
	for (AMarchingBlocksWorld* Old : Imported)
		if (IsValid(Old)) EditorWorld->EditorDestroyActor(Old, true);
	Imported.Reset();

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

	Status = FString::Printf(TEXT("%d layer(s), %d cell(s) imported from %s."), Imported.Num(), CellCount, *FPaths::GetCleanFilename(BaseDir));
	UE_LOG(LogMarchingBlocksWorldImport, Log, TEXT("%s"), *Status);
	if (WithoutTiles.Num() > 0)
	{
		// Said, never filled in: these layers were exported without a tileset.
		const FString Names = FString::Join(WithoutTiles, TEXT("', '"));
		Status += FString::Printf(TEXT(" Without tiles (cells kept, nothing drawn): '%s'."), *Names);
		UE_LOG(LogMarchingBlocksWorldImport, Warning, TEXT("Layer(s) without tiles — their cells are kept, nothing is drawn: '%s'"), *Names);
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
